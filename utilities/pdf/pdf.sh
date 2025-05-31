#!/bin/bash
## read below file for details of qpdf usage
# /usr/share/doc/qpdf/qpdf-manual.pdf
#
#
# TRY PDFTRICKS for gui

echo -n "
choose option
    m) merge pdf files
    e) extract pages from pdf
    p) image to pdf
    l) libreoffice document to pdf
    v) djvu to pdf
    d) remove password (decrypt)
    b) get and edit  metadata ( including bookmarks )
    r) rotate pages
    s) optimize for size
    x) exit
#?  "
    # d) delete pages from pdf (untested)
read ops

case $ops in

m)  echo "which files to merge?"
	read -a IN
	echo -n "provide name for output file:"
	read OUT
	# pdfunite ${IN[@]} $OUT.pdf
	pdftk ${IN[@]} cat output $OUT.pdf
    ;;

p)  echo "which image files to convert? e.g., *.jpg"
	read -a IN
	echo -n "provide name for output file:"
	read OUT
#	convert "${IN[@]}" $OUT.pdf
	img2pdf --output $OUT.pdf ${IN[@]}
	;;

l)  echo "which document files to convert? e.g., *.odt"
	read -a IN
#	echo -n "provide name for output file:"
#	read OUT
	libreoffice --headless --convert-to pdf "${IN[@]}"
	;;

v) echo "which djvu file to convert?"
    read -a IN
    OUT="`basename $IN .djvu`"
    OUT="$OUT".pdf
    ddjvu -format=pdf -quality=85 -verbose $IN $OUT ;;
s)
    echo "which pdf file to modify?"
	read -a IN
	echo -n "provide name for output file:"
	read OUT
#   ebook=150dpi, screen=72dpi, printer=300dpi, default=largesize
    gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$OUT" "$IN"
    ;;

e)  echo -n "name the pdf file to extract images from:"
	read IN
	echo -n "first page to extract:"
	read FIRST
	echo -n "last page to extract:"
	read LAST
	echo -n "provide name for output file:"
	read OUT
	# pdfseparate -f $FIRST -l $LAST $IN $OUT%d
    pdftk $IN cat $FIRST-$LAST output $OUT.pdf
    # pdfunite $(echo $OUT*) $OUT.pdf
	;;

r)  echo -n "name the pdf file to rotate pages:"
	read IN
    echo -n "angle of rotation, +90 -90" # left,right,north,south etc with pdftk
    read ANGLE
	echo -n "first page to rotate:"
	read FIRST
	echo -n "last page to rotate:"
	read LAST
	echo -n "provide name for output file:"
	read OUT
	qpdf --rotate=$ANGLE:$FIRST-$LAST $IN $OUT.pdf
#    pdftk $IN rotate $FIRST-$LAST$ANGLE output $OUT.pdf
	;;

d)  echo -n "Which pdf file to decrypt (without .pdf) ?"
        read FILE
        echo -n "Original password ?"
        read PASS
        qpdf --password="$PASS" --decrypt $FILE.pdf $FILE.decrypted.pdf
#        pdftk $FILE.pdf input_pw "$PASS" output $FILE.decrypted.pdf
        ;;

b)  echo -n "Which pdf file (without .pdf) ?"
        read FILE
        pdftk $FILE.pdf dump_data output $FILE.txt
        echo "metadata dumped to $FILE.txt"
        echo "kindly edit the metadata and enter y to proceed"
        read reply
        [[ $reply = y ]] && pdftk $FILE.pdf update_info $FILE.txt output $FILE.bookmarked.pdf
        ;;

# d) echo " example command to remove page 21
        # pdftk $FILE.pdf cat 1-20 22-end $FILE_edited.pdf" ;;
x)	exit
	;;
esac
