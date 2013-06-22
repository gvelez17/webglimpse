; ############################################################################
;#
;#  ftplib.pl - an FTP library
;#
;#  Revision:  1.1L 4/5/95
;#             Luke Y. Lu <ylu@mail.utexas.edu>
;#             add sub gets to get file and return it as a big string.
;#
;#  Revision:  1.1  8/16/94
;#
;#  Authors:   Gene Spafford    <spaf@cs.purdue.edu>
;#             David Sundstrom  <sunds@lobby.ti.com>
;#
;#  Co-Author: Randal Schwartz
;#
;#
;#  This version of ftplib does not use the chat2.pl library.
;#
;#  References:  RFC959 - File Transfer Protocol (FTP)
;#                        J. Postel and J. Reynolds, Oct 1985
;#
;#
;#  NOTE TO SysV USERS:  You need to have sys/socket.ph installed on your
;#   system in order for the arguments to socket to be correct.  Ftplib
;#   will assume BSD defaults for socket if it cannot load socket.ph.  These
;#   defaults will not work on SysV systems.  Run h2ph to create socket.ph.
;#   (Thanks to Andreas Klingler <mfrz06@hp53.rrze.uni-erlangen.de>)
;#
;#   Thanks to Ed Ravin <elr@wp.prodigy.com> for multi-interface fixes
;#
; ############################################################################
#	@(#)ftplib.pl	1.6 4/14/95 (cc.utexas.edu) /home/uts/cc/ccdc/zippy/src/perl/url_get/SCCS/s.ftplib.pl

package ftp;
if ($] < 5.0) {
    eval 'require "sys/socket.ph"';  ## needed to get socket arguments for sys5
} else {
    eval 'use Socket';	## For Perl5
}

; ############################################################################
; ############################################################################
;#                                                                            #
;#  Package Initialization                                                    #
;#                                                                            #
;#  This section is run when the package is required.  Here I initialize      #
;#  package globals.                                                          #
;#                                                                            #
;#                                                                            #
; ############################################################################

INIT: {	

    # get ftp port; I'll use getservbyname, but assume port 21 if it fails
    eval '$Ftp = (getservbyname("ftp", "tcp"))[2]' || ($Ftp=21);
                                                             
    # signals to catch
    @sigs = ('INT', 'HUP', 'TERM', 'QUIT'); 

;#
;# init socket stuff
;#
    
    # format to pack to build argment for socket call
    $Sockaddr = 'S n a4 x8';
    
    # this will contain the address of the command connection
    # which will be used in the bind to the data connection.
    $Cmdaddr = '\0'x4;
    $Cmdname = '\0'x16;

    # get protocol number for tcp, assume 6 if getprotobyname fails
    eval '$Proto = (getprotobyname("tcp"))[2]' || ($Proto=6);

    # fallback on BSD defaults if socket.ph wasn't loaded
    # Of course, if you're running under SYS5, this won't work for you
    # you must have run h2ph to install socket.ph.
    eval '$Inet = &AF_INET' || ($Inet=2);
    eval '$Stream = &SOCK_STREAM' || ($Stream=1);

    
;#
;# "define" (document) package globals
;#

    # filehandles

    # CMD        - socket handle for command channel
    # DATA       - socket handle for accepted data channel
    # GENERIC    - data channel before accept
    # DFILE      - file handle for get/put
           
    # globals

     $User;
     $Password;
     $Host;
     $NeedsClose=0;     # non-zero if a session is open 
     $NeedsCleanup=0;   # non-zero if a file needs to be removed
     @Resp;             # last response from server
     $Ascii=1;          # true if Ascii mode
     $Debug=0;          # if true, print ftp responses to stderr
     $Timeout=60;        # timeout value; 0==infinity

} # end INIT #

;#
;#
;#
;#
  
