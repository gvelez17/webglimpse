#!/usr/local/bin/perl

package CustomOutputTool;

use strict;

BEGIN {
        use wgHeader qw( :general );
}

my $REVISION = '$Id $';

#CustomOutputTool reads the desired format from a configuration file,
# customoutput.cfg in the archive directory, of the format
#
#  begin_html	...html code...[SPECIAL_VAR]...html code...
#  + ...more html code...
#  + ...more html code...
#
#  other_var   	...html code...
#
#  end_html	...html code...
#
#  Supported variables are listed in $SUPPORTED_VARS
#
#  Special replacement variables are:  [QUERY],[SEARCHTITLE],[CACHEFILE]
#  (may be used only in certain functions)  [MATCHED_LINES], [MATCHED_FILES], [LINK], [DATE], [MATCHED_LINES_SHOWN], [MATCHED_FILES_SHOWN], 

# for begin_html and end_html only: [INCLUDE: filesname]
#
#  Added OutputFields module to allow additional user-defined output fields
#  See OutputFields.pm for more details
#
# This package provides functions to output search results from Webglimpse

# Any replacement Output object must implement all of the following functions
# except as noted

# Path to local libs should already have been set in calling program
use LangUtils;
use wrRepos;    # [TT] 

# Static variables local to this package
my($SUPPORTED_VARS, $OUTPUT_CFG_FILE, $OUTPUT_FIELDS, $NEWQUERYBOX);
$SUPPORTED_VARS = "begin_html end_html begin_files end_files begin_file_marker end_file_marker begin_lines end_lines begin_single_line end_single_line neigh_msg noneigh_msg lines_msg nolines_msg newquery newquerybutton neigh lines matched_lines matched_files matched_lines_shown matched_files_shown starting_from maxfiles maxlines ending_at lines_exceeded files_exceeded begin_highlight end_highlight begin_matched_line end_matched_line begin_file_marker2 end_file_marker2 begin_lines2 end_lines2 path";
$OUTPUT_CFG_FILE = "wgoutput.cfg";
$OUTPUT_FIELDS = ".wgoutputfields";
$NEWQUERYBOX = "newquery.html";

# For variable replacement in results
my %OutputVars = ();

my %OutputFieldFileDefs = ();
my %OutputFieldPathDefs = ();
my %OutputFieldVarDefs = ();

my %AlternateOutputs = ();

my $debug = 0;

1;

### NOW WE ARE ADDING CACHE SUPPORT - NEXT HITS 


sub new {

	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->_initialize(@_);
	return $self;
}

