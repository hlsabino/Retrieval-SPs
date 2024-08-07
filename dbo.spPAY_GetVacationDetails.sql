﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetVacationDetails]
	@EmpNode [int],
	@DocDate [datetime],
	@FromDate [datetime],
	@UserID [int] = 1,
	@LANGID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;
DECLARE @GRADE INT,@GRADEWISEVACATIONPREF VARCHAR(5),@PayrollDate DATETIME,@DOConfirmation DATETIME,@OPLeavesAsOn DATETIME,@CalcCreditFromDOJ nvarchar(10)

--SET TO FIRST DAY FOR THE GIVEN DATE
SET @PayrollDate=DATEADD(MONTH,DATEDIFF(MONTH,0,CONVERT(DATETIME,@DocDate)),0)

--TABLE0
--CHECKING THE VACATION DAYS, VACATION PERIOD OF EMPLOYEE	
IF ((SELECT COUNT(NodeID) FROM COM_CC50051 WITH(NOLOCK) where NodeID=@EmpNode and isnull(VacDaysPerMonth,0)>0)<=0)
	SELECT 'Please assign vacation days for employee' as VacationdaysMessage
ELSE
	SELECT VacationPeriod,isnull(VacDaysPerMonth,0) as VacDaysPerMonth,VacDaysPeriod,'' as VacationdaysMessage FROM COM_CC50051 WITH(NOLOCK) where NodeID=@EmpNode and isnull(VacDaysPerMonth,0)>0

--TABLE1
--START: CHECKING GRADE WISE PREFERENCES IN VACATION MANAGEMENT
SELECT @GradewiseVacationPref=ISNULL(VALUE,'False') FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='GradeWiseVacation'
IF (@GRADEWISEVACATIONPREF='True')
BEGIN
	IF((SELECT COUNT(CostCenterID) FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=50051 and SysColumnName ='CCNID53' and IsColumnInUse=1 and UserProbableValues='H')>0)
		SELECT @GRADE=ISNULL(HistoryNodeID,0) FROM COM_HistoryDetails WITH(NOLOCK) WHERE NodeID=@EmpNode AND CostCenterID=50051 AND HistoryCCID=50053 AND (FromDate<=CONVERT(FLOAT,CONVERT(DATETIME,@PayrollDate))) AND (ToDate>=CONVERT(FLOAT,CONVERT(DATETIME,@PayrollDate)) OR ToDate IS NULL)
	ELSE
		SELECT @GRADE=ISNULL(CCNID53,0) FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=50051 AND NODEID=@EmpNode
END

IF ISNULL(@GRADE,0)=0
	SET @GRADE=1
	
IF ((SELECT COUNT(ID.DocID) FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID 
WHERE  CC.DCCCNID53=@GRADE AND ID.COSTCENTERID=40061 AND ID.StatusID=369 )<=0)
	SELECT 'Please check the vacation preferences for the grade' as VacationPreferencesMessage
ELSE
	SELECT distinct ISNULL(TD.dcAlpha1,'0') VacationField,'' as VacationPreferencesMessage FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID WHERE CC.DCCCNID53=@GRADE AND ID.COSTCENTERID=40061 AND ID.StatusID=369	
--END: CHECKING GRADE WISE PREFERENCES IN VACATION MANAGEMENT

--TABLE2
--START: CHECKING THE REJOINING DATE 
IF ((SELECT count(ID.DocID)  FROM INV_DOCDETAILS ID WITH(NOLOCK) 
JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID 
JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID 
WHERE  TD.tCOSTCENTERID=40072 AND ID.StatusID=369 AND CC.DCCCNID51=@EmpNode 
	        AND isnull(TD.DCALPHA16,'')='No' AND ISNULL(TD.DCALPHA2,'')<>'' AND ISNULL(TD.DCALPHA3,'')<>'' AND ISNULL(TD.DCALPHA1,'')=''
			AND CONVERT(DATETIME,TD.DCALPHA3)<CONVERT(DATETIME,@FromDate))>0)
	SELECT 'Please enter the Re-join date for the last vacation' as VacationMessage
