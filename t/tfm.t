

BEGIN { $| = 1; print "1..8\n"; }
END {print "not ok 1\n" unless $::loaded_tfm;}


BEGIN { print "Loading module Font::TFM\n"; }

use Font::TFM;  
$::loaded_tfm = 1;
print "ok 1\n";

$Font::TFM::TEXFONTSDIR = ".";
### $Font::TFM::DEBUG = 1;

print "Loading metric information about font cmr10\n";
my $cmr = new Font::TFM "cmr10" or
	do { print $Font::TFM::errstr, 'not '; };
print "ok 2\n";


print "Checking design size of cmr10\n";
my $designsize = $cmr->designsize();
print "Got $designsize\n";

print "not " if $designsize != 10;
print "ok 3\n";


print "Checking width of letter A\n";
my $width = $cmr->width('A');
print "Got $width\n";

print "not " if $width != 491521.25;
print "ok 4\n";


print "Checking kern expansion of Wo\n";
my $kernresult = $cmr->kern('Wo');
printf "Got $kernresult\n";

print "not " if $kernresult != -54613.75;
print "ok 5\n";

print "Test error message for non-existing font\n";
my $bad = new Font::TFM 'nonexistent';

if (defined $bad)
	{ print 'not '; }
print "ok 6\n";

if (not defined $Font::TFM::errstr)
	{ print "Font::TFM::errstr not set \n", 'not '; }
elsif (not $Font::TFM::errstr =~ /^No tfm file found for/)
	{ print "Font::TFM::errstr `$Font::TFM::errstr' is not what's expected\n", 'not '; }
print "ok 7\n";

print "Checking kern expansion of va\n";
$kernresult = $cmr->kern('va');
printf "Got $kernresult\n";

print "not " if $kernresult != -36408.75;
print "ok 8\n";


