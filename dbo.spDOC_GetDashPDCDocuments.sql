USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDashPDCDocuments]
	@Location [nvarchar](max),
	@SELECTQRY [nvarchar](max),
	@FROMQRY [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;     

   DECLARE @SQL NVARCHAR(MAX),@days bigint,@DtNextTo datetime,@DT float
    
   select @days=Value from ADM_GlobalPreferences with(nolock) where name='PDC For Next'
   SET  @DtNextTo=dateadd(day,@days,getdate())
   print @DtNextTo
						 
  SET @SQL = '  select  D.AccDocDetailsID,
						D.CostCenterID,
						D.VoucherNo,
						D.Amount,
						D.StatusID,
						D.DocPrefix,
						D.DocNumber,
						convert(datetime,DocDate) DocDate,
						convert(datetime,ChequeMaturityDate) ChequeMaturityDate,
						convert(datetime,ChequeMaturityDate) BillDate,
						C.Status,DT.DocumentName as DocumentName,
						DT.ConvertAS,
						DT.DocumentType,
						DT.Bounce,
						DT.Series,
						DT.DocumentType,
						D.ChequeNumber,
						A.AccountName as BankAccountID,
						D.DebitAccount as BankAccountID_Key,
						S.AccountName as AccountID,
						D.CreditAccount as AccountID_Key,isnull(D.IsNegative,0) IsNegative,
						D.CreditAccount as ActDr,D.BankAccountID BankID,BA.AccountName BankName,D.DocumentType,convert(datetime,D.ChequeDate) ChequeDate'+@SELECTQRY+'
					from  ACC_DocDetails D with(nolock) join COM_Status C with(nolock) on D.StatusID=C.StatusID
					join ADM_DocumentTypes DT with(nolock) on D.CostCenterID=DT.CostCenterID
					join ACC_Accounts A with(nolock) on D.DebitAccount=A.AccountID
					join ACC_Accounts S with(nolock) on D.CreditAccount=S.AccountID
					left join ACC_Accounts BA with(nolock) on D.BankAccountID=BA.AccountID
					join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'+@FROMQRY+'
					where   C.Status=''PDC'' and D.ChequeMaturityDate <= '+convert(nvarchar,convert(float,@DtNextTo))+'  and DT.DocumentType=19 '
					IF(@Location IS NOT NULL AND @Location <>'' AND @Location <> '0' )
					BEGIN
						SET @SQL = @SQL  + ' and L.dcCCNID2 in (' + @Location +') '
					END
					 
					SET @SQL = @SQL  + '  union
					select  D.AccDocDetailsID,
						D.CostCenterID,
						D.VoucherNo,
						D.Amount,
						D.StatusID,
						D.DocPrefix,
						D.DocNumber,
						convert(datetime,DocDate) DocDate,
						convert(datetime,ChequeMaturityDate) ChequeMaturityDate,
						convert(datetime,ChequeMaturityDate) BillDate,
						C.Status,DT.DocumentName as DocumentName,
						DT.ConvertAS,
						DT.DocumentType,
						DT.Bounce,
						DT.Series,
						DT.DocumentType,
						D.ChequeNumber,
						S.AccountName as BankAccountID,
						D.CreditAccount as BankAccountID_Key,
						A.AccountName as AccountID,
						D.DebitAccount as AccountID_Key,isnull(D.IsNegative,0) IsNegative,
						D.DebitAccount as ActDr,D.BankAccountID BankID,BA.AccountName BankName,D.DocumentType,convert(datetime,D.ChequeDate) ChequeDate'+@SELECTQRY+'
					from  ACC_DocDetails D with(nolock) join COM_Status C with(nolock) on D.StatusID=C.StatusID
					join ADM_DocumentTypes DT on D.CostCenterID=DT.CostCenterID
					join ACC_Accounts A with(nolock) on D.DebitAccount=A.AccountID
					join ACC_Accounts S with(nolock) on D.CreditAccount=S.AccountID
					left join ACC_Accounts BA with(nolock) on D.BankAccountID=BA.AccountID
					join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID'+@FROMQRY+'
					where   C.Status=''PDC'' and D.ChequeMaturityDate <= '+convert(nvarchar,convert(float,@DtNextTo))+' and   DT.DocumentType=14 ' 
					IF(@Location IS NOT NULL AND @Location <>'' AND @Location <> '0' )
					BEGIN
						SET @SQL = @SQL  + ' and L.dcCCNID2 in (' + @Location +')   '
					END
					 
			print @SQL	 
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
