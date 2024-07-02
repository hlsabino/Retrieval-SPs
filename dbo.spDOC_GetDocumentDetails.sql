USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocumentDetails]
	@COSTCENTERID [int],
	@DocumentTypeID [int],
	@FLAG [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY                
SET NOCOUNT ON;              
    --Declaration Section              
  DECLARE @HasAccess BIT              
    
declare @TableName varchar(100)  
declare @Query varchar(Max)  
declare @CCID int  
  
  --SP Required Parameters Check              
  IF @DocumentTypeID=0              
  BEGIN              
   RAISERROR('-100',16,1)              
  END              
        
        
        SELECT @COSTCENTERID=COSTCENTERID FROM ADM_DocumentTypes               
		WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID
  --User access check               
    
	IF @FLAG=0              
	BEGIN                
		SELECT  DocumentPrefID,P.PrefValueType,L.ResourceData [Text],PrefDefalutValue,case when prefvaluetype ='CustomTextBox' or prefvaluetype ='BarcodeFormat' or		   prefvaluetype ='TextBox' THEN '0' else 'False' end Value,P.PrefName [DBText],P.PreferenceTypeName [Group],PrefRowOrder,PrefColOrder              
		FROM COM_DocumentPreferences P WITH(NOLOCK)                 
		LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=P.ResourceID  and LanguageID=@LangID                 
		where CostCenterID = (SELECT COSTCENTERID FROM ADM_DocumentTypes WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID)          
		ORDER BY P.PrefValueType  DESC  
		
		SELECT FEATUREID,NAME FROM ADM_FEATURES WITH(NOLOCK)       
		WHERE FEATUREID > 50000   and ISEnabled=1      

	END              
	ELSE              
	BEGIN                
		SELECT  DocumentPrefID,P.PrefValueType,PrefDefalutValue,L.ResourceData [Text],PrefValue Value,P.PrefName [DBText],P.PreferenceTypeName [Group],
		PrefRowOrder,PrefColOrder FROM COM_DocumentPreferences P WITH(NOLOCK)               
		LEFT JOIN COM_LanguageResources L WITH(NOLOCK) ON L.ResourceID=P.ResourceID  and LanguageID=@LangID              
		where CostCenterID=@COSTCENTERID      
		ORDER BY P.PrefValueType  DESC             

		--GETTING DOCUMENT INFO              
		IF @DocumentTypeID < 500001            
		BEGIN             
			SELECT *,CostCenterID as MENUID  FROM               
			ADM_DocumentTypes WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID              
		END             
		ELSE            
		BEGIN            
			SELECT * ,isnull(( SELECT MIN(FeatureID) FROM ADM_RibbonView WITH(NOLOCK)  WHERE DrpID = (SELECT DrpID FROM ADM_RibbonView WITH(NOLOCK)
			WHERE  FeatureID=CostCenterID ) ),CostCenterID)  as MENUID            
			FROM ADM_DocumentTypes WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID              
		END            
		   
		--GETTING CREDIT ACCOUNT AND DEBIT ACCOUNT FROM COSTCENTER DEF              
		if(@DocumentTypeID = 32 or @DocumentTypeID = 33 or @DocumentTypeID = 16 or @DocumentTypeID = 17)  
		begin  
			SELECT SYSCOLUMNNAME,UserProbableValues,USERDEFAULTVALUE,ResourceID FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID IN (SELECT COSTCENTERID FROM ADM_DocumentTypes               
			WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID) AND (SYSCOLUMNNAME = 'AccountID')              
		end  
		else  
		begin  
			SELECT SYSCOLUMNNAME,UserProbableValues,USERDEFAULTVALUE,ResourceID FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID IN (SELECT COSTCENTERID FROM ADM_DocumentTypes               
			WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID) AND (SYSCOLUMNNAME='CreditAccount' OR SYSCOLUMNNAME='DebitAccount' OR SYSCOLUMNNAME = 'CurrencyID')              
		end      
		          
		--Getting Costcenter Fields                
		SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,C.RowNo,C.ColumnNo,C.ColumnSpan,              
		C.UserDefaultValue,C.UserProbableValues,C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,              
		C.IsCostCenterUserDefined,isnull(C.UIwidth,100) UIWidth,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName,C.SectionSeqNumber,  C.IsUnique,    C.LINKDATA,   
		C.LOCALREFERENCE, case when C.LOCALREFERENCE=79 then 79 WHEN  (LOCCDF.COLUMNCOSTCENTERID=7 AND c.dependanton=-7) THEN c.dependanton else LOCCDF.COLUMNCOSTCENTERID end as LRCCID    ,   
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff, EvaluateAfter,DD.Distributeon,RoundOffLineWise,             
		DD.IsRoundOffEnabled,DD.IsDrAccountDisplayed,DD.IsCrAccountDisplayed,DD.IsDistributionEnabled,DD.DistributionColID,              
		DD.IsCalculate,DD.CrRefID,DD.CrRefColID,CR.SysColumnName as CRSysColumnName,CR.sectionid CRSection,DD.DrRefID,DD.DrRefColID,DR.SysColumnName as DRSysColumnName,DR.sectionid DrSection,C.Decimal,  
		C.TextFormat,C.Filter,DD.ShowbodyTotal,C.IsRepeat,c.isnotab,c.lastvaluevouchers,c.dependancy,CASE WHEN c.dependanton=-7 THEN NULL ELSE c.dependanton END dependanton ,C.IsTransfer
		,case when C.LOCALREFERENCE between 40000 and 50000 then (select UserColumnName from ADM_CostCenterDef CC with(nolock) where C.LINKDATA=CC.CostCenterColID) else Null end as VoucherName 
		,C.CrFilter,C.DbFilter,c.Calculate,DD.basedonXMl,Posting,c.IgnoreChar,IGC.Name IgnoreCharText,c.WaterMark,dd.FixedAcc,

		case when (c.columncostcenterid=44 and C.UserDefaultValue is not null and isnumeric(C.UserDefaultValue)=1) 
		then (select L.name from COM_LOOKUP L with(nolock) where L.NodeID=CONVERT(INT,C.UserDefaultValue) )
		else '' end as LookUpName,c.Cformula,IsPartialLinking,DD.distxml,c.MinChar,c.MaxChar

		FROM ADM_CostCenterDef C WITH(NOLOCK)              
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID              
		LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID               
		LEFT JOIN ADM_CostCenterDef LOCCDF WITH(NOLOCK) ON LOCCDF.CostCenterColID = C.LocalReference  
		 LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  C.IgnoreChar
		LEFT JOIN ADM_CostCenterDef DR WITH(NOLOCK) ON (DR.CostCenterColID = DD.DrRefID or DR.CostCenterColID = -DD.DrRefID) and  DD.DrRefID IS NOT NULL  
		LEFT JOIN ADM_CostCenterDef CR WITH(NOLOCK) ON (CR.CostCenterColID = DD.CrRefID or CR.CostCenterColID = -DD.CrRefID)  and  DD.CrRefID IS NOT NULL        
		WHERE C.CostCenterID  = @COSTCENTERID              
		AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND   
		(C.SysColumnName NOT LIKE '%dcCalcNum%') AND (C.SysColumnName NOT LIKE '%dcCurrID%') AND (C.SysColumnName NOT LIKE '%dcExchRT%')   AND (C.SysColumnName NOT LIKE '%dcCalcNumFC%')   AND (C.SysColumnName <> 'UOMConversion')   AND (C.SysColumnName <> 'UOMC
		onvertedQty')          
		ORDER BY  C.RowNo,C.ColumnNo  
		          
		 --select * from COM_LOOKUP           
		--getting Doc Prefix              
		select * from [COM_CostCenterCodeDef] WITH(NOLOCK) where [CostCenterID]=@COSTCENTERID
		          
		--Getting Fixed Doc Prefix              
		select * from COM_DocPrefix WITH(NOLOCK) where DocumentTypeID=@DocumentTypeID              
		order by seriesno,PrefixOrder              
		          
		--GETTING LINK DETAILS              
		SELECT C.IsQtyExecuted,C.AutoSelect,C.DocumentLinkDefID,C.[CostCenterColIDBase],C.[CostCenterIDLinked],C.[CostCenterColIDLinked],C.[IsDefault],C.[LinkedVouchers] ,A.DocumentName ,C.ViewID            
		FROM  [COM_DocumentLinkDef] C WITH(NOLOCK) 
		left join ADM_DocumentTypes A WITH(NOLOCK) on C.[CostCenterIDLinked]=A.CostCenterID  
		WHERE C.[CostCenterIDBase]=@COSTCENTERID    

		-- Local Reference Fields  
		SELECT  C.CostCenterColID,R.ResourceData,C.ColumnCostCenterID,C.SysColumnName  
		FROM ADM_CostCenterDef C WITH(NOLOCK)        
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID= @LangID       
		WHERE C.CostCenterID = (SELECT TOP 1 COSTCENTERID FROM ADM_DOCUMENTTYPES WITH(NOLOCK) WHERE DOCUMENTTYPEID =  @DocumentTypeID )    
		and (syscolumnname='accountid' or syscolumnname='productid' or syscolumnname='debitaccount' or syscolumnname='creditaccount'  
		or (syscolumnname like 'dcalpha%' and ColumnCostCenterID in(2,3) and IsColumnInUse=1))    
		union all  
		select FeatureID,R.ResourceData,FeatureID,R.ResourceData from ADM_Features f  WITH(NOLOCK) 
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=f.ResourceID AND R.LanguageID=@LangID  
		where FeatureID=79  

		SELECT Top 1 @CCID=CostCenterID    
		FROM ADM_DocumentTypes  WITH(NOLOCK)
		WHERE (DocumentTypeID = @DocumentTypeID)  

		select @TableName =tablename from adm_features  WITH(NOLOCK)
		where featureid=@CCID
		set @Query ='select Top 1 * from '+ @TableName +' WITH(NOLOCK) where CostCenterID='+ Convert(varchar(50),@CCID)  

		execute(@Query)  

		-- Getting BASE-LINE Details  
		SELECT * FROM COM_DocumentLinkDetails  WITH(NOLOCK) WHERE DocumentLinkDeFID in   
		(Select DocumentLinkDeFID from [COM_DocumentLinkDef] WITH(NOLOCK) WHERE [CostCenterIDBase]=@COSTCENTERID)    

		--ADDED ON JUN 27 2012 BY HAFEEZ  
		SELECT FEATUREID,NAME FROM ADM_FEATURES WITH(NOLOCK)       
		WHERE FEATUREID > 50000   and ISEnabled=1      
	END     
     
	select 1 where 1<>1
	     
	SELECT *,CostCenterID as MENUID  FROM ADM_DocumentTypes WITH(NOLOCK) WHERE DocumentType=26      

	select * from COM_DocumentDynamicMapping with(NOLOCK) where DocumentTypeID=@DocumentTypeID  

	--Budgets Assigned  
	select CONVERT(DATETIME,FromDate) FromDate_Key,CONVERT(DATETIME,ToDate) ToDate_Key,BudgetID Budget from ADM_DocumentBudgets with(NOLOCK) 
	where CostCenterID= @COSTCENTERID
	ORDER BY FromDate  

	--Copy Document
	SELECT Distinct C.CostCenterIDLinked,D.DocumentName,C.SelectionType,C.GridViewID 
	FROM  COM_CopyDocumentDetails C  WITH(NOLOCK) 
	inner join ADM_DocumentTypes D WITH(NOLOCK) on C.CostCenterIDLinked=D.CostCenterID  
	WHERE C.[CostCenterIDBase]=@COSTCENTERID

	SELECT a.*,b.UserColumnName FROM  COM_CopyDocumentDetails a WITH(NOLOCK) 
	join ADM_CostCenterDef b WITH(NOLOCK)  on a.CostCenterColIDLinked=b.CostCenterColID
	WHERE [CostCenterIDBase]=@COSTCENTERID

	--Get Temp Product Info details
	SELECT  C.TempProductColID,C.UserColumnName,C.SysColumnName,C.UserColumnType,C.ColumnDataType,
	C.RowNo,C.ColumnNo,C.ColumnSpan,isnull(C.SectionSeqNumber,0) SectionSeqNumber,        
	C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,C.IsDefault,         
	C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.RowNo,C.ColumnNo
	from com_doctempproductdef C WITH(NOLOCK)
	WHERE C.CostCenterID  =@COSTCENTERID
	AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)    
	ORDER BY  C.RowNo,C.ColumnNo  

	select distinct ProfileID,ProfileName from COM_DimensionMappings WITH(NOLOCK)

	select CostCenterColID,Mode,Shortcut,SpName,IpParams,OpParams,Expression from ADM_DocFunctions WITH(NOLOCK)
	Where CostCenterID=@COSTCENTERID

	SELECT CONVERT(DATETIME,LD.FromDate) FromDate_Key,CONVERT(DATETIME,LD.ToDate) ToDate_Key, LD.isEnable    
	FROM ADM_LockedDates LD WITH(NOLOCK)  
	WHERE CostCenterID=@COSTCENTERID

	select SrcDoc,linkedfrom,Fld from COM_DocLinkCloseDetails WITH(NOLOCK)
	where CostCenterID=@COSTCENTERID
	
	IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='')
	BEGIN
		set @Query ='Select C52.Name as ComponentName,C54.SNo From Com_CC50052 C52 With(Nolock) 
		inner join Com_CC50054 C54 With(Nolock) on C52.NodeID=C54.ComponentID 
		Where FieldType=''overtime'' And C54.GradeID=1	And C54.Payrolldate=(Select max(payrolldate) From Com_CC50054 with(nolock)) 
		order by C54.SNo'
		EXEC (@Query)
	END
	ELSE
		SELECT 1 WHERE 1<>1
	
	select ActualFileName,GUID,FileExtension from com_files  WITH(NOLOCK)
	where FeatureID=400 and FeaturePK=@COSTCENTERID
	
	select Name,convert(int,replace(Name,'dcAlpha','')) Ind from sys.columns where Name like 'dcAlpha%' and system_type_id=61
	and object_id=object_id('COM_DocTextData')
	
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
