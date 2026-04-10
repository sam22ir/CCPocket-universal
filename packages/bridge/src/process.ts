// ============================================================
// process.ts — OpenClaude Subprocess Management
// ============================================================
// يدير دورة حياة OpenClaude CLI كـ subprocess عبر stdio
// بروتوكول: --output-format stream-json --input-format stream-json --verbose
// ============================================================

import { spawn, type ChildProcess } from 'child_process'
import { createInterface }          from 'readline'
import { randomUUID }               from 'crypto'
import { proxyManager }             from './proxy.ts'
import { buildTranslatorEnv, isTranslatorRunning } from './translator.ts'

export interface OCProcessOptions {
  execPath:    string                          // مسار openclaude
  projectPath: string                          // مسار المشروع → يُمرَّر كـ cwd
  sessionId?:  string                          // UUID → --session-id للاستئناف
  env:         Record<string, string>          // متغيرات البيئة للـ provider
  onChunk: (chunk: OCChunk) => void
  onError: (err: string) => void
  onExit: (code: number | null) => void
}

export type OCChunkType =
  | 'text'          // نص من المساعد
  | 'tool_use'      // طلب استخدام tool
  | 'tool_result'   // نتيجة tool
  | 'error'         // خطأ
  | 'status'        // init / done
  | 'thinking'      // تفكير (إذا كان مفعلاً)

export interface OCChunk {
  type: OCChunkType
  raw: Record<string, unknown>
  text?: string
  tool?: { id: string; name: string; args: unknown }
}

export interface OCProcess {
  pid: number
  send: (userMessage: string) => void
  cancel: () => void
  kill: () => void
  isAlive: () => boolean
}

// ============================================================
// spawn OpenClaude كـ subprocess
// ============================================================

