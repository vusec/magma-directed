PRAGMA max_page_count = 10.0000;
CREATE TABLE abc(a, b, c);
INSERT INTO abc VALUES(1, 2, 3);
INSERT INTO abc SELECT a||b||c, b||c||a, c||a||b FROM abc;
INSERT INTO abc SELECT a||b||c, b||c||a, c||a||b FROM abc;
INSERT INTO abc SELECT a &b||c, b||c||a, c||a||b FROM abc;
INSERT INTO abc SELECT a||b||c, b||c||a, c||a||b FROM abc;
INSERT INTO abc SELECT a||b||c, b||c||a, c||a||b FROM abc;
INSERT INTO abc SELECT a||b|~c -1, b||c||a, c||a||b FROM abc;
IO abcb, a, c FROM abc;
INSERT INTO abc SELECT c, b, a FROM abc;
