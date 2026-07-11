#!/bin/bash

# En lista med de actors/streamers du vill kolla
actors=("anyactor1" "anyactor2" "anyactor3")

for actor in "${actors[@]}"
do
    echo "Försöker hämta: $actor"

    # Kör yt-dlp
    yt-dlp --hls-use-mpegts --ignore-errors --no-check-certificate https://example.com/${actor}

    # Kolla om yt-dlp misslyckades (exit code är något annat än 0)
    if [ $? -ne 0 ]; then
        echo "Kunde inte hämta $actor (offline eller fel), går vidare till nästa..."
    else
        echo "Nedladdning klar eller avbruten för $actor."
    fi
done

echo "Loopen är klar."
