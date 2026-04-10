# CCPocket Universal Architecture

## Overview

`CCPocket Universal` is split into two runtimes:

- `apps/mobile`: Flutter mobile client
- `packages/bridge`: TypeScript bridge server

Runtime flow:

```text
Flutter app
  -> WebSocket JSON messages
Bridge server
  -> OpenClaude subprocess with cwd=project path
  -> or direct OpenAI-compatible HTTP calls
  -> or embedded Anthropic-to-OpenAI translator
```

## Mobile App

The Flutter app is organized by feature rather than the older `screens/services/models/widgets` layout used in planning docs.

Current top-level structure:

```text
apps/mobile/lib/
  core/
    providers/
    router/
    services/
    theme/
  features/
    chat/
    projects/
    sessions/
    settings/
```

Key responsibilities:

- `core/services/websocket_service.dart`: bridge transport with reconnect backoff
- `core/services/storage_service.dart`: local Hive persistence for projects, sessions, and messages
- `core/providers/*`: bridge connection, settings, providers, proxy, translator, tailscale state
- `features/projects/*`: project list and creation UX
- `features/sessions/*`: session list scoped to a project or global history
- `features/chat/*`: chat view, tool approval flow, message rendering
- `features/settings/*`: provider selection, bridge status, proxy status, translator status, tailscale status

## Bridge Server

`packages/bridge/src/` contains the active bridge implementation.

Important files:

- `server.ts`: WebSocket entrypoint and message handlers
- `session.ts`: session lifecycle, history, subprocess/direct fallback routing
- `process.ts`: OpenClaude subprocess spawn and NDJSON parsing
- `project.ts`: bridge-side project persistence and `CLAUDE.md` management
- `proxy.ts`: `free-claude-code` subprocess management
- `translator.ts`: embedded Anthropic Messages API translator
- `providers/index.ts`: provider registry and validation

## Persistence Model

Project persistence is currently duplicated by design:

- Flutter stores local project metadata in Hive for fast offline UI access
- Bridge stores project metadata in `~/.ccpocket/projects.json` and owns filesystem actions like creating folders and writing `CLAUDE.md`

This means the app does not yet have a strict single source of truth for projects. The current behavior works, but future sync work should either:

- make Bridge authoritative and hydrate Flutter from Bridge, or
- keep Flutter authoritative and reduce Bridge persistence to filesystem-only operations

## Runtime Modes

The bridge can operate in three effective modes:

- Native OpenClaude subprocess mode
- Direct provider API fallback mode
- Translator-first mode where OpenClaude targets the embedded translator via `ANTHROPIC_BASE_URL`

Priority in the current implementation:

- translator env
- proxy env
- native provider env

## Current Verification State

At the time this document was updated:

- Flutter: analyzer clean except for non-critical lints already tracked during cleanup
- Bridge: TypeScript compile passes
- Full device E2E remains separate from static verification
