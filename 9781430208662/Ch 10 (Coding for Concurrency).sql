---------------------------------------------------------------------------------------------
-- Query Optimization Basics
---------------------------------------------------------------------------------------------

SELECT  productModel.name as productModel,
        product.name as productName
FROM    AdventureWorks2008.production.product as product
          join AdventureWorks2008.production.productModel as productModel
                 on productModel.productModelId = product.productModelId
WHERE   product.name like '%glove%'


---------------------------------------------------------------------------------------------
-- Transactions; Transaction Syntax; Basic Transactions
---------------------------------------------------------------------------------------------

BEGIN TRANSACTION one
ROLLBACK TRANSACTION one
GO
BEGIN TRANSACTION one
BEGIN TRANSACTION two
ROLLBACK TRANSACTION two
GO
ROLLBACK
GO

SELECT  recovery_model_desc
FROM    sys.databases
WHERE   name = 'AdventureWorks2008'
GO

USE Master
GO

ALTER DATABASE AdventureWorks2008
      SET RECOVERY FULL
GO
EXEC sp_addumpdevice 'disk', 'TestAdventureWorks2008', 'C:\Temp\AdventureWorks2008.bak'
EXEC sp_addumpdevice 'disk', 'TestAdventureWorks2008Log',
                              'C:\Temp\AdventureWorks2008Log.bak' 
GO
BACKUP DATABASE AdventureWorks2008 TO TestAdventureWorks2008
GO

USE AdventureWorks2008
GO
SELECT count(*)
FROM   SALES.SalesTaxRate

BEGIN TRANSACTION Test WITH MARK 'Test'
DELETE SALES.SalesTaxRate
COMMIT TRANSACTION
GP
BACKUP LOG AdventureWorks2008  to TestAdventureWorks2008Log
GO

USE Master
GO
RESTORE DATABASE AdventureWorks2008 FROM TestAdventureWorks2008 
                                                   WITH REPLACE, NORECOVERY
go
RESTORE LOG AdventureWorks2008 FROM TestAdventureWorks2008Log
                                                   WITH STOPBEFOREMARK = 'Test'
GO
USE AdventureWorks2008
GO
SELECT count(*)
FROM   SALES.SalesTaxRate

---------------------------------------------------------------------------------------------
-- Transactions; Transaction Syntax; Basic Transactions
---------------------------------------------------------------------------------------------
Use tempdb
go
SELECT @@TRANCOUNT AS zeroDeep
BEGIN TRANSACTION
SELECT @@TRANCOUNT AS oneDeep
GO

BEGIN TRANSACTION
SELECT @@TRANCOUNT AS twoDeep
COMMIT TRANSACTION --commits very last transaction started with BEGIN TRANSACTION
SELECT @@TRANCOUNT AS oneDeep
GO

COMMIT TRANSACTION
SELECT @@TRANCOUNT AS zeroDeep

GO


BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
BEGIN TRANSACTION
SELECT @@trancount as InTran
ROLLBACK TRANSACTION
SELECT @@trancount as OutTran

GO

COMMIT TRANSACTION
GO

---------------------------------------------------------------------------------------------
-- Transactions; Transaction Syntax; savepoints
---------------------------------------------------------------------------------------------
GO
CREATE SCHEMA arts
CREATE TABLE arts.performer
(
    performerId int identity,
    name varchar(100)
 )
GO
BEGIN TRANSACTION
INSERT INTO arts.performer(name) VALUES ('Elvis Costello')

SAVE TRANSACTION savePoint

INSERT INTO arts.performer(name) VALUES ('Air Supply')

--don't insert Air Supply, yuck! ...
ROLLBACK TRANSACTION savePoint

COMMIT TRANSACTION

SELECT *
FROM arts.performer
GO

---------------------------------------------------------------------------------------------
-- Transactions; Compiled SQL Server Code; Stored Procedures
---------------------------------------------------------------------------------------------
CREATE PROCEDURE tranTest
AS
BEGIN
  SELECT @@TRANCOUNT AS trancount

  BEGIN TRANSACTION
  ROLLBACK TRANSACTION
END
GO
BEGIN TRANSACTION
EXECUTE tranTest
COMMIT TRANSACTION
GO

