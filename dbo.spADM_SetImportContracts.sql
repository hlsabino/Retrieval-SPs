USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportContracts]
	@Feature [int],
	@FeaturePK [bigint],
	@AddressTypeID [int],
	@ExtraFields [nvarchar](max),
	@ExtraUserDefinedFields [nvarchar](max),
	@CostCenterFields [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON     
  --Declaration Section 
  
	DECLARE @return_value int,@Dt FLOAT,@UpdateSql NVARCHAR(max) 

	SET @Dt=CONVERT(FLOAT,GETDATE())

	INSERT INTO COM_Contacts (AddressTypeID,FeatureID,FeaturePK,[GUID],CreatedBy,CreatedDate)
	VALUES (@AddressTypeID,@Feature,@FeaturePK,NEWID(),@UserName,@Dt)
	
	SET @return_value=SCOPE_IDENTITY()  
	
	INSERT INTO COM_ContactsExtended(ContactID,CreatedBy,CreatedDate)
	VALUES (@return_value,@UserName,@Dt)

	INSERT INTO COM_CCCCData (CostCenterID,NodeID,[GUID],CreatedBy,CreatedDate)
	VALUES (65,@return_value,NEWID(),@UserName,@Dt)
	
	IF(@ExtraFields IS NOT NULL AND @ExtraFields <>'')    
	BEGIN    
		set @UpdateSql='update [COM_Contacts]    
		SET '+@ExtraFields+' [ModifiedBy] ='''+ @UserName    
		+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ContactID='+convert(nvarchar,@return_value)
		exec(@UpdateSql)    
	END
			
	IF(@ExtraUserDefinedFields IS NOT NULL AND @ExtraUserDefinedFields <>'')    
	BEGIN    
		set @UpdateSql='update [COM_ContactsExtended]    
		SET '+@ExtraUserDefinedFields+' [ModifiedBy] ='''+ @UserName    
		+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ContactID='+convert(nvarchar,@return_value)      
		exec(@UpdateSql)    
	END    
         
	IF(@CostCenterFields IS NOT NULL AND @CostCenterFields <>'')    
	BEGIN  
		set @UpdateSql='update COM_CCCCDATA      
		SET '+@CostCenterFields+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID =      
		'+convert(nvarchar,@return_value) + ' AND CostCenterID = 65'     
		exec(@UpdateSql)      
	END 
		
COMMIT TRANSACTION      
  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @return_value      
END TRY      
BEGIN CATCH

if(@return_value=-999)
	return  -999
	 
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-116 AND LanguageID=@LangID    
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
