#!/bin/bash

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

declare -A PATH_MAPPINGS

read_config() {
    if [[ -f "$1" ]]; then
        while IFS='=' read -r key value; do
            case "$key" in
                'radarr_url') RADARR_URL="$value" ;;
                'api_key') API_KEY="$value" ;;
                'destination_folder') DESTINATION_FOLDER="$value" ;;
                'use_symbolic_links') USE_SYMBOLIC_LINKS="$value" ;;
                'dry_run') DRY_RUN="$value" ;;
                'path_mapping'* ) # Support for multiple path mappings
                    IFS=',' read -r src dst <<< "${value}"
                    PATH_MAPPINGS["$src"]="$dst"
                    ;;
            esac
        done < "$1"
    fi
}

apply_path_mappings() {
    local path="$1"
    for src in "${!PATH_MAPPINGS[@]}"; do
        if [[ "$path" == $src* ]]; then
            path="${path/#$src/${PATH_MAPPINGS[$src]}}"
            break
        fi
    done
    echo "$path"
}

CONFIG_FILE="create-file-links-from-radarr-api.conf"

# Override with command-line arguments if provided
while getopts ":c:u:k:d:s:r:m:" opt; do
    case ${opt} in
        c ) CONFIG_FILE=$OPTARG ;;
        u ) RADARR_URL=$OPTARG ;;
        k ) API_KEY=$OPTARG ;;
        d ) DESTINATION_FOLDER=$OPTARG ;;
        s ) USE_SYMBOLIC_LINKS=$OPTARG ;;
        r ) DRY_RUN=$OPTARG ;;
        m ) IFS=',' read -r src dst <<< "$OPTARG"
            PATH_MAPPINGS["$src"]="$dst"
            ;;
        \? ) log "Usage: cmd [-c config_file] [-u radarr_url] [-k api_key] [-d destination_folder] [-s use_symbolic_links] [-r dry_run] [-m path_mapping]"; exit ;;
    esac
done

# Read from config file
read_config "$CONFIG_FILE"

# Validate mandatory parameters
if [[ -z "$RADARR_URL" || -z "$API_KEY" || -z "$DESTINATION_FOLDER" || -z "$DRY_RUN" ]]; then
    log "Radarr URL, API Key, DRY RUN, and Destination Folder are required."
    exit 1
fi

# Initialize page variables
page=1
totalPages=1

# Function to process files
process_files() {
    local sourceTitle="$1"
    local droppedPath="$2"
    local importedPath="$3"

    # Apply path mappings
    droppedPath=$(apply_path_mappings "$droppedPath")
    importedPath=$(apply_path_mappings "$importedPath")

    # Extract base file name without extension for importedPath, and escape it
    local baseFileNameImportedEscaped=$(printf '%q' "$(basename "$importedPath" | rev | cut -d. -f2- | rev)")
    # Extract base file name without extension for droppedPath, and escape it
    local baseFileNameDroppedEscaped=$(printf '%q' "$(basename "$droppedPath" | rev | cut -d. -f2- | rev)")

    # Log the directory about to be searched
    local searchDirectory="$(dirname "$importedPath")"
    log "Searching directory: $searchDirectory for files matching base name: $baseFileNameImportedEscaped.*"

    # Check if directory exists before attempting to find to avoid the error
    if [ ! -d "$searchDirectory" ]; then
        log "Error: Search directory does not exist: $searchDirectory"
        return # Exit the function to avoid further errors
    fi

    # Temporarily store the matching files in an array
    local matchingFiles=($(find "$searchDirectory" -type f -name "${baseFileNameImportedEscaped}.*"))
    if [ ${#matchingFiles[@]} -eq 0 ]; then
        log "No matching files found for: $baseFileNameImportedEscaped.*"
        return # Exit the function as there are no files to process
    fi

    # Create the destination folder if there are files to link and if not in dry run
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$DESTINATION_FOLDER/$sourceTitle" && log "Created destination folder: $DESTINATION_FOLDER/$sourceTitle"
    else
        log "[Dry Run] Would create destination folder: $DESTINATION_FOLDER/$sourceTitle"
    fi

    # Process each matching file
    for filePath in "${matchingFiles[@]}"; do
        local fileName=$(basename "$filePath")
        local fileExtension="${fileName##*.}"
        local finalFileName="${baseFileNameDroppedEscaped}.${fileExtension}"

        log "Processing file: $filePath. Target file name: $finalFileName"

        # Create hardlink or symbolic link based on configuration, using the final file name
        if [[ -n "$USE_SYMBOLIC_LINKS" && "$DRY_RUN" == "false" ]]; then
            ln -s "$filePath" "$DESTINATION_FOLDER/$sourceTitle/$finalFileName" && log "Created symbolic link for $filePath at $DESTINATION_FOLDER/$sourceTitle/$finalFileName"
        elif [[ "$DRY_RUN" == "false" ]]; then
            ln "$filePath" "$DESTINATION_FOLDER/$sourceTitle/$finalFileName" && log "Created hardlink for $filePath at $DESTINATION_FOLDER/$sourceTitle/$finalFileName"
        else
            if [[ -n "$USE_SYMBOLIC_LINKS" ]]; then
                log "[Dry Run] Would create symbolic link for $filePath at $DESTINATION_FOLDER/$sourceTitle/$finalFileName"
            else
                log "[Dry Run] Would create hardlink for $filePath at $DESTINATION_FOLDER/$sourceTitle/$finalFileName"
            fi
        fi
    done
}


log "Starting processing of pages. Initial Page: $page, Total Pages Calculated: $totalPages"

# Loop through all pages
# Initialize associative array to keep track of processed movie IDs
declare -A processedMovieIds

while [ $page -le $totalPages ]; do
    log "Fetching data for page $page of $totalPages"
    response=$(curl -s -G "${RADARR_URL}/api/v3/history" --data-urlencode "apikey=${API_KEY}" --data "page=${page}" --data "includeMovie=true" --data "eventType=3")
    
    # Parse total page count from the first request
    if [[ $page -eq 1 ]]; then
        totalPages=$(echo "$response" | jq '.totalRecords')
        totalPages=$((totalPages + 9 / 10)) # Calculate total pages based on 10 records per page
        log "Total pages recalculated based on total records: $totalPages"
        if [[ $totalPages -eq 0 ]]; then
            log "No history records found. Exiting."
            exit 0
        fi
    fi
    
    echo "$response" | jq -r '.records | map(select(.eventType == "downloadFolderImported")) | .[] | "\(.movieId)|\(.sourceTitle)|\(.data.droppedPath)|\(.data.importedPath)"' | while IFS='|' read -r movieId sourceTitle droppedPath importedPath; do
        # Check if movieId has already been processed
        if [[ -z "${processedMovieIds[$movieId]}" ]]; then
            log "Processing record for $sourceTitle"
            process_files "$sourceTitle" "$droppedPath" "$importedPath"
            # Mark movieId as processed
            processedMovieIds[$movieId]=1
        else
            log "Skipping already processed movieId: $movieId for $sourceTitle"
        fi
    done
    
    ((page++))
done


log "Data extraction and linking process complete."
