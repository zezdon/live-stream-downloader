# Live Stream Downloader

Ett universellt, flexibelt och automatiserat Bash-skript för att bevaka och spela in livesändningar samt ladda ner videor från plattformar som Twitch och YouTube med hjälp av `yt-dlp` och `ffmpeg`.

Detta projekt innehåller kod som har genererats med hjälp av AI-verktyg som Google Gemini Ai. All kod har granskats, testats och modifierats manuellt av mig.

## Installation och första körning (RaspOS / Linux)

1. Ladda ner skriptet `stream-recorder.sh` till din Raspberry Pi eller Linux-dator.
2. Gör skriptet körbart genom att köra följande kommando i terminalen:
   ```bash
   chmod +x stream-recorder.sh
   ```
3. Starta skriptet för första gången:
   ```bash
   ./stream-recorder.sh
   ```

När du kör skriptet allra första gången kommer det att märka att konfigurationsfilen saknas och automatiskt skapa en textfil som heter `stream-recorder.txt` i samma katalog. Skriptet avslutas sedan så att du kan fylla i dina kanaler.

## Konfiguration av din bevakningslista

Öppna den nyskapade filen `stream-recorder.txt` i en textredigerare. Här är ett enkelt exempel på hur du kan strukturera din bevakningslista för att spela in och hantera fördröjningar:

```text
# Spela in Twitch kanal direkt (byt ut morrog mot valfri kanal)
morrog

# Vänta i exakt 30 sekunder innan nästa koll
delay(30)

# Spela in en YouTube-livesändning eller ladda ner ett YouTube-klipp
# Byt ut länken nedan mot den URL-adress som syns i din webbläsare
https://youtube.com

# Vänta i 10 sekunder till
delay(10)

# Spela in en annan Twitch-kanal direkt
twitch.tv/limealicious
```

### Viktigt att tänka på:

- **Twitch-kanaler:** Du kan skriva antingen bara det rena kanalnamnet (`morrog`), halva webbadressen (`twitch.tv/limealicious`) eller hela adressen (`https://twitch.tv`). Skriptet förstår alla tre formaten automatiskt.
- **YouTube-länkar:** Klistra alltid in den exakta och fullständiga URL-adressen från din webbläsare när du vill bevaka en specifik livesändning eller ladda ner ett videoklipp.
- **Kommentarer:** Rader som börjar med `#` hoppas automatiskt över av skriptet, vilket gör det enkelt att organisera listan.

## Avancerade funktioner och specialkommandon

Skriptet innehåller flera unika kommandon som du kan skriva direkt i din textfil för att styra hur mappar skapas, hur pauser hanteras och hur skriptet ska bete sig när filer redan existerar.

### 1. Skräddarsydda mappnamn: `url(adress, "mappnamn")`
Standardbeteendet för skriptet är att automatiskt skapa en undermapp baserad på kanalens eller profilens riktiga namn. Om du vill ha en egen struktur och själv bestämma vad mappen ska heta, använder du kommandot `url()` med två parametrar separerade med ett kommatecken:
* **Parameter 1:** Den internetadress (URL) som ska laddas ner eller spelas in.
* **Parameter 2:** Det namn du vill att undermappen ska få på din hårddisk (omges av enkla eller dubbla citationstecken).

*Exempel:*
```text
url(https://youtube.com, "Heathrow Airport")
```
Detta tvingar skriptet att spara alla videor från den strömmen i en mapp som heter exakt `Heathrow Airport`.

### 2. Blixtsnabb mappkontroll: `overwrite(dirkeep)`
När du anger en länk till en hel profil (till exempel en TikTok-profil) brukar verktyget ladda ner alla tillgängliga offentliga videoklipp från den användaren. Om profilen har hundratals videor tar det väldigt lång tid för systemet att skanna igenom hela listan varje gång skriptet startar om, bara för att kontrollera att filerna redan finns.

För att lösa detta använder du kommandot `overwrite(dirkeep)`. 

När `overwrite(dirkeep)` är aktiverat gör skriptet en blixtsnabb kontroll *innan* nedladdningen ens startar: **Om mappen för den profilen redan existerar på din hårddisk och innehåller filer, hoppas hela raden över omedelbart på under en sekund.** Systemet går direkt vidare till nästa rad i listan utan att slösa tid eller nätverkstrafik.

