# Prompt po fazama za Claude Code

Ovo su gotovi promptovi koje redom kopiraš u Claude Code. Svaki je zaokružena faza s kriterijem "gotovo kad". **Ne prelazi na sljedeću fazu dok prethodna nije prošla provjeru.**

Pravila koja vrijede u svakoj fazi su u `CLAUDE.md`: prvo plan, zatim kod, testovi uz kod, na kraju lint, typecheck i test, ažuriranje README-a i commit. Odluke o tehnologijama i razlozi su u `docs/ARCHITECTURE.md`.

## Kako početi (jednom)

1. Na GitHubu otvori privatni repozitorij `chatify` i kloniraj ga:
   ```bash
   git clone https://github.com/<tvoje-korisnicko-ime>/chatify.git
   cd chatify
   ```
2. Raspakiraj zip u korijen (`README.md`, `CLAUDE.md`, `docs/`), pa:
   ```bash
   git add . && git commit -m "docs: add README, CLAUDE.md and build prompts" && git push
   ```
3. Instaliraj Node.js (LTS) i Docker (samo za lokalni Supabase), pa pokreni Claude Code u mapi projekta:
   ```bash
   claude
   ```
   `CLAUDE.md` se učita automatski.
4. Zalijepi **Fazu 0**.

Prije Faze 5 treba ti: besplatan Supabase račun, besplatan Cloudflare račun i (za Fazu 6) API ključ jednog dobavljača modela. Claude Code će te pitati kad zatreba.

Savjet: nakon svake faze pokreni novu sesiju (`/clear`) da kontekst ostane čist; `CLAUDE.md` i git povijest drže sve bitno.

---

## Faza 0: Temelj projekta (monorepo)

```
Pročitaj CLAUDE.md, README.md i docs/ARCHITECTURE.md. Postavi temelj projekta
kao npm workspaces monorepo prema strukturi u CLAUDE.md, ali za sada samo
pakete extension/ i shared/ (worker/, dashboard/ i supabase/ dolaze u kasnijim
fazama; napravi samo prazne mape s README oznakom).

Napravi:
- korijenski package.json s workspaces, zajednički tsconfig (strict), ESLint,
  Prettier, Vitest
- shared/ kao TypeScript paket (zod kao ovisnost) s primjerom sheme i testom
- extension/: WXT ekstenzija (Manifest V3, React, Tailwind) koja se builda za
  Chrome i Edge, s praznim content scriptom samo na https://chatgpt.com/* i
  https://chat.openai.com/* (host_permissions samo te dvije domene, bez
  <all_urls>)
- i18n sloj (hr zadano, en pripremljeno) s jednim primjerom teksta
- skripte u korijenu: npm run dev -w extension, build, lint, typecheck, test
- .gitignore, .env.example (prazne vrijednosti), GitHub Actions workflow koji
  na svaki push pokreće lint, typecheck i test
- ažuriraj odjeljak "Naredbe" u CLAUDE.md sa stvarnim naredbama i README s
  uputama za pokretanje

Prvo napiši plan i pričekaj moju potvrdu.

Gotovo kad: npm install && npm run build && npm test prolaze bez grešaka,
ekstenzija se učita u Chrome (chrome://extensions, Load unpacked) i u
konzoli ChatGPT stranice se ispiše poruka da je content script aktivan.
```

---

## Faza 1: Detektori osjetljivih podataka (u shared/)

