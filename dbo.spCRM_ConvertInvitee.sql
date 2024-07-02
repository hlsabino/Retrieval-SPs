USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_ConvertInvitee]
	@InviteeID [int] = 0,
	@Lead [bit] = 0,
	@Resonse [bit] = 0,
	@CompanyGUID [nvarchar](100),
	@UserName [nvarchar](100),
	@UserID [int],
	@LoginRoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY 
SET NOCOUNT ON

  DECLARE @Dt float,@ParentCode nvarchar(200),@LeadStatusApprove bit,@IsCodeAutoGen bit,@CodePrefix NVARCHAR(300),@CodeNumber INT
  DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT
  DECLARE @SelectedIsGroup bit ,@CompanyName nvarchar(300), @CampaignID int,@LeadID int,@LeadCode nvarchar(400),@CustomerID INT, @ContactID INT,@SelectedNodeID INT,@IsGroup BIT,@AccountID INT 
  SET @Dt=convert(float,getdate())--Setting Current Date  

 SELECT @CampaignID=CampaignNodeID,@CompanyName=Customer,@ContactID=ContactID, @CustomerID=CustomerID 
 FROM CRM_CampaignInvites with(NOLOCK) WHERE NodeID=@InviteeID
 
  SET @SelectedNodeID=1 
--------INSERT INTO LEADS TABLE  
  IF @Lead=1 
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
		create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
		if(@SelectedNodeID is null)
		insert into #temp1
		EXEC [spCOM_GetCodeData] 86,1,''  
		else
		insert into #temp1
		EXEC [spCOM_GetCodeData] 86,@SelectedNodeID,''  
		select @LeadCode=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 with(NOLOCK)
    END  
    

       INSERT INTO CRM_Leads
        (CodePrefix,CodeNumber,
         Code
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
        ,CreatedDate,Mode,SelectedModeID,ContactID)
    Values 
          (@CodePrefix,@CodeNumber  
          ,@LeadCode
          ,@CompanyName
          ,CONVERT(FLOAT,@Dt)
          ,415
          ,@CompanyName
          ,47
          ,49
          ,51
          ,1
		  ,1
		   ,1
          ,@CompanyName
          ,@Depth
          ,@ParentID
          ,@lft
          ,@rgt
          ,@IsGroup
          ,@CompanyGUID
          ,newid()
          ,@UserName
          ,convert(float,@Dt),3,@CustomerID,@ContactID)
     
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
					@Code = @LeadCode,
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
           SalutationID,
           JobTitle,
           Company,
           StatusID,
           Phone1,
           Phone2,
           Email1,
           Fax,
           Department,
           RoleLookUpID,
           Address1,
           Address2,
           Address3,
           City,
           State,
           Zip,
           Country,
           Gender,
           Birthday,
           Anniversary,
           PreferredID,
           PreferredName,
           IsEmailOn,
           IsBulkEmailOn,
           IsMailOn,
           IsPhoneOn,
           IsFaxOn,
           IsVisible,
           Description
           ,Depth
           ,ParentID
           ,lft
           ,rgt
           ,IsGroup
           ,CompanyGUID
           ,GUID
           ,CreatedBy
           ,CreatedDate)
           SELECT 86,@LeadID,
           FirstName,
           MiddleName,
           LastName,
           SalutationID,
           JobTitle,
           Company,
           StatusID,
           Phone1,
           Phone2,
           Email1,
           Fax,
           Department,
           RoleLookUpID,
           Address1,
           Address2,
           Address3,
           City,
           State,
           Zip,
           Country,
           Gender,
           Birthday,
           Anniversary,
           PreferredID,
           PreferredName,
           IsEmailOn,
           IsBulkEmailOn,
           IsMailOn,
           IsPhoneOn,
           IsFaxOn,
           IsVisible,
           Description
           ,Depth
           ,ParentID
           ,lft
           ,rgt
           ,IsGroup
           ,CompanyGUID
           ,GUID
           ,CreatedBy
           ,CreatedDate FROM COM_Contacts with(NOLOCK) WHERE ContactID=@ContactID
    
    
	INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
    VALUES(86,@LeadID,newid(),  @UserName, @Dt) 

      --INSERT PRIMARY CONTACT  
    INSERT  [COM_Contacts] ([AddressTypeID],[FeatureID] ,[FeaturePK],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])  
    VALUES(1,86,@LeadID,@CompanyGUID,NEWID() ,@UserName,@Dt)  
    
    INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
	VALUES(SCOPE_IDENTITY(), @UserName, convert(float,getdate())) 
			 	
	UPDATE  CRM_CampaignInvites SET ConvertedLeadID=@LeadID WHERE NodeID=@InviteeID

	IF exists(select * from  ADM_FeatureActionrolemap with(nolock) where RoleID=@LoginRoleID and FeatureActionID=4829)
	BEGIN  
	 	UPDATE CRM_LEADS SET IsApproved=1, ApprovedDate=CONVERT(float,getdate()),ApprovedBy=@UserName
	 	 where Leadid=@LeadID 
	end

END    
   
  IF @Resonse=1
  BEGIN
		declare @ResLookupID int

		select @ResLookupID=NodeID from com_lookup WITH(NOLOCK) where lookuptype=27 AND IsDefault=1

		INSERT into CRM_CAMPAIGNRESPONSE(CampaignID,CampaignActivityID,ProductID,
		CampgnRespLookupID,ReceivedDate,[Description],CustomerID,CompanyName,ContactName,
		Phone,Email,Fax,ChannelLookupID,VendorLookupID,
		CompanyGUID,GUID,CreatedBy,CreatedDate,
		[FirstName],[MiddleName],[LastName],[JobTitle],[Department],[Address1],[Address2],[Address3],[City],[State]
		,[Zip],[Country],[Phone2],[Email2])
		SELECT @CampaignID,1,1,@ResLookupID,@Dt,@CompanyName,@CustomerID,@CompanyName,FirstName,Phone1,Email2,Fax,1,1,@CompanyGUID,NEWID(),
		@UserName,@Dt,FirstName,MiddleName,LastName,jobTitle,Department,Address1,Address2,Address3,City,State,
		Zip,Country,Phone2,Email2
		from COM_Contacts with(NOLOCK) WHERE ContactID=@ContactID
		UPDATE  CRM_CampaignInvites SET ConvertedResponseID=SCOPE_IDENTITY() WHERE NodeID=@InviteeID
 
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
