-- Oracle DB (Oracle Linux Server)
-- Operations on graph on nested set

DROP TABLE Graph PURGE;


CREATE TABLE Graph (
    TreeId INT NOT NULL,
    NodeId INT NOT NULL,
    lft    INT NOT NULL,
    rgt    INT NOT NULL,
    Name VARCHAR(20) NOT NULL,

    CONSTRAINT chk_lft     CHECK (lft > -1),
    CONSTRAINT chk_rgt     CHECK (rgt > -1),
    CONSTRAINT chk_lft_grt CHECK (lft < rgt),

    PRIMARY KEY (TreeId, NodeId)
);


CREATE OR REPLACE PROCEDURE ins_Graph
    (tmp_treeid IN INT, tmp_id IN INT, tmp_lft IN INT, tmp_rgt IN INT, tmp_name IN CHAR)
    IS
    BEGIN
        INSERT INTO Graph (TreeId, NodeId, lft, rgt, Name) VALUES (tmp_treeid, tmp_id, tmp_lft, tmp_rgt, tmp_name);
    END;
/


BEGIN
    ins_Graph (1, 1, 0, 9, 'SPB');
    ins_Graph (1, 2, 1, 6, 'MSC');
    ins_Graph (1, 3, 2, 3, 'SAM');
    ins_Graph (1, 4, 4, 5, 'KZN');
    ins_Graph (1, 5, 7, 8, 'UFA');

    ins_Graph (2, 5, 0, 3, 'UFA');
    ins_Graph (2, 2, 1, 2, 'MSC');
END;
/

-- Проверить нет ли деревьев, у которых один узел, но этот узел уже есть в другом дереве,
-- тогда нужно удалить дерево с одиночным элементом
CREATE OR REPLACE PROCEDURE CheckForRedundantTrees
IS
    counter INT;
    cur_treeid INT;
    NeededNodeId INT;
BEGIN
    
    FOR C IN
    (
    -- Get TreeId where COUNT(NodeId) = 1
    SELECT TreeId 
    INTO cur_treeid
        FROM
        (SELECT Graph.TreeId, COUNT(NodeId)
            FROM Graph
        GROUP BY Graph.TreeId
        HAVING COUNT(Graph.NodeId) = 1)
    )
    LOOP
    
        cur_treeid := C.TreeId;
        
        dbms_output.put_line('TreeId, where COUNT(NodeId) = 1: ' || cur_treeid);
    
        -- Get NodeId this Tree    
        SELECT NodeId
        INTO NeededNodeId
            FROM Graph
        WHERE TreeId = cur_treeid;
        
        dbms_output.put_line('(NodeId): ' || NeededNodeId);
        
        SELECT COUNT(Graph.TreeId)
        INTO counter
            FROM Graph
        WHERE Graph.NodeId = NeededNodeId;
        
        --dbms_output.put_line('Counter: ' || counter);
        
        IF counter >= 2
        THEN
            DELETE
                FROM Graph 
            WHERE
            Graph.NodeId = NeededNodeId
            AND
            Graph.TreeId = cur_treeid;
        END IF;
        
    END LOOP;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- exception handling logic goes here
            dbms_output.put_line('CheckForRedundantTrees empty');
END;
/


----------------------------------------------------------------------------------
PROMPT 1. Добавление вершины
----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE AddNodeToGraph (tmp_name IN CHAR)
    IS
    BEGIN
        INSERT INTO Graph (TreeId, NodeId, lft, rgt, Name)
            VALUES (
                    (SELECT MAX(TreeId) + 1 FROM Graph),
                    (SELECT MAX(NodeId) + 1 FROM Graph),
                    0, 1, tmp_name);
    END;
/

--/*
PROMPT ADD EKB;
BEGIN
    AddNodeToGraph('EKB');
END;
/
--*/
SELECT * FROM Graph;


----------------------------------------------------------------------------------
PROMPT 2. Удаление вершины
----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DeleteNode (NodeIdForDeletion IN INT)
IS
    var_i         INT;
    var_TreeCount INT;
    var_TreeId    INT;
    
    var_NodeLeft  INT;
    var_NodeRight INT;
