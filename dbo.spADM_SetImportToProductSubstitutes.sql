USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetImportToProductSubstitutes]
	@ProductName [nvarchar](max) = null,
	@ProductCode [nvarchar](max) = null,
	@SubstituteGroupName [nvarchar](300) = NULL,
	@IsCode [bit] = 0,
	@SubstituteXML [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	--Declaration Section  
	DECLARE @XML XML,@TSQL NVARCHAR(MAX),@SQL NVARCHAR(MAX),@ProductID INT=0,@I INT,@COUNT INT,@SubstituteGroupID BIGINT=0,@SubstituteNewGrpID BIGINT
		
	DECLARE @TAB TABLE(ID INT IDENTITY(1,1),SNO INT,ProductID BIGINT,SubstituteGroup NVARCHAR(300),SubstGroupID BIGINT,SubProdID BIGINT
	,Status NVARCHAR(50),SMessage NVARCHAR(200),ExRowNo INT)
	
	SET @XML=@SubstituteXML
	
	--IF @IsCode=0 AND EXISTS(SELECT ProductID FROM dbo.INV_Product with(nolock) where ProductName=@ProductName)
	IF @IsCode=0
	BEGIN
		SET @ProductID=ISNULL((SELECT TOP 1 ProductID FROM dbo.INV_Product with(nolock) where ProductName=@ProductName),0)
		
		INSERT INTO @TAB
		SELECT X.value('@SNO','INT') SNO,@ProductID ProductID,@SubstituteGroupName,ISNULL(S.SubstituteGroupID,0),ISNULL(P.ProductID,0) SubsProductID
		,'','',ISNULL((X.value('@ExRowNo','INT')),0)
		FROM @XML.nodes('/SubstituteXML/Row') as Data(X)
		LEFT JOIN INV_Product P WITH(NOLOCK) ON P.ProductName=X.value('@SubProduct','NVARCHAR(500)')
		LEFT JOIN (SELECT SubstituteGroupName,SubstituteGroupID FROM INV_ProductSubstitutes WITH(NOLOCK) GROUP BY SubstituteGroupName,SubstituteGroupID) AS S ON S.SubstituteGroupName=@SubstituteGroupName
	END 
	--ELSE IF @IsCode=1 AND EXISTS(SELECT ProductID FROM dbo.INV_Product with(nolock) where ProductCode=@ProductCode)
	ELSE IF @IsCode=1
	BEGIN
		SET @ProductID=ISNULL((SELECT TOP 1 ProductID FROM dbo.INV_Product with(nolock) where ProductCode=@ProductCode),0)
		
		INSERT INTO @TAB
		SELECT X.value('@SNO','INT') SNO,@ProductID ProductID,@SubstituteGroupName,ISNULL(S.SubstituteGroupID,0),ISNULL(P.ProductID,0) SubsProductID
		,'','',ISNULL((X.value('@ExRowNo','INT')),0)
		FROM @XML.nodes('/SubstituteXML/Row') as Data(X)
		LEFT JOIN INV_Product P WITH(NOLOCK) ON P.ProductCode=X.value('@SubProduct','NVARCHAR(500)')
		LEFT JOIN (SELECT SubstituteGroupName,SubstituteGroupID FROM INV_ProductSubstitutes WITH(NOLOCK) GROUP BY SubstituteGroupName,SubstituteGroupID) AS S ON S.SubstituteGroupName=@SubstituteGroupName
	END	
	
	SELECT @I=1,@COUNT=COUNT(*) FROM @TAB
	
	SELECT @SubstituteGroupID=ISNULL(SubstituteGroupID,0) FROM INV_ProductSubstitutes WITH(NOLOCK) WHERE SubstituteGroupName=@SubstituteGroupName
	
	IF (@SubstituteXML IS NOT NULL AND @SubstituteXML <> '')
	BEGIN
		IF(@SubstituteGroupID=0)
		BEGIN
			SELECT @SubstituteNewGrpID=ISNULL(MAX(SubstituteGroupID),0)+1 FROM [INV_ProductSubstitutes] WITH(NOLOCK)
			WHILE @I<=@COUNT
			BEGIN
				
				IF(@ProductID=0)
				BEGIN
					UPDATE @TAB SET Status='Fail' WHERE ID=@I
					UPDATE @TAB SET SMessage='Invalid Main Product' WHERE ID=@I
				END
				
				IF((SELECT SubProdID FROM @TAB WHERE ID=@I)=0)
				BEGIN				
					UPDATE @TAB SET Status='Fail' WHERE ID=@I
					UPDATE @TAB SET SMessage=SMessage+' Invalid Sub Product' WHERE ID=@I
				END	
				ELSE
				BEGIN
					INSERT INTO [INV_ProductSubstitutes](SubstituteGroupID,SubstituteGroupName,[ProductID],[SProductID],[GUID],[CreatedBy],[CreatedDate],[SNO])
					SELECT @SubstituteNewGrpID,SubstituteGroup,SubProdID,0,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),SNO
					FROM @TAB WHERE ID=@I					
					
					UPDATE @TAB SET Status='Success' WHERE ID=@I
					UPDATE @TAB SET SMessage='Saved Successfully' WHERE ID=@I
				END
				SET @I=@I+1
			END			
			IF(@ProductID<>0)
			BEGIN
				INSERT INTO [INV_ProductSubstitutes](SubstituteGroupID,SubstituteGroupName,[ProductID],[SProductID],[GUID],[CreatedBy],[CreatedDate],[SNO])
				SELECT @SubstituteNewGrpID,SubstituteGroup,@ProductID,0,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),NULL
				FROM @TAB WHERE ID=1
			END			
		END
		ELSE
		BEGIN					
			DELETE S FROM INV_ProductSubstitutes S WITH(NOLOCK) WHERE SubstituteGroupName=@SubstituteGroupName
			
			WHILE @I<=@COUNT
			BEGIN
				IF(@ProductID=0)
				BEGIN
					UPDATE @TAB SET Status='Fail' WHERE ID=@I
					UPDATE @TAB SET SMessage='Invalid Main Product' WHERE ID=@I
				END				
				
				IF((SELECT SubProdID FROM @TAB WHERE ID=@I)=0)
				BEGIN				
					UPDATE @TAB SET Status='Fail' WHERE ID=@I
					UPDATE @TAB SET SMessage=SMessage+' Invalid Sub Product' WHERE ID=@I
				END	
				ELSE
				BEGIN					
					INSERT INTO [INV_ProductSubstitutes](SubstituteGroupID,SubstituteGroupName,[ProductID],[SProductID],[GUID],[CreatedBy],[CreatedDate],[SNO])
					SELECT SubstGroupID,SubstituteGroup,SubProdID,0,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),SNO
					FROM @TAB WHERE ID=@I
					
					UPDATE @TAB SET Status='Success' WHERE ID=@I
					UPDATE @TAB SET SMessage='Saved Successfully' WHERE ID=@I
				END
				
				SET @I=@I+1
			END			
			IF(@ProductID<>0)
			BEGIN
				INSERT INTO [INV_ProductSubstitutes](SubstituteGroupID,SubstituteGroupName,[ProductID],[SProductID],[GUID],[CreatedBy],[CreatedDate],[SNO])
				SELECT SubstGroupID,SubstituteGroup,@ProductID,0,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),NULL
				FROM @TAB WHERE ID=1
			END			
		END
	END	
	  
COMMIT TRANSACTION  
--ROLLBACK TRANSACTION
   
SET NOCOUNT OFF;  
SELECT * FROM @TAB
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
