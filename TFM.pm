
=head1 NAME

Font::TFM -- read and work with TeX font metric files

=head1 SYNOPSIS

	use Font::TFM;  
	### $Font::TFM::TEXFONTSDIR = "your directories";

	my $cmr = new Font::TFM "cmr10";
	(defined $cmr) or die "Error reading font\n";
	print "Designsize: ", $cmr->designsize(), "\n";
	print $cmr->width("A"), ", ", $cmr->kern('Wo'), "\n";

should print on the output

	Designsize: 10
	491521.25, -54613.75

=head1 DESCRIPTION

Method C<Font::TFM::new> creates a new TFM object in memory, loading
all the necessary information from the C<.tfm> file. Second (optional)
parameter means scale. You can also use C<Font::TFM::new_at> and as
the second parameter put requested size in pt.

List of comma separated directories to be searched is in variable
C<$Font::TFM::TEXFONTSDIR>. These are searched for given C<.tfm> file
(extension C<.tfm> is optional in the call to C<Font::TFM::new>).
Variable C<$Font::TFM::TEXFONTSUSELS> can be set to zero to disable
using ls-R files. If it is kept equal to 1, once it finds file with
name C<$Font::TFM::LSFILENAME>, it doesn't search through the
subdirectories and only uses info in this file fo find the C<.tfm>
file.

These are the methods available on the C<Font::TFM> object:

=over

=item designsize, fontsize

Returns the design size and the actual size of the font in pt.

=item width, height, depth, italic

Returns the requested dimension for a specified character of
the font.

=item kern, lig, ligpassover

For a two-letter string returns kern between them, ligature formed and
number of characters to pass over after the ligature.

=item expand

One string parameter undergoes ligature expansion and then kernings
are inserted. Returns array of string, kern, string, ...

=item word_dimensions

Returns the width, height and depth of a word. Does the lig/kern
expansion, so the result is the real space it will take on output.

=item word_width, word_height, word_depth

Calls C<word_dimensions> and returns appropriate element. No caching
is done, so it is better to call C<word_dimensions> yourself if you
will need more than one dimension of one word.

=item param

Returns parameter of the font, indexed from 1.

=item slant, x_height, em_width, quad

=item space, space_stretch, space_shrink, extra_space

Returns the parameter of the font.

=item name

Returns the name of the font.

=back

Dimensions are multiplied by C<$Font::TFM::MULTIPLY> * actual size
of the font. Value of C<$Font::TFM::MULTIPLY> defaults to 65536, so
the dimensions can be used directly when writing the C<.dvi> file.

Variable C<$Font::TFM::DEBUG> may be set to 1 to get the processing
messages on the standard error output.

=cut

package Font::TFM;
use strict;
use vars qw( $VERSION $DEBUG $TEXFONTSDIR $TEXFONTSUSELS
	$LSFILENAME $MULTIPLY );

# ################
# Global variables
#
$VERSION = 0.05;

$DEBUG = 0;
sub DEBUG ()	{ $DEBUG; }

$TEXFONTSDIR = "/packages/share/tex/lib";
$TEXFONTSUSELS = 1;
$LSFILENAME = "ls-R";
$MULTIPLY = 65536;

# #####################
# Load new font at size
#
sub new_at
	{
	my ($class, $fontname, $size) = @_;
	$size = -$size if ($size > 0);
	new($class, $fontname, $size);
	}