BEGIN
    var_i := 1;

    SELECT COUNT(*)
    INTO var_TreeCount
        FROM ( -- Find trees that have deleting node
            SELECT Graph.TreeId
                FROM Graph
            WHERE Graph.NodeId = NodeIdForDeletion
        );

    --dbms_output.put_line('var_TreeCount: ' || var_TreeCount);

    WHILE var_i <= var_TreeCount
    LOOP
        SELECT TreeId
        INTO var_TreeId
            FROM (-- NodeTrees
                    SELECT Graph.TreeId
                        FROM Graph
                    WHERE Graph.NodeId = NodeIdForDeletion
            )
        WHERE ROWNUM = 1;

        --dbms_output.put_line('var_TreeId: ' || var_TreeId);

        SELECT lft, rgt 
        INTO var_NodeLeft, var_NodeRight
            FROM Graph
        WHERE NodeId = NodeIdForDeletion AND TreeId = var_TreeId;

        DELETE FROM Graph WHERE NodeId = NodeIdForDeletion AND TreeId = var_TreeId;

        --dbms_output.put_line(NodeIdForDeletion || ' ' || var_TreeId || ' ' || var_NodeLeft || ' ' || var_NodeRight);

        UPDATE Graph SET lft = lft - 1, rgt = rgt - 1
            WHERE
                lft BETWEEN var_NodeLeft AND var_NodeRight 
                AND
                TreeId = var_TreeId;

        --dbms_output.put_line('updete 1');

        UPDATE Graph SET lft = lft - 2
            WHERE lft > var_NodeRight AND TreeId = var_TreeId;
        
        --dbms_output.put_line('updete 2');
            
        UPDATE Graph SET rgt = rgt - 2
            WHERE rgt > var_NodeRight AND TreeId = var_TreeId;

        --dbms_output.put_line('updete 3');

        var_i := var_i + 1;
    END LOOP;
    
    CheckForRedundantTrees;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- exception handling logic goes here
            dbms_output.put_line('DeleteNode error');
END;
/

/*
PROMPT DELETE UFA;
BEGIN
    DeleteNode(5); -- UFA
END;
/
--*/
SELECT * FROM Graph;


----------------------------------------------------------------------------------
PROMPT 3. Добавление дуги
----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE InsertNodeHowChild (WhereWillInsertTreeId IN INT, ParentNodeId IN INT, ChildNodeId IN INT, ChildName IN CHAR)
IS
    myLeft  INT := 0;
BEGIN
    SELECT Graph.lft
    INTO myLeft
        FROM Graph
    WHERE 
        Graph.NodeId = ParentNodeId
        AND 
        Graph.TreeId = WhereWillInsertTreeId;

    UPDATE Graph SET Graph.rgt = Graph.rgt + 2
        WHERE Graph.rgt > myLeft AND Graph.TreeId = WhereWillInsertTreeId;
    UPDATE Graph SET Graph.lft = Graph.lft + 2
        WHERE Graph.lft > myLeft AND Graph.TreeId = WhereWillInsertTreeId;

    INSERT INTO Graph (TreeId, NodeId, lft, rgt, Name)
        VALUES(WhereWillInsertTreeId, ChildNodeId, myLeft + 1, myLeft + 2, ChildName);
        
    --DeleteUnwantedTrees(WhereWillInsertTreeId, ChildNodeId);
    CheckForRedundantTrees;
END;
/

CREATE OR REPLACE PROCEDURE AddArchFromParentToChild (NodeIdParent IN INT, NodeIdChild IN INT)
IS
    var_TreeId_parent INT;
    var_Name_parent VARCHAR(20);
    var_Name_child VARCHAR(20);
    var_TreeId_new INT;
