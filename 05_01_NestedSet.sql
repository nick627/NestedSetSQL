-- Oracle DB (Oracle Linux Server)
-- Operations on nested set

-- Based: http://mikehillyer.com/articles/managing-hierarchical-data-in-mysql/
--        Poltavtseva_StorageOfComplexDataStructuresInRelationalDB

DROP TABLE NestedSet PURGE;


CREATE TABLE NestedSet (
    NodeId INT NOT NULL, --GENERATED ALWAYS AS IDENTITY(START with 1 INCREMENT by 1),
    lft    INT NOT NULL,
    rgt    INT NOT NULL,
    Name VARCHAR(20) NOT NULL,

    CONSTRAINT check_lft     CHECK (lft > 0),
    CONSTRAINT check_rgt     CHECK (rgt > 0),
    CONSTRAINT check_lft_grt CHECK (lft < rgt),

    PRIMARY KEY (NodeId)
);


CREATE OR REPLACE PROCEDURE ins_NestedSet (tmp_NodeId IN INT, tmp_Name IN CHAR, tmp_lft IN INT, tmp_rgt IN INT)
IS
BEGIN
    INSERT INTO NestedSet (NodeId, Name, lft, rgt) VALUES (tmp_NodeId, tmp_Name, tmp_lft, tmp_rgt);
END;
/


BEGIN
    ins_NestedSet (1,  'BUSINESS CENTER', 1,20);
    ins_NestedSet (2,  'FIRST FLOOR',     2, 9);
    ins_NestedSet (3,  'CAFE',            3, 4);
    ins_NestedSet (4,  'TOILETS',         5, 6);
    ins_NestedSet (5,  'SECURITY',        7, 8);
    ins_NestedSet (6,  'SECOND FLOOR',   10,19);
    ins_NestedSet (7,  'ADMINIS',        11,14);
    ins_NestedSet (8,  'SERVERS',        12,13);
    ins_NestedSet (9,  'ACCOUNTING',     15,16);
    ins_NestedSet (10, 'SERVICE',        17,18);
END;
/


SELECT * FROM NestedSet ORDER BY NodeId;

-- 

----------------------------------------------------------------------------------
PROMPT 1. Вывести список всех терминальных элементов (листья)
----------------------------------------------------------------------------------
SELECT NestedSet.Name
    FROM NestedSet
WHERE NestedSet.rgt = NestedSet.lft + 1;


----------------------------------------------------------------------------------
PROMPT 2. Найти корень дерева
----------------------------------------------------------------------------------
SELECT NestedSet.Name
    FROM NestedSet
WHERE NestedSet.lft = 1;


----------------------------------------------------------------------------------
PROMPT 3. Определить длину максимального пути (глубину, (размер)) дерева
----------------------------------------------------------------------------------
SELECT NODE.Name, (COUNT(PARENT.Name) - 1) AS DEPTH
    FROM NestedSet NODE,
         NestedSet PARENT
WHERE NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
GROUP BY NODE.Name
ORDER BY DEPTH DESC
FETCH FIRST 1 ROW ONLY;


----------------------------------------------------------------------------------
PROMPT 4. Вывести все пути по одному (двум, трем, ...) уровням в дереве
----------------------------------------------------------------------------------
-- Output all nodes given depth
SELECT NAME
    FROM (
        SELECT NODE.Name AS NAME, (COUNT(PARENT.Name) - 1) AS DEPTH
            FROM NestedSet NODE,
                 NestedSet PARENT
        WHERE NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
        GROUP BY NODE.Name
        ORDER BY DEPTH)
-- 0 - root, 1 - child, 2 - grandchild, ...
WHERE DEPTH = 2;


----------------------------------------------------------------------------------
PROMPT 5. Суммирование данных узлов по поддереву от заданного корня
----------------------------------------------------------------------------------
-- SELECT SUM(NODE.NodeId) AS SUM
SELECT LISTAGG(TMPNAME, ';') WITHIN GROUP (ORDER BY TMPNAME)
    FROM (
          SELECT NODE.Name AS TMPNAME
                FROM NestedSet NODE,
                     NestedSet PARENT
          WHERE
                NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
                AND 
                PARENT.Name = 'SECOND FLOOR'
                AND
                PARENT.NodeId <> NODE.NodeId
        );


