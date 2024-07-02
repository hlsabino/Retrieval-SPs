USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetAccDocumentByVersion]
	@CostCenterID [int],
	@DocID [bigint],
	@Version [int],
	@MaxID [bigint],
	@UserID [int] = 0,
	@RoleID [bigint] = 0,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit,@VoucherNo NVARCHAR(500),@canEdit bit,@ModifiedDate float
		Declare @WID bigint,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@HIstory bit


			SELECT @VoucherNo=VoucherNo  FROM [ACC_DocDetails] WITH(NOLOCK)
			WHERE CostCenterID=@CostCenterID AND DocID=@DocID
			if(@Version =-1)
			BEGIN				
				SELECT @ModifiedDate=ModifiedDate,@Version=versionno FROM  [ACC_DocDetails_History] D WITH(NOLOCK) 
				WHERE AccDocDetailsHistoryID=@MaxID
			END
			ELSE
			BEGIN
				SELECT @ModifiedDate=max(ModifiedDate) FROM  [ACC_DocDetails_History] D WITH(NOLOCK) 
				WHERE CostCenterID=@CostCenterID AND DocID=@DocID and versionno=@Version						
			END
				 
			--GETTING DOCUMENT DETAILS
			SELECT A.[AccDocDetailsID] AS DocDetailsID,A.VoucherNO
					  ,A.[InvDocDetailsID]
					  ,A.[DocID]
					  ,A.[CostCenterID]					  
					  ,A.[DocumentType]
					  ,A.[VersionNo]
					  ,A.[DocAbbr]
					  ,A.[DocPrefix]
					  ,A.[DocNumber]
					  ,CONVERT(DATETIME, A.[DocDate]) AS DocDate
					  ,CONVERT(DATETIME, A.[DueDate]) AS DueDate
					  ,A.[ChequeBankName]
					  ,A.[ChequeNumber]
					  ,CONVERT(DATETIME,A.[ChequeDate]) AS ChequeDate
					  ,CONVERT(DATETIME,A.[ChequeMaturityDate]) AS ChequeMaturityDate
					  ,A.[StatusID]
					  ,A.[BillNo]
						,CONVERT(DATETIME,A.BILLDATE) AS BILLDATE
					  ,A.[LinkedAccDocDetailsID]
					  ,A.[CommonNarration]
						,A.lineNarration
					  ,A.[DocSeqNo]
					  ,A.[DebitAccount]
					  ,A.[CreditAccount]					  
					  ,A.[Amount]
					  ,A.IsNegative
					  ,A.[CurrencyID]
					  ,A.[ExchangeRate]
					  ,A.[CompanyGUID]
					  ,A.[GUID]
					  ,A.[Description]
					  ,A.[CreatedBy]
					  ,CONVERT(DATETIME,A.[CreatedDate]) AS CreatedDate
					  ,A.[ModifiedBy]
					  ,CONVERT(DATETIME,A.[ModifiedDate]) AS ModifiedDate
					  ,amountfc
					  ,db.IsBillwise DBIsBillwise ,cr.IsBillwise CrIsBillwise
					  ,db.AccountCode DBAccountCode,cr.AccountCode CrAccountCode
					  ,db.AccountName DBAccountName,cr.AccountName CrAccountName
					  ,RefCCID,RefNodeid,BankAccountID
				  FROM [ACC_DocDetails_History] A WITH(NOLOCK)  
				  join ACC_Accounts db WITH(NOLOCK) on A.[DebitAccount]=db.AccountID
				  join ACC_Accounts cr WITH(NOLOCK) on A.[CreditAccount]=cr.AccountID
				  WHERE A.CostCenterID=@CostCenterID AND A.DocID=@DocID and docid<>0 and versionno=@Version and 
				  (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0) and a.ModifiedDate=@ModifiedDate
				  order by DocSeqNo
		
			--GETTING DOCUMENT EXTRA COSTCENTER FEILD DETAILS
			SELECT A.* FROM  [COM_DocCCData_History] A WITH(NOLOCK)  
			join [ACC_DocDetails_History] B WITH(NOLOCK) on  A.AccDocDetailsID =B.AccDocDetailsID
			WHERE CostCenterID=@CostCenterID AND B.DocID=@DocID and docid<>0 and versionno=@Version and 
				  (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0) and a.ModifiedDate=@ModifiedDate
			order by DocSeqNo
		 
			--GETTING DOCUMENT EXTRA NUMERIC FEILD DETAILS
			SELECT A.*  FROM [COM_DocNumData_History] A WITH(NOLOCK)  
			join [ACC_DocDetails_History] B WITH(NOLOCK) on  A.AccDocDetailsID =B.AccDocDetailsID
			WHERE CostCenterID=@CostCenterID AND B.DocID=@DocID and docid<>0 and versionno=@Version and a.ModifiedDate=@ModifiedDate
			order by DocSeqNo

			--GETTING DOCUMENT EXTRA TEXT FEILD DETAILS
			SELECT A.*  FROM [COM_DocTextData_History] A WITH(NOLOCK)  
			join [ACC_DocDetails_History] B WITH(NOLOCK) on  A.AccDocDetailsID =B.AccDocDetailsID
			WHERE CostCenterID=@CostCenterID AND B.DocID=@DocID and docid<>0 and versionno=@Version and a.ModifiedDate=@ModifiedDate
			order by DocSeqNo

			--GETTING BillWise
			SELECT [DocNo],RefStatusID,A.[DocSeqNo],[AccountID],[AdjAmount],[AdjCurrID],[AdjExchRT]
			,[IsNewReference],[RefDocNo],[RefDocSeqNo],convert(datetime,RefDocDate) RefDocDate,convert(datetime,RefDocDueDate) RefDocDueDate,[RefBillWiseID]
			,[Narration],A.[AmountFC],IsDocPDC,DiscAmount FROM COM_Billwise a WITH(NOLOCK)			
			WHERE [DocNo]=@VoucherNo




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
