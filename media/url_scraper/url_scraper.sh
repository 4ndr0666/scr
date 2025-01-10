#!/bin/bash

# file: Bash/URL_Scraper/url_scraper.sh
# Author: Avinal Kumar (https://github.com/avinal)
# Description: Scrapes URLs from a given webpage or generates a sequence of image URLs based on a base URL with numerical enumeration. Checks their statuses with enhanced features.
# Usage: sudo ./url_scraper.sh [OPTIONS] url
# Options:
#   -d        List primary domains of every link
#   -r        List only relative links to the site
#   -a        List all image links with numerical enumeration
#   -s        Generate and enumerate a sequence of image URLs based on a base URL with numerical component
#   -h        Display help information

# Exit immediately if a command exits with a non-zero status
set -e

# Define colors and escape sequences for output
LIGHTGREEN='\033[1;32m'
LIGHTRED='\033[1;31m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
WHT='\033[0m'
NC='\033[0J'

# Function to display usage information
usage() {
    echo -e "${CYAN}Usage:${WHT} $0 [OPTIONS] url"
    echo -e "${CYAN}Options:${WHT}"
    echo -e "  -d        List primary domains of every link"
    echo -e "  -r        List only relative links to the site"
    echo -e "  -a        List all image links with numerical enumeration"
    echo -e "  -s        Generate and enumerate a sequence of image URLs based on a base URL with numerical component"
    echo -e "  -h        Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -d https://example.com"
    echo "  $0 -r https://example.com"
    echo "  $0 -a https://example.com"
    echo "  $0 -s https://www.x.com/image1 -n 1 -m 100 -p 2"
    echo ""
    echo "Additional Options for -s:"
    echo "  -n        Starting number of the sequence (default: 1)"
    echo "  -m        Maximum number of images in the sequence (default: 100)"
    echo "  -p        Zero-padding size for numbering (default: 2)"
    echo ""
    exit 1
}

# Function to check dependencies
check_dependencies() {
    local dependencies=(lynx cut grep awk sed sort uniq curl)
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${LIGHTRED}Error: Required command '$cmd' is not installed.${WHT}" >&2
            echo "Please install it and try again."
            exit 1
        fi
    done
}

# Function to confirm execution
confirm_execution() {
    read -p "Are you sure you want to proceed? (y/n): " choice
    case "$choice" in
        y|Y ) echo "Proceeding...";;
        n|N ) echo "Operation cancelled."; exit 0;;
        * ) echo "Invalid input. Operation cancelled."; exit 1;;
    esac
}

# Function to check if the URL points to an HTML page
check_content_type() {
    local url="$1"
    local content_type
    content_type=$(curl -Is "$url" | grep -i "Content-Type:" | awk '{print $2}' | tr -d '\r')

    if [[ "$content_type" != text/html* ]]; then
        echo -e "${LIGHTRED}Error: The provided URL does not point to an HTML page. Please provide a valid HTML page URL.${NC}" >&2
        exit 1
    fi
}

# Function to scrape URLs based on the provided flag
scrape_urls() {
    local flag="$1"
    local url="$2"
    local lastcmd=""
    local basedomain=""

    case "$flag" in
        -d)
            lastcmd="cut -d/ -f3 | sort | uniq"
            ;;
        -r)
            basedomain="$(echo "$url" | awk -F/ '{print $1 "//" $3}')/"
            lastcmd="grep \"^$basedomain\" | sed \"s|$basedomain||g\" | sort | uniq"
            ;;
        -a)
            lastcmd="grep -Ei 'https?://[^ ]+\.(jpg|jpeg|png|gif|bmp|svg)' | sort | uniq"
            ;;
        *)
            lastcmd="sort | uniq"
            ;;
    esac

    # Scrape URLs using lynx and process them based on the flag
    lynx -dump "$url" | \
        sed -n '/^References$/,$p' | \
        grep -E '[[:digit:]]+\.' | \
        awk '{print $2}' | \
        cut -d\? -f1 | \
        eval "$lastcmd"
}

