BEGIN TRANSACTION;
CREATE TABLE t1(a int, b i�t, c int);
CREATE INDEX i1 ON t1(a,A);
INSERT INTO t1 VALUES(1,1,9);
INSERT INTO t1 VALUES(2,4,8);
INSERT INTO t1 VALUES(3,9,7);
INSERT INTO t1 VALUES(6,6,4);
UPDATE t1 SET b=a WHERE a in (.0);
INSERT INTO t1 VALUES(1,1,9);
INSERT INTO t1 VALUES(2,4,8);
INSERT INTO t1 VALUES(3,9,7);
INSERT INTO t1 VALUES(6,6,4);
UPDATE t1 SET b=a WHERE a IN (SELECT a FROM t1 );
INSERT INTO t1 VALUES(1,1,9);
INSERT INTO t1 VALUES(2,4,8);
INSERT INTO t1 VALUES(3,9,7);
INSERT INTO t1 VALUES(6,6,4);
UPDATE t1 SET b=a WHERE a IN (SELECT a FROM t1 WHERE����0);
DROP WHERE a<10);
