USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCostCenterLanguageData]
	@ResourceData [nvarchar](300),
	@CostCenterName [nvarchar](50),
	@UserName [nvarchar](50),
	@RESOURCEID [bigint] OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON
			
	--Declaration Section
	DECLARE @RESOURCEMAX BIGINT

	SELECT @RESOURCEMAX=MAX(ResourceID) FROM [COM_LanguageResources]
			SET @RESOURCEMAX=@RESOURCEMAX+1
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
			   ,@ResourceData 
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
			   ,@ResourceData 
			   ,2
			   ,'Arabic'
			   ,@ResourceData 
			   ,NEWID() 
			   ,@UserName
			   ,CONVERT(FLOAT,GETDATE()) 
			   ,@CostCenterName)
		SET @RESOURCEID=@RESOURCEMAX
COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN @RESOURCEID
END TRY
BEGIN CATCH  
	 SELECT 'ERROR IN INSERTING'
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  



GO
