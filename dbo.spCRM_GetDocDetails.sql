USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetDocDetails]
	@InvDocDetailsID [bigint],
	@DocumentLinkDefID [bigint],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
      
SET NOCOUNT ON    
		
		SELECT DisTINCT B.SysColumnName BASECOL,L.SysColumnName LINKCOL   FROM COM_DocumentLinkDetails A    
		JOIN ADM_CostCenterDef B ON B.CostCenterColID=A.CostCenterColIDBase    
		left JOIN ADM_CostCenterDef L ON L.CostCenterColID=A.CostCenterColIDLinked    
		WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
		
 		SELECT * FROM INV_DocDetails a With(NOLOCK)		
		join COM_DocTextData d on a.InvDocDetailsID=d.InvDocDetailsID
		join COM_DocNumData dn on a.InvDocDetailsID=dn.InvDocDetailsID
		join COM_DocCCData dc on a.InvDocDetailsID=dc.InvDocDetailsID
		wHERE a.InvDocDetailsID=@InvDocDetailsID
        
    
COMMIT TRANSACTION    
SET NOCOUNT OFF;
GO
