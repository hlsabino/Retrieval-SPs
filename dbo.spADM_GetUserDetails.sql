USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetUserDetails]
	@UserName [nvarchar](500),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY     
SET NOCOUNT ON    
    
  --Declaration Section    
  DECLARE @HasAccess bit,@Ret int,@UserID BIGINT
    
  --SP Required Parameters Check    
  if(@UserName='')    
  BEGIN    
   RAISERROR('-100',16,1)    
  END    

	select @UserID=UserID from ADM_Users where UserName COLLATE DATABASE_DEFAULT=@UserName COLLATE DATABASE_DEFAULT and IsUserDeleted = 0

      SELECT a.UserID,a.UserName  COLLATE DATABASE_DEFAULT,a.Password,a.StatusID,s.Status,a.DefaultLanguage,r.RoleID,r.Name FROM dbo.ADM_Users a  
	  JOIN [PACT2C].dbo.ADM_Users ADMUSR ON ADMUSR.USERNAME  COLLATE DATABASE_DEFAULT = a.USERNAME    COLLATE DATABASE_DEFAULT
	  join dbo.COM_Status s on a.StatusID=s.StatusID  
	  join dbo.ADM_UserRoleMap u on a.UserID=u.UserID  
	  join  dbo.ADM_PRoles r on u.RoleID=r.RoleID  
	  WHERE    a.IsUserDeleted = 0 and a.UserName=@UserName
	
	  SELECT Name,Value FROM ADM_GlobalPreferences WHERE Name='LW  Login' or Name='Login'

 	 IF EXISTS(SELECT Value FROM ADM_GlobalPreferences WHERE Name='EnableLocationWise' AND Value='True')  
	 BEGIN  
	  	select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup from COM_Location l
		join COM_Location g on l.lft between g.lft and g.rgt 
		where   g.NodeID in (select NodeID from COM_CostCenterCostCenterMap
		where CostCenterID=50002 and (
			(ParentCostCenterID=6 and ParentNodeID=(select RoleID from ADM_UserRoleMap where UserID =@UserID)))
		 OR (ParentCostCenterID=7 and ParentNodeID=@UserID)
		)  
	 END 
	    
	 IF EXISTS(SELECT Value FROM ADM_GlobalPreferences WHERE Name='EnableDivisionWise' AND Value='True') 
	 BEGIN  
 		select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup from COM_Division l
		join COM_Division g on l.lft between g.lft and g.rgt 
		where   g.NodeID in (select NodeID from COM_CostCenterCostCenterMap
		where CostCenterID=50001 and ParentCostCenterID=6 and ParentNodeID=(
		select RoleID from ADM_UserRoleMap
		where UserID=(select UserID from ADM_Users where UserName=@UserName and IsUserDeleted = 0 )))
	
	 END  
   
SET NOCOUNT OFF;    
return @Ret
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
