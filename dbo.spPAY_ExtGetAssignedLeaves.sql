USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetAssignedLeaves]
	@EmployeeID [int] = 0,
	@LeaveType [int] = 0,
	@Date [datetime],
	@DocID [int] = 0,
	@Userid [int] = 1,
	@Langid [int] = 1,
	@MP [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
	SET NOCOUNT ON;
	
	DECLARE @Grade INT,@Payrolltype VARCHAR(50),@AssignedLeaves FLOAT,@AvlblLeaves FLOAT,@PermonthLeaves FLOAT,@ExtraAssignedLeaves INT,@TempDate DATETIME
	DECLARE @PermonthLeavesRem FLOAT,@MonthNo INT,@MonthSNo INT,@CurrYearLeavestaken FLOAT,@MonthLeavesrem FLOAT,@CarryforwardLeaves FLOAT,@MaxCarryForwardDays FLOAT,@CarryForwardExpireDays FLOAT
	DECLARE @Year INT,@ALStartMonth INT,@ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME,@AssignedLeaves1 FLOAT,@AvlblLeaves1 FLOAT,@TotalAssignedLeaves FLOAT,@TotalAvlblLeaves FLOAT
	DECLARE @EXTRAASSIGNEDLEAVESOP FLOAT,@RC INT,@TRC INT,@ASSLEAVESTABLE FLOAT,@FROMDATETABLE DATETIME,@TODATETABLE DATETIME
	DECLARE @MonthNoEmpDoj FLOAT,@MaxEncashLeaves FLOAT,@LEThresholdLimit FLOAT,@ExstAppliedEncashdays FLOAT,@PayrollDate DATETIME,@IsEditable INT,@ExstAvlblLeaves FLOAT,@MaxLeaves float,@DOCIDNOOFDAYS FLOAT
	DECLARE @EMPDOJ DATETIME,@ActualAvailableLeaves FLOAT,@NOOFHOLIDAYS INT,@WEEKLYOFFCOUNT INT,@TotEncashDays float,@OPBal float
	DECLARE @PrevYearNOOFHOLIDAYS INT,@PrevYearWEEKLYOFFCOUNT INT,@PrevYearLeavestaken float,@PrevYearExstAppliedEncashdays float,@PrevYearLeaveBalance FLOAT,@FDYear DateTime,@TDYear DateTime,@TopUpOpeningBalance FLOAT,@TopUpCarryBalance FLOAT,@EMPDOC DATETIME,@AccrualInProbation NVARCHAR(50),@AvailInProbation NVARCHAR(50)
	
	CREATE TABLE #GETLEAVES(ID INT IDENTITY(1,1) PRIMARY KEY,AssignedLeaves FLOAT,AvailableLeaves FLOAT)
	CREATE TABLE #TABASSIGNEDLEAVES(ID INT IDENTITY(1,1) PRIMARY KEY,AssignedLeaves FLOAT,CarryforwardLeaves INT,EXTFROMDATE DATETIME,EXTTODATE DATETIME,NOOFMONTHS INT,TYPE VARCHAR(30))
	
	----FOR START DATE AND END DATE OF LEAVE YEAR	
	EXEC [spPAY_EXTGetLeaveyearDates] @Date,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
	
	--SET TO FIRST DAY FOR THE GIVEN DATE
	SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@Date)),0)
	SET @AvlblLeaves=0		
	SET @DOCIDNOOFDAYS=0	
	print @PayrollDate
	
	--EMPLOYEE DATE OF JOINING
	SELECT @EMPDOJ=CONVERT(DATETIME,DOJ),@EMPDOC=CONVERT(DATETIME,DOConfirmation) FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmployeeID
	
	--FOR Grade
		DECLARE @IsGradeWiseMP BIT
