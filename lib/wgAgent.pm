#!/usr/bin/perl

package wgAgent;

# A wgAgent object is responsible for performing URL retrievals,
# form posts, and other spider tasks.
#
# For licensing reasons we cannot include LWP in the package, but
# we can use it if installed.  This is the preferred method of retrieval
# if it is available.

use wgHeader;
use wgSiteConf;

BEGIN {
        if ( (eval "require HTTP::Request::Common")
                && (eval "require LWP::UserAgent")
                && (eval "require LWP::Simple")
                && (eval "require URI::URL") ) {

		$HAVE_LWP = 1;

	} else {
		$HAVE_LWP = 0;
	}
#$HAVE_LWP = 0;
}


my $REVISION = '$Id $';

1;

sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;

	if ( $HAVE_LWP ) {

		$self->{ua} = LWP::UserAgent->new();
		$ua = $self->{ua};
		$ua->cookie_jar({ file => "/tmp/.wg.cookies.txt" });   # TODO ask location at install
		$ua->timeout(5);
		
	} 

	# TODO: change to hash indexed by site base URL
	$self->{HaveCookies} = 0;	# we only support one set of cookies for now - should be one per site

	$self->{LastLoadTime} = 0;
	return $self;
}


# From wgSite object, we know
#	username, password  (by path)
#	needcookie, cookiepath, logincgi, userinput, cookieuser, passinput, cookiepass


#   always pass URL, filename, wgSite obj (may be null)
#  href may include one or more of
#
#	NeedHeaders = 1 or 0
#	MoreRecentThan = datestr
#	Username = username
#	Password = password
#	
#
sub getURL {
	my $self = shift;
	my $url = shift;
	my $file = shift;
	my $usite = shift;
	my $href = shift;	
	my $want_plain_content = shift || 0;	# mfs.cgi wants no headers

      	# get site info if avail
	my ($prot, $host, $port, $path) = &url::parse_url($url);
	my ($user, $pass) = ('','');
	if (! $usite) {
		&wgSiteConf::LoadSites;
		$usite = &wgSiteConf::GetSiteFromURL($url);
	}
      	if ($usite) {
	  	($user, $pass) = $usite->GetLogin($path);
      	} 

	$datestr = $href->{MoreRecentThan} || '';

	if ($HAVE_LWP) {
		my $ua = $self->{ua};

 		my $req = HTTP::Request->new(GET => $url);

		if ($usite && $usite->NeedCookie($path)) {
			# TODO - should be if ! havecookies for this path
			if (! $self->{HaveCookies}) {

				my ($logincgi, $uinput, $uval, $pinput, $pval) = $usite->GetCookieLogin($path);
				my $postreq = POST $logincgi, [ $uinput => $uval, $pinput => $pval ];
				$ua->cookie_jar->add_cookie_header($postreq);
				my $resp = $ua->request($postreq);
				$ua->cookie_jar->extract_cookies($resp);
				$self->{HaveCookies} = 1;
			}
			$ua->cookie_jar->add_cookie_header($req);
		}
					
# more recent than
		if ($datestr) {
			$req->header('If-Modified-Since' => $datestr);
		}


# pass .htpasswd style user & pass if necessary			
		if ($user) {
			$req->authorization_basic($user, $pass)
		}

		my $before = time;
			
		my $resp = $ua->request($req);

		my $content = '';
		my $headers = '';

		# Check for Unmodified & error codes (match httpget behaviour)
		my $code = $resp->code;
		if ($code == 304) {
			return("ERROR: Unmodified");	# This is actually a good response, but need to return this line
		} elsif ($code == 400) {
			return("ERROR: Bad request");
		} elsif ($code == 401) {
			return("ERROR: Unauthorized");
		} elsif ($code == 403) {
			return("ERROR: Forbidden");
		} elsif ($code == 404) {
			return("ERROR: Not Found");
		} elsif ($code == 500) {
			return("ERROR: Internal Server Error");
		} elsif ($code == 501) {
			return("ERROR: Not Implemented");
		} elsif ($code == 502) {
			return("ERROR: Bad Gateway");
		} elsif ($code == 503) {
			return("ERROR: Service Unavailable");
		}

		# Return all headers if requested, otherwise just Last-Modified
		if ($href->{NeedHeaders} ) {
			$headers = $resp->headers_as_string;
		} else {
			my $lm = $resp->header('Last-Modified')|| '';
			if ($lm) {
				$headers = "Last-Modified: $lm\n";
			}
		}

		# Write our Redirect: header if its a Redirect
		# otherwise get the content		
		if ($resp->is_redirect) {
			$headers .= "Redirect: ".$resp->header('Location')."\n";
		} else {
			$content = $resp->content;
		}

		# Set the base URI for this response
		my $base_uri = $resp->base || $url;
		my $base_tag = "<BASE HREF=\"$base_uri\">";

        	my $after = time;

	        $self->{LastLoadTime} = $after - $before;
		
 		if ($content && $file && (open F,">$file")) {

			# keep our place in traversal 
			# this is needed for correctly following links on redirects
			print F "$base_tag\n";

			$content =~ s/(<head[^>]*>)/$1$base_tag/;

			print F $content;
			close F;
			return $headers;
		} else {
			if (! $want_plain_content) {
				$content = $headers."\n\n".$content;
			}
			return $content;
		}
		return 0;
		
	} elsif ($url =~ /^http/) { # use httpget

		my $extra = '';

		if ($datestr) {
			$extra .=  " -d \'$datestr\'";
		}
		if ($href->{NeedHeaders} ) {
			$extra .= ' -h';
		}
          	if ($user && $pass) {
         	   	$extra .= " -n $user -p $pass";
          	}
		my $before = time;
		my $output = '';
		if ($file) {
        		$output = `$HTTPGET_CMD \'$url\' -o \'$file\' $extra`;
		} else {
			$output = `$HTTPGET_CMD \'$url\' $extra`;
		}

        	my $after = time;

	        $self->{LastLoadTime} = $after - $before;

	        return $output;
	} else {
		my $output = '';
		if ($file) {
			$output = `$GETURL_CMD -o "$file" "$url"`;
		} else {
			$output = `$GETURL_CMD "$url"`;
		}
		
		return $output;
	}
}

