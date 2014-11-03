DECLARE @FullPath NVARCHAR(1000),
		@Path NVARCHAR(1000),
		@FileName NVARCHAR(256),
		@SqlStatement nvarchar(max),
		@ServerName varchar(50),
		@UserName varchar(50),
		@Password varchar(50),
		@MIDatabaseName varchar(50),
		@AHDatabaseName varchar(50),
		@FilePath varchar(max),
		@ReturnCode int
		, @AllOrNothing INT
		, @SQL VARCHAR(MAX)
		, @CHECK INT, @ALREADY_RAN NVARCHAR(MAX)
		, @ERROR_ON_BATCH INT

DECLARE @Dir NVARCHAR(1000) ;
--SELECT  @Dir = N'c:\DBBackUp\UserRevamp\' ;

SET @ServerName = '$(ServerName)'
SET @UserName = '$(Username)'
SET @Password = '$(Password)'
SET @MIDatabaseName = '$(MIDatabaseName)'
SET @AHDatabaseName = '$(AHDatabaseName)'
SET @FilePath = '$(File_Path)'
SET @AllOrNothing  = '$(AllOrNothing)' 

SET @Dir = @FilePath
SET @ERROR_ON_BATCH = 0


IF RIGHT(@Dir, 1) <> '\' 
	SELECT  @Dir = @Dir + '\' ;

--create track ran script tables
SET @SQL = 'IF NOT EXISTS (SELECT 1 FROM [' + @MIDatabaseName + '].sys.objects WHERE NAME = ''UTILS_DB_SCRIPTS'')
			BEGIN
				CREATE TABLE [' + @MIDatabaseName + '].dbo.UTILS_DB_SCRIPTS (SCRIPT_NAME VARCHAR(250), RUN_AT DATETIME)
			END
IF NOT EXISTS (SELECT 1 FROM [' + @AHDatabaseName + '].sys.objects WHERE NAME = ''UTILS_DB_SCRIPTS'')
			BEGIN
				CREATE TABLE [' + @AHDatabaseName + '].dbo.UTILS_DB_SCRIPTS (SCRIPT_NAME VARCHAR(250), RUN_AT DATETIME)
			END'
EXEC (@SQL)


IF OBJECT_ID('tempdb..#DirTree', 'U') IS NOT NULL 
	DROP TABLE #DirTree;

CREATE TABLE #DirTree
(
	Id INT PRIMARY KEY IDENTITY,
	SubDirectory NVARCHAR(1000),
	Depth INT,
	Is_File BIT,
);

INSERT INTO #DirTree 
	EXEC xp_dirtree @Dir, 0, 1 ;

DECLARE @DirTree TABLE
(
	[Id] INT NOT NULL,
	[ParentId] INT,
	[Depth] INT NOT NULL,
	[FullPath] NVARCHAR(1000) NOT NULL,
	[Path] NVARCHAR(1000),
	[FileName] NVARCHAR(256),
	[FileExtenssion] NVARCHAR(20),
	[Is_File] Bit
);

--SELECT * FROM #DirTree

ALTER TABLE #DirTree 
	ADD ParentId INT;

UPDATE #DirTree
SET ParentId = (SELECT MAX(Id) FROM #DirTree
		WHERE Depth = dt.Depth - 1 AND Id < dt.Id)
FROM #DirTree dt;

