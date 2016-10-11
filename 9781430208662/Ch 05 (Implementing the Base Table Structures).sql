SELECT   len(
            cast(replicate('a',8000) as varchar(8000))
            + cast(replicate('a',8000) as varchar(8000))
          )
GO
SELECT    len(
            cast(replicate('a',8000) as varchar(max))
            + cast(replicate('a',8000) as varchar(8000))
          )
GO
SELECT  table_name
FROM    AdventureWorks2008.information_schema.tables
WHERE   table_schema = 'Purchasing'
ORDER   BY table_name
GO

----------------------------------
-- Set up database
----------------------------------
CREATE DATABASE MovieRental
Go
USE MovieRental
GO
SELECT physical_name
FROM   sys.database_files
GO
SELECT  name, suser_sname(sid) as [login]
FROM    sys.database_principals
WHERE   name = 'dbo'
GO
ALTER AUTHORIZATION ON Database::MovieRental to SA
GO
----------------------------------
-- Schemas
----------------------------------

SELECT name, 
       SCHEMA_NAME(schema_id) as schemaName,
       USER_NAME(principal_id) as principal
FROM   AdventureWorks2008.sys.schemas
ORDER BY Name
GO
SELECT  table_name
FROM    AdventureWorks2008.information_schema.tables
WHERE   table_schema = 'Purchasing'
ORDER BY table_name
GO

CREATE SCHEMA Inventory --tables pertaining to the videos to be rented
GO
CREATE SCHEMA People --tables pertaining to people (nonspecific)
GO
CREATE SCHEMA Rentals --tables pertaining to rentals to customers
GO
CREATE SCHEMA Alt
GO

----------------------------------
-- Columns and Base Datatypes;Nulls
----------------------------------

CREATE TABLE Alt.NullTest
(
   NullColumn varchar(10) NULL,
   NotNullColumn varchar(10) NOT NULL
)
GO
SELECT   name, is_ansi_null_default_on
FROM     sys.databases
WHERE    name = 'MovieRental'
GO
ALTER DATABASE MovieRental
      SET ANSI_NULL_DEFAULT OFF
GO
--turn off default NULLs
SET ANSI_NULL_DFLT_ON OFF

--create test table
CREATE TABLE Alt.testNULL
(
   id   int
)

--check the values
EXEC sp_help 'Alt.testNULL'
GO

CREATE TABLE Inventory.Movie
(
       MovieId              int NOT NULL,
       Name                 varchar(20) NOT NULL,
       ReleaseDate          date NULL,
       Description          varchar(200) NULL,
       GenreId              int NOT NULL,
       MovieRatingId        int NOT NULL
)
GO

------------------------------------------------------------------------------------------------------
-- Columns and Base Datatypes;Surrogate Keys;Manually Managed
------------------------------------------------------------------------------------------------------

CREATE TABLE Inventory.MovieRating (
       MovieRatingId        int NOT NULL,
       Code                 varchar(20) NOT NULL,
       Description          varchar(200) NULL,
       AllowYouthRentalFlag bit NOT NULL
)
GO
INSERT INTO Inventory.MovieRating
            (MovieRatingId, Code, Description, AllowYouthRentalFlag)
VALUES     (0, 'UR','Unrated',1),
        (1, 'G','General Audiences',1),
        (2, 'PG','Parental Guidance',1),
        (3, 'PG-13','Parental Guidance for Children Under 13',1),
        (4, 'R','Restricted, No Children Under 17 without Parent',0)
GO
CREATE TABLE Inventory.Genre (
       GenreId              int NOT NULL,
       Name                 varchar(20) NOT NULL
)
GO
INSERT INTO Inventory.Genre (GenreId, Name)
VALUES (1,'Comedy'),
       (2,'Drama'),
       (3,'Thriller'),
       (4,'Documentary')
GO

------------------------------------------------------------------------------------------------------
-- Columns and Base Datatypes;Surrogate Keys;Generation Using the IDENTITY Property
------------------------------------------------------------------------------------------------------

DROP TABLE Inventory.Movie
GO
CREATE TABLE Inventory.Movie
(
       MovieId              int NOT NULL IDENTITY(1,2),
       Name                 varchar(20) NOT NULL,
       ReleaseDate          date NULL,
       Description          varchar(200) NULL,
       GenreId              int NOT NULL,
       MovieRatingId        int NOT NULL
)
GO
--Genre and Ratings values create as literal values because 
--they are built with explicit values
INSERT INTO Inventory.Movie (Name, ReleaseDate,
                             Description, GenreId, MovieRatingId)
VALUES ('The Maltese Falcon','19411003',
        'A private detective finds himself surrounded by strange people ' +
        'looking for a statue filled with jewels',2,0),
        
       ('Arsenic and Old Lace','19440923',
        'A man learns a disturbing secret about his aunt''s methods ' +
        'for treating gentleman callers',1,0)
GO
SELECT  MovieId, Name, ReleaseDate
FROM    Inventory.Movie
GO
INSERT INTO Inventory.Movie (Name, ReleaseDate,
                             Description, GenreId, MovieRatingId)
VALUES ('Arsenic and Old Lace','19440923',
        'A man learns a disturbing secret about his aunt''s methods ' +
        'for treating gentleman callers',1,0)
GO
SELECT  MovieId, Name, ReleaseDate
FROM    Inventory.Movie
GO
--add a numbering column to the set, partitioned by the duplicate names. 
--order by the MovieId, to keep the lowest key (not that it really matters)
WITH numberedRows as (
SELECT ROW_NUMBER() OVER (PARTITION BY Name ORDER BY MovieId) AS RowNumber,
       MovieId
FROM   Inventory.Movie )
--only keep one row per unique name
DELETE FROM numberedRows
WHERE  RowNumber <> 1
GO
--------------------------------------------------------------------
-- Adding Uniqueness Constraints; Adding Primary Key Constraints
--------------------------------------------------------------------

CREATE TABLE Inventory.MovieFormat (
       MovieFormatId        int NOT NULL
          CONSTRAINT PKInventory_MovieFormat PRIMARY KEY CLUSTERED,
       Name                 varchar(20) NOT NULL
)
GO
INSERT INTO Inventory.MovieFormat(MovieFormatId, Name)
VALUES  (1,'Video Tape')
       ,(1,'DVD')
GO
INSERT INTO Inventory.MovieFormat(MovieFormatId, Name)
VALUES  (1,'Video Tape')
       ,(2,'DVD')
GO

CREATE TABLE Alt.Product
(
   Manufacturer varchar(30) NOT NULL,
   ModelNumber varchar(30) NOT NULL,
   CONSTRAINT PKAlt_Product PRIMARY KEY NONCLUSTERED (Manufacturer, ModelNumber)
)
DROP TABLE Alt.Product
GO

ALTER TABLE Inventory.MovieRating
   ADD CONSTRAINT PKInventory_MovieRating PRIMARY KEY CLUSTERED (MovieRatingId)

ALTER TABLE Inventory.Genre
   ADD CONSTRAINT PKInventory_Genre PRIMARY KEY CLUSTERED (GenreId)

ALTER TABLE Inventory.Movie
   ADD CONSTRAINT PKInventory_Movie PRIMARY KEY CLUSTERED (MovieId)
GO

CREATE TABLE Test (TestId int PRIMARY KEY)
GO
SELECT constraint_name 
FROM   information_schema.table_constraints 
WHERE  table_schema = 'dbo' 
  and  table_name = 'test'
GO

--------------------------------------------------------------------
-- Adding Uniqueness Constraints; Adding Alternate Keys Constraints
--------------------------------------------------------------------