# Set any static fields we will need later
# We need to parse the format file for the fields
sub _initialize {
	my $self = shift;

# We need to know the archive directory to read the configuration file from
# We need the query and title to build the output from templates
	my ($archive_dir, $query, $searchtitle, $lang, $multiple) = @_;
	$self->{archive_dir} = $archive_dir || '';

	defined($multiple) || ($multiple=0);
	$OutputVars{'QUERY'} = &Sanitize($query) || '';
	$OutputVars{'SEARCHTITLE'} = $searchtitle || '';
	$OutputVars{'PATH'} = '';

# Read the .wgoutputfields file for Output field definitions
	$self->ReadOutputFields();

# member variables set by wg
	$self->{maxchars} = 0;
	$self->{filename} = '';

# Set some nice-looking defaults

	$self->{begin_html} = '<HTML><HEAD><TITLE>Webglimpse Search Results</TITLE></HEAD><BODY>';
	$self->{end_html} = '</BODY></HTML>';

	$self->{begin_files} = "<TABLE WIDTH=\"100%\" BORDER=1>\n";
	$self->{end_files} = "</TABLE>\n";

	$self->{begin_file_marker2} = $self->{begin_file_marker} = "<TR><TD BGCOLOR='#aaffff'>\n";
	$self->{end_file_marker2} = $self->{end_file_marker} = "</TD></TR>\n";

	$self->{begin_lines2} = $self->{begin_lines} = "<TR><TD>";
	$self->{end_lines2} = $self->{end_lines} = "</TD></TR>";

	$self->{begin_single_line} = "";
	$self->{end_single_line} = "<br>";

	$self->{neigh_msg} = "neighborhood of <tt>[TITLE]</tt>";
	$self->{noneigh_msg} = "entire archive";

	$self->{begin_highlight} = "<b>";
	$self->{end_highlight} = "</b>";

	$self->{begin_matched_line} = '';
	$self->{end_matched_line} = '';

	$self->{lines_msg} = "jump-to-line is on";
	$self->{nolines_msg} = "";

	$self->{lines_exceeded} = "<br>maximum number of lines exceeded";
	$self->{files_exceeded} = "<br>Maximum number of files exceeded";
# Some local temporary variables
	my ($name, $val, $rest, $newname, $line, $cfgfile);

	$cfgfile = $self->{archive_dir}."/$OUTPUT_CFG_FILE";

# Now test for the existence of the configuration file
	if ( -e $cfgfile && open(F, $cfgfile)) {

		# Parse for settings and override defaults
		$name = '';
		$val = '';
		
		# Check each line
		while(<F>) {


			/^#/ && next; 	# skip comments

			chomp;


			# Added for multiple archive support 10/16/02 --GV
			if ($multiple) {
				s/\|TITLE\|/Combined/g;  
				s/\|[A-Z_a-z0-9]+\|//g;
			}

			$line = $_;

			# If a continuation of the last line, add it on
			if ($line =~ /^\+/) {
				$line =~ s/^\+//;	
				$val .= "\n".$line;
			} 
			# A new line, check if it is a recognized variable
			else {
				$rest = '';
				($newname, $rest) = split(/\s+/,$line,2);

				# Same as existing name, just keep adding on
				if ($newname eq $name) {
					$val .= $rest;
				} 
				
				# Ok, we have a new variable being set
				else {
				
					# Save the old one
					if ($name ne '') {
						$self->{$name} = $val;
					}

					# Check match to supported variable; case insensitive respecting word boundaries
					if ($SUPPORTED_VARS =~ /\b$newname\b/i) {
						$name = $newname;
						$val = $rest;
					} else {
						$name = '';
						$val = '';
					}
				}
			}

		} #endwhile reading file

		# Save the last one
		if ($name ne '') {
			$self->{$name} = $val;
		}
		close(F);

	} #endif opened file successfully

# Replace special variables
	foreach $name (split('\s',$SUPPORTED_VARS)) {
# Only do instance variables
#		&ReplaceVars(\($self->{$name}));
#
		$self->{$name} =~ s/\[QUERY\]/$OutputVars{QUERY}/g;
		$self->{$name} =~ s/\[SEARCHTITLE\]/$OutputVars{SEARCHTITLE}/g;

	}


# Set status variables
	$self->{inside_file} = 0;
	$self->{inside_lines} = 0;

}


# For setting member vars such as maxchars, filename
sub Set{
	my $self=shift;

	my $varname = shift;
	my $value = shift;

	$self->{$varname} = $value;
}


# Alternate output for structured queries, possibly other circumstances
# Currently is set to first X non-tag chars from file
sub PrepareAlternateOutput {
	my $self = shift;

	my $filename = $self->{filename} || return(0);
	my $maxchars = $self->{maxchars} || return(0);

	if (exists $AlternateOutputs{$filename}) {
		return 1;
	}

	open(F,$filename) || return(0);
	my $needchars = $maxchars;
	my $insoif = 0;
	
	while(<F>) {
		chomp;
		if (/^\@FIELD/) {
			$insoif = 1;
			next;
		}

		if ($insoif) {
			($_ eq '}') && ($insoif = 0);
			next;
		} 

		s/<[^>]*>//g;	

		$_ || next;

		my $substr = substr($_,0,$needchars);
		$needchars -= length($substr);
		$needchars--;
		$AlternateOutputs{$filename} .= $substr.' ';	
		if ($needchars <=0) {
			last;
		}
	}
	close F;
	if ($AlternateOutputs{$filename}) {
		return 1;
	} else {
		return 0;
	}
}

