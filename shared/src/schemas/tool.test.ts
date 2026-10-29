import { describe, expect, it } from 'vitest';
import { ToolSchema } from './tool';

describe('ToolSchema', () => {
  it('accepts a supported tool', () => {
    expect(ToolSchema.parse('chatgpt')).toBe('chatgpt');
  });

  it('rejects unsupported tools and non-strings', () => {
    expect(ToolSchema.safeParse('gemini').success).toBe(false);
    expect(ToolSchema.safeParse('').success).toBe(false);
    expect(ToolSchema.safeParse(42).success).toBe(false);
  });
});
