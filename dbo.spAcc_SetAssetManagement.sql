USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAcc_SetAssetManagement]
	@AssetID [int],
	@AssetCode [nvarchar](50),
	@AssetName [nvarchar](max),
	@StatusID [int],
	@PurchaseValue [nvarchar](50),
	@ParentAssetID [int],
	@IsGroup [bit] = 0,
	@CodePrefix [nvarchar](200) = null,
	@CodeNumber [int] = 0,
	@Sno [nvarchar](50),
	@DetailXML [nvarchar](max) = null,
	@ChangeValueXML [nvarchar](max) = null,
	@CustomFieldsQuery [nvarchar](max) = null,
	@CustomCostCenterFieldsQuery [nvarchar](max) = null,
	@AssetDepreciationXML [nvarchar](max) = null,
	@HistoryXML [nvarchar](max) = null,
	@NotesXML [nvarchar](max) = null,
	@AttachmentsXML [nvarchar](max) = null,
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@CreatedBy [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1,
	@RoleID [int] = 0,
	@WID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;      
        
    DECLARE @ID int,@cnt int,@Dt FLOAT, @lft INT,@rgt INT,@TempGuid nvarchar(50),@Selectedlft INT,@Selectedrgt INT,@HasAccess bit,@IsDuplicateNameAllowed bit,@IsAssetCodeAutoGen bit  ,@IsIgnoreSpace bit  ,      
 @Depth int,@ParentID INT,@SelectedIsGroup int , @XML XML,@ParentCode nvarchar(200),@UpdateSql nvarchar(max),@astID INT,@DtXML xml , @DepXML XML  ,@AssetCCID INT,@DeprStartValue float
   DECLARE @HistoryStatus NVARCHAR(300)
       
  if(@ParentAssetID=0 and @AssetID=0)
	select @ParentAssetID=AssetID from acc_assets with(nolock) where parentid=0 and isgroup=1
       
 set @DtXML=@DetailXML      
      
  --GETTING PREFERENCE        
  SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=72 and  Name='DuplicateNameAllowed'        
  SELECT @IsAssetCodeAutoGen=IsEnable from COM_CostCenterCodeDef WITH(nolock) where CostCenterID=72 and IsGroupCode=@IsGroup and IsName=0  
  SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=72 and  Name='IgnoreSpaces'        
        
  --DUPLICATE CHECK        
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0        
  BEGIN        
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1        
   BEGIN        
    IF @AssetID=0        
    BEGIN        
     IF EXISTS (SELECT AssetID FROM ACC_Assets WITH(nolock) WHERE replace(AssetName,' ','')=replace(@AssetName,' ',''))        
     BEGIN        
      RAISERROR('-145',16,1)        
     END        
    END        
    ELSE        
    BEGIN   
  
     IF EXISTS (SELECT AssetID FROM ACC_Assets WITH(nolock) WHERE replace(AssetName,' ','')=replace(@AssetName,' ','') AND AssetID <> @AssetID)        
     BEGIN    
      RAISERROR('-145',16,1)             
     END        
    END        
   END        
   ELSE        
   BEGIN        
    IF @AssetID=0        
    BEGIN        
     IF EXISTS (SELECT AssetID FROM ACC_Assets WITH(nolock) WHERE AssetName=@AssetName)        
     BEGIN        
      RAISERROR('-145',16,1)        
     END        
    END        
    ELSE        
    BEGIN        
     IF EXISTS (SELECT AssetID FROM ACC_Assets WITH(nolock) WHERE AssetName=@AssetName AND AssetID <> @AssetID)        
     BEGIN        
      RAISERROR('-145',16,1)        
     END        
    END        
   END      
  END      
         
  
  if(@AssetID=0)
		set @HistoryStatus='Add'
	else
		set @HistoryStatus='Update'

  SET @Dt=convert(float,getdate())--Setting Current Date        


  --WorkFlow
Declare @CStatusID int
Declare @level int,@maxLevel int
SELECT @CStatusID=ISNULL(StatusID,0) FROM ACC_Assets WITH(NOLOCK) where AssetID=@AssetID
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
		else if(@level is not null and  @maxLevel is not null and @AssetID>0 and @level<@maxLevel and @CStatusID in (1003))--rejected status time
		begin	
		 	set @StatusID=1001 
		end			 
		 
	end
  
 IF @AssetID = 0--------START INSERT RECORD-----------        
  BEGIN--CREATE Asset--        
     --To Set Left,Right And Depth of Record        
    SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth        
    from ACC_Assets with(NOLOCK) where AssetId=@ParentAssetID        
            
    --IF No Record Selected or Record Doesn't Exist        
    if(@SelectedIsGroup is null)         
     select @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth        
     from ACC_Assets with(NOLOCK) where ParentID =0        
                  
    if(@SelectedIsGroup = 1)--Adding Node Under the Group        
     BEGIN        
      UPDATE ACC_Assets SET rgt = rgt + 2 WHERE rgt > @Selectedlft;        
      UPDATE ACC_Assets SET lft = lft + 2 WHERE lft > @Selectedlft;        
      set @lft =  @Selectedlft + 1        
      set @rgt = @Selectedlft + 2        
      set @ParentID = @ParentAssetID        
      set @Depth = @Depth + 1        
     END        
    else if(@SelectedIsGroup = 0)--Adding Node at Same level        
     BEGIN        
      UPDATE ACC_Assets SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;        
      UPDATE ACC_Assets SET lft = lft + 2 WHERE lft > @Selectedrgt;        
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
    IF @IsAssetCodeAutoGen IS NOT NULL AND @IsAssetCodeAutoGen=1 AND @AssetID=0 and @AssetCode=''
    BEGIN        
     SELECT @ParentCode=[AssetCode]  FROM ACC_Assets WITH(NOLOCK) WHERE AssetID=@ParentID          
        
     --CALL AUTOCODEGEN        
     EXEC [spCOM_SetCode] 72,@ParentCode,@AssetCode OUTPUT     
       -- select @AssetCode     
    END  
    
    IF @AssetCode IS NULL OR @AssetCode=''  
		SET @AssetCode=convert(nvarchar,IDENT_CURRENT('dbo.ACC_Assets')+1)
          
      if(@ParentAssetID =0 and @ParentID>0)
		set @ParentAssetID=@ParentID
      else if(@ParentID=0 and @ParentAssetID>0)
		set @ParentID=@ParentAssetID
      
      INSERT INTO ACC_Assets      
      (AssetCode      
      ,AssetName      
      ,StatusID      
      ,PurchaseValue      
      ,ParentAssetID      
      ,SerialNo      
      ,CodePrefix,CodeNumber
      ,IsGroup      
      ,Depth      
      ,ParentID      
      ,lft      
      ,rgt      
      ,CompanyGUID      
      ,GUID      
      ,CreatedBy      
      ,CreatedDate,WorkFlowID,WorkFlowLevel)      
      
     select @AssetCode      
      ,@AssetName      
      ,@StatusID      
      ,@PurchaseValue      
      ,@ParentAssetID      
      ,@Sno
      ,@CodePrefix,@CodeNumber
      , @IsGroup      
      ,@Depth      
      ,@ParentID      
      ,@lft      
      ,@rgt      
      ,@CompanyGUID      
      ,newid()      
      ,@CreatedBy      
      ,@Dt,@WID,ISNULL(@level,0)
		
	  SET @astID=SCOPE_IDENTITY()      
      SET @UpdateSql='update ACC_Assets SET '+@DetailXML+' [CreatedBy] ='''+ @CreatedBy +''' WHERE AssetID = '+convert(nvarchar,@astID)     
	  exec(@UpdateSql)    
		
 --Handling of Extended Table        
    INSERT INTO ACC_AssetsExtended  ([AssetID],[CreatedBy],[CreatedDate])        
    VALUES(@astID, @CreatedBy, @Dt)       
      
       
    --Handling of CostCenter Costcenters Extrafields Table       
      
   INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])      
     VALUES(72,@astID,newid(),  @CreatedBy, @Dt)       
      
      
     IF (@AssetDepreciationXML IS NOT NULL AND @AssetDepreciationXML <> '')        
	 BEGIN
		  select @DeprStartValue=DeprStartValue from ACC_Assets with(nolock) where AssetID=@astID
		  SET @DepXML=@AssetDepreciationXML   
   		  INSERT INTO  [ACC_AssetDepSchedule]  
				   ([AssetID]  
				   ,[DeprStartDate]  
				   ,[DeprEndDate]  
				   ,[DepAmount]  
				   ,[AccDepreciation]  
				   ,[AssetNetValue]  
				   ,[PurchaseValue]  
				   ,[DocID]  
				   ,[VoucherNo]  
				   ,[DocDate]  
				   ,[StatusID]  
				   ,[CreatedBy]  
				   ,[CreatedDate]  
				   ,ActualDeprAmt
				   )  
		                
			SELECT @astID, convert(float,X.value('@From','datetime')) ,convert(float,X.value('@To','datetime')),X.value('@DepAmt','FLOAT'),
				 X.value('@AccDep','FLOAT'),X.value('@NetValue','FLOAT'),@DeprStartValue ,NULL,NULL,NULL,ISNULL(X.value('@StatusID','INT'), 0),
			@CreatedBy,@Dt,X.value('@ActDepAmt','FLOAT')
			FROM @DepXML.nodes('/XML/Row') as Data(X)    
		END  

		if(@WID>0)
		BEGIN	 
			INSERT INTO COM_Approvals(CCID,CCNODEID,StatusID,Date,Remarks,UserID,CompanyGUID,GUID,CreatedBy,CreatedDate,WorkFlowLevel,DocDetID)     
			VALUES(72,@astID,@StatusID,CONVERT(FLOAT,getdate()),'',@UserID,@CompanyGUID,newid(),@CreatedBy,CONVERT(FLOAT,getdate()),isnull(@level,0),0)
		END	
	END --------END INSERT RECORD-----------        
	ELSE--UPDATE--      
	BEGIN--------START UPDATE RECORD----------      
		SELECT @TempGuid=[GUID] from ACC_Assets  WITH(NOLOCK)         
		WHERE AssetID=@AssetID      
                
		IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ          
			RAISERROR('-101',16,1)         
	  
		update ACC_Assets set       
			AssetCode= @AssetCode      
			,AssetName=@AssetName      
			,StatusID=@StatusID      
			, PurchaseValue=@PurchaseValue      
			,ParentAssetID=@ParentAssetID      
			,IsGroup=@IsGroup  
			,WorkFlowLevel=isnull(@level,0)
		where AssetID=@AssetID      
	  
		if(@DetailXML is not null)      
		begin      
			SET @UpdateSql='update ACC_Assets SET '+@DetailXML+' [ModifiedBy] ='''+ @CreatedBy +''',[ModifiedDate] =' + convert(nvarchar,@Dt) +'  WHERE AssetID = '+convert(nvarchar,@AssetID)     
			exec(@UpdateSql)
		end      
		IF (@AssetDepreciationXML IS NOT NULL AND @AssetDepreciationXML <> '' AND NOT EXISTS(select ASSETID from ACC_AssetDepSchedule with(nolock) where ASSETID=@AssetID))        
		BEGIN
			select @DeprStartValue=DeprStartValue from ACC_Assets with(nolock) where AssetID=@AssetID
		
			SET @DepXML=@AssetDepreciationXML   
			DELETE  FROM [ACC_AssetDepSchedule] WHERE ASSETID = @AssetID AND DOCID IS NULL AND VOUCHERNO IS NULL AND STATUSID = 0 
			 
			INSERT INTO  [ACC_AssetDepSchedule]  
			   ([AssetID]  
			   ,[DeprStartDate]  
			   ,[DeprEndDate]  
			   ,[DepAmount]  
			   ,[AccDepreciation]  
			   ,[AssetNetValue]  
			   ,[PurchaseValue]  
			   ,[DocID]  
			   ,[VoucherNo]  
			   ,[DocDate]  
			   ,[StatusID]  
			   ,[CreatedBy]  
			   ,[CreatedDate]
			   ,ActualDeprAmt)  
			SELECT @AssetID, convert(float,X.value('@From','datetime')) ,convert(float,X.value('@To','datetime')) ,X.value('@DepAmt','FLOAT') ,   
				 X.value('@AccDep','FLOAT'),X.value('@NetValue','FLOAT'),@DeprStartValue ,NULL,NULL,NULL,ISNULL(X.value('@StatusID','INT'), 0),
			@CreatedBy,@Dt,X.value('@ActDepAmt','FLOAT')
			FROM @DepXML.nodes('/XML/Row') as Data(X)    
			
			 update ACC_Assets set IsDeprSchedule = 1 where AssetID=@AssetID 		   
		END 
		
		set @astID=@AssetID      
	END--------END UPDATE RECORD----------     
       
    set @UpdateSql='update ACC_AssetsExtended      
  SET '+@CustomFieldsQuery+' [ModifiedBy] ='''+ @CreatedBy      
    +''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE AssetID = '+convert(nvarchar,@astID)     
  exec(@UpdateSql)              
           
    set @UpdateSql='update COM_CCCCDATA        
 SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @CreatedBy+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID = '+convert(nvarchar,@astID) + ' AND CostCenterID = 72'       
	exec(@UpdateSql)  
	      
  --Inserts Multiple Changes       
/*	IF (@ChangeValueXML IS NOT NULL AND @ChangeValueXML <> '')        
	BEGIN      
		SET @XML=@ChangeValueXML        
        
		if exists(select * from ACC_AssetChanges with(nolock) WHERE AssetID=@astID)    
		begin    
			DELETE FROM ACC_AssetChanges WHERE AssetID=@astID    
		end    
		--If Action is NEW then insert new Changes
	   INSERT INTO ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,        
	   AssetOldValue,ChangeValue,AssetNewValue,        
	   LocationID,GUID,CreatedBy,CreatedDate)        
	   SELECT @astID,X.value('@ChangeType','int'),X.value('@ChangeName','NVARCHAR(50)'),        
	   X.value('@StatusID','INT'),convert(float,X.value('@ChangeDate','datetime')),X.value('@AssetOldValue','Float'),        
	   X.value('@ChangeValue','nvarchar(50)'),X.value('@AssetNewValue','Float'),X.value('@LocationID','INT'),        
	   newid(),@CreatedBy,@Dt        
	   FROM @XML.nodes('/ChangeValueXML/Row') as Data(X)       
  END  */

	IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')    
		EXEC spCOM_SetHistory 72,@astID,@HistoryXML,@CreatedBy  

 -- IF (@HistoryXML IS NOT NULL AND @HistoryXML <> '')        
 -- BEGIN     
  
 -- set @XML=@HistoryXML
 --   if exists(select * from ACC_AssetsHistory WHERE AssetManagementID=@astID)    
 --   begin    
	-- DELETE FROM ACC_AssetsHistory        
	-- WHERE AssetManagementID=@astID    
	--end  
	  
 --  --If Action is NEW then insert new Changes      
          
 --  INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,[Date],Vender,VendorID,NextServiceDate,Remarks,Amount,DebitAccount,CreditAccount,PostJV,DocID,VoucherNo,GUID,CreatedBy,CreatedDate,CostCenterID,DocumentName,DocPrefix,DocNumber)        
 --  SELECT X.value('@HistoryType','INT'),@astID,convert(float,X.value('@Date','datetime')) ,X.value('@Vendor','NVARCHAR(50)'),X.value('@VendorID','INT'),     
 --  convert(float,X.value('@NextStartDate','datetime')),X.value('@Remarks','NVARCHAR(500)') ,X.value('@Amount','Float'),        
 --  X.value('@DebitAccount','INT'),X.value('@CreditAccount','INT'),X.value('@PostJV','INT'), X.value('@DocID','INT'),   X.value('@VoucherNo','NVARCHAR(50)'),          
 --  newid(),@CreatedBy,@Dt, X.value('@CostCenterID','INT'), X.value('@DocumentName','nvarchar(50)') , X.value('@DocPrefix','nvarchar(50)'), X.value('@DocNumber','nvarchar(50)')       
 --  FROM @XML.nodes('/XML/MaintenanceGrid/Rows') as Data(X)
   
        
 --  INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,Vender,VendorID,PolicyType,PolicyNumber,StartDate,EndDate,Coverage,GUID,CreatedBy,CreatedDate)        
 --  SELECT X.value('@HistoryType','INT'),@astID,X.value('@Vendor','NVARCHAR(50)'),X.value('@VendorID','INT'),     
 --  X.value('@PolicyType','INT'),X.value('@PolicyNumber','NVARCHAR(50)'),convert(float,X.value('@StartDate','datetime')),
 --  convert(float,X.value('@EndDate','datetime')),X.value('@Coverage','NVARCHAR(50)'),        
 --  newid(),@CreatedBy,@Dt        
 --  FROM @XML.nodes('/XML/InsuranceGrid/Rows') as Data(X)   
   
 --  INSERT INTO ACC_AssetsHistory(HistoryTypeID,AssetManagementID,[Date],Amount,CurrentValue,Remarks,PostJV,DebitAccount,CreditAccount,GainAccount,LossAccount,DocID,VoucherNo,GUID,CreatedBy,CreatedDate,CostCenterID,DocumentName,DocPrefix,DocNumber)        
 --  SELECT X.value('@HistoryType','INT'),@astID,convert(float,X.value('@Date','datetime')),X.value('@Amount','Float'),X.value('@CurrentValue','Float'),   
 --  X.value('@Remarks','NVARCHAR(500)'),X.value('@PostJV','INT'), X.value('@DebitAccount','INT'),X.value('@CreditAccount','INT'),
 --   X.value('@GainAccount','INT'),X.value('@LossAccount','INT'), X.value('@DocID','INT'),   X.value('@VoucherNo','NVARCHAR(50)'),newid(),@CreatedBy,@Dt, X.value('@CostCenterID','INT'), X.value('@DocumentName','nvarchar(50)') , X.value('@DocPrefix','nvarchar(50)'), X.value('@DocNumber','nvarchar(50)')        
 --  FROM @XML.nodes('/XML/DisposeGrid/Rows') as Data(X)   
      
   
 -- END    
  
  --Inserts Multiple Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @XML=@NotesXML  
  
   --If Action is NEW then insert new Notes  
   INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
   GUID,CreatedBy,CreatedDate)  
   SELECT 72,72,@astID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