----------------------------------------------------------------------------------
PROMPT 6. Вычислить уровень иерархии данного узла
PROMPT (уровень узла - число дуг между узлом и корнем,
PROMPT т.е. какая длина пути от корня до данного элемента)
----------------------------------------------------------------------------------
SELECT NODE.Name, (COUNT(PARENT.Name) - 1) AS DEPTH
    FROM NestedSet NODE, 
         NestedSet PARENT
WHERE 
    NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
    AND
    NODE.Name = 'SERVERS'
GROUP BY NODE.Name;


----------------------------------------------------------------------------------
PROMPT 7. Вычислить уровни всех узлов (вывести списком)
----------------------------------------------------------------------------------
SELECT NODE.Name, (COUNT(PARENT.Name) - 1) AS DEPTH
    FROM NestedSet NODE,
         NestedSet PARENT
WHERE NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
GROUP BY NODE.Name
ORDER BY DEPTH;


----------------------------------------------------------------------------------
PROMPT 8. Вычислить разность уровней двух заданных узлов
PROMPT (разность уровней - число дуг между двумя данными узлами)
----------------------------------------------------------------------------------
-- Down
----------------------------------------------------------------------------------
PROMPT 9. Вывести путь между двумя узлами
----------------------------------------------------------------------------------
-- Nodes are not ordered, nodes to be visited are displayed
DEFINE NodeId1 = '2';
DEFINE NodeId2 = '8';

CREATE OR REPLACE VIEW NodePath1 AS
    SELECT PARENT.NodeId, PARENT.lft
        FROM NestedSet NODE, NestedSet PARENT
    WHERE
        NODE.lft BETWEEN PARENT.lft AND PARENT.rgt 
        AND 
    	NODE.NodeId = '&NodeId1'
    GROUP BY PARENT.NodeId, PARENT.lft
    ORDER BY PARENT.NodeId;

CREATE OR REPLACE VIEW NodePath2 AS
    SELECT PARENT.NodeId, PARENT.lft
        FROM NestedSet NODE, NestedSet PARENT
    WHERE
        NODE.lft BETWEEN PARENT.lft AND PARENT.rgt 
        AND 
    	NODE.NodeId = '&NodeId2'
    GROUP BY PARENT.NodeId, PARENT.lft
    ORDER BY PARENT.NodeId;

CREATE OR REPLACE VIEW MatchedEntries AS
    SELECT T1.NodeId, T1.lft
        FROM NodePath1 T1, NodePath2 T2
    WHERE T1.NodeID = T2.NodeID
    ORDER BY T1.NodeID;

CREATE OR REPLACE VIEW ResultQuery9 AS
    (SELECT NodeId FROM NodePath1
    UNION
        SELECT NodeId FROM NodePath2) 
    MINUS
        SELECT NodeId FROM MatchedEntries
    UNION
        SELECT NodeId FROM MatchedEntries
        WHERE MatchedEntries.lft = (SELECT MAX(lft) FROM MatchedEntries);

PROMPT 8.
SELECT COUNT(*) - 1 FROM ResultQuery9;

PROMPT 9.
SELECT * FROM ResultQuery9;

DROP VIEW ResultQuery9;
DROP VIEW MatchedEntries;
DROP VIEW NodePath2;
DROP VIEW NodePath1;


----------------------------------------------------------------------------------
PROMPT 10. Вывести список всех потомков данного элемента.
PROMPT Возможные модификации:
----------------------------------------------------------------------------------
SELECT NODE2.Name, NODE2.depth
    FROM
    (
        -- MAX(SUB_TREE.depth) because COUNT and GROUP BY, those (without MAX and GROUP BY(Name, sub_tree.depth)) or (MAX and GROUP BY(Name))
        SELECT NODE.Name, (COUNT(PARENT.Name) - MAX(SUB_TREE.depth) - 1) AS DEPTH, node.lft, node.rgt
            FROM NestedSet NODE, 
                 NestedSet PARENT,
                 NestedSet SUB_PARENT,
                (
                    SELECT NODE1.Name, (COUNT(PARENT1.Name) - 1) AS DEPTH
                        FROM NestedSet NODE1,
                             NestedSet PARENT1
                    WHERE
                        NODE1.lft BETWEEN PARENT1.lft AND PARENT1.rgt
                        AND
                        NODE1.Name = 'SECOND FLOOR'
                    GROUP BY NODE1.Name
                    FETCH FIRST 1 ROW ONLY
                ) SUB_TREE
        WHERE
            NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
            AND 
            NODE.lft BETWEEN SUB_PARENT.lft AND SUB_PARENT.rgt
            AND
            SUB_PARENT.Name = SUB_TREE.Name
            AND
            NODE.Name <> SUB_TREE.Name
        GROUP BY NODE.Name, node.lft, node.rgt
        ORDER BY DEPTH
    ) NODE2

