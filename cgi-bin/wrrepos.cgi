#!/usr/bin/perl -wT

# wrrepos.cgi creates a repository entry for a .pdf file
# including title, authors, abstract, and online editable 
# annotation given that corresponding Medline (.medl), 
# BibTeX (.bib) and Annotation (.anno) files are available.
# webglimpse archive ID and the filename need to be
# passed to repos.cgi via URL parameters:
#
# http://serv.er:1234/cgi-bin/wg2/wrrepos.cgi?ID=1&FILE=dir/file.pdf
# 
# the webglimpse library path needs to be specified below,
# since wrrepos.cgi builds on several webglimpse elements.
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
    use wgConf;
    use wrRepos;
}


# define valid categories and get flags
my ($flagRatings, $flagCategories);
my ($AnnoSep, %AnnoClasses, @AnnoClasses);

($flagRatings, $flagCategories) = &wrRepos::flagCategoriesAndRatings();
%AnnoClasses = %{&wrRepos::defineCategories()};
@AnnoClasses = keys(%AnnoClasses);
$AnnoSep     = 'HIDDENANNOTATIONFIELDS';

# parse parameters
my ($Prot, $Host, $Port, $Path, $ServerFull, $FileFull, $FilePath, $FileBase, $FileExt, $WebFileBase, $EscWebFileBase, $LocFileBase, $EscLocFileBase, $ArchID, $Referer, $hReferer, $hAnnoTime, $Owner, $AnnoStrBack);

($Prot,$Host,$Port,$Path) = &url::parse_url($q->self_url());
$Path       =~ s,\/(.+?)\/wrrepos\.cgi.*,$1,i;
$ServerFull =  $Prot.'://'.$Host.':'.$Port;

$FileFull    =  $q->url_param('FILE');
$ArchID      =  $q->url_param('ID');
$Referer     =  $q->referer();
$hReferer    =  $q->param('hidden_Referer');
$hAnnoTime   =  $q->param('hidden_AnnoTime');
$AnnoStrBack =  $q->param('hidden_AnnoStrBack');


# test for validity of parameters
unless ( $ServerFull ) {die "ERROR: parse_url failed"};
unless ( $FileFull || $q->param(-name=>'Button_Upload') eq 'Upload') {
    $q->param(-name=>'Button_Upload',-default=>'New');
}
unless ( $ArchID ) {
    print 
	"<span style=\"color: green\"><pre><font size=3>",
	"WARNING: No archive ID specified in URL! <br />",
	"         Using default ID=1. <br />",
	"</font></pre></span>";
    $ArchID = 1;
}


# select correct Referer for WebGlimpse link
if ( $hReferer ) {
    $q->param(-name=>'hidden_Referer',-default=>"$hReferer");
} elsif ( $Referer =~ m/.+webglimpse\.cgi.+/i ) {
    $q->param(-name=>'hidden_Referer',-default=>"$Referer");
} else {
    $q->param(-name=>'hidden_Referer',-default=>"wrsearch.cgi?ID=$ArchID");
}
$hReferer = $q->param('hidden_Referer');


# parse filename (better no dots in filename)
$FileFull =~ s,(.+)(\..+?)$,$1,;
$FileExt  =  $2;

$FileFull =~ s,(.+)/([^/]+)$,$1,;
$FileBase =  $2;

$FilePath =  $FileFull;

$FileExt    =~ s,\.\w{3}\.\d+\.suppl$,\.pdf,i;
$WebFileBase=  $ServerFull.'/'.$FilePath.'/'.$FileBase;

($Owner)    =  ( $FilePath =~ m,.*/([^/]+)$, );


# load environmental variables
my ($User, $UserHost, $UserAddr, $time);
my ($wSite, $mArch, $DocRoot, $ArchDir, $startDir, $startURL, $uploadDir, $uploadURL, @allRootDirs, @allRootURLs, %oneRoot, $oneRoot, $allRoots);

$User       =  $q->remote_user();
$UserHost   =  $q->remote_host();
$UserAddr   =  $q->remote_addr();
$time       =  localtime();

# REable user for Annos unless the remote user works
$User       =  $UserHost unless $User;
$User       =~ s/\.//g;
$User       =~ s/ //g;

$wSite      =  &wgSiteConf::GetSite($ServerFull) || die "GetSite failed!";
$mArch      =  &wgConf::GetArch($ArchID) || die "GetArch failed!";
&wgArch::LoadRoots($mArch) || die "LoadRoots failed!";

$DocRoot    =  $wSite->{'DocRoot'};
$ArchDir    =  $mArch->{'Dir'};
$LocFileBase=  $DocRoot.'/'.$FilePath.'/'.$FileBase;

