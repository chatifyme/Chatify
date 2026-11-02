import { describe, expect, it } from 'vitest';
import { detectAll } from './detect';
import { redact } from './redact';

describe('redact', () => {
  it('replaces an OIB with a placeholder', () => {
    const text = 'OIB klijenta je 12345678903.';

    expect(redact(text, detectAll(text)).text).toBe('OIB klijenta je [OIB].');
  });

  it('replaces every kind with its own placeholder', () => {
    const text =
      'OIB 12345678903, IBAN HR1210010051863000160, mail ana@firma.hr, ključ AKIAIOSFODNN7EXAMPLE';

    expect(redact(text, detectAll(text)).text).toBe(
      'OIB [OIB], IBAN [IBAN], mail [EMAIL], ključ [KLJUČ]',
    );
  });

  it('leaves text without findings unchanged', () => {
    const text = 'Običan prompt bez osjetljivih podataka.';
    const result = redact(text, detectAll(text));

    expect(result.text).toBe(text);
    expect(result.replacements).toHaveLength(0);
  });

  it('removes the original value from the output', () => {
    const text = 'IBAN HR12 1001 0051 8630 0016 0';

    expect(redact(text, detectAll(text)).text).not.toContain('1001');
  });
});
