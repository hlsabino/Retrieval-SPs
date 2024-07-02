USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetFavorites]
	@Call [nvarchar](50) = null,
	@FavID [bigint],
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1,
	@CompanyIndex [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY   
SET NOCOUNT ON  
   
	--Declaration Section  
	DECLARE @HasAccess BIT,@SQL nvarchar(max)

	--SP Required Parameters Check  
	IF @UserID<1  
	BEGIN  
		RAISERROR('-100',16,1)  
	END
	
	DECLARE @TABLE TABLE(ID INT IDENTITY(1,1),FeatureactionID BIGINT,FeatureID BIGINT,  
	FeatureActionName NVARCHAR(300),DisplayName NVARCHAR(300),RowNo INT,ColumnNo INT,ShortCutKey NVARCHAR(300),TabID INT,TabName NVARCHAR(300),  
	GROUPID INT,GroupName NVARCHAR(300),ScreenName NVARCHAR(300),ImagePath NVARCHAR(300),ButtonKeyTip NVARCHAR(300),isReport int,
	FeatureActionTypeID int,FavName NVARCHAR(200),Link nvarchar(max),Category nvarchar(100))

	IF @Call like 'GETLIST%'
	BEGIN
		--select ID,FavName from COM_Favourite F with(nolock) join ADM_Assign M with(nolock) on F.ID=M.NodeID
		--where F.TypeID=1 and M.CostCenterID=69 and (M.UserID=@UserID or M.RoleID=@RoleID) group by ID,FavName order by FavName

		IF(@UserID=1 OR @RoleID=1)
		BEGIN
			select ID,case isnull(s.ResourceData,'') when '' then FavName else s.ResourceData end FavName
			 from COM_Favourite F with(nolock) 
			LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceName=F.FavName AND S.LanguageID=@LangID  
			where F.TypeID=1 
			group by ID,FavName,s.ResourceData order by FavName
		END
		ELSE
		BEGIN
			select ID,case isnull(s.ResourceData,'') when '' then FavName else s.ResourceData end FavName
			 from COM_Favourite F with(nolock) join ADM_Assign M with(nolock) on F.ID=M.NodeID
			LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceName=F.FavName AND S.LanguageID=@LangID  
			where F.TypeID=1 and M.CostCenterID=69 and (M.UserID=@UserID or M.RoleID=@RoleID)
			group by ID,FavName,s.ResourceData order by FavName
		END

		select FavID from COM_Favourite F with(nolock) where TypeID=3 and FeatureActionID=@UserID
		declare @LocID int
		set @Call=replace(@Call,'GETLIST','')
		if isnumeric(@Call)=1
			set @LocID=convert(int,@Call)
		else
			set @LocID=0
		set @Call=''
		if @LocID>0
			select TOP 1 @Call=GUID+'.'+FileExtension from COM_Files with(nolock) where CostCenterID=50002 and IsProductImage=1 and FeaturePK=@LocID
			order by (CASE WHEN IsDefaultImage=0 THEN 100 ELSE IsDefaultImage END),FileID
		if @Call is null or @Call=''
			SELECT @Call=LogoExt FROM PACT2C.dbo.ADM_Company with(nolock) WHERE DBIndex=@CompanyIndex Order by StatusID ASC
		select @Call LogoExt
	END
	ELSE IF @Call='GETDASHBOARDLIST'
	BEGIN
		--select ID,FavName from COM_Favourite F with(nolock) join ADM_Assign M with(nolock) on F.ID=M.NodeID
		--where F.TypeID=1 and M.CostCenterID=69 and (M.UserID=@UserID or M.RoleID=@RoleID) group by ID,FavName order by FavName
		
		IF(@UserID=1 OR @RoleID=1)
		BEGIN
			select ID,case isnull(s.ResourceData,'') when '' then FavName else s.ResourceData end FavName
			from COM_Favourite F with(nolock) 
			LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceName=F.FavName AND S.LanguageID=@LangID  
			where F.TypeID=1 
			group by ID,FavName,s.ResourceData order by FavName
		END
		ELSE 
		BEGIN
			select ID,case isnull(s.ResourceData,'') when '' then FavName else s.ResourceData end FavName
			from COM_Favourite F with(nolock) join ADM_Assign M with(nolock) on F.ID=M.NodeID
			LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceName=F.FavName AND S.LanguageID=@LangID  
			where F.TypeID=1 and M.CostCenterID=69 and (M.UserID=@UserID or M.RoleID=@RoleID) group by ID,FavName,s.ResourceData order by FavName
		END

	END
	ELSE IF @Call='DELETE' OR @Call='FORCEDELETE'
	BEGIN
		if @Call='DELETE' and exists(select * from ADM_Assign with(nolock) where CostCenterID=69 and NodeID=@FavID and UserID!=@UserID)
		begin
			SELECT 'Favourite assigned to users. Still do you want to delete?' DeleteError
			ROLLBACK TRANSACTION
			return -101
		end
		DELETE FROM COM_Favourite WHERE FavID=@FavID
		DELETE FROM COM_Favourite WHERE ID=@FavID
		delete from ADM_Assign where CostCenterID=69 and NodeID=@FavID
		select @FavID Deleted
	END
	ELSE IF @Call='VIEW'
	BEGIN
		INSERT INTO @TABLE  
		select distinct cf.FeatureactionID,cf.FeatureID,null FeatureActionName,  
		s.ResourceData DisplayName,--cf.DisplayName,
		cf.RowNo,cf.ColumnNo,cf.ShortCutKey, R.TabID,null TabName,   
		R.GROUPID,null GroupName,
		s.ResourceData ScreenName,--R.ScreenName,
		R.ImagePath,R.ButtonKeyTip,0, af.FeatureActionTypeID ,
		cf.FavName  FavoriteName,cf.Link,cf.Category
		from COM_Favourite cf WITH(NOLOCK) 
		join ADM_RibbonView R WITH(NOLOCK) on cf.FeatureactionID=R.FeatureActionID AND cf.FeatureID=R.FeatureID 
		LEFT JOIN ADM_FeatureAction af  WITH(NOLOCK) ON   cf.FeatureactionID=af.FeatureactionID 
		LEFT JOIN ADM_FeatureActionRoleMap far  WITH(NOLOCK) ON far.FeatureActionID=af.FeatureactionID and far.roleid=@RoleID 
		LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=cf.ResourceID AND S.LanguageID=@LangID  
		WHERE cf.FavID=@FavID AND cf.isReport=0 --and af.featureid is not null 
		and (far.featureactionrolemapid is not null or cf.featureid=498  or (cf.featureid between 40001 and 49999 and (af.FeatureActionTypeID=1 or af.FeatureActionTypeID=2)))
		order by cf.RowNo,cf.ColumnNo
		--select distinct cf.FeatureactionID,cf.FeatureID,null FeatureActionName,  
		--s.ResourceData DisplayName,--cf.DisplayName,
		--cf.RowNo,cf.ColumnNo,cf.ShortCutKey, R.TabID,null TabName,   
		--R.GROUPID,null GroupName,
		--s.ResourceData ScreenName,--R.ScreenName,
		--R.ImagePath,R.ButtonKeyTip,0, af.FeatureActionTypeID ,
		--cf.FavName  FavoriteName,cf.Link,cf.Category
		--from COM_Favourite cf WITH(NOLOCK) 
		--join ADM_RibbonView R WITH(NOLOCK) on cf.FeatureactionID=R.FeatureActionID AND cf.FeatureID=R.FeatureID 
		--LEFT JOIN ADM_FeatureAction af  WITH(NOLOCK) ON   cf.FeatureactionID=af.FeatureactionID 
		--LEFT JOIN ADM_FeatureActionRoleMap far  WITH(NOLOCK) ON far.FeatureActionID=af.FeatureactionID and far.roleid=@RoleID 
		--LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=R.ScreenResourceID AND S.LanguageID=@LangID  
		--WHERE cf.FavID=@FavID AND cf.isReport=0 --and af.featureid is not null 
		--and (far.featureactionrolemapid is not null or cf.featureid=498  or (cf.featureid between 40001 and 49999 and (af.FeatureActionTypeID=1 or af.FeatureActionTypeID=2)))
		--order by cf.RowNo,cf.ColumnNo
		
		declare @OptXML xml
		select @OptXML = OptionsXML from COM_Favourite F with(nolock) where TypeID=1 and ID=@FavID
		
		if(select X.value('CheckReportSecurity[1]','int') FROM @OptXML.nodes('/XML') as Data(X))=1
			INSERT INTO @TABLE  
			SELECT distinct ADM_RevenUReports.REPORTID FeatureActionID,ADM_RevenUReports.ParentID,ADM_RevenUReports.ReportName FeatureActionName,cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey,  
			'6' 'TabID', 'Reports' 'TabName',R.REPORTID GroupID,R.ReportName GroupName,'Reports', 
			'REP_List-of-reports.png',NULL,1, case when @RoleID!=1 and S.ReportID is null then 0 else 1 end ,   cf.FavName  FavoriteName,cf.Link,cf.Category
			FROM COM_Favourite cf WITH(NOLOCK)      
			INNER JOIN ADM_RevenUReports WITH(NOLOCK) ON ADM_RevenUReports.REPORTID=cf.FeatureactionID  
			LEFT JOIN ADM_RevenUReports R WITH(NOLOCK) ON R.REPORTID=ADM_RevenUReports.PARENTID
			left join (SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0 and (M.ActionType=1 or M.ActionType=0)
				WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
				union
				SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1 and (M.ActionType=1 or M.ActionType=0)
				inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
				WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)) S on S.ReportID=ADM_RevenUReports.REPORTID
			WHERE cf.FavID=@FavID AND cf.isReport=1
			order by cf.RowNo,cf.ColumnNo
		ELSE
			INSERT INTO @TABLE  
			SELECT distinct ADM_RevenUReports.REPORTID FeatureActionID,ADM_RevenUReports.ParentID,ADM_RevenUReports.ReportName FeatureActionName,cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey,  
			'6' 'TabID', 'Reports' 'TabName',R.REPORTID GroupID,R.ReportName GroupName,'Reports', 
			'REP_List-of-reports.png',NULL,1, 1,   cf.FavName  FavoriteName,cf.Link,cf.Category
			FROM COM_Favourite cf WITH(NOLOCK)      
			INNER JOIN ADM_RevenUReports WITH(NOLOCK) ON ADM_RevenUReports.REPORTID=cf.FeatureactionID  
			LEFT JOIN ADM_RevenUReports R WITH(NOLOCK) ON R.REPORTID=ADM_RevenUReports.PARENTID
			WHERE cf.FavID=@FavID AND cf.isReport=1
			order by cf.RowNo,cf.ColumnNo
		
		INSERT INTO @TABLE 
		SELECT distinct L.NodeID FeatureActionID,-44,L.LookupName FeatureActionName,cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey,  
		'9' 'TabID', 'Administration' 'TabName',9 GroupID,'Administration' GroupName,'Administration',
		'lookups.png',NULL,0,0 ,   cf.FavName  FavoriteName,cf.Link,cf.Category
		FROM COM_Favourite cf WITH(NOLOCK)      
		INNER JOIN COM_LookupTypes L WITH(NOLOCK) ON L.NodeID=cf.FeatureactionID  			   
		WHERE cf.FavID=@FavID AND cf.FeatureID=-44
		order by cf.RowNo,cf.ColumnNo
		
		INSERT INTO @TABLE
		select distinct cf.FeatureactionID,cf.FeatureID,null FeatureActionName,  
		cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey, R.TabID,null TabName,   
		R.GROUPID,null GroupName,R.ScreenName,R.ImagePath,R.ButtonKeyTip,0, af.FeatureActionTypeID ,
		cf.FavName  FavoriteName,cf.Link,cf.Category
		from COM_Favourite cf WITH(NOLOCK) 
		inner join ADM_RibbonView R WITH(NOLOCK) on cf.FeatureactionID=R.FeatureActionID AND cf.FeatureID=R.FeatureID 
		LEFT JOIN ADM_FeatureAction af  WITH(NOLOCK) ON   cf.FeatureactionID=af.FeatureactionID 
		LEFT JOIN ADM_FeatureActionRoleMap far  WITH(NOLOCK) ON far.FeatureActionID=af.FeatureactionID and far.roleid=@RoleID 
		WHERE cf.FavID=@FavID AND cf.featureid=494 and cf.FeatureactionID in (
			SELECT R.ID FROM ADM_Assign M with(nolock) inner join ADM_BulkEditTemplate R with(nolock) on R.ID=M.NodeID
			WHERE M.CostCenterID=49 and UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
			GROUP BY R.ID)
		order by cf.RowNo,cf.ColumnNo
	
		select RowNo,ColumnNo,DisplayName,FeatureactionID,ImagePath,ScreenName,ShortCutKey,FeatureID,ButtonKeyTip,isReport,FeatureActionTypeID,Link,Category,Dt.DocumentType
		,CASE WHEN ISNULL(isReport,0)=0 AND t.FeatureID between 40001 and 49999 THEN dbo.fnCOM_HasAccess(@RoleID,t.FeatureID,2) ELSE 1 END  as HasAccess
		from @TABLE  t 
		left join Adm_DocumentTypes Dt WITH(NOLOCK) on Dt.CostcenterID=t.FeatureID 
		order by RowNo,ColumnNo
	     
		SELECT MAX(ROWNO) MaxRows FROM COM_Favourite WITH(NOLOCK) WHERE FavID=@FavID
		
		select OptionsXML from COM_Favourite F with(nolock) where TypeID=1 and ID=@FavID
	END
	ELSE IF @Call='ISESS'
	BEGIN
		INSERT INTO @TABLE  
		select distinct cf.FeatureactionID,cf.FeatureID,null FeatureActionName,  
		cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey, R.TabID,null TabName,   
		R.GROUPID,null GroupName,R.ScreenName,R.ImagePath,R.ButtonKeyTip,0, af.FeatureActionTypeID ,
		cf.FavName  FavoriteName,cf.Link,cf.Category
		from COM_Favourite cf WITH(NOLOCK) 
		LEFT join ADM_RibbonView R WITH(NOLOCK) on cf.FeatureactionID=R.FeatureActionID AND cf.FeatureID=R.FeatureID 
		LEFT JOIN ADM_FeatureAction af  WITH(NOLOCK) ON   cf.FeatureactionID=af.FeatureactionID 
		LEFT JOIN ADM_FeatureActionRoleMap far  WITH(NOLOCK) ON far.FeatureActionID=af.FeatureactionID and far.roleid=@RoleID 
		WHERE cf.FavID=@FavID AND cf.isReport=0 and af.featureid is not null 
		and (far.featureactionrolemapid is not null or cf.featureid=498 or (cf.featureid between 40001 and 49999 and (af.FeatureActionTypeID=1 or af.FeatureActionTypeID=2)))
		order by cf.RowNo,cf.ColumnNo

		INSERT INTO @TABLE  
		SELECT distinct ADM_RevenUReports.REPORTID FeatureActionID,ADM_RevenUReports.ParentID,ADM_RevenUReports.ReportName FeatureActionName,cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey,  
		'6' 'TabID', 'Reports' 'TabName',R.REPORTID GroupID,R.ReportName GroupName,'Reports', 
		'REP_List-of-reports.png',NULL,1,0 ,   cf.FavName  FavoriteName,cf.Link,cf.Category
		FROM COM_Favourite cf WITH(NOLOCK)      
		INNER JOIN ADM_RevenUReports WITH(NOLOCK) ON ADM_RevenUReports.REPORTID=cf.FeatureactionID  
		LEFT JOIN ADM_RevenUReports R WITH(NOLOCK) ON R.REPORTID=ADM_RevenUReports.PARENTID  
		WHERE cf.FavID=@FavID AND cf.isReport=1
		order by cf.RowNo,cf.ColumnNo
		
		INSERT INTO @TABLE
		select distinct cf.FeatureactionID,cf.FeatureID,null FeatureActionName,  
		cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey, R.TabID,null TabName,   
		R.GROUPID,null GroupName,R.ScreenName,R.ImagePath,R.ButtonKeyTip,0, af.FeatureActionTypeID ,
		cf.FavName  FavoriteName,cf.Link,cf.Category
		from COM_Favourite cf WITH(NOLOCK) 
		inner join ADM_RibbonView R WITH(NOLOCK) on cf.FeatureactionID=R.FeatureActionID AND cf.FeatureID=R.FeatureID 
		LEFT JOIN ADM_FeatureAction af  WITH(NOLOCK) ON   cf.FeatureactionID=af.FeatureactionID 
		LEFT JOIN ADM_FeatureActionRoleMap far  WITH(NOLOCK) ON far.FeatureActionID=af.FeatureactionID and far.roleid=@RoleID 
		WHERE cf.FavID=@FavID AND cf.featureid=494 and cf.FeatureactionID in (
			SELECT R.ID FROM ADM_Assign M with(nolock) inner join ADM_BulkEditTemplate R with(nolock) on R.ID=M.NodeID
			WHERE M.CostCenterID=49 and UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
			GROUP BY R.ID)
		order by cf.RowNo,cf.ColumnNo
	
		select RowNo,ColumnNo,DisplayName,FeatureactionID,ImagePath,ScreenName,ShortCutKey,FeatureID,ButtonKeyTip,isReport,FeatureActionTypeID,Link,Category,Dt.DocumentType
		from @TABLE t left join Adm_DocumentTypes Dt on Dt.CostcenterID=t.FeatureID order by RowNo,ColumnNo
	     
		SELECT MAX(ROWNO) MaxRows FROM COM_Favourite WITH(NOLOCK) WHERE FavID=@FavID
		
		select OptionsXML from COM_Favourite F with(nolock) where TypeID=1 and ID=@FavID
	END
	ELSE IF @Call='EDITGET'
	BEGIN
		IF @FavID>0
		BEGIN
			  INSERT INTO @TABLE  
			  select distinct cf.FeatureactionID,cf.FeatureID, f.ResourceData as FeatureActionName,  
			  cf.DisplayName,cf.RowNo,cf.ColumnNo, cf.ShortCutKey, R.TabID, t.ResourceData as TabName,   
			  R.GROUPID, g.ResourceData as GroupName,R.ScreenName,R.ImagePath,R.ButtonKeyTip,0, 
			  af.FeatureActionTypeID , cf.FavName  FavoriteName,cf.Link,cf.Category
			  from COM_Favourite cf WITH(NOLOCK) 
			  inner join ADM_RibbonView R WITH(NOLOCK) on cf.FeatureactionID=R.FeatureActionID AND cf.FeatureID=R.FeatureID 
			  LEFT JOIN ADM_FeatureAction af WITH(NOLOCK) ON   cf.FeatureactionID=af.FeatureactionID 
			  LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=R.TabResourceID AND T.LanguageID=@LangID  
			  LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=R.GroupResourceID AND G.LanguageID=@LangID  
			  LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=R.FeatureActionResourceID AND F.LanguageID=@LangID  
			  WHERE cf.FavID=@FavID AND cf.isReport=0 and (af.featureid is not null or cf.FeatureID=498)
			  order by cf.RowNo,cf.ColumnNo
		  
			  INSERT INTO @TABLE  
			  SELECT distinct ADM_RevenUReports.REPORTID FeatureActionID,ADM_RevenUReports.ParentID,ADM_RevenUReports.ReportName FeatureActionName,cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey,  
			  '6' 'TabID', 'Reports' 'TabName',R.REPORTID GroupID,R.ReportName GroupName,'Reports',
			   'REP_List-of-reports.png',NULL,1,0 ,   cf.FavName  FavoriteName,cf.Link,cf.Category
			   FROM COM_Favourite cf WITH(NOLOCK)      
			   INNER JOIN ADM_RevenUReports WITH(NOLOCK) ON ADM_RevenUReports.REPORTID=cf.FeatureactionID  
			   LEFT JOIN ADM_RevenUReports R WITH(NOLOCK) ON R.REPORTID=ADM_RevenUReports.PARENTID  
			   WHERE cf.FavID=@FavID AND cf.isReport=1
			   order by cf.RowNo,cf.ColumnNo
			   
			   INSERT INTO @TABLE 
			   SELECT distinct L.NodeID FeatureActionID,-44,L.LookupName FeatureActionName,cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey,  
			  '9' 'TabID', 'Administration' 'TabName',-44 GroupID,'Lookup' GroupName,'Administration',
			   'lookups.png',NULL,0,0 ,   cf.FavName  FavoriteName,cf.Link,cf.Category
			   FROM COM_Favourite cf WITH(NOLOCK)      
			   INNER JOIN COM_LookupTypes L WITH(NOLOCK) ON L.NodeID=cf.FeatureactionID  			   
			   WHERE cf.FavID=@FavID AND cf.FeatureID=-44
			   order by cf.RowNo,cf.ColumnNo
		END    
		ELSE
		BEGIN
			  INSERT INTO @TABLE  
			  select distinct cf.FeatureactionID,cf.FeatureID, f.ResourceData as FeatureActionName,  
			  cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey, R.TabID, t.ResourceData as TabName,   
			  R.GROUPID, g.ResourceData as GroupName,R.ScreenName,R.ImagePath,R.ButtonKeyTip,0, af.FeatureActionTypeID ,
			   cf.FavName  FavoriteName,cf.Link,cf.Category
			  from COM_Favourite cf WITH(NOLOCK) 
			  inner join ADM_RibbonView R WITH(NOLOCK) on cf.FeatureactionID=R.FeatureActionID  AND cf.FeatureID=R.FeatureID 
			  LEFT JOIN ADM_FeatureAction af WITH(NOLOCK) ON   cf.FeatureactionID=af.FeatureactionID
			  LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=R.TabResourceID AND T.LanguageID=@LangID  
			  LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=R.GroupResourceID AND G.LanguageID=@LangID  
			  LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=R.FeatureActionResourceID AND F.LanguageID=@LangID  
			  WHERE 1!=1 and cf.isReport=0 and af.featureid is not null 
			  order by cf.RowNo,cf.ColumnNo
		  
			  INSERT INTO @TABLE  
			  SELECT distinct ADM_RevenUReports.REPORTID FeatureActionID,ADM_RevenUReports.ParentID,ADM_RevenUReports.ReportName FeatureActionName,cf.DisplayName,cf.RowNo,cf.ColumnNo,cf.ShortCutKey,  
			  '6' 'TabID', 'Reports' 'TabName',R.REPORTID GroupID,R.ReportName GroupName,'Reports', 
			  'REP_List-of-reports.png',NULL,1,0 ,   cf.FavName  FavoriteName,cf.Link,cf.Category
			   FROM COM_Favourite cf WITH(NOLOCK)      
			   INNER JOIN ADM_RevenUReports WITH(NOLOCK) ON ADM_RevenUReports.REPORTID=cf.FeatureactionID  
			   LEFT JOIN ADM_RevenUReports R WITH(NOLOCK) ON R.REPORTID=ADM_RevenUReports.PARENTID  
			   WHERE 1!=1 and cf.isReport=1  
			   order by cf.RowNo,cf.ColumnNo
		END
		 
		select * from @TABLE order by RowNo,ColumnNo 
		
		select FavID DefaultFavID from COM_Favourite F with(nolock) where TypeID=3 and FeatureActionID=@UserID
		
		select OptionsXML from COM_Favourite F with(nolock) where TypeID=1 and ID=@FavID
	END
	ELSE IF @Call='MENU'
	BEGIN	
		--Getting ribbon view information for that user.  		
		set @SQL='declare @UserID int,@LangID int,@RoleID int
