USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetImportCRMCustomerData]
	@XML [nvarchar](max),
	@CCMapXML [nvarchar](max) = '',
	@AddressXML [nvarchar](max) = '',
	@COSTCENTERID [bigint],
	@IsDuplicateNameAllowed [bit],
	@IsCodeAutoGen [bit],
	@IsOnlyName [bit],
	@IsProductVehicle [bit] = NULL,
	@IsUpdate [bit] = 0,
	@IsCode [bit] = NULL,
	@IsAddress [bit] = 0,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON	


		
		--Declaration Section
		DECLARE	@return_value int,@failCount int
		DECLARE @NodeID bigint, @Table NVARCHAR(50),@SQL NVARCHAR(max),@ParentGroupName NVARCHAR(200),@PK NVARCHAR(50)
		DECLARE @AccountCode nvarchar(max),@GUID nvarchar(max),@CodePrefix nvarchar(100),@CodeNumber BIGINT,@AccountName nvarchar(max),@AliasName nvarchar(max)
        DECLARE @StatusID int,@ExtraFields NVARCHAR(max),@ExtraUserDefinedFields NVARCHAR(max),@CostCenterFields NVARCHAR(max),@PrimaryContactQuery nvarchar(max)
        DECLARE @LinkFields NVARCHAR(MAX), @LinkOption NVARCHAR(MAX),@ProductImage NVARCHAR(MAX),@Customerdata NVARCHAR(MAX), @Substitutes NVARCHAR(MAX),@ProductWiseUOM NVARCHAR(MAX)
		DECLARE @SelectedNode bigint, @IsGroup bit
        DECLARE @CreditDays int, @CreditLimit float
        DECLARE @PurchaseAccount bigint,@Purchase nvarchar(max)
        DECLARE @SalesAccount bigint,@Sales nvarchar(max)
        DECLARE @DebitDays int, @DebitLimit float
		DECLARE @IsBillwise bit, @TypeID int, @ValuationID   int,@Dt float
		DECLARE @Make nvarchar(400),@Model nvarchar(400),@Year nvarchar(400),@Variant nvarchar(400),@Segment nvarchar(400),@VehicleID bigint
		DECLARE @tempCode NVARCHAR(max),@DUPLICATECODE NVARCHAR(300),@DUPNODENO INT,@PARENTCODE NVARCHAR(max)
		DECLARE @tempName NVARCHAR(max),@DUPLICATEName NVARCHAR(300), @DUPNODENOCODE INT
		DECLARE @TempGuid NVARCHAR(max),@HasAccess BIT,@DATA XML,@Cnt INT,@I INT,@customertype INT, @CCID INT, @SubstitutesXML XML,@CustomersXML XML, @ProductImageXML XML
	 
		SET @customertype =(SELECT TOP (1) NODEID FROM COM_LOOKUP WITH(NOLOCK) WHERE LOOKUPTYPE=45)
		SET @DATA=@XML
		SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
		
		--SP Required Parameters Check
		IF @CompanyGUID IS NULL OR @CompanyGUID=''
		BEGIN
			RAISERROR('-100',16,1)
		END

		SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId
		IF(@COSTCENTERID=2)
			SET @PK='AccountID'
		ELSE IF(@COSTCENTERID=3)
			SET @PK='ProductID'
		ELSE IF(@COSTCENTERID=12)
			SET @PK='CurrencyID'	
		ELSE IF(@COSTCENTERID=71)
			SET @PK='ResourceID'
		ELSE IF(@COSTCENTERID=51 or @COSTCENTERID=83)
			SET @PK='CustomerID'
		ELSE IF(@COSTCENTERID=65)
			SET @PK='ContactID'
		ELSE
			SET @PK='NodeID'
			
			
		-- Create Temp Table
		DECLARE  @temptbl TABLE(ID int identity(1,1),
           [AccountCode] nvarchar(500),CodePrefix nvarchar(100),CodeNumber BIGINT  
           ,[AccountName] nvarchar(max)
           ,[AliasName] nvarchar(max)
           ,[StatusID] int
		   ,SelectedNode bigint
		   ,ParentGroupName NVARCHAR(200)
           ,[IsGroup] bit
           ,[CreditDays] int
           ,[CreditLimit] float
           ,[PurchaseAccount] nvarchar(500)
           ,[SalesAccount] nvarchar(500)
           ,[DebitDays] int
           ,[DebitLimit] float
		   ,IsBillwise bit
		   ,TypeID int
		   ,ValuationID   int,ExtraFields nvarchar(max),ExtraUserDefinedFields nvarchar(max),CostCenterFields nvarchar(max),
		   PrimaryContactQuery nvarchar(max), LinkFields nvarchar(max), LinkOption nvarchar(max), Substitutes NVARCHAR(MAX),Customerdata nvarchar(max), ProductImage NVARCHAR(MAX)    
		   ,Make nvarchar(400),Model nvarchar(400),Year nvarchar(400),Variant nvarchar(400),Segment nvarchar(400),VehicleID int, ProductWiseUOM nvarchar(Max))

	 	--SELECT  	X.value('@AccountCode','nvarchar(500)')
      --     ,X.value('@AccountName','nvarchar(max)') from @DATA.nodes('/XML/Row') as Data(X)


		INSERT INTO @temptbl
           ([AccountCode],CodePrefix,CodeNumber  
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
			,ValuationID,ExtraFields ,ExtraUserDefinedFields ,CostCenterFields,PrimaryContactQuery,LinkFields, LinkOption, Substitutes,
			ProductImage,Customerdata,Make ,Model ,Year ,Variant ,Segment,VehicleID,ProductWiseUOM )          
		SELECT
			X.value('@AccountCode','nvarchar(500)'),X.value('@CodePrefix','nvarchar(100)'),X.value('@CodeNumber','bigint')
           ,X.value('@AccountName','nvarchar(max)')
           ,isnull(X.value('@AliasName','nvarchar(max)'),'')
           ,X.value('@StatusID','int')           
           ,isnull(X.value('@SelectedNode','bigint'),0)
           ,isnull(X.value('@GroupName','nvarchar(200)'),'')
           ,isnull(X.value('@IsGroup','bit'),0)
           ,isnull(X.value('@CreditDays','int'),0)
           ,isnull(X.value('@CreditLimit','float'),0)
           ,X.value('@PurchaseAccount','nvarchar(max)')
           ,X.value('@SalesAccount','nvarchar(max)')
           ,isnull(X.value('@DebitDays','int'),0)
           ,isnull(X.value('@DebitLimit','float'),0)
			,isnull(X.value('@IsBillwise','bit'),0)
			,case when X.value('@TypeID','int') is null and @COSTCENTERID=2 then 7
			else isnull(X.value('@TypeID','int'),1) end
			,isnull(X.value('@ValuationID','int'),1)
			,isnull(X.value('@ExtraFields ','nvarchar(max)'),'')
			,isnull(X.value('@ExtraUserDefinedFields ','nvarchar(max)'),'')
			,isnull(X.value('@CostCenterFields','nvarchar(max)'),'')
			,isnull(X.value('@PrimaryContactQuery','nvarchar(max)'),'')
			,isnull(X.value('@LinkFields','nvarchar(max)'),'')
			,isnull(X.value('@LinkOption','nvarchar(max)'),'')
			,isnull(X.value('@Substitutes','nvarchar(max)'),'')	,isnull(X.value('@ProductImage','nvarchar(max)'),'')
			,isnull(X.value('@CustomerName','nvarchar(max)'),'')
			,X.value('@Make','nvarchar(400)'),X.value('@Model','nvarchar(400)'),X.value('@Year','nvarchar(400)')
			,X.value('@Variant','nvarchar(400)'),X.value('@Segment','nvarchar(400)'),X.value('@VehicleID','int')
			,X.value('@ProductWiseUOM','nvarchar(MAX)')
 		from @DATA.nodes('/XML/Row') as Data(X)
		SELECT @I=1, @Cnt=count(ID) FROM @temptbl 
		set @failCount=0
		WHILE(@I<=@Cnt)  
		BEGIN
		begin try
	 
				 	select @AccountCode    = AccountCode 
					,@AccountName    =  AccountName ,@CodePrefix=ISNULL(CodePrefix,''),@CodeNumber=ISNULL(CodeNumber,0)   
					,@AliasName    = AliasName 
					,@StatusID    = StatusID 
					,@SelectedNode    = SelectedNode
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
					,@ValuationID             = ValuationID  
					,@ExtraFields=ExtraFields ,@ExtraUserDefinedFields=ExtraUserDefinedFields ,@CostCenterFields=CostCenterFields
					,@PrimaryContactQuery=PrimaryContactQuery 
					,@LinkFields=LinkFields 
					,@ProductWiseUOM=ProductWiseUOM,
					@LinkOption=LinkOption,
					@Substitutes=Substitutes,@ProductImage=ProductImage,@Customerdata=Customerdata,
					@VehicleID=VehicleID,@Make=Make ,@Model =Model ,@Year =Year ,@Variant =Variant ,@Segment=Segment
					from  @temptbl where ID=@I
		 
			
		if(@IsOnlyName=1 or @StatusID is null)
		begin
			select @StatusID=StatusID from dbo.COM_Status where CostCenterID=@COSTCENTERID and Status='Active'
		end

		if(@Purchase is not null and @Purchase<>'')
		begin
		select @PurchaseAccount=AccountID from ACC_Accounts where AccountName=@Purchase
		end
		else
		begin
		set @PurchaseAccount=0
		end
		 
		if(@Sales is not null and @Sales<>'')
		begin
		select @SalesAccount=AccountID from ACC_Accounts where AccountName=@Sales
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
 
					SET @DUPLICATEName=@DUPLICATEName+' ='''+@AccountName+''' ' 
					
					 
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

		SET @DUPLICATECODE=@DUPLICATECODE+' ='''+@AccountCode+''' ' 
		
		IF 	@COSTCENTERID<>65	
		begin 
		EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENOCODE OUTPUT
		EXEC sp_executesql @DUPLICATEName, @tempName,@DUPNODENO OUTPUT
		end
 
		IF ((@IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0 and @DUPNODENO >0) 
		OR (@DUPNODENOCODE>0 AND (@IsCodeAutoGen IS NULL OR @IsCodeAutoGen=0)))  and @IsUpdate=0
		BEGIN		 
			 
			RAISERROR('-112',16,1)
		END 
		
			--select @COSTCENTERID,@AccountName, @DUPNODENOCODE,@DUPNODENO,@IsCodeAutoGen,@IsUpdate
		  	if(@COSTCENTERID=12)
			begin
		 		INSERT INTO [COM_Currency]
				   ([Name],[Symbol],[Change],[ExchangeRate],[Decimals],[IsBaseCurrency],[GUID],
				   [CreatedBy],[CreatedDate],[IsDailyRates],[StatusID], CompanyGUID)
				 VALUES
				   (@AccountName,'','',1,2,0,newid(),@UserName,@Dt,0,1,@CompanyGUID)

				--To get inserted record primary key
				SET @NodeID=SCOPE_IDENTITY()--Getting the NodeID  
 			end
 			
			--GENERATE CODE			
			IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1
			BEGIN
				if(@SelectedNode is not null and @SelectedNode>0)
				begin
					SET @tempCode=' @PARENTCODE NVARCHAR(max) OUTPUT' 
					SET @DUPLICATECODE=' SELECT @PARENTCODE=[CODE]
					FROM '+@Table+' WITH(NOLOCK) WHERE '
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
				
				CREATE TABLE #TBLCODEGEN(Prefix NVARCHAR(300),CodeNumber Bigint,Suffix nvarchar(300),Code nvarchar(300))
				insert into #TBLCODEGEN
				EXEC spCOM_GetCodeData @COSTCENTERID,@SelectedNode,''
				
				IF EXISTS(SELECT * FROM #TBLCODEGEN)
				BEGIN
					SELECT @AccountCode=Code,@CodePrefix=Prefix+Suffix,@CodeNumber=CodeNumber FROM #TBLCODEGEN
					DROP TABLE #TBLCODEGEN
				END
				--CALL AUTOCODEGEN
				--EXEC [spCOM_SetCode] @CostCenterId,@ParentCode,@AccountCode OUTPUT
				
			END
			
			IF @AccountCode IS NULL OR @AccountCode=''
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
 
					SET @DUPLICATECODE=@DUPLICATECODE+')+1 FROM '+@Table+' '
				EXEC sp_executesql @DUPLICATECODE, N'@Code NVARCHAR(max) OUTPUT', @AccountCode OUTPUT
			END
		
	  		--To Set Left,Right And Depth of Record  
			SET @SQL='DECLARE @SelectedNodeID BIGINT,@IsGroup BIT,@lft BIGINT,@rgt BIGINT,@Selectedlft BIGINT,@Selectedrgt BIGINT,@Depth INT,@ParentID BIGINT, @SelectedIsGroup BIT'  
			SET @SQL=@SQL+' SELECT @IsGroup='+convert(NVARCHAR,@IsGroup)+', @SelectedNodeID='+convert(NVARCHAR,@SelectedNode)  
			SET @SQL=@SQL+' SELECT @SelectedNodeID='+@PK+', @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			from '+@Table+' with(NOLOCK) where '
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

			SET @SQL=@SQL+'='''+@ParentGroupName+''''  

		 	--IF No Record Selected or Record Doesn't Exist  
			SET @SQL=@SQL+' IF(@SelectedIsGroup is null)   
			select @SelectedNodeID='+@PK

			SET @SQL=@SQL+',@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			from '+@Table+' with(NOLOCK) where ParentID =0'  

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
				if @IsCode is not null and @IsCode=0 and exists(select ProductID from dbo.INV_Product  with(nolock) where ProductName=@AccountName)
				begin
					set @NodeID=(select top 1 ProductID from dbo.INV_Product with(nolock) where ProductName=@AccountName)
				end 
				else if @IsCode is not null and @IsCode=1 and exists(select ProductID from dbo.INV_Product  with(nolock) where ProductCode=@AccountCode)
				begin
					set @NodeID=(select top 1 ProductID from dbo.INV_Product with(nolock) where ProductCode=@AccountCode)
				end 
				 set @LinkFields ='<XML><Row '+ @LinkFields+' Qty=''0'' Rate=''0'' /></XML>'
		 		 --print @LinkFields
		 		-- print @LinkOption
		 		if @LinkOption='One-One'
					EXEC [spINV_SetProductBundle] @LinkFields,@NodeID,@CompanyGUID,@UserName,@UserID,@LangID 
				else if @LinkOption='Many-One'
				BEGIN
					CREATE TABLE #TMP (ID INT IDENTITY(1,1), PRODUCTID INT)
					INSERT INTO #TMP(PRODUCTID)
					 	SELECT PRODUCTID FROM INV_Product where ProductName=@AccountName 
					DECLARE @A INT, @COUNT INT
					SET @A=1
					SELECT @COUNT = COUNT(*) FROM #TMP
					WHILE @A<=@COUNT
					BEGIN
						SELECT @NodeID=PRODUCTID FROM #TMP WHERE ID=@A
						EXEC [spINV_SetProductBundle] @LinkFields,@NodeID,@CompanyGUID,@UserName,@UserID,@LangID 
						SET @A=@A+1
					END
				END
	  		end
  
		 	-- Insert statements for procedure here 
		 	if @IsUpdate=0 and @DUPNODENO=0
		 	begin 
		 		 
		 		SET @SQL=@SQL+' INSERT INTO '+@Table
						+'  (StatusID,'
						if(@COSTCENTERID=2)
							SET @SQL=@SQL+'AccountCode,AccountName,CodePrefix,CodeNumber,AccountTypeID,IsBillwise,CreditDays,CreditLimit,DebitDays, DebitLimit, PurchaseAccount,SalesAccount,AliasName'
						else if(@COSTCENTERID=3)
							SET @SQL=@SQL+'ProductCode,ProductName,CodePrefix,CodeNumber,ProductTypeID,ValuationID,AliasName'
						else if(@COSTCENTERID=71)
							SET @SQL=@SQL+'ResourceCode,ResourceName,CodePrefix,CodeNumber,ResourceTypeID'
						else if(@COSTCENTERID=51)
							SET @SQL=@SQL+'CustomerCode,CustomerName,CodePrefix,CodeNumber,CustomerTypeID, Firstname, AliasName'
						else if(@COSTCENTERID=83)
							SET @SQL=@SQL+'CustomerCode,CustomerName,AliasName,CodePrefix,CodeNumber,CustomerTypeID '	
						else if(@COSTCENTERID=65)
							SET @SQL=@SQL+' FirstName,Company,AddressTypeID,FeatureID,FeaturePK'	
						else
							SET @SQL=@SQL+'[Code],[Name],CreditDays,CodePrefix,CodeNumber,CreditLimit,DebitDays, DebitLimit, PurchaseAccount,SalesAccount,AliasName'
						SET @SQL=@SQL+',[Depth],
							[ParentID],
							[lft],
							[rgt],  
							[IsGroup],
							[CompanyGUID],
							[GUID],
							[CreatedBy],
							[CreatedDate]
							)  
						VALUES('
							+convert(NVARCHAR,@StatusID)+',
							N'''+@AccountCode+''',
							N'''+@AccountName+''','
						if(@COSTCENTERID=2)
							SET @SQL=@SQL+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+''+convert(NVARCHAR,@TypeID)+','+convert(NVARCHAR,@IsBillwise)+',' +CONVERT(VARCHAR,@CreditDays)+','+CONVERT(VARCHAR,@CreditLimit)+','+CONVERT(VARCHAR,@DebitDays)+','+CONVERT(VARCHAR,@DebitLimit)+','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+',N'''+@AliasName+''','
						else if(@COSTCENTERID=3)
							SET @SQL=@SQL+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+''+convert(NVARCHAR,@TypeID)+','+convert(NVARCHAR,@ValuationID)+','''+@AliasName+''','
						else if(@COSTCENTERID=71)
							SET @SQL=@SQL+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+'1, '
						else if(@COSTCENTERID=51)
							SET @SQL=@SQL+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+'1, '''+@AccountName+''','''+@AliasName+''','
						ELSE IF  @COSTCENTERID=83
							SET @SQL=@SQL+'N'''+@AliasName+''','+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+convert(NVARCHAR,@customertype)+','
						ELSE IF  @COSTCENTERID=65
							SET @SQL=@SQL+'2,65,0,'
						else
							SET @SQL=@SQL+CONVERT(VARCHAR,@CreditDays)+'N'''+@CodePrefix+''','+convert(NVARCHAR,@CodeNumber)+','+CONVERT(VARCHAR,@CreditLimit)+','+CONVERT(VARCHAR,@DebitDays)+','+CONVERT(VARCHAR,@DebitLimit)+','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+','''+@AliasName+''','
						SET @SQL=@SQL+'@Depth,
							@ParentID,
							@lft,
							@rgt,   
							@IsGroup,'''+@CompanyGUID+''',
							newid(),
							'''+@UserName+''',
							convert(float,getdate()))  
						SET @NodeID=SCOPE_IDENTITY()'--To get inserted record primary key
				print @SQL 
				EXEC sp_executesql @SQL, N'@NodeID INT OUTPUT', @NodeID OUTPUT 
				  
			end
			else IF  @IsUpdate=1
			BEGIN	
				 
				set @SQL=''
				
				--DECLARE @AccountID bigint 
				SET @SQL=@SQL+' UPDATE '+@Table+ ' SET '	
				
				if(@COSTCENTERID=2)
				begin  
					if( @IsCode is not null and @IsCode =0)
						set @NodeID= (Select  top 1  AccountID from ACC_Accounts where AccountName=@AccountName) 
					else
						set @NodeID= (Select  top 1 AccountID from ACC_Accounts where AccountCode=@AccountCode) 
				 	--set @NodeID= (Select  top 1  AccountID from ACC_Accounts where AccountName=@AccountName )
					set @AccountCode= (Select AccountCode from ACC_Accounts where AccountID=@NodeID )
				  	SET @SQL=@SQL+' AccountCode= N'''+ISNULL(@AccountCode,'')+''', AccountName=N'''+@AccountName+''',
					AccountTypeID = '+ISNULL(convert(NVARCHAR,@TypeID),7)+', IsBillwise = '+ISNULL(convert(NVARCHAR,@IsBillwise),0)+',
					CreditDays ='+ISNULL(CONVERT(VARCHAR,@CreditDays),0)+',CreditLimit ='+ISNULL(CONVERT(VARCHAR,@CreditLimit),0)+',
					DebitDays = '+ISNULL(CONVERT(VARCHAR,@DebitDays),0)+', DebitLimit =-'+ISNULL(CONVERT(VARCHAR,@DebitLimit),0)+',
					PurchaseAccount='+ISNULL(CONVERT(VARCHAR,@PurchaseAccount),0)+',SalesAccount='+ISNULL(CONVERT(VARCHAR,@SalesAccount),0)+' ,
					AliasName =N'''+isnull(@AliasName,'')+''' 
					WHERE AccountID='+convert(nvarchar,@NodeID)
					print @SQL
					EXEC  (@SQL)
					
				end
				else if(@COSTCENTERID=3)
				begin
				if( @IsCode is not null and @IsCode =0)
					set @NodeID= (Select  top 1 ProductID from INV_Product where ProductName=@AccountName) 
				else
					set @NodeID= (Select  top 1 ProductID from INV_Product where ProductCode=@AccountCode) 
					
					set @AccountCode= (Select top 1 ProductCode from INV_Product where ProductID=@NodeID)
				  	SET @SQL=@SQL+' ProductCode= N'''+ISNULL(@AccountCode,'')+''', ProductName=N'''+@AccountName+''',
					ProductTypeID = '+ISNULL(convert(NVARCHAR,@TypeID),1)+', ValuationID = '+ISNULL(convert(NVARCHAR,@ValuationID),0)+',
					AliasName =N'''+isnull(@AliasName,'')+''' 
					WHERE ProductID='+convert(nvarchar,@NodeID) 
					EXEC  (@SQL)
					 
				end
				else if(@COSTCENTERID=51 or @COSTCENTERID=83)
				begin
				IF @COSTCENTERID=83
				BEGIN
						if( @IsCode is not null and @IsCode =0)
						set @NodeID= (Select  top 1 CustomerID from CRM_CUSTOMER where CustomerName=@AccountName) 
					else
						set @NodeID= (Select  top 1 CustomerID from CRM_CUSTOMER where CustomerCode=@AccountCode) 
						
						set @AccountCode= (Select CustomerCode from CRM_CUSTOMER where CustomerID=@NodeID)
				END	
				  	SET @SQL=@SQL+' CustomerCode= N'''+ISNULL(@AccountCode,'')+''', CustomerName=N'''+@AccountName+''',
					CustomerTypeID = '+ISNULL(convert(NVARCHAR,@TypeID),1)+',  
					AliasName =N'''+isnull(@AliasName,'')+''' 
					WHERE CustomerID='+convert(nvarchar,@NodeID)
					EXEC  (@SQL)
					
				end
				else if(@COSTCENTERID=65)
				begin
				 
				IF @COSTCENTERID=65
				BEGIN 
					set @NodeID= (Select  top 1 ContactID from Com_Contacts where Company=@AccountName) 
					set @AccountCode= (Select FirstName from Com_Contacts where ContactID=@NodeID)
				END 
				  	SET @SQL=@SQL+' FirstName= N'''+ISNULL(@AccountCode,'')+''', Company=N'''+@AccountName+''',					
					MiddleName =N'''+isnull(@AliasName,'')+''' 
					WHERE ContactID='+convert(nvarchar,@NodeID)				
				  
					EXEC  (@SQL)
					
				end
				else
				begin
					--set @NodeID= (Select NodeID from INV_Product where Name=@AccountName) 
				  	SET @SQL=@SQL+' Name=N'''+@AccountName+''',
					 TypeID = '+ISNULL(convert(NVARCHAR,@TypeID),7)+', 
					CreditDays ='+ISNULL(CONVERT(VARCHAR,@CreditDays),0)+',CreditLimit ='+ISNULL(CONVERT(VARCHAR,@CreditLimit),0)+',
					DebitDays = '+ISNULL(CONVERT(VARCHAR,@DebitDays),0)+', DebitLimit =-'+ISNULL(CONVERT(VARCHAR,@DebitLimit),0)+',
					PurchaseAccount='+ISNULL(CONVERT(VARCHAR,@PurchaseAccount),0)+',SalesAccount='+ISNULL(CONVERT(VARCHAR,@SalesAccount),0)+' ,
					AliasName =N'''+isnull(@AliasName,'')+''' 
					WHERE NodeID in (select Nodeid from '+convert(nvarchar,@Table)+' where Name='''+@AccountName+''
					EXEC  (@SQL)
				
				end
				 
			END
			
			if @COSTCENTERID=65
			BEGIN 
			 
				if(@IsUpdate=0 or @DUPNODENO=0)
				begin
					INSERT INTO Com_ContactsExtended([ContactID],[CreatedBy],[CreatedDate])
					VALUES(@NodeID, @UserName, @Dt)

					--Handling of CostCenter Costcenters Extrafields Table
					--	INSERT INTO ACC_AccountCostCenterMap ([AccountID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
					--	VALUES(@NodeID, @UserName, @Dt, @CompanyGUID,newid())

					INSERT INTO COM_CCCCDATA (CostCenterID,NodeID,[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
					VALUES(65,@NodeID, @UserName, @Dt, @CompanyGUID,newid())
				end
				 
				 
				if @ExtraFields is not null and @ExtraFields<>''
				begin
				print @ExtraFields
					--select @NodeID, @Table, @ExtraFields 
					set @SQL=''
					set @SQL='update '+@Table+' set '+@ExtraFields+ ' where [CONTACTID]='+convert(nvarchar,@NodeID)
					print @SQL
					exec (@SQL)
					--select @SQL
				end
				
				if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''
				begin
					set @SQL='update  dbo.Com_ContactsExtended
					set '+@ExtraUserDefinedFields+ '  where [ContactID]='+convert(nvarchar,@NodeID)
					print @SQL
					exec (@SQL)
				end 
				 
				if @CostCenterFields is not null and @CostCenterFields<>''
					begin
					 
					--set @SQL='update ACC_AccountCostCenterMap 
					--set '+@CostCenterFields+ 'where [AccountID]='+convert(nvarchar,@NodeID)

					set @SQL='update COM_CCCCDATA 
					set '+@CostCenterFields+ ' where [NodeID]='+convert(nvarchar,@NodeID) + ' AND CostCenterID = 65 '
					 
					exec (@SQL)
				end
			
			
			 
					 if (@Customerdata is not null and @Customerdata<>'')
					 begin
					 
					 
			 			DECLARE @TblCustomer TABLE(ID int identity(1,1), GroupName nvarchar(50),CostCenterID Bigint)
						Declare @CustomerID int,@cname nvarchar(max)
						
						set @Customerdata ='<XML><Row '+ @Customerdata+' Action=''NEW''  /></XML>'
		 				 SET @CustomersXML =@Customerdata
		 				 -- select @Substitutes, @NodeID
						INSERT INTO @TblCustomer(GroupName,CostCenterID)
						SELECT X.value('@CustomerName','NVARCHAR(300)'), X.value('@CCID','NVARCHAR(300)')  							 
						FROM @CustomersXML.nodes('/XML/Row') as Data(X)
						
					
						
						IF ((SELECT CostCenterID FROM @TblCustomer )=83)--INSERT CONTACT FOR CUSTOMER
						BEGIN
							select @CustomerID=isnull(customerID,0) from CRM_CUSTOMER with(Nolock) where customername=
							(select top 1 GroupName from @TblCustomer)
							IF @CustomerID=0 or @CustomerID is null
							BEGIN
							 
									select @cname=GroupName from @TblCustomer  
									EXEC @return_value = [dbo].[spcRM_SetCustomer]
														@CustomerID = 0,@CustomerCode = @cname,@CustomerName=@cname, 
														@StatusID=0,@AccountID=0,@SelectedNodeID=0,@IsGroup=0,@ContactsXML=NULL,
														@CompanyGUID=@COMPANYGUID,@ActivityXml=null,@FromImport=1,@GUID='GUID',@UserName=@USERNAME,@UserID=@USERID
														
							 
														--@return_value
												 		set @SQL=''
							set @SQL='update '+@Table+' set Featureid=83, FeaturePK='+convert(nvarchar(200),@return_value)+'
								where [ContactID]='+convert(nvarchar,@NodeID)
								print @SQL
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
							select @CustomerID=isnull(AccountID,0) from ACC_Accounts with(Nolock) where AccountName=
							(select top 1 GroupName from @TblCustomer)
									select @cname=GroupName from @TblCustomer  	
								IF @CustomerID=0 or @CustomerID is null
								BEGIN	
							 		EXEC	@return_value = [dbo].[spACC_SetAccount]
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
												--@return_value
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
											PRINT @SQL
										EXEC(@SQL)
									end
							
						END   
					end
				
			END
			if(@COSTCENTERID=2)
			begin
			 if(@IsUpdate=0 or @DUPNODENO=0)
				begin
					INSERT INTO [ACC_AccountsExtended]([AccountID],[CreatedBy],[CreatedDate])
					VALUES(@NodeID, @UserName, @Dt)

					--Handling of CostCenter Costcenters Extrafields Table
					--	INSERT INTO ACC_AccountCostCenterMap ([AccountID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
					--	VALUES(@NodeID, @UserName, @Dt, @CompanyGUID,newid())

					INSERT INTO COM_CCCCDATA (CostCenterID,NodeID,[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
					VALUES(2,@NodeID, @UserName, @Dt, @CompanyGUID,newid())
				end
	 			if( @IsCode is not null and @IsCode =0)
					set @NodeID= (Select  top 1  AccountID from ACC_Accounts where AccountName=@AccountName) 
				else if(@IsCode=1 and @IsCode is not null)
					set @NodeID= (Select  top 1 AccountID from ACC_Accounts where AccountCode=@AccountCode) 
				if @ExtraFields is not null and @ExtraFields<>''
				begin
					--select @NodeID, @Table, @ExtraFields 
					set @SQL=''
					set @SQL='update '+@Table+' set '+@ExtraFields+ ' where [AccountID]='+convert(nvarchar,@NodeID)
					exec (@SQL)
					--select @SQL
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
					--set @SQL='update ACC_AccountCostCenterMap 
					--set '+@CostCenterFields+ 'where [AccountID]='+convert(nvarchar,@NodeID)

					set @SQL='update COM_CCCCDATA 
					set '+@CostCenterFields+ ' where [NodeID]='+convert(nvarchar,@NodeID) + ' AND CostCenterID = 2 '
					exec (@SQL)
				end

			end
			else if(@COSTCENTERID=3)
			begin
				if(@IsUpdate=0 or @DUPNODENO=0)
				begin
					INSERT INTO INV_ProductExtended  ([ProductID]  ,[CreatedBy]  ,[CreatedDate])  
					VALUES  (@NodeID,@UserName, @Dt)  
					--Handling of CostCenter Costcenters Extrafields Table
					--INSERT INTO INV_ProductCostCenterMap ([ProductID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
					--VALUES(@NodeID, @UserName, @Dt, @CompanyGUID,newid())

					INSERT INTO COM_CCCCDATA (COSTCENTERID , [NodeID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
					VALUES(3,@NodeID, @UserName, @Dt, @CompanyGUID,newid())
				end
				if( @IsCode is not null and @IsCode =0)
					set @NodeID= (Select  top 1 ProductID from INV_Product where ProductName=@AccountName) 
				else if(@IsCode is not null and @IsCode=1)	 
					set @NodeID= (Select  top 1 ProductID from INV_Product where ProductCode=@AccountCode) 
				if @ExtraFields is not null and @ExtraFields<>''
				begin
				set @SQL='update '+@Table+' set '+@ExtraFields+ ' where [ProductID]='+convert(nvarchar,@NodeID)
				exec (@SQL)
				end
				if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''
				begin
				set @SQL='update INV_ProductExtended 
				set '+@ExtraUserDefinedFields+ 'where [ProductID]='+convert(nvarchar,@NodeID)
				exec (@SQL)
				end
				if @CostCenterFields is not null and @CostCenterFields<>''
				begin
				--set @SQL='update INV_ProductCostCenterMap
				--set '+@CostCenterFields+ 'where [ProductID]='+convert(nvarchar,@NodeID)

						set @SQL='update COM_CCCCDATA
				set '+@CostCenterFields+ ' where [NodeID]='+convert(nvarchar,@NodeID) + ' AND CostCenterID = 3 '

				exec (@SQL)
				
				end
				
				if @ProductWiseUOM is not null and @ProductWiseUOM<>'' and @COSTCENTERID=3 --and (@IsUpdate=0 or @DUPNODENO=0)
				begin
					IF((SELECT COUNT(*) FROM [COM_UOM] WHERE PRODUCTID=@NodeID)>0)
					BEGIN 
						UPDATE INV_PRODUCT SET UOMID=1 WHERE PRODUCTID=@NodeID 
						DELETE FROM [COM_UOM] WHERE PRODUCTID=@NodeID
					END
				 set @ProductWiseUOM ='<Data>  <Row RowNo=''1'' UnitiD='''' Action="NEW" MapAction="0" BaseID="-100" '+ @ProductWiseUOM+' /></Data>'
				 DECLARE @UOMDATA XML,@RUOMID INT,@RPRODUCTID INT,@RCOUNT INT,@BASEDATA XML,@BCOUNT INT,@J INT,@BASEID BIGINT,@Conversion FLOAT,
					@MAPACTION2 BIGINT,@ACTION NVARCHAR(300),@UOMID bigint,
					@BASENAME NVARCHAR(300),@TEMPBASEID BIGINT,
					@UNITID INT,@UNAME NVARCHAR(300),@CONVERSIONRATE FLOAT
					
					SET @UOMDATA=@ProductWiseUOM 
					SET @BASEDATA=@ProductWiseUOM 
					DECLARE @TBLBASE TABLE(ID INT IDENTITY(1,1),BASEID BIGINT,BASENAME NVARCHAR(300),MAPACTION INT,CONVERSION float)

					INSERT INTO @TBLBASE
					SELECT    X.value('@BaseID','int'),
					   X.value('@BaseName','NVARCHAR(50)'), X.value('@MapAction','NVARCHAR(50)') , X.value('@Conversion','float') 
					FROM @BASEDATA.nodes('/Data/Row') as Data(X)


					DECLARE @TBLUOM TABLE(ID INT IDENTITY(1,1),UNITID BIGINT,UNITNAME NVARCHAR(300),BASEID BIGINT,
					BASENAME NVARCHAR(300),CONVERSIONRATE FLOAT,MAPACTION INT,ACTION NVARCHAR(300),CONVERSION float)

					INSERT INTO @TBLUOM
					SELECT X.value('@UnitiD','int'), 
					   X.value('@UnitName','NVARCHAR(50)'),X.value('@BaseID','int'),
					   X.value('@BaseName','NVARCHAR(50)'),X.value('@ConversionUnit','float') ,X.value('@MapAction','INT'),X.value('@Action','nvarchar(300)')  
					   , X.value('@Conversion','float') 
					FROM @UOMDATA.nodes('/Data/Row') as Data(X) 

					SELECT @I=1,@RCOUNT=COUNT(*) FROM @TBLUOM
					SELECT @J=1,@BCOUNT=COUNT(*) FROM @TBLBASE
					WHILE @J<=@BCOUNT
					BEGIN
						SELECT  @TEMPBASEID=BASEID,@BASENAME=BASENAME,@Conversion=CONVERSION FROM @TBLBASE WHERE ID=@J
						IF((SELECT ISNULL(COUNT(*),0) FROM [COM_UOM] WHERE   BASEID = @TEMPBASEID)=0)
						BEGIN
							SELECT @BASEID=ISNULL(MAX(BASEID),0) FROM [COM_UOM] WITH(NOLOCK)
							SET @BASEID=@BASEID+1
							INSERT INTO [COM_UOM] (BASEID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
									VALUES   ((@BASEID),@BASENAME,@Conversion,@BASENAME,@Conversion,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@NodeID,1) 
						END		
						ELSE
						BEGIN
							UPDATE [COM_UOM] SET BASENAME=@BASENAME,UNITNAME=@BASENAME WHERE BASEID=@TEMPBASEID AND UNITID=1		
							SET @BASEID=@TEMPBASEID
						END
							
						WHILE @I<=@RCOUNT
						BEGIN
						 
						SELECT @ACTION=ACTION,@MAPACTION2=MAPACTION,@RUOMID=UNITID,@UNAME=UNITNAME,@CONVERSIONRATE=CONVERSIONRATE,@Conversion=CONVERSION FROM @TBLUOM WHERE ID=@I 
						 
						--IF(@TEMPBASEID=(SELECT BASEID FROM @TBLUOM WHERE ID=@I))
						BEGIN   
								 IF (@ACTION=LTRIM(RTRIM('NEW')))
								 BEGIN
									If exists(select unitname from Com_uom where BaseID=@BASEID and Unitname=@UNAME AND UnitID>1)
									 begin
										RAISERROR('-124',16,1)
									 end 
									 --SELECT UNIT ID MAX FROM TABLE 
									(SELECT @UNITID=ISNULL(MAX(UNITID),0) FROM [COM_UOM] WITH(NOLOCK))
									
										INSERT INTO [COM_UOM] (BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
												VALUES	   ((@BASEID),@BASENAME,(@UNITID+1),@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),
												@NodeID,1)
										--SET @RUOMID=SCOPE_IDENTITY()				
										 
										 IF @I=1
											SET @UOMID=SCOPE_IDENTITY()
											 --IF @RUOMID=@UOMID
												--SET @UOMID=SCOPE_IDENTITY()
								END	  
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
				if(@IsUpdate=0 or @DUPNODENO=0)
				begin
					INSERT INTO CRM_CustomerExtended([CustomerID],[CreatedBy],[CreatedDate])
					VALUES(@NodeID, @UserName, @Dt)

					--Handling of CostCenter Costcenters Extrafields Table
					--	INSERT INTO ACC_AccountCostCenterMap ([AccountID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
					--	VALUES(@NodeID, @UserName, @Dt, @CompanyGUID,newid())

					INSERT INTO COM_CCCCDATA (CostCenterID,NodeID,[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
					VALUES(83,@NodeID, @UserName, @Dt, @CompanyGUID,newid())
				end
				if( @IsCode is not null and @IsCode =0)
					set @NodeID= (Select  top 1 CustomerID from crm_customer where CustomerName=@AccountName) 
				else if(@IsCode=1 and @IsCode is not null)
					set @NodeID= (Select  top 1 CustomerID from crm_customer where CustomerCode=@AccountCode) 
				 
					
				if @ExtraUserDefinedFields is not null and @ExtraUserDefinedFields<>''
				begin
					set @SQL='update  dbo.CRM_CustomerExtended
					set '+@ExtraUserDefinedFields+ '  where [CustomerID]='+convert(nvarchar,@NodeID)
					print @SQL
					exec (@SQL)
				end 
			 
				if @CostCenterFields is not null and @CostCenterFields<>''
					begin
					 
					--set @SQL='update ACC_AccountCostCenterMap 
					--set '+@CostCenterFields+ 'where [AccountID]='+convert(nvarchar,@NodeID)

					set @SQL='update COM_CCCCDATA 
					set '+@CostCenterFields+ ' where [NodeID]='+convert(nvarchar,@NodeID) + ' AND CostCenterID = 83 '
					 
					exec (@SQL)
				end
				 
			
				 IF @AddressXML<>'' AND @AddressXML IS NOT NULL and @IsAddress=1
						EXEC spCOM_SetAddress 83,@NodeID,@AddressXML,@UserName  
			
				 IF @AddressXML<>'' AND @AddressXML IS NOT NULL and @IsAddress=0
				 begin
					declare @TempXML xml, @t nvarchar(MAX) 
					set @TempXML=@AddressXML 
					SELECT  @t=Convert(nvarchar(MAX),A.query('/Data/Rows'))
					FROM @TempXML.nodes('/Data/Rows') AS DATA(A) 
					if len(@t)>0
					BEGIN 
						set @t='<Data>'+replace(@t,'Rows','Row')+'</Data>'
						print @t
						EXEC spCOM_SetFeatureWiseContacts 83,@NodeID,1,@t,@UserName,@Dt,@LangID
						set @t=''
						SELECT  @t=Convert(nvarchar(MAX),A.query('/Data/Row')) FROM @TempXML.nodes('/Data/Row') AS DATA(A) 
						set @t='<Data>'+@t+'</Data>'
						EXEC spCOM_SetFeatureWiseContacts 83,@NodeID,2,@t,@UserName,@Dt,@LangID 
					END	
					else
						EXEC spCOM_SetFeatureWiseContacts 83,@NodeID,2,@AddressXML,@UserName,@Dt,@LangID
				 END	
			END 
			else if (@COSTCENTERID<>65) 
			begin
			--Handling of CostCenter Costcenters Extrafields Table
				if(@IsUpdate=0 or @DUPNODENO=0)
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
				set '+@CostCenterFields+ 'where [NodeID]='+convert(nvarchar,@NodeID)
				exec (@SQL)
				end

			end		
			
			 
			if(@COSTCENTERID<>3)
			begin
			
				if(@IsUpdate=0 or @DUPNODENO=0)
				begin
					--INSERT PRIMARY CONTACT
					INSERT COM_Address
					([AddressTypeID]
					,[FeatureID]
					,[FeaturePK] 
					,[CompanyGUID]
					,[GUID] 
					,[CreatedBy]
					,[CreatedDate]
					)
					VALUES
					(1
					,@CostCenterId
					,@NodeID,@CompanyGUID
					,NEWID()
					,@UserName,@Dt
					) 
				end
				
				if(@PrimaryContactQuery is not null and @PrimaryContactQuery<>'')
				begin
					set @SQL='update COM_Address
					SET '+@PrimaryContactQuery+' WHERE [AddressTypeID] = 1 AND [FeaturePK]='+convert(nvarchar,@NodeID)+' and [FeatureID]='+convert(nvarchar,@CostCenterId)
					exec(@SQL)
				end 

				INSERT INTO COM_Address_History(AddressID,AddressTypeID,FeatureID,FeaturePK,ContactPerson,CostCenterID,  
				Address1,Address2,Address3,  
				City,State,Zip,Country,  
				Phone1,Phone2,Fax,Email1,Email2,URL,  
				GUID,CreatedBy,CreatedDate , AddressName)
				SELECT AddressID,AddressTypeID,FeatureID,FeaturePK,ContactPerson,CostCenterID,  
				Address1,Address2,Address3,  
				City,State,Zip,Country,  
				Phone1,Phone2,Fax,Email1,Email2,URL,  
				GUID,CreatedBy,CreatedDate , AddressName
				FROM COM_Address WITH(NOLOCK)
				WHERE FeatureID=@CostCenterId AND FeaturePK=@NodeID
			end 
			IF (@ProductImage IS NOT NULL AND @ProductImage<>'') --ADDED CONDITION BY HAFEEZ TO IMPORT PRODUCT IMAGE
			BEGIN
				 
				SET @ProductImage='<XML><Row '+ @ProductImage+' Action=''NEW''  /></XML>' 
				 
				SET @ProductImageXML=@ProductImage 
				 
				--IF PRODUCT ALREADY CONTAINS IMAGE THEN DELETE THE RECORD 
				DELETE FROM COM_Files WHERE FeatureID=3 AND FeaturePK=@NodeID AND IsProductImage=1
				
				INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
				FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,
				GUID,CreatedBy,CreatedDate)
				SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),
				X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),3,3,@NodeID,
				X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt
				FROM @ProductImageXML.nodes('/XML/Row') as Data(X) 	
				WHERE X.value('@Action','NVARCHAR(10)')='NEW'
				
				 
				 
			END
			
			End Try
			 Begin Catch
				if(@IsProductVehicle is not null and @IsProductVehicle=1 and ERROR_MESSAGE()='-112')
				set @failCount=@failCount
				else
				set @failCount=@failCount+1
			end Catch
			 
			set @I=@I+1

	end

COMMIT TRANSACTION  
--ROLLBACK TRANSACTION  


if(@COSTCENTERID=3)
begin
	SET @SQL='SELECT ProductID NodeID,ProductName Name FROM '+@Table+' WITH(nolock)where ProductName in ( 
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
	set @NodeidXML='set @NodeID= (select top 1 Nodeid from '+convert(nvarchar,@Table)+' where Name='''+@AccountName+''')'
else if (@IsCode is not null and @IsCode=1 and @COSTCENTERID>50000) 
	set @NodeidXML='set @NodeID= (select top 1 Nodeid from '+convert(nvarchar,@Table)+' where Code='''+@AccountCode+''')'
exec sp_executesql @NodeidXML, @str, @NodeID OUTPUT 	

 
IF(@CCMapXML <> '' AND @CCMapXML IS NOT NULL and @NodeID is not null)  
BEGIN   
	EXEC [spCOM_SetCCCCMap] @COSTCENTERID,@NodeID,@CCMapXML,@UserName,@LangID
END  	 
 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
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
