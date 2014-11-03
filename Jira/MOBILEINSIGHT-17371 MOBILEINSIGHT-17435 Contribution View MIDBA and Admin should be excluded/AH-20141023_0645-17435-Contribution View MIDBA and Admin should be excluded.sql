/**************************************
MOBILEINSIGHT-17435
Contribution View: MIDBA and Admin should be excluded
***************************************
Auth: Bogdan Lazarescu
Date: 20141023
Database: AH
**************************************/


DECLARE @OBJECT_ID INT, @DEFINITION VARCHAR(MAX)
SELECT @OBJECT_ID = ObjectID FROM Objects WHERE ObjectName = 'ContributionView'

SET @DEFINITION = 'SELECT u.UserName "Username",   u.FirstName "First name",   u.LastName "Last name", urf.BusinessRoleName "User’s Role", u.isActive AS "Is Active"
	,   u_mgr.UserName "Manager Username",   u_mgr.FirstName "Manager First name",   u_mgr.LastName "Manager Last name", br_mgr.BusinessRoleName "Manager’s Role", CH.Contribution
	, CH.VisitGoal AS "Visit Goal", CH.VisitGoalMTD AS "Visit Goal MTD", CH.ActualVisits AS "Actual Visit", CH.AverageVisitLenght AS "Average Visit Length", CH.OutOfOffice AS "Out Of Office"
	, DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AS "Start of the month", DATEADD(d, -1, GETDATE()) AS "Yesterday"
FROM Downline_NoTestData(@Session.orgId~, @Session.userId~) urf
	INNER JOIN users u on urf.userid = u.userId  
	left join userorgprofile uop on uop.userid = u.userid and uop.orgid = @Session.orgId~
	left join businessrole br on br.BusinessRoleId = uop.BusinessRoleId
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