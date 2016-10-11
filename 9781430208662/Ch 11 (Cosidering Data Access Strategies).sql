CREATE DATABASE architectureChapter
GO
use architectureChapter
go
------------------------------------------------------------------------------
-- Ad Hoc SQL; Advantages; Flexibility and Control
------------------------------------------------------------------------------

CREATE SCHEMA sales
GO
CREATE TABLE sales.contact
(
    contactId   int CONSTRAINT PKsales_contact PRIMARY KEY,
    firstName   varchar(30),
    lastName    varchar(30),
    companyName varchar(100),
    salesLevelId  int, --real table would implement as a foreign key
    contactNotes  varchar(max),
    personalNotes varchar(max),
    CONSTRAINT AKsales_contact UNIQUE (firstName, lastName, companyName)
)
GO

SELECT  contactId, firstName, lastName, companyName, salesLevelId,
                right(contactNotes,500) as notesEnd
FROM    sales.contact
GO
SELECT contactId, firstName, lastName, companyName
FROM sales.contact
GO

CREATE TABLE sales.purchase
(
    purchaseId int CONSTRAINT PKsales_purchase PRIMARY KEY,
    amount      numeric(10,2),
    purchaseDate datetime,
    contactId   int
        CONSTRAINT FKsales_contact$hasPurchasesIn$sales_purchase
            REFERENCES sales.contact(contactId)
)
GO

SELECT  contact.contactId, contact.firstName, contact.lastName,
                sales.yearToDateSales, sales.lastSaleDate
FROM   sales.contact as contact
          LEFT OUTER JOIN
             (SELECT contactId,
                     SUM(amount) AS yearToDateSales,
                     MAX(purchaseDate) AS lastSaleDate
              FROM   sales.purchase
              WHERE  purchaseDate >= --the first day of the current year
                         cast(datepart(year,getdate()) as char(4)) + '0101'
              GROUP  by contactId) AS sales
              ON contact.contactId = sales.contactId
WHERE   contact.lastName like 'Johns%'
GO

SELECT  contact.contactId, contact.firstName, contact.lastName
                --,sales.yearToDateSales, sales.lastSaleDate
FROM   sales.contact as contact
--          LEFT OUTER JOIN
  --             (SELECT contactId,
--                     SUM(amount) AS yearToDateSales,
--                     MAX(purchaseDate) AS lastSaleDate
--              FROM   sales.purchase
--             WHERE  purchaseDate >= --the first day of the current year
--                           cast(datepart(year,getdate()) as char(4)) + '0101'
--              GROUP  by contactId) AS sales
--              ON contact.contactId = sales.contactId
WHERE   contact.lastName like 'Johns%'

GO
UPDATE sales.contact
SET    firstName = 'First Name',
       lastName = 'Last Name',
       salesLevelId = 1,
       companyName = 'Company Name',
       contactNotes = 'Notes about the contact',
       personalNotes = 'Notes about the person'
WHERE contactId = 1
GO
UPDATE sales.contact
SET    firstName = 'First Name'
WHERE  contactId = 1
GO
SELECT firstName, lastName, companyName
FROM   sales.contact
WHERE  firstName like 'firstNameValue%'
  AND  lastName like 'lastNamevalue%'
GO
SELECT firstName, lastName, companyName
FROM   sales.contact
WHERE  firstName like '%'
  AND  lastName like 'lastNamevalue%'
GO
SELECT firstName, lastName, companyName
FROM   sales.contact
WHERE  lastName like 'lastNamevalue%'
GO

----------------------------------------------------------------------------
-- Stored Procedures
----------------------------------------------------------------------------

Use AdventureWorks2008
GO
CREATE PROCEDURE person.address$select
(
    @addressLine1 nvarchar(120) = '%',
    @city         nvarchar(60) = '%',
    @state        nchar(3) = '___', --special because it is a char column
    @postalCode   nvarchar(8) = '%'
) AS
--simple procedure to execute a single query
SELECT address.AddressLine1, address.AddressLine2,
        address.City, state.StateProvinceCode, address.PostalCode
