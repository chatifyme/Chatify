import { browser } from 'wxt/browser';
import { t } from '../i18n';

/** Chatify logo shown on AI tool pages while the extension is active. Replaced in Phase 3. */
export function Badge() {
  const label = t('badgeActive');
  return (
    <img
      src={browser.runtime.getURL('/icon/128.png')}
      alt={label}
      title={label}
            className="fixed bottom-5.5 right-4 z-[2147483647] h-14 w-14 rounded-2xl shadow-lg"
    />
  );
}