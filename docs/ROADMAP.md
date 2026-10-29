# Chatify – plan izrade od početka do kraja

Ovaj dokument povezuje sve dijelove sustava u jedan redoslijed izrade. Tehničke odluke i razlozi su u `ARCHITECTURE.md`, a točni zadaci po fazama u `PROMPTS.md`. Ako se nešto ovdje razlikuje od tih dokumenata, oni imaju prednost, a ovaj dokument treba ispraviti.

## 1. Dijelovi sustava

```
 ┌──────────────────────── preglednik zaposlenika ────────────────────────┐
 │  chatgpt.com                                                           │
 │   └─ Chatify ekstenzija (extension/)                                   │
 │        adapters/  čita polje za unos, hvata slanje                     │
 │        detektori  (iz shared/) OIB, IBAN, ključevi, e-mail             │
 │        rules/     ocjena kvalitete prompta (bez AI-ja)                 │
 │        ui/        oznaka, prozor upozorenja, panel (Shadow DOM)        │
 └───────┬───────────────────────────────┬────────────────────────────────┘
         │ agregirani događaji           │ "Poboljšaj" (samo na klik,
         │ (bez teksta prompta)          │  nakon zamjene oznakama)
         ▼                               ▼
 ┌─────────────────────────────────────────────────────┐      ┌───────────────┐
 │ Cloudflare Worker (worker/, Hono + zod)             │─────▶│ jezični model │
 │  /v1/events  /v1/improve  /v1/policies  cron        │      │ (LlmProvider) │
 │  ponovno pokreće detektore iz shared/               │      └───────────────┘
 └───────────────────────┬─────────────────────────────┘
                         │ uvijek s JWT-om korisnika (RLS)
                         ▼
 ┌─────────────────────────────────────────────────────┐
 │ Supabase (supabase/): Postgres + RLS + Auth         │
 └───────────────────────▲─────────────────────────────┘
                         │ supabase-js s JWT-om admina (RLS)
 ┌───────────────────────┴─────────────────────────────┐      ┌───────────────┐
 │ Nadzorna ploča (dashboard/, Vite + React)           │      │ Resend        │
 │ Cloudflare Pages, samo za admina firme              │      │ tjedni mail   │
 └─────────────────────────────────────────────────────┘      └───────────────┘
```

| Dio | Mapa | Nastaje u fazi | Gdje radi | Trošak |
| --- | --- | --- | --- | --- |
| Zajednički kod: sheme, detektori | `shared/` | 0–1 | ekstenzija i Worker | 0 € |
| Ekstenzija za ChatGPT | `extension/` | 0–4, zatim 5–6 | preglednik zaposlenika | 0 € (5 $ jednokratno za Web Store u fazi 9) |
| Baza i prijava | `supabase/` | 5 | Supabase (besplatna razina) | 0 €; Pro oko 25 $/mj. tek za prvu firmu koja plaća |
| Backend API | `worker/` | 5–7 | Cloudflare Workers | 0 € |
| Jezični model | `worker/src/llm/` | 6 | dobavljač modela | nekoliko €/mj. za pilot, ograničeno kapom |
| Nadzorna ploča | `dashboard/` | 7 | Cloudflare Pages | 0 € |
| E-pošta | `worker/` (cron) | 7 | Resend | 0 € |
| Testovi | `e2e/` + uz svaki paket | od faze 1 | lokalno + GitHub Actions | 0 € |

## 2. Redoslijed izrade

### Dio 1: ekstenzija bez servera (tjedni 1–6)

U ovom dijelu nema backenda, baze ni računa u oblaku. Sve radi lokalno u pregledniku, pa je i demo za firme besplatan.

| Faza | Što nastaje | Ovisi o | Gotovo kad |
| --- | --- | --- | --- |
| **0 Temelj** | monorepo (npm workspaces), `shared/` i `extension/` (WXT, React, Tailwind), i18n, ESLint/Prettier/Vitest, CI na GitHubu, prazne mape za ostale dijelove | – | `npm install`, build i testovi prolaze; ekstenzija se učita u Chrome i javlja se u konzoli na chatgpt.com |
| **1 Detektori** | `shared/src/detectors/`: OIB (ISO 7064), IBAN (mod 97), API ključevi, e-mail; `redact()` | 0 | svi testovi prolaze, pokrivenost > 90 % |
| **2 Adapter** | `extension/adapters/chatgpt.ts`: traži polje i gumb za slanje, prati promjene, pravila kao JSON, rezervni okvir | 0 | čita tekst u novom i postojećem razgovoru, preživi navigaciju |
| **3 Upozorenje** | bojanje (CSS Highlight API), oznaka u okviru za unos, presretanje slanja, prozor s tri radnje | 1, 2 | OIB/IBAN se oboje i slanje se zaustavi → **vrata: demo prvim firmama** |
| **4 Kvaliteta prompta** | `extension/rules/` (vague, missing-context, contradiction, too-short, no-format), ocjena 0–100, panel s prijedlozima | 2, 3 | primjer iz Figme daje tri očekivane oznake |

### Dio 2: server, ploča i objava (tjedni 5–8 i nakon pilota)

Počinje tek kad kažete. Ovdje prvi put trebaju računi (vidi `SETUP.md`).

