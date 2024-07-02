USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetVacationDaysContract]
	@FromDate [datetime],
	@ToDate [datetime],
	@EmpNode [int],
	@DocID [int] = 0,
	@OpBalDays [float],
	@ParamExcDays [float] = 0,
	@VFromDate [datetime],
	@VToDate [datetime],
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

Declare @DimVacDays Float,@BelowSixmonthsDays Float,@BelowOneyearDays Float,@Calculatevacdayforvacationperiod Varchar(3),@ConsiderVacationdayforExcessVacationDays Varchar(3)
Declare @ExcludeWeeklyOffsasVacation Varchar(3),@ExcludeHolidaysasVacation Varchar(3),@ConsiderLOPwhilecalculatingcreditdays Varchar(3),@ConsiderExcessdaysasLOP Varchar(3)
Declare @Perdaysalarycalculations Varchar(50),@GradewiseVacationPref Varchar(5),@AssingedDimVacDays Int,@LeaveType INT
Declare @NoOfHolidays Int,@WeeklyOffCount Int,@Grade Int,@Year Int,@ALStartMonth Int,@ALStartMonthYear DateTime,@ALEndMonthYear DateTime,@LstVacFromDate DateTime,@Leavetaken FLOAT

DECLARE @MONTH111 DATETIME,@MONTH222 DATETIME
DECLARE @MONTH13 DATETIME,@MONTH14 DATETIME

Declare @Month1 DateTime,@Month2 DateTime,@Month3 DateTime,@Month4 DateTime,@Month5 DateTime,@Month6 DateTime
Declare @Month7 DateTime,@Month8 DateTime,@Month9 DateTime,@Month10 DateTime,@Month11 DateTime,@Month12 DateTime,@ActualVacDate DateTime,@ActDOJ DateTime  
Declare @Doj DateTime,@Dorj DateTime,@VacationMonthsDiff Float,@VacationPeriod Varchar(20),@VacDaysPerMonth Float,@VacDaysPeriod Varchar(20),@TMONTHS Int,@MonthlyNoofDays Float,@VacationStartMonth DateTime
Declare @OPLeavesAsOn DateTime,@OpVacDays Float, @LocID INT,@PayrollDate DATETIME,@VacDays Float,@INCREXC VARCHAR(50),@ProbationPeriodPref nvarchar(5)
Declare @TotalCreditedDays Float,@SumofOPandTotalCreditDays Float,@CalcVacDaysuptoLastMonth Varchar(5),@LOANFROMDATE DateTime,@DOConfirmation DateTime,@AccrueVacationDaysPref nvarchar(5)
Declare @CreditDaysCalculation Int
DECLARE @LEAVESTAKEN FLOAT,@LeavesTakenEncash FLOAT,@LeavesTakenEncashSUM FLOAT,@LastReJoinDate DATETIME

--VMDD
DECLARE @VacMgmtDocID INT, @IsDefineDaysExists BIT
CREATE TABLE #VMDD(FromMonth INT,ToMonth INT,DaysPerMonth FLOAT,ApplyToPrevMonths NVARCHAR(50))
CREATE TABLE #VacMonthWiseAllotedDays(ID INT Identity(1,1),VacMonth DateTime,AllotedDays FLOAT,Yearly FLOAT)
--VMDD

SET @LeavesTakenEncashSUM=0

Declare @TABLOANDETAILS Table(SNO Int IDENTITY(1,1),LOANTYPEID Int,LOANAMOUNT Float)
Declare @MonthTab Table(ID INT Identity(1,1),STDATE DateTime,EDDATE DateTime)
Declare @MonthDays Table(ID INT Identity(1,1),FDATE DateTime,TDATE DateTime,TOTALDAYS FLOAT,ACTUALDAYS FLOAT,Days Float,LeaveTaken FLOAT)
Declare @ComponentID Int,@COMPONENTIDSNO Int,@dcNumFiled Varchar(10),@syColName Varchar(15),@strQry Varchar(max)
Declare @TAB Table(VacationDays Float,FromDate DateTime,TODATE DateTime,AppliedDays Float,ApprovedDays Float,PaidDays Float,CreditedDays Float,ExcessDays Float,RemainingDays Float)
Create Table #VacDayTab (VacDays Float)--VDAYS

--SET TO FIRST DAY FOR THE GIVEN DATE
SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@FromDate)),0)
--LOADING PREFERENCES
SELECT @CalcVacDaysuptoLastMonth=ISNULL(VALUE,'False') FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='CalcVacDaysuptolastmonth'
SELECT @AccrueVacationDaysPref=ISNULL(VALUE,'False') FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='AccrueVacationDays'

--START :GET DOJ,VACATIONPERIOD AND VACATION Days FROM EMPLOYEE
SELECT @OPLeavesAsOn=CONVERT(DateTime,OPLeavesAsOn),@OpVacDays=isnull(OpVacationDays,0),@Doj=CONVERT(DateTime,Doj),@VacationPeriod=VacationPeriod,@VacDaysPerMonth=ISNULL(VacDaysPerMonth,0),@VacDaysPeriod=VacDaysPeriod,@DOConfirmation=Convert(DateTime,DOConfirmation) 
FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmpNode
SET @ActDOJ=@Doj
PRINT 'LAON'
PRINT @OPLeavesAsOn
PRINT @OpVacDays
IF(convert(DateTime,@OPLeavesAsOn)<>'Jan  1 1900 12:00AM')
BEGIN
	SET @Doj=@OPLeavesAsOn