ELSE
    SELECT '' as VacationMessage
--END: CHECKING THE REJOINING DATE

--START: LOADING VACATION MANAGEMENT PAYROLL EARNING COMPONENTS 
--TABLE3
SELECT NODEID,NAME,NODEID as PARENTID,0 FROM COM_CC50052 WITH(NOLOCK) WHERE NODEID IN (2,3,4) AND ISGROUP=1

--TABLE4
DECLARE @TABCP TABLE(ID INT IDENTITY(1,1),NAME VARCHAR(100),NODEID INT,PARENTID INT,PERCENTAGE DECIMAL(9,2))

INSERT INTO @TABCP
	SELECT 'EMPLOYEE_BASIC' ,0,2 ,0
INSERT INTO @TABCP
	SELECT NAME ,PC.NODEID ,PARENTID,0 FROM COM_CC50052 PC WITH(NOLOCK),COM_CC50054 CP WITH(NOLOCK) ,INV_DOCDETAILS ID WITH(NOLOCK) 
	JOIN COM_DOCNUMDATA DN WITH(NOLOCK) ON ID.INVDOCDETAILSID=DN.INVDOCDETAILSID 
	JOIN COM_DOCTEXTDATA TD  WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID
	JOIN COM_DOCCCDATA CD  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CD.INVDOCDETAILSID
	WHERE  TD.tCOSTCENTERID=40061 AND ID.StatusID=369 AND PC.NODEID=CP.COMPONENTID --AND  ISNUMERIC(TD.DCALPHA17)=1 
	AND CP.COMPONENTID=TD.DCALPHA17 AND DN.DCNUM1<>0 AND CP.GRADEID=@GRADE AND NAME <> 'EMPLOYEE_BASIC' 
	AND CD.dcCCNID53=@GRADE
		   AND CP.PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GRADEID=@GRADE) ORDER BY PARENTID
INSERT INTO @TABCP
	SELECT A.NAME ,A.NODEID ,A.PARENTID,0 FROM COM_CC50052 A WITH(NOLOCK) JOIN COM_CC50054 B WITH(NOLOCK) ON A.NODEID=B.COMPONENTID WHERE A.PARENTID IN (3,4) and B.GRADEID=@Grade  
	       AND A.NAME <> 'EMPLOYEE_BASIC' AND B.PAYROLLDATE=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) AND GRADEID=@GRADE ) ORDER BY A.PARENTID
	       
SELECT * FROM @TABCP
--END: LOADING VACATION MANAGEMENT PAYROLL EARNING COMPONENTS 

--TABLE5
SELECT @OPLeavesAsOn=CONVERT(DateTime,OPLeavesAsOn) FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmpNode

SELECT @CalcCreditFromDOJ=ISNULL(TD.DCALPHA23,'No')
	FROM   INV_DOCDETAILS ID WITH(NOLOCK) 
	JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID 
	JOIN COM_DOCCCDATA CC WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
	WHERE  TD.tCostCenterID=40061 AND CC.DCCCNID53=@Grade


--START:CHECKING FOR VACATION APPLIED DAYS AND RETURN FROM VACATION
DECLARE @OPVACATIONDAYS FLOAT,@OPVACATIONSALARY FLOAT,@decVal FLOAT
IF ((SELECT count(ID.DocID)  FROM INV_DOCDETAILS ID WITH(NOLOCK) 
JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID 
JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
	 WHERE  TD.tCOSTCENTERID=40072 AND ID.StatusID=369 AND CC.DCCCNID51=@EmpNode AND isnull(TD.DCALPHA16,'')='No' AND ISNULL(TD.DCALPHA2,'')<>'' AND ISNULL(TD.DCALPHA3,'')<>'' AND ISNULL(TD.DCALPHA1,'')<>'' AND CONVERT(DATETIME,TD.DCALPHA3)<CONVERT(DATETIME,@FromDate))>0 AND @CalcCreditFromDOJ='No')
