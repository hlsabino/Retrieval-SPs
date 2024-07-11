USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetProductVendor]
	@ProductIDs [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON;  

		declare @table table(id int identity(1,1),PID nvarchar(50))  
		insert into @table  
		exec SPSplitString @ProductIDs,','  
		
		SELECT  ProductVendorID,ProductID,a.AccountID,b.AccountName,Priority,LeadTime,a.GUID  , a.MinOrderQty
		FROM INV_ProductVendors a WITH(NOLOCK)   
		join ACC_Accounts b WITH(NOLOCK) on a.AccountID =b.AccountID  
		join @table c on ProductID=c.PID
		where b.StatusID=33    
		order by a.AccountID,c.id
     
  

SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH  
  
  
  




GO
