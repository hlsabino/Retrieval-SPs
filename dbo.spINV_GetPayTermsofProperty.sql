USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetPayTermsofProperty]
	@Mode [int],
	@where [nvarchar](max),
	@Cols [nvarchar](max),
	@Join [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY           
SET NOCOUNT ON    
  
 declare @Sql nvarchar(max),@dim int,@table nvarchar(50)
 if(@Mode=1)
 BEGIN
	select @dim=value from adm_globalpreferences WITH(NOLOCK)
	where name='PaytermLinkDim' and value is not null 
	and isnumeric(value)=1 and value<>''
	if(@dim>0)
		select @table=TableName from ADM_Features WITH(NOLOCK) where FeatureID= @dim

	set @Sql='select distinct pd.ProfileID,pd.ProfileName ,t.Name
	,p.DimNodeID,p.Period,p.BasedOn,convert(datetime,p.BaseDate) Basedate,p.days
	from INV_DocDetails a WITH(NOLOCK)  
	join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID  
	join COM_DocPayTerms p  WITH(NOLOCK) on a.VoucherNo=p.VoucherNo  '
	if(@dim>0)
		set @Sql=@Sql+' join '+@table+' t on p.DimNodeID=t.Nodeid '
	
	set @Sql=@Sql+' join Acc_PaymentDiscountProfile pd WITH(NOLOCK)  on p.ProfileID=pd.ProfileID  
	where p.BasedOn=2 '+@where
	
 END
 ELSE if(@Mode=2)
 BEGIN
	 set @Sql='select distinct  a.CostCenterID,a.DocID,a.VoucherNo VNO,a.DocPrefix,a.DocNumber'  
	 set @Sql=@Sql+@Cols  
	 set @Sql=@Sql+' from INV_DocDetails a WITH(NOLOCK)  
	 join COM_DocCCData c WITH(NOLOCK) on a.InvDocDetailsID=c.InvDocDetailsID  
	 join COM_DocNumData n WITH(NOLOCK) on a.InvDocDetailsID=n.InvDocDetailsID  
	 join COM_DocTextData t WITH(NOLOCK) on a.InvDocDetailsID=t.InvDocDetailsID
	 join COM_DocPayTerms p  WITH(NOLOCK) on a.VoucherNo=p.VoucherNo '  
	 set @Sql=@Sql+@Join  
	 set @Sql=@Sql+@where
 END
 ELSE if(@Mode=3)
 BEGIN
	select @dim=value from adm_globalpreferences WITH(NOLOCK)
	where name='PaytermLinkDim' and value is not null 
	and isnumeric(value)=1 and value<>''
	if(@dim>0)
		select @table=TableName from ADM_Features WITH(NOLOCK) where FeatureID= @dim
	set @Sql='select percentage,[Days],Discount,Period,TypeID,BasedOn,Occurences
	,DateNo,Remarks,Remarks1,DimNodeID'
	if(@dim>0)
		set @Sql=@Sql+',t.name'
		
		set @Sql=@Sql+'
	from  Acc_PaymentDiscountTerms pd WITH(NOLOCK) '
	if(@dim>0)
		set @Sql=@Sql+' join '+@table+' t on pd.DimNodeID=t.Nodeid'
	
	set @Sql=@Sql+'where  ProfileID='+@where
 END	 
 print @Sql
 exec(@Sql)  
   
Return 1   
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS            
ErrorLine          
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID          
 END          
SET NOCOUNT OFF            
RETURN -999             
END CATCH
GO
