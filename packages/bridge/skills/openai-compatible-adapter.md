# OpenAI-Compatible Provider Adapter

A generic adapter pattern for registering any OpenAI-compatible provider in the Bridge registry without writing provider-specific code.

## Problem

Every new OpenAI-compatible provider (DeepSeek, Groq, Together, Modal, LM Studio) would normally require a dedicated provider file. This adapter eliminates that need.

## Solution

```typescript
// openai-compatible.ts
export function openaiCompatible(config: OpenAICompatibleConfig): Provider
```

Provide `baseURL + apiKey + models` — get a fully registered provider.

## Config Schema

```typescript
interface OpenAICompatibleConfig {
  id:       string
  name:     string
  baseURL:  string
  models:   Array<{ id: string; name: string; contextWindow?: number }>
  capabilities?: string[]   // default: ['streaming', 'tool_use']
}
```

## Usage in `bridge.config.json`

```json
{
  "customProviders": {
    "deepseek": {
      "name":    "DeepSeek",
      "baseURL": "https://api.deepseek.com/v1",
      "apiKey":  "sk-...",
      "models":  [{ "id": "deepseek-chat", "name": "DeepSeek V3" }]
    },
    "local-lmstudio": {
      "name":    "LM Studio",
      "baseURL": "http://localhost:1234/v1",
      "apiKey":  "lm-studio",
      "models":  [{ "id": "local-model", "name": "Current Model" }]
    },
    "together": {
      "name":    "Together AI",
      "baseURL": "https://api.together.xyz/v1",
      "apiKey":  "togetherai-...",
      "models":  [{ "id": "mistralai/Mixtral-8x7B-Instruct-v0.1", "name": "Mixtral 8x7B" }]
    }
  }
}
```

All custom providers are auto-registered during `initProviders()`.

## Relationship with `translator.ts`

| `openai-compatible.ts` | `translator.ts` |
|----------------------|----------------|
| Registry metadata | Protocol proxy |
| Used directly by Bridge | Used by Claude Code CLI |
| Provider identity & model list | Anthropic ↔ OpenAI translation |

**Both are required** — they serve distinct roles.

## Runtime Provider Validation (3 Steps)

```typescript
validateProvider(baseURL, apiKey, modelId)

// Step 1: GET /v1/models → 200 OK
// Step 2: POST /v1/chat/completions (non-stream, max_tokens: 5) → choices[0]
// Step 3: (optional) POST with stream: true → first SSE chunk
```

## Adding a Provider from Flutter at Runtime

```dart
// Flutter → Bridge: validate
bridge.sendMap({
  'type': 'validate_provider',
  'payload': {
    'baseURL':  'https://api.deepseek.com/v1',
    'apiKey':   'sk-...',
    'modelId':  'deepseek-chat',
  },
});

// Bridge → Flutter: result
// { type: 'provider_validation_result', success: true, step: 'done' }
```

## Supported Providers (Tested)

| Provider | Base URL |
|----------|----------|
| NVIDIA NIM | `https://integrate.api.nvidia.com/v1` |
| OpenRouter | `https://openrouter.ai/api/v1` |
| Together AI | `https://api.together.xyz/v1` |
| DeepSeek | `https://api.deepseek.com/v1` |
| Groq | `https://api.groq.com/openai/v1` |
| Ollama | `http://localhost:11434/v1` |
| LM Studio | `http://localhost:1234/v1` |
| LlamaCPP | `http://localhost:8080/v1` |
