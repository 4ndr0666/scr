#!/bin/bash

set -e

search_dir="${1:-$HOME/Downloads}"
rubbish_bin="rubbish_bin"
alphabet_dir="alphabetized_folders"
default_password="hef"

if [[ ! -d "$search_dir" ]]; then
    echo "Error: Directory '$search_dir' not found."
    exit 1
fi

mkdir -p "$rubbish_bin"
mkdir -p "$alphabet_dir"

declare -A hashes
declare -a skipped_files

extract_with_password() {
    local file=$1
    local password=$2

    case "$file" in
        *.zip) unzip -n -q -P "$password" "$file" -d "$search_dir" ;;
        *.rar) unrar x -p"$password" -y -o- "$file" "$search_dir" ;;
        *.tar) tar --password="$password" -xf "$file" -C "$search_dir" ;;
        *.tar.gz) tar --password="$password" -zxf "$file" -C "$search_dir" ;;
        *.tar.bz2) tar --password="$password" -jxf "$file" -C "$search_dir" ;;
    esac
}

# Extract compressed files and move them to the corresponding alphabetized folder
while read -r -d $'\0' file; do
    echo "Extracting '$file'"

    if extract_with_password "$file" "$default_password"; then
        first_letter=$(basename "$file" | cut -c 1 | tr '[:lower:]' '[:upper:]')
        if [[ $first_letter =~ [A-Z] ]]; then
            target_dir="${alphabet_dir}/${first_letter}"
            mkdir -p "$target_dir"
            mv "$file" "$target_dir"
        else
            mv "$file" "$rubbish_bin"
        fi
    else
        echo "Failed to extract '$file' with the default password"
        skipped_files+=("$file")
    fi
done < <(find "$search_dir" -type f \( -iname "*.zip" -o -iname "*.rar" -o -iname "*.tar" -o -iname "*.tar.gz" -o -iname "*.tar.bz2" \) -print0 | grep -v -z -E "/(jd|JD)/")

# Check for duplicates and organize files into A-Z folders
find "$search_dir" -type f ! -path "${rubbish_bin}/*" ! -path "${alphabet_dir}/*" -print0 | while read -r -d $'\0' file; do
    md5hash=$(md5sum "$file" | awk '{print $1}')

    if [[ -n "${hashes[$md5hash]}" ]]; then
        echo "Duplicate found: '$file' and '${hashes[$md5hash]}'"
    else
        hashes[$md5hash]="$file"

        first_letter=$(basename "$file" | cut -c 1 | tr '[:lower:]' '[:upper:]')

        if [[ $first_letter =~ [A-Z] ]]; then
            target_dir="${alphabet_dir}/${first_letter}"
            mkdir -p "$target_dir"
            mv "$file" "$target_dir"
        fi
    fi
done

if [[ ${#skipped_files[@]} -gt 0 ]]; then
    echo "The following files could not be extracted with the default password:"
    for skipped_file in "${skipped_files[@]}"; do
        echo "  - $skipped_file"
    done

    while true; do
        read -p "Enter another password, or type 'q' to quit: " new_password
        if [[ "$new_password" == "q" ]]; then
            echo "Exiting."
            break
        else
            remaining_skipped_files=()
            for skipped_file in "${skipped_files[@]}"; do
                if extract_with_password "$skipped_file" "$new_password"; then
                    echo "Successfully extracted '$skipped_file' with the provided password"
                    mv "$skipped_file" "$rubbish_bin"
                else
                    remaining_skipped_files+=("$skipped_file")
                fi
            done
            skipped_files=("${remaining_skipped_files[@]}")

            if [[ ${#skipped_files[@]} -eq 0 ]]; then
                echo "All remaining files have been successfully extracted."
                break
            fi
        fi
    done
fi

echo "Completed. Review the files in '${rubbish_bin}' before deleting them."
