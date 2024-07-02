USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDocumentDef]
	@DocumentTypeID [int],
	@DocumentType [int],
	@TaxChartCCID [int],
	@DocumentStaticFieldsXml [nvarchar](max),
	@ColsXml [nvarchar](max),
	@PreferanceXml [nvarchar](max),
	@DocPrefixXml [nvarchar](max),
	@DynamicXML [nvarchar](max),
	@CreditAccountTypes [nvarchar](max),
	@DebitAccountTypes [nvarchar](max),
	@DefaultCreditAccont [int] = 0,
	@DefaultDebitAccont [int] = 0,
	@LinkXML [nvarchar](max),
	@CopyDocumentXML [nvarchar](max),
	@ExtrnFuncXML [nvarchar](max),
	@MenuID [int] = 0,
	@DefCurrID [int] = 0,
	@COLUMNSXML [nvarchar](max),
	@ProductDefault [int] = 0,
	@DueDateFormula [nvarchar](max),
	@NetFormula [nvarchar](max),
	@CloseLink [nvarchar](max),
	@Attachment [nvarchar](max),
	@BudgetsXML [nvarchar](max),
	@LockedDatesXml [nvarchar](max),
	@CompanyGUID [nvarchar](200),
	@UserName [nvarchar](200),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION                
