#!/usr/local/bin/perl

package wgSiteConf;

# Reads wgsites.conf file
#
#HASHES:
# DomainAliases =  aliasdomain -> canonicaldomain
# Sites = 	   canonicaldomain -> wgSite object
# Paths = 	   directory -> URL    (all unique path frags)
# HomeDir = 	   username -> homedir

#SUBROUTINES
# Canonicalize 
# GetSite($baseurl)
# GetSiteFromURL($url)
# CheckSite($baseurl)
# AddSite($site)
# RemoveSite($baseurl)
# CheckURL 
# IsLocal 
# LocalFile2URL 
# LocalURL2File 
# LoadSites 
# SaveSites 
# RemoveAllSites
# SetLocalSite($servername, $docroot)
# GetLocalSite - returns $servername, $docroot

my $REVISION = '$Id $';

my $debug = 0;

BEGIN {
	use wgHeader qw( :conf :makenh :general );
	use wgErrors;
}

use wgSite;

$LocalServerName = '';  # Canonical name of local server
my $localSite;		   # Object representing local server
my $UserDir = '';  	# Defaults to public_html, any simple static userdir is supported
my $LoadedSites = 0;

# Public hashes %Sites, %DomainAliases, %Paths

$CfgFile = "$WGARCHIVE_DIR/$SITECONF";	# Location of wgsites.conf
					# Can be reset in LoadSites() routine

%DomainAliases = ();

%Sites = ();

%Paths = ();
@SortedPaths = ();
my %HomeDir = ();

&initialize;

1;


sub initialize {
	my @thearray;

	# Initialize vars, starting with HomeDir hash
# this can be REALLY SLOW on systems with big passwd files...
#	while(@thearray = getpwent()){
#     		$HomeDir{$thearray[0]} = $thearray[7];
#	}
}



sub Canonicalize {
	my $domain = shift;

	if (defined($DomainAliases{$domain})) {
		return $DomainAliases{$domain};
	}

	return $domain;
}


sub GetSite {
	my $sname = shift;

	&LoadSites unless $LoadedSites;

	# We might be passed baseurl or bare domain; we assume nothing in between
	if ($sname =~ /.+\:\/\/.+/) {
		return $Sites{$sname};
	} else {
		return $Sites{"http://$sname:80"};
	}
} 


# Remove from list in memory
sub RemoveSite {
	my $sname = shift;

	# We might be passed baseurl or bare domain; we assume nothing in between
	if ($sname !~ /.+\:\/\/.+/) {
		$sname = "http://$sname:80";
	}
	
	if (! exists($Sites{$sname})) {
		return 0;
	}

	# Really should also remove relevant entries from DomainAliases, but in fact
	# its very unlikely we will do anything using DomainAliases before
	# re-read the sites from from scratch

	delete $Sites{$sname};

	return 1;
}

# Low-overhead routine to just see if we already added this site to our list
sub HaveBaseUrl {
	my $baseurl = shift;
	return exists($Sites{$baseurl});
}


# CheckSite may do sanity checks also in the future
sub CheckSite {
	my $sname = shift;

	my ($cname,$csite);

	&LoadSites unless $LoadedSites;

	($sname eq 'localhost') && return defined($localSite);

        if ($sname !~ /.+\:\/\/.+/) {
		$cname = &Canonicalize($sname);
		$csite = "http://$cname:80";
	} else {
		my ($prot,$host,$port,$path) = &url::parse_url($sname);
		$cname = &Canonicalize($host);
		$csite = "$prot://$cname:$port";
	}

	($cname eq 'localhost') && return defined($localSite);

	$Sites{$csite} || $Sites{$sname} || $DomainAliases{$cname} || return($ERR_NOSUCHSITE);

#TODO: add more sanity checks here on site vars
#TODO: add detailed error/status message

	return 1;	

}


