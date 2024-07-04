USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDocumentsBYProducts]
	@FromDate [datetime],
	@ToDate [datetime],
	@ProductIDs [nvarchar](max),
	@CustWhere [nvarchar](max),
	@Docs [nvarchar](max),
	@DeleteOldValues [bit],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
       
BEGIN TRY        
SET NOCOUNT ON;    
  
       declare @sql nvarchar(max),@dim int,@SortAvgRate  nvarchar(10),@AvgRateBasedOn  nvarchar(100)
       
       	select @SortAvgRate=Value from ADM_GlobalPreferences with(nolock)
		where Name='SortAvgRate'
		
		select @AvgRateBasedOn=Value from ADM_GlobalPreferences with(nolock)
		where Name='AvgRateBasedOn'
		
		if(@AvgRateBasedOn='DocDate,CreatedDate')
			set @AvgRateBasedOn='a.DocDate,a.CreatedDate'
		else if(@AvgRateBasedOn='CreatedDate')
			set @AvgRateBasedOn='a.CreatedDate,0 cd'
		else if(@AvgRateBasedOn='DocDate,ModifiedDate')
			set @AvgRateBasedOn='a.DocDate,a.ModifiedDate'		
		else if(@AvgRateBasedOn='ModifiedDate')
			set @AvgRateBasedOn='a.ModifiedDate,0 cd'

		set @sql=''
         if(@ProductIDs<>'')
			set @sql='
			declare @tab table (lft int,rgt int)
			insert into @tab
			select lft,rgt from inv_product
			where productid in('+@ProductIDs+')'
		
		set @sql=@sql+' select * from (select distinct DocID,CostCenterID,'
	
		if(@SortAvgRate='true')
			set @SQL=@SQL+@AvgRateBasedOn
		else
			set @SQL=@SQL+'DocDate,0 cd'
			
		set @SQL=@SQL+',VoucherType,VoucherNO,case when documenttype =5 THEN 1 else 0 end dt from INV_DocDetails a  WITH(NOLOCK)
		join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID  '
		
		
		if(@ProductIDs<>'')
			set @sql =@sql+' join inv_product p WITH(NOLOCK) on a.productid=p.productid 
			join @tab  t on   p.lft between t.lft and t.rgt '
		
		set @sql =@sql+' where vouchertype=-1 and isqtyignored=0  '+@CustWhere+'  and a.statusid=369
		and DocDate between '+convert(nvarchar,convert(float,@FromDate))+' and '+convert(nvarchar,convert(float,@ToDate))
		
			
		if(@Docs<>'')
		BEGIN
			set @sql=@sql+' UNION ALL select distinct DocID,CostCenterID,'
	
			if(@SortAvgRate='true')
				set @SQL=@SQL+@AvgRateBasedOn
			else
				set @SQL=@SQL+'DocDate,0 cd'
				
			set @SQL=@SQL+',VoucherType,VoucherNO,0 dt from INV_DocDetails a  WITH(NOLOCK)
			join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID '
			
		if(@ProductIDs<>'')
			set @sql =@sql+' join inv_product p WITH(NOLOCK) on a.productid=p.productid 
			join @tab  t on   p.lft between t.lft and t.rgt '
		 
			set @sql =@sql+'where CostCenterID in ('+@Docs+') and isqtyignored=0  '+@CustWhere+'  and a.statusid=369
			and DocDate between '+convert(nvarchar,convert(float,@FromDate))+' and '+convert(nvarchar,convert(float,@ToDate))
		
		END
		
		set @sql =@sql+' ) as t order by '
		set @AvgRateBasedOn=replace(@AvgRateBasedOn,'a.','')
		set @AvgRateBasedOn=replace(@AvgRateBasedOn,'d.','')

	    if(@SortAvgRate='true')
			set @SQL=@SQL+replace(@AvgRateBasedOn,',0 cd','')
		else
			set @SQL=@SQL+'DocDate'
			
		set @SQL=@SQL+',dt DESC,VoucherType DESC,VoucherNo'        

		
		print @sql
		exec(@sql)  
		
		if(@DeleteOldValues=1)
		BEGIN
		BEGIN TRANSACTION 
			set @sql=' delete from INV_ProductAvgRate '
			if(@ProductIDs<>'')
				set @sql =@sql+' where ProductID in('+@ProductIDs+')'
			exec(	@SQL)
		COMMIT TRANSACTION 
		END
         
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine      
 FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
 END      
ROLLBACK TRANSACTION      
SET NOCOUNT OFF        
RETURN -999         
END CATCH        
--SELECT * FROM ADM_FEATURES WHERE FEATUREID=40034
GO
