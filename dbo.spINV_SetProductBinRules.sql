USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetProductBinRules]
	@ProfileID [bigint],
	@ProfileName [nvarchar](max),
	@RuleType [int],
	@RuleXML [nvarchar](max),
	@Action [bit],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
	
	IF @Action=0
	BEGIN
		DECLARE @XML XML
		SET @XML=@RuleXML
		
		IF @ProfileID=0
		BEGIN
			
			SELECT @ProfileID=isnull(MAX(ProfileID),0)+1 FROM INV_ProductBinRules WITH(NOLOCK)
			
			INSERT INTO INV_ProductBinRules
			SELECT @ProfileID,@ProfileName,X.value('@RuleID','int'),@RuleType 
			FROM @XML.nodes('/XML/Row') as DATA(X)
			
		END
		ELSE
		BEGIN
		
			DELETE FROM INV_ProductBinRules WHERE ProfileID=@ProfileID
			
			INSERT INTO INV_ProductBinRules
			SELECT @ProfileID,@ProfileName,X.value('@RuleID','int'),@RuleType 
			FROM @XML.nodes('/XML/Row') as DATA(X)
		
		END
	END
	ELSE IF @Action=1
	BEGIN
	
		DELETE FROM INV_ProductBinRules WHERE ProfileID=@ProfileID
		SET @ProfileID=0
	END
	
	COMMIT TRANSACTION    
	IF @Action=0      
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
		WHERE ErrorNumber=100 AND LanguageID=@LangID    
	ELSE IF @Action=1  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
		WHERE ErrorNumber=102 AND LanguageID=@LangID 
	
	SET NOCOUNT OFF;      
	RETURN @ProfileID      
END TRY    
BEGIN CATCH      
	--Return exception info [Message,Number,ProcedureName,LineNumber]      
	IF ERROR_NUMBER()=50000    
	BEGIN  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
	END    
	ELSE IF ERROR_NUMBER()=547    
	BEGIN    
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)    
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
