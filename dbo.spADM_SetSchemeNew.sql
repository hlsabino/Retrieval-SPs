USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetSchemeNew]
	@ProfileID [int],
	@ProfileName [nvarchar](50),
	@SchemeXML [nvarchar](max) = null,
	@CompanyGUID [nvarchar](50) = null,
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  
		DECLARE @Dt FLOAT ,@XML XML,@SchemeID INT,@SQL NVARCHAR(MAX),@Cnt INT
		
		DECLARE @TblXML TABLE(ID INT IDENTITY(1,1),Schemexml nvarchar(max))
		DECLARE @I INT,@Count INT,@Price FLOAT,@WEF DATETIME,@GroupID INT

		SET @Dt=convert(float,getdate())--Setting Current Date      
		SET @XML=@SchemeXML

		IF EXISTS (SELECT SchemeID FROM [ADM_SchemesDiscounts] WITH(nolock) 
		WHERE [ProfileName]=@ProfileName and ProfileID<>@ProfileID)  
		BEGIN  
			RAISERROR('-112',16,1)  
		END 

		DECLARE @TblSch TABLE(ID INT IDENTITY(1,1),SchemeID INT,FromQty FLOAT,ToQty FLOAT,FromValue FLOAT,ToValue FLOAT,Quantity FLOAT,Value FLOAT,Percentage FLOAT)
		INSERT INTO @TblSch
		select X.value('@SchemeID','INT'),ISNULL(X.value('@FromQty','float'),0),ISNULL(X.value('@ToQty','float'),0),ISNULL(X.value('@FromValue','float'),0),
		ISNULL(X.value('@ToValue','float'),0),ISNULL(X.value('@Quantity','float'),0),ISNULL(X.value('@Value','float'),0),ISNULL(X.value('@Percentage','float'),0)
		FROM @XML.nodes('/XML/Row/XML') as Data(X) where X.value('@SchemeID','INT')<>0

		DELETE FROM [ADM_SchemesDiscounts] 
		WHERE ProfileID=@ProfileID and SchemeID NOT IN (Select SchemeID From @TblSch)
			
		 if(@ProfileID=0)
			select @ProfileID=isnull(MAX(ProfileID),0)+1 from [ADM_SchemesDiscounts] with(nolock)
		else
		BEGIN
			delete a
			from ADM_SchemeProducts a WITH(NOLOCK)
			join [ADM_SchemesDiscounts] b WITH(NOLOCK) on b.SchemeID=a.SchemeID
			Where b.ProfileID=@ProfileID 
		END


		Select @Cnt=COUNT(a.SchemeID)
		FROM ADM_SchemesDiscounts a WITH(NOLOCK) 
		JOIN @TblSch b on b.SchemeID=a.SchemeID
		JOIN INV_DocDetails c WITH(NOLOCK) on c.IsQtyFreeOffer=b.SchemeID
		WHERE (a.FromQty<>b.FromQty OR a.ToQty<>b.ToQty OR a.FromValue<>b.FromValue OR a.ToValue<>b.ToValue OR 
				a.Quantity<>b.Quantity OR a.Value<>b.Value OR a.Percentage<>b.Percentage)
		
		IF(@Cnt>0)
		BEGIN
			RAISERROR('-405',16,1)  
		END

		---- INSERTING NEW ROWS
		
		set @SQL='		INSERT INTO [ADM_SchemesDiscounts]
					   ([ProfileID],[ProfileName],[ProductID],[AccountID]
					   ,FromDate,ToDate,StatusID,FromQty,ToQty,FromValue,ToValue,Percentage,IsQtyPercent
					   ,Quantity,Value,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate],SNo'
				
		select @SQL=@SQL+',['+name+']' 
		from sys.columns 
		where object_id=object_id('ADM_SchemesDiscounts') and name LIKE 'ccnid%'
				
		SET @SQL=@SQL+') 
		SELECT '+CONVERT(NVARCHAR,@ProfileID)+','''+@ProfileName+''',ISNULL(X.value(''@ProductID'',''INT''),1),ISNULL(X.value(''@AccountID'',''INT''),1),CONVERT(FLOAT,X.value(''@FromDate'',''DATETIME'')),CONVERT(FLOAT,X.value(''@ToDate'',''DATETIME'')),
				ISNULL(X.value(''@StatusID'',''INT''),0),ISNULL(X.value(''@FromQty'',''FLOAT''),0),ISNULL(X.value(''@ToQty'',''FLOAT''),0),ISNULL(X.value(''@FromValue'',''FLOAT''),0),ISNULL(X.value(''@ToValue'',''FLOAT''),0),ISNULL(X.value(''@Percentage'',''FLOAT''),0),
				ISNULL(X.value(''@IsQtyPercent'',''INT''),0),ISNULL(X.value(''@Quantity'',''FLOAT''),0),ISNULL(X.value(''@Value'',''FLOAT''),0)
				,'''+@CompanyGUID+''',NEWID(),'''+@UserName+''',CONVERT(FLOAT,GETDATE()),ISNULL(X.value(''@SNo'',''INT''),0)'
				
		select @SQL=@SQL+',ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),1)' 
		from sys.columns 
		where object_id=object_id('ADM_SchemesDiscounts') and name LIKE 'ccnid%'
						
		SET @SQL=@SQL+' FROM @XML.nodes(''/XML/Row/XML'') as Data(X) 
						WHERE X.value(''@SchemeID'',''INT'')=0 '

		EXEC sp_executesql @SQL,N'@XML XML',@XML

		---- UPDATING EXISTING ROWS

		SET @SQL ='Update [ADM_SchemesDiscounts]
				set [ProfileID]         ='+CONVERT(NVARCHAR,@ProfileID)+'
				   ,[ProfileName]		='''+@ProfileName+'''
				   ,[FromDate]			=CONVERT(FLOAT,X.value(''@FromDate'',''DATETIME''))
				   ,[ToDate]			=CONVERT(FLOAT,X.value(''@ToDate'',''DATETIME''))
				   ,[StatusID]			=ISNULL(X.value(''@StatusID'',''INT''),0)
				   ,[FromQty]			=ISNULL(X.value(''@FromQty'',''float''),0)
				   ,[ToQty]				=ISNULL(X.value(''@ToQty'',''float''),0)
				   ,[FromValue]			=ISNULL(X.value(''@FromValue'',''float''),0)
				   ,[ToValue]			=ISNULL(X.value(''@ToValue'',''float''),0)
				   ,[Percentage]		=ISNULL(X.value(''@Percentage'',''float''),0)
				   ,IsQtyPercent		=ISNULL(X.value(''@IsQtyPercent'',''INT''),0)
				   ,[Quantity]			=ISNULL(X.value(''@Quantity'',''float''),0)
				   ,[Value]				=ISNULL(X.value(''@Value'',''float''),0)
				   ,[ProductID]			=ISNULL(X.value(''@ProductID'',''INT''),1)
				   ,[UOMID]				=ISNULL(X.value(''@UOMID'',''INT''),1)
				   ,[AccountID]			=ISNULL(X.value(''@AccountID'',''INT''),1)
				   ,[CompanyGUID]		='''+@CompanyGUID+'''                   
				   ,ModifiedBy			='''+@UserName+'''
				   ,ModifiedDate		=CONVERT(FLOAT,GETDATE())
				   ,SNo			=ISNULL(X.value(''@SNo'',''INT''),0)'
				   
				select @SQL=@SQL+',['+name+']=ISNULL(X.value(''@'+REPLACE(name,'NID','')+''',''INT''),1)' 
				from sys.columns 
				where object_id=object_id('ADM_SchemesDiscounts') and name LIKE 'ccnid%'
				
				 SET @SQL=@SQL+' FROM @XML.nodes(''/XML/Row/XML'') as Data(X) 
								 JOIN [ADM_SchemesDiscounts] a WITH(NOLOCK) on a.SchemeID=Data.X.value(''@SchemeID'',''INT'')
								 WHERE X.value(''@SchemeID'',''INT'')<>0 '
				 
				 EXEC sp_executesql @SQL,N'@XML XML',@XML


			INSERT INTO ADM_SchemeProducts([SchemeID],[ProductID],[Quantity],[Value],[Percentage] ,IsQtyPercent,Dim1,SchemeRowSNo)
			Select a.SchemeID,ISNULL(X.value('@ProductID','INT'),1),ISNULL(X.value('@Quantity','float'),0)
			,ISNULL(X.value('@Value','float'),0),ISNULL(X.value('@Percentage','float'),0)
			,ISNULL(X.value('@IsQtyPercent','BIT'),0),X.value('@Dim1','INT'),X.value('@SchemeRowSNo','INT')
			FROM @XML.nodes('/XML/Row/XML/ProductsXML/Row') as Data(X) 
			JOIN ADM_SchemesDiscounts a WITH(NOLOCK) on a.SNo=Data.X.value('@SchemeRowSNo','INT')
			WHERE a.ProfileID=@ProfileID

		---------------------------------
		
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
		--if(ERROR_MESSAGE()=-405)
		--	SELECT ErrorMessage+' at row no.'+convert(nvarchar,@I) ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		--else
		if(ERROR_MESSAGE()=-405)
		BEGIN
			declare @vno nvarchar(200)
			select @vno=VoucherNo from INV_DocDetails  with(nolock) where IsQtyFreeOffer IN(Select SchemeID From @TblSch)
			SELECT ErrorMessage+' :'+convert(nvarchar,@vno) ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		else
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
