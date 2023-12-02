#!/usr/bin/env bash
# chatgpt.sh -- Shell Wrapper for ChatGPT/DALL-E/Whisper
# v0.19.4  oct/2023  by mountaineerbr  GPL+3
if [[ -n $ZSH_VERSION  ]]
then 	set -o emacs; setopt NO_SH_GLOB KSH_GLOB KSH_ARRAYS SH_WORD_SPLIT GLOB_SUBST PROMPT_PERCENT NO_NOMATCH NO_POSIX_BUILTINS NO_SINGLE_LINE_ZLE PIPE_FAIL MONITOR NO_NOTIFY
else 	set -o pipefail; shopt -s extglob checkwinsize cmdhist lithist
fi

# OpenAI API key
OPENAI_API_KEY="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"

# DEFAULTS
# Text cmpls model
#"gpt-3.5-turbo-instruct"
MOD="gpt-4"
# Chat cmpls model
#"gpt-3.5-turbo"
MOD_CHAT="gpt-4"
# Edits model  (deprecated)
MOD_EDIT="text-davinci-edit-001"
# Audio model
MOD_AUDIO="whisper-1"
# Prompter flush with <CTRL-D> (multiline bash)
#OPTCTRD=
# Stream response
#STREAM=
# Temperature
#OPTT=
# Top_p probability mass (nucleus sampling)
#OPTP=1
# Maximum response tokens
OPTMAX=512
# Model capacity (auto)
#MODMAX=
# Presence penalty
#OPTA=
# Frequency penalty
#OPTAA=
# N responses of Best_of
#OPTB=
# Number of responses
OPTN=1
# Image size
OPTS=512x512
# Image format
OPTI_FMT=b64_json  #url
# Recorder command (with -ccw and -Ww), e.g. sox
#REC_CMD=""
# Set python tiktoken to count tokens
#OPTTIK=
# Inject restart text
#RESTART=""
# Inject   start text
#START=""
# Chat mode of text cmpls sets "\nQ: " and "\nA:"
# Restart/Start seqs have priority

# INSTRUCTION
# Chat completions, chat mode only
# INSTRUCTION=""
INSTRUCTION_CHAT="The following is a conversation with an AI assistant. The assistant is helpful, creative, clever, and very friendly."

# Awesome-chatgpt-prompts URL
AWEURL="https://raw.githubusercontent.com/f/awesome-chatgpt-prompts/main/prompts.csv"
AWEURLZH="https://raw.githubusercontent.com/PlexPt/awesome-chatgpt-prompts-zh/main/prompts-zh.json"  #prompts-zh-TW.json

# API URL / endpoint
APIURLBASE="${APIURLBASE:-https://api.openai.com/v1}"
APIURL="${APIURL:-$APIURLBASE}"

# CACHE AND OUTPUT DIRECTORIES
CACHEDIR="${XDG_CACHE_HOME:-$HOME/.cache}/chatgptsh"
OUTDIR="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"

# Colour palette
# Normal Colours   # Bold              # Background
Black='\e[0;30m'   BBlack='\e[1;30m'   On_Black='\e[40m'  \
Red='\e[0;31m'     BRed='\e[1;31m'     On_Red='\e[41m'    \
Green='\e[0;32m'   BGreen='\e[1;32m'   On_Green='\e[42m'  \
Yellow='\e[0;33m'  BYellow='\e[1;33m'  On_Yellow='\e[43m' \
Blue='\e[0;34m'    BBlue='\e[1;34m'    On_Blue='\e[44m'   \
Purple='\e[0;35m'  BPurple='\e[1;35m'  On_Purple='\e[45m' \
Cyan='\e[0;36m'    BCyan='\e[1;36m'    On_Cyan='\e[46m'   \
White='\e[0;37m'   BWhite='\e[1;37m'   On_White='\e[47m'  \
Inv='\e[0;7m'      Nc='\e[m'           Alert=$BWhite$On_Red

# Load user defaults
CONFFILE="${CHATGPTRC:-$HOME/.chatgpt.conf}"
[[ -f "${OPTF}${CONFFILE}" ]] && . "$CONFFILE"

# Set file paths
FILE="${CACHEDIR%/}/chatgpt.json"
FILECHAT="${FILECHAT:-${CACHEDIR%/}/chatgpt.tsv}"
FILETXT="${CACHEDIR%/}/chatgpt.txt"
FILEOUT="${OUTDIR%/}/dalle_out.png"
FILEIN="${CACHEDIR%/}/dalle_in.png"
FILEINW="${CACHEDIR%/}/whisper_in.mp3"
FILEAWE="${CACHEDIR%/}/awesome-prompts.csv"
FILEFIFO="${CACHEDIR%/}/fifo.buff"
USRLOG="${OUTDIR%/}/${FILETXT##*/}"
HISTFILE="${CACHEDIR%/}/history_${BASH_VERSION:+bash}${ZSH_VERSION:+zsh}"
HISTCONTROL=erasedups:ignoredups
HISTSIZE=512 SAVEHIST=512 HISTTIMEFORMAT='%F %T '

# Def hist, txt chat types
Q_TYPE="\\nQ: "
A_TYPE="\\nA:"
I_TYPE='[insert]'

# Globs
SPC="*([$IFS])"
SPC1="*(\\\\[ntrvf]|[$IFS])"
NL=$'\n'

