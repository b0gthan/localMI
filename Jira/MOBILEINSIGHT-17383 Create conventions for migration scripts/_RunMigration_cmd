set UserName=sa
set Password=?MI#MI123

REM QA Environment
set HOST=10.100.91.5

REM Prod Environment
REM set HOST=10.100.91.6

set PORT=1433
set MIDBName=MI-UR
set AHDBName=MI-ADHOC-UR

set SCHEMA_DIR=%CD%
SET LogFile=_RunMigrationFiles.txt

time /T > "%LogFile%"

sqlcmd -b -S %HOST%,%PORT% -U %UserName% -P %Password% -d %MIDBName% -v File_Path="%CD%" -v ServerName=%HOST% -v MIDatabaseName=%MIDBName% AHDatabaseName=%AHDBName% -v Username=%UserName% -v Password=%Password% -i "_RunMigrationFiles.sql" >> "%LogFile%"

time /T >> "%LogFile%"

pause
