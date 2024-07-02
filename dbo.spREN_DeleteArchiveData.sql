USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_DeleteArchiveData]
	@ArchDBName [nvarchar](50),
	@featureid [int],
	@DtChar [nvarchar](20),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY
--SET NOCOUNT ON;    

	DECLARE @sql nvarchar(max)

	IF (@featureid=93)
	BEGIN
		set @sql='USE '+@ArchDBName+'
		Delete from REN_UnitsHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
		Delete from REN_UnitsExtendedHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar
		exec(@sql)
	END
	ELSE IF (@featureid=94)
	BEGIN
		set @sql='USE '+@ArchDBName+'
		Delete from REN_TenantHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
		Delete from REN_TenantExtendedHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar
		exec(@sql)
	END
	ELSE IF (@featureid=95)
	BEGIN
		set @sql='USE '+@ArchDBName+'
		Delete from REN_Contract_History where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
		Delete from REN_ContractExtended_History where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
		Delete from REN_ContractParticulars_History where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
		Delete from REN_ContractPayTerms_History where isnull(ModifiedDate, CreatedDate)<'+@DtChar
		exec(@sql)
	END

COMMIT TRANSACTION
--ROLLBACK TRANSACTION

SET NOCOUNT OFF; 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END	
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
