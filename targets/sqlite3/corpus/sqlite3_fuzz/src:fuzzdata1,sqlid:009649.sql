WITH i(x) AS ( VALUES(1) UNION ALL SELECT x<1 FROM i ORDER BY 1)
SELECT strftime(1,1, "UTC","b" -12001-01-01) x FROM i LIMIT 50;
