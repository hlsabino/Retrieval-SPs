USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetCostCenterPreferences]
	@CostCenterID [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON      
       
	--Declaration Section      
	DECLARE @HasAccess BIT, @Value nvarchar(500) ,@CONTQry nvarchar(max),@SQL nvarchar(max) 
	  
	--User acces check      
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,30)      
	  
	IF @HasAccess=0      
	BEGIN      
		RAISERROR('-105',16,1)      
	END      
        
	IF @CostCenterID=10      
	BEGIN      
		--Getting Global Preferences.      
		SELECT  L.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText]      
		FROM ADM_GlobalPreferences P WITH(NOLOCK)         
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID  and LanguageID=1      
		
		if exists (select Value from adm_globalpreferences with(nolock) where Name='EnableLocationWise' and Value='True') 
			and exists (select Value from adm_globalpreferences with(nolock) where Name='LWFinalization' and Value='True')
			SELECT FinancialYearsID, CONVERT(DATETIME,FY.FromDate) FromDate_Key,CONVERT(DATETIME,FY.ToDate) ToDate_Key
			,CONVERT(BIGINT,FY.AccountID) Account_Key,A.AccountName Account,CONVERT(BIGINT,FY.LocationID) Location_Key,L.Name Location
			,InvClose,AccCloseXML,InvCloseXML
			FROM ADM_FinancialYears FY WITH(NOLOCK)
			left join ACC_Accounts A with(nolock) on A.AccountID=FY.AccountID
			left join COM_Location L with(nolock) on L.NodeID=FY.LocationID
			order by FY.FromDate
		else
			SELECT FinancialYearsID, CONVERT(DATETIME,FY.FromDate) FromDate_Key,CONVERT(DATETIME,FY.ToDate) ToDate_Key, CONVERT(BIGINT,FY.AccountID) Account_Key,(SELECT Top 1 AccountName 
			FROM ACC_Accounts with(nolock) WHERE AccountID=FY.AccountID) Account,InvClose,AccCloseXML,InvCloseXML
			FROM ADM_FinancialYears FY WITH(NOLOCK)
			order by FY.FromDate
		 
		SELECT AccountType ,AccountTypeID  
		FROM ACC_AccountTypes A WITH(NOLOCK)     
		JOIN COM_LanguageResources R WITH(NOLOCK) ON A.ResourceID=R.ResourceID    
		WHERE LanguageID=@LangID
		order by AccountType

		set @Value=(select Value from adm_globalpreferences with(nolock) where name='LockTransactionAccountType')

		if(@Value is not null)
		begin
			  declare @table table(TypeID nvarchar(50))
			  insert into @table
			  exec SPSplitString @Value,','
			  
			   select reverse(parsename(replace(reverse(TypeID),'~','.'),1)) as [AccountTypeID],
					  convert(datetime,reverse(parsename(replace(reverse(TypeID),'~','.'),2))) as [Date] from (select TypeID from @table) as [Table]
		end 
		
		SELECT LISTVIEWTYPEID,LISTVIEWNAME,COSTCENTERID FROM ADM_LISTVIEW with(nolock) 
		WHERE COSTCENTERID in(2,3)   
		order by LISTVIEWNAME
	  
		--CHANGE FEATUREID FROM 50050 TO 50051
		select * from adm_features with(nolock)
		where (featureid>50000 or Featureid in (2,3,106,86,89,73,83,65,92,93,94,95,7,76))  and IsEnabled=1 order by NAME

		select CostCenterID,DocumentName,IsInventory,DocumentType from ADM_DocumentTypes with(nolock) 
		order by DocumentName
		
			
		SELECT FEATUREID,Name,TableName FROM ADM_FEATURES WITH(NOLOCK) WHERE IsEnabled=1 AND ALLOWCUSTOMIZATION=1 AND 
		(FEATUREID > 50000 OR FEATUREID IN (2,3,300,65,71,76,72,80,84,81,86,83,88,
		78,73,89,82,16,92,93,101,103,95,94,113,104))
		order by Name
		
		select a.CostCenterColID,b.ResourceData,Cformula,SysColumnName,UserDefaultValue,IsMandatory,Decimal,LocalReference,LinkData
		from ADM_CostCenterDef a  WITH(NOLOCK)
		join COM_LanguageResources b WITH(NOLOCK) on a.ResourceID=b.ResourceID
		where CostCenterID=403 and b.LanguageID=@LangID and IsColumnInUse=1
		
		select a.CostCenterColID,b.ResourceData,a.SysColumnName,columndatatype,usercolumntype from ADM_CostCenterDef a  WITH(NOLOCK)
		join COM_LanguageResources b WITH(NOLOCK) on a.ResourceID=b.ResourceID
		where CostCenterID=3 and b.LanguageID=@LangID and IsColumnInUse=1
		
		SELECT CONVERT(DATETIME,LD.FromDate) FromDate_Key,CONVERT(DATETIME,LD.ToDate) ToDate_Key, LD.isEnable    
		FROM ADM_LockedDates LD WITH(NOLOCK)  WHERE CostCenterID=0
		
		declare @tbname nvarchar(100)
		select @tbname=tablename from ADM_Features where FeatureID in 
		(select value from ADM_GlobalPreferences where Name='CrossDimension')
			
		if exists (select dimin from ADM_CrossDimension with(nolock)) and @tbname is not null and @tbname<>''
		begin
			set @CONTQry=''
			select @CONTQry=@CONTQry+',convert(bigint,cd.'+name+')'+name+'_Key' from sys.columns
			where object_id=object_id('ADM_CrossDimension')
			and name like 'Dcccnid%'
			
			set @SQL='select row_number() over (order by CrossDimensionID) sno,dIn.Name DimIn,convert(bigint,cd.DimIn) DimIn_Key,
			dFor.Name DimFor,convert(bigint,cd.DimFor) DimFor_Key,
			cd.Document,case when cd.document=1 then ''Receipt'' when cd.document=2 then ''Payment'' 
			when cd.document=3 then  ''StockTransfer'' else dt.DocumentName end Document_Key,
			dr.AccountName DrAccount,
			convert(bigint,cd.draccount) DrAccount_Key,
			 cr.AccountName  CrAccount ,convert(bigint,cd.Craccount) CrAccount_Key'+@CONTQry+'
			 from ADM_CrossDimension cd with(nolock)
			join '+ @tbname+' dIn with(nolock) on cd.DimIn=dIn.Nodeid
			join '+ @tbname+' dFor with(nolock) on cd.DimfOR=dFor.Nodeid
			left join ADM_DocumentTypes dt with(nolock) on dt.CostCenterID=cd.document
			left join acc_accounts dr with(nolock) on cd.DrAccount=dr.AccountID
			left join acc_accounts cr with(nolock) on cd.Craccount=cr.AccountID' 
			print @SQL
			exec (@SQL)
		end
		ELSE
			select '' DimIn,convert(bigint,cd.DimFor) DimIn_Key,'' DimFor,convert(bigint,cd.DimFor) DimFor_Key,cd.Document,'Receipt' Document_Key,
			'' DrAccount,convert(bigint,cd.draccount) DrAccount_Key,''  CrAccount ,convert(bigint,cd.Craccount) CrAccount_Key from 
			ADM_CrossDimension cd with(nolock) where 1<>1		
			
		SELECT convert(bigint,RegisterID) RegisterID_Key,RightPanelWidth,RowSize,TouchScreen,ButtonHeight Height,ButtonWidth Width,
		CASE WHEN PaymentModes IS NOT NULL THEN '...' ELSE '' END  PaymentMode,PaymentModes,LevelProfile,ActionHeight,ActionWidth 
		FROM [ADM_RegisterPreferences] WITH(NOLOCK)
		
		select distinct ProfileID,ProfileName from ADM_POSLevelsProfiles WITH(NOLOCK)
		
		--14
		select StatusID,Status from com_status with(nolock) where costcenterid = 50051
		
		--15
		IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME IN ('COM_CC50052','COM_CC50054'))
		BEGIN
			SELECT a.GradeID,CONVERT(DATETIME,a.PayrollDate) as PayrollDate, a.Type,a.SNo,a.ComponentID,b.Name as ComponentName
			FROM COM_CC50054 a WITH(NOLOCK)
			JOIN COM_CC50052 b WITH(NOLOCK) on b.NodeID=a.ComponentID
			WHERE  GradeID=1 
			AND PayrollDate=(SELECT MAX(PayrollDate) FROM COM_CC50054 WITH(NOLOCK) WHERE GradeID=1)
		END
		ELSE
			SELECT 1 WHERE 1<>1
			
		--16
		Select FeatureID,Name from ADM_Features 
		where IsEnabled=1 AND FeatureID>50000
		ORDER BY Name

		--17
		SELECT UserColumnName CostCenterName,CONVERT(NVARCHAR,(50000+CONVERT(INT,REPLACE(SysColumnName,'CCNID','')))) CostCenterID 
		FROM Adm_CostCenterDef WITH(NOLOCK) 
		WHERE CostCenterId=50051 AND IscolumnInUse=1 AND SysColumnName LIKE 'CCNID%' 
		ORDER BY UserColumnName
		
		--18
		SELECT CONVERT(DATETIME,BL.FromDate) FromDate_Key,CONVERT(DATETIME,BL.ToDate) ToDate_Key, BL.isEnable,CONVERT(BIGINT,BL.AccountID) Account_Key ,A.AccountName Account
		FROM ADM_BRSLockedDates BL WITH(NOLOCK) 
		left join ACC_Accounts A with(nolock) on A.AccountID=BL.AccountID
		order by BL.FromDate
		
		--19
		SELECT D.SysColumnName,D.CostCenterColID,R.ResourceData,D.CostCenterID  
		FROM ADM_COSTCENTERDEF D with(nolock)
		LEFT JOIN COM_LANGUAGERESOURCES R with(nolock) ON R.ResourceID=D.ResourceID and R.languageid=@LangID
		WHERE D.CostCenterID>50002 AND 
		(IsColumnUserDefined=0 or IsColumnInUse=1)

		--20
		SELECT * FROM ADM_PenaltyDoc PD WITH(NOLOCK)  WHERE CostCenterID=10
	END      
	      
	ELSE IF @CostCenterID=43      
	BEGIN      
		SELECT  P.PrefValueType,L.ResourceData [Text],'False' Value,P.PrefName [DBText],P.PreferenceTypeName [Group],PrefRowOrder,PrefColOrder      
		FROM COM_DocumentPreferences P WITH(NOLOCK)         
		INNER JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID  and LanguageID=@LangID  AND PreferenceTypeName='Common'      
		AND DocumentTypeID=1      
		EXEC spADM_GetDocuments @UserID,@RoleID,@LangID      
	END  
	ELSE IF @CostCenterID=164
	BEGIN      
		SELECT  l.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText],ProbableValues       
		FROM COM_CostCenterPreferences P WITH(NOLOCK)         
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID and LanguageID=@LangID      
		WHERE P.CostCenterID=@CostCenterID      
		  
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       		
		where d.IsInventory=1
		ORDER BY L.ResourceData 
		
		select a.SysColumnName,a.UserColumnType,b.ResourceData from ADM_CostCenterDef a WITH(NOLOCK)
		join COM_LanguageResources b WITH(NOLOCK) on a.ResourceID=b.ResourceID and b.LanguageID=@LangID
		where a.CostCenterID=(select Value from COM_CostCenterPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and Name='HireContractDoc')  
		 and IsColumnInUse=1 and SysColumnName like 'dcalpha%'
		 
		select a.SysColumnName,a.UserColumnType,b.ResourceData from ADM_CostCenterDef a WITH(NOLOCK)
		join COM_LanguageResources b WITH(NOLOCK) on a.ResourceID=b.ResourceID and b.LanguageID=@LangID
		where a.CostCenterID=(select Value from COM_CostCenterPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and Name='HireDeliveryDoc')  
		and  UserColumnType='date' and IsColumnInUse=1
		
		select a.SysColumnName,a.UserColumnType,b.ResourceData from ADM_CostCenterDef a WITH(NOLOCK)
		join COM_LanguageResources b WITH(NOLOCK) on a.ResourceID=b.ResourceID and b.LanguageID=@LangID
		where a.CostCenterID=(select Value from COM_CostCenterPreferences WITH(NOLOCK) where CostCenterID=@CostCenterID and Name='SIVDoc')  
		and  UserColumnType='date' and IsColumnInUse=1
	END	    
	ELSE IF @CostCenterID=95      
	BEGIN      
		SELECT  l.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText],ProbableValues       
		FROM COM_CostCenterPreferences P WITH(NOLOCK)         
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID and LanguageID=@LangID      
		WHERE P.CostCenterID=@CostCenterID      
		  
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=18      
		ORDER BY L.ResourceData       
		  
		SELECT D.CostCenterID,L.ResourceData,D.DocumentType
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType in(7,11)
		ORDER BY L.ResourceData       
		  
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=18      
		ORDER BY L.ResourceData       
		  
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=19      
		ORDER BY L.ResourceData       
		     
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=15  --Bank payment      
		ORDER BY L.ResourceData       
		     
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=6 --sales return      
		ORDER BY L.ResourceData       
		     
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=14 --PDP      
		ORDER BY L.ResourceData      
		     
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=15 --Bank payment      
		ORDER BY L.ResourceData    
		
		SELECT D.CostCenterID,L.ResourceData ,DocumentType     
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType in(16,22) --Cash Receipt    
		ORDER BY L.ResourceData   
		         
		select StatusID CostCenterID  ,Status  ResourceData from com_status with(nolock)
		where costcenterid = 400 and StatusID in(369,371)  -- Post Document Status  

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=17 --JV Receipt    
		ORDER BY L.ResourceData   
       
		IF EXISTS (SELECT  VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID = 95 AND NAME ='PDCAccounts' 
		AND Value <> '0' AND Value <> '' AND VALUE IS NOT NULL)
		BEGIN
			set @CONTQry =  ('SELECT ACCOUNTID CostCenterID,ACCOUNTNAME ResourceData ,ACCOUNTCODE  FROM ACC_ACCOUNTS with(nolock)
			WHERE ACCOUNTID IN ('+ (SELECT TOP 1 VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID = 95 AND NAME ='PDCAccounts')+')
			ORDER BY ACCOUNTID')
			EXEC(@CONTQry)
		END
		ELSE 
			SELECT ACCOUNTID CostCenterID,ACCOUNTNAME ResourceData ,ACCOUNTCODE  FROM ACC_ACCOUNTS with(nolock) WHERE 1=2
    
		IF EXISTS (SELECT  VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID = 95 AND NAME ='PDPAccounts' 
		AND Value <> '0' AND Value <> '' AND VALUE IS NOT NULL)
		BEGIN
			set @CONTQry =  ('SELECT ACCOUNTID CostCenterID,ACCOUNTNAME ResourceData ,ACCOUNTCODE  FROM ACC_ACCOUNTS
			WHERE ACCOUNTID IN ('+ (SELECT TOP 1 VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID = 95 AND NAME ='PDPAccounts')+')
			ORDER BY ACCOUNTID')
			EXEC(@CONTQry)
		END
		ELSE 
			SELECT ACCOUNTID CostCenterID,ACCOUNTNAME ResourceData ,ACCOUNTCODE  FROM ACC_ACCOUNTS with(nolock) WHERE 1=2
   
		SELECT ReportID,ReportName FROM ADM_RevenuReports with(nolock) WHERE StaticReportType=1 and ReportID>0
		
		SELECT UserID,UserName FROM ADM_Users WITH(NOLOCK) WHERE StatusID=1
		ORDER BY UserName
		
		select c.SysColumnName,b.ResourceData from ADM_CostCenterDef c WITH(NOLOCK)
		join COM_LanguageResources b WITH(NOLOCK) on c.ResourceID=b.ResourceID and b.LanguageID=@LangID
		where c.CostCenterID=95  and C.SysColumnName not in ('Depth','ParentID')                             
		AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0)   
		ORDER BY b.ResourceData
		
		select distinct ProfileID,ProfileName from ADM_DocFlowDef WITH(NOLOCK)		

		SELECT ReportID,ReportName FROM ADM_RevenuReports with(nolock) WHERE   ReportID=11
   
	END      
	ELSE IF @CostCenterID=104      
	BEGIN      
   
		SELECT  l.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText],ProbableValues       
		FROM COM_CostCenterPreferences P WITH(NOLOCK)         
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID and LanguageID=@LangID      
		WHERE P.CostCenterID=@CostCenterID    

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=15  --Bank payment      
		ORDER BY L.ResourceData      

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=14  -- POST DATED payment      
		ORDER BY L.ResourceData    

		SELECT D.CostCenterID,L.ResourceData, D.DocumentType     
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType In(1,2)  --PURCHASE VOUCHER  
		ORDER BY L.ResourceData    

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=23  --Cash payment      
		ORDER BY L.ResourceData    

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=17 --JV Receipt    
		ORDER BY L.ResourceData   

		--termination contract start
		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=18 --PurchaseBankReciept 
		ORDER BY L.ResourceData   

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=19 --PurchasePostDatedReciept 
		ORDER BY L.ResourceData 

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=10 --PurchasePReturn 
		ORDER BY L.ResourceData 

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE   D.DocumentType=22 --PurchaseCashReceipts 
		ORDER BY L.ResourceData       
		--termination contract end
		
		SELECT ReportID,ReportName FROM ADM_RevenuReports with(nolock) WHERE StaticReportType=1 and ReportID>0
	END  
	else if @CostCenterID=72      
	BEGIN      
	 
		SELECT  l.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText],ProbableValues       
		FROM COM_CostCenterPreferences P WITH(NOLOCK)         
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID and LanguageID=@LangID      
		WHERE P.CostCenterID=@CostCenterID      

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE D.DocumentType=17      
		ORDER BY L.ResourceData      

		SELECT AccountTypeID,ResourceData,AccountType,Status     
		FROM ACC_AccountTypes A WITH(NOLOCK)     
		JOIN COM_LanguageResources R WITH(NOLOCK) ON A.ResourceID=R.ResourceID    
		WHERE LanguageID=@LangID     

		select Name, FeatureID from ADM_Features with(nolock) where FeatureID>50000 and isenabled=1

	END      
	ELSE IF @CostCenterID=78      
	BEGIN      
		SELECT  l.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText],ProbableValues       
		FROM COM_CostCenterPreferences P WITH(NOLOCK)         
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID and LanguageID=@LangID      
		WHERE P.CostCenterID=@CostCenterID      

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE D.IsInventory=1        
		ORDER BY L.ResourceData         

		--GETTING LINK DETAILS                  
		SELECT DocumentLinkDefID,[CostCenterColIDBase],[CostCenterIDLinked],[CostCenterColIDLinked],[IsDefault]       
		FROM  [COM_DocumentLinkDef]  WITH(NOLOCK)      
		WHERE [CostCenterIDBase]=78        


		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE D.IsInventory=1  and D.DocumentType=33      
		ORDER BY L.ResourceData       


		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE D.IsInventory=1  and D.DocumentType=34      
		ORDER BY L.ResourceData       

		SELECT D.CostCenterID,L.ResourceData      
		FROM ADM_DocumentTypes D WITH(NOLOCK)      
		INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@LangID       
		WHERE D.DocumentType=17      
		ORDER BY L.ResourceData       
      
	END      
	ELSE      
	BEGIN  
		--Getting COMMON Preferences.      
		SELECT  l.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText],ProbableValues       
		FROM COM_CostCenterPreferences P WITH(NOLOCK)         
		LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=P.ResourceID and LanguageID=@LangID      
		WHERE P.CostCenterID=@CostCenterID      
     
		IF( @CostCenterID=101)      
		BEGIN 
			select a.name SysColumnName,replace(a.name,'dcAlpha','Field') UserColumnName from sys.columns a with(nolock)
			join sys.tables b on a.object_id=b.object_id
			where b.name='COM_DocTextData'  and a.name like 'dcAlpha%' --not in('DocTextDataID','AccDocDetailsID','InvDocDetailsID','tCostCenterID','tDocumentType')
			order by convert(int,replace(a.name,'dcAlpha',''))
		END
		ELSE IF( @CostCenterID=73 or @CostCenterID=89 OR @CostCenterID=86 OR @CostCenterID=83)      
		BEGIN      
			SELECT CostCenterID,DocumentName FROM ADM_DocumentTypes WITH(NOLOCK) WHERE IsInventory=1      
			SELECT LISTVIEWTYPEID,LISTVIEWNAME FROM ADM_LISTVIEW WITH(NOLOCK) WHERE COSTCENTERID=2   
			SELECT ACCOUNTNAME,ACCOUNTID FROM ACC_ACCOUNTS WITH(NOLOCK) WHERE  ISGROUP=1 
			select RoleID,Name from ADM_PRoles WITH(NOLOCK) WHERE ISROLEDELETED=0 

			if( @CostCenterID=89)
			begin
				select NodeID StatusID,Name Status from com_lookup with(nolock) where lookuptype =56
				select NodeID ID,Name Probability from com_lookup with(nolock) where lookuptype =17
				union
				Select '' ID, '' Probability
				set @Value=(select Value from Com_CostCenterPreferences with(nolock) where name='StatusProbability')

				if(@Value is not null)
				begin
					declare @table1 table(TypeID nvarchar(50))
					insert into @table1
					exec SPSplitString @Value,';'

					select reverse(parsename(replace(reverse(TypeID),'-','.'),1)) as [Status],
					reverse(parsename(replace(reverse(TypeID),'-','.'),2)) as [Probability],
					L.Name Probability_Key from (select TypeID from @table1) as [Table]
					join com_lookup l with(nolock) on l.NodeID=reverse(parsename(replace(reverse(TypeID),'-','.'),2))
				end
			end
			
			if(@CostCenterID=86 or @CostCenterID=89)
			begin
				IF @CostCenterID=86
				BEGIN 
					SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType
					,C.ColumnDataType,isnull(C.IsVisible,1) IsVisible
					FROM ADM_CostCenterDef C WITH(NOLOCK)                              
					LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID=1                              
					WHERE C.CostCenterID = 115   AND C.SysColumnName LIKE '%Alpha%'                     
					AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0))       
					UNION
					select 0 CostCenterColID,'' ResourceData,''  UserColumnName,0 ResourceID,'' SysColumnName,'' UserColumnType,'' ColumnDataType,0 IsVisible
				END 
				ELSE  IF @CostCenterID=89
				BEGIN
					SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType
					,C.ColumnDataType,isnull(C.IsVisible,1) IsVisible
					FROM ADM_CostCenterDef C WITH(NOLOCK)                              
					LEFT JOIN COM_LanguageResources R with(nolock) ON R.ResourceID=C.ResourceID AND R.LanguageID=1                              
					WHERE C.CostCenterID = 154   AND C.SysColumnName LIKE '%Alpha%'                     
					AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0))       
					UNION
					select 0 CostCenterColID,'' ResourceData,''  UserColumnName,0 ResourceID,'' SysColumnName,'' UserColumnType,'' ColumnDataType,0 IsVisible

				END
				SELECT   C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,                              
				isnull(C.IsVisible,1) IsVisible
				FROM ADM_CostCenterDef C WITH(NOLOCK)                              
				LEFT JOIN COM_LanguageResources R ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID                              
				WHERE C.CostCenterID = @CostCenterID  AND C.IsVisible=1 and C.SysColumnName not in ('Depth','ParentID')                             
				AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0) 
				UNION
				select 0 CostCenterColID,'' ResourceData,''  UserColumnName,0 ResourceID,'' SysColumnName,'' UserColumnType,
				'' ColumnDataType,0 IsVisible 
				ORDER BY C.CostCenterColID--,C.CostCenterColID    

				SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,
				C.ColumnDataType,isnull(C.IsVisible,1) IsVisible
				FROM ADM_CostCenterDef C WITH(NOLOCK)                              
				LEFT JOIN COM_LanguageResources R ON R.ResourceID=C.ResourceID AND R.LanguageID=1                              
				where CostCenterID=@CostCenterID and  SysTableName='CRM_Contacts'

				SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,
				C.ColumnDataType,isnull(C.IsVisible,1) IsVisible
				FROM ADM_CostCenterDef C WITH(NOLOCK)                              
				LEFT JOIN COM_LanguageResources R ON R.ResourceID=C.ResourceID AND R.LanguageID=1                              
				where CostCenterID=115  AND C.IsVisible=1   
				AND (((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1) AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) OR C.IsColumnUserDefined=0) 

				SELECT DISTINCT ProfileID,ProfileName FROM COM_DimensionMappings WITH(NOLOCK)
			end
			ELSE if(@CostCenterID=73)
			begin
				select NodeID, Name from com_lookup with(nolock) where lookuptype=60
			end
		END     
		else IF( @CostCenterID=92 OR @CostCenterID=76)
		BEGIN    
			IF( @CostCenterID=92 )  
			BEGIN
				SELECT D.CostCenterID,L.ResourceData,DocumentType FROM ADM_DocumentTypes D WITH(NOLOCK)      
				INNER JOIN ADM_RibbonView R with(nolock) ON R.FeatureID=D.CostCenterID      
				LEFT JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=R.FeatureActionResourceID AND L.LanguageID=@langid
				ORDER BY L.ResourceData
			END
			
			SELECT LISTVIEWTYPEID,LISTVIEWNAME FROM ADM_LISTVIEW WITH(NOLOCK) WHERE COSTCENTERID=2
			
		END  
		else IF( @CostCenterID=145)      
		BEGIN      
			SELECT ProductName,ProductID FROM INV_Product WITH(NOLOCK) WHERE  ISGROUP=1 
		END         
		else IF( @CostCenterID=3)      
		BEGIN      
			select UOMID,UnitName,BaseName from COM_UOM  WITH(NOLOCK) WHERE (PRODUCTID=0 OR PRODUCTID IS NULL) AND (ISPRODUCTWISE=0 OR IsProductWise IS NULL)      
			--SELECT ADM_FEATURES.FeatureID,ADM_FEATURES.Name FROM ADM_COSTCENTERDEF WITH(NOLOCK)       
			--LEFT JOIN ADM_FEATURES ON ADM_FEATURES.FEATUREID=ADM_COSTCENTERDEF.COLUMNCOSTCENTERID WHERE CostCenterID=3 AND COLUMNCOSTCENTERID>0 AND       
			--(ISCOLUMNUSERDEFINED=1 OR COLUMNCOSTCENTERID IN (50006,50004))      
			--   AND ISCOLUMNINUSE=1  
			select -1 as FeatureID,'' as Name from ADM_Features with(nolock)
			union
			select FeatureID as FeatureID,Name as Name from ADM_Features with(nolock) where FeatureID>=50000  

			SELECT CostCenterID,DocumentName FROM ADM_DocumentTypes WITH(NOLOCK) WHERE IsInventory=1    

			SELECT UserColumnName,SysColumnName FROM ADM_COSTCENTERDEF with(nolock)
			WHERE  COSTCENTERID=3 AND SysTableName='COM_CCCCData' AND IsColumnInUse=1

			set @Value=(select Value from Com_CostCenterPreferences with(nolock) where name='ProductTypeLinkDimension' and costcenterid=3)

			if(@Value is not null)
			begin
				  create table #table2(TypeID nvarchar(50))
				  insert into #table2
				  exec SPSplitString @Value,','
				  
				   select reverse(parsename(replace(reverse(TypeID),'~','.'),1)) as [ProductTypeID],
						  reverse(parsename(replace(reverse(TypeID),'~','.'),2)) as [DimensionID] from (select TypeID from #table2) as [Table] 
			end
		  
			select ViewName, GridViewID from ADM_GridView with(nolock) where CostCenterID=3	  
			select ColumnCostCenterID from ADM_CostCenterDef with(nolock) where CostCenterID=3 and SysColumnName like 'CCNID%' and iscolumninuse=1
			select ProductTypeID,ProductType from inv_productTypes with(nolock)
			
			set @SQL=(SELECT  VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID=3 AND NAME ='ProductCopyReports')
			IF @SQL is not null and @SQL!=''
			begin
				set @SQL='select ReportID,ReportName from adm_revenureports with(nolock) where ReportID IN ('+@SQL+') ORDER BY ReportName'
				exec(@SQL)
			end
			else
			begin
				select 1 copyreports where 1!=1
			end
			
			SELECT CCTabID,CCTabName FROM ADM_CostCenterTab WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
			AND (CCTabName IN('Notes','Attachments','Assign') OR (QuickViewCCID IS NOT NULL AND QuickViewCCID > 0))
			ORDER BY GroupOrder
			
			SELECT LISTVIEWTYPEID,LISTVIEWNAME FROM ADM_LISTVIEW WITH(NOLOCK) WHERE COSTCENTERID=3
			
		END    
		else IF( @CostCenterID=2)      
		BEGIN

			SELECT AccountType ,AccountTypeID  
			FROM ACC_AccountTypes A WITH(NOLOCK)     
			JOIN COM_LanguageResources R WITH(NOLOCK) ON A.ResourceID=R.ResourceID    
			WHERE LanguageID=@LangID
		  
			select -1 as DimensionID,'' as Dimension from ADM_Features with(nolock)
			union
			select FeatureID as DimensionID,Name as Dimension from ADM_Features with(nolock) where FeatureID>=50000

			set @Value=(select Value from Com_CostCenterPreferences with(nolock) where name='AccountTypeLinkDimension')

			if(@Value is not null)
			begin
				  create table #table1(TypeID nvarchar(50))
				  insert into #table1
				  exec SPSplitString @Value,','
				  
				   select reverse(parsename(replace(reverse(TypeID),'~','.'),1)) as [AccountTypeID],
						  reverse(parsename(replace(reverse(TypeID),'~','.'),2)) as [DimensionID] from (select TypeID from #table1) as [Table]
			end
			else
				select 1
			
			SELECT CCTabID,CCTabName FROM ADM_CostCenterTab WITH(NOLOCK) WHERE CostCenterID=@CostCenterID
			AND (CCTabName IN('Notes','Attachments','Assign','Contacts','Address','Final Reports','Report Template','Credit & Debit') OR (QuickViewCCID IS NOT NULL AND QuickViewCCID > 0))
			ORDER BY GroupOrder
		END
		else IF (@CostCenterID>=50000)
		BEGIN
			select FeatureID as FeatureID,Name as Name from ADM_Features with(nolock) where FeatureID>=50000  
		END    
		else IF( @CostCenterID=51)      
		BEGIN
			set @Value=(select Value from Com_CostCenterPreferences with(nolock) where name='AccountGroup' and costcenterid=51)
			if(@Value is not null)
			begin
				declare @tblaccdata table(TypeID nvarchar(50))
				insert into @tblaccdata
				exec SPSplitString @Value,','

				select reverse(parsename(replace(reverse(TypeID),'~','.'),1)) as [Location],
				  reverse(parsename(replace(reverse(TypeID),'~','.'),2)) as [AccountGroup_Key] ,
				  A.ACCOUNTNAME AS AccountGroup
				  from (select TypeID from @tblaccdata) as T
				  LEFT JOIN ACC_ACCOUNTS A with(nolock) ON   reverse(parsename(replace(reverse(TypeID),'~','.'),2))= A.ACCOUNTID
			end
		END   
		else if (@CostCenterID=1000)
		BEGIN
			SELECT DocumentName,CostCenterID FROM ADM_dOCUMENTTYPES with(nolock)
			
			SELECT Name,FeatureID FROM ADM_Features with(nolock)
			where FeatureID>50000 and IsEnabled=1
		END
		else if (@CostCenterID=88)
		BEGIN
			SELECT Name,FeatureID FROM ADM_Features with(nolock)
			where FeatureID>50000 and IsEnabled=1
			
			SELECT Name,FeatureID FROM ADM_Features with(nolock)
			where FeatureID IN (SELECT COLUMNCOSTCENTERID FROM ADM_CostCenterDef with(nolock) where CostCenterID=118
			and SysColumnName like 'CCNID%' and IsColumnInUse=1)
			
			select l.ResourceData, CostCenterColID, CostCenterID from ADM_CostCenterDef C with(nolock) 
			LEFT JOIN COM_LanguageResources L with(nolock) ON C.ResourceID=L.ResourceID and l.LanguageID=1
			where C.IsColumnInUse=1 AND CostCenterID in 
			(select ColumnCostCenterID from ADM_CostCenterDef  with(nolock) where CostCenterID=118 and SysColumnName like 'CCNID%' and IsColumnInUse=1)
			
		END
		else if (@CostCenterID=106)
		BEGIN
			select CostCenterID,DocumentName from ADM_DocumentTypes with(nolock) where IsInventory=1
			order by DocumentName
				
			select SysColumnName,CostCenterColID,b.ResourceData from ADM_CostCenterDef a with(nolock)
			join COM_LanguageResources b with(nolock) on a.ResourceID=b.ResourceID and b.LanguageID=@LangID
			where costcenterid=92 and UserColumnType='Date'
			
			
			select CostcenterID,SysColumnName,CostCenterColID,b.ResourceData from ADM_CostCenterDef a with(nolock)
			join COM_LanguageResources b with(nolock) on a.ResourceID=b.ResourceID and b.LanguageID=@LangID
			where costcenterid in(select CostCenterID from ADM_DocumentTypes with(nolock) where IsInventory=1)
			 and IsColumnInUse=1 and SysColumnName not like 'dcCalc%'
			 and SysColumnName not like 'dcCurrID%'
			 and SysColumnName not like 'dcExchRT%'			
		END
		else if (@CostCenterID=257)
		BEGIN
			select D.CostCenterID,D.DocumentName,D.DocumentType From ADM_DocumentTypes D with(nolock)
			inner  join com_documentpreferences DP with(nolock) ON DP.CostCenterID=D.CostCenterID
			where D.IsInventory=1 and DP.PrefName='DonotupdateInventory' and DP.PrefValue='True'
			Order By DocumentName
		END
		ELSE IF(@CostCenterID=94)
		BEGIN
			SELECT ACCOUNTNAME,ACCOUNTID FROM ACC_ACCOUNTS WITH(NOLOCK) WHERE  ISGROUP=1
			SELECT AccountType,AccountTypeID FROM ACC_AccountTypes WITH(NOLOCK) 

		END

	END      
       
COMMIT TRANSACTION      
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
ROLLBACK TRANSACTION      
SET NOCOUNT OFF        
RETURN -999         
END CATCH
GO
