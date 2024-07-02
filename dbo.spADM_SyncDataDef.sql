USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SyncDataDef]
	@Type [int],
	@CCXML [nvarchar](max) = null,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON
	
		----Declaration Section
		--DECLARE @HasAccess bit,@FEATUREID int

	declare @ID INT,@i int,@cnt int,@CCID int,@SQL nvarchar(MAX),@TableName nvarchar(50),@POSItemCodeDim int,@XML xml
	
	set @ID=1
	
	if @Type=1 or @Type=2--Getting Offline Master Data Changes
	begin
		declare @Tbl as Table(CCID int,NewNodes int,MaxNodeID INT,ModDate float,ModDateTime datetime)
		
		if @Type=1 and (select count(*) from ADM_OfflineOnlineIDMap with(nolock) where OnlineID=0)=0--For Transaction
		begin
			select CCID,NewNodes,MaxNodeID,ModDate,ModDateTime,'' CCName from @Tbl T
			commit transaction
			return 1
		end
		
		select @SQL=Value from adm_globalPreferences with(nolock) where Name='POSItemCodeDimension'
		if @SQL!='' and isnumeric(@SQL)=1
			set @POSItemCodeDim=@SQL
		
		select @i=max(FeatureId) from adm_features with(nolock) where FeatureId>50000 
		while(@i>=50001)
		begin
			if exists (select * from adm_features with(nolock) where FeatureId=@i and IsEnabled=1)
			begin
				set @SQL=''
				if(@POSItemCodeDim=@i)
					select @SQL='select '+convert(nvarchar,@i)+' CC,(select max(ModifiedDate) from '+TableName+' with(nolock) where NodeID>0) ModifiedDate
					,(select count(*) from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID='+convert(nvarchar,@i)+' and OnlineID=0) NewNodes
					,(select max(NodeID) from '+TableName+' with(nolock) where NodeID>0) NodeID' from adm_features with(nolock) where FeatureID=@i
				else
					select @SQL='select '+convert(nvarchar,@i)+' CC,(select max(isnull(ModifiedDate,createdDate)) from '+TableName+' with(nolock) where NodeID>0) ModifiedDate
					,(select count(*) from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID='+convert(nvarchar,@i)+' and OnlineID=0) NewNodes
					,(select max(NodeID) from '+TableName+' with(nolock) where NodeID>0) NodeID' from adm_features with(nolock) where FeatureID=@i
					
				if(len(@SQL)>0)
				begin
					--print(@SQL)				
					insert into @Tbl(CCID,ModDate,NewNodes,MaxNodeID)
					exec(@SQL)
				end
			end
			set @i=@i-1
		end
		
		
		insert into @Tbl(CCID,ModDate,NewNodes,MaxNodeID)
		select 2 CC,(select max(isnull(ModifiedDate,createdDate))from acc_accounts with(nolock) where accountid>0) ModifiedDate
				--,(select max(AccountID) from acc_accounts with(nolock) where accountid<-10000) NodeID
				,(select count(*) from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID=2 and OnlineID=0) NewNodes
				,(select max(AccountID) from acc_accounts with(nolock) where accountid>0) NodeID
				
		insert into @Tbl(CCID,ModDate,NewNodes,MaxNodeID)
		select 3 CC,(select max(isnull(ModifiedDate,createdDate)) from inv_product with(nolock) where productid>0) ModifiedDate
				,(select count(*) from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID=3 and OnlineID=0) NewNodes
				,(select max(productid) from inv_product with(nolock) where productid>0) NodeID
				
		insert into @Tbl(CCID,ModDate,NewNodes,MaxNodeID)
		select 16 CC,(select max(isnull(ModifiedDate,createdDate)) from inv_product with(nolock) where productid>0) ModifiedDate
				,(select count(*) from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID=16 and OnlineID=0) NewNodes
				,(select max(BatchID) from INV_Batches with(nolock) where BatchID>0) NodeID		
		
		update @Tbl
		set ModDateTime=convert(datetime,ModDate)
		
		select T.*,F.Name CCName from @Tbl T
		inner join adm_features F with(nolock) on F.FeatureID=T.CCID
		
	end
	else if @Type=3--Online Version
	begin
		select top 1 CONVERT(int,REPLACE(VersionNo,'.','')) VersionNo,VersionNo SVersionNo from ADM_Versions with(nolock) 
		order by CONVERT(int,REPLACE(VersionNo,'.','')) desc 
		
		select Name,Value from adm_globalPreferences with(nolock)
		where Name in ('UseGlobalPrefForFileUploadPath','File Upload Path','ftpuserid','ftppassword','isSftp','ftpport','Syncbatchproductasgeneral','Syncserialproductasgeneral')
	end
	else if @Type=4--EXECUTE SCRIPTS
	begin
		EXEC(@CCXML)
	end
	else if @Type=5--EXECUTE SCRIPTS WITH IDENTITY VALUE
	begin
		EXEC sp_executesql @CCXML,N'@ID INT OUTPUT',@ID OUTPUT
	end
	else if @Type=6--Delete Offline Masters and update references
	begin
		declare @CC int,@OfflineID INT
		create table #TMap(ID int identity(1,1), OfflineID INT,OnlineID INT)
		set @CC=convert(int,@CCXML)
		
		insert into #TMap(OfflineID,OnlineID)
		select distinct OfflineID,OnlineID from ADM_OfflineOnlineIDMap with(nolock) where CostCenterID=@CC and OnlineID>0
		
		select @i=1,@Cnt=count(*) from #TMap with(nolock)

		if @CC=2
		begin
			if exists (select DebitAccount from inv_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.DebitAccount=T.OfflineID)
				update inv_docdetails
				set DebitAccount=T.OnlineID
				from inv_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.DebitAccount=T.OfflineID
			
			if exists (select CreditAccount from inv_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.CreditAccount=T.OfflineID)
				update inv_docdetails
				set CreditAccount=T.OnlineID
				from inv_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.CreditAccount=T.OfflineID
				
			if exists (select DebitAccount from acc_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.DebitAccount=T.OfflineID)
				update acc_docdetails
				set DebitAccount=T.OnlineID
				from acc_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.DebitAccount=T.OfflineID
			
			if exists (select CreditAccount from acc_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.CreditAccount=T.OfflineID)
				update acc_docdetails
				set CreditAccount=T.OnlineID
				from acc_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.CreditAccount=T.OfflineID
			
			while(@i<=@Cnt)
			begin
				select @OfflineID=OfflineID from #TMap with(nolock) where ID=@i
				
				EXEC spACC_DeleteAccount @AccountID=@OfflineID,@UserID=@UserID,@RoleID=1,@LangID=@LangID
				
				--delete from ADM_OfflineOnlineIDMap where CostCenterID=@CC and OfflineID=@OfflineID
				
				set @i=@i+1
			end
		end
		else if @CC=3
		begin
			if exists (select ProductID from inv_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.ProductID=T.OfflineID)
				update inv_docdetails
				set ProductID=T.OnlineID
				from inv_docdetails A with(nolock) inner join #TMap T with(nolock) ON A.ProductID=T.OfflineID
			
			while(@i<=@Cnt)
			begin
				select @OfflineID=OfflineID from #TMap with(nolock) where ID=@i
				
				EXEC spINV_DeleteProduct @ProductID=@OfflineID,@UserID=@UserID,@RoleID=1,@LangID=@LangID
				
				--delete from ADM_OfflineOnlineIDMap where CostCenterID=@CC and OfflineID=@OfflineID
				
				set @i=@i+1
			end
		end
		else if @CC>50000 
		begin
			declare @CCName nvarchar(50)
			select @TableName=TableName,@CCName=Name from adm_features with(nolock) where FeatureID=@CCID
			set @SQL='if exists (select A.dcCCNID'+convert(nvarchar,@CC-50000)+' from com_docccdata A with(nolock) inner join #TMap T with(nolock) ON A.dcCCNID'+convert(nvarchar,@CC-50000)+'=T.OfflineID)
				update com_docccdata
				set dcCCNID'+convert(nvarchar,@CC-50000)+'=T.OnlineID
				from com_docccdata A with(nolock) inner join #TMap T with(nolock) ON A.dcCCNID'+convert(nvarchar,@CC-50000)+'=T.OfflineID'
			--print( @SQL)
			exec(@SQL)

			set @SQL='if exists (select A.CCNID'+convert(nvarchar,@CC-50000)+' from com_ccccdata A with(nolock) inner join #TMap T with(nolock) ON A.CCNID'+convert(nvarchar,@CC-50000)+'=T.OfflineID)
				update com_ccccdata
				set CCNID'+convert(nvarchar,@CC-50000)+'=T.OnlineID
				from com_ccccdata A with(nolock) inner join #TMap T with(nolock) ON A.CCNID'+convert(nvarchar,@CC-50000)+'=T.OfflineID'
			exec(@SQL)
			
			set @SQL='if exists (select NodeID from com_docbridge A with(nolock) inner join #TMap T with(nolock) ON A.RefDimensionNodeID=T.OfflineID AND A.RefDimensionID='+convert(nvarchar,@CC)+')
				update com_docbridge
				set RefDimensionNodeID=T.OnlineID
				from com_docbridge A with(nolock) inner join #TMap T with(nolock) ON A.RefDimensionNodeID=T.OfflineID AND A.RefDimensionID='+convert(nvarchar,@CC)
			exec(@SQL)
			
			
			while(@i<=@Cnt)
			begin
				select @OfflineID=OfflineID from #TMap with(nolock) where ID=@i

				EXEC spCOM_DeleteCostCenter @CC,@OfflineID,1,@UserID,@LangID
				
				--delete from ADM_OfflineOnlineIDMap where CostCenterID=@CC and OfflineID=@OfflineID
				
				set @i=@i+1
			end
		end
		
	end
	else if @Type=7--Offline Settings
	begin
		select Value from ADM_GlobalPreferences with(nolock) where Name='OnlineDataBase'
	end
	else if @Type=8--Set Offline Settings
	begin
		if exists (select * from ADM_GlobalPreferences with(nolock) where Name='OnlineDataBase')
			update ADM_GlobalPreferences set value=@CCXML where name='OnlineDataBase'
		else
			insert into Adm_GlobalPreferences(ResourceID,Name,Value,DefaultValue,GUID,CreatedBy,CreatedDate)
			values(0,'OnlineDataBase',@CCXML,'0','GUID','ADMIN',1)
	end
	else if @Type=9--Set Offline Settings
	begin
		if @CCXML=1
			select 2 CC,(select max(isnull(ModifiedDate,createdDate))from ADM_CostCenterDef with(nolock) where CostCenterColID>0) ModifiedDate
				,(select max(CostCenterColID) from ADM_CostCenterDef with(nolock) where CostCenterColID>0) MaxNodeID
		else if @CCXML=2
			select 2 CC,(select max(isnull(ModifiedDate,createdDate))from ADM_CostCenterDef with(nolock) where CostCenterColID>0) ModifiedDate
				,(select max(CostCenterColID) from ADM_CostCenterDef with(nolock) where CostCenterColID>0) MaxNodeID
	end
	else if @Type=10--Get Offline Settings
	begin
		declare @TblSettings as table(CCID int,TableName nvarchar(50),PrimaryKey nvarchar(50),IsModDate bit,ChunkSize int,MaxNodeID INT,ModDate float)
		
		--insert into @TblSettings
		--select * from ADM_SynSettings with(nolock) order by ID
					
		DECLARE @SPInvoice cursor, @nStatusOuter int,@PrimaryKey nvarchar(100),@IsModDate bit,@ChunkSize int,@MaxNodeID INT,@ModDate float,@tempCode nvarchar(max)
		SET @SPInvoice = cursor for 
		SELECT ID,TableName,PrimaryKey,IsModDate,ChunkSize FROM ADM_SynSettings with(nolock)
		where ID in (1,45,46)
		
		OPEN @SPInvoice 
		SET @nStatusOuter = @@FETCH_STATUS
		
		FETCH NEXT FROM @SPInvoice Into @ID,@TableName,@PrimaryKey,@IsModDate,@ChunkSize
		SET @nStatusOuter = @@FETCH_STATUS
		
		WHILE(@nStatusOuter <> -1)
		BEGIN
			set @SQL='select '+convert(nvarchar,@ID)+','''+@TableName+''','''+@PrimaryKey+''','+convert(nvarchar,@IsModDate)+','+convert(nvarchar,@ChunkSize)+',max('+@PrimaryKey+') MaxNodeID,'+(case when @IsModDate=1 then 'max(isnull(ModifiedDate,createdDate))+0.000002' else '0' end )+' ModDate from '+@TableName+' with(nolock)'
			-- SET @tempCode='@MaxNodeID INT OUTPUT,@ModDate float OUTPUT'    
			print(@SQL)
			insert into @TblSettings
			exec(@SQL)
			 --EXEC sp_executesql @SQL,@tempCode,@MaxNodeID OUTPUT ,@ModDate OUTPUT 
			
			FETCH NEXT FROM @SPInvoice Into @ID,@TableName,@PrimaryKey,@IsModDate,@ChunkSize
			SET @nStatusOuter = @@FETCH_STATUS
		END
		
		select *,convert(datetime,ModDate) dModDate from @TblSettings order by CCID
	end
	else if @Type=11
	begin
		select V.Module,max(CONVERT(int,REPLACE(V.Version,'.',''))) VersionNo
		from PACT2C.dbo.ADM_Scripts2C V with(nolock)
		where V.Module is not null
		group by V.Module

		select V.Module,max(CONVERT(int,REPLACE(V.Version,'.',''))) VersionNo
		from PACT2C.dbo.ADM_Scripts V with(nolock)
		where V.Module is not null
		group by V.Module
		
		select CompanyID from PACT2C.dbo.ADM_Company with(nolock) where DBName=DB_NAME()
	end
	else if @Type=12
	begin
		set @XML=@CCXML
		select @TableName=X.value('@Mod','nvarchar(MAX)'),@CCID=X.value('@Ver','int')
		from @XML.nodes('/XML') Data(X)
		
		set @SQL='xyz'
		select top 1 @SQL=Version from PACT2C.dbo.ADM_Scripts2C with(nolock) where Module=@TableName and CONVERT(int,REPLACE(Version,'.',''))>@CCID
		order by CONVERT(int,REPLACE(Version,'.','')) asc

		select * from PACT2C.dbo.ADM_Scripts2C with(nolock) where Module=@TableName and Version=@SQL
	end
	else if @Type=13
	begin
		set @XML=@CCXML
		select @TableName=X.value('@Mod','nvarchar(MAX)'),@CCID=X.value('@Ver','int')
		from @XML.nodes('/XML') Data(X)
		
		set @SQL='xyz'
		select top 1 @SQL=Version from PACT2C.dbo.ADM_Scripts with(nolock) where Module=@TableName and CONVERT(int,REPLACE(Version,'.',''))>@CCID
		order by CONVERT(int,REPLACE(Version,'.','')) asc

		select * from PACT2C.dbo.ADM_Scripts with(nolock) where Module=@TableName and Version=@SQL
	end
	else if @Type=14
	begin
		declare @table as table(ID int identity(1,1),DocName nvarchar(100),CCID int,IsInv bit,DocID INT,ModDate float)
		insert into @table(CCID)
		exec SPSplitString @CCXML,','
		
		update T set IsInv=D.IsInventory,DocName=D.DocumentName
		from @table T
		join ADM_DocumentTypes D with(nolock) on D.CostCenterID=T.CCID
		
		update T
		set DocID=D.DocID,ModDate=D.ModDate
		from @table T
		join (select T.CCID,max(D.DocID) DocID,max(ModifiedDate) ModDate from @table T
			join INV_DocDetails D with(nolock) on D.CostCenterID=T.CCID
			where T.IsInv=1
			Group by T.CCID) AS D on D.CCID=T.CCID
		
		update T
		set DocID=D.DocID,ModDate=D.ModDate
		from @table T
		join (select T.CCID,max(D.DocID) DocID,max(ModifiedDate) ModDate from @table T
			join ACC_DocDetails D with(nolock) on D.CostCenterID=T.CCID
			where T.IsInv=0
			Group by T.CCID) AS D on D.CCID=T.CCID
			
		select * from @table
	end

COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN @ID
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
