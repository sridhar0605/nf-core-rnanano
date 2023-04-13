process NANOPLOT {
    tag "$meta.sample"
    label 'process_medium'

    conda (params.enable_conda ? 'bioconda::nanoplot=1.38.0' : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/nanoplot:1.41.0--pyhdfd78af_0' :
        'quay.io/biocontainers/nanoplot:1.41.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path (ontfile)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.png") , emit: png
    tuple val(meta), path("*.txt") , emit: txt
    tuple val(meta), path('*.log') , emit: log
    path  "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // $options.args \\
    def input_file = ("$ontfile".endsWith(".fastq.gz")) ? "--fastq ${ontfile}" :
        ("$ontfile".endsWith(".txt")) ? "--summary ${ontfile}" :
        ("$ontfile".endsWith(".bam")) ? "--bam ${ontfile}" : ''
    
    def prefix_options = ("$ontfile".endsWith(".fastq.gz")) ? "--prefix ${meta.id}'_'" :
        ("$ontfile".endsWith(".txt")) ? "--prefix ${meta.id}'_'" :
        ("$ontfile".endsWith(".bam")) ? "--prefix ${meta.sample}'_'" : ''
    // def output_dir = ("$ontfile".endsWith(".fastq.gz")) ? "${meta.id}" :
    //                 ("$ontfile".endsWith(".txt")) ? "summary" : ''
    //                 ("$ontfile".endsWith(".bam")) ? "bam" : ''
    // output_html = output_dir+'/*.html'
    // output_png  = output_dir+'/*.png'
    // output_txt  = output_dir+'/*.txt'
    // output_log  = output_dir+'/*.log'
    """
    NanoPlot $args \\
        $input_file \\
        --threads $task.cpus \\
        $prefix_options
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        nanoplot: \$(echo \$(NanoPlot --version 2>&1) | sed 's/^.*NanoPlot //; s/ .*\$//')
    END_VERSIONS
    """
}