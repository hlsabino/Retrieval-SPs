USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_TransferAccountData]
	@FromID [int],
	@ToID [int],
	@CostCenterID [int],
	@Assign [bit],
	@Contacts [bit],
	@Adress [bit],
	@Notes [bit],
	@Attachments [bit],
	@Activities [bit],
	@WHERE [nvarchar](max),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON; 
 
	--Declaration Section  
	DECLARE @HasAccess BIT,@SQL nvarchar(max)

	--Check for manadatory paramters  
	IF(@FromID=0 OR @ToID=0)
	BEGIN  
		RAISERROR('-100',16,1)   
	END
	IF(@CostCenterID =2)
	BEGIN
			--User acces check
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,6)
			
			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END
			
			if(@WHERE!='')
			begin
				--For Accounting Vouchers
				set @SQL='update B set B.AccountID='+convert(nvarchar(max),@FromID)+'
				from Acc_DocDetails D WITH(NOLOCK)
				join com_docccdata DCC WITH(NOLOCK) on D.AccDocDetailsID=DCC.AccDocDetailsID
				join COM_Billwise B WITH(NOLOCK) on B.DocNo=D.VoucherNo
				WHERE D.InvDocDetailsID is null and B.AccountID='+convert(nvarchar,@FromID)+replace(@WHERE,'DCC.dc','B.dc')
				EXEC(@SQL)
				
				set @SQL='UPDATE D set D.DebitAccount='+convert(nvarchar(max),@ToID)+'
				from Acc_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.AccDocDetailsID=DCC.AccDocDetailsID
				WHERE D.InvDocDetailsID is null and D.DebitAccount='+convert(nvarchar,@FromID)+@WHERE
				EXEC(@SQL)
				
				set @SQL='UPDATE D set D.CreditAccount='+convert(nvarchar(max),@ToID)+'
				from Acc_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.AccDocDetailsID=DCC.AccDocDetailsID
				WHERE D.InvDocDetailsID is null and D.CreditAccount='+convert(nvarchar,@FromID)+@WHERE
				EXEC(@SQL)
				
				set @SQL='UPDATE D set D.BankAccountID='+convert(nvarchar(max),@ToID)+'
				from Acc_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.AccDocDetailsID=DCC.AccDocDetailsID
				WHERE D.InvDocDetailsID is null and D.BankAccountID='+convert(nvarchar,@FromID)+@WHERE
				EXEC(@SQL)

				
				--Inventory Vouchers
				set @SQL='UPDATE N set N.remarks=replace(convert(nvarchar(max),remarks),''DebitAccount="'+convert(nvarchar(max),@FromID)+'"'',''DebitAccount="'+convert(nvarchar(max),@ToID)+'"'')
				from Acc_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.InvDocDetailsID=DCC.InvDocDetailsID
				join com_docnumdata N WITH(NOLOCK) on D.InvDocDetailsID=N.InvDocDetailsID
				WHERE D.InvDocDetailsID is not null and DebitAccount='+convert(nvarchar,@FromID)+@WHERE +' and N.remarks is not null and convert(nvarchar(max),N.remarks)<>'''''
				EXEC(@SQL)
				
				set @SQL='UPDATE N set N.remarks=replace(convert(nvarchar(max),remarks),''CreditAccount="'+convert(nvarchar(max),@FromID)+'"'',''CreditAccount="'+convert(nvarchar(max),@ToID)+'"'')
				from Acc_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.InvDocDetailsID=DCC.InvDocDetailsID
				join com_docnumdata N WITH(NOLOCK) on D.InvDocDetailsID=N.InvDocDetailsID
				WHERE D.InvDocDetailsID is not null and CreditAccount='+convert(nvarchar,@FromID)+@WHERE +' and N.remarks is not null and convert(nvarchar(max),N.remarks)<>'''''
				EXEC(@SQL)
				
				set @SQL='update B set B.AccountID='+convert(nvarchar(max),@FromID)+'
				from Acc_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.InvDocDetailsID=DCC.InvDocDetailsID
				join COM_Billwise B WITH(NOLOCK) on B.DocNo=D.VoucherNo
				WHERE D.InvDocDetailsID is not null and B.AccountID='+convert(nvarchar,@FromID)+replace(@WHERE,'DCC.dc','B.dc')
				EXEC(@SQL)
				
				set @SQL='UPDATE D set D.DebitAccount='+convert(nvarchar(max),@ToID)+'
				from Acc_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.InvDocDetailsID=DCC.InvDocDetailsID
				WHERE D.InvDocDetailsID is not null and D.DebitAccount='+convert(nvarchar,@FromID)+@WHERE
				print(@SQL)
				EXEC(@SQL)
				
				set @SQL='UPDATE D set D.CreditAccount='+convert(nvarchar(max),@ToID)+'
				from Acc_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.InvDocDetailsID=DCC.InvDocDetailsID
				WHERE D.InvDocDetailsID is not null and D.CreditAccount='+convert(nvarchar,@FromID)+@WHERE
				print(@SQL)
				EXEC(@SQL)
				
				set @SQL='UPDATE D set D.DebitAccount='+convert(nvarchar(max),@ToID)+'
				from INV_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.InvDocDetailsID=DCC.InvDocDetailsID
				WHERE D.DebitAccount='+convert(nvarchar,@FromID)+@WHERE
				EXEC(@SQL)
				
				set @SQL='UPDATE D set D.CreditAccount='+convert(nvarchar(max),@ToID)+'
				from INV_DocDetails D WITH(NOLOCK) 
				join com_docccdata DCC WITH(NOLOCK) on D.InvDocDetailsID=DCC.InvDocDetailsID
				WHERE D.CreditAccount='+convert(nvarchar,@FromID)+@WHERE
				EXEC(@SQL)
				
			end
			else
			begin
				--For Accounting Vouchers
				UPDATE Acc_DocDetails SET DebitAccount=@ToID WHERE DebitAccount=@FromID
				
				UPDATE Acc_DocDetails SET CreditAccount=@ToID WHERE CreditAccount=@FromID
				
				UPDATE Acc_DocDetails SET BankAccountID=@ToID WHERE BankAccountID=@FromID

				--For Inventory Vouchers
				UPDATE Inv_DocDetails SET DebitAccount=@ToID WHERE DebitAccount=@FromID

				UPDATE Inv_DocDetails SET CreditAccount=@ToID WHERE CreditAccount=@FromID

				--For BillWise
				UPDATE COM_Billwise SET AccountID=@ToID WHERE AccountID=@FromID

				UPDATE COM_Billwise SET DiscAccountID=@ToID WHERE DiscAccountID=@FromID
				
				--Rentals
				if exists(select name from sys.tables where name='REN_Contract')
				begin
					set @SQL='UPDATE REN_Contract SET RentAccID='+convert(nvarchar(max),@ToID)+' WHERE RentAccID='+convert(nvarchar,@FromID)+'
					UPDATE REN_Contract SET IncomeAccID='+convert(nvarchar(max),@ToID)+' WHERE IncomeAccID='+convert(nvarchar,@FromID)
					EXEC(@SQL)
				end
				
				if exists(select name from sys.tables where name='REN_ContractParticulars')
				begin
					set @SQL='UPDATE REN_ContractParticulars SET DebitAccID='+convert(nvarchar(max),@ToID)+' WHERE DebitAccID='+convert(nvarchar,@FromID)+'
					UPDATE REN_ContractParticulars SET CreditAccID='+convert(nvarchar(max),@ToID)+' WHERE CreditAccID='+convert(nvarchar,@FromID)+'
					UPDATE REN_ContractParticulars SET CreditAccID='+convert(nvarchar(max),@ToID)+' WHERE CreditAccID='+convert(nvarchar,@FromID)
					EXEC(@SQL)
				end
				
				if exists(select name from sys.tables where name='REN_ContractPayTerms')
				begin
					set @SQL='UPDATE REN_ContractPayTerms SET DebitAccID='+convert(nvarchar(max),@ToID)+' WHERE DebitAccID='+convert(nvarchar,@FromID)
					EXEC(@SQL)
				end
				
				update com_docnumdata
				set remarks=replace(convert(nvarchar(max),remarks),'DebitAccount="'+convert(nvarchar(max),@FromID)+'"','DebitAccount="'+convert(nvarchar(max),@ToID)+'"')
				where remarks is not null and convert(nvarchar(max),remarks)<>''
				
				update com_docnumdata
				set remarks=replace(convert(nvarchar(max),remarks),'CreditAcount="'+convert(nvarchar(max),@FromID)+'"','CreditAcount="'+convert(nvarchar(max),@ToID)+'"')
				where remarks is not null and convert(nvarchar(max),remarks)<>''
			end

	END
	IF(@CostCenterID =3)
	BEGIN
			--User acces check
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,3,6)
			
			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END 

			--For Inventory Vouchers 
			UPDATE Inv_DocDetails SET ProductID=@ToID WHERE ProductID=@FromID 
	 	
			UPDATE INV_Batches SET ProductID=@ToID WHERE ProductID=@FromID  
		  	
		  	if exists(select name from sys.tables where name='PRD_BillOfMaterial')
			begin
				set @SQL='UPDATE PRD_BillOfMaterial SET ProductID='+convert(nvarchar(max),@ToID)+' WHERE ProductID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PRD_BOMProducts')
			begin
				set @SQL='UPDATE PRD_BOMProducts SET ProductID='+convert(nvarchar(max),@ToID)+' WHERE ProductID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PRD_JobOuputProducts')
			begin
				set @SQL='UPDATE PRD_JobOuputProducts SET ProductID='+convert(nvarchar(max),@ToID)+' WHERE ProductID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
		  	
		  	if exists(select name from sys.tables where name='CRM_Cases')
			begin
				set @SQL='UPDATE CRM_Cases SET ProductID='+convert(nvarchar(max),@ToID)+' WHERE ProductID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='CRM_CampaignProducts')
			begin
				set @SQL='UPDATE CRM_CampaignProducts SET ProductID='+convert(nvarchar(max),@ToID)+' WHERE ProductID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='CRM_CampaignResponse')
			begin
				set @SQL='UPDATE CRM_CampaignResponse SET ProductID='+convert(nvarchar(max),@ToID)+' WHERE ProductID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			 
			if exists(select name from sys.tables where name='CRM_LeadCVRDetails')
			begin
				set @SQL='UPDATE CRM_LeadCVRDetails SET Product='+convert(nvarchar(max),@ToID)+' WHERE Product='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='CRM_ProductMapping')
			begin
				set @SQL='UPDATE CRM_ProductMapping SET ProductID='+convert(nvarchar(max),@ToID)+' WHERE ProductID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
		  	
  		 
	END
	ELSE IF(@CostCenterID=50051)
	BEGIN
			--User acces check
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,6)
			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END
			
			UPDATE COM_HISTORYDETAILS SET NodeID=@ToID WHERE NodeID=@FromID AND CostCenterID=50051
			
			UPDATE COM_CCCCData SET NodeID=@ToID WHERE NodeID=@FromID AND CostCenterID=50051
			
			if exists(select * from sys.columns where object_id=object_id('COM_DOCCCDATA') and name='dcCCNID51')
			begin
				set @SQL='UPDATE COM_DOCCCDATA SET dcCCNID51='+convert(nvarchar(max),@ToID)+' WHERE dcCCNID51='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_EmpDetail')
			begin
				set @SQL='UPDATE PAY_EmpDetail SET EmployeeID='+convert(nvarchar(max),@ToID)+' WHERE EmployeeID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='pay_empaccountslinking')
			begin
				set @SQL='UPDATE pay_empaccountslinking SET EmpSeqNo='+convert(nvarchar(max),@ToID)+' WHERE EmpSeqNo='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='pay_employeeLeaveDetails')
			begin
				set @SQL='UPDATE pay_employeeLeaveDetails SET EmployeeID='+convert(nvarchar(max),@ToID)+' WHERE EmployeeID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_EmpMonthlyAdjustments')
			begin
				set @SQL='UPDATE PAY_EmpMonthlyAdjustments SET EmpSeqNo='+convert(nvarchar(max),@ToID)+' WHERE EmpSeqNo='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_EmpMonthlyArrears')
			begin
				set @SQL='UPDATE PAY_EmpMonthlyArrears SET EmpSeqNo='+convert(nvarchar(max),@ToID)+' WHERE EmpSeqNo='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_EmpMonthlyDues')
			begin
				set @SQL='UPDATE PAY_EmpMonthlyDues SET EmpSeqNo='+convert(nvarchar(max),@ToID)+' WHERE EmpSeqNo='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_EmpPay')
			begin
				set @SQL='UPDATE PAY_EmpPay SET EmployeeID='+convert(nvarchar(max),@ToID)+' WHERE EmployeeID='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_EmpTaxComputation')
			begin
				set @SQL='UPDATE PAY_EmpTaxComputation SET EmpNode='+convert(nvarchar(max),@ToID)+' WHERE EmpNode='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_EmpTaxDeclaration')
			begin
				set @SQL='UPDATE PAY_EmpTaxDeclaration SET EmpNode='+convert(nvarchar(max),@ToID)+' WHERE EmpNode='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_EmpTaxHRAInfo')
			begin
				set @SQL='UPDATE PAY_EmpTaxHRAInfo SET EmpNode='+convert(nvarchar(max),@ToID)+' WHERE EmpNode='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_FinalSettlement')
			begin
				set @SQL='UPDATE PAY_FinalSettlement SET EmpSeqNo='+convert(nvarchar(max),@ToID)+' WHERE EmpSeqNo='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			if exists(select name from sys.tables where name='PAY_LoanGuarantees')
			begin
				set @SQL='UPDATE PAY_LoanGuarantees SET GEmpSeqNo='+convert(nvarchar(max),@ToID)+' WHERE GEmpSeqNo='+convert(nvarchar,@FromID)
				EXEC(@SQL)
			end
			
			
	END
	ELSE IF(@CostCenterID>50000)
	BEGIN
			--User acces check
			SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,6)
			
			IF @HasAccess=0
			BEGIN
				RAISERROR('-105',16,1)
			END
			declare @CCName nvarchar(50)
			set @CCName= 'CCNID'+CONVERT(nvarchar,@CostCenterID-50000) 
				
			--For Dimension Data 
			set @SQL='UPDATE COM_CCCCData SET '+@CCName+'='+Convert(nvarchar,@ToID)+' WHERE '+@CCName+'='+Convert(nvarchar,@FromID)+''
			--print (@SQL)
			exec (@SQL)

			--For Schemes & Discounts
			set @SQL='UPDATE ADM_SchemesDiscounts SET '+@CCName+'='+Convert(nvarchar,@ToID)+' WHERE '+@CCName+'='+Convert(nvarchar,@FromID)+''
			--print (@SQL)
			exec (@SQL)

			-----------------------------------------------------------------------
			set @CCName= 'dcCCNID'+CONVERT(nvarchar,@CostCenterID-50000) 
			--For Dimension Document data
			set @SQL='UPDATE COM_DocCCData SET '+@CCName+'='+Convert(nvarchar,@ToID)+' WHERE '+@CCName+'='+Convert(nvarchar,@FromID)+''
			--print (@SQL)
			exec (@SQL)
			set @SQL=''
			
			--For BillWise
			set @SQL='UPDATE COM_Billwise SET '+@CCName+'='+Convert(nvarchar,@ToID)+' WHERE '+@CCName+'='+Convert(nvarchar,@FromID)+''
			--print (@SQL)
			exec (@SQL)


			IF EXISTS (SELECT * FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='UnitLinkDimension' AND Value=@CostCenterID)
			BEGIN
				set @SQL='UPDATE REN_Units SET NodeID='+Convert(nvarchar,@ToID)+' WHERE NodeID='+Convert(nvarchar,@FromID)+' AND CCID='+Convert(nvarchar,@CostCenterID)
				--print (@SQL)
				exec (@SQL)
			END
			
			IF(@CostCenterID = 50068)
			BEGIN
				
				if exists(select name from sys.tables where name='COM_CC50051')
				begin
					set @SQL='UPDATE COM_CC50051 SET iBank='+convert(nvarchar(max),@ToID)+' WHERE iBank='+convert(nvarchar,@FromID)
					EXEC(@SQL)
				end
				
				if exists(select * from sys.columns where object_id=object_id('COM_DOCTEXTDATA') and name='dcAlpha15')
				begin
					set @SQL='UPDATE T SET T.dcAlpha15='''+Convert(nvarchar,@ToID)+''' 
								FROM COM_DOCTEXTDATA T WITH(NOLOCK) 
								JOIN INV_DOCDETAILS I WITH(NOLOCK) ON I.INVDOCDETAILSID=T.INVDOCDETAILSID
								WHERE T.dcAlpha15='''+Convert(nvarchar,@FromID)+''' AND I.COSTCENTERID=40054'
					EXEC(@SQL)
				end
				
				
			
			END
			
			UPDATE COM_HISTORYDETAILS SET HistoryNodeID=@ToID WHERE HistoryNodeID=@FromID AND HistoryCCID=@CostCenterID AND CostCenterID=50051
			
	END
	ELSE IF(@CostCenterID =83)
	BEGIN
		--For Dimension Document data
		if exists(select * from sys.columns where object_id=object_id('COM_DocCCData') and name='CustomerID')
		begin
			set @SQL='UPDATE COM_DocCCData SET CustomerID='+convert(nvarchar(max),@ToID)+' WHERE CustomerID='+convert(nvarchar,@FromID)
			EXEC(@SQL)
		end
	END

	if(@Assign=1)
	begin
		if(@CostCenterID=7)
		begin
			IF NOT EXISTS (SELECT ParentNodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
			WHERE ParentCostCenterID=@CostCenterID and ParentNodeID=@ToID)
				INSERT INTO [COM_CostCenterCostCenterMap]([ParentCostCenterID],[ParentNodeID],[CostCenterColID],[CostCenterID],[NodeID],[GUID],[Description],[CreatedBy],[CreatedDate],[CompanyGuid])
				SELECT [ParentCostCenterID],@ToID,[CostCenterColID],[CostCenterID],[NodeID],[GUID],[Description],[CreatedBy],CONVERT(FLOAT,GETDATE()),'Clone'
				FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
				WHERE ParentCostCenterID=@CostCenterID and ParentNodeID=@FromID
			
			IF NOT EXISTS (SELECT NodeID FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
			WHERE CostCenterID=@CostCenterID and NodeID=@ToID)
				INSERT INTO [COM_CostCenterCostCenterMap]([ParentCostCenterID],[ParentNodeID],[CostCenterColID],[CostCenterID],[NodeID],[GUID],[Description],[CreatedBy],[CreatedDate],[CompanyGuid])
				SELECT [ParentCostCenterID],[ParentNodeID],[CostCenterColID],[CostCenterID],@ToID,[GUID],[Description],[CreatedBy],CONVERT(FLOAT,GETDATE()),'Clone'
				FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
				WHERE CostCenterID=@CostCenterID and NodeID=@FromID
		end 
		else
		begin
			DELETE CCMP1 from COM_CostCenterCostCenterMap CCMP WITH(NOLOCK)
			JOIN COM_CostCenterCostCenterMap CCMP1 WITH(NOLOCK) 
			ON CCMP1.ParentCostCenterID=CCMP.ParentCostCenterID AND CCMP1.CostCenterID=CCMP.CostCenterID AND CCMP1.NodeID=CCMP.NodeID
			where CCMP.ParentCostCenterID=@CostCenterID  and CCMP.ParentNodeID=@ToID and CCMP1.ParentNodeID=@FromID

			DELETE CCMP1 from COM_CostCenterCostCenterMap CCMP WITH(NOLOCK)
			JOIN COM_CostCenterCostCenterMap CCMP1 WITH(NOLOCK) 
			ON CCMP1.ParentCostCenterID=CCMP.ParentCostCenterID AND CCMP1.CostCenterID=CCMP.CostCenterID AND CCMP1.ParentNodeID=CCMP.ParentNodeID
			where CCMP.CostCenterID=@CostCenterID  and CCMP.NodeID=@ToID and CCMP1.NodeID=@FromID
		
			update COM_CostCenterCostCenterMap 
			set ParentNodeID=@ToID
			where ParentCostCenterID=@CostCenterID and ParentNodeID=@FromID
			
			update COM_CostCenterCostCenterMap 
			set NodeID=@ToID
			where CostCenterID=@CostCenterID and NodeID=@FromID 
		end
	
	end
	
	if(@Contacts=1)
	begin
		if(select count(*) from COM_Contacts WITH(NOLOCK) where FeatureID=@CostCenterID and FeaturePK=@ToID)>0
		begin
			update COM_Contacts 
			set AddressTypeID=2,FeaturePK=@ToID
			where FeatureID=@CostCenterID and FeaturePK=@FromID
		end
		else
		begin
			update COM_Contacts 
			set FeaturePK=@ToID
			where FeatureID=@CostCenterID and FeaturePK=@FromID
		end
	end
	
	if(@Adress=1)
	begin
		if(select count(*) from COM_Address WITH(NOLOCK) where FeatureID=@CostCenterID and FeaturePK=@ToID)>0
		begin
			update COM_Address 
			set AddressTypeID=2,FeaturePK=@ToID
			where FeatureID=@CostCenterID and FeaturePK=@FromID
		end
		else
		begin
			update COM_Address 
			set FeaturePK=@ToID
			where FeatureID=@CostCenterID and FeaturePK=@FromID
		end
	end
	
	if(@Notes=1)
	begin
		update COM_Notes 
		set FeaturePK=@ToID
		where FeatureID=@CostCenterID and FeaturePK=@FromID
	end
	
	if(@Attachments=1)
	begin
		update COM_Files 
		set FeaturePK=@ToID
		where FeatureID=@CostCenterID and FeaturePK=@FromID
	end
	
	if(@Activities=1)
	begin
		SET @SQL='update CRM_Activities 
		set NodeID='+CONVERT(NVARCHAR,@ToID)+'
		where CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' and NodeID='+CONVERT(NVARCHAR,@FromID)
		EXEC (@SQL)
	end
	
		
COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=106 AND LanguageID=@LangID
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		 SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		 FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