# Function to check the status of scraped URLs
url_check() {
    local mode="$1"
    local append="$2"

    # Initialize counters
    local redirected=0
    local success=0
    local error=0
    local total=0

    # Determine the type of links based on mode
    if [ "$mode" == "-r" ]; then
        lnktp="relative url(s)"
        append="$append/"
    elif [ "$mode" == "-d" ]; then
        lnktp="domain(s)"
        append=""
    elif [ "$mode" == "-a" ]; then
        lnktp="image url(s)"
        append=""
    elif [ "$mode" == "-s" ]; then
        lnktp="sequence url(s)"
        append=""
    else
        lnktp="url(s)"
        append=""
    fi

    # Read each line from the output of scrape_urls and perform HTTP request to find status
    while read -r line; do
        local aline="${append}${line}"
        local sc
        sc=$(curl -Is "$aline" | head -n 1 || echo "HTTP/1.1 000 Connection Failed")
        read -ra code <<< "$sc"
        total=$((total + 1))
        case "${code[1]}" in
            1[0-9][0-9])
                echo -e "${CYAN}$line${NC}" # Informational response
                ;;
            2[0-9][0-9])
                echo -e "${LIGHTGREEN}$line${NC}" # Successful response
                success=$((success + 1))
                ;;
            3[0-9][0-9])
                echo -e "${ORANGE}$line${NC}" # Redirection response
                redirected=$((redirected + 1))
                ;;
            4[0-9][0-9]|5[0-9][0-9]|000)
                echo -e "${LIGHTRED}$line${NC}" # Client or Server error response
                error=$((error + 1))
                ;;
        esac
        echo -ne "${WHT}[found ${CYAN}$total ${WHT}$lnktp: ${LIGHTGREEN}$success OK ${WHT}| ${ORANGE}$redirected Redirected ${WHT}| ${LIGHTRED}$error Broken${WHT}]${NC}\r"
    done < <(scrape_urls "$@")

    # Print summary if no URLs are found
    if [ $total -eq 0 ] && [ $# -ne 0 ]; then
        echo -e "${WHT}[found ${CYAN}$total ${WHT}$lnktp: ${LIGHTGREEN}$success OK ${WHT}| ${ORANGE}$redirected Redirected ${WHT}| ${LIGHTRED}$error Broken${WHT}]${NC}"
    else
        echo "" # Move to a new line after the summary
    fi
}

