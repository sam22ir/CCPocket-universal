// ============================================================
// server.ts — Bridge WebSocket Server
// ============================================================
// نقطة الدخول — يستقبل اتصالات Flutter ويوجهها
// ============================================================

import { WebSocketServer, WebSocket } from 'ws'
import { loadConfig }                 from './config.ts'
import { initProviders, listProviders, validateProvider } from './providers/index.ts'
import {
  createSession,
  sendMessage,
  cancelStream,
  deleteSession,
  handleSocketDisconnect,
  resumeSession,
  getSession,
  listSessions,
  sessions,
} from './session.ts'
import { proxyManager, type ProxyConfig }  from './proxy.ts'
import {
  startTranslator,
  stopTranslator,
  configureTranslator,
  isTranslatorRunning,
  translatorBaseUrl,
  type TranslatorConfig,
} from './translator.ts'
import { projectManager } from './project.ts'

// ============================================================
// نوع رسائل WebSocket (من Flutter إلى Bridge)
// ============================================================

interface FlutterMessage {
  type: string
  session_id?: string
  payload?: Record<string, unknown>
}

// ============================================================
// بدء السيرفر
// ============================================================

export function startServer(): void {
  const config = loadConfig()
  initProviders()

  // ── Tailscale Integration ──
  // إذا كان TAILSCALE_IP مُعيَّناً، يُضاف log لعنوان الوصول عبر Tailnet
  const tailscaleIp = process.env['TAILSCALE_IP'] ?? config.bridge.tailscaleIp
  if (tailscaleIp) {
    console.log(`[Server] 🌐 Tailscale enabled — accessible from other devices at:`)
    console.log(`[Server]    ws://${tailscaleIp}:${config.bridge.port}`)
    console.log(`[Server]    (Set TAILSCALE_IP=<your-tailscale-ip> to update)`)
  }

  // Bridge يستمع على 0.0.0.0 ← يشمل Tailscale IP و LAN تلقائياً
  const wss = new WebSocketServer({
    host: config.bridge.host,   // '0.0.0.0' ← يستمع على كل interfaces بما فيها Tailscale
    port: config.bridge.port,
    handleProtocols: (_protocols, _req) => false,
    verifyClient: (_info, cb) => cb(true),
  })

  const listenAddr = tailscaleIp
    ? `ws://localhost:${config.bridge.port} + ws://${tailscaleIp}:${config.bridge.port}`
    : `ws://${config.bridge.host}:${config.bridge.port}`

  console.log(`[Server] Bridge started on ${listenAddr}`)

  wss.on('connection', (socket: WebSocket, req) => {
    const clientIp = req.socket.remoteAddress ?? 'unknown'
    console.log(`[Server] New connection from ${clientIp}`)

    // إرسال ping فوري للتأكيد
    send(socket, { type: 'connected', message: 'Bridge ready', timestamp: Date.now() })

    socket.on('message', (data) => {
      let msg: FlutterMessage

      try {
        msg = JSON.parse(data.toString()) as FlutterMessage
      } catch {
        send(socket, { type: 'error', message: 'Invalid JSON', timestamp: Date.now() })
        return
      }

      handleMessage(socket, msg).catch((err) => {
        console.error('[Server] Handler error:', err)
        send(socket, {
          type: 'error',
          session_id: msg.session_id,
          message: String(err),
          timestamp: Date.now(),
        })
      })
    })

    socket.on('close', () => {
      console.log(`[Server] Client disconnected: ${clientIp}`)
      handleSocketDisconnect(socket)
    })

    socket.on('error', (err) => {
      console.error(`[Server] Socket error:`, err)
    })
  })

  // Graceful shutdown — أوقف الـ proxy والـ translator أيضاً
  process.on('SIGINT',  () => { proxyManager.stop(); stopTranslator(); shutdown(wss) })
  process.on('SIGTERM', () => { proxyManager.stop(); stopTranslator(); shutdown(wss) })
}

// ============================================================
// معالجة الرسائل
// ============================================================

