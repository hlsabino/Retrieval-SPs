USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SearchCases]
	@CustomerID [bigint],
	@ContractID [bigint],
	@ProductID [bigint],
	@SereialNo [nvarchar](200),
	@CaseDate [datetime],
	@where [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON
		declare @sql nvarchar(max),@strColumns nvarchar(max),@STRJOIN nvarchar(max),@I int, @Cnt int,@CostCenterColID bigint,@IsContDisplayed bit, @CostCenterTableName nvarchar(100)
		declare @ColumnCostCenterID bigint,@SysColumnName nvarchar(100),@IsColumnUserDefined bit,@ColumnDataType nvarchar(50),@ColCostCenterPrimary nvarchar(100),@CC int, @GCID bigint
		declare @tblList TABLE (ID int identity(1,1),CostCenterColID BIGINT)   
		 
	  --Read CostCenterColUMNS FROM  GridViewColumns into temporary table  
		INSERT INTO @tblList  
		select costcentercolid from ADM_GridViewColumns  WITH(NOLOCK) 
		WHERE GRIDVIEWID IN (SELECT GRIDVIEWID FROM [ADM_GridView] WITH(NOLOCK) WHERE FeatureID=161)
		and costcentercolid>0
		SELECT @I=1, @Cnt=count(*) FROM @tblList
		 
		set @sql=''
		SET @strColumns=''
		SET @STRJOIN=''
		set @CC=0
		WHILE(@I<=@Cnt)    
		BEGIN     

    SELECT @CostCenterColID=CostCenterColID FROM @tblList  WHERE ID=@I    
    SET @I=@I+1  
    SET @ColumnCostCenterID=0  
    SET @SysColumnName=''    
    SET @IsColumnUserDefined=0  
    SELECT @SysColumnName=SysColumnName,@ColumnDataType=ColumnDataType,@IsColumnUserDefined=IsColumnUserDefined,@ColumnCostCenterID=ColumnCostCenterID  ,@GCID=COSTcENTERID
    FROM ADM_CostCenterDef  WITH(nolock) WHERE CostCenterColID=@CostCenterColID  

    SET @strColumns=@strColumns+','  
 
	IF(@ColumnCostCenterID IS NOT NULL AND @ColumnCostCenterID>0)--IF COSTCENTER COLUMN  
	BEGIN   
     --GETTING COLUMN COSTCENTER TABLE  
     SET @CostCenterTableName=(SELECT Top 1 TableName FROM ADM_features with(nolock) WHERE Featureid=@ColumnCostCenterID)     
 
	 if(@ColumnCostCenterID=2)  
     BEGIN       
       set @ColCostCenterPrimary='AccountID'  
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.AccountName as '+@SysColumnName  
     END  
     ELSE if(@ColumnCostCenterID=11)  
     BEGIN  
    --  set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.UnitName  '
       set @ColCostCenterPrimary='UOMID'  
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.UnitName as '+@SysColumnName   
     END  
     ELSE if(@ColumnCostCenterID=12)  
     BEGIN  
     -- set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Name  '
       set @ColCostCenterPrimary='CurrencyID'  
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME as '+@SysColumnName 
     END   
     ELSE if(@ColumnCostCenterID=44)  
     BEGIN    
		 SET @strColumns=@strColumns+'L'+@SysColumnName+'.Name as '  +@SysColumnName              
		 SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup L'+@SysColumnName+' WITH(NOLOCK) ON (Cases.'+@SysColumnName+'=L'+@SysColumnName+'.NodeID) '   
     END   
     else
     BEGIN   
       set @ColCostCenterPrimary='NodeID'  
    	IF(@GCID =40997)
			SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME as Name'+@SysColumnName  
		else
			SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME as '+@SysColumnName  
      END  
	  
     IF(@IsColumnUserDefined=0 and @ColumnCostCenterID<>44)  
     BEGIN  
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)  
       +' WITH(NOLOCK) ON Cases.'+@SysColumnName+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary  
     END  
     ELSE if(@ColumnCostCenterID<>44)
     BEGIN  
		IF(@GCID =40997)
		  SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)  
		   +' WITH(NOLOCK) ON DC.DCCCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary
		ELSE
		   SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)  
		   +' WITH(NOLOCK) ON C.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary
      
     END  
 
    --INCREMENT COSTCENTER COLUMNS COUNT  
    SET @CC=@CC+1   
    END 
	ELSE IF(@IsColumnUserDefined IS NOT NULL AND @IsColumnUserDefined = 1 AND @SysColumnName not like '%alpha%')   
    BEGIN     
     SET @strColumns=@strColumns+'Cont.'+@SysColumnName
	 if(@IsContDisplayed=0)
	 begin
		SET @IsContDisplayed=1
		SET @STRJOIN=@STRJOIN+' left JOIN COM_Contacts Cont WITH(NOLOCK) ON c.Caseid=Cont.FeaturePK and Cont.FeatureID=73 and Cont.AddressTypeID=1'
	 end
    END   
    ELSE IF(@IsColumnUserDefined IS NOT NULL AND @IsColumnUserDefined = 1 AND @SysColumnName like '%alpha%')   
    BEGIN      
     SET @strColumns=@strColumns+'E.'+@SysColumnName   
    END   
    ELSE IF(@SysColumnName='StatusID')  
    BEGIN     
     SET @strColumns=@strColumns+'S.ResourceData as StatusID'  
     SET @STRJOIN=@STRJOIN+' JOIN COM_Status SS WITH(NOLOCK) ON Cases.StatusID=SS.StatusID  
     JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=SS.ResourceID AND S.LanguageID='+convert(NVARCHAR(10),@LangID)  
    END   
    ELSE IF(@SysColumnName <> '')  
    BEGIN  
     if(@ColumnDataType is not null and @ColumnDataType='DATE')  
     begin 
      SET @strColumns=@strColumns+'convert(nvarchar(12),Convert(datetime,Cases.'+@SysColumnName+'),106) as '+@SysColumnName  
     end 
     else  
     begin   
		SET @strColumns=@strColumns+'Cases.'+@SysColumnName  
      end
    END
 END 

		
		if(@CustomerID>0)	 
		BEGIN
			set @sql=' SELECT    creditAccount,a.ProductID,DocID,VoucherNo,AccountName,dcAlpha6,ProductName, CONVERT(DATETIME, DocDate) AS DocDate
			,isnull((select count(CaseID) FROM CRM_Cases WITH(nolock) WHERE BillingMethod=138 and StatusID<>433 and  SvcContractID=DocID and  (RefCCID is null or RefCCID=0) and Month(CreateDate)=Month('''+convert(nvarchar,@CaseDate)+''')) ,0) MonthCases
			,isnull((select count(CaseID) FROM CRM_Cases WITH(nolock) WHERE BillingMethod=138 and StatusID<>433 and SvcContractID=DocID and  (RefCCID is null or RefCCID=0)) ,0)   CaseCount,dcNum3 AllotedCases,dcAlpha11 CaseType,Costcenterid,dc.*
			'+@strcolumns+'
			FROM INV_DocDetails a With(NOLOCK) 
			left join CRM_CASES Cases On a.DocID=Cases.SvcContractID
			JOIN ACC_Accounts b on a.creditAccount=b.AccountID
			join COM_DocTextData d on a.InvDocDetailsID=d.InvDocDetailsID
			join COM_DocNumData dn on a.InvDocDetailsID=dn.InvDocDetailsID
			join COM_DocCCData dc on a.InvDocDetailsID=dc.InvDocDetailsID
			JOIN INV_Product c on a.ProductID=c.ProductID
			'+@STRJOIN +'
			where creditAccount='+convert(nvarchar,@CustomerID)+' and DOcumentType=35 '
			if(@where<>'')
				set @sql=@sql+' and '+@where
		END
		
		if(@ContractID>0)	 
		BEGIN
			if(@sql<>'')
				set @sql=@sql+' UNION '
			set @sql=@sql+' SELECT    creditAccount,a.ProductID,DocID,VoucherNo,AccountName,dcAlpha6,ProductName, CONVERT(DATETIME, DocDate) AS DocDate
			,isnull((select count(CaseID) FROM CRM_Cases WITH(nolock) WHERE BillingMethod=138  and StatusID<>433 and SvcContractID=DocID and  (RefCCID is null or RefCCID=0) and Month(CreateDate)=Month('''+convert(nvarchar,@CaseDate)+''')) ,0) MonthCases
			,isnull((select count(CaseID) FROM CRM_Cases WITH(nolock) WHERE BillingMethod=138  and StatusID<>433 and SvcContractID=DocID and  (RefCCID is null or RefCCID=0)) ,0)   CaseCount,dcNum3 AllotedCases,dcAlpha11 CaseType,Costcenterid,dc.*
			'+@strcolumns+'
			FROM INV_DocDetails a With(NOLOCK) 
			left join CRM_CASES Cases On a.DocID=Cases.SvcContractID
			JOIN ACC_Accounts b on a.creditAccount=b.AccountID
			join COM_DocTextData d on a.InvDocDetailsID=d.InvDocDetailsID
			join COM_DocNumData dn on a.InvDocDetailsID=dn.InvDocDetailsID
			join COM_DocCCData dc on a.InvDocDetailsID=dc.InvDocDetailsID
			JOIN INV_Product c on a.ProductID=c.ProductID
			'+@STRJOIN +'
			where DOcumentType=35 and DocID='+convert(nvarchar,@ContractID)+' '
			if(@where<>'')
				set @sql=@sql+' and '+@where
		END

		if(@ProductID>0)
		BEGIN	
			if(@sql<>'')
				set @sql=@sql+' UNION '
			set @sql=@sql+' SELECT    creditAccount,a.ProductID,DocID,VoucherNo,AccountName,dcAlpha6,ProductName, CONVERT(DATETIME, DocDate) AS DocDate
			,isnull((select count(CaseID) FROM CRM_Cases WITH(nolock) WHERE BillingMethod=138  and StatusID<>433 and SvcContractID=DocID and  (RefCCID is null or RefCCID=0) and Month(CreateDate)=Month('''+convert(nvarchar,@CaseDate)+''')) ,0) MonthCases
			,isnull((select count(CaseID) FROM CRM_Cases WITH(nolock) WHERE BillingMethod=138  and StatusID<>433 and SvcContractID=DocID and  (RefCCID is null or RefCCID=0)) ,0)   CaseCount,dcNum3 AllotedCases,dcAlpha11 CaseType,Costcenterid,dc.*
			'+@strcolumns+'
			FROM INV_DocDetails a With(NOLOCK) 
			left join CRM_CASES Cases On a.DocID=Cases.SvcContractID
			JOIN ACC_Accounts b on a.creditAccount=b.AccountID
			join COM_DocTextData d on a.InvDocDetailsID=d.InvDocDetailsID
			join COM_DocNumData dn on a.InvDocDetailsID=dn.InvDocDetailsID
			join COM_DocCCData dc on a.InvDocDetailsID=dc.InvDocDetailsID
			JOIN INV_Product c on a.ProductID=c.ProductID
			'+@STRJOIN +'
			where a.ProductID= '+convert(nvarchar,@ProductID)+'and DOcumentType=35 '
			if(@where<>'')
				set @sql=@sql+' and '+@where
		END

		if(@SereialNo<>'')	 
		BEGIN
			if(@sql<>'')
				set @sql=@sql+' UNION '
			set @sql=@sql+' SELECT   creditAccount,a.ProductID,DocID,VoucherNo,AccountName,dcAlpha6,ProductName, CONVERT(DATETIME, DocDate) AS DocDate
			,isnull((select count(CaseID) FROM CRM_Cases WITH(nolock) WHERE BillingMethod=138  and StatusID<>433 and SvcContractID=DocID and  (RefCCID is null or RefCCID=0) and Month(CreateDate)=Month('''+convert(nvarchar,@CaseDate)+''')) ,0) MonthCases
			,isnull((select count(CaseID) FROM CRM_Cases WITH(nolock) WHERE BillingMethod=138  and StatusID<>433 and SvcContractID=DocID and  (RefCCID is null or RefCCID=0)) ,0)   CaseCount,dcNum3 AllotedCases,dcAlpha11 CaseType,Costcenterid,dc.*
			'+@strcolumns+'
			FROM INV_DocDetails a With(NOLOCK)
			join CRM_CASES Cases On a.DocID=Cases.SvcContractID
			JOIN ACC_Accounts b on a.creditAccount=b.AccountID
			join COM_DocTextData d on a.InvDocDetailsID=d.InvDocDetailsID
			join COM_DocNumData dn on a.InvDocDetailsID=dn.InvDocDetailsID
			join COM_DocCCData dc on a.InvDocDetailsID=dc.InvDocDetailsID
			JOIN INV_Product c on a.ProductID=c.ProductID
			'+@STRJOIN +'
			where dcAlpha6 ='''+@SereialNo+''' and DOcumentType=35 '
			if(@where<>'')
				set @sql=@sql+' and '+@where
		END 
		if(@sql='')
			set @where=' where '+@where 
			 
		if(@sql='' and @where<>'')
			set @sql=@sql+'select  Cases.CustomerID creditAccount,0  ProductID,0 DocID,'''' VoucherNo,
			case when (Cases.CustomerMode=1) then (a.accountname) 
			when (Cases.CustomerMode=2) then (cust.customername) else '''' end
			 AccountName,'''' dcAlpha6,'''' ProductName, '''' DocDate'+@strcolumns+'
				from 	CRM_CASES Cases 
				left join crm_customer  cust with(nolock) on Cases.Customerid=cust.customerid and CustomerMode=2
				left join ACC_Accounts a with(nolock) on Cases.Customerid=A.AccountID and CustomerMode=1
				'+@STRJOIN +' '+@where 
 
		print @sql
		if(@sql<>'')
		BEGIN 
			exec(@sql)
		END
		select [CostCenterID],[PrefValue]
		FROM [COM_DocumentPreferences]
		WHERE DocumentType=35 and [PrefName]='DocumentLinkDimension' 
		
		SELECT [DocumentLinkDefID],[CostCenterIDLinked]  FROM [COM_DocumentLinkDef]    
		where [CostCenterIDBase]=73 and 
		[CostCenterIDLinked]  in (SELECT CostCenterID FROM ADM_DOCUMENTTYPES WHERE DocumentType=35)  
	 	

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
