/****** Meta Database Create/Update    Script Date: 1/03/06 ******/
Declare @Check int
Declare @sCommand varchar(500)

/****** Object:  Table [dbo].[CascadeFilterDetails]   ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CascadeFilterDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[CascadeFilterDetails] (
		[FilterDetailID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_CascadeFilterDetails] PRIMARY KEY CLUSTERED,
		[FilterID] [int] NOT NULL DEFAULT (0),
		[ObjectID] [int] NOT NULL DEFAULT (0),
		[FilterColumnID] [int] NULL ,
		[DisplayColumnID] [int] NOT NULL ,
		[ValueColumnID] [int] NOT NULL ,
		[FilterOrder] [tinyint] NOT NULL DEFAULT (0) 
	) ON [PRIMARY]
	end
else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[CascadeFilterDetails]') AND name = N'PK_CascadeFilterDetails')
		begin
		ALTER TABLE [dbo].[CascadeFilterDetails] ADD CONSTRAINT [PK_CascadeFilterDetails] PRIMARY KEY CLUSTERED 
		(
		[FilterDetailID] ASC
		) ON [PRIMARY]
		end

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'FilterID' AND o.parent_obj = Object_ID(N'[dbo].[CascadeFilterDetails]')) 
		begin
			ALTER TABLE [CascadeFilterDetails] ADD CONSTRAINT def_CascadeFilterDetails_FilterID DEFAULT (0) FOR [FilterID];
		end
	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ObjectID' AND o.parent_obj = Object_ID(N'[dbo].[CascadeFilterDetails]')) 
		begin
			ALTER TABLE [CascadeFilterDetails] ADD CONSTRAINT def_CascadeFilterDetails_ObjectID DEFAULT (0) FOR [ObjectID];
		end
	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'FilterOrder' AND o.parent_obj = Object_ID(N'[dbo].[CascadeFilterDetails]')) 
		begin
			ALTER TABLE [CascadeFilterDetails] ADD CONSTRAINT def_CascadeFilterDetails_FilterOrder DEFAULT (0) FOR [FilterOrder];
		end
	end

/****** Object:  Table [dbo].[CascadeFilters]   ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CascadeFilters]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[CascadeFilters] (
		[FilterID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_CascadeFilters] PRIMARY KEY CLUSTERED ,
		[FilterName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ObjectID] [int] NOT NULL ,
		[ColumnID] [int] NOT NULL ,
		[DatabaseID] [int] NOT NULL 
	) ON [PRIMARY]
	end
else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[CascadeFilters]') AND name = N'PK_CascadeFilters')
		begin
		ALTER TABLE [dbo].[CascadeFilters] ADD CONSTRAINT [PK_CascadeFilters] PRIMARY KEY CLUSTERED 
		(
		[FilterID] ASC
		) ON [PRIMARY]
		end

/****** From update_8.1.16 ******/
	SET @Check = (Select Coalesce(Col_length('CascadeFilters','Description'),0))
	If @Check=0
		ALTER TABLE [CascadeFilters] ADD 
			[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	end

/****** Object:  Table [dbo].[Categories]   ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Categories]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Categories] (
		[CategoryID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_Categories] PRIMARY KEY CLUSTERED ,
		[DatabaseID] [int] NOT NULL ,
		[CategoryName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
	) ON [PRIMARY]
	end

/****** Object:  Table [dbo].[CategoryObjects] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[CategoryObjects]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[CategoryObjects] (
		[CategoryID] [int] NOT NULL ,
		[ObjectID] [int] NOT NULL ,
		CONSTRAINT [PK_CategoryObjects] PRIMARY KEY  CLUSTERED 
		(
			[CategoryID],
			[ObjectID]
		)  
	) ON [PRIMARY]

	CREATE INDEX [CategoryObjects_CategoryIDIdx] ON [dbo].[CategoryObjects]([CategoryID]) ON [PRIMARY]
	CREATE INDEX [CategoryObjects_ObjectIDIdx] ON [dbo].[CategoryObjects]([ObjectID]) ON [PRIMARY]
	end

/****** Object:  Table [dbo].[Classes] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Classes]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Classes] (
		[ClassID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_Classes] PRIMARY KEY CLUSTERED ,
		[Class] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[FriendlyName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
			CONSTRAINT [Classes_FriendlyNameIdx] UNIQUE  NONCLUSTERED 
	) ON [PRIMARY]

	Insert Into Classes Values ('bold', 'Bold')
	Insert Into Classes Values ('green', 'Green')
	Insert Into Classes Values ('red', 'Red')
	Insert Into Classes Values ('AlignLeft', 'Align Text Left')
	Insert Into Classes Values ('AlignCenter', 'Align Text Center')
	Insert Into Classes Values ('AlignRight', 'Align Text Right')
	Insert Into Classes Values ('imageAlignLeft', 'Align Image Left')
	Insert Into Classes Values ('imageAlignCenter', 'Align Image Center')
	Insert Into Classes Values ('imageAlignRight', 'Align Image Right')
	Insert Into Classes Values ('BlackTextYellowBackground', 'Black Text Yellow Background')
	Insert Into Classes Values ('WhiteTextGreenBackground', 'White Text Green Background')
	end
else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[Classes]') AND name = N'Classes_FriendlyNameIdx')
		CREATE UNIQUE INDEX [Classes_FriendlyNameIdx] ON [dbo].[Classes]([FriendlyName]) ON [PRIMARY]

	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[Classes]') AND name = N'PK_Classes')
		begin
		ALTER TABLE [dbo].[Classes] ADD CONSTRAINT [PK_Classes] PRIMARY KEY CLUSTERED 
		(
		[ClassID] ASC
		) ON [PRIMARY]
		end
	end


/****** Object:  Table [dbo].[ColumnAccess] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ColumnAccess]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ColumnAccess] (
		[AccessID] [int] NOT NULL 
			CONSTRAINT [PK_ColumnAccess] PRIMARY KEY  CLUSTERED, 
		[AccessName] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]

	Insert Into ColumnAccess Values (0, 'None')
	Insert Into ColumnAccess Values (1, 'Full')
	end


/****** Object:  Table [dbo].[Columns] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Columns]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Columns] (
		[ColumnID] [int] IDENTITY (1, 1) NOT NULL ,
		[ColumnName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ColumnAlias] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Description] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ColumnType] [varchar] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL DEFAULT ('D'),
		[ObjectID] [int] NOT NULL ,
		[OrdinalPosition] [int] NULL ,
		[ColumnOrder] [int] NULL DEFAULT (0),
		[DataType] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[CharacterMaxLen] [int] NULL ,
		[NumericPrecision] [int] NULL ,
		[NumericScale] [int] NULL ,
		[DisplayFormat] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Alignment] [varchar] (15) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[NativeDataType] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Definition] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ExplanationID] [bigint] NOT NULL DEFAULT (0) ,
		[LinkRptID] [int] DEFAULT (0) ,
		[LinkURL] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[FrameID] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[HideColumn] [tinyint] DEFAULT (0) ,
		CONSTRAINT [PK_Columns] PRIMARY KEY  CLUSTERED 
		(
			[ColumnID] ASC
		)
	) ON [PRIMARY]

	CREATE UNIQUE NONCLUSTERED INDEX [IX_Columns] ON [dbo].[Columns] 
	(
	[ObjectID] ASC,
	[ColumnName] ASC
	) ON [PRIMARY]

	end
Else
	begin
/****** From update_6.2.10 ******/
	SET @Check = (Select Coalesce(Col_length('Columns','NativeDataType'),0))
	If @Check=0
		ALTER TABLE [Columns] ADD 
			[NativeDataType] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

/****** From update_7.1.0 ******/
	SET @Check = (Select Coalesce(Col_length('Columns','Definition'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[Columns] ADD 
			[Definition] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		end
	Else
		begin
		ALTER TABLE [Columns] ALTER COLUMN 
			[Definition] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		end

/****** From update_7.2 ******/
	SET @Check = (Select Coalesce(Col_length('Columns','LinkURL'),0))
	If @Check=0
		ALTER TABLE [dbo].[Columns] ADD [LinkURL] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

	SET @Check = (Select Coalesce(Col_length('Columns','FrameID'),0))
	If @Check=0
		ALTER TABLE [dbo].[Columns] ADD [FrameID] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

/****** 7.2.12 ******/
	SET @Check = (Select Coalesce(Col_length('Columns','ExplanationID'),0))
	If @Check=0
		ALTER TABLE [dbo].[Columns] ADD 
			[ExplanationID] [bigint] NOT NULL DEFAULT (0)
/****** 7.3.18 ******/
	SET @Check = (Select Coalesce(Col_length('Columns','ColumnOrder'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[Columns] ADD 
			[ColumnOrder] [int] NULL DEFAULT (0)
		SET @sCommand='UPDATE [Columns] SET ColumnOrder=OrdinalPosition+1'
		Exec (@sCommand)		
		end

	SET @Check = (Select Coalesce(Col_length('Columns','LinkRptID'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[Columns] ADD 
			[LinkRptID] [int] DEFAULT (0)
		SET @sCommand='UPDATE [Columns] SET LinkRptID=0'
		Exec (@sCommand)		
		end

/****** From update 8.0.0 ******/
	/****** Object: Index [PK_Columns] Script Date: 12/07/2006 20:22:45 ******/
	IF EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[Columns]') AND name = N'PK_Columns')
	AND NOT	EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[Columns]') AND name = N'IX_Columns')
		begin
		ALTER TABLE [dbo].[Columns] DROP CONSTRAINT [PK_Columns]

		/****** Object: Index [PK_Columns] Script Date: 12/07/2006 20:33:34 ******/
		ALTER TABLE [dbo].[Columns] ADD CONSTRAINT [PK_Columns] PRIMARY KEY CLUSTERED 
		(
		[ColumnID] ASC
		) ON [PRIMARY]

		/****** Object: Index [IX_Columns] Script Date: 12/07/2006 20:34:00 ******/
		CREATE UNIQUE NONCLUSTERED INDEX [IX_Columns] ON [dbo].[Columns] 
		(
		[ObjectID] ASC,
		[ColumnName] ASC
		) ON [PRIMARY]
		end
	SET @Check = (Select Coalesce(Col_length('Columns','ColumnAlias'),0))
	If @Check=0
		begin
		ALTER TABLE [Columns] ADD 
			[ColumnAlias] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		/*SET @sCommand='UPDATE [Columns] SET ColumnAlias=''C'' + CONVERT(varchar(10), [ColumnID])'
		Exec (@sCommand)*/
		end

	SET @Check = (Select Coalesce(Col_length('Columns','ColumnType'),0))
	If @Check=0
		begin
		ALTER TABLE [Columns] ADD 
			[ColumnType] [varchar] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		SET @sCommand='UPDATE [Columns] SET ColumnType=''D'''
		Exec (@sCommand)
		SET @sCommand='UPDATE [Columns] SET ColumnType=''V'' Where ObjectID In (Select ObjectID FROM [Objects] Where [Type]=''VV'')'
		Exec (@sCommand)
		end

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ColumnOrder' AND o.parent_obj = Object_ID(N'[dbo].[Columns]')) 
		begin
			ALTER TABLE [Columns] ADD CONSTRAINT def_Columns_ColumnOrder DEFAULT (0) FOR [ColumnOrder];
		end
	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ColumnType' AND o.parent_obj = Object_ID(N'[dbo].[Columns]')) 
		begin
			ALTER TABLE [Columns] ADD CONSTRAINT def_Columns_ColumnType DEFAULT ('D') FOR [ColumnType];
		end

	SET @Check = (Select Coalesce(Col_length('Columns','HideColumn'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[Columns] ADD 
			[HideColumn] [int] DEFAULT (0)
		SET @sCommand='UPDATE [Columns] SET HideColumn=0'
		Exec (@sCommand)		
		end

	end


/****** Object:  Table [dbo].[ColumnExplanation] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ColumnExplanation]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ColumnExplanation] (
		[ExplanationID] [bigint] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_ColumnExplanation] PRIMARY KEY CLUSTERED,
		[Explanation] [text] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
	end
else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[ColumnExplanation]') AND name = N'PK_ColumnExplanation')
		begin
		ALTER TABLE [dbo].[ColumnExplanation] ADD CONSTRAINT [PK_ColumnExplanation] PRIMARY KEY CLUSTERED 
		(
		[ExplanationID] ASC
		) ON [PRIMARY]
		end
	end


/****** Object:  Table [dbo].[DatabaseRole] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DatabaseRole]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[DatabaseRole] (
		[DatabaseRoleID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_DatabaseRole] PRIMARY KEY  CLUSTERED,
		[DatabaseID] [int] NOT NULL ,
		[RoleID] [int] NOT NULL 
	) ON [PRIMARY]
	end


/****** Object:  Table [dbo].[UserGroups] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UserGroups]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[UserGroups] (
		[GroupID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_UserGroups] PRIMARY KEY  CLUSTERED ,
		[GroupName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
			CONSTRAINT [SP_GroupNameIdx] UNIQUE  NONCLUSTERED ,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[DefaultTheme] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	) ON [PRIMARY]

	Insert into UserGroups (GroupName) values('Default')
	end
else
	begin
/****** From update_8.1.16 ******/
	SET @Check = (Select Coalesce(Col_length('UserGroups','Description'),0))
	If @Check=0
		ALTER TABLE [UserGroups] ADD 
			[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
/****** From update_9.2.* ******/
	SET @Check = (Select Coalesce(Col_length('UserGroups','DefaultTheme'),0))
	If @Check=0
		ALTER TABLE [UserGroups] ADD 
			[DefaultTheme] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	end

/****** Object:  Table [dbo].[Folder] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Folder]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Folder] (
		[FolderID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_Folder] PRIMARY KEY  CLUSTERED, 
		[FolderName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[OwnerUserID] [int] NOT NULL ,
		[ModifiedUserID] [int] NULL ,
		[FolderType] [int] NOT NULL DEFAULT (1),
		[ParentFolderID] [int] NOT NULL DEFAULT (0),
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[AllRolesAccess] [int] NOT NULL DEFAULT (1),
		[TimeCreated] [datetime] NOT NULL DEFAULT (getdate()),
		[TimeSaved] [datetime] NULL ,
		[DatabaseID] [int] NULL ,
		[GroupID] [int] NULL DEFAULT (0) 
	) ON [PRIMARY]

	CREATE INDEX [Folder_GroupIDIdx] ON [dbo].[Folder]([GroupID]) ON [PRIMARY]
	end
Else
	begin

/****** From update_6.2.0 ******/
	SET @Check = (Select cdefault From syscolumns Where Object_name(id)='Folder' and [name]='FolderType')
	If @Check=0
		ALTER TABLE [dbo].[Folder] WITH NOCHECK ADD 
			CONSTRAINT [DF__Folder__FolderTy__45F365D3] DEFAULT (1) FOR [FolderType]

	SET @Check = (Select cdefault From syscolumns Where Object_name(id)='Folder' and [name]='ParentFolderID')
	If @Check=0
		ALTER TABLE [dbo].[Folder] WITH NOCHECK ADD 
			CONSTRAINT [DF__Folder__ParentFo__46E78A0C] DEFAULT (0) FOR [ParentFolderID]

	SET @Check = (Select cdefault From syscolumns Where Object_name(id)='Folder' and [name]='AllRolesAccess')
	If @Check=0
		ALTER TABLE [dbo].[Folder] WITH NOCHECK ADD 
			CONSTRAINT [DF__Folder__AllRoles__47DBAE45] DEFAULT (1) FOR [AllRolesAccess]

	SET @Check = (Select cdefault From syscolumns Where Object_name(id)='Folder' and [name]='TimeCreated')
	If @Check=0
		ALTER TABLE [dbo].[Folder] WITH NOCHECK ADD 
			CONSTRAINT [DF__Folder__TimeCrea__48CFD27E] DEFAULT (getdate()) FOR [TimeCreated]

/****** From update_7.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('Folder','DatabaseID'),0))
	If @Check=0
		ALTER TABLE [Folder] ADD [DatabaseID] INTEGER

/****** From update_7.2 ******/
	SET @Check = (Select Coalesce(Col_length('Folder','GroupID'),0))
	If @Check=0
		begin
		ALTER TABLE [Folder] ADD [GroupID] INTEGER

		SET @sCommand='UPDATE Folder SET GroupID=(Select top 1 GroupID From UserGroups)'
		Exec (@sCommand)		
		end

	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[Folder]') AND name = N'Folder_GroupIDIdx')
		CREATE INDEX [Folder_GroupIDIdx] ON [dbo].[Folder]([GroupID]) ON [PRIMARY]

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'GroupID' AND o.parent_obj = Object_ID(N'[dbo].[Folder]')) 
		begin
			ALTER TABLE [Folder] ADD CONSTRAINT def_Folder_GroupID DEFAULT (0) FOR [GroupID];
		end
	end


/****** Object:  Table [dbo].[FolderRole] AM ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[FolderRole]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[FolderRole] (
		[FolderRoleID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_FolderRole] PRIMARY KEY  CLUSTERED ,
		[FolderID] [int] NOT NULL ,
		[RoleID] [int] NOT NULL 
	) ON [PRIMARY]
	end


/****** Object:  Table [dbo].[JoinRelationDetails] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[JoinRelationDetails]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[JoinRelationDetails] (
		[JoinRelationDetailsID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_JoinRelationDetails] PRIMARY KEY  CLUSTERED ,
		[JoinRelationID] [int] NOT NULL ,
		[ColumnID1] [int] NOT NULL ,
		[ColumnID2] [int] NOT NULL ,
	) ON [PRIMARY]

	CREATE INDEX [JoinRelationDetails_JoinRelationIDIdx] ON [dbo].[JoinRelationDetails]([JoinRelationID]) ON [PRIMARY]
	end
else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[JoinRelationDetails]') AND name = N'JoinRelationDetails_JoinRelationIDIdx')
		CREATE INDEX [JoinRelationDetails_JoinRelationIDIdx] ON [dbo].[JoinRelationDetails]([JoinRelationID]) ON [PRIMARY]
	end

/****** Object:  Table [dbo].[JoinRelation] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[JoinRelation]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[JoinRelation] (
		[JoinRelationID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_JoinRelation] PRIMARY KEY  CLUSTERED ,
		[ObjectID1] [int] NOT NULL ,
		[Relation] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ObjectID2] [int] NOT NULL ,
		[RelationName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[DatabaseID] [int] NULL ,
		[ObjectLabel1] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ObjectLabel2] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[HideJoin] [tinyint] DEFAULT (0) ,
		[AutoReverse] [tinyint] DEFAULT (1) ,
		[Automatic] [tinyint] DEFAULT (0)
	) ON [PRIMARY]
	end
Else
	begin

/****** From update_6.2.0 ******/
	ALTER TABLE [JoinRelation] ALTER COLUMN
		[RelationName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	
	UPDATE JoinRelation 
		SET RelationName = LEFT((o1.[Description] + ' to ' + o2.[Description]),100)
		FROM ((JoinRelation jr 
		INNER JOIN Objects o1 ON jr.ObjectID1 = o1.ObjectID) 
		INNER JOIN Objects o2 ON jr.ObjectID2 = o2.ObjectID) 
		WHERE RelationName = ''

/****** From update_7.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('JoinRelation','DatabaseID'),0))
	If @Check=0
		ALTER TABLE [JoinRelation] ADD [DatabaseID] [int]

	SET @Check = (Select Coalesce(Col_length('JoinRelation','Automatic'),0))
	If @Check=0
		begin
		ALTER TABLE [JoinRelation] ADD [Automatic] [tinyint] DEFAULT (0)

		SET @sCommand='UPDATE [JoinRelation] SET Automatic=0'
		Exec (@sCommand)		
		end
	
	SET @Check = (Select Coalesce(Col_length('JoinRelation','ObjectLabel1'),0))
	If @Check=0
		ALTER TABLE [JoinRelation] ADD [ObjectLabel1] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

	SET @Check = (Select Coalesce(Col_length('JoinRelation','ObjectLabel2'),0))
	If @Check=0
		ALTER TABLE [JoinRelation] ADD [ObjectLabel2] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

/****** From update_9.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('JoinRelation','ColumnID1'),0))
	If @Check>0
		begin
		SET @sCommand='INSERT INTO JoinRelationDetails ( JoinRelationID, ColumnID1, ColumnID2) SELECT JoinRelationID, ColumnID1, ColumnID2 FROM JoinRelation'
		Exec (@sCommand)	

		ALTER TABLE [JoinRelation] DROP COLUMN [ColumnID1] 
		end
	
	SET @Check = (Select Coalesce(Col_length('JoinRelation','ColumnID2'),0))
	If @Check>0
		ALTER TABLE [JoinRelation] DROP COLUMN [ColumnID2] 

	SET @Check = (Select Coalesce(Col_length('JoinRelation','Description'),0))
	If @Check=0
		ALTER TABLE [JoinRelation] ADD [Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

/****** update_10.0 ******/
	SET @Check = (Select Coalesce(Col_length('JoinRelation','HideJoin'),0))
	If @Check=0
		begin
		ALTER TABLE [JoinRelation] ADD [HideJoin] [tinyint] DEFAULT (0)

		SET @sCommand='UPDATE [JoinRelation] SET HideJoin=0'
		Exec (@sCommand)		
		end

	SET @Check = (Select Coalesce(Col_length('JoinRelation','AutoReverse'),0))
	If @Check=0
		begin
		ALTER TABLE [JoinRelation] ADD [AutoReverse] [tinyint] DEFAULT (1)

		SET @sCommand='UPDATE [JoinRelation] SET AutoReverse=1'
		Exec (@sCommand)		
		end
	
	end

/****** Object:  Table [dbo].[LinkParameters]    Script Date: 10/04/05 11:47:37 AM ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[LinkParameters]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[LinkParameters] (
		[LinkParameterID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_LinkParameters] PRIMARY KEY  CLUSTERED ,
		[ColumnID] [int] NOT NULL DEFAULT (0),
		[ParameterName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ParamDisplayName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ParameterSourceType] [tinyint] NOT NULL DEFAULT (0),
		[ParameterSource] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]

	CREATE INDEX [LP_ColumnIDIdx] ON [dbo].[LinkParameters]([ColumnID]) ON [PRIMARY]
	CREATE INDEX [LinkParameters_ParameterNameIdx] ON [dbo].[LinkParameters]([ParameterName]) ON [PRIMARY]
	end
Else
	begin
	SET @Check = (Select Coalesce(Col_length('LinkParameters','ParamDisplayName'),0))
	If @Check=0
		begin
		ALTER TABLE [LinkParameters] ADD [ParamDisplayName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT e_default Default ''

		SET @sCommand='UPDATE [LinkParameters] SET ParamDisplayName=ParameterName'
		Exec (@sCommand)		
		end
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[LinkParameters]') AND name = N'LinkParameters_ParameterNameIdx')
		CREATE INDEX [LinkParameters_ParameterNameIdx] ON [dbo].[LinkParameters]([ParameterName]) ON [PRIMARY]

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ColumnID' AND o.parent_obj = Object_ID(N'[dbo].[LinkParameters]')) 
		begin
			ALTER TABLE [LinkParameters] ADD CONSTRAINT def_LinkParameters_ColumnID DEFAULT (0) FOR [ColumnID];
		end
	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ParameterSourceType' AND o.parent_obj = Object_ID(N'[dbo].[LinkParameters]')) 
		begin
			ALTER TABLE [LinkParameters] ADD CONSTRAINT def_LinkParameters_ParameterSourceType DEFAULT (0) FOR [ParameterSourceType];
		end
	end


/****** Object:  Table [dbo].[ObjectAccess] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ObjectAccess]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ObjectAccess] (
		[AccessID] [int] NOT NULL 
			CONSTRAINT [PK_ObjectAccess] PRIMARY KEY  CLUSTERED ,
		[AccessName] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]

	Insert Into ObjectAccess Values (0, 'None')
	Insert Into ObjectAccess Values (1, 'Limited')
	Insert Into ObjectAccess Values (2, 'Full')
	end


/****** Object:  Table [dbo].[ObjectParameters] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ObjectParameters]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ObjectParameters] (
		[ObjectParameterID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_ObjectParameters] PRIMARY KEY  CLUSTERED ,
		[ObjectID] [int] NOT NULL DEFAULT (0),
		[ColumnID] [int] NOT NULL DEFAULT (0),
		[Operator] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ParamValue] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[BitCmd] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ParamOrder] [int] NULL ,
		[ParamLevel] [int] NULL ,
		[ParamType] [tinyint] NULL DEFAULT (0) ,
		[ParamName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ParamCaption] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ParamDataType] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ParamDirection] [tinyint] NULL DEFAULT (0) 
	) ON [PRIMARY]

	CREATE INDEX [ObjectParameters_ColumnIDIdx] ON [dbo].[ObjectParameters]([ColumnID]) ON [PRIMARY]
	CREATE INDEX [ObjectParameters_ObjectIDIdx] ON [dbo].[ObjectParameters]([ObjectID]) ON [PRIMARY]
	end
Else
	begin
/****** From update_6.2.12 ******/
	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamOrder'),0))
	If @Check=0
		ALTER TABLE [ObjectParameters] ADD [ParamOrder] [int] 

	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamLevel'),0))
	If @Check=0
		ALTER TABLE [ObjectParameters] ADD [ParamLevel] [int] 

	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[ObjectParameters]') AND name = N'ObjectParameters_ColumnIDIdx')
		CREATE INDEX [ObjectParameters_ColumnIDIdx] ON [dbo].[ObjectParameters]([ColumnID]) ON [PRIMARY]
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[ObjectParameters]') AND name = N'ObjectParameters_ObjectIDIdx')
		CREATE INDEX [ObjectParameters_ObjectIDIdx] ON [dbo].[ObjectParameters]([ObjectID]) ON [PRIMARY]

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ObjectID' AND o.parent_obj = Object_ID(N'[dbo].[ObjectParameters]')) 
		begin
			ALTER TABLE [ObjectParameters] ADD CONSTRAINT def_ObjectParameters_ObjectID DEFAULT (0) FOR [ObjectID];
		end
	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ColumnID' AND o.parent_obj = Object_ID(N'[dbo].[ObjectParameters]')) 
		begin
			ALTER TABLE [ObjectParameters] ADD CONSTRAINT def_ObjectParameters_ColumnID DEFAULT (0) FOR [ColumnID];
		end
		
/****** From update_11.*.* ******/
	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamType'),0))
	If @Check=0
		begin
		ALTER TABLE [ObjectParameters] ADD ParamType tinyint DEFAULT (0)

		SET @sCommand='UPDATE [ObjectParameters] SET ParamType=0'
		Exec (@sCommand)		
		end
	
	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamName'),0))
	If @Check=0
		ALTER TABLE [ObjectParameters] ADD 
			[ParamName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
			
	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamCaption'),0))
	If @Check=0
		ALTER TABLE [ObjectParameters] ADD 
			[ParamCaption] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	
	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamDataType'),0))
	If @Check=0
		ALTER TABLE [ObjectParameters] ADD 
			[ParamDataType] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	
	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamDirection'),0))
	If @Check=0
		begin
		ALTER TABLE [ObjectParameters] ADD ParamDirection tinyint DEFAULT (0)
		
		SET @sCommand='UPDATE [ObjectParameters] SET ParamDirection=0'
		Exec (@sCommand)		
		end
	end


/****** Object:  Table [dbo].[Objects] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Objects]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Objects] (
		[ObjectID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_Objects] PRIMARY KEY  CLUSTERED ,
        [ObjectSchema] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ObjectName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ObjectAlias] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Description] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Type] [varchar] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[DatabaseID] [int] NULL ,
		[Definition] [varchar] (7500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[HideObject] [tinyint] DEFAULT (0), 
		[ExplanationID] [bigint] NULL, 
		[IsCatalogue] [tinyint] DEFAULT (1) 
	) ON [PRIMARY]
	end
Else
	begin

/****** From update_7.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('Objects','DatabaseID'),0))
	If @Check=0
		ALTER TABLE [Objects] ADD [DatabaseID] [int]

/****** From update_7.1.0 ******/
	SET @Check = (Select Coalesce(Col_length('Objects','Definition'),0))
	If @Check=0
		ALTER TABLE [dbo].[Objects] ADD 
			[Definition] [varchar] (7500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

/****** From update_7.2.10 ******/
	SET @Check = (Select Coalesce(Col_length('Objects','HideObject'),0))
	If @Check=0
		begin
		ALTER TABLE [Objects] ADD HideObject tinyint DEFAULT (0)

		SET @sCommand='UPDATE [Objects] SET HideObject=0'
		Exec (@sCommand)		
		end

/****** From update 8.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('Objects','ObjectAlias'),0))
	If @Check=0
		begin
		ALTER TABLE [Objects] ADD 
			[ObjectAlias] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		/*SET @sCommand='UPDATE [Objects] SET ObjectAlias=''O'' + CONVERT(varchar(10), [ObjectID])'
		Exec (@sCommand)*/
		end
/****** From update 8.1.16 *****/
	ALTER TABLE [Objects] ALTER COLUMN 
		[Description] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

/****** From update 10.0.0 *****/
	SET @Check = (Select Coalesce(Col_length('Objects','ObjectSchema'),0))
	If @Check=0
		ALTER TABLE [dbo].[Objects] ADD 
			[ObjectSchema] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

	SET @Check = (Select Coalesce(Col_length('Objects','ExplanationID'),0))
	If @Check=0
		ALTER TABLE [dbo].[Objects] ADD 
			[ExplanationID] [bigint] NULL

	SET @Check = (Select Coalesce(Col_length('Objects','IsCatalogue'),0))
	If @Check=0
		begin
		ALTER TABLE [Objects] ADD IsCatalogue tinyint DEFAULT (1)

		SET @sCommand='UPDATE [Objects] SET IsCatalogue=1'
		Exec (@sCommand)		
		end
	end

/****** Object:  Table [dbo].[ParameterValues] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ParameterValues]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ParameterValues] (
		[ParameterValuesID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_ParameterValues] PRIMARY KEY  CLUSTERED ,
		[ObjectParameterID] [int] NOT NULL ,
		[ParamValue] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ParamValueType] tinyint DEFAULT (0)
	) ON [PRIMARY]
	end
else
	begin
	ALTER TABLE [ParameterValues] ALTER COLUMN
		[ParamValue] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
		
	SET @Check = (Select Coalesce(Col_length('ParameterValues','ParamValueType'),0))
	If @Check=0
		begin
		ALTER TABLE [ParameterValues] ADD ParamValueType tinyint DEFAULT (0)

		SET @sCommand='UPDATE [ParameterValues] SET ParamValueType=0'
		Exec (@sCommand)		
		end
	end

/****** Object:  Table [dbo].[PermissionRights] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[PermissionRights]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[PermissionRights] (
		[PermissionRightID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_PermissionRights] PRIMARY KEY  CLUSTERED ,
		[PermissionID] [int] NOT NULL ,
		[RightID] [int] NOT NULL 
	) ON [PRIMARY]
	end


/****** Object:  Table [dbo].[Permissions] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Permissions]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Permissions] (
		[PermissionID] [int] NOT NULL 
			CONSTRAINT [PK_Permissions] PRIMARY KEY  CLUSTERED ,
		[Permission] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
	) ON [PRIMARY]
	end


/****** Object:  Table [dbo].[ReportParameters] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ReportParameters]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ReportParameters] (
		[ReportParameterID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_ReportParameters] PRIMARY KEY  CLUSTERED ,
		[ReportID] [int] NOT NULL ,
		[ColumnID] [int] NOT NULL ,
		[Operator] [varchar] (25) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[BitCmd] [varchar] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Ask] [int] NULL ,
		[Scheduler] [int] NULL,
		[Caption] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ParamType] [tinyint] NULL DEFAULT (0) ,
		[ParamName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
	) ON [PRIMARY]
	end
else
	begin
/****** From update 9.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('ReportParameters','Caption'),0))
	If @Check=0
		ALTER TABLE [ReportParameters] ADD [Caption] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		
/****** From update_11.*.* ******/
	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamType'),0))
	If @Check=0
		begin
		ALTER TABLE [ObjectParameters] ADD ParamType tinyint DEFAULT (0)

		SET @sCommand='UPDATE [ObjectParameters] SET ParamType=0'
		Exec (@sCommand)		
		end
	
	SET @Check = (Select Coalesce(Col_length('ObjectParameters','ParamName'),0))
	If @Check=0
		ALTER TABLE [ObjectParameters] ADD 
			[ParamName] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
			
	end


/****** Object:  Table [dbo].[ReportParameterValues] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ReportParameterValues]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ReportParameterValues] (
		[ReportParameterValuesID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_ReportParameterValues] PRIMARY KEY CLUSTERED ,
		[ReportParameterID] [int] NOT NULL ,
		[ReportScheduleID] [int] NOT NULL ,
		[ParamValue] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]

	CREATE INDEX [ReportParameterValues_ReportScheduleIDIdx] ON [dbo].[ReportParameterValues]([ReportScheduleID]) ON [PRIMARY]
	end
Else
	begin
/****** From update 9.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('ReportParameterValues','ReportScheduleID'),0))
	If @Check=0
		ALTER TABLE [ReportParameterValues] ADD [ReportScheduleID] [int]

	ALTER TABLE [ReportParameterValues] ALTER COLUMN
		[ParamValue] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL

	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[ReportParameterValues]') AND name = N'ReportParameterValues_ReportScheduleIDIdx')
		CREATE INDEX [ReportParameterValues_ReportScheduleIDIdx] ON [dbo].[ReportParameterValues]([ReportScheduleID]) ON [PRIMARY]
	end

/****** Object:  Table [dbo].[ReportSchedules] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ReportSchedules]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ReportSchedules] (
		[ReportScheduleID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_ReportSchedule] PRIMARY KEY  CLUSTERED ,
		[ReportID] [int] NOT NULL ,
		[ModifiedUserID] [int] NULL ,
		[TimeSaved] [smalldatetime] NULL ,
		[TaskName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[TaskID] [bigint] NULL 
			CONSTRAINT [ReportSchedule_TaskIDIdx] UNIQUE  NONCLUSTERED,
		[OutputFormat] [int] NULL ,
		[Archive] [int] NULL ,
		[Server] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Method] [tinyint] NULL,
		[Broken] [tinyint] NULL
	) ON [PRIMARY]

	CREATE INDEX [ReportSchedules_ReportIDIdx] ON [dbo].[ReportSchedules]([ReportID]) ON [PRIMARY]
	CREATE INDEX [ReportSchedules_ModifiedUserIDIdx] ON [dbo].[ReportSchedules]([ModifiedUserID]) ON [PRIMARY]
	end
else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[ReportSchedules]') AND name = N'ReportSchedules_ReportIDIdx')
		CREATE INDEX [ReportSchedules_ReportIDIdx] ON [dbo].[ReportSchedules]([ReportID]) ON [PRIMARY]
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[ReportSchedules]') AND name = N'ReportSchedules_ModifiedUserIDIdx')
		CREATE INDEX [ReportSchedules_ModifiedUserIDIdx] ON [dbo].[ReportSchedules]([ModifiedUserID]) ON [PRIMARY]

	SET @Check = (Select Coalesce(Col_length('ReportSchedules','TaskID'),0))
	If @Check=0
		ALTER TABLE [ReportSchedules] ADD [TaskID] [bigint]

	SET @Check = (Select Coalesce(Col_length('ReportSchedules','Server'),0))
	If @Check=0
		ALTER TABLE [ReportSchedules] ADD [Server] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

	SET @Check = (Select Coalesce(Col_length('ReportSchedules','Method'),0))
	If @Check=0
		ALTER TABLE [ReportSchedules] ADD [Method] [tinyint]
	end

/****** Object:  Table [dbo].[ReportSessionParameters] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[ReportSessionParameters]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[ReportSessionParameters] (
		[ReportSessionParamID] [bigint] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [IX_ReportSessionParameters] UNIQUE  NONCLUSTERED ,
		[ReportID] [int] NOT NULL DEFAULT (0),
		[UserID] [int] NOT NULL DEFAULT (0),
		[ParamName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[ParamValue] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		CONSTRAINT [PK_ReportSessionParameters] PRIMARY KEY  CLUSTERED 
		(
			[ReportID],
			[UserID],
			[ParamName]
		)  

	) ON [PRIMARY]

	CREATE INDEX [ReportSessionParameters_ReportIDIdx] ON [dbo].[ReportSessionParameters]([ReportID]) ON [PRIMARY]
	CREATE INDEX [ReportSessionParameters_UserIDIdx] ON [dbo].[ReportSessionParameters]([UserID]) ON [PRIMARY]
	end
Else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[ReportSessionParameters]') AND name = N'ReportSessionParameters_ReportIDIdx')
		CREATE INDEX [ReportSessionParameters_ReportIDIdx] ON [dbo].[ReportSessionParameters]([ReportID]) ON [PRIMARY]
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[ReportSessionParameters]') AND name = N'ReportSessionParameters_UserIDIdx')
		CREATE INDEX [ReportSessionParameters_UserIDIdx] ON [dbo].[ReportSessionParameters]([UserID]) ON [PRIMARY]

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ReportID' AND o.parent_obj = Object_ID(N'[dbo].[ReportSessionParameters]')) 
		begin
			ALTER TABLE [ReportSessionParameters] ADD CONSTRAINT def_ReportSessionParameters_ReportID DEFAULT (0) FOR [ReportID];
		end
	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'UserID' AND o.parent_obj = Object_ID(N'[dbo].[ReportSessionParameters]')) 
		begin
			ALTER TABLE [ReportSessionParameters] ADD CONSTRAINT def_ReportSessionParameters_UserID DEFAULT (0) FOR [UserID];
		end

	ALTER TABLE [ReportSessionParameters] ALTER COLUMN
		[ParamValue] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	end

/****** Object:  Table [dbo].[Rights] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Rights]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Rights] (
		[RightID] [int] NOT NULL 
			CONSTRAINT [PK_Rights] PRIMARY KEY  CLUSTERED ,
		[RightName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[RightGroup] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]
	end
else
	begin
	ALTER TABLE [Rights] ALTER COLUMN RightGroup [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL;
	end

/****** Object:  Table [dbo].[Role] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Role]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Role] (
		[RoleID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_Role] PRIMARY KEY CLUSTERED ,
		[RoleName] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
			CONSTRAINT [Role_RoleNameIdx] UNIQUE NONCLUSTERED,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	) ON [PRIMARY]

	SET @sCommand='Insert into [Role] (RoleName) values (''System Admin'')'
	Exec (@sCommand)
	end
Else
	begin

/****** From update_7.2 ******/
	SET @Check = (Select Count(*) FROM [Role] WHERE RoleName='System Admin')
	If @Check=0
		UPDATE [dbo].[Role] SET RoleName='System Admin' WHERE RoleName='Admin'

/****** From update_8.1.16 ******/
	SET @Check = (Select Coalesce(Col_length('Role','Description'),0))
	If @Check=0
		ALTER TABLE [Role] ADD 
			[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[Role]') AND name = N'Role_RoleNameIdx')
		begin
			/****** From update_10.0.0 ******/
			ALTER TABLE [Role] ALTER COLUMN RoleName [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL;

			CREATE UNIQUE INDEX [Role_RoleNameIdx] ON [dbo].[Role]([RoleName]) ON [PRIMARY]
		end
	end

/****** Object:  Table [dbo].[RoleColumns] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RoleColumns]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[RoleColumns] (
		[RoleID] [int] NOT NULL ,
		[ColumnID] [int] NOT NULL ,
		[AccessType] [int] NOT NULL ,
		CONSTRAINT [PK_RoleColumns] PRIMARY KEY  CLUSTERED 
		(
			[RoleID],
			[ColumnID]
		)  
	) ON [PRIMARY]

	CREATE INDEX [RoleColumns_RoleIDIdx] ON [dbo].[RoleColumns]([RoleID]) ON [PRIMARY]
	CREATE INDEX [RoleColumns_ColumnIDIdx] ON [dbo].[RoleColumns]([ColumnID]) ON [PRIMARY]

	end
Else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[RoleColumns]') AND name = N'RoleColumns_RoleIDIdx')
		CREATE INDEX [RoleColumns_RoleIDIdx] ON [dbo].[RoleColumns]([RoleID]) ON [PRIMARY]
	
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[RoleColumns]') AND name = N'RoleColumns_ColumnIDIdx')
		CREATE INDEX [RoleColumns_ColumnIDIdx] ON [dbo].[RoleColumns]([ColumnID]) ON [PRIMARY]

/****** From update_10.0.0 ******/
	SET @sCommand='DELETE FROM RoleColumns WHERE AccessType=1'
	Exec (@sCommand)
	end

/****** Object:  Table [dbo].[RoleObjects] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RoleObjects]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[RoleObjects] (
		[RoleID] [int] NOT NULL ,
		[ObjectID] [int] NOT NULL ,
		[AccessType] [int] NOT NULL ,
		CONSTRAINT [PK_RoleObjects] PRIMARY KEY  CLUSTERED 
		(
			[RoleID],
			[ObjectID]
		)  
	) ON [PRIMARY]

	CREATE INDEX [RoleObjects_RoleIDIdx] ON [dbo].[RoleObjects]([RoleID]) ON [PRIMARY]
	CREATE INDEX [RoleObjects_ObjectIDIdx] ON [dbo].[RoleObjects]([ObjectID]) ON [PRIMARY]

	end
Else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[RoleObjects]') AND name = N'RoleObjects_RoleIDIdx')
		CREATE INDEX [RoleObjects_RoleIDIdx] ON [dbo].[RoleObjects]([RoleID]) ON [PRIMARY]
	
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[RoleObjects]') AND name = N'RoleObjects_ObjectIDIdx')
		CREATE INDEX [RoleObjects_ObjectIDIdx] ON [dbo].[RoleObjects]([ObjectID]) ON [PRIMARY]

/****** From update_10.0.0 ******/
	SET @sCommand='DELETE FROM RoleObjects WHERE AccessType=2'
	Exec (@sCommand)

	end

/****** Object:  Table [dbo].[RolePermissions] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[RolePermissions]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[RolePermissions] (
		[RolePermissionID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_RolePermissions] PRIMARY KEY  CLUSTERED ,
		[RoleID] [int] NOT NULL ,
		[PermissionID] [int] NOT NULL 
	) ON [PRIMARY]

	SET @sCommand='Insert into [RolePermissions] (RoleID, PermissionID) Values (1,1)'
	Exec (@sCommand)	
	end

/****** Object:  Table [dbo].[SessionParameters] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SessionParameters]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[SessionParameters] (
		[SessionParameterID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_SessionParameters] PRIMARY KEY  CLUSTERED ,
		[ParameterName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
			CONSTRAINT [SP_ParameterNameIdx] UNIQUE  NONCLUSTERED ,
		[DefaultValue] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL  ,
		[DataTypeCategory] [int] NULL DEFAULT (2)
	) ON [PRIMARY]
	end
Else
	begin
	SET @Check = (Select Coalesce(Col_length('SessionParameters','DataTypeCategory'),0))
	If @Check=0
		begin
		ALTER TABLE [SessionParameters] ADD 
			[DataTypeCategory] [int] NULL DEFAULT (2)
			
		SET @sCommand='UPDATE [SessionParameters] SET [DataTypeCategory]=2'
		Exec (@sCommand)
		end

	ALTER TABLE [SessionParameters] ALTER COLUMN
		[DefaultValue] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	end

/****** Object:  Table [dbo].[SourceDatabase] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SourceDatabase]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[SourceDatabase] (
		[DatabaseID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_SourceDatabase] PRIMARY KEY  CLUSTERED ,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
	) ON [PRIMARY]
	end


/****** Object:  Table [dbo].[SystemSetting] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[SystemSetting]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[SystemSetting] (
		[SettingName] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
		[SettingValue] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Description] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[DatabaseID] [int] NOT NULL,
		CONSTRAINT [PK_SystemSetting] PRIMARY KEY  NONCLUSTERED 
		(
			[SettingName],
			[DatabaseID]
		)  
	) ON [PRIMARY]

	CREATE INDEX [SystemSetting_DatabaseIDIdx] ON [dbo].[SystemSetting]([DatabaseID]) ON [PRIMARY]
	CREATE INDEX [SystemSetting_SettingNameIdx] ON [dbo].[SystemSetting]([SettingName]) ON [PRIMARY]
	end
Else
	begin

/****** From update_7.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('SystemSetting','DatabaseID'),0))
	If @Check=0
		begin
		ALTER TABLE [SystemSetting] ADD [DatabaseID] [int] NOT NULL CONSTRAINT e_default Default (1)

		IF EXISTS (SELECT name FROM sysindexes WHERE name = 'PK_SystemSetting')
		   	ALTER TABLE SystemSetting DROP CONSTRAINT PK_SystemSetting

		SET @sCommand='ALTER TABLE [dbo].[SystemSetting] WITH NOCHECK ADD CONSTRAINT [PK_SystemSetting] PRIMARY KEY  NONCLUSTERED ([SettingName],[DatabaseID]) ON [PRIMARY]'
		Exec (@sCommand)		
/*	
		ALTER TABLE [dbo].[SystemSetting] WITH NOCHECK ADD 
			CONSTRAINT [PK_SystemSetting] PRIMARY KEY  NONCLUSTERED 
			(
				[SettingName],
				[DatabaseID]
			)  ON [PRIMARY] 
*/
		IF EXISTS (SELECT name FROM sysobjects WHERE name = 'e_default')
			ALTER TABLE SystemSetting DROP CONSTRAINT e_default
		end

	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[SystemSetting]') AND name = N'SystemSetting_DatabaseIDIdx')
		CREATE INDEX [SystemSetting_DatabaseIDIdx] ON [dbo].[SystemSetting]([DatabaseID]) ON [PRIMARY]
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[SystemSetting]') AND name = N'SystemSetting_SettingNameIdx')
		CREATE INDEX [SystemSetting_SettingNameIdx] ON [dbo].[SystemSetting]([SettingName]) ON [PRIMARY]
	end

/****** Object:  Table [dbo].[Templates] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Templates]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Templates] (
		[TemplateID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_Templates] PRIMARY KEY  CLUSTERED ,
		[TemplateName] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[TemplateKey] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
		[TemplateType] [tinyint] NOT NULL DEFAULT (0),
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[OwnerID] [int] NULL ,
		[UsedObjects] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[UsedColumns] [varchar] (6000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[IsDefault] [tinyint] NOT NULL DEFAULT (0) ,
		[IsAvailable] [tinyint] NOT NULL DEFAULT (1),
		[SortOrder] [int] NULL ,
		[RightName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
	) ON [PRIMARY]
	
	CREATE INDEX [Templates_TemplateTypeIdx] ON [dbo].[Templates]([TemplateType]) ON [PRIMARY]

	SET @sCommand='INSERT INTO Templates (TemplateName, Description, IsDefault, SortOrder, RightName) VALUES (''Tabular Report with Header'', ''Start with a tabular report with a header.'', 0, 1, '''')'
	Exec (@sCommand)
	SET @sCommand='INSERT INTO Templates (TemplateName, Description, IsDefault, SortOrder, RightName) VALUES (''Tabular Report without Header'', ''Start with a tabular report without a header or style.'', 1, 2, '''')'
	Exec (@sCommand)
	SET @sCommand='INSERT INTO Templates (TemplateName, Description, IsDefault, SortOrder, RightName) VALUES (''Crosstab Report'', ''Start with a crosstab, also known as a pivot table.'', 0, 3, ''RB_CTB'')'
	Exec (@sCommand)
	SET @sCommand='INSERT INTO Templates (TemplateName, Description, IsDefault, SortOrder, RightName) VALUES (''Bar Chart'', ''Start with a bar chart without header or style.'', 0, 4, ''RB_BCT'')'
	Exec (@sCommand)
	SET @sCommand='INSERT INTO Templates (TemplateName, Description, IsDefault, SortOrder, RightName) VALUES (''Tabular Report with Chart'', ''Start with a tabular report and a pie chart.'', 0, 5, ''RB_PCT'')'
	Exec (@sCommand)
	SET @sCommand='INSERT INTO Templates (TemplateName, Description, IsDefault, SortOrder, RightName) VALUES (''Tabular Report with Export'', ''Start with a tabular report with export to Excel, Word, and PDF.'', 0, 6, ''RB_XLS,RB_WRD,RB_PDF'')'
	Exec (@sCommand)

	end
Else
	begin
	/****** From update 10.1.0 ******/
	SET @Check = (Select Coalesce(Col_length('Templates','RightName'),0))
	If @Check=0
		begin
			ALTER TABLE [dbo].[Templates] ADD [RightName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

			SET @sCommand='UPDATE Templates SET RightName=''RB_CTB'' WHERE TemplateID=3'
			Exec (@sCommand)
			SET @sCommand='UPDATE Templates SET RightName=''RB_BCT'' WHERE TemplateID=4'
			Exec (@sCommand)
			SET @sCommand='UPDATE Templates SET RightName=''RB_PCT'' WHERE TemplateID=5'
			Exec (@sCommand)
			SET @sCommand='UPDATE Templates SET RightName=''RB_XLS,RB_WRD,RB_PDF'' WHERE TemplateID=6'
			Exec (@sCommand)
		end
	end

/****** Object:  Table [dbo].[UserGroupRoles] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UserGroupRoles]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[UserGroupRoles] (
		[UserGroupRoleID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_UserGroupRoles] PRIMARY KEY  CLUSTERED ,
		[GroupID] [int] NOT NULL ,
		[RoleID] [int] NOT NULL 
	) ON [PRIMARY]

	SET @sCommand='Insert into UserGroupRoles select [GroupID], [RoleID] from UserGroups, Role'
	Exec (@sCommand)		
	end


/****** Object:  Table [dbo].[UserGroupSessions] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UserGroupSessions]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[UserGroupSessions] (
		[UserGroupSessionID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_UserGroupSessions] PRIMARY KEY  CLUSTERED ,
		[GroupID] [int] NOT NULL ,
		[SessionParameterID] [int] NOT NULL ,
		[SessionParameterValue] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]

	CREATE  INDEX [UGS_GroupIDIdx] ON [dbo].[UserGroupSessions]([GroupID]) ON [PRIMARY]

	CREATE  INDEX [UGS_SessionParameterIDIdx] ON [dbo].[UserGroupSessions]([SessionParameterID]) ON [PRIMARY]
	end
Else
	begin
	ALTER TABLE [UserGroupSessions] ALTER COLUMN
		[SessionParameterValue] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	end

/****** Object:  Table [dbo].[UserSessions] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UserSessions]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[UserSessions] (
		[UserSessionID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_UserSessions] PRIMARY KEY  CLUSTERED ,
		[UserID] [int] NOT NULL ,
		[SessionParameterID] [int] NOT NULL ,
		[SessionParameterValue] [varchar] (4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
	) ON [PRIMARY]

	CREATE  INDEX [US_UserIDIdx] ON [dbo].[UserSessions]([UserID]) ON [PRIMARY]
	CREATE  INDEX [US_SessionParameterIDIdx] ON [dbo].[UserSessions]([SessionParameterID]) ON [PRIMARY]
	end

/****** Object:  Table [dbo].[UserProfile] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UserProfile]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[UserProfile] (
		[UserProfileID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_UserProfile] PRIMARY KEY  CLUSTERED ,
		[UserID] [int] NOT NULL ,
		[PropertyName] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[PropertyValue] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 
	) ON [PRIMARY]

	CREATE INDEX [UserProfile_UserIDIdx] ON [dbo].[UserProfile]([UserID]) ON [PRIMARY]
	end
Else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[UserProfile]') AND name = N'UserProfile_UserIDIdx')
		CREATE INDEX [UserProfile_UserIDIdx] ON [dbo].[UserProfile]([UserID]) ON [PRIMARY]
	end

/****** Object:  Table [dbo].[UserReport] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UserReport]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[UserReport] (
		[ID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_UserReport] PRIMARY KEY  CLUSTERED ,
		[UserID] [int] NOT NULL ,
		[FolderType] [int] NOT NULL 
			CONSTRAINT [DF_UserReport_FolderType] DEFAULT (1) ,
		[ReportName] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL DEFAULT ('New') ,
		[Description] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[TimeCreated] [smalldatetime] NOT NULL DEFAULT (getdate()) ,
		[TimeSaved] [smalldatetime] NULL ,
		[ParentFolderID] [int] NOT NULL DEFAULT (0) ,
		[ModifiedUserID] [int] NULL ,
		[DatabaseID] [int] NULL ,
		[UsedDatabases] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[UsedObjects] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[UsedColumns] [varchar] (6000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[UsedRelationships] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[UsedCascadingFilters] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[UsedClasses] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[UsedFormats] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[GroupID] [int] NULL DEFAULT (0) , 
		[PhysicalName] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Broken] [tinyint] NULL ,
		[BreakReason] [bigint] NULL ,
		[LastViewDate] [smalldatetime] NULL ,
		[LastViewUserID] [int] NULL , 
		[ViewCount] [bigint] NULL DEFAULT (0) ,
		[Dashboard] [tinyint] NOT NULL DEFAULT (0),
		[Mobile] [tinyint] NOT NULL DEFAULT (0),
		[ExpirationDate] [smalldatetime] NULL,
		[ReportGUID] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	) ON [PRIMARY]

	CREATE INDEX [UserReport_GroupIDIdx] ON [dbo].[UserReport]([GroupID]) ON [PRIMARY]
	CREATE INDEX [UserReport_LastViewUserIDIdx] ON [dbo].[UserReport]([LastViewUserID]) ON [PRIMARY]

	end
Else
	begin
	
/****** From update_6.2.0 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','ParentFolderID'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD ParentFolderID INTEGER NOT NULL DEFAULT (0)
	
	SET @Check = (Select Coalesce(Col_length('UserReport','ModifiedUserID'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD ModifiedUserID INTEGER

	SET @Check = (Select cdefault From syscolumns Where Object_name(id)='UserReport' and [name]='ParentFolderID')
	If @Check=0
		ALTER TABLE [dbo].[UserReport] WITH NOCHECK ADD 
			CONSTRAINT [DF__UserRepor__Paren__4316F928] DEFAULT (0) FOR [ParentFolderID]

/****** From update_7.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','DatabaseID'),0))
	If @Check=0
		ALTER TABLE [UserReport] ADD [DatabaseID] [int]

/****** From update_7.1.7 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','UsedObjects'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD 
			[UsedObjects] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 

	SET @Check = (Select Coalesce(Col_length('UserReport','UsedColumns'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD 
			[UsedColumns] [varchar] (6000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

/****** From update_7.2 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','GroupID'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[UserReport] ADD [GroupID] INTEGER

		SET @sCommand='UPDATE UserReport SET GroupID=(Select top 1 GroupID From UserGroups)'
		Exec (@sCommand)		
		end

/****** From update_7.2.10 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','PhysicalName'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [PhysicalName] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL 

/****** From update 8.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','Broken'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [Broken] [tinyint] NULL

	SET @Check = (Select Coalesce(Col_length('UserReport','BreakReason'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [BreakReason] [bigint] NULL
	
/****** From update 9.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','LastViewDate'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [LastViewDate] [smalldatetime] NULL

	SET @Check = (Select Coalesce(Col_length('UserReport','LastViewUserID'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [LastViewUserID] [int] NULL

	SET @Check = (Select Coalesce(Col_length('UserReport','ViewCount'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [ViewCount] [bigint] NULL DEFAULT (0)

	SET @Check = (Select Coalesce(Col_length('UserReport','TaskName'),0))
	If @Check>0
		begin
		SET @sCommand='INSERT INTO ReportSchedules ( ReportID, ModifiedUserID, TaskName, OutputFormat, Archive, Broken ) SELECT ID, ModifiedUserID, TaskName, OutputFormat, Archive, 0 FROM UserReport WHERE TaskName IS NOT NULL'
		Exec (@sCommand)	

		SET @sCommand='UPDATE ReportParameterValues SET ReportScheduleID = rs.ReportScheduleID FROM ((ReportParameterValues AS rpv INNER JOIN ReportParameters AS rp ON (rpv.ReportParameterID=rp.ReportParameterID)) INNER JOIN ReportSchedules AS rs ON (rp.ReportID=rs.ReportID))'
		Exec (@sCommand)	

		ALTER TABLE [UserReport] DROP COLUMN [TaskName] 
		end

	SET @Check = (Select Coalesce(Col_length('UserReport','OutputFormat'),0))
	If @Check>0
		ALTER TABLE [UserReport] DROP COLUMN [OutputFormat]

	SET @Check = (Select Coalesce(Col_length('UserReport','Archive'),0))
	If @Check>0
		ALTER TABLE [UserReport] DROP COLUMN [Archive]

	SET @Check = (Select Coalesce(Col_length('UserReport','Dashboard'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[UserReport] ADD [Dashboard] [tinyint] NULL DEFAULT (0)
		SET @sCommand='UPDATE [UserReport] SET Dashboard=0'
		Exec (@sCommand)		
		ALTER TABLE [UserReport] ALTER COLUMN Dashboard [tinyint] NOT NULL
		end

/****** From update 9.1.0 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','ExpirationDate'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [ExpirationDate] [smalldatetime] NULL
	
	ALTER TABLE [UserReport] ALTER COLUMN
		[ReportName] [varchar] (200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[UserReport]') AND name = N'UserReport_GroupIDIdx')
		CREATE INDEX [UserReport_GroupIDIdx] ON [dbo].[UserReport]([GroupID]) ON [PRIMARY]
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[UserReport]') AND name = N'UserReport_LastViewUserIDIdx')
		CREATE INDEX [UserReport_LastViewUserIDIdx] ON [dbo].[UserReport]([LastViewUserID]) ON [PRIMARY]

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'GroupID' AND o.parent_obj = Object_ID(N'[dbo].[UserReport]')) 
		begin
			ALTER TABLE [UserReport] ADD CONSTRAINT def_UserReport_GroupID DEFAULT (0) FOR [GroupID];
		end
	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'ReportName' AND o.parent_obj = Object_ID(N'[dbo].[UserReport]')) 
		begin
			ALTER TABLE [UserReport] ADD CONSTRAINT def_UserReport_ReportName DEFAULT ('New') FOR [ReportName];
		end

/****** From update 10.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','UsedRelationships'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [UsedRelationships] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	SET @Check = (Select Coalesce(Col_length('UserReport','UsedCascadingFilters'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [UsedCascadingFilters] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	SET @Check = (Select Coalesce(Col_length('UserReport','UsedClasses'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [UsedClasses] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
	SET @Check = (Select Coalesce(Col_length('UserReport','UsedFormats'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [UsedFormats] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL

/****** From update 10.1.0 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','ReportGUID'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserReport] ADD [ReportGUID] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
		
	SET @Check = (Select Coalesce(Col_length('UserReport','Mobile'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[UserReport] ADD [Mobile] [tinyint] NULL DEFAULT (0)
		SET @sCommand='UPDATE [UserReport] SET Mobile=0'
		Exec (@sCommand)		
		ALTER TABLE [UserReport] ALTER COLUMN Mobile [tinyint] NOT NULL
		end
/****** From update 10.2.23 ******/
	SET @Check = (Select Coalesce(Col_length('UserReport','UsedDatabases'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[UserReport] ADD [UsedDatabases] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL		
		SET @sCommand='UPDATE UserReport SET UsedDatabases=DatabaseID WHERE Dashboard IS NULL OR Dashboard<>1'
		Exec (@sCommand)
		end
	end


/****** Object:  Table [dbo].[Users] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[Users]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[Users] (
		[UserID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_Users] PRIMARY KEY  CLUSTERED ,
		[UserName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL 
			CONSTRAINT [Users_UserNameIdx] UNIQUE NONCLUSTERED,
		[Password] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[FirstName] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[LastName] [varchar] (20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[Email] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[LastDatabaseID] [int] NULL ,
		[GroupID] [int] NULL DEFAULT (0) ,
		[Locked] [tinyint] NULL DEFAULT (0) ,
		[LastPasswordChange] [smalldatetime] NULL 
	) ON [PRIMARY]

	CREATE INDEX [Users_GroupIDIdx] ON [dbo].[Users]([GroupID]) ON [PRIMARY]

	SET @sCommand='Insert into [Users] (UserName, [Password], FirstName, [GroupID]) Values (''Admin'', ''password'', ''Administrator'', 1)'
	Exec (@sCommand)		
			
	end
Else
	begin

/****** From update_7.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('Users','LastDatabaseID'),0))
	If @Check=0
		ALTER TABLE [Users] ADD [LastDatabaseID] [int]

	ALTER TABLE [Users] ALTER COLUMN
		[Password] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL

/****** From update_7.2 ******/
	SET @Check = (Select Coalesce(Col_length('Users','GroupID'),0))
	If @Check=0
		begin
		ALTER TABLE [dbo].[Users] ADD [GroupID] INTEGER

		SET @sCommand='UPDATE [Users] SET GroupID=(Select top 1 GroupID From UserGroups)'
		Exec (@sCommand)		
		end

	ALTER TABLE [dbo].[Users] ALTER COLUMN
		[UserName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL	

	SET @Check = (Select Coalesce(Col_length('Users','Locked'),0))
	If @Check=0
		begin
		ALTER TABLE [Users] ADD [Locked] [tinyint] NULL DEFAULT (0)

		SET @sCommand='UPDATE [Users] SET Locked=0'
		Exec (@sCommand)	
		end
	
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[Users]') AND name = N'Users_UserNameIdx')
		CREATE UNIQUE INDEX [Users_UserNameIdx] ON [dbo].[Users]([UserName]) ON [PRIMARY]
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[Users]') AND name = N'Users_GroupIDIdx')
		CREATE INDEX [Users_GroupIDIdx] ON [dbo].[Users]([GroupID]) ON [PRIMARY]

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'GroupID' AND o.parent_obj = Object_ID(N'[dbo].[Users]')) 
		begin
			ALTER TABLE [Users] ADD CONSTRAINT def_Users_GroupID DEFAULT (0) FOR [GroupID];
		end
--	ALTER TABLE [Users] ALTER COLUMN [GroupID] [int] NULL DEFAULT (0);

/****** From update_10.0 *********/
	SET @Check = (Select Coalesce(Col_length('Users','LastPasswordChange'),0))
	If @Check=0
		ALTER TABLE [dbo].[Users] ADD [LastPasswordChange] [smalldatetime] NULL
	end


/****** Object:  Table [dbo].[UserRole] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UserRole]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[UserRole] (
		[UserID] [int] NOT NULL ,
		[RoleID] [int] NOT NULL ,
		CONSTRAINT [PK_UserRole] PRIMARY KEY  CLUSTERED 
		(
			[UserID],
			[RoleID]
		)  
	) ON [PRIMARY]

	CREATE INDEX [UserRole_UserIDIdx] ON [dbo].[UserRole]([UserID]) ON [PRIMARY]
	CREATE INDEX [UserRole_RoleIDIdx] ON [dbo].[UserRole]([RoleID]) ON [PRIMARY]

	SET @sCommand='Insert into [UserRole] select UserID, RoleID from [Users], [Role]'
	Exec (@sCommand)		
	end
Else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[UserRole]') AND name = N'UserRole_UserIDIdx')
		CREATE INDEX [UserRole_UserIDIdx] ON [dbo].[UserRole]([UserID]) ON [PRIMARY]
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[UserRole]') AND name = N'UserRole_RoleIDIdx')
		CREATE INDEX [UserRole_RoleIDIdx] ON [dbo].[UserRole]([RoleID]) ON [PRIMARY]
	end

/****** Object:  Table [dbo].[UserScheduleSubscription] ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UserScheduleSubscription]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[UserScheduleSubscription] (
		[SubscriptionID] [int] IDENTITY (1, 1) NOT NULL 
			CONSTRAINT [PK_UserScheduleSubscription] PRIMARY KEY  CLUSTERED ,
		[UserID] [int] NOT NULL ,
		[ReportScheduleID] [int] NOT NULL, 
		[Broken] [tinyint] DEFAULT (0) 
	) ON [PRIMARY]

	CREATE INDEX [UserScheduleSubscription_ReportScheduleIDIdx] ON [dbo].[UserScheduleSubscription]([ReportScheduleID]) ON [PRIMARY]

	end
Else
	begin
/****** From update 9.0.0 ******/
	SET @Check = (Select Coalesce(Col_length('UserScheduleSubscription','ReportScheduleID'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserScheduleSubscription] ADD [ReportScheduleID] [int]

	SET @Check = (Select Coalesce(Col_length('UserScheduleSubscription','ReportID'),0))
	If @Check>0
		begin

		SET @sCommand='UPDATE UserScheduleSubscription SET ReportScheduleID = rs.ReportScheduleID From UserScheduleSubscription AS uss INNER JOIN ReportSchedules AS rs ON (uss.ReportID=rs.ReportID)'
		Exec (@sCommand)

		ALTER TABLE [dbo].[UserScheduleSubscription] DROP COLUMN ReportID
		end

	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[UserScheduleSubscription]') AND name = N'UserScheduleSubscription_ReportScheduleIDIdx')
		CREATE INDEX [UserScheduleSubscription_ReportScheduleIDIdx] ON [dbo].[UserScheduleSubscription]([ReportScheduleID]) ON [PRIMARY]

	SET @Check = (Select Coalesce(Col_length('UserScheduleSubscription','Broken'),0))
	If @Check=0
		ALTER TABLE [dbo].[UserScheduleSubscription] ADD [Broken] [tinyint] Default (0)
	end


/****** From update 9.1.0 ******/
/****** Object:  Table [dbo].[DataFormats]   ******/
if not exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[DataFormats]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	begin
	CREATE TABLE [dbo].[DataFormats] (
		[FormatID] [int] IDENTITY (1, 1) NOT NULL ,
		[FormatKey] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[FormatName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Format] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL ,
		[Internal] [tinyint] NOT NULL DEFAULT (0) ,
		[AppliesTo] [int] NOT NULL DEFAULT (0),
		[Explanation] [varchar] (255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL , 
		[ExampleBefore] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[ExampleAfter] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL ,
		[IsAvailable] [tinyint] NOT NULL DEFAULT (1) ,
		[SortOrder] [int] DEFAULT (0),
		CONSTRAINT [PK_DataFormats] PRIMARY KEY  CLUSTERED 
		(
			[FormatID] ASC
		)  
	) ON [PRIMARY]

	CREATE INDEX [DataFormats_SortOrderIdx] ON [dbo].[DataFormats]([SortOrder]) ON [PRIMARY]

                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('GeneralNumber','General Number', 'General Number', 1, 9, 1)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('Currency','Currency', 'Currency', 1, 9, 2)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('IntegerFormat','Integer', '#0', 1, 9, 3)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('Fixed','Fixed', 'Fixed', 1, 9, 4)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('Standard','Standard', 'Standard', 1, 9, 5)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('Percent','Percent', 'Percent', 1, 9, 6)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('Scientific','Scientific', 'Scientific', 1, 9, 7)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('TwoDigit','2-digit place holder', '2-digit place holder', 1, 9, 8)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('ThreeDigit','3-digit place holder', '3-digit place holder', 1, 9, 9)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('GeneralDate','General Date', 'General Date', 1, 10, 10)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('LongDate','Long Date', 'Long Date', 1, 10, 11)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, IsAvailable, SortOrder) VALUES
                                    ('MediumDate','Medium Date', 'Medium Date', 1, 10, 0, 12)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('ShortDate','Short Date', 'Short Date', 1, 10, 13)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('LongTime','Long Time', 'Long Time', 1, 10, 14)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, IsAvailable, SortOrder) VALUES
                                    ('MediumTime','Medium Time', 'Medium Time', 1, 10, 0, 15)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('ShortTime','Short Time', 'Short Time', 1, 10, 16)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('YesNo','Yes/No', 'Yes/No', 1, 12, 17)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('TrueFalse','True/False', 'True/False', 1, 12, 18)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('OnOff','On/Off', 'On/Off', 1, 12, 19)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('PreserveLineFeeds','Preserve Line Feeds', 'Preserve Line Feeds', 1, 8, 20)
                INSERT INTO DataFormats (FormatKey, FormatName, Format, Internal, AppliesTo, SortOrder) VALUES
                                    ('HTML','HTML', 'HTML', 2, 8, 21)
	end
Else
	begin
	IF NOT EXISTS (SELECT * FROM sysindexes WHERE [id] = OBJECT_ID(N'[dbo].[DataFormats]') AND name = N'DataFormats_SortOrderIdx')
		CREATE INDEX [DataFormats_SortOrderIdx] ON [dbo].[DataFormats]([SortOrder]) ON [PRIMARY]

	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'SortOrder' AND o.parent_obj = Object_ID(N'[dbo].[DataFormats]')) 
		begin
			ALTER TABLE [DataFormats] ADD CONSTRAINT def_DataFormats_SortOrder DEFAULT (0) FOR [SortOrder];
		end
	IF NOT EXISTS (Select count(O.name) from dbo.syscolumns c inner join sysObjects O on (o.id=c.cdefault) where c.name = N'AppliesTo' AND o.parent_obj = Object_ID(N'[dbo].[DataFormats]')) 
		begin
			ALTER TABLE [DataFormats] ADD CONSTRAINT def_DataFormats_AppliesTo DEFAULT (0) FOR [AppliesTo];
		end
--	ALTER TABLE [DataFormats] ALTER COLUMN [SortOrder] [int] DEFAULT (0);
	end
	
GO

/****** Object:  Stored Procedure dbo.authenticateUser ******/
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[authenticateUser]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[authenticateUser]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS OFF 
GO

CREATE PROCEDURE [authenticateUser] (
	@prmUser	varchar (50),
	@prmPass	varchar (100) )

AS

SELECT [Users].[UserName], [Users].[UserID]
FROM [Users]
WHERE [Users].[UserName] = @prmUser AND [Users].[Password]=@prmPass
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

