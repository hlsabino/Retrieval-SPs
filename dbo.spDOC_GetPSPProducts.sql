USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetPSPProducts]
	@mode [int],
	@DocID [int],
	@QohWhere [nvarchar](max),
	@CntFld [nvarchar](max),
	@DocDate [datetime],
	@StkCodeFld [nvarchar](max),
	@StkCodeTbl [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;

	declare @Sql nvarchar(max)
	
	if(@mode=0)
	BEGIN
		set @Sql='select distinct docid,Voucherno,Costcenterid
		from inv_docdetails D WITH(NOLOCK)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID   
		where statusid=443 and docid<>'+convert(nvarchar(10),@DocID)+@QohWhere
		exec(@Sql)
	END
	ELSE
	BEGIN
		
		if(@StkCodeFld<>'')
		BEGIN
			create table #tabPSPSTK(invid INT,PrdID INT,BatID INT,DID INT,StkCode INT)
	
			set @Sql='select d.invdocdetailsid,ProductID,BatchID,docid,'+@StkCodeFld+'
			from inv_docdetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID   
			where statusid=443 '+@QohWhere
			
			insert into #tabPSPSTK
			exec(@Sql)
			
			
			set @Sql='	select b.invdocdetailsid,b.ProductID,BatchID,docid,Voucherno,Unit,convert(datetime,DueDate) DueDate,ProductTypeID,Rate,ProductName,ProductCode
			,'+@CntFld+' cntfld,Quantity,UOMConversion,isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID=b.ProductID and DocDate<='+CONVERT(char,convert(float,@DocDate),2)+'
			and D.StatusID=369 AND IsQtyIgnored=0 '+@QohWhere+' and DCC.'+@StkCodeFld+'=a.StkCode and (VoucherType=1 or VoucherType=-1)),0) QOH 
			,a.StkCode,stk.Code
			from #tabPSPSTK a WITH(NOLOCK)
			join inv_docdetails b WITH(NOLOCK) on a.invid=b.invdocdetailsid
			join '+@StkCodeTbl+' stk WITH(NOLOCK) on a.StkCode=stk.Nodeid '
			
			if(@CntFld like 'dcnum%')
				set @Sql=@Sql+' join Com_docNumdata n WITH(NOLOCK) on n.invdocdetailsid=b.invdocdetailsid'
			else if(@CntFld like 'dcalpha%')
				set @Sql=@Sql+' join Com_doctextdata n WITH(NOLOCK) on n.invdocdetailsid=b.invdocdetailsid'
				
			set @Sql=@Sql+' join inv_product c WITH(NOLOCK) on c.ProductID=b.ProductID
			where DID<>'+convert(nvarchar(10),@DocID)+'
			union 
			select * from (select 0 inv,a.ProductID,0 b,0 d,NULL v,a.UOMID,'''+convert(nvarchar(max),@DocDate,113)+''' du,ProductTypeID,0 r,ProductName,ProductCode
			,0 cntfld,0 q,u.Conversion,isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID=a.ProductID and DocDate<='+CONVERT(char,convert(float,@DocDate),2)+'
			and D.StatusID=369 AND IsQtyIgnored=0 '+@QohWhere+'  and DCC.'+@StkCodeFld+'=stk.Nodeid and (VoucherType=1 or VoucherType=-1)),0) QOH 
			,stk.Nodeid,stk.Code
			from '+@StkCodeTbl+' stk WITH(NOLOCK)
			join inv_product a WITH(NOLOCK) on stk.ProductID=a.ProductID
			join com_UOM u WITH(NOLOCK) on u.UOMID=a.UOMID
			left join #tabPSPSTK b WITH(NOLOCK) on stk.Nodeid=b.StkCode
			where a.ProductID>0 and b.StkCode is null and stk.isgroup=0) as t
			where round(t.QOH,2)>0'
			print @Sql
			exec(@Sql)
			
		END
		ELSE
		BEGIN
		
			create table #tabPSP(invid INT,PrdID INT,BatID INT,DID INT)
			set @Sql='select d.invdocdetailsid,ProductID,BatchID,docid
			from inv_docdetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID   
			where statusid=443 '+@QohWhere
		 
			insert into #tabPSP
			exec(@Sql)
			
			
			set @Sql='	select b.invdocdetailsid,b.ProductID,BatchID,docid,Voucherno,Unit,convert(datetime,DueDate) DueDate,ProductTypeID,Rate,ProductName,ProductCode
			,'+@CntFld+' cntfld,Quantity,UOMConversion,isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID=b.ProductID and DocDate<='+CONVERT(char,convert(float,@DocDate),2)+'
			and D.StatusID=369 AND IsQtyIgnored=0 '+@QohWhere+' and (VoucherType=1 or VoucherType=-1)),0) QOH 

			from #tabPSP a WITH(NOLOCK)
			join inv_docdetails b WITH(NOLOCK) on a.invid=b.invdocdetailsid'
			
			if(@CntFld like 'dcnum%')
				set @Sql=@Sql+' join Com_docNumdata n WITH(NOLOCK) on n.invdocdetailsid=b.invdocdetailsid'
			else if(@CntFld like 'dcalpha%')
				set @Sql=@Sql+' join Com_doctextdata n WITH(NOLOCK) on n.invdocdetailsid=b.invdocdetailsid'
				
			set @Sql=@Sql+' join inv_product c WITH(NOLOCK) on c.ProductID=b.ProductID
			where DID<>'+convert(nvarchar(10),@DocID)+'
			union 
			select * from (select 0 inv,a.ProductID,0 b,0 d,NULL v,a.UOMID,NULL du,ProductTypeID,0 r,ProductName,ProductCode
			,0 cntfld,0 q,u.Conversion,isnull((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID=a.ProductID and DocDate<='+CONVERT(char,convert(float,@DocDate),2)+'
			and D.StatusID=369 AND IsQtyIgnored=0 '+@QohWhere+' and (VoucherType=1 or VoucherType=-1)),0) QOH 
			
			from inv_product a WITH(NOLOCK)
			join com_UOM u WITH(NOLOCK) on u.UOMID=a.UOMID
			left join #tabPSP b WITH(NOLOCK) on a.ProductID=b.PrdID
			where a.ProductID>0 and b.PrdID is null and isgroup=0) as t
			where round(t.QOH,2)>0'
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
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
