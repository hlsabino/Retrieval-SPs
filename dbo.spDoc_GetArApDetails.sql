USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetArApDetails]
	@AccountID [int] = 0,
	@DocDate [datetime],
	@docno [nvarchar](500) = NULL,
	@linkedids [nvarchar](max),
	@DocumentType [int],
	@CostCenterID [int],
	@DimWhere [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON
	
	DECLARE @I INT,@CNT INT

	if(@DocumentType=38)
	BEGIN
		DECLARE @Tblids AS TABLE(ID INT NOT NULL IDENTITY(1,1),DetailsID INT)
		INSERT INTO @Tblids(DetailsID)
		exec SPSplitString @linkedids,','  
		
			set @I=0
			WHILE(1=1)
			BEGIN
				SET @CNT=(SELECT Count(*) FROM @Tblids)
				INSERT INTO @Tblids(DetailsID)
				SELECT INV.LinkedInvDocDetailsID
				FROM INV_DocDetails INV with(nolock) 
				INNER JOIN @Tblids T ON INV.InvDocDetailsID=T.DetailsID AND ID>@I
				where INV.LinkedInvDocDetailsID is not null and INV.LinkedInvDocDetailsID>0
				
				IF @CNT=(SELECT Count(*) FROM @Tblids)
					BREAK
				SET @I=@CNT
			END
			
		select * from (
		select a.DocNo,a.Amount,abs(a.Amount)-abs(sum(isnull(b.Amount,0))) Bal from com_billwisenonacc a WITH(NOLOCK)
		left join com_billwisenonacc b WITH(NOLOCK) on a.DocNo=b.RefDocNO and b.Docno<>@docno
		join inv_docdetails d WITH(NOLOCK) on a.DocNo=d.Voucherno
		join @Tblids id on d.InvDocDetailsID=id.DetailsID
		where a.RefDocNO=''
		group by a.DocNo,a.Amount) as t
		where Bal>0.001
	END
	ELSE
	BEGIN

		declare @dpMap NVARCHAR(MAX),@dpXML XML,@sDPNumCols NVARCHAR(MAX),@SQL nvarchar(MAX)
		SET @SQL=''
		SELECT @dpMap=PrefValue From COM_DocumentPreferences WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND PrefName='DocDownPaymentMapXML' 
		if(@dpMap IS NOT NULL AND @dpMap<>'')
		BEGIN
			SET @sDPNumCols=''
			SET @dpXML=@dpMap
			SELECT @sDPNumCols+=',MAX(ISNULL(nd.'+X.value('@DownPaySysColName','NVARCHAR(50)')+',0)) as '+X.value('@DownPaySysColName','NVARCHAR(50)')
			FROM @dpXML.nodes('/XML/Row') as Data(X) 
			WHERE ( X.value('@DownPaySysColName','NVARCHAR(50)') <>'Debit'  AND X.value('@DownPaySysColName','NVARCHAR(50)') <>'Credit')
		END
		
		SELECT @SQL='
		select * from (
		select  a.DocNo,a.Amount,abs(a.Amount)-abs(sum(isnull(b.Amount,0))) Bal '
		IF(LEN(@sDPNumCols)>0)
		BEGIN
			SET @SQL+=@sDPNumCols+',id.DebitAccount as DP_DebitAccount,id.CreditAccount as DP_CreditAccount '
		END

		SET @SQL+=' from com_billwisenonacc a WITH(NOLOCK)
		left join com_billwisenonacc b WITH(NOLOCK) on a.DocNo=b.RefDocNO and b.Docno<>'''+@docno+''' '

		IF(LEN(@sDPNumCols)>0)
		BEGIN
			SET @SQL+=' Left Join INV_DocDetails id WITH(NOLOCK) on id.VoucherNo=a.Docno 
						Left Join COM_DocNumData nd WITH(NOLOCK) on nd.InvDocDetailsID=id.InvDocDetailsID '
				if(@DimWhere<>'')
						SET @SQL+=' Left Join COM_DocCCData cd WITH(NOLOCK) on cd.InvDocDetailsID=id.InvDocDetailsID '
		END
		else if(@DimWhere<>'')
		BEGIN
			SET @SQL+='  Left Join INV_DocDetails id WITH(NOLOCK) on id.VoucherNo=a.Docno
					Left Join COM_DocCCData cd WITH(NOLOCK) on cd.InvDocDetailsID=id.InvDocDetailsID '				
			
		END
		
		
		SET @SQL+=' where a.AccountID is not null and a.AccountID='+convert(nvarchar,@AccountID)+' and a.RefDocNO='''' '
		SET @SQL+=@DimWhere	
		IF(LEN(@sDPNumCols)>0)
			SET @SQL+=' AND id.StatusID=369 '

		SET @SQL+=' group by a.DocNo,a.Amount '
		
		IF(LEN(@sDPNumCols)>0)
			SET @SQL+=',id.DebitAccount,id.CreditAccount '
			
		SET @SQL+=' ) as t
		where Bal>0.001'
		PRINT @SQL
		EXEC(@SQL)
		
		if(@linkedids<>'')
		BEGIN
			
			DECLARE @Tbl AS TABLE(ID INT NOT NULL IDENTITY(1,1), DetailsID INT,LinkedInvDocDetailsID INT)
			
			INSERT INTO @Tbl(DetailsID)
			exec SPSplitString @linkedids,','  
			set @I=0
			WHILE(1=1)
			BEGIN
				SET @CNT=(SELECT Count(*) FROM @Tbl)
				INSERT INTO @Tbl(DetailsID,LinkedInvDocDetailsID)
				SELECT INV.InvDocDetailsID,CASE WHEN T.LinkedInvDocDetailsID IS NULL THEN INV.LinkedInvDocDetailsID ELSE T.LinkedInvDocDetailsID END
				FROM INV_DocDetails INV with(nolock) 
				INNER JOIN @Tbl T ON INV.LinkedInvDocDetailsID=T.DetailsID AND ID>@I
				
				IF @CNT=(SELECT Count(*) FROM @Tbl)
					BREAK
				SET @I=@CNT
			END
			
			 	
			select a.docno from Com_BillwiseNonAcc a WITH(NOLOCK)
			join inv_docdetails b WITH(NOLOCK) on a.docno=b.voucherno
			join @Tbl c on b.InvDocDetailsID=c.DetailsID
			where a.accountid is not null and refdocno=''
			
		END
	END
	
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
