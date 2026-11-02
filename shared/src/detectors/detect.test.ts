import { describe, expect, it } from 'vitest';
import { detectAll } from './detect';

describe('detectAll', () => {
  it('returns nothing for harmless text', () => {
    expect(detectAll('Napiši kratak mail klijentu o sastanku u petak.')).toEqual([]);
    expect(detectAll('')).toEqual([]);
  });

  it('finds every kind in one text, sorted by position', () => {
    const text =
      'OIB 12345678903, IBAN HR1210010051863000160, mail ana@firma.hr, ključ AKIAIOSFODNN7EXAMPLE';

    expect(detectAll(text).map((f) => f.type)).toEqual(['OIB', 'IBAN', 'EMAIL', 'KEY']);
  });

  it('does not report an OIB inside a private key block', () => {
    const text = '-----BEGIN PRIVATE KEY-----\n12345678903\n-----END PRIVATE KEY-----';

    expect(detectAll(text).map((f) => f.type)).toEqual(['KEY']);
  });

  it('returns findings without any copy of the text', () => {
    const [finding] = detectAll('OIB 12345678903');

    expect(Object.keys(finding ?? {}).sort()).toEqual(['confidence', 'end', 'start', 'type']);
  });
});