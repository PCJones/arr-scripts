#!/bin/bash

# Function to log messages with structured formatting
log() {
    local log_type="$1"
    local message="$2"
    # Output log messages to stderr to avoid contaminating function return values
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$log_type] $message" >&2
}

# Function to pause and wait for user input
pause() {
    read -p "Press [Enter] to continue..."
}

# Function to clean series name by removing the book number
clean_series_name() {
    echo "$1" | sed 's/#[0-9]*//g' | sed 's/ *$//g'
}

# Function to remove directory if it is empty
remove_if_empty() {
    dir="$1"
    if [ -d "$dir" ] && [ "$(ls -A "$dir")" == "" ]; then
        log "INFO" "Directory $dir is empty now. Removing it."
        rmdir "$dir"
    fi
}

check_for_subdirectories() {
    local dir="$1"
    
    # Check if the directory contains any subdirectories
    if [ "$(find "$dir" -mindepth 1 -type d | wc -l)" -gt 0 ]; then
        # Check specifically if a subdirectory named "CD1" exists
        if [ -d "$dir/CD1" ]; then
            return 1  # "CD1" directory found, return 1
        else
            return 0  # Subdirectories found, but none is "CD1"
        fi
    else
        return 1  # No subdirectories found
    fi
}


# Function to check if a directory is completely empty (no files or subdirectories)
check_if_empty_directory() {
    local dir="$1"
    if [ "$(ls -A "$dir")" == "" ]; then
        return 0  # Directory is empty
    else
        return 1  # Directory is not empty
    fi
}

# Function to check if there are no audio or ebook files in the directory
check_for_audio_or_ebook_files() {
    local dir="$1"
    
    # Check for audio or ebook files
	if find "$dir" -type f \( -iname "*.mp3" -o -iname "*.m4a" -o -iname "*.m4b" -o -iname "*.epub" \) | grep -q .; then
		return 0  # Audio or ebook files found
	fi
    
    # Check if "CD1" folder exists
    if [ -d "$dir/CD1" ]; then
        return 0  # "CD1" folder found
    fi
    
    return 1  # No audio or ebook files found, and no "CD1" folder found
}


# Function to fix double whitespace in a string
fix_double_whitespace() {
    echo "$1" | sed 's/  */ /g'
}

# Function to check for double whitespace in title, author, or series and ask to fix
check_and_fix_whitespace() {
    local field_name="$1"
    local field_value="$2"
    local metadata_file="$3"
    local jq_field="$4"

    # Only return the fixed value
    if [[ "$field_value" =~ "  " ]]; then
        log "WARNING" "Double whitespace detected in $field_name: \"$field_value\""
        local suggested_fix
        suggested_fix=$(fix_double_whitespace "$field_value")
        log "INFO" "Suggested fix for $field_name: \"$suggested_fix\""
        read -p "Would you like to fix the double whitespace in $field_name (current: \"$field_value\" -> fix: \"$suggested_fix\")? This will edit the metadata.json file (Y/n): " fix_whitespace_input
        fix_whitespace_input=${fix_whitespace_input:-Y}

        if [[ "$fix_whitespace_input" =~ ^[Yy] ]]; then
            log "INFO" "Fixing double whitespace in $field_name"
            if [ "$dry_run" = false ]; then
                jq --arg new_value "$suggested_fix" ".$jq_field = \$new_value" "$metadata_file" > tmp.$$.json && mv tmp.$$.json "$metadata_file"
            fi
            echo "$suggested_fix"  # Return the fixed value only
        else
            echo "$field_value"  # Return original if not fixed
        fi
    else
        echo "$field_value"  # No fix needed, return original
    fi
}

# Function to remove empty directories recursively up to the base path
remove_empty_parents_up_to_base() {
    local dir="$1"
    local base_dir="$2"

    # Loop through the directory hierarchy upwards until we reach the base directory
    while [ "$dir" != "$base_dir" ] && [ "$dir" != "/" ]; do
        if [ -d "$dir" ] && [ "$(ls -A "$dir")" == "" ]; then
            log "INFO" "Directory $dir is empty now. Removing it."
            rmdir "$dir"
        else
            break  # Stop if the directory is not empty
        fi
        dir=$(dirname "$dir")  # Move to the parent directory
    done
}


# Ask for the base folder
read -p "Enter the base directory for audiobooks: " base_folder

# Remove trailing slash from base_folder if it exists
base_folder=$(echo "$base_folder" | sed 's:/*$::')

# Check if the base folder exists
if [ ! -d "$base_folder" ]; then
    log "ERROR" "Base directory does not exist."
	pause
    exit 1
fi

# Ask if dry mode is on or off (default to on)
read -p "Enable dry mode? (Y/n): " dry_mode_input
dry_mode=${dry_mode_input:-Y}

# Convert dry mode input to lowercase for comparison
dry_mode=$(echo "$dry_mode" | tr '[:upper:]' '[:lower:]')

# Dry run flag
if [[ "$dry_mode" == "y" || "$dry_mode" == "yes" ]]; then
    log "INFO" "Running in dry mode."
    dry_run=true
else
    dry_run=false
fi

# Log the base directory being searched
log "INFO" "Searching for metadata.json files in: $base_folder"

# Find all metadata.json files in the base folder recursively (explicit recursive search)
IFS=$'\n' read -rd '' -a metadata_files <<< "$(find "$base_folder" -type f -name "metadata.json" -print)"