CREATE TABLE Inventory.Personality
(
       PersonalityId        int NOT NULL IDENTITY(1,1)
            CONSTRAINT PKInventory_Personality PRIMARY KEY,
       FirstName            varchar(20) NOT NULL,
       LastName             varchar(20) NOT NULL,
       NameUniqueifier      varchar(5) NOT NULL,
            CONSTRAINT AKInventory_Personality_PersonalityName 
                UNIQUE NONCLUSTERED (FirstName, LastName, NameUniqueifier)
)

ALTER TABLE Inventory.Genre
  ADD CONSTRAINT AKInventory_Genre_Name UNIQUE NONCLUSTERED (Name)

ALTER TABLE Inventory.MovieRating
  ADD CONSTRAINT AKInventory_MovieRating_Code UNIQUE NONCLUSTERED (Code)

ALTER TABLE Inventory.Movie
  ADD CONSTRAINT AKInventory_Movie_NameAndDate 
      UNIQUE NONCLUSTERED (Name, ReleaseDate)
GO

--------------------------------------------------------------------
-- Adding Uniqueness Constraints; Implementing Selective Uniqueness
--------------------------------------------------------------------
CREATE TABLE alt.employee
(
    EmployeeId int identity(1,1) constraint PKalt_employee primary key,
    EmployeeNumber char(5) not null 
           CONSTRAINT AKalt_employee_employeeNummer UNIQUE,
    --skipping other columns you would likely have
    InsurancePolicyNumber char(10) null
)
go
--Filtered Alternate Key (AKF)
CREATE UNIQUE INDEX AKFalt_employee_InsurancePolicyNumber ON 
                                    alt.employee(InsurancePolicyNumber)
WHERE InsurancePolicyNumber is not null
GO
INSERT INTO Alt.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0001','1111111111')
GO
INSERT INTO Alt.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0002','1111111111')
GO
INSERT INTO Alt.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0003','2222222222'),
       ('A0004',NULL),
       ('A0005',NULL)
GO
CREATE TABLE Alt.AccountContact
(
    ContactId   varchar(10) not null,
    AccountNumber   char(5) not null, --would be FK
    PrimaryContactFlag bit not null,
    CONSTRAINT PKalt_accountContact 
        PRIMARY KEY(ContactId, AccountNumber)
)
GO
CREATE UNIQUE INDEX 
    AKFAlt_AccountContact_PrimaryContact
            ON Alt.AccountContact(AccountNumber) 
            WHERE PrimaryContactFlag = 1
GO
INSERT INTO Alt.AccountContact
SELECT 'bob','11111',1
go
INSERT INTO Alt.AccountContact
SELECT 'fred','11111',1
GO
BEGIN TRANSACTION
 
UPDATE Alt.AccountContact
SET primaryContactFlag = 0
WHERE  accountNumber = '11111'
 
INSERT Alt.AccountContact
SELECT 'fred','11111',1
 
COMMIT TRANSACTION
GO
CREATE VIEW Alt.Employee_InsurancePolicyNumberUniqueness
WITH SCHEMABINDING
AS
    SELECT  InsurancePolicyNumber
    FROM    Alt.Employee
    WHERE   InsurancePolicyNumber is not null
GO
CREATE UNIQUE CLUSTERED INDEX 
    AKalt_Employee_InsurancePolicyNumberUniqueness 
    ON alt.Employee_InsurancePolicyNumberUniqueness(InsurancePolicyNumber) 
GO

--------------------------------------------------------------------
-- Adding Uniqueness Constraints; Viewing the Constraints
--------------------------------------------------------------------
SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM   INFORMATION_SCHEMA.table_constraints
WHERE  CONSTRAINT_SCHEMA = 'Inventory'
ORDER  BY  CONSTRAINT_SCHEMA, TABLE_NAME
GO

--------------------------------------------------------------------
-- Building Default Constraints; Literals
--------------------------------------------------------------------

CREATE TABLE People.Person (
       PersonId             int NOT NULL IDENTITY(1,1)
          CONSTRAINT PKPerson PRIMARY KEY,
       FirstName            varchar(20) NOT NULL,
       MiddleName           varchar(20) NULL,
       LastName             varchar(20) NOT NULL,
       SocialSecurityNumber char(11) --will be redefined using CLR later
          CONSTRAINT AKPeople_Person_SSN UNIQUE
)

CREATE TABLE Rentals.Customer (
       CustomerId           int NOT NULL
          CONSTRAINT PKRentals_Customer PRIMARY KEY,
       CustomerNumber       char(10)
          CONSTRAINT AKRentals_Customer_CustomerNumber UNIQUE,
       PrimaryCustomerId    int NULL,
       Picture              varbinary(max) NULL,
       YouthRentalsOnlyFlag bit NOT NULL
          CONSTRAINT People_Person$can_be_a$Rentals_Customer
                FOREIGN KEY (CustomerId)
                             REFERENCES People.Person  (PersonId)
                             ON DELETE CASCADE  --cascade delete on SubType
                             ON UPDATE NO ACTION,
          CONSTRAINT   
              Rentals_Customer$can_rent_on_the_account_of$Rentals_Customer
                FOREIGN KEY (PrimaryCustomerId)
                             REFERENCES Rentals.Customer  (CustomerId)
                             ON DELETE NO ACTION
                             ON UPDATE NO ACTION
)
Go
ALTER TABLE Rentals.Customer
   ADD CONSTRAINT DfltRentals_Customer_YouthRentalsOnlyFlag DEFAULT (0)
        FOR YouthRentalsOnlyFlag
GO
INSERT INTO People.Person(FirstName, MiddleName, LastName, SocialSecurityNumber)
VALUES ('Doe','','Maign','111-11-1111')
--skipping several of the columns that are either nullable or have defaults
INSERT INTO Rentals.Customer(CustomerId, CustomerNumber)
SELECT Person.PersonId, '1111111111'
FROM   People.Person
WHERE  SocialSecurityNumber = '111-11-1111'
GO
SELECT CustomerNumber, YouthRentalsOnlyFlag
FROM   Rentals.Customer
GO


--Using the Alt schema for alternative examples
CREATE TABLE Alt.url
(
       scheme        varchar(10) NOT NULL, --http, ftp
       computerName  varchar(50) NOT NULL, --www, or whatever
                         --base domain name (microsoft, amazon, etc.)
       domainName varchar(50) NOT NULL,
       siteType varchar(5) NOT NULL, --net, com, org
       filePath varchar(255) NOT NULL,
       fileName varchar(20) NOT NULL,
       parameter varchar(255) NOT NULL,
              CONSTRAINT PKAlt_Url  PRIMARY KEY (scheme, computerName, 
                                            domainName, siteType,
                                            filePath, fileName, parameter)
)
GO
INSERT INTO alt.url (scheme, computerName, domainName, siteType,
                            filePath, filename, parameter)
VALUES ('http','www','microsoft','com','','','')

--then display the data
SELECT   scheme + '://' + computerName +
                 case when len(rtrim(computerName)) > 0 then '.' else '' end +
                 domainName + '.'
         + siteType
         + case when len(filePath) > 0 then '/' else '' end + filePath
         + case when len(fileName) > 0 then '/' else '' end + fileName
         + parameter as display
FROM alt.url
GO

ALTER TABLE Alt.url
   ADD CONSTRAINT DFLTAlt_Url_scheme
   DEFAULT ('http') FOR scheme

ALTER TABLE alt.url
   ADD CONSTRAINT DFLTAlt_Url_computerName
   DEFAULT ('www') FOR computerName

ALTER TABLE alt.url
   ADD CONSTRAINT DFLTAlt_Url_siteType
   DEFAULT ('com') FOR siteType

ALTER TABLE alt.url
   ADD CONSTRAINT DFLTAlt_Url_filePath
   DEFAULT ('') FOR filePath

ALTER TABLE alt.url
   ADD CONSTRAINT DFLTAlt_Url_fileName
   DEFAULT ('') FOR fileName

