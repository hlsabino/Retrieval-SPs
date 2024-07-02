USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetLinkedProducts]
	@CostCenterID [bigint] = 0,
	@NodeID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON; 

 		--Check for manadatory paramters  
		IF(@CostCenterID=0 or @NodeID=0)  
		BEGIN   
			RAISERROR('-100',16,1)  
		END  
 
		--Getting product.  
		SELECT  LinkedProductID,LinkType,a.ProductID,  
		b.ProductCode,b.ProductName  
		FROM INV_LinkedProducts a WITH(NOLOCK)   
		join INV_Product b WITH(NOLOCK) on a.ProductID =b.ProductID  
		where a.CostCenterID=@CostCenterID  and NodeID=@NodeID

COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