| Faza | Što nastaje | Ovisi o | Gotovo kad |
| --- | --- | --- | --- |
| **5 Baza i događaji** | Supabase migracije (8 tablica, RLS svugdje, testovi izolacije firmi), prijava Google/Microsoft u ekstenziji, Worker `/v1/events`, slanje agregata iz ekstenzije | 1–4 | događaji stižu u bazu, RLS testovi prolaze, payload ne može sadržavati tekst |
| **6 Poboljšaj** | Worker `/v1/improve` iza `LlmProvider`, ponovna provjera detektorima, kapa po firmi; evaluacija modela na ~30 izmišljenih hrvatskih promptova; gumb u panelu | 4, 5 | bez klika nema mrežnog prometa s tekstom; OIB se odbija na Workeru |
| **7 Nadzorna ploča** | `dashboard/`: pregled (KPI, grafovi, timovi), politike, članovi i pozivi, plan i potrošnja; tjedni izvještaj (Cron + Resend) | 5 (6 za potrošnju) | ploča pokazuje stvarne agregate, promjena politike stiže u ekstenziju → **vrata: pilot s 3–5 firmi** |
| **8 Otpornost** | dnevni Playwright test na ChatGPT-u (GitHub Actions), pravila polja sa servera kao JSON | 2, 5 | pokvaren selektor otvori GitHub Issue |
| **9 Objava** | Chrome Web Store (neprikazano), politika privatnosti hr/en, nacrt DPA-a, upute za Google Admin i Intune | 1–8 | ZIP prolazi provjeru trgovine |
| **10 Naplata** | Stripe ili Paddle, webhook u Workeru | pilot: 3 firme kažu da bi platile | firma može pretplatiti plan |
| **11 Učvršćivanje** | RLS matrica, gitleaks, audit, runbook, kopije baze | prije prve firme koja plaća | izvještaj po ozbiljnosti |
| **12 Coach (opcija)** | Custom GPT ili MCP aplikacija nad `/v1/improve` | 6, ako pilot pokaže potrebu | – |

Napomena: `GET /v1/policies` (ekstenzija dohvaća politike firme) nije posebno imenovan u `PROMPTS.md`. Predlažem da nastane u Fazi 7 na Workeru, uz istu provjeru JWT-a i RLS-a.

## 3. Što se gradi u kojem dijelu

### Ekstenzija (`extension/`)

- **Faze 0–4:** content script na `chatgpt.com` i `chat.openai.com`; adapter; detektori iz `shared/`; bojanje; prozor upozorenja; panel s ocjenom; i18n (`hr` zadano, `en` pripremljeno).
- **Faza 5:** prijava (`chrome.identity`, dozvola `identity`), pridruživanje firmi pozivnim kodom, red događaja s ponovnim pokušajem.
- **Faza 6:** gumb "Poboljšaj" s izričitim pristankom.
- **Faza 7:** dohvaćanje politika firme umjesto tvrdo kodiranih.
- **Dozvole:** samo domene AI alata, naša domena i `identity`. Nikad `<all_urls>`.

### Backend (`worker/`)

| Endpoint | Faza | Ulaz | Napomena |
| --- | --- | --- | --- |
| `POST /v1/events` | 5 | `{ tool, week, quality_score, blocked_type, action }[]` | stroga zod shema, odbija nepoznata polja |
| `POST /v1/improve` | 6 | `{ text ≤ 4000, locale }` | ponovni detektori → 400; kapa po firmi |
| `GET /v1/policies` | 7 | – | politike firme za ekstenziju |
| Cron: tjedni izvještaj | 7 | – | jedno od dva dokumentirana mjesta za service role ključ |
| `POST /v1/billing/webhook` | 10 | potpisan zahtjev | drugo dokumentirano mjesto za service role ključ |

### Baza (`supabase/`)

Tablice: `organizations`, `teams`, `members`, `invites`, `events`, `policies`, `plans`, `usage_monthly`. Svaka tablica ima `org_id` i RLS. Nijedan stupac ne može sadržavati tekst prompta. Ploča čita samo agregirane poglede i RPC funkcije. Migracije se pišu u SQL-u kroz Supabase CLI, a tipovi se generiraju iz sheme.

### Nadzorna ploča (`dashboard/`)

Stranice: prijava, pregled, politike, članovi i timovi, plan i potrošnja. Statični SPA na Cloudflare Pagesu, prema zaslonima 3 i 4 u Figmi.

## 4. Podjela posla (prijedlog za tim od troje)

| Tjedni | Osoba 1 (ekstenzija) | Osoba 2 (backend i ploča) | Osoba 3 (dizajn, firme, pravno) |
| --- | --- | --- | --- |
| 1–2 | Faze 0–2 | Faza 1 (detektori, s osobom 1); proučava Supabase i RLS | razgovori s 10–15 firmi; uvjeti korištenja ChatGPT-a |
| 3–4 | Faza 3 | priprema sheme baze (Faza 5, nacrt) | testiranje Faze 3; dogovor demo termina |
| 5–6 | Faza 4 | Faza 5 | demo firmama; pravnik (politika privatnosti, DPA) |
| 7–8 | Faze 6 i 8 (dio u ekstenziji) | Faze 6 i 7 | Faza 9 (tekstovi), odabir pilot firmi |

## 5. Vrata i otvorena pitanja

**Vrata**
1. Nakon Faze 3 dolazi **demo**: radi li zaštita podataka uvjerljivo?
2. Nakon Faze 7 dolazi **pilot** s 3–5 firmi.
3. Kad 3 firme potvrde da bi platile, kreće **naplata** (Faza 10).

**Otvoreno, odlučujete vi**
- Prvi kupac: sigurnost, IT ili voditelji ljudi? Odgovor mijenja prioritet Faze 4 u odnosu na Fazu 3.
- Konačan naziv proizvoda.
- Repozitorij je trenutno javan, a `PROMPTS.md` predviđa privatni.
- Licenca.
- Dobavljač modela (Faza 6, nakon evaluacije).
- Stripe ili Paddle (Faza 10).
