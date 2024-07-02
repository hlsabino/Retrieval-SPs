USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetProductSearchFields]
	@GridViewID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON;   

	declare @value nvarchar(50),@cc int,@colid INT,@FeatureID INT,@ColWidth float,@filter nvarchar(max)
	
	if(@GridViewID=161)
	begin
		SET @FeatureID=161
		set @GridViewID= (select top 1  gridviewid from adm_gridview WITH(NOLOCK) where featureid=161)
	end
	else
		SELECT @FeatureID=FeatureID FROM [ADM_GridView] WITH(NOLOCK) WHERE GRIDVIEWID=@GridViewID
   
   if(@FeatureID=3)
   BEGIN
			declare @tab table(colid INT,name nvarchar(500))
			if (exists(select name from adm_globalpreferences WITH(NOLOCK)
			where name='EnableLocationWise' and value='True') and exists(select name from adm_globalpreferences WITH(NOLOCK)
			where name='Location Stock' and value='True') )
			begin
				insert into @tab
				select c.CostCenterColID,case when iscolumninuse=1 then resourcedata else (select name from ADM_Features WITH(NOLOCK) where FeatureID=50002) end 
				FROM ADM_CostCenterDef c WITH(NOLOCK) 
				JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=c.ResourceID   AND D.LanguageID=1
				where c.CostCenterColID=14391
			end
			if (exists(select name from adm_globalpreferences WITH(NOLOCK)
			where name='EnableDivisionWise' and value='True') and exists(select name from adm_globalpreferences WITH(NOLOCK)
			where name='Division Stock' and value='True') )
			begin
				 insert into @tab
				 select c.CostCenterColID,case when iscolumninuse=1 then resourcedata else (select name from ADM_Features WITH(NOLOCK) where FeatureID=50001) end 
				FROM ADM_CostCenterDef c WITH(NOLOCK) 
				JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=c.ResourceID   AND D.LanguageID=1
				where c.CostCenterColID=14390
			end

			select @value=value from adm_globalpreferences WITH(NOLOCK)
			where name='Maintain Dimensionwise stock' 

			if(@value is not null and @value<>'')
			begin
				set @cc=CONVERT(int,@value) 
				 select @colid=CostCenterColID FROM ADM_CostCenterDef WITH(NOLOCK)
				where costcenterid=3 and SysColumnName ='CCNID'+convert(nvarchar,(@cc-50000))

				insert into @tab
				select c.CostCenterColID,case when iscolumninuse=1 then resourcedata else (select name from ADM_Features where FeatureID=@cc) end 
				FROM ADM_CostCenterDef c WITH(NOLOCK) 
				JOIN COM_LanguageResources D WITH(NOLOCK) ON D.ResourceID=c.ResourceID   AND D.LanguageID=1
				where c.CostCenterColID=@colid
			end
   END
    
    select b.costcentercolid,isnull(ColumnCostCenterID, -b.costcentercolid) ColumnCostCenterID,ColumnCCListViewTypeID,case when t.name is null then ResourceData else t.name end as ResourceData,SysColumnName,ColumnDataType,UserColumnType,isnull(a.iscolumninuse,1) iscolumninuse,b.description,b.columntype,b.[ColumnWidth],b.columnorder,a.dependanton,a.dependancy
	from ADM_GridViewColumns b WITH(NOLOCK)
	inner join ADM_CostCenterDef a WITH(NOLOCK) on b.CostCenterColID=a.CostCenterColID
	left join com_languageresources c WITH(NOLOCK) on c.Resourceid=a.resourceid and c.LanguageID=1
    left join @tab t on a.CostCenterColID=t.colid
    WHERE GRIDVIEWID=@GridViewID
    union
    select b.costcentercolid,-b.costcentercolid ColumnCostCenterID,1 ColumnCCListViewTypeID,a.Name ResourceData,null SysColumnName,null ColumnDataType,'LISTBOX' UserColumnType,'True' iscolumninuse,b.description,b.columntype,b.[ColumnWidth],b.columnorder,'',''
	from ADM_GridViewColumns b WITH(NOLOCK)
	left join ADM_Features a WITH(NOLOCK) on (-b.costcentercolid)=a.FeatureID
    WHERE GRIDVIEWID=@GridViewID and b.costcentercolid<0 and charindex('~',b.Description,1)=0
    union
    select b.costcentercolid,abs(b.costcentercolid) ColumnCostCenterID,1 ColumnCCListViewTypeID,a.Name ResourceData,null SysColumnName,null ColumnDataType,'LISTBOX' UserColumnType,'True' iscolumninuse,b.description,b.columntype,b.[ColumnWidth],b.columnorder,'',''
	from ADM_GridViewColumns b WITH(NOLOCK)
	left join ADM_Features a WITH(NOLOCK) on abs(b.costcentercolid)=a.FeatureID
    WHERE GRIDVIEWID=@GridViewID and charindex('~',b.Description,1)>0
    order by columntype,columnorder
    
	select @ColWidth=[ColumnWidth] from  ADM_GridViewColumns b WITH(NOLOCK) 
	where GRIDVIEWID=@GridViewID and b.CostCenterColID=0 
	
	SELECT @filter=SearchFilter FROM [ADM_GridView] WITH(NOLOCK) WHERE GRIDVIEWID=@GridViewID
	
	select @ColWidth [ColumnWidth],@filter Filter
	
 
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

SET NOCOUNT OFF        
RETURN -999         
END CATCH
GO
