# remove-sonarr-queue-duplicates.sh

Description: Removes all duplicate episodes from Sonarr queue (and thus from SABnzbd/NZBget) except for the newest grab (which should have the highest score/quality). 
How to run (Linux/MacOS/WSL only): 
1. Add executable rights: `chmod +x remove-sonarr-queue-duplicates.sh`
2. Add a cronjob (e.g. `crontab -e`) that runs every 5 Minutes that executes ´remove-sonarr-queue-duplicates.sh`