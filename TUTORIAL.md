# Introduction to UniPrime 2.10

# UniPrime (Ootoowerg)

## TUTORIAL

Here is a simple example of a full execution of UniPrime. Each step can be reviewed with the web-companion interface.
The files you will need (`uniprime.pm` and `UniTools.pm`) are in directory `bin` of the distribution package.

 *  Add a new locus and use the human OAZ1 gene as prototype. The GeneID (4946) is retrieved from GenBank (from the command line in a Terminal window):

```
     ./uniprime.pl --action=locus --target=4946 -v
```

 *  Use the locusID provided (_e.g._ L3.1) and look for orthologues within the class Mammalia and an e-value of 2e-50 as threshold:

```
     ./uniprime.pl --action=ortho --target=L3.1 -e=2e-50 --query=Mammalia[ORGN] -v
```

 *  Use the locusID (_e.g._ L3.1) and establish an alignment and a consensus sequence with a threshold of 60%:

```
     ./uniprime.pl --action=align --target=L3.1 -c=60 -v
```

 *  Use the AlignmentID (_e.g._ A3.2) and design the primer sets:

```
     ./uniprime.pl --action=primer --target=A3.2 -v
```

 *  Optionally, use the primer set (_e.g._ X3.3) and do a virtual PCR with the Mammalian sequence of the WGS databank of the NCBI.

```
     ./uniprime.pl --action=vpcr --target=X3.3 --db=wgs --query=Mammalia[ORGN] -v
```

## COMMAND REFERENCE

There is only one file controlling UniPrime in `bin/uniprime.pl`. You may find more help by using the command-line help of this file.

```
     ./uniprime.pl --help
```

There are five main functions: adding a new locus/gene; searching for the orthologous sequences in other species; establishing the alignment; designing the primer set and doing a virtual PCR if necessary:

```
     uniprime.pl --action=<action> --target=<ID> [options]

  Available actions are:
   'locus'   Add a new locus:
    --target GenBank GeneID to be used for this action or fasta file to be used.
             (mandatory*)
    --pmid   Associate a reference. (PMID)

   'ortho'   Find new orthologues from mRNA sequences of the locus prototype
             with BLASTN with the following options:
    --target LocusID to be used for this action. (mandatory*)
    --db     Database used when performing the tblastx search. (default
             value 'refseq_rna')
    --query  the BLAST search can be limited to the result of an Entrez query
             against the database chosen. (default none; e.g. 'viruses[ORGN]')
    --dna    Use DNA rather than mRNA as initial input sequence. (default mRNA)
    -e       Set the E-value threshold. It is a positive real number. The
             default is 1e-100. Hit with E-value better than (less than)
             this threshold will be shown.

   'align'   Provide alignment using T-coffee:
    --target LocusID to be used for this action. (mandatory*)
    --dna    Use DNA rather than mRNA as initial input sequence. (default mRNA)
    -c       Set the threshold to establish the consensus sequence. It is a
             positive number between 0 and 100. (default 60)
    --select Specify the sub-set of sequence used for the alignement. (e.g.
             --select=S3.1 --select=S3.2 --select=S3.4 specify 3 sequences
             only S3.1, S3.2 and S3.4)

   'primer'  Identify universal primers from consensus sequence:
    --target AlignmentID to be used for this action. (mandatory*)
    --size   Optimal size of the amplification. (default 600)

   'vPCR'    Virtual-PCR retrieving all amplicons:
    --target PrimerID to be used for this action. (mandatory*)
    --db     Database used when performing the tblastx search. (default
             value 'wgs')
    --query  the BLAST search can be limited to the result of an Entrez query
             against the database chosen. (default 'viruses[ORGN]')

   Global options:
    --aligner either GramAlign or T-coffee. (Default GramAlign)
    -v       Print verbose output.
```
