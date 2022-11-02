#!/bin/bash
show_help () {
	echo "Expecting one of following reserved letters/words for $0 first parameter:"
	echo ""
	echo "n|new|new-session|c|create|create-session SessionName \"optional command line to run\""
	echo "a|at|att|attach|attach-session|o|open|open-session SessionName"
	echo "l|ls|list|list-sessions"
	echo "k|kill|kill-session|x|exit|exit-session SessionName"
	echo "?|h|help"
	echo ""
	echo "Any other first param will be interpreted as session name to create or attach to"
	echo "  and additional params interpreted as command line to run."
	echo "Run with no parameters to create or attach to the default session (0)."
}

lower_case () {
	printf "%s" $1 | tr [:upper:] [:lower:]
}

name_prompt () {
	name=$1
	shift 1

	if [ -n "$name" ]
	then
		echo "Name of session${1:+" to $1"}: $name"
	else
		echo ""
		echo "q or quit to quit this script"
		echo -n "Session name${1:+" to $1"}? [0] "
		read name
		case "$(lower_case $name)" in
			q|quit)
				exit 0
				;;
			'')
				name="0"
				;;
		esac
	fi
}

process_action () {
	action="$1"
	shift 1
	name="$1"
	shift 1
	run="$@"

	case "$(lower_case $action)" in
		n|new|new-session|c|create|create-session)
			name_prompt "$name" "create"
			tmux new-session -s ${name:-0} ${run:+"$run"}
			;;
		a|at|att|attach|attach-session|o|open|open-session)
			name_prompt "$name" "attach to"
			tmux attach-session -t ${name:-0}
			;;
		l|ls|list|list-sessions)
			tmux list-sessions
			;;
		k|kill|kill-session|x|exit|exit-session)
			name_prompt "$name" "kill"
			echo -n "Are you sure you want to kill session ${name:-0}? (y/n) [n] "
			read confirm
			case "$(lower_case $confirm)" in
				y|yes)
					tmux kill-session -t ${name:-0}
					echo "Session ${name:-0} killed."
					;;
				*)
					echo "Session ${name:-0} not killed. Script aborted."
					exit 0
					;;
			esac
			;;
		q|quit)
			exit 0
			;;
		'?'|h|help)
			show_help
			;;
		*)
			run="$name${run:+" $run"}"
			name="$action"
			name_prompt "$name" "create/attach to"
			tmux new-session -A -s ${name:-0} ${run:+"$run"}
			;;
	esac
	return $?
}

action=$1
shift 1

if [ -z "$action" ]
then
	show_help
	echo ""
	echo "q or quit to quit this script"
	echo -n "Action (n/a/l/k/?/q) [n]: "
	read action
fi

process_action "$action" $@

exit $?
