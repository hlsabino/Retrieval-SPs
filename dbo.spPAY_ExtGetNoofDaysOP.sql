USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetNoofDaysOP]
	@FromDate [varchar](20) = NULL,
	@ToDate [varchar](20) = null,
	@EmployeeID [int] = 0,
	@LeaveType [int] = 0,
	@Session [varchar](20) = null,
	@userid [int] = 1,
	@langid [int] = 1,
	@Days [decimal](9, 2),
	@NoOfDaysOP [decimal](9, 2) OUTPUT,
	@FromDateOP [datetime] OUTPUT,
	@ToDateOP [datetime] OUTPUT,
	@AtATimeOP [int] OUTPUT,
	@MaxLeavesOP [int] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @NOOFHOLIDAYS INT
	DECLARE @WEEKLYOFFCOUNT INT
	DECLARE @GRADE INT
	DECLARE @INCREXC VARCHAR(50)
	DECLARE @ATATIME INT
	DECLARE @MAXLEAVES INT
	DECLARE @CurrYearLeavestaken DECIMAL(9,2)
	--FOR GRADE
	SELECT @GRADE=ISNULL(CCNID53,0) FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID=@EmployeeID
			IF(@FromDate is not null and @ToDate is not null and isnull(@Session,'Both')='Both')
			BEGIN			
				--INCLUDE OR EXCLUDE HOLIDAYS, ATATIME,MAXLEAVES AND WEEKLYOFFS
						SELECT @INCREXC=ISNULL(INCLUDEREXCLUDE,''),@ATATIME=ISNULL(ATATIME,0),@MAXLEAVES=ISNULL(MAXLEAVES,0) FROM COM_CC50054 WITH(NOLOCK)  
						WHERE  GRADEID=@GRADE AND COMPONENTID=@LeaveType AND MONTH(CONVERT(DATETIME,PAYROLLDATE))=MONTH(CONVERT(DATETIME,@FromDate))	
				--CURRENT YEAR LEAVES TAKEN
						SELECT @CurrYearLeavestaken=SUM(ISNULL(CONVERT(DECIMAL(9,2),TD.dcAlpha7),0))
						FROM INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
						WHERE ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND DC.INVDOCDETAILSID=TD.INVDOCDETAILSID AND 
			            YEAR(CONVERT(DATETIME,ID.DOCDATE))=YEAR(CONVERT(DATETIME,@FromDate)) AND
			            ID.STATUSID NOT IN (372,376) AND
			            DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType AND DC.DCCCNID53=@Grade
			     --CALCULATE MAXNOOFDAYS
						IF ISNULL(@MAXLEAVES,0)>0
						BEGIN
							SET @MAXLEAVES=ISNULL(@MAXLEAVES,0)-ISNULL(@CurrYearLeavestaken,0)
						END
				
				--START WEEKLYOFF COUNT
						--LOADING WEEKLYOFF INFORMATION OF EMPLOYEE
						DECLARE @EMPWEEKLYOFF TABLE (WK11 varchar(50),WK12 varchar(50),WK21 varchar(50),WK22 varchar(50), WK31 varchar(50),
												   WK32 varchar(50),WK41 varchar(50),WK42 varchar(50),WK51 varchar(50),WK52 varchar(50))
						DECLARE @WEEKLYOFF TABLE (WEEKLYWEEKOFFNO int,DAYNAME varchar(100))										   
												   
						--LOADING DATA FROM WEEKLYOFF MASTER											   
						INSERT INTO @EMPWEEKLYOFF 
						SELECT TOP 1 TD.dcAlpha2 WK11,TD.dcAlpha3 WK12,TD.dcAlpha4 WK21,TD.dcAlpha5 WK22,TD.dcAlpha6 WK31,TD.dcAlpha7 WK32,TD.dcAlpha8 WK41,TD.dcAlpha9 WK42,
							         TD.dcAlpha10 WK51,TD.dcAlpha11 WK52	FROM COM_DocCCData DC,INV_DOCDETAILS ID ,COM_DocTextData TD
						WHERE        DC.INVDOCDETAILSID=ID.INVDOCDETAILSID AND TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.COSTCENTERID=40053 AND DC.dcCCNID51=@EmployeeID	AND
						             CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,@FromDate)											
						ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC
						
						--CHECKING FOR EMPLOYEE WEEKLY OFF COUNT FROM WEEKLYOFF MASTER IF NO DATA FOUND
						--LOADING DATA FROM EMPLOYEE MASTER
						IF (SELECT COUNT(*) FROM @EMPWEEKLYOFF)<=0
						BEGIN
							INSERT INTO @EMPWEEKLYOFF 
							SELECT WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,
							       WeeklyOff1,WeeklyOff2	FROM COM_CC50051 
							WHERE  NODEID=@EmployeeID
							DELETE FROM @EMPWEEKLYOFF WHERE ISNULL(WK11,'None')='None' OR ISNULL(WK11,'0')='0'
						END
						
						--CHECKING FOR EMPLOYEE WEEKLY OFF COUNT FROM EMPLOYEE MASTER IF NO DATA FOUND
						--LOADING DATA FROM PREFERENCES
						IF (SELECT COUNT(*) FROM @EMPWEEKLYOFF)<=0
						BEGIN
							INSERT INTO @WEEKLYOFF 
							SELECT case isnull(VALUE,'') when '' then 0 else 1 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 1 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 2 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 2 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'					  
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 3 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 3 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'					  
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 4 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 4 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'					  
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 5 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
							UNION ALL
							SELECT case isnull(VALUE,'') when '' then 0 else 5 end,VALUE	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'		
						END
										
						--LOADING WEEKNO AND DAYNAME INTO ROWS FROM @EMPWEEKLYOFF TABLE (WEEKLYOFF AND EMPLOYEE MASTER)
						IF (SELECT COUNT(*) FROM @WEEKLYOFF)<=0
						BEGIN
							INSERT INTO @WEEKLYOFF
								select case isnull(WK11,'') when '' then 0 else 1 end,case isnull(WK11,'') when '' then '' else WK11 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK12,'') when '' then 0 else 1 end,case isnull(WK12,'') when '' then '' else WK12 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK21,'') when '' then 0 else 2 end,case isnull(WK21,'') when '' then '' else WK21 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK22,'') when '' then 0 else 2 end,case isnull(WK22,'') when '' then '' else WK22 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK31,'') when '' then 0 else 3 end,case isnull(WK31,'') when '' then '' else WK31 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK32,'') when '' then 0 else 3 end,case isnull(WK32,'') when '' then '' else WK32 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK41,'') when '' then 0 else 4 end,case isnull(WK41,'') when '' then '' else WK41 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK42,'') when '' then 0 else 4 end,case isnull(WK42,'') when '' then '' else WK42 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK51,'') when '' then 0 else 5 end,case isnull(WK51,'') when '' then '' else WK51 end FROM @EMPWEEKLYOFF
							UNION ALL
								select case isnull(WK52,'') when '' then 0 else 5 end,case isnull(WK52,'') when '' then '' else WK52 end FROM @EMPWEEKLYOFF
						END
						--LOADING WEEKDATE,DAYNAME AND WEEKNO FOR SELECTED DATERANGE
						DECLARE @WEEKOFFCOUNT TABLE (ID INT ,WEEKDATE DATETIME,DAYNAME VARCHAR(50),WEEKNO INT,COUNT INT)
						DECLARE @STARTDATE DATETIME
						DECLARE @FRDT DATETIME
						DECLARE @TDT DATETIME
						SET @STARTDATE=@FromDate
						SET @FRDT=@FromDate
						SET @TDT=DATEADD(d,-1,dateadd(m,datediff(m,0,@FromDate)+1,0))
						
							;WITH DATERANGE AS
							(
							SELECT @STARTDATE AS DT,1 AS ID
							UNION ALL
							SELECT DATEADD(DD,1,DT),DATERANGE.ID+1 FROM DATERANGE WHERE ID<=DATEDIFF("d",convert(varchar,@FRDT,101),convert(varchar,@TDT,101))
							)
							
							INSERT INTO @WEEKOFFCOUNT
							SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0 FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
							
							
							
							--UPDATING WEEKNO IN WEEKOFFCOUNT TABLE BASED ON WEEKDATE OF MONTH
							UPDATE @WEEKOFFCOUNT SET WEEKNO=((datepart(day,WEEKDATE)-1)/7)+1
							
							--UPDATING COUNT TO 1 IF WEEKNO AND DAYNAME IS WEEKLYOFF
							UPDATE WEEKOFFCOUNT SET WEEKOFFCOUNT.count=1
							FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join @WEEKLYOFF WEEKLYOFF on WEEKLYOFF.WEEKLYWEEKOFFNO=WEEKOFFCOUNT.WEEKNO 
								 AND upper(WEEKLYOFF.DAYNAME)=upper(WEEKOFFCOUNT.DAYNAME)
							--UPDATING COUNT TO 2 IF Holidays exist 
							 UPDATE WEEKOFFCOUNT SET WEEKOFFCOUNT.count=2
							   FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join COM_DocTextData TD on CONVERT(DATETIME,WEEKOFFCOUNT.WEEKDATE)=CONVERT(DATETIME,TD.dcAlpha1)
							   inner join INV_DOCDETAILS ID  on  ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
						AND CONVERT(DATETIME,@FromDate) <= CONVERT(DATETIME,TD.dcAlpha1)
						AND CONVERT(DATETIME,@ToDate) >= CONVERT(DATETIME,TD.dcAlpha1)
						WHERE TD.tCOSTCENTERID=40051
							 
							
						----------START :FOR INCLUDE OR EXCLUDE WEEKDATE BASED ON WEEKLYOFF AND HOLIDAYS
						IF ISNULL(@INCREXC,'')='IncludeHolidays' OR ISNULL(@INCREXC,'')='ExcludeWeeklyOffs'
						BEGIN
							 UPDATE @WEEKOFFCOUNT SET COUNT=0 WHERE COUNT=1
						END
						ELSE IF ISNULL(@INCREXC,'')='IncludeWeeklyOffs' OR ISNULL(@INCREXC,'')='ExcludeHolidays'
						BEGIN
							UPDATE @WEEKOFFCOUNT SET COUNT=0 WHERE COUNT=2
						END
						ELSE IF ISNULL(@INCREXC,'')='ExcludeBoth'
						BEGIN
							UPDATE @WEEKOFFCOUNT SET COUNT=0 WHERE COUNT=1
							UPDATE @WEEKOFFCOUNT SET COUNT=0 WHERE COUNT=2
						END
						----------END :FOR INCLUDE OR EXCLUDE WEEKDATE BASED ON WEEKLYOFF AND HOLIDAYS
						
							 
						--COUNTING WEEKLYOFFS IN GIVEN DATERANGE
						SELECT @WEEKLYOFFCOUNT=COUNT(*) FROM @WEEKOFFCOUNT WHERE COUNT=1	
						SELECT @NOOFHOLIDAYS=COUNT(*) FROM @WEEKOFFCOUNT WHERE COUNT=2	
						--END WEEKLYOFF COUNT
						
						----------START :CHECKING WEEKDAYS NOT HAVING WEEKLYOFFS AND HOLIDAYS
						DECLARE @FD AS DATETIME
						DECLARE @TD AS DATETIME
						
						DECLARE @WEEKDAYS TABLE (ID INT IDENTITY(1,1) ,WEEKDATE DATETIME)
						INSERT INTO @WEEKDAYS SELECT WEEKDATE FROM @WEEKOFFCOUNT WHERE COUNT=0
						
						
						DECLARE @DATELIST TABLE (FROMDATE DATETIME,TODATE DATETIME ,NOOFDAYS INT)
						INSERT INTO @DATELIST VALUES(null,null,@Days)
						DECLARE @K AS INT
						SET @K=1
						DECLARE @RCOUNT AS INT
						DECLARE @DATENAVL AS INT
						DECLARE @DATENAVL1 AS INT
						SET @DATENAVL1=0
						SELECT @RCOUNT= count(*) FROM @WEEKDAYS 
						WHILE(@K<=@RCOUNT)
						BEGIN
							SELECT @FD=WEEKDATE FROM @WEEKDAYS WHERE ID=@K 
							
							SELECT @DATENAVL=COUNT(*) FROM COM_DocTextData TD WITH(NOLOCK),INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC WITH(NOLOCK)
							WHERE  TD.tCostCenterID=40062 AND TD.InvDocDetailsID=DC.InvDocDetailsID AND	ID.InvDocDetailsID=TD.InvDocDetailsID  
								   AND DC.dcCCNID51=@EmployeeID  AND DC.dcCCNID53=@GRADE AND 
								   --AND DC.dcCCNID52=@LeaveType
								   (CONVERT(DATETIME,dcAlpha4) between CONVERT(DATETIME,@FD) and CONVERT(DATETIME,@FD)
  									or CONVERT(DATETIME,dcAlpha5) between CONVERT(DATETIME,@FD) and CONVERT(DATETIME,@FD)
									or CONVERT(DATETIME,@FD) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5))
					 
							IF (ISNULL(@DATENAVL,0)=0)
							BEGIN
								SET @DATENAVL1=@DATENAVL1+1
								UPDATE @DATELIST SET FROMDATE=@FD WHERE ISNULL(FROMDATE,'')=''
									
								IF (isnull(@DATENAVL1,0)=@Days)
								BEGIN
									UPDATE @DATELIST SET TODATE=@FD
								END
							END
						SET @K=@K+1
						END
						
						SELECT @FROMDATE=FROMDATE,@TODATE=TODATE FROM @DATELIST 
						----------START :CHECKING WEEKDAYS NOT HAVING WEEKLYOFFS AND HOLIDAYS
				
				IF ISNULL(@INCREXC,'')='IncludeHolidays' OR ISNULL(@INCREXC,'')='ExcludeWeeklyOffs'
				BEGIN
					
					SELECT @NoOfDaysOP=(DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101))-ISNULL(@NOOFHOLIDAYS,0))+1 ,@FromDateOP=CONVERT(DATETIME,@FromDate),@ToDateOP=CONVERT(DATETIME,@ToDate),@AtATimeOP=@ATATIME,@MaxLeavesOP=@MAXLEAVES
				END
				ELSE IF ISNULL(@INCREXC,'')='IncludeWeeklyOffs' OR ISNULL(@INCREXC,'')='ExcludeHolidays'
				BEGIN
					SELECT @NoOfDaysOP=(DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101))-ISNULL(@WEEKLYOFFCOUNT,0))+1 ,@FromDateOP=CONVERT(DATETIME,@FromDate),@ToDateOP=CONVERT(DATETIME,@ToDate),@AtATimeOP=@ATATIME,@MaxLeavesOP=@MAXLEAVES
				END
				ELSE IF ISNULL(@INCREXC,'')='IncludeBoth'
				BEGIN
					SELECT @NoOfDaysOP=(DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101))-ISNULL(@NOOFHOLIDAYS,0)-ISNULL(@WEEKLYOFFCOUNT,0))+1 ,@FromDateOP=CONVERT(DATETIME,@FromDate),@ToDateOP=CONVERT(DATETIME,@ToDate),@AtATimeOP=@ATATIME,@MaxLeavesOP=@MAXLEAVES
				END
				ELSE IF ISNULL(@INCREXC,'')='ExcludeBoth'
				BEGIN
					SELECT @NoOfDaysOP=(DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101)))+1,@FromDateOP=CONVERT(DATETIME,@FromDate),@ToDateOP=CONVERT(DATETIME,@ToDate),@AtATimeOP=@ATATIME,@MaxLeavesOP=@MAXLEAVES
				END
				--SELECT (DATEDIFF("d",convert(varchar,@FromDate,101),convert(varchar,@ToDate,101))-ISNULL(@NOOFHOLIDAYS,0)-ISNULL(@WEEKLYOFFCOUNT,0))+1 as NoOfDays 
			END	
			ELSE IF ISNULL(@Session,'')='Session1' OR ISNULL(@Session,'')='Session2'
			BEGIN
				SET @ToDate=@FromDate
				SELECT @NoOfDaysOP=0.5,@FromDateOP=CONVERT(DATETIME,@FromDate),@ToDateOP=CONVERT(DATETIME,@ToDate),@AtATimeOP=@ATATIME,@MaxLeavesOP=@MAXLEAVES
			END
		--END
		--ELSE
		--BEGIN
		
		--	SELECT @NoOfDaysOP=-1,@FromDateOP=CONVERT(DATETIME,@FromDate),@ToDateOP=CONVERT(DATETIME,@ToDate),@AtATimeOP=0,@MaxLeavesOP=0
		--END
END
GO
