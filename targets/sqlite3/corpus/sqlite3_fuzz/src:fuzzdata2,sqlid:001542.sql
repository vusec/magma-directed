CREATE TABLE t10(x INTEGER PRIMARY KEY, y INT, z CHAR(100));
CREATE INDEX �������������������������������������t000 ON t10(y);
EXPLAIN QUErYPLAN
SELECT a.x, b.x
FROM t10 AS a JOIN t10 AS b ON B.y=b.x
WHERE (b.x=$ab0 OR b.x=$ab0);
