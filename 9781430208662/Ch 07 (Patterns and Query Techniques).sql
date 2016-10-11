Use tempdb
GO
---------------------------------------------------------------------
-- Precalculated Values; Sequence Tables
----------------------------------------------------------------------

;WITH
digits (i) as(--set up a set of numbers from 0-9
              SELECT i
              FROM  (VALUES (0),(1),(2),(3),(4),
                            (5),(6),(7),(8),(9)) as digits (i))
,sequence (i) as (
        SELECT D1.i + (10*D2.i) + (100*D3.i) + (1000*D4.i)
               --+ (10000*D5.i) + (100000*D6.i)
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3
                CROSS JOIN digits AS D4
              --CROSS JOIN digits AS D5 CROSS JOIN digits AS D6
                )
SELECT *
FROM  sequence
ORDER BY i
GO

CREATE SCHEMA tools
go
CREATE TABLE tools.sequence
(
    i   int CONSTRAINT PKtools_sequence PRIMARY KEY
)
GO

;WITH DIGITS (i) as(--set up a set of numbers from 0-9
        SELECT i
        FROM   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) as digits (i))
--builds a table from 0 to 99999
,sequence (i) as (
        SELECT D1.i + (10*D2.i) + (100*D3.i) + (1000*D4.i) + (10000*D5.i)
               --+ (100000*D6.i)
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3
                CROSS JOIN digits AS D4 CROSS JOIN digits AS D5
                /* CROSS JOIN digits AS D6 */)
INSERT INTO tools.sequence(i)
SELECT i
FROM   sequence
GO
DECLARE @string varchar(21) = 'This is my test value'
SELECT SUBSTRING(split.value,sequence.i,1) as [char],
       UNICODE(SUBSTRING(split.value,sequence.i,1)) as [Unicode]
FROM   tools.sequence
         cross join (select @string as value) as split
WHERE  sequence.i > 0
  AND  sequence.i <= len(@string)
GO

SELECT LastName, sequence.i as position,
              SUBSTRING(Person.LastName,sequence.i,1) as [char],
              UNICODE(SUBSTRING(Person.LastName,sequence.i,1)) as [Unicode]
FROM   AdventureWorks2008.Person.Person
         JOIN tools.sequence
               ON sequence.i <= LEN(Person.LastName )
  And  UNICODE(SUBSTRING(Person.LastName,sequence.i,1)) is not null
ORDER BY 1
GO
DECLARE @delimitedList VARCHAR(100) = '1,2,3,4,5'

SELECT word = SUBSTRING(',' + @delimitedList + ',',i + 1,
                  CHARINDEX(',',',' + @delimitedList + ',',i + 1) - i - 1)
FROM tools.sequence
WHERE i >= 1
  AND i < LEN(',' + @delimitedList + ',') - 1
  AND SUBSTRING(',' + @delimitedList + ',', i, 1) = ','
ORDER BY i
GO

DECLARE @delimitedList VARCHAR(100) = '1,2,3,4,5'
SELECT i
FROM tools.sequence
WHERE i >= 1
  AND i < LEN(',' + @delimitedList + ',') - 1
  AND SUBSTRING(',' + @delimitedList + ',', i, 1) = ','
ORDER BY i
GO

CREATE TABLE poorDesign
(
    poorDesignId    int,
    badValue        varchar(20)
)
INSERT INTO poorDesign
VALUES (1,'1,3,56,7,3,6'),
       (2,'22,3'),
       (3,'1')
GO

SELECT poorDesign.poorDesignId as betterDesignId,
       SUBSTRING(',' + poorDesign.badValue + ',',i + 1,
               CHARINDEX(',',',' + poorDesign.badValue + ',',i + 1) - i - 1)
                                       as betterScalarValue
FROM   poorDesign
         JOIN tools.sequence
            on i >= 1
              AND i < LEN(',' + poorDesign.badValue + ',') - 1
              AND SUBSTRING(',' + + poorDesign.badValue  + ',', i, 1) = ','
GO

SET ANSI_WARNINGS ON
GO
ALTER TABLE tools.sequence
  ADD i3 as cast( power(cast(i as bigint),3) as bigint) PERSISTED
  --Note that I had to cast i as bigint first to let the power function
  --return a bigint

