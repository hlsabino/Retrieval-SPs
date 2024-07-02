USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_BankStmtBalance]
	@AccountID [int],
	@Balxml [nvarchar](max),
	@Mode [int],
	@IsDateWiseBalEntry [int] = 0,
	@Companyguid [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY	
SET NOCOUNT ON

	--Declaration Section
	DECLARE @xml xml, @dt FLOAT,@mess nvarchar(max)
	
	
	if(@Mode=1)
	BEGIN
		set @dt=convert(float,getdate())
		set @xml=@Balxml
		delete from [ACC_BankStmtBalance]
		where [AccountID]=@AccountID and id not in (select X.value('@ID','INT') from @xml.nodes('/XML/ROW') as Data(X)
		 where X.value('@ID','INT')>0)
		
		INSERT INTO [ACC_BankStmtBalance]([AccountID],[Month],[Year],[Balance],Status,[Date],[CompanyGUID]
			   ,[GUID],[CreatedBy],[CreatedDate])
		 select @AccountID,X.value('@Month','INT'),X.value('@Year','INT'),X.value('@Balance','FLOAT'),X.value('@Status','INT'),CONVERT(FLOAT,X.value('@Date','DATETIME')),
		 @Companyguid,newid(),@UserName,@dt
		 from @xml.nodes('/XML/ROW') as Data(X)
		 where X.value('@ID','INT')=0
	     
	     
		 update [ACC_BankStmtBalance]
		 set [Month]=X.value('@Month','INT'),
		 [Year]=X.value('@Year','INT'),
		 [Balance]=X.value('@Balance','FLOAT'),
		 Status=X.value('@Status','INT'),
		 [Date]=CONVERT(FLOAT,X.value('@Date','DATETIME')),
		 ModifiedBy=@UserName,
		 ModifiedDate=@dt
		 from @xml.nodes('/XML/ROW') as Data(X)
		 where X.value('@ID','INT')=ID
		
		set  @mess=''
		if(@IsDateWiseBalEntry=0)
		BEGIN
			select @mess=convert(nvarchar(50),datename(m,[Month]))+' '+ convert(nvarchar(50),[Year])
			from [ACC_BankStmtBalance] WITH(NOLOCK)
			where [AccountID]=@AccountID
			group by [Month],[Year]
			having count(*)>1
			if(@mess<>'')
			BEGIN
				set @mess=@mess+' - duplicate'
				raiserror(@mess,16,1)
			END
		END
		ELSE
		BEGIN
			select @mess=CONVERT(VARCHAR(11), CONVERT(DATETIME,[Date]), 106)
			from [ACC_BankStmtBalance] WITH(NOLOCK)
			where [AccountID]=@AccountID
			group by [Date]
			having count(*)>1
			if(@mess<>'')
			BEGIN
				set @mess=@mess+' - duplicate'
				raiserror(@mess,16,1)
			END
		END
	END
	ELSE if(@Mode=2)
	BEGIN
		select ID,[Month],[Year],[Balance],Status,CONVERT(DATETIME,[Date]) as [Date]
		from [ACC_BankStmtBalance] WITH(NOLOCK)
		where [AccountID]=@AccountID
		order by [Year],[Month]
	END
	
		 
COMMIT TRANSACTION         
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	if(isnumeric(ERROR_MESSAGE())!=1)
	BEGIN
		SELECT ERROR_MESSAGE() ErrorMessage
	END
	ELSE IF ERROR_NUMBER()=50000
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
