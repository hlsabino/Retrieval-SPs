USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetUnApprovedDocsCount]
	@DCCWhere [nvarchar](max),
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON;          
       
	DECLARE @SQL NVARCHAR(MAX),@LocWhere NVARCHAR(MAX)
	,@INVJOIN NVARCHAR(MAX),@ACCJOIN NVARCHAR(MAX)
	,@Dimensions nvarchar(max),@JOIN nvarchar(max),@WHERE nvarchar(max)
	
	if @DCCWhere!='' --OR @Dimensions!='' OR @DIMCOLSJOIN!=''
	BEGIN    
		SET @INVJOIN=' INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.InvDocDetailsID=D.InvDocDetailsID'
		SET @ACCJOIN=' INNER JOIN COM_DocCCData DCC with(nolock) ON DCC.AccDocDetailsID=D.AccDocDetailsID'
	END
	ELSE
	BEGIN
		SET @INVJOIN=''
		SET @ACCJOIN=''
	END
	
	create table #TblUsrWF(WID int,LevelID int,Type int,CtWef float,LvWef int)
	EXEC spRPT_GetReportData @Type=8,@Param1=@UserID,@strXML=null,@RoleID=@RoleID

	SET @SQL='SELECT D.VoucherNo
	FROM INV_DocDetails D with(nolock)'+@INVJOIN+',#TblUsrWF WF
	WHERE WF.WID=D.WorkflowID and WF.LevelID>D.WorkFlowLevel and (D.StatusID=371 or D.StatusID=372 or D.StatusID=441) AND (WF.Type=1 or (D.WorkFlowLevel+1=WF.LevelID and D.StatusID!=372)) 
	'+@DCCWhere+'
	GROUP BY D.VoucherNo
	UNION ALL
	SELECT D.VoucherNo
	FROM ACC_DocDetails D with(nolock)'+@ACCJOIN+',#TblUsrWF WF
	WHERE D.InvDocDetailsID is null and WF.WID=D.WorkflowID and WF.LevelID>D.WorkFlowLevel and (D.StatusID=371 or D.StatusID=372 or D.StatusID=441) AND (WF.Type=1 or (D.WorkFlowLevel+1=WF.LevelID and D.StatusID!=372)) 
	'+@DCCWhere+'
	GROUP BY D.VoucherNo'
	
	SET @SQL='select count(*) CNT from
	('+@SQL+')as T
	DROP TABLE #TblUsrWF'

  --print(@SQL)
 
EXEC(@SQL)    
      
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
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine        
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
  END        
 SET NOCOUNT OFF          
 RETURN -999           
END CATCH         
GO
