#!/usr/local/bin/perl

package ResultCache;


# Search results are stored in /tmp in file pairs
# 	.wgcache.#lines.uniquecmd
# 	.wgptr.#lines.uniquecmd

# .wgptr contains a sequential list of pointers to 
# each new file-hit in .wgcache

# .wgcache contains all the hits returned from glimpse,
# may have many hits per file

# public functions:
# SaveResult
# LoadResult

# private functions:
# ExpireAll
# err_badcache, err_nowritecache

#
# Cache file name is now .wgcache + archive # + keywords + optionstring
#


# Tempdir for use by v 1.X; 2.X may use archive directories
$TMPDIR = "/tmp";

$EXPIRE = 3600; 	# Keep cache files 1 hr; should put this in wgHeader.pm
				# here for backwards compatibility with v 1.X

1;



# Important - everytime we run check for old cache files and expire them!
sub ExpireAll {

	my $fname;
	my $atime;

	my $thetime = time;

	# List all files in $TMPDIR of form .wgcache* or .wgptr*
	opendir TDIR, $TMPDIR || warn("ERROR: Can't open $TMPDIR to expire files\n") && return(0);
	while ($fname = readdir TDIR) {


		($fname =~ /(\.wgcache)|(\.wgptr)/) || next;

		$fname = "$TMPDIR/$fname";

		@_ = stat $fname;
		$atime = $_[8];

		if (($thetime - $atime) > $EXPIRE) {

			# Convince perl -T this is ok
			$fname =~ /^(.*)$/;
			$fname = $1;
			unlink "$fname";
		}
	}

	closedir TDIR;

	return 1;
}

# Use our special filename info to retrieve # file hits
sub HowManyFiles {
	my $fname = shift;

	open(F, "$TMPDIR/$fname") || return(0);
	my $firstline = <F>;
	close F;
	if ($firstline =~ /^([0-9]+):/) {
		return $1;
	} else {
		my $num = `wc $fname` - 1;
		return $num;
	}
}


# Called by webglimpse to guess cache file name on new searches
sub GuessCacheFile {
	my $cmd = shift;

	&FixCmd(\$cmd);

	# Its ok, we made $cmd ourselves & checked it carefully
	$cmd =~ /^(.*)$/;
        $cmd = $1;
	my $guess = ".wgcache.".$cmd;

# Don't second-guess ourseles - eitehr it is there, or not...	
#	my $guess = `ls "$TMPDIR/.wgcache.*.$cmd" 2>/dev/null`;
#	split(/\n/, $guess);
#	$guess = $_[0];
#
#	# Strip off TMPDIR
#	$guess =~ s/$TMPDIR\///g;

	return ($guess);
}	



