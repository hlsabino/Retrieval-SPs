USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_SetGradeWiseSalarySlabs]
	@GradeID [int] = NULL,
	@WEF [datetime] = NULL,
	@GSXML [nvarchar](max) = NULL,
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
Begin TRY

SET ARITHABORT ON

DECLARE @SeqNo INT,@SysDate FLOAT
SET @SysDate=CONVERT(FLOAT,GETDATE())
DECLARE @XML XML
SET @XML= @GSXML

IF EXISTS(SELECT GradeID FROM PAY_GradeWiseSalarySlabs WHERE GradeID=@GradeID and WEF=@WEF)
BEGIN
	DELETE FROM  PAY_GradeWiseSalarySlabs WHERE GradeID=@GradeID and WEF=@WEF
	
	INSERT INTO PAY_GradeWiseSalarySlabs(GradeID,WEF,SNo,ComponentID,MinAmount,MaxAmount,AlertType,ApplicableFormula,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
	SELECT @GradeID,@WEF,CONVERT(NVARCHAR,A.value('@SNo','INT')),CONVERT(NVARCHAR,A.value('@ComponentID','INT')),CONVERT(float,A.value('@MinAmount','float')),CONVERT(float,A.value('@MaxAmount','float')),CONVERT(NVARCHAR(MAX),A.value('@AlertType','nvarchar(max)')),CONVERT(NVARCHAR(MAX),A.value('@ApplicableFormula','nvarchar(max)')),@UserName,@SysDate,@UserName,@SysDate
	FROM @XML.nodes('/Rows/Row') as Data(A)
	
END
ELSE
BEGIN
	INSERT INTO PAY_GradeWiseSalarySlabs(GradeID,WEF,SNo,ComponentID,MinAmount,MaxAmount,AlertType,ApplicableFormula,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
	SELECT @GradeID,@WEF,CONVERT(NVARCHAR,A.value('@SNo','INT')),CONVERT(NVARCHAR,A.value('@ComponentID','INT')),CONVERT(float,A.value('@MinAmount','float')),CONVERT(float,A.value('@MaxAmount','float')),CONVERT(NVARCHAR(MAX),A.value('@AlertType','nvarchar(max)')),CONVERT(NVARCHAR(MAX),A.value('@ApplicableFormula','nvarchar(max)')),@UserName,@SysDate,@UserName,@SysDate
	FROM @XML.nodes('/Rows/Row') as Data(A)
END

IF @@ERROR<>0 BEGIN ROLLBACK TRANSACTION RETURN -102 END
set @SeqNo=SCOPE_IDENTITY() 

COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SELECT  @SeqNo
End TRY
Begin Catch
	SELECT  -12345
	SELECT ERROR_MESSAGE() AS ErrorMessage
	ROLLBACK transaction
End Catch
GO
