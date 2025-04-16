#!/bin/bash

# This script automates server management for a Minecraft Bedrock server running via PufferPanel.
# It automates backups, updates, and restarts to keep the server updated and running smoothly.
# Ideal for use with cron to minimize manual oversight.

# It performs the following tasks:
# - Authenticates with PufferPanel's API to obtain an access token.
# - Sends console commands to notify players of an impending server restart.
# - Stops the server safely before performing maintenance.
# - Creates a timestamped backup of the server, keeping only the latest defined number of backups.
# - Downloads and installs the latest version of the Minecraft Bedrock server software.
# - Restores server settings from backup after updates.
# - Restarts the server to apply the updates.

# PufferPanel API details
API_URL="<Pufferpanel URL>"
CLIENT_ID="<Pufferpanel Client ID>"
CLIENT_SECRET="<Client Secret>"
SERVER_ID="<Pufferpanel Server ID>"
BACKUP_DIR="/var/lib/pufferpanel/servers/${SERVER_ID}/backups"
SERVER_DIR="/var/lib/pufferpanel/servers/${SERVER_ID}"
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

# Function to perform the update
perform_update() {
# Variables to be set as per end user preferences
# The directory holding your Bedrock server files
SERVER="/var/lib/pufferpanel/servers/${SERVER_ID}"

# The directory where you want the server software downloaded to
DOWNLOAD="/var/lib/pufferpanel/servers/${SERVER_ID}"

# The Minecraft Bedrock Server download page
# If Minecraft.net ever goes away or changes, this will need to be changed to
# the current distribution location.
BASE_URL='https://minecraft.net/en-us/download/server/bedrock/'

# User Agent to request page with
# Can be replaced with whatever the latest one is for Chrome \ Edge \ etc.
USER_AGENT='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36'

################################################################################
################################################################################
## BEGIN CODE - DO NOT MODIFY UNLESS YOU KNOW WHAT YOU ARE DOING              ##
################################################################################
################################################################################

URL=`curl -L ${BASE_URL} -H "user-agent: $USER_AGENT" 2>/dev/null| grep /bin-linux/ | grep -v preview | sed -e 's/.*<a href=\"\(https:.*\/bin-linux\/.*\.zip\).*/\1/'`

# Verify if the DOWNLOAD and SERVER destinations exist. Create if it doesn't
for check in "$DOWNLOAD" "$SERVER" ; do
  if [ ! -d ${check} ] ; then
    if [ -e ${check} ] ; then
      # Error out if it does exist but isn't a directory
      printf "\n%s is not a directory!\nPlease edit %s and change the line to point %s to the correct directory\n\n" "${check}" "$0" "${check}"
      exit 1
    fi
    mkdir -p ${check}
  fi
done

# Check for a backup copy of any existing server properties.
# Make a backup copy if none exists.
if [ ! -e ${SERVER}/server.properties.bak ] ; then
  cp ${SERVER}/server.properties ${SERVER}/server.properties.bak
fi
if [ ! -e ${SERVER}/allowlist.json.bak ] ; then
  cp ${SERVER}/allowlist.json ${SERVER}/allowlist.json.bak
fi
if [ ! -e ${SERVER}/permissions.json.bak ] ; then
  cp ${SERVER}/permissions.json ${SERVER}/permissions.json.bak
fi

# Check if a copy of the latest server exists in the DOWNLOAD directory
if [ ! -e ${DOWNLOAD}/${URL##*/} ] ; then
  # If it doesn't exist, clean up older update packages and retrieve the latest zip file and extract it to
  # the SERVER directory.

  # Clean previous update files - Remove .zip files starting with "bedrock_server" in the target directory
find "$SERVER_DIR" -maxdepth 1 -type f -name "bedrock-server*.zip" -exec rm -f {} \;

  #curl ${URL} -v --output ${DOWNLOAD}/${URL##*/} - This was updated to mimic browser headers
curl -A "$USER_AGENT" \
     -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
     -H "Accept-Language: en-US,en;q=0.5" \
     -H "Connection: keep-alive" \
     -H "Upgrade-Insecure-Requests: 1" \
     $URL --output ${DOWNLOAD}/${URL##*/}

  cd ${SERVER}
  unzip -o ${DOWNLOAD}/${URL##*/} 2>&1 > /dev/null
  # Copy the server properties backup into place
  cp ${SERVER}/server.properties.bak ${SERVER}/server.properties
  cp ${SERVER}/allowlist.json.bak ${SERVER}/allowlist.json
  cp ${SERVER}/permissions.json.bak ${SERVER}/permissions.json
  # Remove older copies of the server
  find ${DOWNLOAD} -maxdepth 1 -type f -name bedrock-server\*.zip ! -newer ${DOWNLOAD}/${URL##*/} ! -name ${URL##*/} -delete

# If it does, do nothing. Either the software was downloaded manually and
# setup should be finished manually or it has already been updated.
else
  printf "\nServer is up to date, nothing to do.\n\n"
fi
}

# Send warning messages
send_console_command 'tellraw @a {"rawtext":[{"text":"§eServer restarting in 5 minutes!"}]}'
#sleep 240 # Wait for 4 minutes

send_console_command 'tellraw @a {"rawtext":[{"text":"§cServer restarting in 1 minute!"}]}'
#sleep 60  # Wait for 1 minute

send_console_command 'tellraw @a {"rawtext":[{"text":"§4Restarting server..."}]}'

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

# Perform update
perform_update > "$SERVER_DIR/output.txt"

# Start the server
curl -X 'POST' \
    "$API_URL/daemon/server/$SERVER_ID/start?wait=true" \
    -H 'accept: application/json' \
    -H "Authorization: Bearer $TOKEN" \
    -d ''

echo "Server $SERVER_ID restart completed."
