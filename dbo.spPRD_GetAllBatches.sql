USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetAllBatches]
	@DocDate [datetime],
	@MfgDate [datetime],
	@Bom [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY          
SET NOCOUNT ON;        
            
		select BATCHNUMBER,BatchID,ProductID,CONVERT(DATETIME,MfgDate) MfgDate,CONVERT(DATETIME,ExpiryDate) ExpiryDate,	
		MRPRate MRATE,RETAILRATE RRATE,STOCKISTRATE  SRATE 
		from dbo.INV_Batches with(nolock)
		WHERE STATUSID = 77 and ExpiryDate>=CONVERT(float,@DocDate) and CONVERT(DATETIME,MfgDate)=@MfgDate
		and (ProductID IN (SELECT  ProductID FROM  PRD_BOMProducts with(nolock) where BOMID=@Bom)
		or ProductID=(SELECT  ProductID FROM PRD_BillOfMaterial with(nolock) where BOMID=@Bom))
		
           
SET NOCOUNT OFF;        
RETURN 1        
END TRY        
BEGIN CATCH          
  --Return exception info [Message,Number,ProcedureName,LineNumber]          
  IF ERROR_NUMBER()=50000        
  BEGIN        
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE()          
  END        
  ELSE        
  BEGIN        
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS		
	ErrorLine  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999        
  END        
SET NOCOUNT OFF          
RETURN -999           
END CATCH
GO
