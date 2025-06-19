#!/bin/bash
# shellcheck disable=all

OUTDIR=pacmanlists
OUTFILE=explicit.lst # edit name to your liking

until [ -z "$1" ] ; do
        case $1 in
                -d)
                        OUTDIR="$2"
                        shift
                        shift
                        ;;
                -f)
                        OUTFILE="$2"
                        shift
                        shift
                        ;;
                *)
                        echo unknown parameter $1
                        exit 1
                        ;;
        esac
done

myerrorfunc () {
        echo $1
        exit 1
}


# List explicitly installed packages from repo $1
list_repo_explicit () {
        comm -12 <(pacman -Qqe | sort) <(pacman -Sql $1 | sort)
}

if [ ! -e $OUTDIR ] ; then
        mkdir "$OUTDIR" || myerrorfunc "can not mkdir $OUTDIR"
elif [ -e "$OUTDIR" -a ! -d "$OUTDIR" ] ; then
        myerrorfunc "$OUTDIR exist but not a dir!"
fi

# list ALL explicitly installed packages; TODO: remove base group!
pacman -Qqe > ${OUTFILE}

# explicitly installed
pacman -Qqe  > ${OUTDIR}/${OUTFILE}
# Orphans
pacman -Qtdq > ${OUTDIR}/orphans_${OUTFILE}
# External (often: packages deleted from repos)
pacman -Qqem > ${OUTDIR}/externalpkgs_${OUTFILE}

# list the repos you want to list into separate files here:
for REPO in core extra multilib garuda archcraft chaotic-aur ; do
        list_repo_explicit $REPO > ${REPO}_$OUTFILE
done
