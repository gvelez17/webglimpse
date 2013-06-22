#!/usr/bin/perl 

package CommandWeb;

#use strict;

# Package CommandWeb : generic functions for object management and user interface
# 
#  used to save form data into objects, generate webpages from templates, hashes & arrays
#
# Includes functions   
#
#	AssignInputs	 	convert hash into object by matching name of member vars
#	AssignSpecialInputs	as above, but use obj->Set instead of simple =
#	BuildHash		convert object into has using obj->Get calls
#	BuildHashArray		build array of hashes from an array of objects
#	OutputTemplate		read and process template containing simple variables,
#				checkbox-type flags, and arrays of hashes
#	OutputtoWeb		calls OutputTemplate and prints as content-type: text/html
#	OutputtoFile		calls OutputTemplate and prints result to file
#	OutputtoString		variation of OutputTemplate returns string
#	OutputToFileFromString
#	OutputfromTemplateString  variation of OutputTemplate reads from string
#
#	PromptUser		prompt user to fill in values of a hash
#	PromptUserList		as above, but prompt only for items in a separate list
#	TempPass		Create an encrypted string that can be used to login for an hour, then expires
#	HTMLize			Prepare plain text to be output within HTML doc
#				This way the real password is only passed once in a form and is never stored as a cookie.
#	ValidatePassword	Check password vs encrypted file and return temp string for cookie


# All functions return a true value on success, 0 on failure
# The error message is stored in the global $::lastError variable

my $debug = 0;

# Do not use "my" for these package vars; we want them externally accessible
#$aa = '\[\|';	$AA = '[|';
#$zz = '\|\]';   $ZZ = '|]';

# below are Webglimpse defaults; above are Abra defaults

$aa = '\|';  $AA = '|';
$zz = '\|';  $AA = '|';

1;



# Assign inputs to matching object member vars. Look for both matching case and all UPPER
sub AssignInputs {
	my ($hashref, $obj, $vref) = @_;

	my $vname;

	defined(@$vref) || return(0);
	foreach $vname (@$vref) {
		if (defined($$hashref{$vname})) {
			$obj->{$vname} = $$hashref{$vname};
		} elsif(defined($$hashref{uc($vname)})) {
			$obj->{$vname} = $$hashref{uc($vname)};
		} 		
	}
	return 1;
}


sub AssignSpecialInputs {

	my ($hashref, $obj, $vref) = @_;

	my ($vname,$astr);

	defined(@$vref) || return(0);
	defined($obj) || return(0);
	foreach $vname (@$vref) {
		if (defined($$hashref{$vname})) {
			$astr = $$hashref{$vname};
			$obj->Set($vname, $astr);
#			@{$obj->{$vname}} = split(/\s+/,$astr); 
		} elsif(defined($$hashref{uc($vname)})) {
			$astr = $$hashref{uc($vname)};
			$obj->Set($vname, $astr);
		} 
						
	}
	return 1;

}

# Accept file with one variable per line, format 
#
#	bbVarnameyyValue  
#
#  where bb and yy are specified delimiters (may include regexp chars)
#
sub BuildHashFromFile {
	my ($hashref, $filename, $bb, $yy) = @_;

	open(F, $filename) || return(0);

	while (<F>) {
		chomp;
		s/\r$//; # in case of MS-DOS uploads
		if (/^$bb(.+)$yy(.+)$/) {
			$$hashref{$1} = $2;
		}
	}
	close F;
	return 1;
}


# Assign hash variables from object
sub BuildHash {
	my ($hashref, $obj, $vref, $toupper) = @_;

	my ($vname, $uname);

	# Make sure we got passed the right kinds of animals
	defined(@$vref) || ($::lastError = "BuildHash: $vref is not an array reference") && return(0);

	foreach $vname (@$vref) {
		if ($toupper) {
			$uname = uc($vname);
		} else {
			$uname = $vname;
		}
		$$hashref{$uname} = $obj->Get($vname);
	}
	return 1;
}


# Build array of hashes from an array of objects
sub BuildHashArray {
	my ($aref, $arrobjs, $vref, $toupper) = @_;

	my ($obj, $href);

	defined(@$arrobjs) || ($::lastError = "BuildHashArray: $arrobjs is not an array reference") && return(0);
	foreach $obj (@$arrobjs) {

		# ref to a new anonymous hash
		$href = {};
		&BuildHash($href, $obj, $vref, $toupper) || return(0);
		push @$aref, $href;		

	}
	# sort hash by first entry in vref (first member variable)
	@$aref = sort { $$a{$$vref[0]} <=> $$b{$$vref[0]} } @$aref;

	return 1;
}



