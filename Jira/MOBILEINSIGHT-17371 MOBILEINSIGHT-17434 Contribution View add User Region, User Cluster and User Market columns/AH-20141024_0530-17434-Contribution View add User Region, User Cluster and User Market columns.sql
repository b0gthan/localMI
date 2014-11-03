/**************************************
MOBILEINSIGHT-17435
Contribution View: MIDBA and Admin should be excluded
MOBILEINSIGHT-17434
Contribution View: Contribution View add User Region, User Cluster and User Market columns
***************************************
Auth: Bogdan Lazarescu
Date: 20141024
Database: AH
**************************************/


DECLARE @OBJECT_ID INT, @DEFINITION VARCHAR(MAX)
SELECT @OBJECT_ID = ObjectID FROM Objects WHERE ObjectName = 'ContributionView'

SET @DEFINITION = 'SELECT u.UserName "Username",   u.FirstName "First name",   u.LastName "Last name", u.FullName "Full name", urf.BusinessRoleName "User’s Role"
	, dr.Division "User Region", dr.market_cluster "User Cluster",   dr.region "User Market"   
	, u.isActive AS "Is Active"
	, u_mgr.UserName "Manager Username",   u_mgr.FirstName "Manager First name",   u_mgr.LastName "Manager Last name",   u_mgr.FullName "Manager Full name", br_mgr.BusinessRoleName "Manager’s Role", CH.Contribution
	, CH.VisitGoal AS "Visit Goal", CH.VisitGoalMTD AS "Visit Goal MTD", CH.ActualVisits AS "Actual Visit", CH.AverageVisitLenght AS "Average Visit Length", CH.OutOfOffice AS "Out Of Office"
	, DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS "Start of the month", DATEADD(d, -1, GETDATE()) AS "Yesterday"
FROM Downline_NoTestData(@Session.orgId~, @Session.userId~) urf
	INNER JOIN users u on urf.userid = u.userId  
	left join userorgprofile uop on uop.userid = u.userid and uop.orgid = @Session.orgId~
	left join businessrole br on br.BusinessRoleId = uop.BusinessRoleId
	INNER JOIN UserDivisionRegionMapping udrm WITH(NOLOCK) ON udrm.UserId = urf.UserId AND udrm.IsDefault = 1   
	INNER JOIN DivisionRegion dr WITH(NOLOCK) ON dr.DivisionRegionId = udrm.DivisionRegionId and dr.orgId = @Session.orgId~

	LEFT JOIN users u_mgr on u_mgr.userid = urf.UserParentId
	left join userorgprofile uop_mgr on uop_mgr.userid = u_mgr.userid and uop_mgr.orgid = @Session.orgId~
	left join businessrole br_mgr on br_mgr.BusinessRoleId = uop_mgr.BusinessRoleId
	LEFT JOIN (SELECT CH.UserId, CH.OrgId, Contribution, VisitGoal, VisitGoalMTD, ActualVisits, AverageVisitLenght, OutOfOffice
				FROM ContributionHistory CH
					INNER JOIN (SELECT UserId, OrgID, MAX(CreatedDate) AS CreatedDate 
						FROM ContributionHistory 
						WHERE YEAR(CreatedDate) = YEAR(GETDATE()) AND MONTH(CreatedDate) = MONTH(GETDATE()) 
						GROUP BY UserId, OrgID) CH_G ON CH.UserId = CH_G.UserId AND CH.OrgId = CH_G.OrgId AND CH.CreatedDate = CH_G.CreatedDate) CH ON URF.UserId = CH.UserId AND CH.OrgId = @Session.orgId~
WHERE BR.BusinessRoleType = 8'

UPDATE Objects SET Definition = @DEFINITION WHERE ObjectID = @OBJECT_ID  

DELETE FROM Columns WHERE ObjectID = @OBJECT_ID

INSERT INTO ColumnExplanation(Explanation) SELECT 'User''s full name (last name, first name)' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'User''s full name (last name, first name)')
INSERT INTO ColumnExplanation(Explanation) SELECT 'Region assigned to the user' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'Region assigned to the user')
INSERT INTO ColumnExplanation(Explanation) SELECT 'Cluster assigned to the user' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'Cluster assigned to the user')
INSERT INTO ColumnExplanation(Explanation) SELECT 'Market assigned to the user' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'Market assigned to the user')
INSERT INTO ColumnExplanation(Explanation) SELECT 'Manager''s full name (last name, first name)' WHERE NOT EXISTS (SELECT 1 FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR) = 'Manager''s full name (last name, first name)')

