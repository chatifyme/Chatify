import { z } from 'zod';

/** AI tools Chatify supports. Only ChatGPT for now. */
export const SUPPORTED_TOOLS = ['chatgpt'] as const;

export const toolSchema = z.enum(SUPPORTED_TOOLS);

export type Tool = z.infer<typeof toolSchema>;