/*
--  a. всех потомков
-- Empty
--*/

/*
--  b. потомков заданного уровня (детей, внуков, правнуков, ...)
-- child: DEPTH = 1, grandchild: DEPTH = 2, ...
WHERE NODE2.DEPTH = 1
--*/

/*
--  c. потомков до заданного уровня
WHERE NODE2.DEPTH <= 2
--*/

--/*
--  d. всех терпинальных потомков
WHERE NODE2.rgt = NODE2.lft + 1
--*/

ORDER BY DEPTH;


----------------------------------------------------------------------------------
PROMPT 11. Вычислить количество потомков данного элемента
PROMPT (модификации такие же, как в задаче 10)
----------------------------------------------------------------------------------
SELECT COUNT(NODE2.Name)
    FROM
    (
        -- MAX(SUB_TREE.depth) because COUNT and GROUP BY, those (without MAX and GROUP BY(Name, sub_tree.depth)) or (MAX and GROUP BY(Name))
        SELECT NODE.Name, (COUNT(PARENT.Name) - MAX(SUB_TREE.depth) - 1) AS DEPTH, node.lft, node.rgt
            FROM NestedSet NODE, 
                 NestedSet PARENT,
                 NestedSet SUB_PARENT,
                (
                    SELECT NODE1.Name, (COUNT(PARENT1.Name) - 1) AS DEPTH
                        FROM NestedSet NODE1,
                             NestedSet PARENT1
                    WHERE
                        NODE1.lft BETWEEN PARENT1.lft AND PARENT1.rgt
                        AND
                        NODE1.Name = 'SECOND FLOOR'
                    GROUP BY NODE1.Name
                    FETCH FIRST 1 ROW ONLY
                ) SUB_TREE
        WHERE
            NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
            AND 
            NODE.lft BETWEEN SUB_PARENT.lft AND SUB_PARENT.rgt
            AND
            SUB_PARENT.Name = SUB_TREE.Name
            AND
            NODE.Name <> SUB_TREE.Name
        GROUP BY NODE.Name, node.lft, node.rgt
        ORDER BY DEPTH
    ) NODE2

/*
--  a. всех потомков
-- Empty
--*/

--/*
--  b. потомков заданного уровня (детей, внуков, правнуков, ...)
-- child: depth = 1, grandchild: depth = 2, ...
WHERE NODE2.DEPTH = 2

/*
--  c. потомков до заданного уровня
WHERE NODE2.DEPTH <= 2
--*/

/*
--  d. всех терпинальных потомков
WHERE NODE2.rgt = NODE2.lft + 1
--*/
--GROUP BY NODE2.Name
ORDER BY DEPTH;


----------------------------------------------------------------------------------
PROMPT 12. Вывести список всех предков данного элемента.
PROMPT Возможные модификации:
----------------------------------------------------------------------------------
SELECT PARENT.Name
    FROM NestedSet NODE,
         NestedSet PARENT
WHERE 
    NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
    AND
    NODE.Name = 'SERVERS'
    AND
    PARENT.Name <> NODE.Name
ORDER BY PARENT.lft DESC

/*
-- a. всех предков
-- Empty
--*/

/*
--  b. предков заданного уровня (родитель, дед, прадед)
-- offset 0 - parent, offset 1 - grandparent, ...
OFFSET 1 ROWS FETCH FIRST 1 ROW ONLY 
--*/

--/*
--  c. всех предков до заданного уровня
-- first 1 - to parent,  first 2 - to grnadparent, ...
FETCH FIRST 1 ROW ONLY 
--*/
;


