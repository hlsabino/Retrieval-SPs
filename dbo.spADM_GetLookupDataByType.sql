USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetLookupDataByType]
	@Type [int],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
   
	--Declaration Section
	DECLARE @HasAccess BIT

	SELECT L.NodeID,L.Code,L.Name,L.AliasName,L.Status,L.IsDefault,LT.LookupName FROM COM_Lookup L WITH(NOLOCK) left join COM_LookupTypes LT WITH(NOLOCK) on L.LookupType=LT.NodeID
	WHERE LookupType=@Type
	
	SELECT * FROM COM_Lookup WITH(NOLOCK)

	--SELECT L.NodeID,R.ResourceName,L.LookupName FROM COM_LookupTypes L
	--LEFT JOIN COM_LanguageResources R ON R.ResourceID=L.ResourceID AND R.LanguageID=@LangID

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
 SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
