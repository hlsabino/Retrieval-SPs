USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_PRDJobWiseVariance]
	@IssueType [int],
	@VarianceType [int],
	@IsProductWise [bit],
	@DocWHERE [nvarchar](max),
	@WHERE [nvarchar](max),
	@ProductsNotInBOM [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
	declare @StagVal nvarchar(50),@JobVal nvarchar(50),@StageTbl nvarchar(50),@JobTbl nvarchar(50),@SQL nvarchar(max)
	declare @JobDim int,@StageDim int
	select @StagVal=VALUE,@StageDim=convert(int,VALUE) from COM_CostCenterPreferences with(nolock) where [Name]='StageDimension' and CostCenterID=76
	select @StageTbl=TableName from adm_Features with(nolock) where FeatureID=@StagVal
			
	select @JobVal=VALUE,@JobDim=convert(int,VALUE) from COM_CostCenterPreferences with(nolock) where [Name]='JobDimension' and CostCenterID=76
	select @JobTbl=TableName from adm_Features with(nolock) where FeatureID=@JobVal
	
	declare @Required1 nvarchar(max),@Actual1 nvarchar(max),@Required2 nvarchar(max),@Actual2 nvarchar(max)
	
	if @IssueType=33
		set @WHERE=' and BP.ProductUse=1'+@WHERE
	else
		set @WHERE=' and BP.ProductUse=2'+@WHERE

	if @VarianceType=1
	begin
		set @Required1=',(JO.Qty*JOU.Conversion)/(BPO.Quantity*BPOU.Conversion)*BP.Quantity*BPU.Conversion RequiredQty'
		set @Actual1=',(SELECT sum(INV.UOMConvertedQty) FROM INV_DocDetails INV with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON INV.InvDocDetailsID=DCC.InvDocDetailsID
		WHERE INV.DocumentType='+convert(nvarchar,@IssueType)+' AND INV.ProductID=P.ProductID
		AND DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID AND DCC.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID'+@DocWHERE+'
	 ) ActualQty'
		set @Required2=',BP.Quantity*BPU.Conversion*JO.Qty RequiredQty'
		set @Actual2=',(SELECT sum(INV.UOMConvertedQty) FROM INV_DocDetails INV with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON INV.InvDocDetailsID=DCC.InvDocDetailsID
		WHERE INV.DocumentType='+convert(nvarchar,@IssueType)+' AND INV.ProductID=P.ProductID
		AND DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID AND DCC.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID'+@DocWHERE+'
	 ) ActualQty'
	end
	else if @VarianceType=2
	begin
		set @Required1=',(BP.UnitPrice/BPU.Conversion)*((JO.Qty*JOU.Conversion)/(BPO.Quantity*BPOU.Conversion)*BP.Quantity*BPU.Conversion) RequiredValue'
		set @Actual1=',(SELECT sum(INV.UOMConvertedQty) FROM INV_DocDetails INV with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON INV.InvDocDetailsID=DCC.InvDocDetailsID
		WHERE INV.DocumentType='+convert(nvarchar,@IssueType)+' AND INV.ProductID=P.ProductID
		AND DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID AND DCC.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID'+@DocWHERE+'
	 ) *(BP.UnitPrice/BPU.Conversion) ActualValue'
		set @Required2=',BP.Value*JO.Qty RequiredValue'
		set @Actual2=',(SELECT sum(INV.UOMConvertedQty) FROM INV_DocDetails INV with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON INV.InvDocDetailsID=DCC.InvDocDetailsID
		WHERE INV.DocumentType='+convert(nvarchar,@IssueType)+' AND INV.ProductID=P.ProductID
		AND DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID AND DCC.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID'+@DocWHERE+'
	 )*(BP.UnitPrice/BPU.Conversion) ActualValue
	'
	end

	SET @SQL='
SELECT J.Name JobName, BOMName,S.Name StageName,BS.lft,P.ProductName,P.ProductCode
--, BPO.Quantity*BPOU.Conversion FPConvertedQty, JO.Qty*JOU.Conversion JOConvertedQty,(JO.Qty*JOU.Conversion)/(BPO.Quantity*BPOU.Conversion) Ratio
'+@Required1+@Actual1+' 
FROM PRD_JobOuputProducts JO with(nolock)
inner join '+@JobTbl+' J with(nolock) on JO.NodeID=J.NodeID
inner join PRD_BOMProducts BPO with(nolock) on BPO.BOMID=JO.BOMID and BPO.StageID=JO.StageID and BPO.ProductID=JO.ProductID
inner join COM_UOM BPOU with(nolock) on BPO.UOMID=BPOU.UOMID
inner join COM_UOM JOU with(nolock) on JO.UOMID=JOU.UOMID

inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
inner join PRD_BOMProducts BP with(nolock) on BP.BOMID=B.BOMID and BP.StageID=JO.StageID
inner join INV_Product P with(nolock) on BP.ProductID=P.ProductID 
inner join PRD_BOMStages BS with(nolock) on JO.StageID=BS.StageID 
inner join COM_UOM BPU with(nolock) on BP.UOMID=BPU.UOMID
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 
WHERE JO.IsBOM=0'+@WHERE

	SET @SQL=@SQL+'

UNION ALL

SELECT J.Name, BOMName,S.Name Stage,BS.lft,P.ProductName,P.ProductCode'+@Required2+'
'+@Actual2+'
FROM PRD_JobOuputProducts JO with(nolock)
inner join '+@JobTbl+' J with(nolock) on JO.NodeID=J.NodeID
inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
inner join PRD_BOMProducts BP with(nolock) on BP.BOMID=B.BOMID and BP.StageID=JO.StageID
inner join INV_Product P with(nolock) on BP.ProductID=P.ProductID 
inner join PRD_BOMStages BS with(nolock) on JO.StageID=BS.StageID 
inner join COM_UOM BPU with(nolock) on BP.UOMID=BPU.UOMID
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 

WHERE JO.IsBOM=1'+@WHERE


if @ProductsNotInBOM=1
begin
	SET @SQL=@SQL+'

UNION ALL
SELECT J.Name JobName,null BOMName,S.Name StageName,566989855 lft,P.ProductName,P.ProductCode,null,sum(INV.UOMConvertedQty) FROM INV_DocDetails INV with(nolock)
INNER JOIN COM_DocCCData DCC with(nolock) ON INV.InvDocDetailsID=DCC.InvDocDetailsID
inner join INV_Product P with(nolock) on INV.ProductID=P.ProductID 
inner join '+@JobTbl+' J with(nolock) on DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID
inner join '+@StageTbl+' S with(nolock) on DCC.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID 

left join (SELECT J.NodeID JobID,BP.ProductID
FROM PRD_JobOuputProducts JO with(nolock)
inner join '+@JobTbl+' J with(nolock) on JO.NodeID=J.NodeID
inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
inner join PRD_BOMProducts BP with(nolock) on BP.BOMID=B.BOMID and BP.StageID=JO.StageID
WHERE BP.ProductUse=1
group by J.NodeID,BP.ProductID) JP on JP.JobID=DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+' and JP.ProductID=INV.ProductID

WHERE INV.DocumentType=33 and DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'!=1 and JP.ProductID is null
GROUP BY J.Name,S.Name,P.ProductName,P.ProductCode
'
end


if @IsProductWise=1
	SET @SQL=@SQL+'
ORDER BY ProductName,JobName,BomName,lft'
else
SET @SQL=@SQL+'
	ORDER BY JobName,BomName,lft'


/*
	SET @SQL='
SELECT J.Name JobName, BOMName,S.Name StageName,BS.lft,P.ProductName,P.ProductCode
--, BPO.Quantity*BPOU.Conversion FPConvertedQty, JO.Qty*JOU.Conversion JOConvertedQty,(JO.Qty*JOU.Conversion)/(BPO.Quantity*BPOU.Conversion) Ratio
,(JO.Qty*JOU.Conversion)/(BPO.Quantity*BPOU.Conversion)*BP.Quantity*BPU.Conversion RequiredQty
,(SELECT sum(INV.UOMConvertedQty) 
	FROM INV_DocDetails INV with(nolock),COM_DocCCData T1 with(nolock) 
	WHERE INV.InvDocDetailsID=T1.InvDocDetailsID AND T1.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID AND T1.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID
	AND INV.ProductID=P.ProductID AND (INV.CostCenterID=40998) '+@DocWHERE+'
 ) ActualQty
 
FROM PRD_JobOuputProducts JO with(nolock)
inner join '+@JobTbl+' J with(nolock) on JO.NodeID=J.NodeID
inner join PRD_BOMProducts BPO with(nolock) on BPO.BOMID=JO.BOMID and BPO.StageID=JO.StageID and BPO.ProductID=JO.ProductID
inner join COM_UOM BPOU with(nolock) on BPO.UOMID=BPOU.UOMID
inner join COM_UOM JOU with(nolock) on JO.UOMID=JOU.UOMID

inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
inner join PRD_BOMProducts BP with(nolock) on BP.BOMID=B.BOMID and BP.StageID=JO.StageID
inner join INV_Product P with(nolock) on BP.ProductID=P.ProductID 
inner join PRD_BOMStages BS with(nolock) on JO.StageID=BS.StageID 
inner join COM_UOM BPU with(nolock) on BP.UOMID=BPU.UOMID
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 
WHERE JO.IsBOM=0 and BP.ProductUse=1'+@WHERE

	SET @SQL=@SQL+'

UNION ALL

SELECT J.Name, BOMName,S.Name Stage,BS.lft,P.ProductName,P.ProductCode,BP.Quantity*BPU.Conversion*JO.Qty RequiredQty

,(SELECT sum(INV.UOMConvertedQty) FROM INV_DocDetails INV with(nolock)
	INNER JOIN COM_DocCCData DCC with(nolock) ON INV.InvDocDetailsID=DCC.InvDocDetailsID
	WHERE INV.DocumentType=33 AND INV.ProductID=P.ProductID
	AND DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID AND DCC.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID
 ) ActualQty
 
FROM PRD_JobOuputProducts JO with(nolock)
inner join '+@JobTbl+' J with(nolock) on JO.NodeID=J.NodeID
inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
inner join PRD_BOMProducts BP with(nolock) on BP.BOMID=B.BOMID and BP.StageID=JO.StageID
inner join INV_Product P with(nolock) on BP.ProductID=P.ProductID 
inner join PRD_BOMStages BS with(nolock) on JO.StageID=BS.StageID 
inner join COM_UOM BPU with(nolock) on BP.UOMID=BPU.UOMID
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 

WHERE JO.IsBOM=1 and BP.ProductUse=1'+@WHERE+'
ORDER BY JobName,BomName,lft
'
*/



