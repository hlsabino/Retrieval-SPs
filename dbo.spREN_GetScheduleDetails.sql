USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetScheduleDetails]
	@ContracID [int],
	@Docdate [datetime],
	@SchEventID [int],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY         
SET NOCOUNT ON        
    declare @nextDate datetime,@sql nvarchar(max),@ccid int,@invccid int,@islast int,@RentNodeid int,@CostcenterID int
    
    set @islast=0
	SELECT top 1 @CostcenterID=a.CostCenterID,@nextDate=CONVERT(DATETIME, E.EventTime)
	FROM COM_SchEvents E with(nolock)
	JOIN COM_Schedules S with(nolock) ON E.ScheduleID=S.ScheduleID
	JOIN COM_CCSchedules CC with(nolock) ON S.ScheduleID=CC.ScheduleID
	JOIN COM_DocID AS D with(nolock) on D.ID=CC.NodeID
	JOIN [REN_ContractDocMapping] AS DM on D.ID=DM.DocID
	join ren_contract a WITH(NOLOCK) on dm.[ContractID]=a.[ContractID] 
	WHERE  CC.CostCenterID>=40001 AND CC.CostCenterID<= 50000
	and S.FreqType=0 and a.contractid=@ContracID
	and CONVERT(DATETIME, E.EventTime)>@Docdate
	and DM.IsAccDoc=0 AND E.NODEID>0 AND E.CostCenterID IS NULL
	ORDER BY EventTime
	if(@nextDate is null)
		select @CostcenterID=CostCenterID,@nextDate=CONVERT(DATETIME,EndDate) from ren_contract WITH(NOLOCK) where contractid=@ContracID
			
	if not exists(SELECT  E.EventTime
	FROM COM_SchEvents E with(nolock)
	JOIN COM_Schedules S with(nolock) ON E.ScheduleID=S.ScheduleID
	JOIN COM_CCSchedules CC with(nolock) ON S.ScheduleID=CC.ScheduleID
	JOIN COM_DocID AS D with(nolock) on D.ID=CC.NodeID
	JOIN [REN_ContractDocMapping] AS DM on D.ID=DM.DocID
	join ren_contract a WITH(NOLOCK) on dm.[ContractID]=a.[ContractID] 
	WHERE  CC.CostCenterID>=40001 AND CC.CostCenterID<= 50000
	and S.FreqType=0 and a.contractid=@ContracID	and e.SchEventID<>@SchEventID
	and DM.IsAccDoc=0 AND E.StatusID=1 AND E.NODEID>0 AND E.CostCenterID IS NULL)
		set @islast=1
	
	select @ccid=value from adm_globalpreferences with(nolock) where name ='DepositLinkDimension'
	and value is not null and value<>'' and isnumeric(value)=1

	exec [spDOC_GetNode] @ccid,'Rent',0,0,1,'GUID','Admin',1,1,@RentNodeid output

	select @nextDate nextDate,@islast islastInv,@RentNodeid RentNodeid
		
	if(@ccid>50000)
	BEGIN
		if(@CostcenterID=95)
			select @invccid=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
			where CostCenterID=95 and Name='ContractSalesInvoice'      
		ELSE if(@CostcenterID=104)
			select @invccid=CONVERT(int,Value) from COM_CostCenterPreferences WITH(nolock)      
			where CostCenterID=104 and Name='PurchasePInvoice'      
			
		set @ccid=@ccid-50000
				
		set @sql='SELECT dcccnid'+convert(nvarchar,@ccid)+' PartID,sum(gross) TotInv,count(gross) cnt,sum(dcCalcNum53) TotVat
		FROM INV_DocDetails a with(nolock)
		join com_docccdata b on a.INVDocDetailsid=b.INVDocDetailsid
		join com_docnumdata c on a.INVDocDetailsid=c.INVDocDetailsid
		where dynamicINVDocDetailsid is null and a.StatusID<>376 and costcenterid='+convert(nvarchar,@invccid)+' and refccid='+convert(nvarchar,@CostcenterID)+' and refnodeid='+convert(nvarchar,@ContracID)+'
		group by dcccnid'+convert(nvarchar,@ccid)			
		exec(@sql)
		
		select CCID,CCNodeID,Amount,VatAmount from REN_ContractParticulars a WITH(NOLOCK)
		where [ContractID]=@ContracID
		
	END	
	

    
SET NOCOUNT OFF;        
RETURN 1        
END TRY        
BEGIN CATCH          
 --Return exception info [Message,Number,ProcedureName,LineNumber]          
	IF ERROR_NUMBER()=50000        
	BEGIN        
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
	END        
	ELSE        
	BEGIN        
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine        
		FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=-999 AND LanguageID=@LangID        
	END              
SET NOCOUNT OFF          
RETURN -999           
END CATCH
	
GO
