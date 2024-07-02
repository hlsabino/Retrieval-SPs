USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetLeavesOpeningBalance]
	@EmpIDs [nvarchar](max),
	@PayrollMonth [nvarchar](100),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

DECLARE @ALStartMonthYear DATETIME,@ALEndMonthYear DATETIME,@Date datetime,@Grade INT,@CarryforwardLeaves FLOAT,@MaxCarryForwardDays FLOAT,@Payrolltype VARCHAR(50)
DECLARE @PrevYearNOOFHOLIDAYS INT,@PrevYearWEEKLYOFFCOUNT INT,@PrevYearLeavestaken float,@PrevYearExstAppliedEncashdays float,@PayrollDate DATETIME,@OPBal FLOAT,@CarryForwardExpireDays FLOAT
DECLARE @R INT,@TRC INT,@PrevYearLeaveBalance FLOAT,@FDYear DateTime,@TDYear DateTime,@EmployeeID INT,@LeaveType INT,@SQL NVARCHAR(MAX),@DocType INT,@Remarks NVARCHAR(MAX)

CREATE TABLE #TABALOP (ID INT IDENTITY(1,1),EMPSEQNO INT,Grade INT,LeaveTypeId INT,LeaveType VARCHAR(100),Total FLOAT,Deducted FLOAT,Balance FLOAT)

--SET TO FIRST DAY FOR THE GIVEN DATE
SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@PayrollMonth)),0)

EXEC [spPAY_EXTGetLeaveyearDates] @PayrollMonth,@ALStartMonthYear OUTPUT,@ALEndMonthYear OUTPUT
SET @Date=DATEADD(year,-1,convert(datetime,@PayrollMonth))

