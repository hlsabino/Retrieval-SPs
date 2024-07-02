USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_CancelClosedReservation]
	@QuotationID [int],
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY        
SET NOCOUNT ON;  
	
	UPDATE REN_Quotation SET StatusID=467,VacancyDate=NULL,SysInfo=@SysInfo,AP=@AP,
	ModifiedBy=@UserName,ModifiedDate=CONVERT(FLOAT,GETDATE())
	WHERE QuotationID=@QuotationID
	
	DECLARE  @tblXML TABLE(ID int identity(1,1),DOCID INT,COSTCENTERID int)
	
	INSERT INTO @tblXML       
	select DocID,COSTCENTERID from [REN_ContractDocMapping] WITH(NOLOCK) 
	where [ContractID]=@QuotationID and [Type]=101 and ContractCCID=129
	
	DECLARE @CNT INT,@I INT,@return_value int,@DELETEDOCID INT,@DELETECCID INT
	
	select @I=0,@CNT=max(ID) from @tblXML
	WHILE(@I <  @CNT)      
	BEGIN                
		SET @I = @I+1  
		SELECT @DELETEDOCID = DOCID FROM @tblXML WHERE ID = @I      
        
		SELECT @DELETECCID = COSTCENTERID FROM dbo.ACC_DocDetails  WITH(NOLOCK)        
		WHERE DOCID = @DELETEDOCID      
		
		IF @DELETECCID IS NOT NULL and @DELETECCID>0 AND @DELETEDOCID IS NOT NULL and @DELETEDOCID>0
		BEGIN
			EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]        
			@CostCenterID = @DELETECCID,        
			@DocPrefix = '',        
			@DocNumber = '',   
			@DOCID = @DELETEDOCID,
			@SysInfo=@SysInfo, 
			@AP=@AP,
			@UserID = 1,        
			@UserName = N'ADMIN',        
			@LangID = 1,
			@RoleID=1 
		END

		DELETE from [REN_ContractDocMapping] 
		where [ContractID]=@QuotationID and [Type]=101 and ContractCCID=129   
	END	
	
COMMIT TRANSACTION       
     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;
RETURN @QuotationID        
END TRY        
BEGIN CATCH   
 if(@return_value is null or  @return_value<>-999)     
 BEGIN          
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
 END  
 SET NOCOUNT OFF        
 RETURN -999         
    
    
END CATCH
GO
