USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetAssignedLeavesOP]
	@EmployeeID [int] = 0,
	@LeaveType [int] = 0,
	@Date [datetime],
	@Userid [int] = 1,
	@Langid [int] = 1,
	@AssignedLeavesOP [int] OUTPUT,
	@AvlblLeavesOP [int] OUTPUT,
	@FromDateOP [datetime] OUTPUT,
	@ToDateOP [datetime] OUTPUT,
	@EncahsedLeavesOP [decimal](9, 2) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
DECLARE @Grade INT
DECLARE @Payrolltype VARCHAR(50)
DECLARE @AssignedLeaves DECIMAL(9,2),@AvlblLeaves DECIMAL(9,2)
DECLARE @MonthNo INT,@MonthSNo INT
DECLARE @CurrYearLeavestaken DECIMAL(9,2)
DECLARE @MonthLeavesrem DECIMAL(9,2)
DECLARE @CarryforwardLeaves INT
DECLARE @PermonthLeaves DECIMAL(9,2)
DECLARE @PermonthLeavesRem DECIMAL(9,2)
DECLARE @Year INT,@ALStartMonth INT,@ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME,@MaxCarryForwardDays FLOAT
DECLARE @NOOFHOLIDAYS INT,@WEEKLYOFFCOUNT INT,@EMPDOJ DATETIME
DECLARE @AssignedLeaves1 DECIMAL(9,2),@AvlblLeaves1 DECIMAL(9,2),@TotalAssignedLeaves DECIMAL(9,2),@TotalAvlblLeaves DECIMAL(9,2),@ExstAppliedEncashdays DECIMAL(9,2)
DECLARE @RC INT,@TRC INT,@ASSLEAVESTABLE INT,@FROMDATETABLE DATETIME,@TODATETABLE DATETIME,@PayrollDate DATETIME
DECLARE @PrevYearNOOFHOLIDAYS INT,@PrevYearWEEKLYOFFCOUNT INT,@PrevYearLeavestaken float,@PrevYearExstAppliedEncashdays float,@PrevYearLeaveBalance FLOAT,@FDYear DateTime,@TDYear DateTime

DECLARE @GETLEAVES TABLE(AssignedLeaves INT,AvailableLeaves DECIMAL(9,2))
DECLARE @TABASSIGNEDLEAVES TABLE(ID INT IDENTITY(1,1),AssignedLeaves INT,CarryforwardLeaves INT,EXTFROMDATE DATETIME,EXTTODATE DATETIME,NOOFMONTHS INT,TYPE VARCHAR(30))

SET @AvlblLeaves=0	
SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@Date)),0)
----FOR START DATE AND END DATE OF LEAVEYEAR
EXEC [spPAY_EXTGetLeaveyearDates] @Date,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT

--EMPLOYEE DATE OF JOINING
SELECT @EMPDOJ=CONVERT(DATETIME,DOJ) FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmployeeID

--FOR Grade

DECLARE @IsGradeWiseMP BIT
SELECT @IsGradeWiseMP=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='GradeWiseMonthlyPayroll'
IF @IsGradeWiseMP=1
BEGIN
	IF((SELECT COUNT(CostCenterID) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID53' and IsColumnInUse=1 and UserProbableValues='H')>0)
	BEGIN
		SELECT @Grade=ISNULL(HistoryNodeID,0) FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmployeeID AND CostCenterID=50051 AND HistoryCCID=50053 AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,@PayrollDate)) AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,@PayrollDate) OR ToDate IS NULL)
		IF(CONVERT(DATETIME,@EMPDOJ)>CONVERT(DATETIME,@PayrollDate) AND ISNULL(@Grade,0)=0)
			SELECT @Grade=ISNULL(HistoryNodeID,0) FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmployeeID AND CostCenterID=50051 AND HistoryCCID=50053 AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,@EMPDOJ)) AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,@EMPDOJ) OR ToDate IS NULL)
	END
	ELSE
		SELECT @Grade=ISNULL(CCNID53,0) FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=50051 AND NODEID=@EmployeeID
