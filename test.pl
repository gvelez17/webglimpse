#!/usr/local/bin/perl

BEGIN {
	unshift @INC,'/w/wg2/lib';
}

BEGIN {
        use wgHeader qw( :makenh :general );
        use wgArch;
        use wgRoot;
        use wgSite;
        use wgSiteConf;
        use AllowDeny;
        use LangUtils;
        use wgAgent;
        require "URL.pl";
}


$_ = $ARGV[0];
print "Working on $_\n";

($n) = normalize('',$_);

print "Result is $n\n";

1;

################################################################################
# NORMALIZE
################################################################################
sub normalize{
   my($baseurl,@urllist)=@_;
   my($basefile, $url);
   
   my($baseprot, $basehost, $baseport, $basepath) = &url::parse_url($baseurl);
   my($prot, $host, $port, $path);  

   $basefile = $basepath;
  
   # Chop off end if contains . (likely is file extension)
   if ($basepath =~ /\.[^\/]+$/) {
	$basepath =~ s/(\/)[^\/]+$/\//;
   }

   if ($basepath !~ /\/$/) {
	$basepath .= "/"; # add the last / for the directory if not there already
   }
   
   foreach $url(@urllist){
	next if($url =~ /^\s*$/);
      # print "Original url: $url\n";
      # punt on the mailtos...
      if($url=~/^mailto:/i) {
	 next;
      }
     
      my $orgurl = $url;
 
      # add things that might be missing.
      # if it starts with //
      if($url=~/^\/\//){
	 # tack on http:
	 $url = "http:".$url;
      }
      # if it has no :// it has no protocol
      if ($url=~/^:\/\//){
	 # tack on http
	 $url = "http".$url;
      }
      
      # Added https as valid protocol 5/2/98 --GB
      # if no protocol,
      if($url!~/^http:/i &&
	 $url!~/^https:/i &&
	 $url!~/^ftp:/i &&
	 $url!~/^gopher:/i &&
	 $url!~/^news:/i){
	 
	 # if no / at beginning, it's relative, on same machine, same path
	 if($url!~/^\//){
            if($url !~ /^#/){  #Added by Renfrew to deal with #ABC mark
           	$url = $baseprot."://".$basehost.":".$baseport.$basepath.$url;
            }else{
           	$url = $baseprot."://".$basehost.":".$baseport.$basefile.$url; 
 	    	#Added by Renfrew
            }
	 }else{	# there is a / at the beginning
	    # it's a new path, same machine
	    $url = $baseprot."://".$basehost.":".$baseport.$url;
	 }
      }

      # added by Renfrew to filter # at the end of file"
      if($url =~ /#$/)
      {
         chop $url;
      }
      # end of added
 
      ($prot, $host, $port, $path) = &url::parse_url($url);

       !defined($path) && (warn "Could not parse $url\n") && next;
      #print "URL after parsing: $prot://$host:$port$path\n";
      
      # make sure the path has a preceding /
      $path = "/$path" if $path!~/^\//;
      
      # remove "/A/.." from "/A/../dir", but not ../..
      while ($path =~ s/\/[^\/\.]+\/\.\.//g) {};

      #do we want to remove leading /.. ? causes errors with some servers
      #while ($path =~ s/^\/\.\.\//\//g) {};

      # remove /?X=Y/ patterns; these are 99% redundant links and will loop
      $path =~ s/\/\?[A-Z]=[A-Z](\/|$)/\//g;

      if ($port == 80) {
	      $url = "$prot://$host$path";
      } else {
	      $url = "$prot://$host:$port$path";
      }
      
      # strip off any #text
      $url =~ s/\#.+$//;

      # Fix entry in linkdesc
      if (($url ne $orgurl) && (exists $LINKDESC{$orgurl}) && (! exists $LINKDESC{$url})) {
            $LINKDESC{$url} = $LINKDESC{$orgurl};
            undef $LINKDESC{$orgurl};
      }     
 
   }
   
   return @urllist;
   
}



###############################################################################
# Library- GET_HREF
###############################################################################
sub get_href	{
   my($file) = @_;
   my ($i, $link, $url, $page);
   my(@links) ;
   my(@lnks);
   
   $page = &readFile($file);

   @links = split(/<A(REA)?[\s]+[^\>]*HREF[\s]*=[\s]*|<FRAME[\s]+[^\>]*SRC[\s]*=[\s]*/i, $page);

   foreach $i (1..$#links)	{
      $link = $links[$i];
      if (($link =~ /^\"([^>\"]*)\"/)||($link =~  /^\'([^>\']*)\'/)||($link=~ /([^>\s]*)/))	{

       	        # GFM fix for commas in links creating problems later 
		# map comma to %2c
		my $href = $1;
       		$href =~ s/,/%2c/g;
                                                                                    
       		#Get link text # Note doesn't work for FRAME SRC= tags
                if ($link =~ /^[^>]*>(.+?)<\/A/is) {
                       $LINKDESC{$href} = $1;
                }

		push(@lnks, $href);
      }
   }
   return @lnks;
}


sub readFile {
   my($file) = @_;
   local(*FH);
   my @page = ();
   my($string);
   
   if (open (FH, $file)) {
	   @page = <FH>;
	   close FH;
   } else {
	 warn "Cannot open file $file: $@";
	 @page = ();
   }
   $string = join("",@page);
   return $string;
}


########################################################################
## new_traverse
##
## Recursively follows $numhops levels of links from $url (locally $file)
########################################################################
sub new_traverse {

	my ($url, $file, $indextrunk) = @_;
	my (@thelist);


$mRoot->Validate || print("Lost mRoot in new_traverse!!\n\n");

	# TODO avoid using global mRoot variable
	my $numhops = $mRoot->Get('Hops');

  	#Clean out any recursion in the path
	$url =~ s/(^|\/)(\.(\/|$))+/$1/g;     

	#Fix commas in the URL
	$url =~ s/,/%2c/g;

	if (&wgSiteConf::IsLocal($url)) {
	        # just get the local file name
		$file = &wgSiteConf::LocalURL2File($url);
	        if (! $URL2FILE{$url}) { $NumLocalCollected++; }
        	if(!(-e $file)){
       			logErr("Cannot find $url as $file. Not traversing. 1");
	        	next;
        	}

	} else {

	        # if remote file, go get it!
		my $usite = &wgSiteConf::GetSiteFromURL($url) || 0;
        	$file = &geturl2file($url, $usite);
	        # geturl2file puts it into URL2FILE map
    	}

	push(@thelist, $url);
	$URL2FILE{$url} = $file;

	# We may or may not want to actually index the starting URL
	# This hash should only affect the list for glimpseindex
	if ($indextrunk) {
		$TOINDEX{$file} += 1;
	}

	# Don't assume 1st link is local.  Could start with remote URL.
	# $NumLocalCollected+=1;

   
	if (!$quiet) { print "Traversing $numhops hops...\n"; }
	for($i=0; $i<$numhops; $i++){

		if ($STATSON) {
                	$onLevel=$i;
                	&rewindLeafIDs($onLevel)
		}

		# visit the nodes in the list
		@thelist = visit(@thelist);

		# if there's nothing more to collect, stop there
		my($numlinks);
		$numlinks = @thelist;
		if($numlinks==0) {
			if (!$quiet) { print "No more links to traverse.\n"; }
			last;
		}
		if (($NumLocalCollected >= $mRoot->{MaxLocal}) && ($NumRemoteCollected >= $mRoot->{MaxRemote})) {
			if (!$quiet) { print "Collected maximum # of links.\n"; }
			last;
		}                                                                                 

   	}
}


sub visit{ 
	my(@urllist) = @_;
	my($file);
	my(%ToTraverse);

	my($url, $urlstat, $linkstat, $at_remote, @links, $link);
	my($noindex, $found, $i, $pattern, $allowdeny);
	my($filename,$link_site, $url_site);	 

	foreach $url (@urllist) {

		if ($STATSON) {
	                $leafids[$onLevel]++;
	                &rewindLeafIDs($onLevel + 1);
		}

                # We might have munged the URL for security before storing it
                $url = SecureURL($url);

		$file = $URL2FILE{$url};

		#	 print "Looking at url: $url, file: $file\n";

		# figure out whether this page is local or remote
		$urlstat = &wgSiteConf::CheckURL($url,$file);

		@links = split(",",getlinks($file,$url));
	        #######
        	# if ONLY gathering stats, delete files as we go
                if (($STATSONLY)&&($file =~ /^$REMOTEDIR/)) {  # CHECK IF IS OUR OWN FILE FIRST - if not starting with REMOTEDIR could be a real local file
                        unlink($file);
                }
        	#################

		# for each link,
		foreach $link(@links){

			if ($STATSON) {
				$leafids[$onLevel + 1]++;
			}

			#Added by bgopal for testing purposes: Nov 22/1996: 3.15pm
			if(($link eq "1") || ($link eq " ")) {
				next;
			}

			#Clean out any recursion in the path
			$link =~ s/(^|\/)(\.(\/|$))+/$1/g;     

			if ($mAdIndex->OkayToAddFileOrLink($link)==0){
				logMsg("Not indexing $link; excluded.");
				next;
			}
	 
			# Check if link is local, remote, or ?
			$linkstat = &wgSiteConf::CheckURL($link);

			# Check rules for this root, should we index this link based on local/remote?
			if (! $mRoot->CheckRules($url, $link, $urlstat, $linkstat) ) {
				if (!$quiet) {
					print "Skipping url based on checkrules: $link:$urlstat:$linkstat.\n"; 
				}
				next;
			}

			$filename="";



			if($linkstat==$URL_LOCAL){

			        # just get the local file name
				$filename = &wgSiteConf::LocalURL2File($link);

				if(!(-e $filename)){
					logErr("Cannot find $link as $filename. Not traversing. 3");
					next;
				} elsif ( -d $filename) {
					$linkstat = $URL_SCRIPT;
				} else {
					if($NumLocalCollected >= $mRoot->{MaxLocal}){
						logMsg("Cannot collect $link; already collected local maximum.");
					} else {
						if (! $URL2FILE{$link}) {
							$URL2FILE{$link}=$filename;
							$NumLocalCollected +=1;
						}
					}
				} 
					
			} 

			# Gather the link as a remote URL, either because it is remote or it is a script, or its a directory we found from LocalURL2File
			if(($linkstat==$URL_REMOTE)||($linkstat==$URL_TRAVERSE)||($linkstat==$URL_SCRIPT)){
				if (!$quiet) {	 
					print "Url $link is remote...\n"; 
				}

				# check that we haven't already gotten max
				if(($NumRemoteCollected >= $mRoot->{MaxRemote})&&($urlstat==$URL_REMOTE)){
					logErr("Cannot collect $link; already got maximum number of remote links.");
					next;
				}

  				#logMsg("File $link is remote.");
				if (! $quiet) {
					print "Getting remote url: $link\n";
				}


				# PROBLEM - sometimes we get the same remote file many times!

				# if remote file, go get it!

				my $usite = &wgSiteConf::GetSiteFromURL($link) || 0;
        			$filename = &geturl2file($link, $usite);
				# geturl2file puts it into URL2FILE map

			} 
			elsif($linkstat != $URL_LOCAL) {
				logMsg("Error with $link : status is $linkstat");
				next;
			}
	 
   			# if we haven't already seen this file, add it to the list
	 		#   to index, and add it to traversal list
			if(($filename ne "") && !defined($TOINDEX{$filename}) || ($TOINDEX{$filename}<1)){
				# add the file name to the list of files to index
   				$TOINDEX{$filename}=1;  # use an assoc array to remove dups

       				# push onto the list to traverse
				if ($mRoot->CheckTraverse($link, $linkstat)) {
					$ToTraverse{$link}=1;  # hash to remove dups
				}
			} elsif ($filename ne "") {	# We've seen it before, add one to its link pop rating
				$TOINDEX{$filename}++;
			}
	    
	    		if (defined($FILELINKS{$file})) {
				$FILELINKS{$file} .= ",$filename";
			} else {
				$FILELINKS{$file} = $filename;
			}
		}

		# Added by bgopal, Nov 14 1996
		undef @links;
		@links = ();
	}

	my(@TraverseQ) =  keys(%ToTraverse);
	return @TraverseQ;
}


#####################################################################
#	Exit routine
#####################################################################
sub CleanUp {
	if ((-d $TMPREMOTEDIR)) {
		system("rm -f $TMPREMOTEDIR/*; rmdir $TMPREMOTEDIR");
	}

	# remove the robots file
	system("rm -f $TEMPROBOTFILE");
}

#####################################################################
#	Initialize routine
#####################################################################
sub Initialize{

# move the .remote directory to temp location if found
if ((-d $REMOTEDIR)|| (-d $CACHEDIR)){

   %OLDURL2FILE = ();

   # look up old file/url mappings from last reindexing
   if (-e $MAPFILE ) {
	open(F, $MAPFILE);
	while(<F>) {
		chomp;
		@_ = split($FILE_END_MARK);

		# if this was a remote file we retrieved, we may reuse it
		if ($_[1] =~ s/$REMOTEDIR/$TMPREMOTEDIR/) {
			$OLDURL2FILE{$_[0]} = $_[1];
		}

		# also if its a cache entry
		elsif ($_[1] =~ /$CACHEDIR/) {
			$OLDURL2FILE{$_[0]} = $_[1];
		}
	}
	close F;
   } 


   if (-d $REMOTEDIR) {
   	# Move directory to temporary location
   	if ((-d $TMPREMOTEDIR)) {
		system("rm -f $TMPREMOTEDIR/*; rmdir $TMPREMOTEDIR");
   	}
   	`mv $REMOTEDIR $TMPREMOTEDIR`;

   	$quiet || print("Remote directory found.  Will keep files if current.");
   }
}

# make new remote directory

   mkdir($REMOTEDIR, 0755);
   chmod(0755, $REMOTEDIR);

# Initialize variables to avoid warnings

# open logs
&open_logs();

# set the robots file to the archivepwd
$REMOTEDIR = "$archivepwd/$REMOTEDIR";
$CACHEDIR = "$archivepwd/$CACHEDIR";
$TMPREMOTEDIR = "$archivepwd/$TMPREMOTEDIR";
$WGINDEX = "$archivepwd/$WGINDEX";
$GFILTERS = "$archivepwd/$GFILTERS";
$MADENH = "$archivepwd/$MADENH";
$FLISTFNAME = "$archivepwd/$FLISTFNAME";
$ERRFILENAME = "$archivepwd/$ERRFILENAME";
$LOGFILENAME = "$archivepwd/$LOGFILENAME";
$MAPFILE = "$archivepwd/$MAPFILE";
$TEMPROBOTFILE = "$archivepwd/$TEMPROBOTFILE";
$WGADDSEARCH = "$archivepwd/$WGADDSEARCH";

($archiveprot, $archivehost, $archiveport, $archivepath) =
   &url::parse_url($archiveurl);
}

########################################################################################
# MakeHttpDate
#
# make a http-compliant date string from epoch seconds
########################################################################################
sub MakeHttpDate {
	my $time = shift;

	my @Days = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu','Fri','Sat');
	my @Months = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

	my ($sec, $min, $hrs, $mday, $mon, $yr, $wday, $yday, $isdst) = gmtime($time);

	my $datestr = sprintf('%s, %2.2d %s %4.4d %2.2d:%2.2d:%2.2d GMT',$Days[$wday],$mday, $Months[$mon],$yr + 1900, $hrs, $min, $sec);

	return ($datestr);
}

# Convert any ' or \ chars to %xx notation for security
# Any other checks we need here?
sub SecureURL {
	my $url = shift;

        # Common source of redundant links
        $url =~ s/[\&\?]PHPSESSID=[a-z0-9A-Z]+$//;

	# why doesn't this work? can't get unpack to behave nicely
	#$url =~ s/([\'\\])/\%unpack("c",$1)/ge;

	$url =~ s/\'/\%27/g;
	$url =~ s/\\/\%5c/g;
	$url =~ s/\,/%2c/g;

	return $url;
}

sub rewindLeafIDs {
        my $startat = shift || 1;  # never rewind level 0
        my $j;
        for ($j=$startat; $j<$MaxHops; $j++) {
                $leafids[$j] = 0;
        }
        return;
}


sub makeLeafID {
        my $retstring = '';
        my $j=0;

        while(($leafids[$j] > 0) && ($j<$MaxHops)) {
                $retstring .= "$leafids[$j++].";
        }
        chop $retstring;
#print "leafids: ", @leafids, " new id is $retstring\n";
        return $retstring;
}


sub getURL {
        my $url = shift;
        my $file = shift;
        my $extra = shift;

        my ($before, $after, $output);

        $before = time;

        $output = `$HTTPGET_CMD \'$url\' -o \'$file\' $extra`;

        $after = time;

        $LastLoadTime = $after - $before;

        return $output;
}



sub logErr {
	$msg = shift;
	my $timestamp = &makeTimeStamp();
	print ERRFILE "$timestamp: $msg\n";
}

sub logMsg {
	$msg = shift;
	my $timestamp = &makeTimeStamp();
	print LOGFILE "$timestamp: $msg\n";
}

sub makeTimeStamp {
   my $timestamp = '';
                                                                                
                                                                                
   my ($sec, $min, $hr, $mday, $mon, $year, $wday, $yday, $isdst) = localtime;
   @_ = gmtime;
   $zone = ($hr - $_[2])*100;
   if ($zone > 1200) { $zone = $zone - 2400; }
   $year += 1900;
   $timestamp = sprintf("%2.2d/%s/%4.4d:%2.2d:%2.2d:%2.2d %4.4d",$mday, $MONTHS[$mon],$year,$hr,$min,$sec,$zone);
   return $timestamp;
}

