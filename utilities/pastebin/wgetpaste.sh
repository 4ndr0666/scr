#!/usr/bin/env bash
# shellcheck disable=all
# A Script that automates pasting to a number of pastebin services
# relying only on bash, sed, coreutils (mktemp/sort/tr/wc/whoami/tee) and wget
# Copyright (c) 2007-2009 Bo Ørsted Andresen <bo.andresen@zlin.dk>
# Distributed in the public domain. Do with it whatever you want.

VERSION="2.20"

# don't inherit LANGUAGE from the env
unset LANGUAGE

# escape and new line characters
E=$'\e'
N=$'\n'

### services
SERVICES="ca codepad dpaste gists poundpython"
# ca
ENGINE_ca=ca
URL_ca="http://pastebin.ca/"
SIZE_ca="1024000 1%MB"
# codepad
ENGINE_codepad=codepad
URL_codepad="http://codepad.org/"
SIZE_codepad="64000 64%KB"
# dpaste
ENGINE_dpaste=dpaste
URL_dpaste="http://dpaste.com/"
SIZE_dpaste="25000 25%kB"
DESCRIPTION_SIZE_dpaste="50"
DEFAULT_EXPIRATION_dpaste="30 days"
# gists
ENGINE_gists=gists
URL_gists="https://api.github.com/gists"
# poundpython
ENGINE_poundpython=lodgeit
URL_poundpython="http://paste.pound-python.org/"
# tinyurl
ENGINE_tinyurl=tinyurl
URL_tinyurl="http://tinyurl.com/ api-create.php"
REGEX_RAW_tinyurl='s|^\(http://[^/]*/\)\([[:alnum:]]*\)$|\1\2|'

