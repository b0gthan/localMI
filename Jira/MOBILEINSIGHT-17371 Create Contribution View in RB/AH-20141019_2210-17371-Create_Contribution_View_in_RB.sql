/**************************************
MOBILEINSIGHT-17371
Create Contribution View in RB
***************************************
Auth: Bogdan Lazarescu
Date: 20141019
Database: AH
**************************************/

--insert
DECLARE @OBJECT_ID INT
INSERT INTO Objects (ObjectSchema, ObjectName, ObjectAlias, Description, Type, DatabaseID, Definition, HideObject, ExplanationID, IsCatalogue)
SELECT '', 'ContributionView', '', 'Contribution View', 'VV', 1, 'SELECT u.UserName "Username",   u.FirstName "First name",   u.LastName "Last name", urf.BusinessRoleName "User’s Role", u.isActive AS "Is Active"
	,   u_mgr.UserName "Manager Username",   u_mgr.FirstName "Manager First name",   u_mgr.LastName "Manager Last name", br_mgr.BusinessRoleName "Manager’s Role", CH.Contribution
	, CH.VisitGoal AS "Visit Goal", CH.VisitGoalMTD AS "Visit Goal MTD", CH.ActualVisits AS "Actual Visit", CH.AverageVisitLenght AS "Average Visit Length", CH.OutOfOffice AS "Out Of Office"
	, DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS "Start of the month", DATEADD(d, -1, GETDATE()) AS "Yesterday"
FROM Downline_NoTestData(@Session.orgId~, @Session.userId~) urf
	INNER JOIN users u on urf.userid = u.userId  
	LEFT JOIN users u_mgr on u_mgr.userid = urf.UserParentId
	left join userorgprofile uop_mgr on uop_mgr.userid = u_mgr.userid and uop_mgr.orgid = @Session.orgId~
	left join businessrole br_mgr on br_mgr.BusinessRoleId = uop_mgr.BusinessRoleId
	LEFT JOIN (SELECT CH.UserId, CH.OrgId, Contribution, VisitGoal, VisitGoalMTD, ActualVisits, AverageVisitLenght, OutOfOffice
				FROM ContributionHistory CH
					INNER JOIN (SELECT UserId, OrgID, MAX(CreatedDate) AS CreatedDate 
						FROM ContributionHistory 
						WHERE YEAR(CreatedDate) = YEAR(GETDATE()) AND MONTH(CreatedDate) = MONTH(GETDATE()) 
						GROUP BY UserId, OrgID) CH_G ON CH.UserId = CH_G.UserId AND CH.OrgId = CH_G.OrgId AND CH.CreatedDate = CH_G.CreatedDate) CH ON URF.UserId = CH.UserId AND CH.OrgId = @Session.orgId~' AS Definition, 0, 0, 1

SET @OBJECT_ID = SCOPE_IDENTITY()

INSERT INTO CategoryObjects (CategoryID, ObjectID) SELECT 8, @OBJECT_ID

INSERT INTO ColumnExplanation(Explanation) SELECT 'Individual productivity' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'Individual productivity')
INSERT INTO ColumnExplanation(Explanation) SELECT 'number of visits expected this Month' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'number of visits expected this Month')
INSERT INTO ColumnExplanation(Explanation) SELECT 'number of visits expected Month to date' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'number of visits expected Month to date')
INSERT INTO ColumnExplanation(Explanation) SELECT 'number of visits completed' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'number of visits completed')
INSERT INTO ColumnExplanation(Explanation) SELECT 'average length of submitted visits' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'average length of submitted visits')
INSERT INTO ColumnExplanation(Explanation) SELECT 'Out of Office days' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'Out of Office days')
INSERT INTO ColumnExplanation(Explanation) SELECT 'This month start' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'This month start')
INSERT INTO ColumnExplanation(Explanation) SELECT 'Yesterday’s date' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'Yesterday’s date')

