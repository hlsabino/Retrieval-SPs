USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocVouchersList]
	@CostCenterID [int],
	@DocPrefix [nvarchar](50),
	@Type [int],
	@Account [bigint],
	@FromNo [bigint],
	@ToNo [bigint],
	@FromDate [datetime],
	@ToDate [datetime],
	@Where [nvarchar](max),
	@RePrint [bit],
	@ExcludeUnApproveDocs [bit],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	--Declaration Section
	DECLARE @HasAccess BIT,@IsInventory BIT,@SQL NVARCHAR(MAX),@AccWhere NVARCHAR(100),@FK nvarchar(30)
		
	SELECT @IsInventory=IsInventory FROM  ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID  

	SET @AccWhere=''
	SET @SQL='SELECT DocID,DocPrefix,CONVERT(INT,DocNumber) dno FROM '

	IF @IsInventory=1
	BEGIN
		set @FK='InvDocDetailsID'
		SET @SQL=@SQL+'INV_DocDetails D WITH(NOLOCK)'
		IF @Account>0
		BEGIN			
			SELECT TOP 1 @AccWhere=' AND '+SysColumnName+'='+CONVERT(NVARCHAR,@Account)
			FROM ADM_CostCenterDef WITH(NOLOCK)
			WHERE CostCenterID=@CostCenterID AND ColumnCostCenterID=2 AND (UserColumnName LIKE 'Vendor%' OR UserColumnName LIKE 'Customer%' )
		END
	END
	ELSE
	BEGIN
		set @FK='AccDocDetailsID'
		SET @SQL=@SQL+'ACC_DocDetails D WITH(NOLOCK)'
		IF @Account>0
		BEGIN			
			SELECT TOP 1 @AccWhere=SysColumnName
			FROM ADM_CostCenterDef WITH(NOLOCK)
			WHERE CostCenterID=@CostCenterID AND ColumnCostCenterID=2 AND (UserColumnName LIKE 'Account Name%')

			IF @AccWhere='AccountID'
				SET @AccWhere=' AND (DebitAccount='+CONVERT(NVARCHAR,@Account)+' OR CreditAccount='+CONVERT(NVARCHAR,@Account)+')'
			ELSE
				SET @AccWhere=' AND '+@AccWhere+'='+CONVERT(NVARCHAR,@Account)
		END
	END
	
	if @Where like '%DCC.dcCCNID%'
		SET @SQL=@SQL+'	inner join COM_DocCCData DCC with(nolock) on DCC.'+@FK+'=D.'+@FK
	
	SET @SQL=@SQL+'	WHERE D.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND D.StatusID!=376'+@Where

	IF @Type=1
		SET @SQL=@SQL+'	AND (D.DocPrefix='''+@DocPrefix+''' AND D.DocNumber BETWEEN '+CONVERT(NVARCHAR,@FromNo)+' AND '+CONVERT(NVARCHAR,@ToNo)+')'
	ELSE IF @Type=2
		SET @SQL=@SQL+'	AND (D.DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+' AND '+CONVERT(NVARCHAR,CONVERT(FLOAT,@ToDate))+')'
	
	SET @SQL=@SQL+@AccWhere
	
	if @ExcludeUnApproveDocs=1
		SET @SQL=@SQL+'	AND D.StatusID!=371'
		
	SET @SQL=@SQL+' GROUP BY DocPrefix,CONVERT(INT,DocNumber),DocID'
	
	IF @RePrint=0
	BEGIN
		SET @SQL='SELECT DocID,DocPrefix,dno FROM ('+@SQL+') AS T
LEFT JOIN COM_DocPrints P with(nolock) ON P.NodeID=T.DocID
GROUP BY DocID,DocPrefix,dno HAVING Count(NodeID)=0'
	END
	SET @SQL=@SQL+' ORDER BY DocPrefix,dno'
	
	--print(@SQL)
	EXEC(@SQL)

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