sub AddSite {
	my $msite = shift;

	my ($dir, $alias, $relurl);

	my $baseurl = $msite->BaseUrl;	#always has port, used for lookups
	my $cleanbseurl = $msite->CleanBaseUrl;

	&LoadSites unless $LoadedSites;

	if ($Sites{$baseurl}) {
		$lastError .= "Site ".$msite->BaseUrl."already exists.  Please edit from the list instead of adding a new site.";	
		return($ERR_ALREADYEXISTS);
	}

	foreach $alias (@{$msite->{DomainAliases}}) {

		if (!defined($DomainAliases{$alias})) {
			$DomainAliases{$alias} = $msite->{ServerName};
		}
	}

	$Sites{$baseurl} = $msite;

	if ($msite->IsLocal) {
		$Paths{$msite->{DocRoot}} = $cleanbaseurl;

		foreach $relurl (keys %{$msite->{DirAlias}}) {
			$dir = ${$msite->{DirAlias}}{$relurl};
			$Paths{$dir} = $cleanbaseurl;
			$Paths{$dir} .= $relurl;
		}
	}
	return 1;
}


sub MakeBaseURL {
	my $url = shift;
   	my($protocol,$host,$port,$path) = &url::parse_url($url);

        my $canondomain = &Canonicalize($host);
        $port = 80 unless $port;
        $protocol = 'http' unless $protocol;
        my $baseurl = "$protocol://$canondomain:$port";
	return ($baseurl,$path);
}


#  Accepts URL as input,
#  Returns URL_LOCAL, URL_REMOTE, URL_SCRIPT, or URL_ERROR
#
sub CheckURL {
	my $url = shift;
	my $file = shift || '';

	my ($baseurl, $path) = MakeBaseURL($url);

# TODO: index Sites by domain:port, not just domain

	local $^W = 0;   # Sites{$canondomain} might be undefined

	my $msite = $Sites{$baseurl} || return($URL_REMOTE);	

	if (! $msite->IsLocal ) {
		return $URL_REMOTE;
	}
	if ($msite->IsDynamic($path)) {
		return $URL_SCRIPT;
	}
	# treat directories as dyanmic, we need to retrieve them via http
	if (! $file) {
		$file = LocalURL2File($url);
	}
	if ($msite->IsDynamic($file) || ( -d $file)) {
		return $URL_SCRIPT;
	}

	return $URL_LOCAL;
}

sub GetSiteFromURL {
	my $url = shift;

	my ($baseurl, $path) = MakeBaseURL($url);
	local $^W = 0;   # Sites{$canondomain} might be undefined
	return($Sites{$baseurl});	
}

sub IsLocal {

       my $url = shift || '';

 
	# We used to just check site->IsLocal, but that isn't enough because the
	# path may be dynamic - in which case we need to treat as remote.

	# Now do it this way
	if (&CheckURL($url) == $URL_LOCAL) {
		return 1;
	} else {
		return 0;
	}
}


sub CompleteURL {
	my $url = shift;

	if ($url =~ /^\//) {
		$url = $localSite->CleanBaseUrl.$url;
	}
	return $url;
}


sub LocalFile2URL {
	my $path = shift;
	my ($url, $ldir);

	# This checks all docroots & diraliases for longest match
	foreach $dir (@SortedPaths) {
		if ($path =~ /^$dir(\/|$)(.*)/) {
			$url = $Paths{$dir}.'/'.$2;
			return($url);
		}
	}


        # Was it a userdir?
        if ($path =~ /^\~([^\/]+)$UserDir(.*)/){
		$url = $localSite->CleanBaseUrl."\~$1/$2";
		return $url;
        }
	
	# Check 'em all just in case 
	foreach $user (keys %HomeDir) {
		$dir = $HomeDir{$user};
		if ($path =~ /^$dir\/$UserDir(\/|$)(.*)/) {
			$url = $localSite->CleanBaseUrl."~$user/$2";
			return $url;
		}
	}

	# nope - we can't find any match to it that makes a URL!
	return '';	
} 



