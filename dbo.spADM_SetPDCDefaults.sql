USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetPDCDefaults]
	@XML [nvarchar](max),
	@IsDefault [bit] = 1,
	@IsPDC [int] = 1,
	@CompanyGUID [nvarchar](max),
	@UserID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	IF(@IsPDC=1)
	BEGIN
		if (@IsDefault=1)
			Update Adm_CostCenterDef 
			Set UserProbableValues=@XML
			Where CostCenterID=504 and CostCenterColID=53528
		else
			Update Adm_CostCenterDef 
			Set UserProbableValues=''
			Where CostCenterID=504 and CostCenterColID=53528
	END
	ELSE IF(@IsPDC=2)
	BEGIN
		if (@IsDefault=1)
			Update Adm_CostCenterDef 
			Set LastValueVouchers=@XML
			Where CostCenterID=504 and CostCenterColID=53525
		else
			Update Adm_CostCenterDef 
			Set LastValueVouchers=''
			Where CostCenterID=504 and CostCenterColID=53525
	END
	ELSE IF(@IsPDC=3)
	BEGIN
		if (@IsDefault=1)
			Update Adm_CostCenterDef 
			Set LastValueVouchers=@XML
			Where CostCenterID=70 and CostCenterColID=534062
		else
			Update Adm_CostCenterDef 
			Set LastValueVouchers=''
			Where CostCenterID=70 and CostCenterColID=534062
	END
COMMIT TRANSACTION    
SET NOCOUNT OFF; 
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
 ROLLBACK TRANSACTION  
 SET NOCOUNT OFF  
 RETURN -999     
END CATCH	
GO
