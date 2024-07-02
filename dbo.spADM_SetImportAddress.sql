USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportAddress]
	@AccountCode [nvarchar](500),
	@AccountName [nvarchar](500),
	@AddressTypeID [int],
	@IsCode [bit] = NULL,
	@ExtraFields [nvarchar](max),
	@ExtraUserDefinedFields [nvarchar](max),
	@CostCenterFields [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON     
  --Declaration Section 
  
	DECLARE @return_value int,@Dt FLOAT,@UpdateSql NVARCHAR(max),@FeaturePK BIGINT
    
    IF(@IsCode=1)
		SELECT @FeaturePK=AccountID FROM Acc_Accounts WITH(NOLOCK) WHERE AccountCode=@AccountCode
	ELSE
		SELECT @FeaturePK=AccountID from Acc_Accounts WITH(NOLOCK) WHERE AccountName=@AccountName	
	
	SET @Dt=CONVERT(FLOAT,GETDATE())
	
	IF(@FeaturePK IS NOT NULL)
	BEGIN
		INSERT INTO COM_Address (AddressTypeID,FeatureID,FeaturePK,[GUID],CreatedBy,CreatedDate)
		VALUES (@AddressTypeID,2,@FeaturePK,NEWID(),@UserName,@Dt)
		SET @return_value=SCOPE_IDENTITY()
		
		IF(@ExtraFields IS NOT NULL AND @ExtraFields <>'')    
		BEGIN    
			set @UpdateSql='update [COM_Address]    
			SET '+@ExtraFields+' '+@ExtraUserDefinedFields+' '+@CostCenterFields+' [ModifiedBy] ='''+ @UserName    
			+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE AddressID='+convert(nvarchar,@return_value)
			--PRINT (@UpdateSql)
			EXEC(@UpdateSql)    
		END	 
		INSERT INTO COM_Address_History 
		SELECT * FROM COM_Address with(nolock)
		WHERE FeatureID=2 AND AddressID =@return_value
	END
COMMIT TRANSACTION   
  
IF(@FeaturePK=0 OR @FeaturePK IS NULL OR @FeaturePK='')
BEGIN
	SELECT 'InValid Account' ErrorMessage,-158 ErrorNumber
END
ELSE
BEGIN
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
	WHERE ErrorNumber=100 AND LanguageID=@LangID    
END
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
