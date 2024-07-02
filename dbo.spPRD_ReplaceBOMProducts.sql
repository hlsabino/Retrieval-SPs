USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_ReplaceBOMProducts]
	@BOMIDList [nvarchar](max),
	@ProdXML [nvarchar](max),
	@Suffix [nvarchar](100),
	@IsOverWrite [bit] = 0,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON     
 BEGIN TRANSACTION    
 BEGIN TRY    
    declare  @BOMID BIGINT,@BOMCode NVARCHAR(200),@BOMName NVARCHAR(500),@IsGroup bit,@SelectedNodeID int,@Date Datetime,@StageXML nvarchar(max) 
	DECLARE @Dt FLOAT, @lft bigint,@rgt bigint,@Selectedlft bigint,@Selectedrgt bigint,@HasAccess bit,@IsDuplicateNameAllowed bit,@IsBOMCodeAutoGen bit  ,@IsIgnoreSpace bit  ,   
		@Depth int,@ParentID bigint,@SelectedIsGroup int , @XML XML,@ParentCode nvarchar(200),@SQL nvarchar(max)  ,@ProductionXML XML   ,@BOMCCID bigint,@HistoryStatus NVARCHAR(50)
       
	set @HistoryStatus='Add'
	SET @Dt=convert(float,getdate())
    SELECT @BOMCCID=Convert(bigint,isnull(Value,0)) FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=76 and  Name='BomDimension'      

	declare @Tbl as table(ID int identity(1,1),BOMID bigint)
	
	insert into @Tbl
	exec SPSplitString @BOMIDList,','

	declare @LI int,@LCNT int,@StageIDCnt int
	select @LI=1,@LCNT=count(*) from @Tbl
	
IF @IsOverWrite=1
BEGIN
	WHILE(@LI<=@LCNT)
	BEGIN
		SELECT @SelectedNodeID=BOMID from @Tbl where ID=@LI
		
		SET @XML=@ProdXML
		--INSERT INTO [PRD_BOMProducts]([BOMID] ,StageID,[ProductUse],[ProductID],FilterOn,[Quantity],[UOMID],[UnitPrice]
		--,[ExchgRT],[CurrencyID],[Value],[Wastage],[CreatedBy],[CreatedDate],IncInFinalCost,IncInStageCost,AutoStage,Remarks) 
		update PRD_BOMProducts
		set ProductID=isnull(X.value('@New','bigint'),P.ProductID)
		from PRD_BOMProducts P with(nolock)
		left join @XML.nodes('/XML/Row') as Data(X) on X.value('@Old','int')=P.ProductID
		where P.BOMID=@SelectedNodeID

		SET @LI=@LI+1
	END
	SET @BOMID=1
END
ELSE
BEGIN
	WHILE(@LI<=@LCNT)
	BEGIN
		SELECT @SelectedNodeID=BOMID from @Tbl where ID=@LI
		
		--To Set Left,Right And Depth of Record      
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth      
		from PRD_BillOfMaterial with(NOLOCK) where BOMID=@SelectedNodeID      
	          
		--IF No Record Selected or Record Doesn't Exist      
		if(@SelectedIsGroup is null)
		 continue;
	                
		if(@SelectedIsGroup = 1)--Adding Node Under the Group      
		 BEGIN      
		  UPDATE [PRD_BillOfMaterial] SET rgt = rgt + 2 WHERE rgt > @Selectedlft;      
		  UPDATE [PRD_BillOfMaterial] SET lft = lft + 2 WHERE lft > @Selectedlft;      
		  set @lft =  @Selectedlft + 1      
		  set @rgt = @Selectedlft + 2      
		  set @ParentID = @SelectedNodeID      
		  set @Depth = @Depth + 1      
		 END      
		else if(@SelectedIsGroup = 0)--Adding Node at Same level      
		 BEGIN      
		  UPDATE [PRD_BillOfMaterial] SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;      
		  UPDATE [PRD_BillOfMaterial] SET lft = lft + 2 WHERE lft > @Selectedrgt;      
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
	    
	/*	--GENERATE CODE      
		IF @IsBOMCodeAutoGen IS NOT NULL AND @IsBOMCodeAutoGen=1 AND @BOMID=0      
		BEGIN      
		 SELECT @ParentCode=[BOMCode]      
		 FROM [PRD_BillOfMaterial] WITH(NOLOCK) WHERE BOMID=@ParentID        
	      
		 --CALL AUTOCODEGEN      
		 EXEC [spCOM_SetCode] 76,@ParentCode,@BOMCode OUTPUT        
		END      
    */
		select @BOMCode=BOMCode+@Suffix,@BOMName=BOMName+@Suffix
        from PRD_BillOfMaterial with(nolock) where BOMID=@SelectedNodeID
        
		 INSERT INTO PRD_BillOfMaterial    
		  (BOMCode,BOMDate,BOMName    
		  ,StatusId
		  ,BOMTypeID    
		  ,BOMTypeName    
		  ,ProductID,UOMID,FPQty,Packing
		  ,DivisionID    
		  ,LocationID    
		  ,Description    
		  ,Depth    
		  ,ParentID    
		  ,lft    
		  ,rgt    
		  ,IsGroup    
		  ,CompanyGUID    
		  ,GUID    
		  ,CreatedBy    
		  ,CreatedDate)    
		select
		   BOMCode+@Suffix,BOMDate,BOMName+@Suffix
		  ,StatusId,BOMTypeID,BOMTypeName
		  ,ProductID,UOMID,FPQty,Packing
		  ,DivisionID    
		  ,LocationID    
		  ,Description
		  ,@Depth    
		  ,@ParentID    
		  ,@lft    
		  ,@rgt    
		  ,IsGroup    
		  ,CompanyGUID    
		  ,newid()    
		  ,@UserName    
		  ,@Dt
        from PRD_BillOfMaterial with(nolock) where BOMID=@SelectedNodeID
		SET @BOMID=SCOPE_IDENTITY()     
    
		set @SQL=''
		select @SQL =@SQL+','+a.name from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='PRD_BillOfMaterialExtended' and (a.name!='BOMID')

		SET @SQL='
