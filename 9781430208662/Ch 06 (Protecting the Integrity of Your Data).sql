CREATE DATABASE ProtectionChapter
go
USE ProtectionChapter
Go
------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - Declarative Data Protection
------------------------------------------------------------------------------------------------------

CREATE SCHEMA Music
GO
CREATE TABLE Music.Artist
(
   ArtistId int NOT NULL,
   Name varchar(60) NOT NULL,

   CONSTRAINT PKNameArtist PRIMARY KEY CLUSTERED (ArtistId),
   CONSTRAINT AKNameArtist_Name UNIQUE NONCLUSTERED (Name)
)
CREATE TABLE Music.Publisher
(
        PublisherId              int primary key,
        Name                      varchar(20),
        CatalogNumberMask varchar(100)
        CONSTRAINT DfltNamePublisher_CatalogNumberMask default ('%'),
        CONSTRAINT AKNamePublisher_Name UNIQUE NONCLUSTERED (Name),
)

CREATE TABLE Music.Album
(
   AlbumId int NOT NULL,
   Name varchar(60) NOT NULL,
   ArtistId int NOT NULL,
   CatalogNumber varchar(20) NOT NULL,
   PublisherId int NOT null --not requiring this information

   CONSTRAINT PKAlbum PRIMARY KEY CLUSTERED(AlbumId),
   CONSTRAINT AKAlbum_Name UNIQUE NONCLUSTERED (Name),
   CONSTRAINT FKMusic_Artist$records$Music_Album
            FOREIGN KEY (ArtistId) REFERENCES Music.Artist(ArtistId),
   CONSTRAINT FKMusic_Publisher$published$Music_Album
            FOREIGN KEY (PublisherId) REFERENCES Music.Publisher(PublisherId)
)
GO

INSERT  INTO Music.Publisher (PublisherId, Name, CatalogNumberMask)
VALUES (1,'Capitol',
        '[0-9][0-9][0-9]-[0-9][0-9][0-9a-z][0-9a-z][0-9a-z]-[0-9][0-9]'),
        (2,'MCA', '[a-z][a-z][0-9][0-9][0-9][0-9][0-9]')

INSERT  INTO Music.Artist(ArtistId, Name)
VALUES (1, 'The Beatles'),(2, 'The Who')

INSERT INTO Music.Album (AlbumId, Name, ArtistId, PublisherId, CatalogNumber)
VALUES (1, 'The White Album',1,1,'433-43ASD-33'),
       (2, 'Revolver',1,1,'111-11111-11'),
       (3, 'Quadrophenia',2,2,'CD12345')
GO

ALTER TABLE Music.Artist WITH CHECK
   ADD CONSTRAINT chkMusic_Artist$Name$NoDuranNames
           CHECK (Name not like '%Duran%')
GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - Declarative Data Protection - [WITH CHECK | WITH NOCHECK]
------------------------------------------------------------------------------------------------------

INSERT INTO Music.Artist(ArtistId, Name)
VALUES (3, 'Duran Duran')
GO

INSERT INTO Music.Artist(ArtistId, Name)
VALUES (3, 'Madonna')
GO

ALTER TABLE Music.Artist WITH NOCHECK
   ADD CONSTRAINT chkMusic_Artist$Name$noMadonnaNames
           CHECK (Name not like '%Madonna%')

Go

UPDATE Music.Artist
SET Name = Name
GO

SELECT CHECK_CLAUSE,
       objectproperty(object_id(CONSTRAINT_SCHEMA + '.' +
                                 CONSTRAINT_NAME),'CnstIsNotTrusted') AS NotTrusted
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'Music'
  And CONSTRAINT_NAME = 'chkMusic_Artist$Name$noMadonnaNames'


------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - Declarative Data Protection - CHECK Constraints Based on Simple Expressions
------------------------------------------------------------------------------------------------------

INSERT INTO Music.Album ( AlbumId, Name, ArtistId, PublisherId, CatalogNumber )
VALUES ( 4, '', 1, 1,'dummy value' )
GO

INSERT INTO Music.Album ( AlbumId, Name, ArtistId, PublisherId, CatalogNumber )
VALUES ( 5, '', 1, 1,'dummy value' )
GO

DELETE FROM Music.Album
WHERE  Name = ''
GO
ALTER TABLE Music.Album WITH CHECK
   ADD CONSTRAINT chkMusic_Album$Name$noEmptyString
           CHECK (LEN(RTRIM(Name)) > 0)

GO
------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - Declarative Data Protection 
--  - CHECK Constraints Based on Functions - Example Constraint That Accesses Other Tables (Entry Mask)
------------------------------------------------------------------------------------------------------
CREATE FUNCTION Music.Publisher$CatalogNumberValidate
(
   @CatalogNumber char(12),
   @PublisherId int --now based on the Artist ID
)

RETURNS bit
AS
BEGIN
   DECLARE @LogicalValue bit, @CatalogNumberMask varchar(100)

   SELECT @LogicalValue = CASE WHEN @CatalogNumber LIKE CatalogNumberMask
                                      THEN 1
                               ELSE 0  END
   FROM   Music.Publisher
   WHERE  PublisherId = @PublisherId

   RETURN @LogicalValue
