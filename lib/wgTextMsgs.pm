package wgTextMsgs;

require Exporter;

use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );
@ISA = qw(Exporter);

##############################################################
# Text messages used by all modules   
# Language translators - change messages here!

# Status & error messages are indexed by error codes & other constants

BEGIN {
	use wgErrors;
#	use wgMsgCodes;
}

my @GENERAL = qw( %ErrMsg $PROMPT_RETURN_TO_CONTINUE);

##########################################################################
# Configuration/wgarcmin messages
#
# Global substitutions will be made for ID, CGIBIN, WGHOME
#
my @CONFIG = qw( $MSG_SRCHFORM );

$MSG_SRCHFORM = '<FORM method=get ACTION="/|CGIBIN|/webglimpse.cgi">'."\n".
		'<INPUT TYPE=HIDDEN NAME="ID" VALUE="|ID|">'."\n".
		'<INPUT NAME="query">'."\n".
		'<INPUT TYPE="SUBMIT" VALUE="Search"></FORM>'."\n";



##########################################################################
# Installation messages
#
# Certain global substitutions will be made before printing messages, for:
#
#   VERSION, LASTERROR, WGHOME
#
# The above can be used in any install message or prompt.  In addition, 
# some messages will have local vars substituted, such as
#
#   DIR, FILE
#

my @INSTALL = qw( $MSG_WELCOME $PROMPT_HOME_DIR $PROMPT_ARCH_DIR $PROMPT_CGI_DIR $PROMPT_CGIBIN $PROMPT_USRBIN $PROMPT_ADMIN_EMAIL $PROMPT_SENDMAIL $PROMPT_WEBUID $PROMPT_WHERE_GLIMPSE $PROMPT_WHERE_WGCONVERT $PROMPT_WHERE_GLIMPSEIDX $PROMPT_OS $PROMPT_GET_GLIMPSE $PROMPT_HTTPD_CONF $PROMPT_KEEP_PARSED_INFO $PROMPT_CHOWN_WWW $PROMPT_CHMOD_777 $PROMPT_KEEP_OLD_SITECONF $MSG_KEEPING_CONF  $MSG_COPYING_FILES $MSG_REMOVING_ALL_SITEINFO $PROMPT_DOMAIN $PROMPT_DOCROOT $PROMPT_HTML2TXT $MSG_FINAL $PROMPT_MAKE_ARCH $PROMPT_RUN_WGCMD $MSG_MADE_ARCH $MSG_HAND_COMPILE_HTUML2TXTLEX $MSG_HAND_COMPILE_HTTPGET $MSG_HAND_COMPILE_HTML2TXT $MSG_HAND_COMPILE_HTUML2TXTC $PROMPT_SECURITY $PROMPT_USERNAME $PROMPT_PASSWD $PROMPT_PASS_INSECURE $MSG_WARN_SECURITY $PROMPT_HAVE_WUSAGE $PROMPT_PATH_WUSAGE $PROMPT_WUSAGE_DIR $PROMPT_CHOWN_WUSAGE $PROMPT_REGISTER_OK $MSG_ABOUT_REGISTER $PROMPT_WILL_OVERWRITE);



$MSG_WELCOME = "\n\nThis is Webglimpse version |VERSION| installation script\n".
	       "Webglimpse is the cgi and archive management interface for glimpse.\n".
	       "For documentation please see http://webglimpse.net/docs/\n\n";

$PROMPT_HOME_DIR = "\nFirst, I'll need a Webglimpse home directory, where most of the \n".
		"libraries and executables will be stored.  This directory should be \n".
		"readable by the user the web server runs as, but for greatest security \n".
		"should NOT be under document root or the cgi-bin area.\n".
		" Please enter Webglimpse home directory ";

$PROMPT_ARCH_DIR = "\nNext, I'll need a directory for storing indexes and other \n".
		"archive-related files.  To use the web administration interface,\n".
		"this directory will need to be made writable by the web user.\n".
		"It should NOT be placed under document root or the cgi-bin area.\n".
		"You may want to put this directory on the partition with the most space.\n".
		" Please enter Webglimpse Archive directory ";

