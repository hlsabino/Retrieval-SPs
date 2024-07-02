USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_CheckInvPosting]
	@InvDocXML [nvarchar](max),
	@RoleID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON;    
	 DECLARE @XML xml
	 DECLARE	@return_value int,  @CNT INT ,  @ICNT INT ,@AA XML,@result  NVARCHAR(MAX)
 
	SET @XML= @InvDocXML  
	declare @prds table(prdID BIGINT)
	  
	declare @tblListEnq TABLE (ID int identity(1,1),TRANSXML NVARCHAR(MAX) )    
	INSERT INTO @tblListEnq  
	SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML'))    
	from @XML.nodes('/Enquiries/ROWS') as Data(X)  

	 
	SELECT @CNT = COUNT(ID) FROM @tblListEnq

	SET @ICNT = 0
	WHILE(@ICNT < @CNT)
	BEGIN
		SET @ICNT =@ICNT+1
	
		SELECT @AA = TRANSXML  FROM @tblListEnq WHERE  ID = @ICNT
		 
	 	set @result=''
	 	SELECT  @result= p.ProductCode+' '+p.ProductName +' :'+ac.AccountName 
		from @AA.nodes('/DocumentXML/Row/Transactions') as Data(X)
		join INV_DocDetails a WITH(NOLOCK) on X.value('@LinkedInvDocDetailsID','BIGINT')=a.LinkedInvDocDetailsID
		join ACC_Accounts ac WITH(NOLOCK) on a.CreditAccount=ac.AccountID
		join INV_Product p WITH(NOLOCK) on a.ProductID=p.ProductID
		where X.value('@CreditAccount','BIGINT')=a.CreditAccount
		
		if(@result<>'')
		BEGIN
			select @result ErrorMessage
			return 1
		END	
   END

RETURN 1
END TRY      
BEGIN CATCH     
    if(@return_value=-999)
    return -999  
     IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
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