#take the first Root entry as uploaddir
$startDir   =  $mArch->{'Roots'}[0]{'StartDir'};
$startURL   =  $mArch->{'Roots'}[0]{'StartURL'};
$uploadDir  =  $mArch->{'Roots'}[0]{'StartDir'};
$uploadURL  =  $mArch->{'Roots'}[0]{'StartURL'};
$uploadURL  =~ s,^.+?\/\/.+?\/(.+),$1,;

#make an array with all the other Roots of this archive
$allRoots = $mArch->{'Roots'};
foreach $oneRoot ( @$allRoots ) {
    %oneRoot = %$oneRoot;
    push(@allRootDirs, $oneRoot{'StartDir'});
    push(@allRootURLs, $oneRoot{'StartURL'});
}

# extra escaping for system calls
$EscLocFileBase =   $LocFileBase;
$EscLocFileBase =~ s/(\W)/\\$1/g;

$EscWebFileBase =  $WebFileBase;
$EscWebFileBase =~ s/(\W)/\\$1/g;


# check for personal upload directory via .htaccess name
my ($personalDir, $retval, $exitCode);

if ( $ENV{'REMOTE_USER'} ) {
    $personalDir =  $uploadDir.'/'.$User;
    
    unless ( -d $personalDir ) {	
	$retval=system("mkdir $personalDir >/dev/null 2>&1");
	&wrRepos::checkSysReturn("personalDir=$personalDir");
	$exitCode=($retval>>8);
	print("$0: Non-zero exit code $exitCode from system process!\n",
	      "Call: 'mkdir $personalDir'\n")
	    if $exitCode;
    }

    if ( -d $personalDir && -w $personalDir) { 
	$uploadDir .= '/'.$User;
	$uploadURL .= '/'.$User;
    }

}


# check environmental variables for debugging
my $debug = 0;
my $key;

if ( $debug ) {
    print
	"<pre><font size=-1>",
	"Server with Port:   $ServerFull <br />",
	"Filename Web    :   $WebFileBase$FileExt <br />",
	"Filename Local  :   $LocFileBase$FileExt <br />",
	"Hidden Referer  :   $hReferer <br />",
	"Hidden AnnoTime :   $hAnnoTime <br />",
	"<br />";
    print Data::Dumper->Dump([$wSite
			    ],
			   ['wSite'
			    ]), "<br />";
    print Data::Dumper->Dump([$mArch
			      ],
			     ['mArch'
			      ]), "<br />";
    foreach $key (keys %ENV) {
	print "$key --> $ENV{$key}<br>";
    }
    print "</font></pre>";
}


# create links to .pdf, .anno, .medl, .bib
my ($AnnoExt, $MedlExt, $BibExt, $SupplExt);
my ($WebPdf, $WebAnno, $WebMedl, $WebBib);
my ($LocPdf, $LocAnno, $LocMedl, $LocBib, $LocIndx);
my ($GenPdf, $GenPath);
my $pdfMsg = '';

$AnnoExt  =  '.anno';
$MedlExt  =  '.medl';
$BibExt   =  '.bib';
$SupplExt =  '.suppl';

$MedlExt  = '.ag'.$MedlExt unless ( -e "$LocFileBase$MedlExt");
$BibExt   = '.ag'.$BibExt unless ( -e "$LocFileBase$BibExt");

$WebPdf   = $WebFileBase.$FileExt;
$WebAnno  = $WebFileBase.$AnnoExt;
$WebMedl  = $WebFileBase.$MedlExt;
$WebBib   = $WebFileBase.$BibExt;

$LocPdf   = $LocFileBase.$FileExt;
$LocAnno  = $LocFileBase.$AnnoExt;
$LocMedl  = $LocFileBase.$MedlExt;
$LocBib   = $LocFileBase.$BibExt;
$LocIndx  = $LocFileBase.'.ag.txt';

($GenPdf) = ( $LocPdf =~ m,^$startDir/(.+), );
($GenPath)= ( $GenPdf =~ m,(.+)/[^/]+$, );
$GenPdf   = $FileBase.$FileExt unless $GenPdf;
$GenPath  = $FilePath unless $GenPath;


# create string of links to supplementary files path/bla.bal.{pdf,txt}.01.suppl
my (@LocSuppl, $SupplFull, $SupplNum, $SupplLinks, $EscSupplExt, $encSupplLink);

$EscSupplExt = $SupplExt;
$EscSupplExt =~ s,\.,\\\.,g;

@LocSuppl = glob("$EscLocFileBase".'*.suppl');

foreach (@LocSuppl) {
    ($SupplFull) = ( m,.+/([^/]+)$, );
    ($SupplNum)  = ( $SupplFull =~ m,.+?(\.\w+\.\d+$EscSupplExt)$,);
    $encSupplLink= &wrRepos::url_encode("$WebFileBase$SupplNum");
    $SupplLinks .=
	"<br />".
	$q->a({-href=>"$encSupplLink"},"$GenPath/$SupplFull");
}


