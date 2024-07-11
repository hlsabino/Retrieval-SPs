USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetNextContractNo]
	@CostCenterID [int],
	@parContractID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
     
BEGIN TRY       
SET NOCOUNT ON      
	declare @SNO INT
		
			
	IF (@CostCenterID=95 OR  @CostCenterID=104)
		select @SNO=isnull(Max(SNO),0)+1  
		from  REN_Contract WITH(NOLOCK)   WHERE   CostCenterID = @CostCenterID  and isnull(parentContractID,0)=@parContractID 
	else IF (@CostCenterID=103 OR @CostCenterID=129)
		select @SNO=isnull(Max(SNO),0)+1  
		from  REN_Quotation WITH(NOLOCK)   WHERE   CostCenterID = @CostCenterID  AND StatusID<>430    
	
	select @SNO SNO
    
     
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
