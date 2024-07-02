USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeleteCostCenter]
	@CostCenterID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON
	 DELETE FROM  dbo.ADM_RibbonView WHERE FeatureID=@CostCenterID
	DELETE FROM ADM_FeatureActionRolemap WHERE FeatureActionID in (select FeatureActionID from ADM_FeatureAction where FeatureID=@CostCenterID)
	DELETE FROM  dbo.ADM_FeatureAction WHERE FeatureID=@CostCenterID	
	DELETE FROM  dbo.COM_Status WHERE FeatureID=@CostCenterID
	DELETE FROM ADM_CostCenterDef WHERE CostCenterID=@CostCenterID
	DELETE FROM ADM_GridViewColumns WHERE GridViewID in (select GridViewID from ADM_GridView where FeatureID=@CostCenterID)
	DELETE FROM ADM_GridView WHERE FeatureID=@CostCenterID
	DELETE FROM ADM_ListViewColumns WHERE ListViewID in (select ListViewID from ADM_ListView where FeatureID=@CostCenterID)
	DELETE FROM ADM_ListView WHERE FeatureID=@CostCenterID
	DELETE FROM ADM_FEATURES WHERE FeatureID=@CostCenterID
COMMIT TRANSACTION
SET NOCOUNT OFF;
END TRY
BEGIN CATCH  
	 SELECT 'ERROR IN Deletion',ERROR_MESSAGE()
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  

 
GO
