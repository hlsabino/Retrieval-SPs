USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetTRDocuments]
	@FromDate [datetime],
	@ToDate [datetime],
	@Account [bigint],
	@Filter [int],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

		 Declare @Sql nvarchar(max)
		 set @Sql=''
		 if(@Filter is not null and @Filter=1)
		 set @Sql='select * from ('
		set @Sql=@Sql+'select  D.AccDocDetailsID,D.DocID,D.ChequeNumber,
						D.CostCenterID,D.DocPrefix,D.DocNumber,
						D.VoucherNo,
						D.Amount,
						isnull((select sum(amount) from ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeid=D.AccDocDetailsID),0) TotalPaid,
						D.StatusID,
						convert(datetime,D.DocDate) DocDate,
						convert(datetime,D.DueDate) DueDate,
						R.voucherno   ConvertedVoucherNO,  R.AccDocDetailsID  ConvertedDocID
						,R.Amount Paid
						,D.CreditAccount,Cr.AccountName CrAccName,D.DebitAccount,Dr.AccountName DrAccName
						,(select PrefValue from COM_DocumentPreferences with(nolock)
							where prefname=''TRCloseDocument'' and Costcenterid=a.Costcenterid) TRCloseDoc
						from  ACC_DocDetails D  with(nolock)
		join ACC_DocDetails a with(nolock) on D.RefCCID=400 and D.RefNodeid=a.AccDocDetailsID
		left join ACC_DocDetails R with(nolock) on R.RefCCID=400 and D.AccDocDetailsID=R.RefNodeid
		join ACC_Accounts S with(nolock) on a.CreditAccount=S.AccountID
		join ACC_Accounts Cr with(nolock) on D.CreditAccount=Cr.AccountID
		join ACC_Accounts Dr with(nolock) on D.DebitAccount=Dr.AccountID
		where  S.TrustReceiptAccount=D.CreditAccount
		and D.Docdate between '+convert(nvarchar,CONVERT(FLOAT,@FromDate))+' and '+convert(nvarchar,CONVERT(FLOAT,@ToDate))+'
		and D.costcenterid in(select convert(int,PrefValue) from COM_DocumentPreferences with(nolock)
		where prefname=''LCCloseDocument'' and PrefValue is not null and PrefValue<>''''
		and isnumeric(PrefValue)=1)	'
		if(@Account is not null and  @Account>0)
			set @Sql=@Sql+' and a.CreditAccount='+convert(nvarchar,@Account)
		if(@Filter is not null and @Filter=1)
			set @Sql=@Sql+') as D'
		set @Sql=@Sql+' order by D.DocDate,D.AccDocDetailsID'
		print @Sql
		exec(@Sql)

SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
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
