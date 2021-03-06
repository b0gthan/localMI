/**************************************
MOBILEINSIGHT-17485
Report Builder: Contribution View: Apostrophe is incorrectly displayed.
***************************************
Auth: Bogdan Lazarescu
Date: 20141105
Database: AH
**************************************/

declare @ObjectID INT
SELECT @ObjectID = ObjectID FROM Objects WHERE ObjectName = 'ContributionView'

UPDATE Objects SET Definition = REPLACE(Definition, 'Æ', '’') where ObjectID = @ObjectID
UPDATE Columns SET ColumnName = REPLACE(ColumnName, 'Æ', '’')
	,Description = REPLACE(Description, 'Æ', '’')
	,Definition = REPLACE(Definition, 'Æ', '’')  
WHERE ObjectID = @ObjectID