INSERT INTO Columns
SELECT 'Username','','Username','V',@OBJECT_ID,1,1,200,50,255,255,'','Left',0,'Username',0,0,NULL,NULL,0
UNION ALL SELECT 'First name','','First name','V',@OBJECT_ID,2,2,200,100,255,255,'','Left',0,'First name',0,0,NULL,NULL,0
UNION ALL SELECT 'Last name','','Last name','V',@OBJECT_ID,3,3,200,100,255,255,'','Left',0,'Last name',0,0,NULL,NULL,0
UNION ALL SELECT 'Full name','','Full name','V',@OBJECT_ID,4,4,200,100,255,255,'','Left',0,'Full name',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'User''s full name (last name, first name)'),0,NULL,NULL,0
UNION ALL SELECT 'User’s Role','','User’s Role','V',@OBJECT_ID,5,5,200,50,255,255,'','Left',0,'User’s Role',0,0,NULL,NULL,0
UNION ALL SELECT 'User Region','','User Region','V',@OBJECT_ID,6,6,200,100,255,255,'','Left',0,'User Region',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Region assigned to the user'),0,NULL,NULL,0
UNION ALL SELECT 'User Cluster','','User Cluster','V',@OBJECT_ID,7,7,200,100,255,255,'','Left',0,'User Cluster',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Cluster assigned to the user'),0,NULL,NULL,0
UNION ALL SELECT 'User Market','','User Market','V',@OBJECT_ID,8,8,200,100,255,255,'','Left',0,'User Market',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Market assigned to the user'),0,NULL,NULL,0
UNION ALL SELECT 'Is Active','','Is Active','V',@OBJECT_ID,9,9,11,1,255,255,'','Left',0,'Is Active',0,0,NULL,NULL,0
UNION ALL SELECT 'Manager Username','','Manager Username','V',@OBJECT_ID,10,10,200,50,255,255,'','Left',0,'Manager Username',0,0,NULL,NULL,0
UNION ALL SELECT 'Manager First name','','Manager First name','V',@OBJECT_ID,11,11,200,100,255,255,'','Left',0,'Manager First name',0,0,NULL,NULL,0
UNION ALL SELECT 'Manager Last name','','Manager Last name','V',@OBJECT_ID,12,12,200,100,255,255,'','Left',0,'Manager Last name',0,0,NULL,NULL,0
UNION ALL SELECT 'Manager Full name','','Manager Full name','V',@OBJECT_ID,13,13,200,100,255,255,'','Left',0,'Manager Full name',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Manager''s full name (last name, first name)'),0,NULL,NULL,0
UNION ALL SELECT 'Manager’s Role','','Manager’s Role ','V',@OBJECT_ID,14,14,200,50,255,255,'','Left',0,'Manager’s Role',0,0,NULL,NULL,0
UNION ALL SELECT 'Visit Goal','','Visit Goal','V',@OBJECT_ID,15,15,18,17,10,3,'General Number','Right',0,'Visit Goal',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'number of visits expected this Month'),0,NULL,NULL,0
UNION ALL SELECT 'Out Of Office','','Out Of Office','V',@OBJECT_ID,16,16,3,4,10,255,'','Left',0,'Out Of Office',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Out of Office days'),0,NULL,NULL,0
UNION ALL SELECT 'Visit Goal MTD','','Visit Goal MTD','V',@OBJECT_ID,17,17,18,17,10,3,'General Number','Right',0,'Visit Goal MTD',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'number of visits expected Month to date'),0,NULL,NULL,0
UNION ALL SELECT 'Actual Visit','','Actual Visit','V',@OBJECT_ID,18,18,18,17,10,3,'General Number','Right',0,'Actual Visit',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'number of visits completed'),0,NULL,NULL,0
UNION ALL SELECT 'Contribution','','Contribution','V',@OBJECT_ID,19,19,18,17,10,3,'General Number','Right',0,'Contribution',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Individual productivity'),0,NULL,NULL,0
UNION ALL SELECT 'Average Visit Length','','Average Visit Length','V',@OBJECT_ID,20,20,18,17,10,3,'General Number','Right',0,'Average Visit Length',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'average length of submitted visits'),0,NULL,NULL,0
UNION ALL SELECT 'Start of the month','','Start of the month','V',@OBJECT_ID,21,21,135,8,23,3,'Short Date','Left',0,'Start of the month',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'This month start'),0,NULL,NULL,0
UNION ALL SELECT 'Yesterday','','Yesterday','V',@OBJECT_ID,22,22,135,8,23,3,'Short Date','Left',0,'Today',(SELECT TOP 1 ExplanationID FROM ColumnExplanation WHERE CAST(Explanation AS VARCHAR(250)) = 'Yesterday’s date'),0,NULL,NULL,0
