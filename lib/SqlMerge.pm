#!/usr/bin/perl

package SqlMerge;

my $REVISION = '$Id $';

# SqlMerge.pm merges mysql data with Webglimpse full text results
# according to criteria specified in SqlMergeConf.pm
# 

use SqlMergeConf;
use DBI;
use wgHeader;

# can be used to add more precise hits, or modify title/url/date of existing hits

my %DBHASH = ();

my $debug = 0;

1;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;

	$self->{'tags'} = ();

	return $self;
}

############ EDIT THESE ROUTINES #######################################
# TODO: move to Macros module

sub OutputMatches {
	my $self = shift;

	my $aref = $self->{exactmatches};

	return unless ($#$aref >=0 );

	print "<div id=exactmatches>\n";
	print "<i>Exact matches:</i> \n<br>";
	for my $href (@$aref) {
		$self->OutputItem(
		# item fields go here
		# $href->{fieldname}, ...
			);
	}

	print "</div>";
}

sub OutputItem {
	my $self = shift;
	my @fields = @_;


	# now print the fields in some reasonable way

	return;
}
	


sub OutputItemMatches {
	my $self = shift;
	my $itemsref = shift;

	return if ($#$itemsref < 0);

	# print the records in @$itemsref in some reasonable way
	# each record should be an array of field values

	return;
}

sub OutputCatMatches {
	my $self = shift;
	my $catsref = shift;

	return if ($#$catsref < 0);

	# only applies if you have categories

}


#####################################################################


# Connect to dbs and build hash
sub Connect {
	my $self = shift;

	if ($DBNAME) {
		$self->{wgdbh} = DBI->connect("DBI:mysql:$DBNAME",$DBUSER, $DBPASS); 
	}

	for my $href (@DBLIST) {
		my $mdbname = $href->{'DBNAME'};
		my $mdbuser = $href->{'DBUSER'};
		my $mdbpass = $href->{'DBPASS'};
		my $mtag = $href->{'DBTAG'};
		$self->{$mtag} = DBI->connect("DBI:mysql:$mdbname",$mdbuser, $mdbpass);
		push @{$self->{'tags'}},$mtag;
		$DBHASH{$mtag} = $href;
	}
}


sub Disconnect {
	my $self = shift;
		
	for my $mtag (@{$self->{'tags'}}) {
		if (defined($self{$mtag})){
			$self{$mtag}->disconnect;
		}
	}
}

# Get wg_tag results  (for use in CustomOutputTool)
# note the dbtag is totally different/separate from a wg_tag, which is a keyword
sub GetTagMatches {
	my $self = shift;
	my $query = shift; 	# use trimmed query for partial matches
	my $userid = shift;	# we don't know how generated, but we accept if avail

	my $q = "SELECT URL, rank, userid from $WGTABLE where keyword LIKE '%$query%'";
	# TODO HERE

}

# Todo also allow tags by user
sub SetTagMatch {
	my $self = shift;
	my ($keyword, $url, $delta, $user) = @_;

	# check if already in wg_tags
	
	# add if not

	# delta rank if so
}

# TODO: limit by parent cat
# Get SQL results  (for use in CustomOutputTool)
sub GetSQLMatches {
	my $self = shift;
	my $query = shift;	# probably same as above, but in case diff
	my $dbtag = shift || $DEFAULT_DBTAG; 	# which db are we pulling from	

#print "Tag is $dbtag default is $DEFAULT_DBTAG max sql hits is $MAX_SQL_HITS";

	return '' unless (exists $self->{$dbtag});
	my $mdbh = $self->{$dbtag};
	my $dhref = $DBHASH{$dbtag};
	my $q = '';
	if ($dhref->{ALTQUERY}) {
		$q = $dhref->{ALTQUERY};
		my $qq = $mdbh->quote("$query");
		$q =~ s/\[QUERY\]/$qq/;
	} else {
		$q = "SELECT ".$dhref->{SELECTFIELDS}." from ".$dhref->{TABLENAME}." where "
		.$dhref->{MATCHFIELD}." = '$query' LIMIT $MAX_SQL_HITS";
	}
#print "Query is $q";
	$self->{exactmatches} = $mdbh->selectall_arrayref($q, { Slice => {} });

	return $self->{exactmatches};	
}

# Glimpse SQL file (for fast searching of larger text fields)
# File should be produced as ID\tText\n  we return the ID's of matches  
# May be ID\tName\tshort_content
# or may be ID\tRank\tName\tshort_content
# in case of btucson.com this is SHORT_CONTENT
sub GlimpseSQLFile {
	my $self = shift;
	my $query = shift;	# probably same as above, but in case diff

	# should be sanitized, but double-check it has no ' chars
	$query =~ s/\'//g;

	my $catfind_cmd = "$GLIMPSE_LOC -H $DB_DUMP_DIR -i -w -h -y -L $MAX_CATS -F $CAT_DATA_FILE '$query' |";
	my $itemfind_cmd = "$GLIMPSE_LOC -H $DB_DUMP_DIR -i -w -h -y -L $MAX_ITEMS -F $ITEM_DATA_FILE '$query' |";

#print " commands are $catfind_cmd and $itemfind_cmd <br> ";

        # Fool perl -T into accepting $cmd for execution.  (as per Peter Bigot) --GB 10/17/97
        # We assume that we have sufficiently checked the parameters to be safe at this point.
        $catfind_cmd =~ /^(.*)$/;
        $catfind_cmd = $1;
        $itemfind_cmd =~ /^(.*)$/;
        $itemfind_cmd = $1;

	my @items = ();
	my @cats = ();
	my $gpid;

	my $gpid = open(GOUT, $catfind_cmd);
        if ($gpid) {
        	@cats = <GOUT>;
        	close(GOUT);
		unlink "/tmp/.glimpse_tmp.$gpid";
	}
	$gpid = open(GOUT, $itemfind_cmd );	
        if ($gpid) {
        	@items = <GOUT>;
        	close(GOUT);
		unlink "/tmp/.glimpse_tmp.$gpid";
	}	

	# For now, just output the matches
	$self->OutputCatMatches(\@cats);
	$self->OutputItemMatches(\@items);	

	return;
}



# Add variables to array of lines returned by Glimpse
# This probably should go into Macros module also
sub ModQueryResults {

	my ($self,$glinesref, $query) = @_;
}


#
# Called with a reference to the array of lines returned by Glimpse
# And the original query
sub MergeMysql {

	my ($self,$glinesref, $query) = @_;

# we generally will put sql results ahead of full-text search
# use raw query for exact matches for now

# if modifying, make hash out of glinesref array

	return $num_files_returned;
}

#
sub ReadMysqlConf {

	return 1;  
}