set @UserID='+convert(nvarchar,@UserID)+'
set @RoleID='+convert(nvarchar,@RoleID)+'
set @LangID='+convert(nvarchar,@LangID)
		set @SQL=@SQL+'
SELECT DISTINCT  RibbonViewID 
  ,ISNULL(RV.TabID,0) TabID  
  ,ISNULL(RV.GroupID,0) GroupID  
  ,ISNULL(RV.DrpID,0) DrpID  
  ,T.ResourceData TabName      
  ,G.ResourceData GroupName  
  ,D.ResourceData DrpName      
  ,ISNULL(RV.FeatureID,0) FeatureID  
  ,ISNULL(RV.FeatureActionID,0) FeatureActionID  
  ,F.ResourceData FeatureActionName   
  ,S.ResourceData ScreenName        
  ,ADM_FeatureAction.FeatureActionTypeID  
  ,RV.TabResourceID
  ,RV.GroupResourceID
  ,RV.DrpResourceID
  ,RV.ScreenResourceID  
  ,RV.DisplayNameResourceID
  ,RV.ColumnOrder  
  ,ISNULL(ShowInWeb,0) ShowInWeb
  ,ISNULL(ShowInMobile,0) ShowInMobile
  ,IsOffLine
FROM ADM_RibbonView RV WITH(NOLOCK)  
INNER JOIN ADM_FeatureActionRoleMap WITH(NOLOCK) ON ADM_FeatureActionRoleMap.FeatureActionID=RV.FeatureActionID AND ADM_FeatureActionRoleMap.RoleID=@RoleID   
LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=RV.TabResourceID AND T.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=RV.GroupResourceID AND G.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources D  WITH(NOLOCK) ON D.ResourceID=RV.DrpResourceID AND D.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=RV.FeatureActionResourceID AND F.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=RV.ScreenResourceID AND S.LanguageID=@LangID  
LEFT JOIN ADM_FeatureAction  WITH(NOLOCK) ON ADM_FeatureAction.FeatureActionID=RV.FeatureActionID 
WHERE RV.FeatureID NOT IN (494,498,499) 
UNION
SELECT DISTINCT  RV.RibbonViewID 
  ,ISNULL(RV.TabID,0) TabID  
  ,ISNULL(RV.GroupID,0) GroupID  
  ,ISNULL(RV.DrpID,0) DrpID  
  ,T.ResourceData TabName      
  ,G.ResourceData GroupName  
  ,D.ResourceData DrpName      
  ,ISNULL(RV.FeatureID,0) FeatureID  
  ,ISNULL(RV.FeatureActionID,0) FeatureActionID  
  ,F.ResourceData FeatureActionName   
  ,S.ResourceData ScreenName        
  ,ADM_FeatureAction.FeatureActionTypeID  
  ,RV.TabResourceID
  ,RV.GroupResourceID
  ,RV.DrpResourceID
  ,RV.ScreenResourceID  
  ,RV.DisplayNameResourceID
  ,RV.ColumnOrder  
  ,ISNULL(ShowInWeb,0) ShowInWeb
  ,ISNULL(ShowInMobile,0) ShowInMobile
  ,IsOffLine