END

GO

SELECT Album.CatalogNumber, Publisher.CatalogNumberMask
FROM   Music.Album as Album
         JOIN Music.Publisher as Publisher
            ON Album.PublisherId = Publisher.PublisherId
GO

ALTER TABLE Music.Album
   WITH CHECK ADD CONSTRAINT
       chkMusic_Album$CatalogNumber$CatalogNumberValidate
       CHECK (Music.Publisher$CatalogNumbervalidate
                          (CatalogNumber,PublisherId) = 1)
GO

--to find where your data is not ready for the constraint,
--you run the following query
SELECT Album.Name, Album.CatalogNumber, Publisher.CatalogNumberMask
FROM Music.Album AS Album
       JOIN Music.Publisher AS Publisher
         on Publisher.PublisherId = Album.PublisherId
WHERE Music.Publisher$CatalogNumbervalidate
                        (Album.CatalogNumber,Album.PublisherId) <> 1
GO
INSERT  Music.Album(AlbumId, Name, ArtistId, PublisherId, CatalogNumber)
VALUES  (4,'who''s next',2,2,'1')
GO
INSERT  Music.Album(AlbumId, Name, ArtistId, CatalogNumber, PublisherId)
VALUES  (4,'who''s next',2,'AC12345',2)

SELECT * FROM Music.Album
GO

SELECT *
FROM   Music.Album AS Album
          JOIN Music.Publisher AS Publisher
                on Publisher.PublisherId = Album.PublisherId
WHERE  Music.Publisher$CatalogNumbervalidate
                        (Album.CatalogNumber,Album.PublisherId) <> 1
GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - Declarative Data Protection 
--  - CHECK Constraints Based on Functions - Example Constraint That Accesses Other Rows (Cardinality Enforcement)
------------------------------------------------------------------------------------------------------
CREATE SCHEMA alt
go
CREATE TABLE alt.employee
(
    employeeId    int NOT NULL CONSTRAINT PKalt_employee PRIMARY KEY,
    employeeNumber char(4) NOT NULL
                      CONSTRAINT AKalt_employee_employeeNumber UNIQUE
)
CREATE TABLE alt.office
(
    officeId int NOT NULL CONSTRAINT PKalt_office PRIMARY KEY,
    officeNumber char(4) NOT NULL
                     CONSTRAINT AKalt_office_officeNumber UNIQUE,
)
GO

CREATE TABLE alt.employeeOfficeAssignment
(
       employeeId int,
       officeId  int,
       CONSTRAINT PKalt_employeeOfficeAssignment
                PRIMARY KEY (employeeId, officeId),
       CONSTRAINT FKemployeeOfficeAssignment$assignsAnOfficeTo$employee
                FOREIGN KEY (employeeId) REFERENCES alt.employee(employeeId),
       CONSTRAINT FKemployeeOfficeAssignment$assignsAnOfficeTo$officeId
                FOREIGN KEY (officeId) REFERENCES alt.office(officeId)
)

GO

ALTER TABLE alt.employeeOfficeAssignment
    ADD CONSTRAINT AKemployeeOfficeAssignment_employee UNIQUE (employeeId)
GO

INSERT alt.employee(employeeId, employeeNumber)
VALUES (1,'A001'),
       (2,'A002'),
       (3,'A003')

INSERT INTO alt.office(officeId,officeNumber)
VALUES (1,'3001'),
       (2,'3002'),
       (3,'3003')
GO

CREATE FUNCTION alt.employeeOfficeAssignment$officeEmployeeCount
( @officeId int)
RETURNS int AS
 BEGIN
    RETURN (SELECT count(*)
            FROM   alt.employeeOfficeAssignment
            WHERE  officeId = @officeId
            )
  END
GO

ALTER TABLE alt.employeeOfficeAssignment
    ADD CONSTRAINT CHKalt_employeeOfficeAssignment_employeesInOfficeTwoOrLess
         CHECK (alt.employeeOfficeAssignment$officeEmployeeCount(officeId) <= 2)
GO

INSERT alt.employeeOfficeAssignment(officeId, employeeId)
VALUES (1,1)
GO
INSERT alt.employeeOfficeAssignment(officeId, employeeId)
VALUES (1,2)
GO

INSERT alt.employeeOfficeAssignment(officeId, employeeId)
VALUES (1,3)
GO
INSERT alt.employeeOfficeAssignment(officeId, employeeId)
VALUES (2,3)
GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - Declarative Data Protection 
--  - CHECK Constraints Based on Functions - Errors Caused by Constraints
------------------------------------------------------------------------------------------------------

CREATE SCHEMA utility
CREATE TABLE utility.ErrorMap
(
    ConstraintName sysname primary key,
    Message         varchar(2000)
)
go
INSERT utility.ErrorMap(constraintName, message)
VALUES ('chkMusic_Album$CatalogNumber$CatalogNumberValidate',
        'The catalog number does not match the format set up by the Publisher')
