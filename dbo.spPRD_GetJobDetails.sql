USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetJobDetails]
	@CCID [bigint],
	@NodeID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		 	SELECT * FROM PRD_BillOfMaterial with(nolock) 
		 	where isGroup=0
			ORDER BY lft
		
		declare @StageDim nvarchar(max)
		select @StageDim=Value from COM_CostCenterPreferences with(nolock) where Name='StageDimension' 
		
		if(LEN(@StageDim)>0 and ISNUMERIC(@StageDim)=1 and convert(int,@StageDim)>50000)
		begin
			select @StageDim=TableName from ADM_Features with(nolock) where FeatureID=convert(int,@StageDim)
			set @StageDim='SELECT S.*,D.Code,D.Name FROM PRD_BOMStages S with(nolock)
			INNER JOIN '+@StageDim+' D with(nolock) ON S.StageNodeID=D.NodeID
			 ORDER BY S.lft'
			print(@StageDim)
			exec(@StageDim)
		end
		else
		begin
			SELECT * FROM PRD_BOMStages with(nolock) 
			ORDER BY lft
		end
		
		SELECT BP.*,P.ProductName,P.ProductCOde,U.BaseName 
		FROM  [PRD_BOMProducts] BP with(nolock),INV_Product P with(nolock),
		COM_UOM U WITH(NOLOCK)
		WHERE    BP.ProductUse=2 and  BP.ProductID=P.ProductID and isnull(BP.UOMID,1)=U.UOMID 
		 
		select  j.BomID, bom.BOMName, j.StageID, j.ProductID,j.IsBom,
		j.Qty, isnull(BP.UOMID,1) UOMID, u.UnitName, bp.BOMProductID, p.ProductName, s.StatusID, s.Status, j.CostCenterID, j.NodeID
		from PRD_JobOuputProducts j with(nolock)
		left join PRD_BillOfMaterial bom with(nolock) on j.BomID=bom.BOMID
		join INV_Product p with(nolock) on j.ProductID=p.ProductID
		left join PRD_BOMProducts bp with(nolock) on j.ProductID=bp.ProductID and j.StageID=bp.StageID and j.bomid=bp.bomid and bp.productuse=2
		left join COM_UOM u with(nolock) on isnull(BP.UOMID,1)=u.UOMID
		left join com_status s with(nolock) on j.StatusID=s.StatusID
		where j.CostCenterID=@CCID and j.NodeID=@NodeID
		 
			
		SELECT Status, StatusID FROM COM_Status WHERE CostCenterID=158
		
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
