USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetOrderData]
	@Type [int],
	@CustomerID [int],
	@CCID [bigint],
	@DocID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

	declare @sql nvarchar(max),@TblName nvarchar(max),@statdim int,@Join nvarchar(max)

	if @Type=1
	begin
		select @statdim=value from adm_globalpreferences where Name='OnlineStatDim' and value is not null and isnumeric(value)=1
		set @TblName=''
		if(@statdim>50000)
		begin
			select @TblName=' join '+TableName+' SD with(nolock) on SD.NodeID=DCC.dcCCNID'+convert(nvarchar,FeatureID-50000)
			from adm_features with(nolock) where FeatureID=@statdim
		end
		 
		set @sql='select D.DocID,D.VoucherNo,convert(datetime,D.DocDate) DocDate,sum(Quantity) Quantity,sum(Gross) Amount'
		if @TblName is not null 
			set @sql=@sql+',SD.Name Status'
		else
			set @sql=@sql+','''' Status'
		set @sql=@sql+'
		from INV_Docdetails D with(nolock)
		join COM_DocCCDATA DCC with(nolock)on D.InvDocDetailsID=DCC.InvDocDetailsID
		'+@TblName+'
		where D.CostCenterID='+convert(nvarchar,@CCID)+' and DCC.CustomerID='+convert(nvarchar,@CustomerID)+'
		group by D.DocID,D.VoucherNo,D.DocDate'
		if @TblName is not null
			set @sql=@sql+',SD.Name'
		set @sql=@sql+' order by D.DocDate desc,D.VoucherNo desc'
		
			
		--print @sql
		exec(@sql)

		--select name,value from adm_globalpreferences WITH(NOLOCK)
		--where name in('OnlineProfile','MandOnlineLogin','OnlineLevel1Dim','OnlineSearchFields','OnlineLevel2Dim','OnlineOrderDoc','OnlineRecptDoc','DecimalsinAmount','Date Format',
		--'OnlineLogo','OnlineStatDim','OnlinePaymodes','OnlineRefNoFld','OnlinePaymodeFld')
		--select CurrencyID,Symbol,Name from COM_Currency WITH(NOLOCK) where CurrencyID=1
	end
	else if(@Type=2)
	begin
		select @statdim=value from adm_globalpreferences where Name='OnlineStatDim' and value is not null and isnumeric(value)=1
		set @TblName=''
		if(@statdim>50000)
		begin
			select @TblName=TableName
			,@Join=' join '+TableName+' SD with(nolock) on SD.NodeID=DCC.dcCCNID'+convert(nvarchar,FeatureID-50000)
			from adm_features with(nolock) where FeatureID=@statdim
		end
		else
			set @statdim=0
		 
		set @sql='
		declare @DocID bigint
		set @DocID='+convert(nvarchar,@DocID)+'
		select D.VoucherNo,convert(datetime,D.DocDate) DocDate,P.ProductID,P.ProductName,Quantity,Rate,Gross,StockValue
		,(select top 1 GUID+''.''+FileExtension from com_Files F with(nolock) where F.FeatureID=3 and FeaturePK=P.ProductID and IsProductImage=1 order by IsDefaultImage desc) ImgPath'
		if @TblName is not null 
			set @sql=@sql+',SD.Name Status'
		else
			set @sql=@sql+','''' Status'
		
		select @sql=@sql+',txt.'+value+' Paymode' from adm_globalpreferences WITH(NOLOCK) where name='OnlinePaymodeFld'
		select @sql=@sql+',txt.'+value+'  PaymentRefNo' from adm_globalpreferences WITH(NOLOCK) where name='OnlineRefNoFld'
		
		set @sql=@sql+' from INV_Docdetails D with(nolock)
		join INV_Product P with(nolock) on D.ProductID=P.ProductID
		join COM_DocCCDATA DCC with(nolock)on D.InvDocDetailsID=DCC.InvDocDetailsID
		join COM_DocTextDATA TXT with(nolock)on D.InvDocDetailsID=TXT.InvDocDetailsID
		'+@Join+'
		where DCC.CustomerID='+convert(nvarchar,@CustomerID)+' and D.DocID=@DocID
		order by D.DocSeqNo
--D.CostCenterID=@CCID and 
	
		select DA.AddressTypeID,A.AddressName,A.ContactPerson,A.Address1,A.Address2,A.Address3,City,State,Zip,Country,Phone1,Email1
		from COM_DocAddressData DA with(nolock) 
		join COM_Address A with(nolock) on A.AddressID=DA.AddressID
		where docid=@DocID
		'
		
		if @TblName is not null
			set @sql=@sql+' select SD.Name,H.Remarks,convert(datetime,H.FromDate) FromDate,convert(datetime,H.CreatedDate) CreatedDate from COM_HistoryDetails H with(nolock)
		join '+@TblName+' SD with(nolock) on H.HistoryNodeID=SD.NodeID
		where H.NodeID=@DocID and H.HistoryCCID='+convert(nvarchar,@statdim)+' and H.CostCenterID>40000 and H.CostCenterID<50000
		order by H.HistoryID
		'
		else
			set @sql=@sql+' select 1 Hist_NoStatusDim where 1!=1'
		print(@sql)
		exec(@sql)
	
	end

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
