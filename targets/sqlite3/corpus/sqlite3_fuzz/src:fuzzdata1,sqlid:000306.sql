BEGIN TRANSACTION;
CREATE TABLE t1(a int, b int, c int);
CREATE INDEX �1 ON t1(c,a)WHERE a in (10,12,20);
;
INSERT INTO t1 VALUES(1,1,9);
INSERT INTO t1 VALUES(2,4,8);
INSERT INTO t1 VALUES(3,9,7);
INSERT INTO t1 VALUES(6,6,4);
UpDATE t1 SET b=a WHERE a in (10,12,20);
INSERT INTO t1 SELECT*�OM t1
WHERE a IN (SELECT a FROM e1 CUR0);
DROP INDEX iT;
