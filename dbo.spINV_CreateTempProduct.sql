USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_CreateTempProduct]
	@ProductID [int],
	@CategoryID [int],
	@CustomFieldsQuery [nvarchar](max),
	@CustomCostCenterFieldsQuery [nvarchar](max),
	@PurchasePrice [float],
	@SellingPrice [float],
	@ProductCode [nvarchar](500),
	@INVDOCDETAILSID [int],
	@COMPANYGUID [nvarchar](50),
	@USERNAME [nvarchar](50),
	@USERID [int],
	@LANGID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	
	DECLARE @UOMID INT,@SalesAccountID INT,@PurchaseAccountID INT,@COGSAccountID INT,@ClosingStockAccountID INT
	DECLARE @ValuationID INT,@StatusID INT,@VALUE NVARCHAR(200)	,@Dt float
	SET @Dt=CONVERT(FLOAT,GETDATE())
	IF(@ProductID=0)
	BEGIN
		SET @VALUE=''
		SELECT @VALUE=VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID=3 AND NAME='DefaultUOM'
		IF(@VALUE<>'')
			SET @UOMID=CONVERT(INT,@VALUE)
			
		SET @VALUE=''
		SELECT @VALUE=VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID=3 AND NAME='DefaultProductValuation'
		IF(@VALUE='FIFO')
			SET @ValuationID=1
		ELSE IF(@VALUE='LIFO')
			SET @ValuationID=2
		ELSE
			SET @ValuationID=3
			
		SET @VALUE=''
		SELECT  @VALUE=USERDEFAULTVALUE FROM ADM_COSTCENTERDEF with(nolock) WHERE COSTCENTERID=3 AND SYSCOLUMNNAME='SalesAccountID'
		IF(@VALUE<>'')
			SET @SalesAccountID=CONVERT(INT,@VALUE)
		SET @VALUE=''		
	    SELECT  @VALUE=USERDEFAULTVALUE FROM ADM_COSTCENTERDEF with(nolock) WHERE COSTCENTERID=3 AND SYSCOLUMNNAME='PurchaseAccountID'
	    IF(@VALUE<>'')
			SET @PurchaseAccountID=CONVERT(INT,@VALUE)
	    SET @VALUE=''
	    SELECT  @VALUE=USERDEFAULTVALUE FROM ADM_COSTCENTERDEF with(nolock) WHERE COSTCENTERID=3 AND SYSCOLUMNNAME='COGSAccountID'
	    IF(@VALUE<>'')
			SET @COGSAccountID=CONVERT(INT,@VALUE)
	    SET @VALUE=''
	    SELECT  @VALUE=USERDEFAULTVALUE FROM ADM_COSTCENTERDEF with(nolock) WHERE COSTCENTERID=3 AND SYSCOLUMNNAME='ClosingStockAccountID'
		IF(@VALUE<>'')
			SET @ClosingStockAccountID=CONVERT(INT,@VALUE)
		SET @VALUE=''
	    SELECT  @VALUE=USERDEFAULTVALUE FROM ADM_COSTCENTERDEF with(nolock) WHERE COSTCENTERID=3 AND SYSCOLUMNNAME='StatusID'
		IF(@VALUE<>'')
			SET @StatusID=CONVERT(INT,@VALUE)
			
		EXEC	@ProductID = [dbo].[spINV_SetProduct]
		@ProductID = 0,
		@ProductCode = @ProductCode,
		@ProductName = @ProductCode,
		@AliasName = @ProductCode,
		@ProductTypeID = 1,
		@StatusID = @StatusID,
		@UOMID = @UOMID,
		
		@BarcodeID = 0,
		@Description = N'',
		@SelectedNodeID = 0,
		@IsGroup = 0,
		@CustomFieldsQuery =@CustomFieldsQuery,
		@CustomCostCenterFieldsQuery = @CustomCostCenterFieldsQuery,
		@ContactsXML = N'',
		@NotesXML = N'',
		@AttachmentsXML = N'',
		@SubstitutesXML = N'',
		@VendorsXML = N'',
		@SerializationXML = N'',
		@KitXML = N'',
		@LinkedProductsXML = N'',
		@MatrixSeqno = 0,
		@AttributesXML = N'',
		@AttributesData = N'',
		@AttributesColumnsData = N'',
		@HasSubItem = 0,
		@ItemProductData = N'',
		@AssignCCCCData = N'',
		@ProductWiseUOMData = N'',
		@ProductWiseUOMData1 = N'',
		@CompanyGUID = @COMPANYGUID,
		@GUID = N'',
		@UserName = @USERNAME,
		@UserID = @USERID,
		@LangID = @LANGID  
		
		UPDATE INV_Product SET
		ValuationID = @ValuationID,
		SalesAccountID = @SalesAccountID,
		PurchaseAccountID = @PurchaseAccountID,
		COGSAccountID = @COGSAccountID,
		ClosingStockAccountID = @ClosingStockAccountID,
		PurchaseRate = @PurchasePrice,
		SellingRate = @SellingPrice 
		WHERE ProductID=@ProductID
	END
	
	if(@ProductID>0)
	begin	
		if  exists (select CCnid6 from COM_CCCCData with(nolock) where CostCenterID=3 and nodeid=@ProductID and Ccnid6<>1)
		begin
			declare @cat INT
			set @cat=1
			select @cat=ccnid6 from COM_CCCCData with(nolock) where CostCenterID=3 and nodeid=@ProductID  
			update INV_Product set CategoryID=@cat where productid=@ProductID
		end
		
		WHILE(@INVDOCDETAILSID IS NOT NULL AND @INVDOCDETAILSID>0)
		BEGIN
			UPDATE INV_DOCDETAILS
			SET PRODUCTID=@PRODUCTID
			WHERE INVDOCDETAILSID	=@INVDOCDETAILSID	
			
			delete from inv_Tempinfo  WHERE INVDOCDETAILSID	=@INVDOCDETAILSID
			
			SELECT @INVDOCDETAILSID=LinkedInvDocDetailsID FROM INV_DOCDETAILS with(nolock) WHERE INVDOCDETAILSID=@INVDOCDETAILSID
			
		END	   
	end	  	 
 
COMMIT TRANSACTION    
SET NOCOUNT OFF; 
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID   
RETURN @PRODUCTID
END TRY  
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	if(@ProductID=-999)
		RETURN -999
 	IF ERROR_NUMBER()=50000
	BEGIN		  
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
   
   

GO
