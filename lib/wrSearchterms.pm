#!/usr/bin/perl

package wrSearchterms;

# wrSearchterms collects routines to extract
# strings from plane text, that allow unique 
# identification of the text via a scientific 
# paper database like Pubmed.
#
# Functions:
#
#       find_DOI
#       find_Journal
#       replace_special_characters
#       find_headlines
#       remove_insignificant_lines
#       suggest_title
#       SVM_RBF_Kernel
#       SVM_Classifier
#       SVM_test_Classifier
#       suggest_authors
#       remove_noninformative_searchterms
#       compile_searchterms
#       get_searchterms
#
#       
# (c) Thomas Tuechler 2006
#     Boku Bioinformatics, Vienna, Austria

use strict;
use warnings;


sub find_DOI {

    my $str  = shift;
    my $term = shift;

    my ($doi, $doi_pre, $doi_suf, $i);

    #http://www.doi.org: <DIR>.<REG>/<DSS>
    if ( $$str =~ m,doi[:/]?\s*10\.\d+/,i ) {

	($doi) = ($$str =~ m,doi[:\/]?\s*(10\.\d+\/[^\x00-\x1F\x80-\x9F]+),i);
	push(@$term, $doi);

	($doi) = ($$str =~ m,doi[:\/]?\s*(10\.\d+\/[^\s\x00-\x1F\x80-\x9F]+),i);
	$doi =~ s/\W*$//;
	push(@$term, $doi);

	return "DOI: $doi\n";

    #PNAS: "doi 10.1087 pnas.34221 \n" (slashes lost by pdftotext)
    } elsif ($$str =~ m,doi:?\s*10\.\d+,i) {

	($doi_pre, $doi_suf) = ($$str =~ /doi:*\s*(10.\d+)\s*(.*)/i);

	$doi_suf =~ /\s\s/g;
        $doi_suf =~ /[\x00-\x1F\x80-\x9F]/g unless (pos($doi_suf));

	if (pos($doi_suf)) {
	    $doi_suf = substr($doi_suf, 0, (pos($doi_suf)-1));
	}

	$doi_suf =~ s/ /\//g;
	$doi = $doi_pre . "/" . $doi_suf;
	push(@$term, $doi);

	return "DOI: $doi\n";

    #NOTE: if pdftotext loses slashes and if also a proper delimiter at the end is
    #      lost, then doi retrieval ist lost just as well. we can only transform:
    #      "doi 10.1037 dss-string  crap" -> "10.1037/dss-string" !

    #Science " 10.1124/science.1234231 " (doi is usually at the end of the paper)
    } elsif ( $$str =~ m,\s+10\.\d+, ) {
	
	$i = 0;
	while ( $$str =~ m,\s+10\.\d+,g && $i < 5 ) {
	    $i++;

	    ($doi) =  ($$str =~ m,\s+(10\.\d+\/\S+),);
	    $doi   =~ s,\W+$,,;
	    push(@$term, $doi);
	}

    } else {

	return 'DOI: not found.';
    }
}



sub find_Journal {
    
    my $str  = shift;
    my $term = shift;

    my ($day, $month, $year, $date, $journal);
    my %months = (january => "01",
		  febraury => "02",
		  march => "03",
		  april => "04",
		  may => "05",
		  june => "06",
		  july => "07",
		  august => "08",
		  september => "09",
		  october => "10",
		  november => "11",
		  december => "12");

    #journal specific extractable searchpatterns
    
    #NATURE | VOL 418 | 22 AUGUST 2002
    if ( $$str =~ m/NATURE\s+\|\s+VOL\s+(\d+)\s+\|\s+(\d{1,2})\s+(\w+)\s+(\d{4})/i ) {
	$day     = $2;
	$day     = '0'.$day unless ( length($day) > 1 );
	$month   = lc($3);
	$month   = $months{"$month"};
	$year    = $4;
	$date    = $year.'/'.$month.'/'.$day;
	$journal = "nature\[Jour\] $1\[vi\] $date\[dp\]";
    }

    #SCIENCE VOL 298 4 OCTOBER 2002
    elsif ( $$str =~ m/SCIENCE\s+VOL\s+(\d+)\s+(\d{1,2})\s+(\w+)\s+(\d{4})/i ) {
	$day     = $2;
	$day     = '0'.$day unless ( length($day) > 1 );
	$month   = lc($3);
	$month   = $months{"$month"};
	$year    = $4;
	$date    = $year.'/'.$month.'/'.$day;
	$journal = "science\[Jour\] $1\[vi\] $date\[dp\]";
    }

    #SCIENCE VOL 298 4 OCTOBER 2002
    elsif ( $$str =~ m/(\d{1,2})\s+(\w+)\s+(\d{4})\s+VOL\s+(\d+)\s+SCIENCE/i ) {
	$day     = $1;
	$day     = '0'.$day unless ( length($day) > 1 );
	$month   = lc($2);
	$month   = $months{"$month"};
	$year    = $3;
	$date    = $year.'/'.$month.'/'.$day;
	$journal = "science\[Jour\] $4\[vi\] $date\[dp\]";
    }

    push(@$term, $journal) if ($journal);

    return 1;

}



