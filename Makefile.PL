
use ExtUtils::MakeMaker;
WriteMakefile(
	'NAME'	=>	'Font::TFM',
	'VERSION_FROM' =>	'TFM.pm',
	'dist'	=>	{ COMPRESS => 'gzip -9f', SUFFIX   => '.gz', },
	);


