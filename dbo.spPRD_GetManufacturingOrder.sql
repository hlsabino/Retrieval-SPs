USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRD_GetManufacturingOrder]
	@MFGOrderID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
  
 SELECT *,CONVERT(datetime,OrderDate) MODate FROM PRD_MFGOrder  WITH(NOLOCK)  
  WHERE MFGOrderID=@MFGOrderID  
  
 SELECT * FROM  PRD_MFGOrderExtd WITH(NOLOCK) WHERE MFGOrderID=@MFGOrderID    
    
 SELECT * FROM   COM_CCCCDATA WITH(NOLOCK) WHERE [CostCenterID]=78 and  [NodeID]=@MFGOrderID    
      
 SELECT B.BOMName,B.ProductID,i.ProductName,i.ProductCode,M.* FROM  [PRD_MFGOrderBOMs] M WITH(NOLOCK)  
 left join PRD_BillOfMaterial B WITH(NOLOCK)on B.BOMID=M.BOMID  
 left join INV_Product i WITH(NOLOCK)on i.ProductID=B.ProductID  
  WHERE MFGOrderID=@MFGOrderID    
      
    SELECT B.ProductID,i.ProductName,i.ProductCode,B.BOMName,M.BOMID,CONVERT(datetime,StartDate) SDate,CONVERT(datetime,EstEndDate) EDate,CONVERT(datetime,ActualEndDate) Adate  
    ,W.* FROM  [PRD_MFGOrderWOs] W WITH(NOLOCK)  
    left join [PRD_MFGOrderBOMs] M WITH(NOLOCK) on M.MFGOrderBOMID=W.MFGOrderBOMID  
    left join PRD_BillOfMaterial B WITH(NOLOCK)on B.BOMID=M.BOMID    
    left join INV_Product i WITH(NOLOCK)on i.ProductID=B.ProductID    
    WHERE M.MFGOrderID=@MFGOrderID  
    
 SELECT distinct ReturnAmount,i.ProductCode,i.ProductName,R.ResourceName Machine,R.CreditAccount,R.DebitAccount  
 ,CR.AccountName CRAccountName,Dr.AccountName DRAccountName,BE.CreditAccountID,BE.DebitAccountID,BE.Name,  
 Bp.Quantity ActualQty,case when  Wo.DocID is not null and Wo.DocID>0 then Bpd.Unit else Bp.UOMID end as UOMID,
 case when  Wo.DocID is not null and Wo.DocID>0 then Bpd.Rate else bp.UnitPrice end as UnitPrice,BE.Value BaseAmount  
 , BR.Value MachineBaseAmount,BR.Hours Hrs,case when BR.Hours is not null and BR.Hours>0 and BR.Value is not null and W.hours is not null  
 then (BR.Value/BR.Hours)*W.[Hours] else 0 end as MachineAmount ,W.[Hours]  
 ,[MOWOProductID],W.[MFGOrderWOID],[WODetailsID],W.[BOMProductID],[ProdQuantity],W.[Wastage],[ReturnQty]  
      ,[NetQuantity],W.[ExpenseID],W.[ExchgRT],[Amount],W.ResourceID,CONVERT(datetime,StartDateTime) StartDateTime,CONVERT(datetime,EndDateTime) EndDateTime    
     ,W.[DocID],W.[DocTypeID],W.[Quantity],[RCTQuantity],  
     d.VoucherNo ReciptNo  
 ,d.DocPrefix Prefix,d.DocNumber,d.CostCenterID CCID,l.ResourceData,CONVERT(datetime,d.docdate) ReciptDate  
       
  FROM  [PRD_MOWODetails] W WITH(NOLOCK)  
 left join INV_Product i WITH(NOLOCK)on i.ProductID=W.BOMProductID  
 left join PRD_Resources R WITH(NOLOCK)on R.ResourceID=W.ResourceID  
  left join [PRD_MFGOrderWOs] Wo WITH(NOLOCK) on Wo.MFGOrderWOID=W.MFGOrderWOID  
    left join [PRD_MFGOrderBOMs] M WITH(NOLOCK) on M.MFGOrderBOMID=Wo.MFGOrderBOMID  
    left join PRD_BillOfMaterial B WITH(NOLOCK)on B.BOMID=M.BOMID   
    left join PRD_BOMProducts Bp WITH(NOLOCK)on Bp.BOMID=B.BOMID  and Bp.ProductID=W.BOMProductID 
       left join INV_DocDetails BPD on BPD.DocID=Wo.DocID and BPD.ProductID=W.BOMProductID and W.WODetailsID=1
    left join PRD_Expenses BE WITH(NOLOCK)on BE.ExpenseID=W.ExpenseID        
 left join ACC_Accounts CR WITH(NOLOCK)on CR.AccountID=BE.CreditAccountID  
 left join ACC_Accounts Dr WITH(NOLOCK)on Dr.AccountID=BE.DebitAccountID   
    left join PRD_BOMResources BR WITH(NOLOCK)on BR.BOMID=B.BOMID and BR.ResourceID=W.ResourceID    
  left join INV_DocDetails d on d.DocID=W.DocID  and W.WODetailsID=4
 left join ADM_RibbonView rib on rib.FeatureID=d.CostCenterID  
 left join COM_LanguageResources l on l.ResourceID=rib.ScreenResourceID and l.LanguageID=1   
 WHERE M.MFGOrderID=@MFGOrderID  
 order by W.MOWOProductID  
   
 SELECT * FROM  COM_Notes WITH(NOLOCK)   
 WHERE FeatureID=78 and  FeaturePK=@MFGOrderID  
   
 SELECT * FROM  COM_Files WITH(NOLOCK)   
 WHERE FeatureID=78 and  FeaturePK=@MFGOrderID  
  
   
 select distinct PRD_ProductionMethod.BOMID,PRD_ProductionMethod.Particulars,PRD_BillOfMaterial.BOMName,PRD_ProductionMethod.SequenceNo from PRD_ProductionMethod with(nolock)  
 left join PRD_BillOfMaterial with(nolock) on PRD_ProductionMethod.BOMID=PRD_BillOfMaterial.BOMID where MOID=@MFGOrderID   
 order by PRD_ProductionMethod.SequenceNo   
  
  
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
