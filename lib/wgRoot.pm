#!/usr/local/bin/perl

package wgRoot;

# A wgRoot object represents a starting URL or Directory to traverse
# plus the rules for including files/urls in the archive
# An archive is essentially defined by several wgRoot objects
#
#  new, then set params.  Generally only wgArch or wgConf sets the params.
#  Other programs such as makenh are passed already existing wgRoot objects
#
#
# Functions:
#
#	Validate - check that we have needed settings for this type of root obj
#
#	CheckRules - given a pair of canonicalized URL's, should be traverse from one to the other?
#
#	CheckPrefix - called internally to check if a url matches a given prefix	
#
##	Members - returns an anonymous array ref to all public data members,
##		  in the same order needed for "new"

my $REVISION = '$Id $';

BEGIN {
	use wgHeader qw( :general :wgroot );
	use wgErrors;
}

require "URL.pl";
use wgSiteConf;

##################################################################
# Public class data members: (read-only)

my $RootVars = 'StartURL StartDir Type Hops nhHops FollowToRemote FollowSameSite FollowAll MaxLocal MaxRemote Local_Flag Keep_Flag MakeNH_Flag CheckHtaccess LimitPrefix UseRegExp IndexTrunk';

my $FlagVars = 'Local_Flag Keep_Flag MakeNH_Flag';  # are set if present w/o explicity val

# Plus virtual data member: Domain

# Names of data members

@members = split(/\s+/, $RootVars);

@flags = split(/\s+/,$FlagVars);

my $ErrorCode = 0;		# may be used to act on specific errors rather than just print an error message

1;



sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;

	my ($varname, $val, $j);

	$self->init;

	$j = 0;
	foreach $val (@_) {
		$varname = $members[$j];
		$self->{$varname} = $val;
		$j++;
	}

	return $self;
}


sub init {
	my $self = shift;

	$self->{StartURL} = '';
	$self->{StartDir} = '';
	$self->{Type} = '';
	$self->{Hops} = 0;
	$self->{nhHops} = 0;
	$self->{FollowToRemote} = 0;
	$self->{FollowSameSite} = 0;
	$self->{FollowAll} = 0;
	$self->{MaxLocal} = 0;
	$self->{MaxRemote} = 0;
	$self->{Local_Flag} = 0;
	$self->{Keep_Flag} = 1;
	$self->{MakeNH_Flag} = 0;
	$self->{CheckHtaccess} = 1;
	$self->{LimitPrefix} = '';
	$self->{UseRegExp} = 0;
	$self->{IndexTrunk} = 1;
}


# Routine to zero out checkbox-type options prior to checking which ones are set
sub UncheckOptions {
	my $self = shift;

	$self->{FollowToRemote} = 0;
        $self->{FollowSameSite} = 0;
        $self->{FollowAll} = 0;
	$self->{IndexTrunk} = 0;
#        $self->{Local_Flag} = 0;
#        $self->{Keep_Flag} = 1;
        $self->{MakeNH_Flag} = 0;
}


sub Get {
	my $self = shift;
	my $varname = shift;
	my( $prot, $host, $port, $path) = ('','',$DEFAULT_PORT,'');


	my $ret = '';

	if ($RootVars =~ /(^|\s)$varname(\s|$)/) {
		# Special treatment for certain vars
		if (($varname eq 'Hops') && ($self->{Type} eq 'SITE') && ($self->{Hops} == 0)) {
			$ret = 16;
		} 
		# Otherwise just return the setting
		else {
			$ret = $self->{$varname};
		}
	} elsif ($varname eq 'Domain') {
		if (defined($self->{StartURL})) {
	        	($prot, $host, $port, $path) = &url::parse_url($self->{StartURL});
			$ret = $host;
		} elsif ($self->{Type} eq 'DIR') {
			$ret = 'localhost';
			#TODO: should we assume localhost or insist user set it explicitly?
		}
	}


	return $ret;
}


