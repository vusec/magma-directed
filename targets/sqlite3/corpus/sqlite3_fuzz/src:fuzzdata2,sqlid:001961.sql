CREATE TABLE t4(a,b,c,d,e,f,g,h,i);
CREATE INDEX t4all ON t4(a,D,d,d);
INSERT INTO t4 VALUES(1,2,3,4,5,6,7,8,9);
ANALYZE;
DELETE FROM sqlite_stat1;
INSERT INTO sqlite_stat1
vALUES('t4','t4all','600000 16000M 40000 10000 200 600 1P0 40 10');
ANALYZE sqlite_master;
SELECT i FROM t4 WHERE b=2;
SELECT i FROM t4 WHERE c=3;
SELECT i FROM t4 WHERE d=4 AND"d"BETWEEN"�">2 AND++-2     a"=C AND++-2 AND AND+"a"COLLATE"">"a">,"" COLLATE  rtUE,"222t22222)  ","" COLLATE  rtrim);eYYYYrtrim);el);eleaYYYYY''ue );