FROM ADM_RibbonView RV WITH(NOLOCK)  
LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=RV.TabResourceID AND T.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=RV.GroupResourceID AND G.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources D  WITH(NOLOCK) ON D.ResourceID=RV.DrpResourceID AND D.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=RV.FeatureActionResourceID AND F.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=RV.ScreenResourceID AND S.LanguageID=@LangID  
LEFT JOIN ADM_FeatureAction  WITH(NOLOCK) ON ADM_FeatureAction.FeatureActionID=RV.FeatureActionID  
WHERE (	RV.FeatureID=498 AND RV.FeatureActionID IN 
		(
			SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0
			WHERE ActionType=1 AND UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
			UNION
			SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1
			inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
			WHERE ActionType=1 AND UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)					
		)						
	)
OR (RV.FeatureID=499 AND RV.FeatureActionID IN (SELECT DISTINCT DashBoardID FROM ADM_DashBoardUserRoleMap with(nolock)
WHERE UserID=@UserID or RoleID=@RoleID or GroupID IN  (SELECT GID FROM COM_Groups G with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)))'
set @SQL=@SQL+'
OR (RV.FeatureID=494 AND RV.FeatureActionID IN 
		(
			SELECT R.ID FROM ADM_Assign M with(nolock) inner join ADM_BulkEditTemplate R with(nolock) on R.ID=M.NodeID
			WHERE M.CostCenterID=49 and UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
			GROUP BY R.ID					
		)						
	)
