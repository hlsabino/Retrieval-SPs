USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetLCBills]
	@AccountID [bigint] = 0,
	@IsCredit [bit],
	@VoucherNo [nvarchar](500),
	@DocSeqNo [int],
	@LocationWhere [nvarchar](max),
	@DivisionWhere [nvarchar](max),
	@DimensionWhere [nvarchar](max),
	@Docdate [datetime],
	@CostCenterID [bigint],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY 
   
		DECLARE @Sql nvarchar(max),@CustomQuery1 nvarchar(max),@PrefValue nvarchar(max),@Where nvarchar(max),
		@FeatureName nvarchar(100),@CustomQuery2 nvarchar(max),@CustomQuery3 nvarchar(max),@i int ,@CNT int,@TableName nvarchar(100)
		,@TabRef nvarchar(3),@CCID int
		--SP Required Parameters Check
		IF @AccountID=0
		BEGIN
			RAISERROR('-100',16,1)
		END
		set @Where=' and B.DocDueDate >'+convert(nvarchar,convert(float,@Docdate))
		if(@IsCredit=1)
		begin
			IF(@VoucherNo<>'')
			BEGIN
			 
				set @Sql='SELECT DocNo, abs(sum(AdjAmount)) Amount,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND (SQ.DocNo<>'''+@VoucherNo+''' AND SQ.DocSeqNo='+convert(nvarchar,@DocSeqNo)+')),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				Paid,[AdjCurrID],c.Name 
				  ,[AdjExchRT],
				a.BILLNO,Convert(DATETIME, a.Billdate) as BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber, 
				Convert(DATETIME,a.ChequeDate) as ChequeDate,
				Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_LCBills B with(nolock) 
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo)--and B.DocSeqNo=a.DocSeqNo
				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				 
			 	WHERE   AccountID='+convert(nvarchar,@AccountID)+' and AdjAmount<0 '
				
				set @Sql=@Sql+@Where

				set @Sql=@Sql+' Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name 
    			,[AdjExchRT], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,
				a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate
				having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND (SQ.DocNo<>'''+@VoucherNo+''' AND SQ.DocSeqNo='+convert(nvarchar,@DocSeqNo)+')),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				order by B.DocDate'
				exec(@Sql)
				
				print @Sql

			 SELECT 
			  [DocNo]
			  ,[DocSeqNo]
			  ,[AccountID]
			  ,[AdjAmount]
			  ,[AdjCurrID]
			  ,[AdjExchRT] 
			  ,[DocType]
			  ,[IsNewReference]
			  ,[RefDocNo]
			  ,[RefDocSeqNo]  
			  ,[Narration]
			  ,[IsDocPDC],
			 CONVERT(DATETIME,DocDate) DocDate,CONVERT(DATETIME,DocDueDate) DocDueDate,CONVERT(DATETIME,RefDocDate) RefDocDate,CONVERT(DATETIME,RefDocDueDate) RefDocDueDate
			,c.Name	from COM_LCBills b with(nolock) 
			left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
			 	where DocNo=@VoucherNo and [DocSeqNo]=@DocSeqNo
				and [AccountID]=@AccountID
			END
			ELSE
			BEGIN
				set @Sql='SELECT DocNo, abs(sum(AdjAmount)) Amount,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo  AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				Paid,[AdjCurrID],c.Name
				  ,[AdjExchRT],
				a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber,
				Convert(DATETIME,a.ChequeDate) as ChequeDate,
				Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_LCBills B  with(nolock)
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo) 
				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				
			 	WHERE   AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount<0'
			 	
				set @Sql=@Sql+@Where
				
				set @Sql=@Sql+' Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name
				  ,[AdjExchRT], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,
         		  a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate
		    		having abs(sum(AdjAmount)) >
					ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
					+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
					order by B.DocDate'
				print @Sql
				exec(@Sql)
			END
		END
		ELSE
		BEGIN
		
			IF(@VoucherNo<>'')
			BEGIN
				set @Sql='SELECT DocNo, abs(sum(AdjAmount)) Amount,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND (SQ.DocNo<>'''+@VoucherNo+''' AND SQ.DocSeqNo='+convert(nvarchar,@DocSeqNo)+')),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				Paid,[AdjCurrID],c.Name
				  ,[AdjExchRT]
				,a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber,
				Convert(DATETIME,a.ChequeDate) as ChequeDate,Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_LCBills B with(nolock) 
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo)--and B.DocSeqNo=a.DocSeqNo
				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID  
				 
				WHERE   AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount >0'

				set @Sql=@Sql+@Where

				
				set @Sql=@Sql+' Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name
				  ,[AdjExchRT], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,
				  a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate
				having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND (SQ.DocNo<>'''+@VoucherNo+''' AND SQ.DocSeqNo='+convert(nvarchar,@DocSeqNo)+')),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				order by B.DocDate'
				
				exec(@Sql)

				SELECT  [DocNo]
				  ,[DocSeqNo]
				  ,[AccountID]
				  ,[AdjAmount]
				  ,[AdjCurrID]
				  ,[AdjExchRT] 
				  ,[DocType]
				  ,[IsNewReference]
				  ,[RefDocNo]
				  ,[RefDocSeqNo]  
				  ,[Narration]
				  ,[IsDocPDC],
				CONVERT(DATETIME,DocDate) DocDate,CONVERT(DATETIME,DocDueDate) DocDueDate,CONVERT(DATETIME,RefDocDate) RefDocDate,CONVERT(DATETIME,RefDocDueDate) RefDocDueDate
				,c.Name	from COM_LCBills b with(nolock) 
			left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
		 		where DocNo=@VoucherNo and [DocSeqNo]=@DocSeqNo
			 and [AccountID]=@AccountID
			END
			ELSE
			BEGIN
				set @Sql='SELECT DocNo, abs(sum(AdjAmount)) Amount,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				Paid,[AdjCurrID],c.Name
                ,[AdjExchRT]
				,a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber, 
				Convert(DATETIME,a.ChequeDate) as ChequeDate,Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_LCBills B  with(nolock)
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo)
					left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				 
		 		WHERE  AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount >0'

				set @Sql=@Sql+@Where


				set @Sql=@Sql+' Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name 
				  ,[AdjExchRT],a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName, a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate 
				having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_LCBills SQ with(nolock) WHERE SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0)
				order by B.DocDate'
				
				--print @Sql
				exec(@Sql)
			END
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
