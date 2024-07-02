USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCurrencies]
	@CurrencyID [int],
	@Name [nvarchar](50),
	@Symbol [nvarchar](50),
	@Change [nvarchar](50),
	@CurrencyXMl [nvarchar](max),
	@ExchangeRateXMl [nvarchar](max),
	@DimNodeID [bigint],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		
		--Declaration Section 

		DECLARE @Dt FLOAT,@XML XML ,@XMLExch XML
		DECLARE @TempGuid NVARCHAR(50) 
		DECLARE @HasAccess BIT
		declare @NumCols nvarchar(max),@IDs nvarchar(max),@ind int
		
		declare @tab table(id bigint)
		
		SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
		
		--User acces check
		IF @CurrencyID=0
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,12,1)
		END
		ELSE
		BEGIN
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,12,3)
		END
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		IF(@CurrencyXMl!='')		
			SET @XML=@CurrencyXMl				
			
		insert into @tab
		SELECT X.value('@CurrencyID','BIGINT') 
		FROM @XML.nodes('XML/Row') as DATA(X)
		WHERE  X.value('@Action','VARCHAR(10)')='Delete' 
		
		if exists(select id from @tab)
		BEGIN
			if exists(select a.CurrencyID from [ACC_DocDetails] a
					  join @tab b on a.CurrencyID=b.id)
					RAISERROR('-110',16,1)
			
			if exists(select a.CurrencyID from [INV_DocDetails] a
					  join @tab b on a.CurrencyID=b.id)
					RAISERROR('-110',16,1)
				
			set @IDs=''
			select @IDs=@IDs+convert(nvarchar,id)+',' from @tab
			
			set @IDs=substring(@IDs,0,len(@IDs)- charindex(',',reverse(@IDs))+1)
			
			set @NumCols=''
			select @NumCols =@NumCols+' or ' + a.name+' in ('+@IDs+')' from sys.columns a
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_DocNumData' and a.name like 'dccurrid%'
			
			set @NumCols=substring(@NumCols,4,len(@NumCols))	
			
			set @NumCols='if exists(select InvDocDetailsID from COM_DocNumData a
					  where '+@NumCols+'  )
					RAISERROR(''-110'',16,1)'
			print @NumCols		
			exec(@NumCols )
		END		
				

		IF (@CurrencyID=0)--Create Base Currency.  
		BEGIN--CREATE --  
			INSERT INTO [COM_Currency]  
						([Name]  
						,[Symbol]  
						,[Change]  		 
						,[IsBaseCurrency]  
						,[GUID]   
						,[CreatedBy]  
						,[CreatedDate]
						,CompanyGUID)  
				VALUES  
						(@Name   
						,@Symbol  
						,@Change 	
						,1   
						,NEWID()   
						,@UserName  
						,@Dt
						,@CompanyGUID)  

		--To get inserted record primary key
		SET @CurrencyID=SCOPE_IDENTITY()--Getting the NodeID  
		END  
		ELSE --UPDATE
		BEGIN  

			SELECT @TempGuid=[GUID] FROM [COM_Currency]  WITH(NOLOCK)   
			WHERE CurrencyID=@CurrencyID  

			IF(@TempGuid!=@Guid)  
				BEGIN  
				--ROLLBACK transaction  
					RAISERROR('-101',16,1)-- Need to Get Data From Error Table To return Error Message by Language  
				--return -7  
				END  
		
		--Updating Base Currency.
		UPDATE [COM_Currency]  
			SET  [Name] = @Name    
				,[Symbol] = @Symbol    
				,[Change] = @Change 
				,[GUID]=NEWID()     
				,[ModifiedBy] = @UserName  
				,[ModifiedDate] = @Dt  
			WHERE CurrencyID=@CurrencyID 
		END 

	 

	 IF(@CurrencyXMl!='')
		BEGIN
		SET @XML=@CurrencyXMl
		--Inserting multiple record from xml.
		INSERT INTO [COM_Currency]  
					([Name]  
					,[Symbol]  
					,[Change]  
					,[ExchangeRate]  
					,[Decimals]	
					,[IsDailyRates]	
					,[StatusID]		 
					,[GUID]   
					,[CreatedBy]  
					,[CreatedDate]
					,CompanyGUID,IsDivide)  
			SELECT		
					X.value('@Name','NVARCHAR(50)')
					,X.value('@Symbol','NVARCHAR(50)')
					,X.value('@Change','NVARCHAR(50)')
					,X.value('@ExchangeRate','FLOAT')
					,X.value('@Decimals','INT')
					,ISNULL(X.value('@Daily','BIT') , 0)
					,ISNULL(X.value('@StatusID','BIT') , 1)
					,NEWID()   
					,@UserName  
					,@Dt
					,@CompanyGUID,ISNULL(X.value('@IsDivide','BIT'),0)
					FROM @XML.nodes('XML/Row') as DATA(X)
			WHERE  X.value('@Action','VARCHAR(10)')='Insert' or X.value('@GUID','NVARCHAR(50)')=''

		
		
		DELETE a FROM [COM_ExchangeRates] a
		join @tab b on a.CurrencyID=b.id
							 
		--Delete multiple records from xml.
		DELETE a FROM [COM_Currency] a
		join @tab b on a.CurrencyID=b.id
		

		--Updating Multiple record from xml.
		UPDATE COM_Currency 
			SET  COM_Currency.NAME   = X.value('@Name','NVARCHAR(50)')
				,COM_Currency.Symbol = X.value('@Symbol','NVARCHAR(50)')
				,COM_Currency.CHANGE = X.value('@Change','NVARCHAR(50)')
				,COM_Currency.ExchangeRate = X.value('@ExchangeRate','FLOAT')
				,COM_Currency.Decimals =isnull(X.value('@Decimals','INT'),COM_Currency.Decimals)
				,COM_Currency.IsDailyRates = ISNULL(X.value('@Daily','BIT') ,COM_Currency.IsDailyRates) 
				,COM_Currency.StatusID = ISNULL(X.value('@StatusID','BIT') , 1)
				,[GUID] = NEWID()     
				,[ModifiedBy] = @UserName  
				,[ModifiedDate] = @Dt  
				,IsDivide=ISNULL(X.value('@IsDivide','BIT'),0)
			FROM COM_Currency
				INNER JOIN @XML.nodes('XML/Row') as DATA(X)
				ON X.value('@CurrencyID','INT')=COM_Currency.CURRENCYID
			WHERE  X.value('@Action','VARCHAR(10)')='Update' 
		END
		
	 IF(@ExchangeRateXMl != '')
	 BEGIN
		
		DELETE FROM [COM_ExchangeRates] 
		where DimNodeID=@DimNodeID
		
		SET @XMLExch=@ExchangeRateXMl
		DECLARE @CNT INT ,@I INT , @ExchDate FLOAT,  @CurrID BIGINT , @ExchRate FLOAT  , @CurrencyName nvarchar(100)
			CREATE TABLE #TMPEXCHRATE (ID int IDENTITY (1,1), ExchDate float, CurrencyID BIGINT , ExchRate FLOAT , CurrencyName NVARCHAR(100))

			INSERT INTO #TMPEXCHRATE (ExchDate,CurrencyID,ExchRate,CurrencyName)
			SELECT		
					convert(float,(X.value('@ExchDate','DATETIME')))
					,X.value('@CurrencyID','BIGINT')
					,X.value('@ExchRate','float')
					,X.value('@Currency','VARCHAR(100)')
					FROM @XMLExch.nodes('ExchXML/Row') as DATA(X)
			WHERE  X.value('@Action','VARCHAR(10)')='NEW'	
			 IF(@CurrencyXMl!='')
			BEGIN
			DELETE FROM #TMPEXCHRATE WHERE CurrencyID IN (
								SELECT X.value('@CurrencyID','BIGINT') 
								FROM @XML.nodes('XML/Row') as DATA(X)
								WHERE  X.value('@Action','VARCHAR(10)')='Delete' 
							)
							END 
			
			SELECT @CNT  = COUNT(ID) FROM #TMPEXCHRATE
			SET @I = 1
			WHILE (@I <= @CNT)
			 BEGIN
			  SELECT @ExchDate = ExchDate,@CurrID = CurrencyID,@ExchRate = ExchRate ,@CurrencyName = CurrencyName  FROM #TMPEXCHRATE WHERE ID = @I
			   
			   IF(@CurrID <= 0)
					SELECT  @CurrID = CurrencyID  FROM  [COM_Currency] WHERE  NAME  =@CurrencyName  
				
			

					INSERT INTO [COM_ExchangeRates] ( 
								 [ExchangeDate]  
								,[CurrencyID]	
								,[ExchangeRate] 
								,[CompanyGUID]	
								,[GUID]   
								,[CreatedBy]  
								,[CreatedDate],DimNodeID)  VALUES
							( @ExchDate
							 ,@CurrID
							 ,@ExchRate
							 ,NEWID()
							 ,NEWID()
							 ,@UserName
							 ,@Dt,@DimNodeID)

						SET @I = @I +1
			END
	 END
	 
	 if exists(select value from ADM_GlobalPreferences 
	 where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(bigint,value)>50000)
	 BEGIN
		delete from COM_ExchangeRates
		where ExchangeDate=0 and DimNodeID=@DimNodeID
		
		insert into COM_ExchangeRates
		([ExchangeDate],[CurrencyID],[ExchangeRate],[CompanyGUID]	
		,[GUID],[CreatedBy],[CreatedDate],DimNodeID)
		select 0,CurrencyID,ExchangeRate,NEWID(),NEWID(),@UserName
		,@Dt,@DimNodeID  from COM_Currency
		
	 END
	 
	 

COMMIT TRANSACTION  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;  
RETURN @CurrencyID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN		   
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	ROLLBACK TRANSACTION
	SET NOCOUNT OFF  
	RETURN -999   
END CATCH 
  
  
  
  



GO
