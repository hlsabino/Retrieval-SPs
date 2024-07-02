USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_AdjustCreditBills]
	@accids [nvarchar](max),
	@frmdate [datetime],
	@todate [datetime],
	@locID [int],
	@DivID [int],
	@DimensionID [int],
	@where [nvarchar](max),
	@BasedOnDimensions [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
SET NOCOUNT ON
BEGIN TRY 

declare @Amount float,@DebitAccount INT,@CreditAccount INT,@DocDate float,@duedate float,@DocSeqNo INT,@VoucherNo nvarchar(500)
declare @i int,@cnt int,@docdetalid INT,@ii int,@ccnt int,@AdjAmt float,@sql nvarchar(max),@invID INT,@status int,@refstatus int,@DDate float
declare @li int,@lcnt int,@Locationid INT,@prefValue nvarchar(50),@RefSeqNo int,@billno nvarchar(200),@billdate float,@RefNid INT
declare @tabTrans table(id INT identity(1,1),AccDocDetailsID INT,docd float)
declare @tabbill table(id INT identity(1,1),docno nvarchar(50),SeqNo int,amount float,docdate float,duedate float,statusid int)
declare @Di int,@Dcnt int,@Divisionid INT,@Divpref nvarchar(50),@CurrID INT,@ExchRt Float,@ExchRtBC Float,@amtfc float,@DimCurrencyID INT
declare @Dimi int,@Dimcnt int,@Dimid INT,@DimCCID INT,@DimTable nvarchar(50),@dec int,@DimCurrTable nvarchar(max),@DimExchCCID int,@DocCC nvarchar(max)
declare @tabDim table(id INT identity(1,1),Dimid INT)

--Start : Based On dimensions
declare @k int,@kcnt int,@Dimdtls nvarchar(max),@BasedOnDimsql nvarchar(max),@CCID int ,@NODEID int
set @BasedOnDimsql=''
CREATE TABLE #tabDimensionValues (ID INT IDENTITY(1,1),DimID int)
declare @tabDIMLIST table(ID INT IDENTITY(1,1),Dimdtls NVARCHAR(MAX))
INSERT INTO @tabDIMLIST(Dimdtls)
	exec SPSplitString @BasedOnDimensions,'~'
SET @k=1
SELECT @kcnt=COUNT(*) FROM @tabDIMLIST
WHILE(@k<=@kcnt)
BEGIN	
	SELECT @Dimdtls=Dimdtls FROM @tabDIMLIST WHERE ID=@k
		TRUNCATE TABLE #tabDimensionValues
		INSERT INTO #tabDimensionValues(DimID)
				EXEC SPSplitString @Dimdtls,','	
		SELECT @CCID=DimID-50000 FROM #tabDimensionValues WHERE ID=1
		SELECT @NODEID=DimID FROM #tabDimensionValues WHERE ID=2
		set @BasedOnDimsql=@BasedOnDimsql+'  and dcCCNID'+convert(nvarchar,@CCID)+'='+convert(nvarchar,@NODEID)
SET @k=@k+1
END
Print @BasedOnDimsql
--End : Based On dimensions



set @DocCC=''
select @DocCC =@DocCC +','+a.name from sys.columns a
join sys.tables b on a.object_id=b.object_id
where b.name='COM_DocCCData' and a.name like 'dcCCNID%'

SELECT @dec=isnull(Value,2) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DecimalsinAmount' and ISNUMERIC(Value)=1

set @DimExchCCID=0
select @DimExchCCID=value from adm_globalpreferences WITH(NOLOCK)
where name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000

set @DimCurrTable=''	
if(@DimExchCCID is not null and @DimExchCCID>0)
BEGIN
	select @DimCurrTable=TableName from ADM_Features WITH(NOLOCK)
	where FeatureID=@DimExchCCID
END

set @prefValue=''
select @prefValue=value from adm_globalpreferences WITH(NOLOCK)
where name='EnableLocationWise'
if(@prefValue='true')
begin
	set @prefValue=''
	select @prefValue=value from adm_globalpreferences WITH(NOLOCK)
	where name='LW Bills'
end
if(@prefValue='true' and @locID=0)
begin
	select @lcnt=count(NodeID) from COM_Location WITH(NOLOCK)	
	Where IsGroup=0
end
else
begin
	set @lcnt=1
end



set @DimCCID=0
select @DimCCID=value from adm_globalpreferences WITH(NOLOCK)
where name='Maintain Dimensionwise Bills' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000

if(@DimCCID>0 and @DimensionID=0)
begin
		select @DimTable=TableName from ADM_Features WITH(NOLOCK)
	where FeatureID=@DimCCID
	set @DimCCID=@DimCCID-50000
	
	set @sql='select b.Dcccnid'+convert(nvarchar,@DimCCID)+' from acc_docdetails a WITH(NOLOCK)
		join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
		where (CreditAccount  in('+@accids+') or DebitAccount  in('+@accids+')) and docdate>='+convert(nvarchar,convert(float,@frmdate))+
		' and docdate<='+convert(nvarchar,convert(float,@todate))
		set @sql=@sql+@where	
		set @sql=@sql+' and ((DocumentType not in (14,19) and StatusID not in(377,376,447,448,449)) or (DocumentType in (14,19) and statusid=370))		
		union
		select b.Dcccnid'+convert(nvarchar,@DimCCID)+' from acc_docdetails a WITH(NOLOCK)
		join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
		where (CreditAccount  in('+@accids+') or DebitAccount  in('+@accids+')) and docdate>='+convert(nvarchar,convert(float,@frmdate))+
		' and docdate<='+convert(nvarchar,convert(float,@todate))
		set @sql=@sql+@where	
		set @sql=@sql+' and ((DocumentType not in (14,19) and StatusID not in(377,376,447,448,449)) or (DocumentType in (14,19) and statusid=370))		'
	print @sql
	insert into @tabDim
	exec (@sql)
	
	select @Dimcnt=count(Dimid) from @tabDim
end
else
begin
	set @Dimcnt=1
	set @DimCCID=@DimCCID-50000
end


set @Divpref=''
select @Divpref=value from adm_globalpreferences WITH(NOLOCK)
where name='EnableDivisionWise'
if(@Divpref='true')
begin
	set @Divpref=''
	select @Divpref=value from adm_globalpreferences WITH(NOLOCK)
	where name='DW Bills'
end
if(@Divpref='true' and @DivID=0)
begin
	select @Dcnt=count(NodeID) from COM_Division WITH(NOLOCK)	
	Where IsGroup=0
end
else
begin
	set @Dcnt=1
end

set @sql='Delete b from [COM_Billwise] b  WITH(NOLOCK)   
where AccountID in('+@accids+') and docdate>='+convert(nvarchar,convert(float,@frmdate))+
' and docdate<='+convert(nvarchar,convert(float,@todate))

if(@prefValue='true' and @locID>0)
	set @sql=@sql+'  and dcCCNID2='+convert(nvarchar,@locID)

if(@Divpref='true' and @DivID>0)
	set @sql=@sql+'  and dcCCNID1='+convert(nvarchar,@DivID)

if(@DimCCID>0 and @DimensionID>0)
	set @sql=@sql+'  and dcCCNID'+convert(nvarchar,@DimCCID)+'='+convert(nvarchar,@DimensionID)
	
if(isnull(@BasedOnDimsql,'')<>'')
	set @sql=@sql+@BasedOnDimsql
	
set @sql=@sql+@where	
print @sql
exec(@sql)

	
set @Locationid=0
set @li=0 
while(@li<@lcnt)
begin
      set @li=@li+1 
     if(@prefValue='true')
	begin
		if(@locID>0)
			set @Locationid=@locID
		ELSE	
			 select top 1  @Locationid=NodeID from COM_Location WITH(NOLOCK)
			 where NodeID>@Locationid and IsGroup=0
			order by NodeID 
     end
     
    if(@DimExchCCID=50002)	
		select @DimCurrencyID=CurrencyID from COM_Location WITH(NOLOCK)
		where NodeID=@Locationid
	
		
    set @Divisionid=0
	set @Di=0 
	while(@Di<@Dcnt)
	begin
		  set @Di=@Di+1 
		if(@Divpref='true')
		begin
			if(@DivID>0)
				set @Divisionid=@DivID
			ELSE
				 select top 1  @Divisionid=NodeID from COM_Division WITH(NOLOCK)
				 where NodeID>@Divisionid and IsGroup=0
				order by NodeID 
		end
		
		if(@DimExchCCID=50001)	
			select @DimCurrencyID=CurrencyID from COM_Division WITH(NOLOCK)
			where NodeID=@Divisionid

		
		set @Dimid=0
		set @Dimi=0 
		while(@Dimi<@Dimcnt)
		begin
			  set @Dimi=@Dimi+1 
			if(@DimCCID>0)
			begin
				if(@DimensionID>0)
					set @Dimid=@DimensionID
				ELSE	
					select @Dimid=Dimid from @tabDim where id=@Dimi
			end
			
			if(@DimExchCCID=@DimCCID)	
			BEGIN
				set @sql='select @DimCurrencyID=CurrencyID from '+@DimCurrTable+' WITH(NOLOCK)
				where NodeID='+convert(nvarchar,@Dimid)

				exec sp_executesql @sql,N'@DimCurrencyID INT OUTPUT',@DimCurrencyID output
			END
		
       
			 
				set @sql='select a.AccDocDetailsID,DocDate from acc_docdetails a WITH(NOLOCK)
				join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
				where CreditAccount  in('+@accids+') and (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0) and docdate>='+convert(nvarchar,convert(float,@frmdate))+
				' and docdate<='+convert(nvarchar,convert(float,@todate))
				
				if(@Locationid>0)
					set @sql=@sql+'  and dcCCNID2='+convert(nvarchar,@Locationid)
				
				if(@Divisionid>0)
					set @sql=@sql+'  and dcCCNID1='+convert(nvarchar,@Divisionid)

				if(@Dimid>0)
					set @sql=@sql+'  and dcCCNID'+convert(nvarchar,@DimCCID)+'='+convert(nvarchar,@Dimid)
					
				if(isnull(@BasedOnDimsql,'')<>'')
					set @sql=@sql+@BasedOnDimsql	
				
				set @sql=@sql+' and ((DocumentType not in (14,19) and StatusID not in(377,376,447,448,449)) or (DocumentType in (14,19) and statusid=370))
				union all
				select a.AccDocDetailsID,DocDate from acc_docdetails a WITH(NOLOCK)
				join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
				where CreditAccount  in('+@accids+') and docdate>='+convert(nvarchar,convert(float,@frmdate))+
				' and docdate<='+convert(nvarchar,convert(float,@todate))
				
				if(@Locationid>0)
					set @sql=@sql+'  and dcCCNID2='+convert(nvarchar,@Locationid)
				
				if(@Divisionid>0)
					set @sql=@sql+'  and dcCCNID1='+convert(nvarchar,@Divisionid)

				if(@Dimid>0)
					set @sql=@sql+'  and dcCCNID'+convert(nvarchar,@DimCCID)+'='+convert(nvarchar,@Dimid)
				
				if(isnull(@BasedOnDimsql,'')<>'')
					set @sql=@sql+@BasedOnDimsql	
					
				set @sql=@sql+@where
				set @sql=@sql+' and ((DocumentType not in (14,19) and StatusID not in(377,376,447,448,449)) or (DocumentType in (14,19) and statusid=370))
				order by DocDate'
			 
			 

	print @sql

delete from @tabTrans	
insert into @tabTrans
exec(@sql)

select @cnt=max(id),@i=min(id) from @tabTrans

set @i=@i-1
set @docdetalid=0
while(@i<@cnt)
begin
      set @i=@i+1 
      select @docdetalid=AccDocDetailsID from @tabTrans
      where id=@i
      
       set @invID=0
      select @CreditAccount=CreditAccount,@VoucherNo=VoucherNo,@invID=InvDocDetailsID,@DocSeqNo=DocSeqNo,@status=StatusID from acc_docdetails WITH(NOLOCK)
      where AccDocDetailsID=@docdetalid
       
      if exists(select accountid from ACC_Accounts WITH(NOLOCK) where AccountID=@CreditAccount and IsBillwise=1)
      begin
			if((@invID is null or @invID=0) and not exists(select BillwiseID from com_billwise WITH(NOLOCK) where AccountID=@CreditAccount and [DocNo]=@VoucherNo and DocSeqNo=@DocSeqNo))
            begin
				   if(@DimExchCCID>50000)
				   BEGIN	
						set @sql='select @ExchRtBC=ExhgRtBC from ACC_DocDetails WITH(NOLOCK)
						where AccDocDetailsID='+convert(nvarchar,@docdetalid)
						exec sp_executesql @sql,N'@ExchRtBC float OUTPUT',@ExchRtBC output
					END	
						
				  if exists(select CurrencyID from acc_docdetails WITH(NOLOCK)
				  where (DebitAccount=@CreditAccount or CreditAccount=@CreditAccount) and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
				  group by CurrencyID
				  having COUNT(distinct CurrencyID)>1)
				  BEGIN
					  select @Amount=isnull(SUM(amount),0) from acc_docdetails WITH(NOLOCK)
					  where CreditAccount=@CreditAccount and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
	              
					  select @Amount =@Amount-isnull(SUM(amount),0) from acc_docdetails WITH(NOLOCK)
					  where DebitAccount=@CreditAccount and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
					  
					  if(@DimExchCCID>50000)
						set @CurrID=@DimCurrencyID
					  ELSE	
						set @CurrID=1
						
					  set @ExchRt=1
					  set @amtfc=@Amount
				  END
				  ELSE
				  BEGIN
					  select @Amount=isnull(SUM(amount),0),@amtfc=isnull(SUM(AmountFC),0),@CurrID=max(CurrencyID),@ExchRt=max(ExchangeRate) from acc_docdetails WITH(NOLOCK)
					  where CreditAccount=@CreditAccount and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
	              
					  select @Amount =@Amount-isnull(SUM(amount),0),@amtfc=@amtfc-isnull(SUM(AmountFC),0) from acc_docdetails WITH(NOLOCK)
					  where DebitAccount=@CreditAccount and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)					  
				  END
				  
            

                  set @sql='INSERT INTO [COM_Billwise]    
                     ([DocNo]    
                     ,[DocDate]    
                      ,[DocDueDate]    
                     ,[DocSeqNo]    
                     ,[AccountID]    
                     ,[AdjAmount] ,amountfc  ,StatusID  
                     ,[AdjCurrID]    
                     ,[AdjExchRT]    
                     ,[DocType]    
                     ,[IsNewReference]    
                     ,[RefDocNo]    
                     ,[RefDocSeqNo]    
                     ,[RefDocDate]    
                     ,[RefDocDueDate]    
                     ,[Narration]    
                     ,[IsDocPDC]'+@DocCC+')    
                   select VoucherNo    
                   , DocDate    
                   , DueDate    
                     , DocSeqNo    
                     , '+convert(nvarchar(max),@CreditAccount)+'
                     , -@Amount , -@amtfc ,'+convert(nvarchar(max),@status)+'  
                     , '+convert(nvarchar(max),@CurrID)+'
                     , '+convert(nvarchar(max),@ExchRt)+'
                     , DocumentType    
                     , 1    
                     , NULL    
                     ,NULL    
                   , NULL    
                   ,NULL    
                     , ''''    
                     , 0    '+@DocCC+'   from acc_docdetails a WITH(NOLOCK)
                  join [COM_DocCCData] d WITH(NOLOCK) on a.AccDocDetailsID=d.AccDocDetailsID 
                  where a.AccDocDetailsID='+convert(nvarchar(max),@docdetalid)
                  EXEC sp_executesql @sql,N'@Amount Float,@ExchRt float,@amtfc float',@Amount,@ExchRt,@amtfc
                  
                  if(@DimExchCCID>50000)
				  BEGIN	
						set @sql='update COM_Billwise 
						set AmountBC=round(AdjAmount/'+convert(nvarchar,@ExchRtBC)+','+convert(nvarchar,@dec)+'),ExhgRtBC='+convert(nvarchar,@ExchRtBC)+'
						where DocNo='''+@VoucherNo+''' and [DocSeqNo]='+convert(nvarchar,@DocSeqNo)
						exec(@sql)
				  END	
   
                
            end
            else if(@invID>0 and ((@Locationid>0 and not exists(select BillwiseID from com_billwise WITH(NOLOCK) where AccountID=@CreditAccount and [DocNo]=@VoucherNo and dcCCNID2=@Locationid))
             or (@Locationid=0 and not exists(select BillwiseID from com_billwise WITH(NOLOCK) where AccountID=@CreditAccount and [DocNo]=@VoucherNo))))
            begin
				   if(@DimExchCCID>50000)
				   BEGIN	
						set @sql='select @ExchRtBC=ExhgRtBC from ACC_DocDetails WITH(NOLOCK)
						where AccDocDetailsID='+convert(nvarchar,@docdetalid)
						exec sp_executesql @sql,N'@ExchRtBC float OUTPUT',@ExchRtBC output
					END	

				 if exists(select CurrencyID from acc_docdetails WITH(NOLOCK)
				  where (DebitAccount=@CreditAccount or CreditAccount=@CreditAccount) and VoucherNo=@VoucherNo
				  group by CurrencyID
				  having COUNT(distinct CurrencyID)>1)
				  BEGIN
					  select @Amount=isnull(SUM(amount),0) from acc_docdetails WITH(NOLOCK)
					  where CreditAccount=@CreditAccount and VoucherNo=@VoucherNo
	              
					   select @Amount =@Amount-isnull(SUM(amount),0) from acc_docdetails WITH(NOLOCK)
					   where DebitAccount=@CreditAccount and VoucherNo=@VoucherNo
						set @amtfc=@Amount  
					  if(@DimExchCCID>50000)
						set @CurrID=@DimCurrencyID
					  ELSE	
						set @CurrID=1
						set @ExchRt=1
				   END
				   ELSE
				   BEGIN
					  select @Amount=isnull(SUM(amount),0),@amtfc=isnull(SUM(AmountFC),0),@CurrID=MAX(CurrencyID),@ExchRt=MAX(ExchangeRate) from acc_docdetails WITH(NOLOCK)
					  where CreditAccount=@CreditAccount and VoucherNo=@VoucherNo
	              
					   select @Amount =@Amount-isnull(SUM(amount),0),@amtfc=@amtfc-isnull(SUM(AmountFC),0) from acc_docdetails WITH(NOLOCK)
					   where DebitAccount=@CreditAccount and VoucherNo=@VoucherNo
						
				   END
                
                  if(@Amount<0)
							continue;
							
              select @billno=BillNo,@billdate=BillDate from INV_DocDetails WITH(NOLOCK)
              where InvDocDetailsID=@invID
     
                  set @sql='INSERT INTO [COM_Billwise]    
                     ([DocNo]    
                     ,[DocDate]    
                      ,[DocDueDate]    
                     ,[DocSeqNo]    
                     ,[AccountID]    
                     ,[AdjAmount] ,amountfc ,StatusID,BillNo,BillDate  
                     ,[AdjCurrID]    
                     ,[AdjExchRT]    
                     ,[DocType]    
                     ,[IsNewReference]    
                     ,[RefDocNo]    
                     ,[RefDocSeqNo]    
                     ,[RefDocDate]    
                     ,[RefDocDueDate]    
                     ,[Narration]    
                     ,[IsDocPDC]'+@DocCC+' )    
                   select VoucherNo    
                   , DocDate    
                   , DueDate    
                     , 1    
                     , '+convert(nvarchar(max),@CreditAccount)+'
                     , -@Amount   , -@amtfc  ,'+convert(nvarchar(max),@status)+' 
                     ,@billno,@billdate  
                     , '+convert(nvarchar(max),@CurrID)+'
                     , '+convert(nvarchar(max),@ExchRt)+'
                     , DocumentType    
                     , 1    
                     , NULL    
                     ,NULL    
                   , NULL    
                   ,NULL    
                     , ''''    
                     , 0    
                     '+@DocCC+'  from acc_docdetails a WITH(NOLOCK)
                  join [COM_DocCCData] d  WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID 
                  where a.AccDocDetailsID='+convert(nvarchar(max),@docdetalid)
                  EXEC sp_executesql @sql,N'@Amount Float,@ExchRt float,@amtfc Float,@billno nvarchar(200),@billdate float',@Amount,@ExchRt,@amtfc,@billno,@billdate 
                  
                  if(@DimExchCCID>50000)
				  BEGIN	
						set @sql='update COM_Billwise 
						set AmountBC=round(AdjAmount/'+convert(nvarchar,@ExchRtBC)+','+convert(nvarchar,@dec)+'),ExhgRtBC='+convert(nvarchar,@ExchRtBC)+'
						where DocNo='''+@VoucherNo+''''
						exec(@sql)
				  END	
   
                
            end
      end
      
