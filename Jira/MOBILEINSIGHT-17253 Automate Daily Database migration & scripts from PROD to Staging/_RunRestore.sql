/*
* This will restore the dB from the specified Backup files. We recommend to take the back-ups
* from \\10.100.91.40\backup\DatabaseBackups\ScheduledBackups\Full and copy them on the server.
* Previous to running this script, please set the following paths correctly.
*/
DECLARE @DB_NAME VARCHAR(250)
	, @BK_NAME VARCHAR(250)
	, @SQL VARCHAR(MAX)


SET @DB_NAME = '$(DB_NAME)'
SET @BK_NAME = '$(BK_NAME)'
SET @BK_NAME = REPLACE(@BK_NAME, '.bz2', '')
SET @SQL = '
ALTER DATABASE [' + @DB_NAME + ']
SET SINGLE_USER WITH ROLLBACK IMMEDIATE'

EXEC (@SQL)

SET @SQL = '
RESTORE DATABASE [' + @DB_NAME + ']
FROM  DISK = N''D:\Temp\' + @BK_NAME + ''' WITH  FILE = 1,
NOUNLOAD,  REPLACE,
STATS = 2'

EXEC(@SQL)

SEt @SQL = '
ALTER DATABASE [' + @DB_NAME + ']
SET MULTI_USER WITH ROLLBACK IMMEDIATE'

EXEC(@SQL)