USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetQucikBatch]
	@BatchID [int],
	@IsBatchSeqNoExists [bit],
	@BatchNumber [nvarchar](200),
	@ManufactureDate [datetime] = NULL,
	@ExpiryDate [datetime] = NULL,
	@MRPRate [float],
	@RetailRate [float],
	@StockistRate [float],
	@ProductID [int] = NULL,
	@RetestDate [datetime] = NULL,
	@SelectedNodeID [int],
	@IsGroup [bit],
	@StaticFieldsQuery [nvarchar](max) = null,
	@CustomFieldsQuery [nvarchar](max) = NULL,
	@CustomCostCenterFieldsQuery [nvarchar](max) = NULL,
	@BatchCode [nvarchar](200) = null,
	@CodePrefix [nvarchar](200) = null,
	@CodeNumber [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
	--Declaration Section      
	if(@RetestDate='1/JAN/1900')
		set @RetestDate=NULL   
	if(@ManufactureDate='1/JAN/1900')
		set @ManufactureDate=NULL
	if(@ExpiryDate='1/JAN/1900')
		set @ExpiryDate=NULL  
		 
	DECLARE @Dt FLOAT,@XML xml,@HasAccess bit ,@Dimesion INT     
	DECLARE @TempGuid NVARCHAR(50)     
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
	
	
	    
    DECLARE @AllowDuplicateBatches BIT, @AllowDupBatchesforDiffProducts bit,@IsBatchCodeAutoGen bit ,@BatchNumSameAsCode bit 
	select @AllowDuplicateBatches=CONVERT(bit,value) from COM_CostCenterPreferences WITH(nolock) 
	where CostCenterID=16 and Name='AllowDuplicateBatches'
 	select @AllowDupBatchesforDiffProducts=CONVERT(bit,value) from COM_CostCenterPreferences WITH(nolock) 
 	where CostCenterID=16 and Name='AllowDupBatchesforDiffProducts'
 	select @IsBatchCodeAutoGen=CONVERT(bit,value) from COM_CostCenterPreferences WITH(nolock) 
 	where CostCenterID=16 and Name='BatchCodeAutoGen'
	select @PrefValue=Value from COM_CostCenterPreferences WITH(nolock) 
	where CostCenterID=16 and Name='BatchDimension'
	
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
		
		select @Table=Tablename from adm_features WITH(nolock) where featureid=@Dimesion
		set @NID=0
		
		if(@BatchID>0)
		BEGIN
			select @NID=RefDimensionNodeID from COM_DocBridge with(nolock) where NodeID=@BatchID
			set @UpdateSql='select @Gid=GUID from '+convert(nvarchar,@Table)+' with(nolock) where NodeID='''+convert(nvarchar,@NID)+''''
			exec sp_executesql @UpdateSql,N'@Gid nvarchar(50) output',@Gid OUTPUT 
		END
	END 
	
	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date 
	
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
			select @BatchCode=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 with(nolock)
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
   
	IF (@BatchID=0)--BatchID will be 0 in ALTER procedureess--      
	BEGIN--CREATE --      
		INSERT intO [INV_Batches]([BatchNumber]  ,[MfgDate],[ExpiryDate],[StatusID],[MRPRate],[RetailRate],[StockistRate],[ProductID]
		,[Depth],[ParentID],[lft],[rgt],[IsGroup],[GUID],[CreatedBy],[CreatedDate],CompanyGUID, RetestDate, BatchCode, CodePrefix, CodeNumber)      
		VALUES(@BatchNumber ,CONVERT(FLOAT,@ManufactureDate),CONVERT(FLOAT,@ExpiryDate),77,@MRPRate ,@RetailRate,@StockistRate ,@ProductID       
		,@Depth,@ParentID,@lft,@rgt,@IsGroup,NEWID(),@UserName ,@Dt,@CompanyGUID,CONVERT(FLOAT,@RetestDate),@BatchCode,@CodePrefix,@CodeNumber)      
	    
		SET @BatchID=SCOPE_IDENTITY()--Getting the NodeID
	   
		IF @IsBatchSeqNoExists=1
		BEGIN
			UPDATE COM_CostCenterCodeDef
			SET CurrentCodeNumber=CurrentCodeNumber+1
			WHERE CostCenterID=16
		END
	     
		--INSERTING INTO BATCH DETAILS
		INSERT INTO  [dbo].[INV_BatchDetails]
		([BatchID]
		,[InvDocDetailsID]
		,[Quantity]
		,[HoldQuantity]
		,[ReleaseQuantity]
		,[ExecutedQuantity]
		,[CompanyGUID]
		,[GUID]
		,[CreatedBy]
		,[CreatedDate])
		VALUES(@BATCHID
		,0
		,0
		,0
		,0
		,0
		,@CompanyGUID
		,NEWID()
		,@UserName
		,@Dt) 
		   
		-- Handling of CostCenter Costcenters Extrafields Table  
		INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
		VALUES(16, @BatchID, @UserName, @Dt, @CompanyGUID,newid())    
	END      
	ELSE --UPDATE --      
	BEGIN   
		SELECT @TempGuid=[GUID] FROM [INV_Batches]  WITH(NOLOCK)       
		WHERE BatchID=@BatchID      

		IF(@TempGuid!=@Guid)      
		BEGIN      
			RAISERROR('-101',16,1) -- Need to Get Data From Error Table To return Error Message by Language            
		END      

		UPDATE [INV_Batches]      
		SET [BatchNumber] = @BatchNumber       
		,[MfgDate] = CONVERT(FLOAT,@ManufactureDate)       
		,[ExpiryDate] = CONVERT(FLOAT,@ExpiryDate)      
		,[RetestDate] = CONVERT(FLOAT,@RetestDate)      
		,[MRPRate] = @MRPRate       
		,[RetailRate] = @RetailRate      
		,[StockistRate] = @StockistRate       
		,[ProductID] = @ProductID       
		,[GUID]=newid()      
		,[ModifiedBy] = @UserName      
		,[ModifiedDate] = @Dt      
		,BatchCode=@BatchCode
		,CodePrefix=@CodePrefix
		,CodeNumber=@CodeNumber
		WHERE BatchID=@BatchID      
   
	END      
  
	if(@StaticFieldsQuery IS NOT NULL AND @StaticFieldsQuery <> '')    
	BEGIN    
		-- SET @ExtendedColsXML=dbo.fnCOM_GetExtraFieldsQuery(@ExtendedColsXML,3)  
		set @UpdateSql='update INV_Batches     
		SET '+@StaticFieldsQuery+' [ModifiedBy] ='''+ @UserName    
		+''',[ModifiedDate] =' + convert(NVARCHAR,@Dt) +' WHERE BatchID='+convert(NVARCHAR,@BatchID)   +' '
		exec(@UpdateSql)    
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
  

	-- Update Custom Cost Center Fields  
	IF(@CustomCostCenterFieldsQuery IS NOT NULL AND @CustomCostCenterFieldsQuery <> '')  
	BEGIN  
		if not exists (select nodeid from com_ccccdata where nodeid=@BatchID and CostCenterID=16)
			INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
			VALUES(16, @BatchID, @UserName, @Dt, @CompanyGUID,newid())  
		set @UpdateSql='update COM_CCCCData  
		SET '+@CustomCostCenterFieldsQuery+' [ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' 
		WHERE CostCenterID=16 and NODEID='+convert(NVARCHAR,@BatchID)  +' '
		print @UpdateSql
		exec(@UpdateSql)  
	END 
  
	if(@Dimesion>0)
	begin  
		set @CCStatusID = (select  statusid from com_status WITH(nolock) where costcenterid=@Dimesion and status = 'Active')
		EXEC	@NID = [dbo].[spCOM_SetCostCenter]
		@NodeID = @NID,@SelectedNodeID = 1,@IsGroup = 0,
		@Code = @BatchCode,
		@Name = @BatchNumber,
		@AliasName=@BatchNumber,
		@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
		@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
		@CustomCostCenterFieldsQuery='',@ContactsXML=null,@NotesXML=NULL,
		@CostCenterID = @Dimesion,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1 , @CheckLink = 0 
		
		set @UpdateSql='if exists(select nodeid from com_cc'+convert(nvarchar,@Dimesion)+'  with(nolock) where nodeid='+CONVERT(NVARCHAR,@NID)+')
		 update COM_CCCCDATA  
		SET CCNID'+convert(nvarchar,(@Dimesion-50000))+'='+CONVERT(NVARCHAR,@NID)+'  WHERE CostCenterID=16 and NODEID='+convert(NVARCHAR,@BatchID)
		--print @UpdateSql
		EXEC (@UpdateSql)
	  
		if not exists(select NodeID from COM_DocBridge WITH(nolock) where NodeID=@BatchID and RefDimensionNodeID=@NID)
		BEGIN
			INSERT INTO COM_DocBridge(CostCenterID,NodeID,InvDocID,AccDocID,RefDimensionID,RefDimensionNodeID,CompanyGUID,guid,Createdby,CreatedDate,Abbreviation)
			values(16, @BatchID,0,0,@Dimesion,@NID,'',newid(),@UserName, @dt,'Units')
		END
			
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
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
	END    
	ELSE IF ERROR_NUMBER()=547    
	BEGIN    
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)    
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
