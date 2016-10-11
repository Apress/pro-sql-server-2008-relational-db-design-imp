CREATE DATABASE SecurityChapter
GO
Use SecurityChapter
GO
-----------------------------------------------------------
-- Database Security Overview; Impersonation
-----------------------------------------------------------
CREATE LOGIN system_admin WITH PASSWORD = 'tooHardToEnterAndNoOneKnowsIt'
EXEC sp_addsrvrolemember 'system_admin','sysadmin'
GO
CREATE LOGIN louis with PASSWORD = 'reasonable', DEFAULT_DATABASE=tempdb

--Must execute in Master Database
USE MASTER
GRANT IMPERSONATE ON LOGIN::system_admin TO louis;
GO

--Disconnect and connect as Louis
GO
USE AdventureWorks2008
GO
EXECUTE AS LOGIN = 'system_admin'
GO
USE AdventureWorks2008
SELECT user as [user], system_user as [system_user], 
       original_login() as [original_login]
GO
REVERT --go back to previous context
GO
USE SecurityChapter
GO

REVERT
SELECT user
GO

SELECT object_name(major_id), permission_name, state_desc,
        user_name(grantee_principal_id) as Grantee
FROM   sys.database_permissions
WHERE  objectproperty(major_id,'isTable') = 1
  AND  objectproperty(major_id,'isMsShipped') = 0
GO
--------------------------------------------------------------------------------
-- Database Security Overview; Controlling Access to Objects; Table Security
--------------------------------------------------------------------------------
--You may need to reconnect as the sysadmin...

--start with a new schema for this test
CREATE SCHEMA TestPerms
GO

CREATE TABLE TestPerms.TableExample
(
    TableExampleId int identity(1,1)
                   CONSTRAINT PKTableExample PRIMARY KEY,
    Value   varchar(10)
)
GO
CREATE USER Tony WITHOUT LOGIN
GO
EXECUTE AS USER = 'Tony'
INSERT INTO TestPerms.TableExample(Value)
VALUES ('a row')
GO

REVERT
GRANT INSERT on TestPerms.TableExample to Tony

EXECUTE AS USER = 'Tony'
INSERT INTO TestPerms.TableExample(Value)
VALUES ('a row')
GO

SELECT TableExampleId, value
FROM   TestPerms.TableExample
GO

REVERT
GRANT SELECT on TestPerms.TableExample to Tony
GO

--------------------------------------------------------------------------------
-- Database Security Overview; Controlling Access to Objects; Table Security
--------------------------------------------------------------------------------

CREATE USER Employee WITHOUT LOGIN
CREATE USER Manager WITHOUT LOGIN

GO
CREATE SCHEMA Products
go
CREATE TABLE Products.Product
(
    ProductId   int identity CONSTRAINT PKProduct PRIMARY KEY,
    ProductCode varchar(10) CONSTRAINT AKProduct_ProductCode UNIQUE,
    Description varchar(20),
    UnitPrice   decimal(10,4),
    ActualCost  decimal(10,4)
)
INSERT INTO Products.Product(ProductCode, Description, UnitPrice, ActualCost)
VALUES ('widget12','widget number 12',10.50,8.50),
       ('snurf98','Snurfulator',99.99,2.50)

GO
GRANT SELECT on Products.Product to employee,manager
DENY SELECT on Products.Product (ActualCost) to employee
GO
EXECUTE AS USER = 'manager'
SELECT  *
FROM    Products.Product
GO
REVERT --revert back to SA level user or you will get an error that the
       --user cannot do this operation because it is unclear if the employee
       --user actually exists
GO
EXECUTE AS USER = 'employee'
GO
SELECT * 
FROM   Products.Product
GO

SELECT ProductId, ProductCode, Description, UnitPrice
FROM   Products.Product

GO

------------------------------------------------------------------------------------------------
-- Database Security Overview; Controlling Access to Objects; Roles; Standard Database Roles
------------------------------------------------------------------------------------------------
GO
SELECT is_member('HRManager')
GO
IF (SELECT is_member('HRManager')) = 0 or (SELECT is_member('HRManager')) is null
       SELECT 'I..DON''T THINK SO!'
GO
REVERT
CREATE USER Frank WITHOUT LOGIN
CREATE USER Julie WITHOUT LOGIN
CREATE USER Rie WITHOUT LOGIN
GO
CREATE ROLE HRWorkers

EXECUTE sp_addrolemember 'HRWorkers','Julie'
EXECUTE sp_addrolemember 'HRWorkers','Rie'
GO


CREATE SCHEMA Payroll

CREATE TABLE Payroll.EmployeeSalary
(
    EmployeeId  int,
    SalaryAmount decimal(12,2)

)
GRANT SELECT ON Payroll.EmployeeSalary to HRWorkers
GO

EXECUTE AS USER = 'Frank'

SELECT *
FROM   Payroll.EmployeeSalary
GO


REVERT
EXECUTE AS USER = 'Julie'

SELECT *
FROM   Payroll.EmployeeSalary

GO

REVERT
DENY SELECT ON payroll.employeeSalary TO Rie

