# Chatify – plan izrade prve verzije (v2)

Ažurirano 27. 10. 2026. Ovo je sažeta, ažurna verzija plana. Tehničke odluke i obrazloženja su u `ARCHITECTURE.md`, a faze izrade u `PROMPTS.md`.

## Sažetak

Chatify je ekstenzija za preglednik koja zaposlenicima pomaže pisati bolje promptove i zaustavlja slanje osjetljivih podataka u AI alate (prvo ChatGPT), a firmi svaki tjedan pokazuje kako se AI stvarno koristi. Radi **unutar ChatGPT stranice**, ne kao zasebna aplikacija. Jedina zasebna aplikacija je web nadzorna ploča za admina firme.

- **Problem:** zaposlenici koriste AI alate bez smjernica, često preko osobnih računa, i u njih lijepe OIB-ove, IBAN-e i ključeve.
- **Rješenje:** upozorenje o osjetljivim podacima prije slanja, provjera prompta (označi i predloži, ne piše umjesto korisnika), nadzorna ploča s agregiranim uvidima.
- **Razlika od konkurencije:** dolazimo iz edukacije i produktivnosti, ne iz nadzora; osjetljivi podaci obrađuju se lokalno; ciljamo mala i srednja poduzeća u EU-u, na hrvatskom.
- **Cilj prve verzije:** 3 do 5 pilot firmi koje potvrde da bi platile.

## Tržište i konkurencija

Tržište nadzora i zaštite podataka u AI alatima je zauzeto i konsolidira se; gotovo svi igrači dolaze iz sigurnosti za velike firme.

| Igrač | Pristup | Kome se obraća |
| --- | --- | --- |
| [Akamai Workforce Protector (prije LayerX)](https://www.akamai.com/products/akamai-workforce-protector) | Ekstenzija za preglednik; vidi promptove, štiti podatke, zaustavlja shadow AI | Sigurnosni timovi velikih firmi |
| Island, Palo Alto Prisma Access Browser | Cijeli sigurni preglednik s DLP-om | Velike firme koje mijenjaju preglednik |
| Nightfall AI | DLP koji otkriva i maskira osobne podatke i tajne | Sigurnosni i compliance timovi |
| Prompt Security, WitnessAI, Harmonic Security, AIM Security | Kontrola korištenja AI-ja, shadow AI, regulatorna analitika | Sigurnosni timovi, regulirani sektori |

Akamai je potvrđen na stranici proizvoda; ostale igrače treba provjeriti kod proizvođača prije javne prezentacije.

**Praznina:** edukacija umjesto nadzora; privatnost kao proizvod; mala i srednja poduzeća u EU-u s hrvatskim jezikom i cijenom prilagođenom firmama od 20 do 200 ljudi.

## Proizvod

| Funkcija | Što radi | Gdje se obrađuje |
| --- | --- | --- |
| Upozorenje o osjetljivim podacima | Prepoznaje OIB, IBAN, ključeve i e-mail prije slanja; zamjena oznakama, uređivanje ili slanje svejedno | Isključivo lokalno u pregledniku |
| Provjera prompta | Boji nejasne dijelove, fali kontekst, kontradikcije; ocjena 0–100 | Pravila lokalno; "Poboljšaj" šalje na model tek na klik |
| Nadzorna ploča | Aktivni korisnici, kvaliteta, zaustavljeni podaci, uštede, tablica po timovima, tjedne preporuke | Agregirani podaci na serveru |
| Politike | Admin bira pravila i radnju (zamijeni, blokiraj, upozori) | Postavke firme na serveru |

Korisnik uvijek odlučuje: Chatify označava i predlaže, nikad sam ne mijenja prompt i ne šalje ništa bez klika.

## Privatnost

| Podatak | Gdje se obrađuje | Što se sprema |
| --- | --- | --- |
| Osjetljivi podaci u promptu | Lokalno u pregledniku | Samo vrsta ("OIB pronađen"), nikad sam podatak |
| Ocjena kvalitete (pravila) | Lokalno | Broj ocjene |
| Prijedlozi "Poboljšaj" | Server (Worker) i dobavljač modela, tek na klik, nakon zamjene osjetljivih podataka oznakama | Mi ne spremamo ništa. **Dobavljač modela može zadržati zahtjev do 30 dana i ne koristi ga za treniranje** (potpuno isključenje traži odobrenje dobavljača) |
| Korištenje po timu | Server | Tim, alat, tjedan, ocjena, vrsta zaustavljenog podatka |

Pregled po zaposleniku je isključen zadano i uključuje se samo uz pristanak zaposlenika.

## Plan po tjednima

1. **Tjedni 1–2, osnova:** temelj projekta, detektori podataka, čitanje polja za unos na ChatGPT-u. Razgovori s firmama počinju odmah.
2. **Tjedni 3–4, zaštita podataka:** bojanje, prozor upozorenja, zamjena oznakama. **Vrata: demo prvim firmama.**
3. **Tjedni 5–6, provjera prompta:** pravila bez AI-ja, panel s ocjenom; zatim baza, prijava i događaji.
4. **Tjedni 7–8, "Poboljšaj" i ploča:** Worker s modelom, nadzorna ploča i politike, objava ekstenzije (neprikazana). **Vrata: pilot s 3 do 5 firmi.**
5. **Nakon pilota:** naplata (Faza 10), Claude i Gemini, Edge, dodatno učvršćivanje (Faza 11).

## Troškovi

Ispod 30 € mjesečno tijekom pilota, oko 30 do 60 € mjesečno kad krenu prve plaćene firme (Supabase Pro i model). Detalji i što je provjereno: `ARCHITECTURE.md`, odjeljak 7.

## Rizici

Curenje podataka između firmi (RLS i testovi izolacije), pogrešne tvrdnje o privatnosti (točan tekst o zadržavanju kod dobavljača modela), lomljenje ekstenzije zbog promjena sučelja (dnevni testovi), trošak modela (kapa po firmi), pravni rizik nadzora zaposlenika (lokalna obrada, agregati, pristanak, savjet pravnika). Detalji: `ARCHITECTURE.md`, odjeljak 9.

## Podjela posla (tim od troje)

- **Osoba 1:** ekstenzija i detektori podataka
- **Osoba 2:** Worker, baza, veza s modelom i nadzorna ploča
- **Osoba 3:** dizajn, razgovori s firmama, pravni dio i testiranje

## Sljedeći koraci

- [ ] Razgovarati s 10 do 15 firmi u prvom tjednu: bi li platile za sigurnost podataka ili za edukaciju
- [ ] Pročitati uvjete korištenja ChatGPT-a o dodacima za preglednik
- [ ] Pokrenuti Fazu 0 iz `PROMPTS.md`
- [ ] Provjeriti GitHub Student Developer Pack
- [ ] Dogovoriti konzultaciju s pravnikom (politika privatnosti, ugovor o obradi podataka)
- [ ] Odlučiti konačan naziv proizvoda (Chatify je radni naziv)

**Otvoreno pitanje:** tko je prvi kupac, sigurnosni tim, IT ili voditelji ljudi i produktivnosti? Od odgovora ovisi koji dio gradimo prvi.
