nextflow.enable.dsl=2

include { getDirectory; mapToDirectory } from './commons.nf'

outdirs = {}
outdirs.cleanShortReads = 'reads/short_cleaned/'
outdirs.cleanLongReads = 'reads/long_cleaned/'
outdirs.flyeAssembly = 'assembly/flye/'
outdirs.raconPolish = 'assembly/racon/'
outdirs.canuCorrect = 'reads/long_canu/'
outdirs.circlator = 'assembly/circlator/'
outdirs.pilonPolish = 'assembly/pilon/'

process cleanShortReads {
    publishDir params.outdir + outdirs.cleanShortReads, mode: 'copy', pattern: '{.command.sh,.command.log,.exitcode}', saveAs: { 'nextflow' + it }
    publishDir params.outdir, mode: 'copy'
    conda params.condaEnvsDir + 'urops-assembly'

    input:
    path illumina1Fq
    path illumina2Fq

    output:
    path '.command.sh'
    path '.command.log'
    path '.exitcode'
    path outdirs.cleanShortReads + 'illumina1.fq', emit: fq1
    path outdirs.cleanShortReads + 'illumina2.fq', emit: fq2
    path outdirs.cleanShortReads + 'trimq_used.txt'

    script:
    """
    mkdir -p ${outdirs.cleanShortReads}
    bbduk_keep_percent.py \
            --in1 $illumina1Fq --in2=$illumina2Fq \
            --out1 ${outdirs.cleanShortReads}/illumina1.fq --out2 ${outdirs.cleanShortReads}/illumina2.fq \
            --infodir $outdirs.cleanShortReads \
            --keep_percent $params.shortReadsKeepPercent --start_trimq $params.shortReadsStartTrimq \
            --min_trimq $params.shortReadsMinTrimq --args $params.bbdukArgs
    """
}

process cleanLongReads {
    publishDir params.outdir + outdirs.cleanLongReads, mode: 'copy', pattern: '{.command.sh,.command.log,.exitcode}', saveAs: { 'nextflow' + it }
    publishDir params.outdir, mode: 'copy'
    conda params.condaEnvsDir + 'urops-assembly'

    input:
    path pacbioFq
    path illumina1Fq
    path illumina2Fq

    output:
    path '.command.sh'
    path '.command.log'
    path '.exitcode'
    path outdirs.cleanLongReads + 'pacbio.fq', emit: fq
    path outdirs.cleanLongReads + 'above_10kb_reads_removed.tsv', optional: true

    script:
    """
    mkdir -p ${outdirs.cleanLongReads}
    filtlong -1 $illumina1Fq -2 $illumina2Fq \
        --min_length 1000 --keep_percent 90 --trim --split 500 --mean_q_weight 10 \
        $pacbioFq > ${outdirs.cleanLongReads}/pacbio.fq
    check_long_reads_removed.py --old $pacbioFq --new ${outdirs.cleanLongReads}/pacbio.fq \
        --threshold 10k --tsv ${outdirs.cleanLongReads}/above_10kb_reads_removed.tsv
    """
}

process flyeAssembly {
    publishDir params.outdir + outdirs.flyeAssembly, mode: 'copy', pattern: '{.command.sh,.command.log,.exitcode}', saveAs: { 'nextflow' + it }
    publishDir params.outdir, mode: 'copy'
    conda params.condaEnvsDir + 'urops-assembly'

    input:
    path pacbioFq

    output:
    path '.command.sh'
    path '.command.log'
    path '.exitcode'
    path outdirs.flyeAssembly + 'assembly.fasta', emit: assemblyFa
    path outdirs.flyeAssembly + '22-plasmids/**'
    path outdirs.flyeAssembly + 'flye.log'
    path outdirs.flyeAssembly + 'assembly_graph.*'
    path outdirs.flyeAssembly + 'assembly_info.txt'
    path outdirs.flyeAssembly + 'params.json'

    script:
    """
    mkdir -p ${outdirs.flyeAssembly} # flye can only create 1 dir
    flye --plasmids --threads $params.threads --pacbio-raw $pacbioFq -o ${outdirs.flyeAssembly}
    """
}

process raconPolish {
    publishDir params.outdir + outdirs.raconPolish, mode: 'copy', pattern: '{.command.sh,.command.log,.exitcode}', saveAs: { 'nextflow' + it }
    publishDir params.outdir + outdirs.raconPolish, mode: 'copy'
    conda params.condaEnvsDir + 'urops-assembly'

    input:
    path assemblyFa
    path pacbioFq

    output:
    path '.command.sh'
    path '.command.log'
    path '.exitcode'
    path 'final_racon_assembly.fa', emit: assemblyFa
    path 'final_racon_log.tsv', emit: logFile

    script:
    """
    run_racon.py --in_assembly $assemblyFa --in_pacbio $pacbioFq --out_prefix final_racon --threads $params.threads --maxiters $params.raconMaxIters --args "-m 8 -x -6 -g -8 -w 500"
    """
}

process canuCorrect {
    publishDir params.outdir + outdirs.canuCorrect, mode: 'copy', pattern: '{.command.sh,.command.log,.exitcode}', saveAs: { 'nextflow' + it }
    publishDir params.outdir, mode: 'copy'
    conda params.condaEnvsDir + 'urops-assembly'
    
    input:
    path pacbioFq
    path assemblyFa
    
    output:
    path '.command.sh'
    path '.command.log'
    path '.exitcode'
    path outdirs.canuCorrect + 'canu.correctedReads.fasta.gz', emit: pacbioFa
    path outdirs.canuCorrect + 'canu.report'
    path outdirs.canuCorrect + 'canu.seqStore.err'
    path outdirs.canuCorrect + 'canu.seqStore.sh'
    path outdirs.canuCorrect + 'canu-logs/**'

    script:
    genomeSize = params.canuGenomeSize == null ?
        "\$(seq_length.py $assemblyFa | bases_to_string.py -)"
        : params.canuGenomeSize.toString()
    """
    canu -correct -p canu -d $outdirs.canuCorrect genomeSize=$genomeSize -pacbio $pacbioFq useGrid=false
    """
}

