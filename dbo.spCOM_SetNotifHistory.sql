USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetNotifHistory]
	@StatusID [bigint],
	@ErrorMessage [nvarchar](max) = NULL,
	@EventID [bigint],
	@TemplateID [bigint],
	@TemplateType [int],
	@CostCenterID [bigint],
	@NodeID [bigint],
	@From [nvarchar](max) = NULL,
	@DisplayName [nvarchar](max) = NULL,
	@To [nvarchar](max),
	@CC [nvarchar](max) = NULL,
	@BCC [nvarchar](max) = NULL,
	@Subject [nvarchar](max) = NULL,
	@Body [nvarchar](max) = NULL,
	@AttachmentType [nvarchar](50) = NULL,
	@AttachmentPath [nvarchar](max) = NULL,
	@CompanyGUID [nvarchar](50) = NULL,
	@UserName [nvarchar](50) = NULL,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
	--Declaration Section    
	DECLARE @HasAccess BIT,@Dt FLOAT,@ID BIGINT
  
	SET @Dt=CONVERT(FLOAT,GETDATE())
	
	IF @StatusID=2
		UPDATE COM_SchEvents 
		SET StatusID=@StatusID,[Message]=@ErrorMessage
		WHERE SchEventID=@EventID
	ELSE IF @StatusID=-1
	BEGIN
		set @StatusID=3
		UPDATE COM_SchEvents 
		SET FailureCount=FailureCount+1,StatusID=@StatusID,[Message]=@ErrorMessage
		WHERE SchEventID=@EventID
	END
	ELSE
		UPDATE COM_SchEvents
		SET FailureCount=FailureCount+1,[Message]=@ErrorMessage
		WHERE SchEventID=@EventID
	
	INSERT INTO COM_Notif_History
		(SchEventID,TemplateID,TemplateType,CostCenterID,NodeID,StatusID,ErrorMessage
		,[From],DisplayName,[To],CC,BCC,[Subject],Body,AttachmentType,AttachmentPath
		,CompanyGUID
		,GUID
		,CreatedBy
		,CreatedDate)
	VALUES
		(@EventID,@TemplateID,@TemplateType,@CostCenterID,@NodeID,@StatusID,@ErrorMessage
		,@From,@DisplayName,@To,@CC,@BCC,@Subject,@Body,@AttachmentType,@AttachmentPath
		,@CompanyGUID
		,newid()
		,@UserName
		,@Dt)      

	--To get inserted record primary key    
	SET @ID=SCOPE_IDENTITY()
	
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
--SELECT * FROM COM_NotifTemplate WITH(nolock) WHERE TemplateID=@TemplateID     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;      
RETURN  @ID    
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
    
GO
