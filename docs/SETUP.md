# Postavljanje računala za razvoj

## Ukratko: što ide preko gita, a što ne

Git ne instalira programe; on samo preuzima kod. Ali **gotovo sve što projekt treba instalira se automatski** nakon `git clone` jednom naredbom, `npm install`. Popis knjižnica i alata s točnim verzijama zapisan je u `package.json` i `package-lock.json`, koji su u repozitoriju. Tako svi u timu i CI dobiju iste verzije.

Ručno se instaliraju samo **četiri programa** (Docker tek od Faze 5) i otvara nekoliko besplatnih računa.

## 1. Ručno instalirati (jednom po računalu)

| Program | Zašto | Kad treba |
| --- | --- | --- |
| **Git** | preuzimanje koda, grane, commitovi | odmah |
| **fnm** (upravitelj verzija Nodea) | instalira točnu verziju Node.js zapisanu u `.nvmrc` u repozitoriju; tako se verzija Nodea također "vuče" iz gita | odmah |
| **Google Chrome** ili **Microsoft Edge** | učitavanje i testiranje ekstenzije | odmah |
| **Docker Desktop** | Supabase CLI ga koristi za lokalnu bazu. Besplatan za obrazovanje i male firme (provjerite uvjete licence) | Faza 5 |
| *VS Code* (preporuka) | uređivač; repozitorij će predložiti dodatke (ESLint, Prettier, Tailwind) preko `.vscode/extensions.json` | odmah |
| *GitHub CLI* `gh` (opcija) | pull requestovi iz terminala | po želji |

Verzija Node.js: **24 LTS**. Node 22 prestaje dobivati podršku u travnju 2027., dakle usred projekta, pa je 24 sigurniji izbor. Točna verzija bit će zapisana u `.nvmrc`.

### Windows (PowerShell)

```powershell
winget install --id Git.Git -e
winget install --id Schniz.fnm -e
winget install --id Microsoft.VisualStudioCode -e
winget install --id GitHub.cli -e            # opcija
winget install --id Docker.DockerDesktop -e  # tek za Fazu 5
```

Nakon instalacije fnm-a u PowerShell profil (`notepad $PROFILE`) dodaj red `fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression` i otvori novi terminal.

Zbog razlika u završecima redaka na Windowsu repozitorij će imati `.gitattributes`, pa ništa ne treba ručno podešavati.

### macOS (Homebrew)

```bash
brew install git fnm gh
brew install --cask visual-studio-code
brew install --cask docker                   # tek za Fazu 5
echo 'eval "$(fnm env --use-on-cd)"' >> ~/.zshrc && exec zsh
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install -y git curl unzip
curl -fsSL https://fnm.vercel.app/install | bash && exec $SHELL
# Docker Engine za Fazu 5: https://docs.docker.com/engine/install/
```

### Provjera

```bash
git --version
fnm --version
docker --version   # tek od Faze 5
```

## 2. Preuzimanje projekta i instalacija svega ostalog

```bash
git clone https://github.com/chatifyme/Chatify.git
cd Chatify
fnm install        # pročita .nvmrc i instalira točnu verziju Node.js
fnm use
npm install        # instalira SVE knjižnice i alate iz package-lock.json
```

Ove naredbe rade nakon što se Faza 0 spoji u `main`. Do tada repozitorij ima samo dokumente.

`npm install` donosi sljedeće; ništa od toga se ne instalira ručno:

| Alat | Paket | Za što | Od faze |
| --- | --- | --- | --- |
| TypeScript | `typescript` | jezik | 0 |
| WXT | `wxt`, `@wxt-dev/module-react` | izgradnja ekstenzije (MV3, Chrome i Edge) | 0 |
| React | `react`, `react-dom` | sučelje ekstenzije i ploče | 0 |
| Tailwind | `tailwindcss`, `@tailwindcss/vite` | stilovi | 0 |
| zod | `zod` | sheme i validacija | 0 |
| ESLint, Prettier | `eslint`, `typescript-eslint`, `prettier` | lint i formatiranje | 0 |
| Vitest | `vitest` | jedinični testovi | 0 |
| Playwright | `@playwright/test` | E2E testovi | 2 |
| Supabase CLI | `supabase` | lokalna baza, migracije, RLS testovi, tipovi | 5 |
| supabase-js | `@supabase/supabase-js` | pristup bazi s JWT-om | 5 |
| Hono | `hono` | API na Workeru | 5 |
| Wrangler | `wrangler` | lokalni Worker, secrets, deploy | 5 |
| Vite, React Router, TanStack Query, Recharts | `vite`, `react-router`, `@tanstack/react-query`, `recharts` | nadzorna ploča | 7 |
| Resend | `resend` | tjedni e-mail | 7 |

Supabase CLI i Wrangler namjerno su ovisnosti projekta, a ne globalni programi. Tako svi imaju istu verziju i pokreću ih preko `npx supabase …` i `npx wrangler …`.

Jedini dodatni korak, od Faze 2, je jednokratno preuzimanje preglednika za Playwright:

```bash
npx playwright install chromium
```

## 3. Računi (svi besplatni, osim gdje piše drugačije)

| Račun | Za što | Kad treba | Cijena |
| --- | --- | --- | --- |
| GitHub (organizacija `chatifyme`) | kod, pull requestovi, CI | već postoji | 0 €; provjerite i GitHub Student Developer Pack |
| Supabase | baza, prijava | Faza 5 | 0 € (pauzira se nakon 7 dana neaktivnosti) |
| Google Cloud i Microsoft Entra | OAuth za prijavu Googleom i Microsoftom | Faza 5 | 0 € |
| Cloudflare | Worker, Pages, Cron | Faza 5 | 0 € |
| Dobavljač jezičnog modela | API ključ za "Poboljšaj" | Faza 6 | nekoliko € mjesečno; postavite ograničenje potrošnje na računu |
| Resend | tjedni e-mail | Faza 7 | 0 € |
| Chrome Web Store (razvojni račun) | objava ekstenzije | Faza 9 | oko 5 $ jednokratno |
| Domena | naša domena za Worker i ploču | Faza 9 (opcija) | oko 10–15 € godišnje |

Tajne (ključevi, lozinke) **nikad ne idu u git**. Lokalno idu u `.env.local` (git ga ignorira), a na Cloudflareu kao Wrangler secret. U repozitoriju je samo `.env.example` s praznim vrijednostima.

## 4. Svakodnevni rad

```bash
git switch main && git pull
git switch -c phase-N-kratki-opis
npm run dev -w extension    # ekstenzija s automatskim osvježavanjem
npm run lint && npm run typecheck && npm test
git push -u origin phase-N-kratki-opis   # pa otvori pull request
```

Učitavanje ekstenzije u Chrome: `chrome://extensions` → uključi "Developer mode" → "Load unpacked" → odaberi mapu `extension/.output/chrome-mv3`. Točna putanja bit će potvrđena u Fazi 0.
