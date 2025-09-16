#!/usr/bin/env python

# Heuristic BFS

import sys
import pickle
from collections import defaultdict
import networkx as nx
import numpy as np
import argparse
# input{gap_position,map_file,map_socre,ovlp_socre}
# output{path or none}
parser = argparse.ArgumentParser(description='Automatic path finding.')
# optional
parser.add_argument('-p', '--prefix', type=str, metavar='', default="gap-aid",
                    help='The prefix of generated file. default: gap-aid')
parser.add_argument('-n', '--number', type=int, metavar='', default=5,
                    help='The number of nodes selected in each iteration. default: 5')
parser.add_argument('-i', '--iteration', type=int, metavar='', default=100,
                    help='The iteration number you want to find. default: 100')


# gap_position = sys.argv[1]
# map_file = sys.argv[2]
# map_score = sys.argv[3]
# ovlp_score = sys.argv[4]

parser.add_argument('gap_position', help='gap_position file.')
parser.add_argument('map_file', help='reads map chrosomes paf file.')
parser.add_argument('map_score', help='reads map chrosomes score file.')
parser.add_argument('ovlp_score', help='reads overlap score file.')

args = parser.parse_args()


class Graph(nx.Graph):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def load_shore(self, gap_pos, map_file):
        self.gap = defaultdict(list)
        with open(gap_pos, "r") as f:
            for line in f:
                line = line.split()
                if len(line) > 3:
                    self.gap[line[0]].append((int(line[1]), int(line[2])))
            for k, v in self.gap.items():
                v = sorted(v, key=lambda x: x[0])
                self.gap[k] = v
        with open(f'{map_file}.idx', "rb") as f:
            index = pickle.load(f)
        with open(map_file, "r") as f:
            for key, pos in self.gap.items():
                f.seek(index[key])
                min_start = min(pos, key=lambda x: x[0])[0]
                max_end = max(pos, key=lambda x: x[1])[1]
                line = f.readline()
                while line:
                    cols = line.strip().split()
                    if cols[5] == key:  # and int(cols[-1]) >1 :
                        if (int(cols[8]) < min_start - 50000) or (int(cols[7]) > max_end + 50000):
                            line = f.readline()
                            continue
                        for start, end in pos:
                            self.add_node(f"{key}_{start}_left", visit=0)
                            self.add_node(f"{key}_{start}_right", visit=0)
                            if int(cols[7]) < start and int(cols[8]) > end:
                                break
                            if start > int(cols[8]):
                                sub = start-int(cols[8])
                                if (int(cols[1])-int(cols[3])) > sub and cols[4] == "+":
                                    self.add_node(cols[0], visit=0)
                                    self.add_edge(
                                        f"{key}_{start}_left", cols[0], strand1='+', strand2=cols[4], weight=0)
                                elif int(cols[2]) > sub and cols[4] == "-":
                                    self.add_node(cols[0], visit=0)
                                    self.add_edge(
                                        f"{key}_{start}_left", cols[0], strand1='+', strand2=cols[4], weight=0)
                            elif int(cols[7]) > end:
                                sub = int(cols[7])-end
                                if int(cols[2]) > sub and cols[4] == "+":
                                    self.add_node(cols[0], visit=0)
                                    self.add_edge(
                                        cols[0], f"{key}_{start}_right", strand1=cols[4], strand2='+', weight=0)
                                elif (int(cols[1])-int(cols[3])) > sub and cols[4] == "-":
                                    self.add_node(cols[0], visit=0)
                                    self.add_edge(
                                        cols[0], f"{key}_{start}_right", strand1=cols[4], strand2='+', weight=0)
                        line = f.readline()
                    else:
                        break

    def load_graph(self, mapfile, ovlpfile):
        t1, t2, t3, t4, t5=[ 0.00000045, -0.05826849  ,0.00302898,  0.00000076 , 0.00008379] #[0.00000017 ,0.01682598, 0.01126028, 0.00000076 ,0.00004658] 
        b=0.04249713008044001#-0.012557160480121832
        # 0:qname 1:rname 2:strand 3:conflict_score 4:max_aln_ratio 5:non_conflict_ratio 6:non_conflict_len 7:match_bases
        with open(mapfile, "r") as f:
            for line in f:
                id1, id2, dir, v1, v2, v3, v4, v5 = line.strip().split()
                if id1 in self.nodes:
                    connected_points = set(self.neighbors(id1))
                    for node in connected_points:
                        if id2 in node:
                            w=int(v1)*t1+float(v2)*t2+float(v3)*t3+int(v4)*t4+int(v5)*t5+b
                            self[id1][node]["weight"] = max(0,w)
        with open(ovlpfile, "r") as f:
            for line in f:
                id1, id2, dir, v1, v2, v3, v4, v5 = line.strip().split()
                w=int(v1)*t1+float(v2)*t2+float(v3)*t3+int(v4)*t4+int(v5)*t5+b
                w=max(0,w)
                if self.has_edge(id1,id2):
                    if w> self[id1][id2]["weight"]:
                        self[id1][id2]['strand1']=dir
                        self[id1][id2]['strand2']='+'
                        self[id1][id2]["weight"] = w
                else:
                    self.add_node(id1, visit=0)
                    self.add_node(id2, visit=0)
                    self.add_edge(id1, id2, strand1=dir, strand2='+',
                                weight=w)

    def weighted_random_sample(self, items, weights, k):
        if k > len(items):
            return items
        if np.sum(weights)<=0:
            sampled_indices = np.random.choice(
            len(items), size=k, replace=False)
        else:
            probabilities = np.array(weights) / np.sum(weights)
            try:
                sampled_indices = np.random.choice(
                len(items), size=k, replace=False, p=probabilities)
            except ValueError:
                print("error")
                exit(-1)
        return [items[i] for i in sampled_indices]

    def Heuristic_BFS(self, select_num=5, iteration=100):
        # print(select_num,iteration)
        fo=open(f"{prefix}_auto_path.txt","w")
        for key, pos in self.gap.items():
            for s,e in pos:
                paths = []
                current_node = f"{key}_{s}_left"
                next_edges = self.edges(current_node)
                weights = [self.edges[edge]["weight"] for edge in next_edges]
                if select_num == 0:
                    chosen = next_edges
                else:

                    chosen = self.weighted_random_sample(
                        list(next_edges), weights=weights, k=select_num)
                for node1, node2 in chosen:
                    paths.append([node1, node2])
                while (iteration > 0 or iteration == -1) and len(paths) > 0:
                    next_edges = []
                    weights = []
                    for path in paths:
                        temp = set(self.edges(path[-1]))  # -visit_edges
                        for edge in temp:
                            if edge[1] not in set(path) and edge not in set(next_edges):
                                weights.append(self.edges[edge]["weight"])
                                next_edges.append(edge)

                    if select_num == 0:
                        chosen = next_edges
                    else:
                        chosen = self.weighted_random_sample(
                            next_edges, weights=weights, k=select_num)
                    temp_paths = []
                    for path in paths:
                        for node1, node2 in chosen:
                            if path[-1] == node1:
                                if "right" in node2:
                                    fo.write(key+"\t"+str(s)+"\t")
                                    fo.write("\t".join(path[1:]))
                                    fo.write("\n")
                                    continue
                                new_path = list(path)
                                new_path.append(node2)
                                temp_paths.append(new_path)
                    paths = temp_paths
                    if iteration == -1:
                        continue
                    iteration -= 1
        fo.close()

my_graph = Graph()

prefix=args.prefix
select_num = args.number
iteration = args.iteration

gap_position = args.gap_position
map_file = args.map_file
map_score = args.map_score
ovlp_score = args.ovlp_score


my_graph.load_shore(gap_position, map_file)

my_graph.load_graph(map_score, ovlp_score)
# print(my_graph.edges())
my_graph.Heuristic_BFS(select_num, iteration)
