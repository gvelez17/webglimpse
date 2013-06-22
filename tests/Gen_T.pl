#!/usr/local/bin/perl

BEGIN{
	unshift(@INC, '../lib');
}

use CommandWeb;

%hash1 = ('DOMAINNAME', 'www.tucson.com',
	  'DOMAINSTATE','OK',
	 );
%hash2 = ('DOMAINNAME', 'www.arizona.edu',
	  'DOMAINSTATE', 'NOT OK');

%varhash = ('SUB1ID', 'sub1',
            'SUB2ID', 'sub2',
	    'SUB3ID', 'sub3',
            'PAGE5ID', 'page5',
	    'DOMAINS', [\%hash1, \%hash2],
	    'FREQ_MON', 'SELECTED');

#@DOMAINS = (\%hash1, \%hash2);

#CommandWeb::OutputTemplate("../templates/tmplTestTrans.html", \%varhash, 0);
CommandWeb::OutputTemplate("../templates/tmplManageArch.html", \%varhash, 0);
#CommandWeb::OutputTemplate("../templates/tmplEditDir.html", \%varhash, 0);
#CommandWeb::OutputTemplate("../templates/tmplAddSite.html", \%varhash, 0);
#CommandWeb::OutputTemplate("../templates/tmplAddTree.html", \%varhash, 0);

