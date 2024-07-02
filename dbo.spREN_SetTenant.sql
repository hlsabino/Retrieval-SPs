USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SetTenant]
	@TenantID [int],
	@Code [nvarchar](200),
	@FirstName [nvarchar](200),
	@TabsDetails [nvarchar](max) = null,
	@SelectedNodeID [int],
	@IsGroup [bit],
	@CustomFieldsQuery [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@NotesXML [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@ActivityXML [nvarchar](max) = '',
	@ContactsXML [nvarchar](max) = '',
	@PrimaryContactQuery [nvarchar](max) = '',
	@AssignCCCCData [nvarchar](max) = null,
	@AlertsXML [nvarchar](max) = null,
	@ArtifactsXML [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@WID [int] = 0,
	@RoleID [int] = 1,
	@UserID [int] = 0,
	@LangID [int] = 1,
	@CodePrefix [nvarchar](200) = null,
	@CodeNumber [int] = 0,
	@GroupSeqNoLength [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
	SET NOCOUNT ON;    
	--Declaration Section    
	DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50),@return_value int,@AccReturn_value int,@CCStatusID INT  
	DECLARE @ParentCode nvarchar(200),@CCCCCData XML,@BillWiseCol nvarchar(50) ,@BillWiseval  int,@sqlbw nvarchar(max)  
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT    
	DECLARE @SelectedIsGroup bit,@HasAccess bit,@IsTenantCodeAutoGen bit    
	DECLARE @TEMPxml NVARCHAR(500),@PrefValue NVARCHAR(500),@Dimesion INT,@HistoryStatus nvarchar(50)
	DECLARE @StatusID INT,@RefSelectedNodeID INT,@CreateAcc NVARCHAR(10),@AccDim INT,@AccType INT,@AccGrpID INT,@tempCode NVARCHAR(200),@SQL NVARCHAR(MAX),@i int,@Cnt INT
	Declare @iFlagNew int=0
	SET @AccDim=2
	declare @ContXML nvarchar(max)   
	set @ContXML=@ContactsXML 
	
	select @StatusID=statusid from com_status WITH(NOLOCK) where costcenterid=94 and [Status]='Active'
	--User acces check FOR ACCOUNTS    
	IF @TenantID=0    
	BEGIN    
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,94,1)    
		set @HistoryStatus='Add'
	END    
	ELSE    
	BEGIN    
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,94,3)    
		set @HistoryStatus='Update'
	END    

	IF @HasAccess=0    
	BEGIN    
		RAISERROR('-105',16,1)    
	END   
	
	--User acces check FOR Contacts  
  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
  BEGIN  
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,94,16)  
	IF @HasAccess=0  
	BEGIN  
		RAISERROR('-105',16,1)  
	END  
  END   
    
    --User acces check FOR Notes  
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
	BEGIN  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,94,8)  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  
	END 
	
	--User acces check FOR Alerts   
	IF (@AlertsXML IS NOT NULL AND @AlertsXML <> '')  
	BEGIN  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,94,841)  

		IF @HasAccess=0  
		BEGIN  
			RAISERROR('-105',16,1)  
		END  
	END 
	--User acces check FOR Attachments    
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')    
	BEGIN    
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,94,12)    

		IF @HasAccess=0    
		BEGIN    
			RAISERROR('-105',16,1)    
		END    
	END
	
	--GETTING PREFERENCE   
	SELECT @IsTenantCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) 
	WHERE COSTCENTERID=94 and Name='CodeAutoGen'    
	select @PrefValue=Value from COM_CostCenterPreferences WITH(nolock)  
	where CostCenterID=94 and Name = 'LinkDocument'  

	SELECT @CreateAcc=Value from COM_CostCenterPreferences WITH(nolock)  
	where CostCenterID=94 and Name = 'CreateAccountWhileCreatingTenant'  

	SELECT @AccGrpID=Value from COM_CostCenterPreferences WITH(nolock)  
	where CostCenterID=94 and Name = 'TenantAccLinkAccGroup' 

	SELECT @AccType=Value from COM_CostCenterPreferences WITH(nolock)  
	where CostCenterID=94 and Name = 'TenantAccLinkAccType' 
	    

	SET @Dt=convert(float,getdate())--Setting Current Date    
	 
	--WorkFlow
