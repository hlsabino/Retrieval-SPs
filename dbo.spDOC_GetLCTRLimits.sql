USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetLCTRLimits]
	@AccountID [bigint] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY   
		Declare @LCAmount float,@TRAmount float,@TRCloseAmount float,@LCCloseAmount float,@LCUsed float
		 select LetterofCredit,TrustReceipt From ACC_Accounts With(NOLOCK) WHERE AccountID=@AccountID
		
		select @LCAmount=isnull(sum(amount),0) from ACC_DocDetails with(nolock) 
		where CreditAccount=@AccountID and  StatusID=369 and costcenterid in (select DISTINCT CostCenterID  From COM_DocumentPreferences With(NOLOCK) WHERE
		PrefName='UseAsLC' and PrefValue='true')
	
		select @LCCloseAmount=isnull(sum(amount),0) from ACC_DocDetails with(nolock) 
		where RefCCID=400 and  RefNodeid in (SElect AccDocDetailsID from ACC_DocDetails with(nolock) 
		where CreditAccount=@AccountID and  StatusID=369 and costcenterid in (select DISTINCT CostCenterID  From COM_DocumentPreferences With(NOLOCK) WHERE
		PrefName='UseAsLC' and PrefValue='true'))
		 
		
		 select @TRAmount=isnull(sum(amount),0) from ACC_DocDetails with(nolock) 
		where DebitAccount=@AccountID and  StatusID=369 and costcenterid in (select DISTINCT CostCenterID  From COM_DocumentPreferences With(NOLOCK) WHERE
		PrefName='UseAsTR' and PrefValue='true')
		
		 
		select @TRCloseAmount=isnull(sum(amount),0)  from ACC_DocDetails with(nolock) 
		where RefCCID=400 and  RefNodeid in (SElect AccDocDetailsID from ACC_DocDetails with(nolock) 
		where DebitAccount=@AccountID and  StatusID=369 and costcenterid in (select DISTINCT CostCenterID  From COM_DocumentPreferences With(NOLOCK) WHERE
		PrefName='UseAsTR' and PrefValue='true'))
		
		
		 SELECT @LCUsed=isnull(sum(AdjAmount),0) FROM COM_LCBills with(nolock) WHERE  RefDocNo in (SELECT VoucherNo from ACC_DocDetails with(nolock) 
		where CreditAccount=@AccountID and  StatusID=369 and costcenterid in (select DISTINCT CostCenterID  From COM_DocumentPreferences With(NOLOCK) WHERE
		PrefName='UseAsLC' and PrefValue='true'))
		 
		select @TRAmount TRAmount,@LCAmount LCAmount,@TRAmount-@TRCloseAmount TRCloseAmount,@LCUsed LCUsed,@LCCloseAmount LCCloseAmount
		
		
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
