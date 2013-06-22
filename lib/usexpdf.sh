#! /bin/sh
#
#  usexpdf.sh
#
#  script to read a PDF file from stdin, 
#    store to a temporary file,
#    call pdftotext on the temporary file
#    and print ascii translation to stdout.
#
# written 12/15/98 by Golda Velez as perl script
# adapted 2001.09.11 Tue by Tong Sun to shell script
#
# @Author: Golda Velez
# @Hacker: Tong SUN, (c)2001, all right reserved
# @Version: $Date: 2005/04/03 22:33:42 $ $Revision: 1.4 $
# @Home URL: http://xpt.sourceforge.net/
# 
# Distribute freely, but please include the author's info & copyright,
# the file's version & url with the distribution.
#

# You must have pstotext and ghostscript already installed
# See  http://www.research.digital.com/SRC/virtualpaper/pstotext.html
# and  http://www.cs.wisc.edu/~ghost  for more details.

# == Adjust these contstants to your system.
TEMPDIR="/tmp"
# setup your PATH correctly or use `which cmd` instead, or put full fpath 
PDFTOTEXT="pdftotext"


TEMPFILE="xpdftemp"

# uncomment for testing
#testing=T

# == End constants

[ "$1"x = -zx ] && UNGZIP=T

# Get ready for data
tmpfile="$TEMPDIR/$TEMPFILE.$$"	# need not assumes serial processing
if [ $UNGZIP ] ; then
  gzip -d > $tmpfile
else
  cat > $tmpfile
fi

cmd="$PDFTOTEXT $tmpfile - "

[ $testing ] && echo "Command is: $cmd" >&2
#$cmd
$PDFTOTEXT $tmpfile - 

[ $testing ] || rm $tmpfile

