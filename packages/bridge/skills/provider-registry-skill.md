# Provider Registry Pattern

A self-registering provider architecture for CCPocket Bridge that allows adding new AI providers without modifying core Bridge code.

## Problem

How do you add support for a new AI provider (Groq, Together, Modal, DeepSeek) without touching the Bridge's core logic?

## Solution: Self-Registering Provider Registry

```
bridge.config.json
      ↓ loadConfig()
initProviders()   → registers each provider into the Registry
      ↓
listProviders()   → returns list to Flutter UI
getProvider(id)   → returns instance for session creation
```

## Registry Structure

```typescript
// packages/bridge/src/providers/index.ts

interface Provider {
  id:           string
  name:         string
  models:       ModelInfo[]
  capabilities: string[]
  buildEnv(apiKey: string): Record<string, string>
  validate(baseURL: string, apiKey: string, modelId: string): Promise<ValidationResult>
}

const registry = new Map<string, Provider>()

export function register(provider: Provider): void {
  registry.set(provider.id, provider)
}

export function listProviders(): Provider[] {
  return [...registry.values()]
}

export function getProvider(id: string): Provider | undefined {
  return registry.get(id)
}
```

## Adding a New Provider (3 Steps)

### Step 1: Create provider file

```typescript
// packages/bridge/src/providers/groq.ts
import type { Provider } from './index.ts'

export const groqProvider: Provider = {
  id:   'groq',
  name: 'Groq',
  models: [
    { id: 'llama-3.3-70b-versatile', name: 'Llama 3.3 70B', contextWindow: 128000 },
    { id: 'mixtral-8x7b-32768',      name: 'Mixtral 8x7B',  contextWindow: 32768  },
  ],
  capabilities: ['streaming', 'tool_use'],

  buildEnv(apiKey) {
    return { GROQ_API_KEY: apiKey }
  },

  async validate(baseURL, apiKey, modelId) {
    const res = await fetch(`${baseURL}/openai/v1/models`, {
      headers: { Authorization: `Bearer ${apiKey}` }
    })
    if (!res.ok) return { success: false, step: 'connectivity', message: res.statusText }
    return { success: true, step: 'done', message: 'Groq connected ✓' }
  }
}
```

### Step 2: Register in `initProviders()`

```typescript
import { groqProvider } from './groq.ts'

export function initProviders(): void {
  register(nvidiaProvider)
  register(openAIProvider)
  register(ollamaProvider)
  register(groqProvider)   // ← add here only
}
```

### Step 3: Add API key in `bridge.config.json`

```json
{
  "providers": {
    "groq": { "apiKey": "gsk_..." }
  }
}
```

## Pattern Properties

| Property | Description |
|----------|-------------|
| **Zero coupling** | Each provider is a standalone file |
| **Hot-add** | Custom providers from config at runtime |
| **3-step validation** | connectivity → chat → stream |
| **Flutter-transparent** | Flutter only sees `id` and `models` |

## Custom Providers (Runtime — No Code Required)

```json
{
  "customProviders": {
    "my-local": {
      "name":    "LM Studio Local",
      "baseURL": "http://localhost:1234/v1",
      "apiKey":  "lm-studio",
      "models":  [{ "id": "loaded-model", "name": "Current Model" }]
    }
  }
}
```

Auto-registered via `openai-compatible.ts` adapter during `initProviders()`.

## 3-Step Validation Flow

```
Step 1: GET {baseURL}/models          → 200 OK? ✓ reachable
Step 2: POST /chat/completions        → choices[0]? ✓ model responds
Step 3: POST /chat/completions stream → first SSE chunk? ✓ streaming works
```

## Flutter Integration

```dart
// List providers (from Bridge registry)
bridge.sendMap({ 'type': 'list_providers' });
// ← response: { type: 'providers_list', providers: [...] }

// Validate and add custom provider
bridge.sendMap({
  'type': 'validate_provider',
  'payload': { 'baseURL': '...', 'apiKey': '...', 'modelId': '...' },
});
// ← response: { type: 'provider_validation_result', success: true }
```

## Community Sharing

This skill is part of **CCPocket Bridge Skills** — shareable patterns for:
- VoltAgent community skills
- awesome-agent-skills repository
- Any Bridge using the WebSocket → OpenClaude subprocess pattern
