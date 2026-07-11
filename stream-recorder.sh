#!/bin/bash

# --- KONFIGURATION ---

base_save_dir=$HOME/stream_videos
input_file=stream_recorder.txt
log_file=$base_save_dir/stream_history.log
# ---------------------

# 1. Kontrollera om ffmpeg finns installerat
if ! command -v ffmpeg &> /dev/null; then
    echo "FEL: ffmpeg hittades inte. Installera det med: sudo apt update && sudo apt install ffmpeg"
    exit 1
else
    echo "Systemkontroll: ffmpeg är installerat."
fi

mkdir -p $base_save_dir

cleanup_and_exit() {
    echo -e "\n"
    read -p "Vill du behålla de nedladdade filerna i mappen? (j/n): " choice
    case $choice in 
        n|N|nej|NEJ)
            echo "Rensar undermappar i $base_save_dir..."
            find $base_save_dir/$actor -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
            echo "Rensning klar."
            ;;
        *)
            echo "Filerna behålls."
            ;;
    esac
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

        current_actor_dir=$base_save_dir/$actor
        mkdir -p $current_actor_dir

        echo "--- Kollar: $actor ---"
        
        # Logga att vi kollar streamern
        start_time=$(date "+%Y-%m-%d %H:%M:%S")
        
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate  -o $current_actor_dir/"%(title)s - %(upload_date)s.%(ext)s" https://example.com/${actor}
        
        status=$?

        if [ $status -eq 0 ]; then
            # Om status är 0 betyder det att yt-dlp har kört (laddat ner en stream)
            end_time=$(date "+%Y-%m-%d %H:%M:%S")
            echo "[$start_time till $end_time] $actor var ONLINE" >> "$log_file"
            echo "Loggat: $actor var online."
        else
            # Om offline, slumpmässig paus
            wait_time=$(( ( RANDOM % 14 ) + 2 ))
            echo "Offline: Väntar $wait_time sekunder..."
            read -t $wait_time -n 1 key
            [[ $key == "q" ]] && cleanup_and_exit
        fi

    done < $input_file

    read -t 5 -n 1 key
    [[ $key == "q" ]] && cleanup_and_exit
done