### 3. Återställa kontrollen: `overwrite(no)`
När du har kört en TikTok-profil med `dirkeep` vill du oftast att dina vanliga Twitch- eller YouTube-livesändningar ska kontrolleras som vanligt (så att de spelas in om de går online, även om mappen redan finns). Då skriver du helt enkelt `overwrite(no)` på raden efter för att stänga av den snabba mappkontrollen.



## Komplett exempel på en avancerad lista

### 1. Skräddarsydda mappnamn: `url(adress, "mappnamn")`
Standardbeteendet för skriptet är att automatiskt skapa en undermapp baserad på kanalens eller profilens riktiga namn. Om du vill ha en egen struktur och själv bestämma vad mappen ska heta, använder du kommandot `url()` med två parametrar separerade med ett kommatecken:
* **Parameter 1:** Den internetadress (URL) som ska laddas ner eller spelas in.
* **Parameter 2:** Det namn du vill att undermappen ska få på din hårddisk. **OBS!** Det rekommenderas i dagsläget att du endast använder vanliga bokstäver (a-z) och siffror (0-9) i detta fält för maximal stabilitet.

Här är ett exempel på hur din textfil kan se ut när du kombinerar alla dessa smarta funktioner för att skapa ett effektivt flöde:

```text
# Stäng av frågan om gamla låsfiler vid uppstart
initclean(no)

# Slå på snabb mappkontroll för TikTok (skannar inte 300+ filer om mappen finns)
overwrite(dirkeep)
delay(7)
url(https://tiktok.com, "profilnamn")
delay(5)

# Återställ till standardläge för vanliga livesändningar (så att de spelas in)
overwrite(no)
url(https://youtube.com, "Boten Anna")
delay(5)
```
## Automatisk städning: `clear(folder)`

När du kör skriptet i bakgrunden (till exempel via Crontab eller Systemctl) finns det ingen användare på plats som kan trycka på 'q' för att starta städningen. Då använder du det dynamiska kommandot `clear(folder)` direkt i din textfil för att schemalägga städningen automatiskt.

När skriptet når raden `clear(folder)` körs följande procedur helt automatiskt:
1. **Rensar tomma mappar:** Alla undermappar i ditt videoarkiv som har skapats men blivit tomma raderas.
2. **Hanterar avbrutna filer:** Tar automatiskt bort `.part`-filändelsen på inspelningar som avbrutits och markerar dem med `-avbruten.mp4` i filnamnet så att de blir vanliga spelbara videofiler.
3. **Sorterar mindre videofiler:** Hittar färdiga videofiler som är mindre än 100 MB (ofta korta testklipp eller skräpfiler från streams som snabbt gått ner) och flyttar dem till en separat undermapp märkt med `-mindre-filer` i slutet.

### Hantering av specialtecken i mappnamn (Under utveckling / ToDo)
Skriptet är fullt fönstersäkrat när du använder standardtecken. Att använda specialtecken som bindestreck (`-`) eller understreck (`_`) i de skräddarsydda mappnamnen i kombination med den automatiska städfunktionen `clear(folder)` är i skrivande stund under utveckling och ligger på projektets officiella ToDo-lista för framtida uppdateringar.

*Exempel:*
```text
# Exempel på användning av specialtecken och automatisk städning
initclean(no)
overwrite(no)

# Skapa mappar med bindestreck och understreck
url(https://twitch.tv, "b-e-n-n-y")
delay(7)
url(https://twitch.tv, "j_l_c_s_2")
delay(7)

# Starta automatisk rensning och sortering i slutet av loopen
clear(folder)
```
## Kontrollera terminalutskrifter: `initDebug()`

När skriptet kontrollerar kanaler som är offline, spottar `yt-dlp` och systemet ofta ur sig en hel del röd feltext i terminalen (så kallad *Standard Error*). För att hålla din skärm och dina loggfiler rena och städade kan du styra om denna feltext ska visas eller döljas.

