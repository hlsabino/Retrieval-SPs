USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_ConvertLead]
	@LEADID [int] = 0,
	@Opportunity [bit] = 0,
	@Contact [bit] = 0,
	@Customer [bit] = 0,
	@ACCOUNT [bit] = 0,
	@CustomerContacts [bit] = 0,
	@AccountContacts [bit] = 0,
	@LeadAddressDetails [bit] = 0,
	@CompanyGUID [nvarchar](100),
	@UserName [nvarchar](100),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY   
SET NOCOUNT ON  
	create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)  
	DECLARE @Dt float,@ParentCode nvarchar(200),@IsCodeAutoGen bit,@CodePrefix NVARCHAR(300),@CodeNumber INT  
	DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT  
	DECLARE @SelectedIsGroup bit , @DetailContactID INT,@SelectedNodeID INT,@IsGroup BIT  
	DECLARE @LeadCode NVARCHAR(300),@Code NVARCHAR(300),@OpportunityID INT,@CustomerID INT,@AccountID INT  
	DECLARE @CompanyName nvarchar(500),@Description nvarchar(500),@StatusName nvarchar(50),@ID INT  
	DECLARE @CONTACTSXML NVARCHAR(MAX),@ErrorNumber INT=0
	CREATE TABLE #TBLTEMP(ID  INT IDENTITY(1,1),BASECOLUMN NVARCHAR(300),LINKCOLUMN NVARCHAR(300))  
	CREATE TABLE #TBLCONTACTS(ID INT IDENTITY(1,1),CONTACTID INT)  

	SELECT @LeadCode=Code,@DetailContactID=ContactID,@CompanyName=Company,@Description=[Description]    
	FROM CRM_Leads WITH(nolock) WHERE LeadID=@LEADID  

	SET @Dt=convert(float,getdate())--Setting Current Date    

	SET @SelectedNodeID=1  
  
	------------INSERT INTO OPPORTUNITY TABLE  
	IF (@Opportunity = 1)  
	BEGIN  

		--To Set Left,Right And Depth of Record    
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
		from CRM_Opportunities with(NOLOCK) where OpportunityID=@SelectedNodeID    

		--IF No Record Selected or Record Doesn't Exist    
		if(@SelectedIsGroup is null)     
			select @SelectedNodeID=LeadID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
			from CRM_Opportunities with(NOLOCK) where ParentID =0    
              
		if(@SelectedIsGroup = 1)--Adding Node Under the Group    
		BEGIN    
			UPDATE CRM_Opportunities SET rgt = rgt + 2 WHERE rgt > @Selectedlft;    
			UPDATE CRM_Opportunities SET lft = lft + 2 WHERE lft > @Selectedlft;    
			set @lft =  @Selectedlft + 1    
			set @rgt = @Selectedlft + 2    
			set @ParentID = @SelectedNodeID    
			set @Depth = @Depth + 1    
		END    
		else if(@SelectedIsGroup = 0)--Adding Node at Same level    
		BEGIN    
			UPDATE CRM_Opportunities SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;    
			UPDATE CRM_Opportunities SET lft = lft + 2 WHERE lft > @Selectedrgt;    
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
		SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock)   
		WHERE COSTCENTERID=89 and  Name='CodeAutoGen'    
  
		--GENERATE CODE    
		IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1    
		BEGIN     
			--CALL AUTOCODEGEN   
			if(@SelectedNodeID is null)  
				insert into #temp1  
				EXEC [spCOM_GetCodeData] 89,1,''    
			else  
				insert into #temp1  
				EXEC [spCOM_GetCodeData] 89,@SelectedNodeID,''    
			select @Code=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 WITH(nolock)  
		END    
      
		---CHECKING AUTO GENERATE CODE  
		IF @Code='' OR @Code IS NULL   
			SET @Code=@LeadCode  
 
		IF NOT EXISTS (SELECT ConvertFromLeadID FROM CRM_Opportunities WITH(nolock) WHERE ConvertFromLeadID=@LEADID)    
		BEGIN    
			INSERT INTO #TBLTEMP  
			select l.SysColumnName, b.SysColumnName   
			from COM_DocumentLinkDetails dl WITH(nolock)  
			left join ADM_CostCenterDef b WITH(nolock) on dl.CostCenterColIDBase=b.CostCenterColID  
			left join ADM_CostCenterDef l WITH(nolock) on dl.CostCenterColIDLinked=l.CostCenterColID  
			where DocumentLinkDeFID in (select DocumentLinkDeFID from COM_DocumentLinkDef WITH(nolock) where CostCenterIDBase=86)  
			and l.costcenterid=89  
			 
			DECLARE @ACOUNT INT,@I INT,@TotalCount INT,@SOURCEDATA NVARCHAR(MAX),@DESTDATA NVARCHAR(MAX),@OPPSTATUSID INT  
     
			IF(EXISTS (SELECT * FROM COM_Lookup WITH(NOLOCK) WHERE LookupType=56 AND IsDefault=1))  
				SELECT @OPPSTATUSID=NODEID FROM COM_Lookup WITH(NOLOCK) WHERE LookupType=56 AND IsDefault=1  
			ELSE  
				SET @OPPSTATUSID=(SELECT TOP 1 NODEID FROM COM_Lookup WITH(NOLOCK) WHERE LookupType=56 ORDER BY NodeID)  

			select @TotalCount=COUNT(*) FROM #TBLTEMP  WITH(nolock)     
			
			DELETE FROM #TBLTEMP 
			WHERE LINKCOLUMN IN ('FirstName','Code','StatusID','MiddleName','LastName','JobTitle','Phone1','Phone2','Email1','Fax','Department','SalutationID')  
			alter table #TBLTEMP drop column id  
			alter table #TBLTEMP Add  ID int identity(1,1)  
			
			SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTEMP WITH(nolock)     
			IF (@OPPSTATUSID IS NULL OR @OPPSTATUSID=0)  
				SET @OPPSTATUSID=1  
    
			--FIRST INSERT INTO MAIN TABLE   
			SET @DESTDATA=''  
			SET @SOURCEDATA=''  
			SET @OpportunityID=0  
			SET @SOURCEDATA=' INSERT INTO crm_opportunities (DetailsContactID,ConvertFromLeadID,CodePrefix,CodeNumber,Code,StatusID,'   
			SET @DESTDATA='SELECT 1,'+CONVERT(NVARCHAR(300),@LEADID) +','''+isnull(@CodePrefix,'')+''','+CONVERT(NVARCHAR(300),isnull(@CodeNumber,0)) +','''+@Code+''','+CONVERT(NVARCHAR(300),@OPPSTATUSID)+','    
			--MAIN TABLE    
			WHILE @I<=@ACOUNT  
			BEGIN  

				IF(  exists (SELECT * FROM #TBLTEMP WITH(nolock) WHERE ID=@I and (BASECOLUMN NOT likE '%CCNID%' AND BASECOLUMN NOT likE '%opAlpha%' AND  
				LINKCOLUMN NOT likE '%CCNID%' AND LINKCOLUMN NOT likE '%LDAlpha%')))  
				begin   
					SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','          
					IF((SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)='Company')  
						SET @DESTDATA =@DESTDATA + 'CRM_LEADS.'+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','       
					else  
						SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','    
				end     
				SET @I=@I+1  
			END  
       
			IF(LEN(@SOURCEDATA)>0)  
			BEGIN  
				SET @SOURCEDATA=SUBSTRING(@SOURCEDATA,1,LEN(@SOURCEDATA)-1)   
				SET @DESTDATA=SUBSTRING(@DESTDATA,1,LEN(@DESTDATA)-1)   
			END   
       
			set @SOURCEDATA=@SOURCEDATA+ ',[Depth], [ParentID],  [lft],  [rgt],  [IsGroup],[CompanyGUID],  [GUID],  [CreatedBy],  [CreatedDate] )'      
			set @DESTDATA=@DESTDATA + + ',' + CONVERT(NVARCHAR(300),@Depth) + ',' +CONVERT(NVARCHAR(300),@ParentID) + ',' +CONVERT(NVARCHAR(300),@lft)+ ',' +   
			CONVERT(NVARCHAR(300),@rgt) + ',' + CONVERT(NVARCHAR(300),@IsGroup) + ',''' + CONVERT(NVARCHAR(300),@CompanyGUID) + ''',' + 'newid()'  
			+ ',CRM_LEADS.CreatedBy' +  ', CRM_LEADS.createddate'   

			SET  @SOURCEDATA=@SOURCEDATA +  @DESTDATA + ' FROM CRM_LEADS WITH(nolock)     
			WHERE CRM_LEADS.LEADID='+CONVERT(NVARCHAR(300),@LEADID)   
      print @SOURCEDATA
			EXEC sp_executesql @SOURCEDATA   
    
			SELECT @OpportunityID=OpportunityID,@Code=Code,@CompanyName=Company FROM crm_opportunities WITH(nolock) WHERE ConvertFromLeadID=@LEADID  

			INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])  
			VALUES(89,@OpportunityID,newid(),@USERNAME,@Dt)   

			SET @SOURCEDATA=''  
			SET @DESTDATA=''  
			SET @ACOUNT=0  

			SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTEMP WITH(nolock)   
       
			SET @SOURCEDATA=' INSERT INTO crm_opportunitiesEXTENDED (OpportunityID,'  
			SET @DESTDATA='SELECT '+CONVERT(NVARCHAR(300),@OpportunityID) +','  
			--EXTENDED TABLE  
			WHILE @I<=@TotalCount  
			BEGIN   
				IF exists (SELECT * FROM #TBLTEMP WITH(nolock) WHERE ID=@I and (BASECOLUMN likE '%opAlpha%' AND LINKCOLUMN  likE '%LDAlpha%'))  
				begin  
					SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','          
					SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','      
				end     
				else IF( exists (SELECT * FROM #TBLTEMP WITH(nolock) WHERE ID=@I and (BASECOLUMN likE '%opAlpha%'  
				AND (LINKCOLUMN not likE '%LDAlpha%' or LINKCOLUMN not likE '%CCNID%'))))  
				begin   
					SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','          
					SET @DESTDATA= @DESTDATA + ' L.'+ (SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I) + ','     
				end      
				SET @I=@I+1  
			END  
       
			SET @SOURCEDATA=SUBSTRING(@SOURCEDATA,1,LEN(@SOURCEDATA)-1)   
			SET @DESTDATA=SUBSTRING(@DESTDATA,1,LEN(@DESTDATA)-1)   

			set @SOURCEDATA=@SOURCEDATA+ ',[CreatedBy],  [CreatedDate] )'      
			set @DESTDATA=@DESTDATA + + ',CRM_LEADSEXTENDED.CreatedBy' +  ', CRM_LEADSEXTENDED.createddate'   

			SET  @SOURCEDATA=@SOURCEDATA +  @DESTDATA + ' FROM CRM_LEADSEXTENDED WITH(nolock)     
			JOIN CRM_LEADS L WITH(NOLOCK) ON CRM_LEADSEXTENDED.LEADID=L.LEADID  
			WHERE CRM_LEADSEXTENDED.LEADID='+CONVERT(NVARCHAR(300),@LEADID)   
			PRINT @SOURCEDATA   
			EXEC sp_executesql @SOURCEDATA  
           
			SET @SOURCEDATA=''  
			SET @DESTDATA=''  
			SET @ACOUNT=0  

			SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTEMP WITH(nolock)    

			--CCDATA TABLE  
			WHILE @I<=@TotalCount  
			BEGIN   

				IF( exists (SELECT * FROM #TBLTEMP WITH(nolock) WHERE ID=@I and  (BASECOLUMN likE '%CCNID%' AND LINKCOLUMN likE '%CCNID%') ))  
				begin  
					SET @SOURCEDATA= 'UPDATE COM_CCCCDATA SET '+(SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+'=(  
					SELECT '+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+' FROM COM_CCCCDATA WITH(nolock) WHERE COSTCENTERID=86 AND   
					NODEID='+CONVERT(NVARCHAR,@LEADID) +') WHERE COSTCENTERID=89 AND [NodeID]='+CONVERT(NVARCHAR,@OpportunityID)    
					EXEC sp_executesql @SOURCEDATA  

					SET @SOURCEDATA=''  
				end     
				SET @I=@I+1  
			END  
       
			DECLARE @return_value int,@LinkCostCenterID INT  
			IF(@OpportunityID>0)  
			BEGIN  
				DECLARE @TBLPREF TABLE(ID INT IDENTITY(1,1),VALUE NVARCHAR(300))  
				DECLARE @FILTER NVARCHAR(300),@FILTERVALUE NVARCHAR(300),@PREFVALUE NVARCHAR(300)   
				SELECT @PREFVALUE=VALUE FROM COM_COSTCENTERPREFERENCES WITH(nolock)   
				WHERE COSTCENTERID=86 AND NAME='QualifyProductsBasedon'  

				INSERT INTO @TBLPREF (VALUE)  
				EXEC SPSPLITSTRING @PREFVALUE ,';'  

				SELECT @FILTER=ISNULL(SYSCOLUMNNAME,'') FROM ADM_CostCenterDef WITH(NOLOCK) 
				WHERE CostCenterID=115 AND COSTCENTERCOLID IN (SELECT VALUE FROM @TBLPREF WHERE ID=1)  
				
				SELECT @FILTERVALUE=VALUE FROM @TBLPREF WHERE ID=2  
     
				CREATE TABLE #TBLPRO (ID INT IDENTITY(1,1),DCOLUMN NVARCHAR(300),SCOLUMN NVARCHAR(300))  
				INSERT INTO #TBLPRO  
				select l.SysColumnName, b.SysColumnName   
				from COM_DocumentLinkDetails dl WITH(nolock)  
				join ADM_CostCenterDef b WITH(nolock) on dl.CostCenterColIDBase=b.CostCenterColID   
				join ADM_CostCenterDef l WITH(nolock) on dl.CostCenterColIDLinked=l.CostCenterColID  
				where DocumentLinkDeFID in (select DocumentLinkDeFID from COM_DocumentLinkDef WITH(nolock) where CostCenterIDBase=86)  
				and l.costcenterid=154  

				DECLARE @k int,@tcount int,@sData nvarchar(max),@dData nvarchar(max)  
				select @k=1,@tcount=COUNT(*) from #TBLPRO WITH(nolock)  
				set @sData=''  
				set @dData=''  
   
				while @k<=@tcount  
				begin  
					SET @sData= @sData + (SELECT SCOLUMN FROM #TBLPRO WITH(nolock) WHERE ID=@k)  
					SET @dData= @dData + (SELECT DCOLUMN FROM #TBLPRO WITH(nolock) WHERE ID=@k)  

					IF(@k<>@tcount)  
					BEGIN  
						SET @sData=@sData + ','  
						SET @dData=@dData + ','  
					END  

					set @k=@k+1  
				end  
     
				IF((SELECT COUNT(*) FROM #TBLPRO WITH(nolock))=0)  
				BEGIN  
					select @sData=@sData+','+name,@dData=@dData+','+name
					from sys.columns WITH(NOLOCK)
					where object_id=object_id('CRM_ProductMapping') and name LIKE 'Alpha%'
				END  
				DROP TABLE #TBLPRO  
				
				select @sData=@sData+','+name,@dData=@dData+','+name
				from sys.columns WITH(NOLOCK)
				where object_id=object_id('CRM_ProductMapping') and name LIKE 'CCNID%'
				
				IF(@FILTER<>'' AND @FILTER IS NOT NULL)  
				BEGIN
					set @SOURCEDATA='INSERT into CRM_ProductMapping(CCNodeID,CostCenterID,CRMProduct, ProductID,UOMID,CurrencyID,Description,  
					Quantity '+@dData+',CompanyGUID,GUID,CreatedBy,CreatedDate)  
					select '+CONVERT(nvarchar(300),@OpportunityID)+',89,CRMProduct,ProductID,UOMID,CurrencyID,Description,  
					Quantity '+@sData+',CompanyGUID,GUID,CreatedBy,CreatedDate  
					FROM CRM_ProductMapping WITH(nolock) WHERE  CostCenterID=86 AND CCNodeID='+CONVERT(nvarchar(300),@LEADID)+' and '+convert(nvarchar(300),@FILTER)+'='''+convert(nvarchar(300),@FILTERVALUE)+''''  
					EXEC sp_executesql @SOURCEDATA  
				END  
				ELSE  
				BEGIN  
					set @SOURCEDATA='INSERT into CRM_ProductMapping(CCNodeID,CostCenterID,CRMProduct, ProductID,UOMID,CurrencyID,Description,  
					Quantity '+@dData+',CompanyGUID,GUID,CreatedBy,CreatedDate)  
					select '+CONVERT(nvarchar(300),@OpportunityID)+',89,CRMProduct,ProductID,UOMID,CurrencyID,Description,  
					Quantity '+@sData+',CompanyGUID,GUID,CreatedBy,CreatedDate  
					FROM CRM_ProductMapping WITH(nolock) WHERE  CostCenterID=86 AND CCNodeID='+CONVERT(nvarchar(300),@LEADID)+''  
					EXEC sp_executesql @SOURCEDATA  
				END  
        
				IF @LeadAddressDetails=0  
				BEGIN  
					insert into CRM_CONTACTS (FeatureID,FeaturePK,FirstName,MiddleName,LastName,SalutationID,JobTitle,Company,StatusID,Phone1,  
					Phone2,Email1,Fax,Department  ,CompanyGUID,GUID,CreatedBy,CreatedDate)  
					SELECT 89,@OpportunityID, FirstName,MiddleName,LastName,SalutationID, JobTitle,Company,StatusID,Phone1,
					Phone2,Email1,Fax,Department  ,CompanyGUID,GUID,CreatedBy,CreatedDate 
					FROM CRM_CONTACTS WITH(nolock) WHERE FeatureID=86 AND FeaturePK=@LEADID   
				END  
				ELSE IF @LeadAddressDetails=1  
				BEGIN  
					insert into CRM_CONTACTS(FeatureID,FeaturePK,FirstName,MiddleName,LastName,SalutationID,JobTitle,Company,StatusID,Phone1,  
					Phone2,Email1,Fax,Department  ,CompanyGUID,GUID,CreatedBy,CreatedDate, Address1,Address2,Address3,City,State,Zip,Country)  
					SELECT 89,@OpportunityID, FirstName,MiddleName,LastName,SalutationID, JobTitle,Company,StatusID,Phone1,
					Phone2,Email1,Fax,Department  ,CompanyGUID,GUID,CreatedBy,CreatedDate, Address1,Address2,Address3,City,State,Zip,Country 
					FROM CRM_CONTACTS WITH(nolock) WHERE FeatureID=86 AND FeaturePK=@LEADID   
					truncate table #TBLCONTACTS  
					INSERT INTO #TBLCONTACTS  
					SELECT CONTACTID FROM  COM_CONTACTS WITH(nolock) WHERE FEATUREID=86 AND FEATUREPK=@LEADID --AND ADDRESSTYPEID=2  
    
					DECLARE @M INT,@CCOUNT INT,@CONTACTIDENTITY INT  
					SELECT @M=1, @CCOUNT=COUNT(*) FROM #TBLCONTACTS WITH(nolock)   
					SET @CONTACTSXML=''  
     
					SET @sData=''
					select @sData=@sData+','+name
					from sys.columns WITH(NOLOCK)
					where object_id=object_id('COM_ContactsExtended') and name LIKE 'Alpha%'
					
					SET @dData=''
					select @dData=@dData+','+name
					from sys.columns WITH(NOLOCK)
					where object_id=object_id('COM_CCCCData') and name LIKE 'CCNID%'
						
					WHILE @M<=@CCOUNT  
					BEGIN  
						INSERT INTO COM_CONTACTS([AddressTypeID],[FeatureID],[FeaturePK],[ContactName],[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1],[Phone2]   
						,[Fax],[Email1],[Email2],[URL],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[CostCenterID],[ContactTypeID]    
						,[FirstName],[MiddleName],[LastName],[SalutationID],[JobTitle],[Company],[StatusID],[Department],[RoleLookUpID],[Gender],[BirthDay],[Anniversary],[PreferredID],[PreferredName],[IsEmailOn],[IsBulkEmailOn],[IsMailOn],[IsPhoneOn],[IsFaxOn],[IsVisible],[Depth],[ParentID],[lft],[rgt],[IsGroup],[ConvertFromLeadID])  
						SELECT ADDRESSTYPEID,89,@OpportunityID,[ContactName] ,[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1],[Phone2],[Fax],[Email1],[Email2]    
						,[URL],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],89,[ContactTypeID],[FirstName],[MiddleName],[LastName]     
						,[SalutationID],[JobTitle],[Company],[StatusID],[Department],[RoleLookUpID],[Gender],[BirthDay],[Anniversary],[PreferredID],[PreferredName],[IsEmailOn],[IsBulkEmailOn],[IsMailOn],[IsPhoneOn],[IsFaxOn],[IsVisible],[Depth],[ParentID],[lft],[rgt],[IsGroup],[ConvertFromLeadID] 
						FROM COM_CONTACTS WITH(nolock) WHERE CONTACTID IN (SELECT CONTACTID FROM   #TBLCONTACTS WITH(nolock) WHERE ID=@M)  
						SET @CONTACTIDENTITY=SCOPE_IDENTITY()  
						
						set @SOURCEDATA='INSERT INTO [COM_ContactsExtended]([ContactID],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate]'+@sData+')  
						SELECT @CONTACTIDENTITY,[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate]'+@sData+' 
						FROM [COM_ContactsExtended] WITH(nolock) WHERE CONTACTID IN (SELECT CONTACTID FROM #TBLCONTACTS WITH(nolock) WHERE ID=@M)'  
						EXEC sp_executesql @SOURCEDATA,N'@CONTACTIDENTITY INT,@M INT',@CONTACTIDENTITY,@M 
						
						set @SOURCEDATA='INSERT INTO COM_CCCCData([CostCenterID],[NodeID],[CCNodeID],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[AccountID],[ProductID]'+@dData+')  
						SELECT 65,@CONTACTIDENTITY,NULL,[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[AccountID],[ProductID]'+@dData+'   
						FROM COM_CCCCData WITH(nolock) WHERE CostCenterID=65 AND NODEID   IN (SELECT CONTACTID FROM   #TBLCONTACTS WITH(nolock) WHERE ID=@M)'  
						EXEC sp_executesql @SOURCEDATA,N'@CONTACTIDENTITY INT,@M INT',@CONTACTIDENTITY,@M 
						
						SET @M=@M+1  
					END  
				END  
      
				update CRM_Leads set StatusID=417 where LeadID=@LEADID  
				update crm_opportunities set Mode=4,Leadid=@LEADID,ConvertFromLeadid=@LEADID where OpportunityID=@OpportunityID  
            
				SELECT @LinkCostCenterID=isnull([Value],0) FROM COM_CostCenterPreferences WITH(NOLOCK)   
				WHERE FeatureID=89 AND [Name]='LinkDimension'  
   
				IF @LinkCostCenterID>0  
				BEGIN  
					EXEC @return_value = [dbo].[spCOM_SetCostCenter]  
					@NodeID = 0,@SelectedNodeID = 0,@IsGroup = 0,  
					@Code = @Code,  
					@Name = @CompanyName,  
					@AliasName=@CompanyName,  
					@PurchaseAccount=0,@SalesAccount=0,@StatusID=417,  
					@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,  
					@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,  
					@CostCenterID =@LinkCostCenterID,@CompanyGUID=@COMPANYGUID,@GUID='GUID',@UserName=@USERNAME,@RoleID=1,@UserID=@USERID  
					
					UPDATE [CRM_Opportunities]  
					SET CCOpportunityID=@return_value  
					WHERE OpportunityID=@OpportunityID  
         
					IF(EXISTS(SELECT VALUE FROM COM_COSTCENTERPREFERENCES WITH(nolock) WHERE COSTCENTERID=89 AND NAME='LinkDimension'))  
					BEGIN  
						DECLARE @DIMID INT,@UpdateSql NVARCHAR(MAX)  
						SET @DIMID=0  
						SELECT @DIMID=VALUE-50000 FROM COM_COSTCENTERPREFERENCES WITH(nolock) WHERE COSTCENTERID=89 AND NAME='LinkDimension'  
						IF(@DIMID>0)  
						BEGIN  
							SET @UpdateSql=' UPDATE COM_CCCCDATA SET CCNID'+CONVERT(NVARCHAR(30),@DIMID)+'=  
							(SELECT CCOpportunityID FROM CRM_Opportunities WITH(nolock) WHERE OpportunityID='+convert(nvarchar,@OpportunityID) + ')   
							WHERE NodeID = '+convert(nvarchar,@OpportunityID) + ' AND CostCenterID = 89'  
							exec(@UpdateSql)    
						END  
					END    
				END  
     
			END      
		END 
		--[CRM_History]
		SET @ID=SCOPE_IDENTITY()
		SET @STATUSNAME=(SELECT Name from com_lookup s WITH(nolock),CRM_Opportunities r WITH(nolock) where s.NodeID=r.StatusID and r.LeadId=@LeadID)
		INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,
		ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
		VALUES(@ID,86,@LeadID,0,@UserID,0,@Dt,@UserName ,@CompanyGUID,0,0,0,0,'','Converted to Opportunity : '+@Code +' - Status: '+@STATUSNAME,'Convert')
		--[CRM_History]
	END  
  
	-------------INSERT INTO CUSTOMERS TABLE  
	IF(@Customer=1)  
	BEGIN  
		--To Set Left,Right And Depth of Record  
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
		from [CRM_Customer] with(NOLOCK) where CustomerID=@SelectedNodeID  

		--IF No Record Selected or Record Doesn't Exist  
		if(@SelectedIsGroup is null)   
			select @SelectedNodeID=CustomerID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
			from [CRM_Customer] with(NOLOCK) where ParentID =0  
         
		if(@SelectedIsGroup = 1)--Adding Node Under the Group  
		BEGIN  
			UPDATE CRM_Customer SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
			UPDATE CRM_Customer SET lft = lft + 2 WHERE lft > @Selectedlft;  
			set @lft =  @Selectedlft + 1  
			set @rgt = @Selectedlft + 2  
			set @ParentID = @SelectedNodeID  
			set @Depth = @Depth + 1  
		END  
		else if(@SelectedIsGroup = 0)--Adding Node at Same level  
		BEGIN  
			UPDATE CRM_Customer SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
			UPDATE CRM_Customer SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
		SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=83 and  Name='CodeAutoGen'    
		--GENERATE CODE  
		IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1   
		BEGIN  
			if(@SelectedNodeID is null)  
				insert into #temp1  
				EXEC [spCOM_GetCodeData] 83,1,''    
			else  
				insert into #temp1  
				EXEC [spCOM_GetCodeData] 83,@SelectedNodeID,''    
			--select * from #temp1  
			select @Code=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 WITH(nolock)  
		END  
		IF @CODE='' OR @CODE IS NULL 
			SET @Code=@LeadCode  
		  
		if exists(select value from [com_costcenterpreferences] WITH(nolock) where Name = 'ConvertLead')   
		Begin  
			select @AccountID  = value from [com_costcenterpreferences] WITH(nolock) where Name = 'ConvertLead'  

			IF NOT EXISTS (SELECT ConvertFromLeadID FROM [CRM_Customer] WITH(nolock) WHERE ConvertFromLeadID=@LEADID)    
			BEGIN    
				-- Insert statements for procedure here  
				INSERT INTO [CRM_Customer](CodePrefix,CodeNumber,[CustomerCode],[CustomerName] ,[AliasName],[CustomerTypeID],[StatusID],[AccountID],[Depth],[ParentID]
				,[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],ConvertFromLeadID)  
				VALUES(@CodePrefix,@CodeNumber,@CODE,@CompanyName,@CompanyName,146,393,@AccountID,@Depth,@ParentID,  
				@lft,@rgt,@IsGroup,NULL,NULL,@CompanyGUID,newid(),@Description,@UserName,@Dt,@LEADID)  

				--To get inserted record primary key  
				SET @CustomerID=SCOPE_IDENTITY()  
				--Handling of Extended Table  
				INSERT INTO [CRM_CustomerExtended]([CustomerID],[CreatedBy],[CreatedDate])  
				VALUES(@CustomerID, @UserName, @Dt)  

				--[CRM_History]
				SET @ID=SCOPE_IDENTITY()
				SET @STATUSNAME=( SELECT Status from COM_STATUS s WITH(nolock),CRM_Customer r WITH(nolock) where s.StatusID=r.StatusID and r.ConvertFromLeadID=@LeadID)
				INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,
				ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
				VALUES(@ID,86,@LeadID,0,@UserID,0,@Dt,@UserName ,@CompanyGUID,0,0,0,0,'','Converted to Customer : '+@Code +' - Status: '+@STATUSNAME,'Convert')
				--[CRM_History] 
				IF @CustomerContacts=1  
				BEGIN   
					truncate table #TBLCONTACTS  
					INSERT INTO #TBLCONTACTS  
					SELECT CONTACTID FROM  COM_CONTACTS WHERE FEATUREID=86 AND FEATUREPK=@LEADID-- AND ADDRESSTYPEID=2  
				    
					SET @sData=''
					select @sData=@sData+','+name
					from sys.columns WITH(NOLOCK)
					where object_id=object_id('COM_ContactsExtended') and name LIKE 'Alpha%'
					
					SET @dData=''
					select @dData=@dData+','+name
					from sys.columns WITH(NOLOCK)
					where object_id=object_id('COM_CCCCData') and name LIKE 'CCNID%'
						
					SELECT @M=1, @CCOUNT=COUNT(*) FROM #TBLCONTACTS WITH(nolock)      
					WHILE @M<=@CCOUNT  
					BEGIN  
						INSERT INTO COM_CONTACTS([AddressTypeID],[FeatureID],[FeaturePK],[ContactName],[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1],[Phone2]   
						,[Fax],[Email1],[Email2],[URL],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[CostCenterID],[ContactTypeID]    
						,[FirstName],[MiddleName],[LastName],[SalutationID],[JobTitle],[Company],[StatusID],[Department],[RoleLookUpID],[Gender],[BirthDay],[Anniversary],[PreferredID],[PreferredName],[IsEmailOn],[IsBulkEmailOn],[IsMailOn],[IsPhoneOn],[IsFaxOn],[IsVisible],[Depth],[ParentID],[lft],[rgt],[IsGroup],[ConvertFromLeadID])  
						SELECT ADDRESSTYPEID,83,@CustomerID,[ContactName],[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1],[Phone2],[Fax],[Email1],[Email2]       
						,[URL],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],89,[ContactTypeID],[FirstName],[MiddleName],[LastName]        
						,[SalutationID],[JobTitle],[Company],[StatusID],[Department],[RoleLookUpID],[Gender],[BirthDay],[Anniversary],[PreferredID],[PreferredName],[IsEmailOn],[IsBulkEmailOn],[IsMailOn],[IsPhoneOn],[IsFaxOn],[IsVisible],[Depth],[ParentID],[lft],[rgt],[IsGroup],[ConvertFromLeadID] 
						FROM COM_CONTACTS WITH(nolock) WHERE CONTACTID IN (SELECT CONTACTID FROM   #TBLCONTACTS WITH(nolock) WHERE ID=@M)  
						SET @CONTACTIDENTITY=SCOPE_IDENTITY()  
	
						set @SOURCEDATA='INSERT INTO [COM_ContactsExtended]([ContactID],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate]'+@sData+')  
						SELECT @CONTACTIDENTITY,[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate]'+@sData+'        
						FROM [COM_ContactsExtended] WITH(nolock) WHERE CONTACTID IN (SELECT CONTACTID FROM  #TBLCONTACTS WITH(nolock) WHERE ID=@M)'
						EXEC sp_executesql @SOURCEDATA,N'@CONTACTIDENTITY INT,@M INT',@CONTACTIDENTITY,@M   

						set @SOURCEDATA='INSERT INTO COM_CCCCData([CostCenterID],[NodeID],[CCNodeID],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[AccountID],[ProductID]'+@dData+')  
						SELECT 65,@CONTACTIDENTITY,NULL,[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[AccountID],[ProductID]'+@dData+'   
						FROM COM_CCCCData WITH(nolock) WHERE CostCenterID=65 AND NODEID IN (SELECT CONTACTID FROM  #TBLCONTACTS WITH(nolock) WHERE ID=@M)'  
						EXEC sp_executesql @SOURCEDATA,N'@CONTACTIDENTITY INT,@M INT',@CONTACTIDENTITY,@M   

						SET @M=@M+1  
					END  
				END   
			END     
		end  
	end  
	----------- INSERT INTO CONTACTS TABLE  
	IF (@Contact=1)  
	BEGIN  
		--To Set Left,Right And Depth of Record    
		SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
		from COM_CONTACTS with(NOLOCK) where ContactID=@SelectedNodeID    

		--IF No Record Selected or Record Doesn't Exist    
		if(@SelectedIsGroup is null)     
			select @SelectedNodeID=@DetailContactID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth    
			from COM_CONTACTS with(NOLOCK) where ParentID =0    
            
		if(@SelectedIsGroup = 1)--Adding Node Under the Group    
		BEGIN    
			UPDATE COM_CONTACTS SET rgt = rgt + 2 WHERE rgt > @Selectedlft;    
			UPDATE COM_CONTACTS SET lft = lft + 2 WHERE lft > @Selectedlft;    
			set @lft =  @Selectedlft + 1    
			set @rgt = @Selectedlft + 2    
			set @ParentID = @SelectedNodeID    
			set @Depth = @Depth + 1    
		END    
		else if(@SelectedIsGroup = 0)--Adding Node at Same level    
		BEGIN    
			UPDATE COM_CONTACTS SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;    
			UPDATE COM_CONTACTS SET lft = lft + 2 WHERE lft > @Selectedrgt;    
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
  
		IF  NOT EXISTS (SELECT ConvertFromLeadID FROM COM_CONTACTS WITH(nolock) WHERE ConvertFromLeadID=@LEADID)    
		BEGIN    
			insert into COM_CONTACTS  
			(ContactTypeID,  
			FirstName,  
			MiddleName,  
			LastName,  
			SalutationID,  
			JobTitle,  
			Company,  
			StatusID,  
			Phone1,  
			Phone2,  
			Email1,  
			Fax,  
			Department,  
			RoleLookUpID,  
			Address1,  
			Address2,  
			Address3,  
			City,  
			State,  
			Zip,  
			Country,  
			Gender,  
			Birthday,  
			Anniversary,  
			PreferredID,  
			PreferredName,  
			IsEmailOn,  
			IsBulkEmailOn,IsMailOn,  
			IsPhoneOn,  
			IsFaxOn,  
			IsVisible,  
			Description,  
			Depth,  
			ParentID,  
			lft,  
			rgt,  
			IsGroup,  
			CompanyGUID,  
			GUID,  
			CreatedBy,  
			CreatedDate, ConvertFromLeadID,AddressTypeid,Featureid,featurepk)  

			select 53,  
			FirstName,  
			MiddleName,  
			LastName,  
			SalutationID,  
			JobTitle,  
			Company,  
			StatusID,  
			Phone1,  
			Phone2,  
			Email1,  
			Fax,  
			Department,  
			RoleLookUpID,  
			Address1,  
			Address2,  
			Address3,  
			City,  
			State,  
			Zip,  
			Country,  
			Gender,  
			Birthday,  
			Anniversary,  
			PreferredID,  
			PreferredName,  
			IsEmailOn,  
			IsBulkEmailOn,  
			IsMailOn,  
			IsPhoneOn,  
			IsFaxOn,  
			IsVisible,  
			@Description,  
			@Depth,  
			@ParentID,  
			@lft,  
			@rgt,  
			@IsGroup,  
			@CompanyGUID,  
			newid(),  
			@UserName,  
			convert(float,@Dt),@LEADID,2,65,0 from CRM_CONTACTS WITH(nolock)   
			where featureid=86 and featurepk=@LeadID and featurepk in (select Leadid from CRM_Leads WITH(nolock) where mode IN (0,1))  
			set @DetailContactID=scope_identity()  
			--[CRM_History]
			SET @ID=SCOPE_IDENTITY()
			SET @CompanyName=( SELECT ISNULL(COMPANY,'') from COM_CONTACTS  WITH(nolock) WHERE CONTACTID=@DetailContactID)
			IF(ISNULL(@CompanyName,'')<>'')
				SET @CompanyName='- Description: '+@CompanyName
			ELSE 
				SET @CompanyName=''
			INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,
			ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
			VALUES(@ID,86,@LeadID,0,@UserID,0,@Dt,@UserName ,@CompanyGUID,0,0,0,0,'','Converted to Contact '+@CompanyName,'Convert')
			--[CRM_History]  
		END  
	END  
	-------------INSERT INTO ACCOUNTS TABLE  
	IF(@ACCOUNT=1)  
	BEGIN   
		IF  NOT EXISTS (SELECT ConvertFromLeadID FROM ACC_ACCOUNTS WITH(nolock) WHERE ConvertFromLeadID=@LEADID)    
		BEGIN       
			truncate table   #TBLTEMP   
			alter table #TBLTEMP add bSysTableName nvarchar(100)  
			alter table #TBLTEMP add lSysTableName nvarchar(100)   
			INSERT INTO #TBLTEMP (BASECOLUMN, LINKCOLUMN, bSysTableName, lSysTableName)  
			select l.SysColumnName, b.SysColumnName, l.SysTableName , b.SysTableName    
			from COM_DocumentLinkDetails dl WITH(nolock)  
			join ADM_CostCenterDef b WITH(nolock) on dl.CostCenterColIDBase=b.CostCenterColID  
			join ADM_CostCenterDef l WITH(nolock) on dl.CostCenterColIDLinked=l.CostCenterColID  
			JOIN COM_DocumentLinkDef D WITH(nolock) ON DL.DocumentLinkDeFID=D.DocumentLinkDeFID  
			where D.CostCenterIDBase=86  AND D.COSTCENTERIDLINKED=2  

			SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTEMP WITH(nolock)  
			
			IF (@ACOUNT>0)  
			BEGIN  
				SELECT @SelectedNodeID=isnull(VALUE,1) FROM COM_COSTCENTERPREFERENCES WITH(nolock) WHERE NAME='ConvertedAccountGroup' and costcenterid=86  
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

				SET @SOURCEDATA=' INSERT INTO ACC_ACCOUNTS (AccountTypeID,StatusID,ConvertFromLeadID,'  
				SET @DESTDATA='SELECT 7,33,'+CONVERT(NVARCHAR(300),@LEADID) +','  
      
				WHILE @I<=@ACOUNT  
				BEGIN   
					IF( not exists (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I    and (BASECOLUMN likE '%acAlpha%'   
					OR bSysTableName LIKE 'COM_Contacts' or  LOWER(bSYSTABLENAME)='com_address')))  
					begin  
						SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','   

						IF((SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)='Company')  
							SET @DESTDATA =@DESTDATA + 'CRM_LEADS.'+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','      
						else  
							SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+ ','   
					end     
					SET @I=@I+1  
				END  
				if(len(@SOURCEDATA)>0)  
					SET @SOURCEDATA=SUBSTRING(@SOURCEDATA,1,LEN(@SOURCEDATA)-1)   
				IF(LEN(@DESTDATA)>0)  
					SET @DESTDATA=SUBSTRING(@DESTDATA,1,LEN(@DESTDATA)-1)   

				set @SOURCEDATA=@SOURCEDATA+ ',[IsBillwise],[CreditDays],[CreditLimit],  [DebitDays],  [DebitLimit], [Depth], [ParentID],  [lft],  [rgt],  [IsGroup],[CompanyGUID],  [GUID],  [CreatedBy],  [CreatedDate] )'      
				set @DESTDATA=@DESTDATA + + ',1,0,0,0,0,' + CONVERT(NVARCHAR(300),@Depth) + ',' +CONVERT(NVARCHAR(300),@ParentID) + ',' +CONVERT(NVARCHAR(300),@lft)+ ',' +   
				CONVERT(NVARCHAR(300),@rgt) + ',' + CONVERT(NVARCHAR(300),@IsGroup) + ',''' + CONVERT(NVARCHAR(300),@CompanyGUID) + ''',' + 'newid()'  
				+ ',CRM_LEADS.CreatedBy' +  ', CRM_LEADS.createddate'   

				SET  @SOURCEDATA=@SOURCEDATA +  @DESTDATA + ' FROM CRM_LEADS WITH(nolock) LEFT JOIN CRM_LeadsExtended WITH(nolock) ON CRM_LeadsExtended.LEADID=CRM_LEADS.LEADID   
				LEFT JOIN COM_Contacts ON COM_Contacts.FEATUREPK='+CONVERT(NVARCHAR(300),@LEADID)+' AND ADDRESSTYPEID=1 AND COM_Contacts.FEATUREID=86 WHERE CRM_LEADS.LEADID='+CONVERT(NVARCHAR(300),@LEADID)   
				PRINT @SOURCEDATA  
				EXEC sp_executesql @SOURCEDATA   
       
				SELECT @AccountID=ACCOUNTID FROM ACC_ACCOUNTS WITH(nolock) WHERE ConvertFromLeadID=@LEADID  

				IF(@AccountID IS NOT NULL)  
				BEGIN  
					--Check duplicate  
					exec spACC_CheckDuplicate @AccountID  

					--Handling of Extended Table    
					INSERT INTO [ACC_AccountsExtended]([AccountID],[CreatedBy],[CreatedDate])    
					VALUES(@AccountID, @UserName, @Dt)    

					SET @dData=''
					select @dData=@dData+','+name
					from sys.columns WITH(NOLOCK)
					where object_id=object_id('COM_CCCCData') and name LIKE 'CCNID%'
							
					SET @SOURCEDATA='INSERT INTO COM_CCCCData(CostCenterID,NodeID,CCNodeID,GUID,CreatedBy,CreatedDate'+@dData+')  
					select 2,'+CONVERT(NVARCHAR,@AccountID)+', CCNodeID,newid(), '''+@UserName+''','+CONVERT(NVARCHAR,@Dt)+@dData+' 
					from COM_CCCCDATA WITH(NOLOCK) where [CostCenterID]=86 and [NodeID]='+CONVERT(NVARCHAR,@LEADID)  
					EXEC sp_executesql @SOURCEDATA  

					declare @PrimaryAddressID INT  
					DECLARE @tempsql nvarchar(max)  

					set @SOURCEDATA=''  
					set @I=1  
					WHILE @I<=@ACOUNT  
					begin   
						IF( exists (SELECT * FROM #TBLTEMP WITH(nolock) WHERE ID=@I and LOWER(LSYSTABLENAME)<>'com_address' and (BASECOLUMN likE '%Alpha%' AND LINKCOLUMN likE '%Alpha%') ))  
						begin   
							SET @SOURCEDATA= 'UPDATE [ACC_AccountsExtended] SET '+(SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+'=(  
							SELECT '+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+' FROM CRM_LeadsExtended WITH(nolock) WHERE    
							LeadID='+CONVERT(NVARCHAR,@LEADID) +') WHERE  [ACCOUNTID]='+CONVERT(NVARCHAR,@AccountID) + ''  
							print @SOURCEDATA  
							EXEC sp_executesql @SOURCEDATA   
							SET @SOURCEDATA=''   
						end     
						set @I=@I+1  
					end  
        
					--INSERT INTO HISTROY     
					EXEC [spCOM_SaveHistory]    
					@CostCenterID =2,      
					@NodeID =@AccountID,  
					@HistoryStatus ='Update',  
					@UserName=@UserName,
					@Dt=@Dt    

					--[CRM_History]
					SET @ID=SCOPE_IDENTITY()
					SET @STATUSNAME=( SELECT Status from COM_STATUS s WITH(nolock),ACC_ACCOUNTS r WITH(nolock) where s.StatusID=r.StatusID and r.ConvertFromLeadID=@LeadID)
					INSERT INTO [CRM_History]([AssignmentID],[CCID],[CCNODEID],[TeamNodeID],USERID,[IsTeam],[CreatedDate],[CreatedBy],[CompanyGUID],IsRole,IsGroup,
					ISFROMACTIVITY,AssignedUserID,AssignedUserName,Description,IsFrom)
					VALUES(@ID,86,@LeadID,0,@UserID,0,@Dt,@UserName ,@CompanyGUID,0,0,0,0,'','Converted to Account : '+@Code +' - Status: '+@STATUSNAME,'Convert')
					--[CRM_History]    
					IF @AccountContacts=1  
					BEGIN   
						truncate table #TBLCONTACTS  
						INSERT INTO #TBLCONTACTS  
						SELECT CONTACTID FROM  COM_CONTACTS WITH(nolock) WHERE FEATUREID=86 AND FEATUREPK=@LEADID --AND ADDRESSTYPEID=2  
				        
						SET @sData=''
						select @sData=@sData+','+name
						from sys.columns WITH(NOLOCK)
						where object_id=object_id('COM_ContactsExtended') and name LIKE 'Alpha%'
						 
						SELECT @M=1, @CCOUNT=COUNT(*) FROM #TBLCONTACTS WITH(nolock)      
						WHILE @M<=@CCOUNT  
						BEGIN  

							INSERT INTO COM_CONTACTS([AddressTypeID],[FeatureID],[FeaturePK],[ContactName],[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1],[Phone2],[Fax],[Email1],[Email2],[URL],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[CostCenterID],[ContactTypeID]
							,[FirstName],[MiddleName],[LastName],[SalutationID],[JobTitle],[Company],[StatusID],[Department],[RoleLookUpID],[Gender],[BirthDay],[Anniversary],[PreferredID],[PreferredName],[IsEmailOn],[IsBulkEmailOn],[IsMailOn],[IsPhoneOn],[IsFaxOn],[IsVisible],[Depth],[ParentID],[lft],[rgt],[IsGroup],[ConvertFromLeadID])  
							SELECT ADDRESSTYPEID,2,@AccountID,[ContactName] ,[Address1],[Address2],[Address3],[City],[State],[Zip],[Country],[Phone1],[Phone2],[Fax],[Email1],[Email2]     
							,[URL],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],89,[ContactTypeID],[FirstName],[MiddleName],[LastName]      
							,[SalutationID],[JobTitle],[Company],[StatusID],[Department],[RoleLookUpID],[Gender],[BirthDay],[Anniversary],[PreferredID],[PreferredName],[IsEmailOn],[IsBulkEmailOn],[IsMailOn],[IsPhoneOn],[IsFaxOn],[IsVisible],[Depth],[ParentID],[lft],[rgt],[IsGroup],[ConvertFromLeadID] 
							FROM  COM_CONTACTS WITH(nolock) WHERE CONTACTID IN (SELECT CONTACTID FROM   #TBLCONTACTS WITH(nolock) WHERE ID=@M)  
							SET @CONTACTIDENTITY=SCOPE_IDENTITY()  

							SET @SOURCEDATA= 'INSERT INTO [COM_ContactsExtended]([ContactID],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate]'+@sData+')  
							SELECT @CONTACTIDENTITY,[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate]'+@sData+'     
							FROM [COM_ContactsExtended] WITH(nolock) WHERE CONTACTID IN (SELECT CONTACTID FROM   #TBLCONTACTS WITH(nolock) WHERE ID=@M)'  
							EXEC sp_executesql @SOURCEDATA,N'@CONTACTIDENTITY INT,@M INT',@CONTACTIDENTITY,@M  
							
							SET @SOURCEDATA= 'INSERT INTO COM_CCCCData([CostCenterID],[NodeID],[CCNodeID],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[AccountID],[ProductID]'+@dData+')  
							SELECT 65,@CONTACTIDENTITY,NULL,[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[AccountID],[ProductID]'+@dData+'   
							FROM COM_CCCCData WITH(nolock) WHERE CostCenterID=65 AND NODEID   IN (SELECT CONTACTID FROM   #TBLCONTACTS WITH(nolock) WHERE ID=@M)'  
							EXEC sp_executesql @SOURCEDATA,N'@CONTACTIDENTITY INT,@M INT',@CONTACTIDENTITY,@M  
							
							SET @M=@M+1  
						END  
					END 
        
					set @SOURCEDATA=''  
					set @I=1  
					declare @AddressID INT  
					INSERT INTO COM_Address(AddressTypeID,FeatureID,FeaturePK,[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])  
					VALUES (1,2,@AccountID,NEWID(),NEWID(),@UserName,@Dt)  
					SET @AddressID=SCOPE_IDENTITY()  

					WHILE @I<=@ACOUNT  
					begin  
						--select * from #TBLTEMP WHERE ID=@I   
						IF( exists (SELECT * FROM #TBLTEMP WITH(nolock) WHERE ID=@I and  (LOWER(bSYSTABLENAME)='com_address'  
						AND LOWER(lSYSTABLENAME)='crm_contacts' )))  
						begin    
							SET @SOURCEDATA= 'UPDATE [COM_Address] SET '+(SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+'=(  
							SELECT '+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+' FROM crm_contacts WITH(nolock) WHERE    
							featurepk='+CONVERT(NVARCHAR,@LEADID) +' and featureid=86 and addresstypeid=1)   
							WHERE  [AddressID]='+CONVERT(NVARCHAR,@AddressID) + ''   
							print @SOURCEDATA  
							EXEC sp_executesql @SOURCEDATA   
							SET @SOURCEDATA=''   
						end    
						else IF( exists (SELECT * FROM #TBLTEMP WITH(nolock) WHERE ID=@I and  (LOWER(bSYSTABLENAME)='com_address'  
						AND LINKCOLUMN LIKE '%Alpha%' )))   
						begin    
							SET @SOURCEDATA= 'UPDATE [COM_Address] SET '+(SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+'=(  
							SELECT '+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+' FROM CRM_LeadsExtended WITH(nolock) WHERE    
							LeadID='+CONVERT(NVARCHAR,@LEADID) +')   
							WHERE  [AddressID]='+CONVERT(NVARCHAR,@AddressID) + ''   
							print @SOURCEDATA  
							EXEC sp_executesql @SOURCEDATA   
							SET @SOURCEDATA=''   
						end    
						else  
						IF( exists (SELECT * FROM #TBLTEMP  WITH(nolock) WHERE ID=@I and  (LSYSTABLENAME='CRM_Contacts' AND BASECOLUMN likE '%Alpha%') ))  
						begin   
							SET @SOURCEDATA= 'UPDATE [ACC_AccountsExtended] SET '+(SELECT BASECOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+'=(  
							SELECT '+(SELECT LINKCOLUMN FROM #TBLTEMP WITH(nolock) WHERE ID=@I)+' FROM crm_contacts WITH(nolock) WHERE    
							featurepk='+CONVERT(NVARCHAR,@LEADID) +' and featureid=86)     
							WHERE  [ACCOUNTID]='+CONVERT(NVARCHAR,@AccountID) + ''  
							print @SOURCEDATA  
							EXEC sp_executesql @SOURCEDATA   
							SET @SOURCEDATA=''   
						end    
						set @I=@I+1  
					end   
				END 
			END  
			ELSE
			BEGIN
				SELECT 'Please Map the fields' ErrorMessage,-100 ErrorNumber				
				SET @ErrorNumber=1
			END
		END  
	END
   
	 --set notification  
	 EXEC spCOM_SetNotifEvent -1001,86,@LEADID,@CompanyGUID,@UserName,@UserID,-1  
   
   
COMMIT TRANSACTION    
  
SET NOCOUNT OFF; 
IF(@ErrorNumber<>1)    
BEGIN
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
	WHERE ErrorNumber=103 AND LanguageID=@LangID   
END
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
