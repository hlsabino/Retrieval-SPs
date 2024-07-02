USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportData]
	@XML [nvarchar](max),
	@CCMapXML [nvarchar](max) = '',
	@HistoryXML [nvarchar](max) = null,
	@COSTCENTERID [int],
	@IsDuplicateNameAllowed [bit],
	@IsCodeAutoGen [bit],
	@IsOnlyName [bit],
	@IsProductVehicle [bit] = NULL,
	@IsUpdate [bit] = 0,
	@IsCode [bit] = NULL,
	@Attachment [nvarchar](max) = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON   
 
	--Declaration Section  
	declare @ERROR_MESSAGE nvarchar(max),@HistoryStatus NVARCHAR(10)
	DECLARE @return_value int,@failCount int  , @IsMove bit
	DECLARE @NodeID INT, @Table NVARCHAR(50),@SQL NVARCHAR(max),@ParentGroupName NVARCHAR(200),@PK NVARCHAR(50)  
	DECLARE @AccountCode nvarchar(max),@CodePrefix nvarchar(100),@CodeNumber INT,@GUID nvarchar(max),@AccountName nvarchar(max),@AliasName nvarchar(max)  
	DECLARE @StatusID int,@ExtraFields NVARCHAR(max),@ExtraUserDefinedFields NVARCHAR(max),@CostCenterFields NVARCHAR(max),@CCWEFFields NVARCHAR(max),@PrimaryContactQuery nvarchar(max)  
	DECLARE @LinkFields NVARCHAR(MAX), @LinkOption NVARCHAR(MAX),@ProductImage NVARCHAR(MAX),@Customerdata NVARCHAR(MAX)
	DECLARE @SelectedNode INT, @IsGroup bit , @Substitutes NVARCHAR(MAX),@ProductWiseUOM NVARCHAR(MAX)   
	DECLARE @CreditDays int, @CreditLimit float , @ProductImageXML XML , @AttachmentXML xml 
	DECLARE @PurchaseAccount INT,@Purchase nvarchar(max)  
	DECLARE @SalesAccount INT,@Sales nvarchar(max)  
	DECLARE @DebitDays int, @DebitLimit float  
	DECLARE @IsBillwise bit, @TypeID int, @ValuationID int,@Dt float,@IsAutoBarcode BIT
	DECLARE @Make nvarchar(400),@Model nvarchar(400),@Year nvarchar(400),@Variant nvarchar(400),@Segment nvarchar(400)
	DECLARE @tempCode NVARCHAR(max),@DUPLICATECODE NVARCHAR(300),@DUPNODENO INT,@PARENTCODE NVARCHAR(max)  
	DECLARE @tempName NVARCHAR(max),@DUPLICATEName NVARCHAR(max), @DUPNODENOCODE INT  
	DECLARE @TempGuid NVARCHAR(max),@HasAccess BIT,@DATA XML,@Cnt INT,@I INT, @CCID INT, @SubstitutesXML XML,@CustomersXML XML
	DECLARE @PrefValue NVARCHAR(500),@Dimesion INT,@CCStatID INT,@LinkDim_NodeID int,@RefSelectedNodeID int,@SelectedNodeID int,@SelectedNodeName nvarchar(200)
	
	SET @DATA=@XML  
	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date    
	set  @ERROR_MESSAGE=''
	--SP Required Parameters Check  
	IF @CompanyGUID IS NULL OR @CompanyGUID=''  
	BEGIN  
		RAISERROR('-100',16,1)  
	END  
  
  SELECT @Table=TableName FROM ADM_features WITH(NOLOCK) WHERE FeatureID=@COSTCENTERID  
  IF(@COSTCENTERID=2)  
	SET @PK='AccountID'  
  ELSE IF(@COSTCENTERID=3)
  BEGIN
	SET @PK='ProductID'  
	if (SELECT Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=3 and  Name='AutoBarcode')='TRUE'
		set @IsAutoBarcode=1
	else
		set @IsAutoBarcode=0
  END
  ELSE IF(@COSTCENTERID=12)  
	SET @PK='CurrencyID'   
  ELSE IF(@COSTCENTERID=71)  
	SET @PK='ResourceID'  
  ELSE IF(@COSTCENTERID=83)  
	SET @PK='CustomerID'  
  ELSE IF(@COSTCENTERID=65)  
	SET @PK='ContactID'  
  ELSE  
	SET @PK='NodeID'  
   
   
  -- Create Temp Table  
  DECLARE  @temptbl TABLE(ID int identity(1,1),[AccountCode] nvarchar(500),CodePrefix nvarchar(100),CodeNumber INT  
     ,[AccountName] nvarchar(max),[AliasName] nvarchar(max),[StatusID] int,SelectedNode INT,ParentGroupName NVARCHAR(200)  
     ,[IsGroup] bit,[CreditDays] int,[CreditLimit] float,[PurchaseAccount] nvarchar(500),[SalesAccount] nvarchar(500),[DebitDays] int,[DebitLimit] float  
     ,IsBillwise bit,TypeID int,ValuationID   int,ExtraFields nvarchar(max),ExtraUserDefinedFields nvarchar(max),CostCenterFields nvarchar(max),CCWEFFields nvarchar(max)
     ,PrimaryContactQuery nvarchar(max), LinkFields nvarchar(max), LinkOption nvarchar(max), Substitutes NVARCHAR(MAX),Customerdata nvarchar(max), ProductImage NVARCHAR(MAX)      
     ,ProductWiseUOM nvarchar(Max), IsMove bit)  
  
  
  INSERT INTO @temptbl([AccountCode]
			,CodePrefix
			,CodeNumber  
			,[AccountName]  
			,[AliasName]  
			,[StatusID]  
			,SelectedNode  
			,ParentGroupName  
			,[IsGroup]  
			,[CreditDays]  
			,[CreditLimit]  
			,[PurchaseAccount]  
			,[SalesAccount]  
			,[DebitDays]  
			,[DebitLimit]  
			,IsBillwise  
			,TypeID  
			,ValuationID,ExtraFields ,ExtraUserDefinedFields ,CostCenterFields,CCWEFFields,
			PrimaryContactQuery,LinkFields, LinkOption, Substitutes,  
			ProductImage,Customerdata,ProductWiseUOM, IsMove )            
  SELECT  
   X.value('@AccountCode','nvarchar(500)'),X.value('@CodePrefix','nvarchar(100)'),X.value('@CodeNumber','INT')  
           ,X.value('@AccountName','nvarchar(max)')  
           ,isnull(X.value('@AliasName','nvarchar(max)'),'')  
           ,X.value('@StatusID','int')                   
           --,isnull(X.value('@SelectedNode','INT'),0) 
           ,CASE WHEN (@COSTCENTERID=2 AND X.value('@SelectedNode','INT')=1) THEN (SELECT AccountID FROM ACC_Accounts WITH(NOLOCK) WHERE (AccountCode=X.value('@GroupName','nvarchar(200)')
           OR AccountName=X.value('@GroupName','nvarchar(200)'))) ELSE isnull(X.value('@SelectedNode','INT'),0) END            
           ,isnull(X.value('@GroupName','nvarchar(200)'),'')  
           ,isnull(X.value('@IsGroup','bit'),0)  
           ,isnull(X.value('@CreditDays','int'),0)  
           ,isnull(X.value('@CreditLimit','float'),0)  
           ,X.value('@PurchaseAccount','nvarchar(max)')  
           ,X.value('@SalesAccount','nvarchar(max)')  
           ,isnull(X.value('@DebitDays','int'),0)  
           ,isnull(X.value('@DebitLimit','float'),0)  
   ,case when (X.value('@IsBillwise','bit') is null and @COSTCENTERID=2 and @IsUpdate=0) then 
   isnull(X.value('@IsBillwise','bit'),0) else X.value('@IsBillwise','bit') end 
   ,case when (X.value('@TypeID','int') is null and @COSTCENTERID=2 and @IsUpdate=0) then (7)  
	when (@IsUpdate=0)  then isnull(X.value('@TypeID','int'),1) else X.value('@TypeID','int') end
   ,isnull(X.value('@ValuationID','int'),0)  
   ,isnull(X.value('@ExtraFields ','nvarchar(max)'),'')  
   ,isnull(X.value('@ExtraUserDefinedFields ','nvarchar(max)'),'')  
   ,isnull(X.value('@CostCenterFields','nvarchar(max)'),'')
     ,isnull(X.value('@CCWEFFields','nvarchar(max)'),'')
   ,isnull(X.value('@PrimaryContactQuery','nvarchar(max)'),'')  
   ,isnull(X.value('@LinkFields','nvarchar(max)'),'')  
   ,isnull(X.value('@LinkOption','nvarchar(max)'),'')  
   ,isnull(X.value('@Substitutes','nvarchar(max)'),'') ,isnull(X.value('@ProductImage','nvarchar(max)'),'')  
   ,isnull(X.value('@CustomerName','nvarchar(max)'),'') 
   ,X.value('@ProductWiseUOM','nvarchar(MAX)'),isnull(X.value('@Move','bit'),0)  
   from @DATA.nodes('/XML/Row') as Data(X)  

   IF @COSTCENTERID=2 AND @IsUpdate=0
   BEGIN  
		DECLARE @TblControl AS TABLE(NodeID nvarchar(15))
		
		SET @SQL=''
		SELECT @SQL=Value FROM ADM_GlobalPreferences WITH(NOLOCK) 
		WHERE Name='DebtorsControlGroup' AND Value is not null AND Value<>''
	   
		INSERT INTO @TblControl(NodeID)
		EXEC SPSplitString @SQL,','
	   
		IF EXISTS (SELECT * FROM @TblControl)
		BEGIN
			SELECT TOP 1 @ParentGroupName=A.AccountName,@SelectedNode=T.NodeID FROM ACC_Accounts A WITH(NOLOCK) 
			JOIN @TblControl T ON T.NodeID=A.AccountID

			UPDATE @temptbl SET ParentGroupName=@ParentGroupName
			WHERE TypeID=7 AND (ParentGroupName is null or ParentGroupName='')
		END
		
		DELETE FROM @TblControl
		SET @SQL=''
		SELECT @SQL=Value FROM ADM_GlobalPreferences WITH(NOLOCK) 
		WHERE Name='CreditorsControlGroup' AND Value is not null AND Value<>''
	   
		INSERT INTO @TblControl(NodeID)
		EXEC SPSplitString @SQL,','
	   
		IF EXISTS (SELECT * FROM @TblControl)
		BEGIN
			SELECT TOP 1 @ParentGroupName=A.AccountName,@SelectedNode=T.NodeID FROM ACC_Accounts A WITH(NOLOCK) 
			JOIN @TblControl T ON T.NodeID=A.AccountID

			UPDATE @temptbl SET ParentGroupName=@ParentGroupName
			WHERE TypeID=6 AND (ParentGroupName is null or ParentGroupName='')
		END
   END
   
  SELECT @I=1, @Cnt=count(ID) FROM @temptbl   
  set @failCount=0  

	WHILE(@I<=@Cnt)    
	BEGIN  
		begin try  
	  
		select @AccountCode=AccountCode,@CodePrefix=ISNULL(CodePrefix,''),@CodeNumber=ISNULL(CodeNumber,0)  
	   ,@AccountName    =  AccountName    
	   ,@AliasName    = AliasName   
	   ,@StatusID    = StatusID   
	   ,@SelectedNode    =SelectedNode 
	   ,@ParentGroupName=ParentGroupName  
	   ,@IsGroup    = IsGroup   
	   ,@CreditDays    = CreditDays   
	   ,@CreditLimit    = CreditLimit   
	   ,@Purchase    = PurchaseAccount   
	   ,@Sales    = SalesAccount   
	   ,@DebitDays    = DebitDays   
	   ,@DebitLimit    = DebitLimit   
	   ,@IsBillwise    = IsBillwise   
	   ,@TypeID    = TypeID   
	   ,@ValuationID = ValuationID    
	   ,@ExtraFields=ExtraFields ,@ExtraUserDefinedFields=ExtraUserDefinedFields ,@CostCenterFields=CostCenterFields,@CCWEFFields=CCWEFFields  
	   ,@PrimaryContactQuery=PrimaryContactQuery   
	   ,@LinkFields=LinkFields   
	   ,@ProductWiseUOM=ProductWiseUOM
	   ,@LinkOption=LinkOption,  @IsMove=IsMove,
	   @Substitutes=Substitutes,@ProductImage=ProductImage,@Customerdata=Customerdata
	   from  @temptbl where ID=@I  
	   
		if(@IsOnlyName=1 or @StatusID is null)  
		begin  
			select @StatusID=StatusID from COM_Status with(nolock) where CostCenterID=@COSTCENTERID and Status='Active'  
		end  
		
		if(@StatusID is null or @StatusID='0' )  
			if @COSTCENTERID=83  
				select @StatusID=StatusID from COM_Status with(nolock) where CostCenterID=@COSTCENTERID and Status='Active'  
	     
		if(@Purchase is not null and @Purchase<>'')  
		begin  
			select @PurchaseAccount=AccountID from ACC_Accounts WITH(nolock) where AccountName=@Purchase  
		end  
		else  
		begin  
			set @PurchaseAccount=0  
		end  
	     
		if(@Sales is not null and @Sales<>'')  
		begin  
			select @SalesAccount=AccountID from ACC_Accounts WITH(nolock) where AccountName=@Sales  
		end  
		else  
		begin  
			set @SalesAccount=0  
		end  
	  
		SET @DUPLICATECODE=''  
		SET @tempCode=''  
		SET @DUPLICATEName=''  
		SET @tempName=''  
		SET @DUPNODENO=0  
		SET @DUPNODENOCODE=0  

		SET @tempCode=' @DUPNODENO INT OUTPUT'    

		SET @DUPLICATECODE=' select @DUPNODENO= '  
		   
		if(@COSTCENTERID=2)  
			SET @DUPLICATECODE=@DUPLICATECODE+'AccountID'  
		else if(@COSTCENTERID=3)  
			SET @DUPLICATECODE=@DUPLICATECODE+'ProductID'  
		else if(@COSTCENTERID=12)  
			SET @DUPLICATECODE=@DUPLICATECODE+'CurrencyID'  
		else if(@COSTCENTERID=51 or @COSTCENTERID=83)  
			SET @DUPLICATECODE=@DUPLICATECODE+'CustomerID'  
		else if( @COSTCENTERID=65)  
			SET @DUPLICATECODE=@DUPLICATECODE+'ContactID'   
		else if(@COSTCENTERID=71)  
			SET @DUPLICATECODE=@DUPLICATECODE+'ResourceID'  
		else  
			SET @DUPLICATECODE=@DUPLICATECODE+'NodeID'  
	        
		IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
		BEGIN     
			SET @tempName=' @DUPNODENO INT OUTPUT'    

			SET @DUPLICATEName =@DUPLICATECODE  

			SET @DUPLICATEName=@DUPLICATEName+'  from '+@Table+' WHERE '  
			if(@COSTCENTERID=2)  
				SET @DUPLICATEName=@DUPLICATEName+'AccountName'  
			else if(@COSTCENTERID=3)  
				SET @DUPLICATEName=@DUPLICATEName+'ProductName'  
			else if(@COSTCENTERID=71)  
				SET @DUPLICATEName=@DUPLICATEName+'ResourceName'  
			else if(@COSTCENTERID=51 or @COSTCENTERID=83)  
				SET @DUPLICATEName=@DUPLICATEName+'CustomerName'  
			else if(@COSTCENTERID=65)  
				SET @DUPLICATEName=@DUPLICATEName+'Company'  
			else  
				SET @DUPLICATEName=@DUPLICATEName+'NAME'  

			SET @DUPLICATEName=@DUPLICATEName+' ='''+REPLACE(@AccountName,'''','''''')+''' '        
		END   
	    
		SET @DUPLICATECODE=@DUPLICATECODE+'  from '+@Table+' WHERE '  
		if(@COSTCENTERID=2)  
			SET @DUPLICATECODE=@DUPLICATECODE+'AccountCode'  
		else if(@COSTCENTERID=3)  
			SET @DUPLICATECODE=@DUPLICATECODE+'ProductCode'  
		else if(@COSTCENTERID=51 or @COSTCENTERID=83)  
			SET @DUPLICATECODE=@DUPLICATECODE+'CustomerCode'  
		else if(@COSTCENTERID=65)  
			SET @DUPLICATECODE=@DUPLICATECODE+'Company'  
		else if(@COSTCENTERID=71)  
			SET @DUPLICATECODE=@DUPLICATECODE+'ResourceCode'  
		else  
			SET @DUPLICATECODE=@DUPLICATECODE+'Code'  

		SET @DUPLICATECODE=@DUPLICATECODE+' ='''+REPLACE(@AccountCode,'''','''''')+''' '   
	  --Duplicate code check  
		if @COSTCENTERID=3  
		BEGIN     
			declare @ProductCodeIgnoreText nvarchar(50),@IgnoreSpaces BIT,@IsDuplicateCodeAllowed BIT  
			select @ProductCodeIgnoreText=convert(nvarchar(100),isnull(Value,'')) from COM_CostCenterPreferences WITH(nolock) where CostCenterID=3 and Name='CodeIgnoreSpecialCharacters'  
			SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=3 and  Name='DuplicateCodeAllowed'    
			SELECT @IgnoreSpaces=convert(bit,Value)  FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=3 and  Name='CodeIgnoreSpaces'    
			IF(@IgnoreSpaces=1)  
				set @AccountCode=REPLACE(@AccountCode ,' ','')   
	     
			IF @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0  
			BEGIN   
				declare  @len INT,@CodeSQL NVARCHAR(MAX)  
				set @CodeSQL='ProductCode'  
				set @len=len(@ProductCodeIgnoreText)   
				if(@len>0)  
				begin  
					declare @tempCode1 nvarchar(100), @i1 int   
					set @tempCode1=@AccountCode   
					set @i1=1  
					while @i1<=@len  
					begin  
						declare @n char  
						set @n=@ProductCodeIgnoreText  
						set @ProductCodeIgnoreText=replace(@ProductCodeIgnoreText,@n,'')  
						set @tempCode1=replace(@tempCode1,@n,'')  
						set @CodeSQL='replace('+@CodeSQL+','''+@n+''','''')'  
						set @i1=@i1+1  
					end    
					declare @str1 nvarchar(max) , @count1 int  
					set @str1='@count1 int output'  
					if @IsUpdate=0  
						set @CodeSQL='set @count1=(select count('+@CodeSQL+') from INV_Product WITH(nolock) where '+@CodeSQL+' = '''+@tempCode1+''')'  
					else  
					BEGIN  
						if(@IsCode is not null and @IsCode=1)  
							set @NodeID=(select top 1 ProductID from INV_Product with(nolock) where ProductCode=@AccountCode)     
						else  
							set @NodeID=(select top 1 ProductID from INV_Product with(nolock) where ProductName=@AccountName)     
						set @CodeSQL='set @count1=(select count('+@CodeSQL+') from INV_Product WITH(nolock) where '+@CodeSQL+' = '''+@tempCode1+''' and Productid<>'+convert(nvarchar,@NodeID)+')'  
					END  
					PRINT (@CodeSQL)  
					exec sp_executesql @CodeSQL, @str1, @count1 OUTPUT    
					SELECT (@count1)  
					IF (@count1>0)  
					begin     
						RAISERROR('-112',16,1)  
					end  
				END  
				else  
				begin  
					IF @IsUpdate=0  
					BEGIN   
						IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE [ProductCode]=@AccountCode)  
							RAISERROR('-112',16,1)  
					END  
					ELSE  
					BEGIN  
						if(@IsCode is not null and @IsCode=1)  
							set @NodeID=(select top 1 ProductID from INV_Product with(nolock) where ProductCode=@AccountCode)     
						else  
							set @NodeID=(select top 1 ProductID from INV_Product with(nolock) where ProductName=@AccountName)   
						IF EXISTS (SELECT ProductID FROM INV_Product WITH(NOLOCK) WHERE [ProductCode]=@AccountCode AND ProductID <> @NodeID)  
							RAISERROR('-112',16,1)  
					END     
				end  
			END  
		END  
	     
		IF  @COSTCENTERID<>65    
		begin   
			if(@COSTCENTERID<>3)  
				EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENOCODE OUTPUT  
				
			EXEC sp_executesql @DUPLICATEName, @tempName,@DUPNODENO OUTPUT  
		end  
	     
	    IF @IsUpdate=0
	    BEGIN
			IF (@IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0 and @DUPNODENO >0)     
				RAISERROR('-112',16,1)  
			
			IF (@DUPNODENOCODE>0 AND (@IsCodeAutoGen IS NULL OR @IsCodeAutoGen=0)) 
				RAISERROR('-116',16,1)  
		END
		
		if(@COSTCENTERID=12)  
		begin  
			INSERT INTO [COM_Currency]([Name],[Symbol],[Change],[ExchangeRate],[Decimals],[IsBaseCurrency],[GUID],[CreatedBy],[CreatedDate],[IsDailyRates],[StatusID], CompanyGUID)  
			VALUES(@AccountName,'','',1,2,0,newid(),@UserName,@Dt,0,1,@CompanyGUID)  

			--To get inserted record primary key  
			SET @NodeID=SCOPE_IDENTITY()--Getting the NodeID    
		end  
	     	  
		--GENERATE CODE     
		IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1  
		BEGIN  

		if NOT (@COSTCENTERID=2 or @COSTCENTERID=3 OR @COSTCENTERID>50000)  
		begin   

			if(@SelectedNode is not null and @SelectedNode>0)  
		begin  
			SET @tempCode=' @PARENTCODE NVARCHAR(max) OUTPUT'   
			SET @DUPLICATECODE=' SELECT @PARENTCODE=[CODE] FROM '+@Table+' WITH(NOLOCK) WHERE '  
			if(@COSTCENTERID=2)  
				SET @DUPLICATECODE=@DUPLICATECODE+'AccountID'  
			else if(@COSTCENTERID=3)  
				SET @DUPLICATECODE=@DUPLICATECODE+'ProductID'  
			else if(@COSTCENTERID=51 or @COSTCENTERID=83)  
				SET @DUPLICATECODE=@DUPLICATECODE+'CustomerID'  
			else if(@COSTCENTERID=65)  
				SET @DUPLICATECODE=@DUPLICATECODE+'ContactID'   
			else if(@COSTCENTERID=71)  
				SET @DUPLICATECODE=@DUPLICATECODE+'ResourceID'  
			else  
				SET @DUPLICATECODE=@DUPLICATECODE+'NodeID'  

			SET @DUPLICATECODE=@DUPLICATECODE+'='+CONVERT(VARCHAR,@SelectedNode)+' '  
			EXEC sp_executesql @DUPLICATECODE, @tempCode,@PARENTCODE OUTPUT    
		end  
		else  
			set @ParentCode=''  
			if(@SelectedNode is null or @SelectedNode=0)
				set @SelectedNode=1

			DECLARE @temp1 table(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200),IsManualCode BIT)
			
			if(@SelectedNode is null and @SelectedNode=0)  
				insert into @temp1
				EXEC [spCOM_GetCodeData] @CostCenterId,1,''  
			else
				insert into @temp1
				EXEC [spCOM_GetCodeData] @CostCenterId,@SelectedNode,''  
				
			select @AccountCode=code,@CodePrefix= prefix, @CodeNumber=number from @temp1
		end  
	END  
 
		IF (@AccountCode IS NULL OR @AccountCode='')  and @IsUpdate=0
		BEGIN  
			SET @DUPLICATECODE=' SELECT @Code=MAX('  
			if(@COSTCENTERID=2)  
				SET @DUPLICATECODE=@DUPLICATECODE+'AccountID'  
			else if(@COSTCENTERID=3)  
				SET @DUPLICATECODE=@DUPLICATECODE+'ProductID'  
			else if(@COSTCENTERID=51 or @COSTCENTERID=83)  
				SET @DUPLICATECODE=@DUPLICATECODE+'CustomerID'  
			else if(@COSTCENTERID=65)  
				SET @DUPLICATECODE=@DUPLICATECODE+'ContactID'  
			else if(@COSTCENTERID=71)  
				SET @DUPLICATECODE=@DUPLICATECODE+'ResourceID'  
			else    
				SET @DUPLICATECODE=@DUPLICATECODE+'NodeID'  

			SET @DUPLICATECODE=@DUPLICATECODE+')+1 FROM '+@Table+' WITH(NOLOCK) '  
			EXEC sp_executesql @DUPLICATECODE, N'@Code NVARCHAR(max) OUTPUT', @AccountCode OUTPUT  
		END  
		  
		--To Set Left,Right And Depth of Record    
		SET @SQL='DECLARE @SelectedNodeID INT,@IsGroup BIT,@lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth INT,@ParentID INT, @SelectedIsGroup BIT'    
		SET @SQL=@SQL+' SELECT @IsGroup='+convert(NVARCHAR,@IsGroup)+', @SelectedNodeID='+convert(NVARCHAR,@SelectedNode)    
		SET @SQL=@SQL+' SELECT @SelectedNodeID='+@PK+', @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth from '+@Table+' with(NOLOCK) where '  
		if(@COSTCENTERID=2)  
			SET @SQL=@SQL+'AccountName'  
		else if(@COSTCENTERID=3)  
			SET @SQL=@SQL+'ProductName'  
		else if(@COSTCENTERID=71)  
			SET @SQL=@SQL+'ResourceName'  
		else if(@COSTCENTERID=51 or @COSTCENTERID=83)  
			SET @SQL=@SQL+'CustomerName'   
		else if(@COSTCENTERID=65)  
			SET @SQL=@SQL+'Company'      
		else  
			SET @SQL=@SQL+'Name'  
		  
		SET @SQL=@SQL+'=N'''+@ParentGroupName+''''  

		if(@COSTCENTERID BETWEEN 50001 AND 50075)
			SET @SQL=@SQL+' AND NodeID <>0 '  
		 
		--IF No Record Selected or Record Doesn't Exist    
		SET @SQL=@SQL+' IF(@SelectedIsGroup is null)     
		select @SelectedNodeID='+@PK  
		  
		SET @SQL=@SQL+',@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
		from '+@Table+' with(NOLOCK) where ParentID =0'    
		  
		if(@COSTCENTERID BETWEEN 50001 AND 50075)
			SET  @SQL=@SQL+' AND NodeID <>0 '  
			
		--Updating records left and right positions  
		SET @SQL=@SQL+'IF(@SelectedIsGroup = 1)--Adding Node Under the Group     
		BEGIN    
			UPDATE '+@Table+' SET rgt = rgt + 2 WHERE rgt >= @Selectedrgt;    
			UPDATE '+@Table+' SET lft = lft + 2 WHERE lft > @Selectedrgt;    
			SET @lft =  @Selectedrgt  
			SET @rgt = @Selectedrgt +1   
			SET @ParentID = @SelectedNodeID    
			SET @Depth = @Depth + 1    
		END    
		ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level    
		BEGIN    
			UPDATE '+@Table+' SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;    
			UPDATE '+@Table+' SET lft = lft + 2 WHERE lft > @Selectedrgt;    
			SET @lft =  @Selectedrgt + 1    
			SET @rgt = @Selectedrgt + 2     
		END    
		ELSE  --Adding Root    
		BEGIN    
			SET @lft =  1    
			SET @rgt = 2     
			SET @Depth = 0    
			SET @ParentID =0    
			SET @IsGroup=1    
		END'    
		
		if(@StatusID is null)  
			set @StatusID =1  
	
		if(@LinkFields is not null and @LinkFields<>'')  
		begin 
			if @IsCode is not null and @IsCode=0 and exists(select ProductID from INV_Product  with(nolock) where ProductName=@AccountName)  
			begin  
				set @NodeID=(select top 1 ProductID from INV_Product with(nolock) where ProductName=@AccountName)  
			end   
			else if @IsCode is not null and @IsCode=1 and exists(select ProductID from INV_Product with(nolock) where ProductCode=@AccountCode)  
			begin  
				set @NodeID=(select top 1 ProductID from INV_Product with(nolock) where ProductCode=@AccountCode)  
			end  
			 
			set @LinkFields ='<XML><Row '+ @LinkFields+' Qty=''0'' Rate=''0'' /></XML>'  

			if @LinkOption='One-One'  
				EXEC [spINV_SetProductBundle] @LinkFields,@NodeID,@CompanyGUID,@UserName,@UserID,@LangID   
			else if @LinkOption='Many-One'  
			BEGIN  
				DECLARE @TMP TABLE(ID INT IDENTITY(1,1), PRODUCTID INT)  
				INSERT INTO @TMP(PRODUCTID)  
				SELECT PRODUCTID FROM INV_Product with(nolock) where ProductName=@AccountName   
				DECLARE @A INT, @COUNT INT  
				SET @A=1  
				SELECT @COUNT = COUNT(*) FROM @TMP  
				WHILE @A<=@COUNT  
				BEGIN  
					SELECT @NodeID=PRODUCTID FROM @TMP WHERE ID=@A  
					EXEC [spINV_SetProductBundle] @LinkFields,@NodeID,@CompanyGUID,@UserName,@UserID,@LangID   
					SET @A=@A+1  
				END  
			END  
		end  
	
	  --select @IsUpdate,@DUPNODENO
		--Insert statements for procedure here   
		if @IsUpdate=0 and @DUPNODENO=0  
		begin 
		
			SET @SQL=@SQL+' INSERT INTO '+@Table+' (StatusID,'  
			if(@COSTCENTERID=2)  
				SET @SQL=@SQL+'AccountCode,AccountName,CodePrefix,CodeNumber,AccountTypeID,IsBillwise,CreditDays,CreditLimit,DebitDays, DebitLimit, PurchaseAccount,SalesAccount,AliasName'  
			else if(@COSTCENTERID=3)  
				SET @SQL=@SQL+'ProductCode,ProductName,CodePrefix,CodeNumber,ProductTypeID,ValuationID,AliasName,PurchaseAccountID,SalesAccountID,CreditDays'  
			else if(@COSTCENTERID=71)  
				SET @SQL=@SQL+'ResourceCode,ResourceName,ResourceTypeID'  
			else if(@COSTCENTERID=51)  
				SET @SQL=@SQL+'CustomerCode,CustomerName,CustomerTypeID, Firstname, AliasName'  
			else if(@COSTCENTERID=83)  
				SET @SQL=@SQL+'CustomerCode,CustomerName,CodePrefix,CodeNumber,CustomerTypeID '   
			else if(@COSTCENTERID=65)  
				SET @SQL=@SQL+' FirstName,Company,AddressTypeID,FeatureID,FeaturePK'   
			else  
				SET @SQL=@SQL+'[Code],[Name],CodePrefix,CodeNumber,CreditDays,CreditLimit,DebitDays, DebitLimit, PurchaseAccount,SalesAccount,AliasName'  
			SET @SQL=@SQL+',[Depth],[ParentID],[lft],[rgt],[IsGroup],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate])    
			VALUES('+convert(NVARCHAR,@StatusID)+',N'''+REPLACE(@AccountCode,'''','''''')+''',N'''+REPLACE(@AccountName,'''','''''')+''','  
			--SELECT @Table,@StatusID,@AccountName
			if(@COSTCENTERID=2)  
				SET @SQL=@SQL+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+convert(NVARCHAR,@TypeID)+','+convert(NVARCHAR,@IsBillwise)+',' +CONVERT(VARCHAR,@CreditDays)+','+CONVERT(VARCHAR,@CreditLimit)+','+CONVERT(VARCHAR,@DebitDays)+','+CONVERT(VARCHAR,@DebitLimit)+','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+',N'''+REPLACE(@AliasName,'''','''''')+''','  
			else if(@COSTCENTERID=3)
			BEGIN  
				SET @SQL=@SQL+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+convert(NVARCHAR,@TypeID)+','
				IF(@ValuationID=0)
					SET @SQL=@SQL+ '3'
				ELSE
					SET @SQL=@SQL+ convert(NVARCHAR,@ValuationID)
				SET @SQL=@SQL+',N'''+REPLACE(@AliasName,'''','''''')+''','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+',' +CONVERT(VARCHAR,@CreditDays)+','  
			END
			else if(@COSTCENTERID=71)  
				SET @SQL=@SQL+'1, '  
			else if(@COSTCENTERID=51)  
				SET @SQL=@SQL+'1, N'''+@AccountName+''',N'''+REPLACE(@AliasName,'''','''''')+''','  
			ELSE IF  @COSTCENTERID=83  
				SET @SQL=@SQL+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+'1,'  
			ELSE IF  @COSTCENTERID=65  
				SET @SQL=@SQL+'2,65,0,'  
			else  
				SET @SQL=@SQL+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+CONVERT(VARCHAR,@CreditDays)+','+CONVERT(VARCHAR,@CreditLimit)+','+CONVERT(VARCHAR,@DebitDays)+','+CONVERT(VARCHAR,@DebitLimit)+','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+',N'''+REPLACE(@AliasName,'''','''''')+''','  
			SET @SQL=@SQL+'@Depth,@ParentID,@lft,@rgt,@IsGroup,'''+@CompanyGUID+''',newid(),'''+@UserName+''','+convert(NVARCHAR(32),CAST(@DT AS DECIMAL(18,10)))+','''+@UserName+''','+convert(NVARCHAR(32),CAST(@DT AS DECIMAL(18,10)))+')    
			SET @NodeID=SCOPE_IDENTITY()'--To get inserted record primary key  
			
			EXEC sp_executesql @SQL, N'@NodeID INT OUTPUT', @NodeID OUTPUT   
		    
			set @HistoryStatus='Add'
			
			--To Insert Auto Barcode
			IF @COSTCENTERID=3 and @IsAutoBarcode=1
			BEGIN
				UPDATE INV_Product SET BarCodeID=dbo.fnGetBarCode() WHERE ProductID=@NodeID
			END 
		end  
		else IF  @IsUpdate=1  
		BEGIN 
			set @SQL=''   
			SET @SQL=@SQL+' UPDATE '+@Table+ ' SET ModifiedBy='''+@UserName+''',ModifiedDate='+convert(NVARCHAR(32),CAST(@DT AS DECIMAL(18,10)))+','   
	      
			if(@COSTCENTERID=2)  
			begin    
				if( @IsCode is not null and @IsCode =0)  
					set @NodeID= (Select  top 1  AccountID from ACC_Accounts with(nolock) where AccountName=@AccountName)   
				else  
					set @NodeID= (Select  top 1 AccountID from ACC_Accounts with(nolock) where AccountCode=@AccountCode)   
				  
				if(@AccountCode='' or @AccountCode is null)   
					set @AccountCode= (Select AccountCode from ACC_Accounts with(nolock) where AccountID=@NodeID) 
				
				SET @SQL=@SQL+' AccountCode= N'''+ISNULL(REPLACE(@AccountCode,'''',''''''),'')+''', AccountName=N'''+REPLACE(@AccountName,'''','''''')+''''
				if(@TypeID<>0)
					set @SQL=@SQL+',AccountTypeID = '+convert(NVARCHAR,@TypeID)+''
				if(@StatusID<>0)
					set @SQL=@SQL+',StatusID='+ISNULL(CONVERT(VARCHAR,@StatusID),0)+''	
				if(@IsBillwise is not null) 
					set @SQL=@SQL+',IsBillwise ='+convert(NVARCHAR,@IsBillwise)+''   
				if(@CreditDays<>0)
					set @SQL=@SQL+',CreditDays ='+CONVERT(VARCHAR,@CreditDays)+''
				if(@CreditLimit<>0)
					set @SQL=@SQL+',CreditLimit ='+CONVERT(VARCHAR,@CreditLimit)+'' 
				if(@DebitDays<>0)
					set @SQL=@SQL+',DebitDays ='+CONVERT(VARCHAR,@DebitDays)+''
				if(@DebitLimit<>0)
					set @SQL=@SQL+',DebitLimit ='+CONVERT(VARCHAR,@DebitLimit)+''
				if(@PurchaseAccount>0)
					set @SQL=@SQL+',PurchaseAccount='+ISNULL(CONVERT(VARCHAR,@PurchaseAccount),0)+''
				if(@SalesAccount>0)
					set @SQL=@SQL+',SalesAccount='+ISNULL(CONVERT(VARCHAR,@SalesAccount),0)+' '
				if(@AliasName<>'')
					set @SQL=@SQL+',AliasName =N'''+isnull(REPLACE(@AliasName,'''',''''''),'')+'''  ' 
					
				set @SQL=@SQL+' WHERE AccountID='+convert(nvarchar,@NodeID)  

				EXEC (@SQL)  
				
				if(@IsMove=1 and @IsUpdate=1 and @SelectedNode>0)
				begin
					exec [spACC_MoveAccount] @NodeID,@SelectedNode,1,1
				end
			end  
			else if(@COSTCENTERID=3)  
			begin  
				if( @IsCode is not null and @IsCode =0)  
					set @NodeID= (Select  top 1 ProductID from INV_Product with(nolock) where ProductName=@AccountName)   
				else  
					set @NodeID= (Select  top 1 ProductID from INV_Product with(nolock) where ProductCode=@AccountCode)   
				if(@AccountCode='' or @AccountCode is null)  
					set @AccountCode= (Select top 1 ProductCode from INV_Product with(nolock) where ProductID=@NodeID)  
				SET @SQL=@SQL+' ProductCode= N'''+ISNULL(REPLACE(@AccountCode,'''',''''''),'')+''', ProductName=N'''+REPLACE(@AccountName,'''','''''')+''''  
				if(@TypeID<>0)
					set @SQL=@SQL+',ProductTypeID = '+convert(NVARCHAR,@TypeID)+''  
				if(@ValuationID<>0)
					set @SQL=@SQL+',ValuationID = '+convert(NVARCHAR,@ValuationID)+''
				if(@PurchaseAccount<>0)
					set @SQL=@SQL+',PurchaseAccountID='+ISNULL(CONVERT(VARCHAR,@PurchaseAccount),0)+''
				if(@StatusID<>0)
					set @SQL=@SQL+',StatusID='+ISNULL(CONVERT(VARCHAR,@StatusID),0)+''
				if(@SalesAccount<>0)
					set @SQL=@SQL+',SalesAccountID='+ISNULL(CONVERT(VARCHAR,@SalesAccount),0)+' '
				if(@AliasName<>'')
 					set @SQL=@SQL+',AliasName =N'''+isnull(REPLACE(@AliasName,'''',''''''),'')+'''  ' 
				set @SQL=@SQL+' WHERE ProductID='+convert(nvarchar,@NodeID)   
				PRINT @SQL  
				EXEC  (@SQL)  
				if(@IsMove=1 and @IsUpdate=1 and @SelectedNode>0)
				begin
					exec spINV_MoveProduct @NodeID,@SelectedNode,1,1
				end
			end  
			else if(@COSTCENTERID=83)  
			begin
				if( @IsCode is not null and @IsCode =0)  
					set @NodeID= (Select  top 1 CustomerID from CRM_CUSTOMER with(nolock) where CustomerName=@AccountName)   
				else  
					set @NodeID= (Select  top 1 CustomerID from CRM_CUSTOMER with(nolock) where CustomerCode=@AccountCode)   
					 
				set @AccountCode= (Select CustomerCode from CRM_CUSTOMER with(nolock) where CustomerID=@NodeID)  
				  
				SET @SQL=@SQL+' CustomerCode= N'''+ISNULL(@AccountCode,'')+''', CustomerName=N'''+@AccountName+''',  
				CustomerTypeID = '+ISNULL(convert(NVARCHAR,@TypeID),1)+',    
				AliasName =N'''+isnull(REPLACE(@AliasName,'''',''''''),'')+'''   
				WHERE CustomerID='+convert(nvarchar,@NodeID)  
				EXEC  (@SQL)  
			end  
			else if(@COSTCENTERID=65)  
			begin   
				IF @COSTCENTERID=65  
				BEGIN   
					set @NodeID= (Select  top 1 ContactID from Com_Contacts with(nolock) where Company=@AccountName)
					set @AccountCode= (Select FirstName from Com_Contacts with(nolock) where ContactID=@NodeID)  
				END
				SET @SQL=@SQL+' FirstName= N'''+ISNULL(@AccountCode,'')+''', Company=N'''+@AccountName+''',       
				MiddleName =N'''+isnull(REPLACE(@AliasName,'''',''''''),'')+'''   
				WHERE ContactID='+convert(nvarchar,@NodeID)   
				EXEC  (@SQL)  
			end  
			else  
			begin  
			
				if( @IsCode is not null and @IsCode =0)   
					SET @DUPLICATECODE=' SELECT @NodeID=NodeID  FROM '+@Table+' with(nolock) WHERE  NAME=N'''+LTRIM(RTRIM(@AccountName))+''''  
				ELSE  
					SET @DUPLICATECODE=' SELECT @NodeID=NodeID  FROM '+@Table+' with(nolock) WHERE  CODE=N'''+LTRIM(RTRIM(@AccountCode))+''''  

				EXEC sp_executesql @DUPLICATECODE, N'@NodeID NVARCHAR(max) OUTPUT', @NodeID OUTPUT  
				select @NodeID,@IsCode  

				SET @SQL=@SQL+' Name=N'''+@AccountName+''',Code=N'''+@AccountCode+''',
				StatusID='+ISNULL(CONVERT(VARCHAR,@StatusID),0)+',  
				CreditDays ='+ISNULL(CONVERT(VARCHAR,@CreditDays),0)+',CreditLimit ='+ISNULL(CONVERT(VARCHAR,@CreditLimit),0)+',  
				DebitDays = '+ISNULL(CONVERT(VARCHAR,@DebitDays),0)+', DebitLimit =-'+ISNULL(CONVERT(VARCHAR,@DebitLimit),0)+',  
				PurchaseAccount='+ISNULL(CONVERT(VARCHAR,@PurchaseAccount),0)+',SalesAccount='+ISNULL(CONVERT(VARCHAR,@SalesAccount),0)+' ,  
				AliasName =N'''+isnull(REPLACE(@AliasName,'''',''''''),'')+'''   
				WHERE NodeID='+convert(nvarchar,@NodeID)+''  
				
				EXEC  (@SQL)  
				if(@IsMove=1 and @IsUpdate=1 and @SelectedNode>0 and @COSTCENTERID>50000)
				begin
					exec spCOM_MoveCostCenter @COSTCENTERID,@NodeID,@SelectedNode,@RoleID,1
				end
		       
				if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''  
				begin  
					set @SQL='update '+@Table+' set '+@ExtraUserDefinedFields+ ' where [NodeID]='+convert(nvarchar,@NodeID)  
					exec (@SQL)  
				end  
				if @CostCenterFields is not null and @CostCenterFields<>''  
				begin   
					set @SQL='update COM_CCCCData  
					set '+@CostCenterFields+ 'where      
					CostCenterID = '+convert(nvarchar,@COSTCENTERID)+' AND [NodeID]='+convert(nvarchar,@NodeID)  
					exec (@SQL)  
				end  
			end    
			
			set @HistoryStatus='Update'
		END  
	     
		if @COSTCENTERID=65  
		begin 

			if(@IsUpdate=0 AND @DUPNODENO=0)  
			begin  
				INSERT INTO Com_ContactsExtended([ContactID],[CreatedBy],[CreatedDate])  
				VALUES(@NodeID, @UserName, @Dt)  

				INSERT INTO COM_CCCCDATA (CostCenterID,NodeID,[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
				VALUES(65,@NodeID, @UserName, @Dt, @CompanyGUID,newid())  
			end  
	       
			if @ExtraFields is not null and @ExtraFields<>''  
			begin    
				set @SQL=''  
				set @SQL='update '+@Table+' set '+@ExtraFields+ ' where [CONTACTID]='+convert(nvarchar,@NodeID)  
				print @SQL  
				exec (@SQL)   
			end  
	      
			if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''  
			begin  
				set @SQL='update Com_ContactsExtended  
				set '+@ExtraUserDefinedFields+ '  where [ContactID]='+convert(nvarchar,@NodeID)  
				print @SQL  
				exec (@SQL)  
			end   
	       
			if @CostCenterFields is not null and @CostCenterFields<>''  
			begin  
				set @SQL='update COM_CCCCDATA   
				set '+@CostCenterFields+ ' where [NodeID]='+convert(nvarchar,@NodeID) + ' AND CostCenterID = 65 '  
				exec (@SQL)  
			end  
	     
			if (@Customerdata is not null and @Customerdata<>'')  
			begin  
				DECLARE @TblCustomer TABLE(ID int identity(1,1), GroupName nvarchar(50),CostCenterID INT)  
				Declare @CustomerID int,@cname nvarchar(max)  

				IF LEN(@Customerdata)>0  
				BEGIN  
					SET @Customerdata= replace(@Customerdata,'&','&amp;')      
				END  
	        
				set @Customerdata ='<XML><Row '+ @Customerdata+' Action=''NEW''  /></XML>'  

				SET @CustomersXML =@Customerdata  

				INSERT INTO @TblCustomer(GroupName,CostCenterID)  
				SELECT X.value('@CustomerName','NVARCHAR(300)'), X.value('@CCID','NVARCHAR(300)')            
				FROM @CustomersXML.nodes('/XML/Row') as Data(X)  
	        
				IF ((SELECT CostCenterID FROM @TblCustomer )=83)--INSERT CONTACT FOR CUSTOMER  
				BEGIN  
					select @CustomerID=isnull(customerID,0) from CRM_CUSTOMER with(Nolock) where customername  collate database_default=  
					(select top 1 GroupName from @TblCustomer)  
					IF @CustomerID=0 or @CustomerID is null  
					BEGIN  
						select @cname=GroupName from @TblCustomer    
						EXEC @return_value = [dbo].[spcRM_SetCustomer]  
						@CustomerID = 0,@CustomerCode = @cname,@CustomerName=@cname,   
						@StatusID=0,@AccountID=0,@SelectedNodeID=0,@IsGroup=0,@ContactsXML=NULL,  
						@CompanyGUID=@COMPANYGUID,@ActivityXml=null,@FromImport=1,@GUID='GUID',
						@UserName=@USERNAME,@UserID=@USERID  

						set @SQL=''  
						set @SQL='update '+@Table+' set Featureid=83, FeaturePK='+convert(nvarchar(200),@return_value)+'  
						where [ContactID]='+convert(nvarchar,@NodeID)  
						EXEC(@SQL)  

					END  
					else  
					begin  
						set @SQL=''  
						set @SQL='update '+@Table+' set Featureid=83, FeaturePK='+convert(nvarchar(200),@CustomerID)+'  
						where [ContactID]='+convert(nvarchar,@NodeID)  
						EXEC(@SQL)  
					end  
				END  
				ELSE IF ((SELECT CostCenterID FROM @TblCustomer )=2) --INSERT CONTACT FOR ACCOUNT  
				BEGIN   
					select @CustomerID=isnull(AccountID,0) from ACC_Accounts with(Nolock) where AccountName collate database_default= (select top 1 GroupName from @TblCustomer)  
					select @cname=GroupName from @TblCustomer     
					IF @CustomerID=0 or @CustomerID is null  
					BEGIN   
					SELECT 1
						EXEC @return_value = [dbo].[spACC_SetAccount]  
							@AccountID = 0,  
							@AccountCode = @cname,  
							@AccountName = @cname,  
							@AliasName = @cname,  
							@AccountTypeID = 1,  
							@StatusID = 33,  
							@SelectedNodeID = 0,  
							@IsGroup = 0,  
							@CreditDays = 0,  
							@CreditLimit = 0,  
							@DebitDays = 0,  
							@DebitLimit = 0,  
							@Currency = 1,  
							@PurchaseAccount = 0,  
							@SalesAccount = 0,  
							@COGSAccountID = 0,  
							@ClosingStockAccountID = 0,  
							@IsBillwise = 1,  
							@CompanyGUID = @COMPANYGUID,   
							@GUID = 'GUID',  
							@UserName = @USERNAME,@UserID=@USERID,@RoleID=@RoleID,@CustomFieldsQuery='',@CustomCostCenterFieldsQuery='',  
							@PrimaryContactQuery='',@ContactsXML='',@AttachmentsXML='',@NotesXML='',@AddressXML='',  
							@PDCReceivableAccount=0,@PDCPayableAccount=0,@PaymentTerms='',@Description=NULL   
						SELECT 11
						set @SQL=''  
						set @SQL='update '+@Table+' set Featureid=2, FeaturePK='+convert(nvarchar(200),@return_value)+'  
						where [ContactID]='+convert(nvarchar,@NodeID)  
						print @SQL  
						EXEC(@SQL)  
					END  
					else  
					begin  
						set @SQL=''  
						set @SQL='update '+@Table+' set Featureid=2, FeaturePK='+convert(nvarchar(200),@CustomerID)+'  
						where [ContactID]='+convert(nvarchar,@NodeID)    
						EXEC(@SQL)  
					end  
				END     
			end  
		END  
		else if(@COSTCENTERID=2)  
		begin 

			if(@IsUpdate=0 AND @DUPNODENO=0)  
			begin   
				INSERT INTO [ACC_AccountsExtended]([AccountID],[CreatedBy],[CreatedDate])  
				VALUES(@NodeID, @UserName, @Dt)   

				INSERT INTO COM_CCCCDATA (CostCenterID,NodeID,[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
				VALUES(2,@NodeID, @UserName, @Dt, @CompanyGUID,newid())  
			end  
			if( @IsCode is not null and @IsCode =0)  
				set @NodeID= (Select  top 1  AccountID from ACC_Accounts WITH(nolock) where AccountName=@AccountName)   
			else if(@IsCode=1 and @IsCode is not null)  
				set @NodeID= (Select  top 1 AccountID from ACC_Accounts WITH(nolock) where AccountCode=@AccountCode)   
			
			if @ExtraFields is not null and @ExtraFields<>''  
			begin   
				set @SQL=''  
				set @SQL='update '+@Table+' set '+@ExtraFields+ ' where [AccountID]='+convert(nvarchar,@NodeID)  
				print @SQL 
				exec (@SQL)   
			end  
	      
			if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''  
			begin  
				set @SQL='update [ACC_AccountsExtended]   
				set '+@ExtraUserDefinedFields+ '  where [AccountID]='+convert(nvarchar,@NodeID)  
				print @SQL  
				exec (@SQL)  
			end  
			
			if @CostCenterFields is not null and @CostCenterFields<>''  
			begin  
				set @SQL='update COM_CCCCDATA   
				set '+@CostCenterFields+ ' where [NodeID]='+convert(nvarchar,@NodeID) + ' AND CostCenterID = 2 '  
				exec (@SQL)  
			end  
			
			IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
				EXEC spCOM_SetHistory 2,@NodeID,@HistoryXML,@UserName
		end  
		else if(@COSTCENTERID=3)  
		begin 
			if(@IsUpdate=0 AND @DUPNODENO=0)  
			begin  
				INSERT INTO INV_ProductExtended  ([ProductID]  ,[CreatedBy]  ,[CreatedDate])    
				VALUES  (@NodeID,@UserName, @Dt)    

				INSERT INTO COM_CCCCDATA (COSTCENTERID , [NodeID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
				VALUES(3,@NodeID, @UserName, @Dt, @CompanyGUID,newid())  
			end 
			 
			--if(@IsDuplicateNameAllowed is not null and @IsDuplicateNameAllowed=1)
			--	set @NodeID= (Select  top 1 ProductID from INV_Product WITH(nolock) where ProductCode=@AccountCode)  
			--else 
			if( @IsCode is not null and @IsCode=0)  
				set @NodeID= (Select  top 1 ProductID from INV_Product WITH(nolock) where ProductName=@AccountName)   
			else if(@IsCode is not null and @IsCode=1)    
				set @NodeID= (Select  top 1 ProductID from INV_Product WITH(nolock) where ProductCode=@AccountCode)
				
			if @ExtraFields is not null and @ExtraFields<>''  
			begin  
				set @SQL='update '+@Table+' set '+@ExtraFields+ ' where [ProductID]='+convert(nvarchar,@NodeID)  
				PRINT @SQL
				exec (@SQL)  
				--SELECT UOMID FROM INV_PRODUCT WHERE PRODUCTID=@NodeID
			end  
			
			if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''  
			begin  
				set @SQL='update INV_ProductExtended   
				set '+@ExtraUserDefinedFields+ 'where [ProductID]='+convert(nvarchar,@NodeID)  
				exec (@SQL)  
			end  
			
			if @CostCenterFields is not null and @CostCenterFields<>''  
			begin  
				set @SQL='update COM_CCCCDATA  
				set '+@CostCenterFields+ ' where [NodeID]='+convert(nvarchar,@NodeID) + ' AND CostCenterID = 3 '  
				exec (@SQL)  
			end  
			
			IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
				EXEC spCOM_SetHistory 3,@NodeID,@HistoryXML,@UserName
	      
			if @ProductWiseUOM is not null and @ProductWiseUOM<>'' and @COSTCENTERID=3  
			begin  
				IF((SELECT COUNT(*) FROM [COM_UOM] WITH(nolock) WHERE PRODUCTID=@NodeID)>0)  
				BEGIN   
					UPDATE INV_PRODUCT SET UOMID=1 WHERE PRODUCTID=@NodeID   
					DELETE FROM [COM_UOM] WHERE PRODUCTID=@NodeID  
				END  
				
				set @ProductWiseUOM ='<Data>  <Row RowNo=''1'' UnitiD='''' Action="NEW" MapAction="0" BaseID="-100" '+ @ProductWiseUOM+' /></Data>'  
				DECLARE @UOMDATA XML,@RUOMID INT,@RPRODUCTID INT,@RCOUNT INT,@BASEDATA XML,@BCOUNT INT,@J INT,@BASEID INT,@Conversion FLOAT,  
				@MAPACTION2 INT,@ACTION NVARCHAR(300),@UOMID INT,  
				@BASENAME NVARCHAR(300),@TEMPBASEID INT,  
				@UNITID INT,@UNAME NVARCHAR(300),@CONVERSIONRATE FLOAT  

				SET @UOMDATA=@ProductWiseUOM   
				SET @BASEDATA=@ProductWiseUOM   
				DECLARE @TBLBASE TABLE(ID INT IDENTITY(1,1),BASEID INT,BASENAME NVARCHAR(300),MAPACTION INT,CONVERSION float)  

				INSERT INTO @TBLBASE  
				SELECT X.value('@BaseID','int'),X.value('@BaseName','NVARCHAR(50)'), 
				X.value('@MapAction','NVARCHAR(50)') , X.value('@Conversion','float')   
				FROM @BASEDATA.nodes('/Data/Row') as Data(X)  

				DECLARE @TBLUOM TABLE(ID INT IDENTITY(1,1),UNITID INT,UNITNAME NVARCHAR(300),BASEID INT,  
				BASENAME NVARCHAR(300),CONVERSIONRATE FLOAT,MAPACTION INT,ACTION NVARCHAR(300),CONVERSION float)  

				INSERT INTO @TBLUOM  
				SELECT X.value('@UnitiD','int'),X.value('@UnitName','NVARCHAR(50)'),X.value('@BaseID','int'),  
				X.value('@BaseName','NVARCHAR(50)'),X.value('@ConversionUnit','float') ,X.value('@MapAction','INT'),
				X.value('@Action','nvarchar(300)'),X.value('@Conversion','float')   
				FROM @UOMDATA.nodes('/Data/Row') as Data(X)   

				SELECT @I=1,@RCOUNT=COUNT(*) FROM @TBLUOM  
				SELECT @J=1,@BCOUNT=COUNT(*) FROM @TBLBASE  
				WHILE @J<=@BCOUNT  
				BEGIN  
					SELECT  @TEMPBASEID=BASEID,@BASENAME=BASENAME,@Conversion=CONVERSION FROM @TBLBASE WHERE ID=@J  
					IF((SELECT ISNULL(COUNT(*),0) FROM [COM_UOM] WITH(nolock) WHERE   BASEID = @TEMPBASEID)=0)  
					BEGIN  
						SELECT @BASEID=ISNULL(MAX(BASEID),0) FROM [COM_UOM] WITH(NOLOCK)  
						SET @BASEID=@BASEID+1  
						INSERT INTO [COM_UOM] (BASEID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)  
						VALUES(@BASEID,@BASENAME,@Conversion,@BASENAME,@Conversion,NEWID(),@USERNAME,@Dt,@NodeID,1)   
					END    
					ELSE  
					BEGIN  
						UPDATE [COM_UOM] SET BASENAME=@BASENAME,UNITNAME=@BASENAME WHERE BASEID=@TEMPBASEID AND UNITID=1    
						SET @BASEID=@TEMPBASEID  
					END  

					WHILE @I<=@RCOUNT  
					BEGIN  

						SELECT @ACTION=ACTION,@MAPACTION2=MAPACTION,@RUOMID=UNITID,@UNAME=UNITNAME,@CONVERSIONRATE=CONVERSIONRATE,@Conversion=CONVERSION FROM @TBLUOM WHERE ID=@I   
				 
						IF (@ACTION=LTRIM(RTRIM('NEW')))  
						BEGIN  
							If exists(select unitname from Com_uom WITH(nolock) where BaseID=@BASEID and Unitname=@UNAME AND UnitID>1)  
							begin  
								RAISERROR('-124',16,1)  
							end   
							--SELECT UNIT ID MAX FROM TABLE   
							SELECT @UNITID=ISNULL(MAX(UNITID),0)+1 FROM [COM_UOM] WITH(NOLOCK)  

							INSERT INTO [COM_UOM] (BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)  
							VALUES(@BASEID,@BASENAME,@UNITID,@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,@Dt,@NodeID,1)   

							IF @I=1  
								SET @UOMID=SCOPE_IDENTITY()   
						END      
						SET @I=@I+1  
					END  
					SET @TEMPBASEID=0  
					SET @I=1  
					SET @J=@J+1  
				END  
				update inv_product set UOMID=@UOMID where ProductID=@NodeID  
			end  
		end  
		else if (@COSTCENTERID=83)  
		begin 
			if(@IsUpdate=0 AND @DUPNODENO=0)  
			begin  
				INSERT INTO CRM_CustomerExtended([CustomerID],[CreatedBy],[CreatedDate])  
				VALUES(@NodeID, @UserName, @Dt)  

				INSERT INTO COM_CCCCDATA (CostCenterID,NodeID,[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
				VALUES(83,@NodeID, @UserName, @Dt, @CompanyGUID,newid())  
			end  
			if(@IsCode is not null and @IsCode =0)  
				set @NodeID= (Select  top 1 CustomerID from crm_customer WITH(nolock) where CustomerName=@AccountName)   
			else if(@IsCode=1 and @IsCode is not null)  
				set @NodeID= (Select  top 1 CustomerID from crm_customer WITH(nolock) where CustomerCode=@AccountCode)   

			if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''  
			begin  
				set @SQL='update  dbo.CRM_CustomerExtended  
				set '+@ExtraUserDefinedFields+ '  where [CustomerID]='+convert(nvarchar,@NodeID)  
				print @SQL  
				exec (@SQL)  
			end   

			if @CostCenterFields is not null and @CostCenterFields<>''  
			begin  
				set @SQL='update COM_CCCCDATA   
				set '+@CostCenterFields+ ' where [NodeID]='+convert(nvarchar,@NodeID) + ' AND CostCenterID = 83 '  
				exec (@SQL)  
			end  
		end     
		else   
		begin 
			--Handling of CostCenter Costcenters Extrafields Table  
			if(@IsUpdate=0 AND @DUPNODENO=0)  
			begin  
				INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
				VALUES(@CostCenterID, @NodeID, @UserName, @Dt, @CompanyGUID,newid())  
			end    
			
			if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''  
			begin  
			
				set @SQL='update '+@Table+' set '+@ExtraUserDefinedFields+ ' where [NodeID]='+convert(nvarchar,@NodeID)  
				exec (@SQL)  
			end  

			if @CostCenterFields is not null and @CostCenterFields<>''  
			begin   
				set @SQL='update COM_CCCCData  
				set '+@CostCenterFields+ 'where      
				CostCenterID = '+convert(nvarchar,@COSTCENTERID)+' AND [NodeID]='+convert(nvarchar,@NodeID)  
				print (@SQL)  
				exec (@SQL)  
			end   

			IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
				EXEC spCOM_SetHistory @CostCenterID,@NodeID,@HistoryXML,@UserName
		end    
		
		if(@COSTCENTERID=3 and @NodeID>0) --FOR Stock Code
		begin 
			--Insert Stock Code
			if (select Value from ADM_GlobalPreferences with(nolock) where Name='POSEnable')='True'
			begin
				declare @SellingRateF float, @SellingRateG float
				select @SellingRateF=SellingRateF, @SellingRateG=SellingRateG, @AccountCode=ProductCode from inv_product WITH(nolock) where productID=@NodeID
				if @IsUpdate=0
					exec spDoc_SetStockCode 0,1,@AccountCode,@NodeID,null,@SellingRateF,@SellingRateG,null,@UserName
				else
					exec spDoc_SetStockCode 1,1,@AccountCode,@NodeID,null,@SellingRateF,@SellingRateG,null,@UserName
			end
		end
	    
	    --Duplicate Check
		exec [spCOM_CheckUniqueCostCenter] @COSTCENTERID=@COSTCENTERID,@NodeID =@NodeID,@LangID=@LangID
 
		if(@COSTCENTERID<>3) --FOR Address  
		begin 
			if(@IsUpdate=0 AND @DUPNODENO=0)  
			begin  
				--INSERT PRIMARY CONTACT  
				INSERT COM_Address([AddressTypeID],[FeatureID],[FeaturePK],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],AddressName)  
				VALUES(1,@CostCenterId,@NodeID,@CompanyGUID,NEWID(),@UserName,@Dt,'')    
			end  
	      
			if(@PrimaryContactQuery is not null and @PrimaryContactQuery<>'')  
			begin  
				if  exists ( select addressid from COM_Address with(nolock) where FeatureID=@CostCenterId and AddressTypeID=1 and FeaturePK=@NodeID)
				begin
					set @SQL='update COM_Address  
					SET '+@PrimaryContactQuery+' WHERE [AddressTypeID] = 1 AND [FeaturePK]='+convert(nvarchar,@NodeID)+' and [FeatureID]='+convert(nvarchar,@CostCenterId)  
				end
				else
				begin
					INSERT INTO COM_Address(AddressTypeID,FeatureID,FeaturePK,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
					VALUES (1,@CostCenterId,@NodeID,NEWID(),NEWID(),@UserName,@Dt)
					set @SQL='update COM_Address  
					SET '+@PrimaryContactQuery+' WHERE [AddressTypeID] = 1 AND [FeaturePK]='+convert(nvarchar,@NodeID)+' and [FeatureID]='+convert(nvarchar,@CostCenterId)  
				end
				exec(@SQL)  
			end   
	      
			INSERT INTO COM_Address_History(AddressID,AddressTypeID,FeatureID,FeaturePK,ContactPerson,CostCenterID,    
			Address1,Address2,Address3,City,State,Zip,Country,    
			Phone1,Phone2,Fax,Email1,Email2,URL,GUID,CreatedBy,CreatedDate , AddressName)  
			SELECT AddressID,AddressTypeID,FeatureID,FeaturePK,ContactPerson,CostCenterID,    
			Address1,Address2,Address3,City,State,Zip,Country,    
			Phone1,Phone2,Fax,Email1,Email2,URL,GUID,CreatedBy,CreatedDate , AddressName  
			FROM COM_Address WITH(NOLOCK)  
			WHERE FeatureID=@CostCenterId AND FeaturePK=@NodeID  
		end    
		
		IF (@ProductImage IS NOT NULL AND @ProductImage<>'') --ADDED CONDITION BY HAFEEZ TO IMPORT IMAGES  
		BEGIN 
			SET @ProductImage='<XML><Row '+ @ProductImage+' Action=''NEW''  /></XML>'    
			SET @ProductImageXML=@ProductImage    
			 
			--IF PRODUCT ALREADY CONTAINS IMAGE THEN DELETE THE RECORD  
			DELETE FROM COM_Files WHERE FeatureID=@COSTCENTERID AND FeaturePK=@NodeID AND IsProductImage=1  

			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,  
			FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
			GUID,CreatedBy,CreatedDate, IsDefaultImage)  
			SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(150)'),  
			X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),@COSTCENTERID,@COSTCENTERID,@NodeID,  
			X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  ,X.value('@IsDefaultImage','bit') 
			FROM @ProductImageXML.nodes('/XML/Row') as Data(X)    
			WHERE X.value('@Action','NVARCHAR(10)')='NEW'    
			
		END  
	 
		--@AttachmentXML
		IF (@Attachment IS NOT NULL AND @Attachment<>'') --ADDED CONDITION BY HAFEEZ TO IMPORT Attachments 
		BEGIN 
			SET @AttachmentXML=@Attachment 
			  
			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,  
			FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
			GUID,CreatedBy,CreatedDate, IsDefaultImage)  
			SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(150)'),  
			X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),@COSTCENTERID,@COSTCENTERID,@NodeID,  
			X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  ,X.value('@IsDefaultImage','bit')
			FROM @AttachmentXML.nodes('/XML/Row') as Data(X)    
			WHERE X.value('@Action','NVARCHAR(10)')='NEW'    
			
		END 
	       
		if (@Substitutes is not null and @Substitutes<>'')  
		begin 

			DECLARE @TblSubstitue TABLE(ID int identity(1,1),GroupID INT,GroupName nvarchar(50), SProductID INT)  
			Declare @SCnt int, @SI int, @SubGroupName nvarchar(500), @SubGroupID INT,@SProductID INT, @lft int  

			set @Substitutes ='<XML><Row '+ @Substitutes+' Action=''NEW''  /></XML>'  
			SET @SubstitutesXML=@Substitutes   
			INSERT INTO @TblSubstitue(GroupID,GroupName, SProductID)  
			SELECT X.value('@GroupID','NVARCHAR(50)'),  
			X.value('@GroupName','NVARCHAR(50)'),  
			X.value('@SProductID','NVARCHAR(50)')  
			FROM @SubstitutesXML.nodes('/XML/Row') as Data(X)  
			WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

			SELECT @SubGroupName=LTRIM(RTRIM(GroupName)), @SubGroupID=GroupID, @SProductID=SProductID FROM @TblSubstitue WHERE ID=1   
			IF EXISTS (SELECT SubstituteGroupName FROM [INV_ProductSubstitutes] WITH(NOLOCK)   
			WHERE SubstituteGroupName=@SubGroupName)  
			BEGIN  
				SELECT @SubGroupID=SubstituteGroupID FROM [INV_ProductSubstitutes] WITH(NOLOCK)   
				WHERE SubstituteGroupName=@SubGroupName  
			END  
			ELSE  
			BEGIN  
				SELECT @SubGroupID=ISNULL(MAX(SubstituteGroupID),0)+1 FROM [INV_ProductSubstitutes] WITH(nolock)   
			END  
	      
			if @IsCode is not null and @IsCode=1 and exists(select top 1 ProductID from INV_Product with(nolock) where ProductCode=@AccountCode)  
			begin  
				set @NodeID=(select top 1 ProductID from INV_Product with(nolock) where ProductCode=@AccountCode)   
			end  
			else  
				set @NodeID=(select top 1 ProductID from INV_Product with(nolock) where ProductName=@AccountName)   

			INSERT INTO [INV_ProductSubstitutes](SubstituteGroupID,SubstituteGroupName,[ProductID],[SProductID],[GUID],[CreatedBy],[CreatedDate],CompanyGUID)  
			VALUES (@SubGroupID,@SubGroupName,@NodeID,0,NEWID(),@UserName,@Dt,@CompanyGUID)  
		end  
	    
		if(@COSTCENTERID=2)--FOR HISTROY   
		begin
				--Creating Dimension based on Preference 'AccountTypeLinkDimension'
				declare @CC nvarchar(max), @CostCID nvarchar(10),@IsGrp int
				set @SelectedNodeName=''
				SELECT @CC=[Value] FROM com_costcenterpreferences with(nolock) WHERE [Name]='AccountTypeLinkDimension'
				if (@CC is not null and @CC<>'')
				begin
					SELECT @SelectedNodeName=isnull(X.value('@GroupName','nvarchar(200)'),''),@IsGrp=isnull(X.value('@IsGroup','int'),0) from @DATA.nodes('/XML/Row') as Data(X)  
					DECLARE @TblCC AS TABLE(ID INT IDENTITY(1,1),CC nvarchar(100))
					DECLARE @TblCCVal AS TABLE(ID INT IDENTITY(1,1),CC2 nvarchar(100))

					INSERT INTO @TblCC(CC)
					EXEC SPSplitString @CC,','
					declare @rcnt int,@AccountTypeID int,@AccountID int
					declare @value nvarchar(max)
					set @i=1
					set @AccountID=@NodeID
					select @rcnt=count(*) from @TblCC
					while @i<=@rcnt
					begin
						select @value=cc from @TblCC where id=@i
						--select @value
						insert into @TblCCVal (CC2)
						EXEC SPSplitString @value,'~'
						 --select cc2 from @TblCCVal
						 select @AccountTypeID=AccountTypeID from Acc_Accounts with(NOLOCK) where AccountID=@NodeID
						 select @SelectedNodeID=AccountID from [ACC_Accounts] with(NOLOCK) where AccountName =@SelectedNodeName
						if exists (select cc2 from @TblCCVal where cc2 =@AccountTypeID )
						begin
						
							select @CostCID=cc2 from @TblCCVal where cc2>50000   
							--select @CCID
							if(@CostCID>50000)
							begin
								declare @CCStatusID INT
								set @CCStatusID = (select top 1 statusid from com_status with(nolock) where costcenterid=@CostCID)
								declare @NID INT, @CCIDAcc INT
								select @NID = CCNodeID, @CCIDAcc=CCID  from acc_Accounts with(nolock) where Accountid=@AccountID
								iF(@CCIDAcc<>@CostCID)
								BEGIN
									if(@NID>0)
									begin 
									Update Acc_accounts set CCID=0, CCNodeID=0 where AccountID=@AccountID
									DECLARE @RET INT
										EXEC	@RET = [dbo].[spCOM_DeleteCostCenter]
											@CostCenterID = @CCIDAcc,
											@NodeID = @NID,
											@RoleID=1,
											@UserID = 1,
											@LangID = @LangID
									end	
									set @NID=0
									set @CCIDAcc=0 
								END
								declare @return_val int
								
								if(@NID is null or @NID =0)
								begin 
									
									SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
											WHERE CostCenterID=2 AND RefDimensionID=@CostCID AND NodeID=@SelectedNodeID 
									
									SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
									
									EXEC	@return_val = [dbo].[spCOM_SetCostCenter]
									@NodeID = 0,@SelectedNodeID =@RefSelectedNodeID,@IsGroup = @IsGroup,
									@Code = @AccountCode,
									@Name = @AccountName,
									@AliasName=@AccountName,
									@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
									@CustomFieldsQuery=null,@AddressXML=null,@AttachmentsXML=NULL,
									@CustomCostCenterFieldsQuery=null,@ContactsXML=null,@NotesXML=NULL,
									@CostCenterID = @CostCID,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1,
									@CheckLink = 0,@IsOffline=0 
									 -- Link Dimension Mapping
									 
									INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)
									values(2, @AccountID,0,0,@CostCID,@return_val,'',newid(),@UserName, @dt,'Account')									
									DECLARE @CCMapSql nvarchar(max)
									set @CCMapSql='update COM_CCCCDATA  
									SET CCNID'+convert(nvarchar,(@CostCID-50000))+'='+CONVERT(NVARCHAR,@return_val)+'  WHERE NodeID = '+convert(nvarchar,@AccountID) + ' AND CostCenterID = 2' 									
									EXEC (@CCMapSql)
				 				end
								else
								begin
									declare @Gid nvarchar(50) , @TableName nvarchar(100), @CGid nvarchar(50)
									declare @NidXML nvarchar(max) 
									select @TableName=Tablename from adm_features where featureid=@CostCID
									declare @strgid nvarchar(max) 
									set @strgid='@Gid nvarchar(50) output' 
									set @NidXML='set @Gid= (select GUID from '+@TableName+' with(nolock) where NodeID='+convert(nvarchar,@NID)+')'
										exec sp_executesql @NidXML, @strgid, @Gid OUTPUT 
										
									EXEC	@return_val = [dbo].[spCOM_SetCostCenter]
									@NodeID = @NID,@SelectedNodeID = 1,@IsGroup = 0,
									@Code = @AccountCode,
									@Name = @AccountName,
									@AliasName=@AccountName,
									@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
									@CustomFieldsQuery=null,@AddressXML=null,@AttachmentsXML=NULL,
									@CustomCostCenterFieldsQuery=null,@ContactsXML=null,@NotesXML=NULL,
									@CostCenterID = @CostCID,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1
									,@CheckLink = 0,@IsOffline=0
									
				 				end 
								if(@return_val>0 or @return_val<-10000)
								BEGIN
									Exec [spDOC_SetLinkDimension]
										@InvDocDetailsID=@AccountID, 
										@Costcenterid=2,         
										@DimCCID=@CostCID,
										@DimNodeID=@return_value,
										@BasedOnValue=@AccountTypeID,
										@UserID=@UserID,    
										@LangID=@LangID 
								END
								Update Acc_accounts set CCID=@CostCID, CCNodeID=@return_val where AccountID=@AccountID  
								
							end
						end
						delete from @TblCCVal
						set @i=@i+1
					end 
				end
				 ----------------------------
				 --INSERT INTO HISTROY   
				 EXEC [spCOM_SaveHistory]  
					 @CostCenterID =@COSTCENTERID,    
					 @NodeID =@NodeID,
					 @HistoryStatus =@HistoryStatus,
					 @UserName=@UserName,
					 @DT=@DT
		end
		else if(@COSTCENTERID=3)
		begin
			declare @DimensionPrefValue int
			select @DimensionPrefValue=Value from COM_CostCenterPreferences with(nolock) where CostCenterID=3 and Name='ProductLinkWithDimension'
			set @Dimesion=0
				IF(@DimensionPrefValue is not null and @DimensionPrefValue<>'')  
				BEGIN  

					BEGIN try  
						select @Dimesion=convert(INT,@DimensionPrefValue)  
					end try  
					BEGIN catch  
						set @Dimesion=0   
					end catch  
					
					if(@Dimesion>0)  
					BEGIN  
							SELECT @SelectedNodeName=isnull(X.value('@GroupName','nvarchar(200)'),'') from @DATA.nodes('/XML/Row') as Data(X)  
							select @SelectedNodeID=ProductID from INV_Product with(NOLOCK) where ProductName =@SelectedNodeName
						select @CCStatusID=statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active'
							SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
							WHERE CostCenterID=3 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
							SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
									
							EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]
							@NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
							@Code = @AccountCode,
							@Name = @AccountName,
							@AliasName=@AccountName,
							@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
							@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
							@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
							@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',
							@UserName=@UserName,@RoleID=1,@UserID=1,@CheckLink = 0
							
							Update INV_PRODUCT set CCID=@Dimesion, CCNodeID=@LinkDim_NodeID where ProductID=@NodeID
							
							INSERT INTO COM_DocBridge (CostCenterID,NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,[guid],Createdby,CreatedDate,Abbreviation)
							values(@CostCenterID, @NodeID,0,0,@Dimesion,@LinkDim_NodeID,'',newid(),@UserName, @dt,'Product')
							Delete from com_docbridge WHERE CostCenterID = 3 AND RefDimensionNodeID = 0 AND RefDimensionID =@Dimesion
				
					END
				END
		end
		else if(@COSTCENTERID>50000)
		begin			
			select @PrefValue = Value from COM_CostCenterPreferences WITH(nolock) where CostCenterID=@CostCenterID and  Name = 'LinkDimension' 
			SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterID  
			--Start Map Dimension		
			IF(@PrefValue is not null and @PrefValue<>'')  
			BEGIN  
					set @Dimesion=0  
					BEGIN try  
						select @Dimesion=convert(INT,@PrefValue)  
					end try  
					BEGIN catch  
						set @Dimesion=0   
					end catch  
					if(@Dimesion>0)  
					BEGIN 
						SELECT @SelectedNodeName=isnull(X.value('@GroupName','nvarchar(200)'),'') from @DATA.nodes('/XML/Row') as Data(X) 
						set @SQL='' 
						set @SQL='select @SelectedNodeID=NodeID from '+@Table+' WITH(NOLOCK) where Name='''+convert(nvarchar,@SelectedNodeName) +''''
						
						EXEC sp_executesql @SQL,N'@SelectedNodeID INT OUTPUT',@SelectedNodeID OUTPUT
						--select @SelectedNodeID=AccountID from [ACC_Accounts] with(NOLOCK) where AccountName =@SelectedNodeName
						
						SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
						WHERE CostCenterID=@CostCenterID AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
						SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
						
						select @CCStatID = statusid from com_status WITH(NOLOCK) where costcenterid=@Dimesion and status = 'Active'
						EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]
						@NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
						@Code = @AccountCode,
						@Name = @AccountName,
						@AliasName=@AccountName,
						@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatID,
						@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
						@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
						@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',
						@UserName=@UserName,@RoleID=1,@UserID=1,@CheckLink = 0
						
						INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  
									CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)
						values(@CostCenterID, @NodeID,0,0,@Dimesion,@LinkDim_NodeID,'',newid(),@UserName, @dt,@Table) 
					END  
			END
			--End Map Dimension
		end
		
		End Try  
		Begin Catch  
		     
			set @failCount=@failCount+1  
		    
			if(len(@ERROR_MESSAGE)>0)
				set @ERROR_MESSAGE=@ERROR_MESSAGE+','+ERROR_MESSAGE()
			else
				set @ERROR_MESSAGE=ERROR_MESSAGE() 
		end Catch  
		      
		set @I=@I+1  
   
	end  
  
COMMIT TRANSACTION    
--ROLLBACK TRANSACTION    
  
  
if(@COSTCENTERID=3)  
begin  
	SET @SQL='SELECT ProductID NodeID11,ProductName Name FROM '+@Table+' WITH(nolock)where ProductName in (   
	SELECT X.value(''@AccountName'',''nvarchar(500)'')  
	from @sml.nodes(''/XML/Row'') as Data(X))'  

	EXEC sp_executesql @SQL, N'@sml xml', @XML   
end  
else if(@COSTCENTERID=2)  
begin  
	SET @SQL='SELECT AccountID NodeID,AccountName Name FROM '+@Table+' WITH(nolock)where AccountName in (   
	SELECT X.value(''@AccountName'',''nvarchar(500)'')  
	from @sml.nodes(''/XML/Row'') as Data(X))'  

	EXEC sp_executesql @SQL, N'@sml xml', @XML   
end  
else if(@COSTCENTERID=12)  
begin  
	SET @SQL='SELECT CurrencyID NodeID, Name FROM '+@Table+' WITH(nolock)where Name in (   
	SELECT X.value(''@AccountName'',''nvarchar(500)'')  
	from @sml.nodes(''/XML/Row'') as Data(X))'  

	EXEC sp_executesql @SQL, N'@sml xml', @XML   
end  
else if(@COSTCENTERID=71)  
begin  
	SET @SQL='SELECT ResourceID NodeID,ResourceName Name FROM '+@Table+' WITH(nolock)where ResourceName in (   
	SELECT X.value(''@AccountName'',''nvarchar(500)'')  
	from @sml.nodes(''/XML/Row'') as Data(X))'  

	EXEC sp_executesql @SQL, N'@sml xml', @XML   
end  
else if(@COSTCENTERID=51)  
begin  
	SET @SQL='SELECT CustomerID NodeID,CustomerName Name FROM '+@Table+' WITH(nolock)where CustomerName in (   
	SELECT X.value(''@AccountName'',''nvarchar(500)'')  
	from @sml.nodes(''/XML/Row'') as Data(X))'  

	EXEC sp_executesql @SQL, N'@sml xml', @XML   
end  
else if(@COSTCENTERID=65)  
begin  
	SET @SQL='SELECT ContactID NodeID,Company Name FROM '+@Table+' WITH(nolock) where Company in (   
	SELECT X.value(''@AccountName'',''nvarchar(500)'')  
	from @sml.nodes(''/XML/Row'') as Data(X))'  

	EXEC sp_executesql @SQL, N'@sml xml', @XML   
end  
else if(@COSTCENTERID=83)  
begin  
	SET @SQL='SELECT CustomerID NodeID,CustomerName Name FROM '+@Table+' WITH(nolock) where CustomerName in (   
	SELECT X.value(''@AccountName'',''nvarchar(500)'')  
	from @sml.nodes(''/XML/Row'') as Data(X))'  

	EXEC sp_executesql @SQL, N'@sml xml', @XML   
end  
else  
begin  
	SET @SQL='SELECT NodeID,Name FROM '+@Table+' WITH(nolock)where Name in (   
	SELECT X.value(''@AccountName'',''nvarchar(500)'')  
	from @sml.nodes(''/XML/Row'') as Data(X))'  

	EXEC sp_executesql @SQL, N'@sml xml', @XML   
end  
declare @NodeidXML nvarchar(max)   
declare @str nvarchar(max)   
set @str='@NodeID int output'   
if (@IsCode is not null and @IsCode=0 and @COSTCENTERID>50000)  
	set @NodeidXML='set @NodeID= (select top 1 Nodeid from '+convert(nvarchar,@Table)+' WITH(nolock) where Name='''+@AccountName+''')'  
else if (@IsCode is not null and @IsCode=1 and @COSTCENTERID>50000)   
	set @NodeidXML='set @NodeID= (select top 1 Nodeid from '+convert(nvarchar,@Table)+' WITH(nolock) where Code='''+@AccountCode+''')'  
exec sp_executesql @NodeidXML, @str, @NodeID OUTPUT    
  
   
IF(@CCMapXML <> '' AND @CCMapXML IS NOT NULL and @NodeID is not null)    
BEGIN     
	EXEC [spCOM_SetCCCCMap] @COSTCENTERID,@NodeID,@CCMapXML,@UserName,@LangID  
END
	
	
if(@IsUpdate=1 AND @NodeID IS NULL) 
BEGIN
	SELECT 'Data Not Found' ErrorMessage,-9999 ErrorNumber
	SET @failCount=1
END
else if(@IsUpdate=1 AND @failCount=0) 
	SELECT 'Updated Successfully' ErrorMessage,1100 ErrorNumber
else if(@IsUpdate=0 AND @failCount=0) 
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID  
else
begin 
	SELECT ErrorMessage,ErrorNumber  FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber in (@ERROR_MESSAGE) AND LanguageID=@LangID  
end
 
  SET NOCOUNT OFF;    
  
   
RETURN @failCount   
END TRY    
BEGIN CATCH    

 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountCode=@AccountCode    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
