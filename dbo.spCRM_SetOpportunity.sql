USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetOpportunity]
	@OpportunityID [int] = 0,
	@Code [nvarchar](200) = null,
	@Subject [nvarchar](200) = NULL,
	@Description [nvarchar](500) = NULL,
	@StatusID [int],
	@IsGroup [bit],
	@SelectedNodeID [int],
	@ContactType [int] = 0,
	@Date [datetime] = null,
	@Leadid [int] = 0,
	@Contactid [int] = 0,
	@Campaignid [int] = 0,
	@Company [nvarchar](500),
	@EstimateRevenue [nvarchar](500) = NULL,
	@Currency [int] = 0,
	@EstimateCloseDate [datetime] = null,
	@Probabilityid [int] = 0,
	@Ratingid [int] = 0,
	@CloseDate [datetime] = null,
	@ProductXML [nvarchar](max) = null,
	@DocumentXML [nvarchar](max) = null,
	@ActivityXml [nvarchar](max) = null,
	@Details [nvarchar](max) = null,
	@Reasonid [int] = 0,
	@CustomFieldsQuery [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@NotesXML [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@FeedbackXML [nvarchar](max) = null,
	@ContactsXML [nvarchar](max) = null,
	@PrimaryContactQuery [nvarchar](max),
	@Mode [int] = 0,
	@SelectedModeID [int] = 0,
	@tabdetails [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@GUID [varchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LoginRoleID [int] = 0,
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
 
	DECLARE @UpdateSql nvarchar(max),@Dt FLOAT, @lft INT,@rgt INT,@TempGuid nvarchar(50),@Selectedlft INT,@Selectedrgt INT,@HasAccess bit,@IsDuplicateNameAllowed bit,@IsOpportunityCodeAutoGen bit  ,@IsIgnoreSpace bit  ,
	@Depth int,@ParentID INT,@SelectedIsGroup int ,@ActionType INT,  @XML XML,@DetailXML XML,@ParentCode nvarchar(200),@DetailContact int
	Declare @CostCenterID int,@return_value int,@LinkDim_NodeID INT,@Dimesion INT ,@RefSelectedNodeID INT ,@CCStatusID INT
	declare @LocalXml XML ,@DOCXML XML,@oppid int,@TabXML XML,@sql NVARCHAR(MAX) 
	declare @ScheduleID int,@MaxCount int, @Count int, @stract nvarchar(max), @isRecur bit, @strsch nvarchar(max), @feq int
	set @CostCenterID=89
		
	set @TabXML =@tabdetails 
	set @DetailXML =@Details
	IF EXISTS(SELECT OpportunityID FROM CRM_Opportunities WITH(nolock) WHERE OpportunityID=@OpportunityID AND ParentID=0)  
	BEGIN  
		RAISERROR('-123',16,1)  
	END  
	
	CREATE TABLE #tblActivities (rowno int ,ActivityID	INT,ActivityTypeID	int,ScheduleID	int,CostCenterID	int,NodeID	int,
Status	int,Subject	nvarchar(MAX),Priority	int,PctComplete	float,Location	nvarchar(max),IsAllDayActivity	bit,
ActualCloseDate	float,ActualCloseTime	varchar(20),CustomerID	nvarchar(max),Remarks	nvarchar(MAX),AssignUserID	INT,
AssignRoleID	INT,AssignGroupID	INT,Name	nvarchar(200),StatusID	int,
FreqType	int,FreqInterval	int,FreqSubdayType	int,FreqSubdayInterval	int,FreqRelativeInterval	int,
FreqRecurrenceFactor	int,StartDate	nvarchar(20),EndDate	nvarchar(20),StartTime	nvarchar(20),
EndTime	nvarchar(20),Message	nvarchar(MAX),isRecur bit)

  --GETTING PREFERENCE  
  SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=89 and  Name='DuplicateNameAllowed'  
  SELECT @IsOpportunityCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=89 and  Name='CodeAutoGen'  
  SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=89 and  Name='IgnoreSpaces'  
  SELECT @Dimesion=ISNULL([Value],0) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE FeatureID=89 AND [Name]='LinkDimension'
			
    IF @IsCode=1 and @IsOpportunityCodeAutoGen IS NOT NULL AND @IsOpportunityCodeAutoGen=1 AND @OpportunityID=0 and @CodePrefix=''  
	BEGIN 
		--CALL AUTOCODEGEN 
		create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
		if(@SelectedNodeID is null)
		insert into #temp1
		EXEC [spCOM_GetCodeData] 89,1,''  
		else
		insert into #temp1
		EXEC [spCOM_GetCodeData] 89,@SelectedNodeID,''  
		--select * from #temp1
		select @Code=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 WITH(nolock)
		--select @AccountCode,@ParentID
	END	
	  --User acces check FOR ACCOUNTS  
  IF @OpportunityID=0  
  BEGIN
	SET @ActionType=1
   SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,89,1)  
  END  
  ELSE  
  BEGIN  
	SET @ActionType=3
   SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,89,3)  
  END  
  
  IF @HasAccess=0  
  BEGIN  
   RAISERROR('-105',16,1)  
  END  
  
  IF @MODE=0
  BEGIN
  --DUPLICATE CHECK  
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
  BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
   BEGIN  
    IF @OpportunityID=0  
    BEGIN  
     IF EXISTS (SELECT OpportunityID FROM CRM_Opportunities WITH(nolock) WHERE replace(Company,' ','')=replace(@Company,' ','') AND MODE=0)  
     BEGIN  
      RAISERROR('-112',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT OpportunityID FROM CRM_Opportunities WITH(nolock) WHERE replace(Company,' ','')=replace(@Company,' ','')  AND MODE=0 AND OpportunityID <> @OpportunityID)  
     BEGIN  
      RAISERROR('-112',16,1)       
     END  
    END  
   END  
   ELSE  
   BEGIN  
    IF @OpportunityID=0  
    BEGIN  
     IF EXISTS (SELECT OpportunityID FROM CRM_Opportunities WITH(nolock) WHERE Company=@Company AND MODE=0 )  
     BEGIN  
      RAISERROR('-112',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT OpportunityID FROM CRM_Opportunities WITH(nolock) WHERE Company=@Company  AND MODE=0 AND OpportunityID <> @OpportunityID)  
     BEGIN  
      RAISERROR('-112',16,1)  
     END  
    END  
   END
  END	  
END  
   --User acces check FOR Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,89,8)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  
  --User acces check FOR Attachments  
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')    
	BEGIN    
		SET @XML=@AttachmentsXML
		SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,89,12)    

		IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW') and @HasAccess=0     
		BEGIN    
			RAISERROR('-105',16,1)    
		END 
		
		SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,89,14)    

		IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='MODIFY') and @HasAccess=0     
		BEGIN    
			RAISERROR('-105',16,1)    
		END 
		
		SET @HasAccess=dbo.fnCOM_HasAccess(@LoginRoleID,89,15)    

		IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE') and @HasAccess=0     
		BEGIN    
			RAISERROR('-105',16,1)    
		END 
	END 
  
	SET @Dt=convert(float,getdate())--Setting Current Date  

	set @DOCXML=@DocumentXML
	set @oppid=@OpportunityID


  declare 
 @FirstName NVARCHAR(50),
 @MiddleName NVARCHAR(50),
 @LastName NVARCHAR(50),
 @Salutation INT,
 @jobTitle NVARCHAR(50),
 @Phone1 NVARCHAR(50),
 @Phone2 NVARCHAR(50),
 @Email NVARCHAR(50),
 @Fax NVARCHAR(50),
 @Department NVARCHAR(50),
 @RoleID INT,
 @Address1 NVARCHAR(50),
 @Address2 NVARCHAR(50),
 @Address3 NVARCHAR(50),
 @City NVARCHAR(50),
 @State NVARCHAR(50),
 @Zip NVARCHAR(50),
 @CountryID INT,
 @Gender NVARCHAR(50),
 @Birthday datetime,
 @Anniversary datetime,
 @PreferredID INT,
 @PreferredName NVARCHAR(50)

 create table #detailtbl(
 FirstName NVARCHAR(50)  null,
 MiddleName NVARCHAR(50)  null,
 LastName NVARCHAR(50)  null,
 Salutation INT  null,
 jobTitle NVARCHAR(50)  null,
 Phone1 NVARCHAR(50)  null,
 Phone2 NVARCHAR(50)  null,
 Email NVARCHAR(50)  null,
 Fax NVARCHAR(50)  null,
 Department NVARCHAR(50)  null,
 RoleID INT  null)

 if(@DetailXML is not null)
 begin
 insert into #detailtbl
 select x.value('@FirstName','NVARCHAR(50)'),x.value('@MiddleName','NVARCHAR(50)'),x.value('@LastName','NVARCHAR(50)'),x.value('@Salutation','INT'),
 x.value('@JobTitle','NVARCHAR(50)'),x.value('@Phone1','NVARCHAR(50)'),x.value('@Phone2','NVARCHAR(50)'),x.value('@Email','NVARCHAR(50)'),x.value('@Fax','NVARCHAR(50)'),
 x.value('@Department','NVARCHAR(50)'),x.value('@Role','INT') from  @DetailXML.nodes('Row') as data(x)
 end
   create table #tabdetailtbl(
 Address1 NVARCHAR(50) null,
 Address2 NVARCHAR(50) null,
 Address3 NVARCHAR(50) null,
 City NVARCHAR(50) null,
 State NVARCHAR(50) null,
 Zip NVARCHAR(50) null,
 CountryID INT null 
  )
 
 if(@TabXML is not null)
 begin
 insert into #tabdetailtbl
 select x.value('@Address1','NVARCHAR(50)'),x.value('@Address2','NVARCHAR(50)'),x.value('@Address3','NVARCHAR(50)'),
 x.value('@City','NVARCHAR(50)'),x.value('@State','NVARCHAR(50)'),x.value('@Zip','NVARCHAR(50)'),x.value('@Country','INT') 
 from  @TabXML.nodes('Row') as data(x)
 end

 select @FirstName=FirstName,@MiddleName=MiddleName,@LastName=LastName,@Salutation=Salutation,@jobTitle=jobTitle,@Phone1=Phone1,@Phone2=Phone2,
 @Email=Email,@Fax=Fax,@Department=Department,@RoleID=RoleID from #detailtbl WITH(nolock)

  select @Address1=Address1,
 @Address2 =Address2,
 @Address3 =Address3,
 @City =City,
 @State =State,
 @Zip =Zip,
 @CountryID =CountryID 
  from #tabdetailtbl WITH(nolock)
 
