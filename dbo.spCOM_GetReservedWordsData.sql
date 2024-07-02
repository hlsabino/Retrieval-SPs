USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetReservedWordsData]
	@CCID [int],
	@CCNODEID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON;    
    --Declaration Section    
DECLARE @Sql nvarchar(max),@EmailDisplayCol nvarchar(400)
declare @AssignEmail nvarchar(300),@AssignPhone nvarchar(300),@OwnerEmail nvarchar(300)
 set @AssignEmail=''
 set @AssignPhone=''
 set @OwnerEmail=''
 
 --Get AssignUser Email Address
	select @AssignEmail= @AssignEmail + Email1 + ','   from ADM_Users with(nolock) where 
	Email1 is not null and Email1<>'' and  UserID in (
	select userid from CRM_Assignment with(nolock) WHERE CCID=@CCID and CCNODEID=@CCNODEID and IsFromActivity=0 and
	ISTEAM=0 AND ISROLE=0 AND ISGROUP=0
	union
	select userid from dbo.adm_users with(nolock) where userid in 
	(select nodeid from dbo.COM_CostCenterCostCenterMap with(nolock) where 
	Parentcostcenterid=7 and costcenterid=7 and ParentNodeid in (
	select userid from CRM_Assignment with(nolock) WHERE CCID=@CCID and CCNODEID=@CCNODEID
	and IsFromActivity=0 and
	ISGROUP=1)) --group
	union
	select  UserID from ADM_UserRoleMap with(nolock) where ROLEID IN    
	(select teamnodeid from CRM_Assignment with(nolock) where CCID=@CCID and CCNODEID=@CCNODEID and ISROLE=1 and IsFromActivity=0 and
	IsRole=1) --role
	union
	select userid from crm_teams with(nolock) where isowner=0 and  teamid in              
	( select teamnodeid from CRM_Assignment with(nolock) where CCID=@CCID and CCNODEID=@CCNODEID and IsTeam=1) --team
	) 
	
	--Get AssignUser Phone 
	select @AssignPhone= @AssignPhone + Phone1 + ','   from ADM_Users with(nolock) where 
	Phone1 is not null and Phone1<>'' and  UserID in (
	select userid from CRM_Assignment with(nolock) WHERE CCID=@CCID and CCNODEID=@CCNODEID and IsFromActivity=0 and
	ISTEAM=0 AND ISROLE=0 AND ISGROUP=0
	union
	select userid from dbo.adm_users with(nolock) where userid in 
	(select nodeid from dbo.COM_CostCenterCostCenterMap with(nolock) where 
	Parentcostcenterid=7 and costcenterid=7 and ParentNodeid in (
	select userid from CRM_Assignment with(nolock) WHERE CCID=@CCID and CCNODEID=@CCNODEID
	and IsFromActivity=0 and
	ISGROUP=1)) --group
	union
	select  UserID from ADM_UserRoleMap with(nolock) where ROLEID IN    
	(select teamnodeid from CRM_Assignment with(nolock) where CCID=@CCID and CCNODEID=@CCNODEID and ISROLE=1 and IsFromActivity=0 and
	IsRole=1) --role
	union
	select userid from crm_teams with(nolock) where isowner=0 and  teamid in              
	( select teamnodeid from CRM_Assignment with(nolock) where CCID=@CCID and CCNODEID=@CCNODEID and IsTeam=1) --team
	)
   
		IF(LEN(@AssignEmail)>0)
		BEGIN
			 SET @AssignEmail=SUBSTRING(@AssignEmail,1,LEN(@AssignEmail)-1)	 
		END 
		IF(LEN(@AssignPhone)>0)
		BEGIN
			 SET @AssignPhone=SUBSTRING(@AssignPhone,1,LEN(@AssignPhone)-1)	 
		END 
	
	--Get Owner Email
	IF(@CCID=86)
	BEGIN
		SELECT @OwnerEmail=Email1 FROM ADM_Users WITH(NOLOCK) WHERE UserName IN( SELECT CreatedBy FROM CRM_Leads WITH(NOLOCK) WHERE LeadID=@CCNODEID)
	END			 
IF(@CCID=73)
BEGIN
	 SELECT top 1 contactid, CASE WHEN Email1<>'' AND Email1 IS not NULL THEN Email1 ELSE Email2 END AS '_Customer_Email',
	 CASE WHEN Phone1<>'' AND Phone1 IS not NULL THEN Phone1 ELSE Phone2 END AS '_Customer_Phone',@AssignPhone '_Assign_Phone',@AssignEmail '_Assign_Email'  FROM COM_Contacts with(nolock) WHERE FeatureID=@CCID AND FeaturePK=@CCNODEID
END
ELSE IF(@CCID=86 or @CCID=89)
BEGIN
	 SET @SQL='
	 SELECT top 1 contactid, CASE WHEN Email1<>'''' AND Email1 IS not NULL THEN Email1 ELSE Email2 END AS _Customer_Email,
	 CASE WHEN Phone1<>'''' AND Phone1 IS not NULL THEN Phone1 ELSE Phone2 END AS _Customer_Phone,'''+ @AssignPhone +''' _Assign_Phone,'''+ @AssignEmail +''' _Assign_Email,'''+@OwnerEmail+''' _Owner_Email  
	 FROM CRM_Contacts WITH(NOLOCK) WHERE FeatureID='+CONVERT(NVARCHAR,@CCID)+' AND FeaturePK='+CONVERT(NVARCHAR,@CCNODEID)
	 --print @SQL
	EXEC (@SQL)
	 
END
  
exec(@Sql)

--[spCOM_GetReservedWordsData] 86,109,1,1
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
