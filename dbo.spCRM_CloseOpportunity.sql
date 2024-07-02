USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_CloseOpportunity]
	@Oppurtunity [nvarchar](max),
	@StatusID [int],
	@EstimatedRevenue [nvarchar](50),
	@CloseDate [nvarchar](50),
	@Reason [int] = NULL,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;    
	DECLARE @SQL NVARCHAR(MAX)
	SET @Oppurtunity=@Oppurtunity+'0'
	if(@Oppurtunity IS NOT NULL AND @Oppurtunity<>'')
	BEGIN
		SET @SQL='UPDATE OPR SET StatusID='+CONVERT(NVARCHAR,@StatusID)+',EstimatedRevenue='+CONVERT(NVARCHAR,@EstimatedRevenue)+'		
		,CloseDate=CONVERT(FLOAT,CONVERT(DATETIME,CONVERT(NVARCHAR,'''+@CloseDate+''')))
		FROM CRM_Opportunities OPR WITH(NOLOCK) WHERE OpportunityID IN ('+CONVERT(NVARCHAR,@Oppurtunity)+')'
		PRINT (@SQL)
		EXEC(@SQL)
	END	
 
COMMIT TRANSACTION    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;     
RETURN @StatusID
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