```
Implementiraj detektore osjetljivih podataka u shared/src/detectors/ kao čiste
TypeScript module bez ovisnosti o pregledniku (koristit će ih i ekstenzija i
kasnije Cloudflare Worker). Cilj je da nema lažnih uzbuna i da sve radi lokalno
bez AI-ja.

Detektori:
1. OIB: 11 znamenki + kontrolna znamenka po ISO 7064 (MOD 11,10). Samo valjani
   OIB-ovi se prijavljuju. Prepoznaj i kad je okružen tekstom (npr. "OIB
   klijenta je 12345678903.") i ne hvataj dio duljeg broja.
2. IBAN: ukloni razmake, provjeri duljinu po državi, mod 97. Hrvatski IBAN ima
   21 znak. Prepoznaj i varijantu s razmacima (HR12 1001 0051 8630 0016 0).
3. API ključevi i tajne: poznati prefiksi i oblici (sk-..., AKIA..., ghp_...,
   xoxb-..., Bearer tokeni, "-----BEGIN PRIVATE KEY-----"). Za nepoznate
   dugačke nasumične nizove koristi entropiju s oprezom i nisku pouzdanost.
4. E-mail adrese.

Svaki detektor vraća listu pogodaka { type, start, end, confidence } i NIKAD ne
logira ni vraća sam tekst pogotka izvan lokalne obrade. Napravi i redact(text,
findings) koja zamjenjuje pogotke oznakama [OIB], [IBAN], [KLJUČ], [EMAIL] i
vraća novi tekst + mapu zamjena.

Testovi (Vitest) s točno ovim vrijednostima iz CLAUDE.md: 12345678903 i
69435151530 valjani OIB; 12345678900 nevaljan; HR1210010051863000160 valjan
IBAN; HR1210010051863000161 nevaljan; GB82WEST12345698765432 valjan. Dodaj
testove za hrvatske rečenice, slučajne 11-znamenkaste brojeve koji nisu OIB,
telefonske brojeve (ne smiju biti OIB), višestruke pogotke u jednom tekstu i
redact(). Nikad stvarni podaci.

Prvo plan. Gotovo kad: svi testovi prolaze i pokrivenost detektora je iznad
90 %.
```

---

## Faza 2: Čitanje polja za unos na ChatGPT-u (adapter)

```
Napiši adapter za ChatGPT u extension/adapters/chatgpt.ts. Cilj: pouzdano
pronaći polje za unos, čitati tekst koji korisnik piše i prepoznati gumb za
slanje.

OBAVEZNO: nemoj izmišljati selektore. Otvori https://chatgpt.com (preko
preglednika ili Playwrighta), pregledaj stvarni DOM i na temelju njega napiši
logiku. Polje je contenteditable (ProseMirror), ne textarea.

Zahtjevi:
- Traženje po ulozi i atributima (contenteditable="true", role="textbox",
  blizina gumba za slanje), NE po generiranim imenima klasa.
- Sučelje adaptera koje će kasnije implementirati i Claude/Gemini:
  findInput(), getText(), onTextChange(cb), findSendButton(),
  onSubmitAttempt(cb).
- MutationObserver (uz debounce) jer ChatGPT dinamički mijenja DOM i prelazi
  između razgovora bez osvježavanja stranice.
- Rezervni okvir: ako se polje ne pronađe nakon nekoliko sekundi, prikaži mali
  plutajući okvir ("Zalijepite prompt ovdje na provjeru") u Shadow DOM-u, da
  korisnik nikad ne ostane bez zaštite.
- Pravila traženja polja drže se u zasebnom JSON-u (podaci, ne kod).
- Za sada samo logiraj tekst u konzolu u razvojnom načinu (NIKAD u produkciji).

Dodaj Playwright E2E test (e2e/). Ako test ne može raditi bez prijave u
ChatGPT, objasni zašto i predloži rješenje (npr. lokalna statička stranica
koja oponaša strukturu polja) i svakako ga napravi.

Prvo plan. Gotovo kad: adapter pouzdano čita tekst u novom i postojećem
razgovoru, preživljava navigaciju, a rezervni okvir se prikazuje kad polje
nije pronađeno.
```

---

## Faza 3: Bojanje, upozorenje i presretanje slanja

```
Povezi detektore s adapterom i napravi korisničko iskustvo upozorenja prema
zaslonu 2 u Figmi (Chatify je dodatak unutar ChatGPT stranice, ne zasebna
aplikacija).

Zahtjevi:
1. Dok korisnik piše, pokreni detektore (debounce ~150 ms) nad getText() i
   obojaj pogotke pomoću CSS Custom Highlight API. ::highlight() stil ubaci u
   DOKUMENT stranice (ne u Shadow DOM). Boja osjetljivih podataka: pozadina
   #FEE2E2, tekst #B91C1C.
2. Mala Chatify oznaka u donjem redu ChatGPT-ovog okvira za unos ("Chatify · 3
   osjetljiva podatka") i značka na ikoni ekstenzije.
3. Kad korisnik pokuša poslati (Enter ili klik na gumb), presretni u capture
   fazi. Ako ima pogodaka, spriječi slanje i prikaži prozor upozorenja u Shadow
   DOM-u s popisom pronađenih podataka (vrsta + zamjenska oznaka; podatak se
   prikazuje samo lokalno u prozoru), porukom o politici firme i tri radnje:
   "Zamijeni oznakama i pošalji", "Uredi prompt" i "Pošalji svejedno".
4. "Zamijeni oznakama" mijenja tekst u polju SAMO preko korisničkih događaja
   (execCommand('insertText') nad odabranim rasponom ili beforeinput), NE
   izravnim postavljanjem textContent/innerHTML. Zatim ponovno pokreni slanje.
5. Dostupnost: prozor se zatvara tipkom Esc, fokus ide na prvi gumb i vraća se
   u polje, kontrast boja zadovoljava WCAG AA.
6. Politike su za sada tvrdo kodirane (osobni podaci: zamijeni; ključevi:
   blokiraj; e-mail: upozori); kasnije dolaze sa servera.

Napiši testove (jedinične za logiku odluke, E2E gdje je moguće) za sve tri
radnje i za slučaj bez pogodaka (slanje prolazi neometano).

Prvo plan. Gotovo kad: unos s OIB-om i IBAN-om se oboji, slanje se zaustavi,
svaka od tri radnje radi ispravno, a običan prompt se šalje bez zastoja. To je
prva verzija koju možeš pokazati firmama.
```

