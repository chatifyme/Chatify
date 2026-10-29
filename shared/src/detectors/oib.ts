import type { Finding } from './types';
export function isValidOib(value: string): boolean {
  if (!/^\d{11}$/.test(value)) return false;

  let a = 10;
  for (let i = 0; i < 10; i++) {
    a = (a + Number(value.charAt(i))) % 10;
    if (a === 0) a = 10;
    a = (a * 2) % 11;
  }

  const control = (11 - a) % 10;
  return control === Number(value.charAt(10));
}

export function detectOib(text: string): Finding[] {
  const findings: Finding[] = [];

  for (const match of text.matchAll(/(?<![\d+])\d{11}(?!\d)/g)) {
    const value = match[0];
    if (!isValidOib(value)) continue;

    const start = match.index ?? 0;
    const before = text.slice(Math.max(0, start - 25), start);
    const hasContext = /\boib\b/i.test(before);

    findings.push({
      type: 'OIB',
      start,
      end: start + value.length,
      confidence: hasContext ? 'high' : 'medium',
    });
  }

  return findings;
}