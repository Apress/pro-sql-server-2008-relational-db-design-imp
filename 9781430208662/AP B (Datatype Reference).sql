Use tempdb
go
--------------------------------------------------------------------------------
-- Integer Values - Decimal Values - decimal (or numeric)
--------------------------------------------------------------------------------

DECLARE @testvar decimal(3,1)
SELECT @testvar = -10.155555555
SELECT @testvar
GO
SET NUMERIC_ROUNDABORT ON
DECLARE @testvar decimal(3,1)
SELECT @testvar = -10.155555555
GO
SET NUMERIC_ROUNDABORT OFF
GO
--------------------------------------------------------------------------------
-- Integer Values - Decimal Values - Money Types
--------------------------------------------------------------------------------

CREATE TABLE dbo.testMoney
(
    moneyValue money
)
go

INSERT INTO dbo.testMoney
VALUES ($100)
INSERT INTO dbo.testMoney
VALUES (100)
INSERT INTO dbo.testMoney
VALUES (£100)
GO
SELECT * FROM dbo.testMoney
GO

DECLARE @money1 money,  @money2 money

SET    @money1 = 1.00
SET    @money2 = 800.00
SELECT cast(@money1/@money2 as money)


DECLARE @decimal1 decimal(19,4), @decimal2 decimal(19,4)
SET     @decimal1 = 1.00
SET     @decimal2 = 800.00
SELECT  cast(@decimal1/@decimal2 as decimal(19,4))

SELECT  @money1/@money2
SELECT  @decimal1/@decimal2

GO

--------------------------------------------------------------------------------
-- Date and Time Data - datetimeoffset [(precision)]
--------------------------------------------------------------------------------

DECLARE @LocalTime DateTimeOffset
SET @LocalTime = SYSDATETIMEOFFSET()
SELECT @LocalTime
SELECT SWITCHOFFSET(@LocalTime, '+00:00') As UTCTime
GO

--------------------------------------------------------------------------------
-- Date and Time Data - Discussion on All Date Types - date functions
--------------------------------------------------------------------------------

DECLARE @time1 date = '20081231',
        @time2 date = '20090102'
SELECT DATEDIFF(yy,@time1,@time2)
GO
DECLARE @time1 date = '20080101',
        @time2 date = '20091231'
SELECT DATEDIFF(yy,@time1,@time2)

--------------------------------------------------------------------------------
-- Date and Time Data - Discussion on All Date Types - Representing Dates in Text Formats
--------------------------------------------------------------------------------

select cast ('2009-01-01' as smalldatetime) as dateOnly
select cast('2009-01-01 14:23:00.003' as datetime) as withTime
GO
select cast ('20090101' as smalldatetime) as dateOnly
select cast('2009-01-01T14:23:00.120' as datetime) as withTime
GO

--------------------------------------------------------------------------------
-- Character Strings - Char
--------------------------------------------------------------------------------

SELECT number, CHAR(number)
FROM   utility.sequence
WHERE  number >=0 and number <= 255

--------------------------------------------------------------------------------
-- Character Strings - varchar(max) 
--------------------------------------------------------------------------------

DECLARE @value varchar(max)
SET @value = replicate('X',8000) + replicate('X',8000)
SELECT len(@value)

GO

DECLARE @value varchar(max)
SET @value = replicate(cast('X' as varchar(max)),16000)
SELECT len(@value)

GO

--------------------------------------------------------------------------------
-- Binary Data - binary
--------------------------------------------------------------------------------
declare @value binary(10)
set @value = cast('helloworld' as binary(10))
select @value

select cast(0x68656C6C6F776F726C64 as varchar(10))

declare @value binary(10)
set @value = cast('HELLOWORLD' as binary(10))
select @value
GO

--------------------------------------------------------------------------------
-- Other Datatypes - rowversion
--------------------------------------------------------------------------------

SET nocount on
CREATE TABLE testRowversion
(
   value   varchar(20) NOT NULL,
   auto_rv   rowversion NOT NULL
)

INSERT INTO testRowversion (value) values ('Insert')

SELECT value, auto_rv FROM testRowversion
UPDATE testRowversion
SET value = 'First Update'

