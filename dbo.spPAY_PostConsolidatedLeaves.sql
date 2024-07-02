USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_PostConsolidatedLeaves]
	@DocID [int],
	@PayrollMonth [datetime] = '01-DEC-2016',
	@UserId [int] = 1,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
		DECLARE @TAB TABLE(ID INT IDENTITY(1,1),INVDOCDETAILSID INT,EMPNODE INT,EMPNAME VARCHAR(500),GRADENODE INT,LEAVETYPENODE INT,LEAVETYPENAME VARCHAR(100),
						   DAYS DECIMAL(9,2),FROMDATE DATETIME,TODATE DATETIME,SESSION VARCHAR(10),ATATIME INT,MAXLEAVES INT,
						   ASSIGNEDLEAVES INT,AVLBLLEAVES DECIMAL(9,2),AVLBLLEAVESREM DECIMAL(9,2),REMARKS VARCHAR(200))
		INSERT INTO @TAB
		SELECT  ID.INVDOCDETAILSID,C51.DCCCNID51,EMP.NAME,CASE ISNULL(CC.CCNID53,'0') WHEN 0 THEN C53.DCCCNID53 ELSE CC.CCNID53 END,
			    C52.DCCCNID52,LT.NAME,ISNULL(DN.dcNum1,0) Days,NULL,NULL,'Both',0,0,0,0,0,''
		FROM    INV_DOCDETAILS ID WITH(NOLOCK)
				INNER JOIN COM_DocCCData C51 WITH(NOLOCK) ON C51.INVDOCDETAILSID=ID.INVDOCDETAILSID
				INNER JOIN COM_DocCCData C53 WITH(NOLOCK) ON C53.INVDOCDETAILSID=ID.INVDOCDETAILSID
				INNER JOIN COM_DocCCData C52 WITH(NOLOCK) ON C52.INVDOCDETAILSID=ID.INVDOCDETAILSID
				INNER JOIN COM_DocNumData DN WITH(NOLOCK) ON DN.INVDOCDETAILSID=ID.INVDOCDETAILSID
				INNER JOIN COM_CCCCDATA CC WITH(NOLOCK) ON C51.DCCCNID51=CC.NODEID AND CC.COSTCENTERID=50051
				INNER JOIN COM_CC50051 EMP WITH(NOLOCK) ON EMP.NODEID=C51.DCCCNID51 AND EMP.NODEID=CC.NODEID
				INNER JOIN COM_CC50052 LT WITH(NOLOCK) ON LT.NODEID=C52.DCCCNID52
		WHERE   ID.DOCID=@DocID AND ID.COSTCENTERID=40063
				ORDER BY C51.DCCCNID51,C52.DCCCNID52,ISNULL(DN.dcNum1,0)
			

DECLARE @Days DECIMAL(9,2)
DECLARE @EmpNode INT
DECLARE @PrevEmpNode INT
DECLARE @LeaveType INT
DECLARE @StartDate DATETIME
DECLARE @FDate DATETIME
DECLARE @TDate DATETIME
DECLARE @RCount INT
DECLARE @I INT
DECLARE @EmpName VARCHAR(500)
DECLARE @LeaveTypeName VARCHAR(100)
DECLARE @AssignedLeavesOP INT
DECLARE	@AvlblLeavesOP DECIMAL(9,2) 
DECLARE	@FromDateOP DATETIME
DECLARE	@ToDateOP DATETIME
DECLARE @NoOfDaysOP DECIMAL(9,2) 
DECLARE	@AtATimeOP INT 
DECLARE	@MaxLeavesOP INT 
DECLARE @PrevEmpNodeAvlbl INT
DECLARE @PrevLeaveTypeAvlbl INT
DECLARE @DaysAvlblTable DECIMAL(9,2)

