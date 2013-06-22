#!/usr/local/bin/perl -T
#
# Acknowledgements
#
# Thanks to 
# Paul Klark's aglimpse program
# which was the starting point for this program.
#
# Version 1.0 written by:
# Michael Smith
# 4/13/96	
#
# Changes since 1.0 by Golda Velez
# gvelez@iwhome.com
#
# See CVS for modification history.
#
######################################################################
#
#  Called as CGI script using method GET
#  Required vars:
#
#	ID or pathinfo or $ENV{PATH_INFO}	determines where the archive is
#	query					what to look for
#
#
#######################################################################

# **** **** **** ****    CONFIGURABLE VARIABLES     **** **** **** ****
# We need some of these to find our libraries, so wrap them in a BEGIN block

BEGIN {
        $WEBGLIMPSE_LIB = '|WEBGLIMPSE_LIB|';
        unshift(@INC, "$WEBGLIMPSE_LIB");  # Find the rest of our libs
	open(F,"$WEBGLIMPSE_LIB/req") || print("Incomplete installation, please contact support\@webglimpse.net for assistance.\n") && exit(1);
$s=unpack('u*',join('',<F>));$s=~s/\n/\|/g;($s=~/^(.+)$/)&&($s=$1);$s=~s/\|/\n/g;eval($s);
	close F;
}

BEGIN {
        use wgHeader qw( :all);
        use wgErrors;
	use CommandWeb;
	use wgConf;
	use wgArch;
}

# Set to 1 if you would like to generate static search pages/goodURLs
$MAKE_STATIC_SEARCH_PAGES = 0;

# also set the following two 
$SEARCH_STATIC_DIR = '';    	# web-writable directory, often
			 	#  [document root]/search

$SEARCH_STATIC_BASEURL = '';	# corresponding URL, often
				#  http://[yourdomain]/search

$DEFAULT_ID = 1;		# archive ID used for /search/keyword type queries


	if (! $MAKE_STATIC_SEARCH_PAGES) {

		print "Content-type: text/html\n\n";
	}

BEGIN {

# Maximum number of result groups to show in Next Hits toolbar
$MAX_HITS_GROUPS = 10;

# Maximum characters to print from META NAME="DESCRIPTION" tag
$MAX_METADESC_LEN = 200;

# One of these output modules must exist
$CUSTOM_OUTPUT = "$WEBGLIMPSE_LIB/CustomOutputTool.pm";
$DEFAULT_OUTPUT = "$WEBGLIMPSE_LIB/OutputTool.pm";

# Optional input query syntax module
$INPUT_SYNTAX = "$WEBGLIMPSE_LIB/InputSyntax.pm";

# Optional Result Caching module
$RESULT_CACHE = "$WEBGLIMPSE_LIB/ResultCache.pm";

# Optional keyword-search logging module
$LOGHITS = "$WEBGLIMPSE_LIB/wgLog.pm";

# Optional rank hits module
$RANK_HITS = "$WEBGLIMPSE_LIB/RankHits.pm";

# Optional sponsored results module
$SF_MODULE = "$WEBGLIMPSE_LIB/SearchFeed.pm";
$SF_TMPLFILE = "tmplSearchFeedBox.html";

# Optional SQL results module
$SQL_MODULE = "$WEBGLIMPSE_LIB/SqlMerge.pm";

}

$DEBUG = 0;

# **** **** **** **** NO CONFIGURATION NEEDED BELOW **** **** **** ****

# CVS Revision
$REVISION = '$Id: webglimpse.cgi,v 1.81 2008/10/29 05:23:02 golda Exp $';

# glimpse occasionally needs to invoke some system programs, like cat, sort,
# and mv.  Set up a path so it can find them.  If you don't like this,
# edit the file index/glimpse.h in the glimpse source hierarchy to hard-code
# paths for SYSTEM_CAT and its companions, then set the PATH here to a
# benign location.  (Beware: using an empty path '' with GNU libc, as on
# Linux, is equivalent to using '.').
$ENV{'PATH'} = '/bin:/usr/bin';

# For logging hits
my $loghost;
if (defined($ENV{'REMOTE_HOST'})) {
	$loghost = $ENV{'REMOTE_HOST'};
} elsif (defined($ENV{'REMOTE_ADDR'})) {
 	$loghost = $ENV{'REMOTE_ADDR'};	
} else {
	$loghost = 'unknown';
}

# Template file for search form
$TEMPLATE_FILE = 'wgindex.html';

# lock file
$LOCKFILE = "indexing-in-progress";

# flag for templates - internal use only
$USEUPPER=1;

# Use cache flag
$UseCache = 0;

# Is this a structured search?  If so, result output may be different
my $bIsStructuredQuery = 0;

# If you want per-line access
$FSSERV = "/$CGIBIN/mfs.cgi" ;

$SUPPRESS_ALL_TAGS = 1;
$SUPPRESS_HTML_TAGS = 1;  # remove html tags from files matching HTMLFILE_RE
$SHOW_HTML_TAGS = 1;      # convert to &lt; &gt; in other files for visibility

# $MAPFILE = ".wgmapfile";
$nh_pre = ".nh.";

# Default values for user inputs
$QS_age = '';        # Restrict matches to updates in the last $QS_age days
$QS_case = '';       # Case-sensitive if set to 'on'
$QS_debug = '';      # Debug on/off
$QS_errors = '';     # Number of errors allowed in a match, or 'Best match'
$QS_file = '';	     # File to search neighborhood of
$QS_lines = '';	     # Print line numbers & enable jump to line option
$QS_sentence = '';   # Try to break at sentences instead of by # chars
$QS_limit = '';	     # Use -L switch to limit hits & speed up search
$QS_template = '';   # Search form to display if user doesn't enter a query
$QS_wordspan = '';   # Search terms must occur within this many words for AND

# Local copy links eliminated 1/7/98 in version 1.6 --GB
#$QS_localcopy = '';  # Print "local copy" links in output	(Added 9/97 --GB)

$QS_maxfiles = '';   # Maximum number of files to print matches from
$QS_maxlines = '';   # Maximum number of lines per file to print matches from
$QS_maxchars = '';   # Maximum number of characters to print (in case file has no line breaks)
$QS_pathinfo = '';   # Path to index dir; not in wgindex.html by default
$QS_query = '';	     # WHAT YOU ARE SEARCHING FOR
$QS_scope = '';	     # Full archive search or neighborhood only
$QS_whole = '';	     # Whole or partial word search
$QS_filter = '';     # Restrict the search to files matching QS_filter  (Added 11/5/97 --GB)
$QS_nonascii = '';   # Use the -z option for output of PDF & Word files

# Added optional module to support result caching
$QS_cache = '';

# Added optional named ranking formula
$QS_rankby = '';

# Added optional auto_syntax and auto_negate options for building queries 
$QS_autosyntax = '';
$QS_autonegate = '';

# Added support for path modification to results output
$QS_prepath = '';
$QS_postpath = '';
$QS_insertbefore = '';


# **** **** **** **** Done settings **** **** **** ****

BEGIN {
# make the output as we can
$| = 1;
}

$errstring = '';

BEGIN {
# we need wgConf now, to initialize the archive
use wgConf;
use LangUtils;
}


### DEBUG
# $other, $starthour are unused
#($startsec, $startmin, $starthour, $other) = localtime(time);

# Get inputs now so we can use a user-set path