END
ELSE
BEGIN
	SET @Grade=1
END

--START : CHECKING ASSIGNED LEAVES       
INSERT INTO @TABASSIGNEDLEAVES	       	       
SELECT (ISNULL(DN.DCNUM3,0)),0,CONVERT(DATETIME,TD.DCALPHA3),CONVERT(DATETIME,TD.DCALPHA4),(DATEDIFF(M,CONVERT(DATETIME,TD.DCALPHA3),CONVERT(DATETIME,TD.DCALPHA4))+1),''
FROM   INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC WITH(NOLOCK),COM_DocNumData DN WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
WHERE  ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DN.INVDOCDETAILSID AND DC.INVDOCDETAILSID=DN.INVDOCDETAILSID AND
	   ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND TD.tCostCenterID=40060 AND ID.STATUSID=369  AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1
	   AND CONVERT(DATETIME,@Date) between CONVERT(DATETIME,TD.DCALPHA3) and CONVERT(DATETIME,TD.DCALPHA4) AND
	   DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType --AND DC.DCCCNID53=@Grade --AND DN.DCNUM3>0
INSERT INTO @TABASSIGNEDLEAVES	       	       
SELECT (ISNULL(DN.DCNUM3,0)),0,CONVERT(DATETIME,TD.DCALPHA3),CONVERT(DATETIME,TD.DCALPHA4),(DATEDIFF(M,CONVERT(DATETIME,TD.DCALPHA3),CONVERT(DATETIME,TD.DCALPHA4))+1),''
FROM   INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC WITH(NOLOCK),COM_DocNumData DN WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
WHERE  ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DN.INVDOCDETAILSID AND DC.INVDOCDETAILSID=DN.INVDOCDETAILSID AND
	   ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND TD.tCostCenterID=40081 AND ID.STATUSID=369  AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1
	   AND CONVERT(DATETIME,@Date) between CONVERT(DATETIME,TD.DCALPHA3) and CONVERT(DATETIME,TD.DCALPHA4)
	   AND  DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType

SELECT @AssignedLeaves=isnull(SUM(AssignedLeaves),0) from @TABASSIGNEDLEAVES where NOOFMONTHS=12
--END : CHECKING ASSIGNED LEAVES  