; ############################################################################
; ############################################################################
;#                                                                            #
;#  User routines                                                             #
;#                                                                            #
;#  These are the functions intended to be callable by the user.  In most     #
;#  cases, undef is returned if there was an error, and some non-zero number  #
;#  if the command was successful.                                            #
;#                                                                            #
;#  The exception to this are functions such as "list" which return an        #
;#  array context.  An empty array may indicate no files, or it may indicate  #
;#  an error condition.  To find out, call ftp'error;  if the return value    #
;#  is not "undef", there was an error.                                       #
;#                                                                            #
;#                                                                            #
; ############################################################################

; ############################################################################
;#   change to ascii file transfer
;#
sub ascii { ## Public 
    $Ascii=1;
    &cmd ("2", "type a");
}

; ############################################################################
;#   change to binary file transfer
;#
sub binary { ## Public
    $Ascii=0;
    &cmd ("2", "type i");
}

; ############################################################################
;#
;#  Close an FTP session

sub close { ## Public
    local($ret);
    return 1 unless $NeedsClose;
    $ret=&cmd("2","quit");
    close CMD;
    undef $NeedsClose;
    &signals(0);
    $ret;
}

; ############################################################################
;#   cd up a directory level
;#
sub cdup { ## Public
    &cmd ("2", "cdup");
}

; ############################################################################
;# change remote directory

sub cwd { ## Public
    &cmd("2", "cwd", @_);
}
  
; ############################################################################
;#
;#  enable (disable) debugging - prints FTP server responses to stderr

sub debug { ## Public
    if ($_[0]) {$Debug=1;} else {$Debug=0;}
1;
}

; ############################################################################
;#  delete a remote file

sub delete { ## Public
    &cmd("2", "dele", @_); 
}

; ############################################################################
;#  get a directory listing of remote directory ("ls -l")

sub dir { ## Public
    &get_listing("list", @_);
}

; ############################################################################
;# 
;#  Get last error message

sub error { ## Public
    $Error;
}

; ############################################################################
;#  get a remote file to a local file
;#    get(remote[, local])
;#

sub get { ## Public
    local($remote, $local) = @_;  
    local($ret, $len)=(0,0);
    local($buf, $rin, $rout, $partial, @buf);
    ($local = $remote) unless $local;

    unless (open(DFILE, ">$local")) {  
       $Error =  "Open of local file $local failed: $!";
       return undef;
    }

    $NeedsCleanup = $local;    # in case of signal
    
    return &xferclean() unless (&dataconn());

    return &xferclean() unless (&cmd("1", "retr $remote"));

    return &xferclean() unless (&ftp_accept());

    vec($rin,fileno(DATA),1) = 1;
    for (;;) {
       if (($Timeout==0) || select($rout=$rin, undef, undef, $Timeout)) {
          last unless($len=sysread(DATA,$buf,1024));
          if($Ascii) { 
             substr($buf,0,0)=$partial;  ## prepend from last sysread
             @buf=split(/\r?\n/,$buf);   ## break into lines
             if ($buf=~/\n$/) { $partial=''; } else { $partial=pop(@buf); }
             foreach(@buf) { print DFILE $_,"\n"; }
          } else {
             last unless ( (syswrite(DFILE,$buf,$len)==$len) );
          }
       } else {
           $Error = "Timeout while recieving data from $Host";
           return &xferclean();
       }
    }

    close DATA;
    close DFILE;
    $ret=&cmd("2");

    if (!defined($len)) {
        $Error = "Error while reading data from server: $!";
        return &xferclean();
    } elsif ($len) {
        $Error = "Error while writing to $local: $!";
        return &xferclean();
    }

    undef $NeedCleanup;
    $ret;

}

; ############################################################################
;#  get a remote file and return it as a possibly huge string.
;#  gets(remote)
;#

