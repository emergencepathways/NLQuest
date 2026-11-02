# Speurtocht.NL — Nederlandse questteksten voor World of Warcraft

*English version: see [README.md](README.md)*

Speurtocht.NL laat de teksten van quests in het Nederlands zien. De rest van het spel blijft Engels. De addon is gemaakt om Nederlands te leren terwijl je speelt:

- **Nederlands op jouw niveau.** Het begint op A1–A2 en groeit naar B1 als je personage een hoger level krijgt.
- **Het Engelse origineel** als je het nodig hebt: houd Alt ingedrukt, of wijs de EN-knop aan.
- **Een lezer naast het questvenster**, met Nederlands en Engels naast elkaar. Je kunt op elk Nederlands woord klikken.
- **Een woordenlijst** met de woorden waarop je klikt, klaar om in Anki te zetten.

**Versie 0.2.0** · Classic Era (1.15) nu · World of Warcraft: Forever (1.60) vanaf de lancering

---

## 1. Installeren

1. Pak de download uit. Je krijgt een map met de naam `SpeurtochtNL`.
2. Kopieer die map naar de AddOns-map van het spel. Op Linux met Steam/Proton is dat:
   ```
   ~/.local/share/Steam/steamapps/compatdata/<nummer>/pfx/drive_c/Program Files (x86)/World of Warcraft/_classic_era_/Interface/AddOns/
   ```
   Voor Forever gebruik je de map van Forever in plaats van `_classic_era_`. Die map verschijnt als je Forever hebt geïnstalleerd en één keer hebt gestart.
3. Controleer dat het bestand op `AddOns/SpeurtochtNL/SpeurtochtNL.toc` staat, en niet een map dieper.
4. Open in het personagescherm **AddOns** en zet een vinkje bij **Speurtocht.NL**. Staat er "out of date"? Zet dan een vinkje bij **Load out of date AddOns**. Dat gebeurt als Blizzard het spel bijwerkt voordat de addon is bijgewerkt.
5. Staat er nog een oude versie met de naam **NederQuest** in de AddOns-map? Verwijder die. Anders werken beide versies tegelijk.

WowUp beheert alleen addons die het zelf heeft gedownload. Daarom staat Speurtocht.NL daar als "unknown". Dat is normaal.

---

## 2. Spelen met de addon

Praat met iemand die een quest heeft. Het questvenster is in het Nederlands, en de lezer gaat ernaast open: links Nederlands, rechts Engels.

| Wat wil je? | Wat doe je? |
|---|---|
| Even het Engels zien | Houd **Alt** ingedrukt |
| Het Engels zien zonder het venster te veranderen | Wijs de **EN**-knop op het questvenster aan |
| De lezer openen of sluiten | Klik op **EN**, of typ `/speur reader` |
| De Engelse kolom verbergen | Klik op **- EN** in de lezer |
| Een woord opslaan | Klik erop in de lezer. Opgeslagen woorden worden groen. |
| Een naam of Warcraft-woord herkennen | Klik erop: het wordt rood en wordt niet opgeslagen |
| Een opgeslagen woord verwijderen | Klik er met de rechtermuisknop op |
| Je opgeslagen woorden bekijken | Knop **Woorden** in de lezer, of `/speur vocab` |
| De instellingen openen | `/NLQuest` of `/speur` |

### Snel kiezen

In de instellingen staan drie snelle keuzes. Je kunt ook elke optie apart aan- of uitzetten.

- **Alleen Nederlands**: alleen Nederlands. Geen lezer en geen hulp in het Engels.
- **NL + Engels bij hover**: Nederlands in het questvenster, Engels via de EN-knop en Alt.
- **Naast elkaar**: Nederlands in het questvenster en de lezer ernaast. Dit is de standaard.

### Het niveau groeit met je mee

De lezer laat naast de titel zien op welk niveau een quest is geschreven.

| Questlevel | Niveau | Hoe het leest |
|---|---|---|
| 1–12 | A1–A2 | Korte zinnen, woorden van elke dag |
| 13–25 | A2 | Twee ideeën per zin, veelgebruikte scheidbare werkwoorden |
| 26–42 | A2–B1 | Langere zinnen, bijzinnen met *die/dat/waar*, wat uitdrukkingen |
| 43–60 | B1 | De dramatische toon van de grote verhalen blijft, moeilijke woorden worden uitgelegd |

Namen van personen, plaatsen, vijanden en voorwerpen blijven Engels. Zo passen ze bij de kaart, de tooltips en de questtracker.

Onder elke vertaling staat in de lezer **Woorden in deze quest**: de moeilijkere woorden uit die quest, met hun betekenis. Klik op een woord om het op te slaan.

