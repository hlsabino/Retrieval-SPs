USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportBudget]
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
	@IsAppend [bit] = 0,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY
SET NOCOUNT ON;  
	
	declare @XML xml,@DT float,@BXML xml,@CCListXML xml,@StatID INT=1,@PrevBudgetID INT
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT  
	DECLARE @SelectedIsGroup bit,@SQL nvarchar(max),@SQL2 nvarchar(max)
	
	DECLARE @TabCCList TABLE(ID INT IDENTITY(1,1),CC NVARCHAR(50),CostCenterID NVARCHAR(50))
	SET @PrevBudgetID = @BudgetID
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
		
		--IF @BudgetXML IS NOT NULL
		--BEGIN
		--	IF(@IsAppend=0)
		--	BEGIN
		--		DELETE FROM COM_BudgetAlloc WHERE BudgetDefID=@BudgetID
		--		--DELETE FROM COM_BudgetDimValues WHERE BudgetDefID=@BudgetID
		--		DELETE FROM COM_BudgetDefDims WHERE BudgetDefID=@BudgetID
		--		DELETE FROM COM_BudgetDimRelations WHERE BudgetDefID=@BudgetID
		--	END
		--	ELSE
		--	BEGIN				
		--		--DELETE FROM COM_BudgetDefDims WHERE BudgetDefID=@BudgetID
		--		DELETE FROM COM_BudgetAlloc WHERE BudgetDefID=@BudgetID
		--	END
		--END
	END

	IF @BudgetXML IS NOT NULL
	BEGIN
		SET @XML=@CCList
		SET @XML=@BudgetXML
		IF(@IsAppend = 1 AND @PrevBudgetID > 0)
		BEGIN
			DECLARE @I INT=1,@cnt2 INT
			----
			SET @CCListXML=@CCList
			SET @BXML=@BudgetXML
			
			INSERT INTO @TabCCList
			SELECT CASE WHEN X.value('@CC','NVARCHAR(50)')=2 THEN 'AccountID' WHEN X.value('@CC','NVARCHAR(50)')=3 THEN 'ProductID' 
			WHEN X.value('@CC','NVARCHAR(50)') BETWEEN 50000 AND 59999 THEN 'CC'+REPLACE(LTRIM(REPLACE(SUBSTRING(X.value('@CC','NVARCHAR(50)'),2,10),'0',' ')),' ','0') ELSE X.value('@CC','NVARCHAR(50)') END ,X.value('@CC','NVARCHAR(50)')
			FROM @CCListXML.nodes('/XML/Row') as Data(X)
			
			
			IF((SELECT COUNT(CostCenterID) FROM @TabCCList) <> (SELECT COUNT(CostCenterID) FROM COM_BudgetDefDims WHERE BudgetDefID=@BudgetID))
			   SET @StatID=-1
			ELSE IF((SELECT COUNT(*) FROM COM_BudgetDefDims BD WITH(NOLOCK) 
					LEFT JOIN @TabCCList T ON T.CostCenterID=BD.CostCenterID
					WHERE BD.BudgetDefID=@BudgetID AND  T.CostCenterID IS NULL) > 0)
				SET @StatID=-1
			ELSE IF((SELECT COUNT(*) FROM @TabCCList T  
					LEFT JOIN COM_BudgetDefDims BD WITH(NOLOCK) ON T.CostCenterID=BD.CostCenterID AND BD.BudgetDefID=@BudgetID WHERE BD.CostCenterID IS NULL) > 0)
				SET @StatID=-1
				
			IF(@StatID > 0)
			BEGIN	
				SELECT @cnt2=COUNT(*) FROM @BXML.nodes('/XML/Row') as Data(X) 
				DECLARE @Query NVARCHAR(MAX)='',@I3 INT=1,@cnt3 INT,@CCID NVARCHAR(100)
				SELECT @cnt3=COUNT(*) FROM @TabCCList
				
				WHILE(@I3<=@cnt3)
				BEGIN
					SELECT @CCID=CC FROM @TabCCList WHERE ID=@I3
					IF(@I3=@cnt3)
						SET @Query=@Query+'BA.'+CONVERT(NVARCHAR,REPLACE(@CCID,'CC','CCNID'))+'=T.'+CONVERT(NVARCHAR,@CCID)
					ELSE						
						SET @Query=@Query+'BA.'+CONVERT(NVARCHAR,REPLACE(@CCID,'CC','CCNID'))+'=T.'+CONVERT(NVARCHAR,@CCID)+' AND '
					
					SET @I3=@I3+1
				END
				
				WHILE(@I<=@CNT2)
				BEGIN
					SET @SQL2='SELECT * INTO #TEMP FROM (
					SELECT X.value(''@Sno'',''int'') Sno,'+CONVERT(NVARCHAR,@BudgetID)+' BudgetID,X.value(''@Currency'',''int'') Currency,X.value(''@ExchangeRate'',''float'') ExchangeRate,X.value(''@AnnualAmount'',''float'') AnnualAmount,X.value(''@YearH1Amount'',''float'') YearH1Amount,
					X.value(''@YearH2Amount'',''float'') YearH2Amount,X.value(''@Qtr1Amount'',''float'') Qtr1Amount,X.value(''@Qtr2Amount'',''float'') Qtr2Amount,X.value(''@Qtr3Amount'',''float'') Qtr3Amount,
					X.value(''@Qtr4Amount'',''float'') Qtr4Amount,X.value(''@Month1Amount'',''float'') Month1Amount,X.value(''@Month2Amount'',''float'') Month2Amount,X.value(''@Month3Amount'',''float'') Month3Amount,
					X.value(''@Month4Amount'',''float'') Month4Amount,X.value(''@Month5Amount'',''float'') Month5Amount,X.value(''@Month6Amount'',''float'') Month6Amount,X.value(''@Month7Amount'',''float'') Month7Amount,
					X.value(''@Month8Amount'',''float'') Month8Amount,X.value(''@Month9Amount'',''float'') Month9Amount,X.value(''@Month10Amount'',''float'') Month10Amount,X.value(''@Month11Amount'',''float'') Month11Amount,
					X.value(''@Month12Amount'',''float'') Month12Amount,X.value(''@CF'',''NVARCHAR(10)'') CF,'''+@CompanyGUID+''' CompanyGUID,newid() GUID,'''+@UserName+''' UserName,'+CONVERT(NVARCHAR,@DT)+' Date,
					ISNULL(X.value(''@AccountID'',''INT''),1) AccountID,ISNULL(X.value(''@ProductID'',''INT''),1) ProductID,X.value(''@Rate'',''float'') Rate,
					isnull(X.value(''@dcNumField1'',''float''),0) dcNumField1,isnull(X.value(''@dcNumField2'',''float''),0) dcNumField2,isnull(X.value(''@dcNumField3'',''float''),0) dcNumField3,isnull(X.value(''@dcNumField4'',''float''),0) dcNumField4,isnull(X.value(''@dcNumField5'',''float''),0) dcNumField5'
					--ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),1)
					SELECT @SQL2=@SQL2+',ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),1)'+REPLACE(name,'NID','')
					FROM sys.columns 
					WHERE object_id=object_id('COM_BudgetAlloc') and name LIKE 'ccnid%'
							
					SET @SQL2=@SQL2+' FROM @XML.nodes(''/XML/Row'') as Data(X) 
					
					WHERE X.value(''@Sno'',''NVARCHAR(50)'')='+CONVERT(NVARCHAR,@I)+') AS T
					IF((SELECT COUNT(*) FROM #TEMP T
					JOIN COM_BudgetAlloc BA WITH(NOLOCK) ON BA.BudgetDefID='+CONVERT(NVARCHAR,@PrevBudgetID)+' AND '+@Query+')=0)
					BEGIN
						----------------
						INSERT INTO COM_BudgetAlloc(BudgetDefID,CurrencyID,ExchangeRT,AnnualAmount,YearH1Amount,YearH2Amount,Qtr1Amount,Qtr2Amount,Qtr3Amount,Qtr4Amount,
						Month1Amount,Month2Amount,Month3Amount,Month4Amount,Month5Amount,Month6Amount,Month7Amount,Month8Amount,Month9Amount,Month10Amount,Month11Amount,Month12Amount,RowID,CF,CompanyGUID,GUID,CreatedBy,CreatedDate,
						AccountID,ProductID,Rate,
						dcNumField1,dcNumField2,dcNumField3,dcNumField4,dcNumField5'
					
						select @SQL2=@SQL2+',['+name+']' 
						from sys.columns 
						where object_id=object_id('COM_BudgetAlloc') and name LIKE 'ccnid%'
						
						SET @SQL2=@SQL2+')
						SELECT '+CONVERT(NVARCHAR,@BudgetID)+',X.value(''@Currency'',''int''),X.value(''@ExchangeRate'',''float''),X.value(''@AnnualAmount'',''float''),X.value(''@YearH1Amount'',''float''),
							X.value(''@YearH2Amount'',''float''),X.value(''@Qtr1Amount'',''float''),X.value(''@Qtr2Amount'',''float''),X.value(''@Qtr3Amount'',''float''),
							X.value(''@Qtr4Amount'',''float''),X.value(''@Month1Amount'',''float''),X.value(''@Month2Amount'',''float''),X.value(''@Month3Amount'',''float''),
							X.value(''@Month4Amount'',''float''),X.value(''@Month5Amount'',''float''),X.value(''@Month6Amount'',''float''),X.value(''@Month7Amount'',''float''),
							X.value(''@Month8Amount'',''float''),X.value(''@Month9Amount'',''float''),X.value(''@Month10Amount'',''float''),X.value(''@Month11Amount'',''float''),
							X.value(''@Month12Amount'',''float''),X.value(''@Sno'',''int''),X.value(''@CF'',''NVARCHAR(10)''),'''+@CompanyGUID+''',newid(),'''+@UserName+''','+CONVERT(NVARCHAR,@DT)+',
							ISNULL(X.value(''@AccountID'',''INT''),1),ISNULL(X.value(''@ProductID'',''INT''),1),X.value(''@Rate'',''float''),
							isnull(X.value(''@dcNumField1'',''float''),0),isnull(X.value(''@dcNumField2'',''float''),0),isnull(X.value(''@dcNumField3'',''float''),0),isnull(X.value(''@dcNumField4'',''float''),0),isnull(X.value(''@dcNumField5'',''float''),0)'
						
						select @SQL2=@SQL2+',ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),1)' 
						from sys.columns 
						where object_id=object_id('COM_BudgetAlloc') and name LIKE 'ccnid%'
								
						SET @SQL2=@SQL2+' FROM @XML.nodes(''/XML/Row'') as Data(X) WHERE X.value(''@Sno'',''NVARCHAR(50)'')='+CONVERT(NVARCHAR,@I)+'
						----------------
					END
					
					DROP TABLE #TEMP'
					print(substring(@SQL2,1,4000))
					print(substring(@SQL2,4001,4000))
					print(substring(@SQL2,8001,4000))
					print(substring(@SQL2,12001,4000))
					
					EXEC sp_executesql @SQL2,N'@XML XML',@XML
					
					SET @I=@I+1
				END	
			END			
		END
		ELSE
		BEGIN			
			SET @XML=@CCList
					
			DELETE FROM COM_BudgetAlloc WHERE BudgetDefID=@BudgetID
			--DELETE FROM COM_BudgetDimValues WHERE BudgetDefID=@BudgetID
			DELETE FROM COM_BudgetDefDims WHERE BudgetDefID=@BudgetID
			DELETE FROM COM_BudgetDimRelations WHERE BudgetDefID=@BudgetID
						
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
			--PRINT @SQL
			EXEC sp_executesql @SQL,N'@XML XML',@XML
				
			SET @XML=@RelationsXML
			INSERT INTO COM_BudgetDimRelations(BudgetDefID,ParentBudgetDimValID,ChildBudgetDimValID,CompanyGUID,CreatedBy,CreatedDate)
			SELECT  @BudgetID,X.value('@PID','INT'),X.value('@CID','INT'),@CompanyGUID,@UserName,@DT from @XML.nodes('/Relations/Row') as Data(X)			
		END		
			
			--SELECT X.value('@Currency','int'),X.value('@ExchangeRate','float'),X.value('@AnnualAmount','float'),X.value('@YearH1Amount','float'),
			--X.value('@YearH2Amount','float'),X.value('@Qtr1Amount','float'),X.value('@Qtr2Amount','float'),X.value('@Qtr3Amount','float'),
			--X.value('@Qtr4Amount','float'),X.value('@Month1Amount','float'),X.value('@Month2Amount','float'),X.value('@Month3Amount','float'),
			--X.value('@Month4Amount','float'),X.value('@Month5Amount','float'),X.value('@Month6Amount','float'),X.value('@Month7Amount','float'),
			--X.value('@Month8Amount','float'),X.value('@Month9Amount','float'),X.value('@Month10Amount','float'),X.value('@Month11Amount','float'),
			--X.value('@Month12Amount','float'),X.value('@Sno','int'),X.value('@CF','NVARCHAR(10)'),'dc2bff43-9a6f-40e2-89f1-de077e5775f4',newid(),'admin',45445.7,
			--ISNULL(X.value('@AccountID','INT'),1),ISNULL(X.value('@ProductID','INT'),1),X.value('@Rate','float'),
			--isnull(X.value('@dcNumField1','float'),0),isnull(X.value('@dcNumField2','float'),0),isnull(X.value('@dcNumField3','float'),0)
			--,isnull(X.value('@dcNumField4','float'),0),isnull(X.value('@dcNumField5','float'),0),ISNULL(X.value('@CC1','INT'),1),ISNULL(X.value('@CC2','INT'),1)
			--,ISNULL(X.value('@CC3','INT'),1),ISNULL(X.value('@CC4','INT'),1),ISNULL(X.value('@CC5','INT'),1),ISNULL(X.value('@CC6','INT'),1),ISNULL(X.value('@CC7','INT'),1),ISNULL(X.value('@CC8','INT'),1),ISNULL(X.value('@CC70','INT'),1),ISNULL(X.value('@CC51','INT'),1),ISNULL(X.value('@CC52','INT'),1),ISNULL(X.value('@CC53','INT'),1),ISNULL(X.value('@CC68','INT'),1),ISNULL(X.value('@CC69','INT'),1),ISNULL(X.value('@CC73','INT'),1),ISNULL(X.value('@CC9','INT'),1),ISNULL(X.value('@CC10','INT'),1),ISNULL(X.value('@CC11','INT'),1),ISNULL(X.value('@CC12','INT'),1),ISNULL(X.value('@CC13','INT'),1),ISNULL(X.value('@CC14','INT'),1),ISNULL(X.value('@CC15','INT'),1),ISNULL(X.value('@CC16','INT'),1),ISNULL(X.value('@CC17','INT'),1),ISNULL(X.value('@CC18','INT'),1),ISNULL(X.value('@CC19','INT'),1),ISNULL(X.value('@CC250','INT'),1),ISNULL(X.value('@CC251','INT'),1),ISNULL(X.value('@CC20','INT'),1),ISNULL(X.value('@CC58','INT'),1),ISNULL(X.value('@CC59','INT'),1),ISNULL(X.value('@CC60','INT'),1),ISNULL(X.value('@CC61','INT'),1),ISNULL(X.value('@CC62','INT'),1),ISNULL(X.value('@CC71','INT'),1),ISNULL(X.value('@CC21','INT'),1),ISNULL(X.value('@CC22','INT'),1),ISNULL(X.value('@CC23','INT'),1),ISNULL(X.value('@CC170','INT'),1),ISNULL(X.value('@CC24','INT'),1),ISNULL(X.value('@CC25','INT'),1),ISNULL(X.value('@CC26','INT'),1)
			--,ISNULL(X.value('@CC27','INT'),1),ISNULL(X.value('@CC28','INT'),1),ISNULL(X.value('@CC29','INT'),1) 
			-- FROM @BXML.nodes('/XML/Row') as Data(X)					
	END

COMMIT TRANSACTION  
IF(@StatID=-1)
	SELECT -999,'Dimensions mismatch'
ELSE
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
