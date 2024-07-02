﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetContractDetailsAtCases]
	@CUSTOMERID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON


SELECT DISTINCT C.DOCID,C.VOUCHERNO FROM INV_DOCDETAILS C WITH(NOLOCK) 
JOIN ADM_Documenttypes DT WITH(NOLOCK) ON DT.CostCenterID=C.CostCenterID
WHERE DT.DOCUMENTTYPEID=35 AND C.DEBITACCOUNT=@CUSTOMERID

SELECT P.ProductName,  C.ProductID,DOCID FROM INV_DOCDETAILS C WITH(NOLOCK)
JOIN ADM_Documenttypes DT WITH(NOLOCK) ON DT.CostCenterID=C.CostCenterID
LEFT JOIN INV_Product AS P ON P.ProductID = C.ProductID 
WHERE DT.DOCUMENTTYPE=35 AND C.DEBITACCOUNT=@CUSTOMERID
                      
			
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