EXECUTE AS USER = 'Rie'
SELECT *
FROM   payroll.employeeSalary
GO
REVERT
--note, this query only returns rows for tables where the user has SOME rights
SELECT  table_schema + '.' + table_name as tableName,
        has_perms_by_name(table_schema + '.' + table_name, 'object', 'SELECT')
                                                                
                                                                 as allowSelect
FROM    information_schema.tables

GO
CREATE TABLE TestPerms.BobCan
(
    BobCanId int identity(1,1) CONSTRAINT PKBobCan PRIMARY KEY,
    Value varchar(10)
)
CREATE TABLE TestPerms.AppCan
(
    AppCanId int identity(1,1) CONSTRAINT PKAppCan PRIMARY KEY,
    Value varchar(10)
)
GO
CREATE USER Bob WITHOUT LOGIN
GO
GRANT SELECT on TestPerms.BobCan to Bob
GO
CREATE APPLICATION ROLE AppCan_application with password = '39292ljasll23'
GO
GRANT SELECT on TestPerms.AppCan to AppCan_application
GO

EXECUTE AS USER = 'Bob'
GO
SELECT * FROM TestPerms.BobCan
GO
SELECT * FROM TestPerms.AppCan
GO
REVERT
GO
EXECUTE sp_setapprole 'AppCan_application', '39292ljasll23'
go
SELECT * FROM TestPerms.BobCan
GO
SELECT * from TestPerms.AppCan
GO
SELECT user as userName, system_user as login
GO
--Disconnect and reconnect to clear out app role...

Use SecurityChapter
GO
--Note that this must be executed as a single batch because of the variable
--for the cookie
DECLARE @cookie varbinary(8000);
EXECUTE sp_setapprole 'AppCan_application', '39292ljasll23'
              , @fCreateCookie = true, @cookie = @cookie OUTPUT

SELECT @cookie as cookie
SELECT USER as beforeUnsetApprole

EXEC sp_unsetapprole @cookie

SELECT USER as afterUnsetApprole

REVERT --done with this user
GO

------------------------------------------------------------------------------------------------
-- Database Security Overview; Controlling Access to Objects; Roles; Schemas
------------------------------------------------------------------------------------------------
GO

USE AdventureWorks2008
GO
SELECT  type_desc, count(*)
FROM    sys.objects
WHERE   schema_name(schema_id) = 'HumanResources'
  AND   type_desc in ('SQL_STORED_PROCEDURE','CLR_STORED_PROCEDURE',
                      'SQL_SCALAR_FUNCTION','CLR_SCALAR_FUNCTION',
                      'CLR_TABLE_VALUED_FUNCTION','SYNONYM',
                      'SQL_INLINE_TABLE_VALUED_FUNCTION',
                      'SQL_TABLE_VALUED_FUNCTION','USER_TABLE','VIEW')
GROUP BY type_desc
GO
USE SecurityChapter --or your own db if you are not using mine
GO
CREATE USER Tom WITHOUT LOGIN
GRANT SELECT ON SCHEMA::TestPerms To Tom
GO

EXECUTE AS USER = 'Tom'
GO
SELECT * FROM TestPerms.AppCan
GO
REVERT
GO

CREATE TABLE TestPerms.SchemaGrant
(
    SchemaGrantId int primary key
)
GO
EXECUTE AS USER = 'Tom'
GO
SELECT * FROM TestPerms.schemaGrant
GO 
REVERT
GO
---------------------------------------------------------------------------------------------
-- Controlling Object Access Via T-SQL Coded Objects; Stored Procedures and Scalar Functions
--------------------------------------------------------------------------------------------

CREATE USER procUser WITHOUT LOGIN
GO

CREATE SCHEMA procTest
CREATE TABLE procTest.misc
(
    Value varchar(20),
    Value2 varchar(20)
)
GO
INSERT INTO procTest.misc
VALUES ('somevalue','secret'),
      ('anothervalue','secret')
GO


CREATE PROCEDURE procTest.misc$select
AS
    SELECT Value
    FROM   procTest.misc
GO
GRANT EXECUTE on procTest.misc$select to procUser
GO

EXECUTE AS USER = 'procUser'
GO
SELECT Value, Value2
FROM   procTest.misc
GO

EXECUTE procTest.misc$select
GO

SELECT  routine_schema + '.' + routine_name as procedureName,
        has_perms_by_name(routine_schema + '.' + routine_name, 'object', 
                            'EXECUTE') as allowExecute
FROM    information_schema.routines
WHERE   routine_type = 'PROCEDURE'

REVERT

GO

---------------------------------------------------------------------------------------------
-- Controlling Object Access Via T-SQL Coded Objects;Impersonation Within Objects
--------------------------------------------------------------------------------------------
--this will be the owner of the primary schema
CREATE USER schemaOwner WITHOUT LOGIN
GRANT CREATE SCHEMA to schemaOwner
GRANT CREATE TABLE to schemaOwner

