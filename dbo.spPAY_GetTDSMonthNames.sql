USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetTDSMonthNames]
	@EmpSeqNo [int],
	@Year [int],
	@FromMonth [datetime]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @TDSCompID INT,@TDSSNo INT,@TDSAmt FLOAT,@iQ INT,@iQNo INT
DECLARE @PayMonth DATETIME,@ToMonth DATETIME,@dtmp DATETIME
DECLARE @sQ NVARCHAR(MAX)
DECLARE @SurChr FLOAT,@EduCess FLOAT,@SecEduCess FLOAT
DECLARE @TDS FLOAT,@SurChrAmt FLOAT,@EduCessAmt FLOAT,@SecEduCessAmt FLOAT,@QSum FLOAT

DECLARE @TABMONTHQUARTER TABLE(ID INT IDENTITY(1,1),TDSTYPE VARCHAR(10),MONTHTEXT VARCHAR(15),NODEID VARCHAR(5),YEARNO INT,
							   QUARTERNO INT,PAYROLLDATE DATETIME,AMOUNT DECIMAL(9,2),TDS DECIMAL(9,2),SURCHARGE DECIMAL(9,2),
							   EDUCATIONCESS DECIMAL(9,2),SECANDHIGHEDUCESS DECIMAL(9,2))

DECLARE @TDSMon TABLE (PayrollDate DATETIME,TDSAmt FLOAT)

--SET @EmpSeqNo=640
--SET @Year=2019

SET @ToMonth=DATEADD(month,11,@FromMonth)
--SELECT @FromMonth,@ToMonth

SET @SurChr=0 SET @EduCess=0 SET @SecEduCess=0

SELECT @SurChr=CONVERT(FLOAT,ISNULL(d.dcAlpha3,0)),@EduCess=CONVERT(FLOAT,ISNULL(d.dcAlpha4,0)),@SecEduCess=CONVERT(FLOAT,ISNULL(d.dcAlpha5,0))
FROM INV_DocDetails a WITH(NOLOCK) 
JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
WHERE d.tCostCenterID=40074 and a.StatusID=369 AND CONVERT(INT,d.dcAlpha1)=2019 
--SELECT @SurChr,@EduCess,@SecEduCess

SELECT @PayMonth=CONVERT(DATETIME,MAX(PayrollDate)) FROM COM_CC50054 WITH(NOLOCK) WHERE CONVERT(DATETIME,PayrollDate)<=@FromMonth

SELECT @TDSCompID=ComponentID,@TDSSNo=SNo FROM COM_CC50054 WITH(NOLOCK) WHERE GradeID=1 AND Type=2 AND CONVERT(DATETIME,PayrollDate)=@PayMonth AND TaxMap=(SELECT NodeID FROM COM_CC50052 WITH(NOLOCK) WHERE NAME='IT_TDS')
--SELECT @TDSCompID,@TDSSNo
SET @sQ=''
SET @sQ='	SELECT CONVERT(DATETIME,a.DueDate),c.dcCalcNum'+CONVERT(NVARCHAR,@TDSSNo) + ' 
				FROM INV_DocDetails a WITH(NOLOCK) 
				JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
				JOIN PAY_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
				WHERE a.CostCenterID=40054 and a.StatusID=369 AND a.VoucherType=12 
				AND b.dcCCNID51='+CONVERT(NVARCHAR,@EmpSeqNo)+' AND CONVERT(DATETIME,a.DueDate) BETWEEN '''+CONVERT(NVARCHAR,@FromMonth)+''' AND '''+CONVERT(NVARCHAR,@ToMonth)+''' 
				ORDER BY a.DueDate '

	INSERT INTO @TDSMon
	EXEC sp_executesql @sQ

--SELECT * FROM @TDSMon

SET @iQ=0
SET @iQNo=1
SET @dtmp=@FromMonth
WHILE(@dtmp<=@ToMonth)
BEGIN
	IF(@iQ=3)
	BEGIN
		SET @iQ=0
		SET @iQNo=@iQNo+1
	END
	SET @TDSAmt=0
	SET @TDS=0 SET @SurChrAmt=0 SET @EduCessAmt=0 SET @SecEduCessAmt=0

	SELECT @TDSAmt=ISNULL(TDSAmt,0) FROM @TDSMon WHERE PayrollDate=@dtmp
	IF(@TDSAmt>0)
	BEGIN
		SET @TDS=Round(((100 * @TDSAmt) / (100 + @SurChr + @EduCess + @SecEduCess)),2,1);
		
		IF(@SurChr>0)
			SET @SurChrAmt=Round(((@TDS * @SurChr) / 100),2,1);

		IF(@EduCess>0)
			SET @EduCessAmt=Round(((@TDS * @EduCess) / 100),2,1);

		IF(@SecEduCess>0)
			SET @SecEduCessAmt=Round(((@TDS * @SecEduCess) / 100),2,1);

	END
	
	INSERT INTO @TABMONTHQUARTER
	SELECT 'Monthly',MONTH(@dtmp),MONTH(@dtmp),YEAR(@dtmp),@iQNo,@dtmp,@TDSAmt,@TDS,@SurChrAmt,@EduCessAmt,@SecEduCessAmt

	SET @iQ=@iQ+1
SET @dtmp=DATEADD(month,1,@dtmp)
END

SET @iQ=1
WHILE(@iQ<=4)
BEGIN
	SET @QSum=0
	SELECT @QSum=SUM(ISNULL(Amount,0)) FROM @TABMONTHQUARTER WHERE QuarterNo=@iQ

	INSERT INTO @TABMONTHQUARTER
	SELECT 'Quarterly','Quarter'+convert(nvarchar,@iQ),convert(nvarchar,@iQ),@Year,0,NULL,@QSum,0,0,0,0

SET @iQ=@iQ+1
END

SELECT * FROM @TABMONTHQUARTER
GO
