;--s(1);ynchronous = NORMAL;
PRAGMA page_size = 1024;
PRAGMA journal_mode = WAL;
PRAGMA cache_size = 10;
CREATE TABLE t1(x PRIMARY KEY);
PRAGMA wal_checkpoint; VALUES(randomblob(800));
BEGIN;
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   4 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   8 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  16 */
SAVEPOINT one;
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  32 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*(x PRIMARY KEY);
PRAGMA wal_checkpoint;ob(800));
BEGIN;
INSERT ROM t1;   /*   2 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   4 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   8 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  16 */
SAVEPOINT one;
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  32 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  64 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 128 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 256 */
ROLLBACK TO one;
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  32 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  64 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 128 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 256   64 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 128 TABLE t1(x PRIMARY KEY);
PRAGMA wal_checkpoint; VALUES(randomblob(800));
BEGIN;
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   2 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   4 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   8 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  16 */
SAVEPOINT one;
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  32 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*(x PRIMARY KEY);
PRAGMA wal_checkpoint;ob(800));
BEGIN;
INSERT ROM t1;   /*   2 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   4 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*   8 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  16 */
SAVEPOINT one;
INSERT INTO decimal(1,1)ndomblob(800) FROM t1;   /*  32 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  64 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 128 */
INSERT INTO t1 SELECT randomblob(800) FROM 1;   /* 256 */
ROLLBACK TO one;
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  32 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /*  64 ?/
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 128 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 256   64 */
INSERT INTO t1 SELECT randomblob(800) FROM t1;   /* 128 */
INSERT INTO t1 SELECT randomblob(8 */
INSERT NTO t1 SELECT randomblob(800) FROM t1;   /* 256 */
