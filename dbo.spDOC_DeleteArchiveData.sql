USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_DeleteArchiveData]
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

DECLARE @DbName nvarchar(50),@sql nvarchar(max),@ArchDBName nvarchar(50)
set @DbName=DB_NAME()
set @ArchDBName=@DbName+'_ARCHIVE'
	
	if not exists(select name from sys.databases where name=@ArchDBName)
	begin
		RAISERROR('-105',16,1) 
	end

	--Declaration Section    
	CREATE TABLE #TblTemp(ID INT)
	CREATE TABLE #Tbl(ID INT IDENTITY(1,1),FeatureID INT)
	CREATE TABLE #TblINV(ID INT IDENTITY(1,1),FeatureID INT,IsRevise BIT)
	CREATE TABLE #TblACC(ID INT IDENTITY(1,1),FeatureID INT,IsRevise BIT)
	DECLARE @I INT,@CNT INT,@Dt FLOAT
	DECLARE @DtChar nvarchar(20),@cols nvarchar(max),@TblName nvarchar(max)
	
	SET @Dt=floor(convert(float,dateadd(day,1-@PreserveDays,GETDATE())))
	SET @DtChar=convert(nvarchar,@Dt)
	select @Dt,dateadd(day,1-@PreserveDays,GETDATE())
	
	--DELETE DOCUMENTS DATA
	IF LEN(@DocumentsList)>0
	BEGIN
		create table #TblIDS(DetailsID INT,ModifiedDate float)
		CREATE NONCLUSTERED INDEX IDX_TbLID_DetailsID on #TblIDS(DetailsID)
		CREATE NONCLUSTERED INDEX IDX_TbLID_Mod on #TblIDS(ModifiedDate)
		
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
			WHERE D.IsInventory=1 AND D.CostCenterID IN (SELECT ID FROM #TblTemp with(nolock))
			
			INSERT INTO #TblACC(FeatureID,IsRevise)
			SELECT D.CostCenterID,ISNULL(REV.IsRevise,0)
			FROM ADM_DocumentTypes D WITH(nolock) LEFT JOIN			
			(SELECT CostCenterID,CASE WHEN PrefValue='TRUE' THEN 1 ELSE 0 END IsRevise FROM COM_DocumentPreferences with(nolock)
			WHERE PrefName='EnableRevision') AS REV ON D.CostCenterID=REV.CostCenterID
			WHERE D.IsInventory=0 AND D.CostCenterID IN (SELECT ID FROM #TblTemp with(nolock))
		END

		delete from #TblINV where IsRevise=1
		delete from #TblACC where IsRevise=1

		CREATE NONCLUSTERED INDEX IDX_TbLINV_DetailsID on #TblINV(FeatureID)
		CREATE NONCLUSTERED INDEX IDX_TbLACC_DetailsID on #TblACC(FeatureID)
		
		IF (SELECT COUNT(*) FROM #TblINV with(nolock) WHERE IsRevise=0)>0
		BEGIN		
			set @sql='USE '+@ArchDBName+'
			insert into #TblIDS(DetailsID,ModifiedDate)
			SELECT INV.INVDocDetailsID,INV.ModifiedDate FROM INV_DocDetails_History INV with(nolock)
			INNER JOIN #TblINV I with(nolock) ON I.FeatureID=INV.CostCenterID-- AND I.IsRevise=0
			WHERE INV.ModifiedDate<'+@DtChar+'
			GROUP BY INV.INVDocDetailsID,INV.ModifiedDate			
			
			DELETE CC FROM COM_DocCCData_History CC with(nolock)
			INNER JOIN #TblIDS T with(nolock) ON CC.INVDocDetailsID=T.DetailsID and CC.ModifiedDate=T.ModifiedDate
			
			DELETE NUM FROM COM_DocNumData_History NUM with(nolock)
			INNER JOIN #TblIDS T with(nolock) ON NUM.INVDocDetailsID=T.DetailsID and NUM.ModifiedDate=T.ModifiedDate
			
			DELETE TXT FROM COM_DocTextData_History TXT with(nolock)
			INNER JOIN #TblIDS T with(nolock) ON TXT.INVDocDetailsID=T.DetailsID and TXT.ModifiedDate=T.ModifiedDate
			
			DELETE INV FROM INV_DocDetails_History INV with(nolock)
			INNER JOIN #TblIDS T with(nolock) ON INV.INVDocDetailsID=T.DetailsID and INV.ModifiedDate=T.ModifiedDate'
			
			TRUNCATE TABLE #TblIDS
		END
		
		IF (SELECT COUNT(*) FROM #TblACC with(nolock) WHERE IsRevise=0)>0
		BEGIN
			TRUNCATE TABLE #TblIDS
			set @sql='USE '+@ArchDBName+'
			insert into #TblIDS(DetailsID,ModifiedDate)
			SELECT ACC.AccDocDetailsID,ACC.ModifiedDate FROM ACC_DocDetails_History ACC with(nolock)
			INNER JOIN #TblACC I with(nolock) ON I.FeatureID=ACC.CostCenterID-- AND I.IsRevise=0
			WHERE ACC.ModifiedDate<'+@DtChar+'
			GROUP BY ACC.AccDocDetailsID,ACC.ModifiedDate
			
			DELETE CC FROM COM_DocCCData_History CC with(nolock)
			INNER JOIN #TblIDS T with(nolock) ON CC.ACCDocDetailsID=T.DetailsID and CC.ModifiedDate=T.ModifiedDate 
			
			DELETE NUM FROM COM_DocNumData_History NUM with(nolock)
			INNER JOIN #TblIDS T with(nolock) ON NUM.ACCDocDetailsID=T.DetailsID and NUM.ModifiedDate=T.ModifiedDate
			
			DELETE TXT FROM COM_DocTextData_History TXT with(nolock)
			INNER JOIN #TblIDS T with(nolock) ON TXT.ACCDocDetailsID=T.DetailsID and TXT.ModifiedDate=T.ModifiedDate
			
			DELETE ACC FROM ACC_DocDetails_History ACC with(nolock)
			INNER JOIN #TblIDS T with(nolock) ON ACC.ACCDocDetailsID=T.DetailsID and ACC.ModifiedDate=T.ModifiedDate '
		END
		
		drop table #TblIDS
	END
	
	--DELETE DIMENSIONS DATA
	IF LEN(@DimensionsList)>0
	BEGIN
		INSERT INTO #Tbl
		EXEC SPSplitString @DimensionsList,','
		
		declare @featureid INT
		 
		select @I=1,@CNT=COUNT(*) from #Tbl with(nolock)
		while @I<=@CNT
		BEGIN
			select @featureid=FeatureID from #Tbl with(nolock) where ID=@I
			IF (@featureid=2)
			BEGIN
				set @sql='USE '+@ArchDBName+'
				Delete from ACC_AccountsHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
				Delete from ACC_AccountsExtendedHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar
				exec(@sql)
			END
			ELSE IF (@featureid=3)
			BEGIN
				set @sql='USE '+@ArchDBName+'
				Delete from INV_ProductHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
				Delete from INV_ProductExtendedHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar
				exec(@sql)
			END
			ELSE IF (@featureid=93 OR @featureid=94 OR @featureid=95)
			BEGIN
				set @sql='EXEC [spREN_DeleteArchiveData] '''+@ArchDBName+''','+convert(nvarchar,@featureid)+','''+@DtChar+''','+convert(nvarchar,@UserID)+','+convert(nvarchar,@LangID)
				exec(@sql)
			END 
			set @I=@I+1
		END
	END
	
	
	--SETTINGS
	set @sql='USE '+@ArchDBName+'
	Delete from ADM_FeatureActionRoleMapHistory where CreatedDate<'+@DtChar+'
	Delete from ADM_GlobalPreferences_History where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
	Delete from COM_DocumentPreferences_History where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
	Delete from ADM_UserRoleMapHistory where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
	Delete from ADM_CostCenterDef_History where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
	Delete from ADM_DocumentDef_History where isnull(ModifiedDate, CreatedDate)<'+@DtChar+'
	Delete from ADM_Login where [Login]<'+@DtChar
	--print @sql
	exec(@sql)

COMMIT TRANSACTION
--ROLLBACK TRANSACTION

SET NOCOUNT OFF; 
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