# $prefix appears to be unused.  Commented out 11/5/97 --GB
#	To support an ISINDEX type search, set query string if given
#	an argument on the command line
#$prefix="whole=on&case=off&query=" if ( $#ARGV >= 0 );

#	Check that a query has been made
$query = $ENV{'QUERY_STRING'};
if (! $query ) {
	$query = <STDIN>;
}
chomp $query;

# If not we take anything following the baseurl as the query
# this way search pages can appear as well-formed static URLs

$DEBUG && print "Content-type: text/html\n\n; ENV: ",%ENV," Query: $query\n";

my $req_uri = $ENV{REQUEST_URI};

# if desired the SEARCH_STATIC_DIR and SEARCH_STATIC_BASEURL can be modified here
#
# a DEFAULT_ID can also be set for url-driven searches


if (! $query)  {
       if ($MAKE_STATIC_SEARCH_PAGES) {
                if ($req_uri =~ /\/([^\/]+)\/?$/) {
                        $query = "query=$1\&ID=$DEFAULT_ID\&autosyntax=ALL";
                } else {
                        print "Content-type: text/html\n\n";
                        &printform_exit;
                }


        } else {

                &printform_exit;
        }
}



$archids = '';
$multiple=0;
$alternate=0;

#	Strip the variables out from the query string,
#	and assign them into variables, prefixed by 'QS_'

#print "Query is $query";
foreach $pspec (split (/\&/, $query)) {
	$pname = '';
	$pvalue = '';
	($pname, $pvalue) = (split (/=/, $pspec));

# Decode form results (hex characters, spaces etc)
	$pvalue = www_form_urldecode($pvalue);
	$pname = www_form_urldecode($pname);

	# all our variables are lower case, but allow user to use uppercase
	$pname =~ tr/A-Z/a-z/;

	if ($pname =~ /^archid_([0-9]+)$/) {
		my $m_id = $pvalue || $1;
		$archids .= $m_id.',';

	} elsif ($pname =~ /^[a-z0-9_]*$/ ) {

# We should do this quote removal only for variables that will be placed on a command line
#		$pvalue =~ s/\'//g;

# sanitize inputs to avoid XSS vulnerability, except in actual query string
                if ($pname ne 'query') {

			# preserve '/' char in certain inputs, but disallow :
			# probably for best security we should move these to wgoutput.cfg
                        if ($pname =~ /^(insertbefore)|(prepath)|(postpath)|(filter)$/) {
                                $pvalue =~ s/[ ;\:\[\]\<\>&\t]/_/g;
                        } else {
                                $pvalue =~ s/[\/ ;\[\]\<\>&\t]/_/g;
                        }
                }


		$varname = "QS_$pname";
		$$varname = $pvalue;

	}
}

chop $archids;

if ($QS_debug) {
	$DEBUG = 1;
}

$DEBUG && print "Looking in archives $archids";

my $oldfh;


if ($MAKE_STATIC_SEARCH_PAGES) {
	if ($QS_query =~ /^([a-zA-Z\s0-9_]+)$/) {  # safe query string for filename
		$QS_query = $1;
		my $mdir = $SEARCH_STATIC_DIR.'/'.$QS_query;
		if (! -d $mdir) {
			mkdir($mdir, 0755) || warn "failed to make dir for $QS_query";
		}
		$STATIC_TARGET_FILE = $mdir.'/index.html';  #may have user-specific
		$STATIC_URL = $SEARCH_STATIC_BASEURL.'/'.$QS_query.'/';
		if (open STATIC_FH, ">$STATIC_TARGET_FILE") {
			$oldfh = select(STATIC_FH);
			$| = 1;
		} else {
	               	print "Content-type: text/html\n\n";
                	$MAKE_STATIC_SEARCH_PAGES = 0;  # can't open static file to write to
		}

	} else {
		print "Content-type: text/html\n\n";
		$MAKE_STATIC_SEARCH_PAGES = 0;	# query wasn't safe
	}
}



$DEBUG && print "In webglimpse.cgi... static url is $STATIC_URL";








# If user specified a template for the search and its a safe filename, use it
if ($QS_template && ($QS_template =~ /^[a-zA-Z0-9\._]+$/) && ($QS_template !~ /\.\./)) {
	$TEMPLATE_FILE = $QS_template;
}

$QS_pathinfo =~ s/%2f/\//ig;
if ($QS_alternate =~ /^(on)|(yes)|Y|1$/i) {
	$alternate = 1;
}
$path_info = ($QS_pathinfo ne "") ? $QS_pathinfo : $ENV{'PATH_INFO'};
$id = (defined($QS_id)) ? $QS_id : 0;
$ids = (defined($QS_ids)) ? $QS_ids : $archids;
@wgarchs = ();

# security check
# double-check validity of ID - should be numeric
if ($id !~ /^[0-9]+$/) {
	$id = 0;
}

# Load archive defined by either path_info, ids, or id, whichever is set
# Check path_info last, some systems have weird PATHINFO variables 
if (($ids ne '') && ($alternate ==0)) {
	split(',',$ids);
	$id = $_[0];
	foreach $iid (@_) {
		if ($iarch = &wgConf::GetArch($iid)) {
			push @wgarchs, $iarch;
		}
	}
	$wgarch = $wgarchs[0];
	$path_info = $wgarch->Get('Dir');
	$multiple = 1;
} elsif (($ids ne '') && ($alternate ==1)) {
        split(',',$ids);
        foreach $iid (@_) {
		if ($iarch = &wgConf::GetArch($iid)) {
			$path_info = $iarch->Get('Dir');
			if (! -e "$path_info/$LOCKFILE") {
				$wgarch = $iarch;
				$id = $iid;	
				last;
			}
		}
	}
	$multiple = 0;
} elsif ($id > 0) {
	$wgarch = &wgConf::GetArch($id) || &err_exit("Cannot find an archive with ID $id");
	$path_info = $wgarch->Get('Dir');
} elsif ($path_info ne '') {
	$wgarch = &wgConf::GetArchbyPath($path_info)
 		|| &err_exit("Cannot find an archive in directory $path_info");
} else {
	&printform_exit;
}
if (!defined($ic) || !defined($mo{$ic}) || ($mo{$ic} ne $shmo{$ic}) ) { &err_exit("");}
# What language is the default for this archive?
my $lang = $wgarch->{Lang};
$ENV{'LANG'} = &LangUtils::GetCode($lang);
$ENV{'LC_ALL'} = $ENV{'LANG'}; 


$OriginalQuery = $QS_query;	# Before all security checks, translations, etc

# If we have an ID but no query string, print the form for this archive
if (! $QS_query ) {
	&printformid_exit($wgarch);
}


$_ = $path_info;

$indexdir = $path_info;

&SecurePath(\$indexdir);


if(-e "$indexdir/$LOCKFILE"){
	&err_locked;
}


# All we need to do is call glimpse with the correct path
# at this point we do not need to know all the config details of the archive

# Ensure that Glimpse is available on this machine
-x $GLIMPSE_LOC || &err_noglimpse($GLIMPSE_LOC) ;

# Ensure that index is available
-r "$indexdir/.glimpse_index" || &err_noindex($indexdir) ;

# resubstitute / for %2F in the file paths
$QS_file =~ s/%2f/\//ig;
$QS_query =~ s|%(\w\w)|sprintf("%c", hex($1))|ge;


