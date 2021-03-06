-- uniprime.v2.10 (Ootoowerg)
--
-- Copyright 2006-2012 M.Bekaert
--   Modified by Robin Boutros (2009) [1.60 (blackberry)]
--
-- PostgreSQL database: uniprime
-- --------------------------------------------------------
--

--
-- Name: alignment; Type: TABLE; Tablespace:
--

CREATE TABLE alignment (
    prefix integer NOT NULL,
    id integer NOT NULL,
    locus_prefix integer NOT NULL,
    locus_id integer NOT NULL,
    sequences text NOT NULL,
    alignment text NOT NULL,
    consensus text NOT NULL,
    score integer,
    structure text,
    program character varying(64) NOT NULL,
    comments text,
    updated timestamp without time zone DEFAULT now() NOT NULL,
    author character varying(32) NOT NULL
);


--
-- Name: banks; Type: TABLE; Tablespace:
--

CREATE TABLE banks (
    id character varying(16) NOT NULL,
    bank character varying(128) NOT NULL,
    bydefault boolean DEFAULT false NOT NULL
);


--
-- Name: evidence; Type: TABLE; Tablespace:
--

CREATE TABLE evidence (
    id character varying(8) NOT NULL,
    evidence character varying(128) NOT NULL,
    description text,
    lang character varying(8) DEFAULT 'en'::character varying NOT NULL
);


--
-- Name: execstatus; Type: TABLE; Tablespace:
--

CREATE TABLE execstatus (
    id serial NOT NULL,
    genid integer NOT NULL,
    file text DEFAULT NULL,
    locus_prefix integer DEFAULT -1 NOT NULL,
    locus_id integer DEFAULT -1 NOT NULL,
    email character varying(128) NOT NULL,
    step integer NOT NULL,
    status integer NOT NULL,
    description text NOT NULL
);


--
-- Name: execstatus_id_seq; Type: SEQUENCE SET
--

SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('execstatus', 'id'), 1, false);


--
-- Name: execution; Type: TABLE; Tablespace:
--

CREATE TABLE execution (
    id serial NOT NULL,
    step integer NOT NULL,
    params text NOT NULL,
    email character varying(128) NOT NULL,
    genid integer NOT NULL,
    name character varying(128) DEFAULT NULL::character varying,
    file text DEFAULT NULL,
    locus_prefix integer DEFAULT -1 NOT NULL,
    locus_id integer DEFAULT -1 NOT NULL,
    md5_id text NOT NULL,
    exec integer DEFAULT 0 NOT NULL,
    date timestamp without time zone DEFAULT now() NOT NULL,
    len integer DEFAULT -1 NOT NULL,
    exitvalue integer DEFAULT -1 NOT NULL
);


--
-- Name: execution_id_seq; Type: SEQUENCE SET
--

SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('execution', 'id'), 1, false);


--
-- Name: locus; Type: TABLE; Tablespace:
--

CREATE TABLE locus (
    prefix integer NOT NULL,
    id integer NOT NULL,
    genid integer NOT NULL,
    name character varying(128) NOT NULL,
    alias character varying(128),
    locus_type integer DEFAULT 0 NOT NULL,
    pathway text,
    phenotype text,
    functions text,
    evidence character varying(8) NOT NULL,
    sources text,
    status integer DEFAULT 0,
    comments text,
    updated timestamp without time zone DEFAULT now() NOT NULL,
    author character varying(32) NOT NULL
);


--
-- Name: locus_type; Type: TABLE; Tablespace:
--

CREATE TABLE locus_type (
    id integer NOT NULL,
    locus_type character varying(128) NOT NULL,
    description text,
    lang character varying(8) DEFAULT 'en'::character varying NOT NULL
);


--
-- Name: member; Type: TABLE; Tablespace:
--

CREATE TABLE member (
    id serial NOT NULL,
    "login" character varying(32) NOT NULL,
    pass_md5 character varying(32) NOT NULL,
    email character varying(128) NOT NULL,
    ip character varying(24)  NOT NULL
);


--
-- Name: member_id_seq; Type: SEQUENCE SET
--

SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('member', 'id'), 1, false);


--
-- Name: molecule; Type: TABLE; Tablespace:
--

CREATE TABLE molecule (
    id character varying(8) NOT NULL,
    molecule character varying(128) NOT NULL
);


--
-- Name: mrna; Type: TABLE; Tablespace:
--

