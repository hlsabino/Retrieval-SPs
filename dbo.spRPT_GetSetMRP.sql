USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetSetMRP]
	@Type [int] = 0,
	@MRPID [int],
	@SelectedNodeID [int],
	@IsGroup [bit],
	@Param1 [nvarchar](max) = null,
	@Param2 [nvarchar](max) = null,
	@Param3 [nvarchar](max) = null,
	@RoleID [int],
	@UserID [int],
	@UserName [nvarchar](max),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;
	declare @SQL nvarchar(max),@XML xml,@ProfileName nvarchar(max)
	declare @Join nvarchar(max),@CCWhere nvarchar(max),@ProductWhere nvarchar(max)
	
	IF @Type=1
	BEGIN
		select *,convert(datetime,FromDate) dFromDate,convert(datetime,ToDate) dToDate from INV_MRP with(nolock) where MRPID=@MRPID
		
		select D.CostCenterID,D.DocumentName,D.DocumentType From ADM_DocumentTypes D with(nolock)
		inner  join com_documentpreferences DP with(nolock) ON DP.CostCenterID=D.CostCenterID
		where D.IsInventory=1 and DP.PrefName='DonotupdateInventory' and DP.PrefValue='True'
		and (@RoleID=1 or @UserID=1 or D.CostCenterID IN( select FA.FeatureID from adm_featureactionrolemap FAR with(nolock)
			inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
			where FAR.RoleID=@RoleID and (FA.FeatureActionTypeID=1 or FA.FeatureActionTypeID=2) and FA.FeatureID between 40000 and 50000
			))
		Order By DocumentName
		
		select Name,Value from com_costcenterpreferences with(nolock) where Costcenterid=257
		
		if(@MRPID>0)
			select D.CostCenterID,Convert(datetime, D.DocDate) DocDate,D.DocPrefix,D.DocNumber, D.VoucherNo DocNo
			from com_docbridge B with(nolock) 
			left join INV_DocDetails D with(nolock) on D.DocID=B.NodeID
			where RefDimensionID=257 and RefDimensionNodeID=@MRPID
			group by D.CostCenterID,D.Docdate,D.DocPrefix,D.DocNumber,D.VoucherNo
			order by Docdate,DocPrefix,DocNumber
		else
			select 1 PO where 1!=1
		
		select CustomPreferences from ADM_RevenuReports with(nolock) where ReportID=257
	END
	ELSE IF @Type=2
	BEGIN
		declare @FinalQry nvarchar(max)
		select @XML=ReportDefnXML from adm_revenuReports with(nolock) where ReportID=@MRPID

		select X.value('Identity[1]/Sequence[1]','nvarchar(max)') Sequence		
		,X.value('Identity[1]/ID[1]','nvarchar(max)') ID
		,X.value('Identity[1]/Caption[1]','nvarchar(max)') Caption
		,X.value('Identity[1]/Type[1]','nvarchar(max)') DType
		,X.value('HeaderAppearance[1]/Visibility[1]','int') Visible		
		,X.value('Identity[1]/Field[1]','nvarchar(max)') Field	
		,X.value('Identity[1]/SelectedField[1]','nvarchar(max)') SelectedField 
		,X.value('Width[1]','nvarchar(max)') Width
		,X.value('Format[1]/Decimals[1]','nvarchar(max)') Decimals
		into #TblFields
		from @XML.nodes('PactRevenURpts/PactRevenURptDef/Columns/ColumnDef') as Data(X)
		
		select T.*
			,F.SysTableName,F.SysColumnName,F.ColumnCostCenterID
			,F.IsForeignKey,F.ParentCostCenterID,F.ParentCostCenterSysName,F.ParentCostCenterColSysName
			,SF.CostCenterID SFCostCenterID,SF.SysTableName SFSysTableName,SF.SysColumnName SFSysColumnName
		from #TblFields T
		left join ADM_CostCenterDef F with(nolock) on F.CostCenterColID=abs(T.Field)
		left join ADM_CostCenterDef SF with(nolock) on SF.CostCenterColID=T.SelectedField
		drop table #TblFields
	END
	/*ELSE IF @Type=3--Save MRP Report
	BEGIN
		
		set @XML=@Param1
		select @ProfileName=x.value('Name[1]','nvarchar(200)') from @XML.nodes('/XML') as data(x)
		IF not exists (select MRPID from INV_MRP with(nolock) where MRPID=@MRPID)
		BEGIN--CREATE REPORT--
			set identity_insert INV_MRP ON
			INSERT INTO INV_MRP(MRPID,Name,FCID,FCPeriod,FromDate,ToDate,
				StatusID,IsGroup,Depth,ParentID,lft,rgt
				,DefaultPreferences,OrderFilter,TreeXML,
				GUID,CreatedBy,CreatedDate)
			select @MRPID,@ProfileName,x.value('FCID[1]','INT'),x.value('FCPeriod[1]','nvarchar(50)'),convert(float,x.value('FromDate[1]','DateTime')),convert(float,x.value('ToDate[1]','DateTime')),
			  x.value('StatusID[1]','int'),0,0,0,0,0
			  ,convert(nvarchar(max),x.query('DefaultPref[1]')),@Param2,@Param3,
			  newid(),@UserName,convert(float,getdate())
			from @XML.nodes('/XML') as data(x)
			SET @MRPID=SCOPE_IDENTITY()
			set identity_insert INV_MRP OFF
		END
		ELSE
		BEGIN
			update INV_MRP set FCID=x.value('FCID[1]','INT'),FCPeriod=x.value('FCPeriod[1]','nvarchar(50)')
			,FromDate=convert(float,x.value('FromDate[1]','DateTime')),ToDate=convert(float,x.value('ToDate[1]','DateTime'))
			,DefaultPreferences=convert(nvarchar(max),x.query('DefaultPref[1]'))
			,OrderFilter=@Param2
			,TreeXML=@Param3
			,GUID=newid(),ModifiedBy=@UserName,ModifiedDate=convert(float,getdate())
			from @XML.nodes('/XML') as data(x)      
			where MRPID=@MRPID      
		END
		
		--
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID
	END*/
	ELSE IF @Type=4--Save MRP
	BEGIN
		
		DECLARE @SelectedIsGroup bit
		DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT

		set @XML=@Param1
		select @ProfileName=x.value('Name[1]','nvarchar(200)') from @XML.nodes('/XML') as data(x)
		IF EXISTS (SELECT MRPID FROM INV_MRP WITH(nolock) WHERE MRPID!=@MRPID and MRPID>0 AND Name=@ProfileName) 
		BEGIN
			
			RAISERROR('-112',16,1)  
		END
			
		IF @MRPID=0--------START INSERT RECORD-----------
		BEGIN--CREATE REPORT--
			if @SelectedNodeID=0
				set @SelectedNodeID=1

			--To Set Left,Right And Depth of Record
			SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
			from INV_MRP with(NOLOCK) where MRPID=@SelectedNodeID

			--IF No Record Selected or Record Doesn't Exist
			IF(@SelectedIsGroup is null) 
				select @SelectedNodeID=MRPID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
				from INV_MRP with(NOLOCK) where ParentID =0
						
			IF(@SelectedIsGroup = 1)--Adding Node Under the Group
			BEGIN
				UPDATE INV_MRP SET rgt = rgt + 2 WHERE rgt > @Selectedlft;
				UPDATE INV_MRP SET lft = lft + 2 WHERE lft > @Selectedlft;
				SET @lft =  @Selectedlft + 1
				SET @rgt =	@Selectedlft + 2
				SET @ParentID = @SelectedNodeID
				SET @Depth = @Depth + 1
			END
			ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level
			BEGIN
				UPDATE INV_MRP SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
				UPDATE INV_MRP SET lft = lft + 2 WHERE lft > @Selectedrgt;
				SET @lft =  @Selectedrgt + 1
				SET @rgt =	@Selectedrgt + 2 
			END
			ELSE  --Adding Root
			BEGIN
				SET @lft =  1
				SET @rgt =	2 
				SET @Depth = 0
				SET @ParentID =0
				SET @IsGroup=1
			END
			
			-- Insert statements for procedure here
			INSERT INTO INV_MRP(Name,FCID,FCPeriod,FromDate,ToDate,
				StatusID,IsGroup,Depth,ParentID,lft,rgt
				,DefaultPreferences,OrderFilter,TreeXML,
				GUID,CreatedBy,CreatedDate)
			select @ProfileName,x.value('FCID[1]','INT'),x.value('FCPeriod[1]','nvarchar(50)'),convert(float,x.value('FromDate[1]','DateTime')),convert(float,x.value('ToDate[1]','DateTime')),
			  x.value('StatusID[1]','int'),@IsGroup,@Depth,@ParentID,@lft,@rgt
			  ,convert(nvarchar(max),x.query('DefaultPref[1]')),@Param2,@Param3,
			  newid(),@UserName,convert(float,getdate())
			from @XML.nodes('/XML') as data(x)
			SET @MRPID=SCOPE_IDENTITY()
		END--------END INSERT RECORD-----------
		ELSE
		BEGIN
		BEGIN TRANSACTION
			update INV_MRP set Name=@ProfileName
			,FCID=x.value('FCID[1]','INT'),FCPeriod=x.value('FCPeriod[1]','nvarchar(50)')
			,FromDate=convert(float,x.value('FromDate[1]','DateTime')),ToDate=convert(float,x.value('ToDate[1]','DateTime'))
			,DefaultPreferences=convert(nvarchar(max),x.query('DefaultPref[1]'))
			,OrderFilter=@Param2
			,TreeXML=@Param3
			,GUID=newid(),ModifiedBy=@UserName,ModifiedDate=convert(float,getdate())
			from @XML.nodes('/XML') as data(x)      
			where MRPID=@MRPID  
		COMMIT TRANSACTION
		END
		--select convert(nvarchar(max),x.query('DefaultPref[1]')) from @XML.nodes('/XML') as data(x)			
		--select * from INV_MRP where MRPID=@MRPID
		
		--
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID
	END
	ELSE IF @Type=5
	BEGIN
		CREATE TABLE #TblOrderFilter(InvDetailsID INT)
		CREATE TABLE #TblOrderProducts(PID INT)
		CREATE TABLE #TblProducts(ID int identity(1,1),PID INT,BOMID INT,ParentRowID int,RawQty float,OPID INT,OPIDQty float,ORD INT)
		declare @TblComQty as table(Qry nvarchar(max))
		declare @OrderDateField nvarchar(30),@OrderWhere nvarchar(60),@ToDate datetime,@OrderDetailsIDFilter nvarchar(max),@ShowRaw bit,@ShowRMBasedOnKIT bit
		
		if @UserName!=''
		begin
			set @XML=@UserName
			select @ShowRaw=(case when X.value('ShowRawMaterials[1]','nvarchar(max)') is null then 0 else 1 end)
			from @XML.nodes('XML') as Data(X)
			select @ShowRMBasedOnKIT=(case when X.value('ShowRMBasedOnKIT[1]','nvarchar(max)') is null then 0 else 1 end)
			from @XML.nodes('XML') as Data(X)			
		end

		--Commited Qty
		set @XML=@Param2
		declare @CommitedQTY nvarchar(max)
		select @CommitedQTY=X.value('SO[1]','nvarchar(max)'),@OrderDateField=X.value('@Filter','nvarchar(50)'),@ToDate=X.value('@ToDate','datetime')
		from @XML.nodes('XML') as Data(X)
		if @OrderDateField='DueDate'
			set @OrderDateField='isnull(A.DueDate,A.DocDate)'
		set @OrderWhere=' and convert(float,A.'+@OrderDateField+')<='+convert(nvarchar,convert(float,@ToDate))
		IF @CommitedQTY<>''
		BEGIN		
			insert into #TblOrderProducts
			exec spRPT_MRPPendingOrders 'ProductsList',@CommitedQTY,@OrderDateField,0,@OrderWhere,@Param3
			select 'we',@CommitedQTY,@OrderDateField,0,@OrderWhere,@Param3
		END
		set @CommitedQTY=''
		select @CommitedQTY=X.value('@CC','nvarchar(max)') from @XML.nodes('XML/SOFilter') as Data(X)
		IF @CommitedQTY<>''
		BEGIN	
			select @OrderDetailsIDFilter=X.value('SOFilter[1]','nvarchar(max)')	from @XML.nodes('XML') as Data(X)
			truncate table #TblOrderFilter
			insert into #TblOrderFilter
			EXEC SPSplitString @OrderDetailsIDFilter,','

			insert into #TblOrderProducts
			exec spRPT_MRPPendingOrders 'ProductsList',@CommitedQTY,@OrderDateField,1,@OrderWhere,@Param3
			
			select 'ProductsList',@CommitedQTY,@OrderDateField,1,@OrderWhere,@Param3
		END

		set @SQL='SELECT P.ProductID,P.BOM,0,0,0,0,0