----------------------------------------------------------------------------------
PROMPT 13. Вычислить количество предков данного элемента
PROMPT (модификации такие же, как в задаче 10)
----------------------------------------------------------------------------------
SELECT COUNT(*)
    FROM
    (
        SELECT PARENT.Name
            FROM NestedSet NODE,
                 NestedSet PARENT
        WHERE 
            NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
            AND
            NODE.Name = 'SERVERS'
            AND
            PARENT.Name <> NODE.Name
        ORDER BY PARENT.lft DESC
        
        /*
        -- a. всех предков
        -- Empty
        --*/
        
        /*
        --  b. предков заданного уровня (родитель, дед, прадед)
        -- offset 0 - parent, offset 1 - grandparent, ...
        OFFSET 1 ROWS FETCH FIRST 1 ROW ONLY 
        --*/
        
        --/*
        --  c. всех предков до заданного уровня
        -- first 1 - to parent,  first 2 - to grnadparent, ...
        FETCH FIRST 2 ROW ONLY
        --*/
    );


----------------------------------------------------------------------------------
PROMPT 14. Вывести список всех общих предков для (двух и более)
-- заданных элементов при условии:
----------------------------------------------------------------------------------
--  a. без условий
--  b. находящихся на заданном расстоянии (в том числе ближайших)
--  c. элементы расположены на одном уровне
--  d. элементы расположены на разных уровнях
-- a - d realized below
DEFINE NodeId1 = '6';
DEFINE NodeId2 = '8';

    SELECT PARENT.NodeId
        FROM NestedSet NODE,
             NestedSet PARENT
    WHERE
        NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
        AND
        NODE.NodeId = '&NodeID1'
        AND
        PARENT.NodeId <> NODE.NodeId
INTERSECT
    SELECT PARENT.NodeId
        FROM NestedSet NODE,
             NestedSet PARENT
    WHERE
        NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
        AND
        NODE.NodeId = '&NodeID2'
        AND
        PARENT.NodeId <> NODE.NodeId
-- Если узлов больше добавить INTERSECT продублировать запрос (можно переделать через цикл)
;


----------------------------------------------------------------------------------
PROMPT 15. Найти всех общих предков для (двух и более) заданных
-- элементов. Возможные модификации:
----------------------------------------------------------------------------------
DEFINE NodeId1 = '7';
DEFINE NodeId2 = '8';

    SELECT PARENT.NodeId AS PARENT, PARENT.lft
        FROM NestedSet NODE,
             NestedSet PARENT
    WHERE
        NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
        AND
        NODE.NodeId = '&NodeID1'
        AND
        PARENT.NodeId <> NODE.NodeId
INTERSECT
    SELECT PARENT.NodeId, PARENT.lft
        FROM NestedSet NODE,
             NestedSet PARENT
    WHERE
        NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
        AND
        NODE.NodeId = '&NodeID2'
        AND
        PARENT.NodeId <> NODE.NodeId
--  a. начиная сверху
--ORDER BY lft ASC

--  b. начиная снизу
ORDER BY lft DESC
;


----------------------------------------------------------------------------------
PROMPT 16. Вычислить количество общих предков у двух узлов
----------------------------------------------------------------------------------
DEFINE NodeId1 = '7';
DEFINE NodeId2 = '8';

SELECT COUNT(*) AS ParentCount
    FROM (
            SELECT PARENT.NodeId
                FROM NestedSet NODE,
                     NestedSet PARENT
            WHERE
                NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
                AND
                NODE.NodeId = '&NodeID1'
                AND
                PARENT.NodeId <> NODE.NodeId

            INTERSECT

            SELECT PARENT.NodeId
                FROM NestedSet NODE,
                     NestedSet PARENT
            WHERE
                NODE.lft BETWEEN PARENT.lft AND PARENT.rgt 
                AND
                NODE.NodeId = '&NodeID2'
                AND
                PARENT.NodeId <> NODE.NodeId
    ) COMMONPARENTS;


----------------------------------------------------------------------------------
PROMPT 17. Вставка узла
----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE InsertNodeHowChild (ParentNode IN CHAR, ChildNode IN CHAR)
IS
     no_parent EXCEPTION;
     
     myLeft  INT := 0;
BEGIN
    SELECT NestedSet.lft
    INTO myLeft
        FROM NestedSet
    WHERE NestedSet.Name = ParentNode;

    -- myLeft never equivalent NULL
    IF myLeft = NULL THEN
        RAISE no_parent;
    END IF;

    UPDATE NestedSet SET NestedSet.rgt = NestedSet.rgt + 2
        WHERE NestedSet.rgt > myLeft;
    UPDATE NestedSet SET NestedSet.lft = NestedSet.lft + 2
        WHERE NestedSet.lft > myLeft;

    INSERT INTO NestedSet (NodeId, Name, lft, rgt) 
        VALUES((SELECT (MAX(NodeId) + 1) FROM NestedSet), ChildNode, myLeft + 1, myLeft + 2);

    --dbms_output.put_line('Parent.lft = ' || myLeft);
    EXCEPTION
        WHEN no_parent THEN
            dbms_output.put_line('Not found parent node.');
        WHEN OTHERS THEN
            dbms_output.put_line('Error. Not found parent node.');
