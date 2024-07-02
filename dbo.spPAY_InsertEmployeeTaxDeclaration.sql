USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_InsertEmployeeTaxDeclaration]
	@Year [int],
	@EmpNode [int],
	@EmpTaxXML [nvarchar](max),
	@EmpHRAXML [nvarchar](max),
	@AttachmentXML [nvarchar](max),
	@CreatedBy [nvarchar](50) = NULL,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
Begin Try
DECLARE @XML xml,@Hasaccesss BIT,@RoleID INT,@PrimaryDocumentID int ,@AttachXml XML,@Dt FLOAT,@PREVSEQNO INT
SET @Dt=CONVERT(FLOAT,GETDATE())
--User access check for EMPLOYEE  
SELECT @RoleID=R.ROLEID FROM ADM_USERROLEMAP R WITH(NOLOCK),ADM_USERS U WITH(NOLOCK) WHERE R.USERID=U.USERID AND U.USERID=@UserID
SET @Hasaccesss=dbo.fnCOM_HasAccess(@RoleID,262,1)  
IF @Hasaccesss=0  
BEGIN  
	RAISERROR('-105',16,1)  
END

if(SELECT COUNT(*) FROM PAY_EmpTaxDeclaration WITH(NOLOCK) WHERE EmpNode=@EmpNode AND Year=@Year)>0
BEGIN
	SELECT @PREVSEQNO=MAX(SEQNO) FROM PAY_EmpTaxDeclaration WITH(NOLOCK) WHERE EmpNode=@EmpNode AND Year=@Year
END

DELETE FROM PAY_EmpTaxDeclaration WHERE EmpNode=@EmpNode AND Year=@Year

SET @XML=@EmpTaxXML
INSERT INTO PAY_EmpTaxDeclaration(Year,EmpNode,ComponentID,AmountLimit,Amount,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
SELECT  @Year,@EmpNode,A.value('@ComponentID','int'),A.value('@AmountLimit','nvarchar(50)'),A.value('@Amount','float'),@CreatedBy,getdate(),@CreatedBy,getdate()
FROM @XML.nodes('Rows/row') as Data(A)	
	SET @PrimaryDocumentID=SCOPE_IDENTITY()

DELETE FROM PAY_EmpTaxHRAInfo WHERE EmpNode=@EmpNode  AND Year=@Year

--SELECT @EmpHRAXML

SET @XML=@EmpHRAXML
INSERT INTO PAY_EmpTaxHRAInfo(Year,EmpNode,FromDate,ToDate,Amount,Metro,Address,Landlord,LandlordPAN)
SELECT  @Year,@EmpNode,convert(int, A.value('@FromDt','datetime')),convert(int, A.value('@ToDt','datetime')),
	A.value('@Amt','float'),A.value('@Metro','char(3)'),A.value('@Address','nvarchar(500)'),A.value('@Landlord','nvarchar(100)'),A.value('@LandlordPAN','nvarchar(50)')
FROM @XML.nodes('HRAINFO/row') as Data(A)	

IF (@AttachmentXML IS NOT NULL AND @AttachmentXML <> '')  
BEGIN  
		set @AttachXml=@AttachmentXML 
			
		INSERT INTO COM_Files(FilePath,ActualFileName,RelativeFileName,
		FileExtension,FileDescription,IsProductImage,FeatureID,CostCenterID,FeaturePK,[GUID],CreatedBy,CreatedDate)  
		SELECT X.value('@FilePath','NVARCHAR(500)'),X.value('@ActualFileName','NVARCHAR(50)'),X.value('@RelativeFileName','NVARCHAR(50)'),  
		X.value('@FileExtension','NVARCHAR(50)'),X.value('@FileDescription','NVARCHAR(500)'),X.value('@IsProductImage','bit'),262,262,@PrimaryDocumentID,  
		X.value('@GUID','NVARCHAR(50)'),@CreatedBy,@Dt  
		FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)    
		WHERE X.value('@Action','NVARCHAR(10)')='NEW'  

		--If Action is MODIFY then update Attachments  
		UPDATE COM_Files SET FilePath=X.value('@FilePath','NVARCHAR(500)'),  
		ActualFileName=X.value('@ActualFileName','NVARCHAR(50)'),  
		RelativeFileName=X.value('@RelativeFileName','NVARCHAR(50)'),  
		FileExtension=X.value('@FileExtension','NVARCHAR(50)'),  
		FileDescription=X.value('@FileDescription','NVARCHAR(500)'),  
		IsProductImage=X.value('@IsProductImage','bit'),        
		[GUID]=X.value('@GUID','NVARCHAR(50)'),  
		ModifiedBy=@CreatedBy,  
		ModifiedDate=@Dt  
		FROM COM_Files C WITH(NOLOCK)  
		INNER JOIN @AttachXml.nodes('/AttachmentsXML/Row') as Data(X) ON convert(INT,X.value('@AttachmentID','INT'))=C.FileID  
		WHERE X.value('@Action','NVARCHAR(500)')='MODIFY'  

		--If Action is DELETE then delete Attachments  
		DELETE FROM COM_Files  
		WHERE FileID IN(SELECT X.value('@AttachmentID','INT')  
		FROM @AttachXml.nodes('/AttachmentsXML/Row') as Data(X)  
		WHERE X.value('@Action','NVARCHAR(10)')='DELETE')  
END  

IF ISNULL(@PREVSEQNO,0)>0
BEGIN
	IF(SELECT COUNT(*) FROM COM_Files WITH(NOLOCK) WHERE FeatureID=262 AND FeaturePK=@PREVSEQNO)>0
	BEGIN
		UPDATE COM_Files SET FeaturePK=@PrimaryDocumentID WHERE FeatureID=262 AND FeaturePK=@PREVSEQNO
	END
END

COMMIT TRANSACTION
--SELECT * FROM [COM_CC50051] WITH(nolock) WHERE NodeID=@EmpNode  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @EmpNode    

End Try
Begin Catch
   IF ERROR_NUMBER()=50000  
	BEGIN  
		SELECT * FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@EmpNode    
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK)   
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	END  
	ELSE IF ERROR_NUMBER()=547  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(NOLOCK)  
		WHERE ErrorNumber=-110 AND LanguageID=@LangID  
	END   
	ELSE  
	BEGIN  
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
	END  
	ROLLBACK TRANSACTION  
	SET NOCOUNT OFF    
	RETURN -999     
End Catch
GO