FROM INV_Product P WITH(NOLOCK)'
        IF @Param2!=''
			set @SQL=@SQL+' left join #TblOrderProducts OP on OP.PID=P.ProductID'
        set @SQL=@SQL+' WHERE P.IsGroup=0 AND P.ProductTypeId<>6'
        if @Param2!=''
        begin
			if @Param1!=''
			begin
				set @SQL=@SQL+' and (OP.PID is not null or (1=1'+@Param1+'))'
			end
			else
				set @SQL=@SQL+' and OP.PID is not null'
		end
		else
			set @SQL=@SQL+@Param1
			
		set @SQL=@SQL+' ORDER BY P.ProductName'
	--	print(@SQL)
		insert into #TblProducts
		exec(@SQL)
		
		declare @I int,@CNT nvarchar(max)
		SET @I=0
		while(1=1 and @ShowRaw=1)
		begin
			set @CNT=(select Count(*) FROM #TblProducts WITH(NOLOCK))
			--Group By added if same rawmaterial used @ different stages in same bom
			insert into #TblProducts
			SELECT BP.ProductID,P.BOM,TP.ID,sum((BP.Quantity/(isnull(PU.Conversion,1)*U.Conversion))/BOM.FPQty)--,BP.Quantity/isnull(PU.Conversion,1)
			,(SELECT TOP 1 OUTBP.ProductID FROM PRD_BOMProducts OUTBP with(nolock) WHERE OUTBP.BOMID=BP.BOMID AND OUTBP.StageID=BP.StageID AND OUTBP.ProductUse=2)
			,SUM(isnull(BP.Quantity,0))/isnull((SELECT TOP 1 OUTBP.Quantity FROM PRD_BOMProducts OUTBP with(nolock) WHERE OUTBP.BOMID=BP.BOMID AND OUTBP.StageID=BP.StageID AND OUTBP.ProductUse=2),0),BP.BOMProductID
			FROM PRD_BOMProducts BP with(nolock)
			inner join #TblProducts TP WITH(NOLOCK) ON BP.BOMID=TP.BOMID			
			inner join INV_Product P WITH(NOLOCK) ON P.ProductID=BP.ProductID
			inner join PRD_BillOfMaterial BOM with(nolock) on BOM.BOMID=TP.BOMID
			inner join PRD_BOMStages BS with(nolock) on BS.StageID=BP.StageID
			left join COM_UOM PU with(nolock) ON PU.UOMID=P.UOMID
			LEFT JOIN COM_UOM U with(nolock) ON U.UOMID=BOM.UOMID
			WHERE  BP.ProductUse=1 and TP.ID>@I and TP.ID<=@CNT
			group by BP.ProductID,P.BOM,TP.ID,BP.StageID,BP.BOMID,BP.BOMProductID
			
			IF @CNT=(SELECT Count(*) FROM #TblProducts WITH(NOLOCK))
				BREAK
			SET @I=@CNT
		end
		
--	select * from #TblProducts
	
		set @SQL='SELECT P.ProductID,P.ProductCode,P.ProductName,P.LeadTime,P.SafetyStock,P.ReorderMinOrderQty,P.ReorderOrderMultiple'
		if @ShowRaw=1
			set @SQL=@SQL+',TP.ID,isnull(TP.BOMID,0) BOMID,TP.ParentRowID,TP.RawQty,TP.OPID,TP.OPIDQty,TP.ORD'
		set @SQL=@SQL+'
FROM INV_Product P WITH(NOLOCK)
inner join #TblProducts TP WITH(NOLOCK) on TP.PID=P.ProductID'

		if @ShowRaw=1
			set @SQL=@SQL+' order by TP.ParentRowID,TP.ORD DESC,TP.ID DESC'
		ELSE
			set @SQL=@SQL+' order by TP.ID'
			
		--print(@SQL)
		exec(@SQL)
		
		if @MRPID>0
		begin
			set @SQL='select INV.ProductID,N.* from INV_DocDetails INV with(nolock) inner join COM_DocTextData N with(nolock) on N.InvDocDetailsID=INV.InvDocDetailsID
where INV.DocID='+convert(nvarchar,@MRPID)
			exec(@SQL)
		end
		else
			select 1 NOFC where 1!=1
			
		---PRODUCT WISE VENDORS DATA
		SELECT V.ProductID,V.AccountID VendorID,(SELECT TOP 1 AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=V.AccountID) VendorName
		FROM INV_ProductVendors V with(nolock) INNER JOIN (	
				SELECT V.ProductID,MAX(Priority) Prio
				FROM INV_ProductVendors V with(nolock) INNER JOIN #TblProducts TP WITH(NOLOCK) ON V.ProductID=TP.PID 
				GROUP BY V.ProductID) AS T ON T.ProductID=V.ProductID AND T.Prio=V.Priority
		
		--KIT		
		if @ShowRMBasedOnKIT=1
		begin
			select KP.ParentProductID,KP.ProductID,max(KP.Quantity) RawQty from INV_ProductBundles KP with(nolock)
			inner join #TblProducts TP WITH(NOLOCK) on KP.ProductID=TP.PID
			group by KP.ParentProductID,KP.ProductID
		
			set @SQL='SELECT distinct P.ProductID,P.ProductCode,P.ProductName,P.LeadTime,P.SafetyStock,P.ReorderMinOrderQty,P.ReorderOrderMultiple
FROM INV_ProductBundles KP with(nolock)
inner join #TblProducts TP WITH(NOLOCK) on KP.ProductID=TP.PID
inner join INV_Product P with(nolock) on KP.ParentProductID=P.ProductID
'	
			print(@SQL)
			exec(@SQL)
		end
		else
		begin
			select 1 NOKIT where 1!=1
			select 1 NOKIT where 1!=1
		end
		
		DROP TABLE #TblOrderProducts
		DROP TABLE #TblOrderFilter
		DROP TABLE #TblProducts
	END
	ELSE IF @Type=6
	BEGIN
		CREATE TABLE #TblOrderList(InvDetailsID INT,Qty float,PendingQty float)
		set @XML=@Param1
		select @SQL=X.value('Select[1]','nvarchar(max)'),@Join=X.value('Join[1]','nvarchar(max)'),@CCWhere=X.value('CCWhere[1]','nvarchar(max)'),
				@ProductWhere=isnull(X.value('ProductWhere[1]','nvarchar(max)'),''),@OrderDateField=X.value('@Filter','nvarchar(50)'),@ToDate=X.value('@ToDate','datetime')
		from @XML.nodes('XML') as Data(X)
		if @OrderDateField='DueDate'
			set @OrderDateField='isnull(A.DueDate,A.DocDate)'
		set @OrderWhere=' and convert(float,A.'+@OrderDateField+')<='+convert(nvarchar,convert(float,@ToDate))
		
		--select @SQL,@Join,@CCWhere,@ProductWhere,@OrderDateField,@OrderWhere
		insert into #TblOrderList
		exec spRPT_MRPPendingOrders 'OrderDetail',@MRPID,@OrderDateField,0,@OrderWhere,''
		
		--select * from #TblOrderList
		
		set @SQL='select '+@SQL+',TOR.Qty,TOR.PendingQty from '+@Join+' inner join #TblOrderList TOR on TOR.InvDetailsID=INV.InvDocDetailsID'
		set @SQL=@SQL+' WHERE INV.CostCenterID='+convert(nvarchar,@MRPID)+@ProductWhere+@CCWhere
		set @SQL=@SQL+' ORDER BY INV.DocDate,INV.VoucherNo'
		
	--	print(@SQL)
		exec(@SQL)
		drop table #TblOrderList
	END
	ELSE IF @Type=7
	BEGIN
	BEGIN TRANSACTION
		INSERT INTO com_docbridge(CostCenterID,NodeID,AccDocID,InvDocID,Abbreviation,CompanyGUID,GUID,CreatedBy,CreatedDate,RefDimensionID,RefDimensionNodeID)
		VALUES(@Param1,@Param2,0,0,'','',newid(),@UserName,convert(float,getdate()),257,@MRPID)
	COMMIT TRANSACTION
	END
	ELSE IF @Type=8
	BEGIN
	BEGIN TRANSACTION
		set @XML=@Param1
		INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
		FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
		GUID,CreatedBy,CreatedDate)  
		SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
		X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),257,257,@MRPID,
		X.value('@GUID','NVARCHAR(50)'),X.value('@UserName','NVARCHAR(50)'),convert(float,getdate())  
		FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID
	COMMIT TRANSACTION
	END
	ELSE IF @Type=9
	BEGIN
		select FileID,FileDescription,convert(datetime,CreatedDate) CreatedDate,GUID From COM_Files with(nolock) 
		where CostCenterID=257 and FeaturePK=@MRPID
		Order By FileDescription
	END
	ELSE IF @Type=10
	BEGIN
	BEGIN TRANSACTION
		DELETE From COM_Files where CostCenterID=257 and FeaturePK=@MRPID and FileID=@Param1
	COMMIT TRANSACTION
	END
	ELSE IF @Type=11--FIFO Priority Report
	BEGIN
		declare @QOH nvarchar(max),@PODocs nvarchar(max)
		CREATE TABLE #TblOrderFIFO(InvDetailsID INT,Qty float,PendingQty float)
		CREATE TABLE #TblPOFIFO(ProductID INT,PendingQty float)
		
		set @XML=@Param1
		select @SQL=X.value('Select[1]','nvarchar(max)'),@Join=X.value('Join[1]','nvarchar(max)'),@CCWhere=X.value('CCWhere[1]','nvarchar(max)'),
				@ProductWhere=isnull(X.value('ProductWhere[1]','nvarchar(max)'),''),
				@OrderDateField=X.value('@POFilter','nvarchar(50)'),@PODocs=X.value('@PODocs','nvarchar(max)'),
				@ToDate=X.value('@ToDate','datetime')
		from @XML.nodes('XML') as Data(X)
		if @OrderDateField='DueDate'
			set @OrderDateField='isnull(A.DueDate,A.DocDate)'
		set @OrderWhere=' and convert(float,'+@OrderDateField+')<='+convert(nvarchar,convert(float,@ToDate))
		
		if @Param2=''
		begin
			select @Param2=@Param2+convert(nvarchar,CostCenterID)+',' FROM ADM_DocumentTypes WITH(NOLOCK) where DocumentType=7
			if @Param2!=''
				set @Param2=substring(@Param2,1,len(@Param2)-1)
		end
		--SELECT CostCenterID FROM ADM_DocumentTypes WITH(NOLOCK) WHERE DocumentType IN (SELECT DocumentType FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=40007)
		
		--select @SQL,@Join,@CCWhere,@ProductWhere,@OrderDateField,@OrderWhere
		insert into #TblOrderFIFO
		exec spRPT_MRPPendingOrders 'OrderDetail',@Param2,'DocDate',0,@OrderWhere,''
		
		if @PODocs!=''
		begin
			insert into #TblPOFIFO
			exec spRPT_MRPPendingOrders 'ProductWisePendingOrderQty','40002',@OrderDateField,0,@OrderWhere,''
		end
		--select * from #TblOrderList
		
		set @QOH=',(select SUM(UOMConvertedQty*VoucherType) from INV_DocDetails A WITH(NOLOCK)'
		if @CCWhere!=''
			set @QOH=@QOH+' inner join COM_DocCCDATA DCC with(nolock) on DCC.InvDocDetailsID=A.InvDocDetailsID'
		set @QOH=@QOH+' where A.ProductID=D.ProductID and (VoucherType=1 OR VoucherType=-1) AND IsQtyIgnored=0 and A.StatusID<>376
		and (A.DocumentType=3 or A.DocDate<='+convert(nvarchar,convert(float,@ToDate))+')'+@CCWhere+' ) QOH'
		
		set @SQL='select convert(datetime,D.DocDate) DocDate,D.VoucherNo DocNo,convert(datetime,D.DueDate) DueDate,P.ProductID,P.ProductCode ProductCode,P.ProductName ProductName,DR.AccountName DrAccount
		'+@QOH+@SQL+',TOR.Qty Qty,TOR.PendingQty PendingQty,TPO.PendingQty POQty
		from INV_DocDetails D with(nolock)
