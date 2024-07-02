USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtGetAssignedLeavesOP1]
	@EmployeeID [int] = 0,
	@LeaveType [int] = 0,
	@Date [datetime],
	@Userid [int] = 1,
	@Langid [int] = 1,
	@PayrollNodeID [int],
	@AssignedLeavesOP [int] OUTPUT,
	@AvlblLeavesOP [int] OUTPUT,
	@FromDateOP [datetime] OUTPUT,
	@ToDateOP [datetime] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @Grade INT
	DECLARE @Payrolltype VARCHAR(50)
	DECLARE @AssignedLeaves INT
	DECLARE @AvlblLeaves DECIMAL(9,2)
	DECLARE @MonthNo INT
	DECLARE @CurrYearLeavestaken DECIMAL(9,2)
	DECLARE @MonthLeavesrem DECIMAL(9,2)
	DECLARE @CarryforwardLeaves INT
	DECLARE @GETLEAVES TABLE(AssignedLeaves INT,AvailableLeaves DECIMAL(9,2))
		DECLARE @PermonthLeaves DECIMAL(9,2)
	DECLARE @PermonthLeavesRem DECIMAL(9,2)
	DECLARE @PAYROLLDATE DATETIME
	SELECT @PAYROLLDATE=CONVERT(DATETIME,PAYROLLDATE) FROM COM_CC50054 WHERE NODEID=@PayrollNodeID
	SET @AvlblLeaves=0	
	--START:FOR START AND END MONTH	
	DECLARE @Year INT
	DECLARE @ALStartMonth INT
	DECLARE @ALStartMonthYear DATETIME
	DECLARE @ALEndMonthYear DATETIME
	
	
	--SELECT DISTINCT TOP 1 @Year=YEAR(CONVERT(DATETIME,DOCDATE)) FROM INV_DOCDETAILS WHERE COSTCENTERID=40060
	SELECT @Year=YEAR(CONVERT(DATETIME,@Date))
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
	
	
	if CONVERT(DATETIME,@Date)<CONVERT(DATETIME,@ALStartMonthYear)
	BEGIN
		SET @ALStartMonthYear=DATEADD(YEAR,-1,CONVERT(DATETIME,@ALStartMonthYear))
		SET @ALEndMonthYear=DATEADD(YEAR,-1,CONVERT(DATETIME,@ALEndMonthYear))
	END
	--START:FOR START AND END MONTH			
	--FOR Grade
	SELECT @Grade=ISNULL(CCNID53,0) FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=50051 AND NODEID=@EmployeeID
	--FOR AssignedLeaves & CarryforwardLeaves
	SELECT @AssignedLeaves=ISNULL(DN.DCNUM3,0),@CarryforwardLeaves=ISNULL(DN.dcNum2,0)
	FROM   INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC WITH(NOLOCK),COM_DocNumData DN WITH(NOLOCK)
	WHERE  ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=DN.INVDOCDETAILSID AND dc.INVDOCDETAILSID=DN.INVDOCDETAILSID AND
	       --YEAR(CONVERT(DATETIME,ID.DOCDATE))=YEAR(CONVERT(DATETIME,@Date))  
	       CONVERT(DATETIME,ID.DOCDATE) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
	       AND ID.COSTCENTERID=40060 AND
	       DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType AND DC.DCCCNID53=@Grade AND DN.DCNUM3>0
			            		
	IF((SELECT COUNT(*) FROM COM_CC50054 WITH(NOLOCK) WHERE NODEID=@PAYROLLNODEID)>0)
	--GradeID=@Grade AND MONTH(CONVERT(DATETIME,PAYROLLDATE))=MONTH(CONVERT(DATETIME,@Date)))>0)
	BEGIN			
		IF(@EmployeeID>0 and @LeaveType>0)
		BEGIN				         
			       SELECT @CurrYearLeavestaken=SUM(ISNULL(CONVERT(DECIMAL(9,2),TD.dcAlpha7),0))
				   FROM   INV_DOCDETAILS ID WITH(NOLOCK), COM_DocCCData DC WITH(NOLOCK),COM_DocTextData TD WITH(NOLOCK)
				   WHERE  ID.INVDOCDETAILSID=DC.INVDOCDETAILSID AND ID.INVDOCDETAILSID=TD.INVDOCDETAILSID AND DC.INVDOCDETAILSID=TD.INVDOCDETAILSID AND 
						  --YEAR(CONVERT(DATETIME,ID.DOCDATE))=YEAR(CONVERT(DATETIME,@Date)) 
						  CONVERT(DATETIME,ID.DOCDATE) between CONVERT(DATETIME,@ALStartMonthYear) and CONVERT(DATETIME,@ALEndMonthYear)
						  AND DC.DCCCNID51=@EmployeeID AND DC.DCCCNID52=@LeaveType AND DC.DCCCNID53=@Grade
						  and ID.STATUSID NOT IN (372,376)
				           
				   --For Typeof Payroll
				   SELECT @Payrolltype=ISNULL(CARRYFORWARD,'') FROM COM_CC50054 WITH(NOLOCK) WHERE NODEID=@PAYROLLNODEID--GRADEID=@Grade AND COMPONENTID=@LeaveType		
				   --Get Month
				   
				   --SET @MonthNo=MONTH(CONVERT(DATETIME,@Date))
				   SET @MonthNo=DATEDIFF(m,CONVERT(DATETIME,@ALStartMonthYear),CONVERT(DATETIME,@Date))+1
				   print 'month'
				   print @monthno
			   	   --LEAVES AVAILABLE FOR CURRENT MONTH 
				   IF ISNULL(@AssignedLeaves,0)>0
				   BEGIN
						SET @MonthLeavesrem=ISNULL(@MonthNo,0)---ISNULL(@CurrYearLeavestaken,0)
						SET @PermonthLeaves=@AssignedLeaves/12
						--SET @PermonthLeavesRem=	@PermonthLeaves-ISNULL(@CurrYearLeavestaken,0)
				  
	  					IF (@Payrolltype='None')
						BEGIN
							SET @AvlblLeaves=ISNULL(@AssignedLeaves,0)
							SET @AvlblLeaves=@AvlblLeaves - ISNULL(@CurrYearLeavestaken,0)
						END	
						ELSE IF (@Payrolltype='Monthly')
						BEGIN
							
							IF ISNULL(@CurrYearLeavestaken,0)=0
							BEGIN
								SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0))+ ISNULL(@PermonthLeavesRem,0)
							END
							ELSE
							BEGIN
								--SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0)-1)+ ISNULL(@PermonthLeavesRem,0)
								SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0))+ ISNULL(@PermonthLeavesRem,0)
							END
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
								--SET @AvlblLeaves=@AvlblLeaves --+(ISNULL(@MonthLeavesrem,0)-1)
								SET @AvlblLeaves=@AvlblLeaves + ISNULL(@CarryforwardLeaves,0)
							END
							ELSE
							BEGIN
								--SET @AvlblLeaves=@AssignedLeaves/12
								--SET @AvlblLeaves=@AvlblLeaves +(ISNULL(@MonthLeavesrem,0)-1)
								SET @AvlblLeaves=ISNULL(@PermonthLeaves,0)*(ISNULL(@MonthLeavesrem,0)-1)+ ISNULL(@PermonthLeavesRem,0)
								SET @AvlblLeaves=@AvlblLeaves + ISNULL(@CarryforwardLeaves,0)
							END
						END		
				   END
			   INSERT INTO @GETLEAVES SELECT @AssignedLeaves ,@AvlblLeaves 
		END
			  SELECT @AssignedLeavesOP=ISNULL(AssignedLeaves,0) ,@AvlblLeavesOP=ISNULL(AvailableLeaves,0) ,
			          @FromDateOP=CONVERT(VARCHAR,DATEADD(DD,5,CONVERT(DATETIME,GETDATE())),106),
			          @ToDateOP=CONVERT(VARCHAR,DATEADD(DD,6,CONVERT(DATETIME,GETDATE())),106)  FROM @GETLEAVES
    END
    ELSE
    BEGIN
	     	  SELECT @AssignedLeavesOP=ISNULL(@AssignedLeaves,0),@AvlblLeavesOP=0,
		            @FromDateOP=CONVERT(VARCHAR,DATEADD(DD,0,CONVERT(DATETIME,@Date)),106) ,
		            @ToDateOP=CONVERT(VARCHAR,DATEADD(DD,1,CONVERT(DATETIME,@Date)),106) 
    END
END
GO
