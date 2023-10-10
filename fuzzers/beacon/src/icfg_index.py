#!/usr/bin/env python3
# This script comes from Beacon's repository and has been cleaned up and
# modified to work with newer versions of SVF.

import argparse
import time
import logging

import networkx.drawing.nx_pydot as pdot


def find_node(G, name):
    ln = name.split(":")[1]
    file = name.split(":")[0]
    res = []
    for n, d in G.nodes(data=True):
        info = d.get("label", "")
        if len(info) > 1:
            if 'ln\\": ' + ln in info and file in info:
                print(d)
                res.insert(0, n)

    return res


def reachable_node_fast_new(G, node):
    f_trace = []
    b_trace = []

    unsolve = node.copy()
    init_func = ""

    while len(unsolve) > 0:
        cur = unsolve.pop(0)

        current = G.nodes[cur]
        # print(current)
        current["visited"] = "visited"

        neighbors = list(G.predecessors(cur))
        # print(neighbors)
        for neighbor in neighbors:
            if len(G.nodes[neighbor].get("visited", "")) == 0:
                unsolve.append(neighbor)

        ir = current.get("label", "")
        if len(ir) > 1:
            # print("ir: ")
            # print(ir)

            # Function-level reachability analysis
            pos = ir.find("Fun[")
            if pos != -1:
                # print("find!")
                end = ir.find("]", pos)
                fname = ir[pos + 4 : end]
                if len(init_func) == 0:
                    init_func = fname
                if fname not in f_trace:
                    f_trace.append(fname)
            else:
                pos = ir.find("@_")
                if pos != -1:
                    end = ir.find(",", pos)
                    fname = ir[pos + 1 : end]
                    if fname not in f_trace:
                        f_trace.append(fname)

            # Block-level reachability analysis
            ln_str = 'ln\\": '
            pos = ir.find(ln_str)
            if pos != -1:
                position = ir[pos + len(ln_str) :].split(",")
                loc = position[0]
                file_str = 'fl\\": '
                file_pos = ir.find(file_str)
                if file_pos == -1:
                    file_str = 'file\\": '
                    file_pos = ir.find(file_str)
                assert file_pos != -1
                file = ir[file_pos + len(file_str) :].split('\\"')[1]
                pure_file = file.split("/")[-1]
                bname = pure_file + ":" + loc
                if bname not in b_trace:
                    b_trace.append(bname)
            else:
                pos = ir.find("line: ")
                if pos != -1:
                    position = ir[pos:].split(" ")
                    loc = position[1]
                    file = position[3].split("/")[-1]
                    bname = file + ":" + loc
                    if bname not in b_trace:
                        b_trace.append(bname)

    return f_trace, b_trace


def pre_processing(g):
    aux_edges = {}
    # add edges for context sensitivity
    for node in g.nodes():
        # node = node.split(":")[0]
        # print(node)
        tmp = node.split(":")
        if len(tmp) > 1:
            values = aux_edges.get(tmp[0], [])
            values.append(node)
            aux_edges[tmp[0]] = values

    for key, values in aux_edges.items():
        for context in values:
            g.add_edge(key, context)
            g.add_edge(context, key)

    return g


def cli():
    parser = argparse.ArgumentParser()
    parser.add_argument("target", help="target file:line")
    parser.add_argument("icfg", help="icfg dot file")
    return parser.parse_args()


args = cli()
logging.basicConfig(filename="log-reachability", level=logging.DEBUG)

g = pdot.read_dot(args.icfg)

print("read graph")

print("======================preprpcessing=======================")
start = time.time()
g1 = pre_processing(g)
processing = time.time()
print("======================split=======================")
logging.info("processing time: " + str(processing - start))

target = find_node(g, args.target)
print(target)
logging.info(target)

locating = time.time()
print("==================split-reachable=================")
logging.info("location time: " + str(locating - processing))

f_trace, b_trace = reachable_node_fast_new(g, target)

reachability = time.time()
print("====================split-ftrace==================")
logging.info("reachability time: " + str(reachability - locating))

f_trace = sorted(set(f_trace))
print("num of fuc: " + str(len(f_trace)))

print("======split-btrace=======")
b_trace = sorted(set(b_trace))
print("num of ins: " + str(len(b_trace)))

print("======split-output=======")
with open("ftrace-external-svf.txt", "w") as f:
    for item in f_trace:
        f.write(item + "\n")

    f.close()

with open("bbreaches-external-svf.txt", "w") as f:
    for item in b_trace:
        if item == args.target:
            f.write(item + ";TARGET\n")
        else:
            f.write(item + "\n")

    f.close()

end = time.time()
print("reachability time: " + str(reachability - locating))
logging.info("overall timing: " + str(end - start))
