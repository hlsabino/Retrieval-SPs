USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetBudgetScreenDetails]
	@BudgetXML [nvarchar](max) = null,
	@NumDimensions [int],
	@CCList [nvarchar](max) = null,
	@RelationsXML [nvarchar](max) = null,
	@BudgetYear [datetime],
	@BudgetName [nvarchar](50) = null,
	@BudgetTypeID [int] = 0,
	@BudgetTypeName [nvarchar](50) = null,
	@StatusID [int],
	@IsQtyBudget [int],
	@BudgetID [int] = 0,
	@SelectedNodeID [int] = 0,
	@IsGroup [bit],
	@QtyType [int],
	@ChkBudgetOnlyForDefnAccounts [bit],
	@NonAccDocs [nvarchar](max) = null,
	@NonAccDocsField [nvarchar](50) = null,
	@InvAccDocs [nvarchar](max) = null,
	@InvAccDocsField [nvarchar](50) = null,
	@AccountTypes [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY
SET NOCOUNT ON;  
	
	declare @XML xml,@DT float
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT  
	DECLARE @SelectedIsGroup bit,@SQL nvarchar(max)
	
	IF @BudgetID=0  
    BEGIN  
     IF EXISTS (SELECT BudgetDefID FROM COM_BudgetDef WITH(nolock) WHERE replace(BudgetName,' ','')=replace(@BudgetName,' ',''))  
      RAISERROR('-112',16,1)  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT BudgetDefID FROM COM_BudgetDef WITH(nolock) WHERE replace(BudgetName,' ','')=replace(@BudgetName,' ','') AND BudgetDefID <> @BudgetID)  
      RAISERROR('-112',16,1)       
    END  
   
   
	set @DT=convert(float,getdate())
	select @BudgetID

	IF @BudgetID=0--------START INSERT RECORD-----------  
	BEGIN
		--To Set Left,Right And Depth of Record  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		from COM_BudgetDef with(NOLOCK) where BudgetDefID=@SelectedNodeID  
   
		--IF No Record Selected or Record Doesn't Exist  
		if(@SelectedIsGroup is null)   
			select @SelectedNodeID=BudgetDefID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			from COM_BudgetDef with(NOLOCK) where ParentID =0  
         
		if(@SelectedIsGroup = 1)--Adding Node Under the Group  
		BEGIN  
			UPDATE COM_BudgetDef SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
			UPDATE COM_BudgetDef SET lft = lft + 2 WHERE lft > @Selectedlft;  
			set @lft =  @Selectedlft + 1  
			set @rgt = @Selectedlft + 2  
			set @ParentID = @SelectedNodeID  
			set @Depth = @Depth + 1  
		END  
		else if(@SelectedIsGroup = 0)--Adding Node at Same level  
		BEGIN  
			UPDATE COM_BudgetDef SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
			UPDATE COM_BudgetDef SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
	
		--Inserting into COM_BudgetDef
		INSERT INTO COM_BudgetDef(BudgetName, FinYearStartDate, BudgetTypeID, BudgetType,NumDimensions,StatusID,
								QtyType,Depth,ParentID,lft,rgt,IsGroup,CompanyGUID,GUID,CreatedBy,CreatedDate,QtyBudget,ChkBudgetOnlyForDefnAccounts,NonAccDocs,NonAccDocsField,InvAccDocs,InvAccDocsField,AccountTypes)
		VALUES(@BudgetName,convert(float,@BudgetYear),@BudgetTypeID,@BudgetTypeName,@NumDimensions,@StatusID,
								@QtyType,@Depth,@ParentID,@lft,@rgt,@IsGroup,@CompanyGUID,newid(),@UserName,@DT,@IsQtyBudget,@ChkBudgetOnlyForDefnAccounts,@NonAccDocs,@NonAccDocsField,@InvAccDocs,@InvAccDocsField,@AccountTypes)
		SET @BudgetID=scope_identity()
		
	END
	ELSE
	BEGIN
		IF @StatusID=0
		BEGIN
			DECLARE @Cnt INT
			SET @Cnt=0
			SELECT @Cnt=COUNT(*) FROM ADM_DocumentBudgets WITH(NOLOCK)
			WHERE BudgetID=@BudgetID
			IF @Cnt>0
			BEGIN
				RAISERROR('-367',16,1)
			END
		END
		
		UPDATE COM_BudgetDef 
		SET BudgetName=@BudgetName,FinYearStartDate=convert(float,@BudgetYear),
			QtyType=@QtyType,BudgetTypeID=@BudgetTypeID,BudgetType=@BudgetTypeName,StatusID=@StatusID,NumDimensions=@NumDimensions,
			ModifiedBy=@UserName,ModifiedDate=@DT,QtyBudget=@IsQtyBudget,
			ChkBudgetOnlyForDefnAccounts=@ChkBudgetOnlyForDefnAccounts,NonAccDocs=@NonAccDocs,NonAccDocsField=@NonAccDocsField,
			InvAccDocs=@InvAccDocs,InvAccDocsField=@InvAccDocsField,AccountTypes=@AccountTypes
		WHERE BudgetDefID=@BudgetID

		IF @BudgetXML IS NOT NULL
		BEGIN
			DELETE FROM COM_BudgetDefDims WHERE BudgetDefID=@BudgetID

			DELETE FROM COM_BudgetAlloc WHERE BudgetDefID=@BudgetID

			--DELETE FROM COM_BudgetDimValues WHERE BudgetDefID=@BudgetID

			DELETE FROM COM_BudgetDimRelations WHERE BudgetDefID=@BudgetID
		END
	END

	IF @BudgetXML IS NOT NULL
	BEGIN
			SET @XML=@CCList

			INSERT INTO COM_BudgetDefDims(BudgetDefID,CostCenterID,CompanyGUID,CreatedBy,CreatedDate,CCCodeTypeID)
			SELECT  @BudgetID,X.value('@CC','INT'),@CompanyGUID,@UserName,@DT,ISNULL(X.value('@CCCodeTypeID','INT'),0) 
			from @XML.nodes('/XML/Row') as Data(X)	

			set @XML=@BudgetXML
			
			set @SQL='INSERT INTO COM_BudgetAlloc(BudgetDefID,CurrencyID,ExchangeRT,AnnualAmount,YearH1Amount,YearH2Amount,Qtr1Amount,Qtr2Amount,Qtr3Amount,Qtr4Amount,
				Month1Amount,Month2Amount,Month3Amount,Month4Amount,Month5Amount,Month6Amount,Month7Amount,Month8Amount,Month9Amount,Month10Amount,Month11Amount,Month12Amount,RowID,CF,CompanyGUID,GUID,CreatedBy,CreatedDate,
				AccountID,ProductID,Rate,
				dcNumField1,dcNumField2,dcNumField3,dcNumField4,dcNumField5'
			
			select @SQL=@SQL+',['+name+']' 
			from sys.columns 
			where object_id=object_id('COM_BudgetAlloc') and name LIKE 'ccnid%'
			
			SET @SQL=@SQL+')
			SELECT '+CONVERT(NVARCHAR,@BudgetID)+',X.value(''@Currency'',''int''),X.value(''@ExchangeRate'',''float''),X.value(''@AnnualAmount'',''float''),X.value(''@YearH1Amount'',''float''),
				X.value(''@YearH2Amount'',''float''),X.value(''@Qtr1Amount'',''float''),X.value(''@Qtr2Amount'',''float''),X.value(''@Qtr3Amount'',''float''),
				X.value(''@Qtr4Amount'',''float''),X.value(''@Month1Amount'',''float''),X.value(''@Month2Amount'',''float''),X.value(''@Month3Amount'',''float''),
				X.value(''@Month4Amount'',''float''),X.value(''@Month5Amount'',''float''),X.value(''@Month6Amount'',''float''),X.value(''@Month7Amount'',''float''),
				X.value(''@Month8Amount'',''float''),X.value(''@Month9Amount'',''float''),X.value(''@Month10Amount'',''float''),X.value(''@Month11Amount'',''float''),
				X.value(''@Month12Amount'',''float''),X.value(''@Sno'',''int''),X.value(''@CF'',''NVARCHAR(10)''),'''+@CompanyGUID+''',newid(),'''+@UserName+''','+CONVERT(NVARCHAR,@DT)+',
				ISNULL(X.value(''@AccountID'',''INT''),1),ISNULL(X.value(''@ProductID'',''INT''),1),X.value(''@Rate'',''float''),
				isnull(X.value(''@dcNumField1'',''float''),0),isnull(X.value(''@dcNumField2'',''float''),0),isnull(X.value(''@dcNumField3'',''float''),0),isnull(X.value(''@dcNumField4'',''float''),0),isnull(X.value(''@dcNumField5'',''float''),0)'
			
			select @SQL=@SQL+',ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),1)' 
			from sys.columns 
			where object_id=object_id('COM_BudgetAlloc') and name LIKE 'ccnid%'
					
			SET @SQL=@SQL+' FROM @XML.nodes(''/XML/Row'') as Data(X)'
		
			EXEC sp_executesql @SQL,N'@XML XML',@XML
				
			SET @XML=@RelationsXML
			INSERT INTO COM_BudgetDimRelations(BudgetDefID,ParentBudgetDimValID,ChildBudgetDimValID,CompanyGUID,CreatedBy,CreatedDate)
			SELECT  @BudgetID,X.value('@PID','INT'),X.value('@CID','INT'),@CompanyGUID,@UserName,@DT from @XML.nodes('/Relations/Row') as Data(X)	
	END
	

COMMIT TRANSACTION  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID

SET NOCOUNT OFF;  
RETURN @BudgetID
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
