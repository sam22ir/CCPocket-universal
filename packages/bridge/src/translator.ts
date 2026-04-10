// ============================================================
// translator.ts — Bridge-Embedded Anthropic Messages API
// ============================================================
// يُنفّذ /v1/messages endpoint بـ TypeScript خالص
// يترجم Anthropic format ↔ OpenAI format
// ويُشغّل HTTP server مستقل داخل نفس الـ Bridge process
// ── لا Python، لا subprocess، لا uv ──
// ============================================================

import http from 'http'

// ============================================================
// الأنواع
// ============================================================

export interface TranslatorConfig {
  /** عنوان الـ OpenAI-compatible provider (NIM, OpenRouter, Ollama…) */
  baseURL: string
  /** مفتاح الـ API للمزود */
  apiKey: string
  /** النموذج الكبير (claude-sonnet → BIG_MODEL) */
  bigModel: string
  /** النموذج الصغير (claude-haiku → SMALL_MODEL) */
  smallModel?: string
}

interface AnthropicMessage {
  role: 'user' | 'assistant'
  content: string | AnthropicContentBlock[]
}

interface AnthropicContentBlock {
  type: 'text' | 'tool_use' | 'tool_result' | 'image'
  text?: string
  id?: string
  name?: string
  input?: unknown
  content?: string | AnthropicContentBlock[]
  tool_use_id?: string
}

interface AnthropicTool {
  name: string
  description?: string
  input_schema: {
    type: 'object'
    properties: Record<string, unknown>
    required?: string[]
  }
}

interface AnthropicRequest {
  model: string
  messages: AnthropicMessage[]
  system?: string
  max_tokens?: number
  stream?: boolean
  tools?: AnthropicTool[]
  temperature?: number
  top_p?: number
}

interface OpenAIMessage {
  role: 'system' | 'user' | 'assistant' | 'tool'
  content: string | null
  tool_calls?: OpenAIToolCall[]
  tool_call_id?: string
  name?: string
}

interface OpenAIToolCall {
  id: string
  type: 'function'
  function: {
    name: string
    arguments: string
  }
}

interface OpenAIRequest {
  model: string
  messages: OpenAIMessage[]
  max_tokens?: number
  stream?: boolean
  tools?: OpenAITool[]
  temperature?: number
  top_p?: number
}

interface OpenAITool {
  type: 'function'
  function: {
    name: string
    description?: string
    parameters: unknown
  }
}

// ============================================================
// خوارزمية ترجمة Request: Anthropic → OpenAI
// ============================================================

export function anthropicToOpenAI(body: AnthropicRequest, config: TranslatorConfig): OpenAIRequest {
  const openAIMessages: OpenAIMessage[] = []

  // 1. system prompt → أول رسالة بـ role:system
  if (body.system) {
    openAIMessages.push({ role: 'system', content: body.system })
  }

  // 2. ترجمة المحادثة
  for (const msg of body.messages) {
    const content = extractTextContent(msg.content)
    const toolCalls = extractToolCalls(msg.content)
    const toolResults = extractToolResults(msg.content)

    if (toolResults.length > 0) {
      // tool_result → رسائل tool منفصلة
      for (const result of toolResults) {
        openAIMessages.push({
          role: 'tool',
          content: extractTextContent(result.content ?? ''),
          tool_call_id: result.tool_use_id ?? '',
        })
      }
    } else if (toolCalls.length > 0 && msg.role === 'assistant') {
      // tool_use → assistant message مع tool_calls
      openAIMessages.push({
        role: 'assistant',
        content: content || null,
        tool_calls: toolCalls.map((tc) => ({
          id: tc.id ?? `call_${Date.now()}`,
          type: 'function' as const,
          function: {
            name: tc.name ?? '',
            arguments: JSON.stringify(tc.input ?? {}),
          },
        })),
      })
    } else {
      openAIMessages.push({
        role: msg.role === 'user' ? 'user' : 'assistant',
        content: content,
      })
    }
  }

  // 3. ترجمة النموذج (claude-* → BIG/SMALL model)
  const model = mapModel(body.model, config)

  // 4. ترجمة الأدوات
  const tools: OpenAITool[] | undefined = body.tools?.map((t) => ({
    type: 'function' as const,
    function: {
      name: t.name,
      description: t.description,
      parameters: t.input_schema,
    },
  }))

  return {
    model,
    messages: openAIMessages,
    max_tokens: body.max_tokens ?? 4096,
    stream: body.stream ?? false,
    temperature: body.temperature,
    top_p: body.top_p,
    ...(tools && tools.length > 0 ? { tools } : {}),
  }
}

// ============================================================
// خوارزمية ترجمة Response: OpenAI → Anthropic
// ============================================================