sub gets { ## Public
    local($remote) = @_;  
    local($len)=0;
    local($rets)='';
    local($buf, $rin, $rout, $partial, @buf);
    
    return undef unless (&dataconn());

    return undef unless (&cmd("1", "retr $remote"));

    return undef unless (&ftp_accept());

    vec($rin,fileno(DATA),1) = 1;
    for (;;) {
       if (($Timeout==0) || select($rout=$rin, undef, undef, $Timeout)) {
          last unless($len=sysread(DATA,$buf,1024));
          if($Ascii) { 
             substr($buf,0,0)=$partial;  ## prepend from last sysread
             @buf=split(/\r?\n/,$buf);   ## break into lines
             if ($buf=~/\n$/) { $partial=''; } else { $partial=pop(@buf); }
             foreach(@buf) { $rets .= $_ . "\n"; }
          } else {
             $rets .= substr($buf, 0, $len);
          }
       } else {
           $Error = "Timeout while recieving data from $Host";
           return undef;
       }
    }

    close DATA;

    if (!defined($len)) {
        $Error = "Error while reading data from server: $!";
        return undef;
    }

    return &cmd("2") ? $rets : undef;
}

; ############################################################################
;#  Do a simple name list ("ls")

sub list { ## Public
    &get_listing("nlst", @_);
}

; ############################################################################
;#   Make a remote directory

sub mkdir { ## Public
    &cmd("2", "mkd", @_);
}

; ############################################################################
;#
;#  Open an ftp connection to remote host
;#  open(host,[user],[pass],[acct]);
;#
;#  An alternate FTP port may be specified as part of the hostname:
;#     host:port
;#
;#  Examples:   some.machine.com:4444      128.247.85.2:4444

