USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_SetMachine]
	@ResourceID [bigint],
	@MacCode [nvarchar](500),
	@MacName [nvarchar](500),
	@Cost [float] = 0,
	@Usage [float] = 0,
	@Capacity [float] = 0,
	@Effeciency [float] = 0,
	@ResourceName [nvarchar](50) = NULL,
	@ResourceTypeId [int],
	@StatusID [int],
	@Description [nvarchar](max) = NULL,
	@IsGroup [bit],
	@DbAcc [bigint],
	@CrAcc [bigint],
	@UserName [nvarchar](50),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@PrimaryContactQuery [nvarchar](max),
	@ContactsXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@AddressXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@SelectedNodeID [int],
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION 
BEGIN TRY
SET NOCOUNT ON;

	
	DECLARE @Dt float,@XML xml,@HasAccess bit,@UpdateSql nvarchar(max),@IsDuplicateNameAllowed bit,@IsResCodeAutoGen bit  ,@IsIgnoreSpace bit
    DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint,@SelectedIsGroup int,@ParentCode nvarchar(200)

	-- User acces check FOR Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,71,8)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  
  --User acces check FOR Attachments  
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,71,12)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  
  --User acces check FOR Contacts  
  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,71,16)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  

   SET @Dt=convert(float,getdate())

    --GETTING PREFERENCE  
  SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=71 and  Name='DuplicateNameAllowed'  
  SELECT @IsResCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=71 and  Name='CodeAutoGen'  
  SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=71 and  Name='IgnoreSpaces'  
  
 -- DUPLICATE CHECK  
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
  BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
   BEGIN  
    IF @ResourceID=0  
    BEGIN  
     IF EXISTS (SELECT ResourceId FROM PRD_Resources WITH(nolock) WHERE replace(ResourceName,' ','')=replace(@MacName,' ',''))  
     BEGIN  
      RAISERROR('-107',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ResourceId FROM PRD_Resources WITH(nolock) WHERE replace(ResourceName,' ','')=replace(@MacName,' ','') AND ResourceId <> @ResourceID)  
     BEGIN  
      RAISERROR('-107',16,1)       
     END  
    END  
   END  
   ELSE  
   BEGIN  
    IF @ResourceID=0  
    BEGIN  
     IF EXISTS (SELECT ResourceId FROM PRD_Resources WITH(nolock) WHERE ResourceName=@MacName)  
     BEGIN  
      RAISERROR('-107',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ResourceId FROM PRD_Resources WITH(nolock) WHERE ResourceName=@MacName AND ResourceId <> @ResourceID)  
     BEGIN  
      RAISERROR('-107',16,1)  
     END  
    END  
   END
  END

	IF(@ResourceID=0)
	---New Insert of record
	BEGIN
	  --To Set Left,Right And Depth of Record  
				SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				from [PRD_Resources] with(NOLOCK) where ResourceId=1  
			   
				--IF No Record Selected or Record Doesn't Exist  
				if(@SelectedIsGroup is null)   
				 select @SelectedNodeID=ResourceId,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
				 from [PRD_Resources] with(NOLOCK) where ParentID =0  
			         
				if(@SelectedIsGroup = 1)--Adding Node Under the Group  
				 BEGIN  
				  UPDATE [PRD_Resources] SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
				  UPDATE [PRD_Resources] SET lft = lft + 2 WHERE lft > @Selectedlft;  
				  set @lft =  @Selectedlft + 1  
				  set @rgt = @Selectedlft + 2  
				  set @ParentID = @SelectedNodeID  
				  set @Depth = @Depth + 1  
				 END  
				else if(@SelectedIsGroup = 0)--Adding Node at Same level  
				 BEGIN  
				  UPDATE [PRD_Resources] SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
				  UPDATE [PRD_Resources] SET lft = lft + 2 WHERE lft > @Selectedrgt;  
				  set @lft =  @Selectedrgt + 1  
				  set @rgt = @Selectedrgt + 2   
				 END  
				else  --Adding Root  
				 BEGIN  
				  set @lft =  1  
				  set @rgt = 2   
				  set @Depth = 0  
				  set @ParentID =0  
				  
				 END 
				 --GENERATE CODE  
    IF @IsResCodeAutoGen IS NOT NULL AND @IsResCodeAutoGen=1 AND @ResourceID=0  
    BEGIN  
     SELECT @ParentCode=[ResourceCode]  
     FROM [PRD_Resources] WITH(NOLOCK) WHERE ResourceID=@ParentID    
  
     --CALL AUTOCODEGEN  
     EXEC [spCOM_SetCode] 71,@ParentCode,@MacCode OUTPUT    
    END  

				
				 INSERT INTO PRD_Resources(ResourceCode,ResourceName,StatusId,CreditAccount,DebitAccount,
				 ResourceTypeID,ResourceTypeName,Description,Cost,CostUOMID,ExchgRT,
				 CurrencyID,Capacity,CapacityUOMID,Efficiency,Depth,ParentID,lft,
				 rgt,IsGroup,CompanyGUID,GUID,CreatedBy,CreatedDate,Usage)
				 Values (@MacCode,@MacName,@StatusID,@CrAcc,@DbAcc,
				 @ResourceTypeId,@ResourceName,@Description,@Cost,0,0,
				 0,@Capacity,0,@Effeciency,@Depth,@ParentID,@lft,
				 @rgt,@IsGroup,@CompanyGUID,newid(),@UserName,convert(float,getdate()),@Usage)


				 --To get inserted record primary key  
				  SET @ResourceID=SCOPE_IDENTITY() 


				     --Handling of Extended Table  
    INSERT INTO [PRD_ResourceExtended]([ResourceID],[CreatedBy],[CreatedDate])  
    VALUES(@ResourceID, @UserName, @Dt) 

	  INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
     VALUES(71,@ResourceID,newid(),  @UserName, @Dt) 

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
    ,71  
    ,@ResourceID  
    ,@CompanyGUID  
    ,NEWID()  
    ,@UserName,@Dt  
    )  
        INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 	VALUES(SCOPE_IDENTITY(), @UserName, convert(float,getdate()))
	END
		---Update the PRD_Resource Table
		ELSE
			BEGIN
			Update PRD_Resources
			set ResourceCode =@MacCode,
			ResourceName=@MacName,
			StatusID=@StatusID,
			ResourceTypeID=@ResourceTypeId,
			ResourceTypeName=@ResourceName,
			[Description]=@Description,
			DebitAccount=@DbAcc,
			CreditAccount=@CrAcc,
			Cost=@Cost,
			CostUOMID=0,
			ExchgRT=0,
			CurrencyID=0,
			Capacity=@Capacity,
			CapacityUOMID=0,
			Efficiency=@Effeciency,
			IsGroup=@IsGroup,
			GUID=NEWID(),
			CreatedBy=@UserName,
			CreatedDate=@Dt,
			Usage=@Usage
			WHERE ResourceID=@ResourceID
			END


 
   -- , BEFORE MODIFIEDBY  REQUIRES A NULL CHECK OF @PrimaryContactQuery 
  IF(@PrimaryContactQuery IS NOT NULL AND @PrimaryContactQuery<>'')
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE
		EXEC spCOM_SetFeatureWiseContacts 71,@ResourceID,1,@PrimaryContactQuery,@UserName,@Dt,@LangID
  END

   --Update Extra fields  
  set @UpdateSql='update [PRD_ResourceExtended]  
  SET '+@CustomFieldsQuery+'[ModifiedBy] ='''+ @UserName  
    +''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE ResourceID='+convert(nvarchar,@ResourceID)

	exec(@UpdateSql)  

	
    set @UpdateSql='update COM_CCCCDATA  
	SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID = '+convert(nvarchar,@ResourceID) + ' AND CostCenterID = 71' 
  
  exec(@UpdateSql)   

  --Inserts Multiple Contacts  
   IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE	
		 declare @rValue int
		EXEC @rValue =  spCOM_SetFeatureWiseContacts 71,@ResourceID,2,@ContactsXML,@UserName,@Dt,@LangID   
		 IF @rValue=-1000  
		  BEGIN  
			RAISERROR('-500',16,1)  
		  END   
  END  
  
  	
  --Inserts Multiple Address  
  EXEC spCOM_SetAddress 71,@ResourceID,@AddressXML,@UserName  
  
  --Inserts Multiple Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @XML=@NotesXML  
  
   --If Action is NEW then insert new Notes  
   INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
   GUID,CreatedBy,CreatedDate)  
   SELECT 71,71,@ResourceID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
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
   ON convert(bigint,X.value('@NoteID','bigint'))=C.NoteID  
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
  
   --If Action is DELETE then delete Notes  
   DELETE FROM COM_Notes  
   WHERE NoteID IN(SELECT X.value('@NoteID','bigint')  
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
   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),71,71,@ResourceID,  
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
   ON convert(bigint,X.value('@AttachmentID','bigint'))=C.FileID  
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
  
   --If Action is DELETE then delete Attachments  
   DELETE FROM COM_Files  
   WHERE FileID IN(SELECT X.value('@AttachmentID','bigint')  
    FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)  
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
  END  
  
  COMMIT TRANSACTION    
--SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountID=@AccountID  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @ResourceID    
END TRY    
BEGIN CATCH    
-- Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
 -- SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountID=@AccountID    
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
