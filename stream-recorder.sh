#!/bin/bash

# --- KONFIGURATION ---
script_dir=$(dirname "$(readlink -f "$0")")
script_name="${0##*/}"
script_base="${script_name%.sh}"
input_file="$script_dir/${script_base}.txt"

base_save_dir="$HOME/stream_videos"
log_file="$HOME/stream_history.log"
config_file="$HOME/.ffmpeg_threads_config"
size_config_file="$HOME/.file_size_config"
sleep_config_file="$HOME/.sleep_config"
temp_dir="/tmp/stream_locks"
today=$(date +%Y%m%d)
# ---------------------

# Skapa temp-mappen om den inte existerar
mkdir -p "$temp_dir"

# 1. Hantera inställning för slumpmässig paus
if [[ ! -f "$sleep_config_file" ]]; then
    echo "--- Inställning för slumpmässig paus ---"
    read -p "Ange maximal väntetid i sekunder när en kanal är offline (eller tryck ENTER för 15): " sleep_choice
    if [[ -z "$sleep_choice" ]]; then
        sleep_choice="15"
    fi
    sleep_choice=$(echo "$sleep_choice" | tr -dc '0-9')
    echo "$sleep_choice" > "$sleep_config_file"
    echo "Inställning sparad: Pausar mellan 2 och ${sleep_choice} sekunder."
fi
max_sleep=$(cat "$sleep_config_file" 2>/dev/null)

# 2. Slumpmässig startfördröjning
min_sleep=5
if [ "$max_sleep" -lt "$min_sleep" ]; then
    max_sleep=$min_sleep
fi

start_interval=$(( max_sleep - min_sleep + 1 ))
random_start_sleep=$(( ( RANDOM % start_interval ) + min_sleep ))

echo "Systemet startar. Väntar i en slumpmässig fördröjning på $random_start_sleep sekunder (mellan $min_sleep och $max_sleep)..."
echo "-> Tryck på en tangent för att hoppa över väntetiden och starta direkt."

read -t "$random_start_sleep" -n 1 key < /dev/tty
if [[ -n "$key" ]]; then
    echo -e "\nHoppar över fördröjningen och startar direkt..."
fi

# 3. NYTT: För-skanning av textfilen efter clean(yes/no)
auto_clean=""
if [[ -f "$input_file" ]]; then
    # Letar efter clean(yes) eller clean(no) (struntar i skiftläge och kommentarer)
    if grep -iq "^[[:space:]]*clean(yes)" "$input_file"; then
        auto_clean="yes"
    elif grep -iq "^[[:space:]]*clean(no)" "$input_file"; then
        auto_clean="no"
    fi
fi

# Kolla efter gamla lock-filer som inte tillhör dagens datum
old_locks=$(find "$temp_dir" -name "*.lock" ! -name "${today}-*.lock" 2>/dev/null)

if [[ -n "$old_locks" ]]; then
    if [[ "$auto_clean" == "yes" ]]; then
        # Automatisk rensning (Tyst)
        find "$temp_dir" -name "*.lock" ! -name "${today}-*.lock" -delete 2>/dev/null
    elif [[ "$auto_clean" == "no" ]]; then
        # Automatisk ignorering (Tyst)
        : # Gör ingenting
    else
        # Inget kommando hittades i filen - ställ den vanliga frågan
        echo "Hittade gamla lock-filer från tidigare dagar."
        read -p "Vill du rensa gamla låsfiler innan start? (j/n): " purge_choice
        if [[ "$purge_choice" =~ ^(j|J|ja|JA)$ ]]; then
            find "$temp_dir" -name "*.lock" ! -name "${today}-*.lock" -delete 2>/dev/null
            echo "Gamla låsfiler raderade."
        fi
    fi
fi

# 4. Kontrollera att ffmpeg finns installerat i systemet
if ! command -v ffmpeg &> /dev/null; then
    echo "FEL: ffmpeg saknas. Installera med: sudo apt update && sudo apt install ffmpeg"
    exit 1
