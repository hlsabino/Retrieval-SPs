USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SetImportData]
	@COSTCENTERID [int],
	@Code [nvarchar](max),
	@Name [nvarchar](max),
	@XML [nvarchar](max),
	@IsUpdate [bit],
	@IsCode [bit],
	@ExtraXML [nvarchar](max),
	@ContractXML [nvarchar](max),
	@PayTermsXML [nvarchar](max) = null,
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
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
  
	DECLARE @return_value int,@Dt float,@ParentName nvarchar(50)     
	DECLARE @HasAccess BIT,@DATA XML,@CCID INT,@UnitID INT, @TenantID INT
	SET @DATA=@XML    
	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date      
	DECLARE @PrntNodeID INT ,@TypeName NVARCHAR(max)
	DECLARE @TenantName NVARCHAR(max),@PropertyID INT ,@PropertyName NVARCHAR(max),@StatusID INT  
	DECLARE @IsGroup BIT,@Parent NVARCHAR(max),@SelectedNodeID INT
	DECLARE @EXTRAFIELDXML XML  

	SET @EXTRAFIELDXML =  @ExtraXML  

	DECLARE @temptblImportProp TABLE(ID int identity(1,1),ExtraFields nvarchar(max),ExtraUserDefinedFields nvarchar(max),CostCenterFields nvarchar(max),PrimaryContactQuery nvarchar(max))  

	INSERT INTO @temptblImportProp(ExtraFields,ExtraUserDefinedFields,CostCenterFields,PrimaryContactQuery)            
	SELECT isnull(X.value('@ExtraFields ','nvarchar(max)'),'')  
	,isnull(X.value('@ExtraUserDefinedFields ','nvarchar(max)'),'')  
	,isnull(X.value('@CostCenterFields','nvarchar(max)'),'')  
	,isnull(X.value('@PrimaryContactQuery','nvarchar(max)'),'')  
	from @EXTRAFIELDXML.nodes('/XML/Row') as Data(X)  

	DECLARE @ExtraFields NVARCHAR(max),@ExtraUserDefinedFields NVARCHAR(max),@CostCenterFields NVARCHAR(max),@PrimaryContactQuery NVARCHAR(max),@UpdateSql NVARCHAR(max)   

	SELECT @ExtraFields=ExtraFields,@ExtraUserDefinedFields=ExtraUserDefinedFields,@CostCenterFields=CostCenterFields,@PrimaryContactQuery = PrimaryContactQuery  
	FROM @temptblImportProp  
    
    IF((@COSTCENTERID = 92 AND @Code='Property Particulars') OR (@COSTCENTERID = 93 AND @Code='Unit Particulars'))  
	BEGIN 
		select @SelectedNodeID=ISNULL(X.value('@ParticularID','INT'),0)
		,@ExtraFields=isnull(X.value('@ExtraFields ','nvarchar(max)'),'')
		from @DATA.nodes('Row') as data(X)  
		
		IF(@COSTCENTERID = 92 )
		BEGIN 
			IF(@IsCode=1)
				SELECT @PropertyID = ISNULL(NodeID,0),@UnitID=0 FROM REN_Property with(nolock) WHERE replace(replace(Code,'(',''),')','')  = replace(replace(@Name,'(',''),')','')
			ELSE
				SELECT @PropertyID = ISNULL(NodeID,0),@UnitID=0 FROM REN_Property with(nolock) WHERE replace(replace(name,'(',''),')','')  =replace(replace(@Name ,'(',''),')','')
		END
		ELSE IF(@COSTCENTERID = 93 )
		BEGIN
			IF(@IsCode=1)
				SELECT @UnitID = ISNULL(UnitID,0),@PropertyID = ISNULL(PropertyID,0) FROM REN_UNITS with(nolock) WHERE replace(replace(Code,'(',''),')','')  = replace(replace(@Name,'(',''),')','')
			ELSE
				SELECT @UnitID = ISNULL(UnitID,0),@PropertyID = ISNULL(PropertyID,0) FROM REN_UNITS with(nolock) WHERE replace(replace(Name,'(',''),')','')  = replace(replace(@Name ,'(',''),')','')
		END
		
		IF(@SelectedNodeID > 0 AND (@PropertyID>0 OR @UnitID>0))    
		BEGIN    
			IF(@IsUpdate=1)
			BEGIN
				IF NOT EXISTS (SELECT * FROM REN_Particulars with(nolock) WHERE ParticularID=@SelectedNodeID AND PropertyID=@PropertyID AND UnitID=@UnitID)
				BEGIN
					insert into REN_Particulars(ParticularID,[PropertyID],[UnitID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])    
					select @SelectedNodeID,@PropertyID,@UnitID,'companyguid',newid(),@UserName,@Dt
				END
			END
			ELSE
			BEGIN
				DELETE FROM REN_Particulars WHERE ParticularID=@SelectedNodeID AND PropertyID=@PropertyID AND UnitID=@UnitID  
				
				insert into REN_Particulars(ParticularID,[PropertyID],[UnitID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])    
				select @SelectedNodeID,@PropertyID,@UnitID,'companyguid',newid(),@UserName,@Dt  
			END
			
			IF(@ExtraFields IS NOT NULL AND @ExtraFields <>'')    
			BEGIN    
				set @UpdateSql='update [REN_Particulars]    
				SET '+@ExtraFields+' [ModifiedBy] ='''+ @UserName    
				+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ParticularID='+convert(nvarchar,@SelectedNodeID)+' AND
				PropertyID='+convert(nvarchar,@PropertyID)+' AND
				UnitID='+convert(nvarchar,@UnitID)     
				exec(@UpdateSql) 
			END
			SET @return_value=1
		END

	END 
	ELSE IF(@COSTCENTERID = 93 AND @Code='Unit Rates')  
	BEGIN 
		select @SelectedNodeID=ISNULL(X.value('@ParticularID','INT'),0)
		,@ExtraFields=isnull(X.value('@ExtraFields ','nvarchar(max)'),'')
		from @DATA.nodes('Row') as data(X)  
		
		IF(@IsCode=1)
			SELECT @UnitID = ISNULL(UnitID,0) FROM REN_UNITS with(nolock) WHERE Code  = @Name
		ELSE
			SELECT @UnitID = ISNULL(UnitID,0) FROM REN_UNITS with(nolock) WHERE Name  = @Name 
		
		IF(@UnitID>0)    
		BEGIN    
			IF(@IsUpdate=1)
			BEGIN
				IF NOT EXISTS (SELECT * FROM REN_Particulars with(nolock) WHERE ParticularID=@SelectedNodeID AND PropertyID=@PropertyID AND UnitID=@UnitID)
				BEGIN
					insert into REN_Particulars(ParticularID,[PropertyID],[UnitID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])    
					select @SelectedNodeID,@PropertyID,@UnitID,'companyguid',newid(),@UserName,@Dt
				END
			END
			ELSE
			BEGIN
				DELETE FROM REN_Particulars WHERE ParticularID=@SelectedNodeID AND PropertyID=@PropertyID AND UnitID=@UnitID  
				
				insert into REN_Particulars(ParticularID,[PropertyID],[UnitID],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])    
				select @SelectedNodeID,@PropertyID,@UnitID,'companyguid',newid(),@UserName,@Dt  
			END
			
			IF(@ExtraFields IS NOT NULL AND @ExtraFields <>'')    
			BEGIN    
				set @UpdateSql='update [REN_Particulars]    
				SET '+@ExtraFields+' [ModifiedBy] ='''+ @UserName    
				+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ParticularID='+convert(nvarchar,@SelectedNodeID)+' AND
				PropertyID='+convert(nvarchar,@PropertyID)+' AND
				UnitID='+convert(nvarchar,@UnitID)     
				exec(@UpdateSql) 
			END
			SET @return_value=1
		END

	END 
	ELSE IF(@COSTCENTERID = 92)  
	BEGIN 
		select @StatusID=ISNULL(X.value('@StatusID','INT'),422)
		,@IsGroup=ISNULL(X.value('@IsGroup','BIT'),0),@Parent =X.value('@ParentID','NVARCHAR(max)')
		from @DATA.nodes('Row') as data(X)  
		
		SET @PropertyID = 0 
		
		if(@IsCode=1)
			SELECT @SelectedNodeID = ISNULL(NodeID,1)FROM REN_Property with(nolock) WHERE Code  = @Parent
		ELSE
			SELECT @SelectedNodeID = ISNULL(NodeID,1) FROM REN_Property with(nolock) WHERE Name  = @Parent 
	
		if @SelectedNodeID is null
			set @SelectedNodeID=0
		
		if(@IsUpdate=1)
		BEGIN
			if(@IsCode=1)
				SELECT @PropertyID = ISNULL(NodeID,0) FROM REN_Property with(nolock) WHERE Code  = @Code
			ELSE
				SELECT @PropertyID = ISNULL(NodeID,0) FROM REN_Property with(nolock) WHERE Name  = @Name
			
			IF @PropertyID > 0
			BEGIN
				IF(@ExtraUserDefinedFields IS NOT NULL AND @ExtraUserDefinedFields <>'')    
				BEGIN    
					set @UpdateSql='update [REN_PropertyExtended]    
					SET '+@ExtraUserDefinedFields+' [ModifiedBy] ='''+ @UserName    
					+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@PropertyID)      
					exec(@UpdateSql)    
				END    
			         
				IF(@CostCenterFields IS NOT NULL AND @CostCenterFields <>'')    
				BEGIN  
					set @UpdateSql='update COM_CCCCDATA      
					SET '+@CostCenterFields+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID =      
					'+convert(nvarchar,@PropertyID) + ' AND CostCenterID = 92'     
					exec(@UpdateSql)      
				END 
			END
		END
		
		IF @PropertyID = 0
		BEGIN	
			EXEC @return_value = [dbo].[spREN_setProperty]  
				@PropertyID = @PropertyID,  
				@Code = @Code,  
				@Name = @Name,  
				@Status = @StatusID,  
				@IsGroup = @IsGroup,  
				@SelectedNodeID = @SelectedNodeID,  
				@DetailsXML = N'', 
				@DepositXML = N'',  
				@UnitXML = N'',  
				@ParkingXML = N'',  
				@CustomFieldsQuery = @ExtraUserDefinedFields,  
				@CustomCostCenterFieldsQuery = @CostCenterFields,  
				@RoleXml = N'',  
				@AttachmentsXML = '',
				@ShareHolderXML = '', 
				@CompanyGUID = N'companyguid',  
				@GUID = N'guid',  
				@UserName = @UserName,  
				@UserID = @UserID,  
				@LangId = @LangID,  
				@RoleID = @RoleID 	
				
				SET @PropertyID=@return_value
		END
		
		IF(@ExtraFields IS NULL)
			SET @ExtraFields=''
		
		SET @ExtraFields=@ExtraFields+'Code=N'''+@Code+''',Name=N'''+@Name+''','
		
		IF(@PropertyID > 0 AND @ExtraFields IS NOT NULL AND @ExtraFields <>'')    
		BEGIN    
			set @UpdateSql='update [REN_Property]    
			SET '+@ExtraFields+' [ModifiedBy] ='''+ @UserName    
			+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@PropertyID)      
			exec(@UpdateSql)   
			
			select @CCID=CCID,@return_value=CCNodeID from [REN_Property] with(nolock) WHERE NodeID=@PropertyID
			if(@CCID IS NOT NULL AND @CCID<>'' AND @CCID>50000 AND @return_value IS NOT NULL AND @return_value>0 and @return_value<>'')
			begin
				Exec [spDOC_SetLinkDimension]
					@InvDocDetailsID=@PropertyID, 
					@Costcenterid=92,         
					@DimCCID=@CCID,
					@DimNodeID=@return_value,
					@UserID=@UserID,    
					@LangID=@LangID  
			end  
		END
		
	END  
	ELSE IF(@COSTCENTERID = 93)  
	BEGIN 
		DECLARE @TempGuid nvarchar(50)    
		select @PropertyName = X.value('@PropertyID','NVARCHAR(max)'),@StatusID=ISNULL(X.value('@Status','INT'),424)
		,@IsGroup=ISNULL(X.value('@IsGroup','BIT'),0),@Parent =X.value('@ParentID','NVARCHAR(max)')
		,@TenantName=X.value('@TenantID','NVARCHAR(max)')
		from @DATA.nodes('Row') as data(X)  
		
		if(@PropertyName is null or @PropertyName='')
		begin
			raiserror('Property mandatory to import Units',16,1)
		end

		SET @PropertyID = 0 
		if(@IsCode=1)
		BEGIN
			SELECT @SelectedNodeID = ISNULL(UnitID,1)FROM REN_UNITS with(nolock) WHERE Code  = @Parent
			SELECT @PropertyID = ISNULL(NodeID,0) FROM REN_Property with(nolock) WHERE Code  = @PropertyName
		END
		ELSE
		BEGIN
			SELECT @SelectedNodeID = ISNULL(UnitID,1) FROM REN_UNITS with(nolock) WHERE Name  = @Parent 
			SELECT @PropertyID = ISNULL(NodeID,0) FROM REN_Property with(nolock) WHERE Name  = @PropertyName 
		END
			
		IF (@PropertyID = 0 OR @PropertyID IS NULL OR @PropertyID = '') --CHECKING FOR PROPERTY EXISTANCE  
		BEGIN   
			EXEC @PropertyID = [dbo].[spREN_setProperty]  
				@PropertyID = 0,  
				@Code = @PropertyName,  
				@Name = @PropertyName,  
				@Status = 422,  
				@IsGroup = 0,  
				@SelectedNodeID = 1,  
				@DetailsXML = '<Row></Row>',  
				@DepositXML = N'',  
				@UnitXML = N'',  
				@ParkingXML = N'',  
				@CustomFieldsQuery = N'',  
				@CustomCostCenterFieldsQuery = N'',  
				@RoleXml = N'',  
				@AttachmentsXML = '', 
				@CompanyGUID = N'companyguid',  
				@GUID = N'guid',  
				@UserName = @UserName,  
				@UserID = @UserID,  
				@LangId = @LangID,  
				@RoleID = @RoleID
		END   
		
		SELECT @TenantID = ISNULL(TenantID,0) FROM REN_TENANT with(nolock) WHERE FirstName  = @TenantName  
		IF @TenantID IS NOT NULL 
			SET @ExtraFields=@ExtraFields+' TenantID='+CONVERT(NVARCHAR,@TenantID)+', '
		
		SET @UnitID=0
		if(@IsUpdate=1)
		begin
			if(@IsCode=1)
				SELECT @UnitID = ISNULL(UnitID,0),@TempGuid=[GUID] FROM REN_UNITS with(nolock) WHERE Code  = @Code
			ELSE
				SELECT @UnitID = ISNULL(UnitID,0),@TempGuid=[GUID] FROM REN_UNITS with(nolock) WHERE Name  = @Name  
		end
		
		EXEC @return_value = [dbo].[spREN_SetUnits]  
			@UNITID = @UnitID,  
			@PROPERTYID = @PropertyID,  
			@CODE = @Code,  
			@NAME = @Name,  
			@STATUSID = @StatusID,  
			@IsGroup = @IsGroup,  
			@SelectedNodeID = @SelectedNodeID,  
			@DETAILSXML = @ContractXML,
			@StaticFieldsQuery = @ExtraFields, 
			@CustomCostCenterFieldsQuery = @ExtraUserDefinedFields,  
			@CustomCCQuery = @CostCenterFields,  
			@AttachmentsXML = '', 
			@UnitRateXML = '',         
			@CompanyGUID = N'companyguid',  
			@GUID = @TempGuid,  
			@UserName = @UserName, 
			@RoleID = @RoleID,  
			@UserID = @UserID,  
			@LangId = @LangID  
	END  
	ELSE IF(@COSTCENTERID = 94)  
	BEGIN 
		select @IsGroup=ISNULL(X.value('@IsGroup','BIT'),0),@Parent=ISNULL(X.value('@ParentID','NVARCHAR(100)'),'')
		from @DATA.nodes('Row') as data(X)  
			
		SET @TenantID = 0 
		if(@IsCode=1)
		BEGIN
			SELECT @SelectedNodeID = ISNULL(TenantID,1) FROM REN_TENANT with(nolock) WHERE TenantCode = @Parent
			if(@IsUpdate=1)
				SELECT @TenantID = ISNULL(TenantID,0) FROM REN_TENANT with(nolock) WHERE TenantCode = @Code
		END
		ELSE
		BEGIN
			SELECT @SelectedNodeID = ISNULL(TenantID,1) FROM REN_TENANT with(nolock) WHERE FirstName  = @Parent 
			if(@IsUpdate=1)
				SELECT @TenantID = ISNULL(TenantID,0) FROM REN_TENANT with(nolock) WHERE FirstName  = @Name 
		END	
   
		EXEC @return_value = [spREN_SetTenant]  
			@TenantID = @TenantID,  
			@Code = @Code,  
			@FirstName = @Name,  
			@TabsDetails = @ExtraFields,   
			@SelectedNodeID = @SelectedNodeID,  
			@IsGroup = @IsGroup,  
			@CustomFieldsQuery =@ExtraUserDefinedFields,  
			@CustomCostCenterFieldsQuery = @CostCenterFields,  
			@AttachmentsXML = '', 
			@AssignCCCCData=@ContractXML,
			@CompanyGUID = 'CompanyGUID',  
			@UserName = @UserName, 
			@WID = 0,
			@RoleID = @RoleID, 
			@UserID = @UserID,  
			@LangID = @LangID  
			SELECT 1
	END
	ELSE IF(@COSTCENTERID = 95)  
	BEGIN 

		DECLARE @UnitName NVARCHAR(max),  @AccountantID INT,  @LandlordID INT    
		DECLARE @ContractDate DATETIME ,@StartDate DATETIME ,@EndDate DATETIME    
		DECLARE @TotalAmount FLOAT, @ContractNumber int , @SalesmanID  INT
		DECLARE @ExpectedEndDate DATETIME,@GracePeriod FLOAT   ,@IsOPening BIT
		set @UnitID =  0    
		SET @PropertyID = 0   
		SET @TenantID = 0  
		SET @IsOPening = 1  
		SET @LandlordID = 0  
		SELECT @PropertyName = X.value('@PropertyName','NVARCHAR(max)') ,@IsOPening=isnull(X.value('@IsOPening','BIT'),1)  , @UnitName= X.value('@UnitName','NVARCHAR(max)')  
		, @TenantName= X.value('@TenantName','NVARCHAR(max)'), @ContractDate= X.value('@ContractDate','DATETIME')  
		, @StartDate= X.value('@StartDate','DATETIME'), @EndDate = X.value('@EndDate','DATETIME')  
		, @TotalAmount = X.value('@TotalAmount','FLOAT')  , @SalesmanID = ISNULL(X.value('@SalesmanID ','INT'),1) ,  @AccountantID = ISNULL(X.value('@AccountantID','INT'),1)   
		, @LandlordID = ISNULL(X.value('@LandlordID','INT')  ,0), @ExpectedEndDate= X.value('@ExpectedEndDate','DATETIME'),@GracePeriod  = ISNULL(X.value('@GracePeriod','FLOAT'),0)
		FROM @DATA.nodes('Row') as data(X)  
		
		if(@IsCode=1)
			SELECT @PropertyID = NodeID FROM REN_Property with(nolock) -- getting property id from existing properties  
			WHERE Code  = @PropertyName  
		else
			SELECT @PropertyID = NodeID FROM REN_Property with(nolock) -- getting property id from existing properties  
			WHERE Name  = @PropertyName  

		IF (@PropertyID = 0 OR @PropertyID IS NULL OR @PropertyID = '')  --CHECKING FOR PROPERTY EXISTANCE  
		BEGIN   
			EXEC @PropertyID = [dbo].[spREN_setProperty]  
				@PropertyID = 0,  
				@Code = @PropertyName,  
				@Name = @PropertyName,  
				@Status = 422,  
				@IsGroup = 0,  
				@SelectedNodeID = 1,  
				@DetailsXML = '<Row></Row>',  
				@DepositXML = N'',  
				@UnitXML = N'',  
				@ParkingXML = N'',  
				@CustomFieldsQuery =N'',  
				@CustomCostCenterFieldsQuery = N'',  
				@RoleXml = N'',  
				@AttachmentsXML = '', 
				@CompanyGUID = N'companyguid',  
				@GUID = N'guid',  
				@UserName = N'admin',  
				@UserID = 1,  
				@LangId = 1  
		END   
		
		if(@IsCode=1)
			SELECT @UnitID = UnitID FROM REN_UNITS with(nolock)-- getting Unit id from existing units  
			WHERE Code  = @UnitName  
		else
			SELECT @UnitID = UnitID FROM REN_UNITS with(nolock)-- getting Unit id from existing units  
			WHERE Name  = @UnitName  

		IF (@UnitID = 0 OR @UnitID IS NULL OR @UnitID = '')  --CHECKING FOR PROPERTY EXISTANCE  
		BEGIN   
			EXEC @UnitID =  spREN_SetUnits   
				@UNITID = 0,  
				@PROPERTYID = @PropertyID,  
				@CODE = @UnitName,  
				@NAME = @UnitName,   
				@STATUSID = 424,  
				@IsGroup = 0,  
				@SelectedNodeID = 1,  

				@DETAILSXML = N'',
				@StaticFieldsQuery = N'', 
				@CustomCostCenterFieldsQuery = N'',  
				@CustomCCQuery = N'',  

				@AttachmentsXML = '', 
				@CompanyGUID = N'companyguid',  
				@GUID = N'guid',  
				@UserName = N'admin',  
				@UserID = 1,  
				@LangId = 1  
		END   
		
		if(@IsCode=1)
			SELECT @TenantID = TenantID FROM REN_TENANT with(nolock) -- getting TENANT id from existing TENANT  
			WHERE TenantCode  = @TenantName  
		else
			SELECT @TenantID = TenantID FROM REN_TENANT with(nolock) -- getting TENANT id from existing TENANT  
			WHERE FirstName  = @TenantName  

		IF (@TenantID = 0 OR @TenantID IS NULL OR @TenantID = '') --CHECKING FOR TENANT EXISTANCE  
		BEGIN   
			EXEC @return_value = [spREN_SetTenant]  
				@TenantID = 0,  
				@Code = @TenantName,   
				@FirstName = @TenantName,   
				@TabsDetails = 'TypeID = 129,PositionID = 134,',  
				@SelectedNodeID = 1,  
				@IsGroup = 0,  
				@CustomFieldsQuery = N'',  
				@CustomCostCenterFieldsQuery = N'',  
				@AttachmentsXML = '', 
				@CompanyGUID = 'CompanyGUID',  
				@UserName = 'Admin',  
				@UserID = 1,  
				@LangID = 1 

			if(@return_value>0)
				set @TenantID=@return_value
		END   
		
		if(@LandlordID=0)
		BEGIN
			if exists(select * from com_costcenterpreferences WITH(NOLOCK) 
			where costcenterid=95 and name ='PickCC' and value='0')
				SELECT @LandlordID = LandlordID FROM REN_UNITS with(nolock)
				where UnitID=@UnitID
			else
				SELECT @LandlordID = LandlordID FROM REN_Property WITH(NOLOCK)
				where  NodeID=@PropertyID 
		END
    
		select  @ContractNumber = max(ContractNumber)+ 1 from ren_contract with(nolock) where contractprefix = CONVERT(NVARCHAR,@PropertyID)  
   
		IF(@ContractNumber = 0 OR @ContractNumber IS NULL)  
			SET @ContractNumber = 1  

		EXEC @return_value = [dbo].[spREN_SetContract]  
			@ContractID = 0,  
			@ContractPrefix = @PropertyID,  
			@ContractNumber = @ContractNumber,  
			@ContractDate =  @ContractDate ,
			@LinkedQuotationID=0,  
			@StatusID = 426,  
			@SelectedNodeID = 1,  
			@IsGroup = 0,  
			@PropertyID = @PropertyID,  
			@UnitID = @UnitID, 
			@MultiUnitIds='',
			@MultiUnitName='',
			@TenantID = @TenantID,  
			@RentRecID = 0,  
			@IncomeID = 0,  
			@Purpose = N'',  
			@StartDate =  @StartDate ,  
			@EndDate =  @EndDate ,    
			@TotalAmount = @TotalAmount,  
			@NonRecurAmount = 0,  
			@RecurAmount = @TotalAmount,  
			@ContractXML = @ContractXML,  
			@PayTermsXML = @PayTermsXML,  
			@RcptXML =  N'',  
			@PDRcptXML =  N'',  
			@ComRcptXML = '',  
			@SIVXML =  N'',  
			@RentRcptXML =  N'',  
			@WONO = '',  
			@LocationID = 1,  
			@DivisionID = 1,  
			@RoleID = 1,  
			@ContractLocationID = 1,  
			@ContractDivisionID = 1,  
			@ContractCurrencyID = 1,  
			@CustomFieldsQuery = @ExtraUserDefinedFields,  
			@CustomCostCenterFieldsQuery = @CostCenterFields,  
			@TermsConditions = N'',  
			@SalesmanID    = @SalesmanID,    
			@AccountantID = @AccountantID,    
			@LandlordID = @LandlordID,    
			@Narration = '',    
			@CostCenterID = 95, 
			@AttachmentsXML = '', 
			@ActivityXml = '', 
			@NotesXML  = '',
			@ExtndTill=NULL,
			@basedon=1,
			@RentAmt=0,
			@RenewRefID=0, 
			@WID=0 ,
			@RecurDuration=0,
			@ExpectedEndDate=NULL,
			@GracePeriod=0,
			@Refno =0,
			@IsOPening=@IsOPening,
			@parContractID =0,
			@IsExtended=0,
			@SysInfo =@SysInfo, 
			@AP =@AP,
			@CompanyGUID = 'CompanyGUID',  
			@GUID = 'GUID',  
			@UserName = 'Admin',  
			@UserID = 1,  
			@LangID = 1 
  
		IF(@return_value > 0 )  
		BEGIN  
		
			UPDATE RCP SET DebitAccID=null 
			FROM REN_Contract RC WITH(NOLOCK)
			JOIN REN_ContractParticulars RCP WITH(NOLOCK) on RCP.ContractID=RC.ContractID and RCP.DebitAccID=RC.RentAccID
			WHERE RC.ContractID=@return_value

			IF(@ExtraFields IS NOT NULL AND @ExtraFields <>'')  
			BEGIN  
				set @UpdateSql='update [REN_Contract] SET '+@ExtraFields+' [ModifiedBy] ='''+ @UserName  
				+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ContractID='+convert(nvarchar,@return_value)  
				exec(@UpdateSql)  
			END 
			
			select @AccountantID=isnull(RentAccID,0),@LandlordID=isnull(IncomeAccID,0) from REN_Contract WITH(NOLOCK) where ContractID=@return_value
			if(@AccountantID=0)
			BEGIN
				if exists(select * from com_costcenterpreferences WITH(NOLOCK) 
					where costcenterid=95 and name = 'PickRRfromTenant' and value='True')
						select @AccountantID=AccountID from ren_tenant WITH(NOLOCK) 
						where tenantid=@tenantid
				else if exists(select * from com_costcenterpreferences WITH(NOLOCK) 
					where costcenterid=95 and name ='PickACC'and value='0')
						SELECT @AccountantID = RentalReceivableAccountID FROM REN_UNITS with(nolock)
						where UnitID=@UnitID
				else
						SELECT @AccountantID = RentalReceivableAccountID FROM REN_Property WITH(NOLOCK)
						where  NodeID=@PropertyID 
				
				if(@AccountantID>0)
					update [REN_Contract] 
						set RentAccID=@AccountantID
					 where ContractID=@return_value	
						
			END
			
			if(@LandlordID=0)
			BEGIN
				 if exists(select * from com_costcenterpreferences WITH(NOLOCK) 
					where costcenterid=95 and name ='PickACC'and value='0')
						SELECT @LandlordID = RentalIncomeAccountID FROM REN_UNITS with(nolock)
						where UnitID=@UnitID
				else
						SELECT @LandlordID = RentalIncomeAccountID FROM REN_Property WITH(NOLOCK)
						where  NodeID=@PropertyID 
				
				if(@LandlordID>0)
					update [REN_Contract] 
						set IncomeAccID=@LandlordID
					 where ContractID=@return_value	
						
			END
			
			declare @i int,@cnt int
			declare @tab table(id int identity(1,1),nid INT,cr INT,dr INT,adaccid INT)
			insert into @tab
			select NodeID,CreditAccID,DebitAccID,AdvanceAccountID 
			from ren_contractparticulars WITH(NOLOCK) where ContractID=@return_value
			select @i=0,@cnt=count(id) from @tab
			
			set @SelectedNodeID=0
			select @SelectedNodeID=value from adm_globalpreferences WITH(NOLOCK)	
			where name='DepositLinkDimension' and isnumeric(value)=1	
			if(@SelectedNodeID>50000)
			BEGIN
				select @TypeName=TableName from adm_features WITH(NOLOCK)  where FeatureID=@SelectedNodeID
				set @TypeName='select @PrntNodeID=NodeID from '+@TypeName+' WITH(NOLOCK) where code=''Rent'' or name =''Rent'''
				exec SP_executesql @TypeName,N'@PrntNodeID INT OUTPUT',@PrntNodeID OUTPUT
			END	
			
			while(@i<@cnt)
			BEGIN
				set @i=@i+1
				set @IsOPening=null
				select @TenantID=nid,@AccountantID=isnull(cr,0),@LandlordID=isnull(dr,0),@SalesmanID=isnull(adaccid,0) from @tab where id=@i
				
				if(@TenantID=@PrntNodeID)
				BEGIN
					if(@AccountantID=0)
					BEGIN
						 if exists(select * from com_costcenterpreferences WITH(NOLOCK) 
						where costcenterid=95 and name ='PickACC'and value='0')
							SELECT @AccountantID = AdvanceRentAccountID FROM REN_UNITS with(nolock)
							where UnitID=@UnitID
						else
							SELECT @AccountantID = AdvanceRentAccountID FROM REN_Property WITH(NOLOCK)
							where  NodeID=@PropertyID 
					END
				END
				ELSE if exists(select * from ren_particulars WITH(NOLOCK) 
				where PropertyID=@PropertyID and UnitID=@UnitID and ParticularID=@TenantID)
				BEGIN
					SELECT @AccountantID =case when @AccountantID=0 THEN CreditAccountID ELSE @AccountantID END
					,@LandlordID =case when @LandlordID=0 THEN DebitAccountID ELSE @LandlordID END
					,@SalesmanID =AdvanceAccountID 
					,@IsOPening=PostDebit
					 FROM ren_particulars WITH(NOLOCK) 
					where PropertyID=@PropertyID and UnitID=@UnitID and ParticularID=@TenantID
					
				END
				ELSE if exists(select * from ren_particulars WITH(NOLOCK) 
				where PropertyID=@PropertyID and ParticularID=@TenantID)
				BEGIN
					SELECT @AccountantID =case when @AccountantID=0 THEN CreditAccountID ELSE @AccountantID END
					,@LandlordID =case when @LandlordID=0 THEN DebitAccountID ELSE @LandlordID END
					,@SalesmanID = AdvanceAccountID 
					,@IsOPening=PostDebit
					 FROM ren_particulars WITH(NOLOCK) 
					where PropertyID=@PropertyID and ParticularID=@TenantID
				END
				
				update ren_contractparticulars
				set CreditAccID=@AccountantID,DebitAccID=@LandlordID,AdvanceAccountID=@SalesmanID,PostDebit=@IsOPening
				where ContractID=@return_value and NodeID=@TenantID
			
			END
			
		END  
	END  

COMMIT TRANSACTION      
  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @return_value      
END TRY      
BEGIN CATCH

if(@return_value=-999)
	return  -999
	 
 IF ERROR_NUMBER()=50000    
 BEGIN    
	IF ISNUMERIC(ERROR_MESSAGE())<>1
	BEGIN
		SELECT ERROR_MESSAGE() ErrorMessage
	END
	ELSE
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID   
	END 
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