export function openAIToAnthropic(data: Record<string, unknown>): Record<string, unknown> {
  const choice = (data.choices as Record<string, unknown>[])?.[0]
  if (!choice) {
    return {
      id: `msg_${Date.now()}`,
      type: 'message',
      role: 'assistant',
      content: [{ type: 'text', text: '' }],
      model: data.model ?? 'unknown',
      stop_reason: 'end_turn',
      usage: translateUsage(data.usage as Record<string, number> | undefined),
    }
  }

  const message = choice.message as Record<string, unknown>
  const content: AnthropicContentBlock[] = []

  // نص عادي
  if (message?.content) {
    content.push({ type: 'text', text: String(message.content) })
  }

  // tool calls
  const toolCalls = message?.tool_calls as OpenAIToolCall[] | undefined
  if (toolCalls) {
    for (const tc of toolCalls) {
      let parsedInput: unknown = {}
      try {
        parsedInput = JSON.parse(tc.function.arguments)
      } catch {
        parsedInput = { raw: tc.function.arguments }
      }
      content.push({
        type: 'tool_use',
        id: tc.id,
        name: tc.function.name,
        input: parsedInput,
      })
    }
  }

  const finishReason = choice.finish_reason as string
  const stopReason =
    finishReason === 'tool_calls' ? 'tool_use' :
    finishReason === 'stop'       ? 'end_turn'  : 'end_turn'

  return {
    id:         `msg_${Date.now()}`,
    type:       'message',
    role:       'assistant',
    content,
    model:      data.model ?? 'unknown',
    stop_reason: stopReason,
    usage:      translateUsage(data.usage as Record<string, number> | undefined),
  }
}

// ============================================================
// ترجمة الـ Streaming SSE: OpenAI chunks → Anthropic SSE events
// ============================================================

export async function* translateStream(
  openAIStream: AsyncIterable<Buffer>,
): AsyncGenerator<string> {
  // إرسال message_start
  yield `event: message_start\ndata: ${JSON.stringify({
    type: 'message_start',
    message: {
      id: `msg_${Date.now()}`,
      type: 'message',
      role: 'assistant',
      content: [],
      model: 'translated',
      usage: { input_tokens: 0, output_tokens: 0 },
    },
  })}\n\n`

  // الـ content block index
  let blockIdx = 0
  let blockOpen = false
  let isToolCall = false
  const toolCallBuffers = new Map<number, { id: string; name: string; args: string }>()

  let buffer = ''

  for await (const chunk of openAIStream) {
    buffer += chunk.toString('utf-8')
    const lines = buffer.split('\n')
    buffer = lines.pop() ?? ''        // احتفظ بالسطر غير المكتمل

    for (const line of lines) {
      const trimmed = line.trim()
      if (!trimmed.startsWith('data: ')) continue
      const raw = trimmed.slice(6).trim()
      if (raw === '[DONE]') {
        // أغلق الـ block المفتوح
        if (blockOpen) {
          yield `event: content_block_stop\ndata: ${JSON.stringify({ type: 'content_block_stop', index: blockIdx })}\n\n`
          blockIdx++
          blockOpen = false
        }
        // أرسل message_delta + message_stop
        yield `event: message_delta\ndata: ${JSON.stringify({ type: 'message_delta', delta: { stop_reason: 'end_turn', stop_sequence: null }, usage: { output_tokens: 0 } })}\n\n`
        yield `event: message_stop\ndata: ${JSON.stringify({ type: 'message_stop' })}\n\n`
        continue
      }

      let parsed: Record<string, unknown>
      try { parsed = JSON.parse(raw) } catch { continue }

      const choice = (parsed.choices as Record<string, unknown>[])?.[0]
      if (!choice) continue

      const delta = choice.delta as Record<string, unknown>
      if (!delta) continue

      // ── نص عادي ──
      if (delta.content && typeof delta.content === 'string') {
        if (!blockOpen || isToolCall) {
          if (blockOpen) {
            yield `event: content_block_stop\ndata: ${JSON.stringify({ type: 'content_block_stop', index: blockIdx })}\n\n`
            blockIdx++
          }
          yield `event: content_block_start\ndata: ${JSON.stringify({ type: 'content_block_start', index: blockIdx, content_block: { type: 'text', text: '' } })}\n\n`
          blockOpen = true
          isToolCall = false
        }
        yield `event: content_block_delta\ndata: ${JSON.stringify({ type: 'content_block_delta', index: blockIdx, delta: { type: 'text_delta', text: delta.content } })}\n\n`
      }

      // ── tool calls streaming ──
      const toolCallDeltas = delta.tool_calls as OpenAIToolCall[] | undefined
      if (toolCallDeltas) {
        for (const tc of toolCallDeltas) {
          const idx = (tc as unknown as { index?: number }).index ?? 0
          if (!toolCallBuffers.has(idx)) {
            if (blockOpen && !isToolCall) {
              yield `event: content_block_stop\ndata: ${JSON.stringify({ type: 'content_block_stop', index: blockIdx })}\n\n`
              blockIdx++
            }
            toolCallBuffers.set(idx, { id: tc.id ?? '', name: tc.function?.name ?? '', args: '' })
            yield `event: content_block_start\ndata: ${JSON.stringify({
              type: 'content_block_start',
              index: blockIdx + idx,
              content_block: { type: 'tool_use', id: tc.id, name: tc.function?.name, input: {} },
            })}\n\n`
            blockOpen = true
            isToolCall = true
          }
          const buf = toolCallBuffers.get(idx)!
          if (tc.function?.arguments) {
            buf.args += tc.function.arguments
            yield `event: content_block_delta\ndata: ${JSON.stringify({
              type: 'content_block_delta',
              index: blockIdx + idx,
              delta: { type: 'input_json_delta', partial_json: tc.function.arguments },
            })}\n\n`
          }
        }
      }

      // ── finish_reason ──
      const finishReason = choice.finish_reason as string | undefined
      if (finishReason && finishReason !== 'null') {
        if (blockOpen) {
          yield `event: content_block_stop\ndata: ${JSON.stringify({ type: 'content_block_stop', index: blockIdx })}\n\n`
          blockOpen = false
        }
        const stopReason = finishReason === 'tool_calls' ? 'tool_use' : 'end_turn'
        yield `event: message_delta\ndata: ${JSON.stringify({ type: 'message_delta', delta: { stop_reason: stopReason, stop_sequence: null }, usage: { output_tokens: 0 } })}\n\n`
        yield `event: message_stop\ndata: ${JSON.stringify({ type: 'message_stop' })}\n\n`
      }
    }
  }
}