---

## Faza 4: Provjera kvalitete prompta (pravila bez AI-ja) i panel

```
Napravi provjeru kvalitete prompta u extension/rules/ kao čiste module s
testovima, plus panel s prijedlozima (zaslon 1 u Figmi: panel se prikazuje
ispod ChatGPT-ovog okvira za unos, unutar stranice). Za sada BEZ AI modela.

Pravila (svako vraća { kind, start, end, message, suggestion }):
- "vague": nejasne riječi ("neki", "nešto", "onaj", "stvar", "to") bez
  konkretnog objekta
- "missing-context": upućivanje na nešto što model ne može znati ("kao prošli
  put", "onaj dogovor", "kako smo rekli")
- "contradiction": proturječni zahtjevi (npr. "kratko ali sa svim detaljima")
- "too-short": prompt ispod praga riječi
- "no-format": traži se tekst bez naznačenog formata, tona ili duljine

Ocjena 0–100 iz pogodaka i svojstava prompta (duljina, ima li cilj, kontekst,
format). Formula neka bude jednostavna, dokumentirana i pokrivena testovima.

Panel (React, Shadow DOM): kartica s ocjenom (prsten), popis prijedloga obojen
po vrsti (nejasno #FEF3C7/#92400E, fali kontekst #DBEAFE/#1D4ED8, kontradikcija
#FFE4E6/#BE123C), svaki s opisom problema i prijedlogom te gumbima "Primijeni"
i "Zanemari", te "Primijeni sve". Bojanje u tekstu kao u fazi 3. "Primijeni"
ubacuje prijedlog preko korisničkih događaja (kao u fazi 3). Panel nikad ne
piše prompt umjesto korisnika bez njegovog klika.

Hrvatski jezik: testiraj na stvarnim hrvatskim rečenicama (padeži, dijakritici).

Prvo plan. Gotovo kad: primjer iz Figme ("Napiši mi neki mail klijentu o onome
što smo se dogovorili prošli tjedan, malo formalniji, i ubaci onu cijenu,
bitno da bude kratko ali i da sadrži sve detalje.") daje oznake vague,
missing-context i contradiction, a svi testovi prolaze.
```

---

## Faza 5: Baza, prijava i događaji (Supabase + Worker)

