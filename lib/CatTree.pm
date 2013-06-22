#!/usr/bin/perl

package CatTree;

# Module for retrieving category data
# assumes we have wg-style data files:
#   dbm file indexed by catcode = 16-byte packed code
#   with one byte for each level in the category hierarchy

# Functions
#
#    ListSubCats(catid)		fills in hash of words indexed by catid
#    ListParentCats(catid)	" 
#    GetFullCat(catid)		returns /top/next/nextcat/finalword 
#    FindAllCats(word)		returns list of catid's ending in 
#					a string containing word 
#    FindAllCatsExact(word)	returns list of catid's ending in word

use Fcntl;

use SDBM_File;

BEGIN {
        use wgHeader qw( :general );
        use wgErrors;
}

my $catfile = "$WGHOME/dist/$CATFILE";

my $catopen = 0;

%wgcodes = {};
 
1;


sub OpenCats{
	tie(%wgcodes, SDBM_File, $catfile, O_RDONLY, 0644) 
		|| ($lastError = "Cannot tie hash to $catfile\n") && return(0);

	$catopen = 1;
}

sub CloseCats{
	untie %wgcodes;
}


# Returns an array of hashes as needed by CommandWeb.pm
# I know, we only have 1 key/val pair each so we could just have a simple hash
# but that's not the structure CommandWeb expects
sub ListCats {
	my ($catref, $aref, $lvl) = @_;
	my $word = '';
	my $cat = '';
	my ($href, $catid, $j);

	my @catcode = (0) x 16;
	for ($j = 0; $j < $lvl; $j++) {
		$catcode[$j] = $$catref[$j];
	}
	
	$catcode[$lvl] = 1;
	$catid = pack "C16", @catcode;

	while ((defined $wgcodes{$catid}) && ($catcode[$lvl] < 256)) {
		$href = {};				# ref to new anonymous hash
		$strid = join(':',@catcode);
		$$href{'CATID'} = $strid;
		$$href{'WORD'} = $wgcodes{$catid};	# could also add other vars as needed
							# may add dmozid, descript
		$catcode[$lvl]++;
		$catid = pack "C16", @catcode;

		$$href{'WORD'} || next;	 # Don't bother with blanks

		push @$aref, $href;
	}
	return 1;
}


# Returns index of last nonzero level; category 01 04 80 0 0 0 0 would be level 2
sub GetLevel {
	my $catref = shift;

	my $lvl = 0;
        while (($lvl < 16) && ($$catref[$lvl] > 0)) {
                $lvl++;
        }
	return $lvl - 1;
}


# Returns printable array of hashes, with catcodes written out in decimal
sub ListSubCats {
	my ($catid, $aref, $offset) = @_;

	$catopen || &OpenCats || return(0);

	my @catcode = unpack "C16", $catid;

	my $lvl = &GetLevel(\@catcode) + $offset;

	if ($lvl >= 16 ) {$lvl = 15; }
	if ($lvl < 0) { $lvl = 0; }

	&ListCats(\@catcode, $aref, $lvl);

	return $lvl;
}


sub GetCatString {
	my ($catid,$limit) = @_;

       $catopen || &OpenCats || return(0);

	my $catstring = '/';
	my $catcode = '';

        my @catcode = unpack "C16", $catid;
	my @cats = (0) x 16;
      	my $lvl = 0;
        while (($catcode[$lvl] > 0) && ($lvl < $limit)) {

                # build parent cat string
		$cats[$lvl] = $catcode[$lvl];

		$catid = pack "C16", @cats;
		$catstring .= $wgcodes{$catid};

		$catstring .= '/';

                $lvl++;
        }

	$lvl && (chop $catstring);

	$catcode = join(':',@cats);
	
	return $catstring, $catcode;	

}


sub FindAllCats {
	my $word = shift;

}


sub FindAllCatsExact {
	my $word = shift;

}
