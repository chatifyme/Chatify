# Chatify – upute za Claude

Chatify je ekstenzija za preglednik (Chrome/Edge) koja zaposlenicima pomaže pisati bolje promptove i zaustavlja slanje osjetljivih podataka u AI alate; firmi daje agregirane uvide. Ciljamo mala i srednja poduzeća u EU-u.

Prije rada pročitaj: `README.md`, `docs/plan.md` (plan), `docs/ARCHITECTURE.md` (odluke o tehnologijama i zašto) i `docs/PROMPTS.md` (faze izrade). Radimo **fazu po fazu**, redom iz `docs/PROMPTS.md`.

## Jezik

- S nama komuniciraj na hrvatskom.
- Kod, nazive varijabli, komentare i commit poruke piši na engleskom.
- Tekstovi u sučelju (UI copy) su na hrvatskom i drže se u jednoj datoteci prijevoda po aplikaciji, nikad zapisani izravno u komponente (`hr` zadano, `en` pripremljeno).

## Pravila privatnosti (tvrda, ne kršiti)

1. Sadržaj prompta **nikad** ne napušta preglednik osim kad korisnik sam klikne "Poboljšaj", i tada tek nakon što su osjetljivi podaci zamijenjeni oznakama (`[OIB]`, `[IBAN]`, `[KLJUČ]`).
2. Na server idu samo agregirani događaji: tim, alat, tjedan, ocjena, **vrsta** zaustavljenog podatka. Nikad sam podatak i nikad tekst prompta. Nijedan stupac u bazi ne smije moći sadržavati tekst prompta.
3. Osjetljivi podaci se prepoznaju lokalno regularnim izrazima i kontrolnim zbrojevima, bez AI-ja.
4. API ključ za jezični model nikad ne ide u ekstenziju ni u dashboard; samo u Cloudflare Worker kao secret.
5. Ništa u logovima, testovima, fixtureima ni primjerima ne smije sadržavati stvarne OIB-ove, IBAN-e ili ključeve. Koristi izmišljene vrijednosti koje prolaze kontrolni zbroj (vidi "Testni podaci").
6. Pregled po zaposleniku je isključen prema zadanim postavkama i uključuje se samo uz pristanak zaposlenika.
7. **Točne tvrdnje o modelu.** Dobavljač modela po zadanim postavkama može zadržati zahtjeve do 30 dana i ne koristi ih za treniranje; potpuno isključenje pohrane (Zero Data Retention) traži posebno odobrenje dobavljača. Zato u sučelju, README-u i politici privatnosti **nikad** ne piši "ništa se ne sprema". Piši točno: "prompt se šalje tek na vaš klik, nakon zamjene osjetljivih podataka oznakama; dobavljač modela ga ne koristi za treniranje i može ga zadržati do 30 dana".
8. **Izolacija firmi (multi-tenant).** Svaka tablica s podacima firme ima Row Level Security. Backend uvijek poziva bazu s JWT-om korisnika, tako da RLS vrijedi. Service role ključ smije se koristiti samo u iznimnim, dokumentiranim slučajevima (webhook naplate, tjedni izvještaj) i nikad u kodu koji obrađuje korisnički unos. Svaka RLS politika ima test koji dokazuje da firma A ne vidi podatke firme B.
9. Worker prije slanja na model **ponovno** pokreće iste detektore nad primljenim tekstom i odbija zahtjev (400) ako pronađe osjetljiv podatak (obrana u dubinu).

## Pravila ekstenzije

- Manifest V3. Tražimo pristup samo domenama AI alata (za početak `chatgpt.com`) i našoj domeni, nikad `<all_urls>`. Svaka nova dozvola traži obrazloženje.
- Bez daljinskog izvršavanja koda. Pravila za pronalaženje polja za unos su podaci (JSON), ne kod.
- Polje za unos traži se po ulozi (uređivo polje pri dnu stranice), ne po generiranim imenima klasa. Ne izmišljaj selektore: **otvori stvarnu stranicu** i provjeri.
- Ako polje nije pronađeno, prikaži rezervni okvir za lijepljenje prompta umjesto da zašutiš.
- Bojanje prompta preko CSS Custom Highlight API-ja, bez mijenjanja HTML-a stranice.
- Sučelje (panel, prozor upozorenja) ide u Shadow DOM da se stilovi stranice i naši ne miješaju.
- Korisnik uvijek odlučuje: nikad sam ne mijenjaj prompt i ne šalji ništa bez klika.

