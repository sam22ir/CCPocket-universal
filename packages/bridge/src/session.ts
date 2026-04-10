// ============================================================
// session.ts — Session Manager (OpenClaude Subprocess Mode)
// ============================================================
// يدير الجلسات ويستخدم OpenClaude كـ subprocess مع cwd=projectPath
// الوضع الاحتياطي: Direct API (إذا لم يكن openclaude متاحاً)
// بروتوكول: stdio (stream-json) أو SSE → WebSocket → Flutter
// ============================================================

import { randomUUID } from 'crypto'
import { existsSync } from 'fs'
import { resolve, normalize } from 'path'
import type { Session, ChatMessage } from './providers/base.ts'
import { getProvider } from './providers/index.ts'
import { loadConfig } from './config.ts'
import { spawnOpenClaude, type OCProcess } from './process.ts'
import type { WebSocket } from 'ws'

// ============================================================
// Managed Session
// ============================================================

interface ManagedSession {
  data:           Session
  socket:         WebSocket
  history:        ChatMessage[]
  // ── OpenClaude subprocess (وضع subprocess) ──
  ocProcess:      OCProcess | null
  // ── Fallback: Direct API (وضع احتياطي) ──
  abortController: AbortController | null
  isStreaming:    boolean
  mode:           'subprocess' | 'direct'  // الوضع النشط
}

export const sessions: Map<string, ManagedSession> = new Map()

// ─── send helper ───

function send(socket: WebSocket, payload: unknown): void {
  if (socket.readyState !== 1 /* OPEN */) return
  try {
    socket.send(JSON.stringify(payload))
  } catch (err) {
    console.error('[Session] send error:', err)
  }
}

// ─── Normalize cross-platform paths ───
function normPath(p: string): string {
  return normalize(resolve(p)).split('\\').join('/')
}

// ─── اختر الوضع المناسب ───
function detectMode(): 'subprocess' | 'direct' {
  const config = loadConfig()
  const execPath = config.openclaude?.execPath ?? 'openclaude'

  // إذا كان المسار مطلقاً وغير موجود → direct
  if (execPath !== 'openclaude' && !existsSync(execPath)) {
    console.warn(`[Session] openclaude not found at "${execPath}" → fallback to Direct API`)
    return 'direct'
  }

  return 'subprocess'
}

// ============================================================
// إنشاء جلسة
// ============================================================

export function createSession(opts: {
  projectPath: string
  providerId:  string
  modelId:     string
  socket:      WebSocket
  env:         Record<string, string>
}): Session {
  const id           = randomUUID()
  const projectPath  = normPath(opts.projectPath)
  const sessionMode  = detectMode()

  const sessionData: Session = {
    id,
    project_path: projectPath,
    title: `جلسة — ${new Date().toLocaleString('ar')}`,
    provider_id: opts.providerId,
    model_id:    opts.modelId,
    created_at:  Date.now(),
    updated_at:  Date.now(),
    status:      'idle',
    messages:    [],
  }

  // ── بناء OCProcess إذا كنا في وضع subprocess ──
  let ocProcess: OCProcess | null = null

  if (sessionMode === 'subprocess') {
    const config   = loadConfig()
    const provider = (() => { try { return getProvider(opts.providerId) } catch { return null } })()

    // متغيرات البيئة اللازمة لـ OpenClaude + Provider
    const envVars: Record<string, string> = {
      // ── OpenAI-compatible mode ──
      CLAUDE_CODE_USE_OPENAI: '1',
      OPENAI_BASE_URL:  provider?.baseURL ?? '',
      OPENAI_API_KEY:   provider?.apiKey  ?? '',
      OPENAI_MODEL:     opts.modelId,
      // ── Nvidia NIM الافتراضي ──
      NVIDIA_API_KEY:   provider?.apiKey  ?? '',
      ...opts.env,
    }

    ocProcess = spawnOpenClaude({
      execPath:    config.openclaude?.execPath ?? 'openclaude',
      projectPath,
      env:         envVars,

      onChunk: (chunk) => {
        const ms = sessions.get(id)
        if (!ms) return

        if (chunk.type === 'text' && chunk.text) {
          send(ms.socket, {
            type:       'stream_chunk',
            session_id: id,
            chunk:      chunk.text,
            timestamp:  Date.now(),
          })

        } else if (chunk.type === 'tool_use' && chunk.tool) {
          ms.data.status = 'waiting_approval'
          send(ms.socket, {
            type:       'tool_call_request',
            session_id: id,
            tool:       chunk.tool,
            timestamp:  Date.now(),
          })

        } else if (chunk.type === 'status' && (chunk.raw as Record<string,unknown>).finalEvent) {
          ms.isStreaming  = false
          ms.data.status  = 'idle'
          ms.data.updated_at = Date.now()
          send(ms.socket, {
            type:       'stream_done',
            session_id: id,
            timestamp:  Date.now(),
          })

        } else if (chunk.type === 'error') {
          ms.isStreaming = false
          ms.data.status = 'error'
          send(ms.socket, {
            type:       'error',
            session_id: id,
            message:    chunk.text ?? 'خطأ من OpenClaude',
            timestamp:  Date.now(),
          })
        }
      },

      onError: (err) => {
        const ms = sessions.get(id)
        if (!ms) return
        ms.isStreaming = false
        ms.data.status = 'error'
        console.error(`[Session][subprocess] Error (${id}): ${err}`)
        send(ms.socket, { type: 'error', session_id: id, message: err, timestamp: Date.now() })
      },

      onExit: (code) => {
        const ms = sessions.get(id)
        if (!ms) return
        ms.isStreaming = false
        ms.ocProcess   = null
        if (code !== 0) {
          ms.data.status = 'error'
          send(ms.socket, {
            type:       'error',
            session_id: id,
            message:    `OpenClaude exited with code ${code}`,
            timestamp:  Date.now(),
          })
        }
        console.log(`[Session] Subprocess exited (session: ${id}, code: ${code})`)
      },
    })

    console.log(`[Session] Created (subprocess mode): ${id} @ ${projectPath}`)
  } else {
    console.log(`[Session] Created (direct API mode): ${id} (provider: ${opts.providerId})`)
  }

  sessions.set(id, {
    data:            sessionData,
    socket:          opts.socket,
    history:         [],
    ocProcess,
    abortController: null,
    isStreaming:     false,
    mode:            sessionMode,
  })

  return sessionData
}

