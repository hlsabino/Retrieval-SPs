USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportDataToAccLocDivLimits]
	@DATAXML [nvarchar](max),
	@AccountName [nvarchar](max) = null,
	@AccountCode [nvarchar](max) = null,
	@IsCode [bit] = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section  
	DECLARE @XML XML,@AccountID BIGINT

	IF (@DATAXML IS NOT NULL AND @DATAXML <> '')
	BEGIN 
		SET @XML=@DATAXML  
		IF(@IsCode=1)
			SELECT @AccountID=AccountID FROM ACC_Accounts with(nolock) WHERE AccountCode=@AccountCode
		ELSE
			SELECT @AccountID=AccountID FROM ACC_Accounts with(nolock) WHERE AccountName=@AccountName
		 
		insert into Acc_CreditDebitAmount(AccountID,LocationID,DivisionID,CreditAmount,DebitAmount,CreditDays,DebitDays,Guid,CreatedBy,CreatedDate,DimensionID,CurrencyID)
		select @AccountID,X.value('@LocationID','bigint'),X.value('@DivisionID','bigint'),X.value('@Credit','float'),X.value('@Debit','float')
		,X.value('@CreditDays','bigint'),X.value('@DebitDays','bigint'),newid(),CONVERT(FLOAT,GETDATE()),@UserID,X.value('@DimensionID','bigint'),X.value('@CurrencyID','bigint')
		FROM @XML.nodes('/XML/Row') as Data(X) 	 	  
	END

COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;  
RETURN @AccountID
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
