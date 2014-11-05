DECLARE @ErrorMsg nvarchar(max);
DECLARE @DateStart datetime;
DECLARE @DateEnd datetime;
SET @ErrorMsg = ''

BEGIN TRY
	BEGIN TRANSACTION

	SET @DateStart = GetDate();

	/*
	* The script is intended to be launched immediately after restoring a copy of production database into a staging
	* environment. It will obfuscate e-mail addresses and will reset the passwords so that the real user aren't notified
	* by the staging environment. Will not touch users from demo, acme and dev tenant.
	*
	* This has to be run from MI schema context. It will try to refer [MI-ADHOC] schema, please update if necessary.
	*/

	DECLARE
		@EmailPrefix		varchar(100),
		@MobilePrefix		varchar(100),
		@DefaultPassword	varchar(100),
		@OldPassword		varchar(100),
		@DefaultEmail		varchar(100),
		@DefaultPhone		varchar(100),
		@ApplicationUrl		varchar(100),
		@IPPortal		varchar(100)
	;

	SELECT
		@EmailPrefix		= 'abc.',
		@MobilePrefix		= '999.',
		@DefaultPassword	= 'VG91Z2hQdw==',
		@OldPassword		= 'VG91Z2hQdw==',
		@DefaultEmail		= 'lillig@mobileinsight.com',
		@DefaultPhone		= '111-222-3333',
		@ApplicationUrl		= 'staging.mobileinsight.com',
		@IPPortal		= '162.218.104.98'		-- this is staging.mobileinsight.com
	;

	DECLARE @SelectedOrgs TABLE (
		OrgId		int,
		OrgName		varchar(100)
	);
	INSERT INTO @SelectedOrgs
	SELECT
		OrgId,
		OrgName
	FROM Organization
	WHERE OrgName NOT IN ('Dev')
	;

	DECLARE @PersistentUsers TABLE (
		UserId		int
	);
	INSERT INTO @PersistentUsers
	SELECT DISTINCT
		UserId
	FROM UserOrgProfile uop
		LEFT JOIN @SelectedOrgs so ON so.OrgId = uop.OrgId
	WHERE so.OrgId IS NULL

	-- Update users definition from all the tenants beside Demo, Dev and Acme, on MI (current) schema and ADHOC
	-- Include in the update all the users w/o a valid organization mapping
	UPDATE u
	SET
		 EmailAddress 		= @EmailPrefix + EmailAddress
		,PhoneNo 		= @DefaultPhone
		,MobileNumber 		= @DefaultPhone
		,Password		= @DefaultPassword
		,OldPassword 		= @OldPassword
		,isResetPwd		= 0
		,IsRegistered		= 1
		,Login_Failed_Count = 0
	FROM Users u
		LEFT JOIN @PersistentUsers pu ON pu.UserId = u.UserId
	WHERE 1 = 1
		AND u.EmailAddress NOT LIKE @EmailPrefix + '%'		-- this will make the script idempotent
		AND u.UserName NOT LIKE 'midba%'					-- not really needed anymore - is listed in persistent users
		AND pu.UserId IS NULL;

	UPDATE u_adhoc
	SET
		Email 				= @EmailPrefix + Email
	FROM [MI-ADHOC]..Users u_adhoc
		--INNER JOIN [MI-ADHOC]..UserGroups ug_adhoc ON ug_adhoc.GroupId = u_adhoc.GroupId
		INNER JOIN @SelectedOrgs so ON so.OrgId = u_adhoc.GroupId
	WHERE 1 = 1
		AND u_adhoc.Email NOT LIKE @EmailPrefix + '%'
		AND u_adhoc.UserName NOT LIKE 'midba%'
	;

	-- Update the AlertConfig table for all the users beside midba(s) from all the organizations beside Demo, Dev and Acme
	UPDATE ac
	SET
		 StoreVisit 		= 'None'
		,Task 				= 'None'
		,Compliance 		= 'None'
		,EmailAddress 		= @EmailPrefix + ac.EmailAddress
		,MobileAddress 		= @DefaultPhone
	FROM AlertConfig ac
		INNER JOIN Users u ON u.UserId = ac.UserId
		INNER JOIN @SelectedOrgs so ON so.OrgId = ac.OrgId
	WHERE 1 = 1
		  AND ac.EmailAddress NOT LIKE @EmailPrefix + '%'
		  AND u.UserName NOT LIKE 'midba%'
	;

	-- Update the custom queues beside the ones from Demo, Dev and Acme tenant
	UPDATE q
	SET
		QueueEmailAddress = @EmailPrefix + QueueEmailAddress
	FROM Queues q
		INNER JOIN @SelectedOrgs so ON so.OrgId = q.OrgId
	WHERE 1 = 1
		AND QueueEmailAddress NOT LIKE @EmailPrefix + '%'
	;

	-- Update the Organizations urls
	UPDATE org
	SET
		 OrgURL 			= @ApplicationUrl
		,PortalURL 			= @ApplicationUrl
		,DeviceURL 			= @ApplicationUrl
		,QueueDefaultEmail 	= @DefaultEmail
	FROM Organization org
		INNER JOIN @SelectedOrgs so ON so.OrgId = org.OrgId
	;

	-- Update configuration values

	UPDATE Configuration SET [Value] = '1'			  						WHERE [Name] = 'is_test_server';
	UPDATE Configuration SET [Value] = 'True'			  					WHERE [Name] = 'can.edit.permissions';
	UPDATE Configuration SET [Value] = @DefaultEmail  						WHERE [Name] = 'send_geocerti_report';
	UPDATE Configuration SET [Value] = 'false' 								WHERE [Name] = 'acc_ftp_move_archive_auth';
	UPDATE Configuration SET [Value] = 'false' 								WHERE [Name] = 'acc_is_file_from_ftp';
	UPDATE Configuration SET [Value] = @DefaultEmail 						WHERE [Name] = 'acc_feed_emailTo';
	UPDATE Configuration SET [value] = @DefaultEmail 						WHERE [Name] = 'error_log_mail_address';
	UPDATE Configuration SET [value] = @DefaultEmail 						WHERE [Name] = 'gps_email_id';
	UPDATE Configuration SET [value] = @DefaultEmail 						WHERE [Name] = 'cricket.alert.to';
	UPDATE Configuration SET [value] = 'QA Integration Summary' 			WHERE [Name] = 'cricket.alert.subject';
	UPDATE Configuration SET [value] = 'null' 								WHERE [Name] = 'ftp_username';
	UPDATE Configuration SET [value] = 'null' 								WHERE [Name] = 'ftp_password';
	UPDATE Configuration SET [value] = 'false' 								WHERE [Name] = 'acc_is_file_from_ftp';
	UPDATE Configuration SET [Value] = @IPPortal							WHERE [Name] = 'IPPortal';

	SET @DateEnd = GetDate();
	SET @ErrorMsg = 'Start at : ' + CAST(@DateStart AS nvarchar(25)) + CHAR(13) + CHAR(10) +
					'End at   : ' + CAST(@DateEnd AS nvarchar(25)) + CHAR(13) + CHAR(10) +
					'Duration : ' + CAST(DATEDIFF(ms, @DateStart, @DateEnd) AS nvarchar(20)) + ' ms' + CHAR(13) + CHAR(10);

	IF @@trancount > 0
	BEGIN

		PRINT 'Commit all the updates ...'
		COMMIT TRANSACTION

		-- If all the updates went fine, the finally trigger the update of all form functions from [MI-ADHOC]
		PRINT 'Updating all the form definitions for MI-ADHOC ...'
		UPDATE Forms SET FormName = FormName;

		-- Rebuild all the indexes
		PRINT 'Rebuilding indexes ...'
		EXEC sp_MSforeachtable @command1="print '?'", @command2="ALTER INDEX ALL ON ? REBUILD WITH (ONLINE=OFF)";

	END

END TRY
BEGIN CATCH
	ROLLBACK TRANSACTION
	PRINT 'Inside Catch'

	/** CATCH THE ERROR DETAILS */

	SET @ErrorMsg =	@ErrorMsg +
					'ErrorNumber    = ' + CAST(ERROR_NUMBER() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
					'ErrorSeverity  = ' + CAST(ERROR_SEVERITY() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
					'ErrorState     = ' + CAST(ERROR_STATE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
					'ErrorProcedure = ' + CAST(ERROR_PROCEDURE() AS nvarchar(max)) + CHAR(13) + CHAR(10) +
					'ErrorLine		= ' + CAST(ERROR_LINE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
					'ErrorMessage	= ' + CAST(ERROR_MESSAGE() AS nvarchar(max)) + CHAR(13) + CHAR(10)
	PRINT @ErrorMsg
END CATCH
PRINT @ErrorMsg
