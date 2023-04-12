/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowRnanano.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'
ch_bambu_config  = file("$projectDir/bin/run_bambu.r", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { GUPPY_BASECALLER            } from '../modules/local/guppy_basecaller'
include { GUPPY_BASECALLER_GPU } from '../modules/local/guppy_basecaller_gpu'
include { PYCOQC                      } from '../modules/local/pycoqc'
// if you need to use the same function/module again then we need to use
// module aliasing https://www.nextflow.io/docs/latest/dsl2.html#module-aliases
include { NANOPLOT as NANOPLOT_basecall } from '../modules/local/nanoplot'
include { NANOPLOT as NANOPLOT_fq } from '../modules/local/nanoplot'
include { NANOPLOT as NANOPLOT_bam } from '../modules/local/nanoplot'
include { MINIMAP2_ALIGN } from '../modules/local/minimap2_align'
include { SAMTOOLS_CONVERT } from '../modules/local/samtools_convert'
include { SAMTOOLS_MERGE } from '../modules/local/samtools_merge'
// include { PEPPER                      } from '../modules/local/PEPPER'
include { SAMTOOLS_INDEX  } from '../modules/local/samtools_index'
// include { MOSDEPTH                    } from '../modules/local/MOSDEPTH'
// include { MODBAM2BED                  } from '../modules/local/MODBAM2BED'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { MULTIQC } from '../modules/local/MULTIQC'
include { STRINGTIE2 } from '../modules/local/stringtie2'
include { SUBREAD } from '../modules/local/featurecount'
include { BAMBU } from '../modules/local/bambu'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary

// possiblities:
// QC per flow cell 
// QC per fastq
// enhancement 
def multiqc_report = []

workflow RNANANO {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // CHANNEL: Channel construction to stream reference genome fasta file
    //
    ch_fasta = Channel.fromPath(params.fasta)

    
    if ( params.align_only ) {
        // fastq qc
        
        // 
        MINIMAP2_ALIGN (
        INPUT_CHECK.out.reads,
        file(params.fasta)
        )
        ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

        NANOPLOT_fq (
        INPUT_CHECK.out.reads
        )
        ch_versions = ch_versions.mix(NANOPLOT_fq.out.versions)

    } else {
        // if ( params.use_gpu ) {
        //
        // MODULE: Guppy Basecaller
        //
        // Run with GPU if use_gpu = true, and set a channel to stream Guppy Basecaller output

        GUPPY_BASECALLER_GPU (
            INPUT_CHECK.out.reads
        )
        ch_versions = ch_versions.mix(GUPPY_BASECALLER_GPU.out.versions)
        ch_basecall_out = GUPPY_BASECALLER_GPU.out
        MINIMAP2_ALIGN (
        ch_basecall_out.fastq,
        file(params.fasta)
        )
        ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)
        NANOPLOT_basecall (
        ch_basecall_out.summary
        )
        ch_versions = ch_versions.mix(NANOPLOT_basecall.out.versions)
    }

    SAMTOOLS_CONVERT (
        
        MINIMAP2_ALIGN.out.sams
    )
    ch_samtools_out = SAMTOOLS_CONVERT.out

    //
    // CHANNEL: Channel operation group unaligned bams paths by sample (i.e bams of reads from multiple flow cells but the same sample streamed together to be fed for alignment module)
    //
    ch_samtools_out // minimap2  output channel
    .bam // bams path output
    .map { meta, bam -> [[sample: meta.sample] , bam]} // make sample name the only mets (remove flow cell and other info)
    .groupTuple(by: 0) // group bams by meta (i.e sample) which zero indexed
    .set { ch_bam_path_per_sample } // set channel name


    SAMTOOLS_MERGE (
        ch_bam_path_per_sample
    )
    ch_versions = ch_versions.mix(SAMTOOLS_MERGE.out.versions)


    //
    // MODULE Nanoplot seq bam file
    //
    NANOPLOT_bam (
        SAMTOOLS_MERGE.out.bam
    )
    ch_versions = ch_versions.mix(NANOPLOT_bam.out.versions)

    
    STRINGTIE2 (
        SAMTOOLS_MERGE.out.bam
    )
    ch_versions = ch_versions.mix(STRINGTIE2.out.versions)

    SUBREAD (
        SAMTOOLS_MERGE.out.bam
    )
    ch_versions = ch_versions.mix(SUBREAD.out.versions)

    BAMBU (
        ch_bambu_config,
        SAMTOOLS_MERGE.out.bam,
        file(params.fasta)
    )
    ch_versions = ch_versions.mix(BAMBU.out.versions)


    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowRnanano.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowRnanano.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    // ch_multiqc_files = ch_multiqc_files.mix(PYCOQC.out.json.collect{it[1]}.ifEmpty([]))



    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
