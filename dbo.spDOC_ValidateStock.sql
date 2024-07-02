USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_ValidateStock]
	@ProductID [bigint],
	@DocDate [datetime],
	@Qty [float],
	@Where [nvarchar](max),
	@HoldIssued [bit],
	@ExpecRcvd [bit],
	@unappinhold [bit] = 0,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION            
BEGIN TRY             
SET NOCOUNT ON; 

	declare @SQL nvarchar(max),@I int,@Cnt int,@ToTQty float,@dDate float,@vno nvarchar(max),@OldDate float,@HoldResCancelledDocs nvarchar(max)
	declare @tblList TABLE(ID int identity(1,1),DocDate Float,Vno nvarchar(max),Qty Float)
		  set @HoldResCancelledDocs =''
	  select @HoldResCancelledDocs=Value from Adm_globalPreferences WITH(NOLOCK) where Name='HoldResCancelledDocs'    

		set @SQL='SELECT DocDate,VoucherNo,ISNULL((UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
		INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
		WHERE D.ProductID='+convert(nvarchar,@ProductID)+' and D.StatusID=369  and DocDate>'+CONVERT(nvarchar,convert(float,@DocDate)) +' AND IsQtyIgnored=0 '+@WHERE
		+' and (VoucherType=1 or VoucherType=-1) order by DocDate,VoucherType desc'         
		
		print @SQL
		insert into @tblList
		Exec(@SQL)	
		
		set @I=0
		select @Cnt=COUNT(ID) from @tblList
		
		set  @SQL=''
		if (@HoldIssued=1)
		BEGIN
			set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
			 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
			 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
			 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
			 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID'
			 if(@unappinhold=1)
				set @SQL=@SQL+' in(371,441,369) '
			else
				set @SQL=@SQL+'=369 '	
			 
			 set @SQL=@SQL+' and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1
			 and D.DocDate>@@OldDate@@ and D.DocDate<=@@Date@@'+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
			
			 set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
			 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
			 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
			 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
			 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID'
			 if(@unappinhold=1)
				set @SQL=@SQL+' in(371,441,369) '
			else
				set @SQL=@SQL+'=369 '	
			 
			 set @SQL=@SQL+' and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 
			 and D.DocDate>@@OldDate@@ and D.DocDate<=@@Date@@'+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
		 END

	    if (@ExpecRcvd=1)
		BEGIN			 
			 set @SQL=@SQL+'set @TotQty=@TotQty+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
			 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
			 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
			 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
			 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1
			 and D.DocDate>@@OldDate@@ and D.DocDate<=@@Date@@'+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
		END
			
		WHILE(@I<@Cnt)        
		BEGIN    
		
			SET @I=@I+1   
			if(@I=1)  
				set @OldDate=convert(float,@DocDate)  
		    ElSE   
				set @OldDate=@dDate     			   
				
			select @dDate=DocDate ,@Qty=@Qty+Qty,@vno=Vno from @tblList Where ID=@I
			
			set @ToTQty=0
			
			if(@SQL<>'')
			BEGIN
			
				set @WHERE=replace(@SQL,'@@OldDate@@',CONVERT(nvarchar(max),@OldDate))  				
				set @WHERE=replace(@WHERE,'@@Date@@',CONVERT(nvarchar(max),@dDate))
				print @WHERE
				EXEC sp_executesql @WHERE, N'@TotQty float OUTPUT', @TotQty OUTPUT   				
				if(@ToTQty<>0)
					set @Qty=@Qty+@ToTQty
			END	
			
			if(@Qty<-0.001)
					RAISERROR('-407',16,1)
	
		END  
 

COMMIT TRANSACTION           
SET NOCOUNT OFF;          
RETURN 1          
END TRY          
BEGIN CATCH            
  --Return exception info [Message,Number,ProcedureName,LineNumber]            
  IF ERROR_NUMBER()=50000          
  BEGIN        
     IF (ERROR_MESSAGE() LIKE '-407') 
	BEGIN
		declare @ProductName nvarchar(max)
		select @ProductName=ProductName from inv_product where ProductID=@ProductID	          
	  SELECT ErrorMessage + @ProductName+'  '+@vno  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
	  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
   END
   else       
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
GO
