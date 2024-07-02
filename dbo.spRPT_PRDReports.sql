USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_PRDReports]
	@ReportType [int],
	@SELECT [nvarchar](max),
	@JOIN [nvarchar](max),
	@WHERE [nvarchar](max),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
	declare @StageTbl nvarchar(50),@SQL nvarchar(max),@DbName nvarchar(50),@MachineTbl nvarchar(50)
	select @StageTbl=TableName from adm_Features with(nolock) where FeatureID=(select convert(int,VALUE) from COM_CostCenterPreferences with(nolock) where [Name]='StageDimension' and CostCenterID=76)
	select @MachineTbl=TableName from adm_Features with(nolock) where FeatureID=(select convert(int,VALUE) from COM_CostCenterPreferences with(nolock) where [Name]='MachineDimension' and CostCenterID=76)
	--select @JobVal=VALUE,@JobDim=convert(int,VALUE) from COM_CostCenterPreferences with(nolock) where [Name]='JobDimension' and CostCenterID=76

	set @SQL=''
	
	if @ReportType=294
	begin
		set @DbName=DB_NAME()+'_ARCHIVE.dbo.'
		set @SQL='
SELECT BOMName+''   (Modified On: ''+convert(nvarchar,convert(datetime,DateModified))+''  FP: ''+FP.ProductName+''   Qty: ''+(convert(nvarchar,FPQty))+''   Units: ''+FU.BaseName+'')'' BOMName
,Stage,Section,T.ProductName,T.ProductCode,Unit  ,IPQty,IPRate,IPValue  ,OPQty,OPRate,OPValue  ,Hrs,CostPerHr,Expenses
,(SELECT ISNULL(SUM(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails WHERE ProductID=T.ProductID AND IsQtyIgnored=0 AND StatusID=369) BalQty
FROM  (  
SELECT isnull(B.ModifiedDate,B.CreatedDate) DateModified,P.ProductID,B.ProductID FPID,B.UOMID FPUOMID,B.FPQty,B.BOMName,BS.lft,BS.Depth,S.Name Stage,1 SecID,''INPUT'' Section,P.ProductName,P.ProductCode,U.BaseName Unit  ,BP.Quantity IPQty,BP.UnitPrice IPRate,BP.Value IPValue  ,null OPQty,null OPRate,null OPValue  ,null Hrs,null CostPerHr,null Expenses 
FROM '+@DbName+'PRD_BillOfMaterialHistory B with(nolock)   
inner join '+@DbName+'PRD_BOMProductsHistory BP with(nolock) on BP.BOMID=B.BOMID and BP.CreatedDate=B.ModifiedDate
inner join INV_Product P with(nolock) on BP.ProductID=P.ProductID 
inner join '+@DbName+'PRD_BOMStagesHistory BS with(nolock) on BP.StageID=BS.StageID and BP.CreatedDate=BS.CreatedDate
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 
left join COM_UOM U WITH(NOLOCK) on BP.UOMID=U.UOMID  
WHERE BP.ProductUse=1'+@WHERE+'
 UNION ALL  
SELECT isnull(B.ModifiedDate,B.CreatedDate) DateModified,P.ProductID,B.ProductID FPID,B.UOMID FPUOMID,B.FPQty,B.BOMName,BS.lft,BS.Depth,S.Name Stage,4 SecID,''OUTPUT'' Section,P.ProductName,P.ProductCode,U.BaseName Unit  ,null IPQty,null IPRate,null IPValue  ,BP.Quantity OPQty,BP.UnitPrice OPRate,BP.Value OPValue  ,null Hrs,null CostPerHr,null Expenses  
FROM '+@DbName+'PRD_BillOfMaterialHistory B with(nolock)  
inner join '+@DbName+'PRD_BOMProductsHistory BP with(nolock) on BP.BOMID=B.BOMID and BP.CreatedDate=B.ModifiedDate
inner join INV_Product P with(nolock) on BP.ProductID=P.ProductID  
inner join '+@DbName+'PRD_BOMStagesHistory BS with(nolock) on BP.StageID=BS.StageID and BP.CreatedDate=BS.CreatedDate
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 
 left join COM_UOM U WITH(NOLOCK) on BP.UOMID=U.UOMID  
WHERE BP.ProductUse=2'+@WHERE+'
  UNION ALL  
SELECT isnull(B.ModifiedDate,B.CreatedDate) DateModified,NULL,B.ProductID FPID,B.UOMID FPUOMID,B.FPQty,B.BOMName,BS.lft,BS.Depth,S.Name Stage,3 SecID,''EXPENSES'' Section,null ProductName,null ProductCode,null Unit  ,null IPQty,null IPRate,null IPValue  ,null OPQty,null OPRate,null OPValue  ,null Hrs,null CostPerHr,BE.Value Expenses  
FROM  '+@DbName+'PRD_BillOfMaterialHistory B with(nolock)  
inner join '+@DbName+'PRD_ExpensesHistory BE with(nolock) on BE.BOMID=B.BOMID and BE.CreatedDate=B.ModifiedDate
inner join '+@DbName+'PRD_BOMStagesHistory BS with(nolock) on BE.StageID=BS.StageID and BE.CreatedDate=BS.CreatedDate
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID  
WHERE 1=1'+@WHERE+'
 UNION ALL  
SELECT isnull(B.ModifiedDate,B.CreatedDate) DateModified,NULL,B.ProductID FPID,B.UOMID FPUOMID,B.FPQty,B.BOMName,BS.lft,BS.Depth,S.Name Stage,2 SecID,''MACHINES'' Section,M.Name ProductName,null ProductCode,null Unit  ,null IPQty,null IPRate,null IPValue  ,null OPQty,null OPRate,null OPValue  ,BM.Hours Hrs,BM.Value CostPerHr,null Expenses  
FROM '+@DbName+'PRD_BillOfMaterialHistory B with(nolock)  
inner join '+@DbName+'PRD_BOMResourcesHistory BM with(nolock) on BM.BOMID=B.BOMID and BM.CreatedDate=B.ModifiedDate
inner join '+@DbName+'PRD_BOMStagesHistory BS with(nolock) on BM.StageID=BS.StageID and BM.CreatedDate=BS.CreatedDate
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 
inner join '+@MachineTbl+' M with(nolock) on BM.ResourceID=M.NodeID  
WHERE 1=1'+@WHERE+'
) AS T 
 inner join INV_Product FP with(nolock) on T.FPID=FP.ProductID  
inner join COM_UOM FU with(nolock) on T.FPUOMID=FU.UOMID  
ORDER BY BomName,DateModified,T.lft,SecID      
'
--  AND B.BOMID IN (184) 
	end
print(@SQL)
exec(@SQL)

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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
