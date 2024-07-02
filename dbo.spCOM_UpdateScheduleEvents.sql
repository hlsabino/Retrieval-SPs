USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_UpdateScheduleEvents]
	@ScheduleID [int],
	@IsInventory [bit],
	@DocID [bigint],
	@UserID [bigint] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;

	DECLARE @VoucherNo NVARCHAR(100)
	IF @IsInventory=1
		SELECT TOP 1 @VoucherNo=VoucherNo FROM INV_DocDetails with(nolock) Where DocID=@DocID
	ELSE
		SELECT TOP 1 @VoucherNo=VoucherNo FROM ACC_DocDetails with(nolock) Where DocID=@DocID
	
	UPDATE COM_SchEvents 
	SET STATUSID=2,PostedVoucherNo=@VoucherNo
	WHERE SCHEVENTID=@ScheduleID

COMMIT TRANSACTION  
SET NOCOUNT OFF;  

RETURN 1  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
