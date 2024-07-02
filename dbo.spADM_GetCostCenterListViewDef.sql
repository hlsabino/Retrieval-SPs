USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterListViewDef]
	@CostCenterID [int] = 0,
	@ListViewTypeID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON  
 
   --Declaration Section  
   DECLARE @ListViewID INT  
   --Check for manadatory paramters  
   if(@UserID=0 or @CostCenterID=0)  
    RAISERROR('-100',16,1)  
  
   IF(@ListViewTypeID = 0)  
   BEGIN   
    SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK)   
    where CostCenterID=@CostCenterID and UserID=@UserID and IsUserDefined=1 and ListViewTypeID is null  
        
  
    IF(@ListViewID IS NULL)  
     SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK)   
     where CostCenterID=@CostCenterID and IsUserDefined=0 and ListViewTypeID is null  
   END  
   ELSE  
   BEGIN   
     
    SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK)   
    where CostCenterID=@CostCenterID and ListViewTypeID =@ListViewTypeID  
       
     END  
     
--   IF(@ListViewID IS NULL)  
--    RAISERROR('-105',16,1)  
  
  
   --Getting ListView  
   SELECT [ListViewID],LISTVIEWNAME  
      ,[FeatureID]  
      ,[CostCenterID]  
      ,[ListViewTypeID]  
      ,[SearchFilter]  
      ,[RoleID]  
      ,[UserID]  
      ,[IsUserDefined]  ,ListViewPageSize,ListViewDelaytime,IgnoreUserWise,FilterQOH
      ,[GUID],FilterXML,SearchOption,SearchOldValue,[GroupSearchFilter],[GroupFilterXML],IgnoreSpecial 
      from ADM_ListView WITH(NOLOCK)   
   where ListViewID=@ListViewID  
      
   --Getting ListViewColumns  
   SELECT 'OLD' as 'Link/Delink',ResourceData,a.CostCenterColID,UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,a.ListViewID,a.Description,a.DocumentsList,c.ColumnCostCenterID
   ,a.ColumnType,a.IsParent,a.IsCode,SearchColID,SearchColName
   FROM ADM_ListViewColumns a WITH(NOLOCK)   
   LEFT JOIN ADM_ListView b  WITH(NOLOCK) on a.ListViewID=b.ListViewID  
   LEFT JOIN ADM_CostCenterDef c  WITH(NOLOCK) on b.CostCenterID=c.CostCenterID AND c.CostCenterColID=a.CostCenterColID  
   LEFT JOIN COM_LanguageResources D  WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID  
   where b.ListViewID=@ListViewID  
   order by a.ColumnOrder 

    
   --  
   SELECT LISTVIEWNAME            
      ,[ListViewTypeID]        ,[IsUserDefined], [ListViewID]
   from ADM_ListView WITH(NOLOCK)   
   where [CostCenterID]=@CostCenterID  
    
--   SELECT 'NEW' as 'Link/Delink', SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth'  
--   FROM ADM_CostCenterDef WITH(NOLOCK) WHERE  IsColumnInUse=1 and CostCenterID=@CostCenterID AND CostCenterColID NOT IN  
--   (SELECT COSTCENTERCOLID FROM ADM_ListViewColumns a JOIN ADM_ListView b on a.ListViewID=b.ListViewID WHERE b.[ListViewTypeID]=@ListViewTypeID)  
--     
   SELECT 'NEW' as 'Link/Delink', C.SysColumnName,R.RESOURCEDATA [UserColumnName],ColumnCostCenterID,C.CostCenterColID,'200' as 'ColumnWidth'  
   FROM ADM_CostCenterDef C WITH(NOLOCK)   
   LEFT JOIN COM_LANGUAGERESOURCES R  WITH(NOLOCK) ON C.RESOURCEID=R.RESOURCEID  AND R.LanguageID=@LangID 
   WHERE  C.IsColumnInUse=1 and C.CostCenterID=@CostCenterID AND C.CostCenterColID NOT IN  
   (SELECT COSTCENTERCOLID FROM ADM_ListViewColumns a  WITH(NOLOCK)  
   JOIN ADM_ListView b  WITH(NOLOCK)  on a.ListViewID=b.ListViewID   
   WHERE b.[ListViewTypeID]=@ListViewTypeID)  
  ORDER BY C.UserColumnName
--   SELECT 'NEW' as 'Link/Delink', SysColumnName,UserColumnName,CostCenterColID,ColumnDataType,'200' as 'ColumnWidth'  
--   FROM ADM_CostCenterDef WITH(NOLOCK) WHERE  IsColumnInUse=1 and CostCenterID=@CostCenterID    
  
   SELECT 'NEW' as 'Link/Delink', C.SysColumnName,R.RESOURCEDATA [UserColumnName],C.CostCenterColID,C.ColumnDataType,'200' as 'ColumnWidth'  
   FROM ADM_CostCenterDef C WITH(NOLOCK)  
   LEFT JOIN COM_LANGUAGERESOURCES R  WITH(NOLOCK)  ON C.RESOURCEID=R.RESOURCEID  
   WHERE  C.IsColumnInUse=1 and C.CostCenterID=@CostCenterID   AND R.LanguageID=@LangID   
  ORDER BY C.UserColumnName   
   
  declare @CCColID INT
  select @CCColID=CostCenterColID from ADM_CostCenterDef  WITH(NOLOCK) where SysColumnName like 'Status%' and costcenterid=@CostCenterID
  select StatusID,Status,@CCColID as CostCenterColID from com_Status  WITH(NOLOCK)  where costcenterid=@CostCenterID
  
  
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