END;
/


----------------------------------------------------------------------------------
PROMPT 18. Удаление узла
----------------------------------------------------------------------------------
-- Deletion of a parent node but not the children
CREATE OR REPLACE PROCEDURE DeleteNode (Node IN CHAR)
IS
    no_node EXCEPTION;
    no_root EXCEPTION;
    
    myLeft  INT := 0;
    myRight INT := 0;
BEGIN
    SELECT NestedSet.lft, NestedSet.rgt
    INTO myLeft, myRight
        FROM NestedSet
    WHERE NestedSet.Name = Node;

    IF (myLeft = NULL) OR (myRight = NULL) THEN
        RAISE no_node;
    END IF;

    DELETE FROM NestedSet 
        WHERE NestedSet.lft = myLeft;
    
    -- Update Left, Right for new root children
    UPDATE NestedSet SET NestedSet.rgt = NestedSet.rgt - 1, NestedSet.lft = lft - 1 
        WHERE NestedSet.lft BETWEEN myLeft AND myRight;
    
    -- Update Left, Right for all others
    UPDATE NestedSet SET NestedSet.lft = NestedSet.lft - 2
        WHERE NestedSet.lft > myRight;
    UPDATE NestedSet SET NestedSet.rgt = NestedSet.rgt - 2
        WHERE NestedSet.rgt > myRight;
    
    -- If delete root
    IF (myLeft = 1) THEN
        SELECT NestedSet.rgt
        INTO myRight
            FROM NestedSet
        WHERE NestedSet.lft = myLeft;
        
        UPDATE NestedSet SET NestedSet.lft = NestedSet.lft - 1
            WHERE NestedSet.lft > myRight;
        UPDATE NestedSet SET NestedSet.rgt = NestedSet.rgt - 1
            WHERE NestedSet.rgt > myRight;
        
        UPDATE NestedSet SET NestedSet.rgt = (SELECT (MAX(NestedSet.rgt) + 1) FROM NestedSet)
        WHERE NestedSet.lft = myLeft;
    END IF;
    
    --dbms_output.put_line('Node.lft, Node.rgt) = ' || '(' || myLeft || ',' || myRight || ')');
    EXCEPTION
        WHEN no_node THEN
            dbms_output.put_line('Not found node.');
        WHEN OTHERS THEN
            dbms_output.put_line('Error. Not found node.');
END;
/


----------------------------------------------------------------------------------
PROMPT 20. Удаление поддерева (удаление узла и всех его потомков)
----------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DeleteSubTree (Node IN CHAR)
IS
    no_node EXCEPTION;
     
    myLeft  INT := 0;
    myRight INT := 0;
    myWidth INT := 0;
BEGIN
    SELECT NestedSet.lft, NestedSet.rgt
    INTO myLeft, myRight
        FROM NestedSet
    WHERE NestedSet.Name = Node;

    IF (myLeft = NULL) OR (myRight = NULL) THEN
        RAISE no_node;
    END IF;
    
    myWidth := myRight - myLeft + 1;
    
    DELETE FROM NestedSet
        WHERE NestedSet.lft BETWEEN myLeft AND myRight;
    
    UPDATE NestedSet SET NestedSet.lft = NestedSet.lft - myWidth
        WHERE NestedSet.lft > myRight;
    UPDATE NestedSet SET NestedSet.rgt = NestedSet.rgt - myWidth
        WHERE NestedSet.rgt > myRight;

    --dbms_output.put_line('Node.lft, Node.rgt) = ' || '(' || myLeft || ',' || myRight || ')');

    EXCEPTION
        WHEN no_node THEN
            dbms_output.put_line('Not found node.');
        WHEN OTHERS THEN
            dbms_output.put_line('Error. Not found node.');
END;
/


----------------------------------------------------------------------------------
PROMPT 21. Перемещение поддерева
----------------------------------------------------------------------------------
-- Create temporary table for function MoveSubTreeHowChildDestinationNode
-- Copy NestedSet
CREATE TABLE tbltemp AS SELECT * from NestedSet WHERE 1=0;