BEGIN TRY                
SET NOCOUNT ON;              
    --Declaration Section              
	DECLARE @HasAccess BIT,@CostCenterID int,@XML XML,@I int, @Cnt int ,@Extention nvarchar(10) ,@abc nvarchar(10), @CCCID INT,@Series INT
	DECLARE @BounceSeries INT,@IntermedSeries INT,@StatusID INT,@ConvertAs INT,@IntermediateConvertion INT,@Bounce INT,@OnDiscount INT, @UserColumnName NVARCHAR(50)      
	DECLARE @Header NVARCHAR(500),@BounceINV NVARCHAR(500),@PDCAmtFld NVARCHAR(500),@FORMULA NVARCHAR(MAX),@SectionSeqNumber int,@tabid int,@IsRepeat INT  
	DECLARE @TabOrder int, @GroupOrder int ,@Posting int,@IsFc bit
	DECLARE @CCColIDBase int,@CCColIDLinked int,@k int,@ct int,@DocLinkDefID int,@l int,@cts int
	DECLARE @DebitAccount INT,@CreditAccount INT,@PostingType INT,@RoundOff INT,@ListViewTypeID int              
	DECLARE @DistributionColID INT,@Distxml nvarchar(200),@Distributeon nvarchar(50),@UIWidth int,@colType nvarchar(50),@ProbValues nvarchar(MAX)              
	DECLARE @SectionID INT,@IsMandatory BIT,@IsUnique BIT, @UserDefaultValue NVARCHAR(max),@SectionName  NVARCHAR(200),@IsReadOnly BIT
	DECLARE @Link_Data INT , @Local_Ref INT    , @TempCrdColId  INT  , @TempDbtColId  INT ,  @ColID  INT  , @CurrencyID INT                 
	DECLARE @IsCrAccountDisplayed BIT,@IsDrAccountDisplayed BIT,@CostCenterColID INT,@ColFieldType INT ,@TextFormat INT ,@Colspan INT ,@Decimals INT            
	DECLARE @IsRoundOffEnabled BIT,@IsDistributionEnabled BIT,@ColumnCostCenterID int,@IsCalculate int,@IsVisible bit ,@Filter int              
	DECLARE @DocumentName NVARCHAR(300),@DOCUMENTABBR NVARCHAR(300),@DOCUMENTMENU INT,@GROUPID INT,@GROUPName NVARCHAR(100),@GROUPResID INT,@FEATUREACTIONID INT,@IMAGEPATH NVARCHAR(300)              
	DECLARE @DrpID INT,@IsInventory bit,@TempTypeID INT,@DATA XML,@showtotal int,@TextColumnCostcenterID INT,@vouchers nvarchar(max)
	DECLARE @CrRefID INT,@noTab bit,@dependancy INT,@dependanton INT,@IsTransfer int,@EvaluateAfter NVARCHAR(20)
	DECLARE @CrRefColID INT,@DbFilter int,@DiscountInterest NVARCHAR(300),@DiscountCommision NVARCHAR(300)
	DECLARE @DrRefID INT,@CrFilter int,@AllowDDHistory BIT,@ResID INT,@basedonXMl nvarchar(max),@WaterMark nvarchar(500),@MinChar INT,@MaxChar INT
	DECLARE @DrRefColID INT,@DbIndex int,@CVSP nvarchar(200),@GridViewID INT,@LineRoundoff int,@FixedAcc int,@IsPartialLink BIT,@IgnoreChars INT
	DECLARE @colsql nvarchar(max)

  	DECLARE @DT float
	set @DT=CONVERT(float,getdate())
	
	if(SELECT Value FROM ADM_GlobalPreferences with(nolock) WHERE Name='DocumentDesignerHistory')='TRUE'
		set @AllowDDHistory=1
	else
		set @AllowDDHistory=0

	if exists(SELECT * FROM ADM_GlobalPreferences with(nolock) WHERE Name='Use Foreign Currency' and Value='TRUE')
		set @IsFc=1
	else
		set @IsFc=0

    SELECT TOP 1  @TempTypeID=DocumentTypeID,@IsInventory=IsInventory FROM [ADM_DocumentTypes] with(nolock) WHERE [DocumentType]=@DocumentType
    SET @DATA=@PreferanceXml
    
	--IF @CostCenterID IS ZERO THEN INSERT NEW RECORD MODIFIED SP ON SEP 10 BY HAFEEZ              
	IF @DocumentTypeID=0              
	BEGIN       
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,43,4)              
	             
		IF @HasAccess=0              
		BEGIN              
			RAISERROR('-105',16,1)              
		END           
		SELECT @CostCenterID=MAX(CostCenterID)+1 FROM  ADM_DocumentTypes with(nolock)
   
		IF @CostCenterID<>0              
		BEGIN
			SET @XML=@DocumentStaticFieldsXml              
			--INSERT NEW RECORD INTO DOCUMENT TYPES              
			SELECT @DocumentName=X.value('@DocumentName','NVARCHAR(300)'),@DOCUMENTABBR=X.value('@DocumentAbbr','NVARCHAR(300)')               
			FROM @XML.nodes('/Document/Row') as Data(X)              

			IF EXISTS (SELECT DocumentTypeID FROM ADM_DocumentTypes WITH(nolock) WHERE [DocumentName]=@DocumentName)  
			BEGIN  
				RAISERROR('-112',16,1)  
			END   

			IF EXISTS (SELECT DocumentTypeID FROM ADM_DocumentTypes WITH(nolock) WHERE [DocumentAbbr]=@DOCUMENTABBR)  
			BEGIN  
				RAISERROR('-126',16,1)  
			END       

			declare @PrefCCID INT
			set @PrefCCID=(SELECT TOP 1 COSTCENTERID FROM ADM_DOCUMENTTYPES with(nolock) WHERE  DOCUMENTTYPE=@DocumentType)
    
			INSERT INTO  [ADM_DocumentTypes](IsInventory,[CostCenterID],[DocumentType],[DocumentAbbr],[StatusID],[ConvertAs],[Bounce],[OnDiscount],[Series],[DocumentName],[IsUserDefined],[CompanyGUID],[GUID] ,[Description]              
			,[CreatedBy],[CreatedDate],[IntermediateConvertion],DiscountInterestFld,DiscountCommisionFld,BounceSeries,BouncePenaltyFld,BounceInvDoc,PDCAmtFld,IntermedSeries)              
			SELECT @IsInventory,@CostCenterID,@DocumentType, X.value('@DocumentAbbr','NVARCHAR(300)'), X.value('@StatusID','INT'), X.value('@ConvertAs','INT'), X.value('@Bounce','INT'),  X.value('@OnDiscount','INT'),X.value('@Series','INT'), @DocumentName              
			,1,@CompanyGUID,NEWID(),@DocumentName,@UserName,CONVERT(FLOAT,GETDATE()), X.value('@IntermediateConvertion','INT')
			,X.value('@DiscountInterest','NVARCHAR(300)'),X.value('@DiscountCommision','NVARCHAR(300)'),X.value('@BounceSeries','int')
			,X.value('@BouncePenaltyFld','NVARCHAR(300)'),X.value('@BounceINVDocument','NVARCHAR(300)'),X.value('@PDCAmtFld','NVARCHAR(300)'),X.value('@IntermedSeries','INT')
			FROM @XML.nodes('/Document/Row') as Data(X)              
			SET @DocumentTypeID=SCOPE_IDENTITY()              

			--INSERT INTO DOCUMENT PREFERANCES TABLE              
			INSERT INTO [COM_DocumentPreferences]([CostCenterID],[DocumentTypeID],[DocumentType],[ResourceID],[PreferenceTypeID],[PreferenceTypeName] ,[PrefValueType]              
			  ,[PrefName],[PrefValue],[PrefDefalutValue],[IsPrefValid],PrefColOrder,PrefRowOrder,[CompanyGUID],[GUID],[Description] ,[CreatedBy],[CreatedDate])              
			SELECT @CostCenterID,@DocumentTypeID,[DocumentType],[ResourceID],[PreferenceTypeID],[PreferenceTypeName] ,[PrefValueType]              
			  ,[PrefName],[PrefValue],[PrefDefalutValue],[IsPrefValid],PrefColOrder,PrefRowOrder,[CompanyGUID],[GUID],[Description] ,[CreatedBy],[CreatedDate]              
			FROM [COM_DocumentPreferences] with(nolock) WHERE CostCenterID=@PrefCCID     
			
			DECLARE @ResourceID INT
			EXEC [spCOM_SetInsertResourceData] @DocumentName,@DocumentName,@DocumentName,1,1,@ResourceID OUTPUT 
			
			--INSERT INTO FEATURES TABLE    
			INSERT INTO  [ADM_Features]([FeatureID],[ParentFeatureID],[Name],[SysName],[ResourceID],[FeatureTypeID],[FeatureTypeName],[IsUserDefined]              
			,[FeatureTypeResourceID],[Description],[ApplicationID],[StatusID],[CreatedDate],[CreatedBy],[TableName],IsEnabled)              
			SELECT @CostCenterID,1,@DocumentName,X.value('@DocumentName','NVARCHAR(300)'),@ResourceID,1,X.value('@DocumentName','NVARCHAR(300)'),1,              
			NULL,@DocumentName,1,1,CONVERT(FLOAT,GETDATE()),@UserName, CASE WHEN @IsInventory=1 THEN 'INV_DocDetails' ELSE 'ACC_DocDetails' END ,1     
			FROM @XML.nodes('/Document/Row') as Data(X)              
			
			--INSERT INTO COSTCENTERDEFINATION              
			EXEC [SPInsertDocumentatCostCenterDef] @CostCenterID,@DocumentName,@DocumentType,@UserName               
		    
			--TO GET THE COSTCENTER COLID OF CRED AND DBT ACCS FOR ISDEFAULT IMPLEMENTATION
			SELECT @TempCrdColId = COSTCENTERCOLID FROM ADM_COSTCENTERDEF with(nolock)         
			WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME='CreditAccount'   
			SELECT @TempDbtColId = COSTCENTERCOLID FROM ADM_COSTCENTERDEF with(nolock)        
			WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME='DebitAccount'

			--INSERT INTO MENU     
			SELECT  @tabid=tabid,@GROUPID=GROUPID,@DrpID=DrpID,@IMAGEPATH=ImagePath , @TabOrder = TabOrder,@GroupOrder = GroupOrder   
			FROM ADM_RIBBONVIEW with(nolock) WHERE FEATUREID =@MenuID              
			SELECT @FEATUREACTIONID=FEATUREACTIONID  FROM ADM_FEATUREACTION with(nolock) WHERE FEATUREID=@CostCenterID AND FEATUREACTIONTYPEID=1          

			EXEC [spADM_SetRibbonView] @tabid,@GROUPID,@CostCenterID,@FEATUREACTIONID,'','',@DocumentName,@DocumentName,@DocumentName,@DocumentName,@TabOrder,@GroupOrder,'CompanyGUID','guid',@UserName,@UserID,@LangID,@IMAGEPATH,@DrpID              
			
			UPDATE ADM_RibbonView SET LicSIMPLE=(SELECT TOP 1 R.LicSIMPLE FROM ADM_RibbonView R WITH(NOLOCK)
			JOIN ADM_DocumentTypes DT WITH(NOLOCK) ON DT.CostCenterID=R.FeatureID 
			WHERE DT.DocumentType=11 AND R.LicSIMPLE IS NOT NULL)
			WHERE FEATUREID=@CostCenterID

			DECLARE @TAB TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,FEATUREID INT,ScreenName NVARCHAR(50))
			INSERT INTO @TAB
			SELECT RV.FEATUREID,RV.ScreenName FROM ADM_RibbonView RV WITH(NOLOCK)
			LEFT JOIN ADM_DOCUMENTTYPES DT WITH(NOLOCK) ON DT.COSTCENTERID=RV.FEATUREID
			WHERE DT.ISUSERDEFINED<>0 AND RV.tabid=@tabid AND RV.GROUPID=@GROUPID AND RV.DrpID=@DrpID
			ORDER BY RV.ScreenName
			
			DECLARE @ORDER INT,@OCOUNT INT,@FEATUREID INT
			SELECT @ORDER =1,@OCOUNT=COUNT(*) FROM @TAB

			WHILE @ORDER<=@OCOUNT
			BEGIN
				SELECT @FEATUREID=FEATUREID FROM @TAB WHERE ID=@ORDER
				UPDATE ADM_RibbonView SET Columnorder=@ORDER WHERE FEATUREID=@FEATUREID
				SET @ORDER=@ORDER+1
			END
			
			--INSERT INTO STATUS              
			INSERT INTO  [COM_Status] ([CostCenterID] ,[FeatureID],[Status] ,[ResourceID],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])              
			SELECT @CostCenterID ,@CostCenterID,[Status] ,[ResourceID],[IsUserDefined],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate] FROM [COM_Status] with(nolock) 
			WHERE [CostCenterID] IN  (SELECT COSTCENTERID FROM  [COM_DocumentPreferences] with(nolock) WHERE [DocumentTypeID]=@TempTypeID)              
			
			set @colsql=''
			select @colsql=@colsql+',p.'+Name from sys.columns 
			where Name not in('DocID','ColID','CCTaxID') and object_id=object_id('COM_CCTaxes')
			
			set @colsql='insert into COM_CCTaxes(ColID,DocID'+replace(@colsql,',p.',',')+')			
			select d.CostCenterColID,'+convert(nvarchar(max),@CostCenterID)+@colsql+' 
			from COM_CCTaxes P WITH(NOLOCK) 
			INNER JOIN ADM_CostCenterDef C WITH(NOLOCK) on P.ColID=C.CostCenterColID        
			INNER JOIN ADM_CostCenterDef d WITH(NOLOCK) on d.SysColumnname=C.SysColumnname
			where p.DOCID='+convert(nvarchar(max),@TaxChartCCID)+' and d.CostCenterID='+convert(nvarchar(max),@CostCenterID)
			Exec sp_executesql @colsql
		END              
	END              
	ELSE              
	BEGIN
		--GETTING DOCUMENT INFO              
		SELECT @CostCenterID=CostCenterID FROM ADM_DocumentTypes with(nolock) WHERE DocumentTypeID=@DocumentTypeID  

		if(@AllowDDHistory=1 and (select COUNT(*) from ADM_CostCenterDef_History with(nolock) where CostCenterID=@CostCenterID)=0)
		begin
			insert into ADM_CostCenterDef_History
			select * from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID

			insert into COM_DocumentPreferences_History
			select * from COM_DocumentPreferences with(nolock) where CostCenterID=@CostCenterID

			insert into ADM_DocumentDef_History
			select * from ADM_DocumentDef with(nolock) where CostCenterID=@CostCenterID
		end
         
		--SP Required Parameters Check              
		IF @CostCenterID=0              
		BEGIN              
			RAISERROR('-100',16,1)              
		END     

		--User access check               
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,10)              

		IF @HasAccess=0              
		BEGIN              
			RAISERROR('-105',16,1)              
		END      

		SET @XML=@DocumentStaticFieldsXml              
		--UPDATE RECORD               
		declare @tempAbbr nvarchar(300),@tempName nvarchar(300)
		SELECT @DocumentName=X.value('@DocumentName','NVARCHAR(300)'),@DOCUMENTABBR=X.value('@DocumentAbbr','NVARCHAR(300)'),  @StatusID=X.value('@StatusID','INT')
		,@ConvertAs=X.value('@ConvertAs','INT'),   @IntermediateConvertion=X.value('@IntermediateConvertion','INT'),  @Bounce=X.value('@Bounce','INT') 
		,@OnDiscount=X.value('@OnDiscount','INT'),@Series=X.value('@Series','INT')  ,@BounceSeries=X.value('@BounceSeries','INT')     
		,@DiscountInterest=X.value('@DiscountInterest','NVARCHAR(300)')      ,@DiscountCommision=X.value('@DiscountCommision','NVARCHAR(300)')      --    ,@DOCUMENTMENU=X.value('@DocumentAbbr','NVARCHAR')              
		,@Header=X.value('@BouncePenaltyFld','NVARCHAR(200)'),@BounceINV=X.value('@BounceINVDocument','NVARCHAR(200)'),@PDCAmtFld=X.value('@PDCAmtFld','NVARCHAR(200)'), @FORMULA=X.value('@BouncePenaltyFormula','NVARCHAR(max)'),@IntermedSeries=X.value('@IntermedSeries','INT')
 
		FROM @XML.nodes('/Document/Row') as Data(X)              

		IF EXISTS (SELECT DocumentTypeID FROM ADM_DocumentTypes WITH(nolock) WHERE [DocumentName]=@DocumentName and DocumentTypeID<>@DocumentTypeID)  
		BEGIN  
			RAISERROR('-112',16,1)  
		END   

		IF EXISTS (SELECT DocumentTypeID FROM ADM_DocumentTypes WITH(nolock) WHERE [DocumentAbbr]=@DOCUMENTABBR and DocumentTypeID<>@DocumentTypeID)  
		BEGIN  
			RAISERROR('-126',16,1)  
		END
     
		select  @tempName=DocumentName,@tempAbbr=DocumentAbbr from ADM_DocumentTypes WITH(nolock)  WHERE DocumentTypeID=@DocumentTypeID

		if(@tempAbbr!=@DOCUMENTABBR and (exists(select AccDocDetailsID from ACC_DocDetails with(nolock) where CostCenterID=@CostCenterID) or 
										 exists(select InvDocDetailsID from INV_DocDetails with(nolock) where CostCenterID=@CostCenterID)))
		begin
			RAISERROR('-128',16,1)  
		end
		
		SELECT  @tabid=tabid,@GROUPID=GROUPID,@GROUPName=GroupName,@GROUPResID=GROUPResourceID,@DrpID=isnull(DrpID,[FeatureActionResourceID]),@TabOrder = TabOrder,@GroupOrder = GroupOrder   
		FROM ADM_RIBBONVIEW with(nolock) WHERE FEATUREID =@MenuID       
		if(@DrpID!=(select DrpID from ADM_RibbonView with(nolock) where FeatureID=@CostCenterID))
		BEGIN
			update ADM_RibbonView
			set tabid=@tabid,GROUPID=@GROUPID,GROUPResourceID=@GROUPResID,GROUPName=@GROUPName,DrpID=@DrpID
				,TabOrder=@TabOrder,GroupOrder=@GroupOrder
			where FeatureID=@CostCenterID
		END
		
		if(@tempName!=@DocumentName)
		begin
			update [ADM_Features]
			set Name=@DocumentName
			where FeatureID=(select CostCenterID from [ADM_DocumentTypes] WITH(nolock)  WHERE DocumentTypeID=@DocumentTypeID)


			update ADM_COSTCENTERDEF
			set CostCenterName=@DocumentName
			where CostCenterID=(select CostCenterID from [ADM_DocumentTypes] WITH(nolock)  WHERE DocumentTypeID=@DocumentTypeID)

			update COM_LanguageResources
			set ResourceData=@DocumentName
			where LanguageID=@LangID and ResourceID in
			(select [FeatureActionResourceID] from [ADM_RibbonView] with(nolock) where [FeatureID]=(select CostCenterID from [ADM_DocumentTypes] WITH(nolock)  WHERE DocumentTypeID=@DocumentTypeID))


			update COM_LanguageResources
			set ResourceData=@DocumentName
			where LanguageID=@LangID and ResourceID in
			(select [ScreenResourceID] from [ADM_RibbonView] with(nolock) where [FeatureID]=(select CostCenterID from [ADM_DocumentTypes] WITH(nolock)  WHERE DocumentTypeID=@DocumentTypeID))


			update COM_LanguageResources
			set ResourceData=@DocumentName
			where LanguageID=@LangID and ResourceID in
			(select [ToolTipTitleResourceID] from [ADM_RibbonView] with(nolock) where [FeatureID]=(select CostCenterID from [ADM_DocumentTypes] WITH(nolock)  WHERE DocumentTypeID=@DocumentTypeID))


			update COM_LanguageResources
			set ResourceData=@DocumentName
			where LanguageID=@LangID and ResourceID in
			(select [ToolTipDescResourceID] from [ADM_RibbonView] with(nolock) where [FeatureID]=(select CostCenterID from [ADM_DocumentTypes] WITH(nolock)  WHERE DocumentTypeID=@DocumentTypeID))
		
		end
     
		UPDATE [ADM_DocumentTypes] SET [DocumentAbbr]=@DOCUMENTABBR, [DocumentName]=@DocumentName,[StatusID]=@StatusID,[ConvertAs]=@ConvertAs,[Bounce]=@Bounce, OnDiscount = @OnDiscount,[Series]=@Series,           
		DiscountInterestFld=@DiscountInterest,DiscountCommisionFld=@DiscountCommision,GUID=NEWID(),BounceSeries=@BounceSeries,
		BouncePenaltyFld=@Header,BounceInvDoc=@BounceINV,PDCAmtFld=@PDCAmtFld,IntermedSeries=@IntermedSeries
		,MODIFIEDDATE=CONVERT(FLOAT,GETDATE()),MODIFIEDBY=@UserName,[IntermediateConvertion]=@IntermediateConvertion WHERE DocumentTypeID=@DocumentTypeID                          
	END              
              
	if(@DocumentType = 16 or @DocumentType = 17 or @DocumentType = 28 or @DocumentType = 29)
	begin
		UPDATE ADM_CostCenterDef SET UserDefaultValue=@DefaultDebitAccont,UserProbableValues=@DebitAccountTypes                 
		WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME='AccountID'   
	end
      
	UPDATE ADM_CostCenterDef SET UserDefaultValue=@DefaultCreditAccont,UserProbableValues=@CreditAccountTypes                 
	WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME='CreditAccount'
	              
	UPDATE ADM_CostCenterDef SET UserDefaultValue=@DefaultDebitAccont,UserProbableValues=@DebitAccountTypes              
	WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME='DebitAccount'  

	UPDATE ADM_CostCenterDef SET UserDefaultValue=(case when @ProductDefault=0 then null else @ProductDefault end)   
	WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME='ProductID'

	UPDATE ADM_CostCenterDef SET UserDefaultValue=@DefCurrID           
	WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME='CurrencyID'

	set @CVSP=''''
	select @CVSP=[PrefValue] from COM_DocumentPreferences with(nolock) WHERE [PrefName]='Customer_VendorwiseSPaccount' AND CostCenterID=@CostCenterID
          
	--ADDED CODE ON SEP 12 2011 TO SET PREFERANCE-- HAFEEZ              
	DECLARE @J INT,@COUNT INT,@KEY NVARCHAR(500),@VALUE NVARCHAR(MAX),@GROUP NVARCHAR(300),@CopyVPTDocID int
	DECLARE @TEMP TABLE(ID INT IDENTITY(1,1) PRIMARY KEY,[KEY] NVARCHAR(500),[VALUE] NVARCHAR(MAX),GroupName nvarchar(300))
	
	select @CopyVPTDocID=X.value('@CopyVPT','int') from @DATA.nodes('Xml') as Data(X)
	if(@CopyVPTDocID is not null and @CopyVPTDocID>40000)
	begin
		insert into ADM_DocPrintLayouts(DocumentID,Name,IsDefault,Preferences,BodyFields,ReportHeader,PageHeader,PageFooter,ReportFooter
			,ExtendedDataQuery,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,DocType,FormulaFields)
		select @CostCenterID,Name,IsDefault,Preferences,BodyFields,ReportHeader,PageHeader,PageFooter,ReportFooter
			,ExtendedDataQuery,CompanyGUID,newID(),Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,DocType,FormulaFields 
		from ADM_DocPrintLayouts with(nolock) where DocumentID=@CopyVPTDocID
	end

	INSERT INTO @TEMP ([KEY],[VALUE],GroupName)              
	SELECT X.value('@Name','nvarchar(300)'),X.value('@Value','nvarchar(MAX)'),X.value('@Group','nvarchar(300)')              
	FROM @DATA.nodes('/Xml/Row') as DATA(X)               
	SELECT @J=1,@COUNT=COUNT(*) FROM @TEMP               

	WHILE @J<=@COUNT              
	BEGIN   
		SELECT @KEY=[KEY],@VALUE=[VALUE],@GROUP=GroupName FROM @TEMP WHERE ID=@J               

		if (@KEY ='UseasCrossDimension' and @VALUE!=(select top 1 [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID))
		begin
			if exists(select DocID from ACC_DocDetails with(nolock) where CostCenterID=@CostCenterID)
			begin
				RAISERROR('-558',16,1)              
			end
		END	

		if (@KEY='EnableSchemes' and @VALUE='false' and @VALUE!=(select [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID))
		begin
			if exists(select DocID from INV_DocDetails with(nolock) where CostCenterID=@CostCenterID and IsQtyFreeOffer=1)
			begin
				RAISERROR('Schems Already Used',16,1)              
			end
		end
		else if (@KEY='linewiseDebitAccount' and @VALUE!=(select [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID))
		begin

			if (@IsInventory=1 and exists(select DocID from INV_DocDetails with(nolock) where CostCenterID=@CostCenterID))
			begin
				RAISERROR('-354',16,1)              
			end
			else if exists(select DocID from ACC_DocDetails with(nolock) where CostCenterID=@CostCenterID)
			begin
				RAISERROR('-354',16,1)              
			end

			if(@VALUE='true')
			begin
				update ADM_CostCenterDef  
				set SectionID=3,SectionName='Body'  
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME in('DebitAccount','ChequeNumber','ChequeDate','DueDate','ChequeMaturityDate','ChequeBankName')  
			end
			else
			begin
				update ADM_CostCenterDef  
				set SectionID=1,SectionName='Header'  
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME in('DebitAccount','ChequeNumber','ChequeDate','DueDate','ChequeMaturityDate','ChequeBankName')
			end
		end    
		else  if (@KEY='linewiseCreditAccount' and @VALUE!=(select [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID))
		begin
			
			if (@IsInventory=1 and exists(select DocID from INV_DocDetails with(nolock) where CostCenterID=@CostCenterID))
			begin
				RAISERROR('-355',16,1)              
			end
			else if exists(select DocID from ACC_DocDetails with(nolock) where CostCenterID=@CostCenterID)
			begin
				RAISERROR('-355',16,1)              
			end
			if(@VALUE='true')
			begin
				update ADM_CostCenterDef  
				set SectionID=3,SectionName='Body'  
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME in('CreditAccount','ChequeNumber','ChequeDate','DueDate','ChequeMaturityDate','ChequeBankName','ChequeBookNo')
			end
			else
			begin
				update ADM_CostCenterDef  
				set SectionID=1,SectionName='Header'  
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME in('CreditAccount','ChequeNumber','ChequeDate','DueDate','ChequeMaturityDate','ChequeBankName','ChequeBookNo')
			end
		end  
		else  if (@KEY='LineWisePDC' and @VALUE!=(select [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID))
		begin
			if exists(select DocID from ACC_DocDetails with(nolock) where CostCenterID=@CostCenterID)
			begin
				RAISERROR('-557',16,1)              
			end
			if(@VALUE='true')
			begin
				update ADM_CostCenterDef  
				set SectionID=3,SectionName='Body'  
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME in('ChequeNumber','ChequeDate','DueDate','ChequeMaturityDate','ChequeBankName')
			end
			else
			begin
				update ADM_CostCenterDef  
				set SectionID=1,SectionName='Header'  
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME in('ChequeNumber','ChequeDate','DueDate','ChequeMaturityDate','ChequeBankName')
			end
		end    
		else  if (@KEY='UseasBrsBankStmt' and @VALUE!=(select [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID))
		begin
			if exists(select DocID from ACC_DocDetails with(nolock) where CostCenterID=@CostCenterID)
			begin
				RAISERROR('Documents exists BrsBank Statement can not be changed',16,1)              
			end
			
			if(@VALUE='true' and not exists(select [CostCenterID] from [adm_Costcenterdef] with(nolock) where CostCenterID=@CostCenterID and [SysColumnName]='ChequeNumber'))
			begin
				declare @COLumnID INT,@RID INT,@COLUMNNAME nvarchar(max),@seqNo int
				SELECT @RID=MAX(RESOURCEID) FROM COM_LanguageResources with(nolock)			
				SELECT @COLumnID=MAX(CostCenterColID) FROM ADM_CostCenterDef with(nolock)
				
				select @seqNo=max([SectionSeqNumber]) from ADM_CostCenterDef with(nolock) 
				where CostCenterID=@CostCenterID and Sectionid=3 and syscolumnname in('DebitAmount','CreditAmount')

				set @COLumnID=@COLumnID+1
				set @RID=@RID+1
				set @COLUMNNAME='ChequeNumber'
				set identity_insert adm_Costcenterdef on	
		
				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
				VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
				
				INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
				VALUES(@CostCenterID,@COLumnID,@RID,@DocumentName,'Acc_Docdetails',@COLUMNNAME,@COLUMNNAME,NULL,'TEXT','TEXT','','',0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,@seqNo,3,'Body',1,1,1,1,NULL,'CompanyGUID',newid(),NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
				
				set @seqNo=@seqNo+1
				set @COLumnID=@COLumnID+1
				set @RID=@RID+1
				set @COLUMNNAME='ChequeBankName'
				
				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
				VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
				
				INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
				VALUES(@CostCenterID,@COLumnID,@RID,@DocumentName,'Acc_Docdetails',@COLUMNNAME,@COLUMNNAME,NULL,'TEXT','TEXT','','',0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,@seqNo,3,'Body',1,1,1,1,NULL,'CompanyGUID',newid(),NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
				
				set @seqNo=@seqNo+1
				set @COLumnID=@COLumnID+1
				set @RID=@RID+1
				set @COLUMNNAME='ChequeDate'
				
				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
				VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
				
				INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
				VALUES(@CostCenterID,@COLumnID,@RID,@DocumentName,'Acc_Docdetails',@COLUMNNAME,@COLUMNNAME,NULL,'DATE','DATE','','',0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,@seqNo,3,'Body',1,1,1,1,NULL,'CompanyGUID',newid(),NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
				
				set @seqNo=@seqNo+1
				set @COLumnID=@COLumnID+1
				set @RID=@RID+1
				set @COLUMNNAME='ChequeMaturityDate'
				
				INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
				VALUES(@RID,@COLUMNNAME,1,'English',@COLUMNNAME,NULL) 
				
				INSERT INTO [adm_Costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[SysColumnName],[UserColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate])
				VALUES(@CostCenterID,@COLumnID,@RID,@DocumentName,'Acc_Docdetails',@COLUMNNAME,@COLUMNNAME,NULL,'DATE','DATE','','',0,0,1,1,0,0,0,0,0,0,NULL,0,NULL,@seqNo,3,'Body',1,1,1,1,NULL,'CompanyGUID',newid(),NULL,'ADMIN',4004,NULL,NULL,NULL,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL)
				set identity_insert adm_Costcenterdef oFF	
		
				end
			
		end                 
		else if (@KEY='Line-wise Currency' and @VALUE!=(select [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID))
		begin

			if (@IsInventory=1 and exists(select DocID from INV_DocDetails with(nolock) where CostCenterID=@CostCenterID))
			begin
				RAISERROR('-356',16,1)              
			end
			else if exists(select DocID from ACC_DocDetails with(nolock) where CostCenterID=@CostCenterID)
			begin
				RAISERROR('-356',16,1)              
			end

			if(@VALUE='true')
			begin
				update ADM_CostCenterDef  
				set SectionID=3,SectionName='Body'  
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME in('CurrencyID','ExchangeRate')  
			end
			else
			begin
				update ADM_CostCenterDef  
				set SectionID=1,SectionName='Header'  
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME in('CurrencyID','ExchangeRate')
			end
		end    

		if(@KEY='UseAsLC' or @KEY='UseAsTR') 
		BEGIN
			if(@VALUE='false' and 
			exists(select [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID
					and [PrefValue]='true'))
			BEGIN
				update ADM_CostCenterDef              
				set IsColumnInUse=0,IsColumnUserDefined=1,IsVisible=0
				where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME in('dcalpha1','dcalpha2','dcalpha3')
			END
		END 
		Else if(@KEY='BankNameDropDown') 
		BEGIN
			if(@VALUE='false')
			BEGIN
				update ADM_CostCenterDef              
				set UserColumnType='TEXT'
				where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='ChequeBankName'
			END
			ELSE if(@VALUE='true')
			BEGIN
				update ADM_CostCenterDef              
				set UserColumnType='EditableCombobox'
				where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='ChequeBankName'
			END
		END
		Else if(@KEY='LinewiseDuedate' ) 
		BEGIN
			if(@VALUE='false')
			BEGIN
				update ADM_CostCenterDef              
				set SectionID=1
				where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='DueDate'
			END
			ELSE if(@VALUE='true')
			BEGIN
				update ADM_CostCenterDef              
				set SectionID=3
				where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='DueDate'
			END
		END
		Else if(@KEY='LinewiseBillNoBillDate' ) 
		BEGIN
			if(@VALUE='false')
			BEGIN
				update ADM_CostCenterDef              
				set SectionID=1
				where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME in ('BillNo','BillDate')
			END
			ELSE if(@VALUE='true')
			BEGIN
				update ADM_CostCenterDef              
				set SectionID=3
				where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME in ('BillNo','BillDate')
			END
		END
		if(@KEY='AutoChequeNo')
		BEGIN
			if(@VALUE='True')
			BEGIN
				update ADM_CostCenterDef  
				set ISVISIBLE=1
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME='ChequeBookNo'
			END
			ELSE
			BEGIN
				update ADM_CostCenterDef  
				set ISVISIBLE=0
				where CostCenterID=@CostCenterID and SYSCOLUMNNAME='ChequeBookNo'
			END
		END
		
		UPDATE COM_DocumentPreferences               
		SET [PrefValue]=@VALUE,PrefDefalutValue=@VALUE,              
		[ModifiedBy]=@UserName,              
		[ModifiedDate]=@DT             
		WHERE [PrefName]=@KEY AND CostCenterID=@CostCenterID   AND PreferenceTypeName=@GROUP   
    
		SET @J=@J+1   
	END              

	set @XML=@DocPrefixXml                           
              
    delete from [COM_DocPrefix]              
    where DocumentTypeID=@DocumentTypeID              
	if(@DocPrefixXml<>'')              
	begin                 
		INSERT INTO [COM_DocPrefix]              
		   ([DocumentTypeID]              
		   ,[CCID]              
		   ,[Length]              
		   ,[Delimiter]              
		   ,[PrefixOrder]
		   ,seriesno
		   ,Isdefault
		   ,[CompanyGUID]              
		   ,[GUID]              
		   ,[CreatedBy]              
		   ,[CreatedDate])              
		 select @DocumentTypeID              
		   ,X.value('@CCID','int')              
		 ,X.value('@Length','nvarchar(50)')              
		 ,X.value('@Delimiter','nvarchar(50)')              
		 ,X.value('@PrefixOrder','int')      
		 ,X.value('@SeriesNo','int')      
		 ,X.value('@IsDefault','bit')      
		   ,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE())              
		 FROM @XML.nodes('/Prefix/Row') as Data(X)              
		where X.value('@PrefixType','nvarchar(20)')='Fixed'                     
	end  
	
	IF @DocumentType=38
	BEGIN
		DECLARE @TABPrefix TABLE (ID INT IDENTITY(1,1) PRIMARY KEY,CCID INT)
		
		INSERT INTO @TABPrefix
		SELECT DISTINCT CCD.CostCenterID FROM COM_DocPrefix CDP WITH(NOLOCK) 
		JOIN ADM_CostCenterDef CCD WITH(NOLOCK) ON CCD.CostCenterColID=CDP.CCID
		WHERE CDP.DocumentTypeID=@DocumentTypeID AND CCD.CostCenterID>50000

		SELECT @I=1, @Cnt=count(*) FROM @TABPrefix  

		WHILE(@I<=@Cnt)                
		BEGIN 
			SELECT @DbIndex=(CCID-50000) FROM @TABPrefix WHERE ID=@I
			
			if not exists (select Name from sys.columns where Name='CCNID'+convert(nvarchar,@DbIndex) and object_id=object_id('POS_loginHistory'))
			begin
				set @colsql='alter table POS_loginHistory add CCNID'+convert(nvarchar,@DbIndex)+' INT'
				Exec sp_executesql @colsql
			end
			
			SET @I=@I+1     
		END           
	END
	
	DECLARE @tblList TABLE(ID int identity(1,1) primary key,ColumnSpan int,TextFormat int, ColFieldType INT,              
	Header NVARCHAR(200),FORMULA  NVARCHAR(max),              
	DebitAccount int,CreditAccount int,PostingType INT,RoundOff INT,              
	DistributionColID int,Distxml nvarchar(200),Distributeon nvarchar(50),ColumnCostCenterID int,ListViewTypeID int,              
	SectionID INT,IsMandatory BIT,UserDefaultValue NVARCHAR(max),SectionName  NVARCHAR(200),              
	IsCrAccountDisplayed BIT,IsDrAccountDisplayed BIT,CostCenterColID int,IsCalculate int,UIWidth int,SectionSeqNumber int ,IsUnique BIT  
	,IsReadOnly BIT  , LINKDATA INT , LOCALREFERENCE INT , ColID int , CurrencyID int,colType nvarchar(50),ProbValues nvarchar(MAX),IsVisible BIT
	,CrRefID int  ,CrRefColID int,DrRefID int,DrRefColID int,IsGross bit,Decimal INT,Filter INT,showtotal int,TextColumnCostcenterID int,IsRepeat BIT,Vouchers nvarchar(max),noTab bit,dependanton int,dependancy int,IsTransfer int
	,DbFilter INT,CrFilter INT,DbIndex INT,GridViewID int,EvaluateAfter nvarchar(20),basedon nvarchar(max),Posting int,LineRoundoff int,FixedAcc int,IsPartialLink BIT,IgnoreChars int,WaterMark nvarchar(500),MinChar INT,MaxChar INT)

	set @XML=@ColsXml  
	INSERT INTO @tblList              
	SELECT X.value('@ColumnSpan','INT'), X.value('@TextFormat','INT'), X.value('@ColFieldType','INT'),              
	X.value('@Header','NVARCHAR(200)'), X.value('@Formula','NVARCHAR(max)'),X.value('@DebitAccount','int'), X.value('@CreditAccount','int'), X.value('@PostingType','INT'), X.value('@RoundOff','INT'),               
	X.value('@DistributionColID','int'), X.value('@DistXML','nvarchar(200)'), X.value('@Distributeon','nvarchar(50)'),  X.value('@ColumnCostCenterID','INT'), X.value('@ListViewTypeID','INT'),              
	X.value('@SectionID','INT'), X.value('@IsMandatory','BIT'),  X.value('@UserDefaultValue','NVARCHAR(max)'), X.value('@SectionName','NVARCHAR(200)'),               
	X.value('@IsCrAccountDisplayed','BIT'), X.value('@IsDrAccountDisplayed','BIT'), X.value('@CostCenterColID','int'), X.value('@IsCalculate','int')              
	,X.value('@UIWidth','INT'), X.value('@SectionSeqNumber','INT')   , X.value('@IsUnique','BIT'),X.value('@IsReadOnly','BIT')  
	, X.value('@Link_Data','INT')  , X.value('@Local_Ref','INT')   , X.value('@ColID','int')  , X.value('@CurrencyID','int'),X.value('@DataType','NVARCHAR(50)'),X.value('@ProbableValues','NVARCHAR(MAX)'),ISNULL(X.value('@IsVisible','BIT'),1)
	, X.value('@CrRefID','int')
	, X.value('@CrRefColID','int')
	, X.value('@DrRefID','int')
	, X.value('@DrRefColID','int'), X.value('@IsGross','bit'), X.value('@Decimal','INT'), X.value('@Filter','INT'),X.value('@ShowTotal','int')
	,X.value('@TextColumnCostcenterID','int'),ISNULL(X.value('@IsRepeat','BIT'),1),X.value('@Vouchers','nvarchar(max)'),isnull(X.value('@noTab','bit'),0),X.value('@dependanton','int'),X.value('@dependancy','int')
	,X.value('@IsTransfer','int'), X.value('@DbFilter','INT'), X.value('@CrFilter','INT'), X.value('@Index','INT')
	, X.value('@GridViewID','INT'), X.value('@EvaluateAfter','nvarchar(20)'),X.value('@BasedOnXML','nvarchar(max)'),X.value('@Posting','int')
	, X.value('@LineRoundoff','INT'), X.value('@FixedAcc','INT'),X.value('@IsPartialLink','BIT'),X.value('@IgnoreChars','int'), X.value('@WaterMark','nvarchar(500)')
	,X.value('@MinChar','INT'), X.value('@MaxChar','INT')
	from @XML.nodes('/Xml/Row') as Data(X)              

	update ADM_CostCenterDef              
	set IsColumnInUse=0     , IsUnique = 0 , IsEditable = 1 , LINKDATA = NULL , LOCALREFERENCE = NULL,
	SectionSeqNumber= null ,sectionid = null , SectionName = null ,RowNo=null,ColumnNo=null  
	where CostCenterID=@CostCenterID and IsColumnUserDefined=1     and (CostCenterColID not in               
	(select CostCenterColID from @tblList where CostCenterColID is not null) or syscolumnName like 'dcCCNID%')

	update ADM_DocumentDef 
	set DebitAccount=null,CreditAccount=null
	from adm_costcenterdef d with(nolock)
	where d.CostCenterID=@CostCenterID and  ADM_DocumentDef.costcentercolid=d.costcentercolid
	and d.IsColumnInUse=0 and IsColumnUserDefined=1

	DECLARE @TBLCCCID TABLE (ID INT identity(1,1) PRIMARY KEY,CCCID INT , SYSCOL NVARCHAR(50), USERCOL NVARCHAR(50))  

	--Set loop initialization varaibles              
	SELECT @I=1, @Cnt=count(*) FROM @tblList  
	
     
  WHILE(@I<=@Cnt)                
  BEGIN              
   
   SELECT @TextFormat=TextFormat,@Colspan=ColumnSpan,@ColFieldType=ColFieldType ,@Header=Header,@Formula=Formula,              
    @DebitAccount=DebitAccount,@CreditAccount=CreditAccount,@PostingType=PostingType,@RoundOff=RoundOff,              
    @DistributionColID =DistributionColID,@Distxml =Distxml ,@Distributeon =Distributeon ,@ColumnCostCenterID =ColumnCostCenterID,@ListViewTypeID=ListViewTypeID,              
    @SectionID =SectionID ,@IsMandatory =IsMandatory ,@UserDefaultValue =UserDefaultValue ,@SectionName  =SectionName  ,              
    @IsCrAccountDisplayed =IsCrAccountDisplayed ,@IsDrAccountDisplayed =IsDrAccountDisplayed ,@CostCenterColID =CostCenterColID ,              
    @IsCalculate=IsCalculate,@UIWidth=UIWidth,@SectionSeqNumber=SectionSeqNumber ,@IsUnique =IsUnique , @IsReadOnly =  IsReadOnly  , @CurrencyID = CurrencyID
    ,@Link_Data = LINKDATA ,   @Local_Ref = LOCALREFERENCE,@GridViewID=GridViewID ,  @ColID   = ColID,@colType=colType,@ProbValues=ProbValues,@IsVisible=IsVisible
    ,@CrRefID =CrRefID,@CrRefColID =CrRefColID ,@DrRefID =DrRefID ,@DrRefColID=DrRefColID,@Decimals=Decimal,@Filter=Filter,@showtotal=showtotal,@TextColumnCostcenterID=TextColumnCostcenterID,@IsRepeat=IsRepeat,@vouchers=vouchers
    ,@noTab=noTab,@dependanton=dependanton,@dependancy=dependancy,@IsTransfer=IsTransfer,@DbFilter=DbFilter,@CrFilter=CrFilter,@DbIndex=DbIndex
    ,@EvaluateAfter=EvaluateAfter,@basedonXMl=basedon,@Posting=Posting,@LineRoundoff=LineRoundoff,@FixedAcc=FixedAcc,@IsPartialLink=IsPartialLink,@IgnoreChars=IgnoreChars,@WaterMark=WaterMark,@MinChar=MinChar,@MaxChar=MaxChar
   FROM @tblList WHERE ID=@I              
          
    --IF(@IsReadOnly = 0)
        --SET @IsReadOnly = 1
  --  ELSE
        --SET @IsReadOnly = 0
    if(@SectionSeqNumber is null or (@SectionSeqNumber=0 and @CostCenterColID=0))
    begin
       select @SectionSeqNumber=max(isnull(SectionSeqNumber,0))+1 from ADM_CostCenterDef              
       where CostCenterID=@CostCenterID and SectionID=@SectionID and  (IsColumnInUse=1 OR IsColumnUserDefined=0)              
     end
     if(@UIWidth is null or @UIWidth=0)
        set @UIWidth=100
               
    SET @I=@I+1              
   IF(@ColFieldType=1)              
   BEGIN              
    IF(@RoundOff>0)              
     SET @IsRoundOffEnabled=1              
    ELSE          
     SET @IsRoundOffEnabled=0              
              
    IF(@RoundOff>0)              
     SET @IsDistributionEnabled=1              
    ELSE              
     SET @IsDistributionEnabled=0              
    
    if(@Header='FreeQTY')
    begin 
		update ADM_CostCenterDef 
		set Cformula=@Formula
		where CostCenterID=@CostCenterID and SysColumnName='Quantity'              
		continue;
    END          
    if(@Header='Quantity' or @Header='Rate' or @Header='HoldQuantity' or @Header='ReserveQuantity')              
    begin              
     select @CostCenterColID=CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SysColumnName=@Header              
        IF EXISTS(SELECT CostCenterColID FROM ADM_DocumentDef with(nolock) WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID)               
        BEGIN
              select      @DebitAccount = [DebitAccount]            
             ,  @CreditAccount =  [CreditAccount]   
             ,  @PostingType  =   [PostingType]         
             ,  @RoundOff    =   [RoundOff]       
             ,  @IsRoundOffEnabled  =    [IsRoundOffEnabled]                     
             ,  @IsDrAccountDisplayed =   [IsDrAccountDisplayed]          
             ,  @IsCrAccountDisplayed =  [IsCrAccountDisplayed]           
             ,  @IsDistributionEnabled =   [IsDistributionEnabled]          
             , @DistributionColID =  [DistributionColID]             
             ,@IsCalculate =  IsCalculate FROM ADM_DocumentDef WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID
        end
    end     
    if (exists(select IsGross  FROM @tblList WHERE ID=@I-1 and IsGross=1) and (@CostCenterColID IS NULL or @CostCenterColID <=0))
    begin
        if (@IsInventory=1)   
         select @CostCenterColID=CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SYSCOLUMNNAME='Gross'
        else if(@DocumentType in(17,28,29))
        BEGIN
			if(@Header like '%Debit%')
				select @CostCenterColID=CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SYSCOLUMNNAME='DebitAmount'
			else
				select @CostCenterColID=CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SYSCOLUMNNAME='CreditAmount'
        END
		else
         select @CostCenterColID=CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SYSCOLUMNNAME='Amount'
    end    
	
    IF(@CostCenterColID IS NULL or @CostCenterColID <=0)              
    BEGIN     
    
       --set @CostCenterColID=(select TOP 1 CostCenterColID from ADM_CostCenterDef  with(nolock)            
       --where CostCenterID=@CostCenterID and IsColumnInUse=0 and IsColumnUserDefined=1
       -- and syscolumnName like 'dcnum%' and SysTableName='COM_DocNumData' order by CostCenterColID)
        
        --ADIL
		select @CostCenterColID=CostCenterColID from ADM_CostCenterDef with(nolock)
		where CostCenterID=@CostCenterID 
			and SysTableName='COM_DocNumData' and SysColumnName='dcnum'+convert(nvarchar,@DbIndex)		
        IF(@CostCenterColID IS NULL or @CostCenterColID=0)
		BEGIN
			if(@Header!='Quantity' and @Header!='Rate' and @Header!='HoldQuantity' and @Header!='ReserveQuantity') 
			BEGIN			
					select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)

					INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
					VALUES (@ResID, 'dcNum'+convert(nvarchar,@DbIndex),1,'English', 'dcNum'+convert(nvarchar,@DbIndex),'')
					INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
					VALUES (@ResID, 'dcNum'+convert(nvarchar,@DbIndex),2,'Arabic', 'dcNum'+convert(nvarchar,@DbIndex),'')
				
					INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
					SELECT @CostCenterID,@ResID,DocumentName,'COM_DocNumData','dcNum'+convert(nvarchar,@DbIndex),'dcNum'+convert(nvarchar,@DbIndex),NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,49,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL
					FROM ADM_DocumentTypes with(nolock) WHERE CostCenterID=@CostCenterID
					SET @CostCenterColID=SCOPE_IDENTITY()

					INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
					SELECT @CostCenterID,@ResID,DocumentName,'COM_DocNumData','dcCalcNum'+convert(nvarchar,@DbIndex),'dcCalcNum'+convert(nvarchar,@DbIndex),NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,49,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL
					FROM ADM_DocumentTypes with(nolock) WHERE CostCenterID=@CostCenterID

					if(@IsFc=1)
					BEGIN
						INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
						SELECT @CostCenterID,@ResID,DocumentName,'COM_DocNumData','dcCalcNumFC'+convert(nvarchar,@DbIndex),'dcCalcNumFC'+convert(nvarchar,@DbIndex),NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,49,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL
						FROM ADM_DocumentTypes with(nolock) WHERE CostCenterID=@CostCenterID

						INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
						SELECT @CostCenterID,@ResID,DocumentName,'COM_DocNumData','dcExchRT'+convert(nvarchar,@DbIndex),'dcExchRT'+convert(nvarchar,@DbIndex),NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,49,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL
						FROM ADM_DocumentTypes with(nolock) WHERE CostCenterID=@CostCenterID

						INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,ParentCostCenterSysName,ParentCostCenterColSysName,ParentCCDefaultColID)
						SELECT @CostCenterID,@ResID,DocumentName,'COM_DocNumData','dcCurrID'+convert(nvarchar,@DbIndex),'dcCurrID'+convert(nvarchar,@DbIndex),NULL,'LISTBOX','LISTBOX','','',0,0,1,1,0,1,0,0,12,1,NULL,0,NULL,49,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL,'COM_Currency','CurrencyID',172
						FROM ADM_DocumentTypes with(nolock) WHERE CostCenterID=@CostCenterID
					END
			END
		END
		
        update @tblList
        set CostCenterColID=@CostCenterColID
        WHERE ID=@I-1
    END              
    
    --Add Numeric Column If Not Eixsts In Table
    if(@DbIndex is not null and @DbIndex>=1)
    begin
		if not exists (select Name from sys.columns where Name='dcNum'+convert(nvarchar,@DbIndex) and object_id=object_id('COM_DocNumData'))
		begin
			set @colsql='alter table COM_DocNumData add dcNum'+convert(nvarchar,@DbIndex)+' float
			,dcCalcNum'+convert(nvarchar,@DbIndex)+' float
			,dcCurrID'+convert(nvarchar,@DbIndex)+' int default(1)
			,dcExchRT'+convert(nvarchar,@DbIndex)+' float default(1)
			,dcCalcNumFC'+convert(nvarchar,@DbIndex)+' float'
			Exec sp_executesql @colsql
			
			set @colsql='alter table COM_DocNumData_History add dcNum'+convert(nvarchar,@DbIndex)+' float
			,dcCalcNum'+convert(nvarchar,@DbIndex)+' float
			,dcCurrID'+convert(nvarchar,@DbIndex)+' int default(1)
			,dcExchRT'+convert(nvarchar,@DbIndex)+' float default(1)
			,dcCalcNumFC'+convert(nvarchar,@DbIndex)+' float'
			Exec sp_executesql @colsql
		end
    end
    if(@SectionID=5)
    begin
		if not exists(select CostCenterID from ADM_CostCenterDef WITH(NOLOCK) where CostCenterID=@CostCenterID and SysColumnName='dcPOSRemarksNum'+convert(nvarchar,@DbIndex))
		begin
			select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)
			
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
			VALUES(@ResID,@Header+' Remarks',1,'English',@Header+' Remarks','',NULL,'ADMIN',44,NULL,NULL,NULL)
			INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
			VALUES(@ResID,@Header+' Remarks',2,'Arabic',@Header+' Remarks-AR','',NULL,'ADMIN',44,NULL,NULL,NULL)
			
			INSERT INTO [adm_costcenterdef] ([CostCenterID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat])
			select [CostCenterID],@ResID,[CostCenterName],[SysTableName],@Header+' Remarks','dcPOSRemarksNum'+replace(sysColumnName,'dcNum',''),[ColumnTypeSeqNumber],'','',[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat] 
			from adm_costcenterdef WITH(NOLOCK) where CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID
		end
    end
    
    if(@Header!='Quantity' and @Header!='Rate' and @Header!='HoldQuantity' and @Header!='ReserveQuantity')              
    begin  
         
        --set @abc=(select  top 1 SysColumnName from ADM_CostCenterDef              
        --where CostCenterID=@CostCenterID and IsColumnInUse=0 and IsColumnUserDefined=1 and SysTableName='COM_DocNumData'               
        --order by CostCenterColID)  
        DECLARE @COLNAME NVARCHAR(50)
        SELECT @abc = SYSCOLUMNNAME, @UserColumnName= UserColumnName FROM ADM_COSTCENTERDEF with(nolock)
        WHERE CostCenterID=@CostCenterID and COSTCENTERCOLID = @CostCenterColID and SysTableName='COM_DocNumData'
        
        set @Extention=LTRIM(replace(@abc,'dcNum',''))
            
        DELETE FROM @TBLCCCID
         
        if (@IsInventory=1  and exists(select SYSCOLUMNNAME FROM ADM_COSTCENTERDEF with(nolock)
        WHERE CostCenterID=@CostCenterID and COSTCENTERCOLID = @CostCenterColID and SYSCOLUMNNAME='Gross'))
        begin
            insert into @TBLCCCID (CCCID,SYSCOL, USERCOL)values(@CostCenterColID,'Gross', @Header)
        end
        else if (@IsInventory=0 and  exists(select SYSCOLUMNNAME FROM ADM_COSTCENTERDEF with(nolock)
        WHERE CostCenterID=@CostCenterID and COSTCENTERCOLID = @CostCenterColID and SYSCOLUMNNAME='Amount'))
        begin
            insert into @TBLCCCID (CCCID,SYSCOL, USERCOL)values(@CostCenterColID,'Amount', @Header)
        end
        else
        begin
            insert into @TBLCCCID
            select  CostCenterColID ,SYSCOLUMNNAME, USERCOLUMNNAME from ADM_CostCenterDef  with(nolock)            
            where CostCenterID=@CostCenterID  and
         (syscolumnname like 'dcNum'+@Extention or syscolumnname like 'dcCalcNum'+@Extention
         or   syscolumnname like 'dcCalcNumfc'+@Extention or  syscolumnname like 'dcCurrID'+@Extention or  syscolumnname like 'dcExchRT'+@Extention
         or syscolumnname like 'dcPOSRemarksNum'+@Extention)
            order by CostCenterColID  
        end
    
    
        Declare @LocI int , @LCnt int  
        
        select @LocI=min(id) ,@LCnt=count(id) from @TBLCCCID
        
        set @LCnt = @LocI + @LCnt -1
        
        while(@LocI <= @LCnt )
        BEGIN
         select @CCCID=CCCID  , @COLNAME = SYSCOL from @TBLCCCID where  ID = @LocI   

         IF( @CurrencyID IS NULL OR @CurrencyID = 0 )
            SET @CurrencyID = 1
        
         IF (@COLNAME LIKE 'dcCurrID%')
         BEGIN
            update ADM_CostCenterDef              
            set IsColumnInUse=1 ,UserColumnType = 'LISTBOX', ColumnDataType = 'LISTBOX' , UserDefaultValue = @CurrencyID, ColumnCostCenterID = 12,
              ColumnCCListViewTypeID = 1 , SectionID=@SectionID,SectionSeqNumber=@SectionSeqNumber,UIWidth=@UIWidth  ,IsColumnUserDefined = 1 ,IsVisible=@IsVisible             
            where CostCenterID=@CostCenterID and CostCenterColID=@CCCID
        
         END
         ELSE IF (@COLNAME LIKE 'dcExchRT%')
         BEGIN
            update ADM_CostCenterDef              
            set IsColumnInUse=1 , UserDefaultValue = @CurrencyID,
            ColumnCCListViewTypeID = 1 , SectionID=@SectionID,SectionSeqNumber=@SectionSeqNumber,UIWidth=@UIWidth  ,IsColumnUserDefined = 1 ,IsVisible=@IsVisible              
            where CostCenterID=@CostCenterID and CostCenterColID=@CCCID  
         END
         ELSE
         BEGIN
            if(@ColumnCostCenterID is not null and @ColumnCostCenterID>50000)
             begin
            select  @Local_Ref= CostCenterColID from ADM_CostCenterDef  with(nolock)            
             where CostCenterID=@CostCenterID and SysTableName='COM_DocCCData' and               
             SYSCOLUMNNAME='dcCCNID'+CONVERT(NVARCHAR,(@ColumnCostCenterID-50000))   
            end
            
             update ADM_CostCenterDef              
             set IsColumnInUse=1  ,TextFormat=@TextFormat,ColumnSpan=@Colspan,  UserDefaultValue = @CurrencyID ,IsMandatory=@IsMandatory             
              ,SectionID=@SectionID,SectionSeqNumber=@SectionSeqNumber,UIWidth=@UIWidth  , IsUnique = @IsUnique,IsVisible=@IsVisible
              ,LINKDATA = @Link_Data,LastValueVouchers=@vouchers ,IsEditable = ISNULL(@IsReadOnly,1)
              ,LOCALREFERENCE = @Local_Ref ,decimal=@Decimals,IsRepeat=@IsRepeat,IsnoTab=@noTab              
             where CostCenterID=@CostCenterID and CostCenterColID=@CCCID     
         END
		 
         if(@UserColumnName!='')
         begin
			if @COLNAME LIKE 'dcPOSRemarksNum%'
			 begin
				update com_languageresources set resourcedata=@Header+' Remarks'  where [LanguageID]=@LangID AND resourceid in (select resourceid from adm_Costcenterdef with(nolock) where CostCenterID=@CostCenterID and CostCenterColID=@CCCID )
				update ADM_CostCenterDef set UserColumnName=@Header+' Remarks' where CostCenterID=@CostCenterID and CostCenterColID=@CCCID    
			 end
			 else
			 begin
				 update com_languageresources set resourcedata=@UsercolumnName  where [LanguageID]=@LangID AND resourceid in (select resourceid from adm_Costcenterdef with(nolock) where CostCenterID=@CostCenterID and CostCenterColID=@CCCID )
				 update ADM_CostCenterDef set UserColumnName=    @UsercolumnName       where CostCenterID=@CostCenterID and CostCenterColID=@CCCID    
			 end
         end
         
         set @LocI=@LocI+1         
        END
    end
         
    if(@CrRefColID is not null and @CrRefColID>0)
    begin   
        select @ColumnCostCenterID=CostCenterID from ADM_CostCenterDef with(nolock) where CostCenterColID=@CrRefColID
        if(@ColumnCostCenterID>50000)
        begin
			if(@CrRefID<0)
				select  @CrRefID= -CostCenterColID from ADM_CostCenterDef WITH(NOLOCK)             
				where CostCenterID=@CostCenterID and SysTableName='COM_DocCCData' and               
				SYSCOLUMNNAME='dcCCNID'+CONVERT(NVARCHAR,(@ColumnCostCenterID-50000))             
            else
				select  @CrRefID= CostCenterColID from ADM_CostCenterDef WITH(NOLOCK)             
				where CostCenterID=@CostCenterID and SysTableName='COM_DocCCData' and               
				SYSCOLUMNNAME='dcCCNID'+CONVERT(NVARCHAR,(@ColumnCostCenterID-50000))             
        end
    end
    if(@DrRefColID is not null and @DrRefColID>0)
    begin    
        select @ColumnCostCenterID=CostCenterID from ADM_CostCenterDef with(nolock) where CostCenterColID=@DrRefColID
        if(@ColumnCostCenterID>50000)
        begin
			if(@DrRefID<0)
				select  @DrRefID= -CostCenterColID from ADM_CostCenterDef with(nolock)             
				 where CostCenterID=@CostCenterID and SysTableName='COM_DocCCData' and               
				 SYSCOLUMNNAME='dcCCNID'+CONVERT(NVARCHAR,(@ColumnCostCenterID-50000))
             else
				select  @DrRefID= CostCenterColID from ADM_CostCenterDef with(nolock)             
				 where CostCenterID=@CostCenterID and SysTableName='COM_DocCCData' and               
				 SYSCOLUMNNAME='dcCCNID'+CONVERT(NVARCHAR,(@ColumnCostCenterID-50000))
        end
    end
    
    IF EXISTS(SELECT CostCenterColID FROM ADM_DocumentDef with(nolock) WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID)               
    BEGIN              
              
     UPDATE ADM_DocumentDef set              
     [DebitAccount] = @DebitAccount              
     ,[CreditAccount] = @CreditAccount              
     ,[Formula] = @Formula              
     ,[PostingType] = @PostingType              
     ,[RoundOff] = @RoundOff              
     ,[IsRoundOffEnabled] = @IsRoundOffEnabled              
     ,Distributeon=@Distributeon              
     ,Distxml=@Distxml              
     ,[IsDrAccountDisplayed] = @IsDrAccountDisplayed              
     ,[IsCrAccountDisplayed] = @IsCrAccountDisplayed              
     ,[IsDistributionEnabled] = @IsDistributionEnabled              
     ,[DistributionColID] =@DistributionColID                
     ,IsCalculate=@IsCalculate   
       ,CrRefID=@CrRefID, CrRefColID=@CrRefColID , DrRefID =@DrRefID,DrRefColID =@DrRefColID
       ,EvaluateAfter=@EvaluateAfter
       ,RoundOffLineWise=@LineRoundoff
       ,FixedAcc=@FixedAcc
       ,IsPartialLinking=@IsPartialLink
       ,showbodytotal=isnull(@showtotal,1)
       ,basedonXMl=@basedonXMl,Posting=@Posting
     WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID              
    END              
    ELSE if(@CostCenterColID is not null)              
    BEGIN               
              
     INSERT INTO [ADM_DocumentDef]              
          ([DocumentTypeID]              
          ,[CostCenterID]             
          ,[CostCenterColID]              
          ,[DebitAccount]              
          ,[CreditAccount]              
          ,[Formula]              
          ,[PostingType]              
          ,[RoundOff]              
          ,Distributeon
          ,Distxml              
          ,[IsRoundOffEnabled]              
          ,[IsDrAccountDisplayed]           
          ,[IsCrAccountDisplayed]              
          ,[IsDistributionEnabled]              
          ,[DistributionColID]              
          ,[IsCalculate]              
          ,[CompanyGUID]              
          ,[GUID]              
          ,[CreatedBy]              
          ,[CreatedDate]
            ,CrRefID
            ,CrRefColID
            ,DrRefID
            ,DrRefColID,showbodytotal,EvaluateAfter,basedonXMl,Posting,RoundOffLineWise,FixedAcc,IsPartialLinking)              
       VALUES              
          (@DocumentTypeID              
          ,@CostCenterID              
          ,@CostCenterColID              
          ,@DebitAccount              
          ,@CreditAccount              
          ,@Formula              
          ,@PostingType              
          ,@RoundOff              
          ,@Distributeon
          ,@Distxml              
          ,@IsRoundOffEnabled              
          ,@IsDrAccountDisplayed              
          ,@IsCrAccountDisplayed              
          ,@IsDistributionEnabled       
          ,@DistributionColID              
          ,@IsCalculate              
          ,@CompanyGUID              
          ,newid()               
          ,@UserName              
          ,convert(float,getdate())
          ,@CrRefID              
          ,@CrRefColID    
          ,@DrRefID           
          ,@DrRefColID ,isnull(@showtotal,1) ,@EvaluateAfter,@basedonXMl,@Posting,@LineRoundoff,@FixedAcc,@IsPartialLink   )
        END       
   END              
   ELSE IF(@ColFieldType=3)              
   BEGIN  
     if(@ColumnCostCenterID is not null and (@ColumnCostCenterID=65 or @ColumnCostCenterID=7 or @ColumnCostCenterID=83 or @ColumnCostCenterID>50000))
     begin
            if(@ColumnCostCenterID=65)
            begin
                select  @Local_Ref= CostCenterColID from ADM_CostCenterDef with(nolock)             
                where CostCenterID=@CostCenterID and SYSCOLUMNNAME='ContactID'
            end    
            else if(@ColumnCostCenterID=7)
            begin
                select  @Local_Ref= CostCenterColID from ADM_CostCenterDef  with(nolock)            
                where CostCenterID=@CostCenterID and SYSCOLUMNNAME='UserID'
            end
            else if(@ColumnCostCenterID=83)
            begin
                select  @Local_Ref= CostCenterColID from ADM_CostCenterDef with(nolock)             
                where CostCenterID=@CostCenterID and SYSCOLUMNNAME='CustomerID'
            end    
            else
            begin                
                select  @Local_Ref= CostCenterColID from ADM_CostCenterDef with(nolock)             
                 where CostCenterID=@CostCenterID and SysTableName='COM_DocCCData' and               
                 SYSCOLUMNNAME='dcCCNID'+CONVERT(NVARCHAR,(@ColumnCostCenterID-50000))   
            end
       end
        
		IF(@CostCenterColID IS NULL or @CostCenterColID=0)
		BEGIN			
			/*set @CostCenterColID=(select  top 1 CostCenterColID from ADM_CostCenterDef with(nolock)
			where CostCenterID=@CostCenterID and IsColumnInUse=0 and IsColumnUserDefined=1 and SysTableName='COM_DocTextData'
			order by CostCenterColID)*/
			--ADIL
			select @CostCenterColID=CostCenterColID from ADM_CostCenterDef with(nolock)
			where CostCenterID=@CostCenterID and IsColumnInUse=0 and IsColumnUserDefined=1 and SysTableName='COM_DocTextData' and SysColumnName='dcAlpha'+convert(nvarchar,@DbIndex)
			order by CostCenterColID
			
			IF(@CostCenterColID IS NULL or @CostCenterColID=0)
			BEGIN
				select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)

				INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
				VALUES (@ResID, 'dcAlpha'+convert(nvarchar,@DbIndex),1,'English', 'dcAlpha'+convert(nvarchar,@DbIndex),'')
				INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
				VALUES (@ResID, 'dcAlpha'+convert(nvarchar,@DbIndex),2,'Arabic', 'dcAlpha'+convert(nvarchar,@DbIndex),'')
				
				INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
				SELECT @CostCenterID,@ResID,DocumentName,'COM_DocTextData','dcAlpha'+convert(nvarchar,@DbIndex),'dcAlpha'+convert(nvarchar,@DbIndex),NULL,'TEXT','TEXT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,49,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL
				FROM ADM_DocumentTypes with(nolock) WHERE CostCenterID=@CostCenterID
				SET @CostCenterColID=SCOPE_IDENTITY()
			END

			update @tblList
			set CostCenterColID=@CostCenterColID
			WHERE ID=@I-1		          
		END

		--Add Text Column If Not Eixsts In Table
		if(@DbIndex is not null and @DbIndex>=1)
		begin
			if not exists (select Name from sys.columns where Name='dcAlpha'+convert(nvarchar,@DbIndex) and object_id=object_id('COM_DocTextData'))
			begin
				if(@colType in('FixedDate','FixedDateTime'))
				BEGIN
					set @colsql='alter table COM_DocTextData add dcAlpha'+convert(nvarchar,@DbIndex)+' Datetime'
					Exec sp_executesql @colsql
					
					set @colsql='alter table COM_DocTextData_History add dcAlpha'+convert(nvarchar,@DbIndex)+' Datetime'
					Exec sp_executesql @colsql					
				END
				ELSE
				BEGIN				
					set @colsql='alter table COM_DocTextData add dcAlpha'+convert(nvarchar,@DbIndex)+' nvarchar(max)'
					Exec sp_executesql @colsql
					
					set @colsql='alter table COM_DocTextData_History add dcAlpha'+convert(nvarchar,@DbIndex)+' nvarchar(max)'
					Exec sp_executesql @colsql
				END	
			end
			else if exists (select Name from sys.columns where Name='dcAlpha'+convert(nvarchar,@DbIndex) and system_type_id=61
				and object_id=object_id('COM_DocTextData'))
			BEGIN
				if(@colType not in('FixedDate','FixedDateTime','Date','DateTime'))	
				begin
					set @colsql='Can not assign other than date field at Row no.'+convert(nvarchar,@DbIndex)
					RAISERROR(@colsql,16,1)
				END			
			END
			else if(@colType in('FixedDate','FixedDateTime'))	
			BEGIN
			 if not exists (select Name from sys.columns where Name='dcAlpha'+convert(nvarchar,@DbIndex) and system_type_id=61
				and object_id=object_id('COM_DocTextData'))
				begin
					set @colsql=' Row no.'+convert(nvarchar,@DbIndex)+' is not a date field Can not assign '+@colType
					RAISERROR(@colsql,16,1)
				END			
			END
		end		
		
        if(@ListViewTypeID is null)
        BEGIN
			if(@TextColumnCostcenterID=2)
			begin
				set @ListViewTypeID=2
			end
			else if(@TextColumnCostcenterID=3)
			begin
				set @ListViewTypeID=10
			end
			else if(@TextColumnCostcenterID > 50000)
			begin
				set @ListViewTypeID=1
			end          
        END   
      
             
      update ADM_CostCenterDef              
      set IsColumnInUse=1,SectionSeqNumber=@SectionSeqNumber,UIWidth=@UIWidth,     UserColumnName=@Header ,                        
      SectionID=@SectionID,              
      UserDefaultValue=@UserDefaultValue              
      ,SectionName =@SectionName,TextFormat=@TextFormat,ColumnSpan=@Colspan              
      ,IsMandatory=@IsMandatory ,LastValueVouchers=@vouchers,
      ColumnCostCenterID=isnull( @TextColumnCostcenterID,0),  ColumnCCListViewTypeID=isnull( @ListViewTypeID,0)
      ,IsUnique = @IsUnique  ,IsnoTab=@noTab  
      ,IsEditable =ISNULL(@IsReadOnly,1)
      ,LINKDATA = @Link_Data,Calculate=@IsCalculate
      ,LOCALREFERENCE = @Local_Ref    ,UserColumnType=@colType,UserProbableValues=@ProbValues,IsVisible=@IsVisible,IsRepeat=@IsRepeat   
      ,dependanton=@dependanton   
      ,decimal=@Decimals,IgnoreChar=@IgnoreChars ,WaterMark=@WaterMark,MinChar=@MinChar,MaxChar=@MaxChar
     where CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID
	
		if(@Formula<>'')
		BEGIN
			IF EXISTS(SELECT CostCenterColID FROM ADM_DocumentDef with(nolock) WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID)               
			BEGIN  
				UPDATE ADM_DocumentDef set              
				[Formula] = @Formula              
				WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID              
			END              
			ELSE if(@CostCenterColID is not null)              
			BEGIN    
				INSERT INTO [ADM_DocumentDef]              
				([DocumentTypeID]              
				,[CostCenterID]             
				,[CostCenterColID]             
				,[Formula],IsCalculate      
				,[CompanyGUID]              
				,[GUID]              
				,[CreatedBy]              
				,[CreatedDate])              
				VALUES              
				(@DocumentTypeID              
				,@CostCenterID              
				,@CostCenterColID            
				,@Formula,0              
				,@CompanyGUID              
				,newid()               
				,@UserName              
				,convert(float,getdate()))
			END      
		END 
		ELSE IF EXISTS(SELECT CostCenterColID FROM ADM_DocumentDef with(nolock) WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID)               
		BEGIN  
				UPDATE ADM_DocumentDef set              
				[Formula] = @Formula              
				WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID              
		END              
           
   END              
   ELSE IF(@ColFieldType=2)              
   BEGIN      
      if(@ColumnCostCenterID=65)
      begin
            select  @CostCenterColID= CostCenterColID from ADM_CostCenterDef with(nolock)             
            where CostCenterID=@CostCenterID and SYSCOLUMNNAME='ContactID'
      end 
      else if(@ColumnCostCenterID=7)
      begin
            select  @CostCenterColID= CostCenterColID from ADM_CostCenterDef with(nolock)             
            where CostCenterID=@CostCenterID and SYSCOLUMNNAME='UserID'
      end   
      else if(@ColumnCostCenterID=83)
      begin
            select  @CostCenterColID= CostCenterColID from ADM_CostCenterDef with(nolock)             
            where CostCenterID=@CostCenterID and SYSCOLUMNNAME='CustomerID'
      end 
      else if(@IsInventory=0 and @ColumnCostCenterID=16)
      begin
			if not exists (select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where a.name='BatchID' and b.name='Acc_DocDetails')
			BEGIN
				 alter table Acc_DocDetails add [BatchID] INT Default(1)
			END 
			if not exists(select CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SYSCOLUMNNAME='BatchID')
			BEGIN
				if exists (select [IsUserDefined] from ADM_DocumentTypes with(nolock) where CostCenterID=@CostCenterID and [IsUserDefined]=1)
				BEGIN
					select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)
					
					INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
					VALUES(@ResID,'Batch',1,'English','Batch','')

					INSERT INTO [adm_costcenterdef] ([CostCenterID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])
					VALUES(@CostCenterID,@ResID,'Documents','Acc_DocDetails','Batch','BatchID',NULL,'LISTBOX','LISTBOX','1',NULL,8,1,1,1,1,1,0,0,16,1,NULL,0,NULL,10,550,NULL,8,3,1,1,NULL,'6711ABED-2B8C-4289-8FE5-E1FC04529975','700B4CF7-6194-4B3A-A7A2-7C6310F8CEAF',NULL,'Admin',4.073374614907408e+004,NULL,NULL,NULL,1,16,0,1,'INV_Batches','BatchID',1558,NULL,NULL,NULL,0,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,9,NULL,NULL,1)
				
				END
				ELSE
				BEGIN
					select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)
					where [ResourceID]<500000
					
					INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[FEATURE])
					VALUES(@ResID,'Batch',1,'English','Batch','')
					
					select @CostCenterColID=max([CostCenterColID])+1 from [adm_costcenterdef] WITH(NOLOCK)
					where [CostCenterColID]<500000
					set identity_insert [adm_costcenterdef] ON
					INSERT INTO [adm_costcenterdef] ([CostCenterID],[CostCenterColID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])
					VALUES(@CostCenterID,@CostCenterColID,@ResID,'Documents','Acc_DocDetails','Batch','BatchID',NULL,'LISTBOX','LISTBOX','1',NULL,8,1,1,1,0,1,0,0,16,1,NULL,0,NULL,10,550,NULL,8,3,1,1,NULL,'6711ABED-2B8C-4289-8FE5-E1FC04529975','700B4CF7-6194-4B3A-A7A2-7C6310F8CEAF',NULL,'Admin',4.073374614907408e+004,NULL,NULL,NULL,1,16,0,1,'INV_Batches','BatchID',1558,NULL,NULL,NULL,0,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,9,NULL,NULL,1)
					set identity_insert [adm_costcenterdef] OFF
				END	
			END
            select  @CostCenterColID= CostCenterColID from ADM_CostCenterDef with(nolock)             
            where CostCenterID=@CostCenterID and SYSCOLUMNNAME='BatchID'
      end    
      else
      begin          
		set @CostCenterColID=0
         select  @CostCenterColID= CostCenterColID from ADM_CostCenterDef with(nolock)             
         where CostCenterID=@CostCenterID and SysTableName='COM_DocCCData' and               
         SYSCOLUMNNAME='dcCCNID'+CONVERT(NVARCHAR,(@ColumnCostCenterID-50000))              
      end
      
        update @tblList
		set CostCenterColID=@CostCenterColID
		WHERE ID=@I-1
		
      if(@CostCenterColID is null or @CostCenterColID=0)
      BEGIN
			select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)

			INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
			VALUES (@ResID, 'dcCCNID'+convert(nvarchar,(@ColumnCostCenterID-50000)),1,'English',@Header ,'')
			INSERT INTO COM_LanguageResources (ResourceID, ResourceName, LanguageID, LanguageName, ResourceData,FEATURE)
			VALUES (@ResID, 'dcCCNID'+convert(nvarchar,(@ColumnCostCenterID-50000)),2,'Arabic', @Header,'')
			
			INSERT INTO ADM_CostCenterDef (CostCenterID,ResourceID,CostCenterName,SysTableName,UserColumnName,SysColumnName,ColumnTypeSeqNumber,UserColumnType,ColumnDataType,UserDefaultValue,UserProbableValues,ColumnOrder,IsMandatory,IsEditable,IsVisible,IsCostCenterUserDefined,IsColumnUserDefined,IsCCDeleted,IsColumnDeleted,ColumnCostCenterID,ColumnCCListViewTypeID,FetchMaxRows,IsColumnGroup,ColumnGroupNumber,SectionSeqNumber,SectionID,SectionName,RowNo,ColumnNo,ColumnSpan,IsColumnInUse,UIWidth,CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate
			,[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID])
			SELECT @CostCenterID,@ResID,DocumentName,'COM_DocCCData',@Header,'dcCCNID'+convert(nvarchar,(@ColumnCostCenterID-50000)),NULL,'LISTBOX','LISTBOX','','',0,0,1,1,0,1,0,0,@ColumnCostCenterID,1,NULL,0,NULL,49,NULL,NULL,NULL,NULL,NULL,0,NULL,'COMPANYGUID','EA03CE5E-E892-4DF3-AD70-4338FE733ED1',NULL,'ADMIN',4,NULL,NULL
			,1,@ColumnCostCenterID,0,1,(SELECT TOP 1 TableName FROM [ADM_Features] with(nolock) WHERE FeatureID=@ColumnCostCenterID),'NodeID',(SELECT TOP 1 CostCenterColID FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@ColumnCostCenterID AND SysColumnName='Name')
			FROM ADM_DocumentTypes with(nolock)
			WHERE CostCenterID=@CostCenterID 
			SET @CostCenterColID=SCOPE_IDENTITY()
	  END

	  --Add Costcenter Column If Not Eixsts In Table
	  if(@ColumnCostCenterID is not null and @ColumnCostCenterID>50000)
	  begin
		if not exists (select Name from sys.columns where Name='dcCCNID'+convert(nvarchar,@ColumnCostCenterID-50000) and object_id=object_id('COM_DocCCData'))
		begin
			SELECT @colsql='alter table COM_DocCCData add dcCCNID'+convert(nvarchar,@ColumnCostCenterID-50000)+' '+DATA_TYPE+' default(1) not null
			ALTER TABLE [COM_DocCCData] WITH CHECK ADD  CONSTRAINT [FK_COM_DocCCData_COM_CC'+convert(nvarchar,@ColumnCostCenterID)+'] FOREIGN KEY([dcCCNID'+convert(nvarchar,@ColumnCostCenterID-50000)+']) REFERENCES [COM_CC'+convert(nvarchar,@ColumnCostCenterID)+'] ([NodeID])
			ALTER TABLE [COM_DocCCData] CHECK CONSTRAINT [FK_COM_DocCCData_COM_CC'+convert(nvarchar,@ColumnCostCenterID)+']'
			FROM INFORMATION_SCHEMA.COLUMNS WITH(NOLOCK) 
			WHERE TABLE_NAME='COM_CC'+convert(nvarchar,@ColumnCostCenterID) AND COLUMN_NAME='NodeID'
			
			Exec sp_executesql @colsql
						
			set @colsql='alter table COM_DocCCData_History add dcCCNID'+convert(nvarchar,@ColumnCostCenterID-50000)+' INT  default(1) not null'
			Exec sp_executesql @colsql
		end
  	  end
	        
       if(@Link_Data is not null and (@Link_Data=65 or @Link_Data=7 or @Link_Data=83 or @Link_Data>50000))
       begin
                if(@Link_Data=65)
                begin
                    select  @Local_Ref= CostCenterColID from ADM_CostCenterDef with(nolock)             
                    where CostCenterID=@CostCenterID and SYSCOLUMNNAME='ContactID'
                end    
                else if(@Link_Data=7)
                begin
                    select  @Local_Ref= CostCenterColID from ADM_CostCenterDef with(nolock)             
                    where CostCenterID=@CostCenterID and SYSCOLUMNNAME='UserID'
                end
                else if(@Link_Data=83)
                begin
                    select  @Local_Ref= CostCenterColID from ADM_CostCenterDef with(nolock)             
                    where CostCenterID=@CostCenterID and SYSCOLUMNNAME='CustomerID'
                end                
                else
                begin
                    select  @Local_Ref= CostCenterColID from ADM_CostCenterDef with(nolock)             
                     where CostCenterID=@CostCenterID and SysTableName='COM_DocCCData' and               
                     SYSCOLUMNNAME='dcCCNID'+CONVERT(NVARCHAR,(@Link_Data-50000))   
                end
       end   
       IF NOT EXISTS(select * from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID AND @Local_Ref=-CostCenterColID)         
			SET @Link_Data=NULL  
      update ADM_CostCenterDef              
      set IsColumnInUse=1,SectionSeqNumber=@SectionSeqNumber,UIWidth=@UIWidth,              
      SectionID=@SectionID  , UserColumnName=@Header,fetchmaxrows=@GridViewID,ColumnSpan=@Colspan 
      ,ColumnCostCenterID=@ColumnCostCenterID ,UserColumnType='LISTBOX',UserProbableValues=@ProbValues             
      ,UserDefaultValue=@UserDefaultValue,ColumnCCListViewTypeID=isnull(@ListViewTypeID,1)
      ,SectionName =@SectionName,IsEditable =ISNULL(@IsReadOnly,1)       
      ,IsMandatory=@IsMandatory,TextFormat=@TextFormat,dependancy=@dependancy,dependanton=@dependanton
      ,IsUnique = @IsUnique,Filter=@Filter,IsnoTab=@noTab  ,CrFilter=@CrFilter,DbFilter=@DbFilter
      ,IsVisible=@IsVisible,LINKDATA=@Link_Data,LOCALREFERENCE = @Local_Ref    ,IsRepeat=@IsRepeat,IsTransfer=@IsTransfer,LastValueVouchers=@vouchers
      ,decimal=@Decimals,Cformula=@Formula
     where CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID   
                  
   END              
   ELSE IF(@ColFieldType=4)              
   BEGIN              

     update ADM_CostCenterDef              
     set SectionSeqNumber=@SectionSeqNumber,UIWidth=@UIWidth ,TextFormat=@TextFormat
     --,ColumnSpan=@Colspan           
     --,sectionID= case when @SectionID=null then SectionID else @SectionID end,
     --SectionName=case when @SectionName=null then SectionName else @SectionName  end                  
     where CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID
   END
              
  if(@Header is not null and  @Header!='Quantity' and @Header!='Rate' and @Header!='HoldQuantity' and @Header!='ReserveQuantity' and @Header!='Gross')              
  begin              
   UPDATE COM_LanguageResources              
   SET ResourceData=@Header
   WHERE ResourceID=(SELECT ResourceID FROM ADM_CostCenterDef with(nolock)             
   WHERE CostCenterColID=@CostCenterColID and CostCenterID=@CostCenterID) AND LanguageID=@LangID      
   
   update ADM_CostCenterDef set Usercolumnname=@Header
   where  CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID
  end              
              
              
  END     
  
	if (@CostCenterID<>40994 and exists(select * from adm_costcenterdef WITH(NOLOCK) where CostCenterID=@CostCenterID and sectionid>4))
	BEGIN
		if exists(select a.syscolumnname,a.sectionid,b.syscolumnname,b.sectionid,b.costcentername,* from adm_costcenterdef a WITH(NOLOCK)
		join adm_costcenterdef b WITH(NOLOCK) on a.syscolumnname=b.syscolumnname
		join adm_documenttypes c WITH(NOLOCK) on b.costcenterid=c.costcenterid
		where a.costcenterid=40994 and c.documenttype in(38,39,18)
		and a.syscolumnname like 'dcnum%' and b.syscolumnname like 'dcnum%' 
		and (a.sectionid>4 or b.sectionid>4) and (a.iscolumninuse=1 or b.sectionid>4) and b.iscolumninuse=1 
		and (a.sectionid<>b.sectionid or a.sectionid is null or b.sectionid is null))
			RAISERROR('-579',16,1)              
			
	END	
	
   SET @XML=@CopyDocumentXML              
   
   Delete from Com_CopyDocumentDetails  WHERE [CostCenterIDBase]=(SELECT COSTCENTERID FROM ADM_DocumentTypes               
   WITH(NOLOCK) WHERE  DocumentTypeID=@DocumentTypeID) 
   
    insert into Com_CopyDocumentDetails (CostCenterIDBase,CostCenterIDLinked,CostCenterColIDBase,CostCenterColIDLinked,
										 CompanyGUID,GUID,Description,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,[View],SelectionType
										 ,Width,DisplayIndex,GridViewID)
										 --,IncludeUnPosted
				select X.value('@CostCenterIDBase','int'),X.value('@CostCenterIDLink','int'),X.value('@CostCenterColIDBase','int'),
					   X.value('@CostCenterColIDLink','int'),@CompanyGUID,NEWID(),'Description',@UserName,convert(float,getdate()),@UserName,convert(float,getdate())
					   ,isnull(X.value('@View','bit'),0),isnull(X.value('@SelectionType','int'),0)
					   ,isnull(X.value('@Width','float'),100),isnull(X.value('@DisplayIndex','int'),0),isnull(X.value('@GridViewID','int'),0)
					  -- ,X.value('@IncludeUnPosted','bit')
				FROM  @XML.nodes('/Xml/Row') as Data(X)   
				     
  SET @XML=@LinkXML              
  
  DELETE FROM COM_DocLinkCloseDetails where CostCenterID=@CostCenterID
          
   DELETE FROM COM_DocumentLinkDetails where DocumentLinkDefID in (
   select DocumentLinkDefID FROM [COM_DocumentLinkDef]  with(nolock)            
   WHERE CostCenterIDBase=@CostCenterID)
    
  DELETE FROM [COM_DocumentLinkDef]              
  WHERE CostCenterIDBase=@CostCenterID AND DocumentLinkDefID NOT IN               
  (SELECT  X.value('@DocumentLinkDefID','int') FROM  @XML.nodes('/Xml/Row') as Data(X)              
  WHERE  X.value('@DocumentLinkDefID','int')> 0 )     
 
             
  declare @LinkcolsXML XML, @CostCenterColIDBase int,@IsExecuted bit,@LinkDefID INT, @CostCenterIDLinked int ,@CostCenterColIDLinked int,@IsDefault bit,@vchers NVARCHAR(MAX),@ViewID INT,@AutoSelect bit
  if(@LinkXML IS NOT NULL AND @LinkXML <>'')              
  BEGIN              
   
   declare @TempTable table(tempid int identity(1,1),LinkDefID INT,CostCenterColIDBase int,CostCenterIDLinked int,CostCenterColIDLinked int,IsDefault bit,AutoSelect bit,Vouchers NVARCHAR(MAX),Cols NVARCHAR(MAX),IsExecuted bit,ViewID INT)

   insert into @TempTable
   select X.value('@DocumentLinkDefID','int'),X.value('@CostCenterColIDBase','int'),X.value('@CostCenterIDLinked','int'),X.value('@CostCenterColIDLinked','int'),isnull(X.value('@IsDefault','bit'),0),isnull(X.value('@AutoSelect','bit'),0)
   ,X.value('@Vouchers','NVARCHAR(MAX)'),CONVERT(NVARCHAR(MAX), X.query('BaseLinkDetails')),X.value('@IsExecuted','BIT'),isnull(X.value('@ViewID','int'),0)
     from @XML.nodes('/Xml/Row') as Data(X)

   select @l=1,@cts=count(tempid) from @TempTable

    while(@l<=@cts)
   begin

        select @LinkDefID=LinkDefID,@CostCenterColIDBase=CostCenterColIDBase,@CostCenterIDLinked=CostCenterIDLinked,@IsExecuted=IsExecuted,@ViewID=ViewID ,
        @vchers=Vouchers,@CostCenterColIDLinked=CostCenterColIDLinked,@IsDefault=IsDefault,@AutoSelect=AutoSelect,@LinkcolsXML=Cols from @TempTable where tempid=@l

    

        IF(@LinkDefID>0)
        BEGIN
         UPDATE [COM_DocumentLinkDef]              
			SET [CostCenterIDBase] = @CostCenterID              
			,[CostCenterColIDBase] =      @CostCenterColIDBase       
			,[CostCenterIDLinked] = @CostCenterIDLinked
			,[CostCenterColIDLinked] = @CostCenterColIDLinked
			,[LinkedVouchers] = @vchers
			,[IsDefault] = @IsDefault              
			,[ModifiedBy]=@UserName              
			,[ModifiedDate]=convert(float,getdate())
			,IsQtyExecuted=@IsExecuted
			,AutoSelect=@AutoSelect
			,ViewID=@ViewID              
            WHERE DocumentLinkDefID=@LinkDefID    
        END
        ELSE
        BEGIN
           INSERT INTO [COM_DocumentLinkDef]              
                ([CostCenterIDBase]              
                ,[CostCenterColIDBase]              
                ,[CostCenterIDLinked]              
                ,[CostCenterColIDLinked]  
                ,[LinkedVouchers]            
                ,[IsDefault]              
                ,[CompanyGUID]              
                ,[GUID]              
                ,[CreatedBy]              
                ,[CreatedDate]
                ,IsQtyExecuted
                ,AutoSelect
                ,ViewID)              
          SELECT              
                @CostCenterID              
                ,@CostCenterColIDBase           
                ,@CostCenterIDLinked            
                ,@CostCenterColIDLinked             
                ,@vchers
                ,@IsDefault           
                ,@CompanyGUID,NEWID() 
                ,@UserName
                ,CONVERT(FLOAT,GETDATE())
                ,@IsExecuted
                ,@ViewID
                ,@AutoSelect
                set @LinkDefID=scope_identity()    
        END
        
     
        insert into COM_DocumentLinkDetails(DocumentLinkDeFID,
                                            CostCenterColIDBase,
                                            CostCenterColIDLinked,
                                            [View],UpdateSource,CalcValue,
                                            CompanyGUID,
                                            GUID,
                                            CreatedBy,
                                            CreatedDate)
        select @LinkDefID,X.value('@CostCenterColIDBase','int'),X.value('@CostCenterColIDLink','int'),X.value('@View','bit'),isnull(X.value('@UpdateSource','bit'),0),isnull(X.value('@CalcValue','bit'),0) ,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE())
        from @LinkcolsXML.nodes('/BaseLinkDetails/SubRow') as Data(X)
 
        
      set @l=@l+1
   END
  end
 
  SET @XML=@DynamicXML
 
    BEGIN
    
       DELETE FROM COM_DocumentDynamicMapping where DocumentTypeID=@DocumentTypeID
   
       insert into COM_DocumentDynamicMapping(DocumentTypeID,
                                                CostCenterColIDField,
                                                CostCenterColIDMapping,
                                                ClubFields,IgnoreKit,delimiter,Show
                                                ,ListTypeID,CompanyGUID,
                                                GUID,
                                                CreatedBy,
                                                CreatedDate,DistributOn)
        select @DocumentTypeID,X.value('@Fields','int'),X.value('@Mapping','int'),X.value('@ClubFields','bit'),X.value('@IgnoreKit','bit')
        ,X.value('@delimiter','nvarchar(5)'),X.value('@Show','bit'),X.value('@ListTypeID','int'),@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE())
        ,X.value('@DistributOn','nvarchar(200)')
        from @XML.nodes('/DynamicMappingDetails/DynRow') as Data(X)
        
     END             

    if(@CloseLink<>'')
    BEGIN
		SET @XML=@CloseLink
		
		insert into COM_DocLinkCloseDetails		
		select @CostCenterID,X.value('@SrcDoc','int'),X.value('@from','int'),X.value('@Fld','nvarchar(10)')
        from @XML.nodes('/Xml/Row') as Data(X)
    
    END          
              
    if(@Attachment<>'')
    BEGIN
		SET @XML=@Attachment
		
		delete from COM_Files
		where FeatureID=400 and FeaturePK=@CostCenterID
		
	   INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
	   FileExtension,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
	   GUID,CreatedBy,CreatedDate,IsDefaultImage)  
	   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@ActualFileName','NVARCHAR(50)'),  
	   X.value('@FileExtension','NVARCHAR(50)'),0,400,400,@CostCenterID,
	   X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  ,0
	   FROM @XML.nodes('/Attachments') as Data(X)    	    
    END
   --- CHANGES MADE ON  JUNE 27 2012 by hafeez
   if(@COLUMNSXML<>'')
   BEGIN
       DECLARE @StaticXMLData XML
       SET @StaticXMLData = @COLUMNSXML
        
        IF(@StaticXMLData IS NOT NULL)
        BEGIN
            UPDATE ADM_COSTCENTERDEF
            SET  SectionSeqNumber = X.value('@Order','INT'),  
                IsVisible = isnull(X.value('@Visible','BIT'),1),
                IsEditable = X.value('@Editable','BIT'),
                IsMandatory = X.value('@Mandatory','BIT'),
                Columnspan= X.value('@ColumnSpan','INT'),
                TextFormat= X.value('@TextFormat','INT') ,IsnoTab=isnull(X.value('@noTab','bit'),0)
                 ,ColumnCCListViewTypeID=isnull(X.value('@ListViewID','int'),0)
                 ,IsRepeat= X.value('@IsRepeat','BIT')
                 ,fetchmaxrows=X.value('@GridViewID','int')
                 ,IgnoreChar=X.value('@IgnoreChars','int')
                 ,WaterMark=X.value('@WaterMark','NVARCHAR(500)')
				 ,MinChar=X.value('@MinChar','INT')
				 ,MaxChar=X.value('@MaxChar','INT')
            from @StaticXMLData.nodes('XML/Row') as Data(X)   
            where COSTCENTERID = @COSTCENTERID
            AND CostCenterColID = X.value('@CostCeneterColID','int')
            AND SECTIONID = 1
            
            
            UPDATE ADM_COSTCENTERDEF
            SET  LINKDATA =  X.value('@LinkData','int')
            ,Decimal=X.value('@Decimals','int')
             ,localreference=CASE WHEN  X.value('@LinkData','int') IS NOT NULL and X.value('@LinkData','int') in (250,251) and @DocumentType in(1,6,25,31,34,26,27,2,3,4)
			  THEN (select CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SYSCOLUMNNAME='CreditAccount')
			 WHEN  X.value('@LinkData','int') IS NOT NULL and X.value('@LinkData','int') in (250,251) and @DocumentType not in(1,6,25,31,34,26,27,2,3,4)
			  THEN (select CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID and SYSCOLUMNNAME='DebitAccount')
              WHEN  X.value('@LinkData','int') IS NOT NULL then  (SELECT CostCenterColID FROM ADM_CostCenterDef
			 WHERE CostCenterID=@COSTCENTERID AND SYSCOLUMNnAME LIKE 'dcCCNID%' AND ColumnCostCenterID=(
			 SELECT COSTCENTERID FROM ADM_CostCenterDef
			 WHERE CostCenterColID= X.value('@LinkData','int'))) elSE null end
            from @StaticXMLData.nodes('XML/Row') as Data(X)   
            where COSTCENTERID = @COSTCENTERID
            AND CostCenterColID = X.value('@CostCeneterColID','int')
            AND  X.value('@DBCR','int')=1
            
            UPDATE ADM_COSTCENTERDEF
            SET userdefaultvalue=    X.value('@DefaultValue','nvarchar(max)')
            from @StaticXMLData.nodes('XML/Row') as Data(X)   
            where COSTCENTERID = @COSTCENTERID
            AND CostCenterColID = X.value('@CostCeneterColID','int')
            and (columndatatype='date' or syscolumnname='Quantity')
            
            
            UPDATE ADM_COSTCENTERDEF
            SET  IsVisible = isnull(X.value('@Visible','BIT'),1),
                IsEditable = X.value('@Editable','BIT'),
                IsMandatory = X.value('@Mandatory','BIT'),
                Columnspan= X.value('@ColumnSpan','INT'),IsnoTab=isnull(X.value('@noTab','bit'),1)
                ,IsRepeat= X.value('@IsRepeat','BIT')
                ,fetchmaxrows=X.value('@GridViewID','int')
                ,ColumnCCListViewTypeID=isnull(X.value('@ListViewID','int'),0),Decimal=X.value('@Decimals','int')
                ,TextFormat= X.value('@TextFormat','INT')
            from @StaticXMLData.nodes('XML/Row') as Data(X)   
            where COSTCENTERID = @COSTCENTERID
            AND CostCenterColID = X.value('@CostCeneterColID','int')
            AND SECTIONID = 3
            
             Update COM_LANGUAGERESOURCES
              SET RESOURCEDATA = X.value('@Rename','NVARCHAR(500)')
            from @StaticXMLData.nodes('XML/Row') as Data(X)
            join ADM_COSTCENTERDEF c with(nolock) on  c.CostCenterColID = X.value('@CostCeneterColID','int')
             WHERE c.CostCenterID=@CostCenterID and COM_LANGUAGERESOURCES.ResourceID=c.ResourceID and COM_LANGUAGERESOURCES.LANGUAGEID=@LangID

             Update ADM_COSTCENTERDEF
              SET usercolumnname = X.value('@Rename','NVARCHAR(500)')
            from @StaticXMLData.nodes('XML/Row') as Data(X)
             WHERE CostCenterID=@CostCenterID and CostCenterColID = X.value('@CostCeneterColID','int')
        END       
  END
  
  
			DECLARE @TBL TABLE(ID INT identity(1,1) PRIMARY KEY, ColID int, SeqNum int,visible BIT,ColSpan int)       
            INSERT INTO @TBL      
            SELECT  CostCenterColID,SectionSeqNumber,IsVisible,isnull(ColumnSpan,1)
            from adm_costcenterdef WITH(NOLOCK)
            where costcenterid=@CostCenterID and SectionID=1 and syscolumnname not in('SKU','ExchangeRate')
            and SysColumnName NOT LIKE 'dcCalc%' AND SysColumnName NOT LIKE 'dcCurrID%' AND SysColumnName NOT LIKE 'dcExchRT%'
            order by SectionSeqNumber
            
             declare @r int, @c int,   @icnt int,@invCnt int  
             set @invCnt=3 
             
             if (@DocumentType=38 and not exists(select CostCenterIDBase from [COM_DocumentLinkDef] WITH(NOLOCK) where CostCenterIDBase=@CostCenterID))
				 set @invCnt=0
			
             if exists(select * from  COM_DocumentPreferences with(nolock)
             WHERE [PrefName]='LinkPopup' AND CostCenterID=@CostCenterID and [PrefValue]='true')
				set @invCnt=0
			
			 if exists(select [PrefValue] from  COM_DocumentPreferences with(nolock)
             WHERE [PrefName]='OptionalInventory' AND CostCenterID=@CostCenterID and [PrefValue]='true')
			 BEGIN
				if(@invCnt=0)
					set @invCnt=-1
				else	
			 		set @invCnt=4	 
			 END
				 
            set @r=0
            set @c=0
            set @ColSpan=1
            SET @Colid=0
            select @icnt=0,@cnt=count(*) from @TBL
            while @icnt<@cnt
            begin
                set @icnt=@icnt+1
                if exists(Select visible from @TBL where ID=@icnt and visible=0)
                begin
                    continue;
                end
                Select @Colid=Colid from @TBL where ID=@icnt
                if (@DocumentType=38 and (select SysColumnName from adm_costcenterdef with(nolock) where CostCenterID=@CostCenterID and CostCenterColID=@Colid)='SKU')
					continue;
					
                Select @ColSpan=ColSpan from @TBL where ID=@icnt
                
                if(@ColSpan is null or @ColSpan=0)
                    set @ColSpan=1
                    
                if(@IsInventory=1 and (@r>=0 and  @r<@invCnt) or (@invCnt=-1 and @r=3))
                begin
                    if(@c+@ColSpan>3)
                    begin
                        set @r=@r+1
                        set @c=0
                    end
                end
                else
                begin
                    if(@c+@ColSpan>4)
                    begin
                        set @r=@r+1
                        set @c=0
                    end
                end
                update adm_costcenterdef set RowNo=@r, ColumnNo=@c,ColumnSpan=@ColSpan,SectionName='Header'
                where CostCenterID=@CostCenterID and costcentercolid=@Colid
                 set @c=@c+@ColSpan
                 set @ColSpan=0
                
            end
 
  --SET ROW COLUMN FOR  EXTRA FIELDS AT HEADER SECTION
  DECLARE @TABS TABLE(ID INT IDENTITY(1,1),TABNAME NVARCHAR(300))
  DECLARE  @TABNAME NVARCHAR(300)
  INSERT INTO @TABS
  SELECT sectionName FROM @tblList WHERE SECTIONID=2  GROUP BY sectionName  
  CREATE TABLE #TBLDATA(ID INT identity(1,1) PRIMARY KEY, ColID int, SeqNum int,visible BIT,ColSpan int)  
   SELECT @I=1, @COUNT=count(*) FROM @TABS
   WHILE @I<=@COUNT
   BEGIN
    select @TABNAME=TABNAME from @TABS where id=@I
            truncate table #TBLDATA      
            INSERT INTO #TBLDATA      
            SELECT costcentercolid,SectionSeqNumber,IsVisible,ColumnSpan FROM @tblList
            WHERE SECTIONID=2 AND SectionName=@TABNAME ORDER BY SectionSeqNumber
            
            select @r=0, @c=0, @ColSpan=1, @Colid=0,@icnt=0,@cnt=count(*) from #TBLDATA 
            
            while @icnt<@cnt
            begin
                set @icnt=@icnt+1
                if exists(Select visible from #TBLDATA where ID=@icnt and visible=0)
                begin
                    continue;
                end

                set @ColSpan=(Select ColSpan from #TBLDATA where ID=@icnt)
                set @Colid=(Select Colid from #TBLDATA where ID=@icnt)
                
                if(@ColSpan is null or @ColSpan=0)
                    set @ColSpan=1
                    
                 begin
                    if(@c+@ColSpan>4)
                    begin
                        set @r=@r+1
                        set @c=0
                    end
                end
                            
                update adm_costcenterdef set RowNo=@r, ColumnNo=@c
                where CostCenterID=@CostCenterID and costcentercolid=@Colid
                 set @c=@c+@ColSpan
                 set @ColSpan=0
                
            end
            
    set @I=@I+1
   END
 
    --Assigning Budgets
    DELETE FROM ADM_DocumentBudgets WHERE CostCenterID=@CostCenterID  
    IF @BudgetsXML<>'' AND @BudgetsXML IS NOT NULL
    BEGIN
        SET @XML=@BudgetsXML
        declare @From float,@To float,@BudID INT,@NewBudID INT,@BudIDs nvarchar(max),@NewBudIDs nvarchar(max)
        declare @TblBuds as table(ID int identity(1,1) PRIMARY KEY,FromDate float,ToDate float,BudID INT)
		insert into @TblBuds
        SELECT  CONVERT(FLOAT,X.value('@FromDate','DATETIME')) FromDate,CONVERT(FLOAT,X.value('@ToDate','DATETIME')),X.value('@BudgetID','int')
        FROM @XML.nodes('/Budgets/Row') as DATA(X)
        order by FromDate
        select @I=1, @COUNT=count(*) from @TblBuds
	    while @I<@COUNT
	    begin
			select @J=@I+1,@From=FromDate,@To=ToDate,@BudID=BudID from @TblBuds where ID=@I
			set @BudIDs=''
			select @BudIDs=@BudIDs+','+convert(nvarchar,C.CostCenterID) from COM_BudgetDefDims C WITH(NOLOCK) WHERE C.BudgetDefID=@BudID order by CostCenterID
			while @J<=@COUNT
			begin
				set @NewBudID=null
				select @NewBudID=BudID from @TblBuds where ID=@J and ((FromDate between @From and @To) or (@From between FromDate and ToDate))
				if @NewBudID is not null
				begin
					set @NewBudIDs=''
					select @NewBudIDs=@NewBudIDs+','+convert(nvarchar,C.CostCenterID) from COM_BudgetDefDims C WITH(NOLOCK) WHERE C.BudgetDefID=@NewBudID order by CostCenterID
					if @NewBudIDs!=@BudIDs
					begin
						select @NewBudIDs='-153'+BudgetName from COM_BudgetDef with(nolock) where BudgetDefID=@NewBudID
						RAISERROR(@NewBudIDs,16,1,1000)
					end
				end
				set @J=@J+1
			end
			set @I=@I+1
		end
		
        
        INSERT INTO ADM_DocumentBudgets(CostCenterID,FromDate,ToDate,BudgetID,CompanyGUID,CreatedBy,CreatedDate)
        SELECT @CostCenterID,CONVERT(FLOAT,X.value('@FromDate','DATETIME')) FromDate,CONVERT(FLOAT,X.value('@ToDate','DATETIME')),
            X.value('@BudgetID','int'),@CompanyGUID,@UserName,CONVERT(FLOAT,getdate())
        FROM @XML.nodes('/Budgets/Row') as DATA(X)
        order by FromDate
        
       -- select * from ADM_DocumentBudgets with(nolock) where CostCenterID=@CostCenterID
    END
    --Locked Date between
    IF @LockedDatesXml<>'' AND @LockedDatesXml IS NOT NULL    
	BEGIN    
		DELETE FROM ADM_LockedDates WHERE CostCenterID=@CostCenterID
		SET @XML=@LockedDatesXml    
		   
		INSERT INTO ADM_LockedDates (FromDate,ToDate,isEnable,CostCenterID)    
		SELECT  CONVERT(FLOAT,X.value('@FromDate','DATETIME')),    
		 CONVERT(FLOAT,X.value('@ToDate','DATETIME')),    
		X.value('@isEnable','BIT'),@CostCenterID
		FROM @XML.nodes('/LockedDates/Row') as DATA(X)    
	END
	
    if(@DocumentType=35)
    BEGIN
		update ADM_CostCenterDef              
		set UserColumnType='Date'
		where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME in('dcAlpha4','dcalpha3')
	END
	 	
	if exists(select [PrefValue] from  COM_DocumentPreferences with(nolock) WHERE [PrefName] in('UseAsLC','UseAsTR') AND CostCenterID=@CostCenterID
	and [PrefValue]='true') 
	BEGIN
		update ADM_CostCenterDef              
		set IsColumnInUse=1,IsColumnUserDefined=0
		,SectionID=1,SectionSeqNumber=10,IsVisible=1
		,RowNo=2,ColumnNo=1
		where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='dcalpha1'
		
		Update COM_LANGUAGERESOURCES
		SET RESOURCEDATA ='LIMIT'
		WHERE [LanguageID]=@LangID AND  ResourceID =(Select ResourceID from ADM_COSTCENTERDEF with(nolock)
		where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='dcalpha1')

		update ADM_CostCenterDef              
		set IsColumnInUse=1,IsColumnUserDefined=0
		,SectionID=1,SectionSeqNumber=11,IsVisible=1
		,RowNo=2,ColumnNo=2		
		where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='dcalpha2'
		
		Update COM_LANGUAGERESOURCES
		SET RESOURCEDATA ='Consumed'
		WHERE [LanguageID]=@LangID AND  ResourceID =(Select ResourceID from ADM_COSTCENTERDEF with(nolock)
		where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='dcalpha2')

		update ADM_CostCenterDef              
		set IsColumnInUse=1,IsColumnUserDefined=0
		,SectionID=1,SectionSeqNumber=12,IsVisible=1
		,RowNo=2,ColumnNo=3
		where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='dcalpha3'
		
  		Update COM_LANGUAGERESOURCES
		SET RESOURCEDATA ='Available'
		WHERE [LanguageID]=@LangID AND ResourceID =(Select ResourceID from ADM_COSTCENTERDEF with(nolock)
		where CostCenterID=@CostCenterID   AND SYSCOLUMNNAME ='dcalpha3')
		
		update ADM_CostCenterDef              
		set IsMandatory=1
		where CostCenterID=@CostCenterID AND SYSCOLUMNNAME ='DueDate'
  END
    
	select  @CostCenterColID=CostCenterColID from ADM_CostCenterDef with(nolock)             
    where CostCenterID=@CostCenterID  and syscolumnname ='DueDate'
    if(@DueDateFormula!='')
    BEGIN
		IF EXISTS(SELECT CostCenterColID FROM ADM_DocumentDef with(nolock) WHERE CostCenterColID=@CostCenterColID)               
		BEGIN 
		  UPDATE ADM_DocumentDef set                 
		  [Formula] = @DueDateFormula   
		  WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID              
		END              
		ELSE if(@CostCenterColID is not null)              
		BEGIN  
			  INSERT INTO [ADM_DocumentDef]              
			  ([DocumentTypeID]              
			  ,[CostCenterID]             
			  ,[CostCenterColID]              
			  ,[DebitAccount]              
			  ,[CreditAccount]              
			  ,[Formula]              
			  ,[PostingType]              
			  ,[RoundOff]              
			  ,[RoundOffLineWise]              
			  ,[IsRoundOffEnabled]              
			  ,[IsDrAccountDisplayed]           
			  ,[IsCrAccountDisplayed]              
			  ,[IsDistributionEnabled]              
			  ,[DistributionColID]              
			  ,[IsCalculate]              
			  ,[CompanyGUID]              
			  ,[GUID]              
			  ,[CreatedBy]              
			  ,[CreatedDate]
				,CrRefID
				,CrRefColID
				,DrRefID
				,DrRefColID,showbodytotal)              
		      VALUES              
			  (@DocumentTypeID              
			  ,@CostCenterID              
			  ,@CostCenterColID              
			  ,0              
			  ,0              
			  ,@DueDateFormula              
			  ,0              
			  ,0              
			  ,0              
			  ,0              
			  ,0              
			  ,0              
			  ,0       
			  ,0              
			  ,0              
			  ,@CompanyGUID              
			  ,newid()               
			  ,@UserName              
			  ,convert(float,getdate())
			  ,0              
			  ,0    
			  ,0           
			  ,0 ,0    )
			END     
	END
	ELSE if (@IsInventory=1)
	BEGIN
		IF EXISTS(SELECT CostCenterColID FROM ADM_DocumentDef with(nolock) WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID)               
		BEGIN 
			UPDATE ADM_DocumentDef set                 
			[Formula] = ''
			WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID  
		END
	END
	
	
	select  @CostCenterColID=CostCenterColID from ADM_CostCenterDef  with(nolock)            
    where CostCenterID=@CostCenterID  and syscolumnname ='VoucherNo'
    if(@NetFormula!='')
    BEGIN
		IF EXISTS(SELECT CostCenterColID FROM ADM_DocumentDef with(nolock) WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID)               
		BEGIN 
		  UPDATE ADM_DocumentDef set                 
		  [Formula] = @NetFormula   
		  WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID              
		END              
		ELSE if(@CostCenterColID is not null)              
		BEGIN  
			  INSERT INTO [ADM_DocumentDef]              
			  ([DocumentTypeID]              
			  ,[CostCenterID]             
			  ,[CostCenterColID]              
			  ,[DebitAccount]              
			  ,[CreditAccount]              
			  ,[Formula]              
			  ,[PostingType]              
			  ,[RoundOff]              
			  ,[RoundOffLineWise]              
			  ,[IsRoundOffEnabled]              
			  ,[IsDrAccountDisplayed]           
			  ,[IsCrAccountDisplayed]              
			  ,[IsDistributionEnabled]              
			  ,[DistributionColID]              
			  ,[IsCalculate]              
			  ,[CompanyGUID]              
			  ,[GUID]              
			  ,[CreatedBy]              
			  ,[CreatedDate]
				,CrRefID
				,CrRefColID
				,DrRefID
				,DrRefColID,showbodytotal)              
		      VALUES              
			  (@DocumentTypeID              
			  ,@CostCenterID              
			  ,@CostCenterColID              
			  ,0              
			  ,0              
			  ,@NetFormula              
			  ,0              
			  ,0              
			  ,0              
			  ,0              
			  ,0              
			  ,0              
			  ,0       
			  ,0              
			  ,0              
			  ,@CompanyGUID              
			  ,newid()               
			  ,@UserName              
			  ,convert(float,getdate())
			  ,0              
			  ,0    
			  ,0           
			  ,0 ,0    )
			END  
	END
	ELSE if (@IsInventory=1)
	BEGIN
		IF EXISTS(SELECT CostCenterColID FROM ADM_DocumentDef with(nolock) WHERE CostCenterColID=@CostCenterColID)               
		BEGIN 
			UPDATE ADM_DocumentDef set                 
			[Formula] = ''
			WHERE CostCenterID=@CostCenterID and CostCenterColID=@CostCenterColID  
		END
	END
	
   
   delete from ADM_DocFunctions where CostCenterID=@CostCenterID
   if(@ExtrnFuncXML<>'')
   BEGIN
		  SET @XML=@ExtrnFuncXML        
    
		insert into ADM_DocFunctions(CostCenterID,CostCenterColID,Mode,Shortcut,SpName,IpParams,OpParams,Expression)
		SELECT  @CostCenterID,X.value('@CostCenterColID','int'),X.value('@Mode','INT') ,X.value('@Shortcut','NVARCHAR(MAX)')
            ,X.value('@SpName','NVARCHAR(MAX)'),X.value('@IpParams','NVARCHAR(MAX)'),X.value('@OpParams','NVARCHAR(MAX)'),X.value('@Expression','NVARCHAR(MAX)')
        FROM @XML.nodes('/XML/Row') as DATA(X)
   
   END 
	
	update ADM_CostCenterDef              
	set ModifiedBy=@UserName,ModifiedDate=@DT
	where CostCenterID=@CostCenterID
	
	update ADM_DocumentDef              
	set ModifiedBy=@UserName,ModifiedDate=@DT
	where CostCenterID=@CostCenterID
	
	if(@AllowDDHistory=1)
	begin
		insert into ADM_CostCenterDef_History
		select * from ADM_CostCenterDef with(nolock) where CostCenterID=@CostCenterID
		
		insert into COM_DocumentPreferences_History
		select * from COM_DocumentPreferences with(nolock) where CostCenterID=@CostCenterID
		
		insert into ADM_DocumentDef_History
		select * from ADM_DocumentDef with(nolock) where CostCenterID=@CostCenterID
	end
	
COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
WHERE ErrorNumber=100 AND LanguageID=@LangID              
SET NOCOUNT OFF;                
RETURN @CostCenterID                
END TRY                
BEGIN CATCH                
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000              
 BEGIN
     if(isnumeric(ERROR_MESSAGE())=0)
		SELECT ERROR_MESSAGE() ErrorMessage    
	 else if(ERROR_MESSAGE() like '-153%')
     begin    
		SELECT ErrorMessage+'"'+substring(ERROR_MESSAGE(),5,len(ERROR_MESSAGE()))+'"' ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
		WHERE ErrorNumber=-153 AND LanguageID=@LangID              	
	 end    
	else
	begin
		SELECT * FROM ADM_CostCenterDef WITH(nolock) WHERE CostCenterID=@CostCenterID              
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)               
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID              
	end
 END              
 ELSE IF ERROR_NUMBER()=547              
 BEGIN              
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)              
  WHERE ErrorNumber=-110 AND LanguageID=@LangID              
 END              
 ELSE IF ERROR_NUMBER()=2627              
 BEGIN              
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)              
  WHERE ErrorNumber=-116 AND LanguageID=@LangID              
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
