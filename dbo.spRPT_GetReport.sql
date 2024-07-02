USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetReport]
	@Type [int] = 0,
	@ReportID [int],
	@UserID [int] = 1,
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	IF @Type=0
	BEGIN
		SELECT *,0 Sno,null ShowTitle,null ReportTitle,null ShowColumns,null ShowTotals,null MapXML
		FROM ADM_RevenUReports WITH(NOLOCK) WHERE ReportID=@ReportID
		UNION ALL
		SELECT R.*,Sno,M.ShowTitle,M.ReportTitle,M.ShowColumns,M.ShowTotals,M.MapXML
		FROM ADM_RevenUReports R WITH(NOLOCK)
		INNER JOIN ADM_ReportsMap M WITH(NOLOCK) ON R.ReportID=M.ChildReportID AND M.ParentReportID=@ReportID
		ORDER BY Sno
		
		SELECT M.ReportID,M.ActionType FROM ADM_ReportsUserMap M with(nolock) 	   
	   WHERE M.ReportID=@ReportID AND (@UserID=1 OR @RoleID=1 OR (UserID=@UserID OR RoleID=@RoleID 
		OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)))
		UNION
		SELECT SR.ReportID,M.ActionType FROM ADM_ReportsUserMap M with(nolock)
		inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1
	   inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
	   WHERE SR.ReportID=@ReportID AND (@UserID=1 OR @RoleID=1 OR (UserID=@UserID OR RoleID=@RoleID 
		OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)))
		
		SELECT * FROM [COM_APIFieldsMapping] WITH(NOLOCK) 
		WHERE CostCenterID=50 AND Mode=@ReportID
	END
	ELSE IF @Type=1--Getting UnitStatus From Com_Lookup in Floor Wise Report (Status)
	BEGIN
		declare @XML xml,@StatusDim int,@Query nvarchar(max)
		set @XML=(Select CustomPreferences From ADM_RevenUReports where ReportID=@ReportID)
		set @StatusDim=0
		select @StatusDim=X.value('StatusDimension[1]','INT')
		from @XML.nodes('XML') as Data(X)
		if @StatusDim is not null and @StatusDim>50000
		begin
			select @Query=TableName from ADM_Features with(nolock) where FeatureID=@StatusDim
			set @Query='SELECT NodeID,Name FROM '+@Query+' with(nolock) where IsGroup=0 order by lft'
			exec(@Query)
		end
		else
			select NodeID,Name from com_lookup WITH(NOLOCK) where LookUpType=46
			
	END
	ELSE IF @Type=2
	BEGIN
		declare @TblVAT as Table(ReportID int, ReportName nvarchar(max))
		insert into @TblVAT
		select ReportID,ReportName from ADM_RevenuReports R with(nolock)
		Where DefaultPreferences like '%<UTILREPORT>VATAED1</UTILREPORT>%' 
		or DefaultPreferences like '%<UTILREPORT>VATSAS1</UTILREPORT>%'
		or DefaultPreferences like '%<UTILREPORT>VATFATSupplyList</UTILREPORT>%'
		or DefaultPreferences like '%<UTILREPORT>VATFATPurchaseList</UTILREPORT>%'

		SELECT T.ReportID,T.ReportName FROM ADM_ReportsUserMap M with(nolock)
		JOIN @TblVAT T on T.ReportID=M.ReportID
		WHERE M.ActionType=1 AND (@UserID=1 OR @RoleID=1 OR (UserID=@UserID OR RoleID=@RoleID 
		OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)))
		UNION
		SELECT T.ReportID,T.ReportName FROM ADM_ReportsUserMap M with(nolock)
		inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1
		inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
		JOIN @TblVAT T on T.ReportID=SR.ReportID
		WHERE M.ActionType=1 AND (@UserID=1 OR @RoleID=1 OR (UserID=@UserID OR RoleID=@RoleID 
		OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)))
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