# save edited annotation to annofile if not changed on disc
my (@AnnoStat, $AnnoTime, $NewAnno, $NewRate, @NewCateg, $NewAnnoBack);
my ($AnnoStrDisp, $AnnoHtml, $AnnoRs, $AnnoCs, $AnnoEs, @AnnoEs, $AnnoMeanR, $AnnoUserR, $AnnoCategs, $AnnoCatKeys, $AnnoLastE);
my $buffer_AnnoEdt = '';

if ( -s $LocAnno) {
    @AnnoStat  = lstat($LocAnno);
    $AnnoTime  = $AnnoStat[9];
    $hAnnoTime = $AnnoTime unless ( $hAnnoTime );
}

if ( $q->param('Button_Save') eq 'Save' ) {

    if ( $hAnnoTime != $AnnoTime ) {
	$q->param(-name=>'Button_Save',-values=>['']);
	$q->param(-name=>'Button_Edit',-values=>['Edit']);
	$buffer_AnnoEdt = $q->param('AnnoEdt');

    } else {
	$NewAnno = $q->param('AnnoEdt')."\n$AnnoSep\n$AnnoStrBack";
	$NewRate  = $q->param('Rating');
	@NewCateg = $q->param('Category');
	
	($AnnoStrDisp, $AnnoHtml, $AnnoStrBack, $AnnoRs, $AnnoCs, $AnnoEs,
	 $AnnoMeanR, $AnnoUserR, $AnnoCategs, $AnnoCatKeys, $AnnoLastE) = 
	     &wrRepos::parseAnnoStr(\$NewAnno, \%AnnoClasses, $AnnoSep, $User);

	$NewAnnoBack = &wrRepos::buildNewAnnoBack($AnnoRs, $NewRate, \%AnnoClasses, \@NewCateg, $AnnoEs, $User);
	
	$NewAnno = $q->param('AnnoEdt')."\n$AnnoSep\n$NewAnnoBack";

	open(ANNOFH, ">$LocAnno") || die "ERROR: Can not open $WebAnno\!<br />".
	    "Maybe the owner has removed the whole entry $WebPdf.";
	print ANNOFH $NewAnno;
	close(ANNOFH) || die "ERROR: Can not close $WebAnno\!<br />";
	@AnnoStat  = lstat($LocAnno);
	$AnnoTime  = $AnnoStat[9];
    }
}
$q->param(-name=>'hidden_AnnoTime',-default=>["$AnnoTime"]);


# get the MD5sum of the paper if available and check for duplicates
my ($md5sum, @md5sums, $md5file, $md5Links, $WebDupl, $WebDuplStart, $WebDuplRoot, $i, $j, $inRoots);

$md5file = $WGARCHIVE_DIR.'/.wrMD5sums';
$i = 0;
$j = 0;

if ( -s $LocPdf && -s $md5file && not -s $LocIndx ) {
    open(MD5FH,"<$md5file") || die "ERROR: Can not open $md5file\!<br />";
    @md5sums = <MD5FH>;
    close(MD5FH) || die "Can not close $md5file\!<br />";
    
    # get the papers md5sum and its position
    foreach (@md5sums) {
	chomp($_);
	m/^(\w+)\s+(.+)$/;
	if ( $2 eq $LocPdf ) {
	    $md5sum = $1;
	    last;
	}
	$i++;
    }

    # search for duplicates
    if ( $md5sum ) {
	
	foreach (@md5sums) {
	    $j++;
	    chomp($_);
	    m/^(\w+)\s+(.+)$/;
	    $WebDupl = $2;

	    $inRoots = '';
	    foreach (@allRootDirs) {
		$inRoots =  $_ if ( $WebDupl =~ m,$_/, );
		$inRoots =~ s/(\W)/\\$1/g;
		last if ( $inRoots );
	    }

	    if ( $1 eq $md5sum && $WebDupl ne $LocPdf && -s $WebDupl && $inRoots) {
		($WebDuplStart)  = ( $WebDupl =~ m,^$inRoots/(.+),  );
		($WebDuplRoot)  = ( $WebDupl =~ m,^$DocRoot/(.+),  );
		$WebDuplRoot    = &wrRepos::url_encode($WebDuplRoot);
		$md5Links .=
		    $q->startform(-name=>"md5Links$j",
				  -method=>"post",
				  -action=>"wrrepos.cgi?ID=$ArchID&FILE=$WebDuplRoot").
				  $q->a({href=>"javascript:document.forms['md5Links$j'].submit()",title=>"$WebDuplRoot"},"$WebDuplStart").
				  $q->hidden('hidden_Referer').
				  $q->hidden('hidden_AnnoTime').
				  $q->hidden('hidden_AnnoStrBack').
				  $q->endform,
				  "<br />";
	    }
	}
    }
}