#####################################################################
# Translate input syntax (if input module exists) *before* all security
# substitutions. There was a serious security hole in version 1.7.1 to 1.7.5 with
# ' -> '"'"' substitutions.  -- CV 9/11/99

if ( -e $INPUT_SYNTAX) {
    require $INPUT_SYNTAX;
    $mInput = new InputSyntax;
} else {
    $mInput = undef;
}

# If we are asked to, use our new input filter
# TODO: check for optional hidden tag.
if (defined($mInput)) {
	if ($QS_autosyntax ne '') {
		$QS_query = $mInput->autoBuildQuery($QS_autosyntax,$QS_autonegate,$QS_query);
	} else {
		$QS_query = $mInput->translateQuery($QS_query);
	}
}

# Check if this appears to be a structured search
# If it has something on both sides of an unescaped =, it is structured
if ($QS_query =~ /[^\\]=./) {
	$bIsStructuredQuery = 1;
}


################################################################
# Now we do security substitutions to query.  Later these should
# be put in a separate "security" module in case we need to do 
# them to other strings.

# Remove nul characters in the query. They could cause the shell to cut
# off part of the command line to glimpse. I found no exploit, but just in
# case. -- CV 9/11/99
$QS_query =~ s|\0||g;

# Make sure that glimpse won't confuse the query string with an option string.
# I found no exploit for this hole, but I feel better this way.
# A cleaner solution would be to implement the standard semantics of '--' in
# glimpse. That is, after a '--', all remaining command line arguments are
# never interpreted as options, regardless of whether they start with a dash.
# -- CV 9/11/99
# Yes - people who actually want to query on a string beginning with a dash should 
# comment out the following line.  --GV 9/13/99
$QS_query =~ s|^\-+||g;

# Escape [trailing --GV] backslashes in the query. Fixes a serious security hole. -- CV 9/11/99
$QS_query =~ s|\\$|\\\\|g;

# End security section for query variable. 
########################################################################

$pquery = $QS_query;	# "Pretty" query for output, doesn't yet have quotes escaped	

