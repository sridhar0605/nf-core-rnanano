#!/usr/bin/env Rscript

################################################
################################################
## REQUIREMENTS                               ##
################################################
################################################

## TRANSCRIPT ISOFORM DISCOVERY AND QUANTIFICATION
    ## - ALIGNED READS IN BAM FILE FORMAT
    ## - GENOME SEQUENCE
    ## - ANNOTATION GTF FILE
    ## - THE PACKAGE BELOW NEEDS TO BE AVAILABLE TO LOAD WHEN RUNNING R

# Adopted 
# https://github.com/nf-core/nanoseq/blob/master/bin/run_bambu.r
# Stream lines bambu input.
################################################
################################################
## LOAD LIBRARY                               ##
################################################
################################################
library(bambu)

################################################
################################################
## PARSE COMMAND-LINE PARAMETERS              ##
################################################
################################################
args = commandArgs(trailingOnly=TRUE)

output_tag     <- strsplit(grep('--tag*', args, value = TRUE), split = '=')[[1]][[2]]
output_prefix     <- strsplit(grep('--prefix*', args, value = TRUE), split = '=')[[1]][[2]]
ncore          <- strsplit(grep('--ncore*', args, value = TRUE), split = '=')[[1]][[2]]
genomeseq      <- strsplit(grep('--fasta*', args, value = TRUE), split = '=')[[1]][[2]]
genomeSequence <- Rsamtools::FaFile(genomeseq)
Rsamtools::indexFa(genomeseq)
annot_gtf      <- strsplit(grep('--annotation*', args, value = TRUE), split = '=')[[1]][[2]]
readlist       <- args[6:length(args)]

################################################
################################################
## RUN BAMBU                                  ##
################################################
################################################
grlist <- prepareAnnotations(annot_gtf)
se     <- bambu(reads = readlist, annotations = grlist, genome = genomeSequence, ncore = 1, verbose = TRUE)
writeBambuOutput(se, output_tag,prefix=output_prefix)
