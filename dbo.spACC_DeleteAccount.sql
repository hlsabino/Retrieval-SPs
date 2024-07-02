USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_DeleteAccount]
	@AccountID [int] = 0,
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted INT,@lft INT,@rgt INT,@Width INT,@ActionType INT,@UserName NVARCHAR(50)
		DECLARE @HasRecord INT,@CCID int,@ErrorMsg nvarchar(max)

		--SP Required Parameters Check
		if(@AccountID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,2,4)
		SET @ActionType=4
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

		IF EXISTS(SELECT AccountID FROM ACC_Accounts with(nolock) WHERE (AccountID=@AccountID AND IsUserDefined=0) 
				 OR (ParentID=@AccountID AND IsUserDefined=0))
		BEGIN
			RAISERROR('-115',16,1)
		END
		
		IF not exists(SELECT  FeatureTypeID FROM ADM_FeatureTypeValues with(nolock) where FeatureTypeID IN (SELECT AccountTypeID FROM ACC_Accounts with(nolock) WHERE ACCOUNTID=@AccountID)
		and FeatureID=2 and (userid =@UserID or roleid=@RoleID))
		BEGIN     
			RAISERROR('-105',16,1)  
		 END
		 IF not exists(SELECT  FeatureTypeID FROM ADM_FeatureTypeValues with(nolock) where FeatureTypeID IN (SELECT AccountTypeID FROM ACC_Accounts with(nolock) WHERE ACCOUNTID=@AccountID)
		and FeatureID=2 and (roleid=@RoleID))
		BEGIN     
			RAISERROR('-105',16,1)  
		END

		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=@AccountID
		
		create table #tmpACC (id int identity(1,1),AccountID INT, ConvertFromCustomerID INT)
	
		if @AccountID>0
		begin
			if exists(SELECT * FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=@AccountID and IsGroup=1)
			BEGIN
				insert into #tmpACC
				select AccountID,ConvertFromCustomerID from ACC_Accounts with(nolock) WHERE lft >= @lft AND rgt <= @rgt
			END
			else
			BEGIN
				insert into #tmpACC
				select AccountID,ConvertFromCustomerID from ACC_Accounts with(nolock) WHERE AccountID=@AccountID
			END
		end
		else
		begin
			insert into #tmpACC
			select AccountID,ConvertFromCustomerID from ACC_Accounts with(nolock) WHERE AccountID=@AccountID
			
			delete from ADM_OfflineOnlineIDMap where CostCenterID=2 and OfflineID=@AccountID
		end
		
		if exists(select name from sys.tables where name='Crm_Customer')
		begin
			 --Added to update customer master if converted account is deleted
			declare @a int, @cnt1 int,@CusId INT
			select @a=1,@cnt1=count(*) from #tmpACC with(nolock)  
			while @a<=@cnt1
			begin
				select @CusId=ConvertFromCustomerID from #tmpACC with(nolock) where id=@a 
				if(@CusId>0)
				begin
					set @ErrorMsg='update Crm_Customer set StatusID=393 where customerid='+convert(nvarchar(max),@CusId)
					exec (@ErrorMsg)
				end
				set @a=@a+1
			end
		end
		set @ErrorMsg=''
		/*****Check Refrences here****/		 
		if @AccountID>0
		begin
			set @HasRecord=0
			--ACC_DocDetails(Documents)
			select top 1 @HasRecord=DebitAccount,@ErrorMsg=VoucherNo FROM ACC_DocDetails with(nolock) WHERE DebitAccount in (select AccountID from #tmpACC with(nolock))
			if(@HasRecord!=0)
			begin
				set @ErrorMsg='Account used in Document "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			select top 1 @HasRecord=CreditAccount,@ErrorMsg=VoucherNo FROM ACC_DocDetails with(nolock) WHERE CreditAccount in (select AccountID from #tmpACC with(nolock))
			if(@HasRecord!=0)
			begin
				set @ErrorMsg='Account used in Document "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			--INV_DocDetails(Documents)
			select top 1 @HasRecord=DebitAccount,@ErrorMsg=VoucherNo FROM INV_DocDetails with(nolock) WHERE DebitAccount in (select AccountID from #tmpACC with(nolock))
			if(@HasRecord!=0)
			begin
				set @ErrorMsg='Account used in Document "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			select top 1 @HasRecord=CreditAccount,@ErrorMsg=VoucherNo FROM INV_DocDetails with(nolock) WHERE CreditAccount in (select AccountID from #tmpACC with(nolock))
			if(@HasRecord!=0)
			begin
				set @ErrorMsg='Account used in Document "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			--COM_CCCCDATA
			select top 1 @CCID=CostCenterID,@HasRecord=NodeID FROM COM_CCCCDATA with(nolock) WHERE AccountID in (select AccountID from #tmpACC with(nolock))
			if(@HasRecord>0)
			begin
			
				EXEC [spCOM_GetErrorMsg] @CCID,@HasRecord,'Account used in ',@ErrorMsg output
				RAISERROR(@ErrorMsg,16,1)
			end
			--PriceChart & TaxChart
			select top 1 @HasRecord=T.AccountID,@ErrorMsg=ProfileName FROM COM_CCPrices C with(nolock) inner join #tmpACC T with(nolock) ON T.AccountID=C.AccountID
			if(@HasRecord>0)
			begin
				set @ErrorMsg='Account used in Price chart "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			select top 1 @HasRecord=T.AccountID,@ErrorMsg=ProfileName FROM COM_CCTaxes C with(nolock) inner join #tmpACC T with(nolock) ON T.AccountID=C.AccountID
			if(@HasRecord>0)
			begin
				set @ErrorMsg='Account used in Tax chart "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			--Budget
			select top 1 @HasRecord=C.BudgetDefID FROM COM_BudgetAlloc C with(nolock) inner join #tmpACC T with(nolock) ON T.AccountID=C.AccountID
			if(@HasRecord>0)
			begin
				select @ErrorMsg='Account used in Budget "'+BudgetName+'"' from COM_BudgetDef with(nolock) where BudgetDefID=@HasRecord
				RAISERROR(@ErrorMsg,16,1)
			end
			--Document Definition
			select top 1 @HasRecord=CostCenterID FROM (
			SELECT DISTINCT C.CostCenterID FROM ADM_DocumentDef C with(nolock) inner join #tmpACC T with(nolock) ON T.AccountID=C.DebitAccount
			UNION
			SELECT DISTINCT C.CostCenterID FROM ADM_DocumentDef C with(nolock) inner join #tmpACC T with(nolock) ON T.AccountID=C.CreditAccount
			) AS T
			if(@HasRecord>0)
			begin
				select @ErrorMsg=@ErrorMsg+':'+DocumentName from adm_documenttypes with(nolock) 
				where CostcenterID IN (select top 10 CostCenterID FROM (
				SELECT DISTINCT C.CostCenterID FROM ADM_DocumentDef C with(nolock) inner join #tmpACC T with(nolock) ON T.AccountID=C.DebitAccount
				UNION
				SELECT DISTINCT C.CostCenterID FROM ADM_DocumentDef C with(nolock) inner join #tmpACC T with(nolock) ON T.AccountID=C.CreditAccount
				) AS T)
				SELECT @ErrorMsg='Account used in Document Definition of '+@ErrorMsg
				RAISERROR(@ErrorMsg,16,1)
			end
			--CostCenter Definition
			select top 1 @HasRecord=CostCenterColID,@ErrorMsg=CostCenterName from ADM_CostCenterDef with(nolock) where SysColumnName like '%Account%' and [CostCenterID]>2
				and UserDefaultValue is not null and isnumeric(UserDefaultValue)=1 and convert(int,UserDefaultValue)>0 and UserDefaultValue IN (select AccountID from #tmpACC with(nolock))
			if(@HasRecord>0)
			begin
				set @ErrorMsg='Account used in CostCenter Definition of "'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			
			select top 1 @HasRecord=ISNULL(COUNT(*),0),@ErrorMsg=ISNULL(MAX(AccountName),'') from ACC_Accounts with(nolock) where PDCReceivableAccount IN (select AccountID from #tmpACC with(nolock))
			GROUP BY AccountID
			if(@HasRecord>0)
			begin
				set @ErrorMsg='Account used AS PDC Receivable in Account:"'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			select top 1 @HasRecord=ISNULL(COUNT(*),0),@ErrorMsg=ISNULL(MAX(AccountName),'') from ACC_Accounts with(nolock) where PDCPayableAccount IN (select AccountID from #tmpACC with(nolock))
			GROUP BY AccountID
			if(@HasRecord>0)
			begin
				set @ErrorMsg='Account used AS PDC Payable in Account:"'+@ErrorMsg+'"'
				RAISERROR(@ErrorMsg,16,1)
			end
			--Open Company Data
			if exists (select T.AccountID FROM ADM_FinancialYears C with(nolock) inner join #tmpACC T with(nolock) ON T.AccountID=C.AccountID)
				RAISERROR('Account used in Open Company Data',16,1)
		end
		
		--ondelete External function
		IF (@AccountID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=2 and Mode=8
			if(@tablename<>'')
				exec @tablename 2,@AccountID,'',@UserID,@LangID	
		END	
		
		SELECT @UserName=USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE UserID=@UserID
		
		declare @i int, @cnt int
		DECLARE @NodeID INT, @Dimesion INT 
		DECLARE @CostCntID INT,@NID INT,@sSQL NVARCHAR(MAX),@UsrName NVARCHAR(MAX),@StatusID INT
			
		select @i=1,@cnt=count(*) from #tmpACC with(nolock)
		while @i<=@cnt
		begin
			select @NodeID=AccountID from #tmpACC with(nolock) where id=@i
			
			--INSERT INTO HISTROY   
			EXEC [spCOM_SaveHistory]  
				@CostCenterID =2,    
				@NodeID =@NodeID,
				@HistoryStatus ='Deleted',
				@UserName=@UserName
			
			set @i=@i+1
		end
		
		
		--ondelete External function
		declare @spname nvarchar(200)
		set @spname=''
		select @spname=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=2 and Mode=8
		if(@spname<>'')
			exec @spname 2,@AccountID,'',@UserID,@LangID
		--
		
		Delete from ACC_ReportTemplate WHERE AccountID in (select AccountID from #tmpACC with(nolock))
		
		--Delete from exteneded table
		DELETE FROM ACC_AccountsExtended WHERE AccountID in (select AccountID from #tmpACC with(nolock))

		--Delete from Contacts
		DELETE FROM  COM_ContactsExtended
		WHERE ContactID IN (SELECT CONTACTID FROM COM_CONTACTS WITH(NOLOCK) WHERE FeatureID=2 and FeaturePK IN (select AccountID from #tmpACC with(nolock)))
		DELETE FROM  COM_Contacts 
		WHERE FeatureID=2 and  FeaturePK in (select AccountID from #tmpACC with(nolock))

		--Delete Assign/Map Data
		DELETE FROM COM_CostCenterCostCenterMap WHERE CostCenterID=2 and NodeID in (select AccountID from #tmpACC with(nolock))
		DELETE FROM COM_CostCenterCostCenterMap WHERE ParentCostCenterID=2 and ParentNodeID in (select AccountID from #tmpACC with(nolock))
			
		--Delete from Notes
		DELETE FROM  COM_Notes 
		WHERE FeatureID=2 and  FeaturePK IN (select AccountID from #tmpACC with(nolock))

		--Delete from Files
		DELETE FROM  COM_Files  
		WHERE FeatureID=2 and  FeaturePK IN (select AccountID from #tmpACC with(nolock))

		--Delete from CostCenter Mapping
		DELETE FROM COM_CCCCDATA WHERE CostCenterID=2 and NodeID IN (select AccountID from #tmpACC with(nolock))
		
		--Delete CostCenter Hisory
		DELETE FROM COM_HistoryDetails where CostCenterID=2 and NodeID IN (select AccountID from #tmpACC with(nolock))
		
		--Delete Status Hisory
		DELETE FROM COM_CostCenterStatusMap where CostCenterID=2 and NodeID IN (select AccountID from #tmpACC with(nolock))
			
		select @i=1,@cnt=count(*) from #tmpACC with(nolock)
		while @i<=@cnt
		begin
			set @NodeID=0
			set @Dimesion=0
			select  @NodeID = CCNodeID, @Dimesion=CCID from ACC_Accounts with(nolock) where AccountID in
			(select AccountID from #tmpACC with(nolock) where id=@i)
			if (@NodeID is not null and @NodeID>0)
			begin
				Update Acc_accounts set CCID=0, CCNodeID=0 where AccountID in
				(select AccountID from #tmpACC with(nolock) where id=@i)
				declare @return_value INT
			
		
				EXEC	@return_value = [dbo].[spCOM_DeleteCostCenter]
					@CostCenterID = @Dimesion,
					@NodeID = @NodeID,
					@RoleID=1,
					@UserID = 1,
					@LangID = @LangID,
					@CheckLink = 0
							
				--Deleting from Mapping Table
				Delete from com_docbridge WHERE CostCenterID = 2 AND RefDimensionNodeID = @NodeID AND RefDimensionID = 	@Dimesion
		 
			end
			set @i=@i+1
		end
		
		--Delete user from adm_users while deleting account (vendor portal)
		select @i=0,@cnt=count(*) from #tmpACC with(nolock)
		while @i<=@cnt
		begin
			select  @CostCntID=CostCenterID,@NID=NodeID from COM_DocBridge  with(nolock) where RefDimensionID=2 and RefDimensionNodeID in (select AccountID from #tmpACC with(nolock) where id=@i)
			IF(@CostCntID=50170)
			BEGIN
				SET @UsrName=''
				IF EXISTS(SELECT USERCOLUMNNAME FROM ADM_COSTCENTERDEF WHERE COSTCENTERID=@CostCntID AND SYSCOLUMNNAME='UserNameAlpha')
				BEGIN
					SET @sSQL='select @str=UserNameAlpha from COM_CC'+convert(varchar,@CostCntID)+' where NodeID='+CONVERT(VARCHAR,@NID)
					EXEC sp_executesql @sSQL,N'@str varchar(max) OUTPUT',@UsrName OUTPUT
					IF(ISNULL(@UsrName,'')<>'')
					BEGIN
						DELETE FROM ADM_USERS WHERE USERNAME=@UsrName
						DELETE FROM COM_DocBridge WHERE CostCenterID=@CostCntID AND NodeID=@NID 
						SELECT @StatusID=StatusID FROM COM_STATUS WHERE COSTCENTERID=@CostCntID AND STATUS='Active'
						SET @sSQL=''
						SET @sSQL='Update COM_CC'+CONVERT(VARCHAR,@CostCntID)+' Set StatusID='+ CONVERT(VARCHAR,@StatusID) +' where NodeID='+ CONVERT(VARCHAR,@NID) +''
						--PRINT (@sSQL)
						EXEC (@sSQL)
					END
				 END
			END
		set @i=@i+1
		end	  
		--Delete from main table
		DELETE FROM ACC_Accounts WHERE AccountID IN (select AccountID from #tmpACC with(nolock))

		SET @RowsDeleted=@@rowcount

		--Update left and right extent to set the tree
		UPDATE ACC_Accounts SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE ACC_Accounts SET lft = lft - @Width WHERE lft > @rgt;
			--Deleting from Mapping Table
		--Delete from com_docbridge WHERE CostCenterID = 2 AND NodeID = @PropertyID
		
		
		delete from Acc_CreditDebitAmount where AccountID IN (select AccountID from #tmpACC with(nolock))
		DROP TABLE #tmpACC
		
		----Insert Notifications
		--EXEC spCOM_SetNotifEvent @ActionType,2,@AccountID,'',@UserName,@UserID,-1
			
COMMIT TRANSACTION
--ROLLBACK TRANSACTION
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN @RowsDeleted
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		if isnumeric(ERROR_MESSAGE())=1
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		else
			SELECT ERROR_MESSAGE() ErrorMessage,-1 ErrorNumber
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
	END
	ELSE 
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
	BEGIN TRY
		ROLLBACK TRANSACTION
	END TRY
	BEGIN CATCH 
	END CATCH 
	
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
