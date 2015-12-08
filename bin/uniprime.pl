#!/usr/bin/perl
#
# Universal Primer Design Tools (UniPrime package)
#
# Copyright 2006-2012 Bekaert M <michael.bekaert@stir.ac.uk>
#   Edited by Robin Boutros (2009)
#   Edited by Fabrice Cheng (2010)
#
# This program is free software: you can redistribute it and/or modify it under the terms
# of the GNU Lesser General Public License as published by the Free Software Foundation
# version 3 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
#
use strict;
use warnings;
use DBI;
use Getopt::Long;
use UniTools;

#----------------------------------------
my $version = '2.10 (Ootoowerg)';
my $db_name = 'uniprime';
my $db_user = $ENV{'USER'};
my $db_host = 'localhost';
my $db_pass = q{};

#----------------------------------------------------------
my ($email, $target, $region, $action, $pmid, $align_gapopen, $align_gapext, $db, @selected);
my (
    $verbose,         $aligner,       $query,           $dna,             $evalue,          $consensus,         $size,            $status,        $type,          $out,           $align_Mlalign,
    $align_Mclustalw, $align_Mfast,   $align_Mslow,     $align_matrix,    $primer_min_size, $primer_opt_size,   $primer_max_size, $primer_min_tm, $primer_opt_tm, $primer_max_tm, $primer_min_gc,
    $primer_opt_gc,   $primer_max_gc, $primer_self_any, $primer_self_end, $primer_num_ns,   $primer_max_poly_x, $primer_gc_clamp, $remote,        $webserver
   )
  = (0, 'GramAlign', 'viruses[ORGN]', 0, 1e-40, 60, 600, 1, 6, 1, 1, 0, 0, 1, 0, 18, 22, 27, 55, 60, 65, 40, 50, 60, 6, 3, 2, 5, 1, 1, 0);
GetOptions(
           'action=s'            => \$action,
           'target=s'            => \$target,
           'region:s'            => \$region,
           'db:s'                => \$db,
           'aligner:s'           => \$aligner,
           'dna!'                => \$dna,
           'e:f'                 => \$evalue,
           'c:i'                 => \$consensus,
           'query:s'             => \$query,
           'select:s@'           => \@selected,
           'size:i'              => \$size,
           'pmid:i'              => \$pmid,
           'status:i'            => \$status,
           'type:i'              => \$type,
           'gapopen:f'           => \$align_gapopen,
           'gapext:f'            => \$align_gapext,
           'lalign_id_pair!'     => \$align_Mlalign,
           'clustalw_pair!'      => \$align_Mclustalw,
           'fast_pair!'          => \$align_Mfast,
           'slow_pair!'          => \$align_Mslow,
           'matrix!'             => \$align_matrix,
           'primer_min_size:i'   => \$primer_min_size,
           'primer_opt_size:i'   => \$primer_opt_size,
           'primer_max_size:i'   => \$primer_max_size,
           'primer_min_tm:f'     => \$primer_min_tm,
           'primer_opt_tm:f'     => \$primer_opt_tm,
           'primer_max_tm:f'     => \$primer_max_tm,
           'primer_min_gc:f'     => \$primer_min_gc,
           'primer_opt_gc:f'     => \$primer_opt_gc,
           'primer_max_gc:f'     => \$primer_max_gc,
           'primer_self_any:f'   => \$primer_self_any,
           'primer_self_end:f'   => \$primer_self_end,
           'primer_num_ns:i'     => \$primer_num_ns,
           'primer_max_poly_x:i' => \$primer_max_poly_x,
           'primer_gc_clamp:i'   => \$primer_gc_clamp,
           'v!'                  => \$verbose
          );
