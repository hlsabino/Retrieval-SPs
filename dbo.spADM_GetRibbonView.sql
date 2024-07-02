USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetRibbonView]
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1,
	@IsWebCall [int] = 0,
	@IsMobile [int] = 0,
	@LicenseXML [nvarchar](max) = ''
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON
	
	--Declaration Section
	DECLARE @HasAccess BIT
	declare @TblScreens as Table(ID INT IDENTITY(1,1),IsReport INT,FAID INT,IsDefault BIT)
	declare @DefaultScreenXML nvarchar(max),@XML xml,@LXML xml,@AllowPOS bit,@str nvarchar(max)
	declare @TblRestrictCC as Table(CCID int)

	--SP Required Parameters Check
	IF @UserID<1
	BEGIN
		RAISERROR('-100',16,1)
	END
	set @AllowPOS=1
	if @LicenseXML!=''
	begin
		set @LXML=@LicenseXML
	--		select @LXML
		select @AllowPOS=X.value('POS[1]','bit')
		from @LXML.nodes('/XML') as Data(X)
		if @AllowPOS=0
		begin
			insert into @TblRestrictCC
			select CostCenterID from ADM_DocumentTypes with(nolock) Where DocumentType=38 or DocumentType=39
		end
		set @str=''
		select @str=X.value('WebCC[1]','nvarchar(max)')
		from @LXML.nodes('/XML') as Data(X)
		if @IsWebCall=1 and @str is not null and @str!=''
		begin
			--set @str='select CostCenterID from ADM_DocumentTypes with(nolock) Where CostCenterID not in ('+@str+')'
			set @str='select CostCenterID from ADM_DocumentTypes with(nolock) where DocumentType in (select DocumentType from ADM_DocumentTypes with(nolock) where CostCenterID not in ('+@str+') and IsUserDefined=0)'
			insert into @TblRestrictCC
			exec(@str)
		end
		
		set @str=''
		select @str=X.value('TabMobileCC[1]','nvarchar(max)')
		from @LXML.nodes('/XML') as Data(X)
		if @IsMobile=1 and @str is not null and @str!=''
		begin
			set @str='select CostCenterID from ADM_DocumentTypes with(nolock) where DocumentType in (select DocumentType from ADM_DocumentTypes with(nolock) where CostCenterID not in ('+@str+') and IsUserDefined=0)'
			insert into @TblRestrictCC
			exec(@str)
		end
	end

	--Used to get Mobile ribbon data
	if(@IsMobile=1)
	begin
		BEGIN
		--Getting ribbon view information for that user.
		SELECT DISTINCT  RibbonViewID ,GroupOrder
						,ISNULL(TabID,0) TabID ,ISNULL(GroupID,0) GroupID,DrpID,DrpImage,T.ResourceData TabName			 
						,G.ResourceData GroupName			,D.ResourceData DrpName ,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID
						,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID,F.ResourceData FeatureActionName	
						,S.ResourceData ScreenName		 		 ,ImageType,ImagePath,TT.ResourceData ToolTipTitle
						,ToolTipImg,TD.ResourceData ToolTipDesc ,ISNULL(ADM_FeatureActionRoleMap.FeatureActionRoleMapID,0) [HasAccess]
						,TabOrder,ISNULL(ADM_FeatureAction.FeatureActionTypeID,0)FeatureActionTypeID
						,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip,DN.Resourcedata as RDrpName
						,(select count(*) from ADM_RibbonView RB WITH(NOLOCK) where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount],
						ISNULL(ADM_FeatureActionRoleMap.FeatureActionID,0) FARMID, ColumnOrder,IsMobile,DCT.DocumentType,IsOffLine,ADM_RibbonView.LicSIMPLE
		FROM ADM_RibbonView WITH(NOLOCK)
		inner JOIN ADM_FeatureActionRoleMap WITH(NOLOCK) ON ADM_FeatureActionRoleMap.FeatureActionID=ADM_RibbonView.FeatureActionID AND ADM_FeatureActionRoleMap.RoleID=@RoleID 
		left join @TblRestrictCC TR on TR.CCID=ADM_RibbonView.FeatureID
		LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=ADM_RibbonView.TabResourceID AND T.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=ADM_RibbonView.GroupResourceID AND G.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=ADM_RibbonView.FeatureActionResourceID AND F.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources TT WITH(NOLOCK) ON TT.ResourceID=ADM_RibbonView.ToolTipTitleResourceID AND TT.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources TD WITH(NOLOCK) ON TD.ResourceID=ADM_RibbonView.ToolTipDescResourceID AND TD.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=ADM_RibbonView.DrpResourceID AND D.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources DN WITH(NOLOCK) ON DN.ResourceID=ADM_RibbonView.DisplaynameResourceID AND DN.LanguageID=@LangID
		LEFT JOIN ADM_FeatureAction  WITH(NOLOCK) ON ADM_FeatureAction.FeatureActionID=ADM_RibbonView.FeatureActionID
		LEFT JOIN ADM_DocumentTypes DCT WITH(NOLOCK) ON DCT.CostcenterID=ADM_RibbonView.FeatureID
		WHERE   ADM_RibbonView.IsMobile=@IsMobile and TR.CCID is null and ADM_RibbonView.FeatureID not in (494,498,499,40088,267)
		UNION
		SELECT DISTINCT  RibbonViewID ,GroupOrder
						,ISNULL(TabID,0) TabID
						,ISNULL(GroupID,0) GroupID
						,DrpID
						,DrpImage
						,T.ResourceData TabName			 
						,G.ResourceData GroupName			
						,D.ResourceData DrpName 
				 		,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID
						,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID
						,F.ResourceData FeatureActionName	
						,S.ResourceData ScreenName		 		 
						,ImageType
						,ImagePath
						,TT.ResourceData ToolTipTitle
						,ToolTipImg
						,TD.ResourceData ToolTipDesc 
						,1 [HasAccess]
						,TabOrder
						,ISNULL(ADM_RibbonView.FeatureActionID,0)FeatureActionTypeID
						,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip
						,DN.Resourcedata as RDrpName
						,(select count(*) from ADM_RibbonView RB WITH(NOLOCK)  where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount]
						,ADM_RibbonView.FeatureActionID FARMID, ColumnOrder,IsMobile,NULL,IsOffLine,ADM_RibbonView.LicSIMPLE
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
		WHERE ADM_RibbonView.IsMobile=@IsMobile and  (	ADM_RibbonView.FeatureID=498 AND ADM_RibbonView.FeatureActionID IN 
				(
					SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0
					WHERE (ActionType=1 or ActionType=0) AND UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)
					UNION
					SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1
					inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
					WHERE (ActionType=1 or ActionType=0) AND UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)					
				)						
			)--AND ADM_RibbonView.IsMobile=@IsMobile
		OR (ADM_RibbonView.FeatureID=499 and ADM_RibbonView.IsMobile=1 AND ADM_RibbonView.FeatureActionID IN (SELECT DISTINCT DRP.DashBoardID FROM ADM_DashBoardUserRoleMap DRP with(nolock)
	JOIN ADM_DashBoard DB with(nolock) ON DB.DashBoardID=DRP.DashBoardID AND DB.Mode IN (0,3,4)
		WHERE DRP.UserID=@UserID or DRP.RoleID=@RoleID or DRP.GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)))
		ORDER BY TabOrder,GroupOrder,groupid,Columnorder,RibbonViewID 
		
		SELECT [Name],[Value] FROM ADM_GlobalPreferences WITH(NOLOCK)

		SELECT FA.FeatureID,FA.FeatureActionTypeID,FA.Name,M.[Description] 
		FROM ADM_FeatureActionRoleMap M WITH(NOLOCK)
		INNER JOIN ADM_FeatureAction FA WITH(NOLOCK) ON FA.FeatureActionID=M.FeatureActionID
		WHERE M.RoleID=@RoleID
		ORDER BY FA.FeatureID,FA.FeatureActionTypeID
		
		select  ISNULL(ADM_RibbonView.FeatureID,0) FeatureID
						,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID 
						,S.ResourceData ScreenName	  
						,ISNULL(ADM_RibbonView.FeatureActionID,0)FeatureActionTypeID
		from ADM_RibbonView WITH(NOLOCK)
		LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID
		where ADM_RibbonView.FeatureID=499 AND ADM_RibbonView.FeatureActionID in 
		(SELECT DashBoardID FROM ADM_DashBoardUserRoleMap with(nolock)
		WHERE IsDefault=1 and (UserID=@UserID or RoleID=@RoleID or GroupID IN 
		(SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)))
		
		--User Default Screens
		select @DefaultScreenXML=DefaultScreenXML from ADM_Users with(nolock) WHERE UserID=@UserID
		if(@DefaultScreenXML is not null and @DefaultScreenXML!='')
		begin
			set @XML=@DefaultScreenXML
			
			INSERT INTO @TblScreens
			select X.value('@isReport','int'),X.value('@FeatureActionID','INT'),X.value('@Default','bit')
			from @XML.nodes('/XML/Row') as Data(X)
			--where X.value('@isReport','int')=0
			
			select  ISNULL(R.FeatureID,0) FeatureID
						,ISNULL(R.FeatureActionID,0) FeatureActionID 
						,S.ResourceData ScreenName	  
						,ISNULL(FA.FeatureActionTypeID,0)FeatureActionTypeID,Tbl.IsDefault,Tbl.ID
			from ADM_RibbonView R WITH(NOLOCK)
			inner JOIN ADM_FeatureActionRoleMap FARM WITH(NOLOCK) ON FARM.FeatureActionID=R.FeatureActionID AND FARM.RoleID=@RoleID 
			INNER JOIN ADM_FeatureAction FA  WITH(NOLOCK) ON FA.FeatureActionID=R.FeatureActionID
			INNER JOIN @TblScreens Tbl ON Tbl.FAID=FA.FeatureActionID
			LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=R.ScreenResourceID  AND S.LanguageID=@LangID
			where Tbl.IsReport=0
			UNION
			select  50 FeatureID
						,R.ReportID FeatureActionID 
						,R.ReportName ScreenName	  
						,R.ReportID FeatureActionTypeID,Tbl.IsDefault,Tbl.ID
			from ADM_RevenUReports R WITH(NOLOCK)
			INNER JOIN @TblScreens Tbl ON Tbl.FAID=R.ReportID
			where Tbl.IsReport=1
			order by Tbl.IsDefault desc,Tbl.ID
		end
		else
			select 0 DefaultScreen where 1<>1
 	END
	end 
	else if @IsWebCall=1
	BEGIN
	
	--select 11
		--Getting ribbon view information for that user.
		SELECT DISTINCT  RibbonViewID ,GroupOrder
						,ISNULL(TabID,0) TabID
						,ISNULL(GroupID,0) GroupID
						,DrpID
						,DrpImage
						,T.ResourceData TabName			 
						,G.ResourceData GroupName			
						,D.ResourceData DrpName 
				 		,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID
						,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID
						,F.ResourceData FeatureActionName	
						,S.ResourceData ScreenName		 		 
						,ImageType
						,ImagePath
						,TT.ResourceData ToolTipTitle
						,ToolTipImg
						,TD.ResourceData ToolTipDesc 
						,ISNULL(ADM_FeatureActionRoleMap.FeatureActionRoleMapID,0) [HasAccess]
						,TabOrder
						,ISNULL(ADM_FeatureAction.FeatureActionTypeID,0)FeatureActionTypeID
						,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip
						,DN.Resourcedata as RDrpName
						,(select count(*) from ADM_RibbonView RB WITH(NOLOCK) where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount],
						ISNULL(ADM_FeatureActionRoleMap.FeatureActionID,0) FARMID, ColumnOrder,IsMobile,DCT.DocumentType,WebIcon,ADM_RibbonView.LicSIMPLE
		FROM ADM_RibbonView WITH(NOLOCK)
		inner JOIN ADM_FeatureActionRoleMap WITH(NOLOCK) ON ADM_FeatureActionRoleMap.FeatureActionID=ADM_RibbonView.FeatureActionID AND ADM_FeatureActionRoleMap.RoleID=@RoleID 
		left join @TblRestrictCC TR on TR.CCID=ADM_RibbonView.FeatureID
		LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=ADM_RibbonView.TabResourceID AND T.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=ADM_RibbonView.GroupResourceID AND G.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=ADM_RibbonView.FeatureActionResourceID AND F.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources TT WITH(NOLOCK) ON TT.ResourceID=ADM_RibbonView.ToolTipTitleResourceID AND TT.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources TD WITH(NOLOCK) ON TD.ResourceID=ADM_RibbonView.ToolTipDescResourceID AND TD.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=ADM_RibbonView.DrpResourceID AND D.LanguageID=@LangID
		LEFT JOIN COM_LanguageResources DN WITH(NOLOCK) ON DN.ResourceID=ADM_RibbonView.DisplaynameResourceID AND DN.LanguageID=@LangID
		LEFT JOIN ADM_FeatureAction  WITH(NOLOCK) ON ADM_FeatureAction.FeatureActionID=ADM_RibbonView.FeatureActionID
		LEFT JOIN ADM_DocumentTypes DCT WITH(NOLOCK) ON DCT.CostcenterID=ADM_RibbonView.FeatureID
		WHERE ADM_RibbonView.FeatureID NOT IN (494,498,499,40088,267) AND ADM_RibbonView.ShowInWeb=1 and TR.CCID is null
		UNION
		SELECT DISTINCT  RibbonViewID ,GroupOrder
						,ISNULL(TabID,0) TabID
						,ISNULL(GroupID,0) GroupID
						,DrpID
						,DrpImage
						,T.ResourceData TabName			 
						,G.ResourceData GroupName			
						,D.ResourceData DrpName 
				 		,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID
						,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID
						,F.ResourceData FeatureActionName	
						,S.ResourceData ScreenName		 		 
						,ImageType
						,ImagePath
						,TT.ResourceData ToolTipTitle
						,ToolTipImg
						,TD.ResourceData ToolTipDesc 
						,1 [HasAccess]
						,TabOrder
						,ISNULL(ADM_RibbonView.FeatureActionID,0)FeatureActionTypeID
						,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip
						,DN.Resourcedata as RDrpName
						,(select count(*) from ADM_RibbonView RB WITH(NOLOCK)  where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount]
						,ADM_RibbonView.FeatureActionID FARMID, ColumnOrder,IsMobile,NULL,WebIcon,ADM_RibbonView.LicSIMPLE
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
		WHERE (	ADM_RibbonView.FeatureID=498 AND ADM_RibbonView.FeatureActionID IN 
				(
					SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0
					WHERE (ActionType=1 or ActionType=0) AND UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)
					UNION
					SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1
					inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
					WHERE (ActionType=1 or ActionType=0) AND UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)					
				)						
			)
		OR (ADM_RibbonView.FeatureID=499 AND ADM_RibbonView.ShowInWeb=1 AND ADM_RibbonView.FeatureActionID IN (SELECT DISTINCT DRP.DashBoardID FROM ADM_DashBoardUserRoleMap DRP with(nolock)
	JOIN ADM_DashBoard DB with(nolock) ON DB.DashBoardID=DRP.DashBoardID AND DB.Mode IN (0,2)	
		WHERE DRP.UserID=@UserID or DRP.RoleID=@RoleID or DRP.GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)))
		ORDER BY TabOrder,GroupOrder,groupid,Columnorder,RibbonViewID


		SELECT [Name],[Value] FROM ADM_GlobalPreferences WITH(NOLOCK)

		SELECT FA.FeatureID,FA.FeatureActionTypeID,FA.Name,M.[Description]
		FROM ADM_FeatureActionRoleMap M WITH(NOLOCK)
		INNER JOIN ADM_FeatureAction FA WITH(NOLOCK) ON FA.FeatureActionID=M.FeatureActionID
		WHERE M.RoleID=@RoleID
		ORDER BY FA.FeatureID,FA.FeatureActionTypeID
		
		--Default Dashboard
		select  ISNULL(ADM_RibbonView.FeatureID,0) FeatureID
						,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID 
						,S.ResourceData ScreenName	  
						,ISNULL(ADM_RibbonView.FeatureActionID,0)FeatureActionTypeID
		from ADM_RibbonView WITH(NOLOCK)
		LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID
		where ADM_RibbonView.FeatureID=499 AND ADM_RibbonView.FeatureActionID in 
		(SELECT DashBoardID FROM ADM_DashBoardUserRoleMap with(nolock)
		WHERE IsDefault=1 and (UserID=@UserID or RoleID=@RoleID or GroupID IN 
		(SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)))
		
		--User Default Screens
		select @DefaultScreenXML=DefaultScreenXML from ADM_Users with(nolock) WHERE UserID=@UserID
		if(@DefaultScreenXML is not null and @DefaultScreenXML!='')
		begin
			set @XML=@DefaultScreenXML
			
			INSERT INTO @TblScreens
			select X.value('@isReport','int'),X.value('@FeatureActionID','INT'),X.value('@Default','bit')
			from @XML.nodes('/XML/Row') as Data(X)
			--where X.value('@isReport','int')=0
			
			select  ISNULL(R.FeatureID,0) FeatureID
						,ISNULL(R.FeatureActionID,0) FeatureActionID 
						,S.ResourceData ScreenName	  
						,ISNULL(FA.FeatureActionTypeID,0)FeatureActionTypeID,Tbl.IsDefault,Tbl.ID
			from ADM_RibbonView R WITH(NOLOCK)
			inner JOIN ADM_FeatureActionRoleMap FARM WITH(NOLOCK) ON FARM.FeatureActionID=R.FeatureActionID AND FARM.RoleID=@RoleID 
			INNER JOIN ADM_FeatureAction FA  WITH(NOLOCK) ON FA.FeatureActionID=R.FeatureActionID
			INNER JOIN @TblScreens Tbl ON Tbl.FAID=FA.FeatureActionID
			LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=R.ScreenResourceID  AND S.LanguageID=@LangID
			where Tbl.IsReport=0
			UNION
			select  50 FeatureID
						,R.ReportID FeatureActionID 
						,R.ReportName ScreenName	  
						,R.ReportID FeatureActionTypeID,Tbl.IsDefault,Tbl.ID
			from ADM_RevenUReports R WITH(NOLOCK)
			INNER JOIN @TblScreens Tbl ON Tbl.FAID=R.ReportID
			where Tbl.IsReport=1
			order by Tbl.IsDefault desc,Tbl.ID
		end
		else
			select 0 DefaultScreen where 1<>1
 	
 	END
 	ELSE
 	BEGIN
		--Getting ribbon view information for that user.
		select distinct * from (SELECT   RibbonViewID ,GroupOrder,ISNULL(TabID,0) TabID,ISNULL(GroupID,0) GroupID
			,DrpID,DrpImage,T.ResourceData TabName,G.ResourceData GroupName,D.ResourceData DrpName 
	 		,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID
			,F.ResourceData FeatureActionName,S.ResourceData ScreenName		 		 
			,ImageType,ImagePath,TT.ResourceData ToolTipTitle,ToolTipImg,TD.ResourceData ToolTipDesc 
			,1 [HasAccess],TabOrder
			,ISNULL(ADM_FeatureAction.FeatureActionTypeID,0)FeatureActionTypeID
			,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip,DN.Resourcedata as RDrpName
			,(select count(*) from ADM_RibbonView RB WITH(NOLOCK) where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount],
			ISNULL(ADM_RibbonView.FeatureActionID,0) FARMID, ColumnOrder,AppPath,DCT.DocumentType,ADM_RibbonView.LicSIMPLE
		FROM ADM_RibbonView WITH(NOLOCK)
			inner JOIN ADM_FeatureActionRoleMap WITH(NOLOCK) ON ADM_FeatureActionRoleMap.FeatureActionID=ADM_RibbonView.FeatureActionID AND ADM_FeatureActionRoleMap.RoleID=@RoleID
			left join @TblRestrictCC TR on TR.CCID=ADM_RibbonView.FeatureID
			LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=ADM_RibbonView.TabResourceID AND T.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=ADM_RibbonView.GroupResourceID AND G.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=ADM_RibbonView.FeatureActionResourceID AND F.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources TT WITH(NOLOCK) ON TT.ResourceID=ADM_RibbonView.ToolTipTitleResourceID AND TT.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources TD WITH(NOLOCK) ON TD.ResourceID=ADM_RibbonView.ToolTipDescResourceID AND TD.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=ADM_RibbonView.DrpResourceID AND D.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources DN WITH(NOLOCK) ON DN.ResourceID=ADM_RibbonView.DisplaynameResourceID AND DN.LanguageID=@LangID
			LEFT JOIN ADM_FeatureAction  WITH(NOLOCK) ON ADM_FeatureAction.FeatureActionID=ADM_RibbonView.FeatureActionID
			LEFT JOIN ADM_DocumentTypes DCT WITH(NOLOCK) ON DCT.CostcenterID=ADM_RibbonView.FeatureID
		WHERE ADM_RibbonView.FeatureID NOT IN (494,498,499,40088,267) and ADM_RibbonView.RibbonViewID<>213 and TR.CCID is null
		UNION
		SELECT  RibbonViewID,GroupOrder,ISNULL(TabID,0) TabID,ISNULL(GroupID,0) GroupID
			,DrpID,DrpImage,T.ResourceData TabName,G.ResourceData GroupName,D.ResourceData DrpName 
 			,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID
			,F.ResourceData FeatureActionName,S.ResourceData ScreenName		 		 
			,ImageType,ImagePath,TT.ResourceData ToolTipTitle,ToolTipImg,TD.ResourceData ToolTipDesc 
			,1 [HasAccess],TabOrder
			,ISNULL(ADM_FeatureAction.FeatureActionTypeID,0)FeatureActionTypeID
			,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip,DN.Resourcedata as RDrpName
			,(select count(*) from ADM_RibbonView RB WITH(NOLOCK) where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount],
			ISNULL(ADM_RibbonView.FeatureActionID,0) FARMID, ColumnOrder,AppPath,DCT.DocumentType,ADM_RibbonView.LicSIMPLE
		FROM ADM_RibbonView WITH(NOLOCK)
			inner JOIN ADM_FeatureAction FA  WITH(NOLOCK) ON FA.FeatureID=ADM_RibbonView.FeatureID AND FA.FeatureActionTypeID=2 
			inner JOIN ADM_FeatureActionRoleMap RM WITH(NOLOCK) ON RM.FeatureActionID=FA.FeatureActionID AND RM.RoleID=@RoleID 
			left join @TblRestrictCC TR on TR.CCID=ADM_RibbonView.FeatureID
			LEFT JOIN COM_LanguageResources T  WITH(NOLOCK) ON T.ResourceID=ADM_RibbonView.TabResourceID AND T.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources G  WITH(NOLOCK) ON G.ResourceID=ADM_RibbonView.GroupResourceID AND G.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources F  WITH(NOLOCK) ON F.ResourceID=ADM_RibbonView.FeatureActionResourceID AND F.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources TT WITH(NOLOCK) ON TT.ResourceID=ADM_RibbonView.ToolTipTitleResourceID AND TT.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources TD WITH(NOLOCK) ON TD.ResourceID=ADM_RibbonView.ToolTipDescResourceID AND TD.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=ADM_RibbonView.DrpResourceID AND D.LanguageID=@LangID
			LEFT JOIN COM_LanguageResources DN WITH(NOLOCK) ON DN.ResourceID=ADM_RibbonView.DisplaynameResourceID AND DN.LanguageID=@LangID
			LEFT JOIN ADM_FeatureAction  WITH(NOLOCK) ON ADM_FeatureAction.FeatureActionID=ADM_RibbonView.FeatureActionID
			LEFT JOIN ADM_DocumentTypes DCT WITH(NOLOCK) ON DCT.CostcenterID=ADM_RibbonView.FeatureID
		WHERE ADM_RibbonView.FeatureID between 40000 and 50000 and TR.CCID is null 
		AND ADM_RibbonView.FeatureID NOT IN (40088,267)
		UNION
		SELECT   RibbonViewID ,GroupOrder,ISNULL(TabID,0) TabID,ISNULL(GroupID,0) GroupID
			,DrpID,DrpImage,T.ResourceData TabName,G.ResourceData GroupName,D.ResourceData DrpName 
	 		,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID
			,F.ResourceData FeatureActionName,S.ResourceData ScreenName		 		 
			,ImageType,ImagePath,TT.ResourceData ToolTipTitle,ToolTipImg,TD.ResourceData ToolTipDesc
			,1 [HasAccess],TabOrder
			,ISNULL(ADM_RibbonView.FeatureActionID,0)FeatureActionTypeID
			,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip,DN.Resourcedata as RDrpName
			,(select count(*) from ADM_RibbonView RB WITH(NOLOCK)  where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount]
			,ADM_RibbonView.FeatureActionID FARMID, ColumnOrder,AppPath,NULL,ADM_RibbonView.LicSIMPLE
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
		WHERE (	ADM_RibbonView.FeatureID=498 AND ADM_RibbonView.FeatureActionID IN 
				(
					SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0
					WHERE ActionType=1 AND UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)
					UNION
					SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1
					inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
					WHERE ActionType=1 AND UserID=@UserID or RoleID=@RoleID or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)					
				)						
			)
		OR (ADM_RibbonView.FeatureID=499 AND ADM_RibbonView.FeatureActionID IN (SELECT DISTINCT DRP.DashBoardID FROM ADM_DashBoardUserRoleMap DRP with(nolock)
	JOIN ADM_DashBoard DB with(nolock) ON DB.DashBoardID=DRP.DashBoardID AND DB.Mode IN (0,1)		
		WHERE DRP.UserID=@UserID or DRP.RoleID=@RoleID or DRP.GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)))
		UNION
		SELECT   RibbonViewID ,GroupOrder,ISNULL(TabID,0) TabID,ISNULL(GroupID,0) GroupID
			,DrpID,DrpImage,T.ResourceData TabName,G.ResourceData GroupName,D.ResourceData DrpName 
	 		,ISNULL(ADM_RibbonView.FeatureID,0) FeatureID,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID
			,F.ResourceData FeatureActionName,S.ResourceData ScreenName		 		 
			,ImageType,ImagePath,TT.ResourceData ToolTipTitle,ToolTipImg,TD.ResourceData ToolTipDesc
			,1 [HasAccess],TabOrder
			,ISNULL(ADM_RibbonView.FeatureActionID,0)FeatureActionTypeID
			,TabKeyTip,DrpKeyTip,ButtonKeyTip,GroupKeyTip,DN.Resourcedata as RDrpName
			,(select count(*) from ADM_RibbonView RB WITH(NOLOCK)  where RB.DrpID=ADM_RibbonView.DrpID) [ItemCount]
			,ADM_RibbonView.FeatureActionID FARMID, ColumnOrder,AppPath,NULL,ADM_RibbonView.LicSIMPLE
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
		WHERE (	ADM_RibbonView.FeatureID=494 AND ADM_RibbonView.FeatureActionID IN 
				(
					SELECT R.ID FROM ADM_Assign M with(nolock) inner join ADM_BulkEditTemplate R with(nolock) on R.ID=M.NodeID
					WHERE M.CostCenterID=49 and UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
					GROUP BY R.ID					
				)						
			)
		) as t
		--where t.RibbonViewID=790
		ORDER BY TabOrder,GroupOrder,groupid,Columnorder,RibbonViewID


		SELECT [Name],[Value] FROM ADM_GlobalPreferences WITH(NOLOCK)

		SELECT FA.FeatureID,FA.FeatureActionTypeID,FA.Name,M.[Description] 
		FROM ADM_FeatureActionRoleMap M WITH(NOLOCK)
		INNER JOIN ADM_FeatureAction FA WITH(NOLOCK) ON FA.FeatureActionID=M.FeatureActionID
		WHERE M.RoleID=@RoleID
		ORDER BY FA.FeatureID,FA.FeatureActionTypeID
		
		--Default Dashboard
		select  ISNULL(ADM_RibbonView.FeatureID,0) FeatureID
						,ISNULL(ADM_RibbonView.FeatureActionID,0) FeatureActionID 
						,S.ResourceData ScreenName	  
						,ISNULL(ADM_RibbonView.FeatureActionID,0)FeatureActionTypeID
		from ADM_RibbonView WITH(NOLOCK)
		LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=ADM_RibbonView.ScreenResourceID AND S.LanguageID=@LangID
		where ADM_RibbonView.FeatureID=499 AND ADM_RibbonView.FeatureActionID in 
		(SELECT DashBoardID FROM ADM_DashBoardUserRoleMap with(nolock)
		WHERE IsDefault=1 and (UserID=@UserID or RoleID=@RoleID or GroupID IN 
		(SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID)))
		
		--User Default Screens
	
		select @DefaultScreenXML=DefaultScreenXML from ADM_Users with(nolock) WHERE UserID=@UserID
		if(@DefaultScreenXML is not null and @DefaultScreenXML!='')
		begin
			set @XML=@DefaultScreenXML
			
			INSERT INTO @TblScreens
			select X.value('@isReport','int'),X.value('@FeatureActionID','INT'),X.value('@Default','bit')
			from @XML.nodes('/XML/Row') as Data(X)
			--where X.value('@isReport','int')=0
			
			select  ISNULL(R.FeatureID,0) FeatureID
						,ISNULL(R.FeatureActionID,0) FeatureActionID 
						,S.ResourceData ScreenName	  
						,ISNULL(FA.FeatureActionTypeID,0)FeatureActionTypeID,Tbl.IsDefault,Tbl.ID,DCT.DocumentType
			from ADM_RibbonView R WITH(NOLOCK)
			inner JOIN ADM_FeatureActionRoleMap FARM WITH(NOLOCK) ON FARM.FeatureActionID=R.FeatureActionID AND FARM.RoleID=@RoleID 
			INNER JOIN ADM_FeatureAction FA  WITH(NOLOCK) ON FA.FeatureActionID=R.FeatureActionID
			INNER JOIN @TblScreens Tbl ON Tbl.FAID=FA.FeatureActionID
			LEFT JOIN ADM_DocumentTypes DCT WITH(NOLOCK) ON DCT.CostcenterID=R.FeatureID
			LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=R.ScreenResourceID  AND S.LanguageID=@LangID
			where Tbl.IsReport=0 AND R.FeatureID<>498
			UNION
			select  50 FeatureID
						,R.ReportID FeatureActionID 
						,R.ReportName ScreenName	  
						,R.ReportID FeatureActionTypeID,Tbl.IsDefault,Tbl.ID,0
			from ADM_RevenUReports R WITH(NOLOCK)
			INNER JOIN @TblScreens Tbl ON Tbl.FAID=R.ReportID
			where Tbl.IsReport=1 
			order by Tbl.IsDefault desc,Tbl.ID
		end
		else
			select 0 DefaultScreen where 1<>1
			
		select * from [ADM_HijriCalender] WITH(NOLOCK)
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
