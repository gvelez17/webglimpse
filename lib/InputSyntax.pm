#!/usr/local/bin/perl

package InputSyntax;

use strict;

# InputSyntax translates user-friendly query syntax of the form
#
#      "keyA keyB" AND (keywordC OR keywordD) AND NOT keyE
#
# to the Glimpse syntax, 
#
#      keyA keyB;{keywordC,keywordD};~keyE
#
# by simple substitution.  Embedded regular expressions are left intact.
#
# Also recognizes the special tags
#
#	auto_syntax = ALL, ANY   
#	auto_negate = word list, will be converted to AND NOT (word OR word OR word...)
#
# and generates appropriate boolean query for glimpse
#
# Use of auto_syntax also escapes some regular expression characters, so that users
# performing simple searches can search for expressions containing '.' 
#
# Use of package may be turned on or off in Webglimpse by use of a hidden tag,
# but that is independent of the functionality in this file.
#

1;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->{hasNOT} = 0;

	return $self;
}

# run if $auto_negate or $auto_syntax is not blank
# if $auto_syntax is blank, translateQuery may already have been run
# generally don't run both autoBuildQuery and translateQuery, though wouldn't really hurt
sub autoBuildQuery {
	my $self = shift;
	my ($auto_syntax, $auto_negate, $query) = @_;
	my (@words, $newquery, $notstring);	

	$auto_syntax = uc($auto_syntax);

	# Escape usual boolean & regexp chars 
	$query =~ s/([\.\,\;\*\$\^\[\|\(\)\!\\\#\<\>\-])/\\$1/g;

# TODO: make this optional for accent-insensitive searching.
#  also is necessary to apply accent removal filter prior to indexing
#  see /usr/local/wgnatlaw/lib/ version for original
#	$_ = $query;
#	
#	s/[ÀÁÂÃÄÅ]/A/g;
#	s/Ç/C/g;
#	s/[ÈÉÊË]/E/g;
#	s/[ÌÍÎÏ]/I/g;
#	s/Ñ/N/g;
#	s/[ÒÓÔÕÖ]/O/g;
#	s/[ÙÚÛÜ]/U/g;
#	s/Ý/Y/g;
#
#	s/[àáâãäå]/a/g;
#	s/æ/ae/g;
#	s/ç/c/g;
#	s/[èéêë]/e/g;
#	s/ìíîï/i/g;
#	s/ñ/n/g;
#	s/[ðòóôõö]/o/g;
#	s/[ùúûü]/u/g;
#	s/ý/y/g;
#	$query = $_;

	if ($query =~ /^"(.+)"$/) {
		$newquery = $1;
	} elsif ($auto_syntax eq 'ALL') {
		@words = split(/\s+/,$query);
		$newquery = join(';', @words);
	} elsif ($auto_syntax eq 'ANY') {
		@words = split(/\s+/,$query);
		$newquery = join(',',@words);
	} else {
		$newquery = $query;
	}

	if ($auto_negate ne '') {
		@words = split(/\s+/,$auto_negate);
		$notstring = join(',',@words);
		$newquery = '{'.$newquery.'};~{'.$notstring.'}';
	}	


	return $newquery;
}


sub translateQuery {
	my $self = shift;
	my ($query) = @_;


	# Replace " AND " with ";", eating whitespace
	$query =~ s/\s+and\s+/\;/ig;

	# Replace "OR" with ",", eating whitespace
	$query =~ s/\s+or\s+/\,/ig;

	# Look for 'AND NOT', 'OR NOT', '(NOT...)' type patterns
	# Replace "NOT" with "~", eating trailing whitespace
	# Keep track; we might need to know in case we stop doing glimpse -W by default 
	($query =~ s/([\;\,\(]\s*)not\s+/$1\~/ig) && ($self->{hasNOT} = 1);	

# Don't do this, " are used to escape ' in the query: '"'"'
#	# Remove the quotes, glimpse automatically assumes phrases
#	$query =~ s/\"//g;

	# Replace () with {}, eating inner whitespace
	$query =~ s/\(\s*/\{/g;
	$query =~ s/\s*\)/\}/g;

	return $query;	
}