CREATE OR REPLACE PROCEDURE MoveSubTreeHowChildDestinationNode (DestinationNode IN CHAR, SourceNode IN CHAR)
IS
    myLeft  INT := 0;
    myRight INT := 0;
    myWidth INT := 0;
    
    tmptId INT := 0;
    insLft INT := 0;
    insRgt INT := 0;
    step   INT := 0;
BEGIN
    -- Get the parameters for the sub tree to move
    SELECT NestedSet.NodeId, NestedSet.lft, NestedSet.rgt
    INTO tmptId, myLeft, myRight
        FROM NestedSet
    WHERE NestedSet.Name = SourceNode;

    myWidth := myRight - myLeft + 1;

    -- Get the fldLft and fldRgt value of the new parent cat
    SELECT NestedSet.lft, NestedSet.rgt
    INTO insLft, insRgt
        FROM NestedSet
    WHERE NestedSet.Name = DestinationNode;

    -- Get the offset to renumber the subtree lefts and rights
    step := insLft - myLeft + 1;

    -- Transfer the subtree to a temp table
    INSERT INTO tbltemp (NodeId, Name, lft, rgt)
        SELECT NestedSet.NodeId, NestedSet.Name, NestedSet.lft, NestedSet.rgt
            FROM NestedSet
        WHERE NestedSet.lft >= myLeft AND NestedSet.lft <= myRight;
    
    -- Update the temp table - renumber the lefts and rights and make the catId neg temporarily
    UPDATE tbltemp
        SET tbltemp.lft = tbltemp.lft + step, 
            tbltemp.rgt = tbltemp.rgt + step,
            tbltemp.NodeId = -(tbltemp.NodeId);

    -- Update the rest of the tree to the right of the move point
    UPDATE NestedSet SET NestedSet.rgt = NestedSet.rgt + myWidth
        WHERE NestedSet.rgt > insLft;
    UPDATE NestedSet SET NestedSet.lft = NestedSet.lft + myWidth
        WHERE NestedSet.lft > insLft;

    -- Insert the sub tree in the temp table 
    INSERT INTO NestedSet (NodeId, Name, lft, rgt)
        SELECT tbltemp.NodeId, tbltemp.Name, tbltemp.lft, tbltemp.rgt 
            FROM tbltemp;

    -- Delete the original subtree via Id
    SELECT NestedSet.lft, NestedSet.rgt
    INTO myLeft, myRight
        FROM NestedSet
    WHERE NestedSet.NodeId = tmptId;
    
    myWidth := myRight - myLeft + 1;

    DELETE FROM NestedSet
        WHERE NestedSet.lft BETWEEN myLeft AND myRight;
    
    UPDATE NestedSet SET NestedSet.lft = NestedSet.lft - myWidth
        WHERE NestedSet.lft > myRight;
    UPDATE NestedSet SET NestedSet.rgt = NestedSet.rgt - myWidth
        WHERE NestedSet.rgt > myRight;

    -- Reset neg. tmptId's to pos. and clean up tblcattemp
    UPDATE NestedSet SET NestedSet.NodeId = -(NestedSet.NodeId)
        WHERE NestedSet.NodeId < 0;
    
    DELETE FROM tbltemp;
    --*/
END;
/


----------------------------------------------------------------------------------
PROMPT 17 - 21
----------------------------------------------------------------------------------
BEGIN

    -- Check exception
    InsertNodeHowChild('BUSINESS', 'OPERATO');

    ----------------------------------------------------------------------------------
    -- 19. Вставка поддерева
    ----------------------------------------------------------------------------------
    --/*
    InsertNodeHowChild('BUSINESS CENTER', 'OPERATORS');
    InsertNodeHowChild('OPERATORS', 'MTS');
    InsertNodeHowChild('OPERATORS', 'MEGAFON');
    InsertNodeHowChild('OPERATORS', 'TELE2');
    --*/

    -- 18
    --DeleteNode('OPERATORS');
    --DeleteNode('BUSINESS CENTER');
    --DeleteNode('FIRST FLOOR');

    -- 20
    --DeleteSubTree('OPERATORS');
    
    -- 21
    MoveSubTreeHowChildDestinationNode('SECOND FLOOR', 'OPERATORS');
    MoveSubTreeHowChildDestinationNode('BUSINESS CENTER', 'OPERATORS');

