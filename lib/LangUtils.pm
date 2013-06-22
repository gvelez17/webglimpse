#!/usr/local/bin/perl

package LangUtils;

# generic language utiltities, written for Webglimpse but may be of general use

%CHARSET = (
	'arabic' => 'windows-1256',
        'hebrew' => 'windows-1255',
        'russian' => 'windows-1251',
	'dutch'=> 'windows-1252',
        'russiank' => 'koi-8',
	'bulgarian' => 'windows-1251',
	'polish'  => 'ISO-8859-2',
	'romanian' => 'ISO-8859-2',
	'french' => 'ISO-8859-15'
);

%PROPERNAME = (
	'arabic' => "Arabic",
	'bulgarian' => "Bulgarian",
	'english' => "English",
	'estonian' => 'Eesti Keeles',
	'spanish' => "Español",
	'portuguese' => "Português",
	'hebrew' => "Hebrew",
	'french' => "Français",
	'german' => "Deutsch",
	'italian' => "Italiano",
	'norwegian' => "Norsk",
	'dutch' => "Nederlandse",
	'polish' => "Polsku",
	'finnish' => "Suomi",
	'romanian' => "Romanian"
);


%CODES = (
	'english' => '',	# don't require special code for english
	'arabic' => 'ar_AR',
        'hebrew' => 'iw_IL',
	'dutch' => 'nl_NL',
        'spanish' => 'es_ES',
	'estonian' => 'ee_EE',
	'italian' => 'it_IT',
	'portuguese' => 'pt_BR',	# We have Brazilian Portuguese translation
        'german' => 'de_DE',
        'russian' => 'ru_RU',
        'russiank' => 'ru_RU',
	'finnish' => 'fi_FI',
	'french' => 'fr_FR',
	'norwegian' => 'no_NO',
	'polish' => 'pl_PL',
	'bulgarian' => 'bg_BG'
);

%MONTHS = (
	'Jan' => 1,
	'Feb' => 2,
	'Mar' => 3,
	'Apr' => 4,
	'May' => 5,
	'Jun' => 6,
	'Jul' => 7,
	'Aug' => 8,
	'Sep' => 9,
	'Oct' => 10,
	'Nov' => 11,
	'Dec' => 12
);


1;


sub GetCode {
	my $lang = shift;
	my $ret = $CODES{$lang} || '';
	return $ret;
}

sub GetProperName {
	my $lang = shift;
	if ($lang eq '') { $lang = 'english'; }

	my $ret = $PROPERNAME{$lang} || '';

	return $ret;
}

sub makeMetaTag {
	my $lang = shift;

	my $retstring = '';

	return '' if ((! defined ($lang)) || ($lang eq '') || ($lang eq 'english'));

	$lang = lc($lang);

	$retstring = '<META http-equiv="Content-Type" content="text/html; charset='.$CHARSET{$lang}.'"></META>';

	return $retstring;
}


sub ConvertDate {

	my ($date, $lang) = @_;
	my $mon;
	
	return $date if ((! defined ($lang)) || ($lang eq '') || ($lang eq 'english'));

     # For Russian month name in date.  (AA - 18/6/03)
     # convert to Cyrillic ISO to Cyrillic Windows (1251) Characters
     if ($lang eq 'russian') {
		my $t_date_iso = substr($date,0,3);
		my @t_ascii = unpack("C*", $t_date_iso);
		foreach my $t_char (@t_ascii) {$t_char += 16;}
		my $t_date_1521 = pack("C*",@t_ascii);
		substr($date,0,3) = $t_date_1521; 
	    
            return $date;
     }

	# For non-English languages, return date as DD/MM/YYYY
	# maybe should make this option in CustomOutputTools rather than fixed

	($date =~ /(\w\w\w)\s+(\d+)\s+(\d+)/) || return($date);

	$mon = $MONTHS{$1} || return($date);
	my $nicedate = "$2/$mon/$3";

	return $nicedate;
}