GO

CREATE PROCEDURE utility.ErrorMap$MapError
(
    @ErrorNumber  int = NULL,
    @ErrorMessage nvarchar(2000) = NULL,
    @ErrorSeverity INT= NULL,
    @ErrorState INT = NULL
) AS
  BEGIN
    --use values in ERROR_ functions unless the user passes in values
    SET @ErrorNumber = Coalesce(@ErrorNumber, ERROR_NUMBER())
    SET @ErrorMessage = Coalesce(@ErrorMessage, ERROR_MESSAGE())
    SET @ErrorSeverity = Coalesce(@ErrorSeverity, ERROR_SEVERITY())
    SET @ErrorState = Coalesce(@ErrorState,ERROR_STATE())

    DECLARE @originalMessage nvarchar(2000)
    SET @originalMessage = ERROR_MESSAGE()


    IF @ErrorNumber = 547
      BEGIN
        SET @ErrorMessage =
                        (SELECT message
                         FROM   utility.ErrorMap
                         WHERE  constraintName =
         --this substring pulls the constraint name from the message
         substring( @ErrorMessage,CHARINDEX('constraint "',@ErrorMessage) + 12,
                             charindex('"',substring(@ErrorMessage,
                             CHARINDEX('constraint "',@ErrorMessage) +
                                                                12,2000))-1)
                            )      END
    ELSE
        SET @ErrorMessage = @ErrorMessage

    SET @ErrorState = CASE when @ErrorState = 0 THEN 1 ELSE @ErrorState END

    --if the error was not found, get the original message
    SET @ErrorMessage = isNull(@ErrorMessage, @originalMessage)
    RAISERROR (@ErrorMessage, @ErrorSeverity,@ErrorState )
  END
GO
BEGIN TRY
     INSERT  Music.Album(AlbumId, Name, ArtistId, CatalogNumber, PublisherId)
     VALUES  (5,'who are you',2,'badnumber',2)
END TRY
BEGIN CATCH
    EXEC utility.ErrorMap$MapError
END CATCH
GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - AFTER Triggers
------------------------------------------------------------------------------------------------------
/*
CREATE TRIGGER <schema>.<tablename>$<actions>[<purpose>]Trigger
ON <schema>.<tablename>
AFTER <comma delimited actions> AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
*/
CREATE TABLE utility.ErrorLog(
        ERROR_NUMBER int NOT NULL,
        ERROR_LOCATION sysname NOT NULL,
        ERROR_MESSAGE varchar(4000),
        ERROR_DATE datetime NULL
              CONSTRAINT dfltErrorLog_error_date  DEFAULT (getdate()),
        ERROR_USER sysname NOT NULL
              --use original_login to capture the user name of the actual user
              --not a user they have impersonated
              CONSTRAINT dfltErrorLog_error_user_name DEFAULT (original_login())
)
GO
CREATE PROCEDURE utility.ErrorLog$insert
(
        @ERROR_NUMBER int = NULL,
        @ERROR_LOCATION sysname = NULL,
        @ERROR_MESSAGE varchar(4000) = NULL
) as
 BEGIN
        BEGIN TRY
           INSERT INTO utility.ErrorLog(ERROR_NUMBER,
                                         ERROR_LOCATION, ERROR_MESSAGE)
           SELECT isnull(@ERROR_NUMBER,ERROR_NUMBER()),
                  isnull(@ERROR_LOCATION,ERROR_MESSAGE()),
                  isnull(@ERROR_MESSAGE,ERROR_MESSAGE())
        END TRY
        BEGIN CATCH
           INSERT INTO utility.ErrorLog(ERROR_NUMBER,
                                         ERROR_LOCATION, ERROR_MESSAGE)
           VALUES (-100, 'utility.ErrorLog$insert',
                        'An invalid call was made to the error log procedure')
        END CATCH
END
GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - AFTER Triggers
--   - Range Checks on Multiple Rows
------------------------------------------------------------------------------------------------------
CREATE SCHEMA Accounting
GO
CREATE TABLE Accounting.Account
(
        AccountNumber        char(10)
                  constraint PKAccounting_Account primary key
        --would have other columns
)

CREATE TABLE Accounting.AccountActivity
(
        AccountNumber                char(10)
            constraint Accounting_Account$has$Accounting_AccountActivity
                       foreign key references Accounting.Account(AccountNumber),
       --this might be a value that each ATM/Teller generates
        TransactionNumber            char(20),
        Date                         datetime,
        TransactionAmount            numeric(12,2),
        constraint PKAccounting_AccountActivity
                      PRIMARY KEY (AccountNumber, TransactionNumber)
)
GO

