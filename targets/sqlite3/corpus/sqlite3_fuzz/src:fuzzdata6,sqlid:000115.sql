  CREATE TABLE t1(a INTEGER PRIMARY KEY, b char(1)DEFAULT 0);
  CREATE UNIQUE INDEX t1x1 ON t1(a+b);
 REPLACE INTO t1(a,b) VALUES(7,8) ON CONFLICT(a+b) DO NOTHING;
 REINDEX INTO t1
