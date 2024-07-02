USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetUsersDet]
	@UserID [nvarchar](500),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY         
SET NOCOUNT ON        
       
	--SP Required Parameters Check        
	if(@UserID='')        
	BEGIN        
		RAISERROR('-100',16,1)        
	END        
   
	SELECT a.UserID,a.UserName UserName,a.Password Password,a.StatusID,s.Status,a.DefaultLanguage,r.RoleID RoleID,      
	r.Name RoleName,a.FirstName,a.MiddleName,a.LastName,a.Address1,a.Address2,a.Address3,      
	a.City,a.State,a.Zip,a.Country,a.Phone1,a.Phone2,a.Fax,a.Email1,a.Email2,a.Website,a.Description,      
	a.GUID ,a.Email1Password,a.Email2Password,a.DefaultScreenXML,a.IsPassEncr,ADMUSR.InstanceCount,a.LocationID,a.DivisionID,a.IsOffline,TwoStepVerMode
	FROM dbo.ADM_Users a with(nolock)      
	join dbo.COM_Status s with(nolock) on a.StatusID=s.StatusID        
	join dbo.ADM_UserRoleMap u with(nolock) on u.IsDefault=1 and a.UserID=u.UserID        
	join  dbo.ADM_PRoles r with(nolock) on u.RoleID=r.RoleID    
	left JOIN [PACT2C].dbo.ADM_Users ADMUSR with(nolock) ON ADMUSR.USERNAME COLLATE DATABASE_DEFAULT  =  a.USERNAME  COLLATE DATABASE_DEFAULT    
	WHERE   a.IsUserDeleted = 0 and  a.UserID= @UserID       

    --SELECT 'CHARY',@UserID,@LangID 
	EXEC [spCOM_GetCCCCMapDetails] 7, @UserID,@LangID 

	select M.UserRoleMapID,R.RoleID,R.Name RoleName,Status,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate
	from ADM_UserRoleMap M with(nolock)
	inner join ADM_PRoles R with(nolock) on R.RoleID=M.RoleID
	where UserID=@UserID and IsDefault=0
	order by FromDate,ToDate

	--Getting Files
	EXEC [spCOM_GetAttachments] 7,@UserID,@UserID
	
	select StatusMapID,CostCenterID,[Status],convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate
	from [COM_CostCenterStatusMap] with(nolock)
	where CostCenterID=7 and NodeID=@UserID
	order by FromDate,ToDate
	
        
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