CREATE TRIGGER Accounting.AccountActivity$insertUpdateTrigger
ON Accounting.AccountActivity
AFTER INSERT,UPDATE AS
BEGIN
   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY

   --[validation section]
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   inserted
                             WHERE  inserted.AccountNumber =
                               AccountActivity.AccountNumber)
                   GROUP BY AccountNumber
                   HAVING sum(TransactionAmount) < 0)
      BEGIN
         IF @rowsAffected = 1
             SELECT @msg = 'Account: ' + AccountNumber +
                  ' TransactionNumber:' +
                   cast(TransactionNumber as varchar(36)) +
                   ' for amount: ' + cast(TransactionAmount as varchar(10))+
                   ' cannot be processed as it will cause a negative balance'
             FROM   inserted
        ELSE
          SELECT @msg = 'One of the rows caused a negative balance'
         RAISERROR (@msg, 16, 1)
      END

   --[modification section]
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO

--create some set up test data
INSERT into Accounting.Account(AccountNumber)
VALUES ('1111111111')

GO
INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                         Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000001','20050712',100),
 ('1111111111','A0000000000000000002','20050713',100)
GO
INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                         Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000003','20050713',-300)
GO

--create new Account
INSERT  into Accounting.Account(AccountNumber)
VALUES ('2222222222')
GO
--Now, this data will violate the constraint for the new Account:
INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000004','20050714',100),
       ('2222222222','A0000000000000000005','20050715',100),
       ('2222222222','A0000000000000000006','20050715',100),
       ('2222222222','A0000000000000000007','20050715',-201)

GO

--Viewing trigger events

SELECT sys.trigger_events.type_desc
FROM sys.trigger_events
         JOIN sys.triggers
                  ON sys.triggers.object_id = sys.trigger_events.object_id
WHERE sys.triggers.name = 'AccountActivity$insertUpdateTrigger'

GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - AFTER Triggers
--   - Maintaining Summary Values
------------------------------------------------------------------------------------------------------
ALTER TABLE Accounting.Account
   ADD Balance numeric(12,2)
      CONSTRAINT DfltAccounting_Account_Balance DEFAULT(0.00)

GO
SELECT  Account.AccountNumber,
        SUM(coalesce(TransactionAmount,0.00)) AS NewBalance
FROM   Accounting.Account
        LEFT OUTER JOIN Accounting.AccountActivity
            ON Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber
GO

WITH  Updater as (
SELECT  Account.AccountNumber,
        SUM(coalesce(TransactionAmount,0.00)) as NewBalance
FROM   Accounting.Account
        LEFT OUTER JOIN Accounting.AccountActivity
            On Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber, Account.Balance)
UPDATE Account
SET    Balance = Updater.NewBalance
FROM   Accounting.Account
         JOIN Updater
                on Account.AccountNumber = Updater.AccountNumber
GO

ALTER TRIGGER Accounting.AccountActivity$insertUpdateTrigger
ON Accounting.AccountActivity
AFTER INSERT,UPDATE AS
BEGIN
   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY

   --[validation section]
   --disallow Transactions that would put balance into negatives
   IF EXISTS ( SELECT AccountNumber
               FROM Accounting.AccountActivity as AccountActivity
               WHERE EXISTS (SELECT *
                             FROM   inserted
                             WHERE  inserted.AccountNumber =
                               AccountActivity.AccountNumber)
                   GROUP BY AccountNumber
                   HAVING sum(TransactionAmount) < 0)
      BEGIN
         IF @rowsAffected = 1
             SELECT @msg = 'Account: ' + AccountNumber +
                  ' TransactionNumber:' +
                   cast(TransactionNumber as varchar(36)) +
                   ' for amount: ' + cast(TransactionAmount as varchar(10))+
                   ' cannot be processed as it will cause a negative balance'
             FROM   inserted
        ELSE
          SELECT @msg = 'One of the rows caused a negative balance'
         RAISERROR (@msg, 16, 1)
      END

    --[modification section]
    IF UPDATE (TransactionAmount)
        WITH  Updater as (
        SELECT  Account.AccountNumber,
                SUM(coalesce(TransactionAmount,0.00)) as NewBalance
        FROM   Accounting.Account
                LEFT OUTER JOIN Accounting.AccountActivity
                    On Account.AccountNumber = AccountActivity.AccountNumber
               --This where clause limits the summarizations to those rows
               --that were modified by the DML statement that caused
               --this trigger to fire.
        WHERE  EXISTS (SELECT *
                       FROM   Inserted
                       WHERE  Account.AccountNumber = Inserted.AccountNumber)
        GROUP  BY Account.AccountNumber, Account.Balance)
        UPDATE Account
        SET    Balance = Updater.NewBalance
        FROM   Accounting.Account
                  JOIN Updater
                      on Account.AccountNumber = Updater.AccountNumber

   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO
INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000004','20050714',100)
GO

SELECT  Account.AccountNumber,
        SUM(coalesce(TransactionAmount,0.00)) AS NewBalance
FROM   Accounting.Account
        LEFT OUTER JOIN Accounting.AccountActivity
            ON Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber
GO

INSERT  into Accounting.AccountActivity(AccountNumber, TransactionNumber,
                                        Date, TransactionAmount)
VALUES ('1111111111','A0000000000000000005','20050714',100),
       ('2222222222','A0000000000000000006','20050715',100),
       ('2222222222','A0000000000000000007','20050715',100)
