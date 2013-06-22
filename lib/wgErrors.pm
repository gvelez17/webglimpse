package wgErrors;

require Exporter;

use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS );
@ISA = qw(Exporter);

##############################################################
# Error strings and codes used by all modules   
#

@EXPORT = qw( $OK $WARN $ERR_SYSTEM $ERR_NOFILE $ERR_NODIR
	$ERR_NOSTARTURL $ERR_NOTYPE 
	$ERR_INVALIDROOTTYPE $ERR_CANTPARSEURL 
	$ERR_NOSTARTDIR $NEEDSROOTS $NEEDSDIR $ERR_CANTOPENFILE $ERR_CANTWRITETOFILE
	$ERR_NOID $ERR_CANTMAKEDIR $ERR_CANTOPENDIR 
	$ERR_NOROOTURL $ERR_UNKNOWNCMD $NEEDSINDEX $NEEDSDOMAIN $ERR_NOSUCHSITE $INDEXING $ERR_ALREADYEXISTS
	$ERR_NO_GLIMPSE $ERR_NO_GLIMPSEIDX $ERR_NO_WGCONVERT $ERR_BADPASS
 );

BEGIN {
        use wgHeader qw( :general ); 
}

sub NotifyAdmin {
	my $msg = shift;
	my $subject = shift || "Webglimpse error!";

	return(0) if ($ADMIN_EMAIL eq '');

  	open(MAIL, "| $sendmail -t") || return(0);  
	print MAIL <<EOM;
To: $ADMIN_EMAIL
From: Webglimpse server
Subject: $subject

$msg 

EOM
	close MAIL;
	return 1;
}


$OK = 1;
$WARN = 2;

# Generic errors
$ERR_SYSTEM = 10;
$ERR_NOFILE		= 11;
$ERR_CANTOPENFILE	= 12;
$ERR_CANTWRITETOFILE	= 13;
$ERR_NODIR		= 14;
$ERR_CANTMAKEDIR	= 15;
$ERR_CANTOPENDIR	= 16;

# For wgRoot and other URL-related
$ERR_NOSTARTURL = 100;
$ERR_NOTYPE     = 101;
$ERR_INVALIDROOTTYPE    = 102;
$ERR_CANTPARSEURL       = 103;
$ERR_NOSTARTDIR         =104;


# For wgArch, wgConf, wgarcmin
$NEEDSROOTS 	= 200;
$NEEDSDIR	= 201;
$ERR_NOID	= 202;
$ERR_UNKNOWNCMD	= 204;
$NEEDSINDEX     = 205;
$NEEDSDOMAIN    = 206;
$ERR_BADPASS	= 207;
$INDEXING	= 208;

# For wgSite, wgSiteConf
$ERR_NOSUCHSITE = 300;
$ERR_ALREADYEXISTS = 310;

# For Install
$ERR_NO_GLIMPSE = 400;
$ERR_NO_GLIMPSEIDX = 401;
$ERR_NO_WGCONVERT = 402;

1;
