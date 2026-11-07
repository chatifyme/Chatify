import { t } from '../i18n';

interface FallbackBoxProps {
  /** Receives the pasted text. The caller must never log or store its content. */
  onTextChange: (text: string) => void;
}

/** Small floating box shown when the ChatGPT input cannot be found. */
export function FallbackBox({ onTextChange }: FallbackBoxProps) {
  return (
    <section className="fixed bottom-24 right-4 z-[2147483647] w-80 rounded-2xl bg-white p-4 font-sans shadow-lg ring-1 ring-black/10">
      <h2 className="text-sm font-semibold text-indigo-600">{t('fallbackTitle')}</h2>
      <p className="mt-1 text-xs text-gray-600">{t('fallbackHint')}</p>
      <textarea
        className="mt-3 h-28 w-full resize-none rounded-lg border border-gray-300 p-2 text-sm text-gray-900"
        placeholder={t('fallbackPlaceholder')}
        onChange={(event) => onTextChange(event.target.value)}
      />
    </section>
  );
}
