--CREATE DATABASE Lab5;

USE Lab5;

CREATE TABLE [Graph] (
	[TreeID] INTEGER,
	[NodeID] INTEGER,
	PRIMARY KEY ([TreeID], [NodeID]),
	[Left] INTEGER NOT NULL,
	[Right] INTEGER NOT NULL,
	[Name] VARCHAR(80) NOT NULL
);

INSERT INTO [Graph] ([TreeID], [NodeID], [Left], [Right], [Name]) VALUES
    (1, 1, 0, 7, 'Router1'),
    (1, 2, 1, 4, 'Switch1'),
    (1, 3, 5, 6, 'Router2'),
	(1, 4, 2, 3, 'PC1'),
    (2, 3, 0, 5, 'Router2'),
    (2, 2, 1, 4, 'Switch1'),
    (2, 5, 2, 3, 'PC2');

--[----------------------------------------------------------------------------]
--[ 1. Добавление вершины
--[----------------------------------------------------------------------------]

GO
CREATE PROCEDURE AddNode (@Name NVARCHAR(80)) AS
BEGIN
	DECLARE @NodeID INTEGER;
	DECLARE @TreeID INTEGER;

	SELECT @NodeID = MAX([NodeID]) + 1 FROM [Graph];
	SELECT @TreeID = MAX([TreeID]) + 1 FROM [Graph];

	INSERT INTO [Graph] VALUES (@TreeID, @NodeID, 0, 1, @Name);
END;

--[----------------------------------------------------------------------------]
--[ 2. Удаление вершины
--[----------------------------------------------------------------------------]

GO
CREATE PROCEDURE RemoveNode (@NodeID INTEGER) AS
BEGIN
	-- Find trees that have deleting node
	SELECT [TreeID] INTO #NodeTrees
	FROM [Graph]
	WHERE [NodeID] = @NodeID;

	DECLARE @i INTEGER = 1;
	DECLARE @TreeCount INTEGER;

	SELECT @TreeCount = COUNT(*) FROM #NodeTrees;

	WHILE @i <= @TreeCount
	BEGIN
		DECLARE @TreeID INTEGER;

		SELECT @TreeID = [TreeID] FROM 
		(
			SELECT ROW_NUMBER() OVER(ORDER BY [TreeID]) AS RowNumber, [TreeID]
			FROM #NodeTrees
		) AS TreeNodeNumbers
		WHERE RowNumber = @i;

		DECLARE @NodeLeft INTEGER;
		DECLARE @NodeRight INTEGER;

		SELECT @NodeLeft = [Left], @NodeRight = [Right] FROM [Graph] 
			WHERE [NodeID] = @NodeID AND [TreeID] = @TreeID;

		DELETE FROM [Graph] WHERE [NodeID] = @NodeID AND [TreeID] = @TreeID;

		UPDATE [Graph] SET [Left] = [Left] - 1, [Right] = [Right]  - 1 
			WHERE [Left] BETWEEN @NodeLeft AND @NodeRight AND [TreeID] = @TreeID;

		UPDATE [Graph] SET [Right] = [Right] - 2 
			WHERE [Right] > @NodeRight AND [TreeID] = @TreeID;

		UPDATE [Graph] SET [Left] = [Left] - 2 
			WHERE [Left] > @NodeRight AND [TreeID] = @TreeID;

		SET @i = @i + 1;
	END;

	DROP TABLE #NodeTrees;
END;

--[----------------------------------------------------------------------------]
--[ 3. Добавление дуги
--[----------------------------------------------------------------------------]

GO
CREATE PROCEDURE DeleteUnwantedTrees (@NewTreeID INTEGER, @NodeChildID INTEGER) AS
BEGIN

	DECLARE @Counter INTEGER;
	DECLARE @TreeId_for_delete INTEGER;

	SELECT @Counter = COUNT([TreeID])
	FROM [Graph]
    WHERE [NodeID] = @NodeChildID;
    
    -- minus just inserted TreeID    
    IF @Counter - 1 = 1
    BEGIN
        SELECT @TreeId_for_delete = [TreeID]
		FROM [Graph]
        WHERE [NodeId] = @NodeChildID AND [TreeID] <> @NewTreeID; 
    
        SELECT @Counter = COUNT([NodeID])
		FROM Graph
        WHERE [TreeID] = @TreeId_for_delete;
        
        IF @Counter = 1
        BEGIN
            DELETE FROM [Graph] 
            WHERE [NodeID] = @NodeChildID AND [TreeID] = @TreeId_for_delete;
        END;
    END;
END;

GO
CREATE PROCEDURE InsertNodeHowChild (@WhereWillInsertTreeId INTEGER, @ParentNodeID INTEGER, @ChildNodeID INTEGER, @ChildName VARCHAR(80)) AS
BEGIN
	DECLARE @NodeLeft INTEGER;

    SELECT @NodeLeft = [Left]
	FROM [Graph]
    WHERE [NodeID] = @ParentNodeID AND [TreeID] = @WhereWillInsertTreeId;

    UPDATE [Graph] SET [Right] = [Right] + 2
        WHERE [Right] > @NodeLeft AND [TreeID] = @WhereWillInsertTreeId;
    UPDATE [Graph] SET [Left] = [Left] + 2
        WHERE [Left] > @NodeLeft AND [TreeID] = @WhereWillInsertTreeId;

    INSERT INTO [Graph] ([TreeID], [NodeID], [Left], [Right], [Name])
        VALUES(@WhereWillInsertTreeId, @ChildNodeId, @NodeLeft + 1, @NodeLeft + 2, @ChildName);
        
    EXECUTE DeleteUnwantedTrees @WhereWillInsertTreeId, @ChildNodeID;
END;

GO
CREATE PROCEDURE AddArchFromParentToChild (@ParentNodeID INTEGER, @ChildNodeID INTEGER) AS
BEGIN
	
	DECLARE @var_TreeId_parent INTEGER;
    DECLARE @var_Name_parent VARCHAR(80);
    DECLARE @var_Name_child VARCHAR(80);
    DECLARE @var_TreeId_new INTEGER;

	SELECT DISTINCT @var_Name_parent = [Name]
	FROM [Graph]
    WHERE [NodeID] = @ParentNodeID;
    
    SELECT DISTINCT @var_Name_child = [Name]
	FROM [Graph]
    WHERE [NodeID] = @ChildNodeID;
    
    -- Get TreeId where will be insert NodeIdChild
    SELECT @var_TreeId_parent = parent.[TreeID]
	FROM [Graph] parent
    WHERE parent.[NodeID] = @ParentNodeID AND
		  parent.[TreeID] NOT IN (SELECT [TreeID] FROM Graph WHERE [NodeID] = @ChildNodeID);

    IF @var_TreeId_parent <> 0
    BEGIN
        -- Leftward of the children NodeIdParent
        EXECUTE InsertNodeHowChild @var_TreeId_parent, @ParentNodeID, @ChildNodeID, @var_Name_child;
    END
	ELSE
	BEGIN
		SELECT @var_TreeId_new = MAX([TreeID]) + 1 FROM [Graph];
        
        INSERT INTO [Graph] ([TreeID], [NodeID], [Left], [Right], [Name]) 
			VALUES (@var_TreeId_new, @ParentNodeID, 0, 1, @var_Name_parent);
        
		EXECUTE InsertNodeHowChild @var_TreeId_new, @ParentNodeID, @ChildNodeID, @var_Name_child;
	END;
END;

--[----------------------------------------------------------------------------]
--[ 4. Удаление дуги
--[----------------------------------------------------------------------------]

GO
CREATE PROCEDURE DeleteArch (@ParentNodeID INTEGER, @ChildNodeID INTEGER) AS
BEGIN
	DECLARE @ParentChildTreeID INTEGER;

	SELECT @ParentChildTreeID = [TreeID] FROM
	(
		SELECT [TreeID] FROM [Graph] WHERE [NodeID] = @ParentNodeID
		INTERSECT
		SELECT [TreeID] FROM [Graph] WHERE [NodeID] = @ChildNodeID
	) AS SubTreeNodes;

	DECLARE @NewTreeRootNodeLeft INTEGER;
	DECLARE @NewTreeRootNodeRight INTEGER;

	-- Get New tree root Left and Right by ID
	SELECT @NewTreeRootNodeLeft = [Left], @NewTreeRootNodeRight = [Right] 
	FROM [Graph]
	WHERE [NodeID] = @ChildNodeID AND [TreeID] = @ParentChildTreeID;

	-- Get new tree nodes
	SELECT [NodeID] INTO #NewTreeNodes
	FROM [Graph] 
	WHERE [Left] BETWEEN @NewTreeRootNodeLeft AND @NewTreeRootNodeRight AND
		  [TreeID] = @ParentChildTreeID;

	DECLARE @NewTreeID INTEGER;

	SELECT @NewTreeID = MAX([TreeID]) + 1 FROM [Graph];

	DECLARE @NodeSubtreeCount INTEGER;

	SELECT @NodeSubtreeCount = COUNT(*) FROM #NewTreeNodes;

	DECLARE @NodeLeft INTEGER;
	DECLARE @NodeRight INTEGER;
	DECLARE @NodeWidth INTEGER;

	SELECT @NodeLeft = [Left] FROM [Graph] 
	WHERE [NodeID] = @ChildNodeID;

	SELECT @NodeWidth = [Right] - [Left] + 1,
		   @NodeLeft = [Left],
		   @NodeRight = [Right]
	FROM [Graph] 
	WHERE [NodeID] = @ChildNodeID AND [TreeID] = @ParentChildTreeID;

	-- set new subtree
	UPDATE [Graph]
	SET [TreeID] = @NewTreeID,
		[Left] = [Left] - @NodeLeft,
		[Right] = [Right] - @NodeLeft 
	WHERE [Left] BETWEEN @NewTreeRootNodeLeft AND @NewTreeRootNodeRight AND
		  [TreeID] = @ParentChildTreeID;

	-- update Left, Right for old tree
	UPDATE [Graph] SET [Right] = [Right] - @NodeWidth 
		WHERE [Right] > @NodeRight AND [TreeID] = @ParentChildTreeID;
	UPDATE [Graph] SET [Left] = [Left] - @NodeWidth 
		WHERE [Left] > @NodeRight AND [TreeID] = @ParentChildTreeID;
END;

--[----------------------------------------------------------------------------]
--[ 5. Определить смежность вершин
--[----------------------------------------------------------------------------]

GO
CREATE PROCEDURE AreAdjacent (@NodeID1 INTEGER, @NodeID2 INTEGER) AS
BEGIN
	SELECT CONVERT(BIT, node.[NodeID]) AS IsAdjacency
	FROM [Graph] AS node, [Graph] AS parent
	WHERE (node.[Left] - parent.[Left] = 1 OR parent.[Right] - node.[Right] = 1) AND 
		  (node.[NodeID] = @NodeID1 AND parent.[NodeID] = @NodeID2 OR 
		  parent.[NodeID] = @NodeID1 AND node.[NodeID] = @NodeID2) AND
		  node.[TreeID] = parent.[TreeID];
END;

--[----------------------------------------------------------------------------]
--[ 6. Определить инцидентность узла к ребру
--[----------------------------------------------------------------------------]
GO
CREATE FUNCTION NodeIncidentToEdge (@NodeID INTEGER, @EdgeNodeID1 INTEGER, @EdgeNodeID2 INTEGER)
RETURNS INTEGER
BEGIN
	IF @NodeID = @EdgeNodeID1 OR @NodeID = @EdgeNodeID2
		RETURN 1;

	RETURN 0;
END;

--[----------------------------------------------------------------------------]
--[ 7. Найти путь между двумя вершинами
--[----------------------------------------------------------------------------]
GO
CREATE PROCEDURE FindPath (@NodeID1 INTEGER, @NodeID2 INTEGER) AS
BEGIN

	-- Search common trees for Node 1 and Node 2
	SELECT [TreeID] INTO #CommonTreesID FROM
	(
		SELECT [TreeID] FROM [Graph] WHERE [NodeID] = @NodeID1
		INTERSECT
		SELECT [TreeID] FROM [Graph] WHERE [NodeID] = @NodeID2
	) AS CommonTrees;

	-- Select count of common trees
	DECLARE @CommonTreeCount INTEGER;
	SELECT @CommonTreeCount = COUNT(*) FROM #CommonTreesID;

	IF @CommonTreeCount <> 0
	BEGIN 
		-- If Node 1 and Node 2 are contained in the same tree
		DECLARE @CommonTreeID INTEGER;
		SELECT @CommonTreeID = [TreeID] FROM #CommonTreesID;

		-- Find the way from parent to Node 1
		SELECT parent.[NodeID], parent.[Left] INTO #NodePath1
		FROM [Graph] AS node, [Graph] AS parent
		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
			  node.[TreeID] = @CommonTreeID AND
			  parent.[TreeID] = @CommonTreeID AND
			  node.[NodeID] = @NodeID1
		GROUP BY parent.[NodeID], parent.[Left]
		ORDER BY parent.[NodeID], parent.[Left];

		-- Find the way from parent to Node 2
		SELECT parent.[NodeID], parent.[Left] INTO #NodePath2
		FROM [Graph] AS node, [Graph] AS parent
		WHERE node.[Left] BETWEEN parent.[Left] AND parent.[Right] AND 
			  node.[TreeID] = @CommonTreeID AND
			  parent.[TreeID] = @CommonTreeID AND
			  node.[NodeID] = @NodeID2
		GROUP BY parent.[NodeID], parent.[Left]
		ORDER BY parent.[NodeID], parent.[Left];

		SELECT T1.[NodeID], T1.[Left] INTO #MatchedEntries 
		FROM #NodePath1 T1, #NodePath2 T2
		WHERE T1.NodeID = T2.NodeID
		ORDER BY T1.NodeID;

		DECLARE @MaxLeft INTEGER;
		SELECT @MaxLeft = MAX([Left]) FROM #MatchedEntries;

		(
			SELECT [NodeID] FROM #NodePath1
			UNION
			SELECT [NodeID] FROM #NodePath2
		)
		EXCEPT 
		SELECT [NodeID] FROM #MatchedEntries
		UNION
		SELECT [NodeID] FROM #MatchedEntries WHERE [Left] = @MaxLeft;

		DROP TABLE #NodePath1;
		DROP TABLE #NodePath2;
		DROP TABLE #MatchedEntries;
	END;
	ELSE
	BEGIN
		-- If Node 1 and Node 2 are contained in different trees

		DECLARE @LinkerNodeID INTEGER;

		-- Find the node that contained in two trees
		SELECT @LinkerNodeID = [NodeID] FROM
		(
			SELECT [NodeID] FROM [Graph] 
			WHERE [TreeID] = (SELECT [TreeID] FROM Graph WHERE [NodeID] = @NodeID1)
			INTERSECT 
			SELECT [NodeID] FROM [Graph] 
			WHERE [TreeID] = (SELECT [TreeID] FROM Graph WHERE [NodeID] = @NodeID2)
		) AS LinkNodes;

		-- Find path for (Node1, LinkerNode)
		DECLARE @Path1 TABLE ([NodeID] INTEGER);
		INSERT @Path1
		EXECUTE FindPath @NodeID1, @LinkerNodeID;

		-- Find path for (Node2, LinkerNode)
		DECLARE @Path2 TABLE ([NodeID] INTEGER);
		INSERT @Path2
		EXECUTE FindPath @NodeID2, @LinkerNodeID;

		-- Union two paths
		SELECT * FROM 
		(
			SELECT * FROM @Path1
			UNION
			SELECT * FROM @Path2
		) AS UnionPaths;
	END; 

	DROP TABLE #CommonTreesID;

	RETURN;
END;

--[----------------------------------------------------------------------------]
--[ 8. Найти подграф, обладающий заданными свойствами (или опорное дерево)
--[    Заданное свойство: количество листьев в дереве
--[----------------------------------------------------------------------------]
GO
CREATE PROCEDURE FindSubtree (@LeafCount INTEGER) AS
BEGIN
	SELECT [TreeID], COUNT(*) AS [LeafCount] INTO #LeafsTreeCount
	FROM [Graph]
	WHERE [Right] - [Left] = 1
	GROUP BY [TreeID];

	DECLARE @AppropriatedTreeID INTEGER;

	SELECT @AppropriatedTreeID = [TreeID]
	FROM #LeafsTreeCount
	WHERE [LeafCount] = @LeafCount;

	SELECT [NodeID]
	FROM [Graph]
	WHERE [TreeID] = @AppropriatedTreeID;

	DROP TABLE #LeafsTreeCount;
END;

--[----------------------------------------------------------------------------]
--[ 10. Выделить вершины с только входными дугами
--[----------------------------------------------------------------------------]

GO
CREATE FUNCTION GetInputNodes()
    RETURNS TABLE AS
    RETURN
		SELECT [NodeID] FROM [Graph]
		WHERE [Right] - [Left] = 1 AND [Left] <> 0
		EXCEPT
		SELECT [NodeID] FROM [Graph]
		WHERE [Right] - [Left] <> 1;

--[----------------------------------------------------------------------------]
--[ 11. Удалить вершины с только входными дугами
--[----------------------------------------------------------------------------]

GO
CREATE PROCEDURE DeleteInputNodes AS
BEGIN
	DECLARE @NodeIter INTEGER = 1;
	DECLARE @NodeCount INTEGER;

	SELECT @NodeCount = COUNT(*) FROM GetInputNodes();

	WHILE @NodeIter <= @NodeCount
	BEGIN
		DECLARE @NodeID INTEGER;

		-- Select NodeID from #InputNodes by @NodeIter
		SELECT @NodeID = [NodeID] FROM 
		(
			SELECT ROW_NUMBER() OVER(ORDER BY [NodeID]) AS RowNumber, [NodeID]
			FROM GetInputNodes()
		) AS NodeNumbers
		WHERE RowNumber = @NodeIter;

		-- Find trees that have deleting node (NodeID)
		SELECT [TreeID] INTO #NodeTrees
		FROM [Graph]
		WHERE [NodeID] = @NodeID;

		DECLARE @TreeIter INTEGER = 1;
		DECLARE @TreeCount INTEGER;

		SELECT @TreeCount = COUNT(*) FROM #NodeTrees;

		-- Delete node from each tree
		WHILE @TreeIter <= @TreeCount
		BEGIN
			DECLARE @TreeID INTEGER;

			SELECT @TreeID = [TreeID] FROM 
			(
				SELECT ROW_NUMBER() OVER(ORDER BY [TreeID]) AS RowNumber, [TreeID]
				FROM #NodeTrees
			) AS TreeNodeNumbers
			WHERE RowNumber = @TreeIter;

			DECLARE @NodeLeft INTEGER;
			DECLARE @NodeRight INTEGER;

			SELECT @NodeLeft = [Left], @NodeRight = [Right] FROM [Graph] 
				WHERE [NodeID] = @NodeID AND [TreeID] = @TreeID;

			DELETE FROM [Graph] WHERE [NodeID] = @NodeID AND [TreeID] = @TreeID;

			UPDATE [Graph] SET [Left] = [Left] - 1, [Right] = [Right] - 1 
				WHERE [Left] BETWEEN @NodeLeft AND @NodeRight AND [TreeID] = @TreeID;

			UPDATE [Graph] SET [Right] = [Right] - 2 
				WHERE [Right] > @NodeRight AND [TreeID] = @TreeID;

			UPDATE [Graph] SET [Left] = [Left] - 2 
				WHERE [Left] > @NodeRight AND [TreeID] = @TreeID;

			SET @TreeIter = @TreeIter + 1;
		END;

		DROP TABLE #NodeTrees;
		SET @NodeIter = @NodeIter + 1;
	END;
END;

--[----------------------------------------------------------------------------]
--[ 12. Выделить вершины с только выходными дугами
--[----------------------------------------------------------------------------]

GO
CREATE FUNCTION GetOutputNodes()
    RETURNS TABLE AS
    RETURN
        SELECT [NodeID] FROM [Graph]
		WHERE [Left] = 0 AND [Right] - [Left] <> 1
		EXCEPT
		SELECT [NodeID] FROM [Graph]
		WHERE [Left] <> 0;

--[----------------------------------------------------------------------------]
--[ 13. Удалить вершины с только выходными дугами
--[----------------------------------------------------------------------------]

GO
CREATE PROCEDURE DeleteOutputNodes AS
BEGIN
	DECLARE @NodeIter INTEGER = 1;
	DECLARE @NodeCount INTEGER;

	SELECT @NodeCount = COUNT(*) FROM GetOutputNodes();

	WHILE @NodeIter <= @NodeCount
	BEGIN
		DECLARE @NodeID INTEGER;

		-- Select NodeID from #OutputNodes by @NodeIter
		SELECT @NodeID = [NodeID] FROM 
		(
			SELECT ROW_NUMBER() OVER(ORDER BY [NodeID]) AS RowNumber, [NodeID]
			FROM GetOutputNodes()
		) AS NodeNumbers
		WHERE RowNumber = @NodeIter;

		-- Find trees that have deleting node (NodeID)
		SELECT [TreeID] INTO #NodeTrees
		FROM [Graph]
		WHERE [NodeID] = @NodeID;

		DECLARE @TreeIter INTEGER = 1;
		DECLARE @TreeCount INTEGER;

		SELECT @TreeCount = COUNT(*) FROM #NodeTrees;

		-- Delete node from each tree
		WHILE @TreeIter <= @TreeCount
		BEGIN
			DECLARE @TreeID INTEGER;

			SELECT @TreeID = [TreeID] FROM 
			(
				SELECT ROW_NUMBER() OVER(ORDER BY [TreeID]) AS RowNumber, [TreeID]
				FROM #NodeTrees
			) AS TreeNodeNumbers
			WHERE RowNumber = @TreeIter;

			DECLARE @NodeLeft INTEGER;
			DECLARE @NodeRight INTEGER;
			DECLARE @NewRootNodeID INTEGER;

			-- Select new root NodeID
			SELECT @NewRootNodeID = [NodeID], @NodeLeft = [Left], @NodeRight = [Right]
				FROM [Graph] 
				WHERE [Left] = 1 AND [TreeID] = @TreeID;

			-- Delete old root
			DELETE FROM [Graph] WHERE [NodeID] = @NodeID AND [TreeID] = @TreeID;

			-- Update Left, Right for new root children
			UPDATE [Graph] SET [Left] = [Left] - 1, [Right] = [Right] - 1 
				WHERE [Left] BETWEEN @NodeLeft AND @NodeRight AND [TreeID] = @TreeID;

			-- Update Left, Right for all others
			UPDATE [Graph] SET [Right] = [Right] - 2 
				WHERE [Right] > @NodeRight AND [TreeID] = @TreeID;
			UPDATE [Graph] SET [Left] = [Left] - 2 
				WHERE [Left] > @NodeRight AND [TreeID] = @TreeID;

			-- Set new root
			UPDATE [Graph] SET [Left] = @NodeLeft - 1, [Right] = @NodeRight + 1 
				WHERE [NodeID] = @NewRootNodeID AND [TreeID] = @TreeID;

			SET @TreeIter = @TreeIter + 1;
		END;

		DROP TABLE #NodeTrees;
		SET @NodeIter = @NodeIter + 1;
	END;
END;

--[----------------------------------------------------------------------------]
--[ 9. Определить наличие циклов в графе и найти их
--[----------------------------------------------------------------------------]

GO
CREATE FUNCTION GetCycle()
RETURNS @CycleNodeIDs TABLE(NodeID INTEGER) AS
BEGIN
	DECLARE @GraphChanged INTEGER = 1;

	DECLARE @NodeCountOld INTEGER = 0;
	DECLARE @NodeCountCurrent INTEGER = 0;

	SELECT @NodeCountCurrent = COUNT(*) FROM [Graph];

	WHILE @NodeCountOld <> @NodeCountCurrent
	BEGIN

		EXECUTE DeleteInputNodes;
		SET @NodeCountOld = @NodeCountCurrent;
		SELECT @NodeCountCurrent = COUNT(*) FROM [Graph];
	END;

	IF @NodeCountCurrent = 1
		INSERT INTO @CycleNodeIDs SELECT 1;
	ELSE
		INSERT INTO @CycleNodeIDs SELECT DISTINCT [NodeID] FROM [Graph];

	RETURN;
END;

--[----------------------------------------------------------------------------]
--[ Тестирование
--[----------------------------------------------------------------------------]
GO

-- SELECT * FROM GetOutputNodes();
-- SELECT * FROM GetInputNodes();

--EXECUTE DeleteOutputNodes;
--EXECUTE DeleteInputNodes;

-- EXECUTE FindPath 1, 5;

--EXECUTE AddArchFromParentToChild 4, 5; 

--EXECUTE FindSubtree 1;

--EXECUTE DeleteArch 2, 4;
--SELECT * FROM [Graph];

--[----------------------------------------------------------------------------]
--[ Удаление 
--[----------------------------------------------------------------------------]

DROP PROCEDURE	AddNode;
DROP PROCEDURE	RemoveNode;
DROP PROCEDURE	AreAdjacent;
DROP FUNCTION	NodeIncidentToEdge;
DROP PROCEDURE	FindPath
DROP FUNCTION	GetCycle;
DROP PROCEDURE	DeleteInputNodes;
DROP FUNCTION	GetInputNodes;
DROP PROCEDURE	DeleteOutputNodes;
DROP FUNCTION	GetOutputNodes;
DROP PROCEDURE	FindSubtree;
DROP PROCEDURE	AddArchFromParentToChild;
DROP PROCEDURE	InsertNodeHowChild;
DROP PROCEDURE	DeleteUnwantedTrees;
DROP PROCEDURE  DeleteArch;

DROP TABLE		[Graph];

--[----------------------------------------------------------------------------]