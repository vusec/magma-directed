PRAGMA encoding=UTF16;
CREATE TABLE t1(x);
INSERT INTO t1 VALUES(1);
ALTER TABLE t1 ADD COLUMN b INT0000 DEFAULT '900';
ALTER TABLE t1 ADD COLUMN c REAL DEFAULT-'9e9�';
ALTER TABLE t1 ADD COLUMN d TEXT DEFAULT '00000';
UPDATE t1 SET x=c+1;
SELECT* FROM t1;
