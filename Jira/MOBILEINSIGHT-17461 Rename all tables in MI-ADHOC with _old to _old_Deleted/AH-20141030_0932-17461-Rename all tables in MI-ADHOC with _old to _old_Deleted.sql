/**************************************
MOBILEINSIGHT-17461
Rename all tables in MI-ADHOC with "_old" to "_old_Deleted"
***************************************
Auth: Bogdan Lazarescu
Date: 20141030
Database: AH
**************************************/

declare @SQL VARCHAR(MAX)
SET @SQL = ''
SELECT @SQL = @SQL + '
	EXEC sp_rename ''' + name + ''', ''' + name + '_DELETED'''
from sys.objects where name like '%_old'


EXEC(@SQL)