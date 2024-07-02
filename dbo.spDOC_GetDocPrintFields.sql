USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocPrintFields]
	@DocumentID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;

		--Declaration Section
		DECLARE @HasAccess BIT
		DECLARE @TblCCList TABLE(CCID int, CCName nvarchar(50))
		DECLARE @Tbl AS TABLE(ID NVARCHAR(4))

		IF @DocumentID=78
		BEGIN
			SELECT  R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
					C.IsColumnUserDefined,C.ColumnCostCenterID, Doc.IsInventory
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN ADM_DocumentTypes Doc WITH(NOLOCK) ON C.CostCenterID = Doc.CostCenterID
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID = @DocumentID 
				--AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)
				AND C.IsColumnUserDefined=1 AND C.IsColumnInUse=1 AND SysColumnName NOT LIKE 'CCNID%'
				
			--To Get Product Fields
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
					C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	--,LVC.CostCenterColID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID=3 AND C.IsColumnInUse=1 and C.Systablename='INV_Product' 
			and SysColumnName not in ('ProductImage','IsGroup','SalesAccountID','COGSAccountID','PurchaseAccountID','ClosingStockAccountID','CurrencyID','Attributes')
				--TO GET DOCUMENT FIELDS
				select '78' as CostCenterID,'DocDate' as ResourceData,'DocDate' as UserColumnName,'DocDate' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				union
				select '78' as CostCenterID,'Currency' as ResourceData,'Currency' as UserColumnName,'CurrencyID' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				union
				select '78' as CostCenterID,'VoucherNo' as ResourceData,'VoucherNo' as UserColumnName,'VoucherNo' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				union
				select '78' as CostCenterID,'CreditAccount' as ResourceData,'CreditAccount' as UserColumnName,'CreditAccount' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				union
				select '78' as CostCenterID,'DebitAccount' as ResourceData,'DebitAccount' as UserColumnName,'DebitAccount' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				union
				select '78' as CostCenterID,'Amount' as ResourceData,'Amount' as UserColumnName,'Amount' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				UNION
				select '78' as CostCenterID,'Location' as ResourceData,'Location' as UserColumnName,'Location' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				
	        	--ACCOUT SUMMARY
	        	select '78' as CostCenterID,'Account Name' as ResourceData,'Account Name' as UserColumnName,'Account' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				union
				select '78' as CostCenterID,'Credit Amount' as ResourceData,'Credit Amount' as UserColumnName,'CreditAmount' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				union
				select '78' as CostCenterID,'Debit Amount' as ResourceData,'Debit Amount' as UserColumnName,'DebitAmount' as SysColumnName,'PRD_MFGOrder' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
		
	        	
		END
		ELSE IF @DocumentID=84
		BEGIN
		    SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=84 AND C.IsColumnInUse=1 and C.costcentercolid not in (24401,24402,25890,24354,24144)
		END	 
		ELSE IF @DocumentID=495
		BEGIN
		    select '495' as CostCenterID,'VoucherDate' as ResourceData,'VoucherDate' as UserColumnName,'VoucherDate' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'VoucherNo' as ResourceData,'VoucherNo' as UserColumnName,'VoucherNo' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'DebitAccount' as ResourceData,'DebitAccount' as UserColumnName,'DebitAccount' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'CreditAccount' as ResourceData,'CreditAccount' as UserColumnName,'CreditAccount' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'Amount' as ResourceData,'Amount' as UserColumnName,'Amount' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'Tower' as ResourceData,'Tower' as UserColumnName,'Tower' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'Unit' as ResourceData,'Unit' as UserColumnName,'Unit' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'Tenant' as ResourceData,'Tenant' as UserColumnName,'Tenant' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'ChequeNo' as ResourceData,'ChequeNo' as UserColumnName,'ChequeNo' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'IssuerBank' as ResourceData,'IssuerBank' as UserColumnName,'IssuerBank' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'MaturityDate' as ResourceData,'MaturityDate' as UserColumnName,'MaturityDate' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '495' as CostCenterID,'Status' as ResourceData,'Status' as UserColumnName,'Status' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
		    union
		    select '495' as CostCenterID,'ReceiveDate' as ResourceData,'ReceiveDate' as UserColumnName,'ReceiveDate' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
				
		END
		ELSE IF @DocumentID=90
		BEGIN
		    select '90' as CostCenterID,'BOM' as ResourceData,'BOM' as UserColumnName,'FinishedProduct' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '90' as CostCenterID,'Product' as ResourceData,'Product' as UserColumnName,'Product' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
		    union  
		    select '90' as CostCenterID,'Qty/Unit' as ResourceData,'Qty/Unit' as UserColumnName,'QTYPU' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '90' as CostCenterID,'Qty Based on FP ShortFall' as ResourceData,'Qty Based on FP ShortFall' as UserColumnName,'ShortfallQTY' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
		    union  
		    select '90' as CostCenterID,'Pending Order' as ResourceData,'Pending Order' as UserColumnName,'PendinOrders' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '90' as CostCenterID,'Goods In Transit' as ResourceData,'Goods In Transit' as UserColumnName,'GoodsInTransit' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
		    select '90' as CostCenterID,'Computer ShortFall' as ResourceData,'Computer ShortFall' as UserColumnName,'ComShortFall' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
		    union
		    select '90' as CostCenterID,'Qty on Hand' as ResourceData,'Qty on Hand' as UserColumnName,'QtyOnHand' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID 
		    union
		    select '90' as CostCenterID,'QOH+CSF' as ResourceData,'QOH+CSF' as UserColumnName,'QOHCSF' as SysColumnName,'ACC_DocDetails' as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID    
		END
		ELSE IF @DocumentID=1000
		BEGIN
			 SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,
		    case when C.SysTableName='COM_CCCCDATA' then C.SysColumnName+'_Name' else C.SysColumnName end SysColumnName,
		    C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=1
        	WHERE C.CostCenterID=144 AND C.LocalReference=1000 AND C.IsColumnInUse=1 and C.CostCenterColID not in (26036)
        	
        	SELECT 1
			
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=144 AND C.IsColumnInUse=1 and C.CostCenterColID not in (25131,25130,25132,25133,25144,25145,25140)
		END
		ELSE IF @DocumentID=86
		BEGIN
		    SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,
		    case when C.SysTableName='COM_CCCCDATA' then C.SysColumnName+'_Name' else C.SysColumnName end SysColumnName,
		    C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=1
        	WHERE C.CostCenterID=86 AND C.IsColumnInUse=1 and C.CostCenterColID not in (26036)
        	
		    SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=114 AND C.IsColumnInUse=1
        	
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=144 AND C.IsColumnInUse=1 and C.CostCenterColID not in (25131,25130,25132,25133,25144,25145,25140)
        	
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=86 AND C.IsColumnInUse=1 and C.CostCenterColID = 26036
        	
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=146 AND C.IsColumnInUse=1 
        	
        	declare @table table(id INT identity(1,1),CostCenterID INT,ResourceData nvarchar(50),UserColumnName nvarchar(50),SysColumnName nvarchar(50),SysTableName nvarchar(50),UserColumnType nvarchar(50),ColumnDataType nvarchar(50),IsColumnUserDefined INT,ColumnCostCenterID INT)
			declare @table1 table(id INT identity(1,1),CostCenterID INT,ResourceData nvarchar(50),UserColumnName nvarchar(50),SysColumnName nvarchar(50),SysTableName nvarchar(50),UserColumnType nvarchar(50),ColumnDataType nvarchar(50),IsColumnUserDefined INT,ColumnCostCenterID INT)
			declare @i int,@cnt int,@type nvarchar(50),@CostCenterID INT ,@ResourceData nvarchar(50),@UserColumnName nvarchar(50),@SysColumnName nvarchar(50),@SysTableName nvarchar(50),@UserColumnType nvarchar(50),@ColumnDataType nvarchar(50),@IsColumnUserDefined INT,@ColumnCostCenterID INT

			insert into @table(CostCenterID,ResourceData,UserColumnName,SysColumnName,SysTableName,UserColumnType,ColumnDataType,IsColumnUserDefined,ColumnCostCenterID)
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			WHERE C.CostCenterID=3 AND C.IsColumnInUse=1 and ( SysTableName='COM_CCCCData')


			set @i=1
			select @cnt=count(id) from @table
			while(@i<=@cnt)
			begin
				select @type=systablename,@CostCenterID=CostCenterID,@ResourceData=ResourceData,@UserColumnName=UserColumnName,@SysColumnName=SysColumnName,@SysTableName=SysTableName,@UserColumnType=UserColumnType,@ColumnDataType=ColumnDataType,@IsColumnUserDefined=IsColumnUserDefined,@ColumnCostCenterID=ColumnCostCenterID from @table where @i=id
				
				IF(@type='COM_CCCCData')
				BEGIN
					insert into @table1 values (@CostCenterID,@ResourceData+'_Name',@UserColumnName+'_Name',@SysColumnName+'_Name',@SysTableName,@UserColumnType,@ColumnDataType,@IsColumnUserDefined,@ColumnCostCenterID)
					insert into @table1 values (@CostCenterID,@ResourceData+'_Code',@UserColumnName+'_Code',@SysColumnName+'_Code',@SysTableName,@UserColumnType,@ColumnDataType,@IsColumnUserDefined,@ColumnCostCenterID)
				END
				ELSE
				BEGIN
					insert into @table1 values (@CostCenterID,@ResourceData,@UserColumnName,@SysColumnName,@SysTableName,@UserColumnType,@ColumnDataType,@IsColumnUserDefined,@ColumnCostCenterID)
				END
				set @i=@i+1
			end

			select CostCenterID,ResourceData,UserColumnName,SysColumnName,SysTableName,UserColumnType,ColumnDataType,IsColumnUserDefined,ColumnCostCenterID from @table1
			union
			select C.CostCenterID,R.ResourceData, C.UserColumnName, C.SysColumnName, C.SysTableName, C.UserColumnType, C.ColumnDataType, C.IsColumnUserDefined, C.ColumnCostCenterID 
			from adm_costcenterdef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID 
			where C.costcenterid=3 and C.columncostcenterid=0 and C.isvalidreportbuildercol=1 and 
			C.iscolumninuse=1 and C.costcentercolid not in (264,265,269,283,266,286,26648,26649,26650,282) and C.systablename<>'INV_DocDetails'
			
			SELECT  C.CostCenterColID,C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID 
        	WHERE C.CostCenterID=115 AND C.IsColumnInUse=1 and C.CostCenterColID not in (26658,26659,26660)
		END
		ELSE IF @DocumentID=89
		BEGIN
		    SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=89 AND C.IsColumnInUse=1 and C.CostCenterColID not in (26041)
        	
        	 SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=114 AND C.IsColumnInUse=1
        	
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=144 AND C.IsColumnInUse=1 and C.CostCenterColID not in (25131,25130,25132,25133,25143,25144,25145,25140)
        	
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=89 AND C.IsColumnInUse=1 and C.CostCenterColID = 26041
		END
		ELSE IF @DocumentID=73
		BEGIN
		    SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=73 AND C.IsColumnInUse=1 and C.CostCenterColID not in (26042)
        	
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=114 AND C.IsColumnInUse=1
			UNION ALL
			SELECT 114,'UserName','UserName','CreatedBy','CRM_Feedback','TEXT','String', 0,0
			--To get activity fields	        		        	
			SELECT    C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			WHERE C.CostCenterID=144 and localreference is null  AND C.IsColumnInUse=1   and iscolumnuserdefined=0
			and C.CostCenterColID not in (25131,25130,25132,25133,25143,25144,25145,25140,27294,27295,27296) 
			union all
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=144 and localreference=73  AND C.IsColumnInUse=1  and iscolumnuserdefined=1
        	 
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=73 AND C.IsColumnInUse=1 and C.CostCenterColID = 26042
		END
		ELSE IF @DocumentID=95 OR @DocumentID=103 OR @DocumentID=104 OR @DocumentID=129
		BEGIN
			declare @TblName1 nvarchar(30),@TblName2 nvarchar(30),@TblName3 nvarchar(30),@TblName4 nvarchar(30)
			if @DocumentID=103 OR @DocumentID=129
			begin
				set @TblName1='REN_Quotation'
				set @TblName2='REN_QuotationExtended'
				set @TblName3='REN_QuotationParticulars'
				set @TblName4='REN_QuotationPayTerms'
			end
			else
			begin
				set @TblName1='REN_CONTRACT'
				set @TblName2='REN_ContractExtended'
				set @TblName3='REN_ContractParticulars'
				set @TblName4='REN_ContractPayTerms'
			end
			
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,
			case when C.SysTableName='COM_CCCCDATA' then C.SysColumnName+'_Name' else C.SysColumnName end SysColumnName,
			C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
    		FROM ADM_CostCenterDef C WITH(NOLOCK)
    		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
    		WHERE C.CostCenterID=@DocumentID AND C.IsColumnInUse=1 and (C.SysTableName=@TblName1 OR C.SysTableName=@TblName2 OR C.SysTableName='COM_CCCCData')
			union all
    		SELECT @DocumentID,'sqft','sqft','sqft',@TblName3,'','',0,0
    		union all
    		SELECT @DocumentID,'ExcessDaysAmt','ExcessDaysAmt','ExcessDaysAmt',@TblName1,'','',0,0
			UNION ALL
			Select 95,b.Name+'_Codes',b.Name+'_Codes','DIMCodes_'+CONVERT(NVARCHAR,QuickViewCCID),b.TableName,'TEXT','String',0,0 
			From ADM_CostCenterTab a WITH(NOLOCK) 
			JOIN ADM_Features b WITH(NOLOCK) on b.FeatureID=a.QuickViewCCID
			WHERE CostCenterID=95
			AND QuickViewCCID IS NOT NULL AND QuickViewCCID>0
			UNION ALL
			Select 95,b.Name+'_Names',b.Name+'_Names','DIMNames_'+CONVERT(NVARCHAR,QuickViewCCID),b.TableName,'TEXT','String',0,0 
			From ADM_CostCenterTab a WITH(NOLOCK) 
			JOIN ADM_Features b WITH(NOLOCK) on b.FeatureID=a.QuickViewCCID
			WHERE CostCenterID=95
			AND QuickViewCCID IS NOT NULL AND QuickViewCCID>0
			----    		
    		SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
    		FROM ADM_CostCenterDef C WITH(NOLOCK)
    		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
    		WHERE C.CostCenterID=@DocumentID AND C.IsColumnInUse=1 and C.SysTableName=@TblName3
    		union all
    		SELECT  @DocumentID,'Particulars','Particulars','Particulars',@TblName3,'','',0,0
        	union all
    		SELECT  @DocumentID,'Amount With VAT','Amount With VAT','AmountWithVAT',@TblName3,'Float','Float',0,0
    		union all
    		SELECT  @DocumentID,'Rent With VAT','Rent With VAT','RentWithVAT',@TblName3,'Float','Float',0,0
    		union all
    		SELECT  @DocumentID,'Amount Distribute','Amount Distribute','AmountDistribute',@TblName3,'Float','Float',0,0
			union all
    		SELECT  @DocumentID,'DimName','DimName','DimName',@TblName3,'String','String',0,0
    		
        	IF @DocumentID=95
        	BEGIN
        		SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
				C.IsColumnUserDefined,C.ColumnCostCenterID
        		FROM ADM_CostCenterDef C WITH(NOLOCK)
        		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        		WHERE C.CostCenterID=@DocumentID   and C.SysTableName=@TblName4
        		UNION 
        		select @DocumentID,'RefNo','RefNo','RefNo',@TblName4,NULL,NULL,0,0
        		UNION 
        		select @DocumentID,'PostingDate','PostingDate','PostingDate',@TblName4,NULL,NULL,0,0
				union all
    			SELECT  @DocumentID,'DimName','DimName','DimName',@TblName4,'String','String',0,0
        	END
        	ELSE
        	BEGIN
				SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
				C.IsColumnUserDefined,C.ColumnCostCenterID
        		FROM ADM_CostCenterDef C WITH(NOLOCK)
        		LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        		WHERE C.CostCenterID=@DocumentID   and C.SysTableName=@TblName4
				union all
    			SELECT  @DocumentID,'DimName','DimName','DimName',@TblName4,'String','String',0,0
        	END
        		
        	select CONVERT(nvarchar,@DocumentID) as CostCenterID,'Amount' as ResourceData,'Amount' as UserColumnName,'Amount' as SysColumnName,@TblName3 as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
			select CONVERT(nvarchar,@DocumentID) as CostCenterID,'DetailsTotal' as ResourceData,'DetailsTotal' as UserColumnName,'DetailsTotal' as SysColumnName,@TblName3 as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID
			union
			select CONVERT(nvarchar,@DocumentID) as CostCenterID,'TotalAmount' as ResourceData,'TotalAmount' as UserColumnName,'TotalAmount' as SysColumnName,@TblName3 as SysTableName,null as UserColumnType,0 as ColumnDataType,0 as IsColumnUserDefined,0 as ColumnCostCenterID

        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=94 AND C.IsColumnInUse=1 --and C.SysTableName='REN_Tenant'
        		        	
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=92 AND C.IsColumnInUse=1 --and C.SysTableName='REN_Property'
        	
        	SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=93 AND C.IsColumnInUse=1 --and C.SysTableName='REN_UNITS' 
        	and C.CostCenterColID not in (25897,25898,25899)
        	
        	-- Get All Costcenter fields
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	--,LVC.CostCenterColID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.IsColumnInUse=1 and C.CostCenterID in (select featureid  from adm_features with(nolock) where (featureid=4 or featureid > 50000 or C.IsColumnUserDefined=1) and isenabled=1
			union
			 (select ColumnCostCenterID from ADM_CostCenterDef with(nolock) where CostCenterID=@DocumentID and (SysColumnName='ContactID' OR SysColumnName='CustomerID') and IsColumnInUse=1))-- OR SysColumnName='UserID'
			order by C.CostCenterID,ResourceData

        	select featureid, name, tablename  from adm_features WITH(NOLOCK) 
			where isenabled=1 and (featureid=4 or featureid > 50000 or featureid in (select ColumnCostCenterID from ADM_CostCenterDef with(nolock) where CostCenterID=@DocumentID and (SysColumnName='ContactID' OR SysColumnName='CustomerID') and IsColumnInUse=1))-- OR SysColumnName='UserID'
				
		END
		ELSE IF @DocumentID>40000 OR @DocumentID=2 OR @DocumentID=3 OR @DocumentID=72 OR @DocumentID>50000 --added for barcode fields
		BEGIN 
			INSERT INTO @Tbl 
			SELECT REPLACE(SysColumnName, 'dcNum', '') AS Expr1 FROM ADM_CostCenterDef AS C WITH (NOLOCK)
            WHERE (CostCenterID = @DocumentID) AND (IsColumnInUse = 1) AND (SysColumnName LIKE 'dcNum%')
            
            declare @QtyAdjustments int
            if(@DocumentID>40000 AND @DocumentID<50000)
				set @QtyAdjustments=403
			else
				set @QtyAdjustments=0
				
			--Getting Document Fields  
			SELECT  Case when C.SysColumnName like 'dcCalcNumFC%' then R.ResourceData+'_FCCalculated'
						when C.SysColumnName like 'dcCalcNum%' then R.ResourceData+'_Calculated'
						when C.SysColumnName like 'dcCurrID%' then R.ResourceData+'_Currency'
						when C.SysColumnName like 'dcExchRT%' then R.ResourceData+'_ExchangeRate' 
						else R.ResourceData END ResourceData,
						C.UserColumnName,C.SysColumnName,C.SysTableName,case when C.UserColumnType='LISTBOX' and (C.UserProbableValues='H' or C.UserProbableValues='HISTORY') then 'HISTORY' ELSE C.UserColumnType end UserColumnType,C.ColumnDataType,			
						C.IsColumnUserDefined,C.ColumnCostCenterID, Doc.IsInventory,Doc.DocumentType
				FROM ADM_CostCenterDef C WITH(NOLOCK)
				LEFT JOIN ADM_DocumentTypes Doc WITH(NOLOCK) ON C.CostCenterID = Doc.CostCenterID
				LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
				LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
				WHERE C.CostCenterID = @DocumentID 
					AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)
					AND ((C.SysTableName not like 'COM_DocCCData' or C.SysColumnName='VehicleID') AND C.SysColumnName not like 'ProductID')
			
			UNION ALL
			SELECT  R.ResourceData+'_Remarks' ResourceData,
					C.UserColumnName,'dcRemarksNum'+REPLACE(SysColumnName, 'dcNum', ''),C.SysTableName,'','',			
					C.IsColumnUserDefined,C.ColumnCostCenterID, Doc.IsInventory,Doc.DocumentType
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN ADM_DocumentTypes Doc WITH(NOLOCK) ON C.CostCenterID = Doc.CostCenterID
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID = @DocumentID AND (IsColumnInUse = 1) AND (SysColumnName LIKE 'dcNum%') AND  Doc.IsInventory=1 and C.SectionID=4
			UNION ALL
			SELECT  R.ResourceData+'_Remarks' ResourceData,
					C.UserColumnName,'dcPOSRemarksNum'+REPLACE(SysColumnName, 'dcNum', ''),C.SysTableName,'','',			
					C.IsColumnUserDefined,C.ColumnCostCenterID, Doc.IsInventory,Doc.DocumentType
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN ADM_DocumentTypes Doc WITH(NOLOCK) ON C.CostCenterID = Doc.CostCenterID
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID = @DocumentID AND (IsColumnInUse = 1) AND (SysColumnName LIKE 'dcNum%') AND  Doc.IsInventory=1 and C.SectionID>=5
			ORDER BY ResourceData
				
			--To Get Account Fields
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
					C.IsColumnUserDefined,C.ColumnCostCenterID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID=2 AND C.IsColumnInUse=1
			UNION ALL
			SELECT  C.CostCenterID,R.ResourceData+' Code',C.UserColumnName,C.SysColumnName+'_Code',C.SysTableName,C.UserColumnType,C.ColumnDataType,			
					C.IsColumnUserDefined,C.ColumnCostCenterID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID=2 AND C.IsColumnInUse=1 AND C.ColumnCostCenterID=44
			UNION ALL
			SELECT  C.CostCenterID,R.ResourceData+' AliasName',C.UserColumnName,C.SysColumnName+'_AliasName',C.SysTableName,C.UserColumnType,C.ColumnDataType,			
					C.IsColumnUserDefined,C.ColumnCostCenterID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID=2 AND C.IsColumnInUse=1 AND C.ColumnCostCenterID=44
			ORDER BY ResourceData

			--To Get Product Fields
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
					C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID=3 AND C.IsColumnInUse=1
			UNION ALL
			SELECT  C.CostCenterID,R.ResourceData+' Code',C.UserColumnName,C.SysColumnName+'_Code',C.SysTableName,C.UserColumnType,C.ColumnDataType,			
					C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID=3 AND C.IsColumnInUse=1 AND C.ColumnCostCenterID=44
			UNION ALL
			SELECT  C.CostCenterID,R.ResourceData+' AliasName',C.UserColumnName,C.SysColumnName+'_AliasName',C.SysTableName,C.UserColumnType,C.ColumnDataType,			
					C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.CostCenterID=3 AND C.IsColumnInUse=1 AND C.ColumnCostCenterID=44
			ORDER BY ResourceData

			
			-- Get All Costcenter fields
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	--,LVC.CostCenterColID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.IsColumnInUse=1 and C.CostCenterID in (select featureid  from adm_features with(nolock) where (featureid=4 or featureid > 50000 or FeatureID=@QtyAdjustments or (featureid=110 and C.IsColumnUserDefined=1)) and isenabled=1
			union
			 (select ColumnCostCenterID from ADM_CostCenterDef with(nolock) where CostCenterID=@DocumentID and (SysColumnName='ContactID' OR SysColumnName='CustomerID') and IsColumnInUse=1))-- OR SysColumnName='UserID'
			
			UNION ALL
			SELECT  C.CostCenterID,R.ResourceData+' Code',C.UserColumnName,C.SysColumnName+'_Code',C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.IsColumnInUse=1 and C.CostCenterID>50000 AND C.ColumnCostCenterID=44
			UNION ALL
			SELECT  C.CostCenterID,R.ResourceData+' AliasName',C.UserColumnName,C.SysColumnName+'_AliasName',C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.IsColumnInUse=1 and C.CostCenterID>50000 AND C.ColumnCostCenterID=44

			union all

			SELECT distinct 399 CostCenterID,
			case when c.Name='TestCaseID' then 'test case' WHEN c.Name='Unit' THEN 'UnitName' WHEN c.Name='LabID' THEN 'LabName' else c.Name end ResourceData,
			case when c.Name='TestCaseID' then 'TestName' WHEN c.Name='Unit' THEN 'UnitName'  WHEN c.Name='LabID' THEN 'LabName' else c.Name end UserColumnName,
			case when c.Name='TestCaseID' then 'TestName' WHEN c.Name='Unit' THEN 'UnitName'  WHEN c.Name='LabID' THEN 'LabName' else c.Name end SysColumnName,
			o.name SysTableName
			,case when t.name='sysname' then 'nvarchar' else t.name end UserColumnType,case when t.name='sysname' then 'nvarchar' else t.name  end ColumnDataType,			
			0 IsColumnUserDefined,0 ColumnCostCenterID,0 ColumnCCListViewTypeID,'' UserProbableValues
			from sys.columns c
			join sys.types t on t.system_type_id=c.system_type_id
			join sys.objects o on o.object_id=c.object_id
			where o.name in ('INV_DocExtraDetails','INV_ProductTestcases')
			and EXISTS (SELECT * FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName='EnableTestcase' AND PrefValue='True' and CostCenterID=@DocumentID)
			order by C.CostCenterID,ResourceData
			
			select featureid, name, tablename  from adm_features WITH(NOLOCK) 
			where isenabled=1 and (featureid=4 or featureid > 50000 or FeatureID=@QtyAdjustments or featureid in (select ColumnCostCenterID from ADM_CostCenterDef with(nolock) where CostCenterID=@DocumentID and (SysColumnName='ContactID' OR SysColumnName='CustomerID') and IsColumnInUse=1))-- OR SysColumnName='UserID'
			UNION ALL
			select 399 featureid,'QualityControl' name,'INV_DocExtraDetails' tablename
			where EXISTS (SELECT * FROM COM_DocumentPreferences WITH(NOLOCK) WHERE PrefName='EnableTestcase' AND PrefValue='True' and CostCenterID=@DocumentID)
			order by featureid
			
			IF @DocumentID=2 OR @DocumentID=72 OR @DocumentID>50000 
			BEGIN
				SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
				C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	--,LVC.CostCenterColID
				FROM ADM_CostCenterDef C WITH(NOLOCK)
				LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
				LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
				WHERE C.IsColumnInUse=1 and (C.CostCenterID=110) AND SysColumnName not like 'CCNID%'
				
				SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
				C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	--,LVC.CostCenterColID
				FROM ADM_CostCenterDef C WITH(NOLOCK)
				LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
				LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
				WHERE C.IsColumnInUse=1 and (C.CostCenterID=65) AND SysColumnName not like 'CCNID%'
			
			END
			ELSE
			BEGIN
				--BillWise Fields
				SELECT -5 CostCenterID, Name+' Code' ResourceData,'CCNID'+CONVERT(NVARCHAR,(FeatureID-50000))+'_Code' UserColumnName,
				'CCNID'+CONVERT(NVARCHAR,(FeatureID-50000))+'_Code' SysColumnName,TableName SysTableName,'',0,0
				FROM ADM_Features WITH(NOLOCK) WHERE FeatureID>50000 AND FeatureID<=50050 AND IsEnabled=1
				UNION ALL
				SELECT -5, Name+' Name' ResourceData,'CCNID'+CONVERT(NVARCHAR,(FeatureID-50000))+'_Name' UserColumnName,
				'CCNID'+CONVERT(NVARCHAR,(FeatureID-50000))+'_Name' SysColumnName,TableName SysTableName,'',0,0
				FROM ADM_Features WITH(NOLOCK) WHERE FeatureID>50000 AND FeatureID<=50050 AND IsEnabled=1
				ORDER BY ResourceData
				
				SELECT  C.ColumnCostCenterID TrasferDim
				FROM ADM_CostCenterDef C WITH(NOLOCK)
				--LEFT JOIN ADM_DocumentTypes Doc WITH(NOLOCK) ON C.CostCenterID = Doc.CostCenterID
				--LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
				--LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
				WHERE C.CostCenterID=@DocumentID AND (IsColumnInUse = 1) and C.ColumnCostCenterID>50000 AND C.IsTransfer>0
				
				select prefname,prefvalue from com_documentpreferences WITH(NOLOCK) where costcenterid=@DocumentID and (prefname='DistributeCost' or prefname='DistributeCostDims' or Prefname='EnableRevision')
			END
							
		END
		ELSE
		BEGIN
		    SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID
        	FROM ADM_CostCenterDef C WITH(NOLOCK)
        	LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
        	WHERE C.CostCenterID=@DocumentID AND C.IsColumnInUse=1	        	
		END
		
		
		-- Get All Costcenter fields
		IF @DocumentID IN (2,73,86,88,89,94) 
		BEGIN		
			SELECT  C.CostCenterID,R.ResourceData,C.UserColumnName,C.SysColumnName,C.SysTableName,C.UserColumnType,C.ColumnDataType,			
			C.IsColumnUserDefined,C.ColumnCostCenterID,C.ColumnCCListViewTypeID,C.UserProbableValues	--,LVC.CostCenterColID
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID 
			WHERE C.IsColumnInUse=1 and C.CostCenterID in (select featureid  from adm_features with(nolock) where (featureid=4 or featureid > 50000) and isenabled=1)
			order by C.CostCenterID

			select featureid, name, tablename  from adm_features WITH(NOLOCK) 
			where isenabled=1 and (featureid=4 or featureid > 50000)
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
	FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
