process MINIMAP2_ALIGN {
    label 'process_high'

    conda     (params.enable_conda ? "bioconda::minimap2=2.17" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/minimap2:2.17--hed695b0_3' :
        'quay.io/biocontainers/minimap2:2.17--hed695b0_3' }"

    input:
    tuple val(meta), path(unaligned_bams_paths) , path(reference_fasta), val(bed)

    output:
    tuple val(meta), path ("alignment/*.sam") , emit: sams
    path ("versions.yml")                     , emit: versions

    script:
    // passing bed to minimap turning this off for now.
    // def junctions = (params.protocol != 'DNA' && bed) ? "--junc-bed ${file(bed)}" : ""
    """
    minimap2 \\
        -ax splice \\
        -t $task.cpus \\
        $ref \\
        $fastq > ${meta.id}.sam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        minimap2: \$(minimap2 --version 2>&1)
    END_VERSIONS
    """
}
