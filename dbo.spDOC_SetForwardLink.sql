USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetForwardLink]
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
		Declare @sql nvarchar(max),@Val nvarchar(max),@ActVal nvarchar(max),@VendorName nvarchar(max)
		
		select @linkedCostcenterid=Costcenterid from [INV_DocDetails] WITH(NOLOCK) where [InvDocDetailsID]=@LinkedInvDocDetailsID

		SELECT @DocumentLinkDefID=[DocumentLinkDefID]  FROM [COM_DocumentLinkDef] WITH(NOLOCK)    
		where [CostCenterIDBase]=@linkedCostcenterid and 
		[CostCenterIDLinked]  =@CostCenterID  

		declare @tab table(id INT identity(1,1),Srccol nvarchar(50), Descol nvarchar(50))   
		insert into @tab
		SELECT DisTINCT B.SysColumnName BASECOL,L.SysColumnName LINKCOL   FROM COM_DocumentLinkDetails A with(nolock)   
		JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.CostCenterColIDBase    
		left JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDLinked    
		WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
		and B.columndatatype=L.columndatatype
		set @i=0
		select @ctn=COUNT(id) from @tab
		while(@i<@ctn)
		BEGIN
			set @i=@i+1
			SELECT @Srccol=Srccol,@Descol=Descol from @tab where id=@i
			
			if(@Srccol not in('VoucherNo','RefNO','IsScheme','SKU'))
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
				set @sql=@sql+' with(nolock) where [InvDocDetailsID]='+convert(nvarchar,@LinkedInvDocDetailsID)
 				EXEC sp_executesql @sql,N'@Val nvarchar(max) OUTPUT',@Val output
			END
			if(@Descol not in('VoucherNo','RefNO','IsScheme','SKU'))
			BEGIN
				set @sql='select @ActVal='+@Descol +' from '
				if(@Descol like 'dcnum%')			 
					set @sql=@sql+' COM_DocNumData '			 
				ELSE if(@Descol like 'dcalpha%')
					set @sql=@sql+' [COM_DocTextData] ' 
				ELSE if(@Descol like 'dcccnid%' or @Descol in('ContactID','CustomerID'))
					set @sql=@sql+' [COM_DocCCData] '
				else
					set @sql=@sql+' INV_DocDetails '
				set @sql=@sql+' with(nolock) where [InvDocDetailsID]='+convert(nvarchar,@InvDocDetailsID)
	 
				EXEC sp_executesql @sql,N'@ActVal nvarchar(max) OUTPUT',@ActVal output
			END
			
			if(@Val<>@ActVal
				and @Srccol not in('VoucherNo','RefNO','IsScheme','SKU'))
			BEGIN
				 if exists(select [InvDocDetailsID] from [INV_DocDetails] WITH(NOLOCK) where [LinkedInvDocDetailsID]=@LinkedInvDocDetailsID)
			   BEGIN
					SELECT @VendorName = VoucherNo from [INV_DocDetails] WITH(NOLOCK) where [LinkedInvDocDetailsID]=@LinkedInvDocDetailsID  
					RAISERROR('-389',16,1)  
			   END
			   
				set @sql='update '
				if(@Srccol like 'dcnum%')			 
				set @sql=@sql+' COM_DocNumData '			 
				ELSE if(@Srccol like 'dcalpha%')
				set @sql=@sql+' [COM_DocTextData] ' 
				ELSE if(@Srccol like 'dcccnid%')
				set @sql=@sql+' [COM_DocCCData] '
				else
				set @sql=@sql+' INV_DocDetails '

				set @sql=@sql+' set '+@Srccol +'='''+@ActVal+''' where [InvDocDetailsID]='+convert(nvarchar,@LinkedInvDocDetailsID)
			 
				exec(@sql)
				
			END
			
			
		END
        
    
COMMIT TRANSACTION    
SET NOCOUNT OFF;
GO
