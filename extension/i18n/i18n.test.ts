import { describe, expect, it } from 'vitest';
import { t } from './index';

describe('t', () => {
  it('defaults to Croatian', () => {
    expect(t('badgeActive')).toBe('Chatify je aktivan');
  });

  it('supports English', () => {
    expect(t('badgeActive', 'en')).toBe('Chatify is active');
  });
});
