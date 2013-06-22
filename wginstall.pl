#!/usr/local/bin/perl

# Installation script for Webglimpse 2.X
# See included COPYRIGHT file for license info
#
# (almost) all text messages are in the module wgTextMsgs.pm so that 
# they can be more easily translated. 
#
#
# Basically, the install does the following:
#  
# Prompts user and creates directories for WGHOME, WGARCHIVE_DIR, CGIBIN_DIR
# Checks we have binaries and Glimpse, tries to retrieve if not
# Compiles httpget if necessary
# Generates wgsites.conf file with minimum site config settings
# Copies all files modifying wgHeader.pm with our constants
# Creates dist files
# Offer to generate simple archives on command line
#
# There are three major cases we can see
#
my $UPGRADE1 = 1;  # upgrade from v 1.X
my $UPGRADE2 = 2;  # upgrade from v 2.X
my $NEWINST = 3;   # new install

my $REVISION='$Id $';

my $LEGALOS  = 'linux sco freebsd hpux sunos solaris osf irix';
my $DEFAULTOS = 'linux';
my $PLATFORM = $ARGV[1] || $^O || '';

#Languages we have some information or files for
my @HAVE_LANG = ('hebrew','german','spanish','portuguese','finnish','french','norwegian', 'estonian', 'italian', 'polish', 'bulgarian', 'romanian');

BEGIN {
	unshift(@INC, './lib');	# include from unpacked distribution
}

use wgHeader qw( :all );  #includes global $lastError 
use wgErrors;
use wgTextMsgs qw( :install :general );
use wgSiteConf;

BEGIN {

$have_readkey = 
	eval "require Term::ReadKey";
}

$lastError = '';

# Local variables & defaults
my ($servername, $docroot,$webuser, $instcase);    
$servername = '';
$docroot = '';
$instcase = $NEWINST;
$webuser = 'nobody';

# Welcome message to user, explain what Webglimpse is
&WelcomeMsg || &ErrorExit("User terminated install");

# Find a home directory we can write to
$WGHOME = &FindWritableHome($WGHOME);

# Prompt user for installation directory and other essential dirs
$WGHOME = &prompt($PROMPT_HOME_DIR, $WGHOME);

# Set WEBGLIMPSE_LIB so we can replace it in files as needed
$WEBGLIMPSE_LIB = $WGHOME.'/lib';

# Remove any trailing '/'
if ($WGHOME =~ /\/$/) {
        chop $WGHOME;
}
if ( ! ( -d $WGHOME ) ) {
        mkdir($WGHOME, 0755) || die "\nERROR - Aborting install. Could not create directory $WGHOME.\n  Error was $!\n";
}
$WGARCHIVE_DIR = "$WGHOME/archives";

# Check for Glimpse early  on - don't waste user's time if not installed

# Check if we have needed system binaries
&CheckBinaries || &ErrorExit("CheckBinaries: $lastError");

# See if Glimpse is installed
$glimpseok = &CheckGlimpse;


# See if there is an existing config file, which version, set defaults
# 1.X uses .wgsiteconf in WGHOME, 2.X uses wgsites.conf in WGARCHIVE_DIR
# May also parse httpd.conf, prompt user for main settings.  
# Gets defaults for webuser, CGIBIN_DIR, and CGIBIN
$instcase = &SiteConfig($WGHOME);