/*

SET @SQL='
SELECT J.Name JobName, BOMName,S.Name StageName,BS.lft,P.ProductName,P.ProductCode
--, BPO.Quantity*BPOU.Conversion FPConvertedQty, JO.Qty*JOU.Conversion JOConvertedQty,(JO.Qty*JOU.Conversion)/(BPO.Quantity*BPOU.Conversion) Ratio
,(BP.UnitPrice/BPU.Conversion)*((JO.Qty*JOU.Conversion)/(BPO.Quantity*BPOU.Conversion)*BP.Quantity*BPU.Conversion) RequiredValue
,(SELECT sum(INV.UOMConvertedQty) 
	FROM INV_DocDetails INV with(nolock),COM_DocCCData T1 with(nolock) 
	WHERE INV.InvDocDetailsID=T1.InvDocDetailsID AND T1.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID AND T1.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID
	AND INV.ProductID=P.ProductID AND (INV.CostCenterID=40998) '+@DocWHERE+'
 ) ActualQty
 
FROM PRD_JobOuputProducts JO with(nolock)
inner join '+@JobTbl+' J with(nolock) on JO.NodeID=J.NodeID
inner join PRD_BOMProducts BPO with(nolock) on BPO.BOMID=JO.BOMID and BPO.StageID=JO.StageID and BPO.ProductID=JO.ProductID
inner join COM_UOM BPOU with(nolock) on BPO.UOMID=BPOU.UOMID
inner join COM_UOM JOU with(nolock) on JO.UOMID=JOU.UOMID

inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
inner join PRD_BOMProducts BP with(nolock) on BP.BOMID=B.BOMID and BP.StageID=JO.StageID
inner join INV_Product P with(nolock) on BP.ProductID=P.ProductID 
inner join PRD_BOMStages BS with(nolock) on JO.StageID=BS.StageID 
inner join COM_UOM BPU with(nolock) on BP.UOMID=BPU.UOMID
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 
WHERE JO.IsBOM=0 and BP.ProductUse=1'+@WHERE

	SET @SQL=@SQL+'

UNION ALL

SELECT J.Name, BOMName,S.Name Stage,BS.lft,P.ProductName,P.ProductCode,BP.Value*JO.Qty RequiredValue

,(SELECT sum(INV.UOMConvertedQty) FROM INV_DocDetails INV with(nolock)
	INNER JOIN COM_DocCCData DCC with(nolock) ON INV.InvDocDetailsID=DCC.InvDocDetailsID
	WHERE INV.DocumentType=33 AND INV.ProductID=P.ProductID
	AND DCC.dcCCNID'+convert(nvarchar,(@JobDim-50000))+'=J.NodeID AND DCC.dcCCNID'+convert(nvarchar,(@StageDim-50000))+'=S.NodeID
 )*(BP.UnitPrice/BPU.Conversion) ActualValue
 
FROM PRD_JobOuputProducts JO with(nolock)
inner join '+@JobTbl+' J with(nolock) on JO.NodeID=J.NodeID
inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
inner join PRD_BOMProducts BP with(nolock) on BP.BOMID=B.BOMID and BP.StageID=JO.StageID
inner join INV_Product P with(nolock) on BP.ProductID=P.ProductID 
inner join PRD_BOMStages BS with(nolock) on JO.StageID=BS.StageID 
inner join COM_UOM BPU with(nolock) on BP.UOMID=BPU.UOMID
inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 

WHERE JO.IsBOM=1 and BP.ProductUse=1'+@WHERE+'
ORDER BY JobName,BomName,lft
'*/

-- select * from PRD_JobOuputProducts J with(nolock)

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
