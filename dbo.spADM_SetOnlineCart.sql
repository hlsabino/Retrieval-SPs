USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetOnlineCart]
	@Mode [int],
	@ContactID [bigint],
	@CartId [bigint],
	@TypeID [bigint],
	@DataXML [nvarchar](max),
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY      
SET NOCOUNT ON;   


    -- Insert statements for procedure here
    IF(@Mode=0)
	BEGIN
		iF(@CartId=0)
		BEGIN
			insert into COM_OnlineCart(ContactID,TypeID,DataXML,CreatedDate)
			values(@ContactID,@TypeID,@DataXML,convert(float,getdate()))
			set @CartId=@@identity
		END
		ELSE
		BEGIN
			update COM_OnlineCart
			set ContactID=@ContactID,TypeID=@TypeID,DataXML=@DataXML
			where CartID=@CartId
		END
	END
	ELSE IF(@Mode=1)
	BEGIN
		SELECT * FROM COM_OnlineCart WITH(NOLOCK) WHERE ContactID=@ContactID and TypeID=@TypeID
	END
	ELSE IF(@Mode=2)
	BEGIN
		delete FROM COM_OnlineCart WHERE ContactID=@ContactID and CartID=@CartId
	END

SET NOCOUNT OFF;      
COMMIT TRANSACTION     
IF(@Mode=0)
BEGIN
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID  
	return @CartId
END	
else IF(@Mode=2)
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=102 AND LanguageID=@LangID  
RETURN  1
END TRY    
BEGIN CATCH  
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    

ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999
END CATCH
GO
