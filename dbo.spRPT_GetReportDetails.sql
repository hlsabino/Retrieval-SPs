USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetReportDetails]
	@Type [int],
	@ReportID [int],
	@UserID [bigint] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

declare @XML XML

 IF @Type=1
 BEGIN
	set @XML=(Select ReportDefnXML From ADM_RevenUReports where ReportID=@ReportID)
	
	select @ReportID ReportID, X.value('CCID[1]','BIGINT') as CCID,F.Name,1 IsTreeFilter
	from @XML.nodes('PactRevenURpts/Filters/PreDataFetch/TreeFilter/FilterDef') as Data(X)
	inner join ADM_FEATURES F with(nolock) ON X.value('CCID[1]','BIGINT')=F.FeatureID
	and X.value('CCID[1]','BIGINT')<>300
	UNION
	select @ReportID ReportID, X.value('CCColID[1]','BIGINT') as CCID,X.value('Caption[1]','nvarchar(max)') as Name,0 IsTreeFilter
	from @XML.nodes('PactRevenURpts/Filters/PreDataFetch/FieldFilter/FilterDef') as Data(X)
	inner join ADM_FEATURES F with(nolock) ON abs(X.value('CCID[1]','BIGINT'))=F.FeatureID
	and X.value('CCID[1]','BIGINT')<>300 
 END
 ELSE IF @Type=2
 BEGIN
	set @XML=(Select ReportDefnXML From ADM_RevenUReports where ReportID=@ReportID)
	
	select X.value('ID[1]','nvarchar(max)') ID, X.value('Caption[1]','nvarchar(max)') Caption, X.value('Type[1]','nvarchar(max)') Type
	from @XML.nodes('PactRevenURpts/PactRevenURptDef/Columns/ColumnDef/Identity') as Data(X)
 END
 ELSE IF @Type=3
 BEGIN
	set @XML=(Select ReportDefnXML From ADM_RevenUReports where ReportID=@ReportID)
	
	select @ReportID ReportID, X.value('CCID[1]','BIGINT') as CCID,F.Name,1 IsTreeFilter,X.value('Condition[1]','nvarchar(max)') Condition
	from @XML.nodes('PactRevenURpts/Filters/PreDataFetch/TreeFilter/FilterDef') as Data(X)
	inner join ADM_FEATURES F with(nolock) ON X.value('CCID[1]','BIGINT')=F.FeatureID
	and X.value('CCID[1]','BIGINT')<>300
	UNION
	select @ReportID ReportID, X.value('CCColID[1]','BIGINT') as CCID,X.value('Caption[1]','nvarchar(max)') as Name,0 IsTreeFilter,X.value('Condition[1]','nvarchar(max)') Condition
	from @XML.nodes('PactRevenURpts/Filters/PreDataFetch/FieldFilter/FilterDef') as Data(X)
	inner join ADM_FEATURES F with(nolock) ON abs(X.value('CCID[1]','BIGINT'))=F.FeatureID
	and X.value('CCID[1]','BIGINT')<>300 
	
 END
 ELSE IF @Type=4
 BEGIN
	declare @I INT,@CNT INT
	DECLARE @TblDef AS TABLE(ID INT NOT NULL IDENTITY(1,1),CostCenterID INT,ChildName nvarchar(max),ParentCostCenterID INT,ParentName nvarchar(max))
	
	insert into @TblDef(CostCenterID,ParentCostCenterID)
	select D.CostCenterIDBase,D.CostCenterIDLinked from COM_DocumentLinkDef D with(nolock)
	where CostCenterIDLinked=@ReportID
	
	/*insert into @TblDef(CostCenterID,ChildName,ParentCostCenterID,ParentName)
	select C.CostCenterID,C.DocumentName,P.CostCenterID,P.DocumentName from COM_DocumentLinkDef D with(nolock)
	join ADM_DocumentTypes P on P.CostCenterID=D.CostCenterIDLinked
	join ADM_DocumentTypes C on C.CostCenterID=D.CostCenterIDBase
	where CostCenterIDLinked=@ReportID*/
	
	--select * from @TblDef
	SET @I=0
	WHILE(1=1)
	BEGIN		
		SET @CNT=(SELECT Count(*) FROM @TblDef)
		if @CNT>10000
			break
			
		INSERT INTO @TblDef(CostCenterID,ParentCostCenterID)
		select D.CostCenterIDBase,D.CostCenterIDLinked
		from COM_DocumentLinkDef D with(nolock)
		JOIN @TblDef T ON T.CostCenterID=D.CostCenterIDLinked AND ID>@I and ID<=@CNT
		left join @TblDef TD ON TD.ParentCostCenterID=D.CostCenterIDLinked
		where TD.CostCenterID IS NULL
		group by D.CostCenterIDBase,D.CostCenterIDLinked
		/*
		INSERT INTO @TblDef(CostCenterID,ChildName,ParentCostCenterID,ParentName)
		select C.CostCenterID,C.DocumentName,P.CostCenterID,P.DocumentName
		from COM_DocumentLinkDef D with(nolock)
		join ADM_DocumentTypes P on P.CostCenterID=D.CostCenterIDLinked
		join ADM_DocumentTypes C on C.CostCenterID=D.CostCenterIDBase
		JOIN @TblDef T ON T.CostCenterID=P.CostCenterID AND ID>@I and ID<=@CNT
		left join @TblDef TD ON TD.ParentCostCenterID=P.CostCenterID
		where TD.CostCenterID IS NULL
		group by C.CostCenterID,C.DocumentName,P.CostCenterID,P.DocumentName*/
	
	    IF @CNT=(SELECT Count(*) FROM @TblDef)
			BREAK
			
		SET @I=@CNT
	END
	
	select CostCenterID from @TblDef
	where CostCenterID!=@ReportID
	group by CostCenterID ,ChildName
	order by CostCenterID
 END
 
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
