USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetNationality]
	@Nationality [nvarchar](50),
	@Country [nvarchar](50),
	@UserID [int] = 0,
	@UserName [nvarchar](200),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
BEGIN TRANSACTION    
SET NOCOUNT ON    

	DECLARE @PREFValue INT,@NationalityID BIGINT
	SELECT @PREFValue=CONVERT(INT,ISNULL(Value,0)) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='EIDNationalityDimension'
	IF(@PREFValue IS NOT NULL AND @PREFValue > 50000)
	BEGIN
		DECLARE @SQL NVARCHAR(MAX),@TableName NVARCHAR(50),@CCStatusID INT
		SELECT @TableName=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@PREFValue
	
		SET @SQL='SELECT @NationalityID=NodeID FROM '+@TableName+' WITH(NOLOCK) WHERE Code=N'''+@Nationality+''''
		EXEC sp_executesql @SQL,N' @NationalityID BIGINT OUTPUT',@NationalityID OUTPUT
		
		IF (@NationalityID IS NULL OR @NationalityID <= 0)
		BEGIN
			SELECT @CCStatusID=StatusID FROM com_status with(nolock) where costcenterid=@PREFValue and [status] = 'Active'
			EXEC @NationalityID = [dbo].[spCOM_SetCostCenter]
			@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
			@Code = @Nationality,
			@Name = @Country,
			@AliasName = @Country,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
			@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
			@CostCenterID = @PREFValue,@CompanyGUID='CompanyGUID',@GUID='',@UserName='admin',@RoleID=1,@UserID=1,
			@CheckLink = 0
		END
		
		select @NationalityID 
	END
	 		
COMMIT TRANSACTION    
SET NOCOUNT OFF;    

SELECT  ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID    
RETURN  @NationalityID   
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
