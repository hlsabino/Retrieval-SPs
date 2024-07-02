USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetUserRoles]
	@LocationWhere [nvarchar](max) = null,
	@DivisionWhere [nvarchar](max) = null,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
 --Declaration Section    
 DECLARE @HasAccess BIT,@Where nvarchar(max),@SQL nvarchar(max)
 
	set @Where=''
	if @LocationWhere is not null and @LocationWhere!=''
		set @Where=' and R.RoleID!=1 and R.RoleID IN (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=6 and CostCenterID=50002 and NodeID in ('+@LocationWhere+'))'
	if @DivisionWhere is not null and @DivisionWhere!=''
		set @Where=@Where+' and R.RoleID!=1 and R.RoleID IN (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=6 and CostCenterID=50001 and NodeID in ('+@DivisionWhere+'))'

 --Get Role Information.
 if(@UserID=1) 
 BEGIN 
	SET @SQL='SELECT * FROM ADM_PRoles R WITH(NOLOCK) WHERE StatusID=434 AND IsRoleDeleted<>1'
	if @Where!=''
		SET @SQL=@SQL+@Where
	SET @SQL=@SQL+' ORDER BY Name'
	EXEC(@SQL)
END
ELSE
BEGIN
	SET @SQL='SELECT * FROM ADM_PRoles R WITH(NOLOCK) WHERE StatusID=434 AND Name<>''ADMIN'''
	if @Where!=''
		SET @SQL=@SQL+@Where
	SET @SQL=@SQL+' ORDER BY Name'
	EXEC(@SQL)
	PRINT(@SQL)
END

--Get List of Companies  
   select COMPANYID,  
    CODE,   
    NAME,  
    DBNAME    
  from PACT2C.dbo.ADM_Company WITH(NOLOCK)
  WHERE StatusID = 1    
    
     
 --GET FEATURE ACTION.. MODIFIED ON JULY 08 BY HAFEEZ    
 SELECT A.FeatureActionID,A.Name FeatureName,A.Description,ADM_Features.NAME,A.FEATUREID ,ADM_Features.FEATURETYPEID,FeatureActionTypeID    
 FROM ADM_FeatureAction A WITH(NOLOCK)       
 LEFT JOIN ADM_FeatureActionRoleMap AR WITH(NOLOCK) ON AR.FeatureActionRoleMapID=A.FeatureActionID      
 LEFT JOIN ADM_PRoles R WITH(NOLOCK) ON R.RoleID=AR.RoleID      
 LEFT JOIN ADM_Features WITH(NOLOCK) ON ADM_Features.FEATUREID=A.FEATUREID     
    ORDER BY FeatureID,FeatureActionTypeId    
     
  SELECT [Name],[Value]      
  FROM ADM_GlobalPreferences WITH(NOLOCK)    
    
     
    
COMMIT TRANSACTION     
SET NOCOUNT OFF;       
RETURN 1    
END TRY    
BEGIN CATCH      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH 


GO