if (   (defined $target)
    && (defined $action)
    && (($action =~ m/^[opav]/x) && ($target =~ m/[LAX](\d+)\.(\d+)/x) || ($action =~ m/^[l]/x) && (($target =~ m/(\d+)/x) || (-r $target)))
    && $primer_min_size > 10
    && $primer_opt_size > $primer_min_size
    && $primer_max_size > $primer_opt_size
    && $primer_max_size < 50
    && $primer_min_tm > 20
    && $primer_opt_tm > $primer_min_tm
    && $primer_max_tm > $primer_opt_tm
    && $primer_max_tm < 90
    && $primer_min_gc >= 0
    && $primer_opt_gc > $primer_min_gc
    && $primer_max_gc > $primer_opt_gc
    && $primer_max_gc <= 100
    && $primer_self_any > 0
    && $primer_self_end > 0
    && $primer_num_ns <= 10
    && $primer_max_poly_x > 0
    && $primer_gc_clamp <= 10)
{
    my ($prefix, $id);
    if (defined $2)
    {
        $prefix = oct $1;
        $id     = oct $2;
    }
    else { $id = $target; }
    $out--;
    $db = (($action =~ m/^[v]/x) ? 'wgs' : ($dna ? 'refseq_genomic' : 'refseq_rna')) unless (defined $db);
    print {*STDERR} "\n..:: UniPrime ::..\n> Standalone program version $version <\n\n" if ($verbose);
    my $dbh = DBI->connect("DBI:Pg:dbname=$db_name" . (($db_host ne 'localhost') ? ";host=$db_host" : q{}), $db_user, $db_pass) or die($DBI::errstr);
    my $uniprime_obj = UniTools->new($aligner, $dbh, $remote, $verbose, $webserver);
    $uniprime_obj->addLocus($id, $status, $pmid, $type) if ($action =~ m/^l/x);
    $uniprime_obj->populate_orthologues($prefix, $id, $evalue, lc $db, $dna, $query) if ($action =~ m/^o/x);
    $uniprime_obj->populate_alignment($prefix, $id, $consensus, $dna, $align_gapext, $align_Mlalign, $align_Mclustalw, $align_Mfast, $align_Mslow, $align_matrix, @selected) if ($action =~ m/^a/x);
    $uniprime_obj->populate_primer($prefix,        $id,            $size,          $primer_min_size, $primer_opt_size, $primer_max_size, $primer_min_tm,     $primer_opt_tm, $primer_max_tm,
                                   $primer_min_gc, $primer_opt_gc, $primer_max_gc, $primer_self_any, $primer_self_end, $primer_num_ns,   $primer_max_poly_x, $primer_gc_clamp)
      if ($action =~ m/^p/x);
    $uniprime_obj->virtual_amplicon($prefix, $id, $query, lc $db, 5000) if ($action =~ m/^v/x);
    $dbh->disconnect;
}
else
{
    print
      "\n\n..:: UniPrime ::..\n> Standalone program version $version <\n\nFATAL: Incorrect arguments.\nUsage:      uniprime.pl --action=<action> --target=<ID> [options]\n\n  Available actions are:\n   'locus'   Add a new locus:\n    --target GenBank GeneID to be used for this action or fasta file to be used.\n             (mandatory*)\n    --pmid   Associate a reference. (PMID)\n\n   'ortho'   Find new orthologues from mRNA sequences of the locus prototype\n             with BLASTN with the following options:\n    --target LocusID to be used for this action. (mandatory*)\n    --db     Database used when performing the tblastx search. (default\n             value 'refseq_rna')\n    --query  the BLAST search can be limited to the result of an Entrez query\n             against the database chosen. (default none; e.g. 'viruses[ORGN]')\n    --dna    Use DNA rather than mRNA as initial input sequence. (default mRNA)\n    -e       Set the E-value threshold. It is a positive real number. The\n             default is 1e-100. Hit with E-value better than (less than)\n             this threshold will be shown.\n\n   'align'   Provide alignment using T-coffee:\n    --target LocusID to be used for this action. (mandatory*)\n    --dna    Use DNA rather than mRNA as initial input sequence. (default mRNA)\n    -c       Set the threshold to establish the consensus sequence. It is a\n             positive number between 0 and 100. (default 60)\n    --select Specify the sub-set of sequence used for the alignement. (e.g.\n             --select=S3.1 --select=S3.2 --select=S3.4 specify 3 sequences\n             only S3.1, S3.2 and S3.4)\n\n   'primer'  Identify universal primers from consensus sequence:\n    --target AlignmentID to be used for this action. (mandatory*)\n    --size   Optimal size of the amplification. (default 600)\n\n   'vPCR'    Virtual-PCR retrieving all amplicons:\n    --target 'PrimerID to be used for this action. (mandatory*)\n    --db     Database used when performing the tblastx search. (default\n             value 'wgs')\n    --query  the BLAST search can be limited to the result of an Entrez query\n             against the database chosen. (default 'viruses[ORGN]')\n\n   Global options:\n    --aligner either GramAlign or T-coffee. (Default GramAlign)\n    -v       Print verbose output.\n\n";
    $out++;
}
exit($out);
