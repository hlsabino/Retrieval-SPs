USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetChequeReturnHistory]
	@AccountID [int] = 0,
	@IsCredit [bit],
	@VoucherNo [nvarchar](500),
	@DocSeqNo [int],
	@LocationWhere [nvarchar](max),
	@DivisionWhere [nvarchar](max),
	@DimensionWhere [nvarchar](max),
	@Docdate [datetime],
	@CostCenterID [int],
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
		
		set @Where=''
		if(@LocationWhere is not null and @LocationWhere<>'')
			set @Where=@Where+' and dcCCNID2 in ('+@LocationWhere+')'

		if(@DivisionWhere is not null and @DivisionWhere<>'')
			set @Where=@Where+' and dcCCNID1 in ('+@DivisionWhere+')'
			
		if(@DimensionWhere is not null and @DimensionWhere<>'')
		begin
			 set @PrefValue=''
			select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise Bills'  
		    
			if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)  
			begin  
				  set @PrefValue=convert(INT,@PrefValue)-50000  						 
				  set @Where=@Where+' and dcCCNID'+@PrefValue+' in ('+@DimensionWhere+')'
			end  			
		end
		
		declare @Tab table(ID int identity(1,1),Name int,TabName nvarchar(100))
		
		insert into @Tab		
		SELECT a.FeatureID,TableName
		FROM ADM_Features a with(nolock)
		join ADM_GridViewColumns g with(nolock) on a.FeatureID=g.CostCenterColID
		join adm_gridview gr with(nolock) on gr.GridViewID=g.GridViewID and gr.costcenterid=159
		WHERE  IsEnabled=1  and a.FeatureID>50000

		set @i=1
		set @CustomQuery1=''
		set @CustomQuery2=', '
		set @CustomQuery3=', '
		select @CNT=count(id) from @Tab
		while (@i<=	@CNT)
		begin
		
		select @FeatureName=name,@CCID=name,@TableName=TabName from @Tab where ID=@i
		
    	set @TabRef='A'+CONVERT(nvarchar,@i)
    	set @CCID=@CCID-50000
    	  
		if(@CCID>0)
		begin
			set @CustomQuery1=@CustomQuery1+' left join '+@TableName+' '+@TabRef+' with(nolock) on '+@TabRef+'.NodeID=B.dcCCNID'+CONVERT(nvarchar,@CCID)
			set @CustomQuery2=@CustomQuery2+' '+@TabRef+'.Name ,'
			set @CustomQuery3=@CustomQuery3+' '+@TabRef+'.Name as A'+@FeatureName+' ,'
		end
	    set @i=@i+1
		end
		if(len(@CustomQuery2)>0)
		begin
			set @CustomQuery2=SUBSTRING(@CustomQuery2,0,LEN(@CustomQuery2)-1)
	    end
	    
		if(len(@CustomQuery3)>0)
		begin
	    set @CustomQuery3=SUBSTRING(@CustomQuery3,0,LEN(@CustomQuery3)-1)
		end
		IF(@VoucherNo<>'')
		BEGIN
			set @VoucherNo=replace(@VoucherNo,'''','''''')
		END
		
		if(@IsCredit=1)
		begin
			IF(@VoucherNo<>'')
			BEGIN
			  
				set @Sql='SELECT DocNo, abs(sum(AdjAmount)) Amount,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_ChequeReturn SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo='''+@VoucherNo+''' AND SQ.DocSeqNo='+convert(nvarchar,@DocSeqNo)+')),0) 
				Paid,[AdjCurrID],c.Name 
				  ,[AdjExchRT],
				a.BILLNO,Convert(DATETIME, a.Billdate) as BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber, 
				Convert(DATETIME,a.ChequeDate) as ChequeDate,
				Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate '+@CustomQuery3+'
				FROM COM_ChequeReturn B with(nolock) 
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo)--and B.DocSeqNo=a.DocSeqNo
				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				'+@CustomQuery1+'
			 	WHERE IsNewReference=1 and AccountID='+convert(nvarchar,@AccountID)+' and AdjAmount<0 '
				
				set @Sql=@Sql+@Where

				set @Sql=@Sql+' Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name '+@CustomQuery2+'
    			,[AdjExchRT], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,
				a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate
				having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_ChequeReturn SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo='''+@VoucherNo+''' AND SQ.DocSeqNo='+convert(nvarchar,@DocSeqNo)+')),0) 				
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
			,c.Name	from COM_ChequeReturn b  with(nolock)
			left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
			 	where RefDocNo=@VoucherNo and RefDocSeqNo=@DocSeqNo
				and [AccountID]=@AccountID
			END
			ELSE
			BEGIN
				set @Sql='SELECT DocNo, abs(sum(AdjAmount)) Amount,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_ChequeReturn SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo  AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				Paid,[AdjCurrID],c.Name'+@CustomQuery3+'
				  ,[AdjExchRT],
				a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber,
				Convert(DATETIME,a.ChequeDate) as ChequeDate,
				Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_ChequeReturn B  with(nolock)
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo) 
				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				'+@CustomQuery1+'
			 	WHERE IsNewReference=1 and  AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount<0'
			 	
				set @Sql=@Sql+@Where
				
				set @Sql=@Sql+'Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name'+@CustomQuery2+'
				  ,[AdjExchRT], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,
         		  a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate
		    		having abs(sum(AdjAmount)) >
					ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_ChequeReturn SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
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
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_ChequeReturn SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND  not (SQ.RefDocNo='''+@VoucherNo+''' AND SQ.RefDocSeqNo='+convert(nvarchar,@DocSeqNo)+')),0) 
				Paid,[AdjCurrID],c.Name'+@CustomQuery3+'
				  ,[AdjExchRT]
				,a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber,
				Convert(DATETIME,a.ChequeDate) as ChequeDate,Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_ChequeReturn B  with(nolock)
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo)--and B.DocSeqNo=a.DocSeqNo
				left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID  
				 '+@CustomQuery1+'
				WHERE  IsNewReference=1 and AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount >0'

				set @Sql=@Sql+@Where

				
				set @Sql=@Sql+'Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name'+@CustomQuery2+'
				  ,[AdjExchRT], a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName,
				  a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate
				having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_ChequeReturn SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo AND not (SQ.DocNo='''+@VoucherNo+''' AND SQ.DocSeqNo='+convert(nvarchar,@DocSeqNo)+')),0) 
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
				,c.Name	from COM_ChequeReturn b  with(nolock)
			left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
		 		where RefDocNo=@VoucherNo and RefDocSeqNo=@DocSeqNo
			 and [AccountID]=@AccountID
			END
			ELSE
			BEGIN
				set @Sql='SELECT DocNo, abs(sum(AdjAmount)) Amount,B.DocSeqNo,CONVERT(DATETIME,B.DocDate) DocDate ,CONVERT(DATETIME,DocDueDate) DocDueDate,
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_ChequeReturn SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				Paid,[AdjCurrID],c.Name'+@CustomQuery3+'
                ,[AdjExchRT]
				,a.BILLNO, Convert(DATETIME, a.Billdate) AS BillDate, a.CommonNarration, a.ChequeBankName, a.ChequeNumber, 
				Convert(DATETIME,a.ChequeDate) as ChequeDate,Convert(DATETIME,a.ChequeMaturityDate) as  ChequeMaturityDate 
				FROM COM_ChequeReturn B with(nolock) 
				inner join acc_docdetails a with(nolock) on B.DocNo=a.VoucherNo and a.AccDocDetailsID =(select Min(AccDocDetailsID) from acc_docdetails temp with(nolock) where temp.VoucherNo=B.DocNo)
					left join COM_Currency c with(nolock) on c.CurrencyID=b.AdjCurrID
				 '+@CustomQuery1+'
		 		WHERE IsNewReference=1 and AccountID='+convert(nvarchar,@AccountID)+'  and AdjAmount >0'

				set @Sql=@Sql+@Where


				set @Sql=@Sql+'Group By DocNo,B.DocSeqNo,B.DocDate,DocDueDate,[AdjCurrID],c.Name '+@CustomQuery2+'
				  ,[AdjExchRT],a.BILLNO, Convert(DATETIME, a.Billdate), a.CommonNarration, a.ChequeBankName, a.ChequeNumber, a.ChequeDate,a.ChequeMaturityDate 
				having abs(sum(AdjAmount)) >
				ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_ChequeReturn SQ with(nolock) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				order by B.DocDate'
				
				print @Sql
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
