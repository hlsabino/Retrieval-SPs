USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_SetManufacturingOrder]
	@MFGOrderID [bigint],
	@OrderNumber [nvarchar](200),
	@OrderTypeID [int],
	@OrderTypeName [nvarchar](50),
	@StatusID [int],
	@OrderDate [datetime],
	@OrderName [nvarchar](50),
	@SelectedNodeID [bigint],
	@IsGroup [bit],
	@MOrderBOMs [nvarchar](max),
	@ProductionMethodXML [nvarchar](max),
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@AttachmentsXML [nvarchar](max),
	@NotesXML [nvarchar](max),
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  DECLARE @Dt float,@TempGuid nvarchar(50),@HasAccess bit,@IsAccountCodeAutoGen bit  
  DECLARE @UpdateSql nvarchar(max),@MFGOrderWOID bigint,@MFGOrderBOMID bigint
  DECLARE @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@Depth int,@ParentID bigint  
  DECLARE @SelectedIsGroup bit  
  DECLARE @XML xml,@WOXML xml,@WODXML xml,@IssueXML nvarchar(max),@ProductionXML XML
   Declare @Count int
  --User acces check FOR ACCOUNTS  
  IF @MFGOrderID=0  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,78,1)  
  END  
  ELSE  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,78,3)  
  END  
  
  IF @HasAccess=0  
  BEGIN  
   RAISERROR('-105',16,1)  
  END  
  
  --User acces check FOR Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,78,8)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  
  
  --User acces check FOR Attachments  
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,78,12)  
  
   IF @HasAccess=0  
   BEGIN  
    RAISERROR('-105',16,1)  
   END  
  END  

    IF @MFGOrderID=0  
    BEGIN  
     IF EXISTS (SELECT MFGOrderID FROM PRD_MFGOrder WITH(nolock) WHERE OrderNumber=@OrderNumber)  
     BEGIN  
      RAISERROR('-209',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT MFGOrderID FROM PRD_MFGOrder WITH(nolock) WHERE OrderNumber=@OrderNumber AND MFGOrderID <> @MFGOrderID)  
     BEGIN  
      RAISERROR('-209',16,1)  
     END  
    END  
   
  --GETTING PREFERENCE  
   SELECT @IsAccountCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=78 and  Name='CodeAutoGen'  
    
  
  SET @Dt=convert(float,getdate())--Setting Current Date  
  
  IF @MFGOrderID=0--------START INSERT RECORD-----------  
  BEGIN--CREATE MO--  
    --To Set Left,Right And Depth of Record  
    SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
    from PRD_MFGOrder with(NOLOCK) where MFGOrderID=@SelectedNodeID  
   
    --IF No Record Selected or Record Doesn't Exist  
    if(@SelectedIsGroup is null)   
     select @SelectedNodeID=MFGOrderID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
     from PRD_MFGOrder with(NOLOCK) where ParentID =0  
         
    if(@SelectedIsGroup = 1)--Adding Node Under the Group  
     BEGIN  
      UPDATE PRD_MFGOrder SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
      UPDATE PRD_MFGOrder SET lft = lft + 2 WHERE lft > @Selectedlft;  
      set @lft =  @Selectedlft + 1  
      set @rgt = @Selectedlft + 2  
      set @ParentID = @SelectedNodeID  
      set @Depth = @Depth + 1  
     END  
    else if(@SelectedIsGroup = 0)--Adding Node at Same level  
     BEGIN  
      UPDATE PRD_MFGOrder SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
      UPDATE PRD_MFGOrder SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
    IF @IsAccountCodeAutoGen IS NOT NULL AND @IsAccountCodeAutoGen=1  
    BEGIN     
		 --CALL AUTOCODEGEN  
		 EXEC [spCOM_SetCode] 78,'Parent',@OrderNumber OUTPUT    
    END  
  
    -- Insert statements for procedure here  
    INSERT INTO PRD_MFGOrder  
       (OrderNumber,  
       OrderTypeID ,  
       OrderTypeName,
       [StatusID],  
       OrderDate,
	   OrderName,
       [Depth],  
       [ParentID],  
       [lft],  
       [rgt],  
       [IsGroup],
       [CompanyGUID],  
       [GUID],  
       [CreatedBy],  
       [CreatedDate])  
       VALUES  
       (@OrderNumber,  
       @OrderTypeID,  
       @OrderTypeName,  
       @StatusID,  
       CONVERT(float,@OrderDate),
	   @OrderName,
       @Depth,  
       @ParentID,  
       @lft,  
       @rgt,  
       @IsGroup, 
       @CompanyGUID,  
       newid(),  
       @UserName,  
       @Dt)  
    --To get inserted record primary key  
    SET @MFGOrderID=SCOPE_IDENTITY()  
   
    --Handling of Extended Table  
    INSERT INTO PRD_MFGOrderExtd([MFGOrderID],[CreatedBy],[CreatedDate])  
    VALUES(@MFGOrderID, @UserName, @Dt)    
  
	INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
    VALUES(78,@MFGOrderID,newid(),  @UserName, @Dt)         
      
   END--------END INSERT RECORD-----------  
  ELSE--------START UPDATE RECORD-----------  
  BEGIN     
  
   SELECT @TempGuid=[GUID] from PRD_MFGOrder  WITH(NOLOCK)   
   WHERE [MFGOrderID]=@MFGOrderID  
  
   --IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ    
   --BEGIN    
   --    RAISERROR('-101',16,1)   
   --END    
      
	if exists(select OrderNumber from PRD_MFGOrder where OrderNumber=@OrderNumber And MFGOrderID<>@MFGOrderID)
		begin
		 RAISERROR('-209',16,1)
		end
		else
		Begin 
		 UPDATE PRD_MFGOrder  
       SET OrderNumber=@OrderNumber,  
       OrderTypeID =@OrderTypeID,  
       OrderTypeName=@OrderTypeName,
       [StatusID]=@StatusID,  
       OrderDate= CONVERT(float,@OrderDate),
       [ModifiedBy] = @UserName  
       ,[ModifiedDate] = @Dt
     WHERE [MFGOrderID]=@MFGOrderID  
     
       SET @XML=@MOrderBOMs  
       
       
        delete from [PRD_MOWODetails]      
		where MOWOProductID not in(select  X.value('@MOWOProductID','BIGINT') FROM 
		@XML.nodes('/XML/Row/WOXML/Row/WODetails/Row') as Data(X)  
		where X.value('@MOWOProductID','BIGINT')>0)  and
		MFGOrderWOID in (select MFGOrderWOID from PRD_MFGOrderWOs where MFGOrderBOMID in 
		(select MFGOrderBOMID from PRD_MFGOrderBOMs where MFGOrderID=@MFGOrderID))
  
		delete from [PRD_MFGOrderWOs]      
		where MFGOrderWOID not in(select  X.value('@MFGOrderWOID','BIGINT') FROM 
		@XML.nodes('/XML/Row/WOXML/Row') as Data(X)  
		where X.value('@MFGOrderWOID','BIGINT')>0)  and
		MFGOrderBOMID in (select MFGOrderBOMID from PRD_MFGOrderBOMs where MFGOrderID=@MFGOrderID)
		End
		
		
  END  
   
  
  --Update Extra fields  
  set @UpdateSql='update [PRD_MFGOrderExtd]  
  SET '+@CustomFieldsQuery+'[ModifiedBy] ='''+ @UserName  
    +''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE MFGOrderID='+convert(nvarchar,@MFGOrderID)  
 
  exec(@UpdateSql)  

    set @UpdateSql='update COM_CCCCDATA  
	SET '+@CustomCostCenterFieldsQuery+'[ModifiedBy] ='''+ @UserName+''',[ModifiedDate] =' + convert(nvarchar,@Dt) +' WHERE NodeID = '+convert(nvarchar,@MFGOrderID) + ' AND CostCenterID = 78 ' 
   
  exec(@UpdateSql)  
  
  
  SET @XML=@MOrderBOMs  
  IF (@MOrderBOMs IS NOT NULL AND @MOrderBOMs <> '')  
  BEGIN  
   
   declare @Boms table(id int identity(1,1),MOBOMID bigint,BID bigint,qty float,dID bigint,DType int,WorkOrders nvarchar(max))
   declare @WOs table(id int identity(1,1),WOID bigint,MOBOMID bigint,WONo nvarchar(50),StageNO int,Status int,loc bigint,SDate  float,edate  float,aedate float,qty float,did bigint,DocType int,Details nvarchar(max),IssueXML nvarchar(max))
   Declare @i int,@cnt int,@ii int,@ccnt int,@MOBOMID  bigint
   
   insert into @Boms
   select X.value('@MFGOrderBOMID','bigint'),X.value('@BOMID','int'),X.value('@Quantity','float')
           ,X.value('@DocID','bigint'),X.value('@LinkedDocTypeID','int'),CONVERT(NVARCHAR(MAX), X.query('WOXML'))  
			FROM @XML.nodes('/XML/Row') as Data(X)  
     
    select @i=0,@cnt=count(id) from @Boms
    while(@i<@cnt)
    begin
		set @i=@i+1
		select @WOXML=WorkOrders,@MOBOMID  =MOBOMID  from @Boms where id=@i
		 		
		if(@MOBOMID=0)
		begin
			INSERT INTO [PRD_MFGOrderBOMs]
			   ([MFGOrderID]
			   ,[BOMID]
			   ,[Quantity]
			   ,[DocID]
			   ,[LinkedDocTypeID]
			   ,[CompanyGUID]
			   ,[GUID]
			   ,[CreatedBy]
			   ,[CreatedDate])		
			select @MFGOrderID,BID,qty,dID,DType,@CompanyGUID,NEWID(),@UserName,@Dt
			from @Boms where id=@i	
			
			set @MOBOMID=SCOPE_IDENTITY()  				
		end
		else
		begin
			update [PRD_MFGOrderBOMs]
				set [BOMID]=BID
			   ,[Quantity]=qty
			   ,[DocID]=dID
			   ,[LinkedDocTypeID]=DType
			   from @Boms where id=@i and MFGOrderBOMID	=@MOBOMID	
		end
		
		delete from @WOs
	   insert into @WOs
	   select X.value('@MFGOrderWOID','bigint'),X.value('@BOMID','int'),X.value('@WONumber','nvarchar(50)'),X.value('@Stage','int'),X.value('@StatusID','int'),X.value('@Location','bigint'),			   
			   convert(float,X.value('@StartDate','datetime')),convert(float,X.value('@EstEndDate','datetime')),convert(float,X.value('@ActualEndDate','datetime'))
			   ,X.value('@Quantity','float'),X.value('@DocID','bigint'),X.value('@DocTypeID','int'), CONVERT(NVARCHAR(MAX),X.query('WODetails')), CONVERT(NVARCHAR(MAX),X.query('DocumentXML'))  
				FROM @WOXML.nodes('/WOXML/Row') as Data(X)  
	     
	    
		select @ii=min(id),@ccnt=max(id) from @WOs
		while(@ii<=@ccnt)
		begin
		
		select @WODXML=Details ,@MFGOrderWOID=WOID  from @WOs where id=@ii
	 		
		if(@MFGOrderWOID=0)
		begin
			INSERT INTO [PRD_MFGOrderWOs]
           ([MFGOrderBOMID]
           ,[WONumber]
           ,[Stage]
           ,[Quantity]
           ,[StatusID]
           ,[StartDate]
           ,[EstEndDate]
           ,[ActualEndDate]
           ,[DocID]
           ,[DocTypeID]
           ,[CompanyGUID]
           ,[GUID]
           ,[CreatedBy]
           ,[CreatedDate],Location)
			select @MOBOMID,WONo,StageNO,qty,Status,SDate,edate,aedate,
			did,DocType,@CompanyGUID,NEWID(),@UserName,@Dt,loc
			from @WOs where id=@ii	
			
			set @MFGOrderWOID=SCOPE_IDENTITY()  	
		end
		else
		begin
			update [PRD_MFGOrderWOs]
			set[WONumber]=WONo
           ,[Stage]=StageNO
           ,[Quantity]=qty
           ,[StatusID]=Status
           ,[StartDate]=SDate
           ,[EstEndDate]=edate
           ,[ActualEndDate]=aedate
		   ,[DocID]=did
		   ,[DocTypeID]=DocType
		   ,Location=loc
		   from @WOs where id=@ii and MFGOrderWOID	=@MFGOrderWOID	
		end
		
		 
		INSERT INTO [PRD_MOWODetails]
           ([MFGOrderWOID]
           ,[WODetailsID]
           ,[BOMProductID]
           ,[ProdQuantity]
           ,[Wastage]
           ,[ReturnQty]
           ,[NetQuantity]
           ,[ExpenseID]
           ,[ExchgRT]
           ,[Amount]
           ,[ReturnAmount]
           ,[ResourceID]
           ,[StartDateTime]
           ,[EndDateTime]
           ,[Hours]
           ,[DocID]
           ,[DocTypeID]
           ,[Quantity]
           ,[RCTQuantity]
           ,[CompanyGUID]
           ,[GUID]
           ,[CreatedBy]
           ,[CreatedDate])
     select @MFGOrderWOID
           ,X.value('@WODetailsID','int')
           ,X.value('@BOMProductID','int')
           ,X.value('@ProdQuantity','float')
           ,X.value('@Wastage','float')
           ,X.value('@ReturnQty','float')
           ,X.value('@NetQuantity','float')
           ,X.value('@ExpenseID','int')
           ,X.value('@ExchgRT','float')
           ,X.value('@Amount','float')
           ,X.value('@ReturnAmount','float')
           ,X.value('@ResourceID','int')
           ,convert(float,X.value('@StartDateTime','datetime'))
           ,convert(float,X.value('@EndDateTime','datetime'))
           ,X.value('@Hours','float')
           ,X.value('@DocID','int')
           ,X.value('@DocTypeID','int')
           ,X.value('@Quantity','float')
           ,X.value('@RCTQuantity','float'),@CompanyGUID,NEWID(),@UserName,@Dt
			FROM @WODXML.nodes('/WODetails/Row') as Data(X)  
			where X.value('@MOWOProductID','BIGINT')=0
	      
	     
			update [PRD_MOWODetails] set
           [WODetailsID]=X.value('@WODetailsID','int')
           ,[BOMProductID]=X.value('@BOMProductID','int')
           ,[ProdQuantity]=X.value('@ProdQuantity','float')
           ,[Wastage]=X.value('@Wastage','float')
           ,[ReturnQty]=X.value('@ReturnQty','float')
           ,[NetQuantity]=X.value('@NetQuantity','float')
           ,[ExpenseID]=X.value('@ExpenseID','int')
           ,[ExchgRT]=X.value('@ExchgRT','float')
           ,[Amount]=X.value('@Amount','float')
           ,[ReturnAmount]=X.value('@ReturnAmount','float')
           ,[ResourceID]=X.value('@ResourceID','int')
           ,[StartDateTime]=convert(float,X.value('@StartDateTime','datetime'))
           ,[EndDateTime]=convert(float,X.value('@EndDateTime','datetime'))
           ,[Hours]=X.value('@Hours','float')
           ,[DocID]=X.value('@DocID','int')
           ,[DocTypeID]=X.value('@DocTypeID','int')
           ,[Quantity]=X.value('@Quantity','float')
           ,[RCTQuantity]=X.value('@RCTQuantity','float')
           ,modifiedby=@UserName,
           modifieddate=@Dt
			FROM @WODXML.nodes('/WODetails/Row') as Data(X)  
			where X.value('@MOWOProductID','BIGINT')=[PRD_MOWODetails].MOWOProductID and X.value('@MOWOProductID','BIGINT')>0
	    
			set @ii=@ii+1		
		end
		
    end
   
    
  
   
   
  end
   
  --Inserts Multiple Notes  
  IF (@NotesXML IS NOT NULL AND @NotesXML <> '')  
  BEGIN  
   SET @XML=@NotesXML  
  
   --If Action is NEW then insert new Notes  
   INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,     
   GUID,CreatedBy,CreatedDate)  
   SELECT 78,78,@MFGOrderID,Replace(X.value('@Note','NVARCHAR(MAX)'),'@~','
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
   ON convert(bigint,X.value('@NoteID','bigint'))=C.NoteID  
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
  
   --If Action is DELETE then delete Notes  
   DELETE FROM COM_Notes  
   WHERE NoteID IN(SELECT X.value('@NoteID','bigint')  
    FROM @XML.nodes('/NotesXML/Row') as Data(X)  
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
  
  END  
  
  --Inserts Multiple Attachments  
  IF (@AttachmentsXML IS NOT NULL AND @AttachmentsXML <> '')  
  BEGIN  
   SET @XML=@AttachmentsXML  
  
   INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
   FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,  
   GUID,CreatedBy,CreatedDate)  
   SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
   X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),78,78,@MFGOrderID,  
   X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt  
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
    ModifiedBy=@UserName,  
    ModifiedDate=@Dt  
   FROM COM_Files C   
   INNER JOIN @XML.nodes('/AttachmentsXML/Row') as Data(X)    
   ON convert(bigint,X.value('@AttachmentID','bigint'))=C.FileID  
   WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  
  
   --If Action is DELETE then delete Attachments  
   DELETE FROM COM_Files  
   WHERE FileID IN(SELECT X.value('@AttachmentID','bigint')  
    FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)  
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
  END  


  IF (@ProductionMethodXML IS NOT NULL AND @ProductionMethodXML <> '')  
  BEGIN 
	set @ProductionXML=@ProductionMethodXML

	DELETE FROM PRD_ProductionMethod WHERE MOID=@MFGOrderID

	INSERT INTO PRD_ProductionMethod ([SequenceNo],[BOMID]
           ,[MOID]
           ,[Particulars]
           ,[CompanyGUID]
           ,[GUID]
           ,[CreatedBy]
           ,[CreatedDate]
           ,[ModifiedBy]
           ,[ModifiedDate])
	select X.value('@SequenceNo','BIGINT'),X.value('@BOMID','BIGINT'),@MFGOrderID,X.value('@Particulars','nvarchar(200)'),@CompanyGUID  
      ,newid()  
      ,@UserName  
      ,convert(float,getdate())
      ,@UserName  
      ,convert(float,getdate())
       from @ProductionXML.nodes('/XML/Row') as data(X) 
  end
  
COMMIT TRANSACTION   
 
SELECT *,CONVERT(datetime,OrderDate) MODate FROM PRD_MFGOrder WITH(nolock) WHERE MFGOrderID=@MFGOrderID  
SELECT M.BOMID,M.MFGOrderBOMID FROM  [PRD_MFGOrderBOMs] M WITH(NOLOCK)
WHERE MFGOrderID=@MFGOrderID
      
SELECT M.BOMID,W.MFGOrderWOID,W.WONumber FROM  [PRD_MFGOrderWOs] W WITH(NOLOCK)
left join [PRD_MFGOrderBOMs] M WITH(NOLOCK) on M.MFGOrderBOMID=W.MFGOrderBOMID
WHERE M.MFGOrderID=@MFGOrderID

SELECT [MOWOProductID],W.[MFGOrderWOID],[WODetailsID],W.[BOMProductID],W.[ExpenseID],W.ResourceID,W.[DocID]
FROM  [PRD_MOWODetails] W WITH(NOLOCK)
left join [PRD_MFGOrderWOs] Wo WITH(NOLOCK) on Wo.MFGOrderWOID=W.MFGOrderWOID
left join [PRD_MFGOrderBOMs] M WITH(NOLOCK) on M.MFGOrderBOMID=Wo.MFGOrderBOMID  	
WHERE M.MFGOrderID=@MFGOrderID
	
	
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @MFGOrderID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT * FROM PRD_MFGOrder WITH(nolock) WHERE MFGOrderID=@MFGOrderID    
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
