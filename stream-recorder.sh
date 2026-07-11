#!/bin/bash
# Vänta på nätverk vid autostart så systemet hinner ansluta
sleep 10

# --- KONFIGURATION ---
# Tar reda på mappen där scriptet ligger
script_dir=$(dirname "$(readlink -f "$0")")

# NYTT: Sätter namnet på textfilen till samma som scriptet, fast med .txt
script_name="${0##*/}"
script_base="${script_name%.sh}"
input_file="$script_dir/${script_base}.txt"

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

# 3. Hantera inställning för ffmpeg-trådar
if [[ ! -f "$config_file" ]]; then
    read -p "Begränsa ffmpeg till 1 tråd? (Rekommenderas för Raspberry Pi) (j/n): " thread_choice
    if [[ "$thread_choice" =~ ^(j|J|ja|JA)$ ]]; then
        echo "1" > "$config_file"
    else
        echo "0" > "$config_file"
    fi
fi

if [[ $(cat "$config_file" 2>/dev/null) == "1" ]]; then
    ffmpeg_args=(--downloader-args "ffmpeg:-threads 1")
    echo "System: Begränsar till 1 CPU-tråd."
else
    ffmpeg_args=()
    echo "System: Använder standard (alla trådar)."
fi

# Skapa huvudmappen för videofiler
mkdir -p "$base_save_dir"

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
            exit 0
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

    # Hantera avbrutna .part-filer och rensa skräp under 100kb
    echo "Letar efter avbrutna inspelningar (.part-filer)..."
    find "$base_save_dir" -type f -name "*.mp4.part" -size -100k -delete
    
    find "$base_save_dir" -type f -name "*.mp4.part" | while read -r part_file; do
        new_file="${part_file%.mp4.part}-avbruten.mp4"
        mv "$part_file" "$new_file"
        echo "Fixade fil: $(basename "$part_file") -> $(basename "$new_file")"
    done
    echo "Filhanteringen är klar."

    exit 0
}

echo "Bevakning startad ($today). Logg sparas i: $log_file"

while true; do
    # NYTT: Skapar den nya filen baserad på scriptets namn om den saknas
    if [[ ! -f "$input_file" ]]; then
        echo "Hittar inte listan. Skapar en ny automatisk fil på: $input_file"
        echo "# Lägg till Webbsite-namn eller hela URL-adresser här (ett per rad)" > "$input_file"
        echo "# Rader som börjar med # hoppas över automatiskt" >> "$input_file"
        echo "byt_ut_mig_mot_streamernamn" >> "$input_file"
        exit 1
    elif [[ ! -s "$input_file" ]]; then
        echo "Fel: Listan ($input_file) är helt tom (0 kb)."
        echo "# Lägg till Webbsite-namn eller hela URL-adresser här (ett per rad)" > "$input_file"
        echo "byt_ut_mig_mot_streamernamn" >> "$input_file"
        exit 1
    fi

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        clean_line=$(echo "$raw_line" | sed 's/#.*//')
        item=$(echo "$clean_line" | tr -d '\r\n\t ')
        
        [[ -z "$item" ]] && continue

        item="${item#/}"
        item="${item%/}"

        if [[ "$item" == http://* || "$item" == https://* ]]; then
            url="$item"
        elif [[ "$item" == *twitch.tv* ]]; then
            url="https://$item"
        else
            url="https://example.com"
        fi

        safe_name=$(echo "$url" | tr -dc '[:alnum:]-')
        lock_file="$temp_dir/${today}-${safe_name}.lock"
        
        if [[ -f "$lock_file" ]]; then
            echo "--- $url körs redan idag i ett annat fönster. Hoppar över. ---"
            continue
        fi

        echo "--- Kollar: $url ---"
        touch "$lock_file"
        start_time=$(date "+%Y-%m-%d %H:%M:%S")
        
        # NYTT: yt-dlp skapar nu undermappen själv baserat på profilnamn (uploader)
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate "${ffmpeg_args[@]}" \
            -o "$base_save_dir/%(uploader)s/%(title)s - %(upload_date)s.%(ext)s" "$url"
        
        status=$?
        rm -f "$lock_file"

        if [ $status -eq 0 ]; then
            end_time=$(date "+%Y-%m-%d %H:%M:%S")
            log_entry="[$start_time till $end_time] $url ONLINE"
            
            if [[ "$url" == *"twitch.tv"* ]]; then
                title=$(yt-dlp --get-title --no-check-certificate "$url" 2>/dev/null)
                log_entry="$log_entry - Titel: $title"
            fi
            echo "$log_entry" >> "$log_file"
        else
            wait_time=$(( ( RANDOM % 14 ) + 2 ))
            echo "Offline/Klar: Väntar $wait_time sekunder..."
            
            read -t "$wait_time" -n 1 key
            [[ $key == "q" ]] && cleanup_and_exit
        fi
    done < "$input_file"

    read -t 5 -n 1 key
    [[ $key == "q" ]] && cleanup_and_exit
done