INSERT INTO PRD_BillOfMaterialExtended(BOMID'+@SQL+')    
select '+convert(nvarchar,@BOMID)+@SQL+'
from PRD_BillOfMaterialExtended with(nolock)
where BOMID='+convert(nvarchar(max),@SelectedNodeID)
		--print(@SQL)
		exec(@SQL)


		set @SQL=''
		select @SQL =@SQL+','+a.name from sys.columns a
		join sys.tables b on a.object_id=b.object_id
		where b.name='COM_CCCCData' and (a.name!='NodeID' and a.name!='CCCCDataID')

		SET @SQL='
INSERT INTO COM_CCCCData(NodeID'+@SQL+')    
select '+convert(nvarchar(max),@BOMID)+@SQL+'
from COM_CCCCData with(nolock)
where CostCenterID=76 and NodeID='+convert(nvarchar(max),@SelectedNodeID)
		--print(@SQL)
		exec(@SQL)
        
		set @StageXML=''
		set @StageIDCnt=-1
		select @StageXML=@StageXML+'<Stage ID="'+convert(nvarchar,@StageIDCnt)+'" StageNodeID="'+convert(nvarchar,StageNodeID)+'" Parent="'+convert(nvarchar,ParentID)+'" lft="'+convert(nvarchar,lft)+'" Depth="'+convert(nvarchar,Depth)+'" OldBOMStageID="'+convert(nvarchar,StageID)+'" />' 
		,@StageIDCnt=@StageIDCnt-1
		from PRD_BOMStages with(nolock) where BOMID=@SelectedNodeID
		if @StageXML!=''
			set @StageXML='<Stages>'+@StageXML+'</Stages>'
        	--Stages Inserting
        --	select 2333
		DECLARE @TblStages AS TABLE(ID INT IDENTITY(1,1),StageID INT,StageNodeID BIGINT,Parent INT,lft INT,Depth INT,NewStageID INT,OldBOMStageID int)
		DECLARE @StageID INT,@I INT,@CNT INT
		
		SET @XML=@StageXML
		INSERT INTO @TblStages(StageID,StageNodeID,Parent,lft,Depth,NewStageID,OldBOMStageID)
		SELECT X.value('@ID','int'),X.value('@StageNodeID','bigint'),X.value('@Parent','int'),
			X.value('@lft','int'),X.value('@Depth','int'),X.value('@ID','int'),X.value('@OldBOMStageID','int')
		FROM @XML.nodes('/Stages/Stage') as Data(X)      
        
        update T1
        set T1.Parent=T2.StageID from @TblStages T1
        join @TblStages T2 on T1.Parent=T2.OldBOMStageID
        where T1.Parent>1

		SELECT @I=1,@CNT=COUNT(*) FROM @TblStages
		
		WHILE(@I<=@CNT)
		BEGIN
			IF (SELECT StageID FROM @TblStages WHERE ID=@I)<0
			BEGIN
				INSERT INTO [PRD_BOMStages](BOMID,StageNodeID,[ParentID],[lft],[Depth])
				SELECT @BOMID,StageNodeID,Parent,lft,Depth FROM @TblStages WHERE ID=@I
				SET @StageID=SCOPE_IDENTITY()
				
				UPDATE @TblStages 
				SET NewStageID=@StageID
				WHERE ID=@I
				
				UPDATE @TblStages 
				SET Parent=@StageID
				WHERE Parent=(select StageID from @TblStages WHERE ID=@I)
			END
			
			SET @I=@I+1
		END
		
		UPDATE PRD_BOMStages
		SET StageNodeID=TS.StageNodeID,ParentID=TS.Parent,lft=TS.lft,Depth=TS.Depth
		FROM PRD_BOMStages S INNER JOIN @TblStages TS ON TS.StageID>0 AND TS.StageID=S.StageID

		--select * from PRD_BOMStages where BOMID=@BOMID
		--select * from @TblStages
		
		SET @XML=@ProdXML
		INSERT INTO [PRD_BOMProducts]([BOMID] ,StageID,[ProductUse],[ProductID],FilterOn,[Quantity],[UOMID],[UnitPrice]
		,[ExchgRT],[CurrencyID],[Value],[Wastage],[CreatedBy],[CreatedDate],IncInFinalCost,IncInStageCost,AutoStage,Remarks) 
		select @BOMID,TS.NewStageID,[ProductUse],isnull(X.value('@New','int'),[ProductID]),FilterOn,[Quantity],[UOMID],[UnitPrice]
		,[ExchgRT],[CurrencyID],[Value],[Wastage],[CreatedBy],[CreatedDate],IncInFinalCost,IncInStageCost,AutoStage,Remarks
		from PRD_BOMProducts P with(nolock)
		inner join @TblStages TS ON TS.OldBOMStageID=P.StageID
		left join @XML.nodes('/XML/Row') as Data(X) on X.value('@Old','int')=P.ProductID
		where P.BOMID=@SelectedNodeID
		order by P.BOMProductID
		
		INSERT INTO [PRD_Expenses]([BOMID],StageID,[ResourceID],Name,[CreditAccountID],[DebitAccountID]    
	   ,[ExchgRT],[CurrencyID],[Value],[CreatedBy],[CreatedDate],IncInFinalCost,IncInStageCost)    
		SELECT @BOMID,TS.NewStageID,[ResourceID],Name,[CreditAccountID],[DebitAccountID]    
	   ,[ExchgRT],[CurrencyID],[Value],[CreatedBy],[CreatedDate],IncInFinalCost,IncInStageCost
		FROM [PRD_Expenses] E with(nolock)
		inner join @TblStages TS ON TS.OldBOMStageID=E.StageID
		where E.BOMID=@SelectedNodeID
		order by E.ExpenseID
		
		---BOM Resources
		INSERT INTO [PRD_BOMResources] ([BOMID],StageID,[ResourceID],[Hours]    
		,[ExchgRT],[CurrencyID],[Value],[CreatedBy],[CreatedDate],IncInFinalCost,IncInStageCost)    
		SELECT @BOMID,TS.NewStageID,[ResourceID],[Hours]    
		,[ExchgRT],[CurrencyID],[Value],[CreatedBy],[CreatedDate],IncInFinalCost,IncInStageCost   
		FROM [PRD_BOMResources] R with(nolock)
		inner join @TblStages TS ON TS.OldBOMStageID=R.StageID
		where R.BOMID=@SelectedNodeID
		order by R.BOMResourceID
		
		 insert into PRD_ProductionMethod([SequenceNo],[BOMID]
           ,[MOID]
           ,[Particulars]
           ,[CompanyGUID]
           ,[GUID]
           ,[CreatedBy]
           ,[CreatedDate]
           ,[ModifiedBy]
           ,[ModifiedDate])
		select [SequenceNo],@BOMID
           ,[MOID]
           ,[Particulars]
           ,[CompanyGUID]
           ,[GUID]
           ,[CreatedBy]
           ,[CreatedDate]
           ,[ModifiedBy]
           ,[ModifiedDate]
		from PRD_ProductionMethod
		where BOMID=@SelectedNodeID
		order by [SequenceNo]
	
		if(@BOMCCID>50000)
		begin
			declare @CCStatusID bigint
			set @CCStatusID = (select top 1 statusid from com_status WITH(nolock) where costcenterid=@BOMCCID)
			declare @NID bigint, @CCIDBom bigint
			select @NID = CCNodeID, @CCIDBom=CCID  from PRD_BillOfMaterial WITH(nolock) where BOMID=@BOMID
			iF(@CCIDBom<>@BOMCCID)
			BEGIN
				if(@NID>0)
				begin 
				Update PRD_BillOfMaterial set CCID=0, CCNodeID=0 where BOMID=@BOMID
				DECLARE @RET INT
					EXEC	@RET = [dbo].[spCOM_DeleteCostCenter]
						@CostCenterID = @CCIDBom,
						@NodeID = @NID,
						@RoleID=1,
						@UserID = @UserID,
						@LangID = @LangID
				end	
				set @NID=0
				set @CCIDBom=0 
			END
			declare @return_value int
			if(@NID is null or @NID =0)
			begin 
				EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
				@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
				@Code = @BOMCode,
				@Name = @BOMName,
				@AliasName=@BOMName,
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
				@CustomFieldsQuery=NULL,@AddressXML='',@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=null,@NotesXML=NULL,
				@CostCenterID = @BOMCCID,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName='admin',@RoleID=1,@UserID=1 , @CheckLink = 0
				
				 -- Link Dimension Mapping
				INSERT INTO COM_DocBridge (CostCenterID, NodeID,InvDocID, AccDocID, RefDimensionID  , RefDimensionNodeID ,  CompanyGUID, guid, Createdby, CreatedDate,Abbreviation)
				values(76, @BOMID,0,0,@BOMCCID,@return_value,'',newid(),@UserName, @dt,'BOM')

 			end
			else
			begin
				declare @Gid nvarchar(50) , @Table nvarchar(100), @CGid nvarchar(50)
				declare @NodeidXML nvarchar(max) 
				select @Table=Tablename from adm_features WITH(nolock) where featureid=@BOMCCID
				declare @str nvarchar(max) 
				set @str='@Gid nvarchar(50) output' 
				set @NodeidXML='set @Gid= (select GUID from '+convert(nvarchar,@Table)+' WITH(nolock) where NodeID='+convert(nvarchar,@NID)+')'
					exec sp_executesql @NodeidXML, @str, @Gid OUTPUT 
					
				--select	@Gid,@NID
				EXEC	@return_value = [dbo].[spCOM_SetCostCenter]
				@NodeID = @NID,@SelectedNodeID = 1,@IsGroup = 0,
				@Code = @BOMCode,
				@Name = @BOMName,
				@AliasName=@BOMName,
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
				@CustomFieldsQuery=NULL,@AddressXML=null,@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=null,@NotesXML=NULL,
				@CostCenterID = @BOMCCID,@CompanyGUID=@CompanyGUID,@GUID=@Gid,@UserName='admin',@RoleID=1,@UserID=1, @CheckLink = 0
 			end 
			
			Update PRD_BillOfMaterial set CCID=@BOMCCID, CCNodeID=@return_value where BOMID=@BOMID
			DECLARE @CCMapSql nvarchar(max)
			set @CCMapSql='update COM_CCCCDATA  
			SET CCNID'+convert(nvarchar,(@BOMCCID-50000))+'='+CONVERT(NVARCHAR,@return_value)+'  WHERE NodeID = '+convert(nvarchar,@BOMID) + ' AND CostCenterID = 76' 
			EXEC (@CCMapSql)
			
			Exec [spDOC_SetLinkDimension]
				@InvDocDetailsID=@BOMID, 
				@Costcenterid=76,         
				@DimCCID=@BOMCCID,
				@DimNodeID=@return_value,
				@UserID=@UserID,    
				@LangID=@LangID    

		end
		
		if exists(SELECT Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=76 and Name='AuditTrial' and Value='True')
		begin
			exec @return_value=spADM_AuditData 2,76,@BOMID,@HistoryStatus,'',1,1
			--if @return_value!=1
			--	set @ExtendedColsXML=' With Audit Trial Error'
		end
     
		SET @LI=@LI+1
	END
END
  
 COMMIT TRANSACTION    
--ROLLBACK TRANSACTION    

 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID      
SET NOCOUNT OFF;        
RETURN @BOMID    
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