IF @CountryID='' OR @CountryID IS NULL
 SET @CountryID=NULL

    	--WorkFlow
Declare @CStatusID int
Declare @level int,@maxLevel int
SELECT @CStatusID=ISNULL(StatusID,0) FROM CRM_Opportunities WITH(NOLOCK) where OpportunityID=@OpportunityID
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
		else if(@level is not null and  @maxLevel is not null and @OpportunityID>0 and @level<@maxLevel and @CStatusID in (1003))--rejected status time
		begin	
		 	set @StatusID=1001 
		end			 
		 
	end
		   
   PRINT '@Status'
   PRINT  @StatusID
	 IF @OpportunityID= 0--------START INSERT RECORD-----------  
		BEGIN--CREATE Lead  
  	  --To Set Left,Right And Depth of Record  
				SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				from CRM_Opportunities with(NOLOCK) where OpportunityID=@SelectedNodeID  
			   
				--IF No Record Selected or Record Doesn't Exist  
				if(@SelectedIsGroup is null)   
				 select @SelectedNodeID=LeadID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				 from CRM_Opportunities with(NOLOCK) where ParentID =0  
			         
				if(@SelectedIsGroup = 1)--Adding Node Under the Group  
				 BEGIN  
				  UPDATE CRM_Opportunities SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
				  UPDATE CRM_Opportunities SET lft = lft + 2 WHERE lft > @Selectedlft;  
				  set @lft =  @Selectedlft + 1  
				  set @rgt = @Selectedlft + 2  
				  set @ParentID = @SelectedNodeID  
				  set @Depth = @Depth + 1  
				 END  
				else if(@SelectedIsGroup = 0)--Adding Node at Same level  
				 BEGIN  
				  UPDATE CRM_Opportunities SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
				  UPDATE CRM_Opportunities SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
  
     
			if(@ContactType IS NOT NULL AND @ContactType <> '' AND @ContactType <> 53)
				begin
					set @DetailContact = 1
				end
	    	else
		    	begin
					set @DetailContact = 1
				end
									
					set @GUID= NEWID()
				
				 INSERT INTO CRM_Opportunities
						(DetailsContactID,
					     CodePrefix,CodeNumber,Code,
						 Subject,
						 StatusID,
						 Date,LeadID,CampaignID,Company,EstimatedRevenue,CurrencyID,EstimatedCloseDate,ProbabilityLookUpID,RatingLookUpID,
						 CloseDate,ReasonLookUpID,Description
						,Depth
						,ParentID
						,lft
						,rgt
						,IsGroup
						,CompanyGUID
						,GUID
						,CreatedBy
						,CreatedDate,Mode,SelectedModeID,ContactID,WorkFlowID,WorkFlowLevel)
				Values 
						(@DetailContact,
						@CodePrefix,@CodeNumber,@Code,
						@Subject,
						@StatusID,
						convert(float,@Date),
						@Leadid,
						@Campaignid,
						@Company,
						@EstimateRevenue,
						@Currency,
						convert(float,@EstimateCloseDate),
						@Probabilityid,
						@Ratingid,
						convert(float,@CloseDate),
						@Reasonid,
						@Description
						,@Depth
						,@ParentID
						,@lft
						,@rgt
						,@IsGroup
						,@CompanyGUID
						,newid()
						,@UserName
						,convert(float,@Dt),@Mode,@SelectedModeID,@ContactID,@WID,ISNULL(@level,0))
				 
				 SET @OpportunityID=SCOPE_IDENTITY() 
				 
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
           Department  
           ,CompanyGUID
           ,GUID
           ,CreatedBy
           ,CreatedDate, Address1,
           Address2,
           Address3,
           City,
           State,
           Zip,
           Country)
          values
          (89,@OpportunityID,
          @FirstName,
          @MiddleName,
          @LastName,
          @Salutation,
          @jobTitle,
          @Company,
          @StatusID,
          @Phone1,
          @Phone2,
          @Email,
          @Fax,
          @Department  
          ,@CompanyGUID
          ,newid()
          ,@UserName
          ,convert(float,@Dt),@Address1,
          @Address2,
          @Address3,
          @City,
          @State,
          @Zip,
          @CountryID)



				  --Handling of Extended Table  
    INSERT INTO CRM_OpportunitiesExtended(OpportunityID,[CreatedBy],[CreatedDate])  
    VALUES(@OpportunityID, @UserName, @Dt)  
  
    --Handling of CostCenter Costcenters Extrafields Table 

   INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
     VALUES(89,@OpportunityID,newid(),  @UserName, @Dt) 

		IF @Dimesion>0 
		BEGIN
			SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
			WHERE CostCenterID=89 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
			SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
			
			select @CCStatusID = statusid from com_status WITH(NOLOCK) where costcenterid=@Dimesion and [status] = 'Active'
		
			EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]
				@NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = 0,
				@Code = @Code,
				@Name = @Company,
				@AliasName=@Company,
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
				@CostCenterID =@Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='GUID',@UserName=@USERNAME,@RoleID=1,@UserID=@USERID
		END
		
		--Link Dimension Mapping
		INSERT INTO COM_DocBridge(CostCenterID, NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby,CreatedDate,Abbreviation)
		values(89,@OpportunityID,0,0,@Dimesion,@LinkDim_NodeID,'',newid(),@UserName, @dt,'Cases')   
		
		 --INSERT PRIMARY CONTACT  
		INSERT  [COM_Contacts]  
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
		,89  
		,@OpportunityID  
		,@CompanyGUID  
		,NEWID()  
		,@UserName,@Dt  
		)  
		INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 		VALUES(SCOPE_IDENTITY(), @UserName, convert(float,getdate()))
				 	
	if(@WID>0)
		BEGIN	 
			INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
			VALUES(89,@OpportunityID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
		END			

		END --------END INSERT RECORD-----------  
	ELSE  --------START UPDATE RECORD----------- 	
		BEGIN
			 SELECT @TempGuid=[GUID] from CRM_Opportunities  WITH(NOLOCK)   
			   WHERE OpportunityID=@OpportunityID
			  
			   IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
			   BEGIN    
				   RAISERROR('-101',16,1)   
			   END    
			   ELSE    
			   BEGIN  
  
						UPDATE CRM_Opportunities
					    SET [Code]=@Code,
						[Subject]=@Subject,
						StatusID=@StatusID,
						Date=convert(float,@Date),
						LeadID=@Leadid,ContactID=@ContactID,
						CampaignID=@Campaignid,
						Company=@Company,
						EstimatedRevenue=@EstimateRevenue,
						CurrencyID=@Currency,
						EstimatedCloseDate=convert(float,@EstimateCloseDate),
						ProbabilityLookUpID=@Probabilityid,
						RatingLookUpID=@Ratingid, [ModifiedBy] = @UserName
						,[ModifiedDate] = @Dt,
						CloseDate=convert(float,@CloseDate),SelectedModeID=@SelectedModeID,Mode=@Mode,
						ReasonLookUpID=@Reasonid
						,WorkFlowLevel=isnull(@level,0)
						WHERE OpportunityID = @OpportunityID
						
					       --Update Extra fields
			select @LinkDim_NodeID = CCOpportunityID  from CRM_Opportunities WITH(nolock) where OpportunityID=@OpportunityID    

			if(@Dimesion>0 and @LinkDim_NodeID is not null and @LinkDim_NodeID <>'' )  
			begin    
				declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)  
				declare @NodeidXML nvarchar(max)   
				select @Table=Tablename from adm_features WITH(nolock) where featureid=@Dimesion  
				declare @str nvarchar(max)   
				set @str='@Gid nvarchar(50) output'   
				set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' WITH(nolock) where NodeID='+convert(nvarchar,@LinkDim_NodeID)+')'  

				exec sp_executesql @NodeidXML, @str, @Gid OUTPUT   

				select @CCStatusID = statusid from com_status WITH(nolock) where costcenterid=@Dimesion and status = 'Active'  

				if(@Gid is null	 and @LinkDim_NodeID >0)
					set @LinkDim_NodeID=0
				
				SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
				WHERE CostCenterID=89 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
			
				EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]  
				@NodeID = @LinkDim_NodeID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = 0,
				@Code = @Code,
				@Name = @Company,
				@AliasName=@Company,
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
				@CostCenterID =@Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='GUID',@UserName=@USERNAME,@RoleID=1,@UserID=@USERID, @CheckLink = 0    
				
			END
					  
						 if( @DetailXML is not null)
						  begin
						  Update CRM_CONTACTS set 
						   FirstName=@FirstName,
						   MiddleName=@MiddleName,
						   LastName=@LastName,
						   SalutationID=@Salutation,
						   JobTitle=@jobTitle,
						   Company=@Company,
						   StatusID=@StatusID,
						   Phone1=@Phone1,
						   Phone2=@Phone2,
						   Email1=@Email,Address1=@Address1,
						   Address2=@Address2,
						   Address3=@Address3,
						   City=@City,
						   State=@State,
						   Zip=@Zip,
						   Country=@CountryID,
						   Fax=@Fax,
						   Department=@Department 
						   where FeaturePK=@OpportunityID and Featureid=89 
								end	 
			   END
		  END 
		  
	  		  set @UpdateSql='update [CRM_OpportunitiesExtended]
				  SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName
					+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE OpportunityID='+convert(nvarchar,@OpportunityID)
				 
				  exec(@UpdateSql)
					  
		      set @UpdateSql='update COM_CCCCDATA  
			 SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID = '+convert(nvarchar,@OpportunityID) + ' AND CostCenterID = 89' 
				 exec(@UpdateSql)  
			
		  
   IF  @FeedbackXML IS NOT NULL
	BEGIN
	DECLARE @DATAFEEDBACK XML
	SET @DATAFEEDBACK=@FeedbackXML
	
				Delete from CRM_FEEDBACK where CCNodeID = @OpportunityID and CCID=89
		SET @Sql=''
	 	SET @UpdateSql=''
	 	select @Sql=@Sql+',['+name+']' 
		,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
		from sys.columns  WITH(NOLOCK)
		where object_id=object_id('CRM_FEEDBACK') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
		SET @Sql='INSERT into CRM_FEEDBACK(CCID,CCNodeID,Date,Feedback,CreatedBy,CreatedDate'+@Sql+')
		select 89,@OpportunityID,  
		convert(float,x.value(''@Date'',''datetime'')),x.value(''@FeedBack'',''nvarchar(max)''),x.value(''@CreatedBy'',''nvarchar(200)'') ,'+CONVERT(NVARCHAR,convert(float,@Dt))+'
		'+@UpdateSql+'
		from @XML.nodes(''XML/Row'') as data(x)'
		
		EXEC sp_executesql @SQL,N'@XML XML,@OpportunityID INT',@XML,@OpportunityID 
				    
				   
	END

		  exec spCom_SetActivitiesAndSchedules @ActivityXml,@CostCenterID,@OpportunityID,@CompanyGUID,@Guid,@UserName,@dt,@LangID 
		  set @LocalXml=@ActivityXml
		  
		  Delete from CRM_ProductMapping where CCNodeID = @OpportunityID and CostCenterID=89
		   if(@ProductXML is not null and @ProductXML <> '')
		   begin
					
				set @XML=@ProductXML 
				
				SET @Sql=''
 				SET @UpdateSql=''
				select @Sql=@Sql+',['+name+']' 
				,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'INT' ELSE 'nvarchar(200)' END+''')' 
				from sys.columns  WITH(NOLOCK)
				where object_id=object_id('CRM_ProductMapping') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
				SET @Sql='INSERT into CRM_ProductMapping(CCNodeID,CostCenterID,ProductID,CRMProduct,UOMID,Description,
				   Quantity,CurrencyID,CompanyGUID,GUID,CreatedBy,CreatedDate'+@Sql+')
				   select @OpportunityID,89,
				   x.value(''@Product'',''INT''), x.value(''@CRMProduct'',''INT''),
				   x.value(''@UOM'',''INT''), x.value(''@Desc'',''nvarchar(MAX)''),
				   x.value(''@Qty'',''float''),ISNULL(x.value(''@Currency'',''INT''),1)
				   ,'''+@CompanyGUID+''',newid(),'''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+@UpdateSql+' 
				   from @XML.nodes(''XML/Row'') as data(x)
				   where  x.value(''@Product'',''INT'')is not null and   x.value(''@Product'',''INT'') <> '''' ' 
				
				EXEC sp_executesql @SQL,N'@XML XML,@OpportunityID INT',@XML,@OpportunityID
					
			end

    	  if(@DocumentXML is not null and @DocumentXML <> '')
		begin
			insert into CRM_OpportunityDocMap(OpportunityID,DocID,CompanyGUID,GUID,CreatedBy,CreatedDate)
		    select @OpportunityID,
			       x.value('@DocID','INT'),
				   @CompanyGUID,
				   newid(),
				   @UserName,
				   convert(float,@Dt) 
				   from @DOCXML.nodes('OppDocXML/Row') as data(x)
				   where  x.value('@Action','nvarchar(50)')='NEW'and @oppid=0
		
			update CRM_OpportunityDocMap set 
			DocID= x.value('@DocID','INT')
			from @DOCXML.nodes('OppDocXML/Row') as data(x) 
			where OpportunityID = @OpportunityID and  x.value('@Action','nvarchar(50)')='MODIFY'and @oppid<>0

		end
	--Inserts Multiple Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @XML=@NotesXML  
  
   --If Action is NEW then insert new Notes  
   INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
   GUID,CreatedBy,CreatedDate)  
   SELECT 89,89,@OpportunityID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
'),  
   newid(),@UserName,@Dt  
   FROM @XML.nodes('/NotesXML/Row') as Data(X)  
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
  
   --If Action is MODIFY then update Notes  
   UPDATE COM_Notes  
   SET Note=Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
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
		exec [spCOM_SetAttachments] @OpportunityID,89,@AttachmentsXML,@UserName,@Dt 
  
   -- , BEFORE MODIFIEDBY  REQUIRES A NULL CHECK OF @PrimaryContactQuery 
  IF(@PrimaryContactQuery IS NOT NULL AND @PrimaryContactQuery<>'')
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE
		EXEC spCOM_SetFeatureWiseContacts 89,@OpportunityID,1,@PrimaryContactQuery,@UserName,@Dt,@LangID
  END
  
  --Inserts Multiple Contacts  
  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE 
		 declare @rValue int
		EXEC @rValue =  spCOM_SetFeatureWiseContacts 89,@OpportunityID,2,@ContactsXML,@UserName,@Dt,@LangID   
		 IF @rValue=-1000  
		  BEGIN  
			RAISERROR('-500',16,1)  
		  END   
  END  
  
  
  --Insert Notifications
	EXEC spCOM_SetNotifEvent @ActionType,89,@OpportunityID,@CompanyGUID,@UserName,@UserID,@LoginRoleID
	
	IF EXISTS (SELECT * FROM CRM_Opportunities WITH(nolock) WHERE OpportunityID=@OpportunityID AND CloseDate IS NOT NULL AND LEN(CLOSEDATE)>0)
	BEGIN
			EXEC spCOM_SetNotifEvent -1015,89,@OpportunityID,@CompanyGUID,@UserName,@UserID,@LoginRoleID
	END
	--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=89 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 89,@OpportunityID,@UserID,@LangID
	end  
	--UPDATE LINK DATA
	if(@LinkDim_NodeID>0)
	begin
		UPDATE [CRM_Opportunities] SET CCOpportunityID=@LinkDim_NodeID
		WHERE OpportunityID=@OpportunityID
		
		set @UpdateSql='update COM_CCCCDATA  
		SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@LinkDim_NodeID)+'  WHERE NodeID = '+
		convert(nvarchar,@OpportunityID) + ' AND CostCenterID = 89' 
		EXEC (@UpdateSql)

		Exec [spDOC_SetLinkDimension]
			@InvDocDetailsID=@OpportunityID, 
			@Costcenterid=89,         
			@DimCCID=@Dimesion,
			@DimNodeID=@LinkDim_NodeID,
			@UserID=@UserID,    
			@LangID=@LangID  
	end
	
				

	COMMIT TRANSACTION
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @OpportunityID
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
