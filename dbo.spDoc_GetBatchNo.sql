USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetBatchNo]
	@BatchNumber [nvarchar](200),
	@ProductID [bigint]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  
      
    DECLARE @AllowDuplicateBatches BIT, @AllowDupBatchesforDiffProducts bit
	select @AllowDuplicateBatches=CONVERT(bit,value) from COM_CostCenterPreferences where CostCenterID=16 and Name='AllowDuplicateBatches'
 	select @AllowDupBatchesforDiffProducts=CONVERT(bit,value) from COM_CostCenterPreferences where CostCenterID=16 and Name='AllowDupBatchesforDiffProducts'
 	 
	--select   @AllowDuplicateBatches  
	 
	--Getting  Batchnumber.    
	if(@AllowDuplicateBatches=0 and @AllowDupBatchesforDiffProducts=0)
		SELECT BatchId,BATCHNUMBER FROM INV_Batches with(nolock) WHERE BATCHNUMBER = @BatchNumber-- and ProductID=@ProductID
	else if(@AllowDuplicateBatches=1 and @AllowDupBatchesforDiffProducts=0)
		SELECT BatchId,BATCHNUMBER FROM INV_Batches with(nolock) WHERE BATCHNUMBER = @BatchNumber and ProductID<>@ProductID
	else
		select 1 BatchId,'' BATCHNUMBER  where 1<>1 
		
  	SELECT BatchId,BATCHNUMBER FROM INV_Batches with(nolock) 
  	WHERE BATCHNUMBER = @BatchNumber and ProductID=@ProductID
  	
  	SELECT ShelfLife FROM INV_Product with(nolock) 
  	WHERE ProductID=@ProductID

	select * from com_costcentercodedef with(nolock) WHERE CostCenterID=16                                           

     
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
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999  
  END  

SET NOCOUNT OFF    
RETURN -999     
END CATCH  
  
  
  
  
  
  
GO
