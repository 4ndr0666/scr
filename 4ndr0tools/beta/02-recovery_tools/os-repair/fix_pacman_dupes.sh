#!/bin/bash
# shellcheck disable=all

# Function to identify duplicate packages
identify_duplicates() {
    duplicates=($(pacman -Qq | sort | uniq -d))
}

# Function to remove and reinstall duplicates in batches
handle_duplicates() {
    local batch_size=20
    local total_packages=${#duplicates[@]}
    local total_batches=$(( (total_packages + batch_size - 1) / batch_size ))

    for ((batch=0; batch<total_batches; batch++)); do
        start=$((batch * batch_size))
        end=$((start + batch_size))
        echo -e "\e[1;34mHandling batch $((batch+1)) of $total_batches...\e[0m"

        # Remove duplicates in the current batch
        for ((i=start; i<end && i<total_packages; i++)); do
            pkg=${duplicates[i]}
            echo -e "\e[1;31mRemoving $pkg...\e[0m"
            sudo pacman -Rns --noconfirm $pkg
            if [ $? -ne 0 ]; then
                echo -e "\e[1;31mFailed to remove $pkg. Skipping...\e[0m"
            fi
        done

        # Reinstall duplicates in the current batch
        for ((i=start; i<end && i<total_packages; i++)); do
            pkg=${duplicates[i]}
            echo -e "\e[1;32mReinstalling $pkg...\e[0m"
            sudo pacman -S --noconfirm $pkg
            if [ $? -ne 0 ]; then
                echo -e "\e[1;31mFailed to reinstall $pkg. Skipping...\e[0m"
            fi
        done

        echo -e "\e[1;34mBatch $((batch+1)) of $total_batches completed.\e[0m"
    done
}

# Function to provide final system update and cleanup
final_update() {
    echo -e "\e[1;36mPerforming final system update...\e[0m"
    sudo pacman -Syu --noconfirm
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32mSystem update completed successfully!\e[0m"
    else
        echo -e "\e[1;31mSystem update encountered errors.\e[0m"
    fi
}

# Main function
main() {
    echo -e "\e[1;36mIdentifying duplicate packages...\e[0m"
    identify_duplicates
    if [ ${#duplicates[@]} -eq 0 ]; then
        echo -e "\e[1;32mNo duplicate packages found. Exiting...\e[0m"
        exit 0
    else
        echo -e "\e[1;33mFound ${#duplicates[@]} duplicate packages.\e[0m"
        handle_duplicates
        final_update
    fi
}

# Execute main function
main
