USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenter]
	@NodeID [int],
	@SelectedNodeID [int],
	@IsGroup [bit],
	@Code [nvarchar](max) = NULL,
	@Name [nvarchar](max),
	@AliasName [nvarchar](max),
	@PurchaseAccount [int],
	@SalesAccount [int],
	@CreditLimit [float] = 0,
	@CreditDays [int] = 0,
	@DebitLimit [float] = 0,
	@DebitDays [int] = 0,
	@StatusID [int],
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@ContactsXML [nvarchar](max),
	@AddressXML [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@PrimaryContactQuery [nvarchar](max) = NULL,
	@CostCenterRoleXML [nvarchar](max) = NULL,
	@CostCenterID [int],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@WID [int] = 0,
	@RoleID [int] = 0,
	@UserID [int],
	@LangID [int] = 1,
	@CodePrefix [nvarchar](200) = null,
	@CodeNumber [int] = 0,
	@GroupSeqNoLength [int] = 0,
	@JobsProductXML [nvarchar](max) = NULL,
	@DimMappingXML [nvarchar](max) = null,
	@HistoryXML [nvarchar](max) = null,
	@StatusXML [nvarchar](max) = null,
	@DocXML [nvarchar](max) = null,
	@CalendarXML [nvarchar](max) = null,
	@IsOffline [bit] = 0,
	@CheckLink [bit] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  DECLARE @HasAccess BIT,@Dt FLOAT ,@PARENTCODE NVARCHAR(300),@ExtendedColsXML NVARCHAR(MAX), @UpdateSql nvarchar(max), @Table NVARCHAR(50),@ActionType INT,
  @SQL NVARCHAR(max),@XML XML,@IsDuplicateNameAllowed bit,@IsDuplicateCodeAllowed BIT,@HistoryStatus NVARCHAR(50)
  DECLARE @tempCode NVARCHAR(200),@DUPLICATECODE NVARCHAR(max),@DUPNODENO INT,@IsIgnoreSpace bit 
  declare @isparentcode bit, @CSQL nvarchar(max), @CSQL1 nvarchar(max)
  declare @cnt int,@CODENo int, @HasRecord INT ,@return_value int
  DECLARE @PrefValue NVARCHAR(500),@Dimesion INT,@RefSelectedNodeID INT,@CCStatID INT,@LinkDim_NodeID int
    Declare @level int,@maxLevel int
	set @Name=RTRIM(LTRIM(@Name))

	IF @NodeID=0  
	BEGIN
		set @HistoryStatus='Add'
		SET @ActionType=1
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,1)  
	END   
	ELSE  
	BEGIN  
		set @HistoryStatus='Update'
		SET @ActionType=3
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,3)  
	END  
  
    --User access check  
	IF @HasAccess=0  
	BEGIN  
		RAISERROR('-105',16,1)  
	END  

	--User acces check FOR Notes  
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
	BEGIN  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,8)  
		IF @HasAccess=0  
			RAISERROR('-105',16,1)  
	END
  
  --User acces check FOR Attachments  
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
	BEGIN  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,12)  
		IF @HasAccess=0  
			RAISERROR('-105',16,1)  
	END  

  IF(@CostCenterID=50052 AND @Code='')
	SET @Code=ISNULL(@Name,'')
  
  --User acces check FOR Contacts  
  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,16)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  --GETTING PREFERENCE     
  SELECT @IsDuplicateCodeAllowed=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='DuplicateCodeAllowed' AND CostCenterID=@CostCenterId  
  SELECT @IsDuplicateNameAllowed=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='DuplicateNameAllowed' AND CostCenterID=@CostCenterId  
  SELECT @IsIgnoreSpace=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='IgnoreSpaces' AND CostCenterID=@CostCenterId  
  select @isparentcode=IsParentCodeInherited from COM_CostCenterCodeDef WITH(NOLOCK) where CostCenterID=@CostCenterID
  select @PrefValue = Value from COM_CostCenterPreferences WITH(nolock) where CostCenterID=@CostCenterID and  Name = 'LinkDimension'  
  --To get costcenter table name  
  SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId  
   --GENERATE CODE  
	IF @NodeID>0
	BEGIN  
		
		--Check for Editing of Reference Records
		if(@CheckLink = 1)
		begin
			SET @HasRecord = 0
			SELECT @HasRecord = count(RefDimensionID)  from COM_DocBridge WITH(NOLOCK) WHERE RefDimensionID=  @CostCenterID  and RefDimensionNodeID=  @NodeID
				   
			if (@HasRecord IS NOT NULL AND @HasRecord <>'' AND @HasRecord > 0)
			begin
				SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,8,203)  
				IF(@HasAccess=0)
				BEGIN
					RAISERROR('-385',16,1)
				END
			end
		end 
		--CODE COMMENTED BY ADIL
     /*   if(@isparentcode=1)
		begin
			if(@CodeNumber=0)
				set @Code=@CodePrefix
			else
				set @Code=@CodePrefix+convert(nvarchar,@CodeNumber)
		end*/
	END  
	if @isparentcode is null
		set @isparentcode=0
		
 IF(@isparentcode=0)
 BEGIN				
  --DUPLICATE CODE CHECK  
    IF @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0  
    BEGIN
	  SET @tempCode=' @DUPNODENO INT OUTPUT,@Code nvarchar(max)'    
	  IF @NodeID=0  
	  BEGIN     
	   SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE CODE=@Code '    
	  END  
	  ELSE  
	  BEGIN   
	   SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE CODE=@Code AND NodeID!='+CONVERT(VARCHAR,@NodeID)   
	  END  
    EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT ,@Code 
  END 
 END
 ELSE
 BEGIN
 --DUPLICATE CODE CHECK WHEN INHERIT PARENT CHECK 
    IF @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0  
    BEGIN
	  SET @tempCode=' @DUPNODENO INT OUTPUT,@Code nvarchar(max)'    
	  IF @NodeID=0  
	  BEGIN     
	   SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE CODE=@Code AND CodePrefix ='''+@CodePrefix+''''    
	  END  
	  ELSE  
	  BEGIN   
	   SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE CODE=@Code AND CodePrefix ='''+@CodePrefix+''' AND NodeID!='+CONVERT(VARCHAR,@NodeID)   
	  END  
  EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT ,@Code  
    END 
 END  

  IF @DUPNODENO >0  
  BEGIN  
   RAISERROR('-116',16,1)  
  END  
  SET @DUPLICATECODE=''  
  SET @tempCode=''  
  SET @DUPNODENO=0  
  --DUPLICATE NAME CHECK  
  SET @tempCode=' @DUPNODENO INT OUTPUT,@Name nvarchar(max)'   
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
  BEGIN  
   IF @NodeID=0  
   BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
     SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE replace(NAME,'' '','''')=replace(@Name,'' '','''')'    
    else  
     SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE NAME=@Name '    
   END  
   ELSE  
   BEGIN   
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
     SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE replace(NAME,'' '','''')=replace(@Name,'' '','''') AND NodeID!='+CONVERT(VARCHAR,@NodeID)   
    else  
     SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE NAME=@Name AND NodeID!='+CONVERT(VARCHAR,@NodeID)   
   END  
  END   
   
  EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT,@Name  

  IF @DUPNODENO >0  
  BEGIN  
   RAISERROR('-112',16,1)  
  END  
  SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date    
 
 --IF(@CostCenterID>50000 AND @CostCenterID<=50008)
  IF(@CostCenterID>50000)
	BEGIN
		 Declare @CStatusID int 
		 set @SQL='select @CStatusID=StatusID from '+@Table+' with(nolock) where NodeID='+convert(nvarchar,@NodeID)
		 EXEC sp_executesql @SQL, N'@CStatusID int OUTPUT',@CStatusID OUTPUT	
		 if(@WID>0 and @NodeID>0)	 
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
	END
  IF @NodeID=0 --------START INSERT RECORD-----------  
  BEGIN--CREATE COST CENTER--   
    
   --GENERATE CODE  
   --IF @IsGroup=0  
   BEGIN  
    --IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1  
    --BEGIN  
    -- SET @tempCode=' @PARENTCODE NVARCHAR(300) OUTPUT'   
    -- SET @DUPLICATECODE=' SELECT @PARENTCODE=[CODE]  
    -- FROM '+@Table+' WITH(NOLOCK) WHERE NODEID='+CONVERT(VARCHAR,@SelectedNodeID)+' '  
  
    -- EXEC sp_executesql @DUPLICATECODE, @tempCode,@PARENTCODE OUTPUT    
    -- CALL AUTOCODEGEN  
    -- EXEC [spCOM_SetCode] @CostCenterId,@ParentCode,@Code OUTPUT  
    -- SELECT @Code    
    --END   
   
   IF @Code IS NULL OR @Code=''
   BEGIN
--		SET @Code=convert(nvarchar,IDENT_CURRENT('dbo.'+@Table)+1)
		declare @I INT
		set @I=IDENT_CURRENT('dbo.'+@Table)+1
		SET @Code=convert(nvarchar,@I)
		--DUPLICATE CODE CHECK  
		if @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0  
		begin
			set @DUPNODENO=0
			set @tempCode=' @DUPNODENO INT OUTPUT,@Code nvarchar(max)'    
			set @DUPLICATECODE=' select @DUPNODENO=count(*)  from '+@Table+' WHERE CODE=@Code'    
			while(1=1)
			begin
				set @Code=convert(nvarchar,@I)
				exec sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT,@Code 
				if @DUPNODENO=0
					break;
				set @I=@I+1	
			end
		end  
		
		
   END
   
   if @SelectedNodeID=0
	set @SelectedNodeID=1

   --To Set Left,Right And Depth of Record    
   SET @SQL='DECLARE @SelectedNodeID INT,@IsGroup BIT,@lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth INT,@ParentID INT, @SelectedIsGroup BIT'    
   SET @SQL=@SQL+' SELECT @IsGroup='+convert(NVARCHAR,@IsGroup)+', @SelectedNodeID='+convert(NVARCHAR,@SelectedNodeID)    
   SET @SQL=@SQL+' SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
   from '+@Table+' with(NOLOCK) where NodeID=@SelectedNodeID AND NodeID<>0'    
      
   --IF No Record Selected or Record Doesn't Exist    
   SET @SQL=@SQL+' IF(@SelectedIsGroup is null)     
   select @SelectedNodeID=NodeID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
   from '+@Table+' with(NOLOCK) where ParentID =0 AND NodeID<>0'    
  
     
   --Updating records left and right positions  
   SET @SQL=@SQL+'IF(@SelectedIsGroup = 1)--Adding Node Under the Group     
   BEGIN    
     UPDATE '+@Table+' SET rgt = rgt + 2 WHERE rgt > @Selectedlft;    
     UPDATE '+@Table+' SET lft = lft + 2 WHERE lft > @Selectedlft;    
     SET @lft =  @Selectedlft + 1    
     SET @rgt = @Selectedlft + 2    
     SET @ParentID = @SelectedNodeID    
     SET @Depth = @Depth + 1    
   END    
   ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level    
   BEGIN    
     UPDATE '+@Table+' SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;    
     UPDATE '+@Table+' SET lft = lft + 2 WHERE lft > @Selectedrgt;    
     SET @lft =  @Selectedrgt + 1    
     SET @rgt = @Selectedrgt + 2     
   END    
   ELSE  --Adding Root    
   BEGIN    
     SET @lft =  1    
     SET @rgt = 2     
     SET @Depth = 0    
     SET @ParentID =0    
     SET @IsGroup=1    
   END'   
   END   
   
   if(@CodePrefix is null or @CodePrefix = '')
    set @CodePrefix=''
    --Start Map Dimension		
	IF(@NodeID=0  AND @PrefValue is not null and @PrefValue<>'')  
	BEGIN  
			set @Dimesion=0  
			BEGIN try  
				select @Dimesion=convert(INT,@PrefValue)  
			end try  
			BEGIN catch  
				set @Dimesion=0   
			end catch  
			if(@Dimesion>0)  
			BEGIN 
				SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
				WHERE CostCenterID=@CostCenterID AND RefDimensionID=@Dimesion AND NodeID=@SelectedNodeID 
				SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,@SelectedNodeID)
				
				select @CCStatID = statusid from com_status WITH(NOLOCK) where costcenterid=@Dimesion and status = 'Active'
				EXEC @LinkDim_NodeID = [dbo].[spCOM_SetCostCenter]
				@NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
				@Code = @CODE,
				@Name = @NAME,
				@AliasName=@NAME,
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatID,
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=@CustomCostCenterFieldsQuery,@ContactsXML=NULL,@NotesXML=NULL,
				@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',
				@UserName=@UserName,@RoleID=1,@UserID=1,@CheckLink = 0

			END  
	END
	--End Map Dimension
   --if @IsOffline=0
   --begin
		-- Insert statements for procedure here  
		
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


		SET @SQL=@SQL+' INSERT INTO '+@Table+
		'  (StatusID,[Code],[Name],AliasName,  
      [Depth],[ParentID],[lft],[rgt],    
      [IsGroup],CreditDays,CreditLimit,DebitDays, DebitLimit, PurchaseAccount,SalesAccount,  
      [CompanyGUID],[GUID],[CreatedBy],[CreatedDate],[CodePrefix],[CodeNumber],GroupSeqNoLength'
       
	  IF(@CostCenterID>50000)
	  BEGIN
		SET @SQL=@SQL+' ,WorkFlowID,WorkFlowLevel'		
	  END
      
      SET @SQL=@SQL+' )    
     VALUES('+convert(NVARCHAR,@StatusID)+',N'''+@Code+''',@Name,N'''+replace(@AliasName,'''','''''')+''',  
      @Depth,@ParentID,@lft,@rgt,     
      @IsGroup,'+CONVERT(VARCHAR,@CreditDays)+','+CONVERT(VARCHAR,@CreditLimit)+','+CONVERT(VARCHAR,@DebitDays)+','+CONVERT(VARCHAR,@DebitLimit)+','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+',  
      '''+@CompanyGUID+''',newid(),'''+@UserName+''',convert(float,getdate()),'''+@CodePrefix+''','+CONVERT(VARCHAR,@CodeNumber)+', '+CONVERT(VARCHAR,@GroupSeqNoLength)+''
      
     -- IF(@CostCenterID>50000 AND @CostCenterID<=50008)
	   IF(@CostCenterID>50000)
	  BEGIN
		SET @SQL=@SQL+' , '+CONVERT(VARCHAR,@WID)+', '+ISNULL(CONVERT(VARCHAR,@level),0)+''		
	  END
	  
      SET @SQL=@SQL+')    
     SET @NodeID=SCOPE_IDENTITY()'--To get inserted record primary key  

	 PRINT @SQL
		EXEC sp_executesql @SQL, N'@NodeID INT OUTPUT,@Name nvarchar(max),@AliasName nvarchar(max)', @NodeID OUTPUT,@Name,@AliasName
		
   /*end
   else
   begin
		SET @SQL=@SQL+'
		select @NodeID=min(NodeID) from '+@Table+' with(nolock)
		if(@NodeID>-10000)
			set @NodeID=-10001
		else
			set @NodeID=@NodeID-1
			
		set identity_insert '+@Table+' ON
	 INSERT INTO '+@Table+'(NodeID,StatusID,[Code],[Name],AliasName,  
      [Depth],[ParentID],[lft],[rgt],    
      [IsGroup],CreditDays,CreditLimit,DebitDays, DebitLimit, PurchaseAccount,SalesAccount,  
      [CompanyGUID],[GUID],[CreatedBy],[CreatedDate],[CodePrefix],[CodeNumber],GroupSeqNoLength
      )    
     VALUES(@NodeID,'+convert(NVARCHAR,@StatusID)+',N'''+@Code+''',N'''+@Name+''',N'''+@AliasName+''',  
      @Depth,@ParentID,@lft,@rgt,     
      @IsGroup,'+CONVERT(VARCHAR,@CreditDays)+','+CONVERT(VARCHAR,@CreditLimit)+','+CONVERT(VARCHAR,@DebitDays)+','+CONVERT(VARCHAR,@DebitLimit)+','+CONVERT(VARCHAR,@PurchaseAccount)+','+CONVERT(VARCHAR,@SalesAccount)+',  
      '''+@CompanyGUID+''',newid(),'''+@UserName+''',convert(float,getdate()),'''+@CodePrefix+''','+CONVERT(VARCHAR,@CodeNumber)+', '+CONVERT(VARCHAR,@GroupSeqNoLength)+')    
     set identity_insert '+@Table+' OFF
     INSERT INTO ADM_OfflineOnlineIDMap VALUES('+convert(nvarchar,@CostCenterId)+',@NodeID,0)'

		EXEC sp_executesql @SQL, N'@NodeID INT OUTPUT', @NodeID OUTPUT		
   end*/
   
   --If its a offline insert
   if @NodeID<-10000
	INSERT INTO ADM_OfflineOnlineIDMap VALUES(@CostCenterId,@NodeID,0)
   
   
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
    ,@CostCenterId  
    ,@NodeID,@CompanyGUID  
    ,NEWID()  
    ,@UserName,@Dt  
    )  
       INSERT INTO COM_ContactsExtended(ContactID,[CreatedBy],[CreatedDate])
			 	VALUES(SCOPE_IDENTITY(), @UserName, convert(float,getdate()))
  -- Handling of CostCenter Costcenters Extrafields Table  
   INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
   VALUES(@CostCenterID, @NodeID, @UserName, @Dt, @CompanyGUID,newid())  
   
 --  DECLARE @SQL1 NVARCHAR(MAX)
 --  SET @SQL1='UPDATE '+@Table +' set CodePrefix=N'''+@CodePrefix+''',  CodeNumber='+CONVERT(VARCHAR,@CodeNumber)+' where Nodeid='+Convert(nvarchar,@NodeID)+''
	--exec (@SQL1)
	--Added by Pranathi
	Declare   @PStatusid int, @ProductName nvarchar(100) 
	select @ProductName =convert(int, isnull(value,0)) from com_costcenterpreferences WITH(NOLOCK)
	where costcenterid=3 and name ='ProductName'
	if(@ProductName >50000 )   
		select @PStatusid=StatusID from com_status WITH(NOLOCK) where costcenterid=3 and status='In Active'
 	 
	if(@ProductName >50000)  
	BEGIN
		if(@ProductName=@CostCenterId)
		begin
			declare @ccnumber int
			set @ccnumber=@ProductName-50000
				set @CustomCostCenterFieldsQuery=@CustomCostCenterFieldsQuery+'CCNID'+convert(nvarchar,@ccnumber)+'='''+convert(nvarchar,@NodeID)+''' ,' 
				--				print @CustomCostCenterFieldsQuery
			declare @ProductID INT
			EXEC	@ProductID = [dbo].[spINV_SetProduct]
			@ProductID = 0,
			@ProductCode = @Name,
			@ProductName = @Name,
			@AliasName = @Name,
			@ProductTypeID = 1,
			@StatusID = @PStatusID,
			@UOMID = 1,
			@BarcodeID = 0,
			@Description = N'',
			@SelectedNodeID = 0,
			@IsGroup = 0,
			@CustomFieldsQuery ='',
			@CustomCostCenterFieldsQuery = @CustomCostCenterFieldsQuery,
			@ContactsXML = N'',
			@NotesXML = N'',
			@AttachmentsXML = N'',
			@SubstitutesXML = N'',
			@VendorsXML = N'',
			@SerializationXML = N'',
			@KitXML = N'',
			@LinkedProductsXML = N'',
			@MatrixSeqno = 0,
			@AttributesXML = N'',
			@AttributesData = N'',
			@AttributesColumnsData = N'',
			@HasSubItem = 0,
			@ItemProductData = N'',
			@AssignCCCCData = N'',
			@ProductWiseUOMData = N'',
			@ProductWiseUOMData1 = N'',
			@CompanyGUID = @COMPANYGUID,
			@GUID = N'',
			@UserName = 'admin',
			@UserID = 1,
			@LangID = @LANGID,
			@IsOffline=@IsOffline
			UPDATE [INV_Product] SET ValuationID = 3 WHERE ProductID=@ProductID
		end
	END
	
	if (@DimMappingXML is not null and @DimMappingXML<>'' and @NodeID>0)
	BEGIN
		declare @Profileid INT 
		SELECT @Profileid=ISNULL(VALUE,0) FROM COM_COSTCENTERPREFERENCES WITH(NOLOCK) WHERE CostCenterID=86 AND Name='DimensionMappingProfileName'
	  
		set @DimMappingXML=replace(@DimMappingXML,'CCNID'+cONVERT(NVARCHAR,(@CostCenterID-50000))+'="0"','CCNID'+cONVERT(NVARCHAR,(@CostCenterID-50000))+'="'+convert(nvarchar,@NodeID)+'"')
	 	if(@Profileid>0)
		BEGIN
			DECLARE	@MappingValue int 
			EXEC	@MappingValue = [dbo].[spADM_SetDimensionMapFromDimension]
					@ProfileID = @Profileid,
					@CCID = @CostCenterID,
					@CCNODEID = @NodeID,
					@DataXml = @DimMappingXML,
					@CompanyGUID = @COMPANYGUID,
					@UserName = @UserName,
					@UserID = @UserID,
					@LangID = @LANGID
		END
		
	END 
    --Start Link Dimension Mapping
	IF(@PrefValue is not null and @PrefValue<>'')  
	BEGIN
		INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  
									CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)
		values(@CostCenterID, @NodeID,0,0,@Dimesion,@LinkDim_NodeID,'',newid(),@UserName, @dt,@Table) 
	END
	if(@WID>0)
	BEGIN	 
		INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
		VALUES(@CostCenterID,@NodeID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@UserName,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
	end
	--End Link Dimension Mapping
  END--------END INSERT RECORD-----------  
  ELSE--------START UPDATE RECORD-----------  
  BEGIN     
  
 -- print 1
  --Is Root Node CHECK  
  SET @tempCode=' @DUPNODENO INT OUTPUT'   
  SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WITH(NOLOCK) WHERE NodeID='+convert(NVARCHAR,@NodeID) +' and ParentID=0'     

  EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT  
    
  IF @DUPNODENO >0  
  BEGIN  
   RAISERROR('-123',16,1)  
  END  
  

   DECLARE @TempGuid NVARCHAR(50)    
  
   SET @SQL='SELECT @TempGuid=[GUID] FROM '+@Table+'  WITH(NOLOCK)     
   WHERE NodeID='+convert(NVARCHAR,@NodeID)    
   EXEC sp_executesql @SQL, N'@TempGuid NVARCHAR(100) OUTPUT', @TempGuid OUTPUT        
  
   --IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
   --IF(@TempGuid!=@Guid)    
   --BEGIN         
   -- RAISERROR('-101',16,1)    
   --END    
     IF ( @CodePrefix IS NULL)
     SET @CodePrefix = ''
   SET @ExtendedColsXML='UPDATE '+@Table+'       
   SET  PurchaseAccount='+CONVERT(NVARCHAR,@PurchaseAccount)+',SalesAccount='+CONVERT(NVARCHAR,@SalesAccount)+',  
   code=N'''+@Code+''',Name=@Name,CreditDays='+CONVERT(VARCHAR,@CreditDays)+',CreditLimit='+CONVERT(NVARCHAR,@CreditLimit)+',DebitDays='+CONVERT(NVARCHAR,@DebitDays)+',DebitLimit='+CONVERT(NVARCHAR,@DebitLimit)+',   
   AliasName=N'''+replace(@AliasName,'''','''''')+''',StatusId='+convert(NVARCHAR,@StatusID)+',GUID=newid(),ModifiedBy='''+@UserName+''',  CodePrefix='''+@CodePrefix+''', 
   CodeNumber='+CONVERT(NVARCHAR,@CodeNumber)+',
   GroupSeqNoLength='+CONVERT(NVARCHAR,@GroupSeqNoLength)+',
   ModifiedDate=@ModDate '
   
   IF(@CostCenterID>50000)    
   BEGIN
		SET @ExtendedColsXML=@ExtendedColsXML+' ,WorkFlowLevel='+ ISNULL(CONVERT(VARCHAR,@level),0)+''		
   END
   
   SET @ExtendedColsXML=@ExtendedColsXML+' WHERE NodeID='+convert(NVARCHAR,@NodeID)+''  
   print @ExtendedColsXML
   EXEC sp_executesql @ExtendedColsXML,N'@ModDate float,@Name nvarchar(max)',@Dt,@Name
	
	
    
   	select @ProductName =convert(int, isnull(value,0)) from com_costcenterpreferences where costcenterid=3 and name ='ProductName'
	if(@ProductName >50000)  
	BEGIN
		if(@ProductName=@CostCenterId)
		begin
			set @ccnumber=@ProductName-50000
			declare @ProductSQL nvarchar(max)
			set @ProductSQL='update inv_product set productname='''+@Name +'''
			where productid in (select NodeID from COM_CCCCData WITH(NOLOCK) where CostCenterID=3 
			and ccnid'+CONVERT(nvarchar,@ccnumber)+'='+Convert(nvarchar,@NodeID)+')' 
			EXEC sp_executesql @ProductSQL

			declare @tempCC nvarchar(max)
			set @tempCC=@CustomCostCenterFieldsQuery+'CCNID'+convert(nvarchar,@ccnumber)+'='''+convert(nvarchar,@NodeID)+''' ,' 

			set @ProductSQL=''
			set @ProductSQL='update COM_CCCCData  
			SET '+@tempCC+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +'
			WHERE CostCenterID=3 and CCNID'+convert(nvarchar,@ccnumber)+'='+convert(NVARCHAR,@NodeID)  +''  
			EXEC sp_executesql @ProductSQL  

			set @ProductSQL=''
			set @ProductSQL='Update inv_product set Categoryid= (SELECT CCNID6 
			from com_ccccdata WITH(NOLOCK) where 
			costcenterid=3 and Nodeid in  (select TOP 1 NodeID from COM_CCCCData WITH(NOLOCK)
			where CostCenterID=3 and ccnid'+CONVERT(nvarchar,@ccnumber)+'='+Convert(nvarchar,@NodeID)+')) WHERE 
			PRODUCTID IN  (select NodeID from COM_CCCCData WITH(NOLOCK)
			where CostCenterID=3 and ccnid'+CONVERT(nvarchar,@ccnumber)+'='+Convert(nvarchar,@NodeID)+')'	
			EXEC sp_executesql @ProductSQL
			     
			CREATE TABLE #TEMP(PID INT)
			set @ProductSQL=''
			set @ProductSQL='INSERT INTO #TEMP 
			SELECT NODEID FROM COM_CCCCData WITH(NOLOCK) WHERE COSTCENTERID=3 AND CCNID'+convert(nvarchar,@ccnumber)+'='+convert(NVARCHAR,@NodeID)
			EXEC sp_executesql @ProductSQL
			
			if (@AttachmentsXML is not null and @AttachmentsXML<>'')
			BEGIN
				 SET @XML=@AttachmentsXML   
				 IF EXISTS (SELECT X.value('@IsProductImage','bit') FROM @XML.nodes('/AttachmentsXML/Row') as Data(X) WHERE X.value('@IsProductImage','bit')=1)
				 BEGIN   
						set @ProductSQL=''
						set @ProductSQL='DELETE FROM COM_FILES WHERE COSTCENTERID=3 AND 
						FEATUREPK IN (SELECT NODEID FROM COM_CCCCData WITH(NOLOCK) WHERE COSTCENTERID=3 AND CCNID'+convert(nvarchar,@ccnumber)+'='+convert(NVARCHAR,@NodeID)+') and IsProductImage=1'
						EXEC sp_executesql @ProductSQL
						
						INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,  
						   FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
						   GUID,CreatedBy,CreatedDate,IsDefaultImage)  
			 			   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
							   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),
							   X.value('@IsProductImage','bit'),3,3,C.PID,  
						   X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  ,X.value('@IsDefaultImage','bit')
						   FROM @XML.nodes('/AttachmentsXML/Row') as Data(X), #TEMP C
					   WHERE (X.value('@IsProductImage','bit')=1 and X.value('@Action','NVARCHAR(10)')<>'DELETE' ) 
				 END 
			END
			
			DROP TABLE #TEMP 
			
		end
	end

    DELETE  FROM COM_CCCCData WHERE CostCenterID=@CostCenterID and NODEID=@NodeID  
      
    INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
    VALUES(@CostCenterID, @NodeID, @UserName, @Dt, @CompanyGUID,newid())  
  END --------END UPDATE RECORD-----------  
    
   --Dimension History Data
 -- IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
	--EXEC spCOM_SetHistory @CostCenterID,@NodeID,@HistoryXML,@UserName 
  
   -- , BEFORE MODIFIEDBY  REQUIRES A NULL CHECK OF @PrimaryContactQuery 
  IF(@PrimaryContactQuery IS NOT NULL AND @PrimaryContactQuery<>'')
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE
		EXEC spCOM_SetFeatureWiseContacts @CostCenterID,@NodeID,1,@PrimaryContactQuery,@UserName,@Dt,@LangID
  END
   --Update Extended  
  IF(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <> '')  
  BEGIN  
  -- SET @ExtendedColsXML=dbo.fnCOM_GetExtraFieldsQuery(@ExtendedColsXML,3)  
  
   SET @ExtendedColsXML='update '+@Table+'  
   SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName  
     +''',[ModifiedDate] =@ModDate WHERE NODEID='+convert(NVARCHAR,@NodeID)      
   EXEC sp_executesql @ExtendedColsXML,N'@ModDate float',@Dt
  END  
  
  --CHECK WORKFLOW
  --EXEC spCOM_CheckCostCentetWF @CostCenterID,@NodeID,@WID,@RoleID,@UserID,@UserName,@StatusID output
  
  -- Update Custom Cost Center Fields  
  IF(@CustomCostCenterFieldsQuery IS NOT NULL AND @CustomCostCenterFieldsQuery <> '')  
  BEGIN  
  -- SET @ExtendedColsXML=dbo.fnCOM_GetExtraFieldsQuery(@ExtendedColsXML,3)  
  
  
  set @UpdateSql='update COM_CCCCData  
  SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =@ModDate WHERE CostCenterID='+convert(nvarchar,@CostCenterID) +' and NODEID='+convert(NVARCHAR,@NodeID)  
   
   exec sp_executesql @UpdateSql,N'@ModDate float',@Dt
 END

  	--Duplicate Check
	exec [spCOM_CheckUniqueCostCenter] @CostCenterID=@CostCenterID,@NodeID=@NodeID,@LangID=@LangID
  
  --Series Check
  declare @retSeries INT
  EXEC @retSeries=spCOM_ValidateCodeSeries @CostCenterID,@NodeID,@LangId
  if @retSeries>0
  begin
	ROLLBACK TRANSACTION
	SET NOCOUNT OFF  
	RETURN -999
  end

  if exists (select Value from COM_CostCenterPreferences with(nolock) where Name='CreateUserOnDim' and CostCenterID=@CostCenterID and Value='True')
  begin
	set @SQL='select @tempCode=UserNameAlpha from '+@Table+' with(nolock) where NodeID='+convert(nvarchar,@NodeID)
	EXEC sp_executesql @SQL, N'@tempCode nvarchar(max) OUTPUT',@tempCode OUTPUT
	if (@tempCode is not null and @tempCode<>'')
	BEGIN		--RAISERROR('EMPTY USER NAME',16,1)  
		declare @FeatureID int,@TableName nvarchar(50)
		declare @TblDims as Table(ID int identity(1,1), FeatureID int,Name nvarchar(100),TblName nvarchar(100))

		insert into @TblDims
		select FeatureID,Name,TableName from ADM_Features with(nolock) where FeatureID IN (select CostCenterID from COM_CostCenterPreferences with(nolock) where Name='CreateUserOnDim' and Value='True') order by FeatureID

		select @i=1,@Cnt=count(*) from @TblDims
		while(@i<=@Cnt)
		begin
			select @FeatureID=FeatureID,@TableName=TblName from @TblDims where ID=@i
			set @i=@i+1
			set @DUPNODENO=0
			IF @CostCenterID=@FeatureID
				set @SQL='select @DUPNODENO=count(*) from '+@TableName+' with(nolock) where NodeID!='+convert(nvarchar,@NodeID)+' and UserNameAlpha='''+@tempCode+''''
			else
				set @SQL='select @DUPNODENO=count(*) from '+@TableName+' with(nolock) where UserNameAlpha='''+@tempCode+''''
			EXEC sp_executesql @SQL, N'@DUPNODENO INT OUTPUT',@DUPNODENO OUTPUT
			IF @DUPNODENO=1
				RAISERROR('DUPLICATE USER NAME',16,1)  
		end
	END	
  end
  
  --Inserts Multiple Contacts   
  IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
  BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE 
		 declare @rValue int
		EXEC @rValue = spCOM_SetFeatureWiseContacts @CostCenterID,@NodeID,2,@ContactsXML,@UserName,@Dt,@LangID   
		 IF @rValue=-1000  
		  BEGIN  
			RAISERROR('-500',16,1)  
		  END   
  END  
  
  
   -- To Insert Multiple Address  
  EXEC spCOM_SetAddress @CostCenterID,@NodeID,@AddressXML,@UserName  
  

	IF (@StatusXML IS NOT NULL AND @StatusXML <> '')
		exec spCOM_SetStatusMap @CostCenterID,@NodeID,@StatusXML,@UserName,@Dt
	
	--Inserts Multiple Notes  
	IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
	BEGIN  
		SET @XML=@NotesXML  

		--If Action is NEW then insert new Notes  
		INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
		GUID,CreatedBy,CreatedDate,Progress)  
		SELECT @CostCenterID,@CostCenterID,@NodeID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
		'),  
		newid(),@UserName,@Dt,X.value('@Progress','int')
		FROM @XML.nodes('/NotesXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
  
		--If Action is MODIFY then update Notes  
		UPDATE COM_Notes  
		SET Note=Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
		'),  
		GUID=newid(),  
		Progress=X.value('@Progress','int'),
		ModifiedBy=@UserName,  
		ModifiedDate=@Dt  
		FROM COM_Notes C WITH(NOLOCK)  
		INNER JOIN @XML.nodes('/NotesXML/Row') as Data(X)    
		ON convert(INT,X.value('@NoteID','INT'))=C.NoteID  
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
  
		--If Action is DELETE then delete Notes  
		DELETE FROM COM_Notes  
		WHERE NoteID IN(SELECT X.value('@NoteID','INT')  
		FROM @XML.nodes('/NotesXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
  
	END  
  
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')
	exec [spCOM_SetAttachments] @NodeID,@CostCenterID,@AttachmentsXML,@UserName,@Dt

  IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='PRD_JobOuputProducts')
  BEGIN
	  IF(@JobsProductXML IS NOT NULL AND @JobsProductXML <> '')  
	  BEGIN  
		declare @JXML xml
		SET @JXML=@JobsProductXML  
		
		declare  @tab table (id int identity(1,1),StageID INT,BOMID INT,DimID INT,ProductID INT)
		insert into @tab
		SELECT s.StageID,X.value('@BOMID','INT'),X.value('@DimID','INT'),X.value('@ProductID','INT')
		FROM @JXML.nodes('/XML/Row') as Data(X) 
		left join PRD_BOMStages s with(NOLOCK) on X.value('@StageID','INT')=s.StageNodeID and s.BOMID=X.value('@BOMID','INT')
		
		if exists (select StageID,BOMID,DimID,ProductID from @tab
				group by StageID,BOMID,DimID,ProductID
				having count(*)>1)
		begin
			RAISERROR('-129',16,1)
		end
		else
		begin	 
			delete from PRD_JobOuputProducts where CostCenterID=@CostCenterID and NodeID=@NodeID
		   
			INSERT INTO [PRD_JobOuputProducts]
			([CostCenterID],[NodeID],[StageID],[BomID],[ProductID],[Qty],[UOMID],StatusID,DimID,Remarks
			,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],IsBom) 
			SELECT @CostCenterID,@NodeID,s.StageID,X.value('@BOMID','INT'),
			X.value('@ProductID','INT'),  X.value('@Qty','float'),X.value('@UOMID','INT'),
			X.value('@StatusID','INT'),isnull(X.value('@DimID','INT'),1),X.value('@Remarks','nvarchar(max)'),
			@CompanyGUID, newid(),@UserName,@Dt,X.value('@IsBom','bit')
			FROM @JXML.nodes('/XML/Row') as Data(X) 
			left join PRD_BOMStages s with(NOLOCK) on X.value('@StageID','INT')=s.StageNodeID and s.BOMID=X.value('@BOMID','INT')
		end
	  END  
	  else
	  begin
		if exists (select CostCenterID from PRD_JobOuputProducts WITH(NOLOCK) 
					where CostCenterID=@CostCenterID and NodeID=@NodeID)
			delete from PRD_JobOuputProducts where CostCenterID=@CostCenterID
			and NodeID=@NodeID
			
	  end
 END
  
  if EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='PRD_CCCalendarMap') AND (@CalendarXML IS NOT NULL AND @CalendarXML<>'')
  BEGIN
		DECLARE @CXML XML,@CrBy NVARCHAR(50),@CrDt FLOAT
		SET @CXML=@CalendarXML

		IF EXISTS(Select ID From PRD_CCCalendarMap WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND CCNodeID=@NodeID)
		BEGIN
			SELECT @CrBy=CreatedBy,@CrDt=CreatedDate From PRD_CCCalendarMap WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND CCNodeID=@NodeID
			DELETE a FROM PRD_CCCalendarMap a WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND CCNodeID=@NodeID
		END
		ELSE
		BEGIN
			SET @CrBy=@UserName SET @CrDt=@Dt
		END

		INSERT INTO PRD_CCCalendarMap(CostCenterID, CCNodeID, SNo, FromDate, ToDate, CalendarProfileID, GUID, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
		SELECT @CostCenterID,@NodeID,X.value('@SNo','INT'),CONVERT(FLOAT,X.value('@FromDate','DATETIME')),CONVERT(FLOAT,X.value('@ToDate','DATETIME')),X.value('@CalendarID','INT'),newid(),@CrBy,@CrDt,@UserName,@Dt
		FROM @CXML.nodes('/Rows/Row') as Data(X) 
  END
  
  
  -- ADDED CODE ON DEC 28 BY MUSTAFEEZ   
  if(@CostCenterRoleXML IS NOT NULL AND @CostCenterRoleXML<>'')
  BEGIN
   IF @CostCenterID = 50002
   BEGIN
		IF(@CostCenterRoleXML <> '' AND @CostCenterRoleXML IS NOT NULL)  
		BEGIN  
			EXEC [spCOM_SetCCCCMap] 50002,@NodeID,@CostCenterRoleXML,@UserName,@LangID
		END 
   END 
   ELSE IF  @CostCenterID<>50002   -- ADDED CODE ON JUN 28 BY Hafeez 
   BEGIN  
		EXEC [spCOM_SetCCCCMap] @CostCenterID,@NodeID,@CostCenterRoleXML,@UserName,@LangID
   END
  END 
   
	--CREATE/EDIT LINK DIMENSION
	declare @LinkDimCC nvarchar(max),@iLinkDimCC int,@DimGroup bit,@projDim int,@projpldim int
	set @projpldim=0
	set @projDim=0
	SELECT @projpldim=isnull([Value],0) FROM Adm_globalpreferences with(nolock) 
	WHERE [Name]='ProjPlanDim' and ISNUMERIC(value)=1
	
	SELECT @projDim=isnull([Value],0) FROM Adm_globalpreferences with(nolock) 
	WHERE [Name]='ProjectManagementDimension' and ISNUMERIC(value)=1
	
	set @DimGroup=0
	SELECT @LinkDimCC=[Value] FROM com_costcenterpreferences with(nolock) WHERE CostCenterID=@CostCenterID and [Name]='LinkDimension'
	
	if(@projpldim>0 and @projDim>0 and @CostCenterID=@projpldim)
	BEGIN
		set @iLinkDimCC=@projDim
		set @DimGroup=1
	END	
	ELSE if(ISNUMERIC(@LinkDimCC)=1)
		set @iLinkDimCC=CONVERT(int,@LinkDimCC)
	else
		set @iLinkDimCC=0
	
	
	if (@IsGroup=0 and @iLinkDimCC>50000 and @iLinkDimCC!=@CostCenterID)
	begin
		declare @LinkDimNodeID INT,@CCStatusID INT
		declare @LinkDimCode nvarchar(max),@LinkDimAutoGen nvarchar(10),@CaseNumber nvarchar(500),@CaseID INT
		
		select @LinkDimNodeID=RefDimensionNodeID from com_docbridge with(nolock) 
		WHERE CostCenterID=@CostCenterID AND NodeID=@NodeID AND RefDimensionID=@iLinkDimCC
		 
		if(@LinkDimNodeID is null or (@LinkDimNodeID<=0 and @LinkDimNodeID>-10000) or @LinkDimNodeID=1)
		BEGIN
		
			set @CCStatusID=(select top 1 statusid from com_status with(nolock) where costcenterid=@iLinkDimCC and status = 'Active')
				
			SELECT @LinkDimAutoGen=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='CodeAutoGen' AND CostCenterID=@iLinkDimCC     
			if(@LinkDimAutoGen='True')
			BEGIN
					declare @Codetemp table (prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
					
					insert into @Codetemp
					EXEC [spCOM_GetCodeData] @iLinkDimCC,1,'' ,null,0,0 
					
					select @LinkDimCode=code,@CaseNumber= prefix, @CaseID=number from @Codetemp
			END
			ELSE
			BEGIN
				set @LinkDimCode=@Code
				set @CaseNumber=''
				set @CaseID=0
			END
			DECLARE @Value NVARCHAR(50)
			SELECT @Value=Value FROM COM_CostCenterPreferences WHERE Name='CopyDimensionData' AND CostCenterID=@CostCenterID
			DECLARE @Contact NVARCHAR(max),@Addr NVARCHAR(max),@Note NVARCHAR(max),@Attach NVARCHAR(max)
			SELECT @Contact = CASE WHEN @Value LIKE '%1%' THEN @ContactsXML ELSE '' END
			SELECT @Addr = CASE WHEN @Value LIKE '%2%' THEN @AddressXML ELSE '' END
			SELECT @Note = CASE WHEN @Value LIKE '%3%' THEN @NotesXML ELSE '' END
			SELECT @Attach = CASE WHEN @Value LIKE '%4%' THEN @AttachmentsXML ELSE '' END
			
			if(@CCStatusID is null)
				set @CCStatusID=1
			
			EXEC @return_value = [dbo].[spCOM_SetCostCenter]
			@NodeID = 0,@SelectedNodeID = 1,@IsGroup = @DimGroup,
			@Code = @LinkDimCode,
			@Name = @Name,
			@AliasName=@AliasName,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML=@Addr,@AttachmentsXML=@Attach,
			@CustomCostCenterFieldsQuery=NULL,@ContactsXML=@Contact,@NotesXML=@Note,
			@CostCenterID = @iLinkDimCC,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1,
			@CodePrefix=@CaseNumber,@CodeNumber=@CaseID,
			@CheckLink = 0,@IsOffline=@IsOffline
			
			--set @return_value=0	
			declare @Gid nvarchar(50), @NodeidXML nvarchar(max)					
			select @Table=Tablename from adm_features with(nolock) where featureid=@iLinkDimCC
			set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' WITH(NOLOCK) where NodeID='+convert(nvarchar,@LinkDimNodeID)+')'

			exec sp_executesql @NodeidXML,N'@Gid nvarchar(50) output' , @Gid OUTPUT 
			
			-- Link Dimension Mapping
			INSERT INTO COM_DocBridge(CostCenterID,NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby,CreatedDate,Abbreviation)
			values(@CostCenterID,@NodeID,0,0,@iLinkDimCC,@return_value,'',newid(),@UserName, @dt,'CostCenter')
						
		END
		ELSE IF(@LinkDimNodeID > 0)
		BEGIN
			--DELETE FROM COM_Address WHERE FeatureID=@iLinkDimCC AND FeaturePK=@LinkDimNodeID
			SELECT @Value=Value FROM COM_CostCenterPreferences WHERE Name='CopyDimensionData' AND CostCenterID=@CostCenterID
			SELECT @Addr = CASE WHEN @Value LIKE '%2%' THEN @AddressXML ELSE '' END
			--SET @Addr=REPLACE(@Addr,'MODIFY','NEW')
			--SELECT @LinkDimNodeID,@iLinkDimCC,@Addr
			EXEC @return_value = [dbo].[spCOM_SetCostCenter]
			@NodeID = @LinkDimNodeID,@SelectedNodeID = 1,@IsGroup = @DimGroup,
			@Code = @LinkDimCode,
			@Name = @Name,
			@AliasName=@AliasName,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML=@Addr,@AttachmentsXML=@Attach,
			@CustomCostCenterFieldsQuery=NULL,@ContactsXML=@Contact,@NotesXML=@Note,
			@CostCenterID = @iLinkDimCC,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1,
			@CodePrefix=@CaseNumber,@CodeNumber=@CaseID,
			@CheckLink = 0,@IsOffline=@IsOffline
		END
		ELSE 
			SET @return_value=@LinkDimNodeID
		--UPDATE LINK DATA
		if(@return_value>0 or @return_value<-10000)
		begin
		
			DECLARE @CCMapSql nvarchar(max)
			set @CCMapSql='update COM_CCCCDATA  
			SET CCNID'+convert(nvarchar,(@iLinkDimCC-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  
			WHERE CostCenterID='+convert(nvarchar,@CostCenterID) +' and NODEID='+convert(NVARCHAR,@NodeID)  
			EXEC (@CCMapSql)
			
			if (@iLinkDimCC=@projDim and @projpldim=@CostCenterID)
			BEGIN
				set @CCMapSql='update COM_CCCCDATA  
				SET CCNID'+convert(nvarchar,(@CostCenterID-50000))+'='+CONVERT(NVARCHAR,@NodeID)+'  
				WHERE CostCenterID='+convert(nvarchar,@iLinkDimCC) +' and NODEID='+convert(NVARCHAR,@return_value)  
				EXEC (@CCMapSql)
			END
			
			Exec [spDOC_SetLinkDimension]
				@InvDocDetailsID=@NodeID, 
				@Costcenterid=@CostCenterID,         
				@DimCCID=@iLinkDimCC,
				@DimNodeID=@return_value,
				@UserID=@UserID,    
				@LangID=@LangID  
		end	
			
	end
	
    --Insert Notifications
	EXEC spCOM_SetNotifEvent @ActionType,@CostCenterID,@NodeID,@CompanyGUID,@UserName,@UserID,-1
	
	--Insert Grade in Assigned leaves
	IF(@CostCenterID=50053)
	BEGIN
	    SET @SQL='EXEC spPAY_InsertPayrollCostCenter '+CONVERT(NVARCHAR,@CostCenterID)+','+CONVERT(NVARCHAR,@NodeID)+','+
	    CONVERT(NVARCHAR,@UserID)+','+CONVERT(NVARCHAR,@LangID)
	    EXEC(@SQL)
    END
	
	IF(@CostCenterID=50073)
	BEGIN
		
		DECLARE @SQL2 NVARCHAR(MAX)
		SET @SQL2=' DECLARE @ST NVARCHAR(50),@ET NVARCHAR(50)
		SELECT @ST=ccAlpha2,@ET=ccAlpha3 FROM COM_CC50073 WHERE NodeID='+ CONVERT(NVARCHAR,@NodeID) +'
		SET @ST=''01-Jan-1900''+SUBSTRING(@ST,CHARINDEX('' '',convert(nvarchar,@ST),0),LEN(@ST))
		SET @ET=''01-Jan-1900''+SUBSTRING(@ET,CHARINDEX('' '',convert(nvarchar,@ET),0),LEN(@ET))
		IF(CONVERT(DATETIME,@ST)>CONVERT(DATETIME,@ET))
			SET @ET=''02-Jan-1900''+SUBSTRING(@ET,CHARINDEX('' '',convert(nvarchar,@ET),0),LEN(@ET))
		Update COM_CC50073 SET ccAlpha2=@ST,ccAlpha3=@ET WHERE NodeID='+ CONVERT(NVARCHAR,@NodeID)
		EXEC(@SQL2)

	END


	if (@DocXML is not null and @DocXML<>'' and @NodeID>0)
	BEGIN

		IF(@CostCenterID=50073)
		BEGIN
			
			SET @DocXML=REPLACE(@DocXML,'DIM73NodeID',convert(nvarchar,@NodeID))

			DECLARE @TEMPxml NVARCHAR(MAX),@XML1 XML,@varxml xml,@AUTOCCID INT,
				@ddxml nvarchar(max),@Prefix nvarchar(200),@DocDate DATETIME,@ddID INT
		
			SET @DocDate=GETDATE()
			set @TEMPxml=''
			SET @XML1=@DocXML

			-- INSERT GENERAL TIMINGS 
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('GeneralTimingsXML'))
		from @XML1.nodes('/XML') as Data(X)
			if(@TEMPxml<>'')
		begin
			set @varxml=@TEMPxml
			set @AUTOCCID=40052
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/GeneralTimingsXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@NodeID,0,0
			set @ddID=0
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/GeneralTimingsXML') as Data(X)
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @NodeID,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = N'',      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = '',       
			  @IsImport = 0,      
			  @LocationID = 1,      
			  @DivisionID = 1 ,      
			  @WID = 0,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 0,    
			  @RefNodeid  = 0,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    

		END	

			--INSERT HOURS DEFINITION CHART 
			SELECT @TEMPxml=CONVERT(NVARCHAR(MAX), X.query('HoursDefChartXML'))
			from @XML1.nodes('/XML') as Data(X)
			if(@TEMPxml<>'')
			begin
			set @varxml=@TEMPxml
			set @AUTOCCID=40066
			SELECT @ddxml=CONVERT(NVARCHAR(MAX), X.query('DOCXML'))
			from @varxml.nodes('/HoursDefChartXML') as Data(X)
			
			set @ddxml=Replace(@ddxml,'<RowHead/>','')
			set @ddxml=Replace(@ddxml,'</DOCXML>','')
			set @ddxml=Replace(@ddxml,'<DOCXML>','')
			set @Prefix=''
			EXEC [sp_GetDocPrefix] @ddxml,@DocDate,@AUTOCCID,@Prefix output,@NodeID,0,0
			set @ddID=0
			
			SELECT @ddID=X.value('@DocID','INT')
			from @varxml.nodes('/HoursDefChartXML') as Data(X)
			
			EXEC @return_value = [dbo].[spDOC_SetTempInvDoc]      
			  @CostCenterID = @AUTOCCID,      
			  @DocID = @ddID,      
			  @DocPrefix = @Prefix,      
			  @DocNumber = N'',      
			  @DocDate = @DocDate,      
			  @DueDate = NULL,      
			  @BillNo = @NodeID,      
			  @InvDocXML =@ddxml,      
			  @BillWiseXML = N'',      
			  @NotesXML = N'',      
			  @AttachmentsXML = N'',    
			  @ActivityXML = '',       
			  @IsImport = 0,      
			  @LocationID = 1,      
			  @DivisionID = 1 ,      
			  @WID = 0,      
			  @RoleID = @RoleID,      
			  @DocAddress = N'',      
			  @RefCCID = 0,    
			  @RefNodeid  = 0,    
			  @CompanyGUID = @CompanyGUID,      
			  @UserName = @UserName,      
			  @UserID = @UserID,      
			  @LangID = @LangID    

		END	

		END
	END
	
	  --validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=@CostCenterID and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode @CostCenterID,@NodeID,@UserID,@LangID
	end

	COMMIT TRANSACTION
	--ROLLBACK TRANSACTION
	
		
	--Audit Data
	set @ExtendedColsXML=''
	if exists(SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterId and Name='AuditTrial' and Value='True')
	begin
		exec @return_value=spADM_AuditData 1,@CostCenterID,@NodeID,@HistoryStatus,'',1,1
		if @return_value!=1
			set @ExtendedColsXML=' With Audit Trial Error'
	end

		--INSERT History COM_CCCCDataHistory
		if exists(SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterId and Name='AuditTrial' and Value='True')
		BEGIN
			declare @CommonCols nvarchar(max),@HistoryCols nvarchar(max)='',@HistoryColsInsert nvarchar(max)='',@CC nvarchar(max),@HistoryID BIGINT
			
			SELECT @HistoryID=ISNULL(MAX(NodeHistoryID)+1,1) FROM COM_CCCCDataHistory WITH(NOLOCK)

			SELECT @CommonCols=STUFF((
			select ','+CH.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			JOIN (select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_CCCCDataHistory') AS CH ON CH.name=a.name
			where b.name='COM_CCCCData' FOR XML PATH('')),1,1,'')
			, @HistoryCols=STUFF((
			select ','+a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			LEFT JOIN (select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_CCCCData') AS CH ON CH.name=a.name
			where b.name='COM_CCCCDataHistory' AND CH.name IS NULL AND a.name LIKE 'CCNID%' FOR XML PATH('')),1,1,'')
			, @HistoryColsInsert=STUFF((
			select ','+'1' from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			LEFT JOIN (select a.name from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_CCCCData') AS CH ON CH.name=a.name
			where b.name='COM_CCCCDataHistory' AND CH.name IS NULL AND a.name LIKE 'CCNID%' GROUP BY a.name FOR XML PATH('')),1,1,'')
			
			IF(@HistoryCols IS NULL)
			BEGIN
				set @CC=' INSERT INTO [COM_CCCCDataHistory](NodeHistoryID,'+@CommonCols+')
				select  '+convert(nvarchar,@HistoryID)+','+@CommonCols
						
				set @CC=@CC+' FROM [COM_CCCCData] WITH(NOLOCK)
				WHERE  NodeID='+convert(nvarchar,@NodeID) + ' AND CostCenterID='+convert(nvarchar,@CostCenterID)
			END
			ELSE
			BEGIN
				set @CC=' INSERT INTO [COM_CCCCDataHistory](NodeHistoryID,'+@CommonCols+','+ISNULL(@HistoryCols,'')+')
				select  '+convert(nvarchar,@HistoryID)+','+@CommonCols+','+ISNULL(@HistoryColsInsert,'')
						
				set @CC=@CC+' FROM [COM_CCCCData] WITH(NOLOCK)
				WHERE  NodeID='+convert(nvarchar,@NodeID) + ' AND CostCenterID='+convert(nvarchar,@CostCenterID)
			END
			--PRINT @CC
			exec sp_executesql @CC
		END

	SET NOCOUNT OFF;

	if @ActionType=1
		SELECT   ErrorMessage + ' ''' + isnull(@Code,'')+''''+@ExtendedColsXML as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
		WHERE ErrorNumber=105 AND LanguageID=@LangID   
	else
		SELECT ErrorMessage+@ExtendedColsXML as ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
		WHERE ErrorNumber=100 AND LanguageID=@LangID  
  
	RETURN @NodeID
END TRY  
  
BEGIN CATCH   
if(@return_value=-999)
	return -999 
	--Return exception info [Message,Number,ProcedureName,LineNumber]    
	IF ERROR_NUMBER()=50000  
	BEGIN  
		IF ISNUMERIC(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
