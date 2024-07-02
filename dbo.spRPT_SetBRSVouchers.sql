USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_SetBRSVouchers]
	@SaveXML [nvarchar](max),
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

		DECLARE @SQL NVARCHAR(MAX),@XML XML

		SET @XML=@SaveXML


--		SELECT D.AccDocDetailsID,D.VoucherNo,CONVERT(DATETIME,DocDate) Date,A.AccountName Account,
--			D.ChequeNumber ChequeNo,NULL Dr,D.Amount Cr,
--			D.BRS_Status,CONVERT(DATETIME,ClearanceDate) ClearanceDate
--		FROM ACC_DocDetails D WITH(NOLOCK)
--		LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=D.CreditAccount
--		WHERE D.DebitAccount=@BankAccountID AND 
--			CONVERT(DATETIME,D.DocDate) BETWEEN @FromDate AND @ToDate
		
		UPDATE ACC_DocDetails
		SET BRS_Status=X.value('@Status','int'),
			ClearanceDate=CONVERT(FLOAT,X.value('@Date','DATETIME'))
		FROM ACC_DocDetails D 
		INNER JOIN @XML.nodes('/XML/Row') as Data(X)
		ON D.AccDocDetailsID=X.value('@ID','bigint')

	
COMMIT TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
