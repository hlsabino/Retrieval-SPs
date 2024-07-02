USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetContractsUnitsinCase]
	@PropertyID [bigint] = 0,
	@date [datetime],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    


	if exists(select value from  [COM_CostCenterPreferences] with(nolock) where name='IncomeforExpiredContracts' and costcenterid=95 and value='true')
	BEGIN
		
		if(@PropertyID>0)	
				select a.contractID, a.sno,convert(datetime,a.startdate) startdate,convert(datetime,a.enddate) enddate,convert(datetime,c.receiveDate)receiveDate,c.jvvoucherno
				,b.name unitName,p.name propertyName,a.unitid,a.Propertyid,a.TenantID,t.firstName
				,b.RentalReceivableAccountID UnitRecAcc,p.RentalReceivableAccountID PropRecAcc
				,b.ProvisionAccountID UnitProvsAcc,p.ProvisionAccountID PropProvsAcc,c.CostCenterID,c.DocID
				 from ren_contract a WITH(NOLOCK)
				join ren_units b WITH(NOLOCK) on a.unitid=b.unitid
				left join ren_contract ren WITH(NOLOCK) on a.contractID=ren.RenewRefID
				join ren_Property p WITH(NOLOCK) on a.Propertyid=p.Nodeid
				join ren_tenant t WITH(NOLOCK) on t.TenantID=a.TenantID				
				left join ren_contractdocmapping c WITH(NOLOCK) on a.contractid=c.contractid and c.type=20 
				and month(convert(datetime,c.receiveDate))=month(@date)
				and Year(convert(datetime,c.receiveDate))=Year(@date)
				where ren.contractID is null and a.enddate<convert(float,@date) and a.PropertyID=@PropertyID and a.statusid in(426,427)
			ELSE
				select a.contractID,a.sno,convert(datetime,a.startdate) startdate,convert(datetime,a.enddate) enddate,convert(datetime,c.receiveDate) receiveDate,c.jvvoucherno
				,b.name unitName,p.name propertyName,a.unitid,a.Propertyid,a.TenantID,t.firstName
				,b.RentalReceivableAccountID UnitRecAcc,p.RentalReceivableAccountID PropRecAcc
				,b.ProvisionAccountID UnitProvsAcc,p.ProvisionAccountID PropProvsAcc,c.CostCenterID,c.DocID
				 from ren_contract a WITH(NOLOCK)
				join ren_units b WITH(NOLOCK) on a.unitid=b.unitid
				left join ren_contract ren WITH(NOLOCK) on a.contractID=ren.RenewRefID		
				join ren_Property p WITH(NOLOCK) on a.Propertyid=p.Nodeid
				join ren_tenant t WITH(NOLOCK) on t.TenantID=a.TenantID
				left join ren_contractdocmapping c WITH(NOLOCK) on a.contractid=c.contractid and c.type=20 
				and month(convert(datetime,c.receiveDate))=month(@date)
				and Year(convert(datetime,c.receiveDate))=Year(@date)
				where ren.contractID is null and  a.enddate<convert(float,@date) and a.statusid in(426,427)
				
	END
	ELSE
	BEGIN
			declare @table table(TypeID nvarchar(50))  
			declare @Val nvarchar(50)
			select @Val=value from  [COM_CostCenterPreferences] with(nolock)
			where name='CaseIncomeStatus' and costcenterid=95
			
			insert into @table  
			exec SPSplitString @Val,','  

			    
			if(@PropertyID>0)	
				select a.contractID, a.sno,convert(datetime,a.startdate) startdate,convert(datetime,a.enddate) enddate,convert(datetime,c.receiveDate)receiveDate,c.jvvoucherno
				,b.name unitName,p.name propertyName,a.unitid,a.Propertyid,a.TenantID,t.firstName
				,b.RentalReceivableAccountID UnitRecAcc,p.RentalReceivableAccountID PropRecAcc
				,b.ProvisionAccountID UnitProvsAcc,p.ProvisionAccountID PropProvsAcc,f.amount,c.CostCenterID,c.DocID
				 from ren_contract a WITH(NOLOCK)
				join ren_units b WITH(NOLOCK) on a.unitid=b.unitid
				join @table us on b.unitstatus=us.TypeID
				join ren_Property p WITH(NOLOCK) on a.Propertyid=p.Nodeid
				join ren_tenant t WITH(NOLOCK) on t.TenantID=a.TenantID
				join REN_CONTRACTDOCMAPPING m WITH(NOLOCK) on a.contractid=m.contractid
				join acc_docdetails f WITH(NOLOCK) on m.docid=f.docid
				left join ren_contractdocmapping c WITH(NOLOCK) on a.contractid=c.contractid and c.type=20 
				and month(convert(datetime,c.receiveDate))=month(@date)
				and Year(convert(datetime,c.receiveDate))=Year(@date)
				where a.enddate<convert(float,@date) and a.PropertyID=@PropertyID and a.statusid in(426,427)
				and f.linkedaccdocdetailsid is  null and m.doctype=5 and month(convert(datetime,f.DocDate))=month(dateadd(month,-1,convert(datetime,a.enddate)))
				and Year(convert(datetime,f.DocDate))=Year(dateadd(month,-1,convert(datetime,a.enddate)))
		  
			ELSE
				select a.contractID,a.sno,convert(datetime,a.startdate) startdate,convert(datetime,a.enddate) enddate,convert(datetime,c.receiveDate) receiveDate,c.jvvoucherno
				,b.name unitName,p.name propertyName,a.unitid,a.Propertyid,a.TenantID,t.firstName
				,b.RentalReceivableAccountID UnitRecAcc,p.RentalReceivableAccountID PropRecAcc
				,b.ProvisionAccountID UnitProvsAcc,p.ProvisionAccountID PropProvsAcc,f.amount,c.CostCenterID,c.DocID
				 from ren_contract a WITH(NOLOCK)
				join ren_units b WITH(NOLOCK) on a.unitid=b.unitid
				join @table us on b.unitstatus=us.TypeID		
				join ren_Property p WITH(NOLOCK) on a.Propertyid=p.Nodeid
				join ren_tenant t WITH(NOLOCK) on t.TenantID=a.TenantID
				join REN_CONTRACTDOCMAPPING m WITH(NOLOCK) on a.contractid=m.contractid
				join acc_docdetails f WITH(NOLOCK) on m.docid=f.docid
				left join ren_contractdocmapping c WITH(NOLOCK) on a.contractid=c.contractid and c.type=20 
				and month(convert(datetime,c.receiveDate))=month(@date)
				and Year(convert(datetime,c.receiveDate))=Year(@date)
				where a.enddate<convert(float,@date) and a.statusid in(426,427)
				 and f.linkedaccdocdetailsid is  null and m.doctype=5 and month(convert(datetime,f.DocDate))=month(dateadd(month,-1,convert(datetime,a.enddate)))
				and Year(convert(datetime,f.DocDate))=Year(dateadd(month,-1,convert(datetime,a.enddate)))
  
		END
  
     
       
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
