--------------------------------------------------------
-- Physical Database Structure; Files and Filegroups
--------------------------------------------------------
CREATE DATABASE demonstrateFilegroups ON
PRIMARY ( NAME = Primary1, FILENAME = 'c:\demonstrateFilegroups_primary.mdf',
          SIZE = 10MB),
FILEGROUP SECONDARY
        ( NAME = Secondary1,FILENAME = 
                            'c:\demonstrateFilegroups_secondary1.ndf',
          SIZE = 10MB),
        ( NAME = Secondary2,FILENAME = 
                            'c:\demonstrateFilegroups_secondary2.ndf',
          SIZE = 10MB)
LOG ON ( NAME = Log1,FILENAME = 'c:\demonstrateFilegroups_log.ldf', SIZE = 10MB)
GO
CREATE DATABASE demonstrateFileGrowth ON
PRIMARY ( NAME = Primary1,FILENAME = 'c:\demonstrateFileGrowth_primary.mdf',
                              SIZE = 1GB, FILEGROWTH=100MB, MAXSIZE=2GB)
LOG ON ( NAME = Log1,FILENAME = 'c:\demonstrateFileGrowth_log.ldf', SIZE = 10MB)
GO
USE demonstrateFilegroups
GO
SELECT fg.name as file_group,
        df.name as file_logical_name,
        df.physical_name as physical_file_name
FROM   sys.filegroups fg
         join sys.database_files df
            on fg.data_space_id = df.data_space_id
GO
USE MASTER
GO
DROP DATABASE demonstrateFileGroups
DROP DATABASE demonstrateFileGrowth
GO


--------------------------------------------------------
-- Physical Database Structure; Data on Pages; Page Splits
--------------------------------------------------------

SELECT  s.[name] AS SchemaName,
        o.[name] AS TableName,
        i.[name] AS IndexName,
        f.[avg_fragmentation_in_percent] AS FragPercent,
        f.fragment_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, DEFAULT) f
        JOIN sys.indexes i 
             ON f.[object_id] = i.[object_id] AND f.[index_id] = i.[index_id]
        JOIN sys.objects o 
             ON i.[object_id] = o.[object_id]
        JOIN sys.schemas s 
             ON o.[schema_id] = s.[schema_id]
WHERE o.[is_ms_shipped] = 0
  AND i.[is_disabled] = 0 -- skip disabled indexes

GO

--------------------------------------------------------
-- Physical Database Structure; Data on Pages; Compression
--------------------------------------------------------
USE tempdb
GO
CREATE TABLE test
(
    testId int,
    value  int
) 
WITH (DATA_COMPRESSION = ROW) -- PAGE or NONE
    ALTER TABLE test REBUILD WITH (DATA_COMPRESSION = PAGE) ;

CREATE CLUSTERED INDEX XTest_value
   ON test (value) WITH ( DATA_COMPRESSION = ROW ) ;

ALTER INDEX XTest_value 
   ON test REBUILD WITH ( DATA_COMPRESSION = PAGE )
GO
DROP TABLE Test
GO

--------------------------------------------------------
-- Physical Database Structure; Partitioning
--------------------------------------------------------

CREATE PARTITION FUNCTION PartitionFunction$dates (smalldatetime)
AS RANGE LEFT FOR VALUES ('20020101','20030101');  
                  --set based on recent version of 
                  --AdventureWorks2008.Sales.SalesOrderHeader table to show
                  --partition utilization
GO
CREATE PARTITION SCHEME PartitonScheme$dates
                AS PARTITION PartitionFunction$dates ALL to ( [PRIMARY] )