FROM   Person.Address as address
         join Person.StateProvince as state
                on address.stateProvinceId = state.stateProvinceId
WHERE  address.AddressLine1 like @addressLine1
  AND  address.City like @city
  AND  state.StateProvinceCode like @state
  AND  address.PostalCode like @postalCode  
GO

----------------------------------------------------------------------------
-- Stored Procedures ; Dynamic Procedures
----------------------------------------------------------------------------

ALTER PROCEDURE person.address$select
(
    @addressLine1 nvarchar(120) = '%',
    @city         nvarchar(60) = '%',
    @state        nchar(3) = '___',
    @postalCode   nvarchar(50) = '%'
) AS
BEGIN
    DECLARE @query varchar(max)
    SET @query =
               'SELECT address.AddressLine1, address.AddressLine2,
                       address.City, state.StateProvinceCode, address.PostalCode
                FROM   Person.Address as address
                        join Person.StateProvince as state
                              on address.stateProvinceId = state.stateProvinceId
                WHERE   address.City like ''' + @city + '''
                   AND  state.StateProvinceCode like ''' + @state + '''
                   AND  address.PostalCode like ''' + @postalCode + '''
                   --this param is last because it is largest 
                   --to make the example
                   --easier as this column is very large
                   AND  address.AddressLine1 like ''' + @addressLine1 + ''''

    SELECT @query --just for testing purposes
    EXECUTE (@query)
 END
GO