---

## 3. Opgeslagen woorden → Anki

Bij elk opgeslagen woord bewaart de addon vier dingen: het Nederlandse woord, de Engelse betekenis, de zin waarin je het vond en de titel van de quest. Elk woord in de vertaalde quests heeft een betekenis, dus de Engelse kant van je kaarten is nooit leeg.

Namen en Warcraft-woorden worden nooit opgeslagen. Klik je op **Durnan**, **Anvilmar**, **troggs** of de naam van je eigen personage? Dan wordt het woord **rood** en zie je waarom, in plaats van dat het in je lijst komt. Als je het woord aanwijst, zie je dezelfde uitleg.

### Automatisch: woorden gaan vanzelf naar Anki (aanbevolen)

Addons in WoW kunnen geen bestanden op je computer maken. Maar WoW zelf slaat de gegevens van de addon op als je uitlogt of `/reload` typt. Een klein programma op je computer let op dat moment en stuurt nieuwe woorden direct naar Anki.

**Eén keer instellen** (ongeveer vijf minuten):

1. **Installeer AnkiConnect in Anki.** In Anki: **Extra › Add-ons › Add-ons ophalen…**, vul de code `2055492159` in, klik op OK en start Anki opnieuw.
2. **Start de sync één keer.** Open een terminal in de map `tools` van de addon en voer uit:
   ```
   python3 anki_sync.py
   ```
   Het programma vindt je WoW-map zelf, en maakt in Anki een stapel en een kaarttype met de naam **Speurtocht.NL**. Elk woord krijgt twee kaarten: Nederlands → Engels en Engels → Nederlands, met de voorbeeldzin en de titel van de quest op de achterkant. (Gebruik de eerste keer `--one-way` als je alleen Nederlands → Engels wilt.)
3. **Maak het automatisch.** Voer in dezelfde map uit:
   ```
   bash install_autosync.sh
   ```
   Vanaf nu start de sync samen met je bureaublad en werkt hij rustig op de achtergrond.

**Daarna:** laat Anki openstaan terwijl je speelt. Heb je woorden opgeslagen? Klik dan in de woordenlijst op **Naar Anki** (dat doet even een `/reload`), of log gewoon uit. Een paar seconden later staan de kaarten in je stapel **Speurtocht.NL**. Was Anki dicht? Dan worden de woorden verstuurd zodra je Anki weer opent.

Krijgt een woord later een betere betekenis? Dan wordt de kaart bijgewerkt, en komt er geen dubbele kaart bij.

De sync op de achtergrond stoppen: `bash install_autosync.sh --remove`.

### Andere manier: kopiëren en plakken

Wil je niets installeren?

1. Maak in Anki één keer een notitietype met drie velden: **Extra › Notitietypen beheren › Toevoegen › Basis (en omgekeerde kaart)**, noem het `Speurtocht.NL` en hernoem de velden naar `Nederlands`, `English` en `Zin`.
2. In het spel: `/speur vocab` › **Kopieer tekst** (alleen woorden die je nog niet eerder hebt gekopieerd). De tekst is al geselecteerd: druk op **Ctrl+C** en klik dan op **Markeer als geëxporteerd**.
3. Plak in een teksteditor, sla op als `speurtocht.txt` en kies in Anki **Bestand › Importeren**. Kies notitietype `Speurtocht.NL`, koppel kolom 1–4 aan Nederlands, English, Zin en Labels, en zet **Bestaande notities** op *Bijwerken*.

---

## 4. Quests die nog niet vertaald zijn

Open je een quest zonder vertaling? Dan laat Speurtocht.NL het Engels staan en bewaart de addon stil een kopie van de tekst. Met `/speur capture` zie je hoeveel quests er bewaard zijn.

Wil je ze laten vertalen? Log uit (of typ `/reload`) en voer dit uit:

```
python3 tools/capture_to_json.py "<spelmap>/WTF/Account/<ACCOUNT>/SavedVariables/SpeurtochtNL.lua" captured.json
```

Stuur `captured.json` op, dan komen die quests in de volgende ronde. Zo worden ook de nieuwe quests van Forever vertaald, zoals de Cozy Sleeping Bag-reeks: speel ze één keer en stuur dan het bestand.

Verandert Forever de Engelse tekst van een quest die al vertaald is? Dan zie je in de lezer *tekst gewijzigd*, en wordt de nieuwe tekst apart bewaard. Zo kan de vertaling worden bijgewerkt.

---

## 5. Wat is er vertaald?