end 

    
		set @sql='select a.AccDocDetailsID,DocDate from acc_docdetails a WITH(NOLOCK)
				join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
		where DebitAccount  in('+@accids+') and (LinkedAccDocDetailsID is null or LinkedAccDocDetailsID=0) and docdate>='+convert(nvarchar,convert(float,@frmdate))+
		' and docdate<='+convert(nvarchar,convert(float,@todate))
		if(@Locationid>0)
			set @sql=@sql+'  and dcCCNID2='+convert(nvarchar,@Locationid)
		
		if(@Divisionid>0)
			set @sql=@sql+'  and dcCCNID1='+convert(nvarchar,@Divisionid)

		if(@Dimid>0)
			set @sql=@sql+'  and dcCCNID'+convert(nvarchar,@DimCCID)+'='+convert(nvarchar,@Dimid)
			
		if(isnull(@BasedOnDimsql,'')<>'')
			set @sql=@sql+@BasedOnDimsql
				
		set @sql=@sql+@where
		set @sql=@sql+' and ((DocumentType not in (14,19) and StatusID not in(377,376,447,448,449)) or (DocumentType in (14,19) and statusid=370))
		union all
		select a.AccDocDetailsID,DocDate from acc_docdetails a WITH(NOLOCK)
		join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
		where DebitAccount  in('+@accids+')and docdate>='+convert(nvarchar,convert(float,@frmdate))+
		' and docdate<='+convert(nvarchar,convert(float,@todate))
		if(@Locationid>0)
			set @sql=@sql+'  and dcCCNID2='+convert(nvarchar,@Locationid)
		
		if(@Divisionid>0)
			set @sql=@sql+'  and dcCCNID1='+convert(nvarchar,@Divisionid)

		if(@Dimid>0)
			set @sql=@sql+'  and dcCCNID'+convert(nvarchar,@DimCCID)+'='+convert(nvarchar,@Dimid)
			
		if(isnull(@BasedOnDimsql,'')<>'')
			set @sql=@sql+@BasedOnDimsql
				
		set @sql=@sql+@where
		set @sql=@sql+' and ((DocumentType not in (14,19) and StatusID not in(377,376,447,448,449)) or (DocumentType in (14,19) and statusid=370))
		order by DocDate'
	 
	 	
	
