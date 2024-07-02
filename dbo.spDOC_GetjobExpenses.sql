USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetjobExpenses]
	@NodeID [bigint],
	@BomIDs [nvarchar](max),
	@UnqCCID [bigint] = 0,
	@CCID [bigint] = 0,
	@BomCCID [bigint] = 0,
	@MachineDim [bigint] = 0,
	@IsDirectCall [bit] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON 
   
		declare @Sql nvarchar(max),@StageCCID BIGINT
		
		select @StageCCID=Value from COM_CostCenterPreferences WITH(NOLOCK)
		where CostCenterID=76 and Name='StageDimension' and ISNUMERIC(Value)=1

		if(@IsDirectCall=1)
		BEGIN
				set @BomCCID=0
				set @MachineDim=0
				set @UnqCCID=0
				
				select @CCID=Value from COM_CostCenterPreferences 
				where CostCenterID=76 and Name='JobDimension' and ISNUMERIC(Value)=1

				select @BomCCID=Value from COM_CostCenterPreferences 
				where CostCenterID=76 and Name='BomDimension' and ISNUMERIC(Value)=1
				
				select @UnqCCID=Value from COM_CostCenterPreferences with(nolock) 
				where CostCenterID=76 and Name='JobFilterDim' and ISNUMERIC(Value)=1
				
				select @MachineDim=Value from COM_CostCenterPreferences 
				where CostCenterID=76 and Name='MachineDimension' and ISNUMERIC(Value)=1

		END
		
		set @Sql='select bomID,ProductID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '
		
		set @Sql=@Sql+',sum(AMT) AMT from (select c.CCNodeID bomID,c.ProductID,sum(a.Gross) AMT '
		
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
			if(@BomIDs<>'')
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+' in ('+@BomIDs+')'		
		END	
		
		if(@UnqCCID>0)
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '
		set @Sql=@Sql+'
		group by c.CCNodeID,c.ProductID'
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '
		
		set @Sql=@Sql+' UNION ALL select c.CCNodeID bomID,c.ProductID,sum(a.Gross)*-1 AMT '
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID
		join PRD_BOMProducts b WITH(NOLOCK) on a.ProductID=b.ProductID and b.IncInFinalCost=1
		join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
		Where a.documenttype=34 and b.ProductUse=1   and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			if(@BomIDs<>'')
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+' in ('+@BomIDs+')'		
		END	
		
		if(@UnqCCID>0)
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '
		set @Sql=@Sql+'
		group by c.CCNodeID,c.ProductID'
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '
	

		set @Sql=@Sql+' UNION ALL
		select c.CCNodeID bomID,c.ProductID,sum(d.Amount) AMT '
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID		
		join PRD_Expenses b WITH(NOLOCK) on a.DebitAccount=b.DebitAccountID and a.CreditAccount=b.CreditAccountID and b.IncInFinalCost=1
		join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
		join ACC_DocDetails d on a.InvDocDetailsID=d.InvDocDetailsID
		Where a.documenttype=37 and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			if(@BomIDs<>'')
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+' in ('+@BomIDs+')'		
		END	
		if(@UnqCCID>0)
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
		set @Sql=@Sql+'
		group by c.CCNodeID,c.ProductID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		if(LEN(@MachineDim)>0  and convert(int,@MachineDim)>50000)
		begin
			set @Sql=@Sql+' UNION ALL
			select c.CCNodeID bomID,c.ProductID,sum(d.Amount) AMT '
		
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
			join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID		
			join PRD_BOMResources b WITH(NOLOCK) on CC.dcccnid'+convert(nvarchar,(@MachineDim-50000))+'=b.ResourceID and b.IncInFinalCost=1
			join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
			join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
			join ACC_DocDetails d on a.InvDocDetailsID=d.InvDocDetailsID
			Where a.documenttype=36  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
			if(@BomCCID>0)
			BEGIN
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
				if(@BomIDs<>'')
					set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+' in ('+@BomIDs+')'		
			END	
			if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
			set @Sql=@Sql+'
			group by c.CCNodeID,c.ProductID'
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

			set @Sql=@Sql+' from (select c.CCNodeID bomID,d.StageNodeID StageID,sum(a.Gross) AMT '
		
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID
		join PRD_BOMProducts b WITH(NOLOCK) on a.ProductID=b.ProductID and b.IncInStageCost=1 
		join PRD_BOMStages d  WITH(NOLOCK) on d.bomID=b.bomID and b.StageID=d.StageID and d.StageNodeID=CC.DCCCNID'+convert(nvarchar,(@StageCCID-50000))
		+' join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.StageID=b.StageID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
		Where a.documenttype=33  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			if(@BomIDs<>'')
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+' in ('+@BomIDs+')'		
		END	
		if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
		
		set @Sql=@Sql+' 		group by c.CCNodeID,d.StageNodeID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' UNION ALL select c.CCNodeID bomID,d.StageNodeID StageID,sum(a.Gross)*-1 AMT '
		
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID
		join PRD_BOMProducts b WITH(NOLOCK) on a.ProductID=b.ProductID and b.IncInStageCost=1
		join PRD_BOMStages d  WITH(NOLOCK) on d.bomID=b.bomID and b.StageID=d.StageID
		join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
		Where a.documenttype=34  and b.ProductUse=2  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			if(@BomIDs<>'')
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+' in ('+@BomIDs+')'		
		END	
		if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
		
		set @Sql=@Sql+' 		group by c.CCNodeID,d.StageNodeID'
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		set @Sql=@Sql+' UNION ALL
		select c.CCNodeID bomID,ds.StageNodeID StageID,sum(d.Amount) AMT '
		
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID		
		join PRD_Expenses b WITH(NOLOCK) on a.DebitAccount=b.DebitAccountID and a.CreditAccount=b.CreditAccountID and b.IncInStageCost=1
		join PRD_BOMStages ds  WITH(NOLOCK) on ds.bomID=b.bomID and b.StageID=ds.StageID
		join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'				
		join ACC_DocDetails d on a.InvDocDetailsID=d.InvDocDetailsID
		Where a.documenttype=37 and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			if(@BomIDs<>'')
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+' in ('+@BomIDs+')'		
		END	
		if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '		
		set @Sql=@Sql+'		group by c.CCNodeID,ds.StageNodeID'

		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		if(LEN(@MachineDim)>0  and convert(int,@MachineDim)>50000)
		begin
			set @Sql=@Sql+' UNION ALL
			select c.CCNodeID bomID,ds.StageNodeID StageID,sum(d.Amount) AMT'
			
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '
			
			set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
			join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID		
			join PRD_BOMResources b WITH(NOLOCK) on CC.dcccnid'+convert(nvarchar,(@MachineDim-50000))+'=b.ResourceID and b.IncInStageCost=1	
			join PRD_BOMStages ds  WITH(NOLOCK) on ds.bomID=b.bomID and b.StageID=ds.StageID
			join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
			join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
			join ACC_DocDetails d on a.InvDocDetailsID=d.InvDocDetailsID
			Where a.documenttype=36  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
			if(@BomCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			if(@UnqCCID>0)
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '
				
			set @Sql=@Sql+'			group by c.CCNodeID,ds.StageNodeID'
			
			if(@UnqCCID>0)
				set @Sql=@Sql +',DimID '

		END
		set @Sql=@Sql+') as t
			group by bomID,StageID'
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

			print @Sql
		exec(@Sql)
		
		
		set @Sql='select c.CCNodeID bomID,a.ProductID,sum(a.Quantity) QTY '
		
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '

		set @Sql=@Sql+' from inv_docdetails a WITH(NOLOCK)
		join Com_DOCCCDATA CC  WITH(NOLOCK) on a.InvDocDetailsID=cc.InvDocDetailsID
		join PRD_BOMProducts b WITH(NOLOCK) on a.ProductID=b.ProductID
		join PRD_BillOfMaterial c WITH(NOLOCK) on c.bomID=b.bomID 
		join PRD_JobOuputProducts j WITH(NOLOCK) on c.BOMID=j.BomID and j.NodeID='+convert(nvarchar,@NodeID)+' and j.CostCenterID='+convert(nvarchar,@CCID)+'		
		Where a.documenttype=34 and b.ProductUse=2  and CC.DCCCNID'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@NodeID)
		if(@BomCCID>0)
		BEGIN
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+'=c.CCNodeID '		
			if(@BomIDs<>'')
				set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@BomCCID-50000))+' in ('+@BomIDs+')'		
		END	
		
		if(@UnqCCID>0)
			set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@UnqCCID-50000))+'=j.DimID '
		
		set @Sql=@Sql+'
		group by c.CCNodeID,a.ProductID'
		if(@UnqCCID>0)
			set @Sql=@Sql +',DimID '
			
			print @Sql
		exec(@Sql)

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