--this will be the procedure creator
CREATE USER procedureOwner WITHOUT LOGIN
GRANT CREATE SCHEMA to procedureOwner
GRANT CREATE PROCEDURE to procedureOwner
GRANT CREATE TABLE to procedureOwner
GO
--this will be the average user who needs to access data
CREATE USER aveSchlub WITHOUT LOGIN
GO


EXECUTE AS USER = 'schemaOwner'
GO
CREATE SCHEMA schemaOwnersSchema
GO
CREATE TABLE schemaOwnersSchema.Person
(
    PersonId    int constraint PKtestAccess_Person primary key,
    FirstName   varchar(20),
    LastName    varchar(20)
)
Go
INSERT INTO schemaOwnersSchema.Person
VALUES (1, 'Phil','Mutayblin'),
       (2, 'Del','Eets')
GO

GRANT SELECT on schemaOwnersSchema.Person to procedureOwner
GO


REVERT --we can step back on the stack of principals, 
        --but we can't change directly
        --to procedureOwner. Here I step back to the db_owner user you have
        --used throughout the chapter
GO
EXECUTE AS USER = 'procedureOwner'
GO

CREATE SCHEMA procedureOwnerSchema
GO

CREATE TABLE procedureOwnerSchema.OtherPerson
(
    personId    int constraint PKtestAccess_person primary key,
    FirstName   varchar(20),
    LastName    varchar(20)
)
go
INSERT INTO procedureOwnerSchema.OtherPerson
VALUES (1, 'DB','Smith')
INSERT INTO procedureOwnerSchema.OtherPerson
VALUES (2, 'Dee','Leater')
GO

REVERT
GO
SELECT tables.name as [table], schemas.name as [schema], 
       database_principals.name as [owner]
FROM   sys.tables
         join sys.schemas
            on tables.schema_id = schemas.schema_id
         join sys.database_principals
            on database_principals.principal_id = schemas.principal_id
WHERE  tables.name in ('Person','OtherPerson')
GO

EXECUTE AS USER = 'procedureOwner'
GO
CREATE PROCEDURE  procedureOwnerSchema.person$asCaller
WITH EXECUTE AS CALLER --this is the default
AS
SELECT  personId, FirstName, LastName
FROM    procedureOwnerSchema.OtherPerson --<-- ownership same as proc

SELECT  personId, FirstName, LastName
FROM    schemaOwnersSchema.person  --<-- breaks ownership chain
GO

CREATE PROCEDURE procedureOwnerSchema.person$asSelf
WITH EXECUTE AS SELF --now this runs in context of procedureOwner,
                     --since it created it
AS
SELECT  personId, FirstName, LastName
FROM    procedureOwnerSchema.OtherPerson --<-- ownership same as proc

SELECT  personId, FirstName, LastName
FROM    schemaOwnersSchema.person  --<-- breaks ownership chain

GO

GRANT EXECUTE ON procedureOwnerSchema.person$asCaller to aveSchlub
GRANT EXECUTE ON procedureOwnerSchema.person$asSelf to aveSchlub

REVERT; EXECUTE AS USER = 'aveSchlub'
GO

--this proc is in context of the caller, in this case, aveSchlub
EXECUTE procedureOwnerSchema.person$asCaller
GO

--procedureOwner, so it works
execute procedureOwnerSchema.person$asSelf
GO


REVERT
GO
CREATE PROCEDURE dbo.testDboRights
AS
 BEGIN
    CREATE TABLE dbo.test
    (
        testId int
    )
 END
GO

CREATE USER leroy WITHOUT LOGIN
GO
GRANT EXECUTE on dbo.testDboRights to leroy
GO

GO
EXECUTE AS USER = 'leroy'
EXECUTE dbo.testDboRights
GO

REVERT
GO
ALTER PROCEDURE dbo.testDboRights
WITH EXECUTE AS 'dbo'
AS
 BEGIN
    CREATE TABLE dbo.test
    (
        testId int
    )
 END
GO

EXECUTE AS USER = 'leroy'
EXECUTE dbo.testDboRights
GO
REVERT
GO

---------------------------------------------------------------------------------------------
--  Controlling Object Access Via T-SQL Coded Objects;Crossing Database Lines;Cross Database Chaining
--------------------------------------------------------------------------------------------
GO
CREATE DATABASE externalDb
GO
USE externalDb
GO
                                   --smurf theme song :)
CREATE LOGIN smurf WITH PASSWORD = 'La la, la la la la, la, la la la la'
CREATE USER smurf FROM LOGIN smurf
CREATE TABLE dbo.table1 ( value int )
GO
CREATE DATABASE localDb
GO
USE localDb
GO
CREATE USER smurf FROM LOGIN smurf
GO

CREATE PROCEDURE dbo.externalDb$testCrossDatabase
AS
SELECT Value
FROM   externalDb.dbo.table1
GO
GRANT execute on dbo.externalDb$testCrossDatabase to smurf
GO

EXECUTE AS USER = 'smurf'
go
EXECUTE dbo.externalDb$testCrossDatabase
GO
REVERT

GO
ALTER DATABASE localDb
   SET DB_CHAINING ON
ALTER DATABASE localDb
   SET TRUSTWORTHY ON