IF((SELECT COUNT(*) FROM COM_CC50054 WITH(NOLOCK) WHERE GradeID=@Grade AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GradeID=@Grade))>0) 
BEGIN			
	IF(@EmployeeID>0 and @LeaveType>0)
	BEGIN				         
		--FOR LEAVES TAKEN,HOLIDAYS AND WEEKLYOFFS IN A YEAR
		EXEC [spPAY_GetCurrYearLeavesInfo] @ALStartMonthYear,@ALEndMonthYear,@EmployeeID,@LeaveType,@Userid,@Langid,@Date,1,@CurrYearLeavestaken OUTPUT,@NOOFHOLIDAYS OUTPUT,@WEEKLYOFFCOUNT OUTPUT,@ExstAppliedEncashdays OUTPUT
		--PRINT 'Current year leaves taken ' + CONVERT(VARCHAR,@CurrYearLeavestaken)
		--PRINT 'Holidays count ' + CONVERT(VARCHAR,@NOOFHOLIDAYS)
		--PRINT 'Weekly off count ' + CONVERT(VARCHAR,@WEEKLYOFFCOUNT)
		--For Typeof Payroll
		SELECT @Payrolltype=ISNULL(CARRYFORWARD,'') FROM COM_CC50054 WITH(NOLOCK) WHERE GRADEID=@Grade AND COMPONENTID=@LeaveType AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GradeID=@Grade)
		--START:CHECKING THE PREVIOUS YEAR CARRY FORWARD LEAVES
		IF (@Payrolltype='Yearly' OR @Payrolltype='MonthlyYearly')
		BEGIN
				SET @FDYear=DATEADD("YY",-1,@ALStartMonthYear)
				SET @TDYear=DATEADD("YY",-1,@ALEndMonthYear)
				EXEC spPAY_GetCurrYearLeavesInfo @FDYear,@TDYear,@EmployeeID,@LeaveType,@Userid,@Langid,@Date,0,@PrevYearLeavestaken OUTPUT,@PrevYearNOOFHOLIDAYS OUTPUT,@PrevYearWEEKLYOFFCOUNT OUTPUT,@PrevYearExstAppliedEncashdays OUTPUT
				PRINT @PrevYearLeavestaken
				print 'plt'
				
				SELECT @PrevYearLeaveBalance=isnull(sum(CONVERT(DECIMAL,DN.DCNUM3)),0)-ISNULL(@PrevYearLeavestaken,0)
				FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.INVDOCDETAILSID=ID.INVDOCDETAILSID
					   INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON DN.INVDOCDETAILSID=ID.INVDOCDETAILSID INNER JOIN COM_DocTextDATA TD WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID
				WHERE TD.tCostCenterID=40081 AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1 AND CONVERT(DATETIME,TD.DCALPHA3) BETWEEN CONVERT(DATETIME,@FDYear) AND CONVERT(DATETIME,@TDYear)  AND CC.DCCCNID51=@EmployeeID AND CC.DCCCNID52=@LeaveType 
					   
				IF (isnull(@MaxCarryForwardDays,0)>0 and isnull(@PrevYearLeaveBalance,0)>isnull(@MaxCarryForwardDays,0))
					SET @CarryforwardLeaves=isnull(@MaxCarryForwardDays,0)
				ELSE IF (isnull(@MaxCarryForwardDays,0)>0 and isnull(@PrevYearLeaveBalance,0)<=isnull(@MaxCarryForwardDays,0))
					SET @CarryforwardLeaves=isnull(@PrevYearLeaveBalance,0)
				ELSE IF (isnull(@MaxCarryForwardDays,0)=0)
					SET @CarryforwardLeaves=isnull(@PrevYearLeaveBalance,0)
	   END
	  --END:CHECKING THE PREVIOUS YEAR CARRY FORWARD LEAVES
	  --Get Month
			   
		--SET @MonthNo=MONTH(CONVERT(DATETIME,@Date))
	    SET @MonthNo=DATEDIFF(m,CONVERT(DATETIME,@ALStartMonthYear),CONVERT(DATETIME,@Date))+1
		PRINT 'Month N'
		PRINT @MonthNo
		--START: LEAVES AVAILABLE FOR CURRENT MONTH OF FISCAL YEAR
		IF ISNULL(@AssignedLeaves,0)>0
		BEGIN
			SET @MonthLeavesrem=ISNULL(@MonthNo,0)
			SET @PermonthLeaves=@AssignedLeaves/12
		
  			IF (@Payrolltype='None')
			BEGIN
				SET @AvlblLeaves=ISNULL(@AssignedLeaves,0)
				SET @AvlblLeaves=@AvlblLeaves - ISNULL(@CurrYearLeavestaken,0)
			END	
			ELSE IF (@Payrolltype='Monthly')
			BEGIN
				IF ISNULL(@CurrYearLeavestaken,0)=0
					SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0))- ISNULL(@PermonthLeavesRem,0)
				ELSE
					SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0))- ISNULL(@PermonthLeavesRem,0)- ISNULL(@CurrYearLeavestaken,0)
			END
			ELSE IF (@Payrolltype='Yearly')
			BEGIN
				SET @AvlblLeaves=@AssignedLeaves
				SET @AvlblLeaves=@AvlblLeaves - ISNULL(@CurrYearLeavestaken,0)
				SET @AvlblLeaves=@AvlblLeaves + ISNULL(@CarryforwardLeaves,0)
			END
			ELSE IF (@Payrolltype='MonthlyYearly')
			BEGIN
				IF ISNULL(@CurrYearLeavestaken,0)=0
				BEGIN
					SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0)-1)+ ISNULL(@PermonthLeavesRem,0)
					SET @AvlblLeaves=@AvlblLeaves + ISNULL(@CarryforwardLeaves,0)
				END
				ELSE
				BEGIN
					SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0)-1)+ ISNULL(@PermonthLeavesRem,0)- ISNULL(@CurrYearLeavestaken,0)
					SET @AvlblLeaves=@AvlblLeaves + ISNULL(@CarryforwardLeaves,0)
				END
			END		
		END
		--END: LEAVES AVAILABLE FOR CURRENT MONTH OF FISCAL YEAR
		--START : EXTRA LEAVES AVAILABLE FOR CURRENT FISCAL YEAR
		IF ISNULL(@AssignedLeaves,0)>0
		BEGIN
			SET @PermonthLeavesRem=0
			SET @CurrYearLeavestaken=0
		END	
		SET @RC=1
		SELECT @TRC=COUNT(*) FROM @TABASSIGNEDLEAVES 
		WHILE(@RC<=@TRC)
		BEGIN
			SET @ASSLEAVESTABLE=0
			SET @FROMDATETABLE=NULL
			SET @TODATETABLE=NULL
			--SELECT @ASSLEAVESTABLE=ISNULL(AssignedLeaves,0),@FROMDATETABLE=EXTFROMDATE,@TODATETABLE=EXTTODATE FROM @TABASSIGNEDLEAVES WHERE ID=@RC AND ISNULL(NOOFMONTHS,0)<12
			SELECT @ASSLEAVESTABLE=ISNULL(AssignedLeaves,0),@FROMDATETABLE=EXTFROMDATE,@TODATETABLE=EXTTODATE FROM @TABASSIGNEDLEAVES WHERE ID=@RC AND  ISNULL(NOOFMONTHS,0)<12 
							   AND CONVERT(DATETIME,@EMPDOJ) NOT BETWEEN CONVERT(DATETIME,DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,EXTFROMDATE)),0)) AND CONVERT(DATETIME,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,EXTFROMDATE)+1,0)))
			
			IF ISNULL(@ASSLEAVESTABLE,0)>0
			BEGIN
				SET @AssignedLeaves1= ISNULL(@ASSLEAVESTABLE,0)
				SET @MonthSNo=DATEDIFF(m,CONVERT(DATETIME,@FROMDATETABLE),CONVERT(DATETIME,@Date))+1
				SET @MonthNo=DATEDIFF(m,CONVERT(DATETIME,@FROMDATETABLE),CONVERT(DATETIME,@TODATETABLE))+1
				SET @PermonthLeaves=@AssignedLeaves1/ISNULL(@MonthNo,0)
			
				IF (@Payrolltype='None')
				BEGIN
					SET @AvlblLeaves1=ISNULL(@AssignedLeaves1,0)
					SET @AvlblLeaves1=@AvlblLeaves1 --- ISNULL(@CurrYearLeavestaken,0)
				END	
				ELSE IF (@Payrolltype='Monthly')
				BEGIN
					IF ISNULL(@CurrYearLeavestaken,0)=0
					BEGIN
						SET @AvlblLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))--- ISNULL(@PermonthLeavesRem,0)
						SET @AssignedLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))
					END
					ELSE
					BEGIN
						SET @AvlblLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))--- ISNULL(@PermonthLeavesRem,0)
						SET @AssignedLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))
					END
				END
				ELSE IF (@Payrolltype='Yearly')
				BEGIN
					SET @AvlblLeaves1=@AssignedLeaves1
					SET @AvlblLeaves1=@AvlblLeaves1-- - ISNULL(@CurrYearLeavestaken,0)
					SET @AvlblLeaves1=@AvlblLeaves1 --+ ISNULL(@CarryforwardLeaves,0)
				END
				ELSE IF (@Payrolltype='MonthlyYearly')
				BEGIN
					IF ISNULL(@CurrYearLeavestaken,0)=0
					BEGIN
						SET @AvlblLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))--- ISNULL(@PermonthLeavesRem,0)
						SET @AvlblLeaves1=@AvlblLeaves1 --+ ISNULL(@CarryforwardLeaves,0)
						SET @AssignedLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))
					END
					ELSE
					BEGIN
						SET @AvlblLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))--- ISNULL(@PermonthLeavesRem,0)
						SET @AvlblLeaves1=@AvlblLeaves1 --+ ISNULL(@CarryforwardLeaves,0)
						SET @AssignedLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))
					END
				END	
						
			SET @TotalAssignedLeaves=ISNULL(@TotalAssignedLeaves,0)+ISNULL(@AssignedLeaves1,0)
			SET @TotalAvlblLeaves=ISNULL(@TotalAvlblLeaves,0)+ISNULL(@AvlblLeaves1,0)
			END
		SET @RC=@RC+1							
		END
		--END : EXTRA LEAVES AVAILABLE FOR CURRENT FISCAL YEAR
		PRINT 'Actual values (Assgined/Available)'
		PRINT @AssignedLeaves
		PRINT @AvlblLeaves
		PRINT 'Extra values (Assgined/Available)'
		PRINT @TotalAssignedLeaves
		PRINT @TotalAvlblLeaves
		--IF ASSIGNED LEAVES NOT AVAILABLE FOR CURRENT FISCAL YEAR AND TO DEDUCT LEAVES TAKEN IN CURRENT YEAR FROM EXTRA AVAILABLE LEAVES
		IF ISNULL(@AssignedLeaves,0)<=0 AND ISNULL(@TotalAvlblLeaves,0)>0
			SET @TotalAvlblLeaves=ISNULL(@TotalAvlblLeaves,0)-ISNULL(@PermonthLeavesRem,0)
		
		SET @AssignedLeaves=ISNULL(@AssignedLeaves,0)+ISNULL(@TotalAssignedLeaves,0)
		SET @AvlblLeaves=ISNULL(@AvlblLeaves,0)+ ISNULL(@TotalAvlblLeaves,0)
    
		IF(ISNULL(@AvlblLeaves,0)>0)
		BEGIN
			DECLARE @decVal FLOAT = 0
			SET @decVal=@AvlblLeaves-CONVERT(INT,@AvlblLeaves)
			IF(@decVal>=.50)
				SET @AvlblLeaves=CONVERT(INT,@AvlblLeaves)+.50
			 ELSE
				SET @AvlblLeaves=CONVERT(INT,@AvlblLeaves)
		END
		INSERT INTO @GETLEAVES SELECT @AssignedLeaves ,@AvlblLeaves 
		END
		SELECT @AssignedLeavesOP=ISNULL(AssignedLeaves,0) ,@AvlblLeavesOP=ISNULL(AvailableLeaves,0),@FromDateOP=CONVERT(VARCHAR,DATEADD(DD,0,CONVERT(DATETIME,GETDATE())),106),@ToDateOP=CONVERT(VARCHAR,DATEADD(DD,0,CONVERT(DATETIME,GETDATE())),106),@EncahsedLeavesOP=ISNULL(@ExstAppliedEncashdays,0) FROM @GETLEAVES
	END--EMPLOYEE AND LEAVETYPE
	ELSE
	BEGIN
     	  SELECT @AssignedLeavesOP=ISNULL(@AssignedLeaves,0),@AvlblLeavesOP=0,@FromDateOP=CONVERT(VARCHAR,DATEADD(DD,0,CONVERT(DATETIME,@Date)),106),@ToDateOP=CONVERT(VARCHAR,DATEADD(DD,0,CONVERT(DATETIME,@Date)),106),@EncahsedLeavesOP=0
	END
END
GO
