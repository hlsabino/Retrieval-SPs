USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetTempPartsInfo]
	@FromDate [datetime],
	@ToDate [datetime],
	@Location [nvarchar](max) = null,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

   DECLARE @SQL NVARCHAR(MAX) , @CCID NVARCHAR(MAX)
   SELECT @CCID=VALUE FROM COM_CostCenterPreferences with(nolock) WHERE costcenterid = 3 AND NAME  = 'TempPartDocuments'
     
 set @SQL='	SELECT INVDOC.VoucherNo DocNo, convert(datetime,INVDOC.DocDate) DocDate ,DOCCC.dcCCNID2 LocationID,  loc.Name   Location 
	, INVDOC.CreatedBy CreatedBy ,  convert(datetime,INVDOC.CreatedDate) CreatedDate   , INVDOC.DebitAccount VendorID , Acc.AccountName Vendor
	,INVDOC.INVDOCDETAILSID
	 FROM INV_DOCDETAILS INVDOC with(nolock) 
	 JOIN COM_DOCCCDATA DOCCC with(nolock) ON INVDOC.INVDOCDETAILSID = DOCCC.INVDOCDETAILSID 
	 JOIN COM_Location loc with(nolock) ON DOCCC.dcCCNID2 = loc.NodeID  
	 JOIN Acc_Accounts Acc with(nolock) ON INVDOC.DebitAccount  = Acc.AccountID 
	WHERE PRODUCTID IN (SELECT VALUE FROM COM_CostCenterPreferences with(nolock)
	WHERE costcenterid = 3 AND NAME  = ''TempPartProduct'' ) 
	and INVDOC.DocDate between '+convert(nvarchar(400),convert(float,@FromDate))+' and '+convert(nvarchar(400),convert(float,@ToDate))+'
	  and COSTCENTERID IN ('+REPLACE(@CCID,';',',')+')	 '
	IF(@Location IS NOT NULL AND @Location <>'' AND @Location <> '0' )
	BEGIN
		SET @SQL = @SQL  + ' and  loc.NodeID in ('+ @Location +')   '
	END
	
	set @SQL= @SQL  + '	order by INVDOC.DocDate desc'
	
	print @SQL
	exec(@SQL) 
	
	SELECT T.* FROM [INV_TempInfo] T WITH(NOLOCK)
	WHERE T.InvDocDetailsID IN (SELECT InvDocDetailsID FROM  [INV_DocDetails] WITH(NOLOCK)
	WHERE PRODUCTID IN (SELECT VALUE FROM COM_CostCenterPreferences with(nolock)
	WHERE costcenterid = 3 AND NAME  = 'TempPartProduct' )) 
	 
		
		
COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
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
