USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_ValidateBudget]
	@Where [nvarchar](max),
	@DocDate [datetime],
	@BudStartDate [datetime],
	@BudgetID [bigint],
	@dtype [int],
	@seq [int],
	@saveUnapp [nvarchar](100),
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY            
SET NOCOUNT ON; 
	declare @AllocBudget float,@Mnt int,@BudgetUsed float,@budName NVARCHAR(500),@CF NVARCHAR(5),@AllocID BIGINT
	declare @BudgType int,@QtyType int,@Budget int,@colName NVARCHAR(MAX),@sql NVARCHAR(MAX),@temp int,@nonaccdocs  NVARCHAR(MAX),@NonAccDocsField nvarchar(100)
	
	set @nonaccdocs=''
	
	select @Budget=QtyBudget,@QtyType=QtyType,@BudgType=BudgetTypeID,@budName=BudgetName
	,@nonaccdocs=NonAccDocs,@NonAccDocsField=NonAccDocsField
	from COM_BudgetDef WITH(NOLOCK)
	where BudgetDefID=@BudgetID
		
	if(@BudgType=0)
		set @colName='AnnualAmount'
	else if(@BudgType=1)
	BEGIN
		set @Mnt=DATEDIFF("M",@BudStartDate,@DocDate)
		if(@Mnt>=0 and @Mnt<6)
			set @colName='YearH1Amount'
		else if(@Mnt>=6 and @Mnt<12)
			set @colName='YearH2Amount'
		else
			return -999	
	END
	else if(@BudgType=2)
	BEGIN
		set @Mnt=DATEDIFF("M",@BudStartDate,@DocDate)
		if(@Mnt>=0 and @Mnt<3)
			set @colName='Qtr1Amount'
		else if(@Mnt>=3 and @Mnt<6)
			set @colName='Qtr2Amount'
		else if(@Mnt>=6 and @Mnt<9)
			set @colName='Qtr3Amount'
		else if(@Mnt>=9 and @Mnt<12)
			set @colName='Qtr4Amount'		
		else
			return -999	
	END		
	else if(@BudgType=3)
	BEGIN
		set @Mnt=DATEDIFF("M",@BudStartDate,@DocDate)
		if(@Mnt>=0 and @Mnt<12)
			set @Mnt=@Mnt+1
		else
			return -999	
		set @colName='Month'+convert(nvarchar,@Mnt)+'Amount'
	END
	
	set @sql='select @AllocBudget='+@colName+',@CF=CF,@AllocID=BudgetAllocID from COM_BudgetAlloc WITH(NOLOCK)
	where BudgetDefID='+convert(nvarchar,@BudgetID)
	
	set @sql=@sql+replace(replace(replace(@Where,'dcccnid','ccnid'),'CreditAccount','AccountID'),'DebitAccount','AccountID')

	exec sp_executeSQL @sql,N'@AllocBudget float output,@cf nvarchar(5) output,@AllocID BIGINT output',@AllocBudget output,@CF output,@AllocID output
	
	if(@CF='M' and @Mnt>1)
	BEGIN
		set @temp=@Mnt
		set @colName=''
		while(@temp>1)
		BEGIN
			set @temp=@temp-1
			set @colName=@colName+'+Month'+convert(nvarchar,@temp)+'Amount'
		END
		
		set @sql='select @AllocBudget=@AllocBudget'+@colName+' from COM_BudgetAlloc WITH(NOLOCK)
			where BudgetAllocID='+convert(nvarchar,@AllocID)
		
		exec sp_executeSQL @sql,N'@AllocBudget float output',@AllocBudget output
			
	END
	
	if(@AllocBudget is not null and @AllocBudget>0)
	BEGIN
		set @sql='select @BudgetUsed='
		
		if(@nonaccdocs is not null and @nonaccdocs<>'' and @NonAccDocsField is not null and @NonAccDocsField<>'0' and isnumeric(@NonAccDocsField)=1)
		BEGIN
			set @sql=@sql+'SUM(isnull(DcNum'+@NonAccDocsField+',0))'
		END
		ELSE
		BEGIN
			if(@Budget=1)
				set @sql=@sql+'SUM(isnull(UOMConvertedQty,0))'
			else
				set @sql=@sql+'SUM(isnull(Gross,0))'
		END
			
		set @sql=@sql+' from INV_DocDetails i with(nolock)
		join COM_DocCCData c with(nolock) on i.InvDocDetailsID=c.InvDocDetailsID '
		if(@nonaccdocs is not null and @nonaccdocs<>'' and @NonAccDocsField is not null and @NonAccDocsField<>'0' and isnumeric(@NonAccDocsField)=1)
		BEGIN
			set @sql=@sql+' join COM_DocNumData n with(nolock) on i.InvDocDetailsID=n.InvDocDetailsID '
		END
		
		set @sql=@sql+' where '
		
		if(@nonaccdocs is not null and @nonaccdocs<>'')
		BEGIN
			set @sql=@sql+'	CostCenterID in ('+@nonaccdocs+') '
		END
		ELSE
		BEGIN
			set @sql=@sql+'	IsQtyIgnored=0 '
			
			if(@dtype in(11,7,9,24,33,10,8,12))
				set @sql=@sql+' and VoucherType=-1 '
			else
				set @sql=@sql+' and VoucherType=1 '	
		END
		
		set @sql=@sql+@Where
		if(@BudgType=0)
			set @sql=@sql+' and DocDate>='+CONVERT(nvarchar,convert(float,@BudStartDate))+' and DocDate<'+CONVERT(nvarchar,convert(float,DATEadd("YEAR",1,@BudStartDate)))
		else if(@BudgType=1)
		BEGIN	
			if(@Mnt>=0 and @Mnt<6)
				set @sql=@sql+' and DocDate>='+CONVERT(nvarchar,convert(float,@BudStartDate))+' and DocDate<'+CONVERT(nvarchar,convert(float,DATEadd("MONTH",6,@BudStartDate)))
			else if(@Mnt>=6 and @Mnt<12)
				set @sql=@sql+' and DocDate>='+CONVERT(nvarchar,convert(float,DATEadd(MONTH,6,@BudStartDate)))+' and DocDate<'+CONVERT(nvarchar,convert(float,DATEadd("YEAR",1,@BudStartDate)))
		END
		else if(@BudgType=2)
		BEGIN			
			if(@Mnt>=0 and @Mnt<3)
				set @sql=@sql+' and DocDate>='+CONVERT(nvarchar,convert(float,@BudStartDate))+' and DocDate<'+CONVERT(nvarchar,convert(float,DATEadd("MONTH",3,@BudStartDate)))
			else if(@Mnt>=3 and @Mnt<6)
				set @sql=@sql+' and DocDate>='+CONVERT(nvarchar,convert(float,DATEadd("MONTH",3,@BudStartDate)))+' and DocDate<'+CONVERT(nvarchar,convert(float,DATEadd("MONTH",6,@BudStartDate)))
			else if(@Mnt>=6 and @Mnt<9)
				set @sql=@sql+' and DocDate>='+CONVERT(nvarchar,convert(float,DATEadd("MONTH",6,@BudStartDate)))+' and DocDate<'+CONVERT(nvarchar,convert(float,DATEadd("MONTH",9,@BudStartDate)))
			else if(@Mnt>=9 and @Mnt<12)
				set @sql=@sql+' and DocDate>='+CONVERT(nvarchar,convert(float,DATEadd(MONTH,9,@BudStartDate)))+' and DocDate<'+CONVERT(nvarchar,convert(float,DATEadd("YEAR",1,@BudStartDate)))
		END		
		else if(@BudgType=3)
		BEGIN
			if(@CF='M')
				set @sql=@sql+' and DATEDIFF("M",'''+convert(nvarchar,@BudStartDate)+''',CONVERT(datetime,DocDate)) between 0 and '+CONVERT(nvarchar,(@Mnt-1))
			else	
				set @sql=@sql+' and DATEDIFF("M",'''+convert(nvarchar,@docdate)+''',CONVERT(datetime,DocDate))=0 '
		END
		
		if(@QtyType=1)
			set @sql=@sql+' and IsQtyFreeOffer>0'
		ELSE if(@QtyType=2)
			set @sql=@sql+' and IsQtyFreeOffer=0'
	
		
		exec sp_executeSQL @sql,N'@BudgetUsed float output',@BudgetUsed output

		if(@BudgetUsed>@AllocBudget)
		BEGIN
			if(@saveUnapp='true')
				return	2
			else			
				RAISERROR('-533',16,1)  	
		END	
	END	
		
		
          
SET NOCOUNT OFF;          
RETURN 1          
END TRY          
BEGIN CATCH            
	--Return exception info [Message,Number,ProcedureName,LineNumber]            
	IF ERROR_NUMBER()=50000          
	BEGIN        
		IF (ERROR_MESSAGE() LIKE '-533') 
		BEGIN
			if(@seq=0)
			BEGIN
				if(@Budget=1)
					SELECT replace(ErrorMessage,'##BudgetName##',@budName)  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
					FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber='-534' AND LanguageID=@LangID   
				ELSE   
					SELECT replace(replace(ErrorMessage,'Quantity','Value'),'##BudgetName##',@budName)  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
					FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber='-534' AND LanguageID=@LangID   
			END
			ELSE
			BEGIN	
				if(@Budget=1)  
					SELECT replace(ErrorMessage,'##BudgetName##',@budName)+CONVERT(nvarchar,(@seq-1))  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
					FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID 
				ELSE 
					SELECT replace(replace(ErrorMessage,'Quantity','Value'),'##BudgetName##',@budName)+CONVERT(nvarchar,(@seq-1))  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
					FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID 
			END       
		END
		else       
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) 
			WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID          
		END          
	ELSE          
	BEGIN          
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine          
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID          
	END          
ROLLBACK TRANSACTION          
SET NOCOUNT OFF            
RETURN -999             
END CATCH    
GO
