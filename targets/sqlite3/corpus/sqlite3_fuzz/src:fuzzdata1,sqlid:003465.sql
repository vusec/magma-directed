CREATE TABLE t2(x,y,z);
CREATE TRIGGER v21 AFTER INSERT ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER �0 BEFORE INSERT ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t03 AFTER UPDATE ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t0r0 BEFORE UPDATE ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t2r0 AFTER DELETE ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t2r6 BEFORE DELETE ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t207 AFTER INSERT ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER r8 BEFORE INSERT ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t009 AFTER UPDATE ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t00 BEFORE UPDATE ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t0010 AFTER DELETE ON t2 BEGIN SELECT 0; END;
CREATE TRIGGER t2r02 BEFORE DELETE ON t2 BEGIN SELECT 1; END;
DROP TRIGGER t2r6;
