USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetDetailsByDocno]
	@DocNo [nvarchar](max),
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
	declare @docid bigint
	set @docid=0
	select @docid=isnull(Docid,0) FROM INV_DocDetails D with(nolock) 
	WHERE D.VoucherNo=@DocNo
	
	if(@docid=0) 
		select @docid=isnull(Docid,0) ,@DocNo=D.VoucherNo FROM INV_DocDetails D with(nolock) 
		WHERE (DocAbbr+'-'+DocPrefix+DocNumber)=@DocNo
	
	if(@docid>0)	
		select Account1,AccountCode,AccountName,AccountTypeID,IsBillwise,VoucherNo 
		FROM INV_DocDetails D with(nolock) 
		join acc_accounts a with(nolock) on a.Accountid=d.Account1
		where Docid=@docid
	

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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
