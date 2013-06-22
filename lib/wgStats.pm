#!/usr/local/bin/perl

package wgStats;

# Gather statistics on pages traversed
# an object, each instance = one URL
# designed for standalone use, should not depend on other wg modules except URL.pl

# DEPENDENCIES
#
#  either rest of webglimpse install, or ibmwrap script and wget or httpget.  
#  netscape
#  URL.pl

BEGIN {
	use wgHeader;
	require "URL.pl";
}

# CALLED BY
#   spider.pl
#   	makestats

# CONFIGURATION				      Available Variables
#   WGHOME/templates/tmplStatRobots.txt		  ID   URL   ROBOTNAME   DIRPATH    MODDATE   MODTIME
#                    tmplStatSummary.txt	  ID   URL   COUNT  SSL   DYNAMIC   ROBOTSFILE	
#                    tmplStatReport.txt		  (all StatVars listed below)
#  WGARCHHOME/archive.cfg lists starting URLs & properties

# TODO - accept simple list of URLs and assume all are Tree, fixed # hops
# Make separate "go" script that converts to archive.cfg and generates stats
# optionally managed from wgarcmin.cgi but probably we don't want that

my $REVISION = '$Id $';

my $debug = 0;

# Constants (keep here so this module can be used almost standalone)
$USING_WGET = 0;	# currently using with webglimpse for traversal, uses httpget
$WGET = '/usr/local/bin/wget';
$HTTPGET = "$WGHOME/lib/httpget";
$SSLGET = '/usr/local/bin/netscape';
$ADPAT = '\bads?\b';
$CREDPAT = 'Credit Card Number|\bVISA\b';
$TMPDIR = '/tmp';
$REPORTDIR = "$WGHOME/reports";

if (! -d $REPORTDIR) {
	`mkdir $REPORTDIR`;
}
if (! -d $TMPDIR) {
	$TMPDIR = '$WGHOME/tmp';
	`mkdir $TMPDIR`;
}


$TMPFILE = "$TMPDIR/scratch.txt";

$LEAFOUT    = "$REPORTDIR/LeafReport.txt";
$SUMMARYOUT = "$REPORTDIR/SummaryReport.txt";
$ROBOTSOUT  = "$REPORTDIR/RobotsReport.txt";


# Public variables

my $StatVars= 'ID URL NumLinks NumSSL NumImgs NumAds CredMatch '.
		'ModDate ModTime Size RobotsFlag RobotsList Domain '. 
		'LoadTime Errors Registrant ExternalFlag ProtectedFlag '.
		'LinksTo LinksFrom LinksToSSL UsesCookies IsDynamic';

# Plus used only by roots - Registrant, Address

@members = split(/\s+/, $StatVars);

1;

sub Init {
	
	foreach $fname ($LEAFOUT,$SUMMARYOUT,$ROBOTSOUT) {
		if (-e $fname) {
			`mv $fname $fname.bak`;
		}
	}

	open(L,">$LEAFOUT") || warn("Error opening $LEAFOUT for writing\n");
	open(S,">$SUMMARYOUT")  || warn("Error opening $SUMMARYOUT for writing\n");
	open(R,">$ROBOTSOUT") || warn("Error opening $ROBOTSOUT for writing\n");

	MakeHeaders();
	MakeSummaryHeader();
	MakeRobotsHeader();
}

sub Cleanup {

	close(L);
	close(S);
	close(R);
}


# Called with ID, URL
sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;

	$self->{ID} = shift;
	$self->{URL} = shift;

	$self->{Root} = shift || $self;

	$self->{Domain} = &getDomain($self->{URL});

	$self->{LinksTo} = [];
	$self->{LinksFrom} = [];
	$self->{LinksToSSL} = [];
	$self->{RobotsList} = [];

	$self->{NumLinks} = 0;
	$self->{NumSSL} = 0;
	$self->{NumImgs} = 0;
	$self->{Size} = 0;

	$self->{Registrant} = '';
	$self->{ExternalFlag} = 'N';
	$self->{ProtectedFlag} = 'N';
	$self->{UsesCookies} = 'N';
	$self->{RobotsFlag} = 'N';
	$self->{IsDynamic} = ' ';

	return $self;
}

# Set Robots info, called only with Root objects
sub SetRobotData {
	my $self = shift;
	$_ = shift || return(0);	# space-separated list of paths

	@{$self->{RobotsList}} = split(" ");

	$self->{RobotsFlag} = 'Y';
	return 1;
}

sub MakeRobotsHeader {
	print R "ID\tModDate\tModTime\tProhibits\n";
	return 1;
}


sub MakeRobotsOutput {
	my $self = shift;

# print to R
	foreach $path (@{$self->{RobotsList}}) {
		print R $self->{ID},"\t",$self->{ModDate},"\t",$self->{ModTime},"\t",$path,"\n";
	}
}

