#!/bin/bash

# Variable initialization
notice=""

# sudo by default?
elevate=0

# Ignore lines matching this pattern in excludes file
ignore_pattern='^\s*$\|^\s*#' # blank lines and comments

# Lines matching this pattern in log file are errors
error_pattern='failed:\|rsync error:'

# Common temporary directory/file spec
# tempTemplate=${TMPDIR:-/tmp/}$(basename "$0") # system tmp folder
tempTemplate="$HOME/.$(basename "$0")" # a dot directory in home directory
[[ ! -d $tempTemplate ]] && $(mkdir $tempTemplate) # create if doesn't exist

# Define file variables
defineFiles () {
	# Get random id
	id="${tempDir: -12}"
	# Define the excludes and log files in temporary directory
	settings="$tempDir/settings"
	excludes="$tempDir/excludes"
	logfile="$tempDir/log"
}

# Set up/change settings directory
setTemp () {
	# Temporary directory
	tempDir=""
	if [[ ${#1} -eq 0 ]]; then
		[[ ${#prevId} -ne 12 ]] && tempDir=$(mktemp -d "$tempTemplate/XXXXXXXXXXXX") || tempDir="$tempTemplate/$prevId"
		defineFiles
	elif [[ -d "$tempTemplate/$1" ]]; then
		tempDir="$tempTemplate/$1"
		defineFiles
		if [[ -f $settings ]]; then
			readSettings
		fi
	else
		notice "Invalid backup ID or settings directory deleted." error true
	fi
}

# Update settings file if src/dest/elevate options change
updateSettings () {
	[[ -d $tempDir ]] && echo -e "$src\n$dest\n$elevate" > "$settings" || notice "Temporary directory not set up." error true
}

# Read settings file to variables (if resuming a transfer id)
readSettings () {
	allSettings=()
	while read setting; do
		allSettings+=( "$setting")
	done < $settings
	src=${allSettings[0]}
	dest=${allSettings[1]}
	elevate=${allSettings[2]}
}

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
	[[ -e $tempDir ]] && rm -rf "$tempDir"
	echo -e "$default"
	exit $1
}

# Clean up temporary directory on every unclean exit, 130 is error signal for <Ctrl>+<C>
# trap 'cleanUp 130' SIGHUP SIGINT SIGTERM

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

# Get source
getSrc () {
	fileExist=-1
	until [[ $fileExist -ge 0 ]]; do
		echo
		read -p "Source directory (copy FROM here): " input
		checkExist "$input" "src" $1
	done
	if [[ $fileExist -ge 1 ]]; then
		src=$input
		updateSettings
	fi
	input=""
}
# Get destination
getDest () {
	fileExist=-1
	until [[ $fileExist -ge 0 ]]; do
		echo
		read -p "Destination directory (copy INTO here): " input
		checkExist "$input" "dest" $1
	done
	if [[ $fileExist -ge 1 ]]; then
		dest=$input
		updateSettings
	fi
	input=""
}

# Get transfer ID (to resume)
getIdInput () {
	until [[ ${#id} -eq 12 ]]; do
		echo
		echo -e "If you are resuming a previous transfer,"
		read -p "please enter its ID now (<Return> to skip): " getId
		setTemp "$getId"
	done
}

# Prompt to remove settings directory before exit
removePrompt () {
	until [[ $removeTemp =~ "(c|C)" ]]; do
		echo
		notice "Leave the settings for this transfer if you want to resume or redo it later,\nor if you want to hang on to the transfer log file." notice true
		read -n 1 -p "Remove settings data? [y]es / [N]o / [c]ancel quit: " removeTemp
		echo
		case "$removeTemp" in
			"y"|"Y"|"yes"|"YES")
				notice "Cleaning up and quitting." notice true
				cleanUp $err_rsync
				;;
			""|"n"|"N"|"no"|"NO")
				notice "Quitting, leaving settings directory $green$tempDir$default" notice true
				notice "To resume/redo this transfer, use ID $green$id$default [${lcyan}backup -r ${purple}${id}${default}]" notice true
				exit $err_rsync
				;;
			"c"|"C")
				notice "Cancelling quit." notice
				break
				;;
			*)
				notice "Invalid selection." error true
		esac
	done
}

# Number of excludes in excludes file
getExcludeCount () {
	i=$(grep -cve "$ignore_pattern" "$excludes")
}

showHelp () {
	echo -e "Command-line syntax:\n$ ${lcyan}backup${default} [-h] [-r ${under}backupID${default}] [-e] [-g] [${under}SOURCE$default [${under}DESTINATION$default]]\n${lcyan}backup -h$default shows help on parameters"
	if [[ $1 == full ]]; then
		echo -e " -h: show this help"
		echo -e " -r ${under}backupID${default}: [OPTIONAL] resume from the specified backup ID"
		echo -e " -e: [OPTIONAL] toggle privilege elevation (sudo) ON"
		echo -e " -g: [OPTIONAL] start transfer immediately if transfer ID supplied and valid, or SOURCE and DESTINATION supplied and valid"
		echo -e " ${under}SOURCE${default}: [OPTIONAL] specifies where to copy data FROM"
		echo -e " ${under}DESTINATION${default}: [OPTIONAL] specifies where to copy data TO"
	fi
}

while getopts ":hr:eg" opt; do
	case $opt in
		"h")
			showHelp full
			exit 0
			;;
		"r")
			setTemp "$OPTARG"
			;;
		"e")
			elevate=1
			;;
		"g")
			autoStart=true
			;;
		:)
			notice "Option -$OPTARG requires an argument" error true
			;;
		\?)
			notice "Invalid option: -$OPTARG" error true
			;;
	esac
