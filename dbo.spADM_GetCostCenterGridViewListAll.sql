USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterGridViewListAll]
	@CostCenterID [int] = 0,
	@GridViewID [bigint],
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON
		--Declaration Section
		DECLARE @HasAccess bit,@FEATUREID int

		--Check for manadatory paramters
		if(@UserID=0 or @CostCenterID=0)
			 RAISERROR('-100',16,1)

		--User acces check
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		--Getting GridView
		select * from ADM_GridView WITH(NOLOCK) 
		where CostCenterID=@CostCenterID
		order by IsViewUserDefault desc ,IsUserDefined

		--select * from ADM_GridView where GridViewID=209
		--select * from ADM_GridViewColumns where GridViewID=209

		--delete from ADM_GridViewColumns where GridViewID=209 and GridViewColumnID>60000

		--Getting GridViewColumns
		IF @CostCenterID<>16
		begin
			select 'OLD' as 'Link/Delink',D.Resourceid,ResourceData,UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,ColumnType ,b.DefaultColID DefaultColID , b.DefaultFilterID DefaultFilterID,a.Description,a.IsCode   
			from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
			join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=a.CostCenterColID--b.CostCenterID=c.CostCenterID and 
			JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where b.CostCenterID=@CostCenterID
			union 
			select 'OLD' as 'Link/Delink',  a.CostCenterColID CostCenterColID,'Assign_' + f.name ResourceData,'Assign_' + f.name UserColumnName,
			'' SysColumnName,a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,ColumnType ,b.DefaultColID DefaultColID , b.DefaultFilterID DefaultFilterID,a.Description,a.IsCode
			from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK)  on a.GridViewID=b.GridViewID
		    join ADM_Features f  WITH(NOLOCK)  on f.FeatureID=-a.CostCenterColID and f.FeatureID between 50000 and 50090 
			where b.CostCenterID=@CostCenterID
			ORDER BY a.ColumnOrder
		end
		ELSE
		BEGIN
			select 'OLD' as 'Link/Delink',D.Resourceid,ResourceData,UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,ColumnType ,b.DefaultColID DefaultColID , b.DefaultFilterID DefaultFilterID  
			from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
			join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=a.CostCenterColID
			JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where b.CostCenterID =@CostCenterID
			UNION
			select 'OLD' as 'Link/Delink',D.Resourceid,ResourceData,UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,
			a.GridViewID,A.CostCenterColID,ColumnType ,b.DefaultColID DefaultColID , b.DefaultFilterID DefaultFilterID  
			from ADM_GridViewColumns a WITH(NOLOCK) 
			join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
			join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=a.CostCenterColID
			JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=1
			where b.CostCenterID=3 AND SysColumnName LIKE 'CCNID%'		
			ORDER BY a.ColumnOrder
		END
		--GETTING CONTEXTMENU
		SELECT A.GridViewID,GridViewColumnID,B.FeatureActionTypeID,ResourceData,B.GridShortCut,A.MenuOrder
		from  ADM_GridContextMenu A WITH(NOLOCK) 
		JOIN ADM_FeatureAction  B WITH(NOLOCK)  on A.FeatureActionID=B.FeatureActionID
		JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=B.ResourceID AND D.LanguageID=@LangID
		JOIN ADM_GridView G WITH(NOLOCK) on A.GridViewID=G.GridViewID
		WHERE A.RoleID=@RoleID
		AND G.CostCenterID=@CostCenterID
		--UNION
		--SELECT A.GridViewID,GridViewColumnID,B.FeatureActionTypeID,ResourceData,B.GridShortCut,A.MenuOrder
		--FROM  ADM_UserGridContextMenu A WITH(NOLOCK) 
		--join ADM_FeatureAction  B WITH(NOLOCK)  on A.FeatureActionID=B.FeatureActionID
		--JOIN COM_LanguageResources D ON D.ResourceID=B.ResourceID AND D.LanguageID=@LangID
		--JOIN ADM_GridView G on A.GridViewID=G.GridViewID
		--WHERE A.UserID=@UserID AND G.CostCenterID=@CostCenterID  

		--Getting QuickView
		/*IF EXISTS(select IsUserDefined from ADM_QuickViewDef WITH(NOLOCK) 
		where CostCenterID=@CostCenterID AND UserID = @UserID AND IsUserDefined=1)			
		BEGIN
			select * from ADM_QuickViewDef WITH(NOLOCK) 
			where CostCenterID=@CostCenterID AND UserID = @UserID AND IsUserDefined=1
		END	
		ELSE
		BEGIN
			select * from ADM_QuickViewDef WITH(NOLOCK) 
			where CostCenterID=@CostCenterID AND IsUserDefined=0
		END*/
		select 3 QuickViewTableRemoved

		IF @CostCenterID=16
		BEGIN
			SELECT 'NEW' as 'Link/Delink',SysColumnName,D.ResourceData UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID
			FROM ADM_CostCenterDef a WITH(NOLOCK) 
			JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=a.ResourceID AND D.LanguageID=@LangID
			 WHERE  ((a.IsColumnInUse=1 and a.CostCenterID=16) or a.CostCenterColID between 1101 and 1250 or a.CostCenterColID between 1261 and 1310)
			 AND a.CostCenterColID NOT IN (SELECT COSTCENTERCOLID 
			 FROM ADM_GridViewColumns gc with(nolock)
			 JOIN ADM_GridView g with(nolock) on gc.GridViewID=g.GridViewID)
			 AND (a.COLUMNDATATYPE <>'BIT' OR a.COLUMNDATATYPE IS NULL)
			 UNION
			 SELECT 'NEW' as 'Link/Delink',SysColumnName,D.ResourceData UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID
			 FROM ADM_CostCenterDef a WITH(NOLOCK) 
			 JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=a.ResourceID AND D.LanguageID=@LangID
			 WHERE  IsColumnInUse=1 and CostCenterID =3
			 AND CostCenterColID NOT IN (SELECT COSTCENTERCOLID 
			 FROM ADM_GridViewColumns gc with(nolock) 
			 JOIN ADM_GridView g with(nolock) on gc.GridViewID=g.GridViewID AND g.CostCenterID=16)
			 AND SysColumnName LIKE 'CCNID%' 
			 ORDER BY UserColumnName
		END
		ELSE IF @CostCenterID>=40000 AND @CostCenterID<50000 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID 
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID
			WHERE  IsColumnInUse=1 and CostCenterID=@CostCenterID AND CostCenterColID NOT IN
			(SELECT COSTCENTERCOLID FROM ADM_GridViewColumns a with(nolock) JOIN ADM_GridView b with(nolock) on b.GridViewID=a.GridViewID AND b.COSTCENTERID=@CostCenterID)
			AND (ADM_CostCenterDef.COLUMNDATATYPE <>'BIT' OR ADM_CostCenterDef.COLUMNDATATYPE IS NULL) AND SysColumnName NOT LIKE 'dcNum%'
			AND SysColumnName NOT LIKE 'dcCalcNum%' AND SysColumnName NOT LIKE 'dcCurrID%' AND SysColumnName NOT LIKE 'dcExchRT%'
			ORDER BY ADM_CostCenterDef.UserColumnName
		ELSE IF @CostCenterID=2
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID 
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID
			WHERE  (IsColumnInUse=1 OR SYSCOLUMNNAME LIKE 'AccountGroup') and CostCenterID=@CostCenterID AND CostCenterColID NOT IN
			(SELECT COSTCENTERCOLID FROM ADM_GridViewColumns a with(nolock) JOIN ADM_GridView b with(nolock) on b.GridViewID=a.GridViewID AND b.COSTCENTERID=@CostCenterID)
			AND (ADM_CostCenterDef.COLUMNDATATYPE <>'BIT' OR ADM_CostCenterDef.COLUMNDATATYPE IS NULL  OR SYSCOLUMNNAME LIKE 'IsBillwise' ) 
			UNION ALL
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID 
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID
			WHERE CostCenterID=3 AND SysColumnName IN ('CreatedDate','ModifiedDate')
		ELSE 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID 
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID
			WHERE  IsColumnInUse=1 and CostCenterID=@CostCenterID AND CostCenterColID NOT IN
			(SELECT COSTCENTERCOLID FROM ADM_GridViewColumns a with(nolock) JOIN ADM_GridView b with(nolock) on b.GridViewID=a.GridViewID AND b.COSTCENTERID=@CostCenterID)
			AND (ADM_CostCenterDef.COLUMNDATATYPE <>'BIT' OR ADM_CostCenterDef.COLUMNDATATYPE IS NULL) 
			AND SysTableName<>'REN_QuotationParticulars' AND SysTableName<>'REN_QuotationPayTerms'
			AND SysTableName<>'REN_ContractParticulars' AND SysTableName<>'REN_ContractPayTerms'
			UNION 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ResourceID 
			FROM ADM_CostCenterDef WITH(NOLOCK) 
			WHERE  IsColumnInUse=1 and CostCenterID=@CostCenterID AND SysColumnName='RentAmount'
			UNION ALL
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID 
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID
			WHERE CostCenterID=3 AND @CostCenterID>50000 AND SysColumnName IN ('ModifiedBy','ModifiedDate')
			ORDER BY UserColumnName 
		  
	if(@costcenterid=99 OR @costcenterid=112 or @costcenterid=159 or @costcenterid=23)
	Begin
		if(@costcenterid=99)
		Begin
			SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,'100' as 'ColumnWidth','TEXT' ColumnDataType,0 ResourceID
			FROM ADM_Features WITH(NOLOCK) 
			WHERE  IsEnabled=1  and FeatureID>50000 
			AND FeatureID NOT IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=99))
			union 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,resourcedata UserColumnName,a.CostCenterColID, '100' as 'ColumnWidth',a.ColumnDataType,0 ResourceID
			  from ADM_CostCenterDef a WITH(NOLOCK)
			  			  JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=a.ResourceID AND D.LanguageID=@LangID 		
			  where Costcenterid=99	and  a.CostCenterColID not in (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=99)) order by Usercolumnname 

			SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,g.ColumnWidth,'TEXT' ColumnDataType,0 ResourceID, g.columnorder,g.ColumnType
			FROM ADM_Features  a with(nolock) join ADM_GridViewColumns g with(nolock) on a.FeatureID=g.CostCenterColID and g.GridViewID
			  in (select GridViewID from ADM_GridView with(nolock) where CostCenterID=99)
			WHERE  IsEnabled=1  --and FeatureID>50000 
			AND FeatureID  IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=99))
			union 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,a.CostCenterColID,g.ColumnWidth,a.ColumnDataType,0 ResourceID, g.columnorder,g.ColumnType
			from ADM_CostCenterDef a with(nolock) join ADM_GridViewColumns g with(nolock) on a.CostCenterColID=g.CostCenterColID and g.GridViewID
			  in (select GridViewID from ADM_GridView with(nolock) where CostCenterID=99)
			where Costcenterid=99 and a.costcentercolid in (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=99)) 
			order by g.ColumnOrder


		end
		
		else if(@costcenterid=159)
		Begin
	 		SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,'100' as 'ColumnWidth','TEXT' ColumnDataType,0 ResourceID
			FROM ADM_Features WITH(NOLOCK) 
			WHERE  IsEnabled=1  and FeatureID>50000 
			AND FeatureID NOT IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=159))
			union 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,a.CostCenterColID, '100' as 'ColumnWidth',a.ColumnDataType,0 ResourceID
			  from ADM_CostCenterDef a WITH(NOLOCK)
			  where Costcenterid=159	and  a.CostCenterColID not in (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=159)) order by Usercolumnname
			 


			SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,g.ColumnWidth,'TEXT' ColumnDataType,0 ResourceID, g.columnorder,g.ColumnType
			FROM ADM_Features  a with(nolock) join ADM_GridViewColumns g with(nolock) on a.FeatureID=g.CostCenterColID and g.GridViewID
			  in (select GridViewID from ADM_GridView with(nolock) where CostCenterID=159)
			WHERE  IsEnabled=1  --and FeatureID>50000 
			AND FeatureID  IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=159))
			union 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,a.CostCenterColID,g.ColumnWidth,a.ColumnDataType,0 ResourceID, g.columnorder,g.ColumnType
			from ADM_CostCenterDef a with(nolock) join ADM_GridViewColumns g with(nolock) on a.CostCenterColID=g.CostCenterColID and g.GridViewID
			  in (select GridViewID from ADM_GridView with(nolock) where CostCenterID=159)
			where Costcenterid=159 and a.costcentercolid in (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=159)) 
			order by g.ColumnOrder
		
			 select [ColumnWidth] from  ADM_GridViewColumns b WITH(NOLOCK) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=159)
			and b.CostCenterColID=0 
		 

		end	

		else if @costcenterid=112
		Begin
		SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,'100' as 'ColumnWidth','TEXT' ColumnDataType,0 ResourceID
		FROM ADM_Features WITH(NOLOCK) 
		WHERE  IsEnabled=1  and FeatureID>50000 
		AND FeatureID NOT IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
		SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=112))
		union 
		SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,a.CostCenterColID, '100' as 'ColumnWidth',a.ColumnDataType,0 ResourceID
		from ADM_CostCenterDef a with(nolock)
		where Costcenterid=112	and a.IsColumninUse=1 and  a.CostCenterColID not in (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
		SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=112)) order by Usercolumnname


		SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,g.ColumnWidth,'TEXT' ColumnDataType,0 ResourceID, g.columnorder,g.ColumnType
		FROM ADM_Features  a with(nolock) join ADM_GridViewColumns g with(nolock) on a.FeatureID=g.CostCenterColID and g.GridViewID
		  in (select GridViewID from ADM_GridView with(nolock) where CostCenterID=112)
		WHERE  IsEnabled=1  --and FeatureID>50000 
		AND FeatureID  IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
		SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=112))
		union 
		SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,a.CostCenterColID,g.ColumnWidth,a.ColumnDataType,0 ResourceID, g.columnorder,g.ColumnType
		from ADM_CostCenterDef a with(nolock) join ADM_GridViewColumns g with(nolock) on a.CostCenterColID=g.CostCenterColID and g.GridViewID
		  in (select GridViewID from ADM_GridView with(nolock) where CostCenterID=112)
		where Costcenterid=112 and a.IsColumninUse=1 and  a.costcentercolid in (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
		SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=112)) 
		order by g.ColumnOrder
		--   SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,'200' as 'ColumnWidth',null ColumnDataType,0 ResourceID
		--FROM ADM_Features WITH(NOLOCK) 
		--WHERE  IsEnabled=1  and FeatureID>50000 
		--AND FeatureID NOT IN (SELECT CostCenterColID FROM [ADM_GridViewColumns]  WHERE GRIDVIEWID IN (
		--SELECT GRIDVIEWID FROM [ADM_GridView] WHERE [CostCenterID]=112))


		--SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,'200' as 'ColumnWidth',null ColumnDataType,0 ResourceID
		--FROM ADM_Features WITH(NOLOCK) 
		--WHERE  IsEnabled=1  and FeatureID>50000 
		--AND FeatureID  IN (SELECT CostCenterColID FROM [ADM_GridViewColumns]  WHERE GRIDVIEWID IN (
		--SELECT GRIDVIEWID FROM [ADM_GridView] WHERE [CostCenterID]=112))

		end	 
		else if (@costcenterid=23)
		Begin
			SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,'100' as 'ColumnWidth','TEXT' ColumnDataType,0 ResourceID
			FROM ADM_Features WITH(NOLOCK) 
			WHERE  IsEnabled=1  and FeatureID>50000 
			AND FeatureID NOT IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=23))
			union 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,a.CostCenterColID, '100' as 'ColumnWidth',a.ColumnDataType,0 ResourceID
			  from ADM_CostCenterDef a with(nolock)
			  where Costcenterid=3	and iscolumninuse=1 and syscolumnname not like '%alpha%' and syscolumnname not like '%CCNID%' and   iscolumnuserdefined=0 and  a.CostCenterColID not in (SELECT CostCenterColID FROM [ADM_GridViewColumns]  WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=23)) order by Usercolumnname
 
			SELECT 'NEW' as 'Link/Delink',TableName SysColumnName,Name UserColumnName,FeatureID CostCenterColID,g.ColumnWidth,'TEXT' ColumnDataType,0 ResourceID, g.columnorder,g.ColumnType
			FROM ADM_Features  a WITH(NOLOCK) join ADM_GridViewColumns g with(nolock) on a.FeatureID=g.CostCenterColID and g.GridViewID
			  in (select GridViewID from ADM_GridView with(nolock) where CostCenterID=23)
			WHERE  IsEnabled=1  and FeatureID>50000 
			AND FeatureID  IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=23))
			union 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,a.CostCenterColID,g.ColumnWidth,a.ColumnDataType,0 ResourceID, g.columnorder,g.ColumnType
			from ADM_CostCenterDef a with(nolock) join ADM_GridViewColumns g with(nolock) on a.CostCenterColID=g.CostCenterColID and g.GridViewID
			  in (select GridViewID from ADM_GridView with(nolock) where CostCenterID=23)
			where Costcenterid=3 and iscolumninuse=1 and syscolumnname not like '%alpha%' and syscolumnname not like '%CCNID%' and a.costcentercolid in (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (
			SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=23)) 
			order by g.ColumnOrder
		end	
	end
	else if(@costcenterid=98 or @costcenterid=102)
	 begin
		if(@costcenterid=102)		
			select @FEATUREID=3,@GridViewID=GRIDVIEWID from [ADM_GridView] WITH(NOLOCK) WHERE FEATUREID=102		
		if(@GridViewID=2 or @GridViewID=3 or @GridViewID between 50000 and 50090)
			set @FEATUREID=@GridViewID
		ELSE
			select @FEATUREID=FEATUREID from [ADM_GridView] WITH(NOLOCK) WHERE GRIDVIEWID=@GridViewID
		
		declare @value nvarchar(50),@cc int,@colid bigint
		declare @tab table(colid bigint,name nvarchar(500))
		
		if(@FEATUREID=3)
		BEGIN
			if (exists(select name from adm_globalpreferences with(nolock)
			where name='EnableLocationWise' and value='True') and exists(select name from adm_globalpreferences with(nolock)
			where name='Location Stock' and value='True') )
			begin
				insert into @tab
				select c.CostCenterColID,case when iscolumninuse=1 then resourcedata else (select name from ADM_Features with(nolock) where FeatureID=50002) end 
				FROM ADM_CostCenterDef c WITH(NOLOCK) 
				JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=c.ResourceID   AND D.LanguageID=@LangID
				where c.CostCenterColID=14391
			end
			if (exists(select name from adm_globalpreferences with(nolock)
			where name='EnableDivisionWise' and value='True') and exists(select name from adm_globalpreferences with(nolock)
			where name='Division Stock' and value='True') )
			begin
				 insert into @tab
				 select c.CostCenterColID,case when iscolumninuse=1 then resourcedata else (select name from ADM_Features with(nolock) where FeatureID=50001) end 
				FROM ADM_CostCenterDef c WITH(NOLOCK) 
				JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=c.ResourceID   AND D.LanguageID=@LangID
				where c.CostCenterColID=14390
			end
		
			select @value=value from adm_globalpreferences with(nolock)
			where name='Maintain Dimensionwise stock' 

			if(@value is not null and @value<>'')
			begin
				set @cc=CONVERT(int,@value) 
				 select @colid=CostCenterColID FROM ADM_CostCenterDef with(nolock)
				where costcenterid=3 and SysColumnName ='CCNID'+convert(nvarchar,(@cc-50000))

				insert into @tab
				select c.CostCenterColID,case when iscolumninuse=1 then resourcedata else (select name from ADM_Features with(nolock) where FeatureID=@cc) end 
				FROM ADM_CostCenterDef c WITH(NOLOCK) 
				JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=c.ResourceID   AND D.LanguageID=@LangID
				where c.CostCenterColID=@colid
			end
		END
		
		if(@FEATUREID=2 AND @costcenterid=98)
		BEGIN
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID
			FROM ADM_CostCenterDef WITH(NOLOCK)
			JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID   AND D.LanguageID=@LangID
			WHERE  IsColumnInUse=1 and (ADM_CostCenterDef.CostCenterID=@FEATUREID or (@FEATUREID=3 and CostCenterColID=23089)) 
			AND CostCenterColID NOT IN (SELECT COSTCENTERCOLID FROM ADM_GridViewColumns with(nolock) where GRIDVIEWID=@GridViewID and ColumnType=1  )
			union all 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,'Address_'+UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID
			FROM ADM_CostCenterDef WITH(NOLOCK) 
			JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID 		
			WHERE  IsColumnInUse=1 and IsColumnUserDefined=0 and ADM_CostCenterDef.CostCenterID=110 and ColumnCostCenterID=0		
			union all 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,t.name,CostCenterColID,'200' as 'ColumnWidth',ResourceID
			FROM ADM_CostCenterDef c WITH(NOLOCK)
			join @tab t on c.CostCenterColID=t.colid
			order by UserColumnName
		END
		ELSE
		BEGIN
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID
			FROM ADM_CostCenterDef WITH(NOLOCK)
			JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID   AND D.LanguageID=@LangID
			WHERE  IsColumnInUse=1 and (ADM_CostCenterDef.CostCenterID=@FEATUREID or (@FEATUREID=3 and CostCenterColID=23089)) 
			AND CostCenterColID NOT IN (SELECT COSTCENTERCOLID FROM ADM_GridViewColumns with(nolock) where GRIDVIEWID=@GridViewID and ColumnType=1  )
			union all 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,t.name,CostCenterColID,'200' as 'ColumnWidth',ResourceID
			FROM ADM_CostCenterDef c WITH(NOLOCK)
			join @tab t on c.CostCenterColID=t.colid
			order by UserColumnName
		END
		
		SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,D.ResourceID
		FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID 		
		WHERE  IsColumnInUse=1 and (ADM_CostCenterDef.CostCenterID=@FEATUREID or (@FEATUREID=3 and CostCenterColID=23089)) 
		AND (ADM_CostCenterDef.COLUMNDATATYPE IS NULL)				
		union all 
		SELECT 'NEW' as 'Link/Delink',SysColumnName,t.name,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,ResourceID
		FROM ADM_CostCenterDef c WITH(NOLOCK)
		join @tab t on c.CostCenterColID=t.colid
		order by CostCenterColID
		
		SELECT distinct 'NEW' as 'Link/Delink',D.Resourceid,case when t.name is null then ResourceData else t.name end as ResourceData,case when t.name is null then ResourceData else t.name end as UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,c.ColumnDataType,
		a.GridViewID,A.CostCenterColID,a.description,a.ColumnType  
		from ADM_GridViewColumns a WITH(NOLOCK) 			
		left join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=a.CostCenterColID
		left join @tab t on c.CostCenterColID=t.colid
		left JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
		where GRIDVIEWID=@GridViewID and a.CostCenterColID!=0 and charindex('~',a.Description,1)=0
		UNION ALL
		SELECT distinct 'NEW' as 'Link/Delink',a.CostCenterColID,F.Name ResourceData,F.Name as UserColumnName,'' SysColumnName,a.ColumnOrder,ColumnWidth,'',
		a.GridViewID,A.CostCenterColID,a.description,a.ColumnType  
		from ADM_GridViewColumns a WITH(NOLOCK) 			
		left join ADM_Features F WITH(NOLOCK) on F.FeatureID=abs(a.CostCenterColID)
		where GRIDVIEWID=@GridViewID and charindex('~',a.Description,1)>0			
		ORDER BY ColumnOrder
		
		if(@FEATUREID=2 AND @costcenterid=98)
		BEGIN	
			SELECT D.Resourceid,  ResourceData  ,  UserColumnName,SysColumnName,c.ColumnDataType,c.CostCenterColID  
			from  ADM_CostCenterDef c with(nolock)
			JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where c.CostCenterID=@FEATUREID and IsColumnInUse=1 
			UNION ALL
			SELECT D.Resourceid,  'Address_'+ResourceData  ,  UserColumnName,SysColumnName,c.ColumnDataType,c.CostCenterColID  
			from  ADM_CostCenterDef c with(nolock)
			JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where c.CostCenterID=110 and IsColumnInUse=1 
		END
		ELSE
		BEGIN	
			SELECT D.Resourceid,  ResourceData  ,  UserColumnName,SysColumnName,c.ColumnDataType,c.CostCenterColID  
			from  ADM_CostCenterDef c with(nolock)
			JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where c.CostCenterID=@FEATUREID and IsColumnInUse=1 
		END
		
		select [ColumnWidth] from  ADM_GridViewColumns b WITH(NOLOCK) where GRIDVIEWID=@GridViewID
		and b.CostCenterColID=0 

	 end
	else if (@costcenterid=161)
	 begin  
		 SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID
		 FROM ADM_CostCenterDef WITH(NOLOCK)
		 JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID   AND D.LanguageID=@LangID
		 WHERE  IsColumnInUse=1 and (ADM_CostCenterDef.CostCenterID=73) 
		 AND CostCenterColID NOT IN 
		 (SELECT COSTCENTERCOLID FROM ADM_GridViewColumns a with(nolock) JOIN ADM_GridView b with(nolock) on b.GridViewID=a.GridViewID and b.featureid=@costcenterid where a.ColumnType=1  )
		 AND (ADM_CostCenterDef.COLUMNDATATYPE <>'BIT' OR ADM_CostCenterDef.COLUMNDATATYPE IS NULL)
		union all
		SELECT 'NEW' as 'Link/Delink',SysColumnName,D.ResourceData UserColumnName,CostCenterColID,'200' as 'ColumnWidth',D.ResourceID
		FROM ADM_CostCenterDef a WITH(NOLOCK) 
		JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=a.ResourceID AND D.LanguageID=@LangID
		WHERE  IsColumnInUse=1 and CostCenterID =40997    AND CostCenterColID NOT IN 
		(SELECT COSTCENTERCOLID FROM ADM_GridViewColumns GC with(nolock) JOIN ADM_GRIDVIEW  G with(nolock) ON (GC.GRIDVIEWID=G.GRIDVIEWID OR  G.GRIDVIEWID=@GridViewID) AND G.COSTCENTERID=161 
		where   ColumnType=1  ) 
		and  SysColumnName LIKE '%CCNID%' 
		ORDER BY UserColumnName
		 
		 SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,D.ResourceID
		 FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID 		
		 WHERE  IsColumnInUse=1 and (ADM_CostCenterDef.CostCenterID=73)
		 AND (ADM_CostCenterDef.COLUMNDATATYPE <>'BIT' OR ADM_CostCenterDef.COLUMNDATATYPE IS NULL)				
		   
		SELECT distinct 'NEW' as 'Link/Delink',D.Resourceid, ResourceData  as ResourceData, ResourceData  as UserColumnName,SysColumnName,a.ColumnOrder,ColumnWidth,c.ColumnDataType,
		a.GridViewID,A.CostCenterColID,a.description,a.ColumnType  
		from ADM_GridViewColumns a WITH(NOLOCK) 
		inner join ADM_GridView b WITH(NOLOCK) on a.GridViewID=b.GridViewID
		left join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=a.CostCenterColID 
		left JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
		where b.featureid=@costcenterid and a.CostCenterColID!=0 and charindex('~',a.Description,1)=0
		 
			
			SELECT D.Resourceid,  ResourceData  ,  UserColumnName,SysColumnName,c.ColumnDataType,
			 c.CostCenterColID  
			from  ADM_CostCenterDef c with(nolock)
			JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=C.ResourceID AND D.LanguageID=@LangID
			where c.CostCenterID=73 and IsColumnInUse=1 
		 
		select [ColumnWidth]
		from  ADM_GridViewColumns b WITH(NOLOCK) where 
		  GRIDVIEWID IN (SELECT GRIDVIEWID FROM [ADM_GridView] WITH(NOLOCK) WHERE FeatureID=161)
		and b.CostCenterColID=0 

	 end 
	 else if (@costcenterid=16)
	 BEGIN
	 	SELECT 'NEW' as 'Link/Delink',SysColumnName,D.ResourceData UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,D.ResourceID
		FROM ADM_CostCenterDef a WITH(NOLOCK) 		
		JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=a.ResourceID AND D.LanguageID=@LangID 		
		WHERE  ((IsColumnInUse=1 and a.CostCenterID=16 ) or a.CostCenterColID between 1101 and 1250 or a.CostCenterColID between 1261 and 1310)
		AND (a.COLUMNDATATYPE <>'BIT' OR a.COLUMNDATATYPE IS NULL) 
		ORDER BY UserColumnName

	 END
	 ELSE
	 begin
		IF @CostCenterID=2			
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,D.ResourceID
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID 		
			WHERE  (IsColumnInUse=1 or syscolumnname='AccountGroup') and ADM_CostCenterDef.CostCenterID IN (@CostCenterID  )
			AND (ADM_CostCenterDef.COLUMNDATATYPE <>'BIT' OR ADM_CostCenterDef.COLUMNDATATYPE IS NULL) 
			UNION ALL
			SELECT 'NEW' as 'Link/Delink',SysColumnName,'Address_'+UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,D.ResourceID
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID 		
			WHERE  IsColumnInUse=1 and IsColumnUserDefined=0 and ADM_CostCenterDef.CostCenterID=110 and ColumnCostCenterID=0
			ORDER BY ADM_CostCenterDef.UserColumnName
		ELSE IF @CostCenterID>=40000 AND @CostCenterID<50000 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,D.ResourceID
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID 		
			WHERE  IsColumnInUse=1 and ADM_CostCenterDef.CostCenterID=@CostCenterID  
			AND (ADM_CostCenterDef.COLUMNDATATYPE <>'BIT' OR ADM_CostCenterDef.COLUMNDATATYPE IS NULL) AND SysColumnName NOT LIKE 'dcNum%'
			AND SysColumnName NOT LIKE 'dcCalcNum%' AND SysColumnName NOT LIKE 'dcCurrID%' AND SysColumnName NOT LIKE 'dcExchRT%'ORDER BY ADM_CostCenterDef.UserColumnName
		ELSE
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,D.ResourceID
			FROM ADM_CostCenterDef WITH(NOLOCK) JOIN COM_LanguageResources D with(nolock) ON D.ResourceID=ADM_CostCenterDef.ResourceID AND D.LanguageID=@LangID 		
			WHERE  IsColumnInUse=1 and ADM_CostCenterDef.CostCenterID=@CostCenterID  
			AND SysTableName<>'REN_QuotationParticulars' AND SysTableName<>'REN_QuotationPayTerms'
			AND SysTableName<>'REN_ContractParticulars' AND SysTableName<>'REN_ContractPayTerms'
			AND (ADM_CostCenterDef.COLUMNDATATYPE <>'BIT' OR ADM_CostCenterDef.COLUMNDATATYPE IS NULL) 
			UNION 
			SELECT 'NEW' as 'Link/Delink',SysColumnName,UserColumnName,CostCenterColID,'200' as 'ColumnWidth',ColumnDataType,ResourceID 
			FROM ADM_CostCenterDef WITH(NOLOCK) 
			WHERE  IsColumnInUse=1 and CostCenterID=@CostCenterID AND SysColumnName='RentAmount'
			ORDER BY UserColumnName 
	end
	
	
  declare @CCColID bigint
  select @CCColID=CostCenterColID from ADM_CostCenterDef with(nolock)
  where SysColumnName like 'Status%' and costcenterid=@CostCenterID
  order by CostCenterColID desc
  select StatusID,Status,@CCColID as CostCenterColID from com_Status with(nolock) where costcenterid=@CostCenterID
	
	SELECT NodeID RoleID,ParentNodeID GridViewID FROM COM_CostCenterCostCenterMap a WITH(NOLOCK) 
	join ADM_GridView b WITH(NOLOCK) on a.ParentNodeID=b.GridViewID 
	WHERE ParentCostCenterID=26 AND a.CostCenterID=6 AND  b.CostCenterID=@CostCenterID
	
			
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
