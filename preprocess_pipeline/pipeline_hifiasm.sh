#!/bin/bash
###mapped genomes and reads overlap pipeline
version=240909
echo $(readlink -f $0)" "$*
echo "version: "${version}
USAGE_short="
*****************************************************
version ${version}

USAGE: ./pipeline.sh [options]  <path_to_input_chromosomes> <path_to_input_reads>

DESCRIPTION:
This is a script that maps reads to draft assemblies and get the overlaps of reads.

ARGUMENTS:
path_to_input_chromosomes   Specify path to draft assembly fasta file.
path_to_input_reads         Specify file path to hifiasm corrected reads file or raw reads file.
notice: If you input raw reads, the script will first run hifiasm.

OPTIONS:
-p|--prefix         The prefix of output. (default:gap-aid)
-r|--reads_type     The reads type. (default:hifi)
-m|--mask           The length of the proximity gap you want to mask (default:500000).
-c|--contig         Specify path to assembly fasta file.
-re|--reliable      The alignment you think are reliable ,format:'MapQ aligned_ratio'.(default:'10 0.6')
-l|--length         The Alignment block length you think are unreliable.(default:500)
-f|--filter         Do you want to filter the alignment? yes/no (default:no)
-t|--threads        Number of threads(default:4)
--aligner           minimap2/winnowmap(default:minimap2) 
--map_arg           map args ex:'-x map-hifi';
                    arg must be wraped by ' '
--hifiasm           Installed hifiasm path
--minimap2          Installed minimap2 path       
--seqkit            Installed seqkit path
--jellyfish         Installed jellyfish path
--rafilter          Installed rafilter path
-h|--help           Shows this help. Type --help for a full set of options.
*****************************************************
"
###############default parameter###
prefix="gap-aid"
reads_type="hifi"
mask_length=500000
MapQ=10
aligned_ratio=0.6
align_length=500
filter="no"
aligner="minimap2"
threads=4

while :; do
    case $1 in
    -h | --help)
        echo "$USAGE_short" >&1
        exit 0
        ;;
    -p | --prefix)
        OPTARG=$2
        prefix=$OPTARG
        shift
        ;;
    -r | --reads_type)
        OPTARG=$2
        reads_type=$OPTARG
        shift
        ;;
    -m | --mask)
        OPTARG=$2
        re='^[0-9]+$'
        if [[ $OPTARG =~ $re ]]; then
            echo " -m|--mask flag was triggered, masking shore $OPTARG." >&1
            mask_length=$OPTARG
        else
            echo ":( Wrong syntax for input size threshold. Using the default value ${mask_length}." >&2
        fi
        shift
        ;;
    -c | --contig)
        OPTARG=$2
        orig_contig=$OPTARG
        shift
        ;;
    -re | --reliable)
        OPTARG=$2
        reliable=$OPTARG
        MapQ=$(echo $reliable | awk -F' ' '{print $1}')
        aligned_ratio=$(echo $reliable | awk -F' ' '{print $2}')
        shift
        ;;
    -l | --length)
        OPTARG=$2
        re='^[0-9]+$'
        if [[ $OPTARG =~ $re ]]; then
            echo " -l|--length flag was triggered, Alignment block length $OPTARG." >&1
            align_length=$OPTARG
        else
            echo ":( Wrong syntax for input size threshold. Using the default value ${align_length}." >&2
        fi
        shift
        ;;
    -f | --filter)
        OPTARG=$2
        filter=$OPTARG
        shift
        ;;
    -t | --threads)
        OPTARG=$2
        threads=$OPTARG
        shift
        ;;
    --aligner)
        OPTARG=$2
        aligner=$OPTARG
        shift
        ;;
    --map_arg)
        OPTARG=$2
        map_arg=$OPTARG
        shift
        ;;
    --hifiasm)
        OPTARG=$2
        hifiasm=$OPTARG
        shift
        ;;
    --minimap2)
        OPTARG=$2
        minimap2=$OPTARG
        shift
        ;;
    --seqkit)
        OPTARG=$2
        seqkit=$OPTARG
        shift
        ;;
    --jellyfish)
        OPTARG=$2
        jellyfish=$OPTARG
        shift
        ;;
    --rafilter)
        OPTARG=$2
        rafilter=$OPTARG
        shift
        ;;
    --) # End of all options
        shift
        break
        ;;
    -?*)
        echo ":| WARNING: Unknown option. Ignoring: ${1}" >&2
        ;;
    *) # Default case: If no more options then break out of the loop.
        break ;;
    esac
    shift
