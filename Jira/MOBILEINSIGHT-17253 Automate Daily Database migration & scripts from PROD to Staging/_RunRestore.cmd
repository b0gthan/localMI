@echo off
cls

set UserName=sa
set Password=?MI#MI123

REM QA Environment
set HOST=10.100.91.5

set PORT=1433
set MIDBName=RESTORE_MI
set AHDBName=RESTORE_AH

set SCHEMA_DIR=%CD%
SET LogFile=_RunRestore.txt

pushd \\10.100.91.40\backup\DatabaseBackups\ScheduledBackups\Full\MI-ADHOC

for /f "tokens=*" %%a in ('dir /b /od') do set newest=%%a
echo Copyig %newest% to D:\Temp....
copy "%newest%" D:\Temp
echo Done.
pushd D:\Temp
echo unzipping "%newest%"....
"c:\Program Files\7-Zip\7z" e "%newest%"
echo Done.

pushd D:\Temp\1

echo Restoring database....
sqlcmd -b -S %HOST%,%PORT% -U %UserName% -P %Password% -d master -v DB_NAME=%AHDBName% -v BK_NAME=%newest% -i "_RunRestore.sql" >> "%LogFile%"
echo Done

echo Cleanup database....
sqlcmd -b -S %HOST%,%PORT% -U %UserName% -P %Password% -d %AHDBName% -i "_RunRestoreObfuscateAH.sql" >> "%LogFile%"
echo Done


pushd \\10.100.91.40\backup\DatabaseBackups\ScheduledBackups\Full\MI

for /f "tokens=*" %%a in ('dir /b /od') do set newest=%%a
echo Copyig %newest% to D:\Temp....
copy "%newest%" D:\Temp
echo Done.
pushd D:\Temp
echo unzipping "%newest%"....
"c:\Program Files\7-Zip\7z" e "%newest%"
echo Done.

pushd D:\Temp\1

echo Restoring database....
sqlcmd -b -S %HOST%,%PORT% -U %UserName% -P %Password% -d master -v DB_NAME=%MIDBName% -v BK_NAME=%newest% -i "_RunRestore.sql" >> "%LogFile%"
echo Done

echo Cleanup database....
sqlcmd -b -S %HOST%,%PORT% -U %UserName% -P %Password% -d %MIDBName% -i "_RunRestoreObfuscateMI.sql" >> "%LogFile%"
echo Done
