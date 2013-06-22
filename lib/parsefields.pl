#!/usr/local/bin/perl

# parsefields.pl

# Called by glimpseindex as an on-the-fly filter 

# We need to compile this!
# Use    perl -MO=C,-ofoo.c foo.pl               

# First read list of fields from .wginputfields
# We should already be in the right working directory, hopefully

$debug = 0;

open(F, ".wginputfields") || die("Could not open .wginputfields list\n");

$fields = '';
while(<F>) {
	/^#/ && next;
	chomp;
	$fields .= $_.' ';
}

close F;

$debug && warn("Parsefields read FIELDS: $fields\n");

while(<STDIN>) {

	($name, $val) = split(/[\s\:]+/,$_,2);
	$name =~ s/([^a-zA-Z0-9])/\\$1/g;	
	if (($name ne '') && ($fields =~ /\b$name\b/)) {
		chomp $val;
		$len = length($val);
		print '@FIELD { http://localhost',"\n";
		print "$name\{$len\}:\t$val\n";
		print "}\n";
	} else {
		print $_;
	}
}

1;