# Read the contents of a file, replace variables of the form [VARNAME], and print the results to STDOUT
sub OutputToFile {
	my ($filein, $fileout, $varhash) = @_;
	if (!open(F, ">$fileout")) {
		$::lastError = "OutputToFile: Cannot open file $fileout for writing"; 
		return(0);
	}

	my $old_fh = select(F);
	&OutputTemplate($filein, $varhash);
	select($old_fh);

	close F;
	return 1;
}


# Accept string, replace variables of the form [VARNAME], and print the results to STDOUT
sub OutputToFileFromString {
	my ($tstring, $fileout, $varhash) = @_;
	if (!open(F, ">$fileout")) {
		$::lastError = "OutputToFile: Cannot open file $fileout for writing"; 
		return(0);
	}

	my $old_fh = select(F);
	&OutputfromTemplateString($tstring, $varhash);
	select($old_fh);

	close F;
	return 1;
}


sub OutputToWeb {
	my ($filename, $varhash) = @_;
	print "Content-type: text/html \n\n";
	&OutputTemplate($filename, $varhash);
	return 1;
}


sub GetValue {
	my ($varhash, $key) = @_;
	if (exists $$varhash{$key}) {
		return $$varhash{$key};   # return value if defined (may be empty string)
	} else {
		return "$AA$key$ZZ";		  # leave untouched if undefined
	}
};

sub GetValueIf {
	my ($varhash, $key, $ifkey) = @_;
	my $safevar = ($key =~ /^[a-zA-Z-_0-9]+$/);
	if ($$varhash{$ifkey}) {
		if ($safevar && exists($$varhash{$key})) {
			return $$varhash{$key};   # return value if defined (may be empty string)
		} elsif ($key =~/^"([^"]+)"$/) {
			return $1;		  # quoted string is plaintext
		} elsif ($safevar) {
			return "$AA$key$ZZ";	  # leave untouched if undefined
		} else {
			return "";		  
		}
	} elsif (exists $$varhash{$ifkey}) {
		return "";
	} else {
		return "$AA\?$ifkey\?:$key$ZZ";	  # leave conditional for later checks
	}
};