BEGIN
	IF(CONVERT(DATETIME,@OPLeavesAsOn)>=(SELECT TOP 1 CONVERT(DATETIME,TD.DCALPHA1) FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
	WHERE  TD.tCOSTCENTERID=40072 AND ID.StatusID=369 AND CC.DCCCNID51=@EmpNode AND ISDATE(TD.DCALPHA1)=1 AND ISDATE(DCALPHA3)=1 AND ISNULL(TD.DCALPHA2,'')<>'' AND ISNULL(TD.DCALPHA3,'')<>'' AND ISNULL(TD.DCALPHA1,'')<>'' AND CONVERT(DATETIME,TD.DCALPHA3)<CONVERT(DATETIME,@FromDate) ORDER BY  CONVERT(DATETIME,ISNULL(dcAlpha1,'')) desc))
	BEGIN
		SELECT @OPVACATIONDAYS=ISNULL(OPVACATIONDAYS,0),@OPVACATIONSALARY=ISNULL(OPVACATIONSALARY,0) FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmpNode
	END
	ELSE
	BEGIN
		SELECT TOP 1 @OPVACATIONDAYS= CASE WHEN isnull((convert(Float,dcAlpha11)),0) >0 THEN CASE WHEN ISNULL(convert(Float,dcAlpha12),0)>0 THEN ISNULL(dcAlpha12,0) ELSE -1*isnull((convert(Float,dcAlpha11)),0) END
		ELSE ISNULL(dcAlpha12,0) end ,@OPVACATIONSALARY=0 FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
		WHERE  TD.tCOSTCENTERID=40072 AND ID.StatusID=369  AND CC.DCCCNID51=@EmpNode 
		AND ISNUMERIC(dcAlpha11)=1 AND ISNUMERIC(dcAlpha12)=1
		AND ISDATE(TD.DCALPHA1)=1 AND ISDATE(DCALPHA3)=1 AND ISNULL(TD.DCALPHA2,'')<>'' AND ISNULL(TD.DCALPHA3,'')<>'' AND ISNULL(TD.DCALPHA1,'')<>'' AND CONVERT(DATETIME,TD.DCALPHA3)<CONVERT(DATETIME,@FromDate)  ORDER BY  CONVERT(DATETIME,ISNULL(dcAlpha1,'')) desc
	END
END
--CHECKING FOR VACATION APPLIED AS ENCASH
ELSE IF ((SELECT count(ID.DocID)  FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
		  WHERE  TD.tCOSTCENTERID=40072 AND ID.StatusID=369 AND CC.DCCCNID51=@EmpNode AND isnull(TD.DCALPHA16,'')='Yes' AND CONVERT(DATETIME,TD.DCALPHA3)<CONVERT(DATETIME,@FromDate))>0 AND @CalcCreditFromDOJ='No')
