USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetWeeklyOffHoliDay]
	@FromDate [nvarchar](25) = null,
	@EmployeeID [int] = 0,
	@userid [int] = 1,
	@langid [int] = 1,
	@DATYPE [nvarchar](100) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
declare @PayrollDate datetime,@STARTDATE datetime,@ToDate datetime,@IsHoliday BIT=0,@IsHolidayMast BIT=0,@IsWeeklyOff BIT=0

EXEC spPAY_GetPayrollDate @FROMDATE,@PayrollDate OUTPUT,@STARTDATE OUTPUT, @ToDate OUTPUT 

--SELECT @PayrollDate,@STARTDATE,@ToDate

CREATE TABLE #EMPWEEKLYOFF(Week1_W1 varchar(50),Week1_W2 varchar(50),Week2_W1 varchar(50),Week2_W2 varchar(50), Week3_W1 varchar(50),
								   Week3_W2 varchar(50),Week4_W1 varchar(50),Week4_W2 varchar(50),Week5_W1 varchar(50),Week5_W2 varchar(50))

DECLARE @EMPMASTWF TABLE(ID INT IDENTITY(1,1),NODEID INT,WeeklyOff1 nvarchar(100),WeeklyOff2 nvarchar(100))

DECLARE @WeeklyOffsDefBasedOn NVARCHAR(MAX),@WhereCond NVARCHAR(MAX),@HCCID INT,@CCType NVARCHAR(50),@SQL nvarchar(max)
SELECT @WeeklyOffsDefBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='WeeklyOffsDefBasedOn'
SET @SQL='' SET @WhereCond=''
IF(@WeeklyOffsDefBasedOn<>'')
BEGIN
	DECLARE @BasedOn TABLE (HCCID INT)  
	INSERT INTO @BasedOn  
	EXEC SPSplitString @WeeklyOffsDefBasedOn,','  
	
	DECLARE CUR CURSOR FOR SELECT HCCID FROM @BasedOn
	OPEN CUR
	FETCH NEXT FROM CUR INTO @HCCID
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF EXISTS(SELECT CostCenterColID FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1)
		BEGIN
			SELECT @CCType= ISNULL(UserProbableValues,'') FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1  
			IF(@CCType='')
			BEGIN
			print @WhereCond
				SET @WhereCond=@WhereCond+' 
											AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (Select CCNID'+CONVERT(NVARCHAR,(@HCCID-50000))+' FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+CONVERT(NVARCHAR,@EmployeeID)+') )) '
			END
			ELSE
			BEGIN
				SET @WhereCond=@WhereCond+' AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
											WHERE NodeID IN('+convert(nvarchar,@EmployeeID)+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@HCCID)+'   
											AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR 
												CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@STARTDATE)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ToDate)+''')) 
											AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR ToDate IS NULL)) ) ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC '
									
			END
		END
	FETCH NEXT FROM CUR INTO @HCCID
	END
	CLOSE CUR
	DEALLOCATE CUR	

SET @SQL='
SELECT TOP 1 TD.dcAlpha2 Week1_W1,TD.dcAlpha3 Week1_W2,TD.dcAlpha4 Week2_W1,TD.dcAlpha5 Week2_W2,TD.dcAlpha6 Week3_W1,TD.dcAlpha7 Week3_W2,TD.dcAlpha8 Week4_W1,TD.dcAlpha9 Week4_W2,
			         TD.dcAlpha10 Week5_W1,TD.dcAlpha11 Week5_W2	
FROM INV_DOCDETAILS ID WITH(NOLOCK)
Left Join COM_DocTextData TD WITH(NOLOCK) on TD.InvDocdetailsID=ID.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=ID.InvDocDetailsId
left join com_status status WITH(NOLOCK) on status.statusId=369
Where ID.StatusID=369 AND ID.CostCenterID=40053  and TD.dcAlpha1=''No'' and CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@FromDate)+''')											
		'
IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
BEGIN
	SET @SQL=@SQL+ @WhereCond
END
--PRINT @SQL
INSERT INTO #EMPWEEKLYOFF
EXEC sp_executesql @SQL	

END

