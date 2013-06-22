#!/usr/bin/perl

package wrRepos;

# wrRepos collects routines necessary to use webglimpse as 
# a prints repository. you can specify your own categories
# in the defineCategories sub routine.
#
# Functions:
#
#       defineCategories <- customize categories here!
#       flagCategoriesAndRatings <- (de)activate here!
#       url_decode
#       url_encode
#       withinBraces
#       parseMedline
#       parseBibTeX
#       makeReposInitial
#       makeReposLinks
#       checkSysReturn
#       startReindexing
#       parseAnnoStr
#       buildNewAnnoBack
#
# (c) Boku Bioinformatics, Vienna, Austria
#     Thomas Tuechler, David Kreil 2006
#     

BEGIN {
    use wgHeader qw( :general :install );
}

use wgSiteConf;
use strict;
use Data::Dumper;
use CGI::Carp qw(fatalsToBrowser);



sub defineCategories {

    # use this hash to customize the available categories!
    my %AnnoClasses = (Edi=>"Editorial",
		       Rev=>"Review",
		       The=>"Thesis");

    return \%AnnoClasses;
}


sub flagCategoriesAndRatings {

    # use this to (de)activate categories and ratings;
    # NOTE: if you deactive them, old categories are set zero when editing!
    my $flagRatings    = 0;
    my $flagCategories = 0;

    return ($flagRatings, $flagCategories);
}


sub url_decode {

    my ( $decode ) = @_;

    return () unless defined $decode;
    $decode =~ tr/+/ /;
    $decode =~ s/%([a-fA-F0-9]{2})/ pack "C", hex $1 /eg;
    return $decode;
}



