USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterNodeID]
	@COSTCENTERID [bigint],
	@CostcenterName [nvarchar](200),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
 
BEGIN TRY  
SET NOCOUNT ON  

	   DECLARE @TBL NVARCHAR(50)    
		   
	   SELECT @TBL = TABLENAME FROM ADM_FEATURES WHERE FEATUREID = @COSTCENTERID
	   
	  
	   DECLARE @QRY NVARCHAR(MAX) ,  @NodeIDTemp nvarchar(50) , @TEMPxml XML , @CCXML NVARCHAR(MAX)
	   
	   SET @NodeIDTemp = 0
	   
	   DECLARE @TEMPQUERY NVARCHAR(300)
	   SET @TEMPQUERY='  @NodeIDTemp NVARCHAR(50) OUTPUT'
	   SET @QRY = ' SET @NodeIDTemp = (SELECT TOP 1  NODEID FROM ' + CONVERT(NVARCHAR, @TBL) +' WHERE NAME = '''+@CostcenterName+''')'
	     
	   EXEC SP_EXECUTESQL @QRY ,@TEMPQUERY,@NodeIDTemp  OUTPUT  
	  
	       
	  if(@NodeIDTemp IS NULL OR @NodeIDTemp = '' OR @NodeIDTemp  = 0)
	  begin 
	  BEGIN TRANSACTION 
		   SET @TEMPxml='<XML><Row AccountName ="'+replace(@CostcenterName,'&','&amp;')+'" AccountCode ="'+replace(@CostcenterName,'&','&amp;')+'"  ></Row></XML>'    
		   
		      
		     SET @CCXML = CONVERT(NVARCHAR(MAX), @TEMPxml)
		     
		   EXEC @NodeIDTemp = [dbo].[spADM_SetImportData]    
			  @XML =  @CCXML,    
			  @COSTCENTERID = @COSTCENTERID,    
			  @IsDuplicateNameAllowed = 1,    
			  @IsCodeAutoGen = 0,    
			  @IsOnlyName = 1,    
			  @CompanyGUID = @CompanyGUID,    
			  @UserName = @UserName ,    
			  @UserID = @UserID,
			  @RoleID=@RoleID,
			  @LangID = @LangID  
			 
			 
	  
	   SET @TEMPQUERY='  @NodeIDTemp NVARCHAR(50) OUTPUT'
	   SET @QRY = ' SET @NodeIDTemp = (SELECT TOP 1  NODEID FROM ' + CONVERT(NVARCHAR, @TBL) +' WHERE NAME = '''+@CostcenterName+''')'
	     
	   EXEC SP_EXECUTESQL @QRY ,@TEMPQUERY,@NodeIDTemp  OUTPUT  
		 
	  COMMIT TRANSACTION  
	  end 
			--select  @NodeIDTemp
	-- set  @NodeIDRtn=   @NodeIDTemp 
		    
SET NOCOUNT OFF;     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID    
RETURN @NodeIDTemp  
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