ALTER TABLE alt.url
   ADD CONSTRAINT DFLTAlt_Url_parameter
   DEFAULT ('') FOR parameter
Go

INSERT INTO alt.url (domainName)
VALUES ('usatoday')
GO
--then display the data
SELECT   scheme + '://' + computerName +
                 case when len(rtrim(computerName)) > 0 then '.' else '' end +
                 domainName + '.'
         + siteType
         + case when len(filePath) > 0 then '/' else '' end + filePath
         + case when len(fileName) > 0 then '/' else '' end + fileName
         + parameter as display
FROM alt.url
GO

SELECT cast(column_name as varchaR(20)) as column_name, column_default
FROM   information_schema.columns
WHERE  table_schema = 'Alt'
  AND  table_name  = 'url'

--------------------------------------------------------------------
-- Building Default Constraints; Rich Expressions
--------------------------------------------------------------------
CREATE TABLE Rentals.MovieRental (
       MovieRentalId        int NOT NULL IDENTITY(1,1)
             CONSTRAINT PKRentals_MovieRental PRIMARY KEY,
       ReturnDate           date NOT NULL,
       ActualReturnDate     date NULL,
       MovieRentalInventoryItemId int NOT NULL,
       CustomerId           int NOT NULL,
       RentalTime           smalldatetime NOT NULL,
       RentedByEmployeeId   int NOT NULL,
       AmountPaid           decimal(4,2) NOT NULL,
       CONSTRAINT AKRentals_MovieRental_RentalItemCustomer UNIQUE
             (RentalTime, MovieRentalInventoryItemId, CustomerId)
)
GO
ALTER TABLE Rentals.MovieRental
    ADD CONSTRAINT DFLTMovieRental_RentalTime
           DEFAULT (GETDATE()) FOR RentalTime

ALTER TABLE Rentals.MovieRental
    ADD CONSTRAINT DFLTMovieRental_ReturnDate
           --Default to fourth days later
           DEFAULT (DATEADD(Day,4,GETDATE()))
                  FOR ReturnDate
GO
INSERT  Rentals.MovieRental (MovieRentalInventoryItemId, CustomerId,
        RentedByEmployeeId, AmountPaid)
VALUES (0,0,0,0.00)
GO
SELECT  RentalTime, ReturnDate
FROM    Rentals.MovieRental
GO


--------------------------------------------------------------------
-- Adding Relationships (Foreign Keys)
--------------------------------------------------------------------

ALTER TABLE Inventory.Movie
       ADD CONSTRAINT
           Inventory_MovieRating$defines_age_appropriateness_of$Inventory_Movie
              FOREIGN KEY (MovieRatingId)
                             REFERENCES Inventory.MovieRating  (MovieRatingId)
                             ON DELETE NO ACTION
                             ON UPDATE NO ACTION
ALTER TABLE Inventory.Movie
       ADD CONSTRAINT Inventory_Genre$categorizes$Inventory_Movie
                FOREIGN KEY (GenreId)
                             REFERENCES Inventory.Genre (GenreId)
                             ON DELETE NO ACTION
                             ON UPDATE NO ACTION
GO
INSERT INTO Inventory.Movie (Name, ReleaseDate,
                             Description, GenreId, MovieRatingId)
VALUES ('Stripes','19810626',
        'A loser joins the Army, though the Army is not really '+
        'ready for him',-1,-1)
GO
INSERT INTO Inventory.Movie (Name, ReleaseDate,
                             Description, GenreId, MovieRatingId)
SELECT 'Stripes','19810626',
        'A loser joins the Army, though the Army is not really '+
        'ready for him',
        (SELECT Genre.GenreId
         FROM   Inventory.Genre as Genre
         WHERE  Genre.Name = 'Comedy') as GenreId,
        (SELECT MovieRating.MovieRatingId
         FROM   Inventory.MovieRating as MovieRating
         WHERE  MovieRating.Code = 'R') as MovieRatingId
GO
DELETE FROM Inventory.Genre
WHERE  Name = 'Comedy'

----------------------------------------------------------------------------------------
-- Adding Relationships (Foreign Keys); Automated Relationship Options; Cascade
----------------------------------------------------------------------------------------
CREATE TABLE Inventory.MoviePersonality (
       MoviePersonalityId   int NOT NULL IDENTITY (1,1)
       CONSTRAINT PKInventory_MoviePersonality PRIMARY KEY,
       MovieId              int NOT NULL,
       PersonalityId        int NOT NULL,
       CONSTRAINT AKInventory_MoviePersonality_MoviePersonality
            UNIQUE (PersonalityId,MovieId)
)
GO
ALTER TABLE Inventory.MoviePersonality
       ADD CONSTRAINT
           Inventory_Personality$is_linked_to_movies_via$Inventory_MoviePersonality
                FOREIGN KEY (MovieId)
                             REFERENCES Inventory.Movie  (MovieId)
                             ON DELETE CASCADE
                             ON UPDATE NO ACTION

ALTER TABLE Inventory.MoviePersonality
       ADD CONSTRAINT
        Inventory_Movie$is_linked_to_important_people_via$Inventory_MoviePersonality
                FOREIGN KEY (PersonalityId)
                             REFERENCES Inventory.Personality  (PersonalityId)
                             ON DELETE CASCADE
                             ON UPDATE NO ACTION
GO

INSERT INTO Inventory.Personality (FirstName, LastName, NameUniqueifier)
VALUES ('Cary','Grant',''),
       ('Humphrey','Bogart','')
GO
INSERT INTO Inventory.MoviePersonality (MovieId, PersonalityId)
SELECT  (SELECT  Movie.MovieId
         FROM    Inventory.Movie as Movie
         WHERE   Movie.Name = 'The Maltese Falcon') as MovieId,
        (SELECT  Personality.PersonalityId
         FROM    Inventory.Personality as Personality  
         WHERE   Personality.FirstName = 'Humphrey'
           AND   Personality.LastName = 'Bogart'
           AND   Personality.NameUniqueifier = '') 
                                              as PersonalityId
UNION ALL
SELECT  (SELECT  Movie.MovieId
         FROM    Inventory.Movie as Movie
         WHERE   Movie.Name = 'Arsenic and Old Lace') as MovieId,
        (SELECT  Personality.PersonalityId
         FROM    Inventory.Personality as Personality  
         WHERE   Personality.FirstName = 'Cary'
           AND   Personality.LastName = 'Grant'
           AND   Personality.NameUniqueifier = '') 
                                               as PersonalityId
GO
SELECT Movie.Name as Movie,
       Personality.FirstName + ' '+ Personality.LastName as Personality
FROM   Inventory.MoviePersonality as MoviePersonality
         JOIN Inventory.Personality as Personality
              On MoviePersonality.PersonalityId = Personality.PersonalityId
         JOIN Inventory.Movie as Movie
              ON Movie.MovieId = MoviePersonality.MovieId
GO
DELETE FROM Inventory.Movie
WHERE  Name = 'Arsenic and Old Lace'
GO
SELECT Movie.Name as Movie,
       Personality.FirstName + ' '+ Personality.LastName as Personality
FROM   Inventory.MoviePersonality as MoviePersonality
         JOIN Inventory.Personality as Personality
              On MoviePersonality.PersonalityId = Personality.PersonalityId
         JOIN Inventory.Movie as Movie
              ON Movie.MovieId = MoviePersonality.MovieId
GO



CREATE TABLE Alt.Movie
(
    MovieCode   varchar(20)
        CONSTRAINT PKAlt_Movie PRIMARY KEY,
    MovieName   varchar(200)
)
CREATE TABLE Alt.MovieRentalPackage
(
    MovieRentalPackageCode varchar(25)
        CONSTRAINT PKAlt_MovieRentalPackage PRIMARY KEY,
    MovieCode   varchar(20)
        CONSTRAINT Alt_Movie$is_rented_as$Alt_MovieRentalPackage
                FOREIGN KEY References Alt.Movie(MovieCode)
                ON DELETE CASCADE
                ON UPDATE CASCADE
)