# For setting specific OutputVar from external program
sub SetOutputVar {
	my $self = shift;
	my ($name, $val) = @_;
	$OutputVars{$name} = $val;
}


# Called once on initialization.  
# Reads output field definitions from .wgoutputfields
# Sets all field definitions in %OutputFieldDefs
sub ReadOutputFields {
	my $self = shift;

	# Test for the existence of the output fields file
	if ( -e $self->{archive_dir}."/$OUTPUT_FIELDS" && open(F, $self->{archive_dir}."/$OUTPUT_FIELDS")) {

		while(<F>) {
			# Skip blank lines and comments
			next if (/^\#/ || /^\s+$/);

			chomp;

			@_ = split(/\t/);
			($#_ == 2) || next;  # Make sure we found 3 fields

			# Initialize value to blank (makes sure [KEYNAME] is replaced)
			$OutputVars{$_[1]} = '';

			if ($_[0] eq 'FILE') {
				$OutputFieldFileDefs{$_[1]} = $_[2];
			} elsif ($_[0] eq 'PATH') {
				$OutputFieldPathDefs{$_[1]} = $_[2];
			} elsif (($_[0] eq 'TEXT')||($_[0] eq 'VARTEXT')) {
				$OutputFieldVarDefs{$_[1]} = $_[2];
			} else {
# Currently no way to generate errors from this module. TODO.
				print STDERR "Could not parse $_ as $_[0]:$_[1]:$_[2]\n";
				next;
			}

		}
		close(F);
		return 1;
	}
	return 0;
}


# Called on every new file.  Parses field values out of file, or path
# Uses %OutputFieldDefs
# Sets values in %OutputVars
sub GetOutputFieldVals {
#	my $self = shift;
	my $filename = shift;
	my ($key, $pat);
	$_ = $filename;
	foreach $key (keys %OutputFieldPathDefs) {
		$pat = $OutputFieldPathDefs{$key} || next;
		/$pat/ && ($OutputVars{$key} = $1);
	}

	if (0 < keys %OutputFieldFileDefs) {
		if (open(F, $filename)) {
			while(<F>) {
				foreach $key (keys %OutputFieldFileDefs) {
					$pat = $OutputFieldFileDefs{$key} || next;
					/$pat/ && ($OutputVars{$key} = $1);
				}
			}
			close(F);
		}
	}

}


sub GetCustomOutputFields {
	my $val;
	my ($key, $pat);
	foreach $key (keys %OutputFieldVarDefs) {
		$pat = $OutputFieldVarDefs{$key} || next;
		&ReplaceVars(\$pat);
		$OutputVars{$key} = $pat;
	}
	return 1;
}


sub ReplaceVars {
#	my $self = shift;
	my $ref = shift;
	my $var ='';

	foreach $var (keys %OutputVars) {
		# but if there are [ ] in the value, don't double-replace
		my $val = $OutputVars{$var};

		$val =~ s/\[/\~5b/g; $val =~ s/\]/\~5d/g;
		$$ref =~ s/\[$var\]/$val/g;
	}

	# Check for HOOK: make sure not loopy
	while ( $$ref =~ s/\[HOOK:\s*([^\+\]]+)\+([^\]]+)\]/&ResolveHook($1,$2)/eg) { };

	# Eliminate unreplaced vars except INCLUDE's
	$$ref =~ s/\[(?!INCLUDE)[^\]]+\]//g;

       # now put literal [ ] back in case any from values of OutputVars
       $$ref =~ s/\~5b/\[/g;
       $$ref =~ s/\~5d/\]/g;

}

