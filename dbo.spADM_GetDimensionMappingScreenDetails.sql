﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDimensionMappingScreenDetails]
	@Type [int],
	@DimMappID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;

	IF @Type=0 /*TO GET SCREEN DETAILS*/
	BEGIN
		SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE (FEATUREID>50000 OR FEATUREID=2 or FEATUREID=3)  and ISEnabled=1

		SELECT Distinct ProfileID,ProfileName FROM COM_DimensionMappings WITH(NOLOCK)
		GROUP BY ProfileID,ProfileName
		ORDER BY ProfileName
		
		SELECT  Value,Name FROM COM_CostCenterPreferences WITH(NOLOCK)		
		where CostCenterID=	153

	END
	ELSE IF @Type=2 /*TO GET PROFILE DATA BY PROFILEID*/
	BEGIN
		SELECT T.* FROM COM_DimensionMappings T WITH(NOLOCK)
		WHERE T.ProfileID=@DimMappID
	END
	ELSE IF @Type=5 /*TO DELETE PROFILE*/
	BEGIN
		DELETE FROM COM_DimensionMappings WHERE ProfileID=@DimMappID
	END

	
--COMMIT TRANSACTION 
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
--ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
