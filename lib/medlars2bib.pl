#!/usr/bin/perl

#
# Copyright (C) 2001-2006 D Kreil (boku at kreil.org)
#
# in collaboration with hayes@ebi.ac.uk
#

use warnings;
use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

my $cgi=new CGI;


#
# TODO: allow switch for sending content to browser or file
#

# auto-switch: HTMLify if we are run in a browser environment:
my $htmlify=exists $ENV{GATEWAY_INTERFACE};  # for display on the web

$htmlify=0;  # ... for indexing via the web interface, we override this

if ($htmlify) {
    print $cgi->header();  # to display in browser;
    print <<HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
<title>BibTeX @ARGV</title>
</head>
<body>
<pre>
HTML
}

my $USER=$ENV{USER} || "anon";
my $tmpErr="/tmp/medlars2bib_cgi-$USER-$$.err";
open(STDERR,">$tmpErr") or die "Cannot open $tmpErr for output.\n";

my $skipAnnounce=1;
my %ref=();
my @ids=();
my ($id, $id_type);

$id_type='';
if ($#ARGV>=0 && $ARGV[0]=~/^-s(ingle)?/i) {
    print STDERR
	"\n-single option: Forcing parsing without an AN/UI/PMID line!\n\n";
    shift @ARGV;
    $id=$$;
    $id_type='single';
    $ref{$id} = { id_=>$id, $id_type=>$id };
    unshift @ids, $id;
}


my $ln=0;
unless ($id_type) {
    while (<>) {
	++$ln;
	s/\r//g;  # for MS-DOS saved text files
	unless (/^\s*(AN|UI|PMID)\s*-/ || /<\d+>/) {
	    print STDERR "Skipping to first ID line...  [AN|UI|PMID]\n"
		if $skipAnnounce;
	    print STDERR "IGNORED: $_";
	    $skipAnnounce=0;
	    next;
	}
	if (/<\d+>/) {
	    print STDERR;
	    next;
	}
	($id_type,$id)=/^\s*(AN|UI|PMID)\s*-\s*(\w+)/;
	$ref{$id} = { id_=>$id, $id_type=>$id };
	unshift @ids, $id;
#	print STDERR "Scanning ref $id...\n";
	print "% ref $id";
	last;
    }
    if (eof()) {
	print STDERR
	    "\nNo more input. Consider forced parsing with option '-single'. "
		. "Aborted.\n\n";
	&finish;
	exit;
    }
}

my ($typ,$val);
$typ='';
while (<>) {
    s/\r//g;  # for MS-DOS saved text files
    s/([\#%&_{}\$])/\\$1/g;  # TeX escapes
    ++$ln;
    if (/<\d+>/) {
	print STDERR;
	next;
    }
    if (/^\s*\.?$/) {
	$typ='';
	next;
    }
    chomp;
    if (/^\s*(AN|UI|PMID)\s*-/) {
	($id_type,$id)=/^\s*(AN|UI|PMID)\s*-\s*(\w+)/;
	print "\n% ref $id";
	print STDERR "WARNING: $ln: Replacing earlier reference $id\n"
	    if exists $ref{$id};
	$ref{$id} = { id_=>$id, $id_type=>$id };
	push @ids, $id;
#	print STDERR "Scanning ref $id...\n";
	$typ='';
    }
    elsif (/^\s*(AID|AU|ED|SI|RN|ID|GS|CIN|FAU|PHST|GR)\s*-/) {
	# these may have multiple instances
	# NB: PT, too, but we want to test this easily, so we only use the
	#     first PT line for the time being.
	#     MH, too, but then we'd have to treat the multiple line case (*)
	#     for multiple instances, too.
	($typ,$val)=/^\s*(\w+)\s*-\s*(.*?)\s*$/;
	$ref{$id}{$typ}=[] unless exists $ref{$id}{$typ};
	push @{$ref{$id}{$typ}}, $val;
    }
    elsif (/^\s*([A-Z][A-Z]+|\d\d\d\d)\s*-\s/) {
	($typ,$val)=/^\s*(\w+)\s*-\s*(.*?)\s*$/;
	if (exists $ref{$id}{$typ}) {
	    print STDERR
		"WARNING: $ln: Ignoring additional $typ line in ref# $id\n";
	} else {    
	    $ref{$id}{$typ}=$val;
	}
    }
    else {  # append to earlier value (*)
	if ($typ) {
	    ($val)=/^\s*(.*)/;
	    $ref{$id}{$typ}.="\n$val";
	}
	else {
	    print STDERR "WARNING: $ln: ignored '$_'\n";
	}
    }
}

foreach $id (@ids) {
    # try parsing the SO line :-/
    if (exists $ref{$id}{SO}) {
	$_=$ref{$id}{SO};
#	print STDERR "Note:\tAttempting to parse SO line:\n\t$_\n";
	s/[\n\r]+/ /g;
	my %so=();
	($so{IP})=
	    /[,;.]?\s*n(?:umber|o)[. ]?(\d[^,;.]*(:?\([^)]+\))?[^,;. \t]*)/i;
	s/[,;.]?\s*n(?:umber|o)[. ]?(\d[^,;.]*(:?\([^)]+\))?[^,;. \t]*)//i;
	($so{PG})=/[,;.]?\s*p(?:p?|ages?|gs?)[. ]?(\d[^,;. \t]*)/i;
	s/[,;.]?\s*p(?:p?|ages?|gs?)[. ]?(\d[^,;. \t]*)//i;
	($so{VI})=
            /[,;.]?\s*vol(?:ume)?[. ]?(\d[^,;.]*(:?\([^)]+\))?[^,;. \t]*)/i;
	s/[,;.]?\s*vol(?:ume)?[. ]?(\d[^,;.]*(:?\([^)]+\))?[^,;. \t]*)//i;
	($so{TA})=/^\s*([^.,;]+)/;
	s/^\s*([^.,;]+)//;
	($so{DP})=/[,;.]?\s*((?:\w+)?[. ]?(?:19|20)\d\d[^,;. \t]*)/i;
	s/[,;.]?\s*((?:\w+)?[. ]?(?:19|20)\d\d[^,;. \t]*)//i;