ALTER DATABASE externalDb
   SET DB_CHAINING ON
GO
SELECT cast(name as varchar(10)) as name,
       cast(suser_sname(owner_sid) as varchar(10)) as owner,
       is_trustworthy_on, is_db_chaining_on
FROM   sys.databases where name in ('localdb','externaldb')
GO
EXECUTE AS USER = 'smurf'
go
EXECUTE dbo.externalDb$testCrossDatabase
GO
REVERT
GO

---------------------------------------------------------------------------------------------
--  Controlling Object Access Via T-SQL Coded Objects;Crossing Database Lines;Using Impersonation to Cross Database Lines
--------------------------------------------------------------------------------------------

ALTER DATABASE localDb
   SET DB_CHAINING OFF
ALTER DATABASE localDb
   SET TRUSTWORTHY ON

ALTER DATABASE externalDb
   SET DB_CHAINING OFF

GO

CREATE PROCEDURE dbo.externalDb$testCrossDatabase_Impersonation
WITH EXECUTE AS SELF --as procedure creator
AS
SELECT Value
FROM   externalDb.dbo.table1
GO
GRANT execute on dbo.externalDb$testCrossDatabase_impersonation to smurf
GO

EXECUTE AS USER = 'smurf'
go
EXECUTE dbo.externalDb$testCrossDatabase_impersonation
GO
REVERT
GO

---------------------------------------------------------------------------------------------
--  Controlling Object Access Via T-SQL Coded Objects;Crossing Database Lines;Using a Certificate-Based User
--------------------------------------------------------------------------------------------
GO
REVERT
GO
USE localDb
GO
ALTER DATABASE localDb
   SET TRUSTWORTHY OFF
GO
SELECT cast(name as varchar(10)) as name,
       cast(suser_sname(owner_sid) as varchar(10)) as owner,
       is_trustworthy_on, is_db_chaining_on
FROM   sys.databases where name in ('localdb','externaldb')
GO


CREATE PROCEDURE dbo.externalDb$testCrossDatabase_Certificate
AS
SELECT Value
FROM   externalDb.dbo.table1
GO
GRANT EXECUTE on dbo.externalDb$testCrossDatabase_Certificate to smurf
GO

CREATE CERTIFICATE procedureExecution ENCRYPTION BY PASSWORD = 'Cert Password'
 WITH SUBJECT =  
         'Used to sign procedure:externalDb$testCrossDatabase_Certificate'
GO
ADD SIGNATURE TO dbo.externalDb$testCrossDatabase_Certificate
     BY CERTIFICATE procedureExecution WITH PASSWORD = 'Cert Password'
GO
BACKUP CERTIFICATE procedureExecution TO FILE = 'c:\temp\procedureExecution.cer'
GO

USE externalDb
GO
CREATE CERTIFICATE procedureExecution FROM FILE = 'c:\temp\procedureExecution.cer'
GO

CREATE USER procCertificate FOR CERTIFICATE procedureExecution
GO
GRANT SELECT on dbo.table1 TO procCertificate

GO

USE localDb
GO
EXECUTE AS LOGIN = 'smurf'
EXECUTE dbo.externalDb$testCrossDatabase_Certificate

GO
REVERT
GO
USE MASTER
GO
DROP DATABASE externalDb
DROP DATABASE localDb
GO
USE SecurityChapter

--------------------------------------------------------------------------------
-- Views and Table-Valued Functions; General Usage
--------------------------------------------------------------------------------
GO
SELECT *
FROM Products.Product
GO
CREATE VIEW Products.allProducts
AS
SELECT ProductId,ProductCode, Description, UnitPrice, ActualCost
FROM   Products.Product
GO
CREATE VIEW Products.WarehouseProducts
AS
SELECT ProductId,ProductCode, Description
FROM   Products.Product
GO
CREATE FUNCTION Products.ProductsLessThanPrice
(
    @UnitPrice  decimal(10,4)
)
RETURNS table
AS
     RETURN ( SELECT ProductId, ProductCode, Description, UnitPrice
              FROM   Products.Product
              WHERE  UnitPrice <= @UnitPrice)
GO
SELECT * FROM Products.ProductsLessThanPrice(20)
GO
CREATE FUNCTION Products.ProductsLessThanPrice_GroupEnforced
(
    @UnitPrice  decimal(10,4)
)
RETURNS @output table (ProductId int, 
                       ProductCode varchar(10), 
                       Description varchar(20),
                       UnitPrice decimal(10,4))
AS
 BEGIN
    --cannot raise an error, so you have to implement your own 
    --signal, or perhaps simply return no data.
    IF @UnitPrice > 100 and (
                             IS_MEMBER('HighPriceProductViewer') = 0 
                             or IS_MEMBER('HighPriceProductViewer') is null)
        INSERT @output
        SELECT -1,'ERROR','',-1
    ELSE
        INSERT @output
        SELECT ProductId, ProductCode, Description, UnitPrice
        FROM   Products.Product
        WHERE  UnitPrice <= @UnitPrice
    RETURN
 END
GO
CREATE ROLE HighPriceProductViewer
CREATE ROLE ProductViewer

