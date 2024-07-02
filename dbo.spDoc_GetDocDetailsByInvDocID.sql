USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetDocDetailsByInvDocID]
	@InvDocID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
 
		--SP Required Parameters Check
		IF @InvDocID=0
		BEGIN
			RAISERROR('-100',16,1)
		END
 
		select  docseqno, VoucherNo, 
		Convert(datetime, docdate) as DocDate,
		Convert(datetime, duedate) as DueDate, d.InvDocDetailsID,ProductID ,DocSeqNo,d.StatusID, d.StockValue,
		cc.*
		from	 INV_DocDetails d WITH(NOLOCK)
		left join com_docccdata cc with(nolock) on d.InvDocDetailsID=cc.InvDocDetailsID
		 	where DocID=@InvDocID
		 	
 
 SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber]  
		IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END
SET NOCOUNT OFF  
RETURN -999   
END CATCH





  
GO
