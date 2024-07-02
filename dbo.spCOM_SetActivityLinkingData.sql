USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetActivityLinkingData]
	@CostCenterID [bigint],
	@NodeID [bigint]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION     
SET NOCOUNT ON;    
    CREATE TABLE #TBL(ID INT IDENTITY(1,1),CostCenterColIDBase INT,CostCenterColIDLinked INT)
     CREATE TABLE #TBLCCFIELDS(ID INT IDENTITY(1,1),SYSCOL NVARCHAR(300))
 
    INSERT INTO #TBL
    SELECT DISTINCT CostCenterColIDBase,CostCenterColIDLinked FROM COM_DocumentLinkDetails WITH(NOLOCK)
    WHERE DocumentLinkDeFID IN (SELECT DocumentLinkDeFID FROM [COM_DocumentLinkDef]  WITH(NOLOCK) 
    WHERE CostCenterIDLinked=@CostCenterID AND CostCenterIDBase=144)
    
    DECLARE @COUNT INT,@I INT,@SYSCOLSOURCE NVARCHAR(300),@SYSCOLDEST NVARCHAR(300),@isInventory bit,@PRIMARYKEY NVARCHAR(300),
    @UPDATEAQL NVARCHAR(MAX),@CCCCSQL NVARCHAR(MAX),@tempCode NVARCHAR(300),
    @SOURCEDATA NVARCHAR(300),@DESTDATA NVARCHAR(300),@TSQL NVARCHAR(MAX),@SYSTABLESOURCE NVARCHAR(300),@SYSTABLEDEST NVARCHAR(300)
    
    SELECT @COUNT=COUNT(*),@I=1 FROM #TBL
    SET @TSQL=''
    SET @UPDATEAQL=''
    SET @CCCCSQL=''
    
    SELECT @isInventory=ISINVENTORY FROM ADM_DOCUMENTTYPES WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID
    
    --alpha fields
    WHILE @I<=@COUNT
    BEGIN
		SELECT @SYSCOLDEST=SYSCOLUMNNAME,@SYSTABLEDEST=SYSTABLENAME FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERCOLID IN (
		SELECT CostCenterColIDBase FROM #TBL WHERE ID=@I) AND COSTCENTERID=144 
		
		SELECT @SYSCOLSOURCE=SYSCOLUMNNAME,@SYSTABLESOURCE=SYSTABLENAME FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERCOLID IN (
		SELECT CostCenterColIDLinked FROM #TBL WHERE ID=@I) AND COSTCENTERID=@CostCenterID 
		
		 IF(@CostCenterID>40000 AND @CostCenterID<50000)
		 BEGIN
			
			 SET @tempCode='@SOURCEDATA NVARCHAR(300) OUTPUT'
			 
			 IF @SYSTABLESOURCE='INV_DocDetails' OR @SYSTABLESOURCE='ACC_DocDetails' 
				 SET @TSQL=' SET @SOURCEDATA=(SELECT TOP 1 '+@SYSCOLSOURCE+' FROM '+@SYSTABLESOURCE+' WITH(NOLOCK) WHERE COSTCENTERID='+CONVERT(NVARCHAR(300),@CostCenterID)+'
				 AND DOCID IN ('+CONVERT(NVARCHAR(400),@NodeID) + ') )' 
			 ELSE  IF @SYSTABLESOURCE='COM_DocTextData' OR  @SYSTABLESOURCE='COM_DocNumData' 
			 BEGIN 
			 
				 IF(@isInventory=1)				 
					 SET @TSQL=' SET @SOURCEDATA=(SELECT  TOP 1 '+@SYSCOLSOURCE+' FROM '+@SYSTABLESOURCE+' WITH(NOLOCK) WHERE INVDOCDETAILSID IN(SELECT INVDOCDETAILSID FROM  INV_DocDetails WITH(NOLOCK) WHERE COSTCENTERID='+CONVERT(NVARCHAR(300),@CostCenterID)+'
					 AND DOCID IN ('+CONVERT(NVARCHAR(400),@NodeID) + ')) )' 
			     ELSE
					 SET @TSQL=' SET @SOURCEDATA=(SELECT  TOP 1 '+@SYSCOLSOURCE+' FROM '+@SYSTABLESOURCE+' WITH(NOLOCK) WHERE ACCDOCDETAILSID IN(SELECT ACCDOCDETAILSID FROM  ACC_DocDetails WITH(NOLOCK) WHERE COSTCENTERID='+CONVERT(NVARCHAR(300),@CostCenterID)+'
					 AND DOCID IN ('+CONVERT(NVARCHAR(400),@NodeID) + ')) )' 		 
			 END 	 
			 
			 EXEC SP_EXECUTESQL @TSQL, @tempCode,@SOURCEDATA OUTPUT
			 
			  
			 IF @SYSCOLDEST='AccountId'
				SET @UPDATEAQL=@UPDATEAQL + @SYSCOLDEST +' = ' + ISNULL(@SOURCEDATA,'')
			 ELSE
			    SET @UPDATEAQL=@UPDATEAQL + @SYSCOLDEST+' = ' + ''''+ISNULL(@SOURCEDATA,'')+''''
			    
			 	 SET @UPDATEAQL=@UPDATEAQL + ','  
		 END 
		 ELSE
		 BEGIN
				 IF @CostCenterID=86
					SET @PRIMARYKEY='LEADID'
				 ELSE IF @CostCenterID=89
					SET @PRIMARYKEY='OPPORTUNITYID'	
				ELSE IF @CostCenterID=2
					SET @PRIMARYKEY='AccountID'	
			     ELSE IF @CostCenterID=73
					SET @PRIMARYKEY='CASEID'	
				 ELSE IF @CostCenterID=83
					SET @PRIMARYKEY='CUSTOMERID'
				 ELSE IF @CostCenterID=88
					SET @PRIMARYKEY='CampaignID'
				ELSE IF @CostCenterID=65
					SET @PRIMARYKEY='CONTACTID'		
				ELSE IF(@CostCenterID=94) 
					SET @PRIMARYKEY  = 'TenantID'
				ELSE IF(@CostCenterID=95) 
					SET @PRIMARYKEY  = 'ContractID'			
					
				 SET @tempCode='@SOURCEDATA NVARCHAR(300) OUTPUT'
			  
				 SET @TSQL=' SET @SOURCEDATA=(SELECT '+@SYSCOLSOURCE+' FROM '+@SYSTABLESOURCE+' WITH(NOLOCK) WHERE '+@PRIMARYKEY+'='+CONVERT(NVARCHAR(300),@NodeID)+')'
				 
				 print @TSQL
				  EXEC SP_EXECUTESQL @TSQL, @tempCode,@SOURCEDATA OUTPUT
				
				 IF @SYSCOLDEST='AccountId'
					SET @UPDATEAQL=@UPDATEAQL +  ' CUSTOMERID = ' + ''''+ISNULL(@SOURCEDATA,'')+''''
				 ELSE
				    SET @UPDATEAQL=@UPDATEAQL + @SYSCOLDEST+' = ' + ''''+ISNULL(@SOURCEDATA,'')+''''
			      
			 	 SET @UPDATEAQL=@UPDATEAQL + ','  
		 END
		
    SET @I=@I+1 
    END
    
    
    --update cc fields
      DECLARE @DisableDimension bit
	select @DisableDimension=CONVERT(bit,Value)  from com_costcenterpreferences WITH(NOLOCK)
	where name='DisableDimensionsatActivities' and costcenterid=@CostCenterID
	if(@DisableDimension is null)
		set @DisableDimension=1
	IF( @DisableDimension=1)
	BEGIN
		INSERT INTO #TBLCCFIELDS
		SELECT SYSCOLUMNNAME FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID=144 AND 
		LOCALREFERENCE=@CostCenterID AND ISCOLUMNINUSE=1 AND SYSCOLUMNNAME LIKE '%CCNID%'
		AND SYSCOLUMNNAME IN (	SELECT REPLACE(SYSCOLUMNNAME,'dc','') FROM ADM_COSTCENTERDEF C WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID AND 
			(SysColumnName LIKE '%CCNID%' OR 
			SysColumnName LIKE '%DCCCNID%') AND ((C.IsColumnUserDefined=1 OR C.IsCostCenterUserDefined=1)
			 AND C.IsColumnInUse=1 AND C.ISCOLUMNDELETED=0) )
 
     SET @TSQL=''
      SET @tempCode=''
     SET @SOURCEDATA=''
     SELECT @COUNT=COUNT(*),@I=1 FROM #TBLCCFIELDS
      WHILE @I<=@COUNT
      BEGIN
      SELECT @SYSCOLDEST=SYSCOL FROM #TBLCCFIELDS WHERE ID=@I 
			IF @CostCenterID>40000
			BEGIN
				 SET @tempCode='@SOURCEDATA NVARCHAR(300) OUTPUT' 
				  
				  IF(@isInventory=1)				 
					 SET @TSQL=' SET @SOURCEDATA=(SELECT  TOP 1 dc'+@SYSCOLDEST+' FROM COM_DocCCData WITH(NOLOCK) WHERE INVDOCDETAILSID IN(SELECT INVDOCDETAILSID FROM  INV_DocDetails WITH(NOLOCK) WHERE COSTCENTERID='+CONVERT(NVARCHAR(300),@CostCenterID)+'
					 AND DOCID IN ('+CONVERT(NVARCHAR(400),@NodeID) + ')) )' 
			     ELSE
					 SET @TSQL=' SET @SOURCEDATA=(SELECT  TOP 1 dc'+@SYSCOLDEST+' FROM COM_DocCCData WITH(NOLOCK) WHERE ACCDOCDETAILSID IN(SELECT ACCDOCDETAILSID FROM  ACC_DocDetails WITH(NOLOCK) WHERE COSTCENTERID='+CONVERT(NVARCHAR(300),@CostCenterID)+'
					 AND DOCID IN ('+CONVERT(NVARCHAR(400),@NodeID) + ')) )' 	
					  
				  EXEC SP_EXECUTESQL @TSQL, @tempCode,@SOURCEDATA OUTPUT
				  
				  SET @CCCCSQL=@CCCCSQL + @SYSCOLDEST+' = ' + ''''+ISNULL(@SOURCEDATA,'')+''''
				   SET @CCCCSQL=@CCCCSQL + ','  
			END
			ELSE
			BEGIN
				 SET @tempCode='@SOURCEDATA NVARCHAR(300) OUTPUT' 
				 SET @TSQL=' SET @SOURCEDATA=(SELECT '+@SYSCOLDEST+' FROM COM_CCCCData WITH(NOLOCK) WHERE  COSTCENTERID='+CONVERT(NVARCHAR(300),@CostCenterID)+' AND 
				 NODEID='+CONVERT(NVARCHAR(300),@NodeID)+')'
				 
				  EXEC SP_EXECUTESQL @TSQL, @tempCode,@SOURCEDATA OUTPUT 
				  
				  SET @CCCCSQL=@CCCCSQL + @SYSCOLDEST+' = ' + ''''+ISNULL(@SOURCEDATA,'')+''''
				  SET @CCCCSQL=@CCCCSQL + ','  
			END
      SET @I=@I+1
      END
    END		  
      
     if(len(@UPDATEAQL)>0)
     set @UPDATEAQL=SUBSTRING(@UPDATEAQL,1,LEN(@UPDATEAQL)-1) --ALPHA FIELDS
     
       if(len(@CCCCSQL)>0)
     set @CCCCSQL=SUBSTRING(@CCCCSQL,1,LEN(@CCCCSQL)-1) --CC FIELDS
     
     --IF(LEN(@CCCCSQL)>0)
     --SET  @UPDATEAQL =@UPDATEAQL + ',' +  @CCCCSQL 
     
 
	 SET @TSQL=''
	 IF LEN(@UPDATEAQL)>0
	 BEGIN
	 SET @TSQL=' UPDATE CRM_ACTIVITIES SET '+@UPDATEAQL+' WHERE COSTCENTERID='+CONVERT(NVARCHAR(300),@CostCenterID)+' AND 
				 NODEID='+CONVERT(NVARCHAR(300),@NodeID)
				 
	 EXEC (@TSQL)
	 
	 END
	 
	 SET @TSQL=''
	 IF LEN(@CCCCSQL)>0
	 BEGIN
	 SET @TSQL=' UPDATE CRM_ACTIVITIES SET '+@CCCCSQL+' WHERE COSTCENTERID='+CONVERT(NVARCHAR(300),@CostCenterID)+' AND 
				 NODEID='+CONVERT(NVARCHAR(300),@NodeID)
				 print @TSQL
	 EXEC (@TSQL)
	 
	 END
	 
	 
	 --CHECK IF REFNO IS EMPTY
	 IF EXISTS (SELECT * FROM CRM_ACTIVITIES WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID AND NODEID=@NodeID AND (REFNO  IS NULL OR REFNO=''))
	 BEGIN
			
			DECLARE @tablejoin NVARCHAR(MAX),@SelectedColumn NVARCHAR(400)
			SET @tablejoin=''
			SET @PRIMARYKEY  = ''
			SET @SelectedColumn=''

			IF(@CostCenterID=89) 
			BEGIN
				SET @tablejoin='CRM_Opportunities'
				SET @PRIMARYKEY  = 'OpportunityID'
				SET @SelectedColumn='Code'
			END
			ELSE IF(@CostCenterID=86) 
			BEGIN
				SET @tablejoin='CRM_LEADS'
				SET @PRIMARYKEY  = 'LeadID'
				SET @SelectedColumn='Code'
			END
			ELSE IF(@CostCenterID=2) 
			BEGIN
				SET @tablejoin='Acc_accounts'
				SET @PRIMARYKEY  = 'AccountID'
				SET @SelectedColumn='AccountCode'
			END
			ELSE IF(@CostCenterID=88) 
			BEGIN
				SET @tablejoin='CRM_Campaigns'
				SET @PRIMARYKEY  = 'Campaignid'
				SET @SelectedColumn='Code'
			END
			ELSE IF(@CostCenterID=73) 
			BEGIN
				SET @tablejoin='CRM_Cases'
				SET @PRIMARYKEY  = 'CaseID'
				SET @SelectedColumn='CaseNumber'
			END
			ELSE IF(@CostCenterID=83) 
			BEGIN
				SET @tablejoin='CRM_CUSTOMER'
				SET @PRIMARYKEY  = 'CustomerID'
				SET @SelectedColumn='CustomerCode'
			END
			ELSE IF(@CostCenterID=65) 
			BEGIN
				SET @tablejoin='Com_Contacts'
				SET @PRIMARYKEY  = 'ContactID'
				SET @SelectedColumn='FirstName'
			END
			
			ELSE IF(@CostCenterID=94) 
			BEGIN
				SET @tablejoin='REN_Tenant'
				SET @PRIMARYKEY  = 'TenantID'
				SET @SelectedColumn='FirstName'
			END
			ELSE IF(@CostCenterID=95) 
			BEGIN
				SET @tablejoin='Ren_Contract'
				SET @PRIMARYKEY  = 'ContractID'
				SET @SelectedColumn='ContractNumber'
			END
			ELSE IF(@CostCenterID>40000 and @CostCenterID<50000) 
			BEGIN
				DECLARE @InventoryTable nvarchar(300)
				IF((SELECT isInventory from ADM_DOCUMENTTYPES with(nolock) where CostCenterid=@CostCenterID)=1) --INVENTORY DOCUMENTS
				BEGIN
				set @tablejoin='INV_DOCDETAILS'
				END
				ELSE
				SET @tablejoin='ACC_DOCDETAILS'  
				
				SET @PRIMARYKEY  = 'DOCID'
				SET @SelectedColumn='VoucherNo'
			END
	       
			 SET @TSQL=''
			 SET @TSQL='SET @SOURCEDATA=(SELECT top 1 '+@SelectedColumn+' FROM '+@tablejoin+' WHERE  '+@PRIMARYKEY+'='+CONVERT(NVARCHAR(300),@NodeID)+')'
		 
			SET @tempCode='@SOURCEDATA NVARCHAR(300) OUTPUT' 	
					 
	        EXEC SP_EXECUTESQL @TSQL, @tempCode,@SOURCEDATA OUTPUT   
	        IF LEN(@SOURCEDATA)>0
	        BEGIN
				 UPDATE CRM_ACTIVITIES SET REFNO=@SOURCEDATA WHERE COSTCENTERID=@CostCenterID AND 
				 NODEID=@NodeID 
	        END
	 END
	 
	 
	 
	 
	 
	 --CHECK IF ACCOUNTID IS NULL 
	   IF(@CostCenterID>40000 and @CostCenterID<50000) 
	   BEGIN
			 IF EXISTS (SELECT * FROM CRM_ACTIVITIES WHERE COSTCENTERID=@CostCenterID AND NODEID=@NodeID AND (AccountID  IS NULL OR AccountID=0))
			 BEGIN 
			 
				set @tablejoin=''
				set @SOURCEDATA=''
				SET @PRIMARYKEY  = 'DOCID'
				IF((SELECT isInventory from ADM_DOCUMENTTYPES with(nolock) where CostCenterid=@CostCenterID)=1) --INVENTORY DOCUMENTS
				BEGIN
					SET @tablejoin='INV_DOCDETAILS'
				END
				ELSE
					SET @tablejoin='ACC_DOCDETAILS'  
					
				
				SET @TSQL=''
				SET @TSQL='SET @SOURCEDATA=(SELECT top 1 DebitAccount FROM '+@tablejoin+' WHERE  '+@PRIMARYKEY+'='+CONVERT(NVARCHAR(300),@NodeID)+')'

				SET @tempCode='@SOURCEDATA NVARCHAR(300) OUTPUT' 
				EXEC SP_EXECUTESQL @TSQL, @tempCode,@SOURCEDATA OUTPUT
				IF LEN(@SOURCEDATA)>0
				BEGIN
					UPDATE CRM_ACTIVITIES SET AccountID=@SOURCEDATA WHERE COSTCENTERID=@CostCenterID AND 
					NODEID=@NodeID
				END
			 END
	   END
	   ELSE IF EXISTS (SELECT * FROM CRM_ACTIVITIES WHERE COSTCENTERID=@CostCenterID AND NODEID=@NodeID AND (CUSTOMERID  IS NULL OR CUSTOMERID='')) --CHECK IF CUSTOMERNAME IS EMPTY		
	   BEGIN 
			SET @tablejoin=''
			SET @PRIMARYKEY  = ''
			SET @SelectedColumn=''

			IF(@CostCenterID=89) 
			BEGIN
				SET @tablejoin='CRM_Opportunities'
				SET @PRIMARYKEY  = 'OpportunityID'
				SET @SelectedColumn='COMPANY'
			END
			ELSE IF(@CostCenterID=86) 
			BEGIN
				SET @tablejoin='CRM_LEADS'
				SET @PRIMARYKEY  = 'LeadID'
				SET @SelectedColumn='COMPANY'
			END
			ELSE IF(@CostCenterID=2) 
			BEGIN
				SET @tablejoin='Acc_accounts'
				SET @PRIMARYKEY  = 'AccountID'
				SET @SelectedColumn='AccountCode'
			END
			ELSE IF(@CostCenterID=88) 
			BEGIN
				SET @tablejoin='CRM_Campaigns'
				SET @PRIMARYKEY  = 'Campaignid'
				SET @SelectedColumn='NAME'
			END
			ELSE IF(@CostCenterID=73) 
			BEGIN
				SET @tablejoin='CRM_Cases'
				SET @PRIMARYKEY  = 'CaseID'
				SET @SelectedColumn='CaseNumber'
			END
			ELSE IF(@CostCenterID=83) 
			BEGIN
				SET @tablejoin='CRM_CUSTOMER'
				SET @PRIMARYKEY  = 'CustomerID'
				SET @SelectedColumn='CustomerNAME'
			END
			ELSE IF(@CostCenterID=65) 
			BEGIN
				SET @tablejoin='Com_Contacts'
				SET @PRIMARYKEY  = 'ContactID'
				SET @SelectedColumn='FirstName'
			END
			
			ELSE IF(@CostCenterID=94) 
			BEGIN
				SET @tablejoin='REN_Tenant'
				SET @PRIMARYKEY  = 'TenantID'
				SET @SelectedColumn='FirstName'
			END
			ELSE IF(@CostCenterID=95) 
			BEGIN
				SET @tablejoin='Ren_Contract'
				SET @PRIMARYKEY  = 'ContractID'
				SET @SelectedColumn='ContractNumber'
			END
			  
			 SET @TSQL=''
			 SET @TSQL='SET @SOURCEDATA=(SELECT top 1 '+@SelectedColumn+' FROM '+@tablejoin+' WHERE  '+@PRIMARYKEY+'='+CONVERT(NVARCHAR(300),@NodeID)+')'
		 
			SET @tempCode='@SOURCEDATA NVARCHAR(300) OUTPUT' 
						 print @TSQL
	        EXEC SP_EXECUTESQL @TSQL, @tempCode,@SOURCEDATA OUTPUT
	        IF LEN(@SOURCEDATA)>0
	        BEGIN
				 UPDATE CRM_ACTIVITIES SET CUSTOMERID=@SOURCEDATA WHERE COSTCENTERID=@CostCenterID AND 
				 NODEID=@NodeID
	        END
	 END
	 
	 DROP TABLE #TBLCCFIELDS
	 DROP TABLE #TBL
	 
COMMIT TRANSACTION    
--ROLLBACK TRANSACTION  
 SET NOCOUNT OFF;     
RETURN 1
GO
