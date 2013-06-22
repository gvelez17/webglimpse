#!/usr/local/bin/perl

package wgFilter;

1;

# For now assume tags are on separate lines :-(
sub SkipTag {
	my $starttag = shift;
	my $linesref = shift;

$KEEPLINKS = 1;

	my $tag = '';
	if ($starttag =~ /^<([^\s>]+)/i) {
		$tag = $1;
	} else {
		return 0;
	}
	
	$cnt = 0;
	for ($j=0; $j<=$#$linesref; $j++) {
		if ($linesref->[$j] =~ s/^(.*)$starttag/$1/i) {
			$cnt = 1;
			next;
		}
		if ($linesref->[$j] =~ /<$tag/) {
			$cnt++;	
		}
		if ($cnt && ($linesref->[$j] =~ s/<\/$tag>(.*)$/$1/i)) {
			$cnt--;
		}
		if ($cnt) {
			if ($KEEPLINKS && ($linesref->[$j] =~ /(<a href[^>]+>)/i)) {
				$linesref->[$j] = "$1</A>";
			} else {
				$linesref->[$j] = '';
			}
		}
	}
	return 1;
}


# For now assume tags are on separate lines :-(
sub SkipSection {
	my $startpat = shift;
	my $endpat = shift;
	my $linesref = shift;

$KEEPLINKS = 1;

	$insect = 0;
	for ($j=0; $j<=$#$linesref; $j++) {
		if ($linesref->[$j] =~ /$startpat/i) {
			$insect = 1;
		}
		if ($insect) {
			if ($linesref->[$j] =~ /$endpat/i) {
				$insect = 0;	
			}
			if ($KEEPLINKS && ($linesref->[$j] =~ /(<a href[^>]+>)/i)) {
				$linesref->[$j] = "$1</A>";
			} else {
				$linesref->[$j] = '';
			}
		}
	}
	return 1;
}


sub KillPhrases {
	my $phraseref = shift;
	my $linesref = shift;
	
	for ($j=0; $j<=$#$linesref; $j++) {

		foreach my $phrase (@$phraseref) {
			$phrase = &escape($phrase);
			$linesref->[$j] =~ s/$phrase//g;
		}
	}
	return 1;
}

# ugly, ugly, ugly...
# For now assume tags are on separate lines before and after the munged section :-(
sub MungeSection {
	my $startpat = shift;
	my $endpat = shift;
	my $replacepat = shift;
	my $linesref = shift;

	my $insect = 0; my $insertline = 0;  my $string = '';
	for ($j=0; $j<=$#$linesref; $j++) {
		if (! $insect && ($linesref->[$j] =~ /$startpat/)) {
			$insect = 1; next;
		}
		if ($linesref->[$j] =~ /$endpat/) {
			if ($insertline) {
				$replacepat =~ s/\[STRING\]/$string/;
				$linesref->[$insertline] = $replacepat."\n";
			}
			$insect = 0; last;
		}
		if ($insect) {
			$insertline || ($insertline = $j);
			while(chomp $string){};
# ack - remove all tags if you want, these two are not really enough
			$string =~ s/<br>//ig;
			$string =~ s/<p>//ig;
			$string .= $linesref->[$j];		
			$linesref->[$j] = '';
		}
	}
	return 1;
}





# TODO: use existing routine or cookbook for this
sub escape {
	my $s = shift;
	
	$s =~ s/\&/\\\&/;
	$s =~ s/\@/\\\@/;
	$s =~ s/\$/\\\$/;
	$s =~ s/\-/\\\-/;
	$s =~ s/\[/\\\[/;	
	$s =~ s/\]/\\\]/;
	$s =~ s/\^/\\\^/;
	$s =~ s/\*/\\\*/;
	$s =~ s/\+/\\\+/;
	$s =~ s/\./\\\./;
	
	return $s;
}
	