--LOADING PREVIOUS YEAR ASSIGN LEAVES BASED ON PAYROLLMONTH
SET @SQL='INSERT INTO #TABALOP
	SELECT B.dcCCNID51 as EmpSeqNo,B.dcCCNID53,B.dcCCNID52,D.Name as LeaveType,sum(C.dcNum3) as Total,0 as Deducted,0 as Balance
	FROM INV_DocDetails A WITH(NOLOCK)
		 JOIN COM_DocCCData B WITH(NOLOCK) ON B.InvDocDetailsID=A.InvDocDetailsID
		 JOIN COM_DocNumData C WITH(NOLOCK) ON C.InvDocDetailsID=A.InvDocDetailsID
		 JOIN COM_DoctextData TD WITH(NOLOCK) ON TD.InvDocDetailsID=A.InvDocDetailsID
		 JOIN COM_CC50052 D WITH(NOLOCK) ON D.NodeID=B.dcCCNID52
	WHERE a.StatusID=369 AND (TD.tCostCenterID=40081 OR (TD.tCostcenterID=40060 AND (CommonNarration=''#Opening#'' OR CommonNarration=''#CarryForward#''))) AND b.dcCCNID51 IN('+@EmpIDs+') AND ISDATE(TD.dcAlpha3)=1 
	AND CONVERT(DATETIME,TD.dcAlpha3) between CONVERT(DATETIME,DATEADD(year,-1,'''+CONVERT(NVARCHAR,@ALStartMonthYear)+''')) and  CONVERT(DATETIME,DATEADD(year,-1,'''+CONVERT(NVARCHAR,@ALEndMonthYear)+'''))
	GROUP BY B.dcCCNID51,B.dcCCNID53,B.dcCCNID52,D.Name'
	--print (@SQL)
	EXEC sp_executesql @SQL
	--READING LEAVES TAKEN PREVIOUS YEAR AND UPDATING TOTAL COLUMN BASED ON PAYROLL TYPE (YEARLY/MONTHLYYEARY)
	set @FDYear=DATEADD("YY",-1,@ALStartMonthYear)
	set @TDYear=DATEADD("YY",-1,@ALEndMonthYear)
	SET @R=1
	SELECT @TRC=COUNT(*) FROM #TABALOP 
	WHILE(@R<=@TRC)
	BEGIN
		SELECT @EmployeeID=EmpSeqNo,@LeaveType=LeaveTypeId,@Grade=Grade FROM #TABALOP WHERE ID=@R

		DECLARE @IsGradeWiseMP BIT
		SELECT @IsGradeWiseMP=CONVERT(BIT,Value) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='GradeWiseMonthlyPayroll'
		IF @IsGradeWiseMP=1
		BEGIN
			SELECT @Payrolltype=ISNULL(CARRYFORWARD,''),@MaxCarryForwardDays=ISNULL(MaxCarryForwardDays,0),@CarryForwardExpireDays=isnull(CarryForwardExpireDays,0) FROM COM_CC50054 WITH(NOLOCK) WHERE GRADEID=@Grade AND COMPONENTID=@LeaveType AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GradeID=@Grade)
		END
		ELSE
		BEGIN
			SELECT @Payrolltype=ISNULL(CARRYFORWARD,''),@MaxCarryForwardDays=ISNULL(MaxCarryForwardDays,0),@CarryForwardExpireDays=isnull(CarryForwardExpireDays,0) FROM COM_CC50054 WITH(NOLOCK) WHERE GRADEID=1 AND COMPONENTID=@LeaveType AND PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GradeID=1)
		END

		IF (@Payrolltype='Yearly' OR @Payrolltype='MonthlyYearly')
		BEGIN
		EXEC spPAY_GetCurrYearLeavesInfo @FDYear,@TDYear,@EmployeeID,@LeaveType,@Userid,@Langid,@PayrollMonth,0,@PrevYearLeavestaken OUTPUT,@PrevYearNOOFHOLIDAYS OUTPUT,@PrevYearWEEKLYOFFCOUNT OUTPUT,@PrevYearExstAppliedEncashdays OUTPUT
			
			SELECT @OPBal=OpeningBalance FROM PAY_EmployeeLeaveDetails WITH(NOLOCK) WHERE EmployeeID=@EmployeeID AND LeaveYear=@FDYear AND LeaveTypeID=@LeaveType
			SELECT @PrevYearLeaveBalance=ISNULL(@OPBal,0) + isnull(sum(DN.DCNUM3),0)-(ISNULL(@PrevYearLeavestaken,0)+ISNULL(@PrevYearExstAppliedEncashdays,0)),@DocType=MAX(ID.DocumentType),@Remarks=MAX(ID.CommonNarration)
			FROM   INV_DOCDETAILS ID WITH(NOLOCK) INNER JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.INVDOCDETAILSID=ID.INVDOCDETAILSID
				   INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON DN.INVDOCDETAILSID=ID.INVDOCDETAILSID INNER JOIN COM_DocTextDATA TD WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID
			WHERE (TD.tCOSTCENTERID=40081 OR (TD.tCostCenterID=40060 AND (ID.CommonNarration='#Opening#' OR ID.CommonNarration='#CarryForward#'))) AND ID.STATUSID=369 AND ISDATE(TD.DCALPHA3)=1 AND ISDATE(TD.DCALPHA4)=1 AND ISDATE(TD.dcAlpha3)=1 AND CONVERT(DATETIME,TD.dcAlpha3) between CONVERT(DATETIME,CONVERT(NVARCHAR,@FDYear)) and CONVERT(DATETIME,CONVERT(NVARCHAR,@TDYear)) 
				   AND CC.DCCCNID51=@EmployeeID AND CC.DCCCNID52=@LeaveType 
			
			IF (isnull(@MaxCarryForwardDays,0)>0 and isnull(@PrevYearLeaveBalance,0)>isnull(@MaxCarryForwardDays,0))
			BEGIN
			IF(@DocType=60 AND ISNULL(@Remarks,'')='#CarryForward#')
				SET @CarryforwardLeaves=isnull(@PrevYearLeaveBalance,0)
			ELSE
				SET @CarryforwardLeaves=isnull(@MaxCarryForwardDays,0)
			END
			ELSE IF (isnull(@MaxCarryForwardDays,0)>0 and isnull(@PrevYearLeaveBalance,0)<=isnull(@MaxCarryForwardDays,0))
			BEGIN
				SET @CarryforwardLeaves=isnull(@PrevYearLeaveBalance,0)
			END
			ELSE IF (isnull(@MaxCarryForwardDays,0)=0)
			BEGIN
				SET @CarryforwardLeaves=isnull(@PrevYearLeaveBalance,0)
			END

			IF(@CarryForwardExpireDays>0)
			BEGIN
				DECLARE @T DATETIME,@CurrYearLeavestaken1 FLOAT,@NOOFHOLIDAYS1 INT,@WEEKLYOFFCOUNT1 INT,@ExstAppliedEncashdays1 FLOAT
				SET @T=DATEADD(D,@CarryForwardExpireDays,@ALStartMonthYear)-1	
				if(@PayrollMonth>@T)
				BEGIN
					EXEC spPAY_GetCurrYearLeavesInfo @ALStartMonthYear,@T,@EmployeeID,@LeaveType,@Userid,@Langid,@PayrollMonth,0,@CurrYearLeavestaken1 OUTPUT,@NOOFHOLIDAYS1 OUTPUT,@WEEKLYOFFCOUNT1 OUTPUT,@ExstAppliedEncashdays1 OUTPUT
				--SELECT @CarryforwardLeaves,@CurrYearLeavestaken1
					IF(ISNULL(@CarryforwardLeaves,0)>ISNULL(@CurrYearLeavestaken1,0))
						SET @CarryforwardLeaves=@CurrYearLeavestaken1
				END
			END

			UPDATE #TABALOP SET Total=ISNULL(@CarryforwardLeaves,0) WHERE EmpSeqNo=@EmployeeID AND LeaveTypeId=@LeaveType
		END
		ELSE
		BEGIN
			UPDATE #TABALOP SET Total=0 WHERE EmpSeqNo=@EmployeeID AND LeaveTypeId=@LeaveType
		END
	SET @R=@R+1
	END			
		
SELECT EMPSEQNO,LeaveType,Total,Deducted,Balance FROM #TABALOP
DROP TABLE #TABALOP				   
END

----spPAY_GetLeavesOpeningBalance
--'645',
--'01/Apr/2021',
--1,1
GO