SELECT @IsGradeWiseMP=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='GradeWiseMonthlyPayroll'
IF @IsGradeWiseMP=1
BEGIN
	IF((SELECT COUNT(CostCenterID) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID53' and IsColumnInUse=1 and UserProbableValues='H')>0)
	BEGIN
		SELECT @Grade=ISNULL(HistoryNodeID,0) FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmployeeID AND CostCenterID=50051 AND HistoryCCID=50053 AND (FromDate<=CONVERT(FLOAT,CONVERT(DATETIME,@PayrollDate))) AND (ToDate>=CONVERT(FLOAT,CONVERT(DATETIME,@PayrollDate)) OR ToDate IS NULL)
		IF(CONVERT(DATETIME,@EMPDOJ)>CONVERT(DATETIME,@PayrollDate) AND ISNULL(@Grade,0)=0)
			SELECT @Grade=ISNULL(HistoryNodeID,0) FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmployeeID AND CostCenterID=50051 AND HistoryCCID=50053 AND (FromDate<=CONVERT(FLOAT,CONVERT(DATETIME,@EMPDOJ))) AND (ToDate>=CONVERT(FLOAT,CONVERT(DATETIME,@EMPDOJ)) OR ToDate IS NULL)
	END
	ELSE
		SELECT @Grade=ISNULL(CCNID53,0) FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=50051 AND NODEID=@EmployeeID
END
ELSE
BEGIN
 SET @Grade=1
END

	print @Grade
	--FOR OPENING BALANCE LEAVES
	SET @ActualAvailableLeaves=0
	SELECT @ActualAvailableLeaves=ISNULL(BalanceLeaves,0) FROM PAY_EMPLOYEELEAVEDETAILS WITH(NOLOCK) WHERE CONVERT(DATETIME,LEAVEYEAR)=CONVERT(DATETIME,@ALStartMonthYear) AND EmployeeID=@EmployeeID AND LeaveTypeID=@LeaveType
	
	--READING APPLIED LEAVES
	DECLARE @EDATE DATETIME,@DocumentType int
	SET @TotEncashDays=0
	SET @EDATE=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@date)+1,0))
	IF ISNULL(@DocID,0)>0
	BEGIN
		--APPLIED LEAVES BY DOCID
		SELECT @DOCIDNOOFDAYS=ISNULL(TD.dcAlpha7,0),@ActualAvailableLeaves=isnull(TD.dcAlpha14,0) FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
			   JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
		WHERE  ISDATE(TD.DCALPHA4)=1 and TD.tDocumentType=62 AND DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType AND ID.DOCID=@DocID
		
		--ENCASHED LEAVES BASED ON DATE RANGE
		SET @DocumentType=(SELECT TOP 1 DocumentType FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DocID)
		IF(@DocumentType=62)
		BEGIN
			SELECT @TotEncashDays=ISNULL(TD.dcAlpha3,0) FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
				   JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
			WHERE  TD.tCostCenterID=40058 AND DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType AND convert(datetime,id.docdate) between convert(datetime,@PayrollDate) and convert(datetime,@EDATE)
		END
		ELSE IF(@DocumentType=58)--ENCASHED LEAVES BY DOCID
		BEGIN
			SET @DOCIDNOOFDAYS=0
			SELECT @DOCIDNOOFDAYS=ISNULL(TD.dcAlpha3,0),@ActualAvailableLeaves=isnull(TD.dcAlpha7,0) FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
				   JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
			WHERE  TD.tCostCenterID=40058 AND DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType  AND ID.DOCID=@DocID
		END
	END

	--START : LOADING ASSIGNED LEAVES       
		INSERT INTO #TABASSIGNEDLEAVES	       	       
			SELECT (ISNULL(DN.DCNUM3,0)),(ISNULL(DN.dcNum2,0)),CONVERT(DATETIME,TD.DCALPHA3),CONVERT(DATETIME,TD.DCALPHA4),
			       (DATEDIFF(M,CONVERT(DATETIME,TD.DCALPHA3),CONVERT(DATETIME,TD.DCALPHA4))+1),(SELECT 'COMP' FROM INV_DOCDETAILS D WHERE D.INVDOCDETAILSID=ID.REFNODEID AND D.COSTCENTERID=40059) 
			FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
				   INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID INNER JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
			WHERE TD.tCostCenterID=40060 AND ID.STATUSID=369 AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1 AND CONVERT(DATETIME,@Date) between CONVERT(DATETIME,TD.DCALPHA3) and CONVERT(DATETIME,TD.DCALPHA4)
  		            AND DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType --AND DC.DCCCNID53=@Grade
  		           
		INSERT INTO #TABASSIGNEDLEAVES     	       
			SELECT (ISNULL(DN.DCNUM3,0)),(ISNULL(DN.dcNum2,0)),
			CASE WHEN CONVERT(DATETIME,@EMPDOJ)>CONVERT(DATETIME,TD.DCALPHA3) THEN CONVERT(DATETIME,('01 '+ RIGHT(CONVERT(VARCHAR(11), CONVERT(DATETIME,@EMPDOJ), 106), 8))) ELSE 
			CONVERT(DATETIME,TD.DCALPHA3) END,CONVERT(DATETIME,TD.DCALPHA4),
			CASE WHEN CONVERT(DATETIME,@EMPDOJ)>CONVERT(DATETIME,TD.DCALPHA3) THEN (DATEDIFF(M,CONVERT(DATETIME,('01 '+ RIGHT(CONVERT(VARCHAR(11), CONVERT(DATETIME,@EMPDOJ), 106), 8))),CONVERT(DATETIME,TD.DCALPHA4))+1) ELSE 
			(DATEDIFF(M,CONVERT(DATETIME,TD.DCALPHA3),CONVERT(DATETIME,TD.DCALPHA4))+1) END,''
			FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData DC WITH(NOLOCK) ON ID.INVDOCDETAILSID=DC.INVDOCDETAILSID
				   INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID INNER JOIN COM_DocTextData TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
			WHERE TD.tCostCenterID=40081 AND ID.STATUSID=369 AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1 AND CONVERT(DATETIME,@Date) between CONVERT(DATETIME,TD.DCALPHA3) and CONVERT(DATETIME,TD.DCALPHA4)
  		           AND  DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType --AND DC.DCCCNID53=@Grade	  		           
			   
		--SELECT * FROM @TABASSIGNEDLEAVES			   
		SELECT @AssignedLeaves=isnull(SUM(AssignedLeaves),0) from #TABASSIGNEDLEAVES WITH(NOLOCK) where  NOOFMONTHS=12
		SELECT @FROMDATETABLE=CONVERT(DATETIME,EXTFROMDATE) from #TABASSIGNEDLEAVES WITH(NOLOCK) where  NOOFMONTHS=12

		--IF EMPLOYEE JOINED BETWEEN FISCAL YEAR	
		IF(@AssignedLeaves=0)
			SELECT @AssignedLeaves=isnull(SUM(AssignedLeaves),0),@FROMDATETABLE=CONVERT(DATETIME,@EMPDOJ) from #TABASSIGNEDLEAVES WITH(NOLOCK) where  CONVERT(DATETIME,@EMPDOJ) BETWEEN CONVERT(DATETIME,DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,EXTFROMDATE)),0)) AND CONVERT(DATETIME,DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,EXTFROMDATE)+1,0)))
	--END : CHECKING ASSIGNED LEAVES    
			            		
	IF((SELECT COUNT(*) FROM COM_CC50054 WITH(NOLOCK) WHERE GradeID=@Grade AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GradeID=@Grade))>0)
	BEGIN			
		IF(@EmployeeID>0 and @LeaveType>0)
		BEGIN		
				set @CurrYearLeavestaken=0
				set @ExstAppliedEncashdays=0
				--select @ALStartMonthYear,@ALEndMonthYear,@EmployeeID,@LeaveType,@Userid,@Langid,@Date,0
				IF(@MP=1)
				BEGIN	
				SET @TempDate=DATEADD("d",-1,@Date)	
					EXEC spPAY_GetCurrYearLeavesInfo @ALStartMonthYear,@TempDate,@EmployeeID,@LeaveType,@Userid,@Langid,@Date,0,@CurrYearLeavestaken OUTPUT,@NOOFHOLIDAYS OUTPUT,@WEEKLYOFFCOUNT OUTPUT,@ExstAppliedEncashdays OUTPUT
				END
				ELSE
				BEGIN
				EXEC spPAY_GetCurrYearLeavesInfo @ALStartMonthYear,@ALEndMonthYear,@EmployeeID,@LeaveType,@Userid,@Langid,@Date,0,@CurrYearLeavestaken OUTPUT,@NOOFHOLIDAYS OUTPUT,@WEEKLYOFFCOUNT OUTPUT,@ExstAppliedEncashdays OUTPUT
				END
				--select @CurrYearLeavestaken
				--print 'clt'
				--PRINT @CurrYearLeavestaken
				--PRINT @NOOFHOLIDAYS
				--PRINT @WEEKLYOFFCOUNT		 
				--PRINT @ExstAppliedEncashdays
				--print @DOCIDNOOFDAYS
				
				   --Reading Payroll Type,MaxEncash leaves and Max Leaves
				   SELECT @Payrolltype=ISNULL(CARRYFORWARD,''),@MaxEncashLeaves=isnull(MaxEncashDays,0),@LEThresholdLimit=isnull(LEThresholdLimit,0),@MaxLeaves=isnull(MaxLeaves,0),@MaxCarryForwardDays=ISNULL(MaxCarryForwardDays,0),@AccrualInProbation=ISNULL(AccrualInProbation,'Yes'),@AvailInProbation=ISNULL(AvailInProbation,'Yes'),@CarryForwardExpireDays=isnull(CarryForwardExpireDays,0) FROM COM_CC50054 WITH(NOLOCK) WHERE GRADEID=@Grade AND COMPONENTID=@LeaveType	AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GradeID=@Grade)
					
				   --START:CHECKING THE PREVIOUS YEAR CARRY FORWARD LEAVES
				   IF (@Payrolltype='Yearly' OR @Payrolltype='MonthlyYearly')
				   BEGIN
						SET @FDYear=DATEADD("YY",-1,@ALStartMonthYear)
						SET @TDYear=DATEADD("YY",-1,@ALEndMonthYear)
						EXEC spPAY_GetCurrYearLeavesInfo @FDYear,@TDYear,@EmployeeID,@LeaveType,@Userid,@Langid,@Date,0,@PrevYearLeavestaken OUTPUT,@PrevYearNOOFHOLIDAYS OUTPUT,@PrevYearWEEKLYOFFCOUNT OUTPUT,@PrevYearExstAppliedEncashdays OUTPUT
						PRINT @PrevYearLeavestaken
						
						SET @TopUpOpeningBalance=0
						SELECT @TopUpOpeningBalance=isnull(sum(DN.DCNUM3),0)
						FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.INVDOCDETAILSID=ID.INVDOCDETAILSID
							   INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON DN.INVDOCDETAILSID=ID.INVDOCDETAILSID INNER JOIN COM_DocTextDATA TD WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID
						WHERE TD.tCostCenterID=40060 AND ID.CommonNarration='#Opening#' AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1 AND ID.STATUSID=369 AND CONVERT(DATETIME,TD.DCALPHA3) BETWEEN CONVERT(DATETIME,@FDYear) AND CONVERT(DATETIME,@TDYear)
							   AND CC.DCCCNID51=@EmployeeID AND CC.DCCCNID52=@LeaveType 

						SET @TopUpCarryBalance=0
						SELECT @TopUpCarryBalance=isnull(sum(DN.DCNUM3),0)
						FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.INVDOCDETAILSID=ID.INVDOCDETAILSID
							   INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON DN.INVDOCDETAILSID=ID.INVDOCDETAILSID INNER JOIN COM_DocTextDATA TD WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID
						WHERE  TD.tCostCenterID=40060 AND ID.CommonNarration='#CarryForward#' AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1 AND ID.STATUSID=369 AND CONVERT(DATETIME,TD.DCALPHA3) BETWEEN CONVERT(DATETIME,@FDYear) AND CONVERT(DATETIME,@TDYear)
							   AND CC.DCCCNID51=@EmployeeID AND CC.DCCCNID52=@LeaveType 

						SELECT @OPBal=OpeningBalance FROM PAY_EmployeeLeaveDetails WITH(NOLOCK) WHERE EmployeeID=@EmployeeID AND LeaveYear=@FDYear AND LeaveTypeID=@LeaveType

						SELECT @PrevYearLeaveBalance=isnull(@OPBal,0) + isnull(sum(DN.DCNUM3),0)+ @TopUpOpeningBalance -(ISNULL(@PrevYearLeavestaken,0)+ISNULL(@PrevYearExstAppliedEncashdays,0))
						FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.INVDOCDETAILSID=ID.INVDOCDETAILSID
							   INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON DN.INVDOCDETAILSID=ID.INVDOCDETAILSID INNER JOIN COM_DocTextDATA TD WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID
						WHERE  TD.tCostCenterID=40081 AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1 AND ID.STATUSID=369 AND CONVERT(DATETIME,TD.DCALPHA3) BETWEEN CONVERT(DATETIME,@FDYear) AND CONVERT(DATETIME,@TDYear)
							   AND CC.DCCCNID51=@EmployeeID AND CC.DCCCNID52=@LeaveType 
						
						IF (isnull(@MaxCarryForwardDays,0)>0 and isnull(@PrevYearLeaveBalance,0)>isnull(@MaxCarryForwardDays,0))
							SET @CarryforwardLeaves=isnull(@MaxCarryForwardDays,0)
						ELSE IF (isnull(@MaxCarryForwardDays,0)>0 and isnull(@PrevYearLeaveBalance,0)<=isnull(@MaxCarryForwardDays,0))
							SET @CarryforwardLeaves=isnull(@PrevYearLeaveBalance,0)
						ELSE IF (isnull(@MaxCarryForwardDays,0)=0)
							SET @CarryforwardLeaves=isnull(@PrevYearLeaveBalance,0)

						IF(@CarryForwardExpireDays>0)
						BEGIN
							DECLARE @T DATETIME,@CurrYearLeavestaken1 FLOAT,@NOOFHOLIDAYS1 INT,@WEEKLYOFFCOUNT1 INT,@ExstAppliedEncashdays1 FLOAT
							SET @T=DATEADD(D,@CarryForwardExpireDays,@ALStartMonthYear)-1
							
							if(@Date>@T)
							BEGIN
								EXEC spPAY_GetCurrYearLeavesInfo @ALStartMonthYear,@T,@EmployeeID,@LeaveType,@Userid,@Langid,@Date,0,@CurrYearLeavestaken1 OUTPUT,@NOOFHOLIDAYS1 OUTPUT,@WEEKLYOFFCOUNT1 OUTPUT,@ExstAppliedEncashdays1 OUTPUT
							--SELECT @CarryforwardLeaves,@CurrYearLeavestaken1
								IF(ISNULL(@CarryforwardLeaves,0)>ISNULL(@CurrYearLeavestaken1,0))
									SET @CarryforwardLeaves=@CurrYearLeavestaken1
							END
						END
				   END
				   --END:CHECKING THE PREVIOUS YEAR CARRY FORWARD LEAVES

				   --Set Month No From Given Date and Fiscal Year Start Date
				   SET @MonthNo=DATEDIFF(m,CONVERT(DATETIME,@ALStartMonthYear),CONVERT(DATETIME,@Date))+1
				  
				   --Set Month No, If Employee Doj is after the the fiscal year start date
				   SET @MonthNoEmpDoj=DATEDIFF(m,CONVERT(DATETIME,@ALStartMonthYear),CONVERT(DATETIME,@FROMDATETABLE))

				   if(@AccrualInProbation='No')
				   BEGIN
						SET @MonthNoEmpDoj=DATEDIFF(m,CONVERT(DATETIME,@ALStartMonthYear),CONVERT(DATETIME,@EMPDOC))
				   END
				   
				   --START: CHECKING LEAVES AVAILABLE FOR CURRENT MONTH OF FISCAL YEAR
				   IF ISNULL(@AssignedLeaves,0)>0
				   BEGIN
						--Month No,If Employee Doj is after the the fiscal year start date
						IF ISNULL(@MonthNoEmpDoj,0)>0
						BEGIN
							SET @MonthNo=@MonthNo-@MonthNoEmpDoj
							SET @MonthLeavesrem=ISNULL(@MonthNo,0)
							SET @MonthNoEmpDoj=12-@MonthNoEmpDoj
							
							if(@AccrualInProbation='No' AND CONVERT(DATETIME,@EMPDOC)>CONVERT(DATETIME,@ALEndMonthYear))
								SET @PermonthLeaves=0
							ELSE
								SET @PermonthLeaves=@AssignedLeaves/@MonthNoEmpDoj
						END
						ELSE
						BEGIN--Month No From Given Date and Fiscal Year Start Date
							SET @MonthLeavesrem=ISNULL(@MonthNo,0)
							SET @PermonthLeaves=@AssignedLeaves/12
						END
										
	  					IF (@Payrolltype='None')
						BEGIN
							IF(@AvailInProbation='No' AND CONVERT(DATETIME,@Date)<CONVERT(DATETIME,@EMPDOC))
								SET @AvlblLeaves=0
							ELSE
								SET @AvlblLeaves=ISNULL(@AssignedLeaves,0)- ISNULL(@CurrYearLeavestaken,0)
						END	
						ELSE IF (@Payrolltype='Monthly')
						BEGIN
							SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0)) - ISNULL(@CurrYearLeavestaken,0)
						END
						ELSE IF (@Payrolltype='Yearly')
						BEGIN
							IF(@AvailInProbation='No' AND CONVERT(DATETIME,@Date)<CONVERT(DATETIME,@EMPDOC))
								SET @AvlblLeaves=0
							ELSE
								SET @AvlblLeaves=(@AssignedLeaves  + ISNULL(@CarryforwardLeaves,0)) - ISNULL(@CurrYearLeavestaken,0)
						END
						ELSE IF (@Payrolltype='MonthlyYearly')
						BEGIN
							SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0)) - ISNULL(@CurrYearLeavestaken,0)
							SET @AvlblLeaves=isnull(@AvlblLeaves,0) + ISNULL(@CarryforwardLeaves,0)
						END		
				   END
				   --END: CHECKING LEAVES AVAILABLE FOR CURRENT MONTH OF FISCAL YEAR
				   
				   --START : CHECKING EXTRA LEAVES AVAILABLE FOR CURRENT FISCAL YEAR(TOP UP LEAVES)
				   IF ISNULL(@AssignedLeaves,0)>0
						SET @CurrYearLeavestaken=0
						
				   SET @RC=1
				   SELECT @TRC=COUNT(*) FROM #TABASSIGNEDLEAVES WITH(NOLOCK) 
				   WHILE(@RC<=@TRC)
				   BEGIN
						SET @ASSLEAVESTABLE=0
						SET @FROMDATETABLE=NULL
						SET @TODATETABLE=NULL
						SELECT @ASSLEAVESTABLE=ISNULL(AssignedLeaves,0),@FROMDATETABLE=EXTFROMDATE,@TODATETABLE=EXTTODATE FROM #TABASSIGNEDLEAVES WITH(NOLOCK) WHERE ID=@RC AND  ISNULL(NOOFMONTHS,0)<12 
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
							END	
							ELSE IF (@Payrolltype='Monthly')
							BEGIN
								SET @AvlblLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))
								SET @AssignedLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))
							END
							ELSE IF (@Payrolltype='Yearly')
							BEGIN
								SET @AvlblLeaves1=@AssignedLeaves1
							END
							ELSE IF (@Payrolltype='MonthlyYearly')
							BEGIN
								SET @AvlblLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))
								SET @AssignedLeaves1=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthSNo,0))
							END	
									
						SET @TotalAssignedLeaves=ISNULL(@TotalAssignedLeaves,0)+ISNULL(@AssignedLeaves1,0)
						SET @TotalAvlblLeaves=ISNULL(@TotalAvlblLeaves,0)+ISNULL(@AvlblLeaves1,0)
						END
				   SET @RC=@RC+1							
				   END
				   --END : CHECKING EXTRA LEAVES AVAILABLE FOR CURRENT FISCAL YEAR
				    IF (@Payrolltype='Yearly')
					BEGIN
						SET @TotalAvlblLeaves=ISNULL(@TotalAvlblLeaves,0)+(ISNULL(@TopUpCarryBalance,0))
					END
					ELSE IF (@Payrolltype='MonthlyYearly')
					BEGIN
						SET @TotalAvlblLeaves=ISNULL(@TotalAvlblLeaves,0)+(ISNULL(@TopUpCarryBalance,0))
					END	
						
				--print 'Actual values'
				--print @AssignedLeaves
				--print @AvlblLeaves
				--print 'Extra values'
				--print @TotalAssignedLeaves
				--print @TotalAvlblLeaves
				
				--IF ASSIGNED LEAVES NOT AVAILABLE FOR CURRENT FISCAL YEAR AND TO DEDUCT LEAVES TAKEN IN CURRENT YEAR FROM EXTRA AVAILABLE LEAVES
				IF (ISNULL(@AssignedLeaves,0)<=0 AND ISNULL(@TotalAvlblLeaves,0)>0)
					SET @TotalAvlblLeaves=ISNULL(@TotalAvlblLeaves,0)-ISNULL(@CurrYearLeavestaken,0)

				SET @AssignedLeaves=ISNULL(@AssignedLeaves,0)+ISNULL(@TotalAssignedLeaves,0)
				
				SET @AvlblLeaves=ISNULL(@AvlblLeaves,0)+ ISNULL(@TotalAvlblLeaves,0)
				
				--ENCASH LEAVES
				IF (ISNULL(@AssignedLeaves,0)>0 AND ISNULL(@AvlblLeaves,0)>0)
					SET @AvlblLeaves=ISNULL(@AvlblLeaves,0)-ISNULL(@ExstAppliedEncashdays,0)
					
				--CURRENCT DOCUMENT LEAVES
				IF(isnull(@DocID,0)>0 and isnull(@MaxLeaves,0)>0)
				BEGIN
					--IF (ISNULL(@AvlblLeaves,0)>0)
						SET @AvlblLeaves=isnull(@AvlblLeaves,0)+ISNULL(@DOCIDNOOFDAYS,0)
					--IF(isnull(@ActualAvailableLeaves,0)>0)
					--	SET @ActualAvailableLeaves=isnull(@ActualAvailableLeaves,0)+ISNULL(@DOCIDNOOFDAYS,0)+isnull(@TotEncashDays,0)
				END
				
				--PRINT 'ENCASH'
				--PRINT @ExstAppliedEncashdays
				--PRINT @TotalAvlblLeaves
				--PRINT @AvlblLeaves
				--print @DOCIDNOOFDAYS
					
				DECLARE @decVal FLOAT = 0
				--ROUNDOFF AVAILABLE LEAVES
				IF(ISNULL(@AvlblLeaves,0)>0)
				BEGIN
					
					SET @decVal=@AvlblLeaves-CONVERT(INT,@AvlblLeaves)
					IF(@decVal>=.50)
						SET @AvlblLeaves=CONVERT(INT,@AvlblLeaves)+.50
					 ELSE
   						SET @AvlblLeaves=CONVERT(INT,@AvlblLeaves)
				END
				ELSE
				BEGIN
					SET @AvlblLeaves=0
				END
				--ROUNDOFF ASSIGNED LEAVES
				SET @decVal=0
				IF(ISNULL(@AssignedLeaves,0)>0)
				BEGIN
					
					SET @decVal=@AssignedLeaves-CONVERT(INT,@AssignedLeaves)
					IF(@decVal>=.50)
						SET @AssignedLeaves=CONVERT(INT,@AssignedLeaves)+.50
					 ELSE
   						SET @AssignedLeaves=CONVERT(INT,@AssignedLeaves)
				END
				
			INSERT INTO #GETLEAVES SELECT @AssignedLeaves ,@AvlblLeaves 
		END--EMPLOYEE AND LEAVETYPE
		SELECT ISNULL(AssignedLeaves,0) AssignedLeaves,ISNULL(AvailableLeaves,0) AvailableLeaves,CONVERT(DATETIME,getdate()) as FromDate,CONVERT(DATETIME,getdate()) as ToDate,
		       @MaxEncashLeaves as MaxEncashLeaves,@MaxLeaves as MaxLeaves,ISNULL(@ActualAvailableLeaves,0) AS ActualAvailableLeaves,@LEThresholdLimit as ThresholdLimit FROM #GETLEAVES WITH(NOLOCK)
    END
    ELSE--NO PAYROLL STRUCTURE EXIST
    BEGIN
		SELECT ISNULL(@AssignedLeaves,0) AS AssignedLeaves,0  AS AvailableLeaves,CONVERT(DATETIME,@Date) as FromDate,CONVERT(DATETIME,@Date) as ToDate,
		       0 as MaxEncashLeaves,@MaxLeaves as MaxLeaves,0 AS ActualAvailableLeaves, 0 as ThresholdLimit
    END
	DROP TABLE #GETLEAVES 
	DROP TABLE #TABASSIGNEDLEAVES 
    
SET NOCOUNT OFF;  
--RETURN 1  
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH

GO