# find the corresponding abra file
my (@glimpse_filenames);
my $glimpse = "$ArchDir/.glimpse_filenames";
my $abra = '';

open(GLIMPFH,"<$glimpse") || die "ERROR: Can not open $glimpse\!<br />";
@glimpse_filenames = <GLIMPFH>;
close(GLIMPFH) || die "Can not close $glimpse\!<br />";

foreach (@glimpse_filenames) {
    chomp($_);
    @_ = split("\t", $_);
    if ( $_[1] =~ m/$EscWebFileBase/i ) {
	$abra = $_[0];
	last;
    }
}


# edit corresponding .abra file (get .abra searching .glimpse_filenames)
my @abraTxt;
my ($DelimL, $DelimR, $abraStr, $findDelims, $findLeng, $lengNewAnno, $rmAbras, $rmAbra);

if ( $q->param('Button_Save') eq 'Save' ) {

    # not to interfere with rsync
    do {
	sleep 1;
    } until ( not( -e "$ArchDir/indexing-in-progress" ) );

    open(ABRAFH,"<$abra") || die "ERROR: Can not open $abra\!<br />";
    @abraTxt = <ABRAFH>;
    close(ABRAFH) || die "Can not close $abra\!<br />";
    
    # delimiters as defined in usexpdf.sh
    $DelimL      = 'anno\{\d+\}\:\t';
    $DelimR      = '\nend_of_anno';
    $lengNewAnno = length($NewAnno);
    $abraStr     = join('', @abraTxt);

    $findDelims  = ($abraStr =~ s/($DelimL)(.*?)($DelimR)/$1$NewAnno$3/s);
    ($findDelims) || die "ERROR: No proper Annotation in $abra.";
    
    $findLeng  = ($abraStr =~ s/(anno\{)(\d+)(\}\:\t)/$1$lengNewAnno$3/s);
    ($findLeng) || die "ERROR: No proper length Annotation in $abra.";    

    open(ABRAFH,">$abra") || die "ERROR: Can not open $abra\!<br />";
    print ABRAFH $abraStr;
    close(ABRAFH) || die "Can not close $abra\!<br />";

    # write abra to .wrRMabras, that it is newly built by wrwgreindex!
    $rmAbras  = $ArchDir."/.wrRMabras";
    ($rmAbra) = ( $abra =~ m,.*/([^/]+?)$, );

    open(RMABRAFH, ">>$rmAbras") || die "ERROR: Can not open $rmAbras\!<br />";
    print RMABRAFH "$rmAbra\n";
    close(RMABRAFH) || die "ERROR: Can not close $rmAbras\!<br />";

    # start reindexing
    &wrRepos::startReindexing($ArchDir, $ArchID);

    if ( $debug ) {
	print "<pre><font size=-1>";  
	print "abra: $abra<br />";
	print "findDelims: $findDelims<br />";
	print "rmAbras: $rmAbras<br />";
	print "rmAbra: $rmAbra<br />";
	print "</font></pre>";
    }
}


# load annotation from annofile, get time of last change plus all fields
my (@AnnoTxt, $AnnoStr, $AnnoFields);


if ( -s $LocAnno ) {
    open(ANNOFH, "<$LocAnno") || die "ERROR: Can not open $WebAnno\!<br />";
    @AnnoTxt = <ANNOFH>;
    close(ANNOFH) || die "ERROR: Can not close $WebAnno\!<br />";
    chomp(@AnnoTxt);
    $AnnoStr = join("\n",@AnnoTxt);

    ($AnnoStrDisp, $AnnoHtml, $AnnoStrBack, $AnnoRs, $AnnoCs, $AnnoEs,
     $AnnoMeanR, $AnnoUserR, $AnnoCategs, $AnnoCatKeys, $AnnoLastE) = 
	 &wrRepos::parseAnnoStr(\$AnnoStr, \%AnnoClasses, $AnnoSep, $User);

    $AnnoFields = "<br /><table>".
	"<tr>______________</tr>";
    $AnnoFields .= "<tr><td><i>Average Rating:</i></td><td>$AnnoMeanR</td></tr>"
	if ( $flagRatings );
    $AnnoFields .= "<tr><td><i>Categories:</i></td><td>$AnnoCategs</td></tr>"
	if ( $flagCategories );
    $AnnoFields .=
	"<tr><td><i>Last Edit:</i></td><td>$AnnoLastE</td></tr>".
	"</table>";

} else {
    $AnnoStr = 'No annotation available.';
    $AnnoHtml = 'No annotation available.';
    $AnnoFields = '';
}