sub Sanitize {

	my $s = shift;

# to be applied to user-modifiable strings such as the query
# to prepare for output
	$s =~ s/[\;\[\]\<\>&\t]/_/g;
	return $s;
}


sub ResolveHook {
	my $module_name = shift;
	my $function_name = shift;

	my $result = eval "require $module_name";
	return (0) unless $result;

	$OutputVars{'URL'} = $OutputVars{'HREF'};

	my $href = \%OutputVars;

        my $retstring = '';

        my $retval;

        my $subr = '$retval'." = \&$module_name\:\:$function_name".'($href)';

        my $result = eval $subr;

        $retstring .= $retval;
	
	# check we never return the word [HOOK, then we can't loop
	if ($retstring !~ /\[HOOK/) {
		return $retstring;
	} else {
		return "What are you trying to do...?  Don't put [HOOK in the returned val\n";
	}

}




# applies to BEGIN_HTML and END_HTML sections only
sub IncludeFiles {
	my $ref = shift;
	my @lines = split(/\n/,$$ref);
	my $j;
	for ($j = 0; $j<=$#lines; $j++) {
		if ($lines[$j] =~ /^(.*)\[INCLUDE: ([^\]]+)\](.*)$/) {
			my @filelines = ();
		      	if (open(F, $2)) {
		              @filelines = <F>;
		              close F;
		      }
		      $lines[$j] = $1 . join("\n",@filelines) . $3;
		}
	}
	$$ref = join("\n",@lines);
}

# Clear all file-specific output variables
# Leaves in the two instance variables, QUERY and SEARCHTITLE.
sub ClearVars {
	my($var);
	foreach $var (keys %OutputVars) {
		if ($var !~ /^(QUERY)|(SEARCHTITLE)|(MAXFILES)|(MATCHED_LINES)|(MATCHED_FILES)|(MAXLINES)|(PATH)$/) {
			undef $OutputVars{$var};
		}
	}
}

sub SetNumHits {
	my $self = shift;
	my ($numfiles, $numlines,$startfrom,$maxfiles) = @_;

	$OutputVars{'MATCHED_FILES'} = $numfiles;
	$OutputVars{'MATCHED_LINES'} = $numlines;
	if ($numfiles > 0) {
		$OutputVars{'STARTING_FROM'} = $startfrom + 1;
	} else {
		$OutputVars{'STARTING_FROM'} = 0;
	}
	$OutputVars{'MAXFILES'} = $maxfiles;


	if ($startfrom + $maxfiles <= $numfiles) {
		$OutputVars{'ENDING_AT'} = $startfrom + $maxfiles;
	} else {
		$OutputVars{'ENDING_AT'} = $numfiles;
	}

	return 1;
}
		

sub makeInitialOutput {
	my $self = shift;
	my($pquery, $title, $QS_file, $QS_lines,$lang,$req) = @_;
	my($initial_output) = '';

	$initial_output = $self->{begin_html};

	if ($QS_file) {
		$OutputVars{'NEIGH'} = $self->{neigh_msg};
	} else {
		$OutputVars{'NEIGH'} = $self->{noneigh_msg};
	}

	if($QS_lines){
		$OutputVars{'LINES'} = "$self->{lines_msg}";
	}else{
		$OutputVars{'LINES'} = "$self->{nolines_msg}";
	}

	# Override initial_output for scientific reprints repository usage [TT]
	if ( $WRREPOS ) {
	    &wrRepos::makeReposInitial(\$self, \$initial_output);
	}

        &IncludeFiles(\$initial_output);
        &ReplaceVars(\$initial_output);
        return $initial_output;
}


sub makeBeginFiles {
        my $self = shift;

        my $retstring = $self->{begin_files};
        &ReplaceVars(\$retstring);

        return $retstring;
}

