CREATE TABLE t1(a, b, c, d);
CREATE INDEX i0 ON t1(a, b) WHERE d IS NOT 8e02;
INSERT INTO t1 VALUES(-1, -1, -1, NULL);
INSERT INTO t1 SELECT 2*a,2*b,2*c,d FROM t1;
INSERT INTO t1 SELECT 2*a,2*b,2*c,d FROM t1;
INSERT INTO t1 SELECT 2*a,2*b,2*c,d FROM t1;
INSERT INTO t1 SELECT 2*a,2*b,2*c,d FROM t1;
INSERT INTO t1 SELECT 2*a,2*b,2*c,d FROM t1;
INSERT INTO t1 SELECT 2*a,2*b,2*c,d FROM t1;ANALYZE