#!/bin/bash

# Sonarr API URL and API Key
SONARR_URL="http://localhost:8989"
API_KEY="xx"

# Function to fetch the Sonarr queue
fetch_queue() {
  curl -s -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/queue"
}

# Function to delete a queue item by ID
delete_queue_item() {
  local id=$1
  response=$(curl -s -w "%{http_code}" -o /dev/null -X DELETE -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/queue/$id")
  echo "HTTP response code for deleting item with ID $id: $response"
}

# Fetch the queue
queue=$(fetch_queue)

# Debug: Output the fetched queue
echo "Fetched queue data: $queue"

# Check if the queue fetch was successful
if [[ -z "$queue" || "$queue" == "null" ]]; then
  echo "Failed to fetch the queue or the queue is empty."
  exit 1
fi

# Parse the queue and find duplicates
declare -A episodes
to_delete=()

# Iterate through the records in the queue
while IFS= read -r record; do
  episodeId=$(echo "$record" | jq -r '.episodeId')
  added=$(echo "$record" | jq -r '.added')
  id=$(echo "$record" | jq -r '.id')

  # Debug: Output the parsed record
  echo "Parsed record: episodeId=$episodeId, added=$added, id=$id"

  if [[ -n "${episodes[$episodeId]}" ]]; then
    existing_id=${episodes[$episodeId]%:*}
    existing_added=${episodes[$episodeId]#*:}

    if [[ "$added" > "$existing_added" ]]; then
      to_delete+=("$existing_id")
      episodes[$episodeId]="$id:$added"
    else
      to_delete+=("$id")
    fi
  else
    episodes[$episodeId]="$id:$added"
  fi
done < <(echo "$queue" | jq -c '.records[]')

# Debug: Output items marked for deletion
echo "Items to delete: ${to_delete[@]}"

# Check if there are items to delete
if [[ ${#to_delete[@]} -eq 0 ]]; then
  echo "No duplicate episodes to delete."
else
  # Delete the queued items marked for deletion
  for item in "${to_delete[@]}"; do
    id=${item%%:*}  # Extract only the ID part
    echo "Attempting to delete queue item with ID: $id"
    delete_queue_item "$id"
  done

  echo "Deleted ${#to_delete[@]} duplicate episodes."
fi
