﻿USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetPostingGroupDetails]
	@PostingGroupID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON
		 
		--Getting data from Accounts main table
	SELECT a.PostingGroupID, a.PostGroupCode, a.PostGroupName, a.StatusID, a.PostGroupTypeID, a.PostGroupTypeName, a.AcqnCostACCID, 
           a.AccumDeprACCID, a.AcqnCostDispACCID, a.AccumDeprDispACCID, a.GainsDispACCID, a.LossDispACCID, a.MaintExpenseACCID, 
           a.DeprExpenseACCID,a.GUID, s.Status
	FROM   ACC_PostingGroup AS a INNER JOIN COM_Status AS s ON a.StatusID = s.StatusID
	WHERE PostingGroupID=@PostingGroupID
		
SET NOCOUNT OFF;
RETURN @PostingGroupID
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

SET NOCOUNT OFF  
RETURN -999   
END CATCH  






GO
