USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetProductBOMDetails]
	@PIDs [nvarchar](max),
	@COstCenterID [bigint],
	@LinkedCCID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @Sql nvarchar(Max),@DocumentLinkDefID bigint

		set @Sql='SELECT C.InvDocDetailsID,a.Quantity,a.Unit ,a.ProductID,P.ProductName,P.ProductCOde,U.UnitName,a.voucherno,a.Rate 
					from INV_DocDetails a WITH(NOLOCK)
					join INV_DocDetails B WITH(NOLOCK) on a.InvDocDetailsID =b.LinkedInvDocDetailsID
					join INV_DocDetails C WITH(NOLOCK) on C.DOCID =b.DOCID
					join INV_Product P WITH(NOLOCK) on  a.ProductID=P.ProductID
					join COM_UOM U WITH(NOLOCK) on  a.Unit=U.UOMID 
					WHere C.InvDocDetailsID in  ('+@PIDs+')
					order by a.DocSeqNo'
		
		exec(@Sql)
		
		
		
		SELECT @DocumentLinkDefID=DocumentLinkDeFID 
       FROM [COM_DocumentLinkDef]    WITH(NOLOCK) 
       where [CostCenterIDBase]=@LinkedCCID and [CostCenterIDLinked]=@COstCenterID
  
	   SELECT B.SysColumnName BASECOL,L.SysColumnName LINKCOL ,A.[VIEW],A.CostCenterColIDLinked  
	   FROM COM_DocumentLinkDetails A WITH(NOLOCK) 
	   JOIN ADM_CostCenterDef B WITH(NOLOCK) ON B.CostCenterColID=A.CostCenterColIDBase    
	   left JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON L.CostCenterColID=A.CostCenterColIDLinked    
	   WHERE A.DocumentLinkDeFID=@DocumentLinkDefID  and A.CostCenterColIDLinked<>0  
 

		 
	 
		

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

SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
