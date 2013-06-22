#!/usr/local/bin/perl

# converts html files into ascii by just stripping anything between
#  < and >
# written 4/21/96 by Michael Smith for WebGlimpse
#
# Added code to replace html codes for special chars with the
# characters themselves.  12/19/98 --GB
#
# Also add space in place of space-producing HTML tags
# 12/22/98 --GB


BEGIN{
        $WEBGLIMPSE_LIB = '|WEBGLIMPSE_LIB|';
        unshift(@INC, "$WEBGLIMPSE_LIB");  # Find the rest of our libs
} 
use wgFilter;


$SAVE_LINE_MARK = '_~_';


$carry=0;
$lineno = -1;
$incomplete_tag = 0;
$last_incomplete_tag = 0;

@lines = <STDIN>;

&wgFilter::SkipSection('<SCRIPT\s*[^>]*>','<\/SCRIPT>',\@lines);
&wgFilter::SkipSection('<STYLE\s*[^>]*>','<\/STYLE>',\@lines);

foreach $line (@lines){
	$lineno++;	# we need line number in ORIGINAL file for jump-to-line later

	# put returns back in in case user uploaded wrong
	$line =~ s/\r\n/\n/g;

# if we put in extra returns, not every line will start with <linenum>
# take out for now, consider putting back in with <linenum> inserted
#	$line =~ s/\r/\n/g;

	# now take out the ones we don't want!
	$line =~ s/([^>\.\s])\n/$1 /g;
	$line =~ s/(\s)\n/$1/g;

	if($carry==1){
		# remove all until the first >
		next if($line!~s/[^>]*>//);
		# if we didn't do next, it succeeded -- reset carry
		$carry=0;
	} 

	# save <TITLE, <A, <FRAME, <BASE tags
	$line =~ s/<(\/?)(title|a|frame|base)/#~#$1$2/ig;

	while($line=~s/(<[^\s>][^>]*>)/&addspace($1,$lineno)/ge){};

	if($line=~s/<[^\s>].*$//){
		$carry=1;
	}

	# put saved tags back, and check if the tag is complete
	if ($line =~ /#~#[^>]*$/) {
		$incomplete_tag = 1;
	} else {
		$incomplete_tag = 0;
	}
	$line =~ s/#~#(\/?)(title|a|frame|base)/<$1$2/ig;	

	# put lineno tags back
	$line =~ s/$SAVE_LINE_MARK([0-9]+)$SAVE_LINE_MARK/<$1>/g;

	# If we may have a html-encoded char, check and replace with actual char
	if ($line =~ /\&[^;]{2,6};/) {
		$line = &fixspecial($line);
	}
	if ($line) {
		if (! $last_incomplete_tag) {
			print "<$lineno>";
		}
		print $line;
	}
	if (!$last_incomplete_tag || $line =~ />/) {
		$last_incomplete_tag = $incomplete_tag;
#$last_incomplete_tag && warn "Line $line is incomplete\n";
	}
}


sub addspace () {

	$_ = shift;
	my $lineno = shift;
		
	# Check for tags that should NOT return a space.  Common tags first, then group alphabeticallly
	/(<\/?a[\s>])|(<\/?b>)|(<\/?i>)|(<\/?em>)|(<\/?font)/i && return '';
	/(<\/?strong)|(<\/?sup)|(<\/?sub)|(<\/?samp)|(<\/?strike)|(<\/?style)|(<\/?small)/i && return;
	/(<\/?big)|(<\/?base)|(<\/?cite)|(<\/?code)|(<\/?dfn)|(<\/?kbd)|(<\/?link)|(<\/?meta)/i && return;
	/(<\/?tt>)|(<\/?u>)|(<\/?var)/i && return '';

	# Check for tags that need a return for a record break.
	# insert <linenumber> at the beginning of the next line
	/(<\/?p[\s>])|(<\/?br[\s>])|(<\/?tr[\s>])|(<\/?hr[\s>])|(<\/?li[\s>])/i && return "\n$SAVE_LINE_MARK$lineno$SAVE_LINE_MARK";


	# Otherwise, put in a space
	return ' ';

}


sub fixspecial () {

	$_ = shift;

s/\&#160;/ /g;
s/\&nbsp;/ /g;
s/\&#161;/¡/g;
s/\&iexcl;/¡/g;
s/\&#162;/¢/g;
s/\&cent;/¢/g;
s/\&#163;/£/g;
s/\&pound;/£/g;
s/\&#164;/¤/g;
s/\&curren;/¤/g;
s/\&#165;/¥/g;
s/\&yen;/¥/g;
s/\&#166;/¦/g;
s/\&brvbar;/¦/g;
s/\&#167;/§/g;
s/\&sect;/§/g;
s/\&#168;/¨/g;
s/\&uml;/¨/g;
s/\&#169;/©/g;
s/\&copy;/©/g;
s/\&#170;/ª/g;
s/\&ordf;/ª/g;
s/\&#171;/«/g;
s/\&laquo;/«/g;
s/\&#172;/¬/g;
s/\&not;/¬/g;
s/\&#173;/\\/g;
s/\&shy;/\\/g;
s/\&#174;/®/g;
s/\&reg;/®/g;
s/\&#175;/¯/g;
s/\&macr;/¯/g;
s/\&#176;/°/g;
s/\&deg;/°/g;
s/\&#177;/±/g;
s/\&plusmn;/±/g;
s/\&#178;/²/g;
s/\&sup2;/²/g;
s/\&#179;/³/g;
s/\&sup3;/³/g;
s/\&#180;/´/g;
s/\&acute;/´/g;
s/\&#181;/µ/g;
s/\&micro;/µ/g;
s/\&#182;/¶/g;
s/\&para;/¶/g;
s/\&#183;/·/g;
s/\&middot;/·/g;
s/\&#184;/¸/g;
s/\&cedil;/¸/g;
s/\&#185;/¹/g;
s/\&sup1;/¹/g;
s/\&#186;/º/g;
s/\&ordm;/º/g;
s/\&#187;/»/g;
s/\&raquo;/»/g;
s/\&#188;/¼/g;
s/\&frac14;/¼/g;
s/\&#189;/½/g;
s/\&frac12;/½/g;
s/\&#190;/¾/g;
s/\&frac34;/¾/g;
s/\&#191;/¿/g;
s/\&iquest;/¿/g;
s/\&#192;/À/g;
s/\&Agrave;/À/g;
s/\&#193;/Á/g;
s/\&Aacute;/Á/g;
s/\&#194;/Â/g;
s/\&circ;/Â/g;
s/\&#195;/Ã/g;
s/\&Atilde;/Ã/g;
s/\&#196;/Ä/g;
s/\&Auml;/Ä/g;
s/\&#197;/Å/g;
s/\&ring;/Å/g;
s/\&#198;/Æ/g;
s/\&AElig;/Æ/g;
s/\&#199;/Ç/g;
s/\&Ccedil;/Ç/g;
s/\&#200;/È/g;
s/\&Egrave;/È/g;
s/\&#201;/É/g;
s/\&Eacute;/É/g;
s/\&#202;/Ê/g;
s/\&Ecirc;/Ê/g;
s/\&#203;/Ë/g;
s/\&Euml;/Ë/g;
s/\&#204;/Ì/g;
s/\&Igrave;/Ì/g;
s/\&#205;/Í/g;
s/\&Iacute;/Í/g;
s/\&#206;/Î/g;
s/\&Icirc;/Î/g;
s/\&#207;/Ï/g;
s/\&Iuml;/Ï/g;
s/\&#208;/Ð/g;
s/\&ETH;/Ð/g;
s/\&#209;/Ñ/g;
s/\&Ntilde;/Ñ/g;
s/\&#210;/Ò/g;
s/\&Ograve;/Ò/g;
s/\&#211;/Ó/g;
s/\&Oacute;/Ó/g;
s/\&#212;/Ô/g;
s/\&Ocirc;/Ô/g;
s/\&#213;/Õ/g;
s/\&Otilde;/Õ/g;
s/\&#214;/Ö/g;
s/\&Ouml;/Ö/g;
s/\&#215;/×/g;
s/\&times;/×/g;
s/\&#216;/Ø/g;
s/\&Oslash;/Ø/g;
s/\&#217;/Ù/g;
s/\&Ugrave;/Ù/g;
s/\&#218;/Ú/g;
s/\&Uacute;/Ú/g;
s/\&#219;/Û/g;
s/\&Ucirc;/Û/g;
s/\&#220;/Ü/g;
s/\&Uuml;/Ü/g;
s/\&#221;/Ý/g;
s/\&Yacute;/Ý/g;
s/\&#222;/Þ/g;
s/\&THORN;/Þ/g;
s/\&#223;/ß/g;
s/\&szlig;/ß/g;
s/\&#224;/à/g;
s/\&agrave;/à/g;
s/\&#225;/á/g;
s/\&aacute;/á/g;
s/\&#226;/â/g;
s/\&acirc;/â/g;
s/\&#227;/ã/g;
s/\&atilde;/ã/g;
s/\&#228;/ä/g;
s/\&auml;/ä/g;
s/\&#229;/å/g;
s/\&aring;/å/g;
s/\&#230;/æ/g;
s/\&aelig;/æ/g;
s/\&#231;/ç/g;
s/\&ccedil;/ç/g;
s/\&#232;/è/g;
s/\&egrave;/è/g;
s/\&#233;/é/g;
s/\&eacute;/é/g;
s/\&#234;/ê/g;
s/\&ecirc;/ê/g;
s/\&#235;/ë/g;
s/\&euml;/ë/g;
s/\&#236;/ì/g;
s/\&igrave;/ì/g;
s/\&#237;/í/g;
s/\&iacute;/í/g;
s/\&#238;/î/g;
s/\&icirc;/î/g;
s/\&#239;/ï/g;
s/\&iuml;/ï/g;
s/\&#240;/ð/g;
s/\&ieth;/ð/g;
s/\&#241;/ñ/g;
s/\&ntilde;/ñ/g;
s/\&#242;/ò/g;
s/\&ograve;/ò/g;
s/\&#243;/ó/g;
s/\&oacute;/ó/g;
s/\&#244;/ô/g;
s/\&ocirc;/ô/g;
s/\&#245;/õ/g;
s/\&otilde;/õ/g;
s/\&#246;/ö/g;
s/\&ouml;/ö/g;
s/\&#247;/÷/g;
s/\&divide;/÷/g;
s/\&#248;/ø/g;
s/\&oslash;/ø/g;
s/\&#249;/ù/g;
s/\&ugrave;/ù/g;
s/\&#250;/ú/g;
s/\&uacute;/ú/g;
s/\&#251;/û/g;
s/\&ucirc;/û/g;
s/\&#252;/ü/g;
s/\&uuml;/ü/g;
s/\&#253;/ý/g;
s/\&yacute;/ý/g;
s/\&#254;/þ/g;
s/\&thorn;/þ/g;
s/\&#255;/ÿ/g;
s/\&yuml;/ÿ/g;
s/\&#34;/"/g;
s/\&quot;/"/g;

# Do the ampersand last, so it won't affect the other substitutions
s/\&#38;/\&/g;
s/\&amp;/\&/g;

	return $_;
}