sub LocalURL2File {
	my $url = shift;

        my($alias, $homedir, $retstring);
        $retstring="";
        my($protocol,$host,$port,$path) = &url::parse_url($url);

# TODO: fix %20 and other protected chars in $path


	my ($domain, $msite, $dir, $frag);

	# First get domain
	if ($host) {
		$domain = &Canonicalize($host);
	} else {
		$domain = $LocalServerName;
	}


	$port = 80 unless $port;
	my $baseurl = "$protocol://$domain:$port";
	my $baseurl2 = "$protocol://$host:$port";

	# Is it a local one we know of ?	
	$msite = $Sites{$baseurl} || $Sites{$baseurl2} || ($lastError = "$host = $domain is not a known local domain") && return('');
	
	# check if this is a UserDir pattern
        if($path =~ /^\/~([^\/]+)(.*)/){
                # find the home directory's *real* pwd
                # use getpwent structure, already created
                $homedir = $HomeDir{$1};
                chop ($homedir) if ($homedir=~/\/$/);  # remove any trailing /

                $retstring =  "$homedir/$UserDir$2";
		return $msite->Process($retstring);  
	}	

	# Next check all path aliases for longestmatch
	foreach $dir (keys %Paths) {
		$frag = &escape($Paths{$dir});
		if ($url =~ /^$frag(\/|$)(.*)/) {
			$retstring = $dir.'/'.$2;
			return $msite->Process($retstring);
		}	
	} 	

	# Default to DocRoot of canonical domain

	# Double-check domain is local
	if (! $msite->IsLocal) {
		$lastError = "Domain $domain (url was $url) is not local.";
		return '';
	}	
	$retstring = $msite->{DocRoot}.$path;

	return $msite->Process($retstring);
}


sub escape {
	my $str = shift;

	$str =~ s/([^a-zA-Z0-9_])/\\$1/g;

	return $str;
}


# Format of wgsites.conf has changed to allow multiple site configs in one file
#
# #defaults and primary host info still same as before 
# 
# Server  LocalServerName
# DocRoot primary docroot
# UserDir public_html
# IndexFiles index.html index.htm ...
#
# <Site ServerName>
#    DocRoot  	dir	# only if local
#    Port	80
#    DomainAliases   alias.com  alias2.com ...
#    IndexFiles      index.html index.shtml index.cgi ...    # only if local
#    Dynamic	     \/cgi-bin\/ \.cgi ...	# only matters if local
#    DirAlias	url	dir		# only if local
#    DirAlias	url2	dir2
#    Login	url	user:pass
#    Login	url2	user2:pass2  
# </Site>
#
#
sub LoadSites {

	my $archdir = shift || $WGARCHIVE_DIR;

	my ($wsite,$servername);
	
	$LoadedSites && return(1);

	$CfgFile = $archdir.'/'.$SITECONF;

	if (! -e $CfgFile) {
		$CfgFile = $WGARCHIVE_DIR.'/'.$SITECONF;
		if (! -e $CfgFile) {
			$lastError = "Cannot locate a valid siteconf file. Tried $archdir and $CfgFile.";
			return 0;
		}
	}

$debug && (print "Loading sites from $CfgFile\n\n");

	open(F, $CfgFile) || ($lastError = "Can't open $CfgFile for reading") && return(0);

	&RemoveAllSites;

	$LoadedSites = 1;	# VERY IMPORTANT - we consider from now on
				# that we have sites loaded, so we can manipulate
				# lists.  Otherwise may recurse.

	# Default local server
  	$localSite = new wgSite("http://localhost:80");	

	$wsite = $localSite;

	while (<F>) {

$debug && (print "Read line $_\n\n");

         	# skip comments
                /^\#/ && next;

                # trim leading & trailing whitespace
                s/^\s+//;
                s/\s+$//;
                chomp;
                next unless length;     # skip blank lines

		# Is the the start of a site, end of one, or a regular variable?

		if (/<Site\s+([^\s\>]+)>/i) {
			$baseurl = $1;
			$wsite = new wgSite($baseurl);
			next;
		} elsif (/<\/Site\>/i) {
			$wsite->SetDefaults($localSite);
			&AddSite($wsite);
			$wsite = $localSite;
			next;
		} else {
			($var, $rest) = split(/\s+/,$_,2);
			$wsite->Set($var, $rest);
		}
	}
	close F;

	$LocalServerName = $localSite->{ServerName};
	&AddSite($localSite);

	@SortedPaths = sort { length($b) <=> length($a) } (keys %Paths);

	$LoadedSites = 1;

($debug) && (print "Finished loading sites");
	return 1;
} 




sub SaveSites {
        my $archdir = shift || $WGARCHIVE_DIR;

        $CfgFile = $archdir.'/'.$SITECONF;

	my ($servername, $wsite);

	if (! $LoadedSites) {
		 $lastError = "Can't save, never loaded sites";
		 return(0);
	}

	open(F, ">$CfgFile") || ($lastError = "Can't write to $CfgFile") && return(0);

	my $old_fh = select(F);

	$localSite->PrintVars('');
	
	foreach $baseurl (keys %Sites) {
		$wsite = $Sites{$baseurl};
		next if ($wsite == $localSite);
		print "<Site $baseurl>\n";
		$wsite->PrintVars("\t");
		print "</Site>\n\n";
	}

	select($old_fh);

	close F;

($debug) && (print "Finished saving sites\n\n");

	return 1;
}