async function handleMessage(socket: WebSocket, msg: FlutterMessage): Promise<void> {
  console.log(`[Server] ← ${msg.type}`, msg.session_id ? `(${msg.session_id.slice(0, 8)}...)` : '')

  switch (msg.type) {

    // ── حالة الـ Bridge
    case 'ping': {
      send(socket, { type: 'pong', timestamp: Date.now() })
      break
    }

    // ── Tailscale Status ──
    case 'tailscale_status': {
      const cfg         = loadConfig()
      const tailscaleIp = process.env['TAILSCALE_IP'] ?? cfg.bridge.tailscaleIp ?? null
      send(socket, {
        type:        'tailscale_status',
        enabled:     !!tailscaleIp,
        tailscaleIp: tailscaleIp,
        port:        cfg.bridge.port,
        wsUrl:       tailscaleIp ? `ws://${tailscaleIp}:${cfg.bridge.port}` : null,
        timestamp:   Date.now(),
      })
      break
    }

    // ── قائمة المزودين
    case 'list_providers': {
      const providers = listProviders().map((p) => ({
        id: p.id,
        name: p.name,
        models: p.models,
        capabilities: p.capabilities,
      }))
      send(socket, { type: 'providers_list', providers, timestamp: Date.now() })
      break
    }

    // ── التحقق من مزود مخصص
    case 'validate_provider': {
      const { baseURL, apiKey, modelId } = msg.payload as { baseURL: string; apiKey: string; modelId: string }
      const result = await validateProvider(baseURL, apiKey, modelId)
      send(socket, { type: 'provider_validation_result', ...result, timestamp: Date.now() })
      break
    }

    // ── تشغيل الـ proxy (free-claude-code) ──
    case 'start_proxy': {
      const src = (msg.payload ?? {}) as Record<string, unknown>
      const proxyConfig: ProxyConfig = {
        provider:  (src.provider  ?? 'nvidia_nim') as ProxyConfig['provider'],
        apiKey:    (src.apiKey    ?? src.api_key ?? '') as string,
        model:     (src.model     ?? 'nvidia_nim/meta/llama-3.3-70b-instruct') as string,
        llamacppBaseUrl: src.llamacppBaseUrl as string | undefined,
      }
      try {
        await proxyManager.start(proxyConfig)
        send(socket, {
          type:     'proxy_started',
          baseUrl:  proxyManager.baseUrl,
          timestamp: Date.now(),
        })
      } catch (err) {
        send(socket, {
          type:    'error',
          message: `فشل تشغيل الـ proxy: ${String(err)}`,
          timestamp: Date.now(),
        })
      }
      break
    }

    // ── حالة الـ proxy ──
    case 'proxy_status': {
      send(socket, {
        type:      'proxy_status',
        running:   proxyManager.isRunning,
        baseUrl:   proxyManager.baseUrl,
        timestamp: Date.now(),
      })
      break
    }

    // ── إيقاف الـ proxy ──
    case 'stop_proxy': {
      proxyManager.stop()
      send(socket, { type: 'proxy_stopped', timestamp: Date.now() })
      break
    }

    // ================================================================
    // Bridge-Embedded Anthropic Translator (TypeScript — لا Python)
    // ================================================================

    // ── تشغيل الـ translator المدمج ──
    case 'start_translator': {
      const src = (msg.payload ?? {}) as Record<string, unknown>
      const translatorConfig: TranslatorConfig = {
        baseURL:    (src.baseURL    ?? src.base_url   ?? 'https://integrate.api.nvidia.com/v1') as string,
        apiKey:     (src.apiKey     ?? src.api_key    ?? '') as string,
        bigModel:   (src.bigModel   ?? src.big_model  ?? 'meta/llama-3.3-70b-instruct') as string,
        smallModel: (src.smallModel ?? src.small_model ?? undefined) as string | undefined,
      }
      try {
        const url = await startTranslator(translatorConfig)
        send(socket, {
          type:      'translator_started',
          baseUrl:   url,
          timestamp: Date.now(),
        })
      } catch (err) {
        send(socket, {
          type:    'error',
          message: `فشل تشغيل الـ translator: ${String(err)}`,
          timestamp: Date.now(),
        })
      }
      break
    }

    // ── تحديث إعدادات الـ translator (بدون إعادة تشغيل) ──
    case 'configure_translator': {
      const src = (msg.payload ?? {}) as Record<string, unknown>
      configureTranslator({
        baseURL:    (src.baseURL    ?? src.base_url   ?? '') as string,
        apiKey:     (src.apiKey     ?? src.api_key    ?? '') as string,
        bigModel:   (src.bigModel   ?? src.big_model  ?? '') as string,
        smallModel: (src.smallModel ?? src.small_model ?? undefined) as string | undefined,
      })
      send(socket, { type: 'translator_configured', timestamp: Date.now() })
      break
    }

    // ── حالة الـ translator ──
    case 'translator_status': {
      send(socket, {
        type:      'translator_status',
        running:   isTranslatorRunning(),
        baseUrl:   translatorBaseUrl(),
        timestamp: Date.now(),
      })
      break
    }

    // ── إيقاف الـ translator ──
    case 'stop_translator': {
      stopTranslator()
      send(socket, { type: 'translator_stopped', timestamp: Date.now() })
      break
    }

    // ── إنشاء جلسة جديدة
    case 'create_session': {
      // Flutter قد يرسل الحقول مباشرةً أو داخل payload
      const src = (msg.payload ?? msg) as Record<string, unknown>

      const projectPath = (src.projectPath ?? src.project_path ?? '.') as string
      const providerId = (src.providerId ?? src.provider ?? 'nvidia-nim') as string
      const modelId = (src.modelId ?? src.model ?? 'meta/llama-3.3-70b-instruct') as string
      const env = (src.env ?? {}) as Record<string, string>

      const session = createSession({ projectPath, providerId, modelId, socket, env })
      send(socket, { type: 'session_created', session, timestamp: Date.now() })
      break
    }

    // ── قائمة الجلسات
    case 'list_sessions': {
      const sessions = listSessions()
      send(socket, { type: 'sessions_list', sessions, timestamp: Date.now() })
      break
    }

    // ── استئناف جلسة
    case 'resume_session': {
      if (!msg.session_id) throw new Error('session_id مطلوب')
      const session = resumeSession(msg.session_id, socket)
      if (!session) {
        send(socket, { type: 'error', message: `Session ${msg.session_id} غير موجودة`, timestamp: Date.now() })
      }
      break
    }

    // ── إرسال رسالة
    case 'send_message': {
      if (!msg.session_id) throw new Error('session_id مطلوب')
      const src = (msg.payload ?? msg) as Record<string, unknown>
      const text = ((src.content ?? src.text ?? '') as string).trim()
      if (!text) throw new Error('المحتوى فارغ')
      sendMessage(msg.session_id, text)
      break
    }

    // ── إلغاء الـ streaming
    case 'cancel_stream': {
      if (!msg.session_id) throw new Error('session_id مطلوب')
      cancelStream(msg.session_id)
      break
    }

    // ── حذف جلسة
    case 'delete_session': {
      if (!msg.session_id) throw new Error('session_id مطلوب')
      deleteSession(msg.session_id)
      send(socket, { type: 'session_deleted', session_id: msg.session_id, timestamp: Date.now() })
      break
    }

    // ── الرد على tool approval (من المستخدم) ──
    case 'tool_approve': {
      if (!msg.session_id) throw new Error('session_id مطلوب')
      const payload = (msg.payload ?? {}) as Record<string, unknown>
      const toolId = payload.tool_id as string ?? ''

      // أضف نتيجة الأداة للـ history (نتيجة وهمية — يمكن توسيعها لاحقاً)
      const toolResultMsg = {
        role: 'tool' as const,
        content: JSON.stringify({ status: 'success', message: 'Tool executed successfully' }),
        tool_call_id: toolId,
      }
      const msSession = sessions.get(msg.session_id)
      if (msSession) {
        msSession.history.push(toolResultMsg as Parameters<typeof msSession.history.push>[0])
        // استئناف المحادثة بعد تنفيذ الأداة
        sendMessage(msg.session_id, '')
      }
      send(socket, { type: 'tool_ack', status: 'approved', tool_id: toolId, timestamp: Date.now() })
      break
    }

    case 'tool_reject': {
      if (!msg.session_id) throw new Error('session_id مطلوب')
      const payload = (msg.payload ?? {}) as Record<string, unknown>
      const toolId = payload.tool_id as string ?? ''
      send(socket, { type: 'tool_ack', status: 'rejected', tool_id: toolId, timestamp: Date.now() })
      break
    }

    // ── معرفة حالة جلسة
    case 'get_session': {
      if (!msg.session_id) throw new Error('session_id مطلوب')
      const session = getSession(msg.session_id)
      send(socket, { type: 'session_info', session, timestamp: Date.now() })
      break
    }

    // ── إنشاء مشروع جديد ──
    case 'create_project': {
      const src = (msg.payload ?? msg) as Record<string, unknown>
      try {
        const project = projectManager.create({
          name:         String(src.name ?? 'Untitled'),
          path:         src.path         ? String(src.path)         : undefined,
          description:  src.description  ? String(src.description)  : undefined,
          instructions: src.instructions ? String(src.instructions) : undefined,
        })
        send(socket, { type: 'project_created', project, timestamp: Date.now() })
      } catch (err) {
        send(socket, { type: 'error', message: String(err), timestamp: Date.now() })
      }
      break
    }

    // ── ربط مجلد موجود ──
    case 'link_project': {
      const src = (msg.payload ?? msg) as Record<string, unknown>
      try {
        const project = projectManager.link({
          path:         String(src.path ?? ''),
          name:         String(src.name ?? ''),
          description:  src.description  ? String(src.description)  : undefined,
          instructions: src.instructions ? String(src.instructions) : undefined,
        })
        send(socket, { type: 'project_linked', project, timestamp: Date.now() })
      } catch (err) {
        send(socket, { type: 'error', message: String(err), timestamp: Date.now() })
      }
      break
    }

    // ── قائمة المشاريع ──
    case 'list_projects': {
      const projects = projectManager.list()
      send(socket, { type: 'projects_list', projects, timestamp: Date.now() })
      break
    }

    // ── حذف مشروع (من القائمة فقط، لا يحذف الملفات) ──
    case 'delete_project': {
      const src = (msg.payload ?? msg) as Record<string, unknown>
      const projectId = String(src.project_id ?? '')
      const removed = projectManager.remove(projectId)
      send(socket, { type: 'project_deleted', project_id: projectId, success: removed, timestamp: Date.now() })
      break
    }

    // ── تحديث CLAUDE.md ──
    case 'update_project_instructions': {
      const src = (msg.payload ?? msg) as Record<string, unknown>
      const projectId    = String(src.project_id ?? '')
      const instructions = String(src.instructions ?? '')
      try {
        const project = projectManager.updateInstructions(projectId, instructions)
        send(socket, { type: 'project_updated', project, timestamp: Date.now() })
      } catch (err) {
        send(socket, { type: 'error', message: String(err), timestamp: Date.now() })
      }
      break
    }

    default: {
      console.warn(`[Server] Unknown message type: ${msg.type}`)
      send(socket, { type: 'error', message: `نوع رسالة غير معروف: ${msg.type}`, timestamp: Date.now() })
    }
  }
}

// ============================================================
// مساعدات
// ============================================================

function send(socket: WebSocket, payload: unknown): void {
  if (socket.readyState !== WebSocket.OPEN) return
  try {
    socket.send(JSON.stringify(payload))
  } catch (err) {
    console.error('[Server] send error:', err)
  }
}

function shutdown(wss: WebSocketServer): void {
  console.log('[Server] Shutting down...')
  wss.close(() => {
    console.log('[Server] Closed.')
    process.exit(0)
  })
}

// ============================================================
// Start
// ============================================================

startServer()