// ============================================================
// HTTP Server — يُنفّذ Anthropic Messages API
// ============================================================

/** الكونفوغريشن الحالية للمترجم — تُحدَّث عبر configure() */
let _config: TranslatorConfig | null = null
let _server: http.Server | null = null
let _port = 0

/** تحديث الإعدادات بدون إعادة تشغيل */
export function configureTranslator(config: TranslatorConfig): void {
  _config = config
  console.log(`[Translator] Configured → ${config.baseURL} model: ${config.bigModel}`)
}

/** إرجاع متغيرات البيئة لتمريرها لـ OpenClaude */
export function buildTranslatorEnv(): Record<string, string> {
  if (!_server || !_port) return {}
  return {
    ANTHROPIC_BASE_URL:   `http://127.0.0.1:${_port}`,
    ANTHROPIC_AUTH_TOKEN: 'bridge-embedded',   // قيمة وهمية — لا تُرسل للـ provider
    ANTHROPIC_API_KEY:    'bridge-embedded',
  }
}

/** هل الـ HTTP server يعمل؟ */
export function isTranslatorRunning(): boolean {
  return _server !== null && _port > 0
}

/** الـ URL الكامل للـ translator */
export function translatorBaseUrl(): string {
  return _port > 0 ? `http://127.0.0.1:${_port}` : ''
}

/**
 * تشغيل الـ HTTP server على منفذ حر
 * يعود فوراً — مع الـ URL
 */
export function startTranslator(config: TranslatorConfig, preferredPort = 0): Promise<string> {
  _config = config

  return new Promise((resolve, reject) => {
    if (_server) {
      // يعمل مسبقاً — حدّث الإعدادات فقط
      _config = config
      console.log('[Translator] Config updated (server already running)')
      resolve(translatorBaseUrl())
      return
    }

    _server = http.createServer(handleRequest)

    _server.listen(preferredPort, '127.0.0.1', () => {
      const addr = _server!.address() as { port: number }
      _port = addr.port
      console.log(`[Translator] HTTP server listening on http://127.0.0.1:${_port}`)
      resolve(`http://127.0.0.1:${_port}`)
    })

    _server.on('error', (err) => {
      _server = null
      _port = 0
      reject(err)
    })
  })
}

/** إيقاف الـ HTTP server */
export function stopTranslator(): void {
  if (!_server) return
  _server.close(() => console.log('[Translator] HTTP server stopped'))
  _server = null
  _port = 0
  _config = null
}

// ============================================================
// معالج الطلبات HTTP
// ============================================================

