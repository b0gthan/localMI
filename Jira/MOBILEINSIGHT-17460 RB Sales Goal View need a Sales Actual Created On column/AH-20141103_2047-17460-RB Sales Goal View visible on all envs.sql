/**************************************
MOBILEINSIGHT-17460
RB: Sales Goal View: need a "Sales Actual Created On" column - make it visible on all envs
***************************************
Auth: Bogdan Lazarescu
Date: 20141103
Database: AH
**************************************/


DECLARE @OBJECT_ID INT, @DEFINITION VARCHAR(MAX)
SELECT @OBJECT_ID = ObjectID FROM Objects WHERE ObjectName = 'SalesGoalsVew'


UPDATE Objects SET HideObject = 0 WHERE ObjectID = @OBJECT_ID  