done

#########check necessarily software########
if [ -z "$hifiasm" ]; then
    hifiasm=$(command -v hifiasm)
    if [ -n "$hifiasm" ]; then
        echo "hifiasm path : "$hifiasm
    else
        echo "missing hifiasm,you need install hifiasm"
        exit 1
    fi
else
    echo "hifiasm path : "$hifiasm
fi

if [ "$aligner" == "minimap2" ]; then
    echo "using minimap2 for alignment"
    if [ -z "$minimap2" ]; then
        minimap2=$(command -v minimap2)
        if [ -n "$minimap2" ]; then
            echo "minimap2 path : "$minimap2
        else
            echo "missing minimap2,you need install minimap2"
            exit 1
        fi
    else
        echo "minimap2 path : "$minimap2
    fi
else
    echo "using winnowmap for alignment"
    meryl=$(command -v meryl)
    winnowmap=$(command -v winnowmap)
    if [ -n "$winnowmap" ] && [ -n "$meryl" ]; then
        echo "meryl path : "$meryl
        echo "winnowmap path : "$winnowmap
    else
        echo "missing meryl or winnowmap, you need to install them and add them to PATH"
        exit 1
    fi
fi

if [ -z "$seqkit" ]; then
    seqkit=$(command -v seqkit)
    if [ -n "$seqkit" ]; then
        echo "seqkit path : "$seqkit
    else
        echo "missing seqkit,you need install seqkit"
        exit 1
    fi
else
    echo "seqkit path : "$seqkit
fi

if [ -z "$jellyfish" ]; then
    jellyfish=$(command -v jellyfish)
    if [ -n "$jellyfish" ]; then
        echo "jellyfish path : "$jellyfish
    else
        echo "missing jellyfish,you need install jellyfish"
        exit 1
    fi
else
    echo "jellyfish path : "$jellyfish
fi

if [ -z "$rafilter" ]; then
    rafilter=$(command -v rafilter)
    if [ -n "$rafilter" ]; then
        echo "rafilter path : "$rafilter
    else
        echo "missing rafilter,you need install rafilter"
        exit 1
    fi
else
    echo "rafilter path : "$rafilter
fi

if [ "$reads_type" == "hifi" ]; then
    echo "reads type:hifi"
    if [ -z "$map_arg" ]; then
        if [ "$aligner" == "minimap2" ]; then
            map_arg="-x map-hifi"
        else
            map_arg="-x map-pb"
        fi
    fi
elif [ "$reads_type" == "ont" ]; then

    echo "reads type:ONT"
    if [ -z "$map_arg" ]; then
        map_arg="-x map-ont"
    fi
fi


#########check input########
[ -z $1 ] || [ -z $2 ] && echo >&2 "Not sure how to parse your input: files not listed or not found at expected locations. Exiting!" && echo >&2 "$USAGE_short" && exit 1

[ ! -s $1 ] || [ ! -s $2 ] && echo >&2 "Not sure how to parse your input: files not listed or not found at expected locations. Exiting!" && echo >&2 "$USAGE_short" && exit 1

if [ "$#" -ne 2 ]; then
    echo >&2 "Illegal number of arguments. Please double check your input. Exiting!" && echo >&2 "$USAGE_short" && exit 1
fi

## TODO: check file format
orig_fasta=$1
orig_reads=$2
suffix=$(echo $orig_reads | awk -F'.' '{print $NF}')
if [ "$suffix" != 'fa' ] && [ "$suffix" != 'fasta' ]; then
    echo "The input file must be in fasta format. Fastq and compressed files are not supported."
    exit 1
fi
echo $(date +"%Y-%m-%d %H:%M:%S")

##########1.alignment#############
######step1.1##########
#ref