--START HOLIDAYS
DECLARE @HolidayBasedOn NVARCHAR(MAX)
SELECT @HolidayBasedOn=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='HolidaysBasedOn'
SET @SQL='' SET @WhereCond='' SET @CCType=''
IF(@HolidayBasedOn<>'')
BEGIN
	DECLARE @HBOnH TABLE (HCCID INT)  
	INSERT INTO @HBOnH  
	EXEC SPSplitString @HolidayBasedOn,','  
	
	DECLARE CUR CURSOR FOR SELECT HCCID FROM @HBOnH
	OPEN CUR
	FETCH NEXT FROM CUR INTO @HCCID
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF EXISTS(SELECT CostCenterColID FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1)
		BEGIN
			SELECT @CCType= ISNULL(UserProbableValues,'') FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE CostCenterID=50051 AND ColumnCostCenterID=@HCCID AND IsColumnInUse=1  
			IF(@CCType='')
			BEGIN
				SET @WhereCond=@WhereCond+' 
											AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( Select CCNID'+CONVERT(NVARCHAR,(@HCCID-50000))+' FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID IN('+CONVERT(NVARCHAR,@EmployeeID)+'))) '
			END
			ELSE
			BEGIN
				SET @WhereCond=@WhereCond+' 
											AND (c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN (1) OR c.dcCCNID'+CONVERT(NVARCHAR,(@HCCID-50000)) +' IN ( SELECT DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) 
											WHERE NodeID IN('+convert(nvarchar,@EmployeeID)+') AND CostCenterID=50051 AND HistoryCCID='+CONVERT(NVARCHAR,@HCCID)+'   
											AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR 
												CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@STARTDATE)+''') AND CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@ToDate)+''')) 
											AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@PayrollDate)+''') OR ToDate IS NULL)) ) '
			END
		END
	FETCH NEXT FROM CUR INTO @HCCID
	END
	CLOSE CUR
	DEALLOCATE CUR
	

SET @SQL='
SELECT b.dcalpha1,b.dcalpha2
FROM INV_DOCDETAILS a WITH(NOLOCK)
Left Join COM_DocTextData b WITH(NOLOCK) on b.InvDocdetailsID=a.InvDocDetailsId
Left Join COM_DocCCData c WITH(NOLOCK) on c.InvDocdetailsID=a.InvDocDetailsId
left join com_status status WITH(NOLOCK) on status.statusId=369
Where a.StatusID=369 AND a.CostCenterID=40051  and isdate(b.dcAlpha1)=1 
And convert(datetime,b.dcalpha1)=CONVERT(DATETIME,'''+CONVERT(NVARCHAR,@FromDate)+''')'

IF(@WhereCond IS NOT NULL AND @WhereCond <>'' AND LEN(@WhereCond)>0)
BEGIN
	SET @SQL=@SQL+ @WhereCond
END
--PRINT @SQL

Declare @TEmp table (ID int Identity(1,1),WEEKDATE Nvarchar(max),Remarks nvarchar(max))
insert into @TEmp
EXEC sp_executesql @SQL

IF(SELECT COUNT(*) FROM @TEmp)>0
BEGIN
SET @IsHoliday=1
SET @IsHolidayMast=1
END

END
--END HOLIDAYS

DECLARE @WEEKLYOFF TABLE (WEEKLYWEEKOFFNO int,DAYNAME varchar(100))	
IF (SELECT COUNT(*) FROM #EMPWEEKLYOFF WITH(NOLOCK))>0
BEGIN

INSERT INTO @WEEKLYOFF
				select case isnull(Week1_W1,'') when '' then 0 else 1 end,case isnull(Week1_W1,'') when '' then '' else Week1_W1 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week1_W2,'') when '' then 0 else 1 end,case isnull(Week1_W2,'') when '' then '' else Week1_W2 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week2_W1,'') when '' then 0 else 2 end,case isnull(Week2_W1,'') when '' then '' else Week2_W1 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week2_W2,'') when '' then 0 else 2 end,case isnull(Week2_W2,'') when '' then '' else Week2_W2 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week3_W1,'') when '' then 0 else 3 end,case isnull(Week3_W1,'') when '' then '' else Week3_W1 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week3_W2,'') when '' then 0 else 3 end,case isnull(Week3_W2,'') when '' then '' else Week3_W2 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week4_W1,'') when '' then 0 else 4 end,case isnull(Week4_W1,'') when '' then '' else Week4_W1 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week4_W2,'') when '' then 0 else 4 end,case isnull(Week4_W2,'') when '' then '' else Week4_W2 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week5_W1,'') when '' then 0 else 5 end,case isnull(Week5_W1,'') when '' then '' else Week5_W1 end FROM #EMPWEEKLYOFF WITH(NOLOCK)
			UNION ALL
				select case isnull(Week5_W2,'') when '' then 0 else 5 end,case isnull(Week5_W2,'') when '' then '' else Week5_W2 end FROM #EMPWEEKLYOFF WITH(NOLOCK)

DECLARE @WEEKOFFCOUNT TABLE (ID INT ,WEEKDATE DATETIME,DAYNAME VARCHAR(50),WEEKNO INT,ISVALIDDAY INT,REMARKS VARCHAR(1000))
		DECLARE @STARTDATE1 DATETIME,@ToDate1 DATETIME
		
		SET @STARTDATE1=convert(datetime,@STARTDATE)
		SET @ToDate1=DATEADD(d,0,@ToDate)
		
			;WITH DATERANGE AS
			(
			SELECT @STARTDATE1 AS DT,1 AS ID
			UNION ALL
			SELECT DATEADD(DD,1,DT),DATERANGE.ID+1 FROM DATERANGE WHERE ID<=DATEDIFF("d",convert(datetime,@STARTDATE),convert(datetime,@ToDate1))
			)
			
			INSERT INTO @WEEKOFFCOUNT
			SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0,'' FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
		--END : LOADING WEEKDATE,DAYNAME AND WEEKNO FOR SELECTED DATERANGE	
		--START : UPDATING ISVALIDDAY FOR WEEKLYOFF AND HOLIDAY
			--UPDATING WEEKNO IN WEEKOFFCOUNT TABLE BASED ON WEEKDATE OF MONTH
			--------------------
						declare @PMS int,@PME int
						select @PMS=Value From ADM_GlobalPreferences WITH(NOLOCK) where name='PayDayStart'
						select @PME=Value From ADM_GlobalPreferences WITH(NOLOCK) where name='PayDayEnd'

						declare @PS INT,@PE INT
						declare @wd datetime,@TSwd datetime,@TEwd datetime,@dme datetime
						declare @wno int
						set @wno=0
						select @TSwd=MIN(Weekdate),@TEwd=MAX(Weekdate) FROM @WEEKOFFCOUNT
						--SET @TSwd='01-Nov-2019' SET @TEwd='01-Dec-2019'
						WHILE(@TSwd<=@TEwd)
						BEGIN
							IF(DAY(@TSwd)=@PMS)
							BEGIN
								set @wno=1
								Update @WEEKOFFCOUNT SET WEEKNo=@wno WHERE WeekDate=@TSwd
								set @dme=dateadd(day,-1,dateadd(m,1,@TSwd))
								
								Update @WEEKOFFCOUNT SET WEEKNo=@wno 
								where WeekDate between @TSwd AND DATEADD(day,6,@TSwd)
								
								SET @TSwd=DATEADD(day,7,@TSwd)
								set @wno=@wno+1
							END
							ELSE
							BEGIN
								if(@wno=0)
									SET @TSwd=DATEADD(day,1,@TSwd)
								else
								begin
									IF(DAY(DATEADD(day,6,@TSwd))<=@PME)
									begin
										Update @WEEKOFFCOUNT SET WEEKNo=@wno 
										where WeekDate between @TSwd AND DATEADD(day,6,@TSwd)
										SET @TSwd=DATEADD(day,7,@TSwd)
										set @wno=@wno+1

										if(DATEADD(day,6,@TSwd)>@dme)
										BEGIN
											Update @WEEKOFFCOUNT SET WEEKNo=@wno 
											where WeekDate between @TSwd AND @dme
											SET @TSwd=DATEADD(day,1,@dme)
										END
										
									end
									else 
									begin
										Update @WEEKOFFCOUNT SET WEEKNo=@wno 
										where WeekDate between @TSwd AND @dme
										SET @TSwd=DATEADD(day,1,@dme)
									end
									
								end
							END	
							
						END 

						--------------------------
			
			--UPDATING ISVALIDDAY TO 1 IF WEEKNO AND DAYNAME IS WEEKLYOFF
			UPDATE WEEKOFFCOUNT SET WEEKOFFCOUNT.ISVALIDDAY=1,WEEKOFFCOUNT.REMARKS='Weeklyoff' FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join @WEEKLYOFF WEEKLYOFF on WEEKLYOFF.WEEKLYWEEKOFFNO=WEEKOFFCOUNT.WEEKNO AND upper(WEEKLYOFF.DAYNAME)=upper(WEEKOFFCOUNT.DAYNAME)
			
		IF(SELECT ISVALIDDAY FROM @WEEKOFFCOUNT WHERE CONVERT(DATETIME,WEEKDATE)=CONVERT(DATETIME,@FromDate))=1
			BEGIN
			set @IsHoliday=1
				--EXEC SPPAY_GETHOLIDAY @FROMDATE,@EMPLOYEEID,@USERID,@LANGID,@ISHOLIDAY OUTPUT,@ISHOLIDAYMAST OUTPUT     
				IF(@ISHOLIDAYMAST=0)
					SET @ISWEEKLYOFF=1 
			END
		----ELSE
		----	BEGIN
		----		EXEC SPPAY_GETHOLIDAY @FROMDATE,@EMPLOYEEID,@USERID,@LANGID,@ISHOLIDAY OUTPUT,@ISHOLIDAYMAST OUTPUT      
		----	END
END
ELSE
BEGIN
--START : CheckWeeklyOffsAtPrefAndMaster

DECLARE @WOff1 NVARCHAR(100),@WOff2 NVARCHAR(100)
INSERT INTO @EMPMASTWF
SELECT NODEID,WeeklyOff1,WeeklyOff2 FROM COM_CC50051 WITH(NOLOCK) where NodeID=@EmployeeID

if(SELECT WeeklyOff1 FROM @EMPMASTWF)<>'None'
BEGIN
	SELECT @WOff1=WeeklyOff1 FROM @EMPMASTWF
END
ELSE
BEGIN
	SELECT @WOff1=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='WeeklyOff1'
END

if(SELECT WeeklyOff2 FROM @EMPMASTWF)<>'None'
BEGIN
	SELECT @WOff2=WeeklyOff2 FROM @EMPMASTWF
END
ELSE
BEGIN
	SELECT @WOff2=ISNULL(Value,'') From ADM_GlobalPreferences WITH(NOLOCK) Where Name='WeeklyOff2'
END

IF((datename(WEEKDAY,@FromDate)=@WOff1) OR (datename(WEEKDAY,@FromDate)=@WOff2))
BEGIN
set @IsHoliday=1
	--EXEC spPAY_GetHoliDay @FromDate,@EmployeeID,@userid,@langid,@IsHoliday OUTPUT,@IsHolidayMast OUTPUT      
	
	IF(@IsHolidayMast=0)
		SET @IsWeeklyOff=1 
END
--ELSE
--BEGIN
--	EXEC spPAY_GetHoliDay @FromDate,@EmployeeID,@userid,@langid,@IsHoliday OUTPUT,@IsHolidayMast OUTPUT
--END

-- END : CheckWeeklyOffsAtPrefAndMaster
END


--SELECT @IsHoliday IsHoliday,@IsHolidayMast IsHolidayMast,@IsWeeklyOff IsWeeklyOff
IF(@IsHoliday=1)
BEGIN

	IF(@IsWeeklyOff=1)
		SET @DATYPE='W'
	ELSE
		SET @DATYPE='H'
END
ELSE
BEGIN
	SET @DATYPE=''
END

SET NOCOUNT OFF;		
END


----spPAY_GetWeeklyOffHoliDay
--'02-jan-2021',
--3,
--1,
--1,
--''
GO