// ============================================================
// إرسال رسالة
// ============================================================

export function sendMessage(sessionId: string, text: string): void {
  const ms = sessions.get(sessionId)
  if (!ms) {
    console.warn(`[Session] Not found: ${sessionId}`)
    return
  }

  if (ms.isStreaming) {
    console.warn(`[Session] Already streaming: ${sessionId}`)
    return
  }

  if (text) {
    ms.history.push({ role: 'user', content: text })
  }
  ms.data.updated_at = Date.now()
  ms.data.status     = 'active'
  ms.isStreaming     = true

  // إعلام Flutter ببدء الـ stream
  send(ms.socket, { type: 'stream_start', session_id: sessionId, timestamp: Date.now() })

  if (ms.mode === 'subprocess' && ms.ocProcess?.isAlive()) {
    // ── Subprocess Mode: أرسل عبر stdin ──
    if (text) ms.ocProcess.send(text)
  } else {
    // ── Direct API Mode (Fallback) ──
    _streamDirect(ms, sessionId).catch((err) => {
      console.error(`[Session] Direct stream error (${sessionId}):`, err)
      ms.isStreaming = false
      ms.data.status = 'error'
      send(ms.socket, {
        type: 'error', session_id: sessionId,
        message: String(err), timestamp: Date.now(),
      })
    })
  }
}

// ============================================================
// Direct API Mode — Fallback (الحالي)
// TODO: يُستبدل تدريجياً بـ subprocess mode
// ============================================================

