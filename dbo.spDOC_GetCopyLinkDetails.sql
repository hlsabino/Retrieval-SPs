USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetCopyLinkDetails]
	@CostCenterIDBase [bigint],
	@CostCenterIDLinked [bigint],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    

	--Getting Linking Fields    
	SELECT B.SysColumnName BASECOL,L.SysColumnName LINKCOL ,A.CostCenterColIDLinked   FROM Com_CopyDocumentDetails A WITH(NOLOCK)   
	JOIN ADM_CostCenterDef B WITH(NOLOCK) ON B.CostCenterColID=A.CostCenterColIDBase    
	left JOIN ADM_CostCenterDef L WITH(NOLOCK) ON L.CostCenterColID=A.CostCenterColIDLinked    
	WHERE A.CostCenterIDBase=@CostCenterIDBase and A.CostCenterIDlinked= @CostCenterIDLinked and A.CostCenterColIDLinked<>0  

	--GETTING SYSCOLDATA FROM COSTCENTERDEF   
	SELECT DISTINCT C.UserColumnName,C.*,TBL.SysColumnName,TBL.width ACwidth,TBL.displayindex FROM ADM_COSTCENTERDEF C WITH(NOLOCK)    
	INNER JOIN  (  
		SELECT  case when L.SysColumnName IS null then B.SysColumnName else L.SysColumnName end as SysColumnName,a.width,a.displayindex  
		FROM Com_CopyDocumentDetails A WITH(NOLOCK)     
		JOIN ADM_CostCenterDef B WITH(NOLOCK)  ON B.CostCenterColID=A.CostCenterColIDBase    
		left JOIN ADM_CostCenterDef L WITH(NOLOCK)  ON L.CostCenterColID=A.CostCenterColIDLinked    
		WHERE A.CostCenterIDBase=@CostCenterIDBase and A.CostCenterIDlinked= @CostCenterIDLinked and A.CostCenterColIDLinked<>0 
		AND A.[VIEW]=1 AND A.SelectionType=1) AS TBL ON C.SysColumnName = TBL.SysColumnName  
	WHERE C.COSTCENTERID = @CostCenterIDLinked  

 
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
