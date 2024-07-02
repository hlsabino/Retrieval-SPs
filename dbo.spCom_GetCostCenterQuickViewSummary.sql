USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_GetCostCenterQuickViewSummary]
	@CostCenterID [int],
	@NodeID [nvarchar](max),
	@ShowInCCID [int],
	@Date [datetime],
	@CCXML [nvarchar](max) = NULL,
	@AccountID [int],
	@QuickViewID [int],
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY              
SET NOCOUNT ON              
              
   --Declaration Section              
   declare @tempgroup nvarchar(max),@TempSQL nvarchar(max),@salescol nvarchar(max),@IsAddressDisplayed bit
   Declare @HasAccess bit,@Primarycol varchar(50),@CostCenterTableName nvarchar(50),@CC int ,@Unappstat bit             
   Declare @TableName nvarchar(50),@ColCostCenterPrimary varchar(50),@SQL nvarchar(max),@Where nvarchar(max)              
   Declare @CostCenterColID INT,@Cnt int,@I INT,@STRJOIN nvarchar(max),@strColumns nvarchar(max) , @strGroupBy nvarchar(max),@strIDCols nvarchar(max)
   Declare @SysColumnName nvarchar(50),@UserColumnName nvarchar(50), @ColumnResourceData nvarchar(200),@IsColumnUserDefined BIT,@ColumnCostCenterID INT              
   Declare @ColumnDataType nvarchar(50), @tempWhere nvarchar(max), @Dt float,@Nid INT
   	declare @QOH FLOAT,@HOLDQTY FLOAT,@CommittedQTY FLOAT,@RESERVEQTY FLOAT,@AvgRate FLOAT,@BalQOH FLOAT,@TotalReserve float
   declare @EmpAsOnStatus NVARCHAR(500)
   SET @EmpAsOnStatus=''
   set @salescol=''
   set @strIDCols=''
   set @IsAddressDisplayed=0
     SET @Dt=convert(float,getdate())      
   --Check for manadatory paramters              
   if(@CostCenterID < 1)              
    RAISERROR('-100',16,1)              
              
    set @tempWhere=''      
                 
   --User acces check              
   --SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)              
         
   set @tempgroup=''      
   --Quick view not working in landing page 
   --IF @HasAccess=0              
   --BEGIN                
   -- RAISERROR('-105',16,1)              
   --END               

    --Create temporary table to read xml data into table              
    DECLARE @tblList AS TABLE (ID int identity(1,1),CostCenterColID INT,Param1 NVARCHAR(MAX))                
	DECLARE @QID INT,@Param1 NVARCHAR(MAX)
	
	IF (@QuickViewID IS NOT NULL AND @QuickViewID != 0 )
	BEGIN
		SET @QID=@QuickViewID
	END
	ELSE
	BEGIN
		SELECT @QID=QM.QID FROM ADM_QuickViewDefn Q with(nolock), ADM_QuickViewDefnUserMap QM with(nolock)
		WHERE Q.CostCenterID=@CostCenterID AND Q.QID=QM.QID AND QM.ShowCCID=@ShowInCCID
		AND (QM.RoleID=@RoleID OR QM.UserID=@UserID OR QM.GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE RoleID=@RoleID OR UserID=@UserID))
	END

	IF @QID IS NULL
	BEGIN
		RETURN -1
	END
	ELSE
	
	--Read CostCenterColUMNS FROM  QuickView into temporary table              
	INSERT INTO @tblList              
	select QDV.CostCenterColID,case when (QDV.CostCenterColID=26428 OR QDV.CostCenterColID=50453 OR QDV.CostCenterColID=-11401 OR QDV.CostCenterColID=-11402 OR QDV.CostCenterColID=-11393 OR QDV.CostCenterColID=-11398 OR QDV.CostCenterColID=-11399) then QDV.[Description] when cd.CostCenterID=110 and cd.CostCenterID<>@CostCenterID then '#Address#' else QDV.Param1 end 
	from ADM_QuickViewDefn QDV WITH(NOLOCK)   
	LEFT JOIN ADM_Costcenterdef cd WITH(NOLOCK) on cd.CostCenterColID=QDV.CostCenterColID       
	where QDV.QID=@QID              
	order by QDV.ColumnOrder 
	
	declare @DocsList nvarchar(1000),@AccWhere nvarchar(MAX),@AccJoin nvarchar(MAX),@InvJoin nvarchar(MAX)

	if(@CostCenterID=2)
	begin
		declare @includepdc nvarchar(10),@includeunposted nvarchar(10)
		set @AccWhere=''
		set @AccJoin=''
		set @InvJoin=''
				
		select @includepdc=value from adm_globalpreferences with(nolock)
		where name='IncludePDCs'
		
		select @includeunposted=value from adm_globalpreferences with(nolock)
		where name='IncludeUnPostedDocs'
		
		if(@includepdc='true')
		begin
			if(@includeunposted<>'true')
				set @AccWhere=@AccWhere+' and ((DocumentType not in(14,19) and StatusID=369) or (DocumentType in(14,19) and StatusID=370))'
			else
				set @AccWhere=@AccWhere+' and (DocumentType not in(14,19) or (DocumentType in(14,19) and StatusID=370))'
		end	
		else
			set @AccWhere=@AccWhere+' and DocumentType not in(14,19)'
			
		if(@includeunposted<>'true' and @includepdc<>'true')
			set @AccWhere=@AccWhere+' and StatusID=369'
			
		if @CCXML!='' and exists (select LastSRateDocs from ADM_QuickViewDefn WITH(NOLOCK) where QID=@QID and LastSRateDocs is not null and LastSRateDocs!='')
		begin
			declare @XML xml,@XML2 xml
			set @XML=@CCXML
			select @XML2=LastSRateDocs from ADM_QuickViewDefn WITH(NOLOCK) where QID=@QID
			if exists (select 1 from @XML2.nodes('/X/LW') as DATA(X))
				select @AccJoin=@AccJoin+' and DCC.dcCCNID2 in ('+X.value('@ID','nvarchar(max)')+')' from @XML.nodes('/XML/Loc') as DATA(X)
			if exists (select 1 from @XML2.nodes('/X/DW') as DATA(X))
				select @AccJoin=@AccJoin+' and DCC.dcCCNID1 in ('+X.value('@ID','nvarchar(max)')+')' from @XML.nodes('/XML/Div') as DATA(X)
			if @AccJoin!=''
			begin
				set @InvJoin=' join COM_DocCCDATA DCC with(nolock) on DCC.InvDocDetailsID=D.InvDocDetailsID '+@AccJoin
				set @AccJoin=' join COM_DocCCDATA DCC with(nolock) on DCC.AccDocDetailsID=D.AccDocDetailsID '+@AccJoin
			end
		end
	end
    ELSE if(@CostCenterID=3 and exists(select * from @tblList where CostCenterColID =22821 or CostCenterColID between 22793 and 22799))
    BEGIN
		DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId INT)     
		declare @UOMID INT ,@CCWHERE nvarchar(max),@OrderBY nvarchar(max),@CCname  nvarchar(max)
		set @XML=@CCXML
		   INSERT INTO @tblCC(CostCenterID,NodeId)      
		   SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')      
		   FROM @XML.nodes('/XML/Row') as Data(X)      
		           
		  select @UOMID=UOMID from INV_Product a WITH(NOLOCK)               
		  WHERE ProductID = @NodeID      
		          
		   set @WHERE=' and (ProductID='+convert(nvarchar,@NodeID)+' or ProductID=1)'       
		   set @CCWHERE=' and ProductID='+convert(nvarchar,@NodeID)       
		   set @WHERE=@WHERE+' and ('      
		   set @OrderBY=',ProductID Desc,AccountID Desc'      
		   if exists(select CostCenterID from @tblCC where CostCenterID=2)      
		   begin      
			select @Nid=NodeId from @tblCC where CostCenterID=2      
			set @WHERE=@WHERE+' AccountID ='+convert(nvarchar,@Nid)+'  or '       
			set @CCWHERE=@CCWHERE+' and AccountID='+convert(nvarchar,@Nid)      
		   end      
		   else      
			set @CCWHERE=@CCWHERE+' and AccountID=0'      
		          
		   set @WHERE=@WHERE+' AccountID=0)'       
		         
		   Set @I=50000       
		   SELECT  @CNT=MAX(FEATUREID) FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID> 50000     
		   while(@I<@CNT)      
		   begin      
			set @I=@I+1   
			IF EXISTS (SELECT  FEATUREID FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID=@I)  
			BEGIN 
				set @OrderBY=@OrderBY+',CCNID'+convert(nvarchar,@I-50000)+' Desc '      
				set @CCname='CCNID'+convert(nvarchar,@I-50000)+'=' 
			     
				set @WHERE=@WHERE+' and ('      
				if exists(select CostCenterID from @tblCC where CostCenterID=@I)      
				begin      
				 select @Nid=NodeId from @tblCC where CostCenterID=@I      
				 set @WHERE=@WHERE+@CCname+convert(nvarchar,@Nid)+' or '      
				 set @CCWHERE=@CCWHERE+' and '+@CCname+convert(nvarchar,@Nid)           
				end      
				else      
				 set @CCWHERE=@CCWHERE+' and '+@CCname+'0'       
		           
				set @WHERE=@WHERE+@CCname+'0)'   
			END       
		   end     
    
    END
   SET @strColumns =''              
   SET @STRJOIN =''              
   SET @strGroupBy=''      
   --Get TableName of CostCenter              
   SELECT @TableName=TableName FROM ADM_Features with(nolock) WHERE FeatureID=@CostCenterID
   --print  @TableName              
   SET @STRJOIN=' FROM '+@TableName+' A WITH(NOLOCK) '              
         
   --Set Primary Column              
   set @Primarycol='A.NodeID'              
   if(@CostCenterID=3)              
   set @Primarycol='A.ProductID'              
   if(@CostCenterID=2)              
   set @Primarycol='A.AccountID'              
   if(@CostCenterID=16)              
   set @Primarycol='A.BatchID'    
   if(@CostCenterID=7)              
   set @Primarycol='A.UserID'          
   if(@CostCenterID=71)              
   set @Primarycol='A.ResourceID'       
   if(@CostCenterID=6)              
   set @Primarycol='A.RoleID'              
   if(@CostCenterID=74)              
   set @Primarycol='A.AssetClassID'        
   if(@CostCenterID=75)              
   set @Primarycol='A.DeprBookID'       
   if(@CostCenterID=77)              
   set @Primarycol='A.PostingGroupID'       
   if(@CostCenterID=72)              
   set @Primarycol='A.AssetID'       
    if(@CostCenterID=80)              
   set @Primarycol='A.ResourceID'       
     if(@CostCenterID=81)              
   set @Primarycol='A.ContractTemplID'       
       if(@CostCenterID=83)              
   set @Primarycol='A.CustomerID'       
    if(@CostCenterID=84)              
   set @Primarycol='A.SvcContractID'      
    if(@CostCenterID=76)              
   set @Primarycol='A.BOMID'       
    if(@CostCenterID=101)              
   set @Primarycol='A.BudgetDefID'       
    if(@CostCenterID=86)              
   set @Primarycol='A.LeadID'       
    if(@CostCenterID=89)              
   set @Primarycol='A.OpportunityID'       
   if(@CostCenterID=73)      
   set @Primarycol='A.CaseID'      
    if(@CostCenterID=65)              
   set @Primarycol='A.ContactID'     
    if(@CostCenterID=88)              
   set @Primarycol='A.CampaignID'      
  if(@CostCenterID=90)              
   set @Primarycol='A.SFReportID'   
   if(@CostCenterID=92)              
   set @Primarycol='A.NodeID'   
     if(@CostCenterID=93)              
   set @Primarycol='A.UnitID'     
    if(@CostCenterID=94)              
   set @Primarycol='A.TenantID'     
    if(@CostCenterID=95)              
   set @Primarycol='A.ContractID'     
   if(@CostCenterID=103)              
   set @Primarycol='A.ContractID'     
   if(@CostCenterID=104)              
   set @Primarycol='A.ContractID'      
    
   if(@CostCenterID=3)              
    SET @STRJOIN=@STRJOIN+'JOIN INV_ProductExtended X with(nolock) ON A.ProductID=X.ProductID'         
   if(@CostCenterID=2)                 
    SET @STRJOIN=@STRJOIN+'JOIN ACC_AccountsExtended X with(nolock) ON A.AccountID=X.AccountID'     
   if(@CostCenterId=72)              
    SET @STRJOIN=@STRJOIN+'JOIN ACC_AssetsExtended X with(nolock) ON A.AssetID=X.AssetID'              						
   if(@CostCenterID=76)                 
    SET @STRJOIN=@STRJOIN+'JOIN PRD_BillOfMaterialExtended X with(nolock) ON A.BOMID=X.BOMID'           
     if(@CostCenterId=83)              
    SET @STRJOIN=@STRJOIN+'JOIN CRM_CustomerExtended X with(nolock) ON A.CustomerID=X.CustomerID'            
  if(@CostCenterId=88)              
    SET @STRJOIN=@STRJOIN+'JOIN CRM_CampaignsExtended X with(nolock) ON A.CampaignID=X.CampaignID'   
     if(@CostCenterId=65)              
    SET @STRJOIN=@STRJOIN+'JOIN COM_ContactsExtended X with(nolock) ON A.ContactID=X.ContactID'            
   if(@CostCenterId=94)              
    SET @STRJOIN=@STRJOIN+'JOIN REN_TenantExtended X with(nolock) ON A.TenantID=X.TenantID'       
   if(@CostCenterId=92)              
    SET @STRJOIN=@STRJOIN+'JOIN REN_PropertyExtended X with(nolock) ON A.NodeID=X.NodeID'       
   if(@CostCenterId=86)              
    SET @STRJOIN=@STRJOIN+' LEFT JOIN CRM_CONTACTS CON with(nolock) ON CON.FEATUREPK=A.LEADID AND CON.FEATUREID=86 JOIN CRM_LEADSExtended X with(nolock) ON A.LEADID=X.LEADID'  
       
          
   --Set loop initialization varaibles              
   SELECT @I=1, @Cnt=count(*) FROM @tblList                
            --print @Cnt  
   SET @CC=0               
   WHILE(@I<=@Cnt)                
   BEGIN              
    SELECT @CostCenterColID=CostCenterColID,@Param1=Param1 FROM @tblList WHERE ID=@I                
    SET @I=@I+1              
    SELECT @SysColumnName=SysColumnName,@UserColumnName=UserColumnName, @ColumnDataType=ColumnDataType,@ColumnResourceData=ResourceData,@IsColumnUserDefined=IsColumnUserDefined,@ColumnCostCenterID=ColumnCostCenterID
    FROM ADM_CostCenterDef A WITH(nolock)              
    join dbo.COM_LanguageResources B WITH(nolock) on A.ResourceID=B.ResourceID              
    WHERE CostCenterColID=@CostCenterColID AND LanguageID=@LangID     
	
	IF(@CostCenterID=50051)
	BEGIN
		IF(@SysColumnName='BankBranch' OR @SysColumnName='BankRoutingCode' OR @SysColumnName='BankAgentCode'  OR @SysColumnName='BasicWeekly' OR @SysColumnName='BasicDaily' OR @SysColumnName='BasicHourly' OR @SysColumnName='CreatedBy'  )
		BEGIN
			SET @I=@I+1
			Continue
		END

	END
	
	         
    if(@ColumnCostCenterID=113)
		set @ColumnCostCenterID=0
	SET @strColumns=@strColumns+','              
     
    IF(@ColumnCostCenterID IS NOT NULL AND @ColumnCostCenterID>0 and @ColumnCostCenterID!=44)--IF COSTCENTER COLUMN              
    BEGIN      
     --GETTING COLUMN COSTCENTER TABLE      
            
     SET @CostCenterTableName=(SELECT Top 1 SysTableName FROM ADM_CostCenterDef with(nolock) WHERE CostCenterID=@ColumnCostCenterID)                 
    IF(@CC=0)--FIRST TIME JOIN MAP TABLE              
     BEGIN                
      IF(@CostCenterID=2)--ACCOUNTS                    
   SET @STRJOIN=@STRJOIN+' left  JOIN COM_CCCCDATA ACM WITH(NOLOCK) ON ACM.NodeID=A.AccountID AND ACM.COSTCENTERID='+CONVERT(VARCHAR,@CostCenterID)              
    ELSE IF(@CostCenterID=3)--PRODUCTS              
       SET @STRJOIN=@STRJOIN+' left  JOIN COM_CCCCDATA PCM WITH(NOLOCK) ON PCM.NodeID=A.ProductID AND PCM.COSTCENTERID='+CONVERT(VARCHAR,@CostCenterID)              
      ELSE IF (@CostCenterID=72)            
       SET @STRJOIN=@STRJOIN              
      ELSE IF (@CostCenterID=101)            
       SET @STRJOIN=@STRJOIN                
      ELSE IF (@CostCenterID=76)             
       SET @STRJOIN=@STRJOIN             
      ELSE IF (@CostCenterID=86)             
       SET @STRJOIN=@STRJOIN+' left  JOIN COM_CCCCDATA LCM WITH(NOLOCK) ON LCM.NODEID=A.LEADID AND LCM.COSTCENTERID='+CONVERT(VARCHAR,@CostCenterID)          
	 ELSE IF (@CostCenterID=65)             
       SET @STRJOIN=@STRJOIN+' left  JOIN COM_CCCCDATA ACM WITH(NOLOCK) ON ACM.NODEID=A.ContactID AND ACM.COSTCENTERID='+CONVERT(VARCHAR,@CostCenterID)          
      ELSE IF (@CostCenterID=73)             
       SET @STRJOIN=@STRJOIN                       
      ELSE IF (@CostCenterID=93)             
       SET @STRJOIN=@STRJOIN       
      ELSE IF (@CostCenterID=89)             
       SET @STRJOIN=@STRJOIN        
      ELSE IF (@CostCenterID=92)             
       SET @STRJOIN=@STRJOIN       
      ELSE IF (@CostCenterID=95)             
       SET @STRJOIN=@STRJOIN      
      ELSE IF (@CostCenterID=103)             
       SET @STRJOIN=@STRJOIN	   
      ELSE IF (@CostCenterID=77)             
       SET @STRJOIN=@STRJOIN      
      ELSE IF (@CostCenterID=75)             
       SET @STRJOIN=@STRJOIN     
         ELSE IF (@CostCenterID=104)             
       SET @STRJOIN=@STRJOIN   
      ELSE --OTHER COSTCENTERS   
		SET @STRJOIN=@STRJOIN+' left  JOIN COM_CCCCDATA CCM WITH(NOLOCK) ON CCM.NodeID=A.NodeID AND CCM.COSTCENTERID='+CONVERT(VARCHAR,@CostCenterID)              
                
       --SET @STRJOIN=@STRJOIN+' left  JOIN COM_CostCenterCostCenterMap CCM WITH(NOLOCK) ON CCM.ParentNodeID =A.NodeID AND CCM.ParentCostCenterID='+convert(NVARCHAR(10),@CostCenterID)              
     END  
	 
      
     --Set Primary Column               
     if(@ColumnCostCenterID=3)              
      BEGIN              
       set @ColCostCenterPrimary='ProductID'              
    SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ProductName as '''+@ColumnResourceData+''''
      END              
     ELSE if(@ColumnCostCenterID=2)              
      BEGIN             
  --set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.AccountName , '      
       set @ColCostCenterPrimary='AccountID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.AccountName as '''+@ColumnResourceData+''''
      END              
     ELSE if(@ColumnCostCenterID=11)              
      BEGIN              
        
 -- set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.UnitName  '      
       set @ColCostCenterPrimary='UOMID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.UnitName as '''+@ColumnResourceData+''''
      END              
     ELSE if(@ColumnCostCenterID=12)              
      BEGIN              
         
 --  set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME  '      
       set @ColCostCenterPrimary='CurrencyID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME as '''+@ColumnResourceData+''''
      END              
     ELSE if(@ColumnCostCenterID=17)              
      BEGIN              
        
 --  set @tempgroup=@tempgroup+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BarcodeName  '      
       set @ColCostCenterPrimary='BarcodeID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BarcodeName as '''+@ColumnResourceData+''''              
      END              
     ELSE if(@ColumnCostCenterID=16)              
      BEGIN              
           
       set @ColCostCenterPrimary='BatchID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BatchNumber as '''+@ColumnResourceData+''''              
    END   
    ELSE if(@ColumnCostCenterID=83)              
      BEGIN              
                      
       set @ColCostCenterPrimary='CustomerID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.CustomerName as '''+@ColumnResourceData+''''              
                       
      END          
     ELSE if(@ColumnCostCenterID=88)              
      BEGIN              
                      
       set @ColCostCenterPrimary='CampaignID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Name as '''+@ColumnResourceData+''''              
                       
      END          
    ELSE if(@ColumnCostCenterID=94)              
      BEGIN              
                      
       set @ColCostCenterPrimary='TenantID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.FirstName as '''+@ColumnResourceData+''''              
                       
      END       
              
    ELSE if(@ColumnCostCenterID=92)              
      BEGIN              
                      
       set @ColCostCenterPrimary='NodeID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Name as '''+@ColumnResourceData+''''              
                       
      END        
       ELSE if(@ColumnCostCenterID=95)              
      BEGIN              
                      
       set @ColCostCenterPrimary='ContractID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ContractPrefix as '''+@ColumnResourceData+''''              
                       
      END     
       ELSE if(@ColumnCostCenterID=103)              
      BEGIN              
                      
       set @ColCostCenterPrimary='ContractID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ContractPrefix as '''+@ColumnResourceData+''''              
                       
      END    
       ELSE if(@ColumnCostCenterID=104)              
      BEGIN              
                      
       set @ColCostCenterPrimary='ContractID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ContractPrefix as '''+@ColumnResourceData+''''              
                       
      END       
     ELSE if(@ColumnCostCenterID=72)              
      BEGIN              
                      
       set @ColCostCenterPrimary='AssetID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.AssetName as '''+@ColumnResourceData+''''              
                       
      END                
     ELSE if(@ColumnCostCenterID=86)              
      BEGIN              
                      
       set @ColCostCenterPrimary='LeadID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Company as '''+@ColumnResourceData+''''              
                       
      END        
    ELSE if(@ColumnCostCenterID=73)              
      BEGIN              
                      
       set @ColCostCenterPrimary='CaseID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.CaseNumber as '''+@ColumnResourceData+''''              
                       
      END                           
     ELSE if(@ColumnCostCenterID=89)              
      BEGIN              
                      
       set @ColCostCenterPrimary='OpportunityID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Subject as '''+@ColumnResourceData+''''              
                       
      END              
     ELSE if(@ColumnCostCenterID=101)              
      BEGIN              
                      
       set @ColCostCenterPrimary='BudegtDefID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BudgetName as '''+@ColumnResourceData+''''              
                       
      END              
     ELSE if(@ColumnCostCenterID=93)              
      BEGIN              
                      
       set @ColCostCenterPrimary='UnitID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Code as '''+@ColumnResourceData+''''              
                       
      END                     
     ELSE if(@ColumnCostCenterID=76)              
      BEGIN              
                      
       set @ColCostCenterPrimary='BOMID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BOMName as '''+@ColumnResourceData+''''              
                       
	   END                  
      ELSE               
      BEGIN              
		set @ColCostCenterPrimary='NodeID'              
       SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME as '''+@ColumnResourceData+''''              
      END              
              
     IF(@IsColumnUserDefined=0)              
     BEGIN   
		if(@SysColumnName='ProductGroup' OR @SysColumnName='IsGroup')                 
			SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
			+' WITH(NOLOCK) ON A.ParentID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary  
		else           
			SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
			+' WITH(NOLOCK) ON A.'+@SysColumnName+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary              
     END              
     ELSE IF(@CostCenterID=2)--ACCOUNTS              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)            
       +' WITH(NOLOCK) ON ACM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary   
       
      --SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
      -- +' WITH(NOLOCK) ON ACM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND ACM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END              
     ELSE IF(@CostCenterID=3)--PRODUCTS              
     BEGIN          
      SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)            
       +' WITH(NOLOCK) ON PCM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary   
           
      --SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
      -- +' WITH(NOLOCK) ON PCM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND PCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END           
     ELSE IF(@CostCenterID=72)--Asset              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END                 
     ELSE IF(@CostCenterID=76)--BOM              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END                   
     ELSE IF(@CostCenterID=86)--CRM-LEAD              
     BEGIN              
      SET @STRJOIN=@STRJOIN+'  left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON LCM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary               
     END       
     ELSE IF(@CostCenterID=73)--CRM-Cases              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END                 
     ELSE IF(@CostCenterID=93)             
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.UnitID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END                     
     ELSE IF(@CostCenterID=89)--CRM-Opportunity              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END                     
     ELSE IF(@CostCenterID=101)--BUDGET              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END           
     ELSE IF(@CostCenterID=92)--PROPERTY              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END            
     ELSE IF(@CostCenterID=95)--CONTRACT              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.ContractID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END  
    ELSE IF(@CostCenterID=103 OR @CostCenterID=104)--QUOTATION OR PURCHASE CONTRACT              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       +' WITH(NOLOCK) ON SCM.ContractID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND SCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
     END       
     ELSE IF(@CostCenterID=65)--ACCOUNTS              
     BEGIN              
      SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)            
       +' WITH(NOLOCK) ON ACM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary   
        
     END               
     ELSE --OTHER COSTCENTERS              
     BEGIN              
      --SET @STRJOIN=@STRJOIN+' left  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)              
       --+' WITH(NOLOCK) ON CCM.NodeID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND CCM.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)              
       SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)            
       +' WITH(NOLOCK) ON CCM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary   
        
     END
	 set @strIDCols=@strIDCols+',CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary +' C'+convert(nvarchar,@CostCenterColID)
      --select     @ColCostCenterPrimary
    --INCREMENT COSTCENTER COLUMNS COUNT              
		SET @CC=@CC+1              
              
    END              
    ELSE IF(@IsColumnUserDefined IS NOT NULL AND @IsColumnUserDefined = 1 AND (@CostCenterID=2 OR @CostCenterID=3 OR @CostCenterID=65 OR @CostCenterID=83 OR @CostCenterID=88 OR @CostCenterID=73 OR @CostCenterID=72 OR @CostCenterID=76) and @Param1<>'#Address#')               
    BEGIN
	
		if @ColumnCostCenterID=44
		begin
			SET @strColumns=@strColumns+'L'+CONVERT(NVARCHAR(10),@CostCenterColID) +'.Name as '''+@ColumnResourceData+'''' 
			SET @STRJOIN=@STRJOIN+' left JOIN COM_Lookup L'+CONVERT(NVARCHAR(10),@CostCenterColID)              
				+' WITH(NOLOCK) ON X.'+@SysColumnName +'= L'+CONVERT(NVARCHAR(10),@CostCenterColID)+'.NodeID'
		end
		else
		begin
		
			SET @strColumns=@strColumns+'X.'+@SysColumnName +' as '''+@ColumnResourceData+''''              
		end
    END              
ELSE IF(@SysColumnName='Balance' and @IsColumnUserDefined=0)              
BEGIN   
	SET @strColumns=@strColumns +'(isnull((select SUM(isnull(D.amount,0)) from ACC_DocDetails D with(nolock)'+@AccJoin+' where D.DocDate < =' +convert(nvarchar,@Dt)+@AccWhere+' and D.debitaccount in (select AccountID from ACC_Accounts with(nolock) where lft>=(select lft from ACC_Accounts with(nolock) where AccountID='+convert(nvarchar(50),@NodeID)+')
	and rgt<= (select rgt from ACC_Accounts with(nolock) where AccountID='+convert(nvarchar(50),@NodeID)+'))),0)'
	IF @InvJoin IS NOT NULL AND @InvJoin<>''
		set @strColumns=@strColumns+'
		+isnull((select SUM(isnull(D.amount,0)) from ACC_DocDetails D with(nolock)'+@InvJoin+' where D.DocDate < =' +convert(nvarchar,@Dt)+@AccWhere+' and D.debitaccount in (select AccountID from ACC_Accounts with(nolock) where lft>=(select lft from ACC_Accounts with(nolock) where AccountID='+convert(nvarchar(50),@NodeID)+')
		and rgt<= (select rgt from ACC_Accounts with(nolock) where AccountID='+convert(nvarchar(50),@NodeID)+'))),0)'
	set @strColumns=@strColumns+')-(isnull((select SUM(isnull(D.amount,0)) from ACC_DocDetails D with(nolock)'+@AccJoin+' where D.DocDate < =' +convert(nvarchar,@Dt)+@AccWhere+' and D.creditaccount in (select AccountID from ACC_Accounts with(nolock) where lft>=(select lft from ACC_Accounts with(nolock) where AccountID='+convert(nvarchar,@NodeID)+') 
	and rgt<= (select rgt from ACC_Accounts with(nolock) where AccountID='+convert(nvarchar,@NodeID)+'))),0)'
	IF @InvJoin IS NOT NULL AND @InvJoin<>''
		set @strColumns=@strColumns+'+isnull((select SUM(isnull(D.amount,0)) from ACC_DocDetails D with(nolock)'+@InvJoin+' where D.DocDate < =' +convert(nvarchar,@Dt)+@AccWhere+' and D.creditaccount in (select AccountID from ACC_Accounts with(nolock) where lft>=(select lft from ACC_Accounts with(nolock) where AccountID='+convert(nvarchar,@NodeID)+') 
		and rgt<= (select rgt from ACC_Accounts with(nolock) where AccountID='+convert(nvarchar,@NodeID)+'))),0)'
	set @strColumns=@strColumns+',0)) as Balance
  '      
 END         
  ELSE IF(@SysColumnName='QOH' and @IsColumnUserDefined=0 and @CostCenterID=3  )              
    BEGIN       
		if(@CostCenterColID=25900)
		BEGIN
			EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,1,0,0,0,0,0,0,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT      
			SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@QOH,0))+' as '''+@ColumnResourceData+''''
		END
		else
		begin			
			if(@Param1 is not null and @Param1<>'Description' and @Param1<>'')
			BEGIN
				if(@Param1 like '%QOH%')
				BEGIN
					EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,1,0,0,0,0,0,0,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT      
					
					set @Param1 = Replace(@Param1,'QOH',CONVERT(NVARCHAR,ISNULL(@QOH,0)))				
				END
				IF(@Param1 like '%HOLDQTY%')
				BEGIN 
					select @Unappstat=Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold'
  					EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,0,0,1,0,0,0,@Unappstat,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID      
  					
  					set @Param1 = Replace(@Param1,'HOLDQTY',CONVERT(NVARCHAR,ISNULL(@HOLDQTY,0)))
				END   
				IF(@Param1 like '%RESERVEQTY%')
				BEGIN     
						select @Unappstat=Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold'
  				
					EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,0,0,0,0,1,0,@Unappstat,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID      
					
					set @Param1 = Replace(@Param1,'RESERVEQTY',CONVERT(NVARCHAR,ISNULL(@RESERVEQTY,0)))
				END
				IF(@Param1 like '%BalQty%')
				BEGIN     
					EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,0,1,0,0,0,0,0,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID      
					
					set @Param1 = Replace(@Param1,'BalQty',CONVERT(NVARCHAR,ISNULL(@BalQOH,0)))
					select @Param1
				END
				SET @strColumns=@strColumns +@Param1+' as '''+@ColumnResourceData+''''
			END
			ELSE
			BEGIN
				EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,0,1,0,0,0,0,0,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID      
				
				SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@BalQOH,0))+' as '''+@ColumnResourceData+''''
			END	
		end
             
 END   
 ELSE IF(@SysColumnName='HOLDQTY' and @IsColumnUserDefined=0 and @CostCenterID=3  )            
    BEGIN        
      	select @Unappstat=Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold'
  				
  		EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,0,0,1,0,0,0,@Unappstat,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID      
		SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@HOLDQTY,0))+' as '''+@ColumnResourceData+''''
 END   
 ELSE IF(@SysColumnName='RESERVEQTY' and @IsColumnUserDefined=0 and @CostCenterID=3  )            
    BEGIN     
		 	select @Unappstat=Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold'
  	
  		EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,0,0,0,0,1,0,@Unappstat,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID      
		SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@RESERVEQTY,0))+' as '''+@ColumnResourceData+''''
 END 
 ELSE IF((@CostCenterColID=50453 or @CostCenterColID=-11401 or @CostCenterColID=-11402 ) and @CostCenterID=3)   
    BEGIN
		IF(@Param1 IS NOT NULL AND @Param1 != '')
		BEGIN
			DECLARE @Query NVARCHAR(MAX)
			DECLARE @TblPendingOrders AS TABLE(ProductID INT,Qty FLOAT)
			SET @Query=dbo.fnGetPendingOrders(@Param1,@NodeID,'','',0) 
			--PRINT @Query
			DELETE FROM @TblPendingOrders
			INSERT INTO @TblPendingOrders(ProductID,Qty)
			EXEC(@Query)
			
			select @CommittedQTY=sum(Qty) from @TblPendingOrders 
		END
		ELSE
			EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,0,0,0,1,0,0,0,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID 
		SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@CommittedQTY,0))+' as '''+CASE WHEN @CostCenterColID=-11401 THEN @ColumnResourceData+'2' WHEN @CostCenterColID=-11402 THEN @ColumnResourceData+'3' ELSE @ColumnResourceData+'1' END+''''
 END
 ELSE IF((@CostCenterColID=-11393 OR @CostCenterColID=-11398 OR @CostCenterColID=-11399 )and @CostCenterID=3)   
	BEGIN
		IF(@Param1 IS NOT NULL AND @Param1 != '')
		BEGIN
			Declare @OrderQty FLOAT,@ExecutedQty FLOAT,@str1 nvarchar(max),@temp1 nvarchar(max)
			SET @temp1='@OrderQty FLOAT output'
			SET @str1='SELECT @OrderQty=SUM(a.Quantity)
			FROM  [INV_DocDetails] a WITH(NOLOCK) 
			left JOIN [INV_DocDetails] y WITH(NOLOCK) on y.LinkedInvDocDetailsID=a.InvDocDetailsID and y.StatusID<>376
			WHERE a.CostCenterID IN ('+ convert(varchar,@Param1)+') and a.ProductID IN ('+ convert(varchar,@NodeID)+')
			AND (y.LinkedFieldName is null or y.LinkedFieldName=''Quantity'')
			AND (y.StatusID is null or y.StatusID<>376)'
			EXEC sp_executesql @str1,@temp1,@OrderQty output

			SET @temp1='@ExecutedQty FLOAT output'
			SET @str1='SELECT @ExecutedQty=isnull(sum(isnull(y.LinkedFieldValue,0)),0)  	
			FROM  [INV_DocDetails] a WITH(NOLOCK) 
			left JOIN [INV_DocDetails] y WITH(NOLOCK) on y.LinkedInvDocDetailsID=a.InvDocDetailsID and y.StatusID<>376
			WHERE a.CostCenterID IN ('+ convert(varchar,@Param1)+') and a.ProductID IN ('+ convert(varchar,@NodeID)+')
			AND (y.LinkedFieldName is null or y.LinkedFieldName=''Quantity'')
			AND (y.StatusID is null or y.StatusID<>376)'
			EXEC sp_executesql @str1,@temp1,@ExecutedQty output

			SET @CommittedQTY=ISNULL((@OrderQty-@ExecutedQty),0)
		END
		ELSE
			EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,0,0,0,0,0,1,0,0,0,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT,@UserID,@RoleID 
		SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@CommittedQTY,0))+' as '''+CASE WHEN @CostCenterColID=-11398 THEN 'Expected Qty2' WHEN @CostCenterColID=-11399 THEN 'Expected Qty3' ELSE 'Expected Qty1' END+''''
	END
ELSE IF(@CostCenterID=3 AND @SysColumnName='Last Purchase Rate')
BEGIN
	select @DocsList=LastPRateDocs FROM ADM_QuickViewDefn WHERE QID=@QID
	if @DocsList is null or @DocsList=''
		SET @strColumns=@strColumns +'0 as '''+@ColumnResourceData+''''
	else
		SET @strColumns=@strColumns +'(select TOP 1 Rate from inv_docdetails A with(nolock) where A.StatusID=369 and A.productid='+CONVERT(nvarchar,@NodeID) +' AND A.costcenterid IN (' + @DocsList + ') and A.DocDate<='+CONVERT(NVARCHAR,CONVERT(FLOAT,@Date))+' order by A.DocDate desc) as '''+@ColumnResourceData+''''
END
ELSE IF(@CostCenterID=3 AND @SysColumnName='Last Selling Rate')
BEGIN     
	declare @strDocs nvarchar(1000)
	select @strDocs=LastSRateDocs FROM ADM_QuickViewDefn WHERE QID=@QID
	if @strDocs is null or @strDocs=''
		SET @strColumns=@strColumns +'0 as '''+@ColumnResourceData+''''
	else
		SET @strColumns=@strColumns +'(select TOP 1 Rate from inv_docdetails A with(nolock) where A.productid='+CONVERT(nvarchar,@NodeID) +' AND A.costcenterid IN (' + @strDocs + ') and A.DocDate<='+CONVERT(NVARCHAR,CONVERT(FLOAT,@Date))+' order by A.DocDate desc) as '''+@ColumnResourceData+''''
END
ELSE IF(@CostCenterID=3 AND @SysColumnName='Avg Rate')
BEGIN
	
	EXEC [spDOC_StockAvgValue] @NodeID,@CCXML,@Date,0,1,0,0,0,0,0,0,0,0,@QOH OUTPUT,@HOLDQTY OUTPUT,@CommittedQTY output,@RESERVEQTY OUTPUT,@TotalReserve OUTPUT,@AvgRate OUTPUT,@BalQOH OUTPUT      
	SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@AvgRate,0))+' as '''+@ColumnResourceData+''''
END
ELSE IF(@CostCenterID=3 AND @SysColumnName='PurchaseRate')
BEGIN 
DECLARE	@PRate float,
		@SRate float

EXEC	[dbo].[spDOC_GetProductRates] @NodeID, 0,@CCXML,3, @Date,  @AccountID, 1,@UserID ,@LangID , @PRate OUTPUT,  @SRate OUTPUT

if(@PRate is null or @PRate=0)
	select @PRate=Purchaserate from Inv_product with(nolock) where Productid=@NodeID

SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@PRate,0))+' as '''+@ColumnResourceData+''''
   
END
ELSE IF(@CostCenterID=3 AND @SysColumnName in('SellingRate','SellingRateA','SellingRateb','SellingRatec','SellingRated','SellingRatee'))
BEGIN 
	 set @SRate=0
	set @SQL='  select top 1  @SalesRate='+@SysColumnName+' from COM_CCPrices WITH(NOLOCK)       
		where WEF<='+convert(nvarchar,convert(float,@Date))+@WHERE +'
		and (UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' or UOMID=1)   order by WEF Desc'+@OrderBY+',UOMID Desc'
		
		exec sp_executesql @SQL  , N'@SalesRate float output', @SRate output  
		
		if(@SRate is null or @SRate=0)
		BEGIN
			set @SQL='  select @SalesRate='+@SysColumnName+' from Inv_product with(nolock) where Productid='+convert(nvarchar,@NodeID)
			exec sp_executesql @SQL  , N'@SalesRate float output', @SRate output  	
		END
		SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@SRate,0))+' as '''+@ColumnResourceData+''''
   
END
ELSE IF(@CostCenterID=3 AND @SysColumnName='PW_LandingCost')
BEGIN
	declare @PWLastPCost FLOAT
	IF @ShowInCCID!=3
	BEGIN

		select @DocsList=LastPRateDocs FROM ADM_QuickViewDefn with(nolock) WHERE QID=@QID
		if @DocsList is null or @DocsList=''
		BEGIN
			select @PWLastPCost=stockValue/UOMConvertedQty from INV_DocDetails with(nolock)
			where IsQtyIgnored=0 and VoucherType=1 and ProductID=@NodeID and DocDate<=CONVERT(float,@Date)        
			and CreditAccount=@AccountID        
			and UOMConvertedQty is not null and UOMConvertedQty>0 
			order by DocDate 
		end
		Else
		BEGIN
			set @TempSQL='select @PWLastPCost=stockValue/UOMConvertedQty from INV_DocDetails with(nolock)
			where IsQtyIgnored=0 and VoucherType=1 and ProductID='+convert(nvarchar,@NodeID)+' and DocDate<='+convert(nvarchar,CONVERT(float,@Date))+'         
			and CreditAccount='+convert(nvarchar,@AccountID)+'
			and CostcenterID in ('+@DocsList+') and UOMConvertedQty is not null and UOMConvertedQty>0 
			order by DocDate' 
			--print(@TempSQL)  
			exec sp_executesql  @TempSQL,N'@PWLastPCost FLOAT OUTPUT',@PWLastPCost OUTPUT 
		END	
		
	END
	SET @strColumns=@strColumns +CONVERT(NVARCHAR,ISNULL(@PWLastPCost,0))+' as '''+@ColumnResourceData+''''
END
ELSE IF(@CostCenterID=3 AND @SysColumnName='PW_LastRate')
BEGIN
	declare @PWLastPRate FLOAT
	IF @ShowInCCID!=3
	BEGIN
		select @DocsList=LastPRateDocs FROM ADM_QuickViewDefn with(nolock) WHERE QID=@QID	
		if @DocsList is null or @DocsList=''
		BEGIN
			select @PWLastPRate=Rate from INV_DocDetails with(nolock)
			where IsQtyIgnored=0 and VoucherType=1 and ProductID=@NodeID and DocDate<=CONVERT(float,@Date)        
			and CreditAccount=@AccountID        
			and UOMConvertedQty is not null and UOMConvertedQty>0 
			order by DocDate 
		end
		Else
		BEGIN
			set @TempSQL='select @PWLastPRate=Rate from INV_DocDetails with(nolock)
			where IsQtyIgnored=0 and VoucherType=1 and ProductID='+convert(nvarchar,@NodeID)+' and DocDate<='+convert(nvarchar,CONVERT(float,@Date))+'         
			and CreditAccount='+convert(nvarchar,@AccountID)+'
			and CostcenterID in ('+@DocsList+') and UOMConvertedQty is not null and UOMConvertedQty>0 
			order by DocDate'   
			exec sp_executesql  @TempSQL,N'@PWLastPRate FLOAT OUTPUT',@PWLastPRate OUTPUT 
		END	
	END
	SET @strColumns=@strColumns+CONVERT(NVARCHAR,ISNULL(@PWLastPRate,0))+' as '''+@ColumnResourceData+''''
END
ELSE IF(@CostCenterID=3 AND @SysColumnName='PW_LandingValue')
BEGIN
	declare @PWLastPValue FLOAT
	IF @ShowInCCID!=3
	BEGIN
		select @DocsList=LastPRateDocs FROM ADM_QuickViewDefn with(nolock) WHERE QID=@QID
		if @DocsList is null or @DocsList=''
		BEGIN
			select @PWLastPValue=stockValue from INV_DocDetails with(nolock)
			where IsQtyIgnored=0 and VoucherType=1 and ProductID=@NodeID and DocDate<=CONVERT(float,@Date)        
			and CreditAccount=@AccountID        
			and UOMConvertedQty is not null and UOMConvertedQty>0 
			order by DocDate 
		end
		Else
		BEGIN
			set @TempSQL='select @PWLastPValue=stockValue from INV_DocDetails with(nolock)
			where IsQtyIgnored=0 and VoucherType=1 and ProductID='+convert(nvarchar,@NodeID)+' and DocDate<='+convert(nvarchar,CONVERT(float,@Date))+'         
			and CreditAccount='+convert(nvarchar,@AccountID)+'
			and CostcenterID in ('+@DocsList+') and UOMConvertedQty is not null and UOMConvertedQty>0 
			order by DocDate'   
			exec sp_executesql  @TempSQL,N'@PWLastPValue FLOAT OUTPUT',@PWLastPValue OUTPUT 
		END	
	END
	SET @strColumns=@strColumns+CONVERT(NVARCHAR,ISNULL(@PWLastPValue,0))+' as '''+@ColumnResourceData+''''

END
ELSE IF(@CostCenterID=3 AND @SysColumnName='Last Landing Rate')
BEGIN
	select @DocsList=LastPRateDocs FROM ADM_QuickViewDefn with(nolock) WHERE QID=@QID
	if @DocsList is null or @DocsList=''
		SET @strColumns=@strColumns +'0 as '''+@ColumnResourceData+''''
	else
		SET @strColumns=@strColumns +'(select TOP 1 stockValue/UOMConvertedQty from inv_docdetails A with(nolock) where A.productid='+CONVERT(nvarchar,@NodeID) +' AND A.costcenterid IN (' + @DocsList + ') and A.DocDate<='+CONVERT(NVARCHAR,CONVERT(FLOAT,@Date))+' and UOMConvertedQty is not null and UOMConvertedQty>0  order by A.DocDate desc) as '''+@ColumnResourceData+''''
END
ELSE IF(@CostCenterID=3 AND @SysColumnName LIKE 'PW_LastValue%')
BEGIN
	declare @LastColID INT,@PWCOLUMNNAME NVARCHAR(100),@PWCCID NVARCHAR(20),@DocumentType INT,@val nvarchar(MAX),@RName nvarchar(100),@DataType nvarchar(100)
	set @Val=null
	set @PWCOLUMNNAME=null
	set @RName=@ColumnResourceData
	if ISNUMERIC(@Param1)=1 and convert(INT,@Param1)>0
	begin
		SELECT @PWCOLUMNNAME=C.SYSCOLUMNNAME,@PWCCID=convert(nvarchar,C.CostCenterID),@DocumentType=DocumentType,
			@RName=C.UserColumnName,@DataType=UserColumnType
		FROM ADM_COSTCENTERDEF C
		INNER JOIN ADM_DocumentTypes D ON D.CostCenterID=C.CostCenterID
		WHERE C.CostCenterColID=@Param1
		and C.SYSCOLUMNNAME not like 'dcCalcNum%' and C.SYSCOLUMNNAME not like 'dcCurrID%' and C.SYSCOLUMNNAME not like 'dcExchRT%'
		
		--SELECT C.* FROM ADM_COSTCENTERDEF C
		--INNER JOIN ADM_DocumentTypes D ON D.CostCenterID=C.CostCenterID
		--WHERE C.CostCenterColID=@Param1
		--and C.SYSCOLUMNNAME not like 'dcCalcNum%' and C.SYSCOLUMNNAME not like 'dcCurrID%' and C.SYSCOLUMNNAME not like 'dcExchRT%'
		
		if @PWCOLUMNNAME IS NOT NULL
		begin
			set @sql='select @val='+@PWCOLUMNNAME
				
			set @sql=@sql+' from INV_DocDetails a with(nolock)
			join COM_DocNumData b with(nolock) on a.invdocdetailsid=b.invdocdetailsid 
			join COM_DocCCData c with(nolock) on a.invdocdetailsid=c.invdocdetailsid 
			join COM_DocTextData d with(nolock) on a.invdocdetailsid=d.invdocdetailsid'	
			 
			set @sql=@sql+	' where ProductID='+convert(nvarchar,@NODEID)+' and DocDate<='+convert(nvarchar,CONVERT(float,@Date))+' and CostCenterID in ('+@PWCCID+')'
			
			if(@AccountID <>0)
			begin
				if(@DocumentType=1 or @DocumentType=27 or @DocumentType=26 or @DocumentType=25 or @DocumentType=2  or @DocumentType=34 or @DocumentType=6 or @DocumentType=3 or @DocumentType=4 or @DocumentType=13)    
					set @sql=@sql+' and  CreditAccount='+convert(nvarchar,@AccountID)
				else
					set @sql=@sql+' and DebitAccount='+convert(nvarchar,@AccountID)
			end	
			set @sql=@sql+' order by DocDate'
			-- print(@sql)
			exec sp_executesql @sql,N'@val nvarchar(max) output',@val output
		end
	end	
	
	if @Val is not null
	begin
		if @DataType='DATE'
			SET @strColumns=@strColumns+'CONVERT(DATETIME,'+CONVERT(NVARCHAR,@Val)+') as [PW_Last '+@RName+']'
		else
			SET @strColumns=@strColumns+''''+CONVERT(NVARCHAR,@Val)+''' as [PW_Last '+@RName+']'	
	end
	else if @ColumnResourceData<>@RName
		SET @strColumns=@strColumns +'null as ['+@RName+']'
	else
		SET @strColumns=@strColumns +'null as ['+@ColumnResourceData+']'