sub limitMaxLines {
	my $self = shift;
	my($maxlines) = @_;

	$OutputVars{'MAXLINES'} = $maxlines;

	my $msg = $self->{lines_exceeded};
	&ReplaceVars(\$msg);
	return $msg;
}


sub limitMaxFiles {
	my $self = shift;
	my($maxfiles) = @_;

	my $retstring = '';

	$retstring =  $self->makeEndHits(1);
	$retstring .= $self->{files_exceeded};

	&ReplaceVars(\$retstring);
	return $retstring;
}

# For some shopping carts we need to modify the link output
sub fixLink {
        my $self = shift;
        my ($link, $prepath, $postpath, $insertbefore) = @_;

        if ($prepath && $insertbefore) {
                $link =~ s/$insertbefore/$prepath$insertbefore/;
        }

        if ($postpath) {
                $link .= $postpath;
        }
        return $link;
}

sub makeLinkOutput {
	my $self = shift;
	my($link, $title, $date, $file,$lang) = @_;
	my $retstring =	'';

	# Now we can set the output field values for this file.
	&GetOutputFieldVals($file);

	# TITLE is special - if we have a field named TITLE, use that instead
	if ($OutputVars{TITLE}) {
		$title = $OutputVars{TITLE};
	} else {
		$OutputVars{TITLE} = $title;	# Otherwise let user reach this one
	}

        # fix the title in case it has quotes
        $title =~ s/\"/\&quot;/g;
        $title =~ s/\'/\&apos;/g;

	# If title and begin_file_marker are blank, don't output anything
	if (($title =~ /^\s*$/) && ($self->{begin_file_marker} =~ /^\s*$/) && ($self->{end_lines} =~ /^\s*$/)) {
		$self->{inside_lines} = 0;
		$self->{inside_file} = 1;
		return '';
	}

	# Set special output vars LINK and DATE from params passed in
	$OutputVars{'HREF'} = $link;
	$OutputVars{'LINK'} = "<A HREF=\"$link\">$title</A>";

	# Perform languag-specific date modification
	$OutputVars{'DATE'} = &LangUtils::ConvertDate($date,$lang);

	# Override output vars for use as scientific prints repository [TT]
	if ( $WRREPOS ) {
	    ($OutputVars{'LINK'}, $OutputVars{'DATE'}) = 
		&wrRepos::makeReposLinks(\$self, $link, $OutputVars{'DATE'});
	}

	if ($self->{inside_lines}) {
		$retstring = $self->{end_lines};
		$self->{inside_lines} = 0;
	}

	$retstring .= $self->{begin_file_marker};

	# For backwards compatibility, if no [LINK] or [HREF] tag, put in fixed link text
	if ($retstring !~ /\[LINK\]|\[HREF\]/) {
		$retstring .= "<b><A HREF=\"".$link."\">";
		$retstring .= $title."</A></b>, $date<br>\n";
	}

	$self->{inside_file} = 1;

	&GetCustomOutputFields();
	&ReplaceVars(\$retstring);
	return $retstring;
}


sub makeStartFileDesc {
	my $self = shift;
	my($metadesc, $file, $score) = @_;
	my $retstring = '';

	if ($self->{inside_file}) {
		$retstring = $self->{end_file_marker};
		$self->{inside_file} = 0;
	}


	if ($self->{inside_lines}) {
		$retstring .= $self->{end_lines};
	}
	$retstring .= $self->{begin_lines};
	if ($metadesc ne '') {
		$retstring .= "$metadesc<br>\n";
	}

	$self->{inside_lines} = 1;
	$OutputVars{'SCORE'} = $score;

	&ReplaceVars(\$retstring);
	
	return $retstring;
}


sub makeEndFileDesc {
	my $self = shift;

	my $retstring = $self->{end_lines};

	$self->{inside_lines} = 0;

	&ReplaceVars(\$retstring);

	&ClearVars;
	return $retstring;
}

