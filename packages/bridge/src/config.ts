// ============================================================
// config.ts — Config Loader لـ bridge.config.json
// ============================================================

import { readFileSync, existsSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))


export interface BridgeConfig {
  bridge: {
    port: number
    host: string
    tailscaleIp?: string
  }
  openclaude: {
    execPath: string        // مسار openclaude الـ CLI
    defaultProjectPath: string
  }
  providers: {
    'nvidia-nim'?: { apiKey: string; model?: string }
    'openai'?:     { apiKey: string }
    'gemini'?:     { apiKey: string }
    'anthropic'?:  { apiKey: string }
    'ollama'?:     { baseURL?: string }
  }
  customProviders?: Record<string, {
    name: string
    baseURL: string
    apiKey: string
    models: Array<{ id: string; name: string; contextWindow: number; supportsFunctions: boolean }>
  }>
}

const CONFIG_FILENAME = 'bridge.config.json'
let _config: BridgeConfig | null = null

export function loadConfig(): BridgeConfig {
  if (_config) return _config

  // ابحث عن الإعداد في مجلد bridge أو أعلاه
  const searchPaths = [
    join(__dirname, '..', CONFIG_FILENAME),
    join(__dirname, '..', '..', CONFIG_FILENAME),
    join(process.cwd(), CONFIG_FILENAME),
  ]

  const found = searchPaths.find(existsSync)
  if (!found) {
    console.warn(`[Config] bridge.config.json not found. Using defaults.`)
    _config = defaultConfig()
    return _config
  }

  try {
    const raw = readFileSync(found, 'utf-8')
    _config = JSON.parse(raw) as BridgeConfig
    console.log(`[Config] Loaded from: ${found}`)
    return _config
  } catch (err) {
    console.error(`[Config] Failed to parse bridge.config.json:`, err)
    _config = defaultConfig()
    return _config
  }
}

export function reloadConfig(): BridgeConfig {
  _config = null
  return loadConfig()
}

function defaultConfig(): BridgeConfig {
  return {
    bridge: { port: 8765, host: 'localhost' },
    openclaude: {
      execPath: 'openclaude',
      defaultProjectPath: process.cwd(),
    },
    providers: {},
    customProviders: {},
  }
}
