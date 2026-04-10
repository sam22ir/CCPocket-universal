// ============================================================
// nvidia-nim.ts — Nvidia NIM Provider (المزود الافتراضي للاختبار)
// ============================================================

import { openaiCompatible } from './openai-compatible.ts'
import type { Provider } from './base.ts'

export function createNvidiaNim(apiKey: string, modelOverride?: string): Provider {
  return openaiCompatible({
    id: 'nvidia-nim',
    name: 'Nvidia NIM',
    baseURL: 'https://integrate.api.nvidia.com/v1',
    apiKey,
    models: [
      {
        id: modelOverride ?? 'meta/llama-3.3-70b-instruct',
        name: 'Llama 3.3 70B Instruct',
        contextWindow: 128000,
        supportsFunctions: true,
      },
      {
        id: 'meta/llama-3.1-8b-instruct',
        name: 'Llama 3.1 8B Instruct',
        contextWindow: 128000,
        supportsFunctions: true,
      },
      {
        id: 'nvidia/llama-3.1-nemotron-70b-instruct',
        name: 'Nemotron 70B',
        contextWindow: 128000,
        supportsFunctions: true,
      },
    ],
  })
}

export function createOpenAI(apiKey: string): Provider {
  return openaiCompatible({
    id: 'openai',
    name: 'OpenAI',
    baseURL: 'https://api.openai.com/v1',
    apiKey,
    models: [
      { id: 'gpt-4o', name: 'GPT-4o', contextWindow: 128000, supportsFunctions: true },
      { id: 'gpt-4o-mini', name: 'GPT-4o Mini', contextWindow: 128000, supportsFunctions: true },
    ],
  })
}

export function createGemini(apiKey: string): Provider {
  return openaiCompatible({
    id: 'gemini',
    name: 'Google Gemini',
    baseURL: 'https://generativelanguage.googleapis.com/v1beta/openai',
    apiKey,
    models: [
      { id: 'gemini-2.0-flash', name: 'Gemini 2.0 Flash', contextWindow: 1048576, supportsFunctions: true },
      { id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro', contextWindow: 2097152, supportsFunctions: true },
    ],
  })
}

export function createOllama(baseURL: string = 'http://localhost:11434/v1'): Provider {
  return openaiCompatible({
    id: 'ollama',
    name: 'Ollama (Local)',
    baseURL,
    apiKey: 'ollama', // مطلوب شكلياً
    models: [
      { id: 'llama3.2', name: 'Llama 3.2', contextWindow: 8192, supportsFunctions: false },
      { id: 'codellama', name: 'Code Llama', contextWindow: 16384, supportsFunctions: false },
    ],
  })
}

export function createAnthropic(apiKey: string): Provider {
  // Anthropic عبر OpenAI-compatible proxy
  return openaiCompatible({
    id: 'anthropic',
    name: 'Anthropic',
    baseURL: 'https://api.anthropic.com/v1',
    apiKey,
    models: [
      { id: 'claude-3-5-sonnet-20241022', name: 'Claude 3.5 Sonnet', contextWindow: 200000, supportsFunctions: true },
      { id: 'claude-3-5-haiku-20241022', name: 'Claude 3.5 Haiku', contextWindow: 200000, supportsFunctions: true },
    ],
  })
}
