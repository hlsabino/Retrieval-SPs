﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_RemoveBarcodeLayout]
	@LayoutID [bigint] = 0,
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted int

		--SP Required Parameters Check
		if(@LayoutID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,39,27)
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		IF (select count(*) from INV_MatrixDef with(nolock) where BarcodeID=@LayoutID)>0
		BEGIN
			RAISERROR('-110',16,1)
		END
		ELSE
		
		BEGIN TRANSACTION
		DELETE FROM ADM_DocBarcodeLayouts WHERE BarcodeLayoutID = @LayoutID
		SET @RowsDeleted=@@rowcount		
		COMMIT TRANSACTION
SET NOCOUNT OFF;  
RETURN @RowsDeleted
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
