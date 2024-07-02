USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetAssetClassDetails]
	@AssetClassID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

		 
		--Getting data from Accounts main table
	SELECT a.AssetClassID, a.AssetClassCode, a.AssetClassName, isnull(a.Description,'') as Description,
	 a.StatusID, s.Status , a.GUID,a.FAAccountsID,a.DeprBookID,a.DeprPosting,a.TotalYears
	FROM  ACC_AssetClass a INNER JOIN COM_Status AS s ON a.StatusID = s.StatusID
	WHERE AssetClassID=@AssetClassID
		
 
	 
COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN @AssetClassID
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
