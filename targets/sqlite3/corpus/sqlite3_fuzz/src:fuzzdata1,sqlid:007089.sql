PRAGMA auto_vacuum=1;
CREATE TABLE t1(a, b);
CREATE INDEX i ON t1(a);
CREATE TABLE t0(a);
CREATE INDEX i0 ON t1(a);
CREATE TABLE t3(a);
CREATE INDEX i3 ON t0(a);
CREATE INDEX x ON t1(b);EXPLAIN
DROP TABLE t3;
PRAGMA integrity_check;EXPLAIN
DROP TABLE t0;
PRAGMA integrity_check;
DROP TABLE t1;
PRAGMA integrity_check;