CREATE TABLE mrna (
    prefix integer NOT NULL,
    id integer NOT NULL,
    locus_prefix integer NOT NULL,
    locus_id integer NOT NULL,
    sequence_prefix integer NOT NULL,
    sequence_id integer NOT NULL,
    mrna_type integer DEFAULT 1 NOT NULL,
    "location" text,
    mrna text NOT NULL,
    comments text,
    updated timestamp without time zone DEFAULT now() NOT NULL,
    author character varying(32) NOT NULL
);


--
-- Name: primer; Type: TABLE; Tablespace:
--

CREATE TABLE primer (
    prefix integer NOT NULL,
    id integer NOT NULL,
    locus_prefix integer NOT NULL,
    locus_id integer NOT NULL,
    alignment_prefix integer NOT NULL,
    alignment_id integer NOT NULL,
    penality double precision,
    left_seq character varying(128) NOT NULL,
    left_data text NOT NULL,
    left_name character varying(32),
    right_seq character varying(128) NOT NULL,
    right_data text NOT NULL,
    right_name character varying(32),
    "location" text,
    pcr text,
    comments text,
    updated timestamp without time zone DEFAULT now() NOT NULL,
    author character varying(32) NOT NULL
);


--
-- Name: sequence; Type: TABLE; Tablespace:
--

CREATE TABLE "sequence" (
    prefix integer NOT NULL,
    id integer NOT NULL,
    locus_prefix integer NOT NULL,
    locus_id integer NOT NULL,
    name character varying(128),
    alias character varying(128),
    "location" text,
    translation integer DEFAULT 0 NOT NULL,
    molecule character varying(8),
    circular boolean DEFAULT false NOT NULL,
    chromosome character varying(32),
    isolate character varying(128),
    organelle character varying(64),
    map character varying(128),
    accession character varying(32),
    hgnc integer,
    geneid integer,
    organism character varying(128),
    go text,
    sequence_type integer DEFAULT 0 NOT NULL,
    primer_prefix integer,
    primer_id integer,
    structure text,
    stop integer,
    "start" integer,
    strand integer,
    "sequence" text,
    features text,
    evalue double precision,
    sources text,
    comments text,
    updated timestamp without time zone DEFAULT now() NOT NULL,
    author character varying(32) NOT NULL
);


--
-- Name: sequence_type; Type: TABLE; Tablespace:
--

CREATE TABLE sequence_type (
    id integer NOT NULL,
    sequence_type character varying(128) NOT NULL,
    description text,
    lang character varying(8) DEFAULT 'en'::character varying NOT NULL
);


--
-- Name: status; Type: TABLE; Tablespace:
--

CREATE TABLE status (
    id integer NOT NULL,
    status character varying(128) NOT NULL,
    description text,
    lang character varying(8) DEFAULT 'en'::character varying NOT NULL
);


--
-- Name: stepparams; Type: TABLE; Tablespace:
--

CREATE TABLE stepparams (
    id serial NOT NULL,
    step integer NOT NULL,
    email text NOT NULL,
    genid integer NOT NULL,
    locus_prefix integer DEFAULT -1 NOT NULL,
    locus_id integer DEFAULT -1 NOT NULL,
    md5_id text NOT NULL,
    db text,
    query text,
    dna text,
    alignprog text,
    threshold text,
    alignment text,
    consensus integer,
    sequences text,
    size integer,
    dbpcr text,
    querypcr text,
    primer text,
    organisms text DEFAULT ''::text NOT NULL
);


--
-- Name: stepparams_id_seq; Type: SEQUENCE SET
--

SELECT pg_catalog.setval(pg_catalog.pg_get_serial_sequence('stepparams', 'id'), 1, false);


--
-- Name: translation; Type: TABLE; Tablespace:
--

CREATE TABLE translation (
    id integer NOT NULL,
    translation character varying(128) NOT NULL
);


--
-- Data for Name: banks; Type: TABLE DATA
--