GO

SELECT  Account.AccountNumber,
        SUM(coalesce(TransactionAmount,0.00)) AS NewBalance
FROM   Accounting.Account
        LEFT OUTER JOIN Accounting.AccountActivity
            ON Account.AccountNumber = AccountActivity.AccountNumber
GROUP  BY Account.AccountNumber
GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - AFTER Triggers
--   - Cascading Inserts
------------------------------------------------------------------------------------------------------

CREATE SCHEMA Internet
go
CREATE TABLE Internet.Url
(
    UrlId int not null identity(1,1) constraint PKUrl primary key,
    Name  varchar(60) not null constraint AKInternet_Url_Name UNIQUE,
    Url   varchar(200) not null constraint AKInternet_Url_Url UNIQUE
)

--Not a user manageable table, so not using identity key (as discussed in
--Chapter 5 when I discussed choosing keys) in this one table.  Others are
--using identity-based keys in this example
CREATE TABLE Internet.UrlStatusType
(
        UrlStatusTypeId  int not null
                      CONSTRAINT PKInternet_UrlStatusType PRIMARY KEY,
        Name varchar(20) NOT NULL
                      CONSTRAINT AKInternet_UrlStatusType UNIQUE,
        DefaultFlag bit NOT NULL,
        DisplayOnSiteFlag bit NOT NULL
)

CREATE TABLE Internet.UrlStatus
(
        UrlStatusId int not null identity(1,1)
                      CONSTRAINT PKInternet_UrlStatus PRIMARY KEY,
        UrlStatusTypeId int NOT NULL
                      CONSTRAINT
               Internet_UrlStatusType$defines_status_type_of$Internet_UrlStatus
                      REFERENCES Internet.UrlStatusType(UrlStatusTypeId),
        UrlId int NOT NULL
          CONSTRAINT Internet_Url$has_status_history_in$Internet_UrlStatus
                      REFERENCES Internet.Url(UrlId),
        ActiveTime        datetime,
        CONSTRAINT AKInternet_UrlStatus_statusUrlDate
                      UNIQUE (UrlStatusTypeId, UrlId, ActiveTime)
)
--set up status types
INSERT  Internet.UrlStatusType (UrlStatusTypeId, Name,
                                   DefaultFlag, DisplayOnSiteFlag)
VALUES (1, 'Unverified',1,0),
       (2, 'Verified',0,1),
       (3, 'Unable to locate',0,0)
GO

CREATE TRIGGER Internet.Url$afterInsertTrigger
ON Internet.Url
AFTER INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]

           --[modification section]

          --add a row to the UrlStatus table to tell it that the new row
          --should start out as the default status
          INSERT INTO Internet.UrlStatus (UrlId, UrlStatusTypeId, ActiveTime)
          SELECT INSERTED.UrlId, UrlStatusType.UrlStatusTypeId,
                  current_timestamp
          FROM INSERTED
                CROSS JOIN (SELECT UrlStatusTypeId
                            FROM   UrlStatusType
                            WHERE  DefaultFlag = 1)  as UrlStatusType
                                           --use cross join with a WHERE clause
                                           --as this is not technically a join
                                           --between INSERTED and UrlType
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              --or this will not get rolled back
              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO
INSERT  into Internet.Url(Name, Url)
VALUES ('More info can be found here',
        'http://sqlblog.com/blogs/louis_davidson/default.aspx')

SELECT * FROM Internet.Url
SELECT * FROM Internet.UrlStatus

GO
------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - AFTER Triggers
--   - Cascading from Child to Parent
------------------------------------------------------------------------------------------------------
--start a schema for entertainment-related tables
CREATE SCHEMA Entertainment
go
CREATE TABLE Entertainment.GamePlatform
(
    GamePlatformId int CONSTRAINT PKGamePlatform PRIMARY KEY,
    Name  varchar(20) CONSTRAINT AKGamePlatform_Name UNIQUE
)
CREATE TABLE Entertainment.Game
(
    GameId  int CONSTRAINT PKGame PRIMARY KEY,
    Name    varchar(20) CONSTRAINT AKGame_Name UNIQUE
    --more details that are common to all platforms
)

--associative entity with cascade relationships back to Game and GamePlatform
CREATE TABLE Entertainment.GameInstance
(
    GamePlatformId int,
    GameId int,
    PurchaseDate date,
    CONSTRAINT PKGameInstance PRIMARY KEY (GamePlatformId, GameId),
    CONSTRAINT
    Entertainment_Game$is_owned_on_platform_by$Entertainment_GameInstance
      FOREIGN KEY (GameId)REFERENCES Entertainment.Game(GameId)
                                               ON DELETE CASCADE,
      CONSTRAINT
        Entertainment_GamePlatform$is_linked_to$Entertainment_GameInstance
      FOREIGN KEY (GamePlatformId)
           REFERENCES Entertainment.GamePlatform(GamePlatformId)
                ON DELETE CASCADE
)
GO
INSERT  into Entertainment.Game (GameId, Name)
VALUES (1,'Super Mario Bros'),
       (2,'Legend Of Zelda')

