#!/bin/bash

# --- KONFIGURATION ---
script_dir=$(dirname "$(readlink -f "$0")")
script_name="${0##*/}"
script_base="${script_name%.sh}"
input_file="$script_dir/${script_base}.txt"

base_save_dir="$HOME/stream_videos"
log_file="$script_dir/log/stream_history.log"
config_file="$HOME/.ffmpeg_threads_config"
size_config_file="$HOME/.file_size_config"
sleep_config_file="$HOME/.sleep_config"
temp_dir="/tmp/stream_locks"
today=$(date +%Y%m%d)
# ---------------------

# Skapa mappar om de inte existerar
mkdir -p "$temp_dir"
mkdir -p "$script_dir/log"

# 1. Hantera inställning för slumpmässig paus
if [[ ! -f "$sleep_config_file" ]]; then
    echo "--- Inställning för slumpmässig paus ---"
    read -p "Ange maximal väntetid i sekunder när en kanal är offline (eller tryck ENTER for 15): " sleep_choice
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

# 3. För-skanning av textfilen efter initclean och overwrite
# --- UPPDATERING SIDA 1 ---
auto_clean=""
debug_output="/dev/null" # Standard: Gömmer feltext
overwrite_mode="--no-overwrites"
dirkeep_active="no"

if [[ -f "$input_file" ]]; then
    # Skanna efter initclean
    if grep -iq "^[[:space:]]*initclean(yes)" "$input_file"; then
        auto_clean="yes"
    elif grep -iq "^[[:space:]]*initclean(no)" "$input_file"; then
        auto_clean="no"
    fi

    # NYTT: Skanna efter initDebug vid start
    if grep -iq "^[[:space:]]*initdebug(yes)" "$input_file"; then
        debug_output="/dev/stderr"
        echo "System: Debug-läge AKTIVERAT. Röd feltext visas."
    fi

    if grep -iq "^[[:space:]]*overwrite(yes)" "$input_file"; then
        overwrite_mode="--force-overwrites"
        echo "System: Överskrivning AKTIVERAD (overwrite=yes)."
    elif grep -iq "^[[:space:]]*overwrite(dirkeep)" "$input_file"; then
        overwrite_mode="--no-overwrites"
        dirkeep_active="yes"
        echo "System: Mapp-bevakning AKTIVERAD (overwrite=dirkeep). Befintliga mappar hoppas över helt."
    elif grep -iq "^[[:space:]]*overwrite(no)" "$input_file" || grep -iq "^[[:space:]]*overwrite(keep)" "$input_file"; then
        overwrite_mode="--no-overwrites"
        echo "System: Överskrivning INAKTIVERAD (overwrite=no/keep). Filer kontrolleras individuellt."
    else
        echo "System: Ingen overwrite-inställning hittades. Använder standard (no-overwrites)."
    fi
fi

# Hantering av initclean(yes/no) - Rensar loggfilen
if [[ "$auto_clean" == "yes" ]]; then
    if [[ -f "$log_file" ]]; then
        rm -f "$log_file" 2>/dev/null
        echo "System: initclean(yes) upptäcktes. Gamla loggar har raderats."
    fi
elif [[ "$auto_clean" == "no" ]]; then
    : 