### engines
# ca
LANGUAGES_ca="Plain%Text Asterisk%Configuration C C++ PHP Perl Java VB C# Ruby Python Pascal \
mIRC PL/I XML SQL Scheme ActionScript Ada Apache%Configuration Assembly%(NASM) ASP Bash CSS \
Delphi HTML%4.0%Strict JavaScript LISP Lua Microprocessor%ASM Objective%C VB.NET"
LANGUAGE_COUNT_ca=0
EXPIRATIONS_ca="Never 5%minutes 10%minutes 15%minutes 30%minutes 45%minutes 1%hour 2%hours \
4%hours 8%hours 12%hours 1%day 2%days 3%days 1%week 2%weeks 3%weeks 1%month 2%months \
3%months 4%months 5%months 6%months 1%year"
POST_ca="s=Submit+Post name description type expiry % content"
REGEX_URL_ca='s|^.*content="[0-9]*;\(http://[^/]*/[0-9]*\)".*$|\1|p'
REGEX_RAW_ca='s|^\(http://[^/]*/\)\([0-9]*\)$|\1raw/\2|'
# codepad
LANGUAGES_codepad="C C++ D Haskell Lua OCaml PHP Perl Plain%Text Python Ruby Scheme Tcl"
POST_codepad="submit % % lang % % code"
REGEX_URL_codepad='s|^--.*\(http://codepad.org/[^ ]\+\)|\1|p'
REGEX_RAW_codepad='s|^\(http://[^/]*/\)\([[:alnum:]]*\)$|\1\2/raw.rb|'
# dpaste
LANGUAGES_dpaste="Plain%Text Apache%Config Bash CSS Diff Django%Template/HTML Haskell JavaScript \
Python Python%Interactive/Traceback Ruby Ruby%HTML%(ERB) SQL XML"
LANGUAGE_VALUES_dpaste="% Apache Bash Css Diff DjangoTemplate Haskell JScript Python PythonConsole \
Ruby Rhtml Sql Xml"
EXPIRATIONS_dpaste="30%days 30%days%after%last%view"
EXPIRATION_VALUES_dpaste="off on"
POST_dpaste="submit=Paste+it poster title language hold % content"
REGEX_RAW_dpaste='s|^\(http://[^/]*/\)[^0-9]*\([0-9]*/\)$|\1\2plain/|'
# gists
LANGUAGES_gists="ActionScript Ada Apex AppleScript Arc Arduino ASP Assembly
Augeas AutoHotkey Batchfile Befunge BlitzMax Boo Brainfuck Bro C C# C++
C2hs%Haskell ChucK Clojure CMake C-ObjDump CoffeeScript ColdFusion Common%Lisp
Coq Cpp-ObjDump CSS Cucumber Cython D Darcs%Patch Dart DCPU-16%ASM Delphi Diff
D-ObjDump Dylan eC Ecere%Projects Eiffel Elixir Emacs%Lisp Erlang F# Factor
Fancy Fantom FORTRAN GAS Genshi Gentoo%Ebuild Gentoo%Eclass Gettext%Catalog Go
Gosu Groff Groovy Groovy%Server%Pages Haml Haskell HaXe HTML HTML+Django
HTML+ERB HTML+PHP INI Io Ioke IRC%log Java JavaScript Java%Server%Pages JSON
Julia Kotlin LilyPond Literate%Haskell LLVM Logtalk Lua Makefile Mako Markdown
Matlab Max/MSP MiniD Mirah Moocode mupad Myghty Nemerle Nimrod Nu NumPy ObjDump
Objective-C Objective-J OCaml ooc Opa OpenCL OpenEdge%ABL Parrot Parrot%Assembly
Parrot%Internal%Representation Perl PHP Plain%Text PowerShell Prolog Puppet
Pure%Data Python Python%traceback R Racket Raw%token%data Rebol Redcode
reStructuredText RHTML Ruby Rust Sage Sass Scala Scheme Scilab SCSS Self Shell
Smalltalk Smarty SQL Standard%ML SuperCollider Tcl Tcsh Tea TeX Textile Turing
Twig Vala Verilog VHDL VimL Visual%Basic XML XQuery XS YAML"
LANGUAGE_VALUES_gists="as adb cls scpt arc ino asp asm aug ahk bat befunge bmx
boo b bro c cs cpp chs ck clj cmake c-objdump coffee cfm lisp v cppobjdump css
feature pyx d darcspatch dart dasm16 pas diff d-objdump dylan ec epj e ex el erl
fs factor fy fan f90 s kid ebuild eclass po go gs man groovy gsp haml hs hx html
mustache erb phtml cfg io ik weechatlog java js jsp json jl kt ly lhs ll lgt lua
mak mako md matlab mxt minid duby moo mu myt n nim nu numpy objdump m j ml ooc
opa cl p parrot pasm pir pl aw txt ps1 pl pp pd py pytb r rkt raw r cw rst rhtml
rb rs sage sass scala scm sci scss self sh st tpl sql sml sc tcl tcsh tea tex
textile t twig vala v vhd vim vb xml xq xs yml"
REGEX_URL_gists='s|^.*"html_url": "\([^"]\+\)".*$|\1|p'
REGEX_RAW_gists='s|^\(https://\)\(gist\)\(.github.com/\)\(.*\)$|\1raw\3\2/\4/|'
escape_description_gists() { sed -e 's|"|\\"|g' -e 's|\x1b|\\u001b|g' -e 's|\r||g' <<< "$*"; }
escape_input_gists() { sed -e 's|\\|\\\\|g' -e 's|\x1b|\\u001b|g' -e 's|\r||g' -e 's|\t|\\t|g' -e 's|"|\\"|g' -e 's|$|\\n|' <<< "$*" | tr -d '\n'; }
json_gists() {
    local description="${1}" language="${2}" content="${3}"
    echo "{\"description\":\"${description}\",\"public\":\"true\",\"files\":{\"${description//\/}.${language}\":{\"content\":\"${content}\"}}"
}
# lodgeit
LANGUAGES_lodgeit="Apache%Config%(.htaccess) Bash Batch%(.bat) Boo C C# C++ Clojure Creole%Wiki CSS \
CSV D Debian%control-files Django%/%Jinja%Templates Dylan Erlang eRuby%/%rhtml GAS GCC%Messages \
Genshi%Templates Gettext%catalogs GL%Shader%language Haskell HTML INI%File Interactive%Ruby IO \
IRC%Logs Java javac%Messages JavaScript JSP Lighttpd Literate%Haskell LLVM Lua Mako%Templates Matlab \
Matlab%Session MiniD Multi-File Myghty%Templates MySQL Nasm Nginx Object-Pascal OCaml Perl PHP \
PHP%(inline) Povray Python Python%Console%Sessions Python%Tracebacks reStructuredText Ruby Scala \
Scheme Smalltalk Smarty sources.list SQL SquidConf TeX%/%LaTeX Plain%Text Unified%Diff Vim XML XSLT YAML"
LANGUAGE_VALUES_lodgeit="apache bash bat boo c csharp cpp clojure creole css csv d control html+django \
dylan erlang rhtml gas gcc-messages html+genshi gettext glsl haskell html ini irb io irc java \
javac-messages js jsp lighttpd literate-haskell llvm lua html+mako matlab matlabsession minid multi \
html+myghty mysql nasm nginx objectpascal ocaml perl html+php php povray python pycon pytb rst ruby \
scala scheme smalltalk smarty sourceslist sql squidconf tex text diff vim xml xslt yaml"
POST_lodgeit="submit=Paste! % % language % % code"
REGEX_RAW_lodgeit='s|^\(http://[^/]*/\)show\(/[0-9]*/\)$|\1raw\2|'

