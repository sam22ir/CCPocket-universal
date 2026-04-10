# Bridge API Protocol

## Transport

The mobile app talks to the bridge over WebSocket using JSON messages.

Default local URL:

```text
ws://localhost:8765
```

## Common Message Shape

Typical request shape:

```json
{
  "type": "message_type",
  "session_id": "optional-session-id",
  "payload": {}
}
```

Typical bridge event shape:

```json
{
  "type": "event_type",
  "session_id": "optional-session-id",
  "timestamp": 1710000000000
}
```

## Session Messages

Client to bridge:

- `create_session`
- `send_message`
- `cancel_stream`
- `delete_session`
- `resume_session`
- `get_session`
- `list_sessions`
- `tool_approve`
- `tool_reject`

Bridge to client:

- `session_created`
- `stream_start`
- `stream_chunk`
- `stream_done`
- `stream_cancelled`
- `tool_call_request`
- `tool_ack`
- `error`

## Project Messages

Client to bridge:

- `create_project`
- `link_project`
- `list_projects`
- `delete_project`
- `update_project_instructions`

Bridge to client:

- `project_created`
- `project_linked`
- `projects_list`
- `project_deleted`
- `project_updated`

## Provider And Connection Messages

Client to bridge:

- `ping`
- `list_providers`
- `validate_provider`

Bridge to client:

- `pong`
- `providers_list`
- `provider_validation_result`

## Proxy Messages

Client to bridge:

- `start_proxy`
- `proxy_status`
- `stop_proxy`

Bridge to client:

- `proxy_started`
- `proxy_status`
- `proxy_stopped`

## Translator Messages

Client to bridge:

- `start_translator`
- `configure_translator`
- `translator_status`
- `stop_translator`

Bridge to client:

- `translator_started`
- `translator_configured`
- `translator_status`
- `translator_stopped`

## Tailscale Messages

Client to bridge:

- `tailscale_status`

Bridge to client:

- `tailscale_status`

Payload fields currently used by the mobile app:

- `enabled`
- `tailscaleIp`
- `port`
- `wsUrl`

## Notes

- The current Flutter client also has higher-level helpers in `websocket_service.dart` that wrap several of these raw message types.
- The protocol is defined by the bridge implementation in `packages/bridge/src/server.ts`, so that file is the runtime source of truth when docs and code differ.