END
PRINT @Doj
--END :GET DOJ,VACATIONPERIOD AND VACATION Days FROM EMPLOYEE	
IF((SELECT COUNT(*) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID2' and IsColumnInUse=1 and UserProbableValues='H')>0)
	SELECT @LocID=HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmpNode AND CostCenterID=50051 AND HistoryCCID=50002 AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,@PayrollDate)) AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,@PayrollDate) OR ToDate IS NULL)
ELSE
	SELECT @LocID=ISNULL(CC.CCNID2,1) FROM COM_CC50051 C51 WITH(NOLOCK),COM_CCCCDATA CC  WITH(NOLOCK) WHERE C51.NODEID=CC.NODEID AND C51.NODEID=@EmpNode AND CC.CostCenterID=50051

PRINT 'Loc'
PRINT @LocID	


	--START:LOADING PREFERENCES BASED ON GRADE
	SELECT @GradewiseVacationPref=ISNULL(VALUE,'False') FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='GradeWiseVacation'
	IF (@GRADEWISEVACATIONPREF='True')
	BEGIN
		IF((SELECT COUNT(*) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID53' and IsColumnInUse=1 and UserProbableValues='H')>0)
			SELECT @Grade=ISNULL(HistoryNodeID,0) FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmpNode AND CostCenterID=50051 AND HistoryCCID=50053 AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,@PayrollDate)) AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,@PayrollDate) OR ToDate IS NULL)
		ELSE
			SELECT @Grade=ISNULL(CCNID53,0) FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=50051 AND NODEID=@EmpNode
	END
	
	IF ISNULL(@GRADE,0)=0
		SET @GRADE=1

	PRINT 'GRADE'
	PRINT @GRADE
	SELECT @BelowSixmonthsDays=ISNULL(TD.DCALPHA3,'0'),@BelowOneyearDays=ISNULL(TD.DCALPHA4,'0'),@Calculatevacdayforvacationperiod=ISNULL(TD.DCALPHA9,'NO'),@ConsiderVacationdayforExcessVacationDays=ISNULL(TD.DCALPHA19,'Yes'),
		   @ConsiderLOPwhilecalculatingcreditdays=ISNULL(TD.DCALPHA8,'NO'),@ConsiderExcessdaysasLOP=ISNULL(TD.DCALPHA15,'NO'), @Perdaysalarycalculations=ISNULL(TD.DCALPHA16,'(FIELD/30)') ,@AssingedDimVacDays=ISNULL(dcAlpha5,0),@LeaveType=isnull(TD.DCALPHA1,'0'),
		   @CreditDaysCalculation=ISNULL(TD.DCALPHA18,'1'),
		   @VacMgmtDocID=ID.DocID
	FROM   INV_DOCDETAILS ID WITH(NOLOCK) 
	JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID 
	JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
	WHERE  TD.tCOSTCENTERID=40061 AND CC.DCCCNID53=@Grade 
	
	--VMDD
	SET @IsDefineDaysExists=0
	IF EXISTS (SELECT SeqNo FROM PAY_VacManageDefineDays WITH(NOLOCK) WHERE VMDocID=@VacMgmtDocID)
	BEGIN
		SET @IsDefineDaysExists=1
		INSERT INTO #VMDD
		SELECT FromMonth,ToMonth,DaysPerMonth,ApplyToPrevMonths 
		FROM PAY_VacManageDefineDays WITH(NOLOCK) WHERE VMDocID=@VacMgmtDocID

		declare @dtt1 datetime,@dtt2 datetime,@TotMon INT,@AllotedDays FLOAT,@MNo INT,@APM NVARCHAR(50),@YearlyVD FLOAT
		set @dtt1=dateadd(day,-datepart(day,@ActDOJ)+1,@ActDOJ)
		set @dtt2=dateadd(day,-datepart(day,@ToDate)+1,@ToDate)
		set @dtt2=DATEADD(year,1,@dtt2) -- adding extra 1 year to know the yearly vacation days
		SET @MNo=0
		WHILE(@dtt1<=@dtt2)
		BEGIN
			SET @MNo=@MNo+1
			
			SELECT @AllotedDays=DaysPerMonth,@APM=ApplyToPrevMonths FROM #VMDD WHERE @MNo BETWEEN FromMonth AND ToMonth
			INSERT INTO #VacMonthWiseAllotedDays
			SELECT @dtt1,@AllotedDays,-1

			IF(@APM='Yes')
				UPDATE #VacMonthWiseAllotedDays SET AllotedDays=@AllotedDays

			IF(@MNo%12)=0
			BEGIN
				SELECT @YearlyVD=SUM(AllotedDays) FROM #VacMonthWiseAllotedDays WHERE Yearly=-1
				
				IF(@APM='Yes')
					UPDATE #VacMonthWiseAllotedDays SET Yearly=@YearlyVD
				ELSE
					UPDATE #VacMonthWiseAllotedDays SET Yearly=@YearlyVD WHERE Yearly=-1

			END

		 SET @dtt1=DATEADD(month,1,@dtt1)
		END

	END
	--SELECT * FROM #VacMonthWiseAllotedDays
	--VMDD
		
	--END:LOADING PREFERENCES BASED ON GRADE
	
	--SET @Calculatevacdayforvacationperiod='Yes'
	--START: GET VACDAYS FIELD FROM MONTHLY PAYROLL
	SELECT @COMPONENTIDSNO=SNO FROM COM_CC50054 WITH(NOLOCK) WHERE COMPONENTID=@AssingedDimVacDays AND GRADEID=@Grade AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GradeID=@Grade)
	SET @dcNumFiled='dcNum'+convert(Varchar,@COMPONENTIDSNO)
	
	SELECT @syColName=SYSCOLUMNNAME FROM  adm_costcenterdef WITH(NOLOCK) where costcenterid=40054 AND USERCOLUMNNAME =@dcNumFiled
	SET @syColName=REPLACE(@syColName,'dcNum','dcCalcNum')
	
	IF(ISNULL(@syColName,'')<>'' AND ISNULL(@VacationStartMonth,'')<>'' AND ISNULL(@ToDate,'')<>'')
	BEGIN
		SET @strQry='INSERT INTO #VacDayTab 
						SELECT  ISNULL(SUM('+ @syColName +'),0)  FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN PAY_DOCNUMDATA DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
						WHERE   CC.DCCCNID51='+ CONVERT(Varchar,@EmpNode) +'
								AND ID.COSTCENTERID=40054 AND CONVERT(DateTime,ID.DOCDATE) BETWEEN '''+ convert(Varchar,@VacationStartMonth) +''' and '''+ convert(Varchar,@ToDate)+''''
		--PRINT (@strQry)
		EXEC sp_executesql @STRQRY
	END
	--END: GET VACDAYS FIELD FROM MONTHLY PAYROLL		
					
	--START:FOR START DATE AND END DATE OF LEAVE YEAR
	EXEC [spPAY_EXTGetLeaveyearDates] @FromDate,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
	
	--START : LOADING MONTHS BASED ON GIVEN DATE RANGE FROM FROMDATE AND TODATE

	SET @MONTH111 =dateadd(m,-2,@ALStartMonthYear)
	SET @MONTH222 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear),0))

	SET @Month1 =@ALStartMonthYear
	SET @Month2 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+2,0))
	SET @Month3 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+2,0)))
	SET @Month4 =DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+4,0))
	SET @Month5 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+4,0)))
	SET @Month6 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+6,0))
	SET @Month7 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+6,0)))
	SET @Month8 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+8,0))
	SET @Month9 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+8,0)))
	SET @Month10 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+10,0))
	SET @Month11 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+10,0)))
	SET @Month12 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+12,0))

	SET @MONTH13 = DATEADD(d,1,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+12,0)))
	SET @MONTH14 = DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@ALStartMonthYear)+14,0))
				
	INSERT INTO @MONTHTAB VALUES(@MONTH111,@MONTH222)
	
	INSERT INTO @MonthTab VALUES(@Month1,@Month2)
	INSERT INTO @MonthTab VALUES(@Month3,@Month4)
	INSERT INTO @MonthTab VALUES(@Month5,@Month6)
	INSERT INTO @MonthTab VALUES(@Month7,@Month8)
	INSERT INTO @MonthTab VALUES(@Month9,@Month10)
	INSERT INTO @MonthTab VALUES(@Month11,@Month12)

	INSERT INTO @MONTHTAB VALUES(@MONTH13,@MONTH14)
	--END : LOADING MONTHS BASED ON GIVEN DATE RANGE FROM FROMDATE AND TODATE
	
	IF(@FromDate is not null and @ToDate is not null)
	BEGIN
		--START: FOR WEEKLY OFFS AND HOLIDAYS
		--START :CURRENT DATERANGE LEAVES TAKEN
			--START: LOADING DATES FROM @MonthTab Table	   
			Declare @DATESCOUNT Table (SNO INT Identity(1,1),ID INT ,DATE1 DateTime,DAYNAME Varchar(50),WEEKNO Int,COUNT Int,NOOFDAYS Float)
			Declare @STARTDATE1 DateTime,@ENDATE1 DateTime
			Declare @MRC AS Int,@MC AS Int,@MID Int
			
			SET @MC=1
			
			SELECT @MRC=COUNT(*) FROM @MonthTab
			WHILE (@MC<=@MRC)
			BEGIN
				SELECT @STARTDATE1=CONVERT(DateTime,STDATE),@ENDATE1=CONVERT(DateTime,EDDATE) FROM @MonthTab WHERE ID=@MC
				;WITH DATERANGE AS
				(
				SELECT @STARTDATE1 AS DT,1 AS ID
				UNION ALL
				SELECT DATEADD(DD,1,DT),DATERANGE.ID+1 FROM DATERANGE WHERE ID<=DATEDIFF("d",convert(Varchar,@STARTDATE1,101),convert(Varchar,@ENDATE1,101))
				)
				
				INSERT INTO @DATESCOUNT
				SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS WEEKDATE,DATENAME(DW,DT) AS DAY,0,0,0 FROM DATERANGE	--WHERE (DATEPART(DW,DT)=1 OR DATEPART(DW,DT)=7)
			SET @MC=@MC+1
			END
			--END: LOADING DATES FROM @MonthTab Table
			
			--START: LOADING DATA BASED ON FROMDATE AND TODATE GIVEN 
			Declare @DATESAPPLIEDCOUNT Table (FDATE DateTime,TDATE DateTime,STODATE DateTime,EODATE DateTime,NOOFDAYS Float)
			INSERT INTO @DATESAPPLIEDCOUNT
			SELECT CONVERT(DateTime,dcAlpha2),CONVERT(DateTime,dcAlpha3),CONVERT(DateTime,@FromDate),CONVERT(DateTime,@ToDate),ISNULL(dcAlpha4,0) 
			FROM INV_DOCDETAILS ID WITH(NOLOCK) 
			JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID 
			JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
			WHERE  TD.tCostCenterID=40072 AND ID.STATUSID NOT IN (372,376) AND ID.DOCID!=@DocID AND CC.DCCCNID51=@EmpNode  
			
			--END: LOADING DATA BASED ON FROMDATE AND TODATE GIVEN				 
							  
			--START: UPDATING @DATESCOUNT Table 'COUNT' COLUMN TO 1 FROM LIST OF @DATESAPPLIEDCOUNT Table
			Declare @RC AS Int,@IC AS Int,@TRC AS Int,@DTT AS DateTime,@Days Float
			SET @IC=1
			SELECT @TRC=COUNT(*) FROM @DATESCOUNT
			WHILE(@IC<=@TRC)
			BEGIN
				SELECT @DTT=DATE1 FROM @DATESCOUNT WHERE SNO=@IC
				
				SELECT @RC=COUNT(*) FROM @DATESAPPLIEDCOUNT WHERE CONVERT(DateTime,@DTT) between CONVERT(DateTime,FDATE) and CONVERT(DateTime,TDATE)
				UPDATE @DATESCOUNT SET count=ISNULL(@RC,0) WHERE CONVERT(DateTime,DATE1)=CONVERT(DateTime,@DTT)
			SET @IC=@IC+1
			END
			UPDATE DT SET  DT.NOOFDAYS=ISNULL(DAC.NOOFDAYS,0) FROM @DATESCOUNT DT INNER JOIN @DATESAPPLIEDCOUNT DAC ON DT.DATE1=DAC.FDATE AND ISNULL(DAC.NOOFDAYS,0)=0.5
			--END: UPDATING @DATESCOUNT Table 'COUNT' COLUMN TO 1 FROM LIST OF @DATESAPPLIEDCOUNT Table
		--END :CURRENT DATERANGE LEAVES TAKEN		   

		--START WEEKLYOFF COUNT
			Declare @WEEKOFFCOUNT Table (ID INT ,WEEKDATE DateTime,DAYNAME Varchar(50),WEEKNO Int,COUNT Int,WEEKNOMANUAL Int)
			INSERT INTO @WEEKOFFCOUNT
			EXEC spPAY_GetVacationWeekoff @FromDate,@ToDATE,@EmpNode,0,1,1
		----------------------- 
		--END WEEKLYOFF COUNT	 

		--COUNTING WEEKLYOFFS IN GIVEN DATERANGE
		SELECT @WeeklyOffCount=COUNT(*) FROM @WEEKOFFCOUNT WHERE COUNT=1 and convert(DateTime,WEEKDATE) between CONVERT(DateTime,@FromDate) and CONVERT(DateTime,@ToDate)

		
		--START : UPDATING @DATESAPPLIEDCOUNT Table 'COUNT' COLUMN TO '3- FOR WEEKLYOFF' AND '4- FOR HOLIDAY'
		UPDATE DATESCOUNT SET DATESCOUNT.count=3 FROM @WEEKOFFCOUNT WEEKOFFCOUNT inner join @DATESCOUNT DATESCOUNT on CONVERT(DateTime,DATESCOUNT.date1)= CONVERT(DateTime,WEEKOFFCOUNT.weekdate) and WEEKOFFCOUNT.count=1
		--END : UPDATING @DATESAPPLIEDCOUNT Table 'COUNT' COLUMN TO '3- FOR WEEKLYOFF' AND '4- FOR HOLIDAY'

		--START-- HOLIDAY COUNT
			Declare @HOLIDAYCOUNT Table (ID int Identity(1,1),WEEKDATE Nvarchar(max),Remarks nvarchar(max))
			INSERT INTO @HOLIDAYCOUNT
			EXEC spPAY_GetVacationWeekoff @FromDate,@ToDATE,@EmpNode,1,1,1
		--END -- HOLIDAY COUNT

		--START : UPDATING @DATESAPPLIEDCOUNT Table 'COUNT' COLUMN TO  '4- FOR HOLIDAY'
			UPDATE DATESCOUNT SET DATESCOUNT.count=4 FROM @DATESCOUNT DATESCOUNT 
			inner join @HOLIDAYCOUNT TD on CONVERT(DATETIME,DATESCOUNT.DATE1)=CONVERT(DATETIME,TD.WEEKDATE)
		--END : UPDATING @DATESAPPLIEDCOUNT Table 'COUNT' COLUMN TO  '4- FOR HOLIDAY'
		
		--END: FOR WEEKLY OFFS AND HOLIDAYS

		--COUNTING HOLIDAYS IN GIVEN DATERANGE
		select @NoOfHolidays=COUNT(*) from @DATESCOUNT 
		WHERE CONVERT(DATETIME,DATE1) between CONVERT(DATETIME,@FromDate) AND CONVERT(DATETIME,@ToDate) AND COUNT=4
		AND CONVERT(DATETIME,DATE1) NOT IN(select WEEKDATE from @WEEKOFFCOUNT WHERE COUNT=1 and convert(DateTime,WEEKDATE) between CONVERT(DateTime,@FromDate) and CONVERT(DateTime,@ToDate))
		--END HOLIDAYS COUNT

		PRINT 'DOJ'
		PRINT @Doj

		DECLARE @TMP INT
		SET @TMP=0
		--START : CHECKING THE PREVIOUS VACATION DETAILS OF EMPLOYEE IF NO RECORD FOUND THEN SELECT DOJ

			SET @VacationStartMonth=@FromDate
			IF(convert(DateTime,@OPLeavesAsOn)<>'Jan  1 1900 12:00AM' AND (convert(DateTime,@OPLeavesAsOn)>=convert(DateTime,@VacationStartMonth)))
			BEGIN
				SET @VacationStartMonth=@Doj
			END
			set @LastReJoinDate=@VacationStartMonth
			--VACATION MONTHS DIFFERENCE

			IF(@CalculateVacDayforVacationPeriod='Yes')
				SET @VacationMonthsDiff=  DATEDIFF(MONTH,@VacationStartMonth,DATEADD(D,-1,@ToDate))+1
			ELSE
				SET @VacationMonthsDiff=DATEDIFF(MONTH,@VacationStartMonth,DATEADD(D,-1,@FromDate))+1
			--GET VacDays FROM MONTHLY PAYROLL
			SET @DimVacDays=(SELECT ISNULL(VacDays,0) FROM #VacDayTab)
			
			--PICKING THE PERMONTH DAYS
			IF ISNULL(@DimVacDays,0)>0
			BEGIN
				SET @MonthlyNoofDays=@DimVacDays/12
			END
			ELSE IF ISNULL(@DimVacDays,0)=0 AND @VacationMonthsDiff<=6
			BEGIN
				SET @MonthlyNoofDays=@BelowSixmonthsDays
			END
			ELSE IF ISNULL(@DimVacDays,0)=0 AND @VacationMonthsDiff>6 And @VacationMonthsDiff<=12 
			BEGIN
				SET @MonthlyNoofDays=@BelowOneyearDays
			END
			ELSE
			BEGIN
				IF @VacDaysPeriod='Yearly'
					SET @TMONTHS=12
				ELSE
					SET @TMONTHS=1
			SET @MonthlyNoofDays=@VacDaysPerMonth/@TMONTHS
			END
		DROP TABLE #VACDAYTAB
		--END : CHECKING THE PREVIOUS VACATION DETAILS OF EMPLOYEE IF NO RECORD FOUND THEN SELECT DOJ	
		
		--IF(convert(DateTime,@OPLeavesAsOn)<>'Jan  1 1900 12:00AM' AND (@TMP=0 OR convert(DateTime,@OPLeavesAsOn)>=convert(DateTime,@VacationStartMonth)))
		--BEGIN
		--	SET @VacationStartMonth=@Doj
		--	set @LastReJoinDate=@VacationStartMonth
		--END

		--IF(@CalculateVacDayforVacationPeriod='Yes')
			SET @VacationMonthsDiff=DATEDIFF(MONTH,@VacationStartMonth,DATEADD(D,0,@ToDate))
		--ELSE
		--	SET @VacationMonthsDiff=DATEDIFF(MONTH,@VacationStartMonth,DATEADD(D,-1,@FromDate))

		
		--START : CALCULATING PER MONTH DAYS
		DECLARE @RC1 INT,@MONT1 DATETIME,@MONT2 DATETIME
		SET @RC1=0
		WHILE(@RC1<=@VacationMonthsDiff)
		BEGIN
			IF (@RC1=0)
			BEGIN
				SET @MONT1=DATEADD(MONTH,@RC1,@VacationStartMonth)
				IF (@AccrueVacationDaysPref='False')
				BEGIN
					IF (@VacationMonthsDiff=0)
					BEGIN
						IF(@CalculateVacDayforVacationPeriod='Yes')
							SET @MONT2=DATEADD(D,0,@ToDate)
						ELSE
							SET @MONT2=DATEADD(D,-1,@FromDate)
					END
					ELSE
						SET @MONT2=DATEADD(D,0,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@VacationStartMonth)+1,0)))
				END					
				ELSE
				BEGIN
					SET @MONT2=DATEADD(D,0,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@MONT1)+1,0)))
				END

			END
			ELSE IF (@RC1=@VacationMonthsDiff)
			BEGIN
				SET @MONT1=DATEADD(MONTH,@RC1,DATEADD(M,DATEDIFF(M,0,@VacationStartMonth),0))
				IF (@AccrueVacationDaysPref='False')
				BEGIN
					IF(@CalculateVacDayforVacationPeriod='Yes')
					SET @MONT2=@ToDate--DATEADD(D,0,@ToDate)
					ELSE
					SET @MONT2=CASE WHEN @ToDate=@VToDate THEN DATEADD(D,-1,@ToDate) ELSE @ToDate END--DATEADD(D,-1,@FromDate)
				END
				ELSE
					SET @MONT2=DATEADD(D,0,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FromDate)+1,0)))
			END
			ELSE
			BEGIN
				SET @MONT1=DATEADD(MONTH,@RC1,DATEADD(M,DATEDIFF(M,0,@VacationStartMonth),0))
				IF (@AccrueVacationDaysPref='False')
					SET @MONT2=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@MONT1)+1,0))
				ELSE
					SET @MONT2=DATEADD(D,0,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@MONT1)+1,0)))

					

			END

			--IF(YEAR(@MONT1)=2019 AND MONTH(@MONT1)=8)
			--		BEGIN
			--			SELECT @RC1,@VacationMonthsDiff,@MONT1,@MONT2,@AccrueVacationDaysPref
			--		END
			

			---------------------------------------------------

	IF EXISTS ( 
				SELECT a.InvDocDetailsID
				FROM INV_DocDetails a WITH(NOLOCK) 
				JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
				JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
				WHERE d.tCostCenterID=40072 and a.StatusID=369 AND len(d.dcAlpha2)<=15 and len(d.dcAlpha3)<=15 and ISDATE(ISNULL(d.dcAlpha2,''))=1 AND ISDATE(ISNULL(d.dcAlpha3,''))=1 AND b.dcCCNID51=@Empnode
				AND ( @MONT1 BETWEEN CONVERT(DATETIME,d.dcAlpha2) AND CONVERT(DATETIME,d.dcAlpha3) OR 
						@MONT2 BETWEEN CONVERT(DATETIME,d.dcAlpha2) AND CONVERT(DATETIME,d.dcAlpha3) OR 
						CONVERT(DATETIME,d.dcAlpha2) BETWEEN  @MONT1 AND  @MONT2 OR 
						CONVERT(DATETIME,d.dcAlpha3) BETWEEN  @MONT1 AND  @MONT2 
					)
				)
				BEGIN
				EXEC spPAY_GetVacationLeavesInfoNew @MONT1,@MONT2,@Empnode,1,1,0,@LEAVESTAKEN OUTPUT,@LeavesTakenEncash OUTPUT
				END
				ELSE
				BEGIN
					SET @LEAVESTAKEN=0	SET @LeavesTakenEncash=0
				END
				SET @LeavesTakenEncashSUM=@LeavesTakenEncashSUM+@LeavesTakenEncash
