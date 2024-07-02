USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetBillwiseData]
	@AccountID [bigint] = 0,
	@IsCredit [bit],
	@VoucherNo [nvarchar](500),
	@DocSeqNo [int],
	@LocationWhere [nvarchar](max),
	@DivisionWhere [nvarchar](max),
	@DimensionWhere [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY 
   
   select * from com_billwise WITH(NOLOCK) where Accountid=@AccountID and docno=@VoucherNo
  
 SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	
	select * from COM_Billwise WITH(NOLOCK) where AccountID=@AccountID and DocNo=@VoucherNo and DocSeqNo=@DocSeqNo


	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH


GO