# Prompt user for correct directories
# These settings will be saved in a modifed copy of wgHeader.pm
if ($instcase == $UPGRADE2) {
	if  (! -e $WGARCHIVE_DIR) {
		$WGARCHIVE_DIR = &prompt_writable_dir($PROMPT_ARCH_DIR, $WGARCHIVE_DIR);
	}

} else {
	$WGARCHIVE_DIR = &prompt_writable_dir($PROMPT_ARCH_DIR, $WGARCHIVE_DIR);

	$CGIBIN_DIR = &prompt_writable_dir($PROMPT_CGI_DIR, $CGIBIN_DIR);

	# Chop off trailing slash and whitespace
	$CGIBIN_DIR =~ s/\/*\s*$//g;

	# Make a guess what the equivalent url is
	# (should really only guess if we didn't read the defaults from httpd.conf)
	if ($CGIBIN_DIR =~ /\/cgi-bin\/(.+)$/) {
		$CGIBIN = 'cgi-bin/'.$1;
	}

	$CGIBIN = &prompt($PROMPT_CGIBIN, $CGIBIN);
	$CGIBIN =~ s/^\s*\/+(.+)$/$1/g;
	$CGIBIN =~ s/^(.+)\/+\s*$/$1/g;		# Remove leading & trailing slashes and whitespace
	$webuser = &prompt($PROMPT_WEBUID, $webuser);
	$WWWUID = (getpwnam($webuser))[2];  


	my $user = $ENV{'LOGNAME'} || `whoami`;
	chomp $user;
	$ADMIN_EMAIL = &prompt($PROMPT_ADMIN_EMAIL, "$user\@$servername");
	if (($ADMIN_EMAIL eq 'N')||($ADMIN_EMAIL eq 'n')) { $ADMIN_EMAIL = '';}
	if ($ADMIN_EMAIL ne '') {
		$SENDMAIL = &prompt($PROMPT_SENDMAIL, $SENDMAIL);
	}

	&IsWritable($USRBIN_DIR) || ($USRBIN_DIR = $WGHOME); 
	$USRBIN_DIR = &prompt_writable_dir($PROMPT_USRBIN, $USRBIN_DIR);
}

# If we are upgrading from a version not including wgLog, ask about WUSAGE
if (( -e "./lib/wgLog.pm") && (($instcase != $UPGRADE2) || (! -e "$WGHOME/lib/wgLog.pm"))) {
	# Ask if user has wusage around
	if (&prompt($PROMPT_HAVE_WUSAGE,'N') =~ /^[yY]/) {
		$WUSAGE = &prompt($PROMPT_PATH_WUSAGE, $WUSAGE);
		if ($WUSAGE_DIR eq '') {
			$WUSAGE_DIR = $docroot.'/wusage';
		}
		$WUSAGE_DIR = &prompt($PROMPT_WUSAGE_DIR, $WUSAGE_DIR);
	} else {
		$WUSAGE = '#';      # To comment out line in wgreindex starting with WUSAGE
		$WUSAGE_DIR = '';
	}
}

# We now stick with htuml2txt.pl and prefiltering.  If they want
# another filter they can manually edit .glimpse_filters

my $filter = 2;

$HTML2TXTPROG = 'htuml2txt.pl';		# perl version w/ lang support


&CreateDirs || &ErrorExit("CreateDirs: $lastError");

# Write wgsites.conf file
&wgSiteConf::SaveSites($WGARCHIVE_DIR) || &ErrorExit("ERROR: wgSiteConf::SaveSites: $lastError");

# TODO : if archives already exist offer to update dist & template files in each archive


# See if httpget is already present, if not compile it
#while (! &CheckHttpGet) {  # Also give user option to compile new vers.

&CompileProgs || &ErrorExit("CompileProgs: $lastError");

&CheckHttpGet;


#}

# Try to get glimpse if we don't have it
while (!$glimpseok) {

	# Give user options - press enter after installing yourself, or A to auto-install
	if (&prompt($PROMPT_GET_GLIMPSE) =~ /^[aA]/) {  # Ask user to get glimpse, or try to do it ourselves

		&AutoInstallGlimpse;  # Don't die if we fail, give user another chance

	}

	$glimpseok = &CheckGlimpse;
}


# Prompt user for security system unless is already present
if (! -e "$WGHOME/$PASSFILE") {
	if (&prompt($PROMPT_SECURITY,'Y') =~ /^[yY]/) {
		&CreatePasswdFile || &ErrorExit("CreatePasswdFile: $lastError");
	} else {
		print &subvars($MSG_WARN_SECURITY);
	}
}


if (($instcase == $NEWINST) || !defined($REGISTER_ARCHIVES)) {
	if (&prompt($PROMPT_REGISTER_OK,'') =~ /^[yY]/) {
		$REGISTER_ARCHIVES = 'Y';
	} else {
		$REGISTER_ARCHIVES = 'N';
	}
}

if ($instcase == $UPGRADE2) {
	&prompt($PROMPT_WILL_OVERWRITE);
}

# Now we have all the pieces we need, start to copy files
print &subvars($MSG_COPYING_FILES);
&CopyFiles || &ErrorExit("CopyFiles: $lastError");


print &subvars($MSG_FINAL);

if ($instcase == $NEWINST) {
	if (&prompt($PROMPT_MAKE_ARCH,'Y') =~ /^[yY]/) {
		exec("$USRBIN_DIR/wgcmd N");
	}
} else {
	if  (&prompt($PROMPT_RUN_WGCMD,'Y') =~ /^[yY]/) {
                exec("$USRBIN_DIR/wgcmd");
        }
}

1;


##################################################################
sub WelcomeMsg {
	print &subvars($MSG_WELCOME);
#	&prompt($PROMPT_RETURN_TO_CONTINUE, '');
	return 1;
}

##################################################################
sub CreatePasswdFile {
	my $ret = 1;

	my $user = &prompt($PROMPT_USERNAME,'admin');

	my $pass;

	if ($have_readkey) {
		$pass = &secret_prompt($PROMPT_PASSWD);
	} else {
		$pass = &prompt($PROMPT_PASS_INSECURE);
	}

	$pass = crypt($pass, 'wg');

	open(F, ">>$WGHOME/$PASSFILE") 
		|| ($lastError .= "Cannot open $WGHOME/$PASSFILE for writing : $!\n")
		&& (return 0);

	print F "$user:$pass\n";

	close F;

	return 1;
}



##################################################################
sub CreateDirs {

	my $ret = 1;

	my $madenewdirs = 0;

	# We already created $WGHOME if it did not exist

	my ($dir,$lang);

	my @dirlist = ("$WGHOME/lib","$WGHOME/dist","$WGHOME/tests","$WGHOME/templates");
	foreach $lang (@HAVE_LANG) {
		push @dirlist,"$WGHOME/templates/$lang";
	}

	foreach $dir (@dirlist) {

		# Create the subdirectories if necessary
		if ( ! ( -d $dir ) ) {

        		mkdir($dir, 0755) 
			|| ($lastError .= "Cannot create directory $dir : $!\n")
			&& ($ret = 0);
		}
	}

	# Create WG Archive dir if doesn't exist
	if ( ! ( -d "$WGARCHIVE_DIR" ) ) {
		mkdir($WGARCHIVE_DIR, 0755) 
			|| ($lastError .= "Cannot create directory $WGARCHIVE_DIR : $!\n")
			 && ($ret = 0);

		# create initial archives list file
		my $archlist = $WGARCHIVE_DIR.'/'.$ARCHIVE_LIST;
	        if (open(FILE, ">$archlist")) {

	                print FILE "# Archive list for Webglimpse\n";
        	        print FILE "# ID#  Name          URL                     Hierarchy ID    Context ID  Description\n\n";
                	close FILE;
		} else {
			$lastError .= "WARNING: unable to create archive list $archlist : $! \n";
		}

		# create initial wgsites.conf file
		my $cfgfile = $WGARCHIVE_DIR.'/'.$SITECONF;
                if (open(FILE, ">$cfgfile")) {

                        print FILE "# Site configuration file for Webglimpse\n";
			print FILE "# Should contain info for all relevant local domains\n\n";
                        close FILE;
                } else {
                        $lastError .= "WARNING: unable to create siteconf file $cfgfile : $! \n";
                }

		$madenewdirs = 1;

	}

	# Create CGIBIN dir if doesn't exist
	if ( ! ( -d $CGIBIN_DIR ) ) {
        	mkdir("$CGIBIN_DIR", 0755) 
			|| ($lastError .= "Cannot create directory $CGIBIN_DIR : $!\n")
			&& ($ret = 0);
	}

	# Create WUSAGE report dir if user specified one and it doesn't exist
	if ( ($WUSAGE_DIR ne '') && ! (-d $WUSAGE_DIR)) {
		mkdir("$WUSAGE_DIR", 0755)
			|| warn("Not able to create directory $WUSAGE_DIR for wusage reports: $!\n");
		$madenewdirs = 1;
	}

	if ($madenewdirs) {
	     &MakeWebWritable || warn("Not able to make all files web writable; error was $lastError\n");
	}

	return $ret;
}

##################################################################
sub MakeWebWritable {

	my $cfgfile =  $WGARCHIVE_DIR.'/'.$SITECONF;
	my $archlist = $WGARCHIVE_DIR.'/'.$ARCHIVE_LIST;
	my $ret = 1;

	if (prompt($PROMPT_CHOWN_WWW, 'Y') =~ /^[yY]/) {
		chown($WWWUID, -1, $WGARCHIVE_DIR) 
			|| ($lastError = "chown failed on $WGARCHIVE_DIR: $!\n") && ($ret = 0);
		chown($WWWUID, -1, $cfgfile)
			|| ($lastError = "chown failed on $cfgfile: $!\n") && ($ret = 0);
		chown($WWWUID, -1, $archlist)
			|| ($lastError = "chown failed on $archlist: $!\n") && ($ret = 0);

		if (($WUSAGE_DIR ne '') && prompt($PROMPT_CHOWN_WUSAGE, 'Y') =~ /^[yY]/) {
			chown($WWWUID, -1, $WUSAGE_DIR) 
				|| warn("chown failed on $WUSAGE_DIR: $!");
		}

	}

	if (($ret == 0) && (prompt($PROMPT_CHMOD_777, 'Y') =~ /^[yY]/)) {
		$ret = 1;
		$lastError = '';
		chmod(0777, $WGARCHIVE_DIR)
			|| ($lastError = "chmod failed on $WGARCHIVE_DIR: $!") && ($ret = 0) && break;
		chmod(0777, $cfgfile)
			|| ($lastError = "chmod failed on $cfgfile: $!") && ($ret = 0);
		chmod(0777, $archlist)
			|| ($lastError = "chmod failed on $archlist: $!") && ($ret = 0);
	}

	# Don't fail completely if chown failed, let user do it themselves
	if ($ret == 0) {

		print "\n\nSorry, cannot make your archives web-writable.\n".
		      " You will need to do it manually if you want to use the web interface.\n".
		      " After completing the install, run \n\n".
		      "      chown -R $webuser $WGARCHIVE_DIR\n\n".
		      " If you do not want to do this, you can still use \n".
		      "      $WGHOME/wgcmd \n".
	   	      " to manage your archives (you will have to do some edits manually).\n\n"

		&prompt("Hit return to continue","");

	}

	return 1;
}


#####################################################################################
# CopyFiles routine takes care of actually installing all wg files
sub CopyFiles {

	##################################################################
	# Files to copy

	my @cgibinfiles=(               "webglimpse.cgi",	# main cgi search script
        # REMOVED for security reasons.  If you can run in a safe intranet environment,
        # uncomment the following line to install the web-based archive manager wgarcmin.cgi
        #                               "wgarcmin.cgi",
	#                               "catarch",
					"showimg.cgi",	# to show eye image
                	                "mfs.cgi",      # for jump-to-line
					"wrrepos.cgi",  # for using Webglimpse as scientific reprints repository [TT]
					"wrsearch.cgi");# for using Webglimpse as scientific reprints repository [TT]



	my @execs=(            	
                                "addsearch",	# adds search boxes
                                "makenh",	# make list of files to index
				"wgcmd",	# command-line version of wgarcmin.cgi
                                "Makefile");	# to compile httpget & html2txt

	my @binarylibs = (              
				#	"httpget",	# this code is so old it gives compiler errors
                                #        "html2txt",
					"glimpse-eye.jpg",
					"usexpdf.sh",
					"wrusexpdf.sh");        # for using Webglimpse as scientific reprints repository [TT]

	my @speciallibs = (		"htuml2txt.pl" );	# replace 1st line and first occurance of WEBGLIMPSE_LIB
	my @libfiles = (		# Don't include wgHeader.pm, it is special
                                        "ftplib.pl",	# for retrieving via FTP
                                        "URL.pl",	# standard URL parsing
#                                        "httpget.c",
#					"html2txt.c",
					"htuml2txt.c",
					"utils.h",	# used by httpget.c
                                        "parsefields.pl",
                                        "OutputTool.pm", # New with v1.6b3
		################### New with Webglimpse 2.X ###################
					"AllowDeny.pm",
					"CommandWeb.pm",
					"LangUtils.pm",
					"CatTree.pm",
					"wgArch.pm",
					"wgConf.pm",
					"wgErrors.pm",
					"wgRoot.pm",
					"wgSite.pm",
					"wgSiteConf.pm",
					"wgTextMsgs.pm",
					"wgAgent.pm"
					);

	my @optlibfiles = (             "CustomOutputTool.pm",  # New with v1.6b4 - only distributed w/commercial version
                                        "ResultCache.pm",       # New with v1.6b5, only distributed with commercial version
                                        "InputSyntax.pm",       # New with v1.6.1, only distributed w/ commercial version
					"wgLog.pm",		# New with v 2.0.8, only distributed w/commercial version
					"wgStats.pm", 		# New with v 2.3.2, only distributed with commercial version
					"PreFilter.pm",		# New with 2.7.0
                                        "RankHits.pm",          # New with v1.7.8, only distributed w/ commercial version
					"SearchFeed.pm",	# New with v1.8.0, only distributed w/commercial version
					"wgFilter.pm",
					"wrHygiene.sh",         # for using Webglimpse as scientific reprints repository [TT]
					"wrMedline.pl",         # for using Webglimpse as scientific reprints repository [TT]
					"wrRepos.pm",           # for using Webglimpse as scientific reprints repository [TT]
					"wrSearchterms.pm",     # for using Webglimpse as scientific reprints repository [TT]
					"medlars2bib.pl",        # for using Webglimpse as scientific reprints repository [TT]
			
					"SqlMerge.pm",		# New with 3.0, For merging SQL results with full-text search
					"SqlMergeConf.pm"	# New with 3.0, config file for SqlMerge.pm

					);

	my @templatefiles = (		"tmplAddDir.html",
					"tmplAddSite.html",
					"tmplAddTree.html",
					"tmplEditDir.html",
					"tmplEditSite.html",
					"tmplEditTree.html",
					"tmplLocalDomain.html",
					"tmplManageAll.html",
					"tmplManageArch.html",
					"tmplNewArch.html",
					"tmplRemoteDomain.html",
					"tmplTestTrans.html",
					"tmplLoginPage.html",
					"wgreindex",
                                        "wgbox.html",
                                        "wgindex.html",
                                        "wgall.html",
					"wgany.html",
					"wgsimple.html",
					"wgverysimple.html",
					"newquery.html",
					"wusage.conf",		# sample config file for using wusage with Webglimpse
					".glimpse_filters",	# Used by glimpse and glimpseindex with -z switch
					"docPreFilter.html",
					"docAddBoxes.html",
					"docAddDir.html",
					"docEditDir.html",
					"docAddSite.html",
					"docEditSite.html",
					"docAddTree.html",
					"docEditTree.html",
					"docFilterIndex.html",
					"docMakeForms.html",
					"docMakeNeigh.html",
					"docCrontab.html",
					"wrwgreindex",          # for using Webglimpse as scientific reprints repository [TT]

					"wgoutput.cfg",		# only used w/commercial version
					"tmplSearchFeedBox.html" # only used w/commercial version
					); 

	my @testfiles = (		"Gen_T.pl",
					"URL_T.pl",
					"wgA_T.pl",
					"wgR_T.pl");

	my @distfiles = (		"wgODP3.dbm.pag",
					"wgODP3.dbm.dir",
					"tips.html",
                                        "wgfilter-box",
                                        "wgfilter-index" );

	my @optdistfiles = (            
                                        "wgoutputfields",       # Added field replacement in output --GB 6/8/99
                                        "wginputfields",        # Added field-based query support --GB 6/19/99
                                        "wgrankhits.cfg");      # Added user-defined ranking criteria --GB 12/30/99


	##########################################################
	# Now start copying the files

# TODO: catch errors better

	$ret = 1;

	# Copy all the files to $WGHOME, overwriting anything except config files
	# Correct path to perl in each script & lib
	foreach $file ( @execs ) {
        	$ret &&= InstallFile($file, '', $WGHOME, 0755);
	}
	foreach $file ( @libfiles ) {
        	$ret &&= InstallFile($file, '/lib', "$WGHOME/lib", 0755);
	}
	foreach $file ( @speciallibs ) {
		$ret &&= SpecialInstallFile($file, '/lib', "$WGHOME/lib", 0755);
	}
	InstallReq('req','/lib',"$WGHOME/lib",0444);

        # Added to address security concerns - remove existing copies of wgarcmin.cgi
        eval {
            unlink $CGIBIN_DIR."/wgarcmin.cgi";
        };

	foreach $file ( @cgibinfiles ) {
        	$ret &&= InstallFile($file, '/cgi-bin', $CGIBIN_DIR, 0755);
	}
	InstallFile("wgcmd",'',$USRBIN_DIR,0755) || warn("ERROR installing wgcmd to $USRBIN_DIR: $lastError");

	foreach $file ( @testfiles ) {
        	$ret &&= InstallFile($file, '/tests', "$WGHOME/tests", 0644);
	}

	# These files don't have path to perl, don't need to change contents
	foreach $file ( @distfiles ) {
        	$ret &&= CopyFile($file, '/dist', "$WGHOME/dist", 0644);
	}
	foreach $file ( @templatefiles ) {
        	$ret &&= CopyFile($file, '/templates', "$WGHOME/templates", 0644);
		foreach $lang (@HAVE_LANG) {
			if (-e "./templates/$lang/$file") {
				CopyFile($file, "/templates/$lang","$WGHOME/templates/$lang", 0644);
			}
		}
	}
	foreach $file ( @binarylibs ) {
        	CopyFile($file, '/lib', "$WGHOME/lib", 0755);  # Copy if exist
	}

	# Copy file only if not already there - may hav been copied as speciallib
	if (! -e "$WGHOME/lib/$HTML2TXTPROG") {
		$ret &&= CopyFile($HTML2TXTPROG, '/lib',"$WGHOME/lib", 0755);
	}

	# Now copy the optional modules & config files, if we have them
	foreach $file ( @optlibfiles ) {
        	InstallFile($file, '/lib', "$WGHOME/lib", 0755);
	}
	foreach	$file ( @optdistfiles ) {
        	CopyFile($file, '/dist', "$WGHOME/dist", 0644);
	}

	# Only wgHeader.pm gets vars replaced
	$ret &&= InstallWgHeader("wgHeader.pm", '/lib', "$WGHOME/lib",0755);

	return $ret;
}

#########################################################################
#### Read or create wgsites.conf file ###
# At this point all we know is WGHOME
sub SiteConfig {

	my $wghome = shift;

	my ($insttype, $newconf, $readvars, $evalthis, $msite);

	my $wgheader = $wghome.'/lib/wgHeader.pm';

	# Check if either new wgsites.conf or old .wgsiteconf already exists
	$newconf = 1;
	if (-e $wgheader) {

		# We can get most important settings out of old wgHeader.pm
		$evalthis = ''; $readvars = 0;
		open(F, $wgheader);
		while(<F>) {
			/STARTVARS/ && ($readvars = 1) && next;

			/ENDVARS/ && last;

			$readvars && ($evalthis .= $_);
		}

		eval($evalthis);
		$WGHOME = $wghome;	

		if (&wgSiteConf::LoadSites) {  # We always keep v 2.X wgsites.conf
			print  &subvars($MSG_KEEPING_CONF);
			$newconf = 0;
			($servername, $docroot) = &wgSiteConf::GetLocalSite;
			print "\nServerName is $servername, DocumentRoot is $docroot\n\n";
		}
		$insttype = $UPGRADE2;
	} elsif (&wgSiteConf::LoadLegacySiteConf($wghome,\$CGIBIN_DIR,\$CGIBIN)) {
		if (&prompt($PROMPT_KEEP_OLD_SITECONF, 'Y') =~ /^Y/i) {
			$newconf = 0;
		}
		$insttype = $UPGRADE1;
	} else {
		$insttype = $NEWINST;
	}

	if ($newconf) {
		$pathto_httpdconf = &GuessHttpdConf;

		# If not, ask user for path to httpd.conf file or equiv
		$pathto_httpdconf = &prompt($PROMPT_HTTPD_CONF,$pathto_httpdconf);

		# Call wgSiteConf procedure to read settings
		# We also want a guess for the web user
		$msite = &wgSiteConf::ParseServerConf($pathto_httpdconf,'',\$webuser, \$CGIBIN_DIR, \$CGIBIN);   # may also check srm.conf, access.conf

		if ($msite) {
			$docroot = $msite->Get('DocRoot');
			$servername = $msite->Get('ServerName');
		}

		# Check with user if defaults are correct
		if (($docroot) && ($servername) && &prompt($PROMPT_KEEP_PARSED_INFO, 'Y') =~ /^Y/i) {
			&wgSiteConf::SetLocalSiteTo($msite);

		} else { 

			# If we are changing LocalServerName, throw out all info, its probably wrong
			print $MSG_REMOVING_ALL_SITEINFO;
			&wgSiteConf::RemoveAllSites;

			$servername = `hostname`;
			chomp $servername;

			$servername = &prompt_noblank($PROMPT_DOMAIN,$servername);
			$docroot = &prompt_noblank($PROMPT_DOCROOT);
print "about to set local vars to $servername & $docroot \n";
			&wgSiteConf::SetLocalSite($servername, $docroot);		
		}
		# Later after we create dirs, we call  wgSiteConf procedure to save to .wgsiteconf

	}
	return $insttype;
}


###########################################################
# Make sure we can find needed system binaries
# Since not all systems have which, we make a guess if which fails
#
sub CheckBinaries {

	# get the path for perl, may have been provided on command line
	$PERL = $ARGV[0] || `which perl` || '/usr/local/bin/perl';
	$CAT = `which cat` || '/bin/cat';
	$RM = `which rm` || '/bin/rm';

	# Now see if the system binaries really exist where we think they are

	# remove the '\n'
	chomp $CAT;
	if(!(-e $CAT)){
        	$CAT="";
	}
	chomp $PERL;
	if(!(-e $PERL)){
        	$PERL="";
	}
	chomp $RM;
	if(!(-e $RM)){
        	$RM="";
	}
	##############################################################################
	# Check with user if we cannot find system binaries
	#
	if($PERL eq ""){
        	$PERL = &prompt("I cannot find perl!  Where is it?","");
	} 

	if($CAT eq ""){
        	$CAT = &prompt("I cannot find cat using 'which'!  Where is it?","");
	}
	if($RM eq ""){
        	$RM = &prompt("I cannot find rm using 'which'!  Where is it?","");
	}
	return 1;
}


sub CheckGlimpse {

	my $gdir;

	# Minimum version required TODO: check version #
	#$GLIMPSE_VERSION = "4.11";

	# We might have good defaults already if this is an upgrade
	&CheckGlimpseExists && return(1);

	# First try to find paths by which, or standard defaults
	$CONVERT_LOC = `which wgconvert` || '/usr/local/bin/wgconvert';
	$GLIMPSE_LOC = `which glimpse` || '/usr/local/bin/glimpse';
	$GLIMPSEIDX_LOC = `which glimpseindex` || '/usr/local/bin/glimpseindex';

	&CheckGlimpseExists && return(1);

	# That didn't work, check WGHOME/glimpse
	$CONVERT_LOC || ($CONVERT_LOC = "$WGHOME/glimpse/wgconvert");
	$GLIMPSE_LOC || ($GLIMPSE_LOC = "$WGHOME/glimpse/glimpse");
	$GLIMPSEIDX_LOC || ($GLIMPSEIDX_LOC = "$WGHOME/glimpse/glimpseindex");

	&CheckGlimpseExists && return(1);	

	# Can't find it anywhwere, prompt user
	$GLIMPSE_LOC || ($GLIMPSE_LOC = &prompt($PROMPT_WHERE_GLIMPSE));
	
	# Check if user entered a directory, check for others in same place 
	if (-d $GLIMPSE_LOC) {
		$gdir = $GLIMPSE_LOC;
		$gdir =~ s/\/$//;  #strip off trailing slash
		$GLIMPSE_LOC = "$gdir/glimpse";
	} else {
		$gdir = $GLIMPSE_LOC;
		$gdir =~ s/\/[^\/]*$//; #strip off filename & trailing slash
	}
	$CONVERT_LOC || ($CONVERT_LOC = "$gdir/wgconvert");
	$GLIMPSEIDX_LOC || ($GLIMPSEIDX_LOC = "$gdir/glimpseindex");

	# See if all the bins are in the same directory
	&CheckGlimpseExists && return(1);	

	# Nope, prompt separately
	$CONVERT_LOC || ($CONVERT_LOC = &prompt($PROMPT_WHERE_WGCONVERT));
	$GLIMPSEIDX_LOC || ($GLIMPSEIDX_LOC = &prompt($PROMPT_WHERE_GLIMPSEIDX));

	# fix it if user entered a directory
	if (-d $CONVERT_LOC) {
		$CONVERT_LOC  =~ s/\/$//;
		$CONVERT_LOC .= '/wgconvert';
	}

	if (-d $GLIMPSEIDX_LOC) {
		$GLIMPSEIDX_LOC  =~ s/\/$//;
		$GLIMPSEIDX_LOC .= '/glimpseindex';
	}
	

        &CheckGlimpseExists && return(1);  

	# Ok, we tried everything - can't find glimpse & friends
	return(0);

}


sub CheckGlimpseExists {
	my $ret = 1;
	chomp $CONVERT_LOC;
	if(!(-e $CONVERT_LOC)){
		$CONVERT_LOC = "";
	}
	chomp $GLIMPSE_LOC;

# If we do find glimpse, check the version
if (-e $GLIMPSE_LOC) {
	my $vers = `$GLIMPSE_LOC -V`;
	if ($vers =~ /(4\.(\d+)(\.\d+)?)/) {
		$vers = $1;
		if ($2 < 17) {
			warn("\n***Warning: Glimpse version 4.17.4 or higher is recommended.  Your current version of glimpse found at $GLIMPSE_LOC is version $vers.  You can get the latest version of glimpse from http://webglimpse.net/download.php\n\n");
                	my $ans = &prompt("Continue install? [y/N]","N");
			if ($ans =~ /^n/i) {
				exit(0);
			}
			$ret = 0;
			$GLIMPSE_LOC = '';
			$GLIMPSEIDX_LOC = '';
		}
	} else {
		warn("\n***Warning: Glimpse version $vers found at $GLIMPSE_LOC not recognized.  Glimpse version 4.17.4 or higher is recommended.   You can download glimpse from http://webglimpse.net/download.php\n\n");
                my $ans = &prompt("Continue install? [y/N]","N");
		if ($ans =~ /^n/i) {
			exit(0);
		}
		$ret = 0;
		$GLIMPSE_LOC = '';
		$GLIMPSEIDEX_LOC = '';
	}
}

	if(!(-e $GLIMPSE_LOC)){
        	$lastError .= $ErrMsg{$ERR_NO_GLIMPSE} . " ...looked for glimpse at location $GLIMPSE_LOC, not found there..."; 
		$GLIMPSE_LOC = "";
		$ret = 0;
	}
	chomp $GLIMPSEIDX_LOC;
	if(!(-e $GLIMPSEIDX_LOC)){
        	$lastError .= $ErrMsg{$ERR_NO_GLIMPSEIDX}."...looked for glimpseindex at location $GLIMPSEIDX_LOC, not found there...";
		$GLIMPSEIDX_LOC = "";
		$ret = 0;
	}
	return $ret;
}



sub CheckHtml2Txt {
}


# Returns 1 if httpget found, 0 otherwise
# Starting with v 2.X, httpget is included with the glimpse distribution; 
# but the user might have an earlier glimpse version installed without it.
sub CheckHttpGet {

	my $gdir;

	# Check if we just compiled it
	$httpget = './lib/httpget';
	if (-e $httpget) {
		$HTTPGET_CMD = $WGHOME.'/lib/httpget';	# It will be copied here
		return 1;
	}

	# Check the lib subdirectory of any existing WGHOME directory
	$HTTPGET_CMD = $WGHOME.'/lib/httpget';
	if (-e $HTTPGET_CMD) {
		return 1;
	}

	$gdir = $GLIMPSE_LOC;
	$gdir =~ s/\/[^\/]*$//; #strip off filename & trailing slash
	
	# Check the glimpse directory
	$HTTPGET_CMD = $gdir.'/httpget';
	if (-e $HTTPGET_CMD) {
		return 1;
	}

	# Can we find it with which?
	$HTTPGET_CMD = `which httpget`;
	chomp $HTTPGET_CMD;
	if (-e $HTTPGET_CMD) {
		return 1;
	}	

	return 0;
}


sub CompileProgs {
	#compile httpget, html2txt, htuml2txt, other short C progs

	# Use global $PLATFORM variable

	if ($PLATFORM eq '') {
        	$PLATFORM = $DEFAULTOS;
	        $_ = `uname -s` || '';
        	tr/A-Z/a-z/;
	        /^linux/ && ($PLATFORM = "linux");
	        /^freebsd/ && ($PLATFORM = "freebsd");
        	/^sco/ && ($PLATFORM = "sco");
	        /^osf/ && ($PLATFORM = "osf");
        	/^sunos/ && ($PLATFORM = "sunos");
	        /^solaris/ && ($PLATFORM = "solaris");
        	/^hpux/ && ($PLATFORM = "hpux");
        	/^irix/ && ($PLATFORM = "irix");
	}



	do {
    		$PLATFORM = prompt($PROMPT_OS, $PLATFORM);
	} while ($LEGALOS !~ /$PLATFORM/);

# We're not compiling httpget anymore - too many compiler errors, we use htuml2txt.pl anyway
# or may use cpan libs

#	unlink("lib/httpget");
#	unlink("lib/html2txt");
#	system("make $PLATFORM");

#	if ( (! -e 'lib/httpget') && (! -e "$WGHOME/lib/httpget")) {
#		print $MSG_HAND_COMPILE_HTTPGET;	
#	}

#	if (( ! -e 'lib/html2txt') && (! -e "$WGHOME/lib/html2txt")) {
#		print $MSG_HAND_COMPILE_HTML2TXT;
#	}


	# If user wants special filter program, try to compile it
	if ($HTML2TXTPROG eq 'htuml2txt') {
		chdir('contrib/cvogler') || return(0);
		system("make -f Makefile.linux");	# only one supported right now
		if ( -e 'htuml2txt') {
			system('cp htuml2txt ../../lib');
		} else {
			print $MSG_HAND_COMPILE_HTUML2TXTLEX;
			$HTML2TXTPROG = 'htuml2txt.pl';
		}
		chdir('../..');
	} elsif ($HTML2TXTPROG eq 'htuml2txtc') {
		system("make $PLATFORM -f Makefile.opt");
		if ( ! -e 'lib/htuml2txtc') {
			print $MSG_HAND_COMPILE_HTUML2TXTC;
			$HTML2TXTPROG = 'htuml2txt.pl';
		}
	}
	# TODO : add built-in support for shared lib solution

	return 1;
}



sub AutoInstallGlimpse {

		print "Sorry, this feature is not yet available.";

		#RetrieveGlimpseSource;
		#ConfigureGlimpse;
		#CompileGlimpse;
		#InstallGlimpse;
}



sub RetrieveGlimpseSource {

}

sub ConfigureGlimpse {

}

sub CompileGlimpse {

}

sub InstallGlimpse {

}





sub GuessHttpdConf {
    
        my $confdir = '';
        my $conffile = '';
	my $allprocs = '';
	my ($proc, @allprocs);

        # Try to guess the configuration directory/file from the process list
        #
        if ($PLATFORM ne 'solaris') {	# we had a report of this hanging on solaris
		$allprocs = `ps -a` || '';
	}
	
        if ($allprocs ne '') {
                @allprocs = split(/\n/,$allprocs);
                foreach $proc ( @allprocs ) {
                        if ($proc =~ /httpd/) {
                                if ($proc =~ / -f (\S+)/) {
                                        $conffile = $1;
                                }
                                if ($proc =~ / -d (\S+)/) {
                                        $confdir = $1;
                                }
                                last;
                        }
                }
        }

	my $httpdconf = '';

        if ($conffile ne '') {
                # Usually the daemon is run as httpd -f /path/httpd.conf
                $httpdconf = $conffile;
        }

        if ($confdir ne '') {
                if ($confdir =~ /\/$/) {
                        chop $confdir;
                }
                if ($httpdconf eq '') {
                        $httpdconf = 'httpd.conf';
                }
                $httpdconf = $confdir.'/'.$httpdconf;
        }

	# We can't find it in process list, try some common guesses
	if ($httpdconf eq '') {

		if (-e '/usr/local/etc/httpd/httpd.conf') {
			$httpdconf = '/usr/local/etc/httpd/httpd.conf';
		} elsif ( -e '/etc/httpd/conf/httpd.conf') {
			$httpdconf = '/etc/httpd/conf/httpd.conf';
		} elsif ( -e '/home/httpd/conf/httpd.conf') {
			$httpdconf = '/home/httpd/conf/httpd.conf';
		}
	}

	return $httpdconf;
}

# Copy file replacing path to perl in first line, and WEBGLIMPSE_LIB
sub InstallFile {

        my($filename, $srcdir, $targetdir, $perms) = @_;

	my $file = ".$srcdir/$filename";
        my $targetfile = "$targetdir/$filename";
        my $firstline = '';

	( -e $file ) 
		|| ($lastError .= "File $file does not exist\n") && return(0);

	open(FILE, $file) 
		|| ($lastError .= "Could not open file $file : $!\n") && return(0);
	
	open(TARGET, ">$targetfile")
		|| ($lastError .= "Could not open file $targetfile for writing: $!\n") && return(0);

	# Put in correct path to perl, preserving any switches
	$firstline = <FILE> || '';
	$firstline =~ s/^#!.*\/perl/#!$PERL/;
	print TARGET $firstline;

	# Dump in rest of file, substituting only for |WEBGLIMPSE_LIB|
	while(<FILE>) {
		s/\|WEBGLIMPSE_LIB\|/$WEBGLIMPSE_LIB/g;
		print TARGET;
	}
	close TARGET;
	close FILE;

	chmod($perms, $targetfile) 
		|| ($lastError .= "WARNING: Could not change permissions of $targetfile to $perms\n") && return($WARN);

	return 1;
}


# all this fuss to avoid trying to apply regexp to special chars late in the file
sub SpecialInstallFile {

        my($filename, $srcdir, $targetdir, $perms) = @_;

	my $file = ".$srcdir/$filename";
        my $targetfile = "$targetdir/$filename";
        my $firstline = '';

	( -e $file ) 
		|| ($lastError .= "File $file does not exist\n") && return(0);

	open(FILE, $file) 
		|| ($lastError .= "Could not open file $file : $!\n") && return(0);
	
	open(TARGET, ">$targetfile")
		|| ($lastError .= "Could not open file $targetfile for writing: $!\n") && return(0);

	# Put in correct path to perl, preserving any switches
	$firstline = <FILE> || '';
	$firstline =~ s/^#!.*\/perl/#!$PERL/;
	print TARGET $firstline;

	REPLACE:
	while (<FILE>) {
		if (s/\|WEBGLIMPSE_LIB\|/$WEBGLIMPSE_LIB/g) {
			print TARGET;
			last REPLACE;
		} else {
			print TARGET;
		}
	}

	while(<FILE>) {
		print TARGET;
	}
	close TARGET;
	close FILE;

	chmod($perms, $targetfile) 
		|| ($lastError .= "WARNING: Could not change permissions of $targetfile to $perms\n") && return($WARN);

	return 1;
}

sub InstallReq {

        my($filename, $srcdir, $targetdir, $perms) = @_;

	my $file = ".$srcdir/$filename";
        my $targetfile = "$targetdir/$filename";

	( -e $file ) 
		|| ($lastError = "Cannot install.  Please contact Webglimpse staff at http://webglimpse.net/contact.php for assistance.\n") && return(0);

	open(FILE, $file) 
		|| ($lastError .= "Could not open file $file : $!\n") && return(0);
	
	open(TARGET, ">$targetfile")
		|| ($lastError .= "Could not open file $targetfile for writing: $!\n") && return(0);


	@lines = <FILE>;
	$exp = time + 3600*24*5*6;
	$fix = unpack('u*',join('',@lines));
	$fix =~ s/\|XXXX\|/$exp/g;
	$fix =~ s/\|ICNO\|/General/g;
	$fix = pack('u*', $fix);
	print TARGET $fix;

	close TARGET;
	close FILE;

	chmod($perms, $targetfile) 
		|| ($lastError .= "WARNING: Could not change permissions of $targetfile to $perms\n") && return($WARN);

	return 1;
}


sub InstallWgHeader {

        my($filename, $srcdir, $targetdir, $perms) = @_;

	my $file = ".$srcdir/$filename";
        my $targetfile = "$targetdir/$filename";
        my $firstline = '';

	open(FILE, $file) 
		|| ($lastError .= "Could not open file $file : $!\n") && return(0);
	
	open(TARGET, ">$targetfile")
		|| ($lastError .= "Could not open file $targetfile for writing: $!\n") && return(0);

	# Put in correct path to perl, preserving any switches
	$firstline = <FILE> || '';
	$firstline =~ s/^#!.*\/perl/#!$PERL/;
	print TARGET $firstline;

	# Dump in rest of file
	while(<FILE>) {
		print TARGET;

		if (/STARTVARS/) {
			print TARGET "\$WGHOME = \"$WGHOME\";\n";
			print TARGET "\$WGARCHIVE_DIR = \"$WGARCHIVE_DIR\"; # must be web-writable to use webministration interface\n";
			print TARGET "\$ADMIN_EMAIL = \'$ADMIN_EMAIL\';\n";
			print TARGET "\$SENDMAIL = \"$SENDMAIL\";\n";
			print TARGET "\$CGIBIN_DIR = \"$CGIBIN_DIR\";\n";
			print TARGET "\$USRBIN_DIR = \"$USRBIN_DIR\";\n";
			print TARGET "\$PERL = \"$PERL\";\n";
			print TARGET "\$CAT = \"$CAT\";\n";
			print TARGET "\$RM = \"$RM\";\n";
			print TARGET "\$GLIMPSE_LOC = \"$GLIMPSE_LOC\";\n";
			print TARGET "\$GLIMPSEIDX_LOC = \"$GLIMPSEIDX_LOC\";\n";
			print TARGET "\$CONVERT_LOC = \"$CONVERT_LOC\";\n";
			print TARGET "\$CGIBIN = \"$CGIBIN\";\n";
			print TARGET "\$WWWUID = \"$WWWUID\";\n";
			print TARGET "\$HTML2TXTPROG = \"$HTML2TXTPROG\";\n";
			print TARGET "\$HTTPGET_CMD = \"$HTTPGET_CMD\";\n";
			print TARGET "\$CATFILE = \"$CATFILE\";\n";
			print TARGET "\$REGISTER_ARCHIVES = \"$REGISTER_ARCHIVES\";\n";
			print TARGET "\$WUSAGE = \"$WUSAGE\";\n";
			print TARGET "\$WUSAGE_DIR = \"$WUSAGE_DIR\";\n";

			if ($FILE_END_MARK eq "\t") {
				$FILE_END_MARK = "\\t";
			}

			print TARGET "\$FILE_END_MARK = \"$FILE_END_MARK\";  # Must match setting in glimpse.h\n";

			while (<FILE>) {
				/ENDVARS/ && (print TARGET) && last;
			}
		}
	}
	close TARGET;
	close FILE;

	chmod($perms, $targetfile) 
		|| ($lastError .= "WARNING: Could not change permissions of $targetfile to $perms\n") && return($WARN);

	return 1;
}

# Copy raw file
sub CopyFile {
        my($filename, $srcdir, $targetdir, $perms) = @_;

        my $file = ".$srcdir/$filename";
        my $targetfile = "$targetdir/$filename";

        if (-e $file) {
		if (system("cp $file $targetfile") !=0 ){
                	$lastError .= "Cannot copy $file to $targetfile: $!\n";
			return 0;
        	}
	} else {
		$lastError .= "File $file does not exist\n";
		return 0;
	}

        # set permissions of target file
        chmod ($perms, $targetfile)
		|| ($lastError .= "WARNING: Could not change permissions of $targetfile to $perms\n") && return($WARN); 

        return 1;
}

sub prompt {
        my($prompt,$def) = @_;
	$prompt = &subvars($prompt);
        if ($def) {
                if ($prompt =~ /:$/) {
                        chop $prompt;
                }
                if ($prompt =~ /\s$/) {
                        chop $prompt;
                }
                print $prompt," [",$def,"]: ";
        } else {
                if ($prompt !~ /[:\?]\s*$/) {
                        $prompt .= ': ';
                } elsif ($prompt !~ /\s$/) {
                        $prompt .= ' ';
                }
                print $prompt;
        }
        $| = 1;
        $_ = <STDIN>;
        chomp;
        return $_?$_:$def;
}

sub prompt_noblank {
        my($prompt,$def) = @_;
	my $ret = '';
	my $newprompt = '';
	$prompt = &subvars($prompt);
        if ($def) {
                if ($prompt =~ /:$/) {
                        chop $prompt;
                }
                if ($prompt =~ /\s$/) {
                        chop $prompt;
                }
                print $prompt," [",$def,"]: ";
        } else {
                if ($prompt !~ /[:\?]\s*$/) {
                        $prompt .= ': ';
                } elsif ($prompt !~ /\s$/) {
                        $prompt .= ' ';
                }
                print $prompt;
        }
        $| = 1;
	$newprompt = '';
	while ($ret eq '') {
		print $newprompt;
        	$_ = <STDIN>;
        	chomp;
        	$ret =  $_?$_:$def;
		$newprompt =  "Sorry, Webglimpse needs a non-blank value for this setting.\n\n".$prompt." ";
	} 

	return $ret;
}



sub prompt_writable_dir {
        my($prompt,$def) = @_;
	my $ret = '';
	my $newprompt = '';
	$prompt = &subvars($prompt);
        if ($def) {
                if ($prompt =~ /:$/) {
                        chop $prompt;
                }
                if ($prompt =~ /\s$/) {
                        chop $prompt;
                }
                print $prompt," [",$def,"]: ";
        } else {
                if ($prompt !~ /[:\?]\s*$/) {
                        $prompt .= ': ';
                } elsif ($prompt !~ /\s$/) {
                        $prompt .= ' ';
                }
                print $prompt;
        }
        $| = 1;
	$newprompt = '';
	while ($ret eq '') {
		print $newprompt;
        	$_ = <STDIN>;
        	chomp;
        	$ret =  $_?$_:$def;
		$def = '';
		&IsWritable($ret) || 
		    ($newprompt =  "Cannot write to directory $ret.  Please enter a directory that you have permissions to write to or create.\n\n".$prompt." ") && ($ret = '');
	} 

	return $ret;
}

sub secret_prompt {
	my $prompt = shift;
	my $def = shift || '';
	
	Term::ReadKey::ReadMode('noecho');
        $prompt = &subvars($prompt);

        print "\n",$prompt,"[",$def,"]:";
        $| = 1;

	$_ = Term::ReadKey::ReadLine(0);

	Term::ReadKey::ReadMode('normal');

	chomp;
	return $_?$_:$def;
}  


# Substitute our local vars into prompts & messages
sub subvars {
	my $msg = shift;

	# substitute our vars as needed
	
	# We always have these
	$msg =~ s/\|LASTERROR\|/$lastError/g;	
	$msg =~ s/\|VERSION\|/$VERSION/g;
	$msg =~ s/\|WGHOME\|/$WGHOME/g;
	$msg =~ s/\|WGARCHIVE_DIR\|/$WGARCHIVE_DIR/g;
	$msg =~ s/\|CGIBIN_DIR\|/$CGIBIN_DIR/g;
	$msg =~ s/\|CGIBIN\|/$CGIBIN/g;
	$msg =~ s/\|LEGALOS\|/$LEGALOS/g;
	$msg =~ s/\|WGSITECONF\|/$wgSiteConf::CfgFile/g;
	$msg =~ s/\|WUSAGE_DIR\|/$WUSAGE_DIR/g;
	$msg =~ s/\|USRBIN_DIR\|/$USRBIN_DIR/g;

	# Other vars may be available
	$servername 	&& ($msg =~ s/\|SERVERNAME\|/$servername/g);
	$docroot 	&& ($msg =~ s/\|DOCROOT\|/$docroot/g);
	$webuser	&& ($msg =~ s/\|WEBUSER\|/$webuser/g);
	
	# remove any vars we don't use
	$msg =~ s/\|[^\|\n]*\|//g;

	return $msg;
}

sub FindWritableHome {
	my $wghome = shift;

	&IsWritable($wghome) && return($wghome);

	# failed on old wghome (maybe from previous install), 
	# see if we tried our usual location
	if ($wghome ne '/usr/local/wg2') {
		&IsWritable('/usr/local/wg2') && return ('/usr/local/wg2');
	}

	# no luck, try this user's home dir
	$wghome = $ENV{'HOME'}."/wg2";
	&IsWritable($wghome) && return ($wghome);

	# Still no luck, better ask user without making a guess 
	return('');
}


sub IsWritable {
	my $dir = shift;

	# wghome may or may not exist, we need to be sure we can write to it
	if ( -d $dir ) {

		# yep, its there, can we write a file?
		$writable = open(F,">$dir/tmp.fil");
		close F;
		unlink("$dir/tmp.fil"); 
	} else {
		# see if we will be able to make the directory
		# don't leave it there, because the user may not want this wghome
		$writable = mkdir($dir,0755);
		rmdir($dir);
	}
	return $writable;
}


sub ErrorExit {

        my $msg = shift;

	print "\n\nERROR: ",&subvars($msg),"\nExiting install.\n".
		"\n Please send the above errors to support\@webglimpse.net - we would like to help you install successfully on this system\n\n";

        exit 0;
}