ALTER PROCEDURE tranTest
AS
BEGIN
  --gives us a unique savepoint name, trim it to 125 characters if the
  --user named the procedure really really large, to allow for nestlevel
  DECLARE @savepoint nvarchar(128) = 
      cast(object_name(@@procid) AS nvarchar(125)) +
                         cast(@@nestlevel AS nvarchar(3))

  BEGIN TRANSACTION
  SAVE TRANSACTION @savepoint
    --do something here
  ROLLBACK TRANSACTION @savepoint
  COMMIT TRANSACTION
END
GO

BEGIN TRANSACTION
EXECUTE tranTest
COMMIT TRANSACTION
GO


ALTER PROCEDURE tranTest
AS
BEGIN
  --gives us a unique savepoint name, trim it to 125
  --characters if the user named it really large
  DECLARE @savepoint nvarchar(128) = 
               cast(object_name(@@procid) AS nvarchar(125)) +
                                      cast(@@nestlevel AS nvarchar(3))
  --get initial entry level, so we can do a rollback on a doomed transaction
  DECLARE @entryTrancount int = @@trancount

  BEGIN TRY
    BEGIN TRANSACTION
    SAVE TRANSACTION @savepoint

    --do something here
    RAISERROR ('Invalid Operation',16,1)

    COMMIT TRANSACTION
  END TRY
  BEGIN CATCH 

   --if the tran is doomed, and the entryTrancount was 0
   --we have to rollback    
    IF xact_state()= -1 and @entryTrancount = 0 
        rollback transaction
    --otherwise, we can still save the other activities in the
    --transaction.
    ELSE IF xact_state() = 1 --transaction not doomed, but open
       BEGIN
         ROLLBACK TRANSACTION @savepoint
         COMMIT TRANSACTION
       END

    DECLARE @ERRORmessage nvarchar(4000)
    SET @ERRORmessage = 'Error occurred in procedure ''' + object_name(@@procid)
                        + ''', Original Message: ''' + ERROR_MESSAGE() + ''''
    RAISERROR (@ERRORmessage,16,1)
    RETURN -100
  END CATCH
END
GO

CREATE SCHEMA menu
CREATE TABLE menu.foodItem
(
    foodItemId int not null IDENTITY(1,1)
        CONSTRAINT PKmenu_foodItem PRIMARY KEY,
    name varchar(30) not null
        CONSTRAINT AKmenu_foodItem_name UNIQUE,
    description varchar(60) not null,
        CONSTRAINT CHKmenu_foodItem_name CHECK (name <> ''),
        CONSTRAINT CHKmenu_foodItem_description CHECK (description <> '')
)
GO

CREATE PROCEDURE menu.foodItem$insert
(
    @name   varchar(30),
    @description varchar(60),
    @newFoodItemId int = null output --we will send back the new id here
)
AS
BEGIN
  SET NOCOUNT ON

  --gives us a unique savepoint name, trim it to 125
  --characters if the user named it really large
  DECLARE @savepoint nvarchar(128) = 
               cast(object_name(@@procid) AS nvarchar(125)) +
                                      cast(@@nestlevel AS nvarchar(3))
  --get initial entry level, so we can do a rollback on a doomed transaction
  DECLARE @entryTrancount int = @@trancount

  BEGIN TRY
    BEGIN TRANSACTION
    SAVE TRANSACTION @savepoint

    INSERT INTO menu.foodItem(name, description)
    VALUES (@name, @description)

    SET @newFoodItemId = scope_identity() --if you use an instead of trigger
                                          --you will have to use name as a key
                                          --to do the identity "grab" in a SELECT
                                          --query

    COMMIT TRANSACTION
  END TRY
  BEGIN CATCH 

   --if the tran is doomed, and the entryTrancount was 0
   --we have to rollback    
    IF xact_state()= -1 and @entryTrancount = 0 
        rollback transaction
    --otherwise, we can still save the other activities in the
    --transaction.
    ELSE IF xact_state() = 1 --transaction not doomed, but open
       BEGIN
         ROLLBACK TRANSACTION @savepoint
         COMMIT TRANSACTION
       END

    DECLARE @ERRORmessage nvarchar(4000)
    SET @ERRORmessage = 'Error 0ccurred in procedure ''' + object_name(@@procid)
                        + ''', Original Message: ''' + ERROR_MESSAGE() + ''''
    RAISERROR (@ERRORmessage,16,1)
    RETURN -100
  END CATCH
END
GO

DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Burger',
                                        @description = 'Mmmm Burger',
                                        @newFoodItemId = @foodItemId output
SELECT  @retval as returnValue
IF @retval >= 0
    SELECT  foodItemId, name, description
    FROM    menu.foodItem
    where   foodItemId = @foodItemId
GO

DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger',
                                        @description = '',
                                        @newFoodItemId = @foodItemId output
SELECT  @retval as returnValue
IF @retval >= 0
    SELECT  foodItemId, name, description
    FROM    menu.foodItem
    where   foodItemId = @foodItemId
GO


---------------------------------------------------------------------------------------------
-- Transactions; Compiled SQL Server Code; Triggers
---------------------------------------------------------------------------------------------

CREATE TRIGGER menu.foodItem$InsertTrigger
ON menu.foodItem
AFTER INSERT
AS
BEGIN
   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return
  
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
        --[validation blocks][validation section]
        RAISERROR ('FoodItem''s cannot be done that way',16,1)
       --[modification blocks][modification section]
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END

GO

ALTER PROCEDURE menu.foodItem$insert --modded error handler to return positional output
(
    @name   varchar(30),
    @description varchar(60),
    @newFoodItemId int = null output --we will send back the new id here
)
AS
BEGIN
  SET NOCOUNT ON

  --gives us a unique savepoint name, trim it to 125
  --characters if the user named it really large
  DECLARE @savepoint nvarchar(128) = 
               cast(object_name(@@procid) AS nvarchar(125)) +
                                      cast(@@nestlevel AS nvarchar(3))
  --get initial entry level, so we can do a rollback on a doomed transaction
  DECLARE @entryTrancount int = @@trancount

  BEGIN TRY
    BEGIN TRANSACTION
    SAVE TRANSACTION @savepoint

    INSERT INTO menu.foodItem(name, description)
    VALUES (@name, @description)

    SET @newFoodItemId = scope_identity() --if you use an instead of trigger
                                          --you will have to use name as a key
                                          --to do the identity "grab" in a SELECT
                                          --query

    COMMIT TRANSACTION
  END TRY
  BEGIN CATCH 
   SELECT 'In error handler'

   --if the tran is doomed, and the entryTrancount was 0
   --we have to rollback    
    IF xact_state()= -1 and @entryTrancount = 0 
     begin  
        SELECT 'Transaction Doomed'
        ROLLBACK TRANSACTION
     end
    --otherwise, we can still save the other activities in the
    --transaction.
    ELSE IF xact_state() = 1 --transaction not doomed, but open
       BEGIN
         SELECT 'Savepoint Rollback'
         ROLLBACK TRANSACTION @savepoint
         COMMIT TRANSACTION
       END


    DECLARE @ERRORmessage nvarchar(4000)
    SET @ERRORmessage = 'Error 0ccurred in procedure ''' + object_name(@@procid)
                        + ''', Original Message: ''' + ERROR_MESSAGE() + ''''
    RAISERROR (@ERRORmessage,16,1)
    RETURN -100
  END CATCH
END
GO

DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger',
                                        @description = '',
                                        @newFoodItemId = @foodItemId output
SELECT @retval
GO

DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger',
                                        @description = 'Yummy Big Burger',
                                        @newFoodItemId = @foodItemId output
SELECT @retval
GO

ALTER TRIGGER menu.foodItem$InsertTrigger
ON menu.foodItem
AFTER INSERT
AS
BEGIN
   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return
  
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   RAISERROR ('FoodItem''s cannot be done that way',16,1)
 
END
GO

DECLARE @foodItemId int, @retval int
EXECUTE @retval = menu.foodItem$insert  @name ='Big Burger',
                                        @description = 'Yummy Big Burger',
                                        @newFoodItemId = @foodItemId output
SELECT @retval
GO

----------------------------------------------------------------------------------
--SQL Server Concurrency Controls; Isolation Levels
----------------------------------------------------------------------------------
GO
CREATE TABLE dbo.testIsolationLevel
(
   testIsolationLevelId int identity(1,1)
                CONSTRAINT PKtestIsolationLevel PRIMARY KEY,
   value varchar(10)
)

INSERT dbo.testIsolationLevel(value)
VALUES ('Value1'),
       ('Value2')
GO

SELECT  case transaction_isolation_level
            when 1 then 'Read Uncomitted'      when 2 then 'Read Committed'
            when 3 then 'Repeatable Read'      when 4 then 'Serializable'
            when 5 then 'Snapshot'             else 'Unspecified'
         end
FROM    sys.dm_exec_sessions 
WHERE  session_id = @@spid
GO
----------------------------------------------------------------------------------
--SQL Server Concurrency Controls; Isolation Levels; READ UNCOMMITTED
----------------------------------------------------------------------------------

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL READ COMMITTED --this is the default, just 
                                               --setting for emphasis
BEGIN TRANSACTION
INSERT INTO dbo.testIsolationLevel(value)
VALUES('Value3')
GO

--CONNECTION B
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SELECT *
FROM dbo.testIsolationLevel
GO
--CONNECTION A

COMMIT TRANSACTION
GO

----------------------------------------------------------------------------------
--SQL Server Concurrency Controls; Isolation Levels; READ COMMITTED
----------------------------------------------------------------------------------

--CONNECTION A

SET TRANSACTION ISOLATION LEVEL READ COMMITTED

BEGIN TRANSACTION
SELECT * FROM dbo.testIsolationLevel
GO
--CONNECTION B

DELETE FROM dbo.testIsolationLevel
WHERE testIsolationLevelId = 1
GO

--CONNECTION A
SELECT *
FROM dbo.testIsolationLevel
COMMIT TRANSACTION

GO
----------------------------------------------------------------------------------
--SQL Server Concurrency Controls; Isolation Levels; REPEATABLE READ
----------------------------------------------------------------------------------
--CONNECTION A

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ

BEGIN TRANSACTION
SELECT * FROM dbo.testIsolationLevel
GO
--CONNECTION B

INSERT INTO dbo.testIsolationLevel(value)
VALUES ('Value4')
GO
--CONNECTION B
DELETE FROM dbo.testIsolationLevel
WHERE value = 'Value3'

GO
--CONNECTION A

SELECT * FROM dbo.testIsolationLevel
COMMIT TRANSACTION

GO

----------------------------------------------------------------------------------
--SQL Server Concurrency Controls; Isolation Levels; SERIALIZABLE
----------------------------------------------------------------------------------
--CONNECTION A

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

BEGIN TRANSACTION
SELECT * FROM dbo.testIsolationLevel
GO
--CONNECTION B

INSERT INTO dbo.testIsolationLevel(value)
VALUES ('Value5')
GO
--CONNECTION A

SELECT * FROM dbo.testIsolationLevel
COMMIT TRANSACTION
GO
----------------------------------------------------------------------------------
--SQL Server Concurrency Controls; Isolation Levels; SNAPSHOT
----------------------------------------------------------------------------------
ALTER DATABASE tempDb
SET ALLOW_SNAPSHOT_ISOLATION ON
GO
--CONNECTION A

SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRANSACTION
SELECT * from dbo.testIsolationLevel
GO
--CONNECTION B

SET TRANSACTION ISOLATION LEVEL READ COMMITTED
INSERT INTO dbo.testIsolationLevel(value)
VALUES ('Value6')

GO

--CONNECTION B

DELETE FROM dbo.testIsolationLevel
WHERE  value = 'Value4'
GO

--CONNECTION A

UPDATE  dbo.testIsolationLevel
SET     value = 'Value2-mod'
WHERE   testIsolationLevelId = 2
GO

--CONNECTION A

COMMIT TRANSACTION
SELECT * from dbo.testIsolationLevel
GO



--CONNECTION A
SET TRANSACTION ISOLATION LEVEL SNAPSHOT
BEGIN TRANSACTION

--touch the data
SELECT * FROM dbo.testIsolationLevel

GO
--CONNECTION B
SET TRANSACTION ISOLATION LEVEL READ COMMITTED --any will do

UPDATE dbo.testIsolationLevel
SET    value = 'Value5-mod'
WHERE  testIsolationLevelId = 5 --might be different in yours
GO

--CONNECTION A
UPDATE dbo.testIsolationLevel
SET   value = 'Value5-mod'
WHERE testIsolationLevelId = 5 --might be different in yours
GO

----------------------------------------------------------------------------------
--Coding for Integrity and Concurrency; Pessimistic Locking
----------------------------------------------------------------------------------

--CONNECTION A

BEGIN TRANSACTION
   DECLARE @result int
   EXEC @result = sp_getapplock @Resource = 'invoiceId=1', @LockMode = 'Exclusive'
   SELECT @result
GO

--CONNECTION B
BEGIN TRANSACTION
   DECLARE @result int
   EXEC @result = sp_getapplock @Resource = 'invoiceId=1', @LockMode = 'Exclusive'
   PRINT @result
GO

--CONNECTION B

BEGIN TRANSACTION
SELECT  APPLOCK_TEST('public','invoiceId=1','Exclusive','Transaction')
                                                        as CanTakeLock
ROLLBACK TRANSACTION
GO

--CLEANUP on Connection A
ROLLBACK TRANSACTION
GO

create table applock
(
    applockId int primary key,  --the value that we will be generating 
                                --with the procedure
    connectionId int,           --holds the spid of the connection so you can 
                                --who creates the row
    insertTime datetime default (getdate()) --the time the row was created, so 
                                             --you can see the progression
)

GO

create procedure applock$test
(
    @connectionId int,
    @useApplockFlag bit = 1,
    @stepDelay varchar(10) = '00:00:00'
) as
set nocount on
begin try
    begin transaction
        declare @retval int = 1
        if @useApplockFlag = 1 --turns on and off the applock for testing
            begin
                exec @retval = sp_getapplock @Resource = 'applock$test', 
                                                    @LockMode = 'exclusive'; 
                if @retval < 0 
                    begin
                        declare @errorMessage nvarchar(200)
                        set @errorMessage = case @retval
                                    when -1 then 'Applock request timed out.'
                                    when -2 then 'Applock request canceled.'
                                    when -3 then 'Applock involved in deadlock'
                                else 'Parameter validation or other call error.'
                                             end
                        raiserror (@errorMessage,16,1)
                    end
            end

    --get the next primary key value
    declare @applockId int    
    set @applockId = coalesce((select max(applockId) from applock),0) + 1 

    --delay for parameterized amount of time to slow down operations 
    --and guarantee concurrency problems
    waitfor delay @stepDelay 

    --insert the next value
    insert into applock(applockId, connectionId)
    values (@applockId, @connectionId) 

    --won't have much effect on this code, since the row will now be 
    --exclusively locked, and the max will need to see the new row to 
    --be of any effect.
    exec @retval = sp_releaseapplock @Resource = 'applock$test' 

    --this releases the applock too
    commit transaction
end try
begin catch
    --if there is an error, rollback and display it.
    if @@trancount > 0
        rollback transaction
        select cast(error_number() as varchar(10)) + ':' + error_message()
end catch 

GO
waitfor time '23:46' --set for a time to run so multiple batches 
                            --can simultaneously execute
go
exec applock$test @@spid, 1 -- <1=use applock, 0 = don't use applock>,
            ,'00:00:00.001'--'delay in hours:minutes:seconds.parts of seconds'
go 10000 --runs the batch 10000 times in SSMS
GO


----------------------------------------------------------------------------------
--Coding for Integrity and Concurrency; Optimistic Locking; Adding Optimistic Lock Columns
----------------------------------------------------------------------------------
GO
CREATE SCHEMA hr
CREATE TABLE hr.person
(
     personId int IDENTITY(1,1) CONSTRAINT PKperson primary key,
     firstName varchar(60) NOT NULL,
     middleName varchar(60) NOT NULL,
     lastName varchar(60) NOT NULL,

     dateOfBirth date NOT NULL,
     rowLastModifyTime datetime NOT NULL
         CONSTRAINT DFLTperson_rowLastModifyTime default getdate(),
     rowModifiedByUserIdentifier nvarchar(128) NOT NULL
         CONSTRAINT DFLTperson_rowModifiedByUserIdentifier default suser_sname()

)
GO

CREATE TRIGGER hr.person$InsteadOfUpdate
ON hr.person
INSTEAD OF UPDATE AS
BEGIN

    --stores the number of rows affected
   DECLARE @rowsAffected int = @@rowcount,
           @msg varchar(2000) = ''    --used to hold the error message

      --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --remember to update ALL columns when building instead of triggers
          UPDATE hr.person
          SET    firstName = inserted.firstName,
                 middleName = inserted.middleName,
                 lastName = inserted.lastName,
                 dateOfBirth = inserted.dateOfBirth,
                 rowLastModifyTime = default, -- set the value to the default
                 rowModifiedByUserIdentifier = default 
          FROM   hr.person                              
                     JOIN inserted
                             on hr.person.personId = inserted.personId
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                 ROLLBACK TRANSACTION

              --EXECUTE dbo.errorLog$insert

              DECLARE @ERROR_MESSAGE varchar(8000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END

GO

INSERT INTO hr.person (firstName, middleName, lastName, dateOfBirth)
VALUES ('Paige','O','Anxtent','19391212')

SELECT *
FROM   hr.person
GO

UPDATE hr.person
SET     middleName = 'Ona'
WHERE   personId = 1

SELECT rowLastModifyTime
FROM   hr.person

GO

ALTER TABLE hr.person
  ADD rowversion rowversion
GO
SELECT personId, rowversion
FROM   hr.person
GO
UPDATE  hr.person
SET     firstName = 'Paige' --no actual change occurs
WHERE   personId = 1
Go
SELECT personId, rowversion
FROM   hr.person
GO

----------------------------------------------------------------------------------
--Coding for Integrity and Concurrency; Optimistic Locking; Coding for Row-Level Optimistic Locking
----------------------------------------------------------------------------------
GO
UPDATE  hr.person
SET     firstName = 'Headley'
WHERE   personId = 1  --include the key
  and   firstName = 'Paige'
  and   middleName = 'ona'
  and   lastName = 'Anxtent'
  and   dateOfBirth = '19391212'
GO
UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1  --include the key
  and   rowLastModifyTime = '2005-07-30 00:28:28.397'
GO
UPDATE  hr.person
SET     firstName = 'Fred'
WHERE   personId = 1
  and   rowversion = 0x00000000000007D3
GO
DELETE FROM hr.person
WHERE   personId = 1
  And   rowversion = 0x00000000000007D3
GO
----------------------------------------------------------------------------------
--Coding for Integrity and Concurrency; Optimistic Locking; Logical Unit of Work
----------------------------------------------------------------------------------

CREATE SCHEMA invoicing
go
--leaving off who invoice is for
CREATE TABLE invoicing.invoice
(
     invoiceId int IDENTITY(1,1),
     number varchar(20) NOT NULL,
     objectVersion rowversion not null,
     constraint PKinvoicing_invoice primary key (invoiceId)
)
--also forgetting what product that the line item is for
CREATE TABLE invoicing.invoiceLineItem

(
     invoiceLineItemId int NOT NULL,
     invoiceId int NULL,
     itemCount int NOT NULL,
     cost int NOT NULL,
      constraint PKinvoicing_invoiceLineItem primary key (invoiceLineItemId),
      constraint FKinvoicing_invoiceLineItem$references$invoicing_invoice
            foreign key (invoiceId) references invoicing.invoice(invoiceId)
)
GO

CREATE PROCEDURE invoiceLineItem$del
(
    @invoiceId int, --we pass this because the client should have it
                    --with the invoiceLineItem row
    @invoiceLineItemId int,
    @objectVersion rowversion
) as
  BEGIN
    --gives us a unique savepoint name, trim it to 125
    --characters if the user named it really large
    DECLARE @savepoint nvarchar(128) = 
                          cast(object_name(@@procid) AS nvarchar(125)) +
                                         cast(@@nestlevel AS nvarchar(3))
    --get initial entry level, so we can do a rollback on a doomed transaction
    DECLARE @entryTrancount int = @@trancount

    BEGIN TRY
        BEGIN TRANSACTION
        SAVE TRANSACTION @savepoint

        UPDATE  invoice
        SET     number = number
        WHERE   invoiceId = @invoiceId
          And   objectVersion = @objectVersion

        DELETE  invoiceLineItem
        FROM    invoiceLineItem
        WHERE   invoiceLineItemId = @invoiceLineItemId

        COMMIT TRANSACTION

    END TRY
    BEGIN CATCH

        --if the tran is doomed, and the entryTrancount was 0
        --we have to rollback    
        IF xact_state()= -1 and @entryTrancount = 0 
            rollback transaction
        --otherwise, we can still save the other activities in the
       --transaction.
       ELSE IF xact_state() = 1 --transaction not doomed, but open
         BEGIN
             ROLLBACK TRANSACTION @savepoint
             COMMIT TRANSACTION
         END

    DECLARE @ERRORmessage nvarchar(4000)
    SET @ERRORmessage = 'Error occurred in procedure ''' + 
          object_name(@@procid) + ''', Original Message: ''' 
          + ERROR_MESSAGE() + ''''
    RAISERROR (@ERRORmessage,16,1)
    RETURN -100

     END CATCH
 END

