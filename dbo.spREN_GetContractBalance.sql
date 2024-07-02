USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetContractBalance]
	@ContractID [int],
	@CostCenterID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
/***16-Opening Balance,14-Postdated Payment,19-Postdated Receipts***/

DECLARE @SQL NVARCHAR(MAX),@PDCSQL NVARCHAR(MAX),@DecimalsinAmount Float
DECLARE	@Temp NVARCHAR(80),@UnAppSQL NVARCHAR(MAX),@AccountID INT,@IncludePDC BIT

SELECT @AccountID=RentAccID FROM REN_Contract WITH(NOLOCK) WHERE ContractID=@ContractID

SELECT @DecimalsinAmount=Value FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE name='DecimalsinAmount'

SELECT @IncludePDC=(CASE WHEN Value='True' THEN 1 ELSE 0 END) FROM COM_CostCenterPreferences WITH(NOLOCK) 
WHERE CostCenterID=95 AND Name='IncludePDCOnRenew'

IF @IncludePDC IS NULL
	SET @IncludePDC=1
	
SET @UnAppSQL=' AND D.StatusID IN (369,429,371,372,376)'

SET @SQL='SELECT DebitAccount AccountID,D.Amount DebitAmount,0 CreditAmount
FROM ACC_DocDetails D with(nolock) 
WHERE D.DebitAccount='+CONVERT(NVARCHAR,@AccountID)+' AND D.DocumentType<>16 AND D.DocumentType<>14
AND D.RefNodeid='+CONVERT(NVARCHAR,@ContractID)+' AND D.RefCCID='+CONVERT(NVARCHAR,@CostCenterID)+@UnAppSQL+'
UNION ALL
SELECT CreditAccount,0 DebitAmount,D.Amount CreditAmount
FROM ACC_DocDetails D with(nolock) 
WHERE D.CreditAccount='+CONVERT(NVARCHAR,@AccountID)+' AND D.DocumentType<>16 AND D.DocumentType<>14
AND D.RefNodeid='+CONVERT(NVARCHAR,@ContractID)+' AND D.RefCCID='+CONVERT(NVARCHAR,@CostCenterID)+@UnAppSQL

SET @SQL=@SQL+N' union all '+'select D.CreditAccount AccountID,dbo.[fnDoc_GetPendingAmount](D.VoucherNo) DebitAmount,0 CreditAmount 
		from ACC_DocDetails D WITH(NOLOCK)
		where D.RefCCID='+CONVERT(NVARCHAR,@CostCenterID) +'  and D.RefNodeid='+CONVERT(NVARCHAR,@ContractID)+'  and D.StatusID=429'

IF @IncludePDC=1
BEGIN
	SET @Temp='D.StatusID IN (370,439,371,452)'
		
	declare @LineWisePDC nvarchar(max)
	set @LineWisePDC=''
	SELECT @LineWisePDC=@LineWisePDC+convert(nvarchar,CostCenterID)+',' FROM COM_DocumentPreferences with(nolock) WHERE (DocumentType=14 or DocumentType=19) and (Prefname='LineWisePDC' and Prefvalue='true')
	if(@LineWisePDC!='')
	begin
		set @LineWisePDC=substring(@LineWisePDC,1,len(@LineWisePDC)-1)
		if(charindex(',',@LineWisePDC,1)>0)
			set @LineWisePDC=' and D.CostCenterID not IN ('+@LineWisePDC+')'
		else
			set @LineWisePDC=' and D.CostCenterID!='+@LineWisePDC
	end	
		
	SET @PDCSQL='SELECT DebitAccount AccountID,D.Amount DebitAmount,0 CreditAmount
	FROM ACC_DocDetails D with(nolock) 
	WHERE D.DebitAccount='+CONVERT(NVARCHAR,@AccountID)+' AND '+@Temp+'AND D.RefNodeid='+CONVERT(NVARCHAR,@ContractID)+' AND D.RefCCID='+CONVERT(NVARCHAR,@CostCenterID)+@LineWisePDC+'
	UNION ALL
	SELECT CreditAccount,0 DebitAmount,D.Amount CreditAmount
	FROM ACC_DocDetails D with(nolock)
	WHERE D.CreditAccount='+CONVERT(NVARCHAR,@AccountID)+' AND '+@Temp+'AND D.RefNodeid='+CONVERT(NVARCHAR,@ContractID)+' AND D.RefCCID='+CONVERT(NVARCHAR,@CostCenterID)+@LineWisePDC
	
	SET @SQL=@SQL+N' union all '+@PDCSQL
	
END

SET @SQL='SELECT AccountID,ROUND(ISNULL(SUM(DebitAmount)-SUM(CreditAmount),0),'+CONVERT(NVARCHAR,@DecimalsinAmount)+') Balance
FROM ( '+@SQL+') AS T Group By AccountID'

EXEC(@SQL)

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
