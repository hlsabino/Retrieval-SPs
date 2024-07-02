USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDocumentIDByName]
	@Name [nvarchar](100),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		 
		 select * from adm_documenttypes where documentname =@Name
		 
		 select costcentercolid,usercolumnname, syscolumnname from adm_costcenterdef where costcenterid in
		 (select costcenterid from adm_documenttypes where documentname =@Name) and 
		 syscolumnname like 'dcNum%' and iscolumninuse=1


COMMIT TRANSACTION 
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
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH




GO