sub replace_special_characters {
    
    my $str = shift;

    return 0 unless ( $$str );

    $_ = $$str;
    
    s/\x8A/S/g;   s/\xCF/I/g;   s/\xE8/e/g;      
    s/\x8C/Oe/g;  s/\xD0/D/g;   s/\xE9/e/g;      
    s/\x8E/Z/g;	  s/\xD1/N/g;   s/\xEA/e/g;      
    s/\x99//g;	  s/\xD2/O/g;   s/\xEB/e/g;      
    s/\x9A/s/g;	  s/\xD3/O/g;   s/\xEC/i/g;      
    s/\x9C/oe/g;  s/\xD4/O/g;   s/\xED/i/g;      
    s/\x9E/z/g;	  s/\xD5/O/g;   s/\xEE/i/g;      
    s/\x9F/Y/g;	  s/\xD6/Oe/g;  s/\xEF/i/g;      
    s/\xAD/\-/g;  s/\xD7/x/g;   s/\xF0/d/g;    
    s/\xC0/A/g;   s/\xD8/O/g;   s/\xF1/n/g;    
    s/\xC1/A/g;   s/\xD9/U/g;   s/\xF2/o/g;    
    s/\xC2/A/g;   s/\xDA/U/g;   s/\xF3/o/g;    
    s/\xC3/A/g;   s/\xDB/U/g;   s/\xF4/o/g;    
    s/\xC4/Ae/g;  s/\xDC/Ue/g;  s/\xF5/o/g;    
    s/\xC5/A/g;   s/\xDD/Y/g;   s/\xF6/oe/g;   
    s/\xC6/Ae/g;  s/\xDF/ss/g;  s/\xF8/o/g;    
    s/\xC7/C/g;   s/\xE0/a/g;   s/\xF9/u/g;    
    s/\xC8/E/g;   s/\xE1/a/g;   s/\xFA/u/g;    
    s/\xC9/E/g;   s/\xE2/a/g;   s/\xFB/u/g;    
    s/\xCA/E/g;   s/\xE3/a/g;   s/\xFC/ue/g;   
    s/\xCB/E/g;   s/\xE4/ae/g;  s/\xFD/y/g;    
    s/\xCC/I/g;   s/\xE5/a/g;   s/\xFF/y/g;    
    s/\xCD/I/g;   s/\xE6/ae/g;  
    s/\xCE/I/g;   s/\xE7/c/g;
    
    #ligatures and hyphenation
    s/\x83/f/g;   s/\x88//g;    s/\xA0//g;
    s/\xad//g;    s/\xAE/fi/g;  s/\xAF/fl/g;
	  
    $$str = $_;

    return 1;
}



sub find_headlines
{
    my $str   = shift;
    my $head  = shift;
    my $para  = shift;
    my $first = shift;

    my $i = 0;

    $$str =~ s/\n[\ \t\f\r]+/\n/g;            #remove leading whitespaces
    $$str =~ s/[\ \t\f\r]+\n/\n/g;            #remove lines of only whitespaces
    $$str =~ s/\n\n\n+/\n\n/g;                #remove 3 or more consecutive blank lines
    $$str =~ s/(.+\n.+\n)\n(.+\n.+\n)/$1$2/g; #remove blank lines, if not around a headline
    $$str =~ s/(.+\n.+\n)\n(.+\n.+\n)/$1$2/g; #the second round is necessary to remove all
                                              #non-headline surrounding \n\n's

    #find headline with blank line before
    while ( $$str =~ m/\n\n(.+)\n/g ) {
	push(@$head, $1);
    }
    
    #find paragraph starting line and get first sentence
    while ( $$str =~ m/\n\n(.+?)[\.\n]/g ) {
	push(@$para, $1);
    }
    
    #get first ten lines
    while ( $$str =~ m/([^\n]+)\n/g && $i < 10 ) {
	push(@$first, $1);
	$i++;
    }

    return 1;
}