sub makeJumpToLine {
	my $self = shift;
	my($linkto, $line, $string) = @_;

	my $retstring = $self->{begin_single_line};
	$retstring .= "<A HREF=\"$linkto\">\n" .
	  "line $line</A>:$string\n" . $self->{end_single_line};

	&ReplaceVars(\$retstring);

	return $retstring;
}


sub makeLine {
	my $self = shift;
	my $string = shift;
	# Are we using alternate output?
	if (exists $AlternateOutputs{$self->{filename}}) {
		if ($string =~ /\{\d+\}:/) {	# Structured query result
			$string = $AlternateOutputs{$self->{filename}};
		}
	}

	my $retstring = $self->{begin_single_line}.$string.$self->{end_single_line}."\n";
	&ReplaceVars(\$retstring);
	return $retstring;
}


sub makeEndHits {
	my $self = shift;
	my($file) = @_;

	my $retstring = '';

	$retstring .= $self->{end_lines} if $self->{inside_lines};

	$retstring .= $self->{end_file_marker} if $self->{inside_file};

	$retstring .= $self->{end_files};

	&ReplaceVars(\$retstring);

	return $retstring;
}



sub makeFinalOutput {
	my $self = shift;
	my($QS_query, $lcount, $fcount) = @_;
	my $retstring;

	# Now we can set MATCHED_LINES, MATCHED_FILES values
	$OutputVars{MATCHED_LINES_SHOWN} = $lcount;
	$OutputVars{MATCHED_FILES_SHOWN} = $fcount;

	# We shouldn't need QS_query, it was already set in initialize

	$retstring = $self->{end_html};

	&ReplaceVars(\$retstring);
	&IncludeFiles(\$retstring);

	return $retstring;
}


###################################################################
# THE FOLLOWING FUNCTIONS ARE UNIQUE TO CustomOutputTool.pm
#
# and do NOT need to be defined in alternate output modules
#

# Creates link that will return next N hits from the cache
# Note, some of the query parameters are not preserved, so if the user modifies the query 
# from the "Next Hits" page, some of the search parameters will be reset to defaults.


sub makeNextHits {
	my $self = shift;
	my($id, $cachefile, $query, $maxfiles, $maxlines, $maxchars, $numfiles, $atnum, $numlinks,$qs_lines) = @_;

	# We don't need a toolbar if we are showing all the hits
	if (($numfiles>0) && ($numfiles <= $maxfiles)) {
		return '';
	}
	my $optlines = '';
	if ($qs_lines) {
		$optlines = '&lines=on';
	}

	my($wgurl);

	my $startfrom = 0;

	my $retstring = '<p>';

	chomp $query;
	$query =~ s/ /\%20/g;
	$query =~ &Sanitize($query);
# TODO: fix all nonalphabetic chars in query using standard encoding

	# which toolbar group are we in
	my $tgnum = int $atnum/($maxfiles*$numlinks);
	$startfrom = $tgnum * $maxfiles * $numlinks;

	if ($startfrom > 0) {
		my $prevnum = $startfrom - $maxfiles;
		if ($prevnum < 0) {
			$prevnum = 0;
		}
		$wgurl = "/$main::CGIBIN/webglimpse.cgi?ID=$id&query=$query&cache=$cachefile&startfrom=$prevnum&maxfiles=$maxfiles&maxlines=$maxlines&maxchars=$maxchars$optlines";
		$retstring .= "<A HREF=\"$wgurl\">&lt;&lt;&lt;prev</A> | ";
	}
	my $numgroups = $numlinks;
	my $groupcount = 0;
	while (($groupcount<$numgroups) && ($startfrom < $numfiles)) {
		$wgurl = "/$main::CGIBIN/webglimpse.cgi?ID=$id&query=$query&cache=$cachefile&startfrom=$startfrom&maxfiles=$maxfiles&maxlines=$maxlines&maxchars=$maxchars$optlines";
		my $showend = $startfrom + $maxfiles;
		if ($numfiles < $showend) {
			$showend = $numfiles;
		}
		my $showstart = $startfrom +1;

		$retstring .= "<A HREF=\"$wgurl\">$showstart\-$showend</A> | ";
		$startfrom += $maxfiles;
		$groupcount++;
	}


	if ($startfrom < $numfiles) {
		$wgurl = "/$main::CGIBIN/webglimpse.cgi?ID=$id&query=$query&cache=$cachefile&startfrom=$startfrom&maxfiles=$maxfiles&maxlines=$maxlines&maxchars=$maxchars$optlines";
		$retstring .= "<A HREF=\"$wgurl\">next&gt;&gt;&gt;</A>";
	}

	$retstring =~ s/^(.*)\| $/$1/;
	$retstring .= "<p>\n";	

	return $retstring;

}