| Ronde | Quests | Status |
|---|---|---|
| Coldridge Valley | 13 | ✅ |
| Dun Morogh | 31 | ✅ |
| Runen van de klassentrainers voor dwergen (level 1) | 5 | ✅ |
| Northshire + Elwynn Forest | 48 | volgende |
| Shadowglen + Teldrassil | 48 | |
| Klassenquests van de Alliance tot level 10 | 102 | |
| Kerkers, level 10–60 (Alliance) | 214 | |
| Attunements (Molten Core, Onyxia, Blackwing Lair, Upper Blackrock Spire, Scholomance, sleutel van Blackrock Depths) | 31 | |
| Cozy Sleeping Bag (Forever) | — | na de lancering, via capture |

In `tools/roadmap_v1.json` staat elk quest-ID per ronde.

---

## 6. Chatcommando's

| Commando | Wat het doet |
|---|---|
| `/NLQuest` of `/speur` | Opent de instellingen |
| `/speur reader` | Opent of sluit de lezer |
| `/speur vocab` | Opent je opgeslagen woorden |
| `/speur save woord` | Slaat een woord op door het te typen (met de betekenis, als de addon die kent) |
| `/speur save woord = betekenis` | Slaat een woord op met je eigen betekenis |
| `/speur check` | Controleert of je op de woorden in de lezer kunt klikken |
| `/speur export` | Opent het venster om te kopiëren en plakken (alle woorden) |
| `/speur capture` | Laat zien hoeveel onvertaalde quests er bewaard zijn |
| `/speur status` | Versie, versie van het spel, en of de huidige quest vertaald is |
| `/speur help` | Laat de commando's zien |

Hoofdletters maken niet uit.

---

## 7. Problemen oplossen

- **Er is niets in het Nederlands:** typ `/speur status`. Je ziet dan het quest-ID en of de quest vertaald is. Controleer ook of **Speurtocht.NL aan** is aangevinkt in de instellingen.
- **Er verschijnt een Lua-foutmelding:** typ `/console scriptErrors 1`, doe hetzelfde nog een keer en stuur een screenshot van de hele foutmelding.
- **Klikken op woorden slaat ze niet op:** gebruik versie 0.1.1 of nieuwer. Klik op woorden in de **lezer**, niet in het questvenster zelf (op de tekst in het questvenster kun je niet klikken). Typ `/speur check` en stuur de regel die je dan ziet. Je kunt een woord altijd opslaan door `/speur save woord` te typen.
- **De lezer staat buiten het scherm:** open de instellingen en klik op **Lezer terugzetten**.
- **Woorden komen niet in Anki:** controleer of Anki open is en AnkiConnect is geïnstalleerd. Voer dan `python3 anki_sync.py` uit in de map `tools` om te zien wat er gebeurt. Logboek van de sync op de achtergrond: `journalctl --user -u speurtocht-anki`.

---

## 8. Voor ontwikkelaars

| Pad | Wat het is |
|---|---|
| `Core.lua` | Namespace, instellingen, vertalingen registreren, zoeken op quest-ID (anders op Engelse titel) |
| `Text.lua` | `$n/$c/$r/$b/$g` invullen, Nederlandse namen van klassen en volken, klikbare woorden |
| `Display.lua` | Tekst vervangen in het questvenster en het questlogboek, EN-knop, Alt om te spieken |
| `Reader.lua` | De lezer naast het questvenster |
| `Vocab.lua` | Woorden opslaan, woordenlijst, Anki-export |
| `Capture.lua` | Bewaart onvertaalde en gewijzigde quests |
| `Options.lua` | Instellingenvenster en chatcommando's |
| `Data/*.lua` | Vertalingen, één bestand per ronde |
| `docs/STYLE.md` | De vertaalregels voor elke ronde |
| `tools/extract_vanilla_quests.py` | Engelse brontekst uit de VMaNGOS-database |
| `tools/build_manifest.py` | Verdeelt quests over de rondes (vindt kerkerquests aan de hand van waar hun doelen verschijnen) |
| `tools/anki_sync.py`, `tools/install_autosync.sh` | Stuurt opgeslagen woorden naar Anki via AnkiConnect, eventueel op de achtergrond |
| `tools/build_lexicon.py` | Maakt `Data/Namen.lua` en controleert of elk Nederlands woord een betekenis heeft |
| `Data/Termen.lua` | Warcraft-fantasiewoorden met uitleg |
| `tools/test_harness.lua` | Offline test in een nagebootste WoW-omgeving: `lua5.1 tools/test_harness.lua` |

Engelse brontekst: VMaNGOS-wereld-database (github.com/brotalnia/database). Speurtocht.NL is een onafhankelijk fanproject en is niet verbonden aan Blizzard Entertainment.
