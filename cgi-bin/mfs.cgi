#!/usr/local/bin/perl -T

# mfs.cgi retrieves local file and inserts jump-to-line tags, highlights search terms

# **** **** **** ****    CONFIGURABLE VARIABLES     **** **** **** ****
# We need some of these to find our libraries, so wrap them in a BEGIN block

BEGIN {
        $WEBGLIMPSE_LIB = '|WEBGLIMPSE_LIB|';
        unshift(@INC, "$WEBGLIMPSE_LIB");                       # Find the rest of our libs
}

BEGIN {
        use wgHeader qw( :all);
        use wgErrors;
	use wgConf;
	use wgArch;
	use wgAgent;
}

# **** **** **** **** NO CONFIGURATION NEEDED BELOW **** **** **** ****

print "Content-type: text/html\n\n";

$qs = $ENV{'QUERY_STRING'};
$qs =~ s/\'//g;

#	Strip the variables out from the query string,
#	and assign them into variables, prefixed by 'QS_'
foreach $pspec (split (/\&/, $qs)) {
	$pname = '';
	$pvalue = '';
	($pname, $pvalue) = (split (/=/, $pspec));
# Decode form results (hex characters, spaces etc)
	$pvalue = www_form_urldecode($pvalue);
	$pname = www_form_urldecode($pname);
	# all our variables are lower case, but allow user to use uppercase
	$pname =~ tr/A-Z/a-z/;
	if ($pname =~ /^[a-z0-9_]*$/ ) {
		$varname = "QS_$pname";
		$$varname = $pvalue;
	}
}

$QS_pathinfo =~ s/%2f/\//ig;

$indexdir = ($QS_pathinfo ne "") ? $QS_pathinfo : $ENV{'PATH_INFO'};
$id = (defined($QS_id)) ? $QS_id : 0;

# Load archive defined by either indexdir or id, whichever is se
if ($id > 0) {
	$wgarch = &wgConf::GetArch($id) || &err_exit("Cannot find an archive with ID $id");
	$indexdir = $wgarch->Get('Dir');
} elsif ($indexdir ne '') {
	$wgarch = &wgConf::GetArchbyPath($indexdir) || &err_exit("Cannot find an archive in directory $path_info");
} else {
	&err_exit("Required parameters not available: ID, indexdir\n");
}

# Delete any quotes 
$indexdir =~ s/\'//g;

# Escape backslashes and get rid of nul characters to be safe -- CV 9/11/99
$indexdir =~ s/\\/\\\\/g;
$indexdir =~ s/\0//g;
$file =~ s/\\/\\\\/g;
$file =~ s/\0//g;


if (!$indexdir) {
	print "Content-type: text/html\n\n";
	print "<TITLE>Directory '$indexdir' not found</TITLE>\n";
	print "<H1>Directory '$indexdir' not found</H1>\n";
	print "Cannot find directory '$indexdir' in the file system\n";
	exit;
}

$CUSTOM_OUTPUT = "$WEBGLIMPSE_LIB/CustomOutputTool.pm";
$DEFAULT_OUTPUT = "$WEBGLIMPSE_LIB/OutputTool.pm";
$HAVE_CUSTOM_OUTPUT = 0;
if ( -e $CUSTOM_OUTPUT) {
	require $CUSTOM_OUTPUT;
	$mOutput = new CustomOutputTool($indexdir);
	$HAVE_CUSTOM_OUTPUT = 1;
} elsif (-e $DEFAULT_OUTPUT) {
	require $DEFAULT_OUTPUT;
	$mOutput = new OutputTool;
} else {
	$mOutput = 0;
}
$OPT_CASE = 1;	# ignore case when highlighting matched words


# Added link argument for BASE HREF tag. --GB 11/1/97
$link = $QS_link;