# Clean out all info
# May be done during an install if user overrides parsed settings from httpd.conf
sub RemoveAllSites {

	%DomainAliases = ();

	%Sites = ();

	%Paths = ();

	%HomeDir = ();

 	$LocalServerName = '';	

	undef $LocalSite;

	$UserDir = '';

	$LoadedSites = 0;

	return 1;
}

# Set just the local site info
# May be called during install to implement just user settings
sub SetLocalSite {

	my $sname = shift;
	my $docroot = shift;
	my $port = shift || 80;
	my $prot = shift || 'http';
#	my $username = shift || '';

	$LocalServerName = $sname;

	$localSite = wgSite->new("$prot://$sname:$port");
	
	$localSite->Set('DocRoot', $docroot);

	&AddSite($localSite);

	$LoadedSites = 1;

	return 1;
}

# Same as SetLocalSite but accepts wgSite object
sub SetLocalSiteTo {
	my $msite = shift;

	$localSite = $msite;
	$LocalServerName = $msite->Get('ServerName');
	&AddSite($localSite);
	$LoadedSites = 1;
	return 1;
}


sub GetLocalSite {

	my ($servername,$docroot);

	if (defined($localSite)) {
		$docroot = $localSite->Get('DocRoot');
		$servername = $LocalServerName || $localSite->Get('ServerName');	
		return ($servername, $docroot);
	} else {
		return ('','');
	}

}


1;


sub LoadLegacySiteConf {
	# TODO: parse old .wgsiteconf and use default settings
	return 0;
}



#############################################################
### GLOBALS
###
### Used only within subroutines called by wgSiteConfig
#############################################################
my ($Port, $ServerName, $DocRoot, $ResourceConfig, $AccessConfig);

# Used by install, may be re-read other times also
# Perl routines to configure Webglimpse for a server/domain name
# Returns pointer to wgSite object
sub ParseServerConf {
	my ($serverconf, $vhost, $webuserref, $cgidirref, $cgiurlref) = @_;

	# If we find webuser, cgidir settings, set those

	# Values of required fields
	$Port = 0;
	$Prot = 'http';
	$ServerName = '';
	$DocRoot = '';
	$ResourceConfig = '';
	$AccessConfig = '';

	my($lines);
	$lines = '';

# Reg exp for parsing out lines from httpd.conf           
# May get more than one of each of these lines
	$prefix = "^DirectoryIndex|^UserDir|^Alias|^ScriptAlias|^ServerAlias|^ServerName|^Port|^DocumentRoot|^ResourceConfig|^ServerRoot|^AccessConfig";

# Get Port, ServerName, DocumentRoot, also other settings
	$lines = &SiteConfSetUp($serverconf,$vhost, $webuserref, $cgidirref, $cgiurlref);

# TODO: return 0 if no ServerName	
	if ($ResourceConfig eq '') {
		$ResourceConfig = $serverconf;
		$ResourceConfig =~ s/httpd\.conf$/srm.conf/;
	}

	if ($AccessConfig eq '') {
		$AccessConfig = $serverconf;
		$AccessConfig =~ s/httpd\.conf$/access.conf/;
	}

	if ($ResourceConfig ne $serverconf) {
		$lines .= &SiteConfSetUp($ResourceConfig,$vhost); 
	}
	
	if ($AccessConfig ne $serverconf) {
		$lines .= &SiteConfSetUp($AccessConfig,$vhost);
	}


	$Port = 80 if ($Port == 0);

	my $baseurl='';
	if ($Port == 443) {
		$baseurl = "https://$ServerName:$Port";
	} else {
		$baseurl = "http://$ServerName:$Port";
	}	

	my $mSite = new wgSite($baseurl);


	$mSite->Set('Port', $Port);
	$mSite->Set('DocRoot',$DocRoot);

	my ($varname, $val, $pat, $dir);

	foreach $line (split(/\n/, $lines)) {

		$line =~ s/\s+$//g;	# trim trailing spaces; leading already gone
		($varname, $val) = split(/\s+/, $line, 2);

		# varname already translated to uppercase by SiteConfSetUp routine

		($varname =~ /DIRECTORYINDEX|USERDIR|ALIAS|SCRIPTALIAS|SERVERALIAS/i) || next;

		if ($varname eq 'USERDIR') {
			$mSite->Set('UserDir', $val);
		} elsif ($varname eq 'DIRECTORYINDEX') {
			$mSite->AddVal('IndexFiles', $val);	# AddVal will split $val
		} elsif ($varname eq 'ALIAS') {
			$mSite->AddVal('DirAlias', $val);	# AddVal will split $val
		} elsif ($varname eq 'SCRIPTALIAS') {
			($pat, $dir) = split(/\s+/, $val);	
			$mSite->AddVal('Dynamic', $pat);	# We only keep the url
			defined($cgidirref) && ($$cgidirref = $dir);			# These are used by installation
			defined($cgiurlref) && ($$cgiurlref = $pat);
		} elsif ($varname eq 'SERVERALIAS') {
			$mSite->AddVal('DomainAliases', $val);	
		}		
	} 


($debug) && (print "Finished parsing server config\n\n");

	return $mSite;
}