function handleRequest(req: http.IncomingMessage, res: http.ServerResponse): void {
  const url = req.url ?? '/'

  // health check
  if (req.method === 'GET' && (url === '/health' || url === '/')) {
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ status: 'ok', translator: 'bridge-embedded' }))
    return
  }

  // Anthropic Messages API
  if (req.method === 'POST' && url === '/v1/messages') {
    handleMessages(req, res).catch((err) => {
      console.error('[Translator] Request error:', err)
      if (!res.headersSent) {
        res.writeHead(500, { 'Content-Type': 'application/json' })
        res.end(JSON.stringify({ error: { message: String(err), type: 'server_error' } }))
      }
    })
    return
  }

  // مسار غير معروف
  res.writeHead(404, { 'Content-Type': 'application/json' })
  res.end(JSON.stringify({ error: 'Not found' }))
}

async function handleMessages(
  req: http.IncomingMessage,
  res: http.ServerResponse,
): Promise<void> {
  if (!_config) {
    res.writeHead(503, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ error: { message: 'Translator not configured', type: 'server_error' } }))
    return
  }

  // اقرأ body الطلب
  const body = await readBody(req)
  let anthropicReq: AnthropicRequest
  try {
    anthropicReq = JSON.parse(body) as AnthropicRequest
  } catch {
    res.writeHead(400, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ error: { message: 'Invalid JSON', type: 'invalid_request_error' } }))
    return
  }

  const isStream = anthropicReq.stream === true

  // ترجمة إلى OpenAI format
  const openAIReq = anthropicToOpenAI(anthropicReq, _config)

  // أرسل للـ provider
  const providerUrl = `${_config.baseURL.replace(/\/$/, '')}/chat/completions`
  const providerResp = await fetch(providerUrl, {
    method: 'POST',
    headers: {
      'Content-Type':  'application/json',
      'Authorization': `Bearer ${_config.apiKey}`,
      'Accept':        isStream ? 'text/event-stream' : 'application/json',
    },
    body: JSON.stringify(openAIReq),
  })

  if (!providerResp.ok) {
    const err = await providerResp.text()
    console.error(`[Translator] Provider error ${providerResp.status}:`, err)
    res.writeHead(providerResp.status, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({
      error: { message: `Provider error: ${err}`, type: 'api_error' },
    }))
    return
  }

  if (isStream) {
    // ── Streaming ──
    res.writeHead(200, {
      'Content-Type':      'text/event-stream',
      'Cache-Control':     'no-cache',
      'Connection':        'keep-alive',
      'X-Accel-Buffering': 'no',
    })

    if (!providerResp.body) {
      res.end()
      return
    }

    // ترجم وأرسل كل chunk
    for await (const event of translateStream(nodeReadable(providerResp.body))) {
      if (!res.writable) break
      res.write(event)
    }
    res.end()
  } else {
    // ── Non-streaming ──
    const data = await providerResp.json() as Record<string, unknown>
    const translated = openAIToAnthropic(data)

    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify(translated))
  }
}

// ============================================================
// مساعدات
// ============================================================

function readBody(req: http.IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let data = ''
    req.on('data', (chunk) => { data += chunk.toString() })
    req.on('end',   () => resolve(data))
    req.on('error', reject)
  })
}

/** تحويل Web ReadableStream → AsyncIterable<Buffer> لـ Node.js */
async function* nodeReadable(
  webStream: ReadableStream<Uint8Array>,
): AsyncIterable<Buffer> {
  const reader = webStream.getReader()
  try {
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      yield Buffer.from(value)
    }
  } finally {
    reader.releaseLock()
  }
}

function extractTextContent(
  content: string | AnthropicContentBlock[],
): string {
  if (typeof content === 'string') return content
  return content
    .filter((b) => b.type === 'text' && b.text)
    .map((b) => b.text!)
    .join('')
}

function extractToolCalls(
  content: string | AnthropicContentBlock[],
): AnthropicContentBlock[] {
  if (typeof content === 'string') return []
  return content.filter((b) => b.type === 'tool_use')
}

function extractToolResults(
  content: string | AnthropicContentBlock[],
): AnthropicContentBlock[] {
  if (typeof content === 'string') return []
  return content.filter((b) => b.type === 'tool_result')
}

function mapModel(
  anthropicModel: string,
  config: TranslatorConfig,
): string {
  // claude-3-haiku / claude-haiku → SMALL_MODEL
  if (anthropicModel.includes('haiku')) {
    return config.smallModel ?? config.bigModel
  }
  // claude-3-opus / claude-3-7-sonnet / claude-sonnet → BIG_MODEL
  return config.bigModel
}

function translateUsage(
  usage: Record<string, number> | undefined,
): Record<string, number> {
  if (!usage) return { input_tokens: 0, output_tokens: 0 }
  return {
    input_tokens:  usage.prompt_tokens     ?? 0,
    output_tokens: usage.completion_tokens ?? 0,
  }
}
