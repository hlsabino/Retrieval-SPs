﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetCurrYearLeavesInfo10]
	@FromDate [varchar](20) = null,
	@ToDate [varchar](20) = null,
	@EmployeeID [int] = 0,
	@LeaveType [int] = 0,
	@userid [int] = 1,
	@langid [int] = 1,
	@LVStartDate [datetime],
	@EncahsedLeavesMode [int] = 0,
	@CurrYearLeavesTakenOP [decimal](9, 2) OUTPUT,
	@NoOfHolidayOP [int] OUTPUT,
	@NoOfWkOffsOP [int] OUTPUT,
	@EncahsedLeavesOP [decimal](9, 2) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @NOOFHOLIDAYS INT,@WEEKLYOFFCOUNT INT,@INCREXC VARCHAR(50),@ATATIME INT,@MAXLEAVES INT,@CurrYearLeavestaken DECIMAL(9,2),@ExstAppliedEncashdays DECIMAL(9,2)
	DECLARE @FDATE DATETIME,@TDATE DATETIME
	DECLARE @MONTH1 DATETIME,@MONTH2 DATETIME,@MONTH3 DATETIME,@MONTH4 DATETIME,@MONTH5 DATETIME,@MONTH6 DATETIME
	DECLARE @MONTH7 DATETIME,@MONTH8 DATETIME,@MONTH9 DATETIME,@MONTH10 DATETIME,@MONTH11 DATETIME,@MONTH12 DATETIME
	DECLARE @YEARDIFF INT,@YC INT
	DECLARE @Year INT,@ALStartMonth INT
	DECLARE @ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME
	DECLARE @MONTHTAB TABLE(ID INT IDENTITY(1,1),STDATE DATETIME,EDDATE DATETIME)
	DECLARE @LocID INT,@PayrollDate DATETIME
	
	--SET TO FIRST DAY FOR THE GIVEN DATE
	SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@FromDate)),0)
	IF((SELECT COUNT(*) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID2' and IsColumnInUse=1 and UserProbableValues='H')>0)
		SELECT @LocID=HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmployeeID AND CostCenterID=50051 AND HistoryCCID=50002 AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,@PayrollDate)) AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,@PayrollDate) OR ToDate IS NULL)
	ELSE
		SELECT @LocID=ISNULL(CC.CCNID2,1) FROM COM_CC50051 C51 WITH(NOLOCK),COM_CCCCDATA CC  WITH(NOLOCK) WHERE C51.NODEID=CC.NODEID AND C51.NODEID=@EmployeeID
	
	SELECT @YEARDIFF=DATEDIFF(yyyy,@FromDate,@ToDate)
	SET @YC=0
	
	--START:FOR START DATE AND END DATE OF LEAVE YEAR
	EXEC [spPAY_EXTGetLeaveyearDates] @FromDate,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
		
		IF ISNULL(@YEARDIFF,0)>2
		BEGIN
			SET @FDATE=@FromDate
			--START : LOADING MONTHS BASED ON GIVEN YEAR RANGE FROM FROMDATE AND TODATE
			WHILE(@YC<=@YEARDIFF)
			BEGIN
				SET @MONTH1 =@FDATE
				SET @MONTH2 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+2,0))
				SET @MONTH3 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+2,0)))
				SET @MONTH4 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+4,0))
				SET @MONTH5 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+4,0)))
				SET @MONTH6 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+6,0))
				SET @MONTH7 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+6,0)))
				SET @MONTH8 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+8,0))
				SET @MONTH9 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+8,0)))
				SET @MONTH10 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+10,0))
				SET @MONTH11 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+10,0)))
				SET @MONTH12 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FDATE)+12,0))
				
				INSERT INTO @MONTHTAB VALUES(@MONTH1,@MONTH2)
				INSERT INTO @MONTHTAB VALUES(@MONTH3,@MONTH4)
				INSERT INTO @MONTHTAB VALUES(@MONTH5,@MONTH6)
				INSERT INTO @MONTHTAB VALUES(@MONTH7,@MONTH8)
				INSERT INTO @MONTHTAB VALUES(@MONTH9,@MONTH10)
				INSERT INTO @MONTHTAB VALUES(@MONTH11,@MONTH12)
				SET @FDATE=DATEADD(YY,1,@FDATE)
			SET @YC=@YC+1
			END
			--END : LOADING MONTHS BASED ON GIVEN YEAR RANGE FROM FROMDATE AND TODATE
		END
		ELSE
		BEGIN
				--START : LOADING MONTHS BASED ON GIVEN DATE RANGE FROM FROMDATE AND TODATE
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
				
				INSERT INTO @MONTHTAB VALUES(@MONTH1,@MONTH2)
				INSERT INTO @MONTHTAB VALUES(@MONTH3,@MONTH4)
				INSERT INTO @MONTHTAB VALUES(@MONTH5,@MONTH6)
				INSERT INTO @MONTHTAB VALUES(@MONTH7,@MONTH8)
				INSERT INTO @MONTHTAB VALUES(@MONTH9,@MONTH10)
				INSERT INTO @MONTHTAB VALUES(@MONTH11,@MONTH12)
				--END : LOADING MONTHS BASED ON GIVEN DATE RANGE FROM FROMDATE AND TODATE
		END
		
			IF(@FromDate is not null and @ToDate is not null )
			BEGIN			
				--FOR ENCASHED LEAVES
				IF ISNULL(@EncahsedLeavesMode,0)=0
				BEGIN
					SELECT @ExstAppliedEncashdays=sum(CONVERT(decimal(9,2),TD.DCALPHA3))
					FROM   INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
						   JOIN COM_DocNumData DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
					WHERE  ISNUMERIC(TD.DCALPHA3)=1 AND MONTH(CONVERT(DATETIME,ID.DOCDATE)) <=MONTH(CONVERT(DATETIME,@LVStartDate))
						   AND CONVERT(DATETIME,ID.DOCDATE) BETWEEN CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
					       AND ID.COSTCENTERID=40058 AND ID.STATUSID NOT IN (372,376) AND DC.DCCCNID51=@EmployeeID  AND DC.DCCCNID52=@LeaveType
				END
				ELSE IF ISNULL(@EncahsedLeavesMode,0)=1--FOR MONTHLY PAYROLL PROCEDURE
				BEGIN
					SELECT @ExstAppliedEncashdays=sum(CONVERT(decimal(9,2),TD.DCALPHA3))
					FROM   INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
 						   JOIN COM_DocNumData DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
					WHERE  ISNUMERIC(TD.DCALPHA3)=1	AND MONTH(CONVERT(DATETIME,ID.DOCDATE)) =MONTH(CONVERT(DATETIME,@LVStartDate))
					       AND CONVERT(DATETIME,ID.DOCDATE) BETWEEN CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
					       AND ID.COSTCENTERID=40058 AND ID.STATUSID NOT IN (372,376) AND DC.DCCCNID51=@EmployeeID  AND DC.DCCCNID52=@LeaveType
				END
				--START :CURRENT DATERANGE LEAVES TAKEN
					--START: LOADING DATES FROM @MONTHTAB TABLE	   
				   	DECLARE @DATESCOUNT TABLE (SNO INT IDENTITY(1,1),ID INT ,DATE1 DATETIME,DAYNAME VARCHAR(50),WEEKNO INT,COUNT INT,NOOFDAYS DECIMAL(9,2))
				   	DECLARE @STARTDATE1 DATETIME,@ENDATE1 DATETIME
				   	DECLARE @MRC AS INT,@MC AS INT,@MID INT
				   	
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
						SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0,0 FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
				   	SET @MC=@MC+1
				   	END
				    --END: LOADING DATES FROM @MONTHTAB TABLE
						--START: LOADING DATA BASED ON FROMDATE AND TODATE GIVEN 
						  DECLARE @DATESAPPLIEDCOUNT TABLE (FDATE DATETIME,TDATE DATETIME,STODATE DATETIME,EODATE DATETIME,NOOFDAYS DECIMAL(9,2))
						  INSERT INTO @DATESAPPLIEDCOUNT
							   SELECT CONVERT(DATETIME,dcAlpha4),CONVERT(DATETIME,dcAlpha5),CONVERT(DATETIME,@FromDate),CONVERT(DATETIME,@ToDate),ISNULL(dcAlpha7,0) 
							   FROM   INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
							   WHERE  ID.CostCenterID=40062 AND DC.DCCCNID51=@EmployeeID  AND  DC.dcCCNID52=@LeaveType AND ID.STATUSID NOT IN (372,376)
					   --END: LOADING DATA BASED ON FROMDATE AND TODATE GIVEN				 
						  
					   --START: UPDATING @DATESCOUNT TABLE 'COUNT' COLUMN TO 1 FROM LIST OF @DATESAPPLIEDCOUNT TABLE
						  DECLARE @RC AS INT,@IC AS INT,@TRC AS INT,@DTT AS DATETIME,@DAYS decimal(9,2)
						  SET @IC=1
						  SELECT @TRC=COUNT(*) FROM @DATESCOUNT
						  WHILE(@IC<=@TRC)
						  BEGIN
								SELECT @DTT=DATE1 FROM @DATESCOUNT WHERE SNO=@IC
								
								SELECT @RC=COUNT(*) FROM @DATESAPPLIEDCOUNT WHERE CONVERT(DATETIME,@DTT) between CONVERT(DATETIME,FDATE) and CONVERT(DATETIME,TDATE)
  						        UPDATE @DATESCOUNT SET count=ISNULL(@RC,0) WHERE CONVERT(DATETIME,DATE1)=CONVERT(DATETIME,@DTT)
						  SET @IC=@IC+1
						  END
						  UPDATE DT SET  DT.NOOFDAYS=ISNULL(DAC.NOOFDAYS,0) FROM @DATESCOUNT DT INNER JOIN @DATESAPPLIEDCOUNT DAC ON DT.DATE1=DAC.FDATE AND ISNULL(DAC.NOOFDAYS,0)=0.5
					--END: UPDATING @DATESCOUNT TABLE 'COUNT' COLUMN TO 1 FROM LIST OF @DATESAPPLIEDCOUNT TABLE
				--END :CURRENT DATERANGE LEAVES TAKEN		   
				
				--START HOLIDAYS COUNT
					SET @NOOFHOLIDAYS=0
					IF EXISTS(SELECT SYSCOLUMNNAME FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID=40051 AND ISCOLUMNINUSE=1 AND SYSCOLUMNNAME ='DCCCNID2')
					BEGIN
						SELECT @NOOFHOLIDAYS=COUNT(dcAlpha1) FROM INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID INNER JOIN COM_DocCCData CC WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
						WHERE  ID.COSTCENTERID=40051 and ISDATE(TD.dcAlpha1)=1 AND CC.DCCCNID2=@LocID AND ID.STATUSID=369 AND CONVERT(DATETIME,dcAlpha1) between CONVERT(DATETIME,@FromDate) AND CONVERT(DATETIME,@ToDate)
					END
					ELSE
					BEGIN
						SELECT @NOOFHOLIDAYS=COUNT(dcAlpha1) FROM COM_DocTextData TD,INV_DOCDETAILS ID WHERE ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND ID.COSTCENTERID=40051 AND ID.STATUSID=369 and ISDATE(TD.dcAlpha1)=1
						       AND CONVERT(DATETIME,dcAlpha1) between CONVERT(DATETIME,@FromDate) AND CONVERT(DATETIME,@ToDate)
					END
				--END HOLIDAYS COUNT
				--START WEEKLYOFF COUNT
					--LOADING WEEKLYOFF INFORMATION OF EMPLOYEE
					DECLARE @STRQUERY NVARCHAR(MAX),@I INT,@J INT,@COLNAME VARCHAR(15)
					CREATE TABLE #EMPWEEKLYOFF(WK11 varchar(50),WK12 varchar(50),WK21 varchar(50),WK22 varchar(50), WK31 varchar(50),
											   WK32 varchar(50),WK41 varchar(50),WK42 varchar(50),WK51 varchar(50),WK52 varchar(50))
					CREATE TABLE #WEEKLYOFF(WEEKLYWEEKOFFNO int,DAYNAME varchar(100),WeekNo INT,WkDate DATETIME)										   
					SET @STRQUERY=''	   
											   
					--LOADING DATA FROM WEEKLYOFF MASTER											   
					INSERT INTO #EMPWEEKLYOFF 
					SELECT TOP 1 TD.dcAlpha2 WK11,TD.dcAlpha3 WK12,TD.dcAlpha4 WK21,TD.dcAlpha5 WK22,TD.dcAlpha6 WK31,TD.dcAlpha7 WK32,TD.dcAlpha8 WK41,TD.dcAlpha9 WK42,
						         TD.dcAlpha10 WK51,TD.dcAlpha11 WK52	FROM COM_DocCCData DC WITH(NOLOCK),INV_DOCDETAILS ID WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
					WHERE        DC.INVDOCDETAILSID=ID.INVDOCDETAILSID AND TD.INVDOCDETAILSID=ID.INVDOCDETAILSID AND ID.COSTCENTERID=40053 AND DC.dcCCNID51=@EmployeeID	AND
					             --CONVERT(DATETIME,ID.DUEDATE)<=CONVERT(DATETIME,@FromDate)
					             CONVERT(DATETIME,ID.DUEDATE)>=CONVERT(DATETIME,@ALStartMonthYear)											
					ORDER BY     CONVERT(DATETIME,ID.DUEDATE) DESC
					
					--SET EMPTY COLUMNS
					SET @I=1
					SET @STRQUERY=''
					WHILE(@I<=5)
					BEGIN
						SET @J=1
						WHILE(@J<=2)
						BEGIN
							SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
							SET @STRQUERY=@STRQUERY+' UPDATE #EMPWEEKLYOFF SET '+ @COLNAME +'='''' where '+ @COLNAME +'=''None'''
							
						SET @J=@J+1
						END
					SET @I=@I+1
					END
					--PRINT @STRQUERY
					EXEC sp_executesql @STRQUERY
					--CHECKING FOR EMPLOYEE WEEKLY OFF COUNT FROM WEEKLYOFF MASTER IF NO DATA FOUND
					--LOADING DATA FROM EMPLOYEE MASTER
					IF (SELECT COUNT(*) FROM #EMPWEEKLYOFF)<=0
					BEGIN
						INSERT INTO #EMPWEEKLYOFF 
						SELECT WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,WeeklyOff1,WeeklyOff2,
						       WeeklyOff1,WeeklyOff2	FROM COM_CC50051 WITH(NOLOCK)
						WHERE  NODEID=@EmployeeID
						DELETE FROM #EMPWEEKLYOFF WHERE ISNULL(WK11,'None')='None' OR ISNULL(WK11,'0')='0'
						--EMPLOYEE MASTER
						SET @I=1
						SET @STRQUERY=''
						WHILE(@I<=5)
						BEGIN
							SET @J=1
							WHILE(@J<=2)
							BEGIN
								SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
								SET @STRQUERY=@STRQUERY+' UPDATE #EMPWEEKLYOFF SET '+ @COLNAME +'='''' where '+ @COLNAME +'=''None'''
								
							SET @J=@J+1
							END
						SET @I=@I+1
						END
						--PRINT @STRQUERY
						EXEC sp_executesql @STRQUERY
						--GLOBAL PREFERENCE
						SET @I=1
						SET @STRQUERY=''
						WHILE(@I<=5)
						BEGIN
							SET @J=1
							WHILE(@J<=2)
							BEGIN
								SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
								SET @STRQUERY=@STRQUERY+' UPDATE #EMPWEEKLYOFF SET '+ @COLNAME +'=isnull(VALUE,'''') FROM ADM_GlobalPreferences WITH(NOLOCK)	WHERE  NAME=''WeeklyOff'+CONVERT(VARCHAR,@J)+''' AND ISNULL('+ @COLNAME +','''')=''''  AND ISNULL(VALUE,''None'')<>''None'''
							SET @J=@J+1
							END
						SET @I=@I+1
						END
						--PRINT @STRQUERY
						EXEC sp_executesql @STRQUERY
					END
					ELSE
					BEGIN
						--EMPLOYEE MASTER
						SET @I=1
						SET @STRQUERY=''
						WHILE(@I<=5)
						BEGIN
							SET @J=1
							WHILE(@J<=2)
							BEGIN
								SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
								SET @STRQUERY=@STRQUERY+' UPDATE #EMPWEEKLYOFF SET '+ @COLNAME +'=WeeklyOff'+CONVERT(VARCHAR,@J)+' FROM COM_CC50051 WITH(NOLOCK)	WHERE  NODEID='+CONVERT(VARCHAR,@EmployeeID) +' AND ISNULL('+ @COLNAME +','''')=''''  AND ISNULL(WeeklyOff'+CONVERT(VARCHAR,@J)+',''None'')<>''None'''
							SET @J=@J+1
							END
						SET @I=@I+1
						END
						--PRINT @STRQUERY
						EXEC sp_executesql @STRQUERY
						--GLOBAL PREFRENCE
						SET @I=1
						SET @STRQUERY=''
						WHILE(@I<=5)
						BEGIN
							SET @J=1
							WHILE(@J<=2)
							BEGIN
								SET @COLNAME='WK'+CONVERT(VARCHAR,@I)+CONVERT(VARCHAR,@J)
								SET @STRQUERY=@STRQUERY+' UPDATE #EMPWEEKLYOFF SET '+ @COLNAME +'=isnull(VALUE,'''') FROM ADM_GlobalPreferences WITH(NOLOCK)	WHERE  NAME=''WeeklyOff'+CONVERT(VARCHAR,@J)+''' AND ISNULL('+ @COLNAME +','''')=''''  AND ISNULL(VALUE,''None'')<>''None'''
							SET @J=@J+1
							END
						SET @I=@I+1
						END
						--PRINT @STRQUERY
						EXEC sp_executesql @STRQUERY
					END
					--CHECKING FOR EMPLOYEE WEEKLY OFF COUNT FROM EMPLOYEE MASTER IF NO DATA FOUND
					--LOADING DATA FROM PREFERENCES
					IF (SELECT COUNT(*) FROM #EMPWEEKLYOFF)<=0
					BEGIN
						INSERT INTO #WEEKLYOFF 
						SELECT case isnull(VALUE,'') when '' then 0 else 1 end,VALUE, 0, null FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 1 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 2 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 2 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'					  
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 3 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 3 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'					  
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 4 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 4 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'					  
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 5 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff1'
						UNION ALL
						SELECT case isnull(VALUE,'') when '' then 0 else 5 end,VALUE, 0, null	FROM ADM_GlobalPreferences  WHERE NAME='WeeklyOff2'		
					END
									
					--LOADING WEEKNO AND DAYNAME INTO ROWS FROM #EMPWEEKLYOFF TABLE (WEEKLYOFF AND EMPLOYEE MASTER)
					IF (SELECT COUNT(*) FROM #WEEKLYOFF)<=0
					BEGIN
						INSERT INTO #WEEKLYOFF
							select case isnull(WK11,'') when '' then 0 else 1 end,case isnull(WK11,'') when '' then '' else WK11 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK12,'') when '' then 0 else 1 end,case isnull(WK12,'') when '' then '' else WK12 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK21,'') when '' then 0 else 2 end,case isnull(WK21,'') when '' then '' else WK21 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK22,'') when '' then 0 else 2 end,case isnull(WK22,'') when '' then '' else WK22 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK31,'') when '' then 0 else 3 end,case isnull(WK31,'') when '' then '' else WK31 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK32,'') when '' then 0 else 3 end,case isnull(WK32,'') when '' then '' else WK32 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK41,'') when '' then 0 else 4 end,case isnull(WK41,'') when '' then '' else WK41 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK42,'') when '' then 0 else 4 end,case isnull(WK42,'') when '' then '' else WK42 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK51,'') when '' then 0 else 5 end,case isnull(WK51,'') when '' then '' else WK51 end, 0, null FROM #EMPWEEKLYOFF
						UNION ALL
							select case isnull(WK52,'') when '' then 0 else 5 end,case isnull(WK52,'') when '' then '' else WK52 end, 0, null FROM #EMPWEEKLYOFF
					END
					--LOADING WEEKDATE,DAYNAME AND WEEKNO FOR SELECTED DATERANGE
					--select * from #WEEKLYOFF
					DECLARE @WEEKOFFCOUNT TABLE (ID INT ,WEEKDATE DATETIME,DAYNAME VARCHAR(50),WEEKNO INT,COUNT INT,WEEKNOMANUAL INT)
					DECLARE @STARTDATE DATETIME,@STARTDATE2 DATETIME,@ENDATE2 DATETIME
				   	DECLARE @MRC2 AS INT,@MC2 AS INT,@MID2 INT
				   	
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
						SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0,0 FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
				   	SET @MC2=@MC2+1
				   	END
						
						--UPDATING WEEKNO IN WEEKOFFCOUNT TABLE BASED ON WEEKDATE OF MONTH
						UPDATE @WEEKOFFCOUNT SET WEEKNO=((datepart(day,WEEKDATE)-1)/7)+1
						
						--UPDATING COUNT TO 1 IF WEEKNO AND DAYNAME IS WEEKLYOFF
						UPDATE WEEKOFFCOUNT SET WEEKOFFCOUNT.count=1 FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join #WEEKLYOFF WEEKLYOFF on WEEKLYOFF.WEEKLYWEEKOFFNO=WEEKOFFCOUNT.WEEKNO AND upper(WEEKLYOFF.DAYNAME)=upper(WEEKOFFCOUNT.DAYNAME)
						 
					--COUNTING WEEKLYOFFS IN GIVEN DATERANGE
					SELECT @WEEKLYOFFCOUNT=COUNT(*) FROM @WEEKOFFCOUNT WHERE COUNT=1 and convert(DATETIME,WEEKDATE) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)
				--END WEEKLYOFF COUNT

				--START : UPDATING @DATESAPPLIEDCOUNT TABLE 'COUNT' COLUMN TO '3- FOR WEEKLYOFF' AND '4- FOR HOLIDAY'
				--UPDATING COUNT TO 3 IF DATEAPPLIEDRANGE DATE IS WEEKLYOFF
				UPDATE DATESCOUNT SET DATESCOUNT.count=3 FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join @DATESCOUNT DATESCOUNT on CONVERT(DATETIME,DATESCOUNT.date1)= CONVERT(DATETIME,WEEKOFFCOUNT.weekdate) and WEEKOFFCOUNT.count=1
				
				IF EXISTS(SELECT SYSCOLUMNNAME FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID=40051 AND ISCOLUMNINUSE=1 AND SYSCOLUMNNAME ='DCCCNID2')
				BEGIN
					UPDATE DATESCOUNT SET DATESCOUNT.count=4 FROM @DATESCOUNT DATESCOUNT inner join COM_DocTextData TD on CONVERT(DATETIME,DATESCOUNT.DATE1)=CONVERT(DATETIME,TD.dcAlpha1)
					inner join INV_DOCDETAILS ID  on  ID.INVDOCDETAILSID=TD.INVDOCDETAILSID inner join COM_DocCCData CC  on  ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
					and ISDATE(TD.dcAlpha1)=1 AND CC.DCCCNID2=@LocID AND ID.STATUSID=369 AND CONVERT(DATETIME,DATE1) = CONVERT(DATETIME,TD.dcAlpha1) AND ID.COSTCENTERID=40051
				END
				ELSE
				BEGIN
					 UPDATE DATESCOUNT SET DATESCOUNT.count=4 FROM @DATESCOUNT DATESCOUNT inner join COM_DocTextData TD on CONVERT(DATETIME,DATESCOUNT.DATE1)=CONVERT(DATETIME,TD.dcAlpha1)
					 inner join INV_DOCDETAILS ID  on  ID.INVDOCDETAILSID=TD.INVDOCDETAILSID and ISDATE(TD.dcAlpha1)=1 AND ID.STATUSID=369 AND CONVERT(DATETIME,DATE1) = CONVERT(DATETIME,TD.dcAlpha1) AND ID.COSTCENTERID=40051
				END								
				--END : UPDATING @DATESAPPLIEDCOUNT TABLE 'COUNT' COLUMN TO '3- FOR WEEKLYOFF' AND '4- FOR HOLIDAY'
				DECLARE @DAYSSUM DECIMAL(9,2)
				SET @DAYSSUM=0
				SELECT @DAYSSUM=ISNULL(SUM(NOOFDAYS),0) FROM @DATESCOUNT WHERE COUNT=1 AND NOOFDAYS=0.5 and convert(datetime,date1) between convert(datetime,@FromDate) and convert(datetime,@ToDate)
				
				SELECT @CurrYearLeavesTakenOP=COUNT(*) FROM @DATESCOUNT WHERE count=1
				SET @CurrYearLeavesTakenOP=isnull(@CurrYearLeavesTakenOP,0)-isnull(@DAYSSUM,0)
				 
				SELECT @NoOfHolidayOP=COUNT(*) FROM @DATESCOUNT WHERE count=4 and convert(DATETIME,DATE1) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)
				SELECT @NoOfWkOffsOP=COUNT(*) FROM @DATESCOUNT WHERE count=3 and convert(DATETIME,DATE1) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)
				SET @EncahsedLeavesOP=ISNULL(@ExstAppliedEncashdays,0)
				
				DROP TABLE #EMPWEEKLYOFF
				DROP TABLE #WEEKLYOFF
			END	--FROMDATE AND TODATE	
SET NOCOUNT OFF;  						
END
GO
