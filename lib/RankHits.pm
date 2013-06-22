#!/usr/local/bin/perl

package RankHits;

use Time::Local;

my $REVISION = '$Id $';

# RankHits sorts an array of hits returned by Glimpse according
# to user-defined criteria.  In some cases, the file may be opened again
# for additional information.

# Criteria not requiring opening the file:
#
#	$N		# of times the word appears in the file
#	$HasExactMatch	there is a match to the entire exact query
#	$LineNo		Earliest line in the file where the word appears
#	$TITLE		# of times the word appears in the TITLE tag
#	$FILE		# of times the word appears in the file path
#	(no var)	Context of the word within the record/line
#	$Days		Date (days old)
#	$LinkPop	'link popularity' - # of links to file
#	$LinkString	Actual link, in case we want to put certain sites ahead of others
#	$QueryRegExp	A Regexp for finding positive matches to users query
#	$WordSpan	For AND-only boolean searches, # of words keywords are apart
#
# Criteria requiring the file to be opened 
#
#	$META		# of times the word appears in any META tag
#	%MetaHash	MetaHash{Name} = # of times the word appears in the META tag NAME="Name"	
#	Context away from the record where the word was found (not currently coded for)
#	$HLevel, $Bold,  
#	$FontLevel	HTML codes surrounding the word (others possible)
#	
# Criteria currently not available (because not stored)
#
#	Place within the directory or link tree where the file was found
#	'popularity' of this file in searches
#
#
# Note: Properly speaking, there could be two formulae: one for each result line,
# and one for the file as a whole.  We only use a single formula to evaluate
# the entire file, so we have somewhat less ability to code for correlations.
# This would be an interesting improvement for future versions... --GV
#

# Static variables local to this package
my ($SUPPORTED_VARS, $RANK_CFG_FILE);
$SUPPORTED_VARS = " N LineNo LinkPop TITLE META MetaHash HLevel Bold FontLevel Days LinkString QueryRegExp WordSpan ";  # Requires leading & trailing space
$RANK_CFG_FILE = ".wgrankhits.cfg";
my $rank_cfg_file = '';
my $SecsperDay = 60*60*24;
my $DEF_DAYS = 100;	# If date not returned

# For variable replacement in ranking formula
my ($N, $HasExactMatch, $LineNo, $LinkPop, $TITLE, $FILE, $META, $HLevel, $Bold, $FontLevel, $Days, $LinkString, $QueryRegExp, $WordSpan);
my %MetaHash = ();

# To make sure we do not evaluate variables unnecessarily
my ($NeedN,$NeedMeta ) = (0,0) ;

# From webglimpse
my ($QS_lines, $FILE_END_MARK, $maxchars, $max_wordspan, $threshold, $need_wordspan);

# Regular expression for all keywords in the query
my $Keywords = '';
my $OriginalQuery = '';

# Sequence # to force re-evaluation of formula for each hit
my $seq = 0;

# Ranking formula user chose
my $RankingFormula = '';
my $DefaultRankingFormula = '';
my %NamedRankingFormula = ();


# Translate month abbreviations back to month numbers
my %Months = (
	Jan => 0,
	Feb => 1,
	Mar => 2,
	Apr => 3,
	May => 4,
	Jun => 5,
	Jul => 6,
	Aug => 7,
	Sep => 8,
	Oct => 9,
	Nov => 10,
	Dec => 11
);

# Keep file names for each result line so we don't have to re-parse
my %FileNames = ();

my $debug = 0;

1;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

# We need to know the archive directory to read the configuration file from
	my ($archive_dir) = @_;
	$self->{archive_dir} = $archive_dir || '';
	$rank_cfg_file = $self->{archive_dir}."/$RANK_CFG_FILE";

# Read the .wgrankhits.cfg file for the ranking formula
	$self->ReadRankConf();

	$self->ResetVars();

	$self->{default_ranking_formula} = $DefaultRankingFormula;

	return $self;
}

sub ResetVars {

	$N = 0;
	$HasExactMatch = 0;
	$TITLE = 0;
	$LinkPop = 0;
	$LinkString = '';
	$FILE = 0;
	$META = 0;
	$Days = undef;
	$LineNo = undef;

	$QueryRegExp = '';

	$HLevel = 0;
	$Bold = 0;
	$FontLevel = 0;

	%MetaHash = ();

	return 1;
}


