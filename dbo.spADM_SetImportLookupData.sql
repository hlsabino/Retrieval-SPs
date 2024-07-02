USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportLookupData]
	@DataXML [nvarchar](max),
	@LookType [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY
SET NOCOUNT ON;  
	--Declaration Section
	DECLARE	@return_value int,@failCount int,@I INT,@Cnt INT,@NodeID BIGINT
	DECLARE @XML XML,@Name NVARCHAR(MAX)
	DECLARE @temptbl AS TABLE(ID INT IDENTITY(1,1),Name NVARCHAR(MAX))
	
	SET @XML=@DataXML
	INSERT INTO @temptbl(Name)
	SELECT X.value('@lookup','nvarchar(max)')
	FROM @XML.nodes('/XML/Row') as Data(X)			
		
	SELECT @I=1, @Cnt=count(ID) FROM @temptbl 
	set @failCount=0
	WHILE(@I<=@Cnt)  
	BEGIN
		begin try
			set @NodeID=0
			select @Name=Name from @temptbl where ID=@I
			select @NodeID=NodeID from COM_Lookup with(nolock) where Name=@Name AND LookupType=@LookType
			if(@NodeID=0)
			begin
				EXEC spADM_SetLookup @LookType,0,@Name,@Name,@Name,1,0,null,@CompanyGUID,@UserName,@UserID,@LangID
			end
		End Try
		Begin Catch
			set @failCount=@failCount+1
		end Catch
	 
		set @I=@I+1

	end

	
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
SELECT NodeID,Name FROM COM_Lookup WITH(nolock) WHERE LookupType=@LookType
SET NOCOUNT OFF;  
RETURN @NodeID  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM COM_Lookup WITH(nolock) WHERE NodeID=@NodeID  
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