GO
CREATE TABLE salesOrder
(
    salesOrderId     int,
    customerId       int,
    orderAmount      decimal(10,2),
    orderDate        smalldatetime,
    constraint PKsalesOrder primary key nonclustered (salesOrderId) 
                                                               ON [Primary],
    constraint AKsalesOrder unique clustered (salesOrderId, orderDate)
) on PartitonScheme$dates (orderDate)
GO
INSERT INTO salesOrder
SELECT SalesOrderId, CustomerId, TotalDue, OrderDate
FROM   AdventureWorks2008.Sales.SalesOrderHeader
GO
SELECT *, $partition.PartitionFunction$dates(orderDate) as partiton
FROM   salesOrder
GO
SELECT  partitions.partition_number, partitions.index_id, 
        partitions.rows, indexes.name, indexes.type_desc
FROM    sys.partitions as partitions
           JOIN sys.indexes as indexes
               on indexes.object_id = partitions.object_id
                   and indexes.index_id = partitions.index_id
WHERE   partitions.object_id = object_id('salesOrder')
GO
---------------------------------------------------------------------------
-- Indexes Overview; Basics of Index Creation
---------------------------------------------------------------------------
CREATE SCHEMA produce
go
CREATE TABLE produce.vegetable
(
   --PK constraint defaults to clustered
   vegetableId int CONSTRAINT PKproduce_vegetable PRIMARY KEY,
   name varchar(15)
                   CONSTRAINT AKproduce_vegetable_name UNIQUE,
   color varchar(10),
   consistency varchar(10),
   filler char(4000) default (replicate('a', 4000)) 
)
GO
CREATE INDEX Xproduce_vegetable_color ON produce.vegetable(color)
CREATE INDEX Xproduce_vegetable_consistency ON produce.vegetable(consistency)
GO
CREATE UNIQUE INDEX Xproduce_vegetable_vegetableId_color
        ON produce.vegetable(vegetableId, color)
GO
INSERT INTO produce.vegetable(vegetableId, name, color, consistency)
VALUES (1,'carrot','orange','crunchy'), (2,'broccoli','green','leafy'),
       (3,'mushroom','brown','squishy'), (4,'pea','green','squishy'),
       (5,'asparagus','green','crunchy'), (6,'sprouts','green','leafy'),
       (7,'lettuce','green','leafy'),( 8,'brussels sprout','green','leafy'),
       (9,'spinach','green','leafy'), (10,'pumpkin','orange','solid'),
       (11,'cucumber','green','solid'), (12,'bell pepper','green','solid'),
       (13,'squash','yellow','squishy'), (14,'canteloupe','orange','squishy'),
          (15,'onion','white','solid'), (16,'garlic','white','solid')
GO
SELECT  name, type_desc, is_unique
FROM    sys.indexes
WHERE   object_id('produce.vegetable') = object_id
GO
DROP INDEX Xproduce_vegetable_consistency ON produce.vegetable
GO
---------------------------------------------------------------------------
-- Indexes Overview; Basic Index Usage Patterns; Using Clustered Indexes
---------------------------------------------------------------------------

SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   produce.vegetable
GO
SET SHOWPLAN_TEXT OFF
GO

SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId = 4
GO
SET SHOWPLAN_TEXT OFF
GO

SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId in (1,4)
GO
SET SHOWPLAN_TEXT OFF
GO
---------------------------------------------------------------------------
-- Indexes Overview; Basic Index Usage Patterns; Using Nonclustered Indexes
---------------------------------------------------------------------------
SELECT object_name(i.object_id) as object_name
      , case when i.is_unique = 1 then 'UNIQUE ' else '' end +
                i.type_desc as index_type
      , i.name as index_name
      , user_seeks, user_scans, user_lookups,user_updates
FROM  sys.indexes i 
         left outer join sys.dm_db_index_usage_stats s 
              on i.object_id = s.object_id 
                and i.index_id = s.index_id 
                and database_id = db_id()
WHERE  objectproperty(i.object_id , 'IsUserTable') = 1 
ORDER  BY 1,3
GO
--Used isnull as it is easier if the column can be null
--value you translate to should be impossible for the column
--ProductId is an identity with seed of 1 and increment of 1
--so this should be safe (unless a dba does something weird)
SELECT 1.0/ count(distinct isnull(ProductId,-1)) as density,
            count(distinct isnull(ProductId,-1)) as distinctRowCount,

            1.0/ count(*) as uniqueDensity,
            count(*) as allRowCount
