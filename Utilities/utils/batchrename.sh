#!/usr/bin/env bash
VERSION="1.2.4"
_currentdir=$(pwd)
_tempname="TMP129384756XYZ"

heading() {
  echo " ----------------------------------------------------------------------"
  echo "  $2"
  echo " ----------------------------------------------------------------------"
  echo
}

if [ -f "$(dirname "$0")/colors.sh" ]; then
  . "$(dirname "$0")/colors.sh"
else
  heading green "Multi-File Rename ${VERSION}"
fi

echo " You are in the following directory:"
echo " ${_currentdir}"
echo

read -p " Do you want to rename the files in this directory? [y|n] " _consent

if [[ $_consent != [Yy] ]]; then
  echo " Goodbye..."
  exit 1
fi

if [ ! "$(ls -A $_currentdir)" ]; then
  echo " The directory you have specified is empty. Aborting..."
  exit 1
fi

read -p " What would you like the new file name to be? " _newname

if [[ -z $_newname ]]; then
  echo " New name is required. Aborting..."
  exit 1
fi

read -p " What should the starting number be? " _startn

if ! echo $_startn | egrep -q '^[0-9]+$'; then
  echo " Invalid number. Aborting..."
  exit 1
fi

rename() {
  sourcedir=$1
  newname=$2
  i=$3
  n=0
  j="$_startn"
  for filepath in `ls -v "$sourcedir"/*`
    do
    if [[ -f $filepath && ${filepath##*/} != "$newname"* ]]
    then
      filename="${filepath##*/}"
      ext="${filename##*.}"
      echo " ${filename} renamed to ${newname}${j}.${ext}"
      mv "$filename" "${newname}${i}.${ext}"
      ((i++))
      ((j++))
      ((n++))
    fi
  done
  echo -e "\n ${n} files renamed!\n"
}

rename "$_currentdir" "$_tempname" "1"
rename "$_currentdir" "$_newname" "$_startn"