INSERT INTO banks VALUES ('nr', 'Nucleotide collection', false);
INSERT INTO banks VALUES ('refseq_rna', 'Reference mRNA sequences', true);
INSERT INTO banks VALUES ('refseq_genomic', 'Reference genomic sequences', false);
INSERT INTO banks VALUES ('chromosome', 'NCBI genomes', false);
INSERT INTO banks VALUES ('est', 'Expressed sequence tags', false);
INSERT INTO banks VALUES ('est_others', 'Non-human, non-mouse ESTs', false);
INSERT INTO banks VALUES ('gss', 'Genomic survey sequences', false);
INSERT INTO banks VALUES ('HTGS', 'High throughput genomic sequences', false);
INSERT INTO banks VALUES ('pat', 'Patent sequences', false);
INSERT INTO banks VALUES ('pdb', 'Protein data bank', false);
INSERT INTO banks VALUES ('alu_repeats', 'Human ALU repeat elements', false);
INSERT INTO banks VALUES ('dbsts', 'Sequence tagged sites', false);
INSERT INTO banks VALUES ('wgs', 'Whole-genome shotgun reads', false);
INSERT INTO banks VALUES ('env_nt', 'Environmental samples', false);


--
-- Data for Name: evidence; Type: TABLE DATA
--

INSERT INTO evidence VALUES ('NR', 'Unknown', NULL, 'en');
INSERT INTO evidence VALUES ('DIR', 'Direct GeneID submission', NULL, 'en');
INSERT INTO evidence VALUES ('SEQ', 'User-design fasta entry', NULL, 'en');
INSERT INTO evidence VALUES ('EXO', 'Exon catcher', NULL, 'en');
INSERT INTO evidence VALUES ('ND', 'No biological Data available', NULL, 'en');


--
-- Data for Name: locus_type; Type: TABLE DATA
--

INSERT INTO locus_type VALUES (0, 'Unknown', NULL, 'en');
INSERT INTO locus_type VALUES (1, 'RNA, transfer', 'RNAs explicitly designated as transfer RNAs', 'en');
INSERT INTO locus_type VALUES (2, 'RNA, ribosomal', 'RNAs that are structural components of ribosomes', 'en');
INSERT INTO locus_type VALUES (3, 'RNA, small nuclear', 'RNAs explicitly designated as small nuclear', 'en');
INSERT INTO locus_type VALUES (4, 'RNA, small cytoplasmic', 'RNAs explicitly designated as small cytoplasmic', 'en');
INSERT INTO locus_type VALUES (5, 'RNA, small nucleolar', 'RNAs explicitly designated as small nucleolar', 'en');
INSERT INTO locus_type VALUES (6, 'Gene with protein product', NULL, 'en');
INSERT INTO locus_type VALUES (7, 'Pseudogene', 'Genes are classified as pseudogenes if there is not evidence of transcription, even if there is a predicted coding sequence', 'en');
INSERT INTO locus_type VALUES (8, 'Transposon', NULL, 'en');
INSERT INTO locus_type VALUES (9, 'RNA, micro', 'RNAs explicitly designated as micro RNA', 'en');
INSERT INTO locus_type VALUES (10, 'Other', 'Not classified entry', 'en');


--
-- Data for Name: molecule; Type: TABLE DATA
--

INSERT INTO molecule VALUES ('DNA', 'DNA');
INSERT INTO molecule VALUES ('RNA', 'RNA');
INSERT INTO molecule VALUES ('NA', 'NA');
INSERT INTO molecule VALUES ('tRNA', 'tRNA (transfer RNA)');
INSERT INTO molecule VALUES ('rRNA', 'rRNA (ribosomal RNA)');
INSERT INTO molecule VALUES ('mRNA', 'mRNA (messenger RNA)');
INSERT INTO molecule VALUES ('uRNA', 'uRNA (small nuclear RNA)');
INSERT INTO molecule VALUES ('snRNA', 'snRNA');
INSERT INTO molecule VALUES ('snoRNA', 'snoRNA');
INSERT INTO molecule VALUES ('ss-DNA', 'ss-DNA (single-stranded)');
INSERT INTO molecule VALUES ('ss-RNA', 'ss-RNA (single-stranded)');
INSERT INTO molecule VALUES ('ss-NA', 'ss-NA (single-stranded)');
INSERT INTO molecule VALUES ('ds-DNA', 'ds-DNA (double-stranded)');
INSERT INTO molecule VALUES ('ds-RNA', 'ds-RNA (double-stranded)');
INSERT INTO molecule VALUES ('ds-NA', 'ds-NA (double-stranded)');
INSERT INTO molecule VALUES ('ms-DNA', 'ms-DNA (mixed-stranded)');
INSERT INTO molecule VALUES ('ms-RNA', 'ms-RNA (mixed-stranded)');
INSERT INTO molecule VALUES ('ms-NA', 'ms-NA (mixed-stranded)');


