USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetFeaturesDetails]
	@CostCenterID [int],
	@Name [nvarchar](200),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY  
SET NOCOUNT ON;
   
   DECLARE @IsInventory bit=0, @VoucherType bit=0,@documenttype int
	if(@CostCenterID >40000 and @CostCenterID<50000)
		select @IsInventory=isinventory, @documenttype=documenttype from adm_documenttypes with(nolock)
		where costcenterid=@CostCenterID
		
	if (@documenttype = 1 or @documenttype = 27 or @documenttype = 26 or @documenttype = 25 or @documenttype = 2 or @documenttype = 34 or @documenttype = 6 
		or @documenttype = 3 or @documenttype = 4	or @documenttype = 13)
		set @VoucherType=1
	
	if(@CostCenterID=99)
	BEGIN
		SELECT a.FeatureID CostCenterColID,Name ResourceData ,Name SyscolumnName,'TEXT' ColumnDataType, 0 ColumnCostCenterID, g.ColumnOrder, 'False' IsEditable,0 as IsMandatory                        
		FROM ADM_Features a with(nolock)
		join ADM_GridViewColumns g with(nolock) on a.FeatureID=g.CostCenterColID
		join adm_gridview gr with(nolock) on gr.GridViewID=g.GridViewID and gr.costcenterid=99
		WHERE  IsEnabled=1  and a.FeatureID>50000
		union
		select a.CostCenterColID,  UserColumnName ResourceData, SyscolumnName, ColumnDataType, 0 ColumnCostCenterID, g.ColumnOrder, A.IsEditable,a.IsMandatory                        
		from adm_costcenterdef a with(nolock) 
		join ADM_GridViewColumns g with(nolock) on a.CostCenterColID=g.CostCenterColID
		join adm_gridview gr with(nolock) on gr.GridViewID=g.GridViewID and gr.costcenterid=99                    
		where a.CostCenterID=99                     
		order by g.ColumnOrder      
	END
	ELSE IF @CostCenterID=40 OR @CostCenterID=101  OR @CostCenterID=45 or @CostCenterID=153 or @CostCenterID=151 --PRICE CHART FIELDS OR TAX CHART FIELDS
	BEGIN
		IF @CostCenterID=40 and @Name='Dimension Wise Price Chart'
		BEGIN
			select CostCenterColID,SysColumnName,CASE WHEN C.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,l.ResourceData UserColumnName,ColumnDataType,0 ColumnCostCenterID,C.IsMandatory
			FROM ADM_CostCenterDef C with(nolock)
			join COM_LanguageResources l with(nolock) on C.ResourceID=l.ResourceID and LanguageID= @LangID
			WHERE CostCenterID=40 AND (SysColumnName LIKE 'PurchaseRate%' OR SysColumnName LIKE 'SellingRate%'
			OR SysColumnName LIKE 'ReorderLevel%' OR SysColumnName LIKE 'ReorderQty%'  OR SysColumnName LIKE 'PriceType%')		
			UNION
			SELECT FeatureID , PrimaryKey ,Name,Name,'INT', FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID IN (2,3,11)-- OR FeatureID>50000
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,(FeatureID-50000)) ,Name,Name,'INT', FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1
			UNION
			SELECT -FeatureID , 'CC'+CONVERT(NVARCHAR,(FeatureID-50000)) ,Name+'_Column',Name+'_Column','INT', FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1
			UNION
			SELECT -1,'ProfileName','ProfileName','ProfileName','String',0,0
			UNION
			SELECT -2,'WEF','WEF','WEF','datetime',0,0
			UNION
			SELECT -3,'TillDate','TillDate','TillDate','datetime',0,0
			UNION
			SELECT -4,'ValueFor','ValueFor','ValueFor','String',0,0
			ORDER BY CostCenterColID
		END 
		ELSE IF @CostCenterID=40
		BEGIN
			select CostCenterColID,SysColumnName,CASE WHEN C.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,ColumnDataType,0 ColumnCostCenterID,C.IsMandatory
			FROM ADM_CostCenterDef C with(nolock)
			join COM_LanguageResources l with(nolock) on C.ResourceID=l.ResourceID and LanguageID= @LangID
			WHERE CostCenterID=40 AND (SysColumnName LIKE 'PurchaseRate%' OR SysColumnName LIKE 'SellingRate%'
			OR SysColumnName LIKE 'ReorderLevel%' OR SysColumnName LIKE 'ReorderQty%'  OR SysColumnName LIKE 'PriceType%')		
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID IN (2,3,11,12)-- OR FeatureID>50000
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1
			UNION
			SELECT -1,'ProfileName','ProfileName',NULL,0,0
			UNION
			SELECT -2,'WEF','WEF','datetime',0,0
			UNION
			SELECT -3,'TillDate','TillDate','datetime',0,0
			ORDER BY CostCenterColID
		END
		ELSE IF @CostCenterID=151 and @Name='Schemes & Discounts BasedOn Unique Dimension'
		BEGIN 
			select CostCenterColID,SysColumnName,CASE WHEN C.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData, UserColumnName,ColumnDataType,0 ColumnCostCenterID,C.IsMandatory
			FROM ADM_CostCenterDef C with(nolock)
			join COM_LanguageResources l with(nolock) on C.ResourceID=l.ResourceID and LanguageID= @LangID
			WHERE CostCenterID=151 AND (SysColumnName LIKE 'From%' OR SysColumnName LIKE 'To%'
			OR SysColumnName LIKE 'Percentage%' OR SysColumnName LIKE 'Quantity'  OR SysColumnName LIKE 'Value' OR SysColumnName LIKE 'IsQtyPercent')		
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID IN (2,3)-- OR FeatureID>50000
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1
			UNION
			SELECT -1,'ProfileName','ProfileName',NULL,NULL,0,0
			UNION
			SELECT -2,'RowID','RowID',NULL,NULL,0,0
			UNION
			SELECT -3,'FreeProduct','FreeProduct',NULL,NULL,3,0
			UNION
			SELECT -FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,'Free'+Name Name,NULL,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1
			ORDER BY CostCenterColID
		END  
		ELSE IF @CostCenterID=151
		BEGIN 
			select CostCenterColID,SysColumnName,CASE WHEN C.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData, UserColumnName,ColumnDataType,0 ColumnCostCenterID,C.IsMandatory
			FROM ADM_CostCenterDef C with(nolock)
			join COM_LanguageResources l with(nolock) on C.ResourceID=l.ResourceID and LanguageID= @LangID
			WHERE CostCenterID=151 AND (SysColumnName LIKE 'From%' OR SysColumnName LIKE 'To%'
			OR SysColumnName LIKE 'Percentage%' OR SysColumnName LIKE 'Quantity'  OR SysColumnName LIKE 'Value' OR SysColumnName LIKE 'IsQtyPercent'
			OR SysColumnName LIKE 'Status%')		
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID IN (2,3)-- OR FeatureID>50000
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1
			UNION
			SELECT -1,'ProfileName','ProfileName',NULL,NULL,0,0
			UNION
			SELECT -2,'RowID','RowID',NULL,NULL,0,0
			UNION
			SELECT -3,'FreeProduct','FreeProduct',NULL,NULL,3,0
			ORDER BY CostCenterColID
		END 
		ELSE IF @CostCenterID=153
		BEGIN 
			SELECT FeatureID CostCenterColID, 'CC'+CONVERT(NVARCHAR,FeatureID) SysColumnName ,Name ResourceData,NULL ColumnDataType, FeatureID ColumnCostCenterID,0 as IsMandatory 
			FROM ADM_Features with(nolock) 
			WHERE FeatureID IN (2,3)-- OR FeatureID>50000
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1
			UNION
			SELECT -10,'ProfileName','ProfileName','TEXT',0 ,0
			UNION
			SELECT -FeatureID CostCenterColID, 'BasedCC'+CONVERT(NVARCHAR,FeatureID) SysColumnName ,'Based on '+Name ResourceData,'BIT' ColumnDataType, 0 ColumnCostCenterID,0 
			FROM ADM_Features with(nolock) 
			WHERE FeatureID IN (2,3)  OR FeatureID>50000 AND IsEnabled=1  
			ORDER BY CostCenterColID
		END 
		ELSE IF @CostCenterID=101
		BEGIN
			select CostCenterColID,SysColumnName,CASE WHEN C.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,ColumnDataType ,0 ColumnCostCenterID,C.IsMandatory
			FROM ADM_CostCenterDef C with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on C.ResourceID=l.ResourceID and LanguageID= @LangID
			WHERE CostCenterID=@CostCenterID  AND SysColumnName<>'' and
				(((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) 
				AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)      
				and C.costcentercolid not in (SELECT MAX([CostCenterColID])
				  FROM [ADM_CostCenterDef] with(nolock) where Columncostcenterid is not null and Columncostcenterid =2
				  GROUP BY [CostCenterID],[SysColumnName]
				  HAVING COUNT(*)>1 AND [CostCenterID]> 40000 AND [CostCenterID]< 50000)
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID IN (2,3,11)-- OR FeatureID>50000
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1	
			ORDER BY CostCenterColID
		END
		ELSE IF @CostCenterID=45
		BEGIN
			select CostCenterColID,SysColumnName,CASE WHEN C.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,ColumnDataType , ColumnCostCenterID,C.IsMandatory
			FROM ADM_CostCenterDef C with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on C.ResourceID=l.ResourceID and LanguageID= 1
			WHERE CostCenterID=45  AND SysColumnName<>'' and
			(((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) 
			AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)      
			and C.costcentercolid not in (SELECT MAX([CostCenterColID])
			  FROM [ADM_CostCenterDef] with(nolock) where Columncostcenterid is not null and Columncostcenterid =2
			  GROUP BY [CostCenterID],[SysColumnName]
			  HAVING COUNT(*)>1 AND [CostCenterID]> 40000 AND [CostCenterID]< 50000) 
			UNION
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID IN (2,3,11)-- OR FeatureID>50000
			UNION 
			SELECT FeatureID , 'CC'+CONVERT(NVARCHAR,FeatureID) ,Name,NULL, FeatureID,0 FROM ADM_Features with(nolock) 
			WHERE FeatureID>50000 AND IsEnabled=1	
			ORDER BY CostCenterColID
		END
	END
	ELSE IF @CostCenterID=114 
	BEGIN 
		select CostCenterColID,SysColumnName,CASE WHEN C.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,l.ResourceData UserColumnName,ColumnDataType,ColumnCostCenterID,C.IsMandatory
		FROM ADM_CostCenterDef C with(nolock)
		join COM_LanguageResources l with(nolock) on C.ResourceID=l.ResourceID and LanguageID= @LangID
		WHERE CostCenterID=@CostCenterID AND C.IsColumnInUse=1	
		UNION
		SELECT 7,'CreatedBy','UserName','UserName','LISTBOX',0,0
	END
	ELSE if (@CostCenterID=2 and @Name='Account Dimension wise Cr/Dr Limits')
	BEGIN 
		declare @LocWise bit,@DivWise bit,@UseCur bit,@DimWise int
		
		select @LocWise=value from adm_globalpreferences with(nolock) where name='EnableLocationWise'
		if @LocWise=1
			select @LocWise=value from adm_globalpreferences with(nolock) where name='LW CreditDebit'
		
		select @DivWise=value from adm_globalpreferences with(nolock) where name='EnableDivisionWise'
		if @DivWise=1
			select @DivWise=value from adm_globalpreferences with(nolock) where name='DW CreditDebit'
		
		select @DimWise=isnull(value,0) from adm_globalpreferences with(nolock) where name='DimWiseCreditDebit'
		select @UseCur=value from com_costcenterpreferences with(nolock) where Name='UseCurrencyDbCr' and costcenterid=2
		
		
		SELECT  a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		
		CASE WHEN SysColumnName='CCNID'+convert(nvarchar,(@DimWise-50000)) THEN 'Dimension' ELSE  SysColumnName END SysColumnName,
		
		CASE WHEN SysColumnName='CCNID1' THEN 'Division' WHEN SysColumnName='CCNID2' THEN 'Location'
		WHEN SysColumnName='CCNID'+convert(nvarchar,(@DimWise-50000)) THEN (select Name from adm_features with(nolock) where featureid=ColumnCostCenterID) ELSE  l.ResourceData END ResourceData,
		IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
 		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID=@LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=2 AND (SysColumnName in ('AccountCode','AccountName','CreditDays','CreditLimit','DebitDays','DebitLimit')
		or (SysColumnName='CCNID2' and @LocWise=1) or (SysColumnName='CCNID1' and @DivWise=1)
		or (SysColumnName='Currency' and @UseCur=1) or (@DimWise>0 and SysColumnName='CCNID'+convert(nvarchar,(@DimWise-50000))))    
	END 
	ELSE if (@CostCenterID=2 and @Name='Account Report Template')
	BEGIN  
		declare @rptid INT ,@tempsql nvarchar(500)
		select @rptid=CONVERT(INT,value) from ADM_GlobalPreferences with(nolock) where Name='Report Template Dimension'
	
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,a.IsMandatory
		FROM ADM_COSTCENTERDEF a  with(nolock)
 		join dbo.COM_LanguageResources l  with(nolock) on a.ResourceID=l.ResourceID and LanguageID= 1
		LEFT JOIN ADM_DocumentDef DD  with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=2 AND (SysColumnName like 'AccountCode' 
		or SysColumnName like 'AccountName')   
		union  
		select -100,2,'Account',null,'ACC_Accounts','Template',@rptid,1,'TemplateNodeID','Template',1,0,'String',null,null,null,null,null,null,0,'',0
		union 
		select -101,2,'Account',null,'ACC_Accounts','Positive',@rptid,1,'DrNodeID','Positive',1,0,'String',null,null,null,null,null,null,0,'',0
		union 
		select -102,2,'Account',null,'ACC_Accounts','Negative',@rptid,1,'CrNodeID','Negative',1,0,'String',null,null,null,null,null,null,0,'',0
		union all
		select -103,2,'Account',null,'ACC_Accounts','W.E.F',0,1,'RTDate','W.E.F',1,0,'DATE',null,null,null,null,null,null,0,'',0
		union all 
		select -104,2,'Account',null,'ACC_Accounts','Group',0,1,'RTGroup','Group',1,0,'String',null,null,null,null,null,null,0,'',0
		
		if(@rptid>0)
		begin
			set @tempsql= 'select NodeID, Name, Code, Depth, ParentID, IsGroup, lft, rgt from '+(select tablename from ADM_Features with(nolock) where FeatureID=@rptid)+'  with(nolock)' 
			exec (@tempsql)  
		end
	END
	ELSE if (@CostCenterID=2 and @Name='Account Contacts')
	BEGIN 
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=65 AND a.IsColumnInUse=1 and NOT (a.ColumnCostCenterID=83 AND a.SysColumnName='FeaturePK')
		order by UserColumnName
	END
	ELSE if (@CostCenterID=2 and @Name='Account Address')
	BEGIN 
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=110 AND a.IsColumnInUse=1 
		UNION
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=2 AND a.SysColumnName IN ('AccountCode','AccountName')
		UNION
		SELECT -55,110, 'ADDRESS',a.UserDefaultValue, 'COM_ADDRESS', a.UserColumnName,a.ColumnCostCenterID,a.ColumnCCListViewTypeID, 
		a.SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,'1',ColumnDataType,
		0,0,NULL,0,0,0 ,0, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_CostCenterDef a		
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		WHERE SysColumnName='IsDefault' AND CostCenterID=3
		order by UserColumnName
	END
	ELSE if (@CostCenterID=3 and @Name='Products Wise Bins')
	BEGIN
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=3 AND syscolumnname in ('ProductCode','ProductName','BinDimension','DimesionWiseBin','Capacity','IsDefault','StatusID') 
	END
	ELSE if (@CostCenterID=3 and @Name='Products With Substitutes')
	BEGIN
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=3 AND syscolumnname in ('ProductCode','ProductName') 
		UNION ALL	
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=23 AND syscolumnname in ('SubstituteGroupName')		
		UNION ALL  
		select -255,3,'Product',null,'INV_Product','SubstituteProduct',3,3,'SubstituteProduct','Substitute Product',1,0,'String',null,null,null,null,null,null,0,'',0,0		
		UNION ALL  
		select -1,3,'Product',null,'INV_Product','SNO',0,0,'SNO','SNO',1,0,'String',null,null,null,null,null,null,0,'',0,0
	END
	ELSE if (@CostCenterID=3 and @Name='Products With Multiple UOM Barcode')
	BEGIN
	 
		DECLARE @BarcodeDimension INT
		SELECT @BarcodeDimension=ISNULL(Value,0) FROM COM_CostcenterPreferences WITH(NOLOCK) WHERE CostcenterID=3 AND Name='BarcodeDimension'
	 
		SELECT a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=3 AND syscolumnname in ('ProductCode','ProductName') 
		UNION
		SELECT -19,3, 'Product','', 'INV_ProductBarcode','Base_Name',0,0,'Base_Name','Base_Name',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		UNION
		SELECT -20,3, 'Product','', 'INV_ProductBarcode','Base_Conversion',0,0,'Base_Conversion','Base_Conversion',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		UNION
		SELECT -21,3, 'Product','', 'INV_ProductBarcode','Conversion_UnitName',0,0,'Conversion_UnitName','Conversion_UnitName',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		UNION
		SELECT -22,3, 'Product','', 'INV_ProductBarcode','Conversion_UnitValue',0,0,'Conversion_UnitValue','Conversion_UnitValue',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		UNION
		SELECT -29,3, 'Product','', 'INV_ProductBarcode','UOM_Barcode',@BarcodeDimension,0,'UOM_Barcode','UOM_Barcode',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		UNION
		SELECT -30,3, 'Product','', 'INV_ProductBarcode','Base_Barcode',@BarcodeDimension,0,'Base_Barcode','Base_Barcode',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
	
	END
	ELSE if (@CostCenterID=92 and @Name='Property Particulars')
	BEGIN
	
		select @documenttype=value from ADM_GlobalPreferences WITH(NOLOCK)
		where Name='DepositLinkDimension'
	
		SELECT a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,
		CASE WHEN SysColumnName='ParticularID' THEN @documenttype ELSE ColumnCostCenterID END ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		NULL DebitAccount,NULL CreditAccount,NULL Formula,NULL PostingType,NULL RoundOff,NULL IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		WHERE a.CostcenterID=93 and a.SysTableName='REN_Particulars'
		UNION
		SELECT -1,93, 'Units',NULL, 'REN_Particulars','PropertyID',92,0,'PropertyID','Property',1,0,'LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,0
	END
	ELSE if (@CostCenterID=93 and @Name='Unit Particulars')
	BEGIN
		
		select @documenttype=value from ADM_GlobalPreferences WITH(NOLOCK)
		where Name='DepositLinkDimension'
	
		SELECT a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,
		CASE WHEN SysColumnName='ParticularID' THEN @documenttype ELSE ColumnCostCenterID END ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		NULL DebitAccount,NULL CreditAccount,NULL Formula,NULL PostingType,NULL RoundOff,NULL IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		WHERE a.CostcenterID=93 and a.SysTableName='REN_Particulars'
		UNION
		SELECT -1,93, 'Units',NULL, 'REN_Particulars','UnitID',93,0,'UnitID','Unit',1,0,'LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,0
		
		UNION
		SELECT -2,93, 'Units',NULL, 'REN_Particulars','Post to Debit',93,0,'PostDebit','Post to Debit',1,0,'Combobox',NULL,NULL,NULL,NULL,NULL,NULL,0,'Combobox',NULL,0		
		UNION
		SELECT -3,93, 'Units',NULL, 'REN_Particulars','Bank',2,2,'BankAccountID','Bank',1,0,'LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,0		
		UNION
		SELECT -4,93, 'Units',NULL, 'REN_Particulars','Display',93,0,'Display','Display',1,0,'Combobox',NULL,NULL,NULL,NULL,NULL,NULL,0,'Combobox',NULL,0		
		UNION
		SELECT -5,93, 'Units',NULL, 'REN_Particulars','Percentage Type',93,0,'PercType','Percentage Type',1,0,'Combobox',NULL,NULL,NULL,NULL,NULL,NULL,0,'Combobox',NULL,0
	END	
	ELSE if (@CostCenterID=92 and @Name='Particulars Import')
	BEGIN
		select @documenttype=value from ADM_GlobalPreferences WITH(NOLOCK)
		where Name='DepositLinkDimension'
		SELECT * FROM (
		
		SELECT a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,
		CASE WHEN SysColumnName='ParticularID' THEN @documenttype ELSE ColumnCostCenterID END ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		NULL DebitAccount,NULL CreditAccount,NULL Formula,NULL PostingType,NULL RoundOff,NULL IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		WHERE a.CostcenterID=93 and a.SysTableName='REN_Particulars'
		UNION
		SELECT -1,93, 'Units',NULL, 'REN_Particulars','PropertyID',92,0,'PropertyID','Property',1,0,'LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,0
		UNION
		SELECT a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,
		CASE WHEN SysColumnName='ParticularID' THEN @documenttype ELSE ColumnCostCenterID END ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		NULL DebitAccount,NULL CreditAccount,NULL Formula,NULL PostingType,NULL RoundOff,NULL IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		WHERE a.CostcenterID=93 and a.SysTableName='REN_Particulars'
		UNION
		SELECT -1,93, 'Units',NULL, 'REN_Particulars','UnitID',93,0,'UnitID','Unit',1,0,'LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,0
		
		UNION
		SELECT -2,93, 'Units',NULL, 'REN_Particulars','Post to Debit',93,0,'PostDebit','Post to Debit',1,0,'Combobox',NULL,NULL,NULL,NULL,NULL,NULL,0,'Combobox',NULL,0		
		UNION
		SELECT -3,93, 'Units',NULL, 'REN_Particulars','Bank',2,2,'BankAccountID','Bank',1,0,'LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,0		
		UNION
		SELECT -4,93, 'Units',NULL, 'REN_Particulars','Display',93,0,'Display','Display',1,0,'Combobox',NULL,NULL,NULL,NULL,NULL,NULL,0,'Combobox',NULL,0		
		UNION
		SELECT -5,93, 'Units',NULL, 'REN_Particulars','Percentage Type',93,0,'PercType','Percentage Type',1,0,'Combobox',NULL,NULL,NULL,NULL,NULL,NULL,0,'Combobox',NULL,0
		UNION
		SELECT -151,93, 'Units',NULL, 'REN_Particulars','Condition',92,0,'Condition','Condition',1,0,'String',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		UNION
		SELECT -152,93, 'Units',NULL, 'REN_Particulars','Action',92,0,'Action','Action',1,0,'String',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		UNION
		SELECT -153,93, 'Units',NULL, 'REN_Particulars','Filter',92,0,'Filter','Filter',1,0,'String',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0		
		) AS T GROUP BY CostCenterColID,CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,SysColumnName,ColumnCostCenterID
		,ColumnCCListViewTypeID,IsMandatory,ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DebitAccount,CreditAccount,Formula,PostingType,RoundOff,IsCalculate , IsTransfer, UserColumnType,LINKDATA,IsMandatory
	END
	ELSE if (@CostCenterID=11)
	BEGIN
		SELECT -1 CostCenterColID,11 CostcenterID, 'UOM' CostCenterName,'' UserDefaultValue,'COM_UOM' SysTableName,'BaseName' UserColumnName,0 ColumnCostCenterID
		,0 ColumnCCListViewTypeID,'BaseName' SysColumnName,'BaseName' ResourceData,1 IsColumninuse,0 IsColumnUserDefined,'TEXT' ColumnDataType,NULL DebitAccount
		,NULL CreditAccount,NULL Formula,NULL PostingType,NULL RoundOff,NULL IsCalculate,0 IsTransfer,NULL UserColumnType,NULL LINKDATA,0 IsMandatory
		UNION
		SELECT -2,11, 'UOM','', 'COM_UOM','UnitName',0,0,'UnitName','UnitName',1,0,'TEXT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		UNION
		SELECT -3,11, 'UOM','', 'COM_UOM','Conversion',0,0,'Conversion','Conversion',1,0,'FLOAT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
		
		SELECT UOMID,BaseID,BaseName,UnitID,UnitName,Conversion FROM COM_UOM WITH(NOLOCK) ORDER BY UOMID
	END
	ELSE if (@CostCenterID=7)
	BEGIN
		SELECT a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue,a.UserProbableValues, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		NULL DebitAccount,NULL CreditAccount,NULL Formula,NULL PostingType,NULL RoundOff,NULL IsCalculate ,isnull(IsTransfer,0) IsTransfer,UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		WHERE a.CostcenterID=@CostCenterID AND SysColumnName NOT IN ( 'Email2ConfirmPassword','Email1ConfirmPassword','HistoryStatus','Image')
	END
	ELSE if (@CostCenterID=8 and @Name='Dimension Move')
	BEGIN
		SELECT -4 CostCenterColID,8 CostcenterID,'DimensionID' SysColumnName,'DimensionID**' ResourceData
		UNION
		SELECT -3 CostCenterColID,8 CostcenterID,'DimensionName' SysColumnName,'DimensionName**' ResourceData
		UNION
		SELECT -2 CostCenterColID,8 CostcenterID,'Node' SysColumnName,'Node*' ResourceData
		UNION
		SELECT -1 CostCenterColID,8 CostcenterID,'Group' SysColumnName,'Group*' ResourceData
	END
	ELSE if (@CostCenterID=400 and @Name='Document Edit')
	BEGIN
		SELECT DISTINCT CASE WHEN a.SysColumnName='VoucherNo' THEN -1003 WHEN a.SysColumnName='CommonNarration' THEN 1002 WHEN a.SysColumnName='LineNarration' THEN 1001 ELSE  REPLACE(a.SysColumnName,'dcAlpha','') END CostCenterColID,400 CostcenterID,a.SysColumnName,CASE WHEN a.SysColumnName='VoucherNo' THEN a.SysColumnName+'*' ELSE 'New '+a.SysColumnName END ResourceData,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock) 
		WHERE a.CostcenterID between 40000 and 50000  AND (a.SysColumnName LIKE 'dcAlpha%' OR a.SysColumnName IN ('VoucherNo','CommonNarration','LineNarration'))
		UNION
		SELECT DISTINCT -CASE WHEN a.SysColumnName='CommonNarration' THEN 1002 WHEN a.SysColumnName='LineNarration' THEN 1001 ELSE  REPLACE(a.SysColumnName,'dcAlpha','') END CostCenterColID,400 CostcenterID,a.SysColumnName,'Old '+a.SysColumnName ResourceData,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock) 
		WHERE a.CostcenterID between 40000 and 50000 AND (a.SysColumnName LIKE 'dcAlpha%' OR a.SysColumnName IN ('CommonNarration','LineNarration'))
		ORDER BY CostCenterColID
	END
	ELSE if (@CostCenterID=44)
	BEGIN
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=44

		SELECT NodeID FROM COM_LookUpTypes WHERE LookUpName=SUBSTRING(@Name,0,CHARINDEX('(',@Name)-1)
	END 
	ELSE if (@CostCenterID=74 OR @CostCenterID=75 OR @CostCenterID=77)
	BEGIN 
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=@CostCenterID and IsColumninuse=1
		ORDER BY UserColumnName
	END
	ELSE if (@CostCenterID=115)
	BEGIN
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue,a.UserProbableValues, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsUnique,a.IsMandatory
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=86 AND 
		(((a.IsColumnUserDefined=1 OR a.IsCostCenterUserDefined=1)  AND   (a.SysColumnName NOT LIKE '%dcCalcNum%')
		AND (a.SysColumnName NOT LIKE '%dcExchRT%') AND (a.SysColumnName NOT LIKE '%dcCurrID%')
		AND a.IsColumnInUse=1 AND a.ISCOLUMNDELETED=0) OR a.IsColumnUserDefined=0)      
		and a.costcentercolid not in (SELECT MAX([CostCenterColID])
		FROM [ADM_CostCenterDef] with(nolock) where Columncostcenterid is not null and Columncostcenterid =2
		GROUP BY [CostCenterID],[SysColumnName]
		HAVING COUNT(*)>1 AND [CostCenterID]> 40000 AND [CostCenterID]< 50000)
		union 
		Select -Featureid AS CostCenterColID, FeatureID as CostCenterID, '' CostCenterName,
		'' UserDefaultValue,'' UserProbableValues, '' SysTableName, 'Assigned_'+Name  UserColumnName,
		FeatureID as ColumnCostCenterID,0 ColumnCCListViewTypeID, 'Assigned_'+Name as SysColumnName, 
		'Assigned_'+Name as ResourceData, isenabled IsColumninuse, isenabled IsColumnUserDefined, '' ColumnDataType,
		'' DebitAccount,'' CreditAccount, '' Formula, '' PostingType, '' RoundOff,'' IsCalculate, 0 IsTransfer,'','',0,0
		from adm_features with(nolock) where featureid >50000 and isenabled=1
		union
		SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue,'', SysTableName,UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
		SysColumnName ,CASE WHEN (a.IsMandatory=1 AND SysColumnName='Quantity') THEN 'Products_'+l.ResourceData+'*' WHEN (a.IsMandatory=0 AND SysColumnName='Quantity') THEN 'Products_'+l.ResourceData WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory,0
		FROM ADM_COSTCENTERDEF a with(nolock)
		join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
		LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
		WHERE a.CostcenterID=115 AND a.IsColumnInUse=1
	END
	ELSE  
	BEGIN
		IF (@CostCenterID> 40000 AND @CostCenterID< 50000 and @IsInventory=1)
		BEGIN
			SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
			SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
			DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA
			,DD.DrRefColID,DD.DrRefID,DD.CrRefColID,DD.CrRefID
			,a.ParentCostCenterSysName,a.ParentCostCenterColSysName,a.ParentCCDefaultColID,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
			LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
			WHERE a.CostcenterID=@CostCenterID AND 
			(((a.IsColumnUserDefined=1 OR a.IsCostCenterUserDefined=1) AND   (a.SysColumnName NOT LIKE '%dcCalcNum%')
			  AND (a.SysColumnName NOT LIKE '%dcExchRT%') AND (a.SysColumnName NOT LIKE '%dcCurrID%')
			AND a.IsColumnInUse=1 AND a.ISCOLUMNDELETED=0) OR a.IsColumnUserDefined=0)      
			and a.costcentercolid not in (SELECT MAX([CostCenterColID])
			FROM [ADM_CostCenterDef] with(nolock) where Columncostcenterid is not null and Columncostcenterid =2
			GROUP BY [CostCenterID],[SysColumnName]
			HAVING COUNT(*)>1 AND [CostCenterID]> 40000 AND [CostCenterID]< 50000)
			union 
			Select -Featureid AS CostCenterColID, FeatureID as CostCenterID, '' CostCenterName,
			'' UserDefaultValue, '' SysTableName, 'Assigned_'+Name  UserColumnName,
			FeatureID as ColumnCostCenterID,0 ColumnCCListViewTypeID, 'Assigned_'+Name as SysColumnName, 
			'Assigned_'+Name as ResourceData, isenabled IsColumninuse, isenabled IsColumnUserDefined, '' ColumnDataType,
			'' DebitAccount,'' CreditAccount, '' Formula, '' PostingType, '' RoundOff,'' IsCalculate, 0 IsTransfer,'','',0,0,0,0
			,null,null,0,0
			from adm_features with(nolock) where featureid >50000 and isenabled=1  
			UNION
			SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, 'Product_'+UserColumnName,3 ColumnCostCenterID,ColumnCCListViewTypeID, 
			SysColumnName ,'Product_'+l.ResourceData ResourceData,IsColumninuse,IsColumnUserDefined,'ProductString' ColumnDataType,
			'' DebitAccount,'' CreditAccount, '' Formula, '' PostingType, '' RoundOff,'' IsCalculate, 0 IsTransfer,'','',0,0,0,0
			,a.ParentCostCenterSysName,a.ParentCostCenterColSysName,a.ParentCCDefaultColID,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID  
			where costcenterid=3 and iscolumninuse=1
			and (columncostcenterid=0 or columncostcenterid is null) and systablename <>'INV_DocDetails'
			and (lower(usercolumntype)='string' or  lower(usercolumntype) ='text' or
			lower(usercolumntype) like '%textarea%' or lower(syscolumnname)='aliasname')
			and syscolumnname not in ('HistoryStatus','BinDimension','BinLocation','BinDivision','CreatedBy','ModifiedBy','')
			Union
			--Added to Import batch information @purchase type of vouchers
			SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName,'Batch_'+ UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
			SysColumnName ,'Batch_'+l.ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
			DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,'',0,0,0,0
			,a.ParentCostCenterSysName,a.ParentCostCenterColSysName,a.ParentCCDefaultColID,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= 1
			LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
			WHERE a.CostcenterID=16 AND a.systablename<>'INV_BatchDetails' and @VoucherType=1 
			and (a.syscolumnname not in ('BatchID','Depth','IsGroup','VersionNo','IsDeleted','IsNegativeSaleAllowed','IsAutoAdjustAllowed',
			'AccDocDetailsID','InvDocDetailsID','ActualQuantity','HoldQuantity','ReleaseQuantity','ExecutedQuanity','BatchNumber', 'MfgDate','ExpiryDate' ))
			and	(((a.IsColumnUserDefined=1 OR a.IsCostCenterUserDefined=1)      
			AND a.IsColumnInUse=1 AND a.ISCOLUMNDELETED=0) OR a.IsColumnUserDefined=0)      
			and a.costcentercolid not in (SELECT MAX([CostCenterColID])
			FROM [ADM_CostCenterDef] with(nolock) where Columncostcenterid is not null and Columncostcenterid =2
			GROUP BY [CostCenterID],[SysColumnName]
			HAVING COUNT(*)>1 AND [CostCenterID]> 40000 AND [CostCenterID]< 50000)
			union
			--Extrafields of Accounts and CostCenters
			SELECT a.CostCenterColID,
			a.CostcenterID, 
			a.CostCenterName,
			a.UserDefaultValue,
			a.SysTableName, 
			a.CostCenterName+'_'+a.UserColumnName,
			a.CostcenterID ColumnCostCenterID,
			a.ColumnCCListViewTypeID, 
			a.SysColumnName ,
			a.CostCenterName+'_'+l.ResourceData ResourceData,
			a.IsColumninuse,
			a.IsColumnUserDefined,
			'CostCenterString' ColumnDataType,
			'' DebitAccount,'' CreditAccount, '' Formula, '' PostingType, '' RoundOff,'' IsCalculate, 0 IsTransfer,'','',0,0,0,0
			,a.ParentCostCenterSysName,a.ParentCostCenterColSysName,a.ParentCCDefaultColID,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			join COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and l.LanguageID= 1  
			where a.costcenterid >=50001 and a.iscolumninuse=1
			and (a.columncostcenterid=0 or a.columncostcenterid is null) and a.systablename <>'INV_DocDetails'
			and (lower(a.usercolumntype)='string' or  lower(a.usercolumntype) ='text' or
			lower(a.usercolumntype) like '%textarea%' or lower(a.syscolumnname)='aliasname')
			and lower(a.syscolumnname)<>'name'
			and a.syscolumnname not in ('HistoryStatus','CreatedBy','ModifiedBy','')
			and a.costcenterid in (select distinct columncostcenterid from ADM_COSTCENTERDEF with(nolock) where costcenterid=@CostCenterID and iscolumninuse=1)					
			union			
			SELECT -56 CostCenterColID,@CostCenterID,@Name,NULL UserDefaultValue, SysTableName,'Attachments' UserColumnName,0 ColumnCostCenterID
			,ColumnCCListViewTypeID, 'Attachments' SysColumnName ,'Attachments' ResourceData,IsColumninuse,IsColumnUserDefined,'String' ColumnDataType,
			NULL DebitAccount,NULL CreditAccount, NULL Formula, '' PostingType, '' RoundOff,'' IsCalculate, '0' IsTransfer,'','',0,0,0,0
			,CD.ParentCostCenterSysName,CD.ParentCostCenterColSysName,CD.ParentCCDefaultColID,CD.IsMandatory 
			FROM ADM_CostCenterDef CD WITH(NOLOCK) 
			join dbo.COM_LanguageResources L with(nolock) on CD.ResourceID=L.ResourceID and L.LanguageID=1
			WHERE SysColumnName='Attachments' AND CD.CostCenterID=2
			
			order by UserColumnName
			
		END
		ELSE IF (@CostCenterID=76 and @Name='Bill Of Materials With Multiple Stage')
		BEGIN
			DECLARE @StageDimID INT,@MachineDimID INT
			
			select @StageDimID=Value from COM_CostCenterPreferences with(nolock) where CostCenterID=@CostCenterID and Name='StageDimension'
			select @MachineDimID=Value from COM_CostCenterPreferences with(nolock) where CostCenterID=@CostCenterID and Name='MachineDimension'

			SELECT a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
			SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
			DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
			LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID
			WHERE a.CostcenterID=@CostCenterID AND (((a.IsColumnUserDefined=1 OR a.IsCostCenterUserDefined=1) 
			AND a.IsColumnInUse=1 AND a.ISCOLUMNDELETED=0) OR a.IsColumnUserDefined=0) AND SysTableName NOT IN ('PRD_BOMProducts','PRD_Expenses','PRD_BOMResources')       
			UNION
			SELECT -1,76, 'BOM','', 'PRD_BOMProducts','Stage_Product',3,108,'ProductID','Stage_Product','1','0','LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -2,76, 'BOM','', 'PRD_BOMProducts','Qty',0,0,'Quantity','Qty','1','0','FLOAT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -3,76, 'BOM','', 'PRD_BOMProducts','UOM',11,1,'UOMID','UOM','1','0','LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -4,76, 'BOM','', 'PRD_BOMProducts','UnitPrice',0,0,'UnitPrice','UnitPrice','1','0','FLOAT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -5,76, 'BOM','', 'PRD_BOMProducts','Value',0,0,'Value','Value','1','0','FLOAT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL	,0
			UNION
			SELECT -6,76, 'BOM','', 'PRD_BOMProducts','Wastage',0,0,'Wastage','Wastage','1','0','FLOAT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0	
			UNION
			SELECT -7,76, 'BOM','', 'PRD_BOMProducts','IncInStageCost',0,0,'IncInStageCost','IncInStageCost','1','0','ComboBox',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0			
			UNION
			SELECT -8,76, 'BOM','', 'PRD_BOMProducts','IncInFinalCost',0,0,'IncInFinalCost','IncInFinalCost','1','0','ComboBox',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0	
			UNION
			SELECT -9,76, 'BOM','', 'PRD_BOMProducts','ProductUse',0,0,'ProductUse','ProductType','1','0','ComboBox',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0		
			UNION
			SELECT -10,76, 'BOM','', 'PRD_BOMStages','Stages',@StageDimID,1,'StageNodeID','Stages','1','0','LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL	,0
			UNION
			SELECT -11,76, 'BOM','', 'PRD_BOMStages','StageOrder',0,0,'lft','StageOrder','1','0','INT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -12,76, 'BOM','', 'PRD_Expenses','Name',0,0,'Name','Name','1','0','TEXT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -13,76, 'BOM','', 'PRD_Expenses','CreditAccount',2,1,'CreditAccountID','CreditAccount','1','0','LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -14,76, 'BOM','', 'PRD_Expenses','DebitAccount',2,1,'DebitAccountID','DebitAccount','1','0','LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -15,76, 'BOM','', 'PRD_BOMResources','Machine',@MachineDimID,1,'ResourceID','Machine','1','0','LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0
			UNION
			SELECT -16,76, 'BOM','', 'PRD_BOMResources','Hrs',0,0,'Hours','Hrs','1','0','FLOAT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0			
			UNION
			SELECT -17,76, 'BOM','', 'PRD_BOMResources','Options',0,0,'Options','Options','1','0','INT',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0 FROM
			COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=76 AND Name='EnableMachineoptions'	AND Value='True'			
			UNION
			SELECT -18,76, 'BOM','', 'PRD_BOMResources','MachineDim1',CCP.Value,0,'MachineDim1',F.Name,'1','0','LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0 FROM
			COM_CostCenterPreferences CCP WITH(NOLOCK) JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=CCP.Value WHERE CCP.CostCenterID=76 AND CCP.Name='MachineDim1' 
			AND CCP.Value>0
			UNION
			SELECT -19,76, 'BOM','', 'PRD_BOMResources','MachineDim2',CCP.Value,0,'MachineDim2',F.Name,'1','0','LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,0 FROM
			COM_CostCenterPreferences CCP WITH(NOLOCK) JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=CCP.Value WHERE CCP.CostCenterID=76 AND CCP.Name='MachineDim2' 
			AND CCP.Value>0
		END
		ELSE IF @CostCenterID=95
		BEGIN 
			SELECT DISTINCT  a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue,a.UserProbableValues, CASE WHEN SysTableName='REN_ContractPayTerms' THEN 'REN_ContractParticulars' ELSE SysTableName END SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
			SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
			DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsUnique, isnull(Sectionid,0) Sectionid,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			JOIN dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
			LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
			WHERE a.CostcenterID=@CostCenterID AND 
			(((a.IsColumnUserDefined=1 OR a.IsCostCenterUserDefined=1) AND a.IsColumnInUse=1 AND a.ISCOLUMNDELETED=0) OR a.IsColumnUserDefined=0)      
			AND a.CostCenterColID NOT IN (SELECT CDPT.CostCenterColID FROM ADM_COSTCENTERDEF CDPR WITH(NOLOCK)
			JOIN ADM_COSTCENTERDEF CDPT WITH(NOLOCK) ON CDPR.SYSCOLUMNNAME=CDPT.SYSCOLUMNNAME
			WHERE CDPR.COSTCENTERID=@CostCenterID AND CDPT.COSTCENTERID=@CostCenterID 
			AND CDPR.systablename='REN_ContractParticulars' AND CDPT.systablename ='REN_ContractPayTerms' AND CDPT.SysColumnName NOT LIKE 'CCNID%')
			UNION
			SELECT -26046,CP.CostCenterID,'Contract','','','REN_ContractParticulars',F.Name,CP.Value,0,'LocID',LR.ResourceData,1,0,'LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,NULL,0,0
			FROM COM_CostCenterPreferences CP WITH(NOLOCK)
			JOIN ADM_Features F WITH(NOLOCK) ON F.FeatureID=CP.Value
			JOIN COM_LanguageResources LR WITH(NOLOCK) ON LR.ResourceID=F.ResourceID AND LR.LanguageID=@LangID
			WHERE CostCenterID=@CostCenterID AND CP.Name='DimensionWiseContract'
			UNION
			SELECT -1,95,'Contract','','','REN_Contract','ParentContractNo',95,0,'ParentContractNo','ParentContractNo',1,0,'LISTBOX',NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,NULL,0,0
						
		END		
		ELSE IF (@Name='Job Output')
		BEGIN
			SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue,a.UserProbableValues, SysTableName, UserColumnName,@CostCenterID ColumnCostCenterID,ColumnCCListViewTypeID, 
			SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
			DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsUnique,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
			WHERE a.CostcenterID=@CostCenterID AND SysColumnName IN ('Code','Name')
			UNION
			SELECT -151,@CostCenterID, 'Job',NULL,NULL,'PRD_JobOuputProducts','BOM',76,76,'BOMID','BOM',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,NULL,0 
			UNION				
			SELECT -152,@CostCenterID, 'Job',NULL,NULL,'PRD_JobOuputProducts','Stage',Value,Value,'StageID','Stage',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,NULL,0 
			FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=76 AND Name='StageDimension'
			UNION
			SELECT -153,@CostCenterID, 'Job',NULL,NULL,'PRD_JobOuputProducts','Product',3,3,'ProductID','Product',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,NULL ,0
			UNION
			SELECT -154,@CostCenterID, 'Job',NULL,NULL,'PRD_JobOuputProducts','Size',0,0,'Qty','Size',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,'FLOAT',NULL,NULL ,0
			UNION
			SELECT -155,@CostCenterID, 'Job',NULL,NULL,'PRD_JobOuputProducts','Unit',0,0,'IsBom','Unit',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,'BIT',NULL,NULL,0  
			UNION
			SELECT -156,@CostCenterID, 'Job',NULL,NULL,'PRD_JobOuputProducts','UOM',11,1,'UOMID','UOM',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,'LISTBOX',NULL,NULL,0
			UNION
			SELECT -157,@CostCenterID, 'Job',NULL,NULL,'PRD_JobOuputProducts','Remarks',0,0,'Remarks','Remarks',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,'String',NULL,NULL,0  
			UNION
			SELECT -158,@CostCenterID, 'Job',NULL,NULL,'PRD_JobOuputProducts','Status',113,0,'StatusID','Status',1,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,'COMBOBOX',NULL,NULL ,0 
			order by CostCenterColID DESC
		END
		ELSE
		BEGIN 
			SELECT   a.CostCenterColID,a.CostcenterID, CostCenterName,UserDefaultValue,a.UserProbableValues, SysTableName, UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
			SysColumnName ,CASE WHEN a.IsMandatory=1 THEN l.ResourceData+'*' ELSE l.ResourceData END ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
			DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,LINKDATA,a.IsUnique,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
			LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
			WHERE a.CostcenterID=@CostCenterID AND 
			(((a.IsColumnUserDefined=1 OR a.IsCostCenterUserDefined=1)  AND   (a.SysColumnName NOT LIKE '%dcCalcNum%')
			  AND (a.SysColumnName NOT LIKE '%dcExchRT%') AND (a.SysColumnName NOT LIKE '%dcCurrID%')
			AND a.IsColumnInUse=1 AND a.ISCOLUMNDELETED=0) OR a.IsColumnUserDefined=0)      
			and a.costcentercolid not in (SELECT MAX([CostCenterColID])
			FROM [ADM_CostCenterDef] with(nolock) where Columncostcenterid is not null and Columncostcenterid =2
			GROUP BY [CostCenterID],[SysColumnName]
			HAVING COUNT(*)>1 AND [CostCenterID]> 40000 AND [CostCenterID]< 50000)
			union 
			Select -Featureid AS CostCenterColID, FeatureID as CostCenterID, '' CostCenterName,
			'' UserDefaultValue,'' UserProbableValues, '' SysTableName, 'Assigned_'+Name  UserColumnName,
			FeatureID as ColumnCostCenterID,0 ColumnCCListViewTypeID, 'Assigned_'+Name as SysColumnName, 
			'Assigned_'+Name as ResourceData, isenabled IsColumninuse, isenabled IsColumnUserDefined, '' ColumnDataType,
			'' DebitAccount,'' CreditAccount, '' Formula, '' PostingType, '' RoundOff,'' IsCalculate, 0 IsTransfer,'','',0,0
			from adm_features with(nolock) where featureid >50000 and isenabled=1
			union
			SELECT -7 AS CostCenterColID,7 as CostCenterID,'Users' as CostCenterName,
			'' UserDefaultValue,'' UserProbableValues, '' SysTableName, 'Assigned_Users'  UserColumnName,
			7 as ColumnCostCenterID,0 ColumnCCListViewTypeID, 'Assigned_Users' as SysColumnName, 
			'Assigned_Users' as ResourceData, '1' IsColumninuse, '1' IsColumnUserDefined, '' ColumnDataType,
		    '' DebitAccount,'' CreditAccount, '' Formula, '' PostingType, '' RoundOff,'' IsCalculate, 0 IsTransfer,'','',0,0
			FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='Dimension List' AND (@CostCenterID IN (2,3) OR @CostCenterID>50000)
			AND (Value=CONVERT(NVARCHAR,@CostCenterID) OR Value LIKE CONVERT(NVARCHAR,@CostCenterID)+',%' OR Value LIKE '%,'+CONVERT(NVARCHAR,@CostCenterID)+',%' OR Value LIKE '%,'+CONVERT(NVARCHAR,@CostCenterID) )	
			UNION			
			SELECT -55 AS CostCenterColID, 2 as CostCenterID, 'ADDRESS' CostCenterName,a.UserDefaultValue,a.UserProbableValues, 'COM_ADDRESS', a.UserColumnName,
			a.ColumnCostCenterID,a.ColumnCCListViewTypeID, a.SysColumnName, 
			'Address_'+ResourceData ResourceData, IsColumninuse, '1', a.ColumnDataType,
			'' DebitAccount,'' CreditAccount, '' Formula, '' PostingType, '' RoundOff,'' IsCalculate, 0 IsTransfer,'','',0,0
			FROM ADM_CostCenterDef a		
			join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= @LangID
			WHERE SysColumnName='IsDefault' AND CostCenterID=3 AND @CostCenterID=2
			union			
			SELECT -56 CostCenterColID,@CostCenterID,@Name,CD.UserDefaultValue,CD.UserProbableValues, SysTableName, CD.UserColumnName,
			CD.ColumnCostCenterID,CD.ColumnCCListViewTypeID, CD.SysColumnName, 
			L.ResourceData ResourceData, IsColumninuse, '1', CD.ColumnDataType,
			'' DebitAccount,'' CreditAccount, '' Formula, '' PostingType, '' RoundOff,'' IsCalculate, 0 IsTransfer,'','',0,0
			FROM ADM_CostCenterDef CD WITH(NOLOCK) 
			join dbo.COM_LanguageResources L with(nolock) on CD.ResourceID=L.ResourceID and L.LanguageID=1
			WHERE SysColumnName='Attachments' AND CD.CostCenterID=2 AND @CostCenterID> 40000 AND @CostCenterID< 50000 and @IsInventory=0
		END
		
		SELECT CostCenterID,S.StatusID,R.ResourceData,[Status] as ActualStatus    
		FROM COM_Status S WITH(NOLOCK)    
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID    
		where CostCenterID=@CostCenterID

		IF(@CostCenterID=3)
		begin
			SELECT T.ProductTypeID,R.ResourceData    
			FROM INV_ProductTypes T WITH(NOLOCK)     
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON T.ResourceID=R.ResourceID AND R.LanguageID=@LangID    
			WHERE T.Status='Active'    

			SELECT V.ValuationID,R.ResourceData    
			FROM INV_ValuationMethods V WITH(NOLOCK)    
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON V.ResourceID=R.ResourceID AND R.LanguageID=@LangID    

			select a.UOMID,a.UnitName,a.ProductID,p.ProductCode,p.ProductName from COM_UOM a WITH(NOLOCK)
			left join inv_product p WITH(NOLOCK) on a.ProductID=p.ProductID
			order by a.isproductwise,a.UOMID,a.baseid,a.unitid

		end
		else IF(@CostCenterID=2)
		begin
			SELECT AccountTypeID,ResourceData,AccountType,Status     
			FROM ACC_AccountTypes A WITH(NOLOCK)     
			JOIN COM_LanguageResources R WITH(NOLOCK) ON A.ResourceID=R.ResourceID    
			WHERE LanguageID=@LangID  
			
		end
		else if(@CostCenterID between 40000 and 50000)
		begin
			SELECT [DocumentTypeID],[CostCenterID],[DocumentType],[IsInventory],[DocumentAbbr],[DocumentName]
					,[IsUserDefined],[AccountsXML] FROM [ADM_DocumentTypes] with(nolock) 
			where [CostCenterID]=@CostCenterID
	
			Select * from COM_DocumentPreferences with(nolock)
			where CostCenterID=@CostCenterID
		 	
		 	SELECT U.UOMID,U.UnitName UnitName, P.ProductCode, P.ProductName FROM Com_UOM U WITH(nolock) 
			LEFT JOIN INV_PRODUCT P WITH (NOLOCK) ON U.PRODUCTID=P.PRODUCTID
		
		 --	select UOMID,UnitName from COM_UOM WITH(NOLOCK)
		 	
		 	select name,value from com_costcenterpreferences WITH(NOLOCK) where costcenterid=3 
			and (name='TempPartProduct' or name='BinsDimension' or name='ProductWiseBins')
			
		end
		else if(@CostCenterID=76 OR @CostCenterID=72)
		begin			
			select a.UOMID,a.UnitName,a.ProductID,p.ProductCode,p.ProductName from COM_UOM a WITH(NOLOCK)
			left join inv_product p WITH(NOLOCK) on a.ProductID=p.ProductID
		
		end

		--Getting Currency.    
		SELECT CurrencyID,Name, IsBaseCurrency,ExchangeRate FROM COM_Currency WITH(NOLOCK)  
  
	    SELECT C.CostCenterColID, F.Name + ' - ' + C.SysColumnName AS Name,'/' 'Link/Delink' ,5 'ColumnWidth', C.CostCenterID
		FROM ADM_CostCenterDef AS C WITH(NOLOCK) 
		INNER JOIN ADM_Features AS F WITH(NOLOCK) ON C.CostCenterID = F.FeatureID
		WHERE (C.SysColumnName = N'Code' OR C.SysColumnName = N'Name') AND (C.CostCenterID > 50000) AND (F.IsEnabled = 1)
		 IF (@Name='Job Output')
		 BEGIN			
			SELECT U.UOMID,U.UnitName UnitName, P.ProductCode, P.ProductName FROM Com_UOM U WITH(nolock) 
			LEFT JOIN INV_PRODUCT P WITH (NOLOCK) ON U.PRODUCTID=P.PRODUCTID
			
			SELECT CostCenterID,S.StatusID,R.ResourceData,[Status] as ActualStatus    
			FROM COM_Status S WITH(NOLOCK)    
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=1    
			where CostCenterID=158
		 END
	 	select DefinitionXML,BarcodeXml from ADM_DocBarcodeLayouts WITH(NOLOCK) 
		where CostCenterID=@CostCenterID and  len(Bodyxml)<10

		-- Getting ImportDetails
		--SELECT DISTINCT(NAME) FROM ADM_ImportDetails WHERE COSTCENTERID=@CostCenterID
		if(@CostCenterID=3)
		begin
			SELECT Name, Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID = 3
		end
		if(@CostCenterID=16)
		begin
			SELECT BatchID, BatchNumber, BatchCode FROM Inv_batches WITH(NOLOCK) WHERE isgroup=1
		end
		if(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID=16 or @CostCenterID>=50000)
			select * from COM_CostCenterCodeDef with(nolock) where costcenterid=@CostCenterID 
		
		if(@CostCenterID=3)
			SELECT CostCenterColID,SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE [CostCenterID]=@CostCenterID
			AND CostCenterColID NOT IN (select CostCenterColIDBase FROM COM_DocumentBatchLinkDetails WITH(NOLOCK) 
			where [CostCenterID]=@CostCenterID and batchColid=0 and LinkDimCCID=@CostCenterID) and UserColumnType is not null
			and SysColumnName not in ('Depth','ParentID','','ProductCode','ProductName','ProductGroup','ProductID','IsGroup') AND SysTableName<>'INV_DocDetails'                            
			AND (((IsColumnUserDefined=1 OR IsCostCenterUserDefined=1) AND IsColumnInUse=1 AND ISCOLUMNDELETED=0) OR IsColumnUserDefined=0)    
            
		if(@CostCenterID=83)
			SELECT   a.CostCenterColID,a.CostCenterID, CostCenterName,UserDefaultValue, SysTableName,'Contact_'+UserColumnName UserColumnName,ColumnCostCenterID,ColumnCCListViewTypeID, 
			'Contact_'+SysColumnName SysColumnName,'Contact_'+l.ResourceData ResourceData,IsColumninuse,IsColumnUserDefined,ColumnDataType,
			DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.IsCalculate , isnull(IsTransfer,0) IsTransfer, UserColumnType,a.IsMandatory
			FROM ADM_COSTCENTERDEF a with(nolock)
			join dbo.COM_LanguageResources l with(nolock) on a.ResourceID=l.ResourceID and LanguageID= 1
			LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=a.CostCenterColID 
			WHERE a.CostcenterID=65 AND a.costcentercolid not in (24346,24347,24348,24349,24350,24352) and
			(((a.IsColumnUserDefined=1 OR a.IsCostCenterUserDefined=1) 
			AND a.IsColumnInUse=1 AND a.ISCOLUMNDELETED=0) OR a.IsColumnUserDefined=0)
			
		--Getting Workflows  
		if(@CostCenterID between 40000 and 50000)
			SELECT distinct [WorkFlowDefID],[CostCenterID],[Action],[Expression],a.WorkFlowID  
			FROM [COM_WorkFlowDef] a WITH(NOLOCK)
			join COM_WorkFlow b  WITH(NOLOCK) on a.WorkFlowID=b.WorkFlowID  
			left join COM_Groups g WITH(NOLOCK) on b.GroupID=g.GID
			left join ADM_UserRoleMap r WITH(NOLOCK) on b.RoleID=r.RoleID 
			where  [CostCenterID]=@CostCenterID and IsEnabled=1 and (b.UserID =@UserID or b.roleid=r.RoleID or g.roleid=r.roleid)
	END
	if(@CostCenterID=95)
		select NodeID,Name from com_lookup with(nolock) where lookuptype=48
	 
SET NOCOUNT OFF;   
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
