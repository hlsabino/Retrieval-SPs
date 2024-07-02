USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_CheckAccCreditDetails]
	@AccountID [int] = 0,
	@DocDate [datetime],
	@DocID [int] = 0,
	@CostCenterID [int] = 0,
	@Amt [float],
	@LocationID [int] = 0,
	@DivisionID [int] = 0,
	@DimensionID [int] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON
	
	--Declaration Section
	DECLARE @DebitAmount FLOAT, @CreditAmount FLOAT, @CreditLimt FLOAT, @DebitLimt FLOAT, @Bal FLOAT, @LimitExceeds INT, @IsInv int,@crDays int,@drDays int,@CNT INT,@DimNodeID INT
	DECLARE @CCWhere nvarchar(max),@includepdc nvarchar(10),@includeunposted nvarchar(10),@AccWhere nvarchar(max),@currID INT,@exrt float,@isCurrWise bit,@FeatureID INT,@dtype int
	SET @LimitExceeds=0
	SET @DebitAmount=0
	SET @CreditAmount=0
	SET @Bal=0
	
	select @IsInv=IsInventory,@dtype=DocumentType from ADM_DocumentTypes WITH(NOLOCK) where costcenterid=@CostCenterID
	
	 
	set @AccWhere=''		
		
	select @includepdc=value from adm_globalpreferences with(nolock)
	where name='IncludePDCs'
	
	select @includeunposted=value from adm_globalpreferences with(nolock)
	where name='IncludeUnPostedDocs'
	
	if exists(select value from COM_CostCenterPreferences with(nolock)
	where name='UseCurrencyDbCr' and Value='true')
		set @isCurrWise=1
	ELSE
		set @isCurrWise=0
	
	if(@includepdc='true')
	begin
		if(@includeunposted<>'true')
			set @AccWhere=@AccWhere+' and ((DocumentType not in(14,19) and StatusID=369) or (DocumentType in(14,19) and StatusID=370))'
		else
			set @AccWhere=@AccWhere+' and (DocumentType not in(14,19) or (DocumentType in(14,19) and StatusID=370))'
	end	
	else
		set @AccWhere=@AccWhere+' and DocumentType not in(14,19)'
		
	if(@includeunposted<>'true' and @includepdc<>'true')
		set @AccWhere=@AccWhere+' and StatusID=369'
			
		
	declare @LocWise bit,@DivWise bit,@SQL nvarchar(max),@DebitSQL nvarchar(max),@CreditSQL nvarchar(max),@DimWise INT
	if (select count(value) from adm_globalpreferences WITH(NOLOCK)
		where name in('EnableLocationWise','LW CreditDebit') and value='true')=2
		set @LocWise=1
	else
		set @LocWise=0
	  
	if (select count(value) from adm_globalpreferences WITH(NOLOCK)
		where name in('EnableDivisionWise','DW CreditDebit') and value='true')=2
		set @DivWise=1
	else
		set @DivWise=0
		
	SELECT @DimWise=ISNULL(CONVERT(INT,value),0) from adm_globalpreferences WITH(NOLOCK) where name='DimWiseCreditDebit'
		
	set @CCWhere=''
	--Credit Limit for the account
	IF(@LocWise=1 OR @DivWise=1 OR @DimWise>0)
	BEGIN
		SET @SQL='SELECT @currID=CurrencyID,@CreditLimt=CreditAmount,@DebitLimt=DebitAmount,@crDays=CreditDays,@drDays=DebitDays FROM Acc_CreditDebitAmount WITH(NOLOCK)
				  where AccountID='+CONVERT(NVARCHAR,@AccountID)
		
		if(@LocWise=1)
		BEGIN
			SET @SQL=@SQL+' and LocationID='+CONVERT(NVARCHAR,@LocationID)
			set @CCWhere=' and DCC.dcCCNID2='+convert(nvarchar,@LocationID)
		END
		
		if(@DivWise=1)
		BEGIN
			SET @SQL=@SQL+' and DivisionID='+CONVERT(NVARCHAR,@DivisionID)
			set @CCWhere=@CCWhere+' and DCC.dcCCNID1='+convert(nvarchar,@DivisionID)
		END
		
		IF(@DimWise>0)
		BEGIN
			SET @SQL=@SQL+' and DimensionID='+CONVERT(NVARCHAR,@DimensionID)
			set @CCWhere=@CCWhere+' and DCC.dcCCNID'+CONVERT(NVARCHAR,(@DimWise-50000))+'='+convert(nvarchar,@DimensionID)
		END
		
		print @SQL
		exec sp_executesql @SQL,N'@currID FLOAT output,@CreditLimt FLOAT output,@DebitLimt FLOAT output,@crDays INT output,@drDays INT output',@currID OUTPUT,@CreditLimt output,@DebitLimt output,@crDays output,@drDays output
	END
	ELSE
	BEGIN
		SELECT @currID=Currency,@CreditLimt=Creditlimit,@DebitLimt=Debitlimit,@crDays=CreditDays,@drDays=DebitDays FROM Acc_Accounts WITH(NOLOCK)
		where AccountID=@AccountID
	END
	
	if(@currID>0 and @isCurrWise=1)
	BEGIN
			set @FeatureID=0
			select @FeatureID=isnull(value,0) from ADM_GlobalPreferences WITH(NOLOCK) 
			where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
			
			if(@FeatureID=50002 and @LocationID>0)
				select @DimNodeID=@LocationID
			else if(@FeatureID=50001 and @DivisionID>0)
				select @DimNodeID=@DivisionID	
			else if(@FeatureID=@DimWise and @DimensionID>0)
				select @DimNodeID=@DimensionID
				

			 SET @CNT = 0
			 SELECT @CNT = COUNT(CurrencyID) FROM COM_EXCHANGERATES WITH(NOLOCK) 
			 WHERE CURRENCYID = @currID and EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
			 and DimNodeID=@DimNodeID
	 
			IF( @CNT > 0 )
			BEGIN
				SELECT TOP 1 @exrt=ExchangeRate FROM  COM_EXCHANGERATES WITH(NOLOCK) 
				where CurrencyID = @currID AND EXCHANGEDATE <= CONVERT(FLOAT,convert(datetime,@DocDate))
				and DimNodeID=@DimNodeID
				ORDER BY EXCHANGEDATE DESC
			END 
			ELSE
				SELECT @exrt=ExchangeRate FROM COM_Currency WITH(NOLOCK) where CurrencyID = @currID

		set @CreditLimt =@CreditLimt *@exrt
		set @DebitLimt  =@DebitLimt  *@exrt
		
	END
	
	if (@Amt<0 and @CreditLimt>0) or (@Amt>0 and @DebitLimt>0)
	begin

		SET @SQL='DECLARE @AccountID INT,@DocDate FLOAT	
		declare @tab table(id INT)
		insert into @tab
		select InvDocDetailsID from Inv_DocDetails WITH(NOLOCK) where DOCID='+CONVERT(NVARCHAR,@DocID)+'
		SET @DocDate='+CONVERT(NVARCHAR,CONVERT(FLOAT,@DocDate)) 

		SET @SQL=@SQL+' SET @AccountID='+CONVERT(NVARCHAR,@AccountID)+'
		SELECT  @DebitAmount=ISNULL(SUM(DebitAmount),0),@CreditAmount=ISNULL(SUM(CreditAmount),0) FROM (
		
		SELECT D.Amount DebitAmount,0 CreditAmount FROM ACC_DocDetails D WITH(NOLOCK)  
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=D.AccDocDetailsID'+@CCWhere+'
		WHERE D.DebitAccount=@AccountID '+@AccWhere+'  AND D.DocDate<= @DocDate'
		if(@IsInv=0 and @DocID>0)
			SET @SQL=@SQL+' and D.DOCID<>'+CONVERT(NVARCHAR,@DocID)
		SET @SQL=@SQL+' UNION ALL
		SELECT 0 DebitAmount,D.Amount CreditAmount FROM ACC_DocDetails D WITH(NOLOCK)  
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON   DCC.AccDocDetailsID=D.AccDocDetailsID'+@CCWhere+'
		WHERE D.CreditAccount=@AccountID '+@AccWhere+' AND D.DocDate<= @DocDate'
		if(@IsInv=0 and @DocID>0)
			SET @SQL=@SQL+' and D.DOCID<>'+CONVERT(NVARCHAR,@DocID)
		SET @SQL=@SQL+' UNION ALL
		SELECT D.Amount DebitAmount,0 CreditAmount FROM ACC_DocDetails D WITH(NOLOCK)  
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere
		
		if(@IsInv=1 and @DocID>0)
			SET @SQL=@SQL+' left join @tab t on D.InvDocDetailsID=t.id '
		
		SET @SQL=@SQL+' WHERE D.DebitAccount=@AccountID '+@AccWhere+' AND D.DocDate<= @DocDate'
		if(@IsInv=1 and @DocID>0)
			SET @SQL=@SQL+' and t.id is null '
		SET @SQL=@SQL+' UNION ALL
		SELECT 0 DebitAmount,D.Amount CreditAmount FROM ACC_DocDetails D WITH(NOLOCK)  
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID'+@CCWhere
		if(@IsInv=1 and @DocID>0)
			SET @SQL=@SQL+' left join @tab t on D.InvDocDetailsID=t.id '

		SET @SQL=@SQL+' WHERE D.CreditAccount=@AccountID '+@AccWhere+' AND D.DocDate<= @DocDate'
		if(@IsInv=1 and @DocID>0)
			SET @SQL=@SQL+' and t.id is null '		
		SET @SQL=@SQL+') AS T'
		
		print @SQL
		exec sp_executesql @SQL,N'@CreditAmount FLOAT output,@DebitAmount FLOAT  output',@CreditAmount output,@DebitAmount output
 	 END
 	 
	if(@Amt<0 and @CreditLimt>0)
	begin
		if((@CreditAmount-@DebitAmount+(-@Amt))>@CreditLimt)
			select 1
		else
			select 0
	end
	else if(@Amt>0 and @DebitLimt>0)
	begin
		if((@DebitAmount-@CreditAmount+@Amt)>@DebitLimt)
			select 1
		else
			select 0
	end
	else
		select 0
	
	set @AccWhere=''	
	if(@Amt>0)
	BEGIN
	 if(@drDays>0)
		set @AccWhere=' >0 and DOCDueDate is not null and convert(Datetime,DOCDueDate)<'''+CONVERT(nvarchar,@DocDate)+''''
	ELSE
		set @AccWhere=' >0 and DOCDueDate is not null and DocDate<>DOCDueDate and convert(Datetime,DOCDueDate)<'''+CONVERT(nvarchar,@DocDate)+''''	
	END	
	else if(@Amt<0)
	BEGIN
		if(@crDays>0)
			set @AccWhere=' <0 and DOCDueDate is not null and  convert(Datetime,DOCDueDate)<'''+CONVERT(nvarchar,@DocDate)+''''	
		else
			set @AccWhere=' <0 and DOCDueDate is not null and  DocDate<>DOCDueDate and convert(Datetime,DOCDueDate)<'''+CONVERT(nvarchar,@DocDate)+''''
	END		
	
	if(@AccWhere<>'')
	BEGIN
		SET @SQL='SELECT DocNo FROM COM_Billwise B  with(nolock)				
 		WHERE statusid =369 and  AccountID='+CONVERT(NVARCHAR,@AccountID)+' and AdjAmount '+@AccWhere+REPLACE(@CCWhere,'DCC.','B.')+'	
		Group By AccountID,B.DocSeqNo,B.DocNo,DocDate
		having (abs (abs(sum(AdjAmount)) -(
		ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID= '+CONVERT(NVARCHAR,@AccountID)+' and   SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) 
				+ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ with(nolock) WHERE  SQ.AccountID='+CONVERT(NVARCHAR,@AccountID)+' and  SQ.DocNo=B.DocNo AND SQ.DocSeqNo=B.DocSeqNo AND IsNewReference=0),0))))>0.00001'
	
		print @SQL
		exec(@SQL)		
	END
		
		 
SET NOCOUNT OFF;
RETURN @LimitExceeds
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
