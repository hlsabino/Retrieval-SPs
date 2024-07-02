USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetReviseHistory]
	@DocID [bigint],
	@IsInventory [bit],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY          
SET NOCOUNT ON;        

if(@IsInventory=1)
	select distinct [VersionNo],ReviseReason,[ModifiedBy],convert(datetime,[ModifiedDate])[ModifiedDate] from [INV_DocDetails_History] with(NOLOCK)
	where DocID=@DocID
else
	select distinct [VersionNo],ReviseReason,[ModifiedBy],convert(datetime,[ModifiedDate])[ModifiedDate] from [ACC_DocDetails_History] with(NOLOCK)
	where DocID=@DocID

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
