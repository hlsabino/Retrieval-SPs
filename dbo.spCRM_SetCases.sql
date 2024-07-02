USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetCases]
	@CaseID [int] = 0,
	@CaseNumber [nvarchar](200),
	@CaseDate [datetime] = null,
	@CUSTOMER [int] = 0,
	@StatusID [int],
	@IsGroup [bit],
	@SelectedNodeID [int],
	@CASETYPEID [int] = 0,
	@CASEORIGINID [int] = 0,
	@CASEPRIORITYID [int] = 0,
	@SVCCONTRACTID [int] = 0,
	@CONTRACTLINEID [int] = 0,
	@PRODUCTID [int] = 0,
	@SERIALNUMBER [nvarchar](300) = NULL,
	@BillingMethod [int] = 0,
	@SERVICELVLID [int] = 0,
	@Assigned [int] = 0,
	@DESCRIPTION [nvarchar](max) = NULL,
	@SERVICEXML [nvarchar](max) = NULL,
	@ActivityXml [nvarchar](max) = NULL,
	@NotesXML [nvarchar](max) = NULL,
	@AttachmentsXML [nvarchar](max) = NULL,
	@FeedbackXML [nvarchar](max) = NULL,
	@CustomCostCenterFieldsQuery [nvarchar](max) = NULL,
	@CustomCCQuery [nvarchar](max) = NULL,
	@WaveUser [int] = 0,
	@WAVEDATE [datetime] = NULL,
	@COMMENTS [nvarchar](max) = NULL,
	@ProductXML [nvarchar](max) = null,
	@mode [nvarchar](50) = null,
	@RefCCID [int],
	@RefNodeID [int],
	@ContactsXML [nvarchar](max) = NULL,
	@Subject [nvarchar](500) = null,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@CustomerMode [int] = 1,
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangId [int] = 1,
	@CodePrefix [nvarchar](200) = NULL,
	@CodeNumber [int] = 0,
	@IsCode [bit] = 0,
	@WID [int] = 0,
	@AssignXML [nvarchar](max) = NULL
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON   
 BEGIN TRANSACTION  
 BEGIN TRY  
    
    
	DECLARE @Dt FLOAT, @lft INT,@rgt INT,@TempGuid nvarchar(50),@Selectedlft INT,@Selectedrgt INT,@HasAccess bit
	,@IsDuplicateNameAllowed bit,@IsLeadCodeAutoGen bit  ,@IsIgnoreSpace bit  ,@Depth int,@ParentID INT,@SelectedIsGroup int 
	,@ActionType INT, @XML XML,@UpdateSql NVARCHAR(MAX), @AutoAssign bit,@LinkDim_NodeID INT,@Dimesion INT ,@RefSelectedNodeID INT 
	,@CCStatusID INT, @TEAMNODEID INT=0,@level int,@maxLevel int ,@sql NVARCHAR(MAX),@SID INT
	
	IF @CaseID=0    
	BEGIN  
		SET @ActionType=1  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,73,1)    
	END    
	ELSE    
	BEGIN    
		SET @ActionType=3  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,73,3)    
	END    
    
	--User access check   
	IF @HasAccess=0  
	BEGIN  
		RAISERROR('-105',16,1)  
	END  
    
	--GETTING PREFERENCE    
	SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=73 and  Name='DuplicateNameAllowed'    
	SELECT @IsLeadCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=73 and  Name='CodeAutoGen'    
	SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=73 and  Name='IgnoreSpaces'    
	SELECT @AutoAssign=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=73 and  Name='AutoAssign'  
	SELECT @Dimesion=isnull([Value],0) FROM COM_CostCenterPreferences WITH(NOLOCK)   
	WHERE FeatureID=73 AND [Name]='LinkDimension'  
		
  --DUPLICATE CHECK    
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0    
  BEGIN    
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1    
   BEGIN    
    IF @CaseID=0    
    BEGIN    
     IF EXISTS (SELECT CaseNumber FROM CRM_Cases WITH(nolock) WHERE replace(CaseNumber,' ','')=replace(@CaseNumber,' ',''))    
     BEGIN    
      RAISERROR('-203',16,1)    
   END    
    END    
    ELSE    
    BEGIN    
     IF EXISTS (SELECT CaseNumber FROM CRM_Cases WITH(nolock) WHERE replace(CaseNumber,' ','')=replace(@CaseNumber,' ','') AND CaseID <> @CaseID)    
     BEGIN    
      RAISERROR('-203',16,1)         
     END    
    END    
   END    
   ELSE    
   BEGIN    
    IF @CaseID=0    
    BEGIN    
     IF EXISTS (SELECT CaseNumber FROM CRM_Cases WITH(nolock) WHERE CaseNumber=@CaseNumber)    
     BEGIN    
      RAISERROR('-203',16,1)    
     END    
    END    
    ELSE    
    BEGIN    
     IF EXISTS (SELECT CaseNumber FROM CRM_Cases WITH(nolock) WHERE CaseNumber=@CaseNumber AND CaseID <> @CaseID)    
     BEGIN    
      RAISERROR('-203',16,1)    
     END    
    END    
   END  
  END     
    
	--User acces check FOR Notes    
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')    
	BEGIN    
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,73,8)    

		IF @HasAccess=0    
		BEGIN    
			RAISERROR('-105',16,1)    
		END    
	END    
    
	--User acces check FOR Attachments    
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')    
	BEGIN  
		SET @XML=@AttachmentsXML  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,73,12)    

		IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW') and @HasAccess=0     
		BEGIN    
			RAISERROR('-105',16,1)    
		END 
		
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,73,14)    

		IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='MODIFY') and @HasAccess=0     
		BEGIN    
			RAISERROR('-105',16,1)    
		END 
		
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,73,15)    

		IF exists (SELECT X.value('@FilePath','NVARCHAR(500)') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE') and @HasAccess=0     
		BEGIN    
			RAISERROR('-105',16,1)    
		END
		   
	END  
	
	SET @Dt=convert(float,getdate())--Setting Current Date    
    
	IF @CaseID= 0--------START INSERT RECORD-----------    
	BEGIN--CREATE Case    
		 --To Set Left,Right And Depth of Record   
		if(@WID>0)
		begin
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
			
			if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
			begin			
				set @StatusID=1001
			END
		END
	 
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
		from CRM_Cases with(NOLOCK) where CaseID=@SelectedNodeID    
	        
		--IF No Record Selected or Record Doesn't Exist    
		if(@SelectedIsGroup is null)     
		 select @SelectedNodeID=CaseID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
		 from CRM_Cases with(NOLOCK) where ParentID =0    
	              
		if(@SelectedIsGroup = 1)--Adding Node Under the Group    
		 BEGIN    
		  UPDATE CRM_Cases SET rgt = rgt + 2 WHERE rgt > @Selectedlft;    
		  UPDATE CRM_Cases SET lft = lft + 2 WHERE lft > @Selectedlft;    
		  set @lft =  @Selectedlft + 1    
		  set @rgt = @Selectedlft + 2    
		  set @ParentID = @SelectedNodeID    
		  set @Depth = @Depth + 1    
		 END    
		else if(@SelectedIsGroup = 0)--Adding Node at Same level    
		 BEGIN    
		  UPDATE CRM_Cases SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;    
		  UPDATE CRM_Cases SET lft = lft + 2 WHERE lft > @Selectedrgt;    
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
  
		IF @IsCode=1 and @IsLeadCodeAutoGen IS NOT NULL AND @IsLeadCodeAutoGen=1 AND @CaseID=0 and @CodePrefix=''  
		BEGIN 
			--CALL AUTOCODEGEN 
			create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
			if(@SelectedNodeID is null)
				insert into #temp1
				EXEC [spCOM_GetCodeData] 73,1,''  
			else
				insert into #temp1
				EXEC [spCOM_GetCodeData] 73,@SelectedNodeID,''  
			
			select @CaseNumber=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 WITH(nolock)
		END	
	
		IF @CaseNumber='' OR @CaseNumber IS NULL  
			SELECT @CaseNumber=MAX(CASEID)+1 FROM CRM_Cases WITH(nolock)  
		
		INSERT INTO  [CRM_Cases]  
		(CodePrefix,CodeNumber,[CreateDate]    
		,[CaseNumber]  
		,[StatusID]  
		,[CaseTypeLookupID]   
		,[CaseOriginLookupID]   
		,[CasePriorityLookupID]   
		,[CustomerID]  
		,[SvcContractID]  
		,[ContractLineID]  
		,[ProductID]  
		,[SerialNumber]  
		,[ServiceLvlLookupID]   
		,[Description]  
		,[Depth]  
		,[ParentID]  
		,[lft]  
		,[rgt]  
		,[IsGroup]  
		,[CompanyGUID],AssignedTo  
		,[GUID]  
		,[CreatedBy]  
		,[CreatedDate],BillingMethod,Mode,RefCCID,RefNodeID,CustomerMode  , [subject],WorkFlowID,WorkFlowLevel)  
		VALUES  
		(@CodePrefix,@CodeNumber,convert(float,@CaseDate)  
		,@CaseNumber  
		,@StatusID  
		,@CASETYPEID   
		,@CASEORIGINID   
		,@CASEPRIORITYID  
		,@CUSTOMER  
		,@SVCCONTRACTID  
		,@CONTRACTLINEID  
		,@PRODUCTID  
		,@SERIALNUMBER  
		,@SERVICELVLID  
		,@DESCRIPTION  
		,@Depth  
		,@ParentID  
		,@lft  
		,@rgt  
		,@IsGroup  
		,@CompanyGUID,@Assigned  
		,newid()  
		,@UserName  
		,convert(float,@Dt),@BillingMethod,@mode,@RefCCID,@RefNodeID,@CustomerMode ,@Subject,@WID,@level)  
		
		SET @CaseID=SCOPE_IDENTITY()   
    
		--Handling of Extended Table      
		INSERT INTO CRM_CasesExtended(CaseID,[CreatedBy],[CreatedDate])      
		VALUES(@CaseID, @UserName, @Dt)     
	      
		IF @Assigned>0  
			UPDATE [CRM_Cases] SET ASSIGNEDDATE=CONVERT(FLOAT,GETDATE()) WHERE CASEID=@CaseID   
    
		--INSERT INTO ASSIGNED TABLE   
		if(@AutoAssign=1 AND @StatusID NOT IN (1001,1002,1003))
		begin
			SELECT TOP(1) @TEAMNODEID =  ISNULL(TeamID,0) FROM CRM_Teams WITH(nolock) WHERE UserID=@Assigned AND IsGroup=0    
			EXEC spCRM_SetCRMAssignment 73, @CaseID,@TEAMNODEID,@Assigned,0,@Assigned,'','',@CompanyGUID,@UserName,@LangId  
		end
	
		INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])  
		VALUES(73,@CaseID,newid(),  @UserName, @Dt)    
      
		IF (@AssignXML IS NOT NULL AND @AssignXML <> '')  
		BEGIN
			DECLARE @UID INT, @IsTeam bit,@UsersList nvarchar(max)
			,@RolesList nvarchar(max),@GroupsList nvarchar(max)
			
			SET @XML=@AssignXML 
				 
			SELECT @TeamNodeID=A.value('@TeamNodeID','INT')
			,@UID=A.value('@UserID','INT')   
			,@IsTeam=A.value('@isTeam','bit') 
			,@UsersList=A.value('@UsersXML','nvarchar(max)')
			,@RolesList=A.value('@RolesXML','nvarchar(max)')
			,@GroupsList=A.value('@GroupXML','nvarchar(max)')
			from @XML.nodes('/XML/Row') as DATA(A) 
				
			EXEC [spCRM_SetCRMAssignment] 
				   @CCID=73
				  ,@CCNODEID=@CaseID
				  ,@TeamNodeID=@TeamNodeID
				  ,@USERID=@UID
				  ,@IsTeam=@IsTeam
				  ,@UsersList=@UsersList
				  ,@RolesList=@RolesList
				  ,@GroupsList=@GroupsList
				  ,@CompanyGUID=@CompanyGUID
				  ,@UserName=@UserName
				  ,@LangID=@LangID
		END 	
     
		IF @Dimesion>0  
		BEGIN  
			SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
			WHERE CostCenterID=73 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
			SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
			
			select @CCStatusID = statusid from com_status WITH(NOLOCK) where costcenterid=@Dimesion and [status] = 'Active'
			
			EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]
			@NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
			@Code = @CaseNumber,
			@Name = @CaseNumber,
			@AliasName=@CaseNumber,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
			@CustomCostCenterFieldsQuery=@CustomCCQuery,@ContactsXML=NULL,@NotesXML=NULL,
			@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',
			@UserName=@UserName,@RoleID=@RoleID,@UserID=@UserID,@CheckLink = 0
			
		END  
		
		--Link Dimension Mapping
		INSERT INTO COM_DocBridge(CostCenterID, NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby,CreatedDate,Abbreviation)
		values(73,@CaseID,0,0,@Dimesion,@LinkDim_NodeID,'',newid(),@UserName, @dt,'Cases')   
		
		if(@WID>0)
		BEGIN	 
			INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
			VALUES(73,@CaseID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
		end
 
	END --------END INSERT RECORD-----------    
	ELSE  --------START UPDATE RECORD-----------    
	BEGIN  
		SELECT @TempGuid=[GUID] from CRM_Cases  WITH(NOLOCK)     
		WHERE CaseID=@CaseID  
       
		IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ      
		BEGIN      
			RAISERROR('-101',16,1)     
		END      
		ELSE      
		BEGIN   
			UPDATE [CRM_Cases]  
			SET [CreateDate] =CONVERT(float, @CaseDate)  
			,[CaseNumber] = @CaseNumber  
			,[StatusID] = @StatusID  
			,[CaseTypeLookupID] = @CASETYPEID  
			,Mode=@mode  
			,[CaseOriginLookupID] = @CASEORIGINID  
			,AssignedTo =@Assigned  
			,[CasePriorityLookupID] = @CASEPRIORITYID  
			,BillingMethod=@BillingMethod  
			,[CustomerID] = @CUSTOMER  
			,[SvcContractID] = @SVCCONTRACTID  
			,[ContractLineID] = @CONTRACTLINEID  
			,[ProductID] = @PRODUCTID  
			,[SerialNumber] = @SERIALNUMBER  
			,[ServiceLvlLookupID] = @SERVICELVLID  
			,[Description] = @DESCRIPTION   
			,[Subject]=@Subject
			,[GUID] = @Guid  
			,[ModifiedBy] = @UserName  
			,CustomerMode=@CustomerMode
			,[ModifiedDate] = @Dt 
			WHERE CaseID=@CaseID  
			
			select @LinkDim_NodeID = CCCaseID  from [CRM_Cases] WITH(nolock) where CaseID=@CaseID    
			
			---		
			IF(@StatusID=10006)
			BEGIN
				select @SID=convert(INT,isnull(Value,0)) FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=73 and  Name='DefaultCloseStatus'  
				if(@SID is not null and @SID>0)
					UPDATE CRM_Cases SET closedate=convert(float,@Dt), StatusID=@SID,CloseBy=@UserName where CaseID=@CaseID 
				else
					UPDATE CRM_Cases SET closedate=convert(float,@Dt), CloseBy=@UserName where CaseID=@CaseID
			END
			
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
				WHERE CostCenterID=73 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
			
				EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]  
				@NodeID = @LinkDim_NodeID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,  
				@Code = @CaseNumber,  
				@Name = @CaseNumber,  
				@AliasName=@CaseNumber,  
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,  
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML='',  
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=null,@NotesXML=NULL,  
				@CostCenterID = @Dimesion,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1 , @CheckLink = 0    
				
			END

		END  
    END  
    
	IF @BillingMethod=140  
		UPDATE CRM_Cases SET WaiveBy=@WaveUser,WaiveDate=CONVERT(FLOAT,@WAVEDATE),Comments=@COMMENTS WHERE CaseID=@CaseID  
		  
	--Update Extra fields      
	set @UpdateSql='update [CRM_CasesExtended]      
	SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName      
	+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE CaseID='+convert(nvarchar,@CaseID)      
	exec(@UpdateSql)      

	set @UpdateSql='update COM_CCCCDATA    
	SET '+@CustomCCQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
	WHERE NodeID = '+convert(nvarchar,@CaseID) + ' AND CostCenterID = 73 '   
	exec(@UpdateSql)    
      
	IF  @SERVICEXML IS NOT NULL AND @SERVICEXML <> '' 
	BEGIN  
		SET @XML=@SERVICEXML 
		
		DELETE FROM CRM_CaseSvcTypeMap WHERE CASEID=@CaseID  

		INSERT INTO CRM_CaseSvcTypeMap  
		SELECT @CaseID,A.value('@SeviceType','INT'),A.value('@ServiceReasonID','INT')   
		,A.value('@VoiceOfCustomer','nvarchar(max)'),A.value('@NODEID','INT'),A.value('@TechComments','nvarchar(max)'),   
		@UserName,CONVERT(float,getdate()) from @XML.nodes('/XML/Row') as DATA(A)  
	
	END
	
	IF  @FeedbackXML IS NOT NULL AND @FeedbackXML <> '' 
	BEGIN  
		SET @XML=@FeedbackXML  

		Delete from CRM_FEEDBACK where CCNodeID = @CaseID and CCID=73  
		
		SET @Sql=''
	 	SET @UpdateSql=''
	 	select @Sql=@Sql+',['+name+']' 
		,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'nvarchar(200)' ELSE 'INT' END+''')' 
		from sys.columns  WITH(NOLOCK)
		where object_id=object_id('CRM_FEEDBACK') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
		SET @Sql='INSERT into CRM_FEEDBACK(CCID,CCNodeID,Date,Feedback,CreatedBy,CreatedDate'+@Sql+')
		select 73,@CaseID,  
		convert(float,x.value(''@Date'',''datetime'')),x.value(''@FeedBack'',''nvarchar(max)''),x.value(''@CreatedBy'',''nvarchar(200)'') ,'+CONVERT(NVARCHAR,convert(float,@Dt))+'
		'+@UpdateSql+'
		from @XML.nodes(''XML/Row'') as data(x)'
		
		EXEC sp_executesql @SQL,N'@XML XML,@CaseID INT',@XML,@CaseID  

	END  
	
	IF (@ActivityXml IS NOT NULL AND @ActivityXml <> '')  
		exec spCom_SetActivitiesAndSchedules @ActivityXml,73,@CaseID,@CompanyGUID,@Guid,@UserName,@Dt,@LangID   
 
	--Inserts Multiple Notes    
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')    
	BEGIN    
		SET @XML=@NotesXML    

		--If Action is NEW then insert new Notes    
		INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,[GUID],CreatedBy,CreatedDate)    
		SELECT 73,73,@CaseID,Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),  
		newid(),@UserName,@Dt    
		FROM @XML.nodes('/NotesXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'    

		--If Action is MODIFY then update Notes    
		UPDATE C    
		SET C.Note=Replace(X.value('@Note','NVARCHAR(max)'),'@~','
'),  
		C.[GUID]=newid(),    
		C.ModifiedBy=@UserName,    
		C.ModifiedDate=@Dt    
		FROM COM_Notes C WITH(NOLOCK)    
		INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X) ON convert(INT,X.value('@NoteID','INT'))=C.NoteID    
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'    

		--If Action is DELETE then delete Notes    
		DELETE FROM COM_Notes    
		WHERE NoteID IN(SELECT X.value('@NoteID','INT')    
		FROM @XML.nodes('/NotesXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')    

	END    

	--Inserts Multiple Attachments 
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
		exec [spCOM_SetAttachments] @CaseID,73,@AttachmentsXML,@UserName,@Dt   
	
	if(@ProductXML is not null and @ProductXML <> '')  
	begin  
		SET @XML=@ProductXML  
		Delete from CRM_ProductMapping where CCNodeID = @CaseID and CostCenterID=73  
		
		SET @Sql=''
 		SET @UpdateSql=''
		select @Sql=@Sql+',['+name+']' 
		,@UpdateSql=@UpdateSql+',X.value(''@'+name+''','''+CASE WHEN name LIKE 'ccnid%' THEN 'INT' ELSE 'nvarchar(200)' END+''')' 
		from sys.columns  WITH(NOLOCK)
		where object_id=object_id('CRM_ProductMapping') and (name LIKE 'ccnid%' OR name LIKE 'Alpha%')
			
		SET @Sql='INSERT into CRM_ProductMapping(CCNodeID,CostCenterID,ProductID,CRMProduct,UOMID,Description,  
		Quantity,CurrencyID, CompanyGUID,GUID,CreatedBy,CreatedDate'+@Sql+')  
		select @CaseID,73,  
		x.value(''@Product'',''INT''), x.value(''@CRMProduct'',''INT''),  
		x.value(''@UOM'',''INT''), x.value(''@Desc'',''nvarchar(MAX)''),  
		x.value(''@Qty'',''float''),ISNULL(x.value(''@Currency'',''INT''),1)
		,'''+@CompanyGUID+''',newid(),'''+ @UserName+''','+CONVERT(NVARCHAR,convert(float,@Dt))+@UpdateSql+'  
		from @XML.nodes(''XML/Row'') as data(x)  
		where  x.value(''@Product'',''INT'')is not null and   x.value(''@Product'',''INT'') <> ''''  ' 
			
		EXEC sp_executesql @SQL,N'@XML XML,@CaseID INT',@XML,@CaseID
	end   

	--Inserts Multiple Contacts   
	IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
	BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE 
		declare @rValue int
		EXEC @rValue = spCOM_SetFeatureWiseContacts 73,@CaseID,2,@ContactsXML,@UserName,@Dt,@LangID   
		IF @rValue=-1000  
		BEGIN  
			RAISERROR('-500',16,1)  
		END   
	END    

	--Insert Notifications  
	EXEC spCOM_SetNotifEvent @ActionType,73,@CaseID,@CompanyGUID,@UserName,@UserID,-1  
	IF @StatusID=1001 --FOR CLOSE CASE
	BEGIN
		EXEC spCOM_SetNotifEvent -1015,73,@CaseID,@CompanyGUID,@UserName,@UserID,-1 
	END 
   
	--UPDATE LINK DATA
	if(@LinkDim_NodeID>0)
	begin
		UPDATE [CRM_Cases] SET CCCaseID=@LinkDim_NodeID  
		WHERE CASEID=@CaseID  
		
		IF(@RefCCID > 0 AND @RefNodeID>0)  
        BEGIN  
			SET @UpdateSql='UPDATE COM_DocCCData   
			SET dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@LinkDim_NodeID)  
			+' WHERE InvDocDetailsID IN (SELECT InvDocDetailsID FROM Inv_DocDetails WITH(nolock)   
			WHERE COSTCENTERID='+CONVERT(NVARCHAR,@RefCCID)+' AND DOCID='+CONVERT(NVARCHAR,@RefNodeID)+')'  
			EXEC(@UpdateSql)  
        END 
        
		set @UpdateSql='update COM_CCCCDATA  
		SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@LinkDim_NodeID)+'  WHERE NodeID = '+
		convert(nvarchar,@CaseID) + ' AND CostCenterID = 73' 
		EXEC (@UpdateSql)

		Exec [spDOC_SetLinkDimension]
			@InvDocDetailsID=@CaseID, 
			@Costcenterid=73,         
			@DimCCID=@Dimesion,
			@DimNodeID=@LinkDim_NodeID,
			@UserID=@UserID,    
			@LangID=@LangID  
	end
	--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=73 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 73,@CaseID,@UserID,@LangID
	end
	
 COMMIT TRANSACTION  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @CaseID  
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
