USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetPOSDetails]
	@PosSessionID [int],
	@RegisterID [int],
	@ShiftID [int],
	@CloseType [int],
	@DocDate [datetime],
	@Where [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY		
SET NOCOUNT ON
		declare @Reg int,@shft int,@sql nvarchar(max),@values nvarchar(max),@CshIn int,@OpCsh int,@CshOut int,@Join nvarchar(max),@extraCol nvarchar(max),@rctcc nvarchar(max),@Orders nvarchar(max)
		declare @PosSales nvarchar(max),@PosReturn nvarchar(max),@GiftVSale nvarchar(max)
		
		set @rctcc=''
		Select @rctcc=@rctcc+convert(nvarchar,Costcenterid)+',' from Com_documentpreferences WITH(NOLOCK) 
		where prefName='UseasPosReciept' and prefValue ='true'
		
		set @Orders=''
		Select @Orders=@Orders+convert(nvarchar,Costcenterid)+',' from Com_documentpreferences WITH(NOLOCK) 
		where prefName='UseAsOrder' and prefValue ='true'
		
		set @GiftVSale=''
		Select @GiftVSale=@GiftVSale+convert(nvarchar,Costcenterid)+',' from Com_documentpreferences WITH(NOLOCK) 
		where prefName='UseasGiftVoucher' and prefValue ='true'

		set @PosSales=''
		Select @PosSales=@PosSales+convert(nvarchar,Costcenterid)+',' from Com_documentpreferences WITH(NOLOCK) 
		where prefName='UseAsOrder' and prefValue<>'true'
	
		set @PosReturn=''
		Select @PosReturn=@PosReturn+convert(nvarchar,Costcenterid)+','  from adm_documenttypes WITH(NOLOCK) 
		where documenttype=39
		 

		if(@rctcc<>'')
			set @rctcc=substring(@rctcc,0,len(@rctcc))
		if(@Orders<>'')
			set @Orders=substring(@Orders,0,len(@Orders))	
		if(@GiftVSale<>'')
			set @GiftVSale=substring(@GiftVSale,0,len(@GiftVSale))	
		if(@PosSales<>'')
			set @PosSales=substring(@PosSales,0,len(@PosSales))	
		if(@PosReturn<>'')
			set @PosReturn=substring(@PosReturn,0,len(@PosReturn))	

		set @Reg=0
		Select @Reg=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='Registers'
		and Value is not null and ISNUMERIC(Value)=1
		
		set @shft=0
		Select @shft=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='PosShifts'
		and Value is not null and ISNUMERIC(Value)=1
		
		set @CshIn=0
		Select @CshIn=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='CashIn'
		and Value is not null and ISNUMERIC(Value)=1
		
		set @OpCsh=0
		Select @OpCsh=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='OpeningCashDOc'
		and Value is not null and ISNUMERIC(Value)=1

		set @CshOut=0
		Select @CshOut=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='CashOut'
		and Value is not null and ISNUMERIC(Value)=1
				
		if(@Where is null or @Where='')
		BEGIN
			set @Where=' and DcccNid'+CONVERT(nvarchar,(@Reg-50000))+'='+CONVERT(nvarchar,@RegisterID)
			if(@ShiftID>0 and @shft is not null and @shft<>'' and @shft>50000)
				set @Where=@Where+' and DcccNid'+CONVERT(nvarchar,(@shft-50000))+'='+CONVERT(nvarchar,@ShiftID) 		
			set @Where=@Where+' and datediff(day,convert(datetime,DocDate),'''+convert(nvarchar(50),@DocDate)+''')=0'
		END
		set @Where=@Where+' and a.Statusid<>376 '
		
		set @extraCol=',convert(datetime,DocDate) DocDate,DcccNid'+CONVERT(nvarchar,(@Reg-50000))+' Reg'
		
		set @Join=''
		if @CloseType=0 or @CloseType=3
		begin
			declare @CloseID INT
			select @CloseID=CloseID from POS_loginHistory with(nolock) where POSLoginHistoryID=@PosSessionID
			set @Join=' inner join COM_DocID DID with(nolock) on DID.ID=a.DocID
			inner join POS_loginHistory PH with(nolock) on PH.POSLoginHistoryID=DID.PosSessionID'
			set @Where=@Where+' and PH.CloseID='+convert(nvarchar,@CloseID)
		end
		
		set @Where=@Where+' group by DocDate,DcccNid'+CONVERT(nvarchar,(@Reg-50000))
				
		select @values=PrefValue from [COM_DocumentPreferences] with(nolock) where costcenterid=40994 and [PrefName]='POSFields'
--select @values
		set @values=replace(@values,'dcnum','isnull(sum(dccalcnum')
		set @values=replace(@values,'gross','isnull(sum(gross')
		set @values=replace(@values,',','),0),')
		set @values=SUBSTRING(@values,0,len(@values))
--select @values
		set @sql='select '+@values+@extraCol+' from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
		join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
		where CostcenterID in('+@PosSales+')'
		
		set @sql=@sql+@Where
		print @sql
		if(@values is not null and @values<>'')
			exec(@sql)
		else
			select 1 where 1=2
			
		set @sql='SELECT  '''+@Orders+''' as orders,'''+@GiftVSale+''' as GiftVSale,count(distinct docid) cnt,a.Costcenterid,a.documenttype,d.DocumentName, DocAbbr+''-''+DocPrefix Prefix,MAX(convert(INT,DocNumber)) MAXNumber,Min(convert(INT,DocNumber)) MinNumber'+@extraCol+'
		from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
		join ADM_DocumentTypes d WITH(NOLOCK) on a.CostCenterID=d.CostCenterID'+@Join+'
		where a.documenttype in(38,39)  '+@Where+',a.Costcenterid,DocAbbr,DocPrefix,d.DocumentName,a.documenttype
		order by a.documenttype'
 		exec(@sql)
 		
 		
		if(@CshIn>40000)
		BEGIN
			set @sql='select isnull(sum(Amount),0) Amount,RefCCID'+@extraCol+' from Acc_DocDetails a WITH(NOLOCK)
			join COM_DocCCData c WITH(NOLOCK) on a.AccDocDetailsID=c.AccDocDetailsID'+@Join+'
			where CostCenterID in('
			
			if(@CshIn>40000)
				set @sql=@sql+CONVERT(nvarchar,@CshIn)
			if(@OpCsh>40000)
			BEGIN
				if(@CshIn>40000)
					set @sql=@sql+','+CONVERT(nvarchar,@OpCsh)
				else
					set @sql=@sql+CONVERT(nvarchar,@OpCsh)	
			END	

			set @sql=@sql+') '+@Where+',RefCCID  Order BY RefCCID desc'
			--print @sql	
			exec(@sql)
		END	
		else
			select 1 where 1=2

		if(@CshOut>40000)
 		BEGIN
 			set @sql='select isnull(sum(Amount),0) Amount'+@extraCol+' from Acc_DocDetails a WITH(NOLOCK)
			join COM_DocCCData c WITH(NOLOCK) on a.AccDocDetailsID=c.AccDocDetailsID'+@Join+'
			where CostCenterID='+CONVERT(nvarchar,@CshOut)+@Where
			exec(@sql)
		END	
		else
			select 1 where 1=2	
				
		
		set @sql='select '+@values+@extraCol+' from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
		join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
		where CostcenterID in('+@PosReturn+')  '+@Where
		
		if(@values is not null and @values<>'')
			exec(@sql)
		else
			select 1 where 1=2
			
		set @values=''
		
		select @values=@values+' when costcenterid='+convert(nvarchar,a.costcenterid)+' then '+replace(SysColumnName,'dcNum','dccalcNum')
		from ADM_CostCenterDef a with(nolock)
		join ADM_DocumentTypes b with(nolock) on a.CostCenterID=b.CostCenterID
		where DocumentType=38 and SectionID=12 and SysColumnName like 'dcNum%'
		
		set @sql='select sum(case'+@values +' end) '+@extraCol+' from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
		join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
		where CostcenterID in('+@PosSales+') '+@Where
		
		if(@values is not null and @values<>'')
			exec(@sql)
		else
			select 1 where 1=2
		
		set @values=''
		
		select @values=@values+' when costcenterid='+convert(nvarchar,a.costcenterid)+' then '+replace(SysColumnName,'dcNum','dccalcNum')
		from ADM_CostCenterDef a with(nolock)
		join ADM_DocumentTypes b with(nolock) on a.CostCenterID=b.CostCenterID
		where DocumentType=39 and SectionID=12 and SysColumnName like 'dcNum%'
	
		set @sql='select sum(case'+@values +' end)'+@extraCol+' from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
		join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
		where CostcenterID in('+@PosReturn+') '+@Where
		
		if(@values is not null and @values<>'')
			exec(@sql)
		else
			select 1 where 1=2
		
		
		if(@rctcc<>'')
		BEGIN
			select @values=PrefValue from [COM_DocumentPreferences] with(nolock) where costcenterid=40994 and [PrefName]='POSFields'
	
			set @values=replace(@values,'dcnum','isnull(sum(dccalcnum')
			set @values=replace(@values,'gross','isnull(sum(0')
			set @values=replace(@values,',','),0),')
			set @values=SUBSTRING(@values,0,len(@values))

			set @sql='select '+@values+@extraCol+' from Acc_DocDetails a WITH(NOLOCK)
			join COM_DocCCData c WITH(NOLOCK) on a.AccDocDetailsID=c.AccDocDetailsID
			join COM_DocNumData n WITH(NOLOCK) on a.AccDocDetailsID=n.AccDocDetailsID'+@Join+'
			where CostcenterID in('+@rctcc+') '+@Where		
			if(@values is not null and @values<>'')
				exec(@sql)
			else
				select 1 where 1=2
		END
		ELSE
			select 1 where 1=2
		
		if(@Orders<>'')
		BEGIN
			select @values=PrefValue from [COM_DocumentPreferences] with(nolock) where costcenterid=40994 and [PrefName]='POSFields'
			
			set @values=replace(@values,'dcnum','isnull(sum(dccalcnum')
			set @values=replace(@values,'gross','isnull(sum(gross')
			set @values=replace(@values,',','),0),')
			set @values=SUBSTRING(@values,0,len(@values))	
			
			set @sql='select '+@values+@extraCol+' from INV_DocDetails a WITH(NOLOCK)
			join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
			join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
			where  CostcenterID in('+@Orders+')'
			set @sql=@sql+@Where
			print @sql
			if(@values is not null and @values<>'')
				exec(@sql)
			else
				select 1 where 1=2
		END
		ELSE
			select 1 where 1=2
		
		if(@GiftVSale<>'')
		BEGIN
			select @values=PrefValue from [COM_DocumentPreferences] with(nolock) where costcenterid=40994 and [PrefName]='POSFields'
			
			set @values=replace(@values,'dcnum','isnull(sum(dccalcnum')
			set @values=replace(@values,'gross','isnull(sum(gross')
			set @values=replace(@values,',','),0),')
			set @values=SUBSTRING(@values,0,len(@values))	
			
			set @sql='select '+@values+@extraCol+' from INV_DocDetails a WITH(NOLOCK)
			join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
			join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
			where  CostcenterID in('+@GiftVSale+')'
			set @sql=@sql+@Where
			print @sql
			if(@values is not null and @values<>'')
				exec(@sql)
			else
				select 1 where 1=2
		END
		ELSE
			select 1 where 1=2	
				
		if(@Where is not null and @Where<>'')
		BEGIN
				select @values=PrefValue from [COM_DocumentPreferences] with(nolock) where costcenterid=40994 and [PrefName]='POSFields'
				declare @tbl table(id int identity(1,1),colname nvarchar(100))
				insert into @tbl
				exec SPSplitString @values,','  
				select resourcedata,colname,SectionID from adm_costcenterdef a WITH(NOLOCK)
				join @tbl b on a.Syscolumnname=b.colname
				join com_languageresources c WITH(NOLOCK) on c.resourceid=a.resourceid
				where a.costcenterid=40994 and c.LanguageID=@LangID
				order by id
		END	
		ELSE if(@CloseType in(4,5))
		BEGIN
			declare @IsShiftClose bit,@IsDayClose bit
			set @sql='select @values=DetailsXML,@IsDayClose=IsDayClose,@IsShiftClose=IsShiftClose from POS_loginHistory WITH(NOLOCK)
				where RegisterNodeID='+convert(nvarchar(max),@RegisterID)+' and datediff(day,convert(datetime,Day),'''+convert(nvarchar(50),@DocDate)+''')=0 '
			
			if(@ShiftID>0)
					set @sql=@sql+' and ShiftNodeID='+convert(nvarchar(max),@ShiftID)
			
			set @sql=@sql+'order by posloginhistoryid'
			
			exec sp_executesql @sql,N'@values nvarchar(max) OUTPUT,@IsDayClose bit output,@IsShiftClose bit output',@values output,@IsDayClose output,@IsShiftClose output
			
			if((@CloseType=4 and (@IsDayClose is null or @IsDayClose<>1)) OR (@CloseType=5 and (@IsShiftClose is null or @IsShiftClose<>1)))
				select 'Not close' 	Isclose		
			else	
				select @values 'DetailsXML'
		END		
		else
			select 1 where 1=2	
			
		if exists(Select prefValue from Com_documentpreferences WITH(NOLOCK) 
		where prefName='ShowDenomInClose' and prefValue ='true')
		BEGIN
			set @sql='select Notes,sum(case when DocumentType=39 THEN NotesTender*-1 else NotesTender end) Tender'+@extraCol+' from INV_DocDetails a WITH(NOLOCK)
			join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
			join COM_DocDenominations n WITH(NOLOCK) on a.DOCID=n.DOCID'+@Join+'
			where DocumentType in(38,39)'+@Where+',n.Notes'
			exec(@Sql)
		END
			
		if(@RegisterID>0)
		BEGIN
			select @values=TableName from ADM_Features WITH(NOLOCK)
			where FeatureID=@Reg			
			set @Sql='SELECT Name,Code from '+@values+' WITH(NOLOCK) where NodeID='+convert(nvarchar(max),@RegisterID)
			exec(@Sql)
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
