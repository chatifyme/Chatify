import { detectEmail } from './email';
import { detectIban } from './iban';
import { detectKeys } from './keys';
import { detectOib } from './oib';
import type { DetectorType, Finding } from './types';

// When two findings overlap, the one with the lower number wins.
const PRIORITY: Record<DetectorType, number> = { KEY: 0, IBAN: 1, EMAIL: 2, OIB: 3 };

/** Runs all detectors and returns non-overlapping findings sorted by position. */
export function detectAll(text: string): Finding[] {
  const candidates = [
    ...detectKeys(text),
    ...detectIban(text),
    ...detectEmail(text),
    ...detectOib(text),
  ].sort(
    (a, b) => PRIORITY[a.type] - PRIORITY[b.type] || b.end - b.start - (a.end - a.start),
  );

  const kept: Finding[] = [];
  for (const candidate of candidates) {
    const overlaps = kept.some((k) => candidate.start < k.end && k.start < candidate.end);
    if (!overlaps) kept.push(candidate);
  }

  return kept.sort((a, b) => a.start - b.start);
}