# Create an abbreviated search box that preserves the original options
# Allow user to change query string and do a new search.
sub makeNewQuery {
	my $self = shift;
	my ($indexdir, $maxfiles, $maxlines, 
	    $maxchars, $QS_file,$QS_linenums,$QS_age,$QS_case,
	    $QS_whole,$QS_errors, $QS_filter,$QS_query,$QS_rankby,$QS_ids,
	    $QS_autosyntax, $QS_autonegate, $QS_wordspan) = @_;

	my($wgurl, $retstring);

	# Strip any leading '/' from indexdir (as per Charlie Roche) --GV 9/13/99
	$indexdir =~ s/^\/+//;
	$indexdir = &Sanitize($indexdir);

	$wgurl = "/$main::CGIBIN/webglimpse.cgi/$indexdir";

	if ( -e $self->{archive_dir}."/$NEWQUERYBOX" && open(F, $self->{archive_dir}."/$NEWQUERYBOX")) {
		while(<F>) {
			$retstring .= $_;
		}
		$OutputVars{'HIDDENTAGS'} = "<INPUT TYPE=HIDDEN NAME=case VALUE=\"$QS_case\" >".
                "<INPUT TYPE=HIDDEN NAME=whole VALUE=\"$QS_whole\" >".
                "<INPUT TYPE=HIDDEN NAME=lines VALUE=\"$QS_linenums\" >".
                "<INPUT TYPE=HIDDEN NAME=errors VALUE=\"$QS_errors\" >".
                "<INPUT TYPE=HIDDEN NAME=age VALUE=\"$QS_age\" >".
                "<INPUT TYPE=HIDDEN NAME=maxfiles VALUE=\"$maxfiles\" >".
                "<INPUT TYPE=HIDDEN NAME=maxlines VALUE=\"$maxlines\" >".
                "<INPUT TYPE=HIDDEN NAME=maxchars VALUE=\"$maxchars\" >".
                "<INPUT TYPE=HIDDEN NAME=filter VALUE=\"$QS_filter\" >".
		"<INPUT TYPE=HIDDEN NAME=autosyntax VALUE=\"$QS_autosyntax\" >".
                "<INPUT TYPE=HIDDEN NAME=autonegate VALUE=\"$QS_autonegate\" >".
                "<INPUT TYPE=HIDDEN NAME=wordspan VALUE=\"$QS_wordspan\" >".
                "<INPUT TYPE=HIDDEN NAME=cache VALUE=\"yes\" >";
		if ($QS_ids ne '') {
			$OutputVars{'HIDDENTAGS'} .=
			"<INPUT TYPE=HIDDEN NAME=ids VALUE=\"$QS_ids\">";
		}

	} else {
		$retstring = "<table border=5><tr><td>\n";
		$retstring .=  "<FORM ACTION=\"$wgurl\" METHOD=GET>\n";
		$retstring .= $self->{newquery}." <INPUT NAME=\"query\" VALUE=\"$QS_query\">\n";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=case VALUE=\"$QS_case\" >";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=whole VALUE=\"$QS_whole\" >";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=lines VALUE=\"$QS_linenums\" >";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=errors VALUE=\"$QS_errors\" >";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=age VALUE=\"$QS_age\" >";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=maxfiles VALUE=\"$maxfiles\" >";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=maxlines VALUE=\"$maxlines\" >";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=maxchars VALUE=\"$maxchars\" >";
		$retstring .= "<INPUT TYPE=HIDDEN NAME=filter VALUE=\"$QS_filter\" >"; # Keep directory/neighborhood filtering
		$retstring .= "<INPUT TYPE=HIDDEN NAME=cache VALUE=\"yes\" >";

		if ($QS_ids ne '') {
			$retstring .=
			"<INPUT TYPE=HIDDEN NAME=ids VALUE=\"$QS_ids\">";
		}

		$retstring .= '<INPUT TYPE=SUBMIT  style="background-color:#C7C9B1"  VALUE="'.$self->{newquerybutton}."\">";	

#TODO: get rankby options from wgrankhits.cfg, do not hardcode!
		$retstring .= '
		Rank by:
		<SELECT name="rankby">
		<OPTION VALUE="DEFAULT">Combined score
		<OPTION VALUE="AGE">Most recent first
		<OPTION VALUE="LINKPOP">Link Popularity
		<OPTION VALUE="TITLE_AND_META">Title and Meta matches
		</SELECT>
		';

		$retstring .= "\n</FORM>\n";
		$retstring .= "\n</td></tr></table>\n";
	}


	&ReplaceVars(\$retstring);

	return($retstring);
}