Du styr detta med kommandot `initDebug()` högst upp i din textfil:
* **`initDebug(no)` (Standard / Default):** Gömmer all röd feltext och ovidkommande systemmeddelanden. Terminalen blir tyst, ren och lättläst. Detta läge används automatiskt även om du helt utelämnar kommandot från textfilen.
* **`initDebug(yes)`:** Slår på debug-läget. All röd feltext visas på skärmen, vilket är perfekt om du behöver felsöka en anslutning eller se varför en specifik sajt inte vill ladda ner.

*Exempel:*
```text
# Håll skärmen ren från röd feltext (Default)
initDebug(no)
initclean(no)
overwrite(dirkeep)

# Dina kanaler...
```
## Avsluta skriptet automatiskt: `exit(quit)` och `exit(clean)`

Standardbeteendet för skriptet är att loopa i evighet. När det har gått igenom hela din bevakningslista så börjar det om från början igen. Om du kör skriptet via schemalagda bakgrundsverktyg (som **Crontab** en gång i timmen), vill du att skriptet gör en genomsökning och sedan stänger ner sig själv.

För att styra exakt hur skriptet ska stängas av kan du använda följande kommandon på sista raden i din textfil:

### 1. Avsluta omedelbart: `exit(quit)` eller `exit(0)`
Detta kommando avslutar skriptet och stänger terminalfönstret **direkt på sekunden**. Ingen extra städning eller sortering körs, utan skriptet frigör bara sina låsfiler och stänger ner omedelbart. Det är perfekt om du vill köra en snabb manuell test av din lista.

### 2. Tyst städning och avslut: `exit(clean)`
Detta är det **rekommenderade kommandot för Crontab och Systemctl**. När skriptet stöter på `exit(clean)` körs hela städfunktionen (`run_folder_cleanup`) helt automatiskt i bakgrunden:
* Tomma mappar raderas.
* Avbrutna `.part`-filer fixas till spelbara `-avbruten.mp4`-filer.
* Småfiler sorteras till en specifik mapp.

Hela denna städprocedur körs **helt tyst utan att ställa några frågor** till användaren, och när det är klart stängs skriptet ner klockrent.

---

### Komplett exempel på en automatiserad lista (Crontab-vänlig)

Här är ett exempel på hur din textfil kan se ut när du vill köra en säker, tyst genomsökning i bakgrunden som städar upp efter sig och stänger av sig själv utan att fastna i minnet:

```text
# Stäng av alla manuella startfrågor och feltexter
initclean(no)
initDebug(no)
overwrite(dirkeep)

# Skanna igenom dina valda kanaler en gång
url(https://twitch.tv, "marzzzzy")
delay(4)
url(https://twitch.tv, "kameto")
delay(4)

# Kör automatisk städning utan frågor och avsluta sedan skriptet helt
exit(clean)
```
### Komplett exempel på en engångsskanning

Här är ett exempel på hur din textfil kan se ut när du vill köra en säker och tyst genomsökning i bakgrunden utan att skriptet blir hängande i minnet:

```text
# Stäng av alla manuella startfrågor och feltexter
initclean(no)
initDebug(no)
overwrite(dirkeep)

# Skanna igenom dina valda kanaler en gång
url(https://twitch.tv, "marzzzzy")
delay(4)
url(https://twitch.tv, "kameto")
delay(4)

# Utför en automatisk slutstädning av mappar och skräpfiler
clear(folder)

# Avsluta skriptet helt och frigör systemresurserna
exit(0)
```
## Ändra eller nollställa dina inställningar

Om du har råkat ange fel värden under skriptets första uppstart (till exempel fel antal ffmpeg-trådar eller felaktig storlek för skräpfiler), kan du enkelt nollställa dessa. Alla dina inställningar sparas säkert i en dold mapp som heter `.settings` precis där skriptet är installerat.

För att navigera till skriptet och radera dina inställningar gör du följande i terminalen:

1. Ta reda på exakt var ditt skript är installerat på datorn:
   ```bash
   ls -l stream-recorder.sh
   ```
2. Navigera till mappen där skriptet ligger (om du inte redan står där):
   ```bash
   cd /sökväg/till/mappen/
   ```
3. Radera hela inställningsmappen för att tvinga skriptet att ställa frågorna på nytt vid nästa start:
   ```bash
   rm -rf .settings
   ```
Du kan också välja att gå in i den dolda mappen `.settings` med textredigeraren `nano` för att ändra enskilda filer manuellt utan att radera allt.
