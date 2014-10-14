-- Find out tenant user is in (passed as a parameter from Portal app)
-- Find who I am  (passed as a parameter from Portal app)
-- Find all all downlines for this user
-- Get most recent ContributionHistory data for all these users (for current month only)
-- To additional attributes of the user and his manager
-- -- Join with Users for user info (userId column of ContributionHistory table)
-- -- Join with UserOrgProfile (on userid in both tables)
-- -- Join with Users for manager info (join userid with userparentid in UserOrgProfile)
-- -- User's role (join UserOrgProfile and BusinessRole)
-- -- Manager's role (join UserOrgProfile of the manager and BusinessRole)

For the time being focus on these columns
** ContributionHistory table
- Contribution, VisitGoal, VisitGoalMTD, ActualVisits, AverageVisitLenght, OutOfOffice
** Users table for each user
- username, firstname, lastname, businessrole
** Users table for each User''s Manager
- username, firstname, lastname, businessrole
** From no table
-- Start of the month, Today (YYYY-MM-DD) as date

SELECT TOP 10 * FROM ContributionHistory
SELECT CH.USERID, CH.OrgId, Contribution, VisitGoal, VisitGoalMTD, ActualVisits, AverageVisitLenght, OutOfOffice
FROM ContributionHistory CH
	INNER JOIN (SELECT USERID, OrgID, MAX(CreatedDate) AS CreatedDate 
		FROM ContributionHistory 
		WHERE YEAR(CreatedDate) = YEAR(GETDATE()) AND MONTH(CreatedDate) = MONTH(GETDATE()) 
		GROUP BY USERID, OrgID) CH_G ON CH.USERID = CH_G.USERID AND CH.OrgId = CH_G.OrgId
11, 322

SELECT DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0)


DECLARE @P_OrgId INT, @P_UserId INT
SELECT @P_OrgId = 11, @P_UserId = 283

SELECT u.UserName "Username",   u.FirstName "First name",   u.LastName "Last name", urf.BusinessRoleName "User hierarchy name",   u_mgr.UserName "Manager Username",   u_mgr.FirstName "Manager First name",   u_mgr.LastName "Manager Last name", br_mgr.BusinessRoleName "Manager User hierarchy name", CH.Contribution, CH.VisitGoal AS "Visit Goal", CH.VisitGoalMTD AS "Visit Goal MTD", CH.ActualVisits AS "Actual Visit", CH.AverageVisitLenght AS "Average Visit Lenght", CH.OutOfOffice AS "Out Of Office"
	, DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS "Start of the month", GETDATE() AS "Today"
FROM Downline_NoTestData(@P_OrgId, @P_UserId) urf
	INNER JOIN users u on urf.userid = u.userId  
	INNER JOIN users u_mgr on u_mgr.userid = urf.UserParentId
	left join userorgprofile uop_mgr on uop_mgr.userid = u_mgr.userid and uop_mgr.orgid = @P_OrgId
	left join businessrole br_mgr on br_mgr.BusinessRoleId = uop_mgr.BusinessRoleId     --sales goals details   
	INNER JOIN (SELECT CH.UserId, CH.OrgId, Contribution, VisitGoal, VisitGoalMTD, ActualVisits, AverageVisitLenght, OutOfOffice
				FROM ContributionHistory CH
					INNER JOIN (SELECT UserId, OrgID, MAX(CreatedDate) AS CreatedDate 
						FROM ContributionHistory 
						WHERE YEAR(CreatedDate) = YEAR(GETDATE()) AND MONTH(CreatedDate) = MONTH(GETDATE()) 
						GROUP BY UserId, OrgID) CH_G ON CH.UserId = CH_G.UserId AND CH.OrgId = CH_G.OrgId AND CH.CreatedDate = CH_G.CreatedDate) CH ON URF.UserId = CH.UserId AND CH.OrgId = @P_OrgId


--insert
DECLARE @OBJECT_ID INT
INSERT INTO Objects (ObjectSchema, ObjectName, ObjectAlias, Description, Type, DatabaseID, Definition, HideObject, ExplanationID, IsCatalogue)
SELECT '', 'ContributionView', '', 'Contribution View', 'VV', 1, 'SELECT u.UserName "Username",   u.FirstName "First name",   u.LastName "Last name", urf.BusinessRoleName "User hierarchy name",   u_mgr.UserName "Manager Username",   u_mgr.FirstName "Manager First name",   u_mgr.LastName "Manager Last name", br_mgr.BusinessRoleName "Manager User hierarchy name", CH.Contribution, CH.VisitGoal AS "Visit Goal", CH.VisitGoalMTD AS "Visit Goal MTD", CH.ActualVisits AS "Actual Visit", CH.AverageVisitLenght AS "Average Visit Lenght", CH.OutOfOffice AS "Out Of Office"
	, DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS "Start of the month", GETDATE() AS "Today"