### Poznate zamke (pročitaj prije rada na adapterima)

- Polje za unos na ChatGPT-u i Claudeu je `contenteditable` (ProseMirror), ne `<textarea>`. Tekst mijenjaj **samo preko korisničkih događaja** (`document.execCommand('insertText')` nad odabranim rasponom ili `beforeinput`/paste). Izravno postavljanje `textContent`/`innerHTML` slomi editor.
- Presretanje slanja: Enter i klik na gumb za slanje hvataj u **capture fazi** (`addEventListener(..., true)`), pozovi `preventDefault()` i `stopPropagation()` kad treba prikazati upozorenje; nakon odluke korisnika ponovno pošalji događaj.
- CSS Custom Highlight API: stil `::highlight()` mora biti u **dokumentu stranice** (ubaci `<style>` u stranicu ili `adoptedStyleSheets`), a ne unutar Shadow DOM-a; rasponi (`Range`) moraju pripadati istom dokumentu kao tekst. UI se crta u Shadow DOM-u, bojanje teksta u dokumentu stranice.
- Hrvatski jezik: testiraj detektore i pravila na stvarnim hrvatskim rečenicama (dijakritici, padeži).

## Tehnologije (ne mijenjaj bez pitanja)

Obrazloženje svake odluke i usporedba alternativa je u `docs/ARCHITECTURE.md`.

| Dio | Tehnologija |
| --- | --- |
| Ekstenzija | TypeScript (strict), WXT, React, Tailwind, Shadow DOM |
| Zajednički kod | `shared/`: zod sheme, tipovi i **detektori osjetljivih podataka** (koriste ih ekstenzija i Worker) |
| Backend API | Cloudflare Workers + **Hono** + zod (TypeScript). Ne Express, ne poseban server. |
| Baza i autentikacija | Supabase: Postgres, Row Level Security, Supabase Auth (Google i Microsoft prijava). SQL migracije kroz Supabase CLI, tipovi generirani iz sheme. **Bez Prismae u prvoj verziji** (zaobilazi RLS). |
| Jezični model | Jeftin brzi model iza vlastitog sučelja `LlmProvider` (zamjenjiv dobavljač), strukturirani JSON izlaz validiran zodom, ograničenje potrošnje po firmi |
| Nadzorna ploča | Vite + React + React Router + TanStack Query + Recharts, statički na Cloudflare Pages (ne Next.js) |
| E-pošta | Resend (tjedni izvještaj, preko Cloudflare Cron Triggers) |
| Naplata | **Nije u prvoj verziji.** Tablice `plans` i `usage_monthly` postoje od početka; Stripe ili Paddle tek nakon pilota (Faza 10) |
| Testovi | Vitest (jedinični), Playwright (E2E i provjera polja za unos), `supabase test db` (RLS) |
| Izgradnja i CI | npm workspaces, GitHub Actions, wrangler za deploy. Docker samo lokalno (Supabase CLI ga traži), ne u produkciji. |

Ostajemo na besplatnim razinama; **ne dodavaj plaćene servise bez pitanja.** Ne dodavaj nove ovisnosti bez kratkog obrazloženja.

## Struktura

```
extension/   ekstenzija (entrypoints/, adapters/, rules/, ui/)
worker/      Cloudflare Worker (Hono): /v1/events, /v1/improve, cron izvještaj
dashboard/   nadzorna ploča (Vite + React)
shared/      zod sheme, tipovi, detektori osjetljivih podataka (čisti TS, s testovima)
supabase/    migracije, RLS politike, testovi baze
e2e/         Playwright testovi
docs/        plan, arhitektura, promptovi po fazama
```

Detektori i pravila su **čisti moduli bez ovisnosti o pregledniku** da se testiraju u Vitestu i dijele s Workerom.

## Naredbe

Sve iz korijena repozitorija (npm workspaces). Node.js 24 LTS (`.nvmrc`), najmanje 22.

