USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SetImportUnitRates]
	@CODE [nvarchar](max) = NULL,
	@NAME [nvarchar](max) = NULL,
	@XML [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON	

  
		--Declaration Section
		DECLARE	 @Dt float ,@NodeID INT
		DECLARE  @DATA XML
      
		
		
		SET @Dt=CONVERT(FLOAT,GETDATE())--Setting Current Date  
		
	
			if( @CODE is not null and @CODE <>'')
				set @NodeID= (Select  top 1 UnitID from REN_Units WITH(NOLOCK) where Code=@CODE) 
			else
				set @NodeID= (Select  top 1 UnitID from REN_Units WITH(NOLOCK) where Name=@NAME) 
	
	IF (@XML IS NOT NULL AND @XML <> '')  
	BEGIN  
		SET @DATA=@XML  

		INSERT INTO Ren_UnitRate(UnitID,Amount,Discount,
		AnnualRent,WithEffectFrom,CompanyGUID,  
		GUID,CreatedBy,CreatedDate)  

		SELECT @NodeID,X.value('@Amount','FLOAT'),X.value('@Discount','FLOAT'),X.value('@AnnualRent','FLOAT'),   
		CONVERT(FLOAT, X.value('@WithEffFrom','DATETIME')) , @CompanyGUID, 
		NEWID(),@UserName,@Dt  
		FROM @DATA.nodes('/XML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'
		
		SELECT @NodeID,X.value('@Amount','FLOAT'),X.value('@Discount','FLOAT'),X.value('@AnnualRent','FLOAT'),   
		CONVERT(FLOAT, X.value('@WithEffFrom','DATETIME')) , @CompanyGUID, 
		NEWID(),@UserName,@Dt  
		FROM @DATA.nodes('/XML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  
	END	
 	
	
COMMIT TRANSACTION  

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID
SET NOCOUNT OFF;   
RETURN 1
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
