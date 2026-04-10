// ============================================================
// index.ts — Provider Registry
// ============================================================

import type { Provider } from './base.ts'
import { createNvidiaNim, createOpenAI, createGemini, createOllama, createAnthropic } from './nvidia-nim.ts'
import { openaiCompatible } from './openai-compatible.ts'
import { loadConfig } from '../config.ts'

export type ProviderId = 'nvidia-nim' | 'openai' | 'gemini' | 'ollama' | 'anthropic' | string

const registry: Map<string, Provider> = new Map()

export function initProviders(): void {
  const config = loadConfig()

  // مزودون مدمجون
  if (config.providers['nvidia-nim']?.apiKey) {
    registry.set('nvidia-nim', createNvidiaNim(config.providers['nvidia-nim'].apiKey))
  }
  if (config.providers['openai']?.apiKey) {
    registry.set('openai', createOpenAI(config.providers['openai'].apiKey))
  }
  if (config.providers['gemini']?.apiKey) {
    registry.set('gemini', createGemini(config.providers['gemini'].apiKey))
  }
  if (config.providers['ollama']) {
    registry.set('ollama', createOllama(config.providers['ollama']?.baseURL))
  }
  if (config.providers['anthropic']?.apiKey) {
    registry.set('anthropic', createAnthropic(config.providers['anthropic'].apiKey))
  }

  // مزودون مخصصون من الإعداد
  for (const [id, custom] of Object.entries(config.customProviders ?? {})) {
    registry.set(id, openaiCompatible({
      id,
      name: custom.name,
      baseURL: custom.baseURL,
      apiKey: custom.apiKey,
      models: custom.models,
    }))
  }

  console.log(`[Registry] Loaded ${registry.size} providers:`, [...registry.keys()])
}

export function getProvider(id: string): Provider {
  const p = registry.get(id)
  if (!p) throw new Error(`Provider "${id}" not found. Check bridge.config.json`)
  return p
}

export function listProviders(): Provider[] {
  return [...registry.values()]
}

export function registerProvider(provider: Provider): void {
  registry.set(provider.id, provider)
  console.log(`[Registry] Registered provider: ${provider.id}`)
}

export async function validateProvider(
  baseURL: string,
  apiKey: string,
  modelId: string
): Promise<{ success: boolean; step: string; message: string }> {
  const headers = { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' }
  const timeout = 10_000

  // الخطوة 1: Connectivity
  try {
    const res = await fetch(`${baseURL}/models`, { headers, signal: AbortSignal.timeout(timeout) })
    if (!res.ok) return { success: false, step: 'connectivity', message: `API Key خاطئ أو URL غير متاح (${res.status})` }
  } catch {
    return { success: false, step: 'connectivity', message: 'لا يمكن الوصول إلى العنوان. تحقق من الـ URL.' }
  }

  // الخطوة 2: Smoke Test
  try {
    const body = JSON.stringify({ model: modelId, messages: [{ role: 'user', content: 'Hi' }] })
    const res = await fetch(`${baseURL}/chat/completions`, { method: 'POST', headers, body, signal: AbortSignal.timeout(timeout) })
    const json = await res.json() as Record<string, unknown>
    const choices = json?.choices as Array<Record<string, unknown>> | undefined
    if (!choices?.[0]) return { success: false, step: 'smoke_test', message: `Model ID "${modelId}" غير موجود أو الـ API لا يتوافق مع OpenAI` }
  } catch {
    return { success: false, step: 'smoke_test', message: 'الـ endpoint لا يرد بشكل صحيح. تحقق من Model ID.' }
  }

  return { success: true, step: 'done', message: 'تم التحقق بنجاح ✅' }
}