INSERT INTO Alt.Movie (MovieCode, MovieName)
VALUES ('ArseOldLace','Arsenic and Old Lace')
INSERT INTO Alt.MovieRentalPackage (MovieRentalPackageCode, MovieCode)
VALUES ('ArsenicOldLaceDVD','ArseOldLace')
GO

UPDATE Alt.Movie
SET    MovieCode = 'ArsenicOldLace'
WHERE  MovieCode = 'ArseOldLace'
GO

SELECT *
FROM   Alt.Movie
SELECT *
FROM   Alt.MovieRentalPackage
GO

----------------------------------------------------------------------------------------
-- Adding Relationships (Foreign Keys); Automated Relationship Options; Set Null
----------------------------------------------------------------------------------------

ALTER TABLE Rentals.Customer
    ADD FavoriteMovieId INT NULL --allow nulls or SET NULL will be invalid

--Next define the foreign key constraint with SET NULL:
ALTER TABLE Rentals.Customer
    ADD CONSTRAINT Inventory_Movie$DefinesFavoriteFor$Rentals_Customer
         FOREIGN KEY (FavoriteMovieId)
                     REFERENCES Inventory.Movie  (MovieId)
                     ON DELETE SET NULL
                     ON UPDATE NO ACTION
GO

INSERT INTO People.Person(FirstName, MiddleName, LastName, SocialSecurityNumber)
VALUES ('Doe','M','Aigne','222-22-2222')

INSERT INTO Rentals.Customer(CustomerId, CustomerNumber,
                            PrimaryCustomerId, Picture, YouthRentalsOnlyFlag,
                            FavoriteMovieId)
SELECT Person.PersonId, '2222222222',NULL, NULL, 0, NULL
FROM   People.Person
WHERE  SocialSecurityNumber = '222-22-2222'

GO

SELECT MovieId, ReleaseDate
FROM   Inventory.Movie
WHERE   Name  = 'Stripes'
GO

UPDATE  Rentals.Customer
SET     FavoriteMovieId = 7
WHERE   CustomerNumber = '2222222222'
GO
UPDATE  Rentals.Customer
SET     FavoriteMovieId =  (SELECT MovieId
                            FROM   Inventory.Movie
                            WHERE   Name  = 'Stripes')
WHERE   CustomerNumber = '2222222222'

GO

SELECT  Customer.CustomerNumber, Movie.Name AS FavoriteMovie
FROM    Rentals.Customer AS Customer
          LEFT OUTER JOIN Inventory.Movie AS Movie
            ON Movie.MovieId = Customer.FavoriteMovieId
WHERE   Customer.CustomerNumber = '2222222222'
GO
DELETE  Inventory.Movie
WHERE   Name = 'Stripes'
  AND   ReleaseDate = '19810626'
GO
SELECT  Customer.CustomerNumber, Movie.Name AS FavoriteMovie
FROM    Rentals.Customer AS Customer
          LEFT OUTER JOIN Inventory.Movie AS Movie
            ON Movie.MovieId = Customer.FavoriteMovieId
WHERE   Customer.CustomerNumber = '2222222222'
GO

----------------------------------------------------------------------------------------
-- Adding Relationships (Foreign Keys); Automated Relationship Options; Set Default
----------------------------------------------------------------------------------------
INSERT INTO Inventory.MovieFormat(MovieFormatId, Name)
VALUES (3, 'Playstation Portable')
GO
ALTER TABLE Rentals.Customer
   ADD DefaultMovieFormatId INT NOT NULL
          CONSTRAINT DFLTRentals_Customer_DefaultMovieFormatId
               DEFAULT (2) --DVD (Can hard code because surrogate key
                           --hand created, just make sure to document
                           --usage)
GO
ALTER TABLE Rentals.Customer
    ADD CONSTRAINT 
       Inventory_MovieFormat$DefinesDefaultFormatFor$Rentals_Customer
         FOREIGN KEY (DefaultMovieFormatId)
            REFERENCES Inventory.MovieFormat  (MovieFormatId)
               ON DELETE SET DEFAULT
               ON UPDATE NO ACTION
GO
UPDATE Rentals.Customer
SET    DefaultMovieFormatId = 3
WHERE  CustomerNumber = '2222222222'
GO
SELECT  MovieFormat.Name
FROM    Inventory.MovieFormat as MovieFormat
           JOIN Rentals.Customer
               ON MovieFormat.MovieFormatId = Customer.DefaultMovieFormatId
WHERE   Customer.CustomerNumber = '2222222222'
GO
DELETE FROM Inventory.MovieFormat
WHERE  Name = 'Playstation Portable'
GO
SELECT  MovieFormat.Name
FROM    Inventory.MovieFormat as MovieFormat
           JOIN Rentals.Customer
               ON MovieFormat.MovieFormatId = Customer.DefaultMovieFormatId
WHERE   Customer.CustomerNumber = '2222222222'
GO
-----------------------------------------------------------------------------
-- Dealing with Collations and Sorting;Viewing the Current Collation Type
-----------------------------------------------------------------------------
SELECT serverproperty('collation')
SELECT databasepropertyex('MovieRental','collation')
GO
-----------------------------------------------------------------------------
-- Dealing with Collations and Sorting;Listing Available Collations
-----------------------------------------------------------------------------
SELECT *
FROM ::fn_helpcollations()
GO
-----------------------------------------------------------------------------
-- Dealing with Collations and Sorting;Specifying a Collation Sequence
-----------------------------------------------------------------------------
CREATE TABLE alt.OtherCollate
(
   OtherCollateId integer IDENTITY
        CONSTRAINT PKAlt_OtherCollate PRIMARY KEY ,
   Name nvarchar(30) NOT NULL,
   FrenchName nvarchar(30) COLLATE French_CI_AS_WS NULL,
   SpanishName nvarchar(30) COLLATE Modern_Spanish_CI_AS_WS NULL
)
GO
-----------------------------------------------------------------------------
-- Dealing with Collations and Sorting;Overriding an Assigned Collation
-----------------------------------------------------------------------------
CREATE TABLE alt.collateTest
(
    name    VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)

insert into alt.collateTest(name)
values ('BOB')
insert into alt.collateTest(name)
values ('bob')
GO
SELECT name
FROM alt.collateTest
WHERE name = 'BOB'
GO
SELECT name
FROM   alt.collateTest
WHERE  name = 'BOB' COLLATE Latin1_General_BIN
GO
SELECT name
FROM   alt.collateTest
WHERE name COLLATE Latin1_General_BIN = 'BOB' COLLATE Latin1_General_BIN
GO
-----------------------------------------------------------------------------
-- Dealing with Collations and Sorting; Searching and Sorting
-----------------------------------------------------------------------------

create table alt.TestSorting
(
     value nvarchar(1) collate Latin1_General_CI_AI --case and accent 
                                                    --insensitive
) 
insert into alt.TestSorting
values ('A'),('a'),(nchar(256)) /*?*/,('b'),('B')
GO
select value
from alt.TestSorting
where value like '[A-Z]%' 
GO
select value
from alt.TestSorting
where value collate Latin1_General_CS_AI   
           like '[A-Z]%' collate Latin1_General_CS_AI  --case sensitive and 
                                                        --accent insensitive
GO
SELECT value
FROM   alt.TestSorting
ORDER  BY value collate Latin1_General_CS_AI 
GO
SELECT value
FROM   alt.TestSorting
WHERE  value collate Latin1_General_CS_AI 
        --Doing case sensitive search by looking for a value that has any of 
        --the capital letters in it.
        like '[ABCDEFGHIJKLMNOPQRSTUVWXYZ]%' collate Latin1_General_CS_AI
