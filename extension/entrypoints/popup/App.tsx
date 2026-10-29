import { t } from '../../i18n';

export function App() {
  return (
    <main className="w-72 p-4 font-sans">
      <h1 className="text-lg font-semibold text-indigo-600">{t('popup.title')}</h1>
      <p className="mt-2 text-sm text-slate-700">{t('popup.status')}</p>
    </main>
  );
}
