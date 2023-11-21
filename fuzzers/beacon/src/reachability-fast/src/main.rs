use std::collections::{HashMap, HashSet, VecDeque};
use std::io::Write;

use anyhow::{anyhow, bail, Context, Result};
use graphviz_rust::{dot_generator::*, dot_structures::*};

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: {} <target> <dotfile> [bbreaches-out]", args[0]);
        std::process::exit(1);
    }

    let target = &args[1];
    let filename = &args[2];
    let out_filename = args
        .get(3)
        .map(|s| s.as_str())
        .unwrap_or("bbreaches-external-svf.txt");

    let contents =
        std::fs::read_to_string(filename).with_context(|| format!("Cannot read {}", filename))?;

    let mut graph =
        graphviz_rust::parse(&contents).map_err(|e| anyhow!("Parsing DOT file: {}", e))?;

    add_context_edges(&mut graph);

    let mut predecessors = HashMap::new();
    let mut labels = HashMap::new();
    for stmt in get_stmts(&graph) {
        match stmt {
            Stmt::Node(Node { id, attributes }) => {
                for attr in attributes {
                    if attr.0 == Id::Plain("label".to_string()) {
                        match &attr.1 {
                            Id::Escaped(esc) => {
                                if let Some(label) = labels.insert(id, esc) {
                                    bail!(
                                        "Multiple labels for node {:?}: {:?} and {:?}",
                                        id,
                                        label,
                                        esc
                                    );
                                }
                            }
                            _ => {
                                bail!("Unhandled label for node {:?}: {:?}", id, attr.1);
                            }
                        }
                    }
                }
            }
            Stmt::Edge(Edge {
                ty: EdgeTy::Pair(Vertex::N(n1), Vertex::N(n2)),
                ..
            }) => {
                predecessors
                    .entry(n2)
                    .or_insert_with(HashSet::new)
                    .insert(n1);
            }
            _ => {}
        }
    }

    let target_nodes = find_target_nodes(target, &labels).context("Finding target nodes")?;
    for node in &target_nodes {
        println!("Target: {:?}", node);
    }

    let bbs = reachability(&target_nodes, &predecessors, &labels).context("Reachability")?;

    let mut file = std::fs::File::create(out_filename)
        .with_context(|| format!("Creating {}", out_filename))?;

    for bb in bbs {
        writeln!(file, "{}{}", bb, if &bb == target { ";TARGET" } else { "" })
            .context("Writing to bbs.txt")?;
    }

    Ok(())
}

fn get_stmts(graph: &Graph) -> &[Stmt] {
    match graph {
        Graph::DiGraph { stmts, .. } => stmts,
        Graph::Graph { stmts, .. } => stmts,
    }
}

fn add_context_edges(graph: &mut Graph) {
    let mut nodes_with_ports = HashMap::new();
    for stmt in get_stmts(graph) {
        match stmt {
            Stmt::Node(Node { id: node, .. }) => {
                if let NodeId(id, Some(_)) = node {
                    nodes_with_ports
                        .entry(id.clone())
                        .or_insert(Vec::new())
                        .push(node.clone());
                }
            }
            Stmt::Edge(Edge {
                ty: EdgeTy::Pair(Vertex::N(n), _),
                ..
            }) => {
                if let NodeId(ref id, Some(_)) = n {
                    nodes_with_ports
                        .entry(id.clone())
                        .or_insert(Vec::new())
                        .push(n.clone());
                }
            }
            _ => {}
        }
    }

    for (id, ports) in nodes_with_ports {
        for port in ports {
            graph.add_stmt(stmt!(edge!(node_id!(id) => port.clone())));
            graph.add_stmt(stmt!(edge!(port.clone() => node_id!(id))));
        }
    }
}

fn find_target_nodes(target: &str, labels: &HashMap<&NodeId, &String>) -> Result<Vec<NodeId>> {
    let (filename, line) = {
        let s = target.split(':').collect::<Vec<&str>>();
        if s.len() != 2 {
            bail!("Invalid target: {}", target);
        }
        (s[0], s[1])
    };

    Ok(labels
        .iter()
        .filter(|(_, &label)| {
            label.contains(&format!("ln\\\": {}", line)) && label.contains(filename)
        })
        .map(|(&id, _)| id.clone())
        .collect())
}

fn reachability(
    target_nodes: &[NodeId],
    predecessors: &HashMap<&NodeId, HashSet<&NodeId>>,
    labels: &HashMap<&NodeId, &String>,
) -> Result<HashSet<String>> {
    let mut visited = HashSet::new();
    let mut queue = VecDeque::new();

    for node in target_nodes {
        queue.push_back(node.clone());
    }

    let mut b_trace = HashSet::new();

    while let Some(node) = queue.pop_front() {
        if visited.contains(&node) {
            continue;
        }
        visited.insert(node.clone());

        if let Some(preds) = predecessors.get(&node) {
            for &pred in preds {
                queue.push_back(pred.clone());
            }
        }

        if let Some(label) = labels.get(&node) {
            const LN_STR: &str = "ln\\\": ";
            const FILE_STR: &str = "file\\\": ";
            const FL_STR: &str = "fl\\\": ";
            if let Some(pos) = label.find(LN_STR) {
                let line = label[pos + LN_STR.len()..]
                    .split(',')
                    .next()
                    .with_context(|| {
                        format!("Cannot find line number for {:?} in label {}", node, label)
                    })?
                    .parse::<usize>()
                    .with_context(|| {
                        format!("Cannot parse line number for {:?} in label {}", node, label)
                    })?;

                let filename = label
                    .find(FL_STR)
                    .map(|pos| (FL_STR, pos))
                    .or_else(|| label.find(FILE_STR).map(|pos| (FILE_STR, pos)))
                    .and_then(|(prefix, pos)| label[pos + prefix.len()..].split("\\\"").nth(1))
                    .ok_or_else(|| {
                        anyhow!("Cannot find filename for {:?} in label {}", node, label)
                    })
                    .map(|s| s.split('/').last().expect("Should always have an element"))?;

                b_trace.insert(format!("{}:{}", filename, line));
            }
        }
    }

    Ok(b_trace)
}