BEGIN
    
    SELECT DISTINCT Graph.Name
    INTO var_Name_parent
        FROM Graph
    WHERE Graph.NodeId = NodeIdParent;
    
    SELECT DISTINCT Graph.Name
    INTO var_Name_child
        FROM Graph
    WHERE Graph.NodeId = NodeIdChild;
    
    var_TreeId_parent := 0;
    -- Get TreeId where will be insert NodeIdChild
    SELECT MIN(PARENT.TreeId)
    INTO var_TreeId_parent
        FROM Graph PARENT
    WHERE
        PARENT.NodeId = NodeIdParent
        AND
        PARENT.Treeid NOT IN (
            SELECT TreeId
                FROM Graph
            WHERE Graph.NodeId = NodeIdChild);

    IF var_TreeId_parent <> 0
    THEN
        -- Leftward of the children NodeIdParent
        InsertNodeHowChild(var_TreeId_parent, NodeIdParent, NodeIdChild, var_Name_child);
    --END IF;
    
    ELSE
    
    --EXCEPTION
        --WHEN no_data_found THEN
        -- Your query returned no rows --
        dbms_output.put_line('Error. Not found node.');
        dbms_output.put_line(var_TreeId_parent);
        
        SELECT MAX(TreeId) + 1 
        INTO var_TreeId_new
            FROM Graph;
        
        INSERT INTO Graph (TreeId, NodeId, lft, rgt, Name) VALUES (var_TreeId_new, NodeIdParent, 0, 1, var_Name_parent);
        InsertNodeHowChild(var_TreeId_new, NodeIdParent, NodeIdChild, var_Name_child);
        --INSERT INTO Graph (TreeId, NodeId, lft, rgt, Name) VALUES (var_TreeId_new, NodeIdParent, 1, 2, var_Name_parent);
    END IF;
END;
/

/*
PROMPT SPB -> KZN;
BEGIN
    AddArchFromParentToChild(1, 4);
END;
/
SELECT * FROM Graph;
--*/
/*
PROMPT KZN -> UFA;
BEGIN
    AddArchFromParentToChild(4, 5);
END;
/
SELECT * FROM Graph;
--*/
/*
PROMPT UFA -> EKB;
BEGIN
    AddArchFromParentToChild(5, 6);
END;
/
--*/
SELECT * FROM Graph;

/*
SELECT * FROM Graph;
BEGIN
    CheckForRedundantTrees;
END;
/
SELECT * FROM Graph;
--*/


----------------------------------------------------------------------------------
PROMPT 4. Удаление дуги
----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DeleteArchFromParentToChild (var_ParentNodeID IN INT, var_ChildNodeID IN INT)
IS
    -- Paramms 
    var_ParentChildTreeID INT;
    
    var_NewTreeRootNodeLeft INT;
    var_NewTreeRootNodeRight INT;
    
    var_NewTreeID INT;
    
    var_NodeSubtreeCount INT;
    
    var_NodeLeft INT;
    var_NodeRight INT;
    var_NodeWidth INT;
