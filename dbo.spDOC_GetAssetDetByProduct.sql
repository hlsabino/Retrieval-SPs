USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetAssetDetByProduct]
	@ProductID [int],
	@CostCenterID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON
		
		--SP Required Parameters Check
		IF @ProductID<=0 
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		 select DepreciationMethod,AveragingMethod,Period,PurchaseValue,SalvageValue,convert(datetime,DeprStartDate) DeprStartDate
		 ,EstimateLife,includeSalvageindepr,IsDeprSchedule,SalvageValueType,DeprBookID
		  from ACC_Assets a WITH(NOLOCK)
		 join INV_Product b WITH(NOLOCK)  on a.AssetID=b.AssetGroupID 
		 where ProductID=@ProductID 
		 
		SELECT L.SysColumnName,A.BatchColID
		FROM COM_DocumentBatchLinkDetails A  with(nolock)
		left JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.BatchColID    
		left JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDBase    
		WHERE A.CostCenterID=@Costcenterid and LinkDimCCID=72
		and  L.SysColumnName in('DepreciationMethod',
		'AveragingMethod','Period','PurchaseValue','SalvageValue','DeprStartDate'
		,'EstimateLife','includeSalvageindepr')
			
	
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
