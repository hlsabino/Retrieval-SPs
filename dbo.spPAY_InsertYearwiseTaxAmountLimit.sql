USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_InsertYearwiseTaxAmountLimit]
	@Year [int],
	@TaxAmountLimitXML [nvarchar](max),
	@Regime [nvarchar](20),
	@CreatedBy [nvarchar](50) = NULL,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
Begin Try
DECLARE @XML xml,@Hasaccesss BIT,@RoleID INT

--User access check for EMPLOYEE  
SELECT @RoleID=R.ROLEID FROM ADM_USERROLEMAP R WITH(NOLOCK),ADM_USERS U WITH(NOLOCK) WHERE R.USERID=U.USERID AND U.USERID=@UserID
SET @Hasaccesss=dbo.fnCOM_HasAccess(@RoleID,263,1)  
IF @Hasaccesss=0  
BEGIN  
	RAISERROR('-105',16,1)  
END
	

DELETE FROM PAY_YearwiseTaxAmountLimit WHERE Year=@Year and regime=@Regime

SET @XML=@TaxAmountLimitXML
INSERT INTO PAY_YearwiseTaxAmountLimit(Year,ComponentID,AmountLimit,CreatedBy,CreatedDate,ModifiedDate,Regime)
SELECT  @Year,A.value('@ComponentID','int'),A.value('@AmountLimit','nvarchar(50)'),@CreatedBy,getdate(),getdate(),@Regime
FROM @XML.nodes('Rows/row') as Data(A)	

COMMIT TRANSACTION
--SELECT * FROM [COM_CC50051] WITH(nolock) WHERE NodeID=@EmpNode  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @Year    

End Try
Begin Catch
   IF ERROR_NUMBER()=50000  
	BEGIN  
		--SELECT * FROM COM_CC50051 WITH(NOLOCK) WHERE NodeID=@EmpNode    
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