BEGIN
    SELECT TreeId
    INTO var_ParentChildTreeID
    FROM
    (
        SELECT TreeId FROM Graph WHERE NodeId = var_ParentNodeID
        INTERSECT
        SELECT TreeId FROM Graph WHERE NodeId = var_ChildNodeID
    )
    WHERE ROWNUM = 1;
    
    --dbms_output.put_line('1');

    -- Get New tree root Left and Right by ID
    SELECT lft, rgt 
    INTO var_NewTreeRootNodeLeft, var_NewTreeRootNodeRight
    FROM Graph
    WHERE NodeId = var_ChildNodeID AND TreeId = var_ParentChildTreeID;
    
    SELECT MAX(TreeId) + 1 
    INTO var_NewTreeID
        FROM Graph;
    
    --dbms_output.put_line('2');
    --dbms_output.put_line('var_NewTreeID');
    
    SELECT COUNT(*)
    INTO var_NodeSubtreeCount
        FROM ( -- -- Get new tree nodes
            SELECT NodeId 
                FROM Graph
            WHERE lft BETWEEN var_NewTreeRootNodeLeft AND var_NewTreeRootNodeRight AND
            TreeId = var_ParentChildTreeId
        );
    
    --dbms_output.put_line('3');
     
    SELECT lft 
    INTO var_NodeLeft
    FROM Graph
    WHERE NodeId = var_ChildNodeID AND TreeId = var_ParentChildTreeID;
    
    --dbms_output.put_line('4');
    
    SELECT lft, rgt
    INTO var_NodeLeft, var_NodeRight
        FROM Graph
    WHERE NodeId = var_ChildNodeID AND TreeId = var_ParentChildTreeID;
    
    var_NodeWidth := var_NodeRight - var_NodeLeft + 1;
    
    --dbms_output.put_line('5');
    
    -- Set new subtree
    UPDATE Graph
    SET TreeId = var_NewTreeID,
        lft = lft - var_NodeLeft,
        rgt = rgt - var_NodeLeft 
    WHERE lft BETWEEN var_NewTreeRootNodeLeft AND var_NewTreeRootNodeRight AND
          TreeId = var_ParentChildTreeID;
    
    --dbms_output.put_line('6');
    
    -- update Left, Right for old tree
    UPDATE Graph SET lft = lft - var_NodeWidth 
        WHERE lft > var_NodeRight AND TreeId = var_ParentChildTreeID;
    UPDATE Graph SET rgt = rgt - var_NodeWidth 
        WHERE rgt > var_NodeRight AND TreeId = var_ParentChildTreeID;
    
    CheckForRedundantTrees;
END;
/

/*
SELECT * FROM Graph;
BEGIN
    -- out, in
    DeleteArchFromParentToChild(1, 5); -- SPB -> UFA
END;
/
/*
BEGIN
    AddArchFromParentToChild(1, 5);
END;
/
--*/
SELECT * FROM Graph;

----------------------------------------------------------------------------------
PROMPT 5. Определить смежность вершин
----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION NodesIsAdjacency (NodeId1 IN INT, NodeId2 IN INT)
    RETURN VARCHAR2 
    IS
        var_count INT; -- local variable
    BEGIN
        SELECT COUNT(NODE.NodeId)
        INTO var_count
            FROM Graph NODE, Graph PARENT
        WHERE
            (NODE.lft - PARENT.lft = 1 OR PARENT.rgt - NODE.rgt = 1)
            AND
            (
                NODE.NodeId = NodeId1 AND PARENT.NodeId = NodeID2
                OR
                PARENT.NodeId = NodeId1 AND NODE.NodeId = NodeId2
            )
            AND
            NODE.TreeId = PARENT.TreeId;

        IF var_count <> 0
        THEN 
            RETURN 'TRUE';
        ELSE
            RETURN 'FALSE';
        END IF;
    END;
/

PROMPT SPB - MSC
SELECT NodesIsAdjacency(1, 2) FROM DUAL;
PROMPT UFA - SAM
SELECT NodesIsAdjacency(5, 3) FROM DUAL;


----------------------------------------------------------------------------------
PROMPT 6. Определить инцидентность узла к ребру
----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION GetParentId (NeededNodeId IN INT, NeededTreeId IN INT)
    RETURN NUMBER
IS
    ParentId NUMBER;
BEGIN
    BEGIN
    SELECT PARENT.NodeId
    INTO ParentId
        FROM Graph NODE,
             Graph PARENT
    WHERE 
        NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
        AND
        NODE.NodeId = NeededNodeId
        AND
        NODE.TreeId = NeededTreeId
        AND
        PARENT.TreeId = NeededTreeId
        AND
        PARENT.NodeId <> NODE.NodeId
    ORDER BY PARENT.lft DESC
    FETCH FIRST 1 ROW ONLY;
    
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ParentId := 0;
    END;
    RETURN ParentId;
END;
/

CREATE OR REPLACE FUNCTION NodeIncidenceEdge (NodeId IN INT, EdgeNodeId1 IN INT, EdgeNodeId2 IN INT)
    RETURN VARCHAR2 
IS
    common_tree INT;
    parent1 INT;
    lft1 INT;
    rgt1 INT;
    parent2 INT;
    lft2 INT;
    rgt2 INT;