$PROMPT_CGI_DIR = "\nNow, I'll need a directory that IS under your cgi-bin area \n".
		"to place the webglimpse cgi scripts.  This should be\n".
		"a directory where scripts can execute from the web.\n".
		"Please enter full directory path to Webglimpse cgi area: ";

$PROMPT_CGIBIN = "\nWhat is the script alias (relative url) for this directory? ";

$PROMPT_USRBIN = "\nThe command line administration program, wgcmd, can be used\n".
		"to manage archives through a telnet session.  So, you may\n".
		"want it copied into your path.\n".
		"Please enter directory for command-line copy of wgarcmin: ";

$PROMPT_ADMIN_EMAIL = "\nWhere should I send email notification of errors,\n".
		"such as archives failing to build?  You can enter 'N' for\n".
		"no error messages to be sent.\n".
		"\nAdministrative email address: ";

$PROMPT_SENDMAIL = "Path to sendmail: ";

$PROMPT_WEBUID = "\nWhat username does the web server run as? ";

$PROMPT_LANG = "\nWhat language is preferred as the end-user interface?\n".  
	"Hit return for English, or enter one of Hebrew, Spanish, German, French, Italian, Dutch, Finnish, Norwegian or Portuguese: ";

$PROMPT_WHERE_GLIMPSE = "\nCannot find glimpse, the core search engine used by Webglimpse\n".
	"If you have it already on your system you can enter the path below.  \n".
	"Otherwise, download it now from \n".
	"	http://webglimpse.net/trial/glimpse-latest.tar.gz\n".
	"and follow the instructions in the README.install file. \n\n".
"Path to glimpse: ";

$PROMPT_WHERE_WGCONVERT = "\nI cannot find wgconvert! \n  It should have been installed with glimpse. \n   Where is it? ";

$PROMPT_WHERE_GLIMPSEIDX = "\nI cannot find glimpseindex!  Where is it? ";

$PROMPT_OS = "\nNow I am going to compile the filter program you chose, and also\n".
	" httpget, a very short C program needed by Webglimpse.\n".
	" Please choose the OS closest to your system.  You may\n".
	" want to examine the available Makefiles to see which one would work best.\n".
	" What OS are you running (must be one of |LEGALOS|)? ";

$PROMPT_GET_GLIMPSE = "\nI have had some trouble finding the needed glimpse binaries.  Errors are: \n|LASTERROR|\n.  You may want to download the full glimpse source from http:\/\/webglimpse.net\/download.html and compile new copies now.  If you can do this in another window, go ahead and press enter when ready.  Or, you can press 'A' to have me try to download and install automatically now.  Otherwise, press Ctrl-C to quit the install.";

$PROMPT_HTTPD_CONF = "\nPlease enter the path to the web server configuration file that\n".
		"contains your ServerName, DocRoot and VirtualHost settings\n".
		"For apache servers, this file is usually named httpd.conf.\n".
		"Path to configuration file ";

$PROMPT_KEEP_PARSED_INFO = "\nParsed the following settings from the server config file:\n".
	"	ServerName = |SERVERNAME|\n".
	"	DocumentRoot = |DOCROOT|\n".
	" plus others.  All these settings can be edited from the web administration tool\n".
	" after the install has completed.\n".
	" Please enter 'Y' to keep these settings for later editing\n".
	" or 'N' to forget all parsed values and reenter them now\n".
	"\n".
	" Keep parsed values from server config? ";


$PROMPT_CHOWN_WWW = "\nShould I now make |WEBUSER| the owner of |WGARCHIVE_DIR| so that\n".
	"you can administer archives from the web? ";

$PROMPT_CHOWN_WUSAGE = "\nShould I also make |WEBUSER| the owner of |WUSAGE_DIR| so that\n".
	"usage reports can be created from the web interface? ";

