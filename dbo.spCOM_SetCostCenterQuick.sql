USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenterQuick]
	@NodeID [bigint],
	@Code [nvarchar](500) = NULL,
	@Name [nvarchar](500),
	@StatusID [int],
	@CostCenterID [int],
	@StaticFieldsQuery [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@CCMAPXML [nvarchar](max),
	@HistoryXML [nvarchar](max) = null,
	@StatusXML [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@WID [int] = 0,
	@RoleID [int] = 0,
	@UserID [bigint],
	@LangID [int] = 1,
	@CodePrefix [nvarchar](200) = null,
	@CodeNumber [bigint] = 0,
	@CheckLink [bit] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
	SET NOCOUNT ON;  
	--Declaration Section  
	DECLARE @HasAccess BIT,@Dt FLOAT,@IsDuplicateNameAllowed bit,@IsCodeAutoGen bit   ,@IsDuplicateCodeAllowed BIT
	DECLARE @tempCode NVARCHAR(200),@DUPLICATECODE NVARCHAR(300),@DUPNODENO INT,@IsIgnoreSpace bit
	DECLARE @SQL NVARCHAR(MAX),@Table NVARCHAR(50) 
	declare @isparentcode bit, @CSQL nvarchar(max), @CSQL1 nvarchar(max)
	declare @cnt int,@CODENo int, @HasRecord bigint
	--User access check  
	set @Name=RTRIM(LTRIM(@Name))
	IF @NodeID=0  
	BEGIN  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,1)  
	END  
	ELSE  
	BEGIN  
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,3)  
	END  

	IF @HasAccess=0  
	BEGIN  
	RAISERROR('-105',16,1)  
	END  
	
	IF(@CostCenterID=50052 AND @Code='')
		SET @Code=ISNULL(@Name,'')
		