delete from @tabTrans
insert into @tabTrans
exec(@sql)

select @cnt=max(id),@i=min(id) from @tabTrans

set @i=@i-1
set @docdetalid=0
while(@i<@cnt)
begin
      set @i=@i+1 
      select @docdetalid=AccDocDetailsID from @tabTrans
      where id=@i
       set @invID=0
      select @DDate=Docdate,@Amount=Amount,@DebitAccount=DebitAccount,@VoucherNo=VoucherNo,@DocSeqNo=DocSeqNo,@invID=InvDocDetailsID,@status=StatusID,@RefNid=RefNodeid  from acc_docdetails WITH(NOLOCK)
      where AccDocDetailsID=@docdetalid
       
      
      if exists(select accountid from ACC_Accounts WITH(NOLOCK) where AccountID=@DebitAccount and IsBillwise=1)
      begin
            if((@invID is null or @invID=0) and not exists(select BillwiseID from com_billwise WITH(NOLOCK) where AccountID=@DebitAccount and [DocNo]=@VoucherNo and DocSeqNo=@DocSeqNo))
            begin  
				   if(@DimExchCCID>50000)
				   BEGIN	
						set @sql='select @ExchRtBC=ExhgRtBC from ACC_DocDetails WITH(NOLOCK)
						where AccDocDetailsID='+convert(nvarchar,@docdetalid)
						exec sp_executesql @sql,N'@ExchRtBC float OUTPUT',@ExchRtBC output
					END	

            	  if exists(select CurrencyID from acc_docdetails WITH(NOLOCK)
				  where (DebitAccount=@DebitAccount or CreditAccount=@DebitAccount) and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
				  group by CurrencyID
				  having COUNT(distinct CurrencyID)>1)
				  BEGIN
					  select @Amount=isnull(SUM(amount),0) from acc_docdetails WITH(NOLOCK)
					  where DebitAccount=@DebitAccount  and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
	              
					   select @Amount =@Amount-isnull(SUM(amount),0) from acc_docdetails WITH(NOLOCK)
					   where CreditAccount=@DebitAccount  and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
						set @amtfc=@Amount  
					  if(@DimExchCCID>50000)
						set @CurrID=@DimCurrencyID
					  ELSE	
						set @CurrID=1
						set @ExchRt=1
				   END
				   ELSE
				   BEGIN
					  select @Amount=isnull(SUM(amount),0),@amtfc=isnull(SUM(AmountFC),0),@CurrID=MAX(CurrencyID),@ExchRt=MAX(ExchangeRate) from acc_docdetails WITH(NOLOCK)
					  where DebitAccount=@DebitAccount  and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
	              
					   select @Amount =@Amount-isnull(SUM(amount),0),@amtfc=@amtfc-isnull(SUM(AmountFC),0) from acc_docdetails WITH(NOLOCK)
					   where CreditAccount=@DebitAccount  and (AccDocDetailsID=@docdetalid or LinkedAccDocDetailsID=@docdetalid)
						
				   END
                
                            
				  delete from @tabbill
				  if(@status=429)
				  BEGIN
					 insert into @tabbill
					 select VoucherNo,DocSeqNo,Amount bal,DocDate,DueDate,statusid From acc_docdetails	 WITH(NOLOCK)				 
					 where CreditAccount=@DebitAccount and refnodeid=@RefNid and RefCCID=400
					 and documenttype in(15,18) and statusid=429
				  END				  
				  ELSE if(@Locationid>0 or @Divisionid>0 or @Dimid>0)
				   begin
						  
						  set @sql='select DocNo,DocSeqNo,(amt-paid) bal,DocDate,DocDueDate,statusid From (
						  SELECT DocNo,statusid,DocSeqNo,abs(sum(AdjAmount)) amt,ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ WITH(NOLOCK) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) paid,
						  DocDate,DocDueDate FROM COM_Billwise B WITH(NOLOCK)  
			 			  WHERE  AccountID='+convert(nvarchar,@DebitAccount)+' and AdjAmount<0 and DocDate<='+convert(nvarchar,@DDate)
			 			  
			 			 if(@Locationid>0)
							set @sql=@sql+'  and dcCCNID2='+convert(nvarchar,@Locationid)
						
						if(@Divisionid>0)
							set @sql=@sql+'  and dcCCNID1='+convert(nvarchar,@Divisionid)

						if(@Dimid>0)
							set @sql=@sql+'  and dcCCNID'+convert(nvarchar,@DimCCID)+'='+convert(nvarchar,@Dimid)
						
						if(isnull(@BasedOnDimsql,'')<>'')
							set @sql=@sql+@BasedOnDimsql	
			 			  
			 			 set @sql=@sql+' and statusid=369
			 			  group by DocNo,DocDate,statusid,DocDueDate,DocSeqNo) as t
			 			  where (amt-paid)>0
			 			  order by DocDate'
			 			  
			 			  insert into @tabbill
			 			  exec(@sql)
				   end
				   else
				   begin
					  --insert into @tabbill
					  --select DocNo,DocSeqNo,(amt-paid) bal,DocDate,DocDueDate,statusid From (
					  --SELECT DocNo,DocSeqNo,statusid,abs(sum(AdjAmount)) amt,ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ WITH(NOLOCK) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) paid,
					  --DocDate,DocDueDate FROM COM_Billwise B WITH(NOLOCK)  
			 		 -- WHERE  AccountID=@DebitAccount and AdjAmount<0  and statusid=369 and DocDate<=@DDate
			 		 -- group by DocNo,DocDate,DocDueDate,statusid,DocSeqNo) as t
			 		 -- where (amt-paid)>0
			 		 -- order by DocDate
			 		 set @sql=' select DocNo,DocSeqNo,(amt-paid) bal,DocDate,DocDueDate,StatusID From (
								 SELECT DocNo,DocSeqNo,statusid,abs(sum(AdjAmount)) amt,ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ WITH(NOLOCK) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) paid,'
					 set @sql=@sql+'  DocDate,DocDueDate FROM COM_Billwise B   WITH(NOLOCK)  WHERE  ' 
			 		 set @sql=@sql+'  AccountID='+convert(nvarchar,@DebitAccount)+' '
			 		 set @sql=@sql+'  and AdjAmount<0  and statusid=369 '
			 		 if(isnull(@BasedOnDimsql,'')<>'')
						set @sql=@sql+@BasedOnDimsql
			 		 set @sql=@sql+' and DocDate<='+convert(nvarchar,@DDate) +'' 
			 		 set @sql=@sql+'  group by DocNo,DocDate,DocDueDate,StatusID,DocSeqNo) as t
			 				  where (amt-paid)>0   order by DocDate'
			 		 PRINT (@sql)		 										
			 		 insert into @tabbill
			 		  exec(@sql)	
				   end
				 
			 	  
			 	  set @AdjAmt=@Amount
			 	  select @ii=min(id),@ccnt=max(id) from @tabbill
			 	  while(@ii<=@ccnt and @AdjAmt>0)
			 	  BEGIN
			 		
			 			select @Amount=amount,@RefSeqNo=SeqNo,@VoucherNo=DocNo,@DocDate=DocDate,@duedate=duedate,@refstatus=statusid  from @tabbill
			 			where id=@ii
			 			set @ii=@ii+1
			 			if(@Amount>=@AdjAmt)
			 			BEGIN
			 				set @Amount=@AdjAmt
			 				set @AdjAmt=0
			 			END
			 			else
			 			BEGIN
			 				set @AdjAmt=@AdjAmt-@Amount
			 			END
			 			
			 		 set @sql='INSERT INTO [COM_Billwise]    
                     ([DocNo]    
                     ,[DocDate]    
                      ,[DocDueDate]    
                     ,[DocSeqNo]    
                     ,[AccountID]    
                     ,[AdjAmount],amountfc ,statusid,refstatusid   
                     ,[AdjCurrID]    
                     ,[AdjExchRT]    
                     ,[DocType]    
                     ,[IsNewReference]    
                     ,[RefDocNo]    
                     ,[RefDocSeqNo]    
                     ,[RefDocDate]    
                     ,[RefDocDueDate]    
                     ,[Narration]    
                     ,[IsDocPDC]    
                     '+@DocCC+' )    
                   select VoucherNo    
                   , DocDate    
                   , DueDate    
                     , DocSeqNo    
                     , '+convert(nvarchar(max),@DebitAccount)+'    
                     , @Amount ,round(@Amount/@ExchRt,@dec)  ,'+convert(nvarchar(max),@status)+','+convert(nvarchar(max),@refstatus)+'  
                     , '+convert(nvarchar(max),@CurrID)+'
                     , '+convert(nvarchar(max),@ExchRt)+'
                     , DocumentType    
                     , 0
                     , '''+convert(nvarchar(max),@VoucherNo)+'''    
                     ,'+convert(nvarchar(max),@RefSeqNo)+'    
                   , '''+convert(nvarchar(max),@DocDate)+'''    
                   ,'
                     if(@duedate is null)
						set @sql=@sql+'NULL'
					else	
                     set @sql=@sql+''''+convert(nvarchar(max),@duedate)+''''
                     
                     set @sql=@sql+' 
                     , ''''    
                     , 0    
                     '+@DocCC+'  from acc_docdetails a WITH(NOLOCK)
                  join [COM_DocCCData] d WITH(NOLOCK) on a.AccDocDetailsID=d.AccDocDetailsID 
                  where a.AccDocDetailsID='+convert(nvarchar(max),@docdetalid)
                  EXEC sp_executesql @sql,N'@Amount Float,@ExchRt float,@dec float',@Amount,@ExchRt,@dec
			 	  
			 	  END
			 	  if(@AdjAmt>0)
			 	  BEGIN		
                  set @sql='INSERT INTO [COM_Billwise]    
                     ([DocNo]    
                     ,[DocDate]    
                      ,[DocDueDate]    
                     ,[DocSeqNo]    
                     ,[AccountID]    
                     ,[AdjAmount],amountfc,statusid    
                     ,[AdjCurrID]    
                     ,[AdjExchRT]    
                     ,[DocType]    
                     ,[IsNewReference]    
                     ,[RefDocNo]    
                     ,[RefDocSeqNo]    
                     ,[RefDocDate]    
                     ,[RefDocDueDate]    
                     ,[Narration]    
                     ,[IsDocPDC]    
                     '+@DocCC+' )    
                   select VoucherNo    
                   , DocDate    
                   , DueDate    
                     , DocSeqNo    
                     , '+convert(nvarchar(max),@DebitAccount)+'    
                     , @AdjAmt ,round(@AdjAmt/@ExchRt,@dec) ,'+convert(nvarchar(max),@status)+'  
                    , '+convert(nvarchar(max),@CurrID)+'
                     , '+convert(nvarchar(max),@ExchRt)+'
                     , DocumentType    
                     , 1    
                     , NULL    
                     ,NULL    
                   , NULL    
                   ,NULL    
                     , ''''    
                     , 0    
                     '+@DocCC+'  from acc_docdetails a WITH(NOLOCK)
                  join [COM_DocCCData] d WITH(NOLOCK) on a.AccDocDetailsID=d.AccDocDetailsID 
                  where a.AccDocDetailsID='+convert(nvarchar(max),@docdetalid)
                  EXEC sp_executesql @sql,N'@AdjAmt Float,@ExchRt float,@dec int',@AdjAmt,@ExchRt,@dec
                  END   
                  
                  if(@DimExchCCID>50000)
				  BEGIN	
						select @VoucherNo=VoucherNo,@DocSeqNo=DocSeqNo from acc_docdetails WITH(NOLOCK)
						where AccDocDetailsID=@docdetalid

						set @sql='update COM_Billwise 
						set AmountBC=round(AdjAmount/'+convert(nvarchar,@ExchRtBC)+','+convert(nvarchar,@dec)+'),ExhgRtBC='+convert(nvarchar,@ExchRtBC)+'
						where DocNo='''+@VoucherNo+''' and [DocSeqNo]='+convert(nvarchar,@DocSeqNo)
						exec(@sql)
				  END	

            end
            else if(@invID>0 and ((@Locationid>0 and not exists(select BillwiseID from com_billwise WITH(NOLOCK) where AccountID=@DebitAccount and [DocNo]=@VoucherNo and dcCCNID2=@Locationid))
             or (@Locationid=0 and not exists(select BillwiseID from com_billwise WITH(NOLOCK) where AccountID=@DebitAccount and [DocNo]=@VoucherNo))))
            begin
				   if(@DimExchCCID>50000)
				   BEGIN	
						set @sql='select @ExchRtBC=ExhgRtBC from ACC_DocDetails WITH(NOLOCK)
						where AccDocDetailsID='+convert(nvarchar,@docdetalid)
						exec sp_executesql @sql,N'@ExchRtBC float OUTPUT',@ExchRtBC output
					END	

				  if exists(select CurrencyID from acc_docdetails WITH(NOLOCK)
				  where (DebitAccount=@DebitAccount or CreditAccount=@DebitAccount) and VoucherNo=@VoucherNo
				  group by CurrencyID
				  having COUNT(distinct CurrencyID)>1)
				  BEGIN
					  select @Amount=isnull(SUM(amount),0) from acc_docdetails WITH(NOLOCK)
					  where DebitAccount=@DebitAccount  and VoucherNo=@VoucherNo
	              
					   select @Amount =@Amount-isnull(SUM(amount),0) from acc_docdetails WITH(NOLOCK)
					   where CreditAccount=@DebitAccount  and VoucherNo=@VoucherNo
						set @amtfc=@Amount  
					  if(@DimExchCCID>50000)
						set @CurrID=@DimCurrencyID
					  ELSE	
						set @CurrID=1
						set @ExchRt=1
				   END
				   ELSE
				   BEGIN
					  select @Amount=isnull(SUM(amount),0),@amtfc=isnull(SUM(AmountFC),0),@CurrID=MAX(CurrencyID),@ExchRt=MAX(ExchangeRate) from acc_docdetails WITH(NOLOCK)
					  where DebitAccount=@DebitAccount  and VoucherNo=@VoucherNo
	              
					   select @Amount =@Amount-isnull(SUM(amount),0),@amtfc=@amtfc-isnull(SUM(AmountFC),0) from acc_docdetails WITH(NOLOCK)
					   where CreditAccount=@DebitAccount  and VoucherNo=@VoucherNo
						
				   END
				   
			          
				  delete from @tabbill
				  
				  if(@Locationid>0 or @Divisionid>0 or @Dimid>0)
				   begin
					 
						  set @sql='select DocNo,DocSeqNo,(amt-paid) bal,DocDate,DocDueDate,StatusID From (
						  SELECT DocNo,DocSeqNo,StatusID,abs(sum(AdjAmount)) amt,ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ WITH(NOLOCK) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) paid,
						  DocDate,DocDueDate FROM COM_Billwise B WITH(NOLOCK)  
			 			  WHERE  AccountID='+convert(nvarchar,@DebitAccount)+' and AdjAmount<0 and DocDate<='+convert(nvarchar,@DDate)
			 			  
			 			 if(@Locationid>0)
							set @sql=@sql+'  and dcCCNID2='+convert(nvarchar,@Locationid)
						
						if(@Divisionid>0)
							set @sql=@sql+'  and dcCCNID1='+convert(nvarchar,@Divisionid)

						if(@Dimid>0)
							set @sql=@sql+'  and dcCCNID'+convert(nvarchar,@DimCCID)+'='+convert(nvarchar,@Dimid)
							
						if(isnull(@BasedOnDimsql,'')<>'')
							set @sql=@sql+@BasedOnDimsql	
			 			  
			 			 set @sql=@sql+' and statusid=369
			 			  group by DocNo,DocDate,StatusID,DocDueDate,DocSeqNo) as t
			 			  where (amt-paid)>0
			 			  order by DocDate'
			 			    
			 			    insert into @tabbill
			 			    exec(@sql)
				   end
				   else
				   begin
						--insert into @tabbill
					 -- select DocNo,DocSeqNo,(amt-paid) bal,DocDate,DocDueDate,StatusID From (
					 -- SELECT DocNo,DocSeqNo,StatusID,abs(sum(AdjAmount)) amt,ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ WITH(NOLOCK) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) paid,
					 -- DocDate,DocDueDate FROM COM_Billwise B WITH(NOLOCK)  
			 		--  WHERE  AccountID=@DebitAccount and AdjAmount<0  and statusid=369 and DocDate<=@DDate
			 		--  group by DocNo,DocDate,StatusID,DocDueDate,DocSeqNo) as t
			 		--  where (amt-paid)>0
			 		--  order by DocDate
			 		 set @sql=' select DocNo,DocSeqNo,(amt-paid) bal,DocDate,DocDueDate,StatusID From (
								 SELECT DocNo,DocSeqNo,StatusID,abs(sum(AdjAmount)) amt,ISNULL((SELECT abs(SUM(SQ.AdjAmount)) FROM COM_Billwise SQ WITH(NOLOCK) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo),0) paid,'
					 set @sql=@sql+'  DocDate,DocDueDate FROM COM_Billwise B   WITH(NOLOCK)  WHERE  ' 
			 		 set @sql=@sql+'  AccountID='+convert(nvarchar,@DebitAccount)+' '
			 		 set @sql=@sql+'  and AdjAmount<0  and statusid=369 '
			 		 if(isnull(@BasedOnDimsql,'')<>'')
						set @sql=@sql+@BasedOnDimsql
			 		 set @sql=@sql+' and DocDate<='+convert(nvarchar,@DDate) +'' 
			 		 set @sql=@sql+'  group by DocNo,DocDate,StatusID,DocDueDate,DocSeqNo) as t
			 				where (amt-paid)>0   order by DocDate'
			 		 PRINT (@sql)		 										
			 		 insert into @tabbill
			 		 exec(@sql)
				   end
				 
			 	   
				  select @billno=BillNo,@billdate=BillDate from INV_DocDetails WITH(NOLOCK)
				  where InvDocDetailsID=@invID
                 
			 	  set @AdjAmt=@Amount
			 	  select @ii=min(id),@ccnt=max(id) from @tabbill
			 	  while(@ii<=@ccnt and @AdjAmt>0)
			 	  BEGIN
			 		
			 			select @Amount=amount,@RefSeqNo=SeqNo,@VoucherNo=DocNo,@DocDate=DocDate,@duedate=duedate,@refstatus=StatusID  from @tabbill
			 			where id=@ii
			 			set @ii=@ii+1
			 			if(@Amount>=@AdjAmt)
			 			BEGIN
			 				set @Amount=@AdjAmt
			 				set @AdjAmt=0
			 			END
			 			else
			 			BEGIN
			 				set @AdjAmt=@AdjAmt-@Amount
			 			END
			 			
			 		 set @sql='INSERT INTO [COM_Billwise]    
                     ([DocNo]    
                     ,[DocDate]    
                      ,[DocDueDate]    
                     ,[DocSeqNo]    
                     ,[AccountID]    
                     ,[AdjAmount],amountfc ,statusid,refstatusid,BillNo,BillDate   
                     ,[AdjCurrID]    
                     ,[AdjExchRT]    
                     ,[DocType]    
                     ,[IsNewReference]    
                     ,[RefDocNo]    
                     ,[RefDocSeqNo]    
                     ,[RefDocDate]    
                     ,[RefDocDueDate]    
                     ,[Narration]    
                     ,[IsDocPDC]    
                     '+@DocCC+'  )    
                   select VoucherNo    
                   , DocDate    
                   , DueDate    
                     , 1    
                     , '+convert(nvarchar(max),@DebitAccount)+'    
                     , @Amount , round(@Amount/@ExchRt,@dec),'+convert(nvarchar(max),@status)+','+convert(nvarchar(max),@refstatus)+'
                     ,@billno,@billdate 
                    , '+convert(nvarchar(max),@CurrID)+'
                     , '+convert(nvarchar(max),@ExchRt)+'
                     , DocumentType    
                     , 0
                     , '''+convert(nvarchar(max),@VoucherNo)+'''    
                     ,'+convert(nvarchar(max),@RefSeqNo)+'
                   , '''+convert(nvarchar(max),@DocDate)+'''   
                   ,'
                     if(@duedate is null)
						set @sql=@sql+'NULL'
					else	
                     set @sql=@sql+''''+convert(nvarchar(max),@duedate)+''''
                     
                     set @sql=@sql+'   
                     , ''''    
                     , 0    
                     '+@DocCC+'  from acc_docdetails a WITH(NOLOCK)
                  join [COM_DocCCData] d WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID 
                  where a.AccDocDetailsID='+convert(nvarchar(max),@docdetalid)
                  EXEC sp_executesql @sql,N'@Amount Float,@ExchRt float,@dec float,@billno nvarchar(200),@billdate float',@Amount,@ExchRt,@dec,@billno,@billdate 
			 	  
			 	  END
			 	  if(@AdjAmt>0)
			 	  BEGIN		
                  set @sql='INSERT INTO [COM_Billwise]    
                     ([DocNo]    
                     ,[DocDate]    
                      ,[DocDueDate]    
                     ,[DocSeqNo]    
                     ,[AccountID]    
                     ,[AdjAmount],amountfc, statusid,BillNo,BillDate     
                     ,[AdjCurrID]    
                     ,[AdjExchRT]    
                     ,[DocType]    
                     ,[IsNewReference]    
                     ,[RefDocNo]    
                     ,[RefDocSeqNo]    
                     ,[RefDocDate]    
                     ,[RefDocDueDate]    
                     ,[Narration]    
                     ,[IsDocPDC]    
                     '+@DocCC+'  )    
                   select VoucherNo    
                   , DocDate    
                   , DueDate    
                     , 1    
                     , '+convert(nvarchar(max),@DebitAccount)+'    
                     , @AdjAmt , round(@AdjAmt/@ExchRt,@dec)   ,'+convert(nvarchar(max),@status)+'
                     ,@billno,@billdate 
                     , '+convert(nvarchar(max),@CurrID)+'
                     , '+convert(nvarchar(max),@ExchRt)+'
                     , DocumentType    
                     , 1    
                     , NULL    
                     ,NULL    
                   , NULL    
                   ,NULL    
                     , ''''    
                     , 0    
                     '+@DocCC+'  from acc_docdetails a WITH(NOLOCK)
                  join [COM_DocCCData] d  WITH(NOLOCK) on a.InvDocDetailsID=d.InvDocDetailsID 
                  where a.AccDocDetailsID='+convert(nvarchar(max),@docdetalid)
                  EXEC sp_executesql @sql,N'@AdjAmt Float,@ExchRt float,@dec int,@billno nvarchar(200),@billdate float',@AdjAmt,@ExchRt,@dec,@billno,@billdate 
                  END   
                
                  if(@DimExchCCID>50000)
				  BEGIN	
						select @VoucherNo=VoucherNo from acc_docdetails
						where AccDocDetailsID=@docdetalid

						set @sql='update COM_Billwise 
						set AmountBC=round(AdjAmount/'+convert(nvarchar,@ExchRtBC)+','+convert(nvarchar,@dec)+'),ExhgRtBC='+convert(nvarchar,@ExchRtBC)+'
						where DocNo='''+@VoucherNo+''''
						exec(@sql)
				  END	

            end
      end
end 

end --dimension
END--division
END--location

DROP TABLE #tabDimensionValues		
COMMIT TRANSACTION
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID 
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
