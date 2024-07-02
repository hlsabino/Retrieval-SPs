USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_RemovePrintLayout]
	@LayoutID [bigint] = 0,
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
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
		
		declare @EmailName nvarchar(max)
		if @LayoutID!=0 and exists(select TemplateName from COM_NotifTemplate with(nolock) where AttachmentID=@LayoutID)
		begin
			select @EmailName=TemplateName from COM_NotifTemplate with(nolock) where AttachmentID=@LayoutID
			set @EmailName='Print Layout Used In Email Template "'+@EmailName+'"'
			RAISERROR(@EmailName,16,1)
		end
		
		DELETE FROM ADM_DocPrintLayoutsMap WHERE DocPrintLayoutID = @LayoutID

		DELETE FROM ADM_DocPrintLayouts WHERE DocPrintLayoutID = @LayoutID
		SET @RowsDeleted=@@rowcount
		
		
COMMIT TRANSACTION
SET NOCOUNT OFF;  
RETURN @RowsDeleted
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		if ERROR_MESSAGE() like '%Email Template%'
			SELECT ERROR_MESSAGE() ErrorMessage,50000 ErrorNumber
		else
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