# ########################
# Load new font with scale
#
sub new
	{
	my ($class, $fontname, $fontscale) = @_;
	
	# $fontscale: positive is scale, negative size
	$fontscale = 0 unless defined $fontscale;

	# find the file
	my $filename = find_tfm_file($fontname);
	return unless $filename;

	# try to open the file
	print STDERR "Loading $filename\n" if DEBUG;
	if (! open TFMFILE, $filename)
		{
		print STDERR "Error reading $filename: $!\n" if DEBUG;
		return;
		}

	# make the object
	my $self = {};
	bless $self;
	$self->{name} = $fontname;	
	$self->{name} =~ s/\.tfm$//;

	# read header
	my $buffer = '';
	if (read(TFMFILE, $buffer, 24) != 24)
		{
		print STDERR "Error reading TFM begin: $!\n" if DEBUG;
		return;
		}

	# get 12 fields of the header
	@{$self}{ qw(length headerlength smallest largest numwidth
		numheight numdepth numic numligkern numkern numext numparam) }
			= unpack "n12", $buffer;
	$self->{numofchars} = $self->{largest} - $self->{smallest} + 1;
	$self->{'length'} = $self->{'length'} * 4 - 24;
	$self->{headerlength} *= 4;

	# read rest of the file
	if (read(TFMFILE, $buffer, $self->{'length'}) != $self->{'length'})	
		{
		print STDERR "Error reading body: $!\n";
		return;
		}
	close TFMFILE;

	my $headerrestlength = $self->{headerlength} - 18 * 4;

	my ($face, $headerrest, @charinfo, @width, @height, @depth,
		@italic, @ligkern, @kern, @exten);

	# split the file into various arrays
	(@{$self}{ qw(checksum designsize codingschemestringlength
		codingscheme familystringlength family sevenbitsafe ) },
	undef, undef, $face,
	$headerrest,
	@charinfo[0 .. $self->{numofchars} - 1],
	@width[0 .. $self->{numwidth} - 1],
	@height[0 .. $self->{numheight} - 1],
	@depth[0 .. $self->{numdepth} - 1],
	@italic[0 .. $self->{numic} - 1],
	@ligkern[0 .. $self->{numligkern} - 1],
	@kern[0 .. $self->{numkern} - 1],
	@exten[0 .. $self->{numext} - 1],
	@{$self->{param}}[1 .. $self->{numparam}],
	)
		= unpack "NNCA39CA19C4a$headerrestlength" .
			"a4" x $self->{numofchars} .
			"N$self->{numwidth}N$self->{numheight}N$self->{numdepth}N$self->{numic}" .
			"a4" x $self->{numligkern} .
			"N$self->{numkern}" .
			"a4" x $self->{numext} .
			"N$self->{numparam}", $buffer;
	# the unpack above does all the work
	
	$self->{designsize} = getfixword($self->{designsize});

	my $fontsize = $self->{designsize};
	$fontsize = -$fontscale if ($fontscale < 0);
	$fontsize *= $fontscale if ($fontscale > 0);
	$self->{fontsize} = $fontsize;
	my $multiplysize = $fontsize * $MULTIPLY;

	if ($self->{sevenbitsafe})
		{ $self->{sevenbitsafe} = 1; }

	$self->{face} = "";		# computation of face seems useless
	if ($face < 18)
		{
		my ($weight, $slope, $expansion) = ("M", "R", "R");
		if ($face - 12 >= 0) { $expansion = "E"; $face -= 12; }
		elsif ($face - 6 >= 0) { $expansion = "C"; $face -= 6; }
		if ($face - 4 >= 0) { $weight = "L"; $face -= 4; }
		elsif ($face - 2 >= 0) { $weight = "B"; $face -= 2; }
		if ($face > 0) { $slope = "I"; }
		$self->{face} = "$weight$slope$expansion";
		}

	@{$self->{headerrest}}[0 .. $headerrestlength] = split //, $headerrest;

	@width = map { getfixword($_) * $multiplysize } @width;
	@height = map { getfixword($_) * $multiplysize } @height;
	@depth = map { getfixword($_) * $multiplysize } @depth;
	@italic = map { getfixword($_) * $multiplysize } @italic;
	@kern = map { getfixword($_) * $multiplysize } @kern;
	$self->{param}[1] = getfixword($self->{param}[1]);
	@{$self->{param}}[2 .. $self->{numparam}] =
		map { getfixword($_) * $multiplysize }
			@{$self->{param}}[2 .. $self->{numparam}];
					# compute the actual dimensions

	if (defined @ligkern)		# check for boundary char
		{
		my ($skip, $next, $opbyte, $remainder);
		($skip, $next) = unpack "CA1", $ligkern[0];
		if ($skip == 255)
			{ $self->{"boundary"} = $next; }
		($skip, $next, $opbyte, $remainder) = unpack
			"CA1CC", $ligkern[$#ligkern];
		if ($skip == 255)
			{
			process_lig_kern($self, "boundary", \@ligkern,
				256 * $opbyte + $remainder, \@kern);
			}
		}

	for (0 .. $self->{numofchars} - 1)
		{
		my $char = pack "C", $_ + $self->{smallest};
		my ($wid, $heidep, $italtag, $remainder)
			= unpack "C4", $charinfo[$_];
		next if ($wid == 0);
					# set up dimensions of the character
		($self->{width}{$char}, $self->{height}{$char},
			$self->{depth}{$char}, $self->{italic}{$char})
			= ($width[$wid], $height[$heidep >> 4],
			$depth[$heidep & 0x0f], $italic[$italtag >> 2]);
			
		my $tag = $italtag & 0x03;	# other info
		if ($tag == 1)			# lig/kern program
			{
			process_lig_kern($self, $char, \@ligkern, $remainder, \@kern);
			}
		elsif ($tag == 2)		# larger character
			{
			$self->{larger}{$char} = pack "C", $remainder;
			}
		elsif ($tag == 3)		# extensible character
			{
			my ($top, $mid, $bot, $rep) = unpack "C4", $exten[$remainder];
			$self->{extentop}{$char} = pack "C", $top if $top;
			$self->{extenmid}{$char} = pack "C", $mid if $mid;
			$self->{extenbot}{$char} = pack "C", $bot if $bot;
			$self->{extenrep}{$char} = $rep;
			}
		}
	$self;
	}

# ###################################################
# Process the ligature/kerning program for a character
#
sub process_lig_kern
	{
	my ($self, $char, $ligkernref, $prognum, $kernref) = @_;
	my $firstinstr = 1;
	while (1)
		{
		my ($skipbyte, $nextchar, $opbyte, $remainder)
			= unpack "CA1CC", $ligkernref->[$prognum];
		if ($firstinstr)
			{
			if ($skipbyte > 128)
				{
				$prognum = 256 * $opbyte + $remainder;
				($skipbyte, $nextchar, $opbyte, $remainder)
					= unpack "C4", $ligkernref->[$prognum];
				}
			}
		if ($opbyte >= 128)
			{
			$self->{kern}{$char . $nextchar}
				= $kernref->[ 256 * ($opbyte - 128) + $remainder];
			}
		else
			{
			my ($a, $b, $c) = ($opbyte >> 2, ($opbyte >> 1) & 0x01, $opbyte & 0x01);
			my $out = "";
			$out .= $char if $b;
			$out .= pack "C", $remainder;
			$out .= $nextchar if $c;
			$self->{lig}{$char . $nextchar} = $out;
			$self->{ligpassover}{$char . $nextchar} = $a;
			}
		last if ($skipbyte >= 128);
		$prognum += $skipbyte + 1;
		$firstinstr = 0;
		}
	}

# #################
# Find the TFM file
#
sub find_tfm_file
	{
	my $fontname = shift;
	$fontname .= ".tfm" unless $fontname =~ /\.tfm$/;
	print STDERR "Font::TFM::find_tfm_file: \$fontname = $fontname\n" if DEBUG;
	my $directory;
	for $directory (split /:/, $TEXFONTSDIR)
		{
		print STDERR "Font::TFM::find_tfm_file: \$directory = $directory\n" if DEBUG;
		my $file = find_tfm_file_in_directory($fontname, $directory);
		return $file if $file;
		}
	}
sub find_tfm_file_in_directory
	{
	my ($fontname, $directory) = @_;
	my $tfmfile = "$directory/$fontname";
	my $lsfile = "$directory/$LSFILENAME";
	print STDERR "Font::TFM::find_tfm_file_in_directory: \$directory = $directory\n" if DEBUG;
	if (-f $tfmfile)
		{
		return $tfmfile;
		}
	if ((-f $lsfile) && ($TEXFONTSUSELS))
		{
		my $file = find_tfm_file_in_ls($fontname, $lsfile);
		return $file if $file;
		}
	else
		{
		my $subdir;
		for $subdir (<$directory/*>)
			{
			next unless -d $subdir;
			my $file = find_tfm_file_in_directory($fontname, $subdir);
			return $file if $file;
			}
		}
	return;
	}
sub find_tfm_file_in_ls
	{
	my ($fontname, $lsfile) = @_;
	my $lsdir = $lsfile;
	$lsdir =~ s!/$LSFILENAME$!!;
	print STDERR "Font::TFM::find_tfm_file_in_ls: \$lsfile = $lsfile\n" if DEBUG;
	print STDERR "Font::TFM::find_tfm_file_in_ls: \$lsdir = $lsdir\n" if DEBUG;
	if (not open LSFILE, $lsfile)
		{
		print STDERR "Error reading $lsfile: $!\n" if DEBUG;
		return;
		}
	local ($/) = "\n";
	while (<LSFILE>)
		{
		chomp;
		if (/:$/)
			{
			$lsdir = $_;
			$lsdir =~ s!:$!!;
			print STDERR "Font::TFM::find_tfm_file_in_ls: \$lsdir = $lsdir\n" if (DEBUG > 10);
			}
		elsif ($_ eq $fontname)
			{
			my $file = "$lsdir/$fontname";
			if (-f $file)
				{
				close LSFILE;
				print STDERR "file $fontname found in $lsfile\n" if DEBUG;
				return $file;
				}
			}
		}
	print STDERR "file $fontname not found in $lsfile\n" if DEBUG;
	return;
	}
sub getfixword
	{
	my $val = $_[0];
	my $p = pack "L", $val;
	if ($val & 0x80000000)
		{
		$val = unpack "l", $p;
		}
	return ($val / (1 << 20));
	}
sub kern
	{
	my ($self, $double, $second) = @_;
	$double .= $second if (defined $second);
	if (defined $self->{kern}{$double})
		{ return $self->{kern}{$double}; }
	return 0;
	}
sub lig
	{
	my ($self, $double, $second) = @_;
	$double .= $second if (defined $second);
	if (defined $self->{lig}{$double})
		{ return $self->{lig}{$double}; }
	return undef;
	}
sub ligpassover
	{
	my ($self, $double) = @_;
	$self->{ligpassover}{$double};
	}
sub param
	{
	my ($self, $param) = @_;
	$self->{param}[$param];
	}
sub word_dimensions
	{
	my ($self, $text) = @_;
	my @expanded = $self->expand($text);
	my ($width, $height, $depth) = (0, 0, 0);
	while (@expanded)
		{
		my $word = shift @expanded;
		while ($word =~ /./sg)
			{
			my $char = $&;
			$width += $self->width($char);
			my $newval = $self->height($char);
			$height = $newval if ($newval > $height);
			$newval = $self->depth($char);
			$depth = $newval if ($newval > $depth);
			}
                last if (not @expanded);
		$width += shift @expanded;
		}
	($width, $height, $depth);
	}
sub expand
	{
	my ($self, $text) = @_;
	my $pos = 0;
	
	# ligature substitutions
	while ($pos < (length $text) - 1)
		{
		my $found;
		my $substr = substr $text, $pos, 2;
		$found = $self->lig(substr $text, $pos, 2);
		if (defined $found)
			{
			substr($text, $pos, 2) = $found;
			$pos += $self->ligpassover($substr);
			}
		else
			{ $pos++ }

		}

	# kerning processing
	my @out = ();
	my $currentstring = substr $text, 0, 1;
	while ($text =~ /(.)(?=(.))/gs)
		{
		if ($self->kern($1 . $2))
			{
			push @out, $currentstring;
			$currentstring = '';
			push @out, $self->kern($1 . $2);
			}
		$currentstring .= $2
		}
	push @out, $currentstring;
	@out;
	}


my %PARAM_NAMES = ( slant => 1, space => 2, space_stretch => 3,
	space_shrink => 4, x_height => 5, em_width => 6, quad => 6,
	extra_space => 7 );
my @GENERAL_NAMES = qw( fontsize designsize name checksum );
my @CHAR_NAMES = qw( width height depth italic );
my %WORD_NAMES = ( word_width => 0, word_height => 1, word_depth => 2 );

use vars qw( $AUTOLOAD );
sub AUTOLOAD
	{
	my $self = shift;
	my $function = $AUTOLOAD;
	local ($_);
	$function =~ s/^.*:://;
	print STDERR "Autoloading $function\n" if DEBUG;
	return ($self->word_dimensions(shift))[$WORD_NAMES{$function}]
		if defined $WORD_NAMES{$function};
	return $self->{'param'}[$PARAM_NAMES{$function}]
		if (defined $PARAM_NAMES{$function});
	return $self->{$function}{$_[0]}
		if grep { $_ eq $function } @CHAR_NAMES;
	return $self->{$function}
		if grep { $_ eq $function } @GENERAL_NAMES;
	die "Method $function not defined for $self";
	}

sub Version	{ $VERSION; }

=head1 CHANGES

=over

=item 0.05 Tue Aug 19 10:09:27 MET DST 1997

Minor bug fixes. Module made use strict clean. Tests added.

=item 0.04 Wed Apr  9 10:20:10 MET DST 1997

C<Font::TFM::word_dimensions> added, C<Font::TFM::word_width> and new
C<Font::TFM::word_height> and C<Font::TFM::word_depth> now call it.

C<Font::TFM::MULTIPLY> added, still defaults do 65535.

Module made faster, also uses C<AUTOLOAD> for many things.
Minor bug fixes.

=item 0.03 Sun Feb 16 13:55:26 MET 1997

C<Font::TFM::expand> added to provide lig/kern expansion.

C<Font::TFM::word_width> added to measure width of word on output.

C<Font::TFM::em_width> and C<TFM::name> added.

Name C<Font::TFM> set up instead of C<TFM>.

=item 0.02 Thu Feb 13 20:43:38 MET 1997

First version released/announced on public.

=back

=head1 VERSION

0.05

=head1 SEE ALSO

TeX::DVI(3), TeX::DVI::Parse(3), perl(1).

=head1 AUTHOR

(c) 1996, 1997 Jan Pazdziora, adelton@fi.muni.cz

at Faculty of Informatics, Masaryk University, Brno

=cut

1;
