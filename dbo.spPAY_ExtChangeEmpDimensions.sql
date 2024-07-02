USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExtChangeEmpDimensions]
	@CostCenterID [int] = NULL,
	@DocID [int] = NULL,
	@UserID [int] = NULL,
	@LangID [int] = NULL
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;

declare @StatusID INT
SELECT @StatusID=StatusID From INV_DocDetails WHERE CostCenterID=@CostCenterID AND DocID=@DocID
IF(@StatusID!=369)
	RETURN 1

declare @SQL nvarchar(max),@Cols NVARCHAR(MAX),@UpCols NVARCHAR(MAX),@HUpd NVARCHAR(MAX)
Create table #tb(dcCCNID51 INT,dcAlpha1 DateTime)

set @SQL='' SET @Cols='' SET @HUpd=''
set @UpCols=''
select	@SQL=@SQL+' '+SYSCOLUMNNAME+',',
		@Cols=@Cols+' '+SYSCOLUMNNAME+' INT,',
		@UpCols=@UpCols+''+replace(SYSCOLUMNNAME,'dcCCNID','CCNID')+'=case when T.'+SYSCOLUMNNAME+'!=1 then T.'+SYSCOLUMNNAME+' else '+replace(SYSCOLUMNNAME,'dcCCNID','CCNID')+' end'+',',
		@HUpd=@HUpd+' 
	IF EXISTS (	SELECT HistoryID 
				FROM COM_HistoryDetails hd 
				join #tb T on hd.CostCenterID=50051 AND hd.NodeID=T.dcCCNID51 AND HistoryCCID='+ CONVERT(NVARCHAR,(CONVERT(INT,replace(SYSCOLUMNNAME,'dcCCNID',''))+50000)) +' 
				AND ToDate IS NULL 
			  )
	BEGIN
			IF EXISTS (	SELECT HistoryID 
						FROM COM_HistoryDetails hd 
						join #tb T on hd.CostCenterID=50051 AND hd.NodeID=T.dcCCNID51 AND HistoryCCID='+ CONVERT(NVARCHAR,(CONVERT(INT,replace(SYSCOLUMNNAME,'dcCCNID',''))+50000)) +' 
						AND ToDate IS NULL AND hd.HistoryNodeID != T.'+SYSCOLUMNNAME+'
					  )
			BEGIN
					Update hd SET ToDate=Convert(INT,(DATEADD(day,-1,Convert(Datetime,T.dcAlpha1))))
					FROM COM_HistoryDetails hd
					join #tb T on hd.CostCenterID=50051 AND hd.NodeID=T.dcCCNID51 AND hd.HistoryCCID='+ CONVERT(NVARCHAR,(CONVERT(INT,replace(SYSCOLUMNNAME,'dcCCNID',''))+50000)) +' AND hd.ToDate IS NULL
					WHERE T.'+SYSCOLUMNNAME+'!=1

					INSERT INTO COM_HistoryDetails
					SELECT 50051,T.dcCCNID51,'+ CONVERT(NVARCHAR,(CONVERT(INT,replace(SYSCOLUMNNAME,'dcCCNID',''))+50000)) +',T.'+SYSCOLUMNNAME+',CONVERT(INT,T.dcAlpha1),NULL,'''',''admin'',CONVERT(FLOAT,GETDATE()),''admin'',CONVERT(FLOAT,GETDATE())
					From #tb T 
					WHERE T.'+SYSCOLUMNNAME+'!=1
			END
	END
	ELSE
	BEGIN
		INSERT INTO COM_HistoryDetails
		SELECT 50051,T.dcCCNID51,'+ CONVERT(NVARCHAR,(CONVERT(INT,replace(SYSCOLUMNNAME,'dcCCNID',''))+50000)) +',T.'+SYSCOLUMNNAME+',CONVERT(INT,T.dcAlpha1),NULL,'''',''admin'',CONVERT(FLOAT,GETDATE()),''admin'',CONVERT(FLOAT,GETDATE())
		From #tb T 
		WHERE T.'+SYSCOLUMNNAME+'!=1
	END
	 
	'
from
(
SELECT SYSCOLUMNNAME FROM ADM_COSTCENTERDEF 
WHERE COSTCENTERID=@CostCenterID
AND ISCOLUMNINUSE=1 AND ISVISIBLE=1 
AND SYSCOLUMNNAME IN 
(SELECT 'dc'+SYSCOLUMNNAME FROM ADM_COSTCENTERDEF 
WHERE COSTCENTERID=50051 AND ISCOLUMNINUSE=1 AND ISVISIBLE=1 AND SYSCOLUMNNAME LIKE 'CCNID%' AND SYSCOLUMNNAME <>'CCNID51')
) AS T

--select @Cols

if len(@Cols)>0
begin
	SET @Cols=' ALTER TABLE #tb ADD'+SUBSTRING(@Cols,1,LEN(@Cols)-1)
	--PRINT @Cols  
	EXEC sp_executesql @Cols
end

if len(@SQL)>0
begin
	set @SQL='	SELECT b.dcCCNID51,d.dcAlpha1,'+SUBSTRING(@SQL,1,LEN(@SQL)-1)+'
				FROM INV_DocDetails a WITH(NOLOCK) 
				JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
				JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
				WHERE a.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND a.DocID='+CONVERT(NVARCHAR,@DocID)+' and a.StatusID=369 '
	--print(@SQL)
	INSERT INTO #tb
	EXEC sp_executesql @SQL
	--select * from #tb
	
	set @SQL='update dcc
	set '+SUBSTRING(@UpCols,1,LEN(@UpCols)-1)+'
	from com_ccccdata dcc
	join #tb T on dcc.CostCenterID=50051 and T.dcCCNID51=dcc.NodeID'
	--print(@SQL)
	EXEC sp_executesql @SQL

	--print (@HUpd)
	EXEC sp_executesql @HUpd
end
DROP TABLE #tb

SET NOCOUNT OFF;  
RETURN 1  
END TRY  
BEGIN CATCH 
	ROLLBACK TRANSACTION   
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

----spPAY_ExtChangeEmpDimensions	41098,26165,1,1
GO
