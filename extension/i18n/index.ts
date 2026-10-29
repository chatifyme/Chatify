import { en } from './en';
import { hr } from './hr';

export type MessageKey = keyof typeof hr;
export type Messages = Record<MessageKey, string>;
export type Locale = 'hr' | 'en';

const catalogs: Record<Locale, Messages> = { hr, en };

export const DEFAULT_LOCALE: Locale = 'hr';

export function t(key: MessageKey, locale: Locale = DEFAULT_LOCALE): string {
  return catalogs[locale][key];
}
