USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenterNodeNotes]
	@NoteID [int] = 0,
	@Note [nvarchar](max) = '',
	@FeatureID [int] = 0,
	@FeaturePK [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;        
		--Declaration Section  
		DECLARE @HasAccess BIT,@TempGuid NVARCHAR(50)  

		--SP Required Parameters Check        
		IF(@FeatureID=0 OR @FeaturePK=0 OR @Note='' OR @CompanyGUID IS NULL OR @CompanyGUID='')        
		BEGIN     
			RAISERROR('-100',16,1)       
		END        

		--User access check  
		IF @NoteID=0  
		BEGIN  
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,8)  
		END  
		ELSE  
		BEGIN  
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,8)  
		END  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  

		IF @NoteID=0--------START INSERT RECORD-----------      
		BEGIN        
			INSERT INTO COM_Notes  
				   (Note  
				   ,FeatureID  
				   ,FeaturePK
				   ,CompanyGUID	  
				   ,GUID  
				   ,CreatedBy  
				   ,CreatedDate)        
			VALUES  
				   (@Note  
				   ,@FeatureID  
				   ,@FeaturePK  
				   ,@CompanyGUID	
				   ,NEWID()  
				   ,@UserName  
				   ,CONVERT(float,GETDATE())) 

			--To get inserted record primary key
			SET @NoteID=SCOPE_IDENTITY()   
     
		END--------END INSERT RECORD-----------   
		ELSE--------START UPDATE RECORD-----------        
		BEGIN        
			SELECT @TempGuid=[GUID] FROM COM_Notes WITH(NOLOCK)         
			WHERE NoteID=@NoteID  
			IF(@Guid='')      
				SET @Guid= @TempGuid  
			--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ        
			IF(@TempGuid!=@Guid)
			BEGIN       
				RAISERROR('-101',16,1)
			END        
			       
			UPDATE COM_Notes        
			SET Note=@Note 
				  ,GUID=NEWID()  
				  ,ModifiedBy=@UserName  
				  ,ModifiedDate=convert(FLOAT,GETDATE())        
			WHERE NoteID=@NoteID        
			        
		END--------END UPDATE RECORD-----------        
           
COMMIT TRANSACTION   
SELECT NoteID,Note,GUID FROM COM_Notes WITH(NOLOCK) WHERE NoteID=@NoteID      
SET NOCOUNT OFF;            
RETURN @NoteID        
END TRY  
BEGIN CATCH    
		--Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT NoteID,Note,GUID FROM COM_Notes WITH(NOLOCK) WHERE NoteID=@NoteID      
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
