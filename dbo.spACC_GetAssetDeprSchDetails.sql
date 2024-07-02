USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetAssetDeprSchDetails]
	@AssetID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    
 
    select top(1) A.AssetID,   
     A.AssetCode,   
     A.AssetName,  
     A.StatusID,  
     A.EstimateLife,   
     A.SalvageValueType,  
     A.SalvageValueName,  
     A.SalvageValue, 
     A.IsComponent,A.PurchaseValue,
     A.DeprStartValue,A.PreviousDepreciation,   
	 case when (A.DeprStartDate is null or A.DeprStartDate=0) then null else (convert(datetime,A.DeprStartDate)) end DeprStartDate,   
     case when (A.DeprEndDate is null or A.DeprEndDate=0) then null else (convert(datetime,A.DeprEndDate)) end  DeprEndDate,   
	 case when (A.OriginalDeprStartDate is null or A.OriginalDeprStartDate=0) then null else (convert(datetime,A.OriginalDeprStartDate)) end OriginalDeprStartDate,

     A.AssetNetValue,   
     A.CalcDate,   
	 A.PreviousDepreciation,   
     A.Period,    
     A.DepreciationMethod,   
     A.AveragingMethod,
     A.IsDeprSchedule,--ACC_AssetChanges.AssetNewValue as CurrentValue ,
     A.UOM,A.IncludeSalvageInDepr
     from ACC_Assets A with(nolock)
     where A.AssetID=@AssetID 
     
     
--Depreciation Values     
 SELECT   dep.DPScheduleID ScheduleID,  CONVERT(DATETIME, dep.DeprStartDate ) AS FromDate  
      ,CONVERT(DATETIME, dep.DeprEndDate ) AS ToDate  
      , dep.PurchaseValue   
      , dep.DepAmount AS DeprAmt   
      , dep.AccDepreciation AS accmDepr   
      , dep.AssetNetValue AS NetValue  
   ,dep.DocID   
      ,dep.VoucherNo   
      ,dep.DocDate   
       ,dep.ActualDeprAmt
      ,accdoc.CostCenterID CostCenterID  
      ,accdoc.DocPrefix  DocPrefix  
       ,accdoc.DocNumber  DocNumber  
      FROM  [ACC_AssetDepSchedule] dep with(nolock)   
      LEFT JOIN Com_Status Sts with(nolock) on  Sts.StatusID =  dep.StatusID    
       LEFT JOIN acc_docdetails accdoc with(nolock) on dep.docid = accdoc.docid  and accdoc.docseqno = 1   
       LEFT join ADM_DocumentTypes ADF with(nolock) on accdoc.CostCenterID = ADF.CostCenterID    
      where dep.AssetID=@AssetID  order by CONVERT(DATETIME, dep.DeprStartDate ) asc   
        
       
   select A.*,convert(datetime,A.ChangeDate) as Date  from ACC_AssetChanges A with(nolock) where A.AssetID=@AssetID order by A.ChangeDate
      
       
    select top(1) convert(datetime,ACC_Assets.DeprStartDate) as DepStartDate,ACC_AssetChanges.AssetNewValue ,ACC_AssetChanges.AssetChangeID  
    from ACC_Assets with(nolock) 
    LEFT JOIN ACC_AssetChanges with(nolock) on ACC_Assets.AssetID=ACC_AssetChanges.AssetID   
    where ACC_Assets.AssetID=@AssetID order by ACC_AssetChanges.AssetChangeID desc  

   
        
	select *,case when [Date] is null then null else convert(datetime,[Date]) end as Datee,  
	case when NextServiceDate is null then null else convert(datetime,NextServiceDate) end as MaintenanceNextServiceDate,  
	case when StartDate is null then null else convert(datetime,StartDate) end as InsuranceStartDate,  
	case when EndDate is null then null else convert(datetime,EndDate) end as InsuranceEndDate  
	from ACC_AssetsHistory with(nolock) where AssetManagementID=@AssetID  

      
      
   
SET NOCOUNT OFF;    
RETURN @AssetID    
END TRY    
BEGIN CATCH      
 IF ERROR_NUMBER()=50000    
 BEGIN    
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
SET NOCOUNT OFF      
RETURN -999       
END CATCH      
GO
