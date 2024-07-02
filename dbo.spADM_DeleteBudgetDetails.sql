USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteBudgetDetails]
	@BudgetID [bigint] = 0,
	@CallFromDoc [bit] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

	--Declaration Section
	DECLARE @HasAccess bit,@RowsDeleted bigint,@lft bigint,@rgt bigint,@Width bigint

	--SP Required Parameters Check
	if(@BudgetID=0)
	BEGIN
		RAISERROR('-100',16,1)
	END
	
	IF exists(SELECT * FROM ADM_DocumentBudgets WITH(NOLOCK) WHERE BudgetID=@BudgetID)
		RAISERROR('-139',16,1)
	
	IF @CallFromDoc=0 and exists(SELECT * FROM COM_DocBridge with(nolock) where RefDimensionID=101 and RefDimensionNodeID=@BudgetID)
		RAISERROR('-140',16,1)
	
	DELETE FROM COM_BudgetAlloc where BudgetDefID=@BudgetID;
	
	DELETE FROM COM_BudgetDefDims where BudgetDefID=@BudgetID;

	--DELETE FROM COM_BudgetDimValues where BudgetDefID=@BudgetID;

	DELETE FROM COM_BudgetDimRelations where BudgetDefID=@BudgetID;

	
	--Fetch left, right extent of Node along with width.
	SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
	FROM COM_BudgetDef WITH(NOLOCK) WHERE BudgetDefID=@BudgetID
	
	--Delete From Com_BudgetDef--
	DELETE FROM COM_BudgetDef where BudgetDefID=@BudgetID;
	
	--Update left and right extent to set the tree
	UPDATE COM_BudgetDef SET rgt = rgt - @Width WHERE rgt > @rgt;
	UPDATE COM_BudgetDef SET lft = lft - @Width WHERE lft > @rgt;
	
	SET @RowsDeleted=@@rowcount

COMMIT TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN @RowsDeleted
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