HELP="Name
	${0##*/} -- Wrapper for ChatGPT / DALL-E / Whisper


Synopsis
	${0##*/} [-c|-d] [opt] [PROMPT|TEXT_FILE]
	${0##*/} -e [opt] [INSTRUCTION] [INPUT|TEXT_FILE]
	${0##*/} -i [opt] [S|M|L] [PROMPT]
	${0##*/} -i [opt] [S|M|L] [PNG_FILE]
	${0##*/} -i [opt] [S|M|L] [PNG_FILE] [MASK_FILE] [PROMPT]
	${0##*/} -TTT [-v] [-m[MODEL|ENCODING]] [INPUT|TEXT_FILE]
	${0##*/} -w [opt] [AUDIO_FILE] [LANG] [PROMPT]
	${0##*/} -W [opt] [AUDIO_FILE] [PROMPT-EN]
	${0##*/} -ccw [opt] [LANG]
	${0##*/} -ccW [opt]
	${0##*/} -HHH [/HIST_FILE]
	${0##*/} -l [MODEL]


Description
	With no options set, complete INPUT in single-turn mode of
	plain text completions.

	Option -d starts a multi-turn session in plain text completions,
	and does not set further options automatically.

	Set option -c to start multi-turn chat mode via text completions
	(davinci and lesser models) or -cc for native chat completions
	(gpt-3.5+ models). In chat mode, some options are automatically
	set to un-lobotomise the bot. Set -E to exit on response.

	Option -C resumes (continues from) last history session.

	Positional arguments are read as a single PROMPT. Optionally set
	INTRUCTION with option -S.

	When INSTRUCTION is mandatory (such as for edits models), the
	first positional argument is taken as INSTRUCTION, if none set,
	and the following ones as INPUT or PROMPT.

	If the first positional argument of the script starts with the
	command operator, the command \`/session [HIST_NAME]' to change
	to or create a new history file is assumed (with options -ccCdHH).

	Option -i generates or edits images. Option -w transcribes audio
	and option -W translates audio to English.

	Option -y sets python tiktoken instead of the default script hack
	to preview token count. Set this option for accurate history
	context length (fast).

	As of v0.18, sequences \`\\n' and \`\\t' are only treated specially
	in restart, start and stop sequences!

	A personal (free) OpenAI API is required, set environment or
	option -K.


See Also
	Check the man page for extended description of interface and
	settings. See the online man page and script usage examples at:

	<https://github.com/mountaineerbr/shellChatGPT>.


Environment
	CHATGPTRC
	CONFFILE 	Path to user chatgpt.sh configuration.
			Defaults=\"${CHATGPTRC:-${CONFFILE:-~/.chatgpt.conf}}\"

	FILECHAT 	Path to a history / session TSV file.

	INSTRUCTION 	Initial instruction, or system message.

	INSTRUCTION_CHAT
			Initial instruction, or system message (chat mode).

	OPENAI_API_KEY
	OPENAI_KEY 	Set your personal (free) OpenAI API key.

	REC_CMD 	Audio recording command (with -ccw and -Ww),
			e.g. sox.

	VISUAL
	EDITOR 		Text editor for external prompt editing.
			Defaults=\"${VISUAL:-${EDITOR:-vim}}\"


Chat Commands
	While in chat mode, the following commands can be typed in the
	new prompt to set a new parameter. The command operator may be
	either \`!', or \`/'.

    ------    ----------    ---------------------------------------
    --- Misc Commands ---------------------------------------------
       -z      !last            Print last response json.
       !i      !info            Info on model and session settings.
       !j      !jump            Jump to request, append response primer.
      !!j     !!jump            Jump to request, no response priming.
      !sh      !shell [CMD]     Run command, grab and edit output.
     !!sh     !!shell           Open an interactive shell and exit.
    --- Script Settings -------------------------------------------
       -g      !stream          Toggle response streaming.
       -l      !models          List language model names.
       -o      !clip            Copy responses to clipboard.
       -u      !multi           Toggle multiline, ctrl-d flush (bash).
       -U      !cat             Toggle cat prompter, ctrl-d flush.
       -V      !context         Print context before request (see -HH).
       -VV     !debug           Dump raw request block and confirm.
       -v      !ver             Toggle verbose modes.
       -x      !ed              Toggle text editor interface.
       -xx    !!ed              Single-shot text editor.
       -y      !tik             Toggle python tiktoken use.
       !q      !quit            Exit. Bye.
       !r      !regen           Regenerate last response.
       !?      !help            Print this help snippet.
    --- Model Settings --------------------------------------------
     !NUM      !max      [NUM]  Set max response tokens.
       -N      !modmax   [NUM]  Set model token capacity.
       -a      !pre      [VAL]  Set presence penalty.
       -A      !freq     [VAL]  Set frequency penalty.
       -b      !best     [NUM]  Set best-of n results.
       -m      !mod      [MOD]  Set model by name.
       -n      !results  [NUM]  Set number of results.
       -p      !top      [VAL]  Set top_p.
       -r      !restart  [SEQ]  Set restart sequence.
       -R      !start    [SEQ]  Set start sequence.
       -s      !stop     [SEQ]  Set one stop sequence.
       -t      !temp     [VAL]  Set temperature.
       -w      !rec             Start audio record chat mode.
    --- Session Management ----------------------------------------
        -      !list            List history files (tsv).
        -      !sub      [REGEX]
	                        Search sessions and copy to tail.
       -c      !new             Start new session (session break).
       -H      !hist            Edit raw history file in editor.
      -HH      !req             Print context request now (see -V).
       -L      !log      [FILEPATH]
                                Save to log file (pretty-print).
       !c      !copy     [SRC_HIST] [DEST_HIST]
                                Copy session from source to destination.
       !f      !fork     [DEST_HIST]
                                Fork current session to destination.
       !k      !kill            Comment out last entry in history file.
       !s      !session  [HIST_FILE]
                                Change to, search for, or create hist file.
      !!s     !!session  [HIST_FILE]
                                Same as !session, break session.
    ------    ----------    ---------------------------------------

	E.g.: \`/temp 0.7', \`!modgpt-4', \`-p 0.2', and \`/s hist_name'.

	Change chat context at run time with the \`!hist' command to edit
	the raw history file (delete or comment out entries).

	To preview a prompt completion, append a forward slash \`/' to it.
	Regenerate it again or flush / accept the prompt and response.

	After a response has been written to the history file, regenerate
	it with command \`!regen' or type in a single forward slash in
	the new empty prompt.

	Type in a backslash \`\\' as the last character of the input line
	to append a literal newline, or press <CTRL-V> + <CTRL-J>, or
	<ALT-ENTER> (Zsh).


Options
	Model Settings
	-@ [[VAL%]COLOUR], --alpha=[[VAL%]COLOUR]
		Set transparent colour of image mask. Def=black.
		Fuzz intensity can be set with [VAL%]. Def=0%.
	-NUM
	-M [NUM[/NUM]], --max=[NUM[-NUM]]
		Set maximum number of \`response tokens'. Def=$OPTMAX.
		A second number in the argument sets model capacity.
	-N [NUM], --modmax=[NUM]
		Set \`model capacity' tokens. Def=_auto_, fallback=2048.
	-a [VAL], --presence-penalty=[VAL]
		Set presence penalty  (cmpls/chat, -2.0 - 2.0).
	-A [VAL], --frequency-penalty=[VAL]
		Set frequency penalty (cmpls/chat, -2.0 - 2.0).
	-b [NUM], --best-of=[NUM]
		Set best of, must be greater than opt -n (cmpls). Def=1.
	-B [NUM], --logprobs=[NUM]
		Request log probabilities, see -z (cmpls, 0 - 5),
	-m [MOD], --model=[MOD]
		Set language MODEL name.
	-n [NUM], --results=[NUM]
		Set number of results. Def=$OPTN.
	-p [VAL], --top-p=[VAL]
		Set Top_p value, nucleus sampling (cmpls/chat, 0.0 - 1.0).
	-r [SEQ], --restart=[SEQ]
		Set restart sequence string (cmpls).
	-R [SEQ], --start=[SEQ]
		Set start sequence string (cmpls).
	-s [SEQ], --stop=[SEQ]
		Set stop sequences, up to 4. Def=\"<|endoftext|>\".
	-S [INSTRUCTION|FILE], --instruction
		Set an instruction prompt. It may be a text file.
	-t [VAL], --temperature=[VAL]
		Set temperature value (cmpls/chat/edits/audio),
		(0.0 - 2.0, whisper 0.0 - 1.0). Def=${OPTT:-0}.

	Script Modes
	-c, --chat
		Chat mode in text completions, session break.
	-cc 	Chat mode in chat completions, session break.
	-C, --continue, --resume
		Continue from (resume) last session (cmpls/chat).
	-d, --text
		Start new multi-turn session in plain text completions.
	-e [INSTRUCTION] [INPUT], --edit
		Set Edit mode. Model def=${MOD_EDIT}.
	-E, --exit
		Exit on first run (even with -cc).
	-g, --stream
		Set response streaming.
	-G, --no-stream
		Unset response streaming.
	-i [PROMPT], --image
		Generate images given a prompt.
	-i [PNG]
		Create variations of a given image.
	-i [PNG] [MASK] [PROMPT]
		Edit image with mask, and prompt (required).
	-q, --insert  (deprecated)
		Insert text rather than completing only. Use \`[insert]'
		to indicate where the model should insert text (cmpls).
	-S .[PROMPT_NAME], -.[PROMPT_NAME]
	-S ,[PROMPT_NAME], -,[PROMPT_NAME]
		Load, search for, or create custom prompt.
		Set \`..[prompt]' to silently load prompt.
		Set \`.?' to list prompt template files.
		Set \`,[prompt]' to edit the prompt file.
	-S /[AWESOME_PROMPT_NAME]
	-S %[AWESOME_PROMPT_NAME_ZH]
		Set or search an awesome-chatgpt-prompt(-zh).
		Set \`//' or \`%%' to refresh cache. Davinci+ models.
	-T, --tiktoken
	-TT
	-TTT 	Count input tokens with tiktoken, it heeds options -ccm.
		Set twice to print tokens, thrice to available encodings.
		Set model or encoding with option -m.
	-w [AUD] [LANG] [PROMPT], --transcribe
		Transcribe audio file into text. LANG is optional.
		A prompt that matches the audio language is optional.
		Set twice to get phrase-level timestamps.
	-W [AUD] [PROMPT-EN], --translate
		Translate audio file into English text.
		Set twice to get phrase-level timestamps.

	Script Settings
	-f, --no-conf
		Ignore user configuration file and environment.
	-F 	Edit configuration file, if it exists.
	-FF 	Dump template configuration file to stdout.
	-h, --help
		Print this help page.
	-H   [/HIST_FILE], --hist
		Edit history file with text editor or pipe to stdout.
		A hist file name can be optionally set as argument.
	-HH  [/HIST_FILE]
	-HHH [/HIST_FILE]
		Pretty print last history session to stdout.
		Heeds -ccdrR to print the specified (re-)start seqs.
		Set thrice to print commented out hist entries, too.
	-k, --no-colour
		Disable colour output. Def=auto.
	-K [KEY], --api-key
		Set OpenAI API key.
	-l [MOD], --list-models
		List models or print details of MODEL.
	-L [FILEPATH], --log=[FILEPATH]
		Set log file. FILEPATH is required.
	-o, --clipboard
		Copy response to clipboard.
	-u, --multi
		Toggle multiline prompter, <CTRL-D> flush (Bash).
	-U, --cat
		Set cat prompter, <CTRL-D> flush.
	-v, --verbose
		Less verbose. Sleep after response in voice chat (-vvccw).
		May be set multiple times.
	-V 	Pretty-print context before request.
	-VV 	Dump raw request block to stderr (debug).
	-x, --editor
		Edit prompt in text editor.
	-y, --tik
		Set tiktoken for token count (cmpls, chat).
	-Y, --no-tik
		Unset tiktoken use (cmpls, chat).
	-z, --last
		Print last response JSON data.
	-Z 	Run with interactive Z-shell."

ENDPOINTS=(
	completions               #0
	moderations               #1
	edits                     #2   2024-01-04 -> chat/completions
	images/generations        #3
	images/variations         #4
	embeddings                #5
	chat/completions          #6
	audio/transcriptions      #7
	audio/translations        #8
	images/edits              #9
	#fine-tunes               #10
)
#https://platform.openai.com/docs/{deprecations/,models/,model-index-for-researchers/}
#https://help.openai.com/en/articles/{6779149,6643408}

#set model endpoint based on its name
function set_model_epnf
{
	unset OPTE OPTEMBED TKN_ADJ
	case "$1" in
		*whisper*) 		((OPTWW)) && EPN=8 || EPN=7;;
		code-*) 	case "$1" in
					*search*) 	EPN=5 OPTEMBED=1;;
					*edit*) 	EPN=2 OPTE=1;;
					*) 		EPN=0;;
				esac;;
		text-*|*turbo-instruct*|*moderation*) 	case "$1" in
					*embedding*|*similarity*|*search*) 	EPN=5 OPTEMBED=1;;
					*edit*) 	EPN=2 OPTE=1;;
					*moderation*) 	EPN=1 OPTEMBED=1;;
					*) 		EPN=0;;
				esac;;
		gpt-4*|gpt-3.5*|gpt-*|*turbo*) 		EPN=6 OPTB= OPTBB=
				((OPTC)) && OPTC=2
				#set token adjustment per message
				case "$MOD" in
					gpt-3.5-turbo-0301) 	((TKN_ADJ=4+1));;
					gpt-3.5-turbo*|gpt-4*|*) 	((TKN_ADJ=3+1));;
				esac #https://github.com/openai/openai-cookbook/blob/main/examples/How_to_count_tokens_with_tiktoken.ipynb
				#also: <https://tiktokenizer.vercel.app/>
				;;
		*) 		#fallback
				case "$1" in
					*-edit*) 	EPN=2 OPTE=1;;
					*-embedding*|*-similarity*|*-search*) 	EPN=5 OPTEMBED=1;;
					*) 	EPN=0;;  #defaults
				esac;;
	esac
}

#make cmpls request
function __promptf
{
	curl "$@" "$APIURL/${ENDPOINTS[EPN]}" \
		-X POST \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $OPENAI_API_KEY" \
		-d "$BLOCK" \
	&& { 	[[ \ $*\  = *\ -s\ * ]] || __clr_lineupf ;}
}

function _promptf
{
	typeset chunk str n
	json_minif

	if ((STREAM))
	then 	set -- -s "$@" -S -L --no-buffer
		__promptf "$@" | while IFS= read -r chunk
		do 	chunk=${chunk##*([$' \t'])[Dd][Aa][Tt][Aa]:*([$' \t'])}
			[[ $chunk = *([$IFS]) ]] && continue
			[[ $chunk = *([$IFS])\[+([A-Z])\] ]] && continue
			if ((!n))  #first pass
			then 	((OPTC==1)) && {  #del leading spaces
					str='text":"'
					chunk="${chunk/${str}+${SPC1##\*}/$str}"
					[[ $chunk = *"${str}"\",* ]] && continue
				}
				((++n)) ;: >"$FILE"
			fi
			tee -a "$FILE" <<<"$chunk"
		done
	else
		((OPTV>1)) && set -- -s "$@"
		set -- -\# "$@" -L -o "$FILE"
		__promptf "$@"
	fi
}

function promptf
{
	typeset pid sig

	if ((OPTVV)) && ((!OPTII))
	then 	block_printf || return
	fi

	if ((STREAM))
	then 	if ((RETRY>1))
		then 	cat -- "$FILE"
		else 	_promptf || exit
		fi | prompt_printf
	else
		((RETRY>1)) || _promptf || exit
		if ((OPTI))
		then 	prompt_imgprintf
		else 	prompt_printf
		fi
	fi & pid=$! sig="INT"  #catch <CTRL-C>
	[[ -z $ZSH_VERSION ]] || [[ $- != *m* ]] || __clr_lineupf 10

	trap "kill -- ${ZSH_VERSION:+-}$pid; trap '-' $sig; echo >&2; return 199;" $sig
	wait $pid; trap '-' $sig; echo >&2;

	if ((OPTCLIP)) || [[ ! -t 1 ]]
	then 	typeset out ;out=$(
			((STREAM)) && set -- -j
			prompt_pf -r "$@" "$FILE"
		)
		((!OPTCLIP)) || (${CLIP_CMD:-false} <<<"$out" &)  #clipboard
		[[ -t 1 ]] || printf '%s\n' "$out" >&2  #pipe + stderr
	fi
}

#clear n lines up as needed (assumes one `new line').
function __clr_lineupf
{
	typeset chars n
	chars="${1:-1}" ;((COLUMNS))||COLUMNS=80
	for ((n=0;n<((chars+(COLUMNS-1))/COLUMNS);++n))
	do 	printf '\e[A\e[K' >&2
	done
}
#https://www.zsh.org/mla/workers//1999/msg01550.html
#https://superchlorine.com/2013/08/kill-winch-to-fix-bash-prompt-wrapping-to-the-same-line/

# spin.bash -- provide a `spinning wheel' to show progress
#  Copyright 1997 Chester Ramey (adapted)
BS=$'\b' SPIN_CHARS=("|${BS}" "\\${BS}" "-${BS}" "/${BS}")
function __spinf
{
  printf -- "${SPIN_CHARS[SPIN_INDEX]}" >&2
  ((++SPIN_INDEX)); ((SPIN_INDEX%=4))
}
function __printbf { 	printf "%s${1//?/\\b}" "${1}" >&2; };

#trim leading spaces
#usage: trim_leadf [string] [glob]
function trim_leadf
{
	typeset var ind sub
	var="$1" ind=160
	sub="${var:0:$ind}"
	sub="${sub##$2}"
	var="${sub}${var:$ind}"
	printf '%s\n' "$var"
}
#trim trailing spaces
#usage: trim_trailf [string] [glob]
function trim_trailf
{
	typeset var ind sub
	var="$1" ind=160
	if ((${#var}>ind))
	then 	sub="${var:$((${#var}-${ind}))}"
		sub="${sub%%$2}"
		var="${var:0:$((${#var}-${ind}))}${sub}"
	else 	var="${var%%$2}"
	fi ;printf '%s\n' "$var"
}
#fast trim
#usage: trimf [string] [glob]
function trimf
{
	trim_leadf "$(trim_trailf "$1" "$2")" "$2"
}

#pretty print request body or dump and exit
function block_printf
{
	if ((OPTVV>1))
	then 	printf '%s\n%s\n' "${ENDPOINTS[EPN]}" "$BLOCK"
		printf '\n%s\n' '<CTRL-D> redo, <CTRL-C> exit, <ENTER> continue'
		[[ -n $ZSH_VERSION ]] && setopt LOCAL_OPTIONS NO_MONITOR
		(read </dev/tty) || return 200
	else 	((STREAM)) && set -- -j
		jq -r "$@" '.instruction//empty, .input//empty,
		.prompt//(.messages[]|.role+": "+.content)//empty' <<<"$BLOCK" | STREAM= foldf
		((!OPTC)) || printf ' '
	fi >&2
}

#prompt confirmation prompter
function new_prompt_confirmf
{
	typeset REPLY

	_sysmsgf 'Confirm?' '[Y]es, [n]o, [e]dit, te[x]t editor, [r]edo, or [a]bort ' ''
	REPLY=$(__read_charf) ;__clr_lineupf 64 #!#
	case "${REPLY}" in
		[AaQq]) 	return 201;;  #break
		[Rr]) 	return 200;;          #redo
		[Ee]) 	return 199;;          #edit
		[VvXx]) 	return 198;;  #text editor
		[Nn]|$'\e') 	unset REC_OUT ;return 1;;  #no
	esac  #yes
}

#read one char from user
function __read_charf
{
	typeset REPLY
	read -n ${ZSH_VERSION:+-k} 1 "$@" </dev/tty
	printf '%.1s\n' "$REPLY"
	[[ -z ${REPLY//[$IFS]} ]] || echo >&2
}

#print response
function prompt_printf
{
	typeset stream

	if ((STREAM))
	then 	typeset OPTC OPTV ;stream=1
	else 	set -- "$FILE"
		((OPTBB)) && jq -r '.choices[].logprobs//empty' "$@" >&2
	fi
	if ((OPTEMBED))
	then 	jq -r '(.data),
		(.model//"'"$MOD"'"//"?")+" ("+(.object//"?")+") ["
		+(.usage.prompt_tokens//"?"|tostring)+" + "
		+(.usage.completion_tokens//"?"|tostring)+" = "
		+(.usage.total_tokens//"?"|tostring)+" tkns]"' "$@" >&2
		return
	fi

	jq -r ${stream:+-j --unbuffered} --arg suffix "$(unescapef "$SUFFIX")" \
	  "${JQCOLNULL} ${JQCOL} ${JQCOL2}
	  (.choices[1].index as \$sep | .choices[] |
	  byellow + ( (.text//(.message.content)//(.delta.content) ) |
	  if (${OPTC:-0}>0) then (gsub(\"^[\\\\n\\\\t ]\"; \"\") |  gsub(\"[\\\\n\\\\t ]+$\"; \"\")) else . end)
	  + \$suffix + reset
	  + if .finish_reason != \"stop\" then (if .finish_reason != null then red+\"(\"+.finish_reason+\")\"+reset else null end) else null end,
	  if \$sep then \"---\" else empty end)" "$@" | foldf ||

	prompt_pf -r ${stream:+-j --unbuffered} "$@" 2>/dev/null
}
function prompt_pf
{
	typeset opts
	if [[ -f ${@:${#}} ]]
	then 	((${#} >1)) && opts=("${@:1:$((${#} -1))}") && set -- "${@:${#}}"
	else 	opts=("$@") ;set --
	fi
	jq ${opts[@]} "(.choices//empty|.[$INDEX]|.text//(.message.content)//(.delta.content)//empty)//.data//empty" "$@" || cat -- "${@:${#}}"
}
#https://stackoverflow.com/questions/57298373/print-colored-raw-output-with-jq-on-terminal
#https://stackoverflow.com/questions/40321035/  #gsub(\"^[\\n\\t]\"; \"\")

#make request to image endpoint
function prompt_imgvarf
{
	curl -\# ${OPTV:+-s} -L "$APIURL/${ENDPOINTS[EPN]}" \
		-H "Authorization: Bearer $OPENAI_API_KEY" \
		-F image="@$1" \
		-F response_format="$OPTI_FMT" \
		-F n="$OPTN" \
		-F size="$OPTS" \
		"${@:2}" \
		-o "$FILE"
}

#open file with sys defaults
function __openf
{
	if command -v xdg-open >/dev/null 2>&1
	then 	xdg-open "$1"
	elif command -v open >/dev/null 2>&1
	then 	open "$1"
	else 	false
	fi
}
#https://budts.be/weblog/2011/07/xdf-open-vs-exo-open/

#print image endpoint response
function prompt_imgprintf
{
	typeset n m fname fout
	if [[ $OPTI_FMT = b64_json ]]
	then 	[[ -d "${FILEOUT%/*}" ]] || FILEOUT="${FILEIN}"
		n=0 m=0
		for fname in "${FILEOUT%.png}"*
		do 	fname="${fname%.png}" fname="${fname##*[!0-9]}"
			((m>fname)) || ((m=fname+1))
		done
		while jq -e ".data[${n}]" "$FILE" >/dev/null 2>&1
		do 	fout="${FILEOUT%.*}${m}.png"
			jq -r ".data[${n}].b64_json" "$FILE" | { 	base64 -d || base64 -D ;} > "$fout"
			printf 'File: %s\n' "${fout/"$HOME"/"~"}" >&2
			((OPTV)) ||  __openf "$fout" || function __openf { : ;}
			((++n, ++m)) ;((n<50)) || break
		done
		((n)) || { 	cat -- "$FILE" ;false ;}
	else 	jq -r '.data[].url' "$FILE" || cat -- "$FILE"
	fi
}

function prompt_audiof
{
	((OPTVV)) && echo "model: ${MOD},  temp: ${OPTT}${*:+,  }${*}" >&2

	curl -\# ${OPTV:+-s} -L "$APIURL/${ENDPOINTS[EPN]}" \
		-X POST \
		-H "Authorization: Bearer $OPENAI_API_KEY" \
		-H 'Content-Type: multipart/form-data' \
		-F file="@$1" \
		-F model="$MOD" \
		-F temperature="$OPTT" \
		-o "$FILE" \
		"${@:2}" \
	&& { 	[[ \ ${OPTV:+-s}\  = *\ -s\ * ]] || __clr_lineupf; ((MTURN)) || echo >&2 ;}
}

function list_modelsf
{
	curl "$APIURL/models${1:+/}${1}" \
		-H "Authorization: Bearer $OPENAI_API_KEY" \
		-o "$FILE"

	if [[ -n $1 ]]
	then  	jq . "$FILE" || cat -- "$FILE"
	else 	jq -r '.data[].id' "$FILE" | sort
	fi && printf '%s\n' moderation  #text-moderation-latest text-moderation-stable
}

function lastjsonf
{
	if [[ -s $FILE ]]
	then 	jq "$@" . "$FILE" || cat "$@" -- "$FILE"
	fi
}

#set up context from history file ($HIST and $HIST_C)
function set_histf
{
	typeset time token string max_prev q_type a_type role role_old rest a_append sub ind herr m n
	[[ -s $FILECHAT ]] || return; unset HIST HIST_C;
	((OPTTIK)) && HERR_DEF=1 || HERR_DEF=4
	((herr = HERR_DEF + HERR))  #context limit error
	q_type=${Q_TYPE##$SPC1} a_type=${A_TYPE##$SPC1}
	((OPTC>1 || EPN==6)) && a_append=" "
	((${#})) && token_prevf "${*}"

	while __spinf
		IFS=$'\t' read -r time token string
	do
		[[ ${OPTHH##?}${time}${token} = *([$IFS])\#* ]] && continue
		[[ ${time}${token} = *[Bb][Rr][Ee][Aa][Kk]* ]] && { 	((OPTZZHIST)) && continue; break ;}
		[[ -z ${time}${token}${string} ]] && continue
		if [[ -z $string ]]
		then 	[[ -n $token ]] && string=$token token=$time time=
			[[ -n $time  ]] && string=$time  token=  time=
		fi

		string="${string##[\"]}" string="${string%%[\"]}"
		#improve bash globbing speed with substring manipulation
		sub="${string:0:30}" sub="${sub##@("${q_type}"|"${a_type}"|":")}"
		stringc="${sub}${string:30}"  #del lead seqs `\nQ: ' and `\nA:'

		if ((OPTTIK || token<1)) && ((!OPTZZHIST))
		then 	((token<1 && OPTVV>1)) && __warmsgf "Warning:" "Zero/Neg token in history"
			start_tiktokenf
			if ((EPN==6))
			then 	token=$(__tiktokenf "${stringc##:}")
			else 	token=$(__tiktokenf "\\n${string##:}")
			fi; ((token+=TKN_ADJ))
		fi # every message follows <|start|>{role/name}\n{content}<|end|>\n (gpt-3.5-turbo-0301)
		#trail nls are rm in (text) chat modes, so actual request prompt token count may be *less*
		#we currently ignore (re)start seq tkns, always consider +3 tkns from $[QA]_TYPE

		if (( ( ( (max_prev+token+TKN_PREV)*(100+herr) )/100 ) < MODMAX-OPTMAX))
		then
			((max_prev+=token)); ((MAIN_LOOP)) || ((TOTAL_OLD+=token))
			MAX_PREV=$((max_prev+TKN_PREV))  HIST_TIME="${time}"

			#:|| #debug
			if ((OPTC))
			then 	stringc=$(trim_leadf  "$stringc" "*(\\\\[ntrvf]| )")
				stringc=$(trim_trailf "$stringc" "*(\\\\[ntrvf])")
			fi

			role_old=$role role= rest=
			case "${string}" in
				:*) 	role=system
					rest=
					;;
				"${a_type:-%#}"*|"${START:-%#}"*)
					role=assistant
					if ((OPTC)) || [[ -n "${START}" ]]
					then 	rest="${START:-${A_TYPE}${a_append}}"
					fi
					;;
				*) #q_type, RESTART
					role=user
					if ((OPTC)) || [[ -n "${RESTART}" ]]
					then 	rest="${RESTART:-$Q_TYPE}"
					fi
					;;
			esac

			if ((OPTZZHIST))  #option -ZZ: entries for building shell cmd history
			then 	[[ $role = assistant ]] && { 	((max_prev-=token)) ;continue ;}
				[[ $'\n'"${HIST}"$'\n' = *$'\n'"${stringc}"$'\n'* ]] && continue
				rest=$'\n' ;((++n)) ;((n<=${N_MAX:-20})) || max_prev=$MODMAX
			fi

			HIST="${rest}${stringc}${HIST}"
			((EPN==6)) && HIST_C="$(fmt_ccf "${stringc}" "${role}")${HIST_C:+,}${HIST_C}"
		else 	break
		fi
	done < <(tac -- "$FILECHAT")
	__printbf ' ' #__spinf() end
	((MAX_PREV+=3)) # chat cmpls, every reply is primed with <|start|>assistant<|message|>
	# in text chat cmpls, prompt is primed with A_TYPE = 3 tkns

	if [[ "$role" = system ]]  #first system/instruction: add newlines (txt cmpls)
	then 	[[ ${role_old:=user} = @(user|assistant) ]] || unset role_old
		HIST="${stringc}${role_old:+\\n}\\n${HIST##"$stringc"?(\\n)}"
	fi

	#:|| #debug
	((!OPTC)) || [[ $HIST = "$stringc"*(\\n) ]] ||  #hist contains only one/system prompt?
	HIST=$(trim_trailf "$HIST" "*(\\\\[ntrvf])")  #del multiple trailing nl
	HIST=$(trim_leadf "$HIST" "?(\\\\[ntrvf]|$NL)?( )")  #del one leading nl+sp
}
#https://thoughtblogger.com/continuing-a-conversation-with-a-chatbot-using-gpt/

#print to history file
#usage: push_tohistf [string] [tokens] [time]
function push_tohistf
{
	typeset string token time
	string=$1; ((${#string})) || return; unset CKSUM_OLD
	token=$2; ((token>0)) || {
		start_tiktokenf;    __printbf '(tiktoken)';
		token=$(__tiktokenf "${string}");
		((token+=TKN_ADJ)); __printbf '          '; };
	time=${3:-$(date -Iseconds 2>/dev/null||date +"%Y-%m-%dT%H:%M:%S%z")}
	printf '%.22s\t%d\t"%s"\n' "$time" "$token" "$string" >> "$FILECHAT"
}

#record preview query input and response to hist file
#usage: prev_tohistf [input]
function prev_tohistf
{
	typeset input answer
	input="$*"
	if ((STREAM))
	then 	answer=$(escapef "$(prompt_pf -r -j "$FILE")")
	else 	answer=$(prompt_pf "$FILE")
		answer="${answer##[\"]}" answer="${answer%%[\"]}"
	fi
	push_tohistf "$input" '' '#1970-01-01'  #(dummy dates)
	push_tohistf "$answer" '' '#1970-01-01'  #(as comments)
}

#calculate token preview
#usage: token_prevf [string]
function token_prevf
{
	__printbf '(tiktoken)'
	start_tiktokenf
	TKN_PREV=$(__tiktokenf "${*}")
	((TKN_PREV+=TKN_ADJ))
	__printbf '          '
}

#send to tiktoken coproc
function send_tiktokenf
{
	kill -0 $COPROC_PID 2>/dev/null || return
	typeset q; [[ -n $ZSH_VERSION ]] && q='\\n' || q='\n'
	printf '%s\n' "${1//$NL/$q}" >&"${COPROC[1]}"
}

#get from tiktoken coproc
function get_tiktokenf
{
	typeset REPLY m
	kill -0 $COPROC_PID 2>/dev/null || return
	while IFS= read -r
		((!${#REPLY}))
	do 	((++m)); ((m>800)) && break
	done <&"${COPROC[0]}"
	if ((!${#REPLY}))
	then  	! __warmsgf 'Err:' 'get_tiktokenf()'
	else 	printf '%s\n' "$REPLY"
	fi
}

#start tiktoken coproc (*must be started from main shell*)
function start_tiktokenf
{
	if ((OPTTIK)) && ! kill -0 $COPROC_PID 2>/dev/null
	then 	unset COPROC COPROC_PID; [[ $- != *m* ]] || echo >&2
		coproc { 	PYTHONUNBUFFERED=1 HOPTTIK=1 tiktokenf ;}
		((COPROC_PID)) || COPROC_PID=$!
		if [[ -n $ZSH_VERSION ]]
		then 	COPROC=(p p)  #set file descriptor names
			#clear interactive zsh job control notification
			[[ $- != *m* ]] || __clr_lineupf 10
		fi
	fi
}

#defaults tiktoken fun
function __tiktokenf
{
	if ((OPTTIK)) && kill -0 $COPROC_PID 2>/dev/null
	then 	send_tiktokenf "${*}" && get_tiktokenf
	else 	false
	fi; ((!$?)) || _tiktokenf "$@"
}

#poor man's tiktoken
#usage: _tiktokenf [string] [divide_by]
# divide_by  ^:less tokens  v:more tokens
function _tiktokenf
{
	typeset str tkn var by wc
	var="$1" by="$2"

	# 1 TOKEN ~= 4 CHARS IN ENGLISH
	#str="${1// }" str="${str//[$'\t\n']/xxxx}" str="${str//\\[ntrvf]/xxxx}" tkn=$((${#str}/${by:-4}))

	# 1 TOKEN ~= ¾ WORDS
	var=$(sed 's/\\[ntrvf]/ x /g' <<<"$var")  #escaped special chars
	var=$(sed 's/[^[:alnum:] \t\n]/ x/g' <<<"$var")
	wc=$(wc -w <<<"$var")
	tkn=$(( (wc * 4) / ${by:-3}))

	printf '%d\n' "${tkn:-0}" ;((tkn>0))
}

#use openai python tiktoken lib
#input should be `unescaped'
#usage: tiktokenf [model|encoding] [text|-]
function tiktokenf
{
	python -c "import sys
try:
    import tiktoken
except ImportError as e:
    print(\"Err: python -- \", e)
    exit()
opttiktoken, opttik = ${OPTTIKTOKEN:-0}, ${HOPTTIK:-0}
optv, optl = ${OPTV:-0}, ${OPTL:-0}
mod, text = sys.argv[1], \"\"
if opttik <= 0:
    if opttiktoken+optl > 2:
        for enc_name in tiktoken.list_encoding_names():
            print(enc_name)
        sys.exit()
    elif (len(sys.argv) > 2) and (sys.argv[2] == \"-\"):
        text = sys.stdin.read()
    else:
        text = sys.argv[2]
try:
    enc = tiktoken.encoding_for_model(mod)
except:
    try:
        try:
            enc = tiktoken.get_encoding(mod)
        except:
            enc = tiktoken.get_encoding(\"${MODEL_ENCODING}\")
    except:
        enc = tiktoken.get_encoding(\"r50k_base\")  #davinci
        print(\"Warning: tiktoken -- unknown model/encoding, fallback \", str(enc), file=sys.stderr)
if opttik <= 0:
    encoded_text = enc.encode_ordinary(text)
    if opttiktoken > 1:
        print(encoded_text)
    if optv:
        print(len(encoded_text))
    else:
        print(len(encoded_text),str(enc))
else:
    try:
        while text != \"/END_TIKTOKEN/\":
            text = sys.stdin.readline().rstrip(\"\\n\")
            text = text.replace(\"\\\\\\\\\", \"&\\f\\f&\").replace(\"\\\\n\", \"\\n\").replace(\"\\\\t\", \"\\t\").replace(\"\\\\\\\"\", \"\\\"\").replace(\"&\\f\\f&\", \"\\\\\")
            encoded_text = enc.encode_ordinary(text)
            print(len(encoded_text), flush=True)
    except (KeyboardInterrupt, BrokenPipeError, SystemExit):  #BaseException:
        exit()" "${MOD:-davinci}" "${@:-}"
}
#cl100k_base gpt-3.5-turbo
#json specials \" \\ b f n r t \uHEX

#set output image size
function set_sizef
{
	case "$1" in
		1024*|[Ll][Aa][Rr][Gg][Ee]|[Ll]) 	OPTS=1024x1024;;
		512*|[Mm][Ee][Dd][Ii][Uu][Mm]|[Mm]) 	OPTS=512x512;;
		256*|[Ss][Mm][Aa][Ll][Ll]|[Ss]) 	OPTS=256x256;;
		*) 	return 1;;
	esac ;return 0
}

function set_maxtknf
{
	typeset buff
	set -- "${*:-$OPTMAX}"
	set -- "${*##[+-]}" ;set -- "${*%%[+-]}"

	if [[ $* = *[0-9][!0-9][0-9]* ]]
	then 	OPTMAX="${*##${*%[!0-9]*}}" MODMAX="${*%%"$OPTMAX"}"
		OPTMAX="${OPTMAX##[!0-9]}"
	elif [[ -n ${*//[!0-9]} ]]
	then 	OPTMAX="${*//[!0-9]}"
	fi
	if ((OPTMAX>MODMAX))
	then 	buff="$MODMAX" MODMAX="$OPTMAX" OPTMAX="$buff"
	fi
}

#check input and run a chat command
function cmd_runf
{
	typeset var wc args skip map
	[[ ${*} = *([$IFS:])[/!-]* ]] || return $?
	printf "${NC}" >&2

	set -- "${1##*([$IFS:])?([/!])}" "${@:2}"
	args=("$@") ;set -- "$*"
	((${#1}<320)) || return $?

	case "$*" in
		-[0-9]*|[0-9]*|-M*|[Mm]ax*|\
		-N*|[Mm]odmax*)
			if [[ $* = -N* ]] || [[ $* = -[Mm]odmax* ]]
			then  #model capacity
				set -- "${*##@([Mm]odmax|-N)*([$IFS])}";
				[[ $* = *[!0-9]* ]] && set_maxtknf "$*" || MODMAX="$*"
			else  #response max
				set_maxtknf "${*##?([Mm]ax|-M)*([$IFS])}";
			fi
			if ((HERR))
			then 	unset HERR
				_sysmsgf 'Context length:' 'error reset'
			fi ;__cmdmsgf 'Max model / response' "$MODMAX / $OPTMAX tkns"
			;;
		-a*|presence*|pre*)
			set -- "${*//[!0-9.]}"
			OPTA="${*:-$OPTA}"
			fix_dotf OPTA
			__cmdmsgf 'Presence penalty' "$OPTA"
			;;
		-A*|frequency*|freq*)
			set -- "${*//[!0-9.]}"
			OPTAA="${*:-$OPTAA}"
			fix_dotf OPTAA
			__cmdmsgf 'Frequency penalty' "$OPTAA"
			;;
		-b*|best[_-]of*|best*)
			set -- "${*//[!0-9.]}" ;set -- "${*%%.*}"
			OPTB="${*:-$OPTB}"
			__cmdmsgf 'Best_of' "$OPTB"
			;;
		-[Cc]|break|br|new)
			break_sessionf
			[[ -n ${INSTRUCTION_OLD:-$INSTRUCTION} ]] && {
			  push_tohistf "$(escapef ":${INSTRUCTION_OLD:-$INSTRUCTION}")"
			  _sysmsgf 'INSTRUCTION:' "${INSTRUCTION_OLD:-$INSTRUCTION}" 2>&1 | foldf >&2
			} ;unset CKSUM CKSUM_OLD ;skip=1
			;;
		-g|-G|stream|no-stream)
			((++STREAM)) ;((STREAM%=2))
			__cmdmsgf 'Streaming' $(_onoff $STREAM)
			;;
		-h*|h*|help*|\?*)
			skip=1; [[ -n $ZSH_VERSION ]] && setopt LOCAL_OPTIONS NO_MONITOR
			sed -n -e 's/^\t*//' -e '/^\s*------ /,/^\s*------ /p' <<<"$HELP" | less -S
			;;
		-H|H|history|hist)
			__edf "$FILECHAT"
			unset CKSUM CKSUM_OLD ;skip=1
			;;
		-HH|HH|request|req)
			Q_TYPE="\\n${Q_TYPE}" A_TYPE="\\n${A_TYPE}" set_histf
			printf "\\n---\\n" >&2
			usr_logf "$(unescapef "$HIST\\n---")" >&2
			;;
		j|jump)
			JUMP=1 REPLY=
			return 179
			;;
		[/!]j|[/!]jump|J|Jump)
			JUMP=2 REPLY=
			return 180
			;;
		-L*|log*)
			((++OPTLOG)) ;((OPTLOG%=2))
			((OPTLOG)) || set --
			set -- "${*##@(-L|log)$SPC}"
			if [[ -d "$*" ]]
			then 	USRLOG="${*%%/}/${USRLOG##*/}"
			else 	USRLOG="${*:-${USRLOG}}"
			fi
			[[ "$USRLOG" = '~'* ]] && USRLOG="${HOME}${USRLOG##\~}"
			_cmdmsgf $'\nLog file' "<${USRLOG}>"
			;;
		models*)
			list_modelsf "${*##models*([$IFS])}"
			;;
		-m*|model*|mod*)
			set -- "${*##@(-m|model|mod)}"
			MOD="${*//[$IFS]}"  #by name
			set_model_epnf "$MOD" ;__cmdmsgf 'Model' "$MOD"
			send_tiktokenf '/END_TIKTOKEN/'
			;;
		-n*|results*)
			set -- "${*//[!0-9.]}" ;set -- "${*%%.*}"
			OPTN="${*:-$OPTN}"
			__cmdmsgf 'Results' "$OPTN"
			;;
		-p*|top*)
			set -- "${*//[!0-9.]}"
			OPTP="${*:-$OPTP}"
			fix_dotf OPTP
			__cmdmsgf 'Top P' "$OPTP"
			;;
		-r*|restart*)
			set -- "${*##@(-r|restart)$SPC}"
			restart_compf "$*"
			__cmdmsgf 'Restart Sequence' "$RESTART"
			;;
		-R*|start*)
			set -- "${*##@(-R|start)$SPC}"
			start_compf "$*"
			__cmdmsgf 'Start Sequence' "$START"
			;;
		-s*|stop*)
			set -- "${*##@(-s|stop)$SPC}"
			STOPS=("$(unescapef "${*}")" "${STOPS[@]}")
			__cmdmsgf 'Stop Sequences' "${STOPS[*]}"
			;;
		-t*|temperature*|temp*)
			set -- "${*//[!0-9.]}"
			OPTT="${*:-$OPTT}"
			fix_dotf OPTT
			__cmdmsgf 'Temperature' "$OPTT"
			;;
		-o|clipboard|clip)
			((++OPTCLIP)) ;((OPTCLIP%=2))
			set_clipcmdf
			__cmdmsgf 'Clipboard' $(_onoff $OPTCLIP)
			;;
		-q|insert)
			((++OPTSUFFIX)) ;((OPTSUFFIX%=2))
			__cmdmsgf 'Insert mode' $(_onoff $OPTSUFFIX)
			;;
		-v|verbose|ver)
			((++OPTV)) ;((OPTV%=4))
			case "$OPTV" in
				1) var='Less';;  2) var='Much less';;
				3) var='OFF';;   0) var='ON';;
			esac ;_cmdmsgf 'Verbose' "$var"
			;;
		-V|context)
			((OPTVV==1)) && unset OPTVV || OPTVV=1
			__cmdmsgf 'Print request' $(_onoff $OPTVV)
			;;
		-VV|debug)  #debug
			((OPTVV==2)) && unset OPTVV || OPTVV=2
			__cmdmsgf 'Debug request' $(_onoff $OPTVV)
			;;
		-xx|[/!]editor|[/!]ed|[/!]vim|[/!]vi)
			((OPTX)) || OPTX=2; REPLY= skip=1
			;;
		-x|editor|ed|vim|vi)
			((++OPTX)) ;((OPTX%=2)); REPLY= skip=1
			;;
		-y|-Y|tiktoken|tik|no-tik)
			send_tiktokenf '/END_TIKTOKEN/'
			((++OPTTIK)) ;((OPTTIK%=2))
			__cmdmsgf 'Tiktoken' $(_onoff $OPTTIK)
			#wait $COPROC_PID  #coproc exit #close off coproc input/output
			[[ -n $ZSH_VERSION ]] && unset COPROC_PID
			;;
		-[wW]*|audio*|rec*)
			OPTW=1 ;[[ $* = -W* ]] && OPTW=2
			set -- "${*##@(-[wW][wW]|-[wW]|audio|rec)$SPC}"

			var="${*##*([$IFS])}"
			[[ $var = [a-z][a-z][$IFS]*[[:graph:]]* ]] \
			&& set -- "${var:0:2}" "${var:3}" ;unset var

			INPUT_ORIG=("${@:-${INPUT_ORIG[@]}}") skip=1
			;;
		-z|last)
			lastjsonf >&2
			;;
		k|kill)  #kill hist entry
			if map=$(grep -n -e '^\s*[^#]' "$FILECHAT")
			then 	map=($(cut -d : -f 1 <<<"$map"))
				set -- ${map[$((${#map[@]}-1))]}
				if sed -i -e "${1} s/^/#/" "$FILECHAT"
				then 	var=$(sed -n -e "${1} s/\\t/ /gp" "$FILECHAT")
					printf "Commented out line %d: %.60s%s\\n" \
					"${1}" "${var}" "$( ((${#var}>60)) && echo ' [...]')" >&2
				fi
			fi
			;;
		i|info)
			echo >&2
			printf "${NC}${BWHITE}%-12s:${NC} %-5s\\n" \
			model-name   "${MOD:-?}" \
			model-max    "${MODMAX:-?}" \
			resp-max     "${OPTMAX:-?}" \
			context-prev "${MAX_PREV:-?}" \
			tiktoken     "${OPTTIK:-0}" \
			temperature  "${OPTT:-0}" \
			pres-penalty "${OPTA:-unset}" \
			freq-penalty "${OPTAA:-unset}" \
			top-p        "${OPTP:-unset}" \
			results      "${OPTN:-1}" \
			best-of      "${OPTB:-unset}" \
			logprobs     "${OPTBB:-unset}" \
			insert-mode  "${OPTSUFFIX:-unset}" \
			streaming    "${STREAM:-unset}" \
			clipboard    "${OPTCLIP:-unset}" \
			cat-prompter "${CATPR:-unset}" \
			ctrld-prpter "${OPTCTRD:-unset} [bash]" \
			restart-seq  "\"$( ((OPTC)) && printf '%s' "${RESTART:-$Q_TYPE}" || printf '%s' "${RESTART:-unset}")\"" \
			start-seq    "\"$( ((OPTC)) && printf '%s' "${START:-$A_TYPE}"   || printf '%s' "${START:-unset}")\"" \
			stop-seqs    "$(set_optsf 2>/dev/null ;OPTSTOP=${OPTSTOP#*:} OPTSTOP=${OPTSTOP%%,} ;printf '%s' "${OPTSTOP:-\"unset\"}")" \
			hist-file    "${FILECHAT/"$HOME"/"~"}"  >&2
			;;
		-u|multi|multiline)
			((OPTCTRD)) && unset OPTCTRD || OPTCTRD=1
			[[ -n $ZSH_VERSION ]] ||
			__cmdmsgf 'Prompter <CTRL-D>' $(_onoff $OPTCTRD)
			((OPTCTRD)) && {
				__warmsgf 'TIP:' '* <CTRL-V> + <CTRL-J> for newline * '
				[[ -n $ZSH_VERSION ]] && __warmsgf 'TIP:' '* <ALT-ENTER> for newline * '
			}
			;;
		-U)
			((++CATPR)) ;((CATPR%=2))
			__cmdmsgf 'Cat Prompter' $(_onoff $CATPR)
			;;
		cat*)
			if [[ $* = cat*[!$IFS]* ]]
			then 	cmd_runf /sh "${@}"
			else 	printf '%s\n' '* Press <CTRL-D> to flush * ' >&2
				STDERR=/dev/null  cmd_runf /sh cat
			fi ;skip=1
			;;
		[/!]sh*)
			if [[ -n $ZSH_VERSION ]]
			then 	zsh -i
			else 	bash -i
			fi ;printf '\n%s' Prompt: >&2
			EDIT=1 REPLY=;
			;;
		shell*|sh*)
			set -- "${*##sh?(ell)*([$IFS])}"
			[[ -n $* ]] || set --  ;skip=1
			while :
			do 	REPLY=$( if [[ -n $ZSH_VERSION ]]
				then 	zsh -f ${@:+-c} "${@}"
				else 	bash --norc --noprofile ${@:+-c} "${@}"
				fi </dev/tty | tee $STDERR )  ;echo >&2
				#abort on empty
				[[ $REPLY = *([$IFS]) ]] && { 	SKIP=1 EDIT=1 REPLY="!${args[*]}" ;return ;}

				_sysmsgf 'Edit buffer?' '[Y]es, [n]o, [e]dit, te[x]t editor, [s]hell, or [r]edo ' ''
				case "$(__read_charf)" in
					[AaQqRr]) 	SKIP=1 EDIT=1 REPLY="!${args[*]}"; break;;  #abort, redo
					[Ee]) 		SKIP=1 EDIT=1; break;; #yes, read / vared
					[VvXx]) 	((OPTX)) || OPTX=2 ;break;; #yes, text editor
					[NnQq]|$'\e') 	SKIP=1 PSKIP=1; break;;  #no need to edit
					[!Ss]|'') 	SKIP=1 EDIT=1;
							printf '\n%s\n' '---' >&2; break;;  #yes
				esac ;set --
			done ;__clr_lineupf 61 #!#
			((${#args[@]})) && shell_histf "!${args[*]}"
			;;
		[/!]session*|session*|list*|copy*|fork*|sub|[/!][Ss]*|[Ss]*|[/!][cf]\ *|[cf]\ *)
			echo Session and History >&2
			session_mainf /"${args[@]}"
			;;
		r|regenerate|regen|[$IFS]|[/!]|'')  #regenerate last response
			REGEN=1 SKIP=1 EDIT=1 REPLY=
			if ((!BAD_RES)) && [[ -f "$FILECHAT" ]] &&
			[[ "$(tail -n 2 "$FILECHAT")"$'\n' != *[Bb][Rr][Ee][Aa][Kk]$'\n'* ]]
			then 	# comment out two lines from tail
				wc=$(wc -l <"$FILECHAT") && ((wc>2)) \
				&& sed -i -e "$((wc-1)),${wc} s/^/#/" "$FILECHAT"
				unset CKSUM CKSUM_OLD
			fi
			;;
		q|quit|exit|bye)
			send_tiktokenf '/END_TIKTOKEN/' && wait
			exit 0
			;;
		*) 	return 1
			;;
	esac ;echo >&2
	if ((OPTX)) && ((!(REGEN+skip) ))
	then 	printf "\\r${BWHITE}${ON_CYAN}%s\\a${NC}" '* Press ENTER to CONTINUE * ' >&2
		__read_charf >/dev/null
	fi ;return 0
}

#print msg to stderr
#usage: __sysmsgf [string_one] [string_two] ['']
function __sysmsgf
{
	((OPTV<2)) || return
	printf "${BWHITE}%s${NC}${Color200}${2:+ }%s${NC}${3-\\n}" "$1" "$2" >&2
}
function _sysmsgf { 	OPTV=  __sysmsgf "$@" ;}

function __warmsgf
{
	OPTV= BWHITE="${RED}" Color200="${Color200:-${RED}}" \
	__sysmsgf "$@"
}

#command run feedback
function __cmdmsgf
{
	typeset c s
	for ((c=${#1};c<14;c++))
	do 	s=" $s"
	done
	BWHITE="${WHITE}" Color200="${CYAN}" __sysmsgf "$1" "${s}=> ${2:-unset}"
}
function _cmdmsgf { 	OPTV=  __cmdmsgf "$@" ;}
function _onoff
{
	((${1:-0})) && echo ON || echo OFF
}

#main plain text editor
function __edf
{
	[[ -n $ZSH_VERSION ]] && setopt LOCAL_OPTIONS NO_MONITOR
	${VISUAL:-${EDITOR:-vim}} "$1" </dev/tty >/dev/tty
}

#text editor stdout wrapper
function ed_outf
{
	printf "%s${*:+\\n}" "${*}" > "$FILETXT"
	__edf "$FILETXT" &&
	cat -- "$FILETXT"
}

#text editor chat wrapper
function edf
{
	typeset ed_msg pre rest pos ind sub
	((OPTCMPL))|| ed_msg=$'\n\n'",,,,,,(edit below this line),,,,,,"
	((OPTC)) && rest="${RESTART:-$Q_TYPE}" || rest="${RESTART}"
	rest="$(_unescapef "$rest")"

	if ((MTURN+OPTRESUME))
	then 	MAIN_LOOP=1 Q_TYPE="\\n${Q_TYPE}" A_TYPE="\\n${A_TYPE}" \
		set_histf "${rest}${*}"
	fi

	pre="${INSTRUCTION}${INSTRUCTION:+$'\n\n'}""$(unescapef "$HIST")""${ed_msg}"
	printf "%s\\n" "${pre}"$'\n\n'"${rest}${*}" > "$FILETXT"

	__edf "$FILETXT"

	while pos="$(<"$FILETXT")"
		[[ "$pos" != "${pre:-%#}"* ]] || [[ "$pos" = *"${rest:-%#}" ]]
	do 	__warmsgf "Warning:" "Bad edit: [E]dit, [c]ontinue, [r]edo or [a]bort? " ''
		case "$(__read_charf ;echo >&2)" in
			[AaQq]) return 201;;       #abort
			[CcNn]) break;;            #continue
			[Rr]|$'\e')  return 200;;  #redo
			[Ee]|*) __edf "$FILETXT";; #edit
		esac
	done

	ind=320 sub="${pos:${#pre}:${ind}}"
	if ((OPTCMPL))
	then 	((${#rest})) &&
		sub="${sub##$SPC"${rest}"}"
	else 	sub="${sub##?($SPC"${rest%%$SPC}")$SPC}"
	fi
	pos="${sub}${pos:$((${#pre}+${ind}))}"

	printf "%s\\n" "$pos" > "$FILETXT"

	if ((MTURN))
	then 	cmd_runf "${pos##:}" && return 200
	fi ;return 0
}

#(un)escape from/to json
function _escapef
{
	tr -d '\000' <<<"$*" | sed 's/\\/\\\\/g;' \
	| sed -e  's/\r/\\r/g;   s/\t/\\t/g;       s/"/\\"/g;' \
	    -e $'s/\a/\\\\a/g; s/\f/\\\\f/g;     s/\b/\\\\b/g;' \
	    -e $'s/\v/\\\\v/g; s/\e/\\\\u001b/g; s/[\03\04]//g;' \
	| if [[ $* = *$'\n'* ]]
	then 	sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
	else 	cat  #bsd sed fix
	fi
}  #fallback
#https://stackoverflow.com/questions/1251999/how-can-i-replace-each-newline-n-with-a-space-using-sed
[[ -n $ZSH_VERSION ]] \
&& function _unescapef { 	printf -- "${${*//\%/%%}//\\\"/\"}" ;} \
|| function _unescapef { 	printf -- "${*//\%/%%}" ;}  #fallbacks

function unescapef {
	((${#1})) || return
	jq -Rr '"\"" + . + "\"" | fromjson' <<<"$*" || ! _unescapef "$*"
}
function escapef {
	((${#1})) || return
	printf '%s' "$*" | jq -Rrs 'tojson[1:-1]' || ! _escapef "$*"
}
# json special chars: \" \/ b f n r t \\uHEX
# characters from U+0000 through U+001F must be escaped

function break_sessionf
{
	[[ -f "$FILECHAT" ]] || return
	[[ BREAK"$(tail -n 20 "$FILECHAT")" = *[Bb][Rr][Ee][Aa][Kk] ]] \
	|| _sysmsgf "$(tee -a -- "$FILECHAT" <<<'SESSION BREAK')"
}

#fix variable value, add zero before/after dot.
function fix_dotf
{
	eval "[[ \$$1 = [0-9.] ]] || return"
	eval "[[ \$$1 = .[0-9]* ]] && $1=0\$${1}"
	eval "[[ \$$1 = *[0-9]. ]] && $1=\${${1}}0"
}

#minify json
function json_minif
{
	typeset blk
	blk=$(jq -c . <<<"$BLOCK") || return
	BLOCK="${blk:-$BLOCK}"
}

#format for chat completions endpoint
#usage: fmt_ccf [prompt] [role]
function fmt_ccf
{
	[[ ${1} != *([$IFS]) ]] || return
	printf '{"role": "%s", "content": "%s"}\n' "${2:-user}" "$1"
}

#create user log
function usr_logf
{
	printf '%s  Tokens: %s\n\n%s\n' \
	"${HIST_TIME:-$(date -R 2>/dev/null||date)}" "${MAX_PREV:-?}" "$*"
}

#wrap text at spaces rather than mid-word
function foldf
{
	if ((COLUMNS>16)) && [[ -t 1 ]] && ((!STREAM))
	then 	fold -s -w $COLUMNS 2>/dev/null || cat
	else 	cat
	fi
}

#check if a value if within a fp range
#usage: check_optrangef [val] [min] [max]
function check_optrangef
{
	typeset val min max prop ret
	val="${1:-0}" min="${2:-0}" max="${3:-0}" prop="${4:-property}"

	if [[ -n $ZSH_VERSION ]]
	then 	ret=$(( (val < min) || (val > max) ))
	else 	ret=$(bc <<<"($val < $min) || ($val > $max)") || function check_optrangef { : ;}  #no-`bc' systems
	fi

	if [[ $val = *[!0-9.,+-]* ]] || ((ret))
	then 	printf "${RED}Warning: Bad %s${NC}${BRED} -- %s  ${NC}${YELLOW}(%s - %s)${NC}\\n" "$prop" "$val" "$min" "$max" >&2
		return 1
	fi ;return ${ret:-0}
}

#check and set settings
function set_optsf
{
	typeset s n
	((OPTI+OPTEMBED)) || {
	  ((OPTW)) || {
	    ((OPTE)) || {
	      check_optrangef "$OPTA"   -2.0 2.0 'Presence-penalty'
	      check_optrangef "$OPTAA"  -2.0 2.0 'Frequency-penalty'
	      ((OPTB)) && check_optrangef "${OPTB:-$OPTN}"  "$OPTN" 50 'Best_of'
	      check_optrangef "$OPTBB" 0   5 'Logprobs'
	    }
	    check_optrangef "$OPTP"  0.0 1.0 'Top_p'
	    check_optrangef "$OPTMAX"  1 "$MODMAX" 'Response Max Tokens'
	  }
	  check_optrangef "$OPTT"  0.0 2.0 'Temperature'  #whisper max=1
	}
	((OPTI)) && check_optrangef "$OPTN"  1 10 'Number of Results'

	[[ -n $OPTA ]] && OPTA_OPT="\"presence_penalty\": $OPTA," || unset OPTA_OPT
	[[ -n $OPTAA ]] && OPTAA_OPT="\"frequency_penalty\": $OPTAA," || unset OPTAA_OPT
	{ ((OPTB)) && OPTB_OPT="\"best_of\": $OPTB," || unset OPTB OPTB_OPT;
	  ((OPTBB)) && OPTBB_OPT="\"logprobs\": $OPTBB," || unset OPTBB OPTBB_OPT; } 2>/dev/null
	[[ -n $OPTP ]] && OPTP_OPT="\"top_p\": $OPTP," || unset OPTP_OPT
	[[ -n $SUFFIX ]] && OPTSUFFIX_OPT="\"suffix\": \"$(escapef "$SUFFIX")\"," || unset OPTSUFFIX_OPT
	((STREAM)) && STREAM_OPT="\"stream\": true," || unset STREAM STREAM_OPT
	((OPTV<1)) && unset OPTV

	((EPN==6)) || {
	if ((${#STOPS[@]})) && [[ "${STOPS[*]}" != "${STOPS_OLD[*]:-%#}" ]]
	then  #compile stop sequences  #def: <|endoftext|>
		unset OPTSTOP
		for s in "${STOPS[@]}"
		do 	[[ -n $s ]] || continue
			((++n)) ;((n>4)) && break
			OPTSTOP="${OPTSTOP}${OPTSTOP:+,}\"$(escapef "$s")\""
		done
		if ((n==1))
		then 	OPTSTOP="\"stop\":${OPTSTOP},"
		elif ((n))
		then 	OPTSTOP="\"stop\":[${OPTSTOP}],"
		fi ;STOPS_OLD=("${STOPS[@]}")
	fi #https://help.openai.com/en/articles/5072263-how-do-i-use-stop-sequences
	[[ "$RESTART" = "$RESTART_OLD" ]] || restart_compf
	[[ "$START" = "$START_OLD" ]] || start_compf
	}
}

function restart_compf { RESTART=$(escapef "$(unescapef "${*:-$RESTART}")") RESTART_OLD="$RESTART" ;}
function start_compf {     START=$(escapef "$(unescapef "${*:-$START}")")   START_OLD="$START" ;}

function record_confirmf
{
	if ((OPTV<1)) && { 	((!WSKIP)) || [[ ! -t 1 ]] ;}
	then 	printf "\\r${BWHITE}${ON_PURPLE}%s${NC}" '* Press ENTER to START record * ' >&2
		case "$(__read_charf)" in [AaNnQq]|$'\e') 	return 201;; esac
		__clr_lineupf 33  #!#
	fi
	printf "\\r${BWHITE}${ON_PURPLE}%s${NC}\\a\\n\\n" '* Press ENTER to  STOP record * ' >&2
}

#record mic
#usage: recordf [filename]
function recordf
{
	typeset termux pid sig REPLY

	[[ -e $1 ]] && rm -- "$1"  #remove file before writing to it

	if [[ -n ${REC_CMD%% *} ]] && command -v ${REC_CMD%% *} >/dev/null 2>&1
	then 	$REC_CMD "$1" &  #this ensures max user compat
	elif command -v termux-microphone-record >/dev/null 2>&1
	then 	termux=1
		termux-microphone-record -c 1 -l 0 -f "$1" &
	elif command -v sox  >/dev/null 2>&1
	then 	#sox, best auto option
		{ 	rec "$1" & pid=$! ;} ||
		{ 	sox -d "$1" & pid=$! ;}
	elif command -v arecord  >/dev/null 2>&1
	then 	#alsa-utils
		arecord -i "$1" &
	else 	#ffmpeg
		{ 	ffmpeg -f alsa -i pulse -ac 1 -y "$1" & pid=$! ;} ||
		{ 	ffmpeg -f avfoundation -i ":1" -y "$1" & pid=$! ;}
		#-acodec libmp3lame -ab 32k -ac 1  #https://stackoverflow.com/questions/19689029/
	fi >&2
	pid=${pid:-$!}

	sig="INT HUP TERM EXIT"
	trap "rec_killf $pid $termux; trap '-' $sig;" $sig
	read </dev/tty; rec_killf $pid $termux;
	trap '-' $sig
	wait $pid
}
#avfoundation for macos: <https://apple.stackexchange.com/questions/326388/>
function rec_killf
{
	typeset pid termux
	pid=$1 termux=$2
	((termux)) && termux-microphone-record -q >&2 || kill -INT -- ${ZSH_VERSION:+-}$pid;
}

#set whisper language
function __set_langf
{
	if [[ $1 = [a-z][a-z] ]]
	then 	if ((!OPTWW))
		then 	LANGW="-F language=$1"
			((OPTV)) || __sysmsgf 'Language:' "$1"
		fi ;return 0
	fi ;return 1
}

#whisper
function whisperf
{
	typeset file
	((MTURN)) || __sysmsgf 'Temperature:' "$OPTT"
	check_optrangef "$OPTT" 0 1.0 Temperature

	#set language ISO-639-1 (two letters)
	if __set_langf "$1"
	then 	shift
	elif __set_langf "$2"
	then 	set -- "${@:1:1}" "${@:3}"
	fi

	if { 	((!$#)) || [[ ! -e $1 && ! -e ${@:${#}} ]] ;} && ((!MTURN))
	then 	printf "${PURPLE}%s ${NC}" 'Record mic input? [Y/n]' >&2
		case "$(__read_charf)" in
			[AaNnQq]|$'\e') 	:;;
			*) 	OPTV=4 record_confirmf || return
				WSKIP=1 recordf "$FILEINW"
				set -- "$FILEINW" "$@";;
		esac
	fi

	if [[ -e $1 && $1 = *@(mp3|mp4|mpeg|mpga|m4a|wav|webm) ]]
	then 	file="$1"; shift;
	elif (($#)) && [[ -e ${@:${#}} && ${@:${#}} = *@(mp3|mp4|mpeg|mpga|m4a|wav|webm) ]]
	then 	file="${@:${#}}"; set -- "${@:1:$((${#}-1))}";
	else 	printf "${BRED}Err: %s --${NC} %s\\n" 'Unknown audio format' "$1" >&2
		return 1
	fi ;[[ -e $1 ]] && shift  #get rid of eventual second filename

	#set a prompt
	[[ ${*} = *([$IFS]) ]] || set -- -F prompt="$*"

	#response_format (timestamps) - testing
	if ((OPTW>1 || OPTWW>1)) && ((!MTURN))
	then
		OPTW_FMT=verbose_json   #json, text, srt, verbose_json, or vtt.
		[[ -n $OPTW_FMT ]] && set -- -F response_format="$OPTW_FMT" "$@"

		prompt_audiof "$file" $LANGW "$@"
		jq -r "${JQCOLNULL} ${JQCOL}
			def pad(x): tostring | (length | if . >= x then \"\" else \"0\" * (x - .) end) as \$padding | \"\(\$padding)\(.)\";
			def seconds_to_time_string:
			def nonzero: floor | if . > 0 then . else empty end;
			if . == 0 then \"00\"
			else
			[(./60/60         | nonzero),
			 (./60       % 60 | pad(2)),
			 (.          % 60 | pad(2))]
			| join(\":\")
			end;
			\"Task: \(.task)\" +
			\"\\t\" + \"Lang: \(.language)\" +
			\"\\t\" + \"Dur: \(.duration|seconds_to_time_string)\" +
			\"\\n\", (.segments[]| \"[\" + yellow + \"\(.start|seconds_to_time_string)\" + reset + \"]\" +
			bpurple + .text + reset)" "$FILE" \
			|| jq -r '.text' "$FILE" || cat -- "$FILE"
			#https://rosettacode.org/wiki/Convert_seconds_to_compound_duration#jq
			#https://stackoverflow.com/questions/64957982/how-to-pad-numbers-with-jq
	else
		prompt_audiof "$file" $LANGW "$@"
		jq -r "${JQCOLNULL} ${JQCOL}
		bpurple + .text + reset" "$FILE" || cat -- "$FILE"
	fi
}

#image edits/variations
function imgvarf
{
	typeset size prompt mask ;unset ARGS PNG32
	[[ -e ${1:?input PNG path required} ]]

	if command -v magick >/dev/null 2>&1
	then 	if ! __is_pngf "$1" || ! __is_squaref "$1" || ! __is_rgbf "$1" ||
			{ 	((${#} > 1)) && [[ ! -e $2 ]] ;} || [[ -n ${OPT_AT+force} ]]
		then  #not png or not square, or needs alpha
			if ((${#} > 1)) && [[ ! -e $2 ]]
			then  #needs alpha
				__set_alphaf "$1"
			else  #no need alpha
			      #resize and convert (to png32?)
				if __is_opaquef "$1"
				then  #is opaque
					ARGS="" PNG32="" ;((OPTV)) ||
					printf '%s\n' 'Alpha not needed, opaque image' >&2
				else  #is transparent
					ARGS="-alpha set" PNG32="png32:" ;((OPTV)) ||
					printf '%s\n' 'Alpha not needed, transparent image' >&2
				fi
			fi
			__is_rgbf "$1" || { 	PNG32="png32:" ;printf '%s\n' 'Image colour space is not RGB(A)' >&2 ;}
			img_convf "$1" $ARGS "${PNG32}${FILEIN}" &&
				set -- "${FILEIN}" "${@:2}"  #adjusted
		else 	((OPTV)) ||
			printf '%s\n' 'No adjustment needed in image file' >&2
		fi ;unset ARGS PNG32

		if [[ -e $2 ]]  #edits + mask file
		then 	size=$(print_imgsizef "$1")
			if ! __is_pngf "$2" || ! __is_rgbf "$2" || {
				[[ $(print_imgsizef "$2") != "$size" ]] &&
				{ 	((OPTV)) || printf '%s\n' 'Mask size differs' >&2 ;}
			} || __is_opaquef "$2" || [[ -n ${OPT_AT+true} ]]
			then 	mask="${FILEIN%.*}_mask.png" PNG32="png32:" ARGS=""
				__set_alphaf "$2"
				img_convf "$2" -scale "$size" $ARGS "${PNG32}${mask}" &&
					set  -- "$1" "$mask" "${@:3}"  #adjusted
			else 	((OPTV)) ||
				printf '%s\n' 'No adjustment needed in mask file' >&2
			fi
		fi
	fi ;unset ARGS PNG32

	__chk_imgsizef "$1" || return 2

	## one prompt  --  generations
	## one file  --  variations
	## one file (alpha) and one prompt  --  edits
	## two files, (and one prompt)  --  edits
	if [[ -e $1 ]] && ((${#} > 1))  #img edits
	then 	OPTII=1 EPN=9 MOD=image-ed
		if ((${#} > 2)) && [[ -e $2 ]]
		then 	prompt="${@:3}" ;set -- "${@:1:2}"
		elif ((${#} > 1)) && [[ ! -e $2 ]]
		then 	prompt="${@:2}" ;set -- "${@:1:1}"
		fi
		[[ -e $2 ]] && set -- "${@:1:1}" -F mask="@$2"
	elif [[ -e $1 ]]  #img variations
	then 	OPTII=1 EPN=4 MOD=image-var
	fi
	[[ -n $prompt ]] && set -- "$@" -F prompt="$prompt"

	prompt_imgvarf "$@"
	prompt_imgprintf
}
#https://legacy.imagemagick.org/Usage/resize/
#https://imagemagick.org/Usage/masking/#alpha
#https://stackoverflow.com/questions/41137794/
#https://stackoverflow.com/questions/2581469/
#https://superuser.com/questions/1491513/
#
#set alpha flags for IM
function __set_alphaf
{
	unset ARGS PNG32
	if __has_alphaf "$1"
	then  #has alpha
		if __is_opaquef "$1"
		then  #is opaque
			ARGS="-alpha set -fuzz ${OPT_AT_PC:-0}% -transparent ${OPT_AT:-black}" PNG32="png32:"
			((OPTV)) ||
			printf '%s\n' 'File has alpha but is opaque' >&2
		else  #is transparent
			ARGS="-alpha set" PNG32="png32:"
			((OPTV)) ||
			printf '%s\n' 'File has alpha and is transparent' >&2
		fi
	else  #no alpha, is opaque
		ARGS="-alpha set -fuzz ${OPT_AT_PC:-0}% -transparent ${OPT_AT:-black}" PNG32="png32:"
		((OPTV)) ||
		printf '%s\n' 'File has alpha but is opaque' >&2
	fi
}
#check if file ends with .png
function __is_pngf
{
	if [[ $1 != *.[Pp][Nn][Gg] ]]
	then 	((OPTV)) || printf '%s\n' 'Not a PNG image' >&2
		return 1
	fi ;return 0
}
#convert image
#usage: img_convf [in_file] [opt..] [out_file]
function img_convf
{
	if ((!OPTV))
	then 	[[ $ARGS = *-transparent* ]] &&
		printf "${BWHITE}%-12s --${NC} %s\\n" "Transparent colour" "${OPT_AT:-black}" "Fuzz" "${OPT_AT_PC:-2}%" >&2
		__sysmsgf 'Edit with ImageMagick?' '[Y/n] ' ''
		case "$(__read_charf)" in [AaNnQq]|$'\e') 	return 2;; esac
	fi

	if magick convert "$1" -background none -gravity center -extent 1:1 "${@:2}"
	then 	if ((!OPTV))
		then 	set -- "${@##png32:}" ;__openf "${@:${#}}"
			__sysmsgf 'Confirm edit?' '[Y/n] ' ''
			case "$(__read_charf)" in [AaNnQq]|$'\e') 	return 2;; esac
		fi
	else 	false
	fi
}
#check for image alpha channel
function __has_alphaf
{
	typeset alpha
	alpha=$(magick identify -format '%A' "$1")
	[[ $alpha = [Tt][Rr][Uu][Ee] ]] || [[ $alpha = [Bb][Ll][Ee][Nn][Dd] ]]
}
#check if image is opaque
function __is_opaquef
{
	typeset opaque
	opaque=$(magick identify -format '%[opaque]' "$1")
	[[ $opaque = [Tt][Rr][Uu][Ee] ]]
}
#https://stackoverflow.com/questions/2581469/detect-alpha-channel-with-imagemagick
#check if image is square
function __is_squaref
{
	if (( $(magick identify -format '%[fx:(h != w)]' "$1") ))
	then 	((OPTV)) || printf '%s\n' 'Image is not square' >&2
		return 2
	fi
}
#print image size
function print_imgsizef
{
	magick identify -format "%wx%h\n" "$@"
}
#check file size of image
function __chk_imgsizef
{
	typeset chk_fsize
	if chk_fsize=$(wc -c <"$1" 2>/dev/null) ;(( (chk_fsize+500000)/1000000 >= 4))
	then 	__warmsgf "Warning:" "Max image size is 4MB [file:$((chk_fsize/1000))KB]"
		(( (chk_fsize+500000)/1000000 < 5))
	fi
}
#is image colour space rgb?
function __is_rgbf
{
	[[ " $(magick identify -format "%r" "$@") " = *[Rr][Gg][Bb]* ]]
}

#image generations
function imggenf
{
	BLOCK="{
		\"prompt\": \"${*:?IMG PROMPT ERR}\",
		\"size\": \"$OPTS\",
		\"n\": $OPTN,
		\"response_format\": \"$OPTI_FMT\"
	}"
	promptf
}

#embeds
function embedf
{
	BLOCK="{
		\"model\": \"$MOD\",
		\"input\": \"${*:?INPUT ERR}\",
		\"temperature\": $OPTT, $OPTP_OPT
		\"max_tokens\": $OPTMAX,
		\"n\": $OPTN
	}"
	promptf
}

function moderationf
{
	BLOCK="{ \"input\": \"${*:?INPUT ERR}\" }"
	_promptf
}

#edits
function editf
{
	BLOCK="{
		\"model\": \"$MOD\",
		\"instruction\": \"${1:?EDIT MODE ERR}\",
		\"input\": \"${@:2}\",
		\"temperature\": $OPTT, $OPTP_OPT
		\"n\": $OPTN
	}"
	promptf
}

# Awesome-chatgpt-prompts
function awesomef
{
	typeset REPLY act_keys act_keys_n act zh a l n
	[[ "$INSTRUCTION" = %* ]] && FILEAWE="${FILEAWE%%.csv}-zh.csv" zh=1
	set -- "${INSTRUCTION##[/%]}"
	set -- "${1// /_}"
	FILECHAT="${FILECHAT%/*}/awesome.tsv"
	_cmdmsgf 'Awesome Prompts' "$1"

	if ((OPTRESUME==1))
	then 	unset OPTAWE ;return
	elif ((!MTURN))
	then 	unset OPTAWE
	fi

	if [[ ! -s $FILEAWE ]] || [[ $1 = [/%]* ]]  #second slash
	then 	set -- "${1##[/%]}"
		if 	if ((zh))
			then 	! { curl -\#L "$AWEURLZH" \
				| jq '"act,prompt",(.[]|join(","))' \
				| sed 's/,/","/' >"$FILEAWE" ;}  #json to csv
			else 	! curl -\#L "$AWEURL" -o "$FILEAWE"
			fi
		then 	[[ -f $FILEAWE ]] && rm -- "$FILEAWE"
			return 1
		fi
	fi ;set -- "${1:-%#}"

	#map prompts to indexes and get user selection
	act_keys=$(sed -e '1d; s/,.*//; s/^"//; s/"$//; s/""/\\"/g; s/[][()`*_]//g; s/ /_/g' "$FILEAWE")
	act_keys_n=$(wc -l <<<"$act_keys")
	while ! { 	((act && act <= act_keys_n)) ;}
	do 	if ! act=$(grep -n -i -e "${1//[ _-]/[ _-]}" <<<"${act_keys}")
		then 	select act in ${act_keys}
			do 	break
			done ;act="$REPLY"
		elif act="$(cut -f1 -d: <<<"$act")"
			[[ ${act} = *$'\n'?* ]]
		then 	while read l;
			do 	((++n));
				for a in ${act};
				do 	((n==a)) && printf '%d) %s\n' "$n" "$l" >&2;
				done;
			done <<<"${act_keys}"
			printf '#? <enter> ' >&2
			read -r ${BASH_VERSION:+-e} act </dev/tty
		fi ;set -- "$act"
	done

	INSTRUCTION="$(sed -n -e 's/^[^,]*,//; s/^"//; s/"$//; s/""/"/g' -e "$((act+1))p" "$FILEAWE")"
	((MTURN)) &&
	if ((OPTX))  #edit chosen awesome prompt
	then 	INSTRUCTION=$(ed_outf "$INSTRUCTION") || exit
		printf '%s\n\n' "$INSTRUCTION" >&2 ;sleep 1
	elif [[ -n $ZSH_VERSION ]]
	then 	vared -c -e -h INSTRUCTION
	else 	read -r -e ${OPTCTRD:+-d $'\04'} -i "$INSTRUCTION" INSTRUCTION
		INSTRUCTION=${INSTRUCTION%%*($'\r')}
	fi </dev/tty
	if [[ -z $INSTRUCTION ]]
	then 	__warmsgf 'Err:' 'awesome-chatgpt-prompts fail'
		unset OPTAWE ;return 1
	fi ;echo >&2
}

# Custom prompts
function custom_prf
{
	typeset file filechat name template list msg new skip ret
	filechat="$FILECHAT"
	FILECHAT="${FILECHAT%%.[Tt][SsXx][VvTt]}.pr"
	case "$INSTRUCTION" in  #lax syntax
		*[.]) 	INSTRUCTION=".${INSTRUCTION%%[.]}";;
		*[,]) 	INSTRUCTION=",${INSTRUCTION%%[,]}";;
	esac

	#options
	case "$INSTRUCTION"  in
		*([.,])@(list|\?))
			INSTRUCTION= list=1
			_cmdmsgf 'Prompt File' 'LIST'
			;;
		,*|.,*)   #edit template prompt file
			INSTRUCTION="${INSTRUCTION##[.,]*( )}"
			template=1 skip=0 msg='EDIT TEMPLATE'
			;;
		[.,]) #pick prompt file
			INSTRUCTION=
			;;
	esac

	#set skip confirmation (catch ./file)
	[[ $INSTRUCTION = ..* ]] && [[ $INSTRUCTION != ../*([!/]) ]] \
	&& INSTRUCTION="${INSTRUCTION##[.,]}" skip=${skip:-1}

	[[ ! -f $INSTRUCTION ]] && [[ $INSTRUCTION != ./*([!/]) ]] \
	&& INSTRUCTION="${INSTRUCTION##[.,]}"
	name=$(trim_leadf "$INSTRUCTION" '*( )')

	#set source prompt file
	if [[ -f $name ]]
	then 	file="$name"
	elif [[ $name = */* ]] ||
		! file=$(SESSION_LIST=$list SGLOB='[Pp][Rr]' session_globf "$name")
	then 	template=1
		file=$(SGLOB='[Pp][Rr]' session_name_choosef "$name")
		[[ -e $file ]] && msg=${msg:-LOAD} || msg=CREATE
	fi
	((list)) && exit

	if [[ $file = [Cc]urrent || "$file" = . ]]
	then 	file="${FILECHAT}"
	elif [[ $file = [Aa]bort ]]
	then 	return 2
	fi
	if [[ -f "$file" ]]
	then 	msg=${msg:-LOAD}    INSTRUCTION=$(<"$file")
	else 	msg=${msg:-CREATE}  INSTRUCTION=  template=1 new=1
	fi

	FILECHAT="${filechat%/*}/${file##*/}"
	FILECHAT="${FILECHAT%%.[Pp][Rr]}.tsv"
	if ((OPTHH))
	then 	session_sub_fifof "$FILECHAT"
		return
	fi
	_sysmsgf 'Hist   File:' "${FILECHAT/"$HOME"/"~"}"
	_sysmsgf 'Prompt File:' "${file/"$HOME"/"~"}"
	_cmdmsgf "${new:+New }Prompt Cmd" " ${msg}"

	if { 	[[ $msg = *[Cc][Rr][Ee][Aa][Tt][Ee]* ]] && INSTRUCTION="$*" ret=200 ;} ||
		[[ $msg = *[Ee][Dd][Ii][Tt]* ]] || ((MTURN && OPTRESUME!=1 && skip==0))
	then
		if ((OPTX))  #edit prompt
		then 	INSTRUCTION=$(ed_outf "$INSTRUCTION") || exit
			printf '%s\n\n' "$INSTRUCTION" >&2 ;sleep 1
		elif [[ -n $ZSH_VERSION ]]
		then 	IFS= vared -c -e -h INSTRUCTION
		else 	[[ $INSTRUCTION != *$'\n'* ]] || ((OPTCTRD)) \
			|| { typeset OPTCTRD=2; __cmdmsgf $'\n''Prompter <CTRL-D>' 'one-shot' ;}
			IFS= read -r -e ${OPTCTRD:+-d $'\04'} -i "$INSTRUCTION" INSTRUCTION
			INSTRUCTION=${INSTRUCTION%%*($'\r')}
		fi </dev/tty

		if ((template))  #push changes to file
		then 	printf '%s' "$INSTRUCTION"${INSTRUCTION:+$'\n'} >"$file"
			[[ -e "$file" && ! -s "$file" ]] && { rm -v -- "$file" || rm -- "$file" ;}
		fi
		if [[ -z $INSTRUCTION ]]
		then 	__warmsgf 'Err:' 'custom prompts fail'
			return 1
		fi
	fi
	return ${ret:-0}
}

# Set the clipboard command
function set_clipcmdf
{
	if command -v termux-clipboard-set
	then 	CLIP_CMD='termux-clipboard-set'
	elif command -v pbcopy
	then 	CLIP_CMD='pbcopy'
	elif command -v xsel
	then 	CLIP_CMD='xsel -b'
	elif command -v xclip
	then 	CLIP_CMD='xclip -selection clipboard'
	fi >/dev/null 2>&1
}

#append to shell hist list
function shell_histf
{
	[[ ${*} != *([$IFS]) ]] || return
	if [[ -n $ZSH_VERSION ]]
	then 	print -s -- "$*"
	else 	history -s -- "$*"
	fi
}
#history file must start with a timestamp (# plus Unix timestamp) or else
#the history command will still split on each line of a multi-line command
#https://askubuntu.com/questions/1133015/
#https://lists.gnu.org/archive/html/bug-bash/2011-02/msg00025.html

#print checksum
function cksumf
{
	[[ -f "$1" ]] && wc -l -- "$@"
}

#list session files in cache dir
function session_listf
{
	SESSION_LIST=1 session_globf "$@"
}
#pick session files by globbing cache dir
function session_globf
{
	typeset REPLY file glob sglob ok
	sglob="${SGLOB:-[Tt][Ss][Vv]}"
	[[ ! -f "$1" ]] || return
	[[ "$1" != [Nn]ew ]] || return
	[[ "$1" = [Cc]urrent || "$1" = . ]] && set -- "${FILECHAT##*/}" "${@:2}"

	cd -- "${CACHEDIR}"
	glob="${1%%.${sglob}}" glob="${glob##*/}"
	[[ -f "${glob}".${sglob//[!a-z]} ]] || set -- *${glob}*.${sglob}

	if ((SESSION_LIST))
	then 	ls -- "$@" >&2 ;return
	fi

	if ((${#} >1)) && [[ "$glob" != *[$IFS]* ]]
	then 	printf '# Pick file [.%s]:\n' "${sglob//[!a-z]}" >&2
		select file in 'current' 'new' 'abort' "${@%%.${sglob}}"
		do 	break
		done
		file="${file:-$REPLY}"
	else 	file="${1}"
	fi

	case "$file" in
		[Cc]urrent|.|'')
			file="${FILECHAT##*/}"
			;;
		[Nn]ew) session_name_choosef
			return
			;;
		[Aa]bort)
			printf 'abort'
			return
			;;
		"$REPLY")
			ok=1
			;;
	esac

	file="${CACHEDIR%%/}/${file:-${*:${#}}}"
	file="${file%%.${sglob}}.${sglob//[!a-z]}"
	[[ -f $file || $ok -gt 0 ]] && printf '%s\n' "${file}"
}
#set tsv filename based on input
function session_name_choosef
{
	typeset fname new print_name sglob
	fname="$1" sglob="${SGLOB:-[Tt][Ss][Vv]}"
	while
		fname="${fname%%\/}"
		fname="${fname%%.${sglob}}"
		fname="${fname/\~\//"$HOME"\/}"

		if [[ -d "$fname" ]]
		then 	__warmsgf 'Err:' 'Is a directory'
			fname="${fname%%/}"
		( 	cd "$fname" &&
			ls -- "${fname}"/*.${sglob} ) >&2 2>/dev/null
			shell_histf "${fname}${fname:+/}"
			unset fname
		fi

		if [[ ${fname} = *([$IFS]) ]]
		then 	[[ ${fname} = *.[Pp][Rr] ]] \
			&& _sysmsgf 'New prompt file name <enter>:' \
			|| _sysmsgf 'New session name <enter>:'
			if [[ -n $ZSH_VERSION ]]
			then 	vared -c -e fname
			else 	read -r -e -i "$fname" fname
			fi </dev/tty
		fi

		if [[ -d "$fname" ]]
		then 	unset fname
			continue
		fi

		if [[ $fname != *?/?* ]] && [[ ! -e "$fname" ]]
		then 	fname="${CACHEDIR%%/}/${fname:-x}"
		fi
		fname="${fname:-x}"
		if [[ ! -f "$fname" ]]
		then 	fname="${fname}.${sglob//[!a-z]}"
			new=" new"
		fi

		if [[ $fname = $FILECHAT ]]
		then 	print_name=current
		else 	print_name="${fname/"$HOME"/"~"}"
		fi
		if [[ ! -e $fname ]]
		then 	_sysmsgf "Confirm${new}? [Y/n]:" "${print_name} " '' ''
			case "$(__read_charf)" in [NnQqAa]|$'\e') 	:;; *) 	false;; esac
		else 	false
		fi
	do 	unset fname new print_name
	done

	if [[ ! -e ${fname} ]]
	then 	[[ ${fname} = *.[Pp][Rr] ]] \
		&& printf '(new prompt file)\n' >&2 \
		|| printf '(new hist file)\n' >&2
	fi
	[[ ${fname} != *([$IFS]) ]] && printf '%s\n' "$fname"
}
#pick and print a session from hist file
function session_sub_printf
{
	typeset REPLY file time token string buff buff_end index search sopt cl m n
	file="${1}" ;[[ -s $file ]] || return
	FILECHAT_OLD="$file" search="$REGEX"

	while IFS= read -r
	do 	__spinf
		if [[ ${REPLY} = *([$IFS])\#* ]]
		then 	continue
		elif [[ ${REPLY} = *[Bb][Rr][Ee][Aa][Kk]*([$IFS]) ]]
		then
for ((m=1;m<2;++m))
do 	__spinf 	#grep for user regex
			if ((${search:+1}))
			then
				[[ $search = -?* ]] && sopt="${search%% *}" search="${search#* }"
				grep $sopt "${search}" <<<" " >/dev/null
				(($?<2)) || return 1
				buff_end="regex: ${search}"
				((OPTK)) || cl='--color=always'
				grep $cl $sopt "${search}" \
				< <(_unescapef "$(cut -f1,3- -d$'\t' <<<"$buff")") >&2 || buff=
			else
				for ((n=0;n<10;++n))
				do 	__spinf
					IFS=$'\t' read -r time token string || break
					string="${string##[\"]}" string="${string%%[\"]}"
					buff_end="${buff_end}"${buff_end:+$'\n'}"${string}"
				done <<<"${buff}"
			fi

			[[ -n $buff ]] && {
			  ((${#buff_end}>640)) && ((index=${#buff_end}-640)) || index=0
			  printf -- '---\n%.640s\n---\n' "$(_unescapef "${buff_end:${index:-0}}")" >&2

			  ((OPTPRINT)) && break 2
			  ((${search:+1})) && _sysmsgf "Is this the right session?" '[Y/n/a] ' '' ||
			  _sysmsgf "Is this the tail of the right session?" '[Y]es, [n]o, [r]egex, [a]bort ' ''
			  case "$(__read_charf </dev/tty)" in
			  	[]GgSsRr/?:\;]) 	__sysmsgf 'grep:' '<-opt> <regex> <enter>'
					if [[ -n $ZSH_VERSION ]]
					then 	vared -c -e -h search
					else 	read -r -e -i "$search" search
					fi </dev/tty
					continue
					;;
			  	[Nn]|$'\e') 	false
					;;
				[AaQq]) 	return 1
					;;
				*) 	break 2
					;;
			  esac
			}
done
			unset REPLY time token string buff buff_end index cl m n
			continue
		fi
		buff="${REPLY##\#}"${buff:+$'\n'}"${buff}"
	done < <( 	tac -- "$file" && {
			((OPTHH+OPTPRINT)) || __warmsgf '(end of hist file)' ;}
			echo BREAK;
		); __printbf ' '
	[[ -n ${buff} ]] && printf '%s\n' "$buff"
}
#copy session to another session file, print destination filename
function session_copyf
{
	typeset src dest buff

	((${#}==1)) && [[ "$1" = +([!\ ])[\ ]+([!\ ]) ]] && set -- $@  #filename with spaces

	_sysmsgf 'Source hist file: ' '' ''
	if ((${#}==1)) && [[ "$1" != [Cc]urrent && "$1" != . ]]
	then 	src=current; echo "${src:-err}" >&2
	else 	src="$(session_globf "${@:1:1}" || session_name_choosef "${@:1:1}")"; echo "${src:-err}" >&2
		[[ $src != abort ]] || return
		set -- "${@:2:1}"
	fi
	_sysmsgf 'Destination hist file: ' '' ''
	dest="$(session_globf "$@" || session_name_choosef "$@")"; echo "${dest:-err}" >&2
	dest="${dest:-$FILECHAT}"

	buff=$(session_sub_printf "$src") \
	&& if [[ -f "$dest" ]] ;then 	[[ "$(<"$dest")" != *"${buff}" ]] || return 0 ;fi \
	&& FILECHAT="${dest}" INSTRUCTION_OLD= INSTRUCTION= cmd_runf /break \
	&& printf '%s\n' "$buff" >> "$dest" \
	&& printf '%s\n' "$dest"
}
#create or copy a session, search for and change to a session file.
function session_mainf
{
	typeset name file optsession args arg break msg
	name="${1}${2}"           ;((${#name}<320)) || return
	name="${name##*([$IFS])}" ;[[ $name = [/!]* ]] || return
	name="${name##?([/!])*([$IFS])}"

	case "${name}" in
		#list hist files: /list
		list*)
			_cmdmsgf 'Session' 'list files'
			session_listf "${name##list*([$IFS])}"
			__read_charf >/dev/null </dev/tty ;return
			;;
		#fork current session to [dest_hist]: /fork
		fork*|f\ *)
			_cmdmsgf 'Session' 'fork'
			optsession=4 ;set -- "$*"
			set -- "${1##*([/!])@(fork|f)*([$IFS])}"
			set -- current "${1/\~\//"$HOME"\/}"
			;;
		#search for and copy session to tail: /sub [regex]
		sub*) 	set -- current current
			REGEX="${name##sub*([$IFS])}" optsession=3
			unset name
			;;
		#copy session from hist option: /copy
		copy*|c\ *)
			_cmdmsgf 'Session' 'copy'
			optsession=3
			set -- "${1##*([/!])@(copy|c)*([$IFS])}" "${@:2}" #two args
			set -- "${@/\~\//"$HOME"\/}"
			;;
		#change to, or create a hist file session
		#break session: //
		[/!]*) 	if [[ "$name" != /[!/]*/* ]] || [[ "$name" = [/!]/*/* ]]
			then 	optsession=2 break=1
				name="${name##[/!]}"
			fi;;
	esac

	name="${name##@(session|sub|[Ss])*([$IFS])}"
	name="${name/\~\//"$HOME"\/}"

	#del unused positional args
	args=("$@") ;set --
	for arg in "${args[@]}"
	do 	[[ ${arg} != *([$IFS]) ]] && set -- "$@" "$arg"
	done

	#print hist option
	if ((OPTHH))
	then 	session_sub_fifof "$name"
		return
	#copy/fork session to destination
	elif ((optsession>2))
	then
		session_copyf "$@" >/dev/null || unset file
	#change to hist file
	else
		#set source session file
		if [[ -f $name ]]
		then 	file="$name"
		elif [[ $name = */* ]] ||
			! file=$(session_globf "$name")
		then
			file=$(session_name_choosef "${name}")
		fi

		if [[ $file = [Cc]urrent || "$file" = . ]]
		then 	file="${FILECHAT}"
		elif [[ $file = [Aa]bort ]]
		then 	return 2
		fi
		[[ -f "$file" ]] && msg=change || msg=create
		_cmdmsgf 'Session' "$msg ${break:+ + session break}"

		#break session?
		((!MTURN && OPTRESUME)) || {
		  [[ -f "$file" ]] &&
		    if ((break))  || {
		    	_sysmsgf 'Break session?' '[N/ys] ' ''
		    	case "$(__read_charf)" in [YySs]|$'\e') 	:;; *) 	false ;;esac
		    }
		    then 	FILECHAT="$file" cmd_runf /break
		    else 	#print snippet of tail session
		    	((break)) || OPTPRINT=1 session_sub_printf "${file:-$FILECHAT}" >/dev/null
		    fi
		}
	fi

	[[ ${file:-$FILECHAT} = "${FILECHAT}" ]] || _sysmsgf 'Changed to:' "${file:-$FILECHAT}"
	FILECHAT="${file:-$FILECHAT}"
}
function session_sub_fifof
{
	if [[ -f "$*" ]]
	then 	FILECHAT_OLD="$*"
		session_sub_printf "${*}"
	else 	FILECHAT_OLD="$(session_globf "${*:-*}")" &&
		session_sub_printf "$FILECHAT_OLD"
	fi  >"$FILEFIFO"
	FILECHAT="$FILEFIFO"
}


#parse opts
OPTMM=  #!#fix <=248c483
optstring="a:A:b:B:cCdeEfFgGhHikK:lL:m:M:n:N:p:qr:R:s:S:t:TouUvVxwWyYzZ0123456789@:/,:.:-:"
while getopts "$optstring" opt
do
	if [[ $opt = - ]]  #long options
	then 	for opt in   @:alpha  M:max-tokens  M:max \
			N:mod-max     N:modmax \
			a:presence-penalty      a:presence   a:pre \
			A:frequency-penalty     A:frequency  A:freq \
			b:best-of   b:best      B:logprobs   c:chat \
			C:resume    C:continue  C:cont       d:text \
			e:edit      E:exit      f:no-conf  h:help \
			H:hist      i:image     'j:synthesi[sz]e'  j:synth \
			'J:synthesi[sz]e-voice' J:synth-voice  'k:no-colo*' \
			K:api-key   l:list-model   l:list-models \
			L:log       m:model        m:mod \
			n:results   o:clipboard    o:clip  p:top-p \
			p:top  q:insert  r:restart-sequence  r:restart \
			R:start-sequence           R:start \
			s:stop      S:instruction  t:temperature \
			t:temp      T:tiktoken   u:multiline  u:multi  U:cat \
			v:verbose   x:editor     X:media  w:transcribe  W:translate \
			y:tik  Y:no-tik  z:last  g:stream  G:no-stream  #opt:long_name
		do
			name="${opt##*:}"  name="${name/[_-]/[_-]}"
			opt="${opt%%:*}"
			case "$OPTARG" in $name*) 	break;; esac
		done

		case "$OPTARG" in
			$name|$name=)
				if [[ $optstring = *"$opt":* ]]
				then 	OPTARG="${@:$OPTIND:1}"
					OPTIND=$((OPTIND+1))
				fi;;
			$name=*)
				OPTARG="${OPTARG##$name=}"
				;;
			[0-9]*)  #max resp tkns option
				OPTARG="$OPTMM-$OPTARG" opt=M
				;;
			*) 	__warmsgf "Unkown option:" "--$OPTARG"
				exit 2;;
		esac ;unset name
	fi
	fix_dotf OPTARG

	case "$opt" in
		@) 	OPT_AT="$OPTARG"  #colour name/spec
			if [[ $OPTARG = *%* ]]  #fuzz percentage
			then 	if [[ $OPTARG = *% ]]
				then 	OPT_AT_PC="${OPTARG##${OPTARG%%??%}}"
					OPT_AT_PC="${OPT_AT_PC:-${OPTARG##${OPTARG%%?%}}}"
					OPT_AT_PC="${OPT_AT_PC//[!0-9]}"
					OPT_AT="${OPT_AT%%"$OPT_AT_PC%"}"
				else 	OPT_AT_PC="${OPTARG%%%*}"
					OPT_AT="${OPT_AT##*%}"
					OPT_AT="${OPT_AT##"$OPT_AT_PC%"}"
				fi ;OPT_AT_PC="${OPT_AT_PC##0}"
			fi;;
		[0-9/-]) 	OPTMM="$OPTMM$opt";;
		M) 	OPTMM="$OPTARG";;
		N) 	[[ $OPTARG = *[!0-9]* ]] && OPTMM="$OPTARG" || OPTNN="$OPTARG";;
		a) 	OPTA="$OPTARG";;
		A) 	OPTAA="$OPTARG";;
		b) 	OPTB="$OPTARG";;
		B) 	OPTBB="$OPTARG";;
		c) 	((++OPTC));;
		C) 	((++OPTRESUME));;
		d) 	OPTCMPL=1;;
		e) 	OPTE=1 EPN=2;;
		E) 	OPTEXIT=1;;
		f$OPTF) unset EPN MOD MOD_CHAT MOD_EDIT MOD_AUDIO MODMAX INSTRUCTION OPTC OPTE OPTI OPTLOG USRLOG OPTRESUME OPTCMPL MTURN OPTTIKTOKEN OPTTIK OPTYY OPTFF OPTK OPTHH OPTL OPTMARG OPTMM OPTNN OPTMAX OPTA OPTAA OPTB OPTBB OPTN OPTP OPTT OPTV OPTVV OPTW OPTWW OPTZ OPTZZ OPTSTOP OPTCLIP CATPR OPTCTRD OPT_AT_PC OPT_AT Q_TYPE A_TYPE RESTART START STOPS OPTSUFFIX SUFFIX CHATGPTRC CONFFILE REC_CMD STREAM OPTEXIT APIURL APIURLBASE GPTCHATKEY
			unset RED BRED YELLOW BYELLOW PURPLE BPURPLE ON_PURPLE CYAN BCYAN WHITE BWHITE INV NC VCOL
			unset Color1 Color2 Color3 Color4 Color5 Color6 Color7 Color8 Color9 Color10 Color11 Color200 Inv Nc Vcol8 Vcol9
			OPTF=1 OPTIND=1 OPTARG= ;. "$0" "$@" ;exit;;
		F) 	((++OPTFF));;
		g) 	STREAM=1;;
		G) 	unset STREAM;;
		h) 	while read
			do 	[[ $REPLY = \#\ v* ]] && break
			done <"$0"
			printf '%s\n' "$REPLY" "$HELP"
			exit;;
		H) 	((++OPTHH));;
		i) 	OPTI=1 EPN=3 MOD=image;;
		l) 	((++OPTL));;
		L) 	OPTLOG=1
			if [[ -d "$OPTARG" ]]
			then 	USRLOG="${OPTARG%%/}/${USRLOG##*/}"
			else 	USRLOG="${OPTARG:-${USRLOG}}"
			fi
			[[ "$USRLOG" = '~'* ]] && USRLOG="${HOME}${USRLOG##\~}"
			_cmdmsgf 'Log file' "<${USRLOG}>";;
		m) 	OPTMARG="${OPTARG:-$MOD}" MOD="$OPTMARG";;
		n) 	OPTN="$OPTARG" ;;
		k) 	OPTK=1;;
		K) 	OPENAI_API_KEY="$OPTARG";;
		o) 	OPTCLIP=1;;
		p) 	OPTP="$OPTARG";;
		q) 	OPTSUFFIX=1;;
		r) 	RESTART="$OPTARG";;
		R) 	START="$OPTARG";;
		s) 	((${#STOPS[@]})) && STOPS=("$OPTARG" "${STOPS[@]}") \
			|| STOPS=("$OPTARG");;
		S|.|,) 	if [[ -f "$OPTARG" ]]
			then 	INSTRUCTION="${opt##S}$(<"$OPTARG")"
			else 	INSTRUCTION="${opt##S}$OPTARG"
			fi;;
		t) 	OPTT="$OPTARG";;
		T) 	((++OPTTIKTOKEN));;
		u) 	((OPTCTRD)) && unset OPTCTRD || OPTCTRD=1
			[[ -n $ZSH_VERSION ]] ||
			__cmdmsgf 'Prompter <CTRL-D>' $(_onoff $OPTCTRD);;
		U) 	CATPR=1;;
		v) 	((++OPTV));;
		V) 	((++OPTVV));;  #debug
		x) 	OPTX=1;;
		w) 	((++OPTW));;
		W) 	((OPTW)) || OPTW=1 ;((++OPTWW));;
		y) 	OPTTIK=1;;
		Y) 	OPTTIK= OPTYY=1;;
		z) 	OPTZ=1;;
		#run script with interactive zsh
		Z) 	((++OPTZZ))
			if [[ -z $ZSH_VERSION ]]
			then 	unset BASH_VERSION
				exec zsh -if -- "$0" "$@"; exit;
			fi;;
		\?) 	exit 1;;
	esac ;OPTARG=