process circlator {
    publishDir params.outdir + outdirs.circlator, mode: 'copy', pattern: '{.command.sh,.command.log,.exitcode}', saveAs: { 'nextflow' + it }
    publishDir params.outdir, mode: 'copy'
    conda params.condaEnvsDir + 'urops-circlator'
    
    input:
    path assemblyFa
    path pacbioFa
    
    output:
    path '.command.sh'
    path '.command.log'
    path '.exitcode'
    path outdirs.circlator + '06.fixstart.fasta', emit: assemblyFa
    path outdirs.circlator + 'circularity_summary.json', emit: circularitySummary
    path outdirs.circlator + '*.log'
    path outdirs.circlator + '*.txt'
    path outdirs.circlator + '*.coords'

    script:
    """
    mkdir -p ${outdirs.circlator}

    # circlator can't handle nested directories
    circlator all $assemblyFa $pacbioFa circlator-temp
    circlator_circularity_summary.py circlator-temp > ${outdirs.circlator}/circularity_summary.json

    mv circlator-temp/* ${outdirs.circlator}
    """
}

process pilonPolish {
    publishDir params.outdir + outdirs.pilonPolish, mode: 'copy', pattern: '{.command.sh,.command.log,.exitcode}', saveAs: { 'nextflow' + it }
    publishDir params.outdir + outdirs.pilonPolish, mode: 'copy'
    conda params.condaEnvsDir + 'urops-assembly'
    
    input:
    path assemblyFa
    path illumina1Fq
    path illumina2Fq
    
    output:
    path '.command.sh'
    path '.command.log'
    path '.exitcode'
    path 'final_pilon_assembly.fa', emit: assemblyFa
    path 'pilon*.changes'
    path 'pilon_info.tsv'

    script:
    """
    run_pilon.py --assembly $assemblyFa --reads1 $illumina1Fq --reads2 $illumina2Fq \
                --out final_pilon_assembly.fa \
                --maxiters $params.pilonMaxIters --threads $params.threads
    """
}

process shouldCirculariseOrNot {
    conda params.condaEnvsDir + 'urops-assembly'

    input:
    path assemblyFa
    path flyeDirectory

    output:
    path 'possibly-circular-assembly.fa', optional: true, emit: toCircularise
    path 'linear-assembly.fa', optional: true, emit: doNotCircularise

    script:
    """
    if [[ `flye_possibly_circular.py $flyeDirectory` == yes ]]; then
        ln -s $assemblyFa possibly-circular-assembly.fa
    else
        ln -s $assemblyFa linear-assembly.fa
    fi
    """
}

process flyeCircularitySummary {
    conda params.condaEnvsDir + 'urops-assembly'

    input:
    path flyeDirectory
    path assemblyFa // not used

    output:
    path 'circularity-summary.json', emit: summary

    script:
    """
    flye_circularity_summary.py $flyeDirectory > circularity-summary.json
    """
}

process summariseAssembly {
    conda params.condaEnvsDir + 'urops-assembly'
    publishDir params.outdir, mode: 'copy'

    input:
    path assemblyFa
    path circularitySummary // json file

    output:
    path 'assembly-summary.json'

    script:
    """
    summarise_assembly.py $assemblyFa $circularitySummary > assembly-summary.json
    """
}

workflow circulariseIfNecessary {
    take:
    assembly
    longReads
    flyeDirectory
    
    main:
    shouldCirculariseOrNot(assembly, flyeDirectory)

    // if should circularise
    canuCorrect(longReads, shouldCirculariseOrNot.out.toCircularise)
    circlator(assembly, canuCorrect.out.pacbioFa)

    // if should not circularise
    flyeCircularitySummary(flyeDirectory, shouldCirculariseOrNot.out.doNotCircularise)

    emit:
    assembly = circlator.out.assemblyFa.mix(shouldCirculariseOrNot.out.doNotCircularise)
    circularitySummary = circlator.out.circularitySummary.mix(flyeCircularitySummary.out.summary)
}

workflow assembleGenome {
    take:
    rawIllumina1Fq
    rawIllumina2Fq
    rawPacbioFq

    main:
    cleanShortReads(rawIllumina1Fq, rawIllumina2Fq)

    cleanedShort1 = cleanShortReads.out.fq1
    cleanedShort2 = cleanShortReads.out.fq2

    cleanLongReads(rawPacbioFq, cleanedShort1, cleanedShort2)

    cleanedLong = cleanLongReads.out.fq

    flyeAssembly(cleanedLong)
    flyeDirectory = flyeAssembly.out.assemblyFa.map{ file(it.parent) } // HACK flye directory

    raconPolish(flyeAssembly.out.assemblyFa, cleanedLong)
    circulariseIfNecessary(raconPolish.out.assemblyFa,
                           cleanedLong,
                           flyeDirectory) 
    pilonPolish(circulariseIfNecessary.out.assembly, cleanedShort1, cleanedShort2)

    summariseAssembly(pilonPolish.out.assemblyFa, circulariseIfNecessary.out.circularitySummary)
}
