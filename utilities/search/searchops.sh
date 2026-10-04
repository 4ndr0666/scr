#!/usr/bin/env bash
#

#              === SEARCHOPS.SH v2.0 ===
# This script builds advanced Google search queries.
#

# CONSTANTS
#
readonly SCRIPT_VERSION="2.0"
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}"/Searchops
readonly HISTORY_FILE="$XDG_DATA_HOME/Searchops/history"

if ((BASH_VERSINFO[0] < 4)); then
	printf 'searchops.sh needs bash 4+ (found %s)\n' "$BASH_VERSION" >&2
	exit 1
fi

# REAL ESC BYTES ($'...')
#   * safe for printf '%s'
#
BOLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[1;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# STATE
#
PARTS=() # query tokens; array form enables UNDO
REPLY=""

# HELPERS
#
say() { printf '%s\n' "$1"; } # never escape-interprets data

cls() {
	if command -v clear >/dev/null 2>&1; then
		clear
	else
		printf '%s' $'\033[H\033[2J'
	fi
}

pause() {
	printf '%s' "${CYAN}Press [ENTER] to continue...${NC}"
	local _junk
	read -r _junk || true
}

# PROMPT
#
ask() {
	printf '%s' "$1"
	REPLY=""
	if [[ -t 0 ]]; then read -r -e REPLY; else read -r REPLY; fi
	local rc=$?
	if ((rc != 0)); then
		printf '\n%s\n' "${RED}Input stream closed — exiting.${NC}"
		exit 0
	fi
	return 0
}

yesno() {
	local a
	a="$(trim "$REPLY")"
	a="${a,,}"
	[[ "$a" == y* ]]
}
no() {
	local a
	a="$(trim "$REPLY")"
	a="${a,,}"
	[[ "$a" == n* ]]
}

# PARAMETER EXPANSION ONLY WHITESPACE TRIM
#
trim() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

# URL ENCODER
#   * byte-wise under LC_ALL=C
#   * correct percent-encoding for UTF-8
#   * masks the sign-extension bash prints for bytes > 0x7F,
#   * printf -v: no per-char subshell, no uncontrolled format string
#
urlencode() (
	LC_ALL=C
	local s="$1" i byte hex out=""
	for ((i = 0; i < ${#s}; i++)); do
		byte="${s:i:1}"
		case "$byte" in
		[a-zA-Z0-9.~_-]) out+="$byte" ;;
		*)
			printf -v hex '%02X' "'$byte" 2>/dev/null || hex="3F"
			out+="%${hex:${#hex}-2}"
			;;
		esac
	done
	printf '%s' "$out"
)

# QUERY TOKEN FOR UNDO ARRAY
#   * blank-safe
#   * edge-trimmed
#
append() {
	local t
	t="$(trim "$1")"
	[[ -n "$t" ]] && PARTS+=("$t") || true
}

# VALIDATE
#
v_date() { [[ "$1" =~ ^[0-9]{4}(-[0-9]{2}(-[0-9]{2})?)?$ ]]; }
v_ext() { [[ "$1" =~ ^[a-z0-9]{1,8}$ ]]; }
v_imgsz() { [[ "$1" =~ ^[0-9]+x[0-9]+$ ]]; }
v_int() { [[ "$1" =~ ^[0-9]+$ ]] && (($1 > 0)); }

# SANITIZE
#   * lowercase
#   * strip scheme
#   * www
#   * slash
#
clean_site() {
	local s
	s="$(trim "$1")"
	s="${s,,}"
	s="${s#http://}"
	s="${s#https://}"
	s="${s#www.}"
	s="${s%/}"
	s="${s#,}"
	s="${s%,}"
	printf '%s' "$s"
}

# CLIPBOARD
#   * gracefull degrade
#
copy_url() {
	if command -v pbcopy >/dev/null 2>&1; then
		printf '%s' "$1" | pbcopy
	elif command -v wl-copy >/dev/null 2>&1; then
		printf '%s' "$1" | wl-copy
	elif command -v xclip >/dev/null 2>&1; then
		printf '%s' "$1" | xclip -selection clipboard 2>/dev/null
	elif command -v xsel >/dev/null 2>&1; then
		printf '%s' "$1" | xsel --clipboard --input 2>/dev/null
	else
		return 1
	fi
}

# BROWSER
#   * gracefull degrade
#
open_url() {
	if command -v xdg-open >/dev/null 2>&1; then
		(xdg-open "$1" >/dev/null 2>&1) &
	elif command -v open >/dev/null 2>&1; then
		(open "$1" >/dev/null 2>&1) &
	elif command -v wslview >/dev/null 2>&1; then
		(wslview "$1" >/dev/null 2>&1) &
	else
		return 1
	fi
}

# INPUT
#
op_keywords() {
	ask "${CYAN}Free keywords (plain words, no operators):${NC} "
	append "$REPLY"
}

op_exact() {
	ask "${CYAN}Exact phrase — quotes are added for you:${NC} "
	local v
	v="${REPLY//\"/}" # inner quotes unsupported
	[[ -n "$(trim "$v")" ]] && append "\"$v\"" || true
}

op_or() {
	ask "${CYAN}Alternatives, comma-separated (a, b, c → a OR b OR c):${NC} "
	local alts t out=""
	IFS=',' read -r -a alts <<<"$REPLY"
	for t in "${alts[@]}"; do
		t="$(trim "$t")"
		[[ -n "$t" ]] && out+="${out:+ OR }$t"
	done
	[[ -n "$out" ]] && append "$out" || true
}

op_group() {
	ask "${CYAN}Expression to wrap in parentheses:${NC} "
	local v
	v="$(trim "$REPLY")"
	[[ -n "$v" ]] && append "($v)" || true
}

op_exclude() {
	ask "${CYAN}Exclude terms, space-separated (quote a phrase: \"sponsored content\"):${NC} "
	local t
	set -f # no glob expansion of user words
	# shellcheck disable=SC2086  # deliberate word-splitting of user terms
	for t in $REPLY; do append "-$t"; done
	set +f
}

op_wildcard() {
	ask "${CYAN}Phrase containing the * wildcard (e.g. how to * a firewall):${NC} "
	local v
	v="$(trim "$REPLY")"
	[[ -n "$v" ]] || return 0
	if [[ "$v" != *'*'* ]]; then
		say "${RED}Phrase must contain at least one *${NC}"
		pause
		return 0
	fi
	[[ "$v" == \"*\" ]] || v="\"$v\""
	append "$v"
}

op_range() {
	ask "${CYAN}Range, typed as it will be searched (e.g. 2015..2024, \$10..\$50, 3..5 kWh):${NC} "
	local v
	v="$(trim "$REPLY")"
	[[ -n "$v" ]] || return 0
	if [[ "$v" != *..* || "$v" == ".." ]]; then
		say "${RED}Invalid range — must contain '..' (e.g. 2015..2024)${NC}"
		pause
		return 0
	fi
	append "$v"
}

op_around() {
	say "${CYAN}Proximity: results where both terms occur within n words of each other.${NC}"
	ask "  First term: "
	local a
	a="$(trim "$REPLY")"
	[[ -n "$a" ]] || return 0
	ask "  Distance n (e.g. 3): "
	local n
	n="$(trim "$REPLY")"
	v_int "$n" || {
		say "${RED}Distance must be a positive integer.${NC}"
		pause
		return 0
	}
	ask "  Second term: "
	local b
	b="$(trim "$REPLY")"
	[[ -n "$b" ]] || return 0
	append "$a AROUND($n) $b"
}

# SITE ENGINE
#   * inurl
#   * intitle
#   * intext
#   * inanchor
#   * /
#   * filetype: — supports negation (-site:)
#   * all*-variants
#   * automatic multi-site OR grouping
#   * normalization and validation
#
op_filter() {
	local op="$1" hint
	case "$op" in
	site) hint="domain or TLD — several allowed (a b → (site:a OR site:b))" ;;
	inurl) hint="token required in the URL" ;;
	intitle) hint="word/phrase required in the page title" ;;
	intext) hint="word/phrase required in the body text" ;;
	inanchor) hint="word/phrase required in link anchor text" ;;
	filetype) hint="extension (pdf, xlsx, docx, ppt, csv ...)" ;;
	esac
	ask "${CYAN}${op}:${NC} ${hint}: "
	local raw="$REPLY"
	[[ -n "$(trim "$raw")" ]] || return 0

	local neg=""
	ask "  ${CYAN}Negate this filter (-${op}:)? [y/N]:${NC} "
	yesno && neg="-"

	local prefix="${op}:"
	if [[ "$op" != site && "$op" != filetype ]]; then
		ask "  ${CYAN}Variant — [1] ${op}: this value   [2] all${op}: every following term [1]:${NC} "
		if [[ "$(trim "$REPLY")" == 2 ]]; then
			if [[ -n "$neg" ]]; then
				say "${YELLOW}Negation is not valid with all${op}: — using ${op}: instead.${NC}"
			else
				prefix="all${op}:"
			fi
		fi
	fi

	if [[ "$op" == site ]]; then
		raw="${raw//,/ }"
		local vals=() s
		set -f
		# shellcheck disable=SC2086
		for s in $raw; do
			s="$(clean_site "$s")"
			[[ -n "$s" ]] && vals+=("$s")
		done
		set +f
		((${#vals[@]})) || return 0
		if [[ -n "$neg" ]]; then
			local d
			for d in "${vals[@]}"; do append "-site:$d"; done
		elif ((${#vals[@]} > 1)); then
			local joined="" d
			for d in "${vals[@]}"; do joined+="${joined:+ OR }site:$d"; done
			append "(${joined})"
		else
			append "site:${vals[0]}"
		fi
	elif [[ "$op" == filetype ]]; then
		local v
		v="$(trim "$raw")"
		v="${v#.}"
		v="${v,,}"
		if ! v_ext "$v"; then
			say "${RED}Bad extension '$v' — letters/digits only (e.g. pdf).${NC}"
			pause
			return 0
		fi
		append "${neg}filetype:$v"
	else
		local v
		v="$(trim "$raw")"
		[[ -n "$v" ]] || return 0
		if [[ "$prefix" == all* ]]; then
			append "${prefix}${v}" # all- variants take the rest verbatim
		else
			# multi-word values must be quoted for single-term operators
			[[ "$v" == *" "* && "$v" != \"*\" ]] && v="\"$v\""
			append "${neg}${prefix}${v}"
		fi
	fi
	return 0
}

op_dates() {
	say "${CYAN}Temporal filters — they match the date Google associates with a page${NC}"
	say "${CYAN}(often the index date, not the original publication date).${NC}"
	ask "  after:  — published after  (YYYY | YYYY-MM | YYYY-MM-DD, blank = skip): "
	local a
	a="$(trim "$REPLY")"
	if [[ -n "$a" ]]; then
		v_date "$a" && append "after:$a" || say "${RED}Bad date '$a' — skipped.${NC}"
	fi
	ask "  before: — published before (same formats, blank = skip): "
	local b
	b="$(trim "$REPLY")"
	if [[ -n "$b" ]]; then
		v_date "$b" && append "before:$b" || say "${RED}Bad date '$b' — skipped.${NC}"
	fi
	return 0
}

op_special() {
	cls
	say "${YELLOW}${BOLD}=== SPECIALTY / VERTICAL / INSTANT-ANSWER OPERATORS ===${NC}"
	say ""
	say " ${CYAN}1.${NC} source:     Google News — restrict to one source"
	say " ${CYAN}2.${NC} location:   Google News — restrict to a locale"
	say " ${CYAN}3.${NC} imagesize:  Google Images — exact WxH dimensions"
	say " ${CYAN}4.${NC} define:     dictionary card"
	say " ${CYAN}5.${NC} weather:    weather card"
	say " ${CYAN}6.${NC} maps:       map result"
	say " ${CYAN}7.${NC} movie:      showtimes card"
	say " ${CYAN}8.${NC} flights     flight-search trigger (phrase)"
	say " ${CYAN}9.${NC} conversion  unit / calculator query (typed naturally)"
	say ""
	ask "Select [1-9, blank = cancel]: "
	local pick v f t
	pick="$(trim "$REPLY")"
	[[ -n "$pick" ]] || return 0
	case "$pick" in
	1)
		ask "  News source (e.g. reuters): "
		v="$(trim "$REPLY")"
		[[ -n "$v" ]] && append "source:$v"
		;;
	2)
		ask "  News location (e.g. chicago): "
		v="$(trim "$REPLY")"
		[[ -n "$v" ]] && append "location:$v"
		;;
	3)
		ask "  Image dimensions WxH (e.g. 1920x1080): "
		v="$(trim "$REPLY")"
		v="${v,,}"
		if v_imgsz "$v"; then
			append "imagesize:$v"
		else
			say "${RED}Format must be WxH, e.g. 1920x1080.${NC}"
			pause
		fi
		;;
	4)
		ask "  Word to define: "
		v="$(trim "$REPLY")"
		[[ -n "$v" ]] && append "define:$v"
		;;
	5)
		ask "  Location: "
		v="$(trim "$REPLY")"
		[[ -n "$v" ]] && append "weather:$v"
		;;
	6)
		ask "  Place: "
		v="$(trim "$REPLY")"
		[[ -n "$v" ]] && append "maps:$v"
		;;
	7)
		ask "  Movie title: "
		v="$(trim "$REPLY")"
		[[ -n "$v" ]] && append "movie:$v"
		;;
	8)
		ask "  From (city or airport): "
		f="$(trim "$REPLY")"
		[[ -n "$f" ]] || return 0
		ask "  To (city or airport): "
		t="$(trim "$REPLY")"
		[[ -n "$t" ]] && append "flights from $f to $t"
		;;
	9)
		ask "  Conversion (e.g. 10 km in miles): "
		v="$(trim "$REPLY")"
		[[ -n "$v" ]] && append "$v"
		;;
	*)
		say "${RED}Invalid choice.${NC}"
		pause
		;;
	esac
	return 0
}

