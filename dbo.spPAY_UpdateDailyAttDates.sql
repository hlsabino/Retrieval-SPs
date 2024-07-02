USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_UpdateDailyAttDates]
	@DOCID [int],
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN 

DECLARE @I INT,@CNT INT,@VoucherNo NVARCHAR(600),@DocSeqNo NVARCHAR(500),@DailyAttDate NVARCHAR(100),@UpdStartDate NVARCHAR(500),@UpdEndTime NVARCHAR(500)
CREATE TABLE #TABEMP(ID INT IDENTITY(1,1),VoucherNo NVARCHAR(600),DocSeqNo NVARCHAR(500),DailyAttDate NVARCHAR(100),UpdStartDate NVARCHAR(500),UpdEndTime NVARCHAR(500),IsUpdate NVARCHAR(100))	

INSERT INTO #TABEMP
SELECT T.DCALPHA1,T.DCALPHA2,T.DCALPHA3,T.DCALPHA8,T.DCALPHA9,T.DCALPHA12 FROM INV_DocDetails I WITH(NOLOCK)
JOIN COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=I.InvDocDetailsID
JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
WHERE DOCID=@DOCID AND STATUSID=369 AND T.DCALPHA12='True' AND T.dcAlpha13<>'Absent'

SELECT @CNT=COUNT(*) FROM #TABEMP
SET @I=1
WHILE(@I<=@CNT)
BEGIN
SELECT @VoucherNo=VoucherNo,@DocSeqNo=DocSeqNo,@DailyAttDate=DailyAttDate,@UpdStartDate=UpdStartDate,@UpdEndTime=UpdEndTime FROM #TABEMP WHERE ID=@I 

if(SELECT COUNT(*) FROM INV_DocDetails I
JOIN COM_DocTextData T ON T.InvDocDetailsID=I.InvDocDetailsID
WHERE DocumentType=67 AND I.VoucherNo=@VoucherNo AND I.DocSeqNo=@DocSeqNo AND ISNULL(dcAlpha16,'')='' AND ISNULL(dcAlpha17,'')='')>0
BEGIN
UPDATE T SET dcAlpha16=dcAlpha2,dcAlpha17=dcAlpha3 FROM INV_DocDetails I
JOIN COM_DocTextData T ON T.InvDocDetailsID=I.InvDocDetailsID
WHERE DocumentType=67 AND I.VoucherNo=@VoucherNo AND I.DocSeqNo=@DocSeqNo
END

UPDATE T SET dcAlpha2=@UpdStartDate,dcAlpha3=@UpdEndTime FROM INV_DocDetails I
JOIN COM_DocTextData T ON T.InvDocDetailsID=I.InvDocDetailsID
WHERE DocumentType=67 AND I.VoucherNo=@VoucherNo AND I.DocSeqNo=@DocSeqNo

SET @I=@I+1
END


DROP TABLE #TABEMP
END

----spPAY_UpdateDailyAttDates
--28897,
--1,1
GO
