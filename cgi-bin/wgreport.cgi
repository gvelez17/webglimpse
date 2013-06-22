#!/usr/bin/perl -T

# wgreport - run reports on Webglimpse archives. Lists files that might not have
# indexed correctly.
#
# Can be run on command line OR as cgi script
#
# Required parameters:  

# 	ID = archive ID

#
# Uses package CommandWeb (generic, useful for dual command-line/web interfaces)
# Includes functions   
#
#	ParseCommandLine	Builds hash from command line options
#	ValidatePassword	Check password vs encrypted file
#	OutputToWeb		Generates web form from a template
#	PromptUser		Command line prompts for inputting archive settings
#
# Uses packages wgConf, wgArch  (specific to Webglimpse)
#	wgConf handles the user interface
#	wgArch represents an archive
#
my $REVISION = '$Id $';

BEGIN {
#	$WEBGLIMPSE_LIB = '|WEBGLIMPSE_LIB|';
	$WEBGLIMPSE_LIB = '/usr/local/wg2/lib/';
	unshift(@INC, "$WEBGLIMPSE_LIB");			# Find the rest of our libs

	# Check if we can access the lib dir
	if ( ! -e "$WEBGLIMPSE_LIB/wgHeader.pm") {

		print "Content-type: text/html\n\n";
		print "<HTML><BODY>";
		print "<b>Error:</b>Cannot access required library files in directory $WEBGLIMPSE_LIB<p>\n";
		print "You may need to reinstall Webglimpse to a different directory or change the permissions on the current install directory.  Please check with your system administrator where you can safely install data files that can be accessed by a cgi script, but are NOT directly under document root (web document space).  You may also contact support\@webglimpse.net for general assistance.\n";
		print "</BODY></HTML>";
		exit(1);
	}

}
BEGIN {
	use wgHeader qw( :all);
	use wgTextMsgs qw( :wgarcmin );
	use wgErrors;
}

my $debug = 0;
my $demomode = 0;

# Public libraries we need installed
use CGI qw(:cgi-lib);

# Our own libraries/modules
use wgConf;
use wgArch;
use wgSite;
use wgSiteConf;
use CommandWeb;
use CatTree;

$WGARCMIN = '/'.$CGIBIN.'/wgarcmin.cgi';
$WEBGLIMPSE = '/'.$CGIBIN.'/webglimpse.cgi';
$WGREPORT = '/'.$CGIBIN.'/wgreport.cgi';

my ($CalledFromWeb, $action, $nextpage, $continue, $wgConf);

my (%in, $num);

$lastError = '';

my $USEUPPER = 1;

# We may store some vars in templatehash from the action as well as nextpage
my %templatehash = ();
$templatehash{'EXTRAWIN'} = '';		# Special var for opening extra output window

# We need at least reference to ourself, may need ref to webglimpse
$templatehash{'WGARCMIN'} = $WGARCMIN;
$templatehash{'WEBGLIMPSE'} = $WEBGLIMPSE;
$templatehash{'WGHOME'} = $WGHOME;

my @catarr = ();	# Array of category hashes (has to be structured this way for CommandWeb)

##############################################################

$CalledFromWeb = 0;

# If we are called from the web, we need to check the password
# For security reasons, we check every time, no matter what, before we do anything else.

# We use ReadParse rather than the param() function, so that we get a hash.
# We can use the hash data whether it was gathered from the web or command line