END; 
/
SELECT * FROM NestedSEt;


----------------------------------------------------------------------------------
PROMPT 22.Конвертация из данного представления в другие
----------------------------------------------------------------------------------
-- Модель с хранением пар предок-петомок с добавлением глубины
DROP TABLE TreeStructures PURGE;
DROP TABLE Nodes PURGE;

CREATE TABLE Nodes (
    NodeId INT NOT NULL,
    --ParentId INT NULL,
    Name VARCHAR(20) NOT NULL,
    
    PRIMARY KEY (NodeId)
);

CREATE TABLE TreeStructures (
    NodeId   INT NOT NULL,
    ParentId INT NOT NULL, -- because ParentId FK for NodeId (!)
    Distance INT NOT NULL,

    PRIMARY KEY (NodeId, ParentId),

    FOREIGN KEY (NodeId)   REFERENCES Nodes(NodeId),
    FOREIGN KEY (ParentId) REFERENCES Nodes(NodeId)
);

-- Copy NodeId, Name
INSERT INTO Nodes (NodeId, Name)
    SELECT NestedSet.NodeId, NestedSet.Name
        FROM NestedSet;
/*
-- Find parent
UPDATE Nodes N
    SET ParentId = 
        (SELECT T2.PARENT
            -- Get parent_id via rgt 
            FROM (SELECT TMP.NODE AS ID, PARENT.NodeId AS PARENT
                    FROM NestedSet PARENT,
                        -- MIN(parent.rgt) is parent's node
                        (SELECT node.NodeId AS NODE, MIN(PARENT.rgt) AS RGT_PARENT
                                FROM NestedSet NODE, 
                                    NestedSet PARENT
                            WHERE 
                                NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
                                AND
                                NODE.NodeId IN (SELECT NodeId FROM NestedSet)
                                AND
                                NODE.NodeId <> PARENT.NodeId 
                            GROUP BY NODE.NodeId
                        ) TMP 
                 WHERE PARENT.rgt = TMP.RGT_PARENT) T2
            WHERE N.NodeId = T2.ID);
*/

-- Insert other nodes - node and all his parents
-- at start - all distance = 0
INSERT INTO TreeStructures (NodeId, ParentId, Distance)
    SELECT node.NodeId, PARENT.Nodeid, 0
        FROM NestedSet NODE, 
             NestedSet PARENT
    WHERE 
        NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
        AND
        NODE.NodeId IN (SELECT NodeId FROM NestedSet)
        AND
        NODE.NodeId <> PARENT.NodeId;

-- Add distance for all rows
UPDATE TreeStructures Strct
    SET Distance = 
        (SELECT T2.DEPTH 
        -- DEPTH calculate immediately from TreeStructures.ParentId
        FROM (SELECT NODE.NodeId, (COUNT(PARENT.Name)) AS DEPTH
                FROM NestedSet NODE, 
                     NestedSet PARENT
              WHERE 
                NODE.lft BETWEEN PARENT.lft AND PARENT.rgt
                AND
                NODE.NodeId IN (SELECT NodeId FROM NestedSet)
              GROUP BY NODE.NodeId) T2
        WHERE Strct.ParentId = T2.NodeId);

-- Insert root
/*
INSERT INTO TreeStructures (NodeId, ParentId, Distance) 
    SELECT Nodes.NodeId, Nodes.NodeId, 0 
        FROM Nodes
    WHERE Nodes.ParentId IS NULL;
--*/
INSERT INTO TreeStructures (NodeId, ParentId, Distance) 
    SELECT NestedSet.NodeId, NestedSet.NodeId, 0
        FROM NestedSet
    WHERE NestedSet.lft = 1;


----------------------------------------------------------------------------------
DROP PROCEDURE ins_NestedSet;
-- 17.
DROP PROCEDURE InsertNodeHowChild;
-- 18.
DROP PROCEDURE DeleteNode;
-- 20.
DROP PROCEDURE DeleteSubTree;
-- 21.
DROP PROCEDURE MoveSubTreeHowChildDestinationNode;
-- Remove temporary table for function MoveSubTreeHowChildDestinationNode
DROP TABLE tbltemp PURGE;

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
SELECT * FROM NestedSet ORDER BY NodeId;
SELECT * FROM Nodes ORDER BY NodeId;
SELECT * FROM TreeStructures ORDER BY NodeId, ParentId;
