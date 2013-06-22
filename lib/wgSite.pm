#!/usr/local/bin/perl

package wgSite;

# A wgSite object represents a domain associated with an archive
#
#VARS:
# ServerName = canonical domain name for this server
# DocRoot, Port, Prot - obvious values
#
#LISTS:
# DomainAliases = list of equivalent domain names
# IndexFiles = list of valid index files
# Dynamic = list of regexps that must be retrieved via http, not used as static files
#
#HASHES:
# DirAlias = relurl -> dir	 (same as Alias fakename realname in apache config file)
# Login =  relurl -> user:pass
#
#SUBROUTINES:
# new($baseurl)
# Get($varname) 
# Set($varname, $value) 
# SetDefaults 
# PrintVars 
# BaseUrl 
# CleanBaseUrl
# IsLocal 
# IsDynamic 
# Process 



my $REVISION = '$Id $';

my $DEFAULTID = 0;

BEGIN {
	use wgHeader qw( :wgarch :makenh :general );  # imports $CONFIGFILE, $ArchiveList
	use wgErrors;
	use wgSiteConf;

	require "URL.pl";
}

##################################################################
# Public data members:

my $SiteVars= 'ServerName DocRoot Port Prot UserDir NeedCookie CookiePath LoginCGI UserInput CookieUser PassInput CookiePass';
my $ArrVars= 'DomainAliases IndexFiles Dynamic';
my $HashVars= 'DirAlias Login';

@members = split(/\s+/, $SiteVars.' '.$ArrVars.' '.$HashVars);

##################################################################

my $debug = 0;

($debug) && (print "Content-type: text/html\n\n");

1;


# Called with ServerName or BaseURL
sub new {
        my $class = shift;
	my $baseurl = shift;

        my $self = {};
        bless $self, $class;


	my($prot, $host, $port, $path) = ('','','','');

	if ($baseurl =~ /:\/\//) {
		($prot,$host,$port,$path) = &url::parse_url($baseurl);	
	} else {
		$host = $baseurl;
	}

	# path should be empty

	$self->{ServerName} = $host;

	$self->{Port} = $port || '80';
	$self->{Prot} = $prot || 'http';

	$self->{DocRoot} = '';
	$self->{UserDir} = 'public_html';

	$self->{DomainAliases} = [];
	$self->{IndexFiles} = ['index.html','index.htm','index.shtml','index.php'];
	$self->{Dynamic} = ['\.php.?(\?|$)','\/cgi'];

	$self->{DirAlias} = {};
	$self->{Login} = {};


($debug) && (print "Created new site for $host\n\n");
 
	return $self;
}

sub Get {
	my $self = shift;
	my $varname = shift;

	my ($key, $val, $ret);

	$ret = '';
	if ($SiteVars =~ /(^|\s)$varname(\s|$)/) {
		$ret = $self->{$varname};
	} elsif ($ArrVars =~ /(^|\s)$varname(\s|$)/) { 
		$ref = $self->{$varname};
		$ret = join(' ', @$ref);
	} elsif ($HashVars =~  /(^|\s)$varname(\s|$)/) {
		$ref = $self->{$varname};
		foreach $key (keys %$ref) {
			$val = $$ref{$key};
			$ret .= "$key\t$val\n";			
		}
	} elsif ($varname eq 'IsLocal') {
		if ($self->IsLocal) {
			$ret = 'LOCAL';
		} else {
			$ret = 'REMOTE';
		}
	} elsif ($varname eq 'BaseUrl') {
		$ret = $self->BaseUrl;
	} elsif ($varname eq 'CleanBaseUrl') {
		$ret = $self->CleanBaseUrl;
	} elsif ($varname eq 'NotDefault') {
		my @retlist;
		if ($self->{Port} ne '80') {
			push @retlist,"port $self->{Port}";
		}
		if ($self->{Prot} ne 'http') {
			push @retlist, "using $self->{Prot}";
		}
		$ret = join(',',@retlist);
		if ($ret ne '') { $ret = "($ret)"; }
	}
	return $ret;
}
	

sub Set {
	my $self = shift;
	my $varname = shift;
	my $raw = shift || '';
	my ($key, $val,$ref, $line);

	if ($SiteVars =~ /(^|\s)$varname(\s|$)/) {

		# If changing servername, port or prot, need to change also in site list
		if (defined($self->{$varname}) &&( ($varname eq 'Port')||($varname eq 'Prot')||($varname eq 'ServerName')) && (&wgSiteConf::HaveBaseUrl($self->BaseUrl)) ) {
			&wgSiteConf::RemoveSite($self->BaseUrl);
			$self->{$varname} = $raw;
			&wgSiteConf::AddSite($self);
		} else {
			$self->{$varname} = $raw;
		}
	} elsif ($ArrVars =~ /(^|\s)$varname(\s|$)/) { 
		@{$self->{$varname}} = split(/\s+/,$raw);
	} elsif ($HashVars =~  /(^|\s)$varname(\s|$)/) {
		$ref = $self->{$varname};
	# TODO - empty hash before setting vars #	
		foreach $line (split(/\n/,$raw)) {
			($key, $val) = split(/\s+/,$line,2);	
			$$ref{$key} = $val;
		}
	} else {
		$lastError = "No such member variable $varname";
		return 0;
	}

	return 1;
}