### errors
die() {
	echo "$@" >&2
	exit 1
}

requiredarg() {
	[[ -z $2 ]] && die "$0: option $1 requires an argument"
	((args++))
}

notreadable() {
	die "The input source: \"$1\" is not readable. Please specify a readable input source."
}

noxclip() {
	cat <<EOF >&2
Could not find xclip on your system. In order to use --x$1 you must either
emerge x11-misc/xclip or define x_$1() globally in /etc/wgetpaste.conf or
per user in ~/.wgetpaste.conf to use another program (such as e.g. xcut or
klipper) to $2 your clipboard.

EOF
	exit 1
}

### conversions

# escape % (used for escaping), & (used as separator in POST data), + (used as space in POST data), space and ;
escape() {
	sed -e 's|%|%25|g' -e 's|&|%26|g' -e 's|+|%2b|g' -e 's|;|%3b|g' -e 's| |+|g' <<< "$*" || die "sed failed"
}

# if possible convert URL to raw
converttoraw() {
	local regex
	regex=REGEX_RAW_$ENGINE
	if [[ -n ${!regex} ]]; then
		RAWURL=$(sed -e "${!regex}" <<< "$URL")
		[[ -n $RAWURL ]] && return 0
		echo "Convertion to raw url failed." >&2
	else
		echo "Raw download of pastes is not supported by $(getrecipient)." >&2
	fi
	return 1
}

### verification
verifyservice() {
	for s in $SERVICES; do
		[[ $s == $* ]] && return 0
	done
	echo "\"$*\" is not a supported service.$N" >&2
	showservices >&2
	exit 1
}

