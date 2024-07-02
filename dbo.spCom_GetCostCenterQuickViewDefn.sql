USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_GetCostCenterQuickViewDefn]
	@CostCenterID [int],
	@NodeID [nvarchar](max),
	@ShowInCCID [bigint],
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;    
	declare @QID int
	set @QID=0
	SELECT @QID=QM.QID FROM ADM_QuickViewDefn Q with(nolock), ADM_QuickViewDefnUserMap QM with(nolock)
			WHERE Q.CostCenterID=@CostCenterID AND Q.QID=QM.QID AND QM.ShowCCID=@ShowInCCID
			AND (QM.RoleID=@RoleID OR QM.UserID=@UserID OR QM.GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE RoleID=@RoleID OR UserID=@UserID))
	select @QID QuickViewID
	select C.CostCenterColID,C.SysColumnName,C.ColumnCostCenterID
	from ADM_QuickViewDefn Q WITH(NOLOCK)
	join ADM_CostCenterDef C WITH(NOLOCK) on C.CostCenterColID=Q.CostCenterColID
	where QID=@QID
	order by Q.ColumnOrder

SET NOCOUNT OFF;     
RETURN 1
END TRY
BEGIN CATCH    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT 'ERROR' 
		END  
		ELSE
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=1 
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH
GO
