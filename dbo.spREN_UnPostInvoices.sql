USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_UnPostInvoices]
	@SchedID [int],
	@DELETECCID [int],
	@DELETEDOCID [int] = 0,
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@UserID [int] = 1,
	@UserName [nvarchar](50),
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY    
SET NOCOUNT ON;    
	declare @return_value int
		
	EXEC @return_value = [dbo].[spDOC_DeleteInvDocument]  
	 @CostCenterID = @DELETECCID,  
	 @DocPrefix =  '',  
	 @DocNumber = '',  
	 @DocID=@DELETEDOCID ,
	 @SysInfo =@SysInfo, 
	 @AP =@AP, 
	 @UserID = @UserID,  
	 @UserName = @UserName,  
	 @LangID = @RoleID,
	 @RoleID=@LangID
				 
	UPDATE COM_SchEvents 
	SET STATUSID=1,PostedVoucherNo=null
	WHERE SCHEVENTID=@SchedID
		

COMMIT TRANSACTION  
SET NOCOUNT OFF;    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=102 AND LanguageID=@LangID  
  
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]
 
 if(@return_value=-999)
     return @return_value
 IF ERROR_NUMBER()=50000  
 BEGIN  
	IF ISNUMERIC(ERROR_MESSAGE())=1	
		SELECT ErrorMessage,ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	else
		SELECT ERROR_MESSAGE() ErrorMessage	
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE   
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