CREATE USER HighGuy WITHOUT LOGIN
CREATE USER LowGuy WITHOUT LOGIN

EXEC sp_addrolemember 'HighPriceProductViewer','HighGuy'
EXEC sp_addrolemember 'ProductViewer','HighGuy'
EXEC sp_addrolemember 'ProductViewer','LowGuy'
GO
GRANT SELECT ON Products.ProductsLessThanPrice_GroupEnforced TO ProductViewer
GO

EXECUTE AS USER = 'HighGuy'
SELECT * FROM Products.ProductsLessThanPrice_GroupEnforced(10000)
REVERT
GO
EXECUTE AS USER = 'LowGuy'
SELECT * FROM Products.ProductsLessThanPrice_GroupEnforced(10000)
REVERT
GO
--------------------------------------------------------------------------------
-- Views and Table-Valued Functions; Implementing Configurable Row-Level Security with Views
--------------------------------------------------------------------------------
Go
ALTER TABLE Products.Product
   ADD ProductType varchar(20) NULL
GO
UPDATE Products.Product
SET    ProductType = 'widget'
WHERE  ProductCode = 'widget12'
GO
UPDATE Products.Product
SET    ProductType = 'snurf'
WHERE  ProductCode = 'snurf98'
GO
CREATE VIEW Products.WidgetProducts
AS
SELECT ProductId, ProductCode, Description, UnitPrice, ActualCost
FROM   Products.Product
WHERE  ProductType = 'widget'
WITH CHECK OPTION --This prevents the user from entering data that would not
                  --match the view's criteria
GO
SELECT *
FROM   Products.WidgetProducts
GO
CREATE VIEW Products.ProductsSelective
AS
SELECT ProductId, ProductCode, Description, UnitPrice, ActualCost
FROM   Products.Product
WHERE  ProductType <> 'snurf'
   or  (is_member('snurfViewer') = 1)
   or  (is_member('db_owner') = 1) --can't add db_owner to a role
WITH CHECK OPTION
GO
GRANT SELECT ON Products.ProductsSelective to public
GO

CREATE USER chrissy WITHOUT LOGIN
CREATE ROLE snurfViewer
GO
EXECUTE AS USER = 'chrissy'
SELECT * from Products.ProductsSelective
REVERT
GO

execute sp_addrolemember 'snurfViewer', 'chrissy'
GO
EXECUTE AS USER = 'chrissy'
SELECT * from Products.ProductsSelective
REVERT
GO
CREATE TABLE Products.ProductSecurity
(
    ProductsSecurityId int identity(1,1)
                CONSTRAINT PKProducts_ProductsSecurity PRIMARY KEY,
    ProductType varchar(20), --at this point you probably will create a
                             --ProductType domain table, but this keeps the                             
                             --example a bit simpler
    DatabaseRole    sysname,
                CONSTRAINT AKProducts_ProductsSecurity_typeRoleMapping
                            UNIQUE (ProductType, DatabaseRole)
)
GO
INSERT INTO Products.ProductSecurity(ProductType, DatabaseRole)
VALUES ('widget','public')
GO
ALTER VIEW Products.ProductsSelective
AS
SELECT Product.ProductId, Product.ProductCode, Product.Description,
       Product.UnitPrice, Product.ActualCost, Product.ProductType
FROM   Products.Product as Product
         JOIN Products.ProductSecurity as ProductSecurity
            on  (Product.ProductType = ProductSecurity.ProductType
                and is_member(ProductSecurity.DatabaseRole) = 1)
                or is_member('db_owner') = 1 --don't leave out the dbo!
GO

EXECUTE AS USER = 'chrissy'
SELECT * 
FROM   PRoducts.ProductsSelective
GO
REVERT
GO

INSERT INTO Products.ProductSecurity(ProductType, databaseRole)
VALUES ('snurf','snurfViewer')
go
EXECUTE AS USER = 'chrissy'
SELECT * from PRoducts.ProductsSelective
REVERT


--------------------------------------------------------------------------------------
-- Obfuscating Data
--------------------------------------------------------------------------------------
SELECT encryptByPassPhrase('hi', 'Secure data')
GO
SELECT decryptByPassPhrase('hi',
   0x010000004D2B87C6725612388F8BA4DA082495E8C836FF76F32BCB642B36476594B4F014)
GO

SELECT cast(decryptByPassPhrase('hi',
     0x010000004D2B87C6725612388F8BA4DA082495E8C836FF76F32BCB642B36476594B4F014)
                                              as varchar(30))

GO
CREATE DATABASE EncryptionMaster
go
USE EncryptionMaster
go
CREATE SCHEMA Security
CREATE TABLE Security.passphrase
(
    passphrase nvarchar(4000) --the max size of the passphrase
)
GO

INSERT  into Security.passphrase
VALUES ('ljlOIUEojljljieo#*JlLjlIu*o7G8i&t87*&Yh[p00') --the more unobvious the
                                                       --better!

GO