else
    if [ "$(find "$temp_dir" -name "*.lock" 2>/dev/null | wc -l)" -gt 0 ]; then
        echo "Hittade gamla lock-filer från tidigare körningar."
        read -p "Vill du rensa gamla låsfiler innan start? (j/n): " purge_choice
        if [[ "$purge_choice" =~ ^(j|J|ja|JA)$ ]]; then
            rm -f "$temp_dir"/*.lock 2>/dev/null
            echo "Gamla låsfiler raderade."
        fi
    fi
fi

# 4. Kontrollera att ffmpeg finns installerat i systemet
if ! command -v ffmpeg &> /dev/null; then
    echo "FEL: ffmpeg saknas. Installera med: sudo apt update && sudo apt install ffmpeg"
    exit 1
fi

# 5. Hantera inställning for ffmpeg-trådar
if [[ ! -f "$config_file" ]]; then
    read -p "Begränsa ffmpeg till 1 tråd? (Rekommenderas for Raspberry Pi) (j/n): " thread_choice
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

# 6. Hantera inställning for rensning av skräpfiler
if [[ ! -f "$size_config_file" ]]; then
    echo "--- Inställning for rensning av skräpfiler ---"
    read -p "Hur små avbrutna filer ska raderas? Ange i kb (t.ex. 500), eller tryck bara ENTER for 1000kb: " size_choice
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

# Skapa huvudmappen for videofiler
mkdir -p "$base_save_dir"

# --- 100% FÖNSTERSÄKRAD STÄDFUNKTION (STRUNTAR I STORA/SMÅ BOKSTÄVER) ---
run_folder_cleanup() {
    echo "Rensar tomma mappar men behåller dina inspelningar..."
    find "$base_save_dir" -mindepth 1 -type d -empty -delete

    echo "Letar efter avbrutna inspelningar (.part-filer)..."
    find "$base_save_dir" -type f -name "*.mp4.part" -size -"$min_file_size" | while read -r junk_part; do
        parent_dir=$(basename "$(dirname "$junk_part")")
        lock_match=$(find "$temp_dir" -name "*.lock" -type f 2>/dev/null)
        is_active="no"
        for l_file in $lock_match; do
            l_name=$(basename "$l_file" .lock)
            # KORRIGERING: [,,] gör om båda namnen till små bokstäver under jämförelsen
            if [[ "${l_name,,}" == *"${parent_dir,,}"* ]]; then
                r_pid=$(cat "$l_file" 2>/dev/null)
                if [[ -n "$r_pid" ]] && kill -0 "$r_pid" 2>/dev/null; then
                    is_active="yes"
                    break
                fi
            fi
        done
        if [[ "$is_active" == "no" ]]; then
            rm -f "$junk_part" 2>/dev/null
        fi
    done
    
    find "$base_save_dir" -type f -name "*.mp4.part" | while read -r part_file; do
        parent_dir=$(basename "$(dirname "$part_file")")
        lock_match=$(find "$temp_dir" -name "*.lock" -type f 2>/dev/null)
        is_active="no"
        for l_file in $lock_match; do
            l_name=$(basename "$l_file" .lock)
            # KORRIGERING: [,,] gör om till små bokstäver för skiftlägesoberoende matchning
            if [[ "${l_name,,}" == *"${parent_dir,,}"* ]]; then
                r_pid=$(cat "$l_file" 2>/dev/null)
                if [[ -n "$r_pid" ]] && kill -0 "$r_pid" 2>/dev/null; then
                    is_active="yes"
                    break
                fi
            fi
        done
        
        if [[ "$is_active" == "no" ]]; then
            new_file="${part_file%.mp4.part}-avbruten.mp4"
            mv "$part_file" "$new_file"
            echo "Fixade fil: $(basename "$part_file") -> $(basename "$new_file")"
        fi
    done

    echo "Sorterar mindre videofiler (mellan ${min_size_num}kb och 100000kb)..."
    find "$base_save_dir" -type f -name "*.mp4" -size +"${min_size_num}k" -size -100000k | while read -r video_file; do
        current_dir=$(dirname "$video_file")
        dir_name=$(basename "$current_dir")
        
        if [[ "$dir_name" == *"-mindre-filer" ]]; then
            continue
        fi
        
        lock_match=$(find "$temp_dir" -name "*.lock" -type f 2>/dev/null)
        is_active="no"
        for l_file in $lock_match; do
            l_name=$(basename "$l_file" .lock)
            # KORRIGERING: [,,] skyddar även färdiga .mp4-filer från att flyttas under pågående inspelning
            if [[ "${l_name,,}" == *"${dir_name,,}"* ]]; then
                r_pid=$(cat "$l_file" 2>/dev/null)
                if [[ -n "$r_pid" ]] && kill -0 "$r_pid" 2>/dev/null; then
                    is_active="yes"
                    break
                fi
            fi
        done
        
        if [[ "$is_active" == "yes" ]]; then
            continue
        fi
        
        if [[ ! -s "$video_file" ]]; then
            rm -f "$video_file" 2>/dev/null
            continue
        fi
        
        file_size_bytes=$(stat -c%s "$video_file" 2>/dev/null)
        if [[ -n "$file_size_bytes" ]] && [ "$file_size_bytes" -lt 512000 ]; then
            rm -f "$video_file" 2>/dev/null
            echo "Tyst rensning: Tog bort tom skräpfil från offline-kanal: $(basename "$video_file")"
            continue
        fi
        
        new_dir="$base_save_dir/${dir_name}-mindre-filer"
        mkdir -p "$new_dir"
        
        mv "$video_file" "$new_dir/"
        echo "Flyttade liten fil: $(basename "$video_file") -> ${dir_name}-mindre-filer/"
    done

    find "$base_save_dir" -mindepth 1 -type d -empty -delete
    echo "Mapp- och filhanteringen är klar."
}

cleanup_and_exit() {
    echo -e "\n"
    find "$temp_dir" -name "*.lock" -type f | while read -r lock_f; do
        if [ "$(cat "$lock_f" 2>/dev/null)" == "$$" ]; then
            rm -f "$lock_f" 2>/dev/null
        fi
    done
    
    read -p "Vill du behålla de nedladdade filerna? (j/n): " choice
    if [[ "$choice" =~ ^(n|N|nej|NEJ)$ ]]; then
        echo -e "\a"
        read -p "ÄR DU HELT SÄKER? Detta raderar ALLA undermappar permanent! (j/n): " confirm
        if [[ "$confirm" =~ ^(j|J|ja|JA)$ ]]; then
            find "$base_save_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
            echo "Alla mappar och filer har raderats."
            exit 0
        else
            echo "Radering avbruten."
            run_folder_cleanup
        fi
    else
        run_folder_cleanup
    fi
    exit 0
}
echo "Bevakning startad. Logg sparas i: $log_file"

while true; do
    if [[ ! -f "$input_file" ]]; then
        echo "Hittar inte listan. Skapar en ny automatisk fil på: $input_file"
        echo "# Lägg till Webbsite(webbsajt)-namn, hela URL-adresser, delay(sekunder), url(länk, \"Mappnamn\") eller clear(folder) här" > "$input_file"
        echo "# Rader som börjar med # hoppas över automatiskt" >> "$input_file"
        echo "byt_ut_mig_mot_streamernamn" >> "$input_file"
        exit 1
    elif [[ ! -s "$input_file" ]]; then
        echo "Fel: Listan ($input_file) är helt tom (0 kb)."
        echo "# Lägg till Webbsite(webbsajt)-namn, hela URL-adresser, delay(sekunder), url(länk, \"Mappnamn\") eller clear(folder) här" > "$input_file"
        echo "byt_ut_mig_mot_streamernamn" >> "$input_file"
        exit 1
    fi

    current_overwrite_mode="--no-overwrites"
    current_dirkeep_active="no"

    while IFS= read -r raw_line <&3 || [[ -n "$raw_line" ]]; do
        clean_line=$(echo "$raw_line" | sed 's/#.*//')
        clean_line=$(echo "$clean_line" | tr -d '\r\n\t')
        item=$(echo "$clean_line" | xargs)
        
        [[ -z "$item" ]] && continue

        # Hoppa över initclean() i loopen (sköts vid start)
        if [[ "$item" == initclean\(* || "$item" == InitClean\(* || "$item" == initClean\(* || "$item" == INITCLEAN\(* ]]; then
            continue
        fi

        # --- NY FUNKTION: Kolla efter det dynamiska kommandot clear(folder) ---
        if [[ "$item" == clear\(folder\) || "$item" == Clear\(folder\) || "$item" == CLEAR\(FOLDER\) ]]; then
            echo "--- Manuellt kommando: Startar automatisk mapp- och filrensning ---"
            run_folder_cleanup
            continue
        fi
        # ----------------------------------------------------------------------

        # SKOTTSÄKER DYNAMISK OVERWRITE
        if [[ "$item" == overwrite\(* || "$item" == Overwrite\(* ]]; then
            if [[ "$item" == *"yes"* ]]; then
                current_overwrite_mode="--force-overwrites"
                current_dirkeep_active="no"
                echo "-> Ändrar läge: Överskrivning AKTIVERAD (overwrite=yes)"
            elif [[ "$item" == *"dirkeep"* ]]; then
                current_overwrite_mode="--no-overwrites"
                current_dirkeep_active="yes"
                echo "-> Ändrar läge: Mapp-bevakning AKTIVERAD (overwrite=dirkeep)"
            elif [[ "$item" == *"no"* || "$item" == *"keep"* ]]; then
                current_overwrite_mode="--no-overwrites"
                current_dirkeep_active="no"
                echo "-> Ändrar läge: Överskrivning INAKTIVERAD (overwrite=no/keep)"
            fi
            continue
        fi

    # 3. FUNKTION: Kolla efter delay(sekunder)
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

    # 4. FUNKTION: Avancerad URL- och Mappväljare
    custom_folder=""
    if [[ "$item" == url\(* || "$item" == Url\(* ]]; then
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

    item="${item#/}"
    item="${item%/}"

    # --- KORRIGERAT URL-BLOCK (Sida 8 i din PDF) ---
    if [[ "$item" == http://* || "$item" == https://* ]]; then
        url="$item"
    elif [[ "$item" == *twitch.tv* ]]; then
        url="https://${item}"
    else
        url="https://twitch.tv/${item}"
    fi

    # NYTT: Skapa det säkra namnet på lock-filen (UTAN datum)
        # --- UPPDATERING SIDA 7 ---
        # Vi lägger till _ inuti kontrollen för att stödja understreck
        safe_name=$(echo "$url" | tr -dc '[:alnum:]_-')
        lock_file="$temp_dir/${safe_name}.lock"

    # 5. DYNAMISK MAPP-BEVAKNING (dirkeep - FIXAD OCH FÖNSTERSÄKRAD)
    if [[ "$current_dirkeep_active" == "yes" ]]; then
      check_folder="$custom_folder"
      if [[ -z "$check_folder" ]]; then
        check_folder="${url##*/}"
      fi

      # Kolla om en annan LEVANDE terminal har låst filen
      if [[ -f "$lock_file" ]]; then
        running_pid=$(cat "$lock_file" 2>/dev/null)
        if [[ -n "$running_pid" ]] && kill -0 "$running_pid" 2>/dev/null; then
          echo "--- Mappen '$check_folder' hanteras just nu av ett annat fönster (PID: $running_pid). Hoppar över! ---"
          continue
        fi
      fi

      if [[ -d "$base_save_dir/$check_folder" ]] && [ "$(find "$base_save_dir/$check_folder" -maxdepth 1 -type f | wc -l)" -gt 0 ]; then
        echo "--- Mappen '$check_folder' finns redan och har innehåll. Hoppar över blixtsnabbt! ---"
        continue
      fi
    fi

    # NYTT: SJÄLVLÄKANDE OCH KROCKSÄKER LÅSKONTROLL (Kanalerna krockar ALDRIG mer!)
    if [[ -f "$lock_file" ]]; then
      running_pid=$(cat "$lock_file" 2>/dev/null)
      # kill -0 kollar om processen (terminalfönstret) fortfarande lever i Linux
      if [[ -n "$running_pid" ]] && kill -0 "$running_pid" 2>/dev/null; then
        echo "--- $url körs just nu i ett annat fönster (PID: $running_pid). Hoppar över. ---"
        continue
      else
        echo "--- Hittade en gammal död låsfil för $url. Rensar och tar över! ---"
        rm -f "$lock_file" 2>/dev/null
      fi
    fi

    echo "--- Kollar: $url ---"
    # Skriv in den här terminalens unika ID ($$) i låsfilen
    echo "$$" > "$lock_file"
    start_time=$(date "+%Y-%m-%d %H:%M:%S")

    if [[ -n "$custom_folder" ]]; then
      output_template="$base_save_dir/${custom_folder}/%(title)s - %(upload_date)s.%(ext)s"
      echo "-> Sparas i egen vald mapp: $custom_folder"
    else
      output_template="$base_save_dir/%(uploader)s/%(title)s - %(upload_date)s.%(ext)s"
    fi

    # # Kör yt-dlp med det för stunden gällande overwrite-läget
        # --- UPPDATERING SIDA 8 ---
        # Kör yt-dlp och skicka feltexten till vår dynamiska debug-variabel
        yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate "$current_overwrite_mode" "${ffmpeg_args[@]}" \
            -o "$output_template" "$url" </dev/null 2>$debug_output

    status=$?
    rm -f "$lock_file"

    # KORRIGERING: Helt omarbetad och isolerad loggning. Krockar aldrig med kanal 3!
    # KORRIGERING: Fixat stjärntecknet (twitch.tv) så att loggningen hoppar igång direkt!
    # --- KORRIGERAT LOGG-BLOCK (Sida 9 i din PDF) ---
    if [ $status -eq 0 ]; then
      end_time=$(date "+%Y-%m-%d %H:%M:%S")
      log_entry="[$start_time till $end_time] $url ONLINE"

      # Kontrollera om det är Twitch (Fixat stjärntecken)    
      if [[ "$url" == *"twitch.tv"* ]]; then
        title=$(yt-dlp --get-title --no-check-certificate "$url" 2>/dev/null)
        log_entry="$log_entry - Titel: $title"
      # NYTT: Hantering för YouTube (Hämtar titeln utan att hänga sig på livesändningar)
      elif [[ "$url" == *"youtube.com"* || "$url" == *"youtu.be"* ]]; then
        title=$(yt-dlp --get-title --no-check-certificate --match-filter "!is_live" "$url" 2>/dev/null)
        # Om det var en livesändning returnerar kommandot inget, sätt då en standardtext
        [[ -z "$title" ]] && title="YouTube Live Stream"
        log_entry="$log_entry - Titel: $title"
      fi      
      # Vi skriver till loggfilen via ett rent under-skal för att garantera att loopen inte dör
      (echo "$log_entry" >> "$log_file") 2>/dev/null      
    else
      wait_time=$(( ( RANDOM % sleep_interval ) + 2 ))
      echo "Offline/Klar: Väntar $wait_time sekunder..."

      read -t "$wait_time" -n 1 key < /dev/tty
      [[ $key == "q" ]] && cleanup_and_exit
    fi
  done 3< "$input_file"

  #read -t 5 -n 1 key < /dev/tty
  #[[ $key == "q" ]] && cleanup_and_exit
    # sleep blockerar tangentbordskrockar helt mellan fönstren!
    sleep 5  
done