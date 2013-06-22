#! /bin/sh
#
#  useprog.sh
#
#  script to read a file from stdin, 
#    store to a temporary file,
#    call specified program on the temporary file
#    and print ascii translation to stdout.
#
# written 12/15/98 by Golda Velez as perl script
# adapted 2001.09.11 Tue by Tong Sun to shell script
# adapted 7/20/04 by Golda to generalize for any program
#
# @Author: Golda Velez
# @Hacker: Tong SUN, (c)2001, all right reserved
# @Version: $Date: 2003/09/02 17:46:40 $ $Revision: 1.2 $
# @Home URL: http://xpt.sourceforge.net/
# 
# Distribute freely, but please include the author's info & copyright,
# the file's version & url with the distribution.
#

# == Adjust these contstants to your system.
TEMPDIR="/tmp"
# setup your PATH correctly or use `which cmd` instead, or put full fpath 
PROG=$1

TEMPFILE=$2

if [ -z $TEMPFILE ] ; then
	TEMPFILE='wgtmpfile'
fi

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

cmd="$PROG $tmpfile -"

[ $testing ] && echo "Command is: $cmd" >&2
$cmd

[ $testing ] || rm $tmpfile