WITH DirTree_CTE
AS
(
	SELECT
			dt.Id,
			dt.ParentId,
			dt.Depth,
			CAST(@Dir + dt.SubDirectory AS NVARCHAR(1000)) AS FullPath,
			CAST(
				CASE 
					WHEN dt.Is_File = 0 THEN @Dir + dt.SubDirectory 
					ELSE @Dir
				END AS NVARCHAR(1000)) AS [Path],
			CAST (
				CASE 
					WHEN dt.Is_File = 0 THEN NULL
					ELSE dt.SubDirectory
				END AS NVARCHAR(256)) AS [FileName],
			CAST (
				CASE 
					WHEN dt.Is_File = 0 THEN NULL
					ELSE RIGHT(dt.SubDirectory, CHARINDEX('.', REVERSE(dt.SubDirectory)) - 1)
				END AS NVARCHAR(10)
				) AS [FileExtenssion],
			dt.Is_File
		FROM
			#DirTree AS dt
		WHERE
			dt.ParentId IS NULL
	UNION ALL
	SELECT
		dt.Id,
		dt.ParentId,
		dt.Depth,
		CAST(DirTree_CTE.[Path] + '\' +  dt.SubDirectory AS NVARCHAR(1000)) AS FullPath,
		CAST(
			CASE 
				WHEN dt.Is_File = 0 THEN @Dir + dt.SubDirectory 
				ELSE @Dir
			END AS NVARCHAR(1000)) AS [Path],
		CAST (
			CASE 
				WHEN dt.Is_File = 0 THEN NULL
				ELSE dt.SubDirectory
			END AS NVARCHAR(256)) AS [FileName],
		CAST (
			CASE 
				WHEN dt.Is_File = 0 THEN NULL
				ELSE RIGHT(dt.SubDirectory, CHARINDEX('.', REVERSE(dt.SubDirectory)) - 1)
			END AS NVARCHAR(10)
			) AS [FileExtenssion],
		dt.Is_File
	FROM
		#DirTree AS dt
		JOIN DirTree_CTE
			ON DirTree_CTE.Id = dt.ParentId
)
INSERT INTO @DirTree ([Id], [ParentId],	[Depth], [FullPath], [Path], [FileName], [FileExtenssion], [Is_File])
SELECT dt_c.Id, dt_c.ParentId, dt_c.Depth, dt_c.FullPath, dt_c.[Path], dt_c.[FileName], dt_c.[FileExtenssion], dt_c.Is_File
	FROM DirTree_CTE dt_c
	ORDER BY dt_c.Id


DECLARE @RunnableStatements TABLE
(
	[UniqueId] INT IDENTITY(1,1),
	[FullPath] NVARCHAR(1000),
	[Path] NVARCHAR(1000),
	[FileName] NVARCHAR(256),
	[Runned] bit DEFAULT 0
)

DECLARE @ScriptsToRun int
DECLARE @CurrentId int;

SELECT @ScriptsToRun = 0, @CurrentId = 1

INSERT INTO @RunnableStatements ([FullPath], [Path], [FileName])
	SELECT [FullPath]
			,[Path]
			,[FileName] 
		FROM 
			 @DirTree dt
		WHERE 
			dt.Is_File = 1
			AND dt.FileExtenssion LIKE '%sql%'

SET @ScriptsToRun = SCOPE_IDENTITY()

BEGIN TRANSACTION main

WHILE(@CurrentId <= @ScriptsToRun)
BEGIN
	SELECT @FullPath = FullPath, 
			@Path = [Path], 
			@FileName = [FileName]
		FROM
			@RunnableStatements rs
		WHERE rs.UniqueId = @CurrentId

	IF @FileName is not null and @FileName <> ''
	BEGIN

		SET @ALREADY_RAN = N'SET @CHECK = ISNULL((SELECT TOP 1 1 FROM [' + (CASE WHEN LEFT(@FileName, 2) = 'MI' THEN @MIDatabaseName WHEN LEFT(@FileName, 2) = 'AH' THEN @AHDatabaseName END) + '].dbo.UTILS_DB_SCRIPTS WHERE SCRIPT_NAME = ''' + @FileName  + '''), 0)'
		EXEC sp_executesql @ALREADY_RAN, N'@CHECK INT OUTPUT', @CHECK=@CHECK OUTPUT;

		PRINT 'Start running script <<' + @FileName + '>> on ' 
				+ (CASE WHEN LEFT(@FileName, 2) = 'MI' THEN @MIDatabaseName WHEN LEFT(@FileName, 2) = 'AH' THEN @AHDatabaseName ELSE ' unknown database - script wil not be ran!!!' END) + '.'
				+ (CASE WHEN LEFT(@FileName, 2) IN ('MI', 'AH') AND @CHECK = 1 THEN ' Script already ran!!!' ELSE '' END)

		SET @SqlStatement = 'exec @ReturnCode = master.dbo.xp_cmdshell ''osql -S ' + @ServerName + ' -U ' + @Username + ' -P ' + @Password + ' -d ' + (CASE WHEN LEFT(@FileName, 2) = 'MI' THEN @MIDatabaseName WHEN LEFT(@FileName, 2) = 'AH' THEN @AHDatabaseName END) + ' -b -i "' + @FullPath + '"'''       
		--PRINT @SqlStatement
		IF (LEFT(@FileName, 2) = 'MI' OR LEFT(@FileName, 2) = 'AH') AND @CHECK = 0
			BEGIN
				BEGIN TRANSACTION secondary
				EXECUTE sp_executesql @SqlStatement, N'@ReturnCode int output', @ReturnCode = @ReturnCode OUTPUT
         
				IF @ReturnCode <> 0
					BEGIN
						PRINT 'Failed to execute: ' + @Filename
						ROLLBACK TRANSACTION secondary
						SET @ERROR_ON_BATCH = 1
					END
				ELSE
					BEGIN
						PRINT 'Script ' + @FileName + ' ran successfully'
						SET @SQL = 'INSERT INTO [' + (CASE WHEN LEFT(@FileName, 2) = 'MI' THEN @MIDatabaseName WHEN LEFT(@FileName, 2) = 'AH' THEN @AHDatabaseName END) + '].dbo.UTILS_DB_SCRIPTS(SCRIPT_NAME, RUN_AT) VALUES(''' + @FileName  + ''', GETDATE())'
						EXEC(@SQL)
						COMMIT TRANSACTION secondary
					END
			END			
	END 

	UPDATE rs
		SET rs.Runned = 1
			FROM @RunnableStatements rs
		WHERE rs.UniqueId = @CurrentId

	SET @CurrentId = @CurrentId + 1
END


IF @AllOrNothing = 1 AND @ERROR_ON_BATCH = 1
	BEGIN
		PRINT 'At least one script failed, rolling back everything!'
		ROLLBACK TRANSACTION main
	END
ELSE
	BEGIN
		COMMIT TRANSACTION main
	END