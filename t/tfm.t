

BEGIN { $| = 1; print "1..5\n"; }
END {print "not ok 1\n" unless $::loaded_tfm;}


BEGIN { print "Loading module Font::TFM\n"; }

use Font::TFM;  
$::loaded_tfm = 1;
print "ok 1\n";

$Font::TFM::TEXFONTSDIR = ".";
### $Font::TFM::DEBUG = 1;

print "Loading metric information about font cmr10\n";
my $cmr = new Font::TFM "cmr10";

print "not " unless defined $cmr;
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

