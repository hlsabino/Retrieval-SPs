USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetAssetTransfer]
	@CostCenterID [int],
	@DocID [bigint],
	@InvDocDetailsID [bigint]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @Dt float,@SQL nvarchar(max)

SET @Dt=CONVERT(FLOAT,GETDATE())

declare @txtShiftDate nvarchar(20),@AssDimID int,@LocationDimID int,@CNT INT,@FromInvDetailsID int,@TransferSrc int,@TransferDim int
select @txtShiftDate=PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and PrefName='AssetShiftDate'
select @TransferSrc=PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and PrefName='DimTransferSrc'
select @TransferDim=PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and PrefName='DimTransferDim'
	
if @TransferSrc=72
begin
	set @AssDimID=isnull((select convert(int,value) from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='AssetDimension' and isnumeric(value)=1),0)
	set @LocationDimID=isnull((select convert(int,value) from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='AssetLocationDim' and isnumeric(value)=1),0)
end
	
select @FromInvDetailsID=InvDocDetailsID from inv_docdetails with(nolock) where DocID=@DocID and VoucherType=-1	and DocSeqNo IN (select DocSeqNo from inv_docdetails INVTO with(nolock) where InvDocDetailsID=@InvDocDetailsID)

IF @TransferSrc=72
BEGIN
	declare @FromLoc bigint,@ToLoc bigint,@ShiftDate datetime,@iShiftDate float,@AssetID bigint,@CrossDrAcc bigint,@CrossCrAcc bigint,@PrevLocationStartDate float,@PostAccounting bit
	
	set @PostAccounting=isnull((select 1 from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='PostAccountingWhileTransfer' and value='True'),0)

	--To set variables
	set @SQL='select @AssetID=A.AssetID,@ShiftDate=convert(DATETIME,TXT.'+@txtShiftDate+'),@ToLoc=dcCCNID'+convert(nvarchar,@LocationDimID-50000)+' from COM_DocCCData DCC with(nolock)
inner join COM_DocTextData TXT with(nolock) ON TXT.InvDocDetailsID=DCC.InvDocDetailsID
inner join ACC_Assets A with(nolock) ON A.CCNodeID=DCC.dcCCNID'+convert(nvarchar,@AssDimID-50000)+'
where DCC.InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)	
	EXEC sp_executesql @SQL,N'@AssetID bigint OUTPUT,@ShiftDate datetime OUTPUT,@ToLoc bigint OUTPUT,@FromLoc bigint OUTPUT',@AssetID OUTPUT,@ShiftDate OUTPUT,@ToLoc OUTPUT,@FromLoc OUTPUT
	set @iShiftDate=convert(float,@ShiftDate)
	select @FromLoc=A.LocationID from ACC_Assets A with(nolock) where A.AssetID=@AssetID
	
	--select top 1 @PrevLocationStartDate=DP.FromDate from COM_HistoryDetails DP with(nolock)
	--where DP.CostCenterID=72 and DP.NodeID=@AssetID and DP.HistoryCCID=1 and DP.FromDate<=@iShiftDate and HistoryNodeID=@FromLoc
	--order by FromDate
	--if(@PrevLocationStartDate is null or @PrevLocationStartDate<dateadd(day,1-day(@ShiftDate),@ShiftDate))
	--	set @PrevLocationStartDate=convert(float,dateadd(day,1-day(@ShiftDate),@ShiftDate))

	--Validation for previous month pending depereciation postings
	if exists(select DP.AssetID from ACC_AssetDepSchedule DP with(nolock)
		where DP.AssetID=@AssetID and (DP.DocID is null or DP.DocID=0) and DP.DeprEndDate<@iShiftDate)
		RAISERROR('-147',16,1)

	--Validation for depereciation postings >= shifing date
	if exists(select DP.AssetID from ACC_AssetDepSchedule DP with(nolock) 
		where DP.AssetID=@AssetID and DP.DocID is not null and DP.DocID!=0 and DP.DeprEndDate>=@iShiftDate)
		RAISERROR('-136',16,1)

	--Validation for prevois shifing date
	if exists(select DP.NodeID from COM_HistoryDetails DP with(nolock)
		where DP.CostCenterID=72 and DP.NodeID=@AssetID and DP.HistoryCCID=1 and DP.FromDate>=@iShiftDate)
		RAISERROR('-137',16,1)

	--Update from location 
	set @SQL='UPDATE COM_DocCCData
