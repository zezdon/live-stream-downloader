#!/bin/bash

# --- KONFIGURATION ---
base_save_dir=$HOME/stream_videos
input_file=stream_recorder.txt
log_file="$HOME/stream_history.log"
# ---------------------

# Kontrollera ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "FEL: ffmpeg hittades inte. Installera med: sudo apt update && sudo apt install ffmpeg"
    exit 1
fi

mkdir -p "$base_save_dir"

cleanup_and_exit() {
    echo -e "\n"
    read -p "Vill du behålla de nedladdade filerna? (j/n): " choice
    if [[ $choice =~ ^(n|N|nej|NEJ)$ ]]; then
        echo -e "\a" # Ett litet varningsljud
        read -p "ÄR DU HELT SÄKER? Detta raderar ALLT i undermapparna! (j/n): " confirm
        if [[ $confirm =~ ^(j|J|ja|JA)$ ]]; then
            echo "Rensar undermappar i $base_save_dir..."
            find $base_save_dir/$actor -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
            echo "Allt raderat."
        else
            echo "Radering avbruten. Filerna behålls."
        fi
    else
        echo "Filerna behålls."
    fi
    exit 0
}

echo "Bevakning startad. Loggar till: $log_file"

while true; do
    if [[ ! -f $input_file ]]; then
        echo "Fel: Hittar inte $input_file"
        exit 1
    fi

    while IFS= read -r actor || [[ -n $actor ]]; do
        [[ -z $actor ]] && continue

        url="https://example.com{actor}"
        current_actor_dir=$base_save_dir/$actor
        mkdir -p $current_actor_dir

        echo "--- Kollar: $actor ---"
        start_time=$(date "+%Y-%m-%d %H:%M:%S")
        
        # Kör nedladdning
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate  -o $current_actor_dir/"%(title)s - %(upload_date)s.%(ext)s" https://example.com/${actor}
        
        if [ $? -eq 0 ]; then
            # Om status är 0 betyder det att yt-dlp har kört (laddat ner en stream)
            end_time=$(date "+%Y-%m-%d %H:%M:%S")
            
            # Kolla om det är Twitch och hämta titel
            log_entry="[$start_time till $end_time] $actor var ONLINE"
            if [[ $url == *"twitch.tv"* ]]; then
                # Hämtar titeln snabbt med --get-title
                title=$(yt-dlp --get-title --no-check-certificate $url 2>/dev/null)
                log_entry=$log_entry - Titel: $title
            fi
            
            echo "$log_entry" >> "$log_file"
        else
            wait_time=$(( ( RANDOM % 14 ) + 2 ))
            echo "Offline: Väntar $wait_time sekunder..."
            read -t "$wait_time" -n 1 key
            [[ $key == "q" ]] && cleanup_and_exit
        fi
    done < $input_file

    read -t 5 -n 1 key
    [[ $key == "q" ]] && cleanup_and_exit
done
