# Provider Guide

## Supported Provider Paths

The bridge supports two provider families.

### 1. Built-in providers

Configured in `packages/bridge/bridge.config.json` under `providers`:

- `nvidia-nim`
- `openai`
- `gemini`
- `anthropic`
- `ollama`

These are loaded by `packages/bridge/src/providers/index.ts`.

### 2. Custom OpenAI-compatible providers

Configured in `bridge.config.json` under `customProviders`.

Each custom provider needs:

```json
{
  "name": "Provider Name",
  "baseURL": "https://example.com/v1",
  "apiKey": "sk-...",
  "models": [
    {
      "id": "model-id",
      "name": "Display Name",
      "contextWindow": 32768,
      "supportsFunctions": true
    }
  ]
}
```

## Registry Implementation

The current codebase does not use separate provider files for every provider. Instead it uses:

- `providers/nvidia-nim.ts` for built-in provider constructors
- `providers/openai-compatible.ts` for the generic adapter
- `providers/index.ts` for registry initialization, lookup, and validation

## Validation Flow

`validateProvider()` in `providers/index.ts` does two checks:

- `GET /models` for connectivity and auth
- `POST /chat/completions` smoke test for model/API compatibility

This is what powers provider validation in the bridge protocol.

## Proxy vs Translator

There are two separate compatibility layers in the product.

### Proxy

- Managed by `proxy.ts`
- Launches `free-claude-code`
- Best when the user wants an external Anthropic-compatible local proxy

### Embedded Translator

- Managed by `translator.ts`
- Runs inside the bridge process
- Best when the user wants fewer external dependencies and faster startup

## Security Note

`bridge.config.json` is a local machine config file and may contain API keys. Treat it as secret material.

Recommended practices:

- do not commit real keys
- rotate keys if they were shared accidentally
- prefer platform-secure storage on the mobile side for user-entered secrets
