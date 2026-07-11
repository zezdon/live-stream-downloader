#!/bin/bash
# Vänta på nätverk vid autostart
#sleep 10

# --- KONFIGURATION ---

base_save_dir=$HOME/stream_videos
input_file=stream_recorder.txt
log_file=$base_save_dir/stream_history.log
config_file="$HOME/.ffmpeg_threads_config"
temp_dir="/tmp/stream_locks"
today=$(date +%Y%m%d)
# ---------------------

mkdir -p "$temp_dir"

# 1. Kolla efter gamla lock-filer (inte dagens datum)
old_locks=$(find "$temp_dir" -name "*.lock" ! -name "${today}-*.lock")

if [[ -n "$old_locks" ]]; then
    echo "Hittade gamla lock-filer från tidigare dagar."
    read -p "Vill du rensa gamla låsfiler innan start? (j/n): " purge_choice
    if [[ "$purge_choice" =~ ^(j|J|ja|JA)$ ]]; then
        find "$temp_dir" -name "*.lock" ! -name "${today}-*.lock" -delete
        echo "Gamla låsfiler raderade."
    fi
fi

# Kontrollera ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "FEL: ffmpeg hittades inte. Installera med: sudo apt update && sudo apt install ffmpeg"
    exit 1
fi

# 3. Hantera ffmpeg-trådar
if [[ ! -f "$config_file" ]]; then
    read -p "Begränsa ffmpeg till 1 tråd? (j/n): " thread_choice
    [[ "$thread_choice" =~ ^(j|J|ja|JA)$ ]] && echo "--downloader-args \"ffmpeg:-threads 1\"" > "$config_file" || echo "" > "$config_file"
fi
ffmpeg_args=$(cat "$config_file")

mkdir -p "$base_save_dir"

cleanup_and_exit() {
    echo -e "\n"
    # Ta bara bort lock-filer som skapats av just denna körning för att inte störa andra fönster
    rm -f "$temp_dir/${today}-"*.lock    
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

        # Lock-fil med datum: t.ex. /tmp/stream_locks/20231027-streamer1.lock
        lock_file="$temp_dir/${today}-${actor}.lock"
        
        if [[ -f "$lock_file" ]]; then
            echo "--- $actor körs redan idag i ett annat fönster ---"
            continue
        fi

        url="https://twitch.tv{actor}"
        current_actor_dir=$base_save_dir/$actor
        mkdir -p $current_actor_dir

        echo "--- Kollar: $actor ---"
        touch "$lock_file"        
        start_time=$(date "+%Y-%m-%d %H:%M:%S")
        
        # Kör nedladdning
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate  -o $current_actor_dir/"%(title)s - %(upload_date)s.%(ext)s" "$url2"

        status=$?
        rm -f "$lock_file"

        if [ $status -eq 0 ]; then
            # Om status är 0 betyder det att yt-dlp har kört (laddat ner en stream)
            end_time=$(date "+%Y-%m-%d %H:%M:%S")
            
            # Kolla om det är Twitch och hämta titel
           log_entry="[$start_time till $end_time] $actor ONLINE"
            [[ "$url" == *"twitch.tv"* ]] && log_entry="$log_entry - Titel: $(yt-dlp --get-title "$url" 2>/dev/null)"
            echo "$log_entry" >> "$log_file"
        else
            wait_time=$(( ( RANDOM % 14 ) + 2 ))
            echo "Offline: Väntar $wait_time sek..."
            read -t "$wait_time" -n 1 key
            [[ $key == "q" ]] && cleanup_and_exit
        fi

            # log_entry="[$start_time till $end_time] $actor var ONLINE"
            # if [[ $url == *"twitch.tv"* ]]; then
            #     # Hämtar titeln snabbt med --get-title
            #     title=$(yt-dlp --get-title --no-check-certificate $url 2>/dev/null)
            #     log_entry=$log_entry - Titel: $title
            # fi
            
        #     echo "$log_entry" >> "$log_file"
        # else
        #     wait_time=$(( ( RANDOM % 14 ) + 2 ))
        #     echo "Offline: Väntar $wait_time sekunder..."
        #     read -t "$wait_time" -n 1 key
        #     [[ $key == "q" ]] && cleanup_and_exit
        # fi

   done < "$input_file"

    read -t 5 -n 1 key
    [[ $key == "q" ]] && cleanup_and_exit
done