SET @PrevEmpNodeAvlbl=0
SET @PrevLeaveTypeAvlbl=0
SET @StartDate=DATEADD(M,DATEDIFF(m,0,@PayrollMonth),0)
SET @I=1
SELECT @RCount=COUNT(*) FROM @TAB


	WHILE(@I<=@RCount)
	BEGIN
		SELECT @EmpNode=EMPNODE,@LeaveType=LEAVETYPENODE,@Days=ISNULL(DAYS,0),@EmpName=EMPNAME,@LeaveTypeName=LEAVETYPENAME FROM @TAB WHERE ID=@I
			IF (ISNULL(@PrevEmpNode,0)=0 )
			BEGIN
				SET @FDate=CONVERT(VARCHAR,@StartDate,106)
				SET @TDate=DATEADD(d,@Days,CONVERT(VARCHAR,@FDate,106))
				SET @PrevEmpNode=@EmpNode
				
			END
			ELSE IF @PrevEmpNode=@EmpNode
			BEGIN
				SET @ToDateOP=(SELECT TOP 1 TODATE FROM @TAB WHERE EMPNODE=@EmpNode AND ISNULL(TODATE,'')<>'' ORDER BY ID DESC)
				SET @FDate=DATEADD(d,1,CONVERT(VARCHAR,@ToDateOP,106)) 
				SET @TDate=DATEADD(d,@Days,CONVERT(VARCHAR,@FDate,106))
				
			END
			ELSE IF  @PrevEmpNode<>@EmpNode
			BEGIN
			SET @PrevEmpNode=@EmpNode
			SET @FDate=CONVERT(VARCHAR,@StartDate,106)
			SET @TDate=DATEADD(d,@Days,CONVERT(VARCHAR,@FDate,106))
			END
				--CHECKING AVIALABLE LEAVES
				Exec [spPAY_ExtGetAssignedLeavesOP]  @EmpNode,@LeaveType,@PayrollMonth,@UserId,@LangId,@AssignedLeavesOP output,@AvlblLeavesOP output,@FromDateOP output,@ToDateOP output
				--CHECKING NOOFDAYS CONDITION WITH AVAILABLE LEAVES	
					SET @PrevEmpNodeAvlbl=@EmpNode
					SET @PrevLeaveTypeAvlbl=@LeaveType
					IF (@PrevEmpNodeAvlbl=@EmpNode AND @PrevLeaveTypeAvlbl=@LeaveType)
					BEGIN
						 SELECT @DaysAvlblTable=SUM(ISNULL(AVLBLLEAVESREM,0)) FROM @TAB WHERE EMPNODE=@EmpNode AND LEAVETYPENODE=@LeaveType
						 SET @AvlblLeavesOP=@AvlblLeavesOP-@DaysAvlblTable
					END
					ELSE IF  (@PrevEmpNodeAvlbl<>@EmpNode  AND @PrevLeaveTypeAvlbl<>@LeaveType)
					BEGIN
						SET @PrevEmpNodeAvlbl=@EmpNode
						SET @PrevLeaveTypeAvlbl=@LeaveType
					END
				IF @Days<=@AvlblLeavesOP
				BEGIN
					SET @FromDateOP=''
					SET @ToDateOP=''
					Exec [spPAY_ExtGetNoofDaysop] @FDate,@TDate,@EmpNode,@LeaveType,'Both',@UserId,@LangId,@Days,@NoOfDaysOP output,@FromDateOP output,@ToDateOP output,@AtATimeOP output,@MaxLeavesOP output
					IF ISNULL(@Days,0)>ISNULL(@AtATimeOP,0)
					BEGIN
						UPDATE @TAB SET FROMDATE=@FromDateOP,TODATE=@ToDateOP,ATATIME=@AtATimeOP,MAXLEAVES=@MaxLeavesOP,ASSIGNEDLEAVES=@AssignedLeavesOP,AVLBLLEAVES=@AvlblLeavesOP,AVLBLLEAVESREM=@AvlblLeavesOP-@Days,REMARKS='Cannot apply leaves more than AtATime leaves (Employee: ' + CONVERT(VARCHAR,UPPER(@EmpName)) +' | Leavetype: ' + CONVERT(VARCHAR,UPPER(@LeaveTypeName)) +'  | AtATime: ' + CONVERT(VARCHAR,@AtATimeOP) +'  | Days: ' + CONVERT(VARCHAR,@Days) +')' WHERE EMPNODE=@EmpNode and LEAVETYPENODE=@LeaveType AND ID=@I
					END
					ELSE
					BEGIN
						UPDATE @TAB SET FROMDATE=@FromDateOP,TODATE=@ToDateOP,ATATIME=@AtATimeOP,MAXLEAVES=@MaxLeavesOP,ASSIGNEDLEAVES=@AssignedLeavesOP,AVLBLLEAVES=@AvlblLeavesOP,
						AVLBLLEAVESREM=@AvlblLeavesOP-@Days WHERE EMPNODE=@EmpNode and LEAVETYPENODE=@LeaveType AND ID=@I
					END
					
				END
				ELSE
				BEGIN
					SET @FromDateOP=''
					SET @ToDateOP=''
					Exec [spPAY_ExtGetNoofDaysop] @FDate,@TDate,@EmpNode,@LeaveType,'Both',@UserId,@LangId,@Days,@NoOfDaysOP output,@FromDateOP output,@ToDateOP output,@AtATimeOP output,@MaxLeavesOP output
					UPDATE @TAB SET FROMDATE=@FromDateOP,TODATE=@ToDateOP,AVLBLLEAVES=@AvlblLeavesOP,REMARKS='No leaves available for specified month (Employee: ' + CONVERT(VARCHAR,UPPER(@EmpName)) +' | Leavetype: ' + CONVERT(VARCHAR,UPPER(@LeaveTypeName)) +')'  WHERE EMPNODE=@EmpNode and LEAVETYPENODE=@LeaveType AND ID=@I
				END
		
	SET @I=@I+1
	END

