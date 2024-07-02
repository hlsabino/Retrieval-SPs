USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetAllUnPostedDepreciation]
	@IsUnPostScreen [bit],
	@FromDate [datetime],
	@Dpdate [datetime],
	@DivisionWhere [nvarchar](max) = NULL,
	@LocationWhere [nvarchar](max) = NULL,
	@Select [nvarchar](max),
	@Join [nvarchar](max),
	@Where [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	declare @SQL nvarchar(max)

	set @SQL = 'SELECT   dep.DPScheduleID ScheduleID,dep.AssetID,Acc.AssetCode as AssetCode,Acc.AssetName as Asset,  CONVERT(DATETIME, dep.DeprStartDate ) AS FromDate
	,CONVERT(DATETIME, dep.DeprEndDate ) AS ToDate, dep.PurchaseValue , dep.DepAmount AS DeprAmt , dep.AccDepreciation AS accmDepr 
	, dep.AssetNetValue AS NetValue,dep.DocID       ,dep.VoucherNo,convert(datetime,dep.DocDate) DocDate,
	Acc.DeprExpenseACCID as DebitAccount, Acc.AccumDeprACCID as CreditAccount 
	,convert(datetime,Acc.DeprStartDate) PutToUse'+@Select+'
	FROM [ACC_AssetDepSchedule] dep with(nolock)
	Join Acc_Assets Acc with(nolock) on dep.AssetID=Acc.AssetID
	join com_ccccdata cc with(nolock) on acc.assetid=cc.nodeid and cc.costcenterid=72
	'+@Join+'
	where CONVERT(DATETIME, dep.DeprEndDate ) between  '''+convert(nvarchar,@FromDate) +'''  and  '''+convert(nvarchar,@Dpdate) +''''

	if @IsUnPostScreen=1
		set @SQL=@SQL+' and dep.DocID is not null and dep.VoucherNo is not null'
	else
		set @SQL=@SQL+' and dep.DocID is null and dep.VoucherNo is null'

	if(@LocationWhere<>'')
		set @SQL=@SQL+' and acc.locationid in ('+@LocationWhere+')'
		
	if(@DivisionWhere<>'')
		set @SQL=@SQL+' and cc.ccnid1 in ('+@DivisionWhere+')'
		
	set @SQL=@SQL+@Where
	 
	if @IsUnPostScreen=1
		--set @SQL=@SQL+' order by FromDate,DocDate,VoucherNo,Acc.AssetName asc '
		set @SQL=@SQL+' order by FromDate,Acc.AssetName asc '
	else
		set @SQL=@SQL+' order by Acc.AssetName asc '
	print @SQL	
	exec(@SQL)

	SELECT Name,Value from  COM_CostCenterPreferences with(nolock) WHERE CostCenterID=72 

	select getdate() SystemDate

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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