BEGIN
    SELECT TreeId
    INTO common_tree
        FROM (
            SELECT Graph.TreeId
                FROM Graph
            WHERE Graph.NodeId = EdgeNodeId1
        INTERSECT
            SELECT Graph.TreeId
                FROM Graph
            WHERE Graph.NodeId = EdgeNodeId2);
    
    --dbms_output.put_line(common_tree);
    SELECT GetParentId(EdgeNodeId1, common_tree)
    INTO parent1
        FROM DUAL;
    
    SELECT GetParentId(EdgeNodeId2, common_tree)
    INTO parent2
        FROM DUAL;
    
    IF parent1 IS NULL
    THEN
        parent1 := 0;
    END IF;
    IF parent2 IS NULL
    THEN
        parent2 := 0;
    END IF;
    
    -- Check existing edge
    IF (parent1 = EdgeNodeId2 OR parent2 = EdgeNodeId1)
    --IF (lft1 > lft2 AND lft1 < rgt2) OR (lft2 > lft1 AND lft2 < rgt1)
    THEN
        IF NodeId = EdgeNodeId1 OR NodeId = EdgeNodeId2
        THEN 
            RETURN 'TRUE';
        ELSE
            RETURN 'FALSE';
        END IF;
    END IF;
    
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- exception handling logic goes here
        RETURN 'Error. Maybe not exists edge';
    WHEN OTHERS THEN
        -- exception handling logic goes here
        RETURN 'Error. Maybe not exists edge';
END;
/

-- SPB - (SAM -- MSC)
SELECT NodeIncidenceEdge (1, 3, 2) FROM DUAL;
-- SPB - (SPB -- UFA)
SELECT NodeIncidenceEdge (1, 1, 5) FROM DUAL;
SELECT * FROM graph;