#
# Called with a reference to the array of lines returned by Glimpse
# And the original query
sub RankHits {
	my ($glinesref, $query);

	# $QS_lines, $maxchars, $FILE_END_MARK, $max_wordspan, $threshold
	# are module-wide vars

	($self,$glinesref, $query, $QS_lines, $FILE_END_MARK, $maxchars, $rankby, $max_wordspan, $threshold) = @_;

	my @filescores = ();	# 2-dim array of (rownum, score) tuples
	my @newlines = ();	# for ordered glines array
	my ($ref, $rownum, $filename);

	$DefaultRankingFormula = $self->{default_ranking_formula};

	$rankby = uc($rankby);

	if (defined($rankby) && defined($NamedRankingFormula{$rankby})) {
		$RankingFormula = $NamedRankingFormula{$rankby};
	} else { 
		$RankingFormula = $DefaultRankingFormula;
	}

	# If we have Rules for eliminating some lines, we need a threshold
	if ($max_wordspan && ! defined($threshold)) {
		$threshold = 0;
	}

	# Get the keywords out of the query
	$OriginalQuery = $query;
	$Keywords = SimplifyQuery($query);
	@Keywords = split(/\|/,$Keywords);

	# Make 2-dim array of rownums, scores corresponding to files
	MakeFileScores($glinesref, \@filescores);

$debug && print("<!--Found ",$#filescores, " separate files out of ",$#$glinesref, " lines <p>-->\n");

	# Sort filescores by scores, highest to lowest.
	@filescores = sort { $$b[1] <=> $$a[1] } @filescores;

	# Now create a new array, with files ordered by score
	my $num_files_returned = 0;
	foreach $ref (@filescores) {
		# If we have a threshold, only include lines that score = or higher
		if (! defined($threshold) || ($$ref[1] >= $threshold)) {
			$num_files_returned++;
			$rownum = $$ref[0];
			push @{$$glinesref[$rownum]}, $$ref[1];		# Store the score too
			push @newlines, $$glinesref[$rownum] ;
			$filename = $FileNames{$rownum};
			$rownum++;
	
			while(($rownum < @$glinesref) && ($FileNames{$rownum} eq $filename)) {
				push @newlines, $$glinesref[$rownum];
				$rownum++;
			}
		} else {
			last;
		}
	}

	# Copy the new array back into glines
	@$glinesref = ();
	@$glinesref = @newlines;

	return $num_files_returned;
}

#
# Opens archive_dir/.wgrankhits.cfg and reads in formula for exec
sub ReadRankConf {
	my $rankby;

	$DefaultRankingFormula = '';
	if ( -e $rank_cfg_file && open(F, $rank_cfg_file)) {
		while(<F>) {
			next if (/^\s*\#/);     # Skip comments
			next if (/^\s*$/);      # Skip blank lines
			# may be part of named formula, or default
			if (/^([A-Za-z_0-9]+):(.*)$/) {
				$rankby = uc($1);
				if (exists($NamedRankingForumla{$rankby})) {
					$NamedRankingFormula{$rankby} .= $2;
				} else {
					$NamedRankingFormula{$rankby} = $2;
				}
			} else {
				$DefaultRankingFormula .= $_;  # Otherwise add to formula
			}
		}
		close F;
		$NamedRankingFormula{'DEFAULT'} = $DefaultRankingFormula;
		
		# Security & validity checks here.  We will also eval in a protected shell
		# Make sure all variables are in $SUPPORTED_VARS
		foreach $name (keys %NamedRankingFormula) {
			$RankingFormula = $NamedRankingFormula{$name};
			while ($RankingFormula =~ /\$(\w+)/gi) {
				($SUPPORTED_VARS =~ / $1 /) || ($NamedRankingFormula{$name} = '');
			}
		}
	}  
	$DefaultRankingFormula = $NamedRankingFormula{'DEFAULT'};  # after security checks

	# If we didn't find file, or rejected the formula
	if ($DefaultRankingFormula eq '') {

		#Default to ordering by date, most recent first
		$DefaultRankingFormula = '-$Days';
	}

	# Untaint RankingFormulas; we trust .wgrankhits.cfg file
	foreach $name (keys %NamedRankingFormula) {
		$NamedRankingFormula{$name} =~ /^(.+)$/;
		$NamedRankingFormula{$name} = $1;
	}
	$DefaultRankingFormula  =~ /(.+)/;
	$DefaultRankingFormula = $1;

$debug && print("<!-- Default Ranking formula is: $DefaultRankingFormula --> \n\n");

	return 1;  
}




sub MakeFileScores {
	my ($glinesref, $filescoresref) = @_;

	my $lastfilescore = 0;
	my $curfile = '';
	my $lastfile = '';
	my $lastrownum = 0;
	my $rownum;

	$NeedN = ($RankingFormula =~ /\$N\b/);

	$NeedMeta = ($RankingFormula =~ /\$META\b|\$MetaHash/);

	for ($rownum=0; $rownum < @$glinesref; $rownum++) {
		($lastfilescore, $curfile) = ScoreLine($$glinesref[$rownum], $lastfile);

		# Set global filename hash so we don't have to re-parse
		$FileNames{$rownum} = $curfile;

		if ($curfile ne $lastfile) {
			if ($lastfile ne '') {
				push @$filescoresref, [ $lastrownum, $lastfilescore ];
			}
			$lastfile = $curfile;
			$lastrownum = $rownum;
		}
	}
	if ($lastfile ne '') {
		$lastfilescore = eval $RankingFormula;

		# Now apply 'Rules' that might eliminate $lastfile entirely
		if ($max_wordspan && $need_wordspan) {
			if (($WordSpan==0) || ($WordSpan > $max_wordspan)) {
				$lastfilescore = $threshold - 1;
			}
		}

                # Without the following do-nothing loops, the eval _above_
                # fails to evaluate RankingFormula correctly. Take them out and see!
                $N; $LineNo; $LinkPop; $LinkString; $QueryRegExp; $TITLE; $META; $MetaHash; $HLevel; $Bold; $FontLevel; $Days; $WordSpan; $HasExactMatch;
		foreach (keys(%MetaHash)) {
			$MetaHash{$_};
		}
		push @$filescoresref, [ $lastrownum, $lastfilescore ];
	}

	return 1;
}



#
# Calculates & updates variables for each result line
# Evaluates ranking formula for each previous file when a new file is reached
# The last file is evaluated in MakeFileScores above.
# replace line in place with simpler pattern for faster re-parsing with webglimpse.cgi
#
sub ScoreLine {
	$lineref = shift;

	# We need to know if we're on a new file for some of the scoring rules	
	my $lastfile = shift;

	my ($file, $link, $linkpop, $title, $date, $line, $string);
	$file = '';
	$link = '';
	$title = '';
	$date = '';
	$line = '';
	$string = '';
	my ($monabr, $mday, $year, $mon);

	my $lastfilescore = 0;
	my $firstline = 0;

# TODO: If this is still slow may want to refer to string by ref, no need to copy so many times
        if ($QS_lines) {
                ($file,$link,$linkpop,$title,$date,$line,$string) = @{$lineref};
        } else {
                ($file,$link,$linkpop,$title,$date,$string) = @{$lineref};
        }
	# If this is a new file, we need to score the last one and reset vars
	if ($file ne $lastfile) {
		if ($lastfile ne '') {
			$lastfilescore = eval $RankingFormula;

			# Now apply 'Rules' that might eliminate $lastfile entirely
			if ($max_wordspan && $need_wordspan) {
				if (($WordSpan==0) || ($WordSpan > $max_wordspan)) {
					$lastfilescore = $threshold - 1;
				}
			}
#print "Score for $lastfile is $lastfilescore<br>\n";

			# Without the following do-nothing loop, the eval _above_ 
			# fails to evaluate MetaHash correctly. Take it out and see!
			foreach (keys(%MetaHash)) {
				$MetaHash{$_};
			}
		}
		&ResetVars;
		$firstline = 1;
	}

	$LinkString = $link;

	$QueryRegExp = $Keywords;

	# Bail out early if no valid Keywords to look for
	(! $Keywords) && return(0,$file);

# !!!!
#TODO: only evaluate variables that will be used in RankingFormula

	# Just use link popularity as counted by makenh
	$LinkPop = $linkpop;

	# Count number of matches in the record
	if ($NeedN) {
		while ($string =~ /$Keywords/ig) {
			$N++;
		}
	}
	
	if ($string =~ $OriginalQuery) {
		$HasExactMatch = 1;
	} else {
		$HasExactMatch = 0;
	}

	# How far apart are they?  Only applies if >1 keyword
	if (($#Keywords > 0)&&(($RankingFormula =~ /WordSpan/)||($max_wordspan>0))) {
		$need_wordspan = 1;
		$WordSpan = &getWordSpan(\$string);	
		# Will have to warn user not to divide by this, 0 if no window in this record
	} else {
		$WordSpan = 0;
		$need_wordspan = 0;	# WordSpan itself might be 0 even if we need it
	}

	# Count matches in title; this should only be added once per file
	if ($firstline) {
		$TITLE = 0;
		while ($title =~ /$Keywords/ig) {
			$TITLE++;
		}
	}


	# Count matches in filename; also only counted once per file
	if ($firstline) {
		$FILE = 0;
		while ($file =~ /$Keywords/ig) {
			$FILE++;
		}
	}

	# Check for earliest line number if we have it. (Should be first one encountered, but who knows)
	if ($line && (!defined($LineNo) || ($line < $LineNo))) {
		$LineNo = $line;
	}

	# TODO: Add real support for HLevel, Bold, FontLevel 
	$HLevel = 0; $Bold = 0; $FontLevel = 0; 

	# Look for matches in META tags (we know each META tag will be together on one line)
	if ($NeedMeta) {
		while ($string =~ /<META\s+NAME\s*=\s*['"]?([^\s\"\']+)['"]?\s+CONTENT\s*=[^>]*$Keywords/ig) {

			if (defined($MetaHash{$1})) {
				$MetaHash{$1}++;
			} else {
				$MetaHash{$1} = 1;
			}
			$META++;
		}
	}


	if (!defined($Days) && $date) {
		# Get days old from date format: May 30 1999
		$date =~ /(\w+)\s+(\d+)\s+(\d+)/;
		$monabr = $1;
		$mday = $2;
		$year = $3;
#		($monabr,$mday,$year) = ($date =~ /(\w+) (\d+) (\d+)/);
		$mon = $Months{$monabr};

		if (defined($mday) && defined($mon) && defined($year)) {
			$Days = (time - timelocal(0,0,0,$mday,$mon,$year))/$SecsperDay;
		} else {
			$Days = $DEF_DAYS;
		}
		$debug && print("<!-- mday = $mday, mon = $mon, year = $year, Days = $Days -->\n");
	} elsif ( !defined($Days)) {
		$Days = $DEF_DAYS;
	}



	#TODO: We should only need to compile this once, then 
	# express it with different variables.  $RankingFormula could potentially contain conditionals & other perl code

	#TODO: use Safe to evaluate with reval

	return($lastfilescore, $file);
}

#
# Make a regular expression for all keywords in query
sub SimplifyQuery {
	$_ = shift;

	# First remove all the "NOT"'d keywords
	s/\~\s*\w+//g;

	# Now change all boolean operators into a regexp-style 'OR'
	# don't split up phrases with spaces in them
	s/[\,\;]/\|/g;

	# Result should be of the form  "KEYWORDA|KEYWORDB|PATTERNC"

	return $_;
}


#
# Find size of window in which all @Keywords appear
sub getWordSpan {
	my $stringref = shift;

	my @words = split(/[\s\.\?\:\;\,\"]+/,$$stringref);
	my $numwords = $#words;

	my $n = length($$stringref);
	my %candidate = ();	# $candidate{$pos} = $size

	my $curpos = 0;
	my $curwinsize = &getWindowHere(\@words, $curpos, $numwords);

	my $smallest = $curwinsize;

	# If we don't have all the keywords, return 0
	if (! $curwinsize) {
		return 0;
	}
	
	# Keep going until we can't get a valid window
	while ($curwinsize) {

		# Go past any non-keywords
		while ($words[$curpos] !~ /$Keywords/i) {
			$curpos++;
		}
		# we're at a keyword - measure the window
		$candidate{$curpos} = $curwinsize = &getWindowHere(\@words, $curpos, $numwords);

		# is this the smallest?
		if ($curwinsize && ($curwinsize < $smallest)) {
			$smallest = $curwinsize;
		}
		
		# move past it
		$curpos++;
	}
	# Return smallest window
	return $smallest;

}


#
# Find minimum size of window starting at beginning of this substring
sub getWindowHere {
	my ($wref, $pos, $max) = @_;

	my $numfound = 0;
	my $needfind = $#Keywords;
	$needfind++;
	my %Keywords = ();

	my $j = $pos;

	while (($j <= $max)&&($numfound<$needfind)) {

		my $word = $wref->[$j];
		if ($word =~ /\b($Keywords)\b/i) {
			if (! $Keywords{$word}) {
				$numfound++;
				$Keywords{$word} = $j;
			}
		}
		$j++;
	}
	if ($numfound >= $needfind) {
		return ($j - $pos);
	} else {
		return 0;
	}	
	
}


