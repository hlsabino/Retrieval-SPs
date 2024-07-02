USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetCustomer]
	@CustomerID [int],
	@CustomerCode [nvarchar](200),
	@CustomerName [nvarchar](500),
	@AliasName [nvarchar](50) = null,
	@SelectedTypeId [int] = 0,
	@StatusID [int],
	@AccountID [int],
	@SelectedNodeID [int] = null,
	@IsGroup [bit] = null,
	@CreditDays [int] = 0,
	@CreditLimit [float] = 0,
	@User [varchar](100),
	@Password [varchar](100),
	@OnlineCustType [varchar](100),
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@Description [nvarchar](500) = null,
	@UserName [nvarchar](50),
	@CustomFieldsQuery [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@ContactsXML [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@NotesXML [nvarchar](max) = null,
	@AddressXML [nvarchar](max) = null,
	@ActivityXml [nvarchar](max),
	@AssignCCCCData [nvarchar](max) = null,
	@FromImport [bit] = 0,
	@PrimaryContactQuery [nvarchar](max) = null,
	@RoleID [int] = 0,
	@LangID [int] = 1,
	@CodePrefix [nvarchar](200) = NULL,
	@CodeNumber [int] = 0,
	@IsCode [bit] = 0,
	@WID [int] = 0,
	@UserID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section
		DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50),@HasAccess bit,@IsDuplicateNameAllowed bit,@IsCodeAutoGen bit,@IsIgnoreSpace bit
		DECLARE @UpdateSql nvarchar(max),@ParentCode nvarchar(200)
		DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT
		DECLARE @SelectedIsGroup bit ,  @I INT, @COUNT INT ,@VCOUNT INT

		Declare @CostCenterID int
	declare @LocalXml XML 
	declare @ScheduleID int
 declare @MaxCount int
 
	declare @stract nvarchar(max)
	declare @isRecur bit
		declare @strsch nvarchar(max)
		declare @feq int
	set @CostCenterID=83

		--User acces check FOR Customer 
		IF @CustomerID=0
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,1)
		END
		ELSE
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,3)
		END

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		--User acces check FOR Notes
		IF (@NotesXML IS NOT NULL AND @NotesXML <> '')
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,8)

			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END
		END

		--User acces check FOR Attachments
		IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')    
		BEGIN    
			SET @XML=@AttachmentsXML
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,12)    

			IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
			WHERE X.value('@Action','NVARCHAR(10)')='NEW') and @HasAccess=0     
			BEGIN    
				RAISERROR('-105',16,1)    
			END 
			
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,14)    

			IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
			WHERE X.value('@Action','NVARCHAR(10)')='MODIFY') and @HasAccess=0     
			BEGIN    
				RAISERROR('-105',16,1)    
			END 
			
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,15)    

			IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
			WHERE X.value('@Action','NVARCHAR(10)')='DELETE') and @HasAccess=0     
			BEGIN    
				RAISERROR('-105',16,1)    
			END 
		END  

		--User acces check FOR Contacts
		IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,83,16)

			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END
		END


		--GETTING PREFERENCE
		SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE CostCenterID=83 and  Name='DuplicateNameAllowed'
		SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE CostCenterID=83 and  Name='CodeAutoGen'
		SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=83 and  Name='IgnoreSpaces'  
		IF @IsCode=1 and @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1 AND @CustomerID=0 and @CodePrefix=''  
		BEGIN 
			--CALL AUTOCODEGEN 
			create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
			if(@SelectedNodeID is null)
			insert into #temp1
			EXEC [spCOM_GetCodeData] 83,1,''  
			else
			insert into #temp1
			EXEC [spCOM_GetCodeData] 83,@SelectedNodeID,''  
			
			--select * from #temp1
			select @CustomerCode=code,@CodePrefix= prefix, @CodeNumber=number from #temp1
			--select @AccountCode,@ParentID
		END	
		--DUPLICATE CHECK
		IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0
		BEGIN
			IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
			BEGIN  
				IF @CustomerID=0  
				BEGIN  
				 IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE replace(CustomerName,' ','')=replace(@CustomerName,' ',''))  
				  RAISERROR('-345',16,1)  
				END  
				ELSE  
				BEGIN  
				 IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE replace(CustomerName,' ','')=replace(@CustomerName,' ','') AND CustomerID <> @CustomerID)  
				  RAISERROR('-345',16,1)       
				END  
			END  
			ELSE  
			BEGIN
				IF @CustomerID=0
				BEGIN
					IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE CustomerName=@CustomerName)
					BEGIN
						RAISERROR('-345',16,1)
					END
				END
				ELSE
				BEGIN
					IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE CustomerName=@CustomerName AND CustomerID <> @CustomerID)
					BEGIN
						RAISERROR('-345',16,1)
					END
				END
			END
		END 
		
		
		IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=0
		BEGIN
			IF @CustomerID=0
			BEGIN
				IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE CustomerCode=@CustomerCode)
				BEGIN
					RAISERROR('-116',16,1)
				END
			END
			ELSE
			BEGIN
				IF EXISTS (SELECT CustomerID FROM CRM_Customer WITH(nolock) WHERE CustomerCode=@CustomerCode AND CustomerID <> @CustomerID)
				BEGIN
					RAISERROR('-116',16,1)
				END
			END
		END

		SET @Dt=convert(float,getdate())--Setting Current Date
		  --WorkFlow