GO
;with 
digits (i) as(--set up a set of numbers from 0-9
        select i
        from   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) as digits (i))
--builds a table from 0 to 99999
,sequence (i) as (
        SELECT D1.i + (10*D2.i) + (100*D3.i) + (1000*D4.i) + (10000*D5.i)
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3 
                CROSS JOIN digits AS D4 CROSS JOIN digits AS D5) 
select i, nchar(i) as character
from sequence
where i between 48 and 122 --vary to include any characters 
                           --in the character set of choice 
order by nchar(i) collate Latin1_General_bin --change to the collation you 
                                             --are trying
GO
-----------------------------------------------------------------------------
-- Computed Columns
-----------------------------------------------------------------------------

ALTER TABLE Inventory.Personality
   ADD FullName as
          FirstName + ' ' + LastName + RTRIM(' ' + NameUniqueifier) PERSISTED
GO
INSERT INTO Inventory.Personality (FirstName, LastName, NameUniqueifier)
VALUES ('John','Smith','I'),
       ('John','Smith','II')
GO
SELECT *
FROM Inventory.Personality
GO



CREATE TABLE alt.calcColumns
(
   dateColumn   datetime2(7),
   dateSecond   AS datepart(second,dateColumn) PERSISTED -- calculated column
)
SET NOCOUNT ON
DECLARE @i int
SET @i = 1
WHILE (@i < 200)
BEGIN
   INSERT INTO alt.calcColumns (dateColumn) VALUES (sysdatetime())
   WAITFOR DELAY '00:00:00.01' --or the query runs too fast
                               --and you get duplicates
   SET @i = @i + 1
END

SELECT dateSecond, max(dateColumn) as dateColumn, count(*) AS countStar
FROM alt.calcColumns
GROUP BY dateSecond
ORDER BY dateSecond
GO

CREATE TABLE alt.testCalc
(
    value varchar(10),
    valueCalc AS UPPER(value),
    value2 varchar(10)
)
GO
INSERT INTO alt.testCalc
VALUES ('test','test2')
Go
SELECT *
FROM  alt.testCalc
GO

SELECT   scheme + '://' + computerName +
                 case when len(rtrim(computerName)) > 0 then '.' else '' end +
                 domainName + '.'
         + siteType
         + case when len(filePath) > 0 then '/' else '' end + filePath
         + case when len(fileName) > 0 then '/' else '' end + fileName
         + parameter as display
FROM alt.url
GO
ALTER TABLE alt.url 
   ADD formattedUrl AS
          scheme + '://' + computerName +
                 case when len(rtrim(computerName)) > 0 then '.' else '' end +
                 domainName + '.'
         + siteType
         + case when len(filePath) > 0 then '/' else '' end + filePath
         + case when len(fileName) > 0 then '/' else '' end + fileName
         + parameter PERSISTED
GO
SELECT formattedUrl
FROM   Alt.url
GO

SELECT cast(name as varchar(20)) as name, is_computed
FROM   sys.columns
WHERE  object_id('alt.testCalc') = object_id 
GO
SELECT cast(name as varchar(20)) as name, is_persisted, definition
FROM   sys.computed_columns
WHERE  object_id('alt.testCalc') = object_id 
GO

-----------------------------------------------------------------------------
-- Implementing User-Defined Datatypes; Datatype Aliases
-----------------------------------------------------------------------------
CREATE TYPE SSN
         FROM char(11)
              NOT NULL
GO
CREATE TABLE alt.Person
(
      PersonId      int NOT NULL,
      FirstName      varchar(30) NOT NULL,
      LastName       varchar(30) NOT NULL,
      SSN            SSN              --no null specification to make a point
                                      --generally it is a better idea to
                                      --include a null spec.
)
GO
INSERT Alt.Person
VALUES (1,'rie',' lationship','234-43-3432')

SELECT PersonId, FirstName, LastName, SSN
FROM    Alt.Person
GO
INSERT  Alt.Person
VALUES  (2,'dee','pendency',NULL)
GO


-----------------------------------------------------------------------------
-- Implementing User-Defined Datatypes; CLR-Based Datatypes
-----------------------------------------------------------------------------

EXEC sp_configure 'clr enabled', 1
go
RECONFIGURE
Go

