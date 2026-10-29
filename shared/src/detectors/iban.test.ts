import { describe, expect, it } from 'vitest';
import { isValidIban } from './iban';

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