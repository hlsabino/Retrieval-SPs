USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_SetGroupImage]
	@DATA [nvarchar](max) = NULL,
	@GrpID [bigint],
	@FeatureID [bigint],
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
		DECLARE @Dt FLOAT ,@HasAccess BIT ,@XML xml
		SET @Dt=CONVERT(float,GETDATE())--Setting Current Date    
  		IF (@DATA IS NOT NULL AND @DATA <> '')
		BEGIN
			SET @XML=@DATA  
			--If Action is DELETE then delete Attachments
			DELETE FROM COM_Files
			WHERE FeaturePK IN(SELECT X.value('@FeaturePK','bigint')
			FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)
			WHERE X.value('@Action','NVARCHAR(10)')='NEW') AND IsProductImage=1 AND FeatureID=3  
			
			INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
			FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,
			GUID,CreatedBy,CreatedDate)
			SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),
			X.value('@RelativeFileName','NVARCHAR(50)'),
			X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),
			X.value('@IsProductImage','bit'),3,3,X.value('@FeaturePK','bigint'),
			X.value('@GUID','NVARCHAR(50)'),@UserName,@Dt
			FROM @XML.nodes('/AttachmentsXML/Row') as Data(X) 	
			WHERE X.value('@Action','NVARCHAR(10)')='NEW' 
		
		END
	 

COMMIT TRANSACTION  
select @GrpID
select * from com_files where featureid=3 and FeaturePK in  (select productid from INV_Product where ParentID=652) 
Return @GrpID
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID   
SET NOCOUNT OFF;  
RETURN 0  
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		 
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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


--select * from com_files where featureid=3 and FeaturePK in  (select productid from INV_Product where ParentID=652)
GO
