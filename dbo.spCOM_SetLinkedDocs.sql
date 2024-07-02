USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetLinkedDocs]
	@CostCenterID [bigint] = 0,
	@Xml [nvarchar](max) = '',
	@CompanyGUID [nvarchar](100),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		 
		 Declare @Data xml
		--SP Required Parameters Check
		IF @Xml='' OR @CostCenterID=0
		BEGIN
			RAISERROR('-100',16,1)
		END
 
		set @Data=@Xml
		
		  DELETE FROM [COM_DocumentLinkDef]              
		  WHERE CostCenterIDBase=78             
	  
	    INSERT INTO [COM_DocumentLinkDef]              
				([CostCenterIDBase]              
				,[CostCenterColIDBase]              
				,[CostCenterIDLinked]              
				,[CostCenterColIDLinked]              
				,[IsDefault]              
				,[CompanyGUID]              
				,[GUID]              
				,[CreatedBy]              
				,[CreatedDate])  
				  SELECT 78,1,X.value('@CostCenterID','bigint'),1,0
				  ,@CompanyGUID,NEWID() ,@UserName,CONVERT(FLOAT,GETDATE())
				 from @Data.nodes('/XML/Row') as Data(X) 

 
 
	  
COMMIT TRANSACTION  
SELECT * FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID   
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
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
