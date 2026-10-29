import { describe, expect, it } from 'vitest';
import { isValidOib } from './oib';

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