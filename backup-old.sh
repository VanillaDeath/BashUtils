#!/bin/bash

cleanUp () {
	rm -rf "$tempDir"
	echo
	exit $1
}

# Temporary directory
tempDir=$(mktemp -d "${TMPDIR:-/tmp/}$(basename "$0").XXXXXXXXXXXX")
# Clean up temporary directory on every unclean exit
trap 'cleanUp' SIGHUP SIGINT SIGTERM

# Define the excludes file in temporary directory
excludes="$tempDir/excludes"
# Clean up excludes file when starting a new backup from this script
[ -f "$excludes" ] && rm "$excludes"

# Call these variables to change text colour/format, default resets, under underlines
black="\033[0;30m";     gray="\033[1;30m";
blue="\033[0;34m";      lblue="\033[1;34m";
green="\033[0;32m";     lgreen="\033[1;32m";
cyan="\033[0;36m";      lcyan="\033[1;36m";
red="\033[0;31m";       lred="\033[1;31m";
purple="\033[0;35m";    lpurple="\033[1;35m";
brown="\033[0;33m";     yellow="\033[1;33m";
silver="\033[0;37m";    white="\033[1;37m";
default="\033[0m";      under="\033[4m";
inverse="\033[7m";

errorMsg () {
	echo -e " $red$1$default"
}

# Handle file-checking appropriately
checkExist () {
	srcDest=${2:-"src"}
	quitOnBlank=${3:-false}
	if [[ ${#1} = 0 && $quitOnBlank = true ]]; then
		errorMsg "No file/directory specified. Quitting."
		cleanUp 1
	elif [ -e "$1" ]; then
		echo -e " ${green}$([[ $srcDest = "src" ]] && echo "Source" || echo "Destination") directory specified: $1$default"
	else
		errorMsg "Specified $([[ $srcDest = "src" ]] && echo "source" || echo "destination") directory $1 does not exist."
	fi
}

echo -e "\n${under}${lblue}Wilson's All-Purpose Backup Script v1.0$default"
echo -e "Command-line syntax:\n$ $lcyan./backup.sh$default ${under}SOURCE$default ${under}DESTINATION$default"
echo -e "\nYou can drag and drop items from Finder for Source and Destination.\n"

# Check source parameter
if [[ ${#1} > 0 ]]; then
       	src=$1
	checkExist "$src" "src" false
fi
# If no source parameter, or source parameter invalid, prompt interactively
until [ ${#src} -gt 0 -a -e "$src" ]; do
	read -p "Source directory (copy FROM here): " src
	checkExist "$src" "src" true
done

# Check destination parameter
if [[ ${#2} > 0 ]]; then
	dest=$2
	checkExist "$dest" "dest" false
fi
# If no destination paramter, or destination parameter invalid, prompt interactively
until [ ${#dest} -gt 0 -a -e "$dest" ]; do
	read -p "Destination directory (copy INTO here): " dest
	checkExist "$dest" "dest" true
done

echo -e "\nExclude these file/directory patterns from backup. Press <Return> when done."
echo " Example: /*/Library/"

# Prompt for exclusions until just <Return> entered, up to 100
i=1
while [ $i -le 100 ]; do
	read -p "Exclusion $i$( [[ $i = 1 ]] && echo " [<Return> to skip]"): " exclude
	[[ ${#exclude} > 0 ]] && echo "$exclude" >> "$excludes" || break
	((i++))
done

# Prompt to run with sudo (default Yes), gets system/special files from source
echo
read -p "Do you want to run with elevated privileges (use sudo)? [Y/n] " elevate
case $elevate in
	""|"y"|"Y"|"yes"|"YES")
		elevate=true;;
	*)
		elevate=false;;
esac

# Build rsync command based on parameters and input
cmd_rsync="$([[ $elevate = true ]] && echo "sudo ")rsync --archive --append --progress --human-readable $([ -f "$excludes" ] && echo "--exclude-from=${excludes// /\\ } ")$src $dest"
echo -e "\nCopy the underlined command to File Transfers sticky in case you need to resume it later:\n${under}${cmd_rsync}${default}\n"
read -p "Do you want to run this backup? [Y/n] " confirm
case $confirm in
	""|"y"|"Y"|"yes"|"YES")
		echo -e "\nRunning: $cmd_rsync\n"
		$cmd_rsync
		;;
	*)
		echo -e "\nQuitting."
		# Remove temporary directory since no backup started
		cleanUp 0;;
esac
