USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_ConvertCampaignLead]
	@CampaignID [int] = 0,
	@Leads [bit] = 0,
	@Opportunity [bit] = 0,
	@CompanyGUID [nvarchar](100),
	@UserName [nvarchar](100),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY 
SET NOCOUNT ON

  DECLARE @Dt float,@ParentCode nvarchar(200),@LeadStatusApprove bit, @IsCodeAutoGen bit,@CodePrefix NVARCHAR(300),@CodeNumber INT
  DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT
  DECLARE @SelectedIsGroup bit ,@SelectedNodeID INT,@IsGroup BIT
  DECLARE @CampaignCode NVARCHAR(300),@Code NVARCHAR(300),@LeadID INT,@OpportunityID INT
  DECLARE @CompanyName nvarchar(500),@Description nvarchar(500)
  DECLARE @ACOUNT INT,@I INT,@SOURCEDATA NVARCHAR(MAX),@DESTDATA NVARCHAR(MAX)
  DECLARE @return_value int,@LinkCostCenterID INT,@DIMID INT,@UpdateSql NVARCHAR(MAX)
 create table #temp1(prefix nvarchar(100),number INT, suffix nvarchar(100), code nvarchar(200), IsManualcode bit)
  
--SELECT @CampaignCode=Code,@CompanyName=Company,@Description=Description  FROM CRM_CAMPAIGNS WHERE CAMPAIGNID=@CampaignID

SET @Dt=convert(float,getdate())--Setting Current Date  

  SET @SelectedNodeID=1

