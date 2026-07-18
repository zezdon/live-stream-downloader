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