op_preset() {
	cls
	say "${YELLOW}${BOLD}=== PRESET OPERATOR BLOCKS ===${NC}"
	say "${DIM}Seeds the query with a reusable block — add keywords, then [g] generate.${NC}"
	say ""
	say " ${CYAN}1.${NC} Academic papers ....... filetype:pdf (site:edu OR site:ac.uk)"
	say " ${CYAN}2.${NC} Government documents .. filetype:pdf site:gov"
	say " ${CYAN}3.${NC} Presentation decks .... (filetype:ppt OR filetype:pptx)"
	say " ${CYAN}4.${NC} Spreadsheet datasets . filetype:xlsx"
	say " ${CYAN}5.${NC} Open directories ...... intitle:\"index of\""
	say ""
	ask "Select preset [1-5, blank = cancel]: "
	case "$(trim "$REPLY")" in
	1)
		append "filetype:pdf"
		append "(site:edu OR site:ac.uk)"
		;;
	2)
		append "filetype:pdf"
		append "site:gov"
		;;
	3) append "(filetype:ppt OR filetype:pptx)" ;;
	4) append "filetype:xlsx" ;;
	5) append 'intitle:"index of"' ;;
	esac
	return 0
}

# GENERATE
#
generate() {
	local query="${PARTS[*]}"
	if [[ -z "$(trim "$query")" ]]; then
		say "${RED}Query is empty — add at least one operator first.${NC}"
		pause
		return 0
	fi

	cls
	say "${BLUE}${BOLD}========================================================================${NC}"
	say "${YELLOW}${BOLD}                            GENERATED QUERY${NC}"
	say "${BLUE}${BOLD}========================================================================${NC}"
	printf '%s\n' "${GREEN}${BOLD}${query}${NC}" # %s: user text never escape-interpreted
	say ""

	local enc url params=() r n p
	enc="$(urlencode "$query")"
	url="https://www.google.com/search?q=${enc}"

	say "${CYAN}Optional URL refinements — press ENTER to skip any of them:${NC}"
	if [[ "$query" == *"source:"* || "$query" == *"location:"* ]]; then
		say "${DIM}(hint: the query uses News operators — pick the news vertical)${NC}"
	fi
	if [[ "$query" == *"imagesize:"* ]]; then
		say "${DIM}(hint: imagesize: needs the images vertical)${NC}"
	fi

	ask "  Search vertical [web|news|images|videos|books|shopping] (web): "
	r="$(trim "$REPLY")"
	r="${r,,}"
	case "$r" in
	news | nws) params+=("tbm=nws") ;;
	images | img) params+=("tbm=isch") ;;
	videos | video | vid) params+=("tbm=vid") ;;
	books | bks) params+=("tbm=bks") ;;
	shopping | shop) params+=("tbm=shop") ;;
	esac

	ask "  Results per page, 1-100 (default 10): "
	n="$(trim "$REPLY")"
	if [[ "$n" =~ ^[0-9]+$ ]]; then
		((n > 100)) && n=100
		((n < 1)) && n=1
		params+=("num=$n")
	fi

	ask "  Un-hide omitted results (filter=0)? [y/N]: "
	yesno && params+=("filter=0")

	ask "  SafeSearch override [off|on]: "
	r="$(trim "$REPLY")"
	r="${r,,}"
	[[ "$r" == off ]] && params+=("safe=off")
	[[ "$r" == on ]] && params+=("safe=active")

	ask "  Recency window [h|d|w|m|y]: "
	r="$(trim "$REPLY")"
	r="${r,,}"
	case "$r" in h | d | w | m | y) params+=("tbs=qdr:$r") ;; esac

	ask "  Language restrict (lr=) — 'fr' or 'lang_fr': "
	r="$(trim "$REPLY")"
	r="${r,,}"
	if [[ "$r" =~ ^lang_[a-z]{2}$ ]]; then
		params+=("lr=$r")
	elif [[ "$r" =~ ^[a-z]{2}$ ]]; then
		params+=("lr=lang_$r")
	fi

	ask "  Country restrict (cr=) — 'UK' or 'countryUK': "
	r="$(trim "$REPLY")"
	r="${r^^}"
	if [[ "$r" =~ ^COUNTRY[A-Z]{2}$ ]]; then
		params+=("cr=$r")
	elif [[ "$r" =~ ^[A-Z]{2}$ ]]; then
		params+=("cr=country$r")
	fi

	local suffix=""
	for p in "${params[@]}"; do suffix+="&$p"; done
	url+="$suffix"

	say ""
	say "${BLUE}${BOLD}Final URL:${NC}"
	printf '%s\n' "$url"
	say ""

	if command -v pbcopy >/dev/null 2>&1 || command -v wl-copy >/dev/null 2>&1 ||
		command -v xclip >/dev/null 2>&1 || command -v xsel >/dev/null 2>&1; then
		ask "${CYAN}Copy URL to clipboard? [Y/n]:${NC} "
		if ! no; then
			copy_url "$url" && say "${GREEN}Copied to clipboard.${NC}" ||
				say "${YELLOW}Clipboard copy failed.${NC}"
		fi
	else
		say "${DIM}(no clipboard helper found — copy the URL manually)${NC}"
	fi

	if command -v xdg-open >/dev/null 2>&1 || command -v open >/dev/null 2>&1 ||
		command -v wslview >/dev/null 2>&1; then
		ask "${CYAN}Open it in your browser? [y/N]:${NC} "
		yesno && open_url "$url"
	fi

	(
		umask 077 # history stays private
		printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$query" "$url" \
			>>"$HISTORY_FILE"
	) 2>/dev/null || true
	say "${DIM}Saved to ${HISTORY_FILE}${NC}"
	pause
}

