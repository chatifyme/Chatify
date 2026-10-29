# Napredak po fazama

Nakon svake faze ovdje se dopisuje: što je napravljeno, koje su odluke donesene i zašto, i što je sljedeće.

## Faza 0: Temelj projekta (29. 10. 2026.)

Grana: `phase-0-foundation`.

### Napravljeno

- **Monorepo** (npm workspaces): `shared/` i `extension/`. Mape `worker/`, `dashboard/`, `supabase/` i `e2e/` za sada imaju samo README s fazom u kojoj nastaju.
- **Zajednička konfiguracija:** strogi TypeScript (`tsconfig.base.json`, uključeni `noUncheckedIndexedAccess` i `exactOptionalPropertyTypes`), ESLint (flat config, `typescript-eslint` strict, React Hooks), Prettier i Vitest s projektima `shared` i `extension`.
- **`shared/`:** TypeScript paket sa zodom; primjer sheme `ToolSchema` s testom. Izvozi izvorni `.ts` bez koraka izgradnje, jer ga i WXT (Vite) i kasnije Wrangler (esbuild) prevode sami.
- **`extension/`:** WXT (Manifest V3) + React + Tailwind v4.
  - Content script `entrypoints/chatgpt.content.ts` radi samo na `https://chatgpt.com/*` i `https://chat.openai.com/*` i za sada samo ispisuje `[Chatify] content script active`. Ne čita tekst prompta.
  - Popup s jednim tekstom iz i18n-a, stiliziran Tailwindom.
  - `host_permissions` sadrži samo te dvije domene, a `permissions` je prazan. Obje liste dolaze iz `extension/config/hosts.ts`, a test brani `<all_urls>` i zamjenske znakove u domeni.
  - Build za Chrome (`.output/chrome-mv3`) i Edge (`.output/edge-mv3`).
- **i18n:** `extension/i18n/hr.ts` (zadano) i `en.ts`. Tip `Messages` tjera da `en` ima iste ključeve kao `hr`, a test to provjerava i u izvođenju. I opis u manifestu dolazi iz `hr.ts`.
- **CI:** `.github/workflows/ci.yml` na svaki push i pull request pokreće `npm ci`, lint, typecheck, test i build (Node prema `.nvmrc`).
- **Ostalo:** `.gitignore` (s `.env.local` i `.dev.vars`), `.env.example` bez vrijednosti, `.gitattributes` (LF završeci redaka za Windows i macOS), `.editorconfig`, `.vscode/extensions.json`.
- **Dokumentacija:** `docs/ROADMAP.md` (plan cijelog sustava), `docs/SETUP.md` (instalacija, uključujući grešku PowerShella na Windowsu), odjeljak "Naredbe" u `CLAUDE.md`, "Pokretanje" u `README.md`.

### Odluke i razlozi

| Odluka | Zašto |
| --- | --- |
| TypeScript **5.9**, a ne 7.x | `typescript-eslint` 8.72 podržava TypeScript samo do verzije 6.1. Prelazak kad bude podrške. |
| Node **24 LTS** u `.nvmrc`, `engines: >=22` | Node 22 prestaje dobivati podršku u travnju 2027., usred projekta. |
| Vlastiti mali i18n (`t()`), bez biblioteke | Za nekoliko tekstova biblioteka nije potrebna. Tipovi jamče da prijevodi ne fale. |
| Domene na jednom mjestu (`config/hosts.ts`) | Dodavanje novog AI alata je jedna promjena koju je lako pregledati, i pokrivena je testom. |
| Markdown dokumenti izuzeti iz Prettiera | Ručno pisani hrvatski dokumenti zadržavaju svoj oblik. |
| Tailwind preko `@tailwindcss/vite` | Tailwind v4 radi kroz Vite dodatak, bez PostCSS konfiguracije. |

Nove ovisnosti su samo one iz tablice tehnologija u `CLAUDE.md` i alati za lint, formatiranje i testove. Svi su besplatni i otvorenog koda.

### Provjereno

- `npm install`, `npm run lint`, `npm run typecheck`, `npm test` (7 testova) i `npm run build` prolaze.
- Izgrađena ekstenzija učitana je u Chromium (Playwright). Content script se pokreće na `chatgpt.com` i `chat.openai.com`, a na drugoj domeni ne.
  - Ograničenje: mreža razvojnog okruženja ne dopušta pristup chatgpt.com, pa su stranice na tim adresama bile lažne (stub). Provjera na stvarnoj stranici napravi se ručno (Load unpacked, F12 → Console).

### Sljedeće

Faza 1: detektori OIB, IBAN, API ključeva i e-maila u `shared/src/detectors/`, s testovima napisanim prije koda.