# 检查文件是否以 .ec.fa 结尾
if [[ "$orig_reads" == *.ec.fa ]]; then
    echo "The file ends with .ec.fa"
    paf_file=${orig_reads%.ec.fa}.ovlp.paf
    if [ ! -f "$paf_file" ]; then
        echo "Error: $paf_file does not exist."
        exit 1
    fi
    echo "hifiasm already run, using ${orig_reads} as input"
    echo "paf_file: $paf_file"
    echo "orig_reads: $orig_reads"

else
    echo "run hifiasm first"
    if [ "$reads_type" == "hifi" ]; then
        echo "${hifiasm} -o ${prefix}.asm -t ${threads} --write-paf --write-ec ${orig_reads}"
        ${hifiasm} -o ${prefix}.asm -t ${threads} --write-paf --write-ec ${orig_reads}
        if [ $? -ne 0 ]; then
            echo "hifiasm process error"
            exit 1
        fi
        orig_reads=${prefix}.asm.ec.fa
        paf_file=${prefix}.asm.ovlp.paf
    else
        echo "${hifiasm} -o ${prefix}.asm -t ${threads} --write-paf --write-ec --ont ${orig_reads}"
        ${hifiasm} -o ${prefix}.asm -t ${threads} --write-paf --write-ec --ont ${orig_reads}
        if [ $? -ne 0 ]; then
            echo "hifiasm process error"
            exit 1
        fi
        orig_reads=${prefix}.asm.ec.fa
        paf_file=${prefix}.asm..ovlp.paf
    fi
fi


echo "map to chromosomes "
if [ ! -f "step1.1_done.tag" ]; then
    if [ "$aligner" == "minimap2" ]; then
        echo "${minimap2} ${map_arg} -t ${threads} ${orig_fasta} ${orig_reads} > ${prefix}.map.paf 2>map.log"
        ${minimap2} ${map_arg} -t ${threads} ${orig_fasta} ${orig_reads} >${prefix}.map.paf 2>map.log        
    else
        meryl count k=15 output merylDB ${orig_fasta}
        meryl print greater-than distinct=0.9998 merylDB > repetitive_k15.txt
        ${winnowmap} -W repetitive_k15.txt ${map_arg} -t ${threads} ${orig_fasta} ${orig_reads} > ${prefix}.map.paf
    fi
    awk '{print $2}' ${prefix}.map.paf | sort -nr | head -n 1 >max_reads.txt
    if [ $? -ne 0 ]; then
        echo "map process error"
        exit 1
    fi
    echo "map to chr complete" >step1.1_done.tag
fi
echo "reads map chromosomes complete"
echo $(date +"%Y-%m-%d %H:%M:%S")

##########2.filter############
#######step2.1##########
if [ ! -f "step2.1_done.tag" ]; then
    cut -f1-12 ${prefix}.map.paf >${prefix}.map.sim.paf
    if [ $? -ne 0 ]; then
        echo "step2.1 cut process error"
        exit 1
    fi
    if [ "$filter" == "yes" ]; then
        python $(dirname "$(readlink -f "$0")")/dynamic_programming.py ${prefix}.map.sim.paf ${prefix}.map.filter.paf
        if [ $? -ne 0 ]; then
            echo "filter map process error"
            exit 1
        fi
        mv ${prefix}.map.filter.paf ${prefix}.map.sim.paf
    fi
    if [ $? -ne 0 ]; then
        echo "step2.1 process error"
        exit 1
    fi
    echo "step2.1 complete" >step2.1_done.tag
fi
echo "step2.1 complete"