sub remove_insignificant_lines
{
    my $arr = shift;

    my @buf = ();
    
    foreach (@$arr) {

	if (
	       ( length($_) > 5 )                                  #at least 5 characters
	    && ( /\S+\s+\S+/ )                                     #at least 2 words
	    && ( /[A-Za-z]{4,}/ )                                  #at least 1 word with more than 4 letters
	    && ( !/(vol|volume).*((19[56789][0-9])|(200[0-9]))/i ) #no volume number with date
            && ( !/references and notes/i )
	    && ( !(/author/i && ( /view/i  || /opinion/i ) ) )     #no "authors view doesnt..."
	    && ( !/\d{1,6}[\s\(\),;:-]{1,3}\d{1,6}[\s\(\),;:-]{1,3}\d{1,6}/ )
	                                                           #no references
	    && ( !/(correspondence|received|accepted|published)/i )#no technical information
	    && ( !/(departement|university|(research center))/i )  #no addresses
	    && ( !/(journal|vol\. |volume|vol \d|www\.)/i )        #no journal header
	    && ( !/(e\-mail|\@)/i )                                #no contact address
	    && ( !/(inc\.)/i )                                     #no company address
	    && ( !/^\*/ )                                          #no footnote
	    && ( !/^fig(\.|ure|\s)/i )                             #no figure caption
	    && ( !/^box /i )                                       #no figure caption
	    && ( !/www\./ )                                        #no internet address
	    )
	{
	    push(@buf, $_);
	}
    }
    
    @$arr = @buf;
}



sub suggest_title
{
    my $head = shift;

    my @buff = ();
    my $i = 0;

    foreach (@$head) {
	if (    
	       ( length($_) > 20 )                                  #no lines shorter than 20 characters
	    && ( length($_) < 180 )                                 #no lines longer than 180 characters
	    && ( /\S+\s+\S+\s+\S+/ )                                #at least 3 words
	    && ( /[A-Za-z]{4}\s+.*?[A-Za-z]{4}/ )                   #at least 2 words with more than 4 letters
	    && ( $_ ne 'BIOINFORMATICS APPLICATIONS NOTE' )         #no such bioinformatics headline
	    && ( !/open access\s*/)                                 #no such headline
	    && ( $i < 5 )                                           #at most 5 suggestions
	    )
	{
	    push(@buff, $_);
	    $i++;
	}
    }

    @$head = @buff;
}



sub SVM_RBF_Kernel {
    
    my $SVdatum = shift;
    my $dims    = shift;
    my $Xdatum  = shift;

    #compute the RBF kernalized dotproduct
    my ($norm_dist, $Kerneled_dotproduct, $i, $d);
    
    $norm_dist = 0;

    for ($i = 0; $i < $dims; $i++) {
	$d = $$SVdatum[$i] - $$Xdatum[$i];
	$norm_dist += $d * $d;
    }

    $Kerneled_dotproduct = exp( -sqrt($norm_dist) / 25);

    return $Kerneled_dotproduct;
}



