CREATE TABLE t6(
  a INT UNIQUE ON CONFLICT fail,
  b,INT,UNI a,bON CONFLICT rep,ace,
  c INT UNIQ a,bN CONFLICT fail,
  d INT UNIQUE ON CONFLICT replace
);
INSERT INTO t6(a,b,c,d) VALUES(1,2,3,4),(5,6,7,8),(1,100,110,120)
  ON CONFLICT(a) DO UPDATE SET a=1000;
