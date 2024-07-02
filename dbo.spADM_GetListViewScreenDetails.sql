USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetListViewScreenDetails]
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY 
SET NOCOUNT ON;
   
	--Getting Features.  
	SELECT FEATUREID,Name,TableName FROM ADM_FEATURES WITH(NOLOCK) WHERE 
		FEATUREID NOT IN (1) and (isenabled=1 OR FEATUREID BETWEEN 41000 AND 49999)  
		ORDER BY NAME
		
	SELECT ROLEID,NAME, IsRoleDeleted FROM ADM_PRoles WITH(NOLOCK) where RoleID=@UserID or RoleID!=1
	
	SELECT * FROM ADM_Users WITH(NOLOCK) where UserID=@UserID or UserID!=1
	
	select C.CostCenterColID as Value,F.Name as Name from adm_costcenterdef C WITH(NOLOCK)
	left join adm_Features F with(nolock) on C.ParentCostCenterID=F.FeatureID 
	where  F.IsEnabled=1 and F.FeatureID>50000  --and C.ISCOLUMNINUSE=0

	SELECT * FROM ADM_Users WITH(NOLOCK) 
	where userid in (select distinct userid from ADM_Assign with(nolock) where CostCenterID=69) and (UserID=@UserID or UserID!=1)
	
	select c.CostCenterID,C.CostCenterColID,C.SysColumnName,R.ResourceData from adm_costcenterdef C WITH(NOLOCK)
	join COM_LanguageResources R with(nolock) on R.ResourceID=c.ResourceID
	left join adm_Features F with(nolock) on C.CostCenterID=F.FeatureID 
	where R.LanguageID=@LangID and  F.IsEnabled=1 and c.CostCenterID> 50000 
	and (C.ISCOLUMNINUSE=1 or C.IsColumnUserDefined=0) and C.SysColumnName not like 'CCNID%'
	UNION ALL
	select -1,0,'',''
	order by CostCenterID

COMMIT TRANSACTION 
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
