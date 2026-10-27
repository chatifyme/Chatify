# Arhitektura i odluke o tehnologijama

Cilj: najniži mogući trošak uz najvišu kvalitetu, za tim studenata koji gradi B2B proizvod za firme. Ovaj dokument kaže **što koristimo, zašto, i što smo namjerno odbacili**.

Činjenice označene s (provjereno) provjerene su na službenim stranicama u listopadu 2026.; ostalo su procjene i treba ih provjeriti prije odluke.

## 1. Sažetak odluke

Proizvod je **ekstenzija za preglednik** koja radi unutar ChatGPT stranice, plus **mala web aplikacija za admina**. Sve ostalo je minimalan, gotovo besplatan backend:

```
Preglednik zaposlenika (ChatGPT stranica + Chatify ekstenzija)
   │  detektori i pravila rade LOKALNO
   │
   ├── agregirani događaji ──────▶ Cloudflare Worker (Hono) ──▶ Supabase Postgres (RLS)
   │                                      ▲                            ▲
   └── "Poboljšaj" (na klik, očišćen      │                            │
        tekst) ──────────────────▶ Worker ──▶ jezični model            │
                                                                       │
Admin firme ──▶ Dashboard (Vite SPA, Cloudflare Pages) ────────────────┘
                (supabase-js s JWT-om admina, RLS)
```

Nema vlastitog servera, nema Dockera u produkciji i nema ORM-a između aplikacije i baze.

## 2. Ocjena predložene liste

| Predloženo | Ocjena | Odluka |
| --- | --- | --- |
| Node.js + TypeScript + Express | Kod da, Express ne | **Hono na Cloudflare Workers.** Isti TypeScript, isti REST i middleware koncepti, ali bez servera za plaćati i održavati. Express traži stalno pokrenut proces (hosting od nekoliko eura mjesečno i održavanje). Hono kod se kasnije lako prenosi na Node ako zatreba. |
| PostgreSQL + Prisma | Postgres da, Prisma ne | **Supabase Postgres + SQL migracije + generirani tipovi.** Prisma se spaja izravno na bazu i zaobilazi Row Level Security, pa bi izolaciju firmi morali ručno provoditi u svakom upitu; jedna greška znači da firma A vidi podatke firme B. To je najveći sigurnosni rizik B2B proizvoda. Uz to, Prisma na Workerima dodaje složenost. Ako kasnije zatreba ORM, uzmite Drizzle. |
| AI: model API, npr. OpenAI | Da, uz ispravak | **Iza vlastitog sučelja `LlmProvider`**, s jeftinim brzim modelom i strukturiranim JSON izlazom. Dobavljača biramo mjerenjem na hrvatskim primjerima (Faza 6), ne pogađanjem. Vidi odjeljak 5 o zadržavanju podataka. |
| Autentikacija: JWT ili upravljani auth | Upravljani | **Supabase Auth** s prijavom preko Googlea i Microsofta (firme koriste Workspace ili M365). Vlastiti JWT sustav je gotovo uvijek lošiji od upravljanog i dodatan sigurnosni rizik. Besplatna razina: 50.000 aktivnih korisnika mjesečno (provjereno, izvor trećih strana). |
| Plaćanje: Stripe | Rano, ne u v1 | **Prvih 3 do 5 pilota naplaćujete računom** (ili besplatno). Naplata tek kad ih nekoliko potvrdi da bi platili. Ali **ograničenja planova ugradite odmah** (tablice `plans` i `usage_monthly`) da se naplata kasnije samo priključi. Za EU B2B razmotrite i Paddle ili Lemon Squeezy, koji kao "merchant of record" rješavaju PDV; provjerite dostupnost Stripea za vašu zemlju i vrstu tvrtke. |
| Deployment: Docker + cloud hosting | Ne treba | Workers, Pages i Supabase su upravljani i deployaju se preko GitHub Actions i `wrangler`. **Docker samo lokalno** (Supabase CLI ga koristi). |
| ChatGPT integracija: "Plugin Creator" | **Ne postoji, i ne bi riješio problem** | Vidi odjeljak 3. |

### Dodatne promjene koje preporučujemo

- **Nadzorna ploča: Vite + React umjesto Next.js.** Ploča je prijavljena admin aplikacija bez potrebe za renderiranjem na serveru, pa je statički SPA jeftiniji, jednostavniji i radi besplatno na Cloudflare Pages. Next.js na Cloudflareu traži dodatni adapter. Za javnu početnu stranicu kasnije uzmite Astro (statički).
- **`shared/` paket** sa zod shemama i detektorima. Ekstenzija i Worker koriste isti kod, pa Worker može **ponovno provjeriti** da u tekstu za model nema osjetljivih podataka (obrana u dubinu).
- **Ograničenje potrošnje modela po firmi** (tablica `usage_monthly` i mjesečna kapa) da jedna firma ne može potrošiti cijeli budžet.
- **Dnevni Playwright test** polja za unos na ChatGPT-u, jer je lomljenje zbog promjene sučelja stalan rizik.

