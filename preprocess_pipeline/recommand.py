#!/usr/bin/env python
import sys
import random
from collections import defaultdict

aln="/data/zhaoxianjia/project/t2t/test/reads-chr.map.final.paf"
olp="/data/zhaoxianjia/project/t2t/test/reads-reads.olp.final.paf"

def str_to_int(s):
    try:
        return int(s)
    except ValueError:
        return s

class recommend():
    def __init__(self,path) -> None:
        self.path=path
        self.paf=defaultdict(list)

    def load_map(self):
        with open(self.path) as f:
            for line in f:
                cols=line.strip().split()
                cols=list(map(str_to_int,cols))
                self.paf[(cols[0],cols[5])].append(cols[:11])

    def load_ovlp(self):
        #0:qname 1:qlen 2:qstart 3:qend 4:strand 5:rname 6:rlen 7:rstart 8:rend 9:match 10:aligned 11:mapq
        with open(self.path) as f:
            for line in f:
                cols=line.strip().split()
                cols=list(map(str_to_int,cols))
                # a[0:2], a[3:5] = a[3:5], a[0:2]
                if cols[0] > cols[5]:
                    cols[0:4],cols[5:9]=cols[5:9],cols[0:4]
                self.paf[(cols[0],cols[5])].append(cols[:11])
    
    def merge_alignment(self,aln_list):
        new_aln_list=[]
        new_aln_list.append(aln_list[0])
        for i in range(1,len(aln_list)):
            no_merge=True
            for j in range(len(new_aln_list)-1,-1,-1):
                # print(new_aln_list[j],aln_list[i])
                if  ((new_aln_list[j][2]-aln_list[i][2]>=0 and new_aln_list[j][7]-aln_list[i][7]>=0) or (new_aln_list[j][2]-aln_list[i][2]<=0 and new_aln_list[j][7]-aln_list[i][7]<=0)) \
                    and new_aln_list[j][3]-aln_list[i][2] >500 \
                    and new_aln_list[j][8]-aln_list[i][7] >500 :
                    new_qstart,new_qend=min(new_aln_list[j][2],aln_list[i][2]),max(new_aln_list[j][3],aln_list[i][3])
                    new_rstart,new_rend=min(new_aln_list[j][7],aln_list[i][7]),max(new_aln_list[j][8],aln_list[i][8])
                    average_list = [int((x + y) / 2) for x, y in zip(new_aln_list[j][11:], aln_list[i][11:])]
                    aligned=max(new_qend-new_qstart,new_rend-new_rstart)
                    ratio=(new_aln_list[j][9]/new_aln_list[j][10]+aln_list[i][9]/aln_list[i][10])/2
                    new_aln_list[j] = new_aln_list[j][0:2]+[new_qstart,new_qend]+new_aln_list[j][4:7] \
                                    + [new_rstart,new_rend,int(aligned*ratio),aligned]\
                                    + average_list
                    no_merge=False
                    break
            if no_merge:
                    new_aln_list.append(aln_list[i])
        return sorted(new_aln_list,key=lambda x:(x[7],x[2]))

    def cal_conflict_score(self,aln_list):
        conflict_score=0
        if len(aln_list)==1:
            return conflict_score
        for i in range(len(aln_list)-1):
            pre=aln_list[i]
            pre_qry_len,pre_ref_len=pre[3]-pre[2],pre[8]-pre[7]
            pre_sample_num=max(int(pre_ref_len/500),1)
            pre_ref_point=random.sample(range(pre[7],pre[8]),pre_sample_num)
            pre_ref_point.sort()
            pre_qry_point=[pre[2]+int(pre_qry_len*(item-pre[7])/pre_ref_len) for item in pre_ref_point]
            for j in range(i+1,len(aln_list)):
                cur=aln_list[j] 
                cur_qry_len,cur_ref_len=cur[3]-cur[2],cur[8]-cur[7]
                cur_sample_num=max(int(cur_ref_len/500),1)
                cur_ref_point=random.sample(range(cur[7],cur[8]),cur_sample_num)
                cur_ref_point.sort()
                cur_qry_point=[cur[2]+int(cur_qry_len*(item-cur[7])/cur_ref_len) for item in cur_ref_point]
                ref_differ,qry_differ=0,0
                for i in range(len(pre_ref_point)):
                    for j in range(len(cur_ref_point)):
                        ref_differ += pre_ref_point[i] - cur_ref_point[j]
                        qry_differ += pre_qry_point[i] - cur_qry_point[j]
                differ = abs(ref_differ - qry_differ)
                conflict_score += int(differ/(cur_sample_num*pre_sample_num))
        return conflict_score
    

    def cal_aligned_score(self,aln_list):
        if len(aln_list)==1:
            block=min(aln_list[0][2],aln_list[0][7])+aln_list[0][10]+min(aln_list[0][1]-aln_list[0][3],aln_list[0][6]-aln_list[0][8])
            max_aln_ratio=aln_list[0][10]/block
            non_conflict_ratio=max_aln_ratio
            non_conflict_len=aln_list[0][10]
            match_bases=aln_list[0][9]
        else:
            max_aln=max(aln_list,key=lambda x:x[10])
            block=min(max_aln[2],max_aln[7])+max_aln[10]+min(max_aln[1]-max_aln[3],max_aln[6]-max_aln[8])
            max_aln_ratio=max_aln[10]/block
            non_conflict_len=max_aln[10]
            qs,qe,rs,re=max_aln[2],max_aln[3],max_aln[7],max_aln[8]
            match_bases=max_aln[9]
            for item in aln_list:
                if (item[3]<qs and item[8]<rs) or (item[2]>qe and item[7]>re):
                    qs,qe=min(item[2],qs),max(item[3],qe)
                    rs,re=min(item[7],qs),max(item[8],qe)
                    if (item[2]-max_aln[3] > 0 and item[7]-max_aln[8] > 0) and abs((item[2]-max_aln[3])-(item[7]-max_aln[8])) < min((item[2]-max_aln[3]),(item[7]-max_aln[8])):
                        non_conflict_len += item[10]
                        match_bases += item[9]
                    elif (item[3]-max_aln[2] < 0 and item[8]-max_aln[7] < 0) and abs((max_aln[2]-item[3])-(max_aln[7]-item[8])) < min((max_aln[2]-item[3]),(max_aln[7]-item[8])):
                        non_conflict_len += item[10]
                        match_bases += item[9]
            non_conflict_ratio=non_conflict_len/block
            # non_conflict_percentage=non_conflict_len/max_aln[1]
        max_aln_ratio = round(max_aln_ratio, 4)
        non_conflict_ratio = round(non_conflict_ratio, 4)
        # non_conflict_percentage = round(non_conflict_percentage, 4)
        return max_aln_ratio,non_conflict_ratio,non_conflict_len,match_bases
    
    
    def calculating_recommended_scores(self,out):
        fw=open(out,"w")
        for k,v in self.paf.items():
            for strand in ['+','-']:
                cur_aln=[item for item in v if item[4] == strand]
                aln_num=len(cur_aln)
                if aln_num > 0:
                    tmp=sorted(cur_aln,key=lambda x:(x[7],x[2]))
                    if aln_num > 1:
                        tmp=self.merge_alignment(tmp)
                    conflict_score=self.cal_conflict_score(tmp)
                    max_aln_ratio,non_conflict_ratio,non_conflict_len,match_bases=self.cal_aligned_score(tmp)
                    print(*k, strand, conflict_score, max_aln_ratio, non_conflict_ratio, non_conflict_len, match_bases, sep="\t", file=fw)


if __name__ == "__main__":
    input=sys.argv[1]
    out=sys.argv[2]
    res=recommend(input)
    if  input.endswith("map.final.paf" ):
        res.load_map()
    elif input.endswith("ovlp.final.paf"):
        res.load_ovlp()
    else:
        print("input file error")
        exit(-1)
    res.calculating_recommended_scores(out)