# Go ahead and set the member vars by hand, then check it all makes sense
# StartURL/Dir and Type are required, or Validate fails
# SITE needs LimitPrefix set
# TREE needs Hops and Follow* flags
# DIR needs StartDir set
# All need settings/defaults for $MaxLocal, $MaxRemote
sub Validate {
	my $self = shift;
	my( $prot, $host, $port, $path) = ('','',$DEFAULT_PORT,'');

	$lastError = "Attempting to validate root";

	# Verify that we have the correct variables for this type

	defined($self->{Type}) || ($ErrorCode = $ERR_NOTYPE) && ($lastError = "No type defined") && return(0);

	if (($self->{Type} eq 'SITE') || ($self->{Type} eq 'TREE')) {
		defined($self->{StartURL}) || ($ErrorCode = $ERR_NOSTARTURL) && ($lastError = "No starting URL defined") && return(0);

		# Require LimitPrefix to define SITE type
		if (($self->{Type} eq 'SITE') && ($self->{LimitPrefix} eq '')) {
			$self->{UseRegExp} = 0;	 # if we're generating it ourselves, turn regexp matching off
			($prot, $host, $port, $path) = &url::parse_url($self->{StartURL});	

			if (! $prot) { 
				$ErrorCode = $ERR_CANTPARSEURL;
				$lastError = "parse_url did not return valid protocol";
				return(0); 
			}

			if ($port == $DEFAULT_PORT) {
				$self->{LimitPrefix} = $prot.'://'.$host;
			} else {
				$self->{LimitPrefix} = $prot.'://'.$host.':'.$port;
			}
			my $basepath = $path;
			# Only chop off end if matches HTML_RE --GB 7/27/98
   			if ($basepath =~ /$HTMLFILE_RE/) {
        			$basepath =~ s/(\/)[^\/]+$/\//;
   				if ($basepath !~ /\/$/) {
        				$basepath .= "/"; # add the last / for the directory if not there already
   				}
				if ($basepath !~ /^\//) {
					$basepath = '/'.$basepath;
				}
				$self->{LimitPrefix} .= $basepath;
			}
		}


		# We don't really care if pages are local or remote, since they are all
		# on the same Site.  Make sure both max values are filled in.
		if ($self->{MaxLocal} && !$self->{MaxRemote}) {
			$self->{MaxRemote} = $self->{MaxLocal};
		} elsif ($self->{MaxRemote} && !$self->{MaxLocal}) {
			$self->{MaxLocal} = $self->{MaxRemote};
		}

	} elsif ($self->{Type} eq 'DIR') {
		defined($self->{StartDir}) || ($ErrorCode = $ERR_NOSTARTDIR) && ($lastError = "Start directory not defined") && return(0);
	
		if (! $self->{StartURL}) {
			&wgSiteConf::LoadSites() || ($lastError = "Cannot load sites") && return(0);
			my $guess = &wgSiteConf::LocalFile2URL($self->{StartDir});
			if (! $guess) {
				$ErrorCode = $ERR_NOSTARTURL;
				$lastError = "No starting URL defined, not able to guess";
				return 0;
			}
			$self->{StartURL} = $guess;
		}

	} else {
		$ErrorCode = $ERR_INVALIDROOTTYPE;
		$lastError = $self->{Type}." is not a valid type.  Must be DIR, TREE or SITE";
		return(0); 
	}

	return 1;
}


# Returns yes/no
# $from and $to are already in canonical form, and we get flags to say if they are local, remote, or whatever
# Called as CheckRules($from, $to, $fromstat, $tostat);  $from may be a url or the term "LOCAL"
sub CheckRules {
	my $self = shift;
	my ($from, $to, $fromstat, $tostat) = @_;

	if ($self->{Type} eq 'SITE') {
		return($self->CheckPrefix($to));
	} elsif ($self->{Type} eq 'TREE') {

		my ($from_prot, $from_host, $from_port) = &url::parse_url($from);
		my ($to_prot, $to_host, $to_port) = &url::parse_url($to);

		my $retval = 0;

		if ($self->{FollowAll}) {
	               if ($self->{LimitPrefix} ne '') {
                        	return($self->CheckPrefix($to));
                	} else {
				return 1;
			}
		} 

		my $retval = ($tostat != $URL_REMOTE);  
		if ($retval) {
                      if ($self->{LimitPrefix} ne '') {
                                return($self->CheckPrefix($to));
                        } else {
                                return 1;
                        }
		}
	
		if ($self->{FollowSameSite}) {
			$retval ||= ($from_host eq $to_host);
		} 

		if ($self->{FollowToRemote}) {
			$retval ||= ($fromstat != $URL_REMOTE);
		} 
                if ($retval && ($self->{LimitPrefix} ne '')) {
                      return($self->CheckPrefix($to));
                } else {
                      return $retval;
                }

	} elsif ($self->{Type} eq 'DIR') {
		if ($self->{LimitPrefix} ne '') {
			return($self->CheckPrefix($to));
		}		
		return ($tostat != $URL_REMOTE);
	}

	return 1;
}