inner join COM_DocCCDATA DCC with(nolock) on DCC.InvDocDetailsID=D.InvDocDetailsID
inner join INV_Product P with(nolock) on P.ProductID=D.ProductID
INNER JOIN ACC_Accounts DR with(nolock) ON DR.AccountID=D.DebitAccount
inner join #TblOrderFIFO TOR on TOR.InvDetailsID=D.InvDocDetailsID
left join #TblPOFIFO TPO on TPO.ProductID=D.ProductID
'+@Join
		set @SQL=@SQL+' WHERE D.CostCenterID IN ('+convert(nvarchar,@Param2)+')'+@ProductWhere+@CCWhere
		set @SQL=@SQL+' ORDER BY D.DocDate,D.DocAbbr,D.DocPrefix,D.DocNumber'
		
		--print(@SQL)
		exec(@SQL)
		drop table #TblOrderFIFO
		drop table #TblPOFIFO
	END
	ELSE IF @Type=12
	BEGIN
		set @XML=@Param2
		set @Param2 = 'set @Param2=''''
		select @Param2=@Param2+'',''+convert(nvarchar,CostCenterID) from INV_DocDetails with(nolock) where DocID in ('+@Param1+') group by CostCenterID'
		EXEC sp_executesql @Param2,N'@Param2 nvarchar(max) OUTPUT',@Param2 OUTPUT
		set @Param2=substring(@Param2,2,len(@Param2)-1)
		set @OrderWhere=' and A.DocID in ('+@Param1+')'
		exec spRPT_MRPPendingOrders 'ProductsListWithDocID',@Param2,'',0,@OrderWhere,''
	END
	


SET NOCOUNT OFF;
RETURN @MRPID
END TRY
BEGIN CATCH  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
