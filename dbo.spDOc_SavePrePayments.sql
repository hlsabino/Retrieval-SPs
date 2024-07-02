USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOc_SavePrePayments]
	@IsInventory [bit],
	@costcenterid [int],
	@Prepaymentxml [nvarchar](max),
	@AccDocDetailsID [int],
	@invDetID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY        
SET NOCOUNT ON;    
  
  if(@costcenterid is null or @costcenterid<40000)  
   RAISERROR('-101',16,1)  
     
     
  Declare @i int,@cnt int,@ii int,@ccnt int,@DocID INT,@DELETECCID int,@return_value int,@VoucherNo nvarchar(200),@DocPrefix nvarchar(200),@dt datetime,@DocNumber nvarchar(50),@CCCols nvarchar(max),@sql nvarchar(max)
  declare @xml xml,@DocAbbr nvarchar(200),@DocumentTypeID INT,@DocumentType int,@DocOrder int,@creatdt float,@Credid INT,@DebitAcc INT,@amt float,@acc INT,@qry nvarchar(max),@GUID nvarchar(max) ,@Accqry nvarchar(max)
  declare @NID int,@DimCurr int,@dec nvarchar(5),@ExchRate float,@Currid int,@seq int
  declare @ttdel table(id int identity(1,1),accid INT,dt datetime,data nvarchar(max))  
  declare @tbltran table(id int identity(1,1),CredAcc INT,DebitAcc INT,amt float,Qry nvarchar(max))  
  
  set @DimCurr=0
  SELECT @DimCurr=Value FROM ADM_GlobalPreferences with(nolock)
  WHERE Name ='DimensionwiseCurrency' and value is not null and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
	
  SELECT @Currid=Value FROM ADM_GlobalPreferences with(nolock) WHERE Name='BaseCurrency'
  SELECT @dec=Value FROM ADM_GlobalPreferences with(nolock) WHERE Name='DecimalsinAmount'
    
  set @CCCols=''  
  select @CCCols =@CCCols +','+a.name from sys.columns a  
  join sys.tables b on a.object_id=b.object_id  
  where b.name='COM_DocCCData'  and a.name not in('AccDocDetailsID','INVDocDetailsID','DocCCDataID')  
    
  if(@IsInventory=1)  
   insert into @ttdel(accid)  
   SELECT AccDocDetailsID FROM  [ACC_DocDetails]  WITH(NOLOCK)      
   WHERE refccid=300 and refnodeid=@AccDocDetailsID  
  ELSE  
   insert into @ttdel(accid)  
   SELECT AccDocDetailsID FROM  [ACC_DocDetails]  WITH(NOLOCK)      
   WHERE refccid=400 and refnodeid=@AccDocDetailsID  
    
  select @ii=0,@ccnt=COUNT(accid) from @ttdel  
  while(@ii<@ccnt)  
  BEGIN  
   set @ii=@ii+1  
   set @DocID=0        
   SELECT @DocID = DocID, @DELETECCID = COSTCENTERID FROM ACC_DocDetails with(nolock)     
   where AccDocDetailsID=(select accid from @ttdel where id=@ii)  
     
   if(@DocID is not null and @DocID>0)  
   BEGIN  
     EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]    
     @CostCenterID = @DELETECCID,    
     @DocPrefix = '',    
     @DocNumber = '',   
     @DocID=@DocID ,   
     @UserID = 1,    
     @UserName = @UserName,    
     @LangID = @LangID,  
     @RoleID=1  
   END    
  END   
    
    
  SELECT @creatdt=CONVERT(float,getdate()),@DocumentTypeID=DocumentTypeID,@DocumentType=DocumentType,@DocAbbr=DocumentAbbr,@DocOrder=DocOrder  
  FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID    
    
  
  set @xml=@Prepaymentxml  
  delete from @ttdel  
  insert into @ttdel(dt,data)  
  select X.value('@Date','Datetime'),CONVERT(nvarchar(max),X.query('data'))  
  from @xml.nodes('/PrePaymentXML/Row') as Data(X)   
    
  if(@IsInventory=1)  
  BEGIN  
   set @qry=''  
   select @qry=CONVERT(nvarchar(max),X.query('XML'))  
   from @xml.nodes('/PrePaymentXML') as Data(X)   
   set @Accqry=@qry     
     
   update inv_docdetails  
   set Description=null  
   where Docid=@AccDocDetailsID  
     
   update inv_docdetails  
   set Description=@qry  
   where InvDocDetailsID=@invDetID  
  END  
    
  select @ii=MIN(id),@ccnt=max(id) from @ttdel  
    
  while(@ii<=@ccnt)  
  BEGIN  
     
   SELECT @dt=dt,@xml=data  from @ttdel where id=@ii  
   set @ii=@ii+1  
   if(@IsInventory=1)  
   BEGIN  
    EXEC [sp_GetDocPrefix] '',@dt,@costcenterid,@DocPrefix output,@invDetID,0,0,0,1  
   END  
   ELSE  
   BEGIn  
    EXEC [sp_GetDocPrefix] '',@dt,@costcenterid,@DocPrefix output,@AccDocDetailsID  
   END   
     
   if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef  WITH(NOLOCK) WHERE CostCenterID=@costcenterid AND CodePrefix=@DocPrefix)      
   begin      
    INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)      
    VALUES(@costcenterid,@costcenterid,@DocPrefix,1,1,1,1,Newid(),@UserName,convert(float,getdate()),0,0)      
     set @DocNumber='1'  
   end      
   ELSE  
   BEGIN  
    SELECT  @DocNumber=ISNULL(CurrentCodeNumber,0)+1 FROM COM_CostCenterCodeDef WITH(NOLOCK) --AS CurrentCodeNumber    
    WHERE CostCenterID=@costcenterid AND CodePrefix=@DocPrefix   
   END  
        
        
   SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')      
    
   while exists (select DocNo from COM_DocID with(nolock) where DocNo=@VoucherNo)  
   begin     
    SET @DocNumber=@DocNumber+1  
    SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')  
   end  
     
   set @GUID=newid()  
     
   INSERT INTO COM_DocID(DocNo,[CompanyGUID],[GUID])  
   VALUES(@VoucherNo,@CompanyGUID,@GUID)  
   SET @DocID=@@IDENTITY  
      
   UPDATE COM_CostCenterCodeDef       
   SET CurrentCodeNumber=@DocNumber      
   WHERE CostCenterID=@costcenterid AND CodePrefix=@DocPrefix      
     
   delete from @tbltran  
   insert into @tbltran   
   select X.value('@CredAcc','INT'),X.value('@DebitAcc','INT'),X.value('@Amount','float'),X.value('@Query','nvarchar(max)')   
   from @xml.nodes('/data') as Data(X)   
     
     
   select @i=MIN(id),@cnt=max(id) from @tbltran  
    set @seq=0
   while(@i<=@cnt)  
   BEGIN  
     
    SELECT @Credid=CredAcc,@DebitAcc=DebitAcc,@amt=amt,@qry=Qry  from @tbltran where id=@i  
    set @i=@i+1  
      set @seq=@seq+1
      
    if(@IsInventory=1)  
    BEGIN  
     INSERT INTO ACC_DocDetails      
      ([DocID]      
      ,[CostCenterID]        
      ,[DocumentType],DocOrder     
      ,[VersionNo]      
      ,[VoucherNo]      
      ,[DocAbbr]      
      ,[DocPrefix]      
      ,[DocNumber]      
      ,[DocDate]      
      ,[DueDate]      
      ,[StatusID]      
          
      ,[BillNo]      
      ,BillDate                   
      ,[CommonNarration]      
      ,LineNarration      
      ,[DebitAccount]      
      ,[CreditAccount]      
      ,[Amount]      
      ,IsNegative      
      ,[DocSeqNo]      
      ,[CurrencyID]      
      ,[ExchangeRate]   
      ,[AmountFC]     
      ,[CreatedBy]      
      ,[CreatedDate] ,[ModifiedBy]    
      ,[ModifiedDate],WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID ,RefNodeid  
      ,[Description])      
               
     SELECT @DocID      
      , @CostCenterID       
      , @DocumentType,@DocOrder     
      , 1    
      , @VoucherNo      
      , @DocAbbr      
      , @DocPrefix      
      , @DocNumber      
      , CONVERT(FLOAT,@dt)      
      , DueDate  
      , StatusID      
       
     , BillNo  
      ,BillDate  
      ,CommonNarration  
      ,LineNarration  
      ,@DebitAcc  --debit      
      ,@Credid  --Credit      
      , @amt*ExchangeRate     
      , 0           
      , @seq
      , CurrencyID  
      , ExchangeRate  
      , @amt
       
      , @UserName      
      , @creatdt, @UserName      
      , @creatdt,WorkflowID , WorkFlowStatus , WorkFlowLevel,case when @IsInventory=1 then 300 else 400 end,@AccDocDetailsID  
      ,@Accqry  
       from INV_DocDetails WITH(NOLOCK)  
       where InvDocDetailsID=@invDetID   
         
        SET @acc=@@IDENTITY   
        
      set @sql='INSERT INTO [COM_DocCCData]      
     ([AccDocDetailsID]'+@CCCols+')   
      SELECT     '+convert(nvarchar(max),@acc)+@CCCols+'  
      from [COM_DocCCData] with(nolock)   where  InvDocDetailsID='+convert(nvarchar(max),@invDetID)  
      exec(@sql)  
        
        
     END  
     ELSE  
     BEGIN   
    INSERT INTO ACC_DocDetails      
     ([DocID]      
     ,[CostCenterID]      
         
     ,[DocumentType],DocOrder     
     ,[VersionNo]      
     ,[VoucherNo]      
     ,[DocAbbr]      
     ,[DocPrefix]      
     ,[DocNumber]      
     ,[DocDate]      
     ,[DueDate]      
     ,[StatusID]      
     ,[ChequeBankName]      
     ,[ChequeNumber]      
     ,[ChequeDate]      
     ,[ChequeMaturityDate]      
     ,[BillNo]      
     ,BillDate                   
     ,[CommonNarration]      
     ,LineNarration      
     ,[DebitAccount]      
     ,[CreditAccount]      
     ,[Amount]      
     ,IsNegative      
     ,[DocSeqNo]      
     ,[CurrencyID]      
     ,[ExchangeRate]   
     ,[AmountFC]   
     ,[CreatedBy]      
     ,[CreatedDate] ,[ModifiedBy]    
     ,[ModifiedDate],WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID ,RefNodeid  
     ,[Description])      
              
    SELECT @DocID      
     , @CostCenterID       
     , @DocumentType,@DocOrder     
     , 1    
     , @VoucherNo      
     , @DocAbbr      
     , @DocPrefix      
     , @DocNumber      
     , CONVERT(FLOAT,@dt)      
     , DueDate  
     , StatusID      
     , ChequeBankName  
     , ChequeNumber  
     , ChequeDate  
     , ChequeMaturityDate  
    , BillNo  
     ,BillDate  
     ,CommonNarration  
     ,LineNarration  
     ,@DebitAcc  --debit      
     ,@Credid  --Credit      
     , @amt    
     , 0           
     , 1  
     , CurrencyID  
     , ExchangeRate  
     , @amt/ExchangeRate   
     , @UserName      
     , @creatdt, @UserName      
     , @creatdt,WorkflowID , WorkFlowStatus , WorkFlowLevel,case when @IsInventory=1 then 300 else 400 end,@AccDocDetailsID  
     ,null  
      from ACC_DocDetails WITH(NOLOCK)  
      where AccDocDetailsID=@AccDocDetailsID    
       SET @acc=@@IDENTITY   
        
      set @sql='INSERT INTO [COM_DocCCData]      
     ([AccDocDetailsID]'+@CCCols+')   
      SELECT     '+convert(nvarchar(max),@acc)+@CCCols+'  
      from [COM_DocCCData] with(nolock)   where  AccDocDetailsID='+convert(nvarchar(max),@AccDocDetailsID)  
      exec(@sql)  
        
        
       END   
       
        
      INSERT INTO [COM_DocNumData] ([AccDocDetailsID])       
      values(@acc)  
       
      INSERT INTO [COM_DocTextData]([AccDocDetailsID])  
      values(@acc)  
        
        
        
      if(@qry<>'')  
      BEGIN  
		 set @qry='update [COM_DocCCData] set '+@qry+'AccDocDetailsID ='+convert(nvarchar(max),@acc)  
		  +'where AccDocDetailsID ='+convert(nvarchar(max),@acc)  
		  exec(@qry)  
      END   
      
      if (exists(select name from sys.columns where name='ExhgRtBC') and @DimCurr>50000)		
		BEGIN
		
			set @qry='select @NID=dcCCNID'+convert(nvarchar,(@DimCurr-50000))+' from COM_DocCCData  WITH(NOLOCK) where AccDocDetailsID='+convert(nvarchar,@acc)			
			EXEC sp_executesql @qry, N'@NID float OUTPUT', @NID OUTPUT   
			
			SELECT @ExchRate=ExchangeRate  FROM  COM_EXCHANGERATES WITH(NOLOCK) 
			where CurrencyID = @Currid AND EXCHANGEDATE <= CONVERT(FLOAT,@dt)
			and DimNodeID=@NID ORDER BY EXCHANGEDATE DESC
			
			set @qry='update A
				set AmountBC=round(Amount/'+convert(nvarchar,@ExchRate)+','+@dec+'),ExhgRtBC='+convert(nvarchar,@ExchRate)+'
				FROM ACC_DocDetails A WITH(NOLOCK)
				where AccDocDetailsID ='+convert(nvarchar(max),@acc)  
			
			exec(@qry)
		END
   END   
  END  
  
COMMIT TRANSACTION  
     
SET NOCOUNT OFF;        
RETURN 1        
END TRY        
BEGIN CATCH     
  if(@return_value is not null and  @return_value=-999)           
  return -999    
 --Return exception info [Message,Number,ProcedureName,LineNumber]        
 IF ERROR_NUMBER()=50000      
 BEGIN      
   SELECT ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
   WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END      
 ELSE IF ERROR_NUMBER()=547      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=-110 AND LanguageID=@LangID      
 END    
  ELSE IF ERROR_NUMBER()=1205    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-350 AND LanguageID=@LangID    
 END     
 ELSE IF ERROR_NUMBER()=2627      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=-116 AND LanguageID=@LangID      
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