done
shift $((OPTIND -1))
unset LANGW MTURN MAIN_LOOP SKIP EDIT INDEX HERR BAD_RES REPLY REGEX SGLOB init buff var n s

[[ -t 1 ]] || OPTK=1 ;((OPTK)) || {
  #map colours
  : "${RED:=${Color1:=${Red}}}"       "${BRED:=${Color2:=${BRed}}}"
  : "${YELLOW:=${Color3:=${Yellow}}}" "${BYELLOW:=${Color4:=${BYellow}}}"
  : "${PURPLE:=${Color5:=${Purple}}}" "${BPURPLE:=${Color6:=${BPurple}}}" "${ON_PURPLE:=${Color7:=${On_Purple}}}"
  : "${CYAN:=${Color8:=${Cyan}}}"     "${BCYAN:=${Color9:=${BCyan}}}"
  : "${WHITE:=${Color10:=${White}}}"  "${BWHITE:=${Color11:=${BWhite}}}"
  : "${INV:=${Inv}}" "${NC:=${Nc}}" "${Vcol8:=%F{14}}" "${VCOL:=${Vcol9:=%B%F{14}}}" #zsh vared
  JQCOL="\
  def red:     \"${RED//\\e/\\u001b}\";     \
  def yellow:  \"${YELLOW//\\e/\\u001b}\";  \
  def byellow: \"${BYELLOW//\\e/\\u001b}\"; \
  def bpurple: \"${BPURPLE//\\e/\\u001b}\"; \
  def reset:   \"${NC//\\e/\\u001b}\";"
}
JQCOLNULL="\
def red:     null; \
def yellow:  null; \
def byellow: null; \
def bpurple: null; \
def reset:   null;"

