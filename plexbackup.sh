#!/bin/bash


# Backup a Plex database.
# Original Author Scott Smereka
# Edited by Neil C.
# Edited by Derik Holland
# Version 1.4


# Script Tested on:
# Ubuntu 20.04 on 2020-Aug-9 [ OK ] 

plexServer="192.168.4.102"
plexPort=32400

source "/opt/plexupdate/plexupdate-core"

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
    error "Server ${plexServer} is currently being used by one or more users, skipping installation. Please run again later"
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
