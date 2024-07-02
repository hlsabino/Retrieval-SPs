USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetLead]
	@LeadID [int] = 0,
	@LeadCode [nvarchar](200),
	@Company [nvarchar](200) = NULL,
	@Description [nvarchar](500) = NULL,
	@StatusID [int],
	@IsGroup [bit],
	@SelectedNodeID [int],
	@Date [datetime] = NULL,
	@Subject [nvarchar](500) = NULL,
	@CampaignID [int] = 1,
	@SourceID [int] = null,
	@RatingID [int] = null,
	@IndustryID [int] = null,
	@ContactID [int] = null,
	@DetailsXML [nvarchar](max) = null,
	@TabDetailsXML [nvarchar](max) = null,
	@CustomFieldsQuery [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@ActivityXml [nvarchar](max) = null,
	@NotesXML [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@ProductXML [nvarchar](max) = null,
	@FeedbackXML [nvarchar](max) = null,
	@CVRXML [nvarchar](max) = null,
	@ContactsXML [nvarchar](max) = null,
	@PrimaryContactQuery [nvarchar](max) = NULL,
	@EmailAllow [bit] = 0,
	@BulkEmailAllow [bit] = 0,
	@MailAllow [bit] = 0,
	@PhoneAllow [bit] = 0,
	@FaxAllow [bit] = 0,
	@Mode [int] = 0,
	@SelectedModeID [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangId [int] = 1,
	@CodePrefix [nvarchar](200) = NULL,
	@CodeNumber [int] = 0,
	@IsCode [bit] = 0,
	@WID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON   
BEGIN TRANSACTION  
BEGIN TRY  
    
 DECLARE @UpdateSql nvarchar(max),@Dt FLOAT, @TempGuid nvarchar(50),@HasAccess bit,@ActionType INT,@StatusName nvarchar(50),@ID INT,@Remarks nvarchar(max)  
 Declare @XML XML,@return_value INT,@LinkDim_NodeID int,@Dimesion INT,@RefSelectedNodeID INT ,@CCStatusID INT,@Sql nvarchar(max)  
   
 IF EXISTS(SELECT LeadID FROM CRM_Leads WITH(NOLOCK) WHERE LeadID=@LeadID AND ParentID=0)    
 BEGIN    
  RAISERROR('-123',16,1)    
 END    
   
 --User acces check FOR ACCOUNTS    
 IF @LeadID=0    
 BEGIN  
  SET @ActionType=1  
  SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,86,1)    
 END    
 ELSE    
 BEGIN    
  SET @ActionType=3  
  SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,86,3)    
 END    
  
 IF @HasAccess=0    
 BEGIN    
  RAISERROR('-105',16,1)    
 END   
   
 --User acces check FOR Notes    
 IF (@NotesXML IS NOT NULL AND @NotesXML <> '')    
 BEGIN    
  SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,86,8)    
  
  IF @HasAccess=0    
  BEGIN    
   RAISERROR('-105',16,1)    
  END    
 END    
  
 --User acces check FOR Attachments    
 IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')      
 BEGIN      
  SET @XML=@AttachmentsXML  
  SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,86,12)      
  
  IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)      
  WHERE X.value('@Action','NVARCHAR(10)')='NEW') and @HasAccess=0       
  BEGIN      
   RAISERROR('-105',16,1)      
  END   
    
  SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,86,14)      
  
  IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)      
  WHERE X.value('@Action','NVARCHAR(10)')='MODIFY') and @HasAccess=0       
  BEGIN      
   RAISERROR('-105',16,1)      
  END   
    
  SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,86,15)      
  
  IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)      
  WHERE X.value('@Action','NVARCHAR(10)')='DELETE') and @HasAccess=0       
  BEGIN      
   RAISERROR('-105',16,1)      
  END   
 END      
   
 --GETTING PREFERENCE  
 Declare @IsDuplicateNameAllowed bit,@IsIgnoreSpace bit,@AutoAssign bit    
 SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=86 and  Name='DuplicateNameAllowed'    
 SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=86 and  Name='IgnoreSpaces'    
 SELECT @AutoAssign=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=86 and  Name='AutoAssign'    
 SELECT @Dimesion=isnull([Value],0) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE FeatureID=86 AND [Name]='LinkDimension'  
   
    IF @IsCode=1 AND @LeadID=0 and @LeadCode='' and exists (SELECT * FROM COM_CostCenterCodeDef WITH(nolock)WHERE CostCenterID=86 and IsEnable=1 and IsName=0 and IsGroupCode=@IsGroup)  
 BEGIN   
  --CALL AUTOCODEGEN   
  declare @temp1 table(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)  
  if(@SelectedNodeID is null)  
   insert into @temp1  
   EXEC [spCOM_GetCodeData] 86,1,''    
  else  
   insert into @temp1  
   EXEC [spCOM_GetCodeData] 86,@SelectedNodeID,''    
  select @LeadCode=code,@CodePrefix= prefix, @CodeNumber=number from @temp1   
 END   
  
 IF @MODE=0  
 BEGIN  
  --DUPLICATE CHECK    
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0    
  BEGIN    
   IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1    
   BEGIN    
    IF @LeadID=0    
    BEGIN    
     IF EXISTS (SELECT LeadID FROM CRM_Leads WITH(nolock) WHERE replace(Company,' ','')=replace(@Company,' ','') AND MODE=0)    
     BEGIN    
      RAISERROR('-112',16,1)    
     END    
    END    
    ELSE    
    BEGIN    
     IF EXISTS (SELECT LeadID FROM CRM_Leads WITH(nolock) WHERE replace(Company,' ','')=replace(@Company,' ','') AND MODE=0 AND LeadID <> @LeadID)    
     BEGIN    
      RAISERROR('-112',16,1)         
     END    
    END    
   END    
   ELSE    
   BEGIN    
    IF @LeadID=0    
    BEGIN    
     IF EXISTS (SELECT LeadID FROM CRM_Leads WITH(nolock) WHERE Company=@Company AND MODE=0)    
     BEGIN    
      RAISERROR('-112',16,1)    
     END    
    END    
    ELSE    
    BEGIN    
     IF EXISTS (SELECT LeadID FROM CRM_Leads WITH(nolock) WHERE Company=@Company AND MODE=0 AND LeadID <> @LeadID)    
     BEGIN    
      RAISERROR('-112',16,1)    
     END    
    END    
   END  
  END     
 END  
  
 SET @Dt=convert(float,getdate())--Setting Current Date    
  
 declare @detailtbl table(FirstName NVARCHAR(50),MiddleName NVARCHAR(50),LastName NVARCHAR(50),Salutation INT,jobTitle NVARCHAR(50),  
 Phone1 NVARCHAR(50),Phone2 NVARCHAR(50),Email NVARCHAR(50),Fax NVARCHAR(50),Department NVARCHAR(50),RoleID INT)  
  
 if(@DetailsXML is not null AND @DetailsXML<>'')  
 begin  
  set @XML =@DetailsXML  
  insert into @detailtbl  
  select x.value('@FirstName','NVARCHAR(50)'),x.value('@MiddleName','NVARCHAR(50)'),x.value('@LastName','NVARCHAR(50)'),x.value('@Salutation','INT'),  
  x.value('@JobTitle','NVARCHAR(50)'),x.value('@Phone1','NVARCHAR(50)'),x.value('@Phone2','NVARCHAR(50)'),x.value('@Email','NVARCHAR(50)'),x.value('@Fax','NVARCHAR(50)'),  
  x.value('@Department','NVARCHAR(50)'),x.value('@Role','INT') from  @XML.nodes('Row') as data(x)  
 end  
    
 declare @tabdetailtbl table(Address1 NVARCHAR(50),Address2 NVARCHAR(50),Address3 NVARCHAR(50),City NVARCHAR(50),[State] NVARCHAR(50),  
 Zip NVARCHAR(50),CountryID INT,Gender NVARCHAR(50),Birthday FLOAT,Anniversary FLOAT,PreferredID INT,PreferredName nvarchar(50))  
  
 if(@TabDetailsXML is not null AND @TabDetailsXML<>'')  
 begin  
  set @XML =@TabDetailsXML  
  insert into @tabdetailtbl  
  select x.value('@Address1','NVARCHAR(50)'),x.value('@Address2','NVARCHAR(50)'),x.value('@Address3','NVARCHAR(50)'),  
  x.value('@City','NVARCHAR(50)'),x.value('@State','NVARCHAR(50)'),x.value('@Zip','NVARCHAR(50)'),x.value('@Country','INT'),x.value('@Gender','NVARCHAR(50)')  
  ,CONVERT(FLOAT,x.value('@Birthday','datetime')),CONVERT(FLOAT,x.value('@Anniversary','datetime')),x.value('@PreferredID','INT') ,x.value('@PreferredName','NVARCHAR(50)')   
  from  @XML.nodes('Row') as data(x)  
 end  
  
  --WorkFlow