sub SVM_Classifier {

    my $Xdatum  = shift;
    my $Xclass;
    
    #define SVs and parameters of the optimized classifier
    my (@SVdata, @SVclass, $SVs, $dims, @ALPHA, $B);

                # ccwc      cwcwc     icwc      fcwc      hd        ac        sc,       csc
    @SVdata = ( # 1         2         3         4         5         6         7         8
  		[ 0.31429,  0.74286,  0.05714,  0.28571,  0.00000,  0.00000,  1.00000,  0.00000 ], #  1
  		[ 0.33333,  0.66667,  0.05556,  0.33333,  2.00000,  0.00000,  0.00000,  0.00000 ], #  2
  		[ 0.16667,  0.66667,  0.16667,  0.00000,  2.00000,  0.00000,  0.00000,  0.00000 ], #  3
  		[ 0.30769,  0.53846,  0.15385,  0.30769,  1.00000,  0.00000,  0.00000,  0.00000 ], #  4
  		[ 0.14286,  0.57143,  0.14286,  0.00000,  3.00000,  0.00000,  0.00000,  0.00000 ], #  5
  		[ 0.14286,  0.57143,  0.28571,  0.14286,  2.00000,  0.00000,  1.00000,  0.00000 ], #  6
  		[ 0.00000,  1.00000,  0.00000,  0.00000,  2.00000,  0.00000,  0.00000,  0.00000 ], #  7
  		[ 0.16667,  0.66667,  0.16667,  0.00000,  0.00000,  0.00000,  0.00000,  0.00000 ], #  8
  		[ 0.28571,  0.57143,  0.28571,  0.28571,  2.00000,  0.00000,  0.00000,  0.00000 ], #  9
  		[ 0.00000,  0.00000,  0.00000,  0.00000,  1.00000,  1.00000,  0.00000,  0.00000 ], # 10
  		[ 0.03297,  0.05861,  0.00000,  0.02198,  2.00000,  0.00000,  0.00000,  1.00000 ], # 11
  		[ 0.00000,  0.75000,  0.00000,  0.00000,  0.00000,  0.00000,  0.00000,  1.00000 ], # 12
  		[ 0.00000,  0.75000,  0.00000,  0.00000,  1.00000,  0.00000,  0.00000,  0.00000 ], # 13
  		[ 0.00000,  0.08333,  0.16667,  0.00000,  0.00000,  0.00000,  0.00000,  0.00000 ], # 14
  		[ 0.33333,  0.00000,  0.00000,  0.00000,  0.00000,  1.00000,  0.00000,  0.00000 ], # 15
  		[ 0.07438,  0.07438,  0.00826,  0.01653,  3.00000,  0.00000,  0.00000,  0.00000 ], # 16
  		[ 0.00000,  0.50000,  0.00000,  0.00000,  1.00000,  0.00000,  0.00000,  0.00000 ], # 17
  		[ 0.00000,  0.50000,  0.00000,  0.00000,  1.00000,  0.00000,  0.00000,  0.00000 ], # 18
  		[ 0.00000,  1.00000,  0.00000,  0.00000,  0.00000,  0.00000,  0.00000,  0.00000 ], # 19
  		[ 0.17045,  0.11364,  0.00000,  0.01136,  0.00000,  0.00000,  0.00000,  0.00000 ], # 20
  		[ 0.00000,  0.16667,  0.16667,  0.00000,  1.00000,  0.00000,  0.00000,  0.00000 ], # 21
  		[ 0.00000,  0.00000,  0.72727,  0.00000,  0.00000,  1.00000,  0.00000,  0.00000 ], # 22
  		[ 0.07725,  0.09442,  0.02575,  0.03863,  1.00000,  0.00000,  0.00000,  0.00000 ]  # 23
		);

     @SVclass = (1,  #  1
		 1,  #  2
		 1,  #  3
		 1,  #  4
		 1,  #  5
		 1,  #  6
		 1,  #  7
		 1,  #  8
		 1,  #  9
		 -1, # 10
		 -1, # 11
		 -1, # 12
		 -1, # 13
		 -1, # 14
		 -1, # 15
		 -1, # 16
		 -1, # 17
		 -1, # 18
		 -1, # 19
		 -1, # 20
		 -1, # 21
		 -1, # 22
		 -1  # 23
		 );

    $SVs     = 23;
    $dims    = 8;

    @ALPHA   = ( 16.67345,    #  1
		  7.0286e-8,  #  2
		 15.51093,    #  3
		 51.94187,    #  4
		 37.10105,    #  5
		  6.05130,    #  6
		 12.77613,    #  7
		 91.97253,    #  8
		  2.5172e-7,  #  9
		  1.0137e-8,  # 10
		  8.55429,    # 11
		  6.49637,    # 12
		 40.37248,    # 13
		  8.24446,    # 14
		  2.11942,    # 15
		 43.82212,    # 16
		  6.62568,    # 17
		  6.62568,    # 18
		 59.51791,    # 19
		 24.33495,    # 20
		 11.42718,    # 21
		  7.16755,    # 22
		  6.71919     # 23
		 );

    $B       = -0.48428;

    #project the new datum $Xdatum
    my ($Kerneled_dotproduct, $Sigma, $i);

    $Sigma = 0;

    for ($i = 0; $i < $SVs; $i++) {
	$Kerneled_dotproduct =  &SVM_RBF_Kernel($SVdata[$i], $dims, $Xdatum);
	$Sigma += $SVclass[$i] * $ALPHA[$i] * $Kerneled_dotproduct;
    }

    $Sigma += $B;

    #decide to which class $Xdatum belongs
    if ( $Sigma > 0 ) {
	$Xclass = 1;

    } elsif ( $Sigma < 0 ) {
	$Xclass = -1;

    } else {
	$Xclass = 0;
    }

    return $Xclass;
}