GO

DECLARE @level int = 2 --sum of two cubes

;WITH cubes as
(SELECT i3
FROM   tools.sequence
WHERE  i >= 1 and i < 500) --<<<Vary for performance, and for cheating reasons,
                           --<<<max needed value

SELECT c1.i3 + c2.i3 as [sum of 2 cubes in N Ways]
FROM   cubes as c1
         cross join cubes as c2
WHERE c1.i3 <= c2.i3
GROUP by (c1.i3 + c2.i3)
HAVING count(*) = @level
ORDER BY 1

GO
----------------------------------------------------------------------
-- Precalculated Values; Calculations with Dates
----------------------------------------------------------------------

create table tools.calendar
(
        dateValue datetime NOT NULL CONSTRAINT PKtools_calendar PRIMARY KEY,
        dayName varchar(10) NOT NULL,
        monthName varchar(10) NOT NULL,
        year varchar(60) NOT NULL,
        day tinyint NOT NULL,
        dayOfTheYear smallint NOT NULL,
        month smallint NOT NULL,
        quarter tinyint NOT NULL
)
GO
WITH dates (newDateValue) as (
        select dateadd(day,i,'17530101') as newDateValue
        from tools.sequence
)
INSERT tools.calendar
        (dateValue ,dayName
        ,monthName ,year ,day
        ,dayOfTheYear ,month ,quarter
)
SELECT
        dates.newDateValue as dateValue,
        datename (dw,dates.newDateValue) as dayName,
        datename (mm,dates.newDateValue) as monthName,
        datename (yy,dates.newDateValue) as year,
        datepart(day,dates.newDateValue) as day,
        datepart(dy,dates.newDateValue) as dayOfTheYear,
        datepart(m,dates.newDateValue) as month,
        datepart(qq,dates.newDateValue) as quarter
 
FROM    dates
WHERE  dates.newDateValue between '20000101' and '20100101' --set the date range
ORDER  BY datevalue
GO

SELECT calendar.year, COUNT(*) as orderCount
FROM   AdventureWorks2008.Sales.SalesOrderHeader
         JOIN tools.calendar
               --note, the cast here could be a real performance killer
               --consider using date columns where
            ON CAST(SalesOrderHeader.OrderDate as date) = calendar.dateValue
GROUP BY calendar.year
ORDER BY calendar.year
GO

SELECT MAX(dateValue)
FROM   tools.calendar
WHERE  year = '2008'
GROUP  BY year, month
GO

SELECT calendar.dayName, COUNT(*) as orderCount
FROM   AdventureWorks2008.Sales.SalesOrderHeader
         JOIN tools.calendar
               --note, the cast here could be a real performance killer
               --consider using date columns where
            ON CAST(SalesOrderHeader.OrderDate as date) = calendar.dateValue
WHERE calendar.dayName in ('Tuesday','Thursday')
GROUP BY calendar.dayName
ORDER BY calendar.dayName
GO

WITH onlyWednesdays as --get all wednesdays
(
    SELECT *,
           ROW_NUMBER()  over (partition by calendar.year, calendar.month
                               order by calendar.day) as wedRowNbr
    FROM   tools.calendar
    WHERE  dayName = 'Wednesday'
),
secondWednesdays as --limit to second Wednesdays of the month
(
    SELECT *
    FROM   onlyWednesdays
    WHERE  wedRowNbr = 2
)
,finallyTuesdays as --finally limit to the Tuesdays after the second wed
(
    SELECT calendar.*,
           ROW_NUMBER() OVER (partition by calendar.year, calendar.month
                              order by calendar.day) as rowNbr
    FROM   secondWednesdays
             JOIN tools.calendar
                ON secondWednesdays.year = calendar.year
                    AND secondWednesdays.month = calendar.month
    WHERE  calendar.dayName = 'Tuesday'
      AND  calendar.day > secondWednesdays.day
)
--and in the final query, just get the one month
SELECT year, monthName, day
FROM   finallyTuesdays
WHERE  year = 2008
  AND  rowNbr = 1
