#!/bin/bash
###mapped genomes and reads overlap pipeline
version=240510
echo $(readlink -f $0)" "$*
echo "version: "${version}
USAGE_short="
*****************************************************
version 231122

USAGE: ./pipeline.sh [options]  <path_to_input_chromosomes> <path_to_input_reads>

DESCRIPTION:
This is a script that maps reads to draft assemblies and get the overlaps of reads

ARGUMENTS:
path_to_input_chromosomes   Specify path to draft assembly fasta file.
path_to_input_reads         Specify file path to raw reads file.


OPTIONS:
-p|--prefix         The prefix of output. (default:gap-aid)
-r|--reads_type     The reads type. (default:hifi)
-m|--mask           The length of the proximity gap you want to mask (default:500000).
-c|--contig         Specify path to assembly fasta file.
-re|--reliable      The alignment you think are reliable ,format:'MapQ aligned_length'.default:'10 500'
-f|--filter         Do you want to filter the alignment? default:no
-z|--zip            Do you want to compressed the alignment file with gzip ? default:no
-t|--threads        Number of threads(default:4)
--aligner           minimap2/winnowmap(default:minimap2) 
--map_arg           map args ex:'-x map-hifi';
                    arg must be wraped by ' '
--minimap2          Installed minimap2 path
--winnowmap         Installed winnowmap path         
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
aligned_length=500
filter="no"
zip="no"
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
            echo ":( Wrong syntax for input size threshold. Using the default value ${input_size}." >&2
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
        aligned_length=$(echo $reliable | awk -F' ' '{print $2}')
        shift
        ;;
    -f | --filter)
        OPTARG=$2
        filter=$OPTARG
        shift
        ;;
    -z | --zip)
        OPTARG=$2
        zip=$OPTARG
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

    --minimap2)
        OPTARG=$2
        minimap2=$OPTARG
        shift
        ;;
    --winnowmap)
        OPTARG=$2
        winnowmap=$OPTARG
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
[ -z $1 ] || [ -z $2 ] && echo >&2 "Not sure how to parse your input: files not listed or not found at expected locations. Exiting!" && echo >&2 "$USAGE_short" && exit 1

[ ! -s $1 ] || [ ! -s $2 ] && echo >&2 "Not sure how to parse your input: files not listed or not found at expected locations. Exiting!" && echo >&2 "$USAGE_short" && exit 1

## TODO: check file format

if [ "$#" -ne 2 ]; then
    echo >&2 "Illegal number of arguments. Please double check your input. Exiting!" && echo >&2 "$USAGE_short" && exit 1
fi

orig_fasta=$1
orig_reads=$2

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
    if [ -z "$winnowmap" ]; then
        winnowmap=$(command -v winnowmap)
        if [ -n "$winnowmap" ]; then
            echo "winnowmap path : "$winnowmap
        else
            echo "missing winnowmap,you need install winnowmap"
            exit 1
        fi
    else
        echo "winnowmap path : "$winnowmap
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

if [ -z "$map_arg" ]; then
    if [ "$reads_type" == "hifi" ]; then
        echo "reads type:hifi"
        map_arg="-x map-hifi"
        ava_arg="-x ava-pb"
    else

        echo "reads type:ONT"
        map_arg="-x map-ont"
        ava_arg="-x ava-ont"
    fi
fi
echo $(date +"%Y-%m-%d %H:%M:%S")

##########1.alignment#############

######step1.1##########
#ref
echo "map to chromosomes "
if [ ! -f "step1.1_done.tag" ]; then
    echo "${minimap2} ${map_arg} -t ${threads} ${orig_fasta} ${orig_reads} > ${prefix}.map.paf 2>map.log"
    ${minimap2} ${map_arg} -t ${threads} ${orig_fasta} ${orig_reads} >${prefix}.map.paf 2>map.log
    if [ $? -ne 0 ]; then
        echo "map process error"
        exit 1
    fi
    awk '{print $2}' ${prefix}.map.paf | sort -nr | head -n 1 >max_reads.txt
    if [ $? -ne 0 ]; then
        echo "map process error"
        exit 1
    fi
    echo "map to chr complete" >step1.1_done.tag
