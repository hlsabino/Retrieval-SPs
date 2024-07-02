USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmpAsOnStatus]
	@EmpSeqNo [int],
	@AsOnDate [datetime],
	@LangID [int] = 1,
	@AsOnStatus [nvarchar](500) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;
--------------------------------------------------------------------------------
DECLARE @TEmpSeqNo INT,@TAsOnDate DATETIME,@LType NVARCHAR(200)
SET @TEmpSeqNo=@EmpSeqNo
SET @TAsOnDate=CONVERT(DATETIME,CONVERT(VARCHAR(11),@AsOnDate,106))

SET @AsOnStatus=''
SET @LType=''

IF EXISTS(Select DOResign From COM_CC50051 WITH(NOLOCK) WHERE NodeID=@TEmpSeqNo AND DOResign IS NOT NULL)
BEGIN
	IF EXISTS(Select DORelieve From COM_CC50051  WITH(NOLOCK) WHERE NodeID=@TEmpSeqNo AND DORelieve IS NULL)
		SET @AsOnStatus='Pending Relieving'
	ELSE
		SET @AsOnStatus='Relieved'
END
ELSE
BEGIN
	IF EXISTS(  SELECT TOP 1 *
				FROM INV_DocDetails a WITH(NOLOCK) 
				JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
				JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
				WHERE a.CostCenterID=40072 and a.StatusID=369 AND ISDATE(ISNULL(dcAlpha3,''))=1  
				AND b.dcCCNID51=@TEmpSeqNo AND CONVERT(DATETIME,dcAlpha3)< @TAsOnDate
				AND ( d.dcAlpha1 IS NULL OR dcAlpha1='')
				AND d.dcAlpha16<>'Yes'
				ORDER BY CONVERT(DATETIME,dcAlpha3) DESC )
				SET @AsOnStatus='On Vacation - Not Reported'
	ELSE IF EXISTS(  SELECT TOP 1 *
				FROM INV_DocDetails a WITH(NOLOCK) 
				JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
				JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
				WHERE a.CostCenterID=40072 and a.StatusID=369 
				AND LEN(dcAlpha2)<=15 AND LEN(dcAlpha3)<=15
				AND ISDATE(ISNULL(dcAlpha2,''))=1 AND ISDATE(ISNULL(dcAlpha3,''))=1  
				AND b.dcCCNID51=@TEmpSeqNo AND @TAsOnDate BETWEEN CONVERT(DATETIME,dcAlpha2) AND CONVERT(DATETIME,dcAlpha3)
				AND d.dcAlpha16<>'Yes'
				ORDER BY CONVERT(DATETIME,dcAlpha2) DESC )
				SET @AsOnStatus='On Vacation'
	ELSE IF EXISTS(  SELECT TOP 1 *
				FROM INV_DocDetails a WITH(NOLOCK) 
				JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
				JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
				WHERE a.DocumentType=62 and a.StatusID=369 AND ISDATE(ISNULL(dcAlpha4,''))=1 AND ISDATE(ISNULL(dcAlpha5,''))=1 
				AND b.dcCCNID51=@TEmpSeqNo AND @TAsOnDate BETWEEN CONVERT(DATETIME,dcAlpha4)AND CONVERT(DATETIME,dcAlpha5)
				)
				BEGIN
					SELECT TOP 1 @LType=PC.Name 
					FROM INV_DocDetails a WITH(NOLOCK) 
					JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
					JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
					JOIN COM_CC50052 PC WITH(NOLOCK) ON PC.NodeID=b.dcCCNID52
					WHERE a.DocumentType=62 and a.StatusID=369 AND ISDATE(ISNULL(dcAlpha4,''))=1 AND ISDATE(ISNULL(dcAlpha5,''))=1 
					AND b.dcCCNID51=@TEmpSeqNo AND @TAsOnDate BETWEEN CONVERT(DATETIME,dcAlpha4)AND CONVERT(DATETIME,dcAlpha5)

				SET @AsOnStatus='On Leave - '+@LType
				END
	ELSE 
		SELECT @AsOnStatus=ISNULL(b.ResourceData,a.Status) From COM_Status a WITH(NOLOCK) 
							LEFT JOIN COM_LanguageResources b WITH(NOLOCK) on b.LanguageID=1 AND b.ResourceId=a.ResourceID 
		Where a.CostCenterID IN(1,50051) 
		AND a.StatusID=(Select StatusID From COM_CC50051 WITH(NOLOCK) Where NodeID=@TEmpSeqNo)
END


--SELECT @AsOnStatus as AsOnStatus

--------------------------------------------------------------------------------
SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH

----spPAY_GetEmpAsOnStatus 626,'08-May-2019',1,''
GO
