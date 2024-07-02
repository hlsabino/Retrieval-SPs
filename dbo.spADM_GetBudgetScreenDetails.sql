USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetBudgetScreenDetails]
	@CallType [bigint],
	@BudgetID [bigint],
	@MapXML [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
 
	DECLARE @tablename nvarchar(50),@SQL nvarchar(max),@Name nvarchar(50)
	
IF @CallType=0
BEGIN
	IF @BudgetID=0
	BEGIN
		IF @CallType=0
		BEGIN
			SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK) 
			WHERE (FEATUREID>50000 OR FEATUREID=2 OR FEATUREID=3)  and ISEnabled=1

			select BudgetDefID,BudgetName from COM_BudgetDef WITH(NOLOCK) where IsGroup=1
			
			SELECT C.CostCenterColID,C.SysColumnName,isnull(L.ResourceData,C.UserColumnName) Caption FROM ADM_CostcenterDef C with(nolock)
			left join com_languageResources L with(nolock) on C.ResourceID=L.ResourceID and L.LanguageID=@LangID
			Where C.CostCenterID=101 and C.SysColumnName like 'dcNum%' and C.IsColumnInUse=1
			
			SELECT ListViewName,CostCenterID,ListViewTypeID FROM ADM_ListView WITH(NOLOCK) 
			WHERE CostCenterID IN (SELECT FEATUREID FROM ADM_FEATURES WITH(NOLOCK) 
			WHERE (FEATUREID>50000 OR FEATUREID=2 OR FEATUREID=3)  and ISEnabled=1)
			ORDER BY CostCenterID,ListViewTypeID
		END
		ELSE
		BEGIN
			set @tablename=(select top (1) SysTableName from ADM_CostCenterDef with(nolock) where CostCenterID=@CallType and IsColumnInUse=1)
			set @Name=replace(@tablename,'COM_' , '')

			if(@CallType=2)
				 set @SQL='	select AccountID as AccountName_Key,AccountName from '+@tablename+'  with(nolock)'
			else if(@CallType=3)
				set @SQL='select ProductID as ProductName_Key,ProductName from '+@tablename+'  with(nolock)'
			else
				set @SQL='select NodeID  as '+@Name+'ID ,name as '+@Name+' from '+@tablename+'  with(nolock)'

			exec sp_executesql @sql
		END
	end
	else
	begin
		SELECT convert(datetime,FinYearStartDate) as StartYear,* FROM COM_BudgetDef WITH(NOLOCK) WHERE BudgetDefID=@BudgetID

		SELECT * FROM COM_BudgetAlloc WITH(NOLOCK) WHERE BudgetDefID=@BudgetID
		Order By BudgetAllocID ASC

		SELECT F.Name Name,C.CostCenterID CostCenterID,ISNULL(C.CCCodeTypeID,0) CCCodeTypeID
		FROM COM_BudgetDefDims C WITH(NOLOCK),ADM_Features F WITH(NOLOCK)
		WHERE C.BudgetDefID=@BudgetID and C.CostCenterID=F.FeatureID
		--SELECT * FROM COM_BudgetDimValues WITH(NOLOCK) WHERE BudgetDefID=@BudgetID
		--Order By BudgetAllocID ASC
		
		select CostCenterID,NodeID from COM_DocBridge with(nolock) where RefDimensionID=101 and RefDimensionNodeID=@BudgetID
	end
END
ELSE IF @CallType=101
BEGIN
	SELECT C.CostCenterColID,isnull(L.ResourceData,C.UserColumnName) Caption,C.IsColumnInUse FROM ADM_CostcenterDef C with(nolock)
	left join com_languageResources L with(nolock) on C.ResourceID=L.ResourceID and L.LanguageID=@LangID
	Where C.CostCenterID=101 and C.SysColumnName like 'dcNum%'
END
ELSE IF @CallType=102
BEGIN
	declare @XML xml,@I INT,@CNT INT,@ColID BIGINT,@Header nvarchar(100),@Visible bit 
	set @XML=@MapXML
	
	declare @Tbl AS TABLE(ID INT IDENTITY(1,1),ColID bigint,Header nvarchar(100),Visible bit)
	insert into @Tbl
	select X.value('@ID','bigint'),X.value('@Header','nvarchar(100)'),X.value('@Visible','bit')
	FROM @XML.nodes('/XML/Row') as Data(X)
	--INNER JOIN ADM_CostCenterDef C with(nolock) on C.CostCenterColID=X.value('@ID','BIGINT')
	
--	select * from ADM_CostCenterDef where CostCenterColID=11480

	--update ADM_CostCenterDef
	--set IsColumnInUse=0
	--where CostCenterID=400 and CostCenterColID>=11485 and CostCenterColID<=11489
	
	select @I=1,@CNT=COUNT(*) FROM @Tbl
	while(@I<=@CNT)
	begin
		select @ColID=ColID,@Header=Header,@Visible=Visible
		from @Tbl where ID=@I
		
		update ADM_CostCenterDef
		set IsColumnInUse=@Visible
		where CostCenterColID=@ColID
		
		update COM_LanguageResources
		set ResourceData=@Header
		where ResourceID=(select ResourceID from ADM_CostCenterDef with(nolock) where CostCenterColID=@ColID)
		
		--To update document budget fields
		if @ColID>=11479 and @ColID<=11483
		begin
			update ADM_CostCenterDef
			set IsColumnInUse=@Visible
			where CostCenterID=400 and CostCenterColID=@ColID+6
		end
		
		set @I=@I+1	
	end
END
ELSE IF @CallType=103
BEGIN
	--Assigning Budgets
    DELETE FROM ADM_DocumentBudgets WHERE BudgetID=@BudgetID
    IF @MapXML<>'' AND @MapXML IS NOT NULL
    BEGIN
        SET @XML=@MapXML

        INSERT INTO ADM_DocumentBudgets(CostCenterID,FromDate,ToDate,BudgetID,CompanyGUID,CreatedBy,CreatedDate)
        SELECT  X.value('@CostCenterID','INT'),CONVERT(FLOAT,X.value('@FromDate','DATETIME')),CONVERT(FLOAT,X.value('@ToDate','DATETIME')),
            @BudgetID,'CompanyGUID',@UserID,CONVERT(FLOAT,getdate())
        FROM @XML.nodes('/XML/Row') as DATA(X)
    END
END

COMMIT TRANSACTION 
SET NOCOUNT OFF;   
RETURN 1
END TRY
BEGIN CATCH  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
	FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
