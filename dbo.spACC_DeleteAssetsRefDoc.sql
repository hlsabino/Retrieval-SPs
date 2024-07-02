USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_DeleteAssetsRefDoc]
	@HistoryID [bigint],
	@Type [int],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
	declare @DocNo nvarchar(50),@DocID int,@AssetID bigint

	if(@Type=1)
	BEGIN
		select @DocNo=VoucherNo,@DocID=DocID,@AssetID=AssetManagementID from ACC_AssetsHistory where HistoryID=@HistoryID
		if(@DocID is not null)
		begin
			delete from Com_DocAddressData where AccDocDetailsID in (select AccDocDetailsID from ACC_DocDetails where VoucherNo=@DocNo and DocID=@DocID)
			delete from COM_DocTextData where AccDocDetailsID in (select AccDocDetailsID from ACC_DocDetails where VoucherNo=@DocNo and DocID=@DocID)
			delete from COM_DocCCData where AccDocDetailsID in (select AccDocDetailsID from ACC_DocDetails where VoucherNo=@DocNo and DocID=@DocID)
			delete from COM_DocNumData where AccDocDetailsID in (select AccDocDetailsID from ACC_DocDetails where VoucherNo=@DocNo and DocID=@DocID)
			delete from ACC_DocDetails where VoucherNo=@DocNo and DocID=@DocID
		end
		
		delete from ACC_AssetsHistory where HistoryID=@HistoryID
		delete from ACC_AssetChanges where AssetID=@AssetID and ChangeType=5 and Descriptions=@HistoryID
	END		
	Else if(@Type=2)
	BEGIN
		delete from ACC_AssetsHistory where HistoryID=@HistoryID
	END

COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID
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
