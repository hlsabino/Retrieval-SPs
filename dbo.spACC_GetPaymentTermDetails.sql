USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetPaymentTermDetails]
	@AccountID [int] = 0,
	@linkedID [int] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  

	
	select PaymentTerms  from ACC_Accounts WITH(NOLOCK) where AccountID=@AccountID

	select * from Acc_PaymentDiscountProfile  WITH(NOLOCK)
 
	select * from Acc_PaymentDiscountTerms  WITH(NOLOCK)
		 
	select [VoucherNo],[AccountID],[Amount],[days],[DueDate],DateNo,Remarks1
	,[Percentage],[Remarts] Remarks,Period,BasedOn,a.ProfileID,b.ProfileName,a.dimccid,a.dimnodeid        from   [COM_DocPayTerms] a WITH(NOLOCK)
	left join Acc_PaymentDiscountProfile b WITH(NOLOCK) on a.ProfileID=b.ProfileID
	where [VoucherNo]=  (select VoucherNo from INV_DocDetails  WITH(NOLOCK) where InvDocDetailsID=@linkedID)
   
     
COMMIT TRANSACTION   
SET NOCOUNT OFF; 
RETURN 1  
END TRY  
BEGIN CATCH       
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE()    
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999  
  END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
