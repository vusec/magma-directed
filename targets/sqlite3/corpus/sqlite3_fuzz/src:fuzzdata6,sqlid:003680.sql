CREATE TABLE t8(a INT PRIMARY KEY, b, c);
CREATE UNIQUE INDEX t8x ON t8( 'a''x'COLLATE binary)
    ON CONFLICT((b||'x')) DO NOTHING;
