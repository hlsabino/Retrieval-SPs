USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_LOBFIFO]
	@ReportType [int],
	@GTPQRY [nvarchar](max),
	@GTPWHERE [nvarchar](max),
	@AccountingDate [datetime] = NULL,
	@ToDate [datetime],
	@DateFilter [nvarchar](20),
	@IsReceivable [bit],
	@StatusWhere [nvarchar](max),
	@sbInnerWhere [nvarchar](max),
	@IncludePDC [bit],
	@PDCSeperate [bit],
	@FilterPDCOnMaturityDate [bit],
	@CurrencyType [int],
	@CurrencyID [int],
	@IsBillNoExists [bit],
	@IsBillDateExists [bit],
	@SalesDocs [nvarchar](max),
	@AccountTypeFilter [nvarchar](max),
	@strCols [nvarchar](max),
	@TagID [int],
	@TagColID [nvarchar](50),
	@strGroups [nvarchar](max),
	@SELECTQUERY [nvarchar](max),
	@SelectTagAliasOnly [nvarchar](max),
	@FROMQUERY [nvarchar](max),
	@FutureSlabs [bit],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
	DECLARE @SQL NVARCHAR(MAX),@PDCSQL NVARCHAR(MAX),@DocDateCol nvarchar(100),@TagCol nvarchar(20),@TagDbCol nvarchar(20),@StrTemp nvarchar(max)
	DECLARE @To NVARCHAR(20),@AmtColumn NVARCHAR(10),@CurrWHERE1 NVARCHAR(20),@Var1 nvarchar(20),@Var2 nvarchar(20),@Var3 nvarchar(20)
	,@FSQL NVARCHAR(MAX)='',@TEMPSQL NVARCHAR(MAX)=''
	SET @To=CONVERT(FLOAT,@ToDate)
	IF @CurrencyID>0
	BEGIN
		SET @AmtColumn='AmountFC'
		SET @CurrWHERE1=' AND B.CurrencyID='+CONVERT(NVARCHAR,@CurrencyID)
	END
	ELSE
	BEGIN
		IF @CurrencyType=1
			SET @AmtColumn='AmountBC'
		ELSE
			SET @AmtColumn='Amount'
		SET @CurrWHERE1=''
	END
	
	if(@TagID>0)
	begin
		set @TagCol=',TAG'
		set @TagDbCol=',dcCCNID'+convert(nvarchar,@TagID-50000)
	end
	else
	begin
		set @TagCol=''
		set @TagDbCol=''
	end
	
	if(@DateFilter='DocDueDate')
		set @DateFilter='DueDate'
		
	declare @str nvarchar(max),@MainAccount nvarchar(20),@AdjAccount nvarchar(20),@Where nvarchar(max)
	if @IsReceivable=0
	begin
		set @MainAccount='CreditAccount'
		set @AdjAccount='DebitAccount'
	end
	else
	begin
		set @MainAccount='DebitAccount'
		set @AdjAccount='CreditAccount'
	end

	set @Where='
