// ============================================================
// openai-compatible.ts — Generic adapter لأي مزود OpenAI-compatible
// ============================================================

import type { Provider, Model, ChatMessage, StreamChunk } from './base.ts'

export interface OpenAICompatibleConfig {
  id: string
  name: string
  baseURL: string
  apiKey: string
  models: Model[]
}

export function openaiCompatible(config: OpenAICompatibleConfig): Provider {
  return {
    id: config.id,
    name: config.name,
    baseURL: config.baseURL,
    apiKey: config.apiKey,
    models: config.models,
    capabilities: {
      streaming: true,
      toolUse: true,
      vision: false,
    },

    headers: () => ({
      'Content-Type': 'application/json',
      Authorization: `Bearer ${config.apiKey}`,
    }),

    formatRequest: (messages: ChatMessage[]) => ({
      model: config.models[0]?.id ?? 'default',
      messages: messages.map((m) => ({ role: m.role, content: m.content })),
      stream: true,
    }),

    formatResponse: (raw: unknown): StreamChunk => {
      // raw هو chunk من SSE — نستخرج النص
      const data = raw as Record<string, unknown>
      const choices = data?.choices as Array<Record<string, unknown>> | undefined
      const delta = choices?.[0]?.delta as Record<string, unknown> | undefined
      const text = (delta?.content as string) ?? ''

      return {
        type: text ? 'text' : 'status',
        session_id: '',   // يُملأ من session.ts
        chunk_data: text,
        timestamp: Date.now(),
      }
    },
  }
}
