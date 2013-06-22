#!/usr/bin/perl -wT

# wrsearch is a searchform inspired by the successfull
# google interface, with a simple and an advanced
# version.
#
# (c) Thomas Tuechler 2006
#     Boku Bioinformatics, Vienna, Austria

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

my $q = new CGI;
print $q->header();

#--------------------------------------------------------#
# specify path to webglimpse libraries here:

BEGIN{
    my $WEBGLIMPSE_LIB='';
    unshift(@INC,"$WEBGLIMPSE_LIB");

   die "You need to specify the path to the webglimpse libraries in $0 first!"
	unless ( $WEBGLIMPSE_LIB );
}
#
#--------------------------------------------------------#


BEGIN{
    use wgHeader qw( :all);
    use wrRepos;
}



# define valid categories and get flags
my ($flagRatings, $flagCategories);
my (%AnnoClasses, @AnnoClasses);

($flagRatings, $flagCategories) = &wrRepos::flagCategoriesAndRatings();
%AnnoClasses = %{&wrRepos::defineCategories()};
@AnnoClasses = keys(%AnnoClasses);


# parse parameters
my ($Prot, $Host, $Port, $Path, $ServerFull, $Referer, $ArchID, $QueryStr, $wrSubmitQuery, $wrFormType, $WebWebglimpse);
my ($wrAany, $wrAname, $wrAfull, $wrAsuppl, $wrAbibf, $wrAanno);

($Prot,$Host,$Port,$Path) = &url::parse_url($q->self_url());
$Path          =~ s,\/(.+?)\/wrsearch\.cgi.*,$1,i;
$ServerFull    =  $Prot.'://'.$Host.':'.$Port;
$WebWebglimpse =  $Prot.'://'.$Host.':'.$Port.'/'.$Path.'/'."webglimpse.cgi";

$ArchID        =  $q->url_param('ID');
$wrFormType    =  $q->url_param('WR');
$wrAany        =  $q->url_param('anywhere');
$wrAname       =  $q->url_param('name');
$wrAfull       =  $q->url_param('full');
$wrAsuppl      =  $q->url_param('suppl');
$wrAbibf       =  $q->url_param('bibf');
$wrAanno       =  $q->url_param('anno');
$QueryStr      =  $q->url_param('query');
$wrSubmitQuery =  1 if ( $QueryStr || $wrAany || $wrAname || $wrAfull || $wrAsuppl || $wrAbibf || $wrAanno );


# test for validity of parameters
unless ( $ServerFull ) {die "ERROR: parse_url failed"};
unless ( $ArchID ) {
    print 
	"<span style=\"color: green\"><pre><font size=3>",
	"WARNING: No archive ID specified in URL! <br />",
	"         Using default ID=1. <br />",
	"</font></pre></span>";
    $ArchID = 1;
}
unless ( $wrFormType ) {$wrFormType = 'S'}; 


# defining the standard params for webglimpse search
my %wgQueryParams =
    (ID=>"$ArchID",
     query=>"$QueryStr",
     case=>"",
     whole=>"",
     lines=>"",
     errors=>"0",
     age=>"",
     maxfiles=>"20",
     maxlines=>"1",
     maxchars=>"150",
     filter=>"",
     cache=>"yes",
     rankby=>"DEFAULT"
     );

my %wgQueryCheckboxes  =
    (case=>"Case sensitive",
     whole=>"Partial match",
     lines=>"Jump to line",
     sentece=>"Try to output only sentences",
     limit=>"Maximum speed hits only"
     );
my @wgQueryCheckboxes = keys(%wgQueryCheckboxes);

my %wgQueryPulldowns  =
    (errors=>"Misspellings allowd",
     age=>"Return only files modified within last",
     maxfiles=>"Maximum number of files returned",
     maxlines=>"Maximum number of matches per file returned",
     maxchars=>"Maximum number of characters output per file",
     rankby=>"Rank by"
     );

my %wrQueryParams =
    (any=>"$wrAany",
     name=>"$wrAname",
     full=>"$wrAfull",
     suppl=>"$wrAsuppl",
     bibf=>"$wrAbibf",
     anno=>"$wrAanno",
     );


