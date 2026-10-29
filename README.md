# Chatify

> Ekstenzija za preglednik koja zaposlenicima pomaže pisati bolje promptove i zaustavlja slanje osjetljivih podataka u AI alate. Firmi daje agregirane uvide u korištenje AI-ja.

**Status:** u razvoju (dizajn i planiranje gotovi, kreće izrada) · **Naziv:** radni · **Licenca:** još nije odabrana

## Sadržaj

- [O projektu](#o-projektu)
- [Funkcije](#funkcije)
- [Kako radi](#kako-radi)
- [Privatnost](#privatnost)
- [Tehnologije](#tehnologije)
- [Plan razvoja](#plan-razvoja)
- [Struktura repozitorija](#struktura-repozitorija)
- [Dokumentacija i dizajn](#dokumentacija-i-dizajn)
- [Pokretanje](#pokretanje)
- [Poznata ograničenja](#poznata-ograničenja)

## O projektu

Zaposlenici sve češće koriste ChatGPT, Claude i Gemini, ali bez smjernica i često preko osobnih računa. Posljedica su loši promptovi (nejasni, bez konteksta, kontradiktorni) i osjetljivi podaci (OIB, IBAN, API ključevi) zalijepljeni u vanjske alate.

Chatify rješava oba problema na mjestu gdje nastaju: **unutar stranice AI alata**, prije nego se prompt pošalje. Nije zasebna aplikacija; jedina zasebna aplikacija je web nadzorna ploča za admina firme.

**Po čemu se razlikujemo:** većina postojećih alata dolazi iz sigurnosti i nadzora za velike firme. Chatify dolazi iz edukacije i produktivnosti, osjetljive podatke prepoznaje lokalno u pregledniku i cilja mala i srednja poduzeća u EU-u, na hrvatskom jeziku.

## Funkcije

| Funkcija | Što radi |
| --- | --- |
| **Provjera prompta** | Boji nejasne dijelove, one kojima fali kontekst i kontradikcije; predlaže popravke i daje ocjenu 0–100. Ne piše umjesto korisnika. |
| **Upozorenje o osjetljivim podacima** | Prije slanja prepoznaje OIB, IBAN, API ključeve i e-mail adrese; nudi zamjenu oznakama, uređivanje ili slanje svejedno. |
| **Nadzorna ploča** | Aktivni korisnici, prosječna kvaliteta, zaustavljeni osjetljivi podaci, procjena uštede vremena, pregled po timovima, tjedne preporuke. |
| **Politike** | Admin bira pravila i radnju: zamijeni, blokiraj ili upozori. |

Korisnik uvijek odlučuje: Chatify označava i predlaže, nikad sam ne mijenja prompt i ne šalje ništa bez klika.

## Kako radi

```
 Preglednik zaposlenika (lokalno)
┌──────────────────────────────────┐
│ ChatGPT stranica + Chatify sloj  │
│  - detektori (shared/)           │──── samo agregirani događaji ───┐
│  - pravila kvalitete prompta     │                                 │
└────────────────┬─────────────────┘                                 ▼
                 │ tek na klik "Poboljšaj"             ┌──────────────────────────┐
                 ▼ (nakon zamjene oznakama)            │ Cloudflare Worker (Hono) │
        ┌──────────────────┐                           │ JWT, zod, kape, ponovna  │
        │ Cloudflare Worker│ ── ponovna provjera ──▶   │ provjera detektorima     │
        └────────┬─────────┘                           └────────────┬─────────────┘
                 ▼                                                  ▼
        ┌──────────────────┐                           ┌──────────────────────────┐
        │ Jezični model    │                           │ Supabase (Postgres + RLS)│
        │ (iza LlmProvider)│                           └────────────┬─────────────┘
        └──────────────────┘                                        ▼
                                                        Nadzorna ploča (Vite + React)
```

1. Ekstenzija prati polje za unos na podržanim AI stranicama.
2. Detektori i pravila rade **lokalno**, bez slanja teksta bilo gdje.
3. Samo kad korisnik klikne "Poboljšaj", prompt (nakon zamjene osjetljivih podataka oznakama) ide na Worker, koji ga **ponovno provjeri** istim detektorima i odbije ako je ostalo nešto osjetljivo, pa tek onda šalje modelu.
4. Na server idu samo agregirani događaji: tim, alat, tjedan, ocjena, vrsta zaustavljenog podatka.

## Privatnost

| Podatak | Gdje se obrađuje | Što se sprema |
| --- | --- | --- |
| Osjetljivi podaci u promptu | Lokalno u pregledniku | Samo vrsta ("OIB pronađen"), nikad sam podatak |
| Ocjena kvalitete (pravila) | Lokalno | Broj ocjene |
| Prijedlozi "Poboljšaj" | Worker i dobavljač modela, tek na klik, nakon zamjene oznakama | Mi ne spremamo ništa. **Dobavljač modela može zadržati zahtjev do 30 dana (nadzor zlouporabe) i ne koristi ga za treniranje.** Potpuno isključenje zadržavanja traži odobrenje dobavljača. |
| Korištenje po timu | Server | Tim, alat, tjedan, ocjena, vrsta zaustavljenog podatka |

Pregled po pojedinom zaposleniku isključen je prema zadanim postavkama i uključuje se samo uz pristanak svakog zaposlenika.

Izolacija firmi: svaka tablica ima Row Level Security, a testovi baze dokazuju da firma A ne vidi podatke firme B.

## Tehnologije

| Sloj | Tehnologija | Napomena |
| --- | --- | --- |
| Ekstenzija | TypeScript, [WXT](https://wxt.dev) (Manifest V3, Chrome i Edge), React, Tailwind, Shadow DOM | Bojanje preko CSS Custom Highlight API |
| Zajednički kod | `shared/`: zod sheme i detektori | Isti kod u ekstenziji i na Workeru |
| Backend | Cloudflare Workers + Hono + zod | Besplatna razina; ne Express |
| Baza i prijava | Supabase: Postgres, RLS, Auth (Google/Microsoft) | Bez Prisme jer zaobilazi RLS; SQL migracije kroz Supabase CLI |
| Jezični model | Iza vlastitog sučelja `LlmProvider` | Model se bira evaluacijom na ~30 izmišljenih hrvatskih promptova |
| Nadzorna ploča | Vite + React, TanStack Query, Recharts, Cloudflare Pages | Statična; ne Next.js |
| E-pošta | Resend | Tjedni izvještaj preko Cloudflare Cron Triggers |
| Naplata | Tek nakon pilota (Stripe ili merchant-of-record) | Tablice `plans` i `usage_monthly` postoje od početka |
| Testovi | Vitest, Playwright, `supabase test db` | Dnevna provjera polja za unos |
| Razvoj i objava | npm workspaces, GitHub Actions, wrangler | Docker samo lokalno (Supabase CLI) |

Procjena troškova: ispod 30 € mjesečno tijekom pilota, oko 30 do 60 € kad krenu plaćene firme. Detalji u `docs/ARCHITECTURE.md`.

**Napomena o "ChatGPT pluginu":** ChatGPT plugini ugašeni su u travnju 2024. Naša integracija je content script ekstenzije koji radi unutar stranice. Integracije kroz sam ChatGPT (Custom GPT, MCP aplikacije) ne mogu vidjeti ni zaustaviti ono što korisnik tipka, pa ne zamjenjuju ekstenziju (vidi Fazu 12 u `docs/PROMPTS.md`).

## Plan razvoja

Faze su detaljno opisane u `docs/PROMPTS.md`.

- [ ] **0** Temelj projekta (npm workspaces, WXT, CI)
- [ ] **1** Detektori OIB / IBAN / ključevi / e-mail u `shared/`
- [ ] **2** Adapter za ChatGPT i rezervni okvir
- [ ] **3** Bojanje, upozorenje i presretanje slanja → *demo prvim firmama*
- [ ] **4** Provjera kvalitete prompta (pravila) i panel
- [ ] **5** Baza, prijava i događaji
- [ ] **6** Gumb "Poboljšaj" (Worker + model)
- [ ] **7** Nadzorna ploča, politike, tjedni izvještaj → *pilot s 3–5 firmi*
- [ ] **8** Dnevni testovi i otpornost na promjene sučelja
- [ ] **9** Objava (Chrome Web Store, neprikazano) i pravni minimum
- [ ] **10** Naplata (tek nakon pilota)
- [ ] **11** Učvršćivanje
- [ ] **12** Opcionalno: "Chatify Coach" unutar ChatGPT-a

## Struktura repozitorija

```
chatify/
├── extension/    ekstenzija (adapters/, rules/, ui/)
├── worker/       Cloudflare Worker (Hono)
├── dashboard/    nadzorna ploča (Vite + React)
├── shared/       zod sheme i detektori (koriste ekstenzija i Worker)
├── supabase/     shema, migracije, RLS testovi
├── e2e/          Playwright testovi
├── docs/         plan, arhitektura, promptovi za Claude Code
├── CLAUDE.md     pravila za Claude Code
└── README.md
```

## Dokumentacija i dizajn

- `docs/ARCHITECTURE.md`: odluke o tehnologijama, troškovi, model podataka, rizici
- `docs/plan.md`: plan izrade prve verzije
- `docs/PROMPTS.md`: gotovi promptovi za Claude Code po fazama
- `CLAUDE.md`: pravila rada i privatnosti
- **Figma (4 zaslona, klikabilan prototip):** https://www.figma.com/design/ak5nDaMh1rsZdqkYiu8TDb

## Pokretanje

Potrebno: Node.js 20 ili noviji i Git. Iz korijena repozitorija:

```bash
npm install
npm run build
npm test
```

Učitavanje ekstenzije u Chrome: otvorite `chrome://extensions`, uključite "Developer mode", kliknite "Load unpacked" i odaberite mapu `extension/.output/chrome-mv3`. Na `chatgpt.com` se dolje desno pojavi oznaka "Chatify je aktivan", a u konzoli poruka `[Chatify] content script active`.

Razvoj s automatskim osvježavanjem: `npm run dev -w extension`. Sve naredbe su u `CLAUDE.md`.

## Poznata ograničenja

- Ne vidi mobilne i desktop AI aplikacije ni pozive API-ja iz koda.
- Točan broj tokena nije moguć iz preglednika, samo procjena iz duljine teksta.
- Ovisi o strukturi stranice AI alata i može se slomiti kad alat promijeni sučelje; zato postoje dnevni Playwright testovi i rezervni okvir za lijepljenje prompta.
- Ovo nije pravni savjet. Prije komercijalne upotrebe potrebni su politika privatnosti, ugovor o obradi podataka i provjera pravila o nadzoru zaposlenika. Treba provjeriti i uvjete korištenja AI alata o dodacima za preglednik.
