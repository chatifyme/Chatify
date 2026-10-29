import { z } from 'zod';

/** AI tools Chatify supports. Only ChatGPT for now; Claude and Gemini come later. */
export const ToolSchema = z.enum(['chatgpt']);

export type Tool = z.infer<typeof ToolSchema>;
