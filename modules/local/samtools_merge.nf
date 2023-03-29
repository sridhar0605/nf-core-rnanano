process SAMTOOLS_MERGE {
    label 'process_high'

    conda "bioconda::samtools=1.16.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.16.1--h6899075_1' :
        'quay.io/biocontainers/samtools:1.16.1--h6899075_1' }"

    input:
        tuple val(meta), path(aligned_sams)

    output:
        tuple val(meta), path("${meta.id}.bam")    , emit: bam
        tuple val(meta), path("${meta.id}.bam.bai"), emit: bai
        path  ("versions.yml")                                , emit: versions

    script:
    """
    samtools view -bS -@ ${task.cpus} -o ${meta.id}_unsorted.bam $aligned_sams &&
    samtools sort -o ${meta.id}.bam ${meta.id}_unsorted.bam &&
    samtools index ${meta.id}.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    """
    ln -s ${workflow.launchDir}/stub-test/stubs/aml476081.bam ${meta.sample}.bam
    ln -s ${workflow.launchDir}/stub-test/stubs/aml476081.bam.bai ${meta.sample}.bam.bai
    cp ${workflow.launchDir}/stub-test/stubs/samtools_versions/versions.yml .

    """

}