```
Napravi supabase/ (migracije, RLS, testovi) i worker/ (Cloudflare Worker s
Hono) te prijavu i slanje događaja iz ekstenzije. Pročitaj
docs/ARCHITECTURE.md odjeljke 4 i 6. Pravila 2, 8 i 9 iz CLAUDE.md su
nepovrediva.

Baza (SQL migracije kroz Supabase CLI, lokalno preko Dockera):
- tablice: organizations, teams, members, invites, events, policies, plans,
  usage_monthly (vidi ARCHITECTURE.md odjeljak 6)
- events NE smije imati nijedan stupac koji može sadržavati tekst prompta;
  stupci s ograničenim vrijednostima (enum/check) gdje god je moguće
- Row Level Security na SVAKOJ tablici; pomoćne funkcije is_org_member() i
  is_org_admin(); admin vidi samo svoju firmu
- agregirani pogledi/RPC funkcije za nadzornu ploču koji vraćaju samo zbrojeve
- plans i usage_monthly postoje od početka (ograničenja se čitaju, naplata
  dolazi kasnije)
- testovi baze (supabase test db) koji DOKAZUJU da firma A ne vidi niti može
  mijenjati podatke firme B, za svaku tablicu
- generirani TypeScript tipovi iz sheme

Prijava (Supabase Auth, Google i Microsoft):
- ekstenzija: chrome.identity.launchWebAuthFlow, sesija u chrome.storage.local
  (ne sync), osvježavanje tokena; dozvola "identity" je jedina nova
- pridruživanje firmi preko pozivnog koda

Worker (Hono + zod):
- POST /v1/events prima grupu događaja; zod shema u shared/ je STROGA (odbija
  nepoznata polja); provjerava Supabase JWT; upisuje u bazu pozivom s JWT-om
  korisnika (NE service role); ograničenje broja zahtjeva i veličine tijela
  koje radi na besplatnoj razini Cloudflarea (bez plaćenih servisa)
- ništa se ne logira osim vrste greške i ID-a zahtjeva

Ekstenzija: klijent koji šalje samo { tool, week, quality_score, blocked_type,
action } u grupama, s ponovnim pokušajem ako nema mreže.

Test koji dokazuje da payload nikad ne sadrži tekst prompta (zod shema s
dopuštenim ključevima i vrijednostima + test koji pokušava poslati dodatna
polja i očekuje odbijanje).

Prvo plan, pa pričekaj potvrdu. Gotovo kad: događaji dolaze u bazu, RLS testovi
prolaze, strogi payload test prolazi, a lokalni razvoj radi s jednom naredbom
(opiši u README-u).
```

---

## Faza 6: Gumb "Poboljšaj" (Worker + jezični model)

```
Napravi POST /v1/improve u worker/ i gumb "Poboljšaj" u ekstenziji. Pročitaj
docs/ARCHITECTURE.md odjeljak 5 i pravila 1, 7 i 9 iz CLAUDE.md.

Worker:
- ulaz (zod, strogo): { text (max 4000 znakova), locale }; vraća strukturirane
  prijedloge { kind, quote, message, suggestion }[] validirane zodom
- prije svega: PONOVNO pokreni detektore iz shared/ nad tekstom i odbij zahtjev
  (400) ako ostane bilo kakav osjetljiv podatak
- sučelje LlmProvider u worker/src/llm/ s jednom implementacijom za početak i
  mjestom za druge; dobavljač i model biraju se varijablom okoline
- API ključ kao Wrangler secret, NIKAD u kodu ni u ekstenziji
- provjera JWT-a, ograničenje broja zahtjeva po korisniku, mjesečna kapa po
  firmi iz usage_monthly (+ globalni prekidač kroz varijablu okoline);
  zapisivanje potrošnje tokena
- timeout, ograničen broj ponovnih pokušaja, jasne greške
- nigdje ne logiraj sadržaj prompta ni odgovora
- sustavski prompt na hrvatskom: model samo predlaže popravke, ne piše umjesto
  korisnika, vraća isključivo JSON

Evaluacija modela (obavezno prije odabira):
- napravi docs/model-eval/ s oko 30 IZMIŠLJENIH hrvatskih promptova i
  očekivanim oznakama, te skriptu koja za više kandidata mjeri točnost,
  ispravnost JSON-a i trošak po 1000 zahtjeva
- NE biraj model sam; ispiši tablicu i pitaj mene (ja pokrećem skriptu sa
  svojim ključevima)

Ekstenzija:
- gumb "Poboljšaj" u panelu; prije slanja UVIJEK provjeri da su osjetljivi
  podaci zamijenjeni oznakama; ako nisu, zaustavi i pitaj
- jasna obavijest s izričitim pristankom (klik): "Prompt će biti poslan na
  obradu nakon zamjene osjetljivih podataka oznakama. Dobavljač modela ga ne
  koristi za treniranje i može ga zadržati do 30 dana." (točan tekst mora
  odgovarati pravilu 7; stvarni uvjeti dobavljača moraju biti provjereni)
- prikaz prijedloga u istom obliku kao pravila iz faze 4

Testovi: Worker (Vitest) za validaciju, odbijanje osjetljivih podataka, kapu i
JSON oblik; ekstenzija: dokaz da se bez klika ništa ne šalje.

Prvo plan. Gotovo kad: bez klika na "Poboljšaj" mreža nema nikakvog prometa s
tekstom, zahtjev s OIB-om se odbija na Workeru, s klikom stižu prijedlozi, a
ključ nigdje nije u klijentskom kodu (provjeri pretragom).
```

