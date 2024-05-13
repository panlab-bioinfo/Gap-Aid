from collections import defaultdict
import sys

index_shift = 100

paf_path = sys.argv[1]
output_path = sys.argv[2]

PAF = {}
PAF_original = []
length = defaultdict(int)
count = 0
with open(paf_path) as file:
    for line in file:
        line = line.strip().split()
        if(line[0] not in PAF):
            PAF[line[0]] = {}
        if(line[5] not in PAF[line[0]]):
            PAF[line[0]][line[5]] = {}
        if(line[4] not in PAF[line[0]][line[5]]):
            PAF[line[0]][line[5]][line[4]] = []
        PAF[line[0]][line[5]][line[4]].append([int(line[1]), int(line[2]), int(line[3]), int(line[7]), int(line[8]), count])
        length[line[5]] = int(line[6])
        count += 1

"""for qry in PAF.keys():
    for ref in PAF[qry].keys():
        for strand in PAF[qry][ref].keys():
            print(qry,ref,strand,PAF[qry][ref][strand])"""

available_PAF = {}
practical = set()
for qry in PAF.keys():
    for ref in PAF[qry].keys():
        for strand,infos in PAF[qry][ref].items():
            flag = [0] * len(infos)
            for i,info1 in enumerate(infos):
                for j,info2 in enumerate(infos):
                    if(i != j and max(info1[3] - info1[1],info2[3] - info2[1]) <= min(info1[4] + info1[0] - info1[2] - 1,info2[4] + info2[0] - info2[2] - 1)): #  and (not (info1[1] == info2[1] and info1[2] == info2[2]))
                        flag[i] = 1
                        flag[j] = 1
            if(any(flag)):
                if(qry not in available_PAF):
                    available_PAF[qry] = {}
                if(ref not in available_PAF[qry]):
                    available_PAF[qry][ref] = {}
                if(strand not in available_PAF[qry][ref]):
                    available_PAF[qry][ref][strand] = []
                for i,info in enumerate(infos):
                    if(flag[i]):
                        available_PAF[qry][ref][strand].append(info)
                        practical.add(info[-1])


available = set()
for qry in available_PAF.keys():
    # print(qry)
    for ref in available_PAF[qry].keys():
        # print(ref)
        for strand,infos in available_PAF[qry][ref].items():
            qry_id = {}
            ref_id = {}
            ref_id_reverse = {}
            intervals = []
            min_index = -1
            max_index = -1
            # print(strand)
            length = infos[0][0]
            if(strand == "+"):
                info_sorted = sorted(infos,key = lambda info : int(info[1]))
                min_index = min([info[3] - info[1] for info in info_sorted]) - index_shift
                max_index = max([info[4] + info[0] - info[2] - 1 for info in info_sorted]) + index_shift
                id = 0
                count = 0
                for info in info_sorted:
                    lower = info[3] - info[1]
                    upper = max(info[4] + info[0] - info[2] - 1,lower + length - 1)
                    if(str(info[1]) + " " + str(info[2]) in qry_id):
                        id = qry_id[str(info[1]) + " " + str(info[2])]
                    else:
                        id = count
                        count += 1
                    # qry_id[str(info[1]) + " " + str(info[2])] = id
                    ref_id[str(info[3]) + " " + str(info[4])] = [id,lower,upper]
                    ref_id_reverse[id] = info
                    # print(info[0],info[1],info[2],info[3],info[4])
            else:
                info_sorted = sorted(infos,key = lambda info : int(info[2]),reverse = True)
                min_index = min([info[3] - (info[0] - info[2] - 1) for info in info_sorted]) - index_shift
                max_index = max([info[4] + info[1] for info in info_sorted]) + index_shift
                id = 0
                count = 0
                for info in info_sorted:
                    lower = info[3] - (info[0] - info[2] - 1)
                    upper = max(info[4] + info[1],lower + length - 1)
                    if(str(info[1]) + " " + str(info[2]) in qry_id):
                        id = qry_id[str(info[1]) + " " + str(info[2])]
                    else:
                        id = count
                        count += 1
                    # qry_id[str(info[1]) + " " + str(info[2])] = id
                    ref_id[str(info[3]) + " " + str(info[4])] = [id,lower,upper]
                    ref_id_reverse[id] = info
                    # print(info[0],info[1],info[2],info[3],info[4])
            zipped = list(zip(*sorted(ref_id.items(),key = lambda item : int(item[0].split()[0]))))
            intervals = zipped[0]
            ids = list(zip(*zipped[1]))[0]
            """for key,value in sorted(ref_id.items(),key = lambda item : int(item[0].split()[0])):
                print(key,value)"""
            results = {}
            for index_start in range(len(ids)):
                ref_start = ref_id[intervals[index_start]][1]
                ref_end = ref_id[intervals[index_start]][2]
                index_end = index_start
                for index,interval in enumerate(intervals[index_start + 1 :]):
                    interval = interval.split()
                    interval_start = int(interval[0])
                    interval_end = int(interval[1])
                    if(interval_start <= ref_end):
                        index_end = index + index_start + 1
                    elif(ref_end < interval_start):
                        break
                local_ids = ids[index_start : index_end + 1]
                dp = [1] * len(local_ids)
                backtrack = [-1] * len(local_ids)
                for i in range(1,len(local_ids)):
                    for j in range(i):
                        if(local_ids[j] <= local_ids[i]):
                            if(dp[j] + 1 > dp[i]):
                                backtrack[i] = j                            
                            dp[i] = max(dp[i],dp[j] + 1)
                # print(ref_start,ref_end)
                # print("local_ids",local_ids)
                # print("dp",dp)
                # print("backtrack",backtrack)
                result = []
                index = dp.index(max(dp))
                while(index != -1):
                    result.append(ref_id_reverse[local_ids[index]])
                    index = backtrack[index]
                result.reverse()
                results[str(ref_start) + " " + str(ref_end)] = [max(dp),result]
            max_dp = sorted(results.values(), key = lambda value : value[0], reverse = True)[0][0]
            # print(sorted(results.values(), key = lambda value : value[0], reverse = True))
            for value in sorted(results.values(), key = lambda value : value[0], reverse = True):
                if(value[0] == max_dp):
                    for info in value[1]:
                        # print(info)
                        available.add(info[-1])
                else:
                    break
# print(len(practical))
# print(len(available))
# print(len(practical & available))


writer = open(output_path,"w")
count = 0
with open(paf_path) as file:
    for line in file:
        line = line.strip()
        cols=line.split()
        if(count not in practical and cols[0] != cols[5]):
            print(line,file = writer)
        elif(count in available and cols[0] != cols[5]):
            print(line,file = writer)
        count += 1
writer.close()