WHERE A.AccountID>0'
	if(@DateFilter='DueDate')
		set @Where=@Where+' AND isnull(B.DueDate,B.DocDate)<=@To '
	else
		set @Where=@Where+' AND B.' +@DateFilter + '<=@To '
	
	set @Where=@Where+@sbInnerWhere
	if(len(@GTPWHERE)>0)
		set @Where=@Where+' AND A.' + @GTPWHERE
	set @Where=@Where+@CurrWHERE1
                 
	if (@IncludePDC=1)
	begin
		if (@PDCSeperate=1 or @FilterPDCOnMaturityDate=1)
			set @Where=@Where+' AND (DocumentType<>14 AND DocumentType<>19' + @StatusWhere + ')'
		else
			set @Where=@Where+' AND ((B.StatusID=370 or B.StatusID=439) OR (DocumentType<>14 AND DocumentType<>19' + @StatusWhere + '))'
	end
	else
	begin
		set @Where=@Where+' AND DocumentType<>14 AND DocumentType<>19' + @StatusWhere
	end

	set @Var1='BillAmount'
	set @Var2='Amount'
	set @Var3='Adjusted'
          
	if(@ReportType=10)
	begin
		
		if(@DateFilter='DueDate')
			set @DocDateCol='CONVERT(DATETIME,max(isnull(B.'+@DateFilter+',B.DocDate))) DocDate'
		else
			set @DocDateCol='CONVERT(DATETIME,max(B.'+@DateFilter+')) DocDate'
			
		set @str='	SELECT A.AccountID,' + @strCols +@DocDateCol +',CONVERT(DATETIME,max(B.DueDate)) DueDate,CONVERT(DATETIME,max(B.DocDate)) VoucherDate,B.VoucherNo DocNo,
		sum(' + @AmtColumn + ') Amount,sum(' + @AmtColumn + ') BillAmount'
		if (@IsBillNoExists=1)
			set @str=@str+',(SELECT TOP 1 BillNo FROM INV_DocDetails WITH(NOLOCK) WHERE B.VoucherNo=VoucherNo) BillNo'
		if (@IsBillDateExists=1)
			set @str=@str+',(SELECT TOP 1 CONVERT(DATETIME, BillDate) FROM INV_DocDetails WITH(NOLOCK) WHERE B.VoucherNo=VoucherNo) BillDate'
		set @str=@str+',C50002.Name AS Location'+REPLACE(@SELECTQUERY,'B.DocNo','B.VoucherNo')+',(max(B.DueDate)-max(B.DocDate)) CreditDays,@To-max(B.'+@DateFilter+') OverDue
		,DocumentType DocType,B.StatusID'
						if (@PDCSeperate=1)
						   set @str=@str+',case when DocumentType=14 or DocumentType=19 then 1 else 0 end IsPDC'
	                    
		set @str=@str+' 
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.'+@MainAccount+'=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.XXXDocDetailsIDXXX=B.XXXDocDetailsIDXXX
		INNER JOIN COM_Location AS C50002 with(nolock) ON DCC.dcCCNID2 = C50002.NodeID'+@FROMQUERY

		set @str=@str+' '+@GTPQRY
	                    
		set @str=@str+@Where
	   
		--AdjAmount,Paid
		set @str=@str+'
		GROUP BY A.AccountID,A.AccountName,'+@strGroups+'VoucherNo,C50002.Name,DocumentType,B.StatusID'
		if(@FROMQUERY like '%ADM_DocumentTypes%')
			set @str=@str+',DType.IsInventory'

		--create table #tblAdj(ID int identity(1,1),AccountID INT,Amount float)
		--create table #tblLOB(x int identity(1,1))

		set @SQL='DECLARE @To float
		set @To='+convert(nvarchar,@To)+'
		create table #tblAdj(ID int identity(1,1),AccountID INT,Amount float'
		if(@TagID>0)
			set @SQL=@SQL+',TAG INT'
		set @SQL=@SQL++')
		
		select ID=Identity(int,1,1),*,1 Show  into #tblLOB from (
		'
		set @SQL=@SQL+Replace(@str,'XXXDocDetailsIDXXX','AccDocDetailsID')
		set @SQL=@SQL+'
		UNION ALL
		'
		set @SQL=@SQL+Replace(@str,'XXXDocDetailsIDXXX','InvDocDetailsID')

		set @SQL=@SQL+') as T
		ORDER BY AccountID,'+@TagColID+'DocDate,DocNo

		alter table #tblLOB add Adjusted float

		insert into #tblAdj
		select Account,Amount'+@TagDbCol+' from (
		SELECT '+@AdjAccount+' Account,sum(Amount) Amount'+@TagDbCol+'
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.'+@AdjAccount+'=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=B.AccDocDetailsID'+@GTPQRY+@Where+'
		GROUP BY '+@AdjAccount+@TagDbCol+'
		UNION ALL
		SELECT '+@AdjAccount+' Account,sum(Amount) Amount'+@TagDbCol+'
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.'+@AdjAccount+'=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=B.InvDocDetailsID'+@GTPQRY+@Where+'
		GROUP BY '+@AdjAccount+@TagDbCol+'
		) as t
		GROUP BY Account,Amount'+@TagDbCol+'

		--select * from #tblAdj'
	end
	else if(@ReportType=11)
	begin
		set @Var3='Paid'

		if(@DateFilter='DueDate')
			set @DocDateCol='CONVERT(DATETIME,isnull(max(B.DueDate),B.DocDate))'
		else
			set @DocDateCol='CONVERT(DATETIME,B.DocDate)'


		set @str='	SELECT A.AccountID,' + @strCols + @DocDateCol+ ' DocDate,CONVERT(DATETIME,max(B.DueDate)) DueDate,CONVERT(DATETIME,max(B.DocDate)) VoucherDate,B.VoucherNo,
		sum(' + @AmtColumn + ') AdjAmount,sum(' + @AmtColumn + ') BillAmount'
		if (@IsBillNoExists=1)
			set @str=@str+',(SELECT TOP 1 BillNo FROM INV_DocDetails WITH(NOLOCK) WHERE B.VoucherNo=VoucherNo) BillNo'
		if (@IsBillDateExists=1)
			set @str=@str+',(SELECT TOP 1 CONVERT(DATETIME, BillDate) FROM INV_DocDetails WITH(NOLOCK) WHERE B.VoucherNo=VoucherNo) BillDate'		
		set @str=@str+',C50002.Name AS Location'+REPLACE(@SELECTQUERY,'B.DocNo','B.VoucherNo')+',(max(B.DueDate)-max(B.DocDate)) CreditDays,@To-max(B.'+@DateFilter+') OverDue
		,DocumentType DocType,B.StatusID'
		if (@PDCSeperate=1)
			set @str=@str+',case when DocumentType=14 or DocumentType=19 then 1 else 0 end IsPDC'
		set @str=@str+' 
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.XXXMainAccountXXXX=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.XXXDocDetailsIDXXX=B.XXXDocDetailsIDXXX
		INNER JOIN COM_Location AS C50002 with(nolock) ON DCC.dcCCNID2 = C50002.NodeID'+@FROMQUERY
		set @str=@str+' '+@GTPQRY
		set @str=@str+@Where
		
	   
		--AdjAmount,Paid
		set @str=@str+'
		GROUP BY A.AccountID,A.AccountName,DocDate,VoucherNo,C50002.Name,DocumentType,B.StatusID'
		if(@FROMQUERY like '%ADM_DocumentTypes%')
			set @str=@str+',DType.IsInventory'
			
		set @StrTemp=@str
		
		set @str=Replace(@StrTemp,'XXXMainAccountXXXX','DebitAccount')
		set @str=@str+' 
		UNION ALL 
		'
		set @StrTemp=Replace(@StrTemp,'XXXMainAccountXXXX','CreditAccount')
		set @StrTemp=replace(@StrTemp,'sum(' + @AmtColumn + ')','-sum(' + @AmtColumn + ')')

		set @str=@str+@StrTemp
		
		--	print( @str)
		--create table #tblAdj(ID int identity(1,1),AccountID INT,Amount float)
		--create table #tblLOB(x int identity(1,1))
		--select @strCols
		set @strCols='AccountName,AccountName_ID,'

		set @SQL='DECLARE @To float
		set @To='+convert(nvarchar,@To)+'
		create table #tblAdj(ID int identity(1,1),AccountID INT,Amount float'
		if(@TagID>0)
			set @SQL=@SQL+',DCC.dcCCNID'+(convert(nvarchar,@TagID-50000))
		set @SQL=@SQL+')
		
		select ID=Identity(int,1,1),*,1 Show  into #tblLOB from (
		SELECT AccountID,'+@strCols+'DocDate,DueDate,VoucherDate,VoucherNo,abs(sum(AdjAmount)) AdjAmount,abs(sum(BillAmount)) BillAmount'
		if (@IsBillNoExists=1)
			set @SQL=@SQL+',max(BillNo) BillNo'
		if (@IsBillDateExists=1)
			set @SQL=@SQL+',max(BillDate) BillDate'		

		set @SQL=@SQL+',Location'+@SelectTagAliasOnly+',max(CreditDays) CreditDays,@To-max(OverDue) OverDue
		,DocType,StatusID

		 FROM (
		'
		set @SQL=@SQL+Replace(@str,'XXXDocDetailsIDXXX','AccDocDetailsID')
		set @SQL=@SQL+'
		UNION ALL
		'
		set @SQL=@SQL+Replace(@str,'XXXDocDetailsIDXXX','InvDocDetailsID')
		set @SQL=@SQL+') as VT
		'
		set @SQL=@SQL+'
		GROUP BY AccountID,AccountName,AccountName_ID,DocDate,VoucherDate,DueDate,VoucherNo,Location,DocType,StatusID'
		if(@FROMQUERY like '%ADM_DocumentTypes%')
			set @SQL=@SQL+',IsInventory'
		set @SQL=@SQL+@SelectTagAliasOnly
		
		if @IsReceivable=0
			set @SQL=@SQL+' HAVING sum(AdjAmount)<0'	
		else
			set @SQL=@SQL+' HAVING sum(AdjAmount)>0'	
		
		set @SQL=@SQL+') as T
		ORDER BY AccountID,DocDate,VoucherNo
		'

		set @SQL=@SQL+'
		--select * from #tblLOB
		alter table #tblLOB add Paid float default(0) not null

		insert into #tblAdj
		select Account,abs(sum(Amount)) Amount from (
		select Account,VoucherNo,sum(Amount) Amount from (
		SELECT B.DebitAccount Account,B.VoucherNo,Amount
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.DebitAccount=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=B.AccDocDetailsID'+@GTPQRY+@Where+'
		UNION ALL
		SELECT B.CreditAccount Account,B.VoucherNo,-Amount
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.CreditAccount=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=B.AccDocDetailsID'+@GTPQRY+@Where+'
		UNION ALL
		SELECT B.DebitAccount Account,B.VoucherNo,Amount
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.DebitAccount=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=B.InvDocDetailsID'+@GTPQRY+@Where+'
		UNION ALL
		SELECT B.CreditAccount Account,B.VoucherNo,-Amount
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.CreditAccount=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=B.InvDocDetailsID'+@GTPQRY+@Where+'
		) as t
		group by Account,VoucherNo'
		if @IsReceivable=0
			set @SQL=@SQL+' HAVING sum(Amount)>0'	
		else
			set @SQL=@SQL+' HAVING sum(Amount)<0'	
		set @SQL=@SQL+') as t
		group by Account'
		
	end
	else if(@ReportType=12)
	begin
		declare @TempGTPQRY nvarchar(max)
		set @TempGTPQRY=@GTPQRY
		if len(@GTPQRY)>0
		begin
			set @GTPQRY=',#tblAcc GTP'
		end

		set @Var1='AdjAmount'
		set @Var3='AdjAmount'
		if(@DateFilter='DueDate')
			set @DocDateCol='CONVERT(DATETIME,isnull(max(B.DueDate),B.DocDate))'
		else
			set @DocDateCol='CONVERT(DATETIME,B.DocDate)'

		set @str='SELECT A.AccountID,VoucherNo,' + @strCols + @DocDateCol+ ' DocDate,sum(' + @AmtColumn + ') AdjAmount'
		if (@PDCSeperate=1)
			set @str=@str+',case when DocumentType=14 or DocumentType=19 then 1 else 0 end IsPDC'
		set @str=@str+' 
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.XXXMainAccountXXXX=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.XXXDocDetailsIDXXX=B.XXXDocDetailsIDXXX'
		set @str=@str+' '+@GTPQRY
		set @str=@str+@Where
	   
		--AdjAmount,Paid
		set @str=@str+'
		GROUP BY A.AccountID,A.AccountName,VoucherNo,DocDate,DocumentType,B.StatusID'
		if(@FROMQUERY like '%ADM_DocumentTypes%')
			set @str=@str+',DType.IsInventory'
			
		set @StrTemp=@str
		
		set @str=Replace(@StrTemp,'XXXMainAccountXXXX','DebitAccount')
		set @str=@str+' 
		UNION ALL 
		'
		set @StrTemp=Replace(@StrTemp,'XXXMainAccountXXXX','CreditAccount')
		set @StrTemp=replace(@StrTemp,'sum(' + @AmtColumn + ')','-sum(' + @AmtColumn + ')')

		set @str=@str+@StrTemp

		--create table #tblAdj(ID int identity(1,1),AccountID INT,Amount float)
		--create table #tblLOB(x int identity(1,1))

		set @SQL='DECLARE @To float,@AccountingDate float'

		if len(@GTPQRY)>0
		begin
			set @SQL=@SQL+' 
			create table #tblAcc(GTID INT Primary Key)
			insert into #tblAcc
			'+ substring(@TempGTPQRY, 3, len(@TempGTPQRY)-10)
		end

		set @SQL=@SQL+'
		create table #tblAdj(ID int identity(1,1),AccountID INT,Amount float'
		if(@TagID>0)
			set @SQL=@SQL+',dcCCNID'+(convert(nvarchar,@TagID-50000))
		set @SQL=@SQL+')
		create table #tblLOB(ID int identity(1,1) primary key,AccountID INT'
		if(@TagID>0)
			set @SQL=@SQL+',dcCCNID'+(convert(nvarchar,@TagID-50000))
		set @SQL=@SQL+', DocDate datetime,AdjAmount float,Show bit)

		set @To='+convert(nvarchar,@To)+'
		set @AccountingDate='+convert(nvarchar,convert(float,@AccountingDate))+'
		'

		if(@IsBillNoExists=1)
		begin
			set @SQL=@SQL+'SELECT A.AccountID,A.AccountName,A.lft,A.rgt,A.IsGroup,A.Depth' + @SalesDocs + @SELECTQUERY + ' FROM ACC_Accounts A with(nolock)'+@FROMQUERY
			set @SQL=@SQL+@GTPQRY
			set @SQL=@SQL+' WHERE A.Depth>0'
			if(len(@GTPWHERE)>0)
				set @SQL=@SQL+' AND A.' + @GTPWHERE
			--@strColsstr: AccountTypeFilter
			if (@AccountTypeFilter!='')
			   set @SQL=@SQL+@AccountTypeFilter
			set @SQL=@SQL+' ORDER BY A.lft'
		end
		else
		begin
			set @SQL=@SQL+'SELECT A.AccountID,A.AccountName' + @SalesDocs + @SELECTQUERY + ' FROM ACC_Accounts A with(nolock)'+@FROMQUERY
			set @SQL=@SQL+@GTPQRY
			set @SQL=@SQL+' WHERE A.Depth>0'
			if(len(@GTPWHERE)>0)
				set @SQL=@SQL+' AND A.' + @GTPWHERE
			--@strColsstr: AccountTypeFilter
			if (@AccountTypeFilter!='')
			   set @SQL=@SQL+@AccountTypeFilter
			set @SQL=@SQL+' ORDER BY A.AccountName'        
		end
	                    
		set @FSQL=@FSQL+'
		insert into #tblLOB
		select *,1 Show  from (
		SELECT AccountID,' + @strCols + ' DocDate,sum(AdjAmount) AdjAmount 
		FROM (
		'
		set @FSQL=@FSQL+Replace(@str,'XXXDocDetailsIDXXX','AccDocDetailsID')
		set @FSQL=@FSQL+'
		UNION ALL
		'
		set @FSQL=@FSQL+Replace(@str,'XXXDocDetailsIDXXX','InvDocDetailsID')
		set @FSQL=@FSQL+'
		) AS T
		GROUP BY AccountID,VoucherNo,DocDate
		'
		if @IsReceivable=0
			set @FSQL=@FSQL+' HAVING sum(AdjAmount)<0'	
		else
			set @FSQL=@FSQL+' HAVING sum(AdjAmount)>0'	
		
		set @FSQL=@FSQL+' 
		) as T
		ORDER BY AccountID,DocDate

		insert into #tblAdj
		select Account,abs(sum(Amount)) Amount from (
		select Account,VoucherNo,sum(Amount) Amount from (
		SELECT B.DebitAccount Account,B.VoucherNo,Amount
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.DebitAccount=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=B.AccDocDetailsID'+@GTPQRY+@Where+'
		UNION ALL
		SELECT B.CreditAccount Account,B.VoucherNo,-Amount
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.CreditAccount=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.AccDocDetailsID=B.AccDocDetailsID'+@GTPQRY+@Where+'
		UNION ALL
		SELECT B.DebitAccount Account,B.VoucherNo,Amount
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.DebitAccount=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=B.InvDocDetailsID'+@GTPQRY+@Where+'
		UNION ALL
		SELECT B.CreditAccount Account,B.VoucherNo,-Amount
		FROM Acc_DocDetails B with(nolock) 
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON B.CreditAccount=A.AccountID     
		INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=B.InvDocDetailsID'+@GTPQRY+@Where+'
		) as t
		group by Account,VoucherNo'
		if @IsReceivable=0
			set @FSQL=@FSQL+' HAVING sum(Amount)>0'	
		else
			set @FSQL=@FSQL+' HAVING sum(Amount)<0'	
		set @FSQL=@FSQL+') as t
		group by Account
		'
		if @IsReceivable=0
			set @FSQL=@FSQL+'update #tblLOB set AdjAmount=abs(AdjAmount)
		'
		--DONT MODIFY
		set @FSQL=@FSQL+'select AccountID,sum(Amount) Amount,sum(UnAdjustedAmount) UnAdjustedAmount from (
		select AccountID,sum(AdjAmount) Amount,0 UnAdjustedAmount from #tblLOB with(nolock) group by AccountID
		union all
		select AccountID,0,-sum(Amount) UnAdjustedAmount from #tblAdj with(nolock) group by AccountID) as T group by AccountID'
		
		--DONT MODIFY
		SET @TEMPSQL='select AccountID,sum(Amount) Amount,sum(UnAdjustedAmount) UnAdjustedAmount from (
		select AccountID,sum(AdjAmount) Amount,0 UnAdjustedAmount from #tblLOB with(nolock) group by AccountID
		union all
		select AccountID,0,-sum(Amount) UnAdjustedAmount from #tblAdj with(nolock) group by AccountID) as T group by AccountID
	declare @i int,@Cnt int,@AccountID INT,@Amount float,@ID int,@PrevAccID INT,@Bal float,@TAG int,@PrevTAG INT'
	end

	--DONT MODIFY
	set @FSQL=@FSQL+'
	declare @i int,@Cnt int,@AccountID INT,@Amount float,@ID int,@PrevAccID INT,@Bal float,@TAG int,@PrevTAG INT
	select @PrevAccID=0,@i=1,@Cnt=count(*) from #tblLOB with(nolock)
	while(@i<=@Cnt)
	begin'
	if(@TagID>0)
	begin
		set @FSQL=@FSQL+'
		select @AccountID=AccountID,@TAG='+@TagColID+'@Amount='+@Var1+' from #tblLOB with(nolock) where ID=@i
		if(@PrevAccID!=@AccountID or @TAG!=@PrevTAG)
		begin
			set @Bal=0
			set @PrevAccID=@AccountID
			set @PrevTAG=@TAG
			select @Bal='+@Var2+' from #tblAdj with(nolock) where AccountID=@AccountID and TAG=@TAG
		end
		'
	end
	else
	begin
		set @FSQL=@FSQL+'
		select @AccountID=AccountID,@Amount='+@Var1+' from #tblLOB with(nolock) where ID=@i
		if(@PrevAccID!=@AccountID)
		begin
			set @Bal=0
			set @PrevAccID=@AccountID
			select @Bal='+@Var2+' from #tblAdj with(nolock) where AccountID=@AccountID
		end
		'
	end

	if @ReportType=10 or @ReportType=11
	begin
		set @FSQL=@FSQL+'
		if(@Bal>0)
		begin	
			if(@Amount>@Bal)
			begin
				update #tblLOB set '+@Var3+'=-@Bal where ID=@i
				set @Bal=0
			end
			else
			begin
				update #tblLOB set '+@Var3+'=-@Amount where ID=@i	
				update #tblLOB set Show=0 where ID=@i
				set @Bal=@Bal-@Amount
			end	
		end'
	end
	else
	begin
		set @FSQL=@FSQL+'
		if(@Bal>0)
		begin	
			if(@Amount>@Bal)
			begin
				update #tblLOB set '+@Var3+'=@Amount-@Bal where ID=@i
				set @Bal=0
			end
			else
			begin
				update #tblLOB set Show=0 where ID=@i
				set @Bal=@Bal-@Amount
			end	
		end'
	end

	set @FSQL=@FSQL+'
		set @i=@i+1
	end
	select * from #tblLOB with(nolock) where Show=1
	'
	
	set @SQL=@SQL+@FSQL
	
	IF (@FutureSlabs=1)
	BEGIN
	
		set @SQL=@SQL+'
		TRUNCATE table #tblLOB
		TRUNCATE table #tblAdj'
		
		set @SQL=@SQL+REPLACE(REPLACE(@FSQL,@TEMPSQL,''),'<=@To','>@To')
	
	END
	
	set @SQL=@SQL+'
	drop table #tblLOB
	drop table #tblAdj
	'
            
	print(substring(@SQL,1,4000))
	if(len(@SQL)>4000)
		print(substring(@SQL,4001,len(@SQL)-4000))
		
	exec sp_executesql @SQL

-- select len(@SQL)

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
