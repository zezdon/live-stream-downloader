#!/bin/bash

# --- KONFIGURATION ---

save_dir=$HOME/stream_videos  # Mappen där videon ska sparas
input_file=stream_recorder.txt    # Sökvägen till din textfil

# ---------------------

# Skapa mappen om den inte redan finns
mkdir -p $save_dir

echo "Startar bevakning på Raspberry Pi. Tryck 'q' för att avsluta."


#cd $save_dir/$actor

echo "Variablen: ${save_dir}"

while true; do
    if [[ ! -f $input_file ]]; then
        echo "Fel: Hittar inte $input_file"
        exit 1
    fi

    while IFS= read -r actor || [[ -n $actor ]]; do
        [[ -z $actor ]] && continue

        echo "--- Kollar: $actor ---"

        mkdir -p $save_dir/$actor
        cd $save_dir/$actor

        echo "--- Kollar: $save_dir/$actor ---"

        # Kör yt-dlp med fast sökväg (-o)
        # Filnamnet blir: Streamer_Namn - Titel - Datum.mp4
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate https://twitch.tv/${actor}
        
        status=$?

        # Om streamern är offline (yt-dlp misslyckas)
        if [ $status -ne 0 ]; then
            wait_time=$(( ( RANDOM % 14 ) + 2 ))
            echo "Offline: Väntar $wait_time sekunder innan nästa..."
            
            read -t $wait_time -n 1 key
            if [[ $key == "q" ]]; then
                echo -e "\nAvslutar..."
                exit 0
            fi
        else
            echo "Nedladdning klar för $actor. Går vidare direkt."
        fi

    done < $input_file

    echo "Listan klar. Startar om strax..."
    read -t 5 -n 1 key
    [[ $key == "q" ]] && exit 0
done