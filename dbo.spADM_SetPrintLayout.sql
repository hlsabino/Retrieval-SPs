USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetPrintLayout]
	@LayoutID [int],
	@DocumentID [int],
	@DocType [int] = 0,
	@LayoutName [nvarchar](50),
	@Preferences [nvarchar](max),
	@BodyFields [nvarchar](max),
	@ReportHeader [nvarchar](max),
	@PageHeader [nvarchar](max),
	@PageFooter [nvarchar](max),
	@ReportFooter [nvarchar](max),
	@ExtendedDataQuery [nvarchar](max),
	@FormulaFieldsXML [nvarchar](max) = null,
	@SaveAsLayoutID [int] = 0,
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
  --Declaration Section  
  DECLARE @TempGuid NVARCHAR(50),@HasAccess BIT  
  
  --SP Required Parameters Check  
  IF @DocumentID =0 OR @LayoutName='' OR @LayoutName IS NULL  
  BEGIN  
   RAISERROR('-100',16,1)  
  END  
    
  --User acces check  
  IF @LayoutID=0  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,39,27)  
  END  
  ELSE  
  BEGIN  
   SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,39,27)  
  END  
  
  --IF @HasAccess=0  
  --BEGIN  
  -- RAISERROR('-105',16,1)  
  --END  
  
	IF @SaveAsLayoutID=0
	BEGIN
		IF @LayoutID=0--------START INSERT RECORD-----------  
		BEGIN
			IF EXISTS (SELECT DocumentID FROM ADM_DocPrintLayouts WITH(nolock) WHERE DocumentID=@DocumentID AND Name=@LayoutName) 
				RAISERROR('-112',16,1)
			
			INSERT INTO ADM_DocPrintLayouts  
			(DocumentID,DocType  
			,[Name]  
			,IsDefault  
			,Preferences  
			,BodyFields  
			,ReportHeader  
			,PageHeader  
			,PageFooter  
			,ReportFooter  
			,ExtendedDataQuery  
			,FormulaFields
			,[GUID]   
			,[CreatedBy]  
			,[CreatedDate],CompanyGUID)  
			VALUES  
			(@DocumentID,@DocType  
			,@LayoutName  
			,0  
			,@Preferences  
			,@BodyFields  
			,@ReportHeader  
			,@PageHeader  
			,@PageFooter  
			,@ReportFooter  
			,@ExtendedDataQuery  
			,@FormulaFieldsXML
			,NEWID()   
			,@UserName  
			,CONVERT(FLOAT,GETDATE()),@CompanyGUID)  

			--To get inserted record primary key  
			SET @LayoutID=SCOPE_IDENTITY()

			INSERT INTO ADM_DocPrintLayoutsMap(UserID,RoleID,GroupID,DocPrintLayoutID,CreatedBy,CreatedDate)
			SELECT UserID,0,0,@LayoutID,@UserName,CONVERT(FLOAT,GETDATE()) FROM ADM_Users with(nolock)
		END--------END INSERT RECORD-----------  
		ELSE--------START UPDATE RECORD-----------  
		BEGIN
			IF EXISTS (SELECT DocumentID FROM ADM_DocPrintLayouts WITH(nolock) WHERE DocumentID=@DocumentID and DocPrintLayoutID!=@LayoutID AND Name=@LayoutName) 
				RAISERROR('-112',16,1)

			UPDATE ADM_DocPrintLayouts  
			SET Preferences = @Preferences  
			,Name=@LayoutName 
			,BodyFields = @BodyFields  
			,ReportHeader = @ReportHeader  
			,PageHeader = @PageHeader  
			,PageFooter = @PageFooter  
			,ReportFooter =@ReportFooter  
			,ExtendedDataQuery=@ExtendedDataQuery
			,FormulaFields=@FormulaFieldsXML
			,[GUID] = NEWID()    
			,[ModifiedBy] = @UserName  
			,[ModifiedDate] = CONVERT(FLOAT,GETDATE())  
			WHERE DocPrintLayoutID=@LayoutID  
		END--------END UPDATE RECORD-----------  
	END
	ELSE
	BEGIN
		IF EXISTS (SELECT DocumentID FROM ADM_DocPrintLayouts WITH(nolock) WHERE DocumentID=@DocumentID and DocPrintLayoutID!=@SaveAsLayoutID AND Name=@LayoutName) 
			RAISERROR('-112',16,1)
				
		UPDATE ADM_DocPrintLayouts  
			SET Preferences = @Preferences  
			,BodyFields = @BodyFields  
			,ReportHeader = @ReportHeader  
			,PageHeader = @PageHeader  
			,PageFooter = @PageFooter  
			,ReportFooter =@ReportFooter  
			,ExtendedDataQuery=@ExtendedDataQuery
			,FormulaFields=@FormulaFieldsXML
			,[GUID] = NEWID()    
			,[ModifiedBy] = @UserName  
			,[ModifiedDate] = CONVERT(FLOAT,GETDATE())  
			WHERE DocPrintLayoutID=@SaveAsLayoutID 
		SET @LayoutID=@SaveAsLayoutID
	END
		   
COMMIT TRANSACTION    
SELECT * FROM ADM_DocPrintLayouts WITH(nolock) WHERE DocPrintLayoutID=@LayoutID    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;    
RETURN @LayoutID    
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT * FROM ADM_DocPrintLayouts WITH(nolock) WHERE DocPrintLayoutID=@LayoutID     
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
