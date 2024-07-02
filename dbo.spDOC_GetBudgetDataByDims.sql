USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetBudgetDataByDims]
	@BudgetID [int],
	@FromDate [datetime],
	@CCXML [nvarchar](500),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	DECLARE @I INT,@CNT INT,@Name nvarchar(100),@CCID INT,@ID BIGINT
	DECLARE @XML XML,@AccountID BIGINT,@SQL NVARCHAR(MAX),@CCWhere NVARCHAR(MAX),@BudCCWhere NVARCHAR(MAX),@Where NVARCHAR(MAX)
	DECLARE @tblCC AS TABLE(ID INT identity(1,1),CostCenterID INT,Name NVARCHAR(100),NodeID BIGINT)
	
	SET @XML=@CCXML
	
	INSERT INTO @tblCC(CostCenterID,Name)
	SELECT X.value('@CCID','INT'),X.value('@Name','NVARCHAR(100)')
	FROM @XML.nodes('/XML/Row') as Data(X)
	
	select @I=1,@CNT=COUNT(*) from @tblCC 
	SET @CCWhere=''
	SET @BudCCWhere=''
	
	while(@I<=@CNT)
	begin
		select @ID=NULL,@CCID=CostCenterID,@Name=Name from @tblCC where ID=@I
		if @CCID=2
		begin
			select @ID=AccountID FROM ACC_Accounts with(nolock) where AccountName=@Name
			set @AccountID=@ID
		end
		else if @CCID=50001
			select @ID=NodeID FROM COM_Division with(nolock) where Name=@Name
		else if @CCID=50002
			select @ID=NodeID FROM COM_Location with(nolock) where Name=@Name
		else if @CCID=50003
			select @ID=NodeID FROM COM_Branch with(nolock) where Name=@Name
		else if @CCID=50004
			select @ID=NodeID FROM COM_Department with(nolock) where Name=@Name
		else if @CCID=50005
			select @ID=NodeID FROM COM_Salesman with(nolock) where Name=@Name
		else if @CCID=50006
			select @ID=NodeID FROM COM_Category with(nolock) where Name=@Name
		else if @CCID=50007
			select @ID=NodeID FROM COM_Area with(nolock) where Name=@Name
		else if @CCID=50008
			select @ID=NodeID FROM COM_Teritory with(nolock) where Name=@Name
		else if @CCID>50008
		begin
			set @SQL='select @ID=NodeID FROM COM_CC'+convert(nvarchar,@CCID)+' with(nolock) where Name='''+@Name+''''
			EXEC sp_executesql @SQL,N'@ID BIGINT OUTPUT',@ID OUTPUT
		end
		
		if @CCID>50000
		begin
			set @CCWhere=@CCWhere+' AND DCC.dcCCNID'+CONVERT(NVARCHAR,@CCID-50000)+'='+CONVERT(NVARCHAR,@ID) 
			set @BudCCWhere=@BudCCWhere+' AND CCNID'+CONVERT(NVARCHAR,@CCID-50000)+'='+CONVERT(NVARCHAR,@ID) 
		end
		
		IF @ID is null
			select '"'+@Name+'" dimension not found' ErrorMsg

	--	select @CCID,@ID
		set @I=@I+1
	end
	
	
	


	IF @AccountID IS NOT NULL
	BEGIN
		SET @SQL='select * from COM_BudgetAlloc with(nolock) where BudgetDefID='+convert(nvarchar,@BudgetID)+' AND AccountID='+convert(nvarchar,@AccountID)+@BudCCWhere
		
		exec(@SQL)
			
		SET @SQL='DECLARE @AccountID BIGINT,@From FLOAT,@To FLOAT	
		SET @From='+CONVERT(NVARCHAR,CONVERT(FLOAT,@FromDate))+'
		SET @To='+CONVERT(NVARCHAR,CONVERT(FLOAT,DATEADD(YEAR,1,@FromDate)))

		
		SET @SQL=@SQL+' SET @AccountID='+CONVERT(NVARCHAR,@AccountID)+'
		SELECT  ISNULL(SUM(DebitAmount),0)-ISNULL(SUM(CreditAmount),0) Uitlized FROM (
		
		SELECT CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo, 
		D.Amount DebitAmount,NULL CreditAmount,DCC.*
		FROM ACC_DocDetails D with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID'+@CCWhere+'
		WHERE D.DebitAccount=@AccountID AND D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<= @To
		UNION ALL
		SELECT CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,
		NULL DebitAmount,D.Amount CreditAmount,DCC.*
		FROM ACC_DocDetails D with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID'+@CCWhere+'
		WHERE D.CreditAccount=@AccountID AND D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<=@To
		UNION ALL
		SELECT CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo, 
		D.Amount DebitAmount,NULL CreditAmount,DCC.*
		FROM ACC_DocDetails D with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere+'
		WHERE D.DebitAccount=@AccountID AND D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<=@To
		UNION ALL
		SELECT CONVERT(DATETIME,D.DocDate) DocDate, D.VoucherNo,
		NULL DebitAmount,D.Amount CreditAmount,DCC.*
		FROM ACC_DocDetails D with(nolock)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere+'
		WHERE D.CreditAccount=@AccountID AND D.DocumentType<>16 AND D.DocumentType<>14 AND D.DocumentType<>19 AND D.DocDate>=@From AND D.DocDate<=@To
		) AS T 
		'
		PRINT(@SQL)
		EXEC(@SQL)
	
	END
	


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