CREATE DATABASE CreditInfo
GO
ALTER DATABASE EncryptionMaster  -- we will be using impersonation to keep the
    SET TRUSTWORTHY ON           -- example simple, in practice I would
                                 -- probably use certificates
GO
USE CreditInfo
GO

CREATE SCHEMA Sales
GO
CREATE TABLE Sales.Customer
(
    CustomerId  char(10),
    FirstName   varchar(30),
    LastName    varchar(30),
    CreditCardLastFour char(4),
    CreditCardNumber varbinary(44)
)
GO

CREATE PROCEDURE Customer$insert
(
    @CustomerId  char(10),
    @FirstName   varchar(10),
    @LastName    varchar(10),
    @CreditCardNumber char(16)
)
WITH EXECUTE AS 'dbo'
as

INSERT INTO Sales.Customer (CustomerId,FirstName, LastName, CreditCardLastFour,
                            CreditCardNumber)
SELECT  @CustomerId, @FirstName,@LastName,substring(@CreditCardNumber,13,4),
        encryptByPassPhrase(pass.passPhrase, @CreditCardNumber)
FROM    encryptionMaster.Security.passphrase as pass

GO

EXEC Customer$insert 'cust1','Bob','jones','0000111122223333'
GO

CREATE PROCEDURE Sales.CustomerWithCreditCard
WITH EXECUTE AS 'dbo'
AS
 BEGIN
        SELECT  Customer.CustomerId, FirstName, LastName,
                CreditCardLastFour,
                cast(decryptByPassPhrase(pass.passPhrase,CreditCardNumber)
                             as char(16)) as CreditCardNumber
        FROM    Sales.Customer
                        CROSS JOIN encryptionMaster.Security.passphrase as pass
 END
GO

EXEC Sales.CustomerWithCreditCard
GO

--------------------------------------------------------------------------------------
-- Monitoring and Auditing; Server and Database Audit; Defining an Audit Specification
--------------------------------------------------------------------------------------
Go
USE master
GO
CREATE SERVER AUDIT ProSQLServerDatabaseDesign_Audit
TO FILE                        --choose your own directory, I expect most people 
(     FILEPATH = N'c:\temp\' --have a temp directory on their system drive
      ,MAXSIZE = 15 MB
     ,MAX_ROLLOVER_FILES = 0 --unlimited
)
WITH
(
     ON_FAILURE = SHUTDOWN --if the file cannot be written to, 
                      --shutdown the server
)
GO

CREATE SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    FOR SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = OFF) --disabled. we will enable it later
GO

ALTER SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP) 

GO

USE SecurityChapter
GO
CREATE DATABASE AUDIT SPECIFICATION 
                   ProSQLServerDatabaseDesign_Database_Audit
    FOR SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = OFF)
GO

ALTER DATABASE AUDIT SPECIFICATION 
ProSQLServerDatabaseDesign_Database_Audit
    ADD (SELECT ON Products.Product BY employee,manager),
    ADD (SELECT ON Products.AllProducts BY public)
GO

USE master
GO
ALTER SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = ON)
ALTER SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    WITH (STATE = ON)
GO
USE SecurityChapter
GO
ALTER DATABASE AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Database_Audit
    WITH (STATE = ON)
GO


CREATE drop LOGIN MrSmith WITH PASSWORD = 'Not a good password'
GO
EXECUTE AS USER = 'manager'
GO
SELECT *
FROM   Products.Product
GO
SELECT  * 
FROM     Products.AllProducts 
REVERT
GO
SELECT  * 
FROM     Products.AllProducts 
GO

SELECT event_time, succeeded, 
       database_principal_name,statement
FROM sys.fn_get_audit_file ('c:\temp\*',default,default);
GO

SELECT  sas.name as audit_specification_name,
        audit_action_name
FROM    sys.server_audits as sa
          join sys.server_audit_specifications as sas
             on sa.audit_guid = sas.audit_guid
          join sys.server_audit_specification_details as sasd
             on sas.server_specification_id = sasd.server_specification_id
WHERE  sa.name = 'ProSQLServerDatabaseDesign_Audit'

SELECT --sas.name  as audit_specification_name,
       audit_action_name,dp.name as [principal],
       SCHEMA_NAME(o.schema_id) + '.' + o.name as object
FROM   sys.server_audits as sa
         join sys.database_audit_specifications as sas
             on sa.audit_guid = sas.audit_guid
         join sys.database_audit_specification_details as sasd
             on sas.database_specification_id = sasd.database_specification_id
         join sys.database_principals as dp
             on dp.principal_id = sasd.audited_principal_id
         join sys.objects as o
             on o.object_id = sasd.major_id
WHERE  sa.name = 'ProSQLServerDatabaseDesign_Audit'
  and  sasd.minor_id = 0 --need another query for column level audits
GO

