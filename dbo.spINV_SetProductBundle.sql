USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetProductBundle]
	@BundleXML [nvarchar](max),
	@ProductID [bigint],
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
	DECLARE @Dt FLOAT,@XML xml  
	DECLARE @HasAccess bit

	SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  

	--Check for manadatory paramters    
	IF(@ProductID < 1 and @ProductID>-10000)
	BEGIN   	    
		RAISERROR('-100',16,1)   		    
	END   
	
	IF @BundleXML IS NOT NULL OR @BundleXML<>''
	BEGIN
		SET @XML=@BundleXML
	
		 DELETE FROM [INV_ProductBundles]  
		 WHERE ParentProductID=@ProductID 

		--INSERT PRODUCTS INTO A BUNDLE
		INSERT INTO [INV_ProductBundles]([ParentProductID],[ProductID],Quantity,UNIT,Rate,LinkType,[GUID],[CreatedBy],[CreatedDate],CompanyGUID,Remarks,ModifierName,MinSelect,MaxSelect)
		SELECT @ProductID,X.value('@Product','BIGINT'),X.value('@Qty','FLOAT'),X.value('@Unit','BIGINT'),X.value('@Rate','FLOAT'),X.value('@LINK','INT'),NEWID(),@UserName,@Dt,@CompanyGUID,X.value('@Remarks','NVARCHAR(MAX)'),
		ISNULL(X.value('@ModifierName','NVARCHAR(MAX)'),''),ISNULL(X.value('@MinSelect','INT'),0),ISNULL(X.value('@MaxSelect','INT'),0)
		from @XML.nodes('/XML/Row') as Data(X)
	END
COMMIT TRANSACTION       
SET NOCOUNT OFF;  
RETURN @ProductID  
END TRY
BEGIN CATCH  
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH



GO
