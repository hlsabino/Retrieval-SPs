USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_VPTTerminationDetails]
	@CostCenterID [int] = 95,
	@ContractID [int] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION                        
BEGIN TRY                         
SET NOCOUNT ON                        

	declare @PendingVchrs nvarchar(max),@SQL nvarchar(max),@PartTableName nvarchar(50),@RenewRefID INT,@AllContractID nvarchar(max)
	declare @tabvchrs table(vno nvarchar(50))
	
	select @PartTableName=TableName from adm_features with(nolock) where FeatureID in (select Value from adm_globalPreferences with(nolock) where Name='DepositLinkDimension')

	set @AllContractID=''
	set @RenewRefID=@ContractID
	while(1=1)
	begin
		if(@AllContractID!='')
			set @AllContractID=@AllContractID+','
		set @AllContractID=@AllContractID+convert(nvarchar,@RenewRefID)
		SELECT @RenewRefID=RenewRefID FROM REN_Contract WITH(NOLOCK) WHERE ContractID=@RenewRefID
		if(@RenewRefID is null or @RenewRefID=0)
			break
	end

	set @SQL='select distinct P.Name,CP.Amount,CP.NodeID from REN_Particulars RP with(nolock)
	inner join '+@PartTableName+' P with(nolock) on P.NodeID=RP.ParticularID 
	inner join REN_ContractParticulars CP with(nolock) on CP.CCNodeID=RP.ParticularID
	where CP.ContractID in ('+@AllContractID+') and RP.PropertyID IN (select PropertyID from REN_Contract with(nolock) where ContractID='+convert(nvarchar,@ContractID)+' ) and Refund=1 and ContractType=1'
	exec(@SQL)


	set @SQL='select P.Name,RP.NetAmount Amount from REN_TerminationParticulars RP with(nolock)
    inner join '+@PartTableName+' P with(nolock) on P.NodeID=RP.CCNodeID where ContractID='+convert(nvarchar,@ContractID)
    print @SQL
    exec(@SQL)
	
	SELECT Type,D.StatusID,D.ChequeNumber,convert(datetime,D.ChequeDate) ChequeDate,D.Amount FROM REN_ContractDocMapping C with(nolock)
	inner join acc_docdetails D with(nolock) on D.DocID=C.DocID
	where ContractID=@ContractID and Type=2 and D.StatusID IN (370,376,452)
	order by ChequeDate

	
	set @PendingVchrs=''
	select @PendingVchrs=@PendingVchrs+dbo.[fnDoc_GetPendingVouchers](VoucherNo) from ACC_DocDetails WITH(NOLOCK)
	where RefCCID=@CostCenterID and RefNodeid=@ContractID and StatusID=429

	insert into @tabvchrs
	exec SPSplitString @PendingVchrs,','
	
	select * from (
	select VoucherNo,dbo.[fnDoc_GetPendingAmount](VoucherNo) Amount,ChequeNumber,CONVERT(datetime,ChequeDate) ChequeDate from ACC_DocDetails WITH(NOLOCK)
	where RefCCID=@CostCenterID and RefNodeid=@ContractID and StatusID=429
	union all
	select VoucherNo,Amount,ChequeNumber,CONVERT(datetime,ChequeDate) ChequeDate from ACC_DocDetails WITH(NOLOCK)
	where (StatusID=370 or StatusID=452) and VoucherNo in(select vno from @tabvchrs)) as t
	where Amount<>0
                     
COMMIT TRANSACTION                        
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
ROLLBACK TRANSACTION                        
SET NOCOUNT OFF                          
RETURN -999                           
END CATCH
GO
