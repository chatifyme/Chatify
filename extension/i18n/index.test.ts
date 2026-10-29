import { describe, expect, it } from 'vitest';
import { en } from './en';
import { hr } from './hr';
import { t } from './index';

describe('t', () => {
  it('defaults to Croatian', () => {
    expect(t('popup.status')).toBe('Chatify je aktivan na ChatGPT-u.');
  });

  it('returns English when asked', () => {
    expect(t('popup.status', 'en')).toBe('Chatify is active on ChatGPT.');
  });

  it('has the same keys in every locale', () => {
    expect(Object.keys(en).sort()).toEqual(Object.keys(hr).sort());
  });
});