fi

# 5. Hantera inställning för ffmpeg-trådar
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

# 6. Hantera inställning för rensning av skräpfiler
if [[ ! -f "$size_config_file" ]]; then
    echo "--- Inställning för rensning av skräpfiler ---"
    read -p "Hur små avbrutna filer ska raderas? Ange i kb (t.ex. 500), eller tryck bara ENTER för 1000kb: " size_choice
    if [[ -z "$size_choice" ]]; then
        size_choice="1000"
    fi
    size_choice=$(echo "$size_choice" | tr -dc '0-9')
    echo "$size_choice" > "$size_config_file"
    echo "Inställning sparad: Raderar avbrutna filer mindre än ${size_choice}kb."
fi
min_size_num=$(cat "$size_config_file" 2>/dev/null)
min_file_size="${min_size_num}k"

sleep_interval=$(( max_sleep - 2 + 1 ))
if [ $sleep_interval -le 0 ]; then
    sleep_interval=1
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
            echo "Rering avbruten. Rensar tomma mappar men behåller dina inspelningar..."
            find "$base_save_dir" -mindepth 1 -type d -empty -delete
            echo "Klara inspelningar sparades. Tomma mappar togs bort."
        fi
    else
        echo "Rensar tomma mappar men behåller dina inspelningar..."
        find "$base_save_dir" -mindepth 1 -type d -empty -delete
        echo "Filerna behålls."
    fi

    echo "Letar efter avbrutna inspelningar (.part-filer)..."
    find "$base_save_dir" -type f -name "*.mp4.part" -size -"$min_file_size" -delete
    
    find "$base_save_dir" -type f -name "*.mp4.part" | while read -r part_file; do
        new_file="${part_file%.mp4.part}-avbruten.mp4"
        mv "$part_file" "$new_file"
        echo "Fixade fil: $(basename "$part_file") -> $(basename "$new_file")"
    done

    echo "Sorterar mindre videofiler (mellan ${min_size_num}kb och 100000kb)..."
    find "$base_save_dir" -type f -name "*.mp4" -size +"${min_size_num}k" -size -100000k | while read -r video_file; do
        current_dir=$(dirname "$video_file")
        dir_name=$(basename "$current_dir")
        
        if [[ "$dir_name" == *"-mindre-filer" ]]; then
            continue
        fi
        
        new_dir="$base_save_dir/${dir_name}-mindre-filer"
        mkdir -p "$new_dir"
        
        mv "$video_file" "$new_dir/"
        echo "Flyttade liten fil: $(basename "$video_file") -> ${dir_name}-mindre-filer/"
    done

    find "$base_save_dir" -mindepth 1 -type d -empty -delete
    echo "Filhanteringen är klar."
    exit 0
}

echo "Bevakning startad ($today). Logg sparas i: $log_file"

