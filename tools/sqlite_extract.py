#!/usr/bin/env python3
import argparse
import enum
import sqlite3
import pathlib
from typing import Generator, Literal, Optional


class OperationMode(enum.Enum):
    ALL = "all"
    ONLY_XSQL = "xsql"
    INCLUDE_DBS = "include-dbs"
    PREPEND_DBS = "prepend-dbs"

    def __str__(self):
        return self.value


def cli() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract data from sqlite3 fuzz database"
    )
    parser.add_argument(
        "-o",
        "--output",
        dest="output_dir",
        type=pathlib.Path,
        required=True,
        help="output directory",
    )
    parser.add_argument(
        "mode", type=OperationMode, choices=OperationMode, help="operation mode"
    )
    parser.add_argument("databases", nargs="+", help="sqlite3 database file(s)")
    return parser.parse_args()


def main(output_dir: pathlib.Path, mode: OperationMode, databases: list[str]):
    output_dir.mkdir(parents=True, exist_ok=False)

    # The schema for each database is:
    # CREATE TABLE db (dbid INTEGER PRIMARY KEY, dbcontent BLOB);
    # CREATE TABLE xsql (sqlid INTEGER, sqltext TEXT);

    for db in databases:
        conn = sqlite3.connect(db)
        conn.text_factory = bytes
        cur = conn.cursor()

        db_filename = pathlib.Path(db).stem

        if mode in (
            OperationMode.ALL,
            OperationMode.ONLY_XSQL,
            OperationMode.INCLUDE_DBS,
        ):
            for id, sql in fetch_all("xsql", cur):
                write_tc(output_dir, db_filename, sql, sqlid=id)

        if mode in (OperationMode.ALL, OperationMode.INCLUDE_DBS):
            for id, sql in fetch_all("db", cur):
                write_tc(output_dir, db_filename, sql, dbid=id)

        if mode in (OperationMode.ALL, OperationMode.PREPEND_DBS):
            for dbid, dbsql in fetch_all("db", cur):
                for sqlid, sql in fetch_all("xsql", cur):
                    write_tc(
                        output_dir, db_filename, dbsql + sql, dbid=dbid, sqlid=sqlid
                    )

        cur.close()
        conn.close()


def write_tc(
    dir: pathlib.Path,
    db: str,
    bs: bytes,
    dbid: Optional[int] = None,
    sqlid: Optional[int] = None,
):
    if dbid is None and sqlid is None:
        raise ValueError("dbid or sqlid must be specified")

    fname = f"src:{db}"
    if dbid is not None:
        fname += f",dbid:{dbid:06d}"
    if sqlid is not None:
        fname += f",sqlid:{sqlid:06d}"
    fname += ".sql"

    dir.joinpath(fname).write_bytes(bs)


def fetch_all(
    db: Literal["db", "xsql"], cur: sqlite3.Cursor
) -> Generator[tuple[int, bytes], None, None]:
    cid, c = ("sqlid", "sqltext") if db == "xsql" else ("dbid", "dbcontent")
    for row in cur.execute(f"SELECT {cid}, {c} FROM {db} ORDER BY {cid} ASC"):
        yield row[0], row[1]


if __name__ == "__main__":
    main(**vars(cli()))
