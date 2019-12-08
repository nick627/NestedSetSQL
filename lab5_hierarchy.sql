--CREATE DATABASE Lab5;

USE Lab5;

IF OBJECT_ID('dbo.Node', 'U') IS NOT NULL
	DROP TABLE [Node];

CREATE TABLE [Node] (
	[NodeID] INTEGER PRIMARY KEY,
	[Left] INTEGER NOT NULL,
	[Right] INTEGER NOT NULL,
	[Name] VARCHAR(80) NOT NULL
);

INSERT INTO [Node] ([NodeID], [Left], [Right], [Name]) VALUES
    (1, 0, 15, 'Россия'),
    (2, 1, 4, 'Северо-западный округ'),
    (3, 5, 14, 'Центральный округ'),
    (4, 2, 3, 'Ленинградская область'),
    (5, 6, 7, 'Тверская область'),
    (6, 8, 11, 'Московская область'),
    (7, 12, 13, 'Курская область'),
    (8, 9, 10, 'Москва');

--[----------------------------------------------------------------------------]
--[ 1. Вывести список всех терминальных элементов
--[----------------------------------------------------------------------------]

--SELECT [NodeID] 
--FROM [Node] 
--WHERE [Right] - [Left] = 1;

--[----------------------------------------------------------------------------]
--[ 2. Найти корень дерева
--[----------------------------------------------------------------------------]

--SELECT [NodeID] 
--FROM [Node] 
--WHERE [Left] = 0;

--[----------------------------------------------------------------------------]
--[ 3. Определить длину максимального пути (глубину) дерева
--[----------------------------------------------------------------------------]

--SELECT TOP 1 (COUNT(parent.[NodeID]) - 1) AS [Level]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--GROUP BY node.[Name]
--ORDER BY [Level] DESC;

--[----------------------------------------------------------------------------]
--[ 4. Вывести все пути по одному (двум, трем, ...) уровням в дереве
--[----------------------------------------------------------------------------]

--DECLARE @Level INTEGER = 3;

--SELECT node.[NodeID], (COUNT(parent.name) - 1) AS [Level] INTO #NodeLevel
--FROM [Node] node, [Node] parent
--WHERE node.[Left] BETWEEN PARENT.[Left] AND PARENT.[Right]
--GROUP BY node.[NodeID]
--ORDER BY [Level];

--SELECT [NodeID] 
--FROM #NodeLevel
--WHERE [Level] = @Level;

--DROP TABLE #NodeLevel;

--[----------------------------------------------------------------------------]
--[ 5. Суммирование данных узлов по поддереву от заданного корня
--[----------------------------------------------------------------------------]

--DECLARE @RootNodeID INTEGER = 3;

--SELECT SUM(node.[NodeID]) AS 'Sum'
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  parent.[NodeID] = @RootNodeID AND parent.[NodeID] <> node.[NodeID];

--[----------------------------------------------------------------------------]
--[ 6. Вычислить уровень иерархии данного узла (@NodeID)
--[----------------------------------------------------------------------------]

--DECLARE @NodeID INTEGER = 5;

--SELECT (COUNT(parent.[NodeID]) - 1) AS [Level]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] and node.[NodeID] = @NodeID
--GROUP BY node.[Name];

--[----------------------------------------------------------------------------]
--[ 7. Вычислить уровни всех узлов
--[----------------------------------------------------------------------------]

--SELECT node.[NodeID], (COUNT(parent.name) - 1) AS [Level]
--FROM [Node] node, [Node] parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--GROUP BY node.[NodeID]
--ORDER BY [Level];

--[----------------------------------------------------------------------------]
--[ 8. Вычислить разность уровней двух заданных узлов
--[----------------------------------------------------------------------------]

--DECLARE @NodeID1 INTEGER = 6;
--DECLARE @NodeID2 INTEGER = 8;

--SELECT parent.[NodeID], parent.[Left] INTO #NodePath1
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID1
--GROUP BY parent.[NodeID], parent.[Left]
--ORDER BY parent.[NodeID];

--SELECT parent.[NodeID], parent.[Left] INTO #NodePath2
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID2
--GROUP BY parent.[NodeID], parent.[Left]
--ORDER BY parent.[NodeID];

--SELECT T1.[NodeID], T1.[Left] INTO #MatchedEntries 
--FROM #NodePath1 T1, #NodePath2 T2
--WHERE T1.NodeID = T2.NodeID
--ORDER BY T1.NodeID;

--DECLARE @MaxLeft INTEGER;
--SELECT @MaxLeft = MAX([Left]) FROM #MatchedEntries;

--SELECT COUNT(*) - 1 AS LevelDifference FROM
--(
--(SELECT [NodeID] FROM #NodePath1
--UNION
--SELECT [NodeID] FROM #NodePath2)
--EXCEPT 
--SELECT [NodeID] FROM #MatchedEntries
--UNION
--SELECT [NodeID] FROM #MatchedEntries WHERE [Left] = @MaxLeft
--) AS PathNodes;

--DROP TABLE #NodePath1;
--DROP TABLE #NodePath2;
--DROP TABLE #MatchedEntries;

--[----------------------------------------------------------------------------]
--[ 9. Вывести путь между двумя узлами
--[----------------------------------------------------------------------------]

--DECLARE @NodeID1 INTEGER = 3;
--DECLARE @NodeID2 INTEGER = 8;

--SELECT parent.[NodeID], parent.[Left] INTO #NodePath1
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID1
--GROUP BY parent.[NodeID], parent.[Left]
--ORDER BY parent.[NodeID];

--SELECT parent.[NodeID], parent.[Left] INTO #NodePath2
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID2
--GROUP BY parent.[NodeID], parent.[Left]
--ORDER BY parent.[NodeID];

--SELECT T1.[NodeID], T1.[Left] INTO #MatchedEntries 
--FROM #NodePath1 T1, #NodePath2 T2
--WHERE T1.NodeID = T2.NodeID
--ORDER BY T1.NodeID;

--DECLARE @MaxLeft INTEGER;
--SELECT @MaxLeft = MAX([Left]) FROM #MatchedEntries;

--(SELECT [NodeID] FROM #NodePath1
--UNION
--SELECT [NodeID] FROM #NodePath2)
--EXCEPT 
--SELECT [NodeID] FROM #MatchedEntries
--UNION
--SELECT [NodeID] FROM #MatchedEntries WHERE [Left] = @MaxLeft;

--DROP TABLE #NodePath1;
--DROP TABLE #NodePath2;
--DROP TABLE #MatchedEntries;

--[----------------------------------------------------------------------------]
--[ 10. Вывести всех потомков данного элемента 
--[----------------------------------------------------------------------------]
--[ 10.a. Всех потомков
--[----------------------------------------------------------------------------]
--DECLARE @NodeID INTEGER = 1;

--SELECT node.[NodeID] 
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND
--	  node.[NodeID] <> parent.[NodeID] AND
--	  parent.[NodeID] = @NodeID;

--[----------------------------------------------------------------------------]
--[ 10.b. Потомков заданного уровня (детей, внуков, ...)
--[----------------------------------------------------------------------------]
--DECLARE @NodeID INTEGER = 3;
--DECLARE @Level INTEGER = 2;

--SELECT NodeLevels.[NodeID]
--FROM 
--	(
--		SELECT node.[NodeID], node.[Left], node.[Right], (COUNT(parent.name) - 1) AS [Level]
--		FROM [Node] node, [Node] parent
--		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--		GROUP BY node.[NodeID], node.[Left], node.[Right]
--	) AS NodeLevels,
--	(
--		SELECT node.[NodeID], node.[Left], node.[Right], (COUNT(parent.name) - 1) AS [Level]
--		FROM [Node] node, [Node] parent
--		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--		GROUP BY node.[NodeID], node.[Left], node.[Right]
--	) AS ParentLevels
--WHERE NodeLevels.[Left] BETWEEN ParentLevels.[Left] AND ParentLevels.[Right] AND
--	  NodeLevels.[NodeID] <> ParentLevels.[NodeID] AND
--	  ParentLevels.[NodeID] = @NodeID AND
--	  NodeLevels.[Level] = @Level;

--[----------------------------------------------------------------------------]
--[ 10.c. Потомков до заданного уровня
--[----------------------------------------------------------------------------]
--DECLARE @NodeID INTEGER = 1;
--DECLARE @Level INTEGER = 3;

--SELECT NodeLevels.[NodeID]
--FROM 
--	(
--		SELECT node.[NodeID], node.[Left], node.[Right], (COUNT(parent.name) - 1) AS [Level]
--		FROM [Node] node, [Node] parent
--		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--		GROUP BY node.[NodeID], node.[Left], node.[Right]
--	) AS NodeLevels,
--	(
--		SELECT node.[NodeID], node.[Left], node.[Right], (COUNT(parent.name) - 1) AS [Level]
--		FROM [Node] node, [Node] parent
--		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--		GROUP BY node.[NodeID], node.[Left], node.[Right]
--	) AS ParentLevels
--WHERE NodeLevels.[Left] BETWEEN ParentLevels.[Left] AND ParentLevels.[Right] AND
--	  NodeLevels.[NodeID] <> ParentLevels.[NodeID] AND
--	  ParentLevels.[NodeID] = @NodeID AND
--	  NodeLevels.[Level] < @Level;

--[----------------------------------------------------------------------------]
--[ 10.d. Всех терминальных потомков
--[----------------------------------------------------------------------------]
--DECLARE @NodeID INTEGER = 6;

--SELECT node.[NodeID] 
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND
--	  node.[NodeID] <> parent.[NodeID] AND
--	  parent.[NodeID] = @NodeID AND
--	  node.[Right] - node.[Left] = 1;

--[----------------------------------------------------------------------------]
--[ 11. Вычислить количество потомков данного элемента
--[----------------------------------------------------------------------------]

--DECLARE @NodeID INTEGER = 6;

--SELECT COUNT(node.[NodeID]) 
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND
--	  node.[NodeID] <> parent.[NodeID] AND
--	  parent.[NodeID] = @NodeID;

--[----------------------------------------------------------------------------]
--[ 12. Вывести список всех предков данного элемента
--[----------------------------------------------------------------------------]
--[ 12.a. Всех предков
--[----------------------------------------------------------------------------]

--DECLARE @NodeID INTEGER = 6;

--SELECT parent.[NodeID]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID AND parent.[NodeID] <> node.[NodeID];

--[----------------------------------------------------------------------------]
--[ 12.b. Предков заданного уровня (родитель, дед, прадед, ...)
--[----------------------------------------------------------------------------]

--DECLARE @NodeID INTEGER = 8;
--DECLARE @Level INTEGER = 3;

--SELECT ParentLevels.[NodeID]
--FROM 
--	(
--		SELECT node.[NodeID], node.[Left], node.[Right], (COUNT(parent.name) - 1) AS [Level]
--		FROM [Node] node, [Node] parent
--		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--		GROUP BY node.[NodeID], node.[Left], node.[Right]
--	) AS NodeLevels,
--	(
--		SELECT node.[NodeID], node.[Left], node.[Right], (COUNT(parent.name) - 1) AS [Level]
--		FROM [Node] node, [Node] parent
--		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--		GROUP BY node.[NodeID], node.[Left], node.[Right]
--	) AS ParentLevels
--WHERE NodeLevels.[Left] BETWEEN ParentLevels.[Left] AND ParentLevels.[Right] AND
--	  NodeLevels.[NodeID] <> ParentLevels.[NodeID] AND
--	  NodeLevels.[NodeID] = @NodeID AND
--	  ParentLevels.[Level] = @Level;

--[----------------------------------------------------------------------------]
--[ 12.c. Всех предков до заданного уровня 
--[----------------------------------------------------------------------------]

--DECLARE @NodeID INTEGER = 8;
--DECLARE @Level INTEGER = 3;

--SELECT ParentLevels.[NodeID]
--FROM 
--	(
--		SELECT node.[NodeID], node.[Left], node.[Right], (COUNT(parent.name) - 1) AS [Level]
--		FROM [Node] node, [Node] parent
--		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--		GROUP BY node.[NodeID], node.[Left], node.[Right]
--	) AS NodeLevels,
--	(
--		SELECT node.[NodeID], node.[Left], node.[Right], (COUNT(parent.name) - 1) AS [Level]
--		FROM [Node] node, [Node] parent
--		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right]
--		GROUP BY node.[NodeID], node.[Left], node.[Right]
--	) AS ParentLevels
--WHERE NodeLevels.[Left] BETWEEN ParentLevels.[Left] AND ParentLevels.[Right] AND
--	  NodeLevels.[NodeID] <> ParentLevels.[NodeID] AND
--	  NodeLevels.[NodeID] = @NodeID AND
--	  ParentLevels.[Level] < @Level;

--[----------------------------------------------------------------------------]
--[ 13. Вычислить количество предков данного элемента
--[----------------------------------------------------------------------------]

--DECLARE @NodeID INTEGER = 3;

--SELECT COUNT(parent.[NodeID])
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID AND parent.[NodeID] <> node.[NodeID];

--[----------------------------------------------------------------------------]
--[ 14. Вывести список всех общих предков для (двух и более) заданных элементов 
--[----------------------------------------------------------------------------]
--[ 14.a. Без условий
--[----------------------------------------------------------------------------]
--[ 14.b. Находящихся на заданном расстоянии
--[----------------------------------------------------------------------------]
--[ 14.c. Элементы расположены на одном уровне
--[----------------------------------------------------------------------------]
--[ 14.d. Элементы расположены на разных уровнях
--[----------------------------------------------------------------------------]

--DECLARE @NodeID1 INTEGER = 6;
--DECLARE @NodeID2 INTEGER = 8;

--SELECT parent.[NodeID]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID1 AND parent.[NodeID] <> node.[NodeID]
--INTERSECT
--SELECT parent.[NodeID]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID2 AND parent.[NodeID] <> node.[NodeID];

--[----------------------------------------------------------------------------]
--[ 15. Найти всех общих предков для двух и более заданных элементов
--[----------------------------------------------------------------------------]
--[ 15.a. Начиная сверху
--[----------------------------------------------------------------------------]

--DECLARE @NodeID1 INTEGER = 6;
--DECLARE @NodeID2 INTEGER = 8;

--(
--SELECT parent.[NodeID], parent.[Left]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID1 AND parent.[NodeID] <> node.[NodeID]
--INTERSECT
--SELECT parent.[NodeID], parent.[Left]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID2 AND parent.[NodeID] <> node.[NodeID]
--)
--ORDER BY parent.[Left] ASC;

--[----------------------------------------------------------------------------]
--[ 15.b. Начиная снизу
--[----------------------------------------------------------------------------]

--(
--SELECT parent.[NodeID], parent.[Left]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID1 AND parent.[NodeID] <> node.[NodeID]
--INTERSECT
--SELECT parent.[NodeID], parent.[Left]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID2 AND parent.[NodeID] <> node.[NodeID]
--)
--ORDER BY parent.[Left] DESC;

--[----------------------------------------------------------------------------]
--[ 16. Вычислить количество общих предков у двух узлов
--[----------------------------------------------------------------------------]

--DECLARE @NodeID1 INTEGER = 2;
--DECLARE @NodeID2 INTEGER = 8;

--SELECT COUNT(*) AS ParentCount
--FROM
--(
--SELECT parent.[NodeID]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID1 AND parent.[NodeID] <> node.[NodeID]
--INTERSECT
--SELECT parent.[NodeID]
--FROM [Node] AS node, [Node] AS parent
--WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
--	  node.[NodeID] = @NodeID2 AND parent.[NodeID] <> node.[NodeID]
--) AS CommonParents;

--[----------------------------------------------------------------------------]
--[ 17. Вставка узла
--[----------------------------------------------------------------------------]
--[ 19. Вставка поддерева (см. п. 17)
--[----------------------------------------------------------------------------]

--DECLARE @ParentID INTEGER = 2;
--DECLARE @NodeName VARCHAR(80) = 'Мурманская область';

--DECLARE @ParentLeft INTEGER = 0;
--DECLARE @NewNodeID INTEGER = 0;

--SELECT @NewNodeID = MAX([NodeID]) + 1 FROM [Node];
--SELECT @ParentLeft = [Left] FROM [Node] WHERE [NodeID] = @ParentID;

--UPDATE [Node] SET [Right] = [Right] + 2 WHERE [Right] > @ParentLeft;
--UPDATE [Node] SET [Left] = [Left] + 2 WHERE [Left] > @ParentLeft;

--INSERT INTO [Node] ([NodeID], [Name], [Left], [Right]) VALUES (@NewNodeID, @NodeName, @ParentLeft + 1, @ParentLeft + 2);

--[----------------------------------------------------------------------------]
--[ 18. Удаление узла
--[----------------------------------------------------------------------------]

--DECLARE @NodeID INTEGER = 4;

--DECLARE @NodeLeft INTEGER;
--DECLARE @NodeRight INTEGER;

--SELECT @NodeLeft = [Left], @NodeRight = [Right] FROM [Node] 
--	WHERE [NodeID] = @NodeID;

--DELETE FROM [Node] WHERE [NodeID] = @NodeID;

--UPDATE [Node] SET [Left] = [Left] - 1, [Right] = [Right]  - 1 
--	WHERE [Left] BETWEEN @NodeLeft AND @NodeRight;

--UPDATE [Node] SET [Right] = [Right] - 2 WHERE [Right] > @NodeRight;
--UPDATE [Node] SET [Left] = [Left] - 2 WHERE [Left] > @NodeRight;

--SELECT * FROM [Node];

--[----------------------------------------------------------------------------]
--[ 20. Удаление поддерева (удаление узла и всех его потомков)
--[----------------------------------------------------------------------------]

--DECLARE @NodeID INTEGER = 6;

--DECLARE @NodeLeft INTEGER;
--DECLARE @NodeRight INTEGER;
--DECLARE @NodeWidth INTEGER;

--SELECT @NodeLeft = [Left], @NodeRight = [Right] FROM [Node] 
--	WHERE [NodeID] = @NodeID;

--SET @NodeWidth = @NodeRight - @NodeLeft + 1;

--DELETE FROM [Node] WHERE [Left] BETWEEN @NodeLeft AND @NodeRight;

--UPDATE [Node] SET [Right] = [Right] - @NodeWidth WHERE [Right] > @NodeRight;
--UPDATE [Node] SET [Left] = [Left] - @NodeWidth WHERE [Left] > @NodeRight;

--SELECT * FROM [Node];

--[----------------------------------------------------------------------------]
--[ 21. Перемещение поддерева
--[----------------------------------------------------------------------------]

--DECLARE @SourceNodeID INTEGER = 2;
--DECLARE @DestNodeID INTEGER = 5;

--DECLARE @TempNodeID INTEGER;
--DECLARE @TempNodeLeft INTEGER;
--DECLARE @TempNodeRight INTEGER;
--DECLARE @TempNodeWidth INTEGER;

--DECLARE @InsLeft INTEGER;
--DECLARE @InsRight INTEGER;
--DECLARE @Step INTEGER;

---- Get the parameters for the sub tree to move
--SELECT @TempNodeID = [NodeID], @TempNodeLeft = [Left], @TempNodeRight = [Right]
--FROM [Node]
--WHERE [NodeID] = @SourceNodeID;

--SET @TempNodeWidth = @TempNodeRight - @TempNodeLeft + 1;

---- Get the fldLft and fldRgt value of the new parent cat
--SELECT @InsLeft = [Left], @InsRight = [Right]
--FROM [Node]
--WHERE [NodeID] = @DestNodeID;

---- Get the offset to renumber the subtree lefts and rights
--SET @Step = @InsLeft - @TempNodeLeft + 1;

---- Transfer the subtree to a temp table
--SELECT [NodeID], [Left], [Right], [Name] INTO #TempTable
--FROM [Node]
--WHERE [Node].[Left] >= @TempNodeLeft AND [Node].[Left] <= @TempNodeRight;

---- Update the temp table - renumber the lefts and rights and make the catId neg temporarily
--UPDATE #TempTable
--    SET [Left] = [Left] + @Step, 
--        [Right] = [Right] + @Step,
--        [NodeID] = -[NodeID];

---- Update the rest of the tree to the right of the move point
--UPDATE [Node] SET [Left] = [Left] + @TempNodeWidth
--    WHERE [Left] > @InsLeft;
--UPDATE [Node] SET [Right] = [Right] + @TempNodeWidth
--    WHERE [Right] > @InsLeft;

---- Insert the sub tree in the temp table 
--INSERT INTO [Node] ([NodeID], [Left], [Right], [Name])
--	SELECT [NodeID], [Left], [Right], [Name] FROM #TempTable;

---- Delete the original subtree via ID
--SELECT @TempNodeLeft = [Left], @TempNodeRight = [Right]
--FROM [Node]
--WHERE [NodeID] = @TempNodeID;

--SET @TempNodeWidth = @TempNodeRight - @TempNodeLeft + 1;

--DELETE FROM [Node]
--    WHERE [Left] BETWEEN @TempNodeLeft AND @TempNodeRight;

--UPDATE [Node] SET [Right] = [Right] - @TempNodeWidth
--    WHERE [Right] > @TempNodeRight;
--UPDATE [Node] SET [Left] = [Left] - @TempNodeWidth
--    WHERE [Left] > @TempNodeRight;

---- Reset neg. tmptId's to pos. and clean up tblcattemp
--UPDATE [Node] SET [NodeID] = -[NodeID]
--    WHERE [NodeID] < 0;

--DROP TABLE #TempTable;

--SELECT * FROM [Node];

--[----------------------------------------------------------------------------]
--[ 22. Конвертация из данного представления в модель с рекурсивным указателем
--[     и хранением пар предок - потомок
--[----------------------------------------------------------------------------]

--IF OBJECT_ID('dbo.TreeStructure', 'U') IS NOT NULL
--	DROP TABLE [TreeStructure];

--IF OBJECT_ID('dbo.ExtraNode', 'U') IS NOT NULL
--	DROP TABLE [ExtraNode];

--CREATE TABLE [ExtraNode] (
--	[NodeID] INTEGER PRIMARY KEY,
--	[ParentID] INTEGER,
--	[Name] VARCHAR(80) NOT NULL,
--	FOREIGN KEY ([ParentID]) REFERENCES [ExtraNode]([NodeID])
--);

--CREATE TABLE [TreeStructure] (
--	[NodeID] INTEGER,
--	[ParentID] INTEGER,
--	PRIMARY KEY ([NodeID], [ParentID]),
--	FOREIGN KEY ([NodeID]) REFERENCES [ExtraNode]([NodeID]),
--	FOREIGN KEY ([ParentID]) REFERENCES [ExtraNode]([NodeID])
--);

---- Copy NodeID, Name to ExtraNode table
--INSERT INTO [ExtraNode] ([NodeID], [Name])
--    SELECT [Node].[NodeID], [Node].[Name]
--        FROM [Node];

---- Find parent for each node
--UPDATE [ExtraNode]
--SET [ParentID] = 
--(
--	-- Get ParentID via [Right] 
--	SELECT T1.ParentID FROM 
--	(
--		SELECT T2.[NodeID] AS NodeID, PARENT.[NodeID] AS ParentID FROM [Node] parent,
--		(
--			SELECT node.[NodeID], MIN(parent.[Right]) AS ParentRight
--		    FROM [Node] node, [Node] parent
--		    WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND
--		          node.[NodeID] IN (SELECT [NodeID] FROM [Node]) AND
--		          node.[NodeID] <> parent.[NodeID] 
--		    GROUP BY node.[NodeID]
--		) AS T2 
--        WHERE parent.[Right] = T2.ParentRight

--	) AS T1
--	WHERE [ExtraNode].[NodeID] = T1.NodeID

--);

---- Insert other nodes - node and all his parents
--INSERT INTO [TreeStructure] ([NodeID], [ParentID])
--    SELECT node.[NodeID], parent.[NodeID]
--        FROM [Node] node, [Node] parent
--    WHERE 
--        node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND
--        node.[NodeID] IN (SELECT [NodeID] FROM [Node]) AND
--        node.[NodeID] <> parent.NodeId;

---- Insert root
--INSERT INTO [TreeStructure] ([NodeID], [ParentID]) 
--    SELECT [NodeID], [NodeID]
--        FROM [ExtraNode]
--    WHERE [ParentID] IS NULL;

--SELECT * FROM [ExtraNode]
--SELECT * FROM [TreeStructure];

--[----------------------------------------------------------------------------]