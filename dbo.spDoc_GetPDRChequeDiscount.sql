USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetPDRChequeDiscount]
	@FromDate [datetime],
	@ToDate [datetime],
	@FilterAmount [nvarchar](500),
	@DocumentList [nvarchar](500),
	@BankAccountID [bigint],
	@DiscountBankAccountID [bigint],
	@PDC [bit],
	@LocationList [nvarchar](500),
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;    
  
  DECLARE @From FLOAT,@To FLOAT,@sql nvarchar(max),@PDPsql nvarchar(max),@PDRsql nvarchar(max),@isCrossDimRct bit  
     
  SET @From=CONVERT(FLOAT,@FromDate)  
  SET @To=CONVERT(FLOAT,@ToDate)  
  
	if exists(select PrefValue from COM_DocumentPreferences with(nolock)
	where PrefName = 'UseasCrossDimension' and PrefValue='true' and DocumentType=19)
		set @isCrossDimRct =1
	ELSE
		set @isCrossDimRct =0
		

 
  set @PDRsql=' select  D.AccDocDetailsID,  
	 D.DocID,D.CommonNarration,D.LineNarration,
      D.CostCenterID,'
   
   if(@isCrossDimRct=1) 
		set @PDRsql=@PDRsql+' Case WHEN D.DocOrder=5 THEN Ref.VoucherNo ELSE D.VoucherNo END as VoucherNo, '
   ELSE     
      set @PDRsql=@PDRsql+' D.VoucherNo, '
       
       set @PDRsql=@PDRsql+' D.DocPrefix,
      D.DocNumber,
      D.Amount,  
      D.StatusID,  
      A.PDCDiscountACCOUNT PDCDiscountACCOUNTID  , 
      A.PDCReceivableAccount PDCReceivableAccount,
      --isnull(A.InterestRate,0) InterestRate,
      --ISNULL(A.CheckDiscountLimit,0) CheckDiscountLimit, 
      --ISNULL(A.CommissionRate,0) CommissionRate ,	
      convert(datetime,D.DocDate) DocDate,  
      convert(datetime,D.ChequeMaturityDate) ChequeMaturityDate,  
      convert(datetime,D.ChequeMaturityDate) BillDate,  
      C.Status,  
      D.ChequeNumber,
       convert(datetime,D.ChequeDate,101)  ChequeDate,  
      A.AccountName as BankAccountID,  
      D.DebitAccount as BankAccountID_Key,  
      S.AccountName as AccountID,  
      D.CreditAccount as AccountID_Key,  
      D.CreditAccount as ActDr,D.BankAccountID BankID,BA.AccountName BankName,D.DocumentType,  
      (select top 1  voucherno from ACC_DocDetails with(nolock) where RefCCID=109 and RefNodeid=D.AccDocDetailsID)  as ConvertedVoucherNO,  
      (select top 1  AccDocDetailsID from ACC_DocDetails with(nolock) where RefCCID=109 and RefNodeid=D.AccDocDetailsID) as ConvertedDocID,l.* ,Tex.*  
     from  ACC_DocDetails D with(nolock)  '
     
	if(@isCrossDimRct=1) 
		set @PDRsql=@PDRsql+' left join ACC_DocDetails Ref with(nolock)   on Ref.AccDocDetailsID=D.RefNodeid
		and D.RefCCID=400 and Ref.StatusID=448 and D.DebitAccount=Ref.DebitAccount '
      
      
     set @PDRsql=@PDRsql+' join COM_Status C with(nolock) on D.StatusID=C.StatusID      
     join ACC_Accounts A with(nolock) on D.DebitAccount=A.AccountID  
     join ACC_Accounts S with(nolock) on D.CreditAccount=S.AccountID  
     left join ACC_Accounts BA with(nolock) on D.BankAccountID=BA.AccountID  
     join COM_DocCCData L with(nolock) on D.AccDocDetailsID=L.AccDocDetailsID 
     join COM_DocTextData Tex with(nolock) on D.AccDocDetailsID=Tex.AccDocDetailsID ' 
     if (@LocationList<>'')
		set @PDRsql=@PDRsql+'	left join COM_Location loc with(nolock) on L.dcCCNID2=loc.nodeid '
     
     set @PDRsql=@PDRsql+' where  D.DocumentType=19 	 '
     if(@PDC=0)
      set @PDRsql= @PDRsql + 'AND D.Statusid = 370 ' 
     else if(@PDC=1)
     set @PDRsql= @PDRsql + 'AND D.Statusid = 439 ' 
     if(@FilterAmount is not null and @FilterAmount <> '')
      set @PDRsql= @PDRsql + ' AND D.Amount  '  + @FilterAmount
      
      if(@DocumentList is not null and @DocumentList <> '')
      set @PDRsql= @PDRsql + ' and D.Costcenterid in  (' +  @DocumentList+ ')'
     
     
      if(@isCrossDimRct=1) 
		set @PDRsql=@PDRsql+' and ((D.DocOrder=5 and  Ref.VoucherNo is not null) or (Ref.VoucherNo is null and (D.DocOrder is null or D.DocOrder!=5))) '


      set @PDRsql= @PDRsql + ' and D.DocDate BETWEEN  '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)        
     if(@BankAccountID>0)  
      set @PDRsql=@PDRsql+' and (D.DebitAccount='+convert(nvarchar,@BankAccountID)+' or D.BankAccountID='+convert(nvarchar,@BankAccountID)+') '  
      if(@LocationList<>'')
         set @PDRsql= @PDRsql + ' and loc.Nodeid in  (' +  @LocationList+ ')'
        
	 set @PDRsql=@PDRsql+' order by  ChequeMaturityDate '
  PRINT (@PDRsql) 
     exec(@PDRsql)  
     
     SELECT AccountName,isnull(INTERESTRATE,0) INTERESTRATE ,isnull(COMMISSIONRATE,0) COMMISSIONRATE, isnull(CHECKDISCOUNTLIMIT,0) CHECKDISCOUNTLIMIT
     ,isnull((Select sum(amount) from ACC_DocDetails with(nolock) Where (BankAccountID=@DiscountBankAccountID or DebitAccount =@DiscountBankAccountID) and Statusid=439 ) ,0)  Used
     
     FROM ACC_ACCOUNTS with(nolock)
     WHERE ACCOUNTID = @DiscountBankAccountID
  
   
SET NOCOUNT OFF;    
RETURN 1  
END TRY  
BEGIN CATCH    
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
