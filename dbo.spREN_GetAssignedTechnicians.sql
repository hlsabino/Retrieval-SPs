USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetAssignedTechnicians]
	@FMNodeID [nvarchar](max),
	@DocID [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON

			Declare @SQL nvarchar(max)

			--Prepare query	
			SET @SQL=' select distinct  convert(BIGINT,a.NodeID) NodeID,a.Name,a.Code from COM_CC50159 a WITH(NOLOCK)
			LEFT JOIN COM_CCCCData CC WITH(NOLOCK) ON CC.COSTCENTERID=50159 AND CC.NODEID= a.NodeID
   WHERE  a.IsGroup=0  AND (CCNID158='+@FMNodeID+') and a.NodeID>0 and a.NodeID>=1000 or a.NodeID=1000
    ORDER BY a.Name  ,NodeID'

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
