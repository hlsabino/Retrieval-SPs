USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_DeleteAuditData]
	@Archive [bit],
	@ArchDBName [nvarchar](50),
	@featureid [int],
	@Dt [float],
	@DtChar [nvarchar](20),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
--SET NOCOUNT ON;    

	DECLARE @sql nvarchar(max),@TblName nvarchar(max)

	IF @Archive=1
	BEGIN	
		--Checking History Table
		SET @TblName=@ArchDBName+'.dbo.REN_Contract_History'
		EXEC spADM_COPYTABLE 'REN_Contract_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.REN_ContractExtended_History'
		EXEC spADM_COPYTABLE 'REN_ContractExtended_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.REN_ContractParticulars_History'
		EXEC spADM_COPYTABLE 'REN_ContractParticulars_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.REN_ContractPayTerms_History'
		EXEC spADM_COPYTABLE 'REN_ContractPayTerms_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.REN_TenantHistory'
		EXEC spADM_COPYTABLE 'REN_TenantHistory',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.REN_TenantExtendedHistory'
		EXEC spADM_COPYTABLE 'REN_TenantExtendedHistory',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.REN_UnitsHistory'
		EXEC spADM_COPYTABLE 'REN_UnitsHistory',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.REN_UnitsExtendedHistory'
		EXEC spADM_COPYTABLE 'REN_UnitsExtendedHistory',@ArchDBName,@TblName
	END

	IF (@featureid=93)
	BEGIN
		IF @Archive=1
		BEGIN
			set @sql='INSERT INTO '+@ArchDBName+'.dbo.REN_UnitsHistory
	SELECT * FROM REN_UnitsHistory with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
			exec(@sql)
			
			set @sql='INSERT INTO '+@ArchDBName+'.dbo.REN_UnitsExtendedHistory
	SELECT * FROM REN_UnitsExtendedHistory with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
			exec(@sql)
		END
		Delete from REN_UnitsHistory where isnull(ModifiedDate, CreatedDate)<@Dt
		Delete from REN_UnitsExtendedHistory where isnull(ModifiedDate, CreatedDate)<@Dt
	END
	ELSE IF (@featureid=94)
	BEGIN
		IF @Archive=1
		BEGIN
			set @sql='INSERT INTO '+@ArchDBName+'.dbo.REN_TenantHistory
	SELECT * FROM REN_TenantHistory with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
			exec(@sql)
			
			set @sql='INSERT INTO '+@ArchDBName+'.dbo.REN_TenantExtendedHistory
	SELECT * FROM REN_TenantExtendedHistory with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
			exec(@sql)
		END
		Delete from REN_TenantHistory where isnull(ModifiedDate, CreatedDate)<@Dt
		Delete from REN_TenantExtendedHistory where isnull(ModifiedDate, CreatedDate)<@Dt
	END
	ELSE IF (@featureid=95)
	BEGIN
		IF @Archive=1
		BEGIN
			set @sql='INSERT INTO '+@ArchDBName+'.dbo.REN_Contract_History
	SELECT * FROM REN_Contract_History with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
			exec(@sql)
			
			set @sql='INSERT INTO '+@ArchDBName+'.dbo.REN_ContractExtended_History
	SELECT * FROM REN_ContractExtended_History with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
			exec(@sql)
			
			set @sql='INSERT INTO '+@ArchDBName+'.dbo.REN_ContractParticulars_History
	SELECT * FROM REN_ContractParticulars_History with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
			exec(@sql)
			
			set @sql='INSERT INTO '+@ArchDBName+'.dbo.REN_ContractPayTerms_History
	SELECT * FROM REN_ContractPayTerms_History with(nolock)
	WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
			exec(@sql)
		END
		Delete from REN_Contract_History where isnull(ModifiedDate, CreatedDate)<@Dt
		Delete from REN_ContractExtended_History where isnull(ModifiedDate, CreatedDate)<@Dt
		Delete from REN_ContractParticulars_History where isnull(ModifiedDate, CreatedDate)<@Dt
		Delete from REN_ContractPayTerms_History where isnull(ModifiedDate, CreatedDate)<@Dt
	END

COMMIT TRANSACTION
--ROLLBACK TRANSACTION

--SET NOCOUNT OFF; 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID  
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