----------------------------------------------------------------------------------
PROMPT 7. Найти путь между двумя вершинами
----------------------------------------------------------------------------------
--/*
DROP TABLE MatchedEntries PURGE;
DROP TABLE NodePath2 PURGE;
DROP TABLE NodePath1 PURGE;
DROP TABLE CommonTreesId PURGE;

DROP TABLE ResultQuery PURGE;

CREATE TABLE ResultQuery (NodeId INT);

CREATE TABLE CommonTreesId (TreeId INT);
CREATE TABLE NodePath1(NodeId INT, lft INT);
CREATE TABLE NodePath2 AS SELECT * from NodePath1 where 1=0;
CREATE TABLE MatchedEntries AS SELECT * from NodePath1 where 1=0;
--CREATE TABLE NodePath2(NodeId INT, lft INT);

CREATE OR REPLACE PROCEDURE FindPath (var_NodeId1 IN INT, var_NodeId2 IN INT) 
    IS
        var_CommonTreeCount INT;
        var_CommonTreeID INT;
        var_MaxLeft INT;
        var_LinkerNodeId INT;
    BEGIN
        
        -- Search common trees for Node 1 and Node 2
        INSERT INTO CommonTreesId
        SELECT TreeId
            FROM
            (
                SELECT TreeId FROM Graph WHERE NodeId = var_NodeId1
                INTERSECT
                SELECT TreeId FROM Graph WHERE NodeId = var_NodeId2
            ) CommonTrees;

        -- Select count of common trees
        SELECT COUNT(*)
        INTO var_CommonTreeCount
            FROM CommonTreesId;

        IF var_CommonTreeCount <> 0
        THEN
            -- If Node 1 and Node 2 are contained in the same tree
            
            SELECT TreeId
            INTO var_CommonTreeID
                FROM CommonTreesId;

            -- Find the way from parent to Node 1
            INSERT INTO NodePath1
            SELECT parent.NodeId, parent.lft
                FROM Graph node, Graph parent
            WHERE node.lft BETWEEN parent.lft AND parent.rgt AND 
                  node.TreeId = var_CommonTreeID AND
                  parent.TreeId = var_CommonTreeID AND
                  node.NodeId = var_NodeID1
            GROUP BY parent.NodeId, parent.lft
            ORDER BY parent.NodeId, parent.lft;

            -- Find the way from parent to Node 2
            INSERT INTO NodePath2
            SELECT parent.NodeId, parent.lft
                FROM Graph node, Graph parent
            WHERE node.lft BETWEEN parent.lft AND parent.rgt AND 
                  node.TreeId = var_CommonTreeID AND
                  parent.TreeId = var_CommonTreeID AND
                  node.NodeId = var_NodeID2
            GROUP BY parent.NodeId, parent.lft
            ORDER BY parent.NodeId, parent.lft;

            INSERT INTO MatchedEntries
            SELECT T1.NodeId, T1.lft 
                FROM NodePath1 T1, NodePath2 T2
            WHERE T1.NodeID = T2.NodeID
            ORDER BY T1.NodeID;

            SELECT MAX(lft)
            INTO var_MaxLeft
                FROM MatchedEntries;

            INSERT INTO ResultQuery (NodeId)
            SELECT NodeId
                FROM
                (
                    (
                        SELECT NodeId FROM NodePath1
                        UNION
                        SELECT NodeId FROM NodePath2
                    )
                    MINUS 
                    SELECT NodeId FROM MatchedEntries
                    UNION
                    SELECT NodeId FROM MatchedEntries 
                    WHERE lft = var_MaxLeft
                );

            DELETE FROM NodePath1;
            DELETE FROM NodePath2;
            DELETE FROM MatchedEntries;
        END IF; 
        DELETE FROM CommonTreesId;
END;
/

--SELECT * FROM table(test.FindPath(1, 5));
PROMPT FIND PATH 1, 4
BEGIN
    FindPath(1, 4);
END;
/
SELECT * FROM ResultQuery;
SELECT * FROM Graph;

DELETE FROM CommonTreesId;
DELETE FROM NodePath1;
DELETE FROM NodePath2;
DELETE FROM MatchedEntries;
DELETE FROM ResultQuery;

DROP TABLE ResultQuery PURGE;
DROP TABLE MatchedEntries PURGE;
DROP TABLE NodePath2 PURGE;
DROP TABLE NodePath1 PURGE;
DROP TABLE CommonTreesId PURGE;


----------------------------------------------------------------------------------
PROMPT 8. Найти подграф, обладающий заданными свойствами (или опорное дерево)
----------------------------------------------------------------------------------
PROMPT Ввывести дерево, число узлов в котором равно 5
SELECT TreeId
    FROM Graph
GROUP BY TreeId
HAVING COUNT(NodeId) = 5;

SELECT * FROM Graph;


----------------------------------------------------------------------------------
PROMPT 10. Выделить вершины с только входными дугами
----------------------------------------------------------------------------------
CREATE OR REPLACE VIEW NodesWithOnlyInputArc AS(
    (SELECT Graph.NodeId
        FROM Graph
    WHERE 
        Graph.rgt = Graph.lft + 1 
        AND
        Graph.lft <> 0)
    MINUS
    (SELECT Graph.NodeId
        FROM Graph
    WHERE 
        Graph.rgt - Graph.lft <> 1)
);

SELECT * FROM NodesWithOnlyInputArc;


----------------------------------------------------------------------------------
PROMPT 11. Удалить вершины с только входными дугами
----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DeleteInputNodes
IS
    var_NodeIter INT;
    var_NodeCount INT;

    var_NodeId INT;
    
    var_TreeIter INT;
    var_TreeCount INT;

    var_TreeID INT;
    
    var_NodeLeft INT;
    var_NodeRight INT;
BEGIN
    var_NodeIter := 1;

    SELECT COUNT(*)
    INTO var_NodeCount
        FROM NodesWithOnlyInputArc;

    WHILE var_NodeIter <= var_NodeCount
    LOOP
        -- Select NodeId from NodesWithOnlyInputArc by var_NodeIter
        SELECT NodeId
        INTO var_NodeId
            FROM 
            (SELECT NodeId
                    FROM NodesWithOnlyInputArc)
        WHERE ROWNUM = 1;

        var_TreeIter := 1;
        
        SELECT COUNT(*)
        INTO var_TreeCount
            FROM ( -- Find trees that have deleting node (NodeId)
                SELECT TreeId
                    FROM Graph
                WHERE NodeId = var_NodeId);

        -- Delete node from each tree
        WHILE var_TreeIter <= var_TreeCount
        LOOP
            SELECT TreeId
            INTO var_TreeID
                FROM (
                    SELECT TreeId
                        FROM Graph
                    WHERE NodeId = var_NodeId)
            WHERE ROWNUM = 1;

            SELECT lft, rgt
            INTO var_NodeLeft, var_NodeRight
                FROM Graph 
            WHERE NodeId = var_NodeID AND TreeId = var_TreeId;

            DELETE FROM Graph WHERE NodeId = var_NodeID AND TreeId = var_TreeId;

            UPDATE Graph SET lft = lft - 1, rgt = rgt - 1 
                WHERE lft BETWEEN var_NodeLeft AND var_NodeRight AND TreeId = var_TreeId;

            UPDATE Graph SET lft = lft - 2 
                WHERE lft > var_NodeRight AND TreeId = var_TreeId;

            UPDATE Graph SET rgt = rgt - 2 
                WHERE rgt > var_NodeRight AND TreeId = var_TreeId;

            var_TreeIter := var_TreeIter + 1;
        END LOOP;

        var_NodeIter := var_NodeIter + 1;
    END LOOP;
END;
/
/*
BEGIN
    DeleteInputNodes;
END;
/
--*/
SELECT * FROM Graph;
SELECT * FROM NodesWithOnlyInputArc;

