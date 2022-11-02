#!/bin/bash

# Variable initialization
notice=""

# sudo by default?
elevate=1

# Ignore lines matching this pattern in excludes file
ignore_pattern='^\s*$\|^\s*#'

# Lines matching this pattern in log file are errors
error_pattern='failed:\|rsync error:'

# Temporary directory
tempDir=$(mktemp -d "${TMPDIR:-/tmp/}$(basename "$0").XXXXXXXXXXXX")

# Define the excludes and log files in temporary directory
excludes="$tempDir/excludes"
logfile="$tempDir/log"

# Clean up excludes file when starting a new backup from this script
[[ -f $excludes ]] && rm "$excludes"

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

# Clean-up function to remove temporary directory
cleanUp () {
	rm -rf "$tempDir"
	echo -e "$default"
	exit $1
}

# Clean up temporary directory on every unclean exit, 130 is error signal for <Ctrl>+<C>
trap 'cleanUp 130' SIGHUP SIGINT SIGTERM

# Set/display a notice or error
# Syntax: notice "Message." [notice|error] [true=echo now|false=echo before Enter option prompt]
notice () {
	case "$2" in
		"notice")
			msgColour="$lcyan"
			;;
		"error")
			msgColour="$red"
			;;
		*)
			msgColour="$default"
			;;
	esac
	notice="$msgColour$1$default"
	if [[ $3 == true ]]; then
		echo -e " $notice"
		notice=""
	fi
}

# Trap (almost) any key
anykey () {
	echo -e "$lblue"
	read -n 1 -s -p "Press any key to continue..."
	echo -e "$default"
}

