#! /usr/local/bin/perl -w

require "../lib/URL.pl";

print "\n";
($prot, $host, $port, $path) = &url::parse_url('http://iwhome.com/wgproj/test/');
print ' $prot ';
print " $prot \n";
print ' $host';
print " $host \n";
print ' $port';
print " $port \n";
print ' $path';
print " $path \n\n";
