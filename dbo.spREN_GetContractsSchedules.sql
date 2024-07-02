USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetContractsSchedules]
	@PropertyID [int] = 0,
	@Fromdate [datetime],
	@Todate [datetime],
	@stat [int],
	@SELECTQRY [nvarchar](max),
	@FROMQRY [nvarchar](max),
	@strwhere [nvarchar](max),
	@costcenterid [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    

	DECLARE @From FLOAT,@To FLOAT,@sql nvarchar(max)
	SET @From=CONVERT(FLOAT,@FromDate)
	SET @To=CONVERT(FLOAT,@ToDate)
	
	
	
	set @sql='SELECT S.ScheduleID,CC.NodeID,D.DocNo VoucherNo,CONVERT(DATETIME, E.EventTime) AS EventTime, CONVERT(NVARCHAR, S.FreqType) AS FreqType,
					E.StatusID AS Status, CC.CostCenterID,E.SchEventID,E.GUID,E.SubCostCenterID,E.NODEID sno,AttachmentID,S.RecurMethod
					,convert(datetime,a.startdate) startdate,convert(datetime,a.enddate) enddate,a.[ContractID],b.name unitName,p.name propertyName,a.unitid,a.Propertyid,a.TenantID,t.firstName,POstedvoucherno,PD.ID PostedDocid
					,(select isnull(sum(gross),0) from inv_docdetails WITH(NOLOCK)
					where docid=D.ID and costcenterid=CC.CostCenterID and (CanRecur is null or CanRecur=1)) Amount
		'+@SELECTQRY+' FROM COM_SchEvents E with(nolock)
		JOIN COM_Schedules S with(nolock) ON E.ScheduleID=S.ScheduleID
		JOIN COM_CCSchedules CC with(nolock) ON S.ScheduleID=CC.ScheduleID
		JOIN COM_DocID AS D with(nolock) on D.ID=CC.NodeID
		JOIN [REN_ContractDocMapping] AS DM on D.ID=DM.DocID
		join ren_contract a WITH(NOLOCK) on dm.[ContractID]=a.[ContractID] '
		if(@FROMQRY!='' or @strwhere!='')
		  set @sql=@sql+' join COM_ccCCData L with(nolock) on a.ContractID=L.NodeID and l.CostCenterID='+convert(nvarchar,@costcenterid)+@FROMQRY

		set @sql=@sql+' join ren_units b WITH(NOLOCK) on a.unitid=b.unitid	
		join ren_Property p WITH(NOLOCK) on a.Propertyid=p.Nodeid
		join ren_tenant t WITH(NOLOCK) on t.TenantID=a.TenantID	
		left JOIN COM_DocID AS PD with(nolock) on PD.DocNo=e.POstedvoucherno
		WHERE  CC.CostCenterID>=40001 AND CC.CostCenterID<= 50000
		and S.FreqType=0 and a.StatusID in(426,427)
		and DM.IsAccDoc=0 AND E.StatusID='+convert(nvarchar,@stat)+' AND E.NODEID>0 AND E.CostCenterID IS NULL
		and E.EventTime Between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)
		+' and a.CostCenterID='+convert(nvarchar,@costcenterid)
		set @sql=@sql+@strwhere
		
		if(@PropertyID>0)
			set @sql=@sql+'and a.Propertyid='+convert(nvarchar(max),@PropertyID)
			
		set @sql=@sql+' ORDER BY EventTime'
		print @sql
	exec(@sql)
	
       
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