FROM Downline_NoTestData(@Session.orgId~, @Session.userId~) urf
	INNER JOIN users u on urf.userid = u.userId  
	INNER JOIN users u_mgr on u_mgr.userid = urf.UserParentId
	left join userorgprofile uop_mgr on uop_mgr.userid = u_mgr.userid and uop_mgr.orgid = @Session.orgId~
	left join businessrole br_mgr on br_mgr.BusinessRoleId = uop_mgr.BusinessRoleId
	INNER JOIN (SELECT CH.UserId, CH.OrgId, Contribution, VisitGoal, VisitGoalMTD, ActualVisits, AverageVisitLenght, OutOfOffice
				FROM ContributionHistory CH
					INNER JOIN (SELECT UserId, OrgID, MAX(CreatedDate) AS CreatedDate 
						FROM ContributionHistory 
						WHERE YEAR(CreatedDate) = YEAR(GETDATE()) AND MONTH(CreatedDate) = MONTH(GETDATE()) 
						GROUP BY UserId, OrgID) CH_G ON CH.UserId = CH_G.UserId AND CH.OrgId = CH_G.OrgId AND CH.CreatedDate = CH_G.CreatedDate) CH ON URF.UserId = CH.UserId AND CH.OrgId = @Session.orgId~' AS Definition, 0, 0, 1

SET @OBJECT_ID = SCOPE_IDENTITY()

INSERT INTO CategoryObjects (CategoryID, ObjectID) SELECT 8, @OBJECT_ID

INSERT INTO Columns (ColumnName, ColumnAlias, Description, ColumnType, ObjectID, OrdinalPosition, ColumnOrder, DataType, CharacterMaxLen, NumericPrecision
, NumericScale, DisplayFormat, Alignment, NativeDataType, Definition, ExplanationID, LinkRptID, LinkURL, FrameID, HideColumn)
SELECT 'Username','','Username', 'V', @OBJECT_ID, 1,1,200,50,255,255,'','Left', 0, 'Username', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'First name','','First name', 'V', @OBJECT_ID, 2,2,200,100,255,255,'','Left', 0, 'First name', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Last name','','Last name', 'V', @OBJECT_ID, 3,3,200,100,255,255,'','Left', 0, 'Last name', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'User hierarchy name','','User hierarchy name', 'V', @OBJECT_ID, 4,4,200,50,255,255,'','Left', 0, 'User hierarchy name', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Manager Username','','Manager Username', 'V', @OBJECT_ID, 5,5,200,50,255,255,'','Left', 0, 'Manager Username', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Manager First name','','Manager First name', 'V', @OBJECT_ID, 6,6,200,100,255,255,'','Left', 0, 'Manager First name', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Manager Last name','','Manager Last name', 'V', @OBJECT_ID, 7,7,200,100,255,255,'','Left', 0, 'Manager Last name', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Manager User hierarchy name','','Manager User hierarchy name', 'V', @OBJECT_ID, 8,8,200,50,255,255,'','Left', 0, 'Manager User hierarchy name', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Contribution','','Contribution', 'V', @OBJECT_ID, 9,9,14,17,10,3,'General Number','Right', 0, 'Contribution', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Visit Goal','','Visit Goal', 'V', @OBJECT_ID, 10,10,15,17,10,3,'General Number','Right', 0, 'Visit Goal', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Visit Goal MTD','','Visit Goal MTD', 'V', @OBJECT_ID, 11,11,16,17,10,3,'General Number','Right', 0, 'Visit Goal MTD', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Actual Visit','','Actual Visit', 'V', @OBJECT_ID, 12,12,17,17,10,3,'General Number','Right', 0, 'Actual Visit', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Average Visit Lenght','','Average Visit Lenght', 'V', @OBJECT_ID, 13,13,18,17,10,3,'General Number','Right', 0, 'Average Visit Lenght', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Out Of Office','','Out Of Office', 'V', @OBJECT_ID, 14,14,11,1,255,255,'','Left', 0, 'Out Of Office', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Start of the month','','Start of the month', 'V', @OBJECT_ID, 15,15,135,8,23,3, 'Short Date','Left', 0, 'Start of the month', 0, 0, NULL, NULL, 0
UNION ALL SELECT 'Today','','Today', 'V', @OBJECT_ID, 16,16,135,8,23,3, 'Short Date','Left', 0, 'Today', 0, 0, NULL, NULL, 0

--DELETE
DECLARE @OBJECT_ID INT
SELECT @OBJECT_ID = ObjectID FROM Objects WHERE ObjectName = 'ContributionView'

DELETE FROM Columns WHERE ObjectID = @OBJECT_ID
DELETE FROM CategoryObjects WHERE ObjectID = @OBJECT_ID
DELETE FROM Objects WHERE ObjectID = @OBJECT_ID