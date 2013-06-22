#! /usr/local/bin/perl

BEGIN {
	unshift(@INC, '../lib');
}

use wgRoot;

print "\n";

#######			values and objects    ###########

@values_1 = ('v_StartURL', 'v_StartDir', 0, 'v_Hops', 'v_FollowToRemote', 'v_FollowSameSite', 'v_FollowAll', 'v_MaxLocal', 'v_MaxRemote', 'v_Local_Flag', 'v_Keep_Flag', 'v_MakeNH_Flag', 'v_CheckHtaccess','http://www.ece.arizona.edu/');

$obj1 = wgRoot->new(@values_1);

@values_2 = ('http://iwhome.com/wgproj/test/', 'v_StartDir', 3, 'v_Hops', 'v_FollowToRemote', 'v_FollowSameSite', 'v_FollowAll', 'v_MaxLocal', 'v_MaxRemote', 'v_Local_Flag', 'v_Keep_Flag', 'v_MakeNH_Flag', 'v_CheckHtaccess','');

$obj2 = wgRoot->new(@values_2);

@values_3 = ('','v_StartDir', 1, 'v_Hops', 'v_FollowToRemote', 'v_FollowSameSite', 'v_FollowAll', 'v_MaxLocal', 'v_MaxRemote', 'v_Local_Flag', 'v_Keep_Flag', 'v_MakeNH_Flag', 'v_CheckHtaccess','');

$obj3 = wgRoot->new(@values_3);

@values_4 = ('http://iwhome.com/wgproj/test/', 'v_StartDir', 1, 'v_Hops', 'v_FollowToRemote', 'v_FollowSameSite', 'v_FollowAll', 'v_MaxLocal', 'v_MaxRemote', 'v_Local_Flag', 'v_Keep_Flag', 'v_MakeNH_Flag', 'v_CheckHtaccess','');

$obj4 = wgRoot->new(@values_4);

@values_5 = ('http://iwhome.com/wgproj/test/', 'v_StartDir', 1, 'v_Hops', 1, 0, 0, 1000, 50, 'v_Local_Flag', 'v_Keep_Flag', 'v_MakeNH_Flag', 'v_CheckHtaccess','');

$obj5 = wgRoot->new(@values_5);

@values_6 = ('http://iwhome.com/wgproj/test/', 'v_StartDir', 1, 'v_Hops', 0, 1, 0, 1000, 50, 'v_Local_Flag', 'v_Keep_Flag', 'v_MakeNH_Flag', 'v_CheckHtaccess','');

$obj6 = wgRoot->new(@values_6);

@values_7 = ('http://iwhome.com/wgproj/test/', 'v_StartDir', 1, 'v_Hops', 0, 0, 1, 1000, 50, 'v_Local_Flag', 'v_Keep_Flag', 'v_MakeNH_Flag', 'v_CheckHtaccess','');

$obj7 = wgRoot->new(@values_7);

@values_8 = ('http://iwhome.com/wgproj/test/', 'v_StartDir', 1, 'v_Hops', 0, 1, 0, 1000, 50, 'v_Local_Flag', 'v_Keep_Flag', 'v_MakeNH_Flag', 'v_CheckHtaccess','');

$obj8 = wgRoot->new(@values_8);


#####   	checking the routine CheckPrefix   ###########
print " 	checking the routine CheckPrefix (No type defined) \n\n";
print "LimitPrefix is $obj1->{LimitPrefix}\n\n";

## test case 1		Output: sucess
print "Url is prefixed by LimitPrefix" if $obj1->CheckPrefix('www.ece.arizona.edu/~prakash/');

## test case 1		Output: sucess
print "http://www.ece.arizona.edu/~prakash/ is prefixed by LimitPrefix" if $obj1->CheckPrefix('http://www.ece.arizona.edu/~prakash/');
print "\n	-------------------------------------------------\n\n";


#####   	checking the routine Validate ###########
print "		printing initial values (SITE, TREE, DIR) $wgRoot::SITE, $wgRoot::TREE, $wgRoot::DIR\n\n";


print " 	checking the routine Validate (No type defined) Type = $obj2->{Type}\n\n";

if($obj2->Validate() == 1) { print "Validate success" } 
else { print "Validate Failed" }
print "\n\n";

print " 	checking the routine Validate (no StartURL) StartURL = $obj3->{StartURL}\n\n";

if($obj3->Validate() == 1) { print "Validate success" } 
else { print "Validate Failed" }
print "\n\n";

print " 	checking the routine Validate (with StartURL,but no LimitPrefix)\n";
print " 	StartURL = $obj4->{StartURL} LimitPrefix = $obj4->{LimitPrefix} \n\n";

if($obj4->Validate() == 1) { print "Validate success" } 
else { print "Validate Failed" }
print "\n\n";

print " 	StartURL = $obj4->{StartURL} LimitPrefix = $obj4->{LimitPrefix} \n";


print "	-------------------------------------------------\n\n";
#####   	checking the routine Checkrules###########
print " 	checking the routine Checkrules  \n\n";
print "	printing initial values (SITE, TREE, DIR) $wgRoot::SITE, $wgRoot::TREE, $wgRoot::DIR\n";

print "	fromislocal - 0, toislocal - 1\n\n";


($from, $to, $fromislocal, $toislocal) = ('http://iwhome.com/wgproj/test/new.html', 'http://www.iwhome.com/wgproj/jp/index.html', 0, 1);
print '($from)'; print " = ($from)\n";
print '($to)'; print " = ($to)\n\n";
print "test:1 (FollowToRemote, FollowSameSite, FollowAll) = ($obj5->{FollowToRemote}, $obj5->{FollowSameSite}, $obj5->{FollowAll})\n";
$result = $obj5->CheckRules($from, $to, $fromislocal, $toislocal);
print "subroutine CheckRules returned 	$result \n\n";

print "test:1 (FollowToRemote, FollowSameSite, FollowAll) = ($obj6->{FollowToRemote}, $obj6->{FollowSameSite}, $obj6->{FollowAll})\n";
($from, $to, $fromislocal, $toislocal) = ('http://iwhome.com/wgproj/test/new.html', 'http://www.iwhome.com/wgproj/jp/index.html', 0, 1);
$result = $obj6->CheckRules($from, $to, $fromislocal, $toislocal);
print "subroutine CheckRules returned 	$result \n\n";

($from, $to, $fromislocal, $toislocal) = ('http://www.iwhome.com/wgproj/test/new.html', 'http://www.iwhome.com/wgproj/jp/index.html', 0, 1);
print '($from)'; print " = ($from)\n";
print '($to)'; print " = ($to)\n\n";
print "test:1 (FollowToRemote, FollowSameSite, FollowAll) = ($obj5->{FollowToRemote}, $obj5->{FollowSameSite}, $obj5->{FollowAll})\n";
$result = $obj5->CheckRules($from, $to, $fromislocal, $toislocal);
print "subroutine CheckRules returned 	$result \n\n";

print "test:1 (FollowToRemote, FollowSameSite, FollowAll) = ($obj6->{FollowToRemote}, $obj6->{FollowSameSite}, $obj6->{FollowAll})\n";
($from, $to, $fromislocal, $toislocal) = ('http://www.iwhome.com/wgproj/test/new.html', 'http://www.iwhome.com/wgproj/jp/index.html', 0, 1);
$result = $obj6->CheckRules($from, $to, $fromislocal, $toislocal);
print "subroutine CheckRules returned 	$result \n\n";