--
-- Data for Name: sequence_type; Type: TABLE DATA
--

INSERT INTO sequence_type VALUES (0, 'Unknown', NULL, 'en');
INSERT INTO sequence_type VALUES (1, 'Prototype', 'Manual entry', 'en');
INSERT INTO sequence_type VALUES (2, 'Blasted', NULL, 'en');
INSERT INTO sequence_type VALUES (3, 'vPCR', 'Virtual PCR', 'en');
INSERT INTO sequence_type VALUES (4, 'Generated', NULL, 'en');


--
-- Data for Name: status; Type: TABLE DATA
--

INSERT INTO status VALUES (0, 'Unknown', 'The Recode record is not evaluated', 'en');
INSERT INTO status VALUES (1, 'Locus retrieval', NULL, 'en');
INSERT INTO status VALUES (2, 'Orthologs search', NULL, 'en');
INSERT INTO status VALUES (3, 'Multi-alignment', NULL, 'en');
INSERT INTO status VALUES (4, 'Primer design', NULL, 'en');
INSERT INTO status VALUES (5, 'Virtual PCR', NULL, 'en');
INSERT INTO status VALUES (6, 'Amplification in progress', NULL, 'en');
INSERT INTO status VALUES (7, 'Validated', NULL, 'en');
INSERT INTO status VALUES (8, 'Pending', NULL, 'en');
INSERT INTO status VALUES (9, 'Not validated', NULL, 'en');
INSERT INTO status VALUES (10, 'Discarded', NULL, 'en');
INSERT INTO status VALUES (11, 'Erroneous', NULL, 'en');
INSERT INTO status VALUES (12, 'Not selected', NULL, 'en');


--
-- Data for Name: translation; Type: TABLE DATA
--

INSERT INTO translation VALUES (0, 'Unknown');
INSERT INTO translation VALUES (1, 'Standard');
INSERT INTO translation VALUES (2, 'Vertebrate Mitochondrial');
INSERT INTO translation VALUES (3, 'Yeast Mitochondrial');
INSERT INTO translation VALUES (4, 'Mold, Protozoan, Coelenterate Mito. and Myco/Spiroplasma');
INSERT INTO translation VALUES (5, 'Invertebrate Mitochondrial');
INSERT INTO translation VALUES (6, 'Ciliate Nuclear, Dasycladacean Nuclear, Hexamita Nuclear');
INSERT INTO translation VALUES (9, 'Echinoderm Mitochondrial');
INSERT INTO translation VALUES (10, 'Euploid Nuclear');
INSERT INTO translation VALUES (11, 'Bacterial');
INSERT INTO translation VALUES (12, 'Alternative Yeast Nuclear');
INSERT INTO translation VALUES (13, 'Ascidian Mitochondrial');
INSERT INTO translation VALUES (14, 'Flatworm Mitochondrial');
INSERT INTO translation VALUES (15, 'Blepharisma Macronuclear');
INSERT INTO translation VALUES (16, 'Chlorophycean Mitochondrial');
INSERT INTO translation VALUES (21, 'Trematode Mitochondrial');


--
-- Name: alignment_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY alignment
    ADD CONSTRAINT alignment_pkey PRIMARY KEY (prefix, id);


--
-- Name: banks_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY banks
    ADD CONSTRAINT banks_pkey PRIMARY KEY (id);


--
-- Name: evidence_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY evidence
    ADD CONSTRAINT evidence_pkey PRIMARY KEY (id);


--
-- Name: execstatus_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY execstatus
    ADD CONSTRAINT execstatus_pkey PRIMARY KEY (id);


--
-- Name: execution_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY execution
    ADD CONSTRAINT execution_pkey PRIMARY KEY (id);


--
-- Name: locus_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY locus
    ADD CONSTRAINT locus_pkey PRIMARY KEY (prefix, id);


--
-- Name: locus_type_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY locus_type
    ADD CONSTRAINT locus_type_pkey PRIMARY KEY (id);


--
-- Name: member_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY member
    ADD CONSTRAINT member_pkey PRIMARY KEY (id);


--
-- Name: molecule_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY molecule
    ADD CONSTRAINT molecule_pkey PRIMARY KEY (id);


--
-- Name: molecule_unique; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY molecule
    ADD CONSTRAINT molecule_unique UNIQUE (molecule);