my $User = '';
my $cstring;
if ($CalledFromWeb) {

	$num = ReadParse(\%in);		# From CGI.pm 

	# If the user had their own security, we get REMOTE_USER variable
	if (defined $ENV{'REMOTE_USER'}) {
		$User = $ENV{'REMOTE_USER'};
	}

	# If the user has a .wgpasswd file, make sure we get a username/pass;
	# use cookies since we aren't doing httpd authentication
	elsif (-e $PasswordFile) {
		# Did we get username from web?
		if (exists $in{'USERNAME'}) {
			my $tpass = &CommandWeb::ValidatePassword($in{'USERNAME'}, $in{'PASSWORD'}, $PasswordFile); 
			if (! $tpass) {

                        	print "Content-type: text/html\n\n";    
				$templatehash{'MSG'} = "Invalid username or password.  Please try again.\n";
                        	&CommandWeb::OutputTemplate("$WGTEMPLATES/tmplLoginPage.html",\%templatehash) 
					|| &CErrorExit("CommandWeb::ValidatePassword: ".$CommandWeb::lastError,"<p>".$ErrMsg{$ERR_BADPASS});

				exit 1;

			}

			$User = $in{'USERNAME'};
			
			my $expire = &nexthour;

			print "Set-Cookie: LOGIN=$User:$tpass; path=/;\n";
		} 
		# If we have the user cookie, we're ok; otherwise prompt for it
		elsif (exists $ENV{'HTTP_COOKIE'}) {	
			if ($ENV{'HTTP_COOKIE'} =~ /(^|;)\s*LOGIN=([^;:]+):([^;]+)/) {
				$User = $2;
				my $tpass = $3;
				if ($tpass ne &CommandWeb::TempPass($User,$PasswordFile)) {
                        		print "Content-type: text/html\n\n";    
					$templatehash{'MSG'} = 'Login expired!  Please log in again.';
                        		&CommandWeb::OutputTemplate("$WGTEMPLATES/tmplLoginPage.html",\%templatehash) 
						|| &ErrorExit("CommandWeb::OutputToWeb failed, cannot generate login page");

                        		exit 1;
				}
			} else {
				print "Content-type: text/html\n\n";
				$templatehash{'MSG'} = 'Strange - there is a cookie but no LOGIN info.  Please log in again.';
				&CommandWeb::OutputTemplate("$WGTEMPLATES/tmplLoginPage.html",\%templatehash) 
					|| &CErrorExit("No LOGIN available. Cookie was".$ENV{'HTTP_COOKIE'}."\n");
				exit 1;
			}	
		} else {

			print "Content-type: text/html\n\n";	# We always generate the returned page
  			&CommandWeb::OutputTemplate("$WGTEMPLATES/tmplLoginPage.html",\%templatehash) || &ErrorExit("CommandWeb::OutputToWeb failed, cannot generate login page");

			exit 1;
		}
	} 

	# Otherwise, there is no security!
	else {
		$User = '';
	}
        if ($User eq 'guest') {
                $demomode = 1;
        }

	print "Content-type: text/html\n\n";	# We always generate the returned page

} else {
	print "Not called from web\n";
	# The only param is ID
	$in{'ID'} = $ARGV[0];
}


##############################################################
# Check action - what are we being asked to do?
#  Not case-sensitive.  1st character determines.
#
#	A = check archive for docs not correctly indexed (default)
#	X = exit (not needed when run from web)
#

$action = $in{'ACTION'} || $in{'action'} || 'A';
$action = substr($action, 0, 1);
$action =~ tr/a-z/A-Z/;

$continue = 1;

my ($ArchID, $mArch, $mRoot, $mRootRef, $RootURL, $ret);

my %Explain = ();