sub open {  ## Public

    if ($NeedsClose) {
	$Error = "Connection still open to $Host!";
	return undef;
    }

    $Host = shift(@_);
    local($user, $password, $acct) = @_;
    local($altport,$ret);
    ($Host,$altport) = split (/\:/,$Host);
    $user = "anonymous" unless $user;
    $password = "-" . $main'ENV{'USER'} . "@" unless $password;
    $Error = '';

    local($destaddr,$destproc);

    ;#
    ;# Build destination address
    ;#

    if ($Host =~ /^(\d+)+\.(\d+)\.(\d+)\.(\d+)$/) {
	$destaddr = pack('C4', $1, $2, $3, $4);
    } else {
	local(@temp) = gethostbyname($Host);
	unless (@temp) {
           $Error = "Can't get IP address of $Host";
           return undef;
        }
	$destaddr = $temp[4];
    }

    ;#
    ;# Connect socket to destination; log in
    ;#

    $destproc = pack($Sockaddr, $Inet, 
                    (defined($altport)?$altport:$Ftp), $destaddr);
    if (socket(CMD, $Inet, $Stream, $Proto)) {
       if (connect(CMD, $destproc)) {

          ### This info will be used by future data connections ###
          $Cmdaddr = (unpack ($Sockaddr, getsockname(CMD)))[2];
          $Cmdname = pack($Sockaddr, $Inet, 0, $Cmdaddr);

          select((select(CMD), $| = 1)[$[]);

          &signals($NeedsClose = 1);
          return undef unless (&cmd("2"));

          unless ($ret=&cmd("23", "user $user")) {
             $Error .= "\nuser command to $Host failed";
             return undef;
          }
               
          return 1 if ($ret eq "2");

          unless ($ret=&cmd("23","pass $password")) {
              $Error .= "\npassword command to $Host failed";
              return undef;
          }
              
          return 1 if ($ret eq "2");

          unless (&cmd("2", "acct $acct")) {
              $Error .= "acct command to $Host failed";
              return undef;
          }

          return 1;
       }
    }

    $Error = "Cannot connect to $Host: $!";
    close(CMD);
    return undef;
}

; ############################################################################
;#  put a local file to a remote file
;#    put(local[,remote])

sub put { ## Public
    local($local, $remote) = @_;  
    local($ret, $len)=(0,0);
    local($buf);
    ($remote = $local) unless $remote;

    unless (open(DFILE, "$local")) {  
       $Error =  "Open of local file $local failed: $!";
       return undef;
    }

    return &xferclean() unless (&dataconn());

    return &xferclean() unless (&cmd("1", "stor $remote"));

    return &xferclean() unless (&ftp_accept());

    if($Ascii) {
       while (<DFILE>) { 
          s/\n$/\r\n/;
          print DATA $_; 
       }
    } else {
       while ( ($len=sysread(DFILE,$buf,1024)) && 
               (syswrite(DATA,$buf,$len)==$len) ) {next;}
    }

    close DATA;
    close DFILE;
    $ret=&cmd("2");

    if (!defined($len)) {
        $Error = "Error while writing data to server: $!";
        return undef;
    } elsif ($len) {
        $Error = "Error while reading from $local: $!";
        return undef;
    }

    $ret;
}

; ############################################################################
;#
;#  Get name of current remote directory

sub pwd { ## Public

    return undef unless (&cmd("2", "pwd"));
    if ($Resp[$#Resp]=~/"([^"]+)/) {   #only return dir if quote delimited
        return $1;                  
    }
    $Resp[$#Resp];

}

; ############################################################################
;#
;#  Rename a remote file

sub rename { ## Public
    local($from, $to) = @_;

    &cmd("3", "rnfr $from") && &cmd("2", "rnto $to");
}

; ############################################################################
;# 
;#  Get last response from server, including lreplies

sub response { ## Public
    @Resp;
}

; ############################################################################
;#
;#  Remove a remote directory

sub rmdir { ## Public
    &cmd("2", "rmd", @_);
}

; ############################################################################
;#
;#  Send a site command - response is returned if no error.

sub site { ## Public
    return () unless &cmd("2", "site", @_);     
    @Resp;
}

; ############################################################################
;#
;#  Timeout - set timeout value; 0==infinity

sub timeout { ## Public
    $Timeout = $_[0];
    $Timeout = 1 if ($Timeout < 0);
1;
}

; ############################################################################
;#
;#  Set transfer type (for compatiblity to old ftplib.pl)

sub type { ## Public
    
    local($type) = @_;

    if    ($type eq 'a' || $type eq 'A') {$Ascii = 1;}
    elsif ($type eq 'i' || $type eq 'I' || $type eq 'l' || $type eq 'L') {$Ascii = 0;}
    else {
       $Error = qq(Type must be "a" for ASCII or "i","l" for binary);
       return undef;
    }

    &cmd("2", "type", $type); 
}


; ############################################################################
; ############################################################################
;#                                                                            #
;#  Support routines                                                          #
;#                                                                            #
;#  These are the functions which support ftplib, and are not intended to     #
;#  be called by the user.                                                    #
;#                                                                            #
;#                                                                            #
; ############################################################################

; ############################################################################
;#
;#  Generate a file listing into an array, for either LIST or NLST

sub get_listing {

    local(@dir,$rin,$rout,$ls);     
    undef $Error;

    return () unless &dataconn();
    unless (&cmd("1", @_) && &ftp_accept()) {
       close DATA;
       return ();
    }

    vec($rin,fileno(DATA),1) = 1;
    for (;;) {
       if (($Timeout==0) || select($rout=$rin, undef, undef, $Timeout)) {
           last unless ($ls=<DATA>);
           $ls=~tr/\r\n//d;
           push(@dir,$ls); 
       } else {
           $Error = "Timeout while retrieving file list from $Host";
           close DATA;
           return ();
       }
    }
                       
    close DATA;

    return () unless &cmd("2");
    @dir;

}

; ############################################################################
;#
;#  Accept a data connection from the server

sub ftp_accept {
    unless(accept(DATA,GENERIC)) {
       $Error = "Can't accept data connection: $!";
       close(DATA); close(GENERIC);
       return undef;
    }                            
1;
}

; ############################################################################
;#
;#  Establish a data socket, send PORT command to server, and listen

sub dataconn {

    local($port, $family, $myportcmd, @myaddr);
    unless ($NeedsClose) {
       $Error = "No connection is open";
       return undef;
    }
    if (socket(GENERIC, $Inet, $Stream, $Proto)) {
       if (bind(GENERIC, $Cmdname)) {
          if (listen(GENERIC, 1)) {
             select((select(GENERIC), $| = 1)[0]);
             ($family, $port, @myaddr) = 
                  unpack("S n C C C C x8", getsockname(GENERIC));
             push(@myaddr, $port >> 8, $port & 0xff);
             $myportcmd = join(',', @myaddr);
             if (&cmd("2", "port $myportcmd")) { return 1; }
          }
       }
    }

    $Error = "$!\nCan't create data socket";
    close GENERIC;
    return undef;
}       

; ############################################################################
;#
;#  response = cmd ( primary_response, args ... )
;#
;#  Send a command to the server, and wait for a reply.  Long replies
;#  are ignored, but are collected for the "response" subroutine.
;#
;#  Only the primary response codes are examined for success or failure.
;#  You pass a string of acceptable codes, any of which will be interpreted
;#  as successful.
;#
;#  The remaining argument(s) are the string to send to the server.  If undefined,
;#  no string is sent, and we just wait for a reply.
;#
;#  The matched primary response code is returned upon success.  undef is 
;#  returned on failure, and $Error holds the error.  
;#  @Resp contains the complete server response.

sub cmd {

    local($code, @cmds) = @_;
    local($rin, $rout, $cmd, $buf, $partial, @buf);

    undef @Resp;
    undef $Error;

    unless ($NeedsClose) {
       $Error = "No connection is open";
       return undef;
    }

    if (defined(@cmds)) {     
       $cmd=join(" ", @cmds);
       print CMD $cmd,"\r\n";
       if ($Debug) {
           if ($cmd=~/^pass/) {
               print STDERR ">> pass .....\n";
           } else {
               print STDERR ">> $cmd\n";
           }
       }
    }
                                          
    vec($rin,fileno(CMD),1) = 1;
    for (;;) {
       if (($Timeout==0) || select($rout=$rin, undef, undef, $Timeout)) {
          unless(sysread(CMD, $buf, 1024)) {
             $Error = "Unexpected EOF on command channel";
             return undef;
          } 
          substr($buf,0,0) = $partial;  ## prepend from last sysread
          @buf=split(/\r?\n/, $buf);  ## break into lines
          if ($buf=~/\n$/) { $partial=''; } else { $partial=pop(@buf); }
          foreach $cmd (@buf) {
             if ($Debug) {print STDERR "<< $cmd\n";}
             push(@Resp,$cmd);
             if ($cmd =~/^\d\d\d[^-]/) {
                if ($cmd=~/^([$code])/) {return $1;}
                $Error = "Unexpected reply: '$cmd' -- expected response '[$code]'";
                return undef;
             } 
          }
       } else {
          $Error = "Timeout while talking to $Host";
          return undef;
       }
    }             


}

; ############################################################################
;#
;#  Clean up a data transfer gone bad

sub xferclean {
    
    close DATA;
    close DFILE;
    if ($NeedsCleanup) {
       unlink($NeedsCleanup);
       undef $NeedsCleanup;
    }        
   return undef;
}

; ############################################################################
;#  
;#  Signal handler.  Close connection and die

sub abort {

    $NeedsClose || die "ftp interrupted by signal.\n";

    print CMD "abor\r\n";
    close DATA;
    close CMD;

    close DFILE;
    unlink($NeedsCleanup) if $NeedsCleanup;
    die;
}

; ############################################################################
;#
;#  Establish signal handlers, but only for signals which haven't already
;#  been changed from "DEFAULT"

sub signals {
    local($flag, $sig) = @_;

    local ($old, $new) = ('DEFAULT', "ftp'abort");
    $flag || (($old, $new) = ($new, $old));
    foreach $sig (@sigs) {
	($SIG{$sig} eq $old) && ($SIG{$sig} = $new);
    }     

}

1;  ## required for packages