---------------INSERT INTO LEADS TABLE
 	 IF (@Leads = 1)
   BEGIN
  
               --To Set Left,Right And Depth of Record  
    SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
    from CRM_LEADS with(NOLOCK) where LEADID=@SelectedNodeID  
      
    --IF No Record Selected or Record Doesn't Exist  
    if(@SelectedIsGroup is null)   
     select @SelectedNodeID=LeadID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
     from CRM_LEADS with(NOLOCK) where ParentID =0  
            
    if(@SelectedIsGroup = 1)--Adding Node Under the Group  
     BEGIN  
      UPDATE CRM_LEADS SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
      UPDATE CRM_LEADS SET lft = lft + 2 WHERE lft > @Selectedlft;  
      set @lft =  @Selectedlft + 1  
      set @rgt = @Selectedlft + 2  
      set @ParentID = @SelectedNodeID  
      set @Depth = @Depth + 1  
     END  
    else if(@SelectedIsGroup = 0)--Adding Node at Same level  
     BEGIN  
      UPDATE CRM_LEADS SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
      UPDATE CRM_LEADS SET lft = lft + 2 WHERE lft > @Selectedrgt;  
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
SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=86 and  Name='CodeAutoGen'  
SELECT @LeadStatusApprove=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=88 and  Name='LeadStatusWhileConvert'  

 --GENERATE CODE  
    IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1  
    BEGIN   
		--CALL AUTOCODEGEN 
		
		if(@SelectedNodeID is null)
		insert into #temp1
		EXEC [spCOM_GetCodeData] 86,1,''  
		else
		insert into #temp1
		EXEC [spCOM_GetCodeData] 86,@SelectedNodeID,''  
		
		select @Code=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 with(nolock)
  
    END  
    
  ---CHECKING AUTO GENERATE CODE
    IF @Code='' OR @Code IS NULL 
    begin
      SET @Code=@CampaignCode
    end
 
	IF NOT EXISTS (SELECT ConvertFromCampaignID FROM CRM_LEADS WITH(nolock) WHERE ConvertFromCampaignID=@CampaignID)  
	BEGIN  
		
			CREATE TABLE #TBLTEMP(ID  INT IDENTITY(1,1),BASECOLUMN NVARCHAR(300),LINKCOLUMN NVARCHAR(300))
			INSERT INTO #TBLTEMP
			 select l.SysColumnName, b.SysColumnName 
			 from COM_DocumentLinkDetails dl with(nolock)
			 left join ADM_CostCenterDef b with(nolock) on dl.CostCenterColIDBase=b.CostCenterColID
			 left join ADM_CostCenterDef l with(nolock) on dl.CostCenterColIDLinked=l.CostCenterColID
			where DocumentLinkDeFID in (select DocumentLinkDeFID from COM_DocumentLinkDef with(nolock) where CostCenterIDBase=88 )
			and l.costcenterid=86
				 
			
		 
			DELETE FROM #TBLTEMP WHERE LINKCOLUMN IN ('FirstName','Code','Mode','StatusID','MiddleName','LastName','JobTitle','Phone1','Phone2','Email','Fax','Department','SalutationID')
		 
		 SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTEMP with(nolock)    
	--FIRST INSERT INTO MAIN TABLE 
			SET @DESTDATA=''
			SET @SOURCEDATA=''
			SET @OpportunityID=0
			SET @SOURCEDATA=' INSERT INTO CRM_LEADS (ConvertFromCampaignID,Code,CodePrefix,CodeNumber,StatusID,Mode,' 
			SET @DESTDATA='SELECT '+CONVERT(NVARCHAR(300),@CampaignID) +','''+@Code+''','''+isnull(@CodePrefix,'')+''','+CONVERT(NVARCHAR(300),isnull(@CodeNumber,0)) +',1,0,'  
			 --MAIN TABLE 
				WHILE @I<=@ACOUNT
				BEGIN 
				IF(  exists (SELECT * FROM #TBLTEMP with(nolock) WHERE ID=@I and 
				(BASECOLUMN NOT likE '%CCNID%' AND BASECOLUMN NOT likE '%caAlpha%' AND
				LINKCOLUMN NOT likE '%CCNID%' AND LINKCOLUMN NOT likE '%LDAlpha%')))
				begin
						 
					SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTEMP with(nolock) WHERE ID=@I) 				 
					IF((SELECT LINKCOLUMN FROM #TBLTEMP with(nolock) WHERE ID=@I)='Company')
						 SET @DESTDATA =@DESTDATA + 'CRM_CAMPAIGNS.'+(SELECT LINKCOLUMN FROM #TBLTEMP with(nolock) WHERE ID=@I)   
					 else
					   SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTEMP with(nolock) WHERE ID=@I)
					   
					--IF(@I<>@ACOUNT)
					BEGIN
						 SET @SOURCEDATA =@SOURCEDATA + ','
						 SET @DESTDATA =@DESTDATA + ','
						  
					END
				end	  
				SET @I=@I+1
				END
				
				if((select COUNT(*) from  #TBLTEMP with(nolock))=0)
				begin 
					set @SOURCEDATA =@SOURCEDATA +'Company,Date,'
					set @DESTDATA =@DESTDATA +''''+@Code+''','+convert(nvarchar,convert(float,getdate()))+','
				end 
				 IF(LEN(@SOURCEDATA)>0)
				 BEGIN
						 SET @SOURCEDATA=SUBSTRING(@SOURCEDATA,1,LEN(@SOURCEDATA)-1)	
						 SET @DESTDATA=SUBSTRING(@DESTDATA,1,LEN(@DESTDATA)-1)	
				 END 
				 
				set @SOURCEDATA=@SOURCEDATA+ ',[Depth], [ParentID],  [lft],  [rgt],  [IsGroup],[CompanyGUID],  [GUID],  [CreatedBy],  [CreatedDate] )'  		
				set @DESTDATA=@DESTDATA + + ',' + CONVERT(NVARCHAR(300),@Depth) + ',' +CONVERT(NVARCHAR(300),@ParentID) + ',' +CONVERT(NVARCHAR(300),@lft)+ ',' + 
				CONVERT(NVARCHAR(300),@rgt) + ',' + CONVERT(NVARCHAR(300),@IsGroup) + ',''' + CONVERT(NVARCHAR(300),@CompanyGUID) + ''',' + 'newid()'
				+ ',CRM_CAMPAIGNS.CreatedBy' +  ', CRM_CAMPAIGNS.createddate' 
				
				SET  @SOURCEDATA=@SOURCEDATA +  @DESTDATA + ' FROM CRM_CAMPAIGNS with(nolock)  
				 WHERE CRM_CAMPAIGNS.CAMPAIGNID='+CONVERT(NVARCHAR(300),@CampaignID) 
				 PRINT @SOURCEDATA
				 
				 EXEC (@SOURCEDATA) 
			     SELECT @LEADID=LEADID,@Code=Code,@CompanyName=Company FROM CRM_LEADS WITH(nolock) WHERE ConvertFromCampaignID=@CampaignID
			     
			   INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
				  VALUES(86,@OpportunityID,newid(),  @USERNAME, @Dt) 
				  
				 SET @SOURCEDATA=''
				 SET @DESTDATA=''
				 SET @ACOUNT=0
				 
				 SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTEMP with(nolock) 
				 
				 SET @SOURCEDATA=' INSERT INTO CRM_LEADSEXTENDED (LeadID,'
				 SET @DESTDATA='SELECT '+CONVERT(NVARCHAR(300),@LEADID) +','
				 --EXTENDED TABLE
				WHILE @I<=@ACOUNT
				BEGIN 
				IF( exists (SELECT * FROM #TBLTEMP with(nolock) WHERE ID=@I and (BASECOLUMN likE '%opAlpha%' AND LINKCOLUMN  likE '%LDAlpha%')))
				begin
			 
					SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTEMP with(nolock) WHERE ID=@I) 				 
				    SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTEMP with(nolock) WHERE ID=@I)
					   
				 
					BEGIN
						 SET @SOURCEDATA =@SOURCEDATA + ','
						 SET @DESTDATA =@DESTDATA + ','
						  
					END
				end	  
				SET @I=@I+1
				END
				
				 --IF(LEN(@SOURCEDATA)>0)
				 BEGIN
						 SET @SOURCEDATA=SUBSTRING(@SOURCEDATA,1,LEN(@SOURCEDATA)-1)	
						 SET @DESTDATA=SUBSTRING(@DESTDATA,1,LEN(@DESTDATA)-1)	
				 END 
				 
				set @SOURCEDATA=@SOURCEDATA+ ',[CreatedBy],  [CreatedDate] )'  		
				set @DESTDATA=@DESTDATA + + ',CRM_CAMPAIGNSEXTENDED.CreatedBy' +  ', CRM_CAMPAIGNSEXTENDED.createddate' 
				
				SET  @SOURCEDATA=@SOURCEDATA +  @DESTDATA + ' FROM CRM_CAMPAIGNSEXTENDED with(nolock)   
				 WHERE CRM_CAMPAIGNSEXTENDED.CAMPAIGNID='+CONVERT(NVARCHAR(300),@CampaignID) 
				 PRINT @SOURCEDATA	
		         EXEC(@SOURCEDATA)
		       
		        SET @SOURCEDATA=''
				 SET @DESTDATA=''
				 SET @ACOUNT=0
				 
				 SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTEMP with(nolock)  
				 
			 
				 --CCDATA TABLE
				WHILE @I<=@ACOUNT
				BEGIN 
			 
				IF( exists (SELECT * FROM #TBLTEMP with(nolock) WHERE ID=@I and  (BASECOLUMN likE '%CCNID%' AND LINKCOLUMN likE '%CCNID%') ))
				begin
				 
			 
					SET @SOURCEDATA= 'UPDATE COM_CCCCDATA SET '+(SELECT BASECOLUMN FROM #TBLTEMP with(nolock) WHERE ID=@I)+'=(
					SELECT '+(SELECT LINKCOLUMN FROM #TBLTEMP with(nolock) WHERE ID=@I)+' FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=88 AND 
					NODEID='+CONVERT(NVARCHAR,@CampaignID) +') WHERE COSTCENTERID=86 AND [NodeID]='+CONVERT(NVARCHAR,@OpportunityID)  
				    EXEC(@SOURCEDATA)
				    
				    SET @SOURCEDATA=''
					   
				 
				end	  
				SET @I=@I+1
				END
				 
    
	  	 IF(@LEADID>0)
		 BEGIN
			 
	         update CRM_LEADS set ConvertFromCampaignID=@CampaignID where leadID=@leadID

			SELECT @LinkCostCenterID=isnull([Value],0) FROM COM_CostCenterPreferences WITH(NOLOCK) 
			WHERE FeatureID=86 AND [Name]='LinkDimension'
 
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
					--@return_value
					UPDATE [CRM_LEADS]
					SET CClEADID=@return_value
					WHERE leadID=@leadID
					
					  
					
					  
					  IF(EXISTS(SELECT VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID=86 AND NAME='LinkDimension'))
					  BEGIN
							
							SET @DIMID=0
							SELECT @DIMID=VALUE-50000 FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID=86 AND NAME='LinkDimension'
							IF(@DIMID>0)
							BEGIN
									SET @UpdateSql=' UPDATE COM_CCCCDATA SET CCNID'+CONVERT(NVARCHAR(30),@DIMID)+'=
									(SELECT CCLEADID FROM CRM_LEADS with(nolock) WHERE LEADID='+convert(nvarchar,@leadID) + ') 
													WHERE NodeID = '+convert(nvarchar,@leadID) + ' AND CostCenterID = 86'
									  exec(@UpdateSql)  
							END
					  END		
					  
					
			END
			
			END
		END
   END
   
   --INSERT INTO OPPORTUNITY TABLE
   
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
SELECT @IsCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=89 and  Name='CodeAutoGen'  

 --GENERATE CODE  
    IF @IsCodeAutoGen IS NOT NULL AND @IsCodeAutoGen=1  
    BEGIN   
  
		if(@SelectedNodeID is null)
		insert into #temp1
		EXEC [spCOM_GetCodeData] 89,1,''  
		else
		insert into #temp1
		EXEC [spCOM_GetCodeData] 89,@SelectedNodeID,''  
		--select * from #temp1
		select @Code=code,@CodePrefix= prefix, @CodeNumber=number from #temp1 with(nolock)
    END  
    
  ---CHECKING AUTO GENERATE CODE
    IF @Code='' OR @Code IS NULL 
    begin
      SET @Code=@CampaignCode
    end
 
	IF NOT EXISTS (SELECT ConvertFromCampaignID FROM CRM_Opportunities WITH(nolock) WHERE ConvertFromCampaignID=@CampaignID)  
	BEGIN  
		
			CREATE TABLE #TBLTMP(ID  INT IDENTITY(1,1),BASECOLUMN NVARCHAR(300),LINKCOLUMN NVARCHAR(300))
			INSERT INTO #TBLTMP
			 select 
			 l.SysColumnName, b.SysColumnName 
			 from COM_DocumentLinkDetails dl WITH(nolock)
			 left join ADM_CostCenterDef b WITH(nolock) on dl.CostCenterColIDBase=b.CostCenterColID
			 left join ADM_CostCenterDef l WITH(nolock) on dl.CostCenterColIDLinked=l.CostCenterColID
			where DocumentLinkDeFID in (select DocumentLinkDeFID from COM_DocumentLinkDef WITH(nolock) where CostCenterIDBase=88   )
			and l.costcenterid=89
				 
			
			DELETE FROM #TBLTMP WHERE LINKCOLUMN IN ('FirstName','Code','StatusID','MiddleName','LastName','JobTitle','Phone1','Phone2','Email','Fax','Department','SalutationID')
			
		 SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTMP with(nolock)    
	--FIRST INSERT INTO MAIN TABLE 
			SET @DESTDATA=''
			SET @SOURCEDATA=''
			SET @OpportunityID=0
			SET @SOURCEDATA=' INSERT INTO crm_opportunities (DetailsContactID,ConvertFromCampaignID,Code,CodePrefix,CodeNumber,StatusID,' 
			SET @DESTDATA='SELECT 1,'+CONVERT(NVARCHAR(300),@CampaignID) +','''+@Code+''','''+isnull(@CodePrefix,'')+''','+CONVERT(NVARCHAR(300),isnull(@CodeNumber,0)) +',1,'  
			 --MAIN TABLE 
				WHILE @I<=@ACOUNT
				BEGIN
				
				IF(  exists (SELECT * FROM #TBLTMP with(nolock) WHERE ID=@I and (BASECOLUMN NOT likE '%CCNID%' AND BASECOLUMN NOT likE '%opAlpha%' AND
				LINKCOLUMN NOT likE '%CCNID%' AND LINKCOLUMN NOT likE '%LDAlpha%')))
				begin
				 
					SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTMP with(nolock) WHERE ID=@I) 				 
					IF((SELECT LINKCOLUMN FROM #TBLTMP with(nolock) WHERE ID=@I)='Company')
						 SET @DESTDATA =@DESTDATA + 'CRM_CAMPAIGNS.'+(SELECT LINKCOLUMN FROM #TBLTMP with(nolock) WHERE ID=@I)   
					 else
					   SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTMP with(nolock) WHERE ID=@I)
					   
					--IF(@I<>@ACOUNT)
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
				 
				set @SOURCEDATA=@SOURCEDATA+ ',[Depth], [ParentID],  [lft],  [rgt],  [IsGroup],[CompanyGUID],  [GUID],  [CreatedBy],  [CreatedDate] )'  		
				set @DESTDATA=@DESTDATA + + ',' + CONVERT(NVARCHAR(300),@Depth) + ',' +CONVERT(NVARCHAR(300),@ParentID) + ',' +CONVERT(NVARCHAR(300),@lft)+ ',' + 
				CONVERT(NVARCHAR(300),@rgt) + ',' + CONVERT(NVARCHAR(300),@IsGroup) + ',''' + CONVERT(NVARCHAR(300),@CompanyGUID) + ''',' + 'newid()'
				+ ',CRM_CAMPAIGNS.CreatedBy' +  ', CRM_CAMPAIGNS.createddate' 
				
				SET  @SOURCEDATA=@SOURCEDATA +  @DESTDATA + ' FROM CRM_CAMPAIGNS with(nolock)   
				 WHERE CRM_CAMPAIGNS.CAMPAIGNID='+CONVERT(NVARCHAR(300),@CampaignID) 
				 PRINT @SOURCEDATA
				 
				 EXEC (@SOURCEDATA) 
			     SELECT @OpportunityID=OpportunityID,@Code=Code,@CompanyName=Company FROM crm_opportunities WITH(nolock) WHERE ConvertFromCampaignID=@CampaignID
			     
			   INSERT INTO COM_CCCCDATA ([CostCenterID] ,[NodeID] ,[Guid],[CreatedBy],[CreatedDate])
				  VALUES(89,@OpportunityID,newid(),  @USERNAME, @Dt) 
				  
				 SET @SOURCEDATA=''
				 SET @DESTDATA=''
				 SET @ACOUNT=0
				 
				 SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTMP with(nolock) 
				 
				 SET @SOURCEDATA=' INSERT INTO crm_opportunitiesEXTENDED (OpportunityID,'
				 SET @DESTDATA='SELECT '+CONVERT(NVARCHAR(300),@OpportunityID) +','
				 --EXTENDED TABLE
				WHILE @I<=@ACOUNT
				BEGIN 
				IF( exists (SELECT * FROM #TBLTMP with(nolock) WHERE ID=@I and (BASECOLUMN likE '%opAlpha%' AND LINKCOLUMN  likE '%LDAlpha%')))
				begin
			 
					SET @SOURCEDATA= @SOURCEDATA + (SELECT BASECOLUMN FROM #TBLTMP with(nolock) WHERE ID=@I) 				 
				    SET @DESTDATA= @DESTDATA + (SELECT LINKCOLUMN FROM #TBLTMP with(nolock) WHERE ID=@I)
					   
				 
					BEGIN
						 SET @SOURCEDATA =@SOURCEDATA + ','
						 SET @DESTDATA =@DESTDATA + ','
						  
					END
				end	  
				SET @I=@I+1
				END
				
				 --IF(LEN(@SOURCEDATA)>0)
				 BEGIN
						 SET @SOURCEDATA=SUBSTRING(@SOURCEDATA,1,LEN(@SOURCEDATA)-1)	
						 SET @DESTDATA=SUBSTRING(@DESTDATA,1,LEN(@DESTDATA)-1)	
				 END 
				 
				set @SOURCEDATA=@SOURCEDATA+ ',[CreatedBy],  [CreatedDate] )'  		
				set @DESTDATA=@DESTDATA + + ',CRM_CAMPAIGNSEXTENDED.CreatedBy' +  ', CRM_CAMPAIGNSEXTENDED.createddate' 
				
				SET  @SOURCEDATA=@SOURCEDATA +  @DESTDATA + ' FROM CRM_CAMPAIGNSEXTENDED with(nolock)   
				 WHERE CRM_CAMPAIGNSEXTENDED.CAMPAIGNID='+CONVERT(NVARCHAR(300),@CampaignID) 
				 PRINT @SOURCEDATA	
		         EXEC(@SOURCEDATA)
		       
		        SET @SOURCEDATA=''
				 SET @DESTDATA=''
				 SET @ACOUNT=0
				 
				 SELECT @I=1,@ACOUNT=COUNT(*) FROM #TBLTMP with(nolock)  
				 
			 
			--CCDATA TABLE
			WHILE @I<=@ACOUNT
			BEGIN 
			 
				IF( exists (SELECT * FROM #TBLTMP with(nolock) WHERE ID=@I and  (BASECOLUMN likE '%CCNID%' AND LINKCOLUMN likE '%CCNID%') ))
				begin
				 
			 
					SET @SOURCEDATA= 'UPDATE COM_CCCCDATA SET '+(SELECT BASECOLUMN FROM #TBLTMP with(nolock) WHERE ID=@I)+'=(
					SELECT '+(SELECT LINKCOLUMN FROM #TBLTMP with(nolock) WHERE ID=@I)+' FROM COM_CCCCDATA with(nolock) WHERE COSTCENTERID=88 AND 
					NODEID='+CONVERT(NVARCHAR,@CampaignID) +') WHERE COSTCENTERID=89 AND [NodeID]='+CONVERT(NVARCHAR,@OpportunityID)  
				    EXEC(@SOURCEDATA)
				    
				    SET @SOURCEDATA=''
					   
				 
				end	  
				SET @I=@I+1
			END
				 
	  	 IF(@OpportunityID>0)
		 BEGIN
			 
	         update crm_opportunities set Mode=4,ConvertFromCampaignID=@CampaignID where OpportunityID=@OpportunityID
	         
            --DECLARE @return_value int,@LinkCCID INT
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
					--@return_value
					UPDATE [CRM_Opportunities]
					SET CCOpportunityID=@return_value
					WHERE OpportunityID=@OpportunityID
					
					  
					
					  
					  IF(EXISTS(SELECT VALUE FROM COM_COSTCENTERPREFERENCES WITH(NOLOCK) WHERE COSTCENTERID=89 AND NAME='LinkDimension'))
					  BEGIN
							--DECLARE @DIMID INT,@UpdateSql NVARCHAR(MAX)
							SET @DIMID=0
							SELECT @DIMID=VALUE-50000 FROM COM_COSTCENTERPREFERENCES WITH(NOLOCK) WHERE COSTCENTERID=89 AND NAME='LinkDimension'
							IF(@DIMID>0)
							BEGIN
									SET @UpdateSql=' UPDATE COM_CCCCDATA SET CCNID'+CONVERT(NVARCHAR(30),@DIMID)+'=
									(SELECT CCOpportunityID FROM CRM_Opportunities WITH(NOLOCK) WHERE OpportunityID='+convert(nvarchar,@OpportunityID) + ') 
													WHERE NodeID = '+convert(nvarchar,@OpportunityID) + ' AND CostCenterID = 89'
									  exec(@UpdateSql)  
							END
					  END		
					  
					
			END
			
			END
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
