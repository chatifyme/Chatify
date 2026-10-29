import { t } from '../i18n';

/** Tiny proof that React + Tailwind render inside the Shadow DOM. Replaced in Phase 3. */
export function Badge() {
  return (
    <div className="fixed bottom-4 right-4 rounded-full bg-indigo-600 px-3 py-1 text-xs font-medium text-white shadow-lg">
      {t('badgeActive')}
    </div>
  );
}
