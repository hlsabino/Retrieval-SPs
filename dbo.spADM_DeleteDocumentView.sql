USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteDocumentView]
	@DocViewID [nvarchar](50),
	@ViewType [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
	--Declaration Section
	DECLARE @RowsDeleted bigint

	--SP Required Parameters Check
	if(@DocViewID is null)
	BEGIN
		RAISERROR('-210',16,1)
	END
	
	DECLARE @CostCenterID BIGINT
	
	
	if(@ViewType=1)
	begin
		delete from [ADM_DocViewUserRoleMap] where [DocumentViewID]=@DocViewID
		delete from [ADM_DocumentViewDef] where [DocumentViewID]=@DocViewID
		SELECT @CostCenterID=COSTCENTERID FROM  [ADM_DocumentViewDef] WITH(NOLOCK) where [DocumentViewID]=@DocViewID
	end	
	else
	begin
		delete from adm_documentreports where [DocumentViewID]=@DocViewID
		delete from [ADM_DocReportUserRoleMap] where [DocumentViewID]=@DocViewID
		delete from [ADM_DocumentReportDef] where [DocumentViewID]=@DocViewID
		SELECT @CostCenterID=COSTCENTERID FROM  [adm_documentreports] WITH(NOLOCK) where [DocumentViewID]=@DocViewID
	end

    SET @RowsDeleted=@@rowcount
    
    IF(@CostCenterID BETWEEN 40001 AND 49999)
		UPDATE ADM_DocumentTypes SET GUID=NEWID()where CostCenterID=@CostCenterID 
		
	
    
COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=1

RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=1
	END
	ELSE 
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=1
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH





GO
