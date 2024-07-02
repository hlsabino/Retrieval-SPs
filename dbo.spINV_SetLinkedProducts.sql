USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetLinkedProducts]
	@ProductsXML [nvarchar](max),
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
		DECLARE @Dt FLOAT,@XML xml,@CostCenterID BIGINT,  @NodeID BIGINT    
		DECLARE @HasAccess bit
		
		SET @XML=@ProductsXML

		select @CostCenterID=X.value('@CostCenterID','bigint') , @NodeID=X.value('@NodeID','bigint')			
		FROM @XML.nodes('/XML/Row') as Data(X) 
		where X.value('@LinkedProductID','bigint')=-1
		select @CostCenterID,@NodeID
		SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
  
		
		IF @ProductsXML IS NOT NULL and @ProductsXML<>''
		BEGIN
			 DELETE FROM INV_LinkedProducts
			 WHERE CostCenterID=@CostCenterID and NodeID=@NodeID
			 and  LinkedProductID not IN (SELECT X.value('@LinkedProductID','bigint') 
			 FROM @XML.nodes('/XML/Row') as Data(X) where X.value('@LinkedProductID','bigint')>0)
			 and  ProductID in (SELECT X.value('@Product','bigint') 
			 FROM @XML.nodes('/XML/Row') as Data(X) where X.value('@Product','bigint')>0 and CostCenterID=@CostCenterID and NodeID=@NodeID)
			 
			--INSERT Linked PRODUCTS 
			INSERT INTO INV_LinkedProducts
			([ProductID]  
			,LinkType
			,[CreatedBy]  
			,[CreatedDate],CostCenterID,NodeID)
			SELECT X.value('@Product','BIGINT')
			,X.value('@LINK','INT')
			,@UserName,@Dt,@CostCenterID,@NodeID
			from @XML.nodes('/XML/Row') as Data(X)
			where X.value('@LinkedProductID','bigint')=0
			
			update INV_LinkedProducts
			set ProductID=X.value('@Product','BIGINT')
			,LinkType=X.value('@LINK','INT')
			from @XML.nodes('/XML/Row') as Data(X)
			where X.value('@LinkedProductID','bigint')>0
			and X.value('@LinkedProductID','bigint')=INV_LinkedProducts.LinkedProductID
			and CostCenterID=@CostCenterID and NodeID=@NodeID
			
		END
		else
		begin		
			 DELETE FROM INV_LinkedProducts
			 WHERE CostCenterID=@CostCenterID and NodeID=@NodeID		
		end

COMMIT TRANSACTION   
--SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
--WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;  
RETURN 1  
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
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
