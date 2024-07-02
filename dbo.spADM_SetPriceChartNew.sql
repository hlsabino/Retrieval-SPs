USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetPriceChartNew]
	@ProfileID [int],
	@ProfileName [nvarchar](max) = null,
	@SelectedNodeID [int],
	@IsGroup [bit],
	@PriceXML [nvarchar](max) = null,
	@DeleteXML [nvarchar](max) = null,
	@PriceType [smallint],
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
		DECLARE @Dt FLOAT ,@XML XML,@HasAccess BIT,@SQL nvarchar(max)
		DECLARE @Tbl1 TABLE(ID INT IDENTITY(1,1),CCID INT)
		DECLARE @Tbl2 TABLE(ID INT IDENTITY(1,1),CCNodeID INT)
		DECLARE @TblXML TABLE(ID INT IDENTITY(1,1),ProductID INT,WEF DATETIME,CCID NVARCHAR(500),CCNodeID NVARCHAR(500),
			PurchaseRate FLOAT,PurchaseRateA FLOAT,PurchaseRateB FLOAT,PurchaseRateC FLOAT,
			PurchaseRateD FLOAT,PurchaseRateE FLOAT,PurchaseRateF FLOAT,PurchaseRateG FLOAT,
			SellingRate FLOAT,SellingRateA FLOAT,SellingRateB FLOAT,SellingRateC FLOAT,
			SellingRateD FLOAT,SellingRateE FLOAT,SellingRateF FLOAT,SellingRateG FLOAT)

	set @Dt=convert(float,getdate())
	SET @XML=@PriceXML

	IF(@IsImport=1 and @ProfileID>0)
	BEGIN
	
		SET @SQL ='delete from [COM_CCPrices] where PriceCCID in (select C.PriceCCID from [COM_CCPrices] C WITH(nolock)
		join @XML.nodes(''/XML/Row'') as Data(X) on C.profileid='+CONVERT(NVARCHAR,@ProfileID)+' and C.ProductID = ISNULL(X.value(''@ProductID'',''INT''),0) 
		and c.WEF=CONVERT(FLOAT,X.value(''@WEF'',''DATETIME'')) and c.TillDate=CONVERT(FLOAT,X.value(''@TillDate'',''DATETIME'')) and
		PurchaseRate=ISNULL(X.value(''@PurchaseRate'',''FLOAT''),0) and PurchaseRateA=ISNULL(X.value(''@PurchaseRateA'',''FLOAT''),0) and
		PurchaseRateB=ISNULL(X.value(''@PurchaseRateB'',''FLOAT''),0) and PurchaseRateC=ISNULL(X.value(''@PurchaseRateC'',''FLOAT''),0) and
		PurchaseRateD=ISNULL(X.value(''@PurchaseRateD'',''FLOAT''),0) and PurchaseRateE=ISNULL(X.value(''@PurchaseRateE'',''FLOAT''),0) and
		PurchaseRateF=ISNULL(X.value(''@PurchaseRateF'',''FLOAT''),0) and PurchaseRateG=ISNULL(X.value(''@PurchaseRateG'',''FLOAT''),0) and
		SellingRate=ISNULL(X.value(''@SellingRate'',''FLOAT''),0) and SellingRateA=ISNULL(X.value(''@SellingRateA'',''FLOAT''),0) and
		SellingRateB=ISNULL(X.value(''@SellingRateB'',''FLOAT''),0) and SellingRateC=ISNULL(X.value(''@SellingRateC'',''FLOAT''),0) and
		SellingRateD=ISNULL(X.value(''@SellingRateD'',''FLOAT''),0) and SellingRateE=ISNULL(X.value(''@SellingRateE'',''FLOAT''),0) and
		SellingRateF=ISNULL(X.value(''@SellingRateF'',''FLOAT''),0) and SellingRateG=ISNULL(X.value(''@SellingRateG'',''FLOAT''),0) and
		ReorderLevel=ISNULL(X.value(''@ReorderLevel'',''FLOAT''),0) and ReorderQty=ISNULL(X.value(''@ReorderQty'',''FLOAT''),0) and
		MaxInventoryLevel=ISNULL(X.value(''@MaxInventoryLevel'',''FLOAT''),0) and ReorderMinOrderQty=ISNULL(X.value(''@ReorderMinOrderQty'',''FLOAT''),0) and
		ReorderMaxOrderQty=ISNULL(X.value(''@ReorderMaxOrderQty'',''FLOAT''),0) '
		
		select @SQL=@SQL+' AND C.'+name+'=ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),0)' 
		from sys.columns WITH(NOLOCK)
		where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
		
		SET @SQL=@SQL+')'
		EXEC sp_executesql @SQL,N'@XML XML',@XML
	END
	
	
	IF @ProfileID=0--NEW
	BEGIN
		DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT
		DECLARE @SelectedIsGroup bit

		IF EXISTS (SELECT ProfileID FROM COM_CCPricesDefn WITH(nolock) WHERE ProfileName=@ProfileName) 
			RAISERROR('-112',16,1) 
			
		if @SelectedNodeID=0
			set @SelectedNodeID=-1

		--To Set Left,Right And Depth of Record
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
		from COM_CCPricesDefn with(NOLOCK) where ProfileID=@SelectedNodeID

		--IF No Record Selected or Record Doesn't Exist
		IF(@SelectedIsGroup is null) 
			select @SelectedNodeID=ProfileID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
			from COM_CCPricesDefn with(NOLOCK) where ParentID =0
					
		IF(@SelectedIsGroup = 1)--Adding Node Under the Group
		BEGIN
			UPDATE COM_CCPricesDefn SET rgt = rgt + 2 WHERE rgt > @Selectedlft;
			UPDATE COM_CCPricesDefn SET lft = lft + 2 WHERE lft > @Selectedlft;
			SET @lft =  @Selectedlft + 1
			SET @rgt =	@Selectedlft + 2
			SET @ParentID = @SelectedNodeID
			SET @Depth = @Depth + 1
		END
		ELSE IF(@SelectedIsGroup = 0)--Adding Node at Same level
		BEGIN
			UPDATE COM_CCPricesDefn SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
			UPDATE COM_CCPricesDefn SET lft = lft + 2 WHERE lft > @Selectedrgt;
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
		INSERT INTO COM_CCPricesDefn(ProfileName,PriceType,
						[IsGroup],[Depth],[ParentID],[lft],[rgt],
						[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
						VALUES
						(@ProfileName,@PriceType,
						@IsGroup,@Depth,@ParentID,@lft,@rgt,
						@CompanyGUID,newid(),@UserName,@Dt)
		--To get inserted record primary key
		SET @ProfileID=SCOPE_IDENTITY()
			
		SET @SQL ='INSERT INTO COM_CCPrices
       ([ProfileID],[ProfileName],[ProductID],UOMID,[WEF],PriceType,[AccountID],CurrencyID
	   ,PurchaseRate,PurchaseRateA,PurchaseRateB,PurchaseRateC,PurchaseRateD,PurchaseRateE,PurchaseRateF,PurchaseRateG
	   ,SellingRate,SellingRateA,SellingRateB,SellingRateC,SellingRateD,SellingRateE,SellingRateF,SellingRateG,
       ReorderLevel,ReorderQty,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],TillDate,Remarks,MaxInventoryLevel,ReorderMinOrderQty,ReorderMaxOrderQty'
       
		select @SQL=@SQL+',['+name+']' 
		from sys.columns 
		where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
				
		SET @SQL =@SQL+') 
		SELECT '+CONVERT(NVARCHAR,@ProfileID)+','''+@ProfileName+''',ISNULL(X.value(''@ProductID'',''INT''),0),ISNULL(X.value(''@UOMID'',''INT''),0),CONVERT(FLOAT,X.value(''@WEF'',''DATETIME'')),ISNULL(X.value(''@Type'',''smallint''),0),
		ISNULL(X.value(''@AccountID'',''INT''),0),ISNULL(X.value(''@CurrencyID'',''INT''),0),
		ISNULL(X.value(''@PurchaseRate'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateA'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateB'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateC'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateD'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateE'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateF'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateG'',''FLOAT''),0),
		ISNULL(X.value(''@SellingRate'',''FLOAT''),0),ISNULL(X.value(''@SellingRateA'',''FLOAT''),0),ISNULL(X.value(''@SellingRateB'',''FLOAT''),0),ISNULL(X.value(''@SellingRateC'',''FLOAT''),0),ISNULL(X.value(''@SellingRateD'',''FLOAT''),0),ISNULL(X.value(''@SellingRateE'',''FLOAT''),0),ISNULL(X.value(''@SellingRateF'',''FLOAT''),0),ISNULL(X.value(''@SellingRateG'',''FLOAT''),0),
		ISNULL(X.value(''@ReorderLevel'',''FLOAT''),0),ISNULL(X.value(''@ReorderQty'',''FLOAT''),0),
		'''+@CompanyGUID+''',NEWID(),'''+@UserName+''',CONVERT(FLOAT,GETDATE()),CONVERT(FLOAT,X.value(''@TillDate'',''DATETIME'')),X.value(''@Remarks'',''nvarchar(max)''),
		ISNULL(X.value(''@MaxInventoryLevel'',''FLOAT''),0) ,ISNULL(X.value(''@ReorderMinOrderQty'',''FLOAT''),0),ISNULL(X.value(''@ReorderMaxOrderQty'',''FLOAT''),0) '
		
		select @SQL=@SQL+',ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),0)' 
		from sys.columns 
		where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
				
		SET @SQL =@SQL+' FROM @XML.nodes(''/XML/Row'') as Data(X)'
		print @SQL
		EXEC sp_executesql @SQL,N'@XML XML',@XML
			
	END
	ELSE
	BEGIN--EDIT
		--Dont Check Go For New Inserts If its is coming from search
		IF @ProfileID!=-100
		BEGIN
			IF EXISTS (SELECT ProfileID FROM COM_CCPricesDefn WITH(nolock) WHERE ProfileName=@ProfileName AND ProfileID!=@ProfileID) 
			RAISERROR('-112',16,1) 
			
			UPDATE COM_CCPricesDefn
			SET ProfileName=@ProfileName,PriceType=@PriceType,[GUID]=newid(),ModifiedBy=@UserName,ModifiedDate=@Dt
			WHERE ProfileID=@ProfileID
						
			SET @SQL ='INSERT INTO COM_CCPrices
       ([ProfileID],[ProfileName],[ProductID],UOMID,[WEF],PriceType,[AccountID],CurrencyID
	   ,PurchaseRate,PurchaseRateA,PurchaseRateB,PurchaseRateC,PurchaseRateD,PurchaseRateE,PurchaseRateF,PurchaseRateG
	   ,SellingRate,SellingRateA,SellingRateB,SellingRateC,SellingRateD,SellingRateE,SellingRateF,SellingRateG,
       ReorderLevel,ReorderQty,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],TillDate,Remarks,MaxInventoryLevel,ReorderMinOrderQty,ReorderMaxOrderQty'
       
		select @SQL=@SQL+',['+name+']' 
		from sys.columns 
		where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
				
		SET @SQL =@SQL+') 
		SELECT '+CONVERT(NVARCHAR,@ProfileID)+','''+@ProfileName+''',ISNULL(X.value(''@ProductID'',''INT''),0),ISNULL(X.value(''@UOMID'',''INT''),0),CONVERT(FLOAT,X.value(''@WEF'',''DATETIME'')),ISNULL(X.value(''@Type'',''smallint''),0),
		ISNULL(X.value(''@AccountID'',''INT''),0),ISNULL(X.value(''@CurrencyID'',''INT''),0),
		ISNULL(X.value(''@PurchaseRate'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateA'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateB'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateC'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateD'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateE'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateF'',''FLOAT''),0),ISNULL(X.value(''@PurchaseRateG'',''FLOAT''),0),
		ISNULL(X.value(''@SellingRate'',''FLOAT''),0),ISNULL(X.value(''@SellingRateA'',''FLOAT''),0),ISNULL(X.value(''@SellingRateB'',''FLOAT''),0),ISNULL(X.value(''@SellingRateC'',''FLOAT''),0),ISNULL(X.value(''@SellingRateD'',''FLOAT''),0),ISNULL(X.value(''@SellingRateE'',''FLOAT''),0),ISNULL(X.value(''@SellingRateF'',''FLOAT''),0),ISNULL(X.value(''@SellingRateG'',''FLOAT''),0),
		ISNULL(X.value(''@ReorderLevel'',''FLOAT''),0),ISNULL(X.value(''@ReorderQty'',''FLOAT''),0),
		'''+@CompanyGUID+''',NEWID(),'''+@UserName+''',CONVERT(FLOAT,GETDATE()),CONVERT(FLOAT,X.value(''@TillDate'',''DATETIME'')),X.value(''@Remarks'',''nvarchar(max)''),
		ISNULL(X.value(''@MaxInventoryLevel'',''FLOAT''),0) ,ISNULL(X.value(''@ReorderMinOrderQty'',''FLOAT''),0),ISNULL(X.value(''@ReorderMaxOrderQty'',''FLOAT''),0) '
		
		select @SQL=@SQL+',ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),0)' 
		from sys.columns 
		where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
				
		SET @SQL =@SQL+' FROM @XML.nodes(''/XML/Row'') as Data(X)
		WHERE X.value(''@PriceCCID'',''INT'') IS NULL'
		
		EXEC sp_executesql @SQL,N'@XML XML',@XML
			
		END
		
		UPDATE COM_CCPrices
		SET WEF=CONVERT(FLOAT,X.value('@WEF','DATETIME')),
			PriceType=ISNULL(X.value('@Type','smallint'),0),
			PurchaseRate=ISNULL(X.value('@PurchaseRate','FLOAT'),0),
			PurchaseRateA=ISNULL(X.value('@PurchaseRateA','FLOAT'),0),
			PurchaseRateB=ISNULL(X.value('@PurchaseRateB','FLOAT'),0),
			PurchaseRateC=ISNULL(X.value('@PurchaseRateC','FLOAT'),0),
			PurchaseRateD=ISNULL(X.value('@PurchaseRateD','FLOAT'),0),
			PurchaseRateE=ISNULL(X.value('@PurchaseRateE','FLOAT'),0),
			PurchaseRateF=ISNULL(X.value('@PurchaseRateF','FLOAT'),0),
			PurchaseRateG=ISNULL(X.value('@PurchaseRateG','FLOAT'),0),
			SellingRate=ISNULL(X.value('@SellingRate','FLOAT'),0),
			SellingRateA=ISNULL(X.value('@SellingRateA','FLOAT'),0),
			SellingRateB=ISNULL(X.value('@SellingRateB','FLOAT'),0),
			SellingRateC=ISNULL(X.value('@SellingRateC','FLOAT'),0),
			SellingRateD=ISNULL(X.value('@SellingRateD','FLOAT'),0),
			SellingRateE=ISNULL(X.value('@SellingRateE','FLOAT'),0),
			SellingRateF=ISNULL(X.value('@SellingRateF','FLOAT'),0),
			SellingRateG=ISNULL(X.value('@SellingRateG','FLOAT'),0),
			ReorderLevel=ISNULL(X.value('@ReorderLevel','FLOAT'),0),
			ReorderQty=ISNULL(X.value('@ReorderQty','FLOAT'),0),
			TillDate=CONVERT(FLOAT,X.value('@TillDate','DATETIME')),
			Remarks=X.value('@Remarks','nvarchar(max)'),
			MaxInventoryLevel=ISNULL(X.value('@MaxInventoryLevel','FLOAT'),0),
			ReorderMinOrderQty=ISNULL(X.value('@ReorderMinOrderQty','FLOAT'),0),
			ReorderMaxOrderQty=ISNULL(X.value('@ReorderMaxOrderQty','FLOAT'),0)
		FROM @XML.nodes('/XML/Row') as Data(X),COM_CCPrices P
		WHERE X.value('@PriceCCID','INT') IS NOT NULL AND P.PriceCCID=X.value('@PriceCCID','INT')
		
		--Delete Rows
		IF @DeleteXML IS NOT NULL AND @DeleteXML!=''
		BEGIN
			SET @XML=@DeleteXML
			DELETE FROM COM_CCPrices
			WHERE PriceCCID IN (SELECT X.value('@ID','INT') FROM @XML.nodes('/XML/Row') as Data(X))
			
		END
	END
	
	--Added to set default inactive if action exists
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,40,156)
	if(@HasAccess!=0)
		update COM_CCPricesDefn set statusid=2 where profileid=@ProfileID

	--To Set Used CostCenters with Group Check
	EXEC [spADM_SetPriceTaxUsedCC] 1,@ProfileID,1
	
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
