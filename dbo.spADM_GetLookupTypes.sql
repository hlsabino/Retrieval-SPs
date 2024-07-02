USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetLookupTypes]
	@UserID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;

	SELECT L.NodeID,R.ResourceName,L.LookupName FROM COM_LookupTypes L WITH(NOLOCK)
	INNER JOIN adm_featureaction FA with(nolock) ON FA.FeatureID=44 and FA.FeatureActionTypeID=(100+L.NodeID*5)
	INNER JOIN adm_featureactionrolemap FAR with(nolock) ON FA.FeatureActionID=FAR.FeatureActionID
	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=L.ResourceID AND R.LanguageID=@LangID
	WHERE FAR.RoleID=@RoleID
	ORDER BY R.ResourceName

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