INSERT  into Entertainment.GamePlatform(GamePlatformId, Name)
VALUES (1,'Nintendo Wii'),   --Yes, as a matter of fact I am a
       (2,'Nintendo DS')     --Nintendo Fanboy, why do you ask?

INSERT  into Entertainment.GameInstance(GamePlatformId, GameId, PurchaseDate)
VALUES (1,1,'20060404'),
       (1,2,'20070510'),
       (2,2,'20070404')

--the full outer joins ensure that all rows are returned from all sets, leaving
--nulls where data is missing
SELECT  GamePlatform.Name as Platform, Game.Name as Game, GameInstance. PurchaseDate
FROM    Entertainment.Game as Game
            full outer join Entertainment.GameInstance as GameInstance
                    on Game.GameId = GameInstance.GameId
            full outer join Entertainment.GamePlatform
                    on GamePlatform.GamePlatformId = GameInstance.GamePlatformId

GO

CREATE TRIGGER Entertainment.GameInstance$afterDeleteTrigger
ON Entertainment.GameInstance
AFTER delete AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
        --[validation section]

        --[modification section]
        --delete all Games
        DELETE Game       --where the GameInstance was delete
        WHERE  GameId in (SELECT deleted.GameId
                          FROM   deleted     --and there are no GameInstances 
                           WHERE  not exists (SELECT  *        --left
                                              FROM    GameInstance
                                              WHERE   GameInstance.GameId =
                                                               deleted.GameId))
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO
DELETE  Entertainment.GamePlatform
WHERE   GamePlatformId = 1
go
SELECT  GamePlatform.Name as platform, Game.Name as Game, GameInstance. PurchaseDate
FROM    Entertainment.Game as Game
            FULL OUTER JOIN Entertainment.GameInstance as GameInstance
                    on Game.GameId = GameInstance.GameId
            FULL OUTER JOIN Entertainment.GamePlatform
                    on GamePlatform.GamePlatformId = GameInstance.GamePlatformId
GO




------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - AFTER Triggers
--   - Maintaining an Audit Trail
------------------------------------------------------------------------------------------------------
CREATE SCHEMA hr
go
CREATE TABLE hr.employee
(
    employee_id char(6) CONSTRAINT PKhr_employee PRIMARY KEY,
    first_name  varchar(20),
    last_name   varchar(20),
    salary      money
)
CREATE TABLE hr.employee_auditTrail
(
    employee_id          char(6),
    date_changed         datetime not null --default so we don't have to
                                           --code for it
          CONSTRAINT DfltHr_employee_date_changed DEFAULT (current_timestamp),
    first_name           varchar(20),
    last_name            varchar(20),
    salary               decimal(12,2),
    --the following are the added columns to the original
    --structure of hr.employee
    action               char(6)
          CONSTRAINT ChkHr_employee_action --we don't log inserts, only changes
                                          CHECK(action in ('delete','update')),
    changed_by_user_name sysname
                CONSTRAINT DfltHr_employee_changed_by_user_name
                                          DEFAULT (original_login()),
    CONSTRAINT PKemployee_auditTrail PRIMARY KEY (employee_id, date_changed)
)
GO

CREATE TRIGGER hr.employee$insertAndDeleteAuditTrailTrigger
ON hr.employee
AFTER UPDATE, DELETE AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount
   BEGIN TRY
          --[validation section]
          --[modification section]
          --since we are only doing update and delete, we just
          --need to see if there are any rows
          --inserted to determine what action is being done.
          DECLARE @action char(6)
          SET @action = case when (SELECT count(*) from inserted) > 0
                        then 'update' else 'delete' end

          --since the deleted table contains all changes, we just insert all
          --of the rows in the deleted table and we are done.
          INSERT employee_auditTrail (employee_id, first_name, last_name,
                                     salary, action)
          SELECT employee_id, first_name, last_name, salary, @action
          FROM   deleted

   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE varchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO
INSERT hr.employee (employee_id, first_name, last_name, salary)
VALUES (1, ' Phillip','Taibul',10000)
GO
UPDATE hr.employee
SET salary = salary * 1.10 --ten percent raise!
WHERE employee_id = 1

SELECT *
FROM   hr.employee
GO
SELECT *
FROM   hr.employee_auditTrail
GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - INSTEAD OF Triggers
------------------------------------------------------------------------------------------------------

/*
CREATE TRIGGER <schema>.<tablename>$InsteadOf<actions>[<purpose>]Trigger
ON <schema>.<tablename>
INSTEAD OF <comma delimited actions> AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
*/
------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - INSTEAD OF Triggers
--   - Automatically Maintaining Columns
------------------------------------------------------------------------------------------------------
CREATE SCHEMA school
Go
CREATE TABLE school.student
(
      studentId       int identity not null
            CONSTRAINT PKschool_student PRIMARY KEY,
      studentIdNumber char(8) not null
            CONSTRAINT AKschool_student_studentIdNumber UNIQUE,
      firstName       varchar(20) not null,
      lastName        varchar(20) not null,
--Note that we add these columns to the implementation model, not to the logical
--model. These columns do not actually refer to the student being modeled, they are
--required simply to help with programming and tracking.
      rowCreateDate   datetime not null
            CONSTRAINT dfltSchool_student_rowCreateDate
                                 DEFAULT (current_timestamp),
      rowCreateUser   sysname not null
            CONSTRAINT dfltSchool_student_rowCreateUser DEFAULT (current_user)
)
GO