$AnnoUserR  =  '3' unless ( $AnnoUserR );
$q->param(-name=>"AnnoEdt",-default=>["$AnnoStrDisp"]);
$q->param(-name=>"hidden_AnnoStrBack",-default=>["$AnnoStrBack"]);


# parse TI, AUs, AB and SO from medline file or from bibtex
my ($recPM, $recTI, $recAU, $recAB, $recSO, $PubMed);
my (%recHash, @medlIDs, @bibIDs);

if ( -s $LocMedl ) {
    @medlIDs = ('PMID','TI','AU','AB','SO');
    %recHash = &wrRepos::parseMedline($LocMedl, \@medlIDs);
    $recPM =  $recHash{'PMID'};
    $recTI =  $recHash{'TI'};
    $recAU =  $recHash{'AU'};
    $recAB =  $recHash{'AB'};
    $recSO =  $recHash{'SO'};

} elsif ( -s $LocBib ) {
    @bibIDs = ('PMID','title','author','journal','volume','number','pages','year');
    %recHash = &wrRepos::parseBibTex($LocBib, \@bibIDs);
    $recPM =  $recHash{'PMID'};
    $recTI =  $recHash{'title'};
    $recAU =  $recHash{'author'};
    $recSO =  $recHash{'journal'}.' '.$recHash{'year'}.'; vol. '.$recHash{'volume'}.'('.$recHash{'number'}.'):'.$recHash{'pages'}.'.';
}

if ( $recPM ) {
    $PubMed = 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?CMD=search&DB=PubMed&term=';
    $recPM = $q->a({href=>"$PubMed$recPM"},$recPM);
} else {
    $recPM = 'No PubMed-ID available.';
}

unless ($recTI) {$recTI = 'No title available.'};
unless ($recAU) {$recAU = 'No authors available.'};
unless ($recAB) {$recAB = 'No abstract available.'};
unless ($recSO) {$recSO = 'No Journal available.'};


# upload file of maximum 10MB.
my ($upFile, $upFileTarget, $upFilePdf, $upFileSize, $upFileParent, $upFileChild, $upMsg, $upFileLink, $k);
my $maxFileSize = 10;

