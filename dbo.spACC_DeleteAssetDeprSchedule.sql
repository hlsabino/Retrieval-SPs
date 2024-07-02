USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_DeleteAssetDeprSchedule]
	@AssetID [bigint] = 0,
	@RoleID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	--Declaration Section
	DECLARE @HasAccess bit,@RowsDeleted bigint,@lft bigint,@rgt bigint,@Width bigint

	if(@AssetID=0)
	BEGIN
		RAISERROR('-100',16,1)
	END
	--User acces check
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,72,28)
	IF @HasAccess=0
	BEGIN
		RAISERROR('-105',16,1)
	END
	
	IF exists (select * from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DocID>0)
	BEGIN
		RAISERROR('-135',16,1)
	END
	
	DELETE FROM ACC_AssetDepSchedule WHERE AssetID=@AssetID
			
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
