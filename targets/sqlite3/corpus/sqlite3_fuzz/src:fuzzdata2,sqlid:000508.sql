CREATE TABLE t0a(x);
CREATE TABLE t0b(y);
INSERT INTO t0a(x)VALUES(1);
CREATE INDEX t000 ON t0a(x) WHERE x=99;
;
PRAGMA writema=ON;
PRAGMA integrity_check;