OPENAI_API_KEY="${OPENAI_API_KEY:-${OPENAI_KEY:-${GPTCHATKEY:-${OPENAI_API_KEY:?Required}}}}"
((OPTL+OPTZ)) && unset OPTX
((OPTE+OPTI)) && unset OPTC
((OPTCLIP)) && set_clipcmdf
((OPTC)) || OPTT="${OPTT:-0}"  #!#temp *must* be set
((OPTCMPL)) && unset OPTC  #opt -d
((!OPTC)) && ((OPTRESUME>1)) && OPTCMPL=${OPTCMPL:-$OPTRESUME}  #1# txt cmpls cont
((OPTCMPL)) && ((!OPTRESUME)) && OPTCMPL=2  #2# txt cmpls new
((OPTC+OPTCMPL || OPTRESUME>1)) && MTURN=1  #multi-turn, interactive
((OPTI+OPTE+OPTEMBED)) && ((OPTVV)) && OPTVV=2
((OPTCTRD)) || unset OPTCTRD  #(un)set <ctrl-d> prompter flush [bash]

if ((OPTI+OPTII))
then 	command -v base64 >/dev/null 2>&1 || OPTI_FMT=url
	if set_sizef "$1"
	then 	shift
	elif set_sizef "$OPTS"
	then 	: ;fi
	[[ -e $1 ]] && OPTII=1  #img edits and vars
	unset STREAM