BEGIN
	IF(CONVERT(DATETIME,@OPLeavesAsOn)>=(SELECT TOP 1 CONVERT(DATETIME,TD.DCALPHA1) FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
	WHERE  TD.tCOSTCENTERID=40072 AND ID.StatusID=369 AND CC.DCCCNID51=@EmpNode AND ISDATE(TD.DCALPHA1)=1 AND ISDATE(DCALPHA3)=1 AND isnull(TD.DCALPHA16,'')='Yes'  AND CONVERT(DATETIME,TD.DCALPHA3)<CONVERT(DATETIME,@FromDate) ORDER BY  CONVERT(DATETIME,ISNULL(dcalpha3,'')) desc))
	BEGIN
		SELECT @OPVACATIONDAYS=ISNULL(OPVACATIONDAYS,0),@OPVACATIONSALARY=ISNULL(OPVACATIONSALARY,0) FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmpNode
	END
	ELSE
	BEGIN
		SELECT TOP 1 @OPVACATIONDAYS= CASE WHEN isnull((convert(Float,dcAlpha11)),0) >0 THEN CASE WHEN ISNULL(convert(Float,dcAlpha12),0)>0 THEN ISNULL(dcAlpha12,0) ELSE -1*isnull((convert(Float,dcAlpha11)),0) END
		else isnull((convert(Float,dcAlpha12)),0) end ,@OPVACATIONSALARY=0 FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID
		WHERE  TD.tCOSTCENTERID=40072 AND ID.StatusID=369 AND CC.DCCCNID51=@EmpNode 
		AND ISNUMERIC(dcAlpha11)=1 AND ISNUMERIC(dcAlpha12)=1
		AND ISDATE(TD.DCALPHA1)=1 AND ISDATE(DCALPHA3)=1 AND isnull(TD.DCALPHA16,'')='Yes' AND CONVERT(DATETIME,TD.DCALPHA3)<CONVERT(DATETIME,@FromDate)  ORDER BY  CONVERT(DATETIME,ISNULL(dcalpha3,'')) desc--convert(float,isnull(dcAlpha12,0)) asc--ORDER BY CONVERT(DATETIME,ID.DOCDATE) DESC
	END
END
ELSE
BEGIN
	SELECT @OPVACATIONDAYS=ISNULL(OPVACATIONDAYS,0),@OPVACATIONSALARY=ISNULL(OPVACATIONSALARY,0) FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmpNode
END	 
	--ROUNDUP FOR TOTALCREDITDAYS
	/*
   	IF(ISNULL(@OPVACATIONDAYS,0)>0)
	BEGIN
		SET @decVal = 0
		SET @decVal=@OPVACATIONDAYS-CONVERT(INT,@OPVACATIONDAYS)
		IF(@decVal>=.50)
			SET @OPVACATIONDAYS=CONVERT(INT,@OPVACATIONDAYS)+.50
		ELSE
   			SET @OPVACATIONDAYS=CONVERT(INT,@OPVACATIONDAYS)
	END
	*/

	SELECT @OPVACATIONDAYS AS OPVACATIONDAYS,@OPVACATIONSALARY AS OPVACATIONSALARY,ISNULL(@CalcCreditFromDOJ,'No') AS CalcCreditFromDOJ
--END:CHECKING FOR VACATION APPLIED DAYS AND RETURN FROM VACATION
--TABLE6
SELECT Convert(DateTime,DOConfirmation) ConfirmationDate FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID=@EmpNode

--7
--START: CHECKING FOR UNAPPROVED/APPROVED DOCS
IF ((SELECT count(ID.DocID)  FROM INV_DOCDETAILS ID WITH(NOLOCK) JOIN COM_DOCTEXTDATA TD WITH(NOLOCK) ON ID.INVDOCDETAILSID=TD.INVDOCDETAILSID JOIN COM_DOCCCDATA CC  WITH(NOLOCK) 
ON ID.INVDOCDETAILSID=CC.INVDOCDETAILSID WHERE  CC.DCCCNID51=@EmpNode
 AND TD.tCOSTCENTERID=40072 AND ID.StatusID IN (371,441)
	        AND isnull(TD.DCALPHA16,'')='No' AND ISNULL(TD.DCALPHA2,'')<>'' AND ISNULL(TD.DCALPHA3,'')<>'' AND ISNULL(TD.DCALPHA1,'')='' AND CONVERT(DATETIME,TD.DCALPHA3)<CONVERT(DATETIME,@FromDate))>0)
	SELECT 'Employee has already applied for the vacation is under approval process, you can not apply another' as VacationUnderApprovalMessage
ELSE
    SELECT '' as VacationUnderApprovalMessage
--END: CHECKING FOR UNAPPROVED/APPROVED DOCS


SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH    
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
