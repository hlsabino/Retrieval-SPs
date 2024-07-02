USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_DeletePrefix]
	@CCCodeID [bigint],
	@CostCenterID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;

	--Declaration Section
	declare @Prefix Nvarchar(200)

	select @Prefix=CodePrefix from COM_CostCenterCodeDef WITH(NOLOCK) 
	where CostCenterCodeID=@CCCodeID 
	
	if exists(select InvDocDetailsID from [INV_DocDetails] with(nolock)
		WHERE (CostCenterID=@CostCenterID OR CostCenterID IN (SELECT ISNULL(CostCenterID,@CostCenterID) 
															  FROM ADM_DocumentTypes WITH(NOLOCK)
															  WHERE Series=@CostCenterID )) AND DocPrefix=@Prefix
		UNION
		select AccDocDetailsID from [ACC_DocDetails] with(nolock)
		WHERE (CostCenterID=@CostCenterID OR CostCenterID IN (SELECT ISNULL(CostCenterID,@CostCenterID) 
															  FROM ADM_DocumentTypes WITH(NOLOCK)
															  WHERE Series=@CostCenterID )) AND DocPrefix=@Prefix 
		UNION
		select AccDocDetailsID from [ACC_DocDetails] with(nolock)
		WHERE CostCenterID IN (SELECT ISNULL(CostCenterID,@CostCenterID) FROM ADM_DocumentTypes WITH(NOLOCK)
							   WHERE Series=1 AND (ConvertAs= @CostCenterID OR Bounce=@CostCenterID)) AND DocPrefix=@Prefix 
		)
			RAISERROR('-404',16,1)
	else
		delete from COM_CostCenterCodeDef where CostCenterCodeID=@CCCodeID
	 
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