#-------------------------------------------------------
# Subroutines
########################################################
#
# SiteConfSetUp parses the server config file for main directives
#     skips any in VirtualHost sections
#     assumes all server directives are on separate lines
#
# Accepts server config file as input
# Outputs string containing all important directive lines
# Sets global variables $DocRoot, $Port, $ServerName, $ResourceConfig, $AccessConfig
#
sub SiteConfSetUp	{
	my($srmConfFile, $vhost, $webuserref) = @_;
	my($key,$override,$val, $ServerRoot);

	open (CONF, $srmConfFile) || return '';

	$override = 0;
	$ServerRoot = '';
	
	while (<CONF>)	{
		# Trim leading white space 
		s/^\s*//g;

		# Skip blank lines and non-applicable VirtualHost directives
		while (/^<VirtualHost\s+([^>\s]+)/i && ($1 !~ /^($vhost)$/i) && ($_ = <CONF>)) {
			s/^\s*//g;
			while (!/^<\/VirtualHost/i && ($_ = <CONF>)) {
				s/^\s*//g;
			}
		}

		# If we are in an applicable VirtualHost directive, set override on
		/^\<VirtualHost\s+$vhost/i && ($override = 1);

		# If we are leaving a VirtualHost directive, turn override off
		/^\<\/VirtualHost/i && ($override = 0);

		# Get relevant lines
		if (/^($prefix)\s+(.+)$/i)	{
			$key = $1;
			$val = $2;
			defined($key) && defined($val) || next;
			$key =~ tr/[a-z]/[A-Z]/;
                        # As of Apache 1.3.3, paths/etc may be quoted.
                        # Since we don't split based on quoted strings,
                        # just strip out all double-quote chars. -PAB 4/2/99
                        $val =~ s/\"//g;

			# Setting a unique variable; only overwrite existing setting if $override is set
			if (($key eq 'DOCUMENTROOT') && (($DocRoot eq '') || ($override == 1))) {
				$DocRoot = $val;
			} elsif (($key eq 'PORT') && (($Port == 0) || ($override == 1))) {
				$Port = $val;
			} elsif (($key eq 'SERVERNAME') && (($ServerName eq '') || ($override == 1))) {
				$ServerName = $val;

			} elsif (($key eq 'RESOURCECONFIG') && (($ResourceConfig eq '') || ($override == 1))) {
				$ResourceConfig = $val;
			} elsif ($key eq 'SERVERROOT') {
				$ServerRoot = $val;
			} elsif (($key eq 'ACCESSCONFIG') && (($AccessConfig eq '') || ($override == 1))) {
				$AccessConfig = $val;
			} elsif ($key eq 'USER') {
				$$webuserref = $val;
			} 

			# Or just adding to a list
			else {
				$output .= "$key $val\n";
			}
		}
	}

	close(CONF);

	if (defined($ServerRoot) && ($ServerRoot ne '')) {
		$ResourceConfig = $ServerRoot.'/'.$ResourceConfig;	
		$AccessConfig = $ServerRoot.'/'.$AccessConfig;	
	}
	return $output;
}

1;
