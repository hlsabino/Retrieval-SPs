USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetProductSubstitutes]
	@ProductID [int] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
 
	SELECT SP.SProductID,P.ProductName,P.ProductCode,SP.SubstituteGroupID GroupID,L.Name [Type],L.NodeID STypeID,0 IsUsed,ISNULL(S.SNo,0) SNo
	FROM INV_ProductSubstitutes S WITH(NOLOCK)   
	INNER JOIN INV_ProductSubstitutes SP WITH(NOLOCK) on SP.ProductID=S.ProductID
	INNER JOIN INV_Product P WITH(NOLOCK) on SP.SProductID=P.ProductID
	INNER JOIN COM_Lookup L WITH(NOLOCK) on SP.SubstituteGroupID=L.NodeID
	WHERE S.SProductID=@ProductID and SP.SProductID!=@ProductID
	UNION
	SELECT S.ProductID,P.ProductName,P.ProductCode,S.SubstituteGroupID GroupID,L.Name [Type],L.NodeID STypeID,1 IsUsed,ISNULL(S.SNo,0) SNo
	FROM INV_ProductSubstitutes S WITH(NOLOCK)   
	INNER JOIN INV_Product P WITH(NOLOCK) on S.ProductID=P.ProductID
	INNER JOIN COM_Lookup L WITH(NOLOCK) on S.SubstituteGroupID=L.NodeID
	WHERE S.SProductID=@ProductID
	order by IsUsed desc,STypeID,ProductName
     
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