----------------------------------------------------------------------------------
PROMPT 12. Выделить вершины с только выходными дугами
----------------------------------------------------------------------------------
CREATE OR REPLACE VIEW NodesWithOnlyOutputArc AS(
    (SELECT Graph.NodeId
        FROM Graph
    WHERE
        Graph.rgt <> Graph.lft + 1 
        AND
        Graph.lft = 0)
    MINUS
    (SELECT Graph.NodeId
        FROM Graph
    WHERE Graph.lft <> 0)
);

SELECT * FROM NodesWithOnlyOutputArc;


----------------------------------------------------------------------------------
PROMPT 13. Удалить вершины с только выходными дугами
----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DeleteOutputNodes
IS
    var_NodeIter  INT;
    var_NodeCount INT;

    var_NodeId INT;
    
    var_TreeIter  INT;
    var_TreeCount INT;

    var_TreeId INT;

    var_NodeLeft      INT;
    var_NodeRight     INT;
    var_NewRootNodeID INT;
BEGIN
    var_NodeIter := 1;  

    SELECT COUNT(*)
    INTO var_NodeCount
        FROM NodesWithOnlyOutputArc;

    WHILE var_NodeIter <= var_NodeCount
    LOOP
        -- Select NodeID from NodesWithOnlyOutputArc by var_NodeIter
        SELECT NodeId
        INTO var_NodeId
            FROM (
                SELECT NodeId
                    FROM NodesWithOnlyOutputArc)
        WHERE ROWNUM = 1;
        
        var_TreeIter := 1;

        SELECT COUNT(*)
        INTO var_TreeCount
            FROM ( -- Find trees that have deleting node (NodeID)
                SELECT TreeId 
                    FROM Graph
                WHERE NodeId = var_NodeId);

        -- Delete node from each tree
        WHILE var_TreeIter <= var_TreeCount
        LOOP
            SELECT TreeId
            INTO var_TreeId
            FROM (
                SELECT TreeId 
                    FROM Graph
                WHERE NodeId = var_NodeId)
            WHERE ROWNUM = 1;

            -- Select new root NodeID
            SELECT NodeId, lft, rgt
            INTO var_NewRootNodeID, var_NodeLeft, var_NodeRight
                FROM Graph 
            WHERE lft = 1 AND TreeId = var_TreeId;

            -- Delete old root
            DELETE FROM Graph WHERE NodeId = var_NodeId AND TreeId = var_TreeId;

            -- Update Left, Right for new root children
            UPDATE Graph SET lft = lft - 1, rgt = rgt - 1 
                WHERE lft BETWEEN var_NodeLeft AND var_NodeRight AND TreeId = var_TreeId;

            -- Update Left, Right for all others
            UPDATE Graph SET lft = lft - 2 
                WHERE lft > var_NodeRight AND TreeId = var_TreeId;
            UPDATE Graph SET rgt = rgt - 2 
                WHERE rgt > var_NodeRight AND TreeId = var_TreeId;

            -- Set new root
            UPDATE Graph SET lft = var_NodeLeft - 1, rgt = var_NodeRight + 1 
                WHERE NodeId = var_NewRootNodeID AND TreeId = var_TreeId;

            var_TreeIter := var_TreeIter + 1;
        END LOOP;

        var_NodeIter := var_NodeIter + 1;
    END LOOP;
