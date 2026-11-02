import { describe, expect, it } from 'vitest';
import { detectOib, isValidOib } from './oib';

describe('isValidOib', () => {
  it('accepts a valid OIB', () => {
    expect(isValidOib('12345678903')).toBe(true);
  });

  it('rejects an OIB with a wrong check digit', () => {
    expect(isValidOib('12345678900')).toBe(false);
  });

  it('accepts a second valid OIB', () => {
    expect(isValidOib('69435151530')).toBe(true);
  });

  it('rejects wrong length', () => {
    expect(isValidOib('1234567890')).toBe(false);
    expect(isValidOib('123456789012')).toBe(false);
  });

  it('rejects letters and empty text', () => {
    expect(isValidOib('abcdefghijk')).toBe(false);
    expect(isValidOib('')).toBe(false);
  });
});

describe('detectOib', () => {
  it('finds an OIB inside a sentence', () => {
    const text = 'OIB klijenta je 12345678903.';
    const findings = detectOib(text);

    expect(findings).toHaveLength(1);
    expect(findings[0]?.type).toBe('OIB');
    expect(text.slice(findings[0]?.start, findings[0]?.end)).toBe('12345678903');
  });

  it('ignores an 11-digit number with a wrong check digit', () => {
    expect(detectOib('Broj 12345678900')).toHaveLength(0);
  });

  it('ignores digits that are part of a longer number', () => {
    expect(detectOib('123456789031')).toHaveLength(0);
    expect(detectOib('0112345678903')).toHaveLength(0);
  });

  it('ignores a number that follows a plus sign (phone numbers)', () => {
    expect(detectOib('Nazovi +12345678903')).toHaveLength(0);
  });

  it('has high confidence when the word OIB is nearby', () => {
    const [finding] = detectOib('OIB klijenta je 12345678903.');
    expect(finding?.confidence).toBe('high');
  });

  it('has medium confidence without the word OIB nearby', () => {
    const [finding] = detectOib('Broj je 69435151530 u sustavu');
    expect(finding?.confidence).toBe('medium');
  });
});
