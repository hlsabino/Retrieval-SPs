USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetPDCDefaults]
	@IsPDC [int] = 1,
	@UserID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
SET NOCOUNT ON;
	IF(@IsPDC=1)
		Select UserProbableValues from  Adm_CostCenterDef with(nolock)
		Where CostCenterID=504 and CostCenterColID=53528
	ELSE IF(@IsPDC=2)
		Select LastValueVouchers from  Adm_CostCenterDef with(nolock)
		Where CostCenterID=504 and CostCenterColID=53525
	ELSE IF(@IsPDC=3)
		Select LastValueVouchers from  Adm_CostCenterDef with(nolock)
		Where CostCenterID=70 and CostCenterColID=534062
	    
SET NOCOUNT OFF; 
SELECT * FROM ADM_GlobalPreferences WHERE [NAME] IN ('BackupLocation','IsEncryptBackup','BackupPassCode')
RETURN 1
END TRY
BEGIN CATCH  
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
