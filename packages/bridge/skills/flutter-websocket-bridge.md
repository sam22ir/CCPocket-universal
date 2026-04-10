# Flutter ↔ Bridge WebSocket Protocol

Complete reference for the JSON message protocol between the Flutter app and the Bridge WebSocket server.

## Architecture

```
Flutter App
  ↕ WebSocket  ws://localhost:8765  (JSON messages)
Bridge Server (Bun/Node.js)
  ↕ stdio NDJSON
OpenClaude CLI
```

## Message Shape

```json
{ "type": "message_type", "session_id": "uuid", "payload": {...}, "timestamp": 1234567890 }
```

- `type` — message type (always required)
- `session_id` — session UUID (required for session messages)
- `payload` — additional data (optional, can be merged into root)
- `timestamp` — Unix ms (Bridge includes it; Flutter reads it)

---

## Flutter → Bridge Messages

### Session Management

| Type | Required Fields | Description |
|------|----------------|-------------|
| `create_session` | `projectPath`, `providerId`, `modelId` | Create new session |
| `send_message` | `session_id`, `content` | Send user message |
| `cancel_stream` | `session_id` | Cancel active stream |
| `resume_session` | `session_id` | Reconnect to existing session |
| `delete_session` | `session_id` | Delete session |
| `list_sessions` | — | List all sessions |
| `get_session` | `session_id` | Get session details |

### Project Management

| Type | Required Fields | Description |
|------|----------------|-------------|
| `create_project` | `name`, `path?`, `description?`, `instructions?` | Create project + directory |
| `link_project` | `path`, `name` | Link existing directory |
| `list_projects` | — | List all projects |
| `delete_project` | `project_id` | Remove from list (files untouched) |
| `update_project_instructions` | `project_id`, `instructions` | Update CLAUDE.md |

### Provider Management

| Type | Required Fields | Description |
|------|----------------|-------------|
| `list_providers` | — | List providers from Registry |
| `validate_provider` | `baseURL`, `apiKey`, `modelId` | 3-step validation |

### Translator (Bridge-Embedded)

| Type | Required Fields | Description |
|------|----------------|-------------|
| `start_translator` | `baseURL`, `apiKey`, `bigModel` | Start HTTP translator |
| `configure_translator` | `baseURL`, `apiKey`, `bigModel` | Hot-update config |
| `translator_status` | — | Query translator state |
| `stop_translator` | — | Stop translator |

### Proxy (Python — legacy)

| Type | Fields | Description |
|------|--------|-------------|
| `start_proxy` | `provider`, `apiKey`, `model` | Start Python proxy |
| `proxy_status` | — | Query proxy state |
| `stop_proxy` | — | Stop proxy |

### Tool Approval

| Type | Fields | Description |
|------|--------|-------------|
| `tool_approve` | `session_id`, `tool_id` | Approve tool execution |
| `tool_reject` | `session_id`, `tool_id` | Reject tool execution |

### Infrastructure

| Type | Description |
|------|-------------|
| `ping` | Check connectivity |
| `tailscale_status` | Query Tailscale IP and wsUrl |

---

## Bridge → Flutter Messages

### Session Events

| Type | Fields |
|------|--------|
| `session_created` | `session` object |
| `text` | `session_id`, `chunk_data`, `timestamp` |
| `tool_call` | `session_id`, `tool_name`, `args`, `tool_id` |
| `tool_result` | `session_id`, `tool_id`, `result` |
| `status` | `session_id`, `status: done\|thinking\|error` |
| `stream_cancelled` | `session_id` |
| `session_deleted` | `session_id` |
| `session_info` | `session` object |
| `sessions_list` | `sessions[]` |
| `tool_ack` | `tool_id`, `status: approved\|rejected` |

### Project Events

| Type | Fields |
|------|--------|
| `project_created` | `project` object |
| `project_linked` | `project` object |
| `projects_list` | `projects[]` |
| `project_deleted` | `project_id`, `success` |
| `project_updated` | `project` object |

### System Events

| Type | Fields |
|------|--------|
| `connected` | `message`, `timestamp` |
| `pong` | `timestamp` |
| `providers_list` | `providers[]` |
| `provider_validation_result` | `success`, `step`, `message` |
| `translator_started` | `baseUrl` |
| `translator_configured` | — |
| `translator_status` | `running`, `baseUrl` |
| `translator_stopped` | — |
| `proxy_started` | `baseUrl` |
| `proxy_status` | `running`, `baseUrl` |
| `proxy_stopped` | — |
| `tailscale_status` | `enabled`, `tailscaleIp`, `port`, `wsUrl` |
| `error` | `message`, `code?` |

---

## Flutter `WebSocketService` API

```dart
// Connect (auto-reconnect with exponential backoff)
service.connect()

// Send helpers
service.sendMap({'type': 'ping'})
service.send(BridgeMessage(type: '...', payload: {...}))
service.sendRaw({'type': 'list_sessions'})   // no debug log

// Await specific response
final result = await service.nextMessage(
  (msg) => msg['type'] == 'project_created',
);

// Streams
service.messages          // Stream<BridgeMessage>
service.connectionState   // Stream<ConnectionState>
service.state             // ConnectionState (sync getter)
```

## Auto-Reconnect: Exponential Backoff

```
Attempt 1: wait 2s
Attempt 2: wait 4s
Attempt 3: wait 8s
Attempt 4: wait 16s
Attempt 5+: wait 30s (cap)

On successful connect: counter resets to 0
```

## Tailscale Remote Access

```bash
# Set env var before starting Bridge
TAILSCALE_IP=100.x.x.x bun run start

# Bridge logs:
# [Server] 🌐 Tailscale enabled — accessible at:
# [Server]    ws://100.x.x.x:8765

# Flutter on another device connects to:
ws://100.x.x.x:8765
```
