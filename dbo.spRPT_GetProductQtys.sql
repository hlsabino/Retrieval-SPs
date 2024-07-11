USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetProductQtys]
	@mode [int],
	@ProductIDs [nvarchar](max),
	@ExpQts [nvarchar](max),
	@ComQts [nvarchar](max),
	@DocDate [datetime],
	@QtyWhere [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
        
BEGIN TRY        
SET NOCOUNT ON;      
	
	declare @sql nvarchar(max),@StageCCID int	,@tableName nvarchar(200),@MachineDim int,@Mactab  nvarchar(200),@MacDim1 int,@Mactab1  nvarchar(200)
	CREATE TABLE #TblProducts(ID INT IDENTITY(1,1) NOT NULL,ProductID INT)
	INSERT INTO #TblProducts(ProductID)
	EXEC SPSplitString @ProductIDs,','
	create TABLE #TblPendingOrders(ProductID INT,ExpQty FLOAT,ComQty FLOAT,QOH FLOAT,RMQty float)

	if(@mode=1)
	BEGIN
		if(@ExpQts<>'' or @ComQts<>'')
		BEGIN
			if(@ExpQts<>'')
			BEGIN
				SET @sql=dbo.fnGetPendingQtyQueryForReorder(@ExpQts,@QtyWhere,'',1)		 
				INSERT INTO #TblPendingOrders(ProductID,ExpQty)
				EXEC(@sql)
				 
			END	
			if(@ComQts<>'')
			BEGIN
				SET @sql=dbo.fnGetPendingQtyQueryForReorder(@ComQts,@QtyWhere,'',1)
				INSERT INTO #TblPendingOrders(ProductID,ComQty)
				EXEC(@sql)			 
			END
		END
		
		set @sql='SELECT isnull(sum(UOMConvertedQty*VoucherType),0) QOH,D.ProductID FROM INV_DocDetails D WITH(NOLOCK)      
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+
		' WHERE D.ProductID in('+convert(nvarchar(max),@ProductIDs)+') '+isnull(@QtyWhere,'')+' and statusid=369 AND IsQtyIgnored=0 AND D.DocDate<='+convert(nvarchar,convert(float,@DocDate))+' and (VoucherType=-1 or VoucherType=1)
		 group by D.ProductID'
		
		INSERT INTO #TblPendingOrders(QOH,ProductID)
		exec(@sql)
	    
		set @sql='select ProductCode,ProductName,pr.ProductID,isnull(sum(QOH),0) QOH,isnull(sum(ComQty),0) ComQty,isnull(sum(ExpQty),0) ExpQty
		,(select max(Options) from PRD_BOMResources BP with(nolock) where BP.BOMID=TP.BOM) Options
		from #TblProducts pr
		left join #TblPendingOrders p on pr.ProductID=p.ProductID
		join inv_product TP ON TP.productid=pr.ProductID				
		group by pr.ProductID,ProductCode,ProductName,TP.BOM'
		exec(@sql)
    END
    ELSE if(@mode=2)
    BEGIN
		select @StageCCID=Value from COM_CostCenterPreferences WITH(NOLOCK)
		where CostCenterID=76 and Name='StageDimension' and ISNUMERIC(Value)=1
		
		select @tableName=TableName from ADM_Features WITH(NOLOCK)   WHere FeatureID=@StageCCID
		
		select @MachineDim=Value from COM_CostCenterPreferences WITH(NOLOCK) 
		where CostCenterID=76 and Name='MachineDimension' and ISNUMERIC(Value)=1
		
		select @Mactab=TableName from ADM_Features WITH(NOLOCK)   WHere FeatureID=@MachineDim
		set @Mactab1=''
		select @MacDim1=Value from COM_CostCenterPreferences WITH(NOLOCK) 
		where CostCenterID=76 and Name='MachineDim1' and ISNUMERIC(Value)=1
		
		select  @Mactab1=TableName from ADM_Features WITH(NOLOCK)   WHere FeatureID=@MacDim1
		
		set @sql='SELECT BOM.BOMID,TP.productid FP,BP.ProductID RM, (BP.Quantity*PU.Conversion)/(BOM.FPQty*isnull(U.Conversion,1)) RMQty	
		,TP.ProductCode FPCode,TP.ProductName FPName,RM.ProductCode,RM.ProductName,0 ComQty,0 ExpQty,0 QOH
		,s.[StageID],s.StageNodeID,s.lft,BOM.CCNodeID BOMNodeID'
		
		if(@StageCCID>50000)		
			set @sql=@sql+',sd.Code stageCode,sd.Name stageName'
		
		set @sql=@sql+' into #TblRM FROM #TblProducts P
		join inv_product TP with(nolock)  ON TP.productid=p.ProductID
		join PRD_BillOfMaterial BOM with(nolock) on BOM.BOMID=TP.BOM
		join PRD_BOMProducts BP with(nolock) on	BP.BOMID=TP.BOM	
		join PRD_BOMStages s WITH(NOLOCK) on BP.[StageID]=s.[StageID]'
		if(@StageCCID>50000)		
			set @sql=@sql+' join '+@tableName+' Sd WITH(NOLOCK) on s.StageNodeID=Sd.NodeID '
			
		set @sql=@sql+' join inv_product RM with(nolock)  ON RM.productid=BP.ProductID
		left join COM_UOM PU with(nolock) ON PU.UOMID=BP.UOMID
		LEFT JOIN COM_UOM U with(nolock) ON U.UOMID=BOM.UOMID
		WHERE  BP.ProductUse=1
		select * from #TblRM
		
		SELECT isnull(sum(UOMConvertedQty*VoucherType),0) QOH,D.ProductID FROM INV_DocDetails D WITH(NOLOCK)      
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
		INNER JOIN #TblRM RM WITH(NOLOCK) ON RM.RM=D.ProductID
		WHERE  statusid=369 '+isnull(@QtyWhere,'')+'  AND IsQtyIgnored=0 AND D.DocDate<='+convert(nvarchar,convert(float,@DocDate))+' and (VoucherType=-1 or VoucherType=1)
		 group by D.ProductID 
		 '
		 
		 if(@MachineDim>50000)	
		 BEGIN
			 set @Sql=@Sql +' SELECT BP.BOMID,ResourceID,BOM.FPQty,Hours/(BOM.FPQty*isnull(U.Conversion,1)) Hours,BP.Value,BP.StageID,D.Name ResourceName,Options,BP.Frequency
			 ,Hours as ActHours,BFP.Quantity as ActOPQuantity
			 ,MachineDim1,MachineDim2'
			if(@Mactab1<>'')
			  set @Sql=@Sql +',D1.Name Dim1Name'
			 set @Sql=@Sql +'  into #TblRes
			 FROM #TblProducts P
			join inv_product TP with(nolock) ON TP.productid=p.ProductID
			join PRD_BillOfMaterial BOM with(nolock) on BOM.BOMID=TP.BOM
			join PRD_BOMResources BP with(nolock) on	BP.BOMID=TP.BOM 
			LEFT JOIN COM_UOM U with(nolock) ON U.UOMID=BOM.UOMID
			JOIN PRD_BOMProducts BFP WITH(NOLOCK) ON BFP.ProductUse=2 AND BFP.BOMID=TP.BOM AND BFP.StageID=BP.StageID
			join '+@Mactab+' D WITH(NOLOCK) on BP.ResourceID=D.NodeID'
			if(@Mactab1<>'')
			 set @Sql=@Sql +' left join '+@Mactab1+' D1 WITH(NOLOCK) on BP.MachineDim1=D1.NodeID '
			
			 set @Sql=@Sql +' select * from #TblRes with(nolock)  
			
			select convert(datetime,b.FromDate) FromDate,convert(datetime,b.ToDate) ToDate,a.ResourceID,Day,SAStartTime,SAEndTime,SBStartTime,SBEndTime,SCStartTime,SCEndTime 
			from #TblRes a with(nolock) 
			join PRD_CCCalendarMap b with(nolock)  on b.CCNodeID=a.ResourceID
			join PRD_ProdCalendar c with(nolock) on b.CalendarProfileID=ProfileID
			
			select Dt.dcAlpha201 FromDate,Dt.dcAlpha202 ToDate,a.ResourceID 
			from #TblRes a with(nolock) 
			JOIN INV_DocDetails D WITH(NOLOCK) on D.DocumentType=212
			INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
			INNER JOIN COM_DocTextData Dt WITH(NOLOCK) ON Dt.InvDocDetailsID=D.InvDocDetailsID
			where DCC.dcCCNID'+Convert(nvarchar(max),(@MachineDim-50000))+'=a.ResourceID
			 and (convert(float,Dt.dcAlpha201)>='+convert(nvarchar(max),convert(float,@DocDate))
			 +' or convert(float,Dt.dcAlpha202)>='+convert(nvarchar(max),convert(float,@DocDate))+')
			 

			 select BOMID,ResourceID,MAX(FPQty) FPQty,SUM(Hours) as Hours,SUM(Value) as value,StageID,ResourceName,MAX(Options) as Options,MAX(Frequency)Frequency,SUM(ActHours) as ActHours,
			 MAX(ActOPQuantity) as ActOPQuantity
			 from #TblRes with(nolock)
			 GROUP BY BOMID,ResourceID,StageID,ResourceName
			 ORDER BY BOMID,StageID
			  ' 
		END	  
		ELSE
			set @Sql=@Sql +' select 1 where 1<>1 select 1 where 1<>1 select 1 where 1<>1 select 1 where 1<>1'
		print @sql
		exec(@sql)
		 
		select name,value from com_costcenterpreferences WITH(NOLOCK)
		where costcenterid=76 and name in('MachineDimension','MachineDim1','MachineDim2','BomDimension','StageDimension')
	

	END	 	
    
 
       
SET NOCOUNT OFF;      
RETURN 1      
END TRY      
BEGIN CATCH        
  --Return exception info [Message,Number,ProcedureName,LineNumber]        
  IF ERROR_NUMBER()=50000      
  BEGIN      
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
  END      
  ELSE      
  BEGIN      
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine      
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
  END      
      
SET NOCOUNT OFF        
RETURN -999         
END CATCH


GO
