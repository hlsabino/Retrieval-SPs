USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetProductType]
	@ProductID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
	 
		--SP Required Parameters Check
		IF (@ProductID < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		if exists (SELECT ProductTypeID FROM INV_Product WITH(NOLOCK) 	WHERE ProductID=@ProductID and ParentID=0)
		begin
			select 0,'' ProductCode
		end
		else
		begin
			SELECT ProductTypeID,ProductCode FROM INV_Product WITH(NOLOCK) 	
			WHERE ProductID=@ProductID
		end	
		
		SELECT count(ProductTypeID) ChildCount,isnull(max(CodeNumber),0)+1 NextNumber FROM INV_Product WITH(NOLOCK) 	
		WHERE ParentID=@ProductID and isGroup=0
		
			 

COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
