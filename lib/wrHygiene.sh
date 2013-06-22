#/bin/bash
#
# keeps the prints directory in htdocs hygienically clean;
# i.e. removes files that are not pdf, suppl, anno, medl or bib,
# removes blanks from filenames and directories,
# removes orphan suppl, anno, medl or bib files,
# sets all permissions equally.
#
# (c) Thomas Tuechler 2006
#     Boku Bioinformatics, Vienna


# define temporary files
H_NONCONF='wr_nonconform.tmp';
H_BLANK='wr_blanks.tmp';
H_DIRS='wr_dirs.tmp';
H_FILES='wr_files.tmp';
H_ERRLOG='wr_hygerr.log';
H_SUPPL='wr_suppl.tmp';
H_ANNO='wr_anno.tmp';
H_MEDL='wr_medl.tmp';
H_BIB='wr_bib.tmp';

PDFEXT='.pdf';
AUTEXT='.ag';
TXTEXT='.txt';


#initialise error.log file
date > $H_ERRLOG;


# change input file separator
ifs=$IFS;
IFS=$'\t\n' 2>> $H_ERRLOG;


# select files with wrong filetype
echo "Searching for files with wrong filetype...";
find . ! -name '*.pdf' -a ! -name '*.medl' -a ! -name '*.bib' -a ! -name '*.anno' -a ! -name '*.suppl' -a ! -name '*.sh' -a ! -name 'README.txt' -a ! -name '.htaccess' -a ! -name $H_NONCONF -a ! -name $H_ERRLOG -a ! -type d > $H_NONCONF 2>> $H_ERRLOG;


# remove files with wrong filetype
if [ -s $H_NONCONF ]; then
    echo "Removing files with wrong filetype...";
    for i in `cat $H_NONCONF`; do
	rm -v $i 2>> $H_ERRLOG;
    done;
    rm -v $H_NONCONF 2>> $H_ERRLOG;
fi;


# select files or dirs with correct filename and spaces in the name
echo "Searching for files that contain spaces in their names...";
find . \( \( -name '*.pdf' -o -name '*.medl' -o -name '*.bib' -o -name '*.anno' -o -name '*.suppl' \) -o \( -type d  \) \) -a \( -name '* *' \)  > $H_BLANK 2>> $H_ERRLOG;


# turn blanks into underscores
if [ -s $H_BLANKS ]; then
    echo "Renaming files that contain spaces in their names...";
    for i in `cat $H_BLANK`; do
	mv -v $i `echo $i | sed -e 's/\\ /_/g' -e 's/ /_/g'` 2>> $H_ERRLOG;
    done;
fi;


# select suppl files and search for corresponding pdfs
find . -name '*.suppl'> $H_SUPPL 2>> $H_ERRLOG;
if [ -s $H_SUPPL ]; then
    echo "Checking for orphan supplements...";
    for i in `cat $H_SUPPL`; do
	H_PATH=${i%/*};
	H_NAME=${i##*/};
	H_NAME=${H_NAME%.*.*};
	H_PDF=`find $H_PATH -name "$H_NAME*$PDFEXT" | head -1`;
	[ \! $H_PDF ] && H_NAME=${H_NAME%.*};
	H_PDF=`find $H_PATH -name "$H_NAME*$PDFEXT" | head -1`;
	if [ \! $H_PDF ]; then
	    rm -v $i 2>> $H_ERRLOG;
	fi;
    done;
fi;


# select anno files and search for corresponding pdfs
find . -name '*.anno'> $H_ANNO 2>> $H_ERRLOG;
if [ -s $H_ANNO ]; then
    echo "Checking for orphan annotations...";
    for i in `cat $H_ANNO`; do
	H_PATH=${i%/*};
	H_NAME=${i##*/};
	H_NAME=${H_NAME%.*};
	[ .${H_NAME##*.} ==  $AUTEXT ] && H_NAME=${H_NAME%.*};
	H_PDF=`find $H_PATH -name "$H_NAME*$PDFEXT" | head -1`;
	if [ \! $H_PDF ]; then
	    rm -v $i 2>> $H_ERRLOG;
	fi;
    done;
fi;



# select medl files and search for corresponding pdfs
find . -name '*.medl'> $H_MEDL 2>> $H_ERRLOG;
if [ -s $H_MEDL ]; then
    echo "Checking for orphan medlines...";
    for i in `cat $H_MEDL`; do
	H_PATH=${i%/*};
	H_NAME=${i##*/};
	H_NAME=${H_NAME%.*};
	[ .${H_NAME##*.} ==  $AUTEXT ] && H_NAME=${H_NAME%.*};
	H_PDF=`find $H_PATH -name "$H_NAME*$PDFEXT" | head -1`;
	if [ \! $H_PDF ]; then
	    rm -v $i 2>> $H_ERRLOG;
	fi;
    done;
fi;


# select bib files and search for corresponding pdfs
find . -name '*.bib'> $H_BIB 2>> $H_ERRLOG;
if [ -s $H_BIB ]; then
    echo "Checking for orphan BibTeXs...";
    for i in `cat $H_BIB`; do
	H_PATH=${i%/*};
	H_NAME=${i##*/};
	H_NAME=${H_NAME%.*};
	[ .${H_NAME##*.} ==  $AUTEXT ] && H_NAME=${H_NAME%.*};
	H_PDF=`find $H_PATH -name "$H_NAME*$PDFEXT" | head -1`;
	if [ \! $H_PDF ]; then
	    rm -v $i 2>> $H_ERRLOG;
	fi;
    done;
fi;


# select all directories and all conform files and if necessary change 
# the permissions of files to rw-r----- and of dirs to rw-rw----.
echo "Searching for files and directories with deviant permissions...";

find . -mindepth 1 -type d -a ! -perm 754 > $H_DIRS 2>> $H_ERRLOG;
if [ -s $H_DIRS ]; then 
    echo "Adjusting permissions for directories...";
    for i in `cat $H_DIRS`; do
	chmod -c 754 $i 2>> $H_ERRLOG;
    done;
fi;

find . ! -type d -a ! -name '*.sh' -a ! -name '.htaccess' -a ! -perm 644 > $H_FILES 2>> $H_ERRLOG;
if [ -s $H_FILES ]; then
    echo "Adjusting permissions for directories...";
    for i in `cat $H_FILES`; do
	chmod -c 644 $i 2>> $H_ERRLOG;
    done;
fi;


# remove temporary files
echo "Removing temporary files...";
rm $H_NONCONF 2>> $H_ERRLOG;
rm $H_BLANK 2>> $H_ERRLOG;
rm $H_SUPPL 2>> $H_ERRLOG;
rm $H_ANNO 2>> $H_ERRLOG;
rm $H_MEDL 2>> $H_ERRLOG;
rm $H_BIB 2>> $H_ERRLOG;
rm $H_DIRS 2>> $H_ERRLOG;
rm $H_FILES 2>> $H_ERRLOG;


# make some stats
echo;
echo "Archive statictics:";
echo "-------------------";
echo "`find . -type d | wc -l` directories.";
echo "`find . -name '*.pdf' | wc -l` .pdf files.";
echo "`find . -name '*.suppl' | wc -l` .suppl files.";
echo "`find . -name '*.anno' | wc -l` .anno files.";
echo "`find . -name '*.medl' | wc -l` .medl files.";
echo "`find . -name '*.bib' | wc -l` .bib files.";
echo;


# change input file separator
IFS=$ifs 2>> $H_ERRLOG;
