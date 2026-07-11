#!/bin/bash
# Vänta på nätverk vid autostart så systemet hinner ansluta
#sleep 10

# --- KONFIGURATION ---
input_file="$HOME/stream_recorder.txt"
base_save_dir="$HOME/stream_videos"
log_file="$HOME/stream_history.log"
config_file="$HOME/.ffmpeg_threads_config"
temp_dir="/tmp/stream_locks"
today=$(date +%Y%m%d)
# ---------------------

# Skapa temp-mappen om den inte existerar
mkdir -p "$temp_dir"

# 1. Kolla efter gamla lock-filer som inte tillhör dagens datum
old_locks=$(find "$temp_dir" -name "*.lock" ! -name "${today}-*.lock" 2>/dev/null)

if [[ -n "$old_locks" ]]; then
    echo "Hittade gamla lock-filer från tidigare dagar."
    read -p "Vill du rensa gamla låsfiler innan start? (j/n): " purge_choice
    if [[ "$purge_choice" =~ ^(j|J|ja|JA)$ ]]; then
        find "$temp_dir" -name "*.lock" ! -name "${today}-*.lock" -delete 2>/dev/null
        echo "Gamla låsfiler raderade."
    fi
fi

# 2. Kontrollera att ffmpeg finns installerat i systemet
if ! command -v ffmpeg &> /dev/null; then
    echo "FEL: ffmpeg saknas. Installera med: sudo apt update && sudo apt install ffmpeg"
    exit 1
fi

# 3. Hantera inställning för ffmpeg-trådar (Skrivs som ren text till filen)
if [[ ! -f "$config_file" ]]; then
    read -p "Begränsa ffmpeg till 1 tråd? (Rekommenderas för Raspberry Pi) (j/n): " thread_choice
    if [[ "$thread_choice" =~ ^(j|J|ja|JA)$ ]]; then
        echo "1" > "$config_file"
    else
        echo "0" > "$config_file"
    fi
fi

# Läs filen och bygg upp rätt argument i en Bash-array
if [[ $(cat "$config_file" 2>/dev/null) == "1" ]]; then
    ffmpeg_args=(--downloader-args "ffmpeg:-threads 1")
    echo "System: Begränsar till 1 CPU-tråd."
else
    ffmpeg_args=()
    echo "System: Använder standard (alla trådar)."
fi

# Skapa huvudmappen för videofiler
mkdir -p "$base_save_dir"

# Funktion som körs när du trycker 'q' för att städa upp och avsluta
cleanup_and_exit() {
    echo -e "\n"
    rm -f "$temp_dir/${today}-"*.lock
    
    read -p "Vill du behålla de nedladdade filerna? (j/n): " choice
    if [[ "$choice" =~ ^(n|N|nej|NEJ)$ ]]; then
        echo -e "\a"
        read -p "ÄR DU HELT SÄKER? Detta raderar ALLA undermappar permanent! (j/n): " confirm
        if [[ "$confirm" =~ ^(j|J|ja|JA)$ ]]; then
            find "$base_save_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
            echo "Alla mappar och filer har raderats."
        else
            echo "Radering avbruten. Rensar tomma mappar men behåller dina inspelningar..."
            find "$base_save_dir" -mindepth 1 -type d -empty -delete
            echo "Klara inspelningar sparades. Tomma mappar togs bort."
        fi
    else
        echo "Rensar tomma mappar men behåller dina inspelningar..."
        find "$base_save_dir" -mindepth 1 -type d -empty -delete
        echo "Filerna behålls."
    fi
    exit 0
}

echo "Bevakning startad ($today). Logg sparas i: $log_file"

# Huvudloop som körs för evigt tills 'q' trycks ned
while true; do
    if [[ ! -f "$input_file" ]]; then
        echo "Fel: Hittar inte listan med streamers på: $input_file"
        exit 1
    fi

    # Läs in textfilen med hänsyn till TAB, LF och CRLF
    while IFS=$'\t\n\r' read -d '' -r -a actor_list || [ ${#actor_list[@]} -gt 0 ]; do
        
        for actor in "${actor_list[@]}"; do
            # Tvätta namnet från dolda tecken, snedstreck och mellanslag
            actor=$(echo "$actor" | tr -d '\r\n\t /')
            
            [[ -z "$actor" ]] && continue

            # Definiera unik lock-fil baserat på datum och streamernamn
            lock_file="$temp_dir/${today}-${actor}.lock"
            
            if [[ -f "$lock_file" ]]; then
                echo "--- $actor körs redan idag i ett annat fönster. Hoppar över. ---"
                continue
            fi

            # Korrekt URL utan dolda eller dubbla snedstreck
            url="https://example.com/${actor}"
            current_actor_dir="$base_save_dir/$actor"
            mkdir -p "$current_actor_dir"

            echo "--- Kollar: $actor ---"
            touch "$lock_file"
            start_time=$(date "+%Y-%m-%d %H:%M:%S")
            
            # Kör yt-dlp på en enda rad med array-parametern intakt
            yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate "${ffmpeg_args[@]}" -o "$current_actor_dir/%(title)s - %(upload_date)s.%(ext)s" "$url"
            
            status=$?
            rm -f "$lock_file"

            if [ $status -eq 0 ]; then
                end_time=$(date "+%Y-%m-%d %H:%M:%S")
                log_entry="[$start_time till $end_time] $actor ONLINE"
                
                if [[ "$url" == *"twitch.tv"* ]]; then
                    title=$(yt-dlp --get-title --no-check-certificate "$url" 2>/dev/null)
                    log_entry="$log_entry - Titel: $title"
                fi
                echo "$log_entry" >> "$log_file"
            else
                wait_time=$(( ( RANDOM % 14 ) + 2 ))
                echo "Offline: Väntar $wait_time sekunder..."
                
                read -t "$wait_time" -n 1 key
                [[ $key == "q" ]] && cleanup_and_exit
            fi
        done
    done < "$input_file"

    # Kort paus efter att hela listan har gåtts igenom
    read -t 5 -n 1 key
    [[ $key == "q" ]] && cleanup_and_exit
done
