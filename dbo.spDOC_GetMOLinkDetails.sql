USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetMOLinkDetails]
	@DocumentLinkDefID [int],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit,@LinkCostCenterID int,@SQL NVARCHAR(MAX)
	 
		--SP Required Parameters Check
		IF (@DocumentLinkDefID <1)
		BEGIN
			RAISERROR('-100',16,1)
		END
 
		SELECT @LinkCostCenterID=[CostCenterIDLinked]
		FROM [COM_DocumentLinkDef] with(nolock)
		where [DocumentLinkDefID]=@DocumentLinkDefID

		
		--Create temporary table 
		CREATE TABLE #tblList(ID int identity(1,1),DocDetailsID INT,Val float)  
		 
		SET @SQL='INSERT INTO #tblList
		SELECT a.InvDocDetailsID, a.Quantity-isnull(sum(b.Quantity),0) from 
		INV_DocDetails a with(nolock)
		left join dbo.PRD_MFGOrderBOMs b with(nolock) on a.InvDocDetailsID =b.DocID
		where a.CostCenterID= '+CONVERT(NVARCHAR,@LinkCostCenterID)+'
		group by a.InvDocDetailsID,a.Quantity
		 having a.Quantity-isnull(sum(b.Quantity),0) >0'
		 
		 EXEC (@SQL)   
		 
 		--GETTING DOCUMENT DETAILS
		SELECT distinct a.voucherno,a.[DocID], a.DebitAccount, a.CreditAccount 
		from [INV_DocDetails] a with(nolock)
		join #tblList c with(nolock) on a.InvDocDetailsID=c.DocDetailsID
		where a.statusid=369
		order by  a.voucherno


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

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
