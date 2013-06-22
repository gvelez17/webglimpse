#!/usr/bin/perl -T

# wgarcmin - replacement for confarc. Controls flow of webglimpse management interface.
#
# Can be run on command line OR as cgi script
#
# Required parameters when called from web:  (Actual wgArch data members in StudlyCaps)
#
#	username
#	password
#	action
#	
# Optional parameters
#
#	nextpage
#	Id
# 	ArchiveDir
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
	$WEBGLIMPSE_LIB = '|WEBGLIMPSE_LIB|';
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
# Currently wgarcmin.cgi is always called from the web
# The command line manager is wgcmd

$CalledFromWeb = 1;

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
	&CommandWeb::ParseCommandLine(\%in);
}


##############################################################
# Check action - what are we being asked to do?
#  Not case-sensitive.  1st character determines.
#
#	C = Create new archive 
#	A = Add site/dir/tree Root to an archive
#	S = Save changes to an archive
#	T = Save changes to a root
#	B = Build archive (run wgreindex)
#	D = Delete archive
#	R = Remove a root from an archive
#	H = Save changes to a host
#	E = Erase site from configured list
#	X = exit (not needed when run from web)
#
# Then check nextpage - what does user want to do next?
#
#	N = Prompt for new archive parameters (default)
#	A = Add site/dir/tree screen
#	E = Edit site/dir/tree screen
#	M = Manage archive screen
#	H = Host config screen
#	L = New Local Domain  
#	R = New Remote Domain
#	I = Reindex Report screen
#	S = Search page
#	O = Manage all archives screen (overall view)
#	T = Test path translations
#

$action = $in{'ACTION'} || $in{'action'} || '';
$action = substr($action, 0, 1);
$action =~ tr/a-z/A-Z/;

$nextpage = $in{'NEXTPAGE'} || $in{'nextpage'} || 'O';
$nextpage = substr($nextpage, 0, 1);
$nextpage =~ tr/a-z/A-Z/;

$debug && (print "Action = $action, Nextpage = $nextpage\n");

$continue = 1;

my ($ArchID, $mArch, $mRoot, $mRootRef, $RootURL, $ret);

my %Explain = ();
&initialize;