$file = $QS_file;
$path = $QS_file;
if ($path =~ m#/\.\./#) { &err_noaccess;}
$line = $QS_line;

# make sure the indexdir exists, and is a valid archive dir
if ($indexdir =~ m/^\s*\&/) {
	# Don't let anybody open specific descriptors.
	&err_file ($indexdir);
	die ("UNREACHABLE REACHED");
}
if (!(-d $indexdir)){
	&err_noindexdir;
}
if (!(-e "$indexdir/archive.cfg")){
	&err_badindexdir;
}
my $agent = wgAgent->new();

# If its prefiltered HTML, try to get file from URL instead of the cached one
# assume is HTML unless link appears to be a PDF, .doc or .xls
my $contents = '';
my $WANT_PLAIN_CONTENT = 1; # otherwise, wgAgent::getURL returns a header line
if (($file =~ /\.abra$/) && ($link !~ /\.(pdf|doc|xls)$/i)) {  
	$contents = $agent->getURL($link,'','','',$WANT_PLAIN_CONTENT);
	if ($contents =~ /^error/i) {
		$contents = '';
	}
	my $catstr = '';
	while ($contents =~ /^Redirect: (.*)$/) {
		$contents = '';
		my $rurl = $1;
		if ($catstr =~ /\b$rurl\b/) {
			$contents = '';
			last;	# break looped redirection
		}
		$catstr .= $rurl.' ';
		$contents = $agent->getURL($rurl);
	}
}

$name = '';
if ($contents) {
	@contents = split(/\n/, $contents);
} else {

	# you may comment this check if you want to decrease security
	#  for a shorter execution
	# The following code checks if the filename is in .glimpse_filenames
	$found = 0;
	($lookfor = $file) =~ s/(\W)/\\\1/g;
	
	open (F, "<$indexdir/.glimpse_filenames") || &err_noaccess;
	<F>;
	while (($_ = <F>) && !($found)) {
		$found = (/^${lookfor}\s/ || /^${lookfor}$/);
	}		
	close(F);
	if (! $found) {
		&err_noaccess;
	}
	# End of security check.


	if (($path =~ m/^\s*-\s*$/) ||
	    ($path =~ m/^\s*\&/)) {
		# Don't let anybody open stdin, or specific descriptors.
		&err_file ($path);
		die ("UNREACHABLE REACHED");
	}
	$effname = "<$path";
	$name = $path;
	if ($path =~ /^(.*)\.Z$/) {
		$effname = "exec $gunzip < $path|";
		$name = $1;
	} elsif ($path =~ /^(.*)\.gz$/) {
		$effname = "exec $gunzip < $path|";
		$name = $1;
	} elsif ($path =~ /^(.*)\.zip$/) {
		$effname = "exec $gunzip < $path|";
		$name = $1;
	}

	if (! -f $path) {
		&err_file($path);
		die ("UNREACHABLE REACHED");
	}
	if (!open(INPUT,$effname)) {
		&err_file($path);
		die ("UNREACHABLE REACHED");
	}
	@contents = <INPUT>;
	close INPUT;
}




$HTML = 1;
# Allow .html or .htm --GB 11/1/97
# lets be real conservative on using <PRE>, a lot of cases possible here
if ($name && ($name !~ /$HTMLFILE_RE/)) {
	print "<PRE>\n";
	$HTML = 0;
}

# Use the $link argument for baseurl --GB 11/1/97
$baseurl = $link;

$do_highlight = $HAVE_CUSTOM_OUTPUT && $QS_highlight;

$at_line = 0;

$carry=0;
$lineno = -1;
$need_mark = 0;
$pretag = '#~#';
$posttag = '#';
LINE:
while ($lineno < $#contents) {
	$lineno++;
	$_ = $contents[$lineno];
	chomp;
	if ($HTML) {
		$baseurl && s/<title>/<BASE HREF=\"$baseurl\">$&/i;
	} else {
		s|\&|\&amp;|g;
		s|\<|\&lt;|g;
		s|\>|\&gt;|g;
	}
	if ($line && (($lineno + 1) == $line)) {
		$need_mark = 1;
	}
	
	if($carry==1){
		# skip if we don't find >
		if(!s/^([^>]*)>//) {
			print $_,"\n";
			next;
		}

		# if we didn't do next, it succeeded -- reset carry
		print $1,"\n";
		$carry=0;
	} 

	if ($need_mark) {
		print "<A NAME=\"mfs\"></A>";
		$need_mark = 0;
	}
	
	# remove tags temporarily
	@linetags = (); 
	my $tagno = 0;
	while ( s/(<[^\s>][^>]*>)/$pretag$tagno$posttag/ ) {
		$linetags[$tagno] = $1;
		$tagno++;
	}
	if ( s/(<[^\s>].*)$/$pretag$tagno$posttag/ ) {
		$carry=1;
		$linetags[$tagno] = $1;
		$tagno++;
	}

	# Highlight all occurances of keyword, not only this line
	if ($do_highlight && ! $incomplete_tag) {
		$mOutput->HighlightMatches(\$_, $QS_highlight, $OPT_CASE);
	}
	
	# put tags back in
	# $pretag, $posttag hardcoded in just to make regexp clearer
	while (s/#~#(\d+)#/$linetags[$1]/ge) {}
	
#	print " $lineno :", $_,"\n";
	print $_,"\n";
	
}
if ($HTML == 0) {
	print "</PRE>\n";
}
1;

##############################################################################

sub err_exit {
	my $msg = shift;
	print "<TITLE>Error</TITLE>\n";
	print "<H1>Sorry, an error has occurred</H1>\n";
	print $msg;
	exit;
}

sub err_badconfig {
	print "<TITLE>Error</TITLE>\n";
	print "<H1>Error with \"$indexdir\"</H1>\n";
	print "Cannot open configuration file for archive directory.\n";
	exit;
}
sub err_noindexdir {
	print "<TITLE>Error</TITLE>\n";
	print "<H1>Error with \"$indexdir\"</H1>\n";
	print "Archive directory does not exist.\n";
	exit;
}
sub err_badindexdir {
	print "<TITLE>Error</TITLE>\n";
	print "<H1>Error with \"$indexdir\"</H1>\n";
	print "Directory is not an archive directory.\n";
	exit;
}
sub err_noaccess {
	print "<TITLE>Access denied</TITLE>\n";
	print "<H1>Access to \"$path\" denied</H1>\n";
	print "You don't have permission to get file \"$path\"\n";
	print "from this site.\n";
	exit;
}
sub err_file {
	local ($path) = @_;
	print "<TITLE>Cannot read file \"$path\"</TITLE>\n";
	print "<H1>Cannot read file \"$path\": $!</H1>\n";
	exit;
}
sub www_form_urldecode {  

	local($_) = @_;

	# Reverse the encoding: plus goes to space, then unhex encoded chars
	s/\+/ /g;
	s/%([A-Fa-f0-9]{2})/pack("c",hex($1))/ge; 
	return $_;
}

