USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SaveResources]
	@DATA [nvarchar](max),
	@CompanyGUId [nvarchar](max),
	@UserName [nvarchar](max),
	@UserID [nvarchar](max),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section
	DECLARE @XML XML
	SET @XML=@DATA 

	update COM_LanguageResources
	set ResourceData= A.value('@ResourceEng','NVARCHAR(500)')
	from @XML.nodes('/XML/Row') as DATA(A)	
	WHere ResourceID=A.value('@ResourceID','bigint') and LanguageID=1
	
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[FEATURE])
	SELECT [ResourceID],[ResourceName],1,'English',ResourceEng,[GUID],[Description],@UserName,[CreatedDate],[FEATURE]
	FROM [Com_LanguageResources] WITH(NOLOCK)
	JOIN (SELECT A.value('@ResourceID','bigint') RID ,A.value('@ResourceEng','NVARCHAR(500)') ResourceEng from @XML.nodes('/XML/Row') as DATA(A)	
	LEFT JOIN COM_LanguageResources LR WITH(NOLOCK) ON LR.ResourceID=A.value('@ResourceID','bigint') AND LR.LanguageID=1
	WHERE LR.ResourceID IS NULL) AS T ON [ResourceID]=RID
	
	update COM_LanguageResources
	set ResourceData= A.value('@ResourceAra','NVARCHAR(500)')
	from @XML.nodes('/XML/Row') as DATA(A)	
	WHere ResourceID=A.value('@ResourceID','bigint') and LanguageID=2
		 
	INSERT INTO [Com_LanguageResources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[FEATURE])
	SELECT [ResourceID],[ResourceName],2,'Arabic',ResourceAra,[GUID],[Description],@UserName,[CreatedDate],[FEATURE]
	FROM [Com_LanguageResources] WITH(NOLOCK)
	JOIN (SELECT A.value('@ResourceID','bigint') RID ,A.value('@ResourceAra','NVARCHAR(500)') ResourceAra from @XML.nodes('/XML/Row') as DATA(A)	
	LEFT JOIN COM_LanguageResources LR WITH(NOLOCK) ON LR.ResourceID=A.value('@ResourceID','bigint') AND LR.LanguageID=2
	WHERE LR.ResourceID IS NULL) AS T ON [ResourceID]=RID	 
		
		
COMMIT TRANSACTION   
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK)
 WHERE ErrorNumber=100
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	ROLLBACK TRANSACTION
	SET NOCOUNT OFF  
	RETURN -999   
END CATCH 




GO