--SELECT * FROM @TAB




--Generate Xml for apply leave
DECLARE @strQuery varchar(max)
DECLARE @strResult VARCHAR(100)
DECLARE @ICOUNT INT
DECLARE @TRCOUNT INT
DECLARE @REMARKCOUNT INT
DECLARE @dcAlpha1 VARCHAR(10)
DECLARE @dcAlpha2 VARCHAR(10)
DECLARE @dcAlpha3 VARCHAR(10)
DECLARE @dcAlpha4 DATETIME
DECLARE @dcAlpha5 DATETIME
DECLARE @dcAlpha6 VARCHAR(10)
DECLARE @dcAlpha7 VARCHAR(10)
DECLARE @dcAlpha8 VARCHAR(10)
DECLARE @dcAlpha9 VARCHAR(10)
DECLARE @dcCCNID51 INT
DECLARE @dcCCNID52 INT
DECLARE @INVDOCDETAILSID INT
DECLARE @INVDOCDETAILSIDNEW INT
DECLARE @RMKS VARCHAR(200)=''
SELECT @TRCOUNT=COUNT(*) FROM @TAB
SELECT @REMARKCOUNT=COUNT(*)  FROM @TAB  WHERE ISNULL(REMARKS,'')<>''
--PRINT @REMARKCOUNT
SET @ICOUNT=1
set @strQuery=''
IF ISNULL(@REMARKCOUNT,0)=0
BEGIN
	WHILE(@ICOUNT<=@TRCOUNT)
	BEGIN
			SET @dcAlpha1=''
			SET @dcAlpha2=''
			SET @dcAlpha3=''
			SET @dcAlpha4=''
			SET @dcAlpha5=''
			SET @dcAlpha6=''
			SET @dcAlpha7=''
			SET @dcAlpha8=''
			SET @dcAlpha9=''
			SET @INVDOCDETAILSID=0
			
			SELECT @dcAlpha1=null,@dcAlpha2=ASSIGNEDLEAVES,@dcAlpha3=AVLBLLEAVES,@dcAlpha4=FROMDATE,@dcAlpha5=TODATE,@dcAlpha6=SESSION,@dcAlpha7=DAYS,
			@dcAlpha8=ATATIME,@dcAlpha9=MAXLEAVES,@dcCCNID51=EMPNODE,@dcCCNID52=LEAVETYPENODE,@INVDOCDETAILSID=INVDOCDETAILSID FROM @TAB  WHERE ID=@ICOUNT
			
			set @strQuery=''
			set @strQuery='<Row>'
			set @strQuery=@strQuery+'<AccountsXML></AccountsXML>'
			set @strQuery=@strQuery+'<Transactions DocSeqNo="1"  DocDetailsID="0" LinkedInvDocDetailsID="0" LinkedFieldName="" LineNarration="" ProductID="2" IsScheme="" Quantity="1" Unit="1" UOMConversion="1" UOMConvertedQty="1" Rate="0" Gross="" RefNO=""  IsQtyIgnored="1" AverageRate="0" StockValue="0" StockValueFC="0" CurrencyID="1" ExchangeRate="1.0"   DebitAccount="2"  CreditAccount="2"> </Transactions>'
			set @strQuery=@strQuery+'<Numeric Query="" ></Numeric>'
			set @strQuery=@strQuery+'<Alpha Query="dcAlpha2=N'''+ @dcAlpha2  +''','
			set @strQuery=@strQuery+' dcAlpha3=N'''+ @dcAlpha3  +''','
			set @strQuery=@strQuery+' dcAlpha4=N'''+ CONVERT(VARCHAR,@dcAlpha4) +''','
			set @strQuery=@strQuery+' dcAlpha5=N'''+ CONVERT(VARCHAR,@dcAlpha5) +''','
			set @strQuery=@strQuery+' dcAlpha6=N'''+ @dcAlpha6  +''','
			set @strQuery=@strQuery+' dcAlpha7=N'''+ @dcAlpha7  +''','
			set @strQuery=@strQuery+' dcAlpha8=N'''+ @dcAlpha8  +''','
			set @strQuery=@strQuery+' dcAlpha9=N'''+ @dcAlpha9  +''', "></Alpha>'
			
			set @strQuery=@strQuery+'<CostCenters Query="dcCCNID52='+ CONVERT(VARCHAR,@dcCCNID52) +','
			set @strQuery=@strQuery+' dcCCNID51='+ CONVERT(VARCHAR,@dcCCNID51) +', " ></CostCenters>'									
			set @strQuery=@strQuery+'<EXTRAXML></EXTRAXML></Row>'									
			PRINT 	(@strQuery)

			set @strResult=''
			EXEC @strResult=spDOC_SetTempInvDoc 40062,0,'','',@PayrollMonth,'','',@strQuery ,'','','','','false',0,0,0,1,'',0,0,'admin','admin',1,1,False
			if(ISNULL(@strResult,'')<>'')
			begin
				SELECT @INVDOCDETAILSIDNEW=INVDOCDETAILSID FROM INV_DOCDETAILS WHERE DOCID=CONVERT(INT,@strResult)
				UPDATE INV_DOCDETAILS SET LinkedInvDocDetailsID=@INVDOCDETAILSIDNEW WHERE INVDOCDETAILSID=@INVDOCDETAILSID
				
				--EXEC spPAY_UpdateAssignLeavesConsumed @PayrollMonth
				EXEC spPAY_UpdateAssignLeavesDatewise @PayrollMonth,@INVDOCDETAILSIDNEW,0
				SELECT @strResult +' Saved Successfully' AS ErrorMessage
			end
		
	SET @ICOUNT=@ICOUNT+1	
	END
	UPDATE INV_DOCDETAILS SET STATUSID=369 WHERE DOCID=@DocID
END
ELSE
BEGIN
	SET @strResult='No Leaves updated for employee from consolidated leaves list'
	UPDATE INV_DOCDETAILS SET STATUSID=448 WHERE DOCID=@DocID
	SELECT @strResult AS ErrorMessage
END
--




SET NOCOUNT OFF;
END
GO