ORDER BY TabID,GroupID,ColumnOrder,RibbonViewID  '
		EXEC(@SQL)
		  
		SELECT ISNULL(RV.TabID,0) TabID   
			,MAX(T.ResourceData) TabName    
			,RV.TabResourceID
		FROM ADM_RibbonView RV WITH(NOLOCK)  
		INNER JOIN ADM_FeatureActionRoleMap FAR WITH(NOLOCK) ON FAR.FeatureActionID=RV.FeatureActionID AND FAR.RoleID=@RoleID   
		LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=RV.TabResourceID AND T.LanguageID=@LangID  
		LEFT JOIN ADM_FeatureAction  FA WITH(NOLOCK) ON FA.FeatureActionID=RV.FeatureActionID  
		GROUP BY RV.TabID,RV.TabResourceID
		ORDER BY RV.TabID
				
		SELECT ISNULL(RV.TabID,0) TabID  
			,ISNULL(RV.GroupID,0) GroupID  
			,MAX(T.ResourceData) TabName      
			,MAX(G.ResourceData) GroupName
			,RV.TabResourceID
			,RV.GroupResourceID   
		FROM ADM_RibbonView RV WITH(NOLOCK)  
		LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=RV.TabResourceID AND T.LanguageID=@LangID  
		LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=RV.GroupResourceID AND G.LanguageID=@LangID  
		GROUP BY RV.TabID,RV.GroupID,RV.TabResourceID,RV.GroupResourceID  
		ORDER BY RV.TabID,RV.GroupID
		
		SELECT ISNULL(RV.TabID,0) TabID   
			,ISNULL(RV.GroupID,0) GroupID
			,ISNULL(RV.DrpID,0) DrpID   
			,MAX(T.ResourceData) TabName        
			,MAX(G.ResourceData) GroupName
			,MAX(D.ResourceData) DrpName
			,RV.DrpResourceID
			,RV.GroupResourceID   
		FROM ADM_RibbonView RV WITH(NOLOCK)
		LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=RV.TabResourceID AND T.LanguageID=@LangID  
		LEFT JOIN COM_LanguageResources D  WITH(NOLOCK) ON D.ResourceID=RV.DrpResourceID AND D.LanguageID=@LangID  
		LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=RV.GroupResourceID AND G.LanguageID=@LangID 
		WHERE RV.DrpID IS NOT NULL
		GROUP BY RV.TabID,RV.GroupID,RV.DrpID,RV.TabResourceID,RV.GroupResourceID,RV.DrpResourceID  
		ORDER BY RV.TabID,RV.GroupID,RV.DrpID
	END
	ELSE
	BEGIN  
		  --Getting ribbon view information for that user.  
		set @SQL='
