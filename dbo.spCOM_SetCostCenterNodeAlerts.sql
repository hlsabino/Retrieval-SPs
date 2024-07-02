USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenterNodeAlerts]
	@AlertID [bigint] = 0,
	@AlertMessage [nvarchar](max) = '',
	@FromDate [datetime] = null,
	@ToDate [datetime] = null,
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
		IF(@FeatureID=0 OR @FeaturePK=0 OR @AlertMessage='' OR @CompanyGUID IS NULL OR @CompanyGUID='')        
		BEGIN     
			RAISERROR('-100',16,1)       
		END        

		--User access check  
		IF @AlertID=0  
		BEGIN  
			IF(@FEATUREID=94)
			BEGIN
				SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,844)  
			END
			ELSE IF(@FEATUREID=92)
			BEGIN
				SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,836)  
			END
		END  
		ELSE  
		BEGIN  
			IF(@FEATUREID=94)
			BEGIN
				SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,842)  
			END
			ELSE IF(@FEATUREID=92)
			BEGIN
				SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,838)  
			END
		END  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  

		IF @AlertID=0--------START INSERT RECORD-----------      
		BEGIN        
			INSERT INTO COM_Alerts  
				   (AlertMessage  
				   ,FeatureID,FeaturePK
				   ,FromDate,ToDate
				   ,StatusID
				   ,CompanyGUID	  
				   ,GUID  
				   ,CreatedBy  
				   ,CreatedDate)        
			VALUES  
				   (@AlertMessage 
				   ,@FeatureID,@FeaturePK  
				   ,CONVERT(float,@FromDate),CONVERT(float,@ToDate)
				   ,@StatusID
				   ,@CompanyGUID	
				   ,NEWID()  
				   ,@UserName  
				   ,CONVERT(float,GETDATE())) 

			--To get inserted record primary key
			SET @AlertID=SCOPE_IDENTITY()   
     
		END--------END INSERT RECORD-----------   
		ELSE--------START UPDATE RECORD-----------        
		BEGIN        
			SELECT @TempGuid=[GUID] FROM COM_Alerts WITH(NOLOCK)         
			WHERE AlertID =@AlertID   
			IF(@Guid='')      
				SET @Guid= @TempGuid  
			--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ        
			IF(@TempGuid!=@Guid)
			BEGIN       
				RAISERROR('-101',16,1)
			END        
			       
			UPDATE COM_Alerts        
			SET AlertMessage=@AlertMessage
				  ,FromDate=convert(FLOAT,@FromDate)
				  ,ToDate=convert(FLOAT,@ToDate)
				  ,StatusID=@StatusID
				  ,GUID=NEWID()  
				  ,ModifiedBy=@UserName  
				  ,ModifiedDate=convert(FLOAT,GETDATE())        
			WHERE AlertID=@AlertID        
			        
		END--------END UPDATE RECORD-----------        
           
COMMIT TRANSACTION   
SELECT AlertID,AlertMessage,GUID FROM COM_Alerts WITH(NOLOCK) WHERE AlertID=@AlertID      
SET NOCOUNT OFF;            
RETURN @AlertID        
END TRY  
BEGIN CATCH    
		--Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT AlertID,AlertMessage,GUID FROM COM_Alerts WITH(NOLOCK) WHERE AlertID=@AlertID      
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
