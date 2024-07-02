USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_AuditAPIPosting]
	@CostCenterID [int],
	@NodeID [int],
	@MapID [int],
	@reqMethod [nvarchar](32),
	@Url [nvarchar](max),
	@Parms [nvarchar](max),
	@Headers [nvarchar](max),
	@Body [nvarchar](max),
	@Result [nvarchar](max),
	@PostingClient [nvarchar](32),
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON;
	
	INSERT INTO [COM_APIPostingHistory] (CostCenterID,NodeID,MapID,ActionType,Url,Params,Headers,Body,Result,Client,CreatedBy,CreatedDate)
	VALUES (@CostCenterID,@NodeID,@MapID,@reqMethod,@Url,@Parms,@Headers,@Body,@Result,@PostingClient,@UserName,CONVERT(FLOAT,GETDATE()))

	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)                 
	WHERE ErrorNumber=100 AND LanguageID=1 
SET NOCOUNT OFF;
RETURN 1  
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=1  
  END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