sub GetRevision {	# Basically just so we won't get interpreter warnings
	return $REVISION;
}


sub FindSentences {
        my $self = shift;
        my ($sref, $pat) = @_;

        my @lines = split(/\./,$$sref);

        my $j = 0;
        my $indots = 0;
        while ($j <= $#lines) {
                if ($lines[$j] !~ /$pat/i) {
                        if ($indots) {
                                $lines[$j] = '';
                        } else {
                                $lines[$j] = '...';
                                $indots = 1;
                        }
                } else {
                        $indots = 0;
                }
                $j++;
        }
        $$sref = join('.',@lines);
}

sub HighlightMatches {
	my $self = shift;
	my ($stringref, $highlight, $opt_case) = @_;
	my $b = $self->{begin_highlight};
	my $e = $self->{end_highlight};
	
	# Make sure not to include spaces, possibly erroneously picked up
	# from a windows-edited version of wgoutput.cfg
	$b =~ s/\s+$//g;
	$e =~ s/\s+$//g;

	if ($opt_case) {
		$$stringref =~ s#$highlight#$b$&$e#gio;
	} else {
		$$stringref =~ s#$highlight#$b$&$e#go;
	}

#	$$stringref = $self->{begin_matched_line}.$$stringref.$self->{end_matched_line};
	return 1;
}

sub CenterOutput {
        my $self = shift;

	return(0) unless @_ == 3;	# check args


        my ($sref, $highlight, $maxchars) = @_;
	my ($matchpos, $startpos, $endpos);

	return(1) if (length($$sref) <= $maxchars); # no need to center, we will display whole string

	if ($$sref =~ /^(.*)$highlight/i) {
		$matchpos = length($1);
		$startpos = $matchpos - $maxchars/2;
		if ($startpos < 0) { $startpos = 0; }
		while (($startpos>0)&&(substr($$sref,$startpos,1) !~ /\W/)) {
			$startpos--;
		}

		if ($startpos + $maxchars < length($$sref)) {

			$endpos = $startpos + $maxchars;
			my $highlight_length = length($highlight);
			while (($endpos > ($matchpos + $highlight_length)) && (substr($$sref,$endpos,1) !~ /\W/)) {
				$endpos--;
			}
		} else {
			$endpos = length($sref);
		}
		$$sref = '...'.substr($$sref,$startpos,$endpos-$startpos).'...';
	}
}
