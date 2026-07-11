#!/bin/bash

# --- KONFIGURATION ---

base_save_dir=$HOME/stream_videos
input_file=stream_recorder.txt

# ---------------------

# Skapa mappen om den inte redan finns
mkdir -p $base_save_dir

# Funktion för att städa upp vid avslut
cleanup_and_exit() {
    echo -e "\n"
    read -p "Vill du behålla de nedladdade filerna? (j/n): " choice
    case "$choice" in 
        n|N|nej|NEJ)
            echo "Rensar mappar och filer i $base_save_dir..."
            # Gå igenom undermapparna och radera dem
            for dir in $base_save_dir/*/; do
                if [ -d $dir ]; then
                    rm -rf $dir
                fi
            done
            echo "Klart. Alla undermappar är borttagna."
            ;;
        *)
            echo "Filerna behålls."
            ;;
    esac
    exit 0
}

echo "Bevakar streamers. Tryck 'q' mellan kollarna för att avsluta."

while true; do
    if [[ ! -f $input_file ]]; then
        echo "Fel: Hittar inte $input_file"
        exit 1
    fi

    while IFS= read -r actor || [[ -n $actor ]]; do
        [[ -z $actor ]] && continue

        # Skapa unik undermapp för streamern
        current_actor_dir=$base_save_dir/$actor
        mkdir -p $current_actor_dir

        echo "--- Kollar: $actor ---"
        
        # -o anger nu undermappen specifikt för denna actor

        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate  -o $current_actor_dir/$actor https://example.com/${actor} 
        
        status=$?

        if [ $status -ne 0 ]; then
            wait_time=$(( ( RANDOM % 14 ) + 2 ))
            echo "Offline: Väntar $wait_time sekunder..."
            read -t $wait_time -n 1 key
            [[ $key == "q" ]] && cleanup_and_exit
        else
            # Ge en liten chans att trycka 'q' även efter lyckad nerladdning
            read -t 1 -n 1 key
            [[ $key == "q" ]] && cleanup_and_exit
        fi

    done < $input_file

    echo "Listan klar. Startar om..."
    read -t 5 -n 1 key
    [[ $key == "q" ]] && cleanup_and_exit
done