CREATE TRIGGER school.student$insteadOfInsert
ON school.student
INSTEAD OF INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET ROWCOUNT 0 --in case the client has modified the rowcount
   SET NOCOUNT ON --to avoid the rowcount messages

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO school.student(studentIdNumber, firstName, lastName,
                                     rowCreateDate, rowCreateUser)
          SELECT studentIdNumber, firstName, lastName,
                                        current_timestamp, suser_sname()
          FROM  inserted   --no matter what the user put in the inserted row
   END TRY         --when the row was created, these values will be inserted
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO
INSERT  into school.student(studentIdNumber, firstName, lastName)
VALUES ( '0000001',' Gray', ' Tezine' )

GO
SELECT * FROM school.student
GO
INSERT  school.student(studentIdNumber, firstName, lastName, rowCreateDate,
                       rowCreateUser)
VALUES ( '000002','Norm', 'Ull','99990101','some user' )
GO
SELECT * FROM school.student
GO

------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - INSTEAD OF Triggers
--   - Formatting User Input
------------------------------------------------------------------------------------------------------
CREATE FUNCTION Utility.TitleCase
(
   @inputString varchar(2000)
)
RETURNS varchar(2000) AS
BEGIN
   -- set the whole string to lower
   SET @inputString = LOWER(@inputstring)
   -- then use stuff to replace the first character
   SET @inputString =
   --STUFF in the uppercased character in to the next character,
   --replacing the lowercased letter
   STUFF(@inputString,1,1,UPPER(SUBSTRING(@inputString,1,1)))

   --@i is for the loop counter, initialized to 2
   DECLARE @i int
   SET @i = 1

   --loop from the second character to the end of the string
   WHILE @i < LEN(@inputString)
   BEGIN
      --if the character is a space
      IF SUBSTRING(@inputString,@i,1) = ' '
      BEGIN
         --STUFF in the uppercased character into the next character
         SET @inputString = STUFF(@inputString,@i +
         1,1,UPPER(SUBSTRING(@inputString,@i + 1,1)))
      END
      --increment the loop counter
      SET @i = @i + 1
   END
   RETURN @inputString
END
GO

ALTER TRIGGER school.student$insteadOfInsert
ON school.student
INSTEAD OF INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET ROWCOUNT 0 --in case the client has modified the rowcount
   SET NOCOUNT ON --to avoid the rowcount messages

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
          INSERT INTO school.student(studentIdNumber, firstName, lastName,
                                     rowCreateDate, rowCreateUser)

          SELECT studentIdNumber,
                 Utility.titleCase(firstName),
                 Utility.titleCase(lastName),
                 current_timestamp, suser_sname()
          FROM  inserted   --no matter what the user put in the inserted row
   END TRY                 --when the row was created, these values will be inserted
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO

INSERT school.student(studentIdNumber, firstName, lastName)
VALUES ( '0000007','CaPtain', 'von nuLLY')
GO

SELECT *
FROM school.student

GO
------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - INSTEAD OF Triggers
--   - Redirecting Invalid Data to an Exception Table
------------------------------------------------------------------------------------------------------

CREATE SCHEMA Measurements
go
CREATE TABLE Measurements.WeatherReading
(
    WeatherReadingId int identity
          CONSTRAINT PKWeatherReading PRIMARY KEY,
    ReadingTime   datetime
          CONSTRAINT AKMeasurements_WeatherReading_Date UNIQUE,
    Temperature     float
          CONSTRAINT chkMeasurements_WeatherReading_Temperature
                      CHECK(Temperature between -80 and 150)
                      --raised from last edition for global warming
)
GO
INSERT  into Measurements.WeatherReading (ReadingTime, Temperature)
VALUES ('20080101 0:00',82.00), ('20080101 0:01',89.22),
       ('20080101 0:02',600.32),('20080101 0:03',88.22),
       ('20080101 0:04',99.01)
GO

CREATE TABLE Measurements.WeatherReading_exception
(
    WeatherReadingId  int identity
          CONSTRAINT PKMeasurements_WeatherReading_exception PRIMARY KEY,
    ReadingTime       datetime,
    Temperature       float
)
GO

