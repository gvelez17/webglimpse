# SqlMergeConf.pm
# Edit this file to set up database access 

package SqlMergeConf;

require Exporter;
use vars qw( @ISA @EXPORT);
@ISA = qw(Exporter);

# Note: modifying this file is not for the newbie
# You would only want to do it if you want to combine SQL results
# with full text search results in a very fast search of large datasets

##  VARIABLES TO MODIFY   #########################

# TODO: make archive-specific or at least protect from upgrades

@EXPORT = qw( $SEARCH_FREQ_TABLE $DB_DUMP_DIR $ITEM_DATA_FILE $CAT_DATA_FILE $DEFAULT_DBTAG $DBNAME $DBUSER $DBPASS $WGTABLE @DBLIST $MAX_ITEMS $MAX_CATS $MAX_SQL_HITS %DB1 %DB2 );

# Database containing the wg_tags table
$DBNAME = '';   # for our user data
$DBUSER = '';   # read/write access required
$DBPASS = '';
$WGTABLE = 'wg_tags';   # default name for our tags
			# fields are keyword, URL, rank

# Directory containing text dumps of the database for full-text queries
$DB_DUMP_DIR = '';
$ITEM_DATA_FILE = 'wgdata.txt';	  # you must generate this file independently
$CAT_DATA_FILE = 'wgcats.txt';    # same here
				  # one record per line

# Directory to write search files to under a directory named by the keyword
$SEARCH_FREQ_TABLE = 'wg_queries';	# If you want to keep query results
					# as static pages on your site
					# in order to have more searchable content

$MAX_SQL_HITS = 100;   # Just to keep common queries from getting out of control
		       # DB hits are supposed to be more specific
		       # TODO: this should be controlled in wgoutput.cfg
$MAX_ITEMS = 50;	# TODO: deal with caching
$MAX_CATS = 20;


# Database(s) to apply user queries to
%DB1  = ();
%DB2 = ();
@DBLIST = (\%DB1, \%DB2);

# If there is only one...
$DEFAULT_DBTAG = 'rcats';

# Example structure, please edit
%DB1 = (
	
    'DBTAG' => '',	# for use in wgoutput.cfg ; has nothing to do with wg_tags
    'DBNAME' => '',     
    'DBUSER' => '',	# database user, read-only access ok
    'DBPASS' => '',
    'TABLENAME' => '',  # what table are we querying against
    'MATCHFIELD' => '', # which field should match the user query
    'SELECTFIELDS' => '',   # which fields should we display: comma-delimited list
#    'ALTQUERY' => ' select MYFIELDS from MYTABLES where MYTABLE.MATCHFIELD = [QUERY] limit 20', # for multiple-table queries, provide query instead of matchfield
	   #  [QUERY] is a replacement variable and should remain
	   # Replace MYFIELDS, MYTABLES, MYTABLE and MATCHFIELD
	   # with appropriate table and field names
    'OUTPUTLINE' => '<A HREF=[fieldname1]>[fieldname2]</A><br>[fieldname3]<p>',  # unused
	# see OutputMatches in SqlMerge.pm for actual output line

);


# Databases containing extra info to modify raw wg output



## ENDVARS ###########################

1;
