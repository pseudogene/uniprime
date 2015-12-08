#!/usr/bin/perl -w
#
# Universal Primer Design Tools (UniPrime package)
# Copyright 2006-2008 Bekaert M <michael@batlab.eu>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

use strict;
use DBI;
use Getopt::Long;
use Bio::Seq;

use Bio::Tools::UniTools;

#----------------------------------------
my $version = '1.18 (prune)';
my $db_name = 'uniprime';
my $db_user = $ENV{'USER'};
my $db_host = 'localhost';
my $db_pass = '';

#----------------------------------------------------------

my ( $dbh, $target, $action, $locus, $pmid, $db, @selected );
my ( $verbose, $dna, $evalue, $consensus, $size, $query, $status, $type, $out ) = ( 0, 0, 1e-100, 60, 600, '', 1, 6, 1 );

GetOptions(
    'v!'        => \$verbose,
    'action=s'  => \$action,
    'target=s'  => \$target,
    'db:s'      => \$db,
    'dna!'      => \$dna,
    'e:f'       => \$evalue,
    'c:i'       => \$consensus,
    'query:s'   => \$query,
    'select:s@' => \@selected,
    'size:i'    => \$size,
    'locus=i'   => \$locus,
    'pmid:i'    => \$pmid,
    'status:i'  => \$status,
    'type:i'    => \$type
);

if ( ( defined $target ) && ( length($target) > 2 ) && ( defined $action ) && ( ( $action =~ /^[opav]/ ) && ( $target =~ /[LX](\d+)\.(\d+)/ ) || ( $action =~ /^[l]/ ) && ( $target =~ /(\d+)/ ) ) ) {
    my ( $prefix, $id );
    if ( defined $2 ) {
        $prefix = oct($1);
        $id     = oct($2);
    } else {
        $id = $1;
    }
    $out--;

    $db = ( ( $action =~ /^[v]/ ) ? 'wgs' : ( $dna ? 'refseq_genomic' : 'refseq_rna' ) ) unless ( defined $db );
    print STDERR "\n..:: UniPrime ::..\n> Standalone program version $version <\n\n" if ($verbose);
    if ( $db_host eq 'localhost' ) {
        $dbh = DBI->connect( "DBI:Pg:dbname=$db_name", $db_user, $db_pass ) or die($DBI::errstr);
    } else {
        $dbh = DBI->connect( "DBI:Pg:dbname=$db_name;host=$db_host", $db_user, $db_pass ) or die($DBI::errstr);
    }
    Bio::Tools::UniTools->addLocus( $dbh, $id, $status, $pmid, $type, $verbose ) if ( $action =~ /^l/ );
    Bio::Tools::UniTools->populate_orthologues( $dbh, $prefix, $id, $evalue, lc $db, $dna, $query, $verbose ) if ( $action =~ /^o/ );
    Bio::Tools::UniTools->populate_alignment( $dbh, $prefix, $id, $consensus, $dna, $verbose, @selected ) if ( $action =~ /^a/ );
    Bio::Tools::UniTools->populate_primer( $dbh, $prefix, $id, $size, $verbose ) if ( $action =~ /^p/ );
    Bio::Tools::UniTools->virtual_amplicon( $dbh, $prefix, $id, $query, lc $db, 5000, $verbose ) if ( $action =~ /^v/ );
    $dbh->disconnect;
} else {
    print "\n\n..:: UniPrime ::..\n> Standalone program version $version <\n\nFATAL: Incorrect arguments.\nUsage: uniprime.pl --action=<action> --target==<ID> [options]\n\n  Available actions are:\n   'locus'   Add a new locus:\n    --target GenBank GeneID to be used for this action. (requested*)\n    --pmid   Associate a reference. (PMID)\n    --type   Set locus type. (default 6 for proteic gene)\n    --status Set locus status. (default 1 for preliminary)\n\n   'ortho'   Find new orthologues from mRNA sequences of the locus prototype\n             with BLASTN with the following options:\n    --target LocusID to be used for this action. (requested*)\n    --db     Database used when performing the tblastx search. (default\n             value 'refseq_rna')\n    --query  the BLAST search can be limited to the result of an Entrez query\n             against the database chosen. (default none; e.g. 'viruses[ORGN]')\n    --dna    Use DNA rather than mRNA as initial input sequence. (default mRNA)\n    -e       Set the E-value threshold. It is a positive real number. The\n             default is 1e-100. Hit with E-value better than (less than)\n             this threshold will be shown.\n\n   'align'   Provide alignment using T-coffee:\n    --target LocusID to be used for this action. (requested*)\n    --dna    Use DNA rather than mRNA as initial input sequence. (default mRNA)\n    -c       Set the threshold to establish the consensus sequence. It is a\n             positive number between 0 and 100. (default 70)\n    --select Specify the sub-set of sequence used for the alignement. (e.g.\n             --select=S3.1 --select=S3.2 --select=S3.4 specify 3 sequences\n             only S3.1, S3.2 and S3.4)\n\n   'primer'  Identify universal primers from consensus sequence:\n    --target LocusID to be used for this action. (requested*)\n    --size   Optimal size of the amplification. (default 600)\n\n   'vPCR'    Virtual-PCR retrieving all amplicons:\n    --target 'PrimerID to be used for this action. (requested*)\n    --db     Database used when performing the tblastx search. (default\n             value 'wgs')\n    --query  the BLAST search can be limited to the result of an Entrez query\n             against the database chosen. (default 'viruses[ORGN]')\n\n    -v       Print verbose output.\n\n";
    $out++;
}

exit($out);