CREATE TRIGGER Measurements.WeatherReading$InsteadOfInsertTrigger
ON Measurements.WeatherReading
INSTEAD OF INSERT AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return

   SET NOCOUNT ON --to avoid the rowcount messages
   SET ROWCOUNT 0 --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]

          --<perform action>

           --BAD data
          INSERT Measurements.WeatherReading_exception
                                     (ReadingTime, Temperature)
          SELECT ReadingTime, Temperature
          FROM   inserted
          WHERE  NOT(Temperature between -80 and 120)

           --GOOD data
          INSERT Measurements.WeatherReading (ReadingTime, Temperature)
          SELECT ReadingTime, Temperature
          FROM   inserted
          WHERE  (Temperature between -80 and 120)
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION

              EXECUTE utility.ErrorLog$insert

              DECLARE @ERROR_MESSAGE nvarchar(4000)
              SET @ERROR_MESSAGE = ERROR_MESSAGE()
              RAISERROR (@ERROR_MESSAGE,16,1)

     END CATCH
END
GO

INSERT  into Measurements.WeatherReading (ReadingTime, Temperature)
VALUES ('20080101 0:00',82.00), ('20080101 0:01',89.22),
       ('20080101 0:02',600.32),('20080101 0:03',88.22),
       ('20080101 0:04',99.01)

SELECT *
FROM Measurements.WeatherReading
GO

SELECT *
FROM   Measurements.WeatherReading_exception
GO



------------------------------------------------------------------------------------------------------
-- Automatic Data Protection - DML Triggers - INSTEAD OF Triggers
--   - Forcing No Action to Be Performed on a Table
------------------------------------------------------------------------------------------------------

CREATE SCHEMA System
go
CREATE TABLE System.Version
(
    DatabaseVersion varchar(10)
)
INSERT  into System.Version (DatabaseVersion)
VALUES ('1.0.12')
GO

CREATE TRIGGER System.Version$InsteadOfInsertUpdateDeleteTrigger
ON System.Version
INSTEAD OF INSERT, UPDATE, DELETE AS
BEGIN

   DECLARE @rowsAffected int,    --stores the number of rows affected
           @msg varchar(2000)    --used to hold the error message

   SET @rowsAffected = @@rowcount
   --no need to complain if no rows affected
   IF @rowsAffected = 0 return

   --No error handling necessary, just the message.
   --We just put the kibosh on the action.
   RAISERROR
      ('The System.Version table may not be modified in production',
        16,1)
END

GO

delete system.version
GO
ALTER TABLE system.version
    DISABLE TRIGGER version$InsteadOfInsertUpdateDelete
Go
--------------------------------------------------------------------------------------------------
-- Handing Errors from Triggers and Constraints
--------------------------------------------------------------------------------------------------
CREATE TABLE alt.errorHandlingTest
(
    errorHandlingTestId   int CONSTRAINT PKerrorHandlingTest PRIMARY KEY,
    CONSTRAINT ChkAlt_errorHandlingTest_errorHandlingTestId_greaterThanZero
           CHECK (errorHandlingTestId > 0)
)
GO

CREATE TRIGGER alt.errorHandlingTest$afterInsertTrigger
ON alt.errorHandlingTest
AFTER INSERT
AS

    RAISERROR ('Test Error',16,1)
    ROLLBACK TRANSACTION
GO

--NO Transaction, Constraint Error
INSERT alt.errorHandlingTest
VALUES (-1)
SELECT 'continues'
GO

INSERT alt.errorHandlingTest
VALUES (1)
SELECT 'continues'
GO

BEGIN TRANSACTION
BEGIN TRY
    INSERT alt.errorHandlingTest
    VALUES (-1)
    COMMIT
END TRY
BEGIN CATCH
    SELECT  CASE XACT_STATE()
                WHEN 1 THEN 'Committable'
                WHEN 0 THEN 'No transaction'
                ELSE 'Uncommitable tran' END as XACT_STATE
            ,ERROR_NUMBER() AS ErrorNumber
            ,ERROR_MESSAGE() as ErrorMessage
    ROLLBACK TRANSACTION
END CATCH
GO

BEGIN TRANSACTION
BEGIN TRY
    INSERT alt.errorHandlingTest
    VALUES (1)
    COMMIT
END TRY
BEGIN CATCH
    SELECT  CASE XACT_STATE()
                WHEN 1 THEN 'Committable'
                WHEN 0 THEN 'No transaction'
                ELSE 'Uncommitable tran' END as XACT_STATE
            ,ERROR_NUMBER() AS ErrorNumber
            ,ERROR_MESSAGE() as ErrorMessage
    ROLLBACK TRANSACTION
END CATCH
GO


BEGIN TRY
    DECLARE @errorMessage nvarchar(4000)
    SET @errorMessage = 'Error inserting data into alt.errorHandlingTest'
    INSERT alt.errorHandlingTest
    VALUES (1)
    COMMIT TRANSACTION
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION

    --I also add in the stored procedure or trigger where the error
    --occurred also when in a coded object
    SET @errorMessage = Coalesce(@errorMessage,'') +
          ' ( System Error: ' + CAST(ERROR_NUMBER() as varchar(10)) +
          ':' + ERROR_MESSAGE() + ': Line Number:' +
          CAST(ERROR_LINE() as varchar(10)) + ')'
    RAISERROR (@errorMessage,16,1)
END CATCH


