import sys
import os 

fa=sys.argv[1]
mask_length=int(sys.argv[2])

# mask_length=500000

def mask(fa,length):
    file_name = os.path.basename(fa)
    with open(fa,"r") as f,open(file_name+".infor.txt","w") as fw:
        name=None
        seqs=[]
        for line in f:
            if line[0]=='>':
                if name is not None:
                    gap = []
                    start = None
                    seq="".join(seqs)
                    del seqs
                    seq_len=len(seq)
                    for i in range(seq_len):
                        if seq[i] == 'N' or seq[i] == 'n':
                            if start is None:
                                start = i
                        elif start is not None:
                                fw.write(f"{name}\t{start}\t{i}\t{i-start}\n")
                                gap.append((start, i))
                                start = None
                    if start is not None:
                        fw.write(f"{name}\t{start}\t{seq_len-1}\t{seq_len-1-start}\n")
                        gap.append((start, seq_len-1))
                    if length>0:
                        fo=open(file_name+"_masked","w")
                        seqs=[]
                        pre_start=0
                        for s, e in gap:
                            gap_start = max(0, s - length)
                            gap_end = min(seq_len, e + length)
                            seqs.append(seq[pre_start:gap_start] )
                            seqs.append('N' * (gap_end - gap_start))
                            pre_start=gap_end
                        seqs.append(seq[pre_start:])
                        fo.write(">"+name+"\n")
                        fo.write("".join(seqs))
                        fo.write("\n")                    
                    seqs=[]
                name=line.strip().split()[0][1:]
            else:
                seqs.append(line.strip())
        gap = []
        start = None
        seq="".join(seqs)
        seq_len=len(seq)
        for i in range(seq_len):
            if seq[i] == 'N' or seq[i] == 'n':
                if start is None:
                    start = i
            elif start is not None:
                    fw.write(f"{name}\t{start}\t{i}\t{i-start}\n")
                    gap.append((start, i))
                    start = None
        if start is not None:
            fw.write(f"{name}\t{start}\t{seq_len-1}\t{seq_len-1-start}\n")
            gap.append((start, seq_len-1))
        if length>0:
            seqs=[]
            pre_start=0
            for s, e in gap:
                gap_start = max(0, s - length)
                gap_end = min(seq_len, e + length)
                seqs.append(seq[pre_start:gap_start] )
                seqs.append('N' * (gap_end - gap_start))
                pre_start=gap_end
            seqs.append(seq[pre_start:])
            fo.write(">"+name+"\n")
            fo.write("".join(seqs))
            fo.write("\n")  
            fo.close()

if __name__=='__main__':
    mask(fa,length=mask_length)
   