sub SVM_test_Classifier {

    my @Xdata = (
	      # negative testset ( true class = -1 )
	      [0.10625,  0.05312,  0.00000,  0.02187,  1.00000,  0.00000,  0.00000,  1.00000],
	      [0.08397,  0.04198,  0.03817,  0.04962,  6.00000,  0.00000,  0.00000,  0.00000],
	      [0      ,  0      ,  0      ,  0      ,  0      ,  1      ,  0      ,  0      ],
	      [0.08264,  0.04132,  0.02479,  0.04959,  0.00000,  0.00000,  0.00000,  1.00000],
	      [0.28571,  0.07143,  0.00000,  0.42857,  1.00000,  0.00000,  0.00000,  0.00000],
	      [0.25000,  0.00000,  0.12500,  0.00000,  0.00000,  0.00000,  0.00000,  0.00000],
	      [0.00000,  0.75000,  0.00000,  0.00000,  0.00000,  0.00000,  0.00000,  1.00000],
	      [0.09091,  0.04545,  0.04545,  0.04545,  0.00000,  0.00000,  0.00000,  1.00000],
	      [0.07463,  0.16418,  0.00000,  0.01493,  2.00000,  0.00000,  0.00000,  1.00000],
	      [0      ,  0      ,  0      ,  0      ,  1      ,  1      ,  0      ,  0      ],
	      
	      # positive testset ( true class = 1 )
	      [0.20000,  0.60000,  0.30000,  0.30000,  1.00000,  0.00000,  0.00000,  0.00000],
	      [0.25000,  0.75000,  0.12500,  0.25000,  2.00000,  0.00000,  1.00000,  0.00000],
	      [0.46154,  0.76923,  0.15385,  0.38462,  2.00000,  0.00000,  1.00000,  0.00000],
	      [0.39286,  0.64286,  0.32143,  0.32143,  2.00000,  0.00000,  0.00000,  0.00000],
	      [0.36364,  0.90909,  0.00000,  0.27273,  2.00000,  0.00000,  0.00000,  0.00000],
	      [0.33333,  0.66667,  0.25000,  0.33333,  2.00000,  0.00000,  1.00000,  0.00000],
	      [0.37037,  0.00000,  0.18519,  0.40741,  2.00000,  1.00000,  1.00000,  0.00000],
	      [0.36000,  0.80000,  0.20000,  0.40000,  2.00000,  0.00000,  1.00000,  0.00000],
	      [0.36364,  0.81818,  0.00000,  0.36364,  1.00000,  0.00000,  0.00000,  0.00000],
	      [0.33333,  0.66667,  0.25000,  0.33333,  2.00000,  0.00000,  1.00000,  0.00000]
	      );

    my @Xclass = (-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
		   1, 1, 1, 1, 1, 1, 1, 1, 1, 1);
    my $n      = $#Xclass + 1;
    
    my ($i, $Xtrue, $Xguess, @Xdatum, $RightTag);

    print "Testing the classifier with $n known samples other than the support vectors.\n";
    
    for ($i = 0; $i < $n; $i++) {
	@Xdatum = @{$Xdata[$i]};
	$Xtrue = $Xclass[$i];
	$Xguess = &SVM_Classifier(\@Xdatum);
	$RightTag++ if ($Xguess == $Xtrue);
    }
    
    print "Correct classification for $RightTag out of $n.\n";

}



