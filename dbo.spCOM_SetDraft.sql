USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetDraft]
	@DraftID [bigint] = 0,
	@CostcenterID [int],
	@NodeID [bigint],
	@DataXML [nvarchar](max),
	@Status [int],
	@DocName [nvarchar](200),
	@NoOfProducts [int],
	@NetValue [float],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
          
	--Declaration Section    
	DECLARE @HasAccess BIT    
    
	IF @DraftID=0     
	BEGIN--------START INSERT RECORD-----------    
	INSERT INTO COM_DocDraft(CostcenterID, NodeID, UserID, DataXML,DocName,NoOfProducts,NetValue,  CompanyGUID, GUID, CreatedBy, CreatedDate,ModifiedDate,Status)
	VALUES( @CostcenterID,@NodeID,@UserID,@DataXML,@DocName,@NoOfProducts,@NetValue, @CompanyGUID, NEWID() ,@UserName ,CONVERT(FLOAT,GETDATE()),CONVERT(FLOAT,GETDATE()),@Status)      
 
	--To get inserted record primary key    
	SET @DraftID=SCOPE_IDENTITY()      
    
	END--------END INSERT RECORD-----------      
	ELSE-------START UPDATE RECORD-----------      
	BEGIN      
    
	--SELECT @TempGuid=[GUID] FROM ADM_PRoles WITH(NOLOCK)         
	--WHERE RoleID=@RoleID        
     
	--    if(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ        
	--    BEGIN        
	--     RAISERROR('-101',16,1)    
	--    END        
    
	UPDATE COM_DocDraft      
	SET DataXML=@DataXML    
		,GUID=NEWID()    
		,ModifiedBy=@UserName    
		,ModifiedDate=CONVERT(FLOAT,GETDATE())
		,status=@Status
		,DocName=@DocName
		,NoOfProducts=@NoOfProducts
		,NetValue=@NetValue
	WHERE DraftID=@DraftID      
	END--------END UPDATE RECORD-----------      
  
COMMIT TRANSACTION     


SET NOCOUNT OFF;      
RETURN  @DraftID    
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    

ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH    
    
    
GO