$upMsg = '';
if ( $q->param('Button_Upload') eq 'Upload' ) {

    if ( $q->param('File_Upload') ) {
	$upFile = $q->upload('File_Upload');

	$upFileTarget =   $upFile;
	$upFileTarget =~  s/ /_/g;
	$upFilePdf    =   $upFileTarget;
	
	$upFileSize   = ( -s $upFile );
	$upFileParent = ( $upFile =~ m/.+\.pdf$/ );
	$upFileChild  = ( $upFile =~ m/.+\.anno$/ ||
			  $upFile =~ m/.+\.medl$/ ||
			  $upFile =~ m/.+\.bib$/  ||
			  $upFile =~ m/.+\.suppl$/ );

	# get parent pdf file name
	if ( $upFile =~ /.+\.suppl$/ ) {
	    $upFilePdf =~  s/\.\w{3}\.\d+\.suppl/\.pdf/;

	} elsif ( $upFileChild ) {
	    $upFilePdf =~  s/\.\w+?$/\.pdf/;
	}
	
	# check for validity of filename and for existing parent
	if ( $upFile =~ m/.*\s.*/ ) {
	    $upMsg = "WARNING: Replaced spaces in filename through underscores!<br />";
	}
	
	if ( $upFile =~ m/[^A-Za-z0-9\-\_\.]+/ ) {
	    $upMsg = "ERROR: Filenames may only contain [A-Za-z0-9-_.]<br />";   

	} elsif ( not( $upFileParent ) && not( $upFileChild ) ) {
	    $upMsg = "ERROR: Not a valid file extension!<br />";   

	} elsif  ( $upFileSize > ($maxFileSize * 2**20) ) {
	    $upMsg = "ERROR: $upFile exceeds $maxFileSize MB!<br />";   

	} elsif ( -s "$uploadDir/$upFile" ) {
	    $upMsg =  "ERROR: Filename already exists- rename!<br />";
	
	} elsif ( $upFileChild && not( -s "$uploadDir/$upFilePdf") ) {
	    print "upFilePdf: $upFilePdf<br>";
	    $upMsg =  "ERROR: Upload $upFilePdf first, before uploading a child file!<br />";
	}

	if ( $upMsg =~ m/^ERROR/ ) {
	    close($upFile) || die "ERROR: Can not close $upFile!<br />";
	}

    } else {
	$upMsg = "ERROR: Select a file!<br />";
    }
    
    if ( $upMsg =~ m/^ERROR: / ) {
	$upMsg = $q->span({-style=>'Color: green;'},$upMsg);
    }

    # if filename is okay proceed with upload
    if ( $upMsg !~ m/ERROR/ ) {

	# in case of children files find parent file first
	if ( $upFileChild ) {
	    $abra = '';
	    $k = 0;
	    do {
		open(GLIMPFH,"<$glimpse") || die "ERROR: Can not open $glimpse\!<br />";
		@glimpse_filenames = <GLIMPFH>;
		close(GLIMPFH) || die "Can not close $glimpse\!<br />";

		foreach (@glimpse_filenames) {
		    chomp($_);
		    @_ = split("\t", $_);
		    if ( $_[1] =~ m,$uploadURL/$upFilePdf,i ) {
			$abra = $_[0];
			last;
		    }
		}
		
		unless ( $abra ) {
		    $k++;
		    sleep 1;
		}

	    } until ( $abra );
	    
	    $upMsg .= "Had to wait for indexing of parent pdf file before uploading child.<br />"
		if ( $k > 10 );

	    die "ERROR: abra is $abra\?<br />" unless ($abra =~ m/abra$/);

	    # remove parent .abra file
	    $retval=system("rm -f $abra >/dev/null 2>&1");
	    &wrRepos::checkSysReturn("abra=$abra");
	    $exitCode=($retval>>8);
	    print("$0: Non-zero exit code $exitCode from system process!\n",
		  "Call: 'rm -f $abra'\n")
		if $exitCode;

	    $upMsg .= "Found parent $upFilePdf and removed corresponding cache file.<br />";
	}

	# upload file
	open(UPLOADTARGET,">$uploadDir/$upFileTarget")
	    || die "ERROR: Cannot open $uploadDir/$upFileTarget";
	
	if ( $debug ) {
	    print "upFile: $upFile<br />";
	    print "upFileSize: $upFileSize<br />";
	    print "uploadTarget: $uploadDir/$upFileTarget<br />";
	}
	
	binmode $upFile;
	binmode UPLOADTARGET;
	
	while (<$upFile>) {
	    print UPLOADTARGET;
	}
	
	close($upFile) || die "ERROR: Can not close source $upFile!<br />";
	close UPLOADTARGET || die "ERROR: Can not close target $upFileTarget!<br />";

	# start reindexing
	&wrRepos::startReindexing($ArchDir, $ArchID);
	
	$upFileLink   = 
	    $q->startform(-name=>"upFileLink",
			  -method=>"post",
			  -action=>"wrrepos.cgi?ID=$ArchID&FILE=$uploadURL/$upFilePdf").
			  $q->a({href=>"javascript:document.forms['upFileLink'].submit()"},"$upFileTarget").
			  $q->hidden('hidden_Referer').
			  $q->hidden('hidden_AnnoTime').
			  $q->hidden('hidden_AnnoStrBack').
			  $q->endform;
	$upMsg  .= "Successful upload, reindexing in progress:<br />$upFileLink";
	$pdfMsg =  '';
	}
}

# close edit mask without saving if the cancel button was pressed
if ( $q->param('Button_Cancel') eq 'Cancel' ) {
    $q->param(-name=>'Button_Edit',-default=>'');
}


# create the delete file button if user is the owner and if no retrival is running
my $DeleteFileButton = '';

if ( ($User eq $Owner || $User eq 'admin') && not( -s $LocIndx ) && $abra ) {
    $DeleteFileButton = $q->submit(-name=>'Button_Delete',
				   -onClick=>"doDelete(this.form)",
				   -value=>'Delete');
}


# execute the delete file button
if ( $q->param('Button_Delete') eq 'Delete' ) {

    die "ERROR: Cannot delete this record! No .abra file has been produced so far, so indexing is probably still in progress!"
	unless ( $abra );

    # delete the repository files
    $retval=system("rm -f $EscLocFileBase\* >/dev/null 2>&1");
    &wrRepos::checkSysReturn("EscLocFileBase=$EscLocFileBase");
    $exitCode=($retval>>8);
    print("$0: Non-zero exit code $exitCode from system process!\n",
	  "Call: 'rm -f $LocPdf $LocAnno $LocMedl $LocBib'\n")
	if $exitCode;

    # delete the corresponding abra file
    $retval=system("rm -f $abra >/dev/null 2>&1");
    &wrRepos::checkSysReturn("abra=$abra");
    $exitCode=($retval>>8);
    print("$0: Non-zero exit code $exitCode from system process!\n",
	  "Call: 'rm -f $abra'\n")
	if $exitCode;

    # delete the MD5sums entry
    if ( $md5sum && -s $md5file) {
	splice(@md5sums,$i,1);

	open(MD5FH,">$md5file") || die "ERROR: Can not open $md5file\!<br />";
	foreach (@md5sums) {
	    print MD5FH "$_\n";
	}
	close(MD5FH) || die "Can not close $md5file\!<br />";
    }

    # start reindexing
    &wrRepos::startReindexing($ArchDir, $ArchID);
}


