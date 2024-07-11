USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetPropertyDetails]
	@PropertyID [bigint] = 0,
	@Type [int],
	@Status [bigint],
	@DocStatus [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
    
BEGIN TRY     
SET NOCOUNT ON    
    
 declare @Sql nvarchar(max),@tablename nvarchar(100),@ccid int,@PrefVal nvarchar(100),@col nvarchar(max),@join nvarchar(max)  
      
    set @join=''  
      
    set @col='SELECT ACC.AccDocDetailsID,ACC.StatusID DocStatus,ChequeNumber,CONVERT(DATETIME,ChequeMaturityDate) MaturityDate,CONVERT(DATETIME,ACC.DocDate) DocDate,ACC.VoucherNo   
    ,ACC.BankAccountID BankID,BA.AccountName BankName,ACC.DocumentType,ACC.DebitAccount,ACC.CreditAccount,CA.AccountName CrAccountName,T1.AccountName ,  
    ACC.Amount,ACC.CommonNarration,T2.dcCCNID3,Br.Name BranchName'  
--T3.Name ,T6.Name ,T7.Name ,T8.Name   
  
  set @Sql=' FROM ACC_DocDetails ACC WITH(NOLOCK)  
 join ACC_Accounts T1  WITH(NOLOCK) on ACC.DebitAccount=T1.AccountID  
 join ACC_Accounts CA  WITH(NOLOCK) on ACC.CreditAccount=CA.AccountID  
 left join ACC_Accounts BA  WITH(NOLOCK) on ACC.BankAccountID=BA.AccountID  
 join COM_DocCCData T2  WITH(NOLOCK) on ACC.AccDocDetailsID=T2.AccDocDetailsID 
 join COM_Branch BR  WITH(NOLOCK) on T2.dcCCNID3=BR.NODEID    
 join REN_ContractDocMapping RM  WITH(NOLOCK) on RM.DocID=ACC.DocID and RM.IsAccDoc=1
 join REN_Contract RC  WITH(NOLOCK) on RC.ContractID=RM.ContractID
 '  
 select @PrefVal=Value from COM_CostCenterPreferences where CostCenterID=92 and Name='LinkDocument'   
 if(@PrefVal is not null and @PrefVal<>'' and convert(bigint,@PrefVal)>50000)  
 begin  
  select @tablename=tablename from adm_features where featureid=convert(bigint,@PrefVal)  
   set @join=@join+' join '+@tablename+' p WITH(NOLOCK) on T2.dcCCNID'+convert(nvarchar,convert(bigint,@PrefVal)-50000)+'=p.NodeID'  
   set @col=@col+',p.Name Property , p.NodeID Property_Key '  
 end  
 select @PrefVal=Value from COM_CostCenterPreferences where CostCenterID=93 and Name='LinkDocument'  
 if(@PrefVal is not null and @PrefVal<>'' and convert(bigint,@PrefVal)>50000)  
 begin  
  select @tablename=tablename from adm_features where featureid=convert(bigint,@PrefVal)  
   set @join=@join+' join '+@tablename+' U WITH(NOLOCK) on T2.dcCCNID'+convert(nvarchar,convert(bigint,@PrefVal)-50000)+'=U.NodeID'  
   set @col=@col+',U.Name Unit , U.NodeID Unit_Key '  
 end  
 select @PrefVal=Value from COM_CostCenterPreferences where CostCenterID=94 and Name='LinkDocument'  
 if(@PrefVal is not null and @PrefVal<>'' and convert(bigint,@PrefVal)>50000)  
 begin  
  select @tablename=tablename from adm_features where featureid=convert(bigint,@PrefVal)  
   set @join=@join+' join '+@tablename+' T WITH(NOLOCK) on T2.dcCCNID'+convert(nvarchar,convert(bigint,@PrefVal)-50000)+'=T.NodeID'  
   set @col=@col+',T.Name Tenant , T.NodeID Tenant_Key '  
 end  
if(@Status>0)
BEGIN
	 select @PrefVal=Value from COM_CostCenterPreferences where CostCenterID=95 and Name='PostDocStatus'  
	 if(@PrefVal is not null and @PrefVal<>'' and convert(bigint,@PrefVal)>50000)  
	 begin  
	  select @tablename=tablename from adm_features where featureid=convert(bigint,@PrefVal)  
	   set @join=@join+' join '+@tablename+' S WITH(NOLOCK) on T2.dcCCNID'+convert(nvarchar,convert(bigint,@PrefVal)-50000)+'=S.NodeID'  
	   set @col=@col+',S.Name Status,T2.dcCCNID'+convert(nvarchar,convert(bigint,@PrefVal)-50000)+' StatusID'  
	 end  
END   
	set @Sql=@col+',convert(Datetime,RM.ReceiveDate) ReceiveDate,RM.JVVoucherNo,RM.MapID,ChequeBankName,RC.SNO' +@Sql+@join+' where ACC.RefCCID is not null and  ACC.RefCCID=95 and ACC.DocumentType<>17 and RM.DocType in (1,2,3) '  
	if(@PropertyID>0)  
	begin  
		set @Sql=@Sql+' and RefNodeid in (select ContractID  from REN_Contract where PropertyID='+convert(nvarchar,@PropertyID)+') '  
	end  
	if(@Type=1)  
	begin  
		set @Sql=@Sql+' and ACC.DocumentType<>19 '  
	end  
	else if(@Type=2)  
	begin  
		set @Sql=@Sql+' and ACC.DocumentType=19 ' 
		if(@DocStatus>0)
			set @Sql=@Sql+' and ACC.StatusID= '+CONVERT(nvarchar,@DocStatus) 
	end  
	
	set @Sql=@Sql+' and ACC.StatusID<>376 '
	
	if(@Status>0)
	BEGIN
		select @PrefVal=Value from COM_CostCenterPreferences where CostCenterID=95 and Name='PostDocStatus'  

		if(@PrefVal is not null and @PrefVal<>'' and convert(bigint,@PrefVal)>50000)  
		begin  
		   set @Sql=@Sql+' and T2.dcCCNID'+convert(nvarchar,convert(bigint,@PrefVal)-50000)+' ='+convert(nvarchar,@Status)   
		end  
    END
      
    set @PrefVal=''   
    select @PrefVal=Value from COM_CostCenterPreferences where CostCenterID=92 and Name='CollectionDocs'  
 if(@PrefVal is not null and @PrefVal<>'')  
 begin  
  set @Sql=@Sql+ ' UNION ' + @col+',convert(Datetime,RM.ReceiveDate) ReceiveDate,RM.JVVoucherNo,RM.MapID,ChequeBankName,'''' SNO'+'  FROM ACC_DocDetails ACC WITH(NOLOCK)  
  join ACC_Accounts T1  WITH(NOLOCK) on ACC.DebitAccount=T1.AccountID  
  join ACC_Accounts CA  WITH(NOLOCK) on ACC.CreditAccount=CA.AccountID  
  left join ACC_Accounts BA  WITH(NOLOCK) on ACC.BankAccountID=BA.AccountID  
  join COM_DocCCData T2  WITH(NOLOCK) on ACC.AccDocDetailsID=T2.AccDocDetailsID  
  join COM_Branch BR  WITH(NOLOCK) on T2.dcCCNID3=BR.NODEID  
  left join REN_ContractDocMapping RM  WITH(NOLOCK) on RM.DocDetID=ACC.AccDocDetailsID and RM.IsAccDoc=1 AND rm.cONTRACTid=-1'  
  +@join+ ' where ACC.Costcenterid in ('+@PrefVal+') '  
	if(@PropertyID>0)  
	begin  
		select @PrefVal=Value from COM_CostCenterPreferences where CostCenterID=92 and Name='LinkDocument'   
		if(@PrefVal is not null and @PrefVal<>'' and convert(bigint,@PrefVal)>50000)  
		begin    
			select @PropertyID=CCNODEID FROM REn_Property where nodeid=@PropertyID  
			if(@PropertyID is not null)  
				set @Sql=@Sql+' and T2.dcCCNID'+convert(nvarchar,convert(bigint,@PrefVal)-50000)+'='+convert(nvarchar,@PropertyID)  
		end  
	end  
  
	if(@Type=1)  
	begin  
		set @Sql=@Sql+' and ACC.DocumentType<>19 '  
	end  
	else if(@Type=2)  
	begin  
		set @Sql=@Sql+' and ACC.DocumentType=19 ' 
		if(@DocStatus>0)
			set @Sql=@Sql+' and ACC.StatusID= '+CONVERT(nvarchar,@DocStatus)  
	end  
	
	set @Sql=@Sql+' and ACC.StatusID<>376 '
	
	if(@Status>0)
	BEGIN
		select @PrefVal=Value from COM_CostCenterPreferences where CostCenterID=95 and Name='PostDocStatus'  

		if(@PrefVal is not null and @PrefVal<>'' and convert(bigint,@PrefVal)>50000)  
		begin  
			set @Sql=@Sql+' and T2.dcCCNID'+convert(nvarchar,convert(bigint,@PrefVal)-50000)+' ='+convert(nvarchar,@Status)   
		end 
	END	 
 END  
      
   print @Sql  
   exec (@Sql)  
     
     
   Select * from COM_CostCenterPreferences                          
  where name like '%LinkDocument%'    
  
  
  
     
      
    
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
