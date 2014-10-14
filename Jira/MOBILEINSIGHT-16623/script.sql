--DELETE
DECLARE @OBJECT_ID INT
SELECT @OBJECT_ID = ObjectID FROM Objects WHERE ObjectName = 'SalesGoalsVew'

DELETE FROM ColumnExplanation WHERE ExplanationID IN (SELECT ExplanationID FROM COLUMNS WHERE ObjectID = 1066 UNION ALL SELECT ExplanationID FROM Objects WHERE ObjectName = 'SalesGoalsVew')
DELETE FROM Columns WHERE ObjectID = @OBJECT_ID
DELETE FROM CategoryObjects WHERE ObjectID = @OBJECT_ID
DELETE FROM UserReport WHERE UsedObjects = @OBJECT_ID
DELETE FROM Objects WHERE ObjectID = @OBJECT_ID