# Log how many metadata.json files were found
log "INFO" "Found ${#metadata_files[@]} metadata.json files."

# If no metadata.json files found, print a message and exit
if [ ${#metadata_files[@]} -eq 0 ]; then
    log "INFO" "No metadata.json files found in the base directory."
    exit 0
fi

# Process each metadata.json
for metadata_file in "${metadata_files[@]}"; do
    # Log which metadata.json file is being processed
    current_dir=$(dirname "$metadata_file")
    log "INFO" "Processing metadata.json in directory: $current_dir"

    # Check if the directory is completely empty
    if check_if_empty_directory "$current_dir"; then
        log "WARNING" "Conflict: Directory $current_dir is completely empty. Please resolve the issue before proceeding."
        pause  # Wait for the user to resolve the conflict

        # After resolving the conflict, check if the directory is still empty
        if check_if_empty_directory "$current_dir"; then
            log "WARNING" "Directory $current_dir is still empty after user intervention. Skipping this directory."
            continue  # Skip this directory
        fi
    fi

    # Check if the directory contains subdirectories
    if check_for_subdirectories "$current_dir"; then
        log "WARNING" "Conflict: Directory $current_dir contains subdirectories along with metadata.json. Please resolve the issue before proceeding."
        log "INFO" "Subdirectories detected: $(find "$current_dir" -mindepth 1 -type d)"
        pause  # Wait for the user to resolve the conflict

        # After resolving the conflict, check if metadata.json still exists
        if [ ! -f "$metadata_file" ]; then
            log "WARNING" "metadata.json has been removed from $current_dir. Skipping this directory."
            continue  # Skip this directory
        fi
    fi

    # Check if there are no audio or ebook files in the directory
    if ! check_for_audio_or_ebook_files "$current_dir"; then
        log "WARNING" "Conflict: No audio or ebook files found in $current_dir. Please resolve this issue before proceeding."
        pause  # Wait for the user to resolve the conflict

        # After resolving the conflict, check if audio or ebook files exist now
        if ! check_for_audio_or_ebook_files "$current_dir"; then
            log "WARNING" "No audio or ebook files found after user intervention. Skipping this directory."
            continue  # Skip this directory
        fi
    fi

	# Read necessary fields from metadata.json
	authors=$(jq -r '.authors // .metadata.authors | join(", ") // empty' "$metadata_file")
	title=$(jq -r '.title // .metadata.title // empty' "$metadata_file")
	published_year=$(jq -r '.publishedYear // .metadata.publishedYear // empty' "$metadata_file")
	series=$(jq -r '.series[0] // .metadata.series[0] // empty' "$metadata_file")

	# Check for double whitespaces in authors, title, and series
	authors=$(check_and_fix_whitespace "authors" "$authors" "$metadata_file" "authors")
	title=$(check_and_fix_whitespace "title" "$title" "$metadata_file" "title")
	series=$(check_and_fix_whitespace "series" "$series" "$metadata_file" "series")

	# Log the extracted metadata fields
	log "INFO" "Extracted metadata: authors=\"$authors\", title=\"$title\", published_year=\"$published_year\", series=\"$series\""

	# Handle missing or empty fields (if authors or title are empty, log it and skip)
	if [ -z "$authors" ] || [ -z "$title" ]; then
		log "ERROR" "Missing data in $metadata_file. Skipping this audiobook."
		pause
		continue
	fi

	# Build the correct target folder structure after potential whitespace fixes
	if [ -n "$series" ]; then
		series_clean=$(clean_series_name "$series")
		if [ -n "$published_year" ]; then
			target_dir="$base_folder/$authors/$series_clean/$title ($published_year)"
		else
			target_dir="$base_folder/$authors/$series_clean/$title"
		fi
	else
		if [ -n "$published_year" ]; then
			target_dir="$base_folder/$authors/$title ($published_year)"
		else
			target_dir="$base_folder/$authors/$title"
		fi
	fi

    # Log the target directory path
    log "INFO" "Target directory: $target_dir"

	# Compare current directory with target directory
	if [ "$current_dir" != "$target_dir" ]; then
		log "INFO" "Mismatch found:"
		log "INFO" "  Current: $current_dir"
		log "INFO" "  Target:  $target_dir"

		# Check if target directory already exists
		if [ -d "$target_dir" ]; then
			log "WARNING" "Target directory already exists. Most likely a duplicate. Please resolve this conflict by hand."
			pause
		else
			# Ensure the parent directory of the target exists
			parent_target_dir=$(dirname "$target_dir")
			if [ ! -d "$parent_target_dir" ]; then
				log "INFO" "Parent directory $parent_target_dir does not exist. Creating it..."
				if [ "$dry_run" = true ]; then
					log "INFO" "Dry Run: Would create directory \"$parent_target_dir\""
				else
					mkdir -p "$parent_target_dir"
				fi
			fi

			# Perform the move if not in dry mode, otherwise just print the action
			if [ "$dry_run" = true ]; then
				log "INFO" "Dry Run: Would move \"$current_dir\" to \"$target_dir\""
			else
				log "INFO" "Moving \"$current_dir\" to \"$target_dir\"..."
				mv "$current_dir" "$target_dir"
				
				# Check and remove empty directories upwards until we reach the base path
				remove_empty_parents_up_to_base "$(dirname "$current_dir")" "$base_folder"
			fi
		fi
	else
		log "INFO" "Directory structure is correct for: $current_dir"
	fi
done

log "INFO" "Script completed."
