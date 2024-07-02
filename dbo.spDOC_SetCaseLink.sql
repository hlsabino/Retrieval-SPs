USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetCaseLink]
	@InvDocDetailsID [bigint],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    

SET NOCOUNT ON    
		Declare @Costcenterid bigint,@DocumentLinkDefID bigint,@Srccol nvarchar(50),@Descol nvarchar(50),@i int,@ctn int
		Declare @sql nvarchar(max),@Val nvarchar(max),@ActVal nvarchar(max),@VendorName nvarchar(max)
		
		select @Costcenterid=Costcenterid from [INV_DocDetails] with(nolock) where [InvDocDetailsID]=@InvDocDetailsID

		SELECT @DocumentLinkDefID=[DocumentLinkDefID]  FROM [COM_DocumentLinkDef] with(nolock)
		where [CostCenterIDBase]=73 and 
		[CostCenterIDLinked]  =@Costcenterid  

		declare @tab table(id bigint identity(1,1),Srccol nvarchar(50), Descol nvarchar(50))   
		insert into @tab
		SELECT DisTINCT B.SysColumnName BASECOL,L.SysColumnName LINKCOL   FROM COM_DocumentLinkDetails A  with(nolock)
		JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.CostCenterColIDBase    
		left JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDLinked    
		WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
		
 		set @i=0
		select @ctn=COUNT(id) from @tab
		while(@i<@ctn)
		BEGIN
			set @i=@i+1
			SELECT @Descol=Srccol,@Srccol=Descol from @tab where id=@i
			
			if(@Srccol not in('VoucherNo','RefNO'))
			BEGIN
				set @sql='select @Val='+@Srccol +' from '
				if(@Srccol like 'dcnum%')			 
					set @sql=@sql+' COM_DocNumData with(nolock) '			 
				ELSE if(@Srccol like 'dcalpha%')
					set @sql=@sql+' [COM_DocTextData] with(nolock) ' 
				ELSE if(@Srccol like 'dcccnid%' or @Srccol='CustomerID')
					set @sql=@sql+' [COM_DocCCData] with(nolock) '
				else
					set @sql=@sql+' INV_DocDetails with(nolock) '
				set @sql=@sql+' where [InvDocDetailsID]='+convert(nvarchar,@InvDocDetailsID)
 				EXEC sp_executesql @sql,N'@Val nvarchar(max) OUTPUT',@Val output
			END
			
				if(@Descol like 'acAlpha%')			 
					set @sql='update CRM_CasesExtended  set '+@Descol +' = '''+replace(@Val,'''','''''')
					+''' WHERE CaseID in (select CaseID from CRM_Cases where ContractLineID='+convert(nvarchar,@InvDocDetailsID)+')'
				ELSE if(@Descol like 'CCNID%')
					set @sql='update COM_CCCCDATA  set '+@Descol +' = '+@Val
					+' where CostCenterID =73 and NodeID in (select CaseID from CRM_Cases with(nolock) where ContractLineID='+convert(nvarchar,@InvDocDetailsID)+')'
				ELSE 
					set @sql='update [CRM_Cases]  set '+@Descol +' = '''+@Val+ '''where ContractLineID='+convert(nvarchar,@InvDocDetailsID)
 				EXEC ( @sql)
		END
        
    
COMMIT TRANSACTION    
SET NOCOUNT OFF;    
GO
