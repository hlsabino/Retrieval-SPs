USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetTaxChartNew]
	@ProfileID [int],
	@ProfileName [nvarchar](50) = null,
	@SelectedNodeID [int],
	@IsGroup [bit],
	@TaxXML [nvarchar](max) = null,
	@DeleteXML [nvarchar](max) = null,
	@IsImport [bit] = 0,
	@CompanyGUID [nvarchar](50) = null,
	@UserName [nvarchar](50),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section  
	DECLARE @Dt FLOAT ,@HasAccess BIT
	DECLARE @CCID NVARCHAR(500),@CCNodeID NVARCHAR(500),@XML XML
	DECLARE @Tbl1 TABLE(ID INT IDENTITY(1,1),CCID INT)
	DECLARE @Tbl2 TABLE(ID INT IDENTITY(1,1),CCNodeID INT)
	DECLARE @TblXML TABLE(ID INT IDENTITY(1,1),DocID INT,ColID INT,Price FLOAT,WEF DATETIME,CCID NVARCHAR(500),CCNodeID NVARCHAR(500))
	DECLARE @I INT,@Count INT,@GroupID INT
	DECLARE @SPInvoice cursor, @nStatusOuter int
	DECLARE @CCUpdate NVARCHAR(MAX),@CCTaxID INT,@SQL nvarchar(max)
		,@DocID int,@ColID INT,@ProductID INT,@Price FLOAT,@WEF FLOAT,@AccountID INT,@TillDate FLOAT,@Message NVARCHAR(MAX)

	IF @CompanyGUID IS NULL OR @CompanyGUID=''
		set @CompanyGUID='CompanyGUID'
	
	set @Dt=convert(float,getdate())
	SET @XML=@TaxXML
	
	if(@IsImport=1  and @ProfileID>0)
	begin
		set @SQL='delete from [COM_CCTaxes] where cctaxid in (select C.cctaxid from [COM_CCTaxes] C WITH(nolock)
		join @XML.nodes(''/XML/Row'') as Data(X) on C.profileid='+CONVERT(NVARCHAR,@ProfileID)+' and C.ProductID = ISNULL(X.value(''@ProductID'',''INT''),0) 
		and C.DocID = X.value(''@DocID'',''INT'') and C.ColID = X.value(''@ColID'',''INT'') 
		and c.WEF=CONVERT(FLOAT,X.value(''@WEF'',''DATETIME'')) and C.value=ISNULL(X.value(''@Price'',''FLOAT''),0)  
		and isnull(c.TillDate,0)=isnull(CONVERT(FLOAT,X.value(''@TillDate'',''DATETIME'')),0)
		and isnull(c.[Message],'''')=isnull(X.value(''@Message'',''NVARCHAR(MAX)''),'''')'
		
		select @SQL=@SQL+' AND C.'+name+'=ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),0)' 
		from sys.columns 
		where object_id=object_id('COM_CCTaxes') and name LIKE 'ccnid%'
		
		SET @SQL=@SQL+')'
		EXEC sp_executesql @SQL,N'@XML XML',@XML
	end 
	 
		IF @ProfileID=0--NEW
		BEGIN
			DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT
			DECLARE @SelectedIsGroup bit
	
			IF EXISTS (SELECT ProfileID FROM COM_CCTaxesDefn WITH(nolock) WHERE ProfileName=@ProfileName) 
				RAISERROR('-112',16,1) 
			
			if @SelectedNodeID=0
				set @SelectedNodeID=-1

			--To Set Left,Right And Depth of Record
			SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
			from COM_CCTaxesDefn with(NOLOCK) where ProfileID=@SelectedNodeID

			--IF No Record Selected or Record Doesn't Exist
			IF(@SelectedIsGroup is null) 
				select @SelectedNodeID=ProfileID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
				from COM_CCTaxesDefn with(NOLOCK) where ParentID =0
						
			IF(@SelectedIsGroup = 1)--Adding Node Under the Group
			BEGIN
				UPDATE COM_CCTaxesDefn SET rgt = rgt + 2 WHERE rgt > @Selectedlft;
				UPDATE COM_CCTaxesDefn SET lft = lft + 2 WHERE lft > @Selectedlft;
				SET @lft =  @Selectedlft + 1
				SET @rgt =	@Selectedlft + 2
				SET @ParentID = @SelectedNodeID
				SET @Depth = @Depth + 1
			END
			ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level
			BEGIN
				UPDATE COM_CCTaxesDefn SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
				UPDATE COM_CCTaxesDefn SET lft = lft + 2 WHERE lft > @Selectedrgt;
				SET @lft =  @Selectedrgt + 1
				SET @rgt =	@Selectedrgt + 2 
			END
			ELSE  --Adding Root
			BEGIN
					SET @lft =  1
					SET @rgt =	2 
					SET @Depth = 0
					SET @ParentID =0
					SET @IsGroup=1
			END
			
			-- Insert statements for procedure here
			INSERT INTO COM_CCTaxesDefn(ProfileName,
							[IsGroup],[Depth],[ParentID],[lft],[rgt],
							[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
							VALUES
							(@ProfileName,
							@IsGroup,@Depth,@ParentID,@lft,@rgt,
							@CompanyGUID,newid(),@UserName,@Dt)
			--To get inserted record primary key
			SET @ProfileID=SCOPE_IDENTITY() 
			
			SET @SPInvoice = cursor for 
			SELECT X.value('@DocID','INT'),X.value('@ColID','INT'),ISNULL(X.value('@ProductID','INT'),0),X.value('@Price','FLOAT'),CONVERT(FLOAT,X.value('@WEF','DATETIME'))
				,ISNULL(X.value('@AccountID','INT'),0),CONVERT(FLOAT,X.value('@TillDate','DATETIME')),X.value('@Message','NVARCHAR(MAX)')
				,isnull(X.value('@CCUpdate','NVARCHAR(MAX)'),'')
			FROM @XML.nodes('/XML/Row') as Data(X)
			WHERE X.value('@CCTaxID','INT') IS NULL

			OPEN @SPInvoice 
			SET @nStatusOuter = @@FETCH_STATUS
			
			FETCH NEXT FROM @SPInvoice Into @DocID,@ColID,@ProductID,@Price,@WEF,@AccountID,@TillDate,@Message,@CCUpdate
			SET @nStatusOuter = @@FETCH_STATUS
			WHILE(@nStatusOuter <> -1)
			BEGIN
				INSERT INTO COM_CCTaxes([ProfileID],[ProfileName]
				   ,[DocID],[ColID],[ProductID],[Value],[WEF],[AccountID],TillDate,[Message]
				   ,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate]) 
				SELECT @ProfileID,@ProfileName
					,@DocID,@ColID,@ProductID,@Price,@WEF,@AccountID,@TillDate,@Message
					,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())
				set @CCTaxID=Scope_Identity()
				--select @CCTaxID,@CCUpdate
				if @CCUpdate!=''
				begin
					set @SQL='update COM_CCTaxes set '+substring(@CCUpdate,2,len(@CCUpdate)-1)+' where CCTaxID='+convert(nvarchar,@CCTaxID)
					exec(@SQL)
				end
				
				FETCH NEXT FROM @SPInvoice Into @DocID,@ColID,@ProductID,@Price,@WEF,@AccountID,@TillDate,@Message,@CCUpdate
				SET @nStatusOuter = @@FETCH_STATUS
			END
		END
		ELSE
		BEGIN--EDIT
			--Dont Check Go For New Inserts If its is coming from search
			IF @ProfileID!=-100
			BEGIN
				IF EXISTS (SELECT ProfileID FROM COM_CCTaxesDefn WITH(nolock) WHERE ProfileName=@ProfileName AND ProfileID!=@ProfileID) 
					RAISERROR('-112',16,1) 
				
				UPDATE COM_CCTaxesDefn
				SET ProfileName=@ProfileName,[GUID]=newid(),ModifiedBy=@UserName,ModifiedDate=@Dt
				WHERE ProfileID=@ProfileID

				SET @SPInvoice = cursor for 
				SELECT X.value('@DocID','INT'),X.value('@ColID','INT'),ISNULL(X.value('@ProductID','INT'),0),X.value('@Price','FLOAT'),CONVERT(FLOAT,X.value('@WEF','DATETIME'))
					,ISNULL(X.value('@AccountID','INT'),0),CONVERT(FLOAT,X.value('@TillDate','DATETIME')),X.value('@Message','NVARCHAR(MAX)')
					,isnull(X.value('@CCUpdate','NVARCHAR(MAX)'),'')
				FROM @XML.nodes('/XML/Row') as Data(X)
				WHERE X.value('@CCTaxID','INT') IS NULL
				
				OPEN @SPInvoice 
				SET @nStatusOuter = @@FETCH_STATUS
				
				FETCH NEXT FROM @SPInvoice Into @DocID,@ColID,@ProductID,@Price,@WEF,@AccountID,@TillDate,@Message,@CCUpdate
				SET @nStatusOuter = @@FETCH_STATUS
				WHILE(@nStatusOuter <> -1)
				BEGIN
					INSERT INTO COM_CCTaxes([ProfileID],[ProfileName]
					   ,[DocID],[ColID],[ProductID],[Value],[WEF],[AccountID],TillDate,[Message]
					   ,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate]) 
					SELECT @ProfileID,@ProfileName
						,@DocID,@ColID,@ProductID,@Price,@WEF,@AccountID,@TillDate,@Message
						,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE())
					set @CCTaxID=Scope_Identity()
					--select @CCTaxID,@CCUpdate
					if @CCUpdate!=''
					begin
						set @SQL='update COM_CCTaxes set '+substring(@CCUpdate,2,len(@CCUpdate)-1)+' where CCTaxID='+convert(nvarchar,@CCTaxID)
						exec(@SQL)
					end
					
					FETCH NEXT FROM @SPInvoice Into @DocID,@ColID,@ProductID,@Price,@WEF,@AccountID,@TillDate,@Message,@CCUpdate
					SET @nStatusOuter = @@FETCH_STATUS
				END
			END
			
			UPDATE COM_CCTaxes
			SET DocID=CONVERT(FLOAT,X.value('@DocID','INT')),
				ColID=CONVERT(FLOAT,X.value('@ColID','INT')),
				WEF=CONVERT(FLOAT,X.value('@WEF','DATETIME')),
				TillDate=CONVERT(FLOAT,X.value('@TillDate','DATETIME')),
				Value=ISNULL(X.value('@Price','FLOAT'),0),
				[Message]=X.value('@Message','NVARCHAR(MAX)')
			FROM @XML.nodes('/XML/Row') as Data(X),COM_CCTaxes P
			WHERE X.value('@CCTaxID','INT') IS NOT NULL AND P.CCTaxID=X.value('@CCTaxID','INT')
			
			--Delete Rows
			IF @DeleteXML IS NOT NULL AND @DeleteXML!=''
			BEGIN
				SET @XML=@DeleteXML
				DELETE FROM COM_CCTaxes
				WHERE CCTaxID IN (SELECT X.value('@ID','INT') FROM @XML.nodes('/XML/Row') as Data(X))
				
			END
		END
	
 	--Added to set default inactive if action exists
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,45,156)
	if(@HasAccess!=0)
	begin
		update COM_CCTaxesDefn set statusid=2 where profileid=@ProfileID
		update COM_CCTaxes  set statusid=2 where profileid=@ProfileID
	end 
	
	--To Set Used CostCenters with Group Check
	EXEC [spADM_SetPriceTaxUsedCC] 2,@ProfileID,1
	
	
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;  
RETURN @ProfileID  
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
