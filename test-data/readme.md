# Test Data

This folder contains some small datasets which are used to verify the tools are working correctly before the pipeline is run.

## About the data

- `pacbio.fq`: the first 250 reads from 8e3_2's cleaned pacbio data
- `illumina1.fq`, `illumina2.fq`: the first 750 reads from 8e3_2's cleaned illumina data 
- `assembly.fa`: contig 1 of 8e3_2's assembly
- `pacbio2.fa`: artificial pacbio reads generated from `assembly.fa`. Needed to test Flye.
- `assembly-illumina.bam`: alignment betweeen `assembly.fa` and the illumina files
- `assembly-pacbio.sam`: alignment between `assembly.fa` and `pacbio.fq`
- `assembly-prokka.gff`: GFF file generated by prokka from `assembly.fa`