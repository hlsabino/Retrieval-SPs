USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetTDSData]
	@DOCUMENTID [bigint],
	@NODEID [bigint],
	@DocDate [datetime],
	@ccxml [nvarchar](max),
	@QUERY [nvarchar](max) = '' OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON;   
	
	DECLARE @TDSRecDocs NVARCHAR(MAX),@TDSBasedDim NVARCHAR(MAX),@TDSRecBased INT
	,@ccWhere NVARCHAR(MAX),@TEMPCOLUMN NVARCHAR(32),@sql NVARCHAR(MAX), @XML XML,@AccountIDs NVARCHAR(MAX)
	
	DECLARE @dims TABLE(ID INT IDENTITY(1,1),CCID int,NodeID bigint)
	set @XML=@ccxml
	insert into @dims
	SELECT X.value('@CostCenterID','int'),X.value('@NODEID','bigint')
	from @XML.nodes('/XML/Row') as Data(X) 
	
	select @TDSRecDocs=value from adm_globalpreferences with(nolock)
	where name='TDSRecDocs'
	
	select @TDSBasedDim=value from adm_globalpreferences with(nolock)
	where name='TDSBasedDim' AND value<>'0'
	
    SET @TDSRecBased=0
	select @TDSRecBased=CONVERT(INT,value) from adm_globalpreferences with(nolock)
	where name='TDSRecBased' AND value<>''

	set @ccWhere=''
	
	IF (@TDSBasedDim IS NOT NULL AND @TDSBasedDim<>'')
	BEGIN
		select TOP 1 @ccWhere='JOIN COM_DocCCData DCD with(nolock) ON DCD.'+(CASE WHEN @TDSRecBased=1 THEN 'Inv' ELSE 'Acc' END)+'DocDetailsID=ACD.'+(CASE WHEN @TDSRecBased=1 THEN 'Inv' ELSE 'Acc' END)+'DocDetailsID and DCD.dcCCNID'+convert(nvarchar,(CCID-50000))+'='+convert(nvarchar,NodeID)
		from @dims where CONVERT(NVARCHAR,CCID)=@TDSBasedDim
        
        SET @TEMPCOLUMN=''
		SELECT @TEMPCOLUMN=SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@DOCUMENTID AND UserColumnName='TDS_Applicable'
		
		IF (@TEMPCOLUMN IS NOT NULL AND @TEMPCOLUMN<>'')
		BEGIN
			IF EXISTS (SELECT * FROM COM_HistoryDetails WITH(NOLOCK) WHERE CostCenterID=400 AND CONVERT(FLOAT,@DocDate) BETWEEN FromDate AND ToDate
			AND CONVERT(NVARCHAR,HistoryCCID)=@TDSBasedDim AND HistoryNodeID=(CASE WHEN @TDSBasedDim='4' THEN 4 ELSE (select TOP 1 NodeID from @dims where CONVERT(NVARCHAR,CCID)=@TDSBasedDim) END))
				set @QUERY=@QUERY+ ',''YES'' '+@TEMPCOLUMN
			ELSE  
				set @QUERY=@QUERY+ ',''NO'' '+@TEMPCOLUMN
		END
	END

	SELECT @sql=N'SET @AccountIDs=( SELECT '','' + CONVERT(NVARCHAR,AP2.AccountID) FROM '+LCD.SysTableName+' AP1 WITH(NOLOCK) 
	JOIN '+LCD.SysTableName+' AP2 WITH(NOLOCK) ON AP2.'+LCD.SysColumnName+'=AP1.'+LCD.SysColumnName+'
	WHERE AP1.AccountID='+CONVERT(NVARCHAR,@NODEID)+' AND AP2.AccountID<>'+CONVERT(NVARCHAR,@NODEID)+' AND AP1.'+LCD.SysColumnName+' IS NOT NULL AND AP1.'+LCD.SysColumnName+'<>''''
	FOR XML PATH ('''') )'
	FROM ADM_CostCenterDef CD WITH(NOLOCK) 
	JOIN ADM_CostCenterDef LCD WITH(NOLOCK) ON LCD.CostCenterColID=CD.LinkData
	WHERE CD.CostCenterID=@DOCUMENTID AND CD.SysColumnName='dcAlpha183'

	EXEC sp_executesql @sql,N'@AccountIDs NVARCHAR(MAX) OUTPUT',@AccountIDs OUTPUT

	IF @AccountIDs IS NOT NULL
		SET @AccountIDs=CONVERT(NVARCHAR,@NODEID)+@AccountIDs
	ELSE
		SET @AccountIDs=CONVERT(NVARCHAR,@NODEID)
	
	IF (@TDSRecBased=1)
		SET @ccWhere=@ccWhere+' where (ACD.CreditAccount IN ('+@AccountIDs+') OR ACD.DebitAccount IN ('+@AccountIDs+'))'
	ELSE
		SET @ccWhere=@ccWhere+' where ACD.DebitAccount IN ('+@AccountIDs+')'

	IF (@TDSRecDocs IS NOT NULL AND @TDSRecDocs<>'')
	BEGIN
		SET @TEMPCOLUMN=''
		SELECT @TEMPCOLUMN=SysColumnName FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@DOCUMENTID AND UserColumnName='TDS_AggregateAmt'
		
		IF (@TEMPCOLUMN IS NOT NULL AND @TEMPCOLUMN<>'')
		BEGIN
			SET @sql='01/APR/'
			IF Month(@DocDate)<4
				SET @sql=@sql+CONVERT(NVARCHAR,Year(@DocDate)-1)
			ELSE
				SET @sql=@sql+CONVERT(NVARCHAR,Year(@DocDate))

		    IF @DocDate>=CONVERT(DATETIME,'01/JUL/2021')
			    set @QUERY=@QUERY+ ',ISNULL((SELECT SUM(ISNULL(CASE WHEN ACD.'+(CASE WHEN @TDSRecBased=1 THEN 'DebitAccount' ELSE 'CreditAccount' END)+' IN ('+@AccountIDs+') THEN -ACD.AMOUNT ELSE ACD.AMOUNT END,0)) FROM ACC_DocDetails ACD with(nolock) '+@ccWhere+' and ACD.DocDate BETWEEN '+CONVERT(NVARCHAR,CONVERT(FLOAT,CONVERT(DATETIME,@sql)))+' AND '+CONVERT(NVARCHAR,CONVERT(FLOAT,@DocDate))+' and ACD.CostCenterID in ('+@TDSRecDocs+') and ACD.StatusID=369),0) '+@TEMPCOLUMN
		    ELSE
                set @QUERY=@QUERY+ ',0 '+@TEMPCOLUMN
        END

	END 
GO
