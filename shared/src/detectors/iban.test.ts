import { describe, expect, it } from 'vitest';
import { detectIban, isValidIban } from './iban';

describe('isValidIban', () => {
  it('accepts a valid Croatian IBAN', () => {
    expect(isValidIban('HR1210010051863000160')).toBe(true);
  });

  it('accepts a valid British IBAN', () => {
    expect(isValidIban('GB82WEST12345698765432')).toBe(true);
  });

  it('rejects an IBAN with a wrong checksum', () => {
    expect(isValidIban('HR1210010051863000161')).toBe(false);
  });

  it('rejects the wrong length for the country', () => {
    expect(isValidIban('HR121001005186300016')).toBe(false);
    expect(isValidIban('HR12100100518630001600')).toBe(false);
  });

  it('rejects unknown countries and lower case', () => {
    expect(isValidIban('XX82WEST12345698765432')).toBe(false);
    expect(isValidIban('hr1210010051863000160')).toBe(false);
  });
});

describe('detectIban', () => {
  it('finds an IBAN inside a sentence', () => {
    const text = 'Uplatite na IBAN HR1210010051863000160 do petka.';
    const findings = detectIban(text);

    expect(findings).toHaveLength(1);
    expect(findings[0]?.type).toBe('IBAN');
    expect(text.slice(findings[0]?.start, findings[0]?.end)).toBe('HR1210010051863000160');
  });

  it('finds an IBAN written with spaces', () => {
    const text = 'IBAN: HR12 1001 0051 8630 0016 0, hvala';
    const findings = detectIban(text);

    expect(findings).toHaveLength(1);
    expect(text.slice(findings[0]?.start, findings[0]?.end)).toBe('HR12 1001 0051 8630 0016 0');
  });

  it('ignores an IBAN with a wrong checksum', () => {
    expect(detectIban('HR1210010051863000161')).toHaveLength(0);
  });
});