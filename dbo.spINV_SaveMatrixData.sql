USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SaveMatrixData]
	@ID [bigint],
	@Name [nvarchar](100),
	@COLUMNSXML [nvarchar](max),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
		--Declaration Section  
		DECLARE @Dt FLOAT,@ColsXML xml , @MatrixID int
		DECLARE @HasAccess bit  

		SET @Dt=CONVERT(FLOAT,GETDATE()) 

		SET @ColsXML=@COLUMNSXML  
		if(@ID=0)
		BEGIN 
			SELECT @MatrixID=MAX(ProfileID)+1 FROM INV_MatrixDef
		
		END
		else
		BEGIN
			SET @MatrixID=@ID
			IF EXISTS (SELECT ProfileID FROM INV_MatrixDef WITH(NOLOCK) WHERE ProfileName=@Name AND ProfileID <> @MatrixID)
			BEGIN
				RAISERROR('-112',16,1)
			END 
		END
		
		 if @MatrixID is  null
			set @MatrixID=1
		
		
		if(@ID>0)
			DELETE from INV_MatrixDef WHERE  ProfileID=@MatrixID 
		
		--INSERT ATTRIBUTES
		INSERT INTO INV_MatrixDef  
		( ProfileID  
		 ,ProfileName  
		 ,AttributeID, barcodeid
		 ,GUID
		 ,[CreatedBy]  
		 ,[CreatedDate])  
		SELECT     @MatrixID,@Name
		 ,X.value('@AttributeID','bigint')      
		 ,X.value('@BarcodeID','bigint')   
		 ,newid()   
		 ,@UserName  
		 ,@Dt  
		FROM @ColsXML.nodes('/XML/Row') as Data(X)  
		 

		
COMMIT TRANSACTION
SELECT * FROM INV_MatrixDef WITH(NOLOCK) WHERE ProfileID=@MatrixID
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID     
SET NOCOUNT OFF;  
RETURN @MatrixID  
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT * FROM INV_MatrixDef WITH(NOLOCK) WHERE ProfileID=@MatrixID
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
