// ============================================================
// base.ts — Provider Interface (العقد الأساسي لكل مزود)
// ============================================================

export interface Provider {
  id: string
  name: string
  baseURL: string
  apiKey: string
  models: Model[]
  capabilities: ProviderCapabilities
  headers: () => Record<string, string>
  formatRequest: (messages: ChatMessage[]) => unknown
  formatResponse: (raw: unknown) => StreamChunk
}

export interface Model {
  id: string
  name: string
  contextWindow: number
  supportsFunctions: boolean
}

export interface ProviderCapabilities {
  streaming: boolean
  toolUse: boolean
  vision: boolean
}

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system' | 'tool'
  content: string | null
  tool_calls?: ToolCallRequest[]
  tool_call_id?: string
}

export interface ToolCallRequest {
  id: string
  type: 'function'
  function: {
    name: string
    arguments: string
  }
}

export interface StreamChunk {
  type: 'text' | 'tool_call' | 'tool_result' | 'error' | 'status' | 'done'
  session_id: string
  chunk_data: unknown
  timestamp: number
}

// ToolCall — هيكل موحد لكل المزودين
export interface ToolCall {
  id: string
  name: string
  args: Record<string, unknown>
  status: 'pending' | 'approved' | 'rejected' | 'done'
}

// Session — هيكل الجلسة الكامل
export interface Session {
  id: string
  project_path: string
  title: string
  provider_id: string
  model_id: string
  created_at: number
  updated_at: number
  status: 'active' | 'idle' | 'error' | 'completed' | 'waiting_approval'
  messages: Message[]
}

export interface Message {
  id: string
  session_id: string
  role: 'user' | 'assistant' | 'tool_result'
  content: string
  chunks: string[]
  tool_calls?: ToolCall[]
  status: 'streaming' | 'done' | 'error' | 'cancelled'
  timestamp: number
}