Declare @CStatusID int
Declare @level int,@maxLevel int
SET @CStatusID=0
if(@TenantID>0)
	BEGIN
		SELECT @CStatusID=ISNULL(StatusID,0) FROM REN_Tenant WITH(NOLOCK) where TenantID=@TenantID
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
		else if(@level is not null and  @maxLevel is not null and @TenantID>0 and @level<@maxLevel and @CStatusID in (1003))--rejected status time
		begin	
		 	set @StatusID=1001 
		end			 
		 
	end
	   
	set @iFlagNew=0
	IF @TenantID=0--------START INSERT RECORD-----------    
	BEGIN  
		--To Set Left,Right And Depth of Record    
		set @iFlagNew=1--for updating status tabdetails creating issue for status
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
		from [REN_Tenant] with(NOLOCK) where TenantID=@SelectedNodeID    
     
		--IF No Record Selected or Record Doesn't Exist    
		if(@SelectedIsGroup is null)     
			select @SelectedNodeID=TenantID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
			from [REN_Tenant] with(NOLOCK) where ParentID =0    
		   
		if(@SelectedIsGroup = 1)--Adding Node Under the Group    
		BEGIN    
			UPDATE REN_Tenant SET rgt = rgt + 2 WHERE rgt > @Selectedlft;    
			UPDATE REN_Tenant SET lft = lft + 2 WHERE lft > @Selectedlft;    
			set @lft =  @Selectedlft + 1    
			set @rgt = @Selectedlft + 2    
			set @ParentID = @SelectedNodeID    
			set @Depth = @Depth + 1    
		END    
		else if(@SelectedIsGroup = 0)--Adding Node at Same level    
		BEGIN    
			UPDATE REN_Tenant SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;    
			UPDATE REN_Tenant SET lft = lft + 2 WHERE lft > @Selectedrgt;    
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
		IF @IsTenantCodeAutoGen IS NOT NULL AND @IsTenantCodeAutoGen=1 AND @TenantID=0    
		BEGIN    
			SELECT @ParentCode=[TenantCode]    
			FROM [REN_Tenant] WITH(NOLOCK) WHERE TenantID=@ParentID      

			--CALL AUTOCODEGEN    
			EXEC [spCOM_SetCode] 94,@ParentCode,@Code OUTPUT  
			print '1'    
			print @Code
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
				WHERE CostCenterID=94 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				
				select @CCStatusID = statusid from com_status with(nolock)where costcenterid=@Dimesion and status = 'Active'  
	
				EXEC @return_value = [dbo].[spCOM_SetCostCenter]  
				@NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,  
				@Code = @Code,  
				@Name = @FirstName,  
				@AliasName=@FirstName,  
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,  
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,  
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=@ContXML,@NotesXML=NULL,  
				@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',
				@UserName=@UserName,@RoleID=1,@UserID=1,@CheckLink = 0,
				@PrimaryContactQuery=@PrimaryContactQuery ,@CostCenterRoleXML=@AssignCCCCData 			
				print '2'
				print @Code
			END  
		END   

		---- CREATING ACCOUNTING WHILE CREATING TENANT
		IF(@CreateAcc IS NOT NULL AND @CreateAcc='True')
		BEGIN
			SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
			WHERE CostCenterID=94 AND RefDimensionID=@AccDim AND NodeID=@SelectedNodeID 
			SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				
			select @CCStatusID = statusid from com_status with(nolock)where costcenterid=@AccDim and status = 'Active'  
	
			EXEC	@AccReturn_value = [dbo].[spACC_SetAccount]
			@AccountID = 0,
			@AccountCode = @Code,
			@AccountName = @FirstName,
			@AliasName = @FirstName,
			@AccountTypeID = @AccType,
			@StatusID = 33,
			@SelectedNodeID = @AccGrpID,
			@IsGroup = @IsGroup,
			@CreditDays=0,@CreditLimit=0,@DebitDays=0,@DebitLimit=0,@Currency=0,
			@PurchaseAccount=0,@SalesAccount=0,@COGSAccountID=0,@ClosingStockAccountID=0,
			@PDCReceivableAccount=0,@PDCPayableAccount=0,@IsBillwise=0,@PaymentTerms=0,
			@LetterofCredit=0,@TrustReceipt=0,@CompanyGUID=@COMPANYGUID,@GUID='GUID',@Description='DESC',
			@UserName=@UserName,@RoleID=@RoleID,@UserID=@UserID,
			@CustomFieldsQuery='',@CustomCostCenterFieldsQuery='',
			@PrimaryContactQuery=@PrimaryContactQuery,@ContactsXML=@ContXML,@AttachmentsXML='',@NotesXML='',@AddressXML=''   

		END
		   
 
		-- Insert statements for procedure here   
		print '3'
		print @Code 
		INSERT INTO [REN_Tenant] ([TenantCode],[FirstName],[Depth],[ParentID],[lft],[rgt],[IsGroup],    
		[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],CCNodeID,CCID,StatusID,AccountID,WorkFlowID,WorkFlowLevel,CodePrefix,CodeNumber,GroupSeqNoLength)      
		VALUES (@Code,@FirstName,@Depth,@ParentID,@lft,@rgt,@IsGroup,    
		@CompanyGUID,newid(),@UserName,@Dt,@return_value ,@Dimesion ,@StatusID,@AccReturn_value,@WID,@level,@CodePrefix,@CodeNumber,@GroupSeqNoLength)    
		--To get inserted record primary key    
		SET @TenantID=SCOPE_IDENTITY()          
	    
		--Handling of Extended Table    
		INSERT INTO [REN_TenantExtended]([TenantID],[CreatedBy],[CreatedDate])    
		VALUES(@TenantID,@UserName,@Dt)    

		INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])  
		VALUES(94,@TenantID,newid(),@UserName,@Dt)   

		-- Link Dimension Mapping  
		INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  
		CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)  
		values(94, @TenantID,0,0,@Dimesion,@return_value,'',newid(),@UserName, @dt,'Tenant')  

		IF(@AccReturn_value>0)
		BEGIN
			-- Account Linking Dimension Mapping  
			INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  
			CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)  
			values(94, @TenantID,0,0,2,@AccReturn_value,'',newid(),@UserName, @dt,'Tenant') 
		END
		
	if(@WID>0)
	BEGIN	 
		INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
		VALUES(94,@TenantID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
	END
		--Handling of CostCenter Costcenters Extrafields Table    
	END--------END INSERT RECORD-----------    
	ELSE--------START UPDATE RECORD-----------    
	BEGIN     
    
		SELECT @TempGuid=[GUID] from [REN_Tenant]  WITH(NOLOCK)     
		WHERE TenantID=@TenantID 
		
		IF EXISTS(SELECT TenantID FROM REN_Tenant WHERE TenantID=@TenantID AND ParentID=0)    
		BEGIN    
			RAISERROR('-123',16,1)    
		END    

		UPDATE [REN_Tenant]    
		SET[TenantCode]     =@Code  
		,[FirstName]     =@FirstName     
		,[GUID]          = newid()        
		,[ModifiedBy]    = @UserName    
		,[ModifiedDate]  = @Dt   
		,WorkFlowLevel=isnull(@level,0)
		,CodePrefix=@CodePrefix,CodeNumber=@CodeNumber,GroupSeqNoLength=@GroupSeqNoLength
		WHERE TenantID=@TenantID          
     
		if(@PrefValue is not null and @PrefValue<>'')    
		begin   
			set @Dimesion=0    
			begin try    
				select @Dimesion=convert(INT,@PrefValue)    
			end try    
			begin catch    
				set @Dimesion=0     
			end catch    
 
			declare @NID INT, @CCIDAcc INT  
			select @NID = CCNodeID, @CCIDAcc=CCID  from [REN_Tenant] with(nolock) where TenantID=@TenantID  
  
			if(@Dimesion>0 and @NID is not null and @NID <>'' )      
			begin   
				declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)  
				declare @NodeidXML nvarchar(max) 
				
				select @Table=Tablename from adm_features with(nolock) where featureid=@Dimesion  
				declare @str nvarchar(max)   
				set @str='@Gid nvarchar(50) output'   
				set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' with(nolock) where NodeID='+convert(nvarchar,@NID)+')'  

				exec sp_executesql @NodeidXML, @str, @Gid OUTPUT
				
				DELETE FROM COM_ContactsExtended WHERE ContactID IN(SELECT ContactID FROM COM_Contacts WHERE FeatureID= @Dimesion and FeaturePK=@NID)
				DELETE FROM COM_Contacts WHERE FeatureID= @Dimesion and FeaturePK=@NID

				SET @ContXML=REPLACE(@ContXML,' Action="MODIFY"',' Action="NEW"')
				SET @ContXML=REPLACE(@ContXML,' ContactID="',' XContactID="')
				SET @ContXML=REPLACE(@ContXML,' Action="DELETE"',' Action="XDELETE"')

				SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
				WHERE CostCenterID=94 AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				select @PrimaryContactQuery
				select @CCStatusID =  statusid from com_status with(nolock) where costcenterid=@Dimesion and [status] = 'Active'  
				EXEC @return_value = [dbo].[spCOM_SetCostCenter]  
				@NodeID = @NID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,  
				@Code = @Code,  
				@Name = @FirstName,  
				@AliasName=@FirstName,  
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,  
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,  
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=@ContXML,@NotesXML=NULL,  
				@CostCenterID = @Dimesion,@CompanyGUID=@CompanyGUID,@GUID=@Gid,
				@UserName=@UserName,@RoleID=1,@UserID=1 , @CheckLink = 0,
				@PrimaryContactQuery=@PrimaryContactQuery ,@CostCenterRoleXML=@AssignCCCCData   