$PROMPT_CHMOD_777 = "\nI was not able to change ownership of |WGARCHIVE_DIR|.  Should I\n".
	"set it to be world-writable instead? Not recommended if you are concerned about\n".
	"security, but on some intranets it may be fine.  \n".
	"Set |WGARCHIVE_DIR| to be world-writable? ";


$PROMPT_KEEP_OLD_SITECONF = "\nFound Webglimpse v 1.X configuration file |WGSITECONF|.\n".
	"Keep existing settings? ";

$MSG_KEEPING_CONF = "\n********************************************************************\n".
	"Found existing Webglimpse configuration file |WGSITECONF|. \n".
	"Keeping existing settings so that your archives will continue to work.\n".
	"If you did not want to keep your existing settings, please reinstall to a different\n".
	"home directory, or backup and delete your existing webglimpse files before installing.\n".
	"********************************************************************\n\n";

$PROMPT_WILL_OVERWRITE = "\nWarning: if you have customized template files such as".
	"\n.wgfilter-index, wgreindex, .glimpse_filters, etc you should back them up now.".
	"\nIndividual archive files will not be overwritten, but the ones in".
	"\n      |WGHOME|/templates".
	"\nwill be.  Individual archives can be updated by pressing the".
	"'SAVE CHANGES' button in the web management interface for each archive.\n\n".
	"Hit return to continue";

$MSG_COPYING_FILES = "\nCopying files to |WGHOME| and |CGIBIN_DIR|\n";

$MSG_REMOVING_ALL_SITEINFO = "\nNot using any information parsed from server config files.\n";

$PROMPT_DOMAIN = "\nWhat is the canonical domain for this server?";
$PROMPT_DOCROOT = "\nWhat is the Document Root for that domain?";

$PROMPT_HTML2TXT = "\nNow you need to choose a program to filter tags out of HTML files\n".
	"The default is choice #2, which also provides support for indexing HTML charcter entities.  \n\nImportant Note for non-English languages: you must also have glimpse compiled with ISO_CHAR_SET=1 (the default in 4.14 and above)\n\n".
	"The choices are as follows: \n".
	"	1 - html2txt		The fast, simple, original conversion program\n".
	"	2 - htuml2txt.pl	Perl script handles HTML character codes and preserves TITLE tag, links\n".
	"	                	(required for fast searching of Pre-Filtered files)\n".
	"	3 - htuml2txt		Lex script also handles char codes \n".
	"	4 - htuml2txtc		Experimental C program to do same as above. (you must hand-compile)\n".
#	"	5 - htuml2txt.so	Shared lib built from lex script, requires glimpse 4.13.0 or above\n".
	" Please enter your choice ";

$PROMPT_HAVE_WUSAGE = "\nSearches may be logged to a file in a format usable by \n".
	" web usage analysis software such as wusage by boutell.com.  \n".
	" Do you have wusage installed (and would you like to use it)? ";

$PROMPT_PATH_WUSAGE = "\nWhat is the path to wusage? ";

$PROMPT_WUSAGE_DIR = "\nWusage will generate HTML reports showing the terms users\n".
		" have searched for.  These reports generally are placed somewhere\n".
	 	" in HTML document space, possibly in a password-protected area. \n".
		" What directory should the reports be stored in? ";

$PROMPT_SECURITY = "\nUnless you are already on a secure intranet, you will want to set up \n".
	" some security for the admin interface.  The best way is to use your httpd server's \n".
	" built-in security, usually by creating .htaccess and .htpasswd files.  If you do \n".
	" not know how to do this or do not have access, just hit return to use our built-in. \n".
	" cookie-based authentication. \n\n".
	" Set up cookie-based authentication? ";

# TODO: put this explanation on the web somewhere:
#
#	" We encrypt the password combined with a timestamp so it is not that bad.\n\n".

$PROMPT_USERNAME = "\nEnter administrative username ";

$PROMPT_PASSWD = "\nEnter administrative password ";