GO

DROP TABLE tools.calendar
go
CREATE TABLE tools.calendar
(
        dateValue date NOT NULL CONSTRAINT PKdate_dim PRIMARY KEY,
        dayName varchar(10) NOT NULL,
        monthName varchar(10) NOT NULL,
        year varchar(60) NOT NULL,
        day tinyint NOT NULL,
        dayOfTheYear smallint NOT NULL,
        month smallint NOT NULL,
        quarter tinyint NOT NULL,
        weekendFlag bit not null,

        --start of fiscal year configurable in the load process, currently
        --only supports fiscal months that match the calendar months.
        fiscalYear smallint NOT NULL,
        fiscalMonth tinyint NULL,
        fiscalQuarter tinyint NOT NULL,

        --used to give relative positioning, such as the previous 10 months
        --which can be annoying due to month boundries
        relativeDayCount int NOT NULL,
        relativeWeekCount int NOT NULL,
        relativeMonthCount int NOT NULL
)
GO

WITH dates (newDateValue) as (
        select dateadd(day,i,'17530101') as newDateValue
        from tools.sequence
)
INSERT tools.calendar
        (dateValue ,dayName
        ,monthName ,year ,day
        ,dayOfTheYear ,month ,quarter
        ,weekendFlag ,fiscalYear ,fiscalMonth
        ,fiscalQuarter ,relativeDayCount,relativeWeekCount
        ,relativeMonthCount)
SELECT
        dates.newDateValue as dateValue,
        datename (dw,dates.newDateValue) as dayName,
        datename (mm,dates.newDateValue) as monthName,
        datename (yy,dates.newDateValue) as year,
        datepart(day,dates.newDateValue) as day,
        datepart(dy,dates.newDateValue) as dayOfTheYear,
        datepart(m,dates.newDateValue) as month,
        case
                when month ( dates.newDateValue) <= 3 then 1
                when month ( dates.newDateValue) <= 6 then 2
                when month ( dates.newDateValue) <= 9 then 3
        else 4 end as quarter,

        case when datename (dw,dates.newDateValue) in ('Saturday','Sunday')
                then 1
                else 0
        end as weekendFlag,

        ------------------------------------------------
        --the next three blocks assume a fiscal year starting in July.
        --change if your fiscal periods are different
        ------------------------------------------------
        case
                when month(dates.newDateValue) <= 6
                then year(dates.newDateValue)
                else year (dates.newDateValue) + 1
        end as fiscalYear,

        case
                when month(dates.newDateValue) <= 6
                then month(dates.newDateValue) + 6
                else month(dates.newDateValue) - 6
         end as fiscalMonth,

        case
                when month(dates.newDateValue) <= 3 then 3
                when month(dates.newDateValue) <= 6 then 4
                when month(dates.newDateValue) <= 9 then 1
        else 2 end as fiscalQuarter,

        ------------------------------------------------
        --end of fiscal quarter = july
        ------------------------------------------------

        --these values can be anything, as long as the
        --provide contiguous values on year, month, and week boundaries
        datediff(day,'20000101',dates.newDateValue) as relativeDayCount,
        datediff(week,'20000101',dates.newDateValue) as relativeWeekCount,
        datediff(month,'20000101',dates.newDateValue) as relativeMonthCount

FROM    dates
WHERE  dates.newDateValue between '20000101' and '20100101' --set the date range
GO

SELECT calendar.fiscalYear, COUNT(*) as orderCount
FROM   AdventureWorks2008.Sales.SalesOrderHeader
         JOIN tools.calendar
               --note, the cast here could be a real performance killer
               --consider using date columns where
            ON CAST(SalesOrderHeader.OrderDate as date) = calendar.dateValue
WHERE    weekendFlag = 1
GROUP BY calendar.fiscalYear
ORDER BY calendar.fiscalYear
GO

DECLARE @interestingDate date = '20080107'

SELECT calendar.dateValue as previousTwoWeeks, currentDate.dateValue as today,
        calendar.relativeWeekCount
