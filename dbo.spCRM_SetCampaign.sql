USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetCampaign]
	@CampaignID [int],
	@CampaignCode [nvarchar](200),
	@CampaignName [nvarchar](500),
	@TypeID [int],
	@Venue [int],
	@StatusID [int],
	@VendorID [int] = 0,
	@SelectedNodeID [int],
	@ExpectedResponce [nvarchar](500) = null,
	@Offer [nvarchar](500) = null,
	@ProcuctXML [nvarchar](max) = null,
	@ResponseXML [nvarchar](max) = null,
	@CActivityXML [nvarchar](max) = null,
	@DemoKitXML [nvarchar](max) = null,
	@OrganizationXML [nvarchar](max) = null,
	@STAFFXML [nvarchar](max) = null,
	@ApprovalsXML [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@CustomFieldsQuery [nvarchar](max) = null,
	@TabDetails [nvarchar](max) = null,
	@IsGroup [bit],
	@Description [nvarchar](500) = null,
	@NotesXML [nvarchar](max) = NULL,
	@AttachmentsXML [nvarchar](max) = NULL,
	@SpeakersXML [nvarchar](max) = NULL,
	@ActivityXml [nvarchar](max) = null,
	@InvitesXML [nvarchar](max) = null,
	@EventsXml [nvarchar](max) = null,
	@CompanyGUID [varchar](50),
	@UserName [nvarchar](50),
	@RoleID [int] = 0,
	@LangID [int] = 1,
	@CodePrefix [nvarchar](200) = NULL,
	@CodeNumber [int] = 0,
	@IsCode [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  
  DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50),@HasAccess bit,@IsDuplicateNameAllowed bit,@IsCodeAutoGen bit  
  DECLARE @UpdateSql nvarchar(max),@Sql nvarchar(max),@ParentCode nvarchar(200),@CCCCCData XML,@IsIgnoreSpace bit  
  DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT  
  DECLARE @SelectedIsGroup bit
    
  --User acces check FOR Campaign  
  IF @CampaignID=0  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,88,1)  
  END  
  ELSE  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,88,3)  
  END  
  
       --User acces check FOR Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,88,8)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  
  --User acces check FOR Attachments  
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,88,12)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
 
 
--SELECT 'EFGH'
  IF EXISTS(SELECT StatusID FROM dbo.COM_Status  WHERE CostCenterID=88 AND Status='Active' AND StatusID=@StatusID )  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,88,23)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-111',16,1)  
   END  
  END  
  
  IF EXISTS(SELECT StatusID FROM dbo.COM_Status  
  WHERE CostCenterID=88 AND Status='In Active' AND StatusID=@StatusID )  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,88,24)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-113',16,1)  
   END  
  END  

  --GETTING PREFERENCE  
  SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=88 and  [Name]='DuplicateNameAllowed'  
  SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=88 and  [Name]='CodeAutoGen'  
  SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=88 and  [Name]='IgnoreSpaces'  
 SELECT @IsCode, @IsCodeAutoGen, @CampaignID,@CodePrefix
   IF @IsCode=1 and @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1 AND @CampaignID=0 and @CodePrefix=''  
	BEGIN 
		--CALL AUTOCODEGEN 
		create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
		if(@SelectedNodeID is null)
		insert into #temp1
		EXEC [spCOM_GetCodeData] 88,1,''  
		else
		insert into #temp1
		EXEC [spCOM_GetCodeData] 88,@SelectedNodeID,''  
		--select * from #temp1
		select @CampaignCode=code,@CodePrefix= prefix, @CodeNumber=number from #temp1
		--select @AccountCode,@ParentID
	END	
  --DUPLICATE CHECK  
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
  BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
   BEGIN  
    IF @CampaignID=0  
    BEGIN  
     IF EXISTS (SELECT CampaignID FROM CRM_Campaigns WITH(nolock) WHERE replace([Name],' ','')=replace(@CampaignName,' ',''))  
     BEGIN  
      RAISERROR('-108',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT CampaignID FROM CRM_Campaigns WITH(nolock) WHERE replace([Name],' ','')=replace(@CampaignName,' ','') AND CampaignID <> @CampaignID)  
     BEGIN  
      RAISERROR('-108',16,1)       
     END  
    END  
   END  
   ELSE  
   BEGIN  
    IF @CampaignID=0  
    BEGIN  
     IF EXISTS (SELECT CampaignID FROM CRM_Campaigns WITH(nolock) WHERE [Name]=@CampaignName)  
     BEGIN  
      RAISERROR('-108',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT CampaignID FROM CRM_Campaigns WITH(nolock) WHERE  Name =@CampaignName AND CampaignID <> @CampaignID)  
     BEGIN  
      RAISERROR('-108',16,1)  
     END  
    END  
   END
  END  
 

  SET @Dt=convert(float,getdate())--Setting Current Date  
 
  IF @CampaignID=0--------START INSERT RECORD-----------  
  BEGIN--CREATE ACCOUNT--  
    --To Set Left,Right And Depth of Record  
    SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
    from [CRM_Campaigns] with(NOLOCK) where CampaignID=@SelectedNodeID  
   
    --IF No Record Selected or Record Doesn't Exist  
    if(@SelectedIsGroup is null)   
     select @SelectedNodeID=CampaignID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
     from [CRM_Campaigns] with(NOLOCK) where ParentID =0  
         
    if(@SelectedIsGroup = 1)--Adding Node Under the Group  
     BEGIN  
      UPDATE CRM_Campaigns SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
      UPDATE CRM_Campaigns SET lft = lft + 2 WHERE lft > @Selectedlft;  
      set @lft =  @Selectedlft + 1  
      set @rgt = @Selectedlft + 2  
      set @ParentID = @SelectedNodeID  
      set @Depth = @Depth + 1  
     END  
    else if(@SelectedIsGroup = 0)--Adding Node at Same level  
     BEGIN  
      UPDATE CRM_Campaigns SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
      UPDATE CRM_Campaigns SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
  
    --GENERATE CODE  
    --IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1 AND @CampaignID=0  
    --BEGIN  
    -- SELECT @ParentCode=[Code]  
    -- FROM [CRM_Campaigns] WITH(NOLOCK) WHERE CampaignID=@ParentID    
  
    -- --CALL AUTOCODEGEN  
    -- EXEC [spCOM_SetCode] 88,@ParentCode,@CampaignCode OUTPUT    
    --END  
  
  
			-- Insert statements for procedure here  
			INSERT INTO CRM_Campaigns  
				(CodePrefix,CodeNumber,Code,
			   [Name] ,   
			   [StatusID],
			   [CampaignTypeLookupID],
			   [ExpectedResponse],
			   [Offer], 
			   [VendorLookupID],  
			   [Description], 
			   [Depth],  
			   [ParentID],  
			   [lft],  
			   [rgt],  
			   [IsGroup],  
			   [CompanyGUID],
			   [GUID],
			   [CreatedBy],  
			   [CreatedDate],
			   Venue)
		   VALUES  
		    (@CodePrefix,@CodeNumber,@CampaignCode,--			   (@CampaignCode,  
			   @CampaignName,  
			   @StatusID,  
			   @TypeID,  
			   @ExpectedResponce,
			   @Offer, 
			   @VendorID,
			   @Description,  
			   @Depth,  
			   @ParentID,  
			   @lft,  
			   @rgt,  
			   @IsGroup,  
			   @CompanyGUID,
			   newid(),  
			   @UserName,  
			   @Dt,
			   @Venue)  

    --To get inserted record primary key  
    SET @CampaignID=SCOPE_IDENTITY()  
   
    --Handling of Extended Table  
    INSERT INTO [CRM_CampaignsExtended]([CampaignID],[CreatedBy],[CreatedDate])  
    VALUES(@CampaignID, @UserName, @Dt)  


  
      DELETE FROM  COM_CCCCDATA WHERE NodeID=@CampaignID AND  CostCenterID = 88
	--Handling of CostCenter Costcenters Extrafields Table  

		 	INSERT INTO COM_CCCCData ([NodeID],CostCenterID, [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
			 VALUES(@CampaignID,88, @UserName, @Dt, @CompanyGUID,newid())
			 
	   IF exists(select * from  dbo.ADM_FeatureActionrolemap with(nolock) where RoleID=@RoleID and FeatureActionID=4841)
		BEGIN  
		 	UPDATE CRM_Campaigns SET IsApproved=1, ApprovedDate=CONVERT(float,getdate()),ApprovedBy=@UserName
		 	 where [CampaignID]=@CampaignID 
		end
      
   END--------END INSERT RECORD-----------  
  ELSE--------START UPDATE RECORD-----------  
  BEGIN   
  
   IF EXISTS(SELECT CampaignID FROM CRM_Campaigns WHERE CampaignID=@CampaignID AND ParentID=0)  
   BEGIN  
    RAISERROR('-123',16,1)  
   END  
      
   SELECT @TempGuid=[GUID] from [CRM_Campaigns]  WITH(NOLOCK)   
   WHERE CampaignID=@CampaignID  
  
--   IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
  -- BEGIN    
 --      RAISERROR('-101',16,1)   
  -- END    
--   ELSE    
   BEGIN   
 
   --Insert into Account history  Extended  
   --insert into CRM_CampaignsExtended 
   --select * from [CRM_CampaignsExtended] WHERE CampaignID=@CampaignID      
  
  
   --Handling of CostCenter Costcenters Extrafields Table  
   --INSERT INTO ACC_AccountCostCenterMap ([CampaignID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
   --VALUES(@CampaignID, @UserName, @Dt, @CompanyGUID,newid())  
   
    UPDATE CRM_Campaigns  
    SET [Code] = @CampaignCode  
       ,[Name] = @CampaignName  
	   ,[StatusID] = @StatusID  
       ,[CampaignTypeLookupID] = @TypeID  
       ,[Venue] = @Venue
       ,[IsGroup] = @IsGroup  
       ,[ExpectedResponse]=@ExpectedResponce
	   ,[Offer]=@Offer 
	   ,[VendorLookupID]=@VendorID
	   ,[CompanyGUID]=@CompanyGUID
	   ,[GUID] =  newid()  
	   ,[Description] = @Description
	   ,[ModifiedBy] = @UserName  
       ,[ModifiedDate] = @Dt
    WHERE CampaignID=@CampaignID   
       

   END
   
   --Update CostCenter Extra Fields
		
 
 END
 
 set @UpdateSql='update COM_CCCCDATA 
		SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID = '+convert(nvarchar,@CampaignID)+ ' AND CostCenterID = 88 ' 
	
		exec(@UpdateSql)
		
 if(@TabDetails is not null and @TabDetails <>'')
   begin 
  SET @UpdateSql=' UPDATE CRM_Campaigns SET '+@TabDetails+' WHERE CampaignID = '+CONVERT(nvarchar,@CampaignID)

  exec(@UpdateSql)
  
   end
   
   		--Update Extra fields
		set @UpdateSql='update [CRM_CampaignsExtended]
		SET '+@CustomFieldsQuery+'[ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE CampaignID ='+convert(nvarchar,@CampaignID)
	
		exec(@UpdateSql)
   
	--SETTING CODE EQUALS CampaignID IF EMPTY  

	IF(@CampaignCode IS NULL OR @CampaignCode='')  
	BEGIN  
		UPDATE  CRM_Campaigns  
		SET [Code] = @CampaignID  
		WHERE CampaignID=@CampaignID   
	END
   

--Inserts Multiple Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @XML=@NotesXML  
  
   --If Action is NEW then insert new Notes  
   INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
   GUID,CreatedBy,CreatedDate)  
   SELECT 88,88,@CampaignID,Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),  
   newid(),@UserName,@Dt  
   FROM @XML.nodes('/NotesXML/Row') as Data(X)  
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
  
   --If Action is MODIFY then update Notes  
   UPDATE COM_Notes  
   SET Note=Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),   
    GUID=newid(),  
    ModifiedBy=@UserName,  
    ModifiedDate=@Dt  
   FROM COM_Notes C   
   INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)    
   ON convert(INT,X.value('@NoteID','INT'))=C.NoteID  
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
  
   --If Action is DELETE then delete Notes  
   DELETE FROM COM_Notes  
   WHERE NoteID IN(SELECT X.value('@NoteID','INT')  
    FROM @XML.nodes('/NotesXML/Row') as Data(X)  
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
  
  END  
  
  --Inserts Multiple Attachments  
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
  BEGIN  
   SET @XML=@AttachmentsXML  
  
   INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
   FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
   GUID,CreatedBy,CreatedDate)  
   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),88,88,@CampaignID,  
   X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  
   FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
  
   --If Action is MODIFY then update Attachments  
   UPDATE COM_Files  
   SET FilePath=X.value('@FilePath','NVARCHAR(500)'),  
    ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),  
    RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),  
    FileExtension=X.value('@FileExtension','NVARCHAR(50)'),  
    FileDescription=X.value('@FileDescription','NVARCHAR(500)'),  
    IsProductImage=X.value('@IsProductImage','bit'),        
    GUID=X.value('@GUID','NVARCHAR(50)'),  
    ModifiedBy=@UserName,  
    ModifiedDate=@Dt  
   FROM COM_Files C   
   INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X)    
   ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID  
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
  
   --If Action is DELETE then delete Attachments  
   DELETE FROM COM_Files  
   WHERE FileID IN(SELECT X.value('@AttachmentID','INT')  
    FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)  
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
  END  	

		 if(@ResponseXML is not null and @ResponseXML <> '')
		 begin
		 
		 	set @XML=@ResponseXML
		 	
		 	SET @Sql=''
		 	SET @UpdateSql=''
		 	select @Sql=@Sql+',['+name+']' 
			,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_CAMPAIGNRESPONSE') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
			SET @Sql='INSERT into CRM_CAMPAIGNRESPONSE(CampaignID,CampaignActivityID,ProductID,
			CampgnRespLookupID,ReceivedDate,[Description],CustomerID,CompanyName,ContactName,
			Phone,Email,Fax,ChannelLookupID,VendorLookupID,
			CompanyGUID,GUID,CreatedBy,CreatedDate,
			[FirstName],[MiddleName],[LastName],[JobTitle],[Department],[Address1],[Address2],[Address3],[City],[State]
			,[Zip],[Country],[Phone2],[Email2],[URL]'+@Sql+')
			select @CampaignID,1,1,
			x.value(''@ResponseID'',''INT''),
			CONVERT(float,x.value(''@Date'',''DateTime'')),
			x.value(''@Description'',''nvarchar(500)''),
			x.value(''@CustomerID'',''INT''),
			x.value(''@CompanyName'',''nvarchar(500)''),
			x.value(''@ContactName'',''nvarchar(500)''),
			x.value(''@Phone'',''nvarchar(50)''),
			x.value(''@Email'',''nvarchar(50)''),
			x.value(''@Fax'',''nvarchar(50)''),
			x.value(''@ChannelID'',''INT''),
			x.value(''@VendorID'',''INT''),
			'''+@CompanyGUID+''',
			newid(),
			'''+@UserName+''',
			'+CONVERT(NVARCHAR,convert(float,@Dt))+',
			x.value(''@FirstName'',''nvarchar(200)''),x.value(''@MiddleName'',''nvarchar(200)''),x.value(''@LastName'',''nvarchar(200)''),
			x.value(''@JobTitle'',''nvarchar(200)''),x.value(''@Department'',''nvarchar(200)''),x.value(''@Address1'',''nvarchar(200)''),
			x.value(''@Address2'',''nvarchar(200)''),x.value(''@Address3'',''nvarchar(200)''),x.value(''@City'',''nvarchar(200)''),x.value(''@State'',''nvarchar(200)''),
			x.value(''@Zip'',''nvarchar(200)''),x.value(''@Country'',''nvarchar(200)''),x.value(''@Phone2'',''nvarchar(200)''),x.value(''@Email2'',''nvarchar(200)''),
			x.value(''@URL'',''nvarchar(200)'')'+@UpdateSql+'
			from @XML.nodes(''XML/Row'') as data(x)
			WHERE X.value(''@Action'',''NVARCHAR(10)'')=''NEW'''  
			
			EXEC sp_executesql @SQL,N'@XML XML,@CampaignID INT',@XML,@CampaignID
			
			SET @UpdateSql=''
			select @UpdateSql=@UpdateSql+',['+name+']=X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_CAMPAIGNRESPONSE') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
			SET @Sql='UPDATE CRM_CAMPAIGNRESPONSE  SET
			CampgnRespLookupID=x.value(''@ResponseID'',''INT''),ReceivedDate=CONVERT(float,x.value(''@Date'',''DateTime'')),[Description]=x.value(''@Description'',''nvarchar(500)'')
			,CustomerID=x.value(''@CustomerID'',''INT''),CompanyName=x.value(''@CompanyName'',''nvarchar(500)''),ContactName=x.value(''@ContactName'',''nvarchar(500)''),
			Phone=	x.value(''@Phone'',''nvarchar(50)''),Email=	x.value(''@Email'',''nvarchar(50)''),Fax=x.value(''@Fax'',''nvarchar(50)''),ChannelLookupID=x.value(''@ChannelID'',''INT''),VendorLookupID=			x.value(''@VendorID'',''INT''),
			[FirstName]=x.value(''@FirstName'',''nvarchar(200)''),[MiddleName]=x.value(''@MiddleName'',''nvarchar(200)''),[LastName]=x.value(''@LastName'',''nvarchar(200)''),[JobTitle]=x.value(''@JobTitle'',''nvarchar(200)'')
			,[Department]=x.value(''@Department'',''nvarchar(200)''),[Address1]=x.value(''@Address1'',''nvarchar(200)''),[Address2]=x.value(''@Address2'',''nvarchar(200)''),[Address3]=x.value(''@Address3'',''nvarchar(200)''),[City]=x.value(''@City'',''nvarchar(200)'')
			,[State]=x.value(''@State'',''nvarchar(200)'')
			,[Zip]=x.value(''@Zip'',''nvarchar(200)''),[Country]=x.value(''@Country'',''nvarchar(200)''),[Phone2]=x.value(''@Phone2'',''nvarchar(200)''),[Email2]=x.value(''@Email2'',''nvarchar(200)''),[URL]=x.value(''@URL'',''nvarchar(200)'')
			'+@UpdateSql+'
			,GUID=newid(),ModifiedBy='''+@UserName+''', ModifiedDate='+CONVERT(NVARCHAR,convert(float,@Dt))+' 
			FROM CRM_CAMPAIGNRESPONSE C WITH(NOLOCK)  
			INNER JOIN @XML.nodes(''XML/Row'') as Data(X)    
			ON convert(INT,X.value(''@CampaignResponseID'',''INT''))=C.CampaignResponseID  
			WHERE X.value(''@Action'',''NVARCHAR(500)'')=''MODIFY'' ' 
			
			EXEC sp_executesql @SQL,N'@XML XML',@XML
			
			--If Action is DELETE then delete Notes  
			DELETE FROM CRM_CAMPAIGNRESPONSE  
			WHERE CampaignResponseID IN(SELECT X.value('@CampaignResponseID','INT')  
			FROM @XML.nodes('XML/Row') as Data(X)  
			WHERE X.value('@Action','NVARCHAR(10)')='DELETE')   
				--Delete from CRM_CAMPAIGNRESPONSE where CampaignID = @CampaignID  
			
		end


		if(@CActivityXML is not null and @CActivityXML <> '')
	   begin
			set @XML=@CActivityXML
			Delete from CRM_CAMPAIGNACTIVITIES where CampaignID = @CampaignID 

			INSERT into CRM_CAMPAIGNACTIVITIES(CampaignID,Name,StatusID,
			ChannelLookupID,VendorLookupID,TypeLookupID,PriorityTypeLookupID,Description,StartDate,
			EndDate,BudgetedAmount,ActualCost,CurrencyID,
			   CompanyGUID,GUID,CreatedBy,CreatedDate,CompletionRate,WorkingHrs, CheckList, CloseStatus, CloseDate,ClosedRemarks)
			   select @CampaignID,
		       x.value('@Name','nvarchar(500)'),x.value('@StatusID','int'),x.value('@ChannelID','INT'),
			   x.value('@VendorID','INT'),x.value('@TypeID','INT'),x.value('@PriorityID','INT'),
			   x.value('@Description','nvarchar(500)'),CONVERT(float,x.value('@StartDate','DateTime')),
			   CONVERT(float,x.value('@EndDate','DateTime')),CONVERT(float,x.value('@BudgetAmount','INT')),
			   CONVERT(float,x.value('@ActualCost','INT')),x.value('@CurencyID','INT'),@CompanyGUID,
			   newid(),@UserName,convert(float,@Dt),x.value('@CompletionRate','float'),x.value('@WorkingHrs','float'),
			   x.value('@CheckList','nvarchar(max)'),x.value('@CloseStatus','bit'),CONVERT(float,isnull(x.value('@CloseDate','DateTime'),0)),
			   x.value('@ClosedRemarks','nvarchar(500)')
			   from @XML.nodes('XML/Row') as data(x)
			
		end
		if(@STAFFXML is not null and @STAFFXML <> '')
	   begin
			 set @XML=@STAFFXML
				Delete from CRM_CampaignStaff where CampaignID = @CampaignID 

				INSERT into CRM_CampaignStaff(CampaignID,CustomerName,CustomerID,ContactID,
				StaffInitial,StaffTitle,StaffName,JobTitle,[Type],  
				   CompanyGUID,GUID,CreatedBy,CreatedDate)
				   select @CampaignID, x.value('@Customer','nvarchar(500)'),
			       x.value('@CustomerID','nvarchar(500)'),
				   x.value('@ContactID','nvarchar(500)'),
			       x.value('@StaffInitial','nvarchar(500)'),
				   x.value('@StaffTitle','nvarchar(500)'),
				   x.value('@StaffName','nvarchar(500)'),
				   x.value('@JobTitle','nvarchar(500)'),
				   x.value('@Type','nvarchar(500)'), 
				   @CompanyGUID,
				   newid(),
				   @UserName,
				   convert(float,@Dt) 
				 
				   from @XML.nodes('XML/Row') as data(x)
			
		end
		
		if(@OrganizationXML is not null and @OrganizationXML <> '')
		BEGIN
			SET @XML=@OrganizationXML
			Delete from CRM_CampaignOrganization where CampaignNodeID = @CampaignID and CCID=88 
			
			SET @Sql=''
		 	SET @UpdateSql=''
			select @Sql=@Sql+',['+name+']' 
			,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_CampaignOrganization') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
			SET @Sql='INSERT into CRM_CampaignOrganization (CCID,CampaignNodeID,Customer,ContactName,JobTitle,Department,Country
			,City,CytomedDivision,Territory,CreatedBy,CreatedDate,ContactID,CustomerID,Salutation'+@Sql+')
			select 88,@CampaignID,
			x.value(''@Customer'',''nvarchar(300)''), x.value(''@ContactName'',''nvarchar(300)''), x.value(''@JobTitle'',''nvarchar(300)''), x.value(''@Department'',''nvarchar(300)''), x.value(''@Country'',''nvarchar(300)''), 
			x.value(''@City'',''nvarchar(300)''), x.value(''@CytomedDivision'',''nvarchar(300)''), x.value(''@Territory'',''nvarchar(300)''), '''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+'
			,x.value(''@ContactID'',''nvarchar(300)''), x.value(''@CustomerID'',''nvarchar(300)''),x.value(''@Salutation'',''INT'')
			'+@UpdateSql+' 
			from @XML.nodes(''XML/Row'') as data(x) ' 
			
			EXEC sp_executesql @SQL,N'@XML XML,@CampaignID INT',@XML,@CampaignID
		END

		if(@DemoKitXML is not null and @DemoKitXML <> '')
		BEGIN
			SET @XML=@DemoKitXML 
			Delete from CRM_CampaignDemoKit where CampaignNodeID = @CampaignID and CCID=88 
			
			SET @Sql=''
		 	SET @UpdateSql=''
			select @Sql=@Sql+',['+name+']' 
			,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_CampaignDemoKit') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
			SET @Sql='INSERT into CRM_CampaignDemoKit (CCID,CampaignNodeID,Date,CreatedBy,CreatedDate,ProductId,Quantity,UnitPrice,Value'+@Sql+')
			select 88,@CampaignID,convert(float,x.value(''@Date'',''datetime'')),'''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+'
			,x.value(''@ProductID'',''INT''), x.value(''@Quantity'',''FLOAT''), x.value(''@UnitPrice'',''FLOAT''), x.value(''@Value'',''FLOAT'')
			'+@UpdateSql+' 
			from @XML.nodes(''XML/Row'') as data(x) ' 
			
			EXEC sp_executesql @SQL,N'@XML XML,@CampaignID INT',@XML,@CampaignID
		END
		if(@InvitesXML is not null and @InvitesXML <> '')
		BEGIN
			SET @XML=@InvitesXML 
			
			SET @Sql=''
		 	SET @UpdateSql=''
			select @Sql=@Sql+',['+name+']' 
			,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_CampaignInvites') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
			SET @Sql='INSERT into CRM_CampaignInvites(CCID,CampaignNodeID,Customer,ContactName,JobTitle,Department,Country,City,CytomedDivision,Territory,CreatedBy,CreatedDate
			,ContactID,CustomerID,Salutation,ConvertedLeadID,ConvertedResponseID'+@Sql+')
			select 88,@CampaignID,
			x.value(''@Customer'',''nvarchar(300)''), x.value(''@ContactName'',''nvarchar(300)''), x.value(''@JobTitle'',''nvarchar(300)''), x.value(''@Department'',''nvarchar(300)''), x.value(''@Country'',''nvarchar(300)''), 
			x.value(''@City'',''nvarchar(300)''), x.value(''@CytomedDivision'',''nvarchar(300)''), x.value(''@Territory'',''nvarchar(300)''),'''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+'
			,x.value(''@ContactID'',''nvarchar(300)''), x.value(''@CustomerID'',''nvarchar(300)''),x.value(''@Salutation'',''INT''),0,0'+@UpdateSql+' 
			from @XML.nodes(''XML/Row'') as data(x) 
			WHERE X.value(''@Action'',''NVARCHAR(10)'')=''NEW''  ' 
			
			EXEC sp_executesql @SQL,N'@XML XML,@CampaignID INT',@XML,@CampaignID
			
			SET @UpdateSql=''
			select @UpdateSql=@UpdateSql+',['+name+']=X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_CampaignInvites') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
   --If Action is MODIFY then update Notes  
			SET @Sql='UPDATE CRM_CampaignInvites  SET
			Customer=x.value(''@Customer'',''nvarchar(300)''), ContactName=x.value(''@ContactName'',''nvarchar(300)''), JobTitle=x.value(''@JobTitle'',''nvarchar(300)''), Department=x.value(''@Department'',''nvarchar(300)''), Country=x.value(''@Country'',''nvarchar(300)''), 
			City=x.value(''@City'',''nvarchar(300)''),CytomedDivision= x.value(''@CytomedDivision'',''nvarchar(300)''), Territory=x.value(''@Territory'',''nvarchar(300)''),  
			Salutation=x.value(''@Salutation'',''INT''),CustomerID=x.value(''@CustomerID'',''nvarchar(300)''), ContactID=x.value(''@ContactID'',''nvarchar(300)'') 
			'+@UpdateSql+'
			FROM CRM_CampaignInvites C with(nolock)  
			INNER JOIN @XML.nodes(''XML/Row'') as Data(X)    
			ON convert(INT,X.value(''@NodeID'',''INT''))=C.NodeID  
			WHERE X.value(''@Action'',''NVARCHAR(500)'')=''MODIFY''  ' 
			
			EXEC sp_executesql @SQL,N'@XML XML',@XML

			--If Action is DELETE then delete Notes  
			DELETE FROM CRM_CampaignInvites  
			WHERE NodeID IN(SELECT X.value('@NodeID','INT')  
			FROM @XML.nodes('XML/Row') as Data(X)  
			WHERE X.value('@Action','NVARCHAR(10)')='DELETE')   
			
			
		END
		if(@SpeakersXML is not null and @SpeakersXML <> '')
		BEGIN
			SET @XML=@SpeakersXML 
			Delete from CRM_CampaignSpeakers where CampaignNodeID = @CampaignID and CCID=88 
			
			SET @Sql=''
	 		SET @UpdateSql=''
			select @Sql=@Sql+',['+name+']' 
			,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_CampaignSpeakers') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
				
			SET @Sql='INSERT into CRM_CampaignSpeakers(CCID,CampaignNodeID,Date,CreatedBy,CreatedDate,CustomerID,ContactID,Customer,ContactName'+@Sql+')
			select 88,@CampaignID,convert(float,x.value(''@Date'',''datetime'')), '''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+'
			,x.value(''@CustomerID'',''INT''),x.value(''@ContactID'',''INT''),x.value(''@Customer'',''nvarchar(200)''),x.value(''@ContactName'',''nvarchar(200)'')'+@UpdateSql+' 
			from @XML.nodes(''XML/Row'') as data(x)' 
			
			EXEC sp_executesql @SQL,N'@XML XML,@CampaignID INT',@XML,@CampaignID
		END
		--Campaign Activities
		 exec spCom_SetActivitiesAndSchedules @ActivityXml,88,@CampaignID,@CompanyGUID,'',@UserName,@dt,@LangID 
		 --Events 
		 exec spCom_SetActivitiesAndSchedules @EventsXml,128,@CampaignID,@CompanyGUID,'',@UserName,@dt,@LangID 
		 
		--validate Data External function
		DECLARE @tempCCCode NVARCHAR(200)
		set @tempCCCode=''
		select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=88 and Mode=9
		if(@tempCCCode<>'')
		begin
			exec @tempCCCode 88,@CampaignID,1,@LangID
		end   
		
		if(@ApprovalsXML is not null and @ApprovalsXML <> '')
		BEGIN
			SET @XML=@ApprovalsXML 
			Delete from CRM_CampaignApprovals where CampaignNodeID = @CampaignID and CCID=88 
			
			SET @Sql=''
	 		SET @UpdateSql=''
			select @Sql=@Sql+',['+name+']' 
			,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_CampaignApprovals') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
				
			SET @Sql='INSERT into CRM_CampaignApprovals(CCID,CampaignNodeID,Date,CreatedBy,CreatedDate,FilePath,ActualFileName,FileExtension,GUID'+@Sql+')
			select 88,@CampaignID,
			convert(float,x.value(''@Date'',''datetime'')),'''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+'
			,x.value(''@FilePath'',''nvarchar(MAX)''),x.value(''@ActualFileName'',''nvarchar(MAX)''),x.value(''@FileExtension'',''nvarchar(MAX)'') 
			,x.value(''@GUID'',''nvarchar(MAX)'')'+@UpdateSql+'  
			from @XML.nodes(''XML/Row'') as data(x) ' 
			
			EXEC sp_executesql @SQL,N'@XML XML,@CampaignID INT',@XML,@CampaignID
			
		END
	 
		
		
		Delete from CRM_ProductMapping where CCNodeID = @CampaignID and CostCenterID=88
		if(@ProcuctXML is not null and @ProcuctXML <> '')
		begin
			SET @XML=@ProcuctXML
			
			SET @Sql=''
	 		SET @UpdateSql=''
			select @Sql=@Sql+',['+name+']' 
			,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'INT' ELSE 'nvarchar(200)' END+''')' 
			from sys.columns  WITH(NOLOCK)
			where object_id=object_id('CRM_ProductMapping') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
		
			SET @Sql='INSERT into CRM_ProductMapping(CCNodeID,CostCenterID,ProductID,CRMProduct,UOMID,Description,
			   Quantity,CurrencyID,CompanyGUID,GUID,CreatedBy,CreatedDate'+@Sql+')
			   select @CampaignID,88,
		       x.value(''@Product'',''INT''), x.value(''@CRMProduct'',''INT''),
			   x.value(''@UOM'',''INT''), x.value(''@Desc'',''nvarchar(MAX)''),
			   x.value(''@Qty'',''float''),ISNULL(x.value(''@Currency'',''INT''),1)
			   ,'''+@CompanyGUID+''',newid(),'''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+@UpdateSql+' 
			   from @XML.nodes(''XML/Row'') as data(x)
			   where  x.value(''@Product'',''INT'')is not null and   x.value(''@Product'',''INT'') <> '''' ' 
			
			EXEC sp_executesql @SQL,N'@XML XML,@CampaignID INT',@XML,@CampaignID
			
		end
		
		
 

COMMIT TRANSACTION    
SELECT * FROM CRM_Campaigns WITH (nolock) WHERE CampaignID=@CampaignID  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @CampaignID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT * FROM CRM_Campaigns WITH(nolock) WHERE CampaignID=@CampaignID    
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
