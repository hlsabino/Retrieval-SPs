﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetAvlblNoofDaysOLD]
	@FromDate [varchar](20) = null,
	@ToDate [varchar](20) = null,
	@EmployeeID [int] = 0,
	@LeaveType [int] = 0,
	@Session [varchar](20) = 'Both',
	@userid [int] = 1,
	@langid [int] = 1
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
	DECLARE @CurrDaterangeLeavestaken DECIMAL(9,2)
	DECLARE @FDATE DATETIME
	DECLARE @TDATE DATETIME
	DECLARE @MonthNumber INT
	DECLARE @CurrMonthOpeningBalance DECIMAL(9,2)
	DECLARE @MONTH1 DATETIME
	DECLARE @MONTH2 DATETIME
	DECLARE @MONTH3 DATETIME
	DECLARE @MONTH4 DATETIME
	DECLARE @MONTH5 DATETIME
	DECLARE @MONTH6 DATETIME
	DECLARE @MONTH7 DATETIME
	DECLARE @MONTH8 DATETIME
	DECLARE @MONTH9 DATETIME
	DECLARE @MONTH10 DATETIME
	DECLARE @MONTH11 DATETIME
	DECLARE @MONTH12 DATETIME
	DECLARE @YEARCOUNT INT
	SELECT @YEARCOUNT=DATEDIFF(yyyy,@FromDate,@ToDate)
	SET @YEARCOUNT=@YEARCOUNT+2
	DECLARE @YC INT
	SET @YC=1
	--START:FOR START AND END MONTH	
	DECLARE @Year INT
	DECLARE @ALStartMonth INT
	DECLARE @ALStartMonthYear DATETIME
	DECLARE @ALEndMonthYear DATETIME
		
	--WHILE(@YC<=@YEARCOUNT)
	--BEGIN
		--SELECT @Year=YEAR(CONVERT(DATETIME,@FromDate)-1)+ @YC
		SELECT @Year=YEAR(CONVERT(DATETIME,@FromDate))
		PRINT @Year
		--set @year=2016
		--FOR READING START MONTH FROM GLOBAL PREFERENCES
		SELECT @ALStartMonth=ISNULL(VALUE,1) FROM ADM_GlobalPreferences WHERE (NAME='LeaveYear' OR RESOURCEID=94471)
		
		--SET FIRST DATE TO GIVEN MONTH IN GLOBAL PREFERENCES
		SET @ALStartMonthYear= CONVERT(VARCHAR,@Year)+'-' + DATENAME(MONTH,DATEADD(MONTH,@ALStartMonth,-1))+'-' +'01'
		SET @ALStartMonthYear=CONVERT(DATETIME,@ALStartMonthYear)
		PRINT @ALStartMonthYear
			
		--SET ENDMONTH FOR THE NEXT YEAR (1YEAR)
		SET @ALEndMonthYear=DATEADD(M,11,@ALStartMonthYear)
		
		--SET LAST DATE TO ENDMONTH FOR THE NEXT YEAR (1YEAR)
		SET @ALEndMonthYear=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALEndMonthYear)+1,0))
		SET @ALEndMonthYear=CONVERT(DATETIME,@ALEndMonthYear)
		PRINT @ALEndMonthYear
		
		
		if CONVERT(DATETIME,@FromDate)<CONVERT(DATETIME,@ALStartMonthYear)
		BEGIN
			SET @ALStartMonthYear=DATEADD(YEAR,-1,CONVERT(DATETIME,@ALStartMonthYear))
			SET @ALEndMonthYear=DATEADD(YEAR,-1,CONVERT(DATETIME,@ALEndMonthYear))
		END
		
		SET @MONTH1 =@ALStartMonthYear
		SET @MONTH2 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+2,0))
		SET @MONTH3 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+2,0)))
		SET @MONTH4 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+4,0))
		SET @MONTH5 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+4,0)))
		SET @MONTH6 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+6,0))
		SET @MONTH7 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+6,0)))
		SET @MONTH8 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+8,0))
		SET @MONTH9 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+8,0)))
		SET @MONTH10 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+10,0))
		SET @MONTH11 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+10,0)))
		SET @MONTH12 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+12,0))
		
		DECLARE @MONTHTAB TABLE(ID INT IDENTITY(1,1),STDATE DATETIME,EDDATE DATETIME)
		
		INSERT INTO @MONTHTAB VALUES(@MONTH1,@MONTH2)
		INSERT INTO @MONTHTAB VALUES(@MONTH3,@MONTH4)
		INSERT INTO @MONTHTAB VALUES(@MONTH5,@MONTH6)
		INSERT INTO @MONTHTAB VALUES(@MONTH7,@MONTH8)
		INSERT INTO @MONTHTAB VALUES(@MONTH9,@MONTH10)
		INSERT INTO @MONTHTAB VALUES(@MONTH11,@MONTH12)
	--SET @YC=@YC+1
	--END
	--SELECT * FROM @MONTHTAB
	--END:FOR START AND END MONTH	
	--FOR GRADE
	SELECT @GRADE=ISNULL(CCNID53,0) FROM COM_CCCCData WHERE CostCenterID=50051 AND NodeID=@EmployeeID
		
		
			IF(@FromDate is not null and @ToDate is not null and isnull(@Session,'Both')='Both')
			BEGIN			
					---FOR CURRENT YEAR LEAVES TAKEN
					SELECT @CurrYearLeavestaken=SUM(ISNULL(CONVERT(DECIMAL(9,2),TD.dcAlpha7),0))
				    FROM   INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
				    WHERE  ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND DC.INVDOCDETAILSID=TD.INVDOCDETAILSID AND 
						  --YEAR(CONVERT(DATETIME,ID.DOCDATE))=YEAR(CONVERT(DATETIME,@Date)) 
						  CONVERT(DATETIME,ID.DOCDATE) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
						  AND DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType AND DC.DCCCNID53=@Grade
						  and ID.STATUSID NOT IN (372,376)
				 ---FOR CURRENT YEAR LEAVES TAKEN
				--INCLUDE OR EXCLUDE HOLIDAYS, ATATIME,MAXLEAVES AND WEEKLYOFFS
						SELECT @INCREXC=ISNULL(INCLUDEREXCLUDE,''),@ATATIME=ISNULL(ATATIME,0),@MAXLEAVES=ISNULL(MAXLEAVES,0) FROM COM_CC50054 
						WHERE  GRADEID=@GRADE AND COMPONENTID=@LeaveType AND MONTH(CONVERT(DATETIME,PAYROLLDATE))=MONTH(CONVERT(DATETIME,@FromDate))	
				--START :CURRENT DATERANGE LEAVES TAKEN
						--START: LOADING DATERANGE	   
				   	    DECLARE @DATESCOUNT TABLE (SNO INT IDENTITY(1,1),ID INT ,DATE1 DATETIME,DAYNAME VARCHAR(50),WEEKNO INT,COUNT INT)
				   	    DECLARE @STARTDATE1 DATETIME
				   	    DECLARE @ENDATE1 DATETIME
				   	    DECLARE @MRC AS INT
				   	    DECLARE @MC AS INT
				   	    DECLARE @MID INT
				   	    SET @MC=1
				   	    SELECT @MRC=COUNT(*) FROM @MONTHTAB
				   	    WHILE (@MC<=@MRC)
				   	    BEGIN
				   			SELECT @STARTDATE1=CONVERT(DATETIME,STDATE),@ENDATE1=CONVERT(DATETIME,EDDATE) FROM @MONTHTAB WHERE ID=@MC
				   			;WITH DATERANGE AS
							(
							SELECT @STARTDATE1 AS DT,1 AS ID
							UNION ALL
							SELECT DATEADD(DD,1,DT),DATERANGE.ID+1 FROM DATERANGE WHERE ID<=DATEDIFF("d",convert(varchar,@STARTDATE1,101),convert(varchar,@ENDATE1,101))
							)
							
							INSERT INTO @DATESCOUNT
							SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0 FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
				   	    SET @MC=@MC+1
				   	    END
				   	    --END: LOADING DATERANGE
							--START: LOADING DATEAPPLIEDRANGE 
							   DECLARE @DATESAPPLIEDCOUNT TABLE (FDATE DATETIME,TDATE DATETIME,STODATE DATETIME,EODATE DATETIME)
							   INSERT INTO @DATESAPPLIEDCOUNT
							   SELECT CONVERT(DATETIME,dcAlpha4),CONVERT(DATETIME,dcAlpha5),CONVERT(DATETIME,@FromDate),CONVERT(DATETIME,@ToDate) FROM COM_DocTextData TD,INV_DOCDETAILS ID, COM_DocCCData DC 
							   WHERE  TD.InvDocDetailsID=DC.InvDocDetailsID AND	ID.InvDocDetailsID=TD.InvDocDetailsID AND ID.CostCenterID=40062 AND
						       DC.DCCCNID51=@EmployeeID AND DC.DCCCNID53=@Grade AND  DC.dcCCNID52=@LeaveType AND
				               ID.STATUSID NOT IN (372,376)-- 
				      --         AND
							   --(CONVERT(DATETIME,dcAlpha4) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)
  							 --  or CONVERT(DATETIME,dcAlpha5) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)
							   --or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5)
							   --or CONVERT(DATETIME,@ToDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5))
						   --END: LOADING DATEAPPLIEDRANGE 				 
							  
						   --START: UPDATING DATES APPLIED FROM LIST OF DATERANGE 
							  DECLARE @RC AS INT
							  DECLARE @IC AS INT
							  DECLARE @TRC AS INT
							  DECLARE @DTT AS DATETIME
							  SET @IC=1
							  SELECT @TRC=COUNT(*) FROM @DATESCOUNT
							  WHILE(@IC<=@TRC)
							  BEGIN
									SELECT @DTT=DATE1 FROM @DATESCOUNT WHERE SNO=@IC
									SELECT @RC=COUNT(*) FROM @DATESAPPLIEDCOUNT WHERE 
															CONVERT(DATETIME,@DTT) between CONVERT(DATETIME,FDATE) and CONVERT(DATETIME,TDATE)
  							        UPDATE @DATESCOUNT SET count=ISNULL(@RC,0) WHERE CONVERT(DATETIME,DATE1)=CONVERT(DATETIME,@DTT)
							  SET @IC=@IC+1
							  END
						--END: UPDATING DATES APPLIED FROM LIST OF DATERANGE 
				--END :CURRENT DATERANGE LEAVES TAKEN		   
							   
			     --CALCULATE MAXNOOFDAYS
						IF ISNULL(@MAXLEAVES,0)>0
						BEGIN
							SET @MAXLEAVES=ISNULL(@MAXLEAVES,0)-ISNULL(@CurrYearLeavestaken,0)
						END
				--START HOLIDAYS COUNT
						SELECT @NOOFHOLIDAYS=COUNT(dcAlpha1) FROM COM_DocTextData TD,INV_DOCDETAILS ID 
						WHERE ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
						AND CONVERT(DATETIME,@FromDate) <= CONVERT(DATETIME,TD.dcAlpha1)
						AND CONVERT(DATETIME,@ToDate) >= CONVERT(DATETIME,TD.dcAlpha1)
						AND ID.COSTCENTERID=40051
				--END HOLIDAYS COUNT
				
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
						
						DECLARE @STARTDATE2 DATETIME
				   	    DECLARE @ENDATE2 DATETIME
				   	    DECLARE @MRC2 AS INT
				   	    DECLARE @MC2 AS INT
				   	    DECLARE @MID2 INT
				   	    SET @MC2=1
				   	    SELECT @MRC2=COUNT(*) FROM @MONTHTAB
				   	    WHILE (@MC2<=@MRC2)
				   	    BEGIN
				   			SELECT @STARTDATE2=CONVERT(DATETIME,STDATE),@ENDATE2=CONVERT(DATETIME,EDDATE) FROM @MONTHTAB WHERE ID=@MC2
				   			;WITH DATERANGE AS
							(
							SELECT @STARTDATE2 AS DT,1 AS ID
							UNION ALL
							SELECT DATEADD(DD,1,DT),DATERANGE.ID+1 FROM DATERANGE WHERE ID<=DATEDIFF("d",convert(varchar,@STARTDATE2,101),convert(varchar,@ENDATE2,101))
							)
							
							INSERT INTO @WEEKOFFCOUNT
							SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0 FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
				   	    SET @MC2=@MC2+1
				   	    END
							
							--UPDATING WEEKNO IN WEEKOFFCOUNT TABLE BASED ON WEEKDATE OF MONTH
							UPDATE @WEEKOFFCOUNT SET WEEKNO=((datepart(day,WEEKDATE)-1)/7)+1
							
							--UPDATING COUNT TO 1 IF WEEKNO AND DAYNAME IS WEEKLYOFF
							UPDATE WEEKOFFCOUNT SET WEEKOFFCOUNT.count=1
							FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join @WEEKLYOFF WEEKLYOFF on WEEKLYOFF.WEEKLYWEEKOFFNO=WEEKOFFCOUNT.WEEKNO 
								 AND upper(WEEKLYOFF.DAYNAME)=upper(WEEKOFFCOUNT.DAYNAME)
							 
						--COUNTING WEEKLYOFFS IN GIVEN DATERANGE
						SELECT @WEEKLYOFFCOUNT=COUNT(*) FROM @WEEKOFFCOUNT WHERE COUNT=1 and convert(DATETIME,WEEKDATE) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)

				--END WEEKLYOFF COUNT
				--START : DATEAPPLIEDRANGE COUNT UPDATE
				--UPDATING COUNT TO 3 IF DATEAPPLIEDRANGE DATE IS WEEKLYOFF
				--SELECT * FROM @WEEKOFFCOUNT
							UPDATE DATESCOUNT SET DATESCOUNT.count=3
							FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join @DATESCOUNT DATESCOUNT on --DATESCOUNT.SNO=WEEKOFFCOUNT.id and  
							 CONVERT(DATETIME,DATESCOUNT.date1)= CONVERT(DATETIME,WEEKOFFCOUNT.weekdate) and WEEKOFFCOUNT.count=1
				--UPDATING COUNT TO 4 IF DATEAPPLIEDRANGE DATE IS Holiday
							 UPDATE DATESCOUNT SET DATESCOUNT.count=4
							 FROM @DATESCOUNT DATESCOUNT inner join COM_DocTextData TD on CONVERT(DATETIME,DATESCOUNT.DATE1)=CONVERT(DATETIME,TD.dcAlpha1)
							 inner join INV_DOCDETAILS ID  on  ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
							 AND   CONVERT(DATETIME,DATE1) = CONVERT(DATETIME,TD.dcAlpha1) AND ID.COSTCENTERID=40051
							 
						
					   --SELECT * FROM @DATESCOUNT
					DECLARE @PREVMONTH INT
					DECLARE @NEXTMONTH INT
					
						SELECT @CurrDaterangeLeavestaken=COUNT(*) FROM @DATESCOUNT WHERE COUNT=1 and month(convert(datetime,date1))=month(CONVERT(DATETIME,@FromDate))--convert(DATETIME,date1) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)
					PRINT 'CYLT'
					PRINT @CurrYearLeavestaken
					print 'cm'
					print @CurrDaterangeLeavestaken
					SELECT @PREVMONTH=COUNT(*) FROM @DATESCOUNT WHERE COUNT=1 and month(convert(DATETIME,date1)) < month(CONVERT(DATETIME,@FromDate))
					SELECT @NEXTMONTH=COUNT(*) FROM @DATESCOUNT WHERE COUNT=1 and month(convert(DATETIME,date1)) >month(CONVERT(DATETIME,@FromDate) )
					print 'pm'
					print @PREVMONTH
					print 'nm'
					print @NEXTMONTH
					if month(CONVERT(DATETIME,@FromDate))=month(CONVERT(DATETIME,@ToDate))
					begin
					
							IF ISNULL(@NEXTMONTH,0)=0 AND ISNULL(@PREVMONTH,0)=0
							BEGIN
								SET @CurrMonthOpeningBalance=@CurrDaterangeLeavestaken
							END
							ELSE IF ISNULL(@NEXTMONTH,0)=0 AND ISNULL(@PREVMONTH,0)>0
							BEGIN
								SET @CurrMonthOpeningBalance=@CurrYearLeavestaken-@CurrDaterangeLeavestaken
							END
							ELSE IF ISNULL(@NEXTMONTH,0)>0 AND ISNULL(@PREVMONTH,0)=0
							BEGIN
								SET @CurrMonthOpeningBalance=@CurrYearLeavestaken+ISNULL(@PREVMONTH,0)-(@CurrDaterangeLeavestaken+ISNULL(@NEXTMONTH,0))
							END
					end
					else
					begin
					
						IF ISNULL(@NEXTMONTH,0)=0 AND ISNULL(@PREVMONTH,0)=0
							BEGIN
								SET @CurrMonthOpeningBalance=@CurrDaterangeLeavestaken
							END
							ELSE IF ISNULL(@NEXTMONTH,0)=0 AND ISNULL(@PREVMONTH,0)>0
							BEGIN
								SET @CurrMonthOpeningBalance=@CurrYearLeavestaken-@CurrDaterangeLeavestaken
							END
							ELSE IF ISNULL(@NEXTMONTH,0)>0 AND ISNULL(@PREVMONTH,0)=0
							BEGIN
								set @CurrDaterangeLeavestaken=@CurrDaterangeLeavestaken+ISNULL(@NEXTMONTH,0)
								SET @CurrMonthOpeningBalance=@CurrYearLeavestaken+ISNULL(@PREVMONTH,0)-(@CurrDaterangeLeavestaken)
							END
					end
					print @CurrMonthOpeningBalance
				--END : DATEAPPLIEDRANGE COUNT UPDATE
				
				--START : CHECKING AVAILABLE DAYS 
				DECLARE @AssignedLeavesOP INT
				DECLARE	@AvlblLeavesOP DECIMAL(9,2) 
				DECLARE	@FromDateOP DATETIME
				DECLARE	@ToDateOP DATETIME
				Exec spPAY_ExtGetAssignedLeavesOP  @EmployeeID,@LeaveType,@FromDate,@UserId,@LangId,@AssignedLeavesOP output,@AvlblLeavesOP output,@FromDateOP output,@ToDateOP output
				--END: CHECKING AVAILABLE DAYS 
				print 'tes'
				print @AvlblLeavesOP
				SET @AvlblLeavesOP=@AvlblLeavesOP-isnull(@CurrMonthOpeningBalance,0)
				IF ISNULL(@INCREXC,'')='IncludeHolidays' OR ISNULL(@INCREXC,'')='ExcludeWeeklyOffs'
				BEGIN
					SELECT CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@AvlblLeavesOP AvailableLeaves,convert(varchar,@CurrDaterangeLeavestaken) as LeavesTaken,@NOOFHOLIDAYS Holidays,@WEEKLYOFFCOUNT Weeklyoff
				END
				ELSE IF ISNULL(@INCREXC,'')='IncludeWeeklyOffs' OR ISNULL(@INCREXC,'')='ExcludeHolidays'
				BEGIN
					SELECT CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@AvlblLeavesOP AvailableLeaves,convert(varchar,@CurrDaterangeLeavestaken) as LeavesTaken,@NOOFHOLIDAYS Holidays,@WEEKLYOFFCOUNT Weeklyoff
				END
				ELSE IF ISNULL(@INCREXC,'')='IncludeBoth'
				BEGIN
					SELECT CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@AvlblLeavesOP AvailableLeaves,convert(varchar,@CurrDaterangeLeavestaken) as LeavesTaken,@NOOFHOLIDAYS Holidays,@WEEKLYOFFCOUNT Weeklyoff
				END
				ELSE IF ISNULL(@INCREXC,'')='ExcludeBoth'
				BEGIN
					SELECT CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@AvlblLeavesOP AvailableLeaves,convert(varchar,@CurrDaterangeLeavestaken) as LeavesTaken,@NOOFHOLIDAYS Holidays,@WEEKLYOFFCOUNT Weeklyoff
				END
				
			END	
			ELSE IF ISNULL(@Session,'')='Session1' OR ISNULL(@Session,'')='Session2'
			BEGIN
				SET @ToDate=@FromDate
				SELECT CONVERT(DATETIME,@FromDate) as FromDate,CONVERT(DATETIME,@ToDate) as ToDate,@AvlblLeavesOP AvailableLeaves,convert(varchar,@CurrDaterangeLeavestaken) as LeavesTaken,@NOOFHOLIDAYS Holidays,@WEEKLYOFFCOUNT Weeklyoff
			END
END
GO