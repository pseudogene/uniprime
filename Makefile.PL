# $Id: Makefile.pm,v 1.14 2007/11/30 08:57:39 Europe/Dublin $

require 5.005;
use ExtUtils::MakeMaker ;
use File::Path 'rmtree';
use IO::File;
use Config;

$NAME     = 'Bio';
$DISTNAME = 'uniprime';
$VERSION  = '1.14';

WriteMakefile(
   VERSION => $VERSION,
   NAME	=> $NAME,
   DISTNAME    => $DISTNAME,
   'dist'      => {  COMPRESS     => 'bzip2',
                     SUFFIX       => '.bz2',
                     DIST_DEFAULT => 'all tardist',
                  },
   ($] ge '5.005')  ? (
    'AUTHOR'   => 'Michael Bekaert (michael@batlab.eu)',
    'ABSTRACT' => 'Universal Primer Design Tools (UniPrime)',
   ) : (),
   DIR         => [  ]
);
