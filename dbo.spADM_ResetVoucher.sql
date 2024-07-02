USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_ResetVoucher]
	@VoucherXML [nvarchar](max),
	@UserID [bigint] = 1,
	@LangID [bigint] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY    
	SET NOCOUNT ON;    
  
	declare @XML xml

	set @xml=@VoucherXML

	if(@VoucherXML is not null and @VoucherXML <> '')
	begin
		update COM_CostCenterCodeDef set CurrentCodeNumber=X.value('@NewNo','nvarchar(50)'),CodeNumberLength=X.value('@Length','nvarchar(50)')
		from @xml.nodes('/ResetVoucherXML/Rows') as data(x)
		where CostCenterCodeID=X.value('@CostCenterCodeID','nvarchar(50)') and 
		CostCenterID=X.value('@CostCenterID','nvarchar(50)')
	end
   
  
COMMIT TRANSACTION  
SET NOCOUNT OFF;    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=107 AND LanguageID=1  
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=1  
 END  
 ELSE   
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=1  
 END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  
  
  
  
  
  
GO