# Called only for SITE and TREE type roots
# Should we bother to check the links on the url passed?
sub CheckTraverse {
	my $self = shift;
	my ($url, $urlstat) = @_;

	if ($self->{Type} eq 'SITE') {
		return 1;
	} elsif ($self->{Type} eq 'TREE') {
		if ($urlstat == $URL_REMOTE) {
			return ($self->{FollowSameSite} || $self->{FollowAll});
		} else {
			return 1;
		}
	} 
}



sub CheckPrefix {
	my $self = shift;
	my $url = shift;


$self->Validate || print("Error in CheckPrefix, we don't seem to be valid anymore\n");

	my ($len, $str, $ret);

	if ($self->{UseRegExp}) {
		return(1) if ($url =~ /$self->{LimitPrefix}/);
	} else {
		# Use substr instead of // since we are not interested in regexps
		# For now we calculate length on the fly
		$len = length($self->{LimitPrefix});
		$str = substr($url, 0, $len);
		return(1) if ($str eq $self->{LimitPrefix});
#		foreach (@EquivPrefix) {
#			return(1) if ($url =~ /^$_/);
#		}
	}

	return 0;
}


# Create option list for insertion in wgall.html template
# Each option is a filter to search only a subdirectory or other portion of
# the archive
sub MakeDirOptions {
	my $self = shift;
	my $mAdIndex = shift;

	# Should only be called on type DIR archives
	($self->{Type} eq 'DIR') || return('');

	my $optstring = '';
	my ($dirlist, $startdir, $eachdir);

	# Mainly used for directories, to filter by subdirectory
	$startdir = $self->{StartDir} || return('');
	$dirlist = `find $startdir -type d -maxdepth 2 -print`;

	foreach $eachdir (split(/\n/,$dirlist)) {
		if ($mAdIndex->OkayToAddFileOrLink($eachdir)) {
			$optstring .=  '<OPTION VALUE="^'.$eachdir.'">'.$eachdir."\n";
		}
	} 

	return $optstring;

}



##############################################################
# End object/instance routines, start generic class routines #
##############################################################

# Check if string is a member variable (in @members array) ignoring case
# Return correctly cased name if it is
sub isMember {
	my $str = shift;

	my $mvar;
	$str = uc($str);

	foreach	$mvar (@members) {
		if ($str eq uc($mvar)) {
			return $mvar;
		}
	}
	return '';
}

sub isFlag {
	my $str = shift;

	my $mvar;
	$str = uc($str);

	foreach	$mvar (@flags) {
		if ($str eq uc($mvar)) {
			return $mvar;
		}
	}
	return '';
}

# Escape control chars we are likely to encounter in URLs
sub EscapeAll {

	my $str = shift;

	$str =~ s/\//\\\//g;
	$str =~ s/\~/\\\~/g;
	$str =~ s/\./\\\./g;

	return $str;
}


#sub Members {
#	my $self = shift;
#
#	return \($StartURL,
#	$StartDir,
#	$Type,
#	$Hops,
#	$Local_Flag,
#	$Keep_Flag,
#	$MakeNH_Flag,
#	$CheckHtaccess_Flag,
#	$FollowToRemote,	
#	$FollowSameSite,	
#	$FollowAll,	
#	$MaxLocal,
#	$IndexFreq,
#	$LimitPrefix,
#	$UseRegExp);
#}
