USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetBatch]
	@BatchID [int],
	@IsBatchSeqNoExists [bit],
	@BatchNumber [nvarchar](200),
	@ManufactureDateFormat [nvarchar](50) = NULL,
	@ManufactureDate [datetime] = NULL,
	@ExpiryDateFormat [nvarchar](50),
	@ExpiryDate [datetime] = NULL,
	@StatusID [int],
	@MRPRate [float],
	@MRPCurrID [int] = NULL,
	@MRPExchRT [float],
	@RetailRate [float],
	@RRCurrID [int] = NULL,
	@RRExchRT [float],
	@StockistRate [float],
	@SRCurrID [int] = NULL,
	@SRExchRT [float],
	@ProductID [int] = NULL,
	@VendorAccountID [int],
	@AlertDays [int],
	@PreExpiryDays [int],
	@SelectedNodeID [int],
	@RetestDate [datetime] = NULL,
	@IsGroup [bit],
	@CustomFieldsQuery [nvarchar](max) = NULL,
	@CustomCostCenterFieldsQuery [nvarchar](max) = NULL,
	@CCMapXML [nvarchar](max) = NULL,
	@ContactsXML [nvarchar](max) = NULL,
	@NotesXML [nvarchar](max) = NULL,
	@AttachmentsXML [nvarchar](max) = NULL,
	@AddressTypeID [int] = NULL,
	@ContactName [nvarchar](500) = NULL,
	@Address1 [nvarchar](500) = NULL,
	@Address2 [nvarchar](500) = NULL,
	@Address3 [nvarchar](500) = NULL,
	@City [nvarchar](100) = NULL,
	@State [nvarchar](100) = NULL,
	@Zip [nvarchar](50) = NULL,
	@Country [nvarchar](100) = NULL,
	@Phone1 [nvarchar](50) = NULL,
	@Phone2 [nvarchar](50) = NULL,
	@Fax [nvarchar](50) = NULL,
	@Email1 [nvarchar](50) = NULL,
	@Email2 [nvarchar](50) = NULL,
	@URL [nvarchar](50) = NULL,
	@BatchCode [nvarchar](200) = null,
	@CodePrefix [nvarchar](200) = null,
	@CodeNumber [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
	--Declaration Section      
	DECLARE @Dt FLOAT,@XML xml ,@Dimesion INT,@HasAccess bit,@TempGuid NVARCHAR(50)           
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth INT,@ParentID INT      
	DECLARE @SelectedIsGroup BIT, @ParentCode NVARCHAR(MAX),@UpdateSql NVARCHAR(MAX)    
	declare @NID INT, @CCStatusID INT,  @PrefValue nvarchar(50), @Gid nvarchar(50) , @Table nvarchar(100)

	--User acces check    
	IF @BatchID=0    
	BEGIN    
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,16,1)    
	END    
	ELSE    
	BEGIN    
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,16,3)    
	END    

	IF @HasAccess=0    
	BEGIN    
		RAISERROR('-105',16,1)    
	END    
    if(@VendorAccountID=0)
		set @VendorAccountID=NULL
	if(@RetestDate='1/JAN/1900')
		set @RetestDate=NULL
	if(@ManufactureDate='1/JAN/1900')
		set @ManufactureDate=NULL
	if(@ExpiryDate='1/JAN/1900')
		set @ExpiryDate=NULL		
		
    DECLARE @AllowDuplicateBatches BIT, @AllowDupBatchesforDiffProducts bit,@IsBatchCodeAutoGen bit,@BatchNumSameAsCode bit 
	select @AllowDuplicateBatches=CONVERT(bit,value) from COM_CostCenterPreferences with(nolock) 
	where CostCenterID=16 and Name='AllowDuplicateBatches'
 	select @AllowDupBatchesforDiffProducts=CONVERT(bit,value) from COM_CostCenterPreferences with(nolock) 
 	where CostCenterID=16 and Name='AllowDupBatchesforDiffProducts'
 	select @IsBatchCodeAutoGen=CONVERT(bit,value) from COM_CostCenterPreferences with(nolock)
 	where CostCenterID=16 and Name='BatchCodeAutoGen'
 	select @PrefValue=Value from COM_CostCenterPreferences with(nolock) where CostCenterID=16 and Name='BatchDimension'

	select @BatchNumSameAsCode=CONVERT(bit,value) from COM_CostCenterPreferences with(nolock)
 	where CostCenterID=16 and Name='BatchNumSameAsCode'

	
	if(@PrefValue is not null and @PrefValue<>'')  
	begin     
		set @Dimesion=0  
		begin try  
			select @Dimesion=convert(INT,@PrefValue)  
		end try  
		begin catch  
			set @Dimesion=0   
		end catch  

		select @Table=Tablename from adm_features with(nolock) where featureid=@Dimesion
		set @NID=0

		if(@BatchID>0)
		BEGIN
			select @NID=RefDimensionNodeID from COM_DocBridge with(nolock) where NodeID=@BatchID
			set @UpdateSql='select @Gid=GUID from '+convert(nvarchar,@Table)+' where NodeID='''+convert(nvarchar,@NID)+''''
			exec sp_executesql @UpdateSql,N'@Gid nvarchar(50) output',@Gid OUTPUT 
		END	
	END
	
 	if(@AllowDuplicateBatches=0)
	BEGIN
		if(@AllowDupBatchesforDiffProducts=1)		
		BEGIN    
			if exists (SELECT BatchId,BATCHNUMBER FROM INV_Batches with(nolock) WHERE BATCHNUMBER = @BatchNumber and batchid<>@BatchID AND ProductID=@ProductID)
				RAISERROR('-501',16,1)    
		END 
		else if exists (SELECT BatchId,BATCHNUMBER FROM INV_Batches with(nolock) WHERE BATCHNUMBER = @BatchNumber and batchid<>@BatchID)
		BEGIN    
			RAISERROR('-501',16,1)    
		END 
	END 
	
 	if(@BatchID=0)
 	BEGIN
		IF @IsBatchCodeAutoGen IS NOT NULL AND @IsBatchCodeAutoGen=1 AND @BatchID=0 and @CodePrefix=''  
		BEGIN 
			--CALL AUTOCODEGEN 
			create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
			if(@SelectedNodeID is null)
			insert into #temp1
			EXEC [spCOM_GetCodeData] 16,1,''  
			else
			insert into #temp1
			EXEC [spCOM_GetCodeData] 16,@SelectedNodeID,''  
			--select * from #temp1
			select @BatchCode=code,@CodePrefix= prefix, @CodeNumber=number from #temp1
			--select @BatchCode,@ParentID
		END	
	END

	if((@BatchNumSameAsCode is null or @BatchNumSameAsCode='') AND @BatchNumSameAsCode=1)  
	BEGIN
		SET @BatchNumber=@BatchCode
	END
	
	--To SET Left,Right And Depth of Record      
	SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth      
	FROM [INV_Batches] WITH(NOLOCK) WHERE BatchID=@SelectedNodeID      
        
	--IF No Record Selected or Record Doesn't Exist      
	IF(@SelectedIsGroup is null)       
	BEGIN    
		SELECT @SelectedNodeID=BatchID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth      
		FROM [INV_Batches] WITH(NOLOCK) WHERE ParentID =0      
	END    
	    
	IF(@SelectedIsGroup = 1)--Adding Node Under the Group      
	BEGIN      
		UPDATE [INV_Batches] SET rgt = rgt + 2 WHERE rgt > @Selectedlft;      
		UPDATE [INV_Batches] SET lft = lft + 2 WHERE lft > @Selectedlft;      
		SET @lft =  @Selectedlft + 1      
		SET @rgt = @Selectedlft + 2      
		SET @ParentID = @SelectedNodeID      
		SET @Depth = @Depth + 1      
	END      
	ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level      
	BEGIN      
		UPDATE [INV_Batches] SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;      
		UPDATE [INV_Batches] SET lft = lft + 2 WHERE lft > @Selectedrgt;      
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
	END      
   
	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date 
	
	IF (@BatchID=0)--BatchID will be 0 in ALTER procedureess--      
	BEGIN--CREATE --      
		INSERT intO [INV_Batches]      
		([BatchNumber]      
		,[MfgDateFormat]      
		,[MfgDate]      
		,[ExpiryDateFormat]      
		,[ExpiryDate]      
		,[StatusID]      
		,[MRPRate]      
		,[MrpCurrID]    
		,[MrpExchRT]    
		,[RetailRate]    
		,[RRCurrID]    
		,[RRExchRT]    
		,[StockistRate]      
		,[SRCurrID]    
		,[SRExchRT]    
		,[ProductID]      
		,[VendorAccountID]      
		,[AlertDays]      
		,[PreExpiryDays]     
		,[Depth]      
		,[ParentID]      
		,[lft]      
		,[rgt]      
		,[IsGroup]       
		,[GUID]          
		,[CreatedBy]      
		,[CreatedDate],CompanyGUID, RetestDate, BatchCode, CodePrefix, CodeNumber)      
		VALUES      
		(@BatchNumber       
		,@ManufactureDateFormat       
		,CONVERT(FLOAT,@ManufactureDate)    
		,@ExpiryDateFormat       
		,CONVERT(FLOAT,@ExpiryDate)       
		,@StatusID       
		,@MRPRate      
		,@MRPCurrID     
		,@MRPExchRT    
		,@RetailRate       
		,@RRCurrID    
		,@RRExchRT    
		,@StockistRate       
		,@SRCurrID    
		,@SRExchRT    
		,@ProductID       
		,@VendorAccountID       
		,@AlertDays       
		,@PreExpiryDays ,      
		@Depth,      
		@ParentID,     
		@lft,      
		@rgt,      
		@IsGroup,      
		NEWID()       
		,@UserName      
		,@Dt,@CompanyGUID,  CONVERT(FLOAT,@RetestDate), @BatchCode,@CodePrefix,@CodeNumber)      
    
		SET @BatchID=SCOPE_IDENTITY()--Getting the NodeID
   
		IF @IsBatchSeqNoExists=1
		BEGIN
			UPDATE COM_CostCenterCodeDef
			SET CurrentCodeNumber=CurrentCodeNumber+1
			WHERE CostCenterID=16
		END
    
		-- Handling of CostCenter Costcenters Extrafields Table  
		INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
		VALUES(16, @BatchID, @UserName, @Dt, @CompanyGUID,newid())  
 
		if(@AddressTypeID is not null)
		begin
			--INSERT PRIMARY CONTACT
			INSERT into [COM_Contacts]
			([AddressTypeID]
			, FeatureId
			, FeaturePK
			,[ContactName]
			,[Address1]
			,[Address2]
			,[Address3]
			,[City]
			,[State]
			,[Zip]
			,[Country]
			,[Phone1]
			,[Phone2]
			,[Fax]
			,[Email1]
			,[Email2]
			,[URL]
			,[CompanyGUID]
			,[GUID] 
			,[CreatedBy]
			,[CreatedDate])
			VALUES(@AddressTypeID
			,16
			,@BATCHID
			,@ContactName
			,@Address1
			,@Address2
			,@Address3
			,@City
			,@State
			,@Zip 
			,@Country
			,@Phone1
			,@Phone2
			,@Fax
			,@Email1
			,@Email2
			,@URL
			,@CompanyGUID
			,NEWID()
			,@UserName
			,@Dt)
  
		end
	END      
	ELSE --UPDATE --      
	BEGIN    
		SELECT @TempGuid=[GUID] FROM [INV_Batches]  WITH(NOLOCK)       
		WHERE BatchID=@BatchID    
   
		UPDATE [INV_Batches]      
		SET [BatchNumber] = @BatchNumber       
		,[MfgDateFormat] = @ManufactureDateFormat       
		,[MfgDate] = CONVERT(FLOAT,@ManufactureDate)       
		,[ExpiryDateFormat] = @ExpiryDateFormat       
		,[ExpiryDate] = CONVERT(FLOAT,@ExpiryDate)      
		,[RetestDate] = CONVERT(FLOAT,@RetestDate)      
		,[StatusID] = @StatusID       
		,[MRPRate] = @MRPRate       
		,[MRPCurrID]=@MRPCurrID    
		,[MRPExchRT]=@MRPExchRT    
		,[RetailRate] = @RetailRate      
		,[RRCurrID]=@RRCurrID    
		,[RRExchRT]=@RRExchRT     
		,[StockistRate] = @StockistRate       
		,[SRCurrID]=@SRCurrID    
		,[SRExchRT]=@SRExchRT    
		,[ProductID] = @ProductID       
		,[VendorAccountID] = @VendorAccountID       
		,[AlertDays] = @AlertDays       
		,[PreExpiryDays] = @PreExpiryDays         
		,[GUID]=newid()      
		,[ModifiedBy] = @UserName      
		,[ModifiedDate] = @Dt   
		,BatchCode=@BatchCode
		,CodePrefix=@CodePrefix
		,CodeNumber=@CodeNumber
		WHERE BatchID=@BatchID      
 
		--UPDATE PRIMARY CONTACT
		UPDATE  [COM_Contacts]
		SET [AddressTypeID] = 1
		,[ContactName] = @ContactName
		,[Address1] = @Address1
		,[Address2] = @Address2
		,[Address3] =@Address3
		,[City] = @City
		,[State] = @State
		,[Zip] =@Zip
		,[Country] = @Country
		,[Phone1] = @Phone1
		,[Phone2] = @Phone2
		,[Fax] = @Fax 
		,[Email1] = @Email1
		,[Email2] = @Email2
		,[URL] = @URL
		,[CompanyGUID] =@CompanyGUID 
		,[GUID] = NEWID()
		,[ModifiedBy] = @UserName
		,[ModifiedDate] = @Dt
		WHERE [FeatureID]=16 AND [FeaturePK] = @BATCHID AND [AddressTypeID] = 1

    
	END   
  
	--Update Extended    
	if(@CustomFieldsQuery IS NOT NULL AND @CustomFieldsQuery <> '')    
	BEGIN    
		-- SET @ExtendedColsXML=dbo.fnCOM_GetExtraFieldsQuery(@ExtendedColsXML,3)  
		set @UpdateSql='update INV_Batches     
		SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @UserName    
		+''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE BatchID='+convert(NVARCHAR,@BatchID)   +' '
		exec(@UpdateSql)    
	END    

	--Inserts Multiple Contacts    
	IF (@ContactsXML IS NOT NULL AND @ContactsXML <> '')  
	BEGIN  
		--CHANGES MADE IN PRIMARY CONTACT QUERY BY HAFEEZ ON DEC 20 2013,BECOZ CONTACT QUICK ADD SCREEN IS CUSTOMIZABLE 
		declare @rValue int
		EXEC @rValue =  spCOM_SetFeatureWiseContacts 16,@BatchID,2,@ContactsXML,@UserName,@Dt,@LangID  
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
		INSERT INTO COM_Notes(FeatureID,FeaturePK,Note,       
		GUID,CreatedBy,CreatedDate)    
		SELECT 16,@BatchID,Replace(X.value('@Note','NVARCHAR(max)'),'@~','
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
	BEGIN    
		SET @XML=@AttachmentsXML    

		INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,    
		FileExtension,IsProductImage,FeatureID,FeaturePK,    
		GUID,CreatedBy,CreatedDate)    
		SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),    
		X.value('@FileExtension','NVARCHAR(50)'),X.value('@IsProductImage','bit'),16,@BatchID,    
		X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt    
		FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)      
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'    

		--If Action is MODIFY then update Attachments    
		UPDATE COM_Files    
		SET FilePath=X.value('@FilePath','NVARCHAR(500)'),    
		ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),    
		RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),    
		FileExtension=X.value('@FileExtension','NVARCHAR(50)'),    
		IsProductImage=X.value('@IsProductImage','bit'),          
		GUID=X.value('@GUID','NVARCHAR(50)'),    
		ModifiedBy=@UserName,    
		ModifiedDate=@Dt    
		FROM COM_Files C     
		INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X)      
		ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID    
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'    

		--If Action is DELETE then delete Attachments    
		DELETE FROM COM_Files    
		WHERE FileID IN(SELECT X.value('@AttachmentID','INT')    
		FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')    
	END  
	 	
	-- Update Custom Cost Center Fields  
	IF(@CustomCostCenterFieldsQuery IS NOT NULL AND @CustomCostCenterFieldsQuery <> '')  
	BEGIN  
		if not exists (select nodeid from com_ccccdata with(nolock) where nodeid=@BatchID and CostCenterID=16)
			INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
			VALUES(16, @BatchID, @UserName, @Dt, @CompanyGUID,newid())  

		set @UpdateSql='update COM_CCCCData  
		SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
		WHERE CostCenterID=16 and NODEID='+convert(NVARCHAR,@BatchID)  +' '
		exec(@UpdateSql)  
	END  
  
	if(@Dimesion>0)
	begin  	
		set @CCStatusID = (select  statusid from com_status with(nolock) where costcenterid=@Dimesion and status = 'Active')
		EXEC	@NID = [dbo].[spCOM_SetCostCenter]
		@NodeID = @NID,@SelectedNodeID = 1,@IsGroup = 0,
		@Code = @BatchCode,
		@Name = @BatchNumber,
		@AliasName=@BatchNumber,
		@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
		@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
		@CustomCostCenterFieldsQuery='',@ContactsXML=null,@NotesXML=NULL,
		@CostCenterID = @Dimesion,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1 , @CheckLink = 0 
		
		set @UpdateSql='update COM_CCCCDATA  
		SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@NID)+'  WHERE CostCenterID=16 and NODEID='+convert(NVARCHAR,@BatchID)
		EXEC (@UpdateSql)
		
		if not exists(select NodeID from COM_DocBridge with(nolock) where NodeID=@BatchID and RefDimensionNodeID=@NID)
		BEGIN
			INSERT INTO COM_DocBridge(CostCenterID,NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby,CreatedDate,Abbreviation)
			values(16, @BatchID,0,0,@Dimesion,@NID,'',newid(),@UserName, @dt,'Units')
		END
			
		--UPDATE LINK DATA
		if(@NID>0)
		begin
			Exec [spDOC_SetLinkDimension]
				@InvDocDetailsID=@BatchID, 
				@Costcenterid=16,         
				@DimCCID=@Dimesion,
				@DimNodeID=@NID,
				@UserID=@UserID,    
				@LangID=@LangID  
		end
	END
	
	COMMIT TRANSACTION  
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
	WHERE ErrorNumber=100 AND LanguageID=@LangID        
	SET NOCOUNT OFF;      
	RETURN @BatchID      
END TRY    


BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]      
	IF ERROR_NUMBER()=50000    
	BEGIN    
		SELECT * FROM [INV_Batches] WITH(NOLOCK) WHERE BatchID=@BatchID    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
	END    
	ELSE IF ERROR_NUMBER()=547    
	BEGIN    
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-110 AND LanguageID=@LangID    
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
