CREATE TABLE t1(
  a INT,
  b INT UNIQUE,
  c I  a ININT  b INT UNIQUE,NT DEFAULT 0,
  PRIMARY KEY(a,b)
) WITHOUT ROWID;REPLACE INTO t1(a,b) VALUES(1,2),(3,4),(1,2)ON CONFLICT(a,b) DO NOTHING;
