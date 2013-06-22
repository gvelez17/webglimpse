#!/bin/bash
#
#=================================================================#
#
#  usexpdf.sh
#  
# Reads th .pdf in $1, transforms it to text using pdftotext,
# tries to retrieve medline record for it using bi-T-eutil.pl,
# generated bibtex record from medline using medlars2bib.pl and
# returns everything to webglimpse in structured query enabled
# Harvest SOIF format for indexing via STDOUT.
#
#
# Note that this script needs relies on PreFilter.pm having
#
#  `$prog  "$fname" >"$target"`;
#
# and .glimpse_filters containing the lines
#
#  *.PDF        |WGHOME|/lib/usexpdf.sh     
#  *.pdf	|WGHOME|/lib/usexpdf.sh
#
# which will guarantee that the .pdf's filename 
# is handed as parameter $1 to this script.
#
#
# You must have pstotext and ghostscript already installed.
# Set the PATH to them here:

export PATH=/usr/local/bin:$PATH;

# (c) Boku Bioinformatics, Vienna, Austria
#     Thomas Tuechler, David Kreil  2006
#
#
#=================================================================#


#defining some extensions
PDFEXT=.pdf
SUPEXT=.suppl		  # This is too restrictive. Allow all files! [dpk]
AUTEXT=.ag                      #"ag" used in CutomOutputTool.pm
MEDEXT=.medl                    #"medl" used in usexpdf.sh
ANNEXT=.anno                    #"anno" used in CustomOutputTool.pm
HTMEXT=.html                    #"html" used in CustomOutputTool.pm
CGIEXT=.cgi                     #"cgi" used in CustumOutputTool.pm
BIBEXT=.bib                     # BibTeX bibliography files
TXTEXT=.txt

#getting the parameters
USEXPDF="$0"
NAMEPDF="$1"

CLIBP="${USEXPDF%/*}"            #current library path
CARCP="${CLIBP%/*}/archives"     #current archive path
CFILP="${NAMEPDF%/*}"            #current file path
NAME="${NAMEPDF##*/}"            #current file's basename
NAME="${NAME%.*}"

[ -z "$USER" ] && USER=anon;


#rename uppercase .PDFs to pdf (CustomOutputTool links everyhing to .pdf!)
[ -s "$CFILP/$NAME".PDF ] && mv "$CFILP/$NAME".PDF "$CFILP/$NAME"$PDFEXT


#check for executable pdftotext
PDFTOTEXT="pdftotext";
PDFTTTEST=`which $PDFTOTEXT 2>/dev/null`;
[ -z "$PDFTTTEST" ] && PDFTTTEST="$CLIBP/$PDFTOTEXT";
if [ \! -e "$PDFTTTEST" ]; then
    echo "###ERROR: Cannot locate $PDFTOTEXT - aborted.";
    echo;
    exit;
fi;
PDFTOTEXT="$PDFTTTEST";


#check for existing medline retriever
MLRETRIEVER="wrMedline.pl";
MLRETTEST=`which $MLRETRIEVER 2>/dev/null`;
[ -z "$MLRETTEST" ] && MLRETTEST="$CLIBP/$MLRETRIEVER";
if [ \! -e "$MLRETTEST" ]; then
    echo "###ERROR: Cannot locate $MLRETRIEVER - aborted.";
    echo;
    exit;
fi;
MLRETRIEVER="$MLRETTEST";


#check for existing medline to bibtech converter
MEDLTOBIB="medlars2bib.pl";
MTOBTEST=`which $MEDLTOBIB 2>/dev/null`;
[ -z "$MTOBTEST" ] && MTOBTEST="$CLIBP/$MEDLTOBIB";
if [ \! -e "$MTOBTEST" ]; then
    echo "###ERROR: Cannot locate $MEDLTOBIB - aborted.";
    echo;
    exit;
fi;
MEDLTOBIB="$MTOBTEST";