show_history() {
	cls
	say "${BLUE}${BOLD}======================================${NC}"
	say "${YELLOW}${BOLD}        QUERY HISTORY (last 25)${NC}"
	say "${BLUE}${BOLD}======================================${NC}"
	say ""
	if [[ ! -s "$HISTORY_FILE" ]]; then
		say "${DIM}No saved queries yet.${NC}"
	else
		tail -n 25 "$HISTORY_FILE" | while IFS=$'\t' read -r ts q _u; do
			printf '%s  %s\n' "${DIM}${ts}${NC}" "$q"
		done
	fi
	say ""
	pause
}

# REFERENCE
#
ref_row() { printf '  %-15s | %-40s | %s\n' "$1" "$2" "$3"; }
ref_hdr() {
	say ""
	say "$1"
}

show_reference() {
	cls
	say "${CYAN}${BOLD}         GOOGLE SEARCH OPERATORS ${NC}"

	ref_hdr "${CYAN}CORE LOGIC & SYNTAX${NC}"
	ref_row '"..."' 'Exact phrase match' '"machine learning"'
	ref_row '-term' 'Exclude a word (or quoted phrase)' '-apple -"sponsored"'
	ref_row 'OR  |' 'Either term — OR must be UPPERCASE' 'python OR rust'
	ref_row '( )' 'Group sub-expressions' '(hybrid OR remote)'
	ref_row '*' 'Wildcard: fills one or more words' '"how to * a firewall"'
	ref_row '..' 'Numeric / price / year range' '2018..2024  $50..$100'
	ref_row 'AROUND(n)' 'Terms within n words (unofficial)' 'tesla AROUND(3) recall'

	ref_hdr "${CYAN}PAGE / CONTENT FILTERS${NC}"
	ref_row 'site:' 'Restrict to a domain or TLD' 'site:edu'
	ref_row '-site:' 'Exclude a domain' '-site:pinterest.com'
	ref_row 'inurl:' 'Token must appear in the URL' 'inurl:press'
	ref_row 'intitle:' 'Word/phrase in the HTML <title>' 'intitle:"annual report"'
	ref_row 'intext:' 'Word/phrase in the body text' 'intext:"request for comment"'
	ref_row 'inanchor:' 'In anchor text of inbound links' 'inanchor:"click here"'
	ref_row 'allintitle:' 'ALL following terms in the title' 'allintitle: grant 2024'
	ref_row 'allinurl:' 'ALL following terms in the URL' 'allinurl: api docs'
	ref_row 'allintext:' 'ALL following terms in the body' 'allintext: invoice 2024'
	ref_row 'allinanchor:' 'ALL following terms in link anchors' 'allinanchor: read more'
	ref_row 'filetype:' 'Restrict file extension (ext: = alias)' 'filetype:pdf'
	ref_row '-filetype:' 'Exclude a file type' '-filetype:pdf'
	say "${DIM}  (any of the filters above can be negated with a leading '-')${NC}"

	ref_hdr "${CYAN}TEMPORAL${NC}"
	ref_row 'after:' 'Pages dated after (index date)' 'after:2024-01-01'
	ref_row 'before:' 'Pages dated before (index date)' 'before:2023-12-31'

	ref_hdr "${CYAN}VERTICAL OPERATORS (News / Images)${NC}"
	ref_row 'source:' 'Google News: one source' 'source:reuters'
	ref_row 'location:' 'Google News: one locale' 'location:chicago'
	ref_row 'imagesize:' 'Google Images: exact WxH' 'imagesize:1920x1080'

	ref_hdr "${CYAN}INSTANT-ANSWER TRIGGERS${NC}"
	ref_row 'define:' 'Dictionary definition card' 'define:OSINT'
	ref_row 'weather:' 'Weather card for a location' 'weather:chicago'
	ref_row 'maps:' 'Map result for a place' 'maps:kyoto'
	ref_row 'movie:' 'Showtimes card for a film' 'movie:dune'
	ref_row 'flights ...' 'Flight trigger (typed as a phrase)' 'flights from lax to jfk'
	ref_row 'conversion' 'Units / calculator (typed naturally)' '10 km in miles'

	ref_hdr "${CYAN}URL PARAMETERS (appended by this tool at generate time)${NC}"
	ref_row 'tbm=' 'Vertical: nws isch vid bks shop' 'tbm=nws'
	ref_row 'num=' 'Results per page (1-100)' 'num=100'
	ref_row 'filter=0' 'Un-hide omitted / duplicate results' 'filter=0'
	ref_row 'safe=' 'SafeSearch override: off | active' 'safe=off'
	ref_row 'tbs=qdr:' 'Recency window: h d w m y' 'tbs=qdr:m'
	ref_row 'lr=lang_xx' 'Restrict to a language' 'lr=lang_fr'
	ref_row 'cr=countryXX' 'Restrict to a country' 'cr=countryUK'

	ref_hdr "${CYAN}USAGE NOTES${NC}"
	say "  • allintitle:/allinurl:/... constrain EVERY term after them — put them"
	say "    first and don't mix them with other operators."
	say "  • OR must be uppercase ( | is an alias); AND is implicit."
	say "  • before:/after: match Google's page date (often the index date)."
	say "  • AROUND(n) is undocumented but functional."
	say "  • source:/location: expect the News vertical; imagesize: the Images tab."

	say "${BLUE}${BOLD}========================================================================${NC}"
	pause
}

