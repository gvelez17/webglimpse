package OutputTool;

use strict;

use LangUtils;

1;

# This package provides functions to output search results from Webglimpse

# Any replacement Output object must implement all of the following functions
# and provide the fields defined in _initialize

sub new {

	my $class = shift;
	my $self = {};
	bless $self, $class;
	$self->_initialize();
	return $self;
}

# Set any static fields we will need later
sub _initialize {
	my $self = shift;
	$self->{end_file_marker} = "</UL>\n";
}


sub makeInitialOutput {
	my $self = shift;
	my($pquery, $title, $QS_file, $QS_lines, $lang, $req) = @_;
	my($initial_output) = '';

	$initial_output .= "<HTML><HEAD><TITLE>Result for query \"$pquery\"</TITLE>\n";
	$initial_output .= &LangUtils::makeMetaTag($lang);
	$initial_output .= "</HEAD><BODY BGCOLOR=\"#FFFFFF\">\n";
	$initial_output .= "<center>";
	$initial_output .= $req;    # Condition of use: keep this required message in demo/edu versions
	$initial_output .= "<H1>Results for query \"$pquery\"</H1>\n";
	$initial_output .= "<h3>on: $title</h3>\n";

	if ($QS_file) {
		$initial_output .= "<i>Search on neighborhood of <tt>$title</tt></i>\n";
		$initial_output .= "</center><p>\n";
	} else {
		$initial_output .= "<i>Search on entire archive</i>\n";
		$initial_output .= "</center><p>\n";
	}

	if($QS_lines){
		$initial_output .= "File name (modification date), and list of matched lines (preceded by line numbers)<br>\n";
	}else{
		$initial_output .= "File name (modification date), and list of matched lines<br>\n";
	}

	return $initial_output;
}


sub limitMaxLines {
	my $self = shift;
	my($maxlines) = @_;

	return "<LI>Limit of $maxlines matched lines per file exceeded...\n".$self->{end_file_marker};
	
}


sub limitMaxFiles {
	my $self = shift;
	my($maxfiles) = @_;

	print $self->{end_file_marker};
	print "<H3>Limit of $maxfiles files exceeded.  Check the search options.</H3>\n";
}

sub makeEndHits {
	my $self = shift;
	print $self->{end_file_marker};
	return "<hr>";
}

sub makeLinkOutput {
	my $self = shift;
	my($link, $title, $date) = @_;
	my $retstring =	"<hr><b><A HREF=\"".$link."\">";
	$retstring .= $title."</A></b>, $date<br>\n";

	return $retstring;
}


sub makeStartFileDesc {
	my $self = shift;
	my($metadesc) = @_;
	my $retstring;

	if ($metadesc eq '') {
		$retstring = "\n<UL>\n";
	} else {
		$retstring = "<p>&nbsp;&nbsp;&nbsp;&nbsp;$metadesc <br>\n<UL>\n";
	}
	
	return $retstring;
}

sub makeEndFileDesc {
	my $self = shift;

        my $retstring = $self->{end_file_marker};                  	
	return $retstring;
}

sub makeJumpToLine {
	my $self = shift;
	my($linkto, $line, $string) = @_;

	my $retstring = "<LI><A HREF=\"$linkto\">\n" .
	  "line $line</A>:$string\n";

	return $retstring;
}


sub makeLine {
	my $self = shift;
	my($string) = @_;
	return "<LI>$string\n";
}

sub makeFinalOutput {
	my $self = shift;
	my($QS_query, $lcount, $fcount) = @_;
	my $retstring = "<HR>" ;
	$retstring .= "<H2>Summary for query <code>\"".$QS_query."\":</code></H2>\n" ;
	$retstring .= "<i><a href='http://webglimpse.net/'>WebGlimpse</a></i>\n";
	$retstring .= "search found ".$lcount." matches in ".$fcount." files<br>\n" ;
	$retstring .= "(Some matches may be to HTML tags which may not be shown.)\n";
	$retstring .= "</BODY></HTML>\n";

	return $retstring;
}



sub makeNextHits {
	# null routine to match real one in CustomOutputTool
}


sub HighlightMatches {
	my $self = shift;
	my ($stringref, $highlight, $opt_case) = @_;

	if ($opt_case) {
		$$stringref =~ s#$highlight#<B>$&</B>#gio;
	} else {
		$$stringref =~ s#$highlight#<B>$&</B>#go;
	}

	return 1;
}
