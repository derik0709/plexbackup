#!/bin/bash


# Backup a Plex database.
# Original Author Scott Smereka
# Edited by Neil C.
# Edited by Derik Holland
# Version 1.2


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


# Log file for script's output named with 
# the script's name, date, and time of execution.
scriptName=$(basename ${0})
log="/mnt/Backup/PMS/logs/plexbackup.log"


# Check for root permissions
if [[ $EUID -ne 0 ]]; then
echo -e "${scriptName} requires root privileges.\n"
echo -e "sudo $0 $*\n"
exit 1
fi


# Create Log
echo -e "***********" >> $log 2>&1
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Mounted Share in R/W Mode." | tee -a $log 2>&1


# Check if Plex is running
if running "${plexServer}" "${plexPort}"; then
    error "Server ${plexServer} is currently being used by one or more users, skipping installation. Please run again later"
    exit 6
fi

# Stop Plex
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Stopping Plex Media Server." | tee -a $log 2>&1
sudo service plexmediaserver stop | tee -a $log 2>&1


# Backup database
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Starting Backup." | tee -a $log 2>&1
# WORKING Line: sudo tar cfz "$backupDirectory/buplex-$(date '+%Y-%m(%b)-%d at %khr %Mmin').tar.gz"  "$plexDatabase" >> $log 2>&1
# cd into  directory so the magic --exclude below works per:
# https://stackoverflow.com/questions/984204/shell-command-to-tar-directory-excluding-certain-files-folders
cd "$plexDatabase"
sudo tar cz --exclude='./Cache' -f "$backupDirectory/Derik-Plex-$(date '+%Y-%m(%b)-%d at %khr %Mmin').tar.gz" . >> $log 2>&1


# Restart Plex
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Starting Plex Media Server." | tee -a $log 2>&1
sudo service plexmediaserver start | tee -a $log 2>&1


# Done
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Backup Complete." | tee -a $log 2>&1
echo -e "***********" >> $log 2>&1