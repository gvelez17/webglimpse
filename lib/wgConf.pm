#!/usr/local/bin/perl

package wgConf;

# If any changes made to ARCHIVES_LIST, should only affect this module

# Represents the user interface for configuring archives
# May own objects of type
#
#	wgArch		Represents an archive
#	wgRoot		Represents a Dir, Site or Tree set of pages
#					

# Try to contain all special file formats and user interfaces here
# (though archive.cfg is recognized inside wgArch)

# Currently we are using a flat text file to contain archive information,
# in the future should have option for DBM files

# Functions:
#	new			Reads wgsites.conf for global settings
#    	GetArch			Looks up directory, arch vars from ID in WGHOME/.archives
#	SaveArch
#	LoadArchs
#	SaveArchs
#	GenArchID
#

my $REVISION = '$Id $';

my $debug = 0;

BEGIN {
	use wgHeader qw( :conf :general );  
	use wgErrors;
}


use wgArch;
use CommandWeb;

# Public variables
%Archives = ();
$LastID = 0;

1;


##########################################################################
# GetArch	Looks up by ID in WGHOME/.archives, returns archive object
#
# Format of .archives is 
#
#	ID	PATH	TITLE	CATEGORY	SEARCHURL	DESCRIPTION
#
# fields separated by TAB characters.  Category field is 16-byte string.
#
# Accepts archive ID as input, returns a wgArch object


sub GetArch {
	my $id = shift;

	# Load archive info if we haven't already
	if ($LastID == 0) {
		&LoadArchs;
	}

	if ($Archives{$id}) {
		return $Archives{$id};
	}		

	$lastError = "Could not find an existing archive with Id = $id";
	return(0);
}


sub GetArchbyPath {
	my $Path = shift;
	my $wgarch;

	# Load archive info if we haven't already
	if ($LastID == 0) {
		&LoadArchs;
	}

	foreach $wgarch (values %Archives) {
		if ($wgarch->{Dir} eq $Path) {
			return $wgarch;
		}
	}

	# Check if there really is an archive in that directory, even if we don't have a listing for it
	if (-e "$Path/$CONFIGFILE") {
		$LastID++;		
		$wgarch = new wgArch($LastID);
		$wgarch->{Dir} = $Path;
		$wgarch->LoadRoots || $wgarch->LoadLegacyConfig;	
		AddEntry($wgarch);
		return $wgarch;
	}	

	$lastError = "Could not find an existing archive with Path = $Path";
	return(0);
}


# In the future if we use DBM or other database to store archives, we may save one at a time
# For now we just call SaveArchs to save all of them at once in the flat file
sub SaveArch {
	my $march = shift;

	if ($LastID == 0) {
		return 0;
	}

	return &SaveArchs;
}


sub GenArchID {

	if ($LastID == 0) {
		&LoadArchs;  # If LoadArchs fails, ok, we start at ID 1
	}

	$LastID++;

	return $LastID;
}


sub LoadArchs {
	
	my($id, $sid, $path, $title, $category, $searchurl, $descript, $lang, $addboxes, $prefilter, $killjunk);
	my $wgarch;

	$LastID = 0;
	$id = 0;
	my $ret = 0;

	my $archlist = $WGARCHIVE_DIR.'/'.$ARCHIVE_LIST;
	if (!open(F, $archlist)) {
		$lastError = "Cannot open archive list $archlist";
		return 0;	
	}

	while(<F>) {
		chomp;
		$_ || next;
		/^\s*#/ && next;
		($sid, $path, $title, $category, $searchurl, $descript, $lang,$addboxes,$prefilter,$usesf, $trackid, $pid, $numres, $keywords, $killjunk) = split(/\t/, $_, 15);
		$id = $sid + 0;

		# Put returns back in description field
		$descript =~ s/\|/\n/g;

		$wgarch = new wgArch($id, $path, $title, $category, $searchurl, $descript,$lang,$addboxes,$prefilter,$usesf, $trackid, $pid, $numres, $keywords);	

		$Archives{$id} = $wgarch;
	
		($id > $LastID) && ($LastID = $id);

		$ret = 1;
	}

	close F;

	return $ret;
}



sub SaveArchs {

	my ($wgarch, $line,$descript);

	my $archlist = $WGARCHIVE_DIR.'/'.$ARCHIVE_LIST;
	if (!open(F, ">$archlist")) {
		$lastError = "Cannot open archive list $archlist for writing";
		return(0);
	}

	foreach $wgarch (values %Archives) {

		# Remove carriage returns in description
		$descript = $wgarch->{Description};
		$descript =~ s/[\n\a\r]+/\|/g;

		$wgarch->{PreFilter} =~ s/\t/ /g;
	
		$line = join "\t", $wgarch->{ID},$wgarch->{Dir}, $wgarch->{Title}, $wgarch->{Category}, $wgarch->{SearchURL}, $descript,$wgarch->{Lang},$wgarch->{AddBoxes},$wgarch->{PreFilter},$wgarch->{UseSF},$wgarch->{SFtrackID},$wgarch->{SFpID},$wgarch->{SFnum},$wgarch->{SFkeywords};	

		print F $line,"\n";
	}
	close F;

	return 1;
}

# For now, all archive entries are stored in a text file called .archives
# .archives has the format
# ID	Dir	Title	Category	SearchURL	Description	Lang
# 
# here we know for sure we are adding a new one, just add onto the end of ARCHIVES_LIST
sub AddEntry {
	my $march = shift;

	my ($varname, $line);

	# We need at least ID & Dir to add an entry
	defined($march->{ID}) || return($ERR_NOID);
	defined($march->{Dir}) || return($ERR_NODIR);

        # Remove carriage returns in description
        $descript = $march->{Description};
        $descript =~ s/[\n\a\r]+/\|/g;

	no strict 'refs';
	
	# Build the line for adding to archives list
	$line = '';
	foreach $varname (@wgArch::members) {
		if (defined($march->{$varname})) {
			$line .= $march->{$varname}."\t";
		} else {
			$line .= ' '."\t";
		}
	}
	chop $line;

	# don't check if exists, we will create it if this is the first one
	my $archlist = $WGARCHIVE_DIR.'/'.$ARCHIVE_LIST;
	open(F, ">>$archlist") || (($lastError = "Can't write to $archlist") && return($ERR_CANTWRITETOFILE));

	print F $line,"\n";

	close F;

	# Add to Archives hash so we stay current
	$Archives{$march->{ID}} = $march;

	return(1);
}


sub DelEntry {
	my $id = shift;

	if ($LastID == 0) {
		&LoadArchs || return(0);
	}

	delete $Archives{$id};

	&SaveArchs || return(0);

	return 1;
}
