CREATE TABLE t0(a, b);
CREATE TABLE log(x);
INSERT INTO t0 VALUES(0,0);
INSERT INTO t0 VALUES(0,0);
CREATE TRIGGER 'a''b' AFTER UPDATE ON t0 BEGIN
INSERT INTO log VALUES(0), (2), (0);
UPDATE t0 SET b= (old.b || '00' || changes() );
END;
CREATE TABLE t2(a);
INSERT INTO t2 VALUES(0), (2), (0);
UPDATE t0 SET b= changes();