fi
echo $(date +"%Y-%m-%d %H:%M:%S")

#######step1.2##########
#query
echo "get reads overlap"
if [ ! -f "step1.2_done.tag" ]; then
    if [ "$zip" == "yes" ]; then
        echo "${minimap2} ${ava_arg} -t ${threads} ${orig_reads} ${orig_reads}  2>ovlp.log |gzip -1 ${prefix}.ovlp.paf.gz"
        ${minimap2} ${ava_arg} -t ${threads} ${orig_reads} ${orig_reads} 2>ovlp.log | gzip -1 ${prefix}.ovlp.paf.gz
    else
        echo "${minimap2} ${ava_arg} -t ${threads} ${orig_reads} ${orig_reads} >${prefix}.ovlp.paf 2>ovlp.log"
        ${minimap2} ${ava_arg} -t ${threads} ${orig_reads} ${orig_reads} >${prefix}.ovlp.paf 2>ovlp.log
    fi

    if [ $? -ne 0 ]; then
        echo "overlap process error"
        exit 1
    else
        echo "get reads overlap complete" >step1.2_done.tag
    fi
fi
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
    else
        echo "step2.1 complete" >step2.1_done.tag
    fi
fi
echo $(date +"%Y-%m-%d %H:%M:%S")

#######step2.2#########
if [ ! -f "step2.2_done.tag" ]; then
    python $(dirname "$(readlink -f "$0")")/mask.py ${orig_fasta} ${mask_length}
    suffix=$(echo $orig_reads | awk -F'.' '{print $NF}')
    if [ "$mask_length" -ne 0 ]; then
        ${minimap2} ${map_arg} -t ${threads} ${orig_fasta}_masked ${orig_reads} >${prefix}_useless_map.paf 2>useless_map.log
        awk -v mapq=$MapQ -v al=$aligned_length '{if ($12>mapq && $10>al) print $1}' ${prefix}_useless_map.paf | sort | uniq >filtered_reads.txt
        seqkit grep -v -f filtered_reads.txt $orig_reads >${prefix}_useful.reads.${suffix}
        # ${minimap2} ${ava_arg} -t ${threads} ${prefix}_useful.hifi.${suffix} ${prefix}_useful.hifi.${suffix} >${prefix}.ovlp.paf 2>ovlp.log
        # awk '{print $1}' ${prefix}_no_use_map.paf |sort |uniq >remove_reads.txt
        if [ "$zip" == "yes" ]; then
            zcat ${prefix}.ovlp.paf.gz | grep -vFf filtered_reads.txt | cut -f1-12 >${prefix}.ovlp.sim.paf
        else
            grep -vFf filtered_reads.txt ${prefix}.ovlp.paf | cut -f1-12 >${prefix}.ovlp.sim.paf
        fi
        if [ $? -ne 0 ]; then
            echo "reduce overlap alignments process error"
            exit 1
        fi
    else
        cut -f1-12 ${prefix}.ovlp.paf >${prefix}.ovlp.sim.paf
    fi
    if [ $? -ne 0 ]; then
        echo "step2.2 process error"
        exit 1
    else
        echo "step2.2 complete" >step2.2_done.tag
    fi
fi
echo $(date +"%Y-%m-%d %H:%M:%S")

#######step2.3##########
if [ ! -f "step2.3_done.tag" ]; then

    if [ "$filter" == "yes" ]; then
        python $(dirname "$(readlink -f "$0")")/dynamic_programming.py ${prefix}.ovlp.sim.paf ${prefix}.ovlp.filter.paf
        mv ${prefix}.ovlp.filter.paf ${prefix}.ovlp.sim.paf
        if [ $? -ne 0 ]; then
            echo "filter overlap process error"
            exit 1
        fi
    else
        awk '!($1 == $5)' ${prefix}.ovlp.sim.paf >${prefix}.ovlp.filter.paf
        mv ${prefix}.ovlp.filter.paf ${prefix}.ovlp.sim.paf
    fi
    if [ $? -ne 0 ]; then
        echo "step2.3 process error"
        exit 1
    else
        echo "step2.3 complete" >step2.3_done.tag
    fi