---------------------------------------------------

			--IF(@ConsiderLOPwhilecalculatingcreditdays='Yes')
			--BEGIN
			--  DECLARE @TEMPACTUALDAYS FLOAT
			--  set @TEMPACTUALDAYS=0
			--   SELECT @TEMPACTUALDAYS=CONVERT(FLOAT,TD.DCALPHA9) FROM COM_DOCTEXTDATA TD INNER JOIN INV_DOCDETAILS ID ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID Inner Join com_DocccData cc on cc.invDocdetailsid=ID.invDocdetailsid Where CostcenterID=40054 and cc.dcCCNID51=@EmpNode AND CONVERT(DATETIME,ID.DUEDATE) BETWEEN 	@MONT1 AND @MONT2
   --             INSERT INTO @MonthDays VALUES(@MONT1,@MONT2,DATEDIFF(D,DATEADD(MONTH,0,DATEADD(M,DATEDIFF(M,0,@MONT1),0)),DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@MONT2)+1,0)))+1,DATEDIFF(D,@MONT1,@MONT2)+1-ISNULL(@TEMPACTUALDAYS,0),0)
			--END
			--ELSE
			--   INSERT INTO @MonthDays VALUES(@MONT1,@MONT2,DATEDIFF(D,DATEADD(MONTH,0,DATEADD(M,DATEDIFF(M,0,@MONT1),0)),DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@MONT2)+1,0)))+1,DATEDIFF(D,@MONT1,@MONT2)+1,0)

			DECLARE @LOPDAYS FLOAT
			  set @LOPDAYS=0

			IF(@ConsiderLOPwhilecalculatingcreditdays='Yes')
			   SELECT @LOPDAYS=CONVERT(FLOAT,TD.DCALPHA9) FROM COM_DOCTEXTDATA TD INNER JOIN INV_DOCDETAILS ID ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID Inner Join com_DocccData cc on cc.invDocdetailsid=ID.invDocdetailsid Where CostcenterID=40054 and cc.dcCCNID51=@EmpNode AND CONVERT(DATETIME,ID.DUEDATE) BETWEEN 	@MONT1 AND @MONT2
                
			IF(@CalculateVacDayforVacationPeriod='Yes')
				INSERT INTO @MonthDays VALUES(@MONT1,@MONT2,DATEDIFF(D,DATEADD(MONTH,0,DATEADD(M,DATEDIFF(M,0,@MONT1),0)),DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@MONT2)+1,0)))+1,((DATEDIFF(D,@MONT1,@MONT2)+1)-ISNULL(@LOPDAYS,0)),0,@LEAVESTAKEN+@LeavesTakenEncash)
			ELSE
			   INSERT INTO @MonthDays VALUES(@MONT1,@MONT2,DATEDIFF(D,DATEADD(MONTH,0,DATEADD(M,DATEDIFF(M,0,@MONT1),0)),DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@MONT2)+1,0)))+1,((DATEDIFF(D,@MONT1,@MONT2)+1)-ISNULL(@LOPDAYS,0))-ISNULL(@LEAVESTAKEN,0),0,@LEAVESTAKEN+@LeavesTakenEncash)


		SET @RC1=@RC1+1
		END
		PRINT @MonthlyNoofDays
		
		--IF(@CreditDaysCalculation=1)
		--	UPDATE @MonthDays SET Days= ROUND((( CAST(ACTUALDAYS AS FLOAT)* CAST(@MonthlyNoofDays AS FLOAT) )/ CAST(TOTALDAYS AS FLOAT) ),2,1)
		--ELSE
		--	UPDATE @MonthDays SET Days= ROUND((( CAST(@VacDaysPerMonth AS FLOAT) / CAST(365 AS FLOAT) )* CAST(ACTUALDAYS AS FLOAT) ),2,1)

		IF(@CreditDaysCalculation=1)
		BEGIN
			--((VacDaysPerMonth*MonthDaysToConsider)/TotalMonthDays)
			IF(@IsDefineDaysExists=1)
			BEGIN
				UPDATE @MonthDays SET Days= ROUND((( CAST((Select ISNULL(AllotedDays,0) From #VacMonthWiseAllotedDays WHERE MONTH(VacMonth)=MONTH(FDATE) AND YEAR(VacMonth)=YEAR(FDATE)) AS FLOAT) * CAST(ACTUALDAYS AS FLOAT) )/ CAST(TOTALDAYS AS FLOAT) ),2,1)		
			END
			ELSE
			BEGIN
				UPDATE @MonthDays SET Days= ROUND((( CAST(ACTUALDAYS AS FLOAT)* CAST(@MonthlyNoofDays AS FLOAT) )/ CAST(TOTALDAYS AS FLOAT) ),2,1)
			END
		END
		ELSE
		BEGIN
			--((VacDaysPerYear/365)*MonthDaysToConsider)
			IF(@IsDefineDaysExists=1)
			BEGIN
				UPDATE @MonthDays SET Days= ROUND((( CAST((Select ISNULL(Yearly,0) From #VacMonthWiseAllotedDays WHERE MONTH(VacMonth)=MONTH(FDATE) AND YEAR(VacMonth)=YEAR(FDATE)) AS FLOAT) / CAST(365 AS FLOAT) )* CAST(ACTUALDAYS AS FLOAT) ),2,1)
			END
			ELSE
			BEGIN			
				UPDATE @MonthDays SET Days= ROUND((( CAST(@VacDaysPerMonth AS FLOAT) / CAST(365 AS FLOAT) )* CAST(ACTUALDAYS AS FLOAT) ),2,1)
			END
		END
		

		----CHECKING THE PREFERENCE VACATION Days UPTO LAST MONTH
		IF (@CalcVacDaysuptoLastMonth='False')
			SELECT  @TotalCreditedDays=SUM(Days) FROM @MonthDays WHERE  FDATE>=@FROMDATE AND TDATE<=@TODATE
		ELSE
			SELECT  @TotalCreditedDays=SUM(Days) FROM @MonthDays WHERE CONVERT(DateTime,FDATE)<DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DateTime,@FromDate)),0)
		--END : CALCULATING PER MONTH Days
		--SELECT * FROM @MonthDays WHERE FDATE>=@FROMDATE AND TDATE<=@TODATE
	PRINT 'Twh'
	print @FromDate
	print @ToDate
	PRINT @WeeklyOffCount
	PRINT @NoOfHolidays
	print @TotalCreditedDays

	--SELECTING THE DAYS BASED ON PREFERENCE
	SELECT @INCREXC=ISNULL(INCLUDEREXCLUDE,'') FROM COM_CC50054 WITH(NOLOCK) WHERE GRADEID=@Grade AND COMPONENTID=@LeaveType AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE GradeID=@Grade)
	IF ISNULL(@INCREXC,'')='IncludeWeeklyOffs' OR ISNULL(@INCREXC,'')='ExcludeHolidays'
	BEGIN
		INSERT INTO @TAB 
			SELECT (DATEDIFF("d",convert(Varchar,@FromDate,101),convert(Varchar,@ToDate,101))-ISNULL(@NoOfHolidays,0))+1 as VacationDays ,CONVERT(DateTime,@FromDate) as FromDate,CONVERT(DateTime,@ToDate) as ToDate,0,0,0,0,0,0
	END
	ELSE IF ISNULL(@INCREXC,'')='IncludeHolidays' OR ISNULL(@INCREXC,'')='ExcludeWeeklyOffs'
	BEGIN
		INSERT INTO @TAB 
			SELECT (DATEDIFF("d",convert(Varchar,@FromDate,101),convert(Varchar,@ToDate,101))-ISNULL(@WeeklyOffCount,0))+1 as VacationDays ,CONVERT(DateTime,@FromDate) as FromDate,CONVERT(DateTime,@ToDate) as ToDate,0,0,0,0,0,0
	END
	ELSE IF ISNULL(@INCREXC,'')='ExcludeBoth'
	BEGIN
		INSERT INTO @TAB 
			SELECT (DATEDIFF("d",convert(Varchar,@FromDate,101),convert(Varchar,@ToDate,101))-ISNULL(@NoOfHolidays,0)-ISNULL(@WeeklyOffCount,0))+1 as VacationDays ,CONVERT(DateTime,@FromDate) as FromDate,CONVERT(DateTime,@ToDate) as ToDate,0,0,0,0,0,0
	END
	ELSE IF ISNULL(@INCREXC,'')='IncludeBoth'
	BEGIN
		INSERT INTO @TAB 
			SELECT (DATEDIFF("d",convert(Varchar,@FromDate,101),convert(Varchar,@ToDate,101)))+1 as VacationDays ,CONVERT(DateTime,@FromDate) as FromDate,CONVERT(DateTime,@ToDate) as ToDate,0,0,0,0,0,0
	END
	--select * from @TAB

	-------------------
	IF(@Calculatevacdayforvacationperiod='Yes' AND @ConsiderVacationdayforExcessVacationDays='No' AND @ParamExcDays>0)
		BEGIN
			DECLARE @ExDays FLOAT
			SET @ExDays=@ParamExcDays
			IF(@ExDays>0)
			BEGIN
				Declare @RCnt2 INT,@RId2 INT,@Ex2Days FLOAT,@AcDays FLOAT
				SELECT @RCnt2=COUNT(*) FROM @MonthDays
				SET @RId2=@RCnt2
				SET @Ex2Days=@ExDays
				WHILE(@RId2>0 AND @Ex2Days>0)
				BEGIN
					SELECT @AcDays=ActualDays FROM @MOnthDays WHERE ID=@RId2
					IF(@AcDays>@Ex2Days)
					BEGIN
						UPDATE @MonthDays SET ActualDays=ActualDays-@Ex2Days WHERE ID=@RId2
						SET @Ex2Days=0
					END
					ELSE
					BEGIN
						UPDATE @MonthDays SET ActualDays=0 WHERE ID=@RId2
						SET @Ex2Days=@Ex2Days-@AcDays
					END
					SET @RId2=@RId2-1
				END


				IF(@CreditDaysCalculation=1)
				BEGIN
					--((VacDaysPerMonth*MonthDaysToConsider)/TotalMonthDays)
					IF(@IsDefineDaysExists=1)
					BEGIN
						UPDATE @MonthDays SET Days= ROUND((( CAST((Select ISNULL(AllotedDays,0) From #VacMonthWiseAllotedDays WHERE MONTH(VacMonth)=MONTH(FDATE) AND YEAR(VacMonth)=YEAR(FDATE)) AS FLOAT) * CAST(ACTUALDAYS AS FLOAT) )/ CAST(TOTALDAYS AS FLOAT) ),2,1)		
					END
					ELSE
					BEGIN
						UPDATE @MonthDays SET Days= ROUND((( CAST(ACTUALDAYS AS FLOAT)* CAST(@MonthlyNoofDays AS FLOAT) )/ CAST(TOTALDAYS AS FLOAT) ),2,1)
					END
				END
				ELSE
				BEGIN
					--((VacDaysPerYear/365)*MonthDaysToConsider)
					IF(@IsDefineDaysExists=1)
					BEGIN
						UPDATE @MonthDays SET Days= ROUND((( CAST((Select ISNULL(Yearly,0) From #VacMonthWiseAllotedDays WHERE MONTH(VacMonth)=MONTH(FDATE) AND YEAR(VacMonth)=YEAR(FDATE)) AS FLOAT) / CAST(365 AS FLOAT) )* CAST(ACTUALDAYS AS FLOAT) ),2,1)
					END
					ELSE
					BEGIN			
						UPDATE @MonthDays SET Days= ROUND((( CAST(@VacDaysPerMonth AS FLOAT) / CAST(365 AS FLOAT) )* CAST(ACTUALDAYS AS FLOAT) ),2,1)
					END
				END
				----CHECKING THE PREFERENCE VACATION Days UPTO LAST MONTH
				IF (@CalcVacDaysuptoLastMonth='False')
					SELECT  @TotalCreditedDays=SUM(Days) FROM @MonthDays WHERE  FDATE>=@FROMDATE AND TDATE<=@TODATE
				ELSE
					SELECT  @TotalCreditedDays=SUM(Days) FROM @MonthDays WHERE CONVERT(DateTime,FDATE)<DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DateTime,@FromDate)),0)
			END

		END
	------------------
	
		--ROUNDUP FOR VACATIONDAYS	
		DECLARE @VACATIONDAYS FLOAT, @decVal FLOAT
		SELECT @VACATIONDAYS=ISNULL(VACATIONDAYS ,0) FROM @TAB


	UPDATE @TAB SET AppliedDays=@VACATIONDAYS,ApprovedDays=@VACATIONDAYS,PaidDays=@VACATIONDAYS,CreditedDays= CAST(@TotalCreditedDays as DECIMAL(18,2))
	--
	
	SET @VacDays=(SELECT VacationDays FROM @TAB)
	SET @SumofOPandTotalCreditDays=ISNULL(@OpBalDays,0)+ISNULL(@TotalCreditedDays,0)

	

		declare @FSEncashDays float
	--
	SELECT @FSEncashDays=ISNULL(dcAlpha15,0) FROM INV_DocDetails I WITH(NOLOCK)
JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
JOIN COM_DocNumData N WITH(NOLOCK) ON N.InvDocDetailsID=I.InvDocDetailsID
JOIN COM_CC50052 C52 WITH(NOLOCK) ON C52.Name=dcAlpha12 AND C52.Name IN (SELECT distinct C52.Name VacationField
 FROM INV_DOCDETAILS ID WITH(NOLOCK) 
 JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID 
 JOIN COM_CC50052 C52 WITH(NOLOCK) ON C52.NodeID=TD.dcAlpha1
 WHERE TD.tCOSTCENTERID=40061 AND ID.StatusID=369	)
WHERE T.tCostCenterID=40095 AND dcAlpha1='2' AND dcAlpha10='Partial' AND CC.dcCCNID51=@EmpNode
AND CONVERT(DATETIME,dcAlpha3)<=CONVERT(DATETIME,@FromDate)
AND CONVERT(DATETIME,dcAlpha3)>=CONVERT(DATETIME,@LastReJoinDate)
	--
	
	IF ((ISNULL(@SumofOPandTotalCreditDays,0)-ISNULL(@FSEncashDays,0))>=@VacDays )
	BEGIN
		UPDATE @TAB SET RemainingDays=@SumofOPandTotalCreditDays-(ISNULL(@VacDays ,0)+ISNULL(@FSEncashDays,0))
	END
	ELSE
	BEGIN
		UPDATE @TAB SET PaidDays=ISNULL(@OpBalDays,0)+ISNULL(CreditedDays,0)-ISNULL(@FSEncashDays,0) FROM @TAB
		UPDATE @TAB SET ExcessDays=ISNULL(@VacDays ,0)-(@SumofOPandTotalCreditDays-ISNULL(@FSEncashDays,0))
	END

	SELECT  @Leavetaken=SUM(Leavetaken) FROM @MonthDays WHERE  FDATE>=@FROMDATE AND TDATE<=@TODATE

	SELECT isnull(CreditedDays,0) CreditedDays,isnull(@Leavetaken,0) Leavetaken,isnull(CreditedDays,0)-isnull(@Leavetaken,0) BalanceDays,ISNULL(@FSEncashDays,0)  FSEncashDays 
	FROM @TAB


	END	--END FOR FROM DATE AND TODATE CONDITION CHECKING


--BELOW CRITERIA EXCEPT FOR POSTING THE LEAVES AS VACATION(DOCID=-100)
--IF(@DocID<>-100)
--BEGIN
 
		
--		IF (@CalcVacDaysuptoLastMonth='True')
--			SELECT * FROM @MonthDays WHERE FDATE<@FromDate
--		ELSE
--			SELECT * FROM @MonthDays
--		--
--END

DROP TABLE #VMDD
DROP TABLE #VacMonthWiseAllotedDays


SET NOCOUNT OFF;
END

GO
