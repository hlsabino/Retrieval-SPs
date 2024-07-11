USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetFollowUPDashBoard]
	@FromDate [datetime] = NULL,
	@EndDate [datetime] = NULL,
	@CreatedBy [nvarchar](300) = -100,
	@CCID [int] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON
	
	 
	--TO GET FOLLOW UP LATEST DATA
	DECLARE @COUNT INT,@I INT,@ccnodeid int,@table nvarchar(300),@Primarkey nvarchar(300),@sql nvarchar(max)
	
	if(@CCID=86)
	BEGIN
		set @table='CRM_Leads'
		SET @Primarkey='LeadID'
	END
	ELSE if(@CCID=89)
	BEGIN
		set @table='CRM_Opportunities'
		SET @Primarkey='OpportunityID'
	END
	
	create table #tbl(id int identity(1,1),code nvarchar(200),ccnodeid int,ccid int,subject nvarchar(300),
	Fdate datetime,comments nvarchar(max),isRepeat bit,CreatedBy nvarchar(300))

set @sql='
	insert into #tbl (code ,ccnodeid ,ccid ,subject ,Fdate ,comments,isRepeat,CreatedBy)
	 SELECT  Code,F.CCNodeID , F.CCID,Subject,CONVERT(DATETIME,F.DATE) FDate, F.Feedback Comments,0,F.CreatedBy FROM CRM_Feedback F WITH(NOLOCK) 
	INNER JOIN '+@table+' WITH(NOLOCK) ON '+@table+'.'+@Primarkey+'=F.CCNodeID AND F.CCID='+convert(nvarchar,@CCID)+'
	WHERE F.DATE BETWEEN '+convert(nvarchar,CONVERT(FLOAT,@FromDate))+' AND '+convert(nvarchar,CONVERT(FLOAT,@EndDate))+'
	group by Code,CCNodeID,CCID,Subject,F.DATE,Feedback,F.CreatedBy
	order by FDate desc '
	print @sql
	exec (@sql)
	 
	 CREATE TABLE #TBLDUP(ID INT IDENTITY(1,1),CCNODEID INT)
	 SELECT @COUNT=COUNT(*),@I=1 FROM #tbl WITH(NOLOCK) 
	 WHILE @I<=@COUNT
	 BEGIN
	 SELECT @ccnodeid=ccnodeid FROM #tbl WITH(NOLOCK) WHERE id=@I
	 IF(NOT EXISTS(SELECT * FROM #TBLDUP WITH(NOLOCK) WHERE CCNODEID=@ccnodeid))
	 BEGIN
		INSERT INTO #TBLDUP(CCNODEID) VALUES(@ccnodeid)
		UPDATE #tbl SET isRepeat=1 WHERE ccnodeid=@ccnodeid AND ccid=@CCID AND id<>@I
	 END
	 set @I=@I+1
	 END
	 select * from #tbl WITH(NOLOCK) WHERE ISREPEAT=0 
	 drop table #tbl
	 DROP TABLE #TBLDUP




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