fi

#map models
[[ -n $OPTMARG ]] ||
if ((OPTE))      #edits
then 	MOD="$MOD_EDIT" STREAM=
elif ((OPTC>1))  #chat
then 	MOD="$MOD_CHAT"
elif ((OPTW)) && ((!MTURN))  #audio endpoint only
then 	MOD="$MOD_AUDIO"
fi

[[ -n $EPN ]] || set_model_epnf "$MOD"
[[ ${INSTRUCTION} != *([$IFS]) ]] || unset INSTRUCTION

#auto set ``model capacity''
((MODMAX)) ||
case "$MOD" in  #set model max tokens
	davinci-002|babbage-002) 	MODMAX=16384;;
	davinci|curie|babbage|ada) 	MODMAX=2049;;
	code-davinci-00[2-9]) MODMAX=8001;;
	gpt-4*32k*) 	MODMAX=32768;;
	gpt-4*) 	MODMAX=8192;;
	*turbo*16k*) 	MODMAX=16384;;
	*turbo*|*davinci*) 	MODMAX=4096;;
	*) 	MODMAX=2048;;
esac

#set ``max model / response tkns''
[[ -n $OPTNN && -z $OPTMM ]] ||
set_maxtknf "${OPTMM:-$OPTMAX}"
[[ -n $OPTNN ]] && MODMAX="$OPTNN"

