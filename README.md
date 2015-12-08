UniPrime v1.18 - A workflow-based platform for improved Universal Primer design

April 2008


# UniPrime

## Overview

UniPrime is an open-source software which automatically designs large sets of universal primers by simply inputting a GeneID reference. UniPrime automatically retrieves and aligns orthologous sequences from [GenBank](http://www.ncbi.nlm.nih.gov/Genbank/), identifies regions of conservation within the alignment and generates suitable primers that can amplify variable genomic regions. UniPrime differs from previous automatic primer design programs in that all steps of primer design are automated, saved and are phylogenetically limited. We have experimentally verified the efficiency and success of this program. UniPrime is an experimentally validated, fully automated program that generates successful cross-species primers that take into account the biological aspects of the PCR.

The current version is UniPrime [1.18] (Prune / April 2nd, 2008).


## Documentation

Text files associated with the UniPrime: [README](README.md) [INSTALL](INSTALL.md) [LICENSE](http://creativecommons.org/licenses/LGPL/2.1/).


## Download

The Linux/Unix code is publicly available.

Before installing UniPrime, your system must be compliant with the following requirements:

  * Perl 5.005 or later.
  * [NCBI Blast+](ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/) package: UniPrime uses functionality provided by Blastn.
  * [Primer3](http://primer3.sourceforge.net/) is mandatory since UniPrime is based on Primer3.
  * [T-coffee](http://www.tcoffee.org/) or [GramAlign](http://bioinfo.unl.edu/gramalign.php) is mandatory if you plan to use multi-alignment option.
  * [PostgreSQL](http://www.postgresql.org/) is mandatory since UniPrime store all the sequences, alignments and primers in a database.

Once you download, uncompress (bunzip2), and un-tar (tar xf), see the file [INSTALL](Installation.md) for the installation instructions.


## Tutorial

Here is a simple example of a full execution of UniPrime. Each step can be reviewed with the web-companion interface. For a complete explanation consult the file [README](Manifesto.md).

 *  Added a new locus and use the human [OAZ1](http://www.ncbi.nlm.nih.gov/sites/entrez?Db=gene&Cmd=ShowDetailView&TermToSearch=4946) gene as prototype. The [GeneID (4946)](http://www.ncbi.nlm.nih.gov/sites/entrez?Db=gene&Cmd=ShowDetailView&TermToSearch=4946) is retrieved from GenBank (from the command line in a Terminal window):

```
./uniprime.pl --action=locus --target=4946 -v

or

./uniprime.pl --action=locus --target=mysequence.fasta -v

```

 *  Use the locusID generated at the previous step (e.g. L3.1) and look for orthologues within the class Mammalia and an e-value of 2e<sup>-50</sup> as threshold:

```
./uniprime.pl --action=ortho --target=L3.1 -e=2e-50 --query=Mammalia[ORGN] -v

```

 *  Use the locusID (e.g. L3.1) and establish an alignment and a consensus sequence with a threshold of 60%:

```
./uniprime.pl --action=align --target=L3.1 -c=60 -v

```

 *  Use the AlignmentID (e.g. A3.2) and design the primer set:

```
./uniprime.pl --action=primer --target=A3.2 -v

```

 *  Optionally, use the primer set (e.g. X3.3) and do a virual PCR within the Class Mammalia of the WGS databank of the NCBI.

```
./uniprime.pl --action=vpcr --target=X3.3 --db=wgs --query=Mammalia[ORGN] -v

```
