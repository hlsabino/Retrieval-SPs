USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetDeprBookDetails]
	@DeprBookID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	SELECT a.DeprBookID, a.DeprBookCode, a.DeprBookName,a.AveragingMethod, isnull(a.Description,'') as Description,
	a.DeprBookMethod, dm.Name as DeprMethod,a.DeprMethodBasedOn,a.BasedOnValue, 
	a.SalvageValueType,a.SalvageValue,a.IncludeSalvageInDepr,
	a.StatusID, s.Status , a.GUID	
	FROM  ACC_DeprBook a with(nolock) INNER JOIN COM_Status AS s with(nolock) ON a.StatusID = s.StatusID 
	join ACC_DepreciationMethods DM with(nolock) on a.DeprBookMethod=dm.DepreciationMethodID
	WHERE DeprBookID=@DeprBookID
	 
SET NOCOUNT OFF;
RETURN @DeprBookID
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