# for internal use only
sub FixCmd {
	my $cmdref = shift;

	# Clean out any shell escape chars, pipes, other cleanup. 
	# But, be careful to distinguish between chars so as not to mix up caches
	
	$$cmdref =~ s/([\/\0\`\'\"\~\|\>\<\!\,\;\&\.\\\s\#\*])/unpack("c2",$1)/eg;
	$$cmdref =~ s/^\-+//g;

        # Tell perl that cmd is safe now.
        $$cmdref =~ /^(.*)$/;
        $$cmdref = $1;
}



# Save a new result set to the cache, regardless of whether it already exists. 
# Now an array rather than raw line
sub SaveResult {
	my($maxfiles, $glinesref, $cmd,$tot_files,$tot_lines) = @_;

	my($prevfile, $file, $j,$i,$aref);
	
	# Expire any old cachefiles!
	&ExpireAll;

	&FixCmd(\$cmd);

	my $numlines = @$glinesref;

	my $ptrfile = ".wgptr.".$cmd;
	my $cachefile = ".wgcache.".$cmd;
	open(CFIL, ">$TMPDIR/$cachefile" ) || &err_nowritecache && return('');

	# Write total file & line counts to first line of the cache file
	print CFIL "$tot_files:$tot_lines\n";
	
	$prevfile = '';
	$j = 0;

	open (IFIL, ">$TMPDIR/$ptrfile") || &err_nowritecache && return ('');
	my $offset = tell(CFIL);
	my $line = '';

	foreach $aref (@$glinesref) {
		
		$file = $$aref[0];
		if ($file ne $prevfile) {
			$j++;
			$prevfile = $file;
			print IFIL pack("N", $offset);	  # store offsets to each file
		}
        	for ($i=0; $i<=$#$aref; $i++) {
                	$$aref[$i] =~ s/\t/%09/g;	# Convert tabs to %09 for storing
        	}

		print CFIL join("\t",@$aref),"\n";
		$offset = tell(CFIL);
	}
	close(IFIL);	
	close(CFIL);	

	return $cachefile;
}


# Get N to N+M hits from cache, if exists/available
sub LoadResult {
	my($glinesref, $cachefile, $N, $M, $tot_files_ref, $tot_lines_ref) = @_;
	my($j, $file, $prevfile, $ptrfile,$aref, $i);

	@$glinesref = ();

	($ptrfile = $cachefile) =~ s/^\.wgcache/\.wgptr/;

	# Check for escapes & other possibly bad things in the cachefile
	if ($cachefile =~ /(\.\.)|\||\<|\>|\~/) {  # For now just make sure no one is trying to change dirs or use a pipe
		warn("WARNING: Invalid cache file $cachefile passed to LoadResult!\n");
		&ExpireAll;
		return(0);
	}

	# Ok, we are safe, so bypass the -T security
	$cachefile =~ /^(.*)$/;
	$cachefile = $1;

	# There is no cache file, return empty list
	if ( ! -e "$TMPDIR/$cachefile" ) {
		&ExpireAll;
		return 0;
	}


	# Open the cache for reading
	open(CFIL, "$TMPDIR/$cachefile") || &err_badcache("$TMPDIR/$cachefile") && return(0);

	# Get the file & line counts out of the first line
	$line = <CFIL>;
	if ($line =~ /^([0-9]+):([0-9]+)/) {
		$$tot_files_ref = $1;
		$$tot_lines_ref = $2;
	}	

	$j = 0;
	$prevfile = '';

	# Lookup where we should start reading from cache  
	open(IFIL, "$TMPDIR/$ptrfile") || &err_badcache("$TMPDIR/$ptrfile") && return(0);
	my $size = length(pack("N",0));
	my $start = $N * $size;
	my ($raw,$ptr);

	seek(IFIL, $start, 0) || return(0);
	read(IFIL, $raw, $size) || return(0);
	close IFIL;

	$ptr = unpack("N", $raw);
	seek(CFIL, $ptr, 0) || return(0);
	$j = 0;

	# Read up to $M hits from the cache file
	$line = <CFIL>;
	while (($j < $M) && $line) {
		$aref = [ split("\t",$line) ];
		for ($i=0; $i<=$#$aref; $i++) {
			$aref->[$i] =~ s/%09/\t/g; 	# Convert %09 back to tab char (ok, might be a legit %09 somewhere...remember, this is just for the user to get an idea of what they found)
		}
		$file = $$aref[0];

		if ($file ne $prevfile) {
			$j++;
			$prevfile = $file;
		}
		push @$glinesref, $aref;
		$line = <CFIL>;
	}
	close(CFIL);

	# Our cache file was just used, but expire any other old ones
	&ExpireAll;

	# Return the # of lines we read
	return ($#$glinesref + 1);
}


sub err_nowritecache {

	$cachefile = shift;

	print "<!--ERROR: Unable to open cache file $cachefile for writing!-->";
	warn "ERROR: Unable to open cache file $cachefile for writing!";

	1;
}

sub err_badcache {
	$cachefile = shift;

	print "<!--ERROR: Unable to open cache file $cachefile for reading!-->";
	warn "ERROR: Unable to open cache file $cachefile for reading!";

	1;
}

