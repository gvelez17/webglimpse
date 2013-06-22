#!/usr/bin/perl
#
# tries to get medline entry for pdftext that comes via STDIN
# online pubmed interaction based on and inspired by the
# pubmeds eSearch/eFetch calling example by Oleg Khovayko,
# NCBI, Bethesda, USA.
#
# (c) Boku Bioinformatics, Vienna, Austria
#     Thomas Tuechler 2006

#--------------------------------------------------------#
# specify path to wrSearchterms if not in same dir:

my $WRSEARCHTERMS='';

#--------------------------------------------------------#


BEGIN{
    unless ($WRSEARCHTERMS) {
	$WRSEARCHTERMS =  $0;
	$WRSEARCHTERMS =~ s,(.+)/wrMedline\.pl$,$1,;
    }
    unshift(@INC,"$WRSEARCHTERMS");   
}

use strict;
use warnings;
use LWP::Simple;
use Getopt::Long qw(:config gnu_getopt);
use Pod::Usage;
use wrSearchterms;


sub query_pubmed;
sub fetch_result;
sub parse_medline;
sub crosscheck;
sub get_first_n_words;



#get commandline the options
my %opt;
my @opts=('medlfile|m:s',
	  'logfile|l:s',
	  'interval|i:f',
	  'querymax|q:f',
	  'gethits|g:f',
	  'readchars|r:f',
	  'man',
	  'help|h|?');
GetOptions(\%opt,@opts) or pod2usage(2);
pod2usage(1) if $opt{help};
pod2usage(-verbose => 2) if $opt{man};


$opt{interval}  = 3     unless $opt{interval};
$opt{querymax}  = 30    unless $opt{querymax};
$opt{gethits}   = 100   unless $opt{gethits};
$opt{readchars} = 10000 unless $opt{readchars};



#read string from STDIN and extract meaningful searchterms
my ($str, $s);
my (@term);

read(STDIN, $str, $opt{readchars});

@term = &wrSearchterms::get_searchterms(\$str);



#test for logfile and read last summery entry
my @logfile;
my ($summary, $i, $hit, $total);

$summary = '';