# the advanced search option requires special parameter parsing
my @userdefParam = $q->url_param('WG2');
my ($userdefParam, $i, $warnText);
my @userdefCateg = $q->url_param('Category');
my $RatesMin     = $q->url_param('Rmin');
my $RatesMax     = $q->url_param('Rmax');

if ( $wrFormType eq 'A' ) {

    # note that 1 is best, ie. maximum rating and 5 worst, ie. minimum rating!
    if ( $RatesMin < $RatesMax ) {
	$RatesMin = $q->url_param('Rmax');
	$RatesMax = $q->url_param('Rmin');
    }

    #  include user-defined checkbox settings
    foreach ( @userdefParam ) {
	$wgQueryParams{$_} = '1' if ( $_ );
    }

    # include user-defined select settings
    foreach ( keys(%wgQueryPulldowns) ) {
	$userdefParam = $q->param($_);
	$wgQueryParams{$_} = $userdefParam
	    if ( $userdefParam );
    }

    # building $QueryStr for webglimpse from the textfields
    foreach ( keys(%wrQueryParams) ) {
	$wgQueryParams{'query'} .= "$_".
 	    '%25%33%44'.
	    "$wrQueryParams{$_};" #'%3B' = ';' = ' AND '
	    if ( $wrQueryParams{$_} );
    }

    # adding the categories to $QueryStr
    foreach ( @userdefCateg ) {
	$wgQueryParams{'query'} .=
 	    'anno%25%33%44'.
	    "C\_$_\_1;"; #'%3B' = ';' = ' AND '
    }

    # adding the rating boundaries to $QueryStr
    if ( $RatesMin - $RatesMax < 4 && $RatesMin && $RatesMax ) {
	$wgQueryParams{'query'} .= '{';
	for ($i = $RatesMax; $i <= $RatesMin; $i++) {
	    $wgQueryParams{'query'} .=
		'anno%25%33%44'.
		"aR\_$i,"; #',' =  'OR '
	}

	$wgQueryParams{'query'} =~ s/;$//;
	$wgQueryParams{'query'} =~ s/,$//;
	$wgQueryParams{'query'} =~ s/\+AND\+$//;
	$wgQueryParams{'query'} =~ s/\+OR\+$//;
	$wgQueryParams{'query'} .= '}';

    }

    # the 'Jump to lines' option is NOT compatible with OR searches!
    if ( $wgQueryParams{'query'} =~ m/(,| OR )/ && $wgQueryParams{'lines'} ) {
	$wgQueryParams{'lines'} = '';
	$warnText .=  "'Jump to line' is not compatible with boolean OR searches. it was automatically disabled!\n";
    }
    
    # the same applies for 'Misspellings allowed'!
    if ( $wgQueryParams{'query'} =~ m/(,| OR )/ && $wgQueryParams{'errors'} ) {
	$wgQueryParams{'errors'} = '';
	$warnText .=  "'Misspellings allowed' is not compatible with boolean OR searches- it was automatically disabled!\n";
    }

    # do also warn, if too many wildcards are being used
    if ( $wgQueryParams{'query'} =~ m/\#.+\#/  ||
	 $wgQueryParams{'query'} =~ m/\#.+\{/  ||
	 $wgQueryParams{'query'} =~ m/\{.+\#/    )
    {
	$wgQueryParams{'errors'} = '';
	$warnText .=  "Be careful with complex queries- search may become inefficient!\n";
    }

}


# do special encoding to keep structured queries alive:
# query=anno%3Dmicroarr%23+AND+bibf%3Dauburn
# note that structured query conflicts with allowing of misspellings.
# (for full%3Dmicrarray it will take the fieldname 'full' as a hit)

$wgQueryParams{'query'} =~ s/any%25%33%44//;
$wgQueryParams{'query'} =~ s/;$//;
$wgQueryParams{'query'} =~ s/,$//;
$wgQueryParams{'query'} =~ s/\+AND\+$//;
$wgQueryParams{'query'} =~ s/\+OR\+$//;
$wgQueryParams{'query'} =~ s/ /\+/g;
$wgQueryParams{'query'} =~ s/\=/\%25\%33\%44/g;
$wgQueryParams{'query'} =~ s/\#/\%25\%32\%33/g;
$wgQueryParams{'query'} =~ s/>/\\>/g;

$QueryStr = '';

foreach (keys(%wgQueryParams)) {
    $QueryStr .= "$_=$wgQueryParams{$_}&";
}


$QueryStr =~ s/Combined score/DEFAULT/;
$QueryStr =~ s/\&$//;


# display warnings for complex searches
my $debug = 0;
print "QueryStr: $QueryStr<br>" if ( $debug );
if ( $warnText ) {
    print
	"<span style=\"color: green\"><pre><font size=3>",
	"$warnText","Query is being processed...",
	"</font></pre></span>";
}



# create the search  website
# using the webglimpse css

# at first the header with css
print
    "<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"en-US\" xml:lang=\"en-US\">\n",
    "<head>\n",
    "<title>BibGlimpse</title>\n\n",
    "<style type=\"text/css\">\n",
    "<!-- \n",
    "body,td,div,a {font-family:arial,sans-serif; font-size:10pt; }\n",
    "a:link {color:#000080}\n",
    "div.results {border-top:thin ridge #008000; padding-top: .3em; }\n",
    "div.credits {border-top:thin ridge #008000;  font-size: 9pt; }\n",
    "-->\n",
    "</style>\n\n";

# headline at the top
print
    $q->h3("BibGlimpse Field Search"),"\n",
    "\n<table width=\"100\%\">\n",
    "<tbody align=\"left\" valign=\"top\">\n",
    "<tr>\n";

if ( $wrFormType eq 'S' ) {
    print
	$q->td({-align=>"left",
		-width=>"1\%"},
	       $q->a({href=>"$Prot://$Host:$Port/$Path/wrsearch.cgi?ID=$ArchID&WR=A"},
		     "Advanced&nbsp;search"));
} elsif ( $wrFormType eq 'A' || $wrFormType eq 'H' ) {
    print
	$q->td({-align=>"left",
		-width=>"1\%"},
	       $q->a({href=>"$Prot://$Host:$Port/$Path/wrsearch.cgi?ID=$ArchID"},
		     "Simple&nbsp;search"));
}

print
    $q->td({-align=>"centre",-width=>"1\%"}, "&nbsp;|&nbsp;"),
    $q->td({-align=>"left"},
	   $q->a({href=>"$Prot://$Host:$Port/$Path/wrsearch.cgi?ID=$ArchID&WR=H"},
		 "Help"));

if ( -x $CGIBIN_DIR.'/logout/logout.cgi' ) {
    print
	$q->td({-align=>"right"},
	       "| ",
	       $q->a({href=>"$Prot://logout:logout\@$Host:$Port/$Path/logout/logout.cgi"}, "Logout")), "\n";
}


# search type specific output
print
    "</tr>\n",
    "</tbody>\n",
    "</table>\n",
    "\n<div class=results>\n",
    "<form method='GET'>\n",
    "\n<table width=\"100\%\">\n",
    "<tbody align=\"left\" valign=\"top\">\n",
    $q->p, "\n",;

if ( $wrFormType eq 'S' ) {
    print
	"<input type=hidden name=\"ID\" value=\"$ArchID\">",
	$q->Tr($q->td("New Query:&nbsp;\n",
		      $q->textfield(-name=>'query',
				    -default=>"",
				    -size=>20,
				    -maxlength=>200), "\n",
		      "<input type=submit value='Search'>\n"));
	   
}  elsif ( $wrFormType eq 'A' ) {
    print
	"<input type=hidden name=\"ID\" value=\"$ArchID\">\n",
	"<input type=hidden name=\"WR\" value=\"A\">\n",
	$q->Tr($q->td($q->i("Textfields:"))),
	$q->Tr($q->td({-width=>"1%"},
		      "Anywhere"), "\n",
	       $q->td({-width=>"1%",
		       -align=>"right"}), "\n",
	       $q->td($q->textfield(-name=>'anywhere',
				    -default=>"",
				    -size=>20,
				    -maxlength=>200))), "\n",
	$q->Tr($q->td("Filename"), "\n",
	       $q->td({-align=>"right"},
		      "<b>name=<b>"), "\n",
	       $q->td($q->textfield(-name=>'name',
				    -default=>"",
				    -size=>20,
				    -maxlength=>200))), "\n",
	$q->Tr($q->td("Fulltext"), "\n",
	       $q->td({-align=>"right"},
		      "<b>full=<b>"), "\n",
	       $q->td($q->textfield(-name=>'full',
				    -default=>"",
				    -size=>20,
				    -maxlength=>200))), "\n",
	$q->Tr($q->td("Supplements"), "\n",
	       $q->td({-align=>"right"},
		      "<b>suppl=<b>"), "\n",
	       $q->td($q->textfield(-name=>'suppl',
				    -default=>"",
				    -size=>20,
				    -maxlength=>200))), "\n",
	$q->Tr($q->td("Bibliography"), "\n",
	       $q->td({-align=>"right"},
		      "<b>bibf=<b>"), "\n",
	       $q->td($q->textfield(-name=>'bibf',
				    -default=>"",
				    -size=>20,
				    -maxlength=>200))), "\n",
	$q->Tr($q->td("Annotation"), "\n",
	       $q->td({-align=>"right"},
		      "<b>anno=<b>"), "\n",
	       $q->td($q->textfield(-name=>'anno',
				    -default=>"",
				    -size=>20,
				    -maxlength=>200))), "\n",
	"</tbody>\n",
	"</table>\n",
	$q->p, "\n";

    if ( $flagRatings ) {
	print 
	    "\n<table width=\"100\%\">\n",
	    "<tbody align=\"left\" valign=\"top\">\n",

	    $q->Tr($q->td($q->i("Ratings:"))),
	    $q->Tr($q->td({-width=>"1\%"}, "Maximum&nbsp;"),
		   $q->td(), "\n",
		   $q->td($q->radio_group(-name=>"Rmax",
					  -values=>['1','2','3','4','5'],
					  -default=>"",))), "\n",
	    $q->Tr($q->td({-width=>"1\%"}, "Minimum&nbsp;"),
		   $q->td(), "\n",
		   $q->td($q->radio_group(-name=>"Rmin",
					  -values=>['1','2','3','4','5'],
					  -default=>"",))), "\n",
	    "</tbody>\n",
	    "</table>\n",
	    $q->p, "\n";
    }

    if ( $flagCategories ) {
	print
	    "\n<table width=\"100\%\">\n",
	    "<tbody align=\"left\" valign=\"top\">\n",
	    $q->Tr($q->td($q->i("Categories:"))),
	    $q->Tr($q->td($q->checkbox_group(-name=>'Category',
					     -values=>\@AnnoClasses,
					     -default=>"",
					     -labels=>\%AnnoClasses))), "\n",
	    "</tbody>\n",
	    "</table>\n",
	    $q->p, "\n";
    }
	
    print    
	"\n<table width=\"100\%\">\n",
	"<tbody align=\"left\" valign=\"top\">\n",
	$q->Tr($q->td($q->i("Search&nbsp;options:"))),
	$q->Tr($q->td($q->checkbox_group(-name=>"WG2",
					 -values=>\%wgQueryCheckboxes,
					 -default=>"",
					 -labels=>\%wgQueryCheckboxes))), "\n",
	"</tbody>\n",
	"</table>\n",
    
	"\n<table width=\"100\%\">\n",
	"<tbody align=\"left\" valign=\"top\">\n",
	$q->Tr($q->td({-width=>"1\%"},
		      "Misspellings&nbsp;allowed:&nbsp;"), "\n",
	       $q->td($q->Select({-name=>'errors',
				 -size=>'1'}, "\n",
				 $q->option({-selected}, '0'), "\n",
				 $q->option('1'), "\n",
				 $q->option('2')))), "\n",
	$q->Tr($q->td("Rank&nbsp;by:&nbsp;"), "\n",
	       $q->td($q->Select({-name=>'rankby',
				 -size=>'1'}, "\n",
				 $q->option({-selected}, 'Combined score'), "\n",
				 $q->option('Most recent first'), "\n",
				 $q->option('Meta matches')))), "\n",
	$q->Tr($q->td("Maximum&nbsp;files&nbsp;returned:&nbsp;"), "\n",
	       $q->td($q->Select({-name=>'maxfiles',
				 -size=>'1'}, "\n",
				 $q->option('10'), "\n",
				 $q->option({-selected}, '20'), "\n",
				 $q->option('50'), "\n",
				 $q->option('100'), "\n",
				 $q->option('1000')))), "\n",
	$q->Tr($q->td("Maximum&nbsp;matches&nbsp;per&nbsp;file&nbsp;returned:&nbsp;"), "\n",
	       $q->td($q->Select({-name=>'maxlines',
				 -size=>'1'}, "\n",
				 $q->option({-selected}, '1'), "\n",
				 $q->option('2'), "\n",
				 $q->option('3'), "\n",
				 $q->option('5'), "\n",
				 $q->option('10'), "\n",
				 $q->option('100')))), "\n",
	$q->Tr($q->td("Maximum&nbsp;characters&nbsp;output&nbsp;per&nbsp;file:&nbsp;"), "\n",
	       $q->td($q->Select({-name=>'maxchars',
				 -size=>'1'}, "\n",
				 $q->option('100'), "\n",
				 $q->option({-selected}, '200'), "\n",
				 $q->option('500'), "\n",
				 $q->option('1000')))), "\n",
	$q->Tr($q->td("Modified&nbsp;within&nbsp;last&nbsp;days:&nbsp;"), "\n",
	       $q->td($q->Select({-name=>'age',
				 -size=>'1'}, "\n",
				 $q->option({-selected}, ''), "\n",
				 $q->option('1'), "\n",
				 $q->option('7'), "\n",
				 $q->option('30'), "\n",
				 $q->option('365')))), "\n",
	$q->Tr($q->td("<br />")), "\n",
	$q->Tr($q->td("<input type=submit value='Search'>", "\n",
		      "<input type=reset value='Reset'>")), "\n";
    
} elsif ( $wrFormType eq 'H' ) {
    print
	"The <a href=http://www.biotec.boku.ac.at/bioinf.html?&L=1>Boku-Bioinformatics</a> reprints repository is built on top of the <a href=http://webglimpse.net>Webglimpse</a> advanced site search software. The Webglimpse documentation describes the basic <a href=http://webglimpse.net/docindex/howtos.htm#searchtips>query syntax</a> with an extra section for <a href=http://webglimpse.net/docindex/configure.htm#metatags>structured queries</a>. A more detailed description of the supported syntax is given in the manual pages of the underlying <a href=http://webglimpse.net/gdocs/glimpsehelp.html#sect7>glimpse</a> search engine. Here just a quick example:</p><p>\n",
	"<b>'name=guest# AND bibf=Haesel#'</b></p><p>\n",
	"will find all papers that have <b>'guest'</b> in the filename and <b>'Haesel'</b> in the bibliographic record. The wildcard symbol is <b>'#'</b> and the fields to search in are\n",
	"<ul>\n",
	"<li><b>name</b> filename of the reprint pdf\n",
	"<li><b>full</b> fulltext of the reprint pdf\n",
	"<li><b>suppl</b> fulltext of supplementary material\n",
	"<li><b>bibf</b> bibliographic record, i.e. either MEDLINE or BibTeX\n",
	"<li><b>anno</b> annotation created by users\n",
	"</ul>\n",
	"Of course you can also search without specifying a field.\n";
}


# credits line at the bottom
print
    "</tbody>\n",
    "</table>\n",
    "\n</form>\n",
    "</div>\n",
    $q->p, "\n",
    "<div class=\"credits\">Repository by <a href=\"http://www.biotec.boku.ac.at/bioinf.html?&L=1\">Boku Bioinformatics</A> light-weight scientific reprints management.</div>\n",
    "<!-- (c) Boku Bioinformatics 2006 -->\n";



# if a query has been parsed, submit it!
my $warnTime = 0;

if ( $wrSubmitQuery ) {
    $warnTime = 2000 if $warnText;
    print
	"<form name=\"SubmitQuery\" action=\"javascript:location.replace('$WebWebglimpse?$QueryStr')\" method=\"GET\" encoding=\"text/plain\">",
	"</form>",
	"<script type=\"text/javascript\">",
	"window.setTimeout(\"document.SubmitQuery.submit()\",$warnTime);",
	"</script>";
}


# end the html
print
    "<!-- (c) Boku Bioinformatics 2006 -->",
    $q->end_html, "\n";
