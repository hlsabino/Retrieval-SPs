USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_RestoreAuditData]
	@ArchDbName [nvarchar](50),
	@featureid [int],
	@DtChar [nvarchar](20),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
--SET NOCOUNT ON;

	DECLARE @sql nvarchar(max),@cols nvarchar(max)

	IF (@featureid=93)
	BEGIN
		select @cols=''
		select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('REN_UnitsHistory')
		select @cols=substring(@cols,2,len(@cols)-1)
		set @sql='set identity_insert REN_UnitsHistory ON
	INSERT INTO REN_UnitsHistory('+@cols+')
	SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.REN_UnitsHistory with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
	set identity_insert REN_UnitsHistory OFF'
	--print(@sql)
		exec(@sql)
		
		select @cols=''
		select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('REN_UnitsExtendedHistory')
		select @cols=substring(@cols,2,len(@cols)-1)
		set @sql='set identity_insert REN_UnitsExtendedHistory ON				
	INSERT INTO REN_UnitsExtendedHistory('+@cols+')
	SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.REN_UnitsExtendedHistory with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
	set identity_insert REN_UnitsExtendedHistory OFF'
		exec(@sql)
		
		set @sql='Delete from '+@ArchDbName+'.dbo.REN_UnitsHistory where isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
		Delete from '+@ArchDbName+'.dbo.REN_UnitsExtendedHistory where isnull(ModifiedDate, CreatedDate)>='+@DtChar
		exec(@sql)
	END
	ELSE IF (@featureid=94)
	BEGIN
		select @cols=''
		select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('REN_TenantHistory')
		select @cols=substring(@cols,2,len(@cols)-1)
		set @sql='set identity_insert REN_TenantHistory ON
	INSERT INTO REN_TenantHistory('+@cols+')
	SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.REN_TenantHistory with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
	set identity_insert REN_TenantHistory OFF'
		exec(@sql)
		
		select @cols=''
		select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('REN_TenantExtendedHistory')
		select @cols=substring(@cols,2,len(@cols)-1)
		set @sql='set identity_insert REN_TenantExtendedHistory ON				
	INSERT INTO REN_TenantExtendedHistory('+@cols+')
	SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.REN_TenantExtendedHistory with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
	set identity_insert REN_TenantExtendedHistory OFF'
		exec(@sql)
		
		set @sql='Delete from '+@ArchDbName+'.dbo.REN_TenantHistory where isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
		Delete from '+@ArchDbName+'.dbo.REN_TenantExtendedHistory where isnull(ModifiedDate, CreatedDate)>='+@DtChar
		exec(@sql)
	END
	IF (@featureid=95)
	BEGIN
		select @cols=''
		select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('REN_Contract_History')
		select @cols=substring(@cols,2,len(@cols)-1)
		set @sql='set identity_insert REN_Contract_History ON
	INSERT INTO REN_Contract_History('+@cols+')
	SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.REN_Contract_History with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
	set identity_insert REN_Contract_History OFF'
	--print(@sql)
		exec(@sql)
		
		select @cols=''
		select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('REN_ContractExtended_History')
		select @cols=substring(@cols,2,len(@cols)-1)
		set @sql='set identity_insert REN_ContractExtended_History ON				
	INSERT INTO REN_ContractExtended_History('+@cols+')
	SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.REN_ContractExtended_History with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
	set identity_insert REN_ContractExtended_History OFF'
		exec(@sql)
		
		set @sql='Delete from '+@ArchDbName+'.dbo.REN_Contract_History where isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
		Delete from '+@ArchDbName+'.dbo.REN_ContractExtended_History where isnull(ModifiedDate, CreatedDate)>='+@DtChar
		exec(@sql)

		select @cols=''
		select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('REN_ContractParticulars_History')
		select @cols=substring(@cols,2,len(@cols)-1)
		set @sql='set identity_insert REN_ContractParticulars_History ON
	INSERT INTO REN_ContractParticulars_History('+@cols+')
	SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.REN_ContractParticulars_History with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
	set identity_insert REN_ContractParticulars_History OFF'
		exec(@sql)
		
		select @cols=''
		select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('REN_ContractPayTerms_History')
		select @cols=substring(@cols,2,len(@cols)-1)
		set @sql='set identity_insert REN_ContractPayTerms_History ON				
	INSERT INTO REN_ContractPayTerms_History('+@cols+')
	SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.REN_ContractPayTerms_History with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
	set identity_insert REN_ContractPayTerms_History OFF'
		exec(@sql)
		
		set @sql='Delete from '+@ArchDbName+'.dbo.REN_ContractParticulars_History where isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
		Delete from '+@ArchDbName+'.dbo.REN_ContractPayTerms_History where isnull(ModifiedDate, CreatedDate)>='+@DtChar
		exec(@sql)
	END

 
COMMIT TRANSACTION
--ROLLBACK TRANSACTION

--SET NOCOUNT OFF; 
SELECT 'Restored Archive Successfully' ErrorMessage,100 ErrorNumber
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
