USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterTab]
	@CostCenterID [int] = 0,
	@LocalReference [int] = 0,
	@CompanyID [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION          
BEGIN TRY          
SET NOCOUNT ON          
    
 	IF (@CostCenterID=144 and (@LocalReference between 40000 and 50000))
    BEGIN           
		declare @PrefValue nvarchar(max)
		select @PrefValue=PrefValue from [com_documentpreferences] WITH(nolock)
		where PrefName='ActivityFields' and [CostCenterID]=@LocalReference
		SELECT b.ResourceData,syscolumnname,@PrefValue PrefValue
		FROM [ADM_CostCenterDef] a with(nolock)
		LEFT JOIN COM_LanguageResources b with(nolock) ON b.RESOURCEID=a.RESOURCEID    		
		where a.CostCenterID=@CostCenterID and b.languageid=@LangID		and LocalReference is null 		
		and syscolumnname in('ActivityTypeID','StatusID','Subject','StartDate','EndDate','IsAllDayActivity','ActualCloseDate','AssignGroupID','CustomerID','Remarks','ContactId')
    END  
   ELSE IF (@CostCenterID=144 and  @LocalReference in (92,93,94,95))
    BEGIN           
		declare @PrefValue1 nvarchar(max)
		select @PrefValue1=Value from [COM_CostCenterPreferences] WITH(nolock)
		where Name='ActivityFields' and [CostCenterID]=@LocalReference
		SELECT b.ResourceData,syscolumnname,@PrefValue1 PrefValue
		FROM [ADM_CostCenterDef] a with(nolock)
		LEFT JOIN COM_LanguageResources b with(nolock) ON b.RESOURCEID=a.RESOURCEID    		
		where a.CostCenterID=@CostCenterID and b.languageid=@LangID		and LocalReference is null 		
		and syscolumnname in('ActivityTypeID','StatusID','Subject','StartDate','EndDate','IsAllDayActivity','ActualCloseDate','AssignGroupID','CustomerID','Remarks','ContactId')
    END 
    ELSE
    BEGIN
		SELECT DISTINCT CostCenterID,[CCTabID],b.ResourceData,[CCTabName], [TabOrder] ,[IsVisible], IsTabUserDefined
		  ,isnull(QuickViewCCID,0) QuickViewCCID,isnull(QuickViewID,0) QuickViewID
		FROM [ADM_CostCenterTab] a with(nolock)           
		LEFT JOIN COM_LanguageResources b with(nolock) ON b.RESOURCEID=a.RESOURCEID    and b.languageid=@LangID      
		where a.CostCenterID=@CostCenterID       
		order by [TabOrder]
    END 
    IF(@CostCenterID=144)    
    BEGIN  
		SELECT distinct  c.CostCenterColID, COM_LanguageResources.resourcedata UserColumnName, c.UserColumnType,       
		c.UserDefaultValue, c.UserProbableValues, c.IsEditable, 'EDIT' AS 'MAPACTION',       
		c.IsMandatory, c.ColumnCostCenterID, c.IsCostCenterUserDefined,c.ColumnDataType,  c.TextFormat, c.ResourceID, c.SectionID,      
		c.SectionName,c.SectionSeqNumber,c.ColumnCCListViewTypeID,c.Isvisible,c.ColumnDataType DataType, c.ColumnSpan ColumnSpan,c.localreference 
		, ISNULL(c.Filter,0) Filter,Cformula,LinkData,c.SysColumnName,dependancy,dependanton 
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef a with(nolock) where a.CostCenterID=c.ColumnCostCenterID and  a.SysColumnName='ccnid'+convert(nvarchar,(c.dependanton-50000))) as filterinuse
		,IsUnique,IsnoTab,Decimal Decimals,c.IgnoreChar,IGC.Name IgnoreCharText,c.WaterMark,
		case when (c.columncostcenterid=44 and C.UserDefaultValue is not null and isnumeric(C.UserDefaultValue)=1) 
		then (select L.name from COM_LOOKUP L with(nolock) where L.NodeID=CONVERT(INT,C.UserDefaultValue) )
		else '' end as LookUpName,c.MinChar,c.MaxChar,isnull(C.FieldExpression,'') FieldExpression,isnull(C.LabelColor,'') LabelColor
		FROM ADM_CostCenterDef c with(nolock) 
		LEFT OUTER JOIN COM_LanguageResources with(nolock) ON COM_LanguageResources.ResourceID = c.ResourceID  
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  c.IgnoreChar    
		WHERE c.CostCenterID = @CostCenterID AND c.IsColumnInUse = 1 AND c.IsColumnDeleted = 0 AND C.LocalReference=@LocalReference     
		AND (c.SysColumnName LIKE '%Alpha%' OR c.SysColumnName LIKE 'CCNID%' OR c.SysColumnName LIKE 'AccountID%' OR c.SysColumnName LIKE 'PRODUCTID%') 
		AND COM_LanguageResources.LanguageID = @LangID AND c.UserColumnType IS NOT NULL AND c.IsColumnUserDefined=1      
		ORDER BY c.CostCenterColID        
    END 
    ELSE
    BEGIN
		SELECT distinct  c.CostCenterColID, COM_LanguageResources.resourcedata UserColumnName, c.UserColumnType,       
		c.UserDefaultValue, c.UserProbableValues, c.IsEditable, 'EDIT' AS 'MAPACTION',       
		c.IsMandatory, c.ColumnCostCenterID, c.IsCostCenterUserDefined,c.ColumnDataType,  c.TextFormat, c.ResourceID, c.SectionID,      
		c.SectionName,c.SectionSeqNumber,c.ColumnCCListViewTypeID,c.Isvisible,c.ColumnDataType DataType, c.ColumnSpan ColumnSpan,c.localreference 
		, ISNULL(c.Filter,0) Filter,Cformula,LinkData,c.SysColumnName,dependancy,dependanton 
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef a with(nolock) where a.CostCenterID=c.ColumnCostCenterID and  a.SysColumnName='ccnid'+convert(nvarchar,(c.dependanton-50000))) as filterinuse
		,IsUnique,IsnoTab,Decimal Decimals,c.IgnoreChar,IGC.Name IgnoreCharText,c.WaterMark,
		case when (c.columncostcenterid=44 and C.UserDefaultValue is not null and isnumeric(C.UserDefaultValue)=1) 
		then (select L.name from COM_LOOKUP L with(nolock) where L.NodeID=CONVERT(INT,C.UserDefaultValue) )
		else '' end as LookUpName,c.MinChar,c.MaxChar,isnull(C.FieldExpression,'') FieldExpression,isnull(C.LabelColor,'') LabelColor
		,Calculate,EvalAfter
		FROM ADM_CostCenterDef c with(nolock) 
		LEFT OUTER JOIN COM_LanguageResources with(nolock) ON COM_LanguageResources.ResourceID = c.ResourceID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  c.IgnoreChar     
		WHERE c.CostCenterID = @CostCenterID AND c.IsColumnInUse = 1 AND c.IsColumnDeleted = 0       
		AND (c.SysColumnName LIKE '%Alpha%' OR c.SysColumnName LIKE 'CCNID%' OR c.SysColumnName LIKE 'AccountID%' OR c.SysColumnName LIKE 'PRODUCTID%') 
		AND COM_LanguageResources.LanguageID = @LangID AND c.UserColumnType IS NOT NULL AND c.IsColumnUserDefined=1      
		ORDER BY c.CostCenterColID  
    END
      
      
	--SELECT FEATUREID,Name,TableName FROM ADM_FEATURES WITH(NOLOCK) WHERE IsEnabled=1 AND ALLOWCUSTOMIZATION=1 AND       
	--((FEATUREID > 50000 AND FEATUREID <= 50500) OR FEATUREID IN (2,3,4,16,51,57,58,300,65,71,76,72,80,84,81,86,83,88,78,73,89,90,82,16,92,93,95,129,103,104,94,144,114,115,154,156,155,118,119,120,121,123,127,103,495,496,146,110,251,252,253,254,255))
		SELECT ADF.FEATUREID,CL.RESOURCEDATA Name,ADF.TableName FROM ADM_FEATURES ADF WITH(NOLOCK),COM_LANGUAGERESOURCES CL WITH(NOLOCK)
		WHERE ADF.RESOURCEID=CL.RESOURCEID AND CL.LanguageID=@LangID AND ADF.IsEnabled=1 AND ADF.ALLOWCUSTOMIZATION=1 AND       
	(ADF.FEATUREID > 50000 OR ADF.FEATUREID IN (2,3,4,16,51,57,58,300,65,71,76,72,80,84,81,86,83,88,78,73,89,90,82,16,92,93,95,129,103,104,94,144,114,115,154,156,155,118,119,120,121,123,127,103,495,496,146,110,251,252,253,254,255,40000))
      
      
      
	SELECT ListViewID,ListViewTypeID,CostCenterID,ListViewName from ADM_ListView WITH(NOLOCK)      
      
	   
	IF(@CostCenterID=51)
	BEGIN
		SELECT D.SysColumnName,  D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo, D.ColumnSpan,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType, D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock) 
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID     
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND (IsColumnUserDefined=0 or SysTableName='COM_Contacts') AND IsColumnInUse=1  order by d.sectionseqnumber     
	END
	else if(@CostCenterID=3 OR @CostCenterID=92 OR @CostCenterID=93 OR @CostCenterID=94 
		OR @CostCenterID=86 OR @CostCenterID=65 OR @CostCenterID=83 OR @CostCenterID=88 or @CostCenterID=89  )     
	begin      
		SELECT D.SysColumnName,  D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType, D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,D.SECTIONID,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock) 
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID     
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1  order by d.sectionseqnumber       
	end
	else if(@CostCenterID=115 or @CostCenterID=155 or @CostCenterID=154 or @CostCenterID=156 )     
	begin      
		SELECT D.SysColumnName,  D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType, D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,'Main' TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock) 
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID   
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar  
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=1 AND IsColumnInUse=1  
		AND SysColumnName NOT LIKE 'Alpha%' AND SysColumnName NOT LIKE 'CCNID%'
		order by d.sectionseqnumber       
	end 
	else if(@CostCenterID=118 OR @CostCenterID=123 OR @CostCenterID=121 OR @CostCenterID=127 OR @CostCenterID=120 )  --FOR CAMPAIGN TABS ONLY   
	begin      
		SELECT D.SysColumnName,  D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType, D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,'Main' TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock) 
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID  
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar   
		WHERE D.CostCenterID=@CostCenterID  AND IsColumnInUse=1  order by d.sectionseqnumber       
	end      
	else if(@CostCenterID=16)     
	begin   
		SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType      ,D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID      
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 
		and SectionID is NULL and systablename <>'INV_Product' order by d.sectionseqnumber       
	end     
	else if (@CostCenterID=72)
	begin
		SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType      ,D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=1      
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 and (SectionID is NULL or SectionID =623) order by d.sectionseqnumber       
	end 
	else if (@CostCenterID=50051)    
	begin      
		SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType      ,D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,D.SECTIONID,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID      
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 order by d.sectionseqnumber
		--WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 and (SectionID is NULL or SectionID between 700 and 732) order by d.sectionseqnumber       
	end 
	else if (@CostCenterID>50000)
	begin      
		SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType      ,D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,D.SECTIONID,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID      
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 
		order by d.sectionseqnumber       
	end   
	else if (@CostCenterID=144)     
	begin      
	 IF EXISTS(SELECT SysColumnName FROM ADM_CostCenterDef WHERE COSTCENTERID=144 AND IsColumnUserDefined=0 AND IsColumnInUse=1 AND LOCALREFERENCE=@LocalReference)
	 BEGIN
		SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType      ,D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID      
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 and LocalReference=@LocalReference order by d.sectionseqnumber       
	END
	ELSE
	BEGIN
	SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType      ,D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID      
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 and LocalReference IS NULL 
		AND SysColumnName in ('ActivityTypeID','ActivityTypeName','StatusID','Subject','StartDate','StartTime','EndDate','EndTime','IsAllDayActivity','ActualCloseDate','CustomerID','ContactId')
		order by d.sectionseqnumber 
	END
	end  
	else  if(@COSTCENTERID in( 2, 83, 86, 88, 89, 65, 73, 92, 93, 94, 95, 103, 104, 129))    
	begin      
		SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType      ,D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,D.SectionID,case when (D.SectionID IS NULL or D.SectionID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		,Cformula,Calculate,EvalAfter
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID      
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1  order by d.sectionseqnumber       
	end    
	else      
	begin      
		SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
		D.UserProbableValues ProbableValues,D.RowNo, D.ColumnNo,d.IgnoreChar,d.WaterMark,IGC.Name IgnoreCharText, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType      ,D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
		,D.SectionID,case when (D.SectionID IS NULL or D.SectionID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  , D.UserDefaultValue DefaultValue,IsUnique,IsnoTab,[Decimal] Decimals,d.MinChar,d.MaxChar,isnull(d.FieldExpression,'') FieldExpression,isnull(d.LabelColor,'') LabelColor
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID      
		LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
		LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  D.IgnoreChar
		WHERE D.CostCenterID=@CostCenterID AND IsColumnUserDefined=0 AND IsColumnInUse=1 and SectionID is NULL order by d.sectionseqnumber       
	end
 
	--To Get LookupTypes
	SELECT NodeID,LookupName FROM COM_LookupTypes WITH(NOLOCK) ORDER BY LookupName

	--Selected Quick Add Fields
	IF @CostCenterID=86 or @CostCenterID=73
	BEGIN
		SELECT CostCenterColID,QuickAddOrder FROM ADM_COSTCENTERDEF WITH(NOLOCK)
		WHERE CostCenterID=144 and LocalReference=@CostCenterID AND ShowInQuickAdd=1
		UNION ALL
		SELECT CostCenterColID,QuickAddOrder FROM ADM_COSTCENTERDEF WITH(NOLOCK)
		WHERE CostCenterID=@CostCenterID AND ShowInQuickAdd=1
		ORDER BY QuickAddOrder ASC
	END
	ELSE
	BEGIN
		SELECT CostCenterColID FROM ADM_COSTCENTERDEF WITH(NOLOCK)
		WHERE CostCenterID=@CostCenterID AND ShowInQuickAdd=1
		ORDER BY QuickAddOrder ASC	
	END
	
	--Link Dimension Preference
	Declare @LinkDimID INT
	select @LinkDimID=(case when isnumeric(Value)=1 then convert(int,Value) else 0 end) from COM_CostCenterPreferences WITH(NOLOCK) 
	where CostCenterID=@CostCenterID and 
	((CostCenterID=3 and Name='ProductLinkWithDimension') or 
	 (CostCenterID=93 and Name='UnitLinkDimension') or Name='LinkDimension'
	)
	set @LinkDimID=isnull(@LinkDimID,0)
	select FeatureID LinkDimID,Name FROM ADM_Features with(nolock) WHERE FeatureID=@LinkDimID
	
	
	--Preferences
	select Name,Value from COM_CostCenterPreferences WITH(NOLOCK) 
	WHERE CostCenterID=@CostCenterID AND Name IN ('EnableAssignMapInQuickAdd','AccountImageDimensions'
	,'ProductImageDimensions','ImageDimensions','EnableQuickAdd')
	
	
	SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.CostCenterID  
	FROM ADM_COSTCENTERDEF D with(nolock)
	LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID
	WHERE (D.CostCenterID in (2,3,83,92,93,94) or D.CostCenterID>50000) AND 
	(IsColumnUserDefined=0 or IsColumnInUse=1)
	
	--Activity Fields
	SELECT D.SysColumnName,  D.CostCenterColID,'Activity_'+R.ResourceData ResourceData,D.ResourceID,D.IsMandatory, D.IsEditable, D.IsVisible,D.IsColumnInUse, D.SectionSeqNumber,      
	D.RowNo, D.ColumnNo, D.ColumnSpan,D.IsColumnUserDefined,D.TextFormat,D.ColumnDataType DataType, D.ColumnCCListViewTypeID,D.ColumnCostCenterID 
	,case when (D.SECTIONID IS NULL or D.SECTIONID=0 ) THEN ('Main') else (T.CCTabName) end as TabName  
	FROM ADM_COSTCENTERDEF D with(nolock) 
	LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID     
	LEFT JOIN ADM_COSTCENTERTAB T with(nolock) ON D.SECTIONID=T.CCTABID 
	WHERE D.CostCenterID=144 and D.LocalReference=@CostCenterID AND IsColumnInUse=1
	order by sectionseqnumber,ResourceData
	
	--For Groups
	SELECT DISTINCT CostCenterID,[CCTabID],b.ResourceData      
    ,[CCTabName],GroupOrder [TabOrder] , GroupVisible [IsVisible] , IsTabUserDefined   
	FROM [ADM_CostCenterTab] a with(nolock)           
    LEFT JOIN COM_LanguageResources b with(nolock) ON b.RESOURCEID=a.RESOURCEID    and b.languageid=@LangID      
	where a.CostCenterID=@CostCenterID       
	order by [GroupOrder]    
	
	IF(@CostCenterID in(95,129,103,104))
		SELECT CostCenterColId,resourceid, sectionseqnumber,UserColumnName,SysColumnName, SysTableName,UIWidth,IsVisible,IsMandatory,IsEditable,LinkData 
		FROM ADM_COSTCENTERDEF with(nolock) 
		WHERE CostCenterID=@CostCenterID and systablename in('REN_ContractParticulars','REN_ContractPayTerms','REN_QuotationParticulars','REN_QuotationPayTerms')
		order by sectionseqnumber,SysTableName
	ELSE IF(@CostCenterID =76)
		SELECT CostCenterColId,resourceid, sectionseqnumber,UserColumnName,SysColumnName, SysTableName,UIWidth,IsVisible,IsMandatory,IsEditable,LinkData 
		FROM ADM_COSTCENTERDEF with(nolock) 
		WHERE CostCenterID=@CostCenterID and systablename IN ('PRD_BOMProducts','PRD_Expenses','PRD_BOMResources')
		order by sectionseqnumber,SysTableName
	ELSE IF(@CostCenterID=115 or @CostCenterID=155 or @CostCenterID=154 or @CostCenterID=156 )     
		SELECT CostCenterColId,resourceid, sectionseqnumber,UserColumnName,SysColumnName, SysTableName,UIWidth,IsVisible,IsMandatory,IsEditable,LinkData 
		FROM ADM_COSTCENTERDEF with(nolock) 
		WHERE CostCenterID=@CostCenterID AND IsColumnUserDefined=1 AND IsColumnInUse=1  
		order by sectionseqnumber       
	ELSE
		SELECT ''
		
	SELECT QID,QName,CostCenterID FROM ADM_QuickViewDefn WITH(NOLOCK)   
	GROUP BY QID,QName,CostCenterID
	
	select CostCenterColID,Mode,Shortcut,SpName,IpParams,OpParams,Expression from ADM_DocFunctions WITH(NOLOCK)
	Where CostCenterID=@COSTCENTERID
	
	select LM.CostCenterId,LM.ListViewTypeID NodeID,LV.ListViewName Name from ADM_ListViewCCMap LM WITH(NOLOCK) JOIN ADM_ListView LV WITH(NOLOCK) ON LM.CostCenterID=LV.CostCenterID and LM.ListViewTypeID=LV.ListViewTypeID 
	Where LM.SourceCostCenterID=@CostCenterID
	
	 
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