sub url_encode {

    my ( $encode ) = @_;

    return () unless defined $encode;
    $encode =~ s|([^A-Za-z0-9\-_.!~*\'() /:])|
	uc sprintf "%%%02x",ord $1 |eg;  # added /:?&= to support CGI paths
    $encode =~ s, ,%20,gi; # need these to fetch files rather than "+"
    return $encode;
}

# assuming ASCII; taken from Cgi-Simple-0.077/Simple.pm, which also
# has support for non-ASCII character sets (where "\t" ne "\011").



sub withinBraces {

    # finds the substring within the outermost pair of handled braces:
    # &withinBraces('bla{{ta{}rg{}e{}t}"!"}bla{}bla';'','{','}') = 
    #                    {ta{}rg{}e{}t}"!" 

    my $string     = shift;
    my $braceOpen  = shift;
    my $braceClose = shift;

    my ($i, $letter, $firstOpen, $inBraces);
    my $braceCount = 1;
    
    $string =~ m/$braceOpen/g;
    $firstOpen = pos($string);
    
    for ($i = $firstOpen; $i < length($string); $i++) {
	$letter = substr($string, $i, 1);
	( $letter eq $braceOpen  )  && $braceCount++;
	( $letter eq $braceClose ) && $braceCount--;
	last if ( $braceCount == 0 );
    }
    
    $inBraces = substr($string, $firstOpen, $i - $firstOpen);
    return $inBraces;
}



sub parseMedline {

    my $LocMedl = shift;
    my $ReadIDs = shift;
        
    my ($parseMode, $MedlID);
    my %MedlHash;

    if ( $LocMedl =~ m/.+\.medl$/ && -e $LocMedl && not -z $LocMedl ) {
	open(MEDLFH, "<$LocMedl") || die "ERROR: Can not open $LocMedl\!<br />";	
	while (<MEDLFH>) {
	    chomp;
	    $parseMode = '' if ( m/^[A-Z]{2,4}\s*-\ .+/ );

	    foreach $MedlID (@{$ReadIDs}) {
		if ( m/^$MedlID[\ ]{0,2}-\ .+/ ) {
		    $parseMode = $MedlID;
		    s/^\s*(\S.*)/$1/;
		    last;
		}
	    }
	    
	    foreach $MedlID (@{$ReadIDs}) {
		if ( $parseMode eq $MedlID ) {
		    s/^$MedlID[\ ]{0,2}-\ (.+)/$1/;
		    s/^\s*(.+)\s*$/$1/;
		    if ( $MedlID =~ m/F?AU/ ) {
			$MedlHash{$MedlID} .=  "$_, ";
		    } else {
			$MedlHash{$MedlID} .=  "$_ ";
		    }
		}
	    }
	}
	close(MEDLFH) || die "ERROR: Can not close $LocMedl\!<br />";
	
	foreach (keys %MedlHash) {
	    chop($MedlHash{$_});
	}	
	$MedlHash{'AU'}  =~ s/(.+)\,$/$1\./ if $MedlHash{'AU'};
	$MedlHash{'FAU'} =~ s/(.+)\,$/$1\./ if $MedlHash{'FAU'};

    } else {

	$MedlHash{'status'}  = "FAILED";	
    }

    return %MedlHash;
}




sub parseBibTex {

    my $LocBib  = shift;
    my $ReadIDs = shift;

    my ($parseMode, $BibStr, $BibStart, $BibID, $BibIDpos, $BibField);
    my (@BibBrace, %BibHash);
    
    if ( ($LocBib =~ m/.+\.bib$/) && (-e $LocBib) && (not -z $LocBib) ) {

	open(BIBFH, "<$LocBib") || die "ERROR: Can not open $LocBib\!<br />";
	@_ = <BIBFH>;
	close(BIBFH) || die "ERROR: Can not close $LocBib\!<br />";

	$BibStr =  join(' ', @_);
	$BibStr =~ tr/\n\t\f\r/    /;
	$BibStr =~ s/\s+/ /g;
	$BibStr =~ s/ = \{/=\{/g;
	$BibStr =~ s/ = \"/=\"/g;
	$BibStr =~ s/, ?(\w+) ?= ?(\d+) ?,/, $1=\{$2\},/g;

	$BibHash{'PMID'} =  $BibStr;
	$BibHash{'PMID'} =~ s/^%\D+?(\d+)\D.*$/$1/;
	
	@BibBrace = ('{','}') if ( $BibStr =~ m/\@\w+\{/ );
	@BibBrace = ('(',')') if ( $BibStr =~ m/\@\w+\(/ );

	$BibStr = &withinBraces($BibStr, $BibBrace[0], $BibBrace[1]);
	
	foreach $BibID (@{$ReadIDs}) {
	    $BibIDpos = index($BibStr,"$BibID=");
	    next if ( $BibIDpos == -1 );
	    $BibStart = substr($BibStr, $BibIDpos + length($BibID) + 1, 1);	    	    @BibBrace = '';
	    @BibBrace = ('{','}') if ( $BibStart eq '{' );
	    @BibBrace = ('"','"') if ( $BibStart eq '"' );
	    next unless @BibBrace;
	    $BibField = substr($BibStr, $BibIDpos - 1);
	    $BibField = &withinBraces($BibField, $BibBrace[0], $BibBrace[1]);
	    $BibHash{$BibID} = $BibField;
	}

    } else {

	$BibHash{'status'}  = "FAILED";
    }
    
    return %BibHash;
}



sub makeReposInitial {
    
    my $self           = shift;
    my $initial_output = shift;

    use CGI;
    use CGI::Carp qw(fatalsToBrowser);

    my $q = new CGI;
    my ($selfURL, $Prot, $Host, $Port, $Path);
    my ($WR_archID, $wgarcmin, $LnkAdmin, $WebLogout, $LocLogout, $LnkLogout);

    $WR_archID =  ${$self}->{archive_dir};
    $WR_archID =~ s,.+\/(\d+)$,$1,;

    ($Prot,$Host,$Port,$Path) = &url::parse_url($q->self_url());
    $Path =~ s,^(.+?)\?.*,$1,;
    $Path =~ s,(.+)/[^/]+$,$1,;
    $Path =~ s,^/,,;

    $WebLogout = "$Prot://logout:logout\@$Host:$Port/$Path/logout/logout.cgi";
    $LocLogout = "$CGIBIN_DIR/logout/logout.cgi";
    $LnkLogout = " | ".$q->a({-href=>"$WebLogout"},"Logout");
    $LnkLogout = '' unless ( -x $LocLogout );

    $wgarcmin  = "wgarcmin.cgi?ID=$WR_archID\&ACTION=&NEXTPAGE=M";
    $LnkAdmin  = $q->a({-href=>"$wgarcmin"}, "Local Admin")
	if ( $ENV{'REMOTE_USER'} =~ m/^admin$/i );

    $$initial_output .= 
	$q->br.
	$q->table({-width=>"100%"},
		  $q->Tr($q->td($q->a({-href=>"webglimpse.cgi?ID=$WR_archID"},
				      "Webglimpse Search"), " | ",
				$q->a({-href=>"wrsearch.cgi?ID=$WR_archID&WR=A"},
				      "Field Search"), " | ",
				$q->a({-href=>"http://www.pubmed.com"},
				      "Pubmed"), " | ",
				$q->a({-href=>"http://citeseer.ist.psu.edu"},
				      "CiteSeer")
				),
			 $q->td({-align=>"right"},
				$LnkAdmin,
				$LnkLogout
				)
			 )
		  );
    return 1;
}



sub makeReposLinks {
    
    my $self = shift;
    my $link = shift;
    my $date = shift;

    unless ( $link ) {
	print "$0: reported link is empty<br>";
	return;
    };

    my $WR_REPOS_LINK = '';
    my $WR_REPOS_DATE = $date;

    my ($WR_filebase, $WR_archID, $WR_server, $WR_site, $WR_docroot);
    my ($WR_extPdf, $WR_extAnno, $WR_extMedl, $WR_extBib);
    my ($WR_Pdf, $WR_Anno, $WR_Medl, $WR_Bib);
    my ($encLink, $encWR_Pdf, $encWR_Anno, $encWR_Medl, $encWR_Bib);
    my (@WR_medlIDs, @WR_bibIDs, %WR_recHash);

    my ($WR_PMID, $WR_title, $WR_auth, $WR_auth_first, $WR_auth_last);
    my ($WR_SO, $WR);
    my $Pubmed = 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi';

    # decode the URL in case it contains blanks
    $link = &url_decode($link);
    
    # get URLs and local paths
    $WR_archID   =  ${$self}->{archive_dir};
    $WR_archID   =~ s,.+\/(\d+)$,$1,;
        
    $WR_filebase =  $link;
    $WR_filebase =~ s,(.+)\.pdf$,$1,i;
    $WR_filebase =~ s,^http:\/\/(.+),$1,i;
    $WR_filebase =~ s,^.+?\/(.+),$1,i;
    
    $WR_extPdf   =  '.pdf';
    $WR_extAnno  =  '.anno';
    $WR_extMedl  =  '.medl';
    $WR_extBib   =  '.bib';
    
    $WR_server   =  $link;
    $WR_server   =~ s,(^http:\/\/.+?)\/.+,$1,;

    $WR_site     = &wgSiteConf::GetSite($WR_server)
	|| die "GetSite failed for link '$link' on sever '$WR_server'!";
    $WR_docroot  = $WR_site->{DocRoot}.'/';

    unless ( -s $WR_docroot.$WR_filebase.$WR_extMedl ) {
	$WR_extMedl = '.ag'.$WR_extMedl;
    }
    unless ( -s $WR_docroot.$WR_filebase.$WR_extBib ) {
	$WR_extBib = '.ag'.$WR_extBib;
    }

    $WR_Pdf      =  $WR_filebase.$WR_extPdf;
    $WR_Anno     =  $WR_filebase.$WR_extAnno;
    $WR_Medl     =  $WR_filebase.$WR_extMedl;
    $WR_Bib      =  $WR_filebase.$WR_extBib;


    # parse medline or bibtex file for PMID and title
    @WR_medlIDs  = ('PMID', 'TI', 'AU', 'SO');
    @WR_bibIDs   = ('PMID', 'title', 'author', 'authors');
    @WR_bibIDs   = ('PMID', 'title', 'author', 'authors', 'journal','volume','number','pages','year');

    if ( -s $WR_docroot.$WR_Medl ) {
	%WR_recHash = &parseMedline($WR_docroot.$WR_Medl, \@WR_medlIDs);
    } elsif ( -s $WR_docroot.$WR_Bib ) {
	%WR_recHash = &parseBibTex($WR_docroot.$WR_Bib, \@WR_bibIDs);
    }

    $WR_PMID  = $WR_recHash{'PMID'};
    $WR_title = $WR_recHash{'TI'};
    $WR_title = $WR_recHash{'title'} unless $WR_title;
    $WR_auth  = $WR_recHash{'AU'};
    $WR_auth  = $WR_recHash{'author'} unless $WR_auth;
    $WR_auth  = $WR_recHash{'authors'} unless $WR_auth;
    $WR_SO    = $WR_recHash{'SO'};
    
    # compile medline SO information from bibtex
    unless ( $WR_SO ) {
	$WR_SO =  $WR_recHash{'journal'}.' '.$WR_recHash{'year'}.'; vol. '.$WR_recHash{'volume'}.'('.$WR_recHash{'number'}.'):'.$WR_recHash{'pages'}.'.';
    }

    # reformat "Sur-One, F. and Sur-Two, F." to "Sur-One F, Sur-Two F"
    if ( $WR_auth =~ m/[A-Z][A-Za-z\-]+, ([A-Z]\. ?)+ and/ ) {
	$WR_auth =~ s/([A-Z][A-Za-z\-]+), ([A-Z]\. ?)+ and /$1 $2, /g;
	$WR_auth =~ s/([A-Z][A-Za-z\-]+), ([A-Z]\. ?)$/$1 $2/;
    }

    # compress long authors lists
    if ( length($WR_auth) > 100 ) {
	($WR_auth_first) = ( $WR_auth =~ m/^(([^,]+,){1,5}).*/ );
	($WR_auth_last)  = ( $WR_auth =~ m/.*,([^,]+)$/ );
	$WR_auth = $WR_auth_first.' ...,'.$WR_auth_last;
    }

    # url encoding for all the links
    $encLink    = &url_encode($link);
    $encWR_Pdf  = &url_encode($WR_Pdf);
    $encWR_Anno = &url_encode($WR_Anno);
    $encWR_Medl = &url_encode($WR_Medl);
    $encWR_Bib  = &url_encode($WR_Bib);

    # create links to files
    if ( $link =~ m,.+pdf$,i ) {
	$WR_REPOS_LINK .=
	    "<a href=\"wrrepos.cgi?ID=$WR_archID&FILE=$encWR_Pdf\" \
	             title=\"Repository\">R</a> ";
    }

    if ( -s $WR_docroot.$WR_Anno ) {
	$WR_REPOS_LINK .=
	    "<a href=\"/$encWR_Anno\" title=\"Annotation\">A</a> ";
    }
    if ( $WR_PMID ) {
	$WR_REPOS_LINK .=
	    "<a href=\"$Pubmed?CMD=search&DB=PubMed&term=$WR_PMID\" \
                title=\"Pubmed\">P</a> ";
    }
    if ( -s $WR_docroot.$WR_Medl ) {
	$WR_REPOS_LINK .=
	     "<a href=\"/$encWR_Medl\" title=\"Medline\">M</a> ";
    }

    if ( -s $WR_docroot.$WR_Bib ) {
	$WR_REPOS_LINK .=
	    "<a href=\"/$encWR_Bib\" title=\"BibTeX\">T</a> ";
    }
    if ( $WR_title ) {
	$WR_REPOS_LINK .=
	    "<a href=\"$encLink\" title=\"$WR_filebase\">$WR_title</a></b><br />";
	$WR_REPOS_LINK .= $WR_auth."<br />" if $WR_auth;
	$WR_REPOS_LINK .= $WR_SO if $WR_SO;
	$WR_REPOS_DATE =  '';

    } else {
	$WR_REPOS_LINK .=
	    "<a href=\"$encLink\">$WR_filebase</a></b>",;
    }

    
    # check parsed variables for debugging
    my $WR_debug = 0;
    if ( $WR_debug ) {
	print
	    "<pre><font size=-1>",
	    "link:          $link<br />",
	    "WR_server:     $WR_server<br />",
	    "WR_docroot:    $WR_docroot<br />",
	    "WR_archID:     $WR_archID<br />",	
	    "WR_Pdf:        $WR_Pdf<br />",
	    "WR_Anno:       $WR_Anno<br />",
	    "WR_Medl:       $WR_Medl<br />",
	    "WR_Bib:        $WR_Bib<br />",
	    "WR_PMID:       $WR_PMID<br />",
	    "WR_title:      $WR_title<br />",
	    "WR_REPOS_LINK: $WR_REPOS_LINK<br />";
	

	print Data::Dumper->Dump([$WR_site
				  ],
				 ['WR_site'
				  ]);
	print "</font></pre>";
    }

    return ($WR_REPOS_LINK, $WR_REPOS_DATE);
}



sub checkSysReturn {
    my ($msg)=@_;

    if ($? == -1) {
	print "$0: Failed to execute system call:\n  $!\n";
	print "Message...\n$msg\n...ends.\n";

    } elsif ($? & 127) {
	printf("$0: System process died with signal %d, %s coredump.\n",
	       ($? & 127),  ($? & 128) ? 'yielding a' : 'without a');
	print "Message...\n$msg\n...ends.\n";
    }
    
}



sub startReindexing {

    my $ArchDir = shift;
    my $ArchID  = shift;

    my ($retval, $exitCode);

    $retval   = system("$ArchDir/wgreindex -q >/dev/null 2>&1 &");
    &checkSysReturn("ArchDir=$ArchDir, ID=$ArchID");
    $exitCode = ($retval>>8);

    if ( $exitCode ) {
	print
	    "$0: Non-zero exit code $exitCode from system process!\n",
	    "Call: '$ArchDir/wgreindex -q'\n";
	return 0;
    } else {
	return 1;
    }
}



sub parseAnnoStr {

    my $AnnoStr     = shift;
    my $AnnoClasses = shift;
    my $AnnoSep     = shift;
    my $User        = shift;

    my @AnnoClasses = keys(%$AnnoClasses);
    my (@AnnoStrBack, @AnnoRs, @AnnoCs, @AnnoEs, @AnnoCatKeys);
    my ($AnnoHtml, $AnnoStrDisp, $AnnoR, $AnnoMeanR, $AnnoUserR, $AnnoCategs, $AnnoC, $AnnoLastE, $AnnoStrBack);
    
    $User =  'nobody' unless ( $User );

    # split the annotation into visible and hidden part
    ($AnnoStrDisp, $AnnoStrBack) = ( $$AnnoStr =~  m/^(.*?)\n$AnnoSep(.+)$/s );
    $AnnoStrDisp = $$AnnoStr if ( $$AnnoStr &&  $$AnnoStr !~  m/$AnnoSep/s );

    # display anno with correct newlines
    $AnnoHtml =  $AnnoStrDisp;
    $AnnoHtml =~ s/\n/\<br\>/g;

    # very long annotations
    if ( length($AnnoHtml) > 1000 ) {
	$AnnoHtml =~ s/((\S+\s+){200}).*/$1\.\.\./g;
    }

    # split annotation's background fields into its bits and parts
    @AnnoStrBack = split("\n",$AnnoStrBack);

    # make arrays containing all the individual annotation fields
    foreach (@AnnoStrBack) {
	chomp;
	s/\s*$//;
	push(@AnnoRs, $_) if m/^R_\w+_\d/;
	push(@AnnoCs, $_) if m/^C_\w+_\d/;
	push(@AnnoEs, $_) if m/^\[ Edited by.+/i;
	$AnnoUserR = $_ if m/^R\_$User\_\d/i;
    }
    
    $AnnoUserR =~ s/R\_$User\_(\d)/$1/ if ( $AnnoUserR );

    # compute average rating
    foreach (@AnnoRs) {
	($AnnoR)    = ( $_ =~ m/.+(\d)$/ );
	$AnnoMeanR += $AnnoR if ( $AnnoR );
    }
    $AnnoMeanR /= ($#AnnoRs + 1) if ( $#AnnoRs + 1 > 0 );
    $AnnoMeanR =~ s/([\d\.]{3}).+/$1/;

    # get all the ticked categories
    foreach $AnnoC (@AnnoCs) {
	foreach (@AnnoClasses) {
	    if ( $AnnoC =~ m/.+$_\_1$/ ) {
		$AnnoCategs .= "$$AnnoClasses{$_}, ";
		push(@AnnoCatKeys, $_);
	    }
	}
    }
    $AnnoCategs =~ s/^[\s,]+//;
    $AnnoCategs =~ s/[\s,]+$//;

    $AnnoLastE = $AnnoEs[$#AnnoEs];
    
    return ($AnnoStrDisp, $AnnoHtml, $AnnoStrBack, \@AnnoRs, \@AnnoCs, \@AnnoEs, $AnnoMeanR, $AnnoUserR, $AnnoCategs, \@AnnoCatKeys, $AnnoLastE);
}



sub buildNewAnnoBack {

    my $AnnoRs      = shift;
    my $NewRate     = shift;
    my $AnnoClasses = shift;
    my $NewCateg    = shift;
    my $AnnoEs      = shift;
    my $User        = shift;

    my @AnnoClasses = keys(%$AnnoClasses);    
    my $time        = localtime();
    my $AnnoMeanR   = 0;
    my $c           = 0;

    my ($NewAnnoBack, $AnnoR, $Rate, $AnnoCs, $AnnoClass, $i);


    # add old ratings
    foreach $AnnoR (@$AnnoRs) {
	unless ( $AnnoR =~ m/^R\_$User\_\d$/ ) {
	    ($Rate)       =  ( $AnnoR =~ m/.+(\d)\s*$/ );
	    $AnnoMeanR   +=  $Rate;
	    $NewAnnoBack .=  "$AnnoR\n";
	    $c++;
	}
    }

    # add new rating if so
    if ( $NewRate ) {
	$AnnoMeanR   += $NewRate;
	$NewAnnoBack .= "R\_$User\_$NewRate\n" ;
    }    

    # extra line with average rate: aR_1.5
    $AnnoMeanR   /= ($c + 1);
    $AnnoMeanR   =~ s/([\d\.]{3}).+/$1/;
    $NewAnnoBack .= "aR\_$AnnoMeanR\n";

    # add categories
    foreach $AnnoClass (@AnnoClasses) {
	$AnnoCs = "C\_$AnnoClass\_0";
	foreach (@$NewCateg) {
	    $AnnoCs = "C\_$AnnoClass\_1" if ( m/^$AnnoClass$/ );
	}
	$NewAnnoBack .= "$AnnoCs\n";
    }

    # add the last 10 edit history entries
    for ($i = ($#{@$AnnoEs} - 8); $i <= $#{@$AnnoEs}; $i++) {
	$NewAnnoBack  .=  "$$AnnoEs[$i]\n" if ( $i >= 0 );
    }
    
    $NewAnnoBack  .=  "[ Edited by $User, $time ]\n";

    return $NewAnnoBack;
}



1;
