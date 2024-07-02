USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetImportData]
	@COSTCENTERID [int],
	@Code [nvarchar](200),
	@Company [nvarchar](200),
	@XML [nvarchar](max),
	@IsDuplicateNameAllowed [bit],
	@IsCodeAutoGen [bit],
	@IsUpdate [bit],
	@CodeBase [bit],
	@ExtraXML [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON     
  --Declaration Section 
  
	DECLARE @return_value int,@Dt float
	declare @GUID nvarchar(max),@sql nvarchar(max)
	DECLARE @DATA XML,@EXTRAFIELDXML XML  
	SET @DATA=@XML   
	SET @EXTRAFIELDXML =  @ExtraXML  
	SET @Dt=CONVERT(FLOAT,GETDATE())
       
	-- Create Temp Table  
	DECLARE @ExtraFields NVARCHAR(max) ,@ExtraUserDefinedFields NVARCHAR(max),@CostCenterFields NVARCHAR(max),@PrimaryContactQuery NVARCHAR(max) ,@UpdateSql NVARCHAR(max)   ,@Mode int
        
	SELECT @ExtraFields = isnull(X.value('@ExtraFields ','nvarchar(max)'),'')  
	,@ExtraUserDefinedFields = '<Row '+isnull(X.value('@TabDetails','nvarchar(max)'),'') +'   />' 
	,@CostCenterFields = isnull(X.value('@CostCenterFields','nvarchar(max)'),'')  
	,@PrimaryContactQuery = isnull(X.value('@ContactFields','nvarchar(max)'),'')
	from @EXTRAFIELDXML.nodes('/XML/Row') as Data(X)  
	
	DECLARE @StatusID nvarchar(100),@Date datetime,@Subject nvarchar(200) ,@CampaignID nvarchar(200),@CreatedBy nvarchar(100) ,@ParentID nvarchar(200),@AssignedTo nvarchar(100)
	DECLARE @NodeID INT =0,@SelectedNodeID INT =1 ,@IndustryID INT=0, @RatingID INT=0, @SourceID INT=0,@SalutationID INT=0,@RoleLookupID INT=0,@CloseDate datetime,@AssignedDate datetime

    if @COSTCENTERID=73
    begin	
		select @StatusID = X.value('@StatusID','nvarchar(100)'),
		@Date = X.value('@CreateDate','datetime'),
		@ParentID = X.value('@ParentID','nvarchar(200)'),
		@Subject = X.value('@Subject','nvarchar(200)'),
		@SourceID = X.value('@CasePriorityLookupID','INT'),
		@RatingID = X.value('@CaseOriginLookupID','INT'),
		@RoleLookupID = X.value('@CaseTypeLookupID','INT'),
		@AssignedTo = X.value('@AssignedTo','nvarchar(200)'),  
		@IndustryID= X.value('@ServiceLvlLookupID','INT'), 
		@SalutationID= X.value('@BillingMethod','INT'), 
		@CreatedBy=X.value('@CreatedBy','nvarchar(100)'),
		@CloseDate = X.value('@CreateDate','datetime'),
		@AssignedDate=X.value('@AssignedDate','datetime'),
		@Mode=X.value('@Mode','INT')
		from @DATA.nodes('Row') as data(X)  
		         
		IF @IsUpdate=1
			SELECT @NodeID=CaseID,@GUID=[GUID] FROM CRM_Cases WHERE CaseNumber=LTRIM(RTRIM(@Code))
		
		if(@ParentID is not null AND @ParentID <>'')  
			SELECT @SelectedNodeID=CaseID FROM CRM_Cases WHERE CaseNumber=LTRIM(RTRIM(@ParentID))
			 
		IF @GUID='' OR @GUID IS NULL
			SET @GUID=NEWID()
		
		if @Mode is null or @Mode=0
			SELECT @Mode=ISNULL(Value,DefaultValue) FROM COM_CostCenterPreferences WITH(nolock) 
			WHERE COSTCENTERID=73 and  Name='DefaultModeSelection' and Value<>''
		
		IF @Mode=1
		BEGIN
			if @CodeBase=0
				SELECT @CampaignID=AccountID FROM ACC_Accounts with(nolock) where AccountName=@Company
			else 
				SELECT @CampaignID=AccountID FROM ACC_Accounts with(nolock) where AccountCode=@Company
		END
		ELSE 
		BEGIN
			if @CodeBase=0
				SELECT @CampaignID=CustomerID FROM CRM_Customer with(nolock) where CustomerName=@Company
			else 
				SELECT @CampaignID=CustomerID FROM CRM_Customer with(nolock) where CustomerCode=@Company
		END
		
		if(@Date is null)
			set @Date=@Dt
		
		if (@CreatedBy is null or @CreatedBy='')
			set @CreatedBy='Admin'
					
		exec @return_value=[dbo].[spCRM_SetCases]  
		 @CaseID = @NodeID,  
		 @CaseNumber = @Code,  
		 @CaseDate =@Date,   
		 @CUSTOMER =@CampaignID,  
		 @StatusID =@StatusID,  
		 @IsGroup =0,  
		 @SelectedNodeID =@SelectedNodeID,   
		 @CASETYPEID =@RoleLookupID,   
		 @CASEORIGINID =@RatingID,   
		 @CASEPRIORITYID =@SourceID,   
		 @SVCCONTRACTID =0,  
		 @CONTRACTLINEID =0,  
		 @PRODUCTID =0,  
		 @SERIALNUMBER =NULL,  
		 @BillingMethod =@SalutationID,   
		 @SERVICELVLID =@IndustryID,   
		 @Assigned =0,  
		 @DESCRIPTION ='',  
		 @SERVICEXML ='',  
		 @ActivityXml ='',  
		 @NotesXML ='',  
		 @AttachmentsXML ='',  
		 @FeedbackXML ='',  
		 @CustomCostCenterFieldsQuery =@ExtraFields,  
		 @CustomCCQuery =@CostCenterFields,  
		 @WaveUser =0,  
		 @WAVEDATE =NULL,  
		 @COMMENTS ='',  
		 @ProductXML ='',  
		 @mode =@Mode,  
		 @RefCCID =0,  
		 @RefNodeID =0,  
		 
		 @ContactsXML ='',  
		 @Subject =@Subject, 
		  
		 @CompanyGUID='spCRM_SetImportData',  
		 @GUID =@GUID, 
		 @CustomerMode  = @Mode,      
		 @UserName =@CreatedBy,  
		 @UserID  = @UserID,
		 @RoleID  = @RoleID,
		 @LangId =@LangId,
		 @CodePrefix ='',
		 @CodeNumber =0,
		 @IsCode =0,
		 @WID =0,
		 @AssignXML =''   
    end
    else if @COSTCENTERID=86
    begin
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
	 
		IF @IsUpdate=1
		BEGIN
			 if @CodeBase=0
				SELECT @NodeID=LEADID,@GUID=[GUID] FROM CRM_LEADS WITH(NOLOCK) WHERE Company=LTRIM(RTRIM(@Company))
			 else 
				SELECT @NodeID=LEADID,@GUID=[GUID] FROM CRM_LEADS WITH(NOLOCK) WHERE Code=LTRIM(RTRIM(@Code))
		END
		
		if(@ParentID is not null AND @ParentID <>'')  
		BEGIN  
			if @CodeBase=0
				SELECT @SelectedNodeID=LEADID FROM CRM_LEADS WITH(NOLOCK) WHERE Company=LTRIM(RTRIM(@ParentID))
			 else 
				SELECT @SelectedNodeID=LEADID FROM CRM_LEADS WITH(NOLOCK) WHERE Code=LTRIM(RTRIM(@ParentID))
		END
		 
		IF @GUID='' OR @GUID IS NULL
			SET @GUID=NEWID()
	 
		if (@CreatedBy is null or @CreatedBy='')
			set @CreatedBy='Admin'

		EXEC @return_value = [spCRM_SetLead]  
			  @LeadID = @NodeID,  
			  @LeadCode = @Code,  
			  @Company = @Company,  
			  @Description = @Company,  
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
			  @UserName = @CreatedBy,  
			  @UserID = @UserID,
			  @RoleID=@RoleID,
			  @LangID = @LangID ,
			  @CodePrefix ='',
			  @CodeNumber= 0,
			  @IsCode=1   
	end
	else if @COSTCENTERID=114
    begin	
		
		IF @Company=73
		BEGIN
			SELECT @NodeID=CaseID FROM CRM_Cases WHERE CaseNumber=LTRIM(RTRIM(@Code))
		END
		ELSE IF @Company=86
		BEGIN
			if @CodeBase=0
				SELECT @NodeID=LEADID FROM CRM_LEADS WITH(NOLOCK) WHERE Company=LTRIM(RTRIM(@Code))
			 else 
				SELECT @NodeID=LEADID FROM CRM_LEADS WITH(NOLOCK) WHERE Code=LTRIM(RTRIM(@Code))
		END
		ELSE IF @Company=89
		BEGIN
			if @CodeBase=0
				SELECT @NodeID=OpportunityID FROM CRM_Opportunities WITH(NOLOCK) WHERE Company=LTRIM(RTRIM(@Code))
			 else 
				SELECT @NodeID=OpportunityID FROM CRM_Opportunities WITH(NOLOCK) WHERE Code=LTRIM(RTRIM(@Code))
		END
		
		if(@Date is null)
			set @Date=@Dt
			 
		SET @Sql=''
	 	SET @UpdateSql=''
	 	select @Sql=@Sql+',['+name+']' 
		,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
		from sys.columns  WITH(NOLOCK)
		where object_id=object_id('CRM_FEEDBACK') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
		SET @Sql='INSERT into CRM_FEEDBACK(CCID,CCNodeID,Date,Feedback,CreatedBy,CreatedDate'+@Sql+')
		select '+convert(nvarchar,@Company)+',@NodeID,  
		convert(float,x.value(''@Date'',''datetime'')),x.value(''@FeedBack'',''nvarchar(max)''),x.value(''@CreatedBy'',''nvarchar(200)'') ,'+CONVERT(NVARCHAR,convert(float,@Dt))+'
		'+@UpdateSql+'
		from @XML.nodes(''XML/Row'') as data(x)'
		
		EXEC sp_executesql @SQL,N'@XML XML,@NodeID INT',@XML,@NodeID
		
		set @return_value=1
    end
    
	if(@AssignedTo is not null and @AssignedTo<>'' and @return_value>0)
	BEGIN
		set @UserID=0
		select @UserID=UserID from adm_users WITH(NOLOCK) where username=@AssignedTo

		if(@UserID>0)
			EXEC spCRM_SetCRMAssignment @COSTCENTERID,@return_value,0,@UserID,0,@UserID,'','',@CompanyGUID,@AssignedTo,@LangId
		
		if @AssignedDate is not null
		begin
			select @ExtraFields='update '+tablename+' set AssignedDate='+convert(nvarchar(max),convert(float,@AssignedDate))+' where '+primarykey+'='+convert(nvarchar(max),@return_value)
			from adm_features with(nolock) where featureid=@COSTCENTERID
			
			exec (@ExtraFields)
			
		end
	END	
	
	
	if exists (select * FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=@COSTCENTERID and  Name='DefaultCloseStatus' and Value=@StatusID )
	and @return_value > 0 and @StatusID is not null and @StatusID<>''  and @COSTCENTERID=73
	begin
		if(@CloseDate is null)
			set @CloseDate=@Dt
			
		 exec [dbo].[spCRM_CloseLead] 
			@LeadID =@return_value,
			@CCID =@COSTCENTERID,
			@Date =@CloseDate,
			@UserID =@UserID,
			@LangID =@LangID
	end
 
COMMIT TRANSACTION      
--ROLLBACK TRANSACTION      
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @return_value      
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
