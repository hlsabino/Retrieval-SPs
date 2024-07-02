USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetBRSDetails]
	@XML [nvarchar](max),
	@AccountID [bigint],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
SET NOCOUNT ON      
BEGIN TRY      

	--Declaration Section      
	DECLARE  @DATA XML,@COUNT INT,@I INT, @Dt float,@HasAccess bit
	SET @DATA=@XML      
	declare @AccID INT
	set @Accid=0
	--SP Required Parameters Check      
	IF @CompanyGUID IS NULL OR @CompanyGUID=''      
	BEGIN      
	RAISERROR('-100',16,1)      
	END      
	    
	
	SET @Dt=convert(float,getdate())--Setting Current Date
	SET @AccID =(SELECT COUNT(AccountID) from COM_BRSTemplate where AccountID=@AccountID)

	if(@AccID=0)
	BEGIN
		INSERT INTO COM_BRSTemplate(AccountID, ChequeNo,ClearanceDate,DebitAmount, CreditAmount,
						CompanyGUID, GUID, CreatedBy, CreatedDate)
		SELECT	@AccountID, 
				X.value('@ChequeNo','NVARCHAR(50)'),
				X.value('@ClearanceDate','NVARCHAR(50)'), 
				X.value('@DebitAmount','NVARCHAR(50)'),
				X.value('@CreditAmount','NVARCHAR(50)'),
				@CompanyGUID,@GUID,@UserName,@Dt
		FROM @DATA.nodes('XML/Row') as Data(X)

	END
 
 ELSE
 BEGIN
 	UPDATE COM_BRSTemplate SET ChequeNo=X.value('@ChequeNo','NVARCHAR(50)'),
	ClearanceDate=X.value('@ClearanceDate','NVARCHAR(50)'), 
	DebitAmount=X.value('@DebitAmount','NVARCHAR(50)'),
	CreditAmount=X.value('@CreditAmount','NVARCHAR(50)'),
	ModifiedBy=@UserName,
	ModifiedDate=@Dt
	From @DATA.nodes('XML/Row') as DATA(X)  
	where AccountID=@AccountID      
	
	
 END
 
COMMIT TRANSACTION        

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID          
SET NOCOUNT OFF;        
RETURN @AccountID        
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
 END      
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
END CATCH    



--<XML Parent="70"><Row    RowNo="2" ChequeNo="ChequeNo"/><Row    RowNo="4" ClearanceDate="Clearance Date"/><Row    RowNo="5" DebitAmount="Amount Dr"/><Row    RowNo="6" CreditAmount="Amount Cr"/></XML>


   
      
      

GO