#set other options
set_optsf
APIURL=${APIURL%%/}
if [[ $APIURL != "$APIURLBASE"* ]]  #custom api url and endpoint
then 	if [[ $APIURL = *[!:/]/[!/]* ]]
	then 	ENDPOINTS=("${APIURL##*/}") APIURL="${APIURL%/*}" EPN=0
	else 	unset ENDPOINTS
	fi; function set_model_epnf { 	: ;}  #disable auto endpoint fun
	__sysmsgf "API URL / endpoint:" "$APIURL/${ENDPOINTS[EPN]}"
fi

#load stdin
if [[ -n $TERMUX_VERSION ]]
then 	STDIN='/proc/self/fd/0' STDERR='/proc/self/fd/2'
else 	STDIN='/dev/stdin'      STDERR='/dev/stderr'
fi
((${#})) || [[ -t 0 ]] || ((OPTTIKTOKEN+OPTL+OPTZ)) || set -- "$(<$STDIN)"

((OPTX)) && ((OPTE+OPTEMBED+OPTI+OPTII+OPTTIKTOKEN)) &&
edf "$@" && set -- "$(<"$FILETXT")"  #editor

if ((!(OPTI+OPTII+OPTL+OPTW+OPTZ+OPTTIKTOKEN) )) && [[ $MOD != *moderation* ]]
then 	if ((!OPTHH))
	then 	__sysmsgf "Max Model / Response:" "$MODMAX / $OPTMAX tokens"
     		if ((${#})) && [[ ! -f $1 ]]
		then 	token_prevf "${INSTRUCTION}${INSTRUCTION:+ }${*}"
			__sysmsgf "Prompt:" "~$TKN_PREV tokens"
		fi
	elif ((OPTHH>1))
	then 	__sysmsgf 'Language Model:' "$MOD"
	fi
fi

((OPTW+OPTII+OPTI+OPTEMBED+OPTE)) &&
for arg  #!# escape input
do 	((init++)) || set --
	set -- "$@" "$(escapef "$arg")"
done ;unset arg init

mkdir -p "$CACHEDIR" || exit
if ! command -v jq >/dev/null 2>&1
then 	function jq { 	false ;}
	function escapef { 	_escapef "$@" ;}
	function unescapef { 	_unescapef "$@" ;}
fi
command -v tac >/dev/null 2>&1 || function tac { 	tail -r "$@" ;}  #bsd

if ((OPTHH))  #edit history/pretty print last session
then
	[[ $INSTRUCTION = [.,]* ]] && custom_prf
	((${#})) && session_mainf "/${1##/}" "${@:2}"
	_sysmsgf "Hist   File:" "${FILECHAT_OLD:-$FILECHAT}"
	if ((OPTHH>1))
	then 	((OPTHH>2)) && OPTHH=3000
		((OPTC || EPN==6)) && OPTC=2
		((OPTC+OPTRESUME+OPTCMPL)) || OPTC=1
		Q_TYPE="\\n${Q_TYPE}" A_TYPE="\\n${A_TYPE}" \
		MODMAX=65536 set_histf ''
		usr_logf "$(unescapef "$HIST")"
		[[ ! -e $FILEFIFO ]] || rm -- "$FILEFIFO"
	elif [[ -t 1 ]]
	then 	__edf "$FILECHAT"
	else 	cat -- "$FILECHAT"
	fi
elif ((OPTFF))
then 	if [[ -s "$CONFFILE" ]] && ((OPTFF<2))
	then 	__edf "$CONFFILE"
	else 	curl -Lf "https://gitlab.com/fenixdragao/shellchatgpt/-/raw/main/.chatgpt.conf"
		CONFFILE=stdout
	fi; _sysmsgf 'Conf File:' "$CONFFILE"
elif ((OPTZ))      #last response json
then 	lastjsonf
elif ((OPTL))      #model list
then 	list_modelsf "$@"
elif ((OPTTIKTOKEN))
then 	((OPTYY)) && { 	if [[ -f $* ]]; then 	__tiktokenf "$(<"$*")"; elif [[ ! -t 0 ]]; then 	__tiktokenf "$(cat)"; else 	__tiktokenf "$*"; fi; exit ;}  #mainly for debugging, option -Y
	((OPTTIKTOKEN>2)) || __sysmsgf 'Language Model:' "$MOD"
	((${#})) || [[ -t 0 ]] || set -- "-"
	[[ -f $* ]] && [[ -t 0 ]] && exec 0< "$*" && set -- "-"
	tiktokenf "$*" || ! __warmsgf \
	  "Err:" "Make sure python tiktoken module is installed: \`pip install tiktoken\`"
elif ((OPTW)) && ((!MTURN))  #audio transcribe/translation
then 	whisperf "$@"
elif ((OPTII))     #image variations/edits
then 	if ((${#}>1))
	then 	__sysmsgf 'Image Edits'
	else 	__sysmsgf 'Image Variations' ;fi
	imgvarf "$@"
elif ((OPTI))      #image generations
then 	__sysmsgf 'Image Generations'
	imggenf "$@"
elif ((OPTEMBED))  #embeds
then 	[[ $MOD = *embed* ]] || [[ $MOD = *moderation* ]] \
	|| __warmsgf "Warning:" "Not an embedding model -- $MOD"
	unset Q_TYPE A_TYPE OPTC OPTCMPL STREAM
	[[ -f $1 ]] && set -- "$(<"$1")" "${@:2}"
	((${#})) ||
	if echo Input:; [[ -n $ZSH_VERSION ]]
	then 	IFS= vared -c -e -h REPLY; set -- "$REPLY"; echo >&2;
	else 	IFS= read -r -e ${OPTCTRD:+-d $'\04'} REPLY; set -- "$REPLY"; echo >&2;
	fi </dev/tty
	if [[ $MOD = *embed* ]]
	then 	embedf "$@"
	else 	moderationf "$@" &&
		printf '%-22s: %s\n' flagged $(lastjsonf | jq -r '.results[].flagged') &&
		printf '%-22s: %.24f (%s)\n' $(lastjsonf | jq -r '.results[].categories|keys_unsorted[]' | while read -r; do 	lastjsonf | jq -r "\"$REPLY \" + (.results[].category_scores.\"$REPLY\"|tostring//empty) + \" \" + (.results[].categories.\"$REPLY\"|tostring//empty)"; done)
	fi
elif ((OPTE))      #edits
then 	__sysmsgf 'Text Edits'
	[[ $MOD = *edit* ]] || __warmsgf "Warning:" "Not an edits model -- $MOD"
	[[ -f $1 ]] && set -- "$(<"$1")" "${@:2}"
	[[ -f $2 ]] && set -- "$1" "$(<"$2")" "${@:3}"
	if ((${#INSTRUCTION}))
	then 	set -- "$INSTRUCTION" "$@"
	else 	INSTRUCTION="$1"
	fi ;__sysmsgf 'INSTRUCTION:' "${INSTRUCTION:-(EMPTY)}"
	: "${1:?INSTRUCTION ERR}" "${2:?INPUT ERR}"  ;echo >&2
	editf "$@"
else
	#custom / awesome prompts
	if [[ $INSTRUCTION = [/%.,]* ]] && ((!OPTW))
	then 	if [[ $INSTRUCTION = [/%]* ]]
		then 	OPTAWE=1 ;((OPTC)) || OPTC=1 OPTCMPL=
			awesomef || exit
			_sysmsgf 'Hist   File:' "${FILECHAT}"
		else 	custom_prf "$@"
			case $? in
				200) 	set -- ;;
				[1-9]*) exit $? ;;
			esac
		fi
	fi

	#text/chat completions
	[[ -f $1 ]] && set -- "$(<"$1")" "${@:2}"  #load file (1st arg)
	((OPTW)) && { 	INPUT_ORIG=("$@") ;unset OPTX ;set -- ;}  #whisper input
	if ((OPTC))
	then 	__sysmsgf 'Chat Completions'
		#chatbot must sound like a human, shouldnt be lobotomised
		#presencePenalty:0.6 temp:0.9 maxTkns:150
		#frequencyPenalty:0.5 temp:0.5 top_p:0.3 maxTkns:60 :Marv is a chatbot that reluctantly answers questions with sarcastic responses:
		OPTA="${OPTA:-0.4}" OPTT="${OPTT:-0.6}"  #!#
		STOPS+=("${Q_TYPE//$SPC1}" "${A_TYPE//$SPC1}")
	else 	((EPN==6)) || __sysmsgf 'Text Completions'
	fi
	__sysmsgf 'Language Model:' "$MOD"

	restart_compf ;start_compf
	function unescape_stopsf
	{   typeset s
	    for s in "${STOPS[@]}"
	    do    set -- "$@" "$(unescapef "$s")"
	    done ;STOPS=("$@")
	} ;((${#STOPS[@]})) && unescape_stopsf

	#session cmds
	[[ $* = *([$IFS])/* ]] && [[ ! -f "$1" ]] \
	&& session_mainf "$@" && set --

	#model instruction
	INSTRUCTION_OLD="$INSTRUCTION"
	if ((MTURN+OPTRESUME))
	then 	INSTRUCTION=$(trim_leadf "$INSTRUCTION" "$SPC:$SPC")
		shell_histf "$INSTRUCTION"
		if ((OPTC && OPTRESUME)) || ((OPTCMPL==1 || OPTRESUME==1))
		then 	:
		else 	break_sessionf
			((OPTC)) && INSTRUCTION="${INSTRUCTION:-$INSTRUCTION_CHAT}"
			if [[ ${INSTRUCTION} != ?(:)*([$IFS]) ]]
			then 	push_tohistf "$(escapef ":${INSTRUCTION}")"
				_sysmsgf 'INSTRUCTION:' "${INSTRUCTION}" 2>&1 | foldf >&2
			fi
		fi
		INSTRUCTION_OLD="$INSTRUCTION"
		unset INSTRUCTION
	elif [[ ${INSTRUCTION} = ?(:)*([$IFS]) ]]
	then 	unset INSTRUCTION
	fi
	[[ ${INSTRUCTION} != ?(:)*([$IFS]) ]] && _sysmsgf 'INSTRUCTION:' "${INSTRUCTION}" 2>&1 | foldf >&2

	# fix: bash: enable multiline cmd history  v0.18.0 aug/23
	if ((OPTC+OPTCMPL+OPTRESUME)) && [[ -n $BASH_VERSION ]] && ((!DISABLE_BASH_FIX)) \
		&& [[ $(sed -n 1p -- "$HISTFILE" 2>/dev/null )\#10 != \#[0-9]* ]]
	then 	(echo >&2; set -xv; sed -i -e 's/^/#10\n/' "$HISTFILE")
	fi

	((OPTCTRD)) && {    echo >&2  #warnings and tips
	    [[ -n $ZSH_VERSION ]] &&
	    __warmsgf 'TIP:' '* <ALT-ENTER> for newline * '
	    __warmsgf 'TIP:' '* <CTRL-V> + <CTRL-J> for newline * '
	} || {    ((CATPR)) && echo >&2 ;}
	((OPTCTRD+CATPR)) &&
	    __warmsgf 'TIP:' '* <CTRL-D> to flush input * '
	echo >&2  #!#

	if ((MTURN))  #chat mode (multi-turn, interactive)
	then 	if [[ -n $ZSH_VERSION ]]
		then 	if [[ -o interactive ]] && ((OPTZZ<2))
			then 	setopt HIST_FIND_NO_DUPS HIST_IGNORE_ALL_DUPS HIST_SAVE_NO_DUPS #EXTENDED_HISTORY
				fc -RI
			else 	#load history manually
				EPN= OPTV= OPTC= RESTART= START= OPTTIK= \
				MODMAX=8192 OPTZZHIST=1 N_MAX=40 set_histf
				while IFS= read -r
				do 	[[ ${REPLY} = *([$IFS]) ]] && continue
					print -s -- "$(unescapef "$REPLY")"
				done <<<"$HIST" ;unset HIST REPLY
			fi
		else 	history -c; history -r;  #set -o history;
		fi
	  	[[ -s $HISTFILE ]] &&
		REPLY_OLD=$(trim_leadf "$(fc -ln -1 | cut -c1-1000)" "*([$IFS])")
		shell_histf "$*"
	fi
	cmd_runf "$*" && set --

	#load stdin again?
	((${#})) || [[ -t 0 ]] || set -- "$(<$STDIN)"

	WSKIP=1
	while :
	do 	((REGEN)) && { 	set -- "${REPLY_OLD:-$*}" ;unset REGEN ;}
		((OPTAWE)) || {  #awesome 1st pass skip

		#prompter pass-through
		if ((PSKIP)) && [[ -z $* ]] && [[ -n $REPLY ]]
		then 	set -- "$REPLY"
		#text editor prompter
		elif ((OPTX))
		then 	edf "${@:-$REPLY}" || case $? in 200) 	continue;; 201) 	break;; esac
			while REPLY="$(<"$FILETXT")"
				printf "${BRED}${REPLY:+${NC}${BCYAN}}%s${NC}\\n" "${REPLY:-(EMPTY)}"
			do 	((OPTV)) || new_prompt_confirmf
				case $? in
					201) 	break 2;;  #abort
					200) 	continue 2;;  #redo
					19[89]) 	edf "${REPLY:-$*}" || break 2;;  #edit
					0) 	set -- "$REPLY" ; break;;  #yes
					*) 	set -- ; break;;  #no
				esac
			done ;((OPTX>1)) && unset OPTX
		fi

		#defaults prompter
		if [[ "$* " = @("${Q_TYPE##$SPC1}"|"${RESTART##$SPC1}")$SPC ]] || [[ "$*" = $SPC ]]
		then 	((OPTC)) && Q="${RESTART:-${Q_TYPE:->}}" || Q="${RESTART:->}"
			B=$(_unescapef "${Q:0:320}") B=${B##*$'\n'} B=${B//?/\\b}  #backspaces

			while ((SKIP)) ||
				printf "${CYAN}${Q}${B}${NC}${OPTW:+${PURPLE}VOICE:}${NC}" >&2
				printf "${BCYAN}${OPTW:+${NC}${BPURPLE}}" >&2
			do
				{ 	((SKIP+OPTW)) || [[ -n $ZSH_VERSION ]] ;} && echo >&2
				if ((OPTW)) && ((!EDIT))
				then 	#auto sleep 3-6 words/sec
					((OPTV>1)) && ((!WSKIP)) && __read_charf -t $((SLEEP_WORDS/3))

					record_confirmf || continue
					if recordf "$FILEINW"
					then 	REPLY=$(
						MOD="$MOD_AUDIO" OPTT=0 JQCOL= JQCOL2=
						set_model_epnf "$MOD"
						whisperf "$FILEINW" "${INPUT_ORIG[@]}"
					)
					else 	unset OPTW
					fi ;printf "\\n${NC}${BPURPLE}%s${NC}\\n" "${REPLY:-"(EMPTY)"}" >&2
				else
					if ((OPTCMPL)) && ((MAIN_LOOP || OPTCMPL==1)) \
						&& ((EPN!=6)) && [[ -z "${RESTART}${REPLY}" ]]
					then 	REPLY=" " EDIT=1  #txt cmpls: start with space?
					fi;
					((EDIT)) || unset REPLY  #!#

					if ((CATPR)) && ((!EDIT))
					then
						REPLY=$(cat)
					elif [[ -n $ZSH_VERSION ]]
					then
						((OPTK)) && var= || var="-p${VCOL}"
						IFS= vared -c -e -h ${var} REPLY
					else
						[[ $REPLY != *$'\n'* ]] || ((OPTCTRD)) || {
						  OPTCTRD=2; __cmdmsgf 'Prompter <CTRL-D>' 'one-shot'; }
						IFS= read -r -e ${OPTCTRD:+-d $'\04'} -i "$REPLY" REPLY
					fi </dev/tty
					((OPTCTRD)) && REPLY=${REPLY%%*($'\r')}
				fi ;printf "${NC}" >&2

				if [[ $REPLY = *\\ ]]
				then 	printf '\n%s\n' '---' >&2
					EDIT=1 SKIP=1; ((OPTCTRD))||OPTCTRD=2
					REPLY="${REPLY%%?(\\)\\}"$'\n'
					set -- ;continue
				elif [[ $REPLY = /cat*([$IFS]) ]]
				then 	((CATPR)) || CATPR=2 ;REPLY= SKIP=1
					set -- ;continue
				elif cmd_runf "$REPLY"
				then 	shell_histf "$REPLY"
					((REGEN)) && REPLY="${REPLY_OLD:-$REPLY}"
					SKIP=1 ;set -- ;continue 2
				elif [[ ${REPLY} = */*([$IFS]) ]] && ((!OPTW)) #preview / regen cmds
				then
					((RETRY)) && prev_tohistf "$REPLY_OLD"  #record previous reply
					[[ $REPLY = /* ]] && REPLY="${REPLY_OLD:-$REPLY}"  #regen cmd integration
					REPLY="${REPLY%/*}" REPLY_OLD="$REPLY"
					RETRY=1 BCYAN="${Color8}" VCOL="${Vcol8}"
				elif [[ -n $REPLY ]]
				then
					((RETRY+OPTV)) || new_prompt_confirmf
					case $? in
						201) 	break 2;;            #abort
						200) 	WSKIP=1 ;continue;;  #redo
						199) 	WSKIP=1 EDIT=1 ;continue;;   #edit
						198) 	((OPTX)) || OPTX=2
							set -- ;continue 2;; #text editor
						0) 	:;;                  #yes
						*) 	unset REPLY; set -- ;break;; #no
					esac

					if ((RETRY))
					then 	if [[ "$REPLY" = "$REPLY_OLD" ]]
						then 	RETRY=2 BCYAN="${Color9}" VCOL="${Vcol9}"
						else 	#record prev resp
							prev_tohistf "$REPLY_OLD"
						fi ;REPLY_OLD="$REPLY"
					fi
				else
					set --
				fi ;set -- "$REPLY"
				((OPTCTRD==1)) || unset OPTCTRD
				unset WSKIP SKIP EDIT B Q i
				break
			done
		fi

		if ((!(OPTCMPL+JUMP) )) && [[ -z "${INSTRUCTION}${*}" ]]
		then 	__warmsgf "(empty)"
			set -- ; continue
		fi
		if ((!OPTCMPL)) && ((OPTC)) && [[ "${*}" != *([$IFS]) ]]
		then 	set -- "$(trimf "$*" "$SPC1")"  #!#
			REPLY="$*"
		fi
		((${#REPLY_OLD})) || REPLY_OLD="${REPLY:-$*}"

		}  #awesome 1st pass skip end

		if ((MTURN+OPTRESUME)) && [[ -n "${*}" ]]
		then
			[[ -n $REPLY ]] || REPLY="${*}" #set buffer for EDIT

			((RETRY==1)) ||
			if shell_histf "$*"
				[[ -n $ZSH_VERSION ]]
			then 	fc -A  #zsh interactive
			else 	history -a
			fi

			#system/instruction?
			if [[ ${*} = $SPC:* ]]
			then 	push_tohistf "$(escapef ":$(trim_leadf "$*" "$SPC:")")"
				((OPTV<3)) &&
				if ((EPN==6))
				then 	_sysmsgf "System message added"  #gpt-3.5+ (chat cmpls)
				else 	_sysmsgf "Text appended"  #davinci and earlier (txt cmpls)
				fi
				INSTRUCTION_OLD="${INSTRUCTION_OLD:-$INSTRUCTION}"
				set -- ;continue
			fi
			REC_OUT="${Q_TYPE##$SPC1}${*}"
		fi

		#insert mode option
		if ((OPTSUFFIX)) && [[ "$*" = *"${I_TYPE}"* ]]
		then 	if ((EPN!=6))
			then 	SUFFIX="${*##*"${I_TYPE}"}"
				set -- "${*%%"${I_TYPE}"*}"
			else 	__warmsgf "Err: insert mode:" "bad endpoint (chat cmpls)"
			fi
		fi

		if ((RETRY<2))
		then 	((MTURN+OPTRESUME)) &&
			if ((EPN==6)); then 	set_histf "${*}"; else 	set_histf "${Q_TYPE}${*}"; fi
			if ((OPTC)) || [[ -n "${RESTART}" ]]
			then 	rest="${RESTART:-$Q_TYPE}"
			fi
			((JUMP)) && set -- && unset rest
			ESC="${HIST}${rest}$(escapef "${*}")"
			ESC="$(escapef "${INSTRUCTION}")${INSTRUCTION:+\\n\\n}${ESC##\\n}"

			if ((EPN==6))
			then 	#chat cmpls
				[[ ${*} = *([$IFS]):* ]] && role=system || role=user
				set -- "$(fmt_ccf "$(escapef "$INSTRUCTION")" system)${INSTRUCTION:+,}${HIST_C}${HIST_C:+,}$(fmt_ccf "$(escapef "$*")" "$role")"
			else 	#text cmpls
				if { 	((OPTC)) || [[ -n "${START}" ]] ;} && ((JUMP<2))
				then 	set -- "${ESC}${START:-$A_TYPE}"
				else 	set -- "${ESC}"
				fi
			fi ;unset rest role
		fi

		set_optsf

		if ((EPN==6))
		then 	BLOCK="\"messages\": [${*%,}],"
		else 	BLOCK="\"prompt\": \"${*}\","
		fi
		BLOCK="{ $BLOCK $OPTSUFFIX_OPT
			\"model\": \"$MOD\", $STREAM_OPT
			\"temperature\": $OPTT, $OPTA_OPT $OPTAA_OPT $OPTP_OPT
			\"max_tokens\": $OPTMAX, $OPTB_OPT $OPTBB_OPT $OPTSTOP
			\"n\": $OPTN
		}" #max_tokens is optional for ChatCompletion requests

		#response colours for jq
		if ((RETRY==1))
		then 	((OPTK)) || JQCOL2='def byellow: yellow;'
		else 	unset JQCOL2
		fi ;((OPTC)) && echo >&2

		#request and response prompts
		promptf  ;ret=$?
		((STREAM)) && ((MTURN || EPN==6)) && echo >&2
		((ret>160 || RETRY==1)) && { 	SKIP=1 EDIT=1 ;set -- ;continue ;}
		REPLY_OLD="${REPLY:-$*}"

		#record to hist file
		if 	if ((STREAM))  #no token information in response
			then 	ans=$(prompt_pf -r -j "$FILE"; echo x) ans=${ans%%x}  #unescaped
				ans=$(escapef "$ans")
				tkn_ans=$( ((EPN==6)) && unset A_TYPE;
					__tiktokenf "${A_TYPE}${ans}");
				((tkn_ans+=TKN_ADJ)); ((MAX_PREV+=tkn_ans)); unset TOTAL_OLD;
			else 	tkn=($(jq -r '.usage.prompt_tokens//"0",
					.usage.completion_tokens//"0",
					(.created//empty|strflocaltime("%Y-%m-%dT%H:%M:%S%Z"))' "$FILE") )
				unset ans buff n
				for ((n=0;n<OPTN;n++))  #multiple responses
				do 	buff=$(INDEX=$n prompt_pf "$FILE")
					buff="${buff##[\"]}" buff="${buff%%[\"]}"
					ans="${ans}"${ans:+${buff:+\\n---\\n}}"${buff}"
				done
			fi

			if [[ -z "$ans" ]]
			then 	jq 'if .error then . else empty end' "$FILE" >&2 || cat -- "$FILE" >&2
				__warmsgf "(response empty)"
				if ((HERR<=${HERR_DEF:=1}*5)) && ((MTURN+OPTRESUME)) \
					&& var=$(jq .error.message//empty "$FILE") \
					&& [[ $var = *[Cc]ontext\ length*[Rr]educe* ]]
				then 	#[0]modmax [1]resquested [2]prompt [3]cmpl
					var=(${var//[!0-9$IFS]})
					if ((${#var[@]}<2 || var[1]<=(var[0]*3)/2)) \
					    && [[ "${*:-$REPLY}" != "$ADJ_INPUT" ]]
					then   ADJ_INPUT="${*:-$REPLY}"
					  ((HERR+=HERR_DEF*2)) ;BAD_RES=1 PSKIP=1; set --
					  __warmsgf "Adjusting context:" -$((HERR_DEF+HERR))%
					 ((!OPTTIK)) && ((HERR<HERR_DEF*4)) && _sysmsgf 'TIP:' "Set \`option -y' to use Tiktoken!"
					  sleep $(( (HERR/HERR_DEF)+1)) ;continue
					fi
				fi
			fi ;unset BAD_RES PSKIP
			((${#tkn[@]}>2||STREAM)) && ((${#ans})) && ((MTURN+OPTRESUME))
		then
			if CKSUM=$(cksumf "$FILECHAT") ;[[ $CKSUM != "${CKSUM_OLD:-$CKSUM}" ]]
			then 	Color200=${NC} __warmsgf \
				'Err: History file modified'$'\n' 'Fork session? [Y]es/[n]o/[i]gnore all ' ''
				case "$(__read_charf ;echo >&2)" in
					[IiGg]) 	unset CKSUM CKSUM_OLD ;function cksumf { 	: ;};;
					[QqNnAa]|$'\e') :;;
					*) 		session_mainf /copy "$FILECHAT" || break;;
				esac
			fi
			if ((OPTB>1))  #best_of disables streaming response
			then 	start_tiktokenf
				tkn[1]=$( ((EPN==6)) && unset A_TYPE;
					__tiktokenf "${A_TYPE}${ans}");
			fi
			ans="${A_TYPE##$SPC1}${ans}"
			((OPTAWE)) ||
			push_tohistf "$(escapef "$REC_OUT")" "$(( (tkn[0]-TOTAL_OLD)>0 ? (tkn[0]-TOTAL_OLD) : TKN_PREV ))" "${tkn[2]}"
			push_tohistf "$ans" "${tkn[1]:-$tkn_ans}" "${tkn[2]}" || unset OPTC OPTRESUME OPTCMPL MTURN
			((TOTAL_OLD=tkn[0]+tkn[1])) && MAX_PREV=$TOTAL_OLD
			CKSUM_OLD=$(cksumf "$FILECHAT") ;unset HIST_TIME ADJ_INPUT
		elif ((MTURN))
		then 	BAD_RES=1 SKIP=1 EDIT=1 CKSUM_OLD= PSKIP= JUMP=
			((OPTX)) && __read_charf >/dev/null
			set -- ;continue
		fi
		((OPTW)) && { 	SLEEP_WORDS=$(wc -w <<<"${ans}") ;((STREAM)) && ((SLEEP_WORDS=(SLEEP_WORDS*2)/3)) ;((++SLEEP_WORDS)) ;}
		((OPTLOG)) && (usr_logf "$(unescapef "${ESC}\\n${ans}")" > "$USRLOG" &)

		((++MAIN_LOOP)) ;set --
		unset INSTRUCTION TKN_PREV REC_OUT HIST HIST_C SKIP PSKIP WSKIP JUMP EDIT REPLY STREAM_OPT OPTA_OPT OPTAA_OPT OPTP_OPT OPTB_OPT OPTBB_OPT OPTSUFFIX_OPT SUFFIX OPTAWE RETRY BAD_RES ESC Q
		unset role rest tkn tkn_ans ans buff glob out var ret s n
		((MTURN && !OPTEXIT)) || break
	done
fi

# Notes:
# - Debug command performance by line in Bash:
#   set -x; shopt -s extdebug; PS4='$EPOCHREALTIME:$LINENO: '
# - <https://help.openai.com/en/articles/6654000>

# GPT-4 Image Upload
# Gpt-4 model only. .png, .jpeg, .jpg, and non-animated .gif.
# May upload multiple images at once, max 20MB per image.
#<https://help.openai.com/en/articles/8400551>
# Voice-Out Limits and Formats: Juniper, Sky, Cove, Ember, Breeze.
#<https://help.openai.com/en/articles/8400625>

# vim=syntax sync minlines=3200
