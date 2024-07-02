USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCostCenterScreenDetails]
	@CostCenterID [int],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1,
	@CompanyID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION                                 
BEGIN TRY                                
SET NOCOUNT ON;                              
	--Declaration Section                              
	DECLARE @HasAccess BIT,@DocViewID INT, @SQL NVARCHAR(MAX),@TableName varchar(300)
	DECLARE @code nvarchar(200),@no INT,@GridviewID INT,@temp varchar(300)
	                         
	                        
	--SP Required Parameters Check                              
	IF @CostCenterID=0                              
	BEGIN                              
		RAISERROR('-100',16,1)                              
	END                              
  
	if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and UserID=@UserID)                      
	begin                      
		set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and  UserID=@UserID)                      
	end                      
	else if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and RoleID=@RoleID)
	begin                      
		set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and  RoleID=@RoleID)
	end                      
	else if exists(select DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and GroupID in (select GID from COM_Groups with(nolock) where UserID=@UserID or RoleID=@RoleID))
	begin                      
		set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap with(nolock) where CostCenterID=@CostCenterID and GroupID in (select GID from COM_Groups with(nolock) where UserID=@UserID or RoleID=@RoleID))
	end
	
  	--Getting Costcenter Fields       
	SELECT  distinct C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,                              
	C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,isnull(C.IsVisible,1) IsVisible,C.ColumnCCListViewTypeID,                              
	C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName , C.RowNo,C.ColumnNo, C.ColumnSpan,C.TextFormat,C.SectionSeqNumber
	,c.dependancy,c.dependanton,IGC.Name IgnoreChars,C.WaterMark
    ,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=C.ColumnCostCenterID and  syscolumnname='ccnid'+convert(nvarchar,(c.dependanton-50000))) as filterinuse,
    C.SysTableName,C.UIWidth,C.LocalReference,C.LinkData,C.IsnoTab,C.Decimal,DD.DistributeOn,LR.SysColumnName as ReservedWordType,C.MinChar,C.MaxChar,isnull(C.FieldExpression,'') FieldExpression,isnull(C.LabelColor,'') LabelColor
    ,DF.Mode,DF.SpName,DF.Shortcut,DF.IpParams,DF.OpParams,DF.Expression,c.Calculate,c.Cformula,C.EvalAfter
	FROM ADM_CostCenterDef C WITH(NOLOCK)                              
	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
	LEFT JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterID=C.CostCenterID AND DD.CostCenterColID=C.CostCenterColID 
	LEFT JOIN ADM_CostCenterDef LR WITH(NOLOCK) ON LR.CostCenterID=79 AND LR.CostCenterColID=C.LinkData  
	LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  c.IgnoreChar       
	LEFT JOIN ADM_DocFunctions DF WITH(NOLOCK) ON  DF.CostCenterColID=  C.CostCenterColID AND DF.CostCenterID=C.CostCenterID                     
	WHERE C.CostCenterID = @CostCenterID  and C.SysColumnName not in ('Depth','ParentID')                             
	AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)                              
	ORDER BY C.SectionID,C.SectionSeqNumber--,C.CostCenterColID
	
	SELECT 1 AS ColID  WHERE 1<>1
	SELECT 1 AS ColID  WHERE 1<>1
                                 
  --Getting Costcenter Status.        
	if(@CostCenterID=124)
		SELECT S.StatusID,R.ResourceData AS [Status],[Status] as ActualStatus                              
		FROM COM_Status S WITH(NOLOCK)                              
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
		WHERE CostCenterID = 88                         
	else if(@CostCenterID=104)                       
		SELECT S.StatusID,R.ResourceData AS [Status],[Status] as ActualStatus                              
		FROM COM_Status S WITH(NOLOCK)                              
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
		WHERE CostCenterID = 95
	else if(@CostCenterID=103)                       
		SELECT S.StatusID,R.ResourceData AS [Status],[Status] as ActualStatus                              
		FROM COM_Status S WITH(NOLOCK)                              
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
		WHERE S.StatusID in (426,468)
	else
		SELECT S.StatusID,R.ResourceData AS [Status],[Status] as ActualStatus
		FROM COM_Status S WITH(NOLOCK)
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID
		WHERE CostCenterID = @CostCenterID 
		ORDER BY S.StatusID
                  
	IF @CostCenterID=3--Start Product                              
	BEGIN 
		--Getting Product Type.                      
		IF EXISTS(SELECT FeatureTypeID from  ADM_FeatureTypeValues FT WITH(NOLOCK)                     
		WHERE FT.CostCenterID=3 AND   FT.UserID=@UserID)                              
		BEGIN                                 
			--Getting Account Type.on user                                
			SELECT T.ProductTypeID,R.ResourceData AS ProductType                              
			FROM INV_ProductTypes T WITH(NOLOCK)                               
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON T.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
			WHERE T.[Status]='Active' and T.ProductTypeID IN                              
			(SELECT FeatureTypeID from  ADM_FeatureTypeValues FT WITH(NOLOCK)                     
			WHERE FT.CostCenterID=3 AND   FT.UserID=@UserID)                          
		END                              
		ELSE IF EXISTS(SELECT FeatureTypeID from  ADM_FeatureTypeValues FT WITH(NOLOCK)                     
		WHERE FT.CostCenterID=3 AND   FT.RoleID=@RoleID)
		BEGIN                            
			SELECT T.ProductTypeID,R.ResourceData AS ProductType                              
			FROM INV_ProductTypes T WITH(NOLOCK)                               
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON T.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
			WHERE T.[Status]='Active' and T.ProductTypeID IN                              
			(SELECT FeatureTypeID from  ADM_FeatureTypeValues FT WITH(NOLOCK)                     
			WHERE FT.CostCenterID=3 AND   FT.RoleID=@RoleID)
		END                              
		ELSE                              
		BEGIN                      
			SELECT T.ProductTypeID,R.ResourceData AS ProductType                              
			FROM INV_ProductTypes T WITH(NOLOCK)                               
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON T.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
			WHERE T.[Status]='Active'                              
		end                       
   
		--Getting Product Groups.                              
		DECLARE @GroupCode SYSNAME=(SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='ProductGroup Based On')
		IF(@GroupCode='Name') 
		BEGIN                          
			SELECT ProductID,ProductCode,ProductName,AliasName                               
			FROM INV_Product WITH(NOLOCK)                              
			WHERE IsGroup = 1 
		END
		ELSE IF(@GroupCode='Code')
		BEGIN
			SELECT ProductID,ProductCode,ProductCode ProductName,AliasName                               
			FROM INV_Product WITH(NOLOCK)                              
			WHERE IsGroup = 1
		END                               
                              
		--Valuation Methods                              
		SELECT V.ValuationID,R.ResourceData AS ValuationMethod                              
		FROM INV_ValuationMethods V WITH(NOLOCK)                  
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON V.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
		                          
		--Getting Currency.                              
		SELECT CurrencyID,Name,Symbol,Change,ExchangeRate,Decimals,IsBaseCurrency                               
		FROM COM_Currency WITH(NOLOCK)                              
		                          
		--Getting Barcode.                              
		--SELECT BarcodeID,BarcodeName,Definition FROM INV_BarcodeDef WITH(NOLOCK)                              
		select 1 BarcodeRemoved where 1!=1
		                          
		--Getting BarcodeLayouts.                     
		select BarcodeLayoutID, Name from ADM_DocBarcodeLayouts WITH(NOLOCK) where costcenterid=17                           
		                              
		--Getting Preference                              
		SELECT Name,Value from COM_CostCenterPreferences WITH(NOLOCK) WHERE COSTCENTERID=3                                 
		                             
		--Getting default Code                              
		--EXEC [spCOM_GetCode] @CostCenterID,'PARENT',@code OUTPUT,@no OUTPUT                              
		SELECT 'DEFAULTCODE'--SELECT @code                              
		                          
		--Getting list of cost center names                              
		SELECT FEATUREID,NAME FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID>50000                         
		                      
		select UOMID,UnitName,BaseName,BaseID from COM_UOM  WITH(NOLOCK) WHERE (PRODUCTID=0 OR PRODUCTID IS NULL) AND (ISPRODUCTWISE=0 OR IsProductWise IS NULL)                        
    
		declare @GrpImage bit,@ImageDimCCID INT
		SELECT @GrpImage=convert(bit,Value) from  COM_CostCenterPreferences WITH(NOLOCK) WHERE                        
		CostCenterID=3 and Name='InheritGroupImage'     
		SELECT @ImageDimCCID=convert(INT,isnull(Value,0)) from  COM_CostCenterPreferences WITH(NOLOCK) WHERE                        
		CostCenterID=3 and Name='InheritDimensionImage'                   
		if(@GrpImage=1)
			 SELECT * FROM  COM_Files WITH(NOLOCK) 
			 join INV_Product p WITH(NOLOCK) on COM_Files.FeatureID=3 and FeaturePK =p.ProductID
			 WHERE  IsProductImage=1  and p.IsGroup=1
		else if(@ImageDimCCID>50000)
			 SELECT * FROM  COM_Files WITH(NOLOCK) WHERE  IsProductImage=1 and featureID=@ImageDimCCID
		else
			 select 1  where 1=2                       
	END--End Product                                                 
	ELSE IF @CostCenterID=2--Start ACCOUNT                              
	BEGIN 
		IF EXISTS(SELECT FeatureTypeID from  ADM_FeatureTypeValues FT WITH(NOLOCK)                     
		WHERE FT.CostCenterID=2 AND   FT.UserID=@UserID )                              
		BEGIN
			--Getting Account Type.on user                                
			SELECT AccountTypeID,ResourceData,AccountType,Status                               
			FROM ACC_AccountTypes A WITH(NOLOCK)                               
			JOIN COM_LanguageResources R WITH(NOLOCK) ON A.ResourceID=R.ResourceID                              
			WHERE LanguageID=@LangID AND AccountTypeID IN                              
			(SELECT FeatureTypeID from  ADM_FeatureTypeValues FT WITH(NOLOCK)                     
			WHERE FT.CostCenterID=2 AND   FT.UserID=@UserID )        ORDER BY A.ACCOUNTTYPE                        
		END
		ELSE IF EXISTS(SELECT FeatureTypeID from  ADM_FeatureTypeValues FT WITH(NOLOCK)                     
		WHERE FT.CostCenterID=2 AND   FT.RoleID=@RoleID)                              
		BEGIN
			--Getting Account Type. on User Role group                              
			SELECT AccountTypeID,ResourceData,AccountType,Status
			FROM ACC_AccountTypes A WITH(NOLOCK)
			JOIN COM_LanguageResources R WITH(NOLOCK) ON A.ResourceID=R.ResourceID
			WHERE LanguageID=@LangID AND AccountTypeID IN
			(SELECT FeatureTypeID from  ADM_FeatureTypeValues FT WITH(NOLOCK)
			WHERE FT.CostCenterID=2 AND   FT.RoleID=@RoleID)        ORDER BY A.ACCOUNTTYPE
		END
		ELSE
		BEGIN
			--Getting Account Type.                              
			SELECT AccountTypeID,ResourceData,AccountType,Status
			FROM ACC_AccountTypes A WITH(NOLOCK)
			JOIN COM_LanguageResources R WITH(NOLOCK) ON A.ResourceID=R.ResourceID
			WHERE LanguageID=@LangID      ORDER BY A.ACCOUNTTYPE
		END

		--Getting Preference                              
		select Name,Value from  COM_CostCenterPreferences WITH(NOLOCK) WHERE COSTCENTERID=2                              
		--Getting Currency.                              
		SELECT CurrencyID,Name,Symbol,Change,ExchangeRate,Decimals,IsBaseCurrency                               
		FROM COM_Currency WITH(NOLOCK)

		select * from Acc_PaymentDiscountProfile WITH(NOLOCK) 
	END--End ACCOUNT    
	ELSE IF @CostCenterID=12
	BEGIN 
		if exists(SELECT Name,Value from COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID and Name='UseCurrencyLookup' and Value='True')
		begin
			select NodeID CurrLookupID,Code,Name,AliasName Change from COM_Lookup with(nolock) where LookupType=69 order by Name
		end
		else
		begin
			select 0 NoLookup where 1!=1
		end		
	END         
	ELSE IF @CostCenterID=16--Start Batches                              
	BEGIN 
		--Getting Product Groups.                              
		SELECT BatchID,BatchNumber                               
		FROM INV_Batches WITH(NOLOCK)                              
		WHERE IsGroup = 1                              
	                              
		--Getting Preference                              
		SELECT Name,Value from COM_CostCenterPreferences with(nolock) where CostCenterID=16                            
	                                 
		EXEC [spCOM_GetCode] 16,'PARENT',@code OUTPUT,@no OUTPUT                              
		SELECT @code 
	   
		select DocumentID,Filter FROM ADM_BatchDefinition WITH(NOLOCK)      
	 	
		SELECT @GridviewID=ParentNodeID FROM COM_CostCenterCostCenterMap a WITH(NOLOCK) 
		join ADM_GridView b WITH(NOLOCK) on a.ParentNodeID=b.GridViewID and b.CostCenterID=16
		WHERE ParentCostCenterID=26 AND a.CostCenterID=6 AND NodeID=@RoleID
		if not exists(SELECT GridViewID FROM [ADM_GridView] with(nolock)  WHERE GridViewID =@GridviewID and CostCenterID=16)
			set @GridviewID=300
			
		select a.CostCenterID, a.CostCenterColID,  UserColumnName,  case when SysColumnName='ExpiryDate' then 'ExpDate'
		when SysColumnName='MRPRate' then 'MRate'
		when SysColumnName='RetailRate' then 'RRate'
		when SysColumnName='StockistRate' then 'SRate'
		when SysColumnName='HoldQuantity' then 'Hold'
		when SysColumnName='ReleaseQuantity' then 'Release' else SysColumnName end Name,
		UserColumnType, g.ColumnWidth, g.ColumnOrder, A.IsEditable                        
		from adm_costcenterdef a  with(nolock)
		join ADM_GridViewColumns g with(nolock) on a.CostCenterColID=g.CostCenterColID and g.GridViewID=@GridviewID           
		where a.CostCenterID=16                                                
		order by g.ColumnOrder
	END                              
	ELSE IF @CostCenterID=4--Start Batches                              
	BEGIN 
		--Getting Product Groups.                              
		SELECT CompanyID,DBIndex,Code,Name                              
		FROM  [PACT2C].dbo.ADM_Company WITH(NOLOCK)                              
	END                       
	ELSE IF @CostCenterID IN (76,94,1000)
	BEGIN 
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                         
	END                                                                                
	ELSE IF @CostCenterID=84                  
	BEGIN 
	SET @SQL='SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+'                        
		SELECT SVcContractID,DOCID,StatusID                         
		FROM CRM_ServiceContract WITH(NOLOCK)                              
		WHERE IsGroup = 1' 
	EXEC (@SQL)                           
	END                          
	ELSE IF @CostCenterID=144                        
	BEGIN 
		SELECT FeatureID, Name FROM ADM_Features with(nolock) WHERE  (FeatureID >= 50001) AND (IsEnabled = 1) OR (FeatureID < 50001) ORDER BY Name                                           
	END                     
	ELSE IF @CostCenterID=57 --Shop Supply---                        
	BEGIN 
		select * From COM_Lookup with(nolock) where LookupType=11                         
	END                     
	ELSE IF @CostCenterID=111 --Asset Management---                       
	BEGIN 
		select * from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID                        
	END                       
	ELSE IF @CostCenterID=99 or @CostCenterID=159 --bill wise--                       
	BEGIN 
		SELECT FeatureID CostCenterID,Name UserColumnName,Name,'TEXT' UserColumnType, g.ColumnWidth, g.ColumnOrder, 'False' IsEditable                        
		FROM ADM_Features a with(nolock) join                         
		ADM_GridViewColumns g with(nolock) on a.FeatureID=g.CostCenterColID and g.GridViewID in                         
		(select gridviewid from adm_gridview with(nolock) where costcenterid=@CostCenterID)                        
		WHERE  IsEnabled=1  and FeatureID>50000                         
		AND FeatureID  IN (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (                        
		SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=@CostCenterID))                        
		union                        
		select a.CostCenterColID,  UserColumnName, SyscolumnName Name, UserColumnType, g.ColumnWidth, g.ColumnOrder, A.IsEditable                        
		from adm_costcenterdef a with(nolock) join                         
		ADM_GridViewColumns g with(nolock) on a.CostCenterColID=g.CostCenterColID and g.GridViewID in                         
		(select gridviewid from adm_gridview with(nolock) where costcenterid=@CostCenterID)                        
		where a.CostCenterID=@CostCenterID and a.CostcenterColID                         
		in (SELECT CostCenterColID FROM [ADM_GridViewColumns] with(nolock) WHERE GRIDVIEWID IN (                        
		SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=@CostCenterID))                        
		order by g.ColumnOrder  
	    
		SELECT ColumnWidth FROM [ADM_GridViewColumns] WITH(NOLOCK) WHERE GRIDVIEWID IN (                        
		SELECT GRIDVIEWID FROM [ADM_GridView] with(nolock) WHERE [CostCenterID]=@CostCenterID)
		and CostCenterColID=0                        
	                           
	END                                          
	ELSE IF @CostCenterID=200 --RevenU Report---                       
	BEGIN 
		select * From ADM_RevenUReports with(nolock) where IsGroup=1                         
	END                        
	ELSE IF @CostCenterID=78                        
	BEGIN 
                        
		SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,                              
		C.UserDefaultValue,C.UserProbableValues,isnull(C.IsMandatory,0) IsMandatory,isnull(C.IsEditable,1) IsEditable,isnull(C.IsVisible,1) IsVisible,C.ColumnCCListViewTypeID,                              
		C.IsCostCenterUserDefined,C.IsColumnUserDefined,C.ColumnCostCenterID,C.FetchMaxRows,C.SectionID,C.SectionName                              
		FROM ADM_CostCenterDef C WITH(NOLOCK)                              
		LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID                              
		WHERE C.CostCenterID = 87                               
		AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)                              
		ORDER BY C.CostCenterColID                          

		SELECT S.StatusID,R.ResourceData AS Status,Status as ActualStatus                              
		FROM COM_Status S WITH(NOLOCK)                              
		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID                              
		WHERE CostCenterID = 87                        
		--Getting Preference                              
		SELECT Name,Value from  COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterID                              

		select DocumentLinkDefID,DocumentName,CostCenterIDBase,[CostCenterColIDBase]                            
		,[CostCenterIDLinked],[CostCenterColIDLinked],[IsDefault]                            
		from COM_DocumentLinkDef a     WITH(NOLOCK)                         
		join ADM_DocumentTypes b with(nolock) on a.[CostCenterIDLinked]=b.CostCenterID                            
		where CostCenterIDBase=78                           

		EXEC [spCOM_GetCode] @CostCenterID,'PARENT',@code OUTPUT,@no OUTPUT                              
		SELECT @code                          

		declare @RctCCID int,@IssCCID int,@IssPrefValue nvarchar(50),@RcvPrefValue nvarchar(50)                        
		SELECT @RctCCID=convert(int,Value) from  COM_CostCenterPreferences with(nolock) WHERE                        
		CostCenterID=78 and Name='DocRCT'                          

		SELECT @IssCCID=convert(int,Value) from  COM_CostCenterPreferences with(nolock) WHERE                        
		CostCenterID=78 and Name='DocIssue'                          

		select l.ResourceData from ADM_RibbonView dr   WITH(NOLOCK)                         
		left join COM_LanguageResources l  WITH(NOLOCK) on l.ResourceID=dr.ScreenResourceID and l.LanguageID=@LangID                        
		where dr.FeatureID=@RctCCID                        

		Select @IssPrefValue=PrefValue from COM_DocumentPreferences with(nolock)
		where CostCenterID=@IssCCID    and PrefName='DonotupdateAccounts'                        

		Select @RcvPrefValue=PrefValue from COM_DocumentPreferences with(nolock)
		where CostCenterID=@RctCCID    and PrefName='DonotupdateAccounts'                        

		SELECT @IssPrefValue UpdateAcc,C.CostCenterColID,C.UserDefaultValue,C.SysColumnName,DD.Formula,DD.DebitAccount,DD.CreditAccount,DD.PostingType,DD.CrRefID,DD.CrRefColID,CR.SysColumnName as CRSysColumnName,                        
		CR.sectionid CRSection,DD.DrRefID,DD.DrRefColID,DR.SysColumnName as DRSysColumnName,DR.sectionid DrSection                        
		FROM ADM_CostCenterDef C WITH(NOLOCK)                            
		left JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=C.CostCenterColID                             
		LEFT JOIN ADM_CostCenterDef DR with(nolock) ON DR.CostCenterColID = DD.DrRefID and  DD.DrRefID IS NOT NULL                        
		LEFT JOIN ADM_CostCenterDef CR with(nolock) ON CR.CostCenterColID = DD.CrRefID  and  DD.CrRefID IS NOT NULL                        
		WHERE C.CostCenterID = @IssCCID and ((C.SysColumnName='ProductID' and C.UserColumnName='Product Name') or C.SysColumnName='Gross' or  C.SysColumnName='Rate' or C.SysColumnName='DebitAccount' or C.SysColumnName='CreditAccount')                        

		SELECT @IssCCID=convert(int,Value) from  COM_CostCenterPreferences with(nolock) WHERE                        
		CostCenterID=78 and Name='DocReturn' 

		Select @IssPrefValue=PrefValue from COM_DocumentPreferences with(nolock)
		where CostCenterID=@IssCCID    and PrefName='DonotupdateAccounts'                        

		SELECT case when C.CostCenterID=@RctCCID THEN @RcvPrefValue when C.CostCenterID=@IssCCID THEN @IssPrefValue END UpdateAcc,C.CostCenterID,C.CostCenterColID,C.UserDefaultValue,C.SysColumnName,DD.Formula,DD.DebitAccount,DD.CreditAccount,DD.PostingType,DD.CrRefID,DD.CrRefColID,CR.SysColumnName as CRSysColumnName,                        
		CR.sectionid CRSection,DD.DrRefID,DD.DrRefColID,DR.SysColumnName as DRSysColumnName,DR.sectionid DrSection                        
		FROM ADM_CostCenterDef C WITH(NOLOCK)                            
		left JOIN ADM_DocumentDef DD with(nolock) ON DD.CostCenterColID=C.CostCenterColID                             
		LEFT JOIN ADM_CostCenterDef DR with(nolock) ON DR.CostCenterColID = DD.DrRefID and  DD.DrRefID IS NOT NULL                        
		LEFT JOIN ADM_CostCenterDef CR with(nolock) ON CR.CostCenterColID = DD.CrRefID  and  DD.CrRefID IS NOT NULL                        
		WHERE C.CostCenterID in(@RctCCID,@IssCCID) and ( (C.SysColumnName='ProductID' and C.UserColumnName='Product Name' ) or C.SysColumnName='Gross' or  C.SysColumnName='DebitAccount' or C.SysColumnName='CreditAccount')                        

		SET @SQL='
		select distinct PRD_ProductionMethod.BOMID,PRD_ProductionMethod.Particulars,PRD_BillOfMaterial.BOMName,PRD_ProductionMethod.SequenceNo from PRD_ProductionMethod with(nolock)                        
		left join PRD_BillOfMaterial with(nolock) on PRD_ProductionMethod.BOMID=PRD_BillOfMaterial.BOMID  order by PRD_ProductionMethod.SequenceNo'
		EXEC (@SQL)                                            
	END       
	ELSE IF @CostCenterID=117
	BEGIN 
		SELECT DashBoardID,DashBoardName,DashBoardName from ADM_DashBoard with(nolock) where IsGroup=1
	END                     
	ELSE IF @CostCenterID<>7 and @CostCenterID<>84 and @CostCenterID<>61 and @CostCenterID<>12 and @CostCenterID<>74 and @CostCenterID<>71 and @CostCenterID<>75 and @CostCenterID<>77 and @CostCenterID<>72 and                         
	@CostCenterID<>81 and  @CostCenterID<>83 and @CostCenterID<>65 and @CostCenterID<>68 and @CostCenterID<>114             and @CostCenterID<>124           
	and @CostCenterID<>93 and @CostCenterID<>95 and @CostCenterID<>251 and @CostCenterID<>252 and @CostCenterID<>253 and @CostCenterID<>254 and @CostCenterID<>255 and @CostCenterID<>110 and @CostCenterID<>103 and @CostCenterID<>129 and @CostCenterID<>104  and @CostCenterID<>73 and @CostCenterID<>88 and @CostCenterID<>86 and @CostCenterID<>89 and @CostCenterID<>92 and @CostCenterID<>94 and @CostCenterID<>119-- FOR ANY COSTCENTER TO GET GROUPS.                          
	AND @CostCenterID<>40054 AND @CostCenterID<>1000 AND @CostCenterID<>40088
	BEGIN 
		set @TableName =(SELECT top 1 TableName FROM ADM_Features with(nolock) WHERE FeatureID= @CostCenterID)                           
		if @CostCenterID>50000 and @userid!=1 and exists (select Name,Value from ADM_GlobalPreferences with(nolock) where Name='Dimension List' and value like '%'+convert(nvarchar(10),@CostCenterID)+'%')
		begin
			set @SQL='SELECT A.NODEID,A.CODE,A.[NAME] FROM '+@TableName+' A WITH(NOLOCK) 
	left JOIN (select CMI.NodeID,CMI.lft,CMI.rgt from '+@TableName+' CMI with(nolock)
	JOIN COM_CostCenterCostCenterMap CCMU with(nolock) on CCMU.CostCenterID='+convert(nvarchar,@CostCenterID)+' 
	and CCMU.ParentCostCenterID=7 and CCMU.ParentNodeID in ('+convert(nvarchar,@userid)+') and CMI.NodeID=CCMU.NodeID
	) as CMI ON a.lft between CMI.lft and CMI.rgt
	WHERE A.IsGroup=1 and (a.lft=1 or CMI.lft is not null or A.CreatedBy=(SELECT USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE USERID='+CONVERT(NVARCHAR(40),@UserID)+'))
	order by A.lft desc'
		end
		else
		begin
			set @SQL='SELECT A.NODEID,A.CODE,A.[NAME] FROM '+@TableName+' A WITH(NOLOCK) WHERE A.IsGroup=1'
		end
	--	print(@SQL)                     
	   EXEC(@SQL)                              
	   --Getting Preference                              
	   set @SQL='SELECT Name,Value from  COM_CostCenterPreferences with(nolock) 
	   WHERE CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' or (CostCenterID=3 and Name=''BinsDimension'')'
	   
		IF(@CostCenterID=(SELECT Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=3 and Name='BinsDimension')
			OR @CostCenterID=(SELECT Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='PackDimension'))
			set @SQL=@SQL+' UNION
			SELECT Name,Value FROM COM_CostCenterPreferences WITH(NOLOCK) 
			WHERE CostCenterID=3 and Name IN (''LengthDecimals'',''WidthDecimals'',''HeightDecimals'',''WeightDecimals'',''VolumeDecimals'')'
		print(@SQL)        
		EXEC(@SQL)  
	                               
	   SELECT 'DEFAULTCODE' --SELECT @code                              
	END                              
	ELSE IF @CostCenterID=75                        
	BEGIN 
		SELECT DepreciationMethodID, Name  FROM ACC_DepreciationMethods with(nolock)                     
	END
	ELSE IF @CostCenterID=74
	BEGIN 
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE (CostCenterID=74 or (CostCenterID=72 and Name='ChangeOfFAAccountsNode' and Value='False'))
	END                       
	ELSE IF @CostCenterID=72 
	BEGIN 
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                        
	                        
		--Getting AssetMANAGAMENT Groups.                              
		SELECT AssetID,AssetCode,AssetName                               
		FROM ACC_Assets WITH(NOLOCK)                              
		WHERE IsGroup = 1                         
	END                        
	ELSE IF @CostCenterID=71                          
	BEGIN
		SET @SQL=' 
		SELECT RESOURCENAME,RESOURCECODE,COM_Status.Status FROM PRD_Resources with(nolock)
		LEFT JOIN COM_STATUS with(nolock) ON PRD_Resources.StatusID=COM_Status.StatusID'                         
	    EXEC (@SQL)                    
		SELECT Name,Value from  COM_CostCenterPreferences WHERE CostCenterID=@CostCenterID                              
	                                 
		EXEC [spCOM_GetCode] @CostCenterID,'PARENT',@code OUTPUT,@no OUTPUT                              
		SELECT @code                            
	END                          
	ELSE IF @CostCenterID=73                        
	BEGIN 
		--Get Contact Types, Salutations, Roles, Countries                        
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                              
		select NodeID,Name,IsDefault,[Status] IsVisible from COM_LookUp with(nolock) where LookUpType=60 
		                          
		select * from COM_LookUp with(nolock) where LookUpType=43                        
	END
	ELSE IF @CostCenterID=89                        
	BEGIN 
		--Get Contact Types, Salutations, Roles, Countries                        
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                              
		select * from COM_Status with(nolock) where CostCenterID=86     
		declare @Value nvarchar(300)
		set @Value=(select Value from Com_CostCenterPreferences with(nolock) where name='StatusProbability')
  
		if(@Value is not null)
		begin
			declare @table1 table(TypeID nvarchar(50))
			insert into @table1
			exec SPSplitString @Value,';'
			  
			select reverse(parsename(replace(reverse(TypeID),'-','.'),1)) as [Status],
					  reverse(parsename(replace(reverse(TypeID),'-','.'),2)) as [Probability],
					  L.Name Probability_Key from (select TypeID from @table1) as [Table]
					  join com_lookup l with(nolock) on l.NodeID=reverse(parsename(replace(reverse(TypeID),'-','.'),2))
		end                     
                         
	END                        
	ELSE IF @CostCenterID=81                          
	BEGIN
	SET @SQL=' 
		SELECT CTemplCode,CTemplName,COM_Status.Status FROM CRM_ContractTemplate with(nolock)                   
		LEFT JOIN COM_STATUS with(nolock) ON CRM_ContractTemplate.StatusID=COM_Status.StatusID'
	EXEC (@SQL)
	SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                
		EXEC [spCOM_GetCode] @CostCenterID,'PARENT',@code OUTPUT,@no OUTPUT                              
		SELECT @code                              
		                     
		select * from com_lookup with(nolock) where LookupType=42                        
	END                       
	ELSE IF @CostCenterID=83                        
	BEGIN 
	SET @SQL='
		SELECT CustomerCode,CustomerName,COM_Status.Status FROM CRM_Customer with(nolock)                        
		LEFT JOIN COM_STATUS with(nolock) ON CRM_Customer.StatusID=COM_Status.StatusID'                         
	EXEC (@SQL)
	   SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                                                 
	END              
	ELSE IF @CostCenterID=88 or @CostCenterID=124                    
	BEGIN
	SET @SQL=' 
		SELECT Code,Name,COM_Status.Status FROM CRM_Campaigns with(nolock)                        
		LEFT JOIN COM_STATUS with(nolock) ON CRM_Campaigns.StatusID=COM_Status.StatusID'                         
	EXEC(@SQL)
	
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                           
	END                          
	ELSE IF @CostCenterID=86                        
	BEGIN 
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                           
		select * from COM_Status with(nolock) where CostCenterID=86                        
		SELECT * FROM COM_Lookup  with(nolock)                       
	END      
    ELSE IF @CostCenterID=93                        
	BEGIN 
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=92 
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                        
	END     
	ELSE IF @CostCenterID=92                        
	BEGIN 
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                    
		SELECT * FROM COM_Lookup with(nolock) where lookuptype=36      
		SELECT * FROM COM_Lookup with(nolock) where lookuptype=63                       
	END                    
	ELSE IF (@CostCenterID=95 or @CostCenterID=103 OR  @CostCenterID=104 or @CostCenterID=129)            
	BEGIN 
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=92 or CostCenterID=129
		SELECT Name,Value,CostCenterID from  COM_CostCenterPreferences with(nolock)
		WHERE CostCenterID in (95,@CostCenterID) or name like '%LinkDocument%' or name ='PurchaseCheckNumbersForRent' 
            
		select @TableName = TableName  from ADM_Features  with(nolock)              
		where FeatureID= (SELECT Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=95 AND Name='PostDocStatus')              

		set @code=''
		SELECT @code=Value from  COM_CostCenterPreferences with(nolock)
		WHERE CostCenterID=95 AND Name='DefaultContractDocStatus' and Value is not null and ISNUMERIC(value)=1             

		if(@code<>'')
		BEGIN
			set @SQL ='SELECT @code=Name from '+@TableName+' WITH(NOLOCK) where NodeID='+@code  
			exec Sp_executesql @SQL,N' @code nvarchar(max) output',@code output
		END
		if exists(select * from adm_globalpreferences with(nolock) where name ='VATVersion')			
		BEGIN	
			set @SQL ='SELECT @TableName=Name from com_cc50060 WITH(NOLOCK) where NodeID=3
					  SELECT @temp=Name from com_cc50060 WITH(NOLOCK) where NodeID=1'
			exec Sp_executesql @SQL,N' @TableName nvarchar(max) output,@temp nvarchar(max) output',@TableName output,@temp output
		END
		ELSE
		BEGIN
			set @TableName=''
			set @temp=''
		END	
		
		SELECT @no=NodeID  FROM COM_LOOKUP with(nolock)                   
		WHERE LOOKUPTYPE = 46 AND NAME  = 'Normal'
		
		set @GridviewID=0
		select @GridviewID=value from ADM_GlobalPreferences with(nolock)                        
		where  Name='DepositLinkDimension' and value is not null and isnumeric(value)=1
		
		set @Sql=''
		SELECT @Sql=@Sql+ convert(nvarchar,PropertyID)+',' FROM  [ADM_PropertyUserRoleMap] with(nolock)
		where Userid  =  @UserID or RoleID=@RoleID
	
		declare @SNO INT
		
		IF (@CostCenterID=95 OR  @CostCenterID=104)
		BEGIN
			SET @SQL='select @SNO=isnull(Max(SNO),0)+1  
			from  REN_Contract WITH(NOLOCK)   WHERE   CostCenterID ='+CONVERT(NVARCHAR,@CostCenterID)
			EXEC sp_executesql @SQL,N'@SNO INT OUTPUT',@SNO OUTPUT
		END
		else IF (@CostCenterID=103 OR @CostCenterID=129)
		BEGIN
		SET @SQL='select @SNO=isnull(Max(SNO),0)+1  
			from  REN_Quotation WITH(NOLOCK) WHERE CostCenterID ='+CONVERT(NVARCHAR,@CostCenterID)+'AND StatusID<>430'
			EXEC sp_executesql @SQL,N'@SNO INT OUTPUT',@SNO OUTPUT
		END
		IF (@SNO IS NULL OR @SNO='' OR @SNO=0)
			SET @SNO=1
			
		select @SNO SNO ,@code Name,@no NormalUnit,@GridviewID DepositLinkDimension,@Sql Properties,@TableName TCVat,@temp TcExcemt

		SELECT NodeID,Name,isdefault FROM COM_Lookup WITH(NOLOCK) WHERE LookupType=46    
		
		SELECT NodeID PayeeBank ,Name PayNodeID  FROM COM_LOOKUP  with(nolock)                  
		WHERE LOOKUPTYPE = 48  ORDER BY Name            

		SELECT ACCOUNTID,ACCOUNTTYPEID FROM ACC_ACCOUNTS with(nolock)
		WHERE ACCOUNTTYPEID IN (1,2,3) and ACCOUNTID>0

		select @TableName=TableName from adm_features where featureid=@GridviewID
		set @Sql ='select NodeID,Name Particulars from '+@TableName+ ' with(nolock) where isgroup=0 order by Name'                        
		exec (@Sql)   

		select @TableName=TableName from adm_features with(nolock) 
		where featureid in (select value from ADM_GlobalPreferences with(nolock) where Name='UnitLinkDimension')                        

		set @Sql ='select NodeID,Name [Type] from '+@TableName+ ' with(nolock) where isgroup=0'             
		exec (@Sql) 
		
		SET @SQL='SELECT NodeID,Code FROM REN_PROPERTY with(nolock) WHERE IsGroup = 0' 
		 EXEC (@SQL) 
		       
         if(@CostCenterID =95 or @CostCenterID =104) 
		 BEGIN
		 SET @SQL='SELECT MAX(ContractNumber) + 1  ContractNumber , CONTRACTPREFIX  
			FROM REN_Contract with(nolock)         
			WHERE COSTCENTERID ='+CONVERT(NVARCHAR,@CostCenterID)+' 
			GROUP BY CONTRACTPREFIX' 
		EXEC (@SQL)
		END  
		else
		BEGIN
		SET @SQL='SELECT MAX(Number) + 1  ContractNumber ,Prefix CONTRACTPREFIX  
			FROM REN_Quotation  with(nolock)        
			WHERE COSTCENTERID ='+CONVERT(NVARCHAR,@CostCenterID)+'           
			GROUP BY Prefix' 
		EXEC (@SQL)  
	    END 
	END
	ELSE IF @CostCenterID=65                        
	BEGIN 
		--Get Contact Types, Salutations, Roles, Countries                        
		SELECT * FROM COM_Lookup with(nolock) where lookuptype in (15,16,20,21)                        
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=@CostCenterID                          
	END    
	 
	select * from com_costcentercodedef with(nolock) 
	WHERE CostCenterID=@CostCenterID   
	order by IsName                                        
	
	IF @CostCenterID=3
	BEGIN
		SELECT CostCenterID,DocumentName FROM ADM_DocumentTypes WITH(NOLOCK)
		
		SELECT ProfileID,ProfileName,RuleType FROM INV_ProductBinRules WITH(NOLOCK)	
		GROUP BY ProfileID,ProfileName,RuleType
	END 
	ELSE IF @CostCenterID=2
	BEGIN
		--Getting list of cost center names                              
		SELECT FEATUREID,NAME FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID>50000  
	END 
	ELSE IF (@CostCenterID=65)
	BEGIN
		select * from COM_ContactTypes with(nolock) order by ContactTypeID 
	END            
	ELSE IF @CostCenterID=110                        
	BEGIN                
		SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=2 AND Name='GSTValidation'                          
	END                   
    ELSE IF (@CostCenterID=1000)
	BEGIN
		IF EXISTS (SELECT Value from  COM_CostCenterPreferences with(nolock) 
		WHERE CostCenterID=@CostCenterID AND Name='DayViewRepeatOn' AND Value IS NOT NULL AND Value<>'' AND Value<>'0')
		BEGIN
			SELECT @TableName =TableName FROM ADM_Features with(nolock) WHERE FeatureID=(SELECT Value from  COM_CostCenterPreferences with(nolock) 
			WHERE CostCenterID=@CostCenterID AND Name='DayViewRepeatOn' AND Value IS NOT NULL AND Value<>'' AND Value<>'0')                              
			SET @SQL='SELECT T.NodeID,T.Name FROM '+@TableName+' T WITH(NOLOCK) 
			JOIN COM_Status S WITH(NOLOCK) ON S.StatusID=T.StatusID                             
			WHERE T.NodeID>1 AND T.IsGroup = 0 AND S.Status=''Active''
			union 
			select 1,''NOT Assigned''' 
			EXEC (@SQL)
		END
		ELSE 
			SELECT 1 AS NodeID,'' Name WHERE 1<>1
		select CalendarXML from ADM_Users with(nolock) where UserID=@UserID 
		SELECT DocumentName,CostCenterID FROM ADM_dOCUMENTTYPES with(nolock)
		SELECT FeatureID,Name FROM ADM_Features with(nolock) where FeatureID>50000 AND IsEnabled=1 
		ORDER BY Name
	END            
	ELSE IF(@CostCenterID=50051)
	BEGIN
		select * from COM_Lookup with(nolock) where LookupType BETWEEN 101 AND 123
	END
	ELSE IF(@CostCenterID=251 OR @CostCenterID=252 OR @CostCenterID=253 OR @CostCenterID=254 OR @CostCenterID=255 )
	BEGIN
		select * from COM_Lookup with(nolock) where LookupType BETWEEN 101 AND 113
	END
	ELSE IF (@CostCenterID >=50001 )
	BEGIN
		IF exists(select isnull(value,0) from COM_CostCenterPreferences with(nolock) 
		where CostCenterID=76 and Name='JobDimension' and ISNUMERIC(value)=1 and Value=@CostCenterID)
		BEGIN
			SELECT Status,StatusID FROM COM_Status with(nolock) WHERE CostCenterID=158

			select Value from COM_CostCenterPreferences with(nolock) 
			where Name='StageDimension' and CostCenterID=76 
		END
	END
	
	IF (@CostCenterID IN (73,92,93,94,95,103,104,129))            
	BEGIN 
		SELECT  R.ReportID,Q.ReportName,Q.ReportField,Q.ReportFieldName,Q.DocumentField,Q.DocumentFieldName,A.SysColumnName,Q.Shortcut,Q.DisplayAsPopup,Q.GroupLevel,Q.Width ,Q.Height,Q.mapxml,Q.MapType
		FROM ADM_RevenUReports R  with(nolock)
		inner join ADM_DocumentReports Q WITH(NOLOCK) on Q.DocumentReportID=R.ReportID
		left join ADM_CostCenterDef A WITH(NOLOCK) on A.CostCenterColID=Q.DocumentField 
		left join [ADM_DocReportUserRoleMap] DR WITH(NOLOCK) on DR.DocumentViewID=Q.DocumentViewID and DR.CostCenterID=Q.CostCenterID
		where  Q.CostCenterID=@CostCenterID and (DR.UserID=@UserID OR DR.RoleID=@RoleID OR GroupID IN (SELECT GroupID FROM COM_Groups WITH(NOLOCK) WHERE UserID=@UserID OR RoleID=@RoleID))
		GROUP BY  Q.ReportID, R.ReportID,Q.ReportName,Q.ReportField,Q.ReportFieldName,Q.DocumentField,Q.DocumentFieldName,A.SysColumnName,Q.Shortcut,Q.DisplayAsPopup,Q.GroupLevel ,Q.Width,Q.Height,Q.mapxml,Q.MapType  
		order by Q.ReportID
	END
	
	if @CostCenterID in(2,3,94,95,103,104,129) or @CostCenterID>50000
	begin
		select * from ADM_TypeRestrictions with(nolock) where CostCenterID=@CostCenterID
	end
	
	/*********** COMMON TABLES *********/
	
	--ADD COMMON QUERIES HERE --ADIL
	
	--Getting Workflows
	if @CostCenterID in(2,3,73,76,92,93,94,95,103,104,129,86,89,72,83) or @CostCenterID>50000
	   SELECT distinct [WorkFlowDefID],[CostCenterID],[Action],[Expression],a.WorkFlowID,a.LevelID,IsLineWise,IsExpressionLineWise  
	   FROM [COM_WorkFlowDef]  a   WITH(NOLOCK)
	   join COM_WorkFlow b WITH(NOLOCK) on a.WorkFlowID=b.WorkFlowID  and a.LevelID=b.LevelID
	   LEFT JOIN COM_Groups G with(nolock) on b.GroupID=G.GID
	   where [CostCenterID]=@CostCenterID and IsEnabled=1  
	   and (b.UserID =@UserID or b.RoleID=@RoleID or G.UserID=@UserID or G.RoleID=@RoleID )  
	else
		select 1 NoWorkflow where 1!=1
	 
	
   if(@DocViewID is not null and @DocViewID>0)                      
   begin                      
    SELECT [DocumentViewDefID],c.SysColumnName                      
     ,[DocumentViewID]                      
     ,[DocumentTypeID]                      
     ,d.[CostCenterID]                      
     ,d.[CostCenterColID]                      
     ,[ViewName]                      
     ,d.[IsEditable]                      
     ,[IsReadonly]                      
     ,[NumFieldEditOptionID]                      
     ,d.[IsVisible]                      
     ,[TabOptionID]                      
     ,[CompoundRuleID]                      
     ,[FailureMessage]                      
     ,[ActionOptionID]                      
     ,[Mode]                      
     ,[Expression],ViewFor ,Tabid,d.IsMandatory,ISNULL(FieldColor,'') FieldColor
    FROM [ADM_DocumentViewDef] d  with(nolock)                   
   left join ADM_CostCenterDef c with(nolock) on c.CostCenterColID=d.CostCenterColID where DocumentViewID=@DocViewID                      
   end                      
   else                      
   begin                      
   SELECT [DocumentViewDefID],c.SysColumnName                      
     ,[DocumentViewID]                      
     ,[DocumentTypeID]                      
     ,d.[CostCenterID]                      
     ,d.[CostCenterColID]                      
     ,[ViewName]                      
     ,d.[IsEditable]                      
     ,[IsReadonly]                      
     ,[NumFieldEditOptionID]                      
     ,d.[IsVisible]                      
     ,[TabOptionID]                      
     ,[CompoundRuleID]                      
     ,[FailureMessage]                      
     ,[ActionOptionID]                      
     ,[Mode]                      
     ,[Expression],ViewFor ,Tabid,d.IsMandatory,ISNULL(FieldColor,'') FieldColor                    
    FROM [ADM_DocumentViewDef] d  with(nolock)                     
    left join ADM_CostCenterDef c with(nolock) on c.CostCenterColID=d.CostCenterColID where 1=2 --not to return any row just structure                      
   end                      
             
  --Getting Tab Order for Tabs                            
  SELECT CCTab.CCTabID,CCTab.CCTabName,CCTab.CostCenterID,  R.ResourceData, CCTab.TabOrder,CCTab.IsVisible, CCTab.GroupOrder, CCTab.GroupVisible, CCTab.QuickViewCCID , CCTab.QuickViewID, CCTab.CCIDValues
    from  ADM_CostCenterTab CCTab with(nolock)                          
  LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=CCTab.ResourceID AND R.LanguageID= @LangID                             
 WHERE CostCenterID=@CostCenterID                       
             
--*** DONT ADD ANY QUERIES BELOW TO THIS LINE - ADIL
                         
COMMIT TRANSACTION                               
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
ROLLBACK TRANSACTION                              
SET NOCOUNT OFF                                
RETURN -999                       
END CATCH
GO