export function spawnOpenClaude(opts: OCProcessOptions): OCProcess {
  const {
    execPath,
    projectPath,
    sessionId,
    env,
    onChunk,
    onError,
    onExit,
  } = opts

  let _isAlive = false
  let _child: ChildProcess | null = null

  // الأعلام المؤكدة من مصدر OpenClaude CLI
  const args = [
    '--output-format', 'stream-json',
    '--input-format',  'stream-json',
    '--verbose',
    '--include-partial-messages',
    '--dangerously-skip-permissions',
    // ── استئناف جلسة موجودة إن وُجد session-id ──
    ...(sessionId ? ['--session-id', sessionId] : ['-p', '--print']),
  ]

  try {
    _child = spawn(execPath, args, {
      cwd: projectPath,
      env: {
        ...process.env,
        ...env,
        // ── Proxy env: ANTHROPIC_BASE_URL عبر Python proxy (free-claude-code) ──
        // يُستخدم فقط إذا كان الـ translator المدمج غير نشط
        ...(!isTranslatorRunning() ? proxyManager.buildEnvForOpenClaude() : {}),
        // ── Translator env: ANTHROPIC_BASE_URL → Bridge HTTP server (TypeScript) ──
        // يأخذ الأولوية على الـ proxy إذا كان يعمل
        ...(isTranslatorRunning() ? buildTranslatorEnv() : {}),
        // ── حفاظ على CWD حتى لو Claude نفّذ cd
        CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR: '1',
        FORCE_COLOR: '0',
        NO_COLOR:    '1',
      },
      stdio: ['pipe', 'pipe', 'pipe'],
    })

    _isAlive = true
    console.log(`[Process] Spawned OpenClaude (pid: ${_child.pid}) at ${projectPath}`)
  } catch (err) {
    onError(`فشل تشغيل OpenClaude: ${String(err)}`)
    return _deadProcess()
  }

  const child = _child!

  // ============================================================
  // قراءة stdout كـ NDJSON line by line
  // ============================================================
  const rl = createInterface({ input: child.stdout! })

  rl.on('line', (line: string) => {
    const trimmed = line.trim()
    if (!trimmed || !trimmed.startsWith('{')) return

    try {
      const json = JSON.parse(trimmed) as Record<string, unknown>
      const chunk = parseOCChunk(json)
      if (chunk) onChunk(chunk)
    } catch {
      // تجاهل سطور غير JSON (مثل تحذيرات)
    }
  })

  // ============================================================
  // stderr — سجل أخطاء فقط
  // ============================================================
  child.stderr?.on('data', (data: Buffer) => {
    const text = data.toString('utf-8').trim()
    if (text) {
      console.error(`[Process][stderr] ${text}`)
      // لا نرسل كل رسائل stderr لـ Flutter — فقط الحرجة
      if (text.includes('Error:') || text.includes('FATAL')) {
        onError(text)
      }
    }
  })

  // ============================================================
  // إنهاء العملية — مع Auto-Recovery عند الانهيار المفاجئ
  // ============================================================
  let _lastUserMessage = ''   // نحتفظ بآخر رسالة للاستئناف

  child.on('exit', (code) => {
    _isAlive = false
    console.log(`[Process] OpenClaude exited (code: ${code})`)

    if (code !== 0 && code !== null) {
      // ── انهيار غير طبيعي — أبلغ Flutter ثم أعد المحاولة بعد 1.5s ──
      console.warn(`[Process] Unexpected exit (code: ${code}) — auto-recovering in 1.5s`)
      onError(`⚠️ OpenClaude انهار (كود: ${code}) — جاري الإعادة التلقائية...`)

      setTimeout(() => {
        if (_lastUserMessage) {
          // TODO: في session.ts يمكن استخدام onExit لإعادة تشغيل spawnOpenClaude
          console.log('[Process] Auto-recovery: caller should respawn with last message')
        }
        onExit(code)
      }, 1500)
    } else {
      // إنهاء طبيعي
      onExit(code)
    }
  })

  child.on('error', (err) => {
    _isAlive = false
    onError(`OpenClaude process error: ${err.message}`)
  })

  // ============================================================
  // API المكشوفة للـ session
  // ============================================================
  return {
    pid: child.pid!,

    // إرسال رسالة للمستخدم عبر stdin (NDJSON)
    send: (userMessage: string) => {
      if (!_isAlive || !child.stdin) return
      _lastUserMessage = userMessage   // للـ auto-recovery
      const line = JSON.stringify({ type: 'user', message: { role: 'user', content: userMessage } })
      child.stdin.write(line + '\n')
    },

    // إلغاء الـ stream الحالي (SIGINT)
    cancel: () => {
      if (!_isAlive || !child.stdin) return
      // إرسال Ctrl+C كـ character عبر stdin
      child.stdin.write(JSON.stringify({ type: 'user', message: { role: 'user', content: '\x03' } }) + '\n')
      console.log(`[Process] Sent cancel signal to pid ${child.pid}`)
    },

    // إنهاء العملية نهائياً
    kill: () => {
      if (!_isAlive) return
      _isAlive = false
      child.stdin?.end()
      child.kill('SIGTERM')
      // إذا لم تُغلق خلال 3 ثواني: SIGKILL
      const timer = setTimeout(() => {
        if (!child.killed) {
          child.kill('SIGKILL')
          console.warn(`[Process] Force killed pid ${child.pid}`)
        }
      }, 3000)
      child.once('exit', () => clearTimeout(timer))
    },

    isAlive: () => _isAlive,
  }
}

// ============================================================
// تحليل chunk من OpenClaude NDJSON
// ============================================================

function parseOCChunk(json: Record<string, unknown>): OCChunk | null {
  const type = json.type as string | undefined

  // رسائل stream-json من OpenClaude
  switch (type) {
    case 'content_block_delta': {
      const delta = json.delta as Record<string, unknown> | undefined
      const text = delta?.text as string | undefined
      if (text) return { type: 'text', raw: json, text }
      return null
    }

    case 'content_block_start': {
      const block = json.content_block as Record<string, unknown> | undefined
      if (block?.type === 'tool_use') {
        return {
          type: 'tool_use',
          raw: json,
          tool: {
            id: block.id as string ?? randomUUID(),
            name: block.name as string ?? 'unknown',
            args: {},
          },
        }
      }
      return null
    }

    case 'message_start':
    case 'message_delta':
      return { type: 'status', raw: json }

    case 'message_stop':
      return { type: 'status', raw: { ...json, finalEvent: true } }

    case 'error': {
      const errMsg = (json.error as Record<string, unknown>)?.message as string ?? String(json)
      return { type: 'error', raw: json, text: errMsg }
    }

    default:
      return null
  }
}

// ============================================================
// نسخة ميتة — لحالات الفشل
// ============================================================

function _deadProcess(): OCProcess {
  return {
    pid: -1,
    send: () => {},
    cancel: () => {},
    kill: () => {},
    isAlive: () => false,
  }
}
