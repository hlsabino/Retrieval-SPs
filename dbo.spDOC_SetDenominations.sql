USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetDenominations]
	@PosSessionID [bigint],
	@Mode [bit],
	@DenomXML [nvarchar](max),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY 
	declare @xml xml
	set @xml=@DenomXML
	
	if(@xml is not null and CONVERT(nvarchar(max),@xml)<>'')
	begin
		INSERT INTO COM_DocDenominations(DOCID,[CurrencyID],[Notes],[NotesTender],[Change],[ChangeTender],AccDocDetailsID,PosCloseID)
		select 0,X.value('@CurrencyID','BIGINT'),X.value('@Notes','float'),X.value('@NotesTender','float')
		,X.value('@Change','float'),X.value('@ChangeTender','float'),@Mode,@PosSessionID
		FROM @xml.nodes('/XML') as Data(X) where X.value('@IsDenom','BIT')=1
	end
   
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID        
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