--
-- Name: mrna_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY mrna
    ADD CONSTRAINT mrna_pkey PRIMARY KEY (prefix, id);


--
-- Name: primer_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY primer
    ADD CONSTRAINT primer_pkey PRIMARY KEY (prefix, id);


--
-- Name: sequence_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY "sequence"
    ADD CONSTRAINT sequence_pkey PRIMARY KEY (prefix, id);


--
-- Name: sequence_type_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY sequence_type
    ADD CONSTRAINT sequence_type_pkey PRIMARY KEY (id);


--
-- Name: status_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY status
    ADD CONSTRAINT status_pkey PRIMARY KEY (id);


--
-- Name: stepparams_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY stepparams
    ADD CONSTRAINT stepparams_pkey PRIMARY KEY (id);


--
-- Name: translation_pkey; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY translation
    ADD CONSTRAINT translation_pkey PRIMARY KEY (id);


--
-- Name: translation_unique; Type: CONSTRAINT; Tablespace:
--

ALTER TABLE ONLY translation
    ADD CONSTRAINT translation_unique UNIQUE (translation);


--
-- Name: alignment_locus; Type: FK CONSTRAINT
--

ALTER TABLE ONLY alignment
    ADD CONSTRAINT alignment_locus FOREIGN KEY (locus_prefix, locus_id) REFERENCES locus(prefix, id) ON DELETE CASCADE;


--
-- Name: locus_evidence; Type: FK CONSTRAINT
--

ALTER TABLE ONLY locus
    ADD CONSTRAINT locus_evidence FOREIGN KEY (evidence) REFERENCES evidence(id) ON DELETE CASCADE;


--
-- Name: locus_locus_type; Type: FK CONSTRAINT
--

ALTER TABLE ONLY locus
    ADD CONSTRAINT locus_locus_type FOREIGN KEY (locus_type) REFERENCES locus_type(id) ON DELETE CASCADE;


--
-- Name: locus_status; Type: FK CONSTRAINT
--

ALTER TABLE ONLY locus
    ADD CONSTRAINT locus_status FOREIGN KEY (status) REFERENCES status(id) ON DELETE CASCADE;


--
-- Name: mrna_locus; Type: FK CONSTRAINT
--

ALTER TABLE ONLY mrna
    ADD CONSTRAINT mrna_locus FOREIGN KEY (locus_prefix, locus_id) REFERENCES locus(prefix, id) ON DELETE CASCADE;


--
-- Name: mrna_sequence; Type: FK CONSTRAINT
--

ALTER TABLE ONLY mrna
    ADD CONSTRAINT mrna_sequence FOREIGN KEY (sequence_prefix, sequence_id) REFERENCES "sequence"(prefix, id) ON DELETE CASCADE;


--
-- Name: primer_alignment; Type: FK CONSTRAINT
--

ALTER TABLE ONLY primer
    ADD CONSTRAINT primer_alignment FOREIGN KEY (alignment_prefix, alignment_id) REFERENCES alignment(prefix, id) ON DELETE CASCADE;


--
-- Name: primer_locus; Type: FK CONSTRAINT
--

ALTER TABLE ONLY primer
    ADD CONSTRAINT primer_locus FOREIGN KEY (locus_prefix, locus_id) REFERENCES locus(prefix, id) ON DELETE CASCADE;


--
-- Name: sequence_locus; Type: FK CONSTRAINT
--

ALTER TABLE ONLY "sequence"
    ADD CONSTRAINT sequence_locus FOREIGN KEY (locus_prefix, locus_id) REFERENCES locus(prefix, id) ON DELETE CASCADE;


--
-- Name: sequence_molecule; Type: FK CONSTRAINT
--

ALTER TABLE ONLY "sequence"
    ADD CONSTRAINT sequence_molecule FOREIGN KEY (molecule) REFERENCES molecule(id) ON DELETE CASCADE;


--
-- Name: sequence_sequence_type; Type: FK CONSTRAINT
--

ALTER TABLE ONLY "sequence"
    ADD CONSTRAINT sequence_sequence_type FOREIGN KEY (sequence_type) REFERENCES sequence_type(id) ON DELETE CASCADE;


--
-- Name: sequence_translation; Type: FK CONSTRAINT
--

ALTER TABLE ONLY "sequence"
    ADD CONSTRAINT sequence_translation FOREIGN KEY (translation) REFERENCES translation(id) ON DELETE CASCADE;


--
-- Done
--

