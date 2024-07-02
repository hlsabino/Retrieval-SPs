USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetInsertResourceData]
	@ResourceName [nvarchar](300),
	@ResourceData [nvarchar](300),
	@CostCenterName [nvarchar](50),
	@UserName [nvarchar](50),
	@NoTimes [int],
	@RESOURCEID [bigint] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON
			
	--Declaration Section
	DECLARE @RESOURCEMAX BIGINT,@I INT
	SET @I=1
	
	WHILE @I<=@NoTimes
	BEGIN
		SELECT @RESOURCEMAX=MAX(RESOURCEID)+1 FROM [COM_LanguageResources] WITH(NOLOCK)
		
		--INSERT FOR ENGLISH
		INSERT INTO [COM_LanguageResources]([ResourceID],[ResourceName]
		   ,[LanguageID]
		   ,[LanguageName]
		   ,[ResourceData]
		   ,[GUID] 
		   ,[CreatedBy]
		   ,[CreatedDate] 
		   ,[FEATURE])
		VALUES
		   (@RESOURCEMAX
		   ,@ResourceName
		   ,1
		   ,'English'
		   ,@ResourceData
		   ,NEWID() 
		   ,@UserName
		   ,CONVERT(FLOAT,GETDATE()) 
		   ,@CostCenterName)

		--INSERT FOR ARABIC
		INSERT INTO [COM_LanguageResources]([ResourceID],[ResourceName]
		   ,[LanguageID]
		   ,[LanguageName]
		   ,[ResourceData]
		   ,[GUID] 
		   ,[CreatedBy]
		   ,[CreatedDate] 
		   ,[FEATURE])
		VALUES
		   (@RESOURCEMAX
		   ,@ResourceName
		   ,2
		   ,'Arabic'
		   ,@ResourceData
		   ,NEWID() 
		   ,@UserName
		   ,CONVERT(FLOAT,GETDATE()) 
		   ,@CostCenterName)
		   
		SET @RESOURCEID=@RESOURCEMAX
		SET @I=@I+1
	END
COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN @RESOURCEID
END TRY
BEGIN CATCH  
	 SELECT 'ERROR IN INSERTION'
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  






GO
