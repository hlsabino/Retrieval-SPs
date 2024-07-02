USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetInviteStatus]
	@InviteXML [nvarchar](max) = null,
	@UserName [nvarchar](50),
	@UserID [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;   
	DECLARE  @ActivityID bigint, @XML xml
	if( @InviteXML<>'')
	BEGIN
		 set @XML=@InviteXML
		 
		  UPDATE CRM_Activities    
		   SET InviteComments= X.value('@InviteComments','NVARCHAR(max)'), 
			InviteStatus=X.value('@InviteStatus','nvarchar(100)'),
			ModifiedBy=@UserName,    
			ModifiedDate=CONVERT(float,GETDATE()), 
			StatusID =412
		   FROM CRM_Activities C     
		   INNER JOIN @XML.nodes('/XML/Row') as Data(X)      
		   ON convert(bigint,X.value('@ActivityID','bigint'))=C.ActivityID    
		   where   X.value('@InviteStatus','nvarchar(100)')='Accepted'
		   
		   
		   UPDATE CRM_Activities    
		   SET InviteComments= X.value('@InviteComments','NVARCHAR(max)'), 
			InviteStatus=X.value('@InviteStatus','nvarchar(100)'),
			ModifiedBy=@UserName,    
			ModifiedDate=CONVERT(float,GETDATE())   
		   FROM CRM_Activities C     
		   INNER JOIN @XML.nodes('/XML/Row') as Data(X)      
		   ON convert(bigint,X.value('@ActivityID','bigint'))=C.ActivityID    
		   where   X.value('@InviteStatus','nvarchar(100)')='Rejected' or   X.value('@InviteStatus','nvarchar(100)')='Cancelled'
		   
	END 
						
COMMIT TRANSACTION  
SET NOCOUNT OFF; 
RETURN 1 
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
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
    
    
      select * from COM_Status where CostCenterID=144
GO
