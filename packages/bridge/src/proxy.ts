// ============================================================
// proxy.ts — ProxyManager
// يشغّل free-claude-code كـ subprocess ويمرر ANTHROPIC_BASE_URL
// ============================================================
// المرجع: https://github.com/Alishahryar1/free-claude-code
//
// الإعداد:
//   uv tool install git+https://github.com/Alishahryar1/free-claude-code.git
//
// يستمع على PORT عشوائي ويوفر ANTHROPIC_BASE_URL لـ process.ts
// ============================================================

import { spawn, ChildProcess } from 'child_process'
import { createServer }        from 'net'

// ── البحث عن port حر ──────────────────────────────────────

function findFreePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const srv = createServer()
    srv.listen(0, '127.0.0.1', () => {
      const addr = srv.address()
      const port = typeof addr === 'object' && addr ? addr.port : 0
      srv.close((err) => { if (err) reject(err); else resolve(port) })
    })
    srv.on('error', reject)
  })
}

// ── ProxyConfig ──────────────────────────────────────────────

export interface ProxyConfig {
  /** NVIDIA_NIM_API_KEY أو OPENROUTER_API_KEY حسب الـ provider */
  apiKey:    string
  /** النموذج بصيغة free-claude-code: nvidia_nim/model أو open_router/model */
  model:     string
  /**
   * provider prefix يحدد المتغير البيئي المطلوب:
   *   'nvidia_nim'  → NVIDIA_NIM_API_KEY
   *   'open_router' → OPENROUTER_API_KEY
   *   'lmstudio'    → لا يحتاج key
   *   'llamacpp'    → لا يحتاج key + LLAMACPP_BASE_URL
   */
  provider:  'nvidia_nim' | 'open_router' | 'lmstudio' | 'llamacpp'
  llamacppBaseUrl?: string
}

// ── ProxyManager ─────────────────────────────────────────────

export class ProxyManager {
  private _proc:    ChildProcess | null = null
  private _port:    number = 0
  private _baseUrl: string = ''
  private _started: boolean = false
  private _authToken: string = 'ccpocket-bridge'

  get baseUrl()  { return this._baseUrl  }
  get authToken() { return this._authToken }
  get isRunning() { return this._started   }

  // ── start ────────────────────────────────────────────────

  async start(config: ProxyConfig): Promise<void> {
    if (this._started) {
      console.log('[Proxy] Already running at', this._baseUrl)
      return
    }

    this._port    = await findFreePort()
    this._baseUrl = `http://127.0.0.1:${this._port}`

    // ── بناء env vars حسب الـ provider ──────────────────────
    const proxyEnv: Record<string, string> = {
      ...process.env as Record<string, string>,
      PORT:              String(this._port),
      HOST:              '127.0.0.1',
      // الـ model mapping: نضع نفس الموديل للـ opus/sonnet/haiku
      MODEL:             config.model,
      MODEL_OPUS:        config.model,
      MODEL_SONNET:      config.model,
      MODEL_HAIKU:       config.model,
      // Authentication token يمرره Bridge لاحقاً لـ OpenClaude
      ANTHROPIC_AUTH_TOKEN: this._authToken,
    }

    // أضف API key للـ provider المناسب
    switch (config.provider) {
      case 'nvidia_nim':
        proxyEnv['NVIDIA_NIM_API_KEY']  = config.apiKey
        proxyEnv['NIM_ENABLE_THINKING'] = 'false'
        break
      case 'open_router':
        proxyEnv['OPENROUTER_API_KEY'] = config.apiKey
        break
      case 'llamacpp':
        proxyEnv['LLAMACPP_BASE_URL'] = config.llamacppBaseUrl ?? 'http://localhost:8080/v1'
        break
      case 'lmstudio':
        // لا يحتاج API key
        break
    }

    console.log(`[Proxy] Starting free-claude-code on port ${this._port} (provider: ${config.provider})`)

    // ── تشغيل الـ proxy ───────────────────────────────────────
    // يدعم: `uv run uvicorn server:app` من مجلد free-claude-code
    // أو:    `free-claude-code` إذا كان مثبتاً كـ uv tool
    this._proc = spawn(
      'free-claude-code',
      [],
      {
        env:   proxyEnv,
        stdio: ['ignore', 'pipe', 'pipe'],
        // shell لازم على Windows للـ uv tool commands
        shell: process.platform === 'win32',
      }
    )

    this._proc.stdout?.on('data', (d: Buffer) => {
      process.stdout.write(`[Proxy] ${d.toString()}`)
    })
    this._proc.stderr?.on('data', (d: Buffer) => {
      process.stderr.write(`[Proxy] ERR: ${d.toString()}`)
    })
    this._proc.on('exit', (code) => {
      console.warn(`[Proxy] Process exited with code ${code}`)
      this._started = false
      this._proc    = null
    })

    // انتظر حتى يستجيب الـ proxy
    await this._waitReady()
    this._started = true
    console.log(`[Proxy] ✅ Ready at ${this._baseUrl}`)
  }

  // ── waitReady: polling حتى يكون الـ proxy جاهزاً ──────────

  private async _waitReady(timeoutMs = 15_000): Promise<void> {
    const deadline = Date.now() + timeoutMs
    while (Date.now() < deadline) {
      try {
        const res = await fetch(`${this._baseUrl}/health`)
        if (res.ok) return
      } catch {
        // لم يبدأ بعد — انتظر
      }
      await new Promise(r => setTimeout(r, 500))
    }
    throw new Error(`[Proxy] Timeout: لم يبدأ free-claude-code في ${timeoutMs}ms`)
  }

  // ── stop ─────────────────────────────────────────────────

  stop(): void {
    if (this._proc) {
      this._proc.kill('SIGTERM')
      this._proc    = null
      this._started = false
      console.log('[Proxy] Stopped')
    }
  }

  // ── buildEnvForOpenClaude ─────────────────────────────────
  // يُستخدم في process.ts عند spawn OpenClaude

  buildEnvForOpenClaude(): Record<string, string> {
    if (!this._started) {
      // Proxy لم يبدأ — أعد env فارغ + تحذير
      console.warn('[Proxy] buildEnvForOpenClaude called before proxy is ready!')
      return {}
    }
    return {
      ANTHROPIC_BASE_URL:   this._baseUrl,
      ANTHROPIC_API_KEY:    'dummy',          // مطلوب لـ Claude Code CLI لكن لا يُستخدم
      ANTHROPIC_AUTH_TOKEN: this._authToken,
    }
  }
}

// ── Singleton ────────────────────────────────────────────────

export const proxyManager = new ProxyManager()