'),  
   newid(),@CreatedBy,@Dt  
   FROM @XML.nodes('/NotesXML/Row') as Data(X)  
   WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
  
   --If Action is MODIFY then update Notes  
   UPDATE COM_Notes  
   SET Note=Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
'),  
    GUID=newid(),  
    ModifiedBy=@CreatedBy,  
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
   FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
   GUID,CreatedBy,CreatedDate,IsDefaultImage,ColName)  
   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),72,72,@astID,  
   X.value('@GUID','NVARCHAR(50)'),@CreatedBy,@Dt,X.value('@IsDefaultImage','smallint') ,X.value('@ColName','nvarchar(50)') 
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
    ModifiedBy=@CreatedBy,  
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


	SELECT @AssetCCID=Convert(INT,isnull(Value,0)) FROM COM_CostCenterPreferences  WITH(nolock) 
	WHERE COSTCENTERID=72 and  Name='AssetDimension'      
	if(@AssetCCID>50000)
	begin
		declare @CCStatusID INT
		select top 1 @CCStatusID=statusid from com_status with(nolock) where costcenterid=@AssetCCID
	
		declare @NID INT, @CCIDBom INT
		select @NID = CCNodeID, @CCIDBom=CCID  from ACC_Assets with(nolock) where AssetID=@astID
		iF(@CCIDBom<>@AssetCCID)
		BEGIN
			if(@NID>0)
			begin 
			Update ACC_Assets set CCID=0, CCNodeID=0 where AssetID=@astID
			DECLARE @RET INT
				EXEC @RET = [dbo].[spCOM_DeleteCostCenter]
					@CostCenterID = @CCIDBom,
					@NodeID = @NID,
					@RoleID=1,
					@UserID = 1,
					@LangID = @LangID
			end	
			set @NID=0
			set @CCIDBom=0 
		END
		
		DECLARE @RefSelectedNodeID INT
		SELECT @RefSelectedNodeID=RefDimensionNodeID FROM COM_DocBridge WITH(NOLOCK)
		WHERE CostCenterID=72 AND RefDimensionID=@AssetCCID AND NodeID=@ParentID 
		SET @RefSelectedNodeID=ISNULL(@RefSelectedNodeID,1)
				
		declare @return_value int
		if(@NID is null or @NID =0)
		begin 
			set @AssetCode = replace(@AssetCode,'''','''''') 
			set @AssetName = replace(@AssetName,'''','''''')   
			EXEC @return_value = [dbo].[spCOM_SetCostCenter]
			@NodeID = 0,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
			@Code = @AssetCode,
			@Name = @AssetName,
			@AliasName=@AssetName,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML='',@AttachmentsXML=NULL,
			@CustomCostCenterFieldsQuery=NULL,@ContactsXML=null,@NotesXML=NULL,
			@CostCenterID = @AssetCCID,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1 , @CheckLink = 0

			 -- Link Dimension Mapping
			INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID,RefDimensionNodeID,CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)
			values(72, @astID,0,0,@AssetCCID,@return_value,'',newid(),@CreatedBy, @dt,'Asset') 
 		end
		else
		begin
			declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)
			declare @NodeidXML nvarchar(max) 
			select @Table=Tablename from adm_features with(nolock) where featureid=@AssetCCID
			declare @str nvarchar(max) 
			set @str='@Gid nvarchar(50) output' 
			set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' with(nolock) where NodeID='+convert(nvarchar,@NID)+')'
			exec sp_executesql @NodeidXML, @str, @Gid OUTPUT 
		  
			--select	@AssetName,@NID
			set @AssetCode = replace(@AssetCode,'''','''''') 
			set @AssetName = replace(@AssetName,'''','''''')   
			select @CCStatusID
			EXEC @return_value = [dbo].[spCOM_SetCostCenter]
			@NodeID = @NID,@SelectedNodeID = @RefSelectedNodeID,@IsGroup = @IsGroup,
			@Code = @AssetCode,
			@Name = @AssetName, 
			@AliasName=@AssetName,
			@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
			@CustomFieldsQuery=NULL,@AddressXML=null,@AttachmentsXML=NULL,
			@CustomCostCenterFieldsQuery=NULL,@ContactsXML=null,@NotesXML=NULL,
			@CostCenterID = @AssetCCID,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1, @CheckLink = 0 
 		end 
 		
 		--UPDATE LINK DATA
		if(@return_value>0 and @return_value<>'')
		begin
			Update ACC_Assets set CCID=@AssetCCID, CCNodeID=@return_value where AssetID=@astID
			DECLARE @CCMapSql nvarchar(max)
			set @CCMapSql='update COM_CCCCDATA  
			SET CCNID'+convert(nvarchar,(@AssetCCID-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  WHERE NodeID = '+convert(nvarchar,@astID) + ' AND CostCenterID = 72' 
			EXEC (@CCMapSql)
		
			Exec [spDOC_SetLinkDimension]
				@InvDocDetailsID=@astID, 
				@Costcenterid=72,         
				@DimCCID=@AssetCCID,
				@DimNodeID=@return_value,
				@UserID=@UserID,    
				@LangID=@LangID  
		end 
		
	end


	--INSERT INTO HISTROY   
	EXEC [spCOM_SaveHistory]  
		@CostCenterID =72,    
		@NodeID =@astID,
		@HistoryStatus =@HistoryStatus,
		@UserName=@CreatedBy,
		@DT=@DT
		
	--INSERT History COM_CCCCDataHistory
		if exists(SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=72 and Name='AuditTrial' and Value='True')
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
				WHERE  NodeID='+convert(nvarchar,@astID) + ' AND CostCenterID=72'
			END
			ELSE
			BEGIN
				set @CC=' INSERT INTO [COM_CCCCDataHistory](NodeHistoryID,'+@CommonCols+','+ISNULL(@HistoryCols,'')+')
				select  '+convert(nvarchar,@HistoryID)+','+@CommonCols+','+ISNULL(@HistoryColsInsert,'')
						
				set @CC=@CC+' FROM [COM_CCCCData] WITH(NOLOCK)
				WHERE  NodeID='+convert(nvarchar,@astID) + ' AND CostCenterID=72'
			END
			PRINT @CC
			exec sp_executesql @CC
		END
  
COMMIT TRANSACTION 
--ROLLBACK TRANSACTION         
SET NOCOUNT OFF;       
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=1        
RETURN @astID      
END TRY        
BEGIN CATCH        
 IF ERROR_NUMBER()=50000      
 BEGIN          
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1      
 END      
 ELSE      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=1      
 END      
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
END CATCH
GO
