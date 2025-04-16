#!/bin/bash

# This script is used with cron to automate server restarts and backups for individual Pufferpanel servers.

# It performs the following tasks:
# - Handles server backups by creating timestamped archives,
# - limits backup storage to a defined maximum,
# - and facilitates smooth server restarts via PufferPanel's API.
# The script includes customizable warning messages and leverages OAuth2 for secure authentication.

# PufferPanel API details
API_URL="<Pufferpanel URL>"
CLIENT_ID="<Pufferpanel Client ID>"
CLIENT_SECRET="<Client Secret>"
SERVER_ID="<Pufferpanel Server ID>"
BACKUP_DIR="/var/lib/pufferpanel/servers/${SERVER_ID}/backups"
SERVER_DIR="/var/lib/pufferpanel/servers/${SERVER_ID}/Pal/Saved"
MAX_BACKUPS=7

# Get OAuth2 token
TOKEN=$(curl -s -X POST \
  "$API_URL/oauth2/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET" | jq -r '.access_token')

# Function to send a console command
send_console_command() {
    local command=$1
    curl -X 'POST' \
        "$API_URL/daemon/server/$SERVER_ID/console" \
        -H 'accept: application/json' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer $TOKEN" \
        -d "$command"
}

# Function to perform the backup
perform_backup() {
    # Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create backup file with timestamp and server id
backup_file="$BACKUP_DIR/$(date +'%Y-%m-%d')_${SERVER_ID}.zip"

# Exclude backup directory from backup
zip -r "$backup_file" "$SERVER_DIR" -x "$BACKUP_DIR/*"

# Remove old backups if more than MAX_BACKUPS
while [ $(ls -l "$BACKUP_DIR" | grep -c ^- ) -gt $MAX_BACKUPS ]
do
    # Get the oldest backup file and remove it
    old_backup=$(ls -t "$BACKUP_DIR" | tail -1)
    rm "$BACKUP_DIR/$old_backup"
done
}

# Send warning messages - needs to be replaced with palworld equivalents e.g., /Broadcast <MessageText> - also will the console command function still work?
#send_console_command 'tellraw @a {"rawtext":[{"text":"§eServer restarting in 5 minutes!"}]}'
#sleep 240 # Wait for 4 minutes

#send_console_command 'tellraw @a {"rawtext":[{"text":"§cServer restarting in 1 minute!"}]}'
#sleep 60  # Wait for 1 minute

#send_console_command 'tellraw @a {"rawtext":[{"text":"§4Restarting server..."}]}'

# Stop the server
curl -X 'POST' \
    "$API_URL/daemon/server/$SERVER_ID/stop?wait=true" \
    -H 'accept: application/json' \
    -H "Authorization: Bearer $TOKEN" \
    -d ''

# Wait for 30 seconds
sleep 30

# Perform backup
perform_backup

# Start the server
curl -X 'POST' \
    "$API_URL/daemon/server/$SERVER_ID/start?wait=true" \
    -H 'accept: application/json' \
    -H "Authorization: Bearer $TOKEN" \
    -d ''

echo "Server $SERVER_ID restart completed."
