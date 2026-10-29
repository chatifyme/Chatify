import { hr } from './hr';
import { en } from './en';

export type Locale = 'hr' | 'en';
export type MessageKey = keyof typeof hr;

const catalogs: Record<Locale, Record<MessageKey, string>> = { hr, en };

/** Returns UI text for a key. Croatian is the default. */
export function t(key: MessageKey, locale: Locale = 'hr'): string {
  return catalogs[locale][key];
}
