USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetQueryDefnScreenDetails]
	@Type [int],
	@CostCenterID [int],
	@ViewID [bigint] = 0,
	@ViewName [nvarchar](100) = NULL,
	@Reports [nvarchar](max) = NULL,
	@Docs [nvarchar](max) = NULL,
	@Groups [nvarchar](max) = NULL,
	@Roles [nvarchar](max) = NULL,
	@Users [nvarchar](max) = NULL,
	@ShowPriceChart [bit] = NULL,
	@HeaderFields [nvarchar](max) = NULL,
	@ListViewID [int] = NULL,
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

	IF @Type=0
	BEGIN
		--Groups
		SELECT GID,GroupName FROM COM_Groups WITH(NOLOCK)
		Group By GID,GroupName
		HAVING GroupName IS NOT NULL
		ORDER BY GroupName
			
		--Roles
		SELECT RoleID, Name FROM ADM_PRoles WITH(NOLOCK)
		WHERE StatusID=434
		ORDER BY Name
		
		--Getting All Users
		SELECT UserID,UserName FROM ADM_Users WITH(NOLOCK)
		WHERE StatusID=1
		ORDER BY UserName 
		
		SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE (FEATUREID>50000 OR FEATUREID IN (2,3,92,93,94,95,98,103,104,129)) and ISEnabled=1
		ORDER BY FEATUREID
	END
	ELSE IF @Type=1
	BEGIN
		SELECT ViewID,ViewName FROM ADM_QueryDefn WITH(NOLOCK)
		WHERE CostCenterID=@CostCenterID
		GROUP BY ViewID,ViewName
		
		IF @CostCenterID=98
			SELECT ListViewTypeID,ListViewName FROM ADM_ListView WITH(NOLOCK) WHERE CostCenterID=3
		ELSE
			SELECT ListViewTypeID,ListViewName FROM ADM_ListView WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
			
		if(@CostCenterID=3)	
		BEGIN
			select  L.ResourceData FIELDNAME, a.CostCenterColID COSTCENTERCOLID, a.SysTableName 
			from adm_costcenterdef a WITH(NOLOCK)
			join com_languageresources l WITH(NOLOCK) on a.resourceid=l.resourceid and l.languageid=1
			where CostCenterID=3 and IsColumnInUse=1 
			--Getting Documents.        
			SELECT D.DocumentTypeID,D.CostCenterID,D.DocumentType,D.DocumentAbbr,D.DocumentName,D.IsUserDefined,D.IsInventory      
			FROM ADM_DocumentTypes D WITH(NOLOCK)        
			ORDER BY D.DocumentType Asc      
		END
	END
	ELSE IF @Type=2--To Get Query Defn Data
	BEGIN
		SELECT R.ReportID,R.ReportName,max(Q.HeaderFields) HeaderFields,Q.GroupLevel,max(Q.ReportXML) ReportXML,Q.Shortcut
		FROM ADM_RevenUReports R WITH(NOLOCK), ADM_QueryDefn Q WITH(NOLOCK)
		WHERE Q.ReportID=R.ReportID AND CostCenterID=@CostCenterID AND Q.ViewID=@ViewID
		GROUP BY R.ReportID,R.ReportName,Q.GroupLevel,Q.Shortcut
		ORDER BY MIN(Q.QueryID)
		
		SELECT UserID,RoleID,GroupID 
		FROM ADM_QueryDefn WITH(NOLOCK) 
		WHERE CostCenterID=@CostCenterID AND ViewID=@ViewID
		group by UserID,RoleID,GroupID
		
		SELECT D.CostCenterID,D.DocumentName   
		FROM ADM_DocumentTypes D WITH(NOLOCK), ADM_QueryDefn Q WITH(NOLOCK)
		WHERE Q.DocumentID=D.CostCenterID AND Q.CostCenterID=@CostCenterID AND Q.ViewID=@ViewID
		GROUP BY D.CostCenterID,D.DocumentName  
		
		SELECT TOP 1 ShowPriceChart,ListViewID FROM ADM_QueryDefn WITH(NOLOCK)
		WHERE ViewID=@ViewID
	END
	ELSE IF @Type=3--INSERT/UPDATE
	BEGIN
	BEGIN TRANSACTION
		DECLARE @Dt FLOAT,@XML XML
		DECLARE @TblApp AS TABLE(G BIGINT NOT NULL DEFAULT(0),R BIGINT NOT NULL DEFAULT(0),U BIGINT NOT NULL DEFAULT(0))
		DECLARE @TblReports AS TABLE(ReportID BIGINT,GroupLevel BIT,Shortcut NVARCHAR(100))

		SET @Dt=CONVERT(FLOAT,getdate())
		
		IF @ViewID=0
		BEGIN
			SELECT @ViewID=ISNULL(MAX(ViewID)+1,1) FROM ADM_QueryDefn WITH(NOLOCK)
		END
		ELSE
		BEGIN
			DELETE FROM ADM_QueryDefn WHERE CostCenterID=@CostCenterID AND ViewID=@ViewID
		END
		
		SELECT TOP 1 ViewName FROM ADM_QueryDefn WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND ViewName=@ViewName
		IF @@rowcount>0
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
			WHERE ErrorNumber=-112 AND LanguageID=@LangID  
			ROLLBACK TRANSACTION
			RETURN 0
		END
		
		INSERT INTO @TblApp(G)
		EXEC [SPSplitString] @Groups,','

		INSERT INTO @TblApp(R)
		EXEC [SPSplitString] @Roles,','

		INSERT INTO @TblApp(U)
		EXEC [SPSplitString] @Users,','
		
		--Insert Reports
		SET @XML=@Reports
		INSERT INTO @TblReports(ReportID,GroupLevel,Shortcut)
		select X.value('@ReportID','BIGINT'),X.value('@GroupLevel','BIT'), X.value('@Shortcut','NVarchar(100)') 
		from @XML.nodes('XML/Row') as Data(X) 
		
		DECLARE @QID BIGINT  
		INSERT INTO ADM_QueryDefn(CostCenterID,ViewID,ViewName,ReportID,DocumentID,GroupID,RoleID,UserID
			,ShowPriceChart,ListViewID,GroupLevel,Shortcut,CompanyGUID,[GUID],CreatedBy,CreatedDate)
		SELECT @CostCenterID,@ViewID,@ViewName,ReportID,0,G,R,U,@ShowPriceChart,@ListViewID,GroupLevel,Shortcut,@CompanyGUID,NEWID(),@UserName,@Dt
		FROM @TblApp,@TblReports
		ORDER BY U,R,G
		SET @QID= SCOPE_IDENTITY()
		UPDATE ADM_QueryDefn SET HeaderFields=@HeaderFields,ReportXML=@Reports WHERE Queryid=@QID
		
		--Insert Documents
		DELETE FROM @TblReports
		INSERT INTO @TblReports(ReportID)
		EXEC [SPSplitString] @Docs,','
		
		
		
		INSERT INTO ADM_QueryDefn(CostCenterID,ViewID,ViewName,ReportID,DocumentID,GroupID,RoleID,UserID
			,ShowPriceChart,ListViewID,CompanyGUID,[GUID],CreatedBy,CreatedDate)
		SELECT @CostCenterID,@ViewID,@ViewName,0,ReportID,G,R,U,@ShowPriceChart,@ListViewID,@CompanyGUID,NEWID(),@UserName,@Dt
		FROM @TblApp,@TblReports
		ORDER BY U,R,G
		SET @QID= SCOPE_IDENTITY()
		--UPDATE ADM_QueryDefn SET HeaderFields=@HeaderFields WHERE Queryid=@QID
		
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID    
	
	COMMIT TRANSACTION
	RETURN @ViewID
	END
	ELSE IF @Type=4--DELETE
	BEGIN
		BEGIN TRANSACTION
		select 1
		DELETE FROM ADM_QueryDefn WHERE CostCenterID=@CostCenterID AND ViewID=@ViewID
		COMMIT TRANSACTION

		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=102 AND LanguageID=@LangID
	END
	ELSE IF @Type=5--To Get user assigned reports for a costcenter
	BEGIN
		SELECT Q.QueryID,R.ReportID,R.ReportName,Q.ShowPriceChart,MAX(Q.ListViewID) ListViewID,MAX(Q.HeaderFields) HeaderFields,MAX(Q.ReportXML) ReportXML,MAX(R.StaticReportType) StaticReportType,Q.GroupLevel,Q.Shortcut
		FROM ADM_RevenUReports R WITH(NOLOCK), ADM_QueryDefn Q WITH(NOLOCK)
		WHERE Q.ReportID=R.ReportID AND CostCenterID=@CostCenterID AND
			(Q.UserID=@UserID OR Q.RoleID=@RoleID OR GroupID IN (SELECT GID FROM COM_Groups WITH(NOLOCK) WHERE UserID=@UserID OR RoleID=@RoleID))
		GROUP BY Q.QueryID,R.ReportID,R.ReportName,Q.ShowPriceChart,Q.GroupLevel,Q.Shortcut
		ORDER BY MIN(Q.QueryID)

		SELECT HeaderFields,ReportXML
		FROM ADM_QueryDefn WHERE ViewID IN (SELECT Q.ViewID
			FROM ADM_RevenUReports R WITH(NOLOCK), ADM_QueryDefn Q WITH(NOLOCK)
			WHERE Q.ReportID=R.ReportID AND CostCenterID=@CostCenterID AND
				(Q.UserID=@UserID OR Q.RoleID=@RoleID OR GroupID IN (SELECT GID FROM COM_Groups WITH(NOLOCK) WHERE UserID=@UserID OR RoleID=@RoleID))
			GROUP BY Q.ViewID)
		and (HeaderFields IS NOT NULL OR ReportXML IS NOT NULL)
		
		SELECT D.CostCenterID,D.DocumentName 
		FROM ADM_DocumentTypes D WITH(NOLOCK),ADM_QueryDefn Q WITH(NOLOCK)
		WHERE Q.DocumentID=D.CostCenterID AND Q.CostCenterID=@CostCenterID AND
			(Q.UserID=@UserID OR Q.RoleID=@RoleID OR GroupID IN (SELECT GID FROM COM_Groups WITH(NOLOCK) WHERE UserID=@UserID OR RoleID=@RoleID))
		GROUP BY D.CostCenterID,D.DocumentName
	END
	
	ELSE IF @Type=6--To Get user assigned reports for a costcenter in Document
	BEGIN
		SELECT  R.ReportID,Q.ReportName,Q.ReportField,Q.ReportFieldName,Q.DocumentField,Q.DocumentFieldName,A.SysColumnName,Q.Shortcut,Q.DisplayAsPopup,MAX(Q.HeaderFields) HeaderFields,MAX(R.StaticReportType) StaticReportType
		FROM ADM_RevenUReports R WITH(NOLOCK) inner join ADM_DocumentReports Q WITH(NOLOCK) on Q.DocumentReportID=R.ReportID
	                             left join ADM_CostCenterDef A WITH(NOLOCK) on A.CostCenterColID=Q.DocumentField 
	                             left join [ADM_DocReportUserRoleMap] DR WITH(NOLOCK) on DR.DocumentViewID=Q.DocumentViewID and DR.CostCenterID=Q.CostCenterID
	          where  Q.CostCenterID=@CostCenterID and (DR.UserID=@UserID OR DR.RoleID=@RoleID OR GroupID IN (SELECT GroupID FROM COM_Groups WITH(NOLOCK) WHERE UserID=@UserID OR RoleID=@RoleID))
		GROUP BY  Q.ReportID, R.ReportID,Q.ReportName,Q.ReportField,Q.ReportFieldName,Q.DocumentField,Q.DocumentFieldName,A.SysColumnName,Q.Shortcut,Q.DisplayAsPopup 
		 order by Q.ReportID
	END
	
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
