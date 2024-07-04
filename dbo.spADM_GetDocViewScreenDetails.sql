USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetDocViewScreenDetails]
	@DocumentTypeID [int],
	@CostCenterID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
    
BEGIN TRY    
SET NOCOUNT ON;  
	DECLARE @SQL NVARCHAR(MAX),@IsInventory int  
	set @IsInventory=0
	--SP Required Parameters Check  
	IF @DocumentTypeID=0 and @CostCenterID=0
	BEGIN  
		RAISERROR('-100',16,1)  
	END  
  
	if(@DocumentTypeID>0 and @CostCenterID=0)
	begin
		select @CostCenterID=CostCenterID from dbo.ADM_DocumentTypes with(nolock)
		where DocumentTypeID=@DocumentTypeID
		
		select @IsInventory=D.IsInventory from ADM_DocumentTypes D with(nolock),ADM_RibbonView R with(nolock)
		where D.CostCenterID=R.FeatureID and D.DocumentTypeID=@DocumentTypeID and D.IsInventory=1 and R.TABID=3
	end
	
	--Getting View for Document
	select Distinct DocumentViewID,ViewName from dbo.ADM_DocumentViewDef with(nolock)
	where DocumentTypeID=@DocumentTypeID AND CostCenterID=@CostCenterID 
	
  --Getting Costcenter Fields    
	IF(@CostCenterID=114)
	BEGIN 
		SELECT C.CostCenterColID,R.ResourceData,C.IsEditable,SYScolumnname,IsColumnUserDefined,C.ColumnDataType	 	 
		FROM ADM_CostCenterDef C WITH(NOLOCK)  
		LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
		WHERE C.CostCenterID = @CostCenterID
		AND ((C.IsColumnUserDefined=1   OR C.IsColumnUserDefined=0)AND C.IsColumnInUse=1)  AND (C.SysColumnName NOT LIKE '%dcCurrID%') AND 
		(C.SysColumnName NOT LIKE '%dcCalcNum%') AND (C.SysColumnName NOT LIKE '%dcExchRT%')
		ORDER BY  R.ResourceData
	END	
	ELSE IF(@CostCenterID=40054) -- Monthly Payroll
	BEGIN
		SET @SQL='SELECT  C.CostCenterColID,R.ResourceData,C.IsEditable,SYScolumnname,IsColumnUserDefined,C.ColumnDataType	 	 
		FROM ADM_CostCenterDef C WITH(NOLOCK)  
		LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID='+CONVERT(NVARCHAR,@LangID)+'  
		WHERE C.CostCenterID = 40054
		AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND (C.SysColumnName NOT LIKE ''%dcCurrID%'') AND 
		(C.SysColumnName NOT LIKE ''%dcCalcNum%'') AND (C.SysColumnName NOT LIKE ''%dcExchRT%'')
		UNION ALL
		Select 1000000+NodeID as CostCenterColID,
		CASE WHEN ParentID=2 THEN ''Earnings_''+Name WHEN ParentID=3 THEN ''Deductions_''+Name WHEN ParentID=4 THEN ''Loans_''+Name WHEN ParentID=5 THEN ''Leaves_''+Name ELSE Name END as ResourceData,
		CONVERT(BIT,1) as IsEditable,
		CASE WHEN ParentID=2 THEN ''Earnings_''+Name WHEN ParentID=3 THEN ''Deductions_''+Name WHEN ParentID=4 THEN ''Loans_''+Name WHEN ParentID=5 THEN ''Leaves_''+Name ELSE Name END as SysColumnName,
		CONVERT(BIT,1) as IsColumnUserDefined,
		CASE WHEN ParentID=2 THEN ''EARNINGS'' WHEN ParentID=3 THEN ''DEDUCTIONS'' WHEN ParentID=4 THEN ''LOANS'' WHEN ParentID=5 THEN ''LEAVES'' ELSE '''' END AS ColumnDataType 
		FROM COM_CC50052 WITH(NOLOCK)
		WHERE ISGroup=0 AND StatusID=252 AND ParentID IN (2,3,4,5)
		
		UNION ALL
		Select 2000001 as CostCenterColID,''Earnings_ActualColumn'',1,''Earnings_ActualColumn'',1,''EARNINGS''
		UNION ALL
		Select 2000002 as CostCenterColID,''Earnings_EarnedColumn'',1,''Earnings_EarnedColumn'',1,''EARNINGS''
		UNION ALL
		Select 2000003 as CostCenterColID,''Earnings_ArrearsColumn'',1,''Earnings_ArrearsColumn'',1,''EARNINGS''
		UNION ALL
		Select 2000004 as CostCenterColID,''Earnings_AdjustmentsColumn'',1,''Earnings_AdjustmentsColumn'',1,''EARNINGS''
		UNION ALL
		Select 2000005 as CostCenterColID,''Earnings_Grid'',1,''Earnings_Grid'',1,''EARNINGS''
		UNION ALL
		Select 2000006 as CostCenterColID,''Earnings_OTsGrid'',1,''Earnings_OTsGrid'',1,''EARNINGS''
		UNION ALL
		Select 2000007 as CostCenterColID,''Days_Grid'',1,''Days_Grid'',1,''DAYS''
		
		UNION ALL
		Select 2000011 as CostCenterColID,''Deductions_ActualColumn'',1,''Deductions_ActualColumn'',1,''DEDUCTIONS''
		UNION ALL
		Select 2000012 as CostCenterColID,''Deductions_DeductedColumn'',1,''Deductions_DeductedColumn'',1,''DEDUCTIONS''
		UNION ALL
		Select 2000013 as CostCenterColID,''Deductions_ArrearsColumn'',1,''Deductions_ArrearsColumn'',1,''DEDUCTIONS''
		UNION ALL
		Select 2000014 as CostCenterColID,''Deductions_AdjustmentsColumn'',1,''Deductions_AdjustmentsColumn'',1,''DEDUCTIONS''
		UNION ALL
		Select 2000015 as CostCenterColID,''Deductions_Grid'',1,''Deductions_Grid'',1,''DEDUCTIONS''
		
		UNION ALL
		Select 2000021 as CostCenterColID,''Loans_LoanDocNoColumn'',1,''Loans_LoanDocNoColumn'',1,''LOANS''
		UNION ALL
		Select 2000022 as CostCenterColID,''Loans_BalanceAmountColumn'',1,''Loans_BalanceAmountColumn'',1,''LOANS''
		UNION ALL
		Select 2000023 as CostCenterColID,''Loans_InstallmentAmountColumn'',1,''Loans_InstallmentAmountColumn'',1,''LOANS''
		UNION ALL
		Select 2000024 as CostCenterColID,''Loans_InstallmentNoColumn'',1,''Loans_InstallmentNoColumn'',1,''LOANS''
		UNION ALL
		Select 2000025 as CostCenterColID,''Loans_Grid'',1,''Loans_Grid'',1,''LOANS''
		
		UNION ALL
		Select 2000031 as CostCenterColID,''Leaves_OpeningBalanceColumn'',1,''Leaves_OpeningBalanceColumn'',1,''LEAVES''
		UNION ALL
		Select 2000032 as CostCenterColID,''Leaves_TakenInThisMonthColumn'',1,''Leaves_TakenInThisMonthColumn'',1,''LEAVES''
		UNION ALL
		Select 2000033 as CostCenterColID,''Leaves_NetBalanceColumn'',1,''Leaves_NetBalanceColumn'',1,''LEAVES''
		UNION ALL
		Select 2000034 as CostCenterColID,''Leaves_Grid'',1,''Leaves_Grid'',1,''LEAVES''
		
		ORDER BY  ResourceData'
		
		EXEC (@SQL)
	END
	ELSE IF(@CostCenterID=50051) -- EMPLOYEE MASTER
	BEGIN
		SET @SQL='SELECT  C.CostCenterColID,R.ResourceData,C.IsEditable,SYScolumnname,IsColumnUserDefined,C.ColumnDataType	 	 
		FROM ADM_CostCenterDef C WITH(NOLOCK)  
		LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID='+CONVERT(NVARCHAR,@LangID)+'   
		WHERE C.CostCenterID = 50051
		AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND (C.SysColumnName NOT LIKE ''%dcCurrID%'') AND 
		(C.SysColumnName NOT LIKE ''%dcCalcNum%'') AND (C.SysColumnName NOT LIKE ''%dcExchRT%'')
		UNION ALL
		Select 1000000+NodeID as CostCenterColID,
		CASE WHEN ParentID=2 THEN ''Earnings_''+Name ELSE ''Deductions_''+Name END as ResourceData,
		CONVERT(BIT,1) as IsEditable,
		CASE WHEN ParentID=2 THEN ''Earnings_''+Name ELSE ''Deductions_''+Name END as SysColumnName,
		CONVERT(BIT,1) as IsColumnUserDefined,
		CASE WHEN ParentID=2 THEN ''EARNINGS'' ELSE ''DEDUCTIONS'' END AS ColumnDataType 
		FROM COM_CC50052 WITH(NOLOCK)
		WHERE ISGroup=0 AND StatusID=252 AND ParentID IN (2,3)
		UNION ALL
		Select 2000005 as CostCenterColID,''Earnings_Grid'',1,''Earnings_Grid'',1,''EARNINGS''
		UNION ALL
		Select 2000015 as CostCenterColID,''Deductions_Grid'',1,''Deductions_Grid'',1,''DEDUCTIONS''
		UNION ALL
		
		Select 3000000+NodeID as CostCenterColID,
		CASE WHEN ParentID=2 THEN ''AppraisalEarnings_''+Name ELSE ''AppraisalDeductions_''+Name END as ResourceData,
		CONVERT(BIT,1) as IsEditable,
		CASE WHEN ParentID=2 THEN ''AppraisalEarnings_''+Name ELSE ''AppraisalDeductions_''+Name END as SysColumnName,
		CONVERT(BIT,1) as IsColumnUserDefined,
		CASE WHEN ParentID=2 THEN ''APPRAISALEARNINGS'' ELSE ''APPRAISALDEDUCTIONS'' END AS ColumnDataType 
		FROM COM_CC50052 WITH(NOLOCK)
		WHERE ISGroup=0 AND StatusID=252 AND ParentID IN (2,3)
		
		UNION ALL
		
		SELECT  C.CostCenterColID,''Appraisal_''+R.ResourceData,C.IsEditable,''Appraisal_''+SYScolumnname,IsColumnUserDefined,C.ColumnDataType	 	 
		FROM ADM_CostCenterDef C WITH(NOLOCK)  
		LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID='+CONVERT(NVARCHAR,@LangID)+'   
		WHERE C.CostCenterID = 405 and SysTableName like ''%pay_Emppay%'' And CostCenterName like ''Payroll Earnings''	
			 
		UNION ALL
		Select 3100005 as CostCenterColID,''AppraisalEarnings_Grid'',1,''AppraisalEarnings_Grid'',1,''APPRAISALEARNINGS''
		UNION ALL
		Select 3100015 as CostCenterColID,''AppraisalDeductions_Grid'',1,''AppraisalDeductions_Grid'',1,''APPRAISALDEDUCTIONS''
		ORDER BY  ResourceData'
		
		EXEC (@SQL)
	
	END
	ELSE IF(@CostCenterID=144)
	BEGIN 
		SELECT  C.CostCenterColID,R.ResourceData,C.IsEditable,SYScolumnname,IsColumnUserDefined,C.ColumnDataType	 	 
		FROM ADM_CostCenterDef C WITH(NOLOCK)  
		LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID  
		WHERE C.CostCenterID = @CostCenterID AND C.LocalReference = @DocumentTypeID
		AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND (C.SysColumnName NOT LIKE '%dcCurrID%') AND 
		(C.SysColumnName NOT LIKE '%dcCalcNum%') AND (C.SysColumnName NOT LIKE '%dcExchRT%')
		ORDER BY  R.ResourceData
	END
	ELSE
	BEGIN
		SET @SQL=' SELECT  C.CostCenterColID,R.ResourceData,C.IsEditable,SYScolumnname,IsColumnUserDefined,C.ColumnDataType	 	 
		FROM ADM_CostCenterDef C WITH(NOLOCK)  
		LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID='+CONVERT(NVARCHAR,@LangID)+' 
		WHERE C.CostCenterID = '+CONVERT(NVARCHAR,@CostCenterID)+'
		AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND (C.SysColumnName NOT LIKE ''%dcCurrID%'') AND 
		(C.SysColumnName NOT LIKE ''%dcCalcNum%'') AND (C.SysColumnName NOT LIKE ''%dcExchRT%'') '
		IF(isnull(@IsInventory,0)=1)		
		BEGIN
			SET @SQL=@SQL +' UNION ALL 
			SELECT  C.CostCenterColID,''Batch_''+R.ResourceData,C.IsEditable,SYScolumnname,IsColumnUserDefined,C.ColumnDataType	 	 
			FROM ADM_CostCenterDef C WITH(NOLOCK)  LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID='+CONVERT(NVARCHAR,@LangID)+'  
			WHERE C.CostCenterID =16 AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0) '
		END
		SET @SQL=@SQL +' ORDER BY  R.ResourceData '
		EXEC (@SQL)
	END
    	
	--Getting All Roles
	select RoleID,Name from ADM_PRoles with(nolock) order by Name

 	--Getting All Users
	select UserID,UserName from ADM_Users with(nolock) order by UserName
	
	--Getting All Groups
	select distinct GID GroupID,GroupName from COM_Groups with(nolock) Where IsGroup=1 AND NodeID<>1 order by GroupName
	
	select Distinct DocumentViewID,ViewName from dbo.ADM_DocumentReportDef with(nolock)
	where CostCenterID=@CostCenterID
	
	select (row_number() over (order by sectionname)+50)*-1 id,sectionname from(
	select distinct   sectionname from ADM_CostCenterDef WITH(NOLOCK)
	WHERE CostCenterID = @CostCenterID and sectionid=2) as t
   
  
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
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END  
 
SET NOCOUNT OFF    
RETURN -999     
END CATCH  

----spADM_GetDocViewScreenDetails 
-- 0
-- ,50051
-- ,1
 --,1
GO