sub suggest_authors
{
    my $arr  = shift;
    my $str  = shift;
    my $auth = shift;

    my @fullname = ();
    my @cutname  = ();
    my @newname  = ();
 
    my ($i, $z, $wc, $cwc, $ac, $cc, $fc, $ic, $hdb, $hda, $hdbc, $hdac, $hd, $sc, $csc);
    my ($wccc, $cwcwc, $icwc, $fcwc, $score, $n, $l, $m, $init, $names);
    my ($ccwc2, $cwcwc2, $icwc2, $fcwc2, $hd2);

    $i = 0;

    foreach (@$arr) {
	$z = $_;

	s/^\s*<\w\w>\s+//;           #remove leading special characters
	s/^\s*[^A-Za-z]+\s+//;       #remove leading non-words
	s/(\S)\s+(\S)/$1  $2/g;      #introduce double blanks for correct word counts
	s/(\S)\s(\S)/$1  $2/g;       #repeat to get all of them
	s/ (jr|sr)[ \.]/ /gi;        #remove juniors and seniors...
	s/ (jr|sr),/,/gi;            #...but do not cut the comma
	s/ \d+(st|nd|rd|th) / /gi;   #remove aristoracy...
	s/ \d+(st|nd|rd|th),/,/gi;   #...but do not cut the comma

	#comma count
	$cc = 0;
	$cc++ while ( /,/g );
	$cc++ while ( / and /g );
	$cc++ while ( / & /g );

	#footnote count (footnotes like word<..>1,2)
	$fc = 0; 
	$fc++ while ( /([A-Za-z]+) ?[,<\d\*\x86\x87\xA7\xB2\xB3\xB6\xB9]\S*? /g );
	$fc++ while ( /([A-Za-z]+) ?[,<\d\*\x86\x87\xA7\xB2\xB3\xB6\xB9]\S*$/g );

	#initials count
	$ic = 0; 
	$ic++ while ( / ([A-Z]\.?){1,3}[ \,]/g );
	$ic++ while ( / ([A-Z]\.?){1,3}$/g );

	#word count
	$wc = 0;
	$wc++ if ( /^\S+\s/ );
	$wc++ while ( /\s\S+\s/g );
	$wc++ if ( /\s\S+$/ );

	#capital word count,  ie. Names (not NAMES!)
	$cwc= 0;
	$cwc++ if ( /^[A-Z][a-z]/g );
	$cwc++ while ( / [A-Z][a-z]/g );

	#all words capital (except footnotes)
	$ac = 0;
	$ac = 1 unless ( /(\s|[A-Z])[a-z]/ );

	#count the stars in a line (indicative for authors)
	$sc = 0;
	$sc = 1 if ( /\*/g );

	#count colons: and slashes/ in a line (indicative for non-authors)
	$csc = 0;
	$csc = 1 if ( /[\/\:]/ );

	#compute distance to next headline (assuming unique lines)
	#note that these headlines are meant to be \n\nheadline\n\n!
	$z =~ s,\\,\\\\,g;
	$z =~ s,\*,\\\*,g; #to avoid problems with string interpolation
	$z =~ s,\+,\\\+,g; #in the regular expressions containing $z below
	$z =~ s,\-,\\\-,g; #mask all potetnial control characters.
	$z =~ s,\?,\\\?,g;
	$z =~ s,\^,\\\^,g;
	$z =~ s,\$,\\\$,g;
	$z =~ s,\.,\\\.,g;
	$z =~ s,\/,\\\/,g;
	$z =~ s,\(,\\\(,g;
	$z =~ s,\),\\\),g;
	$z =~ s,\[,\\\[,g;
	$z =~ s,\],\\\],g;
	$z =~ s,\{,\\\{,g;
	$z =~ s,\},\\\},g;

	$hdbc = '';
	$hdac = '';

	if ( $$str =~ m/\n\n($z)\n\n/i ) {
	    $hd = 0;

	} else {

	    ($hdb, $hda) = ( $$str =~ m/(.{1,1000})$z(.{1,1000})/si );	

	    if ($hdb) {
		$hdb  =~ s/.+\n\n(.*?)$/$1/si;
		$hdbc =  1;
		$hdbc++ while ( $hdb =~ /\n/g );
	    }

	    if ($hda) {
		$hda  =~ s/^(.*?)\n\n.+/$1/si;
		$hdac =  1;
		$hdac++ while ( $hda =~ /\n/g );
	    }
	    
	    $hdbc = 6 unless ( $hdbc ne '' );
 	    $hdac = 6 unless ( $hdac ne '' );
	    if ( $hdbc < $hdac ) {$hd = $hdbc;} else {$hd = $hdac;}
	}

	#compute statistics/features
	if ($wc)     {$wccc  = $cc  /  $wc;}      else {$wccc  = 0;}
	if ($wc-$ic) {$cwcwc = $cwc / ($wc-$ic);} else {$cwcwc = 0;}
	if ($wc)     {$icwc  = $ic  /  $wc;}      else {$icwc  = 1;}

	if ($wc)     {$ccwc2 = $cc  /  $wc;}      else {$ccwc2 = 0;}
	if ($wc)     {$cwcwc2= $cwc /  $wc;}      else {$cwcwc2= 0;}
	if ($wc)     {$icwc2 = $ic  /  $wc;}      else {$icwc2 = 0;}
	if ($wc)     {$fcwc2 = $fc  /  $wc;}      else {$fcwc2 = 0;}
	                $hd2 = 6                unless ($hd);
	if ($hd > 6) {$hd2   = 6;          }      else {$hd2   = $hd;}

	#choose heuristic ('H') or SVM ('S') based authors_line_selection
	my $authors_line_selector = 'H';


	if ( $authors_line_selector eq 'H' ) {

	    #compute heuristic score
	    $score = 2 * (($wc > 3) && ($wccc > .25)) + #words to commas
		3 * (($cwcwc >= .8) && ($icwc < 0.7)) + #captial started words to all words
		1 * ($ac) +                             #all words are capitals
		1 * ($ic >= 1) +                        #initials exist
		1 * ($fc >= 1) +                        #footnotes exist
		1 * ($hd <= 3);                         #close to a headline

	    #add special single author cases
	    if (   ( /^(by\s+)?[A-Z]{1,2}\s+[A-Z][A-Za-z]+$/ )
		   || ( /^(by\s+)?[A-Z][A-Za-z]+\s+[A-Z]{1,2}\.?\s+[A-Z][A-Za-z]+$/ )
		   )                                    #by T PEETERS
	    {                                           #David P Kreil
		$score = 6;
	    }
	    
	    #check for false positives
	    if (   ( /((departement)|(university)|(univ\.))/i )
		   || ( /((research cent(er|re))|(laboratory)|(cent(er|re)))/i ) 
		   || ( /((received)|(revised)|(accepted)|(published))/i ) 
		   || ( /((advanced)|(applied)|(research group))/i ) 
		   || ( /(((19[56789][0-9])|(200[0-9])))/i )
		   )
	    {
		$score = 0;
	    }                                      

	} elsif ( $authors_line_selector eq 'S' ) {
	    my @SVM_features = ($ccwc2, $cwcwc2, $icwc2, $fcwc2, $hd2, $ac, $sc, $csc);
	    $score = 6 if (&SVM_Classifier(\@SVM_features) == 1);
	}


	#process putative authors line
	if ($score >= 5) {
	    
	    s/\s(and|&)\s/,/gi;                      #turn "and" or "&" into comma
	    @fullname = split(',', $_);              #split into single comma separated names
	    @newname  = ();
	    
	    foreach $n (@fullname) {                

		$n =~ s/^\s*<\w\w>\s+//;             #cut special characters at the beginnig
		$n =~ s/^\s*[^A-Za-z]+\s+//;         #cut non-words at the beginning
		$n =~ s/^\s+//;                      #cut blanks at beginning
		$n =~ s/\s+$//;                      #cut blanks at end
		$n =~ s/\s*<\w\w>$//;                #cut special characters at end
		$n =~ s/[^a-zA-Z]+$//;               #cut non-words at the end
		$n =~ s/\s\s+/ /g;                   #remove double blanks
		$n =~ s/\./ /g;                      #remove dots
		next if ($n =~ /^\s*$/);	     #skip if empty
		
		@cutname = split(/ /, $n);           #split up the full name
		
		$init = '';
		for ($l = 0; $l < $#cutname; $l++) { #turn first names into initials:
		    next if ($l > 1);                #pubmed does not like 3 initials
		    $m = $cutname[$l];               #load $l-th firstname
		    $m =~ s/^\s+//;                  #cut blanks at beginning
		    if ($m =~ /^[A-Z]/) {            #test if name is valid
			$m =~ s/^([A-Z]).*/$1/;}     #cut to intital...
		    else {$m = '';}                  #...or discard
		    $init = $init . $m;
		}
		
		$m = $cutname[$#cutname];            #load surname
		$m =~ s/^\s+//;                      #cut blanks at beginnig
		$m =~ s/\s+$//;                      #cut blanks at end

		if ( ( $m  =~ /((^[A-Z])|(^o)|(^v[aeo]n)|(^d[aeio])|(^l[aeo])|(^il))/ )
		     && ( length($m) >= 2 ) )
		                                     #check for valid surname
		{
		    $m = $m.' '.$init;               #join surname and initals
		    push(@newname, $m);              #write to names array
		}
	    }
	    
	    $names = join(' ',@newname);
	                                             #check for " A B ", figures and boxes 
	    $names = '' if (    ( $names =~ m/^\s*((fig)|(box))/ )
			     || ( $names =~ m/\b\w\s+\w\b/       )  );
				
	    if ( $names ) {
		push(@$auth, $names);
		$i++;
	    }
	}

	last if ($i >= 10)                            #no more than 10 author line suggestions
    }

    return 1;
}



sub remove_noninformative_searchterms
{
    my $arr = shift;

    if ($$arr[0]) {
	foreach (@$arr) {
	    s/ and / /gi;  s/\bA\b//gi;   s/^the / /gi;  s/^this / /gi;	 s/\W/ /g;
	    s/ the / /gi;  s/ an / /gi;   s/ in / /gi;   s/ of / /gi;    s/ by / /gi;
	    s/ are / /gi;  s/ is / /gi;   s/ as / /gi;   s/ for / /gi;   s/ with / /gi;
	    s/ was / /gi;  s/ a / /gi;    s/ on / /gi;   s/ to / /gi;    s/ from / /gi;
	    s/ can / /gi;  s/ be / /gi;   s/ or / /gi;   s/ this / /gi;  s/ that / /gi;

	    #the following are often part of texts, but are not in pubmeds index:
	    s/abstract/ /gi;
	    s/introduction/ /gi;
	    s/background/ /gi;
	    s/(leading )?article/ /gi;
	    s/ \d //g;
	    s/ \w //g;
	}
    }

    return 1;
}



sub compile_searchterms 
{
    my $term  = shift;
    my $auth  = shift;
    my $head  = shift;
    my $para  = shift;
    my $first = shift;

    my @buf = ();
    my $i;
    
    #add first authors and head suggestion to search terms
    push(@$term, $$auth[0]) if ($$auth[0]);
    push(@$term, $$head[0]) if ($$head[0]);

    #removing initials helps for spanish double names that are mistaken
    if ($$auth[0]) {
	foreach (@$auth) {
	    s/\W/ /g;
	    s/ ([A-Z])+ / /g;
	    s/ ([A-Z])+$//g;
	}
    }

    #replace what is  mistaken as initial or useless
    &remove_noninformative_searchterms($head);
    &remove_noninformative_searchterms($para);
    &remove_noninformative_searchterms($first);

    #add the author and head suggestions alternatingly
    for ($i = 0; $i < 10; $i++) {
	push(@$term, $$auth[$i])  if ($$auth[$i]);
	push(@$term, $$head[$i])  if ($$head[$i]);
	push(@$term, $$para[$i])  if ($$para[$i]);
	push(@$term, $$first[$i]) if ($$first[$i]);
    }

    #polish result (medline will fail on long author lines even if correct!)
    foreach (@$term) {
	if ( length($_) > 50 ) {
	    s/^(.{50,}?)\b.*/$1/;
	}
	push(@buf, $_);
    }
    @$term = @buf;

    return 1;
}



sub get_searchterms
{
    my $str = shift;
    my (@arr, @term, @head, @para, @first, @auth);

    #parse the text for relevant information (as string)
    &find_DOI($str, \@term);
    &find_Journal($str, \@term);
    &replace_special_characters($str);
    &find_headlines($str, \@head, \@para, \@first);
    &remove_insignificant_lines(\@head);
    &remove_insignificant_lines(\@para);
    &remove_insignificant_lines(\@first);

    @arr = split('\n',$$str);

    #parse the text for relevant information (as array)
    &remove_insignificant_lines(\@arr);
    &suggest_title(\@head);
    &suggest_authors(\@arr, $str, \@auth);
    &compile_searchterms(\@term, \@auth, \@head, \@para, \@first);

    return @term;
}



1;
