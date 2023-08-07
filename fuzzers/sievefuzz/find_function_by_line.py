#!/usr/bin/env python3
from clang.cindex import CompilationDatabase, CursorKind, Index


def find_function(node, filename, line, demangled=False):
    if (
        node.kind in [CursorKind.FUNCTION_DECL, CursorKind.CXX_METHOD]
        and node.extent.start.file.name == filename
        and node.extent.start.line <= line <= node.extent.end.line
    ):
        if demangled:
            if node.kind == CursorKind.CXX_METHOD:
                return f"{node.semantic_parent.spelling}::{node.displayname}"
            return node.spelling
        return node.mangled_name

    for child in node.get_children():
        found = find_function(child, filename, line)
        if found is not None:
            return found


def build_args(db_dir, file):
    db = CompilationDatabase.fromDirectory(db_dir)
    cmds = db.getCompileCommands(file)
    if cmds is None or len(cmds) == 0:
        return None
    return list(cmds[0].arguments)[1:]


if __name__ == "__main__":
    from argparse import ArgumentParser
    import logging
    from sys import stderr

    parser = ArgumentParser(description="Find function by line number")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    parser.add_argument("--demangled", action="store_true", help="Demangle function")
    parser.add_argument("--db-dir", type=str, help="Compilation database directory")
    parser.add_argument("file", type=str, help="File to search")
    parser.add_argument("line", type=int, help="Line number to search")

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO, stream=stderr
    )

    bargs = None
    if args.db_dir is not None:
        bargs = build_args(args.db_dir, args.file)
        if bargs is None:
            logging.warn(f"could not find command for {args.file}")
        else:
            bargs = [
                arg
                for arg in bargs
                if arg.startswith("-I")
                or arg.startswith("-D")
                or arg.startswith("-std")
            ]
            logging.debug(f"build args: {bargs}")

    tu = Index.create().parse(args.file, args=bargs)
    fn = find_function(tu.cursor, args.file, args.line, args.demangled)

    if fn is None:
        exit(1)

    print(fn)
