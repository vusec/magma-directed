CREATE TABLE t4(a INT, b INT);
CREATE UNIQUE INDEX t4a1 ON t4(a) WHERE NOT(1)ISNULL;
REINDEX) VALUES(50,60) ON CONFLICT(a) DO NOTHING;
