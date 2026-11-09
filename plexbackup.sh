#!/bin/bash

# Backup a Plex database.
# Original Author Scott Smereka
# Edited by Neil C.
# Edited by Derik Holland
# Version 1.5 - Replaced broken plexupdate-core session check with a
#               self-contained Plex API token based check.

# Script Tested on:
# Ubuntu 20.04 on 2020-Aug-9 [ OK ]

plexServer="192.168.4.102"
plexPort=32400

# Plex API token. Required since Plex now rejects /status/sessions
# requests without one (401 Unauthorized). Pulled live from the server's
# own Preferences.xml so there's no plaintext token sitting in this script.
plexToken=$(grep -oP 'PlexOnlineToken="\K[^"]+' "/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Preferences.xml")

if [[ -z "$plexToken" ]]; then
    echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: ERROR: Could not read PlexOnlineToken from Preferences.xml." | tee -a $log 2>&1
    exit 2
fi

# Plex Database Location. The trailing slash is
# needed and important for rsync.
plexDatabase="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server"

# Location to backup the directory to.
backupDirectory="/mnt/Backup/PMS"

# Number of days to retain backups.
retentionDays=30

# Log file for script's output named with
# the script's name, date, and time of execution.
scriptName=$(basename ${0})
scriptPath=$(realpath ${0})
log="/mnt/Backup/PMS/logs/plexbackup.log"

# Check for root permissions
if [[ $EUID -ne 0 ]]; then
echo -e "${scriptName} requires root privileges.\n"
echo -e "sudo $0 $*\n"
exit 1
fi

# Log a simple error message (replaces the old plexupdate-core "error" helper).
error() {
    echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: ERROR: $*" | tee -a $log 2>&1
}

# Returns 0 (true) if Plex currently has one or more active sessions.
# Returns 1 (false) if Plex is confirmed idle.
# If the server can't be reached at all, treat that as NOT running so the
# backup still attempts (adjust this if you'd rather fail closed).
running() {
    local server="$1"
    local port="$2"
    local resp
    resp=$(curl -s -m 10 "http://${server}:${port}/status/sessions?X-Plex-Token=${plexToken}")

    if [[ -z "$resp" ]]; then
        error "Could not reach Plex at ${server}:${port} to check session status."
        return 1
    fi

    if echo "$resp" | grep -q "Unauthorized"; then
        error "Plex token rejected (401 Unauthorized). Update plexToken in the script."
        return 1
    fi

    local size
    size=$(echo "$resp" | grep -oP 'MediaContainer[^>]*size="\K[0-9]+' | head -1)

    if [[ -z "$size" ]]; then
        error "Could not parse session count from Plex response."
        return 1
    fi

    [[ "$size" -gt 0 ]]
}

# Schedule a one-time at job for the next day at 3:00 AM to retry the backup.
schedule_retry() {
    echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Scheduling retry for tomorrow at 3:00 AM." | tee -a $log 2>&1
    echo "sudo bash ${scriptPath}" | at 03:00 tomorrow >> $log 2>&1
    if [[ $? -eq 0 ]]; then
        echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Retry successfully scheduled." | tee -a $log 2>&1
    else
        echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: ERROR: Failed to schedule retry. Is 'at' installed?" | tee -a $log 2>&1
    fi
}

# Create Log
echo -e "***********" >> $log 2>&1
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Checking if Plex is running." | tee -a $log 2>&1

# Check if Plex is running
if running "${plexServer}" "${plexPort}"; then
    error "Server ${plexServer} is currently being used by one or more users, skipping backup. Please run again later"
    echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Plex is running. Not going to do backup right now." | tee -a $log 2>&1
    schedule_retry
    echo -e "***********" >> $log 2>&1
    exit 6
fi

# Stop Plex
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Plex is not running. Stopping Plex Media Server." | tee -a $log 2>&1
sudo service plexmediaserver stop | tee -a $log 2>&1

# Backup database
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Starting Backup." | tee -a $log 2>&1
# WORKING Line: sudo tar cfz "$backupDirectory/buplex-$(date '+%Y-%m(%b)-%d at %khr %Mmin').tar.gz"  "$plexDatabase" >> $log 2>&1
# cd into  directory so the magic --exclude below works per:
# https://stackoverflow.com/questions/984204/shell-command-to-tar-directory-excluding-certain-files-folders
cd "$plexDatabase"
sudo tar cz --exclude='./Cache' -f "$backupDirectory/Derik-Plex-$(date '+%Y-%m(%b)-%d').tar.gz" . >> $log 2>&1

# Restart Plex
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Starting Plex Media Server." | tee -a $log 2>&1
sudo service plexmediaserver start | tee -a $log 2>&1

# Delete backups older than the retention period
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Deleting backups older than ${retentionDays} days." | tee -a $log 2>&1
find "$backupDirectory" -maxdepth 1 -name "Derik-Plex-*.tar.gz" -mtime +${retentionDays} -print -delete >> $log 2>&1

# Done
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Backup Complete." | tee -a $log 2>&1
echo -e "***********" >> $log 2>&1
