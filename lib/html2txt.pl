#!/usr/local/bin/perl


# converts html files into ascii by just stripping anything between
#  < and >
# written 4/21/96 by Michael Smith for WebGlimpse

$carry=0;

while(<STDIN>){
	$line = $_;
	
	if($carry==1){
		# remove all until the first >
		next if($line!~s/[^>]*>//);
		# if we didn't do next, it succeeded -- reset carry
		$carry=0;
	}

	while($line=~s/<[^>]*>//g){};
	if($line=~s/<.*$//){
		$carry=1;
	}
	print $line;
}
