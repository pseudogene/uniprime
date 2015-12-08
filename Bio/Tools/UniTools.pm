## $Id: UniTools.pm,v 1.18 2008/04/02 14:50:37 Europe/Dublin $
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

# POD documentation - main docs before the code

=head1 NAME

Bio::Tools::UniTools - Universal Primer Design Tools (bioperl module)

=head1 DESCRIPTION

Provide basic and core functions from Sequence downloading, SQL
queries, multi-alignment parser, primer selection and, virtual PCRs
using NCBI Blastn and GenBank database.

=head1 REQUIREMENTS

To use this module you may need:
 * Bioperl (L<http://www.bioperl.org/>) modules,
 * primer3 (L<http://primer3.sourceforge.net/>),
 * T-coffee (L<http://www.ebi.ac.uk/tcoffeew/>) and
 * PostgreSQL (L<http://www.postgresql.org/>) server and Perl client.

=head1 FEEDBACK

User feedback is an integral part of the evolution of this module. Send
your comments and suggestions preferably to author.

=head1 AUTHOR

B<Michael Bekaert> (michael@batlab.eu)

Address:
     School of Biology & Environmental Science
     University College Dublin
     Belfield, Dublin 4
     Dublin
     Ireland

=head1 SEE ALSO

perl(1), primer3_core(1), t_coffee(1), and bioperl web site

=head1 LICENCE

Copyright 2006-2008 - Michael Bekaert

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal
methods are usually preceded with a _

=cut

package Bio::Tools::UniTools;
use vars qw(@ISA $VERSION);
use strict;
use POSIX qw(ceil floor);
use File::Temp qw/tempfile/;
use DBI;
use MIME::Base64;
use File::Basename;
use Bio::SeqIO;
use Bio::PrimarySeq;
use Bio::Tools::dpAlign;

use LWP::Simple;
use LWP::UserAgent;
use HTTP::Cookies;

use Bio::Tools::BlastTools;

use Bio::Tools::Run::Alignment::TCoffee;
use Bio::Tools::Run::Primer3;

$VERSION = '1.18 (prune)';

@ISA = qw(Bio::Root::Root Bio::Root::IO);

# Default path
my $PATH_TMP = '/tmp';

=head2 _findexec

 Title   : _findexec
 Usage   : my $path = $self->_findexec( $exec );
 Function: Find an executable file in the $PATH.
 Returns : The full path to the executable.
 Args    : $exec (mandatory) executable to be found.

=cut                       

sub _findexec {
    my ( $self, @args ) = @_;
    my $exec = shift(@args);

    foreach my $p ( split( /:/, $ENV{'PATH'} ) ) {
        return "$p/$exec" if ( -x "$p/$exec" );
    }
}

=head2 _trim

 Title   : _trim
 Usage   : my $response = $self->trim( $query );
 Function: Strip whitespace (or other characters) from the beginning
           and end of a string.
 Returns : $response, string with whitespace stripped.
 Args    : $query (mandatory), string to be strip.

=cut

sub _trim {
    my ( $self, @args ) = @_;
    my $query = shift(@args);

    $query =~ s/^\s+//;
    $query =~ s/\s+$//;
    return $query;
}

=head2 _compress

 Title   : _compress
 Usage   : my $response = $self->_compress( $query );
 Function: Compress a string into bzip2-encoded data then encodes
           it with MIME base64. This encoding is designed to make
           binary data survive transport through transport layers
           that are not 8-bit clean.
 Returns : $response, data encoded.
 Args    : $query (mandatory), string/binary to be encoded.

=cut

sub _compress {
    my ( $self, @args ) = @_;
    my $query = shift(@args);
    my $PATH_BZIP = ( ( defined $ENV{'BZIPDIR'} ) ? $ENV{'BZIPDIR'} : $self->_findexec('bzip2') );

    my ( $BZ2, $filename ) = tempfile( DIR => $PATH_TMP, UNLINK => 1 );
    print $BZ2 $query;
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

sub _uncompress {
    my ( $self, @args ) = @_;
    my $query = shift(@args);
    my $PATH_BZIP = ( ( defined $ENV{'BZIPDIR'} ) ? $ENV{'BZIPDIR'} : $self->_findexec('bzip2') );

    my ( $BZ2, $filename ) = tempfile( DIR => $PATH_TMP, UNLINK => 1 );
    print $BZ2 decode_base64($query);
    close $BZ2;
    $query = `$PATH_BZIP -d -c $filename`;
    unlink($filename);
    return $query;
}

=head2 _subalign

 Title   : _subalign
 Usage   : my @response = $self->_subalign( $f, $r, $s, $gap );
 Function: Retrive string A in B with mis-mismatches using DPAlign.
 Returns : $response, array ( equivalent of A in B, begin, end positions).
 Args    : $f (mandatory), forward primer;
           $r (mandatory), reverse primer;
           $s (mandatory), needle string;
           $gap (optional), gap penalty.

=cut

sub _subalign {
    my ( $self, @args ) = @_;
    my ( $f, $r, $s, $gap ) = @args;
    $f = Bio::Seq->new( -seq => $f, -alphabet => 'dna', -id => 'forward' );
    $r = ( Bio::Seq->new( -seq => $r, -alphabet => 'dna', -id => 'reverse' ) )->revcom;
    $s = Bio::Seq->new( -seq => $s, -alphabet => 'dna', -id => 'subject' );
    $gap = 3 unless ( defined $gap );

    my $factory = new Bio::Tools::dpAlign( -match => 3, -mismatch => -1, -gap => $gap, -ext => 1, -alg => Bio::Tools::dpAlign::DPALIGN_LOCAL_MILLER_MYERS );
    my $aln = $factory->pairwise_alignment( $f, $s );
    foreach my $seq ( $aln->each_seq_with_id('subject') ) {
        if ( ( my $start = index( $s->seq, $seq->seq ) ) != -1 ) {
            $aln = $factory->pairwise_alignment( $r, $s );
            foreach my $seq2 ( $aln->each_seq_with_id('subject') ) {
                if ( ( my $end = index( $s->seq, $seq2->seq ) ) != -1 ) {
                    next if ( $end - $start < 1 );
                    $start++;
                    $end = ( ( $s->length() < $end + $r->length() ) ? $s->length() : $end + $r->length() );
                    return ( $s->subseq( $start, $end ), $start, $end );
                }
            }
        }
    }
    return ( '', 0, 0 );
}

=head2 _align

 Title   : _align
 Usage   : my $response = $self->_align( $a, $b, $gap  );
 Function: Retrive string A in B with mis-mismatches using DPAlign.
 Returns : $response, equivalent of A in B.
 Args    : $a (mandatory), haystack string;
           $b (mandatory), needle string;
           $gap (optional), gap penalty.

=cut

sub _align {
    my ( $self, @args ) = @_;
    my ( $q, $s, $gap ) = @args;
    $q = Bio::Seq->new( -seq => $q, -alphabet => 'dna', -id => 'query' );
    $s = Bio::Seq->new( -seq => $s, -alphabet => 'dna', -id => 'subject' );
    $gap = 3 unless ( defined $gap );

    my $factory = new Bio::Tools::dpAlign( -match => 4, -mismatch => -1, -gap => $gap, -ext => 1, -alg => Bio::Tools::dpAlign::DPALIGN_LOCAL_MILLER_MYERS );
    my $aln = $factory->pairwise_alignment( $q, $s );
    foreach my $seq ( $aln->each_seq_with_id('subject') ) {
        if ( ( my $start = index( $s->seq, $seq->seq ) ) != -1 ) {
            return $seq->seq;
        }
    }
}

=head2 _getHTTP

 Title   : _getHTTP
 Usage   : my $response = $self->_getHTTP( $query );
 Function: Download Page (HTTP protocol).
 Returns : $response downloaded page.
 Args    : $query (mandatory), page address.

=cut

sub _getHTTP {
    my ( $self, @args ) = @_;
    my $query = shift(@args);

    $query =~ tr/ /+/;
    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar( HTTP::Cookies->new( file => "lwpcookies.txt", autosave => 1 ) );
    my $req = HTTP::Request->new( GET => $query );
    my $res = $ua->request($req);
    return unless ( $res->is_success );
    return $res->as_string;
}

=head2 _getMedLine

Title   : _getMedLine
Usage   : my $response = $self->_getMedLine( @query );
Function: Download MedLine citation.
Returns : $response reference list (wiki style).
Args    : @query (mandatory), list of pmid.

=cut

sub _getMedLine {
    my ( $self, @args ) = @_;
    my (@accession) = @args;
    my $res = '';
    foreach (@accession) {
        my %biblio;
        if ( my $result = $self->_getHTTP( 'http://www.hubmed.org/export/mods.cgi?uids=' . $_ ) ) {
            foreach ( split( /\n/, $result ) ) {
                if (/<title>(.*)<\/title>/) {
                    $biblio{'title'} = $1 unless ( defined $biblio{'title'} );
                } elsif (/<identifier type="doi">(.*)<\/identifier>/) {
                    $biblio{'doi'} = $1;
                } elsif (/<identifier type="pmid">(.*)<\/identifier>/) {
                    $biblio{'pmid'} = $1;
                }
            }
            if ( ( defined $biblio{'title'} ) && ( defined $biblio{'pmid'} || ( defined $biblio{'doi'} && $biblio{'doi'} ne '' ) ) ) {
                $res .= '[' . ( ( defined $biblio{'doi'} && $biblio{'doi'} ne '' ) ? 'http://dx.doi.org/' . $biblio{'doi'} : 'http://www.hubmed.org/display.cgi?uids=' . $biblio{'pmid'} ) . '|' . $biblio{'title'} . ']';
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

sub _getGene {
    my ( $self, @args ) = @_;
    my $geneid = shift(@args);
    my ( $flag_geno, $flag_pheno, $flag_path ) = ( 0, 0, 0 );
    my @pmid;
    my %gene;

    if ( my $result = $self->_getHTTP( 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=gene&retmode=xml&id=' . $geneid ) ) {
        foreach ( split( /\n/, $result ) ) {
            if (/<Entrezgene_summary>(.*)<\/Entrezgene_summary>/) {
                $gene{'comment'} = $1;
            } elsif (/<Gene-ref_locus>(.*)<\/Gene-ref_locus>/) {
                $gene{'locus'} = $1;
            } elsif (/<Gene-ref_syn_E>(.*)<\/Gene-ref_syn_E>/) {
                $gene{'locus'} = $1 unless ( defined $gene{'locus'} );
            } elsif (/<Gene-ref_desc>(.*)<\/Gene-ref_desc>/) {
                $gene{'desc'} = $1;
            } elsif (/<Maps_display-str>(.*)<\/Maps_display-str>/) {
                $gene{'map'} = $1;
            } elsif (/<Gene-commentary_type value="genomic">1<\/Gene-commentary_type>/) {
                $flag_geno++;
            } elsif ( ( $flag_geno == 1 ) && /<Gene-commentary_accession>(.*)<\/Gene-commentary_accession>/ ) {
                $gene{'accession'} = $1;
            } elsif ( ( $flag_geno == 1 ) && /<Seq-interval_from>(\d+)<\/Seq-interval_from>/ ) {
                $gene{'start'} = $1 + 1;
            } elsif ( ( $flag_geno == 1 ) && /<Seq-interval_to>(\d+)<\/Seq-interval_to>/ ) {
                $gene{'end'} = $1 + 1;
                $flag_geno++;
            } elsif (/<Gene-commentary_type value="phenotype">.*<\/Gene-commentary_type>/) {
                $flag_pheno++;
            } elsif ( ( $flag_pheno == 1 ) && /<Gene-commentary_text>(.*)<\/Gene-commentary_text>/ ) {
                if ( defined $gene{'phenotype'} ) {
                    $gene{'phenotype'} .= '|' . $1;
                } else {
                    $gene{'phenotype'} = $1;
                }
                $flag_pheno--;
            } elsif (/<Gene-commentary_heading>Pathways<\/Gene-commentary_heading>/) {
                $flag_path++;
            } elsif ( ( $flag_path == 1 ) && /<Gene-commentary_text>(.*)<\/Gene-commentary_text>/ ) {
                if ( defined $gene{'pathway'} ) {
                    $gene{'pathway'} .= '|' . $1;
                } else {
                    $gene{'pathway'} = $1;
                }
            } elsif ( ( $flag_path == 1 ) && /<\/Gene-commentary>/ ) {
                $flag_path--;
            } elsif (/<PubMedId>(.*)<\/PubMedId>/) {
                push( @pmid, $1 );
            }
        }
        if (@pmid) {
            my %seen = ();
            @{ $gene{'pmid'} } = grep { !$seen{$_}++ } @pmid;
            @{ $gene{'pmid'} } = sort @{ $gene{'pmid'} };
            @{ $gene{'pmid'} } = reverse @{ $gene{'pmid'} };
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

sub _getSequence {
    my ( $self, @args ) = @_;
    my ( $accession, $start, $end, $strand ) = @args;
    $strand = ( ( ( defined $strand ) && $strand ) ? 1 : 0 );
    my ( $flag_s, $flag_c, $flag_g, $flag_m, $flag_go, $flag_dna, $rna );
    my %sequence;

    if ( my $result = $self->_getHTTP("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=$accession&rettype=gb&seq_start=$start&seq_stop=$end") ) {
        foreach ( split( /\n/, $result ) ) {
            if (/^LOCUS /) {
                $sequence{'size'} = int( substr $_, 29, 11 );
                $sequence{'division'} = uc( $self->_trim( substr $_, 64, 3 ) );
                $sequence{'molecule'} = $self->_trim( substr $_, 44, 7 );
                $sequence{'circular'} = ( ( ( substr $_, 55, 8 ) eq 'circular' ) ? 't' : 'f' );
            } elsif (/^VERSION     ([\d\w\_]+.\d+)/) {
                $sequence{'reference'} = uc($1);
            } elsif (/^SOURCE .*\((.*)\)$/) {
                $sequence{'common'} = $1;
            } elsif (/^  ORGANISM  (.*)$/) {
                $sequence{'organism'} = $1;
            } elsif (/^     source          /) {
                $flag_s = 1;
            } elsif ( ( defined $flag_s ) && /^ {21}/ ) {
                $sequence{'taxonid'}    = int($1) if (/\/db\_xref\=\"taxon\:(\d+)\"$/);
                $sequence{'isolate'}    = $1      if (/\/isolate\=\"(.*)\"$/);
                $sequence{'chromosome'} = $1      if (/\/chromosome\=\"(.*)\"$/);
                $sequence{'organelle'}  = $1      if (/\/organelle\=\"(.*)\"$/);
                $sequence{'map'}        = $1      if (/\/map\=\"(.*)\"$/);
            } elsif ( (/^     gene            (complement\()?(join\()?\D?(\d+)\..*\D(\d+)\D?(\))*$/) && ( int($3) < 50 ) && ( ( $sequence{'size'} - int($4) ) < 50 ) ) {
                undef($flag_s);
                $sequence{'strand'}   = ( ( ( defined $1 ) && ( $1 eq 'complement(' ) ) ? -1 : 1 );
                $sequence{'start'}    = $start + int($3) - 1;
                $sequence{'end'}      = $start + int($4) - 1;
                $sequence{'location'} = $sequence{'start'} . '..' . $sequence{'end'};
                $sequence{'location'} = 'complement(' . $sequence{'location'} . ')' if ( $sequence{'strand'} < 0 );
                $flag_g               = 1;
            } elsif ( ( defined $flag_g ) && !( defined $flag_c ) && /^ {12}(.*)$/ ) {
                $sequence{'geneid'} = int($1) if (/\/db\_xref\=\"GeneID\:(\d+)\"$/);
                $sequence{'hgnc'}   = int($1) if (/\/db\_xref\=\"HGNC\:(\d+)\"$/);
                $sequence{'gene'}   = $1      if (/\/gene\=\"(.*)\"$/);
            } elsif ( ( defined $sequence{'gene'} ) && /^     mRNA            (.*)$/ ) {
                undef($flag_g);
                $flag_m = 1;
                $rna    = $self->_trim($1);
            } elsif ( ( defined $flag_m ) && /^ {21}(.*)$/ ) {
                if ( $flag_m == 1 ) {
                    if (/\//) {
                        $flag_m = 2;
                    } else {
                        $rna .= $self->_trim($1);
                    }
                }
                if ( ( $flag_m == 2 ) && (/\/gene\=\"(.*)\"$/) && ( $sequence{'gene'} eq $1 ) ) {
                    $flag_m = 3;
                } elsif ( ( $flag_m == 3 ) && (/\/transcript_id\=\"(.*)\"$/) ) {
                    if ( my $result_rna = $self->_getHTTP("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=$1&rettype=fasta") ) {
                        my ( $flag_gorna, $seq_rna );
                        foreach ( split( /\n/, $result_rna ) ) {
                            if (/^\>/) {
                                $flag_gorna = 1;
                                $seq_rna    = '';
                            } elsif ( defined $flag_gorna ) {
                                $seq_rna .= $_;
                            }
                        }
                        if ( $sequence{'strand'} < 0 ) {
                            my @loc;
                            while ( $rna =~ m/(\d+)\.\.(\d+)/go ) {
                                push @loc, ( $sequence{'size'} - $2 + 1 ) . '..' . ( $sequence{'size'} - $1 + 1 );
                            }
                            $rna = join( ',', reverse(@loc) );
                            $rna = 'join(' . $rna . ')' if ( $#loc > 0 );
                        }
                        $seq_rna =~ s/\W//g;
                        push @{ $sequence{'rna'} },     $rna;
                        push @{ $sequence{'rna_seq'} }, $seq_rna;
                    }
                    undef($flag_m);
                }
            } elsif ( ( defined $sequence{'gene'} ) && /^     CDS             / ) {
                undef($flag_g);
                undef($flag_m);
                $flag_c = 1;
            } elsif ( ( defined $flag_c ) && /^ {21}/ ) {
                if ( / \/gene\=\"(.*)\"$/ && ( $1 eq $sequence{'gene'} ) ) {
                    $flag_c = 2;
                } elsif ( $flag_c == 2 ) {
                    if (/\/transl\_table\=(\d+)$/) {
                        $sequence{'translation'} = int($1);
                    } elsif (/\/go\_process\=\"(.*)$/i) {
                        $flag_go = 1;
                        $sequence{'go'} = $1;
                    } elsif ( ( defined $flag_go ) && /\// ) {
                        undef($flag_go);
                        $sequence{'go'} = substr $sequence{'go'}, 0, ( length( $sequence{'go'} ) - 1 );
                    } elsif ( defined $flag_go ) {
                        $sequence{'go'} .= ' ' . $self->_trim($_);
                    }
                }
            } elsif (/^ORIGIN/) {
                undef($flag_g);
                undef($flag_c);
                $flag_dna = 1;
                $sequence{'sequence'} = '';
            } elsif ( ( defined $flag_dna ) && !(/^\/\//) ) {
                $sequence{'sequence'} .= $_;
            } elsif ( ( defined $flag_dna ) && /^\/\// ) {
                undef($flag_dna);
                $sequence{'sequence'} = uc $sequence{'sequence'};
                $sequence{'sequence'} =~ s/\W//g;
                $sequence{'sequence'} =~ s/\d//g;
                $sequence{'sequence'} = Bio::Seq->new( -seq => $sequence{'sequence'}, -alphabet => 'dna' )->revcom->seq if ( !$strand && ( defined $sequence{'strand'} ) && ( $sequence{'strand'} < 0 ) );
            }
        }
    }
    return %sequence;
}

=head2 _getOrganism

 Title   : _getOrganism
 Usage   : my $response = $self->_getOrganism( $bank, $key, $start,
                                 $end, $evalue, $dna, $verbose );
 Function: Retrieve hit blast sequence and identifies organism and geneid
           (Faster than a classical Bio::DB::Genbank).
 Returns : $response, string TaxonID and GeneID or undef.
 Args    : $key (mandatory), Accession number;
           $start (mandatory), begin of the subsequence;
           $end (mandatory), end of the subsequence;
           $dna (mandatory), boolean allow DNA sequence;
           $verbose (mandatory), boolean active verbose mode.

=cut

sub _getOrganism {
    my ( $self, @args ) = @_;
    my ( $key, $start, $end, $dna, $verbose ) = @args;
    my ( $taxonid, $organism, $molecule, $division, $geneid, $flag ) = ( 0, '', '', '', 0, 0 );

    if ( my $result = $self->_getHTTP("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nucleotide&id=$key&rettype=gb&seq_start=$start&seq_stop=$end") ) {
        foreach ( split( /\n/, $result ) ) {
            if (/^LOCUS /) {
                $division = $self->_trim( ( substr $_, 64, 3 ) );
            } elsif (/^  ORGANISM  (.*)$/) {
                $organism = $1;
            } elsif (/^     source          /) {
                $flag = 1;
            } elsif ( / {21}/ && ( defined $flag ) ) {
                $taxonid  = $1 if (/\/db\_xref\=\"taxon\:(\d+)\"$/);
                $geneid   = $1 if (/\/db\_xref\=\"GeneID\:(\d+)\"$/);
                $molecule = $1 if (/\/mol\_type\=\"(.*)\"$/);
            }
        }
        if ( ( $taxonid > 0 ) && ( $organism ne '' ) ) {
            if ( ( $division ne 'CON' ) && ( ( $dna == 1 ) || ( $molecule =~ /RNA/ ) ) ) {
                print STDERR "  # Get $organism: $key (region $start..$end)\n" if ($verbose);
                return $taxonid . '|' . $geneid;
            } else {
                print STDERR "  # Skip $organism: $key (region $start..$end)\n" if ($verbose);
                return;
            }
        } else {
            print STDERR "  # Skip $key (region $start..$end): No information gathered\n" if ($verbose);
            return;
        }
    }
}

=head2 _vBlast

Title   : _vBlast
Usage   : my @response = $self->_vBlasted( $bank, $evalue, $seq,
                                $query, $verbose );
Function: Make blast and retrieve hits.
Returns : @response, hash list of hits by taxonid.
Args    : $bank (mandatory), Genbank used for Blastn;
          $evalue (mandatory), threshold for Blastn;
          $seq (mand atory), query sequence (nucleotides) for Blastn;
          $query (optional), Entrez query limit;
          $verbose (optional), boolean active verbose mode.

=cut

sub _vBlast {
    my ( $self, @args ) = @_;
    my ( $bank, $evalue, $seq, $query, $verbose ) = @args;

    my %species;
    if ( defined $seq ) {
        my $blasted = Bio::Tools::BlastTools->new_query( $bank, 'blastn', $evalue, 10000 );
        my $size = $seq->length();
        if ( $blasted->submit( $seq, undef, 15, $query ) ) {
            my $hits = Bio::Tools::BlastTools->new_hits(1);
            print STDERR ' (', $blasted->rid, ")\n" if ($verbose);
            if ( $hits->retrieve($blasted) ) {
                for ( my $i = 0 ; $i < $hits->hits ; $i++ ) {
                    my $geneid = $self->_getOrganism( ( split( /\./, ( split( /\|/, $hits->name($i) ) )[3] ) )[0], $hits->hitstart($i), $hits->hitend($i), 1, $verbose );
                    if ( ( defined $geneid ) && $geneid =~ /(\d+)\|(\d+)/ ) {
                        $species{$1} = $hits->evalue($i) . '|' . ( split( /\./, ( split( /\|/, $hits->name($i) ) )[3] ) )[0] . '|' . ( ( $hits->hitstrand($i) > 0 ) ? ( ( ( $hits->hitstart($i) - $hits->querystart($i) + 1 ) >= 1 ) ? ( $hits->hitstart($i) - $hits->querystart($i) + 1 ) : 1 ) . '|' . ( $hits->hitend($i) + $size - $hits->queryend($i) ) : ( ( ( $hits->hitstart($i) - $size + $hits->queryend($i) ) >= 1 ) ? ( $hits->hitstart($i) - $size + $hits->queryend($i) ) : 1 ) . '|' . ( $hits->hitend($i) + $hits->querystart($i) - 1 ) ) . '|' . $hits->hitstrand($i) if ( !( defined $species{$1} ) || ( $species{$1} =~ /^(\.+)\|/ && float($1) < $hits->evalue($i) ) );
                    }
                }
            }
        }
    }
    return %species;
}

=head2 _getBlasted

 Title   : _getBlasted
 Usage   : my %response = $self->_getBlasted( $bank, $evalue, $seq, $dna,
                                 $query, $verbose );
 Function: Make blast and retrieve hits.
 Returns : %response, hash list of hits by geneid.
 Args    : $bank, Genbank used for Blastn;
           $evalue, threshold for Blastn;
           $seq, query sequence (nucleotides) for Blastn;
           $dna (mandatory), boolean allow DNA sequence;
           $query (optional), Entrez query limit (e.g. "Mammalia"[ORGN]);
           $verbose (mandatory), boolean active verbose mode.

=cut

sub _getBlasted {
    my ( $self, @args ) = @_;
    my ( $bank, $evalue, $seq, $dna, $query, $verbose ) = @args;
    my %access;
    my %species;

    if ( defined $seq ) {
        my $blasted = Bio::Tools::BlastTools->new_query( $bank, 'blastn', $evalue, 10000 );
        if ( $blasted->submit( $seq, undef, ( $evalue < 1e-10 ) ? 7 : undef, $query ) ) {
            my $hits = Bio::Tools::BlastTools->new_hits(1);
            print STDERR ' (', $blasted->rid, ")\n" if ($verbose);
            if ( $hits->retrieve($blasted) ) {
                for ( my $i = 0 ; $i < $hits->hits ; $i++ ) {
                    my $geneid = $self->_getOrganism( ( split( /\./, ( split( /\|/, $hits->name($i) ) )[3] ) )[0], $hits->hitstart($i), $hits->hitend($i), $dna, $verbose );
                    if ( ( defined $geneid ) && $geneid =~ /(\d+)\|(\d+)/ ) {
                        $species{$1} = $hits->evalue($i) . '|' . $2 if ( !( defined $species{$1} ) || ( $species{$1} =~ /(\.+)\|/ && float($1) < $hits->evalue($i) ) );
                    }
                }
                if (%species) {
                    foreach (%species) {
                        if (/(.+)\|(\d+)/) {
                            $access{$2} = $1;
                        }
                    }
                }
            }
        }
    }
    return %access;
}

=head2 _addBlasted

 Title   : _addBlasted
 Usage   : $self->_getBlasted( $geneid, $evalue, $locusP, $locusID, $dbh,
                  $verbose );
 Function: Add positive hit to database.
 Returns : none.
 Args    : $geneid (mandatory), geneid of the hit;
           $evalue (mandatory), e-value of Blast survey;
           $locusP (mandatory), prefix reference of the locus;
           $locusID (mandatory), ID reference of the locus;
           $dbh (mandatory), SQL object reference;
           $verbose (optional), boolean active verbose mode.

=cut

sub _addBlasted {
    my ( $self, @args ) = @_;
    my ( $geneid, $evalue, $locusP, $locusID, $dbh, $verbose ) = @args;
    $verbose = 0 unless ( defined $verbose );

    my %gene = $self->_getGene($geneid);
    if ( ( defined $gene{'accession'} ) && ( defined $gene{'start'} ) && ( defined $gene{'end'} ) ) {
        my $prefix = floor( ( ( ( localtime(time) )[5] - 107 ) * 12 + ( localtime(time) )[4] ) / 1.5 );
        print STDERR '> AccessionId: ', $gene{'accession'}, " ($evalue)\n" if ($verbose);
        my %sequence = $self->_getSequence( $gene{'accession'}, $gene{'start'}, $gene{'end'} );
        if (%sequence) {
            my $structure = '1..' . $sequence{'size'};
            $structure = ${ $sequence{'rna'} }[0] if ( defined @{ $sequence{'rna'} } );
            my $sth = $dbh->prepare('INSERT INTO sequence (prefix, id, locus_prefix, locus_id, name, isolate, location, organelle, translation, molecule, circular, chromosome, structure, map, accession, hgnc, geneid, organism, go, sequence_type, stop, start, strand, sequence, evalue, sources, comments, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM sequence WHERE prefix=?;');
            $sth->execute( $prefix, $locusP, $locusID, $sequence{'gene'}, ( ( defined $sequence{'isolate'} ) ? $sequence{'isolate'} : undef ), $sequence{'location'}, ( ( defined $sequence{'organelle'} ) ? $sequence{'organelle'} : undef ), ( ( defined $sequence{'translation'} ) ? $sequence{'translation'} : 1 ), $sequence{'molecule'}, $sequence{'circular'}, ( ( defined $sequence{'chromosome'} ) ? $sequence{'chromosome'} : undef ), $structure, ( ( defined $gene{'map'} ) ? $gene{'map'} : undef ), $sequence{'reference'}, ( ( defined $sequence{'hgnc'} ) ? $sequence{'hgnc'} : undef ), $geneid, $sequence{'organism'}, ( ( defined $sequence{'go'} ) ? $sequence{'go'} : undef ), 2, $sequence{'end'}, $sequence{'start'}, $sequence{'strand'}, $self->_compress( uc $sequence{'sequence'} ), $evalue, ( ( defined @{ $gene{'pmid'} } ) ? ( $self->_getMedLine( @{ $gene{'pmid'} } ) ) : undef ), ( ( defined $gene{'comment'} ) ? $gene{'comment'} : undef ), 'UniPrime v' . $VERSION, $prefix ) or die($DBI::errstr);
            $sth = $dbh->prepare('SELECT prefix, id FROM sequence WHERE geneid=? AND accession=? AND name=? AND location=? AND sequence_type=2;');
            $sth->execute( $geneid, $sequence{'reference'}, $sequence{'gene'}, $sequence{'location'} ) or die($DBI::errstr);

            if ( ( ( $sth->rows ) == 1 ) && ( defined @{ $sequence{'rna'} } ) ) {
                my @seqid = $sth->fetchrow_array;
                my $i     = 0;
                foreach my $rna ( @{ $sequence{'rna'} } ) {
                    $sth = $dbh->prepare('INSERT INTO mrna (prefix, id, locus_prefix, locus_id ,sequence_prefix, sequence_id, mrna, location, mrna_type, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ? FROM mrna WHERE prefix=?;');
                    $sth->execute( $prefix, $locusP, $locusID, $seqid[0], $seqid[1], $self->_compress( uc ${ $sequence{'rna_seq'} }[$i] ), $rna, ++$i, 'UniTools v' . $VERSION, $prefix ) or die($DBI::errstr);
                }
            }
            return 1;
        }
    }
}

=head2 addLocus

 Title   : addLocus (temporary)
 Usage   : Bio::Tools::UniTools->addLocus( $dbh, $geneid, $status,
                                 $pmid_ref, $locus_type, $verbose );
 Function: Add new locus and prototype into the database.
 Returns : none.
 Args    : $geneid (mandatory), geneid of the hit;
           $dbh (mandatory), SQL object reference;
           $status (optional), locus status (0: Unknown; 1: preliminary ...);
           $pmid_ref (optional), pmid associated;
           $locus_type (optional), locus type (0: Unknown; 1: gene ...)
           $verbose (optional), boolean active verbose mode.

=cut

sub addLocus {
    my ( $self, @args ) = @_;
    my ( $dbh, $geneid, $status, $pmid_ref, $locus_type, $verbose ) = @args;
    $verbose    = 0 unless ( defined $verbose );
    $status     = 1 unless ( defined $status );
    $locus_type = 0 unless ( defined $locus_type );

    print STDERR "> GeneId: $geneid\n" if ($verbose);
    my %gene = $self->_getGene($geneid);
    if ( ( defined $gene{'accession'} ) && ( defined $gene{'start'} ) && ( defined $gene{'end'} ) && ( defined $gene{'locus'} ) ) {
        my %sequence = $self->_getSequence( $gene{'accession'}, $gene{'start'}, $gene{'end'} );
        if (%sequence) {
            my $sth = $dbh->prepare('SELECT prefix, id FROM locus WHERE name=?;');
            $sth->execute( $gene{'locus'} ) or die($DBI::errstr);
            if ( ( $sth->rows ) == 0 ) {
                my $prefix = floor( ( ( ( localtime(time) )[5] - 107 ) * 12 + ( localtime(time) )[4] ) / 1.5 );
                $sth = $dbh->prepare('INSERT INTO locus (prefix, id, name, locus_type, phenotype, pathway, functions, evidence, sources, status, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM locus WHERE prefix=?;');
                $sth->execute( $prefix, $gene{'locus'}, $locus_type, ( ( defined $gene{'phenotype'} ) ? $gene{'phenotype'} : undef ), ( ( defined $gene{'pathway'} ) ? $gene{'pathway'} : undef ), ( ( defined $gene{'desc'} ) ? $gene{'desc'} : undef ), ( ( defined $pmid_ref ) ? 'TAS' : 'NAS' ), ( ( defined $pmid_ref ) ? $self->_getMedLine( ($pmid_ref) ) : undef ), $status, 'UniPrime v' . $VERSION, $prefix ) or die($DBI::errstr);
                $sth = $dbh->prepare('SELECT prefix, id FROM locus WHERE name=?;');
                $sth->execute( $gene{'locus'} ) or die($DBI::errstr);
                if ( ( $sth->rows ) == 1 ) {
                    my @locusid   = $sth->fetchrow_array;
                    my $structure = '1..' . $sequence{'size'};
                    $structure = ${ $sequence{'rna'} }[0] if ( defined @{ $sequence{'rna'} } );
                    $sth = $dbh->prepare('INSERT INTO sequence (prefix, id, locus_prefix, locus_id, name, isolate, location, organelle, translation, molecule, circular, chromosome, structure, map, accession, hgnc, geneid, organism, go, sequence_type, stop, start, strand, sequence, sources, comments, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM sequence WHERE prefix=?;');
                    $sth->execute( $prefix, $locusid[0], $locusid[1], $sequence{'gene'}, ( ( defined $sequence{'isolate'} ) ? $sequence{'isolate'} : undef ), $sequence{'location'}, ( ( defined $sequence{'organelle'} ) ? $sequence{'organelle'} : undef ), ( ( defined $sequence{'translation'} ) ? $sequence{'translation'} : 1 ), $sequence{'molecule'}, $sequence{'circular'}, ( ( defined $sequence{'chromosome'} ) ? $sequence{'chromosome'} : undef ), $structure, ( ( defined $gene{'map'} ) ? $gene{'map'} : undef ), $sequence{'reference'}, ( ( defined $sequence{'hgnc'} ) ? $sequence{'hgnc'} : undef ), $geneid, $sequence{'organism'}, ( ( defined $sequence{'go'} ) ? $sequence{'go'} : undef ), 1, $sequence{'end'}, $sequence{'start'}, $sequence{'strand'}, $self->_compress( uc $sequence{'sequence'} ), ( ( defined @{ $gene{'pmid'} } ) ? ( $self->_getMedLine( @{ $gene{'pmid'} } ) ) : undef ), ( ( defined $gene{'comment'} ) ? $gene{'comment'} : undef ), 'UniPrime v' . $VERSION, $prefix ) or die($DBI::errstr);
                    $sth = $dbh->prepare('SELECT prefix, id FROM sequence WHERE geneid=? AND accession=? AND name=? AND location=? AND sequence_type=1;');
                    $sth->execute( $geneid, $sequence{'reference'}, $sequence{'gene'}, $sequence{'location'} ) or die($DBI::errstr);
                    if ( ( ( $sth->rows ) == 1 ) && ( defined @{ $sequence{'rna'} } ) ) {
                        my @seqid = $sth->fetchrow_array;
                        my $i     = 0;
                        foreach my $rna ( @{ $sequence{'rna'} } ) {
                            $sth = $dbh->prepare('INSERT INTO mrna (prefix, id, locus_prefix, locus_id ,sequence_prefix, sequence_id, mrna, location, mrna_type, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ? FROM mrna WHERE prefix=?;');
                            $sth->execute( $prefix, $locusid[0], $locusid[1], $seqid[0], $seqid[1], $self->_compress( uc ${ $sequence{'rna_seq'} }[$i] ), $rna, ++$i, 'UniPrime v' . $VERSION, $prefix ) or die($DBI::errstr);
                        }
                    }
                    printf( STDERR "* %s (%d) added to the database, reference L%lo.%lo. :)\n", $gene{'locus'}, $geneid, $locusid[0], $locusid[1] );
                    return 1;
                }
            } else {
                my @locusid = $sth->fetchrow_array;
                printf( STDERR "* %s (%d) is already in the database, reference L%lo.%lo! :(\n", $gene{'locus'}, $geneid, $locusid[0], $locusid[1] );
                return 1;
            }
        }
    }
    printf( STDERR "* GeneID %d unknown! :(\n", $geneid );
}

=head2 populate_orthologues

 Title   : populate_orthologues
 Usage   : Bio::Tools::UniTools->populate_orthologues( $dbh, $prefix,
                                 $id, $evalue, $bank, $dna, $query, $verbose );
 Function: Retrieve orthologous sequence for referential mRNA.
 Returns : none.
 Args    : $dbh (mandatory), SQL object reference;
           $prefix (mandatory), prefix reference of the locus;
           $id (mandatory), id reference of the locus;
           $evalue (mandatory), threshold for Blastn survey;
           $bank (optional), Genbank used for Blastn (default 'refseq_rna');
           $dna (optional), boolean allow DNA sequence;
           $query (optional), Entrez query limit (e.g. "Mammalia"[ORGN]);
           $verbose (optional), boolean active verbose mode.

=cut

sub populate_orthologues {
    my ( $self, @args ) = @_;
    my ( $dbh, $prefix, $id, $evalue, $bank, $dna, $query, $verbose ) = @args;
    $verbose = 0 unless ( defined $verbose );
    $dna     = 0 unless ( defined $dna );       # 0|1 rna only (true|false)
    $bank = ( $dna ? 'refseq_genomic' : 'refseq_rna' ) unless ( defined $bank );    # nr|chromosome|refseq_rna|refseq_genomic|wgs
    my %access;

    print STDERR "\nSearch for orthologues\n" if ($verbose);
    my $sth = $dbh->prepare( $dna ? 'SELECT a.name, b.sequence, b.geneid FROM locus AS a, sequence AS b WHERE a.prefix=? AND a.id=? AND a.status>=1 AND b.locus_prefix=a.prefix AND b.locus_id=a.id AND b.sequence_type=1;' : 'SELECT a.name, c.mrna, b.geneid FROM locus AS a, sequence AS b, mrna AS c WHERE a.prefix=? AND a.id=? AND a.status>=1 AND b.locus_prefix=a.prefix AND b.locus_id=a.id AND b.sequence_type=1 AND c.sequence_prefix=b.prefix AND c.sequence_id=b.id AND c.mrna_type=1;' );
    $sth->execute( $prefix, $id ) or die($DBI::errstr);
    if ( ( $sth->rows ) > 0 ) {
        while ( my @row = $sth->fetchrow_array ) {
            print STDERR "\nRemote blast of ", $row[0] if ($verbose);
            $row[1] = $self->_uncompress( $row[1] );
            %access = $self->_getBlasted( $bank, $evalue, Bio::Seq->new( -seq => $row[1], -alphabet => 'dna' ), $dna, $query, $verbose );
            if (%access) {
                foreach my $key ( keys %access ) {
                    $self->_addBlasted( $key, $access{$key}, $prefix, $id, $dbh, $verbose ) unless ( $row[2] eq $key );
                }
                my $sth2 = $dbh->prepare('UPDATE locus SET status=2 WHERE prefix=? AND id=? AND status=1;');
                $sth2->execute( $prefix, $id ) or die($DBI::errstr);
                $sth2->finish;
            }
        }
        $sth->finish;
    }
    print STDERR "\nDone.\n" if ($verbose);
}

=head2 populate_alignment

 Title   : populate_alignment
 Usage   : Bio::Tools::UniTools->populate_alignment( $dbh,$prefix,
                                $id, $consen, $dna, $verbose );
 Function: Create multi-alignment for each locus.
 Returns : none.
 Args    : $dbh (mandatory), SQL object reference;
           $prefix (mandatory), prefix reference of the locus;
           $id (mandatory), id reference of the locus;
           $consen (optional), threshold of the consensus generated,
           between 1 and 100 (default 60);
           $dna (optional), boolean allow DNA sequence;
           $verbose (optional), boolean active verbose mode;
           @selected (optional), table of the sub-set of sequences to use.

=cut

sub populate_alignment {
    my ( $self, @args ) = @_;
    my ( $dbh, $prefix, $id, $consen, $dna, $verbose, @selected ) = @args;
    $verbose = 0  unless ( defined $verbose );
    $dna     = 0  unless ( defined $dna );       # 0|1 rna only (true|false)
    $consen  = 60 unless ( defined $consen );
    my ( $structure, $specie, $score );
    my @id;

    print STDERR "\nEstablish alignment\n" if ($verbose);
    my $sth = $dbh->prepare( $dna ? 'SELECT b.name, b.organism, b.sequence, b.structure, b.sequence_type, b.prefix, b.id FROM sequence AS b, locus AS c WHERE c.prefix=? AND c.id=? AND c.status>=2 AND b.locus_prefix=c.prefix AND b.locus_id=c.id;' : 'SELECT b.name, b.organism, a.mrna, a.location, b.sequence_type, b.prefix, b.id FROM mrna AS a, sequence AS b, locus AS c WHERE c.prefix=? AND c.id=? AND c.status>=2 AND a.locus_prefix=c.prefix AND a.locus_id=c.id AND a.mrna_type=1 AND b.prefix=a.sequence_prefix AND b.id=a.sequence_id;' );
    $sth->execute( $prefix, $id ) or die($DBI::errstr);
    if ( ( $sth->rows ) > 1 ) {
        my ( $aln, $factory );
        my $PATH_BZIP = ( ( defined $ENV{'BZIPDIR'} ) ? $ENV{'BZIPDIR'} : $self->_findexec('bzip2') );
        my $locus = sprintf( "%lo.%lo", $prefix, $id );
        open SEQ, '>' . $PATH_TMP . '/align.' . $locus . '.fasta';
        while ( my @row = $sth->fetchrow_array ) {
            my $select = sprintf( "%lo\.%lo", $row[5], $row[6] );
            if ( ( @selected == 0 ) || ( grep /^S$select$/i, @selected ) ) {
                if ( $row[4] == 1 ) {
                    $structure = $row[3];
                    $specie = $1 if ( $row[1] =~ m/^(\w+)/o );
                }
                push( @id, sprintf( "%lo.%lo", $row[5], $row[6] ) );
                print STDERR ' > ', $row[1], ' (', $row[0], ")\n" if ($verbose);
                print SEQ '>', $row[1], "\n", $self->_uncompress( $row[2] ), "\n";
            }
        }
        close SEQ;
        $sth->finish;
        $factory = new Bio::Tools::Run::Alignment::TCoffee( 'ktuple' => 1 );
        $factory->methods( [qw(Mlalign_id_pair Mslow_pair)] );
        $factory->matrix('identity');
        if ( ( -f $PATH_TMP . '/align.' . $locus . '.aln' ) || ( $aln = $factory->align( $PATH_TMP . '/align.' . $locus . '.fasta' ) ) ) {
            my @loc;
            my $program = ( ( -f $PATH_TMP . '/align.' . $locus . '.aln' ) ? 'Imported' : 'T-Coffee ' . $factory->version() );
            print STDERR "\nLocal $program\n" if ($verbose);
            my $sth = $dbh->prepare('INSERT INTO alignment (prefix, id, locus_prefix, locus_id, sequences, alignment, structure, consensus, program, score, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM alignment WHERE prefix=?;');
            if ( -f $PATH_TMP . '/align.' . $locus . '.aln' ) {
                $aln = ( Bio::AlignIO->new( -file => "<$PATH_TMP/align.$locus.aln", -format => 'fasta' ) )->next_aln;
            } else {
                my $out = Bio::AlignIO->new( -file => ">$PATH_TMP/align.$locus.aln", -format => 'fasta', -flush => 0 );
                $out->write_aln($aln);
                open SEQTMP, '<' . $factory->outfile();
                $score = $1 if ( <SEQTMP> =~ m/SCORE=(\d+)/go );
                close SEQTMP;
            }
            my $consensus = uc( $aln->consensus_string($consen) );
            $consensus =~ tr/\?/N/;
            my $realsensus = $consensus;
            if ( ( defined $structure ) && !$dna ) {
                $realsensus = '';
                my ( $pos, $last, $newpos, $newlast, $lastlast ) = ( 0, 1, 0, 1, 1 );
                while ( $structure =~ m/(\d+)\.\.(\d+)/go ) {
                    $pos += ( $2 - $1 + 1 );

                    # Genbank Hack!!!
                    #  /exception="unclassified transcription discrepancy"
                    #  /exception="mismatches in translation"
                    do {
                        eval { $aln->column_from_residue_number( $specie, $pos ) };
                        $pos-- if ($@);
                    } while ( $@ && ( $pos >= 1 ) );

                    $newpos += ( $1 - $lastlast ) + ( $aln->column_from_residue_number( $specie, $pos ) - $aln->column_from_residue_number( $specie, $last ) + 1 );
                    $realsensus .= ( 'N' x ( $1 - $lastlast ) ) . substr( $consensus, $aln->column_from_residue_number( $specie, $last ), ( $aln->column_from_residue_number( $specie, $pos ) - $aln->column_from_residue_number( $specie, $last ) + 1 ) );
                    push @loc, ( $1 - $lastlast + $newlast ) . '..' . $newpos;
                    $newlast  = $newpos + 1;
                    $last     = $pos + 1;
                    $lastlast = $2;
                }
            }
            my $myprefix = floor( ( ( ( localtime(time) )[5] - 107 ) * 12 + ( localtime(time) )[4] ) / 1.5 );
            $sth->execute( $myprefix, $prefix, $id, join( ' ', @id ), encode_base64(`$PATH_BZIP -9 -c $PATH_TMP/align.$locus.aln`), ( @loc ? 'join(' . join( ',', @loc ) . ')' : ( ($structure) ? $structure : '1..' . length($realsensus) ) ), $self->_compress($realsensus), $program, ( ( defined $score ) ? $score : undef ), 'UniPrime v' . $VERSION, $myprefix ) or die($DBI::errstr);
            $sth = $dbh->prepare('UPDATE locus SET status=3 WHERE prefix=? AND id=? AND status=2;');
            $sth->execute( $prefix, $id ) or die($DBI::errstr);
            unlink( $PATH_TMP . '/align.' . $locus . '.aln' );
        }
        unlink( $PATH_TMP . '/align.' . $locus . '.fasta' );
    }
    print STDERR "\nDone.\n" if ($verbose);
}

=head2 populate_primer

 Title   : populate_primer
 Usage   : Bio::Tools::UniTools->populate_primer( $dbh, $prefix,
                                 $id, $w, $verbose );
 Function: Find primers pair for each alignment.
 Returns : none.
 Args    : $dbh (mandatory), SQL object reference;
           $prefix (mandatory), prefix reference of the locus;
           $id (mandatory), id reference of the locus;
           $w (optional), optimal size of the target;
           $verbose (optional), boolean active verbose mode.

=cut

sub populate_primer {
    my ( $self, @args ) = @_;
    my ( $dbh, $prefix, $id, $w, $verbose ) = @args;
    $verbose = 0   unless ( defined $verbose );
    $w       = 600 unless ( defined $w );

    print STDERR "\nSearch for primers\n" if ($verbose);
    my $sth = $dbh->prepare('SELECT b.name, a.prefix, a.id, a.updated, a.sequences, a.consensus, a.structure, a.alignment FROM alignment AS a, locus AS b WHERE b.prefix=? AND b.id=? AND b.status>=3 AND a.locus_prefix=b.prefix AND a.locus_id=b.id;');
    $sth->execute( $prefix, $id ) or die($DBI::errstr);
    if ( ( $sth->rows ) > 0 ) {
        my $PATH_PRIMER3 = ( ( defined $ENV{'PRIMER3DIR'} ) ? $ENV{'PRIMER3DIR'} : $self->_findexec('primer3_core') );
        print "\nLocal Primer3\n" if ($verbose);
        while ( my @row = $sth->fetchrow_array ) {
            print STDERR " > $row[0] (alignment of the $row[3]) in progress\n" if ($verbose);
            $row[5] = $self->_uncompress( $row[5] );
            my $slide = int( length( $row[5] ) / 250 );
            my $size  = int( length( $row[5] ) / $slide );
            my %primers;
            for ( my $i = 1 ; $i <= $slide ; $i++ ) {
                my $primer3 = Bio::Tools::Run::Primer3->new( -seq => Bio::Seq->new( -seq => $row[5], -alphabet => 'dna', -id => $i ), -path => $PATH_PRIMER3 );
                my $results;
                $primer3->add_targets(
                    'PRIMER_PRODUCT_OPT_SIZE'   => $w,
                    'PRIMER_PRODUCT_SIZE_RANGE' => '550-650 500-900 400-1200 1200-10000',
                    'PRIMER_MIN_SIZE'           => 18,
                    'PRIMER_OPT_SIZE'           => 22,
                    'PRIMER_MAX_SIZE'           => 27,
                    'PRIMER_MIN_TM'             => 55,
                    'PRIMER_OPT_TM'             => 60,
                    'PRIMER_MAX_TM'             => 65,
                    'PRIMER_MAX_DIFF_TM'        => 2,
                    'PRIMER_MIN_GC'             => 40,
                    'PRIMER_MAX_GC'             => 60,
                    'PRIMER_GC_CLAMP'           => 1,
                    'PRIMER_NUM_NS_ACCEPTED'    => 2,
                    'PRIMER_SELF_ANY'           => 6.00,
                    'PRIMER_LIBERAL_BASE'       => 1,
                    'PRIMER_NUM_RETURN'         => 10,
                    'PRIMER_MAX_END_STABILITY'  => 9.0,
                    'PRIMER_WT_TM_LT'           => 3.0,
                    'PRIMER_WT_TM_GT'           => 3.0,
                    'TARGET'                    => ( $i * $size ) . ',' . 250
                );
                $results = $primer3->run;
                if ( $results->number_of_results > 0 ) {
                    for ( my $j = 1 ; $j < $results->number_of_results ; $j++ ) {
                        my $p_results = $results->primer_results($j);
                        ${$p_results}{'GROUPE'}   = $i;
                        ${$p_results}{'COMMENTS'} = '';
                        $primers{ ${$p_results}{'PRIMER_PAIR_PENALTY'} } = $p_results;
                    }
                }
            }
            if (%primers) {
                my $sth_seq = $dbh->prepare('SELECT sequence, organism FROM sequence WHERE prefix=? AND id=?;');
                foreach my $s ( split / / => $row[4] ) {
                    if ( %primers && ( $s =~ /(\d+)\.(\d+)/ ) ) {
                        $sth_seq->execute( oct($1), oct($2) ) or die($DBI::errstr);
                        if ( ( $sth_seq->rows ) == 1 ) {
                            my @seq = $sth_seq->fetchrow_array;
                            print STDERR " > Check $seq[1] sequence\n" if ($verbose);
                            $seq[0] = uc $self->_uncompress( $seq[0] );
                            $seq[2] = Bio::Seq->new( -seq => $seq[0], -alphabet => 'dna' )->revcom->seq;
                            foreach my $p ( keys %primers ) {
                                my $ref1 = uc $self->_align( ${ $primers{$p} }{'PRIMER_LEFT_SEQUENCE'}, $seq[0], 6 );
                                if ( ( defined $ref1 ) && ( substr $ref1, -5, 5 ) eq ( substr ${ $primers{$p} }{'PRIMER_LEFT_SEQUENCE'}, -5, 5 ) ) {
                                    my $ref2 = uc $self->_align( ${ $primers{$p} }{'PRIMER_RIGHT_SEQUENCE'}, $seq[2], 6 );
                                    if ( !( defined $ref2 ) || ( substr $ref2, -5, 5 ) ne ( substr ${ $primers{$p} }{'PRIMER_RIGHT_SEQUENCE'}, -5, 5 ) ) {
                                        delete( $primers{$p} );
                                    } else {
                                        my ( $a, $b, $c ) = $self->_subalign( ${ $primers{$p} }{'PRIMER_LEFT_SEQUENCE'}, ${ $primers{$p} }{'PRIMER_RIGHT_SEQUENCE'}, $seq[0], 6 );
                                        if ( ( $c - $b ) > 0 ) {
                                            ${ $primers{$p} }{'COMMENTS'} .= ' * ' . $seq[1] . ', product of ' . ( $c - $b + 1 ) . " bp<br />";
                                        } else {
                                            delete( $primers{$p} );
                                        }
                                    }
                                } else {
                                    delete( $primers{$p} );
                                }
                            }
                        }
                    }
                }
                if (%primers) {
                    my $myprefix = floor( ( ( ( localtime(time) )[5] - 107 ) * 12 + ( localtime(time) )[4] ) / 1.5 );
                    my $sth_pri = $dbh->prepare('INSERT INTO primer (prefix, id, locus_prefix, locus_id, alignment_prefix, alignment_id, penality, left_seq, left_data, right_seq, right_data, location, comments, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM primer WHERE prefix=?;');
                    foreach my $p ( keys %primers ) {
                        my $exon = 0;
                        my @loc;
                        my ($start) = split( /\,/, ${ $primers{$p} }{'PRIMER_LEFT'} );
                        my ($end)   = split( /\,/, ${ $primers{$p} }{'PRIMER_RIGHT'} );
                        while ( $row[6] =~ m/(\d+)\.\.(\d+)/go ) {
                            $exon++;
                            if ( !( defined $loc[1] ) && ( $1 > $start ) ) {
                                $loc[1] = ( ( $exon == 1 ) ? '5&#39;UTR' : 'intron ' . ( $exon - 1 ) );
                            } elsif ( ( $1 <= $start ) && ( $2 >= $start ) ) {
                                $loc[1] = 'exon ' . $exon;
                            }
                            if ( !( defined $loc[2] ) && ( $1 > $end ) ) {
                                $loc[2] = ( ( $exon == 1 ) ? '5&#39;UTR' : 'intron ' . ( $exon - 1 ) );
                            } elsif ( ( $1 <= $end ) && ( $2 >= $end ) ) {
                                $loc[2] = 'exon ' . $exon;
                            }
                        }
                        $loc[1] = '3&#39;UTR' if ( !( defined $loc[1] ) );
                        $loc[2] = '3&#39;UTR' if ( !( defined $loc[2] ) );
                        ${ $primers{$p} }{'GROUPE'} = ( ( $loc[1] ne $loc[2] ) ? $loc[1] . ' - ' . $loc[2] : $loc[1] ) . ' (window ' . ${ $primers{$p} }{'GROUPE'} . ')';
                        ${ $primers{$p} }{'PRIMER_LEFT'}  =~ tr/\,/\|/;
                        ${ $primers{$p} }{'PRIMER_RIGHT'} =~ tr/\,/\|/;
                        $sth_pri->execute( $myprefix, $prefix, $id, $row[1], $row[2], ${ $primers{$p} }{'PRIMER_PAIR_PENALTY'}, ${ $primers{$p} }{'PRIMER_LEFT_SEQUENCE'}, ${ $primers{$p} }{'PRIMER_LEFT'} . '|' . ${ $primers{$p} }{'PRIMER_LEFT_TM'} . '|' . ${ $primers{$p} }{'PRIMER_LEFT_GC_PERCENT'} . '|' . ${ $primers{$p} }{'PRIMER_LEFT_PENALTY'}, ${ $primers{$p} }{'PRIMER_RIGHT_SEQUENCE'}, ${ $primers{$p} }{'PRIMER_RIGHT'} . '|' . ${ $primers{$p} }{'PRIMER_RIGHT_TM'} . '|' . ${ $primers{$p} }{'PRIMER_RIGHT_GC_PERCENT'} . '|' . ${ $primers{$p} }{'PRIMER_RIGHT_PENALTY'}, ${ $primers{$p} }{'GROUPE'}, 'Predicted product: ' . ${ $primers{$p} }{'PRIMER_PRODUCT_SIZE'} . " bp<br />" . ${ $primers{$p} }{'COMMENTS'}, 'UniPrime v' . $VERSION, $myprefix ) or die($DBI::errstr);
                    }
                    $sth_seq = $dbh->prepare('UPDATE locus SET status=4 WHERE prefix=? AND id=? AND status=3;');
                    $sth_seq->execute( $prefix, $id ) or die($DBI::errstr);
                }
            }
        }
    }
    print STDERR "\nDone.\n" if ($verbose);
}

=head2 virtual_amplicon

 Title   : virtual_amplicon
 Usage   : Bio::Tools::UniTools->virtual_amplicon( $dbh, $prefix, $id, $query,
                                              $bank, $maxdist, $verbose );
 Function: Retrieve amplicons from primer pair.
 Returns : array of amplicons.
 Args    : $dbh (mandatory), ;
           $prefix (mandatory), ;
           $id (mandatory),;
           $query (optional), Entrez query limit (e.g. "Mammalia"[ORGN]);
           $bank (optional), databank used for Blastn (default 'wgs');
           $maxdist (optional), maximum length of an amplicon (default 5000);
           $verbose (optional), boolean active verbose mode.

=cut

sub virtual_amplicon {
    my ( $self, @args ) = @_;
    my ( $dbh, $prefix, $id, $query, $bank, $maxdist, $verbose ) = @args;
    $bank    = 'wgs' unless ( defined $bank );
    $maxdist = 5000  unless ( defined $maxdist );
    $verbose = 0     unless ( defined $verbose );
    my $prefixN = floor( ( ( ( localtime(time) )[5] - 107 ) * 12 + ( localtime(time) )[4] ) / 1.5 );
    my %access;

    printf( STDERR "\nExecute a virtual-PCR for primer set X%lo.%lo\n", $prefix, $id ) if ($verbose);
    my $sth = $dbh->prepare('SELECT a.locus_prefix, a.locus_id, a.left_seq, a.right_seq, b.sequences FROM primer AS a, alignment AS b WHERE a.prefix=? AND a.id=? AND a.alignment_prefix=b.prefix AND a.alignment_id=b.id;');
    $sth->execute( $prefix, $id ) or die($DBI::errstr);
    if ( ( $sth->rows ) == 1 ) {
        my $sth_seq  = $dbh->prepare('SELECT sequence, organism, name, isolate, location, organelle, translation, molecule, circular, chromosome, map, accession, hgnc, geneid, go FROM sequence WHERE prefix=? AND id=?;');
        my $sth_vamp = $dbh->prepare('SELECT organism FROM sequence WHERE primer_prefix=? AND primer_id=? AND organism=?;');
        my $sth_add  = $dbh->prepare('INSERT INTO sequence (prefix, id, locus_prefix, locus_id, primer_prefix, primer_id, name, isolate, location, organelle, translation, molecule, circular, chromosome, structure, features, map, accession, hgnc, geneid, organism, go, sequence_type, stop, start, strand, sequence, evalue, author) SELECT ?, CASE WHEN max(id)>=1 THEN max(id)+1 ELSE 1 END, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? FROM sequence WHERE prefix=?;');
        my @row      = $sth->fetchrow_array;
        foreach my $s ( split / / => $row[4] ) {
            if ( $s =~ /(\d+)\.(\d+)/ ) {
                $sth_seq->execute( oct($1), oct($2) ) or die($DBI::errstr);
                if ( ( $sth_seq->rows ) == 1 ) {
                    my %sequence;
                    my @seq = $sth_seq->fetchrow_array;
                    print STDERR "\n > Remote blast for ", $seq[1] if ($verbose);
                    $seq[0] = uc $self->_uncompress( $seq[0] );
                    $sequence{'sequence'} = ( $self->_subalign( $row[2], $row[3], $seq[0] ) )[0];
                    $sth_vamp->execute( $prefix, $id, $seq[1] ) or die($DBI::errstr);
                    if ( ( $sth_vamp->rows ) == 0 ) {
                        $sequence{'size'} = length( $sequence{'sequence'} );
                        if ( $sequence{'size'} > 0 ) {
                            my $structure = '1..' . $sequence{'size'};
                            my $features = '1|' . length( $row[2] ) . "|P|Primer forward\n" . ( length( $row[2] ) + 1 ) . '|' . ( $sequence{'size'} - length( $row[3] ) ) . "|S|PCR Product\n" . ( $sequence{'size'} - length( $row[3] ) + 1 ) . '|' . $sequence{'size'} . '|P|Primer reverse';
                            $sth_add->execute( $prefixN, $row[0], $row[1], $prefix, $id, $seq[2], ( ( defined $seq[3] ) ? $seq[3] : undef ), ( ( defined $seq[4] ) ? $seq[4] : undef ), ( ( defined $seq[5] ) ? $seq[5] : undef ), ( ( defined $seq[6] ) ? $seq[6] : 1 ), ( ( defined $seq[7] ) ? $seq[7] : undef ), ( ( defined $seq[8] ) ? $seq[8] : undef ), ( ( defined $seq[9] ) ? $seq[9] : undef ), $structure, $features, ( ( defined $seq[10] ) ? $seq[10] : undef ), ( ( defined $seq[11] ) ? $seq[11] : undef ), ( ( defined $seq[12] ) ? $seq[12] : undef ), ( ( defined $seq[13] ) ? $seq[13] : undef ), $seq[1], ( ( defined $seq[14] ) ? $seq[14] : undef ), 4, undef, undef, undef, $self->_compress( uc $sequence{'sequence'} ), undef, 'UniPrime v' . $VERSION, $prefixN ) or die($DBI::errstr);
                        }
                    }
                    my %tmp_access = $self->_vBlast( $bank, 0.01, Bio::Seq->new( -seq => $sequence{'sequence'}, -alphabet => 'dna' ), $query, $verbose );
                    while ( my ( $species, $data ) = each(%tmp_access) ) {
                        $data =~ /^(\.+)\|/;
                        my $evalue = $1;
                        $access{$species} = $data if ( !( defined $access{$species} ) || ( $access{$species} =~ /^(\.+)\|/ && float($1) < $evalue ) );
                    }
                }
                $sth_seq->finish;
            }
        }
        if (%access) {
            print STDERR "\n > Collect results\n" if ($verbose);
            foreach my $taxonid ( keys %access ) {
                my ( $evalue, $chrom, $hitstart, $hitend, $hitstrand ) = split( /\|/, $access{$taxonid} );
                my %sequence = $self->_getSequence( $chrom, ( ( ( $hitstart - 250 ) > 1 ) ? ( $hitstart - 250 ) : 1 ), $hitend + 250, 1 );
                if ( ( defined $sequence{'molecule'} ) && ( $sequence{'molecule'} eq 'DNA' ) && ( defined $sequence{'taxonid'} ) && ( defined $sequence{'organism'} ) && ( defined $sequence{'sequence'} ) ) {
                    my $ok = 1;
                    $sth_vamp->execute( $prefix, $id, $sequence{'organism'} ) or die($DBI::errstr);
                    if ( ( $sth_vamp->rows ) == 1 ) {
                        $ok = 0;
                    }
                    if ($ok) {
                        if ( $hitstrand > 0 ) {
                            $sequence{'sequence'} = ( $self->_subalign( $row[2], $row[3], $sequence{'sequence'} ) )[0];
                        } else {
                            $sequence{'sequence'} = ( $self->_subalign( $row[2], $row[3], Bio::Seq->new( -seq => $sequence{'sequence'}, -alphabet => 'dna' )->revcom->seq ) )[0];
                        }
                        $sequence{'size'} = length( $sequence{'sequence'} );
                        if ( $sequence{'size'} > 0 ) {
                            my $structure = '1..' . $sequence{'size'};
                            my $features = '1|' . length( $row[2] ) . "|P|Primer forward\n" . ( length( $row[2] ) + 1 ) . '|' . ( $sequence{'size'} - length( $row[3] ) ) . "|S|PCR Product\n" . ( $sequence{'size'} - length( $row[3] ) + 1 ) . '|' . $sequence{'size'} . '|P|Primer reverse';
                            $sth_add->execute( $prefixN, $row[0], $row[1], $prefix, $id, ( ( defined $sequence{'gene'} ) ? $sequence{'gene'} : sprintf( "X%lo.%lo", $prefix, $id ) ), ( ( defined $sequence{'isolate'} ) ? $sequence{'isolate'} : undef ), ( ( defined $sequence{'location'} ) ? $sequence{'location'} : undef ), ( ( defined $sequence{'organelle'} ) ? $sequence{'organelle'} : undef ), ( ( defined $sequence{'translation'} ) ? $sequence{'translation'} : 1 ), $sequence{'molecule'}, $sequence{'circular'}, ( ( defined $sequence{'chromosome'} ) ? $sequence{'chromosome'} : undef ), $structure, $features, ( ( defined $sequence{'map'} ) ? $sequence{'map'} : undef ), $sequence{'reference'}, ( ( defined $sequence{'hgnc'} ) ? $sequence{'hgnc'} : undef ), ( ( defined $sequence{'geneid'} ) ? $sequence{'geneid'} : undef ), $sequence{'organism'}, ( ( defined $sequence{'go'} ) ? $sequence{'go'} : undef ), 3, $hitstart, $hitend, $hitstrand, $self->_compress( uc $sequence{'sequence'} ), $evalue, 'UniPrime v' . $VERSION, $prefixN ) or die($DBI::errstr);
                            print STDERR '> ', ( ( defined $sequence{'gene'} ) ? $sequence{'gene'} : sprintf( "X%lo.%lo", $prefix, $id ) ), ( ( defined $sequence{'reference'} ) ? '|' . $sequence{'reference'} : '' ), '|', $evalue, '|', $sequence{'organism'}, ' (', $sequence{'size'}, " bp)\n" if ($verbose);
                        }
                    }
                }
            }
            my $sth2 = $dbh->prepare('UPDATE locus SET status=5 WHERE prefix=? AND id=? AND status=4;');
            $sth2->execute( $row[0], $row[1] ) or die($DBI::errstr);
            $sth2->finish;
        }
    }
    print STDERR "\nDone.\n" if ($verbose);
}

# and that's all the module
1;