SET dcCCNID'+convert(nvarchar,@LocationDimID-50000)+'=A.LocationID
from INV_DocDetails D with(nolock) 
inner join COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID
inner join COM_DocTextData TXT with(nolock) ON TXT.InvDocDetailsID=D.InvDocDetailsID
inner join ACC_Assets A with(nolock) ON A.CCNodeID=DCC.dcCCNID'+convert(nvarchar,@AssDimID-50000)+'
where D.InvDocDetailsID='+convert(nvarchar,@FromInvDetailsID)+' and D.VoucherType=-1'
	EXEC(@SQL)
	
	--Insert into COM_HistoryDetails
	set @SQL='
update ACC_Assets
set LocationID=DCC.dcCCNID'+convert(nvarchar,@LocationDimID-50000)+'
from COM_DocCCData DCC with(nolock)
inner join ACC_Assets A with(nolock) ON A.CCNodeID=DCC.dcCCNID'+convert(nvarchar,@AssDimID-50000)+'
where DCC.InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)+'

update COM_HistoryDetails
set ToDate=convert(float,convert(DATETIME,TXT.'+@txtShiftDate+'))-1
from INV_DocDetails D with(nolock) 
inner join COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID
inner join COM_DocTextData TXT with(nolock) ON TXT.InvDocDetailsID=D.InvDocDetailsID
inner join ACC_Assets A with(nolock) ON A.CCNodeID=DCC.dcCCNID'+convert(nvarchar,@AssDimID-50000)+'
inner join COM_HistoryDetails DP with(nolock) ON DP.CostCenterID=72 and DP.NodeID=A.AssetID
where D.InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)+' and D.VoucherType=1 and DP.HistoryCCID=1 and DP.ToDate IS NULL