CREATE ASSEMBLY [Apress]
AUTHORIZATION [dbo]
FROM 0x4D5A90000300000004000000FFFF0000B800000000000000400000000000000000000000000000000000000000000000000000000000000000000000800000000E1FBA0E00B409CD21B8014CCD21546869732070726F6772616D2063616E6E6F742062652072756E20696E20444F53206D6F64652E0D0D0A2400000000000000504500004C0103001A6F50480000000000000000E00002210B010800000E0000000C0000000000001E2C0000002000000040000000004000002000000002000004000000000000000400000000000000008000000002000000000000020040850000100000100000000010000010000000000000100000000000000000000000C42B000057000000004000005008000000000000000000000000000000000000006000000C00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000080000000000000000000000082000004800000000000000000000002E74657874000000240C000000200000000E000000020000000000000000000000000000200000602E727372630000005008000000400000000A000000100000000000000000000000000000400000402E72656C6F6300000C0000000060000000020000001A00000000000000000000000000004000004200000000000000000000000000000000002C0000000000004800000002000500C8210000FC09000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001330020014000000010000110228020000060B12017201000070280200000A2A133001000700000002000011027B020000042A002202037D020000042A000000133001000700000003000011027B010000042A001330020012000000040000111200FE15020000021200177D01000004062A00001330020051000000050000110F00280300000A2C0628050000062A0F00FE16030000016F0400000A28070000062C231201FE150200000212010F00FE16030000016F0400000A28080000062803000006072A7219000070730500000A7A000000133003000D0000000600001102723D00007016280600000A2A0000001B3003006A0000000700001102280700000A0BDE5F25280800000A0C72CE0000700D16026F0900000A17DA130513042B2F72D00000700211046F0A00000A6F0B00000A163214090211046F0A00000A280C00000A280D00000A0D110417D613041104110531CB09280700000A0B280E00000ADE00072A0000010C0000000000000909005F0900000142534A4201000100000000000C00000076322E302E35303732370000000005006C0000004C030000237E0000B8030000D803000023537472696E67730000000090070000E80000002355530078080000100000002347554944000000880800007401000023426C6F6200000000000000020000015717A2030900000000FA013300160000010000001B00000002000000020000000800000004000000010000001B0000000C000000070000000100000003000000040000000100000001000000040000000000CB03010000000000060052004B000E007D0068000E00C7006800060008014B0006000E014B00060015014B0012004C012D01120052012D01060067014B00060071014B000A00A80181010600C4014B000A00E80181010E0028020D020E0044020D0206004B024B000600810261020600A10261020600DE02BF020600EC02BF02060000034B0006002803160306004303160306005E0316030600770316030600900316030600AD0316030000000001000000000001000100092100002900300005000100010001008700130001008E001600502000000000460294001900010070200000000001089D001D0001008420000000000108A50021000100902000000000660BB30026000200A420000000001608BE002A000200C420000000001600D1002F0002002421000000001100D900360003004021000000001100E8003B00040000000100AD0000000100D70000000100E40000000100E400020009001100B3002600210094004D001900B300260029009400190031002701660039005F016B00510079013B005900B40173006100CB011D006100D60179006100E0017E006900940083006100F40188005900FB018E00710027019C0081002701DB0089002701210091002701DB00990027016600A1002701DF00A9002701DF00B10027016600B90027016600C10027016600C90027016600D10027016600D900270166002E00AB003C012E008B00E4002E009300ED002E009B000C012E00A30036012E00C3005A012E00DB005A012E00BB0042012E00B30036012E00CB0036012E00D300360143007B00A200520057005B005F005F005B009200020001000000F80040000000FC00440000000301480002000200030001000300030002000400050002000500070002000800030004800000010000000C0C0082000000000000C403000002000000000000000000000001000A00000000000800000000000000000000000A0013000000000002000000000000000000000001005C000000000002000000000000000000000001004B00000000000000003C4D6F64756C653E006D73636F726C6962004D6963726F736F66742E56697375616C42617369630053736E5564740050726F53716C536572766572446174616261736544657369676E0053797374656D0056616C7565547970650053797374656D2E446174610053797374656D2E446174612E53716C547970657300494E756C6C61626C65006D5F4E756C6C006D5F73736E00546F537472696E67006765745F53736E007365745F53736E0076616C7565006765745F49734E756C6C006765745F4E756C6C0053716C537472696E67005061727365007300497353736E56616C69640073736E00436F6E7665727453534E546F496E740053736E0049734E756C6C004E756C6C00496E743332004F626A65637400417267756D656E74457863657074696F6E002E63746F720053797374656D2E546578742E526567756C617245787072657373696F6E730052656765780052656765784F7074696F6E730049734D6174636800457863657074696F6E00436F6E7665727400546F496E743332004D6963726F736F66742E56697375616C42617369632E436F6D70696C657253657276696365730050726F6A656374446174610053657450726F6A6563744572726F7200537472696E67006765745F4C656E677468006765745F436861727300496E6465784F6600436F6E76657273696F6E7300436F6E63617400436C65617250726F6A6563744572726F72004D6963726F736F66742E53716C5365727665722E5365727665720053716C55736572446566696E65645479706541747472696275746500466F726D61740053657269616C697A61626C654174747269627574650053797374656D2E52756E74696D652E436F6D70696C6572536572766963657300436F6D70696C6174696F6E52656C61786174696F6E734174747269627574650052756E74696D65436F6D7061746962696C6974794174747269627574650053797374656D2E52756E74696D652E496E7465726F705365727669636573004775696441747472696275746500436F6D56697369626C6541747472696275746500434C53436F6D706C69616E744174747269627574650053797374656D2E5265666C656374696F6E00417373656D626C7954726164656D61726B41747472696275746500417373656D626C79436F7079726967687441747472696275746500417373656D626C7950726F6475637441747472696275746500417373656D626C79436F6D70616E7941747472696275746500417373656D626C794465736372697074696F6E41747472696275746500417373656D626C795469746C6541747472696275746500417072657373004170726573732E646C6C00000000173000300030002D00300030002D0030003000300030000123530053004E0020006900730020006E006F0074002000760061006C00690064002E0000808F5E0028003F002100300030003000290028005B0030002D0036005D005C0064007B0032007D007C00370028005B0030002D0036005D005C0064007C0037005B003000310032005D002900290028005B0020002D005D003F00290028003F0021003000300029005C0064005C0064005C00330028003F002100300030003000300029005C0064007B0034007D0024000101001530003100320033003400350036003700380039000000006140AC94750EF14CABD9669F24C7EF6E0008B77A5C561934E08908B03F5F7F11D50A3A0206020206080320000E0320000804200101080320000204000011080600011108110D040001020E040001080E032800080328000204080011080420010E0E0407020E08030701080307010206070211081108042001010E070003020E0E1121050001011225042001030804200108030400010E030500020E0E0E03000001090706080812250E080805200101113D38010001000000030054020D4973427974654F7264657265640154020D497346697865644C656E67746801540E044E616D6506434C5253534E0320000104200101020801000800000000001E01000100540216577261704E6F6E457863657074696F6E5468726F7773012901002432666561663338362D353661382D343463622D386361372D653039383162643139383737000005010000000005010001000017010012436F7079726967687420C2A9202032303038000018010013436861707465722035202D2053534E20554454000000EC2B000000000000000000000E2C0000002000000000000000000000000000000000000000000000002C00000000000000000000000000000000000000005F436F72446C6C4D61696E006D73636F7265652E646C6C0000000000FF250020400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030003000000280000800E000000480000801000000060000080000000000000000000000000000002000200000078000080030000009000008000000000000000000000000000000100007F0000A80000800000000000000000000000000000010001000000C00000800000000000000000000000000000010000000000D80000000000000000000000000000000000010000000000E80000000000000000000000000000000000010000000000F800000000000000000000000000000000000100000000000801000018440000E80200000000000000000000004700002801000000000000000000002848000022000000000000000000000018410000000300000000000000000000000334000000560053005F00560045005200530049004F004E005F0049004E0046004F0000000000BD04EFFE000001000000010000820C0C0000010000820C0C3F000000000000000400000002000000000000000000000000000000440000000100560061007200460069006C00650049006E0066006F00000000002400040000005400720061006E0073006C006100740069006F006E00000000000000B00460020000010053007400720069006E006700460069006C00650049006E0066006F0000003C0200000100300030003000300030003400620030000000500014000100460069006C0065004400650073006300720069007000740069006F006E000000000043006800610070007400650072002000350020002D002000530053004E002000550044005400000040000F000100460069006C006500560065007200730069006F006E000000000031002E0030002E0033003000380034002E00330033003200380030000000000038000B00010049006E007400650072006E0061006C004E0061006D00650000004100700072006500730073002E0064006C006C00000000004800120001004C006500670061006C0043006F007000790072006900670068007400000043006F0070007900720069006700680074002000A900200020003200300030003800000040000B0001004F0072006900670069006E0061006C00460069006C0065006E0061006D00650000004100700072006500730073002E0064006C006C0000000000480014000100500072006F0064007500630074004E0061006D0065000000000043006800610070007400650072002000350020002D002000530053004E002000550044005400000044000F000100500072006F006400750063007400560065007200730069006F006E00000031002E0030002E0033003000380034002E00330033003200380030000000000048000F00010041007300730065006D0062006C0079002000560065007200730069006F006E00000031002E0030002E0033003000380034002E003300330032003800300000000000280000002000000040000000010004000000000080020000000000000000000000000000000000000000000000008000008000000080800080000000800080008080000080808000C0C0C0000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007777777777777777777777777777700444444444444444444444444444447004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF47004FFFFFFFFFFFFFFFFFFFFFFFFFFF4700488888888888888888888888888847004444444444444444444444444444470044C4C4C4C4C4C4C4C4C4ECECE49747004CCCCCCCCCCCCCCCCCCCCCCCCCCC40000444444444444444444444444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC00000018000000180000001800000018000000180000001800000018000000180000001800000018000000180000001800000018000000180000001800000018000000180000001800000018000000180000001800000018000000180000003C0000007FFFFFFFFFFFFFFFFFFFFFFFF2800000010000000200000000100040000000000C0000000000000000000000000000000000000000000000000008000008000000080800080000000800080008080000080808000C0C0C0000000FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF000000000000000000077777777777777744444444444444474FFFFFFFFFFFF8474FFFFFFFFFFFF8474FFFFFFFFFFFF8474FFFFFFFFFFFF8474FFFFFFFFFFFF8474FFFFFFFFFFFF8474FFFFFFFFFFFF8474FFFFFFFFFFFF84748888888888888474CCCCCCCCCCCCC47C4444444444444C000000000000000000000000000000000FFFF000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000FFFF0000FFFF00000000010002002020100001000400E802000002001010100001000400280100000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000C000000203C00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
WITH PERMISSION_SET = SAFE
GO
ALTER ASSEMBLY [Apress]
ADD FILE FROM 0xEFBBBF496D706F7274732053797374656D0D0A496D706F7274732053797374656D2E5265666C656374696F6E0D0A496D706F7274732053797374656D2E52756E74696D652E496E7465726F7053657276696365730D0A496D706F7274732053797374656D2E446174612E53716C0D0A0D0A272047656E6572616C20496E666F726D6174696F6E2061626F757420616E20617373656D626C7920697320636F6E74726F6C6C6564207468726F7567682074686520666F6C6C6F77696E670D0A2720736574206F6620617474726962757465732E204368616E6765207468657365206174747269627574652076616C75657320746F206D6F646966792074686520696E666F726D6174696F6E0D0A27206173736F636961746564207769746820616E20617373656D626C792E0D0A0D0A2720526576696577207468652076616C756573206F662074686520617373656D626C7920617474726962757465730D0A0D0A3C417373656D626C793A20417373656D626C795469746C652822436861707465722035202D2053534E2055445422293E0D0A3C417373656D626C793A20417373656D626C794465736372697074696F6E282222293E0D0A3C417373656D626C793A20417373656D626C79436F6D70616E79282222293E0D0A3C417373656D626C793A20417373656D626C7950726F647563742822436861707465722035202D2053534E2055445422293E0D0A3C417373656D626C793A20417373656D626C79436F707972696768742822436F7079726967687420C2A920203230303822293E0D0A3C417373656D626C793A20417373656D626C7954726164656D61726B282222293E0D0A3C417373656D626C793A20434C53436F6D706C69616E742854727565293E0D0A3C417373656D626C793A20436F6D56697369626C652846616C7365293E0D0A0D0A2754686520666F6C6C6F77696E67204755494420697320666F7220746865204944206F662074686520747970656C696220696620746869732070726F6A656374206973206578706F73656420746F20434F4D0D0A3C417373656D626C793A2047756964282232666561663338362D353661382D343463622D386361372D65303938316264313938373722293E0D0A0D0A272056657273696F6E20696E666F726D6174696F6E20666F7220616E20617373656D626C7920636F6E7369737473206F662074686520666F6C6C6F77696E6720666F75722076616C7565733A0D0A270D0A272020202020204D616A6F722056657273696F6E0D0A272020202020204D696E6F722056657273696F6E0D0A272020202020204275696C64204E756D6265720D0A272020202020205265766973696F6E0D0A270D0A2720596F752063616E207370656369667920616C6C207468652076616C756573206F7220796F752063616E2064656661756C7420746865204275696C6420616E64205265766973696F6E204E756D62657273200D0A27206279207573696E672074686520272A272061732073686F776E2062656C6F773A0D0A0D0A3C417373656D626C793A20417373656D626C7956657273696F6E2822312E302E2A22293E200D0A
AS N'My Project\AssemblyInfo.vb'
GO