#######step2.2#########
if [ ! -f "step2.2_done.tag" ]; then
    python $(dirname "$(readlink -f "$0")")/mask.py ${orig_fasta} ${mask_length}

    if [ "$mask_length" -ne 0 ]; then
        ${minimap2} ${map_arg} -t ${threads} ${orig_fasta}_masked ${orig_reads} >${prefix}_useless_map.paf 2>useless_map.log
        awk -v mapq=$MapQ -v ar=$aligned_ratio '{if ($12 > mapq && $11 / $2 > ar) print $1}' ${prefix}_useless_map.paf | sort | uniq >filtered_reads.txt
        seqkit grep -v -w 0 -j ${threads} -f filtered_reads.txt $orig_reads >${prefix}_useful.reads.fa
        grep -vFf filtered_reads.txt ${prefix}.map.sim.paf | cut -f1-12 > ${prefix}.map.filter.paf
        mv ${prefix}.map.filter.paf ${prefix}.map.sim.paf

        split -l 1000000 ${paf_file} ovlp_chunk_
        ls ovlp_chunk_* | parallel -j 8 "grep -vFf filtered_reads.txt {} | cut -f1-12 > {}.filtered"
        cat ovlp_chunk_*.filtered > ${prefix}.ovlp.sim.paf
        rm ovlp_chunk_*
        if [ $? -ne 0 ]; then
            echo "reduce overlap alignments process error"
            exit 1
        fi
    fi

    if [ $? -ne 0 ]; then
        echo "step2.2 process error"
        exit 1
    fi

    echo "step2.2 complete" >step2.2_done.tag

fi
echo "step2.2 filter reads complete"

#######step2.3##########
if [ ! -f "step2.3_done.tag" ]; then
    awk -v len=$align_length '($1 != $6 && $11 > len)' ${prefix}.ovlp.sim.paf >${prefix}.ovlp.filter.paf
    if [ $? -ne 0 ]; then
        echo "step2.3 process error"
        exit 1
    fi
    mv ${prefix}.ovlp.filter.paf ${prefix}.ovlp.sim.paf
    echo "step2.3 complete" >step2.3_done.tag
fi
echo "step2.3 filter alignments complete"

#######step2.4##########
if [ "$filter" == "yes" ]; then
    if [ ! -f "step2.4_done.tag" ]; then
        python $(dirname "$(readlink -f "$0")")/dynamic_programming.py ${prefix}.ovlp.sim.paf ${prefix}.ovlp.filter.paf
        if [ $? -ne 0 ]; then
            echo "filter overlap process error"
            exit 1
        fi
        mv ${prefix}.ovlp.filter.paf ${prefix}.ovlp.sim.paf
        echo "step2.4 complete" >step2.4_done.tag
    fi
    echo "step2.4 filter conflict alignments complete"
fi
echo "step2 complete"
echo $(date +"%Y-%m-%d %H:%M:%S")

###########3.rafliter################
#######step3.1##########
if [ ! -f "step3.1_done.tag" ]; then

    if [ -z "$orig_contig" ]; then
        ${jellyfish} count -m 21 -s 1G -t ${threads} -C -o ${prefix}.kmers.count ${orig_fasta}
    else
        ${jellyfish} count -m 21 -s 1G -t ${threads} -C -o ${prefix}.kmers.count ${orig_contig}
    fi
    ${jellyfish} dump -c -t -U 1 ${prefix}.kmers.count >${prefix}.kmers.dump
    if [ $? -ne 0 ]; then
        echo "jellyfish  process error"
        exit 1
    fi
    if [ $? -ne 0 ]; then
        echo "step3.1 process error"
        exit 1
    fi
    echo "step3.1 complete" >step3.1_done.tag
fi
echo "step3.1 jellyfish complete"

#######step3.2##########
if [ ! -f "step3.2.1_done.tag" ]; then
    if [ "$mask_length" -ne 0 ]; then
        echo "${rafilter} build -t ${threads}  -o ./ -r ${orig_fasta} -q ${prefix}_useful.reads.fa ${prefix}.kmers.dump"
        ${rafilter} build -t ${threads}  -o ./ -r ${orig_fasta} -q ${prefix}_useful.reads.fa ${prefix}.kmers.dump
    else
        echo "${rafilter} build -t ${threads}  -o ./ -r ${orig_fasta} -q ${orig_reads} ${prefix}.kmers.dump"
        ${rafilter} build -t ${threads}  -o ./ -r ${orig_fasta} -q ${orig_reads} ${prefix}.kmers.dump
    fi
    echo "step3.2.1 complete" >step3.2.1_done.tag
fi

