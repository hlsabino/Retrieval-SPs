USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetPOSCash]
	@RegisterID [bigint],
	@ShiftID [bigint],
	@DocDate [datetime],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY		
SET NOCOUNT ON
		declare @Reg int,@shft int,@sql nvarchar(max),@values nvarchar(max),@CshIn int,@OpCsh int,@CshOut int,@Join nvarchar(max),@extraCol nvarchar(max),@rctcc nvarchar(max),@Orders nvarchar(max)
		declare @PosSales nvarchar(max),@PosReturn nvarchar(max),@GiftVSale nvarchar(max),@cash float,@Where nvarchar(max)
		
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
		
		select @DocDate=Day from POS_loginHistory WITH(NOLOCK) 
		where RegisterNodeID=@RegisterID and Day<convert(float,@DocDate)
						
		if(@Where is null or @Where='')
		BEGIN
			set @Where=' and DcccNid'+CONVERT(nvarchar,(@Reg-50000))+'='+CONVERT(nvarchar,@RegisterID)
			if(@ShiftID>0 and @shft is not null and @shft<>'' and @shft>50000)
				set @Where=@Where+' and DcccNid'+CONVERT(nvarchar,(@shft-50000))+'='+CONVERT(nvarchar,@ShiftID) 		
			set @Where=@Where+' and datediff(day,convert(datetime,DocDate),'''+convert(nvarchar(50),@DocDate)+''')=0'
		END
		
		set @extraCol=',convert(datetime,DocDate) DocDate,DcccNid'+CONVERT(nvarchar,(@Reg-50000))+' Reg'
		
		set @Join=''
		set @Where=@Where+' group by DocDate,DcccNid'+CONVERT(nvarchar,(@Reg-50000))
				
		select @values=replace(SysColumnName,'dcNum','isnull(sum(dccalcNum')
		from ADM_CostCenterDef a with(nolock)
		join ADM_DocumentTypes b with(nolock) on a.CostCenterID=b.CostCenterID
		where DocumentType=38 and IsUserDefined=0 and SectionID=5 and SysColumnName like 'dcNum%'
		
		set @cash=0
		
		set @sql='select @cash='+@values+'),0) from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
		join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
		where CostcenterID in('+@PosSales+')'
		
		set @sql=@sql+@Where
		print @sql	
		if(@values is not null and @values<>'')
			exec sp_executesql @sql,N'@cash float output',@cash output
		 
		
		if(@CshIn>40000 or @OpCsh>40000)
		BEGIN
			set @sql='select @cash=@cash+isnull(sum(Amount),0) from Acc_DocDetails a WITH(NOLOCK)
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
			print @sql	
			exec sp_executesql @sql,N'@cash float output',@cash output
		
		END	
		

		if(@CshOut>40000)
 		BEGIN
 			set @sql='select @cash=@cash-isnull(sum(Amount),0) from Acc_DocDetails a WITH(NOLOCK)
			join COM_DocCCData c WITH(NOLOCK) on a.AccDocDetailsID=c.AccDocDetailsID'+@Join+'
			where CostCenterID='+CONVERT(nvarchar,@CshOut)+@Where
			print @sql	
			exec sp_executesql @sql,N'@cash float output',@cash output		
		END	
		
		set @values=''
		select @values=replace(SysColumnName,'dcNum','isnull(sum(dccalcNum')
		from ADM_CostCenterDef a with(nolock)
		join ADM_DocumentTypes b with(nolock) on a.CostCenterID=b.CostCenterID
		where DocumentType=38 and IsUserDefined=0 and SectionID=12 and SysColumnName like 'dcNum%'
		
		
		set @sql='select @cash=@cash-'+@values+'),0) from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
		join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
		where CostcenterID in('+@PosSales+')'
		
		set @sql=@sql+@Where
		print @sql	
		if(@values is not null and @values<>'')
			exec sp_executesql @sql,N'@cash float output',@cash output
		
		set @values=''
		select @values=replace(SysColumnName,'dcNum','isnull(sum(dccalcNum')
		from ADM_CostCenterDef a with(nolock)
		join ADM_DocumentTypes b with(nolock) on a.CostCenterID=b.CostCenterID
		where DocumentType=38 and IsUserDefined=0 and SectionID=12 and SysColumnName like 'dcNum%'
		
		
		set @sql='select @cash=@cash-'+@values+'),0) from INV_DocDetails a WITH(NOLOCK)
		join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID
		join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID'+@Join+'
		where CostcenterID in('+@PosReturn+')'
		
		set @sql=@sql+@Where
		print @sql	
		if(@values is not null and @values<>'')
			exec sp_executesql @sql,N'@cash float output',@cash output
		 
		
		select @cash cash
		
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
