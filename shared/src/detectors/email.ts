import type { Finding } from './types';

const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g;

export function detectEmail(text: string): Finding[] {
  const findings: Finding[] = [];

  for (const match of text.matchAll(EMAIL)) {
    const value = match[0] ?? '';
    const start = match.index ?? 0;

    findings.push({
      type: 'EMAIL',
      start,
      end: start + value.length,
      confidence: 'high',
    });
  }

  return findings;
}
