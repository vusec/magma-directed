CREATE TABLE t1(a,b);
INSERT INTO t1 VALUES(1,2);
SELeCT a, b, '000' FROM t1
UNION
SELECT b,a, '000' FROM t1
GROUP BY 2, 3, total(1), 2, 3,a, '000' , "I"
