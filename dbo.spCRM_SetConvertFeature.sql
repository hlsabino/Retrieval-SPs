USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetConvertFeature]
	@ResponseID [int] = 0,
	@Customer [bit] = FALSE,
	@LEad [bit] = FALSE,
	@Date [datetime] = null,
	@CustomersID [bigint] = 0,
	@CompanyName [nvarchar](500) = null,
	@ContactName [nvarchar](500) = null,
	@Phone [nvarchar](50) = null,
	@Email [nvarchar](50) = null,
	@Fax [nvarchar](50) = null,
	@Description [nvarchar](500) = null,
	@CAMPCODE [nvarchar](300) = NULL,
	@CompanyGUID [nvarchar](100),
	@UserName [nvarchar](100),
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY 
SET NOCOUNT ON

	DECLARE @Dt float,@ParentCode nvarchar(200),@IsCodeAutoGen bit,@CodePrefix NVARCHAR(300),@CodeNumber BIGINT,@LeadStatusApprove bit
	DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint
	DECLARE @SelectedIsGroup bit,@SelectedNodeID INT,@IsGroup BIT,@AccountID BIGINT
	DECLARE @CampaignID BIGINT, @Code NVARCHAR(300),@LeadID bigint,@OpportunityID BIGINT,@CustomerID BIGINT,@DetailContact BIGINT
	create table #temp1(prefix nvarchar(100),number bigint, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
	
	SELECT @CampaignID=CampaignID  FROM CRM_Campaigns with(NOLOCK) WHERE NAME=@CAMPCODE 

	SET @Dt=convert(float,getdate())--Setting Current Date  
	SET @SelectedNodeID=1


	--------INSERT INTO LEADS TABLE  
	IF (@LEad = 1)  
	BEGIN
		 --To Set Left,Right And Depth of Record  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		from CRM_Leads with(NOLOCK) where LeadID=@SelectedNodeID  
	      
		--IF No Record Selected or Record Doesn't Exist  
		if(@SelectedIsGroup is null)   
		 select @SelectedNodeID=LeadID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		 from CRM_Leads with(NOLOCK) where ParentID =0  
	            
		if(@SelectedIsGroup = 1)--Adding Node Under the Group  
		 BEGIN  
		  UPDATE CRM_Leads SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
		  UPDATE CRM_Leads SET lft = lft + 2 WHERE lft > @Selectedlft;  
		  set @lft =  @Selectedlft + 1  
		  set @rgt = @Selectedlft + 2  
		  set @ParentID = @SelectedNodeID  
		  set @Depth = @Depth + 1  
		 END  
		else if(@SelectedIsGroup = 0)--Adding Node at Same level  
		 BEGIN  
		  UPDATE CRM_Leads SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
		  UPDATE CRM_Leads SET lft = lft + 2 WHERE lft > @Selectedrgt;  
		  set @lft =  @Selectedrgt + 1  
		  set @rgt = @Selectedrgt + 2   
		 END  
		else  --Adding Root  
		 BEGIN  
		  set @lft =  1  
		  set @rgt = 2   
		  set @Depth = 0  
		  set @ParentID =0  
		  set @IsGroup=1  
		 END 
		 
		SET @IsGroup=0 
		SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=86 and  Name='CodeAutoGen'  

		--GENERATE CODE  
		IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1 
		BEGIN  
		--CALL AUTOCODEGEN  
			if(@SelectedNodeID is null)
			insert into #temp1
			EXEC [spCOM_GetCodeData] 86,1,''  
			else
			insert into #temp1
			EXEC [spCOM_GetCodeData] 86,@SelectedNodeID,''  
			--select * from #temp1
			select @Code=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 WITH(NOLOCK)
			--select @AccountCode,@ParentID
		END  
		ELSE ---CHECKING AUTO GENERATE CODE
		BEGIN
			IF @Code='' OR @Code IS NULL 
				SET @Code=@CAMPCODE
		END
    
 
		INSERT INTO CRM_Leads
        (CodePrefix,CodeNumber 
        ,Code
        ,[Subject]
        ,[Date]
        ,StatusId
        ,Company
        ,SourceLookUpID
        ,RatinglookupID
        ,IndustryLookUpID
        ,CampaignID
        ,CampaignResponseID
        ,CampaignActivityID
        ,[Description]
        ,Depth
        ,ParentID
        ,lft
        ,rgt
        ,IsGroup
        ,CompanyGUID
        ,[GUID]
        ,CreatedBy
        ,CreatedDate)
		Values 
          (@CodePrefix,@CodeNumber  
          ,@Code
          ,@CAMPCODE
          ,CONVERT(FLOAT,@Date)
          ,415
          ,@CompanyName
          ,47
          ,49
          ,51
          ,@CampaignID
		  ,1
		   ,1
          ,@Description
          ,@Depth
          ,@ParentID
          ,@lft
          ,@rgt
          ,@IsGroup
          ,@CompanyGUID
          ,newid()
          ,@UserName
          ,convert(float,@Dt))
     
		SET @LeadID=SCOPE_IDENTITY() 

		INSERT INTO CRM_LeadsExtended([LeadID],[CreatedBy],[CreatedDate])  
		VALUES(@LeadID, @UserName, @Dt) 
		
		DECLARE @return_value int,@LinkCostCenterID INT
		SELECT @LinkCostCenterID=isnull([Value],0) FROM COM_CostCenterPreferences WITH(NOLOCK) 
		WHERE FeatureID=86 AND [Name]='LinkDimension'

		IF @LinkCostCenterID>0  AND @IsGroup=0  
		BEGIN
			EXEC @return_value = [dbo].[spCOM_SetCostCenter]
				@NodeID = 0,@SelectedNodeID = 0,@IsGroup = 0,
				@Code = @Code,
				@Name = @CompanyName,
				@AliasName=@CompanyName,
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=85,
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
				@CostCenterID =@LinkCostCenterID,@CompanyGUID=@COMPANYGUID,@GUID='GUID',@UserName=@USERNAME,@RoleID=1,@UserID=@USERID
				--@return_value 
				UPDATE CRM_Leads
				SET CCLeadID=@return_value
				WHERE LeadID=@LeadID 
		END    
		
		insert into CRM_CONTACTS
          (FeatureID,FeaturePK,
           FirstName,
           MiddleName,
           LastName,
           JobTitle,
           Company, 
           Phone1,
           Phone2,
           Email1,
           Fax,
           Department, 
           Address1,
           Address2,
           Address3,
           City,
           State,
           Zip,
           Country  
           ,CompanyGUID
           ,GUID
           ,CreatedBy
           ,CreatedDate
            )
           SELECT 86,@LeadID,
           FirstName,
           MiddleName,
           LastName, 
           JobTitle,
           ContactName, 
           Phone,
           Phone2,
           Email,
           Fax,
           Department, 
           Address1,
           Address2,
           Address3,
           City,
           State,
           Zip,
           Country   
           ,CompanyGUID
           ,GUID
           ,CreatedBy
           ,CreatedDate 
        FROM CRM_CampaignResponse with(nolock) WHERE CampaignResponseID=@ResponseID

		INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
		VALUES(86,@LeadID,newid(),  @UserName, @Dt) 

		--INSERT PRIMARY CONTACT  
		INSERT  [COM_Contacts]([AddressTypeID],[FeatureID],[FeaturePK],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])  
		VALUES(1,86,@LeadID,@CompanyGUID,NEWID(),@UserName,@Dt)  
		
		INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
		VALUES(SCOPE_IDENTITY(), @UserName, convert(float,getdate())) 
			 	
		UPDATE  CRM_CampaignResponse SET ConvertedLeadID=@LeadID WHERE CampaignResponseID=@ResponseID
		
		DECLARE @SELECTEDCUSTOMERID INT
		SELECT @SELECTEDCUSTOMERID=ISNULL(CustomerID,0) FROM CRM_CampaignResponse with(nolock) WHERE CampaignResponseID=@ResponseID
		IF(@SELECTEDCUSTOMERID>0)
		BEGIN 
			UPDATE CRM_Leads SET Mode=3,SelectedModeID=@SELECTEDCUSTOMERID WHERE LeadID=@LeadID
		END
	  
		IF exists(select * from  dbo.ADM_FeatureActionrolemap with(nolock) where RoleID=@RoleID and FeatureActionID=4829)
		BEGIN  
		 	UPDATE CRM_LEADS SET IsApproved=1, ApprovedDate=CONVERT(float,getdate()),ApprovedBy=@UserName
		 	 where Leadid=@LeadID 
		end
   END
    
