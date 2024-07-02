USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_GetCPRNodeID]
	@CPRPref [nvarchar](50) = '',
	@Cprtext [nvarchar](50) = '',
	@CprLookUpType [nvarchar](100) = null,
	@CCID [nvarchar](50) = '',
	@UserID [int] = 0,
	@UserName [nvarchar](200),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
BEGIN TRANSACTION      
SET NOCOUNT ON      
  
 DECLARE @PREFValue INT,@NODEID INT,@ResourceID INT  ,@LookTypeID int
 DECLARE @SQL NVARCHAR(MAX),@TableName NVARCHAR(50),@CCStatusID INT 
 if(@CCID=44)
 begin
	  SET @SQL='SELECT @NODEID=NodeID FROM COM_Lookup WITH(NOLOCK) WHERE Code=N'''+@Cprtext+''''  
	  EXEC sp_executesql @SQL,N' @NODEID INT OUTPUT',@NODEID OUTPUT  
	  
	  IF (@NODEID IS NULL OR @NODEID <= 0)  
	  BEGIN  
	    SELECT @ResourceID=MAX(ResourceID)+1 FROM COM_LanguageResources WITH(NOLOCK)		
		
		INSERT INTO COM_LanguageResources(ResourceID,ResourceName,LanguageID,LanguageName,ResourceData)
		SELECT @ResourceID,@Cprtext,LanguageID,Name,@Cprtext FROM ADM_Laguages WITH(NOLOCK)
		
		SELECT @LookTypeID=NodeID From  COM_LookupTYPES WHERE LooKUpName=@CprLookUpType
		INSERT INTO COM_Lookup(LookupType,Code,Name,AliasName,ResourceID,Status,CompanyGUID,GUID,CreatedBy,CreatedDate,isDefault)  
		VALUES(@LookTypeID,@Cprtext,@Cprtext,@Cprtext,@ResourceID,1,'guid',NEWID(),@UserName,convert(float,getdate()),0)  

		SET @NODEID=SCOPE_IDENTITY()
	 END
	 select @NODEID   
 end
 else
 begin
	 SELECT @PREFValue=CONVERT(INT,ISNULL(Value,0)) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name=@CPRPref --and costcenterid=@CCID
	 IF(@PREFValue IS NOT NULL AND @PREFValue > 50000)  
	 BEGIN  
	  
	  SELECT @TableName=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@PREFValue  
	   
	  SET @SQL='SELECT @NODEID=NodeID FROM '+@TableName+' WITH(NOLOCK) WHERE Code=N'''+@Cprtext+''''  
	  EXEC sp_executesql @SQL,N' @NODEID INT OUTPUT',@NODEID OUTPUT  
	    
	  IF (@NODEID IS NULL OR @NODEID <= 0)  
	  BEGIN  
	   SELECT @CCStatusID=StatusID FROM com_status with(nolock) where costcenterid=@PREFValue and [status] = 'Active'  
	   EXEC @NODEID = [dbo].[spCOM_SetCostCenter]  
	   @NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,  
	   @Code = @Cprtext,  
	   @Name = @Cprtext,  
	   @AliasName = @Cprtext,  
	   @PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,  
	   @CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,  
	   @CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,  
	   @CostCenterID = @PREFValue,@CompanyGUID='CompanyGUID',@GUID='',@UserName='admin',@RoleID=1,@UserID=1,  
	   @CheckLink = 0  
	  END  
	    
	  select @NODEID   
	 END  
end      
COMMIT TRANSACTION      
SET NOCOUNT OFF;      
  
SELECT  ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID      
RETURN  @NODEID     
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
