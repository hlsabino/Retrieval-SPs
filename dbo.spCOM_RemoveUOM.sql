USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_RemoveUOM]
	@BASEID [bigint],
	@PRODUCTID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
	
		--Declaration Section
		DECLARE @HasAccess BIT,@RowsDeleted BIT

		--SP Required Parameters Check
		IF(@BASEID = 0)
		BEGIN
			RAISERROR('-100',16,1)
		END 

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,11,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END 
		
		IF(@BASEID = 1)
		BEGIN
			RAISERROR('-117',16,1)
		END 
		

		IF @PRODUCTID>0
		BEGIN
				UPDATE INV_PRODUCT SET UOMID=1 WHERE PRODUCTID=@PRODUCTID	
				DELETE FROM INV_PRODUCTBARCODE WHERE PRODUCTID=@PRODUCTID	
		END
		
		--TO Remove Unit of Measure(s)
		DELETE FROM COM_UOM WHERE BASEID=@BASEID

		
		SET @RowsDeleted=@@rowcount

COMMIT TRANSACTION
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID
RETURN @RowsDeleted  
END TRY    
BEGIN CATCH    
--Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END  
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
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
