#!/bin/bash

input_file="stream_recorder.txt"

echo "Startar bevakning. Tryck på 'q' för att avsluta efter en koll."

while true; do
    if [[ ! -f "$input_file" ]]; then
        echo "Fel: Hittar inte $input_file"
        exit 1
    fi

    while IFS= read -r actor || [[ -n $actor ]]; do
        [[ -z "$actor" ]] && continue

        echo "--- Kollar: $actor ---"
        
        # Kör yt-dlp
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate https://example.com/${actor}
        
        # Spara statuskoden från yt-dlp
        status=$?

        # Ge användaren en kort chans att avbryta mellan varje actor (2 sekunder)
        echo "Väntar... (tryck 'q' för att stoppa)"

        # Räkna ut slumpmässig tid: $(( (slumptal % intervall) + minimum ))
        # (15 - 2 + 1) = 14. Modulo 14 ger 0-13. + 2 ger 2-15.
        wait_time=$(( ( RANDOM % 14 ) + 2 ))
            
        echo "$actor verkar vara offline. Väntar $wait_time sekunder innan nästa..."
            
        # Vänta i $wait_time sekunder, men tillåt avbrott med 'q'
        read -t "$wait_time" -n 1 key
        if [[ $key == "q" ]]; then
            echo -e "\nAvslutar..."
            exit 0
        fi

    done < "$input_file"

    echo "Hela listan genomgången. Börjar om..."
    sleep 1
done