async function _streamDirect(ms: ManagedSession, sessionId: string): Promise<void> {
  ms.abortController = new AbortController()

  let provider
  try {
    provider = getProvider(ms.data.provider_id)
  } catch (err) {
    throw new Error(`Provider "${ms.data.provider_id}" not found: ${err}`)
  }

  const body = JSON.stringify({
    model:       ms.data.model_id,
    messages:    ms.history.map((m) => ({
      role: m.role,
      content: m.content,
      ...(m.tool_calls ? { tool_calls: m.tool_calls } : {}),
      ...(m.tool_call_id ? { tool_call_id: m.tool_call_id } : {}),
    })),
    stream:      true,
    temperature: 0.7,
    max_tokens:  2048,
  })

  const res = await fetch(`${provider.baseURL}/chat/completions`, {
    method:  'POST',
    headers: provider.headers(),
    body,
    signal:  ms.abortController.signal,
  })

  if (!res.ok) {
    const errText = await res.text()
    throw new Error(`API Error ${res.status}: ${errText}`)
  }

  // ── SSE Reader ──
  const reader  = res.body!.getReader()
  const decoder = new TextDecoder()
  let fullResponse = ''
  let buffer       = ''
  const pendingTools: Record<number, { id: string; name: string; args: string }> = {}

  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      buffer += decoder.decode(value, { stream: true })
      const lines = buffer.split('\n')
      buffer = lines.pop() ?? ''

      for (const line of lines) {
        const trimmed = line.trim()
        if (!trimmed || !trimmed.startsWith('data:')) continue
        const jsonStr = trimmed.slice(5).trim()
        if (jsonStr === '[DONE]') continue

        try {
          const chunk   = JSON.parse(jsonStr) as Record<string, unknown>
          const choices = chunk.choices as Array<Record<string, unknown>> | undefined
          const delta   = choices?.[0]?.delta as Record<string, unknown> | undefined

          const text = delta?.content as string | undefined
          if (text) {
            fullResponse += text
            send(ms.socket, { type: 'stream_chunk', session_id: sessionId, chunk: text, timestamp: Date.now() })
          }

          const toolCallDeltas = delta?.tool_calls as Array<Record<string, unknown>> | undefined
          if (toolCallDeltas) {
            for (const tc of toolCallDeltas) {
              const idx     = (tc.index as number) ?? 0
              const fnDelta = tc.function as Record<string, unknown> | undefined
              if (!pendingTools[idx]) {
                pendingTools[idx] = { id: (tc.id as string) ?? `tool_${idx}`, name: '', args: '' }
              }
              if (fnDelta?.name)      pendingTools[idx].name = fnDelta.name as string
              if (fnDelta?.arguments) pendingTools[idx].args += fnDelta.arguments as string
            }
          }
        } catch { /* تجاهل */ }
      }
    }
  } finally {
    reader.releaseLock()
  }

  // ── إرسال tool_calls المتراكمة ──
  for (const pt of Object.values(pendingTools)) {
    let parsedArgs: Record<string, unknown> = {}
    try { parsedArgs = JSON.parse(pt.args) } catch { parsedArgs = { raw: pt.args } }

    send(ms.socket, {
      type: 'tool_call_request', session_id: sessionId,
      tool: { id: pt.id, name: pt.name, args: parsedArgs }, timestamp: Date.now(),
    })
    ms.history.push({
      role: 'assistant',
      content: null,
      tool_calls: [{ id: pt.id, type: 'function', function: { name: pt.name, arguments: pt.args } }],
    })
  }

  ms.history.push({ role: 'assistant', content: fullResponse })
  ms.data.updated_at = Date.now()
  ms.data.status     = 'idle'
  ms.isStreaming     = false
  ms.abortController = null

  send(ms.socket, { type: 'stream_done', session_id: sessionId, timestamp: Date.now() })
}

// ============================================================
// إلغاء الـ streaming
// ============================================================

export function cancelStream(sessionId: string): void {
  const ms = sessions.get(sessionId)
  if (!ms) return

  if (ms.mode === 'subprocess' && ms.ocProcess?.isAlive()) {
    ms.ocProcess.cancel()
  } else if (ms.abortController) {
    ms.abortController.abort()
    ms.abortController = null
  }

  ms.isStreaming = false
  ms.data.status = 'idle'

  send(ms.socket, { type: 'stream_cancelled', session_id: sessionId, timestamp: Date.now() })
  console.log(`[Session] Cancelled: ${sessionId}`)
}

// ============================================================
// استئناف جلسة
// ============================================================

export function resumeSession(sessionId: string, socket: WebSocket): Session | null {
  const ms = sessions.get(sessionId)
  if (!ms) return null
  ms.socket = socket
  console.log(`[Session] Resumed: ${sessionId}`)
  return ms.data
}

// ============================================================
// حذف جلسة
// ============================================================

export function deleteSession(sessionId: string): void {
  const ms = sessions.get(sessionId)
  if (!ms) return
  ms.ocProcess?.kill()
  ms.abortController?.abort()
  sessions.delete(sessionId)
  console.log(`[Session] Deleted: ${sessionId}`)
}

// ============================================================
// معالجة انقطاع الـ Socket
// ============================================================

export function handleSocketDisconnect(socket: WebSocket): void {
  for (const [id, ms] of sessions.entries()) {
    if (ms.socket !== socket) continue
    console.log(`[Session] Socket disconnected: ${id}`)
    if (ms.isStreaming) {
      ms.ocProcess?.cancel()
      ms.abortController?.abort()
      ms.isStreaming = false
      ms.data.status = 'idle'
    }
  }
}

// ============================================================
// استعلامات
// ============================================================

export function getSession(sessionId: string): Session | null {
  return sessions.get(sessionId)?.data ?? null
}

export function listSessions(): Session[] {
  return [...sessions.values()].map((ms) => ms.data)
}
