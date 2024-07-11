USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetMarketingDashBoard]
	@CreatedBy [nvarchar](300) = -100,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON
	
	EXEC spADM_GetUserNamebyOwner @UserID,@LangID
	DECLARE @SQL NVARCHAR(MAX),@WHERE NVARCHAR(300)
	--LEAD
	SET @WHERE=''
	IF @CreatedBy<>'-100'
	BEGIN
		SET @WHERE=' WHERE CRM_LEADS.CREATEDBY='''+convert(nvarchar,@CreatedBy)+''''
	END
	 
	SET @SQL='
	SELECT COUNT(*) [SUM],isnull(ST.STATUS,''Empty'') STATUS FROM CRM_LEADS WITH(NOLOCK)
	LEFT JOIN COM_Status ST ON ST.STATUSID=CRM_LEADS.STATUSID  '+@WHERE+'
	GROUP BY CRM_LEADS.STATUSID,STATUS 
	UNION 
	SELECT COUNT(*),''All'' FROM CRM_LEADS with(nolock) '+@WHERE+' order  by [SUM] desc'  
	print @SQL
	exec(@SQL)
	
	--OPPORTUNITY
	SET @WHERE=''
	SET @SQL=''
	IF @CreatedBy<>'-100'
	BEGIN
		SET @WHERE=' WHERE CRM_Opportunities.CREATEDBY='''+convert(nvarchar,@CreatedBy)+''''
	END
	 
	SET @SQL='
	SELECT COUNT(*) [SUM],isnull(ST.STATUS,''Empty'') STATUS FROM CRM_Opportunities WITH(NOLOCK)
	LEFT JOIN COM_Status ST ON ST.STATUSID=CRM_Opportunities.STATUSID  '+@WHERE+'
	GROUP BY CRM_Opportunities.STATUSID,STATUS 
	UNION 
	SELECT COUNT(*),''All'' FROM CRM_Opportunities with(nolock) '+@WHERE+' order  by [SUM] desc'  
	print @SQL
	exec(@SQL)
	
	 



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