-------------INSERT INTO CUSTOMERS TABLE
IF  EXISTS (SELECT * FROM CRM_CampaignResponse with(nolock)   WHERE CampaignResponseID=@ResponseID AND CustomerID=0)
BEGIN
	 IF(@Customer=1)
 
     BEGIN
    --To Set Left,Right And Depth of Record
    SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
    from [CRM_Customer] with(NOLOCK) where CustomerID=@SelectedNodeID
 
    --IF No Record Selected or Record Doesn't Exist
    if(@SelectedIsGroup is null) 
     select @SelectedNodeID=CustomerID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
     from [CRM_Customer] with(NOLOCK) where ParentID =0
       
     
    if(@SelectedIsGroup = 1)--Adding Node Under the Group
     BEGIN
      
      UPDATE CRM_Customer SET rgt = rgt + 2 WHERE rgt > @Selectedlft;
      UPDATE CRM_Customer SET lft = lft + 2 WHERE lft > @Selectedlft;
      set @lft =  @Selectedlft + 1
      set @rgt = @Selectedlft + 2
      set @ParentID = @SelectedNodeID
      set @Depth = @Depth + 1
 
     END
    else if(@SelectedIsGroup = 0)--Adding Node at Same level
     BEGIN
      UPDATE CRM_Customer SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
      UPDATE CRM_Customer SET lft = lft + 2 WHERE lft > @Selectedrgt;
      set @lft =  @Selectedrgt + 1
      set @rgt = @Selectedrgt + 2 
     END
    else  --Adding Root
     BEGIN
      set @lft =  1
      set @rgt = 2 
      set @Depth = 0
      set @ParentID =0
      set @IsGroup=1
     END
	 SET @IsGroup=0
	 SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=83 and  Name='CodeAutoGen'  
    --GENERATE CODE
    IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1 
    BEGIN
     	if(@SelectedNodeID is null)
			insert into #temp1
			EXEC [spCOM_GetCodeData] 83,1,''  
		else
			insert into #temp1
			EXEC [spCOM_GetCodeData] 83,@SelectedNodeID,''  
		--select * from #temp1
		select @Code=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 WITH(NOLOCK)
		 
     
    END
    ELSE
    BEGIN
      IF @CODE='' OR @CODE IS NULL 
         SET @Code=@ContactName
    END
     

    -- Insert statements for procedure here
    INSERT INTO [CRM_Customer]
       (CodePrefix,CodeNumber,[CustomerCode],
       [CustomerName] ,
       [AliasName] ,
       [CustomerTypeID],
       [StatusID],
       [AccountID],
       [Depth],
       [ParentID],
       [lft],
       [rgt],
       [IsGroup], 
       [CreditDays], 
       [CreditLimit],
       [CompanyGUID],
       [GUID],
       [Description],
       [CreatedBy],
       [CreatedDate])
       VALUES
       (@CodePrefix,@CodeNumber,@CODE,
       @CompanyName,
       @CompanyName,
       146,
       393,
       @AccountID,
       @Depth,
       @ParentID,
       @lft,
       @rgt,
       @IsGroup,
       NULL,
       NULL, 
       @CompanyGUID,
       newid(),
       @Description,
       @UserName,
       @Dt)
     
    --To get inserted record primary key
    SET @CustomerID=SCOPE_IDENTITY()
  
	--Handling of Extended Table
    INSERT INTO [CRM_CustomerExtended]([CustomerID],[CreatedBy],[CreatedDate])
    VALUES(@CustomerID, @UserName, @Dt)
    
    -- Handling of CostCenter Costcenters Extrafields Table
 	INSERT INTO COM_CCCCData ([NodeID],CostCenterID, [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
	VALUES(@CustomerID,83, @UserName, @Dt, @CompanyGUID,newid())

	SET @CustomersID=@CustomerID

	UPDATE  CRM_CampaignResponse SET CustomerID=@CustomersID WHERE CampaignResponseID=@ResponseID

	insert into com_contacts(ContactTypeID,AddressTypeID,FeatureID,FeaturePK,FirstName,SalutationID,Company,StatusID,Phone1,Email1,Fax,Department,IsVisible,
				  [Description],Depth,ParentID,CompanyGUID,[GUID],CreatedBy,CreatedDate)
		   values(54,2,83,@CustomersID,@ContactName,47,@CompanyName,403,@Phone,@Email, @Fax,1,0,
				 @Description,@Depth,@ParentID,@CompanyGUID,newid(),@UserName,convert(float,@Dt))

	set @DetailContact=scope_identity()
			
	IF NOT EXISTS (SELECT * FROM COM_ContactsExtended with(nolock) WHERE ContactID=@DetailContact)
		INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
		VALUES(@DetailContact, @UserName, convert(float,getdate()))


	IF NOT EXISTS (SELECT * FROM COM_CCCCDATA with(nolock) WHERE [CostCenterID]=65 AND [NodeID]=@DetailContact)
		INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
		VALUES(65,@DetailContact,newid(),  @UserName, @Dt)   
END
END         
COMMIT TRANSACTION  
SET NOCOUNT OFF;   
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=103 AND LanguageID=@LangID 
RETURN 1
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