sub getDomain {
	my $url = shift;

	my($prot, $host, $port, $path) = &url::parse_url($url);

	my $domain = '';

	if ($host =~ /(^|\.)([^\.]+\.?[^\.]+)$/) {
		$domain = $2;
	} # should not be an else...

	return $domain;
}


# analyze url name, headers, file size, file contents
sub analyze {
	my $self = shift;

	my ($rawheaders, $file, $loadtime) = @_;

	if (! $self->{URL}) {
		return 0;
	}

	# Guess if this seems like a static or dynamic page
	my $url = $self->{URL};
	my $sroot = $self->{Root};
	if ($url =~ /\.html?$/) {
		$self->{IsDynamic} = 'N';
	} elsif (($url =~ /cgi/)||($url =~ /\.(pl)|(pm)|(asp)|(sh)|(shtml)|(jhtml)$/)) {
		$self->{IsDynamic} = 'Y';
		$sroot->{IsDynamic} = 'Y';
	}

	$self->{ModDate} = 'unknown';
	$self->{ModTime} = 'unknown';

	# parse available headers for ModTime & ModDate, also set UsesCookies flag
	$self->ParseHeaders($rawheaders);

	$self->{LoadTime} = $loadtime;

	@_ = stat("$file"); 

	$self->{Size} = $_[7];	# may or may not be in headers, get from file directly

	$self->parseHTMLFile($file);

	return 1;
}


sub ParseHeaders {
	my $self = shift;
	my $raw = shift;

# Looking for
#    4 Last-Modified: Wed, 19 Dec 2001 22:13:32 GMT      
#    4 Set-cookie: NGUserID=cf1859a0-11285-1008812863-1;

	my @lines = split(/\n/, $raw);

	foreach $line (@lines) {
		/[0-9]*\s*Last-Modified: (.+)$/ && $self->SetLastModified($1);
		/[0-9]*\s*Set-cookie:/ && ($self->{UsesCookies} = 'Y');
	}

	return;
}



sub SetLastModified {
	my $self = shift;

	$rawdate = shift;

	if ($rawdate =~ /\w\w\w,\s(\d+\s\w+\s\d+)\s([0-9:]+)\s/) {
		$self->{ModDate} = $1;
		$self->{ModTime} = $2;
	}
	return;
}

sub parseHTMLFile {

	my $self=shift;

	my $file = shift;
	my $pagetext = &readFile($file);
	return ($self->parseHTML(\$pagetext));
}

# parse html doc and return list of internal links
# 	# links
#	# SSL links
#	# images
#	# matches to "Credit card" patterns
# @lnks is unused by webglimpse/makestats, but may be used by ibmwrap.pl
#
sub parseHTML {
   my $self = shift;
   my $xref = shift;
   my ($i, $img, $link, $url);
   my(@links,@imgs) ;
   my @lnks = ();
   my $domain = $self->{Domain};
   my $sroot = $self->{Root};  
 
   @links = split(/<A[\s]+[^\>]*HREF[\s]*=[\s]*|<FRAME[\s]+[^\>]*SRC[\s]*=[\s]*/i, $$xref);

   foreach $i (1..$#links)	{
      $link = $links[$i];
      if ($link =~ /^\"?([^>\"\s]*)\"?/)	{
       		$link = $1;
		$link =~ s/,/%2c/g;
#print "Processing link $link\n";
		if (($link =~ /^https:/) || ($link=~/http:\/\/[^\/]+:443/)) {
			push(@{$self->{LinksToSSL}},$link);
			$self->{NumSSL}++;
			$sroot->{NumSSL}++;
		} else {
			$self->{NumLinks}++;
			$sroot->{NumLinks}++;
			if (($link =~ /^https?:/) && ($link !~ /http:\/\/[^\/]+$domain\/?/)) {
#print "its external\n";
				$self->{ExternalFlag} = 'Y';
				push(@{$self->{LinksTo}}, $link);
			} else {
				push(@lnks,$link);
#print "Adding $link to next hops list\n";
			}
		}
      }
   }

   undef @links;

   @imgs = split(/<IMG\s+[^\>]*SRC\s*=\s*/i, $$xref);
   foreach $i (1..$#imgs)	{
      $img = $imgs[$i];
      if ($img =~ /^\"?([^>\"\s]*)\"?/)	{
		$self->{NumImgs}++;
		if ($img =~ /$ADPAT/i) {
			$self->{NumAds}++;
		}
      }
   }
   return(@lnks);
}


# Only called on roots, not leafs
sub GetRegistrant {
	my $self = shift;
	# TODO: call betterwhois
}

# ID URL NumLinks NumSSL NumImgs NumAds CredMatch '.
#		'ModDate ModTime Size RobotsFlag RobotsList '. 
#		'LoadTime Errors Registrant ExternalFlag '.
#		'LinksTo LinksFrom LinksToSSL';

sub RootInfo {
	my $self = shift;
	print "Root: $self->{ID}\t$self->{URL}\t$self->{Registrant}\n";
	print "\nTraversing $self->{Hops} hops/ply\n\n";
}