if [ ! -f "step3.2.2_done.tag" ]; then
    ${rafilter} filter -o ref_result -t ${threads} ref.pos query.pos ${prefix}.map.sim.paf &>ref.filter.log
    if [ $? -ne 0 ]; then
        echo "rafilter filter map process error"
        exit 1
    fi
    echo "step3.2.2 complete" >step3.2.2_done.tag

fi

if [ ! -f "step3.2.3_done.tag" ]; then
    ${rafilter} filter -o qry_result -t ${threads} query.pos query.pos ${prefix}.ovlp.sim.paf &>qry.filter.log
    if [ $? -ne 0 ]; then
        echo "rafilter filter overlap process error"
        exit 1
    fi
    echo "step3.2.3 complete" >step3.2.3_done.tag
fi

if [ ! -f "step3.2_done.tag" ]; then
    sort -k6,6 ref_result/rafiltered.paf >${prefix}.map.final.paf
    sort -k6,6 qry_result/rafiltered.paf >${prefix}.ovlp.final.paf
fi
if [ $? -ne 0 ]; then
    echo "step3.2 process error"
    exit 1
fi
echo "step3.2 complete" >step3.2_done.tag
echo "step3.2 rafilter complete"
echo "step3 complete"
echo $(date +"%Y-%m-%d %H:%M:%S")

###########4.recommand################
if [ ! -f "step4.1_done.tag" ]; then
    python $(dirname "$(readlink -f "$0")")/recommand.py ${prefix}.map.final.paf ${prefix}.map.score.txt
    if [ $? -ne 0 ]; then
        echo "step4.1 process error"
        exit 1
    fi
    echo "step4.1 complete" >step4.1_done.tag
fi

if [ ! -f "step4.2_done.tag" ]; then
    python $(dirname "$(readlink -f "$0")")/recommand.py ${prefix}.ovlp.final.paf ${prefix}.ovlp.score.txt
    if [ $? -ne 0 ]; then
        echo "step4.2 process error"
        exit 1
    fi
    echo "step4.2 complete" >step4.2_done.tag
fi
echo "step4 complete"
echo $(date +"%Y-%m-%d %H:%M:%S")

###########5.build index#############
if [ ! -f "step5_done.tag" ]; then
    python $(dirname "$(readlink -f "$0")")/build_index.py ${prefix}.map.final.paf
    if [ $? -ne 0 ]; then
        echo "step5.1 process error"
        exit 1

    fi
    python $(dirname "$(readlink -f "$0")")/build_index.py ${prefix}.ovlp.final.paf
    if [ $? -ne 0 ]; then
        echo "step5.2 process error"
        exit 1
    fi

    python $(dirname "$(readlink -f "$0")")/build_index.py ${prefix}.map.score.txt
    if [ $? -ne 0 ]; then
        echo "step5.3 process error"
        exit 1
    fi
    python $(dirname "$(readlink -f "$0")")/build_index.py ${prefix}.ovlp.score.txt
    if [ $? -ne 0 ]; then
        echo "step5.4 process error"
        exit 1
    fi
    echo "step5 complete" >step5_done.tag

fi
echo "step5 complete"
echo $(date +"%Y-%m-%d %H:%M:%S")

##########6.make workdir##############
chr_fa=$(realpath ${orig_fasta})
mkdir -p ${prefix}_workdir && cd ${prefix}_workdir
ln -sf ${chr_fa} ./${prefix}.chr.fa
ln -sf ../*infor.txt ./${prefix}.chr.fa.infor.txt
ln -sf ../max_reads.txt .
ln -sf ../*.final.paf* .
ln -sf ../*.score.txt* .
if [ "$mask_length" -ne 0 ]; then
    ln -sf ../${prefix}_useful.reads.fa .
else
    ln -sf $(realpath ${orig_reads}) ./${prefix}.reads.fa
fi
cd ..
echo "step6 complete"
echo $(date +"%Y-%m-%d %H:%M:%S")

###########7.clean tmp################
#rm -rf ref_result qry_result  ${prefix}.map.sim.paf ${prefix}.ovlp.sim.paf ${prefix}.kmers.count ${prefix}.kmers.dump ref.pos query.pos

############finished############
echo "All steps complete. Done!"
echo $(date +"%Y-%m-%d %H:%M:%S")