FROM   tools.calendar
           join (select *
                 from tools.calendar
                 where dateValue = @interestingDate) as currentDate
              on  calendar.relativeWeekCount < (currentDate.relativeWeekCount)
                  and calendar.relativeWeekCount >=
                                         (currentDate.relativeWeekCount -2)
GO

DECLARE @interestingDate date = '20080315'

SELECT MIN(calendar.dateValue), MAX(calendar.dateValue)
FROM   tools.calendar
           JOIN (SELECT *
                 FROM tools.calendar
                 WHERE dateValue = @interestingDate) as currentDate
              ON  calendar.relativeMonthCount < (currentDate.relativeMonthCount)
                  AND calendar.relativeMonthCount >=
                                       (currentDate.relativeMonthCount -12)
GO

DECLARE @interestingDate date = '20040827'

SELECT calendar.year, calendar.month, COUNT(*) as orderCount
FROM   AdventureWorks2008.Sales.SalesOrderHeader
         JOIN tools.calendar
           JOIN (select *
                 from tools.calendar
                 where dateValue = @interestingDate) as currentDate
               on  calendar.relativeMonthCount <=
                                           (currentDate.relativeMonthCount )
                    and calendar.relativeMonthCount >=
                                           (currentDate.relativeMonthCount -10)
            on cast(salesOrderHeader.shipDate as date)= calendar.dateValue
GROUP BY calendar.year, calendar.month
ORDER BY calendar.year, calendar.month
GO

-------------------------------------------------------------------
-- Storing User-Specified Data
-------------------------------------------------------------------

CREATE TABLE Equipment
(
    EquipmentId int NOT NULL
          CONSTRAINT PKEquipment PRIMARY KEY,
    EquipmentTag varchar(10) NOT NULL
          CONSTRAINT AKEquipment UNIQUE,
    EquipmentType varchar(10)
)
GO
INSERT INTO Equipment
VALUES (1,'CLAWHAMMER','Hammer'),
       (2,'HANDSAW','Saw'),
       (3,'POWERDRILL','PowerTool')
GO
-------------------------------------------------------------------
-- Storing User-Specified Data; Entity-Attribute-Value (EAV)
-------------------------------------------------------------------

CREATE TABLE EquipmentPropertyType
(
    EquipmentPropertyTypeId int NOT NULL
        CONSTRAINT PKEquipmentPropertyType PRIMARY KEY,
    Name varchar(15)
        CONSTRAINT AKEquipmentPropertyType UNIQUE,
    TreatAsDatatype sysname NOT NULL
)
INSERT INTO EquipmentPropertyType
VALUES(1,'Width','numeric(10,2)'),
      (2,'Length','numeric(10,2)'),
      (3,'HammerHeadStyle','varchar(30)')
GO
CREATE TABLE EquipmentProperty
(
    EquipmentId int NOT NULL
        CONSTRAINT Equipment$hasExtendedPropertiesIn$EquipmentProperty
           REFERENCES Equipment(EquipmentId),
    EquipmentPropertyTypeId int
        CONSTRAINT EquipmentPropertyTypeId$definesTypesFor$EquipmentProperty
           REFERENCES EquipmentPropertyType(EquipmentPropertyTypeId),
    Value sql_variant,
    CONSTRAINT PKEquipmentProperty PRIMARY KEY 
                     (EquipmentId, EquipmentPropertyTypeId)
)
GO

CREATE PROCEDURE EquipmentProperty$Insert
(
    @EquipmentId int,
    @EquipmentPropertyName varchar(15),
    @Value sql_variant
)
AS
    SET NOCOUNT ON
    DECLARE @entryTrancount int = @@trancount

    BEGIN TRY
        DECLARE @EquipmentPropertyTypeId int,
                @TreatASDatatype sysname

        SELECT @TreatASDatatype = TreatAsDatatype,
               @EquipmentPropertyTypeId = EquipmentPropertyTypeId
        FROM   EquipmentPropertyType
        WHERE  EquipmentPropertyType.Name = @EquipmentPropertyName

      BEGIN TRANSACTION
        --insert the value
        INSERT INTO EquipmentProperty(EquipmentId, EquipmentPropertyTypeId,
                    Value)
        VALUES (@EquipmentId, @EquipmentPropertyTypeId, @Value)

        --Then get that value from the table and cast it in a dynamic SQL
        -- call.  This will raise a trappable error if the type is incompatible
        DECLARE @validationQuery  varchar(max) =
              ' DECLARE @value sql_variant
                SELECT  @value = cast(value as ' + @TreatASDatatype + ')
                FROM    EquipmentProperty
                WHERE   EquipmentId = ' + cast (@EquipmentId as varchar(10)) + '
                  and   EquipmentPropertyTypeId = ' + 
                       cast(@EquipmentPropertyTypeId as varchar(10)) + ' '

        EXEC (@validationQuery)
      COMMIT TRANSACTION
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
Exec EquipmentProperty$Insert 1,'Width','Claw' --width is numeric(10,2)
GO

