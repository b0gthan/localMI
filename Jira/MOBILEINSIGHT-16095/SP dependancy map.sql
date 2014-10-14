SELECT DISTINCT O.name, O.type, O1.name, O1.type
FROM sys.objects O
	INNER JOIN sys.sql_dependencies D ON O.object_id = D.object_id
INNER JOIN sys.objects O1 ON D.referenced_major_id = O1.object_id
AND O.type IN ('P', 'FN', 'IF', 'TF', 'TR')
AND O1.type IN ('P', 'FN', 'IF', 'TF', 'TR')
AND O.name NOT LIKE '_FormView_%'