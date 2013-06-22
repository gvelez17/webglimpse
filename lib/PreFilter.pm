#!/usr/local/bin/perl

package PreFilter;

use wgHeader;

1;

sub new {
		my $class = shift;
		my $self = {};
		bless $self, $class;
		$self->{FileName} = shift;
		$self->{TmpDir} = shift || '/tmp';
		my $allowedfilters = shift || '';
		my $ext;
		$self->{Filters} = {};
		$self->{AllowedFilters} = {};
		$self->{AllowAll} = 0;
		if ($allowedfilters =~ /^\s*all\s*$/i) {
			$self->{AllowAll} = 1;
		} else {
			foreach $ext (split(/\s+/,$allowedfilters)) {
				$self->{AllowedFilters}->{$ext} = 1;
			}
		}
		$self->{UniqueID} = time;	# Name for my tmp files
		return $self;
}

sub LoadFilters{
	my $self=shift;
	my($ext, $filter);
  
	# read in the info from file
	if (! eval{ open(FILE, $self->{FileName}); } ) {
		warn "Cannot open file $_[0]\n";
		return;
	}
  
	while(<FILE>){
		next if /^\s*#/;
		chomp;
		# We now read the trailing '<' as part of the filter program
		# this allows alternate filters that accept the filename as param
		if (/\*\.(\S+)\s+(.+)$/) {
			$ext = $1;
			$filter = $2;
			
			if ($self->{AllowAll} || $self->{AllowedFilters}->{$ext}) {
				# Don't use any html filter except htuml2txt.pl
				next if (($filter =~ /ht.?m/) && ($filter !~ /htuml2txt.pl/));

# TODO: Check that filter program is executable
# TODO: return error using general routine

				$self->{Filters}->{$ext} = $filter;
			}
		}
	}
	close FILE;
}

sub NeedsFilter {
	my $self = shift;
	my $fname = shift;

	if ($fname !~ /\.([^.\/]+)$/) {
		return '';
	}
	if ($self->{Filters}->{$1}) {
		return $1;

	} elsif ($self->{Filters}->{'*'}) {
		return $1;
		# For now return original extension as will be used to compare to filename
	}
	return '';
}

sub FilterInPlace {
	my $self = shift;
	my ($ext, $fname) = @_;

	my $ffile = $TMPDIR.'/.wg_prefilter_tmpfile_'.$self->{UniqueID};	# should never need more than 1 at a time for this indexing
	$self->Filter2File($ext,$fname,$ffile);
	if (! rename($ffile, $fname)) {
		unlink $fname;
print "rename failed, trying to copy $ffile to $fname\n";
		`cp "$ffile" "$fname"`;
		unlink $ffile;
	}
}

sub Filter2File {
	my $self = shift;
	my ($ext, $fname, $target) = @_;

	my $prog = $self->{Filters}->{$ext} || $self->{Filters}->{'*'};

	exit(0) unless $prog;

	# tell filtering program the filename if desired
	$prog =~ s/\[FILENAME\]/$fname/ig;

	# The '<' character may or may not be part of the filter program name
	# this allows filtering by passing the file name as parameter rather than
	# forcing via STDIN - fix suggested by D.P. Kreil, thanks!  --GV
	`$prog "$fname" >"$target"`;

# TODO: check that ftarget is not zero bytes
# if so print error message, prepare error message for email, and keep fname
# check permissions, return vals on files, prog, for likely reason

}


