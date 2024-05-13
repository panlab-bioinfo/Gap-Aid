'''
LastEditTime: 2022-12-05 18:45:52
Description: 
'''
import sys 
import pickle
from collections import defaultdict
# path=sys.argv[1]


def build_index_for_map(path):
    pos_dict=defaultdict(int)
    with open(path,"r") as f:
        pre_pos=f.tell()
        name="-"
        line=f.readline()
        while line:
            cur_name=line.split()[5]
            if name!=cur_name:
                name=cur_name
                pos_dict[name]=pre_pos
            pre_pos=f.tell()
            line=f.readline()
    with open(path+".idx","wb") as f:
        pickle.dump(pos_dict,f)

def build_index_for_ovlp(path):
    pos_dict=defaultdict(list)
    with open(path,"r") as f:
        pre_pos=f.tell()
        qname,rname="-","-"
        line=f.readline()
        while line:
            cols=line.split()
            cur_q_name,cur_r_name=cols[0],cols[5]
            if qname!=cur_q_name:
                qname=cur_q_name
                pos_dict[qname].append(pre_pos)
            if rname!=cur_r_name:
                rname=cur_r_name
                pos_dict[rname].append(pre_pos)
            pre_pos=f.tell()
            line=f.readline()
    with open(path+".idx","wb") as f:
        pickle.dump(pos_dict,f)
def build_index_for_ovlp_score(path):
    pos_dict=defaultdict(list)
    with open(path,"r") as f:
        pre_pos=f.tell()
        qname,rname="-","-"
        line=f.readline()
        while line:
            cols=line.split()
            cur_q_name,cur_r_name=cols[0],cols[1]
            if qname!=cur_q_name:
                qname=cur_q_name
                pos_dict[qname].append(pre_pos)
            if rname!=cur_r_name:
                rname=cur_r_name
                pos_dict[rname].append(pre_pos)
            pre_pos=f.tell()
            line=f.readline()
    with open(path+".idx","wb") as f:
        pickle.dump(pos_dict,f)
        # for k,v in pos_dict.items():
        #     print(k,*v,sep="\t",file=f)
def build_index_for_map_score(path):
    pos_dict=defaultdict(list)
    with open(path,"r") as f:
            pre_pos=f.tell()
            name="-"
            line=f.readline()
            while line:
                cur_name=line.split()[1]
                if name!=cur_name:
                    name=cur_name
                    pos_dict[name]=pre_pos
                pre_pos=f.tell()
                line=f.readline()
    with open(path+".idx","wb") as f:
        pickle.dump(pos_dict,f)
# if __name__=="__main__":
path=sys.argv[1]
print(path)
if path.endswith("ovlp.final.paf") :
    print("indexing")
    build_index_for_ovlp(path)
    print("complete")
elif path.endswith("map.final.paf" ) :
    print("indexing")
    build_index_for_map(path)
    print("complete")
elif path.endswith("ovlp.score.txt" ) :
    print("indexing")
    build_index_for_ovlp_score(path)
    print("complete")
elif path.endswith("map.score.txt" ) :
    print("indexing")
    build_index_for_map_score(path)
    print("complete")
else:
    print("input file error")
    exit(-1)
