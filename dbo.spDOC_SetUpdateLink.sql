USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetUpdateLink]
	@LinkedInvDocDetailsID [int],
	@InvDocDetailsID [int],
	@CostCenterID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
         
SET NOCOUNT ON    


		Declare @linkedCostcenterid INT,@DocumentLinkDefID INT,@Srccol nvarchar(50),@Descol nvarchar(50),@i int,@ctn int
		Declare @sql nvarchar(max),@Val nvarchar(max),@ActVal nvarchar(max),@VendorName nvarchar(max),@Qty Float,@linkQTY float
		
		select @linkedCostcenterid=Costcenterid from [INV_DocDetails] with(nolock) where [InvDocDetailsID]=@LinkedInvDocDetailsID

		SELECT @DocumentLinkDefID=[DocumentLinkDefID]  FROM [COM_DocumentLinkDef] with(nolock)    
		where [CostCenterIDBase]=@CostCenterID and 
		[CostCenterIDLinked]  =@linkedCostcenterid  

		declare @tab table(id INT identity(1,1),Srccol nvarchar(50), Descol nvarchar(50))   
		insert into @tab
		SELECT DisTINCT B.SysColumnName BASECOL,L.SysColumnName LINKCOL   FROM COM_DocumentLinkDetails A with(nolock)   
		JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.CostCenterColIDBase    
		left JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDLinked    
		WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
		and B.columndatatype=L.columndatatype and UpdateSource=1
		
		set @i=0
		select @ctn=COUNT(id) from @tab
		while(@i<@ctn)
		BEGIN
			set @i=@i+1
			SELECT @Srccol=Srccol,@Descol=Descol from @tab where id=@i
			
			if(@Srccol not in('VoucherNo','RefNO','IsScheme','SKU','') and @Descol not in('VoucherNo','RefNO','IsScheme','SKU'))
			BEGIN
				set @sql='select @Val='+@Srccol +' from '
				if(@Srccol like 'dcnum%')			 
					set @sql=@sql+' COM_DocNumData '			 
				ELSE if(@Srccol like 'dcalpha%')
					set @sql=@sql+' [COM_DocTextData] ' 
				ELSE if(@Srccol like 'dcccnid%' or @Srccol in('ContactID','CustomerID'))
					set @sql=@sql+' [COM_DocCCData] '
				else
					set @sql=@sql+' INV_DocDetails '
				set @sql=@sql+' with(nolock) where [InvDocDetailsID]='+convert(nvarchar,@InvDocDetailsID)
 				EXEC sp_executesql @sql,N'@Val nvarchar(max) OUTPUT',@Val output
			 
			    SET @Val=REPLACE(@Val,'''','''''')
				set @sql='update '
				if(@Descol like 'dcnum%')			 
					set @sql=@sql+' COM_DocNumData '			 
				ELSE if(@Descol like 'dcalpha%')
					set @sql=@sql+' [COM_DocTextData] ' 
				ELSE if(@Descol like 'dcccnid%' or @Descol in('ContactID','CustomerID'))
					set @sql=@sql+' [COM_DocCCData] '
				else
					set @sql=@sql+' INV_DocDetails '

				set @sql=@sql+' set '+@Descol +'='''+@Val+''' where [InvDocDetailsID]='+convert(nvarchar,@LinkedInvDocDetailsID)
			 
				exec(@sql)
				
			END
			
			
		END
		
		delete from @tab
		
		insert into @tab
		select SrcDoc,Fld from COM_DocLinkCloseDetails WITH(NOLOCK)
		where CostCenterID=@CostCenterID and linkedfrom=@linkedCostcenterid
		
		
		select @i=min(id) ,@ctn=max(id) from @tab
		while(@i<=@ctn)
		BEGIN
			SELECT @Srccol=Srccol,@Descol=Descol from @tab where id=@i
			
			if(ISNUMERIC(@Srccol)=1 and  @Descol like 'dcalpha%')
			BEGIN
				set @SQL='SELECT @Val='+@Descol+' from COM_DocTextData WITH(NOLOCK) where InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)				
				exec sp_executesql @SQL,N'@Val nvarchar(max) output',@Val output
				
				set @SQL='SELECT @Qty=isnull(Quantity,0) from INV_DocDetails a WITH(NOLOCK)
					join COM_DocTextData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID 
					where costcenterid='+@Srccol+' and '+@Descol+'='''+@Val+''''
						
				exec sp_executesql @SQL,N'@Qty float output',@Qty output
				
				set @SQL='SELECT @linkQTY=isnull(sum(Quantity),0) from INV_DocDetails a WITH(NOLOCK)
					join COM_DocTextData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID 
					where costcenterid='+convert(nvarchar,@CostCenterID)+' and '+@Descol+'='''+@Val+''''
							
				exec sp_executesql @SQL,N'@linkQTY float output',@linkQTY output
					
				if(@linkQTY>=@Qty and @Val is not null and @Val<>'')
				BEGIN
					set @SQL='update INV_DocDetails
					set LinkStatusID=445
					from COM_DocTextData b WITH(NOLOCK) 					
					where INV_DocDetails.InvDocDetailsID=b.InvDocDetailsID and INV_DocDetails.CostCenterID<>'+convert(nvarchar,@CostCenterID)+'
					 and '+@Descol+'='''+@Val+''''
					
					EXEC(@SQL)
				END
			END
			set @i=@i+1
        END
    
COMMIT TRANSACTION    
SET NOCOUNT OFF;
GO
