#!/bin/bash

ORIGIN_REPO="https://github.com/${GIT_OWNER:-derik0709}/plexbackup"
FULL_PATH="/opt/plexbackup"
CONFIGCRON="/etc/plexbackup.cron.conf"
CRONWRAPPER="/etc/cron.daily/plexupdate"
VERBOSE=yes #to be inherited by get-plex-token, do not save to config

# variables to save in config
CONFIGVARS="AUTOINSTALL AUTODELETE DOWNLOADDIR TOKEN FORCE FORCEALL PUBLIC AUTOSTART AUTOUPDATE PLEXSERVER PLEXPORT CHECKUPDATE NOTIFY"
CRONVARS="CONF SCRIPT LOGGING"

yesno() {
	case "$1" in
		"")
			default="Y"
			;;
		yes)
			default="Y"
			;;
		true)
			default="Y"
			;;
		no)
			default="N"
			;;
		false)
			default="N"
			;;
		*)
			default="$1"
			;;
	esac

	default="$(tr "[:lower:]" "[:upper:]" <<< "$default")"
	if [ "$default" == "Y" ]; then
		prompt="[Y/n] "
	else
		prompt="[N/y] "
	fi

	while true; do
		read -n 1 -p "$prompt" answer
		answer=${answer:-$default}
		answer="$(tr "[:lower:]" "[:upper:]" <<< "$answer")"

		if [ "$answer" == "Y" ]; then
			echo
			return 0
		elif [ "$answer" == "N" ]; then
			echo
			return 1
		fi
	done
}

noyes() {
	yesno N
}

install() {
	echo "'$req' is required but not installed, attempting to install..."
	sleep 1

	[ -z "$DISTRO_INSTALL" ] && check_distro

	if [ $EUID -ne 0 ]; then
		sudo $DISTRO_INSTALL $1 || abort "Failed while trying to install '$1'. Please install it manually and try again."
	else
		$DISTRO_INSTALL $1 || abort "Failed while trying to install '$1'. Please install it manually and try again."
	fi
}

check_distro() {
	if [ -f /etc/redhat-release ] && hash dnf 2>/dev/null; then
		DISTRO="redhat"
		DISTRO_INSTALL="dnf -y install"
	elif [ -f /etc/redhat-release ] && hash yum 2>/dev/null; then
		DISTRO="redhat" #or CentOS but functionally the same
		DISTRO_INSTALL="yum -y install"
	elif hash apt 2>/dev/null; then
		DISTRO="debian" #or Ubuntu
		DISTRO_INSTALL="apt install"
	elif hash apt-get 2>/dev/null; then
		DISTRO="debian"
		DISTRO_INSTALL="apt-get install"
	else
		DISTRO="unknown"
	fi
}

abort() {
	echo "$@"
	exit 1
}

install_plexbackup() {
	echo
	read -e -p "Directory to install into: " -i "/opt/plexbackup" FULL_PATH

	while [[ "$FULL_PATH" == *"~"* ]]; do
		echo "Using '~' in your path can cause problems, please type out the full path instead"
		echo
		read -e -p "Directory to install into: " -i "/opt/plexbackup" FULL_PATH
	done

	if [ ! -d "$FULL_PATH" ]; then
		echo -n "'$FULL_PATH' doesn't exist, attempting to create... "
		if ! mkdir -p "$FULL_PATH" 2>/dev/null; then
			sudo mkdir -p "$FULL_PATH" || abort "failed, cannot continue"
			sudo chown $(id -u):$(id -g) "$FULL_PATH" || abort "failed, cannot continue"
		fi
		echo "done"
	elif [ ! -w "$FULL_PATH" ]; then
		echo -n "'$FULL_PATH' exists, but you don't have permission to write to it. Changing owner... "
		sudo chown $(id -u):$(id -g) "$FULL_PATH" || abort "failed, cannot continue"
		echo "done"
	fi

	if [ -d "${FULL_PATH}/.git" ]; then
		cd "$FULL_PATH"
		if git remote -v 2>/dev/null | grep -q "plexupdate"; then
			echo -n "Found existing plexupdate repository in '$FULL_PATH', updating... "
			if [ -w "${FULL_PATH}/.git" ]; then
				git pull &>/dev/null || abort "unknown error while updating, please check '$FULL_PATH' and then try again."
			else
				sudo git pull &>/dev/null || abort "unknown error while updating, please check '$FULL_PATH' and then try again."
			fi
		else
			abort "'$FULL_PATH' appears to contain a different git repository, cannot continue"
		fi
		echo "done"
		cd - &> /dev/null
	else
		echo -n "Installing plexbackup into '$FULL_PATH'... "
		git clone --branch "${BRANCHNAME:-master}" "$ORIGIN_REPO" "$FULL_PATH" &> /dev/null || abort "install failed, cannot continue"
		echo "done"
	fi
}

if [ $EUID -ne 0 ]; then
	echo
	echo "This script needs to install files in system locations and will ask for sudo/root permissions now"
	sudo -v || abort "Root permissions are required for setup, cannot continue"
elif [ ! -z "$SUDO_USER" ]; then
	echo
	abort "This script will ask for sudo as necessary, but you should not run it as sudo. Please try again."
fi

for req in wget git sudo; do
	if ! hash $req 2>/dev/null; then
		install $req
	fi
done

if [ -f ~/.plexbackup ]; then
	echo
	echo -n "Existing configuration found in ~/.plexbackup, would you like to import these settings? "
	if yesno; then
		echo "Backing up old configuration as ~/.plexbackup.old. All new settings should be modified through this script, or by editing ${CONFIGFILE} directly. Please see README.md for more details."
		source ~/.plexbackup
		mv ~/.plexbackup ~/.plexbackup.old
	fi
fi

if [ -f "$(dirname "$0")/../plexbackup.sh" -a -d "$(dirname "$0")/../.git" ]; then
	FULL_PATH="$(readlink -f "$(dirname "$0")/../")"
	echo
	echo "Found plexbackup.sh in '$FULL_PATH', using that as your install path"
else
	install_plexbackup
fi