Declare @CStatusID int
Declare @level int,@maxLevel int
SET @CStatusID=0
if(@LeadID>0)
	BEGIN
		SELECT @CStatusID=ISNULL(StatusID,0) FROM CRM_Leads WITH(NOLOCK) where LeadID=@LeadID
	END

  	if(@WID>0)	 
	  BEGIN
		set @level=(SELECT  top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
		where WorkFlowID=@WID and  UserID =@UserID)
		if(@level is null )
			set @level=(SELECT top 1 LevelID FROM [COM_WorkFlow]  WITH(NOLOCK)  
			where WorkFlowID=@WID and  RoleID =@RoleID)

		if(@level is null ) 
			set @level=(SELECT top 1  LevelID FROM [COM_WorkFlow]   WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) where UserID=@UserID))

		if(@level is null )
			set @level=( SELECT top 1  LevelID FROM [COM_WorkFlow] WITH(NOLOCK) 
			where WorkFlowID=@WID and  GroupID in (select GroupID from COM_Groups WITH(NOLOCK) 
			where RoleID =@RoleID))

		select @maxLevel=max(LevelID) from COM_WorkFlow WITH(NOLOCK)  where WorkFlowID=@WID  
		select @level,@maxLevel
		if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
		begin 
		 	set @StatusID=1001 
		end	
		else if(@level is not null and  @maxLevel is not null and @LeadID>0 and @level<@maxLevel and @CStatusID in (1003))--rejected status time
		begin	
		 	set @StatusID=1001 
		end			 
		 
	end

 IF @LeadID= 0--------START INSERT RECORD-----------    
 BEGIN--CREATE Lead    
  DECLARE @lft INT,@rgt INT,@Depth int,@ParentID INT,@SelectedIsGroup int,@Selectedlft INT,@Selectedrgt INT  
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
     
  INSERT INTO CRM_Leads(CodePrefix,CodeNumber,Code,[Subject],[Date],StatusId,Company,SourceLookUpID  
  ,RatinglookupID,IndustryLookUpID,CampaignID,CampaignResponseID,CampaignActivityID,[Description]  
  ,Depth,ParentID,lft,rgt,IsGroup,CompanyGUID,[GUID],CreatedBy,CreatedDate,Mode,SelectedModeID,ContactID,WorkFlowID,WorkFlowLevel)  
  Values (@CodePrefix,@CodeNumber,@LeadCode,@Subject,convert(float,@Date),@StatusID,@Company,@SourceID  
  ,@RatingID,@IndustryID,@CampaignID,1,1,@Description  
  ,@Depth,@ParentID,@lft,@rgt,@IsGroup,@CompanyGUID,newid(),@UserName,@Dt,@Mode,@SelectedModeID,@ContactID,@WID,isnull(@level,0))  
  
  SET @LeadID=SCOPE_IDENTITY()   
  
  insert into CRM_CONTACTS(FeatureID,FeaturePK,Company,StatusID,  
      FirstName,MiddleName,LastName,SalutationID,JobTitle,  
      Phone1,Phone2,Email1,Fax,Department,RoleLookUpID,  
      Address1,Address2,Address3,City,[State],Zip,Country,Gender,  
      Birthday,Anniversary,PreferredID,PreferredName,  
      IsEmailOn,IsBulkEmailOn,IsMailOn,IsPhoneOn,IsFaxOn,IsVisible,  
      [Description],Depth,ParentID,lft,rgt,IsGroup,CompanyGUID,[GUID],CreatedBy,CreatedDate)  
    SELECT 86,@LeadID,@Company,@StatusID,  
     FirstName,MiddleName,LastName,Salutation,jobTitle,  
     Phone1,Phone2,Email,Fax,Department,RoleID,  
     Address1,Address2,Address3,City,[State],Zip,CountryID,Gender,  
     Birthday,Anniversary,PreferredID,PreferredName,  
     @EmailAllow,@BulkEmailAllow,@MailAllow,@PhoneAllow,@FaxAllow,0,  
     @Description,@Depth,@ParentID,@lft,@rgt,@IsGroup,@CompanyGUID,newid(),@UserName,@Dt  
     from @detailtbl,@tabdetailtbl  
  
  DECLARE @Str nvarchar(50), @a int, @val INT,@cnt int, @DIMContact nvarchar(max),  
  @DIMNotes nvarchar(max), @DIMAttachments nvarchar(max),@DimPrimaryContactQuery nvarchar(max)  
  select @Str=isnull(value,'') from com_costcenterpreferences WITH(NOLOCK)  
  where costcenterid=86 and name='CopyDimensionData'  
      
  declare @temp table (id int identity(1,1), val int)   
  insert into @temp (val)   
  exec SPSplitString @Str,';'    
    
  set @a=1   
  select @cnt=count(*) from @temp   
  while @a<=@cnt  
  begin  
   set @val=null  
   select @val=val from @temp where id=@a   
   if(@val is null)  
    set @a=@a+1  
   else if(@val=1)  
   begin  
    set @DIMContact=@ContactsXML  
    set @DimPrimaryContactQuery=@PrimaryContactQuery  
   end  
   else if(@val=3)  
    set @DIMNotes=@NotesXML  
   else if(@val=4)  
    set @DIMAttachments=@AttachmentsXML  
    set @a=@a+1  
  end  
     
  IF @Dimesion>0    
  BEGIN  
     
   SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)  
   WHERE CostCenterID=86 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID   
   SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)  
     
   select @CCStatusID = statusid from com_status WITH(NOLOCK) where costcenterid=@Dimesion and [status] = 'Active'  
     
   EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]  
    @NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,  
    @Code = @LeadCode,  
    @Name = @Company,  
    @AliasName=@Company,  
    @PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,  
    @CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=@DIMAttachments,  
    @CustomCostCenterFieldsQuery=NULL,@ContactsXML=@DIMContact,@NotesXML=@DIMNotes,  
    @PrimaryContactQuery=@DimPrimaryContactQuery,  
    @CostCenterID =@Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='GUID',  
    @UserName=@USERNAME,@RoleID=1,@UserID=@USERID  
      
  END    
    
  --Link Dimension Mapping  
  INSERT INTO COM_DocBridge(CostCenterID, NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby,CreatedDate,Abbreviation)  
  values(86,@LeadID,0,0,@Dimesion,@LinkDim_NodeID,'',newid(),@UserName, @dt,'Lead')     
     
  --Handling of Extended Table    
  INSERT INTO CRM_LeadsExtended([LeadID],[CreatedBy],[CreatedDate])    
  VALUES(@LeadID, @UserName, @Dt)    
  
    --INSERT INTO ASSIGNED TABLE   
    if(@AutoAssign=1)  
    begin  
   DECLARE @TEAMNODEID INT=0  
   SELECT TOP(1) @TEAMNODEID =  ISNULL(TeamID,0) FROM CRM_Teams WITH(NOLOCK)   
   WHERE UserID=@UserID AND IsGroup=0   
     
   IF @TEAMNODEID>0  
    EXEC spCRM_SetCRMAssignment 86, @LeadID,@TEAMNODEID,@UserID,0,'','','',@CompanyGUID,@UserName,@LangId  
   else if exists (select ParentNodeid from COM_CostCenterCostCenterMap WITH(NOLOCK) where Parentcostcenterid=7 and costcenterid=7 and Nodeid=@UserID)  
   begin  
    declare @TEMPUSERID INT  
    select @TEMPUSERID=ParentNodeid from COM_CostCenterCostCenterMap WITH(NOLOCK)  
    where Parentcostcenterid=7 and costcenterid=7 and Nodeid=@UserID   
    EXEC spCRM_SetCRMAssignment 86, @LeadID,0,@UserID,0,@TEMPUSERID,'','',@CompanyGUID,@UserName,@LangId  
   end  
  end  
  --ELSE if(@AutoAssign=0)  
  --BEGIN  
  -- EXEC spCRM_SetCRMAssignment 86, @LeadID,0,@UserID,0,@UserID,'','',@CompanyGUID,@UserName,@LangId  
  --END  
    
  --Handling of CostCenter Costcenters Extrafields Table   
  INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])  
  VALUES(86,@LeadID,newid(),  @UserName, @Dt)   
  
  --INSERT PRIMARY CONTACT    
  INSERT [COM_Contacts]([AddressTypeID],[FeatureID],[FeaturePK],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate]  )    
  VALUES(1,86,@LeadID,@CompanyGUID,NEWID(),@UserName,@Dt)    
       
  INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])  
  VALUES(SCOPE_IDENTITY(), @UserName, convert(float,getdate()))  
  
  IF exists(select * from  dbo.ADM_FeatureActionrolemap with(nolock) where RoleID=@RoleID and FeatureActionID=4830)  
  BEGIN    
   UPDATE CRM_LEADS SET IsApproved=1, ApprovedDate=@Dt,ApprovedBy=@UserName  
   where Leadid=@LeadID   
  end  
   --[CRM_History]  
  IF(ISNULL(@Subject,'')<>'')
  BEGIN
	SET @ID=SCOPE_IDENTITY()  
	SET @STATUSNAME=(SELECT STATUS from com_status WITH(nolock) where StatusID=@StatusID)  
	INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,  
          ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)  
	VALUES(@ID,86,@LeadID,0,@UserID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,@RoleID,0,0,0,'',@Subject +' - Status: '+@STATUSNAME,'Approve')  
  END

  if(@WID>0)
	BEGIN	 
		INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
		VALUES(86,@LeadID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
	END
   --[CRM_History]  
 END --------END INSERT RECORD-----------    
 ELSE  --------START UPDATE RECORD-----------    
 BEGIN  
  SELECT @TempGuid=[GUID] from CRM_Leads  WITH(NOLOCK)     
  WHERE LeadID=@LeadID  
  
  IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ      
  BEGIN      
   RAISERROR('-101',16,1)     
  END      
  ELSE      
  BEGIN    
   UPDATE CRM_Leads SET [Code]=@LeadCode  
    ,[Subject]= @Subject  
    ,[Date]=convert(float,@Date)  
    ,[Company]=@Company  
    ,SourceLookUpID=@SourceID  
    ,RatinglookupID=@RatingID  
    ,IndustryLookUpID=@IndustryID  
    ,CampaignID=@CampaignID  
    ,[StatusID] = @StatusID,ContactID=@ContactID  
    ,[Description] = @Description  
    ,[GUID] = @Guid  
    ,[ModifiedBy] = @UserName  
    ,[ModifiedDate] = @Dt,SelectedModeID=@SelectedModeID,Mode=@Mode
	,WorkFlowLevel=isnull(@level,0)
   WHERE LeadID = @LeadID  
     
   select @LinkDim_NodeID = CCLeadID  from CRM_Leads WITH(nolock) where LeadID=@LeadID      
  
   if(@Dimesion>0 and @LinkDim_NodeID is not null and @LinkDim_NodeID <>'' )    
   begin      
    declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)    
    declare @NodeidXML nvarchar(max)     
    select @Table=Tablename from adm_features WITH(nolock) where featureid=@Dimesion    
      
    set @str='@Gid nvarchar(50) output'     
    set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' WITH(nolock) where NodeID='+convert(nvarchar,@LinkDim_NodeID)+')'    
  
    exec sp_executesql @NodeidXML, @str, @Gid OUTPUT     
  
    select @CCStatusID = statusid from com_status WITH(nolock) where costcenterid=@Dimesion and status = 'Active'    
  
    if(@Gid is null  and @LinkDim_NodeID >0)  
     set @LinkDim_NodeID=0  
      
    SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)  
    WHERE CostCenterID=86 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID   
    SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)  
     
    EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]    
    @NodeID = @LinkDim_NodeID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,  
    @Code = @LeadCode,  
    @Name = @Company,  
    @AliasName=@Company,  
    @PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,  
    @CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=@DIMAttachments,  
    @CustomCostCenterFieldsQuery=NULL,@ContactsXML=@DIMContact,@NotesXML=@DIMNotes,  
    @PrimaryContactQuery=@DimPrimaryContactQuery,  
    @CostCenterID =@Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='GUID',  
    @UserName=@USERNAME,@RoleID=1,@UserID=@USERID, @CheckLink = 0      
      
     --[CRM_History]  
    IF(ISNULL(@Subject,'')<>'')
    BEGIN
		SET @ID=SCOPE_IDENTITY()  
		SET @STATUSNAME=(SELECT STATUS from com_status WITH(nolock) where StatusID=@StatusID)  
		INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,  
            ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)  
		VALUES(@ID,86,@LeadID,0,@UserID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,@RoleID,0,0,0,'',@Subject +' - Status: '+@STATUSNAME,'Approve')  
	END
     --[CRM_History]  
   END  
     
   if(@DetailsXML is not null AND @DetailsXML<>'' AND @TabdetailsXML is not null AND @TabdetailsXML<>'')  
   begin  
      
    if not exists (select * from CRM_CONTACTS with(nolock) where FeaturePK=@LeadID and Featureid=86 )  
    begin  
     insert into CRM_CONTACTS (FeaturePK,Featureid,guid,createdby,createddate) values(@LeadID,86,newid(),@UserName,@Dt)  
    end  
      
    Update CRM_CONTACTS set Company=@Company,  
       StatusID=@StatusID,  
       FirstName=T1.FirstName,  
       MiddleName=T1.MiddleName,  
       LastName=T1.LastName,  
       SalutationID=T1.Salutation,  
       JobTitle=T1.jobTitle,  
       Phone1=T1.Phone1,  
       Phone2=T1.Phone2,  
       Email1=T1.Email,  
       Fax=T1.Fax,  
       Department=T1.Department,  
       RoleLookUpID=T1.RoleID,  
       Address1=T2.Address1,  
       Address2=T2.Address2,  
       Address3=T2.Address3,  
       City=T2.City,  
       [State]=T2.[State],  
       Zip=T2.Zip,  
       Country=T2.CountryID,  
       Gender=T2.Gender,  
       Birthday=T2.Birthday,  
       Anniversary=T2.Anniversary,  
       PreferredID=T2.PreferredID,  
       PreferredName=T2.PreferredName,  
       IsEmailOn=@EmailAllow,  
       IsBulkEmailOn=@BulkEmailAllow,  
       IsMailOn=@MailAllow,  
       IsPhoneOn=@PhoneAllow,  
       IsFaxOn=@FaxAllow  
    from @detailtbl T1,@tabdetailtbl T2  
    where FeaturePK=@LeadID and Featureid=86   
   end  
  END  
 END   
    
    set @UpdateSql='update COM_CCCCDATA  SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +'   
    WHERE NodeID = '+convert(nvarchar,@LeadID) + ' AND CostCenterID = 86'   
 exec(@UpdateSql)    
      
    --Update Extra fields  
 set @UpdateSql='update [CRM_LeadsExtended] SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName  
    +''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE LeadID='+convert(nvarchar,@LeadID)  
 exec(@UpdateSql)   
   
 --Duplicate Check  
 exec [spCOM_CheckUniqueCostCenter] @CostCenterID=86,@NodeID =@LeadID,@LangID=@LangID  
   
    --Series Check  
 declare @retSeries INT  
 EXEC @retSeries=spCOM_ValidateCodeSeries 86,@LeadID,@LangId  
 if @retSeries>0  
 begin  
  ROLLBACK TRANSACTION  
  SET NOCOUNT OFF    
  RETURN -999  
 end    
  
    IF  @FeedbackXML IS NOT NULL AND @FeedbackXML<>''  
 BEGIN  
  SET @XML=@FeedbackXML  
   
  Delete from CRM_FEEDBACK where CCNodeID = @LeadID and CCID=86  
    
	SET @Sql=''
	SET @UpdateSql=''
	select @Sql=@Sql+',['+name+']' 
	,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
	from sys.columns  WITH(NOLOCK)
	where object_id=object_id('CRM_FEEDBACK') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
		
	SET @Sql='INSERT into CRM_FEEDBACK(CCID,CCNodeID,Date,Feedback,CreatedBy,CreatedDate'+@Sql+')
	select 86,@LeadID,  
	convert(float,x.value(''@Date'',''datetime'')),x.value(''@FeedBack'',''nvarchar(max)''),x.value(''@CreatedBy'',''nvarchar(200)'') ,'+CONVERT(NVARCHAR,convert(float,@Dt))+'
	'+@UpdateSql+'
	from @XML.nodes(''XML/Row'') as data(x)'

	EXEC sp_executesql @SQL,N'@XML XML,@LeadID INT',@XML,@LeadID          
 END  
   
 IF  @CVRXML IS NOT NULL AND @CVRXML<>''  
 BEGIN  
  SET @XML=@CVRXML  
   
  Delete from CRM_LeadCVRDetails where CCNodeID = @LeadID and CCID=86  
   SET @Sql=''
	SET @UpdateSql=''
	select @Sql=@Sql+',['+name+']' 
	,@UpdateSql=@UpdateSql+',X.value(''@'+name+''',''nvarchar(200)'')' 
	from sys.columns  WITH(NOLOCK)
	where object_id=object_id('CRM_LeadCVRDetails') and name LIKE 'Alpha%'

	SET @Sql=' INSERT into CRM_LeadCVRDetails (CCID,CCNodeID,Date,Product,TechnicalInfo,CommercialInfo,CreatedBy,CreatedDate'+@Sql+') 
     select 86,@LeadID,convert(float,x.value(''@Date'',''datetime'')),x.value(''@Product'',''Int''),x.value(''@Technical'',''nvarchar(MAX)''),x.value(''@Commercial'',''nvarchar(MAX)''), '''+@UserName+''','+convert(nvarchar,@Dt)+'
       '+@UpdateSql+' 
     from @XML.nodes(''XML/Row'') as data(x) ' 
	
	EXEC sp_executesql @SQL,N'@XML XML,@LeadID INT',@XML,@LeadID      
 END  
    
 exec spCom_SetActivitiesAndSchedules @ActivityXml,86,@LeadID,@CompanyGUID,@Guid,@UserName,@dt,@LangID   
  
 IF(@PrimaryContactQuery IS NOT NULL AND @PrimaryContactQuery<>'')  
 BEGIN    
  --CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE  
  EXEC spCOM_SetFeatureWiseContacts 86,@LeadID,1,@PrimaryContactQuery,@UserName,@Dt,@LangID  
 END  
    
 --Inserts Multiple Contacts    
 IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')    
 BEGIN    
  --CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE  
  EXEC @return_value =  spCOM_SetFeatureWiseContacts 86,@LeadID,2,@ContactsXML,@UserName,@Dt,@LangID    
  IF @return_value=-1000    
  BEGIN    
   RAISERROR('-500',16,1)    
  END     
 END    
    
 --Inserts Multiple Notes    
 IF (@NotesXML IS NOT NULL AND @NotesXML <> '')    
 BEGIN    
  SET @XML=@NotesXML    
  
  --If Action is NEW then insert new Notes    
  INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,[GUID],CreatedBy,CreatedDate)    
  SELECT 86,86,@LeadID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~',''),newid(),@UserName,@Dt    
  FROM @XML.nodes('/NotesXML/Row') as Data(X)    
  WHERE X.value('@Action','NVARCHAR(10)')='NEW'   
  
  --[CRM_History]  
  SET @ID=SCOPE_IDENTITY()  
  INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,  
          ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)  
          SELECT @ID,86,@LeadID,0,@UserID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,@RoleID,0,0,0,'','Note : '+Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','')+' - Status: '+'NEW','Notes'
            FROM @XML.nodes('/NotesXML/Row') as Data(X)    
  WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
   --[CRM_History]  
  
  --If Action is MODIFY then update Notes    
  UPDATE COM_Notes SET Note=Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','')  
  ,[GUID]=newid(),ModifiedBy=@UserName,ModifiedDate=@Dt    
  FROM COM_Notes C WITH(NOLOCK)    
  INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)      
  ON convert(INT,X.value('@NoteID','INT'))=C.NoteID    
  WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
  
  --[CRM_History]  
  SET @ID=SCOPE_IDENTITY()  
  INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,  
          ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)  
          SELECT @ID,86,@LeadID,0,@UserID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,@RoleID,0,0,0,'','Note : '+Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','')+' - Status: '+'MODIFY','Notes'
            FROM @XML.nodes('/NotesXML/Row') as Data(X)    
  WHERE X.value('@Action','NVARCHAR(10)')='MODIFY'  
   --[CRM_History]    
  
  --If Action is DELETE then delete Notes  
  --[CRM_History]  
  SET @Remarks=(SELECT ISNULL(C.NOTE,'') FROM COM_Notes C WITH(NOLOCK)    
  INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)      
  ON convert(INT,X.value('@NoteID','INT'))=C.NoteID AND X.value('@Action','NVARCHAR(10)')='DELETE'  )
  
  IF(ISNULL(@Remarks,'')<>'')
  BEGIN
	SET @ID=SCOPE_IDENTITY()  
	INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,  
          ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)  
          SELECT @ID,86,@LeadID,0,@UserID,0,CONVERT(FLOAT,GETDATE()),@UserName ,@CompanyGUID,@RoleID,0,0,0,'','Note : '+ @Remarks +' - Status: '+'DELETE','Notes'
  END
  --  
  DELETE FROM COM_Notes    
  WHERE NoteID IN(SELECT X.value('@NoteID','INT')     
  FROM @XML.nodes('/NotesXML/Row') as Data(X)    
  WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
  
 END    
    
 --Inserts Multiple Attachments    
 IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')    
  exec [spCOM_SetAttachments] @LeadID,86,@AttachmentsXML,@UserName,@Dt     
   
    if(@ProductXML is not null and @ProductXML <> '')  
 begin   
  SET @XML=@ProductXML  
    
  Delete from CRM_ProductMapping where CCNodeID = @LeadID and CostCenterID=86  
     
  SET @Sql=''
	SET @UpdateSql=''
	select @Sql=@Sql+',['+name+']' 
	,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'INT' ELSE 'nvarchar(200)' END+''')' 
	from sys.columns  WITH(NOLOCK)
	where object_id=object_id('CRM_ProductMapping') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')

	SET @Sql='INSERT into CRM_ProductMapping(CCNodeID,CostCenterID,ProductID,CRMProduct,UOMID,Description,
	   Quantity,CurrencyID,CompanyGUID,GUID,CreatedBy,CreatedDate'+@Sql+')
	   select @LeadID,86,
	   x.value(''@Product'',''INT''), x.value(''@CRMProduct'',''INT''),
	   x.value(''@UOM'',''INT''), x.value(''@Desc'',''nvarchar(MAX)''),
	   x.value(''@Qty'',''float''),ISNULL(x.value(''@Currency'',''INT''),1)
	   ,'''+@CompanyGUID+''',newid(),'''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+@UpdateSql+' 
	   from @XML.nodes(''XML/Row'') as data(x)
	   where  x.value(''@Product'',''INT'')is not null and   x.value(''@Product'',''INT'') <> '''' ' 
	
	EXEC sp_executesql @SQL,N'@XML XML,@LeadID INT',@XML,@LeadID 
 end  
  
 --Insert Notifications  
 EXEC spCOM_SetNotifEvent @ActionType,86,@LeadID,@CompanyGUID,@UserName,@UserID,@RoleID  
   
 IF @StatusID=416 --FOR CLOSED LEAD  
 BEGIN  
  EXEC spCOM_SetNotifEvent -1015,86,@LeadID,@CompanyGUID,@UserName,@UserID,@RoleID  
 END  
 --validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=86 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 86,@LeadID,@UserID,@LangID
	end  
 --UPDATE LINK DATA  
 if(@LinkDim_NodeID>0)  
 begin  
  UPDATE CRM_Leads SET CCLeadID=@LinkDim_NodeID    
  WHERE LeadID=@LeadID    
    
  set @UpdateSql='update COM_CCCCDATA    
  SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@LinkDim_NodeID)+'  WHERE NodeID = '+  
  convert(nvarchar,@LeadID) + ' AND CostCenterID = 86'   
  EXEC (@UpdateSql)  
  
  Exec [spDOC_SetLinkDimension]  
   @InvDocDetailsID=@LeadID,   
   @Costcenterid=86,           
   @DimCCID=@Dimesion,  
   @DimNodeID=@LinkDim_NodeID,  
   @UserID=@UserID,      
   @LangID=@LangID    
 end  
  --ROLLBACK TRANSACTION  
   
COMMIT TRANSACTION  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @LeadID  
END TRY      
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
    if @return_value=-999  
  return -999;  
 IF ERROR_NUMBER()=50000    
 BEGIN    
  IF ISNUMERIC(ERROR_MESSAGE())=1  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
   WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
  END  
  ELSE  
   SELECT ERROR_MESSAGE() ErrorMessage  
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine   
  FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine   
  FROM COM_ErrorMessages WITH(nolock)    
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