ALTER ASSEMBLY [Apress]
ADD FILE FROM 0xEFBBBF4F7074696F6E20537472696374204F6E0D0A0D0A496D706F7274732053797374656D0D0A496D706F7274732053797374656D2E446174610D0A496D706F7274732053797374656D2E446174612E53716C0D0A496D706F7274732053797374656D2E446174612E53716C54797065730D0A496D706F727473204D6963726F736F66742E53716C5365727665722E5365727665720D0A496D706F7274732053797374656D2E546578742E526567756C617245787072657373696F6E730D0A0D0A272D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D0D0A2720507572706F73653A20536F6369616C205365637572697479206E756D62657220757365722D646566696E65642074797065200D0A27205772697474656E3A2031322F31372F323030350D0A2720436F6D6D656E743A0D0A270D0A272053716C55736572446566696E6564547970652061747472696275746520636F6E7461696E73206461746120757365642062792053514C205365727665722032303035200D0A272061742072756E74696D6520616E64206279207468652050726F66657373696F6E616C2076657273696F6E206F662056697375616C2053747564696F200D0A2720616E642061626F7665206174206465706C6F796D656E742074696D652E205544542773206D7573742062652073657269616C697A61626C6520616E6420696D706C656D656E74200D0A2720494E756C6C61626C652E0D0A270D0A2720466F726D61742E4E6174697665202D20696E646963617465732053514C207365727665722063616E2053657269616C697A6520746865207479706520666F722075730D0A27204E616D65202D204E616D65206F6620554454207768656E206372656174656420696E2053514C20536572766572202875736564206279205653206174206465706C6F796D656E74290D0A27204973427974654F726465726564202D20696E6469636174657320696620747970652063616E206265206F7264657265642028757365642062792053514C20536572766572206174200D0A272072756E74696D65290D0A2720497346697865644C656E677468202D20696E64696361746573206966206C656E677468206F6620747970652069732066697865642028757365642062792053514C20536572766572200D0A272061742072756E74696D65290D0A272D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D2D0D0A3C53657269616C697A61626C6528293E205F0D0A3C4D6963726F736F66742E53716C5365727665722E5365727665722E53716C55736572446566696E65645479706528466F726D61742E4E61746976652C205F0D0A2020202020204973427974654F7264657265643A3D547275652C20497346697865644C656E6774683A3D547275652C204E616D653A3D22434C5253534E22293E205F0D0A5075626C6963205374727563747572652053736E5564740D0A20202020496D706C656D656E747320494E756C6C61626C650D0A0D0A20202020272050726976617465206D656D6265720D0A2020202050726976617465206D5F4E756C6C20417320426F6F6C65616E0D0A2020202050726976617465206D5F73736E20417320496E74656765720D0A0D0A202020205075626C6963204F76657272696465732046756E6374696F6E20546F537472696E67282920417320537472696E670D0A20202020202020202720666F726D61742053534E20666F72206F75747075740D0A202020202020202052657475726E204D652E53736E2E546F537472696E6728223030302D30302D3030303022290D0A20202020456E642046756E6374696F6E0D0A0D0A202020202720707269766174652070726F706572747920746F207365742F6765742073736E2073746F72656420617320696E746765720D0A20202020507269766174652050726F70657274792053736E282920417320496E74656765720D0A20202020202020204765740D0A20202020202020202020202052657475726E206D5F73736E0D0A2020202020202020456E64204765740D0A202020202020202053657428427956616C2076616C756520417320496E7465676572290D0A2020202020202020202020206D5F73736E203D2076616C75650D0A2020202020202020456E64205365740D0A20202020456E642050726F70657274790D0A0D0A202020205075626C696320526561644F6E6C792050726F70657274792049734E756C6C282920417320426F6F6C65616E20496D706C656D656E747320494E756C6C61626C652E49734E756C6C0D0A20202020202020204765740D0A20202020202020202020202052657475726E206D5F4E756C6C0D0A2020202020202020456E64204765740D0A20202020456E642050726F70657274790D0A0D0A20202020272072657475726E206F7572205544542061732061206E756C6C2076616C75650D0A202020205075626C69632053686172656420526561644F6E6C792050726F7065727479204E756C6C28292041732053736E5544540D0A20202020202020204765740D0A20202020202020202020202044696D20682041732053736E554454203D204E65772053736E5544540D0A202020202020202020202020682E6D5F4E756C6C203D20547275650D0A20202020202020202020202052657475726E20680D0A2020202020202020456E64204765740D0A20202020456E642050726F70657274790D0A0D0A20202020272067657420646174612066726F6D2053514C2053657276657220617320737472696E6720616E6420706172736520746F2072657475726E206F7572205544540D0A202020205075626C6963205368617265642046756E6374696F6E20506172736528427956616C20732041732053716C537472696E67292041732053736E5544540D0A2020202020202020496620732E49734E756C6C205468656E0D0A20202020202020202020202052657475726E204E756C6C0D0A2020202020202020456E642049660D0A0D0A2020202020202020272076616C69646174652076616C7565206265696E672070617373656420696E20617320612076616C69642053534E0D0A2020202020202020496620497353736E56616C696428732E546F537472696E67282929205468656E0D0A20202020202020202020202044696D20752041732053736E554454203D204E65772053736E5544540D0A202020202020202020202020752E53736E203D20436F6E7665727453534E546F496E7428732E546F537472696E672829290D0A20202020202020202020202052657475726E20750D0A2020202020202020456C73650D0A2020202020202020202020205468726F77204E657720417267756D656E74457863657074696F6E282253534E206973206E6F742076616C69642E22290D0A2020202020202020456E642049660D0A20202020456E642046756E6374696F6E0D0A0D0A20202020272076616C69646174652073736E207573696E67207265676578206D61746368696E67202D2072657475726E7320747275652069662076616C69642C2066616C7365206966206E6F740D0A2020202050726976617465205368617265642046756E6374696F6E20497353736E56616C696428427956616C2073736E20417320537472696E672920417320426F6F6C65616E0D0A202020202020202052657475726E2052656765782E49734D617463682873736E2C205F0D0A20202020202020202020202020202020225E283F2130303029285B302D365D5C647B327D7C37285B302D365D5C647C375B3031325D2929285B202D5D3F29283F213030295C645C645C33283F2130303030295C647B347D24222C205F0D0A2020202020202020202020202020202052656765784F7074696F6E732E4E6F6E65290D0A20202020456E642046756E6374696F6E0D0A0D0A202020202720707269766174652066756E6374696F6E20746F20636F6E766572742053534E206173206120737472696E6720746F20616E20696E74656765720D0A2020202050726976617465205368617265642046756E6374696F6E20436F6E7665727453534E546F496E7428427956616C2073736E20417320537472696E672920417320496E74656765720D0A202020202020202044696D2073736E4E756D6265727320417320496E74656765720D0A20202020202020205472790D0A202020202020202020202020272074727920612073696D706C6520636F6E76657273696F6E0D0A20202020202020202020202073736E4E756D62657273203D20436F6E766572742E546F496E7433322873736E290D0A2020202020202020436174636820657820417320457863657074696F6E0D0A202020202020202020202020272069662073696D706C6520636F6E76657273696F6E206661696C732C207374726970206F75742065766572797468696E670D0A2020202020202020202020202720627574206E756D6265727320616E6420636F6E7665727420746F20696E74656765720D0A20202020202020202020202044696D2073736E537472696E6720417320537472696E67203D2022220D0A202020202020202020202020466F72206920417320496E7465676572203D203020546F2073736E2E4C656E677468202D20310D0A202020202020202020202020202020204966202230313233343536373839222E496E6465784F662873736E2E436861727328692929203E3D2030205468656E0D0A202020202020202020202020202020202020202073736E537472696E67202B3D2073736E2E43686172732869290D0A20202020202020202020202020202020456E642049660D0A2020202020202020202020204E6578740D0A20202020202020202020202073736E4E756D62657273203D20436F6E766572742E546F496E7433322873736E537472696E67290D0A2020202020202020456E64205472790D0A202020202020202052657475726E2073736E4E756D626572730D0A20202020456E642046756E6374696F6E0D0A0D0A456E64205374727563747572650D0A
AS N'Type1.vb'
GO