$PROMPT_PASS_INSECURE = "\nSorry, cannot find the ReadKey module, password will have to be entered\n".
	" in plain text.  If you don't like this hit Ctrl-C now and get Term::ReadKey from CPAN\n".
	" Enter administrative password ";


$PROMPT_REGISTER_OK = "\nMay I register new archives with the Webglimpse central repository? [yN?]";

$MSG_ABOUT_REGISTER = "\nRegistering your archives will cause them to be listed at http://webglimpse.net,\n".
" and may allow them to become part of a search 'mesh' in the future.\n".
" Basically it will allow more users to find your site and use the \n".
" search feature in various ways.  Currently we register archives by \n".
" sending one email on the creation of each new archive, and in the \n".
" future we may update the last-indexed date by doing one httpget \n".
" retrieval each time the index is rebuilt.\n\n";


$MSG_WARN_SECURITY = "\nOk, make sure you move |CGIBIN_DIR|/wgarcmin.cgi (not copy it) into a secure area or otherwise\n".
	" take care of security by hand.  At this moment your admin interface is NOT secure.\n\n";

$MSG_HAND_COMPILE_HTTPGET = "\nThe URL retrieval program httpget seems not to have compiled.\n".
	"You may want to get a binary version from http://webglimpse.net/download.html#bins \n".
	"and copy by hand into the directory $WGHOME/lib\n\n";


$MSG_HAND_COMPILE_HTML2TXT = "\nThe optional filter program html2txt seems not to have compiled.\n".
	"This program is NOT required. It is a faster but less flexible alternative to htuml2txt.pl and can be specified by the .glimpse_filters file in each archive directory. If desired a binary version is available for some platforms at http://webglimpse.net/download.html#bins \n";

$MSG_HAND_COMPILE_HTUML2TXTLEX = "\nThe filter program htuml2txt seems not to have compiled.\n".
	"To try compiling it by hand, change to the contrib/cvogler directory \n".
	"and read the README.  For now, the filter program has been reset to \n".
	"htuml2txt.pl in the .glimpse_filters file\n\n";

$MSG_HAND_COMPILE_HTUML2TXTC = "\nThe filter program htuml2txtc seems not to have compiled.\n".
	"To try compiling it by hand, run \n".
	"      make -f Makefile.opt [YOUR_OS]\n".
	"from the command line.  You may need to edit settings in Makefile.opt.\n".
	"For now, the filter program has been reset to \n".
	"htuml2txt.pl in the .glimpse_filters file\n\n";


$MSG_SECURITY = "";


$MSG_FINAL = "\n********************************\n".
	" Done with install! You may use \n".
	"	http://|SERVERNAME|/|CGIBIN|/wgarcmin.cgi\n".
	" or \n".
	"	|USRBIN_DIR|/wgcmd\n".
	" to configure archives at any time. (The web version currently has more features)\n\n";


$PROMPT_MAKE_ARCH = 'Run wgcmd to create new archive now?';
$PROMPT_RUN_WGCMD = 'Run wgcmd to manage your archives now?';
$MSG_MADE_ARCH = '';



##########################################################################
# Status messages

##########################################################################
# Common prompts

$PROMPT_RETURN_TO_CONTINUE = 'Press return to continue, Ctrl-C to quit';


##################################################################
#  Command line prompts for wgarcmin.cgi
#

my @WGARCMIN = qw($MSG_INTRO $PROMPT_FIRST_CMD $PROMPT_NEXT_CMD $MSG_HELP $MSG_EXITING $MSG_EDIT_ARCHIVECFG $PROMPT_ARCH_TYPE $MSG_EDIT_WGSITES $MSG_WEB_INTERFACE $MSG_WGINDEXHTML $MSG_GLIMPSE $MSG_EDIT_ARCHIVES %Explain %Prompts);

$MSG_INTRO = "\nThis is wgcmd, the archive manager for Webglimpse.\n".
	    "You can also manage your archives by editing the configuration\n".
	    "files directly.  Type '?' for more information.\n\n";

