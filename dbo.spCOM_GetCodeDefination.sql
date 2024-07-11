USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCodeDefination]
	@CostCenterID [int],
	@IsName [bit] = 0,
	@IsGroupCode [smallint] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
    
BEGIN TRY    
SET NOCOUNT ON  
	--User acces check FOR Notes
	IF (@CostCenterID=0)
		RAISERROR('-105',16,1) 
	
	SELECT * FROM COM_CostCenterCodeDef with(nolock)
	WHERE COSTCENTERID=@COSTCENTERID and IsName=@IsName and IsGroupCode=@IsGroupCode
	
	SELECT [LEVELNO],[CodeLength]  FROM COM_CCParentCodeDef with(nolock)
	where [CostCenterID]=@COSTCENTERID
		
 
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
