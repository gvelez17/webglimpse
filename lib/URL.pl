#
# URL.pl - package to parse WWW URLs
#
# @(#)URL.pl	1.9 2/8/96
# @(#)URL.pl	1.9 /home/uts/cc/ccdc/zippy/src/perl/url_get/SCCS/s.URL.pl
#
# Hacked by Stephane Bortzmeyer <bortzmeyer@cnam.cnam.fr> to add support
# for empty paths in URLs and to accept dashes in host names. 22 Jan 1994
#
# Jack Lund 9/3/93 <j.lund@cc.utexas.edu>
#
# modified to use cpan URI.pm if present --GV 3/15/07

package url;

BEGIN {
        if (eval "require URI") {

                $HAVE_URI = 1;

        } else {
                $HAVE_URI = 0;
        }
}


# Default port numbers for URL services

$ftp_port = 21;
$http_port = 80;
$gopher_port = 70;
$telnet_port = 23;
$wais_port = 210;
$news_port = 119;

# syntax: &url'parse_url(URL)
# returns array containing following:
# 	protocol	protocol string from url. ex: "gopher", "http".
#	host		host that specified protocol server is running on
#	port		port that server answers on
# the rest of the array is protocol-dependant. See code for details.
#

sub parse_url {
    my ($url) = @_;
    my $userstring = '';

    my ($protocol, $host, $port, $path, $userid, $passwd);

    if ($HAVE_URI) {  # No longer supports embedded FTP login info
		      # are many people actually using this?

	my $u = URI->new($url) || return undef;

	$host = '';
	eval '$host = $u->host';

	if ($host) {
		my $fullpath = $u->path;
		if ($u->query) {
			$fullpath .= '?'.$u->query;
		}
		return ($u->scheme, $u->host, $u->port, $fullpath, '','');
	}
    }

    # fall thru to old heuristic parsing method
    if ($url =~ m#^(\w+):#) {
	$protocol = $1;
	$protocol =~ tr/A-Z/a-z/;
    } else {
	return undef;
    }

    if ($protocol eq "file" || $protocol eq "ftp") {

# URL of type: file://[user[:passwd]@]hostname[:port]/path

	if ($url =~ m#^\s*\w+://([^ \t/]+@)?([^ \t/:]+):?(\d*)/(.*)$#) {
	    $userstring = $1 || '';	 # Correct uninitialized variable warning as per Seth Chaiklin --GV 9/13/99
	    $host = $2;
	    $host =~ tr/A-Z/a-z/;
	    $port = ($3 ne "" ? $3 : $ftp_port);
	    $path = $4; 
	    if ($userstring =~ /(.*):(.*)@/) {
		$userid = $1;
		$passwd = $2;
	    } else {
		($userid = $userstring) =~ s/\@$//; # '\' for perl 5.0
		$passwd = "";
	    }
	    if ($host eq "localhost") {
		$port = undef;
	    }
	    return ($protocol, $host, $port, $path, $userid, $passwd);
	}

# URL of type: file:/path

	if ($url =~ m#^\s*\w+:(.*)$#) {
	    $host = "localhost";  # Current host
	    $port = undef;
	    return ($protocol, $host, $port, $1);
	}
	return undef;
    }

    if ($protocol eq "news") {

# URL of type: news://host[:port]/article

	if ($url =~ m#^\s*\w+://([^ \t:/]):?(\d*)/(.*)$#) {
	    $host = $1;
	    $port = ($2 ne "" ? $2 : $news_port);
	    $selector = $3;
	}

# URL of type: news:article

	elsif ($url =~ m#^\s*\w+:(.*)$#) {
	    $host = $ENV{"NNTPSERVER"};
	    unless ($host) {
		warn "Couldn't get NNTP server name\n";
		return undef;
	    }
	    $port = $news_port;
	    $selector = $1;
	}
	else {
	    return undef;
	}
	return ($protocol, $host, $port, $selector);
    }

# URL of type: http://host[:port]/path[?search-string]

    if (($protocol eq "http")||($protocol eq "https")) {
	if ($url =~ m#^\s*\w+://([\w-\.]+):?(\d*)([^ \t]*)$#) {
	    $server = $1;
	    $server =~ tr/A-Z/a-z/;
	    $port = ($2 ne "" ? $2 : $http_port);
	    $path = ( $3 ? $3 : '/');
	    return ($protocol, $server, $port, $path);
	}
	return undef;
    }

# URL of type: telnet://user@host[:port]

    if ($protocol eq "telnet") {
	if ($url =~ m#^\s*\w+://([^@]+)@([^: \t]+):?(\d*)$#) {
	    $user = $1;
	    $2 =~ tr/A-Z/a-z/;
	    $host = $2;
	    $port = (defined($3) ? $3 : $telnet_port);
	    return($protocol, $host, $port, $user);
	}

# URL of type: telnet://host[:port]

	if ($url =~ m#^\s*\w+://([^: \t]+):?(\d*)$#) {
	    $1 =~ tr/A-Z/a-z/;
	    $host = $1;
	    $port = (defined($2) ? $2 : $telnet_port);
	    return($protocol, $host, $port);
	}
	return undef;
    }

# URL of type: gopher://host[:port]/[gtype]selector-string[?search-string]

    if ($protocol eq "gopher") {
	if ($url =~ m#^\s*\w+://([\w-\.]+):?(\d*)/?(\w?)([^ \t\?]*)\??(.*)$#) {
	    $server = $1;
	    $server =~ tr/A-Z/a-z/;
	    $port = ($2 ne "" ? $2 : $gopher_port);
	    $gtype = ($3 ne "" ? $3 : 1);
	    $selector = $4;
	    $search = $5;
	    return ($protocol, $server, $port, $gtype, $selector, $search);
	}
	return undef;
    }

# URL of type: wais://host[:port]/database?search-string

    if ($protocol eq "wais") {
	if ($url =~ m#^\s\w+://([\w-\.]+):?(\d*)/?([^\?]+)\??(.*)$#) {
	    $1 =~ tr/A-Z/a-z/;
	    $server = $1;
	    $port = (defined($2) ? $2 : $wais_port);
	    $database = $3;
	    $search = $4;
	    return ($protocol, $server, $port, $database, $search);
	}
	return undef;
    }
}