verifylanguage() {
	local i j l lang count v values
	lang=LANGUAGES_$ENGINE
	count=LANGUAGE_COUNT_$ENGINE
	values=LANGUAGE_VALUES_$ENGINE
	if [[ -n ${!lang} ]]; then
		((i=0))
		for l in ${!lang}; do
			if [[ $LANGUAGE == ${l//\%/ } ]]; then
				if [[ -n ${!count} ]]; then
					((LANGUAGE=i+1))
				elif [[ -n ${!values} ]]; then
					((j=0))
					for v in ${!values}; do
						if [[ i -eq j ]]; then
							if [[ ${v} == \% ]]; then
								LANGUAGE=
							else
								LANGUAGE=${v//\%/ }
							fi
							break
						fi
						((j++))
					done
				fi
				return 0
			fi
			((i++))
		done
	else
		[[ $LANGUAGESET = 0 ]] || return 0
	fi
	echo "\"$LANGUAGE\" is not a supported language for $(getrecipient).$N" >&2
	showlanguages >&2
	exit 1
}

verifyexpiration() {
	local i j e expiration count v values
	expiration=EXPIRATIONS_$ENGINE
	count=EXPIRATION_COUNT_$ENGINE
	values=EXPIRATION_VALUES_$ENGINE
	if [[ -n ${!expiration} ]]; then
		((i=0))
		for e in ${!expiration}; do
			if [[ ${EXPIRATION} == ${e//\%/ } ]]; then
				if [[ -n ${!count} ]]; then
					((EXPIRATION=i+1))
				elif [[ -n {!values} ]]; then
					((j=0))
					for v in ${!values}; do
						if [[ i -eq j ]]; then
							if [[ ${v} == \% ]]; then
								EXPIRATION=
							else
								EXPIRATION=${v//\%/ }
							fi
							break
						fi
						((j++))
					done
				fi
				return 0
			fi
			((i++))
		done
	else
		[[ $EXPIRATIONSET = 0 ]] || return 0
	fi
	echo "\"$EXPIRATION\" is not a supported expiration option for $(getrecipient).$N" >&2
	showexpirations >&2
	exit 1
}

# verify that the pastebin service did not return a known error url. otherwise print a helpful error message
verifyurl() {
	dieifknown() {
		[[ -n ${!1%% *} && ${!1%% *} == $URL ]] && die "${!1#* }"
	}
	local t
	for t in ${!TOO*}; do
		[[ $t == TOO*_$SERVICE ]] && dieifknown "$t"
	done
}

# print a warning if failure is predictable due to the mere size of the paste. note that this is only a warning
# printed. it does not abort.
warnings() {
	warn() {
		if [[ -n $2 && $1 -gt $2 ]]; then
			echo "Pasting > ${3//\%/ } often tend to fail with $SERVICE. Use --verbose or --debug to see the"
			echo "error output from wget if it fails. Alternatively use another pastebin service."
		fi
	}
	local size lines
	size=SIZE_$SERVICE
	warn "$SIZE" "${!size% *}" "${!size#* }"
	lines=LINES_$SERVICE
	warn "$LINES" "${!lines}" "${!lines} lines"
}

### input
getfilenames() {
	for f in "$@"; do
		[[ -f $f ]] || die "$0: $f No such file found."
		SOURCE="files"
		FILES[${#FILES[*]}]="$f"
	done
}

x_cut() {
	if [[ -x $(type -P xclip) ]]; then
		xclip -o || die "xclip failed."
	else
		noxclip cut "read from"
	fi
}

### output
usage() {
	cat <<EOF
Usage: $0 [options] [file[s]]

Options:
    -l, --language LANG           set language (defaults to "$DEFAULT_LANGUAGE")
    -d, --description DESCRIPTION set description (defaults to "stdin" or filename)
    -n, --nick NICK               set nick (defaults to your username)
    -s, --service SERVICE         set service to use (defaults to "$DEFAULT_SERVICE")
    -e, --expiration EXPIRATION   set when it should expire (defaults to "$DEFAULT_EXPIRATION")

    -S, --list-services           list supported pastebin services
    -L, --list-languages          list languages supported by the specified service
    -E, --list-expiration         list expiration setting supported by the specified service

    -u, --tinyurl URL             convert input url to tinyurl

    -c, --command COMMAND         paste COMMAND and the output of COMMAND
    -i, --info                    append the output of \`$INFO_COMMAND\`
    -I, --info-only               paste the output of \`$INFO_COMMAND\` only
    -x, --xcut                    read input from clipboard (requires x11-misc/xclip)
    -X, --xpaste                  write resulting url to the X primary selection buffer (requires x11-misc/xclip)
    -C, --xclippaste              write resulting url to the X clipboard selection buffer (requires x11-misc/xclip)

    -r, --raw                     show url for the raw paste (no syntax highlighting or html)
    -t, --tee                     use tee to show what is being pasted
    -v, --verbose                 show wget stderr output if no url is received
        --completions             emit output suitable for shell completions (only affects --list-*)
        --debug                   be *very* verbose (implies -v)

    -h, --help                    show this help
    -g, --ignore-configs          ignore /etc/wgetpaste.conf, ~/.wgetpaste.conf etc.
        --version                 show version information

Defaults (DEFAULT_{NICK,LANGUAGE,EXPIRATION}[_\${SERVICE}] and DEFAULT_SERVICE)
can be overridden globally in /etc/wgetpaste.conf or /etc/wgetpaste.d/*.conf or
per user in any of ~/.wgetpaste.conf or ~/.wgetpaste.d/*.conf.
EOF
}

showservices() {
	local max s IND INDV engine url d
	if [[ -n $COMPLETIONS ]]; then
		for s in $SERVICES; do
			if [[ -n $VERBOSE ]]; then
				d=URL_$s && echo "$s:${!d% *}"
			else
				echo "$s"
			fi
		done
		exit 0
	fi
	echo "Services supported: (case sensitive):"
	max=4
	for s in $SERVICES; do
		[[ ${#s} -gt $max ]] && max=${#s}
	done
	((IND=6+max))
	if [[ $VERBOSE ]]; then
		max=0
		for s in $SERVICES; do
			s=URL_$s
			s=${!s% *}
			[[ ${#s} -gt $max ]] && max=${#s}
		done
		((INDV=3+max+IND))
		engine=" $E[${INDV}G| Pastebin engine:"
	fi
	echo "   Name: $E[${IND}G| Url:$engine"
	echo -ne "   "; for((s=3;s<${INDV:-${IND}}+17;s++)); do (( $s == IND-1 || $s == INDV-1 )) && echo -ne "|" || echo -ne "="; done; echo
	for s in $SERVICES; do
		[[ $s = $DEFAULT_SERVICE ]] && d="*" || d=" "
		[[ $VERBOSE ]] && engine=ENGINE_$s && engine="$E[${INDV}G| ${!engine}"
		url=URL_$s
		url=${!url% *}
		echo "   $d$s $E[${IND}G| $url$engine"
	done | sort
}

printlist() {
	while [[ -n $1 ]]; do
		echo "${1//\%/ }"
		shift
	done
}

showlanguages() {
	local l lang d
	lang=LANGUAGES_$ENGINE
	[[ -n $COMPLETIONS ]] && printlist ${!lang} | sort && exit 0
	echo "Languages supported by $(getrecipient) (case sensitive):"
	[[ -z ${!lang} ]] && echo "$N\"$ENGINE\" has no support for setting language." >&2 && exit 1
	for l in ${!lang}; do
		[[ ${l//\%/ } = $DEFAULT_LANGUAGE ]] && d="*" || d=" "
		echo "   $d${l//\%/ }"
	done | sort
}

showexpirations() {
	local e expiration info d
	expiration=EXPIRATIONS_$ENGINE
	[[ -n $COMPLETIONS ]] && printlist ${!expiration} && exit 0
	echo "Expiration options supported by $(getrecipient) (case sensitive):"
	info=EXPIRATION_INFO_$SERVICE
	[[ -z ${!expiration} ]] && echo "$N${!info}\"$ENGINE\" has no support for setting expiration." >&2 && exit 1
	for e in ${!expiration}; do
		[[ ${e//\%/ } = $DEFAULT_EXPIRATION ]] && d="*" || d=" "
		echo "   $d${e//\%/ }"
	done
}

showurl() {
	echo "Your ${2}paste can be seen here: $1"
	[[ $XPASTE ]] && x_paste "$1" primary
	[[ $XCLIPPASTE ]] && x_paste "$1" clipboard
}

x_paste() {
	if [[ -x $(type -P xclip) ]]; then
		echo -n "$1" | xclip -selection $2 -loops 10 &>/dev/null || die "xclip failed."
	else
		noxclip paste "write to"
	fi
}

### Posting helper functions

# get the url to post to
getrecipient() {
	local urls target serv
	for s in $SERVICES tinyurl; do
		if [[ $s == $SERVICE ]]; then
			urls=URL_$SERVICE
			if [[ RAW == $1 ]]; then
				[[ ${!urls} = ${!urls#* } ]] || target=${!urls#* }
			else
				serv="$SERVICE: "
			fi
			echo "${serv}${!urls% *}${target}"
			return 0
		fi
	done
	die "Failed to get url for \"$SERVICE\"."
}

# generate POST data
postdata() {
	local post nr extra f
	post=POST_$ENGINE
	if [[ -n ${!post} ]]; then
		nr=${!post//[^ ]}
		[[ 6 = ${#nr} ]] || die "\"${SERVICE}\" is not supported by ${FUNCNAME}()."
		extra=${!post%% *}
		[[ '%' = $extra ]] || echo -n "$extra&"
		e() {
			post="$1"
			shift
			while [[ -n $1 ]]; do
				f=${post%% *}
				[[ '%' != $f ]] && echo -n "$f=${!1}" && [[ $# -gt 1 ]] && echo -n "&"
				shift
				post=${post#$f }
			done
		}
		e "${!post#$extra }" NICK DESCRIPTION LANGUAGE EXPIRATION CVT_TABS INPUT
	elif [[ function == $(type -t json_$ENGINE) ]]; then
		json_$ENGINE "$DESCRIPTION" "$LANGUAGE" "$INPUT"
	else
		die "\"${SERVICE}\" is not supported by ${FUNCNAME}()."
	fi
}

# get url from response from server
geturl() {
	local regex
	regex=REGEX_URL_$ENGINE
	if [[ -n ${!regex} ]]; then
		[[ needstdout = $1 ]] && return 0
		sed -n -e "${!regex}" <<< "$*"
	else
		[[ needstdout = $1 ]] && return 1
		sed -n -e 's|^.*Location: \(http://[^ ]*\).*$|\1|p' <<< "$*"
	fi
}

### read cli options

# separate groups of short options. replace --foo=bar with --foo bar
while [[ -n $1 ]]; do
	case "$1" in
		-- )
		for arg in "$@"; do
			ARGS[${#ARGS[*]}]="$arg"
		done
		break
		;;
		--debug )
		set -x
		DEBUG=0
		;;
		--*=* )
		ARGS[${#ARGS[*]}]="${1%%=*}"
		ARGS[${#ARGS[*]}]="${1#*=}"
		;;
		--* )
		ARGS[${#ARGS[*]}]="$1"
		;;
		-* )
		for shortarg in $(sed -e 's|.| -&|g' <<< "${1#-}"); do
			ARGS[${#ARGS[*]}]="$shortarg"
		done
		;;
		* )
		ARGS[${#ARGS[*]}]="$1"
	esac
	shift
done

# set the separated options as input options.
set -- "${ARGS[@]}"

while [[ -n $1 ]]; do
	((args=1))
	case "$1" in
		-- )
		shift && getfilenames "$@" && break
		;;
		-c | --command )
		requiredarg "$@"
		SOURCE="command"
		COMMANDS[${#COMMANDS[*]}]="$2"
		;;
		--completions )
		COMPLETIONS=0
		;;
		-d | --description )
		requiredarg "$@"
		DESCRIPTION="$2"
		;;
		-e | --expiration )
		requiredarg "$@"
		EXPIRATIONSET=0
		EXPIRATION="$2"
		;;
		-E | --list-expiration )
		LISTEXPIRATION=0
		;;
		-h | --help )
		USAGE=0
		;;
		-g | --ignore-configs )
		IGNORECONFIGS=0
		;;
		-i | --info )
		INFO=0
		;;
		-I | --info-only )
		SOURCE=info
		;;
		-l | --language )
		requiredarg "$@"
		LANGUAGESET=0
		LANGUAGE="$2"
		;;
		-L | --list-languages )
		LISTLANGUAGES=0
		;;
		-n | --nick )
		requiredarg "$@"
		NICK=$(escape "$2")
		;;
		-r | --raw )
		RAW=0
		;;
		-s | --service )
		requiredarg "$@"
		SERVICESET="$2"
		;;
		-S | --list-services )
		SHOWSERVICES=0
		;;
		-t | --tee )
		TEE=0
		;;
		-u | --tinyurl )
		requiredarg "$@"
		SERVICE=tinyurl
		SOURCE="url"
		INPUTURL="$2"
		;;
		-v | --verbose )
		VERBOSE=0
		;;
		--version )
		echo "$0, version $VERSION" && exit 0
		;;
		-x | --xcut )
		SOURCE=xcut
		;;
		-X | --xpaste )
		XPASTE=0
		;;
		-C | --xclippaste )
		XCLIPPASTE=0
		;;
		-* )
		die "$0: unrecognized option \`$1'"
		;;
		*)
		getfilenames "$1"
		;;
	esac
	shift $args
done

### defaults
load_configs() {
	if [[ ! $IGNORECONFIGS ]]; then
		# compatibility code
		local f deprecated=
		for f in {/etc/,~/.}wgetpaste{.d/*.bash,}; do
			if [[ -f $f ]]; then
				if [[ -z $deprecated ]]; then
					echo "The config files for wgetpaste have changed to *.conf.$N" >&2
					deprecated=0
				fi
				echo "Please move ${f} to ${f/%.bash/.conf}" >&2
				source "$f" || die "Failed to source $f"
			fi
		done
		[[ -n $deprecated ]] && echo >&2
		# new locations override old ones in case they collide
		for f in {/etc/,~/.}wgetpaste{.d/*,}.conf; do
			if [[ -f $f ]]; then
				source "$f" || die "Failed to source $f"
			fi
		done
	fi
}
load_configs
[[ $SERVICESET ]] && verifyservice "$SERVICESET" && SERVICE=$(escape "$SERVICESET")
DEFAULT_NICK=${DEFAULT_NICK:-$(whoami)} || die "whoami failed"
DEFAULT_SERVICE=${DEFAULT_SERVICE:-gists}
DEFAULT_LANGUAGE=${DEFAULT_LANGUAGE:-Plain Text}
DEFAULT_EXPIRATION=${DEFAULT_EXPIRATION:-1 month}
SERVICE=${SERVICE:-${DEFAULT_SERVICE}}
ENGINE=ENGINE_$SERVICE
ENGINE="${!ENGINE}"
default="DEFAULT_NICK_$SERVICE" && [[ -n ${!default} ]] && DEFAULT_NICK=${!default}
default="DEFAULT_LANGUAGE_$SERVICE" && [[ -n ${!default} ]] && DEFAULT_LANGUAGE=${!default}
default="DEFAULT_EXPIRATION_$SERVICE" && [[ -n ${!default} ]] && DEFAULT_EXPIRATION=${!default}
NICK=${NICK:-$(escape "${DEFAULT_NICK}")}
[[ -z $SOURCE ]] && SOURCE="stdin"
CVT_TABS=No

INFO_COMMAND=${INFO_COMMAND:-"emerge --info"}
INFO_ARGS=${INFO_ARGS:-"--ignore-default-opts"}

### everything below this should be independent of which service is being used...

# show listings if requested
[[ $USAGE ]] && usage && exit 0
[[ $SHOWSERVICES ]] && showservices && exit 0
[[ $LISTLANGUAGES ]] && showlanguages && exit 0
[[ $LISTEXPIRATION ]] && showexpirations && exit 0

# language and expiration need to be verified before they are escaped but after service and defaults
# have been selected
LANGUAGE=${LANGUAGE:-${DEFAULT_LANGUAGE}}
verifylanguage
LANGUAGE=$(escape "$LANGUAGE")
EXPIRATION=${EXPIRATION:-${DEFAULT_EXPIRATION}}
verifyexpiration
EXPIRATION=$(escape "$EXPIRATION")

# set prompt
if [[ 0 -eq $UID ]]; then
	PS1="#"
else
	PS1=$
fi

# set default description
size=DESCRIPTION_SIZE_$SERVICE
if [[ -z $DESCRIPTION ]]; then
	case "$SOURCE" in
		info )
		DESCRIPTION="$PS1 $INFO_COMMAND;"
		;;
		command )
		DESCRIPTION="$PS1"
		for c in "${COMMANDS[@]}"; do
			DESCRIPTION="$DESCRIPTION $c;"
		done
		;;
		files )
		DESCRIPTION="${FILES[@]}"
		;;
		* )
		DESCRIPTION="$SOURCE"
		;;
	esac
	if [[ -n ${!size} && ${#DESCRIPTION} -gt ${!size} ]]; then
		DESCRIPTION="${DESCRIPTION: -${!size}}"
	fi
else
	if [[ -n ${!size} && ${#DESCRIPTION} -gt ${!size} ]]; then
		die "Your description (${#DESCRIPTION} bytes) is too long. Shorten it to fit within ${!size} bytes."
	fi
fi

# create tmpfile for use with tee
if [[ $TEE ]]; then
	TMPF=$(mktemp /tmp/wgetpaste.XXXXXX)
	[[ -f $TMPF ]] || die "Could not create a temporary file for use with tee."
fi

# read input
case "$SOURCE" in
	url )
	INPUT="${INPUTURL}"
	;;
	command )
	for c in "${COMMANDS[@]}"; do
		if [[ $TEE ]]; then
			echo "$PS1 $c$N$(bash -c "$c" 2>&1)$N" | tee -a "$TMPF"
		else
			INPUT="$INPUT$PS1 $c$N$(bash -c "$c" 2>&1)$N$N"
		fi
	done
	;;
	info )
	if [[ $TEE ]]; then
		echo "$PS1 $INFO_COMMAND$N$($INFO_COMMAND $INFO_ARGS 2>&1)" | tee "$TMPF"
	else
		INPUT="$PS1 $INFO_COMMAND$N$($INFO_COMMAND $INFO_ARGS 2>&1)"
	fi
	;;
	xcut )
	if [[ $TEE ]]; then
		x_cut | tee "$TMPF"
	else
		INPUT="$(x_cut)"
	fi
	;;
	stdin )
		if [[ $TEE ]]; then
			tee "$TMPF"
		else
			INPUT="$(cat)"
		fi
	;;
	files )
	if [[ ${#FILES[@]} -gt 1 ]]; then
		for f in "${FILES[@]}"; do
			[[ -r $f ]] || notreadable "$f"
			if [[ $TEE ]]; then
				echo "$PS1 cat $f$N$(<"$f")$N" | tee -a "$TMPF"
			else
				INPUT="$INPUT$PS1 cat $f$N$(<"$f")$N$N"
			fi
		done
	else
		[[ -r $FILES ]] || notreadable "$FILES"
		if [[ $TEE ]]; then
			tee "$TMPF" < "$FILES"
		else
			INPUT=$(<"$FILES")
		fi
	fi
	;;
esac
NOINPUT="No input read. Nothing to paste. Aborting."
if [[ $TEE ]]; then
	[[ 0 -eq $(wc -c < "$TMPF") ]] && die "$NOINPUT"
else
	[[ -z $INPUT ]] && die "$NOINPUT"
fi

# append info if needed
if [[ $INFO ]]; then
	DESCRIPTION="$DESCRIPTION $PS1 $INFO_COMMAND;"
	if [[ $TEE ]]; then
		echo "$N$PS1 $INFO_COMMAND$N$($INFO_COMMAND $INFO_ARGS 2>&1)" | tee -a "$TMPF"
	else
		INPUT="$INPUT$N$PS1 $INFO_COMMAND$N$($INFO_COMMAND $INFO_ARGS 2>&1)"
	fi
fi

# now that tee has done its job read data into INPUT
[[ $TEE ]] && INPUT=$(<"$TMPF") && echo

# escape DESCRIPTION and INPUT
if [[ function = $(type -t escape_description_$ENGINE) ]]; then
	DESCRIPTION=$(escape_description_$ENGINE "$DESCRIPTION")
else
	DESCRIPTION=$(escape "$DESCRIPTION")
fi
if [[ function = $(type -t escape_input_$ENGINE) ]]; then
	INPUT=$(escape_input_$ENGINE "$INPUT")
else
	INPUT=$(escape "$INPUT")
fi

# print friendly warnings if max sizes have been specified for the pastebin service and the size exceeds that
SIZE=$(wc -c <<< "$INPUT")
LINES=$(wc -l <<< "$INPUT")
warnings >&2

# set recipient
RECIPIENT=$(getrecipient RAW)

if [[ $SERVICE == tinyurl ]]; then
	URL=$(LC_ALL=C wget -qO - "$RECIPIENT?url=$INPUT")
else
	# create temp file (wget is much more reliable reading
	# large input via --post-file rather than --post-data)
	[[ -f $TMPF ]] || TMPF=$(mktemp /tmp/wgetpaste.XXXXXX)
	if [[ -f $TMPF ]]; then
		postdata > "$TMPF" || die "Failed to write to temporary file: \"$TMPF\"."
		WGETARGS="--post-file=$TMPF"
	else
		# fall back to using --post-data if the temporary file could not be created
		# TABs and new lines need to be escaped for wget to interpret it as one string
		WGETARGS="--post-data=$(postdata | sed -e 's|$|%0a|g' -e 's|\t|%09|g' | tr -d '\n')"
	fi

	# paste it
	WGETARGS="--tries=5 --timeout=60 $WGETARGS"
	if geturl needstdout || [[ $DEBUG || ! -w /dev/null ]]; then
		OUTPUT=$(LC_ALL=C wget -O - $WGETARGS $RECIPIENT 2>&1)
	else
		OUTPUT=$(LC_ALL=C wget -O /dev/null $WGETARGS $RECIPIENT 2>&1)
	fi

	# clean temporary file if it was created
	if [[ -f $TMPF ]]; then
		if [[ $DEBUG ]]; then
			echo "Left temporary file: \"$TMPF\" alone for debugging purposes."
		else
			rm "$TMPF" || echo "Failed to remove temporary file: \"$TMPF\"." >&2
		fi
	fi

	# get the url
	URL=$(geturl "$OUTPUT")
fi

# verify that the pastebin service did not return a known error url such as toofast.html from rafb
verifyurl

# handle the case when there was no location returned
if [[ -z $URL ]]; then
	if [[ $DEBUG || $VERBOSE ]]; then
		die "Apparently nothing was received. Perhaps the connection failed.$N$OUTPUT"
	else
		echo "Apparently nothing was received. Perhaps the connection failed. Enable --verbose or" >&2
		die "--debug to get the output from wget that can help diagnose it correctly."
	fi
fi

# converttoraw() sets RAWURL upon success.
if [[ $RAW ]] && converttoraw; then
	showurl "$RAWURL" "raw "
else
	showurl "$URL"
fi

exit 0