declare @HistID bigint
INSERT INTO COM_HistoryDetails(CostCenterID,NodeID,HistoryCCID,HistoryNodeID,FromDate,ToDate,Remarks,CreatedBy,CreatedDate)
select 72,A.AssetID,1,DCC.dcCCNID'+convert(nvarchar,@LocationDimID-50000)+',convert(float,convert(DATETIME,TXT.'+@txtShiftDate+')),null,D.LineNarration,D.CreatedBy,convert(float,getdate())
from INV_DocDetails D with(nolock) 
inner join COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID
inner join COM_DocTextData TXT with(nolock) ON TXT.InvDocDetailsID=D.InvDocDetailsID
inner join ACC_Assets A with(nolock) ON A.CCNodeID=DCC.dcCCNID'+convert(nvarchar,@AssDimID-50000)+'
where D.InvDocDetailsID='+convert(nvarchar,@InvDocDetailsID)+' and D.VoucherType=1
set @HistID=SCOPE_IDENTITY()
INSERT INTO COM_DocBridge(CostCenterID,NodeID,AccDocID,InvDocID,Abbreviation,CompanyGUID,GUID,CreatedBy,CreatedDate,RefDimensionID,RefDimensionNodeID)
VALUES('+convert(nvarchar,@CostCenterID)+','+convert(nvarchar,@DocID)+',0,'+convert(nvarchar,@InvDocDetailsID)+','''','''','''','''',convert(float,getdate()),132,@HistID)
'
	--print(@SQL)
	EXEC(@SQL)
	
	if @PostAccounting=1
	begin
		--Inter Company Accounting Posting
		select @CrossDrAcc=DrAccount,@CrossCrAcc=CrAccount from ADM_CrossDimension where Dimension=@LocationDimID and Document=3 and DimIn=@FromLoc and DimFor=@ToLoc
		if @CrossDrAcc is null or @CrossCrAcc is null
			RAISERROR('-517',16,1)

		declare @Days int,@StartValue float,@PrevMnAccDepr float,@RemDepr float,@DeprAmt float,@MnDays float,@Decimals int,@TotalAccDepr float,@TotalAssetVal float
			,@AccDeprAccount bigint,@AssetAccount bigint
		--set @Days=@iShiftDate-@PrevLocationStartDate
		set @Days=day(@iShiftDate)-1

		select @AssetAccount=A.AcqnCostACCID,@AccDeprAccount=A.AccumDeprACCID
		from ACC_Assets A with(nolock) where A.AssetID=@AssetID
		
		--select @AssetID,@FromLoc,@ToLoc,@ShiftDate,@CrossDrAcc,@CrossCrAcc,@AssetAccount,@AccDeprAccount
		
		select top 1 @DeprAmt=DepAmount,@RemDepr=DepAmount+AssetNetValue,@PrevMnAccDepr=AccDepreciation-DepAmount,@MnDays=(DeprEndDate-DeprStartDate)+1
		from ACC_AssetDepSchedule DP with(nolock)
		where AssetID=@AssetID and DeprEndDate>=@iShiftDate order by DeprEndDate

		if(@Days>0 and @DeprAmt is not null)
		begin
			set @TotalAssetVal=@PrevMnAccDepr+@RemDepr
			
			select @Decimals=Value from ADM_GlobalPreferences with(nolock) where Name='DecimalsinAmount'
			set @DeprAmt=(@DeprAmt*@Days)/@MnDays
			set @DeprAmt=str(@DeprAmt,12,@Decimals)
			set @TotalAccDepr=@DeprAmt+@PrevMnAccDepr
			set @TotalAccDepr=str(@TotalAccDepr,12,@Decimals)
			set @RemDepr=str(@TotalAssetVal-@TotalAccDepr,12,@Decimals)
			
			--select @DeprAmt,@RemDepr,@TotalAccDepr,@TotalAssetVal
			
			INSERT INTO ACC_DocDetails(InvDocDetailsID,DocID,VOUCHERNO,CostCenterID,DocumentType,VersionNo,DocAbbr,DocPrefix,DocNumber,DocDate,DueDate
			,StatusID,BillNo,BillDate,CommonNarration,LineNarration,DebitAccount,CreditAccount,Amount
			,DocSeqNo,CurrencyID,ExchangeRate,AmountFC,CreatedBy,CreatedDate
			,WorkflowID,WorkFlowStatus,WorkFlowLevel,RefCCID,RefNodeid)
			SELECT InvDocDetailsID,0,VoucherNo,CostCenterID,DocumentType,VersionNo,DocAbbr,DocPrefix,DocNumber,@iShiftDate,CONVERT(FLOAT,DueDate)--CONVERT(FLOAT,DocDate)
			 ,StatusID,BillNo,BILLDate,CommonNarration,LineNarration,@AccDeprAccount,@AssetAccount,@TotalAccDepr
			 ,0,CurrencyID,ExchangeRate,@TotalAccDepr,CreatedBy,CreatedDate
			 ,WorkflowID,WorkFlowStatus,WorkFlowLevel,RefCCID,RefNodeid   
			from INV_DocDetails with(nolock) where InvDocDetailsID=@FromInvDetailsID
			UNION ALL
			SELECT InvDocDetailsID,0,VoucherNo,CostCenterID,DocumentType,VersionNo,DocAbbr,DocPrefix,DocNumber,@iShiftDate,CONVERT(FLOAT,DueDate)
			 ,StatusID,BillNo,BILLDate,CommonNarration,LineNarration,@CrossDrAcc,@AssetAccount,@RemDepr
			 ,0,CurrencyID,ExchangeRate,@RemDepr,CreatedBy,CreatedDate
			 ,WorkflowID,WorkFlowStatus,WorkFlowLevel,RefCCID,RefNodeid   
			from INV_DocDetails with(nolock) where InvDocDetailsID=@FromInvDetailsID
			UNION ALL
			SELECT InvDocDetailsID,0,VoucherNo,CostCenterID,DocumentType,VersionNo,DocAbbr,DocPrefix,DocNumber,@iShiftDate,CONVERT(FLOAT,DueDate)
			 ,StatusID,BillNo,BILLDate,CommonNarration,LineNarration,@AssetAccount,@AccDeprAccount,@TotalAccDepr
			 ,0,CurrencyID,ExchangeRate,@TotalAccDepr,CreatedBy,CreatedDate
			 ,WorkflowID,WorkFlowStatus,WorkFlowLevel,RefCCID,RefNodeid   
			from INV_DocDetails with(nolock) where InvDocDetailsID=@InvDocDetailsID
			UNION ALL
			SELECT InvDocDetailsID,0,VoucherNo,CostCenterID,DocumentType,VersionNo,DocAbbr,DocPrefix,DocNumber,@iShiftDate,CONVERT(FLOAT,DueDate)
			 ,StatusID,BillNo,BILLDate,CommonNarration,LineNarration,@AssetAccount,@CrossCrAcc,@RemDepr
			 ,0,CurrencyID,ExchangeRate,@RemDepr,CreatedBy,CreatedDate
			 ,WorkflowID,WorkFlowStatus,WorkFlowLevel,RefCCID,RefNodeid   
			from INV_DocDetails with(nolock) where InvDocDetailsID=@InvDocDetailsID
		end
	end
	
	--RAISERROR('-517',16,1)

END
GO