print '4'
print @Code
				Update [REN_Tenant] set CCID=@Dimesion, CCNodeID=@return_value where TenantID=@TenantID    
				
			END  
		END   
		
		IF(@CreateAcc IS NOT NULL AND @CreateAcc='True')
		BEGIN
			declare @NID2 INT
			select @NID2 = AccountID from [REN_Tenant] with(nolock) where TenantID=@TenantID  
  
			if(@NID2 is not null and @NID2 <>'' )      
			begin   
				declare @Gid2 nvarchar(50) , @Table2 nvarchar(100), @CGid2 nvarchar(50)  
				declare @NodeidXML2 nvarchar(max) ,@isbillwise bit
				
				select @Table2=Tablename from adm_features with(nolock) where featureid=@AccDim
				declare @str2 nvarchar(max)   
				set @str2='@Gid2 nvarchar(50) output'   
				set @NodeidXML2='set @Gid2= (select GUID from '+convert(nvarchar,@Table2)+' with(nolock) where AccountID='+convert(nvarchar,@NID2)+')'  

				exec sp_executesql @NodeidXML2, @str2, @Gid2 OUTPUT
				
				DELETE FROM COM_ContactsExtended WHERE ContactID IN(SELECT ContactID FROM COM_Contacts WHERE FeatureID= @AccDim and FeaturePK=@NID2)
				DELETE FROM COM_Contacts WHERE FeatureID= @AccDim and FeaturePK=@NID2

				SET @ContXML=REPLACE(@ContXML,' Action="MODIFY"',' Action="NEW"')
				SET @ContXML=REPLACE(@ContXML,' ContactID="',' XContactID="')
				SET @ContXML=REPLACE(@ContXML,' Action="DELETE"',' Action="XDELETE"')

				SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
				WHERE CostCenterID=94 AND RefDimensionID=@AccDim AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				
				select @CCStatusID =  statusid from com_status with(nolock) where costcenterid=@Dimesion and [status] = 'Active' 
				select @isbillwise=isbillwise from acc_accounts WITH(NOLOCK) where accountid=@NID2
				if(@isbillwise is null)
					set @isbillwise=0
				EXEC @AccReturn_value = [dbo].[spACC_SetAccount]
				@AccountID = @NID2,
				@AccountCode = @Code,
				@AccountName = @FirstName,
				@AliasName = @FirstName,
				@AccountTypeID = @AccType,
				@StatusID = 33,
				@SelectedNodeID = @AccGrpID,
				@IsGroup = @IsGroup,
				@CreditDays=0,@CreditLimit=0,@DebitDays=0,@DebitLimit=0,@Currency=0,
				@PurchaseAccount=0,@SalesAccount=0,@COGSAccountID=0,@ClosingStockAccountID=0,
				@PDCReceivableAccount=0,@PDCPayableAccount=0,@IsBillwise=@isbillwise,@PaymentTerms=0,
				@LetterofCredit=0,@TrustReceipt=0,@CompanyGUID=@COMPANYGUID,@GUID=@Gid2,@Description='DESC',
				@UserName=@UserName,@RoleID=@RoleID,@UserID=@UserID,
				@CustomFieldsQuery='',@CustomCostCenterFieldsQuery='',
				@PrimaryContactQuery=@PrimaryContactQuery,@ContactsXML=@ContXML,@AttachmentsXML='',@NotesXML='',@AddressXML='' 

				Update [REN_Tenant] set AccountID=@AccReturn_value where TenantID=@TenantID    
				
				IF(@AccReturn_value>0)
				BEGIN
					IF NOT EXISTS(Select * FROM COM_DocBridge WHERE CostCenterID=94 AND NodeID=@TenantID AND RefDimensionID=@AccDim AND RefDimensionNodeID=@AccReturn_value)
					BEGIN
						-- Account Linking Dimension Mapping  
						INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  
						CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)  
						values(94, @TenantID,0,0,2,@AccReturn_value,'',newid(),@UserName, @dt,'Tenant') 
					END
				END


			END 
		END
		
		  
	END    

	  PRINT '@Status insert /update after'
   PRINT @StatusID
	IF(@Code IS NULL OR @Code='')    
	BEGIN    
		UPDATE  [REN_Tenant]    
		SET [TenantCode] = @TenantID    
		WHERE TenantID=@TenantID          
	END    
	
	DECLARE @UpdateSql nvarchar(max)  
    
	if(@TabsDetails is not null and @TabsDetails <>'')  
	begin  
		SET @UpdateSql=' UPDATE REN_Tenant SET '+@TabsDetails+',[ModifiedBy] ='''+ @UserName    
	+''',[ModifiedDate] =' + str(@Dt,20,10) +'  WHERE TenantID = '+CONVERT(nvarchar,@TenantID)  
	
		exec(@UpdateSql)  
	end  

IF (@iFlagNew>0 and  @WID>0) 
 begin
	set @UpdateSql='';
	SET @UpdateSql=' UPDATE REN_Tenant SET  [StatusID] = '+CONVERT(nvarchar,@StatusID)+'   WHERE TenantID = '+CONVERT(nvarchar,@TenantID)  
	set @iFlagNew=0
	exec(@UpdateSql)  
 end

    SELECT @StatusID=StatusID FROM REN_Tenant WITH(NOLOCK) WHERE TenantID=@TenantID
    --CHECK WORKFLOW
	--EXEC spCOM_CheckCostCentetWF 94,@TenantID,@WID,@RoleID,@UserID,@UserName,@StatusID output
	
 
	--Update Extra fields    
	set @UpdateSql='update [REN_TenantExtended]  
	SET '+@CustomFieldsQuery+'[ModifiedBy] ='''+ @UserName    
	+''',[ModifiedDate] =' + str(@Dt,20,10) +' WHERE TenantID='+convert(nvarchar,@TenantID)    
	exec(@UpdateSql)    
  
	set @UpdateSql='update COM_CCCCDATA  SET  
	'+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + str(@Dt,20,10) +' WHERE NodeID = '+
	convert(nvarchar,@TenantID) + ' AND CostCenterID = 94'   
	exec(@UpdateSql)    
    
      --BillWise Value Update   
	  SELECT @BillWiseCol=SYSCOLUMNNAME FROM ADM_COSTCENTERDEF WITH(NOLOCK)  WHERE COSTCENTERID=94 AND USERCOLUMNNAME='BILLWISE' AND USERCOLUMNTYPE='COMBOBOX'   
	  IF(@AccReturn_value is not null and @AccReturn_value>0 and @BillWiseCol is not null and @BillWiseCol<>'')  
	  BEGIN  
	  SET @sqlbw=' SELECT @BillWiseval='+@BillWiseCol+' from REN_TenantExtended  WITH(NOLOCK) WHERE TenantID='+convert(nvarchar,@TenantID)  
	  EXEC sp_executesql @sqlbw,N'@BillWiseval INT output',@BillWiseval output  
	  UPDATE Acc_Accounts SET IsBillwise=@BillWiseval WHERE AccountID=@AccReturn_value  
	  END  
	  -- 

 -- , BEFORE MODIFIEDBY  REQUIRES A NULL CHECK OF @PrimaryContactQuery 
  IF(@PrimaryContactQuery IS NOT NULL AND @PrimaryContactQuery<>'')
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE
		EXEC spCOM_SetFeatureWiseContacts 94,@TenantID,1,@PrimaryContactQuery,@UserName,@Dt,@LangID
  END

	--Inserts Multiple Contacts   
	IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
	BEGIN  
		print @ContactsXML
		 declare @rValue int
		EXEC @rValue = spCOM_SetFeatureWiseContacts 94,@TenantID,2,@ContactsXML,@UserName,@Dt,@LangID   
		 IF @rValue=-1000  
		  BEGIN  
			RAISERROR('-500',16,1)  
		  END   
	END

	 --Inserts Multiple Notes  
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
	BEGIN  
		SET @XML=@NotesXML  

		--If Action is NEW then insert new Notes  
		INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
		GUID,CreatedBy,CreatedDate)  
		SELECT 94,94,@TenantID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
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
		SELECT 94,@TenantID,
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
					on Alert.AttachmentGUID=Files.Guid   and Files.FeatureID=Alert.FeatureID and Files.FeatureID=94 and Files.FeaturePK=-100 and Alert.FeaturePK=@TenantID
		

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
	
	--Inserts Multiple Artifacts  
	IF (@ArtifactsXML IS NOT NULL AND @ArtifactsXML <> '')  
	BEGIN  
		SET @XML=@ArtifactsXML  

		--If Action is NEW then insert new Artifact  
		INSERT INTO COM_Artifacts(FeatureID,FeaturePK,Name,Attachment,Value,Mandatory,StatusID,     
		GUID,CreatedBy,CreatedDate)  
		SELECT 94,@TenantID,
		Replace(X.value('@Name','NVARCHAR(MAX)'),'@~',''),  
		Replace(X.value('@Attachment','NVARCHAR(MAX)'),'@~',''),  
		Replace(X.value('@Value','NVARCHAR(MAX)'),'@~',''),  
		Replace(X.value('@Mandatory','NVARCHAR(50)'),'@~',''),  
		Replace(X.value('@StatusID','INT'),'@~',''),  
		newid(),@UserName,@Dt  
		FROM @XML.nodes('/ArtifactXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

		--If Action is MODIFY then update Artifact  
		UPDATE COM_Artifacts  
		SET Name=Replace(X.value('@Name','NVARCHAR(MAX)'),'@~',''),     
		Attachment=Replace(X.value('@Attachment','NVARCHAR(MAX)'),'@~',''),  
		Value=Replace(X.value('@Value','NVARCHAR(MAX)'),'@~',''),  
		Mandatory=Replace(X.value('@Mandatory','NVARCHAR(50)'),'@~',''),  
		StatusID=Replace(X.value('@StatusID','INT'),'@~',''),  
		GUID=newid(),  
		ModifiedBy=@UserName,  
		ModifiedDate=@Dt  
		FROM COM_Artifacts C WITH(NOLOCK)  
		INNER JOIN @XML.nodes('/ArtifactXML/Row') as Data(X)    
		ON convert(INT,X.value('@ArtifactID','INT'))=C.ArtfID  
		WHERE X.value('@Action','NVARCHAR(10)')='MODIFY'  

		--If Action is DELETE then delete Artifact  
		DELETE FROM COM_Artifacts  
		WHERE ArtfID IN(SELECT X.value('@ArtifactID','INT')  
		FROM @XML.nodes('/ArtifactXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  

	END 
	
	--Inserts Multiple Attachments    
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '') 
		exec [spCOM_SetAttachments] @TenantID,94,@AttachmentsXML,@UserName,@Dt   
	
	
	if(@ActivityXml<>'')      
		exec spCom_SetActivitiesAndSchedules @ActivityXml,94,@TenantID,@CompanyGUID,'',@UserName,@dt,@LangID     
	
	
	
	IF  (@AssignCCCCData IS NOT NULL AND @AssignCCCCData <> '') 
	BEGIN
		 SET @XML=@AssignCCCCData
		 EXEC [spCOM_SetCCCCMap] 94,@TenantID,@XML,@UserName,@LangID
	END	
	
	--UPDATE LINK DATA
	if(@return_value>0 and @return_value<>'')
	begin
	
		set @UpdateSql='update COM_CCCCDATA    
		SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  WHERE NodeID = '+
		convert(nvarchar,@TenantID) + ' AND CostCenterID = 94'   
		EXEC (@UpdateSql)  
			
		Exec [spDOC_SetLinkDimension]
			@InvDocDetailsID=@TenantID, 
			@Costcenterid=94,         
			@DimCCID=@Dimesion,
			@DimNodeID=@return_value,
			@UserID=@UserID,    
			@LangID=@LangID 
			
			DELETE FROM COM_Files    
			WHERE FeatureID=@Dimesion and FeaturePK=@return_value
			
			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,
			IsProductImage,IsDefaultImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate)    
			select  FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,
			IsProductImage,IsDefaultImage,@Dimesion,@Dimesion,@return_value,[GUID],CreatedBy,CreatedDate 
			from COM_Files with(nolock)
			where FeatureID=94 and FeaturePK=@TenantID
	end
	IF(@return_value > 0)
	BEGIN
		IF EXISTS (select Value from COM_CostCenterPreferences with(nolock) where Name='CreateUserOnDim' and CostCenterID=@Dimesion and Value='True')
		BEGIN
			DECLARE @Tab nvarchar(100)
			select @Tab=Tablename from adm_features with(nolock) where featureid=@Dimesion  
			set @SQL='select @tempCode=UserNameAlpha from '+@Tab+' with(nolock) where NodeID='+convert(nvarchar,@return_value)
			EXEC sp_executesql @SQL, N'@tempCode nvarchar(max) OUTPUT',@tempCode OUTPUT
			
			IF (@tempCode is not null and @tempCode<>'')
			BEGIN
				declare @FeatureID int,@TableName nvarchar(50),@DUPNODENO INT
				declare @TblDims as Table(ID int identity(1,1), FeatureID int,Name nvarchar(100),TblName nvarchar(100))

				insert into @TblDims
				select FeatureID,Name,TableName from ADM_Features with(nolock) where FeatureID IN (select CostCenterID from COM_CostCenterPreferences with(nolock) where Name='CreateUserOnDim' and Value='True') order by FeatureID

				select @i=1,@Cnt=count(*) from @TblDims
				while(@i<=@Cnt)
				BEGIN
					select @FeatureID=FeatureID,@TableName=TblName from @TblDims where ID=@i
					set @i=@i+1
					set @DUPNODENO=0
					--SELECT @SQL
					IF @Dimesion=@FeatureID
						set @SQL='select @DUPNODENO=count(*) from '+@TableName+' with(nolock) where NodeID!='+convert(nvarchar,@return_value)+' and UserNameAlpha='''+@tempCode+''''
					else
						set @SQL='select @DUPNODENO=count(*) from '+@TableName+' with(nolock) where UserNameAlpha='''+@tempCode+''''
					EXEC sp_executesql @SQL, N'@DUPNODENO INT OUTPUT',@DUPNODENO OUTPUT
					
					IF @DUPNODENO>0
					BEGIN
						RAISERROR('DUPLICATE USER NAME',16,1)  
					END
				END
			END
		END
	END
	if(@AccReturn_value>0 and @AccReturn_value<>'')
	begin
	
		set @UpdateSql='update COM_CCCCDATA    
		SET AccountID='+CONVERT(NVARCHAR,@AccReturn_value)+'  WHERE NodeID = '+
		convert(nvarchar,@TenantID) + ' AND CostCenterID = 94'   
		EXEC (@UpdateSql)  
	
		Exec [spDOC_SetLinkDimension]
			@InvDocDetailsID=@TenantID, 
			@Costcenterid=94,         
			@DimCCID=@AccDim,
			@DimNodeID=@AccReturn_value,
			@UserID=@UserID,    
			@LangID=@LangID 
			
			DELETE FROM COM_Files    
			WHERE FeatureID=@Dimesion and FeaturePK=@return_value
			
			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,
			IsProductImage,IsDefaultImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate)    
			select  FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,
			IsProductImage,IsDefaultImage,@AccDim,@AccDim,@AccReturn_value,[GUID],CreatedBy,CreatedDate 
			from COM_Files with(nolock)
			where FeatureID=94 and FeaturePK=@TenantID
	end
	--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=94 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 94,@TenantID,@UserID,@LangID
	end
	--INSERT INTO HISTROY   
	EXEC [spCOM_SaveHistory]  
		@CostCenterID =94,    
		@NodeID =@TenantID,
		@HistoryStatus =@HistoryStatus,
		@UserName=@UserName,
		@DT=@DT

COMMIT TRANSACTION      
SELECT * FROM [REN_Tenant] WITH(nolock) WHERE TenantID=@TenantID    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @TenantID      
END TRY      
BEGIN CATCH

	if(@return_value=-999)
		return -999
      
	--Return exception info [Message,Number,ProcedureName,LineNumber]      
	IF ERROR_NUMBER()=50000    
	BEGIN    
		SELECT * FROM [REN_Tenant] WITH(nolock) WHERE TenantID=@TenantID      
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
