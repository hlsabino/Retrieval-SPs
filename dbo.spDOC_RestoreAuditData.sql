USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_RestoreAuditData]
	@DocumentsList [nvarchar](max),
	@DimensionsList [nvarchar](max),
	@PreserveDays [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
--SET NOCOUNT ON;

	DECLARE @sql nvarchar(max),@DbName nvarchar(50),@ArchDbName nvarchar(50)
	select @DbName=DB_NAME(),@ArchDbName=DB_NAME()+'_ARCHIVE'

	if not exists(select name from sys.databases where name=@ArchDbName)
	begin
		return 1
	end

	--Declaration Section    
	CREATE TABLE #TblTemp(ID BIGINT)
	CREATE TABLE #Tbl(ID INT IDENTITY(1,1),FeatureID INT)
	CREATE TABLE #TblINV(ID INT IDENTITY(1,1),FeatureID INT,IsRevise BIT)
	CREATE TABLE #TblACC(ID INT IDENTITY(1,1),FeatureID INT,IsRevise BIT)
	DECLARE @I INT,@CNT INT,@Dt FLOAT
	DECLARE @DtChar nvarchar(20),@cols nvarchar(max),@hcols nvarchar(max),@TblName nvarchar(max)
	
	SET @Dt=floor(convert(float,dateadd(day,-@PreserveDays+1,GETDATE())))
	SET @DtChar=convert(nvarchar,@Dt)
	--select @Dt,dateadd(day,-@PreserveDays+1,GETDATE())
	
		
	--Checking History Table
	SET @TblName=@ArchDbName+'.dbo.INV_DocDetails_History'
	EXEC spADM_COPYTABLE 'INV_DocDetails_History',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.ACC_DocDetails_History'
	EXEC spADM_COPYTABLE 'ACC_DocDetails_History',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.COM_DocCCData_History'
	EXEC spADM_COPYTABLE 'COM_DocCCData_History',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.COM_DocNumData_History'
	EXEC spADM_COPYTABLE 'COM_DocNumData_History',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.COM_DocTextData_History'
	EXEC spADM_COPYTABLE 'COM_DocTextData_History',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.ACC_AccountsHistory'
	EXEC spADM_COPYTABLE 'ACC_AccountsHistory',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.ACC_AccountsExtendedHistory'
	EXEC spADM_COPYTABLE 'ACC_AccountsExtendedHistory',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.INV_ProductHistory'
	EXEC spADM_COPYTABLE 'INV_ProductHistory',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.INV_ProductExtendedHistory'
	EXEC spADM_COPYTABLE 'INV_ProductExtendedHistory',@ArchDbName,@TblName
	
	--SETTINGS
	SET @TblName=@ArchDbName+'.dbo.ADM_FeatureActionRoleMapHistory'
	EXEC spADM_COPYTABLE 'ADM_FeatureActionRoleMapHistory',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.ADM_GlobalPreferences_History'
	EXEC spADM_COPYTABLE 'ADM_GlobalPreferences_History',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.COM_DocumentPreferences_History'
	EXEC spADM_COPYTABLE 'COM_DocumentPreferences_History',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.ADM_UserRoleMapHistory'
	EXEC spADM_COPYTABLE 'ADM_UserRoleMapHistory',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.ADM_CostCenterDef_History'
	EXEC spADM_COPYTABLE 'ADM_CostCenterDef_History',@ArchDbName,@TblName
	
	SET @TblName=@ArchDbName+'.dbo.ADM_DocumentDef_History'
	EXEC spADM_COPYTABLE 'ADM_DocumentDef_History',@ArchDbName,@TblName
	
	
	
	--DELETE DOCUMENTS DATA
	IF LEN(@DocumentsList)>0
	BEGIN
		IF @DocumentsList='ALL'
		BEGIN
			INSERT INTO #TblINV(FeatureID,IsRevise)
			SELECT D.CostCenterID,ISNULL(REV.IsRevise,0)
			FROM ADM_DocumentTypes D WITH(nolock) LEFT JOIN			
			(SELECT CostCenterID,CASE WHEN PrefValue='TRUE' THEN 1 ELSE 0 END IsRevise FROM COM_DocumentPreferences with(nolock)
			WHERE PrefName='EnableRevision') AS REV ON D.CostCenterID=REV.CostCenterID
			WHERE D.IsInventory=1
			
			INSERT INTO #TblACC(FeatureID,IsRevise)
			SELECT D.CostCenterID,ISNULL(REV.IsRevise,0)
			FROM ADM_DocumentTypes D WITH(nolock) LEFT JOIN			
			(SELECT CostCenterID,CASE WHEN PrefValue='TRUE' THEN 1 ELSE 0 END IsRevise FROM COM_DocumentPreferences with(nolock)
			WHERE PrefName='EnableRevision') AS REV ON D.CostCenterID=REV.CostCenterID
			WHERE D.IsInventory=0
		END
		ELSE
		BEGIN		
			INSERT INTO #TblTemp
			EXEC SPSplitString @DocumentsList,','
		
			INSERT INTO #TblINV(FeatureID,IsRevise)
			SELECT D.CostCenterID,ISNULL(REV.IsRevise,0)
			FROM ADM_DocumentTypes D WITH(nolock) LEFT JOIN			
			(SELECT CostCenterID,CASE WHEN PrefValue='TRUE' THEN 1 ELSE 0 END IsRevise FROM COM_DocumentPreferences with(nolock)
			WHERE PrefName='EnableRevision') AS REV ON D.CostCenterID=REV.CostCenterID
			WHERE D.IsInventory=1 AND D.CostCenterID IN (SELECT ID FROM #TblTemp)
			
			INSERT INTO #TblACC(FeatureID,IsRevise)
			SELECT D.CostCenterID,ISNULL(REV.IsRevise,0)
			FROM ADM_DocumentTypes D WITH(nolock) LEFT JOIN			
			(SELECT CostCenterID,CASE WHEN PrefValue='TRUE' THEN 1 ELSE 0 END IsRevise FROM COM_DocumentPreferences with(nolock)
			WHERE PrefName='EnableRevision') AS REV ON D.CostCenterID=REV.CostCenterID
			WHERE D.IsInventory=0 AND D.CostCenterID IN (SELECT ID FROM #TblTemp)
		END

		IF (SELECT COUNT(*) FROM #TblINV WHERE IsRevise=0)>0
		BEGIN
			select @cols='',@hcols=''
			select @cols=@cols+','+QUOTENAME(name),@hcols=@hcols+',CC.'+QUOTENAME(name) from sys.columns where object_id=object_id('COM_DocCCData_History')
			select @cols=substring(@cols,2,len(@cols)-1), @hcols=substring(@hcols,2,len(@hcols)-1)
			set @sql='set identity_insert COM_DocCCData_History ON
INSERT INTO COM_DocCCData_History('+@cols+')
SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.COM_DocCCData_History CC WITH(nolock)
INNER JOIN '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock) ON CC.ModifiedDate=INV.ModifiedDate and CC.INVDocDetailsID=INV.INVDocDetailsID
INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar+'
set identity_insert COM_DocCCData_History OFF'
		--print(@sql)
			exec(@sql)
	
			select @cols='',@hcols=''
			select @cols=@cols+','+QUOTENAME(name),@hcols=@hcols+',NUM.'+QUOTENAME(name) from sys.columns where object_id=object_id('COM_DocNumData_History')
			select @cols=substring(@cols,2,len(@cols)-1), @hcols=substring(@hcols,2,len(@hcols)-1)
			set @sql='set identity_insert COM_DocNumData_History ON
INSERT INTO COM_DocNumData_History('+@cols+')
SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.COM_DocNumData_History NUM WITH(nolock)
INNER JOIN '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock) ON NUM.ModifiedDate=INV.ModifiedDate and NUM.INVDocDetailsID=INV.INVDocDetailsID
INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar+'
set identity_insert COM_DocNumData_History OFF'
			exec(@sql)
		
			select @cols='',@hcols=''
			select @cols=@cols+','+QUOTENAME(name),@hcols=@hcols+',TXT.'+QUOTENAME(name) from sys.columns where object_id=object_id('COM_DocTextData_History')
			select @cols=substring(@cols,2,len(@cols)-1), @hcols=substring(@hcols,2,len(@hcols)-1)
			set @sql='set identity_insert COM_DocTextData_History ON
INSERT INTO COM_DocTextData_History('+@cols+')
SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.COM_DocTextData_History TXT WITH(nolock)
INNER JOIN '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock) ON TXT.ModifiedDate=INV.ModifiedDate and TXT.INVDocDetailsID=INV.INVDocDetailsID
INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar+'
set identity_insert COM_DocTextData_History OFF'
			exec(@sql)
		
			select @cols='',@hcols=''
			select @cols=@cols+','+QUOTENAME(name),@hcols=@hcols+',INV.'+QUOTENAME(name) from sys.columns where object_id=object_id('INV_DocDetails_History')
			select @cols=substring(@cols,2,len(@cols)-1), @hcols=substring(@hcols,2,len(@hcols)-1)
			set @sql='set identity_insert INV_DocDetails_History ON
INSERT INTO INV_DocDetails_History('+@cols+')		
SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock)
INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar+'
set identity_insert INV_DocDetails_History OFF'
			exec(@sql)
			
			set @sql='SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock)
INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar
			exec(@sql)
		
			set @sql='DELETE CC FROM '+@ArchDbName+'.dbo.COM_DocCCData_History CC WITH(nolock)
			INNER JOIN '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock) ON CC.ModifiedDate=INV.ModifiedDate and CC.INVDocDetailsID=INV.INVDocDetailsID
			INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
			WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar
			exec(@sql)
		
			set @sql='DELETE NUM FROM '+@ArchDbName+'.dbo.COM_DocNumData_History NUM WITH(nolock)
			INNER JOIN '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock) ON NUM.ModifiedDate=INV.ModifiedDate and NUM.INVDocDetailsID=INV.INVDocDetailsID
			INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
			WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar
			exec(@sql)
		
			set @sql='DELETE TXT FROM '+@ArchDbName+'.dbo.COM_DocTextData_History TXT WITH(nolock)
			INNER JOIN '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock) ON TXT.ModifiedDate=INV.ModifiedDate and TXT.INVDocDetailsID=INV.INVDocDetailsID
			INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
			WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar
			exec(@sql)
		
			set @sql='DELETE INV FROM '+@ArchDbName+'.dbo.INV_DocDetails_History INV WITH(nolock)
			INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID
			WHERE isnull(INV.ModifiedDate,INV.CreatedDate)>='+@DtChar
			exec(@sql)
		
		END
		
		--select * from ACC_DocDetails_History
		IF (SELECT COUNT(*) FROM #TblACC WHERE IsRevise=0)>0
		BEGIN
			select @cols='',@hcols=''
			select @cols=@cols+','+QUOTENAME(name),@hcols=@hcols+',CC.'+QUOTENAME(name) from sys.columns where object_id=object_id('COM_DocCCData_History')
			select @cols=substring(@cols,2,len(@cols)-1), @hcols=substring(@hcols,2,len(@hcols)-1)
			set @sql='set identity_insert COM_DocCCData_History ON
INSERT INTO COM_DocCCData_History('+@cols+')
SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.COM_DocCCData_History CC WITH(nolock)
INNER JOIN '+@ArchDbName+'.dbo.ACC_DocDetails_History ACC WITH(nolock) ON CC.ModifiedDate=ACC.ModifiedDate and CC.ACCDocDetailsID=ACC.ACCDocDetailsID
INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID
WHERE isnull(ACC.ModifiedDate,ACC.CreatedDate)>='+@DtChar+'
set identity_insert COM_DocCCData_History OFF'
				exec(@sql)
				
			select @cols='',@hcols=''
			select @cols=@cols+','+QUOTENAME(name),@hcols=@hcols+',NUM.'+QUOTENAME(name) from sys.columns where object_id=object_id('COM_DocNumData_History')
			select @cols=substring(@cols,2,len(@cols)-1), @hcols=substring(@hcols,2,len(@hcols)-1)
			set @sql='set identity_insert COM_DocNumData_History ON
INSERT INTO COM_DocNumData_History('+@cols+')
SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.COM_DocNumData_History NUM WITH(nolock)
INNER JOIN '+@ArchDbName+'.dbo.ACC_DocDetails_History ACC WITH(nolock) ON NUM.ModifiedDate=ACC.ModifiedDate and NUM.ACCDocDetailsID=ACC.ACCDocDetailsID
INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID
WHERE isnull(ACC.ModifiedDate,ACC.CreatedDate)>='+@DtChar+'
set identity_insert COM_DocNumData_History OFF'
			exec(@sql)
			
			select @cols='',@hcols=''
			select @cols=@cols+','+QUOTENAME(name),@hcols=@hcols+',TXT.'+QUOTENAME(name) from sys.columns where object_id=object_id('COM_DocTextData_History')
			select @cols=substring(@cols,2,len(@cols)-1), @hcols=substring(@hcols,2,len(@hcols)-1)
			set @sql='
set identity_insert COM_DocTextData_History ON
INSERT INTO COM_DocTextData_History('+@cols+')
SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.COM_DocTextData_History TXT WITH(nolock)
INNER JOIN '+@ArchDbName+'.dbo.ACC_DocDetails_History ACC WITH(nolock) ON TXT.ModifiedDate=ACC.ModifiedDate and TXT.ACCDocDetailsID=ACC.ACCDocDetailsID
INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID
WHERE isnull(ACC.ModifiedDate,ACC.CreatedDate)>='+@DtChar+'
set identity_insert COM_DocTextData_History OFF'
			exec(@sql)
			
			select @cols='',@hcols=''
			select @cols=@cols+','+QUOTENAME(name),@hcols=@hcols+',ACC.'+QUOTENAME(name) from sys.columns where object_id=object_id('ACC_DocDetails_History')
			select @cols=substring(@cols,2,len(@cols)-1), @hcols=substring(@hcols,2,len(@hcols)-1)
			set @sql='
set identity_insert ACC_DocDetails_History ON
INSERT INTO ACC_DocDetails_History('+@cols+')
SELECT '+@hcols+' FROM '+@ArchDbName+'.dbo.ACC_DocDetails_History ACC WITH(nolock)
INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID
WHERE isnull(ACC.ModifiedDate,ACC.CreatedDate)>='+@DtChar+'
set identity_insert ACC_DocDetails_History OFF'
			exec(@sql)


			set @sql='DELETE CC FROM '+@ArchDbName+'.dbo.COM_DocCCData_History CC WITH(nolock)
			INNER JOIN '+@ArchDbName+'.dbo.ACC_DocDetails_History ACC WITH(nolock) ON CC.ModifiedDate=ACC.ModifiedDate and CC.ACCDocDetailsID=ACC.ACCDocDetailsID
			INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID
			WHERE isnull(ACC.ModifiedDate,ACC.CreatedDate)>='+@DtChar
			exec(@sql)
			
			set @sql='DELETE NUM FROM '+@ArchDbName+'.dbo.COM_DocNumData_History NUM WITH(nolock)
			INNER JOIN '+@ArchDbName+'.dbo.ACC_DocDetails_History ACC WITH(nolock) ON NUM.ModifiedDate=ACC.ModifiedDate and NUM.ACCDocDetailsID=ACC.ACCDocDetailsID
			INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID
			WHERE isnull(ACC.ModifiedDate,ACC.CreatedDate)>='+@DtChar
			exec(@sql)
			
			set @sql='DELETE TXT FROM '+@ArchDbName+'.dbo.COM_DocTextData_History TXT WITH(nolock)
			INNER JOIN '+@ArchDbName+'.dbo.ACC_DocDetails_History ACC WITH(nolock) ON TXT.ModifiedDate=ACC.ModifiedDate and TXT.ACCDocDetailsID=ACC.ACCDocDetailsID
			INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID
			WHERE isnull(ACC.ModifiedDate,ACC.CreatedDate)>='+@DtChar
			exec(@sql)
			
			set @sql='DELETE ACC FROM '+@ArchDbName+'.dbo.ACC_DocDetails_History ACC WITH(nolock)
			INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID
			WHERE isnull(ACC.ModifiedDate,ACC.CreatedDate)>='+@DtChar
			exec(@sql)
		END
	END
	
	
	--DELETE DIMENSIONS DATA
	IF LEN(@DimensionsList)>0
	BEGIN
		INSERT INTO #Tbl
		EXEC SPSplitString @DimensionsList,','
		--SELECT @DimensionsList
		declare @featureid bigint
		set @I=1
		select @CNT=COUNT(*) from #Tbl WITH(nolock)
		while @I<=@CNT
		BEGIN
			select @featureid=FeatureID from #Tbl WITH(nolock) where ID=@I
			IF (@featureid=2)
			BEGIN
				select @cols=''
				select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('ACC_AccountsHistory')
				select @cols=substring(@cols,2,len(@cols)-1)
				set @sql='set identity_insert ACC_AccountsHistory ON
			INSERT INTO ACC_AccountsHistory('+@cols+')
			SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.ACC_AccountsHistory with(nolock)
			WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
			set identity_insert ACC_AccountsHistory OFF'
			--print(@sql)
				exec(@sql)
				
				select @cols=''
				select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('ACC_AccountsExtendedHistory')
				select @cols=substring(@cols,2,len(@cols)-1)
				set @sql='set identity_insert ACC_AccountsExtendedHistory ON				
			INSERT INTO ACC_AccountsExtendedHistory('+@cols+')
			SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.ACC_AccountsExtendedHistory with(nolock)
			WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
			set identity_insert ACC_AccountsExtendedHistory OFF'
				exec(@sql)
				
				set @sql='Delete from '+@ArchDbName+'.dbo.ACC_AccountsHistory where isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
				Delete from '+@ArchDbName+'.dbo.ACC_AccountsExtendedHistory where isnull(ModifiedDate, CreatedDate)>='+@DtChar
				exec(@sql)
			END
			ELSE IF (@featureid=3)
			BEGIN
				select @cols=''
				select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('INV_ProductHistory')
				select @cols=substring(@cols,2,len(@cols)-1)
				set @sql='set identity_insert INV_ProductHistory ON
			INSERT INTO INV_ProductHistory('+@cols+')
			SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.INV_ProductHistory with(nolock)
			WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
			set identity_insert INV_ProductHistory OFF'
				exec(@sql)
				
				select @cols=''
				select @cols=@cols+','+QUOTENAME(name) from sys.columns where object_id=object_id('INV_ProductExtendedHistory')
				select @cols=substring(@cols,2,len(@cols)-1)
				set @sql='set identity_insert INV_ProductExtendedHistory ON				
			INSERT INTO INV_ProductExtendedHistory('+@cols+')
			SELECT '+@cols+' FROM '+@ArchDbName+'.dbo.INV_ProductExtendedHistory with(nolock)
			WHERE isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
			set identity_insert INV_ProductExtendedHistory OFF'
				exec(@sql)
				
				set @sql='Delete from '+@ArchDbName+'.dbo.INV_ProductHistory where isnull(ModifiedDate, CreatedDate)>='+@DtChar+'
				Delete from '+@ArchDbName+'.dbo.INV_ProductExtendedHistory where isnull(ModifiedDate, CreatedDate)>='+@DtChar
				exec(@sql)
			END
			ELSE IF (@featureid=93 OR @featureid=94 OR @featureid=95)
			BEGIN
				set @sql='EXEC [spREN_RestoreAuditData] '''+@ArchDbName+''','+CONVERT(NVARCHAR,@featureid)+','''+@DtChar+''','+CONVERT(NVARCHAR,@UserID)+','+CONVERT(NVARCHAR,@LangID)
				exec(@sql)
			END
			set @I=@I+1
		END
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