CREATE TYPE [dbo].[CLRSSN]
EXTERNAL NAME [Apress].[ProSqlServerDatabaseDesign.SsnUdt]

GO

ALTER TABLE People.Person 
   ADD SocialSecurityNumberCLR CLRSSN NULL
GO
UPDATE People.Person
   SET SocialSecurityNumberCLR = SocialSecurityNumber
GO

ALTER TABLE People.Person
   DROP CONSTRAINT AKPeople_Person_SSN
ALTER TABLE People.Person
   DROP COLUMN SocialSecurityNumber
EXEC sp_rename 'People.Person.SocialSecurityNumberCLR',
   'SocialSecurityNumber', 'COLUMN';
GO

ALTER TABLE People.Person
   ALTER COLUMN SocialSecurityNumber CLRSSN NOT NULL
ALTER TABLE People.Person
   ADD CONSTRAINT AKPeople_Person_SSN UNIQUE (SocialSecurityNumber)
GO
SELECT SocialSecurityNumber, socialSecurityNumber.ToString() as CastedVersion
FROM  People.Person

GO

-----------------------------------------------------------------------------
-- Documenting Your Database
-----------------------------------------------------------------------------

--dbo.person table description
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'tables pertaining to the videos to be rented',
   @level0type = 'Schema', @level0name = 'Inventory'

--dbo.person table description
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Defines movies that will be rentable in the store',
   @level0type = 'Schema', @level0name = 'Inventory',
   @level1type = 'Table', @level1name = 'Movie'

--dbo.person.personId description
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key of a movie instance',
   @level0type = 'Schema', @level0name = 'Inventory',
   @level1type = 'Table', @level1name = 'Movie',
   @level2type = 'Column', @level2name = 'MovieId'

--dbo.person.firstName description
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The known name of the movie',
   @level0type = 'Schema', @level0name = 'Inventory',
   @level1type = 'Table', @level1name = 'Movie',
   @level2type = 'Column', @level2name = 'Name'

--dbo.person.lastName description
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The date the movie was originally released',
   @level0type = 'Schema', @level0name = 'Inventory',
   @level1type = 'Table', @level1name = 'Movie',
   @level2type = 'Column', @level2name = 'ReleaseDate'
GO

SELECT objname, value
FROM   fn_listExtendedProperty ('Description',
                                 'Schema','Inventory',
                                 'Table','Movie',
                                 'Column',null)
GO
-----------------------------------------------------------------------------
-- Working with Dependency Information
-----------------------------------------------------------------------------
SELECT  objects.type_desc as object_type,
        OBJECT_SCHEMA_NAME(referencing_id) + '.' + 
                     OBJECT_NAME(referencing_id) AS object_name, 
        COL_NAME(referencing_id, referencing_minor_id) as
                    column_name,
        CASE WHEN referenced_id IS NOT NULL THEN 'Does Exist' 
                   ELSE 'May Not Exist' END 
             AS referencedObjectExistance,
        referenced_class_desc,
        coalesce(referenced_server_name,'<>') + '.'
            + coalesce(referenced_database_name,'<>') + '.' 
            + coalesce(referenced_schema_name,'<>') + '.'
            + coalesce(referenced_entity_name,'<>') as 
                                            referenced_object_name,
        COL_NAME(referenced_id, referenced_minor_id) as 
                                referenced_column_name,
        is_caller_dependent,
        is_ambiguous
FROM  sys.sql_expression_dependencies
       join sys.objects
           on objects.object_id = sql_expression_dependencies.referencing_id
GO
CREATE TABLE Alt.DependencyTest
(
    DependencyTestId    int
        CONSTRAINT PKAlt_DependencyTest PRIMARY KEY,
    Value   varchar(20)
)
GO

CREATE PROCEDURE Alt.DependencyTest$Proc
(
      @DependencyTestId int
) AS
   BEGIN
        SELECT DependencyTest.DependencyTestId, DependencyTest.Value
        FROM Alt.DependencyTest
        WHERE DependencyTest.DependencyTestId = @DependencyTestId
   END
GO
DROP TABLE Alt.DependencyTest
GO
SELECT    coalesce(referenced_server_name,'<>') + '.'
            + coalesce(referenced_database_name,'<>') + '.' 
            + coalesce(referenced_schema_name,'<>') + '.'
            + coalesce(referenced_entity_name,'<>') as referenced_object_name,
        referenced_minor_name
FROM   sys.dm_sql_referenced_entities ('Alt.DependencyTest$Proc','OBJECT')
GO


CREATE TABLE Alt.DependencyTest
(
    DependencyTestId    int
        CONSTRAINT PKAlt_DependencyTest PRIMARY KEY,
    Value   varchar(20)
)
GO
select coalesce(referencing_schema_name,'<>') + '.'
       + coalesce(referencing_entity_name,'<>') as referenced_object_name,
              referencing_class_desc as referencing_class
from   sys.dm_sql_referencing_entities ('Alt.DependencyTest','OBJECT')