#init medline log files
MLENTRY="$CARCP/wrMedline_$USER-$$.tmp";
MLLOG="$CARCP/.wrMedline.log";
[    -s "$MLLOG"    ] && echo "$NAMEPDF" >> "$MLLOG";
[ \! -s "$MLLOG"    ] && echo "$NAMEPDF" >  "$MLLOG";



#add md5sum to md5file if not listed already
#(eg. changes in annotation cause relisting!)
MD5MAKER='md5sum';
MD5TEST=`which $MD5MAKER 2>/dev/null`;
if [ -e "$MD5TEST" ]; then
    MD5SUMS="$CARCP/.wrMD5sums";
    MD5SUM=`"$MD5MAKER" "$NAMEPDF"`
    MD5LISTED=`grep "$NAMEPDF" "$MD5SUMS" 2>/dev/null`;
    [ -z "$MD5LISTED" ] && echo "$MD5SUM" >> "$MD5SUMS";
fi



#STDOUT a header with the file name and path in SOIF format:

#@FILE {
#field_one{5}:   value
#field_two{4}:   empty
#}

#NOTE: SOIF needs correct lengths and a tab before the value!
#      if these are wrong anything below in the stream is doomed to fail
#      without proper error messages!
#      also be aware, that '@FILE { url/of/file with blanks.pdf' will
#      fail as well at some point and that simply leaving the url away
#      is not a solution!

echo '@FILE { Boku_Bioninformatics';



#'name{}:' send filename to STDOUT
NAMEPDFSIZE="${#NAMEPDF}";
let NAMEPDFSIZE=NAMEPDFSIZE+1;
echo -e "name{""$NAMEPDFSIZE""}:\t""$NAMEPDF";



#'full{}:' send pdftext to STDOUT (with replacing of formfeeds)
TXTFILE="$CFILP/$NAME$AUTEXT$TXTEXT";
if [ \! -s "$TXTFILE" ]; then
    "$PDFTOTEXT" -q "$NAMEPDF" - | sed -e 's/\n/\r\n/g' -e 's/\f/\r\n/g' \
	> "$TXTFILE";
fi;

TXTFILESIZE=$(stat -c%s "$TXTFILE");
echo -en "full{""$TXTFILESIZE""}:\t";
cat "$TXTFILE";



#'suppl{}:' send supplements to STDOUT if available
#           (they need to be pdf or text already!)
#           standard format for supplements is:
#           name.pdf.01.suppl, name.txt.02.suppl, ...

SUPPLTEST="$CFILP/$NAME$AUTEXT$SUPPLEXT";
find "$CFILP/$NAME"*"$SUPEXT" 2>/dev/null > "$SUPPLTEST";
if [ -s "$SUPPLTEST" ]; then
    while read  SUPPL; do
	SUPFILE="$SUPPL$AUTEXT$TXTEXT";	    
	SUPTY="${SUPPL%.suppl}";
	SUPTY="${SUPTY%.*}";
	SUPTY="${SUPTY##*.}";

	if ( [ "$SUPTY" = pdf ] || [ "$SUPTY" = PDF ] ); then
	    "$PDFTOTEXT" -q "$SUPPL" - | sed -e 's/\n/\r\n/g' -e 's/\f/\r\n/g' \
		> "$SUPFILE";
	else
	    cp "$SUPPL" "$SUPFILE";
	fi

	SUPFILESIZE=$(stat -c%s "$SUPFILE");
	echo -en "suppl{""$SUPFILESIZE""}:\t";
	cat "$SUPFILE";

	rm -f "$SUPFILE";
    done < "$SUPPLTEST";
else
    echo -e "suppl{7}:\tnosuppl";
fi



#'bibf{}:' take care of the bibliography
#          with medline preceeding over bibtex

MEDLINE=`ls "$CFILP/$NAME"*"$MEDEXT" 2>/dev/null | tail -1`;
BIBTEX=`ls "$CFILP/$NAME"*"$BIBEXT" 2>/dev/null | tail -1`;

