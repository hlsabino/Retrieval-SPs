USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetListViewsDefByTypeID]
	@CostCenterID [int],
	@typeID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON  

  
	--Getting ListView  
	SELECT a.[ListViewID],a.LISTVIEWNAME,a.[CostCenterID],a.[ListViewTypeID],a.[SearchFilter]
	,a.[RoleID],a.[UserID],a.[IsUserDefined],b.ColumnType,b.IsParent  
	,D.ResourceData  as ResourceData,
	b.CostCenterColID,SysColumnName,b.ColumnOrder,b.ColumnWidth,b.Description,b.DocumentsList,c.ColumnCostCenterID
	,SearchOption,SearchOldValue from ADM_ListView a WITH(NOLOCK)   
	LEFT JOIN ADM_ListViewColumns b WITH(NOLOCK) on a.ListViewID=b.ListViewID
	LEFT JOIN ADM_CostCenterDef c  WITH(NOLOCK) on c.CostCenterColID=b.CostCenterColID  
	LEFT JOIN COM_LanguageResources D  WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
	--LEFT JOIN ADM_Features F  WITH(NOLOCK) ON b.CostCenterColID <-50000 and F.FeatureID=(b.CostCenterColID*-1)
	where a.CostCenterID=@CostCenterID and a.ListViewTypeID=@typeID
	order by b.ColumnOrder
     
 
  
COMMIT TRANSACTION  
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
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH    
  
GO
