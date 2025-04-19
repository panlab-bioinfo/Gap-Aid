# Gap-Aid

Gap-Aid provides an interactive visualization tool for displaying the alignments between long reads and genomic regions of gaps. Upon user selection of alignment information, Gap-Aid automatically presents the next round of alignments, progressively constructing the assembly path to complete the gap-filling process. 


## Installation




1.Windows

Download Gap-Aid-v2.0.exe from [Releases](https://github.com/panlab-bioinfo/Gap-Aid/releases) then execute

2.Mac

Download Gap-Aid-v2.0.pkg from [Releases](https://github.com/panlab-bioinfo/Gap-Aid/releases) then execute

3.Linux
Download Gap-Aid-v2.0.tar.gz from [Releases](https://github.com/panlab-bioinfo/Gap-Aid/releases)
```
tar -zxvf Gap-Aid-v2.0.tar.gz
cd Gap-Aid
chmod +x Gap-Aid
./Gap-Aid
```

<details>
<summary><b>Run from source</b></summary>

    git clone https://github.com/panlab-bioinfo/Gap-Aid.git
    cd Gap-Aid
    conda create -f environment.yml
    conda activate gapaid
    chmod +x Gap-Aid.py
    ./Gap-Aid.py

</details>


## Preprocessing

The preprocess program  can only be used on Linux systems

### Prerequisites

* python>=3.8
* minimap2 https://github.com/lh3/minimap2.git
* seqkit https://github.com/shenwei356/seqkit.git
* jellyfish https://github.com/gmarcais/Jellyfish.git
* rafilter https://github.com/panlab-bioinfo/RAfilter
* hifiasm(optional) https://github.com/chhylp123/hifiasm


### Usage Details
```bash
cd Gap-Aid/preprocess/pipeline.sh
chmod + x pipeline.sh
```

Run pipeline.sh with full paths or add pipeline.sh to environment PATH

```bash  
version 240720

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
-re|--reliable      The alignment you think are reliable ,format:'MapQ aligned_ratio'.(default:'10 0.6')
-l|--length         The Alignment block length you think are unreliable.(default:500)
-f|--filter         Do you want to filter the alignment? yes/no (default:no)
-z|--zip            Do you want to compressed the alignment file with gzip ? yes/no (default:no)
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
```
#### Input file format
The raw reads file must be fatsa format,any compressed files are not supported

#### Parameter Description
|Short Parameter  |  Long Parameter |  Description|
|--------|------------------|-----------------------|
|-p |   --prefix  　 | The prefix of output files.  |
|-r |  --reads_type 　　　 | The reads type.  You can choose hifi or ont. (default:hifi)  |
|-m |  --mask 　　　 | To avoid the influence of repeated sequences near the gap, you can choose to mask the sequences before and after the gap. The default length is 500k  |
|-c |  --contig　　　  | Contigs used to assemble scaffolds to obtain more comprehensive kmer information  |
|-re | --reliable 　 | Use alignment length and alignment quality to filter alignments. By default, alignments with mapq>10 and alignment ratio(alignment ratio=Alignment block length / reads sequence length) greater than 0.6 are considered high-quality alignments. In non-gap regions, the reads corresponding to such alignments will be filtered out.  |
|-l |--length | The Alignment block length you think are unreliable.(default:500)By default, alignments with alignment block length less than 500bp will be discarded.
|-f |  --filter　   | Do you want to filter the conflict alignments? (yes or no default:no ) This will use a dynamic programming algorithm to remove some of the conflicting alignments, which has a high memory requirement |
|-z |  --zip　   | Do you want to compressed the alignment file with gzip ? This will make the file smaller but will take more time.(yes or no default:no ) |


#### Output file description
The files needed by Gap-aid are in the $prefix_workdir

There are 12 files.

*.chr.fa is the scaffold that your input

*reads.\* is filtered reads

*infor.txt is the scaffold gap information

*map.final.paf\* is the alignments of scaffold and reads

*ovlp.final.paf\* is the alignments of reads and reads

*.score.txt\* is the score we use to recommend the reads
### Using overlaps and corrected reads generated by hifiasm. (testing)
If you have run hifiasm, you can run the following commands to generate the corrected reads and overlaps.

```
hifiasm -o you_prefix -t 32 --write-paf --write-ec /dev/null
```
You can also see https://github.com/chhylp123/hifiasm

If you haven't run hifiasm, the following script will run hifiasm first. Make sure you have installed hifiasm. 

Then you can run the script in preprocesss.
```
cd Gap-Aid/preprocess/
chmod + x pipeline_hifiasm.sh
```
```
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
```



### filter output file
This will use stricter parameters to filter the alignment files, which may filter out reads in the gap regions. If the file is not particularly large, it is not recommended to use this scrtpt.
```
cd Gap-Aid/preprocess/
chmod + x filter.sh
./filter.sh [options]  <useless_map.paf>  <path_to_workdir>
```
```bash  
*****************************************************
version 250102

USAGE: ./filter.sh [options]  <useless_map.paf>  <path_to_workdir>

DESCRIPTION:
This is a script that maps reads to draft assemblies and get the overlaps of reads

ARGUMENTS:
path_to_paf       Specify path to <prefix>_useless_map.paf generated by pipeline.sh.
path_to_workdir   Specify path to <prefix>_workdir generated by pipeline.sh.(e.g.,gap-aid_workdir)

OPTIONS:
-p|--prefix         The prefix of output. (default:gap-aid-filter)
-re|--reliable      The alignment you think are reliable ,format:'MapQ aligned_ratio'.(default:'0 0.5')
-l|--length         The Alignment block length you think are unreliable.(default:1000)
-t|--threads        Number of threads(default:4)
-h|--help           Shows this help. Type --help for a full set of options.
*****************************************************
*****************************************************
```


### Using Gap-Aid

*example.tar.gz* is an example for Gap-Aid, it applies to visualization programs, not to preprocessing programs.

usage:
```
tar -zxvf example.tar.gz
#Select the example directory in the Gap-Aid
```


<!--*Gap-Aid-v2.0.exe* is a binary program under Windows.-->

*Gap-Aid-v2.0.pkg* is a binary program under Mac.