#	print STDERR
#	    "`$so{TA}', vol $so{VI}, no $so{IP}, $so{PG} ($so{DP})\n";
#	print STDERR "Note:\tRemaining unparsed SO line:\n\t$_\n"
#	    if /\w/;
	$ref{$id}{TA}=$so{TA} if defined $so{TA} && !exists $ref{$id}{TA};
	$ref{$id}{VI}=$so{VI} if defined $so{VI} && !exists $ref{$id}{VI};
	$ref{$id}{IP}=$so{IP} if defined $so{IP} && !exists $ref{$id}{IP};
	$ref{$id}{PG}=$so{PG} if defined $so{PG} && !exists $ref{$id}{PG};
	$ref{$id}{DP}=$so{DP} if defined $so{DP} && !exists $ref{$id}{DP};
    }
    # construct key: add first letter of author names : last two digits of year
    my $key='';
    my ($snm,$ins,$sfx);
    my $au;
    foreach $au (@{$ref{$id}{AU}}) {
	if ($au=~/^et al/) {
	    $key.="etal";
	    $au='others';
	}
	else {
	    $key.=substr($au,0,1);
	    ($snm,$ins,$sfx)=$au=~/^\s*(.+?)\s*([^a-z]+)(?:\s+(.+))?\s*$/;
	    ($snm)=$au=~/^\s*(.+)\s*$/ unless $snm;
	    $au="$snm";
            unless ($ins) {
                $au="{$au}";
		next;
	    }
	    $au.=',';
	    my $space=' ';
	    do {
		my $inl=substr($ins,0,1);
		$ins=substr($ins,1);
		$au.="$space$inl." if $inl!~/[ \t.,;'-]/;
                if ($inl=~/[-']/) {
		    $au.=$inl;
		    $space='';
		}
		else {
		    $space=' ';
		}
	    } while ($ins);
	    next unless $sfx;
	    $au.=", $sfx";
	}
    }
    $key=$snm if length($key)==1;
    my $year=0;
    if (exists $ref{$id}{DP}) {
	$_=$ref{$id}{DP};
	($year)=/^\s*(19\d\d|20\d\d)/;
	($year)=/^\s*(\d\d\d\d)/ unless $year;
	($year)=/(\d\d\d\d)/ unless $year;
    }
    print STDERR "WARNING: No year for ref $id!\n" unless $year;
    my $yr=substr($year,-2);
    $key.=":$yr";
    print STDERR "Generated key $key for ref $id\n";
    # Quick hack: assume that all references are articles in journals...
    if (!exists $ref{$id}{PT} ||
	( $ref{$id}{PT} ne 'Journal Article' &&
	  $ref{$id}{PT} ne 'Journal Paper'
	)
       ) {
	print STDERR "WARNING: ref $id has PT='$ref{$id}{PT}'!\n";
    }
    # quick hack: assume there are always individual authors...
    my $author=join(" and ",@{$ref{$id}{AU}});
    my $comment='';
    if (exists $ref{$id}{SO} &&
	(!exists $ref{$id}{TA} ||
         !exists $ref{$id}{VI} ||
         !exists $ref{$id}{IP} ||
         !exists $ref{$id}{PG}
	 )
        ) {
        $ref{$id}{SO}=~s/[\n\r]+/ /g;
        $comment="  % $ref{$id}{SO}";
    }
    $ref{$id}{TI}=~s/[.:]+$// if exists $ref{$id}{TI};
    print "
\@Article{$key,$comment
  author = 	 {",$author,"}";
    print ",
  title = 	 {",$ref{$id}{TI},"}"
      if exists $ref{$id}{TI};
    print ",
  journal = 	 {",$ref{$id}{TA},"},
  year = 	 ",$year;
    print ",
  volume = 	 {",$ref{$id}{VI},"}"
      if exists $ref{$id}{VI};
    print ",
  number = 	 {",$ref{$id}{IP},"}"
      if exists $ref{$id}{IP};
    print ",
  pages = 	 {",$ref{$id}{PG},"}"
      if exists $ref{$id}{PG};
    print "\n}\n";
}

sub finish {
    close(STDERR);

    #
    # Dump the saved STDERR to screen as a TeX comment (%)
    #
    print "</pre><br><br><hr>\n" if $htmlify;
    if (-s $tmpErr) {
	print"<br><pre>" if $htmlify;
	print "\n% Standard Error from conversion:\n% \n";
	open(IN,"<$tmpErr") or die "Could not open $tmpErr\n";
	while (<IN>) {
	    s/^/% /;
	    print;
	}
	close(IN);
	print "</pre>\n" if $htmlify;
    }
    print "</body></html>\n" if $htmlify;
    unlink($tmpErr);
}

&finish;
