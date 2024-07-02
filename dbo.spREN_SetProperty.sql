USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SetProperty]
	@PropertyID [int] = 0,
	@Code [nvarchar](200),
	@Name [nvarchar](500),
	@Status [int],
	@IsGroup [bit],
	@SelectedNodeID [int],
	@DetailsXML [nvarchar](max) = null,
	@DepositXML [nvarchar](max) = null,
	@UnitXML [nvarchar](max) = null,
	@ParkingXML [nvarchar](max) = null,
	@CustomFieldsQuery [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@RoleXml [nvarchar](max) = null,
	@NotesXML [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@ShareHolderXML [nvarchar](max) = null,
	@AlertsXML [nvarchar](max) = null,
	@HistoryXML [nvarchar](max) = NULL,
	@WID [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangId [int] = 1,
	@RoleID [int] = 1,
	@CodePrefix [nvarchar](200) = null,
	@CodeNumber [int] = 0,
	@GroupSeqNoLength [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON     
BEGIN TRANSACTION    
BEGIN TRY    
	DECLARE @UpdateSql nvarchar(max),@Dt FLOAT, @lft INT,@rgt INT,@TempGuid nvarchar(50),@Selectedlft INT,@Selectedrgt INT,
	@HasAccess bit,@IsDuplicateNameAllowed bit,@IsLeadCodeAutoGen bit  ,@IsIgnoreSpace bit,    
	@Depth int,@ParentID INT,@SelectedIsGroup int , @XML XML,@ParentCode nvarchar(200)    
	DECLARE @return_value int,@TEMPxml NVARCHAR(500),@PrefValue NVARCHAR(500),@Dimesion INT,@CCStatusID INT,@UpdateLandLord bit 
	DECLARE @RefSelectedNodeID INT
	  
	--GETTING PREFERENCE      
	SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=92 and  Name='DuplicateNameAllowed'      
	SELECT @IsLeadCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=92 and  Name='CodeAutoGen'      
	SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=92 and  Name='IgnoreSpaces'      
	select @PrefValue = Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=92 and  Name = 'LinkDocument' 
	select @UpdateLandLord = Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=92 and  Name = 'UpdateLandLord'    
	--DUPLICATE CHECK      
	IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0      
	BEGIN      
		IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1      
		BEGIN      
			IF @PropertyID=0      
			BEGIN      
				IF EXISTS (SELECT NodeID FROM REN_Property WITH(nolock) WHERE replace(Name,' ','')=replace(@Name,' ',''))      
				BEGIN      
					RAISERROR('-112',16,1)      
				END      
			END      
			ELSE      
			BEGIN      
				IF EXISTS (SELECT NodeID FROM REN_Property WITH(nolock) WHERE replace(Name,' ','')=replace(@Name,' ','') AND NodeID<>@PropertyID)      
				BEGIN      
					RAISERROR('-112',16,1)           
				END      
			END      
		END      
		ELSE      
		BEGIN      
			IF @PropertyID=0      
			BEGIN      
				IF EXISTS (SELECT NodeID FROM REN_Property WITH(nolock) WHERE Name=@Name)      
				BEGIN      
					RAISERROR('-112',16,1)      
				END      
			END      
			ELSE      
			BEGIN      
				IF EXISTS (SELECT NodeID FROM REN_Property WITH(nolock) WHERE Name=@Name AND NodeID<>@PropertyID)      
				BEGIN      
					RAISERROR('-112',16,1)      
				END      
			END      
		END    
	END       
    
    --User acces check FOR Notes  
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
	BEGIN  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,92,8)  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  
	END  
	
	--User acces check FOR Alerts
	IF (@AlertsXML IS NOT NULL AND @AlertsXML <> '')  
	BEGIN  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,92,836)  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  
	END 
	--User acces check FOR Attachments    
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')    
	BEGIN    
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,92,12)    

		IF @HasAccess=0    
		BEGIN    
			RAISERROR('-105',16,1)    
		END    
	END    
    
	SET @Dt=convert(float,getdate())--Setting Current Date     
   	--WorkFlow
Declare @CStatusID int
Declare @level int,@maxLevel int
SELECT @CStatusID=ISNULL(StatusID,0) FROM REN_Property WITH(NOLOCK) where NodeID=@PropertyID

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
		 	set @Status=1001 
		end	
		else if(@level is not null and  @maxLevel is not null and @PropertyID>0 and @level<@maxLevel and @CStatusID in (1003))--rejected status time
		begin	
		 	set @Status=1001 
		end			 
		 
	end
		   
   PRINT '@Status'
   PRINT  @Status

	IF @PropertyID= 0--------START INSERT RECORD-----------      
	BEGIN--CREATE Property     
	  
		 --To Set Left,Right And Depth of Record      
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth      
		from REN_Property with(NOLOCK) where NodeID=@SelectedNodeID      
	          
		--IF No Record Selected or Record Doesn't Exist      
		if(@SelectedIsGroup is null)       
			select @SelectedNodeID=NodeID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth      
			from REN_Property with(NOLOCK) where ParentID =0      
	                
		if(@SelectedIsGroup = 1)--Adding Node Under the Group      
		BEGIN      
			UPDATE REN_Property SET rgt = rgt + 2 WHERE rgt > @Selectedlft;      
			UPDATE REN_Property SET lft = lft + 2 WHERE lft > @Selectedlft;      
			set @lft =  @Selectedlft + 1      
			set @rgt = @Selectedlft + 2      
			set @ParentID = @SelectedNodeID      
			set @Depth = @Depth + 1      
		END      
		else if(@SelectedIsGroup = 0)--Adding Node at Same level      
		BEGIN      
			UPDATE REN_Property SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;      
			UPDATE REN_Property SET lft = lft + 2 WHERE lft > @Selectedrgt;     
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
		IF @IsLeadCodeAutoGen IS NOT NULL AND @IsLeadCodeAutoGen=1 AND @PropertyID=0      
		BEGIN      
			SELECT @ParentCode=[Code]      
			FROM REN_Property WITH(NOLOCK) WHERE NodeID=@ParentID        

			--CALL AUTOCODEGEN      
			EXEC [spCOM_SetCode] 92,@ParentCode,@Code OUTPUT        
		END      
   
		if(@PrefValue is not null and @PrefValue<>'')    
		begin    
		   
			set @Dimesion=0    
			begin try    
				select @Dimesion=convert(INT,@PrefValue)    
			end try    
			begin catch    
				set @Dimesion=0    
			end catch    
			if(@Dimesion>0)    
			begin  
				SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
				WHERE CostCenterID=92 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				
				if(@Status=1001 OR @Status=1002 OR @Status=1003)
					set @CCStatusID=@Status
				else
					select @CCStatusID = statusid from com_status WITH(nolock) where costcenterid=@Dimesion and status = 'Active'  
				EXEC @return_value = [dbo].[spCOM_SetCostCenter]  
				@NodeID = 0,@SelectedNodeID =@RefSelectedNodeID,@IsGroup = @IsGroup,  
				@Code = @Code,  
				@Name = @Name,  
				@AliasName=@Name,  
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,  
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,  
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,  
				@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',
				@RoleID=1,@UserID=1,@CheckLink = 0  

			end    
		end     
   
   
   PRINT '@Status'
   PRINT @Status
		insert into REN_Property(Code,Name,StatusID,Depth,ParentID,lft,rgt,IsGroup,CompanyGUID,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate ,CCNodeID,CCID,CodePrefix,CodeNumber,GroupSeqNoLength,WorkFlowID,WorkFlowLevel)    
		VALUES(@Code,@Name,@Status,
		@Depth,@SelectedNodeID,@lft,@rgt,@IsGroup,@CompanyGUID,newid(),@UserName,@Dt,@UserName,@Dt  , @return_value ,@Dimesion
		,@CodePrefix,@CodeNumber,@GroupSeqNoLength,@WID,@level)   
      
		set @PropertyID=scope_identity()    
 
		--Handling of Extended Table      
		INSERT INTO REN_PropertyExtended([NodeID],[CreatedBy],[CreatedDate])      
		VALUES(@PropertyID, @UserName, @Dt)      
   
		-- Link Dimension Mapping   
		INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])    
		VALUES(92,@PropertyID,newid(),  @UserName, @Dt)     

		INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  
		CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)  
		values(92, @PropertyID,0,0,@Dimesion,@return_value,'',newid(),@UserName, @dt,'Property')  
    
		if(@WID>0)
		BEGIN	 
			INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
			VALUES(92,@PropertyID,@Status,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
		END
	END --------END INSERT RECORD-----------      
	ELSE  --------START UPDATE RECORD-----------      
	BEGIN    
  
		SELECT @TempGuid=[GUID] from REN_Property  WITH(NOLOCK)       
		WHERE NodeID=@PropertyID    

		IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ        
		BEGIN        
			RAISERROR('-101',16,1)       
		END        
		ELSE        
		BEGIN    
			DELETE FROM  COM_CCCCDATA WHERE NodeID=@PropertyID AND  CostCenterID = 92    

			--Handling of CostCenter Costcenters Extrafields Table      

			INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[CompanyGUID],[Guid],[CreatedBy],[CreatedDate])    
			VALUES(92,@PropertyID, @CompanyGUID,newid(),  @UserName, @Dt)   
			 
			--UPDATE   
			Update REN_Property set  Code=@Code,Name=@Name,StatusID=@Status 
			,CodePrefix=@CodePrefix,CodeNumber=@CodeNumber,GroupSeqNoLength=@GroupSeqNoLength
			,WorkFlowLevel=isnull(@level,0)
			where NodeID=@PropertyID     
    
			if(@PrefValue is not null and @PrefValue<>'')    
			begin  
				set @Dimesion=0    
				begin try    
					select @Dimesion=convert(INT,@PrefValue)    
				end try    
				begin catch    
					set @Dimesion=0     
				end catch    

				declare @NID INT

				select @NID = CCNodeID  from Ren_Property WITH(nolock) where NodeID=@PropertyID   

				if(@Dimesion>0 and @NID is not null and @NID <>'' )  
				begin    
					declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)  
					declare @NodeidXML nvarchar(max)   
					select @Table=Tablename from adm_features WITH(nolock) where featureid=@Dimesion  
					declare @str nvarchar(max)   
					set @str='@Gid nvarchar(50) output'   
					set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' WITH(nolock) where NodeID='+convert(nvarchar,@NID)+')'  

					exec sp_executesql @NodeidXML, @str, @Gid OUTPUT   
					
					if(@Status=1001 OR @Status=1002 OR @Status=1003)
						set @CCStatusID=@Status
					else
						select @CCStatusID = statusid from com_status WITH(nolock) where costcenterid=@Dimesion and status = 'Active'  

					if(@Gid is null and @NID >0)
						set @NID=0
					
					SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
					WHERE CostCenterID=92 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
					SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				
					EXEC @return_value = [dbo].[spCOM_SetCostCenter]  
					@NodeID = @NID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,  
					@Code = @Code,  
					@Name = @Name,  
					@AliasName=@Name,  
					@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,  
					@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML='',  
					@CustomCostCenterFieldsQuery=NULL,@ContactsXML=null,@NotesXML=NULL,  
					@CostCenterID = @Dimesion,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1 , @CheckLink = 0   
					  
					Update REN_PROPERTY set CCID=@Dimesion, CCNodeID=@return_value where NodeID=@PropertyID        
				END  
			END   
		END    
	END 
	
	
	IF((@UnitXML IS NOT NULL AND @UnitXML <>'') OR (@ParkingXML IS NOT NULL AND @ParkingXML <>''))    
	BEGIN    
		DELETE FROM REN_PropertyUnits WHERE PropertyID = @PropertyID 
	    
	    IF(@UnitXML IS NOT NULL AND @UnitXML <>'')
	    BEGIN    
			set @XML=@UnitXML
			insert into REN_PropertyUnits(PropertyID,[Type],Numbers,Rent,UnitTypeCCID,UnitTypeNodeID,TypeID,
			CompanyGUID,[GUID],CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)    
			select  @PropertyID,    
			X.value('@Type','nvarchar(200)'),    
			X.value('@Numbers','INT'),    
			X.value('@Rent','FLOAT'),0,0,        
			X.value('@TypeID','INT'),@CompanyGUID,newid(),@UserName,@Dt,@UserName,@Dt    
			from @XML.nodes('/XML/Row') as data(X)    
		END
		
		IF(@ParkingXML IS NOT NULL AND @ParkingXML <>'')
	    BEGIN    
			set @XML=@ParkingXML
			insert into REN_PropertyUnits(PropertyID,[Type],Numbers,Rent,UnitTypeCCID,UnitTypeNodeID,TypeID,
			CompanyGUID,[GUID],CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)    
			select  @PropertyID,    
			X.value('@Type','nvarchar(200)'),    
			X.value('@Numbers','INT'),    
			X.value('@Rent','FLOAT'),0,0,        
			X.value('@TypeID','INT'),@CompanyGUID,newid(),@UserName,@Dt,@UserName,@Dt    
			from @XML.nodes('/XML/Row') as data(X)   
		END 
    END
    
    IF(@DetailsXML IS NOT NULL AND @DetailsXML <>'')    
	BEGIN    
		set @UpdateSql='update [REN_Property]    
		SET '+@DetailsXML+' [ModifiedBy] ='''+ @UserName    
		+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@PropertyID)      
		exec sp_executesql @UpdateSql    
	END 
	     
	IF (@UpdateLandLord IS NOT NULL AND @UpdateLandLord=1)  
	BEGIN      
		UPDATE U SET U.LandlordID=P.LandlordID  
		FROM REN_Units U WITH(NOLOCK)
		JOIN REN_Property P WITH(NOLOCK) ON  P.NodeID=U.PropertyID
		WHERE P.NodeID=@PropertyID   
	END     
 	
	--CHECK WORKFLOW
	--EXEC spCOM_CheckCostCentetWF 92,@PropertyID,@WID,@RoleID,@UserID,@UserName,@Status output
	  
	IF(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <>'')    
	BEGIN    
		set @UpdateSql='update [REN_PropertyExtended]    
		SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName    
		+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@PropertyID)    
		exec sp_executesql @UpdateSql   
	END    
         
	IF(@CustomCostCenterFieldsQuery IS NOT NULL AND @CustomCostCenterFieldsQuery <>'')    
	BEGIN  
		set @UpdateSql='update COM_CCCCDATA      
		SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID =      
		'+convert(nvarchar,@PropertyID) + ' AND CostCenterID = 92'     
		exec sp_executesql @UpdateSql   
	END    
    
    IF(@DepositXML IS NOT NULL AND @DepositXML <>'')    
	BEGIN  
		set @XML=@DepositXML    
		delete from REN_Particulars where PropertyID=@PropertyID and UnitID=0     

		insert into REN_Particulars(ParticularID,PropertyID,UnitID,CreditAccountID,DebitAccountID,AdvanceAccountID,Refund,DiscountPercentage,VAT,InclChkGen
		,VatType,TaxCategoryID,SPType,RecurInvoice,PostDebit,DiscountAmount,Months,TypeID,ContractType ,CompanyGUID,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate
		,DimNodeID,Display,BankAccountID,PercType)    
		 select  X.value('@Particulars','INT'),@PropertyID,0,       
		X.value('@CreditAccount','INT'),    
		X.value('@DebitAccount','INT'),  X.value('@AdvanceAccountID','INT')  , 
		X.value('@Refund','INT'),    
		X.value('@Percentage','FLOAT'),X.value('@Vat','FLOAT'),  X.value('@InclChkGen','INT'), 
		X.value('@VatType','Nvarchar(50)'),X.value('@TaxCategoryID','INT'),X.value('@SPType','INT'), X.value('@RecurInvoice','BIT'), X.value('@PostDebit','BIT'),
		X.value('@Amount','FLOAT'),X.value('@Months','FLOAT'),X.value('@TypeID','INT'),X.value('@ContractType','INT'),@CompanyGUID,newid(),@UserName,@Dt,@UserName,@Dt    
		,X.value('@DimNodeID','INT'),X.value('@Display','INT')
		,ISNULL(X.value('@BankAccountID','INT'),0),X.value('@PercType','INT')
		from @XML.nodes('/XML/Row') as data(X)    
		
		set @UpdateSql=''
		select @UpdateSql=X.value('@UpdateQuery','Nvarchar(max)')from @XML.nodes('/XML') as data(X)    
		if(@UpdateSql!='')
		BEGIN
			set @UpdateSql='update REN_Particulars set '+@UpdateSql+'ParticularID=ParticularID 
			from @XML.nodes(''/XML/Row'') as data(X)     
			where [PropertyID]='+convert(nvarchar(max),@PROPERTYID)+' and [UnitID]=0
			and ParticularID=X.value(''@Particulars'',''INT'')'
			exec sp_executesql @UpdateSql,N'@XML xml',@XML
		END
	END 
	   
	IF (@RoleXml IS NOT NULL AND @RoleXml ='<XML></XML>')  
	BEGIN  
		INSERT INTO [ADM_PropertyUserRoleMap]([PropertyID],UserID,RoleID,LocationID,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])    
		SELECT  @PropertyID ,@UserID ,@RoleID ,(SELECT LocationID FROM REN_Property WITH(NOLOCK) WHERE NodeID=@PropertyID) ,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())    
	END 
	ELSE IF(@RoleXml IS NOT NULL AND @RoleXml <>'')    
	BEGIN    
		DELETE from [ADM_PropertyUserRoleMap] where [PropertyID]=@PropertyID    
		    
		SET @XML=@RoleXml    

		INSERT INTO [ADM_PropertyUserRoleMap]([PropertyID],UserID,RoleID,LocationID,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])    
		SELECT @PropertyID,X.value('@UserID','INT'),X.value('@RoleID','INT'),X.value('@LocationID','INT'),@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())    
		from @XML.nodes('/XML/Row') as Data(X)   
	END    
			
		
	--Inserts Multiple Notes  
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
	BEGIN  
		SET @XML=@NotesXML  

		--If Action is NEW then insert new Notes  
		INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
		GUID,CreatedBy,CreatedDate)  
		SELECT 92,92,@PropertyID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
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
		FROM COM_Notes C WITH(NOLOCK)  
		INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)    
		ON convert(INT,X.value('@NoteID','INT'))=C.NoteID  
		WHERE X.value('@Action','NVARCHAR(10)')='MODIFY'  

		--If Action is DELETE then delete Notes  
		DELETE FROM COM_Notes  
		WHERE NoteID IN(SELECT X.value('@NoteID','INT')  
		FROM @XML.nodes('/NotesXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  

	END  
	
	--Inserts Multiple Alerts  
	IF (@AlertsXML IS NOT NULL AND @AlertsXML <> '')  
	BEGIN  
		SET @XML=@AlertsXML  

		--If Action is NEW then insert new Notes  
		INSERT INTO COM_Alerts(FeatureID,FeaturePK,AlertMessage,FromDate,ToDate,StatusID,AttachmentID,AttachmentGUID,
		GUID,CreatedBy,CreatedDate)  
		SELECT 92,@PropertyID,
		Replace(X.value('@AlertMessage','NVARCHAR(MAX)'),'@~',''),  
		CONVERT(FLOAT,CONVERT(DATETIME,REPLACE(X.value('@FromDate','NVARCHAR(MAX)'),'@~',''))),
		CONVERT(FLOAT,CONVERT(DATETIME,REPLACE(X.value('@ToDate','NVARCHAR(MAX)'),'@~',''))),
		Replace(X.value('@StatusID','INT'),'@~',''),  
		Replace(X.value('@AttachmentID','INT'),'@~',''),  
		Replace(X.value('@AttachmentGUID','NVARCHAR(MAX)'),'@~',''),
		newid(),@UserName,@Dt  
		FROM @XML.nodes('/AlertsXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='NEW' 
		
		Update Files set Files.FeaturePK=Alert.FeaturePK from Com_Files Files with(nolock) join COM_Alerts Alert with(nolock)
					on Alert.AttachmentGUID=Files.Guid and Files.FeatureID=Alert.FeatureID and Files.FeatureID=92 and Files.FeaturePK=-100 and Alert.FeaturePK=@PropertyID

		--If Action is MODIFY then update Notes  
		UPDATE COM_Alerts  
		SET AlertMessage=Replace(X.value('@AlertMessage','NVARCHAR(MAX)'),'@~',''),     
		FromDate=CONVERT(FLOAT,CONVERT(DATETIME,REPLACE(X.value('@FromDate','NVARCHAR(MAX)'),'@~',''))),
		ToDate=CONVERT(FLOAT,CONVERT(DATETIME,REPLACE(X.value('@ToDate','NVARCHAR(MAX)'),'@~',''))),
		StatusID=Replace(X.value('@StatusID','INT'),'@~',''),  
		--AttachmentID=Replace(X.value('@AttachmentID','INT'),'@~',''),  
		--AttachmentGUID=Replace(X.value('@AttachmentGUID','NVARCHAR(MAX)'),'@~',''),    
		GUID=newid(),  
		ModifiedBy=@UserName,  
		ModifiedDate=@Dt  
		FROM COM_Alerts C WITH(NOLOCK)  
		INNER JOIN @XML.nodes('/AlertsXML/Row') as Data(X)    
		ON convert(INT,X.value('@AlertID','INT'))=C.AlertID  
		WHERE X.value('@Action','NVARCHAR(10)')='MODIFY'  

		--If Action is DELETE then delete Notes  
		DELETE FROM COM_Alerts  
		WHERE AlertID IN(SELECT X.value('@AlertID','INT')  
		FROM @XML.nodes('/AlertsXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  

	END 
	
	--HistoryXML
	IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
		EXEC spCOM_SetHistory 92,@PropertyID,@HistoryXML,@UserName  
	
    --Inserts Multiple Attachments    
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')    
		exec [spCOM_SetAttachments] @PropertyID,92,@AttachmentsXML,@UserName,@Dt
	 
    --Inserts Property Share holder
	IF (@ShareHolderXML IS NOT NULL AND @ShareHolderXML <> '')    
	BEGIN    
		SET @XML=@ShareHolderXML    
		delete from [REN_PropertyShareHolder] where PropertyID=@PropertyID

		INSERT INTO [REN_PropertyShareHolder]
		([PropertyID],[Account],[Income],[Expenses],[OpIncome],[OpExpenses],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		SELECT  @PropertyID,  X.value('@Account','NVARCHAR(500)'),X.value('@Income','float'),X.value('@Expenses','float'),    
		X.value('@OpIncome','float'),X.value('@OpExpenses','float'),'', NEWID(),@UserName,@Dt    
		FROM @XML.nodes('/XML/Row') as Data(X)      
	END 
	
	--UPDATE LINK DATA
	if(@return_value>0 and @return_value<>'')
	begin
		
		DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=@Dimesion AND ParentNodeID=@return_value AND CostCenterID IN (6,7,50002)
		
		INSERT INTO  COM_CostCenterCostCenterMap (ParentCostCenterID,ParentNodeID,CostCenterID,NodeID,GUID,CreatedBy,CreatedDate)
		SELECT @Dimesion,@return_value,7,UserID,GUID,CreatedBy,CreatedDate FROM [ADM_PropertyUserRoleMap] WITH(NOLOCK) 
		WHERE [PropertyID]=@PropertyID AND UserID IS NOT NULL
		UNION
		SELECT @Dimesion,@return_value,50002,LocationID,GUID,CreatedBy,CreatedDate FROM [ADM_PropertyUserRoleMap] WITH(NOLOCK) 
		WHERE [PropertyID]=@PropertyID AND LocationID IS NOT NULL
		
		set @UpdateSql='update COM_CCCCDATA    
		SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  WHERE NodeID = '+
		convert(nvarchar,@PropertyID) + ' AND CostCenterID = 92'   
		exec sp_executesql @UpdateSql   
		
		Exec [spDOC_SetLinkDimension]
			@InvDocDetailsID=@PropertyID, 
			@Costcenterid=92,         
			@DimCCID=@Dimesion,
			@DimNodeID=@return_value,
			@UserID=@UserID,    
			@LangID=@LangID  
	end   
   
    --validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=92 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 92,@PropertyID,@UserID,@LangID
	end  
COMMIT TRANSACTION    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID      
SET NOCOUNT OFF;        
RETURN @PropertyID    
END TRY        
BEGIN CATCH        
	--Return exception info [Message,Number,ProcedureName,LineNumber]        
	IF ERROR_NUMBER()=50000      
	BEGIN    
		if isnumeric(ERROR_MESSAGE())=1  
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
			WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
		else
			SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber	
	
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
