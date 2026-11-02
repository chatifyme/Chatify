import { describe, expect, it } from 'vitest';
import { detectEmail } from './email';

describe('detectEmail', () => {
  it('finds an e-mail in a Croatian sentence', () => {
    const text = 'Pošalji na ivan.horvat@firma.hr, hvala';
    const findings = detectEmail(text);

    expect(findings).toHaveLength(1);
    expect(findings[0]?.type).toBe('EMAIL');
    expect(text.slice(findings[0]?.start, findings[0]?.end)).toBe('ivan.horvat@firma.hr');
  });

  it('supports plus addressing and subdomains', () => {
    const text = 'ana+test@mail.example.co.uk';
    const findings = detectEmail(text);

    expect(text.slice(findings[0]?.start, findings[0]?.end)).toBe(text);
  });

  it('finds several addresses', () => {
    expect(detectEmail('a@x.hr i b@y.com')).toHaveLength(2);
  });

  it('ignores text without a valid address', () => {
    expect(detectEmail('@ samo znak')).toHaveLength(0);
    expect(detectEmail('korisnik@localhost')).toHaveLength(0);
    expect(detectEmail('')).toHaveLength(0);
  });
});
