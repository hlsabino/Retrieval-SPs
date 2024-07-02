USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetAssignedSupervisorID]
	@p1 [nvarchar](max),
	@p2 [nvarchar](max),
	@p3 [nvarchar](max),
	@p4 [nvarchar](max),
	@p5 [nvarchar](max),
	@p7 [nvarchar](max),
	@p8 [nvarchar](max),
	@p9 [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1,
	@DocID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON

			Declare @SQL nvarchar(max)

			--Prepare query	
			SET @SQL='SELECT SP.NodeID SupervisorID
FROM REN_Contract C WITH(NOLOCK)
JOIN REN_Property P WITH(NOLOCK) ON C.PropertyID=P.NodeID
JOIN REN_Units U WITH(NOLOCK) ON C.UnitID=U.UnitID
JOIN REN_Tenant T WITH(NOLOCK) ON C.TenantID=T.TenantID
JOIN COM_CCCCData CCD WITH(NOLOCK) ON CCD.NodeID=U.UnitID AND CCD.CostCenterID=93
JOIN COM_CC50158 SP WITH(NOLOCK) ON CCD.CCNID158=SP.NodeID
WHERE C.CostCenterID=95 AND C.RefContractID=0 AND C.StatusID IN (426,427)
AND (CONVERT(FLOAT,GETDATE()) BETWEEN C.StartDate AND ISNULL(ISNULL(C.TerminationDate,C.RefundDate),C.EndDate) or  (C.EndDate <CONVERT(FLOAT,GETDATE()) and  FMTAfterEndDate=1))
AND T.CCNodeID= ' + @p1

		 	--Execute statement
			Exec sp_executesql @SQL
			 

 
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
 SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
