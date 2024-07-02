USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetParticulars]
	@UnitID [int] = 0,
	@PropertyID [int] = 0,
	@ContractStartDate [datetime],
	@ContractType [int] = 0,
	@ContractEndDate [datetime],
	@ContractID [int],
	@MultiUnitIDs [nvarchar](max),
	@RenewRefID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY                       
SET NOCOUNT ON                      
                   
                   
	declare @T1 nvarchar(100),@T2 nvarchar(100),@Sql nvarchar(max)   , @Rent FLOAT,@PropRRA INT,@isvat bit
	declare @PrefValue NVARCHAR(500),@colnames nvarchar(max)   ,@bankid int
	declare @dimCid int,@table nvarchar(50),@partCCID int,@RentNodeid int
	declare @ServiceUnitDims int,@ServiceUnitTypes nvarchar(max) 
	
	set @colnames=''
	SELECT @colnames=@colnames+',PRT.'+SYSCOLUMNNAME	FROM ADM_CostCenterDef with(nolock) 
	WHERE COSTCENTERID=95  and SYSCOLUMNNAME like 'CCNID%'
	and SysTableName='REN_ContractParticulars'
					
	set @dimCid=0
	select @dimCid=Value from COM_CostCenterPreferences WITH(NOLOCK)
	where Name='DimensionWiseContract' and costcenterid=95 and Value is not null and Value<>'' and ISNUMERIC(value)=1

	if exists(select * from adm_globalpreferences with(nolock) where name ='VATVersion')	 
		set @isvat=1
	else
		set @isvat=0
		
	if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'')
	BEGIN
		set @Sql =' SELECT @PropertyID=PropertyID FROM REN_Units with(nolock) WHERE UnitID in('+@MultiUnitIDs+')'
		EXEC sp_executesql @Sql,N'@PropertyID INT OUTPUT',@PropertyID output
	END                       
	else IF @UnitID<> 0
	  SELECT @PropertyID=PropertyID,@Rent=Rent FROM REN_Units with(nolock) WHERE UnitID=@UnitID             
    
    select @partCCID=value from ADM_GlobalPreferences with(nolock) 
    where  Name='DepositLinkDimension' and value is not null and value<>'' and isnumeric(value)=1
      
	select @T1=TableName from adm_features with(nolock) where featureid=@partCCID
	
	select @bankid=BankAccount,@PropRRA=RentalReceivableAccountID from REN_Property WITH(NOLOCK) where NodeID=@PropertyID
         
    --Unit Particulars                   
	set @Sql =' select T1.NodeID,T1.Name as Particulars, PRT.PropertyID, PRT.UnitID, PRT.CreditAccountID CreditID, PRT.DebitAccountID DebitID, PRT.Refund, PRT.DiscountPercentage, PRT.DiscountAmount,PRT.Months,PRT.DimNodeID,
	ACC.AccountCode CreditCode, ACC.AccountNAME CreditName  ,ACCD.AccountCode DebitCode, ACCD.AccountNAME DebitName , '+ CONVERT(NVARCHAR,ISNULL(@PropertyID, 0)) +' ActualPropertyID   '
	
	if(@isvat=1)
		SET  @Sql  = @Sql + ',Tx.Name TaxCategory,PRT.TaxCategoryID,SPT.Name SPTypeName,PRT.SPType,PRT.VatType,PRT.RecurInvoice'
	else
		SET  @Sql = @Sql + ',NULL TaxCategory,NULL TaxCategoryID,NULL SPTypeName,NULL SPType,NULL VatType,NULL RecurInvoice'

		if (@dimCid>50000)
			set @Sql=@Sql+' ,Dim.Name Dimname'
		ELSE
			set @Sql=@Sql+' ,'''' Dimname'	

					
	SET  @Sql  = @Sql +@colnames+ ',PRT.BankAccountID,PRT.Display,PostDebit,InclChkGen,VAT,AdvanceAccountID AdvanceAcc,UNT.RentalIncomeAccountID IncomeAccID , UNT.RentalReceivableAccountID RentRecAccID ,  UNT.AdvanceRentAccountID AdvRentAccID ,ACCAdvRec.AccountNAME ACCAdvRec                   
	,  UNT.BankAccount DebitAccID,Debit.AccountNAME DebitAcc , UNT.TermsConditions , PRT.TypeID Type ,UNT.AdvanceRentPaid AdvanceRentPaid , AdvRentP.AccountNAME AdvanceRentPaidName   from '+@T1 + ' AS T1 with(nolock) '

	SET  @Sql  = @Sql + ' LEFT JOIN REN_Particulars PRT with(nolock) ON T1.NodeID = PRT.PARTICULARID                        
	left JOIN REN_Units UNT with(nolock) ON  PRT.PropertyID = UNT.PropertyID and PRT.UnitID = UNT.UnitID '  
	
	if(@isvat=1)                   
		SET  @Sql  = @Sql + ' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=PRT.TaxCategoryID  LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=PRT.SPType '
	
	if (@dimCid>50000)
	BEGIN
		select @table=tablename from adm_features with(NOLOCK) where featureid=@dimCid
		set @Sql=@Sql+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=PRT.DimNodeID '			
	END
	               
	SET  @Sql  = @Sql + 'LEFT JOIN ACC_Accounts ACC with(nolock) ON ACC.AccountID = PRT.CreditAccountID                        
	LEFT JOIN ACC_Accounts ACCAdvRec with(nolock) ON ACCAdvRec.AccountID = UNT.AdvanceRentAccountID 
	LEFT JOIN ACC_Accounts Debit with(nolock) ON Debit.AccountID = UNT.BankAccount            
	LEFT JOIN ACC_Accounts AdvRentP with(nolock) ON AdvRentP.AccountID = UNT.AdvanceRentPaid                    
	LEFT JOIN ACC_Accounts ACCD with(nolock) ON  ACCD.AccountID = PRT.DebitAccountID  WHERE PRT.PropertyID = ' + CONVERT(NVARCHAR, ISNULL(@PropertyID, 0))        
	
	if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'')
		SET  @Sql = @Sql + ' AND PRT.UnitID in ('+@MultiUnitIDs+') AND UNT.UnitID in ('+@MultiUnitIDs+')'
	else
		SET  @Sql  = @Sql + ' AND PRT.UNITID = ' + CONVERT(NVARCHAR, @UnitID) + ' AND UNT.UNITID = ' + CONVERT(NVARCHAR, @UnitID)
		
	IF(@ContractType > 0)        
		SET  @Sql = @Sql + ' AND PRT.CONTRACTTYPE = ' + CONVERT(NVARCHAR, @ContractType)         
	
	SET  @Sql = @Sql + ' order by T1.Code'	   
	
	exec (@Sql)            
    
    --Property Particulars
	set @Sql =' select T1.NodeID,T1.Name as Particulars, PRT.PropertyID, PRT.UnitID, PRT.CreditAccountID CreditID, PRT.DebitAccountID DebitID, PRT.Refund, PRT.DiscountPercentage, PRT.DiscountAmount, PRT.Months,PRT.DimNodeID,                          
	ACC.AccountCode CreditCode, ACC.AccountNAME CreditName  ,ACCD.AccountCode DebitCode, ACCD.AccountNAME DebitName , '+ CONVERT(NVARCHAR,ISNULL(@PropertyID, 0)) +' ActualPropertyID                       
    ,InclChkGen ,VAT,AdvanceAccountID AdvanceAcc,PRP.RentalIncomeAccountID IncomeAccID , PRP.RentalReceivableAccountID RentRecAccID ,  PRP.AdvanceRentAccountID AdvRentAccID,ACCAdvRec.AccountNAME ACCAdvRec '
    
	if(@isvat=1)
		SET  @Sql  = @Sql + ',Tx.Name TaxCategory,PRT.TaxCategoryID,SPT.Name SPTypeName,PRT.SPType,PRT.VatType,PRT.RecurInvoice'
	else
		SET  @Sql = @Sql + ',NULL TaxCategory,NULL TaxCategoryID,NULL SPTypeName,NULL SPType,NULL VatType,NULL RecurInvoice'
	if (@dimCid>50000)
		set @Sql=@Sql+' ,Dim.Name Dimname'
	ELSE
		set @Sql=@Sql+' ,'''' Dimname'	

	SET  @Sql = @Sql +@colnames+ ',PRT.BankAccountID,PRT.Display,PostDebit,  PRP.BankAccount DebitAccID,Debit.AccountNAME DebitAcc , PRP.TermsConditions , PRT.TypeID Type  ,PRP.AdvanceRentPaid AdvanceRentPaid , AdvRentP.AccountNAME AdvanceRentPaidName   from '+@T1 + ' AS T1 with(nolock)  '                      
	SET  @Sql = @Sql + ' LEFT JOIN REN_Particulars PRT with(nolock) ON T1.NodeID = PRT.PARTICULARID                       
    JOIN REN_Property PRP with(nolock) ON PRT.PropertyID = PRP.NodeID                      
	LEFT JOIN ACC_Accounts ACC with(nolock) ON ACC.AccountID = PRT.CreditAccountID                        
	LEFT JOIN ACC_Accounts ACCAdvRec with(nolock) ON ACCAdvRec.AccountID = PRP.AdvanceRentAccountID                        
	LEFT JOIN ACC_Accounts Debit with(nolock) ON Debit.AccountID = PRP.BankAccount          '  
 
	if(@isvat=1)
		SET  @Sql  = @Sql + ' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=PRT.TaxCategoryID  LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=PRT.SPType '
	
	if (@dimCid>50000)
	BEGIN		
		set @Sql=@Sql+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=PRT.DimNodeID '			
	END

	SET  @Sql = @Sql + ' LEFT JOIN ACC_Accounts AdvRentP with(nolock)  ON AdvRentP.AccountID = PRP.AdvanceRentPaid                   
	LEFT JOIN ACC_Accounts ACCD with(nolock) ON ACCD.AccountID = PRT.DebitAccountID   
	WHERE PRT.PropertyID = ' + CONVERT(NVARCHAR, @PropertyID)  + ' AND PRT.UNITID = 0 ' 
	
	IF(@ContractType > 0)      
		SET  @Sql = @Sql + ' AND PRT.CONTRACTTYPE = ' + CONVERT(NVARCHAR, @ContractType)                    
	
	SET  @Sql = @Sql + ' order by T1.Code'	   
	exec (@Sql)    
    
    if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'')
    BEGIN
		set @Sql ='SELECT PropertyID,AnnualRent RENT,RentalIncomeAccountID,RentalReceivableAccountID,AdvanceRentAccountID,DefVatType
		,'+convert(nvarchar,isnull(@bankid,'0'))+' bankid,'+convert(nvarchar,isnull(@PropRRA,'0'))+' PropRentRecAccID FROM REN_Units with(nolock) WHERE UnitID in('+@MultiUnitIDs+')'
		print @Sql
		exec (@Sql) 
    END
    Else
		SELECT PropertyID,RentalReceivableAccountID,AnnualRent RENT,@PropRRA PropRentRecAccID,DefVatType,@bankid bankid FROM REN_Units with(nolock) WHERE UnitID = @UnitID                       
                      
	select 1 where 1<>1
                      
    select  @PrefValue = Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 and  Name = 'StopContifnotrefund'
    
    select  @ServiceUnitDims=Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 And Name ='ServiceUnitDims'
	select  @ServiceUnitTypes=Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 And Name ='ServiceUnitTypes'
    
	if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'')
		BEGIN                  
			set @Sql ='SELECT RefContractID,UnitID,StatusID,CONVERT(datetime, StartDate) StartDate, CONVERT(datetime, EndDate) EndDate,contractid     FROM '
			
			if(@PrefValue is not null and @PrefValue='true')
				set @Sql =@Sql+' (select a.RefContractID,a.ContractPrefix,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when  b.contractid is null and a.statusid in(426,427) then 73048
					when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate 
					when a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a
				left join ren_contract b on a.contractid=b.renewrefid and b.statusid<>451
				where a.statusid<>451) as t  '
			else
				set @Sql =@Sql+' (select a.RefContractID,a.ContractPrefix,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate when  a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a WITH(NOLOCK)) as t '
			
			if(@ServiceUnitDims>0 and @ServiceUnitTypes is not null and @ServiceUnitTypes<>'')
				set @Sql =@Sql+' join COM_ccccdata u with(nolock) on u.NodeID=t.contractid '
			
			set @Sql =@Sql+' WHERE ( '''+convert(nvarchar,@ContractStartDate)+'''   between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)      
			or       '''+convert(nvarchar,@ContractEndDate)+'''  between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)
	 		or	CONVERT(datetime, StartDate) between '''+convert(nvarchar,@ContractStartDate)+''' and  '''+convert(nvarchar,@ContractEndDate)+''' 
	 		or CONVERT(datetime, EndDate) between '''+convert(nvarchar,@ContractStartDate)+''' and  '''+convert(nvarchar,@ContractEndDate)+'''  )             
			AND t.UnitID in('+@MultiUnitIDs+') and    t.StatusID not in(477,451) '
			
			if(@ServiceUnitDims>0 and @ServiceUnitTypes is not null and @ServiceUnitTypes<>'')
				set @Sql =@Sql+' and u.CostCenterID=95 and u.CCNID'+convert(nvarchar(max),(@ServiceUnitDims-50000))+' not in('+@ServiceUnitTypes+')'
			
			if(@ContractID>0)
				set @Sql =@Sql+' and t.ContractID<>'+convert(nvarchar,@ContractID)+' and t.RefContractID<>'+convert(nvarchar,@ContractID)			
		END
		ELSE
		BEGIN
			set @Sql='SELECT RefContractID,UnitID,StatusID,CONVERT(datetime, StartDate) StartDate, CONVERT(datetime, EndDate) EndDate,contractid FROM '
			
			if(@PrefValue is not null and @PrefValue='true')
				set @Sql =@Sql+' (select a.RefContractID,a.ContractPrefix,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when a.contractid='+convert(nvarchar,@RenewRefID)+' then a.enddate
				 when  b.contractid is null and a.statusid in(426,427) then 73048
				 when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate 
					when a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a
				left join ren_contract b on a.contractid=b.renewrefid and b.statusid<>451
				where a.statusid<>451) as t  '
			else
				set @Sql =@Sql+' (select a.RefContractID,a.UnitID,a.StatusID,a.ContractPrefix,a.contractid,a.startdate,
				case when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate when  a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a WITH(NOLOCK)) as t '
			
			if(@ServiceUnitDims>0 and @ServiceUnitTypes is not null and @ServiceUnitTypes<>'')
				set @Sql =@Sql+' join COM_ccccdata u with(nolock) on u.NodeID=t.contractid '
		
			set @Sql =@Sql+' WHERE ( '''+convert(nvarchar,@ContractStartDate)+'''   between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)      
			or       '''+convert(nvarchar,@ContractEndDate)+'''  between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)
			or	CONVERT(datetime, StartDate) between '''+convert(nvarchar,@ContractStartDate)+''' and  '''+convert(nvarchar,@ContractEndDate)+''' 
	 		or CONVERT(datetime, EndDate) between '''+convert(nvarchar,@ContractStartDate)+''' and  '''+convert(nvarchar,@ContractEndDate)+'''   )             
			AND t.UnitID = '+convert(nvarchar,@UnitID)+' and    t.StatusID <> 477   and    t.StatusID <> 451   '
			
			if(@ServiceUnitDims>0 and @ServiceUnitTypes is not null and @ServiceUnitTypes<>'')
				set @Sql =@Sql+' and u.CostCenterID=95 and u.CCNID'+convert(nvarchar(max),(@ServiceUnitDims-50000))+' not in('+@ServiceUnitTypes+')'
		
			set @Sql =@Sql+' and t.ContractID<>'+convert(nvarchar,@ContractID )		 		
		END	  
	exec(@Sql)	  
		           
	exec [spDOC_GetNode] @partCCID,'Rent',0,0,1,'GUID','Admin',1,1,@RentNodeid output

                        
    if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'')
    BEGIN 
		set @Sql ='SELECT  Name,UnitID,RENT RENTAMT , ISNULL((CASE WHEN DISCOUNTPERCENTAGE = -100 THEN DISCOUNTAMOUNT ELSE (RENT  * DISCOUNTPERCENTAGE) / 100 END),0)  DICOUNT   
		, ISNULL(AnnualRent,0) RENT ,CONVERT(FLOAT,ISNULL(CASE WHEN RentableArea<>''0'' THEN RentableArea END,1)) RentableArea
		,UnitStatus,dbo.[fnREN_GetPrevRent] (UnitID,'+convert(nvarchar(max),@RentNodeid)+') PrevVal
		FROM REN_Units  with(nolock) WHERE UnitID in('+@MultiUnitIDs+')'  
		exec (@Sql) 
    END
    ELSE
    BEGIN        
			SELECT  RENT RENTAMT , CASE WHEN DISCOUNTPERCENTAGE = -100 THEN DISCOUNTAMOUNT ELSE (RENT  * DISCOUNTPERCENTAGE) / 100 END  DICOUNT   
			, AnnualRent RENT,CONVERT(FLOAT,ISNULL(CASE WHEN RentableArea<>'0' THEN RentableArea END,1)) RentableArea 
			,UnitStatus,dbo.[fnREN_GetPrevRent] (@UnitID,@RentNodeid) PrevVal
			FROM REN_Units  with(nolock) WHERE UNITID  = @UnitID    
    END
    
    set @Sql ='SELECT AccountantID,SalesmanID,LandlordID,LocationID'
    
    if(@ContractType!=2)
		set @Sql =@Sql+',BasedOn,DefVatType'
		
	if(@isvat=1)
		set @Sql =@Sql+',ccnid70,ccnid58,ccnid59,ccnid61,ccnid62,ccnid60,SPT.Name SPTypeName,Tx.Name TcExcemt '
	else
		set @Sql =@Sql+',0 ccnid70,0 ccnid58,0 ccnid59,0 ccnid61,0 ccnid62,0 ccnid60 '
	
	if (@dimCid>50000)
		set @Sql=@Sql+' ,Dim.NodeID DimNodeID,Dim.Name Dimname'
	ELSE
		set @Sql=@Sql+' ,0 DimNodeID,'''' Dimname'	
	
	set @Sql=@Sql+@colnames
	
	if(@ContractType=2)
		set @Sql =@Sql+' FROM REN_Property a with(nolock) 
		join com_ccccdata  PRT with(nolock)  on a.NodeID=PRT.nodeid'
	ELSE
		set @Sql =@Sql+' FROM REN_Units a with(nolock) 
		join com_ccccdata  PRT with(nolock)  on a.unitid=PRT.nodeid'
	if(@isvat=1)
			SET  @Sql  = @Sql + ' LEFT JOIN COM_CC50060 Tx WITH(NOLOCK) ON Tx.NodeID=PRT.ccnid60   LEFT JOIN COM_CC50061 SPT WITH(NOLOCK) ON SPT.NodeID=PRT.ccnid61 '

	if (@dimCid>50000)
	BEGIN		
		set @Sql=@Sql+' LEFT JOIN '+@table+' Dim WITH(NOLOCK) ON Dim.NodeID=PRT.ccnid'+convert(nvarchar(50),(@dimCid-50000))
	END
	
	if(@ContractType=2)
		set @Sql =@Sql+' WHERE a.NodeID ='+convert(nvarchar,@PropertyID)+' and PRT.costcenterid=92'	
    ELSE if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'') 
		set @Sql =@Sql+' WHERE UnitID in('+@MultiUnitIDs+') and PRT.costcenterid=93'		
    ELSE if(@UnitID>0)
		set @Sql =@Sql+' WHERE UnitID='+convert(nvarchar,@UnitID)+' and PRT.costcenterid=93'
		print @Sql
     exec (@Sql) 
     
     if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'')
     BEGIN
		set @Sql ='SELECT RUR.UNITID,CONVERT(DATETIME,WITHEFFECTFROM) WEF,RUR.Amount RENTAMT,RUR.Discount DICOUNT , RUR.AnnualRent  RENT 
		FROM REN_UNITRATE RUR with(nolock)
		WHERE RUR.UNITID  in('+@MultiUnitIDs+')' 
		exec (@Sql) 
     END
     BEGIN 
 		SELECT CONVERT(DATETIME,WITHEFFECTFROM) WEF,RUR.Amount RENTAMT,RUR.Discount DICOUNT , RUR.AnnualRent  RENT 
		FROM REN_UNITRATE RUR with(nolock)
		WHERE RUR.UNITID  =@UnitID  
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
SET NOCOUNT OFF                        
RETURN -999                         
END CATCH
GO
