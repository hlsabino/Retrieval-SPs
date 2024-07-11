USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetMachineDetails]
	@ResourceID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit

		--SP Required Parameters Check
		IF (@ResourceID < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--Getting Resources
		SELECT * FROM PRD_Resources WITH(NOLOCK) 	
		WHERE ResourceID=@ResourceID

		--Getting Contacts 
		EXEC [spCom_GetFeatureWiseContacts] 71,@ResourceID,2,1,1
		 

		--Getting Notes
		SELECT * FROM  COM_Notes WITH(NOLOCK) 
		WHERE FeatureID=71 and  FeaturePK=@ResourceID

		--Getting Files
		SELECT * FROM  COM_Files WITH(NOLOCK) 
		WHERE FeatureID=71 and  FeaturePK=@ResourceID

		--Getting ADDRESS 
		EXEC spCom_GetAddress 71,@ResourceID,1,1

		--Getting Contacts
		EXEC [spCom_GetFeatureWiseContacts] 71,@ResourceID,1,1,1

		 SELECT * FROM COM_CCCCDATA  WITH(NOLOCK)
		  WHERE NodeID = @ResourceID AND CostCenterID  = 71 

			--Getting data from Resource extended table
		SELECT * FROM  PRD_ResourceExtended WITH(NOLOCK) 
		WHERE ResourceID=@ResourceID
		

SET NOCOUNT OFF;
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

SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
