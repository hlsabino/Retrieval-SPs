﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetFilesbasedonNodeID]
	@CostCenterID [bigint],
	@NodeID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
SET NOCOUNT ON;

		 select * from COM_Files where FeatureID=@CostCenterID and FeaturePK=@NodeID and isproductimage=1


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