---

## Faza 7: Nadzorna ploča i politike (Vite + React)

```
Napravi dashboard/ kao Vite + React SPA (React Router, TanStack Query,
Recharts, Tailwind) prema zaslonima 3 i 4 u Figmi. Statički build za
Cloudflare Pages. NE Next.js.

Stranice:
- Pregled: KPI kartice (aktivni korisnici, prosječna kvaliteta prompta,
  zaustavljeni osjetljivi podaci, procijenjena ušteda vremena), graf kvalitete
  po tjednima, tablica po timovima, tjedne preporuke, razdoblje 7/30/90 dana.
- Politike: popis pravila (osobni podaci, financijski podaci, ključevi, izvorni
  kod, ugovori) s prekidačem i radnjom (zamijeni/blokiraj/upozori), postavke
  privatnosti (pregled po zaposleniku isključen zadano), opseg (timovi, alati).
  Promjene se spremaju u tablicu policies, a ekstenzija ih dohvaća.
- Prijava admina (Supabase Auth), pozivanje članova, timovi, prikaz plana i
  potrošnje ("Poboljšaj" pozivi ovaj mjesec).

Podaci isključivo iz agregiranih pogleda/RPC funkcija iz Faze 5, preko
supabase-js s JWT-om admina (RLS vrijedi). "Procijenjena ušteda vremena" mora
biti jasno označena kao procjena s objašnjenjem formule. Pregled po osobi samo
za članove koji su dali pristanak. Ploča nikad ne prikazuje ni traži sadržaj
prompta.

Tjedni izvještaj: Cloudflare Cron Trigger u worker/ + Resend; prvo ručni
okidač i predložak.

Prvo plan. Gotovo kad: ploča prikazuje stvarne agregate iz baze, admin može
promijeniti politiku i ekstenzija ju primjenjuje pri sljedećem učitavanju, a
svi prikazi poštuju RLS i pristanak (dokaži testom).
```

---

## Faza 8: Otpornost na promjene sučelja i E2E testovi

```
Napravi sustav koji nas upozori prije nego kupci primijete da je ChatGPT
promijenio sučelje.

- GitHub Actions workflow (svako jutro) koji Playwrightom otvori ChatGPT (kasnije
  Claude i Gemini) i provjeri da adapter pronalazi polje za unos, čita tekst i
  prepoznaje gumb za slanje. Ako ne uspije, otvori GitHub Issue s opisom i
  snimkom zaslona.
- Pravila traženja polja dohvaćaju se sa servera kao JSON (podaci, ne kod) s
  ugrađenom rezervnom verzijom i provjerom sheme; nevaljan odgovor se ignorira.
- Rezervni okvir iz faze 2 mora biti pokriven E2E testom.
- E2E testovi za cijeli tok: unos s osjetljivim podacima, upozorenje, zamjena,
  slanje.

Prvo plan. Gotovo kad: workflow radi po rasporedu, namjerno pokvaren selektor
izaziva upozorenje (dokaži), a pravila se mogu ažurirati bez nove verzije
ekstenzije.
```

---

## Faza 9: Objava i pravni minimum

```
Pripremi ekstenziju za objavu u Chrome Web Storeu kao neprikazanu (unlisted).

- Provjeri manifest: minimalne dozvole (domene AI alata, naša domena, identity),
  bez <all_urls>, bez daljinskog koda.
- Napiši politiku privatnosti (hrvatski i engleski) i opis jedine svrhe za
  Chrome Web Store, točno prema onome što kod stvarno radi. Pravilo 7 iz
  CLAUDE.md vrijedi: ne tvrdi "ništa se ne sprema".
- Nacrt ugovora o obradi podataka (DPA) za pravnika (jasno označi da nije
  pravni savjet).
- Skripta za produkcijski build i ZIP paket za Web Store.
- Kratke upute za firme: instalacija svim zaposlenicima preko Google Admin
  konzole (ExtensionInstallForcelist) i Microsoft Intunea.
- Sigurnost: nema tajni u repozitoriju, npm audit, CSP u manifestu.

Prvo plan. Gotovo kad: ZIP paket prolazi lokalnu provjeru zahtjeva trgovine,
dokumenti su u docs/, a README opisuje cijeli proces objave.
```

---

## Faza 10: Naplata (tek nakon pilota)