if [ -n "$MEDLINE" ]; then

    #check if .medl or .ag.medl
    if [ -s "$CFILP/$NAME$MEDEXT" ]; then
	MEDFILE="$CFILP/$NAME$MEDEXT";
	MEDTYP='manmedl';
    elif [ -s "$CFILP/$NAME$AUTEXT$MEDEXT" ]; then
	MEDFILE="$CFILP/$NAME$AUTEXT$MEDEXT";
	MEDTYP='cagmedl';
    fi

else

    #try to retrieve medline from pubmed
    [ -s "$MLENTRY" ] && rm "$MLENTRY";    

    cat "$TXTFILE" | "$MLRETRIEVER" -m "$MLENTRY" -l "$MLLOG";

    if [ \! -s "$MLENTRY" ]; then
	touch "$CFILP/$NAME$AUTEXT$MEDEXT";
	MEDTYP='nomedl';
    elif [ -s "$MLENTRY" ]; then
	MEDFILE="$CFILP/$NAME$AUTEXT$MEDEXT";
	cp -p "$MLENTRY" "$MEDFILE";
	MEDTYP='agmedl';
    fi
fi

#send medline file ...
if [ -s "$MEDFILE" ]; then

    MEDFILESIZE=$(stat -c%s "$MEDFILE");
    if [ -n "$MEDFILESIZE" ] && [ "$MEDFILESIZE" -gt 0 ]; then
	echo -en "bibf{""$MEDFILESIZE""}:\t";
	cat "$MEDFILE";
    fi;

    # create bibtex from medline
    BIBFILE="$CFILP/$NAME$AUTEXT$BIBEXT";
    if [ -s "$CFILP/$NAME$BIBEXT" ]; then
	BIBTYP="manbib";
    else
	if [ -s "$CFILP/$NAME$AUTEXT$BIBEXT" ]; then
	    BIBTYP="cagbib";
	else
	    $MEDLTOBIB "$MEDFILE" > "$BIBFILE";
	    BIBTYP="agbib";
	fi
    fi

#... OR bibtex ...
elif [ -n "$BIBTEX" ]; then

    MEDTYP='nomedl';

    #check if .bib or .ag.bib
    if [ -s "$CFILP/$NAME$BIBEXT" ]; then
	BIBFILE="$CFILP/$NAME$BIBEXT";
	BIBTYP='manbib';
    elif [ -s "$CFILP/$NAME$AUTEXT$BIBEXT" ]; then
	BIBFILE="$CFILP/$NAME$AUTEXT$BIBEXT";
	BIBTYP='cagbib';
    fi

    #TODO: automatic retrieval of bibtexs.
    
    BIBFILESIZE=$(stat -c%s "$BIBFILE");

    if  [ -n "$BIBFILESIZE" ] && [ "$BIBFILESIZE" -gt 0 ]; then
	echo -en "bibf{""$BIBFILESIZE""}:\t";
	cat "$BIBFILE";
    fi;

#... OR nothing to STDOUT
else

    MEDTYP='nomedl';
    BIBTYP='nobib';
fi




#'bibt{}:' send bibliography types to STDOUT
MEDTYPSIZE=${#MEDTYP};
BIBTYPSIZE=${#BIBTYP};

[ $MEDTYPSIZE -gt 0 ] && echo -e "bibt{"$MEDTYPSIZE"}:\t"$MEDTYP;
[ $BIBTYPSIZE -gt 0 ] && echo -e "bibt{"$BIBTYPSIZE"}:\t"$BIBTYP;



#'anno{}:' send annotation to STDOUT if available
ANNOTAT=`ls $CFILP/$NAME$ANNEXT 2>/dev/null | head -1`;
if [ \! -z "$ANNOTAT" ]; then
    let ANNOTATSIZE=$(stat -c%s "$ANNOTAT")+12;
    echo -en "anno{""$ANNOTATSIZE""}:\t";
    cat "$ANNOTAT";
else
    echo -e "anno{19}:\tnoanno";
fi
echo;
echo 'end_of_anno';



echo '}';



#clear the temporary text file
rm -f "$TXTFILE";
rm -f "$SUPPLTEST";
rm -f "$MLENTRY";