SELECT RibbonViewID ,GroupOrder  
,ISNULL(TabID,0) TabID,ISNULL(GroupID,0) GroupID,DrpID,DrpImage,T.ResourceData TabName,G.ResourceData GroupName,D.ResourceData DrpName   
,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID  
,F.ResourceData FeatureActionName,S.ResourceData ScreenName,ImageType,ImagePath  
,TT.ResourceData ToolTipTitle,ToolTipImg,TD.ResourceData ToolTipDesc   
,ISNULL(ADM_FeatureActionRoleMap.FeatureActionRoleMapID,0) [HasAccess],TabOrder,ADM_FeatureAction.FeatureActionTypeID  
,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip  
,DN.Resourcedata as RDrpName,ADM_RibbonView.TabResourceID,ADM_RibbonView.GroupResourceID,ADM_RibbonView.ScreenResourceID,  
ADM_RibbonView.DisplayNameResourceID, ADM_RibbonView.ColumnOrder  
,(select count(*) from ADM_RibbonView RB WITH(NOLOCK) where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount] 
,ISNULL(ShowInWeb,0) ShowInWeb,ISNULL(ShowInMobile,0) ShowInMobile,IsOffLine
FROM ADM_RibbonView WITH(NOLOCK)  
LEFT JOIN ADM_FeatureActionRoleMap WITH(NOLOCK) ON ADM_FeatureActionRoleMap.FeatureActionID=ADM_RibbonView.FeatureActionID AND ADM_FeatureActionRoleMap.RoleID=@RoleID   
LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=ADM_RibbonView.TabResourceID AND T.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=ADM_RibbonView.GroupResourceID AND G.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=ADM_RibbonView.FeatureActionResourceID AND F.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources TT WITH(NOLOCK) ON TT.ResourceID=ADM_RibbonView.ToolTipTitleResourceID AND TT.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources TD WITH(NOLOCK) ON TD.ResourceID=ADM_RibbonView.ToolTipDescResourceID AND TD.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=ADM_RibbonView.DrpResourceID AND D.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources DN WITH(NOLOCK) ON DN.ResourceID=ADM_RibbonView.DisplaynameResourceID AND DN.LanguageID=@LangID  
LEFT JOIN ADM_FeatureAction  WITH(NOLOCK) ON ADM_FeatureAction.FeatureActionID=ADM_RibbonView.FeatureActionID  
WHERE ISNULL(ADM_RibbonView.FeatureID,0)!=494
and (ADM_FeatureActionRoleMap.FeatureActionID is not null or ADM_RibbonView.FeatureID=498)
UNION ALL
SELECT RibbonViewID ,GroupOrder  
,ISNULL(TabID,0) TabID,ISNULL(GroupID,0) GroupID,DrpID,DrpImage,T.ResourceData TabName,G.ResourceData GroupName,D.ResourceData DrpName   
,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID  
,F.ResourceData FeatureActionName,S.ResourceData ScreenName,ImageType,ImagePath  
,TT.ResourceData ToolTipTitle,ToolTipImg,TD.ResourceData ToolTipDesc   
,ISNULL(ADM_RibbonView.FeatureactionID,0) [HasAccess],TabOrder,ADM_FeatureAction.FeatureActionTypeID  
,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip  
,DN.Resourcedata as RDrpName,ADM_RibbonView.TabResourceID,ADM_RibbonView.GroupResourceID,ADM_RibbonView.ScreenResourceID,  
ADM_RibbonView.DisplayNameResourceID, ADM_RibbonView.ColumnOrder  
,(select count(*) from ADM_RibbonView RB WITH(NOLOCK) where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount] 
,ISNULL(ShowInWeb,0) ShowInWeb,ISNULL(ShowInMobile,0) ShowInMobile,IsOffLine
FROM ADM_RibbonView WITH(NOLOCK)  
LEFT JOIN COM_LanguageResources T WITH(NOLOCK) ON T.ResourceID=ADM_RibbonView.TabResourceID AND T.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources G WITH(NOLOCK) ON G.ResourceID=ADM_RibbonView.GroupResourceID AND G.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources F WITH(NOLOCK) ON F.ResourceID=ADM_RibbonView.FeatureActionResourceID AND F.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources TT WITH(NOLOCK) ON TT.ResourceID=ADM_RibbonView.ToolTipTitleResourceID AND TT.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources TD WITH(NOLOCK) ON TD.ResourceID=ADM_RibbonView.ToolTipDescResourceID AND TD.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=ADM_RibbonView.DrpResourceID AND D.LanguageID=@LangID  
LEFT JOIN COM_LanguageResources DN WITH(NOLOCK) ON DN.ResourceID=ADM_RibbonView.DisplaynameResourceID AND DN.LanguageID=@LangID  
LEFT JOIN ADM_FeatureAction  WITH(NOLOCK) ON ADM_FeatureAction.FeatureActionID=ADM_RibbonView.FeatureActionID  
WHERE ISNULL(ADM_RibbonView.FeatureID,0)=494 and ADM_RibbonView.FeatureactionID in (
SELECT R.ID FROM ADM_Assign M with(nolock) inner join ADM_BulkEditTemplate R with(nolock) on R.ID=M.NodeID
WHERE M.CostCenterID=49 and UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
GROUP BY R.ID)
ORDER BY TabOrder,GroupOrder,ColumnOrder,RibbonViewID'
		  set @SQL='declare @UserID int,@LangID int,@RoleID int
