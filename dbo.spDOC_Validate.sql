USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_Validate]
	@InvDocXML [nvarchar](max),
	@DocID [int],
	@DocDate [datetime],
	@IsDel [bit],
	@ActivityXML [nvarchar](max),
	@docType [int],
	@ConsiderUnAppInHold [bit],
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION            
BEGIN TRY             
SET NOCOUNT ON; 

	declare @xml xml,@TRANSXML xml,@I int,@Cnt int,@InvDocDetailsID INT,@Dt float,@LinkedID INT,@TotLinkedQty float,@ToTValue float
	declare @tblList TABLE(ID int identity(1,1),TRANSXML NVARCHAR(MAX))
	declare @tab TABLE(ID int identity(1,1),DocDate float,qty float)
	declare @ProductID INT,@Qty FLOAT,@prevDate FLOAT, @prevQty  FLOAT ,@DetailIDs nvarchar(max),@iI INT,@cCnt   INT,@TotQty FLOAT
	declare @WHERE NVARCHAR(MAX),@PrefValue nvarchar(50),@NID INT,@sql NVARCHAR(MAX),@HoldRes float,@HoldResCancelledDocs nvarchar(max)
	declare @loc int,@div int,@dim int,@oldProdID INT,@isQtyUsed bit,@VoucherType int,@HRIssue nvarchar(50),@ExpRecd nvarchar(50)


	select @HRIssue=Value from ADM_GlobalPreferences with(nolock) where Name='ConsiderHoldAndReserveAsIssued'

	select @ExpRecd=Value from ADM_GlobalPreferences with(nolock) where Name='ConsiderExpectedAsReceived' 
	  set @HoldResCancelledDocs =''
	  select @HoldResCancelledDocs=Value from Adm_globalPreferences WITH(NOLOCK) where Name='HoldResCancelledDocs'    

	set @loc=0
	set @div=0
	set @dim=0
	
	set @PrefValue='' 
	select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='EnableLocationWise'        
	if(@PrefValue='True')
	begin         
		set @PrefValue=''      
		select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Location Stock'        
		if(@PrefValue='True')      
		begin      
			set @loc=1
		end       
	end   
	
	set @PrefValue='' 
	select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='EnableDivisionWise'        
	if(@PrefValue='True')
	begin         
		set @PrefValue=''      
		select @PrefValue= Value from ADM_GlobalPreferences with(nolock) where Name='Division Stock'        
		if(@PrefValue='True')      
		begin 
			set @div=1			  
		end       
	end  	     
           
	set @PrefValue=''      
	select @PrefValue= isnull(Value,'') from ADM_GlobalPreferences with(nolock) where Name='Maintain Dimensionwise stock'        

	if(@PrefValue is not null and @PrefValue<>'' and convert(INT,@PrefValue)>0)        
	begin     
	
		if(convert(INT,@PrefValue)=50001)
			set @div=1
		else if(convert(INT,@PrefValue)=50002)
			set @loc=1
		else if(convert(INT,@PrefValue)>50002)			
			set @dim=convert(INT,@PrefValue)-50000 
			       
	end        
           
		DECLARE @TblDeleteRows AS Table(IDent int identity(1,1),ID INT,DynamicType INT)
		
		if(@IsDel=1)
		BEGIN
			INSERT INTO @TblDeleteRows(ID,DynamicType)
			SELECT InvDocDetailsID,0 FROM INV_DocDetails WITH(NOLOCK)
			WHERE DocID=@DocID and VoucherType=1
		END
		ELSE
		BEGIN
			SET @XML=@ActivityXML   
			SELECT @DetailIDs=X.value('@DetailIds','nvarchar(max)')   
			from @XML.nodes('/XML') as Data(X)    
	    
			declare @tblIDsList table(Id INT)  
			insert into @tblIDsList  
			exec SPSplitString @DetailIDs,'~'

			INSERT INTO @TblDeleteRows(ID,DynamicType)
			SELECT InvDocDetailsID,0 FROM INV_DocDetails WITH(NOLOCK)
			WHERE DocID=@DocID and VoucherType=1 and (DynamicInvDocDetailsID is null or DynamicInvDocDetailsID=0)  
			AND InvDocDetailsID NOT IN (SELECT ID from @tblIDsList)
			
			INSERT INTO @TblDeleteRows(ID,DynamicType)
			SELECT InvDocDetailsID,1 FROM INV_DocDetails WITH(NOLOCK)    
			where DynamicInvDocDetailsID is not null and VoucherType=1 and DynamicInvDocDetailsID in(    
			select InvDocDetailsID FROM INV_DocDetails WITH(NOLOCK)      
			WHERE DocID =@DocID AND InvDocDetailsID NOT IN (SELECT ID from @tblIDsList))
			
		END

		SELECT @I=min(IDent), @Cnt=max(IDent) FROM @TblDeleteRows       

		WHILE(@I<=@Cnt)        
		BEGIN      
		    
			SELECT  @InvDocDetailsID=ID FROM @TblDeleteRows  WHERE IDent=@I        
			select @prevDate=DocDate, @ProductID=ProductID from [INV_DocDetails] WITH(NOLOCK) 
			WHERE InvDocDetailsID=@InvDocDetailsID
			
			set @WHERE=''
			if(@loc=1)
			BEGIN
				select @NID=dcCCNID2 from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID=@InvDocDetailsID        
				set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@NID)        
			END
			
			if(@div=1)
			BEGIN
				select @NID=dcCCNID1 from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID=@InvDocDetailsID        
				set @WHERE =' and dcCCNID1='+CONVERT(nvarchar,@NID)        
			END
			
			if(@dim>0)
			BEGIN
				set @sql='select @NID=dcCCNID'+CONVERT(nvarchar,@dim) +' from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
				set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,@dim)+'='+CONVERT(nvarchar,@NID)        
			END

			
			set @SQL='SELECT DocDate,ISNULL((UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID='+convert(nvarchar,@ProductID)+' and D.StatusID=369  and DocDate>='+CONVERT(nvarchar,@prevDate) +' AND IsQtyIgnored=0 '+@WHERE
			+' and D.InvDocDetailsID<>'+CONVERT(nvarchar,@InvDocDetailsID)+' and (VoucherType=1 or VoucherType=-1) order by DocDate ,VoucherType desc'         
			
			print @SQL
			
			delete from @tab
			insert into @tab
			exec(@SQL)
			SELECT @iI=min(ID), @cCnt=max(ID) FROM @tab       
			
			
			set @SQL='set @TotQty=(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
			INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
			WHERE D.ProductID='+convert(nvarchar,@ProductID) +' and D.StatusID=369 and DocDate<'+CONVERT(nvarchar,@prevDate)+' AND IsQtyIgnored=0 '+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
		    
		    if (@HRIssue='true')
			BEGIN
				set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
				 if(@HoldResCancelledDocs<>'')
					set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
					
				 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID'
				 
				 if (@ConsiderUnAppInHold=1)				 
					set @SQL=@SQL+' in(371,441,369) '
				else	
					set @SQL=@SQL+'=369 '
				 
				 set @SQL=@SQL+'  and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1
				 and D.DocDate<'+CONVERT(nvarchar,@prevDate) +@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
				
				 set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
				 if(@HoldResCancelledDocs<>'')
					set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
					
				 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID'
				 
				 if (@ConsiderUnAppInHold=1)				 
					set @SQL=@SQL+' in(371,441,369) '
				else	
					set @SQL=@SQL+'=369 '
				 
				 set @SQL=@SQL+' and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 
				 and D.DocDate<'+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
			 END

		    if (@ExpRecd='true')
			BEGIN			 
				 set @SQL=@SQL+'set @TotQty=@TotQty+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
				 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
				 if(@HoldResCancelledDocs<>'')
					set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
					
				 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
				 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
				 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
				 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1
				 and D.DocDate<'+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
			END
			
			EXEC sp_executesql @SQL, N'@TotQty float OUTPUT', @TotQty OUTPUT   
			
			if(@TotQty<-0.01)
					RAISERROR('-407',16,1)

			WHILE(@iI<=@cCnt)        
			BEGIN      			   
				select @prevDate=DocDate ,@prevQty=qty from @tab Where ID=@iI
				
				set @SQL=''
				set @HoldRes=0
				if (@HRIssue='true')
				BEGIN
					set @SQL=@SQL+'set @HoldRes=@HoldRes-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1
					 and D.DocDate='+CONVERT(nvarchar,@prevDate) +@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
					
					 set @SQL=@SQL+'set @HoldRes=@HoldRes-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 
					 and D.DocDate='+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
				 END

				if (@ExpRecd='true')
				BEGIN			 
					 set @SQL=@SQL+'set @HoldRes=@HoldRes+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when (l.IsQtyIgnored=0'
				 
					 if(@HoldResCancelledDocs<>'')
						set @SQL=@SQL+' or l.Costcenterid in('+@HoldResCancelledDocs+')'
						
					 set @SQL=@SQL+') then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1
					 and D.DocDate='+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
				END	
				
				if(@SQL<>'')
				BEGIN
					EXEC sp_executesql @SQL, N'@HoldRes float OUTPUT', @HoldRes OUTPUT   
					set @prevQty=@prevQty+@HoldRes
				END
				
				set @TotQty=@TotQty+@prevQty
				if(@TotQty<-0.01)
					RAISERROR('-407',16,1)

				SET @iI=@iI+1
			END 
		  	SET @I=@I+1    
	
		END  
 
 	declare @bb nvarchar(max)
	set @bb=convert(varchar,CHAR(17))

	insert into @tblList  
	exec SPSplitString @InvDocXML,@bb
	SELECT @I=min(ID), @Cnt=max(ID) FROM @tblList       
 
