USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetVPTMastersData]
	@DocumentID [int],
	@DocumentSeqNo [int],
	@ExtendedDataQuery [nvarchar](max),
	@Attachments [int],
	@UserID [int],
	@UserName [nvarchar](50),
	@LangID [int] = 1,
	@IsFSDoc [bit] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;


	--Declaration Section
	DECLARE @HasAccess BIT, @SQL NVARCHAR(MAX),@TableName NVARCHAR(300)
	DECLARE @code NVARCHAR(200),@no INT, @IsInventoryDoc BIT,@ExtSelectQuery nvarchar(max),@ExtJoinQuery nvarchar(max),@ExtFSQuery NVARCHAR(MAX),@TempExtSelectQuery nvarchar(max)
	DECLARE @VoucherNo NVARCHAR(100),@VoucherType INT,@IsSinglePDC BIT
	DECLARE @AlpCols NVARCHAR(MAX),@sContractCols NVARCHAR(MAX)
	set @sContractCols=''
	set @IsSinglePDC=0
	SET @ExtFSQuery=''
	
	if @DocumentID=95 and exists(select Value from COM_CostCenterPreferences WITH(NOLOCK)
			where CostCenterID=@DocumentID and Name='SinglePDC' and Value ='true' )
		set @IsSinglePDC=1
		
	--Check For Company Fields Exists
	if(@ExtendedDataQuery like '%#PACTCOMPANYID#%')
	begin		
		SET @ExtendedDataQuery=replace(@ExtendedDataQuery,'#PACTCOMPANYID#',replace(db_name(),'PACT2C',''))
	end

	if @ExtendedDataQuery is not null and @ExtendedDataQuery!='' and charindex('~',@ExtendedDataQuery)>0
	begin
		declare @pos int
		set @pos=charindex('~',@ExtendedDataQuery)
		set @ExtSelectQuery=substring(@ExtendedDataQuery,1,@pos-1)
		set @TempExtSelectQuery=substring(@ExtendedDataQuery,1,@pos-1)
		set @ExtJoinQuery=substring(@ExtendedDataQuery,@pos+1,len(@ExtendedDataQuery)-@pos)

		if(CHARINDEX('|',@TempExtSelectQuery)>0)
		BEGIN
			set @pos=charindex('|',@TempExtSelectQuery)
			set @ExtSelectQuery=substring(@TempExtSelectQuery,1,@pos-1)
			set @ExtFSQuery=substring(@TempExtSelectQuery,@pos+1,len(@TempExtSelectQuery)-@pos)
		END
	end
	else
	begin
		set @ExtSelectQuery=''
		set @ExtJoinQuery=''
	end

	IF @DocumentID=78
	BEGIN
		--FINISHED PRODUCTS
	  	set @SQL='SELECT BOM.BOMName, BOM.BOMCode, i.Quantity AS Qty,i.Rate as UnitPrice,i.quantity*i.Rate as Value, OExt.*, O.*, OBOM.MFGOrderBOMID,CONVERT(DATETIME,OrderDate) OrderDate_Date,S.Status,
		(SELECT TOP 1 Particulars FROM PRD_ProductionMethod WITH(NOLOCK) WHERE BOMID=BOM.BOMID) AS ProductionMethod,
		P.ProductCode ProductCode, P.ProductName ProductName,case when P.IsLotwise=1 then ''True'' else ''False'' End as IsLotwise,
		P.AliasName,PT.ProductType  ProductTypeID,VM.ValuationMethod as ValutionID,PS.Status ProductStatus,UOM.BaseName UOMID
		,P.ReorderLevel,P.ReorderQty,P.ShelfLife,P.Packing,P.BarcodeID,PP.ProductName ParentID
		,P.PurchaseRateA,P.PurchaseRateB,P.PurchaseRateC,P.PurchaseRateD,P.PurchaseRateE,P.PurchaseRateF,P.PurchaseRateG
		,P.SellingRateA,P.SellingRateB,P.SellingRatEC,P.SellingRateD,P.SellingRateE,P.SellingRateF,P.SellingRateG
		,DEP.Name DepartmentID,CAT.Name CategoryID,P.PurchaseRate,P.SellingRate,
		O.CreatedBy,CONVERT(DATETIME,O.CreatedDate) CreatedDate,
		O.ModifiedBy,CONVERT(DATETIME,O.ModifiedDate) ModifiedDate
		FROM  PRD_MFGOrder AS O WITH(NOLOCK)
		INNER JOIN PRD_MFGOrderExtd AS OExt WITH(NOLOCK) ON O.MFGOrderID = OExt.MFGOrderID
		INNER JOIN PRD_MFGOrderBOMs AS OBOM WITH(NOLOCK) ON O.MFGOrderID = OBOM.MFGOrderID 
		INNER JOIN PRD_MFGOrderWOs AS WO WITH(NOLOCK) ON WO.MFGOrderBOMID = OBOM.MFGOrderBOMID
		INNER JOIN PRD_MOWODetails AS WOd WITH(NOLOCK) ON WOd.MFGOrderWOID= WO.MFGOrderWOID and  WODetailsID=4
		INNER JOIN PRD_BillOfMaterial AS BOM WITH(NOLOCK) ON OBOM.BOMID = BOM.BOMID
		join inv_docdetails i WITH(NOLOCK) on i.docid=wod.docid
		INNER JOIN INV_Product AS P WITH(NOLOCK) ON i.ProductID = P.ProductID
		INNER JOIN INV_ProductTypes AS PT WITH(NOLOCK) ON P.ProductTypeID=PT.ProductTypeID 
		INNER JOIN INV_ValuationMethods AS VM WITH(NOLOCK) ON P.ValuationID=VM.ValuationID
		INNER JOIN COM_Status AS S WITH(NOLOCK) ON S.StatusID = O.StatusID
		INNER JOIN COM_Status AS PS WITH(NOLOCK) ON PS.StatusID = P.StatusID
		Left JOIN COM_UOM AS UOM WITH(NOLOCK) ON   P.UOMID=UOM.UOMID
		INNER JOIN INV_Product AS PP WITH(NOLOCK) ON P.ParentID = PP.ProductID       
		Left JOIN COM_Department AS DEP WITH(NOLOCK) ON P.DepartmentID=DEP.NodeID 
		Left JOIN COM_Category AS CAT WITH(NOLOCK) ON P.CategoryID=CAT.NodeID 
		WHERE O.MFGOrderID = '+CONVERT(NVARCHAR,@DocumentSeqNo)+'         
		ORDER BY OBOM.MFGOrderBOMID'
		EXEC (@SQL)
		
		--RAW MATERIALS
		set @SQL='SELECT  OBOM.BOMID, WO.WONumber WorkOrderNumber, WOD.WODetailsID, WOD.BOMProductID, WOD.ProdQuantity, WOD.Wastage, WOD.ReturnQty, WOD.NetQuantity, 
		P.ProductCode, P.ProductName, COM_Category.Name AS CategoryName,
		Bp.Quantity ActualQty,                 
		case when  Wo.DocID is not null and Wo.DocID>0 then Bpd.Rate else bp.UnitPrice end as UnitPrice,
		case when  Wo.DocID is not null and Wo.DocID>0 then Bpd.Rate*WOD.NetQuantity else bp.UnitPrice*WOD.NetQuantity end as Value
		,P.AliasName,PT.ProductType  ProductTypeID,VM.ValuationMethod as ValutionID,PS.Status ProductStatus,UOM.BaseName UOMID
		,P.ReorderLevel,P.ReorderQty,P.ShelfLife,P.Packing,P.BarcodeID,PP.ProductName ParentID
		,P.PurchaseRateA,P.PurchaseRateB,P.PurchaseRateC,P.PurchaseRateD,P.PurchaseRateE,P.PurchaseRateF,P.PurchaseRateG
		,P.SellingRateA,P.SellingRateB,P.SellingRatEC,P.SellingRateD,P.SellingRateE,P.SellingRateF,P.SellingRateG
		,DEP.Name DepartmentID,CAT.Name CategoryID,P.PurchaseRate,P.SellingRate
		FROM      PRD_MFGOrder AS O WITH(NOLOCK) 
		INNER JOIN PRD_MFGOrderBOMs AS OBOM WITH(NOLOCK) ON O.MFGOrderID = OBOM.MFGOrderID 
		INNER JOIN PRD_MFGOrderWOs AS WO WITH(NOLOCK) ON OBOM.MFGOrderBOMID = WO.MFGOrderBOMID
		INNER JOIN PRD_MOWODetails AS WOD WITH(NOLOCK) ON WO.MFGOrderWOID = WOD.MFGOrderWOID
		left join PRD_BillOfMaterial B WITH(NOLOCK)on B.BOMID=OBOM.BOMID   
		left join PRD_BOMProducts Bp WITH(NOLOCK)on Bp.BOMID=B.BOMID  and Bp.ProductID=WOD.BOMProductID 
		left join INV_DocDetails BPD WITH(NOLOCK) on BPD.DocID=Wo.DocID and BPD.ProductID=WOD.BOMProductID and WOD.WODetailsID=1
		INNER JOIN INV_Product AS P WITH(NOLOCK) ON WOD.BOMProductID = P.ProductID 
		LEFT JOIN COM_Category WITH(NOLOCK) ON P.CategoryID = COM_Category.NodeID
		INNER JOIN INV_ProductTypes AS PT WITH(NOLOCK) ON P.ProductTypeID=PT.ProductTypeID 
		INNER JOIN INV_ValuationMethods AS VM WITH(NOLOCK) ON P.ValuationID=VM.ValuationID
		INNER JOIN COM_Status AS PS WITH(NOLOCK) ON PS.StatusID = P.StatusID
		Left JOIN COM_UOM AS UOM WITH(NOLOCK) ON   P.UOMID=UOM.UOMID
		INNER JOIN INV_Product AS PP WITH(NOLOCK) ON P.ParentID = PP.ProductID
		Left JOIN COM_Department AS DEP WITH(NOLOCK) ON P.DepartmentID=DEP.NodeID 
		Left JOIN COM_Category AS CAT WITH(NOLOCK) ON P.CategoryID=CAT.NodeID 
		WHERE  O.MFGOrderID = '+CONVERT(NVARCHAR,@DocumentSeqNo)+' AND WOD.WODetailsID=1
		ORDER BY COM_Category.Code, WorkOrderNumber'
		EXEC (@SQL)

		--PRODUCTION METHODS
		set @SQL='SELECT BOM.BOMName, BOM.BOMCode,PM.Particulars
		FROM PRD_ProductionMethod AS PM WITH(NOLOCK)       
		INNER JOIN PRD_MFGOrder AS O WITH(NOLOCK) ON PM.MOID = O.MFGOrderID 
		LEFT JOIN PRD_BillOfMaterial AS BOM WITH(NOLOCK) ON BOM.BOMID = PM.BOMID
		WHERE O.MFGOrderID = '+CONVERT(NVARCHAR,@DocumentSeqNo)+'
		ORDER BY BOM.BOMName'
		EXEC (@SQL)
		
		set @SQL='declare @tab table(docid INT,crname INT,drname INT,amount float,voucherno nvarchar(100),date float,Currency INT,lname nvarchar(200))
		declare @tab1 table(docid INT,crname INT,drname INT,amount float,voucherno nvarchar(100),date float,Currency INT,lname nvarchar(200))

		insert into @tab
		select  a.docid,a.CreditAccount, a.DebitAccount,amount,a.voucherno,docdate,A.CurrencyID,l.name
		from PRD_MFGDocRef M WITH(NOLOCK)  
		inner join acc_docdetails A WITH(NOLOCK) on A.docid=M.accdocid  
		inner join COM_docccData CC WITH(NOLOCK) on CC.accdocdetailsid=A.accdocdetailsid
		inner join COM_LOCATION L WITH(NOLOCK) on L.NodeID=CC.dcCCNID2  
		where M.MFGOrderID='+CONVERT(NVARCHAR,@DocumentSeqNo)+'   and a.CreditAccount<>-99
		 
		insert into @tab1 
		select a.docid, a.CreditAccount, a.DebitAccount,amount,a.voucherno,docdate,CurrencyID,''''
		from PRD_MFGDocRef M WITH(NOLOCK)  
		inner join acc_docdetails A WITH(NOLOCK) on A.docid=M.accdocid   
		where M.MFGOrderID='+CONVERT(NVARCHAR,@DocumentSeqNo)+'   and a.DebitAccount<>-99
				
		select  CR.AccountName CreditAccount,Dr.AccountName DebitAccount,Amount,VoucherNo,convert(datetime,date) DocDate,C.Name CurrencyID,lname Location from
		(select case when a.crname =-99 then b.crname else a.crname end as cr,
		case when a.drname =-99 then b.drname else a.drname end as dr,  a.Amount ,a.date,a.voucherno,a.Currency,a.docid,a.lname from @tab a
		join @tab1 b on a.voucherno=b.voucherno) as t
		inner join ACC_Accounts CR WITH(NOLOCK)on CR.AccountID=t.cr  
		inner join ACC_Accounts Dr WITH(NOLOCK)on Dr.AccountID=t.dr
		left join COM_CURRENCY C WITH(NOLOCK) on C.CurrencyID=t.Currency
		union ALL
		select distinct  CR.AccountName CreditAccount,Dr.AccountName DebitAccount,amount,a.voucherno, convert(datetime,a.docdate) docdate,C.Name CurrencyID,l.name Location
		from PRD_MFGDocRef M WITH(NOLOCK)  
		inner join inv_docdetails i WITH(NOLOCK) on i.docid=M.invdocid 
		inner join acc_docdetails A WITH(NOLOCK) on i.invdocdetailsid  =A.invdocdetailsid
		inner join ACC_Accounts CR WITH(NOLOCK)on CR.AccountID=A.CreditAccount  
		inner join ACC_Accounts Dr WITH(NOLOCK)on Dr.AccountID=A.DebitAccount
		inner join COM_docccData CC WITH(NOLOCK) on CC.invdocdetailsid=i.invdocdetailsid
		inner join COM_LOCATION L WITH(NOLOCK) on L.NodeID=CC.dcCCNID2  
		left join COM_CURRENCY C WITH(NOLOCK) on C.CurrencyID=A.CurrencyID
		where M.MFGOrderID='+CONVERT(NVARCHAR,@DocumentSeqNo)+'
			
		create table #TEMP(id int identity(1,1),CA INT,DA INT,Amount float)
		insert into #TEMP(CA,DA,Amount) 
		select  t.cr,t.dr ,sum(Amount )from
		(select case when a.crname =-99 then b.crname else a.crname end as cr,
		case when a.drname =-99 then b.drname else a.drname end as dr,  a.Amount ,a.date,a.voucherno,a.Currency,a.docid,a.lname from @tab a
		join @tab1 b on a.voucherno=b.voucherno) as t
		inner join ACC_Accounts CR WITH(NOLOCK)on CR.AccountID=t.cr  
		inner join ACC_Accounts Dr WITH(NOLOCK)on Dr.AccountID=t.dr
		left join COM_CURRENCY C WITH(NOLOCK) on C.CurrencyID=t.Currency
		group by t.cr,t.dr
		union ALL
		select distinct  a.CreditAccount, a.DebitAccount,sum(amount)
		from PRD_MFGDocRef M WITH(NOLOCK)  
		inner join inv_docdetails i WITH(NOLOCK) on i.docid=M.invdocid 
		inner join acc_docdetails A WITH(NOLOCK) on i.invdocdetailsid  =A.invdocdetailsid
		inner join COM_docccData CC WITH(NOLOCK) on CC.invdocdetailsid=i.invdocdetailsid
		inner join COM_LOCATION L WITH(NOLOCK) on L.NodeID=CC.dcCCNID2  
		where M.MFGOrderID='+CONVERT(NVARCHAR,@DocumentSeqNo)+'
		group by a.CreditAccount, a.DebitAccount
	                              
        DECLARE @TABLE1 TABLE(ID INT IDENTITY(1,1),ACCOUNT INT,CR FLOAT,DR FLOAT)
        
        DECLARE @COUNT INT ,@SCOPE INT,@CR FLOAT,@DR FLOAT,@ACC INT, @k int
        SET @k=1
        SELECT @COUNT=COUNT(*) FROM #TEMP with(nolock)
        WHILE @k<=@COUNT
        BEGIN
			SELECT @ACC=CA FROM #TEMP with(nolock) WHERE ID=@k
			IF((SELECT COUNT(*) FROM @TABLE1 WHERE ACCOUNT=@ACC)=0)
			BEGIN
                    
				INSERT INTO @TABLE1 VALUES (@ACC,0,0)
				SET @SCOPE=SCOPE_IDENTITY()

				SELECT @CR=ISNULL(SUM(Amount),0) FROM #TEMP with(nolock) WHERE CA=@ACC
				SELECT @DR=ISNULL(SUM(Amount),0) FROM #TEMP with(nolock) WHERE DA=@ACC
				UPDATE @TABLE1 SET CR=@CR WHERE ID=@SCOPE
				UPDATE @TABLE1 SET DR=@DR WHERE ID=@SCOPE
    
			END
			SET @CR=0
			SET @DR=0
			SET @ACC=0
			SELECT @ACC=DA FROM #TEMP with(nolock) WHERE ID=@k
			IF((SELECT COUNT(*) FROM @TABLE1 WHERE ACCOUNT=@ACC)=0)
			BEGIN
                    
				INSERT INTO @TABLE1 VALUES (@ACC,0,0)
				SET @SCOPE=SCOPE_IDENTITY()

				SELECT @CR=ISNULL(SUM(Amount),0) FROM #TEMP with(nolock) WHERE CA=@ACC
				SELECT @DR=ISNULL(SUM(Amount),0) FROM #TEMP with(nolock) WHERE DA=@ACC
				UPDATE @TABLE1 SET CR=@CR WHERE ID=@SCOPE
				UPDATE @TABLE1 SET DR=@DR WHERE ID=@SCOPE
                    
    
            END
			SET @k=@k+1
        END
                
        SELECT A.AccountName Account,CR CreditAmount,DR DebitAmount 
        FROM @TABLE1 T inner join Acc_Accounts A with(nolock) on A.AccountID=T.ACCOUNT

        drop table #TEMP'
		EXEC (@SQL) 			
	END
	IF @DocumentID=76
	BEGIN
		--PRODUCTION METHODS
		set @SQL='SELECT BOM.BOMCode,BOM.BOMName,S.Status StatusID,BOM.CreatedBy,CONVERT(DATETIME,BOM.CreatedDate) CreatedDate,BOM.ModifiedBy,CONVERT(DATETIME,BOM.ModifiedDate) ModifiedDate,UOM.BaseName UOMID,PP.ProductName ProductID,L.Name LocationID,D.Name DivisionID,CONVERT(DATETIME,BOM.BOMDate) Date,BOM.*,BOMEXT.*
		FROM PRD_BillOfMaterial AS BOM WITH(NOLOCK) 
		LEFT JOIN PRD_BillOfMaterialExtended AS BOMEXT ON BOM.BOMID=BOMEXT.BOMID
		LEFT JOIN COM_STATUS S WITH(NOLOCK) ON BOM.StatusID=S.StatusID
		Left JOIN COM_UOM AS UOM WITH(NOLOCK) ON   BOM.UOMID=UOM.UOMID
		INNER JOIN INV_Product AS PP WITH(NOLOCK) ON BOM.ProductID = PP.ProductID 
		left join COM_LOCATION L WITH(NOLOCK) on L.NodeID=BOM.LocationID
		left join COM_DIVISION D WITH(NOLOCK) on D.NodeID=BOM.DivisionID 
		WHERE BOM.BOMID = '+CONVERT(NVARCHAR,@DocumentSeqNo)+''
		EXEC (@SQL)		
		
	END
	ELSE IF @DocumentID=88
	BEGIN
		set @SQL='SELECT '+@ExtSelectQuery+'A.Code,A.Name,S.Status StatusID,L.Name CampaignTypeLookupID,A.ExpectedResponse,A.Offer,L1.Name VendorLookupID,CONVERT(DATETIME,A.ProposedStartDate) ProposedStartDate,CONVERT(DATETIME,A.ProposedEndDate) ProposedEndDate,CONVERT(DATETIME,A.ActualStartDate) ActualStartDate,CONVERT(DATETIME,A.ActualEndDate) ActualEndDate,
			A.BudgetAllocated,A.EstimatedRevenue,PRO.ProductName PRODUCT_ProductName,U.BaseName PRODUCT_UOM,CP.UnitPrice PRODUCT_Price,
			A.CreatedBy,CONVERT(DATETIME,A.CreatedDate) CreatedDate,A.ModifiedBy,CONVERT(DATETIME,A.ModifiedDate) ModifiedDate
			FROM CRM_Campaigns A WITH(NOLOCK)
			LEFT JOIN COM_STATUS S WITH(NOLOCK) ON A.StatusID=S.StatusID
			LEFT JOIN COM_LOOKUP L WITH(NOLOCK) ON A.CampaignTypeLookupID=L.NodeID
			LEFT JOIN COM_LOOKUP L1 WITH(NOLOCK) ON A.VendorLookupID=L1.NodeID
			LEFT JOIN CRM_CampaignProducts CP WITH(NOLOCK) ON CP.CampaignID=A.CampaignID
			LEFT JOIN INV_Product PRO WITH(NOLOCK) on CP.ProductID=PRO.ProductID
			LEFT JOIN COM_UOM U WITH(NOLOCK) on CP.UOMID=U.UOMID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.CampaignID=CC.NodeID and CC.CostCenterID=88
			'+@ExtJoinQuery+'
			WHERE A.CampaignID='+convert(nvarchar,@DocumentSeqNo)
		--Print(@SQL)
		EXEC(@SQL)
	END
	ELSE IF (@DocumentID=2 or @DocumentID=3 OR @DocumentID=73 OR @DocumentID=84 OR @DocumentID=86 OR @DocumentID=89 OR @DocumentID=95 OR @DocumentID=103 OR @DocumentID=104 OR @DocumentID=129 or @DocumentID>50000)
	BEGIN
		Declare @CustomQuery1 nvarchar(max),@FeatureName nvarchar(100),@CustomQuery3 nvarchar(max),@CustomQueryNoName nvarchar(max),@i int ,@CNT int,@Table nvarchar(100),@TabRef nvarchar(3),@CCID int
		create table #CustomTable(ID int identity(1,1),CostCenterID int)
		
		IF @DocumentID!=50051
		BEGIN
			if @DocumentID=95 OR @DocumentID=103 OR @DocumentID=104 OR @DocumentID=129
				insert into #CustomTable(CostCenterID)
				select FeatureID from adm_Features with(nolock) where FeatureID>50000 and IsEnabled=1 and FeatureID<>50054
			else
				insert into #CustomTable(CostCenterID)
				select ColumnCostCenterID from adm_CostCenterDef WITH(NOLOCK) 
				where CostCenterID=@DocumentID and SystableName='COM_CCCCDATA' and ColumnCostCenterID>50000
		END
		set @i=1
		set @CustomQuery1=''
		set @CustomQuery3=', '
		set @CustomQueryNoName=', '
		select @CNT=count(id) from #CustomTable WITH(NOLOCK)

		while (@i<=	@CNT)
		begin
			select @CCID=CostCenterID from #CustomTable WITH(NOLOCK) where ID=@i
	 
			select @Table=TableName,@FeatureName=FeatureID from adm_features WITH(NOLOCK) where FeatureID = @CCID
			set @TabRef='A'+CONVERT(nvarchar,@i)
			set @CCID=@CCID-50000
	    	 
			if(@CCID>0)
			begin
				set @CustomQuery1=@CustomQuery1+' left join '+@Table+' '+@TabRef+' WITH(NOLOCK) on '+@TabRef+'.NodeID=CC.CCNID'+CONVERT(nvarchar,@CCID)
				set @CustomQuery3=@CustomQuery3+' '+@TabRef+'.Name as CCNID'+CONVERT(nvarchar,@CCID)+'_Name ,'
				set @CustomQueryNoName=@CustomQueryNoName+' '+@TabRef+'.Name as CCNID'+CONVERT(nvarchar,@CCID)+' ,'
			end
			set @i=@i+1
		end
		
		if(len(@CustomQuery3)>0)
		begin
			set @CustomQuery3=SUBSTRING(@CustomQuery3,0,LEN(@CustomQuery3)-1)
			set @CustomQueryNoName=SUBSTRING(@CustomQueryNoName,0,LEN(@CustomQueryNoName)-1)
		end

		--SELECT @CustomQuery1,@CustomQuery3,@CustomQueryNoName
		IF @DocumentID=84
		BEGIN
			set @SQL='SELECT A.DocID,convert(datetime,A.Date) as Date,S.Status as ContractStatus,CT.CTemplName ContractTemplID,C.CustomerName CustomerID,convert(datetime,A.StartDate) as StartDate,convert(datetime,A.EndDate) as EndDate,CT.BillFrequencyName as BillingScheduleID,
			LL.DocID as [GROUP],P.ProductName as PRODUCT_ProductName,CL.LineNumber PRODUCT_Number,CL.SerialNumber PRODUCT_SerialNumber,CL.AllottedUnits PRODUCT_AllottedUnits,CL.Price PRODUCT_Price,CL.ServicePrice PRODUCT_ServicePrice,
			Case when CL.UnitsType=1 then ''Cases'' else ''Minutes'' end [PRODUCT_UnitsType],convert(datetime,CL.SvcStartDate) as PRODUCT_StartDate,convert(datetime,CL.SvcEndDate) as PRODUCT_EndDate,
			Case when SCH.FreqType=1 then ''Once'' when  SCH.FreqType=4 then ''Daily'' when  SCH.FreqType=8 then ''Weekly'' else ''Monthly'' end PRODUCT_Schedule,R.ResourceName as PRODUCT_Employee,
			Case when CL.SvcFrequencyName=1 then ''Monthly'' when  CL.SvcFrequencyName=2 then ''Quarterly'' when  CL.SvcFrequencyName=3 then ''Semi-Annually'' when  CL.SvcFrequencyName=4 then ''Annually'' else ''Adhoc'' end PRODUCT_Frequency
			,Case when CL.StatusID=395 then ''Active'' else ''InActive'' End PRODUCT_Status,CL.voucherno PRODUCT_VoucherNo'+@CustomQuery3+',EXT.*,CL.Discount PRODUCT_Discount,CL.NetPrice PRODUCT_NetPrice,
				A.CreatedBy,CONVERT(DATETIME,A.CreatedDate) CreatedDate,
        	A.ModifiedBy,CONVERT(DATETIME,A.ModifiedDate) ModifiedDate
			FROM CRM_ServiceContract A WITH(NOLOCK)
			LEFT JOIN CRM_ServiceContract LL WITH(NOLOCK) on A.ParentID=LL.SvcContractID
			LEFT JOIN CRM_ContractLines CL WITH(NOLOCK) on A.SvcContractID=CL.SvcContractID
			LEFT JOIN COM_STATUS S WITH(NOLOCK) on A.StatusID=S.StatusID 
			LEFT JOIN CRM_ContractTemplate CT WITH(NOLOCK) on A.ContractTemplID=CT.ContractTemplID
			LEFT JOIN CRM_customer C WITH(NOLOCK) on A.CustomerID=C.CustomerID
			LEFT JOIN INV_Product P WITH(NOLOCK) on CL.ProductID=P.ProductID
			LEFT JOIN COM_SCHEDULES SCH WITH(NOLOCK) on CL.ScheduleID=SCH.ScheduleID
			LEFT JOIN PRD_Resources R WITH(NOLOCK) on CL.Employeeid=R.ResourceID
			LEFT JOIN CRM_ServiceContractExtd EXT WITH(NOLOCK) on A.SvcContractID=EXT.SvcContractID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.SvcContractID=CC.NodeID and CC.CostCenterID=84'
			+@CustomQuery1+'
			where A.SvcContractID='+convert(nvarchar,@DocumentSeqNo)
			--print(@SQL)
			exec(@SQL)
		END
        ELSE IF @DocumentID=86
		BEGIN
			set @SQL='SELECT '+@ExtSelectQuery+'A.Code,A.Subject,convert(datetime,A.Date) as Date,A.Company,O.COMPANY AS [Group],S.Status as StatusID,L1.Name SourceLookUpID,L2.Name RatinglookupID,L3.Name IndustryLookUpID,
			C.Name CampaignID,L4.Name ContactType,D.FirstName,D.MiddleName,D.LastName,
			L5.Name SalutationID,D.JobTitle,D.Phone1,D.Phone2,D.Email1,D.Fax,D.Department,L6.Name RoleLookupID,D.Address1,D.Address2,D.Address3,D.City,D.State,
			D.Zip,L7.Name Country,D.Gender,convert(datetime,D.Birthday) as Birthday,convert(datetime,D.Anniversary) as Anniversary,A.CreatedBy as AssignedTo,
			convert(datetime,A.CreatedDate) as AssignedDate, convert(datetime,A.CreatedDate) as CreatedDate,A.CreatedBy as Owner,D.PreferredName'+@CustomQuery3+',EXT.*,
			case when D.IsEmailOn=0 then ''NO'' else ''YES'' end [IsEmailOn],
			case when D.IsBulkEmailOn=0 then ''NO'' else ''YES'' end [IsBulkEmailOn],
			case when D.IsMailOn=0 then ''NO'' else ''YES'' end [IsMailOn],
			case when D.IsPhoneOn=0 then ''NO'' else ''YES'' end [IsPhoneOn],
			case when D.IsFaxOn=0 then ''NO'' else ''YES'' end [IsFaxOn],
			A.CreatedBy,CONVERT(DATETIME,A.CreatedDate) CreatedDate,
			A.ModifiedBy,CONVERT(DATETIME,A.ModifiedDate) ModifiedDate
			FROM crm_leads A  WITH(NOLOCK)
			lEFT JOIN crm_leads O  WITH(NOLOCK) on A.PARENTID=O.LeadID
			LEFT JOIN CRM_Campaigns C WITH(NOLOCK) on A.CampaignID=C.CampaignID
			LEFT JOIN COM_STATUS S WITH(NOLOCK) on A.StatusID=S.StatusID
			LEFT JOIN CRM_CONTACTS D WITH(NOLOCK) on D.FeatureID=86 AND D.FeaturePK='+convert(nvarchar,@DocumentSeqNo)+'
			LEFT JOIN COM_LOOKUP L1 WITH(NOLOCK) on A.SourceLookUpID=L1.NodeID
			LEFT JOIN COM_LOOKUP L2 WITH(NOLOCK) on A.RatingLookUpID=L2.NodeID
			LEFT JOIN COM_LOOKUP L3 WITH(NOLOCK) on A.RatingLookUpID=L3.NodeID
			LEFT JOIN COM_LOOKUP L4 WITH(NOLOCK) on L4.NodeID=53
			LEFT JOIN COM_LOOKUP L5 WITH(NOLOCK) on D.SalutationID=L5.NodeID
			LEFT JOIN COM_LOOKUP L6 WITH(NOLOCK) on D.RoleLookUpID=L6.NodeID
			LEFT JOIN COM_LOOKUP L7 WITH(NOLOCK) on D.Country=L7.NodeID
			LEFT JOIN CRM_LeadsExtended EXT WITH(NOLOCK) on A.LeadID=EXT.LeadID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.LeadID=CC.NodeID and CC.CostCenterID=86'
			+@ExtJoinQuery+@CustomQuery1+'
			where A.LeadID='+convert(nvarchar,@DocumentSeqNo)
				--print(@SQL)
				--print(substring(@SQL,4001,4000))
				
			exec(@SQL)

			
			SET @AlpCols=''
			SELECT @AlpCols=STUFF( (SELECT ','+Name FROM Sys.Columns WITH(NOLOCK) WHERE object_id=OBJECT_ID('CRM_Feedback') AND Name Like 'Alpha%'  FOR XML PATH('') ),1,1,'') 

			set @SQL='select NodeID,Convert(Datetime,Date) Date,Convert(Datetime,Date) FILTERDATE,FeedBack'
			IF(LEN(@AlpCols)>0)
				SET @SQL+=','+@AlpCols
			SET @SQL+=' from  CRM_Feedback WITH(NOLOCK) 
			where CCID=86 and CCNodeID='+convert(nvarchar,@DocumentSeqNo)
			exec(@SQL)

			
			SET @AlpCols=''
			SELECT @AlpCols=STUFF( (SELECT ',A.'+Name FROM Sys.Columns WITH(NOLOCK) WHERE object_id=OBJECT_ID('crm_activities') AND Name Like 'Alpha%'  FOR XML PATH('') ),1,1,'') 

			set @SQL='SELECT A.ActivityID,CASE WHEN ACTIVITYTYPEID=1 THEN ''Appointment Regular'' WHEN ACTIVITYTYPEID=2 THEN ''Task Regular'' WHEN ACTIVITYTYPEID=3 THEN ''Appointment Recurring'' ELSE ''Task Recurring'' END AS ActivityTypeID,
			Com_Status.Status as StatusID,Subject,Case when Priority=0 then ''Low'' when Priority=1 then ''Normal'' else ''High'' End as Priority,PctComplete [Complete%],Location,
			case when IsAllDayActivity=0 then ''No'' else ''Yes'' end IsAllDayActivity,CustomerID,Remarks,Convert(Datetime,StartDate) StartDate,convert(Datetime,EndDate) EndDate,StartTime,EndTime'
			IF(LEN(@AlpCols)>0)
				SET @SQL+=','+@AlpCols
			SET @SQL+=' From crm_activities A with(nolock)
			Left Join Com_Status WITH(NOLOCK) on A.StatusID=Com_Status.StatusID
			where  A.costcenterid=86 and A.nodeid='+convert(nvarchar,@DocumentSeqNo)
			exec(@SQL)
			
			select	NT.Note Notes From COM_Notes NT WITH(NOLOCK) where  NT.FeatureID=86 and NT.FeaturePK=convert(nvarchar,@DocumentSeqNo)
			    
		    set @SQL='select CVR.*,Convert(Datetime,CVR.Date) as CVRDate,P.ProductName
		    from CRM_LeadCVRDetails CVR with(nolock)
		    inner join INV_Product P WITH(NOLOCK) on CVR.Product=P.ProductID
		    where CVR.CCID=86 and CVR.CCNodeID='+convert(nvarchar,@DocumentSeqNo)
			exec(@SQL) 
		    
		    --assigned users email address
		    exec spCOM_GetAssignedUserEmailAddress 86,@DocumentSeqNo
		    
		    Declare @LD1 nvarchar(max),@LDFeatureName nvarchar(100),@LDCustomQuery3 nvarchar(max),@LDi int ,@LDCNT int,@LDTable nvarchar(100),@LDTabRef nvarchar(3),@LDCCID int
			Declare @LDCustomTable table(ID int identity(1,1),CostCenterID int)
			insert into @LDCustomTable(CostCenterID)
			select ColumnCostCenterID from adm_CostCenterDef WITH(NOLOCK) where CostCenterID=3 and SystableName='COM_CCCCDATA' and ColumnCostCenterID>50000 and IsColumnInUse=1 

			set @LDi=1
			set @LD1=''
			set @LDCustomQuery3=', '
			select @LDCNT=count(id) from @LDCustomTable
			while (@LDi<=	@LDCNT)
			begin
				
				select @LDCCID=CostCenterID from @LDCustomTable where ID=@LDi
		 
				select @LDTable=TableName,@LDFeatureName=FeatureID from adm_features WITH(NOLOCK) where FeatureID = @LDCCID
				set @LDTabRef='A'+CONVERT(nvarchar,@LDi)
				set @LDCCID=@LDCCID-50000
		    	 
				if(@LDCCID>0)
				begin
					set @LD1=@LD1+' left join '+@LDTable+' '+@LDTabRef+' WITH(NOLOCK) on '+@LDTabRef+'.NodeID=CC.CCNID'+CONVERT(nvarchar,@LDCCID)
					set @LDCustomQuery3=@LDCustomQuery3+' '+@LDTabRef+'.Name as CCNID'+CONVERT(nvarchar,@LDCCID)+'_Name ,'+@LDTabRef+'.Code as CCNID'+CONVERT(nvarchar,@LDCCID)+'_Code ,'
				end
				set @LDi=@LDi+1
			end
				
			if(len(@LDCustomQuery3)>0)
			begin
				set @LDCustomQuery3=SUBSTRING(@LDCustomQuery3,0,LEN(@LDCustomQuery3)-1)
			end
			
			declare @Alphatable table(id int identity(1,1),name nvarchar(50),field nvarchar(50))
			declare @AlphaColumns nvarchar(max),@Alphai INT,@AlphaCnt INT

			insert into @Alphatable (name,field)
			select Usercolumnname,Syscolumnname from adm_Costcenterdef WITH(NOLOCK)
			where costcenterid=3 and IsColumnInUse=1 and Systablename='INV_ProductExtended'

			set @Alphai=1
			select @AlphaCnt=count(id) from @Alphatable
			set @AlphaColumns=''

			while(@Alphai<=@AlphaCnt)
			begin
				select @AlphaColumns=@AlphaColumns+',PROEXED.'+field from @Alphatable where @Alphai=id
				set @Alphai=@Alphai+1
			end

			set @SQL='select P.ProductMapID,PRO.AliasName,PRO.BarcodeID'
			if(@AlphaColumns is not null and @AlphaColumns<>'')
			begin
				set @SQL=@SQL+@AlphaColumns
			end						
			
		    set @SQL=@SQL+',PRO.IsLotwise,PRO.ManufacturerBarcode,PRO.Packing
			,PRO.ProductCode,PRO1.ProductName as ParentID,PRO.ProductName,PRO.PurchaseRate,PRO.PurchaseRateA,PRO.PurchaseRateB,PRO.PurchaseRateC,PRO.PurchaseRateD,PRO.PurchaseRateE
			,PRO.PurchaseRateF,PRO.PurchaseRateG,PRO.ReorderLevel,PRO.ReorderQty,PRO.SellingRate,PRO.SellingRateA,PRO.SellingRateB,PRO.SellingRateC,PRO.SellingRateD
			,PRO.SellingRateE,PRO.SellingRateF,PRO.SellingRateG,PRO.ShelfLife'+@LDCustomQuery3+'
			FROM crm_leads L  WITH(NOLOCK)
			LEFT JOIN CRM_ProductMapping P WITH(NOLOCK) on P.CostcenterID=86 AND P.CCNodeID=L.LeadID 
			LEFT JOIN INV_Product PRO WITH(NOLOCK) on P.ProductID=PRO.ProductID
			LEFT JOIN INV_Product PRO1 WITH(NOLOCK) on PRO1.ProductID=PRO.ParentID
			LEFT JOIN INV_ProductExtended PROEXED WITH(NOLOCK) on PROEXED.ProductID=P.ProductID
			LEFT JOIN COM_UOM U WITH(NOLOCK) on P.UOMID=U.UOMID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on P.ProductID=CC.NodeID and CC.CostCenterID=3'
			+@LD1+'
			where L.LeadID='+convert(nvarchar,@DocumentSeqNo)+' order by P.ProductMapID'
			--	print(@SQL)
			exec(@SQL)
						
			--Product Mapping Fields
			Declare @PrefID INT,@PrefTable nvarchar(50),@CP nvarchar(max),@CPFeatureName nvarchar(100),@CPCustomQuery3 nvarchar(max),@CPi int ,@CPCNT int,@CPTable nvarchar(100),@CPTabRef nvarchar(3),@CPCCID int
			Declare @CPCustomTable table(ID int identity(1,1),CostCenterID int)
			insert into @CPCustomTable(CostCenterID)
			select ColumnCostCenterID from adm_CostCenterDef WITH(NOLOCK) where CostCenterID=115 and SysColumnName  like '%CCNID%' and ColumnCostCenterID>50000 and IsColumnInUse=1 

			set @CPi=1
			set @CP=''
			set @CPCustomQuery3=', '
			select @CPCNT=count(id) from @CPCustomTable
			while (@CPi<=	@CPCNT)
			begin

				select @CPCCID=CostCenterID from @CPCustomTable where ID=@CPi

				select @CPTable=TableName,@CPFeatureName=FeatureID from adm_features WITH(NOLOCK) where FeatureID = @CPCCID
				set @CPTabRef='A'+CONVERT(nvarchar,@CPi)
				set @CPCCID=@CPCCID-50000
				 
				if(@CPCCID>0)
				begin
					set @CP=@CP+' left join '+@CPTable+' '+@CPTabRef+' WITH(NOLOCK) on '+@CPTabRef+'.NodeID=P.CCNID'+CONVERT(nvarchar,@CPCCID)
					set @CPCustomQuery3=@CPCustomQuery3+' '+@CPTabRef+'.Name as CCNID'+CONVERT(nvarchar,@CPCCID)+' ,'
				end
				set @CPi=@CPi+1
			end

			if(len(@CPCustomQuery3)>0)
			begin
				set @CPCustomQuery3=SUBSTRING(@CPCustomQuery3,0,LEN(@CPCustomQuery3)-1)
			end
			
			declare @Alpha1table table(id int identity(1,1),name nvarchar(50),field nvarchar(50))
			declare @Alpha1Columns nvarchar(max),@Alpha1i INT,@Alpha1Cnt INT

			insert into @Alpha1table (name,field)
			select Usercolumnname,Syscolumnname from adm_Costcenterdef WITH(NOLOCK)
			where costcenterid=115 and IsColumnInUse=1 and Syscolumnname like '%alpha%'

			set @Alpha1i=1
			select @Alpha1Cnt=count(id) from @Alpha1table
			set @Alpha1Columns=''

			while(@Alpha1i<=@Alpha1Cnt)
			begin
				select @Alpha1Columns=@Alpha1Columns+' ,P.'+field from @Alpha1table where @Alpha1i=id
				set @Alpha1i=@Alpha1i+1
			end

			set @Alpha1Columns=substring(@Alpha1Columns,2,len(@Alpha1Columns))
			
			select @PrefID=value from adm_globalpreferences WITH(NOLOCK) where name='CRM-Products'
			
			if(@PrefID is not null and @PrefID<>'')
			begin
				select @PrefTable=tablename from adm_features WITH(NOLOCK) where featureid=@PrefID
			end
			
			set @SQL='select P.ProductMapID,U.UnitName UOMID'+@CPCustomQuery3+',P.Quantity'
					
			if(@PrefID is not null and @PrefID<>'')
			begin
				select @PrefTable=tablename from adm_features WITH(NOLOCK) where featureid=@PrefID
				set @SQL=@SQL+' ,CRM.Name CRMProduct'
			end
			
			if(@Alpha1Columns is not null and @Alpha1Columns<>'')
			begin
				set @SQL=@SQL+@Alpha1Columns
			end
			
			set @SQL=@SQL+' ,P.Remarks,P.Description
			FROM crm_leads L  WITH(NOLOCK)
			LEFT JOIN CRM_ProductMapping P WITH(NOLOCK) on P.CostcenterID=86 AND P.CCNodeID=L.LeadID'
			 
			if(@PrefID is not null and @PrefID<>'')
			begin
				set @SQL=@SQL+' LEFT JOIN '+@PrefTable+' CRM WITH(NOLOCK) on P.CRMProduct=CRM.NodeID'
			end
			
			set @SQL=@SQL+' LEFT JOIN COM_UOM U WITH(NOLOCK) on P.UOMID=U.UOMID'
			+@CP+'
			where L.LeadID='+convert(nvarchar,@DocumentSeqNo)+' order by P.ProductMapID'
			--print(@SQL)
			exec(@SQL)
  
		END
		ELSE IF @DocumentID=2
		BEGIN
			set @SQL='	SELECT '+@ExtSelectQuery+'A.AccountCode,A.AccountName,A.AliasName,AG.AccountName [ParentID],case when A.IsBillWise=''0'' then ''No'' else ''yes'' END AS IsBillWise, 
			case when A.IsGroup=''0'' then ''False'' else ''True'' END AS IsGroup,
			CO.AccountName COGSACCOUNTID,
			CLOSING.AccountName ClosingStockAccountID,
			PDC.AccountName PDCReceivableAccount,
			PDCPayable.AccountName PDCPayableAccount,PDCDiscount.AccountName PDCDiscountAccount 
			,SalesAccount.AccountName SalesAccount 
			,PurchaseAccount.AccountName PurchaseAccount,PT.ResourceData StatusID,CU.Name Currency,
			case when A.CrOptionID=''0'' then ''Due Date'' when A.CrOptionID=''1'' then ''First Day of Month'' when A.CrOptionID=''2'' then ''Last Day of Month''
			when A.CrOptionID=''4'' then ''BillingCycle'' else ''Due Date'' END AS CrOptionID,
			case when A.DrOptionID=''0'' then ''Due Date'' when A.DrOptionID=''1'' then ''First Day of Month'' when A.DrOptionID=''2'' then ''Last Day of Month''
			when A.DrOptionID=''4'' then ''BillingCycle'' else ''Due Date'' END AS DrOptionID,ACCOUNTTYPES.AccountType AccountTypeID,
			convert(datetime,A.CreatedDate) CreatedDate,A.CreatedBy,convert(datetime,A.ModifiedDate) ModifiedDate,A.ModifiedBy,A.CreditDays,A.CreditLimit,A.DebitDays,A.DebitLimit,A.DebitDays,
			AE.*,C.*'+@CustomQuery3+'
			FROM ACC_Accounts A with(nolock) 
			LEFT JOIN ACC_ACCOUNTS AG WITH(NOLOCK) ON AG.ACCOUNTID=A.PARENTID
			LEFT JOIN COM_STATUS ST WITH(NOLOCK) ON A.StatusID=ST.StatusID
			JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=ST.ResourceID AND PT.LanguageID=1 
			LEFT JOIN COM_Currency CU WITH(NOLOCK) ON A.Currency=CU.CurrencyID
			LEFT JOIN ACC_AccountTypes ACCOUNTTYPES WITH(NOLOCK) ON ACCOUNTTYPES.AccountTypeID=A.AccountTypeID
			LEFT JOIN ACC_ACCOUNTS CO WITH(NOLOCK) ON CO.COGSACCOUNTID=A.ACCOUNTID
			LEFT JOIN ACC_ACCOUNTS CLOSING WITH(NOLOCK) ON A.ClosingStockAccountID=CLOSING.ACCOUNTID
			LEFT JOIN ACC_ACCOUNTS PDC WITH(NOLOCK) ON A.PDCReceivableAccount=PDC.ACCOUNTID
			LEFT JOIN ACC_ACCOUNTS PDCPayable WITH(NOLOCK) ON PDCPayable.ACCOUNTID=A.PDCPayableAccount
			LEFT JOIN ACC_ACCOUNTS PDCDiscount WITH(NOLOCK) ON PDCDiscount.ACCOUNTID=A.PDCDiscountAccount
			LEFT JOIN ACC_ACCOUNTS SalesAccount WITH(NOLOCK) ON SalesAccount.ACCOUNTID=A.SalesAccount
			LEFT JOIN ACC_ACCOUNTS PurchaseAccount WITH(NOLOCK) ON PurchaseAccount.ACCOUNTID=A.PurchaseAccount
			LEFT JOIN ACC_ACCOUNTSEXTENDED AE WITH(NOLOCK) ON AE.ACCOUNTID=A.AccountID
			LEFT JOIN COM_Contacts C WITH(NOLOCK) ON C.FeaturePK='+convert(nvarchar,@DocumentSeqNo)+' AND C.FeatureID=2 AND C.AddressTypeID=1
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.AccountID=CC.NodeID and CC.CostCenterID=2
			'+@ExtJoinQuery+' '+@CustomQuery1+'
			WHERE A.AccountID='+convert(nvarchar,@DocumentSeqNo)
			--Print(@SQL)
			exec(@SQL)
			
		END
		ELSE IF @DocumentID=3
		BEGIN
		  
			set @SQL='	SELECT A.ProductCode,A.ProductName,PT.ResourceData StatusID,A.AliasName,
			PT.ResourceData as ProductType,pTypes.ResourceData ProductTypeID,
			CC2.AccountName as COGSAccountID,CC3.AccountName as ClosingStockAccountID,
			SalesAccount.AccountName as SalesAccountID,PurchaseAccount.AccountName as PurchaseAccountID,VT.ResourceData as ValuationID,
			CC4.UnitName as UOMID,CU.Name CurrencyID,AG.ProductName PARENTID,case when A.IsGroup=''0'' then ''False'' else ''True'' END AS IsGroup,
			CC1.Name as DepartmentID,Category.Name CategoryID, A.[PurchaseRate],A.[SellingRate],A.[ReorderLevel],A.[ReorderQty],A.[ShelfLife],A.[Packing] ,A.[PurchaseRateA],A.[PurchaseRateB]
			,A.[PurchaseRateC],A.[PurchaseRateD],A.[PurchaseRateE],A.[PurchaseRateF],A.[PurchaseRateG],A.[SellingRateA]
			,A.[SellingRateB],A.[SellingRateC],A.[SellingRateD],A.[SellingRateE],A.[SellingRateF],A.[SellingRateG] ,
			convert(datetime,A.CreatedDate) CreatedDate,A.CreatedBy,convert(datetime,A.ModifiedDate) ModifiedDate,A.ModifiedBy,AE.*'+@CustomQuery3+'
			FROM INV_PRODUCT A with(nolock) 
			LEFT JOIN INV_PRODUCT AG WITH(NOLOCK) ON AG.ProductID=A.PARENTID
			LEFT JOIN INV_ProductTypes ProductTypes WITH(NOLOCK) ON ProductTypes.ProductTypeID=A.ProductTypeID
			JOIN COM_LanguageResources pTypes WITH(NOLOCK) ON pTypes.ResourceID=ProductTypes.ResourceID AND pTypes.LanguageID=1 
			LEFT JOIN COM_STATUS ST WITH(NOLOCK) ON A.StatusID=ST.StatusID 
			JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=ST.ResourceID AND PT.LanguageID=1 
			LEFT JOIN INV_ProductExtended AE WITH(NOLOCK) ON AE.ProductID=A.ProductID 
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.ProductID=CC.NodeID and CC.CostCenterID=3
			JOIN INV_ProductTypes PP WITH(NOLOCK) ON A.ProductTypeID=PP.ProductTypeID        
			left  JOIN COM_Department CC1 WITH(NOLOCK) ON A.DepartmentID= CC1.NodeID   
			left  JOIN COM_Category Category WITH(NOLOCK) ON A.CategoryID= Category.NodeID       
			left  JOIN ACC_Accounts CC2 WITH(NOLOCK) ON A.COGSAccountID= CC2.AccountID 
			left  JOIN ACC_Accounts CC3 WITH(NOLOCK) ON A.ClosingStockAccountID= CC3.AccountID 
			left  JOIN ACC_Accounts SalesAccount WITH(NOLOCK) ON A.SalesAccountID= SalesAccount.AccountID 
			left  JOIN ACC_Accounts PurchaseAccount WITH(NOLOCK) ON A.PurchaseAccountID= PurchaseAccount.AccountID 
			JOIN INV_ValuationMethods VV WITH(NOLOCK) ON A.ValuationID=VV.ValuationID            
			JOIN COM_LanguageResources VT WITH(NOLOCK) ON VT.ResourceID=VV.ResourceID AND VT.LanguageID=1 
			left  JOIN COM_UOM CC4 WITH(NOLOCK) ON A.UOMID= CC4.UOMID
			LEFT JOIN COM_Currency CU WITH(NOLOCK) ON A.CurrencyID=CU.CurrencyID
			'+@CustomQuery1+'
			WHERE A.ProductID='+convert(nvarchar,@DocumentSeqNo)
			Print(@SQL)
			exec(@SQL)
			
		END
		ELSE IF @DocumentID=50051
		BEGIN
			DECLARE @EMPID INT

			if(@IsFSDoc=1)
			begin
				set @SQL='SELECT @EMPID=CC.dcCCNID51 FROM INV_DocDetails I WITH(NOLOCK)
						JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.InvDocDetailsID=I.InvDocDetailsID
						WHERE I.CostCenterID=40095 AND DOCID='+convert(nvarchar,@DocumentSeqNo)

						EXEC sp_executesql @SQL,N'@EMPID INT OUTPUT',@EMPID OUTPUT
			end
			ELSE
			BEGIN
				SET @EMPID=@DocumentSeqNo
			END

			-- 0 GETTING EMPLOYEE MASTER DETAILS
			
			SELECT @TABLENAME=TABLENAME FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID=@DocumentID
			set @SQL=' SELECT '+@ExtSelectQuery+'AG.Name PARENTID,ST.Status StatusID,convert(datetime,A.CreatedDate) CreatedDate,convert(datetime,A.ModifiedDate) ModifiedDate,
			CONVERT(DATETIME,A.DOB) DOB,CONVERT(DATETIME,A.DOJ) DOJ,CONVERT(DATETIME,A.DOConfirmation) DOConfirmation,CONVERT(DATETIME,A.NextAppraisalDate) NextAppraisalDate,
			CONVERT(DATETIME,A.PassportIssDate) PassportIssDate, CONVERT(DATETIME,A.PassportExpDate) PassportExpDate,CONVERT(DATETIME,A.VisaIssDate) VisaIssDate,
			CONVERT(DATETIME,A.VisaExpDate) VisaExpDate,CONVERT(DATETIME,A.IqamaIssDate) IqamaIssDate,CONVERT(DATETIME,A.IqamaExpDate) IqamaExpDate,CONVERT(DATETIME,A.ContractIssDate) ContractIssDate,
			CONVERT(DATETIME,A.ContractExpDate) ContractExpDate,CONVERT(DATETIME,A.ContractExtendDate) ContractExtendDate,CONVERT(DATETIME,A.IDIssDate) IDIssDate,
			CONVERT(DATETIME,A.IDExpDate) IDExpDate,CONVERT(DATETIME,A.LicenseIssDate) LicenseIssDate,CONVERT(DATETIME,A.LicenseExpDate) LicenseExpDate,CONVERT(DATETIME,A.MedicalIssDate) MedicalIssDate,
			CONVERT(DATETIME,A.MedicalExpDate) MedicalExpDate,CONVERT(DATETIME,A.OpLeavesAsOn) OpLeavesAsOn,CONVERT(DATETIME,A.OpLOPAsOn) OpLOPAsOn,
			CONVERT(DATETIME,A.DOResign) ResignedDate,CONVERT(DATETIME,A.DORelieve) RelievingDate,CONVERT(DATETIME,A.DOTentRelieve) TentativeRelieingDate,
			RM.Code as ReportingManagerCode,RM.Name as ReportingManagerName,
			BK.Code as BankDefCode,BK.Name as BankDefName,BK.ccAlpha1 as BankDefBankName,BK.ccAlpha3 as BankDefBranchCode,BK.ccAlpha2 as BankDefBranchName,BK.ccAlpha4 as BankDefBranchAddress,
			BK.ccAlpha5 as BankDefIFSCCode,BK.ccAlpha6 as BankDefMICRCode,BK.ccAlpha7 as BankDefBankAgentCode,BK.ccAlpha8 as BankDefBankRoutingCode,
			L104.AliasName as EmployeeTypeAlias,L108.AliasName as NationalityAlias,L114.AliasName as ReligionAlias,
			(datediff(day,CONVERT(DATETIME,A.DOJ),GETDATE())+1) as ServiceDays,
			A.*,C.*
			FROM '+@TABLENAME+' A with(nolock) 	
			LEFT JOIN '+@TABLENAME+' AG WITH(NOLOCK) ON AG.NODEID=A.PARENTID		 
			LEFT JOIN COM_CC50051 RM WITH(NOLOCK) ON RM.NodeID=A.RptManager
			LEFT JOIN COM_CC50068 BK WITH(NOLOCK) ON BK.NodeID=A.iBank
			LEFT JOIN COM_Contacts C WITH(NOLOCK) ON C.FeaturePK='+convert(nvarchar,@EMPID)+' AND C.FeatureID='+CONVERT(NVARCHAR,@DocumentID)+' AND C.AddressTypeID=1
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.NODEID=CC.NodeID and CC.CostCenterID='+CONVERT(NVARCHAR,@DocumentID)+'
			LEFT JOIN COM_STATUS ST WITH(NOLOCK) ON A.StatusID=ST.StatusID
			LEFT JOIN COM_LOOKUP L104 WITH(NOLOCK) on A.EmpType=L104.NodeID
			LEFT JOIN COM_LOOKUP L108 WITH(NOLOCK) on A.Nationality=L108.NodeID
			LEFT JOIN COM_LOOKUP L114 WITH(NOLOCK) on A.Religion=L114.NodeID
		 
			'+@ExtJoinQuery+'
			WHERE A.NODEID='+convert(nvarchar,@EMPID)
			--select @SQL
			--Print(@SQL)
			exec(@SQL)
			
			-- 1 GETTING QUALIFICATIONS DETAILS
			set @SQL='SELECT Field1 as Year,b.Name as Domain,b1.Name as Qualification,b2.Name as QualificationLevel, Field5 as Institute,
			Field6 as University, Field7 as Duration, Field8 as GradeOrPercentage, Field9 as Remarks
			FROM PAY_EmpDetail a WITH(NOLOCK) 
			LEFT JOIN COM_LookUp b WITH(NOLOCK) on b.NodeID=a.Field2
			LEFT JOIN COM_LookUp b1 WITH(NOLOCK) on b1.NodeID=a.Field3
			LEFT JOIN COM_LookUp b2 WITH(NOLOCK) on b2.NodeID=a.Field4
			WHERE a.DType=251 AND a.EmployeeID='+convert(nvarchar,@EMPID)
			
			exec(@SQL)
			
			-- 2 GETTING CERTIFICATIONS DETAILS
			set @SQL='SELECT Field1 as CertificationDate,Field2 as ValidTill,b.Name as Domain,b1.Name as Certification, Field5 as Institute,
			Field6 as GradeOrPercentage, Field7 as Remarks
			FROM PAY_EmpDetail a WITH(NOLOCK) 
			LEFT JOIN COM_LookUp b WITH(NOLOCK) on b.NodeID=a.Field3
			LEFT JOIN COM_LookUp b1 WITH(NOLOCK) on b1.NodeID=a.Field4
			WHERE a.DType=252 AND a.EmployeeID='+convert(nvarchar,@EMPID)
			exec(@SQL)
			
			-- 3 GETTING PREVIOUS EMPLOYMENT DETAILS
			set @SQL='SELECT Field1 as FromDate,Field2 as ToDate,Field3 as Company,Field4 as CompanyDetails, Field5 as Location,
			Field6 as Department, Field7 as Designation, Field8 as Grade, Field9 as ReferenceNo, Field10 as ReferenceName, Field11 as Remarks,Field12 as LeavingReason
			FROM PAY_EmpDetail a WITH(NOLOCK) 
			WHERE a.DType=253 AND a.EmployeeID='+convert(nvarchar,@EMPID)
			exec(@SQL)
			
			-- 4 GETTING MEDICAL HISTORY DETAILS
			set @SQL='SELECT Field1 as MedicalTest,Field2 as ValidTill,Field3 as Result,Field4 as Remarks
			FROM PAY_EmpDetail a WITH(NOLOCK) 
			WHERE a.DType=254 AND a.EmployeeID='+convert(nvarchar,@EMPID)
			exec(@SQL)

			-- 5 GETTING DEPENDENT INFO DETAILS
			set @SQL='SELECT Field1 as Name,Field2 as DateOfBirth,Field3 as Age,Field4 as Sex,b.Name as Relation,
			Field6 as PassportNo, Field7 as PassportIssDate, Field8 as PassportExpDate, 
			Field9 as VisaNo, Field10 as VisaIssDate, Field11 as VisaExpDate, 
			Field12 as MedicalNo, Field13 as MedicalIssDate, Field14 as MedicalExpDate, b1.Name as Nationality, Field16 as Insurance			
			FROM PAY_EmpDetail a WITH(NOLOCK) 
			LEFT JOIN COM_LookUp b WITH(NOLOCK) on b.NodeID=a.Field5
			LEFT JOIN COM_LookUp b1 WITH(NOLOCK) on b1.NodeID=a.Field15
			WHERE a.DType=255 AND a.EmployeeID='+convert(nvarchar,@EMPID)
			exec(@SQL)

			-- 6 GETTING MONTHLY PAYROLL DETAILS

			DECLARE @mpDocID INT
			set @SQL='select top 1 @mpDocID=DocID from INV_DocDetails D with(nolock) 
			join COM_DocCCDATA DCC with(nolock) on D.InvDocDetailsID=DCC.InvDocDetailsID
			join COM_DocTextDATA TXT with(nolock) on D.InvDocDetailsID=TXT.InvDocDetailsID
			where CostCenterID=40054 and DCC.dcCCNID51='+convert(nvarchar,@EMPID)+' and D.DueDate<=GETDATE()
			order by D.DueDate DESC'
			EXEC sp_executesql @SQL,N'@mpDocID INT OUTPUT',@mpDocID OUTPUT
			
			IF(@mpDocID IS NULL)
				SET @mpDocID=0

			set @SQL='SELECT D.VoucherType,N.*,convert(float,T.dcAlpha1) BasicMonthly,convert(float,T.dcAlpha3) NetSalary,T.*
			FROM INV_DocDetails D WITH(NOLOCK) LEFT JOIN
			INV_DocDetails LD WITH(NOLOCK) ON LD.InvDocDetailsID=D.LinkedInvDocDetailsID LEFT JOIN
			COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=D.InvDocDetailsID LEFT JOIN
			PAY_DocNumData N WITH(NOLOCK) ON N.InvDocDetailsID=D.InvDocDetailsID LEFT JOIN
			COM_Currency C WITH(NOLOCK) ON C.CurrencyID=D.CurrencyID LEFT JOIN
			COM_Status S WITH(NOLOCK) ON S.StatusID=D.StatusID 
			where D.CostCenterID=40054 and D.DocID='+convert(nvarchar,@mpDocID)
			EXEC(@SQL)
		
			-- 7 GETTING APPRAISALS DETAILS
			set @SQL='
			declare @EffectFrom float
			SELECT top 1 @EffectFrom=EffectFrom FROM PAY_EmpPay WITH(NOLOCK)
			where EmployeeID='+convert(nvarchar,@EMPID)+' and EffectFrom<=GETDATE()
			order by EffectFrom desc
			
			SELECT *,0.0 EmptyData FROM PAY_EmpPay D WITH(NOLOCK)
			where D.EmployeeID='+convert(nvarchar,@EMPID)+' and EffectFrom=@EffectFrom '
			EXEC(@SQL)
			
			-- 8 GETTING FINAL SETTLEMENT DETAILS FROM DOCUMENT
			set @SQL='
			SELECT '+@ExtFSQuery+' EMP.Code as EmpCode,EMP.Name as EmpName,CONVERT(DATETIME,a.DocDate) as cDocDate,CONVERT(DATETIME,a.CreatedDate) cCreatedDate,CONVERT(DATETIME,a.ModifiedDate) cModifiedDate,*
			FROM INV_DocDetails a WITH(NOLOCK) 
			JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocNumData c WITH(NOLOCK) ON c.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
			JOIN COM_CC50051 EMP WITH(NOLOCK) on EMP.NodeID=b.dcCCNID51
			WHERE a.CostCenterID=40095 '

			IF(@IsFSDoc=1)
				SET @SQL=@SQL+' and DOCID='+convert(nvarchar,@DocumentSeqNo)
			ELSE
				SET @SQL=@SQL+' and b.dcCCNID51='+convert(nvarchar,@EMPID)
			
			EXEC(@SQL)


			-- 9 GETTING ALL APPRAISALS
			set @SQL='
			SELECT D.*,CONVERT(DATETIME,EffectFrom) as cEffectFrom,CONVERT(DATETIME,ApplyFrom) as cApplyFrom,
			ISNULL(L.Name,'''') as cAppraisalType,0.0 EmptyData 
			FROM PAY_EmpPay D WITH(NOLOCK) 
			LEFT JOIN COM_Lookup L WITH(NOLOCK) ON L.NodeID=D.AppraisalType
			WHERE D.EmployeeID='+convert(nvarchar,@EMPID) +' ORDER BY EffectFrom DESC '
			EXEC(@SQL)

			--10 NoticePay
			set @SQL='SELECT D.VoucherType,N.*,convert(float,T.dcAlpha1) BasicMonthly,convert(float,T.dcAlpha3) NetSalary,T.*
			FROM INV_DocDetails D WITH(NOLOCK) LEFT JOIN
			INV_DocDetails LD WITH(NOLOCK) ON LD.InvDocDetailsID=D.LinkedInvDocDetailsID LEFT JOIN
			COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=D.InvDocDetailsID LEFT JOIN
			COM_DocCCDATA CC WITH(NOLOCK) ON CC.InvDocDetailsID=D.InvDocDetailsID LEFT JOIN
			PAY_DocNumData N WITH(NOLOCK) ON N.InvDocDetailsID=D.InvDocDetailsID
			WHERE D.CostCenterID=40054 and D.StatusID=369 AND CC.dcCCNID51='+convert(nvarchar,@EMPID) +'
			AND ISNULL(T.dcAlpha23,'''')=''NoticePay'''
			EXEC(@SQL)

			--11 UnProcessed Salary
			set @SQL='SELECT D.VoucherType,N.*,convert(float,T.dcAlpha1) BasicMonthly,convert(float,T.dcAlpha3) NetSalary,T.*
			FROM INV_DocDetails D WITH(NOLOCK) LEFT JOIN
			INV_DocDetails LD WITH(NOLOCK) ON LD.InvDocDetailsID=D.LinkedInvDocDetailsID LEFT JOIN
			COM_DocTextData T WITH(NOLOCK) ON T.InvDocDetailsID=D.InvDocDetailsID LEFT JOIN
			COM_DocCCDATA CC WITH(NOLOCK) ON CC.InvDocDetailsID=D.InvDocDetailsID LEFT JOIN
			PAY_DocNumData N WITH(NOLOCK) ON N.InvDocDetailsID=D.InvDocDetailsID
			WHERE D.CostCenterID=40054 and D.StatusID=369 AND CC.dcCCNID51='+convert(nvarchar,@EMPID) +'
			AND ISNULL(T.dcAlpha23,'''')=''UnProcessed'''
			EXEC(@SQL)
					
		END
		ELSE IF @DocumentID>50000
		BEGIN		
			SELECT @TABLENAME=TABLENAME FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID=@DocumentID
			IF @TABLENAME<>''
			BEGIN
				declare @ExtraQry nvarchar(max)
				set @ExtraQry=''
				if exists (select Name,value from com_costcenterpreferences with(nolock) 
				where CostCenterID=76 and Name='JobDimension' and Value=convert(nvarchar,@DocumentID))
				begin
					declare @StageTbl nvarchar(max),@SQLBOM nvarchar(max),@BOMName nvarchar(max),@StageName nvarchar(max),@FP nvarchar(max)
					select @StageTbl=VALUE from COM_CostCenterPreferences with(nolock) where [Name]='StageDimension' and CostCenterID=76
					select @StageTbl=TableName from adm_Features with(nolock) where FeatureID=@StageTbl
					
					set @SQLBOM='
					select @BOMName=B.BomName,@FP=P.ProductName,@StageName=S.Name from PRD_JobOuputProducts JO with(nolock)
					inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
					inner join INV_Product P with(nolock) on JO.ProductID=P.ProductID 
					inner join PRD_BOMStages BS with(nolock) on JO.StageID=BS.StageID 
					inner join '+@StageTbl+' S with(nolock) on BS.StageNodeID=S.NodeID 
					where JO.NodeID='+convert(nvarchar,@DocumentSeqNo)

					set @StageTbl=N'@BOMName nvarchar(max) OUTPUT,@StageName nvarchar(max) OUTPUT,@FP nvarchar(max) OUTPUT'
					EXEC sp_executesql @SQLBOM,@StageTbl,@BOMName OUTPUT,@StageName OUTPUT,@FP OUTPUT--,@DUPNODENO OUTPUT ,@Code 
					set @ExtraQry=','''+isnull(@BOMName,'')+''' BOMName'
					set @ExtraQry=@ExtraQry+','''+isnull(@StageName,'')+''' StageName'
					set @ExtraQry=@ExtraQry+','''+isnull(@FP,'')+''' FinishedProduct'
				end
				
				SET @SQL=''
				SELECT @SQL=@SQL+',A.'+a.name
				FROM sys.columns a
				WHERE a.object_id= object_id(@TABLENAME) and (a.name LIKE 'ccAlpha%' or a.name in ('UserNameAlpha','PasswordAlpha'))
					
				set @SQL=' SELECT '+@ExtSelectQuery+'A.Code,A.Name,A.AliasName,A.CreditDays,A.CreditLimit,A.DebitDays,A.DebitLimit,
				case when A.IsGroup=''0'' then ''False'' else ''True'' END AS IsGroup,SalesAccount.AccountName SalesAccount 
	,PurchaseAccount.AccountName PurchaseAccount,PT.ResourceData StatusID,AG.Name PARENTID, 
	convert(datetime,A.CreatedDate) CreatedDate,A.CreatedBy,convert(datetime,A.ModifiedDate) ModifiedDate,A.ModifiedBy,C.*'
	+@CustomQuery3+@ExtraQry+@SQL+'
				FROM '+@TABLENAME+' A with(nolock) 	
				LEFT JOIN '+@TABLENAME+' AG WITH(NOLOCK) ON AG.NODEID=A.PARENTID		 
				LEFT JOIN COM_Contacts C WITH(NOLOCK) ON C.FeaturePK='+convert(nvarchar,@DocumentSeqNo)+' AND C.FeatureID='+CONVERT(NVARCHAR,@DocumentID)+' AND C.AddressTypeID=1
				LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.NODEID=CC.NodeID and CC.CostCenterID='+CONVERT(NVARCHAR,@DocumentID)+'
				LEFT JOIN COM_STATUS ST WITH(NOLOCK) ON A.StatusID=ST.StatusID 
				 JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=ST.ResourceID AND PT.LanguageID=1 
				LEFT JOIN ACC_ACCOUNTS SalesAccount WITH(NOLOCK) ON SalesAccount.ACCOUNTID=A.SalesAccount
				LEFT JOIN ACC_ACCOUNTS PurchaseAccount WITH(NOLOCK) ON PurchaseAccount.ACCOUNTID=A.PurchaseAccount
				'+@ExtJoinQuery+@CustomQuery1+'
				WHERE A.NODEID='+convert(nvarchar,@DocumentSeqNo)
				--Print(@SQL)
				exec(@SQL)
				
				if exists (select Name,value from com_costcenterpreferences with(nolock) 
				where CostCenterID=76 and Name='JobDimension' and Value=convert(nvarchar,@DocumentID))
				begin
					set @SQLBOM='select B.BOMCode,B.BOMName,P.ProductCode,P.ProductName,S.Code StageCode,S.Name StageName,JO.Qty Size
,case when JO.IsBom=1 then ''BOM'' else ''QTY'' end Unit
,U.UnitName UOM,JO.Remarks,ST.Status
from PRD_JobOuputProducts JO with(nolock)
inner join PRD_BillOfMaterial B with(nolock) on JO.BOMID=B.BOMID
inner join INV_Product P with(nolock) on JO.ProductID=P.ProductID 
inner join PRD_BOMStages BS with(nolock) on JO.StageID=BS.StageID 
inner join '+(select F.TableName from COM_CostCenterPreferences P with(nolock) join adm_Features F with(nolock) on F.FeatureID=P.Value where P.[Name]='StageDimension' and isnumeric(P.Value)=1 and P.CostCenterID=76)+' S with(nolock) on BS.StageNodeID=S.NodeID 
left join COM_UOM U with(nolock) on JO.UOMID=U.UOMID
left join COM_Status ST with(nolock) on JO.StatusID=ST.StatusID
where JO.NodeID='+convert(nvarchar,@DocumentSeqNo)
					EXEC(@SQLBOM)
				end
			END
		END
		ELSE IF @DocumentID=89
		BEGIN
			set @SQL='SELECT '+@ExtSelectQuery+'A.Code,A.Subject,convert(datetime,A.Date) as Date,A.Company,O.COMPANY AS [Group],S.STATUS as StatusID,C.Name CampaignID,A.EstimatedRevenue,
			A.CreatedBy,CONVERT(DATETIME,A.CreatedDate) CreatedDate,
			CO.NAME CurrencyID,LD.Company as LeadID,P.Quantity as PRODUCT_Quantity,P.Remarks PRODUCT_Remarks,PRO.ProductName PRODUCT_ProductName,U.BaseName PRODUCT_UOM, convert(datetime,A.ESTIMATEDCLOSEDATE) as EstimatedCloseDate,
			A.ModifiedBy,CONVERT(DATETIME,A.ModifiedDate) ModifiedDate,
			L1.NAME AS ProbabilityLookUpID,L2.NAME AS RatingLookUpID,convert(datetime,A.CloseDate) as CloseDate, L3.NAME AS ReasonLookUpID,L4.Name as Contact'+@CustomQuery3+',EXT.*
			FROM CRM_OPPORTUNITIES A  WITH(NOLOCK)
			lEFT JOIN CRM_OPPORTUNITIES O  WITH(NOLOCK) on A.PARENTID=O.OPPORTUNITYID
			LEFT JOIN CRM_CONTACTS D WITH(NOLOCK) on D.FeatureID=89 AND D.FeaturePK='+convert(nvarchar,@DocumentSeqNo)+'
			lEFT JOIN crm_leads LD  WITH(NOLOCK) on A.leadid=LD.leadid
			LEFT JOIN COM_STATUS S WITH(NOLOCK) on A.StatusID=S.StatusID
			LEFT JOIN CRM_Campaigns C WITH(NOLOCK) on A.CampaignID=C.CampaignID
			LEFT JOIN COM_CURRENCY CO WITH(NOLOCK) on A.CURRENCYID=CO.CURRENCYID
			LEFT JOIN COM_LOOKUP L1 WITH(NOLOCK) on A.ProbabilityLookUpID=L1.NodeID
			LEFT JOIN COM_LOOKUP L2 WITH(NOLOCK) on A.RatingLookUpID=L2.NodeID
			LEFT JOIN COM_LOOKUP L3 WITH(NOLOCK) on A.REASONLookUpID=L3.NodeID
			LEFT JOIN COM_LOOKUP L4 WITH(NOLOCK) on L4.NodeID=53
			LEFT JOIN CRM_ProductMapping P WITH(NOLOCK) on P.CostcenterID=89 AND P.CCNodeID=A.OpportunityID 
			LEFT JOIN INV_Product PRO WITH(NOLOCK) on P.ProductID=PRO.ProductID
			LEFT JOIN COM_UOM U WITH(NOLOCK) on P.UOMID=U.UOMID
			LEFT JOIN CRM_OpportunitiesExtended EXT WITH(NOLOCK) on A.OPPORTUNITYID=EXT.OPPORTUNITYID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.OPPORTUNITYID=CC.NodeID and CC.CostCenterID=89'
			+@ExtJoinQuery+@CustomQuery1+'
			where A.OPPORTUNITYID='+convert(nvarchar,@DocumentSeqNo)
			Print(@SQL)
			exec(@SQL)
			
			
			SET @AlpCols=''
			SELECT @AlpCols=STUFF( (SELECT ','+Name FROM Sys.Columns WITH(NOLOCK) WHERE object_id=OBJECT_ID('CRM_Feedback') AND Name Like 'Alpha%'  FOR XML PATH('') ),1,1,'') 
			
			set @SQL='select NodeID,Convert(Datetime,Date) Date,Convert(Datetime,Date) FILTERDATE,FeedBack'
			IF(LEN(@AlpCols)>0)
				SET @SQL+=','+@AlpCols
			SET @SQL+=' from  CRM_Feedback WITH(NOLOCK) 
			where CCID=89 and CCNodeID='+convert(nvarchar,@DocumentSeqNo)
			exec(@SQL)

			SET @AlpCols=''
			SELECT @AlpCols=STUFF( (SELECT ',A.'+Name FROM Sys.Columns WITH(NOLOCK) WHERE object_id=OBJECT_ID('crm_activities') AND Name Like 'Alpha%'  FOR XML PATH('') ),1,1,'') 

			set @SQL='SELECT A.ActivityID,CASE WHEN ACTIVITYTYPEID=1 THEN ''Appointment Regular'' WHEN ACTIVITYTYPEID=2 THEN ''Task Regular'' WHEN ACTIVITYTYPEID=3 THEN ''Appointment Recurring'' ELSE ''Task Recurring'' END AS ActivityTypeID,
			Com_Status.Status as StatusID,Subject,Case when Priority=0 then ''Low'' when Priority=1 then ''Normal'' else ''High'' End as Priority,PctComplete [Complete%],Location,
			case when IsAllDayActivity=0 then ''No'' else ''Yes'' end IsAllDayActivity,CustomerID,Remarks,Convert(Datetime,StartDate) StartDate,convert(Datetime,EndDate) EndDate,StartTime,EndTime'
			IF(LEN(@AlpCols)>0)
				SET @SQL+=','+@AlpCols
			SET @SQL+=' From crm_activities A with(nolock)
			Left Join Com_Status WITH(NOLOCK) on A.StatusID=Com_Status.StatusID
			where  A.costcenterid=89 and A.nodeid='+convert(nvarchar,@DocumentSeqNo)
			exec(@SQL)
					
			select	NT.Note Notes From COM_Notes NT WITH(NOLOCK) where  NT.FeatureID=89 and NT.FeaturePK=convert(nvarchar,@DocumentSeqNo)
		END
		ELSE IF @DocumentID=73
		BEGIN
			set @SQL='SELECT '+@ExtSelectQuery+'convert(datetime,A.CreateDate) as CreateDate,convert(datetime,A.EstimateDate) as EstimateDate,convert(datetime,A.EstComplDate) as EstComplDate,convert(datetime,A.ActualComplDate) as ActualComplDate,
			A.CreatedBy,CONVERT(DATETIME,A.CreatedDate) CreatedDate,A.Subject,
			A.CaseNumber,S.STATUS as StatusID,L1.NAME AS CaseTypeLookupID,L2.NAME AS CaseOriginLookupID, L3.NAME AS CasePriorityLookupID,O.CaseNumber as ParentID,
			CASE WHEN A.CustomerMode=2 THEN CCU.CustomerName ELSE CU.AccountName end as CustomerID,SV.VOUCHERNO as SvcContractID,PR.ProductName as CaseProductName,convert(datetime,A.CreatedDate) as CreatedDate,
			convert(nvarchar,A.ContractLineID)+''-''+PR.ProductName as ContractLineID,A.SerialNumber,L4.Name as ServiceLvlLookupID,A.ConsumedUnits,L5.Name as BillingMethod,
			A.ModifiedBy,CONVERT(DATETIME,A.ModifiedDate) ModifiedDate,
			A.CreatedBy as AssignedTo,convert(datetime,A.CreateDate) as AssignedDate,A.FeedBack,A.Suggestion,A.Comments,convert(datetime,A.WaiveDate) as WaiveDate'+@CustomQuery3+',
			P.Quantity as PRODUCT_Quantity,P.Remarks PRODUCT_Remarks,PRO.ProductName PRODUCT_ProductName,U.BaseName PRODUCT_UOM,A.CreatedBy as [Owner],EXT.*
			FROM CRM_CASES A  WITH(NOLOCK)
			lEFT JOIN CRM_CASES O  WITH(NOLOCK) on A.PARENTID=O.CaseID
			LEFT JOIN COM_STATUS S WITH(NOLOCK) on A.StatusID=S.StatusID
			LEFT JOIN COM_LOOKUP L1 WITH(NOLOCK) on A.CaseTypeLookupID=L1.NodeID
			LEFT JOIN COM_LOOKUP L2 WITH(NOLOCK) on A.CaseOriginLookupID=L2.NodeID
			LEFT JOIN COM_LOOKUP L3 WITH(NOLOCK) on A.CasePriorityLookupID=L3.NodeID
			LEFT JOIN COM_LOOKUP L4 WITH(NOLOCK) on A.ServiceLvlLookupID=L4.NodeID
			LEFT JOIN COM_LOOKUP L5 WITH(NOLOCK) on A.BillingMethod=L5.NodeID
			LEFT JOIN Acc_Accounts CU WITH(NOLOCK) on A.CustomerID=CU.AccountID
			LEFT JOIN CRM_Customer CCU WITH(NOLOCK) on A.CustomerID=CCU.CustomerID
			LEFT JOIN INV_DOCDETAILS SV WITH(NOLOCK) on A.SvcContractID=SV.DOCID AND SV.DOCUMENTTYPE=35
			LEFT JOIN CRM_ProductMapping P WITH(NOLOCK) on P.CostcenterID=73 AND P.CCNodeID=A.CaseID
			LEFT JOIN INV_Product PR WITH(NOLOCK) on A.ProductID=PR.ProductID
			LEFT JOIN INV_Product PRO WITH(NOLOCK) on P.ProductID=PRO.ProductID
			LEFT JOIN COM_UOM U WITH(NOLOCK) on P.UOMID=U.UOMID
			LEFT JOIN CRM_CasesExtended EXT WITH(NOLOCK) on A.CaseID=EXT.CaseID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on A.CaseID=CC.NodeID and CC.CostCenterID=73'
			+@ExtJoinQuery+@CustomQuery1+'
			where A.CaseID='+convert(nvarchar,@DocumentSeqNo)
			--Print(@SQL)
			EXEC(@SQL)
				

			SET @AlpCols=''
			SELECT @AlpCols=STUFF( (SELECT ','+Name FROM Sys.Columns WITH(NOLOCK) WHERE object_id=OBJECT_ID('CRM_Feedback') AND Name Like 'Alpha%'  FOR XML PATH('') ),1,1,'') 

			set @SQL='select CC.NodeID,Convert(Datetime,Date) Date,Convert(Datetime,Date) FILTERDATE,FeedBack,CC.CreatedBy'
			IF(LEN(@AlpCols)>0)
				SET @SQL+=','+@AlpCols
			SET @SQL+=REPLACE(@CustomQuery3,'_Name','')+'
			from  CRM_Feedback CC WITH(NOLOCK) '+@CustomQuery1+' 
			where CCID=73 and CC.CCNodeID='+convert(nvarchar,@DocumentSeqNo)
			print  @sql
			exec(@SQL)

			SET @AlpCols=''
			SELECT @AlpCols=STUFF( (SELECT ',A.'+Name FROM Sys.Columns WITH(NOLOCK) WHERE object_id=OBJECT_ID('crm_activities') AND Name Like 'Alpha%'  FOR XML PATH('') ),1,1,'') 

			set @SQL='SELECT A.ActivityID,CASE WHEN ACTIVITYTYPEID=1 THEN ''Appointment Regular'' WHEN ACTIVITYTYPEID=2 THEN ''Task Regular'' WHEN ACTIVITYTYPEID=3 THEN ''Appointment Recurring'' ELSE ''Task Recurring'' END AS ActivityTypeID,
			Com_Status.Status as StatusID,Subject,Case when Priority=0 then ''Low'' when Priority=1 then ''Normal'' else ''High'' End as Priority,PctComplete [Complete%],Location,
			case when IsAllDayActivity=0 then ''No'' else ''Yes'' end IsAllDayActivity,CustomerID,Remarks,Convert(Datetime,StartDate) StartDate,convert(Datetime,EndDate) EndDate,StartTime,EndTime'
			IF(LEN(@AlpCols)>0)
				SET @SQL+=','+@AlpCols
			SET @SQL+=' From crm_activities A with(nolock)
			Left Join Com_Status WITH(NOLOCK) on A.StatusID=Com_Status.StatusID
			where  A.costcenterid=73 and A.nodeid='+convert(nvarchar,@DocumentSeqNo)
			exec(@SQL)
					
		    select	NT.Note Notes From COM_Notes NT WITH(NOLOCK) where  NT.FeatureID=73 and NT.FeaturePK=convert(nvarchar,@DocumentSeqNo)
		    
		    --assigned users email address
		    exec spCOM_GetAssignedUserEmailAddress 73,@DocumentSeqNo
		    
			set @SQL='SELECT ST.ServiceName,R.Reason,STM.VoiceOfCustomer,STM.TechinicianComments,
			T.Name Technician FROM dbo.CRM_CaseSvcTypeMap STM WITH(NOLOCK) 
			LEFT JOIN CRM_ServiceTypes ST with(nolock) ON ST.ServiceTypeID=STM.ServiceTypeID 
			LEFT JOIN CRM_ServiceReasons R with(nolock) ON R.ServiceReasonID=STM.ServiceReasonID 
			left join COM_CC50019 t with(nolock) on t.NodeID=STM.Techincian
			where caseid='+convert(nvarchar,@DocumentSeqNo)
			exec(@SQL)
  
  
		END
		ELSE IF @DocumentID=95 OR @DocumentID=103 OR @DocumentID=104 OR @DocumentID=129
		BEGIN
		--select * from REN_Tenant
			declare @Accountant nvarchar(50),@SalesMan nvarchar(50),@LandLord nvarchar(50) ,@UTTableName nvarchar(100),@UnitID nvarchar(10),@PropertyID nvarchar(10),@TenantID nvarchar(10)
			set @Accountant=(select tablename from adm_Features WITH(NOLOCK) where featureid=(select value from com_CostCenterpreferences WITH(NOLOCK) where FeatureID=92 and Name='Accountant'))
			set @SalesMan=(select tablename from adm_Features WITH(NOLOCK) where featureid=(select value from com_CostCenterpreferences WITH(NOLOCK) where FeatureID=92 and Name='Salesman'))
			set @LandLord=(select tablename from adm_Features WITH(NOLOCK) where featureid=(select value from com_CostCenterpreferences WITH(NOLOCK) where FeatureID=92 and Name='Landlord'))
			set @UTTableName=(select tablename from adm_Features WITH(NOLOCK) where featureid=(select value from ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='UnitLinkDimension'))
			if @Accountant is null
				set @Accountant='COM_Location'
			if @SalesMan is null
				set @SalesMan='COM_Location'
			if @LandLord is null
				set @LandLord='COM_Location'
			declare @PK nvarchar(20),@EXTPK nvarchar(20),@SELECT nvarchar(max),@TblName1 nvarchar(30),@TblName2 nvarchar(30),@TblName3 nvarchar(30),@TblName4 nvarchar(30)
			declare @j nvarchar(50),@SecurityDeposit FLOAT,@dimCid int,@dtable nvarchar(100)
			set @j=(select tablename from adm_Features WITH(NOLOCK) where featureid=(select value from adm_globalpreferences with(nolock) where Name='DepositLinkDimension'))
			set @dimCid=0
			set @dtable=''

			if @DocumentID=95
			BEGIN
				select @dimCid=Value from COM_CostCenterPreferences WITH(NOLOCK)
				where Name='DimensionWiseContract' and costcenterid=95 and Value is not null and Value<>'' and ISNUMERIC(value)=1
			END

			if @DocumentID=103 OR @DocumentID=129
			begin
				set @PK='QuotationID'
				set @EXTPK='QuotationID'
				set @TblName1='REN_Quotation'
				set @TblName2='REN_QuotationExtended'
				set @TblName3='REN_QuotationParticulars'
				set @TblName4='REN_QuotationPayTerms'
				set @SELECT='convert(Datetime,L.Date) Date,graceperiod,L.Prefix,L.Number,CONVERT(DATETIME, ExtendTill) AS ExtendTill,case when L.MultiName is null or L.MultiName='''' then U.Name else L.MultiName end MultiName,'
				SET @SQL='select @UnitID=UnitID,@PropertyID=PropertyID,@TenantID=TenantID from REN_Quotation with(nolock) where QuotationID='+CONVERT(NVARCHAR,@DocumentSeqNo)
				EXEC sp_executesql @SQL,N'@UnitID INT OUTPUT,@PropertyID INT OUTPUT,@TenantID INT OUTPUT',@UnitID OUTPUT,@PropertyID OUTPUT,@TenantID OUTPUT
			end
			else
			begin
				IF @DocumentID=95
				BEGIN
				set @sContractCols=',TenanctRecvBalance,TenanctRecvBalInclPDC ';

					SET @SQL='DECLARE @RenewRefID INT=@DocumentSeqNo,@i INT=1 
					WHILE (@i=1)
					BEGIN
						IF EXISTS (SELECT RC.RenewRefID FROM REN_Contract RC WITH(NOLOCK)
						WHERE RC.ContractID=@RenewRefID AND RC.RenewRefID IS NOT NULL AND RC.RenewRefID<>0)
						BEGIN
							SELECT @RenewRefID=RC.RenewRefID FROM REN_Contract RC WITH(NOLOCK)
							WHERE RC.ContractID=@RenewRefID AND RC.RenewRefID IS NOT NULL AND RC.RenewRefID<>0
						END
						ELSE
							SET @i=2
					END


					SELECT @SecurityDeposit=L.Amount FROM REN_ContractParticulars L WITH(NOLOCK) 
					JOIN '+@j+' CC WITH(NOLOCK) ON L.CCNodeID=CC.NodeID
					WHERE ContractID=@RenewRefID AND CC.Name Like ''Sec%Dep%''
					
					if @SecurityDeposit is null
						set @SecurityDeposit=0
					'

					EXEC sp_executesql @SQL,N'@DocumentSeqNo INT,@SecurityDeposit FLOAT  OUTPUT',@DocumentSeqNo,@SecurityDeposit OUTPUT
				END
				
				if @SecurityDeposit is null
					set @SecurityDeposit=0

				set @SELECT='convert(Datetime,L.ContractDate) ContractDate,graceperiod,L.ContractNumber,convert(Datetime,L.VacancyDate) VacancyDate,convert(Datetime,L.TerminationDate) TerminationDate, CONVERT(DATETIME, ExtendTill) AS ExtendTill,
				L.SRTAmount,L.RefundAmt,L.PDCRefund,L.Penalty,L.Amt,case when L.TerminationDate is not null then (L.TerminationDate-L.StartDate)+1 else 0 end RentDaysTillTerminate,L.RentAmt,L.InputVAT,L.OutputVAT,
				 (select AccountName from acc_accounts with(nolock) where AccountID=L.TermPayMode) TermPayMode,L.TermChequeNo,convert(datetime,L.TermChequeDate) TermChequeDate,L.TermRemarks,convert(Datetime,L.RefundDate) RefundDate,CASE WHEN L.RefundAmt IS NOT NULL AND L.RefundAmt<>0 THEN L.RefundAmt ELSE '+CONVERT(NVARCHAR,@SecurityDeposit)+' END SecurityDeposit,L.SecurityDeposit ExcessDaysAmt,L.AgeOfRenewal,'
				set @PK='CONTRACTID'
				set @EXTPK='NodeID'
				set @TblName1='REN_CONTRACT'
				set @TblName2='REN_ContractExtended'
				set @TblName3='REN_ContractParticulars'
				set @TblName4='REN_ContractPayTerms'
				
				SET @SQL='select @UnitID=UnitID,@PropertyID=PropertyID,@TenantID=TenantID from REN_Contract with(nolock) where ContractID='+CONVERT(NVARCHAR,@DocumentSeqNo)
				EXEC sp_executesql @SQL,N'@UnitID INT OUTPUT,@PropertyID INT OUTPUT,@TenantID INT OUTPUT',@UnitID OUTPUT,@PropertyID OUTPUT,@TenantID OUTPUT
				
			end
			
			Declare @ExtQuery nvarchar(max),@ExtJoin nvarchar(max),@SysColumnName nvarchar(max),@Exti int ,@ExtCNT int,@ExtCCID int
			,@ExtTab nvarchar(50),@ExtTabRef nvarchar(6),@PrimaryKey nvarchar(32)
			create table #ExtendedTable(ID int identity(1,1),SysColumnName nvarchar(max),CostCenterID int)
			
			truncate table #ExtendedTable
			set @ExtQuery=''
			set @ExtJoin=''
					
			insert into #ExtendedTable(SysColumnName,CostCenterID)
			select SysColumnName,ColumnCostCenterID from adm_CostCenterDef WITH(NOLOCK) 
			where CostCenterID=@DocumentID and SystableName=@TblName2 and IsColumnInUse=1

			select @Exti=1,@ExtCNT=count(id) from #ExtendedTable

			while (@Exti<=	@ExtCNT)
			begin
				select @SysColumnName=SysColumnName,@ExtCCID=isnull(CostCenterID,0) from #ExtendedTable where ID=@Exti
				
				if(@ExtCCID is not null and @ExtCCID<>'' and @ExtCCID>0)	
				begin
					select @ExtTab=TableName,@PrimaryKey=PrimaryKey from adm_features WITH(NOLOCK) where FeatureID = @ExtCCID
					set @ExtTabRef='EXT'+CONVERT(nvarchar,@Exti)
					
					set @ExtQuery=@ExtQuery+','+@ExtTabRef+'.'+CASE WHEN @ExtCCID=2 THEN 'AccountName ' WHEN @ExtCCID=3 THEN 'ProductName ' ELSE 'Name ' END+@SysColumnName
					set @ExtJoin=@ExtJoin+' left join '+@ExtTab+' '+@ExtTabRef+' WITH(NOLOCK) on '+@ExtTabRef+'.'+@PrimaryKey+'=EXT.'+@SysColumnName

				end
				else
				begin
					set @ExtQuery=@ExtQuery+',EXT.'+@SysColumnName
				end
				set @Exti=@Exti+1
			end
			
			if @DocumentID=95
			begin
				set @ExtTab=(select tablename from adm_Features WITH(NOLOCK) where featureid=(select value from adm_globalpreferences with(nolock) where Name='TerminationReason'))
				if(@ExtTab is not null and @ExtTab<>'')
				begin
					set @SELECT=@SELECT+'TR.Name TermReason,'
					set @ExtJoin=@ExtJoin +' LEFT JOIN '+@ExtTab+' TR WITH(NOLOCK) ON TR.Nodeid=L.Reason '
				end
			END	
			
			set @SQL='select '+@ExtSelectQuery+@SELECT+'S.StatusID iStatusID,S.Status as StatusID,P.Name AS PropertyID,U.Name AS UNITID,L.CreatedBy,CONVERT(DATETIME,L.CreatedDate) CreatedDate,
				T.TenantCode AS TenantID,A.AccountName AS RentAccID,ACC.AccountName AS IncomeAccID,L.PURPOSE,
				L3.Name RentTypeID,L.SNO,L.Narration,L.NoOfUnits,
				CASE WHEN (CASE WHEN DATEPART(DAY,L.StartDate)>DATEPART(DAY,(L.EndDate+1)) THEN DATEDIFF(MONTH,L.StartDate,(L.EndDate+1))-1
				ELSE DATEDIFF(MONTH,L.StartDate,(L.EndDate+1)) END/12)=0 THEN '''' ELSE CONVERT(VARCHAR,(CASE WHEN DATEPART(DAY,L.StartDate)>DATEPART(DAY,(L.EndDate+1)) THEN DATEDIFF(MONTH,L.StartDate,(L.EndDate+1))-1
				ELSE DATEDIFF(MONTH,L.StartDate,(L.EndDate+1)) END/12))+'' Years '' END+
				CASE WHEN (CASE WHEN DATEPART(DAY,L.StartDate)>DATEPART(DAY,(L.EndDate+1)) THEN DATEDIFF(MONTH,L.StartDate,(L.EndDate+1))-1
				ELSE DATEDIFF(MONTH,L.StartDate,(L.EndDate+1)) END%12)=0 THEN '''' ELSE CONVERT(VARCHAR,(CASE WHEN DATEPART(DAY,L.StartDate)>DATEPART(DAY,(L.EndDate+1)) THEN DATEDIFF(MONTH,L.StartDate,(L.EndDate+1))-1
				ELSE DATEDIFF(MONTH,L.StartDate,(L.EndDate+1)) END%12))+'' Months '' END+
				CASE WHEN (DATEDIFF(DAY,DATEADD(MM,(CASE WHEN DATEPART(DAY,L.StartDate)>DATEPART(DAY,(L.EndDate+1)) THEN DATEDIFF(MONTH,L.StartDate,(L.EndDate+1))-1
				ELSE DATEDIFF(MONTH,L.StartDate,(L.EndDate+1)) END%12),(DATEADD(YY,(CASE WHEN DATEPART(DAY,L.StartDate)>DATEPART(DAY,(L.EndDate+1)) THEN DATEDIFF(MONTH,L.StartDate,(L.EndDate+1))-1
				ELSE DATEDIFF(MONTH,L.StartDate,(L.EndDate+1)) END/12),L.StartDate))),(L.EndDate+1)))=0 THEN '''' ELSE CONVERT(VARCHAR,(DATEDIFF(DAY,DATEADD(MM,(CASE WHEN DATEPART(DAY,L.StartDate)>DATEPART(DAY,(L.EndDate+1)) THEN DATEDIFF(MONTH,L.StartDate,(L.EndDate+1))-1
				ELSE DATEDIFF(MONTH,L.StartDate,(L.EndDate+1)) END%12),(DATEADD(YY,(CASE WHEN DATEPART(DAY,L.StartDate)>DATEPART(DAY,(L.EndDate+1)) THEN DATEDIFF(MONTH,L.StartDate,(L.EndDate+1))-1
				ELSE DATEDIFF(MONTH,L.StartDate,(L.EndDate+1)) END/12),L.StartDate))),(L.EndDate+1))))+'' Days'' END AS RentDuration,
				convert(Datetime,L.StartDate) StartDate,convert(Datetime,L.EndDate) EndDate,L.TotalAmount,L.NonRecurAmount,L.RecurAmount,L.WorkflowID,L.WorkflowLevel,
				L.ModifiedBy,CONVERT(DATETIME,L.ModifiedDate) ModifiedDate
				--,datediff(year,convert(Datetime,L.StartDate),dateadd(day,1,convert(Datetime,L.EndDate))) TotalYears
				,datediff(year,convert(Datetime,L.StartDate),dateadd(day,1,convert(Datetime,L.EndDate)))-case when DATEADD(Year,datediff(year,convert(Datetime,L.StartDate),dateadd(day,1,convert(Datetime,L.EndDate))),convert(Datetime,L.StartDate))>dateadd(day,1,convert(Datetime,L.EndDate)) then 1 else 0 end TotalYears
				,L1.Name FloorLookUpID,L2.Name ViewLookUpID,L.TotalAmount Amount
				,isnull((select RentAmount from '+@TblName3+' with(nolock) where '+@PK+'=L.'+@PK+' and Sno=1),0) RentAmount
				,isnull((select Discount from '+@TblName3+' with(nolock) where '+@PK+'=L.'+@PK+' and Sno=1),0) DiscountAmount
				,isnull((select Amount from '+@TblName3+' with(nolock) where '+@PK+'=L.'+@PK+' and Sno=1),0) AfterDiscount
				,L.TotalAmount-isnull((select Discount from '+@TblName3+' with(nolock) where '+@PK+'=L.'+@PK+' and Sno=1),0) NetAmount
				,L.TermsConditions
				--,DATEDIFF(day,CONVERT(Datetime,L.StartDate),CONVERT(Datetime,L.EndDate))/30 Months
				,DATEDIFF(MONTH,L.StartDate,L.EndDate+1) Months
				,DATEDIFF(Day,L.StartDate,L.EndDate)+1 TotalDays
				,SalesMan.Name SalesmanID,LLORD.NAME AS LANDLORDID'+@CustomQuery3+@ExtQuery+'
				,CASE WHEN isnumeric(U.RentableArea)=0 or convert(float,U.RentableArea)=0.0 THEN isnull((select RentAmount from '+@TblName3+' with(nolock) where '+@PK+'=L.'+@PK+' and Sno=1),0.0) ELSE (isnull((select RentAmount from '+@TblName3+' with(nolock) where '+@PK+'=L.'+@PK+' and Sno=1),0.0)/U.RentableArea) END RatePerArea
				,(select sqft from '+@TblName3+' with(nolock) where '+@PK+'=L.'+@PK+' and Sno=1) sqft,RecurDuration '
				
				IF (@DocumentID=95 OR @DocumentID=104)
					set @SQL=@SQL+',ProposedRent,ProposedDisc,ProposedAfterDisc,ProposedDailyRent,ProposedDiscPer,Variance,PendFinalSettl,FinalSettlXML '

				set @SQL=@SQL+@sContractCols+'
				from '+@TblName1+' L WITH(NOLOCK)
				LEFT JOIN '+@TblName2+' EXT WITH(NOLOCK) ON L.'+@PK+'=EXT.'+@EXTPK+'
				LEFT JOIN COM_STATUS S WITH(NOLOCK) ON L.STATUSID=S.STATUSID
				LEFT JOIN REN_Property P WITH(NOLOCK) ON L.PropertyID=P.NodeID
				LEFT JOIN REN_Units U WITH(NOLOCK) ON L.UnitID=U.UnitID 
			    LEFT JOIN COM_LOOKUP L1 WITH(NOLOCK) on U.FloorLookupID=L1.NodeID
			    LEFT JOIN COM_LOOKUP L2 WITH(NOLOCK) on U.ViewLookupID=L2.NodeID
			    LEFT JOIN COM_LOOKUP L3 WITH(NOLOCK) on U.RentTypeID=L3.NodeID
				LEFT JOIN REN_Tenant T WITH(NOLOCK) ON L.TenantID=T.TenantID
				LEFT JOIN '+@LandLord+' LLORD WITH(NOLOCK) ON L.LANDLORDID=LLORD.NODEID
				LEFT JOIN '+@SalesMan+' SalesMan with(nolock) on SalesMan.NodeID=L.SalesmanID
				LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON L.RentAccID=A.AccountID
				LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON L.IncomeAccID=ACC.AccountID
				LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on L.'+@PK+'=CC.NodeID and CC.CostCenterID='+convert(nvarchar,@DocumentID)
				+@CustomQuery1+@ExtJoinQuery+@ExtJoin+' 
				WHERE L.'+@PK+'='+convert(nvarchar,@DocumentSeqNo)
		 	Print(substring(@SQL,0,4000))
		 	Print(substring(@SQL,4001,4000))
		 	
			EXEC(@SQL)
			
			declare @VatNode nvarchar(50),@VATSQL nvarchar(max),@CCcolnames nvarchar(max),@CCcoljoin nvarchar(max)
			select @VatNode=Value from com_costcenterpreferences with(nolock) where CostCenterID=95 and Name='VatNode'
			if isnumeric(@VatNode)=0
				set @VatNode='-12345'
			set @VATSQL=''
			
			set @CCcolnames=''
			set @CCcoljoin=''
			SELECT @CCcolnames=@CCcolnames+',C'+CONVERT(NVARCHAR,ROW_NUMBER() OVER (ORDER BY[ColumnCostCenterID]))+'.Name '+SYSCOLUMNNAME
			,@CCcoljoin=@CCcoljoin+' LEFT JOIN '+ParentCostCenterSysName+' C'+CONVERT(NVARCHAR,ROW_NUMBER() OVER (ORDER BY[ColumnCostCenterID]))+' WITH(NOLOCK) ON C'+CONVERT(NVARCHAR,ROW_NUMBER() OVER (ORDER BY[ColumnCostCenterID]))+'.NodeID=L.'+SYSCOLUMNNAME	
			FROM ADM_CostCenterDef with(nolock) 
			WHERE COSTCENTERID=@DocumentID and SYSCOLUMNNAME like 'CCNID%'
			and SysTableName=@TblName3
	
			if exists (select FeatureID from ADM_Features with(nolock) where FeatureID=50061)
				set @VATSQL=',(select name from COM_CC50061 with(nolock) where NodeID=L.SPType) SPType'
			set @SQL='if (('+convert(nvarchar,@DocumentID)+'=95 OR '+convert(nvarchar,@DocumentID)+'=104) AND exists (select top(1) CCID from REN_ContractParticulars WITH(NOLOCK) where ContractID='+convert(nvarchar,@DocumentSeqNo)+'))
			OR (('+convert(nvarchar,@DocumentID)+'=103 OR '+convert(nvarchar,@DocumentID)+'=129) AND exists (select top(1) CCID from REN_QuotationParticulars WITH(NOLOCK) where QuotationID='+convert(nvarchar,@DocumentSeqNo)+')) 
			begin
					select L.NodeID ParticularID,L.Amount,L.Narration,A.AccountName AS CreditAccID,ACC.AccountName AS DebitAccID,CC.Name Particulars,L.ChequeNO,convert(Datetime,L.ChequeDate) Date,L.PayeeBank
					,case when L.VatPer>0 then convert(nvarchar,L.VatPer) when CC.NodeID='+@VatNode+' then null else ''Exempt'' end VatPer
					,L.VatAmount'+@VATSQL+'
					,case when CC.NodeID='+@VatNode+' then null when L.VatPer is null and (L.VatType is null or L.VatType='''') then L.Amount else L.TaxableAmt+isnull(L.VatAmount,0.0) end AmountWithVAT
					,case when L.Sno=1 then L.TaxableAmt else null end RentWithVAT
					,L.DetailsXML,L.TaxableAmt,L.VatType,L.Sqft,L.Rate,L.RentAmount,L.Discount,LOC.Name LocationID,L.NetAmount'

					if (@dimCid>50000)
						set @SQL=@SQL+' ,Dim.Name Dimname'
					ELSE
						set @SQL=@SQL+' ,'''' Dimname'

					IF(@TblName3='REN_ContractParticulars')
						set @SQL=@SQL+',L.NonTaxAmount'

					set @SQL=@SQL+@CCcolnames+'
					from '+@TblName3+' L WITH(NOLOCK)
					LEFT JOIN '+@j+' CC WITH(NOLOCK) ON L.CCNodeID=CC.NodeID
					LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON L.CreditAccID=A.AccountID
					LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON L.DebitAccID=ACC.AccountID
					LEFT JOIN COM_Location LOC WITH(NOLOCK) ON L.LocationID=LOC.NodeID
					'+@CCcoljoin

					if (@dimCid>50000)
					BEGIN
						select @dtable=tablename from adm_features with(NOLOCK) where featureid=@dimCid
						set @SQL=@SQL+' LEFT JOIN '+@dtable+' Dim WITH(NOLOCK) ON Dim.NodeID=L.DimNodeID '
					END

					set @SQL=@SQL+' where L.'+@PK+'='+convert(nvarchar,@DocumentSeqNo)+'
			end
			else
			begin
					select L.NodeID ParticularID,L.Amount,L.Narration,A.AccountName AS CreditAccID,ACC.AccountName AS DebitAccID,NULL as Particulars,L.ChequeNO,convert(Datetime,L.ChequeDate) Date,L.PayeeBank
					,case when L.VatPer>0 then convert(nvarchar,L.VatPer) when L.CCNodeID='+@VatNode+' then null else ''Exempt'' end VatPer
					,L.VatAmount'+@VATSQL+'
					,case when L.CCNodeID='+@VatNode+' then null when L.VatPer is null and (L.VatType is null or L.VatType='''') then L.Amount else L.TaxableAmt+isnull(L.VatAmount,0.0) end AmountWithVAT
					,case when L.Sno=1 then L.TaxableAmt else null end RentWithVAT
					,L.DetailsXML,L.TaxableAmt,L.VatType,L.Sqft,L.Rate,L.RentAmount,L.Discount,LOC.Name LocationID,L.NetAmount'
					
					if (@dimCid>50000)
						set @SQL=@SQL+' ,Dim.Name Dimname'
					ELSE
						set @SQL=@SQL+' ,'''' Dimname'

					IF(@TblName3='REN_ContractParticulars')
						set @SQL=@SQL+',L.NonTaxAmount'

					set @SQL=@SQL+@CCcolnames+'
					from '+@TblName3+' L WITH(NOLOCK)
					LEFT JOIN ACC_Accounts A WITH(NOLOCK) ON L.CreditAccID=A.AccountID
					LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON L.DebitAccID=ACC.AccountID
					LEFT JOIN COM_Location LOC WITH(NOLOCK) ON L.LocationID=LOC.NodeID
					'+@CCcoljoin

					if (@dimCid>50000)
					BEGIN
						select @dtable=tablename from adm_features with(NOLOCK) where featureid=@dimCid
						set @SQL=@SQL+' LEFT JOIN '+@dtable+' Dim WITH(NOLOCK) ON Dim.NodeID=L.DimNodeID '
					END

					set @SQL=@SQL+' where L.'+@PK+'='+convert(nvarchar,@DocumentSeqNo)+'
			end'
			print @SQL
			exec(@SQL)
			
			
			set @CCcolnames=''
			set @CCcoljoin=''
			SELECT @CCcolnames=@CCcolnames+',C'+CONVERT(NVARCHAR,ROW_NUMBER() OVER (ORDER BY[ColumnCostCenterID]))+'.Name '+SYSCOLUMNNAME
			,@CCcoljoin=@CCcoljoin+' LEFT JOIN '+ParentCostCenterSysName+' C'+CONVERT(NVARCHAR,ROW_NUMBER() OVER (ORDER BY[ColumnCostCenterID]))+' WITH(NOLOCK) ON C'+CONVERT(NVARCHAR,ROW_NUMBER() OVER (ORDER BY[ColumnCostCenterID]))+'.NodeID=L.'+SYSCOLUMNNAME	
			FROM ADM_CostCenterDef with(nolock) 
			WHERE COSTCENTERID=@DocumentID and SYSCOLUMNNAME like 'CCNID%'
			and SysTableName=@TblName4
			
			set @SQL='
			select L.ChequeNO,convert(Datetime,L.ChequeDate) Date,convert(Datetime,L.ChequeDate) ChequeDate,L1.Name PayeeBank,ACC.AccountName AS DebitAccID,L.Amount,L.Narration
			,DD.VoucherNo as DocID,S.Status StatusID,LP.Name Period'
			if @DocumentID=95
			BEGIN
				set @SQL=@SQL+',CASE WHEN L.Sno=1 THEN (SELECT top 1 ISNULL(P.CODE+CONVERT(NVARCHAR,Q.Number),0) FROM REN_Contract C WITH(NOLOCK)
								LEFT JOIN REN_QuotationPayTerms QPT WITH(NOLOCK) ON QPT.QuotationID=C.QuotationID 
								LEFT JOIN REN_Quotation Q WITH(NOLOCK) ON Q.QuotationID=QPT.QuotationID
								LEFT JOIN REN_Property P WITH(NOLOCK) ON P.NodeID=Q.Prefix
								WHERE C.CONTRACTID=L.'+@PK+') ELSE '''' END RefNo,convert(datetime,DD.DocDate) PostingDate'
								
				set @SQL=@SQL+',CC.Name Particular,convert(Datetime,L.TillDate) TillDate'
			END

			if (@dimCid>50000)
				set @SQL=@SQL+' ,Dim.Name Dimname'
			ELSE
				set @SQL=@SQL+' ,'''' Dimname'

			set @SQL=@SQL+',LOC.Name LocationID'+@CCcolnames+' 
			from '+@TblName4+' L WITH(NOLOCK)
			LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON L.DebitAccID=ACC.AccountID
			LEFT JOIN COM_LOOKUP L1 WITH(NOLOCK) on L.CustomerBank=L1.NodeID
			LEFT JOIN COM_LOOKUP LP WITH(NOLOCK) on L.Period=LP.NodeID'

			if (@dimCid>50000)
			BEGIN
				select @dtable=tablename from adm_features with(NOLOCK) where featureid=@dimCid
				set @SQL=@SQL+' LEFT JOIN '+@dtable+' Dim WITH(NOLOCK) ON Dim.NodeID=L.DimNodeID '
			END

			if @IsSinglePDC=1
				set @SQL=@SQL+' JOIN REN_ContractDocMapping LL WITH(NOLOCK) ON L.ContractID = LL.ContractID 
				JOIN Acc_DocDetails DD WITH(NOLOCK) on  LL.DocID =  DD.DocID '
			ELSE
				set @SQL=@SQL+' LEFT JOIN REN_ContractDocMapping LL WITH(NOLOCK) ON L.'+@PK+'=LL.CONTRACTID and LL.Type=2 and L.Sno=LL.Sno and LL.ContractCCID='+convert(nvarchar,@DocumentID)+'
				LEFT JOIN ACC_DocDetails DD WITH(NOLOCK) ON LL.DocID=DD.DocID AND (DD.DocumentType!=17 OR (DD.DocumentType=17 AND CreditAccount>0)) '

			set @SQL=@SQL+' LEFT JOIN COM_STATUS S WITH(NOLOCK) ON DD.STATUSID=S.STATUSID
			LEFT JOIN COM_Location LOC WITH(NOLOCK) ON L.LocationID=LOC.NodeID'+@CCcoljoin
			if @DocumentID=95
				set @SQL=@SQL+' LEFT JOIN '+@j+' CC WITH(NOLOCK) ON L.Particular=CC.NodeID '
			set @SQL=@SQL+' where L.'+@PK+'='+convert(nvarchar,@DocumentSeqNo)
			if @IsSinglePDC=1
				set @SQL=@SQL+' and (DD.debitaccount=L.DebitAccID or DD.BankAccountID=L.DebitAccID) and DD.amount=L.amount and DD.ChequeNumber=L.ChequeNo '
			set @SQL=@SQL+' order by L.Sno'
			print @SQL
			exec(@SQL)

			Create Table #tmp(id int identity(1,1),Amount float,DetailsTotal float)			
			
			if @DocumentID=103 OR @DocumentID=129
			begin
				set @SQL='Select Amount,(select SUM(Amount)  From REN_QuotationParticulars WITH(NOLOCK) where  QuotationID='+convert(nvarchar,@DocumentSeqNo)+' and ISRECURR=0) 
				From REN_QuotationPayTerms WITH(NOLOCK) where QuotationID='+convert(nvarchar,@DocumentSeqNo)
			end
			else
			begin
				SET @SQL='Select Amount,(select SUM(Amount)  From REN_ContractParticulars WITH(NOLOCK) where CONTRACTID='+convert(nvarchar,@DocumentSeqNo)+' and ISRECURR=0) 
				From REN_ContractPayTerms WITH(NOLOCK) where CONTRACTID='+convert(nvarchar,@DocumentSeqNo)
			end	
			
			Insert into #tmp
			EXEC (@SQL)
			
			update #tmp set DetailsTotal=0 where id<>1
			
			select Id,Amount,Case when DetailsTotal=0 then NULL else DetailsTotal end as DetailsTotal,SUM(Amount+DetailsTotal) as TotalAmount 
			from #tmp WITH(NOLOCK) 
			Group by Id,Amount,DetailsTotal
			
			drop table #tmp
		
			truncate table #ExtendedTable
			set @ExtQuery=''
			set @ExtJoin=''
					
			insert into #ExtendedTable(SysColumnName,CostCenterID)
			select SysColumnName,CASE WHEN (ColumnCostCenterID>0 AND UserColumnType='LISTBOX') THEN ColumnCostCenterID ELSE 0 END from adm_CostCenterDef WITH(NOLOCK) 
			where CostCenterID=94 and SystableName='REN_TenantExtended' and IsColumnInUse=1

			select @Exti=1,@ExtCNT=count(id) from #ExtendedTable

			while (@Exti<=	@ExtCNT)
			begin
				select @SysColumnName=SysColumnName,@ExtCCID=isnull(CostCenterID,0) from #ExtendedTable where ID=@Exti
				
				if(@ExtCCID is not null and @ExtCCID<>'' and @ExtCCID>0)	
				begin
					select @ExtTab=TableName,@PrimaryKey=PrimaryKey from adm_features WITH(NOLOCK) where FeatureID = @ExtCCID
					set @ExtTabRef='EXT'+CONVERT(nvarchar,@Exti)
					
					set @ExtQuery=@ExtQuery+','+@ExtTabRef+'.'+CASE WHEN @ExtCCID=2 THEN 'AccountName ' WHEN @ExtCCID=3 THEN 'ProductName ' ELSE 'Name ' END+@SysColumnName
					set @ExtJoin=@ExtJoin+' left join '+@ExtTab+' '+@ExtTabRef+' WITH(NOLOCK) on '+@ExtTabRef+'.'+@PrimaryKey+'=EXT.'+@SysColumnName

				end
				else
				begin
					set @ExtQuery=@ExtQuery+',EXT.'+@SysColumnName
				end
				set @Exti=@Exti+1
			end
			
			--TENANT
			set @Sql=' 
			select T.TenantCode,L1.Name TypeID,L2.Name PositionID,T.FirstName,T.MiddleName,T.LastName,T.LeaseSignatory,T.ContactPerson,A.AccountName PostingID,T.Phone1,T.Phone2,
			T.Email,T.Fax,T.IDNumber,T.Profession,T.Passport,T.Nationality,convert(datetime,T.PassportIssueDate) PassportIssueDate,convert(datetime,T.PassportExpiryDate) PassportExpiryDate,
			T.SponsorName,T.SponsorPassport,convert(datetime,T.SponsorIssueDate) SponsorIssueDate,convert(datetime,T.SponsorExpiryDate) SponsorExpiryDate,
			T.License,T.LicenseIssuedBy,convert(datetime,T.LicenseIssueDate) LicenseIssueDate,convert(datetime,T.LicenseExpiryDate) LicenseExpiryDate
			'+@CustomQueryNoName+@ExtQuery+'
			From REN_Tenant T with(nolock)
			left join Com_LookUp L1 with(nolock) on L1.NodeID=T.TypeID
			left join Com_LookUp L2 with(nolock) on L2.NodeID=T.PositionID
			left join Acc_Accounts A with(nolock) on A.AccountID=T.PostingID
			LEFT JOIN REN_TenantExtended EXT WITH(NOLOCK) on T.TenantID=EXT.TenantID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on T.TenantID=CC.NodeID and CC.CostCenterID=94'
			+@CustomQuery1+@ExtJoin+'
			where T.TenantID=' +convert(nvarchar,@TenantID)
			--print(@SQL)
			exec(@SQL)
			
			truncate table #ExtendedTable
			set @ExtQuery=''
			set @ExtJoin=''
					
			insert into #ExtendedTable(SysColumnName,CostCenterID)
			select SysColumnName,CASE WHEN (ColumnCostCenterID>0 AND UserColumnType='LISTBOX') THEN ColumnCostCenterID ELSE 0 END 
			from adm_CostCenterDef WITH(NOLOCK) 
			where CostCenterID=92 and SystableName='REN_PropertyExtended' and IsColumnInUse=1

			select @Exti=1,@ExtCNT=count(id) from #ExtendedTable

			while (@Exti<=	@ExtCNT)
			begin
				select @SysColumnName=SysColumnName,@ExtCCID=isnull(CostCenterID,0) from #ExtendedTable where ID=@Exti
				
				if(@ExtCCID is not null and @ExtCCID<>'' and @ExtCCID>0)	
				begin
					select @ExtTab=TableName,@PrimaryKey=PrimaryKey from adm_features WITH(NOLOCK) where FeatureID = @ExtCCID
					set @ExtTabRef='EXT'+CONVERT(nvarchar,@Exti)
					
					set @ExtQuery=@ExtQuery+','+@ExtTabRef+'.'+CASE WHEN @ExtCCID=2 THEN 'AccountName ' WHEN @ExtCCID=3 THEN 'ProductName ' ELSE 'Name ' END+@SysColumnName
					set @ExtJoin=@ExtJoin+' left join '+@ExtTab+' '+@ExtTabRef+' WITH(NOLOCK) on '+@ExtTabRef+'.'+@PrimaryKey+'=EXT.'+@SysColumnName

				end
				else
				begin
					set @ExtQuery=@ExtQuery+',EXT.'+@SysColumnName
				end
				set @Exti=@Exti+1
			end
			
			--PROPERTY
			set @Sql='
			select P.Code,P.Name,S.Status StatusID,L1.Name PropertyTypeLookUpID,P.PlotArea,P.BuiltUpArea,L2.Name LandLordLookUpID,P.Address1,P.Address2,P.City,P.State [State],
			P.Zip,P.Country,P.BondNo,Convert(Datetime,P.BondDate) BondDate,L3.Name BondTypeLookUpID,P.PropertyNo,L4.Name PropertyPositionLookUpID,L5.Name PropertyCategoryLookUpID,
			L6.Name TowerType,
			P.Units,P.Parkings,P.Floors,AA.AccountName RentalIncomeAccountID,AA2.AccountName RentalReceivableAccountID,AA3.AccountName AdvanceRentAccountID,AA4.AccountName BankAccount,
			AA5.AccountName BankLoanAccount,AA6.AccountName RentalAccount,AA7.AccountName RentPayableAccount,P.AdvanceRentPaid,P.TermsConditions
			,LandLord.Name LandlordID
			'+@CustomQueryNoName+@ExtQuery+'
			From REN_Property P with(nolock)
			Left join Com_Status S with(Nolock) on P.StatusID=S.StatusID
			left join Com_LookUp L1 with(nolock) on L1.NodeID=P.PropertyTypeLookUpID
			left join Com_LookUp L2 with(nolock) on L2.NodeID=P.LandLordLookUpID
			left join Com_LookUp L3 with(nolock) on L3.NodeID=P.BondTypeLookUpID
			left join Com_LookUp L4 with(nolock) on L4.NodeID=P.PropertyPositionLookUpID
			left join Com_LookUp L5 with(nolock) on L5.NodeID=P.PropertyCategoryLookUpID
			left join Com_LookUp L6 with(nolock) on L6.NodeID=P.TowerType
			left join Acc_Accounts AA with(nolock) on AA.AccountID=P.RentalIncomeAccountID
			left join Acc_Accounts AA2 with(nolock) on AA2.AccountID=P.RentalReceivableAccountID
			left join Acc_Accounts AA3 with(nolock) on AA3.AccountID=P.AdvanceRentAccountID
			left join Acc_Accounts AA4 with(nolock) on AA4.AccountID=P.BankAccount
			left join Acc_Accounts AA5 with(nolock) on AA5.AccountID=P.BankLoanAccount
			left join Acc_Accounts AA6 with(nolock) on AA6.AccountID=P.RentalAccount
			left join Acc_Accounts AA7 with(nolock) on AA7.AccountID=P.RentPayableAccount
			left join '+@LandLord+' LandLord with(nolock) on LandLord.NodeID=P.LandlordID
			LEFT JOIN REN_PropertyExtended EXT WITH(NOLOCK) on P.NodeID=EXT.NodeID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on P.NodeID=CC.NodeID and CC.CostCenterID=92'
			+@CustomQuery1+@ExtJoin+'
			where P.NodeID=' +convert(nvarchar,@PropertyID)
			--Print(substring(@SQL,0,4000))
		 	--Print(substring(@SQL,4001,4000))
			exec(@SQL)

			truncate table #ExtendedTable
			set @ExtQuery=''
			set @ExtJoin=''
					
			insert into #ExtendedTable(SysColumnName,CostCenterID)
			select SysColumnName,CASE WHEN (ColumnCostCenterID>0 AND UserColumnType='LISTBOX') THEN ColumnCostCenterID ELSE 0 END from adm_CostCenterDef WITH(NOLOCK) 
			where CostCenterID=93 and SystableName='REN_UnitsExtended' and IsColumnInUse=1

			select @Exti=1,@ExtCNT=count(id) from #ExtendedTable

			while (@Exti<=	@ExtCNT)
			begin
				select @SysColumnName=SysColumnName,@ExtCCID=isnull(CostCenterID,0) from #ExtendedTable where ID=@Exti
				
				if(@ExtCCID is not null and @ExtCCID<>'' and @ExtCCID>0)	
				begin
					select @ExtTab=TableName,@PrimaryKey=PrimaryKey from adm_features WITH(NOLOCK) where FeatureID = @ExtCCID
					set @ExtTabRef='EXT'+CONVERT(nvarchar,@Exti)
					
					set @ExtQuery=@ExtQuery+','+@ExtTabRef+'.'+CASE WHEN @ExtCCID=2 THEN 'AccountName ' WHEN @ExtCCID=3 THEN 'ProductName ' ELSE 'Name ' END+@SysColumnName
					set @ExtJoin=@ExtJoin+' left join '+@ExtTab+' '+@ExtTabRef+' WITH(NOLOCK) on '+@ExtTabRef+'.'+@PrimaryKey+'=EXT.'+@SysColumnName

				end
				else
				begin
					set @ExtQuery=@ExtQuery+',EXT.'+@SysColumnName
				end
				set @Exti=@Exti+1
			end
			
			set @Sql='
			select C.Code,C.Name,P.Code Property,S.Status StatusID,C.RentableArea,C.BuildUpArea,L1.Name FloorLookUpID ,L2.Name ViewLookUpID,
			C.NoOfBathrooms,C.NoOfParkings,C.ElectricityCode,C.ElectricityKW,C.DiscountAmount Discount,C.AnnualRent,C.MonthlyRent,C.RentPerSQFT,U.Name [Group],
			C.Rent Amount,Case when C.RentTypeID=1 then ''Annual'' when C.RentTypeID=2 then ''Monthly'' else ''SqFt'' end as AmountType,Accountant.Name AccountantID,
			SalesMan.Name SalesmanID,LandLord.Name LandlordID, Convert(float,C.ElectricityKW) Electricity,C.BasedOn,
			C.TermsConditions'+@CustomQueryNoName+@ExtQuery+',UnitType.Name as NodeID,L3.Name as UnitType
			From REN_Units C with(nolock)
			inner join REN_Units U with(nolock) on U.UnitID=C.UnitID
			inner join REN_Property P with(nolock) on C.PropertyID=P.NodeID
			Left join Com_Status S with(Nolock) on C.Status=S.StatusID
			left join Com_LookUp L1 with(nolock) on L1.NodeID=C.FloorLookUpID
			left join Com_LookUp L2 with(nolock) on L2.NodeID=C.ViewLookUpID
			left join Com_LookUp L3 with(nolock) on L3.NodeID=C.UnitType
			left join '+@Accountant+' Accountant with(nolock) on Accountant.NodeID=C.AccountantID
			left join '+@SalesMan+' SalesMan with(nolock) on SalesMan.NodeID=C.SalesmanID
			left join '+@LandLord+' LandLord with(nolock) on LandLord.NodeID=C.LandlordID
			left join '+@UTTableName+' UnitType with(nolock) on U.NodeID=UnitType.Nodeid
			LEFT JOIN REN_UnitsExtended EXT WITH(NOLOCK) on C.UnitID=EXT.UnitID
			LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on C.UnitID=CC.NodeID and CC.CostCenterID=93'
			+@CustomQuery1+@ExtJoin+' 
			where C.UnitID=' +convert(nvarchar,@UnitID)
			
			exec(@SQL)
			
			set @Sql='SELECT ParticularNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,P.Name Period
			,ActAmount Amount,CP.Rate,CP.Discount,CP.Amount AfterDiscount,ActAmount,Distribute,U.Name Unit,CP.Narration,LP.Sqft
			,Fld1 ,Fld2 ,Fld3 ,Fld4 ,Fld5 ,Fld6 ,Fld7 ,Fld8 ,Fld9 ,Fld10,CP.ProposedRent,CP.ProposedDisc,CP.ProposedAmount,CP.BaseRent,CP.PrevRent
			FROM REN_ContractParticularsDetail CP with(nolock)
			JOIN '+@TblName1+' L WITH(NOLOCK) ON L.'+@PK+'=CP.ContractID AND L.Costcenterid=CP.Costcenterid
			JOIN '+@TblName3+' LP WITH(NOLOCK) ON L.'+@PK+'=LP.'+@PK+' AND LP.Sno=1
			left join com_lookup P with(nolock) on P.NodeID=CP.Period
			left join REN_Units U with(nolock) on U.UnitID=ISNULL(CP.Unit,L.UnitID)
			where CP.ContractID='+convert(nvarchar,@DocumentSeqNo)+' and CP.Costcenterid='+convert(nvarchar,@DocumentID)
		
			
			exec(@SQL)
				
		END
		drop table #CustomTable
	END
	ELSE IF(@DocumentID=94)
	BEGIN
		set @Sql=' 
		select '+@ExtSelectQuery+'T.TenantCode,L1.Name TypeID,L2.Name PositionID,T.FirstName,T.MiddleName,T.LastName,T.LeaseSignatory,T.ContactPerson,A.AccountName PostingID,T.Phone1,T.Phone2,
		T.Email,T.Fax,T.IDNumber,T.Profession,T.Passport,T.Nationality,convert(datetime,T.PassportIssueDate) PassportIssueDate,convert(datetime,T.PassportExpiryDate) PassportExpiryDate,
		T.SponsorName,T.SponsorPassport,convert(datetime,T.SponsorIssueDate) SponsorIssueDate,convert(datetime,T.SponsorExpiryDate) SponsorExpiryDate,
		T.License,T.LicenseIssuedBy,convert(datetime,T.LicenseIssueDate) LicenseIssueDate,convert(datetime,T.LicenseExpiryDate) LicenseExpiryDate
		From REN_Tenant T with(nolock)
		left join Com_LookUp L1 with(nolock) on L1.NodeID=T.PositionID
		left join Com_LookUp L2 with(nolock) on L2.NodeID=T.PositionID
		left join Acc_Accounts A with(nolock) on A.AccountID=T.PostingID
		LEFT JOIN REN_TenantExtended EXT WITH(NOLOCK) on T.TenantID=EXT.TenantID
		LEFT JOIN COM_CCCCDATA CC WITH(NOLOCK) on T.TenantID=CC.NodeID and CC.CostCenterID=94'
		+@ExtJoinQuery+'
		where T.TenantID=' +convert(nvarchar,@DocumentSeqNo)
		--print(@SQL)
		exec(@SQL)
	END
		
	--ATTACHMENTS
	if @Attachments=0
		select '' [GUID],'' ActualFileName,'' FileExtension where 1<>1
	else-- if @Attachments=1
		select [GUID],ActualFileName,FileExtension  from COM_Files with(nolock)
		where FeatureID=@DocumentID AND FeaturePK=@DocumentSeqNo and AllowinPrint=1

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
