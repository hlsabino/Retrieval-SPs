USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportProductWithMulitpleUOM]
	@XML [nvarchar](max),
	@CCMapXML [nvarchar](max) = '',
	@ProductUOM [nvarchar](max) = '',
	@COSTCENTERID [bigint],
	@IsDuplicateNameAllowed [bit],
	@IsCodeAutoGen [bit],
	@IsOnlyName [bit],
	@IsProductVehicle [bit] = NULL,
	@IsUpdate [bit] = 0,
	@IsCode [bit] = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON	

  
		--Declaration Section
		DECLARE	@return_value int,@failCount int
		DECLARE @NodeID bigint, @Table NVARCHAR(50),@SQL NVARCHAR(max),@ParentGroupName NVARCHAR(200),@PK NVARCHAR(50)
		DECLARE @AccountCode nvarchar(max),@GUID nvarchar(max),@AccountName nvarchar(max),@AliasName nvarchar(max),@CodePrefix nvarchar(max),@CodeNumber nvarchar(max)
        DECLARE @StatusID int,@ExtraFields NVARCHAR(max),@ExtraUserDefinedFields NVARCHAR(max),@CostCenterFields NVARCHAR(max),@PrimaryContactQuery nvarchar(max)
        DECLARE @LinkFields NVARCHAR(MAX), @LinkOption NVARCHAR(MAX), @Substitutes NVARCHAR(MAX),@ProductWiseUOM NVARCHAR(MAX)
		DECLARE @SelectedNode bigint, @IsGroup bit,@multiBarcodes NVARCHAR(MAX)
        DECLARE @CreditDays int, @CreditLimit float
        DECLARE @PurchaseAccount bigint,@Purchase nvarchar(max)
        DECLARE @SalesAccount bigint,@Sales nvarchar(max)
        DECLARE @DebitDays int, @DebitLimit float
		DECLARE @IsBillwise bit, @TypeID int, @ValuationID   int,@Dt float
		DECLARE @Make nvarchar(400),@Model nvarchar(400),@Year nvarchar(400),@Variant nvarchar(400),@Segment nvarchar(400),@VehicleID bigint
		DECLARE @tempCode NVARCHAR(max),@DUPLICATECODE NVARCHAR(300),@DUPNODENO INT,@PARENTCODE NVARCHAR(max)
		DECLARE @tempName NVARCHAR(max),@DUPLICATEName NVARCHAR(300), @DUPNODENOCODE INT
		DECLARE @TempGuid NVARCHAR(max),@HasAccess BIT,@DATA XML,@Cnt INT,@I INT, @CCID INT, @SubstitutesXML XML
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
		ELSE IF(@COSTCENTERID=51)
			SET @PK='CustomerID'
		ELSE
			SET @PK='NodeID'
			 
		-- Create Temp Table
		DECLARE  @temptbl TABLE(ID int identity(1,1),
           [AccountCode] nvarchar(500)
           ,[AccountName] nvarchar(max)
           ,[AliasName] nvarchar(max)
           ,[CodePrefix] nvarchar(max)
           ,[CodeNumber] nvarchar(max)
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
		   PrimaryContactQuery nvarchar(max), LinkFields nvarchar(max), LinkOption nvarchar(max), Substitutes NVARCHAR(MAX)   
		   ,Make nvarchar(400),Model nvarchar(400),Year nvarchar(400),Variant nvarchar(400),Segment nvarchar(400),VehicleID int, ProductWiseUOM nvarchar(Max))

	 	--SELECT  	X.value('@AccountCode','nvarchar(500)')
      --     ,X.value('@AccountName','nvarchar(max)') from @DATA.nodes('/XML/Row') as Data(X)


		INSERT INTO @temptbl
           ([AccountCode]
           ,[AccountName]
           ,[AliasName]
           ,[CodePrefix]
           ,[CodeNumber]
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
			,ValuationID,ExtraFields ,ExtraUserDefinedFields ,CostCenterFields,PrimaryContactQuery,LinkFields, LinkOption, Substitutes
			,Make ,Model ,Year ,Variant ,Segment,VehicleID,ProductWiseUOM )          
		SELECT
			X.value('@AccountCode','nvarchar(500)')
           ,X.value('@AccountName','nvarchar(max)')
           ,isnull(X.value('@AliasName','nvarchar(max)'),'')
           ,isnull(X.value('@CodePrefix','nvarchar(max)'),'')
           ,isnull(X.value('@CodeNumber','nvarchar(max)'),'')
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
			,isnull(X.value('@Substitutes','nvarchar(max)'),'')
			,X.value('@Make','nvarchar(400)'),X.value('@Model','nvarchar(400)'),X.value('@Year','nvarchar(400)')
			,X.value('@Variant','nvarchar(400)'),X.value('@Segment','nvarchar(400)'),X.value('@VehicleID','int')
			,X.value('@ProductWiseUOM','nvarchar(MAX)')
 		from @DATA.nodes('/XML/Row') as Data(X)
		SELECT @I=1, @Cnt=count(ID) FROM @temptbl 
		set @failCount=0
		WHILE(@I<=@Cnt)  
		BEGIN 
				 	select @AccountCode    = AccountCode 
					,@AccountName    =  AccountName  
					,@AliasName    = AliasName 
					,@CodePrefix    = CodePrefix 
					,@CodeNumber    = CodeNumber 
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
					@Substitutes=Substitutes,
					@VehicleID=VehicleID,@Make=Make ,@Model =Model ,@Year =Year ,@Variant =Variant ,@Segment=Segment
					from  @temptbl where ID=@I

		if(@IsOnlyName=1 or @StatusID is null)
		begin
			select @StatusID=StatusID from COM_Status WITH(NOLOCK) where CostCenterID=@COSTCENTERID and Status='Active'
		end

		if(@Purchase is not null and @Purchase<>'')
		begin
			select @PurchaseAccount=AccountID from ACC_Accounts WITH(NOLOCK) where AccountName=@Purchase
		end
		else
		begin
			set @PurchaseAccount=0
		end
		 
		if(@Sales is not null and @Sales<>'')
		begin
			select @SalesAccount=AccountID from ACC_Accounts WITH(NOLOCK) where AccountName=@Sales
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
		else if(@COSTCENTERID=51)
			SET @DUPLICATECODE=@DUPLICATECODE+'CustomerID'
		else if(@COSTCENTERID=71)
			SET @DUPLICATECODE=@DUPLICATECODE+'ResourceID'
		else
			SET @DUPLICATECODE=@DUPLICATECODE+'NodeID'
						
		IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0
		BEGIN			
					SET @tempName=' @DUPNODENO INT OUTPUT' 	
			
					SET @DUPLICATEName =@DUPLICATECODE

					SET @DUPLICATEName=@DUPLICATEName+'  from '+@Table+' WITH(NOLOCK) WHERE '
					if(@COSTCENTERID=2)
						SET @DUPLICATEName=@DUPLICATEName+'AccountName'
					else if(@COSTCENTERID=3)
						SET @DUPLICATEName=@DUPLICATEName+'ProductName'
					else if(@COSTCENTERID=71)
						SET @DUPLICATEName=@DUPLICATEName+'ResourceName'
					else if(@COSTCENTERID=51)
						SET @DUPLICATEName=@DUPLICATEName+'CustomerName'
					else
						SET @DUPLICATEName=@DUPLICATEName+'NAME'
 
					SET @DUPLICATEName=@DUPLICATEName+' ='''+@AccountName+''' ' 
					
					 
		END 
	 
		SET @DUPLICATECODE=@DUPLICATECODE+'  from '+@Table+' WITH(NOLOCK) WHERE '
		if(@COSTCENTERID=2)
			SET @DUPLICATECODE=@DUPLICATECODE+'AccountCode'
		else if(@COSTCENTERID=3)
			SET @DUPLICATECODE=@DUPLICATECODE+'ProductCode'
		else if(@COSTCENTERID=51)
			SET @DUPLICATECODE=@DUPLICATECODE+'CustomerCode'
		else if(@COSTCENTERID=71)
			SET @DUPLICATECODE=@DUPLICATECODE+'ResourceCode'
		else
			SET @DUPLICATECODE=@DUPLICATECODE+'Code'

		SET @DUPLICATECODE=@DUPLICATECODE+' ='''+@AccountCode+''' ' 
		
		
		EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENOCODE OUTPUT
		EXEC sp_executesql @DUPLICATEName, @tempName,@DUPNODENO OUTPUT
	
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
					else if(@COSTCENTERID=51)
						SET @DUPLICATECODE=@DUPLICATECODE+'CustomerID'
					else if(@COSTCENTERID=71)
						SET @DUPLICATECODE=@DUPLICATECODE+'ResourceID'
					else
						SET @DUPLICATECODE=@DUPLICATECODE+'NodeID'
 
					SET @DUPLICATECODE=@DUPLICATECODE+'='+CONVERT(VARCHAR,@SelectedNode)+' '
				   EXEC sp_executesql @DUPLICATECODE, @tempCode,@PARENTCODE OUTPUT  
				end
				else
					set @ParentCode=''
		 
				--CALL AUTOCODEGEN
				EXEC [spCOM_SetCode] @CostCenterId,@ParentCode,@AccountCode OUTPUT
				
			END
		
			IF @AccountCode IS NULL OR @AccountCode=''
			BEGIN
				SET @DUPLICATECODE=' SELECT @Code=MAX('
					if(@COSTCENTERID=2)
						SET @DUPLICATECODE=@DUPLICATECODE+'AccountID'
					else if(@COSTCENTERID=3)
						SET @DUPLICATECODE=@DUPLICATECODE+'ProductID'
					else if(@COSTCENTERID=51)
						SET @DUPLICATECODE=@DUPLICATECODE+'CustomerID'
					else if(@COSTCENTERID=71)
						SET @DUPLICATECODE=@DUPLICATECODE+'ResourceID'
					else  
						SET @DUPLICATECODE=@DUPLICATECODE+'NodeID'
 
					SET @DUPLICATECODE=@DUPLICATECODE+')+1 FROM '+@Table+' WITH(NOLOCK) '
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
			else if(@COSTCENTERID=51)
				SET @SQL=@SQL+'CustomerName'			
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
 
		 	-- Insert statements for procedure here 
		 	if @IsUpdate=0 and @DUPNODENO=0
		 	begin 
		 		SET @SQL=@SQL+' INSERT INTO '+@Table
						+'  (StatusID,'
						if(@COSTCENTERID=2)
							SET @SQL=@SQL+'AccountCode,AccountName,AccountTypeID,IsBillwise,CreditDays,CreditLimit,DebitDays, DebitLimit, PurchaseAccount,SalesAccount,AliasName'
						else if(@COSTCENTERID=3)
							SET @SQL=@SQL+'ProductCode,ProductName,ProductTypeID,ValuationID,AliasName,CodePrefix,CodeNumber'
						else if(@COSTCENTERID=71)
							SET @SQL=@SQL+'ResourceCode,ResourceName,ResourceTypeID'
						else if(@COSTCENTERID=51)
							SET @SQL=@SQL+'CustomerCode,CustomerName,CustomerTypeID, Firstname, AliasName'
						else
							SET @SQL=@SQL+'[Code],[Name],CreditDays,CreditLimit,DebitDays, DebitLimit, PurchaseAccount,SalesAccount,AliasName'
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
							SET @SQL=@SQL+''+convert(NVARCHAR,@TypeID)+','+convert(NVARCHAR,@IsBillwise)+',' +CONVERT(VARCHAR,@CreditDays)+','+CONVERT(VARCHAR,@CreditLimit)+','+CONVERT(VARCHAR,@DebitDays)+','+CONVERT(VARCHAR,@DebitLimit)+','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+',N'''+@AliasName+''','
						else if(@COSTCENTERID=3)
							SET @SQL=@SQL+''+convert(NVARCHAR,@TypeID)+','+convert(NVARCHAR,@ValuationID)+','''+@AliasName+''','''+@CodePrefix+''','''+@CodeNumber+''','
						else if(@COSTCENTERID=71)
							SET @SQL=@SQL+'1, '
						else if(@COSTCENTERID=51)
							SET @SQL=@SQL+'1, '''+@AccountName+''','''+@AliasName+''','
						else
							SET @SQL=@SQL+CONVERT(VARCHAR,@CreditDays)+','+CONVERT(VARCHAR,@CreditLimit)+','+CONVERT(VARCHAR,@DebitDays)+','+CONVERT(VARCHAR,@DebitLimit)+','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+','''+@AliasName+''','
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
				
				if(@COSTCENTERID=3)
				begin
				if( @IsCode is not null and @IsCode =0)
					set @NodeID= (Select  top 1 ProductID from INV_Product WITH(NOLOCK) where ProductName=@AccountName) 
				else
					set @NodeID= (Select  top 1 ProductID from INV_Product WITH(NOLOCK) where ProductCode=@AccountCode) 
					
					set @AccountCode= (Select top 1 ProductCode from INV_Product WITH(NOLOCK) where ProductID=@NodeID)
				  	SET @SQL=@SQL+' ProductCode= N'''+ISNULL(@AccountCode,'')+''', ProductName=N'''+@AccountName+''',
					ProductTypeID = '+ISNULL(convert(NVARCHAR,@TypeID),1)+', ValuationID = '+ISNULL(convert(NVARCHAR,@ValuationID),0)+',
					AliasName =N'''+isnull(@AliasName,'')+''' 
					WHERE ProductID='+convert(nvarchar,@NodeID) 
					EXEC  (@SQL)
					 
				end
			END 
			
			if(@COSTCENTERID=3)
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
					set @NodeID= (Select  top 1 ProductID from INV_Product WITH(NOLOCK) where ProductName=@AccountName) 
				else if(@IsCode is not null and @IsCode=1)	 
					set @NodeID= (Select  top 1 ProductID from INV_Product WITH(NOLOCK) where ProductCode=@AccountCode) 
				if @ExtraFields is not null and @ExtraFields<>''
				begin
				set @SQL='update '+@Table+' set '+@ExtraFields+ ' where [ProductID]='+convert(nvarchar,@NodeID)
				exec (@SQL)
				end
				-- select @ProductUOM
				
				if @ProductUOM is not null and @ProductUOM<>'' and @COSTCENTERID=3 --and (@IsUpdate=0 or @DUPNODENO=0)
				begin
					declare @BARCODE NVARCHAR(100),@BarKey BIGINT, @BarDim int 
					IF((SELECT COUNT(*) FROM [COM_UOM] WITH(NOLOCK) WHERE PRODUCTID=@NodeID)>0)
					BEGIN 
						UPDATE INV_PRODUCT SET UOMID=1 WHERE PRODUCTID=@NodeID 
						DELETE FROM [COM_UOM] WHERE PRODUCTID=@NodeID
					END
					DECLARE @UOMDATA XML,@RUOMID INT,@RPRODUCTID INT,@RCOUNT INT,@BASEDATA XML,@BCOUNT INT,@J INT,@BASEID BIGINT,@Conversion FLOAT,
					@MAPACTION2 BIGINT,@ACTION NVARCHAR(300),@UOMID bigint,
					@BASENAME NVARCHAR(300),@TEMPBASEID BIGINT,
					@UNITID INT,@UNAME NVARCHAR(300),@CONVERSIONRATE FLOAT
					
					SET @UOMDATA=@ProductUOM 
					SET @BASEDATA=@ProductUOM 
					DECLARE @TBLBASE TABLE(ID INT IDENTITY(1,1),BASEID BIGINT,BASENAME NVARCHAR(300),MAPACTION INT,CONVERSION float,BaseBarcode NVARCHAR(100),BaseBarKey BIGINT,MultiBarcode NVARCHAR(max))
					declare @TblUomBarcodes TABLE(Barcode NVARCHAR(300))
					INSERT INTO @TBLBASE (BASENAME,BASEID,MAPACTION,CONVERSION,BaseBarcode,BaseBarKey,MultiBarcode)
					SELECT   distinct( X.value('@BaseName','NVARCHAR(50)')), 
					 X.value('@BaseID','int'), X.value('@MapAction','NVARCHAR(50)') , X.value('@Conversion','float') , 
					  X.value('@BaseBarcode','NVARCHAR(100)'),isnull(X.value('@BaseBarKey','bigint'),0)
					  , X.value('@BaseMultiBarcode','NVARCHAR(MAX)')
					FROM @BASEDATA.nodes('/Data/Row') as Data(X)
 
					DECLARE @TBLUOM TABLE(ID INT IDENTITY(1,1),UNITID BIGINT,UNITNAME NVARCHAR(300),BASEID BIGINT,
					BASENAME NVARCHAR(300),CONVERSIONRATE FLOAT,MAPACTION INT,ACTION NVARCHAR(300),CONVERSION float,Barcode NVARCHAR(100),BarKey BIGINT,MultiBarcode NVARCHAR(max))

					INSERT INTO @TBLUOM
						SELECT X.value('@UnitiD','int'), 
						   X.value('@UnitName','NVARCHAR(50)'),X.value('@BaseID','int'),
						   X.value('@BaseName','NVARCHAR(50)'),X.value('@ConversionUnit','float') ,X.value('@MapAction','INT'),X.value('@Action','nvarchar(300)')  
						   , X.value('@Conversion','float') , X.value('@Barcode','NVARCHAR(100)'),isnull(X.value('@BarKey','bigint'),0)
						   , X.value('@MultiBarcode','NVARCHAR(MAX)')
						FROM @UOMDATA.nodes('/Data/Row') as Data(X) 
						where X.value('@UnitName','NVARCHAR(50)') is not null and X.value('@UnitName','NVARCHAR(50)')<>''
						
					declare @BARDIMENSION NVARCHAR(100)
					SELECT @BARDIMENSION=Value FROM COM_CostCenterPreferences with(nolock) where Name='BarcodeDimension' 
					if @BARDIMENSION!='' and isnumeric(@BARDIMENSION)=1 and convert(int,@BARDIMENSION)>50000
						set @BarDim=convert(int,@BARDIMENSION)
					else
						set @BarDim=0


					SELECT @I=1,@RCOUNT=COUNT(*) FROM @TBLUOM
					SELECT @J=1,@BCOUNT=COUNT(*) FROM @TBLBASE
					WHILE @J<=@BCOUNT
					BEGIN
						SELECT  @TEMPBASEID=BASEID,@BASENAME=BASENAME,@Conversion=CONVERSION, @BARCODE=BaseBarcode,@BarKey=BaseBarKey,@multiBarcodes=MultiBarcode FROM @TBLBASE WHERE ID=@J
			
					
						delete from @TblUomBarcodes
						INSERT INTO @TblUomBarcodes
						EXEC SPSplitString @multiBarcodes,','
							
						IF((SELECT ISNULL(COUNT(*),0) FROM [COM_UOM] WITH(NOLOCK) WHERE   BASEID = @TEMPBASEID)=0)
						BEGIN
							
							SELECT @BASEID=ISNULL(MAX(BASEID),0) FROM [COM_UOM] WITH(NOLOCK)
							SET @BASEID=@BASEID+1
							INSERT INTO [COM_UOM] (BASEID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
									VALUES((@BASEID),@BASENAME,@Conversion,@BASENAME,@Conversion,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@NodeID,1) 
							SET @UOMID=SCOPE_IDENTITY() 
							 
							If exists(select Barcode from INV_ProductBarcode with(nolock) where BARCODE=@BARCODE and @BARCODE is not null and @BARCODE<>'')
								RAISERROR('-130',16,1) 
							
							If exists(select a.Barcode from INV_ProductBarcode a with(nolock)
									join @TblUomBarcodes b on a.BARCODE=b.Barcode)
								RAISERROR('-130',16,1) 
							
							if(@BARCODE is null)
							begin
								set @BARCODE=''
								set @BarKey=0
							end
						 	
							insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
							VALUES (@BARCODE,@BarKey,0,@UOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE()))
							
								
							insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
							select Barcode,0,0,@UOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE())
							from @TblUomBarcodes
						END		
						ELSE
						BEGIN
							UPDATE [COM_UOM] SET BASENAME=@BASENAME,UNITNAME=@BASENAME WHERE BASEID=@TEMPBASEID AND UNITID=1		
							SET @BASEID=@TEMPBASEID
						END
					
						WHILE @I<=@RCOUNT
						BEGIN 
							SELECT @ACTION=ACTION,@MAPACTION2=MAPACTION,@RUOMID=UNITID,@UNAME=UNITNAME,@CONVERSIONRATE=CONVERSIONRATE,@Conversion=CONVERSION ,
							@BARCODE=Barcode ,@BarKey=BarKey,@multiBarcodes=MultiBarcode FROM @TBLUOM WHERE ID=@I 
							
							delete from @TblUomBarcodes
							INSERT INTO @TblUomBarcodes
							EXEC SPSplitString @multiBarcodes,','
							
							BEGIN   
								
								 IF (@ACTION=LTRIM(RTRIM('NEW')))
								 BEGIN
									If exists(select unitname from Com_uom WITH(NOLOCK) where BaseID=@BASEID and Unitname=@UNAME AND UnitID>1)
									 begin
										RAISERROR('-124',16,1)
									 end 
									 --SELECT UNIT ID MAX FROM TABLE 
									(SELECT @UNITID=ISNULL(MAX(UNITID),0) FROM [COM_UOM] WITH(NOLOCK))
									
									INSERT INTO [COM_UOM] (BaseID,BASENAME,UNITID,UNITNAME,CONVERSION,GUID,CREATEDBY,CREATEDDATE,ProductID,IsProductWise)
											VALUES	   ((@BASEID),@BASENAME,(@UNITID+1),@UNAME,@CONVERSIONRATE,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),
											@NodeID,1)
									SET @RUOMID=SCOPE_IDENTITY()	
								
									If exists(select Barcode from INV_ProductBarcode with(nolock) where BARCODE=@BARCODE and @BARCODE is not null and @BARCODE<>'')
									begin 
										set @failCount=@failCount+1
										RAISERROR('-130',16,1)
									end	
									If exists(select a.Barcode from INV_ProductBarcode a with(nolock)
									join @TblUomBarcodes b on a.BARCODE=b.Barcode)
									begin 
										set @failCount=@failCount+1
										RAISERROR('-130',16,1) 
									END
									
								--	  SELECT @BARCODE, @BARDIMENSION,@ProductUOm
								 	insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
									VALUES (@BARCODE,@BarKey,0,@RUOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE()))
									
									insert into INV_ProductBarcode(Barcode,Barcode_Key,venderID,unitID,productID,COMPANYGUID,GUID,CREATEDBY,CREATEDDATE,MODIFIEDBY,MODIFIEDDATE)
									select Barcode,0,0,@RUOMID,@NodeID,NULL,NEWID(),@USERNAME,CONVERT(FLOAT,GETDATE()),@USERNAME,CONVERT(FLOAT,GETDATE())
									from @TblUomBarcodes
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
 
SET NOCOUNT OFF;   
RETURN @failCount  
END TRY  
BEGIN CATCH  
 
 	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
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
