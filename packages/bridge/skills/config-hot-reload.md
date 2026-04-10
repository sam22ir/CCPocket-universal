# Config Hot-Reload

Dynamic configuration updates for the Bridge — change providers, models, and API keys at runtime without restarting the server.

## Problem

Most agent bridges assume static configuration at startup.  
CCPocket needs to switch providers and models **during an active chat** without dropping the WebSocket connection.

## Solution: Config Layer + Live Registry Mutation

```
Flutter → { type: 'provider_switch', provider_id, model_id }
           ↓
Bridge: getProvider(id) → fetches from in-memory Registry
           ↓
Registry updated without restart
           ↓
New sessions use the new provider
Existing sessions continue with their original provider
```

## `bridge.config.json` Schema

```typescript
interface BridgeConfig {
  bridge: {
    host:         string    // default: '0.0.0.0'
    port:         number    // default: 8765
    tailscaleIp?: string    // optional Tailscale IP
  }
  openclaude: {
    execPath: string        // path to openclaude CLI
    baseDir:  string        // default projects directory
  }
  providers: {
    [id: string]: {
      apiKey?:  string
      baseURL?: string
    }
  }
  customProviders?: {
    [id: string]: {
      name:    string
      baseURL: string
      apiKey:  string
      models:  Array<{ id: string; name: string }>
    }
  }
  activeProvider?: string
  activeModel?:   string
}
```

## Example `bridge.config.json`

```json
{
  "bridge": { "host": "0.0.0.0", "port": 8765 },
  "openclaude": {
    "execPath": "openclaude",
    "baseDir":  "~/ccpocket-projects"
  },
  "providers": {
    "nvidia-nim": { "apiKey": "nvapi-..." },
    "openai":     { "apiKey": "sk-..." },
    "ollama":     { "baseURL": "http://localhost:11434/v1" }
  },
  "customProviders": {
    "deepseek": {
      "name":    "DeepSeek",
      "baseURL": "https://api.deepseek.com/v1",
      "apiKey":  "sk-...",
      "models":  [{ "id": "deepseek-chat", "name": "DeepSeek V3" }]
    }
  }
}
```

## Runtime Updates from Flutter

```dart
// Validate and register a new custom provider
bridge.sendMap({
  'type': 'validate_provider',
  'payload': {
    'baseURL': 'https://api.deepseek.com/v1',
    'apiKey':  'sk-...',
    'modelId': 'deepseek-chat',
  },
});
// After success: auto-added to Registry

// Hot-reconfigure Translator (no restart needed)
await ref.read(translatorProvider.notifier).configure(
  TranslatorConfig.nim(apiKey: newKey),
);
```

## API Keys Security Rules

| Rule | Implementation |
|------|---------------|
| Never logged | Bridge redacts keys from stderr |
| Never sent to Flutter | Flutter sends `provider_id` only |
| Stored in Keychain | `flutter_secure_storage` / Platform Keychain |
| `bridge.config.json` permissions | `chmod 600` on Linux/macOS |
| Subprocess isolation | Child process gets filtered env copy |

## Flutter Secure Storage

```dart
// Save API key for a provider
await ref.read(secureStorageProvider).saveApiKey('nvidia-nim', 'nvapi-...');

// Read it back
final key = await ref.read(secureStorageProvider).getApiKey('nvidia-nim');

// List all saved providers
final saved = await ref.read(secureStorageProvider).listSavedProviders();
// → { 'nvidia-nim': true, 'openai': false }
```

Keys stored in:
- **iOS**: Keychain with `first_unlock_this_device` accessibility
- **Android**: Jetpack Security encrypted storage (auto-migrated in v11+)

## Translator Hot-Configure

```dart
// Update translator config while it's running
// Takes effect immediately for new requests
await ref.read(translatorProvider.notifier).configure(
  TranslatorConfig(
    baseURL:  'https://api.openrouter.ai/v1',
    apiKey:   'sk-or-...',
    bigModel: 'anthropic/claude-3.5-sonnet',
  ),
);
```

The Bridge applies the new config without interrupting existing sessions.
