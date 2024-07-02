USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_SetAccount]
	@AccountID [int],
	@AccountCode [nvarchar](200),
	@AccountName [nvarchar](500),
	@AliasName [nvarchar](500),
	@AccountTypeID [int],
	@StatusID [int],
	@SelectedNodeID [int],
	@IsGroup [bit],
	@CreditDays [int],
	@CreditLimit [float],
	@DebitDays [int],
	@DebitLimit [float],
	@Currency [int],
	@PurchaseAccount [int],
	@SalesAccount [int],
	@COGSAccountID [int],
	@ClosingStockAccountID [int],
	@PDCReceivableAccount [int],
	@PDCPayableAccount [int],
	@IsBillwise [bit],
	@PaymentTerms [int],
	@LetterofCredit [float],
	@TrustReceipt [float],
	@TrustReceiptAccount [int] = 1,
	@MarginAccount [int] = 1,
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@Description [nvarchar](500),
	@UserName [nvarchar](50),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@PrimaryContactQuery [nvarchar](max),
	@ContactsXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@AddressXML [nvarchar](max),
	@AssignCCCCData [nvarchar](max) = null,
	@WID [int] = 0,
	@RoleID [int] = 1,
	@UserID [int] = 0,
	@LangID [int] = 1,
	@CrOptionID [int] = 0,
	@DrOptionID [int] = 0,
	@TB [int] = 0,
	@PL [int] = 0,
	@BS [int] = 0,
	@PLT [int] = 0,
	@IsDrCr [bit] = 0,
	@GLClubTranBy [int] = 0,
	@PDCDiscountAccount [int] = NULL,
	@INTERESTRATE [float] = 0,
	@COMMISSIONRATE [float] = 0,
	@CHECKDISCOUNTLIMIT [float] = 0,
	@DistCost [int] = 0,
	@CodePrefix [nvarchar](200) = NULL,
	@CodeNumber [int] = 0,
	@CreditDebitXML [nvarchar](max) = null,
	@HistoryXML [nvarchar](max) = null,
	@StatusXML [nvarchar](max) = null,
	@IsCode [bit] = 0,
	@GroupSeqNoLength [int] = 0,
	@ReportTemplateXML [nvarchar](max) = null,
	@IsOffline [bit] = 0,
	@PDCOnReplaceAccount [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  DECLARE @Dt float,@XML xml,@TempGuid nvarchar(50),@HasAccess bit,@IsDuplicateNameAllowed bit,@IsDuplicateCodeAllowed bit,@ActionType INT
  DECLARE @UpdateSql nvarchar(max),@ParentCode nvarchar(200),@CCCCCData XML,@IsIgnoreSpace bit  
  DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT  
  DECLARE @SelectedIsGroup bit  ,@HistoryStatus NVARCHAR(300),@AccountTypeAllowDuplicate NVARCHAR(300),@AccountTypeChar NVARCHAR(5)
  declare @isparentcode bit,@RefSelectedNodeID INT
  Declare @level int,@maxLevel int
 set @AccountName=ltrim(@AccountName)
  --User acces check FOR ACCOUNTS  
  IF @AccountID=0  
  BEGIN
	SET @ActionType=1
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,1)  
  END  
  ELSE  
  BEGIN  
	SET @ActionType=3
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,3)  
  END  
  
  IF @HasAccess=0  
  BEGIN  
   RAISERROR('-105',16,1)  
  END  
  
	if(@AccountID=0)
		set @HistoryStatus='Add'
	else
		set @HistoryStatus='Update'
		
  
  --User acces check FOR Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,8)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  
  --User acces check FOR Attachments  
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,12)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  
  --User acces check FOR Contacts  
  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,16)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  
  IF not exists(SELECT  FeatureTypeID FROM ADM_FeatureTypeValues with(nolock) where FeatureTypeID= @AccountTypeID 
  and FeatureID=2 and (userid =@UserID or roleid=@RoleID))
  BEGIN     
    RAISERROR('-357',16,1)  
  END
  
  
  
  IF EXISTS(SELECT StatusID FROM dbo.COM_Status with(nolock)
  WHERE CostCenterID=2 AND Status='Active' AND StatusID=@StatusID )  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,23)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-111',16,1)  
   END  
  END  
  
  IF EXISTS(SELECT StatusID FROM dbo.COM_Status with(nolock)
  WHERE CostCenterID=2 AND Status='In Active' AND StatusID=@StatusID )  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,24)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-113',16,1)  
   END  
  END  
  
  --GETTING PREFERENCE  
    IF @IsGroup=0
    BEGIN
		SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateCodeAllowed'  
		SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateNameAllowed'  
	END
	ELSE
	BEGIN
		SELECT @IsDuplicateCodeAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateGroupCodeAllowed'  
		SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='DuplicateGroupNameAllowed'  
	END
	SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=2 and  Name='IgnoreSpaces'  
	select @isparentcode=IsParentCodeInherited  from COM_CostCenterCodeDef with(nolock) where CostCenterID=2
	SELECT @AccountTypeAllowDuplicate=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=2 and  Name='AccountTypeAllowDuplicate'

	--If Duplicate code allowed then check for AccountType
	SET @AccountTypeChar='~'+CONVERT(nvarchar,@AccountTypeID)+'~'
  
	IF @IsCode=1 AND @AccountID=0 and @AccountCode='' and exists (SELECT * FROM COM_CostCenterCodeDef WITH(nolock)WHERE CostCenterID=2 and IsEnable=1 and IsName=0 and IsGroupCode=@IsGroup)
	BEGIN 
		--CALL AUTOCODEGEN 
		create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
		if(@SelectedNodeID is null)
			insert into #temp1
			EXEC [spCOM_GetCodeData] 2,1,''  
		else
			insert into #temp1
			EXEC [spCOM_GetCodeData] 2,@SelectedNodeID,''  
		select @AccountCode=code,@CodePrefix= prefix, @CodeNumber=number from #temp1
	END	
	
  
  --DUPLICATE CHECK  
  IF @IsDuplicateNameAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
  BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
	BEGIN  
    IF @AccountID=0  
    BEGIN  
     IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup and replace(AccountName,' ','')=replace(@AccountName,' ',''))  
      RAISERROR('-108',16,1)  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup and replace(AccountName,' ','')=replace(@AccountName,' ','') AND AccountID <> @AccountID)  
      RAISERROR('-108',16,1)       
    END  
   END  
   ELSE  
   BEGIN  
    IF @AccountID=0  
    BEGIN  
		 IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup and  AccountName=@AccountName)  
		  RAISERROR('-108',16,1)  
    END  
    ELSE  
    BEGIN  
		 IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup and  AccountName=@AccountName AND AccountID <> @AccountID)  
		  RAISERROR('-108',16,1)  
    END  
   END
 
  END  

  SET @Dt=convert(float,getdate())--Setting Current Date  
  declare @CStatusID int
  SELECT @CStatusID=StatusID
		FROM ACC_Accounts WITH(NOLOCK) where AccountID=@AccountID

  	if(@WID>0 and @AccountID>0)	 
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
		select @level,@maxLevel
		if(@level is not null and  @maxLevel is not null and @maxLevel>@level)
		begin 
		 	set @StatusID=1001 
		end	
		else if(@level is not null and  @maxLevel is not null and @level<@maxLevel and @CStatusID in (1003))--rejected status time
		begin	
		 	set @StatusID=1001 
		end	
		 
		 
	end
  
  	
  IF @AccountID=0--------START INSERT RECORD-----------  
  BEGIN--CREATE ACCOUNT--  
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
    from [ACC_Accounts] with(NOLOCK) where AccountID=@SelectedNodeID  
   
    --IF No Record Selected or Record Doesn't Exist  
    if(@SelectedIsGroup is null)   
     select @SelectedNodeID=AccountID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
     from [ACC_Accounts] with(NOLOCK) where ParentID =0  
         
    if(@SelectedIsGroup = 1)--Adding Node Under the Group  
     BEGIN  
      UPDATE ACC_Accounts SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
      UPDATE ACC_Accounts SET lft = lft + 2 WHERE lft > @Selectedlft;  
      set @lft =  @Selectedlft + 1  
      set @rgt = @Selectedlft + 2  
      set @ParentID = @SelectedNodeID  
      set @Depth = @Depth + 1  
     END  
    else if(@SelectedIsGroup = 0)--Adding Node at Same level  
     BEGIN  
      UPDATE ACC_Accounts SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
      UPDATE ACC_Accounts SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
     
     if @ParentID=1 and @IsGroup=0 and not exists (select Value from COM_CostCenterPreferences with(nolock) where FeatureID=2 and Name='AllowChildAtRoot' and Value='True')
     begin
		RAISERROR('-224',16,1)
     end
	
    if @IsOffline=0
	 begin
      -- Insert statements for procedure here  
	  INSERT INTO [ACC_Accounts]  
       (CodePrefix,CodeNumber,[AccountCode],[AccountName],[AliasName],[AccountTypeID],[StatusID],
       [Depth],[ParentID],[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[DebitDays],[DebitLimit],
       [PurchaseAccount],[SalesAccount],[COGSAccountID],[ClosingStockAccountID],PDCReceivableAccount,PDCPayableAccount,PDCReplaceAccount,
       [IsBillwise],[PaymentTerms],LetterofCredit,TrustReceipt,  TrustReceiptAccount,MarginAccount, 
       [CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedDate],Currency,CrOptionID,
	   DrOptionID,TB_INT ,PL ,BS ,PLT,PDCDiscountAccount,InterestRate,CommissionRate,CheckDiscountLimit,GLClubTranBy,DistCost,WorkFlowID,WorkFlowLevel)    
       VALUES  
       (@CodePrefix,@CodeNumber,@AccountCode,@AccountName,@AliasName,@AccountTypeID,@StatusID,  
       @Depth,@ParentID,@lft,@rgt,@IsGroup,@CreditDays,@CreditLimit,@DebitDays,@DebitLimit,  
       @PurchaseAccount,@SalesAccount,@COGSAccountID,@ClosingStockAccountID,@PDCReceivableAccount,@PDCPayableAccount,@PDCOnReplaceAccount,
       @IsBillwise,@PaymentTerms,@LetterofCredit,@TrustReceipt,isnull(@TrustReceiptAccount,0),isnull(@MarginAccount,0), 
       @CompanyGUID,newid(),@Description,  
       @UserName,@Dt,@Dt,@Currency,@CrOptionID,
  	  @DrOptionID,@TB,@PL,@BS,@PLT,@PDCDiscountAccount,@INTERESTRATE,@COMMISSIONRATE,@CHECKDISCOUNTLIMIT,@GLClubTranBy,@DistCost,@WID,@level)  
		--To get inserted record primary key  
		SET @AccountID=SCOPE_IDENTITY()  
    end
    else
    begin
		set identity_insert [ACC_Accounts] ON
		select @AccountID=min(AccountID) from acc_accounts with(nolock)
		if(@AccountID>-10000)
			set @AccountID=-10001
		else
			set @AccountID=@AccountID-1
			
		-- Insert statements for procedure here  
	   INSERT INTO [ACC_Accounts]  
       (AccountID,CodePrefix,CodeNumber,[AccountCode],[AccountName],[AliasName],[AccountTypeID],[StatusID],
       [Depth],[ParentID],[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[DebitDays],[DebitLimit],
       [PurchaseAccount],[SalesAccount],[COGSAccountID],[ClosingStockAccountID],PDCReceivableAccount,PDCPayableAccount,PDCReplaceAccount,
       [IsBillwise],[PaymentTerms],LetterofCredit,TrustReceipt,  TrustReceiptAccount,MarginAccount, 
       [CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedDate],Currency,CrOptionID,
	   DrOptionID,TB_INT ,PL ,BS ,PLT,PDCDiscountAccount,InterestRate,CommissionRate,CheckDiscountLimit,GLClubTranBy,DistCost,WorkFlowID,WorkFlowLevel)  
       VALUES  
       (@AccountID,@CodePrefix,@CodeNumber,@AccountCode,@AccountName,@AliasName,@AccountTypeID,@StatusID,  
       @Depth,@ParentID,@lft,@rgt,@IsGroup,@CreditDays,@CreditLimit,@DebitDays,@DebitLimit,  
       @PurchaseAccount,@SalesAccount,@COGSAccountID,@ClosingStockAccountID,@PDCReceivableAccount,@PDCPayableAccount,@PDCOnReplaceAccount,
       @IsBillwise,@PaymentTerms,@LetterofCredit,@TrustReceipt,isnull(@TrustReceiptAccount,0),isnull(@MarginAccount,0), 
       @CompanyGUID,newid(),@Description,  
       @UserName,@Dt,@Dt,@Currency,@CrOptionID,
  	   @DrOptionID,@TB,@PL,@BS,@PLT,@PDCDiscountAccount,@INTERESTRATE,@COMMISSIONRATE,@CHECKDISCOUNTLIMIT,@GLClubTranBy,@DistCost,@WID,@level)
  	   set identity_insert [ACC_Accounts] OFF
  	   
		if exists(select [Value] from  ADM_GlobalPreferences with(nolock) WHERE [Name]='IsControlAccounts' and [Value]='True')
			and exists (select AccountTypeID from ACC_Accounts with(nolock) where AccountID=@AccountID and AccountTypeID in (6,7) and IsBillwise=0)
			and exists (select AccountID from COM_BillWise with(nolock) where AccountID=@AccountID)
			and dbo.fnCOM_HasAccess(@RoleID,2,182)=0
		begin
			RAISERROR('-223',16,1)
		end
  	   
  	   INSERT INTO ADM_OfflineOnlineIDMap VALUES(2,@AccountID,0)
    end  
   
    --Handling of Extended Table  
    INSERT INTO [ACC_AccountsExtended]([AccountID],[CreatedBy],[CreatedDate])  
    VALUES(@AccountID, @UserName, @Dt)  
  
    --Handling of CostCenter Costcenters Extrafields Table  

    --INSERT INTO ACC_AccountCostCenterMap ([AccountID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
   -- VALUES(@AccountID, @UserName, @Dt, @CompanyGUID,newid())  

   INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
     VALUES(2,@AccountID,newid(),  @UserName, @Dt)  

     
     
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
    ,2  
    ,@AccountID  
    ,@CompanyGUID  
    ,NEWID()  
    ,@UserName,@Dt  
    )  
    INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 	VALUES(SCOPE_IDENTITY(), @UserName, @DT)



if(@WID>0)
	BEGIN	 
		INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
		VALUES(2,@AccountID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
	end



			 	
   END--------END INSERT RECORD-----------  
  ELSE--------START UPDATE RECORD-----------  
  BEGIN   
  
  --GENERATE CODE  
  --CODE COMMENTED BY ADIL
/*	if(@isparentcode=1)
	begin
		if(@CodeNumber=0)
		begin
			set @AccountCode=@CodePrefix
		end
		else
		begin
			set @AccountCode=@CodePrefix+convert(nvarchar,@CodeNumber)
		end	
	end*/
  
  
   IF EXISTS(SELECT AccountID FROM ACC_Accounts with(nolock) WHERE AccountID=@AccountID AND ParentID=0)  
   BEGIN  
    RAISERROR('-123',16,1)  
   END  
      
   SELECT @TempGuid=[GUID] from [ACC_Accounts]  WITH(NOLOCK)   
   WHERE AccountID=@AccountID  
  
   IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
   BEGIN 
   print '-101'
       --RAISERROR('-101',16,1)   
   END    
   ELSE    
   BEGIN   
  
  
	if exists(select * from [ACC_Accounts] WITH(NOLOCK) where AccountID=@AccountID and [IsBillwise] <> @IsBillwise)
	BEGIN
		if (select count(*) from acc_docdetails WITH(NOLOCK) where DebitAccount=@AccountID or CreditAccount=@AccountID)>0
			RAISERROR('-583',16,1)   
	END
    
  --checking AccountType While Saving for Vendor Users
	 Declare @AccTypeID Nvarchar(100)
	 SELECT @AccTypeID=AccountTypeID from [ACC_Accounts]  WITH(NOLOCK)  WHERE AccountID=@AccountID  
  
	 IF(@AccTypeID != @AccountTypeID)  
	 BEGIN 
		if exists(select * from COM_Contacts WITH(NOLOCK) where FeaturePK=@AccountID and FeatureID = 2 and UserID is not null)
			RAISERROR('Cannot Change Account Type ,User Created With Reference to it',16,1)
	 END   

   --Delete mapping if any  
 --  DELETE FROM  ACC_AccountCostCenterMap WHERE AccountID=@AccountID  

    --DELETE FROM  COM_CCCCDATA WHERE NodeID=@AccountID AND  CostCenterID = 2


  
   --Handling of CostCenter Costcenters Extrafields Table  
   --INSERT INTO ACC_AccountCostCenterMap ([AccountID],[CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
   --VALUES(@AccountID, @UserName, @Dt, @CompanyGUID,newid())  

   
    --INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[CompanyGUID],[Guid],[CreatedBy],[CreatedDate])
    -- VALUES(2,@AccountID, @CompanyGUID,newid(),  @UserName, @Dt)      
 
  
    UPDATE [ACC_Accounts]  
       SET [AccountCode] = @AccountCode  
       ,[AccountName] = @AccountName  
       ,[AliasName] = @AliasName  
       ,[AccountTypeID] = @AccountTypeID  
       ,[StatusID] = @StatusID  
       ,[IsGroup] = @IsGroup  
       ,[CreditDays] = @CreditDays  
       ,[CreditLimit] = @CreditLimit  
       ,[DebitDays] = @DebitDays  
       ,[DebitLimit] = @DebitLimit  
       ,[PurchaseAccount] = @PurchaseAccount  
       ,[SalesAccount] = @SalesAccount
	   ,[COGSAccountID] = @COGSAccountID
	   ,[ClosingStockAccountID] = @ClosingStockAccountID  
	   ,PDCReceivableAccount=@PDCReceivableAccount
	   ,PDCPayableAccount=@PDCPayableAccount
	   ,PDCReplaceAccount=@PDCOnReplaceAccount
       ,[IsBillwise] = @IsBillwise       
       ,[PaymentTerms] = @PaymentTerms    
       ,LetterofCredit = @LetterofCredit
       ,TrustReceipt = @TrustReceipt
       ,TrustReceiptAccount=isnull(@TrustReceiptAccount,0)
       ,MarginAccount=isnull(@MarginAccount  ,0)
       ,[GUID] =  newid()  
       ,[Description] = @Description     
       ,[ModifiedBy] = @UserName  
       ,[ModifiedDate] = @Dt,Currency=@Currency ,
	  CrOptionID =  @CrOptionID,
  	  DrOptionID = @DrOptionID,
  	  TB_INT=@TB ,PL=@PL ,BS=@BS ,PLT  =@PLT,
  	  PDCDiscountAccount=@PDCDiscountAccount,InterestRate=@INTERESTRATE,CommissionRate=@COMMISSIONRATE
  	  ,CheckDiscountLimit=@CHECKDISCOUNTLIMIT,GLClubTranBy=@GLClubTranBy,CodePrefix=@CodePrefix,CodeNumber=@CodeNumber    	  
  	  ,DistCost=@DistCost
	  ,WorkFlowLevel=isnull(@level,0)
     WHERE AccountID=@AccountID        
       
   END  
  END  
  
	if exists(select * from sys.columns where object_ID=object_ID('ACC_Accounts') and name='IsDrCr')
	BEGIN
			set @UpdateSql='update [ACC_Accounts]  
			SET IsDrCr ='+ convert(nvarchar,@IsDrCr) 
			+'WHERE AccountID='+convert(nvarchar,@AccountID)   
			exec(@UpdateSql)  
	END		
 
  --CHECK WORKFLOW
  --EXEC spCOM_CheckCostCentetWF 2,@AccountID,@WID,@RoleID,@UserID,@UserName,@StatusID output
 
  --SETTING ACCOUNT CODE EQUALS AccountID IF EMPTY  
  IF(@AccountCode IS NULL OR @AccountCode='')  
  BEGIN
	set @AccountCode=convert(nvarchar,@AccountID)
	IF  @IsDuplicateCodeAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
	begin
		declare @I INT
		set @I=@AccountID
		while(1=1)
		begin
			set @AccountCode=convert(nvarchar,@I)
			if not EXISTS (SELECT AccountID FROM ACC_Accounts WITH(NOLOCK) WHERE IsGroup=@IsGroup and [AccountCode]=@AccountCode AND AccountID<>@AccountID)
				break;
			set @I=@I+1
		end
	end
	UPDATE  [ACC_Accounts]  
	SET [AccountCode]=@AccountCode  
	WHERE AccountID=@AccountID        
  END
  
  if(@isparentcode=0)
  BEGIN
   --DUPLICATE CODE CHECK  
	  IF @IsDuplicateCodeAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
	  BEGIN
		 IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup and [AccountCode]=@AccountCode AND AccountID<>@AccountID)  
			RAISERROR('-116',16,1)  
	  END
  END
  ELSE
  BEGIN 
   --DUPLICATE CODE CHECK  WHEN INHERIT PARENT CHECKED
	  IF @IsDuplicateCodeAllowed=0 OR charindex(@AccountTypeChar,@AccountTypeAllowDuplicate,1)=0
	  BEGIN
		 IF EXISTS (SELECT AccountID FROM ACC_Accounts WITH(nolock) WHERE IsGroup=@IsGroup and AccountID<>@AccountID and ([AccountCode]=@AccountCode))--  or (CodePrefix=@CodePrefix and CodeNumber=@CodeNumber)
			RAISERROR('-116',16,1)  
	  END
  END

 -- , BEFORE MODIFIEDBY  REQUIRES A NULL CHECK OF @PrimaryContactQuery 
  IF(@PrimaryContactQuery IS NOT NULL AND @PrimaryContactQuery<>'')
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE
		EXEC spCOM_SetFeatureWiseContacts 2,@AccountID,1,@PrimaryContactQuery,@UserName,@Dt,@LangID
  END
  
  --Update Extra fields  
  if @CustomFieldsQuery is not null or @CustomFieldsQuery<>''
  begin
	  set @UpdateSql='update [ACC_AccountsExtended]  
	  SET '+@CustomFieldsQuery+'[ModifiedBy] ='''+ @UserName  
		+''',[ModifiedDate] =@ModDate WHERE AccountID='+convert(nvarchar,@AccountID)   
	  EXEC sp_executesql @UpdateSql,N'@ModDate float',@Dt
  end
  if exists (select CostCenterColID from adm_costcenterdef  with(nolock) where CostCenterID=2 and CostCenterColID=244)
  and ((select count(*) from sys.columns where object_id=object_id('ACC_AccountsExtended') and name in ('acAlpha51','acAlpha60'))=2)
	  begin
		set @UpdateSql='
		if exists (select acAlpha60 from ACC_AccountsExtended with(nolock) where AccountID=@AccountID and acAlpha60=0)
		begin
			update ACC_AccountsExtended set acAlpha60=@AccountID where AccountID=@AccountID 
		end'
		EXEC sp_executesql @UpdateSql,N'@AccountID int',@AccountID
		set @UpdateSql='
declare @TRN nvarchar(max),@GA BIGINT
select @TRN=acAlpha51,@GA=acAlpha60 from ACC_AccountsExtended with(nolock) where AccountID=@AccountID
if @TRN is not null and @TRN!=''''
begin
	if len(@TRN)!=15
		RAISERROR(''Tax Registration Number - TRN/TIN length should be 15'',16,1)
	else
	begin
		begin try
			select convert(BIGINT,@TRN)
		end try
		begin catch
			RAISERROR(''Invalid Tax Registration Number - TRN/TIN'',16,1)
		end catch
	end
	if exists (select acAlpha51 from ACC_AccountsExtended with(nolock) where acAlpha60!=@GA and acAlpha51=@TRN)
	begin
		set @TRN=''Duplicate Tax Registration Number - TRN/TIN - ''+@TRN
		RAISERROR(@TRN,16,1)
	end
	else if exists (select acAlpha51 from ACC_AccountsExtended with(nolock) where acAlpha60=@GA and acAlpha51!=@TRN)
	begin
		set @TRN=''Group Company Account has different Tax Registration Number - TRN/TIN - ''+@TRN
		RAISERROR(@TRN,16,1)
	end
end'
		EXEC sp_executesql @UpdateSql,N'@AccountID int',@AccountID
	end
	  

    set @UpdateSql='update COM_CCCCDATA  
	SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID = '+convert(nvarchar,@AccountID) + ' AND CostCenterID = 2' 
  exec(@UpdateSql)  

	--Duplicate Check
	exec [spCOM_CheckUniqueCostCenter] @CostCenterID=2,@NodeID =@AccountID,@LangID=@LangID

	--Series Check
	declare @retSeries INT
	EXEC @retSeries=spCOM_ValidateCodeSeries 2,@AccountID,@LangId
	if @retSeries>0
	begin
		ROLLBACK TRANSACTION
		SET NOCOUNT OFF  
		RETURN -999
	end
  

  --ADDED CODE ON DEC 08 2011 BY HAFEEZ  

  IF  (@AssignCCCCData IS NOT NULL AND @AssignCCCCData <> '')   
  BEGIN    
    SET @CCCCCData=@AssignCCCCData  
    
    EXEC [spCOM_SetCCCCMap] 2,@AccountID,@CCCCCData,@UserName,@LangID  
    
    if(@IsGroup=1 and not exists(select Name from com_costcenterpreferences with(nolock) where CostCenterID=2 and Name='DontAssignGroupToNodes' and Value='True'))
    begin
		declare @count int, @a int,@acc INT 
		create table #temp (id int identity(1,1), Accountid INT )
		insert into #temp
		select AccountID from acc_accounts with(nolock) where lft between (select lft from acc_accounts with(nolock) where accountid=@AccountID) 
	    and (select rgt from acc_accounts with(nolock) where accountid=@AccountID) and accountid<>@AccountID order by lft
	    select @a=1,@count=count(*) from #temp with(nolock)	

	    while @a<=@count
	    begin
			select @acc=Accountid from #temp with(nolock) where id=@a   
 
			EXEC [spCOM_SetCCCCMap] 2,@acc,@CCCCCData,@UserName,@LangID  
			set @a=@a+1
	    end
	    drop table #temp 
	end
  END  
  
  --Dimension History Data
  IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
	EXEC spCOM_SetHistory 2,@AccountID,@HistoryXML,@UserName  

  --Inserts Multiple Contacts  
  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE  
		 declare @rValue int
		EXEC @rValue =  spCOM_SetFeatureWiseContacts 2,@AccountID,2,@ContactsXML,@UserName,@Dt,@LangID  
		 IF @rValue=-1000  
		  BEGIN  
			RAISERROR('-500',16,1)  
		  END   
  END  
  
  	
  --Inserts Multiple Address  
  EXEC spCOM_SetAddress 2,@AccountID,@AddressXML,@UserName  
  
  IF (@StatusXML IS NOT NULL AND @StatusXML <> '')
		exec spCOM_SetStatusMap 2,@AccountID,@StatusXML,@UserName,@Dt

  --Inserts Multiple Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @XML=@NotesXML  
  
   --If Action is NEW then insert new Notes  
   INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
   GUID,CreatedBy,CreatedDate)  
   SELECT 2,2,@AccountID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
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
   WHERE X.value('@Action','NVARCHAR(10)')='MODIFY'  
  
   --If Action is DELETE then delete Notes  
   DELETE FROM COM_Notes  
   WHERE NoteID IN(SELECT X.value('@NoteID','INT')  
    FROM @XML.nodes('/NotesXML/Row') as Data(X)  
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
  
  END  
  
  --Inserts Multiple notes  
 -- EXEC spCOM_SetNotes 2,@AccountID,@NotesXML,@UserName  
   
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
	exec [spCOM_SetAttachments] @AccountID,2,@AttachmentsXML,@UserName,@Dt
   
	--Creating Dimension based on Preference 'AccountTypeLinkDimension'
	declare @CC nvarchar(max), @CCID nvarchar(10),@Tabs nvarchar(200),@CCContactsXML nvarchar(max), @CCAttachmentsXML nvarchar(max),@CCNotesXML nvarchar(max), @CCAddressXML nvarchar(max),@CCAssignCCCCData NVARCHAR(MAX)
	SELECT @CC=[Value] FROM com_costcenterpreferences with(nolock) WHERE [Name]='AccountTypeLinkDimension'
	SELECT @Tabs=[Value] FROM com_costcenterpreferences with(nolock) WHERE [Name]='CopyTabs' and costcenterid=2
	
	if (@CC is not null and @CC<>'')-- and @IsGroup=0)
	begin
		DECLARE @TblCC AS TABLE(ID INT IDENTITY(1,1),CC nvarchar(100))
		DECLARE @TblCCVal AS TABLE(ID INT IDENTITY(1,1),CC2 nvarchar(100))
		
		--START TABS
		SET @CCContactsXML=''
		SET @CCAttachmentsXML=''
		SET @CCNotesXML=''
		SET @CCAddressXML=''
		SET @CCAssignCCCCData=''
		SELECT @CCContactsXML = CASE WHEN @Tabs LIKE '%1%' THEN @ContactsXML ELSE '' END
		SELECT @CCAddressXML = CASE WHEN @Tabs LIKE '%2%' THEN @AddressXML ELSE '' END
		SELECT @CCNotesXML = CASE WHEN @Tabs LIKE '%3%' THEN @NotesXML ELSE '' END
		SELECT @CCAttachmentsXML = CASE WHEN @Tabs LIKE '%4%' THEN @AttachmentsXML ELSE '' END
		SELECT @CCAssignCCCCData = CASE WHEN @Tabs LIKE '%5%' THEN @AssignCCCCData ELSE '' END
		--END TABS
		
		INSERT INTO @TblCC(CC)
		EXEC SPSplitString @CC,','
		declare @cnt int
		declare @value nvarchar(max)
		set @i=1
		select @cnt=count(*) from @TblCC
		while @i<=@cnt
		begin
			select @value=cc from @TblCC where id=@i
			--select @value
			insert into @TblCCVal (CC2)
			EXEC SPSplitString @value,'~'
			 --select cc2 from @TblCCVal
			if exists (select cc2 from @TblCCVal where cc2 =@AccountTypeID )
			begin
			
				select @CCID=cc2 from @TblCCVal where cc2>50000   
				--select @CCID
				if(@CCID>50000)
				begin
					declare @CCStatusID INT
					set @CCStatusID = (select top 1 statusid from com_status with(nolock) where costcenterid=@CCID)
					declare @NID INT, @CCIDAcc INT
					select @NID = CCNodeID, @CCIDAcc=CCID  from acc_Accounts with(nolock) where Accountid=@AccountID
					iF(@CCIDAcc<>@CCID)
					BEGIN
						if(@NID>0)
						begin 
						Update Acc_accounts set CCID=0, CCNodeID=0 where AccountID=@AccountID
						DECLARE @RET INT
							EXEC	@RET = [dbo].[spCOM_DeleteCostCenter]
								@CostCenterID = @CCIDAcc,
								@NodeID = @NID,
								@RoleID=1,
								@UserID = 1,
								@LangID = @LangID
						end	
						set @NID=0
						set @CCIDAcc=0 
					END
					
					declare @return_value int
					if(@NID is null or @NID =0)
					begin 
						SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
								WHERE CostCenterID=2 AND RefDimensionID=@CCID AND NodeID=@SelectedNodeID 
						
						SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
						
						EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
						@NodeID = 0,@SelectedNodeID =@RefSelectedNodeID,@IsGroup = @IsGroup,
						@Code = @AccountCode,
						@Name = @AccountName,
						@AliasName=@AccountName,
						@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
						@CustomFieldsQuery=null,@AddressXML=@CCAddressXML,@AttachmentsXML=@CCAttachmentsXML,
						@CustomCostCenterFieldsQuery=@CustomCostCenterFieldsQuery,@ContactsXML=@CCContactsXML,@NotesXML=@CCNotesXML,
						@CostCenterRoleXML=@CCAssignCCCCData,
						@CostCenterID = @CCID,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1,
						@CheckLink = 0,@IsOffline=@IsOffline 
						 -- Link Dimension Mapping
						INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)
						values(2, @AccountID,0,0,@CCID,@return_value,'',newid(),@UserName, @dt,'Account')
						DECLARE @CCMapSql nvarchar(max)
						set @CCMapSql='update COM_CCCCDATA  
						SET CCNID'+convert(nvarchar,(@CCID-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  WHERE NodeID = '+convert(nvarchar,@AccountID) + ' AND CostCenterID = 2' 
						EXEC (@CCMapSql)
				 	end
					else
					begin
						declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)
						declare @NodeidXML nvarchar(max) 
						select @Table=Tablename from adm_features where featureid=@CCID
						declare @str nvarchar(max) 
						set @str='@Gid nvarchar(50) output' 
						set @NodeidXML='set @Gid= (select GUID from '+@Table+' with(nolock) where NodeID='+convert(nvarchar,@NID)+')'
							exec sp_executesql @NodeidXML, @str, @Gid OUTPUT 
							
						SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
						WHERE CostCenterID=2 AND RefDimensionID=@CCID AND NodeID=@AccountID 
						
						SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
					
						EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
						@NodeID = @NID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
						@Code = @AccountCode,
						@Name = @AccountName,
						@AliasName=@AccountName,
						@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
						@CustomFieldsQuery=null,@AddressXML=NULL,@AttachmentsXML=NULL,
						@CustomCostCenterFieldsQuery=@CustomCostCenterFieldsQuery,@ContactsXML=NULL,@NotesXML=NULL,
						@CostCenterRoleXML=@CCAssignCCCCData,
						@CostCenterID = @CCID,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1
						,@CheckLink = 0,@IsOffline=@IsOffline
						
						--Notes
						DECLARE @NOTEID INT
						if(isnull(@CCNotesXML,'')<>'')
						begin
							SET @NOTEID=(SELECT TOP 1 N.FEATUREPK FROM  COM_NOTES N WITH(NOLOCK),COM_DocBridge B WITH(NOLOCK)
							WHERE N.FEATUREID=B.REFDIMENSIONID AND N.FEATUREPK=B.REFDIMENSIONNODEID AND B.COSTCENTERID=2 AND B.NODEID=@AccountID)
							if(isnull(@NOTEID,0)>0)
							begin
								DELETE FROM  COM_Notes 	WHERE FeatureID=@CCID and  FeaturePK =@NOTEID
								INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,GUID,CreatedBy,CreatedDate)  
								SELECT @CCID,@CCID,@NOTEID,Note,newid(),@UserName,@Dt FROM  COM_Notes	WHERE FeatureID=2 and  FeaturePK =@AccountID
							end
						end
						
						--Address
						DECLARE @ADDRESSID INT
						if(isnull(@CCAddressXML,'')<>'')
						begin
							SET @ADDRESSID=(SELECT TOP 1 N.FEATUREPK FROM  COM_Address N WITH(NOLOCK),COM_DocBridge B WITH(NOLOCK)
											WHERE N.FEATUREID=B.REFDIMENSIONID AND N.FEATUREPK=B.REFDIMENSIONNODEID AND B.COSTCENTERID=2 AND B.NODEID=@AccountID)
							if(isnull(@ADDRESSID,0)>0)
							begin											
								DELETE FROM  COM_Address WHERE FeatureID=@CCID and  FeaturePK =@ADDRESSID and AddressTypeID<>1
								
								IF(@CCAddressXML like '%AddressTypeID="1"%')
										DELETE FROM  COM_Address WHERE FeatureID=@CCID and  FeaturePK =@ADDRESSID and AddressTypeID=1
								
								SET @CCAddressXML=Replace(@CCAddressXML,'MODIFY','NEW')
								SET @CCAddressXML=Replace(@CCAddressXML,'AddressID','ADDID')
								EXEC spCOM_SetAddress @CCID,@ADDRESSID,@CCAddressXML,@UserName  
							end
						end
						
						--Attachment
						DECLARE @ATTACHMENTID INT
						if(isnull(@CCAttachmentsXML,'')<>'')
						begin
							SET @ATTACHMENTID=(SELECT TOP 1 N.FEATUREPK FROM  COM_FILES N WITH(NOLOCK),COM_DocBridge B WITH(NOLOCK)
							WHERE N.FEATUREID=B.REFDIMENSIONID AND N.FEATUREPK=B.REFDIMENSIONNODEID AND B.COSTCENTERID=2 AND B.NODEID=@AccountID)
							if(isnull(@ATTACHMENTID,0)>0)
							begin
								DELETE FROM  COM_FILES WHERE FeatureID=@CCID and  FeaturePK =@ATTACHMENTID
							
								INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate , IsDefaultImage,LocationID ,DivisionID,ColName,ValidTill,HasThumb
													,IssueDate,Type,RefNum,Remarks,DocNo,status,AllowInPrint,IsSign)
								select FilePath,ActualFileName,RelativeFileName,FileExtension,FileDescription,IsProductImage,@CCID,@CCID,@ATTACHMENTID,[GUID],CreatedBy,CreatedDate , IsDefaultImage,LocationID ,DivisionID,ColName,ValidTill,HasThumb
													,IssueDate,Type,RefNum,Remarks,DocNo,status,AllowInPrint,IsSign from com_files with(nolock) where FeatureID=2 and  FeaturePK =@AccountID
							end
						end
						
						--Contact
						DECLARE @CONTACTID INT
						if(isnull(@CCContactsXML,'')<>'')
						begin
							SET @CONTACTID=(SELECT TOP 1 N.FEATUREPK FROM  COM_Contacts N WITH(NOLOCK),COM_DocBridge B WITH(NOLOCK)
							WHERE N.FEATUREID=B.REFDIMENSIONID AND N.FEATUREPK=B.REFDIMENSIONNODEID AND B.COSTCENTERID=2 AND B.NODEID=@AccountID)
							if(isnull(@CONTACTID,0)>0)
							begin
								DELETE FROM COM_ContactsExtended WHERE ContactID in (SELECT CONTACTID FROM COM_Contacts WHERE  FeatureID=@CCID and  FeaturePK =@CONTACTID AND AddressTypeID<>1)
								DELETE FROM COM_Contacts WHERE  FeatureID=@CCID and  FeaturePK =@CONTACTID AND AddressTypeID<>1
							
								SET @CCContactsXML=Replace(@CCContactsXML,'MODIFY','NEW')
								SET @CCContactsXML=Replace(@CCContactsXML,'ContactID','ContID')
								 declare @rValue1 int
								EXEC @rValue1 = spCOM_SetFeatureWiseContacts @CCID,@CONTACTID,2,@CCContactsXML,@UserName,@Dt,@LangID   
							end
						end
						
				 	end 
					if(@return_value>0 or @return_value<-10000)
					BEGIN
						Exec [spDOC_SetLinkDimension]
							@InvDocDetailsID=@AccountID, 
							@Costcenterid=2,         
							@DimCCID=@CCID,
							@DimNodeID=@return_value,
							@BasedOnValue=@AccountTypeID,
							@UserID=@UserID,    
							@LangID=@LangID 
					END
					Update Acc_accounts set CCID=@CCID, CCNodeID=@return_value where AccountID=@AccountID  
					
				end
			end
			delete from @TblCCVal
			set @i=@i+1
		end 
	end
  
  --validate Data External function
	DECLARE @tempCode NVARCHAR(200)
	set @tempCode=''
	select @tempCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=2 and Mode=9
	if(@tempCode<>'')
	begin
		exec @tempCode 2,@AccountID,@UserID,@LangID
	end
	
  --Inserts Location Division Wise Credit & Debit Amount
    IF (@CreditDebitXML IS NOT NULL AND @CreditDebitXML <> '')  
	BEGIN 
		SET @XML=@CreditDebitXML  
		
		if exists(select * from Acc_CreditDebitAmount with(nolock) where AccountID=@AccountID)
		BEGIN
			delete from Acc_CreditDebitAmount where AccountID=@AccountID
		END
		
		insert into Acc_CreditDebitAmount(AccountID,LocationID,DivisionID,DimensionID,CurrencyID,CreditAmount,DebitAmount,CreditDays,DebitDays,Guid,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate
		,CrOptionID,DrOptionID,CreditRemarks,DebitRemarks)
		       select @AccountID,X.value('@LocationID','INT'),X.value('@DivisionID','INT'),X.value('@DimensionID','INT'),X.value('@CurrencyID','INT'),
					  X.value('@Credit','float'),X.value('@Debit','float'),X.value('@CreditDays','INT'),X.value('@DebitDays','INT'),newid(),@Dt,@UserID,@Dt,@UserID
				,X.value('@CrOptionID','int'),X.value('@DrOptionID','int'),X.value('@CreditRemarks','NVARCHAR(MAX)'),X.value('@DebitRemarks','NVARCHAR(MAX)')
			   FROM @XML.nodes('/XML/Row') as Data(X) 	 	  

    END
    
    if(@ReportTemplateXML iS NOT NULL AND @ReportTemplateXML <> '')  
    BEGIN
		set @XML=@ReportTemplateXML
		
		delete from ACC_ReportTemplate where accountid=@AccountID 
		if(@IsGroup=1)
		BEGIN
			DECLARE @GLFT INT, @GRGT INT
			select @GLFT=LFT, @GRGT=rgt FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID= @AccountID
			
			DELETE FROM ACC_REPORTTEMPLATE
			WHERE TemplateReportID IN (
				SELECT TemplateReportID FROM ACC_REPORTTEMPLATE with(nolock) 
				inner join @XML.nodes('/XML/Row') as Data(X) ON X.value('@TemplateNodeID','INT')=TemplateNodeID
				WHERE ACCOUNTID IN (SELECT AccountID FROM ACC_ACCOUNTS with(nolock) WHERE LFT>@GLFT AND RGT<@GRGT))
			--DELETE FROM ACC_REPORTTEMPLATE WHERE ACCOUNTID IN (SELECT AccountID FROM ACC_ACCOUNTS with(nolock) WHERE LFT>@GLFT AND RGT<@GRGT)			
		END
		
		insert into ACC_ReportTemplate([TemplateNodeID],[AccountID],[DrNodeID],[CrNodeID],[CreatedBy],[CreatedDate], RTDate,RTGroup)
		select X.value('@TemplateNodeID','INT'),@AccountID,X.value('@DrNodeID','INT'),
		X.value('@CrNodeID','INT'),@UserName,@Dt,Convert(float,X.value('@RTDate','DateTime')),X.value('@Grp','nvarchar(50)')
		FROM @XML.nodes('/XML/Row') as Data(X) 	
	END
    --Insert Notifications
	EXEC spCOM_SetNotifEvent @ActionType,2,@AccountID,@CompanyGUID,@UserName,@UserID,-1
	
	if(@GroupSeqNoLength>0)
		update ACC_Accounts set GroupSeqNoLength=@GroupSeqNoLength where AccountID=@AccountID
  

	--INSERT INTO HISTROY   
	EXEC [spCOM_SaveHistory]  
		@CostCenterID =2,    
		@NodeID =@AccountID,
		@HistoryStatus =@HistoryStatus,
		@UserName=@UserName,
		@DT=@DT
	
	
 COMMIT TRANSACTION    
 --ROLLBACK TRANSACTION    
 
SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountID=@AccountID  

IF @ActionType=1
	SELECT   ErrorMessage + ' ''' + isnull(@AccountCode,'')+'''' as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
	WHERE ErrorNumber=105 AND LanguageID=@LangID 
ELSE	
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID  
	
SET NOCOUNT OFF;    
RETURN @AccountID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
	IF ISNUMERIC(ERROR_MESSAGE())=1
	BEGIN
		SELECT * FROM [ACC_Accounts] WITH(nolock) WHERE AccountID=@AccountID    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END
	ELSE
		SELECT ERROR_MESSAGE() ErrorMessage
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
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
