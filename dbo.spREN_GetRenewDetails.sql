USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetRenewDetails]
	@ContractID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION                        
BEGIN TRY                         
SET NOCOUNT ON                        
                        
	declare @RenewRefID BIGINT,@QuotationID BIGINT,@cnt int,@Ed float,@parentID BIGINT,@sno BIGINT
	declare @tab table(StartDate Float,EndDate Float)

	SELECT @RenewRefID=isnull(RenewRefID,0),@QuotationID=isnull(QuotationID,0),@parentID=isnull(ParentContractID,0)
	FROM REN_CONTRACT WITH(NOLOCK)                       
	where ContractID = @ContractID
	
	if(@parentID>0)
	BEGIN
		SELECT @parentID=isnull(ContractID,0),@sno=SNO
		FROM REN_CONTRACT WITH(NOLOCK)
		where RenewRefID = @parentID and isnull(RefContractID,0)=0
	END
	
	insert into @tab
	select StartDate,EndDate FROM REN_CONTRACT WITH(NOLOCK)                       
	where ContractID = @ContractID
	
	set @cnt=1
	while(@QuotationID=0 and @RenewRefID>0)
	BEGIN
		if exists(select isnull(RenewRefID,0) from REN_Contract	WITH(NOLOCK)	
		where ContractID=@RenewRefID)
		BEGIN
			set @cnt=@cnt+1
			select @RenewRefID=isnull(RenewRefID,0),@QuotationID=isnull(QuotationID,0)  
			from REN_Contract WITH(NOLOCK)		
			where ContractID=@RenewRefID
			
			insert into @tab
			select StartDate,EndDate FROM REN_CONTRACT WITH(NOLOCK)                       
			where ContractID = @RenewRefID

		END	
		ELSE
			set @RenewRefID=0
	END
	
	select @Ed=max(EndDate) from @tab

	if(@QuotationID>0 and exists(select QuotationID from REN_Quotation WITH(NOLOCK)
	where QuotationID = @QuotationID and EndDate>@Ed))
	BEGIN
		SELECT  DISTINCT  @cnt cnt,convert(datetime,@Ed) MaxENDdate,CP.NodeID, CP.QuotationID ContractID, CP.CCID, CP.CCNodeID, CP.CreditAccID, CP.ChequeNo, convert(datetime,CP.ChequeDate) ChequeDate, CP.PayeeBank,                      
		CP.DebitAccID, CP.Amount, CP.RentAmount RentAmount, CP.Discount DiscountAmount,CP.Narration
		,CP.InclChkGen,CP.vattype,CP.VatPer,CP.VatAmount, ACC.ACCOUNTNAME CREDITNAME , ACCD.ACCOUNTNAME  DEBITNAME ,CP.IsRecurr   ,0 Refund , 0  StatusID                   
		, '' VoucherNo ,'' DocPrefix ,'' DocNumber , 0  CostCenterID, ''  DocumentName ,0  DocID,cp.Detailsxml           
		FROM REN_QuotationParticulars  CP WITH(NOLOCK)  
		join REN_Quotation CNT WITH(NOLOCK) ON CP.QuotationID = CNT.QuotationID
		LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.CreditAccID                         
		LEFT JOIN ACC_Accounts ACCD WITH(NOLOCK) ON ACCD.ACCOUNTID = CP.DebitAccID                           
		where  CP.QuotationID = @QuotationID                   

		SELECT DISTINCT  CP.NodeID,  CP.ChequeNo, Convert(datetime,CP.ChequeDate) ChequeDate , CP.CustomerBank, CP.DebitAccID, CP.Amount,                 
		period,ACC.AccountName DebitAccName , CP.Narration , ''  StatusID   , '' VoucherNo ,''  DocPrefix ,''  DocNumber , 0 CostCenterID,  ''  DocumentName,0 DocID                        
		FROM REN_quotationPayTerms CP WITH(NOLOCK)                       
		LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON ACC.ACCOUNTID = CP.DebitAccID                         
		where CP.QuotationID = @QuotationID --and CDM.TYPE = 2                     
	END
	ELSE
	BEGIN
		SElect 1 where 1<>1
		SElect 1 where 1<>1
	END
	
	SELECT @parentID ParentRefID,@sno ParentSno
                     
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
