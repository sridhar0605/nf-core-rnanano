process BAMBU {
    tag "$meta.sample"
    label 'process_high'

    conda "conda-forge::r-base=4.0.3 bioconda::bioconductor-bambu=3.0.8 bioconda::bioconductor-bsgenome=1.66.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-bambu:3.0.8--r42hc247a5b_0' :
        'quay.io/biocontainers/bioconductor-bambu:3.0.8--r42hc247a5b_0' }"

    input:
    path ch_bambu_config
    tuple val(meta),path(bam)
    path reference_fasta
    

    output:
    path "${meta.sample}_counts_gene.txt"         , emit: ch_gene_counts
    path "${meta.sample}_counts_transcript.txt"   , emit: ch_transcript_counts
    path "${meta.sample}_extended_annotations.gtf", emit: extended_gtf
    path "${meta.sample}_versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    run_bambu.r \\
        --tag=. \\
        --prefix=${meta.sample}_ \\
        --ncore=1 \\
        --annotation=${params.gtf} \\
        --fasta=$reference_fasta $bam

    cat <<-END_VERSIONS > ${meta.sample}_versions.yml
    "${task.process}":
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        bioconductor-bambu: \$(Rscript -e "library(bambu); cat(as.character(packageVersion('bambu')))")
        bioconductor-bsgenome: \$(Rscript -e "library(BSgenome); cat(as.character(packageVersion('BSgenome')))")
    END_VERSIONS
    """
}