Declare @CStatusID int
Declare @level int,@maxLevel int
SELECT @CStatusID=ISNULL(StatusID,0) FROM CRM_Customer WITH(NOLOCK) where CustomerID=@CustomerID
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
		else if(@level is not null and  @maxLevel is not null and @CustomerID>0 and @level<@maxLevel and @CStatusID in (1003))--rejected status time
		begin	
		 	set @StatusID=1001 
		end			 
		 
	end
		IF @CustomerID=0--------START INSERT RECORD-----------
		BEGIN--CREATE Customer--
				
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
						set @rgt =	@Selectedlft + 2
						set @ParentID = @SelectedNodeID
						set @Depth = @Depth + 1
 
					END
				else if(@SelectedIsGroup = 0)--Adding Node at Same level
					BEGIN
						UPDATE CRM_Customer SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
						UPDATE CRM_Customer SET lft = lft + 2 WHERE lft > @Selectedrgt;
						set @lft =  @Selectedrgt + 1
						set @rgt =	@Selectedrgt + 2 
					END
				else  --Adding Root
					BEGIN
						set @lft =  1
						set @rgt =	2 
						set @Depth = 0
						set @ParentID =0
						set @IsGroup=1
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
							[CreatedDate],UserName,Password,OnlineCustType,WorkFlowID,WorkFlowLevel)
							VALUES
							(@CodePrefix,@CodeNumber,@CustomerCode,
							@CustomerName,
							@AliasName,
							@SelectedTypeId,
							@StatusID,
							@AccountID,
							@Depth,
							@ParentID,
							@lft,
							@rgt,
							@IsGroup,
							@CreditDays,
							@CreditLimit, 
							@CompanyGUID,
							newid(),
							@Description,
							@UserName,
							@Dt,@User,@Password,@OnlineCustType,@WID,ISNULL(@level,0))
					
				--To get inserted record primary key
				SET @CustomerID=SCOPE_IDENTITY()
 
	
				--Handling of Extended Table
				INSERT INTO [CRM_CustomerExtended]([CustomerID],[CreatedBy],[CreatedDate])
				VALUES(@CustomerID, @UserName, @Dt)
 
			-- Handling of CostCenter Costcenters Extrafields Table
		 	INSERT INTO COM_CCCCData ([NodeID],CostCenterID, [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
			 VALUES(@CustomerID,83, @UserName, @Dt, @CompanyGUID,newid())

				 
				IF @FromImport=0
				BEGIN
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
				,83
				,@CustomerID
				,@CompanyGUID
				,NEWID()
				,@UserName,@Dt
				)
				INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 	VALUES(SCOPE_IDENTITY(), @UserName, convert(float,getdate()))
			   END

			   if(@WID>0)
		BEGIN	 
			INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
			VALUES(83,@CustomerID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserID,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
		END	
				
 		END--------END INSERT RECORD-----------
		ELSE--------START UPDATE RECORD-----------
		BEGIN	
			print 'Update'	
			IF EXISTS(SELECT CustomerID FROM [CRM_Customer] WHERE CustomerID=@CustomerID AND ParentID=0)
			BEGIN
				RAISERROR('-123',16,1)
			END	  
			SELECT @TempGuid=[GUID] from [CRM_Customer]  WITH(NOLOCK) 
			WHERE CustomerID=@CustomerID

			--IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ  
		--	BEGIN  
		--		   RAISERROR('-101',16,1)	
		--	END  
			--ELSE  
			BEGIN 

 
			 --Delete mapping if any
			 DELETE FROM  COM_CCCCData WHERE NodeID=@CustomerID and CostCenterID=83

			-- Handling of CostCenter Costcenters Extrafields Table
		 	INSERT INTO COM_CCCCData ([NodeID],CostCenterID, [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])
			 VALUES(@CustomerID,83, @UserName, @Dt, @CompanyGUID,newid())

				UPDATE [CRM_Customer]
				   SET [CustomerCode] = @CustomerCode
					  ,[CustomerName] = @CustomerName
					  ,[AliasName] = @AliasName
					  ,[CustomerTypeID]=@SelectedTypeId
					  ,[StatusID] = @StatusID
					  ,[AccountID]=@AccountID
					  ,[IsGroup] = @IsGroup
					  ,[CreditDays] = @CreditDays
					  ,[CreditLimit] = @CreditLimit
					  ,[GUID] =  newid()
					  ,[Description] = @Description   
					  ,[ModifiedBy] = @UserName
					  ,[ModifiedDate] = @Dt
					  ,UserName=@User,Password=@Password
					  ,OnlineCustType=@OnlineCustType
					  ,WorkFlowLevel=isnull(@level,0)
				 WHERE CustomerID=@CustomerID      
			END
	
END
				 --SETTING Customer CODE EQUALS CustomerID IF EMPTY
		IF(@CustomerCode IS NULL OR @CustomerCode='')
		BEGIN
		 
			UPDATE  [CRM_Customer]
			SET [CustomerCode] = @CustomerID
			WHERE CustomerID=@CustomerID   
		 
		END

  -- , BEFORE MODIFIEDBY  REQUIRES A NULL CHECK OF @PrimaryContactQuery 
  IF(@PrimaryContactQuery IS NOT NULL AND @PrimaryContactQuery<>'')
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE
		EXEC spCOM_SetFeatureWiseContacts 83,@CustomerID,1,@PrimaryContactQuery,@UserName,@Dt,@LangID
  END
  
		--Update Extra fields
		set @UpdateSql='update [CRM_CustomerExtended]
		SET '+@CustomFieldsQuery+'[ModifiedBy] ='''+ @UserName
		  +''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE CustomerID ='+convert(nvarchar,@CustomerID)
	print @CustomFieldsQuery
	print @UpdateSql
		exec(@UpdateSql)
	
		
		--Update CostCenter Extra Fields
		set @UpdateSql='update COM_CCCCDATA 
		SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID = '+convert(nvarchar,@CustomerID)+ ' AND CostCenterID = 83 ' 
	
		exec(@UpdateSql)
 
	   --Inserts Multiple Contacts  
	  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
	  BEGIN  
			--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE 
		 declare @rValue int
		EXEC @rValue =  spCOM_SetFeatureWiseContacts 83,@CustomerID,2,@ContactsXML,@UserName,@Dt,@LangID  
		 IF @rValue=-1000  
		  BEGIN  
			RAISERROR('-500',16,1)  
		  END   
	  END  
  

		--Inserts Multiple Address
		EXEC spCOM_SetAddress 83,@CustomerID,@AddressXML,@UserName  

		--Inserts Multiple Notes
		IF (@NotesXML IS NOT NULL AND @NotesXML <> '')
		BEGIN
			SET @XML=@NotesXML

			--If Action is NEW then insert new Notes
			INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,			
			GUID,CreatedBy,CreatedDate)
			SELECT 83,83,@CustomerID,Replace(X.value('@Note','NVARCHAR(max)'),'@~','
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
			exec [spCOM_SetAttachments] @CustomerID,83,@AttachmentsXML,@UserName,@Dt   
			
	--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=83 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 83,@CustomerID,1,@LangID
	end		 
IF @ActivityXml <>'' AND @ActivityXml IS NOT NULL
BEGIN 

exec spCom_SetActivitiesAndSchedules @ActivityXml,83,@CustomerID,@CompanyGUID,@Guid,@UserName,@dt,@LangID 

END	

  IF  (@AssignCCCCData IS NOT NULL AND @AssignCCCCData <> '')   
  BEGIN  
  DECLARE @CCCCCData XML
    SET @CCCCCData=@AssignCCCCData  
    EXEC [spCOM_SetCCCCMap] 83,@CustomerID,@CCCCCData,@UserName,@LangID  
  END  	 

COMMIT TRANSACTION  
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
RETURN @CustomerID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM [CRM_Customer] WITH(nolock) WHERE CustomerID=@CustomerID  
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