WHILE(@I<=@Cnt)        
BEGIN      
    
	SELECT  @xml=CONVERT(NVARCHAR(MAX),TRANSXML) FROM @tblList  WHERE ID=@I        
  
    SELECT @TRANSXML=CONVERT(NVARCHAR(MAX), X.query('Transactions'))
	from @xml.nodes('/Row') as Data(X) 
	
	set @VoucherType=0
	
    SELECT @InvDocDetailsID=X.value('@DocDetailsID','INT'),@ProductID=X.value('@ProductID','INT')    
	 ,@Qty=X.value('@UOMConvertedQty','FLOAT') from @TRANSXML.nodes('/Transactions') as Data(X)      
	 
	if(@docType=30 or @docType=5)
		select @VoucherType=X.value('@VoucherType','int')  from @TRANSXML.nodes('/Transactions') as Data(X)      
	else
		set @VoucherType=1
		
	if(@InvDocDetailsID>0 and @VoucherType=1)
	BEGIN
		select @prevDate=DocDate, @prevQty=UOMConvertedQty,@oldProdID=ProductID from [INV_DocDetails] WITH(NOLOCK) 
		WHERE InvDocDetailsID=@InvDocDetailsID
		
		if(@oldProdID<>@ProductID)
		BEGIN      
				set @ProductID=@oldProdID
				
				set @WHERE=''
				if(@loc=1)
				BEGIN
					select @NID=dcCCNID2 from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID=@InvDocDetailsID        
					set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@NID)        
				END
				
				if(@div=1)
				BEGIN
					select @NID=dcCCNID1 from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID=@InvDocDetailsID        
					set @WHERE =' and dcCCNID1='+CONVERT(nvarchar,@NID)        
				END
				
				if(@dim>0)
				BEGIN
					set @sql='select @NID=dcCCNID'+CONVERT(NVARCHAR,@dim )+' from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
				
					EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
					set @WHERE =@WHERE+' and dcCCNID'+CONVERT(NVARCHAR,@dim)+'='+CONVERT(nvarchar,@NID)        
				END

				
				set @SQL='SELECT DocDate,ISNULL((UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
				INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
				WHERE D.ProductID='+convert(nvarchar,@ProductID)+' and D.StatusID=369  and DocDate>='+CONVERT(nvarchar,@prevDate) +' AND IsQtyIgnored=0 '+@WHERE
				+' and D.InvDocDetailsID<>'+CONVERT(nvarchar,@InvDocDetailsID)+' and (VoucherType=1 or VoucherType=-1) order by DocDate ,VoucherType desc'         
				
				print @SQL
				
				delete from @tab
				insert into @tab
				exec(@SQL)
				SELECT @iI=min(ID), @cCnt=max(ID) FROM @tab       
				
				
				set @SQL='set @TotQty=(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
				INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
				WHERE D.ProductID='+convert(nvarchar,@ProductID) +' and D.StatusID=369  and DocDate<'+CONVERT(nvarchar,@prevDate)+' AND IsQtyIgnored=0 '+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
			    
			    if (@HRIssue='true')
				BEGIN
					set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1
					 and D.DocDate<'+CONVERT(nvarchar,@prevDate) +@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
					
					 set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 
					 and D.DocDate<'+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
				 END

				if (@ExpRecd='true')
				BEGIN			 
					 set @SQL=@SQL+'set @TotQty=@TotQty+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1
					 and D.DocDate<'+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
				END  
				
				EXEC sp_executesql @SQL, N'@TotQty float OUTPUT', @TotQty OUTPUT   
				
				if(@TotQty<-0.01)
						RAISERROR('-407',16,1)

				WHILE(@iI<=@cCnt)        
				BEGIN      			   
					select @prevDate=DocDate ,@prevQty=qty from @tab Where ID=@iI
					
					set @SQL=''
					set @HoldRes=0
					if (@HRIssue='true')
					BEGIN
						set @SQL=@SQL+'set @HoldRes=@HoldRes-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
						 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
						 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
						 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
						 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1
						 and D.DocDate='+CONVERT(nvarchar,@prevDate) +@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
						
						 set @SQL=@SQL+'set @HoldRes=@HoldRes-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
						 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
						 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
						 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
						 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 
						 and D.DocDate='+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
					 END

					if (@ExpRecd='true')
					BEGIN			 
						 set @SQL=@SQL+'set @HoldRes=@HoldRes+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
						 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
						 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
						 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
						 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1
						 and D.DocDate='+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
					END	
					
					if(@SQL<>'')
					BEGIN
						EXEC sp_executesql @SQL, N'@HoldRes float OUTPUT', @HoldRes OUTPUT   
						set @prevQty=@prevQty+@HoldRes
					END	
					
					set @TotQty=@TotQty+@prevQty
					if(@TotQty<-0.01)
						RAISERROR('-407',16,1)

					SET @iI=@iI+1
				END 
		END
		Else if(@prevDate<CONVERT(float,@DocDate) or @Qty<@prevQty)
		BEGIN
			set @WHERE=''
			if(@loc=1)
			BEGIN
				select @NID=dcCCNID2 from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID=@InvDocDetailsID        
				set @WHERE =' and dcCCNID2='+CONVERT(nvarchar,@NID)        
			END
			
			if(@div=1)
			BEGIN
				select @NID=dcCCNID1 from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID=@InvDocDetailsID        
				set @WHERE =' and dcCCNID1='+CONVERT(nvarchar,@NID)        
			END
			
			if(@dim>0)
			BEGIN
				set @sql='select @NID=dcCCNID'+CONVERT(nvarchar,@dim) +' from COM_DocCCData WITH(NOLOCK) where InvDocDetailsID='+CONVERT(nvarchar,@InvDocDetailsID)
			
				EXEC sp_executesql @sql,N'@NID INT OUTPUT',@NID output		 
				set @WHERE =@WHERE+' and dcCCNID'+CONVERT(nvarchar,@dim)+'='+CONVERT(nvarchar,@NID)        
			END
			
			if(@Qty=@prevQty and @prevDate<CONVERT(float,@DocDate))
			BEGIN
				set @SQL='set @TotQty=(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
				INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
				WHERE D.ProductID='+convert(nvarchar,@ProductID)+' and D.StatusID=369  and D.InvDocDetailsID<>'+CONVERT(nvarchar,@InvDocDetailsID) +' and DocDate<'+CONVERT(nvarchar,CONVERT(float,@DocDate))+' AND IsQtyIgnored=0 '+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
			    
			    if (@HRIssue='true')
				BEGIN
					set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1
					 and D.DocDate<'+CONVERT(nvarchar,CONVERT(float,@DocDate)) +@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
					
					 set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 
					 and D.DocDate<'+CONVERT(nvarchar,CONVERT(float,@DocDate))+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
				 END

				if (@ExpRecd='true')
				BEGIN			 
					 set @SQL=@SQL+'set @TotQty=@TotQty+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1
					 and D.DocDate<'+CONVERT(nvarchar,CONVERT(float,@DocDate))+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
				END  
  
				EXEC sp_executesql @SQL, N'@TotQty float OUTPUT', @TotQty OUTPUT   

				if(@TotQty<-0.01)
					RAISERROR('-407',16,1)
			END
			ELSE
			BEGIN
				 		
				set @SQL='SELECT DocDate,ISNULL((UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
				INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
				WHERE D.ProductID='+convert(nvarchar,@ProductID)+' and D.StatusID=369  and DocDate>='+CONVERT(nvarchar,@prevDate) +' AND IsQtyIgnored=0 '+@WHERE
				+' and D.InvDocDetailsID<>'+CONVERT(nvarchar,@InvDocDetailsID)+' and (VoucherType=1 or VoucherType=-1) order by DocDate ,VoucherType desc'         
		
				delete from @tab
				insert into @tab
				exec(@SQL)
				SELECT @iI=min(ID), @cCnt=max(ID) FROM @tab       
				
				
				set @SQL='set @TotQty=(SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails D WITH(NOLOCK)
				INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID        
				WHERE D.ProductID='+convert(nvarchar,@ProductID) +' and D.StatusID=369  and DocDate<'+CONVERT(nvarchar,@prevDate)+' AND IsQtyIgnored=0 '+@WHERE+' and (VoucherType=1 or VoucherType=-1) )'         
			    
			    if (@HRIssue='true')
				BEGIN
					set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1
					 and D.DocDate<'+CONVERT(nvarchar,@prevDate) +@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
					
					 set @SQL=@SQL+'set @TotQty=@TotQty-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 
					 and D.DocDate<'+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
				 END

				if (@ExpRecd='true')
				BEGIN			 
					 set @SQL=@SQL+'set @TotQty=@TotQty+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
					 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
					 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
					 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
					 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1
					 and D.DocDate<'+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
				END  
  
				EXEC sp_executesql @SQL, N'@TotQty float OUTPUT', @TotQty OUTPUT   
				
				set @isQtyUsed=0
				WHILE(@iI<=@cCnt)        
				BEGIN      			   
					select @prevDate=DocDate ,@prevQty=qty from @tab Where ID=@iI
					if(@prevDate>=CONVERT(float,@DocDate) and @isQtyUsed=0)
					BEGIN
						set @prevQty=@prevQty+@Qty
						set @isQtyUsed=1
					END
					
					set @SQL=''
					set @HoldRes=0
					if (@HRIssue='true')
					BEGIN
						set @SQL=@SQL+'set @HoldRes=@HoldRes-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
						 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
						 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
						 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
						 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1
						 and D.DocDate='+CONVERT(nvarchar,@prevDate) +@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
						
						 set @SQL=@SQL+'set @HoldRes=@HoldRes-(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
						 (SELECT D.ReserveQuantity HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
						 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
						 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
						 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 
						 and D.DocDate='+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp )'				 
					 END

					if (@ExpRecd='true')
					BEGIN			 
						 set @SQL=@SQL+'set @HoldRes=@HoldRes+(select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from
						 (SELECT D.HoldQuantity,isnull(sum(case when l.IsQtyIgnored=0 then l.UOMConvertedQty else l.ReserveQuantity end),0) release  
						 FROM INV_DocDetails D WITH(NOLOCK) INNER JOIN COM_DocCCData DCC WITH(NOLOCK) ON DCC.InvDocDetailsID=D.InvDocDetailsID
						 left join INV_DocDetails l WITH(NOLOCK) on d.InvDocDetailsID=l.LinkedInvDocDetailsID 
						 WHERE D.ProductID='+convert(nvarchar,@ProductID) +' AND D.IsQtyIgnored=1 and D.StatusID=369 and D.DocumentType in (1,2,4,10,25,26,27) and D.VoucherType=1
						 and D.DocDate='+CONVERT(nvarchar,@prevDate)+@WHERE+' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp )'
					END	
					
					if(@SQL<>'')
					BEGIN
						EXEC sp_executesql @SQL, N'@HoldRes float OUTPUT', @HoldRes OUTPUT   
						set @prevQty=@prevQty+@HoldRes
					END		
					
					set @TotQty=@TotQty+@prevQty
					
					if(@TotQty<-0.01)
						RAISERROR('-407',16,1)

					SET @iI=@iI+1
				END 
			END
	   
	   END
    END
   	SET @I=@I+1    

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
	  SELECT ErrorMessage + @ProductName  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
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
