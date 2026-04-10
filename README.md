# CCPocket Universal

Mobile-first client for running an OpenClaude-style coding assistant through a local TypeScript bridge.

## Repo Layout

- `apps/mobile`: Flutter app
- `packages/bridge`: TypeScript bridge server
- `docs/`: architecture, provider guide, and bridge protocol notes

## What It Does

- manages local projects and sessions
- connects Flutter to a local WebSocket bridge
- runs OpenClaude in a project working directory
- supports direct OpenAI-compatible providers
- supports both an external proxy and an embedded translator
- exposes provider, translator, proxy, and tailscale status in the app

## Quick Start

### 1. Bridge

```bash
cd packages/bridge
npm install
```

Create a local config file from the example:

```bash
copy bridge.config.example.json bridge.config.json
```

Then edit `bridge.config.json` and add your own keys.

Start the bridge:

```bash
npm run dev
```

### 2. Mobile App

```bash
cd apps/mobile
flutter pub get
flutter run
```

## Verification

Useful local checks:

```bash
cd apps/mobile
flutter analyze --no-pub

cd ..\..\packages\bridge
.\node_modules\.bin\tsc.cmd --noEmit --pretty false --allowImportingTsExtensions --module nodenext --moduleResolution nodenext --target es2022 --lib es2022,dom --types node --skipLibCheck src/server.ts src/process.ts src/translator.ts src/proxy.ts src/project.ts src/session.ts src/index.ts src/config.ts src/providers/index.ts src/providers/nvidia-nim.ts src/providers/openai-compatible.ts src/providers/base.ts
```

## Local Secrets

- `packages/bridge/bridge.config.json` is local-only and gitignored
- use `packages/bridge/bridge.config.example.json` as the public template
- do not commit real API keys or tokens

If a real key was ever stored in a tracked or shared file, rotate it before publishing the repository.

## Docs

- `docs/architecture.md`
- `docs/provider-guide.md`
- `docs/api-protocol.md`