--------------------------------------------------------------------------------------
-- Monitoring and Auditing; Watching Table History Using DML Triggers
--------------------------------------------------------------------------------------
GO
USE SecurityChapter
GO
CREATE SCHEMA Sales
GO
CREATE SCHEMA Inventory
GO
CREATE TABLE Sales.invoice
(
    InvoiceId   int not null identity(1,1) CONSTRAINT PKInvoice PRIMARY KEY,
    InvoiceNumber char(10) not null
                      CONSTRAINT AKInvoice_InvoiceNumber UNIQUE,
    CustomerName varchar(60) not null , --should be normalized in real database
    InvoiceDate smalldatetime not null
)
CREATE TABLE Inventory.Product
(
    ProductId int identity(1,1) CONSTRAINT PKProduct PRIMARY KEY,
    name varchar(30) not null CONSTRAINT AKProduct_name UNIQUE,
    Description varchar(60) not null ,
    Cost numeric(12,4) not null
)
CREATE TABLE Sales.InvoiceLineItem
(
    InvoiceLineItemId int identity(1,1)
                      CONSTRAINT PKInvoiceLineItem PRIMARY KEY,
    InvoiceId int not null,
    ProductId int not null,
    Quantity numeric(6,2) not null,
    Cost numeric(12,4) not null,
    discount numeric(3,2) not null,
    discountExplanation varchar(200) not null,
    CONSTRAINT AKInvoiceLineItem_InvoiceAndProduct
             UNIQUE (InvoiceId, ProductId),
    CONSTRAINT FKSales_Invoice$listsSoldProductsIn$Sales_InvoiceLineItem
             FOREIGN KEY (InvoiceId) REFERENCES Sales.Invoice(InvoiceId),
    CONSTRAINT FKSales_Product$isSoldVia$Sales_InvoiceLineItem
             FOREIGN KEY (InvoiceId) REFERENCES Sales.Invoice(InvoiceId)
    --more constraints should be in place for full implementation
)

GO
CREATE TABLE Sales.InvoiceLineItemDiscountAudit
(
    InvoiceLineItemDiscountAudit  int identity(1,1)
          CONSTRAINT PKInvoiceLineItemDiscountAudit PRIMARY KEY,
    InvoiceId   int,
    InvoiceLineItemId int,
    AuditTime   datetime,
    SetByUserId sysname,
    Quantity numeric(6,2) not null,
    Cost numeric(12,4) not null,
    Discount numeric(3,2) not null,
    DiscountExplanation varchar(300) not null
)

GO