Ovu fazu NE počinji dok najmanje tri pilot firme ne potvrde da bi platile.

```
Pročitaj docs/ARCHITECTURE.md odjeljke 2 i 8. Prije koda me pitaj koji pružatelj
naplate koristimo (Stripe ili merchant-of-record poput Paddlea) i napiši kratku
usporedbu za našu situaciju (EU B2B, PDV, tvrtka u Hrvatskoj); ne pretpostavljaj
dostupnost. Zatim:

- plan i ograničenja već postoje (tablice plans i usage_monthly); poveži ih s
  naplatom: Checkout/portal za pretplatu, webhook u worker/ s provjerom
  potpisa i idempotentnošću
- webhook je JEDINO mjesto gdje se smije koristiti service role ključ; izoliraj
  ga i dokumentiraj
- ograničenja planova se provode na Workeru (broj mjesta, mjesečni "Poboljšaj"
  pozivi) s jasnim porukama korisniku
- nema pohrane podataka o karticama kod nas; sve ostaje kod pružatelja
- testovi za webhook (valjan i nevaljan potpis, dupla dostava)

Prvo plan. Gotovo kad: firma može pretplatiti plan, promjena plana mijenja
ograničenja, a testni webhook radi.
```

---

## Faza 11: Učvršćivanje prije prvih plaćenih firmi

```
Napravi sigurnosni i operativni pregled cijelog repozitorija i ispravi ono što
je očito; za sve ostalo izvijesti.

- RLS: matrica testova (svaka tablica, svaka uloga, obje firme)
- pretraga tajni (gitleaks u CI-ju), npm audit, CSP, minimalne dozvole
- provjeri da nijedan payload, log, tablica ni poruka o grešci ne može
  sadržavati tekst prompta
- sigurnosne kopije: plan prelaska na Supabase Pro ili redoviti izvoz
  agregiranih podataka; opiši postupak obnove i isprobaj ga
- praćenje troška modela i upozorenje kad firma dosegne 80 % kape
- kratki runbook za incidente (curenje podataka, pad ekstenzije, prekid
  dobavljača modela)

Izvijesti po ozbiljnosti; ne mijenjaj arhitekturu bez moje potvrde.
```

---

## Faza 12 (opcionalno): "Chatify Coach" unutar ChatGPT-a

Samo ako pilot pokaže potrebu. ChatGPT plugini više ne postoje; ovo bi bio Custom GPT ili MCP aplikacija kojoj korisnik izričito zalijepi prompt. **Ne zamjenjuje ekstenziju**, jer takve integracije ne vide ni ne zaustavljaju ono što korisnik tipka prije slanja.

```
Pročitaj docs/ARCHITECTURE.md odjeljak 3, pa u aktualnoj OpenAI dokumentaciji
provjeri trenutne mogućnosti (Custom GPT s Actions ili aplikacija na MCP-u).
Predloži najmanju verziju "Chatify Coach" koja koristi isti /v1/improve
endpoint (ista pravila privatnosti i odbijanja osjetljivih podataka) i opiši
što može i što ne može. Ne gradi ništa prije moje potvrde.
```

---

## Dodatni promptovi (kad zatreba)

**Dodavanje novog alata (Claude ili Gemini):**
```
Dodaj adapter za <Claude | Gemini> prema sučelju iz extension/adapters. Otvori
stvarnu stranicu i pregledaj DOM, ne pretpostavljaj. Dodaj domenu u
host_permissions (samo tu domenu), E2E test i stavku u dnevnu provjeru.
```

**Ispravak nakon promjene sučelja:**
```
Dnevna provjera javlja da adapter za <alat> više ne pronalazi polje za unos.
Otvori stranicu, pronađi što se promijenilo, popravi pravila traženja (podaci,
ne kod) i dodaj regresijski test.
```

**Sigurnosni pregled:**
```
Napravi sigurnosni pregled cijelog repozitorija: traži tajne, provjeri da
nijedan payload, log ili tablica ne može sadržavati tekst prompta, provjeri RLS
politike, dozvole u manifestu i ovisnosti. Izvijesti po ozbiljnosti, ne mijenjaj
kod bez moje potvrde.
```

**Pregled koda prije spajanja:**
```
Napravi pregled promjena u ovoj grani u odnosu na main: ispravnost, testovi,
kršenje načela iz CLAUDE.md (posebno privatnost i izolacija firmi),
jednostavnost. Izvijesti, ne mijenjaj.
```