# check for existing file to decide which output to make
unless ( -s $LocPdf ) {
    $pdfMsg  = "The file you requested does not exist.<p>";
    $q->param(-name=>'Button_Upload',-default=>'New')
	unless ($q->param(-name=>'Button_Upload') eq 'Upload');
}


# encode all the relevant links to allow for spaces in filenames
my ($encWebPdf, $encWebAnno, $encWebMedl, $encWebBib);

$encWebPdf  = &wrRepos::url_encode($WebPdf);
$encWebAnno = &wrRepos::url_encode($WebAnno);
$encWebMedl = &wrRepos::url_encode($WebMedl);
$encWebBib  = &wrRepos::url_encode($WebBib);



# create the repository website
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

# java script function for delete button confirmation
print 
    "<Script Language=\"Javascript\">\n",
    "<!--\n",
    "function doDelete(mform) {\n",
    "    msg = \"Really delete the whole record?\";\n",
    "    if (confirm(msg)) {\n",
    "        mform.Button_Delete.value='Delete';\n",
    "    } else {\n",
    "        mform.Button_Delete.value='';\n",
    "    }\n",
    "    return true;\n",
    "}\n",
    "//-->\n",
    "</Script>\n\n",
    "</head>\n\n<body>\n\n";

# headline at the top
print
    $q->h3("BibGlimpse Record $FileBase$FileExt"),"\n",
    "<table width=\"100\%\">\n",
    "<tbody align=\"left\" valign=\"top\">\n",
    "<tr>\n",
    $q->td({-width=>"1%"},
	   $q->a({href=>"$hReferer"},"Search&nbsp;Results")), "\n";

if ( $q->param('Button_Upload') eq 'New'   || 
     $q->param('Button_Upload') eq 'Upload') {
    print
	$q->td({-width=>"1%",-align=>"center"}, " | "), "\n",
	$q->td({-width=>"1%"},
	       $q->startform(-name=>"ReposLink",
			     -method=>"post",
			     -action=>"$Referer"), "\n",
	       $q->a({href=>"javascript:document.forms['ReposLink'].submit()",
		      title=>"Last visited record"},
		     "Repository"),"\n",
	       $q->hidden('hidden_Referer'),"\n",
	       $q->hidden('hidden_AnnoTime'),"\n",
	       $q->hidden('hidden_AnnoStrBack'),"\n",
	       $q->endform), "\n";
}

if ( -x $CGIBIN_DIR.'/logout/logout.cgi' ) {
    print
	$q->td({-align=>"right"},
	       "| ",
	       $q->a({href=>"$Prot://logout:logout\@$Host:$Port/$Path/logout/logout.cgi"}, "Logout")), "\n";
}

print
    "</tr>\n",
    "</tbody>\n",
    "</table>\n";

# record specific output
print
    "<div class=results>\n",
    "<table width=\"100\%\">\n",
    "<tbody align=\"left\" valign=\"top\">\n";