while true; do
    if [[ ! -f "$input_file" ]]; then
        echo "Hittar inte listan. Skapar en ny automatisk fil på: $input_file"
        echo "# Lägg till Webbsida-namn, hela URL-adresser, delay(sekunder) eller url(länk, \"Mappnamn\") här" > "$input_file"
        echo "# Rader som börjar med # hoppas över automatiskt" >> "$input_file"
        echo "byt_ut_mig_mot_streamernamn" >> "$input_file"
        exit 1
    elif [[ ! -s "$input_file" ]]; then
        echo "Fel: Listan ($input_file) är helt tom (0 kb)."
        echo "# Lägg till Webbsida-namn, hela URL-adresser, delay(sekunder) eller url(länk, \"Mappnamn\") här" > "$input_file"
        echo "byt_ut_mig_mot_streamernamn" >> "$input_file"
        exit 1
    fi

    # Vi läser filen via kanal 3 (u3)
    while IFS= read -r raw_line <&3 || [[ -n "$raw_line" ]]; do
        # 1. Ta bort kommentarer
        clean_line=$(echo "$raw_line" | sed 's/#.*//')
        
        # KORRIGERING: Ta bort dolda Windows-kontrolltecken (\r) men behåll vanliga mellanslag
        clean_line=$(echo "$clean_line" | tr -d '\r\n\t')
        
        # Trimma endast mellanslag i början och slutet av raden
        item=$(echo "$clean_line" | xargs)
        
        [[ -z "$item" ]] && continue

        # --- NY FUNKTION: Hoppa över clean(yes) och clean(no) i loopen ---
        if [[ "$item" =~ ^[cC]lean\( ]]; then
            continue
        fi

        # --- FUNKTION: Kolla efter delay(sekunder) ---
        if [[ "$item" =~ ^[dD]elay\(([0-9]+)\)$ ]]; then
            custom_delay="${BASH_REMATCH[1]}"
            echo "--- Manuellt kommando: Pausar i $custom_delay sekunder ---"
            echo "-> Tryck 'q' för att hoppa över pausen."
            
            read -t "$custom_delay" -n 1 delay_key < /dev/tty
            if [[ "$delay_key" == "q" ]]; then
                read -t 2 -n 1 -p "Vill du avsluta hela skriptet? (q för ja, vänta för att hoppa över): " confirm_key < /dev/tty
                if [[ "$confirm_key" == "q" ]]; then
                    cleanup_and_exit
                fi
                echo -e "\nHoppar över denna paus..."
            fi
            continue
        fi

        # --- FUNKTION: Avancerad URL- och Mappväljare (MED KOMMA-KONTROLL) ---
        custom_folder=""
        if [[ "$item" =~ ^[uU]rl\( ]]; then
            # SÄKERHETSSPÄRR: Kolla om raden saknar ett kommatecken
            if [[ "$item" != *","* ]]; then
                echo "-> FEL: Raden '$item' saknar kommatecken (,). Hoppar över..."
                continue
            fi

            # 1. Klipp ut allt efter "url(" fram till kommatecknet
            extracted_url=$(echo "$item" | sed -E "s/^[uU]rl\(([^,]+),.*/\1/" | xargs)
            
            # 2. Klipp ut allt efter kommatecknet till slutet av raden            
            extracted_folder=$(echo "$item" | cut -d',' -f2-)

            # 3. Tvätta mappnamnet: ta bort slutparentes och alla typer av citationstecken            
            custom_folder=$(echo "$extracted_folder" | tr -d ')"' | tr -d "'" | xargs)

            # 4. Sätt variabeln item till den rena länken
            item="$extracted_url"
            
            echo "-> Identifierade specialkommando!"
            echo "-> Länk: $item"
            echo "-> Mapp: $custom_folder"
        fi
        # ---------------------------------------------------------------------

        item="${item#/}"
        item="${item%/}"

        if [[ "$item" == http://* || "$item" == https://* ]]; then
            url="$item"
        elif [[ "$item" == *twitch.tv* ]]; then
            url="https://${item}"
        else
            url="https://example.com{item}"
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
        
        # Bestäm utmatningsformat (Dynamisk mapp eller standard från yt-dlp)
        if [[ -n "$custom_folder" ]]; then
            output_template="$base_save_dir/${custom_folder}/%(title)s - %(upload_date)s.%(ext)s"
            echo "-> Sparas i egen vald mapp: $custom_folder"
        else
            output_template="$base_save_dir/%(uploader)s/%(title)s - %(upload_date)s.%(ext)s"
        fi

        # Kör yt-dlp och stäng dess stdin
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate "${ffmpeg_args[@]}" \
            -o "$output_template" "$url" </dev/null
        
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
            wait_time=$(( ( RANDOM % sleep_interval ) + 2 ))
            echo "Offline/Klar: Väntar $wait_time sekunder..."
            
            read -t "$wait_time" -n 1 key < /dev/tty
            [[ $key == "q" ]] && cleanup_and_exit
        fi
    done 3< "$input_file"

    read -t 5 -n 1 key < /dev/tty
    [[ $key == "q" ]] && cleanup_and_exit
done