if ( $opt{logfile} && -s $opt{logfile} ) {
    open(LOGFH, "<$opt{logfile}") || die "ERROR: Can not open $opt{logfile}\n";

    while (<LOGFH>) {push(@logfile, $_);}

    close(LOGFH) || die "ERROR: Can not close $opt{logfile}\n";

    #read log file from the end
    $i = $#logfile - 1;
    while ( $i > 0 && not $summary =~ /\#{6}SUMMARY/ ) {
	$summary = $logfile[$i];
	($hit, $total) = ( $summary =~ /\#{6}SUMMARY: (\d+) of (\d+)/i );
	$i--;
    }
}

$hit = 0 unless ($hit);
$total = 0 unless ($total);



#search the pubmed database
my ($query, $esearch_result, $Count, $QueryKey, $WebEnv);
my ($retstart, $retmax, $efetch, $efetch_result, @efetch_result);
my ($log, $time, $j, $medline, $ti, $ab, @fau, $fau, $pmid, $check);

my $utils   = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils";
my $db      = "Pubmed";
my $report  = "MEDLINE";
my $esearch = "$utils/esearch.fcgi?" .
              "db=$db&retmax=2&usehistory=y&term=";

$time = localtime();
$log  = "######WRMEDLINE: $time\n";
$fau  = ' ';
$i    = 0;

foreach $s (@term) {

    $check     = 0;

    $i++;
    last if ($i > $opt{querymax});
    
    #query the pubmed database with the searchterm
    ($Count, $QueryKey, $WebEnv, $esearch_result) = &query_pubmed($s, $esearch);
    sleep $opt{interval};

    $log .=
	"###SEARCHTERM:\n".
	" $s\n".
	"-COUNT:\n".
	" $Count\n";    

    next if ($Count == 0);
    next if ($Count  > $opt{gethits});

    $retstart = 0;
    $retmax   = $Count;

    #fetch the results for all hits at once from  pubmed
    $efetch_result = &fetch_result($utils, $retstart, $retmax, $db, $QueryKey, $WebEnv);
    @efetch_result = split("\n\n", $efetch_result);
    sleep $opt{interval};
   
    $j = 0;

    #crosscheck if title, author or abstract of hit can be refound in the text
    foreach (@efetch_result) {
	$j++;
	
	$medline = $_;
	$medline =~ s/^[\s\n]+//;
	$medline =~ s/\n[\s\n]+$//;
	
	($pmid, $ti, $ab, @fau) = &parse_medline(\$_);

	$check  = &crosscheck(\$str, \$ti, \$ab, \@fau);

	#if hit was unique, chances are that this is indeed the real paper
	$check += 0.3 if ($Count == 1);

	last if ($check > .7);
    }
    

    if ($check > .7) {
	
	foreach (@fau) {
	    s/^\s*(.+?)\s*$/$1/;
	    s/ ,/,/g;
	    $fau .= "$_; ";
	}

	$log .= 
	    "###IDENTIFICATION SUCCEEDED:\n".
	    "-PMID:\n".
	    " $pmid\n".
	    "-TITLE:\n".
	    "$ti\n".
	    "-ABSTRACT:\n".
	    "$ab\n".
	    "-AUTHORS:\n".
	    "$fau\n";

	$hit++;
	last;

    } else {

	$medline = '';
    }    
}

$total++;

unless ( $medline ) {$log .= "###IDENTIFICATION FAILED.\n";}

$log .= "######SUMMARY: $hit of $total\n";



#append to logflile
if ( $opt{logfile} ) {

    open(LOGFH, ">>$opt{logfile}") || die "ERROR: Can not open $opt{logfile}\n";

    print LOGFH "$log\n";

    close(LOGFH) || die "ERROR: Can not close $opt{logfile}\n";
}



#medline to file or to STDOUT
if ( $opt{medlfile} && $medline ) {

    open(MEDFH, ">$opt{medlfile}") || die "ERROR: Can not open $opt{medlfile}\n";

    print MEDFH "$medline\n";

    close(MEDFH) || die "ERROR: Can not close $opt{medlfile}\n";

} elsif ( $medline ) {

    print("$medline\n");
}



#subroutines

sub query_pubmed
{
    my $query   = shift;
    my $esearch = shift;

    my ($Count,$QueryKey,$WebEnv);
 
    $esearch_result = get($esearch . $query);
    
    ($Count,$QueryKey,$WebEnv) =
	$esearch_result =~ m|<Count>(\d+)</Count>.*<QueryKey>(\d+)</QueryKey>.*<WebEnv>(\S+)</WebEnv>|s;

    return ($Count, $QueryKey, $WebEnv, $esearch_result);
}



sub fetch_result
{
    my ($utils, $retstart, $retmax, $db, $QueryKey, $WebEnv) = @_;

    $efetch   = "$utils/efetch.fcgi?" .
	"rettype=$report&retmode=text&retstart=$retstart&retmax=$retmax&" .
	"db=$db&query_key=$QueryKey&WebEnv=$WebEnv";
    
    $efetch_result = get($efetch);
    
    return $efetch_result;
}



sub parse_medline
{
    my $efetch_result = shift;

    my ($pmid, $ti, $ab, $fau, @fau);
    my @efetch_result;

    @efetch_result = split(/\n/, $$efetch_result);

    foreach (@efetch_result) {

	if ( /^PMID-/ ) {
	    $pmid =  substr($_, 6);
	    chomp($pmid);
	    $pmid =~ s/(\s)+/ /g;
	} elsif ( /^TI  -/ ) {
	    $ti   =  substr($_, 6);
	    chomp($ti);
	    $ti   =~ s/(\s)+/ /g;
	} elsif ( /AB  -/ ) {
	    $ab   =  substr($_, 6);
	    chomp($ab);
	    $ab   =~ s/(\s)+/ /g;
	} elsif ( /^FAU -/ ) {
	    $fau  =  substr($_, 6);
	    chomp($fau);
	    $fau  =~ s/(\s)+/ /g;
	    push(@fau, $fau);
	}
    }

    # some Medlines do not have an abstract (eg. PMID 12192400)
    $ab = "noabstractinmedline" unless ( $ab );
    
    return ($pmid, $ti, $ab, @fau);
}



sub crosscheck
{
    my $str = shift;
    my $ti  = shift;
    my $ab  = shift;
    my $fau = shift;

    my ($i, $n, $s, $a);
    my ($check_ti, $check_ab, $check_fau, $check, $trial);

    $check_ti  = 0;    
    $check_ab  = 0;
    $check_fau = 0;
    $trial     = 0;


    #convert to words only string to be searchable with medline terms
    $$str =~ s/\b(\w+)\b/ $1 /g;
    $$str =~ s/\s+/ /g;
    $$str =  lc($$str);
    
    for ($i = 1; $i <= 3; $i++) {
	$trial += 2;
	
	$n =  $i * 4;
	$s =  &get_first_n_words($ti, $n);

	#pubmed sometimes adds a dot after the title
	$s =~ s/\s*\.\s*$//;
	if ( index($$str, $s) >= 0 ) {
	    $check_ti++;

	#pubmed sometimes has : in titles that dont exist in pdf
	} else {
	    $s =~ s/ : / /;
	    $check_ti++ if( index($$str, $s) >= 0 );
	}

	$n =  $i * 8;
	$s =  &get_first_n_words($ab, $n);

	#pubmed does not have "Abstract:" at beginning of abstracts
	#reduce trials if no abstract exists!
	$s =~ s/abstract\W*\s+//;
	$check_ab++ if ( index($$str, $s) >= 0 );
	$trial-- if ( $$ab =~ m/noabstractinmedline/ );

    }
 
    foreach $a (@$fau) {
	$trial++;

	#leave away the first names
	$a =~ s/,\s*$//g;
	$s =  &get_first_n_words(\$a, 1);
	$check_fau++ if (index($$str, $s) >= 0);

    }

    #compute the statistic
    $check = ($check_ti + $check_ab + $check_fau) / $trial;
    $check = 0 unless ( (($check_ti gt 0) + ($check_ab gt 0) + ($check_fau gt 0)) >= 2 );
    
    return $check;
}



sub get_first_n_words
{
    my $str   = shift;
    my $n     = shift;

    return unless ( $$str );
    
    my $i     = 0;
    my $words = ''; 

    #convert to have same format as the string to search in
    &wrSearchterms::replace_special_characters($str);
    $$str =~ s/\n[\ \t\f\r]+/\n/g;
 
    $$str =~ s/\b(\w+)\b/ $1 /g;
    $$str =~ s/\s+/ /g;
    $$str =  lc($$str);

    while ( ($$str =~ /(\S+)/g) && ($i < $n) ) {
	$words .= "$1 ";
	$i++;
    }
    $words =~ s/\s+$//;
    $words =~ s/\W+$//;

    return $words;
}



__END__

=head1 NAME

wrMedline - Try to find correct Medline record from a PDF reprint

=head1 SYNOPSIS

pdftotext {pdfFile} - | wrMedline.pl {parameters} [options]

 Parameters:
    --medlfile=...      save Medline entry here
    --logfile=...	save logfile here
    --interval=...      interval between medline requests
    --readchars=...     number of characters read from STDIN
    

 Options:
   -h -? --help		show the help text
   --man		page the full documentation


=head1 DESCRIPTION

wrMedline tries to extract informative strings from a text, in order to uniquely identify within the scientific PubMed database.

=head1 OPTIONS AND PARAMETERS

=over 4

=item B<-h -? --help>

Shows the help text and exits.

=item B<--man>

Pages the full documentation and exits.

=item B<-m --medlfile>

If the retrieved Medline entry should not go to STDOUT name a file to save it here.

=item B<-l --logfile>

Give path to file where the search results should be logged. Default is none. The logfile will tell you what searchterms were used, how many hits PubMed produced for each of them and if the hits could be confirmed by reversivly searching the Medline terms in the text. If you apply wrMedline.pl to more than one paper, the logfile will also summarize verified hits versus total number of papers searches.

=item B<-i --interval>

Interval to pause between queries. Default is 3 seconds. Check usage conditions on PubMed website. Typically any set of more than 100 requests should be processed out of peak hours only and no more than one request per 3 seconds should be made.

=item B<-q --querymax>

Maximum number of queries to be sent for one text. Default is 30. However, if the number of reasonable searchterms is smaller, this maximum value will not be reached. Usually no more than 50 meaningful searchterms can are extracted from one paper.

=item B<-g --gethits>

Maximum number of PubMed hits to be processed. Default is 100. If PubMed offers more hits for one searchterm than this number, wrMedline.pl will neglect them and proceed with the next searchterm.

=item B<-r --readchars>

Number of characters to be read from STDIN. Default is 10,000, which is approximately the first page of a usual paper reprint. Note that some publications have the authors listed on the last page (especially technical reports, short reviews, etc.).

=back


=head1 CREDITS

Copyright (c) Thomas Tuechler, David P Kreil 2006,
              Boku Bioinformatics, Vienna, Austria
              L<http://bioinf.boku.ac.at/>


=head1 SEE ALSO

PubMed usage conditions can be found on:
L<http://eutils.ncbi.nlm.nih.gov/entrez/query/static/eutils_help.html>


=cut