--Check for editing of Reference Records
  if(@CheckLink = 1)
		begin
			SET @HasRecord = 0
			SELECT @HasRecord = count(RefDimensionID)  from    COM_DocBridge  WHERE RefDimensionID=  @CostCenterID  and RefDimensionNodeID=  @NodeID
				   
			if (@HasRecord IS NOT NULL AND @HasRecord <>'' AND @HasRecord > 0)
			begin
				SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,8,203)  
				IF(@HasAccess=0)
				BEGIN
					RAISERROR('-385',16,1)
				END
			end
		end 
		
		
	--GETTING PREFERENCE  
	SELECT @IsDuplicateNameAllowed=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='DuplicateNameAllowed' AND CostCenterID=@CostCenterId  
	SELECT @IsCodeAutoGen=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='CodeAutoGen' AND CostCenterID=@CostCenterId  
	SELECT @IsIgnoreSpace=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='IgnoreSpaces' AND CostCenterID=@CostCenterId  
	select @isparentcode=IsParentCodeInherited  from COM_CostCenterCodeDef where CostCenterID=@CostCenterID
    SELECT @IsDuplicateCodeAllowed=convert(bit,Value) FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE Name='DuplicateCodeAllowed' AND CostCenterID=@CostCenterId  

	--To get costcenter table name  
	SELECT Top 1 @Table=SysTableName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterId  
	
	--DUPLICATE CODE CHECK  
	--CODE COMMENTED BY ADIL
	/*if(@isparentcode=1)
	begin
		if(@CodeNumber=0)
		begin
			set @Code=@CodePrefix
		end
		else
		begin  
			set @Code=@CodePrefix+convert(nvarchar,@CodeNumber)
		end	
	end*/

	IF(@isparentcode=0)
 BEGIN				
  --DUPLICATE CODE CHECK  
    IF @IsDuplicateCodeAllowed IS NOT NULL AND @IsDuplicateCodeAllowed=0  
    BEGIN
	  SET @tempCode=' @DUPNODENO INT OUTPUT,@Code nvarchar(500)'    
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
	  SET @tempCode=' @DUPNODENO INT OUTPUT,@Code nvarchar(500)'    
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
	SET @tempCode=' @DUPNODENO INT OUTPUT'   
	IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
	BEGIN  
	IF @NodeID=0  
	BEGIN  
	IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
		SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE replace(NAME,'' '','''')=replace('''+@Name+''' ,'' '','''')'    
	else  
		SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE NAME='''+@Name+''' '    
	END  
	ELSE  
	BEGIN   
	IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
		SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE replace(NAME,'' '','''')=replace('''+@Name+''' ,'' '','''') AND NodeID!='+CONVERT(VARCHAR,@NodeID)   
	else  
		SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE NAME='''+@Name+''' AND NodeID!='+CONVERT(VARCHAR,@NodeID)   
	END  
	END   
  
	EXEC sp_executesql @DUPLICATECODE, @tempCode,@DUPNODENO OUTPUT  
    
	IF @DUPNODENO >0  
	BEGIN  
	RAISERROR('-112',16,1)  
	END  
	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date    
    
	--Is Root Node CHECK  
	SET @tempCode=' @DUPNODENO INT OUTPUT'   
	SET @DUPLICATECODE=' select @DUPNODENO=NodeID  from '+@Table+' WHERE NodeID='+convert(NVARCHAR,@NodeID) +' and ParentID=0'     
  
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
	IF(@TempGuid!=@Guid)    
	BEGIN         
	RAISERROR('-101',16,1)    
	END    
	
	  
	--Update Main Table
	IF(@StaticFieldsQuery IS NULL)
		set @StaticFieldsQuery=''
	IF(@CustomFieldsQuery IS NULL)
		set @CustomFieldsQuery=''
	
	set @SQL='update '+@Table+'
	SET '+@StaticFieldsQuery+@CustomFieldsQuery+'[GUID]= NEWID(), [ModifiedBy] ='''+ @UserName
	  +''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE NodeID='+convert(NVARCHAR,@NodeID)
	exec(@SQL)
	
	--Update CostCenter Extra Fields
	set @SQL='update COM_CCCCDATA
	SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID='+convert(nvarchar,@NodeID) + ' AND COSTCENTERID = '+convert(nvarchar,@CostCenterID)
	exec(@SQL)
	
	set @SQL=' UPDATE '+@Table+' SET NAME=RTRIM(LTRIM(NAME)) WHERE NodeID='+convert(NVARCHAR,@NodeID)
	exec(@SQL)
	
	--Duplicate Check
	exec [spCOM_CheckUniqueCostCenter] @CostCenterID=@CostCenterID,@NodeID=@NodeID,@LangID=@LangID
	
	--Series Check
	declare @retSeries bigint
	EXEC @retSeries=spCOM_ValidateCodeSeries @CostCenterID,@NodeID,@LangId
	if @retSeries>0
	begin
		ROLLBACK TRANSACTION
		SET NOCOUNT OFF  
		RETURN -999
	end
	
	--CHECK WORKFLOW
    EXEC spCOM_CheckCostCentetWF @CostCenterID,@NodeID,@WID,@RoleID,@UserID,@UserName,@StatusID output
	
	--CCCC MAP
	IF @CCMAPXML<>''
		EXEC [spCOM_SetCCCCMap] @CostCenterID,@NodeID,@CCMAPXML,@UserName,@LangID
		
		
	--CREATE/EDIT LINK DIMENSION
	declare @LinkDimCC nvarchar(max),@iLinkDimCC int
	SELECT @LinkDimCC=[Value] FROM com_costcenterpreferences with(nolock) WHERE CostCenterID=@CostCenterID and [Name]='LinkDimension'
	if(ISNUMERIC(@LinkDimCC)=1)
		set @iLinkDimCC=CONVERT(int,@LinkDimCC)
	else
		set @iLinkDimCC=0
	
	if (@LinkDimCC>50000 and @iLinkDimCC!=@CostCenterID)
	begin
		declare @LinkDimNodeID INT,@return_value int,@CCStatusID bigint
		
		--set @UpdateSql='select @LinkDimNodeID=CCNID'+convert(nvarchar,(@LinkDimCC-50000))+' from COM_CCCCData WHERE CostCenterID='+convert(nvarchar,@CostCenterID) +' and NODEID='+convert(NVARCHAR,@NodeID)  
		--EXEC sp_executesql @UpdateSql,N'@LinkDimNodeID INT OUTPUT',@LinkDimNodeID OUTPUT  
		
		select @LinkDimNodeID=RefDimensionNodeID from com_docbridge with(nolock) 
		WHERE CostCenterID=@CostCenterID AND NodeID=@NodeID AND RefDimensionID=@iLinkDimCC
		
		set @CCStatusID=(select top 1 statusid from com_status with(nolock) where costcenterid=@LinkDimCC)

		if(@LinkDimNodeID is null or @LinkDimNodeID=1)
		begin 
			EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
			@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
			@Code = @Code,
			@Name = @Name,
			@AliasName=@Name,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML='',@AttachmentsXML=NULL,
			@CustomCostCenterFieldsQuery=NULL,@ContactsXML='',@NotesXML=NULL,
			@CostCenterID = @LinkDimCC,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1 , @CheckLink = 0
			
			-- -- Link Dimension Mapping
			INSERT INTO COM_DocBridge(CostCenterID,NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby,CreatedDate,Abbreviation)
			values(@CostCenterID,@NodeID,0,0,@LinkDimCC,@return_value,'',newid(),@UserName, @dt,'Account')
 		end
		else
		begin
			declare @Gid nvarchar(50), @NodeidXML nvarchar(max) 
			select @Table=Tablename from adm_features with(nolock) where featureid=@LinkDimCC
			set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' where NodeID='+convert(nvarchar,@LinkDimNodeID)+')'

			exec sp_executesql @NodeidXML,N'@Gid nvarchar(50) output' , @Gid OUTPUT 
				
			EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
			@NodeID = @LinkDimNodeID,@SelectedNodeID=1,@IsGroup = 0,
			@Code = @Code,
			@Name = @Name,
			@AliasName=@Name,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML='',@AttachmentsXML=NULL,
			@CustomCostCenterFieldsQuery=NULL,@ContactsXML='',@NotesXML=NULL,
			@CostCenterID = @LinkDimCC,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1, @CheckLink = 0
 		end 
		
		--Update Acc_accounts set CCID=@CCID, CCNodeID=@return_value where AccountID=@AccountID
		DECLARE @CCMapSql nvarchar(max)
		set @CCMapSql='update COM_CCCCDATA  
		SET CCNID'+convert(nvarchar,(@LinkDimCC-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  
		WHERE CostCenterID='+convert(nvarchar,@CostCenterID) +' and NODEID='+convert(NVARCHAR,@NodeID)  
		EXEC (@CCMapSql)
		--UPDATE LINK DATA
		if(@return_value>0)
		begin
			Exec [spDOC_SetLinkDimension]
				@InvDocDetailsID=@NodeID, 
				@Costcenterid=@CostCenterID,         
				@DimCCID=@LinkDimCC,
				@DimNodeID=@return_value,
				@UserID=@UserID,    
				@LangID=@LangID  
		end			
	end
	
	--Dimension History Data
	IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
		EXEC spCOM_SetHistory @CostCenterID,@NodeID,@HistoryXML,@UserName  
	
	IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')
		exec [spCOM_SetAttachments] @NodeID,@CostCenterID,@AttachmentsXML,@UserName,@Dt
	
	IF (@StatusXML IS NOT NULL AND @StatusXML <> '')
		exec spCOM_SetStatusMap @CostCenterID,@NodeID,@StatusXML,@UserName,@Dt

	--Insert Notifications
	EXEC spCOM_SetNotifEvent 3,@CostCenterID,@NodeID,@CompanyGUID,@UserName,@UserID,@RoleID

	--Insert Grade in Assigned leaves
	IF(@CostCenterID=50053)
		EXEC spPAY_InsertPayrollCostCenter @CostCenterID,@NodeID,@UserID,@LangID
	
	
	COMMIT TRANSACTION   
	--rollback TRANSACTION
	

	--Audit Data
	set @SQL=''
	if exists(SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterId and Name='AuditTrial' and Value='True')
	begin
		exec @return_value=spADM_AuditData 1,@CostCenterID,@NodeID,'Update','',1,1
		if @return_value!=1
			set @SQL=' With Audit Trial Error'
	end

	SET NOCOUNT OFF;     
	SELECT ErrorMessage+@SQL ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID    
	RETURN @NodeID  
END TRY  
  
BEGIN CATCH    
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