ALTER PROCEDURE person.address$select
(
    @addressLine1 nvarchar(120) = '%',
    @city         nvarchar(60) = '%',
    @state        nchar(3) = '___',
    @postalCode   nvarchar(50) = '%'
) AS
BEGIN
    DECLARE @query varchar(max)
    SET @query =
               'SELECT address.AddressLine1, address.AddressLine2,
                        address.City, state.StateProvinceCode, address.PostalCode
                FROM   Person.Address as address
                        join Person.StateProvince as state
                                on address.stateProvinceId = state.stateProvinceId
                WHERE   1=1'
    IF @city <> '%'
          SET @query = @query + ' AND address.City like ' + quotename(@city,'''')
    IF @state <> '___'
            SET @query = @query + ' AND state.StateProvinceCode like ' +
                                                              quotename(@state,'''')
    IF @postalCode <> '%'
            SET @query = @query + ' AND address.City like ' + quotename(@city,'''')
    IF @addressLine1 <> '%'
            SET @query = @query + ' AND address.addressLine1 like ' +
                                            quotename(@addressLine1,'''')
    SELECT  @query
    EXECUTE (@query)
 END

GO
----------------------------------------------------------------------------
-- Stored Procedures ; Security
----------------------------------------------------------------------------
GO
CREATE USER  fred WITHOUT LOGIN
GO
CREATE PROCEDURE testChaining
AS
EXECUTE ('SELECT CustomerId, StoreId, AccountNumber 
          FROM    Sales.Customer')
GO
GRANT EXECUTE ON testChaining TO fred
GO
EXECUTE AS user = 'fred'
EXECUTE testChaining
REVERT
GO
ALTER PROCEDURE testChaining
WITH EXECUTE AS SELF
AS
EXECUTE ('SELECT CustomerId, StoreId, AccountNumber 
                    FROM Sales.Customer')

GO
EXECUTE AS user = 'fred'
EXECUTE testChaining
REVERT
GO

select *
from   sys.databases
GO

CREATE PROCEDURE dbo.doAnything
(
    @query nvarchar(4000)
)
WITH EXECUTE AS SELF
AS
EXECUTE (@query)
GO
------------------------------------------------------------------------------------------
-- Stored Procedures; Pitfalls; Difficulty Affecting Only Certain Columns in an Operation
------------------------------------------------------------------------------------------

USE architectureChapter
GO
CREATE PROCEDURE sales.contact$update
(
    @contactId   int,
    @firstName   varchar(30),
    @lastName    varchar(30),
    @companyName varchar(100),
    @salesLevelId  int,
    @personalNotes varchar(max),
    @contactNotes  varchar(max)
)
AS
    DECLARE @entryTrancount int = @@trancount

    BEGIN TRY
          UPDATE sales.contact
          SET         firstName = @firstName,
                          lastName = @lastName,
                          companyName = @companyName,
                          salesLevelId = @salesLevelId,
                          personalNotes = @personalNotes,
                          contactNotes = @contactNotes
          WHERE  contactId = @contactId
    END TRY
    BEGIN CATCH

        --if the tran is doomed, and the entryTrancount was 0
        --we have to rollback    
        IF xact_state()= -1 and @entryTrancount = 0 
            rollback transaction

      DECLARE @ERRORmessage nvarchar(4000)
      SET @ERRORmessage = 'Error occurred in procedure ''' + 
                  object_name(@@procid) + ''', Original Message: ''' 
                 + ERROR_MESSAGE() + ''''
      RAISERROR (@ERRORmessage,16,1)
      RETURN -100

     END CATCH
GO
ALTER PROCEDURE sales.contact$update
(
    @contactId   int,
    @firstName   varchar(30),
    @lastName    varchar(30),
    @companyName varchar(100),
    @salesLevelId  int,
    @personalNotes varchar(max),
    @contactNotes  varchar(max)
)
WITH EXECUTE AS SELF
AS
    DECLARE @entryTrancount int = @@trancount

    BEGIN TRY
       --declare variable to use to tell whether to include the 
       DECLARE @salesOrderIdChangedFlag bit = 
                       case when (select salesLevelId 
                                          from   sales.contact
                                          where  contactId = @contactId) =
                                                             @salesLevelId 
                                   then 0 else 1 end
    
        DECLARE @query nvarchar(max)
        SET @query = '
        UPDATE sales.contact
        SET        firstName = ' + quoteName(@firstName,'''') + ',
                       lastName = ' + quoteName(@lastName,'''') + ',
                      companyName = ' + quoteName(@companyName, '''') + ',
                     '+ case when @salesOrderIdChangedFlag = 1 then 
                     'salesLevelId = ' + quoteName(@salesLevelId, '''') + ',
                     ' else '' end +  'personalNotes = ' + quoteName(@personalNotes,
                                                                         '''') + ', 
                    contactNotes = ' + quoteName(@contactNotes,'''') + '
         WHERE  contactId = ' + cast(@contactId as varchar(10)) 
         SELECT @query
    END TRY
    BEGIN CATCH

        --if the tran is doomed, and the entryTrancount was 0
        --we have to rollback    
        IF xact_state()= -1 and @entryTrancount = 0 
            rollback transaction

      DECLARE @ERRORmessage nvarchar(4000)
      SET @ERRORmessage = 'Error occurred in procedure ''' + 
                  object_name(@@procid) + ''', Original Message: ''' 
                 + ERROR_MESSAGE() + ''''
      RAISERROR (@ERRORmessage,16,1)
      RETURN -100

     END CATCH
GO
CREATE TRIGGER sales.contact$insteadOfUpdate
ON sales.contact
INSTEAD OF UPDATE
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
          --[validation blocks]
          --[modification blocks]
          --<perform action>
         
          UPDATE contact
          SET    firstName = inserted.firstName,
                     lastName = inserted.lastName,
                     companyName = inserted.companyName,
                     personalNotes = inserted.personalNotes,
                     contactNotes = inserted.contactNotes
          FROM   sales.contact as contact
                    JOIN inserted
                        on inserted.contactId = contact.contactId

          IF UPDATE(salesLevelId) --this column requires heavy validation
                                  --only want to update if necessary
               UPDATE contact
               SET    salesLevelId = inserted.salesLevelId
               FROM   sales.contact as contact
                                JOIN inserted
                                     ON inserted.contactId = contact.contactId

             --this correlated subquery checks for rows that have changed
              WHERE  EXISTS (SELECT *
                                            FROM   deleted
                                            WHERE  deleted.contactId = 
                                                       inserted.contactId 
                                                  AND  deleted. salesLevelId <> 
                                                        inserted. salesLevelId) 
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              --optional
              --EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)
     END CATCH
END
GO
