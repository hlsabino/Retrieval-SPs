USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportDataToAccReportTemplate]
	@DATAXML [nvarchar](max),
	@AccountName [nvarchar](max) = null,
	@AccountCode [nvarchar](max) = null,
	@IsCode [bit] = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  
		DECLARE @Dt FLOAT ,@XML XML,@TSQL NVARCHAR(MAX),@SQL NVARCHAR(MAX),@TABLEname NVARCHAR(300),@return_value INT, @AccountID BIGINT
		SET @Dt=CONVERT(FLOAT,GETDATE())
		if(@IsCode=1)
			select @AccountID=AccountID from ACC_Accounts with(nolock) where AccountCode=@AccountCode
		else
			select @AccountID=AccountID from ACC_Accounts with(nolock) where AccountName=@AccountName
		 
	 	IF (@DATAXML IS NOT NULL AND @DATAXML <> '')
		BEGIN  
			set @XML=@DATAXML 
			if not exists (select accountid from ACC_ReportTemplate r with(nolock)
			join @XML.nodes('/XML/Row') as Data(X) on r.Accountid=@AccountID and r.templatenodeid= X.value('@TemplateNodeID','bigint')
			and r.drnodeid= X.value('@DrNodeID','bigint') and  r.crnodeid= X.value('@CrNodeID','bigint')
			and r.RTDATE =Convert (float,X.value('@RTDate','DateTime')))
				insert into ACC_ReportTemplate([TemplateNodeID],[AccountID],[DrNodeID],[CrNodeID],[CreatedBy],
				[CreatedDate], RTDate,RTGroup)
				select X.value('@TemplateNodeID','bigint'),@AccountID,X.value('@DrNodeID','bigint'),
				X.value('@CrNodeID','bigint'),@UserName,@Dt	,Convert (float,X.value('@RTDate','DateTime')),X.value('@RTGroup','nvarchar(50)')
				FROM @XML.nodes('/XML/Row') as Data(X) 	 
		END
		
	 
	  
	  
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;  
RETURN @AccountID
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
