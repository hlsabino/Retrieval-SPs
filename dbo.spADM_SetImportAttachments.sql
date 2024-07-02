USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportAttachments]
	@AttXML [nvarchar](max),
	@CCID [int],
	@Name [nvarchar](max) = null,
	@Code [nvarchar](max) = null,
	@IsCode [bit] = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  
		DECLARE @NodeID INT ,@SQL NVARCHAR(MAX),@prim NVARCHAR(300),@TABLEname NVARCHAR(300),@dt Float
		
		select @dt=convert(float,getdate())
		select @TABLEname=TableName,@prim=PrimaryKey from adm_features WITH(NOLOCK) where FeatureID=@CCID
		
		if(@IsCode=1)
		BEGIN			
			set @SQL='select @NodeID='+@prim+' from '+@TABLEname + ' with(nolock) where '
			if(@CCID=3)
				set @SQL=@SQL+'ProductCode='
			else if(@CCID=2)
				set @SQL=@SQL+'AccountCode='
			else if(@CCID=73)
				set @SQL=@SQL+'CaseNumber='
			else if(@CCID=86 or @CCID=92 or @CCID=93 or @CCID > 50000)
				set @SQL=@SQL+'Code='	
			else if(@CCID=94)
				set @SQL=@SQL+'TenantCode='
			else if(@CCID=95)
				set @SQL=@SQL+'sno='			
							
			set @SQL=@SQL+''''+@Code+''''
				
		END	
		else
		BEGIN
			set @SQL='select @NodeID='+@prim+' from '+@TABLEname + ' with(nolock) where '
			if(@CCID=3)
				set @SQL=@SQL+'ProductName='
			else if(@CCID=2)
				set @SQL=@SQL+'AccountName='
			else if(@CCID=73)
				set @SQL=@SQL+'CaseNumber='
			else if(@CCID=86)
				set @SQL=@SQL+'Company='
			else if(@CCID=92 or @CCID=93 or @CCID > 50000)
				set @SQL=@SQL+'Name='	
			else if(@CCID=94)
				set @SQL=@SQL+'FirstName='
			else if(@CCID=95)
				set @SQL=@SQL+'sno='			
							
			set @SQL=@SQL+''''+@Name +''''	
		END	
		
		EXEC sp_executesql @SQL,N'@NodeID INT OUTPUT',@NodeID output
		
		exec [spCOM_SetAttachments] @NodeID,@CCID,@AttXML,@UserName,@dt
 		
	  
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;  
RETURN @NodeID
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		if isnumeric(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		else
			SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber
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
