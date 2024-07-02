USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetjobDetails]
	@NodeID [int],
	@DocID [int] = 0,
	@qtywhere [nvarchar](max),
	@docDate [datetime],
	@CostcenterID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON 
   
	Declare @CCID INT,@StageCCID INT,@Sql nvarchar(max),@tableName nvarchar(200),@DocumentType int,@BomCCID int,@UnqCCID int
	declare @VType int,@MachineDim INT,@DbCol nvarchar(500),@CrCol nvarchar(500),@DrAccID INT,@CrAccID INT,@OnlySelected nvarchar(10)
	

	select @DocumentType=DocumentType from ADM_DocumentTypes WITH(NOLOCK) where CostCenterID=@CostcenterID
	select @CCID=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where CostCenterID=76 and Name='JobDimension' and ISNUMERIC(Value)=1
	
	
	if(@DocumentType=1 or @DocumentType=27 or @DocumentType=26 or @DocumentType=25 or @DocumentType=2  or @DocumentType=34 or @DocumentType=6 or @DocumentType=3 or @DocumentType=4 or @DocumentType=13)      
		set @VType=1      
	else if(@DocumentType=11 or @DocumentType=5 or @DocumentType=7 or @DocumentType=9 or @DocumentType=24 or @DocumentType=33 or @DocumentType=10 or @DocumentType=8 or @DocumentType=12)      
		set @VType=-1      
	       
	set @StageCCID=0
	set @MachineDim=0
	set @UnqCCID=0
	
	
	select @OnlySelected=Value from adm_globalPreferences WITH(NOLOCK)
	where Name='ShowOnlySelectedStages'

	select @BomCCID=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where CostCenterID=76 and Name='BomDimension' and ISNUMERIC(Value)=1

	select @StageCCID=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where CostCenterID=76 and Name='StageDimension' and ISNUMERIC(Value)=1
	
	select @MachineDim=Value from COM_CostCenterPreferences WITH(NOLOCK) 
	where CostCenterID=76 and Name='MachineDimension' and ISNUMERIC(Value)=1
	
	select @UnqCCID=Value from COM_CostCenterPreferences with(nolock) 
	where CostCenterID=76 and Name='JobFilterDim' and ISNUMERIC(Value)=1
	
	if(@UnqCCID>0)
		select @tableName=TableName from ADM_Features with(nolock) where FeatureID=@UnqCCID

	if(@DocumentType not in(36,37) and @VType=1)
	BEGIN
		
		set @Sql='Select distinct BomName,[StageID],b.FPQty,a.[BomID],a.[ProductID],[Qty],a.IsBom,a.[UOMID],b.ProductID BomProductID,i.ProductName
		,b.CCID,b.CCNodeID,DimID '
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',d.Name DimName '
		
	
		set @Sql=@Sql +' from PRD_JobOuputProducts a WITH(NOLOCK) 
		join  PRD_BillOfMaterial b WITH(NOLOCK) on a.BomID=b.BOMID
		join INV_Product i WITH(NOLOCK)  on b.ProductID=i.ProductID '
		if(@UnqCCID>0)
			set @Sql=@Sql +' left join '+@tableName+' d WITH(NOLOCK)  on a.DimID=d.NodeID '
			
	    if exists (select PrefValue from COM_DocumentPreferences with(nolock)
		where CostCenterID=@CostCenterID and PrefName='jobswithissues' and PrefValue='True')
		BEGIN
			SET @Sql=@Sql+' join  (select distinct dcCCNID'+CONVERT(nvarchar,(@CCID-50000))+' ID '
			
			if(@BomCCID>0)
					set @Sql=@Sql +',dcCCNID'+CONVERT(nvarchar,(@BomCCID-50000))+' BomID '
			
			SET @Sql=@Sql+' from INV_DocDetails i with(nolock) 
			join COM_DocCCData d with(nolock) on d.InvDocDetailsID=i.InvDocDetailsID
			where i.VoucherType=-1 and IsQtyIgnored=0) as t on a.NodeID=t.ID '
			if(@BomCCID>0)
					set @Sql=@Sql +' and b.CCNodeID=t.BomID  '
		END
		
		set @Sql=@Sql+' where (a.StatusID=0 or a.StatusID=5) and a.NodeID='+CONVERT(nvarchar,@NodeID)+' and a.CostCenterID='+CONVERT(nvarchar,@CCID)		
		--print @Sql
		exec(@Sql)
	END
	ELSE
	BEGIN	
		set @Sql='Select BomName,[StageID],b.FPQty,a.[BomID],a.[ProductID],[Qty],a.IsBom,a.[UOMID],b.ProductID BomProductID,i.ProductName
		,b.CCID,b.CCNodeID,DimID '
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',d.Name DimName '
	
		set @Sql=@Sql +' from PRD_JobOuputProducts a WITH(NOLOCK) 
		join  PRD_BillOfMaterial b WITH(NOLOCK) on a.BomID=b.BOMID
		join INV_Product i WITH(NOLOCK) on b.ProductID=i.ProductID'
		if(@UnqCCID>0)
			set @Sql=@Sql +' left join '+@tableName+' d WITH(NOLOCK)  on a.DimID=d.NodeID '
			
		set @Sql=@Sql +' where (a.StatusID=0 or a.StatusID=5) and a.NodeID='+CONVERT(nvarchar,@NodeID)+' and a.CostCenterID='+CONVERT(nvarchar,@CCID)
		--print @Sql
		exec(@Sql)
	END	
	
	if(@DocumentType=37)
	BEGIN
		set @Sql='SELECT Distinct BE.*,c.AccountName CRAccountName,d.AccountName DRAccountName,a.DimID
		,( SELECT isnull(sum(dcNum1),0) FROM INV_DocDetails i  WITH(NOLOCK) 
		  join COM_DocNumData n  WITH(NOLOCK) on i.InvDocDetailsID=n.InvDocDetailsID 
		  join COM_DocCCData d  WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID 
			 where  i.CreditAccount=CreditAccountID and i.DebitAccount=DebitAccountID and documenttype=37 AND dcccnid'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
			if(@StageCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@StageCCID-50000))+'=s.StageNodeID'
			if(@BomCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=BOM.CCNodeID '		
			if(@UnqCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=a.DimID '		
				
				set @Sql=@Sql +') as Used 
		FROM  [PRD_Expenses] BE with(nolock) 
		join PRD_JobOuputProducts a WITH(NOLOCK) on BE.[BOMID] =a.[BomID] 
		join PRD_BOMStages s WITH(NOLOCK) on BE.[StageID]=s.[StageID]
		left join Acc_Accounts c WITH(NOLOCK) on BE.CreditAccountID=c.AccountID	
		left join Acc_Accounts d WITH(NOLOCK) on BE.DebitAccountID=d.AccountID	'
		if(@BomCCID>0)
				set @Sql=@Sql +' JOIN PRD_BillOfMaterial BOM WITH(NOLOCK) on BE.BOMID=BOM.BOMID '
			 
		set @Sql=@Sql +' where  (a.StatusID=0 or a.StatusID=5) and a.NodeID='+convert(nvarchar,@NodeID)+' and a.CostCenterID='+convert(nvarchar,@CCID)
		exec(@Sql)
		print @Sql
	END
	ELSE if(@DocumentType=36)
	BEGIN		
		if(LEN(@MachineDim)>0  and convert(int,@MachineDim)>50000)
		begin
			select @tableName=TableName from ADM_Features with(nolock) where FeatureID=convert(int,@MachineDim)
	
			SELECT @DrAccID=b.DebitAccount,@CrAccID=b.CreditAccount,@CrCol=c.SysColumnName,@DbCol=d.SysColumnName FROM ADM_CostCenterDef a with(nolock) 
			join ADM_DocumentDef b WITH(NOLOCK) on a.CostCenterColID=b.CostCenterColID
			left join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=b.CrRefColID
			left join ADM_CostCenterDef d WITH(NOLOCK) on d.CostCenterColID=b.DrRefColID
			WHERE a.SysColumnName='dcnum3' and a.CostcenterID=@CostcenterID

			set @Sql='SELECT Distinct BR.*,D.Name ResourceName,a.DimID
			,(SELECT isnull(sum(dcNum2),0) FROM COM_DocNumData i WITH(NOLOCK) 
			 join COM_DocCCData d WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID 
			 where dcccnid'+convert(nvarchar,(@MachineDim-50000))+'=BR.ResourceID AND dcccnid'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
			if(@StageCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@StageCCID-50000))+'=s.StageNodeID '
			if(@BomCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=BOM.CCNodeID '		
			if(@UnqCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=a.DimID '
		
				set @Sql=@Sql +') as Used '
			if exists(select * from sys.columns a
					join sys.tables b on a.object_id=b.object_id
					where a.name=@CrCol and b.name=@tableName)
				set @Sql=@Sql +',D.'+@CrCol+' as CrAccountID,Cr.AccountName as CrAccount'
			Else if(@CrAccID>0)
				set @Sql=@Sql +','+convert(nvarchar,@CrAccID)+' as CrAccountID,Cr.AccountName as CrAccount'	
			if exists(select * from sys.columns a
					join sys.tables b on a.object_id=b.object_id
					where a.name=@DbCol and b.name=@tableName)
				set @Sql=@Sql +',D.'+@DbCol+' as DrAccountID,Dr.AccountName as DrAccount'
			Else if(@DrAccID>0)
				set @Sql=@Sql +','+convert(nvarchar,@DrAccID)+' as DrAccountID,Dr.AccountName as DrAccount'	

			set @Sql=@Sql +'	FROM  [PRD_BOMResources] BR with(nolock)
			join PRD_JobOuputProducts a WITH(NOLOCK) on BR.[BOMID] =a.[BomID] 
			 INNER JOIN '+@tableName+' D with(nolock) ON BR.ResourceID=D.NodeID'
			
			if(@BomCCID>0)
				set @Sql=@Sql +' JOIN PRD_BillOfMaterial BOM WITH(NOLOCK) on Br.BOMID=BOM.BOMID '
			
			if exists(select * from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where a.name=@CrCol and b.name=@tableName)
				set @Sql=@Sql +' left join acc_accounts cr WITH(NOLOCK) on cr.accountID=D.'+@CrCol
			Else if(@CrAccID>0)
				set @Sql=@Sql +' left join acc_accounts cr WITH(NOLOCK) on cr.accountID='+CONVERT(nvarchar,@CrAccID)
			if exists(select * from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where a.name=@DbCol and b.name=@tableName)
				set @Sql=@Sql +' left join acc_accounts Dr WITH(NOLOCK) on Dr.accountID=D.'+@DbCol
			Else if(@DrAccID>0)
				set @Sql=@Sql +' left join acc_accounts Dr WITH(NOLOCK) on Dr.accountID='+CONVERT(nvarchar,@DrAccID)

			 if(@StageCCID>0)
			  set @Sql=@Sql +' join PRD_BOMStages s WITH(NOLOCK) on BR.[StageID]=s.[StageID]'
			 set @Sql=@Sql +' where (a.StatusID=0 or a.StatusID=5) and a.NodeID='+convert(nvarchar,@NodeID)+' and a.CostCenterID='+convert(nvarchar,@CCID)
			exec(@Sql)
		end
	END
	ELSE
	BEGIN	
	
	set @Sql='SELECT *,(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i  WITH(NOLOCK) 
			join COM_DocCCData d  WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID 
			WHERE ProductID= a.ProductID AND IsQtyIgnored=0 AND '+@qtywhere+' (VoucherType=1 OR VoucherType=-1) 
			and statusid=369 and DocDate<='+CONVERT(nvarchar,(convert(float,@docDate)))+') as QOH
			
		   ,(SELECT isnull(sum(UOMConvertedQty),0) FROM INV_DocDetails i  WITH(NOLOCK) 
			join COM_DocCCData d  WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID 
			WHERE ProductID= a.ProductID AND IsQtyIgnored=0 AND dcccnid'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
			if(@StageCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@StageCCID-50000))+'=a.StageNodeID'
			if(@BomCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=a.CCNodeID '		
			if(@UnqCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=a.DimID '

		 set @Sql=@Sql +' and  (VoucherType='+convert(nvarchar,@VType)+')        
			and DocDate<='+CONVERT(nvarchar,(convert(float,@docDate)))+') as Used '
			 if(@VType=1)
			 BEGIN
				  set @Sql=@Sql +',(SELECT isnull(sum(UOMConvertedQty),0) FROM INV_DocDetails i  WITH(NOLOCK) 
				join COM_DocCCData d  WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID 
				WHERE ProductID= a.ProductID AND IsQtyIgnored=0 AND dcccnid'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
				if(@StageCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@StageCCID-50000))+'=a.StageNodeID'
				if(@BomCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=a.CCNodeID '		
				if(@UnqCCID>0)
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=a.DimID '
		
				set @Sql=@Sql +' and  (VoucherType=-1)        
				and DocDate<='+CONVERT(nvarchar,(convert(float,@docDate)))+') as Issued '
	     
			 END
			 else
			 BEGIN
					set @DbCol=''
					select @DbCol=Value from COM_CostCenterPreferences WITH(NOLOCK)
					where CostCenterID=76 and Name='JobRemainingQty' and Value<>''
					if(@DbCol like 'dcnum%')
					BEGIN
						set @Sql=@Sql +',(SELECT isnull(sum('+@DbCol+'),0) FROM INV_DocDetails i  WITH(NOLOCK) 
						join COM_DocCCData d  WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID 
						join COM_DocNUmData dn  WITH(NOLOCK) on i.InvDocDetailsID=dn.InvDocDetailsID 	
						WHERE ProductID= a.ProductID AND IsQtyIgnored=0 AND dcccnid'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
						if(@StageCCID>0)
							set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@StageCCID-50000))+'=a.StageNodeID'
						if(@BomCCID>0)
								set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=a.CCNodeID '		
						if(@UnqCCID>0)
								set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=a.DimID '

						 set @Sql=@Sql +' and  (VoucherType='+convert(nvarchar,@VType)+')        
							and DocDate<='+CONVERT(nvarchar,(convert(float,@docDate)))+') as RemainingQty '
					END	
			 END
			 
		set @Sql=@Sql+' from(SELECT Distinct a.BOMProductID,a.Remarks,i.ProductCode,i.ProductName,i.ProductTypeID,a.[BOMID],[ProductUse],a.[ProductID],[Quantity],a.[UOMID]
		  ,a.AutoStage,[UnitPrice],[ExchgRT],a.[CurrencyID],[Value],a.[Wastage],[FilterOn],b.DimID,a.[StageID],U.BaseName,U.UnitName,U.Conversion'
		   
		   if(@StageCCID>0)
				set @Sql=@Sql +',s.StageNodeID'
			if(@BomCCID>0)
				set @Sql=@Sql +',BOM.CCNodeID '		
			
			set @Sql=@Sql +' FROM [PRD_BOMProducts] a WITH(NOLOCK)
			join PRD_JobOuputProducts b WITH(NOLOCK) on a.[BOMID] =b.[BomID] 
			join INV_Product i WITH(NOLOCK) on a.ProductID=i.ProductID
			left join COM_UOM U WITH(NOLOCK) on a.UOMID=U.UOMID '
			 if(@StageCCID>0)
			  set @Sql=@Sql +' join PRD_BOMStages s WITH(NOLOCK) on a.[StageID]=s.[StageID]'
			 if(@BomCCID>0)
				set @Sql=@Sql +' JOIN PRD_BillOfMaterial BOM WITH(NOLOCK) on a.BOMID=BOM.BOMID '
		
			 set @Sql=@Sql +'where (b.StatusID=0 or b.StatusID=5) and b.NodeID='+convert(nvarchar,@NodeID)+' and b.CostCenterID='+convert(nvarchar,@CCID)+') as a ORDER BY BOMProductID'
		print @Sql
		exec(@Sql)
	END
	
	select @tableName=TableName from ADM_Features WITH(NOLOCK)   WHere FeatureID=@CCID
	
	set @Sql='SELECT *,'+CONVERT(nvarchar,@CCID)+' jobCCID,'+CONVERT(nvarchar,@StageCCID)+' StageCCID ,'+CONVERT(nvarchar,@MachineDim)+' MachineCCID from '+@tableName+' WITH(NOLOCK) Where   NodeID='+convert(nvarchar,@NodeID)
	
	exec(@Sql)

	if(@StageCCID>0)
	BEGIN
		select @tableName=TableName from ADM_Features WITH(NOLOCK)   WHere FeatureID=@StageCCID
		
		set @Sql='SELECT BOMID,StageID,StageNodeID,Code,Name,a.lft from  PRD_BOMStages a WITH(NOLOCK)  
		join '+@tableName+' b WITH(NOLOCK) on a.StageNodeID=b.NodeID
		Where [BOMID] in (Select [BomID] from PRD_JobOuputProducts WITH(NOLOCK)  
		where (StatusID=0 or StatusID=5) and NodeID='+convert(nvarchar,@NodeID)+' and CostCenterID='+convert(nvarchar,@CCID)+')'
		
		exec(@Sql)
	END
	ELSE
		SELECt 1
		
	set @Sql='select BatchID,INV.UomConvertedQty Quantity,INV.ProductID'
	 if(@StageCCID>0)
        set @Sql=@Sql +',dcccnid'+convert(nvarchar,(@StageCCID-50000))+' StageID '
	set @Sql=@Sql+'FROm INV_DocDetails AS INV with(nolock) 
	INNER JOIN COM_DocCCData AS CC with(nolock) ON INV.InvDocDetailsID = CC.InvDocDetailsID
	where BatchID>1 and INV.VoucherType=-1 and INV.IsQtyIgnored=0  AND dcccnid'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
	set @Sql=@Sql+' and INV.ProductID in( SELECT a.[ProductID]
		FROM [PRD_BOMProducts] a WITH(NOLOCK)
		Where a.[BOMID] in (Select [BomID] from PRD_JobOuputProducts WITH(NOLOCK)  
		where (StatusID=0 or StatusID=5) and NodeID='+convert(nvarchar,@NodeID)+' and CostCenterID='+convert(nvarchar,@CCID)+')
		and [ProductUse]=1)'
	exec(@Sql)
	
	if exists(select prefvalue from COM_DocumentPreferences WITH(NOLOCK)
	where PrefName='QtyBasedCost' and PrefValue='true' and costcenterid=@CostcenterID)
		set @VType=-1
	
	if @VType=1 and exists(select prefvalue from COM_DocumentPreferences WITH(NOLOCK)
	where PrefName='CalcOpRate' and PrefValue='true' and costcenterid=@CostcenterID)
	BEGIN
		
		set @Sql='select bomID,ProductID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '
		
		set @Sql=@Sql+',sum(AMT) AMT from (select bt.bomID,bt.ProductID,sum(bt.Gross) AMT '
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',bt.DimID '
			
		set @Sql=@Sql+' from (select distinct b.bomID,c.ProductID,a.Gross,a.InvDocDetailsID '	
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '
			
		set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID
		join PRD_BOMProducts b WITH(NOLOCK) on a.ProductID=b.ProductID and b.IncInFinalCost=1
		join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
		Where a.documenttype=33  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
		END	
		
		if(@UnqCCID>0)
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '	
			
		
		set @Sql=@Sql+') as bt
		group by bt.bomID,bt.ProductID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',bt.DimID '
			
		set @Sql=@Sql+' UNION ALL
		select b.bomID,c.ProductID,sum(d.Amount) AMT '
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID		
		join PRD_Expenses b WITH(NOLOCK) on a.DebitAccount=b.DebitAccountID and a.CreditAccount=b.CreditAccountID and b.IncInFinalCost=1
		join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
		join ACC_DocDetails d WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID
		Where a.documenttype=37 and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
		END	
		if(@UnqCCID>0)
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
		set @Sql=@Sql+'
		group by b.bomID,c.ProductID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		if(LEN(@MachineDim)>0  and convert(int,@MachineDim)>50000)
		begin
			set @Sql=@Sql+' UNION ALL
			select b.bomID,c.ProductID,sum(d.Amount) AMT '
		
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
			join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID		
			join PRD_BOMResources b WITH(NOLOCK) on CC.dcccnid'+convert(nvarchar,(@MachineDim-50000))+'=b.ResourceID and b.IncInFinalCost=1
			join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
			join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
			join ACC_DocDetails d WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID
			Where a.documenttype=36  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
			if(@BomCCID>0)
			BEGIN
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			END	
			if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
			set @Sql=@Sql+'
			group by b.bomID,c.ProductID'
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

		END
		set @Sql=@Sql+') as t
			group by bomID,ProductID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '
	print @Sql
		exec(@Sql)
		
		set @Sql='select bomID,StageID,sum(AMT) AMT '
		
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' from (select b.bomID,b.StageID,sum(a.Gross) AMT '
		
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID
		join PRD_BOMProducts b WITH(NOLOCK) on a.ProductID=b.ProductID and b.IncInStageCost=1 '
		if(@StageCCID>0)
			set @Sql=@Sql+' join PRD_BOMStages st WITH(NOLOCK) on st.StageID=b.StageID and st.StageNodeID=CC.DCCCNID'+convert(nvarchar,(@StageCCID-50000))
			
		set @Sql=@Sql+' join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.StageID=b.StageID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
		Where a.documenttype=33  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
		END	
		if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
		
		set @Sql=@Sql+' 		group by b.bomID,b.StageID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '
		
		

		set @Sql=@Sql+' UNION ALL
		select b.bomID,b.StageID,sum(d.Amount) AMT '
		
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID		
		join PRD_Expenses b WITH(NOLOCK) on a.DebitAccount=b.DebitAccountID and a.CreditAccount=b.CreditAccountID and b.IncInStageCost=1
		join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.StageID=b.StageID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'				
		join ACC_DocDetails d WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID
		Where a.documenttype=37 and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
		END	
		if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
		set @Sql=@Sql+'		group by b.bomID,b.StageID'

		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		if(LEN(@MachineDim)>0  and convert(int,@MachineDim)>50000)
		begin
			set @Sql=@Sql+' UNION ALL
			select b.bomID,b.StageID,sum(d.Amount) AMT'
			
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '
			
			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
			join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID		
			join PRD_BOMResources b WITH(NOLOCK) on CC.dcccnid'+convert(nvarchar,(@MachineDim-50000))+'=b.ResourceID and b.IncInStageCost=1	
			join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
			join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.StageID=b.StageID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
			join ACC_DocDetails d WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID
			Where a.documenttype=36  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
			if(@BomCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '
				
			set @Sql=@Sql+'			group by b.bomID,b.StageID'
			
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

		END
		set @Sql=@Sql+') as t
			group by bomID,StageID'
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

			print @Sql
		exec(@Sql)
	END
	
SET NOCOUNT OFF;      
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
 SET NOCOUNT OFF        
RETURN -999         
END CATCH


GO
