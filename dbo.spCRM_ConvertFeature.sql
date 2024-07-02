USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_ConvertFeature]
	@CCID [int] = 0,
	@CCNodeID [int] = 0,
	@ACCOUNT [bit] = 0,
	@AccountContacts [bit] = 0,
	@AccountAddress [bit] = 0,
	@AccountAssign [bit] = 0,
	@PRODUCT [bit] = 0,
	@CompanyGUID [nvarchar](100),
	@UserName [nvarchar](100),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY 
SET NOCOUNT ON		

	DECLARE @Dt float
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT
	DECLARE @SelectedIsGroup bit ,@SelectedNodeID INT,@IsGroup BIT
	DECLARE @Code NVARCHAR(300),@CompanyName nvarchar(500),@AccountID INT
	DECLARE @COUNT INT,@I INT,@SOURCEDATA NVARCHAR(MAX),@DESTDATA NVARCHAR(MAX),@SQL NVARCHAR(MAX)
			
			
	set @Dt=CONVERT(float,getdate())
    --INSERT INTO ACCOUNTS TABLE
	IF(@ACCOUNT=1)
	BEGIN 
		IF  NOT EXISTS (SELECT ConvertFromCustomerID FROM ACC_ACCOUNTS WITH(nolock) WHERE ConvertFromCustomerID=@CCNodeID)  
		BEGIN  
			CREATE TABLE #TBLTEMP(ID  INT IDENTITY(1,1),BASECOLUMN NVARCHAR(300),LINKCOLUMN NVARCHAR(300))
			INSERT INTO #TBLTEMP
			select DISTINCT l.SysColumnName,b.SysColumnName 
			from COM_DocumentLinkDetails dl WITH(nolock)
			left join ADM_CostCenterDef b WITH(nolock) on dl.CostCenterColIDBase=b.CostCenterColID
			left join ADM_CostCenterDef l WITH(nolock) on dl.CostCenterColIDLinked=l.CostCenterColID
			where DocumentLinkDeFID in (select DocumentLinkDeFID from COM_DocumentLinkDef  WITH(nolock) where CostCenterIDBase=83)
			and l.costcenterid=2
		
			SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP WITH(nolock)
			
			IF (@COUNT>0)
			BEGIN
				SELECT @SelectedNodeID=isnull(VALUE,1) FROM COM_COSTCENTERPREFERENCES WITH(nolock) 
				WHERE NAME='ConvertedAccountGroup' and costcenterid=83
				
				--To Set Left,Right And Depth of Record
				SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=isnull(ParentID,1),@Depth=isnull(Depth,1)
				from ACC_ACCOUNTS with(NOLOCK) where ACCOUNTID=@SelectedNodeID
				
				--IF No Record Selected or Record Doesn't Exist
				if(@SelectedIsGroup is null) 
					select @SelectedNodeID=ACCOUNTID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth
					from ACC_ACCOUNTS with(NOLOCK) where ParentID =0

				if(@SelectedIsGroup = 1)--Adding Node Under the Group
				BEGIN
					UPDATE ACC_ACCOUNTS SET rgt = rgt + 2 WHERE rgt > @Selectedlft;
					UPDATE ACC_ACCOUNTS SET lft = lft + 2 WHERE lft > @Selectedlft;
					set @lft =  @Selectedlft + 1
					set @rgt = @Selectedlft + 2
					set @ParentID = @SelectedNodeID
					set @Depth = @Depth + 1
				END
				else if(@SelectedIsGroup = 0)--Adding Node at Same level
				BEGIN
					UPDATE ACC_ACCOUNTS SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;
					UPDATE ACC_ACCOUNTS SET lft = lft + 2 WHERE lft > @Selectedrgt;
					set @lft =  @Selectedrgt + 1
					set @rgt = @Selectedrgt + 2 
				END
				else  --Adding Root
				BEGIN
					set @lft =  1
					set @rgt = 2 
					set @Depth = 0
					set @ParentID =0
					set @IsGroup=1
				END
				
				SET @IsGroup=0

				--FIRST INSERT INTO MAIN TABLE 
				SET @DESTDATA=''
				SET @SOURCEDATA=''
		
				SET @SOURCEDATA=' INSERT INTO ACC_ACCOUNTS (AccountTypeID,StatusID,ConvertFromCustomerID,'
				SET @DESTDATA='SELECT 7,33,'+CONVERT(NVARCHAR(300),@CCNodeID) +','
			
				WHILE @I<=@COUNT
				BEGIN
					IF(exists (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I and 
					(BASECOLUMN NOT likE '%CCNID%' AND BASECOLUMN NOT likE '%acAlpha%' AND
					LINKCOLUMN NOT likE '%CCNID%' AND LINKCOLUMN NOT likE '%cuAlpha%')))
					begin 
						SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)
						
						IF((SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)='Company')
							SET @DESTDATA =@DESTDATA + 'CRM_Customer.'+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)   
						else
						   SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)
						
						BEGIN
							SET @SOURCEDATA =@SOURCEDATA + ','
							SET @DESTDATA =@DESTDATA + ','
						END 
					end	  
					SET @I=@I+1
				END
				
				IF(LEN(@SOURCEDATA)>0)
				BEGIN
					SET @SOURCEDATA=SUBSTRING(@SOURCEDATA,1,LEN(@SOURCEDATA)-1)	
					SET @DESTDATA=SUBSTRING(@DESTDATA,1,LEN(@DESTDATA)-1)	
				END 
				 
				set @SOURCEDATA=@SOURCEDATA+ ',[IsBillwise],[CreditDays],[CreditLimit],  [DebitDays],  [DebitLimit], [Depth], [ParentID],  [lft],  [rgt],  [IsGroup],[CompanyGUID],  [GUID],  [CreatedBy],  [CreatedDate] )'  		
				set @DESTDATA=@DESTDATA + + ',1,0,0,0,0,' + CONVERT(NVARCHAR(300),@Depth) + ',' +CONVERT(NVARCHAR(300),@ParentID) + ',' +CONVERT(NVARCHAR(300),@lft)+ ',' + 
				CONVERT(NVARCHAR(300),@rgt) + ',' + CONVERT(NVARCHAR(300),@IsGroup) + ',''' + CONVERT(NVARCHAR(300),@CompanyGUID) + ''',' + 'newid()'
				+ ',CRM_Customer.CreatedBy' +  ', CRM_Customer.createddate' 
				
				SET  @SOURCEDATA=@SOURCEDATA +  @DESTDATA + ' FROM CRM_Customer  WITH(nolock) 
				LEFT JOIN CRM_CustomerExtended  WITH(nolock) ON CRM_CustomerExtended.CustomerID=CRM_Customer.CustomerID 
				LEFT JOIN COM_Contacts  WITH(nolock) ON COM_Contacts.FEATUREPK='+CONVERT(NVARCHAR(300),@CCNodeID)+' AND COM_Contacts.FEATUREID=83  AND COM_Contacts.AddressTypeID=1
				WHERE CRM_Customer.CustomerID='+CONVERT(NVARCHAR(300),@CCNodeID)
				
				EXEC sp_executesql @SOURCEDATA 
				
				SELECT @AccountID=ACCOUNTID FROM ACC_ACCOUNTS WITH(nolock) WHERE ConvertFromCustomerID=@CCNodeID
			 
				IF(@AccountID IS NOT NULL)
				BEGIN 
					--Check duplicate
					exec spACC_CheckDuplicate @AccountID
					
					--Handling of Extended Table  
					INSERT INTO [ACC_AccountsExtended]([AccountID],[CreatedBy],[CreatedDate])  
					VALUES(@AccountID, @UserName, @Dt)  
					
					if exists (select * from #TBLTEMP WITH(nolock) where BASECOLUMN likE '%acAlpha%' AND LINKCOLUMN  likE '%cuAlpha%')
					BEGIN
						set @SQL='update [ACC_AccountsExtended] set ' 
						SET @SOURCEDATA=''
						SET @DESTDATA=''
						
						SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP WITH(nolock)
					
						WHILE @I<=@COUNT  
						BEGIN   
						 
							IF(exists (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I and 
							(BASECOLUMN likE '%acAlpha%' AND LINKCOLUMN  likE '%cuAlpha%')))
							BEGIN  
								SET @SOURCEDATA=''
								SET @DESTDATA=''
								SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I) 
								SET @SQL=@SQL+   @SOURCEDATA
								IF((SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)='Company')
									SET @DESTDATA =@DESTDATA + 'CRM_Customer.'+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)   
								 else
								   SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)
								  
								SET @SQL=@SQL+ '= cus.'+@DESTDATA  
								SET @SQL =@SQL + ','
								 
							END	  
							SET @I=@I+1
						END
				
					 
						set @SQL=@SQL+ 'modifiedby='''+@UserName+''' from ACC_Accounts acc  WITH(nolock) 
						JOIN ACC_AccountsExtended EXT WITH(nolock) ON ACC.ACCOUNTID=EXT.ACCOUNTID
						left join CRM_CustomerExtended cus WITH(nolock) on acc.ConvertFromCustomerID=cus.CustomerID
						WHERE ACC.ACCOUNTID='+CONVERT(NVARCHAR(100),@AccountID)+' AND ACC.ConvertFromCustomerID='+CONVERT(NVARCHAR(100),@CCNodeID)
						+' AND EXT.AccountID=ACC.ACCOUNTID'
						
						EXEC sp_executesql @SQL
					end  
					
					--INSERT INTO HISTROY   
					EXEC [spCOM_SaveHistory]  
						@CostCenterID =2,    
						@NodeID =@AccountID,
						@HistoryStatus ='Update',
						@UserName=@UserName,
						@Dt=@Dt
						
						set @SOURCEDATA=''
						select @SOURCEDATA=@SOURCEDATA+','+name
						from sys.columns WITH(NOLOCK)
						where object_id=object_id('COM_CCCCData') and name LIKE 'CCNID%'
		
						SET @SQL='INSERT INTO COM_CCCCData(CostCenterID,NodeID,CCNodeID,GUID,CreatedBy,CreatedDate'+@SOURCEDATA+')
						select 2,'+CONVERT(NVARCHAR,@AccountID)+',CCNodeID,newid(),'''+ @UserName+''','+CONVERT(NVARCHAR,@Dt)+@SOURCEDATA+' 
						from COM_CCCCDATA WITH(nolock) where [CostCenterID]=83 and [NodeID]='+CONVERT(NVARCHAR,@CCNodeID)
					    
					    EXEC sp_executesql @SQL
						
						CREATE TABLE #TBL(ID INT IDENTITY(1,1),NodeID INT) 
						
						IF @AccountContacts=1
						BEGIN 
							DECLARE @CONTACTIDENTITY INT,@CONTACTID INT
							TRUNCATE TABLE #TBL
							INSERT INTO #TBL
							SELECT CONTACTID FROM  COM_CONTACTS WITH(nolock) WHERE FEATUREID=83 AND FEATUREPK=@CCNodeID --AND ADDRESSTYPEID=2
							
							set @DESTDATA=''
							select @DESTDATA=@DESTDATA+','+name
							from sys.columns WITH(NOLOCK)
							where object_id=object_id('COM_ContactsExtended') and name LIKE 'acAlpha%'
						
							SELECT @I=1, @COUNT=COUNT(*) FROM #TBL WITH(nolock) 			
							WHILE @I<=@COUNT
							BEGIN 
								SELECT @CONTACTID=NodeID FROM #TBL WITH(nolock) WHERE ID=@I
								
								INSERT INTO COM_CONTACTS([AddressTypeID],[FeatureID],[FeaturePK],[ContactName],[Address1],[Address2],[Address3],[City]        ,[State]        ,[Zip]        ,[Country]        ,[Phone1]        ,[Phone2]        ,[Fax]        ,[Email1]        ,[Email2]        ,[URL]        ,[CompanyGUID]        ,[GUID]        ,[Description]        ,[CreatedBy]        ,[CreatedDate]        ,[ModifiedBy]        ,[ModifiedDate]        ,[CostCenterID]        ,[ContactTypeID]        ,[FirstName]        ,[MiddleName]        ,[LastName]        ,[SalutationID]        ,[JobTitle]        ,[Company]        ,[StatusID]        ,[Department]        ,[RoleLookUpID]        ,[Gender]        ,[BirthDay]        ,[Anniversary]        ,[PreferredID]        ,[PreferredName]        ,[IsEmailOn]        ,[IsBulkEmailOn]        ,[IsMailOn]        ,[IsPhoneOn]        ,[IsFaxOn]        ,[IsVisible]        ,[Depth]        ,[ParentID]        ,[lft]        ,[rgt]        ,[IsGroup]        ,[ConvertFromLeadID])
								SELECT ADDRESSTYPEID,2,@AccountID,[ContactName] ,[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1]        ,[Phone2]        ,[Fax]        ,[Email1]        ,[Email2]        ,[URL]        ,[CompanyGUID]        ,[GUID]        ,[Description]        ,[CreatedBy]        ,[CreatedDate]        ,[ModifiedBy]        ,[ModifiedDate]        ,89        ,[ContactTypeID]        ,[FirstName]        ,[MiddleName]        ,[LastName]        ,[SalutationID]        ,[JobTitle]        ,[Company]        ,[StatusID]        ,[Department]        ,[RoleLookUpID]        ,[Gender]        ,[BirthDay]        ,[Anniversary]        ,[PreferredID]        ,[PreferredName]        ,[IsEmailOn]        ,[IsBulkEmailOn]        ,[IsMailOn]        ,[IsPhoneOn]        ,[IsFaxOn]        ,[IsVisible]        ,[Depth]        ,[ParentID]        ,[lft]        ,[rgt]        ,[IsGroup]        ,[ConvertFromLeadID] 
								FROM COM_CONTACTS WITH(nolock) WHERE CONTACTID=@CONTACTID
								SET @CONTACTIDENTITY=SCOPE_IDENTITY()
								
								
								SET @SQL='INSERT INTO [COM_ContactsExtended]([ContactID],[CreatedBy],[CreatedDate]'+@DESTDATA+')
								SELECT '+CONVERT(NVARCHAR,@CONTACTIDENTITY)+','''+ @UserName+''','+CONVERT(NVARCHAR,@Dt)+@DESTDATA+' 
								FROM [COM_ContactsExtended] WITH(nolock) WHERE CONTACTID='+CONVERT(NVARCHAR,@CONTACTID)
								EXEC sp_executesql @SQL
								
								SET @SQL='INSERT INTO COM_CCCCData(CostCenterID,NodeID,CCNodeID,GUID,CreatedBy,CreatedDate'+@SOURCEDATA+')
								select CostCenterID,'+CONVERT(NVARCHAR,@CONTACTIDENTITY)+',CCNodeID,newid(),'''+ @UserName+''','+CONVERT(NVARCHAR,@Dt)+@SOURCEDATA+' 
								from COM_CCCCDATA WITH(nolock) where [CostCenterID]=65 and [NodeID]='+CONVERT(NVARCHAR,@CONTACTID)
								EXEC sp_executesql @SQL
								
								SET @I=@I+1
							END
							
						END 
						
						IF @AccountAddress=1
						BEGIN 
							DECLARE @ADDRESSIDENTITY INT
							TRUNCATE TABLE #TBL
							INSERT INTO #TBL
							SELECT AddressID FROM  COM_Address WITH(nolock) WHERE FEATUREID=83 AND FEATUREPK=@CCNodeID --AND ADDRESSTYPEID=2
							
							set @DESTDATA=''
							select @DESTDATA=@DESTDATA+','+name
							from sys.columns WITH(NOLOCK)
							where object_id=object_id('COM_Address') and (name LIKE 'Alpha%' OR name LIKE 'CCNID%')
							
							SELECT @I=1, @COUNT=COUNT(*) FROM #TBL WITH(nolock) 			
							WHILE @I<=@COUNT
							BEGIN 
								SET @SQL='INSERT INTO [COM_Address] ([ContactPerson],[AddressTypeID],[FeatureID],[FeaturePK],[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1],[Phone2],[Fax],[Email1],[Email2],[URL],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[CostCenterID],[AddressName]'+@DESTDATA+')
								SELECT ContactPerson,AddressTypeID,2,'+CONVERT(NVARCHAR,@AccountID)+',[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1],[Phone2],[Fax],[Email1],[Email2],[URL],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[CostCenterID],[AddressName]'+@DESTDATA+'
								FROM COM_Address WITH(nolock) WHERE AddressID IN (SELECT NodeID FROM #TBL WITH(nolock) WHERE ID='+CONVERT(NVARCHAR,@I)+')
								SET @ADDRESSIDENTITY=SCOPE_IDENTITY()'
								EXEC sp_executesql @SQL,N'@ADDRESSIDENTITY INT OUTPUT',@ADDRESSIDENTITY OUTPUT								
								
								INSERT INTO [COM_Address_History]
								SELECT * FROM COM_Address WITH(nolock) 
								WHERE AddressID=@ADDRESSIDENTITY
								
								 SET @I=@I+1
							END
						END
						
						IF @AccountAssign=1
						BEGIN 
							DECLARE @ASSIGNDENTITY INT
							TRUNCATE TABLE #TBL
							INSERT INTO #TBL
							SELECT CCCCMapID FROM  COM_CostCenterCostCenterMap WITH(nolock) WHERE ParentCostCenterID=83 AND ParentNodeID=@CCNodeID 
							
							SELECT @I=1, @COUNT=COUNT(*) FROM #TBL WITH(NOLOCK) 			
							WHILE @I<=@COUNT
							BEGIN 
								INSERT INTO [COM_CostCenterCostCenterMap] ([ParentCostCenterID],[ParentNodeID],[CostCenterColID],[CostCenterID],[NodeID],[GUID],[Description],[CreatedBy],[CreatedDate],[CompanyGuid])
								SELECT 2,@AccountID,NULL,[CostCenterID],[NodeID],[GUID],[Description],@UserName,@dt,[CompanyGuid] 
								FROM COM_CostCenterCostCenterMap WITH(NOLOCK) 
								WHERE CCCCMapID IN (SELECT NodeID FROM #TBL WITH(NOLOCK) WHERE ID=@I)
								 
								SET @I=@I+1
							END
						END
						drop table #TBL
						UPDATE CRM_Customer SET [STATUSID]=442  WHERE CustomerID=@CCNodeID
					END
				END
			END
		END
	
	-------------INSERT INTO PRODUCT TABLE
	IF(@PRODUCT=1)
	BEGIN
		IF  NOT EXISTS (SELECT ConvertedCRMProduct FROM INV_Product WITH(nolock) WHERE ConvertedCRMProduct=@CCNodeID)  
		BEGIN  
			SELECT 	@SOURCEDATA=TABLENAME FROM ADM_FEATURES WITH(nolock) WHERE FEATUREID=@CCID
			
			SET @SQL=' select @CODE=CODE  from '+@SOURCEDATA+' WITH(nolock) WHERE NODEID='+CONVERT(NVARCHAR(300),@CCNodeID)
			EXEC sp_executesql @SQL,N'@CODE NVARCHAR(300) OUTPUT',@CODE OUTPUT  
			
			SET @SQL=' select @CompanyName=NAME  from '+@SOURCEDATA+' WITH(nolock) WHERE NODEID='+CONVERT(NVARCHAR(300),@CCNodeID)
			EXEC sp_executesql @SQL,N'@CompanyName NVARCHAR(300) OUTPUT' ,@CompanyName OUTPUT  
			
			SELECT @SelectedNodeID=isnull(VALUE,1) FROM COM_COSTCENTERPREFERENCES WITH(nolock) 
			WHERE NAME='ConvertedProductGroup' and costcenterid=145    
			
			declare @UOM INT
			select @UOM=isnull(userdefaultvalue,1) from adm_costcenterdef WITH(nolock) 
			where costcentercolid=268
			
			IF @SelectedNodeID=0 OR @SelectedNodeID=NULL
				SET @SelectedNodeID=1
			
			DECLARE @return_value INT
			EXEC @return_value = [dbo].[spINV_SetProduct]
				@ProductID = 0,
				@ProductCode = @Code,
				@ProductName = @CompanyName,
				@AliasName=@CompanyName,
				@ProductTypeID=1,
				@StatusID =31,  	
				@UOMID=@UOM,
				@Description=@CompanyName,
				@SelectedNodeID = @SelectedNodeID,
				@IsGroup = 0,
				@CustomCostCenterFieldsQuery=NULL,
				@ContactsXML =NULL,
				@NotesXML =NULL,
				@AttachmentsXML =NULL,
				@BarcodeID =0,
				@CompanyGUID=@COMPANYGUID,
				@GUID='GUID',
				@UserName=@USERNAME,
				@UserID=@USERID
							
				UPDATE INV_Product
				SET ConvertedCRMProduct=@CCNodeID
				WHERE PRODUCTID=@return_value 
		END
	END
	 
	 
COMMIT TRANSACTION  
SET NOCOUNT OFF;   
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=103 AND LanguageID=@LangID 
RETURN 1
END TRY  
BEGIN CATCH  
 IF ERROR_NUMBER()=50000
 BEGIN
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
 END
 ELSE IF ERROR_NUMBER()=547
 BEGIN
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
  WHERE ErrorNumber=-110 AND LanguageID=@LangID
 END
 ELSE IF ERROR_NUMBER()=2627
 BEGIN
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
  WHERE ErrorNumber=-116 AND LanguageID=@LangID
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