sub MakeSummaryHeader {
	print S "ID\tURL\tNumLinks\tNumSSL\tRobotsFlag\tProtectedFlag\tUsesCookies\tIsDynamic\tRegistrant\tAddress\n";
}

sub MakeSummaryOutput {
	my $self = shift;

# print to S
	foreach $var ("ID","URL","NumLinks","NumSSL","RobotsFlag","ProtectedFlag","UsesCookies","IsDynamic","Registrant") {
	
		print S $self->{$var},"\t";
	}
	my $address = $self->{Address};
	$address =~ s/\n/ /g;
	print S $address,"\n";

}

sub MakeHeaders {
	print L "ID\tURL\tNumLinks\tNumImgs\tNumAds\tNumSSL\tSize\tLoadTime\tModDate\tModTime\tExternal companies\tExternal Sites\tSSL Links\n";
}

sub MakeLeafOutput {
	my $self = shift;

	foreach $var ("ID","URL","NumLinks","NumImgs","NumAds","NumSSL","Size","LoadTime","ModDate","ModTime","ExternalFlag") {
	
		print L $self->{$var},"\t";
	}
	
	foreach $site (@{$self->{LinksTo}}) {
		print L "$site ";
	}
	print L "\t";
	foreach $site (@{$self->{LinksToSSL}}) {
		print L "$site ";
	}

	print L "\n";
}


###################################################
# From makenh

sub readFile {
   my $file = shift;

   local(*FH);
   my @page = ();
   my($string);
   
   if (open (FH, $file)) {
	   @page = <FH>;
	   close FH;
   } else {
	 warn "wgStats:readFile:Cannot open file $file: $@\n";
	 @page = ();
   }
   $string = join("",@page);
   return $string;
}



# was our own retrieve URL subroutine, because we need to time page loads
sub retrieveURL {
	my $self = shift;
	my $root = $self->{Root};

	my $outfile = shift;	

	if (! $self->{URL}) {
		return 0;
	}

	# Guess if this seems like a static or dynamic page
	my $url = $self->{URL};
	if ($url =~ /\.html?$/) {
		$self->{IsDynamic} = 'N';
	} elsif (($url =~ /cgi/)||($url =~ /\.(pl)|(pm)|(asp)|(sh)|(shtml)|(jhtml)$/)) {
		$self->{IsDynamic} = 'Y';
		$root->{IsDynamic} = 'Y';
	}

	my $cmd = "$WGET -O $outfile -S ".$self->{URL};
	
	my $before = time;
	
# TODO: error handling

	my $raw = `$cmd`;

	my $after = time;

	$self->{ModDate} = 'unknown';
	$self->{ModTime} = 'unknown';

# parse available headers for ModTime & ModDate, also set UsesCookies flag
	$self->ParseHeaders($raw);

	$self->{LoadTime} = $after - $before;

	@_ = stat("$outfile"); 

	$self->{Size} = $_[7];	# may or may not be in headers, get from file directly

	return 1;
}


sub ParseHeaders {
	my $self = shift;
	my $raw = shift;

# Looking for  (with wget prefixed by a number)
#    Last-Modified: Wed, 19 Dec 2001 22:13:32 GMT      
#    Set-cookie: NGUserID=cf1859a0-11285-1008812863-1;

	my @lines = split(/\n/, $raw);

	foreach $line (@lines) {

		if ($USING_WGET) {
			/[0-9]*\s*Last-Modified: (.+)$/ && $self->SetLastModified($1);
			/[0-9]*\s*Set-cookie:/ && ($self->{UsesCookies} = 'Y');
		} else {
			/^Last-Modified: (.+)$/ && $self->SetLastModified($1);
			/^Set-cookie:/ && ($self->{UsesCookies} = 'Y');
		}

	}

	return;
}

sub getWhoisData {
	my $self = shift;

	my ($domain, $url, $output, @lines, $line, $registrant, $address, $in_reg);

	$registrant = '';
	$address = '';
	$in_addr = 0;
	$domain = $self->{Domain} || warn("No domain for $self->{URL}\n") && return;
#	$url = "http://betterwhois.com/bwhois.cgi?domain=$domain";  # doesn't work anymore?  Needed different parsing than below
	$url = "http://checkdomain.com/cgi-bin/checkdomain.pl?domain=$domain";

	$output = `$HTTPGET \'$url\' -o $TMPFILE`;
	open(F, $TMPFILE);
	while (<F>) {
		s/<[^>]+>/ /g;	# remove tags
		if (/Registrant:\s*(.+)$/) {
			$registrant = $1;
			next;
		}
		if (/Address:\s*(.+)$/) {
			$address = $1;
		}
	}
	close(F);
	unlink($TMPFILE);

	chomp $registrant;
	chomp $address;

	$self->{Registrant} = $registrant;
	$self->{Address} = $address;

	return;
}