fi
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
    else
        echo "step3.1 complete" >step3.1_done.tag
    fi
fi
echo $(date +"%Y-%m-%d %H:%M:%S")

#######step3.2##########
if [ ! -f "step3.2.1_done.tag" ]; then
    ${rafilter} build -o ./ -r ${orig_fasta} -q ${orig_reads} ${prefix}.kmers.dump
    if [ $? -ne 0 ]; then
        echo "rafilter build process error"
        exit 1
    else
        echo "step3.2.1 complete" >step3.2.1_done.tag
    fi
fi

if [ ! -f "step3.2.2_done.tag" ]; then
    ${rafilter} filter -o ref_result -t ${threads} ref.pos query.pos ${prefix}.map.sim.paf &>ref.filter.log
    if [ $? -ne 0 ]; then
        echo "rafilter filter map process error"
        exit 1
    else
        echo "step3.2.2 complete" >step3.2.2_done.tag
    fi
fi

if [ ! -f "step3.2.3_done.tag" ]; then
    ${rafilter} filter -o qry_result -t ${threads} query.pos query.pos ${prefix}.ovlp.sim.paf &>qry.filter.log
    if [ $? -ne 0 ]; then
        echo "rafilter filter overlap process error"
        exit 1
    else
        echo "step3.2.3 complete" >step3.2.3_done.tag
    fi
fi
sort -k6,6 ref_result/rafiltered.paf >${prefix}.map.final.paf
sort -k6,6 qry_result/rafiltered.paf >${prefix}.ovlp.final.paf
if [ $? -ne 0 ]; then
    echo "step3.2 process error"
    exit 1
fi
echo $(date +"%Y-%m-%d %H:%M:%S")

###########4.recommand################
if [ ! -f "step4.1_done.tag" ]; then
    python $(dirname "$(readlink -f "$0")")/recommand.py ${prefix}.map.final.paf ${prefix}.map.score.txt
    if [ $? -ne 0 ]; then
        echo "step4.1 process error"
        exit 1
    else
        echo "step4.1 complete" >step4.1_done.tag
    fi
fi

if [ ! -f "step4.2_done.tag" ]; then
    python $(dirname "$(readlink -f "$0")")/recommand.py ${prefix}.ovlp.final.paf ${prefix}.ovlp.score.txt
    if [ $? -ne 0 ]; then
        echo "step4.2 process error"
        exit 1
    else
        echo "step4.2 complete" >step4.2_done.tag
    fi
fi
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
echo $(date +"%Y-%m-%d %H:%M:%S")

##########6.make workdir##############
suffix=$(echo $orig_reads | awk -F'.' '{print $NF}')
chr_fa=$(realpath ${orig_fasta})
mkdir -p ${prefix}_workdir && cd ${prefix}_workdir
ln -sf ${chr_fa} ./${prefix}.chr.fa
ln -sf ../*infor.txt ./${prefix}.chr.fa.infor.txt
ln -sf ../max_reads.txt .
ln -sf ../*.final.paf* .
ln -sf ../*.score.txt* .
if [ "$mask_length" -ne 0 ]; then
    ln -sf ../${prefix}_useful.reads.${suffix} .
else
    ln -sf ../${orig_fasta} ./${prefix}.reads.${suffix}
fi
cd ..
echo $(date +"%Y-%m-%d %H:%M:%S")

###########7.clean tmp################
rm -rf ref_result qry_result ${prefix}.map.paf ${prefix}.map.sim.paf ${prefix}.ovlp.paf ${prefix}.ovlp.sim.paf ${prefix}.kmers.count ${prefix}.kmers.dump ref.pos query.pos

echo "Done"
echo $(date +"%Y-%m-%d %H:%M:%S")