CREATE TRIGGER Sales.InvoiceLineItem$insertAndUpdateAuditTrail
ON Sales.InvoiceLineItem
AFTER INSERT,UPDATE AS
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
      IF UPDATE(Cost)
         INSERT INTO Sales.InvoiceLineItemDiscountAudit (InvoiceId,
                         InvoiceLineItemId, AuditTime, SetByUserId, Quantity, 
                         Cost, Discount, DiscountExplanation)
         SELECT inserted.InvoiceId, inserted.InvoiceLineItemId, 
                current_timestamp, suser_sname(), inserted.Quantity, 
                inserted.Cost, inserted.Discount,
                inserted.DiscountExplanation

         from   inserted
                   join Inventory.Product as Product
                      on inserted.ProductId = Product.ProductId
         --if the Discount is more than 0, or the cost supplied is less than the
         --current value
         where   inserted.Discount > 0
            or   inserted.Cost < Product.Cost
                      -- if it was the same or greater, that is good!
                      -- this keeps us from logging if the cost didn't actually
                      -- change
   END TRY
   BEGIN CATCH
               IF @@trancount > 0
                     ROLLBACK TRANSACTION

              --or this will not get rolled back
              --EXECUTE dbo.errorLog$insert

              DECLARE @ERROR_MESSAGE varchar(8000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO


INSERT INTO Inventory.Product(name, Description,Cost)
VALUES ('Duck Picture','Picture on the wall in my hotelRoom',200.00),
       ('Cow Picture','Picture on the other wall in my hotelRoom',150.00)

GO

INSERT INTO Sales.Invoice(InvoiceNumber, CustomerName, InvoiceDate)
VALUES ('IE00000001','The Hotel Picture Company','1/1/2005')
GO

INSERT INTO Sales.InvoiceLineItem(InvoiceId, ProductId, Quantity,
                                  Cost, Discount, DiscountExplanation)
SELECT  (SELECT InvoiceId 
         FROM   Sales.Invoice 
         WHERE  InvoiceNumber = 'IE00000001'),
        (SELECT ProductId 
         FROM   Inventory.Product 
         WHERE  Name = 'Duck Picture'),  1,200,0,''
GO

SELECT * FROM Sales.InvoiceLineItemDiscountAudit
GO

INSERT INTO Sales.InvoiceLineItem(InvoiceId, ProductId, Quantity,
                                  Cost, Discount, DiscountExplanation)
SELECT  (SELECT InvoiceId 
         FROM Sales.Invoice 
         WHERE InvoiceNumber = 'IE00000001'),
        (SELECT ProductId 
         FROM Inventory.Product 
         WHERE name = 'Cow Picture'),
        1,150,.45,'Customer purchased two, so I gave 45% off'

SELECT * FROM Sales.InvoiceLineItemDiscountAudit

--------------------------------------------------------------------------------------
-- Monitoring and Auditing; DDL Triggers; Preventing a DDL Action
--------------------------------------------------------------------------------------
GO
CREATE TRIGGER tr_server$allTableDDL_prevent --note, not a schema owned object
ON DATABASE
AFTER CREATE_TABLE, DROP_TABLE, ALTER_TABLE
AS
 BEGIN
   BEGIN TRY  --note the following line will not wrap
        RAISERROR ('The trigger: tr_server$allTableDDL_prevent must be disabled
                    before making any table modifications',16,1)
   END TRY
   --using the same old error handling
   BEGIN CATCH
              IF @@trancount > 0
                    ROLLBACK TRANSACTION

              --commented out, build from Chapter 6 if desired
              --EXECUTE dbo.errorLog$insert

              DECLARE @ERROR_MESSAGE varchar(8000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO

CREATE TABLE dbo.test  --dbo for simplicity of example
(
    testId int identity CONSTRAINT PKtest PRIMARY KEY
)

--------------------------------------------------------------------------------------
-- Monitoring and Auditing; DDL Triggers; Recording a DDL Action
--------------------------------------------------------------------------------------
GO
--Note: Slight change in syntax to drop DDL trigger, requires clause indicating
--where the objects are
DROP TRIGGER tr_server$allTableDDL_prevent ON DATABASE
GO

--first create a table to log to
CREATE TABLE dbo.TableChangeLog
(
    TableChangeLogId int identity
        CONSTRAINT pkTableChangeLog PRIMARY KEY (TableChangeLogId),
    ChangeTime      datetime,
    UserName        sysname,
    Ddl             varchar(max)--so we can get as much of the batch as possible
)
GO
--not a schema bound object
CREATE TRIGGER tr_server$allTableDDL
ON DATABASE
AFTER CREATE_TABLE, DROP_TABLE, ALTER_TABLE
AS
 BEGIN
   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY

        --we get our data from the EVENT_INSTANCE XML stream
        INSERT INTO dbo.TableChangeLog (ChangeTime, userName, Ddl)
        SELECT getdate(), user,
              EVENTDATA().value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]',
             'nvarchar(max)')

   END TRY
   --using the same old error handling
   BEGIN CATCH
              IF @@trancount > 0
                     ROLLBACK TRANSACTION

              --From Ch6, get code if you want to enable
              --EXECUTE dbo.errorLog$insert

              DECLARE @ERROR_MESSAGE varchar(8000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END

GO

CREATE TABLE dbo.test
(
    id int
)
GO
DROP TABLE dbo.test
GO

SELECT * FROM dbo.TableChangeLog


--------------------------------------------------------------------------------------
-- Monitoring and Auditing; Logging with Profiler
--------------------------------------------------------------------------------------


CREATE PROCEDURE dbo.Server$Watch
as

--note that we have to do some things because these procedures are very picky
--about datatypes.
declare @traceId int, @retval int,
        @stoptime datetime, @maxfilesize bigint, @filecount int
set @maxfilesize = 10 --MB
set @filecount = 20

--creates a trace, placing the file in the root of the server (clearly you should
--change this location to something that fits your own server standards other than
--the root of the c: drive)
exec @retval =  sp_trace_create @traceId = @traceId output,
                     @options = 2, --rollover to a different file
                                   --once max is reached
                     @tracefile = N'c:\trace.trc',
                     @maxfilesize = @maxfilesize,
                     @stoptime = @stoptime,
                     @filecount = 20

--this is because the fourth parameter must be a bit, and the literal 1 thinks it is
--an integer
declare @true bit
set @true = 1

--then we manually add events
exec sp_trace_setevent @traceID, 12, 1, @true 
exec sp_trace_setevent @traceID, 12, 6, @true  --12 = sql:batchstarting 
                                               --6 = NTUserName
exec sp_trace_setevent @traceID, 12, 7, @true  --12 = sql:batchstarting
                                               --7=NTDomainName
exec sp_trace_setevent @traceID, 12, 11, @true --12 = sql:batchstarting 
                                               --11=LoginName
exec sp_trace_setevent @traceID, 12, 14, @true --12 = sql:batchstarting 
                                               --14=StartTime

exec sp_trace_setevent @traceID, 13, 1, @true --13 = sql:batchending 
                                              -- 1 = textdata
exec sp_trace_setevent @traceID, 13, 6, @true --13 = sql:batchending  
                                              -- 6=NTUserName
exec sp_trace_setevent @traceID, 13, 7, @true --13 = sql:batchending 
                                              -- 7=NTDomainName
exec sp_trace_setevent @traceID, 13, 11, @true --13 = sql:batchending  
                                               --11=LoginName
exec sp_trace_setevent @traceID, 13, 14, @true --13 = sql:batchending 
                                               --14=StartTime

--and start the trace
exec sp_trace_setstatus @traceId = @traceId, @status = 1 --1 starts it

--this logs that we started the trace to the event viewer
declare @msg varchar(2000)
set @msg = 'logging under trace:' + cast(@traceId as varchar(10)) + ' started'
exec xp_logevent 60000, @msg, 'informational'
GO

exec master..sp_procoption 'dbo.Server$Watch','startup','true'
GO