while ($continue) {

	$debug && (print "Continuing action is |$action|<p>\n");

	# Allow a read-only demo mode
	$demomode && ($action = '');

	# First we take care of the requested action


	# Archive report
	if ($action eq 'A') {

		print("In A\n");

		$ArchID = $in{'ID'} || $in{'ARCHID'} || &ErrorExit($ERR_NOID);
		$ValidBytes = $in{'MinBytes'} || $in{'MINBYTES'} || 100;	

		$mArch = &wgConf::GetArch($ArchID) || &ErrorExit("wgConf::GetArch: $lastError, Arch ID was $ArchID");

		$ArchDir = $mArch->{'Dir'};
	
		@report = ();	# array of hashes w/url, bytes

		# Examine .wg_toindex
		open F, $ArchDir.'/'.$FLISTFNAME;		
		my $href;
		while(<F>) {
			my ($fname, $url) = split(/\t/);
			@_ = stat($fname);
			my $fsize = $_[7];
			if ($fsize < $ValidBytes) {			
				$href = {};
				$href->{'File'} = $fname;
				$href->{'Url'} = $url;
				$href->{'Size'} = $fsize;
				push @report, $href;

			print $href->{'Url'},"\t",$href->{'Size'},"\n";
			}
		}
		close F;		

	}

	$templatehash{'FILEERRS'} = \@report;

	$templatefile = 'wgReport.html';

	if ($CalledFromWeb) {
		if ($templatefile !~ /^\//) {
			$templatefile = $WGTEMPLATES.'/'.$templatefile;
		}
		$debug && (print "About to use $templatefile for output\n");
		&CommandWeb::OutputTemplate("$templatefile",\%templatehash) || &ErrorExit("CommandWeb::OutputToWeb failed on $templatefile, hash was ",%templatehash);
		$continue = 0;
	} else {
		foreach my $href (@report) {
			print $href->{'Url'},"\t",$href->{'Size'},"\n";
		}
		$continue = 0;
	} 

 } # End while $continue

1;

##############################################################
##############################################################

sub LoadArchive {
	
	my $march;

	# Did user pass Archive ID or path?  Check local dir.
	my $id = $in{'ID'} || $in{'ARCHID'} || $ArchID;
	if (defined($id)) {	# User-specified archive
		$march = &wgConf::GetArch($id);	
	} elsif (defined($in{'ARCHDIR'})) {	# User-specified directory
		$march = &wgConf::GetArchbyPath($in{'ARCHDIR'});
	} elsif (!$CalledFromWeb) {				# Try local dir
		$march = &wgConf::GetArchbyPath('.');	
	}
	
	return($march);
}




# Substitute our local vars into prompts & messages
sub subvars {
        my $msg = shift;

        # substitute our vars as needed

        # We always have these
        $msg =~ s/\|LASTERROR\|/$lastError/g;
	$msg =~ s/\|DOCURL\|/$DOCURL/g;
        $msg =~ s/\|VERSION\|/$VERSION/g;
        $msg =~ s/\|WGHOME\|/$WGHOME/g;
        $msg =~ s/\|WGARCHIVE_DIR\|/$WGARCHIVE_DIR/g;
        $msg =~ s/\|CGIBIN_DIR\|/$CGIBIN_DIR/g;
        $msg =~ s/\|CGIBIN\|/$CGIBIN/g;
        $msg =~ s/\|LEGALOS\|/$LEGALOS/g;
        $msg =~ s/\|WGSITECONF\|/$wgSiteConf::CfgFile/g;

        # Other vars may be available
        $servername     && ($msg =~ s/\|SERVERNAME\|/$servername/g);
        $docroot        && ($msg =~ s/\|DOCROOT\|/$docroot/g);
        $webuser        && ($msg =~ s/\|WEBUSER\|/$webuser/g);

        # remove any vars we don't use
        $msg =~ s/\|[^\|\n]*\|//g;

        return $msg;
}


sub CErrorExit {
	my $msg = shift;
	print "Content-type: text/html\n\n";
	&ErrorExit($msg);
}


sub ErrorExit {

        my $msg = shift;

	$msg = &subvars($msg);

        print STDERR scalar localtime, "$msg";

        print "ERROR: $msg\n\n";

        if ($debug) {
                my $name;
                print "Inputs were: <p>\n";
                foreach $name (keys (%in)) {
                        print "$name = $in{$name} <p>\n";
                }
        }

        exit 0;
}

sub nexthour {
    my @months = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug",
               "Sep","Oct","Nov","Dec");
    my @days = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat");

    my ($sec,$min,$hr,$mday,$mon,$yr,$wday,$yday,$isdst) = gmtime(time + 3600);

    # format must be Wed, DD-Mon-YYYY HH:MM:SS GMT
    my $timestr = sprintf("%3s, %02d-%3s-%4d %02d:%02d:%02d GMT",
        $days[$wday],$mday,$months[$mon],$yr+1900,$hr,$min,$sec);
    return $timestr;
}

