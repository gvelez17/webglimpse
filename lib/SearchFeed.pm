#!/usr/local/bin/perl

package SearchFeed;

use RankHits;
use CommandWeb;
use LWP::Simple;

BEGIN {
	use wgHeader qw( :general ); 
	use wgErrors;
}

my $REVISION = '$Id $';

# SearchFeed retrieves results from searchfeed.com 
# based on a list of keywords to match + desired keywords

# From whitepaper, fields are
# Title, URL, URI, Description, Bid
# we don't actually need to know that here

# (move this to rankhits)
# ranks hits based on # matching keywords + # desired matches

# returns top N requests in array of hashes

my $SF_URL = "http://www.searchfeed.com/rd/feed/TextFeed.jsp";

my $DEFAULT_TEMPLATE = "$WGTEMPLATES/tmplSearchFeedBox.html";	

my $DEFAULT_SHOW_RESULTS = 2;

my $GET_RESULTS_TO_EXAMINE = 20;

my $myTempTrackID = 'W5313115333';

my $myTemppID = '15105';

1;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	my ($trackID, $pID, $RemoteAddr, $numResults, @preferredKeywords) = @_;

	$self->{'trackID'} = $trackID || $myTempTrackID || return(0);
	$self->{'pID'} = $pID || $myTemppID || return(0);
	$self->{'RemoteAddr'} = $RemoteAddr || $ENV{'REMOTE_ADDR'};
	$self->{'numResults'} = $numResults || $DEFAULT_SHOW_RESULTS;
	$self->{'preferredKeywords'} = @preferredKeywords || ();
	@{$self->{'Results'}} = ();	# array of hashes

	return $self;
}

# returns array of hashes of Title, URL, URI, Description, Bid
#
sub GetResults {
	my $self = shift;
	my $keyref = shift;	# ref to list of keywords

	my $results = '';
	my $url_prefix = $SF_URL.'?trackID='.$self->{'trackID'}.'&pID='.$self->{'pID'}.'&p='.$self->{'RemoteAddr'}.'&nl='.$GET_RESULTS_TO_EXAMINE.'&page=1&cat=';
	foreach my $keyword (@$keyref) {
		my $content = '';
		if (defined($content = get "$url_prefix$keyword") && ($content !~ /No Results/)) {

			$results .= $content;
		}
	}
	$self->ParseResults(\$results);
	return \{$self->{'Results'}};
}


sub ParseResults {
	my $self = shift;
	my $txtref = shift;

	my $href;
	my @lines = split(/\n/,$$txtref);
	foreach my $line (@lines) {
		my ($field, $len, $data) = split(/\|/,$line);
		if ($field eq 'Title') {
			if (scalar(%$href)) {
				push @{$self->{'Results'}}, $href;
			}
			$href = {};
		}
		$href->{$field} = $data;
	}
	return 1;
}


# later should use RankHits.pm and allow user-defined formulas
# for now just use our own formula
sub RankResults {
	my $self = shift;
	my $exactregexp = shift;

	my @prefkeylist = $self->{'preferredKeywords'};

	my @keylist = split(/\s+/,$exactregexp);

	# TODO: pull formula from wgRankHits.cfg. Note bid is ususally .01 - .20 
	my $RankingFormula = '10*$TITLE_EXACT + 5*$DESC_EXACT + 5*$TITLE + 5*$TITLE_PREF + 4*$DESC + 4*$DESC_PREF + 100*$BID - 20*$FAKEHIT';
	for my $href (@{$self->{'Results'}}) {
		my $TITLE = 0;
		my $DESC = 0;
		my $TITLE_PREF = 0;
		my $DESC_PREF = 0;
		my $BID = 0;
		my $TITLE_EXACT = 0;
		my $DESC_EXACT = 0;
		my $FAKEHIT = 0;

		my $max = 3;	# prevent keyword stuffing
		my $score = 0;

		my $s = $href->{'Title'};
		my $d = $href->{'Description'};


		if ($s =~ /$exactregexp/i) {
			$TITLE_EXACT++;
		}
		if ($s =~ /$exactregexp/i) {
			$DESC_EXACT++;
		}

		foreach my $key (@keylist) {
			if ($s =~ /\b$key\b/i) {
				$TITLE++;
			}
			if ($d  =~ /\b$key\b/i) {
				$DESC++;
			}
		}

		foreach my $key (@prefkeylist) {
			if ($s =~ /\b$key\b/i) {
				$TITLE_PREF++;
			}
		
			if ($d =~ /\b$key\b/i) {
				$DESC_PREF++;
			}
		}

		# we have to check for 'fake' matching phrases
		if ($s =~ /^Information For $key/) {
			$FAKEHIT = 1;
		}

		$BID = $href->{'Bid'};

		$href->{'score'} = eval $RankingFormula;

#print "Score for $s was ".$href->{'score'}."\n<p>";
	}
	my @res = @{$self->{'Results'}} = sort { $b->{'score'} <=> $a->{'score'} } @{$self->{'Results'}};
#foreach $r (@res) { print $r->{'Title'}."  ".$r->{'Description'}.$r->{'Bid'}.$r->{'score'}." \n<p>"; }
	$#res = $self->{'numResults'} - 1;
	@{$self->{'Results'}} = @res;
}

# Returns html fragment for placement in web page
sub FormatResults {
	my $self = shift;
	my $templatefile = shift || $DEFAULT_TEMPLATE;
	my %templatehash = ();
	$templatehash{RESULTS} = $self->{'Results'};
	return &CommandWeb::OutputtoString($templatefile, \%templatehash);
}








