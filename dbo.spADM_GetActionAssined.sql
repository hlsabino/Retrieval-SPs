USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetActionAssined]
	@FeatureID [int],
	@FeatureName [nvarchar](500),
	@Mode [int] = 1,
	@UserID [bigint] = 1,
	@RoleID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON;    
	
	IF @FeatureName LIKE 'dcNum%' or @FeatureName in ('Quantity','FreeQTY','Rate','Gross')
	BEGIN
		
		--User access check    
		DECLARE @HasAccess BIT
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@FeatureID,2)    

		IF @HasAccess=0    
		BEGIN    
			RAISERROR('-105',16,1)    
		END 
		
		DECLARE @DocViewID bigint

		if exists(select DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@FeatureID and UserID=@UserID)
			 and  exists(select DocumentViewID  FROM [ADM_DocumentViewDef] WITH(NOLOCK) where DocumentViewID in(select DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@FeatureID and UserID=@UserID))
		begin  
			set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@FeatureID and  UserID=@UserID)
		end  
		else if exists(select DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@FeatureID and RoleID=@RoleID)  
		and exists (select DocumentViewID  FROM [ADM_DocumentViewDef] WITH(NOLOCK) where DocumentViewID in(select DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@FeatureID and RoleID=@RoleID)  )
		begin  
			set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@FeatureID and  RoleID=@RoleID)  
		end  
		else if exists(select DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@FeatureID and GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))  
		begin  
			set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@FeatureID and GroupID in (select GroupID from   COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID))  
		end 
		
		SELECT CCD.SysColumnName FeatureName
		,CASE WHEN ISNULL(DVD.IsVisible,1)=1 AND ISNULL(DVD.IsEditable,CCD.IsEditable)=1 THEN 1 ELSE 0 END IsActionAssined
		FROM ADM_CostCenterDef CCD WITH(NOLOCK)
		LEFT JOIN [ADM_DocumentViewDef] DVD WITH(NOLOCK) ON DVD.CostCenterColID=CCD.CostCenterColID AND DVD.DocumentViewID=@DocViewID AND (DVD.Mode=3 OR DVD.Mode=@Mode)
		WHERE CCD.CostCenterID=@FeatureID AND CCD.SysColumnName=@FeatureName
	END
	ELSE 
	BEGIN
		IF EXISTS (SELECT * FROM ADM_FeatureAction FA WITH(NOLOCK)
		JOIN ADM_FeatureActionRoleMap FARM WITH(NOLOCK) ON FARM.FeatureActionID=FA.FeatureActionID
		WHERE FA.FeatureID=@FeatureID AND FA.Name=@FeatureName AND FARM.RoleID=@RoleID)
			SELECT @FeatureName FeatureName,CASE WHEN @FeatureName like '%donot%' or @FeatureName like '%do not%' or @FeatureName like '%dont%' THEN 0 ELSE 1 END IsActionAssined
		ELSE
			SELECT @FeatureName FeatureName,CASE WHEN @FeatureName like '%donot%' or @FeatureName like '%do not%' or @FeatureName like '%dont%' THEN 1 ELSE 0 END IsActionAssined
	END

SET NOCOUNT OFF;    
RETURN 1    
END TRY    
-- TEST   
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