SELECT value, auto_rv from testRowversion
UPDATE testRowversion
SET value = 'Last Update'

SELECT value, auto_rv FROM testRowversion
GO

--------------------------------------------------------------------------------
-- Other Datatypes - uniqueidentifier
--------------------------------------------------------------------------------

DECLARE @guidVar uniqueidentifier
SET @guidVar = newid()

SELECT @guidVar as guidVar
GO

CREATE TABLE guidPrimaryKey
(
   guidPrimaryKeyId uniqueidentifier NOT NULL rowguidcol DEFAULT newId(),
   value varchar(10)
)
GO
INSERT INTO guidPrimaryKey(value)
VALUES ('Test')
GO
SELECT *
FROM guidPrimaryKey
GO

DROP TABLE guidPrimaryKey
go
CREATE TABLE guidPrimaryKey
(
   guidPrimaryKeyId uniqueidentifier NOT NULL
                    rowguidcol DEFAULT newSequentialId(),
   value varchar(10)
)
GO
INSERT INTO guidPrimaryKey(value)
SELECT 'Test'
UNION ALL
SELECT 'Test1'
UNION ALL
SELECT 'Test2'
GO

SELECT *
FROM guidPrimaryKey

GO

--------------------------------------------------------------------------------
-- Other Datatypes - table - table variables
--------------------------------------------------------------------------------

DECLARE @tableVar TABLE
(
   id int IDENTITY PRIMARY KEY,
   value varchar(100)
)
INSERT INTO @tableVar (value)
VALUES ('This is a cool test')

SELECT id, value
FROM @tableVar
GO

CREATE FUNCTION table$testFunction
(
   @returnValue varchar(100)

) 
RETURNS @tableVar table
(
     value varchar(100)
)
AS
BEGIN
   INSERT INTO @tableVar (value)
   VALUES (@returnValue)

   RETURN
END
GO
SELECT *
FROM dbo.table$testFunction('testValue')

GO

DECLARE @tableVar TABLE
(
   id int IDENTITY,
   value varchar(100)
)
BEGIN TRANSACTION
    INSERT INTO @tableVar (value)
    VALUES ('This will still be there')  
ROLLBACK TRANSACTION

SELECT id, value
FROM @tableVar
GO

--------------------------------------------------------------------------------
-- Other Datatypes - table - Table Valued Parameters
--------------------------------------------------------------------------------
CREATE TYPE GenericIdList AS TABLE
( 
    Id Int Primary Key
)
GO
DECLARE @ProductIdList GenericIdList

INSERT INTO @productIDList
VALUES (1),(2),(3),(4)

SELECT ProductID, Name, ProductNumber
FROM   AdventureWorks2008.Production.product
         JOIN @productIDList as list
            on Product.ProductID = List.Id
GO

CREATE PROCEDURE product$list
(
    @productIdList GenericIdList READONLY
)
AS 
SELECT ProductID, Name, ProductNumber
FROM   AdventureWorks2008.Production.product
         JOIN @productIDList as list
            on Product.ProductID = List.Id
GO
DECLARE @ProductIdList GenericIdList

INSERT INTO @productIDList
VALUES (1),(2),(3),(4)

EXEC product$list @ProductIdList
GO
--------------------------------------------------------------------------------
-- Other Datatypes - sql_variant
--------------------------------------------------------------------------------
DECLARE @varcharVariant sql_variant
SET @varcharVariant = '1234567890'
SELECT @varcharVariant AS varcharVariant,
   SQL_VARIANT_PROPERTY(@varcharVariant,'BaseType') as baseType,
   SQL_VARIANT_PROPERTY(@varcharVariant,'MaxLength') as maxLength,
   SQL_VARIANT_PROPERTY(@varcharVariant,'Collation') as collation
GO
DECLARE @numericVariant sql_variant
SET @numericVariant = 123456.789
SELECT @numericVariant AS numericVariant,
   SQL_VARIANT_PROPERTY(@numericVariant,'BaseType') as baseType,
   SQL_VARIANT_PROPERTY(@numericVariant,'Precision') as precision,
   SQL_VARIANT_PROPERTY(@numericVariant,'Scale') as scale
