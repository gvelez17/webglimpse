#! usr/local/bin/perl

package AllowDeny;

use wgHeader;
use strict;

1;

sub new {
		my $class = shift;
		my $self = {};
		bless $self, $class;
		$self->{FileName} = shift;
		$self->{IndexPat} = [];
		$self->{IndexAd} = [];
		return $self;
}

sub LoadAllowDeny{
	my $self=shift;
	my($lineno, $AD, $pat, $i);
  
	# read in the info from file
	if (! eval{ open(FILE, $self->{FileName}); } ) {
		warn "Cannot open file $_[0]\n";
		return;
	}
  
	$lineno=0;
	$i = 0;
	while(<FILE>){

		# Skip comments as per Mike Kay --GV
		next if /^\s*#/;

		$lineno++;
		/(\S+)\s*(\S+)/;
		$AD = $1;
		$pat = $2;
		if($AD=~/Allow/i){
			${$self->{IndexPat}}[$i] = $pat;
			${$self->{IndexAd}}[$i] = 1;
		}elsif ($AD=~/Deny/i){
			${$self->{IndexPat}}[$i] = $pat;
			${$self->{IndexAd}}[$i] = 0;
		}else{
			print "Syntax error in $_[0], line $lineno ($_)\n";
		}
		$i ++;
	}
	close FILE;
}

sub OkayToAddFileOrLink{
	my $self = shift;
	my $file_or_link = shift;
	my($to_index, $found, $pattern, $allowdeny, $i);

	# first, check if it's excluded
	$to_index=1;  # by default, it's accepted

	#    print "$file\n";
	foreach $i (0 .. $#{$self->{IndexPat}}) {
		$pattern = ${$self->{IndexPat}}[$i];
		$allowdeny= ${$self->{IndexAd}}[$i];
		# print "$pattern $allowdeny\n";
		if($file_or_link=~/$pattern/){
			$to_index=$allowdeny;
			last;
		}
	}
	return $to_index;
}
