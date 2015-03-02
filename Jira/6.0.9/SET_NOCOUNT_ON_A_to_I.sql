IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Account_Supporter' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Account_Supporter]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Account_Supporter]    Script Date: 3/2/2015 6:36:12 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

/*	
	===========================================================================
	Stored procedure used as a getter for Accounts dropdown. As per re-engineering 
	for Users structures, MOBILEINSIGHT-16656, the function seams to return or all
	the defined Accounts in one organization, or a list of accounts used in the 
	stores assigned to the user's downline.

	EXEC [Account_Supporter] 18, 'DROP_DOWN_ACCOUNT_NAME_FOR_CONTACT', 1
	===========================================================================
*/
CREATE PROCEDURE [dbo].[Account_Supporter](
	 @P_OrgId 		int
	,@P_Action_Type Varchar(50)
	,@P_UserId 		int
)
AS
SET NOCOUNT ON
BEGIN

	-- The calling user's down-line accounts
	WITH DownlineAccounts_CTE AS (
		SELECT DISTINCT
			a.AccountId
		FROM UserReporting_Function(@P_OrgId, @P_UserId) urf
			INNER JOIN StoreUserMapping stum WITH (NOLOCK) ON urf.UserId = stum.UserId
			INNER JOIN Store s WITH (NOLOCK) ON stum.StoreId = s.StoreId
			INNER JOIN Account a WITH (NOLOCK) ON s.AccountId = a.AccountId
	)
	-- Query to return the data
	SELECT
		 ac.AccountId
		,ac.AccountName
	FROM Account ac WITH (NOLOCK)
		LEFT JOIN DownlineAccounts_CTE da_c ON ac.AccountId = da_c.AccountId
	WHERE 1 = 1
		AND ac.IsActive = 1
		AND ac.OrgId = @P_OrgId
		AND ( 1 = 0
				OR @P_Action_Type = 'DROP_DOWN_ACCOUNT_NAME'
				OR ( 1 = 1
					   AND @P_Action_Type IN (
												'DROP_DOWN_ACCOUNT_NAME_FOR_CONTACT'
											   ,'DROP_DOWN_ACCOUNT_NAME_FOR_ALL'
											   ,'DROP_DOWN_ACCOUNT_NAME_FOR_REPORT'
					   						 )
					   AND da_c.AccountId IS NOT NULL	-- Force the filtering
				   )
			)
	ORDER BY
		ac.AccountName
;
END
;

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'AdhocReportBuilder_Worker' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[AdhocReportBuilder_Worker]')
	END
GO
/****** Object:  StoredProcedure [dbo].[AdhocReportBuilder_Worker]    Script Date: 3/2/2015 6:36:13 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AdhocReportBuilder_Worker]
AS
SET NOCOUNT ON
BEGIN

	DECLARE @OrgId INT

	SET @OrgId=0

	SELECT OrgId INTO #OrgList FROM Organization ORDER BY 1

	SELECT TOP 1 @OrgId = OrgId 
		FROM #OrgList 
		ORDER BY 1

	WHILE @OrgId > 0
	BEGIN
		
		--syncronize created published reports
		--if the userdivisionregion or the role changes for a user he should get the appropriate reports from that region/role
		EXEC [dbo].[SyncReportsWithGeographyAndRole] @OrgId
		EXEC [dbo].[SyncDeleteReports] @OrgId
		DELETE #OrgList WHERE OrgId = @OrgId

		SET @OrgId=0
		SELECT TOP 1 @OrgId = OrgId FROM #OrgList ORDER BY 1

	END
    --we need to delete the reports that do not match the published criteria from the users
	
   --EXEC [dbo].[SyncDeleteReports]



END


GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'AdhocVisitSearch' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[AdhocVisitSearch]')
	END
GO
/****** Object:  StoredProcedure [dbo].[AdhocVisitSearch]    Script Date: 3/2/2015 6:36:14 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AdhocVisitSearch](
      @P_OrgId VARCHAR(20),
      @P_UserId VARCHAR(20),
      @P_FormId VARCHAR(20),
      @P_FullName VARCHAR(50),
      @P_FromDate VARCHAR(20),
      @P_ToDate VARCHAR(20),
      @P_PageNumber Int = '',
      @P_SortBy VARCHAR(30)= '',
      @P_SortOrder VARCHAR(15) = ''
)

AS
SET NOCOUNT ON
Declare @WhereCondition VARCHAR(max)
DECLARE @SQL varchar(max)
DECLARE  @Paging varchar(200), @SortBy VARCHAR(50), @SortOrder VARCHAR(5), @SecondSortBy VARCHAR(50), @LeadFormId VARCHAR(5)
BEGIN

      IF @P_PageNumber = ''
      BEGIN
            SET @P_PageNumber = 0
      END

      SET @SortBy = 'FormVisitId'
      SET @SortOrder = 'Desc'
      SET @SecondSortBy = ''
      SET @LeadFormId = ''
    SELECT @LeadFormId = Value From Configuration Where Name = 'IsLead_Form'

      /** Its used for sorting purpose */
      IF @P_SortBy != '' AND @P_SortBy <> 'NULL' And @P_SortBy <> 'undefined'
      BEGIN
            SET @SortBy = @P_SortBy
            Select @SortBy =
                  Case
                        When @P_SortBy = 'FormName' then 'Forms.FormName'
                        When @P_SortBy = 'CreatedBy' then 'Users.FullName'
                        When @P_SortBy = 'CreatedOn' then 'FormVisit.VisitDate'
                        When @P_SortBy = 'TimeIn' then 'FormVisit.TimeIn'
                        When @P_SortBy = 'TimeOut' then 'FormVisit.TimeOut'
                        Else @P_SortBy
                  End
      END

      IF @P_SortOrder != '' AND @P_SortOrder <> 'NULL' And  @P_SortOrder <> 'undefined'
            Set @SortOrder = @P_SortOrder


      SET @SecondSortBy =
                        Case
                        When @SortBy = 'Forms.FormName' then 'FormName'
                        When @SortBy = 'Users.FullName' then 'FullName'
                        When @SortBy = 'FormVisit.VisitDate' then 'CreatedOn'
                        When @SortBy = 'FormVisit.TimeIn' then 'TimeIn'
                        When @SortBy = 'FormVisit.TimeOut' then 'TimeOut'
                        Else @SortBy
                        End

SET @Paging = ' Where ROWID between '+ltrim(STR(@P_PageNumber+1))+' and '+ltrim(STR(@P_PageNumber+101))+ ' Order By '+@SecondSortBy+' '+ @SortOrder+' '

      /** Increase performance */
      IF OBJECT_ID('TEMPDB..#StoreVisit_Hierarchy_Function_Temp') IS NOT NULL DROP TABLE #StoreVisit_Hierarchy_Function_Temp
      CREATE TABLE #StoreVisit_Hierarchy_Function_Temp(AutoId INT IDENTITY, UserId INT)
      INSERT INTO #StoreVisit_Hierarchy_Function_Temp(UserId)
      SELECT DISTINCT UserId FROM User_Hierarchy_Function(@P_OrgId, @P_UserId)

      SET @WhereCondition = ' AND Forms.IsActive = 1 AND (FormVisit.storeid is null OR FormVisit.storeid=0) '

            IF (@P_FormId <>'null' AND @P_FromDate <>'null' AND @P_ToDate <>'null' AND LEN(@P_FormId) > 0
            AND LEN(@P_FromDate) > 0 AND LEN(@P_ToDate) > 0 )
            BEGIN

                  SET @WhereCondition = @WhereCondition + ' and FormVisit.FormId = '+@P_FormId+' AND Users.Fullname LIKE ''%'+@P_FullName+'%'' AND
                              FormVisit.VisitDate >= CONVERT(DATETIME, '''+@P_FromDate+''', 121) AND
                              FormVisit.VisitDate <= CONVERT(DATETIME, '''+@P_ToDate+''', 121)+1'
            END

            ELSE IF (@P_FromDate <>'null' AND @P_ToDate <>'null' AND LEN(@P_FromDate) > 0 AND LEN(@P_ToDate) > 0)
            BEGIN
                  SET @WhereCondition = @WhereCondition + ' and Users.Fullname LIKE ''%'+@P_FullName+'%'' AND
              FormVisit.VisitDate >= CONVERT(DATETIME, '''+@P_FromDate+''', 121) AND
                              FormVisit.VisitDate <= CONVERT(DATETIME, '''+@P_ToDate+''', 121)+1'
            END

            ELSE IF (@P_FromDate <>'null' AND @P_ToDate <>'null' AND LEN(@P_FromDate) > 0 AND LEN(@P_ToDate) > 0)
            BEGIN
                  SET @WhereCondition = @WhereCondition + ' and Users.Fullname LIKE ''%'+@P_FullName+'%'' AND
                              FormVisit.VisitDate >= CONVERT(DATETIME, '''+@P_FromDate+''', 121) AND
                              FormVisit.VisitDate <= CONVERT(DATETIME, '''+@P_ToDate+''', 121)+1'
            END

           /** TODO remove later for speed - INNER JOIN FormFieldValues ON FormFieldValues.FormVisitId = FormVisit.FormVisitId  */
            SET @SQL= 'SELECT DISTINCT Row_Number() Over(Order By '+@SortBy+' '+ @SortOrder+') As ROWID, FormVisit.FormVisitId, FormVisit.Description, FormVisit.UserId as CreatedBy, Forms.FormName, Users.FullName,
                        FormVisit.TimeIn, FormVisit.TimeOut,
                        CONVERT(VARCHAR(10), FormVisit.VisitDate, 101) AS CreatedOn, FormVisit.VisitDate  INTO #ResultTemp
                        FROM FormVisit INNER JOIN Forms ON FormVisit.FormId = Forms.FormId
                        INNER JOIN Users ON Users.UserId = FormVisit.UserId
                        WHERE ';

            IF ISNUMERIC(@LeadFormId) > 0
            BEGIN
                  SET @SQL = @SQL + 'Forms.FormId not in('+@LeadFormId+') And '
            END

            SET @SQL = @SQL + 'FormVisit.UserId IN (SELECT UserId FROM #StoreVisit_Hierarchy_Function_Temp) And Forms.orgId = '+@P_OrgId+'
                        '  + @WhereCondition

            SET @SQL= @SQL + ' Select * From  #ResultTemp ' --- + @Paging       to aviod the limit of records in UI that is 101

			      IF (@P_SortBy = 'createdOn' OR @P_SortBy = 'timeIn' OR @P_SortBy = 'timeOut')
			      SET @SQL = @SQL + 'Order By Cast(Cast(CONVERT(VARCHAR(10), CreatedOn, 101) + '' '' + TimeIn as datetime) as float) ' + @SortOrder

            print @SQL
            EXEC (@SQL)

END

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Alerts_EMail_SMS' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Alerts_EMail_SMS]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Alerts_EMail_SMS]    Script Date: 3/2/2015 6:36:15 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Alerts_EMail_SMS] (
	@P_Type VARCHAR(100)
	,@P_OrgId VARCHAR(50)
	,@P_UserId VARCHAR(50)
	,@P_Id VARCHAR(50)
	,@P_Other VARCHAR(100)
	)
AS
SET NOCOUNT ON
BEGIN

	IF @P_Type = 'GetUpdateTaskDetails'
	BEGIN
		SELECT DISTINCT t.OrgId
			,t.TaskId
			,t.Title
			,t.UserId
			,t.StartDate
			,t.EndDate
			,t.[Status]
			,t.[Priority]
			,t.AdditionalNotes
			,u.FullName AS AssignedBy
			,t.Createdby
		FROM Task t
		INNER JOIN Users u ON t.UserId = u.UserId
		INNER JOIN AlertConfig ac ON ac.UserId = t.CreatedBy
			AND ac.OrgId = t.OrgId
		WHERE t.UpdateMailFlag = 'False'
			AND ac.Task <> 'NONE'
	END
	ELSE
		IF @P_Type = 'GetCallTaskAlertDetails'
		BEGIN
			SELECT DISTINCT t.OrgId
				,t.TaskId
				,t.Title
				,t.UserId
				,t.StartDate
				,t.EndDate
				,t.[Status]
				,t.[Priority]
				,t.AdditionalNotes
				,u.FullName AS AssignedBy
				,t.Createdby
			FROM Task t
			INNER JOIN Users u ON u.UserId = t.CreatedBy
			WHERE --t.createdBy = u.UserId
				t.StartDate = CONVERT(VARCHAR(10), GETDATE() + 1, 120)
				--IN (
				--	SELECT StartDate
				--	FROM Task
				--	WHERE StartDate = CONVERT(VARCHAR(10), GETDATE() + 1, 120)
				--	)
				AND t.ReminderMailFlag = 'False'
				AND t.[Status] != 'Closed'
		END
		ELSE
			IF @P_Type = 'GetcallCreateTaskDetails'
			BEGIN
				SELECT DISTINCT t.OrgId
					,t.TaskId
					,t.Title
					,t.UserId
					,t.StartDate
					,t.EndDate
					,t.[Status]
					,t.Priority
					,t.AdditionalNotes
					,u.FullName AS AssignedBy
					,t.Createdby
				FROM Task t
				INNER JOIN Users u ON u.UserId = t.CreatedBy
				WHERE (
						t.CreateMailFlag = 'False'
						OR t.CreateMailFlag IS NULL
						)
			END
			ELSE
				IF @P_Type = 'GetTaskAlertConfigurationDetails'
				BEGIN
					SELECT DISTINCT c1.[Value] AS AlertEmail_ID
						,c2.[Value] AS AlertEmail_Pwd
						,ac.UserId
						,ac.Task
						,ac.EmailAddress
						,ac.MobileAddress
						,ac.ServiceProviderId
					FROM Configuration c1
						,Configuration c2
						,AlertConfig ac
						INNER JOIN Users u ON u.UserId = ac.UserId
					WHERE c1.NAME = 'ALERT_MAIL_ADDRESS'
						AND c2.NAME = 'ALERT_MAIL_PASSWORD'
						AND u.isActive = 'true'
						AND u.UserId = @P_UserId
						AND ac.OrgId = @P_OrgId
				END
				ELSE
					IF @P_Type = 'GetcallStoreVisitAlertDetails'
					BEGIN
						SELECT st.OrgId
							,sv.StoreId
							,sv.UserId
							,ac.AccountName
							,sv.DATE
							,sv.StartTime
							,sv.EndTime
							,sv.CreatedBy
							,st.StoreVisitsCategory
							,st.OrgId
							,CASE 
								WHEN dr.TimeZone IS NULL
									THEN 'Eastern'
								ELSE dr.TimeZone
								END AS TimeZone
							,StoreName
							,CertifiedStoreNickName
							,CASE 
								WHEN CustomizedLabel IS NULL
									OR CustomizedLabel = ''
									OR CustomizedLabel = 'null'
									THEN LabelValue
								ELSE CustomizedLabel
								END AS StoreLabel
						FROM StoreVisit sv
							INNER JOIN Store st ON st.StoreId = sv.StoreId
								AND sv.[Date] = CONVERT(VARCHAR(10), GETDATE() + 1, 120)
							INNER JOIN Users us ON us.UserId = sv.UserId
							INNER JOIN UserDivisionRegionMapping udrm ON udrm.UserId = us.UserId
								AND udrm.DivisionRegionId = st.DivisionRegionId
							INNER JOIN Account ac ON ac.AccountId = st.AccountId
							INNER JOIN DivisionRegion dr ON dr.DivisionRegionId = udrm.DivisionRegionId
								AND dr.OrgId = sv.OrgId
							INNER JOIN LabelKeyValueBundleMap lmap ON lmap.OrgId = sv.OrgId
							INNER JOIN LabelKeyBundle lkey ON lmap.LabelKeyBundleId = lkey.LabelKeyBundleId
							INNER JOIN LabelValueBundle lval ON lval.LabelValueBundleId = lmap.LabelValueBundleId
						WHERE sv.ReminderMailFlag = 'False'
							AND sv.DATE != SUBSTRING(CONVERT(VARCHAR(10), sv.CreatedOn + 1, 120), 1, 10)
							AND lkey.IsActive = 'true'
							AND lval.IsActive = 'true'
							AND ac.IsActive = 'true'
							AND st.IsActive = 'true'
							AND sv.IsActive = 'true'
							AND lkey.LabelKey = 'store'
					END
					ELSE
						IF @P_Type = 'GetcallStoreVisitScheduleDetails'
						BEGIN
							SELECT DISTINCT st.OrgId
								,sv.StoreId
								,sv.UserId
								,ac.AccountName
								,sv.GroupId
								,sv.DATE
								,sv.StartTime
								,sv.EndTime
								,sv.CreatedBy
								,st.StoreVisitsCategory
								,st.OrgId
								,CASE 
									WHEN dr.TimeZone IS NULL
										THEN 'Eastern'
									ELSE dr.TimeZone
									END AS TimeZone
								,CASE 
									WHEN st.CertifiedStoreNickName = ''
										THEN st.StoreName
									WHEN st.CertifiedStoreNickName IS NULL
										THEN st.StoreName
									ELSE st.CertifiedStoreNickName
									END AS StoreName
								,CASE 
									WHEN CustomizedLabel IS NULL
										OR CustomizedLabel = ''
										OR CustomizedLabel = 'null'
										THEN LabelValue
									ELSE CustomizedLabel
									END AS StoreLabel
							FROM StoreVisit sv
								INNER JOIN Store st ON st.StoreId = sv.StoreId
									AND sv.IsActive = 'true'
									AND st.IsActive = 'true'
								INNER JOIN Users us ON us.UserId = sv.UserId
								INNER JOIN Account ac ON ac.AccountId = st.AccountId
								INNER JOIN UserDivisionRegionMapping udrm ON udrm.UserId = us.UserId
									AND udrm.DivisionRegionId = st.DivisionRegionId
								INNER JOIN DivisionRegion dr ON dr.DivisionRegionId = udrm.DivisionRegionId
									AND dr.OrgId = sv.OrgId
								INNER JOIN LabelKeyValueBundleMap lmap ON lmap.OrgId = sv.OrgId
								INNER JOIN LabelKeyBundle lkey ON lmap.LabelKeyBundleId = lkey.LabelKeyBundleId
								INNER JOIN LabelValueBundle lval ON lval.LabelValueBundleId = lmap.LabelValueBundleId
							WHERE sv.CreateMailFlag = 'False'
								AND lkey.IsActive = 'true'
								AND lval.IsActive = 'true'
								AND ac.IsActive = 'true'
								AND lkey.LabelKey = 'store'
						END
						ELSE
							IF @P_Type = 'GetStoreVisitAlertConfigurationDetails'
							BEGIN
								SELECT DISTINCT c1.[Value] AS ALERTEMAIL_ID
									,c2.[Value] AS ALERTEMAIL_PWD
									,ac.UserId
									,u.UserName
									,ac.StoreVisit
									,ac.EmailAddress
									,ac.MobileAddress
									,ac.ServiceProviderId
								FROM Configuration c1
									,Configuration c2
									,AlertConfig ac
								INNER JOIN Users u ON u.UserId = ac.UserId
								WHERE c1.NAME = 'ALERT_MAIL_ADDRESS'
									AND c2.NAME = 'ALERT_MAIL_PASSWORD'
									AND u.isActive = 'true'
									AND u.UserId = @P_UserId
									AND ac.OrgId = @P_OrgId
							END
							/******************************************************************/
							/*                                                                */
							/*   New conditions added                                         */
							/*                                                                */
							/******************************************************************/
							ELSE
								IF @P_Type = 'StoreVisitSchedule'
								BEGIN
									SELECT st.OrgId
										,sv.StoreId
										,sv.UserId
										,ac.AccountName
										--,sv.GroupId
										,sv.DATE
										,sv.StartTime
										,sv.EndTime
										,sv.CreatedBy
										,st.StoreVisitsCategory
										,CASE 
											WHEN dr.TimeZone IS NULL
												THEN 'Eastern'
											ELSE dr.TimeZone
											END AS TimeZone
										,CASE 
											WHEN st.CertifiedStoreNickName = ''
												THEN st.StoreName
											WHEN st.CertifiedStoreNickName IS NULL
												THEN st.StoreName
											ELSE st.CertifiedStoreNickName
											END AS StoreName
										,CASE 
											WHEN CustomizedLabel IS NULL
												OR CustomizedLabel = ''
												OR CustomizedLabel = 'null'
												THEN LabelValue
											ELSE CustomizedLabel
											END AS StoreLabel
										,c1.[Value] AS AlertEmailId
										,c2.[Value] AS AlertEmailPassword
										,us.UserName
										,acfg.StoreVisit
										,acfg.EmailAddress
										,acfg.MobileAddress
										,acfg.ServiceProviderId
									FROM StoreVisit sv
										INNER JOIN Store st ON st.StoreId = sv.StoreId
											AND sv.IsActive = 'true'
											AND st.IsActive = 'true'
										INNER JOIN Users us ON us.UserId = sv.UserId
										INNER JOIN Account ac ON ac.AccountId = st.AccountId
										INNER JOIN UserDivisionRegionMapping udrm ON udrm.UserId = us.UserId
											AND udrm.DivisionRegionId = st.DivisionRegionId
										INNER JOIN DivisionRegion dr ON dr.DivisionRegionId = udrm.DivisionRegionId
											AND dr.OrgId = sv.OrgId
										INNER JOIN LabelKeyValueBundleMap lmap ON lmap.OrgId = sv.OrgId
										INNER JOIN LabelKeyBundle lkey ON lmap.LabelKeyBundleId = lkey.LabelKeyBundleId
										INNER JOIN LabelValueBundle lval ON lval.LabelValueBundleId = lmap.LabelValueBundleId
										INNER JOIN AlertConfig acfg ON acfg.OrgId = sv.OrgId
											AND acfg.UserId = us.UserId
										,Configuration c1
										,Configuration c2
									WHERE sv.CreateMailFlag = 'False'
										AND sv.GroupId IS NULL
										AND lkey.IsActive = 'true'
										AND lval.IsActive = 'true'
										AND ac.IsActive = 'true'
										AND lkey.LabelKey = 'store'
										AND c1.NAME = 'ALERT_MAIL_ADDRESS'
										AND c2.NAME = 'ALERT_MAIL_PASSWORD'
										AND sv.CreatedBy = acfg.UserId
										AND acfg.Task <> 'NONE'
								END
								ELSE
									IF @P_Type = 'UpdateTaskMail'
									BEGIN
										SELECT DISTINCT t.OrgId
											,t.TaskId
											,t.Title
											,t.UserId
											,t.StartDate
											,t.EndDate
											,t.[Status]
											,t.[Priority]
											,t.AdditionalNotes
											,u1.FullName AS AssignedBy
											,t.Createdby
											,c1.[Value] AS AlertEmailId
											,c2.[Value] AS AlertEmailPassword
											--,ac1.UserId
											,ac1.Task
											,ac1.EmailAddress
											,ac1.MobileAddress
											,ac1.ServiceProviderId
										FROM Task t
											INNER JOIN Users u1 ON t.UserId = u1.UserId
											INNER JOIN AlertConfig ac1 ON ac1.UserId = t.CreatedBy
												AND ac1.OrgId = t.OrgId
											INNER JOIN Users u2 ON u2.UserId = ac1.UserId
											,Configuration c1
											,Configuration c2
										WHERE t.UpdateMailFlag = 'False'
											AND ac1.Task <> 'NONE'
											AND u2.isActive = 'true'
											AND c1.NAME = 'ALERT_MAIL_ADDRESS'
											AND c2.NAME = 'ALERT_MAIL_PASSWORD'
									END
									ELSE
										IF @P_Type = 'CreateTaskMail'
										BEGIN
											SELECT DISTINCT t.OrgId
												,t.TaskId
												,t.Title
												,t.UserId
												,t.StartDate
												,t.EndDate
												,t.[Status]
												,t.Priority
												,t.AdditionalNotes
												,u1.FullName AS AssignedBy
												,t.Createdby
												,c1.[Value] AS AlertEmailId
												,c2.[Value] AS AlertEmailPassword
												--,ac.UserId
												,ac.Task
												,ac.EmailAddress
												,ac.MobileAddress
												,ac.ServiceProviderId
											FROM Task t
												INNER JOIN Users u1 ON u1.UserId = t.CreatedBy
												INNER JOIN AlertConfig ac ON ac.OrgId = t.OrgId
													AND ac.UserId = t.UserId
												INNER JOIN Users u2 ON u2.UserId = ac.UserId
												,Configuration c1
												,Configuration c2
											WHERE (
													t.CreateMailFlag = 'False'
													OR t.CreateMailFlag IS NULL
													)
												AND c1.NAME = 'ALERT_MAIL_ADDRESS'
												AND c2.NAME = 'ALERT_MAIL_PASSWORD'
												AND u2.isActive = 'true'
												AND Task IN (
													'Email'
													,'SMS'
													,'Both'
													)
										END
										ELSE
											IF @P_Type = 'StoreVisitAlert'
											BEGIN
												SELECT DISTINCT st.OrgId
													,sv.StoreId
													,sv.UserId
													,ac.AccountName
													,sv.DATE
													,sv.StartTime
													,sv.EndTime
													,sv.CreatedBy
													,st.StoreVisitsCategory
													--,st.OrgId
													,CASE 
														WHEN dr.TimeZone IS NULL
															THEN 'Eastern'
														ELSE dr.TimeZone
														END AS TimeZone
													,StoreName
													,CertifiedStoreNickName
													,CASE 
														WHEN CustomizedLabel IS NULL
															OR CustomizedLabel = ''
															OR CustomizedLabel = 'null'
															THEN LabelValue
														ELSE CustomizedLabel
														END AS StoreLabel
													,c1.[Value] AS AlertEmailId
													,c2.[Value] AS AlertEmailPassword
													--,ac2.UserId
													,us.UserName
													,ac2.StoreVisit
													,ac2.EmailAddress
													,ac2.MobileAddress
													,ac2.ServiceProviderId
												FROM StoreVisit sv
													INNER JOIN Store st ON st.StoreId = sv.StoreId
														AND sv.[Date] = CONVERT(VARCHAR(10), GETDATE() + 1, 120)
													INNER JOIN Users us ON us.UserId = sv.UserId
													INNER JOIN UserDivisionRegionMapping udrm ON udrm.UserId = us.UserId
														AND udrm.DivisionRegionId = st.DivisionRegionId
													INNER JOIN Account ac ON ac.AccountId = st.AccountId
													INNER JOIN DivisionRegion dr ON dr.DivisionRegionId = udrm.DivisionRegionId
														AND dr.OrgId = sv.OrgId
													INNER JOIN LabelKeyValueBundleMap lmap ON lmap.OrgId = sv.OrgId
													INNER JOIN LabelKeyBundle lkey ON lmap.LabelKeyBundleId = lkey.LabelKeyBundleId
													INNER JOIN LabelValueBundle lval ON lval.LabelValueBundleId = lmap.LabelValueBundleId
													INNER JOIN AlertConfig ac2 ON ac2.OrgId = sv.OrgId
														AND ac2.UserId = sv.UserId AND ac2.UserId = sv.CreatedBy
													,Configuration c1
													,Configuration c2
												WHERE sv.ReminderMailFlag = 'False'
													AND sv.DATE != SUBSTRING(CONVERT(VARCHAR(10), sv.CreatedOn + 1, 120), 1, 10)
													AND lkey.IsActive = 'true'
													AND lval.IsActive = 'true'
													AND ac.IsActive = 'true'
													AND st.IsActive = 'true'
													AND sv.IsActive = 'true'
													AND lkey.LabelKey = 'store'
													AND c1.NAME = 'ALERT_MAIL_ADDRESS'
													AND c2.NAME = 'ALERT_MAIL_PASSWORD'
													AND us.isActive = 'true'
													AND ac2.Task <> 'NONE'
											END
											ELSE
												IF @P_Type = 'TaskAlert'
												BEGIN
													SELECT DISTINCT t.OrgId
														,t.TaskId
														,t.Title
														,t.UserId
														,t.StartDate
														,t.EndDate
														,t.[Status]
														,t.[Priority]
														,t.AdditionalNotes
														,u1.FullName AS AssignedBy
														,t.Createdby
														,c1.[Value] AS AlertEmailId
														,c2.[Value] AS AlertEmailPassword
														--,ac.UserId
														,ac.Task
														,ac.EmailAddress
														,ac.MobileAddress
														,ac.ServiceProviderId
													FROM Task t
														INNER JOIN Users u1 ON u1.UserId = t.CreatedBy
														INNER JOIN Users u2 ON u2.UserId = t.UserId
														INNER JOIN AlertConfig ac ON ac.OrgId = t.OrgId
															AND ac.UserId = u2.UserId
														,Configuration c1
														,Configuration c2
													WHERE t.StartDate = CONVERT(VARCHAR(10), GETDATE() + 1, 120)
														AND t.ReminderMailFlag = 'False'
														AND t.[Status] != 'Closed'
														AND c1.NAME = 'ALERT_MAIL_ADDRESS'
														AND c2.NAME = 'ALERT_MAIL_PASSWORD'
														AND u2.isActive = 'true'
														AND Task IN (
															'Email'
															,'SMS'
															,'Both'
															)
												END
END

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'AverageStoreVisitLength_Retailer_Geography' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[AverageStoreVisitLength_Retailer_Geography]')
	END
GO
/****** Object:  StoredProcedure [dbo].[AverageStoreVisitLength_Retailer_Geography]    Script Date: 3/2/2015 6:36:16 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AverageStoreVisitLength_Retailer_Geography] 
(
	@OrgId int,
	@InitialName VARCHAR(50),
	@UserId int,
	@UserType varchar(50) = 'Team',
	@AccountName VARCHAR(100) = '',
	@DivisionName  VARCHAR(100) = '',
	@MarketCluster VARCHAR(100) = '',
	@RegionName VARCHAR(100) = ''
)
AS
SET NOCOUNT ON
BEGIN
	DECLARE @StartDate datetime, 
			@EndDate datetime,
			@Switch int,
			@IsCompliance bit

	DECLARE @NoOfMonth int

	SET @NoOfMonth = 12

	SELECT @UserId = CASE WHEN IsCompliance = 0 THEN 0 ELSE @UserId END 
	FROM Organization 
	WHERE OrgId = @OrgId

	SET @Switch = 0
	IF @AccountName != ''
	BEGIN
		SET @Switch = @Switch  + 1
	END
	IF @DivisionName != ''
	BEGIN
		SET @Switch = @Switch  + 2
	END
	IF @MarketCluster != ''
	BEGIN
		SET @Switch = @Switch  + 4
	END
	IF @RegionName != ''
	BEGIN
		SET @Switch = @Switch  + 8
	END

    SET @StartDate = DATEADD(m, DATEDIFF(m, 0, DATEADD(mm, -@NoOfMonth, GETDATE())), 0)
    SET @EndDate   = DATEADD(mi, - 1, DATEADD(m, DATEDIFF(m, 0, DATEADD(m, 1, GETDATE())), 0))

    print 'Orgid			= ' + cast(@OrgId as varchar(2))
    print 'InitialName		= ' + @InitialName
    print 'UserId			= ' + cast(@UserId as varchar(6))
    print 'UserType		= ' + @UserType
    print 'AccountName		= ' + @AccountName
    print 'DivisionName	= ' + @DivisionName
    print 'MarketCluster	= ' + @MarketCluster
    print 'RegionName		= ' + @RegionName
	PRINT @Switch

	DECLARE @ResultTable TABLE
	(
		ResultShortName VARCHAR(100),
		ResultId VARCHAR(100),
		ResultName VARCHAR(100),
		M01	VARCHAR(10),
		M02	VARCHAR(10),
		M03	VARCHAR(10),
		M04	VARCHAR(10),
		M05	VARCHAR(10),
		M06	VARCHAR(10),
		M07	VARCHAR(10),
		M08	VARCHAR(10),
		M09	VARCHAR(10),
		M10	VARCHAR(10),
		M11	VARCHAR(10),
		M12	VARCHAR(10),
		M13 VARCHAR(10)
	)

	;WITH StoerVisit_cte
	AS
	(
		SELECT 
			CASE 
				WHEN @Switch = 0 THEN CASE
					WHEN @InitialName = 'Account_Name' THEN a.AccountName
					WHEN @InitialName = 'Store_Division' THEN dr.Division
					WHEN @InitialName = 'MarketGroup' THEN dr.Region
					WHEN @InitialName = 'store_market_cluster' THEN dr.market_cluster
				END
				WHEN @Switch >= 8 THEN s.StoreName
				WHEN @Switch >= 4 THEN dr.Region
				WHEN @Switch >= 2 THEN dr.market_cluster
				WHEN @Switch = 1 THEN dr.Division
			END AS Result,
			ABS(DATEDIFF(mm, GETDATE(), fv.CreatedOn) - 1) AS [Month],
			AVG(ISNULL(fv.LengthOfVisitInMinutes, 0) * 1.000) AS VisitLength
		FROM dbo.Hierarchy_Function(@OrgId, @UserId) hf
		INNER JOIN FormVisit fv WITH (nolock) ON fv.StoreId = hf.StoreId
			AND fv.CreatedOn BETWEEN @StartDate AND @EndDate
		INNER JOIN Store s WITH (nolock) ON  s.StoreId = hf.StoreId AND s.OrgId = @OrgId
		INNER JOIN Account a WITH (nolock) ON a.AccountID = s.AccountId AND a.OrgId = @OrgId
		INNER JOIN DivisionRegion dr WITH (nolock) ON dr.OrgId = @OrgId
			AND dr.DivisionRegionId = s.DivisionRegionId AND dr.IsTestData = 0
		WHERE
			a.IsActive = 1
			AND s.IsActive = 1 and s.iscompliance = 1
			AND (@UserType = 'Team' OR	@UserType = 'Individual' AND hf.UserId = @UserId)
			AND (
				@Switch = 0 OR
				@Switch =  1 AND a.AccountName = @AccountName OR
				@Switch =  2 AND dr.Division = @DivisionName OR
				@Switch =  3 AND a.AccountName = @AccountName AND dr.Division = @DivisionName OR
				@Switch =  4 AND dr.market_cluster = @MarketCluster OR
				@Switch =  5 AND a.AccountName = @AccountName AND dr.market_cluster = @MarketCluster  OR
				@Switch =  6 AND dr.Division = @DivisionName AND dr.market_cluster = @MarketCluster  OR
				@Switch =  7 AND a.AccountName = @AccountName AND dr.Division = @DivisionName 
					AND dr.market_cluster = @MarketCluster  OR
				@Switch =  8 AND dr.Region = @RegionName OR
				@Switch =  9 AND a.AccountName = @AccountName AND dr.Region = @RegionName OR
				@Switch = 10 AND dr.Division = @DivisionName AND dr.Region = @RegionName OR
				@Switch = 11 AND a.AccountName = @AccountName AND dr.Division = @DivisionName AND dr.Region = @RegionName OR
				@Switch = 12 AND dr.market_cluster = @MarketCluster AND dr.Region = @RegionName OR
				@Switch = 13 AND a.AccountName = @AccountName AND dr.market_cluster = @MarketCluster 
					AND dr.Region = @RegionName OR
				@Switch = 14 AND dr.Division = @DivisionName AND dr.market_cluster = @MarketCluster 
					AND dr.Region = @RegionName OR
				@Switch = 15 AND a.AccountName = @AccountName AND dr.Division = @DivisionName 
					AND dr.market_cluster = @MarketCluster  AND dr.Region = @RegionName
				)
		GROUP BY 							
			CASE 
				WHEN @Switch = 0 THEN CASE
					WHEN @InitialName = 'Account_Name' THEN a.AccountName
					WHEN @InitialName = 'Store_Division' THEN dr.Division
					WHEN @InitialName = 'MarketGroup' THEN dr.Region
					WHEN @InitialName = 'store_market_cluster' THEN dr.market_cluster
				END
				WHEN @Switch >= 8 THEN s.StoreName
				WHEN @Switch >= 4 THEN dr.Region
				WHEN @Switch >= 2 THEN dr.market_cluster
				WHEN @Switch = 1 THEN dr.Division
			END,
			ABS(DATEDIFF(mm, GETDATE(), fv.CreatedOn) - 1)
	)
	INSERT INTO @ResultTable(ResultShortName, ResultId, ResultName, M01, M02, M03, M04, M05, M06, M07, M08, M09, M10, M11, M12, M13)
		SELECT ResultShortName, pvt.Result AS ResultId, pvt.Result AS ResultName
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[1],0),5)) as [M01]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[2],0),5)) as [M02]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[3],0),5)) as [M03]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[4],0),5)) as [M04]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[5],0),5)) as [M05]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[6],0),5)) as [M06]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[7],0),5)) as [M07]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[8],0),5)) as [M08]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[9],0),5)) as [M09]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[10],0),5)) as [M10]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[11],0),5)) as [M11]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[12],0),5)) as [M12]
				, CONVERT(DECIMAL(10,3),ROUND(ISNULL(pvt.[13],0),5)) as [M13]
		FROM
		(SELECT COALESCE(Abbreviation, sv_c.[Result]) AS ResultShortName, sv_c.[Result],sv_c.[Month],AVG(sv_c.[VisitLength]) AS VisitLength
				FROM StoerVisit_cte sv_c
					LEFT JOIN MarketGroupAbbreviation mga WITH (NOLOCK) ON (CASE 
																	WHEN @Switch & 16 > 0 THEN 1
																	ELSE 0
																END) = 1 AND mga.MarketGroups = sv_c.[Result]			
				GROUP BY sv_c.[Month], sv_c.[Result], COALESCE(Abbreviation, sv_c.[Result])
					WITH ROLLUP
		) avg_calc
		PIVOT
		(
			SUM(avg_calc.VisitLength)
				FOR avg_calc.[Month] IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13])
		) AS pvt
		WHERE 
			(pvt.ResultShortName IS NOT NULL AND pvt.[Result] IS NOT NULL)
			OR (pvt.ResultShortName IS NULL AND pvt.[Result] IS NULL)

	SELECT rt.ResultId, rt.ResultName, rt.M01, rt.M02, rt.M03, rt.M04, rt.M05, rt.M06, rt.M07, rt.M08, rt.M09, rt.M10, rt.M11, rt.M12, rt.M13 
	FROM  @ResultTable rt
END

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'AverageStoreVisitLocation_Retailer_Geography' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[AverageStoreVisitLocation_Retailer_Geography]')
	END
GO
/****** Object:  StoredProcedure [dbo].[AverageStoreVisitLocation_Retailer_Geography]    Script Date: 3/2/2015 6:36:17 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AverageStoreVisitLocation_Retailer_Geography] 
(
	@OrgId int,
	@InitialName VARCHAR(50),
	@UserId int,
	@UserType varchar(50) = 'Team',
	@AccountName VARCHAR(100) = '',
	@DivisionName  VARCHAR(100) = '',
	@MarketCluster VARCHAR(100) = '',
	@RegionName VARCHAR(100) = ''
)
AS
SET NOCOUNT ON
BEGIN
	DECLARE @NoOfMonth int

	SET @NoOfMonth = 12

	DECLARE @StartDate datetime, 
			@EndDate datetime,
			@Switch int,
			@IsCompliance bit

	SELECT @UserId = CASE WHEN IsCompliance = 0 THEN 0 ELSE @UserId END 
	FROM Organization 
	WHERE OrgId = @OrgId

	SET @Switch = 0
	IF @AccountName != ''
	BEGIN
		SET @Switch = @Switch  + 1
	END
	IF @DivisionName != ''
	BEGIN
		SET @Switch = @Switch  + 2
	END
	IF @MarketCluster != ''
	BEGIN
		SET @Switch = @Switch  + 4
	END
	IF @RegionName != ''
	BEGIN
		SET @Switch = @Switch  + 8
	END

    SET @StartDate = DATEADD(m, DATEDIFF(m, 0, DATEADD(mm, -@NoOfMonth, GETDATE())), 0)
    SET @EndDate   = DATEADD(mi, - 1, DATEADD(m, DATEDIFF(m, 0, DATEADD(m, 1, GETDATE())), 0))

    print 'Orgid			= ' + cast(@OrgId as varchar(2))
    print 'InitialName		= ' + @InitialName
    print 'UserId			= ' + cast(@UserId as varchar(6))
    print 'UserType		= ' + @UserType
    print 'AccountName		= ' + @AccountName
    print 'DivisionName	= ' + @DivisionName
    print 'MarketCluster	= ' + @MarketCluster
    print 'RegionName		= ' + @RegionName
	PRINT @Switch

	DECLARE @ResultTable TABLE
	(
		ResultShortName VARCHAR(100),
		ResultId VARCHAR(100),
		ResultName VARCHAR(100),
		M01	VARCHAR(10),
		M02	VARCHAR(10),
		M03	VARCHAR(10),
		M04	VARCHAR(10),
		M05	VARCHAR(10),
		M06	VARCHAR(10),
		M07	VARCHAR(10),
		M08	VARCHAR(10),
		M09	VARCHAR(10),
		M10	VARCHAR(10),
		M11	VARCHAR(10),
		M12	VARCHAR(10),
		M13 VARCHAR(10)
	)

	;WITH Stores_CTE
	AS
	(
		SELECT
			CASE 
				WHEN @Switch = 0 THEN CASE
					WHEN @InitialName = 'Account_Name' THEN a.AccountName
					WHEN @InitialName = 'Store_Division' THEN dr.Division
					WHEN @InitialName = 'MarketGroup' THEN dr.Region
					WHEN @InitialName = 'store_market_cluster' THEN dr.market_cluster
				END
				WHEN @Switch >= 8 THEN s.StoreName
				WHEN @Switch >= 4 THEN dr.Region
				WHEN @Switch >= 2 THEN dr.market_cluster
				WHEN @Switch = 1 THEN dr.Division
			END AS Result,
			s.StoreId,
			COUNT(s.StoreId) OVER 
			(
				PARTITION BY CASE 
					WHEN @Switch = 0 THEN CASE
						WHEN @InitialName = 'Account_Name' THEN a.AccountName
						WHEN @InitialName = 'Store_Division' THEN dr.Division
						WHEN @InitialName = 'MarketGroup' THEN dr.Region
						WHEN @InitialName = 'store_market_cluster' THEN dr.market_cluster
					END
					WHEN @Switch >= 8 THEN s.StoreName
					WHEN @Switch >= 4 THEN dr.Region
					WHEN @Switch >= 2 THEN dr.market_cluster
					WHEN @Switch = 1 THEN dr.Division
				END
			) AS StoreCount				
		FROM UserReporting_Function(@OrgId, @UserId) ur_f
			INNER JOIN StoreUserMapping sump WITH (nolock) ON sump.UserId = ur_f.UserId
			INNER JOIN Store s WITH (nolock) ON s.StoreId = sump.StoreId AND s.OrgId = ur_f.OrgId
			INNER JOIN Account a WITH (nolock) ON a.AccountId = s.AccountId AND a.OrgId = ur_f.OrgId 
			INNER JOIN DivisionRegion dr WITH (nolock) ON dr.OrgId = @OrgId 
				AND dr.DivisionRegionId = s.DivisionRegionId
		WHERE 
			a.IsActive = 1
			AND s.IsActive = 1 and s.iscompliance = 1
			AND (@UserType = 'Team' OR	@UserType = 'Individual' AND ur_f.UserId = @UserId)
			AND (
				@Switch = 0 OR
				@Switch =  1 AND a.AccountName = @AccountName OR
				@Switch =  2 AND dr.Division = @DivisionName OR
				@Switch =  3 AND a.AccountName = @AccountName AND dr.Division = @DivisionName OR
				@Switch =  4 AND dr.market_cluster = @MarketCluster OR
				@Switch =  5 AND a.AccountName = @AccountName AND dr.market_cluster = @MarketCluster  OR
				@Switch =  6 AND dr.Division = @DivisionName AND dr.market_cluster = @MarketCluster  OR
				@Switch =  7 AND a.AccountName = @AccountName AND dr.Division = @DivisionName 
					AND dr.market_cluster = @MarketCluster  OR
				@Switch =  8 AND dr.Region = @RegionName OR
				@Switch =  9 AND a.AccountName = @AccountName AND dr.Region = @RegionName OR
				@Switch = 10 AND dr.Division = @DivisionName AND dr.Region = @RegionName OR
				@Switch = 11 AND a.AccountName = @AccountName AND dr.Division = @DivisionName AND dr.Region = @RegionName OR
				@Switch = 12 AND dr.market_cluster = @MarketCluster AND dr.Region = @RegionName OR
				@Switch = 13 AND a.AccountName = @AccountName AND dr.market_cluster = @MarketCluster 
					AND dr.Region = @RegionName OR
				@Switch = 14 AND dr.Division = @DivisionName AND dr.market_cluster = @MarketCluster 
					AND dr.Region = @RegionName OR
				@Switch = 15 AND a.AccountName = @AccountName AND dr.Division = @DivisionName 
					AND dr.market_cluster = @MarketCluster  AND dr.Region = @RegionName
			)
	),
	StoreVisitCount_CTE
	AS
	(
		SELECT	
			s_c.Result,
			COUNT(fv.FormVisitId) AS StoreVisitCount,
			s_c.StoreCount,
			CONVERT(DECIMAL(10,3) ,ROUND(COUNT(fv.FormVisitId) * 1.000 / s_c.StoreCount,3)) AS Avg_VisitCount,
			ABS(DATEDIFF(mm, GETDATE(), fv.CreatedOn) - 1) AS [Month]
		FROM Stores_CTE s_c
		LEFT JOIN FormVisit fv WITH (nolock) ON fv.StoreId = s_c.StoreId AND fv.CreatedOn BETWEEN @StartDate AND @EndDate		GROUP BY s_c.Result, s_c.StoreCount, ABS(DATEDIFF(mm, GETDATE(), fv.CreatedOn) - 1)
	)
	INSERT INTO @ResultTable(ResultShortName, ResultId, ResultName, M01, M02, M03, M04, M05, M06, M07, M08, M09, M10, M11, M12, M13)
		SELECT ResultShortName, pvt.Result AS ResultId, pvt.Result AS ResultName
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[1],0)),3)) as [M01]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[2],0)),3)) as [M02]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[3],0)),3)) as [M03]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[4],0)),3)) as [M04]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[5],0)),3)) as [M05]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[6],0)),3)) as [M06]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[7],0)),3)) as [M07]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[8],0)),3)) as [M08]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[9],0)),3)) as [M09]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[10],0)),3)) as [M10]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[11],0)),3)) as [M11]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[12],0)),3)) as [M12]
				, CONVERT(DECIMAL(10,3),ROUND(AVG(ISNULL(pvt.[13],0)),3)) as [M13]
		FROM
		(SELECT COALESCE(Abbreviation, svc_c.[Result]) AS ResultShortName, svc_c.[Result], svc_c.[Month], AVG(ISNULL(svc_c.Avg_VisitCount,0)) AS Avg_VisitCount --CONVERT(DECIMAL(10,3),ROUND(SUM(svc_c.StoreVisitCount) * 1.000 / SUM(svc_c.StoreCount),3))) AS Avg_VisitCount
				FROM StoreVisitCount_CTE svc_c
					LEFT JOIN MarketGroupAbbreviation mga WITH (nolock) ON (CASE 
																	WHEN @Switch & 16 > 0 THEN 1
																	ELSE 0
																END) = 1 AND mga.MarketGroups = svc_c.[Result]			
				GROUP BY svc_c.[Month], svc_c.[Result], COALESCE(Abbreviation, svc_c.[Result])
		) avg_calc
		PIVOT
		(
			SUM(avg_calc.Avg_VisitCount)
				FOR avg_calc.[Month] IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13])
		) AS pvt
		GROUP BY  ResultShortName, pvt.Result
			WITH ROLLUP
			HAVING (pvt.ResultShortName IS NOT NULL AND pvt.[Result] IS NOT NULL)
			OR (pvt.ResultShortName IS NULL AND pvt.[Result] IS NULL)
		ORDER BY pvt.[Result]			


	SELECT rt.ResultId, rt.ResultName, rt.M01, rt.M02, rt.M03, rt.M04, rt.M05, rt.M06, rt.M07, rt.M08, rt.M09, rt.M10, rt.M11, rt.M12, rt.M13 
	FROM  @ResultTable rt
END

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Common_Drop_Down_Supporter' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Common_Drop_Down_Supporter]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Common_Drop_Down_Supporter]    Script Date: 3/2/2015 6:36:18 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

;
/*
	===========================================================================
	Based on the review conducted for Users Revamp, the following requirements
	where deducted:

	The stored procedure is used to populate the dropdowns from compliance and
	contribution reports. The @P_OrgId depicts the current organization, the
	@P_Id depicts the current logged user; @P_NextId isn't used.
	@P_Action type will designate the output of the stored procedure:

	- BIZPLAN_MARKET_SEARCH or STORE_MARKET_SEARCH will return a distinct list
		of regions either bellonging to the user's downline if it's a hierarchical
		user or the entire list of regions from the organization for the non
		hierarchical roles.

	- REPORT_ALL_ACCOUNT or REPORT_SELECT_ACCOUNT will return a list of distinct
		of divisions from the current user's downline. In addition, for the
		REPORT_SELECT_ACCOUNT option, we will filter the Accounts based on the
		specified value of @P_Other_1.
		
	- REPORT_ACCOUNT_REGION or REPORT_SELECT_ACCOUNT_SELECT_REGION will return
		a distinct list of MarketClusters from the selected user's downline. In
		addition, the values are beign filtered based on Account = @P_Other_1
		and Division = @P_Other_2; these parameters can have the metavlue 'All'.

	- REPORT_SELECT_ACCOUNT_SELECT_REGION_SELECT_MARKET or
		REPORT_ALL_ACCOUNT_SELECT_REGION_SELECT_MARKET will return a list of
		distinct users from the users downline. In addition will filter based
		on Geograohy and Account like this:
		in case of REPORT_SELECT_ACCOUNT_SELECT_REGION_SELECT_MARKET, we test
		that Account = @P_Other_1, Division = @P_Other_2 and Region = @P_Other_3
		in case of REPORT_ALL_ACCOUNT_SELECT_REGION_SELECT_MARKET, we test that
		Division = @P_Other_1 and Region = @P_Other_2

	- REPORT_SELECT_REGION will return the distinct list of regions from the
		current organization where Division = @P_Other_1

	- INDUSTRY will return the distinct list of industries from the current
		organization

	TestCase
	---------------------------------------------------------------------------
	EXEC [Common_Drop_Down_Supporter] 'STORE_MARKET_SEARCH'			, 11, 1
	EXEC [Common_Drop_Down_Supporter] 'REPORT_ALL_ACCOUNT'			, 18, 1
	EXEC [Common_Drop_Down_Supporter] 'REPORT_ALL_ACCOUNT'			, 18, 6538
	
	Utils to search for proper test cases:
	---------------------------------------------------------------------------

	===========================================================================
*/ --/*
CREATE PROCEDURE [dbo].[Common_Drop_Down_Supporter] (
	 @P_Action_Type	varchar(100)
	,@P_OrgId		int
	,@P_Id			int = NULL
	,@P_NextId		int = NULL
	,@P_Other_1		varchar(100) = ''
	,@P_Other_2		varchar(100) = ''
	,@P_Other_3		varchar(100) = ''
)
AS --*/
SET NOCOUNT ON
BEGIN
/* -- Stub param list for testing purposes
DECLARE 
	 @P_Action_Type	varchar(100)
	,@P_OrgId		int
	,@P_Id			int
	,@P_NextId		int
	,@P_Other_1		varchar(100)
	,@P_Other_2		varchar(100)
	,@P_Other_3		varchar(100)
;
SELECT
	 @P_Action_Type = 'REPORT_ALL_ACCOUNT'
	,@P_OrgId		= 11
	,@P_Id			= 1
	,@P_NextId		= NULL
	,@P_Other_1		= NULL
	,@P_Other_2		= NULL
	,@P_Other_3		= NULL
; --*/

	-- Type of the user
	DECLARE @P_BusinessRoleType int;
	SELECT 
		@P_BusinessRoleType = br.BusinessRoleType
	FROM UserOrgProfile uop WITH (NOLOCK)
		INNER JOIN BusinessRole br WITH (NOLOCK) ON uop.BusinessRoleID = br.BusinessRoleID
	WHERE 1 = 1
		AND uop.OrgID = @P_OrgId
		AND uop.UserID = @P_Id
	;
	-- Down-line's geographies
	DECLARE @DownlineGeographies TABLE (
		 DivisionRegionId	int
		,Division			varchar(100)
		,market_cluster		varchar(100)
		,Region				varchar(100)
	)
	;
	-- If needed somehow, populate the down-line geographies and apply the filtering
	IF @P_Action_Type = 'BIZPLAN_MARKET_SEARCH' OR @P_Action_Type = 'STORE_MARKET_SEARCH'
	OR @P_Action_Type = 'REPORT_ALL_ACCOUNT' OR @P_Action_Type = 'REPORT_SELECT_ACCOUNT'
	OR @P_Action_Type = 'REPORT_ACCOUNT_REGION' OR @P_Action_Type = 'REPORT_SELECT_ACCOUNT_SELECT_REGION'
		INSERT INTO @DownlineGeographies
		SELECT DISTINCT
			 dr.DivisionRegionId
			,dr.Division
			,dr.market_cluster
			,dr.Region
		FROM UserReporting_Function(@P_OrgId, @P_Id) urf
		  --INNER JOIN Users u WITH (NOLOCK) ON urf.UserID = u.UserId
			INNER JOIN StoreUserMapping stum WITH (NOLOCK) ON urf.UserID = stum.UserId
			INNER JOIN Store s WITH (NOLOCK) ON stum.StoreId = s.StoreId AND s.OrgId = @P_OrgId
			INNER JOIN DivisionRegion dr WITH (NOLOCK) ON s.DivisionRegionId = dr.DivisionRegionId
			INNER JOIN Account a WITH (NOLOCK) ON s.AccountId = a.AccountId
		WHERE 1 = 1
			AND s.isActive = 1
		  --AND (dr.isTestData = 0 OR u.isViewTestData = 1) -- filter for test data
			AND CASE
					WHEN @P_Action_Type = 'BIZPLAN_MARKET_SEARCH'					THEN 1
					WHEN @P_Action_Type = 'STORE_MARKET_SEARCH'						THEN 1
					WHEN @P_Action_Type = 'REPORT_ALL_ACCOUNT' 						THEN 1
					WHEN @P_Action_Type = 'REPORT_SELECT_ACCOUNT'
						AND a.AccountName = @P_Other_1								THEN 1
					WHEN @P_Action_Type = 'REPORT_ACCOUNT_REGION'
						AND (@P_Other_1 = 'All' OR a.AccountName 	= @P_Other_1)
						AND (@P_Other_2 = 'All' OR dr.Division 		= @P_Other_2)	THEN 1
					WHEN @P_Action_Type = 'REPORT_SELECT_ACCOUNT_SELECT_REGION'
						AND a.AccountName = @P_Other_1
						AND dr.Division	  = @P_Other_2								THEN 1
					-- Default filter out
					ELSE 0
				END = 1
	;

	-- Depending on the specified action parameter we will take the appropriate action

	IF @P_Action_Type = 'BIZPLAN_MARKET_SEARCH' OR @P_Action_Type = 'STORE_MARKET_SEARCH'
		BEGIN
			SELECT DISTINCT
				dr.Region
			FROM DivisionRegion dr WITH (NOLOCK)
				LEFT JOIN @DownlineGeographies dg ON dr.DivisionRegionId = dg.DivisionRegionId 
			WHERE 1 = 1 
				AND dr.OrgId = @P_OrgId
				AND dr.Region IS NOT NULL
				AND ( 1 = 0
						OR @P_BusinessRoleType != 8				-- is of non-hierarchical role
						OR dg.DivisionRegionId IS NOT NULL		-- filter based on down-line
					)
			ORDER BY
				dr.Region ASC
			;
		END
	ELSE IF @P_Action_Type = 'REPORT_ALL_ACCOUNT' OR @P_Action_Type = 'REPORT_SELECT_ACCOUNT'
		BEGIN
			SELECT DISTINCT
				dg.Division
			FROM @DownlineGeographies dg
			;
		END
	ELSE IF @P_Action_Type = 'REPORT_ACCOUNT_REGION' OR @P_Action_Type = 'REPORT_SELECT_ACCOUNT_SELECT_REGION'
		BEGIN
			SELECT DISTINCT
				MarketCluster = dg.market_cluster
			FROM @DownlineGeographies dg
			;
		END
	ELSE IF @P_Action_Type = 'REPORT_SELECT_USER_FROM_GEOGRAPHY'
		BEGIN
			SELECT DISTINCT
				 urf.UserId
				,Users = u.FullName + ' (' + u.UserName + ')'
			FROM UserReporting_Function(@P_OrgId, @P_Id) urf
				INNER JOIN Users u ON urf.UserID = u.UserId
				INNER JOIN StoreUserMapping stum WITH (NOLOCK) ON urf.UserID = stum.UserId
				INNER JOIN Store s WITH (NOLOCK) ON stum.StoreId = s.StoreId AND s.OrgId = @P_OrgId
				INNER JOIN DivisionRegion dr WITH (NOLOCK) ON s.DivisionRegionId = dr.DivisionRegionId
				INNER JOIN Account a WITH (NOLOCK) ON s.AccountId = a.AccountId
			WHERE 1 = 1
				AND s.isActive = 1
				AND u.isActive = 1
				AND (@P_Other_1 = 'All' OR dr.Division = @P_Other_1)
				AND (@P_Other_2 = 'All' OR dr.market_cluster = @P_Other_2)
				AND (@P_Other_3 = 'All' OR dr.Region = @P_Other_3)
			ORDER BY
				u.FullName + ' (' + u.UserName + ')'
			;
		END
	ELSE IF @P_Action_Type = 'REPORT_SELECT_REGION'
		BEGIN
			SELECT DISTINCT
				dr.Region
			FROM DivisionRegion dr WITH (NOLOCK)
			WHERE 1 = 1
				AND dr.OrgId = @P_OrgId
				AND dr.Division = @P_Other_1
				AND dr.Region IS NOT NULL
			;
		END
	ELSE IF @P_Action_Type = 'INDUSTRY'
		BEGIN
			SELECT
				 IndustryId
				,IndustryName
			FROM Industry WITH (NOLOCK)
			WHERE 1 = 1
				AND OrgId = @P_OrgId
				AND isActive = 1
			;
		END
	;
END
;

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Compliance_QuartzTimer' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Compliance_QuartzTimer]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Compliance_QuartzTimer]    Script Date: 3/2/2015 6:36:19 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [dbo].[Compliance_QuartzTimer]
(
	@OrgId varchar(10),
	@Today datetime
)
AS
SET NOCOUNT ON
BEGIN

	--RETURN 0

	SET NOCOUNT ON

	declare @ComplianceDate datetime

	SET @ComplianceDate = dateadd(dd,-1,@Today)

	-- Weekly Variable declaration
	declare @wFirstDateOfMonth datetime
	declare @wFirstDateOfCompWeek datetime
	declare @wLastDateOfCompWeek datetime
	declare @wLastDateOfMonth datetime
	declare @wLastDateOfLastWeekOfMonth datetime
	declare @wNextWeekFirstDate datetime

	DECLARE @wFirstDate datetime
	DECLARE @wLastDate datetime
	DECLARE @wNextDate datetime

	declare @wNumberOfWeeksForTheMonth int
	declare @wCurrWeekCountOfTheMonth int

	DECLARE @wFirstDateOfCurrCompPeriod datetime
	DECLARE @wLastDateOfCurrCompPeriod datetime

	DECLARE @FirstDateOfCurrCompPeriod datetime
	DECLARE @LastDateOfCurrCompPeriod datetime

	DECLARE @wCompPerWeek int

	DECLARE @WeeklyComplianceStartDay varchar(10)

	SET @WeeklyComplianceStartDay=''

	SELECT @WeeklyComplianceStartDay=WeeklyComplianceStartDay FROM Organization WHERE OrgId=@OrgId

	SELECT @wFirstDateOfCompWeek=dbo.[ComplianceWeeklyDate]('Previous',@ComplianceDate,@WeeklyComplianceStartDay)
	select @wLastDateOfCompWeek = dateadd(dd, 6, @wFirstDateOfCompWeek)

	select @wFirstDateOfMonth = dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@wLastDateOfCompWeek)), 0))
	select @wLastDateOfMonth = dateadd(dd,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@wLastDateOfCompWeek)), 0))

	select @wLastDateOfLastWeekOfMonth = (case 
											when DateName(dw,dateadd(dd,1,@wLastDateOfMonth))=@WeeklyComplianceStartDay
												then @wLastDateOfMonth 
											else dateadd(dd,-8,dbo.[ComplianceWeeklyDate]('Next',@wLastDateOfMonth,@WeeklyComplianceStartDay))
										  end)

	select @wNextWeekFirstDate = case 
									when @wLastDateOfCompWeek = @wLastDateOfLastWeekOfMonth
										then dateadd(mm,1,@wFirstDateOfMonth)
									 else dateadd(dd,1,@wLastDateOfCompWeek)
								end

	select @wNumberOfWeeksForTheMonth = (datepart(ww,@wLastDateOfLastWeekOfMonth)-datepart(ww,@wFirstDateOfMonth))+1
	select @wCurrWeekCountOfTheMonth = (datepart(ww,@wLastDateOfCompWeek)-datepart(ww,@wFirstDateOfMonth))+1

	SET @wFirstDate = CASE 
						WHEN @wCurrWeekCountOfTheMonth=1 
							THEN @wFirstDateOfMonth 
						ELSE @wFirstDateOfCompWeek 
					 END
	SET @wLastDate = @wLastDateOfCompWeek
	SET @wNextDate = @wNextWeekFirstDate

	SET @wCompPerWeek = 100/@wNumberOfWeeksForTheMonth

	SELECT @wFirstDateOFCurrCompPeriod=dbo.[ComplianceWeeklyDate]('Previous',getdate(),@WeeklyComplianceStartDay)
	SELECT @wLastDateOfCurrCompPeriod = dateadd(d,6,@wFirstDateOfCurrCompPeriod)

--	select 'Weekly' Category
--		 , convert(varchar(10),@ComplianceDate,102) ComplianceDate
--		 , convert(varchar(10),@wFirstDateOfCompWeek,102) FirstDateOfCompWeek
--		 , convert(varchar(10),@wLastDateOfCompWeek,102) LastDateOfCompWeek
--		 , convert(varchar(10),@wNextWeekFirstDate,102) NextWeekFirstDate
--		 , convert(varchar(10),@wFirstDateOfMonth,102) FirstDateOfMonth
--		 , convert(varchar(10),@wLastDateOfMonth,102) LastDateOfMonth
--		 , convert(varchar(10),@wLastDateOfLastWeekOfMonth,102) LastDateOfLastWeekOfMonth
--		 , convert(varchar(10),@wNumberOfWeeksForTheMonth,102) NoOfWeeksForTheMonth
--		 , convert(varchar(10),@wCurrWeekCountOfTheMonth,102) CurrWeekCountOfTheMonth
--		 , convert(varchar(10),@wCompPerWeek,102) CompPerWeek
--		 , convert(varchar(10),@wFirstDate, 102) FirstDate
--		 , convert(varchar(10),@wLastDate,102) LastDate
--		 , convert(varchar(10),@wNextDate,102) NextStartDate
--		 , convert(varchar(10),@wFirstDateOfCurrCompPeriod,102) FirstDateOfCurrCompPeriod
--		 , convert(varchar(10),@wLastDateOfCurrCompPeriod,102) LastDateOfCurrCompPeriod

--		RETURN 0

	-- Weekly Variable declaration - end

	-- Monthly Variable declaration
	DECLARE @mFirstDate datetime
	DECLARE @mLastDate datetime
	DECLARE @mNextDate datetime

	DECLARE @mFirstDateOfCurrCompPeriod datetime
	DECLARE @mLastDateOfCurrCompPeriod datetime

	SET @mFirstDate = dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@ComplianceDate)), 0))
	SET @mLastDate = dateadd(d,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@mFirstDate)), 0))
	SET @mNextDate = dateadd(mm,1,@mFirstDate)

	SET @mFirstDateOfCurrCompPeriod = dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1, getdate())), 0))
	SET @mLastDateOfCurrCompPeriod = dateadd(d,-1,dateadd(m, datediff(m, 0, dateadd(m, 1, getdate())), 0))

--	SELECT 'Monthly' Category
--		 , convert(varchar(10),@mFirstDate,102) FirstDate
--		 , convert(varchar(10),@mLastDate,102) LastDate
--		 , convert(varchar(10),@mNextDate,102) NextDate
--		 , convert(varchar(10),@mFirstDateOfCurrCompPeriod,102) FirstDateOfCurrMonth
--		 , convert(varchar(10),@mLastDateOfCurrCompPeriod,102) LastDateOfCurrMonth

	-- Monthly Variable declaration - end

	-- BiWeekly Variable declaration
	DECLARE @bFirstDate datetime
	DECLARE @bLastDate datetime
	DECLARE @bNextDate datetime

	DECLARE @bFirstDateOfCurrCompPeriod datetime
	DECLARE @bLastDateOfCurrCompPeriod datetime

	IF (datepart(dd,@ComplianceDate) < 16)
	BEGIN
		SET @bFirstDate = dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@ComplianceDate)), 0))
		SET @bLastDate = dateadd(d,14,@bFirstDate)
		SET @bNextDate = dateadd(dd,1,@bLastDate)
	END
	ELSE
	BEGIN
		SET @bFirstDate = dateadd(dd, 15, dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@ComplianceDate)), 0)))
		SET @bLastDate = dateadd(d,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@bFirstDate)), 0))
		SET @bNextDate = dateadd(dd,1,@bLastDate)
	END

	IF (datepart(dd,getdate()) < 16)
	BEGIN
		SET @bFirstDateOfCurrCompPeriod = dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))
		SET @bLastDateOfCurrCompPeriod = dateadd(d,14,@bFirstDateOfCurrCompPeriod)
	END
	ELSE
	BEGIN
		SET @bFirstDateOfCurrCompPeriod = dateadd(dd, 15, dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0)))
		SET @bLastDateOfCurrCompPeriod = dateadd(d,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@bFirstDateOfCurrCompPeriod)), 0))
	END

--	SELECT 'BiWeekly' Category
--		 , convert(varchar(10),@bFirstDate,102) FirstDate
--		 , convert(varchar(10),@bLastDate,102) LastDate
--		 , convert(varchar(10),@bNextDate,102) NextDate
--		 , convert(varchar(10),@bFirstDateOfCurrCompPeriod,102) FirstDateOfCurrPeriod
--		 , convert(varchar(10),@bLastDateOfCurrCompPeriod,102) LastDateOfCurrPeriod

	-- BiWeekly Variable declaration - end

	-- Generic variables
	DECLARE @FirstDate datetime
	DECLARE @LastDate datetime
	DECLARE @NextDate datetime
	DECLARE @ComplianceNext numeric(6,2)
	DECLARE @DoCompCalc bit
	-- Generic variables - end

--	RETURN 0

	DECLARE @StoreId int
		,	@StoreVisitGPSCount int
		,	@StoreVisitNonGPSCount int
		,	@StoreVisitTotal int
		,	@StoreVisitCategory varchar(50)
		,	@StoreVisitRule int
		,	@StoreVisitEffectiveDate datetime
		,	@StoreVisitCategoryNew  varchar(50)
		,	@StoreVisitRuleNew int
		,	@StoreVisitEffectiveDateNew datetime
		,	@ComplianceLastId int
		,	@ComplianceLastCategory varchar(50)
		,	@ComplianceLastRule int
		,	@ComplianceLast numeric(6,2)
		,	@ComplianceLastDate datetime
		,	@ComplianceLastRecent int
		,	@ComplianceLastInitial int
		,	@ComplianceNew numeric(6,2)
		,	@FrequencyChangeFlag varchar(5)

		,	@ComplianceNewId int
		,	@LastRunDate datetime
		,	@RecentForTheMonth int 

		,	@ComplianceTempId int
		,	@IsCalculatedFlag int

	DECLARE AllStores_Cursor CURSOR FOR
	SELECT	StoreId 
		,	StoreVisitsCategory
		,	StoreVisitRule
		,	StoreVisitEffectiveDate
		,	StoreVisitsCategoryNew
		,	StoreVisitRuleNew
		,	StoreVisitEffectiveDateNew
	FROM	Store
	WHERE   IsActive=1
		AND   OrgId=@OrgId
		/** Requirement changes - compliance on/off */
		AND IsCompliance = 1

	--AND		StoreVisitsCategory='Weekly'
	--AND		StoreId=2012
	--AND StoreId IN ('40404', '40403', '40402', '40401', '40400', '40399', '40398', '40397', '40396')
	ORDER BY StoreId


-- Cursor starts
	OPEN AllStores_Cursor;

	FETCH NEXT FROM AllStores_Cursor 
		INTO
			@StoreId 
		,	@StoreVisitCategory
		,	@StoreVisitRule
		,	@StoreVisitEffectiveDate
		,	@StoreVisitCategoryNew
		,	@StoreVisitRuleNew
		,	@StoreVisitEffectiveDateNew

	WHILE @@FETCH_STATUS = 0
	BEGIN

		SET @FirstDate = NULL
		SET @LastDate = NULL
		SET @NextDate = NULL
		SET @DoCompCalc = 0
		SET @LastRunDate=NULL
		SET	@FrequencyChangeFlag=NULL
		SET @RecentForTheMonth=NULL
		SET @IsCalculatedFlag=0

		--PRINT '@StoreId = '--+ str(@StoreId)
		IF @StoreVisitCategory='Weekly'
		BEGIN

			SET @FirstDate = @wFirstDateOfCompWeek
			SET @LastDate  = @wLastDateOfCompWeek
			SET @NextDate  = @wNextDate

			SET @FirstDateOfCurrCompPeriod  = @wFirstDateOfCurrCompPeriod
			SET @LastDateOfCurrCompPeriod  = @wLastDateOfCurrCompPeriod

		END

		IF @StoreVisitCategory='BiWeekly'
		BEGIN

			SET @FirstDate = @bFirstDate
			SET @LastDate  = @bLastDate
			SET @NextDate  = @bNextDate

			SET @FirstDateOfCurrCompPeriod  = @bFirstDateOfCurrCompPeriod
			SET @LastDateOfCurrCompPeriod  = @bLastDateOfCurrCompPeriod

		END

		IF @StoreVisitCategory='Monthly'
		BEGIN

			SET @FirstDate = @mFirstDate
			SET @LastDate  = @mLastDate
			SET @NextDate  = @mNextDate

			SET @FirstDateOfCurrCompPeriod  = @mFirstDateOfCurrCompPeriod
			SET @LastDateOfCurrCompPeriod  = @mLastDateOfCurrCompPeriod

		END

		--PRINT '@FirstDate: '+cast(@FirstDate as varchar(10))
		--PRINT '@LastDate: '+cast(@LastDate as varchar(10))

		-- Check for no entry in compliance history if not then insert an entry
		IF 
			(
				SELECT	MAX(ComplianceId)
				FROM	ComplianceHistory
				WHERE	StoreId=@StoreId
			) 
			IS NULL

		BEGIN
			EXEC [ComplianceInsertForStoreId] 
					@StoreId
				,	@StoreVisitCategory
				,	@StoreVisitRule
				,	100
				,	@FirstDate
				,	1
				,	1
				,	@IsCalculatedFlag
				,	@ComplianceNewId
		END

		IF (@ComplianceDate=@LastDate)
			SET @DoCompCalc = 1

		--PRINT '@DoCompCalc = ' + str(@DoCompCalc)
		IF (@DoCompCalc = 1)
		BEGIN

			SELECT	@ComplianceLastId=ComplianceId
				,	@ComplianceLastCategory=StoreVisitsCategory
				,	@ComplianceLastRule=StoreVisitRule
				,	@ComplianceLastDate=Date
				,	@ComplianceLast=Compliance
				,	@ComplianceLastRecent=RecentForMonth
				,	@ComplianceLastInitial=InitialDateFlag
				,	@FrequencyChangeFlag=FrequencyChangeFlag
			FROM	ComplianceHistory
			WHERE	StoreId=@StoreId
			AND		ComplianceId = 
						(
							SELECT	MAX(ComplianceId)
							FROM	ComplianceHistory
							WHERE	StoreId=@StoreId
						)

			IF @StoreVisitCategory='Weekly' and @FrequencyChangeFlag='MW'
				SET @FirstDate = @mFirstDate

			IF @StoreVisitCategory='Weekly' and @FrequencyChangeFlag='BW'
				SET @FirstDate = @mFirstDate

			SET @StoreVisitGPSCount=0
			SET @StoreVisitNonGPSCount=0

			SELECT	@StoreVisitGPSCount=isnull(sum(case when GpsInsideGeofence='YES' then 1 end),0)
				,	@StoreVisitNonGPSCount = isnull(sum(case when GpsInsideGeofence='NO' then 1 end),0)
			FROM	FormVisit
			INNER JOIN Forms ON Forms.FormId=FormVisit.FormId AND Forms.isApplyToCompliance=1
			WHERE	(VisitDate BETWEEN	@FirstDate 
							   AND		dateadd(ss,-1,dateadd(dd,1,@LastDate)))
			AND		StoreId = @StoreId

			SET @StoreVisitTotal=@StoreVisitGPSCount+@StoreVisitNonGPSCount

--			SELECT	@ComplianceLastId as ComplianceLastId
--				,	@ComplianceLastCategory as LastCategory
--				,	@ComplianceLastRule as LastRule
--				,	@ComplianceLastDate as LastDate
--				,	@ComplianceLastRecent as LastRecent
--				,	@ComplianceLastInitial as LastInitial
--				,	@StoreVisitCategory as CategoryCurr
--				,	@StoreVisitCategoryNew as CategoryNew
--				,	@StoreVisitEffectiveDateNew as EffectiveDateNew
--				,	@FirstDate as FirstDate
--				,	@NextDate as NextDate

			--PRINT '@StoreVisitCategory = '+@StoreVisitCategory
			--PRINT '@FrequencyChangeFlag = '+@FrequencyChangeFlag

			IF @StoreVisitCategory='Weekly'
			BEGIN

				IF (@FrequencyChangeFlag IS NULL)
				BEGIN
						SET @ComplianceNew = @ComplianceLast
													- ((@wCompPerWeek*1.0000/@ComplianceLastRule)
														*(@ComplianceLastRule
															-case when @ComplianceLastRule>@StoreVisitTotal 
																		then @StoreVisitTotal 
																		else @ComplianceLastRule
															 end))
					SET @ComplianceNext = 
						CASE 
							WHEN @wCurrWeekCountOfTheMonth=@wNumberOfWeeksForTheMonth
								THEN 100 
							ELSE @ComplianceNew 
						END
					SET @IsCalculatedFlag=1
				END
				ELSE
				IF (@FrequencyChangeFlag='MW')
				BEGIN
					SET @ComplianceNew = 100
					SET @ComplianceNext = 100
					SET @FirstDate = @mFirstDate
				END
				ELSE
				IF (@FrequencyChangeFlag='BW')
				BEGIN
					SET @ComplianceNew = 100
					SET @ComplianceNext = 100
					SET @FirstDate = @mFirstDate
				END

				IF (@FrequencyChangeFlag='NewW')
				BEGIN
					SET @ComplianceNew = 100
					SET @ComplianceNext = 100
				END

			END

			IF @StoreVisitCategory='BiWeekly'
			BEGIN

				--PRINT 'Inside BiWeekly calc'

				--PRINT '@ComplianceLast=' + str(@ComplianceLast)
				--PRINT '@Compliance Calc=' + str((50.0000/@ComplianceLastRule*(@ComplianceLastRule-@StoreVisitTotal)))

				SET @ComplianceNew = @ComplianceLast
				IF ((@ComplianceLastRule-@StoreVisitTotal)> 0)
					SET @ComplianceNew = @ComplianceNew - 
										 --(50.0000/@ComplianceLastRule*(@ComplianceLastRule-@StoreVisitTotal))
										 (50.0000/@ComplianceLastRule*(@ComplianceLastRule
										-case when @ComplianceLastRule>@StoreVisitTotal 
													then @StoreVisitTotal 
													else @ComplianceLastRule
										 end))
				SET @ComplianceNext = 
					CASE 
						WHEN datepart(dd,@ComplianceDate)=15
							THEN @ComplianceNew
						ELSE 100
					END

				SET @IsCalculatedFlag=1

				--PRINT '@ComplianceNew=' + str(@ComplianceNew)
				--PRINT '@ComplianceNext=' + str(@ComplianceNext)
			END

			IF @StoreVisitCategory='Monthly'
			BEGIN

				SET @ComplianceNew = 100.00
				IF ((@ComplianceLastRule-@StoreVisitTotal)> 0)
					SET @ComplianceNew = @ComplianceNew*1.0000/@ComplianceLastRule*@StoreVisitTotal

				SET @ComplianceNext = 100
				SET @IsCalculatedFlag=1

				--PRINT '@ComplianceNew'+str(@ComplianceNew)
				--PRINT '@ComplianceNext'+str(@ComplianceNext)
			END

			-- For new store with future date
			IF	(@StoreVisitEffectiveDate>@ComplianceDate)
			BEGIN
				SET @ComplianceNew = 100.00
				SET @ComplianceNext = 100.00
			END
			
			SET @RecentForTheMonth = CASE WHEN datepart(mm,@ComplianceDate)=datepart(mm,@Today) THEN 0 ELSE 1 END

			EXEC [ComplianceUpdateByCompId] 
					@ComplianceLastId
				,	@StoreVisitGPSCount
				,	@StoreVisitNonGPSCount
				,	@StoreVisitTotal
				,	@ComplianceNew
				,	@LastDate
				,	0
				,	0
				,	@IsCalculatedFlag

			-- No change in Freq
			IF	(@StoreVisitCategory=@StoreVisitCategoryNew)
			AND (@StoreVisitRule=@StoreVisitRuleNew)
			AND (@StoreVisitEffectiveDate=@StoreVisitEffectiveDateNew)
			BEGIN

				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategory
					,	@StoreVisitRule
					,	@ComplianceNext
					,	@NextDate
					,	1
					,	1
					,	0
					,	@ComplianceNewId

				IF	(@StoreVisitEffectiveDate>@Today)
				BEGIN
					SET @ComplianceNewId=NULL
					SELECT @ComplianceNewId=max(ComplianceId) FROM ComplianceHistory
					WHERE StoreId = @StoreId
					UPDATE ComplianceHistory SET
							FrequencyChangeFlag='NewW'
					WHERE ComplianceId=@ComplianceNewId
				END

			END
			ELSE
			--   Monthly to Weekly
			IF	(@StoreVisitCategory='Monthly' and @StoreVisitCategoryNew='Weekly')
			AND (@StoreVisitEffectiveDateNew=@Today)
			BEGIN

				--PRINT ' Monthly to Weekly'

				SET @ComplianceNewId=NULL
				SELECT @StoreVisitCategoryNew, @StoreVisitRuleNew,@NextDate
				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategoryNew
					,	@StoreVisitRuleNew
					,	100.00
					,	@NextDate
					,	1
					,	1
					,	0
					,	@ComplianceNewId

				SELECT @ComplianceNewId=max(ComplianceId) FROM ComplianceHistory
				WHERE StoreId = @StoreId

				--PRINT 'New='+str(@ComplianceNewId)

				UPDATE ComplianceHistory SET
						FrequencyChangeFlag='MW'
				WHERE ComplianceId=@ComplianceNewId

				EXEC [Compliance_ChangeStoreFrequency] @StoreId

			END --   Monthly to Weekly - end
			ELSE
			--   Monthly to BiWeekly
			IF	(@StoreVisitCategory='Monthly' and @StoreVisitCategoryNew='BiWeekly')
			AND (@StoreVisitEffectiveDateNew=@Today)
			BEGIN

				--PRINT ' Monthly to BiWeekly'

				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategoryNew
					,	@StoreVisitRuleNew
					,	100.00
					,	@Today
					,	1
					,	1
					,	0
					,	@ComplianceNewId

				EXEC [Compliance_ChangeStoreFrequency] @StoreId

			END --   Monthly to BiWeekly
			ELSE
			--   BiWeekly to Monthly
			IF	(@StoreVisitCategory='BiWeekly' and @StoreVisitCategoryNew='Monthly')
			AND (@StoreVisitEffectiveDateNew=@Today)
			BEGIN

				--PRINT ' BiWeekly to Monthly'

				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategoryNew
					,	@StoreVisitRuleNew
					,	100.00
					,	@Today
					,	1
					,	1
					,	0
					,	@ComplianceNewId

				EXEC [Compliance_ChangeStoreFrequency] @StoreId

			END --   BiWeekly to Monthly - end
			ELSE
			--   BiWeekly to Weekly
			IF	(@StoreVisitCategory='BiWeekly' and @StoreVisitCategoryNew='Weekly')
			AND (@StoreVisitEffectiveDateNew=@Today)
			BEGIN

				--PRINT ' BiWeekly to Weekly'

				SET @ComplianceNewId=NULL
				SELECT @StoreVisitCategoryNew, @StoreVisitRuleNew,@NextDate
				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategoryNew
					,	@StoreVisitRuleNew
					,	100.00
					,	@NextDate
					,	1
					,	1
					,	0
					,	@ComplianceNewId

				SELECT @ComplianceNewId=max(ComplianceId) FROM ComplianceHistory
				WHERE StoreId = @StoreId

				--PRINT 'New='+str(@ComplianceNewId)

				UPDATE ComplianceHistory SET
						FrequencyChangeFlag='BW'
				WHERE ComplianceId=@ComplianceNewId

				EXEC [Compliance_ChangeStoreFrequency] @StoreId

			END -- BiWeekly to Weekly - end
			ELSE
			--   Weekly to BiWeekly/Monthly
			IF	(@StoreVisitCategory='Weekly' and @StoreVisitCategoryNew in ('BiWeekly','Monthly'))
			AND (@StoreVisitEffectiveDateNew=@Today)
			BEGIN

				--PRINT ' Weekly to BiWeekly/Monthly'

				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategoryNew
					,	@StoreVisitRuleNew
					,	100.00
					,	@Today
					,	1
					,	1
					,	0
					,	@ComplianceNewId

				EXEC [Compliance_ChangeStoreFrequency] @StoreId

			END -- Weekly to BiWeekly/Monthly - end
			ELSE  -- Not met in any above changeover
			/** When Changing StoreVisitRule */
			IF	(@StoreVisitEffectiveDateNew=@Today AND @StoreVisitRule<>@StoreVisitRuleNew)
				BEGIN
					--PRINT '@StoreVisitRule --'+STR(@StoreVisitRule)
					--PRINT '@StoreVisitRuleNew --'+STR(@StoreVisitRuleNew)

					EXEC [Compliance_ChangeStoreFrequency] @StoreId

					EXEC [ComplianceInsertForStoreId] 
							@StoreId
						,	@StoreVisitCategory
						,	@StoreVisitRuleNew
						,	@ComplianceNext
						,	@NextDate
						,	1
						,	1
						,	0
						,	@ComplianceNewId


					--PRINT 'CALLED - Compliance_ChangeStoreFrequency'
				END
			ELSE 
			BEGIN
				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategory
					,	@StoreVisitRule
					,	@ComplianceNext
					,	@NextDate
					,	1
					,	1
					,	0
					,	@ComplianceNewId
			END

			-- Update zero for store visit counter

			SET @StoreVisitGPSCount=0
			SET @StoreVisitNonGPSCount=0

			SELECT	@StoreVisitGPSCount=isnull(sum(case when GpsInsideGeofence='YES' then 1 end),0)
				,	@StoreVisitNonGPSCount = isnull(sum(case when GpsInsideGeofence='NO' then 1 end),0)
			FROM	FormVisit
			INNER JOIN Forms ON Forms.FormId=FormVisit.FormId AND Forms.isApplyToCompliance=1
			WHERE	(VisitDate BETWEEN	@FirstDateOFCurrCompPeriod 
							   AND		dateadd(ss,-1,dateadd(dd,1,@LastDateOfCurrCompPeriod)))
			AND		StoreId = @StoreId

			UPDATE Store SET
				StoreVisitGPSCount=@StoreVisitGPSCount,
				StoreVisitNonGPSCount=@StoreVisitNonGPSCount
			WHERE StoreId = @StoreId

		END  -- End of Do Compliance
		ELSE
		BEGIN
			--   Weekly to Monthly
			IF	(@StoreVisitCategory='Weekly' and @StoreVisitCategoryNew='Monthly')
			AND (@StoreVisitEffectiveDateNew=@Today)
			BEGIN

				--PRINT ' Weekly to Monthly'

				DELETE ComplianceHistory
				WHERE	ComplianceId = 
							(
								SELECT	MAX(ComplianceId)
								FROM	ComplianceHistory
								WHERE	StoreId=@StoreId
							)

				SELECT @LastRunDate=Date FROM ComplianceHistory
				WHERE 
						ComplianceId = 
							(
								SELECT	MAX(ComplianceId)
								FROM	ComplianceHistory
								WHERE	StoreId=@StoreId
							)
				-- If there is gap between end of last week and 1st of current month
				-- then insert a new record with count of visits without calculating compliance
				IF (datediff(dd,@LastRunDate,@Today)) > 0
				BEGIN

					SELECT	@ComplianceLastId=ComplianceId
						,	@ComplianceLastCategory=StoreVisitsCategory
						,	@ComplianceLastRule=StoreVisitRule
						,	@ComplianceLastDate=Date
						,	@ComplianceLast=Compliance
						,	@ComplianceLastRecent=RecentForMonth
						,	@ComplianceLastInitial=InitialDateFlag
					FROM	ComplianceHistory
					WHERE	StoreId=@StoreId
					AND		ComplianceId = 
								(
									SELECT	MAX(ComplianceId)
									FROM	ComplianceHistory
									WHERE	StoreId=@StoreId
								)

					--PRINT '@ComplianceLastId='+str(@ComplianceLastId)

					UPDATE ComplianceHistory SET
							RecentForMonth=0
						,	InitialDateFlag=0
						--,	IsCalculatedFlag=0
					WHERE ComplianceId=@ComplianceLastId

					EXEC [ComplianceInsertForStoreId] 
							@StoreId
						,	@ComplianceLastCategory
						,	@ComplianceLastRule
						,	@ComplianceLast
						,	@ComplianceDate
						,	1
						,	0
						,	0
						,	@ComplianceNewId

					SET @StoreVisitGPSCount=0
					SET @StoreVisitNonGPSCount=0

					SELECT	@StoreVisitGPSCount=isnull(sum(case when GpsInsideGeofence='YES' then 1 end),0)
						,	@StoreVisitNonGPSCount = isnull(sum(case when GpsInsideGeofence='NO' then 1 end),0)
					FROM	FormVisit
					INNER JOIN Forms ON Forms.FormId=FormVisit.FormId AND Forms.isApplyToCompliance=1
					WHERE	(VisitDate BETWEEN	dateadd(dd,1,@LastRunDate )
									   AND		@Today)
					AND		StoreId = @StoreId

					SET @StoreVisitTotal=@StoreVisitGPSCount+@StoreVisitNonGPSCount

					EXEC [ComplianceUpdateByCompId] 
							@ComplianceNewId
						,	@StoreVisitGPSCount
						,	@StoreVisitNonGPSCount
						,	@StoreVisitTotal
						,	@ComplianceLast
						,	@ComplianceDate
						,	1
						,	0
						,	0

				END -- IF (datediff(dd,@LastRunDate,@Today)) > 0

				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategoryNew
					,	@StoreVisitRuleNew
					,	100.00
					,	@Today
					,	1
					,	1
					,	0
					,	@ComplianceNewId

				EXEC [Compliance_ChangeStoreFrequency] @StoreId

				SET @StoreVisitGPSCount=0
				SET @StoreVisitNonGPSCount=0

				SELECT	@StoreVisitGPSCount=isnull(sum(case when GpsInsideGeofence='YES' then 1 end),0)
					,	@StoreVisitNonGPSCount = isnull(sum(case when GpsInsideGeofence='NO' then 1 end),0)
				FROM	FormVisit
				INNER JOIN Forms ON Forms.FormId=FormVisit.FormId AND Forms.isApplyToCompliance=1
				WHERE	(VisitDate BETWEEN	@mFirstDateOFCurrCompPeriod 
								   AND		dateadd(ss,-1,dateadd(dd,1,@mLastDateOfCurrCompPeriod)))
				AND		StoreId = @StoreId

				UPDATE Store SET
					StoreVisitGPSCount=@StoreVisitGPSCount,
					StoreVisitNonGPSCount=@StoreVisitNonGPSCount
				WHERE StoreId = @StoreId

			END --   Weekly to Monthly - end

			--   Weekly to BiWeekly
			IF	(@StoreVisitCategory='Weekly' and @StoreVisitCategoryNew='BiWeekly')
			AND (@StoreVisitEffectiveDateNew=@Today)
			BEGIN

				--PRINT ' Weekly to BiWeekly'

				DELETE ComplianceHistory
				WHERE	ComplianceId = 
							(
								SELECT	MAX(ComplianceId)
								FROM	ComplianceHistory
								WHERE	StoreId=@StoreId
							)

				SELECT @LastRunDate=Date FROM ComplianceHistory
				WHERE 
						ComplianceId = 
							(
								SELECT	MAX(ComplianceId)
								FROM	ComplianceHistory
								WHERE	StoreId=@StoreId
							)
				IF (datediff(dd,@LastRunDate,@Today)) > 0
				BEGIN

					SELECT	@ComplianceLastId=ComplianceId
						,	@ComplianceLastCategory=StoreVisitsCategory
						,	@ComplianceLastRule=StoreVisitRule
						,	@ComplianceLastDate=Date
						,	@ComplianceLast=Compliance
						,	@ComplianceLastRecent=RecentForMonth
						,	@ComplianceLastInitial=InitialDateFlag
					FROM	ComplianceHistory
					WHERE	StoreId=@StoreId
					AND		ComplianceId = 
								(
									SELECT	MAX(ComplianceId)
									FROM	ComplianceHistory
									WHERE	StoreId=@StoreId
								)

					UPDATE ComplianceHistory SET
							RecentForMonth=0
						,	InitialDateFlag=0
					WHERE ComplianceId=@ComplianceLastId

					EXEC [ComplianceInsertForStoreId] 
							@StoreId
						,	@ComplianceLastCategory
						,	@ComplianceLastRule
						,	@ComplianceLast
						,	@ComplianceDate
						,	1
						,	0
						,	0
						,	@ComplianceNewId

					SET @StoreVisitGPSCount=0
					SET @StoreVisitNonGPSCount=0

					SELECT	@StoreVisitGPSCount=isnull(sum(case when GpsInsideGeofence='YES' then 1 end),0)
						,	@StoreVisitNonGPSCount = isnull(sum(case when GpsInsideGeofence='NO' then 1 end),0)
					FROM	FormVisit
					INNER JOIN Forms ON Forms.FormId=FormVisit.FormId AND Forms.isApplyToCompliance=1
					WHERE	(VisitDate BETWEEN	dateadd(dd,1,@LastRunDate )
									   AND		@Today)
					AND		StoreId = @StoreId

					SET @StoreVisitTotal=@StoreVisitGPSCount+@StoreVisitNonGPSCount

					EXEC [ComplianceUpdateByCompId] 
							@ComplianceNewId
						,	@StoreVisitGPSCount
						,	@StoreVisitNonGPSCount
						,	@StoreVisitTotal
						,	@ComplianceLast
						,	@ComplianceDate
						,	1
						,	0
						,	0

				END -- IF (datediff(dd,@LastRunDate,@Today)) > 0

				SET @ComplianceNew = CASE WHEN datepart(dd,@Today) = 16 THEN @ComplianceNew ELSE 100 END
				EXEC [ComplianceInsertForStoreId] 
						@StoreId
					,	@StoreVisitCategoryNew
					,	@StoreVisitRuleNew
					,	@ComplianceNew
					,	@Today
					,	1
					,	1
					,	0
					,	@ComplianceNewId

				EXEC [Compliance_ChangeStoreFrequency] @StoreId

				SET @StoreVisitGPSCount=0
				SET @StoreVisitNonGPSCount=0

				SELECT	@StoreVisitGPSCount=isnull(sum(case when GpsInsideGeofence='YES' then 1 end),0)
					,	@StoreVisitNonGPSCount = isnull(sum(case when GpsInsideGeofence='NO' then 1 end),0)
				FROM	FormVisit
				INNER JOIN Forms ON Forms.FormId=FormVisit.FormId AND Forms.isApplyToCompliance=1
				WHERE	(VisitDate BETWEEN	@bFirstDateOFCurrCompPeriod 
								   AND		dateadd(ss,-1,dateadd(dd,1,@bLastDateOfCurrCompPeriod)))
				AND		StoreId = @StoreId

				UPDATE Store SET
					StoreVisitGPSCount=@StoreVisitGPSCount,
					StoreVisitNonGPSCount=@StoreVisitNonGPSCount
				WHERE StoreId = @StoreId

			END --   Weekly to Biweekly - end

		END -- End of Do Compliance

		SELECT TOP 2 @ComplianceTempId=ComplianceId
		FROM	ComplianceHistory
		WHERE	StoreId=@StoreId
		ORDER BY ComplianceId desc

		SELECT @LastRunDate=Date FROM ComplianceHistory
		WHERE 
				ComplianceId = 
					(
						SELECT	MAX(ComplianceId)
						FROM	ComplianceHistory
						WHERE	StoreId=@StoreId
					)

		--PRINT '@ComplianceTempId = '+STR(@ComplianceTempId)
		--PRINT '@ComplianceDate = '+cast(@ComplianceDate as varchar)
		--PRINT '@Today = '+cast(@Today as varchar)

		IF (@ComplianceTempId IS NOT NULL AND datepart(mm,@ComplianceDate)<>datepart(mm,@LastRunDate))
		BEGIN
			UPDATE ComplianceHistory SET
					RecentForMonth=1
				,	InitialDateFlag=0
			WHERE ComplianceId=@ComplianceTempId
		END

		FETCH NEXT FROM AllStores_Cursor 
			INTO
				@StoreId 
			,	@StoreVisitCategory
			,	@StoreVisitRule
			,	@StoreVisitEffectiveDate
			,	@StoreVisitCategoryNew
			,	@StoreVisitRuleNew
			,	@StoreVisitEffectiveDateNew

	END

	CLOSE AllStores_Cursor
	DEALLOCATE AllStores_Cursor

END

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'ComplianceReport_ByStore' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[ComplianceReport_ByStore]')
	END
GO
/****** Object:  StoredProcedure [dbo].[ComplianceReport_ByStore]    Script Date: 3/2/2015 6:36:21 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[ComplianceReport_ByStore] (
  @pInitialName   VARCHAR(50),
  @pOrgId			VARCHAR(50),
  @pUserId		VARCHAR(50),
  @pMonth			VARCHAR(50),
  @pAccountName	VARCHAR(100)='',
  @pRegion		VARCHAR(100)='',
  @pMarketGroup	VARCHAR(100)='',
  @pRepID			VARCHAR(100)=''
)

AS
SET NOCOUNT ON
BEGIN

-- Declare
  DECLARE @NofMonths int
  DECLARE @CUIDColumnName varchar(40)
  DECLARE @SQL varchar(max)
  DECLARE @strColNames varchar(max)
  DECLARE @whereCondition varchar(max)
  DECLARE @ResultId varchar(50)
  DECLARE @ResultName varchar(50)
  DECLARE @pRoleLevelNum int
  DECLARE @ResultShortName varchar(50)
  DECLARE @ResultShortNameWhereAndGroup varchar(200)
  DECLARE @AliasName varchar(5)
  DECLARE @AdditionalTable varchar(50)
  DECLARE @NickNameSQL varchar(1000)

  DECLARE @IsCompliance bit
  SET @IsCompliance = 1
  SELECT @IsCompliance = IsCompliance From Organization Where OrgId = @pOrgId
  IF @IsCompliance = 0
    SET @pUserId='0'

-- Set
  SET @ResultId=''
  SET @ResultName=''
  SET @CUIDColumnName=''
  SET @NofMonths=12
  SET @whereCondition=''
  SET @AliasName = 'st.'
  SET @AdditionalTable = ''
  SET @NickNameSQL = ''

  SET @ResultId = 'StoreId'
  SET @ResultName = 'StoreName'

  IF @pAccountName in ('ALL','SELECT')
    SET @pAccountName=''

  IF @pRegion in ('ALL','SELECT')
    SET @pRegion=''

  IF @pMarketGroup in ('ALL','SELECT')
    SET @pMarketGroup=''

  IF @pRepID in ('ALL','SELECT')
    SET @pRepID=''

-- Define filters
  IF @pAccountName!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.AccountName='''+@pAccountName+''''
      SET @ResultId = 'StoreId'
      SET @ResultName = 'StoreName'
      SET @AliasName = 'st.'
    END
  IF @pRegion!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.DivisionName='''+@pRegion+''''
      SET @ResultId = 'StoreId'
      SET @ResultName = 'StoreName'
      SET @AliasName = 'st.'
    END
  IF @pMarketGroup!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.RegionName='''+@pMarketGroup+''''
      SET @ResultId = 'StoreId'
      SET @ResultName = 'StoreName'
      SET @AliasName = 'st.'
    END
  IF @pRepID!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.FullName='''+@pRepID+''''
      SET @ResultId = 'StoreId'
      SET @ResultName = 'StoreName'
      SET @AliasName = 'st.'
    END

  Declare @SelectDate datetime
  Declare @FromDate datetime
  Declare @ToDate datetime
  Declare @EndOfMonth datetime
  Declare @StartOfMonth datetime
  Declare @EndDate int
  Declare @WeekCount int
  Declare @DayCount int
  Declare @DayName varchar(10)
  Declare @TempEndOfMonth datetime
  Declare @ComplianceWeeklyDay Varchar(10)
  Declare @ComplianceEndDay Varchar(10)

  Declare @CurrDate varchar(10)
  SET @CurrDate = convert(varchar(10),dateadd(dd,0,getdate()),120)
--SET @CurrDate = '2010-09-01'

  SET @ComplianceWeeklyDay = ''
  SET @ComplianceEndDay = ''
  SELECT @ComplianceWeeklyDay = WeeklyComplianceStartDay From Organization Where OrgId = @pOrgId

  IF @ComplianceWeeklyDay=''
    RETURN 0

  SET @SelectDate = convert(datetime, @pMonth, 101)
  SET @SelectDate = CONVERT(VARCHAR(10), @SelectDate, 101)
  SET @SelectDate = @SelectDate - DAY(@SelectDate) + 1
  SET @StartOfMonth = @SelectDate

  while(1=1)
    begin

      select @DayName = DATENAME(dw, @SelectDate)
      if @DayName = @ComplianceWeeklyDay
        begin
          set @FromDate = @SelectDate
          break;
        end

      else
        begin
          set @SelectDate = DATEADD(day,-1,@SelectDate)
        end

    end

  select @EndOfMonth = dateadd(day,-1,dateadd(month,1,@StartOfMonth))
  select @EndDate = datepart(day,@EndOfMonth)
  set @TempEndOfMonth = @EndOfMonth

  SET @ComplianceEndDay = DATENAME(dw,dateAdd(day,-1,@FromDate))

  while(1=1)
    begin

      select @DayName = DATENAME(dw, @EndOfMonth)
      if @DayName = @ComplianceEndDay
        begin
          set @ToDate = @EndOfMonth
          break;
        end

      else
        begin
          set @EndOfMonth = DATEADD(day,-1,@EndOfMonth)
        end

    end

  declare @Week1 varchar(100)
  declare @Week2 varchar(100)
  declare @Week3 varchar(100)
  declare @Week4 varchar(100)
  declare @Week5 varchar(100)

  declare @BiWeek1 varchar(100)
  declare @BiWeek2 varchar(100)
  declare @Month1 varchar(100)

  set @Week1 = ''''+ convert(varchar(10),@FromDate,120)+ ''' and ''' +convert(varchar(10),DATEADD(day,6,@FromDate),120)+''''
  set @Week2 = ''''+ convert(varchar(10),DATEADD(day,7,@FromDate),120)+ ''' and ''' +convert(varchar(10),DATEADD(day,13,@FromDate),120)+''''
  set @Week3 = ''''+ convert(varchar(10),DATEADD(day,14,@FromDate),120)+ ''' and ''' +convert(varchar(10),DATEADD(day,20,@FromDate),120)+''''
  set @Week4 = ''''+ convert(varchar(10),DATEADD(day,21,@FromDate),120)+ ''' and ''' +convert(varchar(10),DATEADD(day,27,@FromDate),120)+''''
  set @Week5 = ''''+ case when  @ToDate > DATEADD(day,28,@FromDate)
  then convert(varchar(10),DATEADD(day,28,@FromDate),120)+ ''' and ''' +convert(varchar(10),@ToDate,120)
                     else '1900-01-01'' and ''1900-01-01'
                     end+''''
  set @BiWeek1 = ''''+ convert(varchar(10),@StartOfMonth,120)+''' and '''+convert(varchar(10),DATEADD(day,14,@StartOfMonth),120)+''''
  set @BiWeek2 = ''''+ convert(varchar(10),DATEADD(day,15,@StartOfMonth),120)+''' and '''+convert(varchar(10),@TempEndOfMonth,120)+''''
  set @Month1 = ''''+ convert(varchar(10),@StartOfMonth,120)+''' and '''+convert(varchar(10),@TempEndOfMonth,120)+''''

--	SELECT
--			@FromDate AS [From Date],
--			@ToDate AS [To Date],
--			@Week1 AS [Week 1],
--			@Week2 AS [Week 2],
--			@Week3 AS [Week 3],
--			@Week4 AS [Week 4],
--			@Week5 AS [Week 5],
--			@BiWeek1 AS [BiWeek 1],
--			@BiWeek2 AS [BiWeek 1],
--			@Month1 AS [Monthly]

	-- Main query
  SET @SQL = '

	SELECT hf.* into #StoreUserMappingTemp
		FROM dbo.Hierarchy_Function('+@pOrgId+','+@pUserId+') hf
--			INNER JOIN Store st on st.StoreId = hf.StoreId
--			INNER JOIN Account ac on ac.AccountId = st.AccountId
--		WHERE hf.StoreId IS NOT NULL
--			AND ac.StoreVisitRule>0


			SELECT '+ @ResultId + ', '+ @ResultName + ', StoreVisitsCategory
			  INTO #StoresList
			  FROM (SELECT '+ @AliasName+@ResultId + ', '+ @AliasName+@ResultName + ',
				   Store.StoreVisitsCategory + '' (''+ltrim(str(Store.StoreVisitRule))+'')'' AS StoreVisitsCategory
				   FROM '+@AdditionalTable+'
				   vwComplianceStore AS st INNER JOIN
						 #StoreUserMappingTemp AS hf ON
						hf.StoreId = st.StoreId
						INNER JOIN Store on st.StoreId = Store.StoreId
				where 1=1 '+@whereCondition + '
				AND st.StoreId IN (
							SELECT  StoreUserMapping.StoreId
							FROM    StoreUserMapping INNER JOIN
									Users ON StoreUserMapping.UserId = Users.UserId
					)
		) AS svc
			GROUP BY '+ @ResultId + ', '+ @ResultName + ', StoreVisitsCategory

		-- Visits

			SELECT '+ @AliasName+@ResultId + '
			, fm.StoreVisitsCategory
			, period
			, SUM(fm.VisitCount) AS VisitCount
			INTO #VisitsList
			FROM '+@AdditionalTable+'
				#StoreUserMappingTemp AS hf LEFT OUTER JOIN
				vwComplianceStore AS st on hf.StoreId = st.StoreId LEFT OUTER JOIN
					   --(SELECT fv.StoreId, CreatedOn
						('
  IF CONVERT(VARCHAR(10),DATEADD(dd,-(DAY(getdate())-1),getdate()),120)=@pMonth
    BEGIN
      SET @SQL = @SQL + '
					    SELECT fv.StoreId
								, st.StoreVisitsCategory + '' (''+ltrim(str(st.StoreVisitRule))+'')'' AS StoreVisitsCategory
								, case st.StoreVisitsCategory
									when ''Weekly'' then
										case
											when cast(convert(varchar(10),fv.CreatedOn,120) as datetime) between '+@Week1+' then ''Week1''
											when cast(convert(varchar(10),fv.CreatedOn,120) as datetime) between '+@Week2+' then ''Week2''
											when cast(convert(varchar(10),fv.CreatedOn,120) as datetime) between '+@Week3+' then ''Week3''
											when cast(convert(varchar(10),fv.CreatedOn,120) as datetime) between '+@Week4+' then ''Week4''
											when cast(convert(varchar(10),fv.CreatedOn,120) as datetime) between '+@Week5+' then ''Week5''
										end
									when ''BiWeekly'' then
										case
											when cast(convert(varchar(10),fv.CreatedOn,120) as datetime) between '+@BiWeek1+' then ''BiWeek1''
											when cast(convert(varchar(10),fv.CreatedOn,120) as datetime) between '+@BiWeek2+' then ''BiWeek2''
										end
									else ''Monthly''
								end AS period
								, 1 AS VisitCount
						  FROM FormVisit fv, #StoreUserMappingTemp AS hf, Store st, Forms f
						 WHERE (
								   (st.StoreVisitsCategory = ''Weekly''
										and (cast(convert(varchar(10),fv.CreatedOn,120) as datetime)
												BETWEEN cast('''+convert(varchar(10),@FromDate,120)+''' as datetime)
														AND cast('''+convert(varchar(10),@ToDate,120)+''' as datetime)
											)
									)
								OR
								   (st.StoreVisitsCategory = ''BiWeekly''
										and (cast(convert(varchar(10),fv.CreatedOn,120) as datetime)
												BETWEEN cast('''+convert(varchar(10),@StartOfMonth,120)+''' as datetime)
														AND cast('''+convert(varchar(10),@TempEndOfMonth,120)+''' as datetime)
											)
									)
								OR
								   (st.StoreVisitsCategory = ''Monthly''
										and (cast(convert(varchar(10),fv.CreatedOn,120) as datetime)
												BETWEEN cast('''+convert(varchar(10),@StartOfMonth,120)+''' as datetime)
														AND cast('''+convert(varchar(10),@TempEndOfMonth,120)+''' as datetime)
											)
									)
							) AND f.FormId=fv.FormId AND f.isApplyToCompliance=1
						 --WHERE (cast(convert(varchar(10),fv.CreatedOn,120) as datetime) BETWEEN cast('''+convert(varchar(10),@FromDate,120)+''' as datetime)
						--   AND cast('''+convert(varchar(10),@ToDate,120)+''' as datetime))
						   AND fv.StoreId = hf.StoreId
						   AND fv.StoreId = st.StoreId '
    END
  ELSE
    BEGIN
      SET @SQL = @SQL + '
					    SELECT fv.StoreId
								, fv.StoreVisitsCategory + '' (''+ltrim(str(fv.StoreVisitRule))+'')'' AS StoreVisitsCategory
								, case fv.StoreVisitsCategory
									when ''Weekly'' then
										case
											when cast(convert(varchar(10),fv.Date,120) as datetime) between '+@Week1+' then ''Week1''
											when cast(convert(varchar(10),fv.Date,120) as datetime) between '+@Week2+' then ''Week2''
											when cast(convert(varchar(10),fv.Date,120) as datetime) between '+@Week3+' then ''Week3''
											when cast(convert(varchar(10),fv.Date,120) as datetime) between '+@Week4+' then ''Week4''
											when cast(convert(varchar(10),fv.Date,120) as datetime) between '+@Week5+' then ''Week5''
										end
									when ''BiWeekly'' then
										case
											when cast(convert(varchar(10),fv.Date,120) as datetime) between '+@BiWeek1+' then ''BiWeek1''
											when cast(convert(varchar(10),fv.Date,120) as datetime) between '+@BiWeek2+' then ''BiWeek2''
										end
									else ''Monthly''
								end AS period
								, StoreVisitTotal VisitCount
						 FROM ComplianceHistory fv, #StoreUserMappingTemp AS hf
						 WHERE (cast(convert(varchar(10),fv.Date,120) as datetime) BETWEEN cast('''+convert(varchar(10),@StartOfMonth,120)+''' as datetime)
						    AND cast('''+convert(varchar(10),@TempEndOfMonth,120)+''' as datetime))
						   AND fv.StoreId = hf.StoreId '
    END

  SET @SQL = @SQL + '
						) AS fm ON st.StoreId = fm.StoreId
			WHERE 1=1
			  '+@whereCondition + '
			GROUP BY '+ @AliasName+@ResultId + ', fm.StoreVisitsCategory, period
	-- End of Visits

	-- Main SQL
	select pvt.ResultId, pvt.ResultName '

  SET @SQL = @SQL + ', pvt.StoreVisitsCategory AS Frequency, Week1, Week2, Week3, Week4, Week5, BiWeek1, BiWeek2, Monthly
	into #temp1
	from
	(
		select Stores.'+ @ResultId + ' AS ResultId, Stores.'+ @ResultName + ' as ResultName
		, coalesce(visits.StoreVisitsCategory, Stores.StoreVisitsCategory) as StoreVisitsCategory
		, period
		, VisitCount as avgVisit
		 from #StoresList as Stores LEFT OUTER JOIN #VisitsList as visits
		 ON Stores.'+ @ResultId + '=visits.'+ @ResultId + '
		) P
		PIVOT
		(
			sum(avgVisit)
			for period in (Week1, Week2, Week3, Week4, Week5, BiWeek1, BiWeek2, Monthly)

		) as PVT
		order by PVT.ResultName
		'

-- Store nick name check and update
  IF (@ResultName='StoreName')
    BEGIN
      SET @NickNameSQL = '
			-- Store nick name check and update

			SELECT * INTO #StoreListForNickName from StoreListForNickNameChange('+@pOrgId+','+@pUserId+')

			BEGIN
			UPDATE #temp1 SET
				ResultName=isnull(
						CASE
							WHEN LTRIM(RTRIM(CertifiedStoreNickName))='''' THEN ST.StoreName
							WHEN CertifiedStoreNickName is null THEN ST.StoreName
							ELSE CertifiedStoreNickName
						END, ResultName)
			FROM
			  Store ST
			  JOIN #temp1 ON #temp1.ResultId=ST.StoreId
			WHERE
			  ST.StoreName in (SELECT StoreName FROM #StoreListForNickName)
			  AND ST.OrgId = '+@pOrgId+'
			  AND ST.IsActive=1
			  /** Requirement changes - compliance on/off */
			  AND ST.IsCompliance = 1
			END '
    END

  declare @avgSQL varchar(max)

  SET @avgSQL = '
		select '''+dateName(month,convert(datetime, @pMonth, 101))+' '+left(@pMonth, 4)+''' AS MonthYear
			--, substring(StoreName,0,charindex(''('',StoreName)) AccountName, ResultId as StoreId, ResultName StoreName
			, Account.AccountName, ResultId as StoreId, ResultName StoreName, ''1'' AS StoreCount
			, Frequency '

  IF CONVERT(VARCHAR(10),DATEADD(dd,-(DAY(getdate())-1),getdate()),120)=@pMonth
    BEGIN
      SET @avgSQL = @avgSQL + '
		    , convert(varchar(6),convert(int,case left(Frequency,6) when ''Weekly'' then
				case when ''' +convert(varchar(10),DATEADD(day,6,@FromDate),120) + ''' < ''' + @CurrDate + '''
						 then isnull(Week1,0) else Week1 end else Week1 end)) as Week1
		    , convert(varchar(6),convert(int,case left(Frequency,6) when ''Weekly'' then
				case when ''' +convert(varchar(10),DATEADD(day,13,@FromDate),120) + ''' < ''' + @CurrDate + '''
						 then isnull(Week2,0) else Week2 end else Week2 end)) as Week2
		    , convert(varchar(6),convert(int,case left(Frequency,6) when ''Weekly'' then
				case when ''' +convert(varchar(10),DATEADD(day,20,@FromDate),120) + ''' < ''' + @CurrDate + '''
						 then isnull(Week3,0) else Week3 end else Week3 end)) as Week3
		    , convert(varchar(6),convert(int,case left(Frequency,6) when ''Weekly'' then
				case when ''' +convert(varchar(10),DATEADD(day,27,@FromDate),120) + ''' < ''' + @CurrDate + '''
						 then isnull(Week4,0) else Week4 end else Week4 end)) as Week4
		    , convert(varchar(6),convert(int,Week5)) as Week5
		    , convert(varchar(6),convert(int,case left(Frequency,8) when ''BiWeekly'' then
				case when ''' +convert(varchar(10),DATEADD(day,14,@StartOfMonth),120) + ''' < ''' + @CurrDate + '''
						 then isnull(BiWeek1,0) else BiWeek1 end else BiWeek1 end)) as BiWeek1
		    , convert(varchar(6),convert(int,case left(Frequency,8) when ''BiWeekly'' then
				case when ''' +convert(varchar(10),@TempEndOfMonth,120) + ''' < ''' + @CurrDate + '''
						 then isnull(BiWeek2,0) else BiWeek2 end else BiWeek2 end)) as BiWeek2
		    --, convert(varchar(6),convert(int,BiWeek2)) as BiWeek2
		    , convert(varchar(6),convert(int,case left(Frequency,7) when ''Monthly'' then
				case when ''' +convert(varchar(10),@TempEndOfMonth,120) + ''' < ''' + @CurrDate + '''
						 then isnull(Monthly,0) else Monthly end else Monthly end)) as Monthly
		    --, convert(varchar(6),convert(int,Monthly)) as Monthly
			, convert(varchar(6),convert(decimal(6,2),round(ch.Compliance,2))) as Compliance '
    END
  ELSE
    BEGIN
      SET @avgSQL = @avgSQL + '
		    , convert(varchar(6),convert(int,Week1)) as Week1
		    , convert(varchar(6),convert(int,Week2)) as Week2
		    , convert(varchar(6),convert(int,Week3)) as Week3
		    , convert(varchar(6),convert(int,Week4)) as Week4
		    , convert(varchar(6),convert(int,Week5)) as Week5
		    , convert(varchar(6),convert(int,BiWeek1)) as BiWeek1
		    , convert(varchar(6),convert(int,BiWeek2)) as BiWeek2
		    , convert(varchar(6),convert(int,Monthly)) as Monthly
			, convert(varchar(6),convert(decimal(6,2),round(ch.Compliance,2))) as Compliance '
    END
  SET @avgSQL = @avgSQL + '
		from #temp1
			inner join Store on #temp1.ResultId=Store.StoreId
			inner join Account on Store.AccountId=Account.AccountId
			left outer join
				( select StoreId, Compliance from ComplianceHistory
					Where ComplianceHistory.date
							between cast('''+convert(varchar(10),@pMonth,120)+''' as datetime)
							and dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,cast('''+convert(varchar(10),@pMonth,120)+''' as datetime))), 0))
						  and ComplianceHistory.RecentForMonth=1
						  and StoreId in (select ResultId from #Temp1) -- order by 1,2
				)ch on #temp1.ResultId = ch.StoreId
		order by MonthYear, AccountName, StoreName, Frequency
	'

  SET @SQL=@SQL+@NickNameSQL+' '+@avgSQL

--print @SQL

  EXEC (@SQL)

END

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'ComplianceReport_ByStore_Summary' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[ComplianceReport_ByStore_Summary]')
	END
GO
/****** Object:  StoredProcedure [dbo].[ComplianceReport_ByStore_Summary]    Script Date: 3/2/2015 6:36:22 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[ComplianceReport_ByStore_Summary] (
  @MonthYearList	VARCHAR(1000)='',
  @pInitialName   VARCHAR(50),
  @pOrgId			VARCHAR(50),
  @pUserId		VARCHAR(50),
  @pAccountName	VARCHAR(100)='',
  @pRegion		VARCHAR(100)='',
  @pCluster		VARCHAR(100)='',
  @pMarketGroup	VARCHAR(100)='',
  @pRepID			VARCHAR(100)=''
)

AS
SET NOCOUNT ON
BEGIN

-- Declare
  DECLARE @CUIDColumnName varchar(40)
  DECLARE @SQL varchar(max)
  DECLARE @strColNames varchar(max)
  DECLARE @whereCondition varchar(max)
  DECLARE @ResultNameParam varchar(200)
  DECLARE @pRoleLevelNum int
  DECLARE @ResultShortName varchar(50)
  DECLARE @ResultShortNameWhereAndGroup varchar(200)
  DECLARE @ResultColumn1 varchar(max)
  DECLARE @ResultColumn2 varchar(max)
  DECLARE @NickNameSQL varchar(2000)

-- Set
  SET ARITHABORT OFF
  SET ANSI_WARNINGS OFF

  SET @ResultColumn1=''
  SET @CUIDColumnName=''
  SET @whereCondition=''
  SET @ResultShortNameWhereAndGroup=''
  SET @NickNameSQL = ''

  SET @ResultColumn1 = 'StoreId'
  SET @ResultColumn2 = 'StoreName'

  IF @pAccountName in ('ALL','SELECT')
    SET @pAccountName=''

  IF @pRegion in ('ALL','SELECT')
    SET @pRegion=''

  IF @pCluster in ('ALL','SELECT')
    SET @pCluster=''

  IF @pMarketGroup in ('ALL','SELECT')
    SET @pMarketGroup=''

  IF @pRepID in ('ALL','SELECT')
    SET @pRepID=''

-- Define filters
  IF @pAccountName!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.AccountName='''+@pAccountName+''''
    END
  IF @pRegion!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.DivisionName='''+@pRegion+''''
    END

  IF @pRegion!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.DivisionName='''+@pRegion+''''
    END

  IF @pCluster!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.MarketClusterName='''+@pCluster+''''
    END

  IF @pMarketGroup!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.RegionName='''+@pMarketGroup+''''
    END
  IF @pRepID!=''
    BEGIN
      SET @whereCondition	= @whereCondition+'
			and st.FullName='''+@pRepID+''''
    END

/** Get the Date condition */
  DECLARE	@return_value int,
  @DateWhereCondtion varchar(max),
  @MonthCount int, @DateSelection VARCHAR(500)

  EXEC	@return_value = [dbo].[DateCondition_Supporter]
  @pMonthYear = @MonthYearList,
  @DateWhereCondtion = @DateWhereCondtion OUTPUT,
  @MonthCount = @MonthCount OUTPUT,
  @DateSelection = @DateSelection OUTPUT
  print '@MonthCount-->'+str(@MonthCount)


-- Define column names
  DECLARE @i int
  DECLARE @prefix varchar
  SET @strColNames=''
  SET @i=0
  While @i<@MonthCount
    BEGIN
      SET @prefix=''
      IF @i < 10
        SET @prefix=''
      SET @strColNames = @strColNames+'
			, [M'+convert(varchar(2),@i)+'] as [M'+@prefix+convert(varchar(2),@i)+']'
      SET @i=@i+1
    END

-- Main query
  SET @SQL = '

	SELECT * into #StoreUserMappingTemp from dbo.Hierarchy_Function('+@pOrgId+','+@pUserId+')

	CREATE TABLE #MonthAndNumber
		(
			  MonthYear varchar(15)
			, NumberIdentity [int] IDENTITY(1,1) NOT NULL
			, Number as ltrim(rtrim(str(NumberIdentity-1)))
		)
	INSERT INTO #MonthAndNumber (MonthYear)
	SELECT ltrim(rtrim(OutputValue)) As MonthYear FROM dbo.Spliter('''+@MonthYearList+', '','','')

	select pvt.ResultColumn1, ResultColumn2, ''1'' AS StoreCount '

  SET @SQL = @SQL + @strColNames +'
	into #temp1
	from
	(
		select st.'+ @ResultColumn1 + ' as ResultColumn1 , st.'+ @ResultColumn2 + ' as ResultColumn2,
		''M''+#MonthAndNumber.Number as months,
		AVG(compliance*1.00) as compliance
		from ComplianceHistory ch, vwStoreWithNames st,#MonthAndNumber
		where --[date]
				--between dateadd(m, datediff(m, 0, dateadd(mm,'+convert(varchar(3),@MonthCount*(-1))+',getdate())), 0)
				--and dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))
				'+@DateWhereCondtion+'
				and ch.StoreId = st.StoreId AND ch.RecentForMonth=1
				and ch.StoreId in
						(
							SELECT  StoreUserMapping.StoreId
							FROM    StoreUserMapping INNER JOIN
									Users ON StoreUserMapping.UserId = Users.UserId
							WHERE   (StoreUserMapping.StoreId is not null)
						)
				-- and st.isOnBoarding=1
				and ch.StoreId in (select StoreId from #StoreUserMappingTemp)
			    and dateName(mm,ch.date)+'' ''+dateName(year,ch.date)=#MonthAndNumber.MonthYear
'

  SET @SQL = @SQL + @whereCondition

  SET @SQL = @SQL + '
			GROUP BY st.'+@ResultColumn1+', st.'+ @ResultColumn2 +', ''M''+#MonthAndNumber.Number
		) P
		PIVOT
		(
			sum(compliance)
			for months in '

  SET @strColNames=''
  SET @i=0
  SET @prefix=''
  While @i<@MonthCount
    BEGIN
      IF @i != 0
        SET @prefix=',
				'
      SET @strColNames = @strColNames+@prefix+' [M'+convert(varchar(2),@i)+']'
      SET @i=@i+1
    END

  SET @SQL = @SQL + '('+@strColNames +')

		) as PVT
		order by PVT.ResultColumn1 '

  print @SQL
-- Final output from main query

  SET @strColNames=''
  SET @i=0
  While @i<@MonthCount
    BEGIN
      SET @prefix=''
      IF @i < 10
        SET @prefix=''
      SET @strColNames = @strColNames+',
			 isnull(convert(varchar(6),convert(decimal(6,2),round(M'+@prefix+convert(varchar(2),@i)+',2))),NULL) as M'+@prefix+convert(varchar(2),@i)+''
      SET @i=@i+1
    END

-- Store nick name check and update
  IF (@ResultColumn2='StoreName')
    BEGIN
      SET @NickNameSQL = @NickNameSQL + '

			-- Store nick name check and update

			SELECT * INTO #StoreListForNickName from StoreListForNickNameChange('+@pOrgId+','+@pUserId+')

			BEGIN
			UPDATE #temp1 SET
				ResultColumn2= isnull(
						CASE
							WHEN LTRIM(RTRIM(CertifiedStoreNickName))='''' THEN ST.StoreName
							WHEN CertifiedStoreNickName is null THEN ST.StoreName
							ELSE CertifiedStoreNickName
						END, ResultColumn2)
			FROM
			  Store ST
			  JOIN #temp1 ON #temp1.ResultColumn1=ST.StoreId
			WHERE
			  ST.StoreName in (SELECT StoreName FROM #StoreListForNickName)
			  AND ST.OrgId = '+@pOrgId+'
			END '
    END

  DECLARE @resultSQL AS VARCHAR(MAX)
  SET @resultSQL = '

	-- Get average and list
	IF (select count(1) from #temp1) > 0
	BEGIN
		select '

  SET @resultSQL=@resultSQL+ 'Account.AccountName AS ResultColumn1, ResultColumn2, ''1'' AS StoreCount '+@strColNames+'
			from #temp1
			inner join Store on #temp1.ResultColumn1=Store.StoreId
			inner join Account on Store.AccountId=Account.AccountId
			order by Account.AccountName, ResultColumn2
	END
	ELSE
	BEGIN
		select * from #temp1
	END
	'

  SET @SQL=@SQL+@NickNameSQL+@resultSQL

  PRINT @SQL

  EXEC (@SQL)

END


GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'ComplianceReport_Gps' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[ComplianceReport_Gps]')
	END
GO
/****** Object:  StoredProcedure [dbo].[ComplianceReport_Gps]    Script Date: 3/2/2015 6:36:23 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- EXEC [ComplianceReport_GPS] '3', 1, '10','Team', 'Test Account','Test Region','Test Market', 'User, Iss(testrae)'    
-- EXEC [ComplianceReport_GPS] '7', 'May 2012', '4531','Team', 'all','ALL','ALL', 'ALL','sandbox'    
    
-- EXEC [ComplianceReport_GPS] '3', 1, '10','Team', 'Test Account','Test Region','Test Market', 'User, Iss(testrae)'    
-- EXEC [ComplianceReport_GPS] '7', 'May 2012', '4531','Team', 'All','ALL','ALL', 'ALL','all' 
---EXEC [ComplianceReport_GPS] '7', 'November 2012,October 2012,September 2012,August 2012','1','Team','Store_Division','All','All','All' ,'all'  
    
CREATE PROCEDURE [dbo].[ComplianceReport_Gps]     
 @P_OrgId  VARCHAR(20),    
 @MonthYearList VARCHAR(1000)='',    
 @pUserName  VARCHAR(50),    
 @pUserType  VARCHAR(50)='Team',    
 @pAccountName VARCHAR(100)='',    
 @pRegion  VARCHAR(100)='',    
 @pMarketGroup VARCHAR(100)='',    
 @pRepID   VARCHAR(50)='',    
 @pClusterGroup   VARCHAR(50) = ''    
AS    
SET NOCOUNT ON
BEGIN    
    
 -- Declare    
 DECLARE @CUIDColumnName varchar(40)    
 DECLARE @SQL varchar(max)    
 DECLARE @strColNames varchar(max)    
 DECLARE @whereCondition varchar(max)    
 DECLARE @ResultName varchar(max)    
 DECLARE @pRoleLevelNum int    
 DECLARE @ResultShortName varchar(50)    
 DECLARE @ResultShortNameWhereAndGroup varchar(200)    
 DECLARE @Result1 varchar(50)    
 DECLARE @Result2 varchar(1000)    
 DECLARE @ResultFlag varchar(50)    
 DECLARE @GPS_FormsTblName varchar(50)    
 DECLARE @whereConditionForms varchar(max)    
 DECLARE @NickNameSQL varchar(1000)    
    
 DECLARE @IsCompliance bit    
 SET @IsCompliance = 1    
 SELECT @IsCompliance = IsCompliance From Organization Where OrgId = @P_OrgId    
 IF @IsCompliance = 0    
  SET @pUserName='0'    
     
 -- Set     
 SET ARITHABORT OFF    
 SET ANSI_WARNINGS OFF    
    
 --SET @MonthCount=3    
 SET @ResultName=''    
 SET @CUIDColumnName=''    
 SET @whereCondition=''    
 SET @ResultShortNameWhereAndGroup=''    
 SET @GPS_FormsTblName=''--, @GPS_Forms g'    
 SET @whereConditionForms=''    
 SET @ResultFlag ='0'    
 SET @NickNameSQL = ''    
    
 SET @ResultName='AccountName'    
    
 IF @pAccountName!='' and @pAccountName!='All' and @pAccountName!='Select'    
 BEGIN    
  SET @whereCondition = @whereCondition+'    
    and st.AccountName='''+@pAccountName+'''and st.MarketClusterName!=''SandBox'''    
  SET @ResultName = 'us.FullName+''(''+us.UserName+'')|''+st.StoreName'    
  SET @ResultFlag ='1'    
 END    
    
 IF @pAccountName!='' and @pAccountName='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion!='Select'     
   and @pMarketGroup!='All' and @pMarketGroup!='Select'    
 BEGIN 
 SET @whereCondition = @whereCondition+'    
     and st.RegionName='''+@pMarketGroup+'''and st.MarketClusterName!=''SandBox'''    
  SET @ResultName = 'us.FullName+''(''+us.UserName+'')|''+st.StoreName'    
  SET @ResultFlag ='1'    
  print 'ddddd'    
 END    
    
 IF @pAccountName='All' and @pRegion='Select' and @pMarketGroup='Select' and  @pRepID='Select'    
 BEGIN    
  print '2'    
  SET @ResultFlag ='2'    
 END    
    
 ELSE IF @pAccountName!='Select' and @pAccountName!='All' and @pRegion='Select' and @pMarketGroup='Select' and  @pRepID='Select'    
 BEGIN    
  print '3'    
  SET @ResultFlag ='3'    
 END    
    
 ELSE IF @pAccountName!='All' and @pRegion!='Select' and @pMarketGroup='Select' and  @pRepID='Select'    
 BEGIN    
  print '4'    
  SET @ResultFlag ='4'    
 END    
    
 ELSE IF @pAccountName!='All' and @pRegion!='Select' and @pMarketGroup!='Select' and  @pRepID='Select'    
 BEGIN    
  print '5'    
  SET @ResultFlag ='5'    
 END    
 ELSE IF @pAccountName!='Select' and @pAccountName='All' and @pRegion!='All' and @pRegion!='Select'     
   and @pMarketGroup!='All' and @pMarketGroup!='Select' and  @pRepID!='All' and  @pRepID!='Select'     
 BEGIN    
  print '6'    
  SET @ResultFlag ='6'    
 END    
    
 ELSE IF @pAccountName!='Select' and @pAccountName!='All' and @pRegion!='All' and @pRegion!='Select'     
   and @pMarketGroup!='All' and @pMarketGroup!='Select' and  @pRepID!='All' and  @pRepID!='Select'     
 BEGIN    
  print '7'    
  SET @ResultFlag ='7'    
 END    
    
print @ResultFlag    
 -- Define filters    
    
 IF @pRegion!='' and @pRegion!='All' and @pRegion!='Select'    
 BEGIN    
  SET @whereCondition = @whereCondition+'    
   and st.DivisionName='''+@pRegion+'''and st.MarketClusterName!=''SandBox'''    
  SET @ResultName = 'DivisionName'    
 END    
    
 IF @pMarketGroup!=''  and @pMarketGroup!='All' and @pMarketGroup!='Select'    
 BEGIN    
  SET @whereCondition = @whereCondition+'    
    and st.RegionName='''+@pMarketGroup+'''and st.MarketClusterName!=''SandBox'''    
  SET @ResultName = 'RegionName'    
 END    
    
    ELSE IF @pClusterGroup!='All' and @pClusterGroup!='Select'     
  BEGIN    
   SET @whereCondition = @whereCondition+'    
    and st.MarketClusterName='''+@pClusterGroup+'''and st.DivisionName!=''SandBox'''      
  END    
    
 IF @pRepID!=''    
 BEGIN    
  IF @pRepID!='All' and  @pRepID!='Select'    
   BEGIN    
    SET @whereCondition = @whereCondition+'    
     and us.FullName+''(''+us.UserName+'')''='''+@pRepID+'''    
     --and us.FullName+''(''+us.UserName+'')''=g.RAE'    
    SET @ResultName = 'us.FullName+''(''+us.UserName+'')|''+st.AccountName'    
   END    
  ELSE     
    IF @ResultFlag='1'    
     BEGIN    
      print 'IF COND '+@ResultFlag    
      SET @ResultName = 'us.FullName+''(''+us.UserName+'')|''+st.StoreName'    
     END    
    IF @ResultFlag!='1'    
     BEGIN    
      print 'eLS COND '+@ResultFlag    
      SET  @ResultName = 'us.FullName+''(''+us.UserName+'')|''+st.AccountName'    
     END    
        
    IF @ResultFlag='2'    
     BEGIN    
      print 'Test '+@ResultFlag    
      SET @ResultName = 'st.AccountName+''|0'''    
     END    
    IF @ResultFlag='3'    
     BEGIN    
      print 'Test '+@ResultFlag    
      SET @ResultName = 'st.DivisionName+''|0'''    
     END    
    IF @ResultFlag='4'    
     BEGIN    
      print 'Test '+@ResultFlag    
      SET @ResultName = 'st.RegionName+''|0'''    
     END    
    IF @ResultFlag='5'    
     BEGIN    
      print 'Test '+@ResultFlag    
      SET @ResultName = 'st.StoreName+''|0'''    
     END    
    IF @ResultFlag='6'    
     BEGIN    
      print 'Test '+@ResultFlag    
      SET @ResultName = 'st.AccountName+''|''+st.StoreName'    
     END    
    IF @ResultFlag='7'    
     BEGIN    
      print 'Test '+@ResultFlag    
      SET @ResultName = 'st.StoreName+''|''+st.StoreName'    
     END    
    
      
 END    
    
 IF @pRegion!='' and @pMarketGroup=''    
 BEGIN    
  SET @ResultShortNameWhereAndGroup = '    
   group by ResultName     
   order by [Order], ResultName'    
 END    
    
 /** Get the Date condition */    
 DECLARE @return_value int,    
 @DateWhereCondtion varchar(max),    
 @MonthCount int, @DateSelection VARCHAR(500)    
    
     
 EXEC @return_value = [dbo].[DateCondition_Supporter]    
 @pMonthYear = @MonthYearList,    
 @DateWhereCondtion = @DateWhereCondtion OUTPUT,     
 @MonthCount = @MonthCount OUTPUT,     
 @DateSelection = @DateSelection OUTPUT     
 --print '@MonthCount-->'+str(@MonthCount)    
    
-- Define column names    
 DECLARE @i int    
 DECLARE @prefix varchar    
 SET @strColNames=''    
 SET @i=0    
 While @i<@MonthCount    
 BEGIN    
  SET @prefix=''    
  IF @i < 10    
   SET @prefix=''    
  SET @strColNames = @strColNames+'    
   , [FG'+convert(varchar(2),@i)+'] as [FG'+@prefix+convert(varchar(2),@i)+']    
   , [G'+convert(varchar(2),@i)+'] as [G'+@prefix+convert(varchar(2),@i)+']    
   , [FN'+convert(varchar(2),@i)+'] as [FN'+@prefix+convert(varchar(2),@i)+']    
   , [N'+convert(varchar(2),@i)+'] as [N'+@prefix+convert(varchar(2),@i)+']'    
 SET @i=@i+1    
 END    
    
 -- Main query    
 SET @SQL = '    
    
 SELECT * into #StoreUserMappingTemp from dbo.Hierarchy_Function('+@P_OrgId+','+@pUserName+') '    
 IF @pUserType = 'Individual'    
 BEGIN    
  SET @SQL = @SQL + 'Where UserId='+@pUserName    
 END    
    
 SET @SQL = @SQL +'    
    
 CREATE TABLE #MonthAndNumber     
  (    
     MonthYear varchar(15)    
   , NumberIdentity [int] IDENTITY(1,1) NOT NULL    
   , Number as ltrim(rtrim(str(NumberIdentity-1)))    
  )    
 INSERT INTO #MonthAndNumber (MonthYear)    
 SELECT ltrim(rtrim(OutputValue)) As MonthYear FROM dbo.Spliter('''+@MonthYearList+', '','','')    
    
    
 DECLARE @GPS_StatusReport TABLE (    
 StoreId int,    
 Date datetime,    
 GPS_NoStoreVisitFlag int,    
 Non_GPS_TotalVisitFlag int    
 )    
    
 INSERT INTO @GPS_StatusReport (StoreId, Date, GPS_NoStoreVisitFlag, Non_GPS_TotalVisitFlag)    
 SELECT fv.StoreId, fv.CreatedOn, CASE fv.GpsInsideGeofence WHEN ''Yes'' THEN count(fv.GpsInsideGeofence) END as GPS_NoStoreVisitFlag,    
   CASE fv.GpsInsideGeofence WHEN ''No'' THEN count(fv.GpsInsideGeofence) END as Non_GPS_TotalVisitFlag 
   from FormVisit fv
   INNER JOIN Forms f ON f.FormId=fv.FormId AND f.isApplyToCompliance=1
   where fv.StoreId > 0    
 Group by fv.StoreId,fv.CreatedOn,fv.GpsInsideGeofence    
    
 select pvt.ResultName '    
    
 SET @SQL = @SQL + @strColNames +'    
     
 into #Temp1    
 from    
 (    
  select '+ @ResultName + ' as ResultName,     
  ''FG''+#MonthAndNumber.Number as months,     
  nullIf(sum(GPS_NoStoreVisitFlag),0) as compliance    
  from @GPS_StatusReport ch, vwComplianceStore st, Users us, StoreUserMapping stm, #MonthAndNumber    
  where --[Date]    
    --between dateadd(m, datediff(m, 0, dateadd(mm,'+convert(varchar(3),@MonthCount*(-1))+',getdate())), 0)     
    --and dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))    
    '+@DateWhereCondtion+'    
    and stm.Storeid=ch.StoreId    
    and stm.UserId=us.UserId    
    and ch.StoreId = st.StoreId --and st.mgrlevel1cuid !=''Unassigned''    
    and ch.StoreId in (select StoreId from #StoreUserMappingTemp)     
       and dateName(mm,ch.date)+'' ''+dateName(year,ch.date)=#MonthAndNumber.MonthYear '    
  SET @SQL = @SQL + @whereCondition    
  SET @SQL = @SQL + '    
   GROUP BY '+@ResultName+', ''FG''+#MonthAndNumber.Number    
  union    
  select '+ @ResultName + ' as ResultName,     
  ''FN''+#MonthAndNumber.Number as months,     
  nullIf(sum(Non_GPS_TotalVisitFlag),0) as compliance    
  from @GPS_StatusReport ch, vwComplianceStore st, Users us, StoreUserMapping stm, #MonthAndNumber    
  where --[Date]    
    --between dateadd(m, datediff(m, 0, dateadd(mm,'+convert(varchar(3),@MonthCount*(-1))+',getdate())), 0)     
    --and dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))    
    '+@DateWhereCondtion+'    
    and stm.Storeid=ch.StoreId    
    and stm.UserId=us.UserId    
    and ch.StoreId = st.StoreId --and st.mgrlevel1cuid !=''Unassigned''    
    and ch.StoreId in (select StoreId from #StoreUserMappingTemp)     
       and dateName(mm,ch.date)+'' ''+dateName(year,ch.date)=#MonthAndNumber.MonthYear'    
  SET @SQL = @SQL + @whereCondition    
  SET @SQL = @SQL + '    
   GROUP BY '+@ResultName+', ''FN''+#MonthAndNumber.Number    
  union    
  select '+ @ResultName + ' as ResultName,     
  ''G''+#MonthAndNumber.Number as months,     
  nullIf((case sum(isnull(GPS_NoStoreVisitFlag,0)+isnull(Non_GPS_TotalVisitFlag,0)) when 0 then 0 else sum(isnull(GPS_NoStoreVisitFlag,0))*100.00/sum(isnull(GPS_NoStoreVisitFlag,0)+isnull(Non_GPS_TotalVisitFlag,0)) end),0.0) as compliance    
  from @GPS_StatusReport ch, vwComplianceStore st, Users us, StoreUserMapping stm, #MonthAndNumber     
  where --[Date]    
    --between dateadd(m, datediff(m, 0, dateadd(mm,'+convert(varchar(3),@MonthCount*(-1))+',getdate())), 0)     
    --and dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))    
    '+@DateWhereCondtion+'    
    and stm.Storeid=ch.StoreId    
    and stm.UserId=us.UserId    
    and ch.StoreId = st.StoreId --and st.mgrlevel1cuid !=''Unassigned''    
    and ch.StoreId in (select StoreId from #StoreUserMappingTemp)     
       and dateName(mm,ch.date)+'' ''+dateName(year,ch.date)=#MonthAndNumber.MonthYear '    
  SET @SQL = @SQL + @whereCondition    
  SET @SQL = @SQL + '    
   GROUP BY '+@ResultName+', ''G''+#MonthAndNumber.Number    
  union    
  select '+ @ResultName + ' as ResultName,     
  ''N''+#MonthAndNumber.Number as months,     
  nullIf((case sum(isnull(GPS_NoStoreVisitFlag,0)+isnull(Non_GPS_TotalVisitFlag,0)) when 0 then 0 else sum(isnull(Non_GPS_TotalVisitFlag,0))*100.00/sum(isnull(GPS_NoStoreVisitFlag,0)+isnull(Non_GPS_TotalVisitFlag,0)) end),0.0) as compliance    
  from @GPS_StatusReport ch, vwComplianceStore st, Users us, StoreUserMapping stm, #MonthAndNumber     
  where --[Date]    
    --between dateadd(m, datediff(m, 0, dateadd(mm,'+convert(varchar(3),@MonthCount*(-1))+',getdate())), 0)     
    --and dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))    
    '+@DateWhereCondtion+'    
    and stm.Storeid=ch.StoreId    
    and stm.UserId=us.UserId    
    and ch.StoreId = st.StoreId --and st.mgrlevel1cuid !=''Unassigned''    
    and ch.StoreId in (select StoreId from #StoreUserMappingTemp)     
       and dateName(mm,ch.date)+'' ''+dateName(year,ch.date)=#MonthAndNumber.MonthYear '    
  SET @SQL = @SQL + @whereCondition    
  SET @SQL = @SQL + '    
   GROUP BY '+@ResultName+', ''N''+#MonthAndNumber.Number    
  ) P    
  PIVOT    
  (    
   sum(compliance)    
   for months in '    
    
  SET @strColNames=''    
  SET @i=0    
  SET @prefix=''    
  While @i<@MonthCount    
  BEGIN    
   IF @i != 0    
    SET @prefix=',    
    '    
   SET @strColNames = @strColNames+@prefix +'  [FG'+convert(varchar(2),@i)+']'    
             +', [G'+convert(varchar(2),@i)+']'    
             +', [FN'+convert(varchar(2),@i)+']'    
             +', [N'+convert(varchar(2),@i)+']'    
  SET @i=@i+1    
  END    
    
  SET @SQL = @SQL + '('+@strColNames +')    
    
  ) as PVT    
  order by PVT.ResultName '    
    
 -- Calculating Overall - Start    
    
 -- Calculating Overall - End    
    
 -- To display columns as Month1, Month2 ... in output     
-- DECLARE @strMonthYear varchar(MAX)    
-- SET @strMonthYear=' '    
-- SET @i=0    
-- While @i<=@MonthCount    
-- BEGIN    
--  SET @prefix=''    
--  SET @strMonthYear = @strMonthYear+    
--   ' '''+DateName(mm,dateadd(mm,-@i,getdate()))+' '+DateName(yyyy,dateadd(mm,-@i,getdate()))+''' as Month'+cast(@i as varchar(2))+', '    
--  SET @i=@i+1    
-- END    
 -- End of Month display    
    
    
    
  -- Store nick name check and update    
  IF (charindex('st.StoreName',@SQL,0)>0)    
  BEGIN    
   SET @NickNameSQL = '    
   -- Store nick name check and update    
    
    
   SELECT * INTO #StoreListForNickName from StoreListForNickNameChange('+@P_OrgId+','+@pUserName+')    
    
   BEGIN    
   UPDATE #temp1 SET    
    ResultName=isnull(replace(ResultName,(RTRIM(LTRIM(RIGHT(#temp1.ResultName,(CHARINDEX(''|'',REVERSE(#temp1.ResultName))-1))))),    
    (CASE     
       WHEN LTRIM(RTRIM(CertifiedStoreNickName))='''' THEN ST.StoreName    
       WHEN CertifiedStoreNickName is null THEN ST.StoreName    
       ELSE CertifiedStoreNickName     
      END)), ResultName)    
   FROM       
     Store ST, #temp1    
   WHERE     
     (RTRIM(LTRIM(RIGHT(#temp1.ResultName,(CHARINDEX(''|'',REVERSE(#temp1.ResultName))-1)))))=ST.StoreName    
      AND ST.StoreName in (SELECT StoreName FROM #StoreListForNickName)    
      AND ST.OrgId = '+@P_OrgId+'    
      AND ST.IsActive=1    
      /** Requirement changes - compliance on/off */    
      AND ST.IsCompliance = 1    
   END '    
  END    
    
 -- Final output from main query    
 DECLARE @avgSQL varchar(MAX)    
 SET @avgSQL = ''    
    
 SET @avgSQL = 'select null, null '    
    
 SET @strColNames=''    
 SET @i=0    
 While @i<@MonthCount    
 BEGIN    
  SET @prefix=''    
  IF @i < 10    
   SET @prefix=''    
  SET @strColNames = @strColNames+',    
    isnull(CONVERT(VARCHAR(6),nullIf(convert(decimal(6,0),round(isnull(sum(FG'+@prefix+convert(varchar(2),@i)+'),0)+isnull(sum(FN'+@prefix+convert(varchar(2),@i)+'),0),2)),0)),NULL) as F'+@prefix+convert(varchar(2),@i)+''    
  SET @strColNames = @strColNames+',    
    isnull(convert(varchar(6),convert(decimal(6,0),round(sum(FG'+@prefix+convert(varchar(2),@i)+'),2))),NULL) as FG'+@prefix+convert(varchar(2),@i)+''    
  SET @strColNames = @strColNames+',    
    isnull(convert(varchar(6),convert(decimal(6,2),round(avg(G'+@prefix+convert(varchar(2),@i)+'),2))),NULL) as G'+@prefix+convert(varchar(2),@i)+''    
  SET @strColNames = @strColNames+',    
    isnull(convert(varchar(6),convert(decimal(6,0),round(sum(FN'+@prefix+convert(varchar(2),@i)+'),2))),NULL) as FN'+@prefix+convert(varchar(2),@i)+''    
  SET @strColNames = @strColNames+',    
    isnull(convert(varchar(6),convert(decimal(6,2),round(avg(N'+@prefix+convert(varchar(2),@i)+'),2))),NULL) as N'+@prefix+convert(varchar(2),@i)+''    
  SET @i=@i+1    
 END    
    
 SET @avgSQL = '    
    
 -- Get average and list    
 BEGIN '    
  SET @avgSQL=@avgSQL+' select '+@DateSelection    
  IF(@pRepID!='')    
   SET @Result2=' RTRIM(LTRIM(LEFT(ResultName,(CHARINDEX(''|'',ResultName)-1)))) as ResultName,    
   RTRIM(LTRIM(RIGHT(ResultName,(CHARINDEX(''|'',REVERSE(ResultName))-1)))) as ResultName1'    
  ELSE    
   SET @Result2=' ResultName '    
    
  SET @avgSQL=@avgSQL+ '''0'' as [Order],  '+@Result2+@strColNames+' from #Temp1'    
    
  IF (@pRegion!='' and @pMarketGroup='')    
   SET @avgSQL=@avgSQL+@ResultShortNameWhereAndGroup    
  ELSE    
   SET @avgSQL=@avgSQL+ '     
   group by ResultName     
   order by [Order], ResultName,ResultName1'    
  SET @avgSQL=@avgSQL+'    
 END    
 '    
    
-- print @SQL    
-- print @NickNameSQL    
-- print @strOverallColNames    
-- print @avgSQL    
    
 SET @SQL=@SQL+@NickNameSQL+@avgSQL    
 print @SQL    
    
 EXEC (@SQL)    
    
 SET ARITHABORT ON    
 SET ANSI_WARNINGS ON    
END   
  

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'ComplianceReport_Retailer_Frequency' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[ComplianceReport_Retailer_Frequency]')
	END
GO
/****** Object:  StoredProcedure [dbo].[ComplianceReport_Retailer_Frequency]    Script Date: 3/2/2015 6:36:24 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- EXEC [ComplianceReport_Retailer_Frequency] '1', 'September 2010,October 2010, November 2010', 'Account_Name','1','Team','All','All','All'  
-- EXEC [ComplianceReport_Retailer_Frequency] 7,'may 2010,may 2011, may 2012', '4531','Team','BiWeekly','all','all','all'  
  
CREATE PROCEDURE [dbo].[ComplianceReport_Retailer_Frequency](  
 @P_OrgId VARCHAR(20),  
 @MonthYearList VARCHAR(1000)='',  
 @pUserName  VARCHAR(50),  
 @pUserType  VARCHAR(50)='Team',  
 @pFrequency     VARCHAR(10)='',  
 @pAccountName VARCHAR(100)='',  
 @pRegion  VARCHAR(100)='',  
 @pMarketGroup VARCHAR(100)='',  
 @pClusterGroup   VARCHAR(100) = ''  
)  
AS  
SET NOCOUNT ON
BEGIN  
  
 -- Declare  
 DECLARE @CUIDColumnName varchar(40)  
 DECLARE @SQL varchar(max)  
 DECLARE @strColNames varchar(max)  
 DECLARE @whereCondition varchar(max)  
 DECLARE @ResultColumn1 varchar(max)  
-- DECLARE @ResultColumn2 varchar(max)  
 DECLARE @ResultNameParam varchar(200)  
 DECLARE @pRoleLevelNum int  
 DECLARE @ResultShortName varchar(50)  
 DECLARE @ResultShortNameWhereAndGroup varchar(200)  
 DECLARE @NickNameSQL varchar(2000)  
 DECLARE @IsCompliance bit  
   
 SET @IsCompliance = 1  
 SELECT @IsCompliance = IsCompliance From Organization Where OrgId = @P_OrgId  
 IF @IsCompliance = 0  
  SET @pUserName='0'  
   
 -- Set   
 SET ARITHABORT OFF  
 SET ANSI_WARNINGS OFF  
  
 SET @ResultColumn1=''  
-- SET @ResultColumn2=''  
 SET @CUIDColumnName=''  
 SET @whereCondition=''  
 SET @ResultShortNameWhereAndGroup=''  
 SET @NickNameSQL = ''  
  
 SET @ResultColumn1 = 'Account_Name'  
 SET @ResultNameParam=''  
  
        IF @pAccountName='All' and @pRegion='All' and @pMarketGroup!='Select' and @pMarketGroup!='All'  
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.RegionName='''+@pMarketGroup+'''st.DivisionName!=''SandBox''' 
   SET @ResultColumn1='RegionName'  
   --SET @ResultColumn2='AccountName'  
   print 'Untreated case'  
  END  
  
  IF @pAccountName!='' and @pAccountName='All'  and @pRegion='All' and @pMarketGroup='All'   
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.DivisionName!=''SandBox''' 
   SET @ResultColumn1='RegionName'  
   --SET @ResultColumn2='AccountName'  
   print '1'  
  END  
  
  ELSE IF @pAccountName='Select' and @pRegion='Select' and @pMarketGroup='Select'   
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.DivisionName!=''SandBox'''
   SET @ResultColumn1='RegionName'  
   --SET @ResultColumn2='AccountName'  
   print '2'  
  END  
  
  ELSE IF @pAccountName='All' and @pRegion!='All' and @pRegion!='Select' and @pMarketGroup='All'  
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.DivisionName='''+@pRegion+'''and st.RegionName!=''SandBox'''  
   SET @ResultColumn1='RegionName'  
   --SET @ResultColumn2='AccountName'  
   print '3'  
  END  
  
  ELSE IF @pAccountName='All' and @pRegion!='All' and @pRegion!='Select' and @pMarketGroup!='All' and @pMarketGroup!='Select'   
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.DivisionName='''+@pRegion+'''  
    and st.RegionName='''+@pMarketGroup+'''and st.DivisionName!=''SandBox'''  
   SET @ResultColumn1='StoreName'  
   --SET @ResultColumn2='StoreName'  
   print '4'  
  END  
  
  ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion='All' and @pRegion!='Select'   
    and @pMarketGroup='All' and @pMarketGroup!='Select'  
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.AccountName='''+@pAccountName+'''and st.DivisionName!=''SandBox'''  
   SET @ResultColumn1='RegionName'  
   --SET @ResultColumn2='StoreName'  
   print '5'  
  END  
  ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion!='Select'   
    and @pMarketGroup='All' and @pMarketGroup!='Select'  
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.AccountName='''+@pAccountName+'''  
    and st.DivisionName='''+@pRegion+'''and st.RegionName!=''SandBox'''  
   SET @ResultColumn1='RegionName'  
   --SET @ResultColumn2='StoreName'  
   print '6'  
  END  
  
  ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion!='Select'   
    and @pMarketGroup!='All' and @pMarketGroup!='Select'  
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.AccountName='''+@pAccountName+'''  
    and st.DivisionName='''+@pRegion+'''  
    and st.RegionName='''+@pMarketGroup+'''st.MarketClusterName!=''SandBox'''  
   SET @ResultColumn1='StoreName'  
   --SET @ResultColumn2='StoreName'  
   print '7'  
  END  
  
  ELSE IF @pAccountName='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion='Select'   
    and @pMarketGroup!='All' and @pMarketGroup='Select'  
  BEGIN
    SET @whereCondition = @whereCondition+'
    and st.MarketClusterName!=''SandBox'''   
   SET @ResultColumn1='AccountName'  
   --SET @ResultColumn2='AccountName'  
   print '8'  
  END  
  
  ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion='Select'   
    and @pMarketGroup!='All' and @pMarketGroup='Select'  
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.AccountName='''+@pAccountName+'''st.MarketClusterName!=''SandBox'''  
   SET @ResultColumn1='DivisionName'  
   --SET @ResultColumn2='DivisionName'  
   print '9'  
  END  
  ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion!='Select'   
    and @pMarketGroup!='All' and @pMarketGroup='Select'  
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.AccountName='''+@pAccountName+'''  
    and st.DivisionName='''+@pRegion+'''st.MarketClusterName!=''SandBox'''  
   SET @ResultColumn1='RegionName'  
   --SET @ResultColumn2='RegionName'  
   print '10'  
  END  
  
  
  ELSE IF @pClusterGroup!='All' and @pClusterGroup!='Select'   
  BEGIN  
   SET @whereCondition = @whereCondition+'  
    and st.MarketClusterName='''+@pClusterGroup+'''st.RegionName!=''SandBox''' 
   print '11'  
  END  
    
 -- Define filters  
 IF @pRegion!='' and @pMarketGroup=''  
 BEGIN  
  SET @ResultShortNameWhereAndGroup = '  
    left outer join MarketGroupAbbreviation mga  
  on mga.marketgroups =  #temp2.ResultColumn1  
  group by ResultColumn1, coalesce(Abbreviation,#temp2.ResultColumn1)  
  order by [Order]'  
 END  
   
   
  
 /** Get the Date condition */  
 DECLARE @return_value int,  
 @DateWhereCondtion varchar(max),  
 @MonthCount int, @DateSelection VARCHAR(500)  
  
   
 EXEC @return_value = [dbo].[DateCondition_Supporter]  
 @pMonthYear = @MonthYearList,  
 @DateWhereCondtion = @DateWhereCondtion OUTPUT,   
 @MonthCount = @MonthCount OUTPUT,   
 @DateSelection = @DateSelection OUTPUT   
  
 --print '@MonthCount-->'+str(@MonthCount)  
  
  
-- Define column names  
 DECLARE @i int  
 DECLARE @prefix varchar  
 SET @strColNames=''  
 SET @i=0  
 While @i<=@MonthCount  
 BEGIN  
  SET @prefix=''  
  IF @i < 10  
   SET @prefix=''  
  SET @strColNames = @strColNames+'  
   , [Weekly'+convert(varchar(2),@i)+'] as [Weekly'+@prefix+convert(varchar(2),@i)+']  
   , [BiWeekly'+convert(varchar(2),@i)+'] as [BiWeekly'+@prefix+convert(varchar(2),@i)+']  
   , [Monthly'+convert(varchar(2),@i)+'] as [Monthly'+@prefix+convert(varchar(2),@i)+']'  
 SET @i=@i+1  
 END  
  
 -- Main query  
 SET @SQL = '  
  
 SELECT * into #StoreUserMappingTemp from dbo.Hierarchy_Function('+@P_OrgId+','+@pUserName+') '  
 IF @pUserType = 'Individual'  
 BEGIN  
  SET @SQL = @SQL + 'Where UserId='+@pUserName  
 END  
  
 SET @SQL = @SQL +'  
  
 CREATE TABLE #MonthAndNumber   
  (  
     MonthYear varchar(15)  
   , NumberIdentity [int] IDENTITY(1,1) NOT NULL  
   , Number as ltrim(rtrim(str(NumberIdentity-1)))  
  )  
 INSERT INTO #MonthAndNumber (MonthYear)  
 SELECT ltrim(rtrim(OutputValue)) As MonthYear FROM dbo.Spliter('''+@MonthYearList+', '','','')  
  
 select pvt.ResultColumn1, StoreCount'  
  
 SET @SQL = @SQL + @strColNames +'  
 into #temp1  
 from  
 (  
  select st.'+ @ResultColumn1 + ' as ResultColumn1, count(ch.StoreVisitsCategory) as StoreCount,   
  StoreVisitsCategory+#MonthAndNumber.Number as months,   
  --(sum(TotalStoreVisits)*100.0/sum(Rule_NoStoreVisit)) as compliance  
  AVG(compliance*1.00) as compliance  
  from ComplianceHistory ch, vwComplianceStore st, #MonthAndNumber   
  where --[date]  
    --between dateadd(m, datediff(m, 0, dateadd(mm,'+convert(varchar(3),@MonthCount*(-1))+',getdate())), 0)   
    --and dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))  
    '+@DateWhereCondtion+'  
  
    and ch.StoreId = st.StoreId AND ch.RecentForMonth=1   
    and ch.StoreVisitsCategory='''+@pFrequency+''' --and st.isOnBoarding=1   
    and ch.StoreId in (select StoreId from #StoreUserMappingTemp)   
       and dateName(mm,ch.date)+'' ''+dateName(year,ch.date)=#MonthAndNumber.MonthYear  
'  
  
  SET @SQL = @SQL + @whereCondition  
  
  SET @SQL = @SQL + '  
   GROUP BY st.'+@ResultColumn1+', StoreVisitsCategory+#MonthAndNumber.Number  
  ) P  
  PIVOT  
  (  
   sum(compliance)  
   for months in '  
  
  SET @strColNames=''  
  SET @i=0  
  SET @prefix=''  
  While @i<=@MonthCount  
  BEGIN  
   IF @i != 0  
    SET @prefix=',  
    '  
   SET @strColNames = @strColNames+@prefix+' [Weekly'+convert(varchar(2),@i)+']'  
             +', [BiWeekly'+convert(varchar(2),@i)+']'  
             +', [Monthly'+convert(varchar(2),@i)+']'  
  SET @i=@i+1  
  END  
  
  SET @SQL = @SQL + '('+@strColNames +')  
  
  ) as PVT  
  order by PVT.ResultColumn1 '  
  
  SET @strColNames=''  
  SET @i=0  
  SET @prefix=''  
  While @i<=@MonthCount  
  BEGIN  
   IF @i != 0  
    SET @prefix=',  
    '  
   SET @strColNames = @strColNames+@prefix  
     +' [Weekly'+convert(varchar(2),@i)+']'  
     +', case when [Weekly'+convert(varchar(2),@i)+'] is not null then StoreCount else null end AS [Weekly'+convert(varchar(2),@i)+'count]'  
     +', [BiWeekly'+convert(varchar(2),@i)+']'  
     +', case when [BiWeekly'+convert(varchar(2),@i)+'] is not null then StoreCount else null end AS [BiWeekly'+convert(varchar(2),@i)+'Count]'  
     +', [Monthly'+convert(varchar(2),@i)+']'  
     +', case when [Monthly'+convert(varchar(2),@i)+'] is not null then StoreCount else null end AS [Monthly'+convert(varchar(2),@i)+'Count]'  
  SET @i=@i+1  
  END  
  
 -- Calculating Overall - Start  
 DECLARE @strOverallColNames VARCHAR(MAX)  
 DECLARE @colW varchar(10)  
 DECLARE @colB varchar(10)  
 DECLARE @colM varchar(10)  
 DECLARE @colOverall varchar(10)  
 DECLARE @colOverallCount varchar(15)  
  
 SET @strOverallColNames=''  
 SET @i=0  
 While @i<=@MonthCount  
 BEGIN  
  SET @prefix=''  
  IF @i < 10  
   SET @prefix=''  
  
  SET @colW='Weekly'+@prefix+convert(varchar(2),@i)  
  SET @colB='BiWeekly'+@prefix+convert(varchar(2),@i)  
  SET @colM='Monthly'+@prefix+convert(varchar(2),@i)  
  SET @colOverall='Overall'+@prefix+convert(varchar(2),@i)  
  SET @colOverallCount='Overall'+@prefix+convert(varchar(2),@i)+'Count'  
  
  SET @strOverallColNames = @strOverallColNames+  
  char(13)+'  , '+@colOverall +'=( (isnull('+@colW+',0) * isnull(StoreCount,0)) + (isnull('+@colB+',0) * isnull(StoreCount,0)) + (isnull('+@colM+',0) * isnull(StoreCount,0)))/( case when '+@colW+' is not null then StoreCount else 0 end + case when '+@colB
+' is not null then StoreCount else 0 end + case when '+@colM+' is not null then StoreCount else 0 end)'  
  +  
  char(13)+'  , '+@colOverallCount +'=( case when '+@colW+' is not null then StoreCount else 0 end + case when '+@colB+' is not null then StoreCount else 0 end + case when '+@colM+' is not null then StoreCount else 0 end)'  
  SET @i=@i+1  
 END  
  
 SET @strOverallColNames = char(13)+'  
     SELECT ResultColumn1, StoreCount, '+@strColNames +''+@strOverallColNames+'   
     INTO #Temp2   
     FROM #Temp1 '  
 -- Calculating Overall - End  
  
  -- Store nick name check and update  
  IF (@ResultColumn1='StoreName')  
  BEGIN  
   SET @NickNameSQL = '  
   -- Store nick name check and update  
  
   SELECT * INTO #StoreListForNickName1 from StoreListForNickNameChange('+@P_OrgId+','+@pUserName+')  
  
   BEGIN  
   UPDATE #temp1 SET  
    ResultColumn1 = isnull(   
      CASE   
       WHEN LTRIM(RTRIM(CertifiedStoreNickName))='''' THEN ST.StoreName  
       WHEN CertifiedStoreNickName is null THEN ST.StoreName  
       ELSE CertifiedStoreNickName   
      END, ResultColumn1)  
   FROM     
     Store ST  
     join #temp1 on ST.StoreName = #temp1.ResultColumn1  
   WHERE   
     ST.StoreName in (SELECT StoreName FROM #StoreListForNickName1)  
     AND ST.OrgId = '+@P_OrgId+'  
     AND ST.IsActive=1  
     /** Requirement changes - compliance on/off */  
     AND ST.IsCompliance = 1  
   END '  
  END  
  
  
 -- Final output from main query  
  
 SET @strColNames=''  
 SET @i=0  
 While @i<=@MonthCount  
 BEGIN  
  SET @prefix=''  
  IF @i < 10  
   SET @prefix=''  
  SET @strColNames = @strColNames+',  
    convert(varchar(6),convert(decimal(6,2),round(avg(Weekly'+@prefix+convert(varchar(2),@i)+'),2))) as Weekly'+@prefix+convert(varchar(2),@i)+',   
    convert(varchar(6),convert(int,avg(Weekly'+@prefix+convert(varchar(2),@i)+'Count))) as Weekly'+@prefix+convert(varchar(2),@i)+'Count'  
  SET @strColNames = @strColNames+',  
    convert(varchar(6),convert(decimal(6,2),round(avg(BiWeekly'+@prefix+convert(varchar(2),@i)+'),2))) as BiWeekly'+@prefix+convert(varchar(2),@i)+',   
    convert(varchar(6),convert(int,avg(BiWeekly'+@prefix+convert(varchar(2),@i)+'Count))) as BiWeekly'+@prefix+convert(varchar(2),@i)+'Count'  
  SET @strColNames = @strColNames+',  
    convert(varchar(6),convert(decimal(6,2),round(avg(Monthly'+@prefix+convert(varchar(2),@i)+'),2))) as Monthly'+@prefix+convert(varchar(2),@i)+',   
    convert(varchar(6),convert(int,avg(Monthly'+@prefix+convert(varchar(2),@i)+'Count))) as Monthly'+@prefix+convert(varchar(2),@i)+'Count'  
  SET @strColNames = @strColNames+',  
    convert(varchar(6),convert(decimal(6,2),round(avg(Overall'+@prefix+convert(varchar(2),@i)+'),2))) as Overall'+@prefix+convert(varchar(2),@i)+',   
    convert(varchar(6),convert(int,avg(Overall'+@prefix+convert(varchar(2),@i)+'Count))) as Overall'+@prefix+convert(varchar(2),@i)+'Count'  
  SET @i=@i+1  
 END  
  
 -- To populate month column  
-- DECLARE @strMonthYear varchar(MAX)  
-- SET @strMonthYear=' '  
-- SET @i=0  
-- While @i<=@MonthCount  
-- BEGIN  
--  SET @prefix=''  
--  SET @strMonthYear = @strMonthYear+  
--   ' '''+DateName(mm,dateadd(mm,-@i,getdate()))+' '+DateName(yyyy,dateadd(mm,-@i,getdate()))+''' as Month'+cast(@i as varchar(2))+', '  
--  SET @i=@i+1  
-- END  
  
 DECLARE @resultSQL AS VARCHAR(MAX)  
 SET @resultSQL = '  
  
 -- Get average and list  
 BEGIN  
  select '+@ResultNameParam+@DateSelection  
  IF (@pRegion!='' and @pMarketGroup='')  
   SET @resultSQL=@resultSQL+'coalesce(Abbreviation,#temp2.ResultColumn1) AS ResultShortName,'  
  
  --SET @resultSQL=@resultSQL+ 'case ResultColumn1 when ''AVERAGE'' THEN ''1'' ELSE ''0'' END as [Order],  ResultColumn1, ResultColumn2 '+@strColNames+' from #temp2'  
  SET @resultSQL=@resultSQL+ '''0'' as [Order],  ResultColumn1 '+@strColNames+' from #temp2'  
  
  IF (@pRegion!='' and @pMarketGroup='')  
   SET @resultSQL=@resultSQL+@ResultShortNameWhereAndGroup  
  ELSE  
   SET @resultSQL=@resultSQL+ '   
   group by ResultColumn1  
   order by [Order], ResultColumn1'  
  SET @resultSQL=@resultSQL+'  
 END  
 '  
 print @SQL  
 print @strOverallColNames  
 print @resultSQL  
  
 SET @SQL=@SQL+@NickNameSQL+@strOverallColNames+@resultSQL  
  
 --PRINT @SQL  
  
 EXEC (@SQL)  
  
END  

GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'ComplianceReport_Retailer_Geography' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[ComplianceReport_Retailer_Geography]')
	END
GO
/****** Object:  StoredProcedure [dbo].[ComplianceReport_Retailer_Geography]    Script Date: 3/2/2015 6:36:26 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*    
-- EXEC [ComplianceReport_Retailer_Geography] '1', 'September 2010, December 2010 ', 'Account_Name','1','Team','All','All','All'     
-- EXEC [ComplianceReport_Retailer_Geography] '5', 'January 2011, December 2010, November 2010', 'Account_Name','1','Team','All','All','All'     
-- EXEC [ComplianceReport_Retailer_Geography] '5', 'December 2010, November 2010, October 2010', 'Account_Name','1','Team','All','All','All'     
    
EXEC [ComplianceReport_Retailer_Geography_rps] '5', 'December 2010', 'Account_Name','1','Team','All','All','All'     
EXEC [ComplianceReport_Retailer_Geography_rps] '5', 'January 2011, December 2010', 'Account_Name','1','Team','All','All','All'     
EXEC [ComplianceReport_Retailer_Geography] '7', 'November 2012,October 2012,September 2012,August 2012', 'Store_Division','1','Team','All','All','All'     
*/    
CREATE PROCEDURE [dbo].[ComplianceReport_Retailer_Geography](    
 @P_OrgId  VARCHAR(20),    
 @MonthYearList VARCHAR(1000)='',    
 @pInitialName VARCHAR(50),    
 @pUserName  VARCHAR(50),    
 @pUserType  VARCHAR(50)='Team',    
 @pAccountName VARCHAR(100)='',    
 @pRegion  VARCHAR(100)='',    
 @pMarketGroup VARCHAR(100)='',    
 @pClusterGroup VARCHAR(100)=''    
)    
AS    
SET NOCOUNT ON
BEGIN    
    
 -- Declare    
 DECLARE @CUIDColumnName varchar(40)    
 DECLARE @SQL varchar(max)    
 DECLARE @strColNames varchar(max)    
 DECLARE @whereCondition varchar(max)    
 DECLARE @ResultNameParam varchar(200)    
 DECLARE @pRoleLevelNum int    
 DECLARE @ResultShortName varchar(50)    
 DECLARE @ResultShortNameWhereAndGroup varchar(200)    
 DECLARE @ResultColumn1 varchar(max)    
 DECLARE @ResultColumn2 varchar(max)    
 DECLARE @NickNameSQL varchar(2000)    
 DECLARE @IsCompliance bit    
     
 SET @IsCompliance = 1    
 SELECT @IsCompliance = IsCompliance From Organization Where OrgId = @P_OrgId    
 IF @IsCompliance = 0    
  SET @pUserName='0'    
    
 -- Set     
 SET ARITHABORT OFF    
 SET ANSI_WARNINGS OFF    
    
 SET @ResultColumn1=''    
 SET @CUIDColumnName=''    
 SET @whereCondition=''    
 SET @ResultShortNameWhereAndGroup=''    
 SET @NickNameSQL = ''    
    
 SET @ResultNameParam=''    
 print 'initial name : ' +@pInitialName    
    
 -- Define filters    
 IF @pInitialName='Account_Name'    
 BEGIN    
    IF @pAccountName='All' and @pRegion='All' and @pMarketGroup!='Select' and @pMarketGroup!='All'    
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.RegionName='''+@pMarketGroup+'''  
		and st.MarketClusterName!=''sandbox'''     
		SET @ResultColumn1='RegionName'    
		SET @ResultColumn2='AccountName'    
		print 'Untreated case'    
	END    
    
	IF @pAccountName!='' and @pAccountName='All'  and @pRegion='All' and @pMarketGroup='All'     
	BEGIN   
		SET @whereCondition = @whereCondition+'   
		and st.MarketClusterName!=''sandbox'''   
		SET @ResultColumn1='RegionName'    
		SET @ResultColumn2='AccountName'    
		print '1'    
	END    
	ELSE IF @pAccountName='Select' and @pRegion='Select' and @pMarketGroup='Select'     
	BEGIN   
		SET @whereCondition = @whereCondition+'   
		and st.MarketClusterName!=''sandbox'''  
		SET @ResultColumn1='RegionName'    
		SET @ResultColumn2='AccountName'    
		print '2'    
	END    
    
	ELSE IF @pAccountName='All' and @pRegion!='All' and @pRegion!='Select' and @pMarketGroup='All'    
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.DivisionName='''+@pRegion+'''  
		and st.MarketClusterName!=''sandbox'''      
		SET @ResultColumn1='RegionName'    
		SET @ResultColumn2='AccountName'    
		print '3'    
	END    
    
	ELSE IF @pAccountName='All' and @pRegion!='All' and @pRegion!='Select' and @pMarketGroup!='All' and @pMarketGroup!='Select'     
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.DivisionName='''+@pRegion+'''    
		and st.RegionName='''+@pMarketGroup+'''  
		and st.MarketClusterName!=''sandbox'''      
		SET @ResultColumn1='StoreName'    
		SET @ResultColumn2='StoreName'    
		print '4'    
	END    
    
	ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion='All' and @pRegion!='Select'     
	and @pMarketGroup='All' and @pMarketGroup!='Select'    
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.AccountName='''+@pAccountName+'''  
		and st.MarketClusterName!=''sandbox'''       
		SET @ResultColumn1='RegionName'    
		SET @ResultColumn2='StoreName'    
		print '5'    
	END    
	
	ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion!='Select'     
	and @pMarketGroup='All' and @pMarketGroup!='Select'    
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.AccountName='''+@pAccountName+'''    
		and st.DivisionName='''+@pRegion+'''  
		and st.MarketClusterName!=''sandbox'''      
		SET @ResultColumn1='RegionName'    
		SET @ResultColumn2='StoreName'    
		print '6'    
	END    
    
	ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion!='Select'     
    and @pMarketGroup!='All' and @pMarketGroup!='Select'    
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.AccountName='''+@pAccountName+'''    
		and st.DivisionName='''+@pRegion+'''    
		and st.RegionName='''+@pMarketGroup+'''  
		and st.MarketClusterName!=''sandbox'''      
		SET @ResultColumn1='StoreName'    
		SET @ResultColumn2='StoreName'    
		print '7'    
	END    
    
	ELSE IF @pAccountName='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion='Select'     
	and @pMarketGroup!='All' and @pMarketGroup='Select'    
	BEGIN    
		SET @whereCondition = @whereCondition+'  
		and st.MarketClusterName!=''sandbox'''     
		SET @ResultColumn1='AccountName'    
		SET @ResultColumn2='AccountName'    
		print '8'    
	END    
    
	ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion='Select'     
	and @pMarketGroup!='All' and @pMarketGroup='Select'    
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.AccountName='''+@pAccountName+'''  
		and st.MarketClusterName!=''sandbox'''    
		SET @ResultColumn1='DivisionName'    
		SET @ResultColumn2='DivisionName'    
		print '9'    
	END    
	
	ELSE IF @pAccountName!='All' and @pAccountName!='Select' and @pRegion!='All' and @pRegion!='Select'     
    and @pMarketGroup!='All' and @pMarketGroup='Select'    
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.AccountName='''+@pAccountName+'''    
		and st.DivisionName='''+@pRegion+'''  
		and st.MarketClusterName!=''sandbox'''    
		SET @ResultColumn1='RegionName'    
		SET @ResultColumn2='RegionName'    
		print '10'    
	END
      
	ELSE IF @pClusterGroup!='All' and @pClusterGroup!='Select'     
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.MarketClusterName='''+@pClusterGroup+''' and st.MarketClusterName!=''sandbox'''    
		print '11'    
	END    
END -- @pInitialName='Account_Name'

ELSE IF @pInitialName='Store_Division'    
BEGIN    
	IF dbo.IsFieldSelected(@pRegion) = 0 and dbo.IsFieldSelected(@pMarketGroup) = 0
	BEGIN
		SET @whereCondition = @whereCondition+'
		and st.MarketClusterName!=''sandbox'''
		SET @ResultColumn1='DivisionName'    
		SET @ResultColumn2='RegionName'    
		print '11'
	END    
	ELSE IF dbo.IsFieldSelected(@pRegion) = 0 and dbo.IsFieldSelected(@pMarketGroup) = 1    
	BEGIN
		SET @whereCondition = @whereCondition+'    
		and st.RegionName='''+@pMarketGroup+''' and st.MarketClusterName!=''sandbox'''    
		SET @ResultColumn1='StoreName'    
		SET @ResultColumn2='StoreName'    
		print 'Untreated case - 12.5'    
	END    
	ELSE IF dbo.IsFieldSelected(@pRegion) = 1 and dbo.IsFieldSelected(@pMarketGroup) = 0     
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.DivisionName='''+@pRegion+''' and st.MarketClusterName!=''sandbox'''    
		SET @ResultColumn1='RegionName'    
		SET @ResultColumn2='RegionName'    
		print '13'    
	END    
	ELSE IF dbo.IsFieldSelected(@pRegion) = 1 and dbo.IsFieldSelected(@pMarketGroup) = 1     
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.DivisionName='''+@pRegion+'''    
		and st.RegionName='''+@pMarketGroup+''' and st.MarketClusterName!=''sandbox'''    
		SET @ResultColumn1='StoreName'    
		SET @ResultColumn2='StoreName'    
		print '14'    
	END    
	IF dbo.IsFieldSelected(@pClusterGroup) = 1
	BEGIN    
		SET @whereCondition = @whereCondition+'    
		and st.MarketClusterName='''+@pClusterGroup+''' and st.MarketClusterName!=''sandbox'''    
		print '15'    
	END    

END	-- @pInitialName='Store_Division'
    
 /** Get the Date condition */    
 DECLARE @return_value int,    
 @DateWhereCondtion varchar(max),    
 @MonthCount int, @DateSelection VARCHAR(500)    
     
 EXEC @return_value = [dbo].[DateCondition_Supporter]    
 @pMonthYear = @MonthYearList,    
 @DateWhereCondtion = @DateWhereCondtion OUTPUT,     
 @MonthCount = @MonthCount OUTPUT,     
 @DateSelection = @DateSelection OUTPUT    
 --print '@MonthCount-->'+str(@MonthCount)    
    
-- Define column names    
 DECLARE @i int    
 DECLARE @prefix varchar    
 SET @strColNames=''    
 SET @i=0    
 While @i<@MonthCount    
 BEGIN    
  SET @prefix=''    
  IF @i < 10    
   SET @prefix=''    
  SET @strColNames = @strColNames+'    
   , [Weekly'+convert(varchar(2),@i)+'] as [Weekly'+@prefix+convert(varchar(2),@i)+']    
   , [BiWeekly'+convert(varchar(2),@i)+'] as [BiWeekly'+@prefix+convert(varchar(2),@i)+']    
   , [Monthly'+convert(varchar(2),@i)+'] as [Monthly'+@prefix+convert(varchar(2),@i)+']'    
 SET @i=@i+1    
 END    
    
    
     
    
 -- Main query    
 SET @SQL = '    
    
 SELECT * into #StoreUserMappingTemp from dbo.Hierarchy_Function('+@P_OrgId+','+@pUserName+') '    
 IF @pUserType = 'Individual'    
 BEGIN    
  SET @SQL = @SQL + 'Where UserId='+@pUserName    
 END    
    
 SET @SQL = @SQL +'    
    
 CREATE TABLE #MonthAndNumber     
  (    
     MonthYear varchar(15)    
   , NumberIdentity [int] IDENTITY(1,1) NOT NULL    
   , Number as ltrim(rtrim(str(NumberIdentity-1)))    
  )    
 INSERT INTO #MonthAndNumber (MonthYear)    
 SELECT ltrim(rtrim(OutputValue)) As MonthYear FROM dbo.Spliter('''+@MonthYearList+', '','','')    
    
 select pvt.ResultColumn1, ResultColumn2, StoreCount'    
    
 SET @SQL = @SQL + @strColNames +'    
 into #temp1    
 from    
 (    
  select st.'+ @ResultColumn1 + ' as ResultColumn1 , st.'+ @ResultColumn2 + ' as ResultColumn2, count(ch.StoreVisitsCategory) as StoreCount,    
  StoreVisitsCategory+#MonthAndNumber.Number as months,     
  AVG(compliance*1.00) as compliance    
  from ComplianceHistory ch, vwComplianceStore st, #MonthAndNumber    
  where --[date]    
    '+@DateWhereCondtion+'    
    and ch.StoreId = st.StoreId AND ch.RecentForMonth=1 -- and st.isOnBoarding=1     
    and ch.StoreId in (select StoreId from #StoreUserMappingTemp)     
       and dateName(mm,ch.date)+'' ''+dateName(year,ch.date)=#MonthAndNumber.MonthYear    
'    
    
  SET @SQL = @SQL + @whereCondition    
    
  SET @SQL = @SQL + '    
   GROUP BY st.'+@ResultColumn1+', st.'+ @ResultColumn2 +', StoreVisitsCategory+#MonthAndNumber.Number    
    
  ) P    
  PIVOT    
  (    
   sum(compliance)    
   for months in '    
    
  SET @strColNames=''    
  SET @i=0    
  SET @prefix=''    
  While @i<@MonthCount    
  BEGIN    
   IF @i != 0    
    SET @prefix=',    
    '    
   SET @strColNames = @strColNames+@prefix+' [Weekly'+convert(varchar(2),@i)+']'    
             +', [BiWeekly'+convert(varchar(2),@i)+']'    
             +', [Monthly'+convert(varchar(2),@i)+']'    
  SET @i=@i+1    
  END    
    
  SET @SQL = @SQL + '('+@strColNames +')    
    
  ) as PVT    
  order by PVT.ResultColumn1    
  '    
    
  -- Store nick name check and update    
  IF (@ResultColumn1='StoreName')    
  BEGIN    
   SET @NickNameSQL = '    
    
   -- Store nick name check and update    
    
   SELECT * INTO #StoreListForNickName1 from StoreListForNickNameChange('+@P_OrgId+','+@pUserName+')    
    
   BEGIN    
   UPDATE #temp1 SET    
    ResultColumn1 = isnull(     
      CASE     
       WHEN LTRIM(RTRIM(CertifiedStoreNickName))='''' THEN ST.StoreName    
       WHEN CertifiedStoreNickName is null THEN ST.StoreName    
       ELSE CertifiedStoreNickName     
      END, ResultColumn1)    
            FROM          
     Store ST    
     join #temp1 on ST.StoreName = #temp1.ResultColumn1    
   WHERE     
     ST.StoreName in (SELECT StoreName FROM #StoreListForNickName1)    
     AND ST.OrgId = '+@P_OrgId+'    
     AND ST.IsActive=1    
        
   END '    
  END    
    
  IF (@ResultColumn2='StoreName')    
  BEGIN    
   SET @NickNameSQL = @NickNameSQL + '    
    
   -- Store nick name check and update    
    
   SELECT * INTO #StoreListForNickName2 from StoreListForNickNameChange('+@P_OrgId+','+@pUserName+')    
    
   BEGIN    
   UPDATE #temp1 SET    
    ResultColumn2=isnull(     
      CASE     
       WHEN LTRIM(RTRIM(CertifiedStoreNickName))='''' THEN ST.StoreName    
       WHEN CertifiedStoreNickName is null THEN ST.StoreName    
       ELSE CertifiedStoreNickName     
      END, ResultColumn2)    
   FROM          
     Store ST    
     join #temp1 on ST.StoreName = #temp1.ResultColumn2    
   WHERE     
     ST.StoreName in (SELECT StoreName FROM #StoreListForNickName2)    
     AND ST.OrgId = '+@P_OrgId+'    
     AND ST.IsActive=1    
     /** Requirement changes - compliance on/off */    
     AND ST.IsCompliance = 1    
   END '    
  END    
    
  DECLARE @SQLTempTable varchar(max)    
  SET @SQLTempTable = ''    
  DECLARE @strColNamesForStoreCountCol varchar(max)    
    
  SET @strColNamesForStoreCountCol=''    
  SET @i=0    
  SET @prefix=''    
  While @i<@MonthCount    
  BEGIN    
   IF @i != 0    
    SET @prefix=',    
    '    
   SET @strColNamesForStoreCountCol = @strColNamesForStoreCountCol+char(13)+'   '    
     +', [Weekly'+convert(varchar(2),@i)+']'    
     +', case when [Weekly'+convert(varchar(2),@i)+'] is not null then StoreCount else null end AS [Weekly'+convert(varchar(2),@i)+'count]'    
     +', [BiWeekly'+convert(varchar(2),@i)+']'    
     +', case when [BiWeekly'+convert(varchar(2),@i)+'] is not null then StoreCount else null end AS [BiWeekly'+convert(varchar(2),@i)+'Count]'    
     +', [Monthly'+convert(varchar(2),@i)+']'    
     +', case when [Monthly'+convert(varchar(2),@i)+'] is not null then StoreCount else null end AS [Monthly'+convert(varchar(2),@i)+'Count]'    
  SET @i=@i+1    
  END    
    
  SET @SQLTempTable = @SQLTempTable + '    
    
  SELECT ResultColumn1, ResultColumn2, StoreCount '+@strColNamesForStoreCountCol +'     
  INTO #Temp2     
  FROM #Temp1     
  '    
    
  SET @strColNamesForStoreCountCol=''    
  SET @i=0    
  SET @prefix=''    
  While @i<@MonthCount    
  BEGIN    
   IF @i != 0    
    SET @prefix=',    
    '    
   SET @strColNamesForStoreCountCol = @strColNamesForStoreCountCol+char(13)+'   '    
     +',Avg([Weekly'+convert(varchar(2),@i)+']) AS [Weekly'+convert(varchar(2),@i)+']'    
     +',Avg([Weekly'+convert(varchar(2),@i)+'Count]) AS [Weekly'+convert(varchar(2),@i)+'Count]'    
     +',Avg([BiWeekly'+convert(varchar(2),@i)+']) AS [BiWeekly'+convert(varchar(2),@i)+']'    
     +',Avg([BiWeekly'+convert(varchar(2),@i)+'Count]) AS [BiWeekly'+convert(varchar(2),@i)+'Count]'    
     +',Avg([Monthly'+convert(varchar(2),@i)+']) AS [Monthly'+convert(varchar(2),@i)+']'    
     +',Avg([Monthly'+convert(varchar(2),@i)+'Count]) AS [Monthly'+convert(varchar(2),@i)+'Count]'    
  SET @i=@i+1    
  END    
    
  SET @SQLTempTable = @SQLTempTable + '    
  SELECT ResultColumn1, ResultColumn2 '+@strColNamesForStoreCountCol +'     
  INTO #Temp3     
  FROM #Temp2    
  group by ResultColumn1, ResultColumn2     
  '    
    
  SET @strColNamesForStoreCountCol=''    
  SET @i=0    
  SET @prefix=''    
  While @i<@MonthCount    
  BEGIN    
   IF @i != 0    
    SET @prefix=',    
    '    
   SET @strColNamesForStoreCountCol = @strColNamesForStoreCountCol+char(13)+'  '    
     +', [Weekly'+convert(varchar(2),@i)+'])'    
     +', [Weekly'+convert(varchar(2),@i)+'Count])'    
     +', [BiWeekly'+convert(varchar(2),@i)+'])'    
     +', [BiWeekly'+convert(varchar(2),@i)+'Count])'    
     +', [Monthly'+convert(varchar(2),@i)+'])'    
     +', [Monthly'+convert(varchar(2),@i)+'Count])'    
  SET @i=@i+1    
  END    
    
 -- Calculating Overall - Start    
 DECLARE @strOverallColNames VARCHAR(MAX)    
 DECLARE @colW varchar(10)    
 DECLARE @colWCount varchar(15)    
 DECLARE @colB varchar(10)    
 DECLARE @colBCount varchar(15)    
 DECLARE @colM varchar(10)    
 DECLARE @colMCount varchar(15)    
 DECLARE @colOverall varchar(10)    
 DECLARE @colOverallCount varchar(15)    
    
 SET @strOverallColNames=''    
 SET @i=0    
 While @i<@MonthCount    
 BEGIN    
  SET @prefix=''    
  IF @i < 10    
   SET @prefix=''    
    
  SET @colW='Weekly'+@prefix+convert(varchar(2),@i)    
  SET @colWCount='Weekly'+@prefix+convert(varchar(2),@i)+'Count'    
  SET @colB='BiWeekly'+@prefix+convert(varchar(2),@i)    
  SET @colBCount='BiWeekly'+@prefix+convert(varchar(2),@i)+'Count'    
  SET @colM='Monthly'+@prefix+convert(varchar(2),@i)    
  SET @colMCount='Monthly'+@prefix+convert(varchar(2),@i)+'Count'    
  SET @colOverall='Overall'+@prefix+convert(varchar(2),@i)    
  SET @colOverallCount='Overall'+@prefix+convert(varchar(2),@i)+'Count'    
    
  SET @strOverallColNames = @strOverallColNames+    
  char(13)+'   , '+@colOverall +'=( (isnull('+@colW+',0) * isnull('+@colWCount+',0)) + (isnull('+@colB+',0) * isnull('+@colBCount+',0)) + (isnull('+@colM+',0) * isnull('+@colMCount+',0)))/( case when '+@colW+' is not null then '+@colWCount+' else 0 end + 
  
case when '+@colB+' is not null then '+@colBCount+' else 0 end + case when '+@colM+' is not null then '+@colMCount+' else 0 end)'    
  +    
  char(13)+'   , '+@colOverallCount +'=( case when '+@colW+' is not null then '+@colWCount+' else 0 end + case when '+@colB+' is not null then '+@colBCount+' else 0 end + case when '+@colM+' is not null then '+@colMCount+' else 0 end)'    
  SET @i=@i+1    
 END    
    
 SET @strOverallColNames = char(13)+'    
  SELECT * '+@strOverallColNames+'     
  INTO #Temp4     
  FROM #Temp3 '    
 -- Calculating Overall - End    
    
 -- Final output from main query    
    
 SET @strColNames=''    
 SET @i=0    
 While @i<@MonthCount    
 BEGIN    
  SET @prefix=''    
  IF @i < 10    
   SET @prefix=''    
  SET @strColNames = @strColNames+'    
    , isnull(convert(varchar(6),convert(decimal(6,2),round(Weekly'+@prefix+convert(varchar(2),@i)+',2))),NULL) as Weekly'+@prefix+convert(varchar(2),@i)+'    
    , isnull(convert(varchar(6),convert(int,Weekly'+@prefix+convert(varchar(2),@i)+'Count)),NULL) as Weekly'+@prefix+convert(varchar(2),@i)+'Count'    
  SET @strColNames = @strColNames+'    
    , isnull(convert(varchar(6),convert(decimal(6,2),round(BiWeekly'+@prefix+convert(varchar(2),@i)+',2))),NULL) as BiWeekly'+@prefix+convert(varchar(2),@i)+'    
    , isnull(convert(varchar(6),convert(int,BiWeekly'+@prefix+convert(varchar(2),@i)+'Count)),NULL) as BiWeekly'+@prefix+convert(varchar(2),@i)+'Count'    
  SET @strColNames = @strColNames+'    
    , isnull(convert(varchar(6),convert(decimal(6,2),round(Monthly'+@prefix+convert(varchar(2),@i)+',2))),NULL) as Monthly'+@prefix+convert(varchar(2),@i)+'    
    , isnull(convert(varchar(6),convert(int,Monthly'+@prefix+convert(varchar(2),@i)+'Count)),NULL) as Monthly'+@prefix+convert(varchar(2),@i)+'Count'    
  SET @strColNames = @strColNames+'    
    , isnull(convert(varchar(6),convert(decimal(6,2),round(Overall'+@prefix+convert(varchar(2),@i)+',2))),NULL) as Overall'+@prefix+convert(varchar(2),@i)+'    
    , isnull(convert(varchar(6),convert(int,Overall'+@prefix+convert(varchar(2),@i)+'Count)),NULL) as Overall'+@prefix+convert(varchar(2),@i)+'Count'    
  SET @i=@i+1    
 END    
    
 -- To populate month column    
-- DECLARE @splitIndividual varchar(50)     
-- DECLARE @strMonthYear varchar(MAX)    
-- SET @strMonthYear=''    
-- SET @MonthYearList = @MonthYearList+','    
-- SET @i=0    
-- While @i<@MonthCount    
-- BEGIN    
--  SET @splitIndividual = LEFT(@MonthYearList,CHARINDEX(',', @MonthYearList, 1))    
--  SET @strMonthYear = @strMonthYear+' '''+@splitIndividual+''' as Month'+cast(@i as varchar(2))+', '    
--  SET @i=@i+1    
--  SET @MonthYearList = REPLACE(@MonthYearList,@splitIndividual,'')    
--  SET @MonthYearList = RIGHT(@MonthYearList,LEN(@MonthYearList))    
--  --PRINT @MonthYearList    
-- END    
 --SELECT @strMonthYear        
    
 DECLARE @resultSQL AS VARCHAR(MAX)    
 SET @resultSQL = '    
    
 select '+@ResultNameParam+@DateSelection    
 SET @resultSQL=@resultSQL    
  + '--''0'' as [Order],     
   ResultColumn1, ResultColumn2     
  '+@strColNames+'    
  from #Temp4 '    
    
 IF (@pRegion!='' and @pMarketGroup='')    
  SET @resultSQL=@resultSQL+@ResultShortNameWhereAndGroup    
 ELSE    
  SET @resultSQL=@resultSQL+ '     
  order by --[Order],     
  ResultColumn1,ResultColumn2    
  '    
    
 print @SQL    
 print @NickNameSQL    
 print @SQLTempTable    
 print @strOverallColNames    
 print @resultSQL    
    
 SET @SQL=@SQL+@NickNameSQL+@SQLTempTable+@strOverallColNames+@resultSQL    
    
 EXEC (@SQL)    
    
END    
GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Contribution_Reports_UI_Supporter' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Contribution_Reports_UI_Supporter]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Contribution_Reports_UI_Supporter]    Script Date: 3/2/2015 6:36:27 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Contribution_Reports_UI_Supporter](
@P_OrgId Varchar(10)
)
AS
SET NOCOUNT ON
BEGIN

Declare @countvalue int
	Declare @FromDate datetime
    Declare @ToDate datetime
	Declare @WeeklyComplianceStartDay Varchar(10), @WeeklyComplianceEndDay Varchar(10), @WeeklyComplianceEndDayNo Int
	SET @WeeklyComplianceStartDay = ''
	SET @WeeklyComplianceEndDay = ''

	SELECT @WeeklyComplianceStartDay = WeeklyComplianceStartDay From Organization Where OrgId = @P_OrgId
	SELECT @WeeklyComplianceEndDayNo = dbo.[getWeekDayNumber]('DayNo',@WeeklyComplianceStartDay)

	/** IF its sunday need to point saturday  Otherwise previous day*/
	IF @WeeklyComplianceEndDayNo = 1
		SET @WeeklyComplianceEndDayNo = 7
	Else
		SET @WeeklyComplianceEndDayNo = @WeeklyComplianceEndDayNo - 1
	SELECT @WeeklyComplianceEndDay = dbo.[getWeekDayNumber]('DayName', @WeeklyComplianceEndDayNo)

	CREATE TABLE #MonthDetails(MonthNumber int identity(1,1),MONTHNAME VARCHAR(15),WEEK VARCHAR(25),WEEKNUMBER VARCHAR(25), YEARS VARCHAR(5), MONTHFULLNAME VARCHAR(15))

	if (object_id('TempDB..#MonthList') is null)
	CREATE TABLE #MonthList(Id int, Months varchar(10))

	declare @StartDate datetime
	declare @MonthDiff int
    declare @nextDate datetime
	declare @SQL varchar(max)
	select @StartDate = cast(value as datetime) from configuration where name = 'contribution_start_date' and OrgId = @P_OrgId
	set @MonthDiff = datediff(month, @StartDate, getdate()) + 1
   
	if @MonthDiff > 13
	begin
		
		set @nextDate = dateadd(mm,@MonthDiff -13,@StartDate)
		insert into #MonthList (id, Months) SELECT rec as Id,
		convert(varchar(10),dateadd(mm,rec-1,@nextDate ),101) AS Months
		FROM (SELECT top 13 row_number() OVER(ORDER BY [Name]) AS rec FROM configuration) RecNumber 		
		
	end
	else
	begin

       set @SQL = 'insert into #MonthList (id, Months) SELECT rec as Id,
       convert(varchar(10),dateadd(mm, rec - 1, '''+cast(@StartDate as varchar(max))+'''),101) AS Months  FROM (SELECT TOP ' + cast(@MonthDiff as varchar(2))+ ' row_number() OVER(ORDER BY [Name]) AS rec
       FROM configuration) RecNumber'

	exec (@SQL)		
	end

	SELECT DATEPART(Year,Months) as 'YEARS', DATENAME(month,Months) as 'MONTHNAME','0' as 'WEEK','0' as 'WEEKNUMBER','0' as 'MonthNumber','' as 'MONTHFULLNAME' from #MonthList   

END


GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Contribution_Store_Calculation' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Contribution_Store_Calculation]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Contribution_Store_Calculation]    Script Date: 3/2/2015 6:36:28 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Contribution_Store_Calculation]
(
	@OrgId INT
	,@UserId INT
	,@Dates VARCHAR(max)
	,@CurrentUser INT = null
	,@DivisionName VARCHAR(50) = null
	,@Market_Cluster VARCHAR(50) = null
	,@RegionName VARCHAR(50) = null
	,@Status INT OUT
	,@StatusMsg VARCHAR(MAX) OUT
)
AS
SET NOCOUNT ON
BEGIN
/*****************************************************/
/* Global variables declaration and initialization   */
/*                                           - Start */
/*****************************************************/

DECLARE @StoreId INT
		,@StatementStartDate datetime
		,@DateFrom DATETIME
		,@DateTo DATETIME

--DECLARE @Status INT
--		,@StatusMsg VARCHAR(MAX)

SELECT 
		@Status = 1
		,@StatusMsg = ''
		,@StatementStartDate = GETDATE()

/*****************************************************/
/* Global variables declaration and initialization   */
/*                                           - End   */
/*****************************************************/

BEGIN TRY
		BEGIN TRANSACTION

		/*****************************************************/
		/* For testing                               - Start */
		/*****************************************************/

		--DECLARE @OrgId INT
		--		,@UserId INT
		--		,@Dates VARCHAR(max)
		--		,@CurrentUser INT
		--		,@DivisionName VARCHAR(50)
		--		,@Market_Cluster VARCHAR(50)
		--		,@RegionName VARCHAR(50)

		--SET @Dates = '2014-01-01,2014-02-01,2014-03-01,2014-04-01,2014-05-01,2014-06-01,2014-07-01'
	
		--SELECT @OrgId = 4
		--		,@UserId = 6188
		--		,@CurrentUser = null
		--		,@StoreId = null
		--		,@DivisionName = null
		--		,@Market_Cluster = null
		--		,@RegionName = null

		/*****************************************************/
		/* For testing                               - End   */
		/*****************************************************/

		/*****************************************************/
		/* Create a Period Table for selected months - Start */
		/*****************************************************/

		DECLARE @PeriodTable TABLE
		(
			Year INT,
			Month INT,
			FirstDay DATETIME,
			LastDay DATETIME,
			DaysInMonth INT,
			MonthNo INT
		)

		/*****************************************************/
		/* Create a Period Table for selected months - End   */
		/*****************************************************/

		/*****************************************************/
		/* Populate period table                     - Start */
		/*****************************************************/

		;WITH Dates_Cte
		AS
		(SELECT CAST(s_n.OutputValue AS DATETIME) AS Date
			FROM dbo.Spliter_New(@Dates,',') s_n
		)
		INSERT INTO  @PeriodTable(FirstDay, LastDay, DaysInMonth, Month, Year, MonthNo)
			SELECT 
					d_c.[Date] AS [FirstDay]
					,DATEADD(mm, DATEDIFF(mm, 0, d_c.[Date]) + 1, -1) AS [LastDate]
					,DAY(DATEADD(d, -1, DATEADD(mm, DATEDIFF(m, 0, d_c.[Date]) + 1, 0))) AS [DaysInMonth]
					,DATEPART(mm, d_c.[Date]) AS [Month]
					,DATEPART(yy, d_c.[Date]) AS [Year]
					,DATEDIFF(mm, 0, d_c.[Date]) AS MonthNo
				FROM Dates_Cte d_c

		SELECT @DateFrom = MIN(pt.FirstDay)
				,@DateTo = CASE 
								WHEN DATEDIFF(mm, MAX(pt.LastDay), GETDATE()) = 0 THEN GETDATE()
								ELSE MAX(pt.LastDay)
							END
				FROM @PeriodTable pt

		/*****************************************************/
		/* Populate period table                     - End   */
		/*****************************************************/


		/*****************************************************/
		/* Current Month Variables                   - Start */
		/*****************************************************/
		DECLARE @CurrentDate DATETIME
				,@CurrentDay INT
				,@FirstDay INT
				,@DaysInCurrentMonth INT
				,@CurrentMonthNo INT
				,@CurrentYear INT
				,@CurrentMonth INT
				,@IsCurrentMonth tinyint

		/*****************************************************/
		/* Current Month Variables                   - End   */
		/*****************************************************/

		/*****************************************************/
		/* Current Month assignment                  - Start */
		/*****************************************************/

		--SET @CurrentDate = '2014-01-25 00:00:00.000'--, @IsCurrentMonth = 0

		SELECT @CurrentDate = CASE 
									WHEN DATEDIFF(mm, @DateTo, GETDATE()) =  0 THEN GETDATE()
									ELSE @DateTo
								END
				,@CurrentDay = DATEPART(dd, @CurrentDate)
				,@FirstDay = DAY(DATEADD(mm, DATEDIFF(m, 0, @CurrentDate), 0))
				,@DaysInCurrentMonth = DAY(DATEADD(d, -1, DATEADD(mm, DATEDIFF(m, 0, @CurrentDate) + 1, 0)))
				,@CurrentMonthNo = DATEDIFF(mm, 0, @CurrentDate)
				,@CurrentYear = DATEPART(yy, @CurrentDate)
				,@CurrentMonth = DATEPART(mm, @CurrentDate)
				,@IsCurrentMonth = CASE WHEN DATEDIFF(mm, @CurrentDate, GetDate()) = 0 THEN 1
										ELSE 0
									END

		/*****************************************************/
		/* Current Month assignment                  - End   */
		/*****************************************************/

		/*****************************************************/
		/* Test current Month assignment             - Start */
		/*****************************************************/

		--SELECT @CurrentDate AS CurrentDate
		--		,@CurrentYear AS CurrentYear
		--		,@CurrentMonth AS CurrentMonth
		--		,@FirstDay AS FirstDay
		--		,@DaysInCurrentMonth AS DaysInCurrentMonth
		--		,@CurrentDay AS CurrentDay
		--		,@CurrentMonthNo AS CurrentMonthNo
		--		,CASE @IsCurrentMonth 
		--			WHEN 0 THEN 'False'
		--			ELSE 'True'
		--		END AS IsCurrentMonth

		/*****************************************************/
		/* Test current Month assignment             - End   */
		/*****************************************************/

		/*****************************************************/
		/* Query for contribution                    - Start */
		/*****************************************************/

		;WITH StoreContribution_CTE
		AS
		(
			SELECT pt.[Year]
					,pt.[Month]
					,u.[UserName]
					,ur_f.[UserId]
					,sh.[StoreId]
					,sh.[StoreName]
					,sh.[Status]
					,sh.statusChangedDate AS [StatusChanged]
					,CASE sh.storeVisitCategory 
							WHEN 0 THEN 'Weekly'
							WHEN 1 THEN 'BiWeekly'
							WHEN 2 THEN 'Monthly'
						END AS [Period]
					,sh.storeVisitRule AS [Frequency]					
					,sh.visitGoal AS [VisitGoal]
					,sh.actualVisits AS [ActualVisits]
					,CASE 
						WHEN sh.totalVisitLength = 0 THEN NULL
						ELSE sh.totalVisitLength
					END AS [TotalVisitsLength]
				FROM @PeriodTable pt
					CROSS JOIN UserReporting_Function(@OrgId, @UserId) ur_f
						INNER JOIN Users u WITH (nolock) ON ur_f.UserId = u.Userid
						LEFT JOIN (Store s WITH (nolock)
							INNER JOIN StoreHistory sh WITH (nolock) ON sh.StoreId = s.StoreId
													AND sh.OrgId = s.OrgId
								 )
								 ON sh.UserId = ur_f.UserId 
									AND s.OrgId = @OrgId
									AND DATEDIFF(mm, 0, CONVERT(DATETIME, '01/'+ sh.Month, 103)) = MonthNo																
				WHERE 1 = 1
						AND DATEDIFF(mm, pt.FirstDay, GETDATE()) <> 0
						AND (@StoreId IS NULL OR s.StoreId = @StoreId)
						AND (@CurrentUser IS NULL OR ur_f.UserId = @CurrentUser OR ur_f.UserId = @UserId)
						AND (@DivisionName IS NULL OR s.Store_Division = @DivisionName)
						AND (@Market_Cluster IS NULL OR s.store_market_cluster = @Market_Cluster)
						AND (@RegionName IS NULL OR s.MarketGroup = @RegionName)					

			UNION ALL
			/**********************************************************/
			/* Calculate contribution for current month               */
			/**********************************************************/
			SELECT	DATEPART(yy, @CurrentDate) AS Year
					,DATEPART(mm, @CurrentDate) AS Month
					,u.UserName
					,cusdo.UserId
					,cusdo.StoreId
					,cusdo.StoreName
					,cusdo.Status	
					,cusdo.StatusDate AS [StatusChanged]
					,cusdo.StoreVisitsCategory AS [Period]
					,cusdo.StoreVisitRule AS [Frequency]
					,ROUND
					(
						(
						cusdo.DaysInMonth * 1.00 
								/ (CASE cusdo.StoreVisitsCategory 
											WHEN 'Monthly'	THEN cusdo.DaysInMonth
											WHEN 'BiWeekly' THEN 14
											WHEN 'Weekly'	THEN 7
									END) 
								* cusdo.StoreVisitRule 
								* (cusdo.StoreDays - ISNULL(cusdo.NoOfOooDays, 0)) 
								* 1.00 
								/ cusdo.DaysInMonth
						),0
					) AS [VisitGoal]
					,COUNT(fv.FormVisitId) AS [ActualVisits]
					,SUM(fv.LengthOfVisitInMinutes) AS [TotalVisitsLength] 
				FROM 
					ContributionUserStoreDetailOoo(@OrgId, @UserId, @CurrentDate, null, null, null, null) cusdo
					INNER JOIN Users u WITH (nolock) ON u.UserId = cusdo.UserId 
						LEFT JOIN FormVisit fv WITH (nolock) ON fv.StoreId = cusdo.StoreId
																		AND fv.UserId = cusdo.UserId																
																		AND DATEDIFF(mm, fv.CreatedOn, @CurrentDate) = 0
																		AND fv.CreatedOn >= cusdo.StartDate 
																		AND fv.CreatedOn <= cusdo.EndDate
				WHERE 1 = 1
					AND @IsCurrentMonth = 1
				GROUP BY 
					cusdo.UserId
					,u.UserName
					,cusdo.StoreId
					,cusdo.StoreName
					,cusdo.StoreVisitsCategory
					,cusdo.StoreVisitRule
					,cusdo.Status	
					,cusdo.StatusDate
					,cusdo.DaysInMonth
					,cusdo.StoreDays
					,cusdo.NoOfOooDays
		)
		SELECT 
				sc_c.[Year]
				,sc_c.[Month]
				,sc_c.[UserName]
				,CAST(sc_c.[UserId] AS INT) AS [UserId]
				,CAST(sc_c.[StoreId] AS INT) AS [StoreId]
				,sc_c.[StoreName]
				,sc_c.[Status]
				,sc_c.[StatusChanged]
				,sc_c.[Period]
				,sc_c.[Frequency]
				,sc_c.[VisitGoal]
				,sc_c.[ActualVisits]
				,CAST(sc_c.[TotalVisitsLength] AS INT) AS [TotalVisitsLength]
			FROM StoreContribution_CTE sc_c
			WHERE sc_c.StoreId IS NOT NULL
				ORDER BY
					sc_c.[Year] DESC
					,sc_c.[Month] DESC
					,sc_c.UserId
					,sc_c.StoreName
					

		/*****************************************************/
		/* Query for contribution                    - End   */
		/*****************************************************/

		IF @@trancount > 0
		BEGIN
--			PRINT 'COMMIT TRANSACTION'
			COMMIT TRANSACTION
		END
	END TRY

	BEGIN CATCH
--		PRINT 'ROLLBACK TRANSACTION'

		SET @Status = 0
		ROLLBACK TRANSACTION

		/** CATCH THE ERROR DETAILS */
		SET @StatusMsg = 'Error'
					+ CHAR(13) + CHAR(10) + 'StartDate :' + CONVERT(nvarchar, @StatementStartDate, 121)
					+ CHAR(13) + CHAR(10) + 'EndDate : ' + CONVERT(nvarchar, GETDATE(), 121)
					+ CHAR(13) + CHAR(10);
		SET @StatusMsg = 'ErrorNumber    = ' + CAST(ERROR_NUMBER() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorSeverity  = ' + CAST(ERROR_SEVERITY() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorState     = ' + CAST(ERROR_STATE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorProcedure = ' + CAST(ERROR_PROCEDURE() AS nvarchar(max)) + CHAR(13) + CHAR(10) +
						'ErrorLine		= ' + CAST(ERROR_LINE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorMessage	= ' + CAST(ERROR_MESSAGE() AS nvarchar(max)) + CHAR(13) + CHAR(10)
	END CATCH	
END


GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Contribution_User_Calculation' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Contribution_User_Calculation]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Contribution_User_Calculation]    Script Date: 3/2/2015 6:36:29 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Contribution_User_Calculation]
(
	@OrgId INT
	,@UserId INT
	,@Dates VARCHAR(max)
	,@CurrentUser INT = null
	,@DivisionName VARCHAR(50) = null
	,@Market_Cluster VARCHAR(50) = null
	,@RegionName VARCHAR(50) = null
	,@Status INT OUT
	,@StatusMsg VARCHAR(MAX) OUT
)
AS
SET NOCOUNT ON
BEGIN
/*****************************************************/
/* Global variables declaration and initialization   */
/*                                           - Start */
/*****************************************************/

DECLARE @StoreId INT
		,@StatementStartDate datetime
		,@DateFrom DATETIME
		,@DateTo DATETIME
/*********** Test ***********************************/
--DECLARE @Status INT
--		,@StatusMsg VARCHAR(MAX)
/*********** Test ***********************************/

SELECT 
		@Status = 1
		,@StatusMsg = ''
		,@StatementStartDate = GETDATE()

/*****************************************************/
/* Global variables declaration and initialization   */
/*                                           - End   */
/*****************************************************/

BEGIN TRY
		BEGIN TRANSACTION

		/*****************************************************/
		/* For testing                               - Start */
		/*****************************************************/

		--DECLARE @OrgId INT
		--		,@UserId INT
		--		,@Dates VARCHAR(max)
		--		,@CurrentUser INT
		--		,@DivisionName VARCHAR(50)
		--		,@Market_Cluster VARCHAR(50)
		--		,@RegionName VARCHAR(50)

		----SET @Dates = '2013-12-01,2014-01-01,2014-02-01,2014-03-01,2014-04-01,2014-05-01,2014-06-01,2014-07-01'
		--SET @Dates = '2014-06-01,2014-07-01'

		--SELECT @OrgId = 8
		--		,@UserId = 492
		--		,@CurrentUser = null
		--		,@StoreId = null
		--		,@DivisionName = null
		--		,@Market_Cluster = null
		--		,@RegionName = null

		/*****************************************************/
		/* For testing                               - End   */
		/*****************************************************/

		/*****************************************************/
		/* Create a Period Table for selected months - Start */
		/*****************************************************/

		DECLARE @PeriodTable TABLE
		(
			Year INT,
			Month INT,
			FirstDay DATETIME,
			LastDay DATETIME,
			DaysInMonth INT,
			MonthNo INT
		)

		/*****************************************************/
		/* Create a Period Table for selected months - End   */
		/*****************************************************/

		/*****************************************************/
		/* Populate period table                     - Start */
		/*****************************************************/

		;WITH Dates_Cte
		AS
		(SELECT CAST(s_n.OutputValue AS DATETIME) AS Date
			FROM dbo.Spliter_New(@Dates,',') s_n
		)
		INSERT INTO  @PeriodTable(FirstDay, LastDay, DaysInMonth, Month, Year, MonthNo)
			SELECT 
					d_c.[Date] AS [FirstDay]
					--,DATEADD(mm, DATEDIFF(mm, 0, d_c.[Date]) + 1, -1) AS [LastDate]
					,DATEADD(ms, -3, DATEADD(mm, DATEDIFF(m, 0, d_c.[Date]) + 1, 0)) AS LastDay
					,DAY(DATEADD(d, -1, DATEADD(mm, DATEDIFF(m, 0, d_c.[Date]) + 1, 0))) AS [DaysInMonth]
					,DATEPART(mm, d_c.[Date]) AS [Month]
					,DATEPART(yy, d_c.[Date]) AS [Year]
					,DATEDIFF(mm, 0, d_c.[Date]) AS MonthNo
				FROM Dates_Cte d_c

		SELECT @DateFrom = MIN(pt.FirstDay)
				,@DateTo = CASE 
								WHEN DATEDIFF(mm, MAX(pt.LastDay), GETDATE()) = 0 THEN DATEADD(ms, -3, DATEADD(dd, DATEDIFF(dd, 0, GETDATE()) + 1, 0)) 
								ELSE MAX(pt.LastDay)
							END
				FROM @PeriodTable pt

		--SELECT * FROM @PeriodTable

		DECLARE @UsersTable TABLE
		(
			UserId INT,
			UserName VARCHAR(100),
			IsActive INT
		)

		DECLARE @UserContribution TABLE
		(
			Year INT,
			Month INT,
			Team INT,
			UserId	INT,
			UserName VARCHAR(100),
			VisitGoal INT,
			OutOfOffice INT,
			VisitGoalMTD NUMERIC(18,2),
			ActualVisits INT,
			Contribution INT,
			TotalVisitsLength INT
		)

		INSERT INTO @UsersTable (UserId, UserName, IsActive)
			SELECT DISTINCT ur_f.UserId, u.UserName, u.IsActive 
				FROM UserReporting_Function(@OrgId, @UserId) ur_f
					INNER JOIN Users u ON u.UserId = ur_f.UserId
					LEFT JOIN
						( 
						StoreUserMapping sump 
							INNER JOIN Store s ON s.StoreId = sump.StoreId AND s.OrgId = @OrgId
						)ON sump.UserId = ur_f.UserId
					WHERE 
						(@StoreId IS NULL OR s.StoreId = @StoreId)
						AND (@DivisionName IS NULL OR s.Store_Division = @DivisionName)
						AND (@Market_Cluster IS NULL OR s.store_market_cluster = @Market_Cluster)
						AND (@RegionName IS NULL OR s.MarketGroup = @RegionName)
						AND (@CurrentUser IS NULL 
											OR (@CurrentUser IS NOT NULL 
												AND (ur_f.UserId = @CurrentUser 
													OR ur_f.UserId = @UserId)))	

		/*****************************************************/
		/* Populate period table                     - End   */
		/*****************************************************/

		/*****************************************************/
		/* Current Month Variables                   - Start */
		/*****************************************************/
		DECLARE @CurrentDate DATETIME
				,@CurrentDay INT
				,@FirstDay INT
				,@DaysInCurrentMonth INT
				,@CurrentMonthNo INT
				,@CurrentYear INT
				,@CurrentMonth INT
				,@IsCurrentMonth tinyint

		/*****************************************************/
		/* Current Month Variables                   - End   */
		/*****************************************************/

		/*****************************************************/
		/* Current Month assignment                  - Start */
		/*****************************************************/

		--SET @CurrentDate = '2014-01-25 00:00:00.000'--, @IsCurrentMonth = 0

		SELECT @CurrentDate = CASE 
									WHEN DATEDIFF(mm, @DateTo, GETDATE()) =  0 THEN GETDATE()
									ELSE @DateTo
								END
				,@CurrentDay = DATEPART(dd, @CurrentDate)
				,@FirstDay = DAY(DATEADD(mm, DATEDIFF(m, 0, @CurrentDate), 0))
				,@DaysInCurrentMonth = DAY(DATEADD(d, -1, DATEADD(mm, DATEDIFF(m, 0, @CurrentDate) + 1, 0)))
				,@CurrentMonthNo = DATEDIFF(mm, 0, @CurrentDate)
				,@CurrentYear = DATEPART(yy, @CurrentDate)
				,@CurrentMonth = DATEPART(mm, @CurrentDate)
				,@IsCurrentMonth = CASE WHEN DATEDIFF(mm, @CurrentDate, GetDate()) = 0 THEN 1
										ELSE 0
									END

		/*****************************************************/
		/* Current Month assignment                  - End   */
		/*****************************************************/

		/*****************************************************/
		/* Test current Month assignment             - Start */
		/*****************************************************/

		--SELECT @CurrentDate AS CurrentDate
		--		,@CurrentYear AS CurrentYear
		--		,@CurrentMonth AS CurrentMonth
		--		,@FirstDay AS FirstDay
		--		,@DaysInCurrentMonth AS DaysInCurrentMonth
		--		,@CurrentDay AS CurrentDay
		--		,@CurrentMonthNo AS CurrentMonthNo
		--		,CASE @IsCurrentMonth 
		--			WHEN 0 THEN 'False'
		--			ELSE 'True'
		--		END AS IsCurrentMonth

		/*****************************************************/
		/* Test current Month assignment             - End   */
		/*****************************************************/

		/*****************************************************/
		/* Calculate contribution for current month  - Begin */
		/*****************************************************/

		IF(@IsCurrentMonth = 1)
		BEGIN

			;WITH CurentMonthContibution_CTE
			AS
			(
				SELECT	
						DATEPART(yy, @CurrentDate) AS Year
						,DATEPART(mm, @CurrentDate) AS Month
						,CASE WHEN u.UserId = @UserId THEN 0
							ELSE 1
						END AS Team
						,u.UserId
						,u.UserName
						,cusdo.StoreId
						,ROUND(
								cusdo.DaysInMonth * 1.00 /
									CASE cusdo.StoreVisitsCategory 
										WHEN 'Weekly'   THEN 7
										WHEN 'BiWeekly' THEN 14
										ELSE cusdo.DaysInMonth
									END *
								CASE Status WHEN 'Current' THEN (DaysInMonth - ISNULL(cusdo.NoOfOooDays, 0)) * 1.00 / DaysInMonth * StoreVisitRule
									ELSE 
										CASE 
											WHEN ISNULL(cusdo.NoOfOooDays, 0) >= StoreDays THEN 0
											ELSE ((cusdo.StoreDays - ISNULL(cusdo.NoOfOooDays, 0))* 1.00) / DaysInMonth * StoreVisitRule
										END
								END, 0
						) AS VisitGoal
						,ISNULL(cusdo.OutOfOfficeMTD, 0) AS OutOfOffice
						,ROUND(
							CAST(DaysInMonth AS NUMERIC(18,2)) * 1.00 /
								CASE StoreVisitsCategory 
									WHEN 'Weekly'   THEN 7.00
									WHEN 'BiWeekly' THEN 14.00
									ELSE CAST(DaysInMonth AS NUMERIC(18,2))
								END *
							CASE 
								WHEN Status = 'Current' THEN  
											CASE 
												WHEN ISNULL(cusdo.NoOfOooDays, 0) >= cusdo.StoreDaysMTD THEN 0.00
												ELSE CAST((cusdo.StoreDaysMTD -ISNULL(cusdo.NoOfOooDays, 0)) AS NUMERIC(18,2)) * 1.00 / CAST(cusdo.DaysInMonth AS NUMERIC(18,2)) *  CAST(cusdo.StoreVisitRule AS NUMERIC(18,2))
											END
								ELSE 
									CASE
										WHEN ISNULL(cusdo.NoOfOooDays, 0) >= DATEDIFF(dd, cusdo.StatusDate, @CurrentDate) THEN 0.00
										--ELSE ((DATEDIFF(dd, cusdo.StatusDate, @CurrentDate) - ISNULL(cusdo.NoOfOooDays, 0)) * 1.00) / cusdo.DaysInMonth * cusdo.StoreVisitRule
										ELSE (CAST((cusdo.StoreDaysMTD - ISNULL(cusdo.NoOfOooDays, 0)) AS NUMERIC(18,2)) * 1.00) / CAST(cusdo.DaysInMonth AS NUMERIC(18,2)) * CAST(cusdo.StoreVisitRule AS NUMERIC(18,2))
									END
							END, 2
						) AS VisitGoalMTD
						,cusdo.StartDate
						,cusdo.EndDate
					FROM UserReporting_Function(@OrgId, @UserId) ur_f
						INNER JOIN Users u ON u.UserId = ur_f.UserId
						LEFT JOIN ContributionUserStoreDetailOoo(@OrgId, @UserId, @CurrentDate, null, null, null, null) cusdo ON cusdo.UserId = u.UserId				
			),
			Store_CTE
			AS
			(
				SELECT cmc_c.Year
						,cmc_c.Month
						,cmc_c.Team
						,cmc_c.UserId
						,cmc_c.UserName
						,cmc_c.StoreId
						,SUM(cmc_c.VisitGoal) OVER (PARTITION BY cmc_c.Year, cmc_c.Month, cmc_c.UserId) AS VisitGoal
						,cmc_c.OutOfOffice AS OutOfOffice
						,SUM(cmc_c.VisitGoalMTD) OVER (PARTITION BY cmc_c.Year, cmc_c.Month, cmc_c.UserId) AS VisitGoalMTD
						,cmc_c.StartDate
						,cmc_c.EndDate
					FROM CurentMonthContibution_CTE cmc_c
			)
			INSERT INTO @UserContribution(Year, Month, Team, UserId, UserName, VisitGoal, OutOfOffice, VisitGoalMTD, ActualVisits, Contribution, TotalVisitsLength)
			SELECT 	s_c.Year
					,s_c.Month
					,s_c.Team
					,s_c.UserId
					,s_c.UserName
					,CAST(ISNULL(s_c.VisitGoal, 0) AS INT) VisitGoal
					,s_c.OutOfOffice
					,CAST(ISNULL(s_c.VisitGoalMTD, 0) AS NUMERIC(18,2)) VisitGoalMTD
					--,COUNT(fv.FormVisitId) AS ActualVisit /*Visits to his stores*/
					,COUNT(fv.FormVisitId) + ISNULL(oa_GroupVisit.[Visits], 0) AS ActualVisit
					,CAST(CASE 
							WHEN VisitGoalMTD = 0 THEN 0
							ELSE
								ISNULL(ROUND(
										(COUNT(fv.FormVisitId) + ISNULL(oa_GroupVisit.[Visits], 0)) * 100.00 / VisitGoalMTD
									, 0), 0) 
							END
						AS INT) AS Contribution
					--,SUM(fv.LengthOfVisitInMinutes) AS [TotalVisitsLength] /*Total visits length to his stores*/
					,ISNULL(SUM(fv.LengthOfVisitInMinutes), 0) + ISNULL(oa_GroupVisit.[TotalVisitsLength], 0) AS [TotalVisitsLength]
					--,oa_GroupVisit.UserId
					--,oa_GroupVisit.[Visits]
					--,oa_GroupVisit.[TotalVisitsLength]					
				FROM Store_CTE s_c
					LEFT JOIN FormVisit fv ON
												fv.UserId = s_c.UserId
												AND fv.StoreId = s_c.StoreId
												AND DATEDIFF(mm, fv.CreatedOn, @CurrentDate) = 0
												AND fv.CreatedOn >= s_c.StartDate 
												AND fv.CreatedOn <= s_c.EndDate
					OUTER APPLY
					(
						SELECT 
							fv.UserID
							,COUNT(fv.FormVisitId) AS [Visits]
							,SUM(fv.LengthOfVisitInMinutes) AS [TotalVisitsLength]  
							FROM FormVisit fv WITH (nolock) 
							WHERE fv.UserId = s_c.UserId
									AND DATEDIFF(mm, fv.CreatedOn, @CurrentDate) = 0
									AND fv.CreatedOn >= DATEADD(mm, DATEDIFF(m, 0, @CurrentDate), 0)
									AND fv.CreatedOn <= DATEADD(d, -1, DATEADD(mm, DATEDIFF(m, 0, @CurrentDate) + 1, 0))
									AND fv.UserOwnerId <> fv.UserId
							GROUP BY fv.UserId
					) oa_GroupVisit
				WHERE @IsCurrentMonth = 1 
				GROUP BY 
					s_c.Year
					,s_c.Month
					,s_c.Team
					,s_c.UserId
					,s_c.UserName
					,s_c.VisitGoal
					,s_c.OutOfOffice
					,s_c.VisitGoalMTD
					,oa_GroupVisit.UserId
					,oa_GroupVisit.[Visits]
					,oa_GroupVisit.[TotalVisitsLength]
				ORDER BY 
					s_c.Year
					,s_c.Month
					,s_c.UserName

		END

		/*****************************************************/
		/* Calculate contribution for current month  - End   */
		/*****************************************************/


		;WITH UserContribution_Cte
		AS
		(
			SELECT pt.Year
					,pt.Month
					,CASE WHEN ut.UserId = @UserId THEN 0
						ELSE 1
					END AS Team
					,ut.UserId
					,ut.UserName
					,ISNULL(oa_ch.VisitGoal, 0) AS VisitGoal
					,CASE 
						WHEN oa_ch.OutOfOffice IS NULL OR oa_ch.OutOfOffice = 0 THEN CAST(NULL AS INT)
						ELSE oa_ch.OutOfOffice
					END	AS OutOfOffice
					,ISNULL(oa_ch.VisitGoalMTD, 0) AS VisitGoalMTD
					,ISNULL(oa_ch.ActualVisits, 0) AS ActualVisits
					,CASE oa_ch.Contribution 
						WHEN 0 THEN CAST(NULL AS INT)
						ELSE oa_ch.Contribution
					END AS Contribution
					,CASE oa_ch.AverageVisitLenght 
						WHEN 0 THEN CAST(NULL AS INT)
						ELSE oa_ch.AverageVisitLenght
					END	AS TotalVisitsLength
	--			,ca_date.LastDay
				FROM 
					@PeriodTable pt
					CROSS JOIN @UsersTable ut
					OUTER APPLY 
					(	SELECT
								DATEPART(yy, ch.CreatedDate) AS Year
								,DATEPART(mm, ch.CreatedDate) AS Month
								,ch.UserId
								--,u.UserName
								,ch.VisitGoal
								,ch.OutOfOffice
								,ch.VisitGoalMTD
								,ch.ActualVisits
								,ch.Contribution
								,ch.AverageVisitLenght
							FROM 
								ContributionHistory ch 
									CROSS APPLY 
										(SELECT MAX(ch2.CreatedDate) AS LastDay
											FROM ContributionHistory ch2
												WHERE 
													DATEDIFF(mm, ch2.CreatedDate, pt.[FirstDay]) = 0
													AND ch2.UserId = ch.UserId
													AND ch2.OrgId = ch.OrgId
										) ca_date
								WHERE 
									DATEDIFF(mm, ch.CreatedDate, pt.[FirstDay]) = 0 
									AND ch.UserId = ut.UserId
									AND ch.CreatedDate = ca_date.LastDay 
									AND ch.OrgId = @OrgId
									
						) oa_ch
										
					WHERE 			
						ut.IsActive = 1
						AND DATEDIFF(mm, pt.[FirstDay], GETDATE()) > 0 
	
		)
		INSERT INTO @UserContribution(Year, Month, Team, UserId, UserName, VisitGoal, OutOfOffice, VisitGoalMTD, ActualVisits, Contribution, TotalVisitsLength)
		SELECT uc_c.Year
				,uc_c.Month
				,uc_c.Team
				,uc_c.UserId
				,uc_c.UserName
				,SUM(uc_c.VisitGoal) AS VisitGoal
				,ISNULL(SUM(uc_c.OutOfOffice), 0) AS OutOfOffice
				,SUM(uc_c.VisitGoalMTD) AS VisitGoalMTD
				,SUM(uc_c.ActualVisits) AS ActualVisits
				,ROUND((--CASE 
							--WHEN GROUPING(uc_c.UserId) = 0 AND GROUPING(uc_c.UserName) = 0 THEN ISNULL(AVG(uc_c.Contribution),0) 
							--ELSE 
								CASE 
									WHEN SUM(uc_c.VisitGoalMTD) = 0 THEN 0
									ELSE SUM(uc_c.ActualVisits) * 100.00/SUM(uc_c.VisitGoalMTD)
								--END
						END), 0) AS Contribution
				,SUM(uc_c.TotalVisitsLength) AS TotalVisitsLength
				--,GROUPING(uc_c.Year) AS YearGroupping
				--,GROUPING(uc_c.Month) AS MonthGroupping
				--,GROUPING(uc_c.Team) AS TeamGroupping
				--,GROUPING(uc_c.UserId) AS UserIdGroupping
				--,GROUPING(uc_c.UserName) AS UserNameGroupping
			FROM UserContribution_Cte uc_c
			GROUP BY
					uc_c.Year
					,uc_c.Month					
					,uc_c.Team
					,uc_c.UserId
					,uc_c.UserName
			--WITH ROLLUP
			--HAVING 1 = 1
			--		--GROUPING(uc_c.Year) = 0
			--		AND GROUPING(uc_c.Month) = 1
			--		AND GROUPING(uc_c.Team) = 1
			--		AND GROUPING(uc_c.UserId) = 1
			--		AND GROUPING(uc_c.UserName) = 1	
			--		OR
			--		(GROUPING(uc_c.Year) = 0
			--			AND GROUPING(uc_c.Month) = 0
			--			AND GROUPING(uc_c.Team) = 0
			--			AND GROUPING(uc_c.UserId) = 0
			--			AND GROUPING(uc_c.UserName) = 0)
			--		OR
			--		(GROUPING(uc_c.Year) = 0
			--			AND GROUPING(uc_c.Month) = 0
			--			AND GROUPING(uc_c.Team) = 0
			--			AND GROUPING(uc_c.UserId) = 1
			--			AND GROUPING(uc_c.UserName) = 1
			--			AND uc_c.Team = 1)
			ORDER BY 
					uc_c.Year
					,uc_c.Month
					,uc_c.UserName

		INSERT INTO  @UserContribution
			SELECT uc.Year
					,uc.Month
					,uc.Team
					,uc.UserId
					,uc.UserName
					,SUM(uc.VisitGoal) AS VisitGoal
					,SUM(uc.OutOfOffice) AS OutOfOffice
					,SUM(uc.VisitGoalMTD) AS VisitGoalMTD
					,SUM(uc.ActualVisits) AS ActualVisits
					,CASE 
						WHEN SUM(uc.VisitGoalMTD) = 0 THEN 0 
						ELSE ROUND(SUM(uc.ActualVisits) * 100.00 / SUM(uc.VisitGoalMTD), 0)
					END AS Contribution
					,SUM(uc.TotalVisitsLength) TotalVisitsLength
				FROM @UserContribution uc
				GROUP BY 
					uc.Year
					,uc.Month
					,uc.Team
					,uc.UserId
					,uc.UserName
				WITH ROLLUP
				HAVING 1 = 1
					AND GROUPING(uc.UserId) = 1
					AND GROUPING(uc.UserName) = 1
					AND
					(	
						(
							GROUPING(uc.Year) = 0
							AND GROUPING(uc.Month) = 0
							AND GROUPING(uc.Team) = 0
							AND uc.Team = 1
						)
						OR	
						(
							GROUPING(uc.Year) = 1
							AND GROUPING(uc.Month) = 1
							AND GROUPING(uc.Team) = 1
						)
						OR	
						(
							GROUPING(uc.Year) = 0
							AND GROUPING(uc.Month) = 1
							AND GROUPING(uc.Team) = 1
						)
					)
		SELECT 
				uc.Year
				,uc.Month
				--,uc.Team
				,uc.UserId
				,uc.UserName
				,uc.VisitGoal
				,uc.OutOfOffice
				,CAST(ROUND(uc.VisitGoalMTD,0) AS INT) AS VisitGoalMTD
				,uc.ActualVisits
				,uc.Contribution
				,uc.TotalVisitsLength
				--,uc.YearGroupping
				--,uc.MonthGroupping
				--,uc.TeamGroupping
				--,uc.UserIdGroupping
				--,uc.UserNameGroupping
			FROM @UserContribution uc
			--WHERE
			--	uc.UserId IS NOT NULL 
			--	AND uc.UserName IS NOT NULL
			ORDER BY 
				uc.Year DESC
				,uc.Month DESC
				,uc.UserName ASC

		/*****************************************************/
		/* Query for contribution                    - End   */
		/*****************************************************/

		IF @@trancount > 0
		BEGIN
--			PRINT 'COMMIT TRANSACTION'
			COMMIT TRANSACTION
		END
	END TRY

	BEGIN CATCH
--		PRINT 'ROLLBACK TRANSACTION'

		SET @Status = 0
		ROLLBACK TRANSACTION

		/** CATCH THE ERROR DETAILS */
		SET @StatusMsg = 'Error'
					+ CHAR(13) + CHAR(10) + 'StartDate :' + CONVERT(nvarchar, @StatementStartDate, 121)
					+ CHAR(13) + CHAR(10) + 'EndDate : ' + CONVERT(nvarchar, GETDATE(), 121)
					+ CHAR(13) + CHAR(10);
		SET @StatusMsg = 'ErrorNumber    = ' + CAST(ERROR_NUMBER() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorSeverity  = ' + CAST(ERROR_SEVERITY() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorState     = ' + CAST(ERROR_STATE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorProcedure = ' + CAST(ERROR_PROCEDURE() AS nvarchar(max)) + CHAR(13) + CHAR(10) +
						'ErrorLine		= ' + CAST(ERROR_LINE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorMessage	= ' + CAST(ERROR_MESSAGE() AS nvarchar(max)) + CHAR(13) + CHAR(10)
	END CATCH	
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Contribution_UserGroup_Calculation' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Contribution_UserGroup_Calculation]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Contribution_UserGroup_Calculation]    Script Date: 3/2/2015 6:36:30 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[Contribution_UserGroup_Calculation]
(
	@OrgId INT
	,@UserId INT
	,@Dates VARCHAR(max)
	,@CurrentUser INT = null
	,@DivisionName VARCHAR(50) = null
	,@Market_Cluster VARCHAR(50) = null
	,@RegionName VARCHAR(50) = null
	,@Status INT OUT
	,@StatusMsg VARCHAR(MAX) OUT
)
AS
SET NOCOUNT ON
BEGIN
/*****************************************************/
/* Global variables declaration and initialization   */
/*                                           - Start */
/*****************************************************/

DECLARE @StoreId INT
		,@StatementStartDate datetime
		,@DateFrom DATETIME
		,@DateTo DATETIME
/*********** Test ***********************************/
--DECLARE @Status INT
--		,@StatusMsg VARCHAR(MAX)
/*********** Test ***********************************/

SELECT 
		@Status = 1
		,@StatusMsg = ''
		,@StatementStartDate = GETDATE()

/*****************************************************/
/* Global variables declaration and initialization   */
/*                                           - End   */
/*****************************************************/

BEGIN TRY
		BEGIN TRANSACTION

		/*****************************************************/
		/* For testing                               - Start */
		/*****************************************************/

		--DECLARE @OrgId INT
		--		,@UserId INT
		--		,@Dates VARCHAR(max)
		--		,@CurrentUser INT
		--		,@DivisionName VARCHAR(50)
		--		,@Market_Cluster VARCHAR(50)
		--		,@RegionName VARCHAR(50)

		--SET @Dates = '2013-12-01,2014-01-01,2014-02-01,2014-03-01,2014-04-01,2014-05-01,2014-06-01,2014-07-01'
		----SET @Dates = '2014-01-01'

		--SELECT @OrgId = 4
		--		,@UserId = 6188
		--		,@CurrentUser = null
		--		,@StoreId = null
		--		,@DivisionName = null
		--		,@Market_Cluster = null
		--		,@RegionName = null

		/*****************************************************/
		/* For testing                               - End   */
		/*****************************************************/

		/*****************************************************/
		/* Create a Period Table for selected months - Start */
		/*****************************************************/

		DECLARE @PeriodTable TABLE
		(
			Year INT,
			Month INT,
			FirstDay DATETIME,
			LastDay DATETIME,
			DaysInMonth INT,
			MonthNo INT
		)

		/*****************************************************/
		/* Create a Period Table for selected months - End   */
		/*****************************************************/

		/*****************************************************/
		/* Populate period table                     - Start */
		/*****************************************************/

		;WITH Dates_Cte
		AS
		(SELECT CAST(s_n.OutputValue AS DATETIME) AS Date
			FROM dbo.Spliter_New(@Dates,',') s_n
		)
		INSERT INTO  @PeriodTable(FirstDay, LastDay, DaysInMonth, Month, Year, MonthNo)
			SELECT 
					d_c.[Date] AS [FirstDay]
					--,DATEADD(mm, DATEDIFF(mm, 0, d_c.[Date]) + 1, -1) AS [LastDate]
					,DATEADD(ms, -3, DATEADD(mm, DATEDIFF(m, 0, d_c.[Date]) + 1, 0)) AS LastDay
					,DAY(DATEADD(d, -1, DATEADD(mm, DATEDIFF(m, 0, d_c.[Date]) + 1, 0))) AS [DaysInMonth]
					,DATEPART(mm, d_c.[Date]) AS [Month]
					,DATEPART(yy, d_c.[Date]) AS [Year]
					,DATEDIFF(mm, 0, d_c.[Date]) AS MonthNo
				FROM Dates_Cte d_c

		SELECT @DateFrom = MIN(pt.FirstDay)
				,@DateTo = CASE 
								WHEN DATEDIFF(mm, MAX(pt.LastDay), GETDATE()) = 0 THEN GETDATE()
								ELSE MAX(pt.LastDay)
							END
				FROM @PeriodTable pt

		--SELECT * FROM @PeriodTable

		/*****************************************************/
		/* Populate period table                     - End   */
		/*****************************************************/

				/*****************************************************/
		/* Current Month Variables                   - Start */
		/*****************************************************/
		DECLARE @CurrentDate DATETIME
				,@CurrentDay INT
				,@FirstDay INT
				,@DaysInCurrentMonth INT
				,@CurrentMonthNo INT
				,@CurrentYear INT
				,@CurrentMonth INT
				,@IsCurrentMonth tinyint

		/*****************************************************/
		/* Current Month Variables                   - End   */
		/*****************************************************/

		/*****************************************************/
		/* Current Month assignment                  - Start */
		/*****************************************************/

		--SET @CurrentDate = '2014-01-25 00:00:00.000'--, @IsCurrentMonth = 0

		SELECT @CurrentDate = CASE 
									WHEN DATEDIFF(mm, @DateTo, GETDATE()) =  0 THEN GETDATE()
									ELSE @DateTo
								END
				,@CurrentDay = DATEPART(dd, @CurrentDate)
				,@FirstDay = DAY(DATEADD(mm, DATEDIFF(m, 0, @CurrentDate), 0))
				,@DaysInCurrentMonth = DAY(DATEADD(d, -1, DATEADD(mm, DATEDIFF(m, 0, @CurrentDate) + 1, 0)))
				,@CurrentMonthNo = DATEDIFF(mm, 0, @CurrentDate)
				,@CurrentYear = DATEPART(yy, @CurrentDate)
				,@CurrentMonth = DATEPART(mm, @CurrentDate)
				,@IsCurrentMonth = CASE WHEN DATEDIFF(mm, @CurrentDate, GetDate()) = 0 THEN 1
										ELSE 0
									END

		/*****************************************************/
		/* Current Month assignment                  - End   */
		/*****************************************************/

		;WITH UserContribution_Cte
		AS
		(
			SELECT pt.Year
					,pt.Month
					,u.UserName
					,u.UserId
					,oa_ch.StoreName
					,oa_ch.StoreId
					,oa_ch.AssignedTo
					,oa_ch.Visits
					,oa_ch.TotalVisitLength
				FROM 
					@PeriodTable pt
					CROSS JOIN UserReporting_Function(@OrgId, @UserId) ur_f
					INNER JOIN Users u ON u.UserId = ur_f.UserId
					CROSS APPLY 
					(	SELECT
								DATEPART(yy, CONVERT(DATETIME, '01/'+ gvh.Month, 103)) AS Year
								,DATEPART(mm, CONVERT(DATETIME, '01/'+ gvh.Month, 103)) AS Month
								,gvh.UserId
								,gvh.StoreId
								,gvh.storeName AS StoreName
								,gvh.assignedTo AS AssignedTo
								,gvh.visits AS Visits
								,gvh.totalVisitLength AS TotalVisitLength
							FROM 
								GroupVisitHistory gvh
									INNER JOIN Store s ON gvh.StoreId = s.StoreId 									
								WHERE 
									--DATEDIFF(mm, ch.CreatedDate, pt.[FirstDay]) = 0 
									gvh.UserId = ur_f.UserId
									AND DATEDIFF(mm, CONVERT(DATETIME, '01/'+ gvh.Month, 103), pt.[FirstDay]) = 0
									AND gvh.OrgId = @OrgId
									AND s.OrgId = @OrgId						
									AND (@StoreId IS NULL OR s.StoreId = @StoreId)
									AND (@DivisionName IS NULL OR s.Store_Division = @DivisionName)
									AND (@Market_Cluster IS NULL OR s.store_market_cluster = @Market_Cluster)
									AND (@RegionName IS NULL OR s.MarketGroup = @RegionName)
									
						) oa_ch
										
					WHERE 			
						u.IsActive = 1
						AND (@CurrentUser IS NULL 
											OR (@CurrentUser IS NOT NULL 
												AND (u.UserId = @CurrentUser 
													OR u.UserId = @UserId)))
			UNION ALL
			/*****************************************************/
			/* Current Month query                               */
			/*****************************************************/
			SELECT DATEPART(yy, @CurrentDate) AS Year
					,DATEPART(mm, @CurrentDate) AS Month
					,u_visitor.UserName
					,fv.UserId
					,s.StoreName
					,s.StoreId
					,u_owner.FullName AS AssignedTo
					,COUNT(fv.FormVisitId) AS [Visits]
					,SUM(fv.LengthOfVisitInMinutes) AS [TotalVisitsLength]  
				FROM UserReporting_Function(@OrgId,@UserId) ur_f
					INNER JOIN FormVisit fv WITH (nolock) ON fv.UserId = ur_f.UserId 
																		AND DATEDIFF(mm, fv.CreatedOn, @CurrentDate) = 0
																		AND fv.CreatedOn >= DATEADD(mm, DATEDIFF(m, 0, @CurrentDate), 0)
																		AND fv.CreatedOn <= DATEADD(d, -1, DATEADD(mm, DATEDIFF(m, 0, @CurrentDate) + 1, 0))
																		AND fv.UserOwnerId <> fv.UserId
					INNER JOIN Users u_visitor WITH (nolock) ON u_visitor.UserId = fv.UserId
					INNER JOIN Users u_owner WITH (nolock) ON u_owner.UserId = fv.UserOwnerId
					INNER JOIN Store s WITH (nolock) ON s.StoreId = fv.StoreId
				WHERE 
					@IsCurrentMonth = 1
				GROUP BY 
					fv.UserId
					,u_visitor.UserName
					,s.StoreName
					,s.StoreId
					,u_owner.FullName	
		)
		SELECT uc_c.Year
				,uc_c.Month
				,uc_c.UserId AS UserId
				,uc_c.UserName AS UserName
				,uc_c.StoreName AS StoreName
				,uc_c.StoreId AS StoreId
				,uc_c.AssignedTo AS AssignTo
				,uc_c.Visits AS Visits
				,uc_c.TotalVisitLength AS TotalVisitsLength
			FROM UserContribution_Cte uc_c
			ORDER BY 
					uc_c.Year
					,uc_c.Month
					,uc_c.UserName


		/*****************************************************/
		/* Query for contribution                    - End   */
		/*****************************************************/

		IF @@trancount > 0
		BEGIN
--			PRINT 'COMMIT TRANSACTION'
			COMMIT TRANSACTION
		END
	END TRY

	BEGIN CATCH
--		PRINT 'ROLLBACK TRANSACTION'

		SET @Status = 0
		ROLLBACK TRANSACTION

		/** CATCH THE ERROR DETAILS */
		SET @StatusMsg = 'Error'
					+ CHAR(13) + CHAR(10) + 'StartDate :' + CONVERT(nvarchar, @StatementStartDate, 121)
					+ CHAR(13) + CHAR(10) + 'EndDate : ' + CONVERT(nvarchar, GETDATE(), 121)
					+ CHAR(13) + CHAR(10);
		SET @StatusMsg = 'ErrorNumber    = ' + CAST(ERROR_NUMBER() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorSeverity  = ' + CAST(ERROR_SEVERITY() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorState     = ' + CAST(ERROR_STATE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorProcedure = ' + CAST(ERROR_PROCEDURE() AS nvarchar(max)) + CHAR(13) + CHAR(10) +
						'ErrorLine		= ' + CAST(ERROR_LINE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorMessage	= ' + CAST(ERROR_MESSAGE() AS nvarchar(max)) + CHAR(13) + CHAR(10)
	END CATCH	
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Dashboard_GetAlertsForStoreVisit' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Dashboard_GetAlertsForStoreVisit]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Dashboard_GetAlertsForStoreVisit]    Script Date: 3/2/2015 6:36:31 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- EXEC [Dashboard_GetAlertsForStoreVisit]  '5', '5112'

CREATE PROCEDURE [dbo].[Dashboard_GetAlertsForStoreVisit]
(	
	@pOrgId		 VARCHAR(50),
	@pUserId	 VARCHAR(20)	
)

AS
SET NOCOUNT ON
BEGIN
		SELECT	STOREVISITID, CREATEMAILFLAG, STORENAME,CERTIFIEDSTORENICKNAME 
		FROM	STOREVISIT SV, USERS US, STORE ST, ACCOUNT AC
		WHERE	CREATEMAILFLAG='TRUE'  
				AND US.USERID=@pUserId  
				AND US.USERID=SV.USERID 
				AND CONVERT(VARCHAR(10),SV.CREATEDON,120) IN  
				(
					SELECT DISTINCT CONVERT(VARCHAR(10),SV.CREATEDON,120) 
					FROM	STOREVISIT 
					WHERE	(SV.CREATEDON > GETDATE()-1 AND SV.CREATEDON<=GETDATE()+3)
				)  
				AND AC.ACCOUNTID=ST.ACCOUNTID 
				AND AC.ISACTIVE=1 
				AND SV.STOREID=ST.STOREID 
				AND ST.ISACTIVE=1
				AND ST.OrgId=@pOrgId
		ORDER BY SV.CREATEDON DESC
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Dashboard_GetAlertsForTasks' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Dashboard_GetAlertsForTasks]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Dashboard_GetAlertsForTasks]    Script Date: 3/2/2015 6:36:32 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- EXEC [Dashboard_GetAlertsForTasks] '5', '1'

CREATE PROCEDURE [dbo].[Dashboard_GetAlertsForTasks]
(	
	@pOrgId		 VARCHAR(50),
	@pUserId	 VARCHAR(20)	
)

AS
SET NOCOUNT ON
BEGIN

		SELECT USERID AS ASSIGNEDTO, MAILSENTTIME, TASKID, MAILSENTFLAG, TITLE, CREATEMAILFLAG 
		FROM   TASK 
		WHERE  ISACTIVE=1 
			   AND CREATEMAILFLAG='TRUE' 
			   AND USERID=@pUserId 
			   AND OrgId=@pOrgId
			   AND CONVERT(VARCHAR(10),CREATEDON,120) IN 
			   (
					SELECT DISTINCT CONVERT(VARCHAR(10),CREATEDON,120)
					FROM TASK 
					WHERE (CREATEDON > GETDATE()-1 AND CREATEDON<=GETDATE()+3)
			   )
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Dashboard_GetStoreVisit' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Dashboard_GetStoreVisit]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Dashboard_GetStoreVisit]    Script Date: 3/2/2015 6:36:32 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- EXEC [Dashboard_GetStoreVisit]  '5', '5112'

CREATE PROCEDURE [dbo].[Dashboard_GetStoreVisit]
(	
	@pOrgId		 VARCHAR(50),
	@pUserId	 VARCHAR(20)	
)

AS
SET NOCOUNT ON
BEGIN
	
		SELECT DISTINCT ST.STOREID, ST.STORENAME, ST.CERTIFIEDSTORENICKNAME, ST.STORENUMBER 
        FROM STOREVISIT SV 
			   INNER JOIN STORE ST ON ST.STOREID = SV.STOREID 
			   INNER JOIN USERS U ON U.USERID = SV.USERID 
			   INNER JOIN ACCOUNT AC ON AC.ACCOUNTID=ST.ACCOUNTID 
			   AND AC.ISACTIVE=1 AND ST.ISACTIVE=1
		WHERE (SV.DATE>GETDATE()-1 AND SV.DATE<=GETDATE()+3) 
			   AND ST.ISACTIVE=1 
               AND U.USERID=@pUserId
               AND ST.OrgId=@pOrgId
			   ORDER BY ST.STORENAME 

END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Dashboard_GetTaskList' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Dashboard_GetTaskList]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Dashboard_GetTaskList]    Script Date: 3/2/2015 6:36:33 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- EXEC [Dashboard_GetTaskList]  '1', '5112'

CREATE PROCEDURE [dbo].[Dashboard_GetTaskList]
(	
	@pOrgId		 VARCHAR(50),
	@pUserId	 VARCHAR(20)	
)

AS
SET NOCOUNT ON
BEGIN
		SELECT TASKID, TITLE 
        FROM TASK
		WHERE ISACTIVE=1 
			  AND USERID=@pUserId
			  AND (CONVERT(VARCHAR(20),STARTDATE,110) BETWEEN CONVERT(VARCHAR(20),GETDATE()-1,110) 
		      AND CONVERT(VARCHAR(20),GETDATE()+3,110)) 
              AND OrgId=@pOrgId
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DateCondition_Supporter' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DateCondition_Supporter]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DateCondition_Supporter]    Script Date: 3/2/2015 6:36:34 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =================================================================================================
-- Author:		<Palani G>
-- Create date: <Oct-7-2010>
-- Description:	<DateCondition_Supporter SP to generate the date condtion for compliance reports>
-- =================================================================================================


-- EXEC DateCondition_Supporter 'July 2010','','',''
-- EXEC DateCondition_Supporter 'January 2011, December 2010, November 2010, September 2010', '','',''
-- EXEC DateCondition_Supporter 'September 2010, October 2010', '','',''

CREATE PROCEDURE [dbo].[DateCondition_Supporter](
	@pMonthYear VARCHAR(500),
	@DateWhereCondtion VARCHAR(MAX) OUT,
	@MonthCount INT OUT,
	@DateSelection VARCHAR(500) OUT
	--@MonthYearNumber VARCHAR(1000) OUT
)
AS
SET NOCOUNT ON
BEGIN


--DROP TABLE #monthYearList
DECLARE @monthYear VARCHAR(1000)
SET @monthYear = @pMonthYear
--SET @monthYear = 'September 2010, October 2010, November 2010'
DECLARE @monthYearList varchar(500)
DECLARE @monthYearId varchar(20), @Pos int, @countId int, @CommaCount int, @countDescendingId int

SELECT @CommaCount = count(*) FROM [dbo].Spliter(@monthYear,',')

SET @CommaCount = @CommaCount-1

--SELECT @CommaCount
SET @countId = -1
SET @countDescendingId = +1

CREATE TABLE #monthYearList
	(
		Id int,
		DescendingId int,
		MonthYear VARCHAR(50),
		FromDate VARCHAR(50),
		ToDate VARCHAR(50),
	)
	SET @monthYearList = LTRIM(RTRIM(@monthYear))+ ','

	IF @CommaCount = 0
	BEGIN
		SELECT @Pos = CAST(LEN(@monthYear) AS INT )+1
	END
	ELSE
	BEGIN
		SET @Pos = CHARINDEX(',', @monthYear, 1)
	END
	--print 'position-->'+str(@Pos)
	
	IF REPLACE(@monthYearList, ',', '') <> ''
	BEGIN
		SET @countDescendingId= 0
		WHILE @Pos > 0
		BEGIN
			SET @countId=@CommaCount
			SET @monthYearId = LTRIM(RTRIM(LEFT(@monthYearList, @Pos - 1)))
			IF @monthYearId <> ''
			BEGIN
				INSERT INTO #monthYearList (Id, DescendingId, MonthYear, FromDate, ToDate) 
				VALUES (@countId, @countDescendingId, CAST(@monthYearId AS VARCHAR(50)), 
						dateadd(m, datediff(m, 0, dateadd(mm,0,@monthYearId)),0),
						dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,@monthYearId)), 0))) 
			END
			SET @monthYearList = RIGHT(@monthYearList, LEN(@monthYearList) - @Pos)
			SET @Pos = CHARINDEX(',', @monthYearList, 1)
			SET @CommaCount = (@CommaCount-1)
			SET @countDescendingId = @countDescendingId + 1
		END
	END	

	-- SELECT * FROM #monthYearList


DECLARE @strColNames VARCHAR(1000)
DECLARE @strMonthYear VARCHAR(1000)
DECLARE @pNofMonths int
--DECLARE @strMonthYearNumber VARCHAR(1000)

	SELECT @pNofMonths = count(*) FROM #monthYearList
	--PRINT 'No of months ->'+STR(@pNofMonths)
	DECLARE @i int
	SET @strMonthYear = ''
	--SET @strMonthYearNumber = ''
	SET @strColNames=''
	SET @i=1
	While @i<=@pNofMonths
	BEGIN
		IF @i < 2
		SELECT @strColNames = @strColNames+'([date] between  '''+convert(varchar(100),dateadd(m, datediff(m, 0, dateadd(mm,0,FromDate)),0))+''''+
						' AND '''+convert(varchar(100),dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,ToDate)), 0)))+''' )',
		--@strMonthYearNumber = @strMonthYearNumber+MonthYear+LTRIM(str(DescendingId))+', ',
		--@strMonthYear = @strMonthYear+' '''+MonthYear+''' as Month'+cast(id as varchar(2))+', '
		@strMonthYear = @strMonthYear+' '''+MonthYear+''' as Month'+cast(DescendingId as varchar(2))+', '
 		FROM #monthYearList order by MonthYear --desc

	SET @i=@i+1
	--PRINT '  @i->'+STR(@i)
	END



SELECT @DateWhereCondtion = REPLACE(@strColNames,')(','OR ')
SELECT @MonthCount = COUNT(*) FROM #monthYearList
SELECT @DateSelection = @strMonthYear
--SELECT @MonthYearNumber = @strMonthYearNumber

--SELECT @DateWhereCondtion AS DateWhereCondition
--SELECT @MonthCount AS MonthCount
--SELECT @DateSelection AS DateSelection


----SELECT @strMonthYearNumber AS MonthYearNumber

END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DateCondition_Supporter_MyCompliance' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DateCondition_Supporter_MyCompliance]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DateCondition_Supporter_MyCompliance]    Script Date: 3/2/2015 6:36:35 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ===============================================================================================================
-- Author:		<Palani G>
-- Create date: <Nov-23-2010>
-- Description:	<DateCondition_Supporter_MyCompliance SP to generate the date condtion for my compliance reports>
-- ===============================================================================================================

-- EXEC [DateCondition_Supporter_MyCompliance] 'July 2010, January 2010, March 2010, Aug 2010, September 2010'
-- EXEC [DateCondition_Supporter_MyCompliance] 'September 2010, October 2010' 
-- EXEC [DateCondition_Supporter_MyCompliance] 'July 2010' 
-- Exec [Reports_Supporter_ActionParameter] 'MY_COMPLIANCE_MAIN_REPORT',4

CREATE PROCEDURE [dbo].[DateCondition_Supporter_MyCompliance](
	@pMonthYear VARCHAR(500)
)
AS
SEt NOCOUNT ON
BEGIN


DECLARE @monthYear VARCHAR(1000)
SET @monthYear = @pMonthYear
--SET @monthYear = 'September 2010, October 2010, November 2010'
DECLARE @monthYearList varchar(500)
DECLARE @monthYearId varchar(20), @Pos int, @countId int, @CommaCount int

SELECT @CommaCount = count(*) FROM [dbo].Spliter(@monthYear,',')

SET @CommaCount = @CommaCount-1

--SELECT @CommaCount
SET @countId = -1

CREATE TABLE #monthYearList
	(
		[Month] DATETIME
	)
	SET @monthYearList = LTRIM(RTRIM(@monthYear))+ ','

	IF @CommaCount = 0
	BEGIN
		SELECT @Pos = CAST(LEN(@monthYear) AS INT )+1
	END
	ELSE
	BEGIN
		SET @Pos = CHARINDEX(',', @monthYear, 1)
	END

	IF REPLACE(@monthYearList, ',', '') <> ''
	BEGIN
		WHILE @Pos > 0
		BEGIN
			SET @countId=@CommaCount
			SET @monthYearId = LTRIM(RTRIM(LEFT(@monthYearList, @Pos - 1)))
			IF @monthYearId <> ''
			BEGIN
				INSERT INTO #monthYearList ([Month]) 
				VALUES (CAST(@monthYearId AS VARCHAR(50)))
			END
			SET @monthYearList = RIGHT(@monthYearList, LEN(@monthYearList) - @Pos)
			SET @Pos = CHARINDEX(',', @monthYearList, 1)
			SET @CommaCount = (@CommaCount-1)
		END
	END	

	--SELECT (convert(varchar(10),[Month],121)) AS [Month] FROM #monthYearList order by [Month] desc
	SELECT (convert(varchar(10),[Month],121)) AS [Month], DATENAME(MM, [Month]) + ' ' + CAST(YEAR([Month]) AS VARCHAR(4)) AS [MonthYear]  FROM #monthYearList order by [Month] desc
--

END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DhtmlCalendarModule' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DhtmlCalendarModule]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DhtmlCalendarModule]    Script Date: 3/2/2015 6:36:36 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

;
/*
	===========================================================================
	Based on the review conducted for Users Revamp, the following requirements
	where deducted:

	The SP is an utility "factotum" stored procedure, with the following behaviour
	depending on the @pActionType parameter:

	- GetAccountName will return a list of the accounts in which @pUserOrGroupId
	has assigned stores, in @pOrgId;

	- GetStoreNameForUser will return the list of assigned stores for the user
	@pUserOrGroupId with their associated accounts, from @pOrgId;

	- GetStoreName will return the list of assigned stores for the user
	@pUserOrGroupId with their associated accounts, from @pOrgId, filtered by
	@pAccountId;

	- in case of GetAccountName, GetStoreNameForUser, GetStoreName we will test
	the permissions of @ploginUserId in order to display CertifiedStoreNickName

	- GetDownLineUsers: return the downline of @pUserOrGroupId from @pOrgId, but
	only the ones who can "Modify Calendar and Receive Calendar Alerts"
	Modification: This only returns users who are active (10/01/2014)
	

	TestCase
	---------------------------------------------------------------------------
	EXEC [DhtmlCalendarModule] 'GetAccountName', 18, 6528
	EXEC [DhtmlCalendarModule] 'GetEventType', 18
	
	Utils to search for proper test cases:
	---------------------------------------------------------------------------

	===========================================================================
*/
CREATE PROCEDURE [dbo].[DhtmlCalendarModule](   
	 @pActionType		varchar(50)  
	,@pOrgId			int  
	,@pUserOrGroupId	int = NULL 
	,@pAccountId		int = NULL
	,@ploginUserId		int = NULL
)  
AS
SET NOCOUNT ON
BEGIN
	IF @pActionType = 'GetAccountName'
		BEGIN
			SELECT DISTINCT
				 a.AccountName
				,a.AccountId
			FROM Account a WITH (NOLOCK)
				INNER JOIN Store s WITH (NOLOCK) ON s.AccountId = a.AccountId AND s.OrgId = @POrgId
				INNER JOIN StoreUserMapping stum WITH (NOLOCK) ON stum.StoreId = s.StoreId AND stum.UserId = @pUserOrGroupId
			WHERE 1 = 1
				AND a.IsActive = 1
				AND s.IsActive = 1
			ORDER BY
				a.AccountName
			;
		END
	ELSE IF @pActionType = 'GetStoreName' OR  @pActionType = 'GetStoreNameForUser' OR @pActionType = 'GetStoreNameForGroup'
		BEGIN
			WITH GroupUsers_CTE AS (
				SELECT
					gm.UserId
				FROM GroupMembership gm WITH (NOLOCK)
				WHERE 1 = 1
					AND gm.GroupId = @pUserOrGroupId
					AND gm.IsActive = 1
			)
			SELECT
				 s.StoreId
				,s.StoreName
				,CertifiedStoreNickName =	CASE
											-- If the user has permission to see the certified store name (own - 140, downline's - 106)
											WHEN (@ploginUserId  = stum.UserId AND dbo.PermissionCheck(@pOrgId, @ploginUserId, 140) = 1)
											  OR (@ploginUserId != stum.UserId AND dbo.PermissionCheck(@pOrgId, @ploginUserId, 106) = 1) THEN
												CASE
													WHEN s.CertifiedStoreNickName IS NULL 
														OR LTRIM(RTRIM(s.CertifiedStoreNickName)) = ''
														OR LTRIM(RTRIM(s.CertifiedStoreNickName)) = 'null' THEN s.StoreName
													ELSE s.CertifiedStoreNickName
												END
											-- No permission
											ELSE s.StoreName
										END
				,a.AccountId
				,a.AccountName
			FROM Account a WITH (NOLOCK)
				INNER JOIN Store s WITH (NOLOCK) ON s.AccountId = a.AccountId AND s.OrgId = @POrgId
				INNER JOIN StoreUserMapping stum WITH (NOLOCK) ON stum.StoreId = s.StoreId
					LEFT JOIN GroupUsers_CTE gu ON gu.UserId = stum.UserId
			WHERE 1 = 1
				AND a.IsActive = 1
				AND s.IsActive = 1
				AND CASE @pActionType
						--
						WHEN 'GetStoreName' THEN
							CASE WHEN a.AccountId = @pAccountId AND stum.UserId = @pUserOrGroupId THEN 1 ELSE 0 END
						--
						WHEN 'GetStoreNameForUser' THEN
							CASE WHEN stum.UserId = @pUserOrGroupId THEN 1 ELSE 0 END
						--
						WHEN 'GetStoreNameForGroup' THEN
							CASE WHEN gu.UserId IS NOT NULL THEN 1 ELSE 0 END
						-- Default filter out
						ELSE 0
					END = 1
			ORDER BY
				CertifiedStoreNickName
			;
		END
	ELSE IF @pActionType = 'GetDownLineUsers'
		BEGIN
			SELECT
				 u.FullName
				,u.UserId
				,u.UserName
			FROM UserReporting_Function(@pOrgId, @pUserOrGroupId) urf
				INNER JOIN Users u WITH (NOLOCK) ON urf.UserID = u.UserId
				INNER JOIN Privileges p WITH (NOLOCK) ON urf.BusinessRoleID = p.BusinessRoleID
			WHERE 1 = 1
				AND urf.UserID != @pUserOrGroupId
				AND urf.BusinessRoleType = 8		-- Hierarchical roles only
				AND p.PermissionId = 26				-- Modify Calendar and Receive Calendar Alerts
				AND u.isActive = 1					-- This only returns users who are active
			ORDER BY
				u.FullName
			;
		END
	ELSE IF @pActionType = 'GetEventType'
		BEGIN
			SELECT
				 svet.StoreVisitEventTypeId
				,svet.EventType
				,svet.isActive
				,svet.EventColorCode
			FROM StoreVisitEventType svet WITH (NOLOCK)
			WHERE 1 = 1
				AND svet.OrgId = @pOrgId
				AND svet.EventIsActive = 1
			ORDER BY
				svet.priority
			;
		END
	;
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DynamicForm_Builder' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DynamicForm_Builder]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DynamicForm_Builder]    Script Date: 3/2/2015 6:36:36 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--EXEC [DynamicForm_Builder] '11', 'FIELD_LIST', '1214', null, null, null
--EXEC [DynamicForm_Builder] '11', 'FIELD_LIST', '945', null, null, null
--exec [DynamicForm_Builder] '7', 'AVAILABLE_FORM_LIST_FOR_DROP_DOWN', '4591', null, null, null

CREATE PROCEDURE [dbo].[DynamicForm_Builder] (
	 @P_OrgId VARCHAR(20)
	,@P_Form_Type VARCHAR(50)
	,@P_Id VARCHAR(MAX)
	,@P_NextId VARCHAR(MAX)
	,@P_Other_1 VARCHAR(500) = ''
	,@P_Other_2 VARCHAR(500) = ''
	)
AS
SET NOCOUNT ON
BEGIN
	SET NOCOUNT ON

	DECLARE @SalesStageWithDate VARCHAR(MAX)
	DECLARE @PriorVisitDate VARCHAR(10)

	SET @SalesStageWithDate = ''

	IF @P_Form_Type = 'ADHOC_FORM_LIST'
	BEGIN
			;WITH FormLevelMap_CTE
			AS
			(
				SELECT --DISTINCT 
					f.FormId
					,f.FormName
					,f.IsTimeStamp
					,f.IsGeoValidation
					,f.IsStoreStamp
					,f.OrgId
					,flm.BusinessRoleID
					,flm.OrgLevelMapId
					,flm.AccountId
				FROM Forms f WITH (nolock) 
					INNER JOIN FormLevelMap flm WITH (nolock)  ON flm.FormId = f.FormId
				WHERE 
					f.IsActive = 1 AND
					f.LeadFlag = 0 AND
					f.OrgId = @P_OrgId AND
					/** Hide old form(Wired, Wireless, Wired & Wireless) for submit from device */
					f.VisitAllowFlag = 1 AND
					/** for show adhoc form only */
					f.IsStoreStamp = 0
			),
			flmHierarchy_CTE
			AS
			(
				SELECT	
						flm_c.FormId,
						uop.UserId
					FROM FormLevelMap_CTE flm_c
						INNER JOIN UserOrgProfile uop WITH (nolock) ON uop.OrgId = flm_c.OrgId 
																		AND uop.BusinessRoleID = flm_c.BusinessRoleID 
																		AND flm_c.OrgLevelMapId IS NULL 
																		AND flm_c.AccountId IS NULL
					WHERE 
						uop.UserId = @P_Id
			)
			SELECT DISTINCT 
					flm_c.FormId
					,flm_c.FormName
					,flm_c.IsTimeStamp
					,flm_c.IsGeoValidation
					,flm_c.IsStoreStamp
				FROM flmHierarchy_CTE fh_c
					INNER JOIN FormLevelMap_CTE flm_c ON flm_c.FormId = fh_c.FormId 
															AND flm_c.BusinessRoleID IS NULL 
															AND flm_c.AccountId IS NULL
					INNER JOIN DivisionRegion dr WITH (nolock)  ON dr.OrgLevelMapId = flm_c.OrgLevelMapId AND dr.OrgId = flm_c.OrgId
					INNER JOIN UserDivisionRegionMapping udrm WITH (nolock)  ON udrm.DivisionRegionId = dr.DivisionRegionId AND udrm.UserId = fh_c.UserId
	END
	ELSE IF @P_Form_Type = 'ADHOC_FORM_LIST_FOR_DROP_DOWN'
	BEGIN
		/** Get All the forms based on permission */
		SELECT 
			f.FormId
			,f.FormName
			,f.IsTimeStamp
			,f.IsGeoValidation --, IsStoreStamp  
		FROM Forms f
		WHERE f.IsActive = 1 AND
				f.LeadFlag = 0 AND
				/** Hide old form(Wired, Wireless, Wired & Wireless) for submit from device */
				f.VisitAllowFlag = 1 AND
				/** for show adhoc form only */
				f.IsStoreStamp = 0 AND
				f.OrgId = @P_OrgId
		ORDER BY f.FormName
	END
	ELSE IF @P_Form_Type = 'VISIT_ALLOW_FORM_LIST'
	BEGIN
		/** Get All the forms based on permission */
			;WITH FormLevelMap_CTE
			AS
			(
				SELECT --DISTINCT 
					f.FormId
					,f.FormName
					,f.IsTimeStamp
					,f.IsGeoValidation
					,f.IsStoreStamp
					,f.OrgId
					,flm.BusinessRoleID
					,flm.OrgLevelMapId
					,flm.AccountId
				FROM Forms f WITH (nolock) 
					INNER JOIN FormLevelMap flm WITH (nolock)  ON flm.FormId = f.FormId
				WHERE 
					f.IsActive = 1 AND
					f.LeadFlag = 0 AND
					f.OrgId = @P_OrgId AND
					/** Hide old form(Wired, Wireless, Wired & Wireless) for submit from device */
					f.VisitAllowFlag = 1 AND
					/** for show adhoc form only */
					f.IsStoreStamp = 1
			),
			flmHierarchy_CTE
			AS
			(
				SELECT	
						flm_c.FormId,
						uop.UserId
					FROM FormLevelMap_CTE flm_c
						INNER JOIN UserOrgProfile uop WITH (nolock) ON uop.OrgId = flm_c.OrgId 
																		AND uop.BusinessRoleID = flm_c.BusinessRoleID 
																		AND flm_c.OrgLevelMapId IS NULL 
																		AND flm_c.AccountId IS NULL
					WHERE 
						uop.UserId = @P_Id
			),
			flmOrganization_CTE
			AS
			(
				SELECT 
						flm_c.FormId
					FROM flmHierarchy_CTE fh_c
						INNER JOIN FormLevelMap_CTE flm_c ON flm_c.FormId = fh_c.FormId 
																AND flm_c.BusinessRoleID IS NULL 
																AND flm_c.AccountId IS NULL
						INNER JOIN DivisionRegion dr WITH (nolock)  ON dr.OrgLevelMapId = flm_c.OrgLevelMapId AND dr.OrgId = flm_c.OrgId
						INNER JOIN UserDivisionRegionMapping udrm WITH (nolock)  ON udrm.DivisionRegionId = dr.DivisionRegionId AND udrm.UserId = fh_c.UserId
			)
			SELECT DISTINCT 
					flm_c.FormId
					,flm_c.FormName
					,flm_c.IsTimeStamp
					,flm_c.IsGeoValidation
					,flm_c.IsStoreStamp
				FROM flmOrganization_CTE fo_c
					INNER JOIN FormLevelMap_CTE flm_c ON flm_c.FormId = fo_c.FormId 
															AND flm_c.BusinessRoleID IS NULL 
															AND flm_c.OrgLevelMapId IS NULL 
					INNER JOIN Store s WITH (nolock) ON s.AccountId = flm_c.AccountId AND s.OrgId = flm_c.OrgId
				WHERE 
					s.StoreId = @P_NextId
	END
	ELSE IF @P_Form_Type = 'AVAILABLE_FORM_LIST_FOR_DROP_DOWN'
	BEGIN
			/** Get All the forms based on permission */
			SELECT DISTINCT 
				f.FormId
				,f.FormName
				,f.IsTimeStamp
				,f.IsGeoValidation
				,f.IsStoreStamp
			FROM Forms f
			/** TODO add later */
				INNER JOIN FormLevelMap flm ON flm.FormId = f.FormId
			WHERE f.IsActive = 1
				AND (@P_Other_1 IS NULL OR @P_Other_1 = 'LEAD')
				AND f.IsStoreStamp = 1
				AND f.OrgId = @P_OrgId
			ORDER BY f.FormName
	END
	ELSE IF @P_Form_Type = 'AVAILABLE_FORM_LIST'
	BEGIN
			;WITH FormLevelMap_CTE
			AS
			(
				SELECT --DISTINCT 
					f.FormId
					,f.FormName
					,f.IsTimeStamp
					,f.IsGeoValidation
					,f.IsStoreStamp
					,f.OrgId
					,flm.BusinessRoleID
					,flm.OrgLevelMapId
					,flm.AccountId
				FROM Forms f WITH (nolock) 
					INNER JOIN FormLevelMap flm WITH (nolock)  ON flm.FormId = f.FormId
				WHERE 
					f.OrgId = @P_OrgId AND
					f.IsActive = 1 AND
					CASE 
						WHEN @P_Other_1 = 'LEAD' AND f.LeadFlag = 1 THEN 1
						WHEN @P_Other_1 <> 'LEAD' AND f.LeadFlag = 0 THEN 1
						ELSE 0
					END = 1	AND
					f.IsStoreStamp = 1								
			),
			flmHierarchy_CTE
			AS
			(
				SELECT	
						flm_c.FormId,
						uop.UserId
					FROM FormLevelMap_CTE flm_c
						INNER JOIN UserOrgProfile uop WITH (nolock) ON uop.OrgId = flm_c.OrgId 
																		AND uop.BusinessRoleID = flm_c.BusinessRoleID 
																		AND flm_c.OrgLevelMapId IS NULL 
																		AND flm_c.AccountId IS NULL
					WHERE 
						uop.UserId = @P_Id
			)
			SELECT DISTINCT 
					flm_c.FormId
					,flm_c.FormName
					,flm_c.IsTimeStamp
					,flm_c.IsGeoValidation
					,flm_c.IsStoreStamp
				FROM flmHierarchy_CTE fh_c
					INNER JOIN FormLevelMap_CTE flm_c ON flm_c.FormId = fh_c.FormId 
															AND flm_c.BusinessRoleID IS NULL 
															AND flm_c.AccountId IS NULL
					INNER JOIN DivisionRegion dr WITH (nolock)  ON dr.OrgLevelMapId = flm_c.OrgLevelMapId AND dr.OrgId = flm_c.OrgId
					INNER JOIN UserDivisionRegionMapping udrm WITH (nolock)  ON udrm.DivisionRegionId = dr.DivisionRegionId AND udrm.UserId = fh_c.UserId
				ORDER BY flm_c.FormName
	END
	ELSE IF @P_Form_Type = 'INSERT_DEFAULT_VALUE'
	BEGIN
		/** Insert all the Default values */
		DECLARE @ValueId INT; SET @ValueId = NULL;

    IF @P_Id = 'null' OR @P_Id = '' OR @P_Id = '0'
    BEGIN
      SET @P_Id = NULL
      SELECT @ValueId = FieldDefaultValueId FROM FieldDefaultValues WHERE FormId IS NULL AND DefaultValue = @P_NextId
    END ELSE
    BEGIN
      SELECT @ValueId = FieldDefaultValueId FROM FieldDefaultValues WHERE FormId = @P_Id AND DefaultValue = @P_NextId
    END    

    IF (@ValueId IS NULL)
    BEGIN
      INSERT INTO FieldDefaultValues (FormId, DefaultValue, TempId) VALUES (@P_Id, @P_NextId, @P_Other_1)
      SET @ValueId = @@IDENTITY
    END ELSE
    BEGIN
      UPDATE FieldDefaultValues SET TempId = @P_Other_1 WHERE FieldDefaultValueId = @ValueId;
    END

    SELECT FieldDefaultValueId FROM FieldDefaultValues
    WHERE FieldDefaultValueId = @ValueId
	END
	ELSE IF @P_Form_Type = 'QUEUE_LIST'
	BEGIN
			SELECT 	q.QueueId,
					q.OrgId,
					q.QueueName,
					q.QueueDescription,
					q.ActionToHierarchy,
					q.IsAutomaticEmail, 
					q.EmailAllowedToIndividual, 
					q.QueueEmailAddress, 
					q.EmailSubject, 
					q.EmailContent, 
					q.IsActive, 
					q.CreatedOn, 
					q.CreatedBy, 
					q.UpdatedOn, 
					q.UpdatedBy, 
					q.IsEditable
			FROM Queues q
			WHERE 1 = 1
					AND q.IsActive = 1
					AND q.OrgId = @P_OrgId
-- 					CASE
-- 						WHEN @P_Id IS NOT NULL AND
-- 										(q.EmailAllowedToIndividual <> '' OR
-- 											q.QueueId IN (
-- 														 SELECT q2.QueueId
-- 															FROM Queues q2
-- 															WHERE q2.QueueName IN ('Manager Action','Action Items')
-- 												AND q2.OrgId = @P_OrgId)) THEN 1
-- 						WHEN @P_Id IS NULL THEN 1
-- 						ELSE 0
-- 					END = 1
			ORDER BY q.QueueName
	END
	ELSE IF @P_Form_Type = 'DEFAULT_VALUES_LIST'
	BEGIN
		-- Clean the @P_ID
		IF (@P_Id = 'null' OR @P_Id = '' OR @P_Id = '0') SET @P_Id = NULL;
		/** Get all the Default values */
		SELECT DISTINCT 
				FieldDefaultValueId,
				DefaultValue
			FROM FieldDefaultValues
			WHERE 
				DefaultValue IS NOT NULL OR
				DefaultValue NOT LIKE '%NULL%'
			ORDER BY DefaultValue
	END
	ELSE IF @P_Form_Type = 'DEFAULT_VALUES_LIST_BY_FORMID'
	BEGIN
		-- Clean the @P_ID
		IF (@P_Id = 'null' OR @P_Id = '' OR @P_Id = '0') SET @P_Id = NULL;
		/** Get all the Default values */
		SELECT DISTINCT
				FieldDefaultValueId,
				DefaultValue
			FROM FieldDefaultValues
			WHERE 1 = 1
				AND ( (@P_Id IS NULL AND TempId = @P_Other_1) OR FormId = @P_Id )
				AND (DefaultValue IS NOT NULL OR DefaultValue NOT LIKE '%NULL%')
			ORDER BY DefaultValue
	END
	ELSE IF @P_Form_Type = 'CREATE_FORM_UI'
	BEGIN
		/** Get all the fields based on forms id */
		SELECT ff.FormId
				,f.FormName
				,ff.FormFieldId
				,CASE 
						WHEN ff.ParentFieldId IS NULL THEN '0'
						ELSE ff.ParentFieldId
				END AS ParentFieldId
				,ff.IsParent
				,ff.FieldName
				,ft.FieldName AS FieldType
				,ff.FieldSize
				,ff.FieldDefaultValueId
				,fdv.DefaultValue
				,ff.IsRequiredField
				,CASE 
						WHEN ff.ExpressionWithId IS NOT NULL
							OR ff.ExpressionWithId <> '' THEN ExpressionWithId
						ELSE NULL
				END AS Expression
				,ff.TimeStampId
		FROM Forms f 
			INNER JOIN FormFields ff ON ff.FormId = f.FormId
			INNER JOIN FieldType ft ON ff.FieldTypeId = ft.FieldTypeId
			LEFT OUTER JOIN FieldDefaultValues fdv ON ff.FieldDefaultValueId = fdv.FieldDefaultValueId
		WHERE 
				f.FormId = @P_Id
				AND f.IsActive = 1
				AND ff.IsActive = 1
		ORDER BY ff.FieldOrdering
	END
	ELSE IF @P_Form_Type = 'CREATE_LEAD_FORM_UI'
	BEGIN
		/** Get all the fields for create lead form */
		SELECT ff.FormId
				,f.FormName
				,ff.FormFieldId
				,CASE 
						WHEN ff.ParentFieldId IS NULL THEN '0'
						ELSE ff.ParentFieldId
				END AS ParentFieldId
				,ff.IsParent
				,ff.FieldName
				,ft.FieldName AS FieldType
				,ff.FieldSize
				,ff.FieldDefaultValueId
				,fdv.DefaultValue
				,ff.IsRequiredField
				,CASE 
						WHEN ff.ExpressionWithId IS NOT NULL
							OR ff.ExpressionWithId <> '' THEN ExpressionWithId
						ELSE NULL
				END AS Expression
				,ff.TimeStampId
		FROM Forms f 
			INNER JOIN Configuration c ON c.Value = f.FormId AND c.Name = 'Lead_Form_Id'
			INNER JOIN FormFields ff ON ff.FormId = f.FormId
			INNER JOIN FieldType ft ON ff.FieldTypeId = ft.FieldTypeId
				LEFT OUTER JOIN FieldDefaultValues fdv ON ff.FieldDefaultValueId = fdv.FieldDefaultValueId
		WHERE 
				f.IsActive = 1
				AND ff.IsActive = 1
		ORDER BY ff.FieldOrdering
	END
	ELSE IF @P_Form_Type = 'SUBMITED_FORM_LIST'
	BEGIN
		/** Adhoc Form - Get all the submitted form list based on userId (NOT a storeId), StartingDate and EndingDate */
		SELECT DISTINCT
				fv.FormVisitId
				,f.FormName
				,CONVERT(VARCHAR(10), fv.VisitDate, 101) + ' ' + fv.TimeIn + '-' + u.FullName AS TimeIn
				,CONVERT(VARCHAR(10), fv.VisitDate, 101) AS CreatedOn
				,CASE
						WHEN fv.UserId = @P_Id THEN 'Yes'
						ELSE 'No'
				END AS SelfFormFlag
			FROM UserReporting_Function(@P_OrgId ,@P_Id) ur_f
				INNER JOIN Users u ON u.UserId = ur_f.UserId
				INNER JOIN FormVisit fv ON fv.UserId = ur_f.UserId
				INNER JOIN Forms f ON f.FormId = fv.FormId AND f.OrgId = @P_OrgId
			WHERE
				CASE
					WHEN @P_NextId IS NULL AND fv.StoreId IS NULL THEN 1
					WHEN @P_NextId IS NOT NULL AND fv.StoreId = @P_NextId THEN 1
					ELSE 0
				END = 1
				AND fv.VisitDate >= CONVERT(DATETIME, @P_Other_1, 121)
				AND fv.VisitDate <= CONVERT(DATETIME, @P_Other_2, 121) + 1
				/* Requirement - submitted form allow to view/edit even form is deleted (inActive) */
				--AND Forms.IsActive = 'TRUE'
		ORDER BY fv.FormVisitId DESC
	END
	ELSE IF @P_Form_Type = 'SUBMITED_FORM_VIEW'
	BEGIN
		;WITH FormVisit_CTE
		AS
		(
			SELECT 
					fv.FormVisitId,
					fv.FormId,
					fv.UserId,
					fv.StoreId,
					fv.Description,
					fv.VisitDate,
					fv.SalesStage
				FROM FormVisit fv
					LEFT JOIN SalesStage ss ON ss.FormVisitId = fv.FormVisitId AND ss.SalesStageName = fv.SalesStage
				WHERE fv.FormVisitId = @P_Id
		),
		PriorVisit_CTE
		AS
		(
			SELECT fv_c.FormVisitId,
					MAX(CONVERT(VARCHAR(10), fv.VisitDate, 101)) AS PriorVisitDate
				FROM FormVisit fv
					INNER JOIN FormVisit_CTE fv_c ON fv_c.UserId = fv.UserId
														AND fv_c.StoreId = fv.StoreId
														AND CONVERT(VARCHAR(10), fv_c.VisitDate, 101) <> CONVERT(VARCHAR(10), fv.VisitDate, 101)
														AND fv.FormVisitId < fv_c.FormVisitId
			GROUP BY fv_c.FormVisitId
		)
			SELECT 
					ff.FormId
					,f.FormName
					,ffv.FormFieldValueId AS FormFieldId
					,ff.ParentFieldId
					,ff.IsParent
					,ff.FieldName
					,ft.FieldName AS FieldType
					,ff.FieldSize
					,ff.FormFieldId AS FieldDefaultValueId
					,fdv.DefaultValue
					,CASE 
						WHEN ffv.FieldValue = '' THEN 'NULL'
						ELSE ffv.FieldValue
					END AS FieldValue
					,pit.PictureItemId AS PictureItemId
					,pit.[Description] AS PictureDescription
					,pit.PictureOrder AS PictureOrder
					,pit.STATUS AS PictureStatus
					,pc.CategoryId AS PictureCategoryId
					,pc.CategoryName AS PictureCategoryName
					,ff.IsEditable AS IsFieldEnable
					,ff.IsRequiredField
					,fv_c.SalesStage
					,u.FullName AS CreatedBy
					,CASE 
						WHEN ff.ExpressionWithId IS NOT NULL 
								OR ff.ExpressionWithId <> '' THEN ExpressionWithId
						ELSE NULL
					END AS Expression
					,ff.TimeStampId
					,CASE 
							WHEN pv_c.PriorVisitDate != ''	THEN pv_c.PriorVisitDate
							ELSE CONVERT(VARCHAR(10), fv_c.VisitDate, 101)
					END AS PriorVisitDate
					FROM FormVisit_CTE fv_c
						LEFT JOIN PriorVisit_CTE pv_c ON pv_c.FormVisitId = fv_c.FormVisitId
						INNER JOIN Forms f ON f.FormId = fv_c.FormId
						INNER JOIN FormFields ff ON ff.FormId = f.FormId						
						INNER JOIN FieldType ft ON ff.FieldTypeId = ft.FieldTypeId
						INNER JOIN Users u ON u.UserId = fv_c.UserId
							LEFT OUTER JOIN FieldDefaultValues fdv ON ff.FieldDefaultValueId = fdv.FieldDefaultValueId
							LEFT OUTER JOIN FormFieldValues ffv ON ff.FormFieldId = ffv.FormFieldId
							LEFT OUTER JOIN PictureItems pit ON ffv.FormFieldValueId = pit.FormFieldValueId
							LEFT OUTER JOIN PictureItemCategories pict ON pict.PictureItemId = pit.PictureItemId
							LEFT OUTER JOIN PictureCategories pc ON pc.CategoryId = pict.CategoryId
					WHERE 
						ffv.FormVisitId = @P_Id
						/* Requirement - submitted form allow to view/edit even form is deleted (inActive) */
						--AND f.IsActive = 'TRUE' AND ff.IsActive = 'TRUE'   
					ORDER BY ff.FieldOrdering
	END
	ELSE IF @P_Form_Type = 'LEAD_FORM_INFO'
	BEGIN
		/** TODO ADD LATER - New requirement add date with every SalesStage drop down */
		--SELECT @SalesStageWithDate = CASE WHEN SalesStage.UpdatedOn IS NOT NULL THEN (FormVisit.SalesStage + ' - ' + SUBSTRING(CONVERT(VARCHAR, SalesStage.UpdatedOn,101), 0, 11)) ELSE FormVisit.SalesStage END  
		/** TODO ADD LATER - New requirement undo add date with every SalesStage drop down */
			SELECT DISTINCT 
					fv.FormVisitId
					,f.FormName
					,fv.LeadIndexKey
					,fv.SalesStage
					,CONVERT(VARCHAR(10), fv.VisitDate, 101) CreatedOn
					,fv.TimeIn
					,fv.TimeOut
					,u.FullName AS CreatedBy
				FROM FormVisit fv
					INNER JOIN Forms f ON fv.FormId = f.FormId
					INNER JOIN Users u ON u.UserId = fv.UserId
				WHERE f.IsActive = 1
					AND fv.FormVisitId = @P_Id
	END
	ELSE IF @P_Form_Type = 'SUBMITED_ADHOCFORM_VIEW'
	BEGIN
		/** Get all the field values based on form visitid (for update we need FormFieldValues.FormFieldValueId as FormFieldId)*/
		SELECT 
					ff.FormId
					,f.FormName
					,ffv.FormFieldValueId AS FormFieldId
					,ff.ParentFieldId
					,ff.IsParent
					,ff.FieldName
					,ft.FieldName AS FieldType
					,ff.FieldSize
					,ff.FormFieldId AS FieldDefaultValueId
					,fdv.DefaultValue
					,CASE 
						WHEN ffv.FieldValue = '' THEN 'NULL'
						ELSE ffv.FieldValue
					END AS FieldValue
					,pit.PictureItemId AS PictureItemId
					,pit.[Description] AS PictureDescription
					,pit.PictureOrder AS PictureOrder
					,pit.STATUS AS PictureStatus
					,pc.CategoryId AS PictureCategoryId
					,pc.CategoryName AS PictureCategoryName
					,ff.IsEditable AS IsFieldEnable
					,ff.IsRequiredField
					,fv.[Description]
					,CASE 
						WHEN ExpressionWithId IS NOT NULL 
								OR ExpressionWithId <> '' THEN ExpressionWithId
						ELSE NULL
					END AS Expression
					,ff.TimeStampId
					FROM FormVisit fv
						INNER JOIN Forms f ON f.FormId = fv.FormId
						INNER JOIN FormFields ff ON ff.FormId = f.FormId						
						INNER JOIN FieldType ft ON ff.FieldTypeId = ft.FieldTypeId
							LEFT OUTER JOIN FieldDefaultValues fdv ON ff.FieldDefaultValueId = fdv.FieldDefaultValueId
							LEFT OUTER JOIN FormFieldValues ffv ON ff.FormFieldId = ffv.FormFieldId
							LEFT OUTER JOIN PictureItems pit ON ffv.FormFieldValueId = pit.FormFieldValueId
							LEFT OUTER JOIN PictureItemCategories pict ON pict.PictureItemId = pit.PictureItemId
							LEFT OUTER JOIN PictureCategories pc ON pc.CategoryId = pict.CategoryId
					WHERE 
						ffv.FormVisitId = @P_Id
						AND fv.FormVisitId = @P_Id
						/* Requirement - submitted form allow to view/edit even form is deleted (inActive) */
						--AND f.IsActive = 'TRUE' AND ff.IsActive = 'TRUE'   
					ORDER BY ff.FieldOrdering
	END
	ELSE IF @P_Form_Type = 'SECTION_LIST'
	BEGIN
		/** Get all the sections based on forms id */
			SELECT 
					fs.FormSectionId
					,fs.SectionName
					,fs.SectionOrdering
					,fs.SectionDescription
				FROM Forms f 
					INNER JOIN FormSection fs ON fs.FormId = f.FormId
				WHERE f.IsActive = 1
					AND fs.IsActive = 1
					AND fs.FormId = @P_Id
					AND (@P_NextId IS NULL OR fs.FormSectionId = @P_NextId)
				ORDER BY fs.SectionOrdering
	END
	ELSE IF @P_Form_Type = 'VISIT_INFO'
	BEGIN
		/** NEW REQUIREMENT LOGIC CHANGES */
			SELECT @PriorVisitDate =
					MAX(CONVERT(VARCHAR(10), fv.VisitDate, 101))
				FROM FormVisit fv
					INNER JOIN FormVisit fv_c ON fv_c.UserId = fv.UserId
														AND fv_c.StoreId = fv.StoreId
														AND CONVERT(VARCHAR(10), fv_c.VisitDate, 101) <> CONVERT(VARCHAR(10), fv.VisitDate, 101)
														AND fv.FormVisitId < fv_c.FormVisitId
			WHERE fv_c.FormVisitId = @P_Id
			GROUP BY fv_c.FormVisitId

		SELECT fv_c.UserId,
				s.StoreNumber AS StoreId,
				s.StoreName,
				CASE 
					WHEN s.CertifiedStoreNickname = ''	OR CertifiedStoreNickname IS NULL THEN s.StoreName
					ELSE s.CertifiedStoreNickname
				END AS StoreNickName,
				CONVERT(VARCHAR(10), fv_c.VisitDate, 101) AS CurrentDate
				,CASE 
					WHEN @PriorVisitDate != '' THEN @PriorVisitDate
					ELSE CONVERT(VARCHAR(10), fv_c.VisitDate, 101)
					END AS LastVisitDate
				,fv_c.TimeIn
				,fv_c.TimeOut
			FROM  FormVisit fv_c
				INNER JOIN Store s ON s.StoreId = fv_c.StoreId
			WHERE fv_c.FormVisitId = @P_Id
	END
	ELSE IF @P_Form_Type = 'ADHOC_INFO'
	BEGIN
		/** Get AdhocInfo based on StoreId*/
		SELECT 
			fv.Description
			,CONVERT(VARCHAR(10), fv.VisitDate, 101) AS CreatedOn
			,fv.TimeIn
			,fv.TimeOut
		FROM FormVisit fv
		WHERE fv.FormVisitId = @P_Id
	END
	ELSE IF @P_Form_Type = 'LEAD_XL_FIELD_LIST'
	BEGIN
		SELECT FormFieldId, FieldName, FieldOrdering 
			FROM
				(SELECT null AS FormFieldId, 'Assigned To' AS FieldName, NULL AS FieldOrdering UNION ALL	
				SELECT null AS FormFieldId, 'Sales Stage' AS FieldName, NULL AS FieldOrdering UNION ALL	
				SELECT ff.FormFieldId
						,ff.FieldName
						,ff.FieldOrdering
				FROM Forms f 
					INNER JOIN FormFields ff ON ff.FormId = f.FormId
				WHERE	f.FormId = 1
						AND f.IsActive = 1
						AND ff.IsActive = 1) AS ff_Union
		ORDER BY ff_Union.FieldOrdering
	END
			-- EXEC [DynamicForm_Builder] '3', 'FIELD_LIST', '1', '', '', ''  
	ELSE IF @P_Form_Type = 'FIELD_LIST'
	BEGIN
		/** Get all the fields based on forms id and/or section id*/
		SELECT fs.FormSectionId
				,fs.SectionName
				,fs.SectionOrdering
				,fs.SectionDescription
				,ff.FormFieldId
				,ff.FieldOrdering
				,ff.FieldTypeId
				,ff.FieldName
				,ff.FieldSize
				,ff.FieldDefaultValueId
				,ff.ParentFieldId
				,ff.IsParent
				,ff.QueueId
				,ff.IsRequiredField
				,ff.IsDynamicReport
				,ff.IsEditable
				,fdv.DefaultValue
				,ff.ExpressionWithId
				,ff.ExpressionWithQuestion
				,ff.TimestampId
			FROM Forms f WITH (nolock)
				INNER JOIN FormFields ff WITH (nolock) ON ff.FormId = f.FormId
					LEFT OUTER JOIN FieldDefaultValues fdv WITH (nolock) ON fdv.FieldDefaultValueId = ff.FieldDefaultValueId
					LEFT OUTER JOIN FormSection fs WITH (nolock) ON fs.FormSectionId = ff.FormSectionId
			WHERE f.FormId = @P_Id
					AND f.IsActive = 1
					AND ff.IsActive = 1
					AND (@P_NextId IS NULL OR ff.FormSectionId = @P_NextId)
			ORDER BY ff.FieldOrdering
	END
	ELSE IF @P_Form_Type = 'EXPORT_STORE_VISIT'
	BEGIN
			SELECT @PriorVisitDate =
					MAX(CONVERT(VARCHAR(10), fv.VisitDate, 101))
				FROM FormVisit fv
					INNER JOIN FormVisit fv_c ON fv_c.UserId = fv.UserId
														AND fv_c.StoreId = fv.StoreId
														AND CONVERT(VARCHAR(10), fv_c.VisitDate, 101) <> CONVERT(VARCHAR(10), fv.VisitDate, 101)
														AND fv.FormVisitId < fv_c.FormVisitId
			WHERE fv_c.FormVisitId = @P_Id
			GROUP BY fv_c.FormVisitId
		SELECT ff.FormId
				,f.FormName
				,ffv.FormFieldValueId AS FormFieldId
				,ff.ParentFieldId
				,ff.IsParent
				,ff.FieldName
				,ft.FieldName AS FieldType
				,ff.FieldSize
				,ff.FormFieldId AS FieldDefaultValueId
				,fdv.DefaultValue
				,CASE 
					WHEN ffv.FieldValue = ''
						THEN 'NULL'
					ELSE ffv.FieldValue
					END AS FieldValue
				,pit.PictureItemId AS PictureItemId
				,replace(pit.Path, cast(pit.PictureitemId AS VARCHAR(10)) + '.jpg', cast(pit.PictureitemId AS VARCHAR(10)) + '_100x100.jpg') AS PicturePath
				,dbo.escapeHtml(pit.[Description]) AS PictureDescription
				,pit.PictureOrder AS PictureOrder
				,pit.STATUS AS PictureStatus
				,NULL AS PictureCategoryId
				,stuff((
						SELECT ';' + pct.CategoryName
						FROM PictureItemCategories pict
							JOIN PictureCategories pct ON pct.CategoryId = pict.CategoryId
						WHERE pict.PictureItemId = pit.PictureItemId
						FOR XML path('')
						), 1, 1, '') AS PictureCategoryName
				,ff.IsEditable AS IsFieldEnable
				,ff.IsRequiredField
				,fv_c.SalesStage
				,u.FullName AS CreatedBy
				,CASE 
					WHEN ff.ExpressionWithId IS NOT NULL OR ff. ExpressionWithId <> '' THEN ExpressionWithId
					ELSE NULL
				END AS Expression
				,ff.TimeStampId
				,CASE 
					WHEN @PriorVisitDate != '' THEN @PriorVisitDate
					ELSE CONVERT(VARCHAR(10), fv_c.VisitDate, 101)
				END AS PriorVisitDate
			FROM FormVisit fv_c
				INNER JOIN Forms f  ON f.FormId = fv_c.FormId
				INNER JOIN FormFields ff ON ff.FormId = f.FormId
				INNER JOIN FieldType ft ON ff.FieldTypeId = ft.FieldTypeId
				INNER JOIN Users u ON u.UserId = fv_c.UserId
					LEFT OUTER JOIN FieldDefaultValues fdv ON ff.FieldDefaultValueId = fdv.FieldDefaultValueId
					LEFT OUTER JOIN FormFieldValues ffv ON ff.FormFieldId = ffv.FormFieldId
					LEFT OUTER JOIN PictureItems pit ON ffv.FormFieldValueId = pit.FormFieldValueId
				WHERE fv_c.FormVisitId = @P_Id
						and ffv.FormVisitId = @P_Id
				ORDER BY ff.FieldOrdering
					,pit.PictureOrder
	END
	ELSE IF @P_Form_Type = 'EXPORT_AD_HOC_VISIT'
	BEGIN
		SELECT ff.FormId
				,f.FormName
				,ffv.FormFieldValueId AS FormFieldId
				,ff.ParentFieldId
				,ff.IsParent
				,ff.FieldName
				,ft.FieldName AS FieldType
				,ff.FieldSize
				,ff.FormFieldId AS FieldDefaultValueId
				,fdv.DefaultValue
				,CASE 
					WHEN ffv.FieldValue = ''
						THEN 'NULL'
					ELSE ffv.FieldValue
					END AS FieldValue
				,pit.PictureItemId AS PictureItemId
				,replace(pit.Path, cast(pit.PictureitemId AS VARCHAR(10)) + '.jpg', cast(pit.PictureitemId AS VARCHAR(10)) + '_100x100.jpg') AS PicturePath
				,dbo.escapeHtml(pit.[Description]) AS PictureDescription
				,pit.PictureOrder AS PictureOrder
				,pit.STATUS AS PictureStatus
				,NULL AS PictureCategoryId
				,stuff((
						SELECT ';' + pct.CategoryName
							FROM PictureItemCategories pict
								JOIN PictureCategories pct ON pct.CategoryId = pict.CategoryId
							WHERE pict.PictureItemId = pit.PictureItemId
							FOR XML path('')
						), 1, 1, '') AS PictureCategoryName
				,ff.IsEditable AS IsFieldEnable
				,ff.IsRequiredField
				,fv.Description
				,CASE 
					WHEN ff.ExpressionWithId IS NOT NULL OR ff. ExpressionWithId <> '' THEN ExpressionWithId
					ELSE NULL
				END AS Expression
				,ff.TimeStampId
			FROM FormVisit fv
				INNER JOIN Forms f  ON f.FormId = fv.FormId
				INNER JOIN FormFields ff ON ff.FormId = f.FormId
				INNER JOIN FieldType ft ON ff.FieldTypeId = ft.FieldTypeId
					LEFT OUTER JOIN FieldDefaultValues fdv ON ff.FieldDefaultValueId = fdv.FieldDefaultValueId
					LEFT OUTER JOIN FormFieldValues ffv ON ff.FormFieldId = ffv.FormFieldId
					LEFT OUTER JOIN PictureItems pit ON ffv.FormFieldValueId = pit.FormFieldValueId
				WHERE 
						fv.FormVisitId = @P_Id
						AND ffv.FormVisitId = @P_Id
				ORDER BY ff.FieldOrdering
					,pit.PictureOrder
	END
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DynamicForm_Creator_Copy' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DynamicForm_Creator_Copy]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DynamicForm_Creator_Copy]    Script Date: 3/2/2015 6:36:38 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DynamicForm_Creator_Copy](
	@P_OrgId INT,
	@P_Id VARCHAR(20),
	@P_UserId VARCHAR(50),
	@P_Name VARCHAR(200),
	@P_IsTimeStamp VARCHAR(5)='',
	@P_IsDynamicReporting VARCHAR(5)='',
	@P_IsGeoValidation VARCHAR(5)='',
	@P_IsStoreStamp VARCHAR(5)='',
	@P_IsApplyToCompliance VARCHAR(5)='',

	/** XML data */
	@P_OrganizationXML VARCHAR(MAX)='',
	@P_HierarchyXML VARCHAR(MAX)='',
	@P_AccountXML VARCHAR(MAX)='',
	@P_FormSectionXML VARCHAR(MAX)='',
	@P_FormFieldXML VARCHAR(MAX)='',

	/** OUTPUT PARAMS*/
	@P_Form_Status INT OUT,
	@P_ErrorProcedure VARCHAR(100) OUT,
	@P_ErrorLine VARCHAR(15) OUT,
	@P_ErrorMessage NVARCHAR(MAX) OUT
)
AS
SET NOCOUNT ON
BEGIN

  DECLARE @MyXML XML
  DECLARE @FormId INT
  DECLARE @UserName VARCHAR(30)
  DECLARE @SectionId INT
  DECLARE @FieldId INT
  DECLARE @SectionCount INT
  DECLARE @FieldCount INT
  DECLARE @SectionOrdering INT
  DECLARE @FieldDefaultValueId INT
  DECLARE @FieldOrdering INT
  
  DECLARE @WorkflowTypeId TABLE(
      FieldOrdering INT,
      QueueId INT)
     /** CREATE #OrganizationXML_TempTable - 1 */
  DECLARE @OrganizationXML_TempTable TABLE (OrgLevelMapId INT)  
  /** CREATE #HierarchyXML_TempTable - 2 */
  DECLARE @HierarchyXML_TempTable TABLE (BusinessRoleId INT)
  /** CREATE #AccountXML_TempTable - 3 */
  DECLARE @AccountXML_TempTable TABLE (AccountId INT)
  /** CREATE #SectionXML_TempTable - 4 */
  DECLARE @FormSectionXML_TempTable TABLE (
      FormSectionId VARCHAR(20), 
      SectionName VARCHAR(100), 
      SectionOrdering VARCHAR(5), 
      SectionDescription VARCHAR(500))
  /** CREATE #FormFieldXML_TempTable - 5 */
  DECLARE @FormFieldXML_TempTable TABLE (
    FormFieldId VARCHAR(20), 
    SectionOrdering VARCHAR(5),
    FieldOrdering VARCHAR(5), 
    FieldTypeId VARCHAR(5), 
    FieldName VARCHAR(1000),
    FieldSize VARCHAR(5), 
    FieldDefaultValueId VARCHAR(20), 
    FieldDefaultValue VARCHAR(500),
    ParentId VARCHAR(20),
    IsRequiredField VARCHAR(5), 
    ISDynamicReporting VARCHAR(5),
    QueueId VARCHAR(20), 
    IsEditable VARCHAR(5),
    ExpressionWithId VARCHAR(1000), 
    ExpressionWithQuestion VARCHAR(1000), 
    TimestampId VARCHAR(5))

   
  BEGIN TRY
      BEGIN TRANSACTION
  SET @P_Form_Status = 0

  IF(@P_OrganizationXML != '' AND @P_HierarchyXML != '' AND @P_AccountXML != '' AND @P_FormSectionXML != '' AND @P_FormFieldXML != '')
  BEGIN
   SET @MyXML = @P_OrganizationXML
   
   INSERT INTO @OrganizationXML_TempTable(OrgLevelMapId)
   SELECT T.item.value('(ID)[1]', 'INT')
   FROM @MyXML.nodes('OrganizationXML/R') AS T(item)

   SET @MyXML = @P_HierarchyXML

   INSERT INTO @HierarchyXML_TempTable(BusinessRoleId)
   SELECT T.item.value('(ID)[1]', 'INT')
   FROM @MyXML.nodes('HierarchyXML/R') AS T(item)

   SET @MyXML = @P_AccountXML
   
   INSERT INTO @AccountXML_TempTable(AccountId)
   SELECT T.item.value('(ID)[1]', 'INT')
   FROM @MyXML.nodes('AccountXML/R') AS T(item)

   SET @MyXML = @P_FormSectionXML
   
   INSERT INTO @FormSectionXML_TempTable(FormSectionId, SectionName, SectionOrdering, SectionDescription)
   SELECT T.item.value('(ID)[1]', 'VARCHAR(20)'), T.item.value('(SN)[1]', 'VARCHAR(100)'), T.item.value('(SO)[1]', 'VARCHAR(5)'), T.item.value('(SD)[1]', 'VARCHAR(500)')
   FROM @MyXML.nodes('FormSectionXML/R') AS T(item)
   
   SET @SectionCount=@@ROWCOUNT

 /** TODO - newly field added for dynamic calculation AND TIMESTAMP :: (ExpressionWithId and ExpressionWithQuestion) AND TimestampId */
   SET @MyXML = @P_FormFieldXML
   
   INSERT INTO @FormFieldXML_TempTable(FormFieldId, SectionOrdering,
    FieldOrdering, FieldTypeId , FieldName ,
    FieldSize, FieldDefaultValueId, FieldDefaultValue,
    ParentId ,IsRequiredField ,ISDynamicReporting,
    QueueId, IsEditable,
    ExpressionWithId, ExpressionWithQuestion, TimestampId)
   SELECT T.item.value('(ID)[1]', 'VARCHAR(20)'), T.item.value('(SO)[1]', 'VARCHAR(5)'),
    T.item.value('(QO)[1]', 'VARCHAR(5)'),  T.item.value('(TI)[1]', 'VARCHAR(5)'), T.item.value('(HT)[1]', 'VARCHAR(1000)'),
    T.item.value('(DT)[1]', 'VARCHAR(5)'),  T.item.value('(DVI)[1]', 'VARCHAR(20)'), T.item.value('(DV)[1]', 'VARCHAR(500)'),
    T.item.value('(PI)[1]', 'VARCHAR(20)'), T.item.value('(RQ)[1]', 'VARCHAR(5)'), T.item.value('(DR)[1]', 'VARCHAR(5)'),
    T.item.value('(QI)[1]', 'VARCHAR(20)'), T.item.value('(IE)[1]', 'VARCHAR(5)'),
    T.item.value('(EWI)[1]', 'VARCHAR(1000)'), T.item.value('(EWQ)[1]', 'VARCHAR(1000)'), T.item.value('(TST)[1]', 'VARCHAR(5)')
   FROM @MyXML.nodes('FormFieldXML/R') AS T(item)
   SET @FieldCount=@@ROWCOUNT

   /** Delete dummy section */
   DELETE FROM @FormSectionXML_TempTable WHERE SectionOrdering = '0' OR SectionOrdering = ''

   /** Avoid null or zero values in SectionOrdering*/
   UPDATE @FormFieldXML_TempTable SET SectionOrdering = NULL WHERE SectionOrdering = '0' OR SectionOrdering = 'null' OR SectionOrdering = ''

   /** Avoid null or zero values in TimestampId*/
   UPDATE @FormFieldXML_TempTable SET TimestampId = NULL WHERE TimestampId = '0' OR TimestampId = 'null' OR TimestampId = ''

   /** Avoid null or zero values in ExpressionWithId and ExpressionWithQuestion*/
   UPDATE @FormFieldXML_TempTable SET ExpressionWithId = NULL, ExpressionWithQuestion = NULL WHERE ExpressionWithId = '0' OR ExpressionWithId = 'null' OR ExpressionWithId = ''

   /** Avoid null or zero values in ParentId*/
   UPDATE @FormFieldXML_TempTable SET ParentId = NULL WHERE ParentId = '0' OR ParentId = 'null' OR ParentId = ''

   /** Avoid null or zero values in FieldSize*/
   UPDATE @FormFieldXML_TempTable SET FieldSize = NULL WHERE FieldSize = '0' OR FieldSize = 'null' OR FieldSize = ''

   /** Avoid null or zero values in QueueId*/
   UPDATE @FormFieldXML_TempTable SET QueueId = NULL WHERE QueueId = '0' OR QueueId = 'null' OR QueueId = ''

   /** Avoid null or zero values in FieldDefaultValueId*/
   UPDATE @FormFieldXML_TempTable SET FieldDefaultValueId = NULL WHERE FieldDefaultValueId = '0' OR FieldDefaultValueId = 'null' OR FieldDefaultValueId = ''

  END
  
   /** Form copy */
   INSERT INTO Forms(
      OrgId, 
      FormName, 
      IsQueue, 
      IsTimeStamp, 
      IsDynamicReporting, 
      IsGeoValidation, 
      IsStoreStamp, 
      IsApplyToCompliance, 
      IsActive, 
      VisitAllowFlag, 
      CreatedBy, 
      CreatedOn)
   SELECT 
      OrgId, 
      @P_Name, 
      IsQueue, 
      IsTimeStamp, 
      IsDynamicReporting, 
      IsGeoValidation, 
      IsStoreStamp, 
      IsApplyToCompliance, 
      IsActive, 
      VisitAllowFlag, 
      @P_UserId, 
      GETDATE()
    FROM 
      Forms 
    WHERE 
      FormId = @P_Id
   
   SET @FormId = SCOPE_IDENTITY()

   DECLARE @FormSection_temp_table TABLE (
      FormId INT, 
      FormSectionId INT, 
      SectionName VARCHAR(100), 
      SectionOrdering INT, 
      SectionDescription VARCHAR(500), 
      IsActive BIT)

   /** INSERT INTO #SectionXML_TempTable*/
   INSERT INTO @FormSection_temp_table(
      FormId, 
      FormSectionId, 
      SectionName, 
      SectionOrdering, 
      SectionDescription, 
      IsActive)
   SELECT 
      FormId, 
      FormSectionId, 
      SectionName, 
      SectionOrdering, 
      SectionDescription, 
      IsActive
    FROM 
      FormSection 
    WHERE 
      FormId = @P_Id 
      AND IsActive = 1 
    ORDER BY SectionOrdering
    
   SET @SectionCount=@@ROWCOUNT

   DECLARE @FormFields_temp_table TABLE (
      FormId INT, 
      FormSectionId INT, 
      FormFieldId INT, 
      FieldOrdering INT, 
      FieldTypeId INT, 
      FieldName VARCHAR(500), 
      FieldSize INT, 
      FieldDefaultValueId INT, 
      ParentFieldId INT, 
      ParentFieldOrdering INT, 
      IsParent BIT,
      IsRequiredField BIT, 
      IsDynamicReport BIT,  
      QueueId INT, 
      IsEditable BIT, 
      ExpressionWithId VARCHAR(1000), 
      ExpressionWithQuestion VARCHAR(1000), 
      TimestampId VARCHAR(5), 
      IsActive BIT)
   
   INSERT INTO @FormFields_temp_table(
      FormId, 
      FormSectionId, 
      FormFieldId, 
      FieldOrdering, 
      FieldTypeId,
      FieldName, 
      FieldSize, 
      FieldDefaultValueId, 
      ParentFieldId, 
      IsParent, 
      IsRequiredField,
      IsDynamicReport, 
      QueueId, 
      IsEditable, 
      ExpressionWithId, 
      ExpressionWithQuestion, 
      TimestampId, 
      IsActive)
   SELECT 
      FormId, 
      FormSectionId, 
      FormFieldId, 
      FieldOrdering, 
      FieldTypeId, 
      FieldName, 
      FieldSize, 
      FieldDefaultValueId, 
      ParentFieldId, 
      IsParent, 
      IsRequiredField,
      IsDynamicReport, 
      QueueId, 
      IsEditable, 
      ExpressionWithId, 
      ExpressionWithQuestion, 
      TimestampId, 
      IsActive
    FROM 
      FormFields 
    WHERE 
      FormId = @P_Id 
      AND IsActive = 1 
    ORDER BY FieldOrdering

   SET @FieldCount=@@ROWCOUNT

   DECLARE @OldSectionId INT
   WHILE @SectionCount > 0
   BEGIN

    /** Insert into section one by one */
    INSERT INTO FormSection(
        FormId, 
        SectionName, 
        SectionOrdering, 
        SectionDescription, 
        IsActive)
    SELECT TOP 1 
        @FormId, 
        SectionName, 
        SectionOrdering, 
        SectionDescription, 
        IsActive
      FROM 
        @FormSection_temp_table

    SET @SectionId = SCOPE_IDENTITY()
    SET @OldSectionId = (SELECT TOP 1 FormSectionId FROM @FormSection_temp_table)

    /** New Section update */
    UPDATE @FormFields_temp_table 
    SET FormSectionId = @SectionId 
    WHERE FormSectionId = @OldSectionId

    DELETE FROM @FormSection_temp_table 
    WHERE FormSectionId = @OldSectionId
    
    SET @SectionCount = @SectionCount - 1
   
   END

   SELECT * FROM @FormFields_temp_table

   DECLARE @ParentFormFields_temp_table TABLE (
      FormFieldId INT, 
      ParentFieldId INT, 
      ParentFieldOrdering INT)
      
   INSERT INTO @ParentFormFields_temp_table(
      FormFieldId, 
      ParentFieldId)
   SELECT 
      FormFieldId, 
      ParentFieldId
    FROM 
      @FormFields_temp_table 
    WHERE 
      FormId = @P_Id 
      AND IsActive = 1 
      AND ParentFieldId IS NOT NULL 
      AND ParentFieldId != 0 
    ORDER BY FieldOrdering

   UPDATE 
      T2
    SET 
      T2.ParentFieldOrdering = T1.FieldOrdering
    FROM 
      @FormFields_temp_table T1
        INNER JOIN @ParentFormFields_temp_table T2 ON T2.ParentFieldId = T1.FormFieldId
    WHERE 
      T1.FormId = @P_Id

   /** Field copy */
   INSERT INTO FormFields(
      FormId, 
      FormSectionId, 
      FieldOrdering, 
      FieldTypeId, 
      FieldName, 
      FieldSize, 
      FieldDefaultValueId, 
      ParentFieldId, 
      IsParent, 
      QueueId, 
      IsRequiredField, 
      IsDynamicReport, 
      IsEditable, 
      ExpressionWithId, 
      ExpressionWithQuestion, 
      TimestampId,
      IsActive)
   SELECT 
      @FormId, 
      FormSectionId, 
      FieldOrdering, 
      FieldTypeId, 
      FieldName, 
      FieldSize, 
      FieldDefaultValueId, 
      ParentFieldId, 
      IsParent, 
      QueueId, 
      IsRequiredField, 
      IsDynamicReport, 
      IsEditable, 
      ExpressionWithId, 
      ExpressionWithQuestion, 
      TimestampId, 
      IsActive
    FROM 
      @FormFields_temp_table 
    WHERE 
      FormId = @P_Id 
      AND IsActive = 1
    ORDER BY 
      FieldOrdering

--print '#FormFields_temp_table 2'


   UPDATE 
      @ParentFormFields_temp_table 
    SET 
      FormFieldId = T1.FormFieldId
    FROM 
      FormFields T1
        INNER JOIN @ParentFormFields_temp_table T2 ON T2.ParentFieldOrdering = T1.FieldOrdering
    WHERE 
      T1.FormId = @FormId 
      AND T1.IsActive = 1

   /** Parent field copy */
   UPDATE 
      FormFields 
    SET 
      ParentFieldId = T1.FormFieldId
    FROM 
      @ParentFormFields_temp_table T1
        INNER JOIN FormFields T2 ON T2.ParentFieldId = T1.ParentFieldId
    WHERE 
      T2.FormId = @FormId 
      AND T2.IsActive = 1

   /** FieldDefaultValues copy for combo box drop down values */
   INSERT INTO FieldDefaultValues(
      FormId, 
      DefaultValue, 
      TempId)
   SELECT 
      @FormId, 
      DefaultValue, 
      TempID
    FROM 
      FieldDefaultValues 
    WHERE 
      FormId = @P_Id

   DECLARE @FieldDefaultValues_Temp TABLE(
      FieldDefaultValueId INT,
      NewFieldDefaultValueId INT,
      FormId INT,
      DefaultValue VARCHAR(MAX))
      
   INSERT INTO @FieldDefaultValues_Temp (
      FieldDefaultValueId,
      NewFieldDefaultValueId,
      FormId,
      DefaultValue)
   SELECT 
      FieldDefaultValueId, 
      FieldDefaultValueId AS NewFieldDefaultValueId, 
      @FormId AS FormId, 
      DefaultValue 
    FROM 
      FieldDefaultValues 
    WHERE 
      FormId = @P_Id

   UPDATE 
      fdvt
    SET 
      fdvt.NewFieldDefaultValueId = fdv.FieldDefaultValueId
    FROM 
      @FieldDefaultValues_Temp fdvt
        INNER JOIN FieldDefaultValues fdv ON fdv.DefaultValue = fdvt.DefaultValue
                                          AND fdv.FormId = @FormId

   UPDATE 
      T2 
    SET 
      T2.FieldDefaultValueId = T1.NewFieldDefaultValueId
    FROM 
      @FieldDefaultValues_Temp T1
        INNER JOIN FormFields T2 ON T2.FieldDefaultValueId = T1.FieldDefaultValueId
    WHERE 
      T2.FormId = @FormId 
      AND T2.IsActive = 1

------ End

   /** Workflow copy */
   INSERT INTO WorkflowMap(
      WorkflowId, 
      QueueId, 
      FormId, 
      SectionId, 
      FormFieldId)
    SELECT 
      wf.WorkflowId, 
      ff.QueueId, 
      @FormId, 
      ff.FormSectionId, 
      ff.FormFieldId
    FROM 
      FormFields ff
        INNER JOIN Workflow wf ON wf.WorkflowName = ff.FieldName
    WHERE 
      ff.FormId = @FormId 
      AND ff.QueueId > 0

   /** Orglevel, HierarchyLevel, AccountLevel copy */
   INSERT INTO FormLevelMap(
      FormId, 
      OrgLevelMapId, 
	 BusinessRoleID, 
      AccountId)
    SELECT 
      @FormId, 
      OrgLevelMapId, 
      BusinessRoleID, 
      AccountId
    FROM 
      FormLevelMap 
    WHERE 
      FormId = @P_Id
  
   /** COMMIT THE TRANSACTION */
   IF @@trancount > 0
   BEGIN
    PRINT 'COMMIT TRANSACTION'
    COMMIT TRANSACTION
	SET @P_Form_Status = 1
   END
   ELSE
   BEGIN
    PRINT 'ROLLBACK TRANSACTION'
    ROLLBACK TRANSACTION
	SET @P_Form_Status = 0
   END


  END TRY
  BEGIN CATCH
   --PRINT '@P_Form_Status: ' + STR(@P_Form_Status)
   PRINT 'ROLLBACK TRANSACTION'
   ROLLBACK TRANSACTION
   SET @P_Form_Status = 0
   /** CATCH THE ERROR DETAILS */
		DECLARE @ErrorMsg nvarchar(max);
		SET @ErrorMsg=	'ErrorNumber    = ' + CAST(ERROR_NUMBER() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorSeverity  = ' + CAST(ERROR_SEVERITY() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorState     = ' + CAST(ERROR_STATE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorProcedure = ' + CAST(ERROR_PROCEDURE() AS nvarchar(max)) + CHAR(13) + CHAR(10) +
						'ErrorLine		= ' + CAST(ERROR_LINE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorMessage	= ' + CAST(ERROR_MESSAGE() AS nvarchar(max)) + CHAR(13) + CHAR(10)
		PRINT @ErrorMsg;

  END CATCH
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DynamicForm_Creator_Insert' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DynamicForm_Creator_Insert]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DynamicForm_Creator_Insert]    Script Date: 3/2/2015 6:36:39 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DynamicForm_Creator_Insert](
 @P_OrgId INT,
 @P_Id VARCHAR(20),
 @P_UserId VARCHAR(50),
 @P_Name VARCHAR(200),
 @P_IsTimeStamp VARCHAR(5)='',
 @P_IsDynamicReporting VARCHAR(5)='',
 @P_IsGeoValidation VARCHAR(5)='',
 @P_IsStoreStamp VARCHAR(5)='',
 @P_IsApplyToCompliance VARCHAR(5)='',

 /** XML data */
 @P_OrganizationXML VARCHAR(MAX)='',
 @P_HierarchyXML VARCHAR(MAX)='',
 @P_AccountXML VARCHAR(MAX)='',
 @P_FormSectionXML VARCHAR(MAX)='',
 @P_FormFieldXML VARCHAR(MAX)='',

 /** OUTPUT PARAMS*/
 @P_Form_Status INT OUT,
 @P_ErrorProcedure VARCHAR(100) OUT,
 @P_ErrorLine VARCHAR(15) OUT,
 @P_ErrorMessage NVARCHAR(MAX) OUT
)
AS
SET NOCOUNT ON
BEGIN

  DECLARE @MyXML XML
  DECLARE @FormId INT
  DECLARE @UserName VARCHAR(30)
  DECLARE @SectionId INT
  DECLARE @FieldId INT
  DECLARE @SectionCount INT
  DECLARE @FieldCount INT
  DECLARE @SectionOrdering INT
  DECLARE @FieldDefaultValueId INT
  DECLARE @FieldOrdering INT
  
  DECLARE @WorkflowTypeId TABLE(
      FieldOrdering INT,
      QueueId INT)
     /** CREATE #OrganizationXML_TempTable - 1 */
  DECLARE @OrganizationXML_TempTable TABLE (OrgLevelMapId INT)  
  /** CREATE #HierarchyXML_TempTable - 2 */
  DECLARE @HierarchyXML_TempTable TABLE (BusinessRoleId INT)
  /** CREATE #AccountXML_TempTable - 3 */
  DECLARE @AccountXML_TempTable TABLE (AccountId INT)
  /** CREATE #SectionXML_TempTable - 4 */
  DECLARE @FormSectionXML_TempTable TABLE (
      FormSectionId VARCHAR(20), 
      SectionName VARCHAR(100), 
      SectionOrdering VARCHAR(5), 
      SectionDescription VARCHAR(500))
  /** CREATE #FormFieldXML_TempTable - 5 */
  DECLARE @FormFieldXML_TempTable TABLE (
    FormFieldId VARCHAR(20), 
    SectionOrdering VARCHAR(5),
    FieldOrdering VARCHAR(5), 
    FieldTypeId VARCHAR(5), 
    FieldName VARCHAR(1000),
    FieldSize VARCHAR(5), 
    FieldDefaultValueId VARCHAR(20), 
    FieldDefaultValue VARCHAR(500),
    ParentId VARCHAR(20),
    IsRequiredField VARCHAR(5), 
    ISDynamicReporting VARCHAR(5),
    QueueId VARCHAR(20), 
    IsEditable VARCHAR(5),
    ExpressionWithId VARCHAR(1000), 
    ExpressionWithQuestion VARCHAR(1000), 
    TimestampId VARCHAR(5))

   
  BEGIN TRY
      BEGIN TRANSACTION
  SET @P_Form_Status = 0

  IF(@P_OrganizationXML != '' AND @P_HierarchyXML != '' AND @P_AccountXML != '' AND @P_FormSectionXML != '' AND @P_FormFieldXML != '')
  BEGIN
   SET @MyXML = @P_OrganizationXML
   
   INSERT INTO @OrganizationXML_TempTable(OrgLevelMapId)
   SELECT T.item.value('(ID)[1]', 'INT')
   FROM @MyXML.nodes('OrganizationXML/R') AS T(item)

   SET @MyXML = @P_HierarchyXML

   INSERT INTO @HierarchyXML_TempTable(BusinessRoleId)
   SELECT T.item.value('(ID)[1]', 'INT')
   FROM @MyXML.nodes('HierarchyXML/R') AS T(item)

   SET @MyXML = @P_AccountXML
   
   INSERT INTO @AccountXML_TempTable(AccountId)
   SELECT T.item.value('(ID)[1]', 'INT')
   FROM @MyXML.nodes('AccountXML/R') AS T(item)

   SET @MyXML = @P_FormSectionXML
   
   INSERT INTO @FormSectionXML_TempTable(FormSectionId, SectionName, SectionOrdering, SectionDescription)
   SELECT T.item.value('(ID)[1]', 'VARCHAR(20)'), T.item.value('(SN)[1]', 'VARCHAR(100)'), T.item.value('(SO)[1]', 'VARCHAR(5)'), T.item.value('(SD)[1]', 'VARCHAR(500)')
   FROM @MyXML.nodes('FormSectionXML/R') AS T(item)
   
   SET @SectionCount=@@ROWCOUNT

 /** TODO - newly field added for dynamic calculation AND TIMESTAMP :: (ExpressionWithId and ExpressionWithQuestion) AND TimestampId */
   SET @MyXML = @P_FormFieldXML
   
   INSERT INTO @FormFieldXML_TempTable(FormFieldId, SectionOrdering,
    FieldOrdering, FieldTypeId , FieldName ,
    FieldSize, FieldDefaultValueId, FieldDefaultValue,
    ParentId ,IsRequiredField ,ISDynamicReporting,
    QueueId, IsEditable,
    ExpressionWithId, ExpressionWithQuestion, TimestampId)
   SELECT T.item.value('(ID)[1]', 'VARCHAR(20)'), T.item.value('(SO)[1]', 'VARCHAR(5)'),
    T.item.value('(QO)[1]', 'VARCHAR(5)'),  T.item.value('(TI)[1]', 'VARCHAR(5)'), T.item.value('(HT)[1]', 'VARCHAR(1000)'),
    T.item.value('(DT)[1]', 'VARCHAR(5)'),  T.item.value('(DVI)[1]', 'VARCHAR(20)'), T.item.value('(DV)[1]', 'VARCHAR(500)'),
    T.item.value('(PI)[1]', 'VARCHAR(20)'), T.item.value('(RQ)[1]', 'VARCHAR(5)'), T.item.value('(DR)[1]', 'VARCHAR(5)'),
    T.item.value('(QI)[1]', 'VARCHAR(20)'), T.item.value('(IE)[1]', 'VARCHAR(5)'),
    T.item.value('(EWI)[1]', 'VARCHAR(1000)'), T.item.value('(EWQ)[1]', 'VARCHAR(1000)'), T.item.value('(TST)[1]', 'VARCHAR(5)')
   FROM @MyXML.nodes('FormFieldXML/R') AS T(item)
   SET @FieldCount=@@ROWCOUNT

   /** Delete dummy section */
   DELETE FROM @FormSectionXML_TempTable WHERE SectionOrdering = '0' OR SectionOrdering = ''

   /** Avoid null or zero values in SectionOrdering*/
   UPDATE @FormFieldXML_TempTable SET SectionOrdering = NULL WHERE SectionOrdering = '0' OR SectionOrdering = 'null' OR SectionOrdering = ''

   /** Avoid null or zero values in TimestampId*/
   UPDATE @FormFieldXML_TempTable SET TimestampId = NULL WHERE TimestampId = '0' OR TimestampId = 'null' OR TimestampId = ''

   /** Avoid null or zero values in ExpressionWithId and ExpressionWithQuestion*/
   UPDATE @FormFieldXML_TempTable SET ExpressionWithId = NULL, ExpressionWithQuestion = NULL WHERE ExpressionWithId = '0' OR ExpressionWithId = 'null' OR ExpressionWithId = ''

   /** Avoid null or zero values in ParentId*/
   UPDATE @FormFieldXML_TempTable SET ParentId = NULL WHERE ParentId = '0' OR ParentId = 'null' OR ParentId = ''

   /** Avoid null or zero values in FieldSize*/
   UPDATE @FormFieldXML_TempTable SET FieldSize = NULL WHERE FieldSize = '0' OR FieldSize = 'null' OR FieldSize = ''

   /** Avoid null or zero values in QueueId*/
   UPDATE @FormFieldXML_TempTable SET QueueId = NULL WHERE QueueId = '0' OR QueueId = 'null' OR QueueId = ''

   /** Avoid null or zero values in FieldDefaultValueId*/
   UPDATE @FormFieldXML_TempTable SET FieldDefaultValueId = NULL WHERE FieldDefaultValueId = '0' OR FieldDefaultValueId = 'null' OR FieldDefaultValueId = ''

  END

  -- INSERT SECTION --
   /** insert forms */
   INSERT INTO FORMS(OrgId, FormName, IsTimeStamp, IsDynamicReporting, IsGeoValidation, IsStoreStamp, IsApplyToCompliance, CreatedBy)
   VALUES(@P_OrgId, @P_Name, @P_IsTimeStamp, @P_IsDynamicReporting, @P_IsGeoValidation, @P_IsStoreStamp, @P_IsApplyToCompliance, @P_UserId)
   SET @FormId = SCOPE_IDENTITY()
   
   SELECT FieldDefaultValue FROM @FormFieldXML_TempTable WHERE FieldDefaultValue IS NOT NULL AND LEN(FieldDefaultValue) > 0

  WHILE @SectionCount > 0
  BEGIN

   /** Insert into section one by one */
 --step 1.
   INSERT INTO FormSection(FormId, SectionName, SectionOrdering, SectionDescription)
   SELECT TOP 1 @FormId, SectionName, SectionOrdering, SectionDescription
   FROM @FormSectionXML_TempTable
 --step 2.
   SET @SectionId = SCOPE_IDENTITY()
   SET @SectionOrdering = (SELECT TOP 1 SectionOrdering FROM @FormSectionXML_TempTable)
   --PRINT '@SectionOrdering: '+ str(@SectionOrdering)
 --step 3.   PRINT '@FieldId: '+ str(@FieldId)
   /** insert into field table section by section fields */
   INSERT INTO FormFields(FormId, FormSectionId, FieldOrdering, FieldTypeId, FieldName, FieldSize,
       FieldDefaultValueId, IsRequiredField, QueueId, IsEditable, ExpressionWithId, ExpressionWithQuestion, TimestampId)
   SELECT @FormId, @SectionId, FieldOrdering, FieldTypeId, FieldName, FieldSize,
     FieldDefaultValueId, IsRequiredField, QueueId, IsEditable, ExpressionWithId, ExpressionWithQuestion, TimestampId
   FROM @FormFieldXML_TempTable WHERE SectionOrdering = '-'+LTRIM(STR(@SectionOrdering))


   SET @FieldId = SCOPE_IDENTITY()
 --step 4.

   DELETE FROM @FormFieldXML_TempTable WHERE SectionOrdering = '-'+LTRIM(STR(@SectionOrdering))
   DELETE FROM @FormSectionXML_TempTable WHERE SectionOrdering = @SectionOrdering


   SET @SectionCount = @SectionCount-1
  END

  IF @FormId > 0 AND @FieldId > 0
  BEGIN
   /** insert the field without section, queue should be the under section */
   SELECT @FormId, FieldOrdering, FieldTypeId, FieldName, FieldSize,
     FieldDefaultValueId, IsRequiredField, QueueId, IsEditable, ExpressionWithId, ExpressionWithQuestion, TimestampId
   FROM @FormFieldXML_TempTable

   INSERT INTO FormFields(FormId, FieldOrdering, FieldTypeId, FieldName, FieldSize,
       FieldDefaultValueId, IsRequiredField, QueueId, IsEditable, ExpressionWithId, ExpressionWithQuestion, TimestampId)
   SELECT @FormId, FieldOrdering, FieldTypeId, FieldName, FieldSize,
     FieldDefaultValueId, IsRequiredField, QueueId, IsEditable, ExpressionWithId, ExpressionWithQuestion, TimestampId
   FROM @FormFieldXML_TempTable

   /** Store the formid into defaultvalue table */
   /*
   UPDATE FieldDefaultValues SET FormId = @FormId
    WHERE FieldDefaultValueId IN (SELECT DISTINCT FormFields.FieldDefaultValueId FROM FieldDefaultValues
    INNER JOIN FormFields ON FormFields.FieldDefaultValueId = FieldDefaultValues.FieldDefaultValueId
    WHERE FormFields.FormId = @FormId)
  */
  UPDATE fdv
	SET fdv.FormId = @FormId
	FROM FieldDefaultValues fdv
			INNER JOIN FormFields ff ON ff.FieldDefaultValueId = fdv.FieldDefaultValueId
    WHERE ff.FormId = @FormId


   /** Store the workflow map */
   INSERT INTO WorkflowMap(
	WorkflowId, 
	QueueId, 
	FormId, 
	SectionId, 
	FormFieldId)
   SELECT 
    wf.WorkflowId, 
    ff.QueueId, 
    @FormId, 
    ff.FormSectionId, 
    ff.FormFieldId
   FROM 
    FormFields ff
      INNER JOIN Workflow wf ON wf.WorkflowName = ff.FieldName
   WHERE 
    ff.FormId = @FormId 
    AND ff.QueueId > 0 
    AND wf.OrgId = @P_OrgId
   --we eliminate the workflow field which is actually the workflow name and must not be treated as a workflow object(is case it's a reserved workflow name)
    AND NOT EXISTS (SELECT 1 FROM FieldType ft WHERE ft.FieldName='WorkflowField' AND ff.FieldTypeId = ft.FieldTypeId)

   /** organization level map */
   INSERT INTO FormLevelMap(FormId, OrgLevelMapId)
   SELECT @FormId, OrgLevelMapId
   FROM @OrganizationXML_TempTable WHERE OrgLevelMapId > 0

   /** hierarchy level map */
   INSERT INTO FormLevelMap(FormId, BusinessRoleId)
   SELECT @FormId, BusinessRoleId
   FROM @HierarchyXML_TempTable WHERE BusinessRoleId > 0

   /** Account level map */
   INSERT INTO FormLevelMap(FormId, AccountId)
   SELECT @FormId, AccountId
   FROM @AccountXML_TempTable WHERE AccountId > 0
  END
  
   /** COMMIT THE TRANSACTION */
   IF @@trancount > 0
   BEGIN
    PRINT 'COMMIT TRANSACTION'
    COMMIT TRANSACTION
	SET @P_Form_Status = 1
   END
   ELSE
   BEGIN
    PRINT 'ROLLBACK TRANSACTION'
    ROLLBACK TRANSACTION
	SET @P_Form_Status = 0
   END


  END TRY
  BEGIN CATCH
   --PRINT '@P_Form_Status: ' + STR(@P_Form_Status)
   PRINT 'ROLLBACK TRANSACTION'
   ROLLBACK TRANSACTION
   SET @P_Form_Status = 0
   /** CATCH THE ERROR DETAILS */
		DECLARE @ErrorMsg nvarchar(max);
		SET @ErrorMsg=	'ErrorNumber    = ' + CAST(ERROR_NUMBER() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorSeverity  = ' + CAST(ERROR_SEVERITY() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorState     = ' + CAST(ERROR_STATE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorProcedure = ' + CAST(ERROR_PROCEDURE() AS nvarchar(max)) + CHAR(13) + CHAR(10) +
						'ErrorLine		= ' + CAST(ERROR_LINE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorMessage	= ' + CAST(ERROR_MESSAGE() AS nvarchar(max)) + CHAR(13) + CHAR(10)
		PRINT @ErrorMsg;

  END CATCH
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DynamicForm_Creator_Update' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DynamicForm_Creator_Update]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DynamicForm_Creator_Update]    Script Date: 3/2/2015 6:36:40 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- EXEC [DynamicForm_Creator_Update] '', '22','1', 'Check box test', '0', '0','0','0','<OrganizationXML><R><ID>1</ID></R><R><ID>5</ID></R><R><ID>2</ID></R><R><ID>6</ID></R><R><ID>9</ID></R><R><ID>21</ID></R><R><ID>22</ID></R><R><ID>23</ID></R><R><ID>12</ID></R><R><ID>17</ID></R><R><ID>13</ID></R><R><ID>18</ID></R><R><ID>10</ID></R><R><ID>7</ID></R><R><ID>19</ID></R><R><ID>20</ID></R><R><ID>3</ID></R><R><ID>4</ID></R></OrganizationXML>','<HierarchyXML><R><ID>1</ID></R><R><ID>2</ID></R><R><ID>8</ID></R><R><ID>9</ID></R><R><ID>10</ID></R><R><ID>12</ID></R></HierarchyXML>','<AccountXML><R><ID></ID></R></AccountXML>','<FormSectionXML><R><ID>-2</ID><SN>sfsdf</SN><SO>1</SO><SD>sdfsd</SD></R></FormSectionXML>','<FormFieldXML><R><ID>239</ID><SO>0</SO><QO>1</QO><TI>2</TI><HT>Sec 1</HT><DT>0</DT><DVI>0</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>0</IE></R><R><ID>240</ID><SO>0</SO><QO>2</QO><TI>12</TI><HT>sawe</HT><DT>0</DT><DVI>0</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>0</IE></R><R><ID>241</ID><SO>0</SO><QO>3</QO><TI>3</TI><HT>combosec2</HT><DT>0</DT><DVI>7</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>0</IE></R><R><ID>242</ID><SO>0</SO><QO>4</QO><TI>3</TI><HT>combosec2</HT><DT>0</DT><DVI>7</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>0</IE></R><R><ID>243</ID><SO>0</SO><QO>5</QO><TI>3</TI><HT>combosec3</HT><DT>0</DT><DVI>7</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>0</IE></R><R><ID>244</ID><SO>0</SO><QO>6</QO><TI>1</TI><HT>dbcb</HT><DT>225</DT><DVI>0</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>1</IE></R><R><ID>245</ID><SO>0</SO><QO>7</QO><TI>5</TI><HT>sfsfsdf</HT><DT>0</DT><DVI>4</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>1</IE></R><R><ID>246</ID><SO>0</SO><QO>8</QO><TI>6</TI><HT>Pending</HT><DT>0</DT><DVI>4</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>1</IE></R><R><ID>247</ID><SO>0</SO><QO>9</QO><TI>6</TI><HT>Completed</HT><DT>0</DT><DVI>4</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>1</IE></R><R><ID>248</ID><SO>0</SO><QO>10</QO><TI>6</TI><HT>Cancelled</HT><DT>0</DT><DVI>4</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>1</IE></R><R><ID>null</ID><SO>-2</SO><QO>11</QO><TI>2</TI><HT>sfsdf</HT><DT></DT><DVI>0</DVI><DV></DV><PI>0</PI><RQ>0</RQ><DR>0</DR><QI>0</QI><IE>0</IE></R></FormFieldXML>', '', '', '', ''
CREATE PROCEDURE [dbo].[DynamicForm_Creator_Update](
	@P_OrgId INT,
	@P_Id VARCHAR(20),
	@P_UserId VARCHAR(50),
	@P_Name VARCHAR(200),
	@P_IsTimeStamp VARCHAR(5)='',
	@P_IsDynamicReporting VARCHAR(5)='',
	@P_IsGeoValidation VARCHAR(5)='',
	@P_IsStoreStamp VARCHAR(5)='',
	@P_IsApplyToCompliance VARCHAR(5)='',

	/** XML data */
	@P_OrganizationXML VARCHAR(MAX)='',
	@P_BusinessRoleXML VARCHAR(MAX)='',
	@P_AccountXML VARCHAR(MAX)='',
	@P_FormSectionXML VARCHAR(MAX)='',
	@P_FormFieldXML VARCHAR(MAX)='',

	/** OUTPUT PARAMS*/
	@P_Form_Status INT OUT,
	@P_ErrorProcedure VARCHAR(100) OUT,
	@P_ErrorLine VARCHAR(15) OUT,
	@P_ErrorMessage NVARCHAR(MAX) OUT
)
AS
SET NOCOUNT ON
BEGIN

	DECLARE @MyXML XML
  
	DECLARE @WorkflowTypeId TABLE(
		FieldOrdering INT,
		QueueId INT
	)
	
	/**************************************************/
	/* CREATE @OrganizationXML_TempTable - 1          */
	/**************************************************/
	
	DECLARE @OrganizationXML_TempTable TABLE (
		OrgLevelMapId INT
	)  
	
	/**************************************************/
	/* CREATE @BusinessRoleXML_TempTable - 2             */
	/**************************************************/

	DECLARE @BusinessRoleXML_TempTable TABLE (
		BusinessRoleId INT
	)
	
	/**************************************************/
	/* CREATE @AccountXML_TempTable - 3               */
	/**************************************************/

	DECLARE @AccountXML_TempTable TABLE (
		AccountId INT
	)
	
	/**************************************************/
	/* CREATE @SectionXML_TempTable - 4               */
	/**************************************************/

	DECLARE @FormSectionXML_TempTable TABLE (
		UniqueId INT IDENTITY(1, 1),
		FormSectionId INT,
		SectionName VARCHAR(100), 
		SectionOrdering INT, 
		SectionDescription VARCHAR(500)
	)

	/**************************************************/
	/* CREATE @FormFieldXML_TempTable - 5             */
	/**************************************************/


	DECLARE @FormFieldXML_TempTable TABLE (
		FormFieldId INT, 
		FormSectionId INT,
		FieldOrdering INT, 
		FieldTypeId INT, 
		FieldName VARCHAR(1000),
		FieldSize INT, 
		FieldDefaultValueId INT, 
		FieldDefaultValue VARCHAR(500),
		ParentId INT,
		IsRequiredField INT, 
		ISDynamicReporting INT,
		QueueId INT, 
		IsEditable INT,
		ExpressionWithId VARCHAR(1000), 
		ExpressionWithQuestion VARCHAR(1000), 
		TimestampId INT
	)

   
	BEGIN TRY
		BEGIN TRANSACTION
		
		SET @P_Form_Status = 0

		/*-------------------------------------- Populate Temporary Tables -------------------------------------------*/


		IF(@P_OrganizationXML != '' AND @P_BusinessRoleXML != '' AND @P_AccountXML != '' AND @P_FormSectionXML != '' AND @P_FormFieldXML != '')
		BEGIN

			/**************************************************/
			/* Populate @OrganizationXML_TempTable from XML   */
			/**************************************************/

			SET @MyXML = @P_OrganizationXML
   
			INSERT INTO @OrganizationXML_TempTable(OrgLevelMapId)
				SELECT T.item.value('(ID)[1]', 'INT')
					FROM @MyXML.nodes('OrganizationXML/R') AS T(item)

			/**************************************************/
			/* Populate @BusinessRoleXML_TempTable from XML      */
			/**************************************************/

			SET @MyXML = @P_BusinessRoleXML

			INSERT INTO @BusinessRoleXML_TempTable(BusinessRoleId)
				SELECT T.item.value('(ID)[1]', 'INT')
					FROM @MyXML.nodes('HierarchyXML/R') AS T(item)

			/**************************************************/
			/* Populate @AccountXML_TempTable from XML        */
			/**************************************************/

			SET @MyXML = @P_AccountXML
   
			INSERT INTO @AccountXML_TempTable(AccountId)
				SELECT T.item.value('(ID)[1]', 'INT')
					FROM @MyXML.nodes('AccountXML/R') AS T(item)

   
			/**************************************************/
			/* Populate @FormSectionXML_TempTable from XML    */
			/**************************************************/

			SET @MyXML = @P_FormSectionXML

			INSERT INTO @FormSectionXML_TempTable(FormSectionId, SectionName, SectionOrdering, SectionDescription)
				SELECT 
						CAST(CASE WHEN T.item.value('(ID)[1]', 'VARCHAR(20)') NOT IN ('null', '-') THEN T.item.value('(ID)[1]', 'VARCHAR(20)')
								ELSE null 
							END AS INT) AS FormSectionId
						,T.item.value('(SN)[1]', 'VARCHAR(100)') AS SectionName
						,CAST(T.item.value('(SO)[1]', 'VARCHAR(5)') AS INT) AS SectionOrdering
						,T.item.value('(SD)[1]', 'VARCHAR(500)') AS SectionDescription
					FROM @MyXML.nodes('FormSectionXML/R') AS T(item)
   
			/**************************************************/
			/* Populate @FormFieldXML_TempTable from XML      */
			/**************************************************/

			/** TODO - newly field added for dynamic calculation AND TIMESTAMP :: (ExpressionWithId and ExpressionWithQuestion) AND TimestampId */
			SET @MyXML = @P_FormFieldXML
   
			INSERT INTO @FormFieldXML_TempTable(FormFieldId, FormSectionId,
					FieldOrdering, FieldTypeId , FieldName ,
					FieldSize, FieldDefaultValueId, FieldDefaultValue,
					ParentId ,IsRequiredField ,ISDynamicReporting,
					QueueId, IsEditable,
					ExpressionWithId, ExpressionWithQuestion, TimestampId)
			 SELECT CAST(CASE WHEN T.item.value('(ID)[1]', 'VARCHAR(20)') <> 'null' THEN T.item.value('(ID)[1]', 'VARCHAR(20)')
							ELSE null
						END AS INT) AS FormFieldId
					,CAST(CASE WHEN T.item.value('(SO)[1]', 'VARCHAR(5)') NOT IN ('null', '0', '') THEN T.item.value('(SO)[1]', 'VARCHAR(5)')
							ELSE null
						END AS INT) AS FormSectionId
					,CAST(CASE WHEN T.item.value('(QO)[1]', 'VARCHAR(5)') <> 'null' THEN T.item.value('(QO)[1]', 'VARCHAR(5)')
							ELSE null
						END AS INT) AS FieldOrdering
					,CAST(CASE WHEN T.item.value('(TI)[1]', 'VARCHAR(5)') <> 'null' THEN T.item.value('(TI)[1]', 'VARCHAR(5)')
							ELSE null
						END AS INT) AS FieldTypeId
					,CASE WHEN T.item.value('(HT)[1]', 'VARCHAR(1000)') <> 'null' THEN T.item.value('(HT)[1]', 'VARCHAR(1000)') 
							ELSE null
						END AS FieldName
					,CAST(CASE WHEN T.item.value('(DT)[1]', 'VARCHAR(5)') <> 'null' THEN T.item.value('(DT)[1]', 'VARCHAR(5)')
							ELSE null
						END AS INT) AS FieldSize
					,CAST(CASE WHEN T.item.value('(DVI)[1]', 'VARCHAR(20)') NOT IN ('null', '0', '') THEN T.item.value('(DVI)[1]', 'VARCHAR(20)')
							ELSE null
						END AS INT) AS FieldDefaultValueId
					,CASE WHEN T.item.value('(DV)[1]', 'VARCHAR(500)') NOT IN ('null', '0', '') THEN T.item.value('(DV)[1]', 'VARCHAR(500)') 
							ELSE null
						END AS FieldDefaultValue
					,CAST(CASE WHEN T.item.value('(PI)[1]', 'VARCHAR(20)') NOT IN ('null', '0', '') THEN T.item.value('(PI)[1]', 'VARCHAR(20)')
							ELSE null
						END AS INT) AS ParentId
					,CAST(CASE WHEN T.item.value('(RQ)[1]', 'VARCHAR(5)') <> 'null' THEN T.item.value('(RQ)[1]', 'VARCHAR(5)')
							ELSE null
						END AS INT) AS IsRequiredField
					,CAST(CASE WHEN T.item.value('(DR)[1]', 'VARCHAR(5)') <> 'null' THEN T.item.value('(DR)[1]', 'VARCHAR(5)')
							ELSE null
						END AS INT) AS ISDynamicReporting
					,CAST(CASE WHEN T.item.value('(QI)[1]', 'VARCHAR(20)') NOT IN ('null', '0', '') THEN T.item.value('(QI)[1]', 'VARCHAR(20)')
							ELSE null
						END AS INT) AS QueueId
					,CAST(CASE WHEN T.item.value('(IE)[1]', 'VARCHAR(5)') <> 'null' THEN T.item.value('(IE)[1]', 'VARCHAR(5)')
							ELSE null
						END AS INT) AS IsEditable
					,CASE WHEN T.item.value('(EWI)[1]', 'VARCHAR(1000)') NOT IN ('null', '0', '') THEN T.item.value('(EWI)[1]', 'VARCHAR(1000)')
							ELSE null
						END AS ExpressionWithId
					,CASE WHEN T.item.value('(EWQ)[1]', 'VARCHAR(1000)') NOT IN ('null', '0', '') THEN T.item.value('(EWQ)[1]', 'VARCHAR(1000)')
							ELSE null
						END AS ExpressionWithQuestion
					,CAST(CASE WHEN T.item.value('(TST)[1]', 'VARCHAR(5)') NOT IN ('null', '0', '') THEN T.item.value('(TST)[1]', 'VARCHAR(5)')
							ELSE null
						END AS INT) AS TimestampId
				FROM @MyXML.nodes('FormFieldXML/R') AS T(item)

        /** Delete dummy section */
        DELETE FROM @FormSectionXML_TempTable WHERE FormSectionId = 0 OR FormSectionId = ''

        /** Avoid null or zero values in SectionOrdering */
        UPDATE @FormFieldXML_TempTable SET FormSectionId = NULL WHERE FormSectionId = 0 OR FormSectionId IS NULL

        /** Avoid null or zero values in TimestampId */
        UPDATE @FormFieldXML_TempTable SET TimestampId = NULL WHERE TimestampId = 0 OR TimestampId IS NULL

        /** Avoid null or zero values in ExpressionWithId and ExpressionWithQuestion */
        UPDATE @FormFieldXML_TempTable SET ExpressionWithId = NULL, ExpressionWithQuestion = NULL WHERE ExpressionWithId = 0 OR ExpressionWithId IS NULL

        /** Avoid null or zero values in ParentId */
        UPDATE @FormFieldXML_TempTable SET ParentId = NULL WHERE ParentId = 0 OR ParentId IS NULL

        /** Avoid null or zero values in FieldSize */
        UPDATE @FormFieldXML_TempTable SET FieldSize = NULL WHERE FieldSize = 0 OR FieldSize IS NULL

        /** Avoid null or zero values in QueueId */
        UPDATE @FormFieldXML_TempTable SET QueueId = NULL WHERE QueueId = 0 OR QueueId IS NULL

        /** Avoid null or zero values in FieldDefaultValueId */
        UPDATE @FormFieldXML_TempTable SET FieldDefaultValueId = NULL WHERE FieldDefaultValueId = 0

      END

		/*------------------------------------------------- PROCESSING -----------------------------------------------*/

		/*
		*  ATTENTION:
		*  Data integrity is kept from the portal side by sending us FormFields linked to newly created sections via
		*  negative FormSectionId(s).
		* */

		/**************************************************/
		/* Update form                                    */
		/**************************************************/

		UPDATE f 
			SET	f.FormName = @P_Name, 
				f.IsTimeStamp = @P_IsTimeStamp, 
				f.IsDynamicReporting = @P_IsDynamicReporting,
				f.IsGeoValidation = @P_IsGeoValidation,
				f.UpdatedBy = @P_UserId, 
				f.UpdatedOn = GETDATE()
			FROM Forms f
			WHERE 
				f.FormId = @P_Id
		/*
		* ATTENTION:
		* Handling of sections: because we aren't able to capture the Identity column of newly created sections together
		* with the passed "dummy" section ID (INSERT - OUTPUT with FROM fields doesn't work in SQL SERVER 2005) IT IS
		* CRITICAL that the sections ARE FIRST deleted / updated AND only afterwards inserted.
		*/

		/**************************************************/
		/* Set to inactive deleted sections               */
		/**************************************************/
		;WITH CommonSections_CTE AS (
			-- We need to filter out the newly inserted sections
			SELECT
				FormSectionId
			FROM @FormSectionXML_TempTable
			WHERE FormSectionId > 0
		)
		UPDATE fs
			SET fs.IsActive = 0
		FROM FormSection fs
			LEFT JOIN CommonSections_CTE cs_c ON cs_c.FormSectionId = fs.FormSectionId
		WHERE 1 = 1
			AND fs.Formid = @P_Id
			AND cs_c.FormSectionId IS NULL

		/**************************************************/
		/* Update form sections                           */
		/**************************************************/

		UPDATE fs
		SET	fs.SectionName = fsx_tt.SectionName,
			fs.SectionDescription = fsx_tt.SectionDescription,
			fs.SectionOrdering = fsx_tt.SectionOrdering
		FROM @FormSectionXML_TempTable fsx_tt
			INNER JOIN FormSection fs ON fsx_tt.FormSectionId = fs.FormSectionId
		WHERE
			fs.FormId = @P_Id

		/**************************************************/
		/* Insert new sections in FormSection             */
		/**************************************************/

		-- We have to capture the newly assigned FormSectionId so that we will use them latter in FormField updates

		DECLARE @InsertedSections_TemporaryTable TABLE (
			InsertedFormSectionId INT,
			NegativeFormSectionId INT
		)

		INSERT INTO FormSection(FormId, SectionName, SectionOrdering, SectionDescription)
		SELECT
			@P_Id,
			fsx_tt.SectionName,
			fsx_tt.SectionOrdering,
			fsx_tt.SectionDescription
		FROM @FormSectionXML_TempTable fsx_tt
		WHERE fsx_tt.FormSectionId < 0

		-- For one FormId, the SectionOrdering number is unique - it represent the order of the section so it can be
		-- used like a secondary key based on which we can join; we will use this as a key so that we are joining
		-- on the section ordering to retrieve the [newly] inserted sections.
		INSERT INTO @InsertedSections_TemporaryTable(InsertedFormSectionId, NegativeFormSectionId)
		SELECT
			fs.FormSectionId,
			fsx_tt.FormSectionId
		FROM FormSection fs
			INNER JOIN @FormSectionXML_TempTable fsx_tt ON fsx_tt.SectionOrdering = fs.SectionOrdering
		WHERE 1 = 1
			AND fs.FormId = @P_Id
			AND fs.isActive = 1
		  	AND fsx_tt.FormSectionId < 0

  --DECLARE @Msg nvarchar(max);
  --SET @Msg= "Inserted into InsertedSections_TemporaryTable";
  PRINT 'Inserted into InsertedSections_TemporaryTable';

		/**************************************************/
		/* Disable deleted fields                         */
		/**************************************************/

		;WITH CommonFields_CTE AS (
			-- We need to filter out the null ID values from the newly inserted fields
			SELECT
				FormFieldId
			FROM @FormFieldXML_TempTable
			WHERE FormFieldId IS NOT NULL
		)
		UPDATE FormFields
		SET isActive = 0
		FROM FormFields ff
			LEFT JOIN CommonFields_CTE cf_c ON cf_c.FormFieldId = ff.FormFieldId
		WHERE 1 = 1
		  	AND ff.FormId = @P_Id
			AND cf_c.FormFieldId IS NULL

		/**************************************************/
		/* Update form fields                             */
		/**************************************************/

		UPDATE ff
			SET ff.FormSectionId = ISNULL(in_tt.InsertedFormSectionId, ffx_tt.FormSectionId),
				ff.FieldOrdering = ffx_tt.FieldOrdering,
				ff.FieldName = ffx_tt.FieldName,
				ff.FieldDefaultValueId = ffx_tt.FieldDefaultValueId,
				ff.IsRequiredField = ffx_tt.IsRequiredField,
				ff.QueueId = ffx_tt.QueueId,
				ff.ParentFieldId = ffx_tt.ParentId,
				ff.IsDynamicReport = ffx_tt.ISDynamicReporting,
				ff.IsEditable = ffx_tt.IsEditable,
				ff.ExpressionWithId = ffx_tt.ExpressionWithId,
				ff.ExpressionWithQuestion = ffx_tt.ExpressionWithQuestion,
				ff.TimestampId = ffx_tt.TimestampId,
				ff.FieldSize = ffx_tt.FieldSize,
				ff.IsActive = CASE
								WHEN ffx_tt.FormFieldId IS NULL THEN 0
								ELSE 1
							  END
			FROM FormFields ff
				INNER JOIN @FormFieldXML_TempTable ffx_tt ON ff.FormFieldId = ffx_tt.FormFieldId AND ff.FormId = @P_Id
				LEFT JOIN @InsertedSections_TemporaryTable in_tt ON in_tt.NegativeFormSectionId = ffx_tt.FormSectionId

    --SET @Msg= "Updated FormFields";
    PRINT 'Updated FormFields';

		/**************************************************/
		/* Insert new fields                              */
		/**************************************************/

		INSERT INTO FormFields(
			FormId,
			FormSectionId,
			FieldOrdering,
			FieldTypeId,
			FieldName,
			FieldSize,
			FieldDefaultValueId,
			IsRequiredField,
			QueueId,
			IsEditable,
			ExpressionWithId,
			ExpressionWithQuestion,
			TimestampId)
			SELECT
					@P_Id,
					FormSectionId = ISNULL(is_tt.InsertedFormSectionId, ffx_tt.FormSectionId),
					ffx_tt.FieldOrdering,
					ffx_tt.FieldTypeId,
					ffx_tt.FieldName,
					ffx_tt.FieldSize,
					ffx_tt.FieldDefaultValueId,
					ffx_tt.IsRequiredField,
					ffx_tt.QueueId,
					ffx_tt.IsEditable,
					ffx_tt.ExpressionWithId,
					ffx_tt.ExpressionWithQuestion,
					ffx_tt.TimestampId
				FROM @FormFieldXML_TempTable AS ffx_tt
					LEFT JOIN @InsertedSections_TemporaryTable is_tt ON is_tt.NegativeFormSectionId = ffx_tt.FormSectionId
				WHERE
					ffx_tt.FormFieldId IS NULL

		/**************************************************/
		/* ------------ WorkflowMap Begin --------------- */
		/**************************************************/

		/**************************************************/
		/* Delete workflow map and freshly add workflow	  */
		/* map because user might be create workflow when */
		/* editing form                                   */
		/**************************************************/

		DELETE FROM WorkflowMap 
			WHERE FormId = @P_Id

		/**************************************************/
		/* This fixed for Workflow fields QueueId empty   */
		/* time (after implement workflow type            */
		/**************************************************/

		INSERT INTO @WorkflowTypeId(FieldOrdering, QueueId)
			SELECT 
					ff.Fieldordering, 
					ff.QueueId 
				FROM FormFields ff
					INNER JOIN FieldType ft ON ft.FieldTypeId = ff.FieldTypeId AND ft.FieldName = 'WorkflowField'
				WHERE ff.FormId = @P_Id 
					AND ff.IsActive = 1
				ORDER BY ff.FieldOrdering
   
		DECLARE @WorkflowTypeIdCount INT, 
				@TempQueueId INT, 
				@TempFieldOrdering INT

		SET @WorkflowTypeIdCount = 0
		SET @TempQueueId = 0
		SET @TempFieldOrdering = 0

		SELECT @WorkflowTypeIdCount = COUNT(1) 
			FROM @WorkflowTypeId

		WHILE(@WorkflowTypeIdCount > 0)
		BEGIN
			SELECT 
					@TempQueueId  = QueueId, 
					@TempFieldOrdering = FieldOrdering 
				FROM 
					@WorkflowTypeId
				WHERE Fieldordering = (SELECT TOP (1) Fieldordering FROM @WorkflowTypeId)

			UPDATE FormFields 
				SET QueueId = @TempQueueId
				WHERE 
					FormId = @P_Id
					AND FieldOrdering IN (SELECT TOP (6) FieldOrdering 
												FROM Formfields 
												WHERE FormId = @P_Id 
													AND IsActive = 1 
													AND FieldOrdering > @TempFieldOrdering 
												ORDER BY FieldOrdering
										)

			DELETE @WorkflowTypeId 
				WHERE Fieldordering = @TempFieldOrdering
			
			SELECT @WorkflowTypeIdCount = COUNT(1) 
				FROM @WorkflowTypeId

		END

		/**************************************************/
		/* Added the workflow map                         */
		/**************************************************/

		INSERT INTO WorkflowMap(
				WorkflowId, 
				QueueId,
				FormId, 
				SectionId, 
				FormFieldId)
			SELECT 
					wf.WorkflowId, 
					ff.QueueId, 
					@P_Id, 
					ff.FormSectionId, 
					ff.FormFieldId
				FROM 
					FormFields ff
						INNER JOIN Workflow wf ON wf.WorkflowName = ff.FieldName
				WHERE 
					ff.FormId = @P_Id 
					AND ff.QueueId > 0  
					AND wf.OrgId = @P_OrgId
					-- we eliminate the workflow field which is actually the workflow name and must not be treated as
					-- a workflow object(is case it's a reserved workflow name)
					AND NOT EXISTS (SELECT 1 
										FROM FieldType ft 
										WHERE ft.FieldName = 'WorkflowField' 
											AND ft.FieldTypeId = ff.FieldTypeId
									)

		/**************************************************/
		/* -------------- WorkflowMap End --------------- */
		/**************************************************/

		/**************************************************/
		/* Delete existing all level id based on formId   */
		/**************************************************/

		DELETE FormLevelMap 
			WHERE FormId = @P_Id


		/**************************************************/
		/* Organization level map                         */
		/**************************************************/

		INSERT INTO FormLevelMap(FormId, OrgLevelMapId)
			SELECT @P_Id
					,OrgLevelMapId
				FROM @OrganizationXML_TempTable 
				WHERE OrgLevelMapId > 0

		/**************************************************/
		/* BusinessRole level map                            */
		/**************************************************/

		INSERT INTO FormLevelMap(FormId, BusinessRoleId)
			SELECT @P_Id
					,BusinessRoleId
				FROM @BusinessRoleXML_TempTable 
				WHERE BusinessRoleId > 0

		/**************************************************/
		/* Account level map                              */
		/**************************************************/

		INSERT INTO FormLevelMap(FormId, AccountId)
			SELECT @P_Id
					,AccountId
				FROM @AccountXML_TempTable 
				WHERE AccountId > 0
  
		/**************************************************/
		/**          COMMIT THE TRANSACTION              **/
		/**************************************************/

		IF @@trancount > 0
		BEGIN
			PRINT 'COMMIT TRANSACTION'
			COMMIT TRANSACTION
			SET @P_Form_Status = 1
		END
		ELSE
		BEGIN
			PRINT 'ROLLBACK TRANSACTION'
			ROLLBACK TRANSACTION
			SET @P_Form_Status = 0
		END

	END TRY
	BEGIN CATCH
		--PRINT '@P_Form_Status: ' + STR(@P_Form_Status)
		PRINT 'ROLLBACK TRANSACTION BOGDAN'
		ROLLBACK TRANSACTION
		SET @P_Form_Status = 0
		
		/**************************************************/
		/**        CATCH THE ERROR DETAILS               **/
		/**************************************************/

		DECLARE @ErrorMsg nvarchar(max);
		SET @ErrorMsg =	'ErrorNumber    = ' + CAST(ERROR_NUMBER() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorSeverity  = ' + CAST(ERROR_SEVERITY() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorState     = ' + CAST(ERROR_STATE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorProcedure = ' + CAST(ERROR_PROCEDURE() AS nvarchar(max)) + CHAR(13) + CHAR(10) +
						'ErrorLine		= ' + CAST(ERROR_LINE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorMessage	= ' + CAST(ERROR_MESSAGE() AS nvarchar(max)) + CHAR(13) + CHAR(10)
		PRINT @ErrorMsg;

	END CATCH
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DynamicForm_Generator' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DynamicForm_Generator]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DynamicForm_Generator]    Script Date: 3/2/2015 6:36:41 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DynamicForm_Generator] (
	@P_Action_Type VARCHAR(50)
	,@P_UserId VARCHAR(50)
	,@P_FormId VARCHAR(20)
	,@P_StoreId VARCHAR(50)
	,@P_TimeIn VARCHAR(50)
	,@P_TimeOut VARCHAR(50)
	,@P_gpsLatitude VARCHAR(50)
	,@P_gpsLongitude VARCHAR(50)
	,@P_gpsGeofenceDistance VARCHAR(50)
	,@P_gpsInsideGeofence VARCHAR(50)
	,@P_gpsGeofenceMessage VARCHAR(50)
	,@P_description VARCHAR(500)
	,@P_version VARCHAR(50)
	,@p_deviceName VARCHAR(50)
	,@P_deviceVersion VARCHAR(50)
	,@P_deviceModel VARCHAR(50)
	,@P_XML VARCHAR(MAX)
	,@P_Form_Status VARCHAR(10) OUT
	,@P_PicturesList VARCHAR(MAX) OUT
	,@P_Msg nvarchar(max) OUT
	)
AS
SET NOCOUNT ON
BEGIN
	DECLARE @MyXML XML
	DECLARE @FormVisitId INT
	DECLARE @P_WorkflowPointer_ID INT
	DECLARE @wid INT
	DECLARE @OrgId INT
	DECLARE @StoreFormVisitCount INT
	DECLARE @isApplyToCompliance BIT
	DECLARE @OwnedById INT
	DECLARE @LengthOfVisitInMinutes INT

	DECLARE @StartDate datetime
	SET @P_Msg = 'Begin Transaction'

	BEGIN TRY
		BEGIN TRANSACTION

		SET @StartDate = GETDATE();

		SELECT TOP 1 @OwnedById = sump.UserId
			FROM StoreUserMapping sump
			WHERE sump.StoreId = CAST(@P_StoreId AS INT)

		SET @P_Form_Status = 1
		SET @P_Msg = 'Success'
		SET @MyXML = @P_XML

		-- Create table for the current visit field values from FormFieldValues (created this to avoid the join with FormFieldValues)
		/*************************************************************/
		/*   Begin - Variable table section                          */
		/*************************************************************/
		
		DECLARE @FormFieldValues_Temp TABLE(
			FormFieldValueId INT
			,FormFieldId INT
			,FormVisitId INT
			,FieldValue VARCHAR(1000)
			)

		/** CREATE TEMP TABLE */
		DECLARE @DynamicFormTempTable TABLE(
			FormFieldId VARCHAR(7000)
			,FormFieldValues VARCHAR(8000)
			,PictureItemId INT
			,PicturePath VARCHAR(250)
			,PictureDescription VARCHAR(max)
			,PictureStatus BIT
			,PictureOrder SMALLINT
			,PictureCategoryId INT
			)

		DECLARE @WorkFlowPointer_Temp TABLE (
			[WorkflowPointerId] [int] IDENTITY(300300,1) NOT NULL,
			[StoreId] [int] NULL,
			[QueueId] [int] NOT NULL,
			[FormId] [int] NOT NULL,
			[SectionId] [int] NOT NULL,
			[FormVisitId] [int] NOT NULL,
			[StatusFormFieldValueId] [int] NULL,
			[DescriptionFormFieldValueId] [int] NULL,
			[ActionItem] [varchar](50) NULL,
			[Category] [varchar](100) NULL,
			[Description] [varchar](500) NULL,
			[DueDate] [varchar](100) NULL,
			[Status] [varchar](100) NULL,
			[IsMailSentFlag] [bit] NOT NULL,
			[CreatedOn] [datetime] NULL,
			[CreatedBy] [int] NULL,
			[UpdatedOn] [datetime] NULL,
			[UpdatedBy] [int] NULL
			)

		/*************************************************************/
		/*   End - Variable table section                            */
		/*************************************************************/

		/** INSERT INTO TEMP TABLE FROM XML*/
		INSERT INTO @DynamicFormTempTable (
			FormFieldId
			,FormFieldValues
			,PictureItemId
			,PicturePath
			,PictureDescription
			,PictureOrder
			,PictureCategoryId
			)
			SELECT f.value('(I)[1]', 'VARCHAR(10)') AS FormFieldId
					,f.value('(V)[1]', 'varchar(1000)') AS FormFieldValue
					,p.value('(PictureItemId)[1]', 'int') AS PictureItemId
					-- hold the PictureOrder, not the PictureItemId!
					,p.value('(Path)[1]', 'varchar(250)') AS Path
					,p.value('(Description)[1]', 'varchar(max)') AS Description
					,p.value('(PictureOrder)[1]', 'smallint') AS PictureOrder
					,i.value('.', 'int') AS CategoryId
				FROM @MyXML.nodes('DynamicFormXML/F') AS FormField(f)
					OUTER APPLY f.nodes('PictureItem') AS Pictures(p)
					OUTER APPLY p.nodes('Categories') AS Categories(c)
					OUTER APPLY c.nodes('CategoryId') AS CategoryId(i)

		--PICTURE CAPTURE CHANGES
		--SELECT distinct * FROM @DynamicFormTempTable
		/*************************************************************/
		/*   Begin - Insert section                                  */
		/*************************************************************/

		IF @P_Action_Type = 'INSERT'
			OR @P_Action_Type = 'INSERT_ADHOC_FORM'
		BEGIN
			SET @StoreFormVisitCount = 0

			IF @P_Action_Type = 'INSERT'
				BEGIN
					SELECT @StoreFormVisitCount = COUNT(0)
						FROM FormVisit fv
					WHERE fv.FormId = @P_FormId
						AND fv.UserId = @P_UserId
						AND fv.StoreId = @P_StoreId
						AND fv.TimeIn = dbo.ConvertAnyTimeTo12Format(@P_TimeIn)
						AND CONVERT(VARCHAR(10), fv.VisitDate, 121) = CONVERT(VARCHAR(10), getDate(), 121)

				END

			IF @StoreFormVisitCount > 0
				BEGIN
					SET @P_Form_Status = 0
					SET @P_Msg = 'Duplicate Visit'
				END

			IF @StoreFormVisitCount = 0
				BEGIN

					/** for adhoc form, it's not related any store */
					IF @P_StoreId = 'null'
						OR @P_StoreId = ''
						SET @P_StoreId = NULL

					IF @P_description = ''
						OR @P_description = 'null'
						SET @P_description = NULL
					SET @LengthOfVisitInMinutes = (
							SELECT CASE
									WHEN DATEDIFF(MI, CAST(@P_TimeIn AS DATETIME), CAST(@P_TimeOut AS DATETIME)) < 0
										THEN DATEDIFF(MI, CAST(@P_TimeIn AS DATETIME), CAST('11:59 PM' AS DATETIME)) + 1 + DATEDIFF(MI, CAST('12:00 AM' AS DATETIME), CAST(@P_TimeOut AS DATETIME))
									ELSE DATEDIFF(MI, CAST(@P_TimeIn AS DATETIME), CAST(@P_TimeOut AS DATETIME))
									END
							)

					INSERT INTO FormVisit (
							FormId
							,UserId
							,StoreId
							,TimeIn
							,TimeOut
							,LengthOfVisitInMinutes
							,GpsLatitude
							,GpsLongitude
							,GpsGeofenceDistance
							,GpsInsideGeofence
							,GpsGeofenceMessage
							,Version
							,DeviceName
							,DeviceVersion
							,DeviceModel
							,CreatedBy
							,Description
							,UserOwnerId
							)
						VALUES (
							@P_FormId
							,@P_UserId
							,@P_StoreId
							,dbo.ConvertAnyTimeTo12Format(@P_TimeIn)
							,dbo.ConvertAnyTimeTo12Format(@P_TimeOut)
							,@LengthOfVisitInMinutes
							,@P_gpsLatitude
							,@P_gpsLongitude
							,@P_gpsGeofenceDistance
							,@P_gpsInsideGeofence
							,@P_gpsGeofenceMessage
							,@P_version
							,@p_deviceName
							,@P_deviceVersion
							,@P_deviceModel
							,@P_UserId
							,@P_description
							,@OwnedById
							)

					SET @FormVisitId = @@IDENTITY

					--PRINT '--------'
					--PRINT '@@IDENTITY' + CAST(@FormVisitId AS VARCHAR(20))

					/* Insert into FormFieldValues and also into FormFieldValues_Temp */
					INSERT INTO FormFieldValues (
							FormFieldId
							,FormVisitId
							,FieldValue
							)
							OUTPUT INSERTED.FormFieldValueId, INSERTED.FormFieldId, INSERTED.FormVisitId, INSERTED.FieldValue
								INTO @FormFieldValues_Temp(FormFieldValueId, FormFieldId, FormVisitId, FieldValue)
						SELECT DISTINCT CAST(dftt.FormFieldId AS INT) AS FormFieldId
								,@FormVisitId
								,dftt.FormFieldValues
							FROM @DynamicFormTempTable dftt
							ORDER BY CAST(dftt.FormFieldId AS INT)

					/**Picture Capture changes start*/
					--Inserting into PictureItems by grouping the records as there will be multiple records in @DynamicFormTempTable per Picture Item
					INSERT INTO PictureItems (
							FormFieldValueId
							,Path
							,Description
							,STATUS
							,PictureOrder
							,UserId
							)
						SELECT DISTINCT ffv_t.FormFieldValueId
								,replace(replace(dftt.PicturePath, 'visitId', @FormVisitId), 'formFieldId', ffv_t.FormFieldId)
								,dftt.PictureDescription
								,0
								,dftt.PictureOrder
								,@P_UserId
							FROM @DynamicFormTempTable dftt
								JOIN @FormFieldValues_Temp ffv_t ON dftt.FormFieldId = ffv_t.FormFieldId
								JOIN FormFields ff ON dftt.FormFieldId = ff.FormFieldId
							WHERE ff.FieldTypeId = (
									SELECT ft.FieldTypeId
										FROM FieldType ft
										WHERE ft.FieldName = 'PictureGroup'
										)
								AND dftt.PictureOrder IS NOT NULL
							ORDER BY dftt.PictureOrder

					--Inserting into PictureItemCategories by uniquely identifying each record by formfieldvalueid and PictureOrder
					INSERT INTO PictureItemCategories (
							PictureItemId
							,CategoryId
							)
						SELECT pit.PictureItemId
								,dftt.PictureCategoryId
							FROM @DynamicFormTempTable dftt
								JOIN @FormFieldValues_Temp ffv_t ON dftt.FormFieldId = ffv_t.FormFieldId AND ffv_t.FormVisitId = @FormVisitId
								JOIN PictureItems pit ON ffv_t.FormFieldValueId = pit.FormFieldValueId AND dftt.PictureOrder = pit.PictureOrder
							ORDER BY dftt.PictureOrder

					SET @P_PicturesList = ''

					SELECT @P_PicturesList = @P_PicturesList + cast(ffv_t.FormFieldId AS VARCHAR(10)) + ';' + cast(pit.PictureOrder AS VARCHAR(3)) + ';' + cast(pit.PictureItemId AS VARCHAR(10)) + '|'
						FROM @FormFieldValues_Temp ffv_t
								INNER JOIN PictureItems pit ON pit.FormFieldValueId = ffv_t.FormFieldValueId
							ORDER BY ffv_t.FormFieldId
								,pit.PictureOrder

					/**Picture Capture changes end*/
					SELECT @OrgId = f.OrgId
							,@isApplyToCompliance = isApplyToCompliance
						FROM Forms f
						WHERE f.FormId = @P_FormId

					SELECT @wid = w.workflowid
						FROM Workflow w
							WHERE w.WorkflowName = 'Action Items'
								AND w.OrgId = @OrgId

					/** For increase workflow performance */
					INSERT INTO @WorkFlowPointer_Temp (
							StoreId
							,QueueId
							,FormId
							,SectionId
							,FormVisitId
							,Category
							,ActionItem
							,CreatedBy
							,CreatedOn
							,IsMailSentFlag
							)
						SELECT @P_StoreId
								,wm.QueueId
								,wm.FormId
								,wm.SectionId
								,ffv_t.FormVisitId
								,SectionName
								,FieldValue
								,@P_UserId
								,GETDATE()
								,0
							FROM WorkflowMap wm
								INNER JOIN @FormFieldValues_Temp ffv_t ON ffv_t.FormFieldId = wm.FormFieldId
								INNER JOIN FormSection fs ON fs.FormId = wm.FormId AND fs.FormSectionId = wm.SectionId
							WHERE wm.FormId = @P_FormId
								AND wm.WorkflowId = @wid
								

					SET @P_WorkflowPointer_ID = @@IDENTITY

					--PRINT '@P_WorkflowPointer_ID: ' + CAST(@P_WorkflowPointer_ID AS VARCHAR(20))

					IF @P_WorkflowPointer_ID IS NOT NULL
						BEGIN
							;WITH WorkFlowPointer_CTE
							AS(
								SELECT wfp.WorkflowPointerId,
										MAX(CASE WHEN w.WorkflowName = 'Due Date'
												THEN ffv_t.FieldValue
											END) AS DueDate
										,MAX(CASE WHEN w.WorkflowName = 'Description'
												THEN ffv_t.FieldValue
											END) AS Description
										,MAX(CASE WHEN w.WorkflowName = 'Description'
												THEN ffv_t.FormFieldValueId
											END) AS DescriptionFormFieldValueId
										,MAX(CASE WHEN w.WorkflowName = 'Status'
												THEN ffv_t.FieldValue
											END) AS Status
										,MAX(CASE WHEN w.WorkflowName = 'Status'
												THEN ffv_t.FormFieldValueId
											END) AS StatusFormFieldValueId
									FROM WorkFlowMap wfm
											INNER JOIN @FormFieldValues_Temp ffv_t on ffv_t.FormFieldId = wfm.FormFieldId
											INNER JOIN WorkFlow w ON wfm.WorkflowId = w.WorkFlowID
											INNER JOIN @WorkFlowPointer_Temp wfp ON wfp.QueueId = wfm.QueueId AND wfp.FormId = wfm.FormId AND wfp.SectionId = wfm.SectionId
										WHERE w.WorkFlowName IN ('Due Date', 'Description', 'Status')
											AND w.OrgId = @OrgId
									GROUP BY wfp.WorkflowPointerId
							)
							UPDATE wfp
								SET wfp.DueDate = wfp_c.DueDate,
									wfp.Description = wfp_c.Description,
									wfp.DescriptionFormFieldValueId = wfp_c.DescriptionFormFieldValueId,
									wfp.Status = wfp_c.Status,
									wfp.StatusFormFieldValueId = wfp_c.StatusFormFieldValueId
								FROM @WorkFlowPointer_Temp wfp
									INNER JOIN WorkFlowPointer_CTE wfp_c ON wfp_c.WorkflowPointerId = wfp.WorkflowPointerId
						END

					INSERT INTO WorkflowPointer(
								StoreId
								,QueueId
								,FormId
								,SectionId
								,FormVisitId
								,StatusFormFieldValueId
								,DescriptionFormFieldValueId
								,ActionItem
								,Category
								,Description
								,DueDate
								,Status
								,CreatedBy
								,CreatedOn
								,IsMailSentFlag)
							SELECT 	wfp.StoreId
									,wfp.QueueId
									,wfp.FormId
									,wfp.SectionId
									,wfp.FormVisitId
									,wfp.StatusFormFieldValueId
									,wfp.DescriptionFormFieldValueId
									,wfp.ActionItem
									,wfp.Category
									,wfp.Description
									,wfp.DueDate
									,wfp.Status
									,wfp.CreatedBy
									,wfp.CreatedOn
									,wfp.IsMailSentFlag 
								FROM @WorkFlowPointer_Temp wfp

				IF @isApplyToCompliance = 1
				BEGIN
					IF @P_gpsInsideGeofence = 'Yes'
						UPDATE Store
							SET StoreVisitGPSCount = StoreVisitGPSCount + 1
							WHERE StoreId = @P_StoreId

					IF @P_gpsInsideGeofence = 'No'
						UPDATE Store
							SET StoreVisitNonGPSCount = StoreVisitNonGPSCount + 1
							WHERE StoreId = @P_StoreId
				END
			END
		END
		/*************************************************************/
		/*   Begin - Update section                                  */
		/*************************************************************/
		ELSE
			IF @P_Action_Type = 'UPDATE'
				OR @P_Action_Type = 'UPDATE_FROM_PORTAL'
				OR @P_Action_Type = 'UPDATE_ADHOC_FORM'
				OR @P_Action_Type = 'UPDATE_ADHOC_FORM_PORTAL'
				BEGIN
					/** UPDATE VALUES BASED ON FORMFIELDVALUE ID - (D.FormFieldId should be come as FormFieldValueId)*/
					UPDATE ffv
						SET ffv.FieldValue = dftt.FormFieldValues
							FROM @DynamicFormTempTable dftt
								INNER JOIN FormFieldValues ffv ON ffv.FormFieldValueId = dftt.FormFieldId

					IF @P_Action_Type = 'UPDATE'
							OR @P_Action_Type = 'UPDATE_ADHOC_FORM'
						BEGIN
							SET @P_FormId = NULL

							SELECT @P_FormId = ffv.FormVisitId
								FROM FormFieldValues ffv
								WHERE ffv.FormFieldValueId = (
										SELECT TOP (1) dftt.FormFieldId
											FROM @DynamicFormTempTable dftt
										)
						END

					/** Updated by and Updated On from Portal */
					UPDATE FormVisit
						SET UpdatedBy = @P_UserId
							,UpdatedOn = GETDATE()
							,Description = @P_Description
						WHERE FormVisitId = @P_FormId

					-- Add the current visit details into @FormFieldValues_Temp
					INSERT INTO @FormFieldValues_Temp (
							FormFieldValueId
							,FormFieldId
							,FormVisitId
							,FieldValue
							)
						SELECT ffv.FormFieldValueId
								,ffv.FormFieldId
								,ffv.FormVisitId
								,ffv.FieldValue
							FROM FormFieldValues ffv
							WHERE ffv.FormVisitId = @P_FormId

					--Picture Capture changes starts
					/** Update PictureItems Table */
					UPDATE pit
						SET pit.Description = dftt.PictureDescription
							FROM PictureItems pit
								INNER JOIN @DynamicFormTempTable dftt ON pit.FormFieldValueId = dftt.FormFieldId AND pit.PictureOrder = dftt.PictureOrder

					/** Delete the Category entries for each Picture Item of the current visit*/
					DELETE PictureItemCategories
						FROM PictureItemCategories pic
							INNER JOIN PictureItems pit ON pit.PictureItemId = pic.PictureItemId
							INNER JOIN @DynamicFormTempTable dftt ON pit.FormFieldValueId = dftt.FormFieldId AND pit.PictureOrder = dftt.PictureOrder

					/** Insert the new Category values per Picture Item */
					INSERT INTO PictureItemCategories (
							PictureItemId
							,CategoryId
							)
						SELECT DISTINCT pit.PictureItemId
								,dftt.PictureCategoryId
							FROM @DynamicFormTempTable dftt
								JOIN PictureItems pit ON pit.FormFieldValueId = dftt.FormFieldId
									AND pit.PictureOrder = dftt.PictureOrder
							WHERE pit.PictureItemId IS NOT NULL
								AND dftt.PictureCategoryId IS NOT NULL
								AND NOT EXISTS (
									SELECT *
										FROM PictureItemCategories pic
											WHERE pic.PictureItemId = pit.PictureItemId
												AND PictureCategoryId = dftt.PictureCategoryId /* TODO ?????*/
									)
							ORDER BY pit.PictureItemId

					SET @P_PicturesList = ''

					SELECT @P_PicturesList = @P_PicturesList + cast(pit.FormFieldValueId AS VARCHAR(10)) + ';' + cast(pit.PictureOrder AS VARCHAR(3)) + ';' + cast(pit.PictureItemId AS VARCHAR(10)) + '|'
						FROM @FormFieldValues_Temp ffv_t
							INNER JOIN PictureItems pit ON pit.FormFieldValueId = ffv_t.FormFieldValueId
						ORDER BY ffv_t.FormFieldId, pit.PictureOrder

					--Picture Capture changes ends
					/** For increase workflow performance */
					/** Action Items field value update - WorkflowId = 1 */
					SELECT @OrgId = f.OrgId
						FROM Forms f
							JOIN FormVisit fv ON fv.FormId = f.FormId
						WHERE fv.FormVisitId = @P_FormId

						;WITH WorkFlowPointer_CTE
						AS(
							SELECT wfp.WorkflowPointerId
									,MAX(CASE WHEN w.WorkflowName = 'Action Items'
											THEN ffv_t.FieldValue
										END) AS ActionItem
									,MAX(CASE WHEN w.WorkflowName = 'Action Items'
											THEN GETDATE()
										END) AS UpdatedOn
									,MAX(CASE WHEN w.WorkflowName = 'Due Date'
											THEN ffv_t.FieldValue
										END) AS DueDate
									,MAX(CASE WHEN w.WorkflowName = 'Description'
											THEN ffv_t.FieldValue
										END) AS Description
									,MAX(CASE WHEN w.WorkflowName = 'Description'
											THEN ffv_t.FormFieldValueId
										END) AS DescriptionFormFieldValueId
									,MAX(CASE WHEN w.WorkflowName = 'Status'
											THEN ffv_t.FieldValue
										END) AS Status
									,MAX(CASE WHEN w.WorkflowName = 'Status'
											THEN ffv_t.FormFieldValueId
										END) AS StatusFormFieldValueId
								FROM WorkFlowMap wfm
										INNER JOIN @FormFieldValues_Temp ffv_t on ffv_t.FormFieldId = wfm.FormFieldId
										INNER JOIN WorkFlow w ON wfm.WorkflowId = w.WorkFlowID
										INNER JOIN WorkflowPointer wfp ON wfp.QueueId = wfm.QueueId AND wfp.FormId = wfm.FormId AND wfp.SectionId = wfm.SectionId
									WHERE wfp.FormVisitId = @P_FormId
										AND w.WorkFlowName IN ('Action Items', 'Due Date', 'Description', 'Status')
										AND w.OrgId = @OrgId
								GROUP BY wfp.WorkflowPointerId
						)
						UPDATE wfp
							SET wfp.ActionItem = wfp_c.ActionItem,
								wfp.UpdatedOn = wfp_c.UpdatedOn,
								wfp.DueDate = wfp_c.DueDate,
								wfp.Description = wfp_c.Description,
								wfp.DescriptionFormFieldValueId = wfp_c.DescriptionFormFieldValueId,
								wfp.Status = wfp_c.Status,
								wfp.StatusFormFieldValueId = wfp_c.StatusFormFieldValueId
							FROM WorkflowPointer wfp
								INNER JOIN WorkFlowPointer_CTE wfp_c ON wfp_c.WorkflowPointerId = wfp.WorkflowPointerId

				END

		IF @P_PicturesList <> ''
			SET @P_PicturesList = substring(@P_PicturesList, 1, len(@P_PicturesList) - 1)

		SET @P_Msg = @P_Msg
					+ CHAR(13) + CHAR(10) + 'StartDate :' + CONVERT(nvarchar, @StartDate, 121)
					+ CHAR(13) + CHAR(10) + 'EndDate : ' + CONVERT(nvarchar, GETDATE(), 121);

		/** COMMIT THE TRANSACTION */
		PRINT @P_Form_Status
		IF @@trancount > 0
		BEGIN
--			PRINT 'COMMIT TRANSACTION'
			COMMIT TRANSACTION
		END
	END TRY

	BEGIN CATCH
--		PRINT 'ROLLBACK TRANSACTION'

		SET @P_Form_Status = 0
		ROLLBACK TRANSACTION

		/** CATCH THE ERROR DETAILS */
		DECLARE @ErrorMsg nvarchar(max);
		SET @ErrorMsg=	'ErrorNumber    = ' + CAST(ERROR_NUMBER() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorSeverity  = ' + CAST(ERROR_SEVERITY() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorState     = ' + CAST(ERROR_STATE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorProcedure = ' + CAST(ERROR_PROCEDURE() AS nvarchar(max)) + CHAR(13) + CHAR(10) +
						'ErrorLine		= ' + CAST(ERROR_LINE() AS nvarchar(20)) + CHAR(13) + CHAR(10) +
						'ErrorMessage	= ' + CAST(ERROR_MESSAGE() AS nvarchar(max)) + CHAR(13) + CHAR(10)
		 --@ErrorMsg;
		SET @P_Msg = 'Error'
					+ CHAR(13) + CHAR(10) + 'StartDate :' + CONVERT(nvarchar, @StartDate, 121)
					+ CHAR(13) + CHAR(10) + 'EndDate : ' + CONVERT(nvarchar, GETDATE(), 121)
					+ CHAR(13) + CHAR(10) + @ErrorMsg;
--		PRINT @P_Form_Status;
--		PRINT @ErrorMsg;
	END CATCH
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'DynamicForm_XML_Supporter' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[DynamicForm_XML_Supporter]')
	END
GO
/****** Object:  StoredProcedure [dbo].[DynamicForm_XML_Supporter]    Script Date: 3/2/2015 6:36:43 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

;
/*
    ===========================================================================
    Based on the review conducted for Users Revamp, the following requirements
    where deducted:

    The stored procedure is used in conjunction with DFB UI components. For a given
    form, from one organization, it will return the mappings of that specific form
    to the Organization levels (geographies), Business roles or Accounts.

    TestCase
    ---------------------------------------------------------------------------
    EXEC [DynamicForm_XML_Supporter] NULL, 'GET_ORG_LEVEL_MAPID', '1216'
    EXEC [DynamicForm_XML_Supporter] '11', 'ORGANIZATION_LEVEL', '1216'
    EXEC [DynamicForm_XML_Supporter] '11', 'BUSINESSROLE_LEVEL', '1216'
    EXEC [DynamicForm_XML_Supporter] '11', 'ACCOUNT_LEVEL',		'1216'
	
    Utils to search for proper test cases:
    ---------------------------------------------------------------------------


    ===========================================================================
*/
CREATE PROCEDURE [dbo].[DynamicForm_XML_Supporter] (
    @P_OrgId	 varchar(20),
    @P_Type	 varchar(50),
    @P_FormId	 varchar(20) = NULL
)
AS
SET NOCOUNT ON
BEGIN
    IF @P_Type = 'GET_ORG_LEVEL_MAPID'
	   BEGIN
		  SELECT
			 flm.OrgLevelMapId
		  FROM OrgLevel ol WITH (NOLOCK)
			 INNER JOIN OrgLevelMap olm WITH (NOLOCK) ON olm.OrgLevelId = ol.OrgLevelId
			 INNER JOIN FormLevelMap flm WITH (NOLOCK) ON flm.OrgLevelMapId = olm.OrgLevelMapId
		  WHERE 1 = 1
			 AND flm.FormLevelMapId IS NOT NULL
			 AND (@P_OrgId IS NULL OR ol.OrgId = @P_OrgId)
			 AND (@P_FormId IS NULL OR flm.FormId = @P_FormId)
		  ;
	   END
    ELSE IF @P_Type = 'ORGANIZATION_LEVEL'
	   BEGIN
		  --Return all the geographies (OrgLevel) from the designated organization and
		  --mark the geographies to which @P_FormId is being mapped to.
		  SELECT
			  text	   = item.OrgLevelIdentifier
			 ,id		   = item.OrgLevelMapId
			 ,AssignedId = CASE WHEN flm.FormId IS NOT NULL THEN item.OrgLevelMapId ELSE 0 END
			 ,checked	   = CASE WHEN flm.FormId IS NOT NULL THEN 'true' ELSE '' END
		  FROM OrgLevel ol WITH (NOLOCK)
			 INNER JOIN OrgLevelMap item WITH (NOLOCK) ON item.OrgLevelId = ol.OrgLevelId
			 LEFT JOIN FormLevelMap flm WITH (NOLOCK) ON flm.OrgLevelMapId = item.OrgLevelMapId AND flm.FormId = @P_FormId
		  WHERE 1 = 1
			 AND ol.OrgId = @P_OrgId
		  FOR XML AUTO
		  ;
	   END
    ELSE IF @P_Type = 'BUSINESSROLE_LEVEL'
	   BEGIN
		  --Return all the busness roles form the selected organization and mark
		  --the roles to which @P_FormId is being mapped to.
		  SELECT
			  text	   		= item.BusinessRoleName
			 ,id		   	= item.BusinessRoleID
			 ,AssignedId 	= CASE WHEN flm.FormId IS NOT NULL THEN item.BusinessRoleID ELSE 0 END
			 ,checked	   	= CASE WHEN flm.FormId IS NOT NULL THEN 'true' ELSE '' END
		  FROM BusinessRole item WITH (NOLOCK)
			 LEFT JOIN FormLevelMap flm WITH (NOLOCK) ON flm.BusinessRoleId = item.BusinessRoleId AND flm.FormId = @P_FormId
		  WHERE 1 = 1
			 AND item.OrgID = @P_OrgId
			 AND item.isActive = 1
		  ORDER BY
			 item.BusinessRoleLevel ASC
		  FOR XML AUTO
		  ;
	   END
    ELSE IF @P_Type = 'ACCOUNT_LEVEL'
	   BEGIN
		  --Return all the accounts form the depicted organization and mark
		  --the ones to which @P_FormId is being mapped to.
		  SELECT
			  text	   = item.AccountName
			 ,id		   = item.AccountId
			 ,AssignedId = CASE WHEN flm.FormId IS NOT NULL THEN item.AccountId ELSE 0 END
			 ,checked	   = CASE WHEN flm.FormId IS NOT NULL THEN 'true' ELSE '' END
		  FROM Account item WITH (NOLOCK)
			 LEFT JOIN FormLevelMap flm WITH (NOLOCK) on flm.AccountId = item.AccountId AND flm.FormId = @P_FormId
		  WHERE 1 = 1
			 AND item.OrgId = @P_OrgId
			 AND item.isActive = 1
		  FOR XML AUTO
		  ;
	   END
END
;

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'getCompliance' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[getCompliance]')
	END
GO
/****** Object:  StoredProcedure [dbo].[getCompliance]    Script Date: 3/2/2015 6:36:43 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[getCompliance] (
	@P_OrgId			VARCHAR(20),
	@UserName			varchar(50),
	@WeekNumber			int,
	@BiweekNumber		int,
	@ComplianceWeekly	decimal(18,2) = 0.00 out,
	@ComplianceBiweekly	decimal(18,2) = 0.00 out,
	@ComplianceMonthly	decimal(18,2) = 0.00 out,
	@ComplianceOverall	decimal(18,2) = 0.00 out
)
AS
SET NOCOUNT ON
BEGIN
	/**
		The parameters @WeekNumber and @BiweekNumber parameters are not used. They have been kept to not alter the
		upstream Java code.
		From the output parameters, only the @ComplianceOverall is being used (and correctly populated).

		The procedure will return the Overall individual Compliance based on the compliance history augmented table - this
		means the compliance of the stores assigned to the depicted user only.
	 */

	-- Default values
	SET @ComplianceWeekly	=   0.00
	SET @ComplianceBiweekly	=   0.00
	SET @ComplianceMonthly	=   0.00
	SET @ComplianceOverall	= 100.00

	-- Get the user ID
	DECLARE @UserId INT;
	SELECT @UserId = UserId	FROM Users WHERE Username = @UserName;
	IF @UserId IS NULL RETURN;

	-- Compute the boundaries of the current month
	DECLARE @StartOfMonth DATETIME, @EndOfMonth DATETIME;
	SELECT
		@StartOfMonth = dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0)),
		@EndOfMonth = dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))
	;

	-- Compute the compliance of the current user
	SELECT
		@ComplianceOverall = AVG(ch.Compliance * 1.00)
	FROM ComplianceHistory ch WITH (NOLOCK)
		INNER JOIN StoreUserMapping stum WITH (NOLOCK) ON stum.StoreId = ch.StoreId AND stum.UserId = @UserId
		INNER JOIN Store s WITH (NOLOCK) ON s.StoreId = stum.StoreId AND s.OrgId = @P_OrgId
	WHERE 1 = 1
		AND s.IsActive = 1
		AND s.IsCompliance = 1
		AND ch.Date BETWEEN @StartOfMonth AND @EndOfMonth
		AND ch.RecentForMonth = 1
	;
	SET @ComplianceOverall = ISNULL(@ComplianceOverall, 100.00)
	;
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'getComplianceForTeam' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[getComplianceForTeam]')
	END
GO
/****** Object:  StoredProcedure [dbo].[getComplianceForTeam]    Script Date: 3/2/2015 6:36:44 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[getComplianceForTeam] (
	@P_OrgId			VARCHAR(20),
	@UserName			varchar(50),
	@WeekNumber			int,
	@BiweekNumber		int,
	@ComplianceWeekly	decimal(18,2) = 0.00 out,
	@ComplianceBiweekly	decimal(18,2) = 0.00 out,
	@ComplianceMonthly	decimal(18,2) = 0.00 out,
	@ComplianceOverall	decimal(18,2) = 0.00 out
)
AS
SET NOCOUNT ON
BEGIN
	SET NOCOUNT ON

	/**
		The parameters @WeekNumber and @BiweekNumber parameters are not used. They have been kept to not alter the
		upstream Java code.
		From the output parameters, only the @ComplianceOverall is being used (and correctly populated).

		The procedure will return the Overall team Compliance based on the compliance history augmented table - this
		means the compliance of the stores assigned to the depicted user and his down line.
	 */

	-- Default values
	SET @ComplianceWeekly	=   0.00
	SET @ComplianceBiweekly	=   0.00
	SET @ComplianceMonthly	=   0.00
	SET @ComplianceOverall	= 100.00

	-- Get the user ID
	DECLARE @UserId INT;
	SELECT @UserId = UserId	FROM Users WHERE Username = @UserName;
	IF @UserId IS NULL RETURN;

	-- Compute the boundaries of the current month
	DECLARE @StartOfMonth DATETIME, @EndOfMonth DATETIME;
	SELECT
		@StartOfMonth = dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0)),
		@EndOfMonth = dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))
	;

	-- Compute the compliance of the team
	SELECT
		@ComplianceOverall = AVG(ch.Compliance * 1.00)
	FROM ComplianceHistory ch WITH (NOLOCK)
		INNER JOIN StoreUserMapping stum WITH (NOLOCK) ON stum.StoreId = ch.StoreId
		INNER JOIN Store s WITH (NOLOCK) ON s.StoreId = stum.StoreId AND s.OrgId = @P_OrgId
		INNER JOIN UserReporting_Function(@P_OrgId, @UserId) urf ON urf.UserId = stum.UserId
	WHERE 1 = 1
		AND s.IsActive = 1
		AND s.IsCompliance = 1
		AND ch.Date BETWEEN @StartOfMonth AND @EndOfMonth
		AND ch.RecentForMonth = 1
	;
	SET @ComplianceOverall = ISNULL(@ComplianceOverall, 100.00)
	;
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'getComplianceGPS' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[getComplianceGPS]')
	END
GO
/****** Object:  StoredProcedure [dbo].[getComplianceGPS]    Script Date: 3/2/2015 6:36:45 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/**
	The stored procedure will compute the GPS compliance of the stores assigned to the depicted user and his down-line,
	for the current month only, if the parameter '@P_For' is 'Team'. If the parameter '@P_For' is 'Individual' then
	only the individual compliance is computed.
 */
CREATE PROCEDURE [dbo].[getComplianceGPS] (
	 @P_OrgId 		int
	,@P_UserId		int
	,@P_Level		varchar(50) = 'Team'
	,@ComplianceGPS decimal(18,2) = 0.00 out
)
AS
SET NOCOUNT ON
BEGIN
	-- Compute the boundaries of the current month
	DECLARE @StartOfMonth DATETIME, @EndOfMonth DATETIME;
	SELECT
		@StartOfMonth = dateadd(m,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0)),
		@EndOfMonth = dateadd(mi,-1,dateadd(m, datediff(m, 0, dateadd(m, 1,getdate())), 0))
	;
	SELECT
		@ComplianceGPS = SUM(CASE fv.GpsInsideGeofence WHEN 'Yes' THEN 1 ELSE 0 END) * 100.00 / COUNT(0)
	FROM FormVisit fv WITH(NOLOCK)
		INNER JOIN StoreUserMapping stum WITH(NOLOCK) ON stum.StoreId = fv.StoreId
		INNER JOIN Store s WITH(NOLOCK) ON stum.StoreId = s.StoreId AND s.OrgId = @P_OrgId
		INNER JOIN UserReporting_Function(@P_OrgId, @P_UserId) urf ON urf.UserId = stum.UserId
	WHERE 1 = 1
		AND s.isActive = 1
		AND s.IsCompliance = 1
		AND fv.CreatedOn BETWEEN @StartOfMonth AND @EndOfMonth
		AND fv.GpsInsideGeofence IN ('Yes', 'No')
		AND (@P_Level = 'Team' OR (@P_Level = 'Individual' AND fv.UserId = @P_UserId))
	;
	-- By default, return 0 if there are no visits
	SET @ComplianceGPS = ISNULL(@ComplianceGPS, 0.00)
	;

END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'getDynamicMenuQuery' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[getDynamicMenuQuery]')
	END
GO
/****** Object:  StoredProcedure [dbo].[getDynamicMenuQuery]    Script Date: 3/2/2015 6:36:46 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*Author Palani*/

-- EXEC [getDynamicMenuQuery] '9', '1', 'COMPLIANCE', 'RETAILER', 'TEAM'
-- EXEC [getDynamicMenuQuery] '9', '1', 'COMPLIANCE', 'RETAILER', 'INDIVIDUAL'
-- EXEC [getDynamicMenuQuery] '9', '1', 'COMPLIANCE', 'GEOGRAPHY', 'TEAM'

-- EXEC [getDynamicMenuQuery] '9', '1', 'SALES', 'RETAILER', 'TEAM'
-- EXEC [getDynamicMenuQuery] '9', '1', 'SALES', 'GEOGRAPHY', 'TEAM'
-- EXEC [getDynamicMenuQuery] '9', '1', 'SALES', 'GEOGRAPHY', 'INDIVIDUAL'

CREATE PROCEDURE [dbo].[getDynamicMenuQuery](
@P_OrgId VARCHAR(20),
@pUserId VARCHAR(50),
@pMenuOption VARCHAR(50),
@pChartType VARCHAR (50),
@pChartLevel VARCHAR (50)=''
)
AS
SET NOCOUNT ON
BEGIN

/** Avoid to generate query restults when the org isCompliance=False */ 
DECLARE @IsCompliance bit
SET @IsCompliance = 1
SELECT @IsCompliance = IsCompliance From Organization Where OrgId = @P_OrgId
IF @IsCompliance = 0
	SET @pUserId='0'

/** For increase the performance */
SELECT STOREID, USERID INTO #HF_Temp FROM dbo.Hierarchy_Function(@P_OrgId,@pUserId)

	IF @pMenuOption = 'COMPLIANCE'
	BEGIN
		IF @pChartType = 'RETAILER'
		BEGIN
			IF @pChartLevel = 'TEAM'
			BEGIN
				SELECT DISTINCT Account.AccountName, DivisionRegion.Division, DivisionRegion.market_cluster, DivisionRegion.Region
				FROM         Store INNER JOIN
				DivisionRegion ON DivisionRegion.DivisionRegionId = Store.DivisionRegionId INNER JOIN
				StoreUserMapping AS SM ON SM.StoreId = Store.StoreId INNER JOIN
				Account ON Store.AccountId = Account.AccountId LEFT OUTER JOIN
					#HF_Temp AS HF ON HF.StoreId = SM.StoreId
					WHERE (HF.UserId = SM.UserId) 
						   AND Account.IsActive=1 AND Store.isActive=1
					       /** Requirement changes - compliance on/off */
				           AND Store.IsCompliance = 1
				order by 1,2,3
			END
			ELSE
			BEGIN
				SELECT DISTINCT Account.AccountName, DivisionRegion.Division, DivisionRegion.market_cluster, DivisionRegion.Region
				FROM         Store INNER JOIN
				DivisionRegion ON DivisionRegion.DivisionRegionId = Store.DivisionRegionId INNER JOIN
				StoreUserMapping AS SM ON SM.StoreId = Store.StoreId INNER JOIN
				Account ON Store.AccountId = Account.AccountId
				WHERE SM.UserId = @pUserId  AND Account.IsActive=1 AND Store.isActive=1 
			          /** Requirement changes - compliance on/off */
			          AND Store.IsCompliance = 1				
				ORDER BY 1,2,3
			END
		END


		IF @pChartType = 'GEOGRAPHY'
		BEGIN
			IF @pChartLevel = 'TEAM'
			BEGIN
				SELECT DISTINCT '' AccountName, DivisionRegion.Division, DivisionRegion.market_cluster, DivisionRegion.Region
				FROM         Store INNER JOIN
				DivisionRegion ON DivisionRegion.DivisionRegionId = Store.DivisionRegionId INNER JOIN
				StoreUserMapping AS SM ON SM.StoreId = Store.StoreId INNER JOIN
				Account ON Store.AccountId = Account.AccountId LEFT OUTER JOIN
					#HF_Temp AS HF ON HF.StoreId = SM.StoreId
					WHERE (HF.UserId = SM.UserId)
						   AND Account.IsActive=1 AND Store.isActive=1
				           /** Requirement changes - compliance on/off */
				           AND Store.IsCompliance = 1						   
				order by 1,2,3
			END
			ELSE
			BEGIN
				SELECT DISTINCT '' AccountName, DivisionRegion.Division, DivisionRegion.market_cluster, DivisionRegion.Region
				FROM         Store INNER JOIN
				DivisionRegion ON DivisionRegion.DivisionRegionId = Store.DivisionRegionId INNER JOIN
				StoreUserMapping AS SM ON SM.StoreId = Store.StoreId INNER JOIN
				Account ON Store.AccountId = Account.AccountId 
				WHERE SM.UserId = @pUserId  AND Account.IsActive=1 AND Store.isActive=1
				      /** Requirement changes - compliance on/off */
				      AND Store.IsCompliance = 1
				order by 1,2,3
			END
		END
	END ELSE IF @pMenuOption = 'SALES'
	BEGIN
		IF @pChartType = 'RETAILER'
		BEGIN
			IF @pChartLevel = 'TEAM'
			BEGIN
				SELECT DISTINCT Account.AccountName, DivisionRegion.Division, DivisionRegion.market_cluster, DivisionRegion.Region
				FROM         Store INNER JOIN
				DivisionRegion ON DivisionRegion.DivisionRegionId = Store.DivisionRegionId INNER JOIN
				StoreUserMapping AS SM ON SM.StoreId = Store.StoreId INNER JOIN
				SalesFeed AS SF ON SF.StoreId = Store.StoreId INNER JOIN
				Account ON Store.AccountId = Account.AccountId LEFT OUTER JOIN
					#HF_Temp AS HF ON HF.StoreId = SM.StoreId
					WHERE (HF.UserId = SM.UserId) 
						   AND Account.IsActive=1 AND Store.isActive=1
						   /** Requirement changes - compliance on/off */
				           AND Store.IsCompliance = 1
				order by 1,2,3
			END
			ELSE
			BEGIN
				SELECT DISTINCT Account.AccountName, DivisionRegion.Division, DivisionRegion.market_cluster, DivisionRegion.Region
				FROM         Store INNER JOIN
				DivisionRegion ON DivisionRegion.DivisionRegionId = Store.DivisionRegionId INNER JOIN
				StoreUserMapping AS SM ON SM.StoreId = Store.StoreId INNER JOIN
				SalesFeed AS SF ON SF.StoreId = Store.StoreId INNER JOIN
				Account ON Store.AccountId = Account.AccountId
				WHERE SM.UserId = @pUserId  AND Account.IsActive=1 AND Store.isActive=1 
				      /** Requirement changes - compliance on/off */
				      AND Store.IsCompliance = 1				
				ORDER BY 1,2,3
			END
		END


		IF @pChartType = 'GEOGRAPHY'
		BEGIN
			IF @pChartLevel = 'TEAM'
			BEGIN
				SELECT DISTINCT '' AccountName, DivisionRegion.Division, DivisionRegion.market_cluster, DivisionRegion.Region
				FROM         Store INNER JOIN
				DivisionRegion ON DivisionRegion.DivisionRegionId = Store.DivisionRegionId INNER JOIN
				StoreUserMapping AS SM ON SM.StoreId = Store.StoreId INNER JOIN
				SalesFeed AS SF ON SF.StoreId = Store.StoreId INNER JOIN
				Account ON Store.AccountId = Account.AccountId LEFT OUTER JOIN
					#HF_Temp AS HF ON HF.StoreId = SM.StoreId
					WHERE (HF.UserId = SM.UserId)
						   AND Account.IsActive=1 AND Store.isActive=1
				      /** Requirement changes - compliance on/off */
				      AND Store.IsCompliance = 1						   
				order by 1,2,3
			END
			ELSE
			BEGIN
				SELECT DISTINCT '' AccountName, DivisionRegion.Division, DivisionRegion.market_cluster, DivisionRegion.Region
				FROM         Store INNER JOIN
				DivisionRegion ON DivisionRegion.DivisionRegionId = Store.DivisionRegionId INNER JOIN
				StoreUserMapping AS SM ON SM.StoreId = Store.StoreId INNER JOIN
				SalesFeed AS SF ON SF.StoreId = Store.StoreId INNER JOIN
				Account ON Store.AccountId = Account.AccountId 
				WHERE SM.UserId = @pUserId  AND Account.IsActive=1 AND Store.isActive=1
				      /** Requirement changes - compliance on/off */
				      AND Store.IsCompliance = 1				
				order by 1,2,3
			END
		END
	END

END


GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'GetFormVisits' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[GetFormVisits]')
	END
GO
/****** Object:  StoredProcedure [dbo].[GetFormVisits]    Script Date: 3/2/2015 6:36:47 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetFormVisits]
(
	@OrgId			int,
	@UserId			int,
	@IsActive		bit,
	@FormId			int,
	@StoreNumOrName	varchar(100),
	@SubmittedBy	varchar(50),
	@StartVisitDate	datetime,
	@EndVisitDate	datetime,
	@OrderBy		tinyint,
	@OrderDirection bit,
	@PageNo			int,
	@PageSize		int,
	@TotalRowCount	int OUT
)
AS
SET NOCOUNT ON
BEGIN
	--DECLARE
	--	@OrgId			int,
	--	@UserId			int,
	--	@IsActive		bit,
	--	@FormId			int,
	--	@StoreNumOrName	varchar(100),
	--	@SubmittedBy	varchar(50),
	--	@StartVisitDate	datetime,
	--	@EndVisitDate	datetime,
	--	@OrderBy		tinyint,
	--	@OrderDirection bit,
	--	@PageNo			int,
	--	@PageSize		int,
	--	@TotalRowCount	int

	--SELECT
	--	@OrgId = 6,
	--	@UserId = 1,
	--	@IsActive = NULL,
	--	@FormId = NULL,
	--	@StoreNumOrName = NULL,
	--	@SubmittedBy = NULL,
	--	@StartVisitDate = NULL,
	--	@EndVisitDate = NULL,
	--	@OrderBy = NULL,
	--	@OrderDirection = NULL,
	--	@PageNo = NULL,
	--	@PageSize = NULL,
	--	@TotalRowCount = NULL 

	IF @IsActive IS NULL
		SET @IsActive = 1
	IF @OrderBy IS NULL
		SET @OrderBy = 0
	IF @OrderDirection IS NULL
		SET @OrderDirection = 0
	IF @PageNo IS NULL
		SET @PageNo = 0
	IF @PageSize IS NULL
		SET @PageSize = 10
	SET @TotalRowCount = 0

	DECLARE @GetFormVisits TABLE
	(
		[FormVisitId] int,
		[Form Name] varchar(50),
		[Property Name] varchar(100),
		[Property Number] varchar(50),
		[Submitted By] varchar(50),
		[Date] datetime,
		[Time In] varchar(8), 
		[Time Out] varchar(8),
		[Device] varchar(50),
		[TotalRowCount] int
	)

;WITH FormVisits_CTE
AS
(
	SELECT 	COUNT(fv.FormVisitId) OVER () AS TotalRowCount,
			ROW_NUMBER() OVER (
								ORDER BY
											CASE WHEN @OrderBy = 0 AND @OrderDirection = 0 THEN f.[FormName] END ASC,
											CASE WHEN @OrderBy = 1 AND @OrderDirection = 0 THEN CASE 
																										WHEN s.[CertifiedStoreNickname] IS NOT NULL AND LEN(s.[CertifiedStoreNickname]) > 0 THEN s.[CertifiedStoreNickname]
																										ELSE s.[StoreName] 
																								END  
																								END ASC ,
											CASE WHEN @OrderBy = 2 AND @OrderDirection = 0 THEN s.StoreNumber END ASC,
											CASE WHEN @OrderBy = 3 AND @OrderDirection = 0 THEN u.fullname END ASC ,
											CASE WHEN @OrderBy = 4 AND @OrderDirection = 0 THEN fv.VisitDate END ASC, 	
											CASE WHEN @OrderBy = 5 AND @OrderDirection = 0 THEN fv.TimeIn END ASC ,
											CASE WHEN @OrderBy = 6 AND @OrderDirection = 0 THEN fv.TimeOut END ASC, 	
											CASE WHEN @OrderBy = 7 AND @OrderDirection = 0 THEN fv.DeviceName END ASC,
											CASE WHEN @OrderBy = 0 AND @OrderDirection = 1 THEN f.[FormName] END DESC,
											CASE WHEN @OrderBy = 1 AND @OrderDirection = 1 THEN CASE 
																										WHEN s.[CertifiedStoreNickname] IS NOT NULL AND LEN(s.[CertifiedStoreNickname]) > 0 THEN s.[CertifiedStoreNickname]
																										ELSE s.[StoreName] 
																								END  
																								END DESC ,
											CASE WHEN @OrderBy = 2 AND @OrderDirection = 1 THEN s.StoreNumber END DESC,
											CASE WHEN @OrderBy = 3 AND @OrderDirection = 1 THEN u.fullname END DESC ,
											CASE WHEN @OrderBy = 4 AND @OrderDirection = 1 THEN fv.VisitDate END DESC, 	
											CASE WHEN @OrderBy = 5 AND @OrderDirection = 1 THEN fv.TimeIn END DESC ,
											CASE WHEN @OrderBy = 6 AND @OrderDirection = 1 THEN fv.TimeOut END DESC, 	
											CASE WHEN @OrderBy = 7 AND @OrderDirection = 1 THEN fv.DeviceName END DESC
								) AS [RowNumber],			
			fv.FormVisitId AS [FormVisitId],
			f.FormName AS [Form Name],
			CASE WHEN s.CertifiedStoreNickname IS NOT NULL AND LEN(s.CertifiedStoreNickname) > 0 THEN s.CertifiedStoreNickname
				ELSE s.StoreName 
				END AS [Property Name], 
			s.StoreNumber AS [Property Number],
			u.FullName AS [Submitted By],
			fv.VisitDate AS [Date],
			fv.TimeIn AS [Time In], 
			fv.TimeOut AS [Time Out],
			fv.DeviceName AS [Device]
		FROM UserReporting_Function(@OrgId, @UserId) ur_f
				INNER JOIN FormVisit fv WITH (nolock) ON fv.UserId = ur_f.UserId
				INNER JOIN Forms f WITH (nolock) ON f.FormId = fv.FormId AND f.OrgId = ur_f.OrgId
				INNER JOIN (Users u WITH (nolock) 
					LEFT OUTER JOIN Country c3 WITH (nolock) ON c3.CountryId = u.BusinessCountryId
					LEFT OUTER JOIN State s4 WITH (nolock) ON s4.StateId = u.BusinessStateId
					LEFT OUTER JOIN Country c4 WITH (nolock) ON c4.CountryId = u.HomeCountryId
					LEFT OUTER JOIN State s5 WITH (nolock) ON s5.StateId = u.HomeStateId) ON u.UserId = ur_f.UserId
				INNER JOIN (Store s WITH (nolock) 
					LEFT OUTER JOIN Country c WITH (nolock) ON c.CountryId = s.CertifiedCountryId
					LEFT OUTER JOIN State s2 WITH (nolock) ON s2.StateId = s.CertifiedStateId
					LEFT OUTER JOIN Country c2 WITH (nolock) ON c2.CountryId = s.CountryId
					LEFT OUTER JOIN State s3 WITH (nolock) ON s3.StateId = s.StateId) ON s.StoreId = fv.StoreId AND s.OrgId = ur_f.OrgId
				WHERE f.OrgId = @OrgId
					AND u.isActive = @IsActive
					AND (@FormId IS NULL OR f.FormId = @FormId)
					AND (  (@StoreNumOrName IS NULL) 
						  OR (s.StoreNumber LIKE '%' + @StoreNumOrName + '%') 
						  OR (s.StoreName LIKE '%' + @StoreNumOrName + '%')
						  OR (s.CertifiedStoreNickname LIKE '%' + @StoreNumOrName + '%')
					    )
					AND (@SubmittedBy IS NULL OR u.fullname like '%'+@SubmittedBy+'%')
					AND (@StartVisitDate IS NULL OR fv.VisitDate BETWEEN @StartVisitDate AND @EndVisitDate)
)
INSERT INTO @GetFormVisits
(
	    [FormVisitId],
	    [Form Name],
	    [Property Name],
	    [Property Number],
	    [Submitted By],
	    [Date],
	    [Time In],
	    [Time Out],
	    [Device],
		[TotalRowCount]
)
SELECT	fv_c.[FormVisitId], 
		fv_c.[Form Name], 
		fv_c.[Property Name], 
		fv_c.[Property Number], 
		fv_c.[Submitted By], 
		fv_c.[Date], 
		fv_c.[Time In], 
		fv_c.[Time Out], 
		fv_c.[Device],
		fv_c.[TotalRowCount]
	FROM FormVisits_CTE fv_c
	WHERE fv_c.RowNumber BETWEEN ((@PageNo) * @PageSize + 1) AND ((@PageNo + 1) * @PageSize)
	ORDER BY [RowNumber]

	SELECT TOP(1) @TotalRowCount = gfv.[TotalRowCount] FROM @GetFormVisits gfv
	SELECT gfv.[FormVisitId], gfv.[Form Name], gfv.[Property Name], gfv.[Property Number], gfv.[Submitted By], gfv.[Date], gfv.[Time In], gfv.[Time Out], gfv.[Device]
		FROM @GetFormVisits gfv
END

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'GetUserDownline' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[GetUserDownline]')
	END
GO
/****** Object:  StoredProcedure [dbo].[GetUserDownline]    Script Date: 3/2/2015 6:36:48 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

;
/*
 ******************************************** Params ******************************************
	OrgId			- Organization Id					    	- required
	UserId			- User Id							    	- required
	UserName       	- UserName / FirstName / LastName			- not required
	ParentUserName 	- UserName / FirstName / LastName			- not required
	RoleId			- BusinessRoleID					    	- not required
	DivisionName  	- DivisionName						    	- not required
  	ClusterName		- ClusterName						    	- not required
	RegionId  		- RegionId						    		- not required
	OrderBy			- Id of column to be sort by (0 index)	    - not required - default 0
						0 - [FirstName],
						1 - [LastName],
						2 - [UserName],
						3 - [Region],
						4 - [BusinessRoleName],
						5 - [Division],
						6 - [EmailAddress],
	OrderDirection	- Direction of order (0 - ASC, 1 - DESC)    - not required - default 0
	StartIndex		- Start index					    		- not required - default 0
	PageSize		- No of row / page					    	- not required - default 10
 ******************************************** END *********************************************
*/

CREATE PROCEDURE [dbo].[GetUserDownline]
(
	@OrgId		    int,
	@UserId		    int,
	@UserName		varchar(50)		= NULL,
	@ParentUserName varchar(50)		= NULL,
	@RoleId		    int				= NULL,
	@DivisionName	varchar(100)	= NULL,
	@ClusterName	varchar(100)	= NULL,
	@RegionId	 	varchar(100)	= NULL,
	@OrderBy		tinyint			= 0,
	@OrderDirection bit				= 0,
	@StartIndex	    int				= 0,
	@PageSize		int				= 10
)
AS
SET NOCOUNT ON
BEGIN
/*
DECLARE 
	@OrgId			int,
	@UserId			int,
	@UserName			varchar(50),
	@ParentUserName	varchar(50),	
	@RoleId			int,
	@DivisionName		varchar(100),
	@ClusterName		varchar(100),
	@RegionName		varchar(100),
	@OrderBy			tinyint,
	@OrderDirection	bit,
	@StartIndex		int,
	@PageSize			int,
	@TotalRowCount		int 

SELECT 
	@OrgId		    = 9,
	@UserId		    = 1,
	@ParentUserName    = null,
	@OrderBy		    = 0,
	@OrderDirection    = 0,
	@StartIndex	    = 0,
	@PageSize		    = 10
*/
	-- We will create a CTE in which we are building the "Extended" user profile
	-- where we will join information for geography and user org profile
	WITH ExtendedUserProfile_CTE AS (
		SELECT
			 UserId				= usr.UserId
			,FirstName			= usr.FirstName
			,LastName			= usr.LastName
			,UserName			= usr.UserName
			,Email				= usr.EmailAddress
			,BusinessRoleId		= urf.BusinessRoleId
			,BusinessRoleName	= urf.BusinessRoleName
			-- For non-hierarchical roles, we obfuscate the geography
			,Division			= CASE WHEN urf.BusinessRoleType = 8 THEN dr.Division ELSE NULL END
			,Cluster			= CASE WHEN urf.BusinessRoleType = 8 THEN dr.market_cluster ELSE NULL END
			,Region				= CASE WHEN urf.BusinessRoleType = 8 THEN dr.Region ELSE NULL END
			-- Pagination and sorting
			,RowNumber			= ROW_NUMBER() OVER (ORDER BY
												CASE WHEN @OrderDirection = 0 AND  @OrderBy = 0 THEN usr.[FirstName] END ASC,
												CASE WHEN @OrderDirection = 0 AND  @OrderBy = 1 THEN usr.[LastName] END ASC,
												CASE WHEN @OrderDirection = 0 AND  @OrderBy = 2 THEN (usr.LastName + ', ' + usr.FirstName + ' (' + usr.UserName + ')') END ASC,
												CASE WHEN @OrderDirection = 0 AND  @OrderBy = 3 THEN usr.[UserName] END ASC,
												CASE WHEN @OrderDirection = 0 AND  @OrderBy = 4 THEN urf.[BusinessRoleName] END ASC,
												CASE WHEN @OrderDirection = 0 AND  @OrderBy = 5 THEN dr.[Division] END ASC,
												CASE WHEN @OrderDirection = 0 AND  @OrderBy = 6 THEN usr.[EmailAddress] END ASC,
												CASE WHEN @OrderDirection = 1 AND  @OrderBy = 0 THEN usr.[FirstName] END DESC,
												CASE WHEN @OrderDirection = 1 AND  @OrderBy = 1 THEN usr.[LastName] END DESC,
												CASE WHEN @OrderDirection = 1 AND  @OrderBy = 2 THEN (usr.LastName + ', ' + usr.FirstName + ' (' + usr.UserName + ')') END DESC,
												CASE WHEN @OrderDirection = 1 AND  @OrderBy = 3 THEN usr.[UserName] END DESC,
												CASE WHEN @OrderDirection = 1 AND  @OrderBy = 4 THEN urf.[BusinessRoleName] END DESC,
												CASE WHEN @OrderDirection = 1 AND  @OrderBy = 5 THEN dr.[Division] END DESC,
												CASE WHEN @OrderDirection = 1 AND  @OrderBy = 6 THEN usr.[EmailAddress] END DESC
											 )
			,TotalRowCount		= COUNT (0) OVER ()
		FROM dbo.UserReporting_Function(@OrgId, @UserId) urf
			INNER JOIN Users usr WITH (NOLOCK) ON urf.UserId = usr.UserId
			INNER JOIN UserDivisionRegionMapping udrm WITH (NOLOCK) ON urf.UserId = udrm.UserId AND udrm.IsDefault = 1
			INNER JOIN DivisionRegion dr WITH (NOLOCK) ON udrm.DivisionRegionId = dr.DivisionRegionId AND dr.OrgId = urf.OrgId
			LEFT JOIN Users u_mgr WITH (NOLOCK) ON u_mgr.UserId = urf.UserParentId
		WHERE 1 = 1
			AND usr.IsActive = 1			-- preliminary naive filter
			AND usr.UserId != @UserId
			AND (@UserName IS NULL OR ( 1 = 0
										OR usr.FirstName LIKE '%' + @UserName + '%'
										OR usr.LastName  LIKE '%' + @UserName + '%'
										OR usr.UserName  LIKE '%' + @UserName + '%'
										OR 	( 1 = 1
												AND @UserName LIKE '%' + usr.FirstName + '%'
												AND @UserName LIKE '%' + usr.LastName + '%'
											)
									  )
				)
			AND (@ParentUserName IS NULL OR ( 1 = 0
												OR u_mgr.FirstName LIKE '%' + @ParentUserName + '%'
												OR u_mgr.LastName  LIKE '%' + @ParentUserName + '%'
												OR u_mgr.UserName  LIKE '%' + @ParentUserName + '%'
												OR 	( 1 = 1
													  AND @ParentUserName LIKE '%' + u_mgr.FirstName + '%'
													  AND @ParentUserName LIKE '%' + u_mgr.LastName + '%'
													)
											)
				)
			AND (@RoleId IS NULL OR urf.BusinessRoleId = @RoleId)
			-- Geography filter only if hierarchical role.
			AND (@DivisionName IS NULL OR (dr.Division LIKE '%' + @DivisionName + '%' AND urf.BusinessRoleType = 8))
			AND (@ClusterName IS NULL OR (dr.market_cluster LIKE '%' + @ClusterName + '%' AND urf.BusinessRoleType = 8))
			AND (@RegionId IS NULL OR (dr.DivisionRegionId = @RegionId AND urf.BusinessRoleType = 8))
	)
	-- Final query statement where we extract one page
	SELECT
		 UserId
		,FirstName
		,LastName
		,UserName
		,Email
		,BusinessRoleName
		,Division
		,TotalRowCount
	FROM ExtendedUserProfile_CTE eup_c
	WHERE 1 = 1
		AND eup_c.RowNumber BETWEEN (@StartIndex) AND (@StartIndex + @PageSize - 1)		-- Pagination
	ORDER BY
		eup_c.RowNumber
	;
END
;

GO


IF EXISTS (SELECT 1 FROM sys.objects WHERE NAME = 'Internationalization_Support' AND type = 'P')
	BEGIN
		EXEC('DROP PROCEDURE [dbo].[Internationalization_Support]')
	END
GO
/****** Object:  StoredProcedure [dbo].[Internationalization_Support]    Script Date: 3/2/2015 6:36:49 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/** Author - Balachandran */
/*

EXEC [Internationalization_Support] 'GET_COUNTRY', '5', '1'
EXEC [Internationalization_Support] 'GET_LABEL', '5', '1', '2'
EXEC [Internationalization_Support] 'GET_LABEL', '8', '1', '0'
EXEC [Internationalization_Support] 'GET_STATE', '5', '1', '1'
EXEC [Internationalization_Support] 'GET_STATE_WITH_POSTAL_REGEX', '5', '1', '2'
EXEC [Internationalization_Support] 'GET_POSTAL_REGEX', '5', '1', '2'

*/

CREATE PROCEDURE [dbo].[Internationalization_Support] (
	@P_Action_Type VARCHAR(50),
	@P_OrgId INT,
	@P_UserId INT,
	@P_CountryId INT = 0
)
AS
SET NOCOUNT ON
BEGIN
	IF @P_Action_Type = 'GET_COUNTRY'
	BEGIN
		SELECT Country.CountryId, CountryKey, CountryName, 
			Postal_Code_RegEx, Postal_Code_Sample,
			State_Label, City_Label, Address_Label, Postal_Code_Label 
		FROM CountryOrgMap
			INNER JOIN Country ON Country.CountryId = CountryOrgMap.CountryId
		WHERE CountryOrgMap.OrgId = @P_OrgId AND Country.IsActive = 1 AND CountryOrgMap.IsActive = 1
		ORDER BY CountryName ASC
	END
	ELSE IF @P_Action_Type = 'GET_POSTAL_REGEX'
	BEGIN		
		SELECT Country.CountryId, CountryKey, CountryName, Postal_Code_RegEx, Postal_Code_Sample, Postal_Code_Label
		FROM CountryOrgMap
			INNER JOIN Country ON Country.CountryId = CountryOrgMap.CountryId
		WHERE CountryOrgMap.OrgId = @P_OrgId AND Country.CountryId = @P_CountryId AND
			Country.IsActive = 1 AND CountryOrgMap.IsActive = 1
	END
	ELSE IF @P_Action_Type = 'GET_LABEL'
	BEGIN
		IF @P_CountryId = NULL OR @P_CountryId = 0
		BEGIN
			/** For Create UI in Lazlo */			
			DECLARE @AddressLabel VARCHAR(50), @CityLabel VARCHAR(50), @StateLabel VARCHAR(50), @ZipLabel VARCHAR(50)
			SELECT @AddressLabel = CASE WHEN CustomizedLabel IS NULL OR CustomizedLabel = '' OR CustomizedLabel = 'null' 
					THEN LabelValue ELSE CustomizedLabel END 
					FROM LabelKeyBundle 
					INNER JOIN LabelKeyValueBundleMap ON LabelKeyValueBundleMap.LabelKeyBundleId = LabelKeyBundle.LabelKeyBundleId
					INNER JOIN LabelValueBundle ON LabelValueBundle.LabelValueBundleId = LabelKeyValueBundleMap.LabelValueBundleId		
					WHERE LabelKeyBundle.IsActive = 'TRUE' AND LabelValueBundle.IsActive = 'TRUE' AND 
						LabelKeyValueBundleMap.OrgId = @P_OrgId AND LabelKeyBundle.IsPortal = 'TRUE'
			AND LabelKey='address'
			SELECT @CityLabel = CASE WHEN CustomizedLabel IS NULL OR CustomizedLabel = '' OR CustomizedLabel = 'null' 
					THEN LabelValue ELSE CustomizedLabel END 
					FROM LabelKeyBundle 
					INNER JOIN LabelKeyValueBundleMap ON LabelKeyValueBundleMap.LabelKeyBundleId = LabelKeyBundle.LabelKeyBundleId
					INNER JOIN LabelValueBundle ON LabelValueBundle.LabelValueBundleId = LabelKeyValueBundleMap.LabelValueBundleId		
					WHERE LabelKeyBundle.IsActive = 'TRUE' AND LabelValueBundle.IsActive = 'TRUE' AND 
						LabelKeyValueBundleMap.OrgId = @P_OrgId AND LabelKeyBundle.IsPortal = 'TRUE'
			AND LabelKey='city' 
			SELECT @StateLabel = CASE WHEN CustomizedLabel IS NULL OR CustomizedLabel = '' OR CustomizedLabel = 'null' 
					THEN LabelValue ELSE CustomizedLabel END 
					FROM LabelKeyBundle 
					INNER JOIN LabelKeyValueBundleMap ON LabelKeyValueBundleMap.LabelKeyBundleId = LabelKeyBundle.LabelKeyBundleId
					INNER JOIN LabelValueBundle ON LabelValueBundle.LabelValueBundleId = LabelKeyValueBundleMap.LabelValueBundleId		
					WHERE LabelKeyBundle.IsActive = 'TRUE' AND LabelValueBundle.IsActive = 'TRUE' AND 
						LabelKeyValueBundleMap.OrgId = @P_OrgId AND LabelKeyBundle.IsPortal = 'TRUE'
			AND  LabelKey='state'
			SELECT @ZipLabel = CASE WHEN CustomizedLabel IS NULL OR CustomizedLabel = '' OR CustomizedLabel = 'null' 
					THEN LabelValue ELSE CustomizedLabel END 
					FROM LabelKeyBundle 
					INNER JOIN LabelKeyValueBundleMap ON LabelKeyValueBundleMap.LabelKeyBundleId = LabelKeyBundle.LabelKeyBundleId
					INNER JOIN LabelValueBundle ON LabelValueBundle.LabelValueBundleId = LabelKeyValueBundleMap.LabelValueBundleId		
					WHERE LabelKeyBundle.IsActive = 'TRUE' AND LabelValueBundle.IsActive = 'TRUE' AND 
						LabelKeyValueBundleMap.OrgId = @P_OrgId AND LabelKeyBundle.IsPortal = 'TRUE'
			AND LabelKey='zip'

				SELECT '' AS CountryId, '' AS CountryKey, '' AS CountryName,
					'' AS Postal_Code_RegEx, '' AS Postal_Code_Sample,
					@StateLabel AS State_Label, @CityLabel AS City_Label, @AddressLabel AS Address_Label, 
					@ZipLabel AS Postal_Code_Label			
		END ELSE
		BEGIN
			SELECT Country.CountryId, CountryKey, CountryName,
				Postal_Code_RegEx, Postal_Code_Sample,
				State_Label, City_Label, Address_Label, Postal_Code_Label
			FROM CountryOrgMap
				INNER JOIN Country ON Country.CountryId = CountryOrgMap.CountryId
			WHERE CountryOrgMap.OrgId = @P_OrgId AND Country.CountryId = @P_CountryId AND
				Country.IsActive = 1 AND CountryOrgMap.IsActive = 1
		END
	END
	ELSE IF @P_Action_Type = 'GET_STATE'
	BEGIN
		SELECT State.StateId, StateName, Abbreviation			 
		FROM State
		INNER JOIN CountryStateMap ON CountryStateMap.StateId = State.StateId
		WHERE CountryStateMap.CountryId = @P_CountryId AND State.IsActive = 1 AND CountryStateMap.IsActive = 1 
		ORDER BY Abbreviation ASC
	END
	ELSE IF @P_Action_Type = 'GET_STATE_WITH_POSTAL_REGEX'
	BEGIN
		SELECT State.StateId, StateName, Abbreviation,
			Postal_Code_RegEx, Postal_Code_Sample, State_Label, City_Label, Address_Label, Postal_Code_Label
		FROM State
		INNER JOIN CountryStateMap ON CountryStateMap.StateId = State.StateId
		INNER JOIN Country ON Country.CountryId = CountryStateMap.CountryId
		WHERE CountryStateMap.CountryId = @P_CountryId AND State.IsActive = 1 AND CountryStateMap.IsActive = 1 
		ORDER BY Abbreviation ASC
	END
END

GO


