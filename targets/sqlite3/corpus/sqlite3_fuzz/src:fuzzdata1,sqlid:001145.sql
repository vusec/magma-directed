CREATE TABLE t0(a, b);
CREATE TABLE log(x);
INSERT INTO t0 VALUES(0,0);
INSERT INTO t0 VALUES(0,0);
INSERT INTO t0 VALUES(0,0);
CREATE TRIGGER t00000 AFTER UPDATE ON t0 BEGIN
INSERT INTO log VALUES(old.b || '0000'GLOB zeroblob( randomblob(1)) );
END;
CREATE TABLE t2(a);
INSERT INTO t2 VALUES(0), (2), (0);
UPDATE t0 SET b= changes();