sub AddVal {		# Just like Set except for Array type vars, adds to list
        my $self = shift;
        my $varname = shift;
        my $raw = shift || '';
        my ($key, $val,$ref, $line);

        if ($SiteVars =~ /(^|\s)$varname(\s|$)/) {
                $self->{$varname} = $raw;
        } elsif ($ArrVars =~ /(^|\s)$varname(\s|$)/) {
                push(@{$self->{$varname}},split(/\s+/,$raw));
        } elsif ($HashVars =~  /(^|\s)$varname(\s|$)/) {
                $ref = $self->{$varname};

                foreach $line (split(/\n/,$raw)) {
                        ($key, $val) = split(/\s+/,$line,2);
                        $$ref{$key} = $val;
                }
        } else {
                $lastError = "No such member variable $varname";
                return 0;
        }
        return 1;
}


# We use default values for Port, Prot, IndexFiles, and Dynamic
sub SetDefaults {
	my $self = shift;
	my $def = shift;

	
	if ( ! $self->{Port} ) {
		$self->{Port} = $def->{Port} || '80';
	}

	if (! $self->{Prot} ) {
		$self->{Prot} = $def->{Prot} || 'http';
	}

	my $aref = $self->{IndexFiles};
	if ($#$aref < 0) {
		$self->{IndexFiles} = $def->{IndexFiles};    # Its ok just to have a pointer
	}

	$aref = $self->{Dynamic};
	if ($#$aref < 0) {
		$self->{Dynamic} = $def->{Dynamic};
	}

}	




sub PrintVars {

	my $self = shift;
	my $indent = shift;

	my ($varname, $line, $key, $val,$aref);

	foreach $varname (split(/\s+/,$SiteVars)) {
		print "$indent$varname\t",$self->{$varname},"\n";
	}

	foreach $varname (split (/\s+/,$ArrVars)) {
		$aref = $self->{$varname};
		if (defined($aref)) {
			$line = join(" ",@$aref);
			print "$indent$varname\t$line\n";
		}	
	}

	foreach $varname (split (/\s+/,$HashVars)) {
		$aref = $self->{$varname};
		foreach $key (keys %$aref) {
			$val = $$aref{$key};
			print "$indent$varname\t$key\t$val\n";
		}	
	}

	return 1;
}
 

sub BaseUrl {
	my $self=shift;

	my $baseurl = $self->{Prot}.'://'.$self->{ServerName}.':'.$self->{Port};
#	if (($self->{Port} ne '80') && ($self->{Port} ne '')) {
#		$baseurl .= ':'.$self->{Port};
#	}
	return $baseurl;
}

# We always have the port now for reference, so need this to avoid
# having :80 on printable urls
sub CleanBaseUrl {
	my $self=shift;

	my $baseurl = $self->{Prot}.'://'.$self->{ServerName};
	if (($self->{Port} ne '80') && ($self->{Port} ne '')) {
		$baseurl .= ':'.$self->{Port};
	}
	return $baseurl;
}

	
sub CompleteURL {
	my $self = shift;
        my $url = shift;

        if ($url =~ /^\//) {
                $url = $self->CleanBaseUrl.$url;
        }
        return $url;
}


sub NeedCookie {
	my $self = shift;
	my $path = shift;
	
	if ($self->{NeedCookie}) {
		my $cpath = $self->{CookiePath};
		if ($path =~ /^\/?$cpath/) {
			return 1;
		} else {
			return 0;
		}
	} else {
		return 0;
	}
}


sub GetCookieLogin {
	my $self = shift;
	my $path = shift;

# NeedCookie should already have been called - or we could call it here.
	
	return ($self->{LoginCGI},$self->{UserInput}, $self->{CookieUser}, $self->{PassInput}, $self->{CookiePass});
}


sub GetLogin {
	my $self = shift;
	my $path = shift;

	my $lpath;
	foreach $lpath (keys %{$self->{'Login'}}) {
		if ($path =~ /^\/?$lpath/) {
			my ($user, $pass) = split(':',$self->{'Login'}->{$lpath});
			return ($user, $pass);
		}
	}
	return ('','');
}



sub IsLocal {
	my $self = shift;
	if ($self->{DocRoot}) {
		return 1;
	} else {
		return 0;
	}
}



sub IsDynamic {
	my $self = shift;
	my $relurl = shift;

	my $dynurl;

	foreach $dynurl (@{$self->{Dynamic}}) {
		if ($relurl =~ /$dynurl/) {
			return 1;
		}
	}
	return 0;
}





sub Process {
	my $self=shift;
        my $retstring = shift;

        # if it's a directory, try adding an index file
        if(-d $retstring){

                # append a / if needed
                $retstring .= '/' if($retstring!~/\/$/);

                my $indexfile;

DIRINDEX:       foreach $indexfile (@{$self->{IndexFiles}}) {

                        if ( -e "$retstring$indexfile") {
                                $retstring .= $indexfile;
                                last DIRINDEX;
                        }
                }
        }

# Get rid of // sequences and any trailing /
        $retstring =~ s/\/\//\//g;
        $retstring =~ s/\/$//g;

# Get rid of ./ sequences ; they should have been removed from the URL in makenh,
# but check for them here too just in case some weird translation is going on.
        $retstring =~ s/(^|\/)(\.(\/|$))+/$1/g;

        return $retstring;
}