END
ELSE IF(@CostCenterID=2 AND @SysColumnName='Balance As On Document Date')
BEGIN
	declare @BalDocDate float
	--Debit Amount	
	set @sql='SELECT @BalDocDate=(ISNULL((SELECT SUM(D.AMOUNT) FROM ACC_DocDetails D with(nolock)'+@AccJoin+' where D.DebitAccount='+convert(nvarchar,@NodeID)
	+' and D.DocDate<='+convert(nvarchar,convert(float,@Date))+@AccWhere+'),0)'
	IF @InvJoin IS NOT NULL AND @InvJoin<>''
		set @sql=@sql+'+ISNULL((SELECT SUM(D.AMOUNT) FROM ACC_DocDetails D with(nolock)'+@InvJoin+' where D.DebitAccount='+convert(nvarchar,@NodeID)
		+' and D.DocDate<='+convert(nvarchar,convert(float,@Date))+@AccWhere+'),0)'
	set @sql=@sql+')'
	--Credit Amount	 
	set @sql=@sql+'-(ISNULL((SELECT SUM(D.AMOUNT) FROM ACC_DocDetails D with(nolock)'+@AccJoin+' where D.CreditAccount='+convert(nvarchar,@NodeID)
	+' and D.DocDate<='+convert(nvarchar,convert(float,@Date))+@AccWhere+'),0)'
	IF @InvJoin IS NOT NULL AND @InvJoin<>''
		set @sql=@sql+'+ISNULL((SELECT SUM(D.AMOUNT) FROM ACC_DocDetails D with(nolock)'+@InvJoin+' where D.CreditAccount='+convert(nvarchar,@NodeID)
		+' and D.DocDate<='+convert(nvarchar,convert(float,@Date))+@AccWhere+'),0)'
	set @sql=@sql+')'
	PRINT @sql
	exec sp_executesql @sql,N'@BalDocDate float output',@BalDocDate output
	
	SET @strColumns=@strColumns+'CONVERT(FLOAT,'+CONVERT(NVARCHAR,convert(decimal(14,3),@BalDocDate))+') as '''+@ColumnResourceData+''''
END
ELSE IF(@CostCenterID=2 AND @SysColumnName='Balance As On System Date')
BEGIN
	declare @BalSysDate float
	--Debit Amount	
	set @sql='SELECT @BalSysDate=(ISNULL((SELECT SUM(D.AMOUNT) FROM ACC_DocDetails D with(nolock)'+@AccJoin+' where D.DebitAccount='+convert(nvarchar,@NodeID)
	+' and D.DocDate<='+convert(nvarchar,@Dt)+@AccWhere+'),0)'
	IF @InvJoin IS NOT NULL AND @InvJoin<>''
		set @sql=@sql+'+ISNULL((SELECT SUM(D.AMOUNT) FROM ACC_DocDetails D with(nolock)'+@InvJoin+' where D.DebitAccount='+convert(nvarchar,@NodeID)
		+' and D.DocDate<='+convert(nvarchar,@Dt)+@AccWhere+'),0)'
	set @sql=@sql+')'
	--Credit Amount	 
	set @sql=@sql+'-(ISNULL((SELECT SUM(D.AMOUNT) FROM ACC_DocDetails D with(nolock)'+@AccJoin+' where D.CreditAccount='+convert(nvarchar,@NodeID)
	+' and D.DocDate<='+convert(nvarchar,@Dt)+@AccWhere+'),0)'
	IF @InvJoin IS NOT NULL AND @InvJoin<>''
		set @sql=@sql+'+ISNULL((SELECT SUM(D.AMOUNT) FROM ACC_DocDetails D with(nolock)'+@InvJoin+' where D.CreditAccount='+convert(nvarchar,@NodeID)
		+' and D.DocDate<='+convert(nvarchar,@Dt)+@AccWhere+'),0)'
	set @sql=@sql+')'
	exec sp_executesql @sql,N'@BalSysDate float output',@BalSysDate output
	
	SET @strColumns=@strColumns+'CONVERT(FLOAT,'+CONVERT(NVARCHAR,convert(decimal(14,3),@BalSysDate))+') as '''+@ColumnResourceData+''''
END
ELSE IF(@CostCenterID=2 AND @SysColumnName='Balance Credit')
BEGIN
	
	declare @Bal float,@CrLimit float,@DOBal float
	--Debit Amount	
	set @sql='SELECT @Bal=(ISNULL((SELECT SUM(ISNULL(D.AMOUNT,0)) FROM ACC_DocDetails D with(nolock)'+@AccJoin+' where D.DebitAccount='+convert(nvarchar,@NodeID)
	+' and D.DocDate<='+convert(nvarchar,@Dt)+@AccWhere+'),0)'
	IF @InvJoin IS NOT NULL AND @InvJoin<>''
		set @sql=@sql+'+ISNULL((SELECT SUM(ISNULL(D.AMOUNT,0)) FROM ACC_DocDetails D with(nolock)'+@InvJoin+' where D.DebitAccount='+convert(nvarchar,@NodeID)
		+' and D.DocDate<='+convert(nvarchar,@Dt)+@AccWhere+'),0)'
	set @sql=@sql+')'
	--Credit Amount	 
	set @sql=@sql+'-(ISNULL((SELECT SUM(ISNULL(D.AMOUNT,0)) FROM ACC_DocDetails D with(nolock)'+@AccJoin+' where D.CreditAccount='+convert(nvarchar,@NodeID)
	+' and D.DocDate<='+convert(nvarchar,@Dt)+@AccWhere+'),0)'
	IF @InvJoin IS NOT NULL AND @InvJoin<>''
		set @sql=@sql+'+ISNULL((SELECT SUM(ISNULL(D.AMOUNT,0)) FROM ACC_DocDetails D with(nolock)'+@InvJoin+' where D.CreditAccount='+convert(nvarchar,@NodeID)
		+' and D.DocDate<='+convert(nvarchar,@Dt)+@AccWhere+'),0)'
	set @sql=@sql+')'
	exec sp_executesql @sql,N'@Bal float output',@Bal output
	
	select @CrLimit=CreditLimit from ACC_Accounts with(nolock) WHERE AccountID=@NodeID
	
	select @DocsList=LastPRateDocs FROM ADM_QuickViewDefn with(nolock) WHERE QID=@QID
	
	if @DocsList is not null and @DocsList<>''
	BEGIN
		--Debit Amount	
	set @sql='SELECT @DOBal=ISNULL((SELECT SUM(ISNULL(StockValue,0)) FROM INV_DocDetails with(nolock) where DebitAccount='+convert(nvarchar,@NodeID)
	+' and DocDate<='+convert(nvarchar,convert(float,@Date))+' and costcenterid in ('+@DocsList+')),0) ' 
	set @sql=@sql+'-ISNULL((SELECT SUM(ISNULL(StockValue,0)) FROM INV_DocDetails with(nolock) where CreditAccount='+convert(nvarchar,@NodeID)
	+' and DocDate<='+convert(nvarchar,convert(float,@Date))+' and costcenterid in ('+@DocsList+')),0) ' 

		exec sp_executesql  @sql,N'@DOBal FLOAT OUTPUT',@DOBal OUTPUT 
	end
	
	SET @strColumns=@strColumns+'CONVERT(FLOAT,'+convert(nvarchar,convert(decimal(14,3),(@CrLimit-(@Bal+ISNULL(@DOBal,0)))))+') as '''+@ColumnResourceData+''''
END
 else if (@CostCenterColID between 26706 and 26720 or @Param1='#Address#')--Address Fields
  BEGIN                  
	if @IsAddressDisplayed=0
	begin
		set @IsAddressDisplayed=1
		SET @STRJOIN=@STRJOIN+'
	  LEFT JOIN COM_Address ADDS WITH(NOLOCK) ON ADDS.AddressTypeID=1 and ADDS.FeatureID='+convert(nvarchar,@CostCenterID)+' and ADDS.FeaturePK='+@Primarycol
	end
	SET @strColumns=@strColumns+'ADDS.'+@SysColumnName+' as ['+@ColumnResourceData+']'                        
  END  
 else if (@SysColumnName ='SalutationID' and @CostCenterID=65)      
  BEGIN      
  SET @strColumns=@strColumns+'SLookup.Name as Salutation '         
 SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup SLookup WITH(NOLOCK) ON (A.SalutationID=SLookup.NodeID) '      
        
  END      
  else if (   @SysColumnName ='ContactTypeID' and @CostCenterID=65)      
  BEGIN      
  SET @strColumns=@strColumns+'CLookup.Name as ContactType'      
  SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup CLookup WITH(NOLOCK) ON (A.ContactTypeID=CLookup.NodeID) '      
    END      
 else if ( @SysColumnName ='RoleLookupID' and @CostCenterID=65)      
  BEGIN      
  SET @strColumns=@strColumns+'RLookup.Name as  Role '        
  SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup RLookup WITH(NOLOCK) ON (A.RoleLookupID=RLookup.NodeID) '      
        
  END       
  else if (@SysColumnName ='Country' and @CostCenterID=65)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Country '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.Country=CTLookup.NodeID) '      
  END       
      
  else if (@SysColumnName ='RatinglookupID' and @CostCenterID=86)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Rating '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.RatinglookupID=CTLookup.NodeID) '      
  END        
  else if (@SysColumnName ='SourceLookUpID' and @CostCenterID=86)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Source '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.SourceLookUpID=CTLookup.NodeID) '      
  END       
  else if (@SysColumnName ='IndustryLookUpID' and @CostCenterID=86)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Industry '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.IndustryLookUpID=CTLookup.NodeID) '      
  END     
     else if (@SysColumnName ='FIRSTNAME' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.FIRSTNAME as  '     +@SysColumnName                    
  END        
   else if (@SysColumnName ='MiddleName' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.MiddleName as  '     +@SysColumnName                    
  END    
 else if (@SysColumnName ='LastName' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.LastName as  '     +@SysColumnName                    
  END        
   else if (@SysColumnName ='JobTitle' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.JobTitle as  '     +@SysColumnName                    
  END  
 else if (@SysColumnName ='Phone1' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.Phone1 as  '     +@SysColumnName                    
  END
  else if (@SysColumnName ='Phone2' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.Phone2 as  '     +@SysColumnName                    
  END    
    else if (@SysColumnName ='Email' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.Email1 as  '     +@SysColumnName                    
  END  
  else if (@SysColumnName ='Fax' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.Fax as  '     +@SysColumnName                    
  END  
   else if (@SysColumnName ='Department' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.Department as  '     +@SysColumnName                    
  END  
 else if (@SysColumnName ='Address1' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.Address1 as  '     +@SysColumnName                    
  END  
   else if (@SysColumnName ='Address2' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.Address2 as  '     +@SysColumnName                    
  END  
   else if (@SysColumnName ='Address3' and @CostCenterID=86)              
  BEGIN              
  SET @strColumns=@strColumns+'CON.Address3 as  '     +@SysColumnName                    
  END     
  else if (@SysColumnName ='CampaignID' and @CostCenterID=86)      
  BEGIN      
  SET @strColumns=@strColumns+'resource.ResourceName as Campaign '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN PRD_Resources resource WITH(NOLOCK) ON (A.CampaignID=resource.ResourceID) '      
  END      
 else if (@SysColumnName ='AssignedTo' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'Users.UserName as AssignedTo  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ADM_Users Users WITH(NOLOCK) ON (A.AssignedTo=Users.UserID) '      
  END     
 else if (@SysColumnName ='CaseTypeLookupID' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as CaseType  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.CaseTypeLookupID=CTLookup.NodeID) '      
  END          
 else if (@SysColumnName ='CaseOriginLookupID' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup3.Name as CaseOrigin  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup3 WITH(NOLOCK) ON (A.CaseOriginLookupID=CTLookup3.NodeID) '      
  END    
       
  else if (@SysColumnName ='CasePriorityLookupID' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup1.Name as CasePriority  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup1 WITH(NOLOCK) ON (A.CasePriorityLookupID=CTLookup1.NodeID) '      
  END    
  else if (@SysColumnName ='ServiceLvlLookupID' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup2.Name as ServiceLevel  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup2 WITH(NOLOCK) ON (A.ServiceLvlLookupID=CTLookup2.NodeID) '      
  END    
  else if (@SysColumnName ='CustomerID' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'cust.CustomerName as Customer  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN CRM_Customer cust WITH(NOLOCK) ON (A.CustomerID=cust.CustomerID) '      
  END  
  else if (@SysColumnName ='SvcContractID' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'contract.DocID as Contract  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN CRM_ServiceContract contract WITH(NOLOCK) ON (A.SvcContractID=contract.SvcContractID) '      
  END  
  else if (@SysColumnName ='ContractLineID' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'convert(nvarchar,A.ContractLineID)+''-''+contractline.ProductNAME '+' as ContractLine'  
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN INV_Product contractline WITH(NOLOCK) ON (A.ProductID=contractline.ProductID) '      
  END  
  else if (@SysColumnName ='ProductID' and @CostCenterID=73)      
  BEGIN      
  SET @strColumns=@strColumns+'product.ProductNAME as Product  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN INV_Product product WITH(NOLOCK) ON (A.ProductID=product.ProductID) '      
  END 
  
  else if (@SysColumnName ='AveragingMethod' and @CostCenterID=75)      
  BEGIN      
  SET @strColumns=@strColumns+'Case WHen AveragingMethod=1 then  ''None'' else ''FullMonth'' end as AveragingMethod '        
  END	
  else if (@SysColumnName ='DeprBookMethod' and @CostCenterID=75)      
  BEGIN      
  SET @strColumns=@strColumns+'DM.Name as DeprBookMethod  '         
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_DepreciationMethods DM WITH(NOLOCK) ON (A.DeprBookMethod=DM.DepreciationMethodID) '      
  END 
  
  else if (@SysColumnName ='AcqnCostACCID' and @CostCenterID=77)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC1.AccountName as AssetAccount  '         
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC1 WITH(NOLOCK) ON (A.AcqnCostACCID=ACC1.AccountID) '      
  END 
  
  else if (@SysColumnName ='AccumDeprDispACCID' and @CostCenterID=77)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC1.AccountName as AccumDepreciation  '         
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC1 WITH(NOLOCK) ON (A.AccumDeprDispACCID=ACC1.AccountID) '      
  END 
  
  else if (@SysColumnName ='DeprExpenseACCID' and @CostCenterID=77)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC1.AccountName as DeprExpense  '         
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC1 WITH(NOLOCK) ON (A.DeprExpenseACCID=ACC1.AccountID) '      
  END
  
  else if (@SysColumnName ='DeprBookMethod' and @CostCenterID=75)      
  BEGIN      
  SET @strColumns=@strColumns+'DM.Name as DeprBookMethod  '         
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_DepreciationMethods DM WITH(NOLOCK) ON (A.DeprBookMethod=DM.DepreciationMethodID) '      
  END  
  else if (@SysColumnName ='ProbabilityLookUpID' and @CostCenterID=89)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Probability '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.ProbabilityLookUpID=CTLookup.NodeID) '      
  END        
  else if (@SysColumnName ='CampaignTypeLookupID' and @CostCenterID=88)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Type  '        
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.CampaignTypeLookupID=CTLookup.NodeID) '      
  END      
 else if (@SysColumnName ='StatusID' and @CostCenterID=89)            
  BEGIN            
  SET @strColumns=@strColumns+'CTLookupSTATUS.Name as  Status '         
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookupSTATUS WITH(NOLOCK) ON (A.StatusID=CTLookupSTATUS.NodeID) '            
  END           
  else if (@SysColumnName ='RatingLookUpID' and @CostCenterID=89)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Rating '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.RatingLookUpID=CTLookup.NodeID) '      
  END      
      
  else if (@SysColumnName ='TypeID' and @CostCenterID=94)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Type '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.TypeID=CTLookup.NodeID) '      
  END      
      
  else if (@SysColumnName ='PositionID' and @CostCenterID=94)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Position '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.PositionID=CTLookup.NodeID) '      
  END      
       
  else if (@SysColumnName ='ReasonLookUpID' and @CostCenterID=89)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Reason '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.ReasonLookUpID=CTLookup.NodeID) '      
  END      
  else if (@SysColumnName ='CampaignID' and @CostCenterID=89)      
  BEGIN      
  SET @strColumns=@strColumns+'resource.ResourceName as Campaign '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN PRD_Resources resource WITH(NOLOCK) ON (A.CampaignID=resource.ResourceID) '      
  END      
  else if (@SysColumnName ='LeadID' and @CostCenterID=89)      
  BEGIN      
  SET @strColumns=@strColumns+'lead.Company as Lead '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN CRM_Leads lead WITH(NOLOCK) ON (A.LeadID=lead.LeadID) '      
  END      
  else if (@SysColumnName ='CurrencyID' and @CostCenterID=89)      
  BEGIN      
  SET @strColumns=@strColumns+'currency.Name as Currency '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Currency currency WITH(NOLOCK) ON (A.CurrencyID=currency.CurrencyID) '      
  END     
      
  else if (@SysColumnName ='ClassID' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'class.AssetClassName as Class '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_AssetClass class WITH(NOLOCK) ON (A.ClassID=currency.AssetClassID) '      
  END     
  else if (@SysColumnName ='SubClassID' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'class.AssetClassName as SubClass '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_AssetClass class WITH(NOLOCK) ON (A.SubClassID=class.AssetClassID) '      
  END     
  else if (@SysColumnName ='EmployeeID' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'resource.ResourceName as Employee '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN PRD_Resources resource WITH(NOLOCK) ON (A.EmployeeID=resource.ResourceID) '      
  END     
  else if (@SysColumnName ='ParentAssetID' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'asset.AssetName as Parent Asset '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Assets asset WITH(NOLOCK) ON (A.ParentAssetID=asset.AssetID) '      
  END     
  else if (@SysColumnName ='LocationID' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'location.Name as Location '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Location location WITH(NOLOCK) ON (A.LocationID=location.NodeID) '      
  END     
  else if (@SysColumnName ='AssetDepreciationJV' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'account.DocumentName as AssetDepreciation '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ADM_DocumentTypes account WITH(NOLOCK) ON (A.AssetDepreciationJV=account.CostCenterID) '      
  END    
  else if (@SysColumnName ='AssetDisposalJV' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'account.DocumentName as AssetDisposal '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ADM_DocumentTypes account WITH(NOLOCK) ON (A.AssetDisposalJV=account.CostCenterID) '      
  END     
  else if (@SysColumnName ='PostingGroupID' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'postinggroup.PostGroupName as Posting Group '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_PostingGroup postinggroup WITH(NOLOCK) ON (A.PostingGroupID=postinggroup.PostingGroupID) '      
  END     
  else if (@SysColumnName ='StatusID' and @CostCenterID=72)      
  BEGIN      
  SET @strColumns=@strColumns+'case when A.StatusID=1 then ''Active'' else ''Dispose'' end as Status '     
  END  
  else if (@SysColumnName ='PropertyTypeLookUpID' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Property Type '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.PropertyTypeLookUpID=CTLookup.NodeID) '      
  END      
  else if (@SysColumnName ='LandLordLookUpID' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Land Lord '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.LandLordLookUpID=CTLookup.NodeID) '      
  END       
  else if (@SysColumnName ='BondTypeLookUpID' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Bond Type '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.BondTypeLookUpID=CTLookup.NodeID) '      
  END      
  else if (@SysColumnName ='PropertyPositionLookUpID' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Property Position '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.PropertyPositionLookUpID=CTLookup.NodeID) '      
  END      
  else if (@SysColumnName ='PropertyCategoryLookUpID' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'CTLookup.Name as Property Category '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.PropertyCategoryLookUpID=CTLookup.NodeID) '      
  END      
  else if (@SysColumnName ='RentalIncomeAccountID' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Rental Income Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.RentalIncomeAccountID=ACC.AccountID) '      
  END      
  else if (@SysColumnName ='RentalReceivableAccountID' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Rental Receivable Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.RentalReceivableAccountID=ACC.AccountID) '      
  END      
  else if (@SysColumnName ='AdvanceRentAccountID' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Advance Rent Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.AdvanceRentAccountID=ACC.AccountID) '      
  END      
  else if (@SysColumnName ='BankAccount' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Bank Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.BankAccount=ACC.AccountID) '      
  END      
  else if (@SysColumnName ='BankLoanAccount' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Bank Loan Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.BankLoanAccount=ACC.AccountID) '      
  END      
  else if (@SysColumnName ='RentalAccount' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Rental Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.RentalAccount=ACC.AccountID) '      
  END      
  else if (@SysColumnName ='RentPayableAccount' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Rent Payable Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.RentPayableAccount=ACC.AccountID) '      
  END      
  else if (@SysColumnName ='AdvanceRentPaid' and @CostCenterID=92)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Advance Rent Paid '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.AdvanceRentPaid=ACC.AccountID) '      
  END       
  else if (@SysColumnName ='UnitID' and @CostCenterID=95)      
  BEGIN      
  SET @strColumns=@strColumns+'UNT.Name as Unit '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Units UNT WITH(NOLOCK) ON (A.UnitID=UNT.UnitID) '      
  END        
  else if (@SysColumnName ='PropertyID' and @CostCenterID=95)      
  BEGIN      
  SET @strColumns=@strColumns+'PRT.Name as Property '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Property PRT WITH(NOLOCK) ON (A.PropertyID=PRT.NodeID) '      
  END       
  else if (@SysColumnName ='TenantID' and @CostCenterID=95)      
  BEGIN      
  SET @strColumns=@strColumns+'TNT.FirstName as Tenant '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Tenant TNT WITH(NOLOCK) ON (A.TenantID=TNT.TenantID) '      
  END     
  else if (@SysColumnName ='RentAccID' and @CostCenterID=95)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Rent Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts PRT WITH(NOLOCK) ON (A.RentAccID=ACC.AccountID) '      
  END       
  else if (@SysColumnName ='IncomeAccID' and @CostCenterID=95)      
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Income Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts TNT WITH(NOLOCK) ON (A.IncomeAccID=ACC.AccountID) '      
  END       
  
  else if (@SysColumnName ='UnitID' and (@CostCenterID=103 OR @CostCenterID=104) )      
  BEGIN      
  SET @strColumns=@strColumns+'UNT.Name as Unit '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Units UNT WITH(NOLOCK) ON (A.UnitID=UNT.UnitID) '      
  END        
  else if (@SysColumnName ='PropertyID' and (@CostCenterID=103 OR @CostCenterID=104) )     
  BEGIN      
  SET @strColumns=@strColumns+'PRT.Name as Property '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Property PRT WITH(NOLOCK) ON (A.PropertyID=PRT.NodeID) '      
  END       
  else if (@SysColumnName ='TenantID' and (@CostCenterID=103 OR @CostCenterID=104) )        
  BEGIN      
  SET @strColumns=@strColumns+'TNT.FirstName as Tenant '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Tenant TNT WITH(NOLOCK) ON (A.TenantID=TNT.TenantID) '      
  END     
  else if (@SysColumnName ='RentAccID' and  (@CostCenterID=103 OR @CostCenterID=104) )     
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Rent Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts PRT WITH(NOLOCK) ON (A.RentAccID=ACC.AccountID) '      
  END       
  else if (@SysColumnName ='IncomeAccID' and (@CostCenterID=103 OR @CostCenterID=104) )       
  BEGIN      
  SET @strColumns=@strColumns+'ACC.Name as Income Account '       
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts TNT WITH(NOLOCK) ON (A.IncomeAccID=ACC.AccountID) '      
  END   
  else if((@CostCenterID=2 and @SysColumnName='AccountImage') or (@CostCenterID=3 and @SysColumnName='ProductImage')
  or (@CostCenterID>50000 and @SysColumnName='DimensionImage') )
     begin
		set @strColumns=@strColumns+'f.FileExtension,f.GUID FileGUID  '  
		 SET @STRJOIN=@STRJOIN+' left join COM_Files f WITH(NOLOCK) on FeaturePK='+Convert(nvarchar,@PrimaryCol)+' 
		 and F.CostCenterid='+Convert(nvarchar,@CostCenterID)+' and IsProductImage=1 and IsDefaultImage=1 '
	end
	ELSE IF(@CostCenterID=50051 AND @SysColumnName='CreditDays')     
	BEGIN
			DECLARE @EDOB DATETIME
			SET @SQL ='SELECT @EDOB=CONVERT(DATETIME,DOB) from COM_CC50051 WITH(NOLOCK) Where NodeId='+CONVERT(NVARCHAR,@NodeID)
			EXEC sp_executesql @SQL,N'@EDOB DATETIME OUTPUT',@EDOB OUTPUT
			
			IF(@EDOB IS NOT NULL)
				SET @strColumns=@strColumns+'DATEDIFF(YEAR,'''+CONVERT(NVARCHAR,@EDOB)+''','''+CONVERT(NVARCHAR,GETDATE())+''') as '''+@ColumnResourceData+''''  
			ELSE 
				SET @strColumns=@strColumns+'0 as '''+@ColumnResourceData+''''  
	END     
	ELSE IF(@CostCenterID=50051 AND @SysColumnName='Service')     
	BEGIN
		DECLARE @EDOJ DATETIME,@strVal NVARCHAR(100)
		DECLARE @tbl TABLE (iy INT,im INT,id INT)
		SET @SQL ='SELECT @EDOJ=CONVERT(DATETIME,DOJ) from COM_CC50051 WITH(NOLOCK) Where NodeId='+CONVERT(NVARCHAR,@NodeID)
		EXEC sp_executesql @SQL,N'@EDOJ DATETIME OUTPUT',@EDOJ OUTPUT

		INSERT INTO @tbl
		SELECT * FROM fnCOM_GetYearsMonthsDays(@EDOJ,GETDATE())
		SELECT @strVal= convert(nvarchar,iy)+' Years '+convert(nvarchar,im)+' Months '+convert(nvarchar,id)+' Days' FROM @tbl 
		SET @strColumns=@strColumns+''''+@strVal+''' as '''+@ColumnResourceData+''''  

	END  
	ELSE IF(@CostCenterID=50051 AND @SysColumnName='NextShift')     
	BEGIN
		DECLARE @Shift NVARCHAR(100)
		SET @Shift=''
		EXEC spPAY_GetEmpShift @Date,@NodeID,@UserID,@LangID,@Shift OUTPUT
		SET @strColumns=@strColumns+''''+@Shift+''' as '''+@ColumnResourceData+''''  

	END 
	ELSE IF(@CostCenterID=50051 AND @SysColumnName='LastIncrement')     
	BEGIN
		DECLARE @LastIncrement NVARCHAR(100)
		SET @LastIncrement=''
		SET @SQL ='SELECT TOP 1 @LastIncrement=REPLACE(SUBSTRING(CONVERT(VARCHAR(11), CONVERT(DATETIME,a.EffectFrom), 113), 4, 8),'' '',''-'')
		FROM PAY_EmpPay a WITH(NOLOCK)
		WHERE EmployeeID='+CONVERT(NVARCHAR,@NodeID) +'
		ORDER BY a.EffectFrom DESC '

		EXEC sp_executesql @SQL,N'@LastIncrement NVARCHAR(100) OUTPUT',@LastIncrement OUTPUT

		SET @strColumns=@strColumns+''''+@LastIncrement+''' as '''+@ColumnResourceData+''''  

	END 
	ELSE IF(@CostCenterID=50051 AND (@SysColumnName='BasicMonthly' OR @SysColumnName='NetSalary' OR @SysColumnName='AnnualCTC'))  
	begin
		DECLARE @PayValue NVARCHAR(100)
		SET @PayValue=''
		SET @SQL ='SELECT @PayValue='+@SysColumnName+' FROM Pay_EmpPay C1 WITH(NOLOCK) WHERE C1.EmployeeID='+CONVERT(NVARCHAR,@NodeID) +' AND C1.SeqNo IN (SELECT TOP 1 SeqNo FROM PAY_EMPPAY with(nolock) WHERE EmployeeID='+CONVERT(NVARCHAR,@NodeID) +' ORDER BY EffectFrom DESC)'

		EXEC sp_executesql @SQL,N'@PayValue NVARCHAR(100) OUTPUT',@PayValue OUTPUT
		SET @strColumns=@strColumns+''''+@PayValue+''' as '''+@ColumnResourceData+''''
	end 
    ELSE IF(@SysColumnName='StatusID')              
    BEGIN          
 --if @CostCenterID=2       
 -- set @tempgroup=@tempgroup+' S.ResourceData , '  
      
		IF(@CostCenterID=50051)
		BEGIN
			SET @strColumns=SUBSTRING(@strColumns,0,LEN(@strColumns))
			--select @strColumns,@NodeID,@Date,@LangID
			EXEC spPAY_GetEmpAsOnStatus @NodeID,@Date,@LangID,@EmpAsOnStatus OUTPUT
		END
		ELSE
		BEGIN
			 SET @strColumns=@strColumns+'S.ResourceData as '''+@ColumnResourceData+''''              
			 SET @STRJOIN=@STRJOIN+' JOIN COM_Status SS WITH(NOLOCK) ON A.StatusID=SS.StatusID              
			 JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=SS.ResourceID AND S.LanguageID='+convert(NVARCHAR(10),@LangID)              
		 END
        
    END              
 ELSE IF(@SysColumnName='DeprBookMethod' and @CostCenterID=75)              
    BEGIN              
  SET @strColumns=@strColumns+'DM.Name  as  ''Depreciation Method'''            
     SET @STRJOIN=@STRJOIN+' left JOIN ACC_DepreciationMethods DM WITH(NOLOCK) ON A.DeprBookMethod=DM.DepreciationMethodID '      
             
    END          
    ELSE IF(@SysColumnName='AccountTypeID')              
    BEGIN              
 --if @CostCenterID=2       
 -- set @tempgroup=@tempgroup+'AT.ResourceData  '      
     SET @strColumns=@strColumns+'AT.ResourceData  as '''+@ColumnResourceData+''''              
     SET @STRJOIN=@STRJOIN+' JOIN ACC_AccountTypes AA WITH(NOLOCK) ON A.AccountTypeID=AA.AccountTypeID              
     JOIN COM_LanguageResources AT WITH(NOLOCK) ON AT.ResourceID=AA.ResourceID AND AT.LanguageID='+convert(NVARCHAR(10),@LangID)              
    END              
    ELSE IF(@SysColumnName='CustomerTypeID')              
    BEGIN              
  --if @CostCenterID=2       
  --set @tempgroup=@tempgroup+'AT.ResourceData  '      
     SET @strColumns=@strColumns+'AT.ResourceData as CustomerType'              
     SET @STRJOIN=@STRJOIN+' JOIN ACC_AccountTypes AA WITH(NOLOCK) ON A.CustomerTypeID=AA.AccountTypeID              
     JOIN COM_LanguageResources AT WITH(NOLOCK) ON AT.ResourceID=AA.ResourceID AND AT.LanguageID='+convert(NVARCHAR(10),@LangID)              
    END              
    ELSE IF(@SysColumnName='ProductTypeID')              
    BEGIN              
  --if @CostCenterID=2       
  --set @tempgroup=@tempgroup+'PT.ResourceData  '      
     SET @strColumns=@strColumns+'PT.ResourceData  as '''+@ColumnResourceData+''''            
     SET @STRJOIN=@STRJOIN+' JOIN INV_ProductTypes PP WITH(NOLOCK) ON A.ProductTypeID=PP.ProductTypeID              
     JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=PP.ResourceID AND PT.LanguageID='+ convert(NVARCHAR(10),@LangID)              
    END              
 ELSE IF(@SysColumnName='DeprBookMethod' and @CostCenterID=75)              
    BEGIN              
  SET @strColumns=@strColumns+'DM.Name  as  ''Depreciation Method'''            
     SET @STRJOIN=@STRJOIN+' left JOIN ACC_DepreciationMethods DM WITH(NOLOCK) ON A.DeprBookMethod=DM.DepreciationMethodID '      
             
    END      
     ELSE IF(@SysColumnName='BudgetName' and @CostCenterID=101)              
    BEGIN              
	  SET @strColumns=@strColumns+'BD.BudgetName  as  '''+@ColumnResourceData+''''           
     SET @STRJOIN=@STRJOIN+' inner JOIN COM_BudgetDef BD WITH(NOLOCK) ON A.BudgetDefID=BD.BudgetDefID '      
             
    END    
     ELSE IF(@SysColumnName='RoleID' and @CostCenterID=7)
     BEGIN
		SET @strColumns=@strColumns+'RL.Name as '''+@ColumnResourceData+''''
		SET @STRJOIN=@STRJOIN+'  LEFT JOIN ADM_UserRoleMap URM WITH(NOLOCK) ON URM.UserID=A.UserID AND URM.IsDefault=1 '
		SET @STRJOIN=@STRJOIN+'  LEFT JOIN ADM_PRoles RL WITH(NOLOCK) ON RL.RoleID=URM.RoleID '
     END 
    ELSE IF(@SysColumnName <> '')              
    BEGIN              
		if(@ColumnDataType is not null and @ColumnDataType='DATE')              
			SET @strColumns=@strColumns+'convert(nvarchar(12),Convert(datetime,A.'+@SysColumnName+'),106)  as '''+@ColumnResourceData+''''   
		else if @ColumnCostCenterID=44
		begin
			SET @strColumns=@strColumns+'L'+CONVERT(NVARCHAR(10),@CostCenterColID) +'.Name as '''+@ColumnResourceData+'''' 
			SET @STRJOIN=@STRJOIN+' left JOIN COM_Lookup L'+CONVERT(NVARCHAR(10),@CostCenterColID)              
				+' WITH(NOLOCK) ON A.'+@SysColumnName +'= L'+CONVERT(NVARCHAR(10),@CostCenterColID)+'.NodeID'
		end
        else
			SET @strColumns=@strColumns+'A.'+@SysColumnName+' as '''+@ColumnResourceData+''''              
     END       
 ELSE               
 BEGIN                  
     SET @strColumns=@strColumns+'A.'+@SysColumnName+' as '''+@ColumnResourceData+''''              
 END              
 
   END

   if (@CostCenterID=2 and @strColumns not like '%A.AccountTypeID%')
	set @strColumns = @strColumns+',A.AccountTypeID'
	
	IF(@CostCenterID=50051 AND EXISTS (SELECT * FROM @tblList WHERE CostCenterColID=30002)) ---StatusID
	BEGIN
		SET @SQL=' with rows as ( select 1 rowno,'+@Primarycol+' as NodeID'+@strColumns+','''+@EmpAsOnStatus+''' as Status'+@strIDCols +@STRJOIN+' WHERE '+@Primarycol+' IN(' +convert(nvarchar(MAX), @NodeID)   +')'+ @tempWhere     +      
					' ) select * from rows ' 
	END
	ELSE
	BEGIN  
		SET @SQL=' with rows as ( select 1 rowno,'+@Primarycol+' as NodeID'+@strColumns+@strIDCols+@STRJOIN+' WHERE '+@Primarycol+' IN(' +convert(nvarchar(MAX), @NodeID)   +')'+ @tempWhere     +      
					' ) select * from rows '              
	END
              
       
   
	IF(@CostCenterID=117)              
	BEGIN              
		SET @SQL=' Select distinct 1 rowno, DashBoardName,DashBoardType from ADM_DashBoard with(nolock) where DashBoardID='+convert(nvarchar(50), @NodeID)     
	end                       
               
	SET @SQL=@SQL+' SELECT * FROM  COM_Files WITH(NOLOCK)  WHERE FeatureID='+Convert(nvarchar,@CostCenterID)+' and  FeaturePK in ('+Convert(nvarchar(max),@NodeID)+')'              
	
	print @SQL
	if(@NodeID<>'')
		Exec sp_executesql @SQL               

SET NOCOUNT OFF;              
RETURN 1              
END TRY              
BEGIN CATCH                
 --Return exception info [Message,Number,ProcedureName,LineNumber]                
 IF ERROR_NUMBER()=50000              
 BEGIN              
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID               END              
 ELSE              
 BEGIN              
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine              
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID              
 END              

SET NOCOUNT OFF                
RETURN -999                 
END CATCH


GO