FROM   AdventureWorks2008.Production.WorkOrder
GO

CREATE TABLE testIndex
(
    testIndex int identity(1,1) constraint PKtestIndex primary key,
    bitValue bit,
    filler char(2000) not null default (replicate('A',2000))
)
CREATE INDEX XtestIndex_bitValue on testIndex(bitValue)
go
SET NOCOUNT ON
INSERT INTO testIndex(bitValue)
VALUES (0)
GO 50000 --runs current batch 20000 times in Management Studio.
INSERT INTO testIndex(bitValue)
VALUES (1)
GO 100 --puts 10 rows into table with value 1


SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   testIndex
WHERE  bitValue = 0
GO
SET SHOWPLAN_TEXT OFF
GO


SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   testIndex 
WHERE  bitValue = 1
GO
SET SHOWPLAN_TEXT OFF
GO

UPDATE STATISTICS dbo.testIndex 
DBCC SHOW_STATISTICS('dbo.testIndex', 'XtestIndex_bitValue') 
                                                WITH HISTOGRAM
GO
CREATE INDEX XtestIndex_bitValueOneOnly 
      ON testIndex(bitValue) WHERE bitValue = 1 
GO
UPDATE STATISTICS dbo.testIndex( XtestIndex_bitValueOneOnly)
DBCC SHOW_STATISTICS('dbo.testIndex', 'XtestIndex_bitValueOneOnly') 
                                                WITH HISTOGRAM

SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   testIndex 
WHERE  bitValue = 1
GO
SET SHOWPLAN_TEXT OFF
GO

---------------------------------------------------------------------------
-- Indexes Overview; Indexing and Multiple Columns; Composite Indexes
---------------------------------------------------------------------------

SET SHOWPLAN_TEXT ON
GO
SELECT vegetableId, name, color, consistency 
FROM  produce.vegetable
WHERE color = 'green'
  and consistency = 'crunchy'

GO
SET SHOWPLAN_TEXT OFF
GO

SELECT COUNT(Distinct color) as color,
       COUNT(Distinct consistency) as consistency
FROM   produce.vegetable
GO

CREATE INDEX Xproduce_vegetable_consistencyAndColor
         ON produce.vegetable(consistency, color)


SET SHOWPLAN_TEXT ON
GO
SELECT vegetableId, name, color, consistency 
FROM  produce.vegetable
WHERE color = 'green'
  and consistency = 'crunchy'

GO
SET SHOWPLAN_TEXT OFF
GO

---------------------------------------------------------------------------
-- Indexes Overview; Indexing and Multiple Columns; Covering Indexes
---------------------------------------------------------------------------

SET SHOWPLAN_TEXT ON
GO
select name, color
from produce.vegetable
where color = 'green'

GO
SET SHOWPLAN_TEXT OFF
GO

DROP INDEX Xproduce_vegetable_color ON produce.vegetable
CREATE INDEX Xproduce_vegetable_color ON produce.vegetable(color) INCLUDE (name)
GO


SET SHOWPLAN_TEXT ON
GO
select name, color
from produce.vegetable
where color = 'green'

GO
SET SHOWPLAN_TEXT OFF
GO
---------------------------------------------------------------------------
-- Indexes Overview; Indexing and Multiple Columns; Multiple Indexes
---------------------------------------------------------------------------

CREATE INDEX Xproduce_vegetable_consistency ON produce.vegetable(consistency)
--existing index repeated as a reminder
--CREATE INDEX Xvegetable_color ON produce.vegetable(color) INCLUDE (name)
go
SET SHOWPLAN_TEXT ON
GO
SELECT consistency, color
FROM   produce.vegetable with (index=Xproduce_vegetable_color,
                             index=Xproduce_vegetable_consistency)
