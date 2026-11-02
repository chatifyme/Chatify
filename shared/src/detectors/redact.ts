import type { DetectorType, Finding } from './types';

export const PLACEHOLDERS: Record<DetectorType, string> = {
  OIB: '[OIB]',
  IBAN: '[IBAN]',
  KEY: '[KLJUČ]',
  EMAIL: '[EMAIL]',
};

/** Where a replacement happened. Never stores the original text. */
export interface Replacement {
  type: DetectorType;
  placeholder: string;
  originalStart: number;
  originalEnd: number;
  newStart: number;
  newEnd: number;
}

export interface RedactResult {
  text: string;
  replacements: Replacement[];
}

/** Replaces findings with placeholders. Overlapping or unsorted findings are handled. */
export function redact(text: string, findings: readonly Finding[]): RedactResult {
  const ordered = [...findings].sort((a, b) => a.start - b.start || b.end - a.end);

  let output = '';
  let cursor = 0;
  const replacements: Replacement[] = [];

  for (const finding of ordered) {
    if (finding.start < cursor || finding.end > text.length) continue;

    output += text.slice(cursor, finding.start);
    const placeholder = PLACEHOLDERS[finding.type];
    const newStart = output.length;
    output += placeholder;

    replacements.push({
      type: finding.type,
      placeholder,
      originalStart: finding.start,
      originalEnd: finding.end,
      newStart,
      newEnd: output.length,
    });
    cursor = finding.end;
  }

  output += text.slice(cursor);
  return { text: output, replacements };
}