INSERT INTO Columns (ColumnName, ColumnAlias, Description, ColumnType, ObjectID, OrdinalPosition, ColumnOrder, DataType, CharacterMaxLen, NumericPrecision
, NumericScale, DisplayFormat, Alignment, NativeDataType, Definition, ExplanationID, LinkRptID, LinkURL, FrameID, HideColumn)
SELECT 'Username','','Username','V',@OBJECT_ID,1,1,200,50,255,255,'','Left',0,'Username',0,0,NULL,NULL,0
UNION ALL SELECT 'First name','','First name','V',@OBJECT_ID,2,2,200,100,255,255,'','Left',0,'First name',0,0,NULL,NULL,0
UNION ALL SELECT 'Last name','','Last name','V',@OBJECT_ID,3,3,200,100,255,255,'','Left',0,'Last name',0,0,NULL,NULL,0
UNION ALL SELECT 'User’s Role','','User’s Role','V',@OBJECT_ID,4,4,200,50,255,255,'','Left',0,'User’s Role',0,0,NULL,NULL,0
UNION ALL SELECT 'Is Active','','Is Active','V',@OBJECT_ID,5,5,11,1,255,255,'','Left',0,'Is Active',0,0,NULL,NULL,0
UNION ALL SELECT 'Manager Username','','Manager Username','V',@OBJECT_ID,6,6,200,50,255,255,'','Left',0,'Manager Username',0,0,NULL,NULL,0
UNION ALL SELECT 'Manager First name','','Manager First name','V',@OBJECT_ID,7,7,200,100,255,255,'','Left',0,'Manager First name',0,0,NULL,NULL,0
UNION ALL SELECT 'Manager Last name','','Manager Last name','V',@OBJECT_ID,8,8,200,100,255,255,'','Left',0,'Manager Last name',0,0,NULL,NULL,0
UNION ALL SELECT 'Manager’s Role','','Manager’s Role ','V',@OBJECT_ID,9,9,200,50,255,255,'','Left',0,'Manager’s Role',0,0,NULL,NULL,0
UNION ALL SELECT 'Visit Goal','','Visit Goal','V',@OBJECT_ID,10,10,18,17,10,3,'General Number','Right',0,'Visit Goal',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'number of visits expected this Month'),0,NULL,NULL,0
UNION ALL SELECT 'Out Of Office','','Out Of Office','V',@OBJECT_ID,11,11,3,4,10,255,'','Left',0,'Out Of Office',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Out of Office days'),0,NULL,NULL,0
UNION ALL SELECT 'Visit Goal MTD','','Visit Goal MTD','V',@OBJECT_ID,12,12,18,17,10,3,'General Number','Right',0,'Visit Goal MTD',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'number of visits expected Month to date'),0,NULL,NULL,0
UNION ALL SELECT 'Actual Visit','','Actual Visit','V',@OBJECT_ID,13,13,18,17,10,3,'General Number','Right',0,'Actual Visit',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'number of visits completed'),0,NULL,NULL,0
UNION ALL SELECT 'Contribution','','Contribution','V',@OBJECT_ID,14,14,18,17,10,3,'General Number','Right',0,'Contribution',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Individual productivity'),0,NULL,NULL,0
UNION ALL SELECT 'Average Visit Length','','Average Visit Length','V',@OBJECT_ID,15,15,18,17,10,3,'General Number','Right',0,'Average Visit Length',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'average length of submitted visits'),0,NULL,NULL,0
UNION ALL SELECT 'Start of the month','','Start of the month','V',@OBJECT_ID,16,16,135,8,23,3,'Short Date','Left',0,'Start of the month',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'This month start'),0,NULL,NULL,0
UNION ALL SELECT 'Yesterday','','Yesterday','V',@OBJECT_ID,17,17,135,8,23,3,'Short Date','Left',0,'Today',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Yesterday’s date'),0,NULL,NULL,0
