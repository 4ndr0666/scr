#!/bin/bash
# shellcheck disable=all

# Merge contents of TheCLoudold and TheCLoudold1 into C
rsync -av --ignore-existing --ignore-times --update --progress --recursive /23.1/TheCLoudold/ /23.1/C
rsync -av --ignore-existing --ignore-times --update --progress --recursive /23.1/TheCLoudold1/ /23.1/C

# Verify merge success
if [ $? -eq 0 ]; then
    echo "Merge successful. Deleting source directories."

    # Delete TheCLoudold and TheCLoudold1 if merge was successful
    rm -r /23.1/TheCLoudold
    rm -r /23.1/TheCLoudold1

    echo "Source directories deleted."
else
    echo "Merge encountered errors. Source directories were not deleted."
fi
