USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_InsertEmployeeTaxComputation]
	@Year [int],
	@EmpNode [int],
	@EmpTaxXML [nvarchar](max),
	@CreatedBy [nvarchar](50) = NULL,
	@Flag [int] = 0,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
Begin Try
DECLARE @XML xml,@Hasaccesss BIT,@RoleID INT,@RCount INT
SET @RCount=0
--User access check for EMPLOYEE  
SELECT @RoleID=R.ROLEID FROM ADM_USERROLEMAP R WITH(NOLOCK),ADM_USERS U WITH(NOLOCK) WHERE R.USERID=U.USERID AND U.USERID=@UserID
SET @Hasaccesss=dbo.fnCOM_HasAccess(@RoleID,264,1)  
IF @Hasaccesss=0  
BEGIN  
	RAISERROR('-105',16,1)  
END
	
IF(@Flag=0)
BEGIN
	DELETE FROM PAY_EmpTaxComputation WHERE EmpNode=@EmpNode AND Year=@Year

	SET @XML=@EmpTaxXML
	INSERT INTO PAY_EmpTaxComputation(Year,EmpNode,HeaderID,HeaderName,ComponentID,ComponentAmount,TotalAmount,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,RegimeType)
	SELECT  @Year,@EmpNode,A.value('@HeaderID','int'),A.value('@HeaderName','nvarchar(400)'),A.value('@ComponentID','int'),A.value('@ComponentAmount','float'),A.value('@TotalAmount','float'),@CreatedBy,getdate(),@CreatedBy,getdate(),A.value('@RegimeType','int')
	FROM @XML.nodes('Rows/row') as Data(A)	
END
ELSE IF(@Flag=1)
BEGIN
	DELETE FROM PAY_EmpTaxComputation WHERE EmpNode=@EmpNode AND Year=@Year
	IF(@@ROWCOUNT=0)
		SET @RCount=0
	ELSE 
		SET @RCount=1
END	

COMMIT TRANSACTION
IF(@Flag=0)
BEGIN
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=100 AND LanguageID=@LangID  
END
ELSE IF(@Flag=1)
BEGIN
	IF(@RCount=0)
	BEGIN
		SELECT 'No Data Exist' ErrorMessage,0 ErrorNumber 
	END
	ELSE
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
		WHERE ErrorNumber=102 AND LanguageID=@LangID  
	END
END
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
