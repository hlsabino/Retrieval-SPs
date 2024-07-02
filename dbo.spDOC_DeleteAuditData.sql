USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_DeleteAuditData]
	@Archive [bit],
	@DocumentsList [nvarchar](max),
	@DimensionsList [nvarchar](max),
	@PreserveDays [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
DECLARE @DbName nvarchar(50),@sql nvarchar(max),@ArchDBName nvarchar(50)
set @DbName=DB_NAME()
set @ArchDBName=@DbName+'_ARCHIVE'
IF @Archive=1
BEGIN	
	if not exists(select name from sys.databases where name=@ArchDBName)
	begin
		declare @path nvarchar(500)
		select @path=replace(F.physical_name,'.mdf','_ARCHIVE.mdf') from sys.databases D 
		inner join sys.master_files F on D.database_id=F.database_id
		where D.name=@DbName and F.type_desc='ROWS'
		
		BEGIN TRY      
			set @sql='CREATE DATABASE '+@ArchDBName+' ON  PRIMARY (NAME = '''+@ArchDBName+''', FILENAME ='''+@path+''')
			 LOG ON (NAME='''+@ArchDBName+'_log'', FILENAME='''+replace(@path,'.mdf','.ldf')+''')'
			 
			 --	CREATE DATABASE PACT2C_ARCHIVE ON  PRIMARY (NAME = 'PACT2C_ARCHIVE', FILENAME ='D:\Database\RevenU\PAC2C.mdf')
			 --LOG ON (NAME='PACT2C_ARCHIVE_log', FILENAME='D:\Database\RevenU\PAC2C.ldf')
			--print(@sql)
			exec(@sql)
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
	end
END
		
BEGIN TRANSACTION      
BEGIN TRY      
--SET NOCOUNT ON;    

	--Declaration Section    
	CREATE TABLE #TblTemp(ID BIGINT)
	CREATE TABLE #Tbl(ID INT IDENTITY(1,1),FeatureID INT)
	CREATE TABLE #TblINV(ID INT IDENTITY(1,1),FeatureID INT,IsRevise BIT)
	CREATE TABLE #TblACC(ID INT IDENTITY(1,1),FeatureID INT,IsRevise BIT)
	DECLARE @I INT,@CNT INT,@Dt FLOAT,@LoingDt float
	DECLARE @DtChar nvarchar(20),@cols nvarchar(max),@TblName nvarchar(max)
	
	SET @Dt=floor(convert(float,dateadd(day,1-@PreserveDays,GETDATE())))
	SET @DtChar=convert(nvarchar,@Dt)
	SET @LoingDt=floor(convert(float,dateadd(day,-30,GETDATE())))
--	select @Dt,dateadd(day,1-@PreserveDays,GETDATE())
	
	IF @Archive=1
	BEGIN	
		--Checking History Table
		SET @TblName=@ArchDBName+'.dbo.INV_DocDetails_History'
		EXEC spADM_COPYTABLE 'INV_DocDetails_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.ACC_DocDetails_History'
		EXEC spADM_COPYTABLE 'ACC_DocDetails_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.COM_DocCCData_History'
		EXEC spADM_COPYTABLE 'COM_DocCCData_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.COM_DocNumData_History'
		EXEC spADM_COPYTABLE 'COM_DocNumData_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.COM_DocTextData_History'
		EXEC spADM_COPYTABLE 'COM_DocTextData_History',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.ACC_AccountsHistory'
		EXEC spADM_COPYTABLE 'ACC_AccountsHistory',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.ACC_AccountsExtendedHistory'
		EXEC spADM_COPYTABLE 'ACC_AccountsExtendedHistory',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.INV_ProductHistory'
		EXEC spADM_COPYTABLE 'INV_ProductHistory',@ArchDBName,@TblName
		
		SET @TblName=@ArchDBName+'.dbo.INV_ProductExtendedHistory'
		EXEC spADM_COPYTABLE 'INV_ProductExtendedHistory',@ArchDBName,@TblName
		
		
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
		
		SET @TblName=@ArchDbName+'.dbo.ADM_Login'
		EXEC spADM_COPYTABLE 'ADM_Login',@ArchDbName,@TblName
	END
	
	--DELETE DOCUMENTS DATA
	IF LEN(@DocumentsList)>0
	BEGIN
		create table #TblIDS(DetailsID bigint,ModifiedDate float)
		CREATE NONCLUSTERED INDEX IDX_TbLID_DetailsID on #TblIDS(DetailsID)
		--CREATE NONCLUSTERED INDEX IDX_TbLID_Mod on #TblIDS(ModifiedDate)
		
		--SELECT @DocumentsList
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

		delete from #TblINV where IsRevise=1
		delete from #TblACC where IsRevise=1

		CREATE NONCLUSTERED INDEX IDX_TbLINV_DetailsID on #TblINV(FeatureID)
		CREATE NONCLUSTERED INDEX IDX_TbLACC_DetailsID on #TblACC(FeatureID)

		IF (SELECT COUNT(*) FROM #TblINV WITH(nolock) WHERE IsRevise=0)>0
		BEGIN
			insert into #TblIDS(DetailsID,ModifiedDate)
			SELECT top 50000 INV.INVDocDetailsID,INV.ModifiedDate FROM INV_DocDetails_History INV WITH(nolock)
			INNER JOIN #TblINV I WITH(nolock) ON I.FeatureID=INV.CostCenterID-- AND I.IsRevise=0
			WHERE INV.ModifiedDate<@Dt
			GROUP BY INV.INVDocDetailsID,INV.ModifiedDate

			IF @Archive=1
			BEGIN
				set @sql='INSERT INTO '+@ArchDBName+'.dbo.COM_DocCCData_History
			SELECT CC.* FROM COM_DocCCData_History CC WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON CC.INVDocDetailsID=T.DetailsID and CC.ModifiedDate=T.ModifiedDate'
				exec(@sql)
				
				set @sql='INSERT INTO '+@ArchDBName+'.dbo.COM_DocNumData_History
			SELECT NUM.* FROM COM_DocNumData_History NUM WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON NUM.INVDocDetailsID=T.DetailsID and NUM.ModifiedDate=T.ModifiedDate'
				exec(@sql)
				
				set @sql='INSERT INTO '+@ArchDBName+'.dbo.COM_DocTextData_History
			SELECT TXT.* FROM COM_DocTextData_History TXT WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON TXT.INVDocDetailsID=T.DetailsID and TXT.ModifiedDate=T.ModifiedDate'
				exec(@sql)
				
				set @sql='INSERT INTO '+@ArchDBName+'.dbo.INV_DocDetails_History			
			SELECT INV.* FROM INV_DocDetails_History INV WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON INV.INVDocDetailsID=T.DetailsID and INV.ModifiedDate=T.ModifiedDate'
				exec(@sql)
			END
			
			DELETE CC FROM COM_DocCCData_History CC WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON CC.INVDocDetailsID=T.DetailsID and CC.ModifiedDate=T.ModifiedDate
			
			DELETE NUM FROM COM_DocNumData_History NUM WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON NUM.INVDocDetailsID=T.DetailsID and NUM.ModifiedDate=T.ModifiedDate
			
			DELETE TXT FROM COM_DocTextData_History TXT WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON TXT.INVDocDetailsID=T.DetailsID and TXT.ModifiedDate=T.ModifiedDate
			
			DELETE INV FROM INV_DocDetails_History INV WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON INV.INVDocDetailsID=T.DetailsID and INV.ModifiedDate=T.ModifiedDate
			
			TRUNCATE TABLE #TblIDS
		END
		
		IF (SELECT COUNT(*) FROM #TblACC WITH(nolock) WHERE IsRevise=0)>0
		BEGIN
			insert into #TblIDS(DetailsID,ModifiedDate)
			SELECT top 50000 ACC.AccDocDetailsID,ACC.ModifiedDate FROM ACC_DocDetails_History ACC WITH(nolock)
			INNER JOIN #TblACC I WITH(nolock) ON I.FeatureID=ACC.CostCenterID-- AND I.IsRevise=0
			WHERE ACC.ModifiedDate<@Dt
			GROUP BY ACC.AccDocDetailsID,ACC.ModifiedDate
			
			IF @Archive=1
			BEGIN
				set @sql='INSERT INTO '+@ArchDBName+'.dbo.COM_DocCCData_History
			SELECT CC.* FROM COM_DocCCData_History CC WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON CC.ACCDocDetailsID=T.DetailsID and CC.ModifiedDate=T.ModifiedDate'
				exec(@sql)
				
				set @sql='INSERT INTO '+@ArchDBName+'.dbo.COM_DocNumData_History
			SELECT NUM.* FROM COM_DocNumData_History NUM WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON NUM.ACCDocDetailsID=T.DetailsID and NUM.ModifiedDate=T.ModifiedDate'
				exec(@sql)
				
				set @sql='INSERT INTO '+@ArchDBName+'.dbo.COM_DocTextData_History
			SELECT TXT.* FROM COM_DocTextData_History TXT WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON TXT.ACCDocDetailsID=T.DetailsID and TXT.ModifiedDate=T.ModifiedDate'
				exec(@sql)
				
				set @sql='INSERT INTO '+@ArchDBName+'.dbo.ACC_DocDetails_History
			SELECT ACC.* FROM ACC_DocDetails_History ACC WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON ACC.ACCDocDetailsID=T.DetailsID and ACC.ModifiedDate=T.ModifiedDate'
				exec(@sql)
			END
			
			DELETE CC FROM COM_DocCCData_History CC WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON CC.ACCDocDetailsID=T.DetailsID and CC.ModifiedDate=T.ModifiedDate 
			
			DELETE NUM FROM COM_DocNumData_History NUM WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON NUM.ACCDocDetailsID=T.DetailsID and NUM.ModifiedDate=T.ModifiedDate
			
			DELETE TXT FROM COM_DocTextData_History TXT WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON TXT.ACCDocDetailsID=T.DetailsID and TXT.ModifiedDate=T.ModifiedDate
			
			DELETE ACC FROM ACC_DocDetails_History ACC WITH(nolock)
			INNER JOIN #TblIDS T WITH(nolock) ON ACC.ACCDocDetailsID=T.DetailsID and ACC.ModifiedDate=T.ModifiedDate 
		END
		
		drop table #TblIDS
	END
	
	--DELETE DIMENSIONS DATA
	IF LEN(@DimensionsList)>0
	BEGIN
		if @DimensionsList='ALL'
			set @DimensionsList='2,3,93,94,95'
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
				IF @Archive=1
				BEGIN
					set @sql='INSERT INTO '+@ArchDBName+'.dbo.ACC_AccountsHistory
			SELECT * FROM ACC_AccountsHistory with(nolock)
			WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
					exec(@sql)
					
					set @sql='INSERT INTO '+@ArchDBName+'.dbo.ACC_AccountsExtendedHistory
			SELECT * FROM ACC_AccountsExtendedHistory with(nolock)
			WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
					exec(@sql)
				END
				Delete from ACC_AccountsHistory where isnull(ModifiedDate, CreatedDate)<@Dt
				Delete from ACC_AccountsExtendedHistory where isnull(ModifiedDate, CreatedDate)<@Dt
			END
			ELSE IF (@featureid=3)
			BEGIN
				IF @Archive=1
				BEGIN
					set @sql='INSERT INTO '+@ArchDBName+'.dbo.INV_ProductHistory
			SELECT * FROM INV_ProductHistory with(nolock)
			WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
					exec(@sql)
					
					set @sql='INSERT INTO '+@ArchDBName+'.dbo.INV_ProductExtendedHistory
			SELECT * FROM INV_ProductExtendedHistory with(nolock)
			WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
					exec(@sql)
				END
				Delete from INV_ProductHistory where isnull(ModifiedDate, CreatedDate)<@Dt
				Delete from INV_ProductExtendedHistory where isnull(ModifiedDate, CreatedDate)<@Dt
			END
			ELSE IF (@featureid=93 OR @featureid=94 OR @featureid=95)
			BEGIN
				set @sql='EXEC [spREN_DeleteAuditData] '+CONVERT(NVARCHAR,@Archive)+','''+@ArchDBName+''','+CONVERT(NVARCHAR,@featureid)+','+CONVERT(NVARCHAR(MAX),@Dt)+','''+@DtChar+''','+CONVERT(NVARCHAR,@UserID)+','+CONVERT(NVARCHAR,@LangID)
				EXEC (@sql)   
			END
			set @I=@I+1
		END
	END

	--SETTINGS
	IF @Archive=1
	BEGIN
		set @sql='INSERT INTO '+@ArchDBName+'.dbo.ADM_FeatureActionRoleMapHistory
SELECT * FROM ADM_FeatureActionRoleMapHistory with(nolock) WHERE CreatedDate<'+@DtChar
		exec(@sql)
		
		set @sql='INSERT INTO '+@ArchDBName+'.dbo.ADM_GlobalPreferences_History
SELECT * FROM ADM_GlobalPreferences_History with(nolock) WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
		exec(@sql)
		
		set @sql='INSERT INTO '+@ArchDBName+'.dbo.COM_DocumentPreferences_History
SELECT * FROM COM_DocumentPreferences_History with(nolock) WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
		exec(@sql)
		
		set @sql='INSERT INTO '+@ArchDBName+'.dbo.ADM_UserRoleMapHistory
SELECT * FROM ADM_UserRoleMapHistory with(nolock) WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
		exec(@sql)
		
		set @sql='INSERT INTO '+@ArchDBName+'.dbo.ADM_CostCenterDef_History
SELECT * FROM ADM_CostCenterDef_History with(nolock) WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
		exec(@sql)
		
		set @sql='INSERT INTO '+@ArchDBName+'.dbo.ADM_DocumentDef_History
SELECT * FROM ADM_DocumentDef_History with(nolock) WHERE isnull(ModifiedDate, CreatedDate)<'+@DtChar
		exec(@sql)
		
		set @sql='INSERT INTO '+@ArchDBName+'.dbo.ADM_Login
SELECT * FROM ADM_Login with(nolock) WHERE [Login]<'+convert(nvarchar,@LoingDt)
		exec(@sql)
	END
	Delete from ADM_FeatureActionRoleMapHistory where CreatedDate<@Dt
	Delete from ADM_GlobalPreferences_History where isnull(ModifiedDate, CreatedDate)<@Dt
	Delete from COM_DocumentPreferences_History where isnull(ModifiedDate, CreatedDate)<@Dt
	Delete from ADM_UserRoleMapHistory where isnull(ModifiedDate, CreatedDate)<@Dt
	Delete from ADM_CostCenterDef_History where isnull(ModifiedDate, CreatedDate)<@Dt
	Delete from ADM_DocumentDef_History where isnull(ModifiedDate, CreatedDate)<@Dt
	
	Delete from ADM_Login where [Login]<@LoingDt
	

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
