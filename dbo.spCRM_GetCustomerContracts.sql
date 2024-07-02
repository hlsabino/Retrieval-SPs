USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetCustomerContracts]
	@CustomerID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
	 
		if(@CustomerID>0)
		BEGIN	 
		 SELECT   DocID,VoucherNo, CONVERT(DATETIME, DocDate) AS DocDate
	     FROM INV_DocDetails d With(NOLOCK)
	     join COM_DocTextData t with(nolock) on d.InvDocDetailsID=t.InvDocDetailsID
	     where creditAccount=@CustomerID and DOcumentType=35 and CONVERT(datetime,dcAlpha4)>=getdate() 
	    END 
	    ELSE
	    BEGIN
		 SELECT   DocID,VoucherNo, CONVERT(DATETIME, DocDate) AS DocDate
	     FROM INV_DocDetails d With(NOLOCK)
	     join COM_DocTextData t with(nolock) on d.InvDocDetailsID=t.InvDocDetailsID
	     where DOcumentType=35	and CONVERT(datetime,dcAlpha4) >=getdate() 
	    END
	 	
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