## 3. Što je s "ChatGPT pluginom"

ChatGPT plugini više ne postoje: beta je najavljena u ožujku 2023., a sustav je potpuno ugašen **9. travnja 2024.** (izvor: [pregled promjena](https://www.getdrio.com/blog/chatgpt-plugins-vs-custom-gpts)). Zamijenili su ih Custom GPT-ovi s Actions i, od 2025., aplikacije temeljene na MCP-u.

Ali ni oni ne rješavaju naš problem. Takve integracije poziva **model kad odluči** da mu zatreba alat, što znači nakon što je korisnik već poslao poruku. Nemaju način da vide ni zaustave ono što korisnik upravo tipka. (Ovo je naš zaključak iz načina rada tih integracija, a ne izravna tvrdnja iz izvora; prije oslanjanja provjerite u dokumentaciji.) Provjera prompta i zaustavljanje osjetljivih podataka **prije slanja** moguće je samo kodom koji radi u samoj stranici, a to je **ekstenzija preglednika**.

Zato je "integracija s ChatGPT-om" u našem proizvodu = content script ekstenzije. Jedna opcionalna kasnija ideja (Faza 12): Custom GPT ili MCP aplikacija "Chatify Coach" kojoj korisnik izričito zalijepi prompt i traži savjet. To je dodatni kanal, ne zamjena.

## 4. Tok autentikacije

1. Korisnik u ekstenziji klikne "Prijava". Ekstenzija otvara Supabase OAuth (Google ili Microsoft) preko `chrome.identity.launchWebAuthFlow`. To traži dozvolu `identity`, koja je dopuštena i mala.
2. Sesija (access i refresh token) sprema se u `chrome.storage.local`, nikad u `sync`.
3. Pridruživanje firmi: admin šalje pozivni kod ili e-poštu; korisnik ga unosi pri prvoj prijavi.
4. Worker na svakom zahtjevu provjerava Supabase JWT, pa bazu poziva **s tim JWT-om** (ne service role ključem), tako da RLS vrijedi.
5. Dashboard koristi isti Supabase Auth; admin vidi samo svoju firmu zahvaljujući RLS-u.

## 5. Jezični model: cijena, kvaliteta, privatnost

- **Kvaliteta na hrvatskom** nije zajamčena ni za jedan model; Faza 6 uključuje malu evaluaciju (oko 30 izmišljenih hrvatskih promptova s očekivanim oznakama) koja mjeri točnost, ispravnost JSON-a i trošak po 1000 zahtjeva. Biramo **najjeftiniji model koji prolazi prag**.
- **Zadržavanje podataka (provjereno za OpenAI):** zapisi za praćenje zlouporabe zadržavaju se do 30 dana po zadanim postavkama, a podaci poslani API-ju ne koriste se za treniranje osim ako sami to uključite. **Zero Data Retention** dostupan je samo odobrenim korisnicima i traži kontakt s prodajom ([izvor](https://developers.openai.com/api/docs/guides/your-data)). Studentski tim vjerojatno neće dobiti ZDR odmah.
  - **Posljedica:** ne smijemo tvrditi "ništa se ne sprema". Točna tvrdnja i način zaštite: u model ide samo mali dio teksta, tek na klik, i **nakon zamjene osjetljivih podataka oznakama**, uz ugovor o obradi podataka s dobavljačem. Provjerite uvjete svakog dobavljača koji razmatrate.
  - Isto vrijedi za Anthropic, Mistral i ostale: uvjete zadržavanja treba pročitati, ne pretpostaviti.
- **Troškovi:** kratki zahtjevi na maloj modelskoj razini koštaju vrlo malo po pozivu, ali ukupno ovisi o broju korisnika. Zato kapa po firmi i brojanje potrošnje od prvog dana.
- **Alternativa za osjetljive firme:** kasnije ponuditi da Worker koristi model unutar firme kupca. Ne za prvu verziju.

## 6. Model podataka (sažetak)

Detaljna shema piše se u Fazi 5. Načela: svaka tablica ima `org_id`, RLS je uključen svugdje, nijedan stupac ne može sadržavati tekst prompta.

| Tablica | Svrha |
| --- | --- |
| `organizations` | firma |
| `teams` | timovi unutar firme |
| `members` | korisnik (`auth.users`), firma, tim, uloga (`admin` ili `member`), `pseudo_id`, `consent_individual_view` (zadano `false`) |
| `invites` | pozivni kodovi |
| `events` | `org_id`, `team_id`, `pseudo_id`, `tool`, `week`, `quality_score`, `blocked_type`, `action`, `created_at` |
| `policies` | pravilo, radnja (`replace`, `block`, `warn`), uključeno |
| `plans` | plan firme i ograničenja (broj mjesta, broj "Poboljšaj" poziva mjesečno) |
| `usage_monthly` | potrošnja po firmi i mjesecu (pozivi, tokeni) |

Nadzorna ploča čita **agregirane poglede** (views ili RPC funkcije koje vraćaju samo zbrojeve), ne sirove događaje, osim za članove s pristankom.

## 7. Troškovi

| Stavka | Faza pilota | Kad se mijenja |
| --- | --- | --- |
| Cloudflare Workers | 0 €; besplatna razina: 100.000 zahtjeva dnevno i 10 ms CPU vremena po zahtjevu (provjereno). Čekanje odgovora modela uglavnom ne troši CPU vrijeme, ali to izmjerite. | Kad prijeđete dnevni limit, plaćeni plan |
| Cloudflare Pages, Cron Triggers | 0 € | |
| Supabase | 0 €; besplatna razina: 500 MB baze, 50.000 aktivnih korisnika, **pauziranje nakon 7 dana neaktivnosti, bez automatskih sigurnosnih kopija** (provjereno, izvor trećih strana) | **Prije prve naplaćene firme prijeđite na Pro (oko 25 $ mjesečno)** zbog kopija i bez pauziranja |
| Jezični model | nekoliko eura mjesečno za pilot (procjena) | Raste s brojem korisnika; kontrolirano kapom po firmi |
| Resend (e-pošta) | besplatna razina | |
| GitHub Actions, Playwright | besplatno za privatne repozitorije do kvote (provjerite) | |
| Chrome Web Store razvojni račun | oko 5 $ jednokratno (nije potvrđeno na službenoj stranici) | |
| Domena | oko 10 do 15 € godišnje (procjena) | |
| Pravni predlošci i savjet | jedna konzultacija | |

Okvirno: **ispod 30 € mjesečno** tijekom pilota, uz jednokratnu domenu i trgovinu, a **oko 30 do 60 € mjesečno** kad krenu prve plaćene firme (Supabase Pro i model). Sve su to procjene; potvrdite cijene prije odluke.

## 8. Kad što nadograditi

| Okidač | Nadogradnja |
| --- | --- |
| Prva firma koja plaća | Supabase Pro, sigurnosne kopije, ugovor o obradi podataka |
| Dnevni limit Workera dosegnut | Plaćeni Workers plan |
| Tri firme potvrde da bi platile | Faza 10: naplata (Stripe ili Paddle) |
| Firme traže SSO i revizijske zapise | Dodatne Supabase mogućnosti ili Clerk, po potrebi |
| Firma ne želi slanje na vanjski model | Model unutar firme kupca |
| Potrebna javna početnica | Astro statička stranica |

## 9. Glavni rizici

| Rizik | Ublažavanje |
| --- | --- |
| Curenje podataka između firmi | RLS na svakoj tablici, backend uvijek s JWT-om korisnika, testovi izolacije |
| Pogrešna tvrdnja o privatnosti | Pravilo 7 u `CLAUDE.md`; sav tekst o privatnosti prolazi pregled |
| Promjena sučelja ChatGPT-a | Dnevni E2E test, pravila kao JSON podaci, rezervni okvir |
| Trošak modela | Kapa po firmi, brojanje tokena, mali modeli, kratki ulazi |
| Besplatne razine nestanu ili se promijene | Kod je prenosiv (Hono, Postgres); plan prijelaza u odjeljku 8 |
| Pravni rizik nadzora zaposlenika | Lokalna obrada, samo agregati, pristanak za pregled po osobi, obavijest zaposlenicima, savjet pravnika |

## Izvori

- [Pregled ChatGPT pluginova, Custom GPT-ova i MCP aplikacija](https://www.getdrio.com/blog/chatgpt-plugins-vs-custom-gpts)
- [OpenAI: Your data (zadržavanje i Zero Data Retention)](https://developers.openai.com/api/docs/guides/your-data)
- [Cloudflare Workers: ograničenja](https://developers.cloudflare.com/workers/platform/limits)
- [Supabase: pregled cijena i ograničenja 2026.](https://www.jetadmin.io/blog/supabase-pricing-2026-guide-to-plans-limits-and-real-world-costs/)