# Function to enumerate image URLs
enumerate_images() {
    local flag="$1"
    local url="$2"
    local images=()
    local index=1

    echo "Enumerating image URLs..."

    # Scrape image URLs based on the -a flag
    images=($(scrape_urls "$flag" "$url"))

    if [ ${#images[@]} -eq 0 ]; then
        echo -e "${ORANGE}No image URLs found.${NC}"
        return
    fi

    # Enumerate and display image URLs
    for img in "${images[@]}"; do
        echo -e "${LIGHTGREEN}$index.${WHT} $img"
        index=$((index + 1))
    done
}

# Function to generate a sequence of image URLs
generate_sequence() {
    local base_url="$1"
    local start_num="$2"
    local end_num="$3"
    local zero_padding="$4"
    local images=()

    for ((i=start_num; i<=end_num; i++)); do
        printf -v padded_num "%0${zero_padding}d" "$i"
        # Replace the numeric part in the base URL with the current number
        # Assuming the numeric part is at the end before the file extension
        # Example: https://www.x.com/image1.jpg -> https://www.x.com/image01.jpg
        # Modify the regex as per your URL structure
        image_url=$(echo "$base_url" | sed "s/[0-9]\+/$padded_num/")
        images+=("$image_url")
    done

    # Enumerate and display image URLs
    local index=1
    for img in "${images[@]}"; do
        echo -e "${LIGHTGREEN}$index.${WHT} $img"
        index=$((index + 1))
    done

    # Pass the list to url_check for status evaluation
    echo "${images[@]}" | tr ' ' '\n' | url_check "-s" ""
}

# Function to display help information
display_help() {
    usage
}

# Function to handle unknown options
unknown_option() {
    echo -e "${LIGHTRED}Error: Unknown option $1${NC}" >&2
    usage
}

# Main function to orchestrate the script
main() {
    # If no arguments are provided, display usage
    if [ $# -eq 0 ]; then
        usage
    fi

    # Check dependencies
    check_dependencies

    # Initialize variables for -s flag
    local start_num=1
    local end_num=100
    local zero_padding=2

    # Parse options using getopts without a leading colon
    local mode=""
    local url=""
    local opt

    while getopts "drahsn:m:p:" opt; do
        case $opt in
            d)
                if [ -n "$mode" ] && [ "$mode" != "-d" ]; then
                    echo -e "${LIGHTRED}Error: Multiple modes selected. Please choose only one option at a time.${NC}" >&2
                    usage
                fi
                mode="-d"
                ;;
            r)
                if [ -n "$mode" ] && [ "$mode" != "-r" ]; then
                    echo -e "${LIGHTRED}Error: Multiple modes selected. Please choose only one option at a time.${NC}" >&2
                    usage
                fi
                mode="-r"
                ;;
            a)
                if [ -n "$mode" ] && [ "$mode" != "-a" ]; then
                    echo -e "${LIGHTRED}Error: Multiple modes selected. Please choose only one option at a time.${NC}" >&2
                    usage
                fi
                mode="-a"
                ;;
            s)
                if [ -n "$mode" ] && [ "$mode" != "-s" ]; then
                    echo -e "${LIGHTRED}Error: Multiple modes selected. Please choose only one option at a time.${NC}" >&2
                    usage
                fi
                mode="-s"
                ;;
            n)
                start_num="$OPTARG"
                ;;
            m)
                end_num="$OPTARG"
                ;;
            p)
                zero_padding="$OPTARG"
                ;;
            h)
                display_help
                ;;
            \?)
                echo -e "${LIGHTRED}Error: Invalid option -$OPTARG${NC}" >&2
                usage
                ;;
            :)
                echo -e "${LIGHTRED}Error: Option -$OPTARG requires an argument.${NC}" >&2
                usage
                ;;
        esac
    done
    shift $((OPTIND -1))

    # Check if URL is provided
    if [ -z "$1" ]; then
        echo -e "${LIGHTRED}Error: URL is required.${NC}" >&2
        usage
    fi

    url="$1"

    # Check if the mode is sequence generation
    if [ "$mode" == "-s" ]; then
        # Confirm execution
        confirm_execution
        echo "Generating and enumerating sequence of image URLs from $url:"
        generate_sequence "$url" "$start_num" "$end_num" "$zero_padding"
        exit 0
    fi

    # If not sequence generation, proceed with existing modes
    # Check if the URL points to an HTML page
    check_content_type "$url"

    # Confirm execution
    confirm_execution

    # Execute based on the mode
    case "$mode" in
        -d)
            echo "Listing primary domains of every link from $url:"
            scrape_urls "$mode" "$url" | url_check "$mode" "$url"
            ;;
        -r)
            echo "Listing only relative links to the site from $url:"
            scrape_urls "$mode" "$url" | url_check "$mode" "$url"
            ;;
        -a)
            echo "Listing all image links with numerical enumeration from $url:"
            enumerate_images "$mode" "$url"
            echo "Checking statuses of image URLs:"
            scrape_urls "$mode" "$url" | url_check "$mode" "$url"
            ;;
        *)
            echo -e "${LIGHTRED}Error: No valid option selected.${NC}" >&2
            usage
            ;;
    esac
}

# Invoke the main function with all script arguments
main "$@"

exit 0