if ( $q->param('Button_Upload') eq 'New'   || 
     $q->param('Button_Upload') eq 'Upload' ||
     $pdfMsg ) {

    print
	$q->p,"\n",
	$pdfMsg, "\n",
	$q->Tr($q->td($q->i("Upload .pdf file:")), "\n",
	       $q->td($q->start_multipart_form(), "\n",
		      $q->filefield(-name=>'File_Upload',
			     -size=>30,
			     -maxlength=>80), "\n",
		      $q->submit(-name=>'Button_Upload',
				 -value=>'Upload'), "\n",
		      $q->hidden('hidden_Referer'), "\n",
		      $q->hidden('hidden_AnnoTime'), "\n",
		      $q->hidden('hidden_AnnoStrBack'), "\n",
		      $q->endform)), "\n",
	$q->Tr($q->td(), "\n",
	       $q->td($upMsg)), "\n";


} elsif ( -s $LocPdf ) {
    
    print
	$q->Tr($q->td($q->i("Reprint:")), "\n",
	       $q->td($q->a({href=>"$encWebPdf",
			 title=>"$FilePath/$FileBase"},
			    "$GenPdf"), "\n",
		      $SupplLinks),
	       $q->td($q->startform, "\n",
		      $q->submit(-name=>'Button_Upload',
				 -value=>'New'), "\n",
		      $DeleteFileButton, "\n",
		      $q->hidden('hidden_Referer'), "\n",
		      $q->hidden('hidden_AnnoTime'), "\n",
		      $q->hidden('hidden_AnnoStrBack'), "\n",
		      $q->endform)), "\n";

    if ( ( -s $LocIndx ) || not( $abra ) ) {
	print
	    $q->Tr($q->td(), "\n",
		   $q->td($q->span({-style=>'Color: green;'},
				   "Reindexing in progress, reload page to update..."))), "\n";
    }

    print
	$q->Tr($q->td($q->i("Title:")), "\n",
	       $q->td($q->b($recTI))), "\n",
	$q->Tr($q->td($q->i("Authors:")), "\n",
	       $q->td($recAU)), "\n",
	$q->Tr($q->td($q->i("Journal:")), "\n",
	       $q->td($recSO)), "\n",
	$q->Tr($q->td($q->i("PubMed:")), "\n",
	       $q->td($recPM)), "\n",
	$q->Tr($q->td($q->i("Abstract:")), "\n",
	       $q->td($recAB)), "\n";

    if ( -s $LocAnno ) {
	print
	    $q->Tr($q->td($q->i("Annotation:")), "\n",
		   $q->td($q->a({href=>"$encWebAnno"},
				"$FileBase$AnnoExt"))), "\n";
    } else {
	print 
	    $q->Tr($q->td($q->i("Annotation:")), "\n",
		   $q->td("$FileBase$AnnoExt")), "\n";
    }

    if ( $q->param('Button_Edit') eq 'Edit' ) {
	print 
	    "<tr>", "\n",
	    "<td></td>", "\n",
	    "<td>", "\n",
	    $q->startform, "\n",
	    $q->textarea(-name=>'AnnoEdt',
			 -default=>"$AnnoStrDisp",
			 -rows=>10,
			 -columns=>100), "\n";
	if ( $flagRatings ) {
	    print
		$q->p,
		"<i>Rating (1 for must-read, 5 for never-mind):</i><br />",
		$q->radio_group(-name=>'Rating',
				-values=>['1','2','3','4','5'],
				-default=>$AnnoUserR,
				-labels=>{1=>"1",2=>"2",3=>"3",4=>"4",5=>"5"});
	}
	if ( $flagCategories ) {
	    print
		$q->p,
		"<i>Category:</i><br />",
		$q->checkbox_group(-name=>'Category',
				   -values=>\@AnnoClasses,
				   -default=>$AnnoCatKeys,
				   -labels=>\%AnnoClasses);
	}
	print
	    "</td>", "\n",
	    $q->td($q->submit(-name=>'Button_Save',-value=>'Save'), "\n",
		   $q->reset('Reset'), "\n",
		   $q->submit(-name=>'Button_Cancel',-value=>'Cancel'), "\n",
		   $q->hidden('hidden_Referer'), "\n",
		   $q->hidden('hidden_AnnoTime'), "\n",
		   $q->hidden('hidden_AnnoStrBack'), "\n",
		   $q->endform),
	    "</tr>", "\n";
	if ( $buffer_AnnoEdt ) {
	    print
		$q->Tr($q->td($q->span({-style=>'Color: green;'},
				       "ATTENTION:")), "\n",
		       $q->td($q->span({-style=>'Color: green;'},
				       "Annotation file has been changed on disc. Use your last version below to re-edit!"))), "\n",
		$q->Tr($q->td(), "\n",
		       $q->td("<pre>$buffer_AnnoEdt</pre>")), "\n";
	}
    } else {
	print
	    $q->Tr($q->td(), "\n",
		   $q->td($AnnoHtml,
			  $AnnoFields), "\n",
		   $q->td($q->startform, "\n",
			  $q->submit(-name=>'Button_Edit',-value=>'Edit'), "\n",
			  $q->hidden('hidden_Referer'), "\n",
			  $q->hidden('hidden_AnnoTime'), "\n",
			  $q->hidden('hidden_AnnoStrBack'), "\n",
			  $q->endform)), "\n";
    }

    if ( -s $LocMedl ) {
	print
	    $q->Tr($q->td($q->i("Medline:")), "\n",
		   $q->td($q->a({href=>"$encWebMedl"},
				"$FileBase$MedlExt"))), "\n";
    }
    
    if ( -s $LocBib ) {
	print
	    $q->Tr($q->td($q->i("BibTeX:")), "\n",
		   $q->td($q->a({href=>"$encWebBib"},
				"$FileBase$BibExt"))), "\n";
    }

    if ( $md5Links ) {
	print
	    $q->Tr($q->td($q->i("Duplicates:")), "\n",
		   $q->td($md5Links)), "\n";
    }
}


# credits line at the bottom
print
    "</tbody>\n",
    "</table>\n",
    "</div>\n",
    $q->p, "\n",
    "<div class=\"credits\">Repository by <a href=\"http://www.biotec.boku.ac.at/bioinf.html?&L=1\">Boku Bioinformatics</A> light-weight scientific reprints management.</div>\n",
    "<!-- (c) Boku Bioinformatics 2006 -->",
    $q->end_html, "\n";