while ($continue) {

	$debug && (print "Continuing action is |$action|<p>\n");

	# Allow a read-only demo mode
	$demomode && ($action = '');

	# First we take care of the requested action

	##############################################################
	# Create Archive - check and save settings passed to script
	#			create files associated with archive
	#  On command line, this may happen as part of New or Edit
	if ($action eq 'C') {

		# Its ok if we can't load archives, maybe there aren't any yet.
		&wgConf::LoadArchs();

		$ArchID = &wgConf::GenArchID() || &ErrorExit("wgConf::GenArchID: $lastError");

		$mArch = wgArch->new($ArchID) || &ErrorExit("wgArch::new: $lastError. Arch id was $ArchID");

		&CommandWeb::AssignInputs(\%in, $mArch, \@wgArch::members) || &ErrorExit("CommandWeb::AssignInputs failed on archive $ArchID");

		# If user selected category from drop-down, override CatCode
		if ($in{'CATEGORY'}) {
			$mArch->{'CatCode'} = $in{'CATEGORY'};
		}
		# $mArch->Validate();

		$mArch->Create() || &ErrorExit("wgArch::Create:  $ret: $lastError");;
	}


	# Adding a Root to an archive
	elsif ($action eq 'A') {

		$ArchID = $in{'ID'} || $in{'ARCHID'} || &ErrorExit($ERR_NOID);
	
		$mArch = &wgConf::GetArch($ArchID) || &ErrorExit("wgConf::GetArch: $lastError, Arch ID was $ArchID");

		$type = $in{'TYPE'} || &ErrorExit("TYPE not defined, please check your form.  See $DocURL for instructions on how to modify the system.");

		$mRoot = new wgRoot;
		&CommandWeb::AssignInputs(\%in, $mRoot, \@wgRoot::members) || &ErrorExit("CommandWeb::AssignInputs failed on root");

		$mRoot->Validate() || &ErrorExit("wgRoot:Validate: $lastError");

		$mArch->LoadRoots || &ErrorExit("wgArch::LoadRoots: $lastError");

		$mArch->AddRoot($mRoot) || &ErrorExit("wgArch::AddRoot: $lastError");

		$mArch->SaveRoots || &ErrorExit("wgArch::SaveRoots: $lastError");
	}

	# Save changes to an archive
	elsif ($action eq 'S') {

		$ArchID = $in{'ID'} || $in{'ARCHID'} || &ErrorExit($ERR_NOID);

		$mArch = &wgConf::GetArch($ArchID) || &ErrorExit("wgConf::GetArch: $lastError, id was $ArchID");

		$mArch->SetCheckboxesOff;	# because we get no value for unchecked boxes

		&CommandWeb::AssignInputs(\%in, $mArch, \@wgArch::members)  || &ErrorExit("CommandWeb::AssignInputs failed on arch $ArchID");

# This was overwriting too many people's individual files...
# Put in warning popup instead of commenting out
		$mArch->MakeArchFiles;	# Rebuild template files with new info

		&wgConf::SaveArch($mArch)  || &ErrorExit("wgConf::SaveArch: $lastError, archive id was $ArchID");


	}

#TODO Roots are defined by URL, but what if someone edits the URL?

	# Save changes to a root
	elsif ($action eq 'T') {
		$ArchID = $in{'ID'} || $in{'ARCHID'} || &ErrorExit($ERR_NOID);
		$RootURL = $in{'STARTURL'} || $in{'StartURL'} || &ErrorExit($ERR_NOSTARTURL);	
		$OldURL = $in{'OLDURL'} || $RootURL;

		$mArch = &wgConf::GetArch($ArchID) || &ErrorExit("wgConf::GetArch: $lastError on id $ArchID");
		$mArch->LoadRoots || &ErrorExit("wgArch::LoadRoots: $lastError");

		# We index roots by URL, so if that changes have to delete & re-add
		if ($OldURL ne $RootURL) {
			$mArch->DelRoot($OldURL) || &ErrorExit("wgArch::DelRoot: $lastError, on archive $ArchID and root $RootURL");
			$mRootRef = new wgRoot;
			$mArch->AddRoot($mRootRef) || &ErrorExit("wgArch::AddRoot: $lastError");
		} else {	
			$mRootRef = $mArch->GetRoot($RootURL) || &ErrorExit("wgArch::GetRoot: $lastError, url was $RootURL");
		}

			# Unchecked boxes won't come through as inputs, so zero out in advance
			$mRootRef->UncheckOptions();
		&CommandWeb::AssignInputs(\%in, $mRootRef, \@wgRoot::members)  || &ErrorExit("CommandWeb::AssignInputs failed on root");
		$mRootRef->Validate() || &ErrorExit("wgRoot:Validate: $lastError");

		$mArch->SaveRoots || &ErrorExit("wgArch:SaveRoots: $lastError");
	}


	##############################################################
	# Build Archive - run wgreindex, if we have permissions to
	elsif ($action eq 'B') {

		$ArchID = $in{'ID'} || $in{'ARCHID'} || &ErrorExit($ERR_NOID);

		$mArch = &wgConf::GetArch($ArchID) || &ErrorExit("wgConf::GetArch: $lastError, id was $ArchID");

		$mArch->Validate || &ErrorExit("wgArch::Validate: $lastError");
		
		# We may want to output the build results to an extra output window 
		my $extrawin = '';

		$mArch->Build(\$extrawin);

# Might put in an option to do this later; for now building in the background.
	#	if ($extrawin) {
	#		$templatehash{'EXTRAWIN'} = $extrawin;
	#	}

	}

	################################################################
	# Delete archive
	elsif ($action eq 'D') {

		$ArchID = $in{'ID'} || $in{'ARCHID'} || &ErrorExit($ERR_NOID);
		$mArch = &wgConf::GetArch($ArchID) || &ErrorExit("wgConf::GetArch: $lastError, id was $ArchID");
		$mArch->Destroy || &ErrorExit("wgArch::Destroy: $lastError");				

	}

	################################################################
	# Remove root from archive
	elsif ($action eq 'R') {
		$ArchID = $in{'ID'} || $in{'ARCHID'} || &ErrorExit($ERR_NOID);
		$RootURL = $in{'STARTURL'} || $in{'StartURL'} || &ErrorExit($ERR_NOSTARTURL);	

		$mArch = &wgConf::GetArch($ArchID) || &ErrorExit("wgConf::GetArch: $lastError on id $ArchID");

		$mArch->DelRoot($RootURL) || &ErrorExit("wgArch::DelRoot: $lastError, on archive $ArchID and root $RootURL");

	}

	################################################################
	# Erase host from configured list
	elsif ($action eq 'E') {
		my $baseurl = $in{"BASEURL"} || $in{'BaseUrl'} || $in{'baseurl'};
		&wgSiteConf::LoadSites;
		&wgSiteConf::RemoveSite($baseurl);  # remove from memory list
		&wgSiteConf::SaveSites;
	}

	################################################################
	# Save changes to Host
	elsif ($action eq 'H') {

		my $servername = $in{"SERVERNAME"} || $in{'ServerName'} || $in{'servername'};
		my $port = $in{'PORT'} || $in{'Port'} || $in{'port'} || '80';
		my $prot = $in{'PROT'} || $in{'Prot'} || $in{'prot'} || 'http';
		$port =~ s/^\s*([^\s]+)\s*$/$1/g;
		$prot =~ s/^\s*([^\s]+)\s*$/$1/g;
		$port = '80' unless ($port ne '');
		$prot = 'http' unless ($prot ne '');
		my $wsite;
                my $oldbaseurl = $in{'BASEURL'} || '';
		my $newbaseurl = "$prot://$servername:$port";
		&wgSiteConf::LoadSites;
		if ($oldbaseurl && ($wsite = &wgSiteConf::GetSite($oldbaseurl))) {
			&CommandWeb::AssignSpecialInputs(\%in, $wsite, \@wgSite::members)  || &ErrorExit("CommandWeb::AssignInputs failed on site");
			$wsite->SetDefaults;  # In case user entered some blanks
		} else {
			$wsite = new wgSite($newbaseurl) || &ErrorExit("Could not create new site for $servername: $lastError");
			&CommandWeb::AssignSpecialInputs(\%in, $wsite, \@wgSite::members)  || &ErrorExit("CommandWeb::AssignInputs failed on site");
			$wsite->SetDefaults;
			&wgSiteConf::AddSite($wsite) || &ErrorExit("Could not add site $servername : $lastError");
		}
		&wgSiteConf::SaveSites || &ErrorExit("wgArch:SaveSites: $lastError");
	}

	################################################################
	# Exit
	elsif ($action eq 'X') {
		$continue = 0;
	}

	################################################################
	# Unknown action code
	elsif ($action) {

	}

	################################################################
	# No action
	else {

	}



#####################################################################
# Completed requested action, now we generate the next page/prompts 
#	Our main task is to generate the hash of values needed by the page template	
#
#  Probably all the code below can be moved in to wgConf.pm or another template module
#
#  Then we could just say $continue = wgconf->GenPage($nextpage, *in)
######################################################################

#	N = Prompt for new archive parameters (default)
#	A = Add site/dir/tree screen
#	E = Edit site/dir/tree screen
#	M = Manage archive screen
#	H = Host config screen 
#	R = Reindex Report screen
#	O = Manage all archives screen (overall view)
#	D = Documenatation page
#
	my $templatefile = '';
	my @marray = ();
	my @sarray = ();


	##############################################################
	# New Archive - get parameters
	if ($nextpage eq 'N') {
		# Only replaced template info is category list
		@catarr = ();	 # Will be array of hashes, for CommandWeb
		
		my $id, $offset;

		$offset = $in{'OFFSET'} || 1;

		if ($in{'CATEGORY'}) {
			$id = pack "C16",split(':',$in{'CATEGORY'});	# User selected from list
		} elsif ($in{'CATCODE'}) {
			$id =  pack "C16",split(':',$in{'CATCODE'});	# Nope, use last code
			if ($offset == -1) { $offset = 0; }		# already up one level
		} else {
			$id = pack "C16", ( (0) x 16 );
			$offset = 0;
		}	

		my $lvl = &CatTree::ListSubCats($id, \@catarr, $offset);

		($templatehash{'CATSTRING'},$templatehash{'CATCODE'}) = &CatTree::GetCatString($id, $lvl);


		$templatehash{'CATS'} = \@catarr;

		# Keep title, description if we have them
		# probably could do this with wgArch::members instead of hardcoded names
		if ($in{'TITLE'}) {
			$templatehash{'TITLE'} = $in{'TITLE'};
		}

		if ($in{'DESCRIPTION'}) {
			$templatehash{'DESCRIPTION'} = $in{'DESCRIPTION'};
		}


		$templatefile = 'tmplNewArch.html';		

		&CatTree::CloseCats;
	}

	##############################################################
	# Add Root to Archive
	elsif ($nextpage eq 'A') {
		# All we need to make sure we have is ARCHID, and TYPE

		if ($in{'ID'}) {
			$templatehash{'ID'} = $in{'ID'};
		} elsif ($in{'ARCHID'}) {
			$templatehash{'ID'} = $in{'ARCHID'};
		} elsif ($ArchID) {
			$templatehash{'ID'} = $ArchID;
		} else {
			&ErrorExit("ID not defined, please check your form.  See $DocURL for instructions on how to modify the system.");
		}

		$type = $in{'TYPE'} || &ErrorExit("TYPE not defined, please check your form.  See $DocURL for instructions on how to modify the system.");

		if ($type eq 'DIR') {
			$templatefile = 'tmplAddDir.html';
		} elsif ($type eq 'SITE') {
			$templatefile = 'tmplAddSite.html';
		} elsif ($type eq 'TREE') {
			$templatefile = 'tmplAddTree.html';
		} else {
			&ErrorExit("TYPE $type is not valid, please check your form.  See $DocURL for instructions on how to modify the system.");
		}	

		$templatehash{'TYPE'} = $type;

		# For fun we include Title if we have it
		if ($mArch) {
			$templatehash{'TITLE'} = $mArch->{'Title'};	
		}

	}


	##############################################################
	# Edit Root - get existing configuration
	elsif ($nextpage eq 'E') {

		# Did user pass Archive ID or path?  Check local dir.
		$mArch = &LoadArchive || &ErrorExit("Cannot load archive containing root to edit");

		# User also should have passed StartURL, if not use the first one
		$mArch->LoadRoots || &ErrorExit("wgArch::LoadRoots: $lastError");        # LastErr will be set
	
		if (defined($in{'STARTURL'})) {
			$mRoot = $mArch->GetRoot($in{'STARTURL'}) || &ErrorExit("wgArch::GetRootRef: $lastError, URL was ".$in{'STARTURL'});
		} else {
			$mRoot = ${$mArch->{Roots}}[0] || &ErrorExit("wgarcmin: Do not seem to have any roots loaded, cannot edit");
		}
	
		# Now set the template vars needed
		&CommandWeb::BuildHash(\%templatehash, $mRoot, \@wgRoot::members, $USEUPPER) || &ErrorExit("CommandWeb::BuildHash: ".$CommandWeb::lastError." failed on root, hash is %templatehash");

		$templatehash{'ID'} = $mArch->{ID};

		# Choose correct template file for root type
		if ($mRoot->{'Type'} eq 'DIR') {
			$templatefile = 'tmplEditDir.html';
		} elsif ($mRoot->{'Type'} eq 'SITE') {
			$templatefile = 'tmplEditSite.html';
		} elsif ($mRoot->{'Type'} eq 'TREE') {
			$templatefile = 'tmplEditTree.html';
		} else {
			&ErrorExit("Unrecognized root type $mRoot->{'Type'} ");
		}
	}

	######################################################################3
	# Manage Archive
	elsif ($nextpage eq 'M') {

		my @members = @wgArch::members;
		push(@members, 'Status','StatusMsg','WusageLink');

		$mArch = &LoadArchive || &ErrorExit("Could not find an archive to manage.");

		&CommandWeb::BuildHash(\%templatehash, $mArch, \@members, $USEUPPER) || &ErrorExit("CommandWeb::BuildHash: ".$CommandWeb::lastError." failed on arch, hash is %templatehash");

		# In addition to category code we need string

		my $id =  pack "C16",split(':',$mArch->{CatCode});	
		my $junk;
		($templatehash{'CATSTRING'},$junk) = &CatTree::GetCatString($id, 16);
		$templatehash{'PROPERLANG'} = &LangUtils::GetProperName($mArch->{Lang});    
		# Now we need to add a reference to an array of hashes for the Roots
		# $mArch->{Roots} is basically it, but we don't need the extra object baggage

		$mArch->LoadRoots || &ErrorExit("wgArch::LoadRoots: $lastError");
		
		if ($#{$mArch->{Roots}} >= 0) {

			&CommandWeb::BuildHashArray(\@marray, $mArch->{Roots}, \@wgRoot::members, $USEUPPER) || &ErrorExit("CommandWeb::BuildHashArray failed on roots array : ".$CommandWeb::lastError." ".$lastError);
		} else {
			@marray = ();
		}

		$templatehash{'ROOTS'} = \@marray;

		# Also a reference to an array of hashes for each domain still to be defined
		


		$templatefile = 'tmplManageArch.html';
	}


	######################################################################3
	# Manage All Archives (Overall view)
	elsif ($nextpage eq 'O') {
		
		# TODO: add status var to each archive object
		
		my @carray = ();
		my @members = ();
		@marray = ();

		if (&wgConf::LoadArchs) {	# May legit. return 0 if no archives exist
			@carray = values(%wgConf::Archives);

			@members = @wgArch::members;
			push(@members, 'Status','StatusMsg');

			&CommandWeb::BuildHashArray(\@marray, \@carray, \@members, $USEUPPER) || &ErrorExit("CommandWeb::BuildHashArray failed on Archives array : ".$CommandWeb::lastError);
		}
		
		$templatehash{'ARCHIVES'} = \@marray;

		if (&wgSiteConf::LoadSites) {
			@carray = values (%wgSiteConf::Sites);
			@members = @wgSite::members;
			push(@members, 'IsLocal');
			push(@members, 'BaseUrl');
			push(@members, 'NotDefault');
			&CommandWeb::BuildHashArray(\@sarray, \@carray,\@members,$USEUPPER) || &ErrorExit("CommandWeb::BuildHashArray failed on Sites array: ".$CommandWeb::lastError);
		} else {
			print "Couldn't load sites, last error was $lastError\n<p>";
		}
		$templatehash{'SITES'} = \@sarray;

		$templatefile = 'tmplManageAll.html';		

	}


	######################################################################
	# Host Config screen
	elsif ($nextpage eq 'H') {
		
		my $baseurl = $in{"BASEURL"} || $in{'BaseUrl'} || $in{'baseurl'} || &ErrorExit("No domain name selected.  Please go back and highlight a domain name to configure.");
		my $wsite = &wgSiteConf::GetSite($baseurl);
		if (!defined($wsite)) {
			$wsite =  new wgSite($baseurl);
		}

		my @members = @wgSite::members;
		push(@members, 'BaseUrl');

		&CommandWeb::BuildHash(\%templatehash, $wsite, \@members, $USEUPPER) || &ErrorExit("CommandWeb::BuildHash: ".$CommandWeb::lastError." failed on site, hash is %templatehash");

		if ($wsite->IsLocal) {
			$templatefile = 'tmplLocalDomain.html';
		} else {
			$templatefile = 'tmplRemoteDomain.html';
		}
	}

	#####################################################################
	# New Host/Domain Config screen
	elsif (($nextpage eq 'L')||($nextpage eq 'R')) {

		my $wsite = new wgSite('');	# use dummy var for defaults
		my @members = @wgSite::members;
		&CommandWeb::BuildHash(\%templatehash, $wsite, \@members, $USEUPPER) || &ErrorExit("CommandWeb::BuildHash: ".$CommandWeb::lastError." failed on site, hash is %templatehash");
		$templatehash{'SERVERNAME'} = $in{'NEWDOMAIN'} || '';
		if ($nextpage eq 'L') {
			$templatefile = 'tmplLocalDomain.html';
		} else {
			$templatefile = 'tmplRemoteDomain.html';
		}
	}

	#####################################################################
	# Info/Report Screen
	elsif ($nextpage eq 'I') {

	}

	######################################################################
	# Search Screen
	elsif ($nextpage eq 'S') {
		
		$mArch = &LoadArchive || &ErrorExit("Could not find an archive to manage.");
		%templatehash = {};
		$templatefile = $mArch->{Dir} . '/wgindex.html';
	}

	######################################################################
	# Doc page
	elsif ($nextpage eq 'D') {
		my $pagename = $in{'DOC'} || 'docFAQ.html';

		# Some doc pages are customized by archive; if so we'll be passed the archive ID
		if ($in{'ID'}) {
 			my @members = @wgArch::members;
	                $mArch = &LoadArchive || &ErrorExit("Could not find an archive to manage.");
        	        &CommandWeb::BuildHash(\%templatehash, $mArch, \@members, $USEUPPER); # error not fatal
		}
		$templatehash{CGIBIN} = $CGIBIN;
		$templatehash{WGARCMIN} = $WGARCMIN;
		$templatefile = $pagename;
	}


	######################################################################
	# Test path translations
	elsif ($nextpage eq 'T') {
		my $file = $in{'FILE'} || $in{'file'} || '';
		my $url = $in{'URL'} || $in{'url'} || '';
		my $dom = $in{'DOMAIN'} || $in{'domain'} || '';
		my $canon = '';

		&wgSiteConf::LoadSites;

		if ($file) {
			$url = &wgSiteConf::LocalFile2URL($file);
		} elsif ($url) {
			$file = &wgSiteConf::LocalURL2File($url);
		}

		if ($dom) {
			$canon = &wgSiteConf::Canonicalize($dom);
		}

		$templatehash{'FILE'} = $file;
		$templatehash{'URL'} = $url;
		$templatehash{'DOMAIN'} = $dom;
		$templatehash{'CANON'} = $canon;

		$templatefile = 'tmplTestTrans.html';

	}

	######################################################################3
	# Bogus action
	else {
		&ErrorExit("Unknown value $nextpage given for NEXTPAGE");
	}

	# done with if..else
	######################################################################3

	if ($CalledFromWeb) {
		if ($templatefile !~ /^\//) {
			$templatefile = $WGTEMPLATES.'/'.$templatefile;
		}
		$debug && (print "About to use $templatefile for output\n");
		&CommandWeb::OutputTemplate("$templatefile",\%templatehash) || &ErrorExit("CommandWeb::OutputToWeb failed on $templatefile, hash was ",%templatehash);
		$continue = 0;
	} else {
		&SetDefaults(\%in, $nextpage);

		$continue = &CommandWeb::PromptUser($Explain{$nextpage}, \%in, \%Prompts);
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



#
#	N = Prompt for new archive parameters (default)
#	A = Add site/dir/tree screen
#	E = Edit site/dir/tree screen
#	M = Manage archive screen
#	H = Host config screen 
#	R = Reindex Report screen
#	S = Search page
#	O = Manage all archives screen (overall view)
#
sub initialize {

	$Explain{'N'} = "N = Prompt for new archive parameters";
	$Explain{'A'} = "A = Add new root to archive";
	$Explain{'E'} = "E = Edit an archive root";
	$Explain{'M'} = "M = Manage archive";
	$Explain{'H'} = "H = Configure host/domain";
	$Explain{'R'} = "R = Reindex report";
	$Explain{'S'} = "S = Search archive";
	$Explain{'O'} = "O = Manage all archives";


	$Prompts{'ID'} = "Archive ID:";
	$Prompts{'Dir'} = "Directory where archive files are stored (NOT directory to be indexed, that will be asked later)";

}

sub SetDefaults {
	my ($inref, $nextpage) = @_;

	%$inref = ();

	if ($nextpage eq 'N') {
		$$inref{'TITLE'} = '';
		$$inref{'CATEGORY'} = '';
#TODO:

	} elsif ($nextpage eq 'A') {
	} elsif ($nextpage eq 'E') {
	} elsif ($nextpage eq 'M') {
	} elsif ($nextpage eq 'H') {
	} elsif ($nextpage eq 'R') {
	} elsif ($nextpage eq 'S') {
	} elsif ($nextpage eq 'O') {
	} else {
		
	}

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

