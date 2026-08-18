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

### Hantering av specialtecken i mappnamn
Skriptet är fullt fönstersäkrat och stöder att du använder specialtecken som bindestreck (`-`), understreck (`_`) eller mellanslag i dina skräddarsydda mappnamn, utan att terminalerna krockar eller att filerna sorteras fel.

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