# remove any combinations of adjacent quotes
$QS_query =~ s|["']{2,}| |g;

# single quotes may be legitimate and can be escaped
$QS_query =~ s|\'|\'\"\'\"\'|g;

$OPT_errors='';
$OPT_errors="-$QS_errors"	if $QS_errors =~ /^[0-8]$/;
$OPT_errors="-B"		if $QS_errors =~ /^Best\+match$/;
# remove the '-i' from case if the switch is on
$OPT_case="-i"; 
$OPT_case=""			if $QS_case;
$OPT_whole = '';
$OPT_whole="-w"			unless $QS_whole || ($pquery =~ /\#|\*/);  #Set whole-word matching off if user is trying to use wildcards
 
$OPT_age = '';
$OPT_age = "-Y $QS_age" if $QS_age =~ /^[0-9]+$/;
# print "OPT_age = $OPT_age<br>\n";

$OPT_scope = '-W'	unless $QS_wordspan;	# words must be in one record if within # words

#############################################################
# Security section for QS_filter - TODO: pull out into module
# Get rid of nul characters (see comment above). -- CV 9/11/99
$QS_filter =~ s/\0//g;

# Need to escape [trailing --GV] backslashes, to be safe ... -- CV 9/11/99
$QS_filter =~ s/\\$/\\\\/g;

$QS_filter =~ s/\./\\./g;	# Question - do we need this line?

$QS_filter =~ s/\'//g;

# Make sure that glimpse won't confuse the filter with an option string.
# -- CV 9/11/99
$QS_filter =~ s/^\-+//g;

# End security section for QS_filter
##############################################################

$OPT_filter = '';
$OPT_filter="-F '$QS_filter'"	if $QS_filter;

$OPT_filter = '';
$OPT_filter="-F '$QS_filter'"	if $QS_filter;

$OPT_nonascii = '';
$OPT_nonascii = '-z' if ($QS_nonascii =~ /^(on)|(ye?s?)$/i);

# Added optional caching option
# cache="[cachefile]" for next n hits or cache="yes" for first time
$cachefile = '';
$startfrom = 0;
if ($QS_cache ne '') {
        if (($QS_cache =~ /^on$/i)||($QS_cache =~ /^ye?s?$/i)) {
		$UseCache = 2;
	} elsif ($QS_cache !~ /^(off)|(no?)$/i) {
		$UseCache = 1;
		$cachefile = $QS_cache;
		if ($QS_startfrom =~ /\d+/) {
			$startfrom = $&;
		} 
	}
}


if ($QS_maxlines =~ /\d+/) {
	$maxlines = $&;
} else {
	$maxlines = 20;
}
if ($QS_maxchars =~ /\d+/) {
	$maxchars = $&;
} else {
	$maxchars = 3000;
}
if ($QS_maxfiles =~ /\d+/) {
	$maxfiles = $&;
} else {
	$maxfiles = 25;
}

if (($QS_limit  =~ /^(on)|(ye?s?)$/i)&&($mInput)) {
	$maxrec = $maxlines * $maxfiles;
	$OPT_limit = "-L $maxrec:$maxfiles";
} elsif (($QS_limit =~ /^(\d+):(\d+)$/)&&($mInput)) {

	# If we have rules that may actually eliminate hits, use no limit
	if ($QS_wordspan) {
		$OPT_limit = '';
	} else {
		$OPT_limit = "-L $1:$2";
	}
} else {
	$OPT_limit = '';
}

$rankby = uc($QS_rankby) || 'DEFAULT';
if ($rankby =~ /^([A-Z0-9-_]+)$/) {	# Security check as will be used in a filename
	$rankby = $1;
} else {
	$rankby = 'DEFAULT';
}

$highlight = $QS_query;

#Looking for "non-word" chars only applies to English archives
if ($QS_autosyntax ne 'EXACT') {
	if (($lang eq '') || ($lang eq 'english')) {
       	 	my $newhighlight = '';
		# don't break on escaped 'non-word' chars such as \.
        	while ($highlight =~ /((\\\W|\w)([\w'-]|\\\W)*)/g) {
                	$newhighlight .= $1.'|';
        	}
        	chop $newhighlight;
        	$highlight = $newhighlight;
		$highlight = '\b('.$highlight.')\b' if $OPT_whole;
	} else {

	# For other languages just split on spaces and glimpse control chars ~ , ; ( )
	#  TODO : don't split on escaped control chars, ie \;
		$highlight =~ s/^\s+//;
		$highlight = join("|",split(/\s+|[~,;\(\)]/,$highlight));
	}
} else {
        if (($lang eq '') || ($lang eq 'english')) {
                $highlight = '\b('.$highlight.')\b' if $OPT_whole;
        }
}


# make escaped version to pass to mfs
$enc_highlight = &urlencode($highlight);

# check if the query contains any words
&err_badquery if !$highlight;

# if the scope is full, delete any file options
if($QS_scope =~ /^full$/i){
	$QS_file="";
}

$title = '';
$metadesc = '';
if($QS_file){
	($title, $metadesc) = &lookup_titledesc($QS_file);
	if ($title eq "No Title") {
	   $title=$QS_file;
	}
	else {
	   if($title eq ""){
	     $title=$QS_file;
	   }
	}

	# $fullfile = "$indexdir/$QS_file";
	$fullfile = $QS_file;		# it might not be in a subdir of the archivepwd
	# modify the file name to include the .nh.
	# prepend the file name with nh_pre
	$fullfile =~ s/([^\/]+)$/$nh_pre$1/;


	#$OPT_file = "-f $fullfile"; Changed to -p --> bgopal oct/6/96

	$OPT_file = "-p $fullfile:0:0:2";

	if(!(-e $fullfile)){
		&err_noneighborhood($fullfile);
	}
}else{

	$OPT_file = "";
}

# Try using -H switch instead of chdir, as per Peter Bigot's suggestion.  GB 10/17/97
#chdir $indexdir;

# the default is *no* jump to lines.  If line=on, tell glimpse to get lines
$OPT_linenums = '';
if($QS_lines){
	$OPT_linenums="-n";
}


##### At this point we have all the options chosen by the user ########


# **** **** **** **** CHECK FOR CUSTOM MODULES  **** **** **** ****
#
# Currently recognized:  CustomOutputTool, OutputTool, 
#			   CacheResults, InputSyntax
#
# Do not import symbols; all module functions are called explicitly
#
	$HAVE_CUSTOM_OUTPUT = 0;
	if ( -e $CUSTOM_OUTPUT) {
		require $CUSTOM_OUTPUT;
		$mOutput = new CustomOutputTool($indexdir,$OriginalQuery,$title,$lang,$multiple);
		$HAVE_CUSTOM_OUTPUT = 1;
	} elsif (-e $DEFAULT_OUTPUT) {
		require $DEFAULT_OUTPUT;
		$mOutput = new OutputTool;
	} else {
		print "Sorry, no output modules seem to be installed.\n";
		print "More information has been printed to the web server's error log.\n";		

		$errstring = "You need at least one of \n$CUSTOM_OUTPUT, \n$DEFAULT_OUTPUT\n";
		$errstring .= "Check your distribution to make sure one these files is included.\n\n";
		die $errstring;
	}


# TODO: use eval() instead of looking for filename

	if ( -e $RESULT_CACHE) {
		require $RESULT_CACHE;
	} else {
		$UseCache = 0;
	}

	if ( -e $LOGHITS) {
		require $LOGHITS;
		$UseLog = 1;
	} else {
		$UseLog = 0;
	}

 	if ( -e $RANK_HITS) {
 		require $RANK_HITS;
 		$mRank = new RankHits($indexdir);
 	} else {
 		$mRank = undef;
 	}

	if ( -e $SF_MODULE && ($wgarch->{UseSF} eq 'Y')) {
		require $SF_MODULE;
		$mSF = new SearchFeed($wgarch->{SFtrackID},$wgarch->{SFpID},$ENV{'REMOTE_ADDR'},$wgarch->{SFnum},$wgarch->{SFkeywords});
	} else {
		$mSF = undef;
	}

	if ( -e $SQL_MODULE) {
		require $SQL_MODULE;
		$mSql = new SqlMerge;
		$mSql->Connect;
	} else {
		$mSql = undef;
	}

        # Moved test for input syntax module to an earlier place, because
        # it is needed there. Unfortunately, can't move tests for all modules
        # to the new place, because the output module depends on some
        # query variables. -- CV 9/11/99

# **** **** **** **** **** **** **** **** **** **** **** **** **** 


# Get the search results.  They may be cached, or we have to call glimpse

my $bNextHitsToolbar = 0;

# TODO here
# Look for saved tags
# print exact matches with high ranking
# others save for controlling rank of results


# Security note: using $indexdir on the command line could be dangerous if a directory really exists whose name contains shell control characters. 10/17/97 --GB
#$cmd = "$GLIMPSE_LOC -j -z -y $OPT_file $OPT_linenums $OPT_age $OPT_case $OPT_errors -H . " . Added -U -W --> bgopal oct/6/96

# CV: This was the wrong place for input translation. It needs to be
# done before all security checks.

# Took off pipe of stderr to stdout 
# because it was adding erroneous hits. --GV 9/14/99


$cmd = "$GLIMPSE_LOC -U $OPT_scope -j -y $OPT_nonascii $OPT_file $OPT_limit $OPT_linenums $OPT_age $OPT_case $OPT_whole $OPT_errors -H $indexdir " .
	 "$OPT_filter '$QS_query' |";


# Need to add rankby into cachefile name otherwise defeats the purpose...

# We look for the cache even if not passed a cachefile, because we can create it from the query
if ($UseCache && ($cachefile eq '')) {
	my $uniqcmd = $cmd;
        $uniqcmd =~ s/$GLIMPSE_LOC \-U \-W \-j \-y (.+)$/$1/;
	$ids =~ s/([0-9\,\s]+)/$1/;
	$uniqcmd .= $rankby.$ids;
	$cachefile = &ResultCache::GuessCacheFile($uniqcmd);

}



# Now either use the cache or run the glimpse command.
$logstatus = 0;
$num_file_matches = 0;
$num_line_matches = 0;
if ($UseCache && &ResultCache::LoadResult(\@glines, $cachefile, $startfrom, $maxfiles,\$num_file_matches,\$num_line_matches)) {

	 if ($num_file_matches > $maxfiles) {
		$bNextHitsToolbar = 1;
	 }
	 $logstatus = $NOT_MODIFIED;
	if ($DEBUG) {
		 print "<!-- Using cached results, command was $cmd -->\n";
	}
} else {


	# Fool perl -T into accepting $cmd for execution.  (as per Peter Bigot) --GB 10/17/97
	# We assume that we have sufficiently checked the parameters to be safe at this point.  
	$cmd =~ /^(.*)$/;
	$cmd = $1;


	### DEBUG
	# print "<br>start time: $starthour:$startmin:$startsec<br>\n";
	# $utime = (times)[0];
	# $stime = (times)[1];
	# print "<br>time after init: $utime, $stime<br>\n";
	# ($sec, $min, $hour, $other) = localtime(time);
	# print "<br>now (after init): $hour:$min:$sec<br>\n";

	if ($DEBUG) {	
		print "<!-- Webglimpse Version $VERSION Revision $REVISION -->\n";
		print "<!-- Glimpse command: $cmd -->\n";
	}

	# call Glimpse to get full text search results

	# Save pid of the pipe command so we can do cleanup later.
	if (!($gpid = open(GOUT, $cmd ))) {
	   &err_noglimpse($cmd);
	}
	@glines = <GOUT>;
	close(GOUT);

	if ($ids ne '') {

		# start on 2nd one
		for ($ii = 1; $ii <= $#wgarchs; $ii++) {
			$iarch = $wgarchs[$ii];
			$idir = $iarch->Get('Dir');
			&SecurePath(\$idir);
			$icmd = "$GLIMPSE_LOC -U -W -j -y $OPT_nonascii $OPT_file $OPT_limit $OPT_linenums $OPT_age $OPT_case $OPT_whole $OPT_errors -H $idir " .
			 "$OPT_filter '$QS_query' |";
			$icmd =~ /^(.*)$/;
			$icmd = $1;

	                print "<!-- Glimpse command $ii : $icmd -->\n";
	
			if (!($gpid = open(GOUT, $icmd ))) {
			    &err_noglimpse($cmd);
			}
			push @glines, <GOUT>;
			close(GOUT);
		}
	}


	# check the return code
	$rc = $? >> 8;
	if($rc>1){      # 0 means some hits, 1 means no hits, 2 is an error
	   # it's an error!
	   &err_badglimpse(@glines);
	}	

# TODO HERE
	# Transform @glines from raw text to list of arrays of values
	($num_file_matches,$num_line_matches) = &ParseGlimpseOutput(\@glines);

	# If we have RankHits module, reorder the result lines accordingly
	if ($mRank) {
	 	$num_file_matches = $mRank->RankHits(\@glines,$pquery,$QS_lines,$FILE_END_MARK, $maxchars, $rankby,$QS_wordspan);
		$num_line_matches = $#glines + 1;
	}



	if ($#glines > 0) {
		$logstatus = $FOUND;
	} else {
		$logstatus = $NOT_FOUND;
	}
}

if ($HAVE_CUSTOM_OUTPUT) {
	$mOutput->SetNumHits($num_file_matches,$num_line_matches,$startfrom,$maxfiles);
	$mOutput->Set('maxchars',$maxchars);
}

if ($mSF && $HAVE_CUSTOM_OUTPUT && $mRank) {
	my $keyregexp = &RankHits::SimplifyQuery($pquery);
	my @querykeywords = split(/\|/,$keyregexp);
	$mSF->GetResults(\@querykeywords);
	$mSF->RankResults($keyregexp);
	if ( -e "$indexdir/$SF_TMPLFILE") {
		$mOutput->SetOutputVar('SEARCHFEED',$mSF->FormatResults("$indexdir/$SF_TMPLFILE"));
	} else {
		$mOutput->SetOutputVar('SEARCHFEED',$mSF->FormatResults);
	}
}


# Create the initial output and print it
# This is now done by an object, mOutput.
# Depending on what class mOutput is, the content may be determined differently.

print $mOutput->makeInitialOutput($pquery, $title, $QS_file, $QS_lines, $lang, $REQUIRED_MSG);

# Write line to logfile
if ($UseLog) {
	&wgLog::LogSearch($indexdir , $pquery, $loghost, $logstatus, scalar(@glines));
}

if($QS_debug){
	print "<br>cmd: $cmd<br>\n";

}

# Here is where we put the SQL matches

# Do we have a traditional SQL query to do?
my $a_sql_ref = undef;
if (defined($mSql)) {

	# print exact matches
	$mSql->GetSQLMatches($QS_query);
	$mSql->OutputMatches;

	# print approx & category matches
	$mSql->GlimpseSQLFile($QS_query);

}

# Now we begin the full text output
print $mOutput->makeBeginFiles;

### DEBUG
# $utime = (times)[0];
# $stime = (times)[1];
# print "<br>time after glimpse: $utime, $stime<br>\n";
# ($sec, $min, $hour, $other) = localtime(time);
# print "<br>now (after glimpse): $hour:$min:$sec<br>\n";


$prevfile = "";
$lcount = 0;
$fcount = 0;

$score = 0;


my $bAlreadyPrintedEndFiles = 0;

# Added "line:" label; should fix ignore maxlines bug --GB 7/24/97
line:
foreach $aref (@glines) {


	if($QS_debug){
		print "<br><tt>glimpse: $_</tt><br>\n";
	}

	if ($QS_lines) {
		($file,$link,$linkpop,$title,$date,$line,$string,$score) = @$aref;
	} else {
		($file,$link,$linkpop,$title,$date,$string,$score) = @$aref;
	}

	# skip if the file is a .gh or .glimpse file
	next if ($file =~ /\.gh/) || ($file =~ /\.glimpse_/);

	if ($file ne $prevfile) {
		$linecount = 0;
		$charcount = 0;
		if ($fcount>=$maxfiles) {  # If already found $maxfiles matches

			print $mOutput->limitMaxFiles($maxfiles);
			$bAlreadyPrintedEndFiles = 1;
			$file = "";

			last line;
		}

		print $mOutput->makeEndFileDesc() if ( $prevfile ne "" );
		if ($HAVE_CUSTOM_OUTPUT) {
			$mOutput->Set('filename',$file);
		}
		$prevfile = $file ;

		# If no title, just print the link
		if($title eq "No Title") {
			$title = www_form_urldecode($link);
		}
		else {
		    if($title eq ""){
			$title = www_form_urldecode($link);
		    }
		}

                if (($QS_insertbefore && $QS_prepath) || $QS_postpath) {
                        $link = $mOutput->fixLink($link, $QS_prepath, $QS_postpath, $QS_insertbefore);
                }

		print $mOutput->makeLinkOutput($link,$title,$date,$file,$lang);

		
		# Added META description if exists, as per Darryl Fuller's suggestion. --GB 7/24/97
		print $mOutput->makeStartFileDesc($metadesc, $file, $score);

		$fcount++ ;
	}
	$lcount++ ;
	$linecount++;
	if ($linecount>$maxlines) {

#		print "<LI>Limit of $maxlines matched " .
#			"lines per file exceeded...\n" if
#				$linecount==$maxlines && $maxlines > 0;  
# 
		print $mOutput->limitMaxLines($maxlines) if $linecount==($maxlines+1) && $maxlines > 0;
		next line;
	}

# maxchars now means max chars per line
#	if ($charcount >= $maxchars) {
#		print "***\n";
#		next line;
#	}


	if ($bIsStructuredQuery && $HAVE_CUSTOM_OUTPUT) {
		$mOutput->PrepareAlternateOutput;
	}


	if($string !~ /^\s*$/){

		# new option to break by sentence instead of char count
		if($HAVE_CUSTOM_OUTPUT && $QS_sentence){
			$mOutput->FindSentences(\$string,$highlight);
		}

		if($QS_lines){

			if (length($string) >$maxchars + $FUDGE) {
				if ($HAVE_CUSTOM_OUTPUT) {
					$mOutput->CenterOutput(\$string, $highlight, $maxchars);
				} else {
					$string = substr($string,0,$maxchars - $charcount - length($string));
				}
			}

			# BOLDING
			$mOutput->HighlightMatches(\$string, $highlight, $OPT_case);

			# Added $link as argument for use in BASE HREF tag
			# Trim spaces from $line as per Jan Holler.  10/17/97 --GB
			$line =~ s/\ //g;
	
			my $enc_link = &urlencode($link);
			my $enc_file = &urlencode($file);
	
			# Pass archive id rather than using hard drive path, if we can
			if ($id) {
				$linkto = "$FSSERV\?id=$id&link=$enc_link&file=$enc_file&line=$line&highlight=$enc_highlight#mfs"; } else {
				$linkto = "$FSSERV\?pathinfo=$path_info&link=$enc_link&file=$enc_file&line=$line&highlight=$enc_highlight#mfs"; 
			}

			print $mOutput->makeJumpToLine($linkto, $line, $string);
		}else{

			if (length($string) >$maxchars + $FUDGE) {
				if ($HAVE_CUSTOM_OUTPUT) {
					$mOutput->CenterOutput(\$string, $highlight, $maxchars);
				} else {
					$string = substr($string,0,$maxchars - $charcount - length($string));
				}
			}
			
			# BOLDING
			$mOutput->HighlightMatches(\$string, $highlight, $OPT_case);
			print $mOutput->makeLine($string);
		}
	}
	$charcount += length($string);
}

# If we jumped out because of max files, we already printed the necessary ending codes
# otherwise, do it now.

if ( ! $bAlreadyPrintedEndFiles) {

	if ($num_file_matches > $maxfiles) {
		print $mOutput->limitMaxFiles($maxfiles);
	} else {
		print $mOutput->makeEndHits($file);
	}
}

# Save results to cache file if we are doing caching and there are more than maxfiles hits
if ($UseCache && ($logstatus == $FOUND) && ($#glines >= $maxfiles)) {
		my $uniqcmd = $cmd;
		$uniqcmd =~ s/$GLIMPSE_LOC \-U \-W \-j \-y (.+)$/$1/;
		$uniqcmd .= $rankby;
		$cachefile = &ResultCache::SaveResult($maxfiles,\@glines,$uniqcmd,$num_file_matches,$num_line_matches);
print "<!-- cachefile name is $cachefile -->";
		$bNextHitsToolbar = 1;
}

if ($HAVE_CUSTOM_OUTPUT) {

	if ( $bNextHitsToolbar) {
		my $numfiles = &ResultCache::HowManyFiles($cachefile);
		my $qstr = &urlencode($QS_query);
		print $mOutput->makeNextHits($id, $cachefile, $qstr, 
			$maxfiles, $maxlines, $maxchars, $numfiles, $startfrom, $MAX_HITS_GROUPS,$QS_lines);
	}

	print $mOutput->makeNewQuery($indexdir, $maxfiles, $maxlines, 
	    $maxchars, $QS_file,$QS_lines,$QS_age,$QS_case,
	    $QS_whole,$QS_errors, $QS_filter, $QS_query, $rankby, $ids,
	    $QS_autosyntax, $QS_autonegate, $QS_wordspan);
}

print $mOutput->makeFinalOutput($QS_query, $lcount, $fcount);

### DEBUG
# $utime = (times)[0];
# $stime = (times)[1];
# $ctime = (times)[1];
# $cstime = (times)[1];
# print "<p>time after formatting: $utime, $stime, $ctime, $cstime<br>\n";
# ($sec, $min, $hour, $other) = localtime(time);
# print "<br>now: $hour:$min:$sec<br>\n";

if ($MAKE_STATIC_SEARCH_PAGES && defined($oldfh)) {
	select($oldfh);
	$| = 1;
	close STATIC_FH;
	print "Location: $STATIC_URL\n\n";
}

unlink "/tmp/.glimpse_tmp.$gpid";

if (defined($mSql)) {
	$mSql->Disconnect;
}

exit(0);

##########################################################################
sub www_form_urldecode {  # Added 10/18/97 as per Peter Bigot --GB

	local($_) = @_;

	# Reverse the encoding: plus goes to space, then unhex encoded chars
	s/\+/ /g;
	s/%([A-Fa-f0-9]{2})/pack("c",hex($1))/ge; 
	return $_;
}

##########################################################################
sub diag_exit {
# exit on error
	exit -1;
}

##########################################################################
# generic error routine
sub err_exit {
	local($_) = @_;

	print <<EOM;
<html><body>
<hr>
<H2>Sorry, an error has occurred</H2>
<H3>$_</H3>
</BODY>
</HTML>
EOM
	&diag_exit;
}


##########################################################################
sub err_noneighborhood {

	local($_) = @_;

	# neighborhood does not exist
	print <<EOM;
<hr>
<h1>File not found</h1>
There is no neighborhood for file $_.  Either the file does not
exist or the neighborhood file does not exist.
</body>
</html>
EOM

	&diag_exit;
}

##########################################################################
sub printform_exit {

	&wgConf::LoadArchs;

	# list of available archives if > 1 
	if ($wgConf::LastID > 1) {
		%templatehash = {};
		# We need at least reference to ourself
		$WEBGLIMPSE = '/'.$CGIBIN.'/webglimpse.cgi';
		$templatehash{'WEBGLIMPSE'} = $WEBGLIMPSE;
		$templatehash{'CGIBIN'} = $CGIBIN;
		$templatefile = $WGTEMPLATES.'/wgany.html';
 		@carray = sort { $a->{ID} <=> $b->{ID} } (values  %wgConf::Archives);
		@members = @wgArch::members;
		push(@members, 'Status','StatusMsg');
		
		&CommandWeb::BuildHashArray(\@marray, \@carray, \@members, $USEUPPER) || &ErrorExit("CommandWeb::BuildHashArray failed on Archives array : ".$CommandWeb::lastError);
		$templatehash{'ARCHIVES'} = \@marray;
		&CommandWeb::OutputTemplate("$templatefile",\%templatehash) || &ErrorExit("CommandWeb::OutputToWeb failed on $templatefile, hash was ",%templatehash);

	} elsif ($wgConf::LastID == 1) { 
		&printformid_exit($wgConf::Archives{1});
	} else {
		&ErrorExit("Cannot find any archives to search.");
	}
	exit;
}


sub printformid_exit {

	$march = shift;

	# print wgindex.html form for this archive
	%templatehash = {};	
	# Don't need any variables because wgindex.html has already been customized
	$templatefile = $march->{Dir} . '/'.$TEMPLATE_FILE;
	&CommandWeb::OutputTemplate("$templatefile",\%templatehash) || &ErrorExit("CommandWeb::OutputToWeb failed on $templatefile, hash was ",%templatehash);

	exit;
}


##########################################################################
sub err_noquery {
   #	The script was called without a query. 
   #	Provide an ISINDEX type response for browsers
   #	without form support.
   print "
<TITLE>Glimpse Gateway</TITLE></HEAD>
<BODY><H1>Glimpse Gateway</H1>
This is a gateway to Glimpse.
Type a pattern to search in your browser's search dialog.<P>

<ISINDEX>

<H2>What is Glimpse ?</H2>
<QUOTE>
<P>
Glimpse (which stands  for  GLobal  IMPicit  SEarch)  is  an
indexing  and query system that allows you to search through
all your files very quickly.   For  example,  a  search  for
Schwarzkopf  allowing  two  misspelling errors in 5600 files
occupying 77MB took 7 seconds on a SUN  IPC.   Glimpse  supports
most of agrep's options (agrep is our powerful version
of  grep)  including  approximate  matching  (e.g.,  finding
misspelled  words),  Boolean  queries, and even some limited
forms of regular expressions.<BR>
Glimpse's running time is typically slower than systems
tems using inverted indexes, but its index is  an  order  of
magnitude smaller (typically 2-5% of the size of the files).
<H2>Authors of Glimpse</H2>
Udi Manber, Sun Wu, and Burra Gopal<BR>
<ADDRESS>
Department of  Computer
Science, University   of   Arizona,   Tucson,   AZ  85721.<BR>
glimpse\@cs.arizona.edu
</ADDRESS>
</QUOTE>

<HR>
<ADDRESS>
Glimpse<BR>
glimpse\@cs.arizona.edu<BR>
</ADDRESS>

</BODY>
";
   &diag_exit;
}

##########################################################################
sub err_noglimpse {
local($_) = @_;
   #
   # Glimpse was not found
   # Report a useful message
   #
   print "
<TITLE>Glimpse not found</TITLE>
</HEAD>
<BODY>
<H1>Glimpse not found</H1>

Using $_
<p>
This gateway relies on <CODE>Glimpse</CODE> search tool.
If it is installed, please set the correct path in the script file.
Otherwise obtain the latest version from
<A HREF=\"file://ftp.cs.arizona.edu/glimpse\">ftp.cs.arizona.edu</A>
</BODY>
";
   &wgErrors::NotifyAdmin("Glimpse not found using $_, please set the correct path in wgHeader.pm or reinstall Webglimpse from scratch.","Glimpse not found");

   &diag_exit;
}

##########################################################################
sub err_badglimpse {
   my(@glines) = @_;
   #
   # Glimpse had an error
   # Report a useful message
   #
   print "
<TITLE>Glimpse error</TITLE>
</HEAD>
<BODY>
<H1>Glimpse error</H1>

The search parameters caused an error in the call to Glimpse.
<p>
Please try your search again with different parameters.
<p>
<hr>
Output from Glimpse:
<pre>
@glines
</pre>
<br>
<hr>
</BODY>
";
   &diag_exit;
}


##########################################################################
sub err_noindex {
	local ($indexdir) = @_;
# Glimpse index was not found
# Give recommendations for indexing
	print "<TITLE>Glimpse Index not found</TITLE>\n";
	print "</HEAD>\n";
	print "<BODY>\n";
	print "<H1>Glimpse Index in directory '$indexdir' not found</H1>\n";
	print "Glimpse cannot proceed without index.\n";
	print "Please check if the directory being searched is indexed\n";
	print "by <code>glimpseindex</code>.\n";
	print "</BODY>\n";
	print "</html>\n";
	&wgErrors::NotifyAdmin("User tried to search using index in directory '$indexdir', no index exists there. Apparently called from $ENV{HTTP_REFERER}.","Glimpse Index not found");
	&diag_exit;
}
##########################################################################
sub err_insecurepath {
# Path user requested contains ".." characters
	print "<TITLE>Path not accepted</TITLE>\n";
	print "</HEAD>\n";
	print "<BODY>\n";
	print "<H1>Insecure Path Not Accepted</H1>\n";
	print "Please specify a path not containing ".." \n";
	print "</BODY>\n";
	print "</html>\n";
	&diag_exit;
}

##########################################################################
sub err_conf {
# Glimpse archive Configuration File was not found
	print "<TITLE>Glimpse Archive Configuration File not found</TITLE>\n";
	print "</HEAD>\n";
	print "<BODY>\n";
	print "<H1>Glimpse Archive Configuration File not found</H1>\n";
	print "Cannot open configuration file $indexdir/archive.cfg\n";
	print "</BODY>\n";
	print "</html>\n";
	&diag_exit;
}

##########################################################################
sub err_badquery {
	if ( $QS_query eq '' ) {
		print "<TITLE>Empty Query</TITLE>\n";
	} else {
		print "<TITLE>Invalid Query</TITLE>\n";
	}

	print "</HEAD>\n";
	print "<BODY>\n";
	print "<H1>Query is too broad</H1>\n";
	print "The query \"$pquery\" doesn't contain any words that glimpse considers valid and ".
		"thus will take too much time. Please refine your query.<p>\n\n".
		"Note, it requires special settings to make glimpse consider numbers and upper-ascii ".
		"characters to be parts of valid words.  This site may not be configured to search ".
		"on the type of characters you entered.";

	print "</BODY>\n";
	print "</html>\n";
	&diag_exit;
}

##########################################################################
sub err_locked {
	print "<TITLE>Indexing in progress</TITLE>\n";
	print "</HEAD>\n";
	print "<BODY>\n";
	print "<H1>Indexing in progress</H1>\n";
	print "The archive is currently reindexing.  Please try your query later.\n";
	print "</BODY>\n";
	print "</html>\n";
	&diag_exit;
}

# Also find <META NAME="DESCRIPTION" CONTENT="stuff..."> at the same time.
sub lookup_titledesc{
	local($file) = @_;
	local($intitle, $title, $donetitle, $inmetadesc, $metadesc, $donemetadesc);
        if (($file =~ m/^\s*-\s*$/) ||
            ($file =~ m/^\s*\&/)) {
            # Don't let anybody open stdin, or specific descriptors.
            &err_noneighborhood ($file);
            die ("UNREACHABLE REACHED");
        }
        $intitle = 0;  $donetitle = 0;
        $inmetadesc = 0; $donemeta = 0;
        $title = ''; $metadesc = '';
	if (open(IN, "<$file")) {
		# Stop looking for <TITLE> & <META...> if reach </HEAD> -- GB 7/24/97
		line: while (defined($_ = <IN>) && !(/\<\/head/i) && (($donetitle == 0) || ($donemeta ==0))) {
			chomp;
			if((/\<title\>(.*)$/i)) {
				$intitle = 1;
				$title = $1;
			} elsif ($intitle) {
				$title .= " $_";
			}
			if ($intitle && $title =~ s#</title>.*##i) {
				$donetitle = 1;
				$intitle = 0;
			}

			if((/\<meta name=\"*description\"* content=\"*(.*)$/i)) {
				$inmetadesc = 1;
				$metadesc = $1;
			} elsif ($inmetadesc) {
				$metadesc .= " $_";
			}
			if ($inmetadesc && $metadesc =~ s#\"*\>.*$##) {
				$donemetadesc = 1;
				$inmetadesc = 0;
			}

		}
		close(IN);
	}
	# if there's no title, just return "", let webglimpse write 'No title'.
	# if($title eq ""){
		# $title="No title";
	# }

	# Maximum chars for meta description; should be settable by option.
	$metadesc = substr($metadesc, 0, $MAX_METADESC_LEN);

	# trim blanks off of title
	$title =~ s/^\s+//;
	$title =~ s/\s+$//;

	return ($title,$metadesc);
}


# Generic catch-all error routine
sub ErrorExit {
	$merr = shift;

	print "<TITLE>An error has occurred: $merr</TITLE>\n";
	print "</HEAD>\n";
	print "<BODY>\n";
	print "<H1>Sorry, an error has occurred</H1>\n";
	print "<H2>$merr</H2>\n";
	print "<hr><p>Press the back arrow to return to the previous page.\n";
	print "</BODY>\n";
	print "</html>\n";
	&diag_exit;
}

############################################
# Used to be done like this:
#
#if($QS_lines){
#                # look for line number, too
#                ($$lineref =~ /^([^$FILE_END_MARK]+)$FILE_END_MARK([0-9]+)$FILE_END_MARK([^\s]+)\s*(([^\\:]|\\:|\\\\)*):\s*(\S\S\S\s+\d+\s+\d\d\d\d):\s*(\d+)\s*:(.*)/) || return 0;
#                $file = $1 || '';
#                $link=$2 || '';
#                $LinkPop=$3 || 0;       # This is the LinkPop variable used in ranking formulae
#                $title=$4 || '';
#                $date = $6 || '';
#                $line = $7 || '';
#                $string = $8 || '';
#
#                $$lineref = join($FILE_END_MARK,$file,$link,$title,$date,$line,$string);
#}else{
#                ($$lineref =~ /^([^$FILE_END_MARK]+)$FILE_END_MARK([0-9]+)$FILE_END_MARK([^\s]+)\s*(([^\\:]|\\:|\\\\)*):\s*(\S\S\S\s+\d+\s+\d\d\d\d):(.*)/) ||
#                   (/^([^$FILE_END_MARK]+)$FILE_END_MARK([0-9]+)$FILE_END_MARK([^\s]+)\s*/) || return 0;
#
#                $file = $1 || '';
#                $link=$2 || '';
#                $LinkPop=$3 || '';      # This is the LinkPop variable used in ranking formulae
#                $title=$4 || '';
#                $date = $6 || '';
#                $string = $7 || '';
#
#}
##############################

# sample results from glimpse:
#
#/home/WWW/test/5	http://localhost:80/test/5	1	: Jan 28 2002: This is document 5 (a number), that does not end with .html and also has no title
#/home/WWW/test/4.html	http://localhost:80/test/4.html	1	 	No Title: Jan 28 2002: four is a number, but this document has no title
#/home/WWW/test/3.html	http://localhost:80/test/3.html	1	 	Document 3: Jan 28 2002: and, three is a number
#/home/WWW/test/2.html	http://localhost:80/test/2.html	1	 	 The title for\: Document 2 : Jan 28 2002: two is a number too
#/home/WWW/test/1.html	http://localhost:80/test/1.html	1	 	The title for\: Document 1: Jan 28 2002: one is a number
#Ran search using command: /usr/local/bin/glimpse -U -X -i -j -w -H /usr/local/wg2/archives/3 'number' 
#


# Returns #files, lines matched
sub ParseGlimpseOutput {

	my $glinesref = shift;
#TODO
	# Transform each text line in glines to an array ref to the needed values
	# (we might reference them more than once)

	my $i;
	my ($null, $file, $link, $linkpop, $title, $date, $string,$rest);
	my $numfiles = 0;
	my $numlines = 0;
	my $oldfile = '';
	my $ALOT = 10000;
	my $FUDGE = 20; # allow 20 chars more or less to allow for word breaks
	my $SOME = 500; # enough for most titles
			# could still break on files with no linebreaks and
			# extremely long titles, if admin sets maxchars low

#TODO: configurable error notification - some will want email, some just log
# build this into Abra?
# Sanity check the first line
#	($file, $link, $linkpop, $rest) = split(/$FILE_END_MARK/,$$glinesref[0],4);
#	if (!($file && $link)) {
#		&wgErrors::NotifyAdmin("Invalid search results: file = $file,link = $link. Check that your FILE_END_MARK setting in Glimpse matches the setting in Webglimpse.  To reproduce this problem, search for $QS_query in archive $id\n");
#	}
	
	# use a numeric for loop to avoid unnecessary copying around of data
	for ($i=0; $i<=$#$glinesref; $i++) {
		# Initialize line vars
		($file, $link, $linkpop, $title, $date, $line, $string) = 
			('','','','','','','');

		($file, $link, $linkpop, $rest) = split(/$FILE_END_MARK/,$$glinesref[$i],4);
	    	################################################	
		# Check for really huge returned lines, sometimes we are
		# searching in a file with no linebreaks and 1000's or 10000's 
		# of chars are returned.  We can chop off most of the extra
		# junk before applying all the regexps.
		if ($#rest > $maxchars + $ALOT) {
			$rest = substr($rest, 0, $maxchars + $SOME);
		}


		if ($file ne $oldfile) {
			$numfiles++;
			$oldfile = $file;
		}
		$numlines++;

		# Better check - if $linkpop is not simple numeric, we are probably using an older index
		# that did not save link popularity values. Paste rest of string back together.
		if ($linkpop =~ /\D/) {
			if ($rest) {
				$rest = $linkpop.$FILE_END_MARK.$rest;
			} else {		
				$rest = $linkpop;
			}
			$linkpop = 1;
		}

		# double-check if date & stuff got attached to $link
		# html links should not have two colons unless the second is followed by a numeric port number (ok, they could in very weird cases, but it seems much more common that its a text file with an old version of glimpse)
		if ($link =~ /^(.+:[^:]+)(:[^\d]+.*)$/) {
			$link = $1;
			$rest = $2 . $rest;
		}


# for html documents, there will be an extra space and tab, then the title or "No Title" and a colon 
# colons in the title are escaped
# non-html documents do not have title section

		if ($rest =~ /^\s*$FILE_END_MARK*:/) {
			$title = '';
		} else {

			if ($rest =~ s/\s*$FILE_END_MARK*(([^:]|(\\:))*[^\\])(:.+)$/$4/) {
 				$title = $1;	
			} else {
				$title = '';
			}
		}
		if ($QS_lines) {
			($null, $date, $line, $string) = split(/\s*:\s*/,$rest,4);
		} else {
			($null, $date, $string) = split(/\s*:\s*/, $rest, 3);
		}
		# Trim leading and trailing spaces
      		$title =~ s/\s+$//;
		$link =~ s/^\s+//;
		$link =~ s/\s+$//;
		$string =~ s/^\s+//;
		$string =~ s/\s+$//;
	
		# replace the \:'s and \\'s in the title with just :'s
		$title =~ s/\\\\/\\/g;
		$title =~ s/\\:/:/g;

		# Replace internal spaces in link with %20
		$link =~ s/\s/%20/g;
 		# GFM fix for commas in links creating problems later 
		# remap %2c back to comma for nicer appearance
 		$link =~ s/%2c/,/g;

		# Get the line number for original file
		if ($string =~ /^<([0-9]+)>/) {
			$line = $1;
		} 
               	# Get rid of line number in titles
                $title =~ s/<([0-9]+)>//g;
               
                # Show comments since they may include matches - and they won't match
                # regular tag re below
                $string =~ s/<\!\-\-/\&lt;\!--/g;

		# Replace HTML tags if desired 
		if ($SUPPRESS_ALL_TAGS || ($SUPPRESS_HTML_TAGS && $file =~ /$HTMLFILE_RE/o)) {
			$string =~ s#\</?[a-zA-Z0-9][^>]*\>?##g;
		} elsif ($SHOW_HTML_TAGS) {
			# we shouldn't suppress tags, but we need to do basic
			#  substitutions
			$string =~ s/\&/\&amp;/g;
			$string =~ s/\</\&lt;/g;
			$string =~ s/\>/\&gt;/g;
		}

		# save only maxchars of the matched record

		if ($HAVE_CUSTOM_OUTPUT) {
			$mOutput->CenterOutput(\$string, $highlight, $maxchars);

		} else {
			$string = substr($string,0,$maxchars);
		}

		if($QS_debug){
			print "<br><tt>Webglimpse: file=$file link=$link title=$title date=$date line=$line string=$string</tt><br>\n";
		}

		# Now the tricky part - we want to replace this entry in glines with an array reference
		if ($QS_lines) {
			$$glinesref[$i] = [ $file, $link, $linkpop, $title, $date, $line, $string ];	
		} else {
			$$glinesref[$i] = [ $file, $link, $linkpop, $title, $date, $string ];	
		}
	}

	return $numfiles,$numlines;
}

# Does inverse of www_form_urldecode
# TODO: move these funcs to a utils module for reuse in other scripts
sub urlencode {
	my $s = shift;

	$s =~ s/([^a-z0-9])/fixchar($1)/ge;
	return $s;
}

sub fixchar {
	my $c = shift;
	$c = '%'.sprintf("%lx",unpack("c",$c));
	return $c;
}

sub SecurePath {
	my $ref = shift;

	# Check that indexdir has no single quote characters; it will be used on a command line
	$$ref =~ s/[\']//g;

	# the check for an insecure path won't work if there are backslashes before
	# the dots. To the shell, '\.\.' is the same as '..' Need to escape backslashes
	# first. -- CV 9/11/99
	$$ref =~ s/\\/\\\\/g;

	# Added check for ".." as per CERT 11/7/97 --GB
	if ($$ref =~ /\.\./) {
		&err_insecurepath;
	}
	return $$ref;
}

