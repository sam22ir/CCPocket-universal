# Bridge-Embedded Anthropic Translator

A TypeScript HTTP server embedded inside the Bridge that translates **Anthropic Messages API → OpenAI Chat Completions format**, eliminating the need for Python proxies entirely.

## Problem

Claude Code CLI exclusively communicates via the **Anthropic Messages API**.  
External providers (NIM, OpenRouter, Ollama) expose **OpenAI-compatible APIs**.  
Previous solution required a Python subprocess (`free-claude-code`) with `uv` and a ~3s cold start.

## Solution Architecture

```
Claude Code CLI
  ↓  ANTHROPIC_BASE_URL=http://127.0.0.1:{port}
translator.ts (HTTP Server — pure TypeScript)
  ↓  translates Anthropic Messages → OpenAI Chat Completions
NIM / OpenRouter / Ollama / any OpenAI-compatible endpoint
```

## API

```typescript
export async function startTranslator(config: TranslatorConfig): Promise<string>
export async function stopTranslator(): Promise<void>
export async function configureTranslator(config: TranslatorConfig): Promise<void>
export function isTranslatorRunning(): boolean
export function translatorBaseUrl(): string

export function buildTranslatorEnv(): Record<string, string>
// Returns: { ANTHROPIC_BASE_URL: 'http://127.0.0.1:8090' }
```

## TranslatorConfig

```typescript
interface TranslatorConfig {
  baseURL:     string    // e.g. 'https://integrate.api.nvidia.com/v1'
  apiKey:      string
  bigModel:    string    // primary model
  smallModel?: string    // lightweight tasks
  port?:       number    // default: 8090
}

// Preset factories
TranslatorConfig.nim(apiKey: string)        // → NVIDIA NIM
TranslatorConfig.openRouter(apiKey: string) // → OpenRouter
TranslatorConfig.ollama()                   // → local Ollama
```

## Translation Schema

### Request: Anthropic → OpenAI

| Anthropic Field | OpenAI Field | Notes |
|----------------|--------------|-------|
| `messages[].role` | `messages[].role` | direct mapping |
| `messages[].content` (string) | `messages[].content` | direct |
| `messages[].content` (array) | `messages[].content` | text blocks merged |
| `system` | `messages[0]` with `role: 'system'` | prepended |
| `max_tokens` | `max_tokens` | direct |
| `stream` | `stream` | direct |
| `tools` | `tools` | Anthropic tool → OpenAI function |

### Response: OpenAI SSE → Anthropic SSE (Streaming)

| OpenAI SSE | Anthropic SSE |
|------------|---------------|
| `data: {"choices":[{"delta":{"content":"..."}}]}` | `event: content_block_delta` → `{"type":"text_delta","text":"..."}` |
| `[DONE]` | `event: message_stop` |

## Process Priority in `process.ts`

```typescript
// 1. Translator running? → use it (highest priority)
if (isTranslatorRunning()) {
  env = { ...env, ...buildTranslatorEnv() }
}
// 2. Proxy running?
else if (proxyManager.isRunning) {
  env = { ...env, ...proxyManager.buildEnvForOpenClaude() }
}
// 3. Neither → use native API (requires real Anthropic key)
```

## WebSocket Lifecycle (Flutter → Bridge)

```
Flutter → { type: 'start_translator', payload: { baseURL, apiKey, bigModel } }
Bridge  → { type: 'translator_started', baseUrl: 'http://127.0.0.1:8090' }

Flutter → { type: 'configure_translator', payload: { ... } }
Bridge  → { type: 'translator_configured' }

Flutter → { type: 'translator_status' }
Bridge  → { type: 'translator_status', running: true, baseUrl: '...' }

Flutter → { type: 'stop_translator' }
Bridge  → { type: 'translator_stopped' }
```

## Flutter Provider

```dart
// Start translator
await ref.read(translatorProvider.notifier).start(
  TranslatorConfig.nim(apiKey: 'nvapi-...'),
);

// Check status
final ts = ref.watch(translatorProvider);
// ts.status: idle | starting | running | error
// ts.baseUrl: 'http://127.0.0.1:8090'
```

## Advantages Over Python Proxy

| | Python Proxy | Bridge-Embedded |
|--|--|--|
| Dependencies | Python + uv | **none** |
| Cold start | ~3 seconds | **instant** |
| Streaming SSE | ✅ | ✅ |
| Tool calls | ✅ | ✅ |
| Cross-platform | requires Python | **TypeScript only** |
| Hot-reload config | requires restart | ✅ `configure_translator` |
