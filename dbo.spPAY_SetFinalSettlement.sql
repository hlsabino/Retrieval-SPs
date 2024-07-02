USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_SetFinalSettlement]
	@DocNo [int] = NULL,
	@DocDate [datetime] = NULL,
	@EmpSeqNo [int] = NULL,
	@CalcDOR [datetime] = NULL,
	@Remarks [nvarchar](max) = NULL,
	@GraAmt [float],
	@AvailGraAmt [float],
	@CumLeaveSalBalAmt [float],
	@LEAmt [float],
	@UPSAmt [float],
	@NPAmt [float],
	@OthAddAmt [float],
	@OthDedAmt [float],
	@TotLoanBalAmt [float],
	@TotAmt [float],
	@CalcXML [nvarchar](max),
	@CreatedBy [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
Begin Try

DECLARE @XML xml,@iUser nvarchar(50),@CDate float
SET @XML=@CalcXML

IF (@DocNo>0)
BEGIN
	Select @iUser=CreatedBy,@CDate=CreatedDate From PAY_FinalSettlement WITH(NOLOCK) WHERE DocNo=@DocNo 
	DELETE FROM PAY_FinalSettlement WHERE DocNo=@DocNo
END
ELSE
BEGIN
	SET @iUser=@CreatedBy 
	SET @CDate=CONVERT(FLOAT,GetDate())
	Select @DocNo=ISNULL(MAX(ISNULL(DocNo,0)),0)+1 FROM PAY_FinalSettlement WITH(NOLOCK)
END

INSERT INTO PAY_FinalSettlement(DocNo, DocDate, EmpSeqNo,CalcDOR,Remarks, TotGratuityAmt,TotGratuityAvailedAmt,CumLeaveSalBalAmt,TotLeaveEncashAmt, TotUnPaidSalAmt, TotNoticePayAmt, TotOthAddAmt, TotOthDedAmt,TotLoanBalAmt, GrandTotalAmt, 
							DType,SubDType, Field1, Field2, Field3, Field4, Field5, Field6, Field7, Field8, Field9, Field10, Field11, Field12, Field13, Field14, Field15, Field16, Field17, Field18, Field19, 
							Field20, Field21, Field22, Field23, Field24, Field25,Field26,Field27,Field28,Field29,Field30, 
							CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)

SELECT @DocNo,@DocDate,@EmpSeqNo,@CalcDOR,@Remarks,@GraAmt,@AvailGraAmt,@CumLeaveSalBalAmt,@LEAmt,@UPSAmt,@NPAmt,@OthAddAmt,@OthDedAmt,@TotLoanBalAmt,@TotAmt,
ISNULL(A.value('@DType','INT'),0),ISNULL(A.value('@SubDType','INT'),0),
ISNULL(A.value('@Field1','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field2','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field3','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field4','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field5','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field6','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field7','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field8','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field9','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field10','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field11','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field12','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field13','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field14','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field15','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field16','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field17','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field18','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field19','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field20','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field21','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field22','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field23','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field24','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field25','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field26','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field27','NVARCHAR(MAX)'),NULL),
ISNULL(A.value('@Field28','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field29','NVARCHAR(MAX)'),NULL),ISNULL(A.value('@Field30','NVARCHAR(MAX)'),NULL),
@iUser,@CDate,@CreatedBy,CONVERT(FLOAT,GETDATE()) from @XML.nodes('Rows/Row') as Data(A)

COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SELECT  @DocNo
End Try
Begin Catch
	SELECT  -12345
	SELECT ERROR_MESSAGE() AS ErrorMessage
	ROLLBACK transaction
End Catch
GO