set @UserID='+convert(nvarchar,@UserID)+'
set @RoleID='+convert(nvarchar,@RoleID)+'
set @LangID='+convert(nvarchar,@LangID)+@SQL
		--print(substring(@SQL,1,4000))
		--print(substring(@SQL,4001,len(@SQL)-4000))
		EXEC(@SQL)

		--select ID,FavName,F.CreatedBy from COM_Favourite F with(nolock) join ADM_Assign M with(nolock) on F.ID=M.NodeID
		--where F.TypeID=1 and M.CostCenterID=69 and (M.UserID=@UserID or M.RoleID=@RoleID)
		--group by ID,FavName,F.CreatedBy order by FavName
		IF(@UserID=1 OR @RoleID=1)
		BEGIN
			select ID,case isnull(s.ResourceData,'') when '' then FavName else s.ResourceData end FavName
			,F.CreatedBy from COM_Favourite F with(nolock) 
			LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceName=F.FavName AND S.LanguageID=@LangID  
			where F.TypeID=1 
			group by ID,FavName,F.CreatedBy,s.ResourceData order by FavName
		END
		ELSE
		BEGIN
			select ID,case isnull(s.ResourceData,'') when '' then FavName else s.ResourceData end FavName
			,F.CreatedBy from COM_Favourite F with(nolock) join ADM_Assign M with(nolock) on F.ID=M.NodeID
			LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceName=F.FavName AND S.LanguageID=@LangID  
			where F.TypeID=1 and M.CostCenterID=69 and (M.UserID=@UserID or M.RoleID=@RoleID)
			group by ID,FavName,F.CreatedBy,s.ResourceData order by FavName
		END

		SELECT REPORTID FeatureActionID,REPORTNAME GroupName,IsGroup,ParentID GroupID FROM ADM_RevenUReports WITH(NOLOCK) 
		where reportid>0 and (IsGroup=1 or (@UserID=1 or @RoleID=1 or reportid in 
		(
		SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) 
			inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0
		WHERE (ActionType=1 or ActionType=0) AND (UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID))
		UNION   ALL
		SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1 and (M.ActionType=1 or M.ActionType=0)
inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
		)))
		
		SELECT L.NodeID,isnull(R.ResourceName,L.LookupName) LookupName FROM COM_LookupTypes L WITH(NOLOCK)
		INNER JOIN adm_featureaction FA with(nolock) ON FA.FeatureID=44 and FA.FeatureActionTypeID=(100+L.NodeID*5)
		INNER JOIN adm_featureactionrolemap FAR with(nolock) ON FA.FeatureActionID=FAR.FeatureActionID
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=L.ResourceID AND R.LanguageID=@LangID
		WHERE FAR.RoleID=@RoleID
		ORDER BY LookupName
	END
      
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
	SET NOCOUNT OFF    
	RETURN -999     
END CATCH

GO
