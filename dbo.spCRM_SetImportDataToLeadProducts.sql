USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetImportDataToLeadProducts]
	@PRODUCTXML [nvarchar](max),
	@AccountName [nvarchar](max) = null,
	@AccountCode [nvarchar](max) = null,
	@IsCode [bit] = NULL,
	@LeadXML [nvarchar](max),
	@LExtraFields [nvarchar](max),
	@IsDuplicateNameAllowed [bit],
	@IsCodeAutoGen [bit],
	@IsUpdate [bit],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  
		DECLARE @Dt FLOAT ,@XML XML,@LeadID INT=0,@StatusID INT=415,@Qty float,@UOMID INT,@SQL NVARCHAR(MAX), @return_value INT
		DECLARE @NodeID INT,@BINID INT,@ExtraFields NVARCHAR(MAX),@tempCode NVARCHAR(300),@PRODUCTID INT,@BIN NVARCHAR(300), @I INT,@COUNT INT,@CCID INT,
		@PRODUCTNAME NVARCHAR(300),@CRMPRODUCTNAME NVARCHAR(300),@DESCR NVARCHAR(300),  @TableName nvarchar(300),@CostCenterId INT,@GUID NVARCHAR(MAX)
		,@CodePrefix NVARCHAR(200)='',@CodeNumber BIGINT=0,@Mode INT=0,@SelectedModeID BIGINT=0,@EXTRAFIELDXML XML 
		SET @Dt=CONVERT(FLOAT,GETDATE())
		DECLARE @TAB TABLE(Prefix NVARCHAR(500),Number NVARCHAR(500),Suffix NVARCHAR(500),Code NVARCHAR(500),IsManualCode INT)
		SELECT @CostCenterId=ISNULL(VALUE,'0') FROM ADM_GLOBALPREFERENCES WITH(NOLOCK) WHERE NAME='CRM-Products'
		
		DECLARE @Date datetime ,@ParentID nvarchar(200),@Subject nvarchar(200),@SalutationID INT=0,@RoleLookupID INT=0, @SourceID INT=0,@CreatedBy nvarchar(100)
		, @RatingID INT=0,@PrimaryContactQuery NVARCHAR(max),@AssignedTo nvarchar(100),@CampaignID nvarchar(200) ,@IndustryID INT=0,@DATA XML,@SelectedNodeID INT =1
		,@ExtraUserDefinedFields NVARCHAR(max),@CostCenterFields NVARCHAR(max)
		
		SET @XML=@PRODUCTXML
		DECLARE @TABLE TABLE(ID INT IDENTITY(1,1),PRODUCT NVARCHAR(300),CRMPRODUCT NVARCHAR(300),QUANTITY NVARCHAR(300),DESCP NVARCHAR(300)
		,Extra NVARCHAR(300))
		SELECT Top 1 @TableName=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId  
		
		SELECT @LeadID=LEADID,@StatusID=StatusID,@GUID=[GUID] FROM CRM_LEADS WITH(NOLOCK) WHERE Code=LTRIM(RTRIM(@AccountCode))
		IF(@LeadXML IS NOT NULL)	  	    	  	    
		BEGIN
			SET @DATA=@LeadXML		
			SET @EXTRAFIELDXML =  @LExtraFields 
			
			SELECT @ExtraFields = isnull(X.value('@ExtraFields ','nvarchar(max)'),'')  
			,@ExtraUserDefinedFields = '<Row '+isnull(X.value('@TabDetails','nvarchar(max)'),'') +'   />' 
			,@CostCenterFields = isnull(X.value('@CostCenterFields','nvarchar(max)'),'')  
			,@PrimaryContactQuery = isnull(X.value('@ContactFields','nvarchar(max)'),'')
			from @EXTRAFIELDXML.nodes('/XML/Row') as Data(X)
			  
			select @StatusID = X.value('@StatusID','nvarchar(100)'),
			@Date = ISNULL(X.value('@Date','datetime'),X.value('@CreatedDate','datetime')),
			@ParentID = X.value('@ParentID','nvarchar(200)'),
			@Subject = X.value('@Subject','nvarchar(200)'),
			@SourceID = X.value('@SourceLookUpID','INT'),
			@RatingID = X.value('@RatinglookupID','INT'),
			@RoleLookupID = X.value('@RoleLookupID','INT'),
			@AssignedTo = X.value('@AssignedTo','nvarchar(200)'),
			@CampaignID = X.value('@CampaignID','nvarchar(200)'),  
			@IndustryID= X.value('@IndustryLookUpID','INT'), 
			@SalutationID= X.value('@SalutationID','INT'), 
			@CreatedBy=X.value('@CreatedBy','nvarchar(100)')
			,@Mode=X.value('@Mode','INT')
			from @DATA.nodes('Row') as data(X) 
			
			
			if(@Date is null)
				set @Date=@Dt
			
			if(@StatusID is not null AND @StatusID <>'')  
			BEGIN  
				select @StatusID =ISNULL(StatusID,0)  from COM_Status WITH(NOLOCK)
				where CostCenterID=@COSTCENTERID AND  [Status]  =LTRIM(RTRIM(@StatusID))   
			END 
			ELSE 
				SET @StatusID='415'
				
			if(@SalutationID>0)
				set @PrimaryContactQuery = @PrimaryContactQuery+' Salutation="'+@SalutationID+'" '  				

			if(@RoleLookupID>0)	
				set @PrimaryContactQuery = @PrimaryContactQuery+' Role="'+@RoleLookupID+'" '  
			
			set @PrimaryContactQuery = '<Row '+@PrimaryContactQuery+'   />'  
			
			IF (SELECT ISNULL(Value,'False') FROM COM_CostCenterPreferences WITH(nolock) 
			WHERE COSTCENTERID=@COSTCENTERID and  Name='DuplicateNameAllowed' )='False' AND @IsDuplicateNameAllowed=1
			BEGIN
				UPDATE   COM_CostCenterPreferences  SET Value='True'
				WHERE COSTCENTERID=@COSTCENTERID and  Name='DuplicateNameAllowed' 
			END  
		 
			IF (SELECT ISNULL(Value,0) FROM COM_CostCenterPreferences WITH(nolock) 
			WHERE COSTCENTERID=@COSTCENTERID and  Name='CodeAutoGen' )='False' AND @IsCodeAutoGen=1
			BEGIN
				UPDATE   COM_CostCenterPreferences  SET Value='True'
				WHERE COSTCENTERID=@COSTCENTERID and  Name='CodeAutoGen' 
			END
			
			 --if @IsCode=0
				--SELECT @NodeID=LEADID,@GUID=[GUID] FROM CRM_LEADS WITH(NOLOCK) WHERE
			 --else 
			SELECT @NodeID=LEADID,@GUID=[GUID] FROM CRM_LEADS WITH(NOLOCK) WHERE Code=LTRIM(RTRIM(@AccountCode)) AND  Company=LTRIM(RTRIM(@AccountName))
				
			if(@NodeID is null)
				set @NodeID=0
				
			if(@ParentID is not null AND @ParentID <>'')  
			BEGIN  
				if @IsCode=0
					SELECT @SelectedNodeID=LEADID FROM CRM_LEADS WITH(NOLOCK) WHERE Company=LTRIM(RTRIM(@ParentID))
				 else 
					SELECT @SelectedNodeID=LEADID FROM CRM_LEADS WITH(NOLOCK) WHERE Code=LTRIM(RTRIM(@ParentID))
			END
			 
			IF @GUID='' OR @GUID IS NULL
				SET @GUID=NEWID()
			
			SELECT @Mode=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=86 AND Name='DefaultModeSelection'
		 	 IF(@Mode=3)
				 SELECT @SelectedModeID=CustomerID FROM CRM_Customer WITH(NOLOCK) WHERE CustomerName=@AccountName
			 ELSE IF(@Mode=2)
				 SELECT @SelectedModeID=AccountID FROM Acc_Accounts WITH(NOLOCK) WHERE AccountName=@AccountName		 
			
			if (@CreatedBy is null or @CreatedBy='')
				set @CreatedBy='Admin'
				
			EXEC @return_value = [spCRM_SetLead]  
				  @LeadID = @NodeID,  
				  @LeadCode = @AccountCode,  
				  @Company = @AccountName,  
				  @Description = @AccountName,  
				  @StatusID = @StatusID,  
				  @IsGroup = 0,
				  @SelectedNodeID = @SelectedNodeID,  
				  @Date = @Date,  
				  @Subject = @Subject,  
				  @CampaignID = @CampaignID,  
				  @SourceID = @SourceID,  
				  @RatingID = @RatingID,  
				  @IndustryID = @IndustryID,   
				  @DetailsXML =@PrimaryContactQuery, 
				  @TabDetailsXML =  @ExtraUserDefinedFields,  
				  @CustomFieldsQuery = @ExtraFields,  
				  @CustomCostCenterFieldsQuery = @CostCenterFields,  
				  @CompanyGUID = 'spCRM_SetImportData',
				  @GUID=@GUID,
				  @Mode=@Mode,
				  @SelectedModeID =@SelectedModeID,
				  @UserName = @CreatedBy,  
				  @UserID = @UserID,
				  @RoleID=@RoleID,
				  @LangID = @LangID ,
				  @CodePrefix ='',
				  @CodeNumber= 0,
				  @IsCode=1 
		END
		
		 --if @IsCode=0
			--SELECT @LeadID=LEADID,@StatusID=StatusID,@GUID=[GUID] FROM CRM_LEADS WITH(NOLOCK) WHERE Company=LTRIM(RTRIM(@AccountName))
	  --  else 
		SELECT @LeadID=LEADID,@StatusID=StatusID,@GUID=[GUID] FROM CRM_LEADS WITH(NOLOCK) WHERE Code=LTRIM(RTRIM(@AccountCode)) AND  Company=LTRIM(RTRIM(@AccountName))
	  
		INSERT INTO @TABLE
		SELECT
			X.value('@Product','nvarchar(500)')
           ,X.value('@CRMProduct','nvarchar(max)')
			,X.value('@Quantity','nvarchar(max)')
			,X.value('@Description','nvarchar(max)')
			,X.value('@ExtraFields','nvarchar(max)')
	  	from @XML.nodes('/XML/Row') as Data(X)
	  	
	  	SELECT @I=1,@COUNT=COUNT(*) FROM @TABLE
	  	WHILE @I<=@COUNT
	  	BEGIN
	  	
	  	 SELECT @PRODUCTNAME=LTRIM(RTRIM(PRODUCT)),@ExtraFields=LTRIM(RTRIM(Extra)),
	  	 @DESCR=LTRIM(RTRIM(DESCP)),@Qty=QUANTITY,@CRMPRODUCTNAME=LTRIM(RTRIM(CRMPRODUCT)) FROM @TABLE WHERE ID=@I
	  	 
	  	 IF(@CostCenterId=0)
	  	 BEGIN
	  		 IF @IsCode=1
	  			 SELECT @PRODUCTID =PRODUCTID,@UOMID=UOMID FROM INV_PRODUCT WITH(NOLOCK) WHERE PRODUCTCODE=@PRODUCTNAME
			 ELSE 
				 SELECT @PRODUCTID =PRODUCTID,@UOMID=UOMID FROM INV_PRODUCT WITH(NOLOCK) WHERE PRODUCTNAME=@PRODUCTNAME --OR PRODUCTCODE=@PRODUCTNAME)
		 END
		 ELSE
		 BEGIN 
			 
			 SELECT @PRODUCTID=ISNULL(VALUE,1) FROM COM_COSTCENTERPREFERENCES WITH(NOLOCK) WHERE FEATUREID=3 
			  and Name='TempPartProduct'
			 SELECT @UOMID=UOMID FROM INV_PRODUCT WITH(NOLOCK) WHERE PRODUCTID=@PRODUCTID 
			 
		 END	 
	  		SET @tempCode=' @return_value INT OUTPUT'
	  	 
	  	    SET @SQL=' select @return_value=NodeID  from '+@TableName+' WITH(NOLOCK) WHERE replace(NAME,'' '','''')=replace('''+@CRMPRODUCTNAME+''' ,'' '','''')'  
	  	    EXEC sp_executesql @SQL, @tempCode,@return_value OUTPUT  	  	    
			
			
	  	    IF (@return_value=0 OR @return_value='' OR @return_value IS NULL)
	  	    AND @CostCenterId>0
	  	    BEGIN	  				
	  				EXEC @return_value = [dbo].[spCOM_SetCostCenter]
					@NodeID = 0,@SelectedNodeID = 0,@IsGroup = 0,
					@Code = @CRMPRODUCTNAME,
					@Name = @CRMPRODUCTNAME,
					@AliasName=@CRMPRODUCTNAME,@STATUSID=87,
					@PurchaseAccount=0,@SalesAccount=0, 
					@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
					@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
					@CostCenterID =@CostCenterId,@CompanyGUID=@CompanyGUID,@GUID='GUID',@UserName=@UserName,@RoleID=@RoleID,@UserID=@UserID
				
	  	    END
	  	    IF @PRODUCTID IS NULL OR @PRODUCTID=''
	  		BEGIN	
	  			SET @PRODUCTID=1
	  			SET @UOMID=NULL
	  		END
			 
			 IF @return_value=NULL OR @return_value=''
				SET @return_value=0
				
		 
	  		INSERT into CRM_ProductMapping(CCNodeID,CostCenterID,ProductID,CRMProduct,Quantity,UOMID,Description,CompanyGUID,GUID,CreatedBy,CreatedDate)
	  		VALUES (@LeadID,86,@PRODUCTID,@return_value,@Qty,@UOMID,@DESCR,@CompanyGUID,NEWID(),@UserName,@Dt)
	  		SET @NodeID=SCOPE_IDENTITY()
	  		
	  		IF @ExtraFields<>'' AND @ExtraFields IS NOT NULL
	  		BEGIN
	  			 SET @ExtraFields	 =SUBSTRING(@ExtraFields,1,LEN(@ExtraFields)-1)	
	  			SET @SQL=' UPDATE CRM_ProductMapping SET '+@ExtraFields+' where PRODUCTMAPID='+CONVERT(NVARCHAR,@NodeID)
	  			EXEC (@SQL)
	  		END
	  		
	  set @PRODUCTNAME=''
	  set @ExtraFields=''
	  set @DESCR=''
	  set @Qty=''
	  set @CRMPRODUCTNAME=''
	  set @return_value=0
	  
	  	SET @I=@I+1
	  	END
	  
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;  
RETURN @NodeID
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
