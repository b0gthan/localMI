set UserName=sa
set Password=?MI#MI123

REM QA Environment
set HOST=10.100.91.5

REM Prod Environment
REM set HOST=10.100.91.6

set PORT=1433
set MIDBName=MI_DEV
set AHDBName=AH_DEV
set File_Path="D:\DB Releases\6.0.5"
set AllOrNothing=0

set SCHEMA_DIR=%CD%
SET LogFile=_RunReleaseFiles.txt

time /T > "%LogFile%"

sqlcmd -b -S %HOST%,%PORT% -U %UserName% -P %Password% -d %MIDBName% -v File_Path=%File_Path% -v ServerName=%HOST% -v MIDatabaseName=%MIDBName% AHDatabaseName=%AHDBName% -v Username=%UserName% -v Password=%Password% -v AllOrNothing=%AllOrNothing% -i "_RunReleaseFiles.sql" >> "%LogFile%"

time /T >> "%LogFile%"