WHERE  color = 'green'
 and   consistency = 'leafy'
GO
SET SHOWPLAN_TEXT OFF
GO

---------------------------------------------------------------------------
-- Indexes Overview; Indexing and Multiple Columns; Multiple Indexes
---------------------------------------------------------------------------

SET SHOWPLAN_TEXT ON
GO
SELECT maritalStatus, hiredate
FROM   Adventureworks2008.HumanResources.Employee
ORDER BY maritalStatus ASC, hireDate DESC

GO
SET SHOWPLAN_TEXT OFF
GO

 CREATE INDEX Xemployee_maritalStatus_hireDate ON 
       Adventureworks2008.HumanResources.Employee (maritalStatus,hiredate)
GO

SET SHOWPLAN_TEXT ON
GO
SELECT maritalStatus, hiredate
FROM   Adventureworks2008.HumanResources.Employee
ORDER BY maritalStatus ASC, hireDate DESC

GO
SET SHOWPLAN_TEXT OFF
GO
DROP INDEX Xemployee_maritalStatus_hireDate ON 
        Adventureworks2008.HumanResources.Employee
GO
CREATE INDEX Xemployee_maritalStatus_hireDate ON 
    AdventureWorks2008.HumanResources.Employee(maritalStatus ASC,hiredate DESC)
GO
SET SHOWPLAN_TEXT ON
GO
SELECT maritalStatus, hiredate
FROM   Adventureworks2008.HumanResources.Employee
ORDER BY maritalStatus ASC, hireDate DESC

GO
SET SHOWPLAN_TEXT OFF
GO

---------------------------------------------------------------------------
-- Indexes Overview; Nonclustered Indexes on a Heap
---------------------------------------------------------------------------
ALTER TABLE produce.vegetable
    DROP CONSTRAINT PKproduce_vegetable

ALTER TABLE produce.vegetable
    ADD CONSTRAINT PKproduce_vegetable PRIMARY KEY NONCLUSTERED (vegetableID)
GO

SET SHOWPLAN_TEXT ON
GO
SELECT *
FROM   produce.vegetable
WHERE  vegetableId = 4
GO
SET SHOWPLAN_TEXT OFF
GO

---------------------------------------------------------------------------
-- Advanced Index Usage Scenarios; Indexed Views  
---------------------------------------------------------------------------
USE AdventureWorks2008
GO
CREATE VIEW Production.ProductAverageSales
WITH SCHEMABINDING
AS
SELECT Product.productNumber,
       SUM(SalesOrderDetail.lineTotal) as totalSales,
       COUNT_BIG(*) as countSales
FROM   Production.Product as Product
          JOIN Sales.SalesOrderDetail as SalesOrderDetail
                 ON product.ProductID=SalesOrderDetail.ProductID
GROUP  BY Product.productNumber
GO


SET SHOWPLAN_TEXT ON
GO
SELECT productNumber, totalSales, countSales
FROM   Production.ProductAverageSales
GO
SET SHOWPLAN_TEXT OFF
GO

CREATE UNIQUE CLUSTERED INDEX XPKProductAverageSales on
                      Production.ProductAverageSales(productNumber)


SET SHOWPLAN_TEXT ON
GO
SELECT productNumber, totalSales, countSales
FROM   Production.ProductAverageSales
GO
SET SHOWPLAN_TEXT OFF
GO

SET SHOWPLAN_TEXT ON
GO
SELECT Product.productNumber, sum(SalesOrderDetail.lineTotal) / COUNT(*)
FROM   Production.Product as Product
          JOIN Sales.SalesOrderDetail as SalesOrderDetail
                 ON product.ProductID=SalesOrderDetail.ProductID
GROUP  BY Product.productNumber
GO
SET SHOWPLAN_TEXT OFF
GO

SET SHOWPLAN_TEXT ON
GO

GO
SET SHOWPLAN_TEXT OFF
GO

