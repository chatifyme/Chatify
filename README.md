# Chatify
A startup focused on improving the accuracy, reliability, and security of AI usage in businesses

# Chatify

> AI koučing za zaposlenike i zaštita osjetljivih podataka za firme. Ekstenzija za preglednik koja pomaže pisati bolje promptove i zaustavlja slanje osjetljivih podataka u AI alate.

**Status:** u razvoju (faza dizajna i planiranja) · **Naziv:** radni · **Licenca:** još nije odabrana

---

## Sadržaj

- [O projektu](#o-projektu)
- [Funkcije](#funkcije)
- [Kako radi](#kako-radi)
- [Privatnost](#privatnost)
- [Tehnologije](#tehnologije)
- [Plan razvoja](#plan-razvoja)
- [Struktura repozitorija](#struktura-repozitorija)
- [Dizajn i dokumentacija](#dizajn-i-dokumentacija)
- [Pokretanje](#pokretanje)
- [Doprinos](#doprinos)
- [Poznata ograničenja](#poznata-ograničenja)

---

## O projektu

Zaposlenici sve češće koriste ChatGPT, Claude i Gemini, ali bez smjernica i često preko osobnih računa. Posljedica su loši promptovi (nejasni, bez konteksta, kontradiktorni) i osjetljivi podaci (OIB, IBAN, API ključevi) zalijepljeni u vanjske alate.

Chatify rješava oba problema na mjestu gdje nastaju, u pregledniku, prije nego se prompt pošalje.

**Po čemu se razlikujemo:** većina postojećih alata dolazi iz sigurnosti i nadzora za velike firme. Chatify dolazi iz edukacije i produktivnosti, obrađuje osjetljive podatke lokalno u pregledniku i cilja mala i srednja poduzeća u EU-u.

## Funkcije

| Funkcija | Što radi |
| --- | --- |
| **Provjera prompta** | Boji nejasne dijelove, one kojima fali kontekst i kontradikcije; predlaže popravke i daje ocjenu 0–100. Ne piše umjesto korisnika, korisnik odlučuje. |
| **Upozorenje o osjetljivim podacima** | Prije slanja prepoznaje OIB, IBAN, API ključeve i e-mail adrese; nudi zamjenu oznakama, uređivanje ili slanje svejedno. |
| **Nadzorna ploča** | Aktivni korisnici, prosječna kvaliteta promptova, zaustavljeni osjetljivi podaci, procjena uštede vremena, pregled po timovima i tjedne preporuke. |
| **Politike** | Admin bira koja se pravila primjenjuju i što se događa kad se podatak pronađe: zamijeni, blokiraj ili upozori. |

## Kako radi

```
   Preglednik zaposlenika (lokalno)
  ┌─────────────────────────────────┐
  │  Detektori osjetljivih podataka │──┐
  │  Pravila kvalitete prompta      │  │  samo agregirani
  └──────────────┬──────────────────┘  │  događaji
                 │ na klik "Poboljšaj" │
                 ▼                     ▼
        ┌────────────────┐      ┌─────────────┐      ┌──────────────────┐
        │ Cloudflare     │      │  Supabase   │ ───▶ │ Nadzorna ploča   │
        │ Worker         │      │  (Postgres) │      │ (Next.js)        │
        └───────┬────────┘      └─────────────┘      └──────────────────┘
                ▼
        ┌────────────────┐
        │ Jezični model  │
        │ (bez pohrane)  │
        └────────────────┘
```

1. Ekstenzija prati polje za unos na podržanim AI stranicama.
2. Detektori i pravila rade **lokalno**, bez slanja teksta bilo gdje.
3. Samo kad korisnik klikne "Poboljšaj", prompt (nakon zamjene osjetljivih podataka oznakama) ide preko posrednika na jezični model.
4. Na server idu samo anonimni, agregirani događaji (tim, alat, tjedan, ocjena, vrsta zaustavljenog podatka).

## Privatnost

| Podatak | Gdje se obrađuje | Što se sprema |
| --- | --- | --- |
| Osjetljivi podaci u promptu | Lokalno u pregledniku | Samo vrsta ("OIB pronađen"), nikad sam podatak |
| Ocjena kvalitete (pravila) | Lokalno | Broj ocjene |
| Prijedlozi "Poboljšaj" | Server, tek na klik, nakon zamjene oznakama | Ništa; kod dobavljača modela isključena pohrana |
| Korištenje po timu | Server | Tim, alat, tjedan, ocjena, vrsta zaustavljenog podatka |

Pregled po pojedinom zaposleniku isključen je prema zadanim postavkama i uključuje se samo uz pristanak svakog zaposlenika.

## Tehnologije

| Sloj | Tehnologija |
| --- | --- |
| Ekstenzija | TypeScript, [WXT](https://wxt.dev) (Manifest V3, Chrome i Edge) |
| Sučelje u ekstenziji | React, Tailwind, Shadow DOM |
| Bojanje prompta | CSS Custom Highlight API |
| Detektori | Regularni izrazi + kontrolni zbrojevi (OIB, IBAN mod 97, prefiksi ključeva) |
| Backend i prijava | Supabase (Postgres) |
| Posrednik prema modelu | Cloudflare Workers |
| Nadzorna ploča | Next.js, Recharts, Cloudflare Pages |
| E-pošta | Resend |
| Testovi | GitHub Actions, Playwright (dnevna provjera da ekstenzija pronalazi polje za unos) |

Cilj je prvih šest mjeseci ostati na besplatnim razinama (procjena troškova ispod 100 €).

## Plan razvoja

- [ ] **Tjedni 1–2, Osnova:** čitanje polja za unos na jednom alatu (ChatGPT), prvi dokaz da radi, razgovori s firmama
- [ ] **Tjedni 3–4, Zaštita podataka:** detektori (OIB, IBAN, ključevi), bojanje, prozor s upozorenjem, zamjena oznakama → *demo prvim firmama*
- [ ] **Tjedni 5–6, Prompt checker:** pravila bez AI-ja, gumb "Poboljšaj", panel s ocjenom
- [ ] **Tjedni 7–8, Backend i ploča:** prijava firme, nadzorna ploča, politike, objava ekstenzije (unlisted) → *pilot s 3–5 firmi*
- [ ] **Nakon pilota:** Claude i Gemini, Edge, dodatne funkcije

## Struktura repozitorija

Planirana struktura (mijenja se tijekom razvoja):

```
chatify/
├── extension/        # ekstenzija za preglednik (WXT, TypeScript, React)
│   ├── detectors/    # OIB, IBAN, ključevi, e-mail (s testovima)
│   └── rules/        # pravila kvalitete prompta
├── worker/           # Cloudflare Worker (posrednik prema modelu)
├── dashboard/        # nadzorna ploča (Next.js)
├── supabase/         # shema baze i migracije
├── docs/             # dokumentacija i plan
└── README.md
```

## Dizajn i dokumentacija

- **Figma (4 zaslona, klikabilan prototip):** https://www.figma.com/design/ak5nDaMh1rsZdqkYiu8TDb
- **Plan izrade prve verzije (MVP):** https://claude.ai/artifact/HFdpPu7bwp4RUaLGCEKsM9

## Pokretanje

Kod još nije napisan. Upute za instalaciju i pokretanje dodat će se čim bude prva radna verzija ekstenzije.

## Doprinos

Projekt je u ranoj fazi i radi ga manji tim. Prijedloge i ideje možete otvoriti kao *Issue*. Upute za doprinos i pravila koda dodat će se kasnije.

## Poznata ograničenja

- Ekstenzija ne vidi mobilne i desktop AI aplikacije ni pozive API-ja iz koda.
- Točan broj tokena po zaposleniku nije moguć iz preglednika, dostupna je samo procjena iz duljine teksta.
- Ekstenzija ovisi o strukturi stranice AI alata, pa se može slomiti kad alat promijeni sučelje; zato postoje dnevni automatski testovi i rezervni okvir za lijepljenje prompta.
- Ovo nije pravni savjet. Prije komercijalne upotrebe potrebne su politika privatnosti, ugovor o obradi podataka i provjera pravila o nadzoru zaposlenika.
