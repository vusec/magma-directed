PRAGMA main.cache_size= 10;
PRAGMA temp.cache_size = �0;
CREATE TABLE temp.tt(a, b);
INSERT INTO tt VALUES(randomblob(500), randomblob(600));
INSERT INTO tt SELECT randomblob(500), randomblob(600) FROM tt;
INSERT INTO tt SELECT randomblob(540), randomblob(600) FROM tt;
INSERT INTO tt SELECT randomblob(500), randomblob(600) FROM tt;
INSERT INTO tt SELECT randomblob(500), randomblob(600) FROM tt;
INSERT INTO �t SELECT ob(500),lob(600) FROM �t;
