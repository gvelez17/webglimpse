#!/usr/bin/perl

package wgLog;

BEGIN {
	use wgHeader qw ( :wglog );
	use wgErrors;
}

my $REVISION = '$Id $';

# UseLog outputs searches in common log format

my $debug = 0;

1;




# Return wusage command line for updating reports as of today
sub WusageCmd {
	my $archdir = shift;

	my $cmd = '';

   	my ($sec, $min, $hr, $mday, $mon, $year, $wday, $yday, $isdst) = localtime;
	$mon++;	
	$cmd = $WUSAGE." -b $mon/$mday -c $archdir/wusage.conf";

	return $cmd;
}

sub makeTimeStamp {
   my $timestamp = '';
                                                                                      
   my ($sec, $min, $hr, $mday, $mon, $year, $wday, $yday, $isdst) = localtime;
   @_ = gmtime;
   $zone = ($hr - $_[2])*100;
   if ($zone > 1200) { $zone = $zone - 2400; }
   $year += 1900;
   $timestamp = sprintf("%2.2d/%s/%4.4d:%2.2d:%2.2d:%2.2d %4.4d",$mday, $MONTHS[$mon],$year,$hr,$min,$sec,$zone);
   return $timestamp;
}

# Add a line to the logfile in similar to common log format
sub LogSearch {
   my ($archdir, $query, $loc, $status, $numhits) = @_;
   my $logfile = $archdir.'/'.$LOGFILE;

   # We know $logfile is ok
   $logfile =~ /^(.*)$/;
   $logfile = $1;

   my $line = '';
   my $timestamp = makeTimeStamp();

   $line = "$loc - - \[$timestamp\] \"GET $query \" $status $numhits\n";

   open(F, ">>$logfile") || return(0);

   print F $line;

   close F;
}
