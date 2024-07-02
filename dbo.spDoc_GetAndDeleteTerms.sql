USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetAndDeleteTerms]
	@ProfileID [int] = 0,
	@Type [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  

if(@Type=3)
begin	
	if(exists(select VoucherNo from [COM_DocPayTerms] with(nolock) where  ISNULL(VoucherNo,'')<>'' and ProfileID=@ProfileID))
	begin
	   RAISERROR('-110',16,1) 
	end
	else
	begin
		delete from Acc_PaymentDiscountTerms where ProfileID=@ProfileID
		delete from Acc_PaymentDiscountProfile where ProfileID=@ProfileID
	end
	
end
else
begin
	if(@ProfileID=0)
	begin
	   select * from Acc_PaymentDiscountProfile with(nolock)
	   select FeatureID,Name from ADM_Features with(nolock) where FeatureID>50000
	end
	Else
	begin
	   select * from Acc_PaymentDiscountTerms a with(nolock) where ProfileID=@ProfileID
	end
end

   
     
COMMIT TRANSACTION   
SET NOCOUNT OFF;
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
  WHERE ErrorNumber=102 AND LanguageID=@LangID    
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
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999  AND LanguageID=@LangID 
  END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
