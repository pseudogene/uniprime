## $Id: UniTools.pm,v 2.10 2012/09/07 12:35:58 Scotland/Stirling $
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

=head1 NAME

Bio::UniTools - Universal Primer Design Tools

=head1 DESCRIPTION

Provide basic and core functions from Sequence downloading, SQL queries, multi-alignment
parser, primer selection and, virtual PCRs using NCBI Blastn and GenBank database.

=head1 REQUIREMENTS

To use this module you may need:
 * primer3 (L<http://primer3.sourceforge.net/>)
 * T-coffee (L<http://www.tcoffee.org/>)
   or GramAlign (L<http://bioinfo.unl.edu/gramalign.php>),
 * PostgreSQL (L<http://www.postgresql.org/>) server and Perl client.

=head1 FEEDBACK

User feedback is an integral part of the evolution of this module. Send your comments and
suggestions preferably to author.

=head1 AUTHOR

B<Michael Bekaert> (michael.bekaert@stir.ac.uk)

Address:
     Institute of Aquaculture
     University of Stirling
     Stirling
     Scotland, FK9 4LA
     UK

=head1 SEE ALSO

perl(1), primer3_core, T-coffee or GramAlign

=head1 LICENSE AND COPYRIGHT

Copyright 2006-2012 - Michael Bekaert

This program is free software: you can redistribute it and/or modify it under the terms
of the GNU Lesser General Public License as published by the Free Software Foundation
version 3 of the License.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License along with this
program.  If not, see <http://www.gnu.org/licenses/>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are
usually preceded with a _

=cut

package UniTools;
use vars qw($VERSION);
use strict;
use warnings;
use Cwd;
use POSIX qw(ceil floor);
use File::Temp qw/tempfile/;
use DBI;
use MIME::Base64;
use File::Basename;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Cookies;
$VERSION = '2.10';

# Default path
use constant PATH_TMP => '/tmp';

=head2 _findexec

 Title   : _findexec
 Usage   : my $path = $self->_findexec( $exec );
 Function: Find an executable file in the $PATH.
 Returns : The full path to the executable.
 Args    : $exec (mandatory) executable to be found.

=cut

sub _findexec
{
    my ($self, @args) = @_;
    my $exec = shift(@args);
    foreach my $p (split m/:/, $ENV{'PATH'}) { return "$p/$exec" if (-x "$p/$exec"); }
    return;
}

=head2 _trim

 Title   : _trim
 Usage   : my $response = $self->trim( $query );
 Function: Strip whitespace (or other characters) from the beginning
           and end of a string.
 Returns : $response, string with whitespace stripped.
 Args    : $query (mandatory), string to be strip.

=cut

sub _trim
{
    my ($self, @args) = @_;
    my $query = shift(@args);
    $query =~ s/^\s+//;
    $query =~ s/\s+$//;
    return $query;
}

=head2 _compress

 Title   : _compress
 Usage   : my $response = $self->_compress( $query );
 Function: Compress a string into bzip2-encoded data then encodes it with MIME base64.
           This encoding is designed to make binary data survive transport through
           transport layers that are not 8-bit clean.
 Returns : $response, data encoded.
 Args    : $query (mandatory), string/binary to be encoded.

=cut

sub _compress
{
    my ($self, @args) = @_;
    my $query = shift(@args);
    my $PATH_BZIP = ((defined $ENV{'BZIPDIR'}) ? $ENV{'BZIPDIR'} : $self->_findexec('bzip2'));
    my ($BZ2, $filename) = tempfile(DIR => PATH_TMP, UNLINK => 1);
    print {$BZ2} $query;
    close $BZ2;
    $query = encode_base64(`$PATH_BZIP -9 -c $filename`);
    unlink($filename);
    return $query;
}

=head2 _uncompress

 Title   : _uncompress
 Usage   : my $response = $self->_uncompress( $query );
 Function: Decodes data encoded with MIME base64 and bzip2 encoded.
 Returns : $response, data/binary decoded.
 Args    : $query (mandatory), string to be decoded.

=cut

sub _uncompress
{
    my ($self, @args) = @_;
    my $query = shift(@args);
    my $PATH_BZIP = ((defined $ENV{'BZIPDIR'}) ? $ENV{'BZIPDIR'} : $self->_findexec('bzip2'));
    my ($BZ2, $filename) = tempfile(DIR => PATH_TMP, UNLINK => 1);
    print $BZ2 decode_base64($query);
    close $BZ2;
    $query = `$PATH_BZIP -d -c $filename`;
    unlink($filename);
    return $query;
}

=head2 _getHTTP

 Title   : _getHTTP
 Usage   : my $response = $self->_getHTTP( $query );
 Function: Download Page (HTTP protocol).
 Returns : $response downloaded page.
 Args    : $query (mandatory), page address.

=cut

sub _getHTTP
{
    my ($self, @args) = @_;
    my $query = shift(@args);
    $query =~ tr/ /+/;
    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar(HTTP::Cookies->new(file => "lwpcookies.txt", autosave => 1));
    my $req = HTTP::Request->new(GET => $query);
    my $res = $ua->request($req);
    return unless ($res->is_success);
    return $res->as_string;
}

=head2 _updateStatus

 Title   : _updateStatusGene (webserver)
 Usage   : $self->_updateStatusGene( $geneid, $reload, $gonext, $desc );
 Function: Update the status using the GenID.
 Returns : return the genID.
 Args    : $geneid (mandatory), geneid of the hit;
           $reload (mandatory), ;
           $gonext (mandatory), ;
           $desc (mandatory), .

=cut

sub _updateStatus
{
    my ($self, @args) = @_;
    my ($geneid, $reload, $gonext, $desc) = @args;
    my $execstatus;
    if ($self->{'_webserver'})
    {
        if (!exists $self->{'_prefix'})
        {
            $execstatus = $self->{'_dbh'}->prepare('UPDATE execstatus SET status=?, description=? WHERE email=? AND genid=?;');
            $execstatus->execute(
                                 $reload,
                                 '<p>'
                                   . (($reload == 0 && !$gonext) ? '<img class="loading" src="images/loader.gif" alt="">' : q{})
                                   . $desc . '</p>'
                                   . (($reload == 1) ? '<a href="#" onclick="window.location.reload(true);">Refresh the page</a>' : q{})
                                   . (($gonext) ? '<a href="query.php">Go to the next step.</a>' : q{}),
                                 $self->{'_email'},
                                 $geneid
                                );
        }
        else
        {
            $execstatus = $self->{'_dbh'}->prepare('UPDATE execstatus SET status=?, description=? WHERE email=? AND locus_prefix=? and locus_id=?;');
            $execstatus->execute(
                                 $reload,
                                 '<p>'
                                   . (($reload == 0 && !$gonext) ? '<img class="loading" src="images/loader.gif" alt="">' : q{})
                                   . $desc . '</p>'
                                   . (($reload == 1) ? '<a href="#" onclick="window.location.reload(true);">Refresh the page</a>' : q{})
                                   . (($gonext) ? '<a href="query.php">Go to the next step.</a>' : q{}),
                                 $self->{'_email'},
                                 $self->{'_prefix'},
                                 $self->{'_id'}
                                );
        }
        $execstatus->finish();
    }
    print {*STDERR} '> Status update: ', (exists $self->{'_prefix'} ? 'Prefix ' . $self->{'_prefix'} . ' and ID ' . $self->{'_id'} : 'GeneID ' . $geneid), ' "', $desc, "\"\n" if ($self->{'_verbose'});
    return;
}

=head2 _critial_error

 Title   : _critial_error
 Usage   : $self->_critial_error( $desc, $errlevel );
 Function: Update the status using the prefix/id.
 Returns : none.
 Args    : $desc (mandatory), error description;
           $errlevel (optional), error number.

=cut

sub _critial_error
{
    my ($self, @args)     = @_;
    my ($desc, $errlevel) = @args;
    if ($self->{'_webserver'})
    {
        #my $execstatus = $dbh->prepare('UPDATE execstatus SET status=-1, description=? WHERE email=? AND genid=?;');
        #$execstatus->execute('<p>' . $desc . '</p>', $self->{'_email'}, $geneid);
        #$execstatus->finish();
    }
    print {*STDERR} '### ', $desc, (defined $errlevel ? ' [' . $errlevel . q{]} : q{}), "!\n";
    return;
}

=head2 _parcefasta

 Title   : _parcefasta
 Usage   : my %response = $self->_parcefasta( $infile );
 Function: Parce the first FASTA sequence of $infile.
 Returns : %response, hash (name and nucleotid sequence).
 Args    : $infile (mandatory), fasta file.

=cut

sub _parcefasta
{
    my ($self, @args) = @_;
    my $infile = shift(@args);
    if (open my $FASTA, '<', $infile)
    {
        my %result;
        while (<$FASTA>)
        {
            if (defined $result{'name'} && !m/^>/)
            {
                s/[^ATCGU]//igx;
                chomp;
                $result{'seq'} .= uc $_;
            }
            elsif (defined $result{'name'} && m/^>/) { last; }
            if (m/^>(.*)$/)
            {
                $result{'name'} = $1;
                $result{'seq'}  = q{};
            }
        }
        close $FASTA;
        return %result if (length($result{'seq'}) > 50);
    }
    return;
}

=head2 _subalign

 Title   : _subalign
 Usage   : my @response = $self->_subalign( $f, $r, $s );
 Function: Retrieve string A in B with mis-mismatches.
 Returns : $response, array (equivalent of A in B, begin, end positions).
 Args    : $f (mandatory), forward primer;
           $r (mandatory), reverse primer;
           $s (mandatory), needle string.

=cut

sub _subalign
{
    my ($self, @args) = @_;
    my ($f, $r, $s) = @args;
    my ($left_pos,  $left_align)  = $self->_align($f, $s, '-left');
    my ($right_pos, $right_align) = $self->_align($r, $s, '-right');
    my $length_s = $right_pos - $left_pos + 1;
    my $s_result = substr($s, $left_pos, $length_s);
    return ($s_result, $left_pos, $right_pos);
}

=head2 _align

 Title   : _align
 Usage   : my $response = $self->_align( $a, $b, $left_or_right );
 Function: Retrieve string A in B with mismatches.
 Returns : $response, equivalent of A in B.
 Args    : $a (mandatory), haystack string;
           $b (mandatory), needle string;
           $left_or_right (mandatory), direction.

=cut

sub _align
{
    my ($self, @args) = @_;
    my ($q, $s, $left_or_right) = @args;
    my ($SEQ, $tempfileseq) = tempfile(DIR => PATH_TMP, UNLINK => 1);
    print {$SEQ} '>Sequence1', "\n", $q, "\n";
    print {$SEQ} '>Sequence2', "\n", $s, "\n";
    my (undef, $output_file) = tempfile(DIR => PATH_TMP, OPEN => 0);
    my $cwd = getcwd();
    my @thealigner;
    if ($self->{'_aligner'} eq 'GramAlign') { @thealigner = ($self->{'_aligner_bin'} . ' -i ' . $tempfileseq . ' -o ' . $output_file . ' -f 2 -q'); }
    elsif ($self->{'_aligner'} eq 't_coffee')
    {
        @thealigner = ($self->{'_aligner_bin'} . ' -infile=' . $tempfileseq . ' -outfile=' . $output_file . ' -output=fasta_aln –type=dna -quiet aligner_bin');
##sample_seq1.dnd unlink(???);
    }
    chdir(PATH_TMP);
    if (system(@thealigner) != 0)
    {
        $self->_critial_error('Critial error in function _align: failed to launch the aligner', 1);
        exit(1);
    }
    chdir($cwd);
    my $count   = 0;
    my $count2  = 0;
    my $count3  = 0;
    my $species = 0;
    my $step    = 0;
    my $result  = q{};

    if (open my $ALIGNOUTPUT, '<', $output_file)
    {
        while (my $line = <$ALIGNOUTPUT>)
        {
            my @tab_lettre = split(m//, $line);
            if ($step == 4) { last; }
            foreach my $lettre (@tab_lettre)
            {
                if ($lettre eq q{>})
                {
                    ++$species;
                    if ($species == 2) { $step = 2; }
                    last;
                }
                else
                {
                    if ($lettre eq "\n") { last; }
                    if ($step == 0)
                    {
                        if ($lettre eq q{-}) { ++$count; }
                        else
                        {
                            if ($species == 1) { $step = 1; }
                            last;
                        }
                    }
                    if ($step == 1) { last; }
                    if ($step == 2)
                    {
                        if ($count2 < $count) { ++$count2; }
                        else
                        {
                            if ($count3 < length($q))
                            {
                                if ($lettre eq q{-}) { return (0, undef); }
                                $result = $result . $lettre;
                                ++$count3;
                            }
                            else
                            {
                                $step = 4;
                                last;
                            }
                        }
                    }
                }
            }
        }
        close $ALIGNOUTPUT;
        close $SEQ;
        unlink($tempfileseq);
        unlink($output_file);
    }
    else
    {
        $self->_critial_error('Critial error in function _align: failed to Open input file', 2);
        exit(2);
    }
    my $position = $count + length($q);
    if ($count == 0) { $count = -1 }
    if ($left_or_right eq '-left')  { return ($count + 1, $result); }
    if ($left_or_right eq '-right') { return ($position,  $result); }
}

=head2 _calculate_consensus

 Title   : _calculate_consensus
 Usage   : $self->_calculate_consensus( $num_nucleotide, $treshold, $option, @matrix );
 Function: Find the majority nucleotide (> $treshold) otherwise put a '?'.
 Returns : The majority nucleotide.
 Args    :  $num_nucleotide (mandatory), position of the majority nucleotide we are
           looking for in the sequence;
           $treshold (optional) threshold of the consensus generated, between 1 and 100
           (default 60);
           $option;
           @matrix (mandatory), the matrix that contains the fasta sequence of all
           species.


=cut

sub _calculate_consensus
{
    my ($self, @args) = @_;
    my ($num_nucleotide, $treshold, $option, @matrix) = @args;
    my $rate           = 0;
    my %map_nucleotide = ();
    my $max_occurence  = 0;
    my $max_nucleotide;
    for my $i (1 .. $#matrix) { $map_nucleotide{$matrix[$i][$num_nucleotide]} = 0; }
    if (!defined $treshold) { $treshold = 60; }
    $rate = $treshold / 100 * $#matrix;
    for my $i (1 .. $#matrix) { $map_nucleotide{$matrix[$i][$num_nucleotide]}++; }

    while (my ($key, $value) = each(%map_nucleotide))
    {
        if ($value > $max_occurence)
        {
            $max_occurence  = $value;
            $max_nucleotide = $key;
        }
    }
    if ($max_occurence >= $rate)
    {
        if ($max_nucleotide ne q{-})
        {
            if ($max_nucleotide eq "\n") { return q{}; }
            return $max_nucleotide;
        }
        else
        {
            if   ($option eq 'with-') { return q{-}; }
            else                      { return q{N}; }
        }
    }
    else { return q{N}; }
    return;
}

=head2 _consensus

 Title   : _consensus
 Usage   : $self->_consensus( $file_aln, $treshold, $specie );
 Function: Create the consensus sequence from the result of GramAlign/T-Coffee.
 Returns : A String that represents the consensus sequence.
 Args    : $file_aln (mandatory), the file that contains the result of the aligner
           (aligned fasta);
           $treshold (optional) threshold of the consensus generated, between 1 and 100
           (default 60);
           $specie.


=cut

sub _consensus
{
    my ($self, @args) = @_;
    my ($file_aln, $treshold, $specie) = @args;
    $specie .= "\n";
    my $consensus = q{};
    my @matrix;
    my $i              = 0;
    my $j              = 0;
    my $current_specie = q{};
    my $specie_int     = 1;
    open my $FILE_OUT, '<', $file_aln;

    while (my $line = <$FILE_OUT>)
    {
        my @tab_lettre = split(m//, $line);
        foreach my $lettre (@tab_lettre)
        {
            if ($lettre eq '>')
            {
                $i++;
                $j = 0;
                $current_specie = substr($line, 1);
                if ($specie eq $current_specie) { $specie_int = $i; }
                last;
            }
            else
            {
                $matrix[$i][$j] = $lettre;
                $j++;
            }
        }
    }
    for my $num_nucleotide (0 .. $#{$matrix[1]}) { $consensus .= $self->_calculate_consensus($num_nucleotide, $treshold, 'with-', @matrix); }
    close $FILE_OUT;
    return ($consensus, $specie_int, @matrix);
}

=head2 _spacing

 Title   : _spacing
 Usage   : $self->_spacing( $structure, $consensus, $specie_int, @matrix );
 Function: Adding the spacing to the consensus sequence from the $structure.
 Returns : A String that represents the consensus sequence with the spacing.
 Args    : $structure;
           $consensus;
           $specie_int;
           @matrix.

=cut

sub _spacing
{
    my ($self, @args) = @_;
    my ($structure, $consensus, $specie_int, @matrix) = @args;
    my $pos = 0;
    my ($length, $tmp_2, $tmp_count) = (0, 0, 0);
    my $realcount      = 0;
    my $count          = 0;
    my %hash_result    = ();
    my $real_consensus = q{};
    my $shift          = 0;
    while ($structure =~ m/(\d+)\.\.(\d+)/gx)
    {
        if ($pos != 0) { $length = $1 - $tmp_2; }
        if ($pos == 0) { $shift  = $1 - 1; }
        $pos += ($2 - $1 + 1);
        if ($length != 0) { $real_consensus .= substr($consensus, $tmp_count - $shift, $count - $tmp_count - $shift) . q{N} x $length; }
        $tmp_2     = $2;
        $realcount = 0;
        $tmp_count = $count;
        $count     = 0;

        for my $i (0 .. $#{$matrix[1]})
        {
            if ($matrix[$specie_int][$i] ne q{-}) { $realcount++; }
            $count++;
            if ($realcount > $pos) { last; }
        }
    }
    $real_consensus = $real_consensus . substr($consensus, $tmp_count - $shift);
    return $real_consensus;
}

=head2 _getMedLine

Title   : _getMedLine
Usage   : my $response = $self->_getMedLine( @accession );
Function: Download MedLine citation.
Returns : $response reference list (wiki style).
Args    : @accession (mandatory), list of pmid.

=cut

sub _getMedLine
{
    my ($self, @args) = @_;
    my (@accession) = @args;
    my $res = q{};
    foreach (@accession)
    {
        my %biblio;
        if (my $result = $self->_getHTTP('http://www.hubmed.org/export/mods.cgi?uids=' . $_))
        {
            foreach (split(m/\n/, $result))
            {
                if (m/<title>(.*)<\/title>/) { $biblio{'title'} = $1 unless (exists $biblio{'title'}); }
                elsif (m/<identifier type="doi">(.*)<\/identifier>/)  { $biblio{'doi'}  = $1; }
                elsif (m/<identifier type="pmid">(.*)<\/identifier>/) { $biblio{'pmid'} = $1; }
            }
            if ((exists $biblio{'title'}) && (exists $biblio{'pmid'} || (exists $biblio{'doi'} && $biblio{'doi'} ne q{})))
            {
                $res .= q{[} . ((exists $biblio{'doi'} && $biblio{'doi'} ne q{}) ? 'http://dx.doi.org/' . $biblio{'doi'} : 'http://www.hubmed.org/display.cgi?uids=' . $biblio{'pmid'}) . q{|} . $biblio{'title'} . q{]};
            }
        }
    }
    return $res;
}

=head2 _getGene

Title   : _getGene
Usage   : %gene = $self->_getGene( $geneid );
Function: Extract data from Gene DataBank (xml).
Returns : Hash with extracted data.
Args    : $geneid (mandatory), geneid of the hit.

=cut

sub _getGene
{
    my ($self, @args) = @_;
    my $geneid = shift(@args);
    my ($flag_geno, $flag_pheno, $flag_path) = (0, 0, 0);
    my @pmid;
    my %gene;
    if (my $result = $self->_getHTTP('http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&retmode=xml&id=' . $geneid))
    {
        foreach (split(m/\n/, $result))
        {
            if    (m/<Entrezgene_summary>(.*)<\/Entrezgene_summary>/) { $gene{'comment'} = $1; }
            elsif (m/<Gene-ref_locus>(.*)<\/Gene-ref_locus>/)         { $gene{'locus'}   = $1; }
            elsif (m/<Gene-ref_syn_E>(.*)<\/Gene-ref_syn_E>/)         { $gene{'locus'}   = $1 unless (defined $gene{'locus'}); }
            elsif (m/<Gene-ref_desc>(.*)<\/Gene-ref_desc>/)           { $gene{'desc'}    = $1; }
            elsif (m/<Maps_display-str>(.*)<\/Maps_display-str>/)     { $gene{'map'}     = $1; }
            elsif (m/<Gene-commentary_type value="genomic">1<\/Gene-commentary_type>/) { $flag_geno++; }
            elsif (($flag_geno == 1) && m/<Gene-commentary_accession>(.*)<\/Gene-commentary_accession>/) { $gene{'accession'} = $1; }
            elsif (($flag_geno == 1) && m/<Seq-interval_from>(\d+)<\/Seq-interval_from>/)                { $gene{'start'}     = $1 + 1; }
            elsif (($flag_geno == 1) && m/<Seq-interval_to>(\d+)<\/Seq-interval_to>/)
            {
                $gene{'end'} = $1 + 1;
                $flag_geno++;
            }
            elsif (m/<Gene-commentary_type value="phenotype">.*<\/Gene-commentary_type>/) { $flag_pheno++; }
            elsif (($flag_pheno == 1) && m/<Gene-commentary_text>(.*)<\/Gene-commentary_text>/)
            {
                if (defined $gene{'phenotype'}) { $gene{'phenotype'} .= q{|} . $1; }
                else                            { $gene{'phenotype'} = $1; }
                $flag_pheno--;
            }
            elsif (m/<Gene-commentary_heading>Pathways<\/Gene-commentary_heading>/) { $flag_path++; }
            elsif (($flag_path == 1) && m/<Gene-commentary_text>(.*)<\/Gene-commentary_text>/)
            {
                if (defined $gene{'pathway'}) { $gene{'pathway'} .= q{|} . $1; }
                else                          { $gene{'pathway'} = $1; }
            }
            elsif (($flag_path == 1) && m/<\/Gene-commentary>/) { $flag_path--; }
            elsif (m/<PubMedId>(.*)<\/PubMedId>/) { push(@pmid, $1); }
        }
        if (@pmid)
        {
            my %seen = ();
            @{$gene{'pmid'}} = grep { !$seen{$_}++ } @pmid;
            @{$gene{'pmid'}} = sort @{$gene{'pmid'}};
            @{$gene{'pmid'}} = reverse @{$gene{'pmid'}};
        }
    }
    return %gene;
}

=head2 _getSequence

Title   : _getSequence
Usage   : %sequence = $self->_getSequence( $accession, $start, $end, $strand );
Function: Extract relevant information from sequence.
Returns : Hash with extracted data.
Args    : $accession (mandatory), accession number of the hit;
          $start (mandatory), begin of the sequence;
          $end (mandatory), end of the sequence;
          $strand (optional), boolean undef (or false) allow automatic
          strand selection, true disable any selection.

=cut

sub _getSequence
{
    my ($self, @args) = @_;
    my ($accession, $start, $end, $strand) = @args;
    $strand = (((defined $strand) && $strand) ? 1 : 0);
    my ($flag_s, $flag_c, $flag_g, $flag_m, $flag_go, $flag_dna, $rna);
    my %sequence;
    if (my $result = $self->_getHTTP("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=$accession&rettype=gb&seq_start=$start&seq_stop=$end"))
    {
        foreach (split(/\n/, $result))
        {
            if (/^LOCUS /)
            {
                $sequence{'size'} = int(substr $_, 29, 11);
                $sequence{'division'} = uc($self->_trim(substr $_, 64, 3));
                $sequence{'molecule'} = $self->_trim(substr $_, 44, 7);
                $sequence{'circular'} = (((substr $_, 55, 8) eq 'circular') ? q{t} : q{f});
            }
            elsif (m/^VERSION     ([\d\w\_]+.\d+)/) { $sequence{'reference'} = uc($1); }
            elsif (m/^SOURCE .*\((.*)\)$/)          { $sequence{'common'}    = $1; }
            elsif (m/^  ORGANISM  (.*)$/)           { $sequence{'organism'}  = $1; }
            elsif (m/^     source          /)       { $flag_s                = 1; }
            elsif ((defined $flag_s) && m/^ {21}/)
            {
                $sequence{'taxonid'}    = int($1) if (m/\/db\_xref\=\"taxon\:(\d+)\"$/);
                $sequence{'isolate'}    = $1      if (m/\/isolate\=\"(.*)\"$/);
                $sequence{'chromosome'} = $1      if (m/\/chromosome\=\"(.*)\"$/);
                $sequence{'organelle'}  = $1      if (m/\/organelle\=\"(.*)\"$/);
                $sequence{'map'}        = $1      if (m/\/map\=\"(.*)\"$/);
            }
            elsif ((m/^     gene            (complement\()?(join\()?\D?(\d+)\..*\D(\d+)\D?(\))*$/) && (int($3) < 50) && (($sequence{'size'} - int($4)) < 50))
            {
                undef($flag_s);
                $sequence{'strand'}   = (((defined $1) && ($1 eq 'complement(')) ? -1 : 1);
                $sequence{'start'}    = $start + int($3) - 1;
                $sequence{'end'}      = $start + int($4) - 1;
                $sequence{'location'} = $sequence{'start'} . '..' . $sequence{'end'};
                $sequence{'location'} = 'complement(' . $sequence{'location'} . q{)} if ($sequence{'strand'} < 0);
                $flag_g               = 1;
            }
            elsif ((defined $flag_g) && !(defined $flag_c) && /^ {12}(.*)$/)
            {
                $sequence{'geneid'} = int($1) if (m/\/db\_xref\=\"GeneID\:(\d+)\"$/);
                $sequence{'hgnc'}   = int($1) if (m/\/db\_xref\=\"HGNC\:(\d+)\"$/);
                $sequence{'gene'}   = $1      if (m/\/gene\=\"(.*)\"$/);
            }
            elsif ((exists $sequence{'gene'}) && m/^     mRNA            (.*)$/)
            {
                undef($flag_g);
                $flag_m = 1;
                $rna    = $self->_trim($1);
            }
            elsif ((defined $flag_m) && m/^ {21}(.*)$/)
            {
                if ($flag_m == 1)
                {
                    if (m/\//) { $flag_m = 2; }
                    else       { $rna .= $self->_trim($1); }
                }
                if (($flag_m == 2) && (m/\/gene\=\"(.*)\"$/) && ($sequence{'gene'} eq $1)) { $flag_m = 3; }
                elsif (($flag_m == 3) && (m/\/transcript_id\=\"(.*)\"$/))
                {
                    if (my $result_rna = $self->_getHTTP("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=$1&rettype=fasta"))
                    {
                        my ($flag_gorna, $seq_rna);
                        foreach (split(m/\n/, $result_rna))
                        {
                            if (m/^\>/)
                            {
                                $flag_gorna = 1;
                                $seq_rna    = q{};
                            }
                            elsif (defined $flag_gorna) { $seq_rna .= $_; }
                        }
                        if ($sequence{'strand'} < 0)
                        {
                            my @loc;
                            while ($rna =~ m/(\d+)\.\.(\d+)/go) { push @loc, ($sequence{'size'} - $2 + 1) . '..' . ($sequence{'size'} - $1 + 1); }
                            $rna = join(q{,}, reverse(@loc));
                            $rna = 'join(' . $rna . q{)} if ($#loc > 0);
                        }
                        $seq_rna =~ s/\W//g;
                        push @{$sequence{'rna'}},     $rna;
                        push @{$sequence{'rna_seq'}}, $seq_rna;
                    }
                    undef($flag_m);
                }
            }
            elsif ((exists $sequence{'gene'}) && m/^     CDS             /)
            {
                undef($flag_g);
                undef($flag_m);
                $flag_c = 1;
            }
            elsif ((defined $flag_c) && m/^ {21}/)
            {
                if (m/ \/gene\=\"(.*)\"$/ && ($1 eq $sequence{'gene'})) { $flag_c = 2; }
                elsif ($flag_c == 2)
                {
                    if (m/\/transl\_table\=(\d+)$/) { $sequence{'translation'} = int($1); }
                    elsif (m/\/go\_process\=\"(.*)$/i)
                    {
                        $flag_go = 1;
                        $sequence{'go'} = $1;
                    }
                    elsif ((defined $flag_go) && m/\//)
                    {
                        undef($flag_go);
                        $sequence{'go'} = substr $sequence{'go'}, 0, (length($sequence{'go'}) - 1);
                    }
                    elsif (defined $flag_go) { $sequence{'go'} .= q{ } . $self->_trim($_); }
                }
            }
            elsif (m/^ORIGIN/)
            {
                undef($flag_g);
                undef($flag_c);
                $flag_dna = 1;
                $sequence{'sequence'} = q{};
            }
            elsif ((defined $flag_dna) && !(m/^\/\//)) { $sequence{'sequence'} .= $_; }
            elsif ((defined $flag_dna) && m/^\/\//)
            {
                undef($flag_dna);
                $sequence{'sequence'} = uc $sequence{'sequence'};
                $sequence{'sequence'} =~ s/\W//g;
                $sequence{'sequence'} =~ s/\d//g;
                $sequence{'sequence'} = $self->_reverse_compl($sequence{'sequence'}) if (!$strand && (defined $sequence{'strand'}) && ($sequence{'strand'} < 0));
            }
        }
    }
    return %sequence;
}

=head2 _getOrganism

 Title   : _getOrganism
 Usage   : my $response = $self->_getOrganism( $key, $start, $end, $dna, $mystep );
 Step    : 2 - Orthologs Search
           5 - Virtual PCR
 Function: Retrieve hit blast sequence and identifies organism and geneid
           (Faster than a classical Bio::DB::Genbank).
 Returns : $response, string TaxonID and GeneID or undef.
 Args    : $key (mandatory), Accession number;
           $start (mandatory), begin of the subsequence;
           $end (mandatory), end of the subsequence;
           $dna (mandatory), boolean allow DNA sequence;
           $mystep (mandatory), step.

=cut

sub _getOrganism
{
    my ($self, @args) = @_;
    my ($key, $start, $end, $dna, $mystep) = @args;
    my ($taxonid, $organism, $molecule, $division, $geneid, $flag) = (0, q{}, q{}, q{}, 0, 0);
    if (my $result = $self->_getHTTP("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=$key&rettype=gb&seq_start=$start&seq_stop=$end"))
    {
        if ($mystep == 2 && $self->{'_webserver'})
        {
            my $debut = index($result, 'ORGANISM');
            my @splitorg = split(m/;/, substr($result, $debut, index($result, q{.}, $debut) - $debut));
            $splitorg[0] = (split(m/\n/, $splitorg[0]))[1];
            my $sth = $self->{'_dbh'}->prepare('SELECT organisms FROM stepparams WHERE email=? AND locus_prefix=? AND locus_id=?');
            $sth->execute($self->{'_email'}, $self->{'_prefix'}, $self->{'_id'});
            if (my $listOrgs = $sth->fetchrow_hashref())
            {
                my $allOrgs = $listOrgs->{'organisms'};
                if (!$allOrgs) { $allOrgs = q{}; }
                foreach my $org (@splitorg)
                {
                    if ($org)
                    {
                        if (index($allOrgs, $org) == -1) { $allOrgs = $allOrgs . $org . q{;}; }
                    }
                }
                $sth = $self->{'_dbh'}->prepare('UPDATE stepparams SET organisms=? WHERE email=? AND locus_prefix=? AND locus_id=?;');
                $sth->execute($allOrgs, $self->{'_email'}, $self->{'_prefix'}, $self->{'_id'});
            }
            $sth->finish();
        }
        foreach (split(m/\n/, $result))
        {
            if (m/^LOCUS /) { $division = $self->_trim((substr $_, 64, 3)); }
            elsif (m/^  ORGANISM  (.*)$/)     { $organism = $1; }
            elsif (m/^     source          /) { $flag     = 1; }
            elsif (m/^ {21}/ && (defined $flag))
            {
                $taxonid  = $1 if (m/\/db\_xref\=\"taxon\:(\d+)\"$/);
                $geneid   = $1 if (m/\/db\_xref\=\"GeneID\:(\d+)\"$/);
                $molecule = $1 if (m/\/mol\_type\=\"(.*)\"$/);
            }
        }
        if (($taxonid > 0) && ($organism ne q{}))
        {
            if (($division ne 'CON') && (($dna == 1) || ($molecule =~ /RNA/)))
            {
                print {*STDERR} "  # Get $organism: $key (region $start..$end)\n" if ($self->{'_verbose'});
                return $taxonid . q{|} . $geneid;
            }
            else { print {*STDERR} "  # Skip $organism: $key (region $start..$end)\n" if ($self->{'_verbose'}); }
        }
        else { print {*STDERR} "  # Skip $key (region $start..$end): No information gathered\n" if ($self->{'_verbose'}); }
    }
    return;
}

=head2 _vBlast

Title   : _vBlast
Usage   : my @response = $self->_vBlasted( $bank, $evalue, $seq, $query );
Step    : 5 - Virtual PCR
Function: Make blast and retrieve hits.
Returns : @response, hash list of hits by taxonid.
Args    : $bank (mandatory), Genbank used for Blastn;
          $evalue (mandatory), threshold for Blastn;
          $seq (mandatory), query sequence (nucleotides) for Blastn;
          $query (optional), Entrez query limit.

=cut

sub _vBlast
{
    my ($self, @args) = @_;
    my ($bank, $evalue, $seq, $query) = @args;
    my %species;
    if (defined $seq)
    {
        my ($FILE, $tempfileseq) = tempfile(DIR => PATH_TMP, UNLINK => 1);
        print {$FILE} $seq;
        close($FILE);
        my (undef, $tempfileseqout) = tempfile(DIR => PATH_TMP, UNLINK => 1, OPEN => 0);
        my @theblast =
          (   $self->{'_blastn'}
            . ' -task blastn -dust yes -db '
            . $bank
            . (defined $query ? ' -entrez_query \'' . $query . '\' -remote' : $self->{'_remote'})
            . ' -query '
            . $tempfileseq
            . ' -out '
            . $tempfileseqout
            . ' -outfmt 7 -evalue '
            . $evalue
            . ' -word_size 15');
        if (system(@theblast) != 0)
        {
            $self->_critial_error('Communication error: NCBI Remote Blast is unavailable. Please try again', 3);
            exit(3);
        }
        my %hits = $self->_parseBlastResult($tempfileseqout);
        unlink($tempfileseq);
        unlink($tempfileseqout);
        my $size = length($seq);
        for (my $i = 0 ; $i < $hits{'_hits'} ; $i++)
        {
            my $geneid = $self->_getOrganism((split(m/\./, (split(m/\|/, $hits{'_name'}[$i]))[3]))[0], $hits{'_hitstart'}[$i], $hits{'_hitend'}[$i], 1, 5);
            if ((defined $geneid) && $geneid =~ m/(\d+)\|(\d+)/)
            {
                $species{$1} =
                    $hits{'_evalue'}[$i] . q{|}
                  . (split(/\./, (split(m/\|/, $hits{'_name'}[$i]))[3]))[0] . q{|}
                  . (  ($hits{'_hitstrand'}[$i] > 0)
                     ? ((($hits{'_hitstart'}[$i] - $hits{'_querystart'}[$i] + 1) >= 1) ? ($hits{'_hitstart'}[$i] - $hits{'_querystart'}[$i] + 1) : 1) . q{|} . ($hits{'_hitend'}[$i] + $size - $hits{'_queryend'}[$i])
                     : ((($hits{'_hitstart'}[$i] - $size + $hits{'_queryend'}[$i]) >= 1) ? ($hits{'_hitstart'}[$i] - $size + $hits{'_queryend'}[$i]) : 1) . q{|} . ($hits{'_hitend'}[$i] + $hits{'_querystart'}[$i] - 1))
                  . q{|}
                  . $hits{'_hitstrand'}[$i]
                  if (!(defined $species{$1}) || ($species{$1} =~ m/^(\.+)\|/ && float($1) < $hits{'_evalue'}[$i]));
            }
        }
    }
    return %species;
}

=head2 _parseBlastResult

 Title   : _parseBlastResult
 Usage   : my %response = $self->_parseBlastResult( $file );
 Function: Retrieve hits from file that contains blast result.
 Step    : 2 - Orthologs Search
 Returns : %response, hash list of hits by geneid.
 Args    : $file (mandatory), path of the file that contains the blast results.

=cut

sub _parseBlastResult
{
    my ($self, @args) = @_;
    my ($file) = @args;
    my %hits = ('_hits' => 0, '_name' => [], '_hitstart' => [], '_hitend' => [], '_evalue' => [], '_hitstrand' => [], '_queryend' => [], '_querystart' => []);
    if (open my $FILE_OUT, '<', $file)
    {
        while (my $line = <$FILE_OUT>)
        {
            my @blastinfo = split(m/\s+/, $line);
            if ($blastinfo[0] ne '#')
            {
                $hits{'_name'}[$hits{'_hits'}]       = $blastinfo[1];
                $hits{'_querystart'}[$hits{'_hits'}] = $blastinfo[6];
                $hits{'_queryend'}[$hits{'_hits'}]   = $blastinfo[7];
                $hits{'_hitstart'}[$hits{'_hits'}]   = $blastinfo[8];
                $hits{'_hitend'}[$hits{'_hits'}]     = $blastinfo[9];
                $hits{'_evalue'}[$hits{'_hits'}]     = $blastinfo[10];
                if   ($hits{'_hitstart'}[$hits{'_hits'}] <= $hits{'_hitend'}[$hits{'_hits'}]) { $hits{'_hitstrand'}[$hits{'_hits'}] = 1; }
                else                                                                          { $hits{'_hitstrand'}[$hits{'_hits'}] = -1; }
                $hits{'_hits'}++;
            }
        }
        close $FILE_OUT;
    }
    return %hits;
}

=head2 _getBlasted

 Title   : _getBlasted
 Usage   : my %response = $self->_getBlasted( $bank, $evalue, $seq, $dna, $query );
 Function: Make blast and retrieve hits.
 Step    : 2 - Orthologs Search
 Returns : %response, hash list of hits by geneid.
 Args    : $bank (mandatory), Genbank used for Blastn;
           $evalue (mandatory), threshold for Blastn;
           $seq (mandatory), query sequence (nucleotides) for Blastn;
           $dna (mandatory), boolean allow DNA sequence;
           $query (optional), Entrez query limit (e.g. "Mammalia"[ORGN]).

=cut

sub _getBlasted
{
    my ($self, @args) = @_;
    my ($bank, $evalue, $seq, $dna, $query) = @args;
    my %access;
    my %species;
    if (defined $seq)
    {
        my ($FILE, $tempfileseq) = tempfile(DIR => PATH_TMP, UNLINK => 1);
        print {$FILE} $seq;
        close($FILE);
        my (undef, $tempfileseqout) = tempfile(DIR => PATH_TMP, open => 0);
        if ($evalue < 1e-10)    ## constant!!
        {
            my @theblast =
              (   $self->{'_blastn'}
                . ' -task blastn -dust yes -db '
                . $bank
                . (defined $query ? ' -entrez_query \'' . $query . '\' -remote' : $self->{'_remote'})
                . ' -query '
                . $tempfileseq
                . ' -out '
                . $tempfileseqout
                . ' -outfmt 7 -evalue '
                . $evalue
                . ' -word_size 7');
            if (system(@theblast) != 0)
            {
                $self->_critial_error('Communication error: NCBI Remote Blast is unavailable. Please try again', 4);
                exit(4);
            }
        }
        else
        {
            my @theblast =
              (   $self->{'_blastn'}
                . ' -task blastn -dust yes -db '
                . $bank
                . (defined $query ? ' -entrez_query \'' . $query . '\' -remote' : $self->{'_remote'})
                . ' -query '
                . $tempfileseq
                . ' -out '
                . $tempfileseqout
                . ' -outfmt 7 -evalue '
                . $evalue);
            if (system(@theblast) != 0)
            {
                $self->_critial_error('Communication error: NCBI Remote Blast is unavailable. Please try again', 5);
                exit(5);
            }
        }
        my %hits = $self->_parseBlastResult($tempfileseqout);
        unlink($tempfileseq);
        unlink($tempfileseqout);
        for (my $i = 0 ; $i < $hits{'_hits'} ; $i++)
        {
            $self->_updateStatus(undef, 0, 0, 'Organism: ' . $hits{'_name'}[$i]);
            my $geneid = $self->_getOrganism((split(m/\./, (split(m/\|/, $hits{'_name'}[$i]))[3]))[0], $hits{'_hitstart'}[$i], $hits{'_hitend'}[$i], $dna, 2);
            if ((defined $geneid) && $geneid =~ /(\d+)\|(\d+)/)
            {
                $species{$1} = $hits{'_evalue'}[$i] . ($2 > 0 ? q{|} . $2 : q{*} . (split(m/\./, (split(m/\|/, $hits{'_name'}[$i]))[3]))[0] . q{+} . $hits{'_hitstart'}[$i] . q{+} . $hits{'_hitend'}[$i] . q{+} . $hits{'_hitstrand'}[$i])
                  if (!(defined $species{$1}) || ($species{$1} =~ m/(\.+)\|/ && float($1) < $hits{'_evalue'}[$i]));
            }
        }
        if (%species)
        {
            foreach my $key (keys %species)
            {
                $self->_updateStatus(undef, 0, 0, 'species | ' . $key);
                if ($species{$key} =~ m/(.+)\|(\d+)/) { $access{$2} = $1; }
                elsif ($species{$key} =~ m/(.+)\*(\w+)\+(\d+\+\d+\+-?\d+)/) { $access{$2} = $1 . q{*} . $3; }
            }
        }
    }
    return %access;
}

=head2 _addBlasted

 Title   : _addBlasted
 Usage   : $self->_addBlasted( $geneid, $evalue );
 Function: Add positive hit to database.
 Returns : none.
 Args    : $geneid (mandatory), geneid of the hit;
           $evalue (mandatory), e-value of Blast survey.

=cut

sub _addBlasted
{
    my ($self,   @args)   = @_;
    my ($geneid, $evalue) = @args;
    my %gene;
    if ($evalue =~ m/(.+)\*(\d+)\+(\d+)\+(-?\d+)/)
    {
        %gene   = ('accession' => $geneid, 'start' => $2, 'end' => $3, 'strand' => $4);
        $evalue = $1;
        $geneid = 0;
    }
    else { %gene = $self->_getGene($geneid); }
    if ((defined $gene{'accession'}) && (defined $gene{'start'}) && (defined $gene{'end'}))
    {
        my $prefix = floor((((localtime(time))[5] - 107) * 12 + (localtime(time))[4]) / 1.5);
        $self->_updateStatus($geneid, 0, 0, 'AccessionId: ' . $gene{'accession'} . " ($evalue)");
        my %sequence = $self->_getSequence($gene{'accession'}, $gene{'start'}, $gene{'end'}, defined($gene{'strand'}) ? $gene{'strand'} : undef);
        if (%sequence && defined $sequence{'gene'} && $sequence{'sequence'})
        {
            my $structure = '1..' . $sequence{'size'};
            $structure = ${$sequence{'rna'}}[0] if (defined @{$sequence{'rna'}});
            my $sth =
              $self->{'_dbh'}->prepare(
                'INSERT INTO sequence (prefix, id, locus_prefix, locus_id, name, isolate, location, organelle, translation, molecule, circular, chromosome, structure, map, accession, hgnc, geneid, organism, go, sequence_type, stop, start, strand, sequence, evalue, sources, comments, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM sequence WHERE prefix=?;'
              );
            $sth->execute(
                          $prefix,        $self->{'_prefix'},
                          $self->{'_id'}, $sequence{'gene'},
                          ((defined $sequence{'isolate'}) ? $sequence{'isolate'} : undef), $sequence{'location'},
                          ((defined $sequence{'organelle'}) ? $sequence{'organelle'} : undef), ((defined $sequence{'translation'}) ? $sequence{'translation'} : 1),
                          ((defined $sequence{'molecule'})   ? $sequence{'molecule'}   : 'NA'),  $sequence{'circular'},
                          ((defined $sequence{'chromosome'}) ? $sequence{'chromosome'} : undef), $structure,
                          ((defined $gene{'map'})            ? $gene{'map'}            : undef), $sequence{'reference'},
                          ((defined $sequence{'hgnc'})       ? $sequence{'hgnc'}       : undef), $geneid,
                          $sequence{'organism'}, ((defined $sequence{'go'}) ? $sequence{'go'} : undef),
                          2,                                          $sequence{'end'},
                          $sequence{'start'},                         $sequence{'strand'},
                          $self->_compress(uc $sequence{'sequence'}), $evalue,
                          ((defined @{$gene{'pmid'}}) ? ($self->_getMedLine(@{$gene{'pmid'}})) : undef), ((defined $gene{'comment'}) ? $gene{'comment'} : undef),
                          $self->{'_email'}, $prefix
                         );
            $sth = $self->{'_dbh'}->prepare('SELECT prefix, id FROM sequence WHERE author=? AND geneid=? AND accession=? AND name=? AND location=? AND sequence_type=2;');
            $sth->execute($self->{'_email'}, $geneid, $sequence{'reference'}, $sequence{'gene'}, $sequence{'location'});
            if ($sth->rows == 1)
            {
                my @seqid = $sth->fetchrow_array;
                $self->_updateStatus($geneid, 0, 0, 'Add ' . $gene{'accession'} . ' as Sequence S' . $seqid[0] . q{.} . $seqid[1]);
                if (defined @{$sequence{'rna'}})
                {
                    my $i = 0;
                    foreach my $rna (@{$sequence{'rna'}})
                    {
                        $sth =
                          $self->{'_dbh'}->prepare(
                            'INSERT INTO mrna (prefix, id, locus_prefix, locus_id ,sequence_prefix, sequence_id, mrna, location, mrna_type, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ? FROM mrna WHERE prefix=?;'
                          );    #bug?
                        $sth->execute($prefix, $self->{'_prefix'}, $self->{'_id'}, $seqid[0], $seqid[1], $self->_compress(uc ${$sequence{'rna_seq'}}[$i]), $rna, ++$i, $self->{'_email'}, $prefix);
                    }
                }
            }
            $sth->finish();
            return 1;
        }
    }
    return;
}

=head2 _getGenId

 Title   : _getGenId
 Usage   : $self->_getGenId( $prefix, $id );
 Function: Retrieve the genID.
 Returns : return the genID.
 Args    : $prefix (mandatory), prefix reference of the locus;
           $id (mandatory), ID reference of the locus.

=cut

sub _getGenId
{
    my ($self,   @args) = @_;
    my ($prefix, $id)   = @args;
    my $getGenId = $self->{'_dbh'}->prepare('SELECT genid FROM locus WHERE prefix=? AND id=?;');
    $getGenId->execute($prefix, $id);
    if (($getGenId->rows) > 0)
    {
        my $line = $getGenId->fetchrow_hashref();
        $getGenId->finish();
        return $line->{'genid'};
    }
    $getGenId->finish();
    return;
}

=head2 _reverse_compl

 Title   : _reverse_compl
 Usage   : $self->_reverse_compl( $sequence );
 Function: Obtain the reverse complement of a sequence.
 Return  : reverse complement of $sequence.
 Args    : $sequence (mandatory).

=cut

sub _reverse_compl
{
    my ($self, @args) = @_;
    my $sequence = shift @args;
    $sequence = reverse $sequence;
    $sequence =~ tr/ATGC/TACG/;
    return $sequence;
}

=head2 _parse_primer3_output
 Title   : _parse_primer3_output
 Usage   : $self->_parse_primer3_output ($FILE, $i)
 Function: Parse the file result of primer3
 Return  : all the information retrieve from the File
 Args    : $FILE (mandatory), contains the output of primer3;
           $i (mandatory), integer.

=cut

sub _parse_primer3_output
{
    my ($self, @args) = @_;
    my $filename = shift @args;
    my @primers  = ();
    if (open my $PRIMER_OUTPUT, '<', $filename)
    {
        while (my $line = <$PRIMER_OUTPUT>)
        {
            chomp $line;
            my $index = 0;
            if ($line =~ m/_(\d+).*?=/) { $index = $1; }
            $primers[$index]{'LEFT_SEQUENCE'}    = $2 if ($line =~ m/PRIMER_LEFT(_\d+)?_SEQUENCE=(.+)/o);
            $primers[$index]{'RIGHT_SEQUENCE'}   = $2 if ($line =~ m/PRIMER_RIGHT(_\d+)?_SEQUENCE=(.+)/o);
            $primers[$index]{'PAIR_PENALTY'}     = $2 if ($line =~ m/PRIMER_PAIR_PENALTY(_\d+)?=(.+)/o);
            $primers[$index]{'LEFT'}             = $2 if ($line =~ m/PRIMER_LEFT(_\d+)?=(.+)/o);
            $primers[$index]{'LEFT_TM'}          = $2 if ($line =~ m/PRIMER_LEFT(_\d+)?_TM=(.+)/o);
            $primers[$index]{'LEFT_GC_PERCENT'}  = $2 if ($line =~ m/PRIMER_LEFT(_\d+)?_GC_PERCENT=(.+)/o);
            $primers[$index]{'LEFT_PENALTY'}     = $2 if ($line =~ m/PRIMER_LEFT(_\d+)?_PENALTY=(.+)/o);
            $primers[$index]{'RIGHT'}            = $2 if ($line =~ m/PRIMER_RIGHT(_\d+)?=(.+)/o);
            $primers[$index]{'RIGHT_TM'}         = $2 if ($line =~ m/PRIMER_RIGHT(_\d+)?_TM=(.+)/o);
            $primers[$index]{'RIGHT_GC_PERCENT'} = $2 if ($line =~ m/PRIMER_RIGHT(_\d+)?_GC_PERCENT=(.+)/o);
            $primers[$index]{'RIGHT_PENALTY'}    = $2 if ($line =~ m/PRIMER_RIGHT(_\d+)?_PENALTY=(.+)/o);
            $primers[$index]{'PRODUCT_SIZE'}     = $2 if ($line =~ m/PRIMER_PRODUCT_SIZE(_\d+)?=(.+)/o);
        }
        close $PRIMER_OUTPUT;
    }
    return @primers;
}

=head2 new

 Title   : new
 Usage   : my $nb = UniTools->new( $aligner, $dbh, $remote, $verbose, $webserver,
                                        $email );
 Function: Initialise UniPrime object.
 Returns : An UniPrime object.
 Args    : $aligner (mandatory), aligner to use;
           $dbh (mandatory), SQL object reference;
           $remote (optional),  boolean active remote blast mode;
           $verbose (optional), boolean active verbose mode;
           $webserver (optional), boolean active verbose mode;
           $email (mandatory if webserver if true), reference email of the user.

=cut

sub new
{
    my ($self, @args) = @_;
    my ($aligner, $dbh, $remote, $verbose, $webserver, $email) = @args;
    $self = {};
    if (!defined $aligner || $aligner eq 'GramAlign')
    {
        $self->{'_aligner'} = 'GramAlign';
        $self->{'_aligner_bin'} = ((defined $ENV{'GRAMALIGNDIR'}) ? $ENV{'GRAMALIGNDIR'} : UniTools->_findexec('GramAlign'));
    }
    elsif ($aligner eq 'T-coffee')
    {
        $self->{'_aligner'} = 'T-coffee';
        $self->{'_aligner_bin'} = ((defined $ENV{'DIR_4_TCOFFEE'}) ? $ENV{'DIR_4_TCOFFEE'} . '/bin/t_coffee' : UniTools->_findexec('t_coffee'));
    }
    if (exists $self->{'_aligner_bin'} && -x $self->{'_aligner_bin'})
    {
        if (defined $dbh)
        {
            $self->{'_dbh'} = $dbh if (defined $dbh);
            $self->{'_verbose'} = ((defined $verbose && int($verbose) == 1) ? 1 : 0);
            if ((defined $webserver && int($webserver) == 1))
            {
                if (defined $email)
                {
                    $self->{'_webserver'} = 1;
                    $self->{'_email'}     = $email;
                }
                else
                {
                    print {*STDERR} " # Initialisation error:\n # When using a webservice configuration an email must be provided!\n";
                    return;
                }
            }
            else { $self->{'_webserver'} = 0; $self->{'_email'} = 'local'; }

            #$self->{'_blastcl3'}= ((defined $ENV{'BLASTCLDIR'}) ? $ENV{'BLASTCLDIR'} : UniTools->_findexec('blastcl3'));
            #if (!-x $self->{'_blastcl3'})
            #{
            #    print {*STDERR} " # Initialisation error:\n # blastcl3 (blast2 package) must be installed!\n";
            #    return;
            #}
            $self->{'_blastn'} = ((defined $ENV{'BLASTCLDIR'}) ? $ENV{'BLASTCLDIR'} : UniTools->_findexec('blastn'));
            if (!-x $self->{'_blastn'})
            {
                print {*STDERR} " # Initialisation error:\n # blastn (ncbi-blast+ package) must be installed!\n";
                return;
            }
            $self->{'_remote'} = ((defined $remote && int($remote) == 1) ? '-remote' : '-num_threads 12');
            $self->{'_primer3'} = ((defined $ENV{'PRIMER3DIR'}) ? $ENV{'PRIMER3DIR'} : UniTools->_findexec('primer3_core'));
            if (!-x $self->{'_primer3'})
            {
                print {*STDERR} " # Initialisation error:\n # primer3 must be installed!\n";
                return;
            }
            bless($self);
            return $self;
        }
        else
        {
            print {*STDERR} " # Initialisation error:\n # A valid SQL object must the provided!\n";
            return;
        }
    }
    else
    {
        print {*STDERR} " # Initialisation error:\n # A valid Aligner must be installed (unable to find ", ((!defined $aligner || $aligner eq 'GramAlign') ? 'GramAlign' : 'T-coffee'), ")!\n";
        return;
    }
}

=head2 addLocus

 Title   : addLocus (temporary)
 Usage   : uniprime_obj->addLocus( $geneid, $status, $pmid_ref, $locus_type );
 Function: Add new locus and prototype into the database.
 Returns : none.
 Args    : $geneid (mandatory), geneid of the hit or file name;
           $status (optional), locus status (0: Unknown; 1: preliminary ...);
           $pmid_ref (optional), pmid associated;
           $locus_type (optional), locus type (0: Unknown; 1: gene ...).

=cut

sub addLocus
{
    my ($self, @args) = @_;
    my ($geneid, $status, $pmid_ref, $locus_type) = @args;
    $status     = 1 unless (defined $status);
    $locus_type = 0 unless (defined $locus_type);
    my (%sequence, %gene);
    my ($sth, $file, $myname);
    my $myid = -1;
    my $prefix = floor((((localtime(time))[5] - 107) * 12 + (localtime(time))[4]) / 1.5);

    #add sequence file
    if (-r $geneid && (my %seq = $self->_parcefasta($geneid)))
    {
        $file   = $geneid;
        $geneid = 0;
        $geneid = -$1 if ($file =~ m/\/(\d+)\..+\.fasta$/);

        #if (!$self->{'_webserver'})
        #{
        #    my $query = $self->{'_dbh'}->prepare('INSERT INTO execstatus (genid, email, step, status, description, file) VALUES (?,?,?,?,?,?);');
        #    $query->execute($geneid, $self->{'_email'}, 1, 0, '<p>Adding sequence ' . $seq{'name'} . ' from ' . $file . '"</p>', $file);
        #    print {*STDERR} '> Status update: GeneID ', $geneid, ' "Adding sequence ', $seq{'name'}, ' from ', $file, "\"\n" if ($self->{'_verbose'});
        #} else {
        $self->_updateStatus($geneid, 0, 0, 'Adding sequence ' . $seq{'name'} . ' from ' . $file);

        #}
        $sth    = $self->{'_dbh'}->prepare('INSERT INTO locus (prefix, id, genid, name, locus_type, evidence, sources, status, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ? FROM locus WHERE prefix=?;');
        $myname = $seq{'name'};
        if (!($sth->execute($prefix, $geneid, $seq{'name'}, 10, 'SEQ', ((defined $pmid_ref) ? $self->_getMedLine(($pmid_ref)) : undef), $status, $self->{'_email'}, $prefix)))
        {
            $self->_critial_error('Database manipulation error', 6);
            exit(5);
        }
        $sth = $self->{'_dbh'}->prepare('SELECT prefix, id FROM locus WHERE author=? AND genid=?;');
        if (!($sth->execute($self->{'_email'}, $geneid)))
        {
            $self->_critial_error('Database manipulation error', 7);
            exit(7);
        }
        if (my $row = $sth->fetchrow_hashref())
        {
            $self->{'_prefix'} = $prefix;
            $self->{'_id'}     = $row->{'id'};

            #my $query = $self->{'_dbh'}->prepare('UPDATE execution SET locus_prefix=?, locus_id=?, name=? WHERE email=? AND genid=?;');
            #$query->execute($row->{'prefix'}, $self->{'_id'}, $myname, $self->{'_email'}, $geneid);
            if ($self->{'_webserver'})
            {
                my $query = $self->{'_dbh'}->prepare('UPDATE execution SET locus_prefix=?, locus_id=?, name=? WHERE email=? AND genid=?;');
                $query->execute($row->{'prefix'}, $self->{'_id'}, $myname, $self->{'_email'}, $geneid);
                $query = $self->{'_dbh'}->prepare('UPDATE execstatus SET locus_prefix=?, locus_id=?, description=? WHERE email=? AND genid=?;');
                $query->execute($row->{'prefix'}, $self->{'_id'}, '<p>Adding locus</p>', $self->{'_email'}, $geneid);
                $query->finish();
            }

            #$query->finish();
        }
        $sequence{'size'}      = length $seq{'seq'};
        $sequence{'gene'}      = $seq{'name'};
        $sequence{'molecule'}  = 'NA';
        $sequence{'circular'}  = 'f';
        $sequence{'reference'} = q{};
        $sequence{'organism'}  = 'unknown';
        $sequence{'end'}       = 1;
        $sequence{'start'}     = $sequence{'size'};
        $sequence{'strand'}    = 1;
        $sequence{'sequence'}  = $seq{'seq'};
    }
    elsif ($geneid =~ /(\d+)/)
    {
        #if (!$self->{'_webserver'})
        #{
        #    my $query = $self->{'_dbh'}->prepare('INSERT INTO execstatus (genid, email, step, status, description) VALUES (?,?,?,?,?);');
        #    $query->execute($geneid, $self->{'_email'}, 1, 0, '<p>Adding GeneId: ' . $geneid . '</p>');
        #    print {*STDERR} '> Status update: GeneID ', $geneid, ' "Adding GeneId: ', $geneid, "\"\n" if ($self->{'_verbose'});
        #}
        #else {
        $self->_updateStatus($geneid, 0, 0, 'Adding GeneId: ' . $geneid);

        #}
        %gene = $self->_getGene($geneid);
        if (%gene && (exists $gene{'accession'}) && (exists $gene{'start'}) && (exists $gene{'end'}) && (exists $gene{'locus'}))
        {
            $self->_updateStatus($geneid, 0, 0, 'Retrieving the sequence.');
            %sequence = $self->_getSequence($gene{'accession'}, $gene{'start'}, $gene{'end'});
            if (%sequence)
            {
                $sth = $self->{'_dbh'}->prepare('SELECT prefix, id FROM locus WHERE genid=? AND author=?;');
                if (!($sth->execute($geneid, $self->{'_email'})))
                {
                    $self->_critial_error('Database manipulation error', 8);
                    exit(8);
                }
                if (($sth->rows) == 0)
                {
                    $sth =
                      $self->{'_dbh'}->prepare(
                        'INSERT INTO locus (prefix, id, genid, name, locus_type, phenotype, pathway, functions, evidence, sources, status, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM locus WHERE prefix=?;'
                      );    #bug?
                    $myname = $gene{'locus'};
                    if (
                        !(
                           $sth->execute(
                                        $prefix, $geneid, $gene{'locus'}, $locus_type,
                                        ((defined $gene{'phenotype'}) ? $gene{'phenotype'} : undef),
                                        ((defined $gene{'pathway'})   ? $gene{'pathway'}   : undef),
                                        ((defined $gene{'desc'})      ? $gene{'desc'}      : undef),
                                        'DIR', ((defined $pmid_ref) ? $self->_getMedLine(($pmid_ref)) : undef),
                                        $status, $self->{'_email'}, $prefix
                                        )
                         )
                       )
                    {
                        $self->_critial_error('Database manipulation error', 9);
                        exit(9);
                    }
                    my $qlocus = $self->{'_dbh'}->prepare('SELECT prefix, id FROM locus WHERE author=? AND genid=?;');
                    if (!($qlocus->execute($self->{'_email'}, $geneid)))
                    {
                        $self->_critial_error('Database manipulation error', 10);
                        exit(10);
                    }
                    if (my $row = $qlocus->fetchrow_hashref())
                    {
                        $self->{'_prefix'} = $prefix;
                        $self->{'_id'}     = $row->{'id'};

                        #my $query = $self->{'_dbh'}->prepare('UPDATE execution SET locus_prefix=?, locus_id=?, name=? WHERE email=? AND genid=?;');
                        #$query->execute($row->{'prefix'}, $self->{'_id'}, $myname, $self->{'_email'}, $geneid);
                        if ($self->{'_webserver'})
                        {
                            my $query = $self->{'_dbh'}->prepare('UPDATE execution SET locus_prefix=?, locus_id=?, name=? WHERE email=? AND genid=?;');
                            $query->execute($row->{'prefix'}, $self->{'_id'}, $myname, $self->{'_email'}, $geneid);
                            $query = $self->{'_dbh'}->prepare('UPDATE execstatus SET locus_prefix=?, locus_id=?, description=? WHERE email=? AND genid=?;');
                            $query->execute($row->{'prefix'}, $self->{'_id'}, '<p>Adding locus</p>', $self->{'_email'}, $geneid);
                            $query->finish();
                        }

                        #$query->finish();
                    }
                }
                else
                {
                    my @locusid = $sth->fetchrow_array;
                    $self->_updateStatus($geneid, -1, 0, '# ' . $gene{'locus'} . ' (' . $geneid . ') is already in the database, reference L' . $locusid[0] . q{.} . $locusid[1] . '!');
                    return 1;
                }
            }
        }
        else
        {
            if ($self->{'_webserver'}) { $self->_updateStatus($geneid, 0, 0, 'Failed to retrieve information from NCBI Website. Please try again later'); }
        }
    }
    else { $self->_updateStatus($geneid, -1, 0, 'GeneID ' . $geneid . ' unrecognised!'); }
    if (%sequence)
    {
        if (exists $self->{'_prefix'} && exists $self->{'_id'})
        {
            my $structure = '1..' . $sequence{'size'};
            $structure = ${$sequence{'rna'}}[0] if (defined @{$sequence{'rna'}});
            $sth =
              $self->{'_dbh'}->prepare(
                'INSERT INTO sequence (prefix, id, locus_prefix, locus_id, name, isolate, location, organelle, translation, molecule, circular, chromosome, structure, map, accession, hgnc, geneid, organism, go, sequence_type, stop, start, strand, sequence, sources, comments, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM sequence WHERE prefix=?;'
              );
            $self->_updateStatus($geneid, 0, 0, 'Inserting sequence.');
            if (
                !(
                   $sth->execute(
                                $self->{'_prefix'}, $self->{'_prefix'},
                                $self->{'_id'},     $sequence{'gene'},
                                ((defined $sequence{'isolate'}) ? $sequence{'isolate'} : undef), $sequence{'location'},
                                ((defined $sequence{'organelle'}) ? $sequence{'organelle'} : undef), ((defined $sequence{'translation'}) ? $sequence{'translation'} : 1),
                                $sequence{'molecule'}, $sequence{'circular'},
                                ((defined $sequence{'chromosome'}) ? $sequence{'chromosome'} : undef), $structure,
                                ((defined $gene{'map'})            ? $gene{'map'}            : undef), $sequence{'reference'},
                                ((defined $sequence{'hgnc'})       ? $sequence{'hgnc'}       : undef), $geneid,
                                $sequence{'organism'}, ((defined $sequence{'go'}) ? $sequence{'go'} : undef),
                                1,                  $sequence{'end'},
                                $sequence{'start'}, $sequence{'strand'},
                                $self->_compress(uc $sequence{'sequence'}), ((defined @{$gene{'pmid'}}) ? ($self->_getMedLine(@{$gene{'pmid'}})) : undef),
                                ((defined $gene{'comment'}) ? $gene{'comment'} : undef), $self->{'_email'},
                                $self->{'_prefix'}
                                )
                 )
               )
            {
                $self->_critial_error('Database manipulation error', 11);
                exit(11);
            }
            $sth = $self->{'_dbh'}->prepare('SELECT prefix, id FROM sequence WHERE author=? AND geneid=? AND accession=? AND name=? AND location=? AND sequence_type=1;');
            if (!($sth->execute($self->{'_email'}, $geneid, $sequence{'reference'}, $sequence{'gene'}, $sequence{'location'})))
            {
                $self->_critial_error('Database manipulation error', 12);
                exit(12);
            }
            if ((($sth->rows) == 1) && (defined @{$sequence{'rna'}}))
            {
                my @seqid = $sth->fetchrow_array;
                my $i     = 0;
                foreach my $rna (@{$sequence{'rna'}})
                {
                    $sth =
                      $self->{'_dbh'}->prepare(
                        'INSERT INTO mrna (prefix, id, locus_prefix, locus_id ,sequence_prefix, sequence_id, mrna, location, mrna_type, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ? FROM mrna WHERE prefix=?;'
                      );    #bug?
                    if (!($sth->execute($self->{'_prefix'}, $self->{'_prefix'}, $self->{'_id'}, $seqid[0], $seqid[1], $self->_compress(uc ${$sequence{'rna_seq'}}[$i]), $rna, ++$i, $self->{'_email'}, $self->{'_prefix'})))
                    {
                        $self->_critial_error('Database manipulation error', 13);
                        exit(13);
                    }
                }
            }
            $self->_updateStatus($geneid, 1, 1, $myname . ' (' . $geneid . ') added to the database as locus L' . $self->{'_prefix'} . q{.} . $self->{'_id'});
            return 1;
        }
    }
    $sth->finish();
    return;
}

=head2 populate_orthologues

 Title   : populate_orthologues
 Usage   : uniprime_obj->populate_orthologues( $prefix, $id,  $evalue, $bank, $dna,
                                              $query );
 Function: Retrieve orthologous sequence for referential mRNA.
 Returns : none.
 Args    : $prefix (mandatory), prefix reference of the locus;
           $id (mandatory), id reference of the locus;
           $evalue (mandatory), threshold for Blastn survey;
           $bank (optional), Genbank used for Blastn (default 'refseq_rna');
           $dna (optional), boolean allow DNA sequence;
           $query (optional), Entrez query limit (e.g. "Mammalia"[ORGN]).

=cut

sub populate_orthologues
{
    my ($self, @args) = @_;
    my ($prefix, $id, $evalue, $bank, $dna, $query) = @args;
    $dna = 0 unless (defined $dna);    ## 0|1 rna only (true|false)
    $bank = ($dna ? 'refseq_genomic' : 'refseq_rna') unless (defined $bank);    ## nr|chromosome|refseq_rna|refseq_genomic|wgs
    my %access;
    my $geneid;
    if (!defined($geneid = $self->_getGenId($prefix, $id))) { exit(); }
    $dna = 1 if ($geneid <= 0);                                                 ## DNA only
    $self->{'_prefix'} = $prefix;
    $self->{'_id'}     = $id;
    my $sth =
      $self->{'_dbh'}->prepare($dna
        ? ' SELECT a . name, b . sequence, b . geneid FROM locus AS a, sequence AS b WHERE a . prefix = ? AND a.id=? AND a . author = ? AND a.status>=1 AND b.locus_prefix=a.prefix AND b.locus_id=a.id AND b.sequence_type=1;'
        : 'SELECT a.name, c.mrna, b.geneid FROM locus AS a, sequence AS b, mrna AS c WHERE a.prefix=? AND a.id=? AND a.author=? AND a.status>=1 AND b.locus_prefix=a.prefix AND b.locus_id=a.id AND b.sequence_type=1 AND c.sequence_prefix=b.prefix AND c.sequence_id=b.id AND c.mrna_type=1;'
      );

    if (!($sth->execute($self->{'_prefix'}, $self->{'_id'}, $self->{'_email'})))
    {
        $self->_critial_error('Database manipulation error', 14);
        exit(14);
    }
    if (($sth->rows) > 0)
    {
        while (my @row = $sth->fetchrow_array)
        {
            $self->_updateStatus($geneid, 0, 0, 'Blast of ' . $row[0]);
            $row[1] = $self->_uncompress($row[1]);
            %access = $self->_getBlasted($bank, $evalue, $row[1], $dna, $query);
            if (%access)
            {
                foreach my $key (keys %access)
                {
                    $self->_updateStatus($geneid, 0, 0, 'Add blasted ' . $key);
                    $self->_addBlasted($key, $access{$key}) unless ($row[2] eq $key);
                }
                my $sth2 = $self->{'_dbh'}->prepare('UPDATE locus SET status = 2 WHERE prefix = ? AND id=? AND author = ? AND status=1;');
                if (!($sth2->execute($self->{'_prefix'}, $self->{'_id'}, $self->{'_email'})))
                {
                    $self->_critial_error('Database manipulation error', 15);
                    exit(15);
                }
                $sth2->finish;
            }
        }
        $sth->finish;
    }
    $self->_updateStatus($geneid, 1, 1, 'Search for Orthologs - done');
    return;
}

=head2 populate_alignment

 Title   : populate_alignment
 Usage   : uniprime_obj->populate_alignment( $prefix, $id, $consen, $dna, $gapopen
                      $gapext, $Mlalign, $Mclustalw, $Mfast, $Mslow, $matrix, @selected );
 Function: Create multi-alignment for each locus.
 Returns : none.
 Args    : $prefix (mandatory), prefix reference of the locus;
           $id (mandatory), id reference of the locus;
           $consen (optional), threshold of the consensus generated, between 1 and 100
           (default 60);
           $dna (optional), boolean allow DNA sequence;
           $gapopen (optional), Specify the gap-open cost;
           $gapext (optional), Specify the gap-extension cost;
           $Mlalign (optional), 10 best local alignments Model;
           $Mclustalw (optional), ClustalW pairwise alignment Model;
           $Mfast (optional), fast heuristic global alignment Model;
           $Mslow (optional), accurate global alignment Model;
           $matrix (optional), Force to generate a complete distance/identity matrix
           prior to the aligment;
           @selected (optional), list of the sequence to use.

=cut

sub populate_alignment
{
    my ($self, @args) = @_;
    my ($prefix, $id, $consen, $dna, $gapopen, $gapext, $Mlalign, $Mclustalw, $Mfast, $Mslow, $matrix, @selected) = @args;
    $dna    = 0  unless (defined $dna);      # 0|1 rna only (true|false)
    $consen = 60 unless (defined $consen);
    $matrix = 0  unless (defined $matrix);
    my ($structure, $specie, $geneid, $my_specie);
    my (@ids, @gramalign, @tcoffee);
    if (!defined($geneid = $self->_getGenId($prefix, $id))) { exit(); }
    $dna = 1 if ($geneid <= 0);              ## DNA only
    $self->{'_prefix'} = $prefix;
    $self->{'_id'}     = $id;
    $self->_updateStatus($geneid, 0, 0, 'Establishing alignment');
    my $cwd = getcwd();
    my $sth =
      $self->{'_dbh'}->prepare($dna
        ? 'SELECT b.name, b.organism, b.sequence, b.structure, b.sequence_type, b.prefix, b.id FROM sequence AS b, locus AS c WHERE c.prefix=? AND c.id=? AND c.status>=2 AND b.locus_prefix=c.prefix AND b.locus_id=c.id ORDER BY c.prefix, c.id;'
        : 'SELECT b.name, b.organism, a.mrna, a.location, b.sequence_type, b.prefix, b.id FROM mrna AS a, sequence AS b, locus AS c WHERE c.prefix=? AND c.id=? AND c.status>=2 AND a.locus_prefix=c.prefix AND a.locus_id=c.id AND a.mrna_type=1 AND b.prefix=a.sequence_prefix AND b.id=a.sequence_id ORDER BY c.prefix, c.id;'
      );

    if (!($sth->execute($self->{'_prefix'}, $self->{'_id'})))
    {
        $self->_critial_error('Database manipulation error', 16);
        exit(16);
    }
    if (($sth->rows) > 1)
    {
        my ($aln, $factory);
        my $PATH_BZIP = ((defined $ENV{'BZIPDIR'}) ? $ENV{'BZIPDIR'} : $self->_findexec('bzip2'));
        my $locus = sprintf("%lo.%lo", $self->{'_prefix'}, $self->{'_id'});
        open my $SEQ, '>', PATH_TMP . '/align.' . $locus . '.fasta';
        my $fabcount = 0;
        while (my @row = $sth->fetchrow_array)
        {
            my $select = sprintf("%lo\.%lo", $row[5], $row[6]);
            if ((@selected == 0) || (grep { $_ =~ /^S$select$/i } @selected))
            {
                if ($row[4] == 1 || !defined($structure))
                {
                    $structure = $row[3];
                    if ($row[1] =~ m/^(\w+)/o)
                    {
                        $specie    = $1;
                        $my_specie = $row[1];
                    }
                }
                push(@ids, sprintf("%lo.%lo", $row[5], $row[6]));
                $self->_updateStatus($geneid, 0, 0, $row[1] . ' (' . $row[0] . ')');
                print {$SEQ} '>', $row[1], "\n", $self->_uncompress($row[2]), "\n";
            }
        }
        close $SEQ;
        $sth->finish;
        if (scalar @ids > 1)
        {
            if ($self->{'_aligner'} eq 'GramAlign')
            {
                $self->_updateStatus($geneid, 0, 0, 'Begin alignment (GramAlign)');
                @gramalign =
                  (   $self->{'_aligner_bin'} . ' -i '
                    . PATH_TMP
                    . '/align.'
                    . $locus
                    . '.fasta -o '
                    . PATH_TMP
                    . '/align.'
                    . $locus
                    . '.aln -f 2 -q'
                    . (defined $gapopen ? ' -g ' . $gapopen : q{})
                    . (defined $gapext  ? ' -e ' . $gapext  : q{})
                    . ((defined $matrix && $matrix) ? ' -C' : q{}));
                chdir(PATH_TMP);
                if (system(@gramalign) != 0)
                {
                    $self->_critial_error('Failed to run GramAlign', 17);
                    exit(17);
                }
                chdir($cwd);
                $self->_updateStatus($geneid, 0, 0, 'Alignment done');
            }
            elsif ($self->{'_aligner'} eq 'T-coffee')
            {
                $self->_updateStatus($geneid, 0, 0, 'Begin alignment. (T-Coffee)');
                my @t_coffee_options;
                push @t_coffee_options, 'lalign_id_pair' if (defined $Mlalign && (defined $Mfast || !$Mfast) && $Mlalign);
                push @t_coffee_options, 'clustalw_pair' if (defined $Mclustalw && $Mclustalw);
                push @t_coffee_options, 'fast_pair'     if (defined $Mfast     && $Mfast);
                push @t_coffee_options, 'slow_pair'     if (defined $Mslow     && (defined $Mfast || !$Mfast) && $Mslow);
                @tcoffee =
                  (   $self->{'_aligner_bin'}
                    . ' -infile='
                    . PATH_TMP
                    . '/align.'
                    . $locus
                    . '.fasta -outfile='
                    . PATH_TMP
                    . '/align.'
                    . $locus
                    . '.aln -output='
                    . 'fasta_aln'
                    . (@t_coffee_options ? ' -method=' . join q{,}, @t_coffee_options : q{})
                    . (defined $gapopen ? ' -gapopen=' . $gapopen : q{})
                    . (defined $gapext  ? ' -gapext=' . $gapext   : q{})
                    . ' -ktuple=1 -quiet -no_warning');
                chdir(PATH_TMP);

                if (system(@tcoffee) != 0)
                {
                    $self->_critial_error('Failed to run T-Coffee', 18);
                    exit(18);
                }
                chdir($cwd);
                unlink('./align.' . $locus . '.dnd');
                $self->_updateStatus($geneid, 0, 0, 'Alignment done');
            }
        }
        else
        {
            $self->_updateStatus($geneid, -1, 0, 'Your dataset contains only 1 sequence. For multiple alignments you need at least 2 sequences');
            return;
        }

        #Retrieve the information from the .aln file and make the consensus
        if (-f PATH_TMP . '/align.' . $locus . '.aln')
        {
            my @loc;
            my $sth =
              $self->{'_dbh'}->prepare(
                 'INSERT INTO alignment (prefix, id, locus_prefix, locus_id, sequences, alignment, structure, consensus, program, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ? FROM alignment WHERE prefix=?;'
              );
            my $filealn = PATH_TMP . '/align.' . $locus . '.aln';
            my ($consensus, $specie_int, @matrixx) = $self->_consensus($filealn, $consen, $my_specie);
            my $realsensus = $consensus;
            if ((defined $structure) && !$dna) { $realsensus = $self->_spacing($structure, $consensus, $specie_int, @matrixx); }
            my $myprefix = floor((((localtime(time))[5] - 107) * 12 + (localtime(time))[4]) / 1.5);
            if (
                !(
                   $sth->execute(
                                $myprefix, $self->{'_prefix'}, $self->{'_id'},
                                join(' ', @ids),
                                encode_base64(`$PATH_BZIP -9 -c $filealn`),
                                (@loc ? 'join(' . join(',', @loc) . ')' : (($structure) ? $structure : '1..' . length($realsensus))),
                                $self->_compress($realsensus),
                                $self->{'_aligner'}, $self->{'_email'}, $myprefix
                                )
                 )
               )
            {
                $self->_critial_error('Database manipulation error', 19);
                exit(19);
            }
            $sth = $self->{'_dbh'}->prepare('SELECT prefix, id FROM alignment WHERE prefix=? AND locus_prefix=? AND locus_id=? AND sequences=? AND alignment=? AND structure=? AND consensus=? AND program=? AND author=? ORDER BY id DESC LIMIT 1;');
            if (
                !(
                   $sth->execute(
                                $myprefix, $self->{'_prefix'}, $self->{'_id'},
                                join(q{ }, @ids),
                                encode_base64(`$PATH_BZIP -9 -c $filealn`),
                                (@loc ? 'join(' . join(',', @loc) . ')' : (($structure) ? $structure : '1..' . length($realsensus))),
                                $self->_compress($realsensus),
                                $self->{'_aligner'}, $self->{'_email'}
                                )
                 )
               )
            {
                $self->_critial_error('Database manipulation error', 20);
                exit(20);
            }

            #if ($sth->rows == 1)
            #{
            my @seqid = $sth->fetchrow_array;
            $self->_updateStatus($geneid, 0, 0, 'Alignment step - done');
            $self->_updateStatus($geneid, 1, 1, 'Alignment added to the database as A' . $seqid[0] . q{.} . $seqid[1]);

            #}
            $sth = $self->{'_dbh'}->prepare('UPDATE locus SET status=3 WHERE prefix=? AND id=? AND status=2;');
            if (!($sth->execute($self->{'_prefix'}, $self->{'_id'})))
            {
                $self->_critial_error('Database manipulation error', 21);
                exit(21);
            }
            unlink(PATH_TMP . '/align.' . $locus . '.aln');
        }
        unlink(PATH_TMP . '/align.' . $locus . '.fasta');
    }
    return;
}

=head2 populate_primer

 Title   : populate_primer
 Usage   : uniprime_obj->populate_primer( $prefix_align, $id_align, $w, $min_size,
                         $opt_size, $max_size, $min_tm, $opt_tm, $max_tm, $min_gc,
                         $opt_gc, $max_gc, $self_any, $self_end, $num_ns, $max_poly_x,
                         $gc_clamp );
 Function: Find primers pair for each alignment.
 Returns : none.
 Args    : $id_align (mandatory), id reference of the alignment;
           $prefix_align (mandatory), prefix reference of the alignment;
           $w (optional), optimal size of the target;
           $min_size (optional), Minimum length (in bases) of a primer;
           $opt_size (optional), Optimal length (in bases) of a primer;
           $max_size (optional), Maximum length (in bases) of a primer;
           $min_tm (optional), Minimum melting temperature (Celsius) for a primer;
           $opt_tm (optional), Optimal melting temperature (Celsius) for a primer;
           $max_tm (optional), Maximum melting temperature (Celsius) for a primer;
           $min_gc (optional), Minimum percentage of Gs and Cs in any primer;
           $opt_gc (optional), Optimal percentage of Gs and Cs in any primer;
           $max_gc (optional), Maximum percentage of Gs and Cs in any primer;
           $self_any (optional), Maximum Self Complementarity;
           $self_end (optional), Maximum 3' Self Complementarity;
           $num_ns (optional), Maximum number of N's;
           $max_poly_x (optional), Maximum Poly-X length;
           $gc_clamp (optional), CG Clamp.

=cut

sub populate_primer
{
    my ($self, @args) = @_;
    my ($prefix_align, $id_align, $w, $min_size, $opt_size, $max_size, $min_tm, $opt_tm, $max_tm, $min_gc, $opt_gc, $max_gc, $self_any, $self_end, $num_ns, $max_poly_x, $gc_clamp) = @args;
    $w          = 600  unless (defined $w);
    $min_size   = 18   unless (defined $min_size);
    $opt_size   = 22   unless (defined $opt_size);
    $max_size   = 27   unless (defined $max_size);
    $min_tm     = 55   unless (defined $min_tm);
    $opt_tm     = 60   unless (defined $opt_tm);
    $max_tm     = 65   unless (defined $max_tm);
    $min_gc     = 40   unless (defined $min_gc);
    $opt_gc     = 50   unless (defined $opt_gc);
    $max_gc     = 60   unless (defined $max_gc);
    $self_any   = 6.00 unless (defined $self_any);
    $self_end   = 3.00 unless (defined $self_end);
    $num_ns     = 2    unless (defined $num_ns);
    $max_poly_x = 5    unless (defined $max_poly_x);
    $gc_clamp   = 1    unless (defined $gc_clamp);
    my $geneid;
    my $sth =
      $self->{'_dbh'}->prepare(
        'SELECT b.name, a.prefix, a.id, a.updated, a.sequences, a.consensus, a.structure, a.alignment, b.prefix, b.id, b.genid FROM alignment AS a, locus AS b WHERE a.prefix=? AND a.id=? AND b.status>=3 AND a.locus_prefix=b.prefix AND a.locus_id=b.id;'
      );

    if (!($sth->execute($prefix_align, $id_align)))
    {
        $self->_critial_error('Database manipulation error', 23);
        exit(23);
    }
    if (($sth->rows) == 1)
    {
        my @row = $sth->fetchrow_array;
        $self->{'_prefix'} = $row[8];
        $self->{'_id'}     = $row[9];
        my $geneid = $row[10];
        $self->_updateStatus($geneid, 0, 0, "$row[0] A$row[1].$row[2] (alignment of the $row[3]) in progress");
        $row[5] = $self->_uncompress($row[5]);
        my $size  = int($w / 3);
        my $slide = int(length($row[5]) / $size);

        for (my $j = 1 ; $j < ($slide - 2) ; $j++)
        {
            my $GROUP = $j;
            my ($FILE, $tempfileseq) = tempfile(DIR => PATH_TMP, UNLINK => 1);
            my $value          = int($w * 0.66);
            my $target         = ($j * $size) . ',' . $value;
            my $consens_primer = $row[5];
            $consens_primer =~ tr/-/N/;
            my $primer_input =
                "PRIMER_TASK=generic\n"
              . "PRIMER_PRODUCT_OPT_SIZE=$w\n"
              . "PRIMER_PRODUCT_SIZE_RANGE=550-650 500-900 400-1200 250-10000\n"
              . "PRIMER_MIN_SIZE=$min_size\n"
              . "PRIMER_OPT_SIZE=$opt_size\n"
              . "PRIMER_MAX_SIZE=$max_size\n"
              . "PRIMER_MIN_TM=$min_tm\n"
              . "PRIMER_OPT_TM=$opt_tm\n"
              . "PRIMER_MAX_TM=$max_tm\n"
              . "PRIMER_MAX_DIFF_TM=2\n"
              . "PRIMER_MIN_GC=$min_gc\n"
              . "PRIMER_OPT_GC_PERCENT=$opt_gc\n"
              . "PRIMER_MAX_GC=$max_gc\n"
              . "PRIMER_GC_CLAMP=$gc_clamp\n"
              . "PRIMER_NUM_NS_ACCEPTED=$num_ns\n"
              . "PRIMER_SELF_ANY=$self_any\n"
              . "PRIMER_SELF_END=$self_end\n"
              . "PRIMER_MAX_POLY_X=$max_poly_x\n"
              . "PRIMER_LIBERAL_BASE=1\n"
              . "PRIMER_NUM_RETURN=10\n"
              . "PRIMER_MAX_END_STABILITY=9.0\n"
              . "PRIMER_WT_TM_LT=3.0\n"
              . "PRIMER_WT_TM_GT=3.0\n"
              . "TARGET=$target\n"
              . "SEQUENCE_TEMPLATE=$consens_primer\n" . "=";
            print {$FILE} $primer_input;
            close $FILE;
            my @primer3_bin = ($self->{'_primer3'} . ' -output=' . $tempfileseq . '_output ' . $tempfileseq);

            if (system(@primer3_bin) != 0)
            {
                $self->_critial_error('Failed to run primer3', 24);
                exit(24);
            }
            my $COMMENTS;
            my @parced_primer = $self->_parse_primer3_output($tempfileseq . '_output');
            unlink($tempfileseq . '_output');
            my $sth_pri =
              $self->{'_dbh'}->prepare(
                'INSERT INTO primer (prefix, id, locus_prefix, locus_id, alignment_prefix, alignment_id, penality, left_seq, left_data, right_seq, right_data, location, comments, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM primer WHERE prefix=?;'
              );
            my $sth_pri_test =
              $self->{'_dbh'}->prepare(
                'SELECT prefix, id FROM primer WHERE prefix=? AND locus_prefix=? AND locus_id=? AND alignment_prefix=? AND alignment_id=? AND penality=? AND left_seq=? AND left_data=? AND right_seq=? AND right_data=? AND location=? AND comments=? AND author=?;'
              );
            for (my $o = 0 ; $o <= $#parced_primer ; $o++)
            {
                $COMMENTS = q{};
                my $sth_seq = $self->{'_dbh'}->prepare('SELECT sequence, organism FROM sequence WHERE prefix=? AND id=?;');
                foreach my $s (split m/ / => $row[4])
                {
                    if (exists $parced_primer[$o]{'LEFT_SEQUENCE'} && exists $parced_primer[$o]{'RIGHT_SEQUENCE'} && ($s =~ m/(\d+)\.(\d+)/))
                    {
                        if (!($sth_seq->execute(oct($1), oct($2))))
                        {
                            $self->_critial_error('Database manipulation error', 25);
                            exit(25);
                        }
                        if (($sth_seq->rows) == 1)
                        {
                            my @seq = $sth_seq->fetchrow_array;
                            $self->_updateStatus($geneid, 0, 0, "Check $seq[1] sequence");
                            $seq[0] = uc $self->_uncompress($seq[0]);
                            my ($position, $ref1) = $self->_align($parced_primer[$o]{'LEFT_SEQUENCE'}, $seq[0], '-left');

                            #look at the last 5 nucleotides.
                            if ((defined $ref1) && (substr $ref1, -5, 5) eq (substr $parced_primer[$o]{'LEFT_SEQUENCE'}, -5, 5))
                            {
                                my ($position2, $ref2) = $self->_align($self->_reverse_compl($parced_primer[$o]{'RIGHT_SEQUENCE'}), $seq[0], '-right');
                                my $revcomp = $self->_reverse_compl($parced_primer[$o]{'RIGHT_SEQUENCE'});
                                if (!(defined $ref2) || (substr $ref2, -5, 5) ne (substr $self->_reverse_compl($parced_primer[$o]{'RIGHT_SEQUENCE'}), -5, 5))
                                {
                                    delete $parced_primer[$o]{'LEFT_SEQUENCE'};
                                    last;
                                }
                                else
                                {
                                    if (($position2 - $position) > 0) { $COMMENTS .= ' * ' . $seq[1] . ', product of ' . ($position2 - $position + 1) . ' bp<br />'; }
                                    else
                                    {
                                        delete $parced_primer[$o]{'LEFT_SEQUENCE'};
                                        last;
                                    }
                                }
                            }
                            else
                            {
                                delete $parced_primer[$o]{'LEFT_SEQUENCE'};
                                last;
                            }
                        }
                    }
                }
                if (exists $parced_primer[$o]{'LEFT_SEQUENCE'} && exists $parced_primer[$o]{'RIGHT_SEQUENCE'})
                {
                    my $myprefix = floor((((localtime(time))[5] - 107) * 12 + (localtime(time))[4]) / 1.5);
                    $self->_updateStatus($geneid, 0, 0, 'Adding primers...');
                    my $exon = 0;
                    my @loc;
                    my ($start) = split(m/\,/, $parced_primer[$o]{'LEFT'});
                    my ($end)   = split(m/\,/, $parced_primer[$o]{'RIGHT'});
                    while ($row[6] =~ m/(\d+)\.\.(\d+)/go)
                    {
                        $exon++;
                        if (!(defined $loc[1]) && ($1 > $start)) { $loc[1] = (($exon == 1) ? '5&#39;UTR' : 'intron ' . ($exon - 1)); }
                        elsif (($1 <= $start) && ($2 >= $start)) { $loc[1] = 'exon ' . $exon; }
                        if (!(defined $loc[2]) && ($1 > $end)) { $loc[2] = (($exon == 1) ? '5&#39;UTR' : 'intron ' . ($exon - 1)); }
                        elsif (($1 <= $end) && ($2 >= $end)) { $loc[2] = 'exon ' . $exon; }
                    }
                    $loc[1] = '3&#39;UTR' if (!(defined $loc[1]));
                    $loc[2] = '3&#39;UTR' if (!(defined $loc[2]));
                    $GROUP = (($loc[1] ne $loc[2]) ? $loc[1] . ' - ' . $loc[2] : $loc[1]) . ' (window ' . $GROUP . ')';
                    $parced_primer[$o]{'LEFT_SEQUENCE'}  =~ tr/\,/\|/;
                    $parced_primer[$o]{'RIGHT_SEQUENCE'} =~ tr/\,/\|/;
                    if (
                        !(
                           $sth_pri->execute(
                                             $myprefix,                            $self->{'_prefix'},
                                             $self->{'_id'},                       $row[1],
                                             $row[2],                              $parced_primer[$o]{'PAIR_PENALTY'},
                                             $parced_primer[$o]{'LEFT_SEQUENCE'},  $parced_primer[$o]{'LEFT'} . '|' . $parced_primer[$o]{'LEFT_TM'} . '|' . $parced_primer[$o]{'LEFT_GC_PERCENT'} . '|' . $parced_primer[$o]{'LEFT_PENALTY'},
                                             $parced_primer[$o]{'RIGHT_SEQUENCE'}, $parced_primer[$o]{'RIGHT'} . '|' . $parced_primer[$o]{'RIGHT_TM'} . '|' . $parced_primer[$o]{'RIGHT_GC_PERCENT'} . '|' . $parced_primer[$o]{'RIGHT_PENALTY'},
                                             $GROUP,                               'Predicted product: ' . $parced_primer[$o]{'PRODUCT_SIZE'} . ' bp<br />' . $COMMENTS,
                                             $self->{'_email'},                    $myprefix
                                            )
                         )
                       )
                    {
                        $self->_critial_error('Database manipulation error', 26);
                        exit(26);
                    }
                    if (
                        !(
                           $sth_pri_test->execute(
                                                  $myprefix,                            $self->{'_prefix'},
                                                  $self->{'_id'},                       $row[1],
                                                  $row[2],                              $parced_primer[$o]{'PAIR_PENALTY'},
                                                  $parced_primer[$o]{'LEFT_SEQUENCE'},  $parced_primer[$o]{'LEFT'} . '|' . $parced_primer[$o]{'LEFT_TM'} . '|' . $parced_primer[$o]{'LEFT_GC_PERCENT'} . '|' . $parced_primer[$o]{'LEFT_PENALTY'},
                                                  $parced_primer[$o]{'RIGHT_SEQUENCE'}, $parced_primer[$o]{'RIGHT'} . '|' . $parced_primer[$o]{'RIGHT_TM'} . '|' . $parced_primer[$o]{'RIGHT_GC_PERCENT'} . '|' . $parced_primer[$o]{'RIGHT_PENALTY'},
                                                  $GROUP,                               'Predicted product: ' . $parced_primer[$o]{'PRODUCT_SIZE'} . ' bp<br />' . $COMMENTS,
                                                  $self->{'_email'},                    $myprefix
                                                 )
                         )
                       )
                    {
                        $self->_critial_error('Database manipulation error', 22);
                        exit(22);
                    }
                    if (($sth->rows) == 1)
                    {
                        my @row2 = $sth->fetchrow_array;
                        $self->_updateStatus($geneid, 0, 0, 'Primer: X' . $row2[0] . '.' . $row2[1] . ' with penalty=' . $parced_primer[$o]{'PAIR_PENALTY'});
                        $sth_seq = $self->{'_dbh'}->prepare('UPDATE locus SET status=4 WHERE prefix=? AND id=? AND status=3;');
                        if (!($sth_seq->execute($self->{'_prefix'}, $self->{'_id'})))
                        {
                            $self->_critial_error('Database manipulation error', 27);
                            exit(27);
                        }
                    }
                }
                else
                {
                    $sth_seq = $self->{'_dbh'}->prepare('UPDATE locus SET status=4 WHERE prefix=? AND id=? AND status=3;');
                    if (!($sth_seq->execute($self->{'_prefix'}, $self->{'_id'})))
                    {
                        $self->_critial_error('Database manipulation error', 28);
                        exit(28);
                    }
                }
            }
        }
        $self->_updateStatus($geneid, 1, 1, 'Primers designed - done');
        return 1;
    }
    else
    {
        $self->_updateStatus($geneid, -1, 0, 'The alignment in unknown');
        return 1;
    }
}

=head2 virtual_amplicon

 Title   : virtual_amplicon
 Usage   : uniprime_obj->virtual_amplicon( $prefix, $id, $query, $bank, $maxdist );
 Function: Retrieve amplicons from primer pair.
 Returns : array of amplicons.
 Args    : $prefix (mandatory), prefix reference of the primer;
           $id (mandatory), id reference of the primer;
           $query (optional), Entrez query limit (e.g. "Mammalia"[ORGN]);
           $bank (optional), databank used for Blastn (default 'wgs');
           $maxdist (optional), maximum length of an amplicon (default 5000).

=cut

sub virtual_amplicon
{
    my ($self, @args) = @_;
    my ($prefix, $id, $query, $bank, $maxdist) = @args;
    $bank    = 'wgs' unless (defined $bank);
    $maxdist = 5000  unless (defined $maxdist);
    my $prefixN = floor((((localtime(time))[5] - 107) * 12 + (localtime(time))[4]) / 1.5);
    my %access;
    my ($geneid, $locusid, $locusprefix);
    my $sth = $self->{'_dbh'}->prepare('SELECT a.locus_prefix, a.locus_id FROM primer AS a WHERE a.prefix=? AND a.id=?;');
    $sth->execute($prefix, $id);

    if (my $prefixid = $sth->fetchrow_hashref())
    {
        if (!defined($geneid = $self->_getGenId($prefixid->{'locus_prefix'}, $prefixid->{'locus_id'}))) { exit(); }
        $self->{'_id'}     = $prefixid->{'locus_id'};
        $self->{'_prefix'} = $prefixid->{'locus_prefix'};
    }
    else { exit(); }
    $self->_updateStatus($geneid, 0, 0, 'Execute a virtual-PCR for primer set X' . $prefix . q{.} . $id);
    $sth->finish();
    $sth = $self->{'_dbh'}->prepare('SELECT a.locus_prefix, a.locus_id, a.left_seq, a.right_seq, b.sequences FROM primer AS a, alignment AS b WHERE a.prefix=? AND a.id=? AND a.alignment_prefix=b.prefix AND a.alignment_id=b.id;');
    if (!($sth->execute($prefix, $id)))
    {
        $self->_critial_error('Database manipulation error', 29);
        exit(29);
    }
    if (($sth->rows) == 1)
    {
        my $sth_seq  = $self->{'_dbh'}->prepare('SELECT sequence, organism, name, isolate, location, organelle, translation, molecule, circular, chromosome, map, accession, hgnc, geneid, go FROM sequence WHERE prefix=? AND id=?;');
        my $sth_vamp = $self->{'_dbh'}->prepare('SELECT organism FROM sequence WHERE author=? AND primer_prefix=? AND primer_id=? AND organism=?;');
        my $sth_add =
          $self->{'_dbh'}->prepare(
            'INSERT INTO sequence (prefix, id, locus_prefix, locus_id, primer_prefix, primer_id, name, isolate, location, organelle, translation, molecule, circular, chromosome, structure, features, map, accession, hgnc, geneid, organism, go, sequence_type, stop, start, strand, sequence, evalue, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM sequence WHERE prefix=?;'
          );
        my @row = $sth->fetchrow_array;
        foreach my $s (split m/ / => $row[4])
        {
            if ($s =~ m/(\d+)\.(\d+)/)
            {
                if (!($sth_seq->execute(oct($1), oct($2))))
                {
                    $self->_critial_error('Database manipulation error', 30);
                    exit(30);
                }
                if (($sth_seq->rows) == 1)
                {
                    my %sequence;
                    my @seq = $sth_seq->fetchrow_array;
                    $self->_updateStatus($geneid, 0, 0, 'Blast for ' . $seq[1]);
                    $seq[0] = uc $self->_uncompress($seq[0]);
                    $sequence{'sequence'} = ($self->_subalign($row[2], $self->_reverse_compl($row[3]), $seq[0]))[0];
                    if (!($sth_vamp->execute($self->{'_email'}, $prefix, $id, $seq[1])))
                    {
                        $self->_critial_error('Database manipulation error', 31);
                        exit(31);
                    }
                    if (($sth_vamp->rows) == 0)
                    {
                        $sequence{'size'} = length($sequence{'sequence'});
                        if ($sequence{'size'} > 0)
                        {
                            my $structure = '1..' . $sequence{'size'};
                            my $features  = '1|'
                              . length($row[2])
                              . "|P|Primer forward\n"
                              . (length($row[2]) + 1) . q{|}
                              . ($sequence{'size'} - length($row[3]))
                              . "|S|PCR Product\n"
                              . ($sequence{'size'} - length($row[3]) + 1) . '|'
                              . $sequence{'size'}
                              . '|P|Primer reverse';
                            if (
                                !(
                                   $sth_add->execute(
                                                    $prefixN, $row[0], $row[1], $prefix,
                                                    $id, $seq[2], ((defined $seq[3]) ? $seq[3] : undef), ((defined $seq[4]) ? $seq[4] : undef),
                                                    ((defined $seq[5]) ? $seq[5] : undef), ((defined $seq[6]) ? $seq[6] : 1), ((defined $seq[7]) ? $seq[7] : undef), ((defined $seq[8]) ? $seq[8] : undef),
                                                    ((defined $seq[9]) ? $seq[9] : undef), $structure, $features, ((defined $seq[10]) ? $seq[10] : undef),
                                                    ((defined $seq[11]) ? $seq[11] : undef), ((defined $seq[12]) ? $seq[12] : undef), ((defined $seq[13]) ? $seq[13] : undef), $seq[1],
                                                    ((defined $seq[14]) ? $seq[14] : undef), 4, undef, undef,
                                                    undef, $self->_compress(uc $sequence{'sequence'}), undef, $self->{'_email'},
                                                    $prefixN
                                                    )
                                 )
                               )
                            {
                                $self->_critial_error('Database manipulation error', 32);
                                exit(32);
                            }
                        }
                    }
                    my %tmp_access = $self->_vBlast($bank, 0.01, $sequence{'sequence'}, $query);
                    while (my ($species, $data) = each(%tmp_access))
                    {
                        $data =~ m/^(\.+)\|/;
                        my $evalue = $1;
                        $access{$species} = $data if (!(defined $access{$species}) || ($access{$species} =~ m/^(\.+)\|/ && float($1) < $evalue));
                    }
                }
                $sth_seq->finish;
            }
        }
        if (%access)
        {
            $self->_updateStatus($geneid, 0, 0, 'Collect results');
            foreach my $taxonid (keys %access)
            {
                my ($evalue, $chrom, $hitstart, $hitend, $hitstrand) = split(m/\|/, $access{$taxonid});
                my %sequence = $self->_getSequence($chrom, ((($hitstart - 250) > 1) ? ($hitstart - 250) : 1), $hitend + 250, 1);
                if ((defined $sequence{'molecule'}) && ($sequence{'molecule'} eq 'DNA') && (defined $sequence{'taxonid'}) && (defined $sequence{'organism'}) && (defined $sequence{'sequence'}))
                {
                    my $ok = 1;
                    if (!($sth_vamp->execute($self->{'_email'}, $prefix, $id, $sequence{'organism'})))
                    {
                        $self->_critial_error('Database manipulation error', 33);
                        exit(33);
                    }
                    if (($sth_vamp->rows) == 1) { $ok = 0; }
                    if ($ok)
                    {
                        if   ($hitstrand > 0) { $sequence{'sequence'} = ($self->_subalign($row[2], $self->_reverse_compl($row[3]), $sequence{'sequence'}))[0]; }
                        else                  { $sequence{'sequence'} = ($self->_subalign($row[2], $self->_reverse_compl($row[3]), $self->_reverse_compl($sequence{'sequence'})))[0]; }
                        $sequence{'size'} = length($sequence{'sequence'});
                        if ($sequence{'size'} > 0)
                        {
                            my $structure = '1..' . $sequence{'size'};
                            my $features  = '1|'
                              . length($row[2])
                              . "|P|Primer forward\n"
                              . (length($row[2]) + 1) . q{|}
                              . ($sequence{'size'} - length($row[3]))
                              . "|S|PCR Product\n"
                              . ($sequence{'size'} - length($row[3]) + 1) . q{|}
                              . $sequence{'size'}
                              . '|P|Primer reverse';
                            if (
                                !(
                                   $sth_add->execute(
                                                    $prefixN, $row[0],
                                                    $row[1],  $prefix,
                                                    $id, ((defined $sequence{'gene'}) ? $sequence{'gene'} : sprintf("X%lo.%lo", $prefix, $id)),
                                                    ((defined $sequence{'isolate'})   ? $sequence{'isolate'}   : undef), ((defined $sequence{'location'})    ? $sequence{'location'}    : undef),
                                                    ((defined $sequence{'organelle'}) ? $sequence{'organelle'} : undef), ((defined $sequence{'translation'}) ? $sequence{'translation'} : 1),
                                                    $sequence{'molecule'}, $sequence{'circular'},
                                                    ((defined $sequence{'chromosome'}) ? $sequence{'chromosome'} : undef), $structure,
                                                    $features, ((defined $sequence{'map'}) ? $sequence{'map'} : undef),
                                                    $sequence{'reference'}, ((defined $sequence{'hgnc'}) ? $sequence{'hgnc'} : undef),
                                                    ((defined $sequence{'geneid'}) ? $sequence{'geneid'} : undef), $sequence{'organism'},
                                                    ((defined $sequence{'go'})     ? $sequence{'go'}     : undef), 3,
                                                    $hitstart,  $hitend,
                                                    $hitstrand, $self->_compress(uc $sequence{'sequence'}),
                                                    $evalue,    $self->{'_email'},
                                                    $prefixN
                                                    )
                                 )
                               )
                            {
                                $self->_critial_error('Database manipulation error', 34);
                                exit(34);
                            }
                            $self->_updateStatus(
                                                 $geneid,
                                                 0,
                                                 0,
                                                 ((defined $sequence{'gene'})          ? $sequence{'gene'}             : q{X} . $prefix . q{.} . $id) . q{ }
                                                   . ((defined $sequence{'reference'}) ? q{|} . $sequence{'reference'} : q{}) . q{|}
                                                   . $evalue . q{|}
                                                   . $sequence{'organism'} . ' ('
                                                   . $sequence{'size'} . ' bp)'
                                                );
                        }
                    }
                }
            }
            my $sth2 = $self->{'_dbh'}->prepare('UPDATE locus SET status=5 WHERE prefix=? AND id=? AND status=4;');
            if (!($sth2->execute($row[0], $row[1])))
            {
                $self->_critial_error('Database manipulation error', 35);
                exit(35);
            }
            $sth2->finish;
        }
    }
    $self->_updateStatus($geneid, 1, 0, 'Primers VPCRd - Done');
    return;
}

=head2 version

 Title   : version
 Usage   : my $nb = UniTools->version();
 Function: Dump version and inner data.
 Returns : none.
 Args    : none.

=cut

sub version
{
    use Data::Dumper;
    my ($self, @args) = @_;
    print {*STDOUT} "\n>UniPrime version ", $VERSION, " (Bio/UniTools.pm)\n\n\$_self db:\n", Dumper($self), "\n";
}
1;