# fixup plain text to output reasonably as HTML
sub HTMLize {
	$_ = shift;

	# preserve returns and multiple spaces, except trailing ones
	s/\s+$//;
	s/\n\n/<p>/g;
	s/\n/<br>\n/g;
	s/<p>/<p>\n/g;	
	s/  /&nbsp;&nbsp;/g;

	# hotlink things that look like links unless they are in quotes
	s/([^'"])(https?:\/\/[^\s\,]+[^\s\,\.])/$1<A HREF="$2">$2<\/A>/g;

	return $_;
}

sub GetChecked {
	my ($varhash, $key) = @_;

	# any nonzero value in the variable, check the box, except for 'n' and 'N'	
	if (($$varhash{$key})&&($$varhash{$key} !~ /^[nN]$/)) {
		return "CHECKED";
	} else {
		return '';
	}
}

# allow ':' in variable names to support explicit data fields
sub OutputTemplate {
	my ($filename, $varhash) = @_;
	
	my ($key, $value, $rkey, $aref, $rvalue, $hashref, $line);

	no strict 'refs';

	if (!open(INPUT, $filename)) {
		$::lastError = "OutputTemplate: Cannot open the file $filename \n";
		return(0);
	}

	while(<INPUT>) {
		$line = '';

		# Take care of conditionals
		/^\?([a-zA-Z0-9_:]+)\?/ && !($$varhash{$1}) && next;
		s/$aa\?([a-zA-Z0-9_:]+)\?:([^\|]+)$zz/&GetValueIf($varhash,$2,$1)/ge;  # $2 might be just text; we do security check in GetValueIf
		# Replace vars repeatedly if contains array of hashes ~ARRAYNAME~ 
		if(s/~([a-zA-Z0-9_:]+)~//) {
			$aref = $$varhash{$1};
			if (defined @$aref) {

				foreach $hashref (@$aref) {
					$line = $_;
					$line =~ s/$aa\?([a-zA-Z0-9_:]+)\?:([^\|]+)$zz/&GetValueIf($hashref,$2,$1)/ge;  
					foreach $rkey (keys(%$hashref)) {
						$rvalue = $$hashref{$rkey};
						$line =~ s/$aa$rkey$zz/$rvalue/g;
					}
		                      	# Replace straightforward |VARNAME| type variables
                		        $line =~ s/$aa([a-zA-Z0-9_:]+)$zz/&GetValue($varhash, $1)/ge;

		                        # Replace checkboxes #VARNAME# with "CHECKED" as needed
                		        $line =~ s/\#([a-zA-Z0-9_:]+)\#/&GetChecked($varhash, $1)/ge;

                       			# Clean out remaining unreplaced | | vars
                        		$line =~ s/$aa([a-zA-Z0-9_:]+)$zz//ge;
                        		$line =~ s/$aa\?[a-zA-Z0-9_:]+\?[^\|]+$zz//ge;
					print $line;
				}
			} 
		} else { 
			# Replace straightforward |VARNAME| type variables
			s/$aa([a-zA-Z0-9_:]+)$zz/&GetValue($varhash, $1)/ge;

			# Replace checkboxes #VARNAME# with "CHECKED" as needed
			s/\#([a-zA-Z0-9_:]+)\#/&GetChecked($varhash, $1)/ge;

			# Clean out remaining unreplaced | | vars
			s/$aa([a-zA-Z0-9_:]+)$zz//ge;
	               	s/$aa\?[a-zA-Z0-9_:]+\?[^\|]+$zz//ge;
	
			print;
		}
	}
	close INPUT;
	return 1;
}

#TODO: use $aa and $zz here instead of \|
sub OutputtoString {
	my ($filename, $varhash) = @_;
	
	my ($key, $value, $rkey, $aref, $rvalue, $hashref, $line);

	my $retstring = '';

	no strict 'refs';

	if (!open(INPUT, $filename)) {
		$::lastError = "OutputTemplate: Cannot open the file $filename \n";
		return(0);
	}

	while(<INPUT>) {

		# Replace straightforward |VARNAME| type variables
		s/\|([a-zA-Z0-9_\:]+)\|/&GetValue($varhash, $1)/ge;

		# Replace checkboxes #VARNAME# with "CHECKED" as needed
		s/\#([a-zA-Z0-9_\:]+)\#/&GetChecked($varhash, $1)/ge;

		# Replace vars repeatedly if contains array of hashes ~ARRAYNAME~ 
		if(s/~([a-zA-Z0-9_:]+)~//) {
			$aref = $$varhash{$1};
			if (defined @$aref) {
				foreach $hashref (@$aref) {
					$line = $_;
					foreach $rkey (keys(%$hashref)) {
						$rvalue = $$hashref{$rkey};
						$line =~ s/\|$rkey\|/$rvalue/g;
					}

                       			# Clean out remaining unreplaced | | vars
                        		$line =~ s/\|([a-zA-Z0-9_\:]+)\|//ge;
					$retstring .= $line;
				}
			} 
		} else {
			# Clean out remaining unreplaced | | vars
			s/\|([a-zA-Z0-9_\:]+)\|//ge;
			$retstring .= $_."\n";
		}
	}
	close INPUT;
	return $retstring;
}

# optionally print to STDOUT and return string
sub OutputfromTemplateString {
	my ($templatestring, $varhash, $quiet) = @_;
	if (! defined($quiet)) {$quiet = 0; }
	my $retstring = '';
	
	my ($key, $value, $rkey, $aref, $rvalue, $hashref, $line);

	no strict 'refs';

	foreach (split(/\n/, $templatestring)) {

		# Take care of conditionals
		/^\?([a-zA-Z0-9_:]+)\?/ && !($$varhash{$1}) && next;
		s/$aa\?([a-zA-Z0-9_:]+)\?:([^\|]+)$zz/&GetValueIf($varhash,$2,$1)/ge;  # $2 might be just text; we do security check in GetValueIf
		# Replace straightforward |VARNAME| type variables
		s/$aa([a-zA-Z0-9_:]+)$zz/&GetValue($varhash, $1)/ge;

		# Replace checkboxes #VARNAME# with "CHECKED" as needed
		s/\#([a-zA-Z0-9_:]+)\#/&GetChecked($varhash, $1)/ge;

		# Replace vars repeatedly if contains array of hashes ~ARRAYNAME~ 
		if(s/~([a-zA-Z0-9_:]+)~//) {
			$aref = $$varhash{$1};
			if (defined @$aref) {
				foreach $hashref (@$aref) {
					$line = $_;
					$line =~ s/$aa\?([a-zA-Z0-9_:]+)\?:([^\|]+)$zz/&GetValueIf($hashref,$2,$1)/ge;  
					foreach $rkey (keys(%$hashref)) {
						$rvalue = $$hashref{$rkey};
						$line =~ s/$aa$rkey$zz/$rvalue/g;
					}
                       			# Clean out remaining unreplaced | | vars
                        		$line =~ s/$aa([a-zA-Z0-9_:]+)$zz//ge;
                        		$line =~ s/$aa\?[a-zA-Z0-9_:]+\?[^\|]+$zz//ge;
					$quiet || print $line,"\n";
					$retstring .= $line."\n";
				}
			} 
		} else {
			# Clean out remaining unreplaced | | vars
			s/$aa([a-zA-Z0-9_:]+)$zz//ge;
               		s/$aa\?[a-zA-Z0-9_:]+\?[^\|]+$zz//ge;
			$quiet || print;
			$retstring .= $_;
			$quiet || print "\n";
			$retstring .= "\n";
		}
	}
	return $retstring;
}

# Prompt for a set of variables on the command line
sub PromptUser {
	my($explain, $refReplaceVars, $refPrompts) = @_;
	my($var, $val, $prompt,$ret);
	print $explain;
	$ret = 0;
	foreach $var (keys %$refReplaceVars) {
		$val = $$refReplaceVars{$var};
		$prompt = $$refPrompts{$var} || "Value for $var:";
		$$refReplaceVars{$var} = prompt($prompt, $val);
		$ret = 1;
	}	
	return $ret;
}


# Prompt for a list of variables on the command line
sub PromptUserList {
	my($explain, $refReplaceVars, $refList, $refPrompts) = @_;
	my($var, $val, $prompt,$ret);
	print $explain;
	$ret = 0;
	foreach $var (@$refList) {
		$val = $$refReplaceVars{$var};
		$prompt = $$refPrompts{$var} || "Value for $var:";
		$$refReplaceVars{$var} = prompt($prompt, $val);
		$ret = 1;
	}	
	return $ret;
}

##########################################################################
sub prompt {
	my($prompt,$def) = @_;
	if ($def) {
		if ($prompt =~ /:$/) {
			chop $prompt;
		}
		if ($prompt =~ /\s$/) {
			chop $prompt;
		}
		print $prompt," [",$def,"]: ";
	} else {
		if ($prompt !~ /[:\?]\s*$/) {
			$prompt .= ': ';
		} elsif ($prompt !~ /\s$/) {
			$prompt .= ' ';
		}
		print $prompt;
	}
	$| = 1;
	$_ = <STDIN>;
	chomp;
	return $_?$_:$def;
}

################################################################################
# Create an encrypted string that can be used to login for an hour, then expires
# only useful after 1 hr if hacker cracks it.  This way the real password is only 
# passed once in a form and is never stored as a cookie.
sub TempPass {
	my ($username, $passfile) = @_;

	my $tpass = '';

        open (F, $passfile) || (($::lastError = "CheckSum: Could not open $passfile for reading") && return 0);

        while (<F>) {
                chomp;
                ($user, $pass) = split(/:/);
                if ($user eq $username) {
                        # Make our very special expiring checksum
                        my $hr = int time/3600;
                        $checksum = crypt($pass.$hr, $pass);
			close F;
                        return $checksum;
		}
	}
        $::lastError = "CheckSum: $username is not a recognized username";
        close F;
        return 0;
}


##########################################################################
sub ValidatePassword {
	my ($username, $password, $passfile) = @_;
	my ($user, $pass, $cryptpass) = ('','','');

	my $tpass = '';

	# If no password file exists, allow everyone
	(-e $passfile) || return(1);

	# If it exists but we can't open it, return an error.
	open (F, $passfile) || (($::lastError = "ValidatePassword: Could not open $passfile for reading") && return 0);

	while (<F>) {
		chomp;
		($user, $pass) = split(/:/);
		if ($user eq $username) {
			if (crypt($password, $pass) eq $pass) {
				close F;

				# Make our very special expiring password
				my $hr = int time/3600;
				$tpass = crypt($pass.$hr, $pass);

				return $tpass;
			} else {
				$::lastError = "ValidatePassword: Invalid password for user $username";
				close F;
				return 0;
			}
		}
	}
	$::lastError = "ValidatePassword: $username is not a recognized username";
	close F;
	return 0;
}

##############################################################################
# ParseCommandLine  	Gets command line options, places into %in hash
#
sub ParseCommandLine {
	my $hashref = shift;

	while ( $_ = $ARGV[0]) {
        	shift;
		last if /^--$/;

		

	}

	return 1;
}


##############################################################################
sub get_option {
        &usage("missing argument for $_[0]") if ($#ARGV==-1) ;
        my $result = $ARGV[0];
        shift @ARGV;     
        return $result;
}


=head1 NAME

CommandWeb, OutputTemplate - Generates HTML pages

=head1 SYNOPSIS

        use CommandWeb;

        OutputTemplate("template.html", \%varhash);

=head1 DESCRIPTION

The module CommandWeb.pm contains several functions useful for both command-line and
web user interfaces.

OutputTemplate was written to generate HTML form pages for the web interface of Web
glimpse. It takes the template HTML file and a reference to the array of parameters 
from the user. It then generates a HTML form page with new parameters included in the 
template file that can be viewed on the web browser.

=over

=item OutputTemplate

Takes two arguments, name of the HTML template file, and a hash reference. Keys of the 
hash that is passed to the module by reference contains words in the template file 
that are to be replaced by the corresponding values of the hash.


