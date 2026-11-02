import type { Finding } from './types';

interface KeyRule {
  pattern: RegExp;
  // Optional extra check on the matched text to avoid false alarms.
  check?: (match: string) => boolean;
}

const KEY_RULES: KeyRule[] = [
  // AWS access key id
  { pattern: /\bAKIA[0-9A-Z]{16}\b/g },
  // GitHub tokens
  { pattern: /\bgh[pousr]_[A-Za-z0-9]{36,}\b/g },
  // OpenAI-style keys; must contain a digit so words like "sk-learn-..." are ignored
  { pattern: /\bsk-[A-Za-z0-9_-]{20,}/g, check: (match) => /\d/.test(match) },
];

export function detectKeys(text: string): Finding[] {
  const findings: Finding[] = [];

  for (const rule of KEY_RULES) {
    for (const match of text.matchAll(rule.pattern)) {
      const value = match[0] ?? '';
      if (rule.check && !rule.check(value)) continue;

      const start = match.index ?? 0;
      findings.push({
        type: 'KEY',
        start,
        end: start + value.length,
        confidence: 'high',
      });
    }
  }

  return findings;
}