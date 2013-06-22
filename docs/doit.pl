#!/usr/local/bin/perl
#
BEGIN{
	unshift @INC, "/usr/local/wg2/lib";
}
use wgFilter;

$filename = $ARGV[0];
open F,$filename;
@lines = <F>;
close F;

&wgFilter::SkipSection('<ol start="\d\d?" type="I">','^</ol>',\@lines);

$writeto = "./fixed/$filename";
print "Writing to $writeto\n";

open F,">$writeto";
print F @lines;
close F;

1;


