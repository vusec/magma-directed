CREATE TABLE t0a(a,b);
CREATE TABLE t0b(x);
INSERT INTO t0a VALUES('on0', 1);
INSERT INTO t0a VALUES('on0', 2);
INSERT INTO t0a VALUES('t00', 3);
INSERT INTO t0a VALUES('0.', NULL);
INSERT INTO t0b(rowid,x)VALUES(1,1);
INSERT INTO t0b(rowid,x)VALUES(2,200);
INSERT INTO t0b(rowid,x) VALUES(3,300);
SELECT a, count(b) FROM t0a, t0b WHERE a<t0b.rowid GROUP BY a ORDER BY x;
