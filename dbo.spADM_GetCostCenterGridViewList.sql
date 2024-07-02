USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterGridViewList]
	@CostCenterID [int] = 0,
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON
		--Declaration Section
		DECLARE @FEATUREID int

		--Check for manadatory paramters
		if(@UserID=0 or @CostCenterID=0)
			 RAISERROR('-100',16,1)
		
		DECLARE @Tbl AS TABLE(ID INT)
		
		INSERT INTO @Tbl
		SELECT ParentNodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
		WHERE ParentCostCenterID=26 AND CostCenterID=6 AND NodeID=@RoleID

		--Getting GridView
		--select * from ADM_GridView WITH(NOLOCK) 
		--where CostCenterID=@CostCenterID AND (IsUserDefined=0 OR GridViewID IN (SELECT ID FROM @Tbl))
		--order by IsViewUserDefault desc ,IsUserDefined
		
		if(dbo.fnCOM_HasAccess(@RoleID,26,221)=1)
			SELECT  AGV.GridViewID,AGV.FeatureID,AGV.CostCenterID,CL.RESOURCEDATA ViewName,AGV.ResourceID,AGV.SearchFilter,AGV.RoleID,AGV.UserID,AGV.IsViewRoleDefault,AGV.IsViewUserDefault,AGV.IsUserDefined,AGV.CompanyGUID,AGV.GUID,AGV.Description,AGV.CreatedBy,AGV.CreatedDate,AGV.ModifiedBy,AGV.ModifiedDate,AGV.FilterXml,AGV.ChunkCount,AGV.DefaultColID,AGV.DefaultFilterID,AGV.DefaultSearchListviews,AGV.DefaultListViewID
			FROM ADM_GridView AGV WITH(NOLOCK) 
			join COM_LANGUAGERESOURCES CL WITH(NOLOCK) on AGV.RESOURCEID=CL.RESOURCEID
			join @Tbl t on t.ID=AGV.GridViewID
			WHERE   AGV.CostCenterID=@CostCenterID AND CL.LanguageID=@LangID 
			ORDER BY IsViewUserDefault desc ,IsUserDefined
		ELSE
			SELECT  AGV.GridViewID,AGV.FeatureID,AGV.CostCenterID,CL.RESOURCEDATA ViewName,AGV.ResourceID,AGV.SearchFilter,AGV.RoleID,AGV.UserID,AGV.IsViewRoleDefault,AGV.IsViewUserDefault,AGV.IsUserDefined,AGV.CompanyGUID,AGV.GUID,AGV.Description,AGV.CreatedBy,AGV.CreatedDate,AGV.ModifiedBy,AGV.ModifiedDate,AGV.FilterXml,AGV.ChunkCount,AGV.DefaultColID,AGV.DefaultFilterID,AGV.DefaultSearchListviews,AGV.DefaultListViewID
			FROM ADM_GridView AGV WITH(NOLOCK) ,COM_LANGUAGERESOURCES CL WITH(NOLOCK)
			WHERE  AGV.RESOURCEID=CL.RESOURCEID AND CostCenterID=@CostCenterID AND CL.LanguageID=@LangID AND (IsUserDefined=0 OR GridViewID IN (SELECT ID FROM @Tbl))
			ORDER BY IsViewUserDefault desc ,IsUserDefined
		
		--Getting GridViewColumns
		IF @CostCenterID=16
			select ResourceData,UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,c.ColumnDataType,c.UserColumnType
			from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
			join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterID IN  (c.CostCenterID) and c.CostCenterColID=a.CostCenterColID
			JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where b.CostCenterID in (@CostCenterID,3)  AND (b.IsUserDefined=0 OR b.GridViewID IN (SELECT ID FROM @Tbl))
			ORDER BY a.ColumnOrder
		else if(@CostCenterID=2 or @CostCenterID =3 or @CostCenterID =94 or @CostCenterID>50000)
			select isnull(ResourceData,a.Description) ResourceData,UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,c.ColumnDataType,c.UserColumnType
			 from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
			join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=a.CostCenterColID
			left JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where b.CostCenterID=@CostCenterID AND (b.IsUserDefined=0 OR b.GridViewID IN (SELECT ID FROM @Tbl))
			union
			select 'Assign_' +f.Name  ResourceData,'Assign_' +f.Name  UserColumnName,'' SysColumnName,
			a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,null ColumnDataType,'String'
			from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
		    join ADM_Features f  WITH(NOLOCK)  on f.FeatureID=-a.CostCenterColID and f.FeatureID between 50000 and 50090
			ORDER BY a.ColumnOrder
		ELSE IF @CostCenterID BETWEEN 40000 AND 50000
			select CASE WHEN C.COLUMNCOSTCENTERID > 50000 THEN E.Name ELSE D.ResourceData END AS ResourceData,UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,null ColumnDataType,UserColumnType,a.ColumnType
			from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
			join ADM_CostCenterDef c WITH(NOLOCK) on b.CostCenterID=c.CostCenterID and c.CostCenterColID=a.CostCenterColID
			LEFT JOIN ADM_FEATURES E WITH(NOLOCK) ON E.FEATUREID =C.COLUMNCOSTCENTERID 
			LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where b.CostCenterID=@CostCenterID AND (b.IsUserDefined=0 OR b.GridViewID IN (SELECT ID FROM @Tbl)) --AND a.ColumnType=1
			ORDER BY a.ColumnOrder
		ELSE
			select isnull(ResourceData,a.Description) ResourceData,UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,null ColumnDataType,UserColumnType
			from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
		    left join ADM_CostCenterDef c WITH(NOLOCK) on b.CostCenterID=c.CostCenterID and c.CostCenterColID=a.CostCenterColID
			left JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where b.CostCenterID=@CostCenterID AND (b.IsUserDefined=0 OR b.GridViewID IN (SELECT ID FROM @Tbl)) 
			ORDER BY a.ColumnOrder
		
		--GETTING CONTEXTMENU
		SELECT DISTINCT A.GridViewID,GridViewColumnID,B.FeatureActionTypeID,isnull(D.ResourceData,B.Name) ResourceData,B.GridShortCut,A.MenuOrder
		from  ADM_GridContextMenu A WITH(NOLOCK) 
		LEFT JOIN ADM_FeatureAction  B WITH(NOLOCK)  on A.FeatureActionID=B.FeatureActionID
		LEFT JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=B.ResourceID AND D.LanguageID=@LangID
		LEFT JOIN ADM_GridView G WITH(NOLOCK) on A.GridViewID=G.GridViewID
		WHERE A.RoleID=@RoleID
		AND G.CostCenterID=@CostCenterID AND (G.IsUserDefined=0 OR G.GridViewID IN (SELECT ID FROM @Tbl))

		select 3 QuickViewTableRemoved

		select 4 TableRemoved
		select 5 TableRemoved
		
		if(@CostCenterID=76)
			select Name,Value from com_costcenterpreferences WITH(NOLOCK) 
			where costcenterid=@CostCenterID and (Name='SingleBOM' or  Name='DefaultCollapse' or Name='SearchView')
		else
			select Name,Value from com_costcenterpreferences WITH(NOLOCK) 
			where costcenterid=@CostCenterID and (Name='DefaultCollapse' or Name='SearchView')
		
		--Quick Add
		declare @CntQuick int
		SELECT @CntQuick=count(CostCenterColID) FROM ADM_CostCenterDef with(nolock) 
		WHERE CostCenterID=@CostCenterID AND ShowInQuickAdd=1
		select @CntQuick ShowInQuickAdd,(select Value from com_costcenterpreferences with(nolock) where CostCenterID=@CostCenterID and Name='EnableQuickAdd') EnableQuickAdd
		
		if(@CostCenterID=3)
		begin
			--select * from com_costcenterpreferences  WITH(NOLOCK) where costcenterid=3 and Name='InheritGroupImage'
			declare @GrpImage bit,@ImageDimCCID INT
			SELECT @GrpImage=convert(bit,Value) from  COM_CostCenterPreferences WITH(NOLOCK)
			WHERE CostCenterID=3 and Name='InheritGroupImage'     
            select @GrpImage Value
			if(@GrpImage=1)
				 SELECT c.* FROM  COM_Files c WITH(NOLOCK) 
				 join INV_Product p with(nolock) on c.FeatureID=3 and FeaturePK =p.ProductID
				 WHERE  IsProductImage=1  and p.IsGroup=1 
		end
	
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
