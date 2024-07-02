USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetHistory]
	@PARENTFEATUREID [bigint],
	@PNodeID [bigint],
	@XML [xml],
	@UserName [nvarchar](50)
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @Dt float

	SET @Dt=CONVERT(FLOAT,GETDATE())
	
	INSERT INTO COM_HistoryDetails(CostCenterID,NodeID,HistoryCCID,HistoryNodeID,FromDate,ToDate,Remarks,CreatedBy,CreatedDate)
	SELECT @PARENTFEATUREID,@PNodeID,X.value('@CCID','int'),X.value('@NodeID','NVARCHAR(500)'),convert(float,X.value('@FromDate','DATETIME')),convert(float,X.value('@ToDate','DATETIME')),  
	   X.value('@Remarks','NVARCHAR(MAX)'),@UserName,@Dt  
	FROM @XML.nodes('/History/XML/Row') as Data(X)    
	WHERE X.value('@ID','bigint')=0 AND X.value('@Modified','NVARCHAR(10)')<>'2'

	------- UPDATE TODATE WHEN TODATE IS NOT ENTERED
	declare @rcnt int,@rid int,@HID2 int,@HID int,@CCID INT,@CCNID INT,@HCCID int,@FD INT
	Create Table #tmp1(RId int IDENTITY(1,1),HID int,CCID INT,CCNID INT,HCCID int,FD INT)
	INSERT INTO #tmp1
	select HistoryID,CostCenterID,NodeID,HistoryCCID,FromDate FROM COM_HistoryDetails WITH(NOLOCK) 
	WHERE CostCenterID=@PARENTFEATUREID AND NodeID= @PNodeID AND ToDate IS NULL
	ORDER BY CostCenterID,NodeID,HistoryCCID,FromDate DESC
	set @rcnt=@@ROWCOUNT
	set @rid=1 
	if(@rcnt>1)
	begin
		while(@rid<=@rcnt)
		begin
		SET @HID=0 SET @HID2=0
		Select @HID=HID,@CCID=CCID,@CCNID=CCNID,@HCCID=HCCID,@FD=FD FROM #tmp1 WHERE RId=@rid
		Select @HID2=HID FROM #tmp1 WHERE CCID=@CCID AND CCNID=@CCNID AND HCCID=@HCCID AND RId=@rid+1
		
		IF(@HID2 IS NOT NULL AND @HID2>0)
			Update COM_HistoryDetails SET ToDate=@FD-1 WHERE HistoryID=@HID2
		
		set @rid=@rid+2
		end
	end
	DROP TABLE #tmp1
	-------
	
	INSERT INTO [COM_HistoryDetails_History]
	SELECT *,'Update' FROM COM_HistoryDetails WITH(NOLOCK) 
	WHERE HistoryID IN ( SELECT X.value('@ID','bigint') FROM @XML.nodes('/History/XML/Row') as Data(X) WHERE X.value('@ID','bigint')!=0 AND X.value('@Modified','NVARCHAR(10)')<>'2' )
	
	UPDATE COM_HistoryDetails  
	SET HistoryNodeID=X.value('@NodeID','NVARCHAR(500)'),  
		FromDate=convert(float,X.value('@FromDate','DATETIME')),  
		ToDate=convert(float,X.value('@ToDate','DATETIME')),  
		Remarks=X.value('@Remarks','NVARCHAR(MAX)'),  
		ModifiedBy=@UserName,  
		ModifiedDate=@Dt  
	FROM COM_HistoryDetails C   
	INNER JOIN @XML.nodes('/History/XML/Row') as Data(X) ON convert(bigint,X.value('@ID','bigint'))=C.HistoryID  
	WHERE X.value('@ID','bigint')!=0
	
	
	INSERT INTO [COM_HistoryDetails_History]
	SELECT *,'Deleted' FROM COM_HistoryDetails WITH(NOLOCK)
	WHERE HistoryID IN ( SELECT X.value('@ID','bigint') FROM @XML.nodes('/History/XML/Row') as Data(X) WHERE X.value('@ID','bigint')!=0 AND X.value('@Modified','NVARCHAR(10)')='2' )
	
	DELETE FROM COM_HistoryDetails 
	WHERE HistoryID IN ( SELECT X.value('@ID','bigint') FROM @XML.nodes('/History/XML/Row') as Data(X) WHERE X.value('@ID','bigint')!=0 AND X.value('@Modified','NVARCHAR(10)')='2' )
	
	
	
		/*
   --If Action is DELETE then delete Attachments  
   DELETE FROM COM_Files  
   WHERE FileID IN(SELECT X.value('@AttachmentID','bigint')  
    FROM @XML.nodes('/AttachmentsXML/Row') as Data(X)  
    WHERE X.value('@Action','NVARCHAR(10)')='DELETE') */ 
    
GO
