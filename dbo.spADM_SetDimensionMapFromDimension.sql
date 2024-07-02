USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetDimensionMapFromDimension]
	@ProfileID [int],
	@CCID [int] = 0,
	@CCNODEID [int] = 0,
	@DataXml [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](200),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
   
	Declare @XML XML,@dt float,@ProfileName NVARCHAR(300),@DefXml NVARCHAR(MAX),@SQL NVARCHAR(MAX)
	
	SELECT @ProfileName=PROFILENAME,@DefXml=[DefXml] FROM COM_DimensionMappings WITH(NOLOCK) WHERE ProfileID=@ProfileID
  --SP Required Parameters Check  
	set @dt=CONVERT(float,getdate())

  SET @XML=@DataXml 
  
	set @SQL='INSERT INTO [COM_DimensionMappings]
           ([ProfileID]
           ,[ProfileName]
           ,[ProductID]
           ,[AccountID]
           ,[alpha1]
           ,[alpha2]
           ,[alpha3]
           ,[alpha4]
           ,[alpha5]
           ,[DefXml]
           ,[CompanyGUID]
           ,[GUID]           
           ,[CreatedBy]
           ,[CreatedDate]'
			
			select @SQL=@SQL+',['+name+']' 
			from sys.columns 
			where object_id=object_id('COM_DimensionMappings') and name LIKE 'ccnid%'
				
			SET @SQL=@SQL+')
		select
           '+CONVERT(INT,@ProfileID)+'
           ,'''+@ProfileName+'''
           ,isnull(X.value(''@ProductID'',''INT''),1)
           ,isnull(X.value(''@AccountID'',''INT''),1)
           ,X.value(''@alpha1'',''nvarchar(max)'')
           ,X.value(''@alpha2'',''nvarchar(max)'')
           ,X.value(''@alpha3'',''nvarchar(max)'')
           ,X.value(''@alpha4'',''nvarchar(max)'')
           ,X.value(''@alpha5'',''nvarchar(max)'')
           ,'''+@DefXml+'''
           ,'''+@CompanyGUID+'''
           ,NEWID()           
           ,'''+@UserName+'''
           ,'+CONVERT(FLOAT,@dt)
			
			select @SQL=@SQL+',ISNULL(X.value(''@'+name+''',''INT''),1)' 
			from sys.columns 
			where object_id=object_id('COM_DimensionMappings') and name LIKE 'ccnid%'
					
			SET @SQL=@SQL+'
			from @XML.nodes(''/XML/Row'') as Data(X)  
			where X.value(''@DimMapID'',''INT'')=0
			and X.value(''@Action'',''NVARCHAR(300)'')=''NEW'''
			
	EXEC sp_executesql @SQL,N'@XML XML',@XML
			
  set @SQL='UPDATE [COM_DimensionMappings]
   SET [ProfileName] = '''+@ProfileName+'''
      ,[ProductID] = isnull(X.value(''@ProductID'',''INT''),1)
      ,[AccountID] =isnull(X.value(''@AccountID'',''INT''),1)
      ,[alpha1] = X.value(''@alpha1'',''nvarchar(max)'')
      ,[alpha2] = X.value(''@alpha2'',''nvarchar(max)'')
      ,[alpha3] = X.value(''@alpha3'',''nvarchar(max)'')
      ,[alpha4] = X.value(''@alpha4'',''nvarchar(max)'')
      ,[alpha5] = X.value(''@alpha5'',''nvarchar(max)'')
      ,[DefXml] = '''+@DefXml+''''            
				   
	select @SQL=@SQL+',['+name+']=ISNULL(X.value(''@'+name+''',''INT''),1)' 
	from sys.columns 
	where object_id=object_id('COM_DimensionMappings') and name LIKE 'ccnid%'
		
	SET @SQL=@SQL+'
	  from @XML.nodes(''/XML/Row'') as Data(X) 
	  WHERE DimensionMappingsID=X.value(''@DimMapID'',''INT'')
	  and X.value(''@DimMapID'',''INT'')>0 and X.value(''@Action'',''NVARCHAR(300)'')=''UPDATE'''
			
	EXEC sp_executesql @SQL,N'@XML XML',@XML
  
	DELETE FROM [COM_DimensionMappings]  
	WHERE DimensionMappingsID IN(SELECT X.value('@DimMapID','INT')  
	FROM @XML.nodes('/XML/Row') as Data(X)  
	WHERE X.value('@Action','NVARCHAR(10)')='DELETE')    
	
COMMIT TRANSACTION   
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID 
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