# MAIN ENTRY POINT
#
build_search() {
	while true; do
		cls
		say "${BLUE}${BOLD}========================================${NC}"
		say "${YELLOW}${BOLD}QUERY WORKBENCH${NC} ${DIM}(${#PARTS[@]} tokens)${NC}"
		say "${BLUE}${BOLD}========================================${NC}"
		if ((${#PARTS[@]} == 0)); then
			say "${RED}Current query: (empty)${NC}"
		else
			printf '%s\n' "${GREEN}${BOLD}Current query:${NC} ${PARTS[*]}"
		fi
		say ""
		say "${CYAN}— TERMS & LOGIC —${NC}"
		say "  1 Keywords       2 Exact phrase    3 OR alternatives"
		say "  4 Group ( )      5 Exclude -term   6 Wildcard *"
		say "  7 Range ..       8 Proximity AROUND(n)"
		say "${CYAN}— PAGE / CONTENT FILTERS —${NC}"
		say "  9 site:         10 inurl:         11 intitle:"
		say " 12 intext:       13 inanchor:      14 filetype:"
		say " 15 after: / before:"
		say "${CYAN}— SPECIALTY / VERTICAL / INSTANT —${NC}"
		say " 16 source: location: imagesize: define: weather:"
		say "    maps: movie: flights conversion"
		say "${CYAN}— TOOLS —${NC}"
		say "  p Presets   u Undo last   c Clear all"
		say "  ${BOLD}g Generate query + URL${NC}   q Back to main menu"
		say ""
		ask "Select: "
		case "$(trim "$REPLY")" in
		1) op_keywords ;;
		2) op_exact ;;
		3) op_or ;;
		4) op_group ;;
		5) op_exclude ;;
		6) op_wildcard ;;
		7) op_range ;;
		8) op_around ;;
		9) op_filter site ;;
		10) op_filter inurl ;;
		11) op_filter intitle ;;
		12) op_filter intext ;;
		13) op_filter inanchor ;;
		14) op_filter filetype ;;
		15) op_dates ;;
		16) op_special ;;
		p | P) op_preset ;;
		u | U) if ((${#PARTS[@]})); then
			unset "PARTS[$((${#PARTS[@]} - 1))]"
			say "${YELLOW}Removed last token.${NC}"
			sleep 1
		else
			say "${YELLOW}Nothing to undo.${NC}"
			sleep 1
		fi ;;
		c | C) PARTS=() ;;
		g | G) generate ;;
		q | Q) return 0 ;;
		*)
			say "${RED}Invalid choice.${NC}"
			sleep 1
			;;
		esac
	done
}

main_menu() {
	while true; do
		cls
		say "# === //${CYAN}${BOLD} SEARCHOPS.SH ${NC}// ${DIM}v${SCRIPT_VERSION}"
		say ""
		say "${CYAN}1.${NC} Operators"
		say "${CYAN}2.${NC} Build Search"
		say "${CYAN}3.${NC} History"
		say "${CYAN}4.${NC} Exit"
		say ""
		ask "> "
		case "$(trim "$REPLY")" in
		1) show_reference ;;
		2) build_search ;;
		3) show_history ;;
		4)
			say "${RED}Terminated.${NC}"
			exit 0
			;;
		*)
			say "${RED}Invalid option — choose 1-4.${NC}"
			sleep 1
			;;
		esac
	done
}

trap 'printf "\n%s\n" "${YELLOW}Interrupted.${NC}"; exit 130' INT TERM
main_menu "$@"
