# httpget uses httpget.c and utils.h in the lib directory
# html2txt is a very simple text-parsing program to strip HTML tags

# It has been compiled on the following platforms
#  sunos solaris osf linux
# I am not able to port it and test it on every platform.

# This will get called from the wginstall script.
# Sunos, Linux use gcc
# Solaris requires specifying the nsl and socket libaries
# OSF uses cc
# 'another-config' uses gcc and the libraries

# If your OS isn't supported, try compiling (using make) for each
# option; if it compiles cleanly for one of the supported options,
# httpget should work just fine (you can test it from the command line).

# Good luck!



CC = gcc

OSFCC = cc
IRIXCC = cc

linux:
	$(CC) -O -o lib/httpget lib/httpget.c 
	$(CC) -O -o lib/html2txt lib/html2txt.c


linuxsocks:
	$(CC) -O -DSOCKS  -lsocks5 -o lib/httpget lib/httpget.c 
	$(CC) -O -o lib/html2txt lib/html2txt.c


freebsd:
	$(CC) -O -o lib/httpget lib/httpget.c 
	$(CC) -O -o lib/html2txt lib/html2txt.c

sco:
	$(CC) -Dsco -DSYSV -s -O -o lib/httpget lib/httpget.c -lsocket
	$(CC) -Dsco -DSYSV -s -O -o lib/html2txt lib/html2txt.c -lsocket

sunos:
	$(CC) -O -o lib/httpget lib/httpget.c
	$(CC) -O -o lib/html2txt lib/html2txt.c

solaris:
	$(CC) -O -o lib/httpget lib/httpget.c -lnsl -lsocket
	$(CC) -O -o lib/html2txt lib/html2txt.c

osf:
	$(OSFCC) -O -o lib/httpget lib/httpget.c
	$(OSFCC) -O -o lib/html2txt lib/html2txt.c

hpux:
	$(OSFCC) -D_HPUX_SOURCE -Aa -O -o lib/httpget lib/httpget.c
	$(OSFCC) -D_HPUX_SOURCE -Aa -O -o lib/html2txt lib/html2txt.c

irix:
	$(IRIXCC) -O -o lib/httpget lib/httpget.c -lnsl -lsocket
	$(IRIXCC) -O -o lib/html2txt lib/html2txt.c

another-config:
	$(CC) -O -o lib/httpget lib/httpget.c -lnsl -lsocket
	$(CC) -O -o lib/html2txt lib/html2txt.c
