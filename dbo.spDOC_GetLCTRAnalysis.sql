USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetLCTRAnalysis]
	@AccIDS [nvarchar](max),
	@AsonDate [datetime],
	@AccDocdetailsID [bigint],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY   
		Declare @maraccount bigint,@Traccount bigint,@account bigint
		
		 declare @table table(ID BIGINT)  
		 insert into @table  
		 exec SPSplitString @AccIDS,',' 
		 if(@AccDocdetailsID>0)
		 BEGIN
			SELECT abs(SUM(SQ.AdjAmount)) amt FROM COM_LCBills SQ with(nolock) 
			join ACC_DocDetails a with(nolock) on a.AccDocdetailsID=@AccDocdetailsID
			WHERE SQ.RefDocNo=a.VoucherNo AND SQ.RefDocSeqNo=a.DocSeqNo

			select @maraccount=MarginAccount,@Traccount=TrustReceiptAccount,@account=AccountID from  ACC_Accounts with(nolock) 
			where AccountID =(select CreditAccount from  ACC_DocDetails with(nolock) where AccDocdetailsID=@AccDocdetailsID)

			select SUM(cr-dr) Amount,@maraccount MarginAccount,@Traccount Traccount,@account account from (
			select amount cr,0 dr from  ACC_DocDetails with(nolock) where LinkedAccDocDetailsID=@AccDocdetailsID
			and CreditAccount=@maraccount
			union all
			select 0 cr,amount dr from  ACC_DocDetails with(nolock) where LinkedAccDocDetailsID=@AccDocdetailsID
			and DebitAccount=@maraccount) as t
			
			select sum(Amount) CLoseAmount from ACC_DocDetails with(nolock)
			where RefCCID=400 and RefNodeid=@AccDocdetailsID and (LinkedAccDocDetailsID is null OR LinkedAccDocDetailsID =0)			 
		 END
		 ELSE
		 BEGIN 
			select a.AccountID,AccountCode,AccountName, LetterofCredit,TrustReceipt,isnull((	select sum(amt) from (select isnull(
			case when ac.DueDate>convert(float,@AsonDate) THEN ac.amount ELSE ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=ac.VoucherNo AND SQ.RefDocSeqNo=ac.DocSeqNo),0)     END,0)-isnull(sum(jc.amount),0) amt from ACC_DocDetails ac with(nolock)
			left join ACC_DocDetails jc with(nolock) on ac.AccDocDetailsID=jc.RefNodeid and jc.RefCCID=400   
			where ac.CreditAccount=a.AccountID and ac.docdate<=convert(float,@AsonDate) and
			ac.StatusID=369 and (ac.LinkedAccDocDetailsID is null or ac.LinkedAccDocDetailsID=0)
			and ac.costcenterid in (select DISTINCT CostCenterID  From COM_DocumentPreferences With(NOLOCK) WHERE
			PrefName='UseAsLC' and PrefValue='true')
			group by ac.amount,ac.AccDocDetailsID,ac.DocSeqNo,ac.DueDate,ac.VoucherNo) as t),0) as LCAmount

			,isnull((	select sum(amt) from (select D.Amount-isnull((select sum(amount) from ACC_DocDetails with(nolock) where RefCCID=400 and RefNodeid=D.AccDocDetailsID),0) amt
			from  ACC_DocDetails D  with(nolock)
			join ACC_DocDetails e with(nolock) on D.RefCCID=400 and D.RefNodeid=e.AccDocDetailsID
			join ACC_Accounts S with(nolock) on e.CreditAccount=S.AccountID
			where  D.Docdate <=convert(float,@AsonDate) and S.TrustReceiptAccount=D.CreditAccount
			and D.costcenterid in(select convert(int,PrefValue) from COM_DocumentPreferences with(nolock)
			where prefname='LCCloseDocument' and PrefValue is not null and PrefValue<>''
			and isnumeric( PrefValue)=1) and e.CreditAccount=a.AccountID ) as t),0) as TRAmount
			From ACC_Accounts a With(NOLOCK)
			join @table b on a.AccountID=b.ID
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