END;
/
/*
BEGIN
    DeleteOutputNodes;
END;
/
--*/
SELECT * FROM Graph;
SELECT * FROM NodesWithOnlyOutputArc;

----------------------------------------------------------------------------------
PROMPT 9. Определить наличие циклов в графе и найти их
----------------------------------------------------------------------------------

CREATE TABLE Temp(
    NodeId INT
);

CREATE OR REPLACE PROCEDURE GetCycle
IS
    var_GraphChanged INT;
    var_NodeCountOld INT;
    var_NodeCountCurrent INT;
BEGIN
    var_GraphChanged := 1;

    var_NodeCountOld := 0;
    var_NodeCountCurrent := 0;

    SELECT COUNT(*)
    INTO var_NodeCountCurrent
        FROM Graph;

    -- Delete single nodes    
    DELETE
        FROM Graph
    WHERE Graph.TreeId IN 
        (-- Get TreeId where COUNT(NodeId) = 1
        SELECT TreeId 
            FROM
            (SELECT Graph.TreeId, COUNT(NodeId)
                FROM Graph
            GROUP BY Graph.TreeId
            HAVING COUNT(Graph.NodeId) = 1));

    WHILE var_NodeCountOld <> var_NodeCountCurrent
    LOOP
        DeleteInputNodes;

        var_NodeCountOld := var_NodeCountCurrent;

        SELECT COUNT(*)
        INTO var_NodeCountCurrent
            FROM Graph;
    END LOOP;

    IF var_NodeCountCurrent = 1
    THEN
        INSERT INTO Temp (NodeId) SELECT 0 FROM DUAL;
    ELSE
        INSERT INTO Temp (NodeId) SELECT DISTINCT NodeId FROM Graph;
    END IF;
END;
/

--/*
BEGIN
    GetCycle;
END;
/
--*/
SELECT * FROM Temp;

DROP TABLE Temp PURGE;


----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
SELECT * FROM Graph;

DROP PROCEDURE ins_Graph;
DROP PROCEDURE CheckForRedundantTrees;
-- 1.
DROP PROCEDURE AddNodeToGraph;
-- 2.
DROP PROCEDURE DeleteNode;
-- 3.
DROP PROCEDURE InsertNodeHowChild;
DROP PROCEDURE AddArchFromParentToChild;
-- 4.
--DROP PROCEDURE DeleteArchFromParentToChild;
-- 5.
DROP FUNCTION NodesIsAdjacency;
-- 6.
DROP FUNCTION GetParentId;
DROP FUNCTION NodeIncidenceEdge;
--7.
DROP PROCEDURE FINDPATH;
-- 10.
DROP VIEW NodesWithOnlyInputArc;
-- 11.
DROP PROCEDURE DeleteInputNodes;
-- 12.
DROP VIEW NodesWithOnlyOutputArc;
-- 13.
DROP PROCEDURE DeleteOutputNodes;
-- 9.
DROP PROCEDURE GetCycle;