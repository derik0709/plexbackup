#!/bin/bash


# Restore a Plex database.
# Original Author Scott Smereka
# Edited by Neil C.
# Edited by Derik Holland
# Version 1.2


# Script Tested on:
# Ubuntu 20.04 on 2020-Aug-9 [ OK ] 

# Plex Database Location. The trailing slash is 
# needed and important for rsync.
plexDatabase="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server"


# Location to backup the directory to.
backupDirectory="/mnt/Backup/PMS"


# Log file for script's output named with 
# the script's name, date, and time of execution.
scriptName=$(basename ${0})
log="/mnt/Backup/PMS/logs/plexrestore.log"


# Check for root permissions
if [[ $EUID -ne 0 ]]; then
echo -e "${scriptName} requires root privileges.\n"
echo -e "sudo $0 $*\n"
exit 1
fi


# Create Log
echo -e "***********" >> $log 2>&1
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Starting restore of Plex database ." | tee -a $log 2>&1


# Stop Plex
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Stopping Plex Media Server." | tee -a $log 2>&1
sudo service plexmediaserver stop | tee -a $log 2>&1


# Select backup to restore
printf "Which backup do you want to restore? \n"

while [ -z "$name" ]
do

    select name in "$backup/*.tar.gz"; do break; done

    if [ -z "$name" ]
    then
        if [ -f "$REPLY" ]
        then
            name="$REPLY"
            printf "You chose by name: '%s'\n" "$name"
        else
            printf "There is no file by that name.\n"
        fi
    else
        printf "You chose by number: '%s'\n" "$name"
    fi

done

# Restore database
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Starting restore process." | tee -a $log 2>&1
#sudo tar cz --exclude='./Cache' -f "$backupDirectory/Derik-Plex-$(date '+%Y-%m(%b)-%d at %khr %Mmin').tar.gz" . >> $log 2>&1
#sudo tar xz -f /mnt/Backup/PMS/Derik-PMS-2023-10\(Oct\)-16.tar.gz -C $plexDatabase


# Restart Plex
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Starting Plex Media Server." | tee -a $log 2>&1
sudo service plexmediaserver start | tee -a $log 2>&1


# Done
echo -e "$(date '+%Y-%b-%d at %k:%M:%S') :: Backup Complete." | tee -a $log 2>&1
echo -e "***********" >> $log 2>&1