EXEC EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'Width', @Value = 2
EXEC EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'Length',@Value = 8.4
EXEC EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'HammerHeadStyle',@Value = 'Claw'
EXEC EquipmentProperty$Insert @EquipmentId =2 ,
        @EquipmentPropertyName = 'Width',@Value = 1
EXEC EquipmentProperty$Insert @EquipmentId =2 ,
        @EquipmentPropertyName = 'Length',@Value = 7
EXEC EquipmentProperty$Insert @EquipmentId =3 ,
        @EquipmentPropertyName = 'Width',@Value = 6
EXEC EquipmentProperty$Insert @EquipmentId =3 ,
        @EquipmentPropertyName = 'Length',@Value = 12.1
GO
SELECT Equipment.EquipmentTag,Equipment.EquipmentType,
       EquipmentPropertyType.name, EquipmentProperty.Value
FROM   EquipmentProperty
         JOIN Equipment
            on Equipment.EquipmentId = EquipmentProperty.EquipmentId
         JOIN EquipmentPropertyType
            on EquipmentPropertyType.EquipmentPropertyTypeId =
                                   EquipmentProperty.EquipmentPropertyTypeId
GO

SET ANSI_WARNINGS OFF --eliminates the NULL warning on aggregates.
SELECT  Equipment.EquipmentTag,Equipment.EquipmentType,
   MAX(CASE WHEN EquipmentPropertyType.name = 'Width' THEN Value END) AS Width,
   MAX(CASE WHEN EquipmentPropertyType.name = 'Length'THEN Value END) AS Length,
   MAX(CASE WHEN EquipmentPropertyType.name = 'HammerHeadStyle' THEN Value END)
                                                            AS 'HammerHeadStyle'
FROM   EquipmentProperty
         JOIN Equipment
            on Equipment.EquipmentId = EquipmentProperty.EquipmentId
         JOIN EquipmentPropertyType
            on EquipmentPropertyType.EquipmentPropertyTypeId =
                                     EquipmentProperty.EquipmentPropertyTypeId
GROUP BY Equipment.EquipmentTag,Equipment.EquipmentType
GO

