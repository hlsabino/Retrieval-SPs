USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_SetDocumentBulkMapping]
	@DATA [nvarchar](max),
	@NAME [nvarchar](200),
	@Type [nvarchar](200),
	@ID [bigint],
	@CompanyGUID [varchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  

	DECLARE @XML XML
	DECLARE @Dt float
	SET @XML=@DATA
	SET @Dt=convert(float,getdate())--Setting Current Date  
  
IF @ID =-100
BEGIN
	SELECT @ID=ISNULL(MAX([BulkID]),0)+1 FROM [COM_DocumentBulkMapping]
END
ELSE
BEGIN
	DELETE FROM [COM_DocumentBulkMapping] WHERE [BulkID]=@ID
END

  INSERT INTO  [COM_DocumentBulkMapping]
           ([BulkID]
           ,[Name],[MappingType]
           ,[Document],[Type] 
           ,[CostCenterColID]
           ,[ReadOnly] ,[Mandatory]
           ,[Update]
           ,[Order]
           ,[CompanyGUID]      
           ,[CreatedBy]
           ,[CreatedDate]
           )
SELECT @ID,@NAME,@Type,X.value('@CostCenterID','bigint'),X.value('@Type','int'),X.value('@CostCenterColID','BigInt'),  
   X.value('@Readonly','int'),X.value('@Mandatory','int'),X.value('@Update','int'),X.value('@Order','int'),@CompanyGUID,@UserName,@Dt  
   FROM @XML.nodes('/XML/Row') as Data(X)    
    

 
  
COMMIT TRANSACTION      
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @ID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
     
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=2627  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-116 AND LanguageID=@LangID  
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