$PROMPT_NEXT_CMD = 
	" Please enter a command, optionally followed by an archive ID #\n".
	" By default, archive #|ID| will be used\n".
        "  N - Create new archive\n".
	"  L - List available archive IDs\n".
        "  A # - Add documents to archive\n".
	"  B # - Build archive\n".
	"  D # - Delete archive\n".
	"  I # - Info on archive\n".
	"  S 'query' # - Search archive for 'query'\n".
	"  # - Change current working archive to #\n".
	"  ? - Help\n".
	"  X - Exit\n\n".
	"Enter command: ";


$PROMPT_FIRST_CMD =  
	" Please enter a command, and if required an archive ID #\n".
        "  N - Create new archive\n".
	"  L - List available archive IDs\n".
        "  A # - Add documents to archive #\n".
	"  B # - Build archive #\n".
	"  D # - Delete archive #\n".
	"  I # - Info on archive #\n".
	"  S 'query' # - Search archive # for 'query'\n".
	"  # - Change current working archive to #\n".
	"  ? - Help\n".
	"  X - Exit\n\n".
	"Enter command: ";

%Explain = (
	'N' => '',
	'A' => '',
	'H' => ''
);


%Prompts = (
	'ID' => 'Archive ID',
	'Dir' => 'Directory where archive files are stored (NOT directory to be indexed, that will be asked later)',
	'TITLE' => 'Archive Title',
	'TYPE' => 'Add documents by Directory, Site or Tree (D/S/T)? ',
	'CATEGORY' => 'Category code (optional)',
	'STARTURL' => 'Starting URL',
	'HOPS' => 'Number of "hops" to traverse from starting page',
	'MAXLOCAL' => 'Maximum number of local pages to index',
	'MAXREMOTE' => 'Maximum number of remote pages to gather',
	'FOLLOWTOREMOTE' => 'Follow links to remote sites?',
	'FOLLOWSAMESITE' => 'Follow links on remote sites to other pages on the same site?',
	'FOLLOWALL' => 'Follow all links, even from one remote site to another?'
);	

$MSG_HELP = " Help is available on the following topics:\n".
	"   ?E - Editing an archive \n".
	"   ?S - Searching an archive from your web pages\n".
	"   ?G - Glimpse, using in telnet to search\n".
	"   ?H - Host/domain info, editing\n".
	"   ?O - Overview of all archives, editing\n".
	"   ?W - Web interface, how to use\n".
	" Enter one of the above as a command\n".
	" to print the help text for that topic.\n\n";


$MSG_WEB_INTERFACE = 
	"\n How To Use the Web Interface: \n\n".
	" If you initially chose to make archive files owned by the web user\n".
	" or have since made the |WGARCHIVE_DIR| directory web-writable\n".
	" then you can manage your archives through the web interface at\n".
	"		|WGARCMIN|\n\n";

$MSG_EDIT_ARCHIVECFG =
	"\n How To Edit your Archive Settings: \n\n". 
	" To make changes to an archive, please edit the file\n".
	" 		archive.cfg \n".
	" in the archive directory. The current archive directory is \n".
	"		|DIR| \n".
	" You can enter the command 'I' to print this file to the screen\n\n";

$MSG_EDIT_WGSITES = 
	"\n How To Edit Host/Domain Info:\n\n".
	" To make changes to domain configuration info, please edit\n".
	"              wgsites.conf \n".
	" in the directory \n".
	"	       |WGHOME|\/archives\n\n"; 

$MSG_WGINDEXHTML = 
	"\n How To Search your Archive:\n\n".
	" To search this archive, copy one of these forms \n".
	"		|DIR|/wgindex.html \n".
	"		|DIR|/wgsimple.html \n".
	"		|DIR|/wgverysimple.html \n".
	" into your website and edit as desired\n".
	" Or, you may cut and paste the following html into any web page:\n".
	" \n$MSG_SRCHFORM\n\n";