- Instalacija: `npm install` (pokreće i `wxt prepare` za tipove ekstenzije)
- Svi testovi: `npm test` (Vitest, projekti `shared` i `extension`); pokrivenost: `npm run test:coverage`
- Provjera tipova: `npm run typecheck`
- Lint i formatiranje: `npm run lint` (ESLint + Prettier provjera); popravak formata: `npm run format`
- Build: `npm run build` (Chrome i Edge, izlaz u `extension/.output/chrome-mv3` i `edge-mv3`)
- Razvoj ekstenzije: `npm run dev -w extension` (Edge: `npm run dev:edge -w extension`)
- Razvoj Workera: `npm run dev -w worker` (nastaje u Fazi 5, još ne postoji)
- Razvoj ploče: `npm run dev -w dashboard` (nastaje u Fazi 7, još ne postoji)

## Način rada

- Radi u malim koracima i nakon svakog koraka pokreni testove prije commita.
- Prije svake faze kratko napiši plan (što ćeš raditi i koje datoteke dirati) i čekaj odobrenje kad se mijenja arhitektura ili struktura mapa.
- Za svaki detektor podataka prvo napiši testove (valjani i nevaljani primjeri), zatim kod.
- Jedan commit = jedna logična promjena. Poruke u obliku `feat:`, `fix:`, `test:`, `docs:`, `chore:`.
- Nikad ne radi `git push --force` i ne mijenjaj povijest bez izričitog odobrenja.
- Nikad ne spremaj tajne u repozitorij. Koristi `.env.local` (u `.gitignore`), Wrangler secrets i `.env.example` s praznim vrijednostima.
- Kad nešto nije jasno (ime proizvoda, pravno pitanje, izbor kupca, izbor modela), pitaj umjesto da pogađaš.
- Nakon svake faze: lint, typecheck, test, ažuriraj README (kvačice u planu razvoja) i commit.

## Testni podaci (izmišljeni, provjereni)

Koristi ove vrijednosti u testovima; nikad stvarne podatke. Mogu se slučajno poklopiti sa stvarnima, zato se ne koriste izvan testova.

| Vrijednost | Vrsta | Očekivano |
| --- | --- | --- |
| `12345678903` | OIB | valjan |
| `69435151530` | OIB | valjan |
| `12345678900` | OIB | **nevaljan** (kriva kontrolna znamenka) |
| `HR1210010051863000160` | IBAN (HR) | valjan |
| `HR1210010051863000161` | IBAN (HR) | **nevaljan** |
| `GB82WEST12345698765432` | IBAN (GB) | valjan |

OIB ima 11 znamenki i kontrolnu znamenku po ISO 7064 (MOD 11,10). Hrvatski IBAN ima 21 znak, a svaki IBAN mora zadovoljiti mod 97. Detektor izbjegava lažne uzbune (proizvoljan 11-znamenkasti broj koji nije valjan OIB, telefonski brojevi) i prepoznaje varijante s razmacima (`HR12 1001 0051 8630 0016 0`).

## Dizajn

Figma prototip (4 zaslona): https://www.figma.com/design/ak5nDaMh1rsZdqkYiu8TDb

Chatify **nije zasebna aplikacija za pisanje prompta**: radi unutar ChatGPT stranice kao dodatak preglednika (oznaka u okviru za unos, panel s prijedlozima, prozor upozorenja). Jedina zasebna aplikacija je web nadzorna ploča za admina firme.

Indigo `#4F46E5` kao primarna boja, font Inter, zaobljeni kutovi (8–18 px). Boje oznaka u promptu:

| Vrsta | Pozadina | Tekst |
| --- | --- | --- |
| Nejasno | `#FEF3C7` | `#92400E` |
| Fali kontekst | `#DBEAFE` | `#1D4ED8` |
| Kontradikcija | `#FFE4E6` | `#BE123C` |
| Osjetljivi podatak | `#FEE2E2` | `#B91C1C` |

## Što NE radimo u prvoj verziji

Mobilne i desktop AI aplikacije, snimanje ekrana, točno brojanje tokena po zaposleniku, pregled po osobi bez pristanka, plaćene usluge, vlastiti Express server, Docker u produkciji, naplata (Stripe/Paddle), ChatGPT "plugin" (ne postoji više, vidi `docs/ARCHITECTURE.md`).

## Poznata ograničenja (ne obećavaj ono što ekstenzija ne može)

- Ne vidi mobilne i desktop AI aplikacije ni pozive API-ja iz koda.
- Točan broj tokena nije moguć iz preglednika, samo procjena iz duljine teksta.
- Lomi se kad AI alat promijeni sučelje; zato postoje dnevni Playwright testovi i rezervni okvir.
