#!/bin/bash

# Filen som innehåller namnen
input_file="stream_recorder.txt"

echo "Startar bevakning. Tryck på 'q' under pauserna för att avsluta."

while true; do
    # Kontrollera om filen existerar
    if [[ ! -f "$input_file" ]]; then
        echo "Fel: Hittar inte $input_file"
        exit 1
    fi

    # Läs filen rad för rad
    while IFS= read -r actor || [[ -n $actor ]]; do
        # Hoppa över tomma rader
        [[ -z "$actor" ]] && continue

        echo "--- Kollar: $actor ---"
        
        # Kör yt-dlp
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate https://example.com/${actor}
        
        # Ge användaren en kort chans att avbryta mellan varje actor (2 sekunder)
        echo "Väntar... (tryck 'q' för att stoppa)"
        read -t 2 -n 1 key
        if [[ $key == "q" ]]; then
            echo -e "\nAvslutar scriptet..."
            exit 0
        fi
    done < "$input_file"

    echo "Färdig med listan. Börjar om om 10 sekunder..."
    
    # En lite längre paus efter att hela listan körts igenom
    read -t 10 -n 1 key
    if [[ $key == "q" ]]; then
        echo -e "\nAvslutar scriptet..."
        exit 0
    fi
done