done
shift $((OPTIND-1))

# Banner
echo -e "\n${under}${lblue}Wilson's All-Purpose Backup Script v1.0$default"
showHelp
echo -e "\nYou can drag and drop items from Finder for Source and Destination."

if [[ ${#1} == 0 ]]; then
	[[ ${#id} -ne 12 ]] && getIdInput
else
	[[ ${#id} -ne 12 ]] && setTemp
fi

# Check source parameter
if [[ ${#1} -gt 0 || ${#src} -gt 0 ]]; then
       	[[ ${#1} -gt 0 ]] && src=$1
	checkExist "$src" "src" false
else
	fileExist=0
fi
# If no source parameter, or source parameter invalid, prompt interactively
[[ $fileExist -le 0 ]] && getSrc true
# If just <Return> pressed at interactive prompt, exit
[[ $fileExist -eq 0 ]] && cleanUp 1

# Check destination parameter
if [[ ${#2} -gt 0 || ${#dest} -gt 0 ]]; then
	[[ ${#2} -gt 0 ]] && dest=$2
	checkExist "$dest" "dest" false
else
	fileExist=0
fi
# If no destination paramter, or destination parameter invalid, prompt interactively
[[ $fileExist -le 0 ]] && getDest true
# If just <Return> pressed at interactive prompt, exit
[[ $fileExist -eq 0 ]] && cleanUp 1

# Main Menu loop
until [[ $selection =~ "(q|Q|x|X)" ]]; do
	# If excludes file exists then get excludes count, else excludes count is 0
	[[ -f $excludes ]] && getExcludeCount || i=0
	if [[ -f $logfile && -s $logfile ]]; then
		isLog=true
		failed_lines=$(grep -wci "$error_pattern" "$logfile")
	fi

	cmd_rsync="$([[ $elevate -eq 1 ]] && echo "sudo ")rsync --archive --append --progress --human-readable --log-file=${logfile// /\\ } $([[ $i -gt 0 ]] && echo "--exclude-from=${excludes// /\\ } ")${src// /\\ } ${dest// /\\ }"

	echo -e "\nCommand: ${purple}${cmd_rsync}${default}\n"
	echo -e "Copy this ID to File Transfers sticky in case you need to resume it later:\n${lcyan}backup -r ${purple}${id}${default}\n"
		
	if [[ $autoStart != true ]]; then
		echo -e "${inverse}MENU:${default} Type ${under}${lcyan}blue letter${default} and hit ${lcyan}<Return>${default}, or just hit ${lcyan}<Return>${default} to start transfer\n"
		echo -e "${under}${lcyan}G${default}O (or just hit ${lcyan}<Return>${default})\n"
		echo -e "${under}${lcyan}R${default}esume previous transfer [${green}${id}${default}]"
		echo -e "${under}${lcyan}S${default}ource      [$green$src$default]"
		echo -e "${under}${lcyan}D${default}estination [$green$dest$default]\n"
		echo -e "${under}${lcyan}L${default}ist Exclusions [$green$i$default]"
		echo -e "${under}${lcyan}A${default}dd Exclusions"
		echo -e "${under}${lcyan}O${default}pen Exclusions file directly"
		echo -e "${under}${lcyan}C${default}lear All Exclusions\n"
		echo -e "${under}${lcyan}E${default}levate execution (sudo) [$green$([[ $elevate -eq 1 ]] && echo "ON" || echo "OFF")$default]\n"
		if [[ $isLog == true ]]; then
			logsize=$(stat -f '%z' "$logfile")
			echo -e "${under}${lcyan}V${default}iew Log file [${green}${logsize:-0} bytes${default}]"
			if [[ $failed_lines -gt 0 ]]; then
				echo -e "${under}${lcyan}!${default} View Errors [${red}${failed_lines:-0}${default}]"
			fi
			echo
		fi
		echo -e "${under}${lcyan}Q${default}uit"
	fi
		
	if [[ ${#notice} -gt 0 ]]; then
		echo -e "\n $notice"
		notice=""
	else
		echo
	fi

	if [[ $autoStart == true ]]; then
		selection="g"
		autoStart=false
	else
		read -n 1 -p "Enter option (<Return> to start): " selection
	fi
	echo
	
	case $selection in
		""|"g"|"G")
			notice "Running: $green$cmd_rsync$default\n" notice true
			eval $cmd_rsync
			err_rsync=$?
			failed_lines=$(grep -wci "$error_pattern" "$logfile")
			# failed_lines=$?
			echo
			if [[ $failed_lines -eq 0 ]]; then
				notice "Backup completed with no errors." notice
			else
				notice "Backup completed with $failed_lines errors." error
			fi
			;;
		"r"|"R")
			prevId="$id"
			id=""
			getIdInput	
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
			updateSettings
			;;
		"v"|"V")
			notice "Opening log file..." notice true
			$(open -e "$logfile")
			anykey
			;;
		"!")
			if [[ $failed_lines -gt 0 ]]; then
				notice "Showing errors in log file..." notice true
				$(grep -wi "$error_pattern" "$logfile" | open -fe)
				anykey
			else
				notice "Invalid selection." error
			fi
			;;
		"q"|"Q"|"x"|"X")
			removePrompt
			# notice "Quitting." notice true
			# cleanUp 0
			;;
		*)
			notice "Invalid selection." error
			;;
	esac
done
