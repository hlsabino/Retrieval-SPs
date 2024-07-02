USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetBomDetails]
	@BomID [int],
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
   
	Declare @CCID INT,@StageCCID INT,@Sql nvarchar(max),@tableName nvarchar(200),@DocumentType int
	declare @VType int,@MachineDim INT,@DbCol nvarchar(500),@CrCol nvarchar(500),@DrAccID INT,@CrAccID INT
	

	select @DocumentType=DocumentType from ADM_DocumentTypes with(nolock) where CostCenterID=@CostcenterID
	select @CCID=Value from COM_CostCenterPreferences with(nolock) 
	where CostCenterID=76 and Name='BomDimension' and ISNUMERIC(Value)=1
	
	if(@DocumentType=1 or @DocumentType=27 or @DocumentType=26 or @DocumentType=25 or @DocumentType=2  or @DocumentType=34 or @DocumentType=6 or @DocumentType=3 or @DocumentType=4 or @DocumentType=13)      
		set @VType=1      
	else if(@DocumentType=11 or @DocumentType=7 or @DocumentType=9 or @DocumentType=24 or @DocumentType=33 or @DocumentType=10 or @DocumentType=8 or @DocumentType=12)      
		set @VType=-1      
	       
	set @StageCCID=0
	set @MachineDim=0
	
	select @StageCCID=Value from COM_CostCenterPreferences with(nolock) 
	where CostCenterID=76 and Name='StageDimension' and ISNUMERIC(Value)=1
		
	select @MachineDim=Value from COM_CostCenterPreferences with(nolock) 
	where CostCenterID=76 and Name='MachineDimension' and ISNUMERIC(Value)=1
		
	Select BomName,[StageID],a.FPQty,a.[BOMID],b.[ProductID],Quantity [Qty],'true' IsBom,b.[UOMID],a.ProductID BomProductID,i.ProductName  
	,a.CCID,a.CCNodeID 
	from  PRD_BillOfMaterial a with(nolock)
	join PRD_BOMProducts b with(nolock) on a.[BomID]=b.[BOMID] and b.ProductUse=2
	join INV_Product i with(nolock) on a.ProductID=i.ProductID
	where a.BOMID=@BomID
	
	if(@DocumentType=37)
	BEGIN
		set @Sql='SELECT BE.*,c.AccountName CRAccountName,d.AccountName DRAccountName
		,0 as Used 
		FROM  [PRD_Expenses] BE with(nolock)
		 join PRD_BOMStages s with(nolock) on BE.[StageID]=s.[StageID]
		left join Acc_Accounts c WITH(NOLOCK) on BE.CreditAccountID=c.AccountID	
		left join Acc_Accounts d WITH(NOLOCK) on BE.DebitAccountID=d.AccountID		 
		Where BE.[BOMID]='+convert(nvarchar,@BomID)
		exec(@Sql)
		print @Sql
	END
	ELSE if(@DocumentType=36)
	BEGIN		
		if(LEN(@MachineDim)>0  and convert(int,@MachineDim)>50000)
		begin
			select @tableName=TableName from ADM_Features with(nolock) where FeatureID=convert(int,@MachineDim)
	
			SELECT @DrAccID=b.DebitAccount,@CrAccID=b.CreditAccount,@CrCol=c.SysColumnName,@DbCol=d.SysColumnName 
			FROM ADM_CostCenterDef a with(nolock) 
			join ADM_DocumentDef b with(nolock) on a.CostCenterColID=b.CostCenterColID
			left join ADM_CostCenterDef c with(nolock) on c.CostCenterColID=b.CrRefColID
			left join ADM_CostCenterDef d with(nolock) on d.CostCenterColID=b.DrRefColID
			WHERE a.SysColumnName='dcnum3' and a.CostcenterID=@CostcenterID

			set @Sql='SELECT BR.*,D.Name ResourceName
			,0 as Used '
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
			INNER JOIN '+@tableName+' D with(nolock) ON BR.ResourceID=D.NodeID'
			if exists(select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where a.name=@CrCol and b.name=@tableName)
				set @Sql=@Sql +' left join acc_accounts cr with(nolock) on cr.accountID=D.'+@CrCol
			Else if(@CrAccID>0)
				set @Sql=@Sql +' left join acc_accounts cr with(nolock) on cr.accountID='+CONVERT(nvarchar,@CrAccID)
			if exists(select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where a.name=@DbCol and b.name=@tableName)
				set @Sql=@Sql +' left join acc_accounts Dr with(nolock) on Dr.accountID=D.'+@DbCol
			Else if(@DrAccID>0)
				set @Sql=@Sql +' left join acc_accounts Dr with(nolock) on Dr.accountID='+CONVERT(nvarchar,@DrAccID)

			 if(@StageCCID>0)
			  set @Sql=@Sql +' join PRD_BOMStages s with(nolock) on BR.[StageID]=s.[StageID]'
			 set @Sql=@Sql +'WHERE BR.BOMID='+convert(nvarchar,@BomID)
			exec(@Sql)
		end
	END
	ELSE
	BEGIN	
		set @Sql='SELECT i.ProductCode,i.ProductName,i.ProductTypeID,a.[BOMID],[ProductUse],a.[ProductID],[Quantity],a.[UOMID],a.Remarks
		  ,a.AutoStage,[UnitPrice],[ExchgRT],a.[CurrencyID],[Value],a.[Wastage],[FilterOn],a.[StageID],U.BaseName,U.UnitName,U.Conversion
		   ,(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i  WITH(NOLOCK) 
			join COM_DocCCData d  WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID 
			WHERE ProductID= a.ProductID AND IsQtyIgnored=0 AND '+@qtywhere+' (VoucherType=1 OR VoucherType=-1) 
			and DocDate<='+CONVERT(nvarchar,(convert(float,@docDate)))+') as QOH
		   ,0 as Used '
			 if(@VType=1)
			 BEGIN
				  set @Sql=@Sql +',0 as Issued '
	     
			 END
			set @Sql=@Sql +' FROM [PRD_BOMProducts] a WITH(NOLOCK)
			join INV_Product i with(nolock) on a.ProductID=i.ProductID
			left join COM_UOM U WITH(NOLOCK) on a.UOMID=U.UOMID '
			 if(@StageCCID>0)
			  set @Sql=@Sql +' join PRD_BOMStages s with(nolock) on a.[StageID]=s.[StageID]'
			 set @Sql=@Sql +'Where a.[BOMID]='+convert(nvarchar,@BomID)
		
		exec(@Sql)
	END
	
	SELECT *,@CCID BomCCID,@StageCCID StageCCID ,@MachineDim MachineCCID 
	from PRD_BillOfMaterial a with(nolock)
	join PRD_BillOfMaterialExtended b with(nolock) on a.BOMID=b.BOMID
	Where a.BOMID=@BomID
	
	

	if(@StageCCID>0)
	BEGIN
		select @tableName=TableName from ADM_Features WITH(NOLOCK)   WHere FeatureID=@StageCCID
		
		set @Sql='SELECT BOMID,StageID,StageNodeID,Code,Name,a.lft from  PRD_BOMStages a WITH(NOLOCK)  
		join '+@tableName+' b with(nolock) on a.StageNodeID=b.NodeID
		Where [BOMID]='+convert(nvarchar,@BomID)
		
		exec(@Sql)
	END
	ELSE
		SELECT 1
		
	set @Sql='select BatchID,INV.UomConvertedQty Quantity,INV.ProductID'
	 if(@StageCCID>0)
        set @Sql=@Sql +',dcccnid'+convert(nvarchar,(@StageCCID-50000))+' StageID '
	set @Sql=@Sql+'FROm INV_DocDetails AS INV with(nolock) 
	INNER JOIN COM_DocCCData AS CC with(nolock) ON INV.InvDocDetailsID = CC.InvDocDetailsID
	where BatchID>1 and INV.VoucherType=-1 and INV.IsQtyIgnored=0 '
	if(@CCID is not null and @CCID>50000)
		set @Sql=@Sql +' AND dcccnid'+convert(nvarchar,(@CCID-50000))+'='+convert(nvarchar,@BomID)
	set @Sql=@Sql+' and INV.ProductID in( SELECT a.[ProductID]
		FROM [PRD_BOMProducts] a WITH(NOLOCK)
		Where a.[BOMID] ='+convert(nvarchar,@BomID)+' and [ProductUse]=1)'
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