SET ANSI_WARNINGS OFF
DECLARE @query varchar(8000)
SELECT  @query = 'select Equipment.EquipmentTag,Equipment.EquipmentType ' + (
                SELECT distinct
                    ',MAX(CASE WHEN EquipmentPropertyType.name = ''' +
                       EquipmentPropertyType.name + ''' THEN cast(Value as ' +
                       EquipmentPropertyType.TreatAsDatatype + ') END) AS [' +
                       EquipmentPropertyType.name + ']' AS [text()]
                FROM
                    EquipmentPropertyType
                FOR XML PATH('') ) + '
                FROM  EquipmentProperty
                             JOIN Equipment
                                on Equipment.EquipmentId =
                                     EquipmentProperty.EquipmentId
                             JOIN EquipmentPropertyType
                                on EquipmentPropertyType.EquipmentPropertyTypeId
                                   = EquipmentProperty.EquipmentPropertyTypeId
          GROUP BY Equipment.EquipmentTag,Equipment.EquipmentType  '
EXEC (@query)
GO

-------------------------------------------------------------------
-- Storing User-Specified Data; Adding Columns to a Table
-------------------------------------------------------------------

ALTER TABLE Equipment
    ADD Length numeric(10,2) SPARSE NULL
GO

CREATE PROCEDURE equipment$addProperty
(
    @propertyName   sysname, --the column to add
    @datatype       sysname, --the datatype as it appears in a column creation
    @sparselyPopulatedFlag bit = 1 --Add column as sparse or not
)
WITH EXECUTE AS SELF
AS
  --note: I did not include full error handling for clarity
  DECLARE @query nvarchar(max)

 --check for column existance
 IF NOT EXISTS (select *
               from   sys.columns
               where  name = @propertyName
                 and  OBJECT_NAME(object_id) = 'equipment')
  BEGIN
    --build the ALTER statement, then execute it
     SET @query = 'ALTER TABLE equipment ADD ' + quotename(@propertyName) + ' '
                + @datatype 
                + case when @sparselyPopulatedFlag = 1 then ' SPARSE ' end
                + ' NULL '
     EXEC (@query)
  END
 ELSE
     RAISERROR ('The property you are adding already exists',16,1)
GO
--exec equipment$addProperty 'Length','numeric(10,2)',1 -- added manually
EXEC equipment$addProperty 'Width','numeric(10,2)',1
EXEC equipment$addProperty 'HammerHeadStyle','varchar(30)',1
GO

SELECT EquipmentTag, EquipmentType, HammerHeadStyle
       ,Length,Width
FROM   Equipment
GO

UPDATE Equipment
SET    Length = 7,
       Width =  1
WHERE  EquipmentTag = 'HANDSAW'
GO

SELECT EquipmentTag, EquipmentType, HammerHeadStyle
       ,Length,Width
FROM   Equipment
GO

ALTER TABLE Equipment
 ADD CONSTRAINT CHKEquipment$HammerHeadStyle CHECK
        ((HammerHeadStyle is NULL AND EquipmentType <> 'Hammer')
        OR EquipmentType = 'Hammer')
GO

UPDATE Equipment
SET    Length = 12.1,
       Width =  6,
       HammerHeadStyle = 'Wrong!'
WHERE  EquipmentTag = 'HANDSAW'
GO

UPDATE Equipment
SET    Length = 12.1,
       Width =  6
WHERE  EquipmentTag = 'POWERDRILL'

UPDATE Equipment
SET    Length = 8.4,
       Width =  2,
       HammerHeadStyle = 'Claw'
WHERE  EquipmentTag = 'CLAWHAMMER'

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle
       ,Length,Width
FROM   Equipment
GO

SELECT name, is_sparse
FROM   sys.columns
WHERE  OBJECT_NAME(object_id) = 'Equipment'
GO

ALTER TABLE Equipment
    DROP CONSTRAINT CHKEquipment$HammerHeadStyle
ALTER TABLE Equipment
    DROP COLUMN HammerHeadStyle, Length, Width
GO
ALTER TABLE Equipment
  ADD SparseColumns xml column_set FOR ALL_SPARSE_COLUMNS

GO
EXEC equipment$addProperty 'Length','numeric(10,2)',1
EXEC equipment$addProperty 'Width','numeric(10,2)',1
EXEC equipment$addProperty 'HammerHeadStyle','varchar(30)',1
GO
ALTER TABLE Equipment
 ADD CONSTRAINT CHKEquipment$HammerHeadStyle CHECK
        ((HammerHeadStyle is NULL AND EquipmentType <> 'Hammer')
        OR EquipmentType = 'Hammer')
GO
UPDATE Equipment
SET    Length = 7,
       Width =  1
WHERE  EquipmentTag = 'HANDSAW'

GO
SELECT *
FROM   Equipment
GO

UPDATE Equipment
SET    SparseColumns = '<Length>12.10</Length><Width>6.00</Width>'
WHERE  EquipmentTag = 'PowerDrill'

UPDATE Equipment
SET    SparseColumns = '<Length>8.40</Length><Width>2.00</Width>
                        <HammerHeadStyle>Claw</HammerHeadStyle>'
WHERE  EquipmentTag = 'CLAWHAMMER'
GO
--------------------------------------------------------------------------------------
-- Commonly Implemented Objects
--------------------------------------------------------------------------------------

CREATE SCHEMA utility
GO
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