$MSG_GLIMPSE = 
	"\n How To Search an Archive with Glimpse:\n\n".
	" To search an archive from the command line, use\n".
	"	$GLIMPSE_LOC -U -X -H |DIR| 'your_query'\n".
	" You may add other options to glimpse, but the -U and -X\n".
	" are required because of the format used for webglimpse.\n".
	" Type just 'glimpse' by itself to get a list of options.\n\n";


$MSG_EDIT_ARCHIVES = 
	"\n How To Edit the List of All Archives:\n\n".
	" To edit/view list of all archives, see\n".
	"		archives.list \n".
	" in the directory\n".
	"		|WGHOME|\/archives\n".
	" Note, this file is tab-delimited.\n\n";

$MSG_EXITING = "Goodbye!\n";



###########################################################################
# Status messages

$CONFIGURE_DOMAIN_WEB = "Need to configure domain <A HREF='|WGARCMIN|?NEXTPAGE=L&ID=".$self->{ID}."&NEWDOMAIN=|DOMAIN|'>|DOMAIN|</A>";

$CONFIGURE_DOMAIN_CMD = "Need to configure domain |DOMAIN| by editing wgsites.conf. Type ?H for more info.";

$CONFIGURE_DOMAIN = $CONFIGURE_DOMAIN_WEB;


##########################################################################
# Error messages (indexed by error code) 
# Substitutions will be made locally as errors are produced, for
# vars such as FILE, DIR, TYPE, TITLE, DOMAIN.  Not all are valid for all errors.
#
%ErrMsg = (
	$ERR_SYSTEM => 'System error |ERRMSG| has occurred',
	$ERR_NOFILE => 'File |FILE| does not exist',
	$ERR_CANTOPENFILE => 'Cannot open file |FILE|',
	$ERR_CANTWRITETOFILE => 'Cannot write to file |FILE|',
	$ERR_NODIR => 'Directory |DIR| does not exist',
	$ERR_CANTMAKEDIR => 'Cannot create directory |DIR|',
	$ERR_CANTOPENDIR => 'Cannot open/list directory |DIR|',

	$ERR_NOSTARTURL => 'Root does not have a valid starting URL',
	$ERR_NOTYPE => 'Type of root unknown',
	$ERR_INVALIDROOTTYPE => '|TYPE| is not a valid root type',
	$ERR_CANTPARSEURL => 'Cannot parse URL |URL|',
	$ERR_NOSTARTDIR => 'Root does not have a valid starting directcory',
	
	$NEEDSROOTS => 'Archive |TITLE| does not have any valid roots',
	$NEEDSDIR => 'Archive directory |DIR| is not set or does not exist',
	$ERR_NOID => 'Archive ID is not set!',
	$ERR_UNKNOWNCMD => 'Unknown command |CMD|',
	$NEEDSINDEX => 'Archive |TITLE| has not been indexed',
	$NEEDSDOMAIN => 'Domain |DOMAIN| has not been configured',

	$ERR_NOSUCHSITE => 'Site |SITE| unknown',

	$ERR_NO_GLIMPSE => 'Cannot find glimpse!',
	$ERR_NO_GLIMPSEIDX => 'Cannot find glimpseindex!',
	$ERR_NO_WGCONVERT => 'Cannot find wgconvert.  Usually wgconvert can be compiled along with glimpse, but may have been missing from some binary distributions.',


	$ERR_BADPASS => 'Invalid Username or Password.  To use this script from the web, you must supply a valid username and password in the form. See |DOCURL| for more details.'
	
);


@EXPORT = ( @GENERAL );
@EXPORT_OK = ( @INSTALL, @GENERAL, @CONFIG, @WGARCMIN );

%EXPORT_TAGS = (
    'all'      => [ @EXPORT_OK ],
    'install'   => [ @INSTALL ],
    'general'  => [ @GENERAL ],
    'config'  => [ @CONFIG ],
    'wgarcmin' => [ @WGARCMIN ]
);

$xtra = '|XTRA|';

1;
