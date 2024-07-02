USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenterNodeArtifacts]
	@ArtifactID [bigint] = 0,
	@ArtifactName [nvarchar](max) = '',
	@Attachment [nvarchar](max) = '',
	@Value [nvarchar](max) = '',
	@MandatoryType [nvarchar](50) = '',
	@FeatureID [int] = 0,
	@FeaturePK [bigint] = 0,
	@StatusID [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;        
		--Declaration Section  
		DECLARE @HasAccess BIT,@TempGuid NVARCHAR(50)  

		--SP Required Parameters Check        
		IF(@FeatureID=0 OR @FeaturePK=0 OR @ArtifactName='' OR @CompanyGUID IS NULL OR @CompanyGUID='')        
		BEGIN     
			RAISERROR('-100',16,1)       
		END        

		--User access check  
		IF @ArtifactID=0  
				SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,848)  
		ELSE  
				SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,846)  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  

		IF @ArtifactID=0--------START INSERT RECORD-----------      
		BEGIN        
			INSERT INTO COM_Artifacts  
				   (Name  
				   ,FeatureID,FeaturePK
				   ,Attachment,Value,Mandatory
				   ,StatusID
				   ,CompanyGUID	  
				   ,GUID  
				   ,CreatedBy  
				   ,CreatedDate)        
			VALUES  
				   (@ArtifactName 
				   ,@FeatureID,@FeaturePK  
				   ,@Attachment,@Value,@MandatoryType
				   ,@StatusID
				   ,@CompanyGUID	
				   ,NEWID()  
				   ,@UserName  
				   ,CONVERT(float,GETDATE())) 

			--To get inserted record primary key
			SET @ArtifactID=SCOPE_IDENTITY()   
     
		END--------END INSERT RECORD-----------   
		ELSE--------START UPDATE RECORD-----------        
		BEGIN        
			SELECT @TempGuid=[GUID] FROM COM_Artifacts WITH(NOLOCK)         
			WHERE ArtfID =@ArtifactID   
			IF(@Guid='')      
				SET @Guid= @TempGuid  
			--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ        
			IF(@TempGuid!=@Guid)
			BEGIN       
				RAISERROR('-101',16,1)
			END        
			       
			UPDATE COM_Artifacts        
			SET Name=@ArtifactName
				  ,Attachment=@Attachment
				  ,Value=@Value
				  ,Mandatory=@MandatoryType
				  ,StatusID=@StatusID
				  ,GUID=NEWID()  
				  ,ModifiedBy=@UserName  
				  ,ModifiedDate=convert(FLOAT,GETDATE())        
			WHERE ArtfID=@ArtifactID        
			        
		END--------END UPDATE RECORD-----------        
           
COMMIT TRANSACTION   
SELECT ArtfID,Name,GUID FROM COM_Artifacts WITH(NOLOCK) WHERE ArtfID=@ArtifactID      
SET NOCOUNT OFF;            
RETURN @ArtifactID        
END TRY  
BEGIN CATCH    
		--Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT ArtfID,Name,GUID FROM COM_Artifacts WITH(NOLOCK) WHERE ArtfID=@ArtifactID  
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