# Handle file-checking appropriately
checkExist () {
	srcDest=${2:-"src"}
	checkBlank=${3:-false}
	fileExist=0
	if [[ ${#1} -eq 0 && $checkBlank == true ]]; then
		notice "No file/directory specified." error true
		fileExist=0
	elif [[ -e $1 ]]; then
		if [[ ( $srcDest == "src" && $1 == $dest ) || ( $srcDest == "dest" && $1 == "$src" ) ]]; then
			notice "Source and destination cannot be the same." error true
			fileExist=-2
		else
			notice "${green}$([[ $srcDest == "src" ]] && echo "Source" || echo "Destination") directory specified: $1$default" notice true
			fileExist=1
		fi
	else
		notice "Specified $([[ $srcDest == "src" ]] && echo "source" || echo "destination") directory $1 does not exist." "error" true
		fileExist=-1
	fi
}

getSrc () {
	fileExist=-1
	until [[ $fileExist -ge 0 ]]; do
		read -p "Source directory (copy FROM here): " input
		checkExist "$input" "src" $1
	done
	[[ $fileExist -ge 1 ]] && src=$input
	input=""
}
getDest () {
	fileExist=-1
	until [[ $fileExist -ge 0 ]]; do
		read -p "Destination directory (copy INTO here): " input
		checkExist "$input" "dest" $1
	done
	[[ $fileExist -ge 1 ]] && dest=$input
	input=""
}

getExcludeCount () {
	i=$(grep -cve "$ignore_pattern" "$excludes")
}

echo -e "\n${under}${lblue}Wilson's All-Purpose Backup Script v1.0$default"
echo -e "Command-line syntax:\n$ $lcyan./backup.sh$default ${under}SOURCE$default ${under}DESTINATION$default"
echo -e "\nYou can drag and drop items from Finder for Source and Destination.\n"


# Check source parameter
if [[ ${#1} -gt 0 ]]; then
       	src=$1
	checkExist "$src" "src" false
else
	fileExist=0
fi
# If no source parameter, or source parameter invalid, prompt interactively
[[ $fileExist -le 0 ]] && getSrc true
# If just <Return> pressed at interactive prompt, exit
[[ $fileExist -eq 0 ]] && cleanUp 1

# Check destination parameter
if [[ ${#2} -gt 0 ]]; then
	dest=$2
	checkExist "$dest" "dest" false
else
	fileExist=0
fi
# If no destination paramter, or destination parameter invalid, prompt interactively
[[ $fileExist -le 0 ]] && getDest true
# If just <Return> pressed at interactive prompt, exit
[[ $fileExist -eq 0 ]] && cleanUp 1


until [[ $selection =~ "(q|Q|x|X)" ]]; do
	if [[ -f "$excludes" ]]; then
		# [[ $i -eq 0 ]] && rm "$excludes"
		getExcludeCount
	else
		i=0
	fi
	cmd_rsync="$([[ $elevate -eq 1 ]] && echo "sudo ")rsync --archive --append --progress --human-readable --log-file=${logfile// /\\ } $([[ $i -gt 0 ]] && echo "--exclude-from=${excludes// /\\ } ")${src// /\\ } ${dest// /\\ }"
	echo -e "\nCopy this command to File Transfers sticky in case you need to resume it later:\n${purple}${cmd_rsync}${default}\n"
	
	echo -e "${inverse}MENU:${default} Type ${under}${lcyan}blue letter${default} and hit ${lcyan}<Return>${default}, or just hit ${lcyan}<Return>${default} to start transfer\n"
	echo -e "${under}${lcyan}G${default}O (or just hit ${lcyan}<Return>${default})\n"
	echo -e "${under}${lcyan}S${default}ource [$green$src$default]"
	echo -e "${under}${lcyan}D${default}estination [$green$dest$default]\n"
	echo -e "${under}${lcyan}L${default}ist Exclusions [$green$i$default]"
	echo -e "${under}${lcyan}A${default}dd Exclusions"
	echo -e "${under}${lcyan}O${default}pen Exclusions file directly (one exclusion pattern per line)"
	echo -e "${under}${lcyan}C${default}lear All Exclusions\n"
	echo -e "${under}${lcyan}E${default}levate execution (sudo) [$green$([[ $elevate -eq 1 ]] && echo "ON" || echo "OFF")$default]\n"
	echo -e "${under}${lcyan}Q${default}uit"
	
	if [[ ${#notice} -gt 0 ]]; then
		echo -e "\n $notice"
		notice=""
	else
		echo
	fi
	read -n 1 -p "Enter option (<Return> to start): " selection
	echo
	
	case $selection in
		""|"g"|"G")
			notice "Running: $green$cmd_rsync$default\n" notice true
			eval $cmd_rsync
			err_rsync=$?
			$(grep -wqi "$error_pattern" "$logfile")
			failed_lines=$?
			[[ $err_rsync -ne 0 || $failed_lines -eq 0 ]] && errors=1 || errors=0
			echo
			if [[ $errors -eq 0 ]]; then
				notice "Backup completed with no errors." notice true
			else
				notice "Backup completed with errors." error true
			fi
			until [[ $viewlog =~ "(|n|N|no|NO)" ]]; do
				read -n 1 -p "View log file? [y]es / [N]o$([[ $errors -eq 1 ]] && echo " / [e]rrors only"): " viewlog
				echo
				case "$viewlog" in
					"y"|"Y"|"yes"|"YES")
						$(open -e "$logfile")
						;;
					""|"n"|"N"|"no"|"NO")
						break;;
					"e"|"E"|"errors"|"ERRORS")
						if [[ $errors -eq 1 ]]; then
							$(grep -wi "$error_pattern" "$logfile" | open -fe)
						else
							notice "Invalid selection." error true
						fi
						;;
					*)
						notice "Invalid selection." error true
						;;
				esac
			done
			until [[ $removeTemp =~ "(|y|Y|yes|YES|n|N|no|NO)" ]]; do
				read -n 1 -p "Remove temporary data, including excludes and log files? [Y/n]: " removeTemp
				echo
				case "$removeTemp" in
					""|"y"|"Y"|"yes"|"YES")
						notice "Cleaning up and quitting." notice true
						cleanUp $err_rsync
						;;
					"n"|"N"|"no"|"NO")
						notice "Quitting, leaving temporary directory $green$tempDir$default" notice true
						exit $err_rsync
						;;
					*)
						notice "Invalid selection." error true
				esac
			done
			;;
		"s"|"S")
			getSrc true
			;;
		"d"|"D")
			getDest true
			;;
		"l"|"L")
			getExcludeCount
			if [[ $i -gt 0 ]]; then
				echo -e "Exclusion patterns for this backup are:\n$green"
				[[ $i -lt 20 ]] && grep -ve "$ignore_pattern" "$excludes" || grep -ve '^\s*$\|^\s*#' "$excludes" | less
				echo -e "$default"
				anykey
			else
				notice "No exclusions specified for this backup." notice
			fi
			echo
			;;
		"a"|"A")
			getExcludeCount
			echo -e "\nExclude these file/directory patterns from backup. Press <Return> when done."
			echo " Example: /*/Library/"

			# Prompt for exclusions until just <Return> entered, up to 100
			while [[ $i -le 100 ]]; do
				((j=$i+1))
				read -p "Exclusion $j$( [[ $j = 1 ]] && echo " [<Return> to cancel]"): " exclude
				[[ ${#exclude} -gt 0 ]] && echo "- $exclude" >> "$excludes" || break
				getExcludeCount
			done
			notice "Exclusions updated." notice
			;;
		"o"|"O")
			comment="Enter one exclusion per line. Start line with -  to exclude, or +  to include."
			[[ ! -f $excludes ]] && echo -e "# $comment" > "$excludes"
			notice "$comment" notice true
			$(open -e "$excludes")
			anykey
			;;
		"c"|"C")
			getExcludeCount
			if [[ -f $excludes ]]; then
				rm "$excludes" && notice "Exclusions removed." notice || notice "Failed to remove exclusions file." error
			else
				notice "No exclusions to remove." error
				echo
			fi
			;;
		"e"|"E")
			((elevate=1-$elevate))
			notice "Elevation ${green}$([[ $elevate -eq 1 ]] && echo "ON" || echo "OFF")${default}" notice
			;;
		"q"|"Q"|"x"|"X")
			notice "Quitting." notice true
			cleanUp 0;;
		*)
			notice "Invalid selection." error
			;;
	esac
done
