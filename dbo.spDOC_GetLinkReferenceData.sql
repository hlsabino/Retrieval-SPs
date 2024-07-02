USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetLinkReferenceData]
	@COSTCENTERCOlID [int],
	@DOCUMENTID [int],
	@NODEID [int],
	@DocDate [datetime],
	@CreditAccount [int],
	@ccxml [nvarchar](max),
	@ProfileExists [bit] = 0,
	@DocumentLinkDefID [int] = 0,
	@LocationID [int] = 0,
	@DivisionID [int] = 0,
	@DueDate [datetime] = null,
	@DocID [int] = 0,
	@DbAcc [int] = 0,
	@CrAcc [int] = 0,
	@DimWhere [nvarchar](max) = '',
	@UserID [int] = 0,
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY    
SET NOCOUNT ON;  

DECLARE @TABLE NVARCHAR(50),@QUERY NVARCHAR(MAX),@AccWhere NVARCHAR(MAX),@TEMPCOLUMN NVARCHAR(500),@COLUMN NVARCHAR(50) , @DUPLICATECODE NVARCHAR(500),@tempCode NVARCHAR(500)
DECLARE @ID NVARCHAR(100),@COLUMNCNT INT ,@COLUMNS NVARCHAR(MAX),@TableName NVARCHAR(100),@Join NVARCHAR(MAX),@sql nvarchar(max),@dependancy int
DECLARE @FeatureID INT,@FeatureTableName NVARCHAR(100),@COSTCENTERID INT,@xml xml,@Where nvarchar(max),@CID INT,@CurrencyID INT
declare @lOCATION INT,@IsParent BIT,@ccWhere nvarchar(max),@IncludeCC nvarchar(max),@isHist bit,@linkData INT,@dec int

	set @dec=2
	select @dec=convert(int,value) from adm_globalpreferences WITH(NOLOCK)
	where name ='DecimalsinAmount' and isnumeric(value)=1

	SELECT @COSTCENTERID=ColumnCostCenterID from ADM_CostCenterDef WITH(NOLOCK) where CostCenterColID=@COSTCENTERCOlID
	declare @cctable table(ID INT IDENTITY(1,1),CCID nvarchar(50)) 
	SELECT @TableName=TABLENAME FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID=@COSTCENTERID 

	declare @dims TABLE(ID INT IDENTITY(1,1),CCID int,NodeID INT)
	set @XML=@ccxml
	insert into @dims
	SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')
	from @XML.nodes('/XML/Row') as Data(X) 


	if(@CostCenterID=2)
	begin
		declare @includepdc nvarchar(10),@includeunposted nvarchar(10)
		set @AccWhere=''		
				
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
	end
	
	IF(@COSTCENTERID =2)
		SET @ID = 'ACCOUNTID'
	ELSE IF(@COSTCENTERID =3)
		SET @ID = 'PRODUCTID'
	ELSE IF(@COSTCENTERID =83)
		SET @ID = 'CustomerID'	
	ELSE IF(@COSTCENTERID =65)
		SET @ID = 'ContactID'					
	ELSE 
		SET @ID = 'NODEID'
	 
	declare @TEMPLINKTABLE TABLE (ID INT IDENTITY(1,1) ,SYSCOLUMNNAME NVARCHAR(100),FCCID INT,COLUMNNAME NVARCHAR(100),CCID INT,IsParent BIT,inclcc nvarchar(max),dependancy int,filterinuse bit,FeatureID int,Prob bit,LinkData INT)
	
	INSERT INTO @TEMPLINKTABLE 
	SELECT ISNULL(CDF.SYSCOLUMNNAME,C.LinkData),ISNULL(CDF.ColumnCostCenterID,C.linkdata) , C.SYSCOLUMNNAME,C.ColumnCostCenterID,0,c.LastValueVouchers,C.dependancy
	,isnull(PDF.IsColumnInUse,0) as filterinuse
	,CDF.CostCenterID,case when C.linkdata is null and PDF.syscolumnname like 'ccnid%' and pdf.UserProbableValues='h' then 1 when CDF.UserProbableValues='h' then 1 else 0 end ,C.linkdata
	FROM ADM_COSTCENTERDEF C WITH(NOLOCK) 
	LEFT JOIN ADM_CostCenterDef CDF WITH(NOLOCK)  ON C.linkdata = CDF.CostCenterColID 
	LEFT JOIN ADM_CostCenterDef PDF WITH(NOLOCK)  ON PDF.costcenterid = @COSTCENTERID and PDF.syscolumnname=REPLACE(C.SYSCOLUMNNAME,'dc','')
	WHERE C.CostCenterID = @DOCUMENTID AND (c.LocalReference = @COSTCENTERCOlID OR c.LocalReference = -@COSTCENTERCOlID)
	and  (@DOCUMENTID in (154) or C.linkdata is null or C.linkdata not in (-100,-101,-102,276,277,22786,22787,22788,22789,22790,22791,22792,22793,22794,22795,22796,22797,22798,22799,22820,22821))
	and not (C.linkdata is not null and (@COSTCENTERID =3 and C.linkdata<0))
	and C.SysColumnName not like 'dccalc%'
	
	if(@COSTCENTERID =3 )
	BEGIN
		INSERT INTO @TEMPLINKTABLE
		SELECT ISNULL(CDF.SYSCOLUMNNAME,(C.linkdata*-1)),ISNULL(CDF.ColumnCostCenterID,(C.linkdata*-1)) , C.SYSCOLUMNNAME,C.ColumnCostCenterID,1,'',0,0,CDF.CostCenterID,0,C.linkdata
			FROM ADM_COSTCENTERDEF C WITH(NOLOCK) 
		LEFT JOIN ADM_CostCenterDef CDF WITH(NOLOCK)  ON (C.linkdata*-1) = CDF.CostCenterColID    
		WHERE C.CostCenterID = @DOCUMENTID AND  c.LocalReference = @COSTCENTERCOlID 
		and  C.linkdata is not null and C.linkdata<0	and  C.linkdata not in (-100,-101,-102)
		and C.SysColumnName not like 'dccalc%'
		union all
		SELECT CDF.SYSCOLUMNNAME,0 , C.SYSCOLUMNNAME,0,0,'',0,0,0,0,C.linkdata
		FROM ADM_COSTCENTERDEF C WITH(NOLOCK) 	
		LEFT JOIN ADM_CostCenterDef CDF WITH(NOLOCK)  ON C.linkdata = CDF.CostCenterColID
		WHERE C.CostCenterID = @DOCUMENTID AND  c.LocalReference = 79 
		and  C.linkdata =225
	END
	
	declare @LocWise bit,@DivWise bit,@DIVIS INT,@DimWise INT
	select @LocWise=value from adm_globalpreferences WITH(NOLOCK) where name='EnableLocationWise'
	select @DivWise=value from adm_globalpreferences WITH(NOLOCK) where name='EnableDivisionWise'
	SELECT @DimWise=ISNULL(CONVERT(INT,value),0) from adm_globalpreferences WITH(NOLOCK) where name='DimWiseCreditDebit'
	
	if(@LocWise=1)
		select @LocWise=value from adm_globalpreferences WITH(NOLOCK) where name='LW CreditDebit' 
	if(@DivWise=1)
		select @DivWise=value from adm_globalpreferences WITH(NOLOCK) where name='DW CreditDebit'
						
	IF((@LocWise=1 AND @COSTCENTERID=50001) OR (@DivWise=1 AND @COSTCENTERID=50002) OR (@DimWise>0 AND @COSTCENTERID=@DimWise) )
	BEGIN
		INSERT INTO @TEMPLINKTABLE 
		SELECT ISNULL(CDF.SYSCOLUMNNAME,C.LinkData),ISNULL(CDF.ColumnCostCenterID,C.linkdata) , C.SYSCOLUMNNAME,C.ColumnCostCenterID,0,c.LastValueVouchers,C.dependancy
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=@COSTCENTERID and  syscolumnname=REPLACE(C.SYSCOLUMNNAME,'dc','')) as filterinuse
		,CDF.CostCenterID,0,C.linkdata
		FROM ADM_COSTCENTERDEF C WITH(NOLOCK) 
		LEFT JOIN ADM_CostCenterDef CDF WITH(NOLOCK)  ON C.linkdata = CDF.CostCenterColID    
		WHERE C.CostCenterID = @DOCUMENTID and C.linkdata in (49994,49995,49996,49997,49998,49999)
	END
	
	set @Join=''
	SELECT @COLUMNCNT = COUNT(ID)  FROM @TEMPLINKTABLE
 
	DECLARE @I INT,@LinkFeatureID int
	
 	SET @I = 1
    WHILE (@COLUMNCNT >= @I)
    BEGIN 
		set @IncludeCC=''
		SELECT @TEMPCOLUMN = SYSCOLUMNNAME,@COLUMN = COLUMNNAME,@IsParent=IsParent,@IncludeCC=isnull(inclcc,''),@LinkFeatureID=FeatureID,@isHist=Prob,@linkData=LinkData
		FROM @TEMPLINKTABLE WHERE ID =  @I  			
		
		IF @TEMPCOLUMN='-1'
			SET @TEMPCOLUMN='addr.AddressName AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-2'
			SET @TEMPCOLUMN='addr.ContactPerson AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-3'
			SET @TEMPCOLUMN='addr.Address1 AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-4'
			SET @TEMPCOLUMN='addr.Address2 AS '+ @COLUMN		
		ELSE IF @TEMPCOLUMN='-5'
			SET @TEMPCOLUMN='addr.Address3 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-6'
			SET @TEMPCOLUMN='addr.City AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-7'
			SET @TEMPCOLUMN='addr.State AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-8'
			SET @TEMPCOLUMN='addr.Zip AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-9'
			SET @TEMPCOLUMN='addr.Country AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-10'
			SET @TEMPCOLUMN='addr.Phone1 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-11'
			SET @TEMPCOLUMN='addr.Phone2 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-12'
			SET @TEMPCOLUMN='addr.Fax AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-13'
			SET @TEMPCOLUMN='addr.Email1 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-14'
			SET @TEMPCOLUMN='addr.Email2 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-15'
			SET @TEMPCOLUMN='addr.URL AS '+ @COLUMN

		ELSE IF @TEMPCOLUMN='-16'
			SET @TEMPCOLUMN='bill.AddressName AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-17'
			SET @TEMPCOLUMN='bill.ContactPerson AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-18'
			SET @TEMPCOLUMN='bill.Address1 AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-19'
			SET @TEMPCOLUMN='bill.Address2 AS '+ @COLUMN		
		ELSE IF @TEMPCOLUMN='-20'
			SET @TEMPCOLUMN='bill.Address3 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-21'
			SET @TEMPCOLUMN='bill.City AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-22'
			SET @TEMPCOLUMN='bill.State AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-23'
			SET @TEMPCOLUMN='bill.Zip AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-24'
			SET @TEMPCOLUMN='bill.Country AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-25'
			SET @TEMPCOLUMN='bill.Phone1 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-26'
			SET @TEMPCOLUMN='bill.Phone2 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-27'
			SET @TEMPCOLUMN='bill.Fax AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-28'
			SET @TEMPCOLUMN='bill.Email1 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-29'
			SET @TEMPCOLUMN='bill.Email2 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-30'
			SET @TEMPCOLUMN='bill.URL AS '+ @COLUMN 
		ELSE IF @TEMPCOLUMN='-31'
			SET @TEMPCOLUMN='ship.AddressName AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-32'
			SET @TEMPCOLUMN='ship.ContactPerson AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-33'
			SET @TEMPCOLUMN='ship.Address1 AS '+ @COLUMN	
		ELSE IF @TEMPCOLUMN='-34'
			SET @TEMPCOLUMN='ship.Address2 AS '+ @COLUMN		
		ELSE IF @TEMPCOLUMN='-35'
			SET @TEMPCOLUMN='ship.Address3 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-36'
			SET @TEMPCOLUMN='ship.City AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-37'
			SET @TEMPCOLUMN='ship.State AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-38'
			SET @TEMPCOLUMN='ship.Zip AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-39'
			SET @TEMPCOLUMN='ship.Country AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-40'
			SET @TEMPCOLUMN='ship.Phone1 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-41'
			SET @TEMPCOLUMN='ship.Phone2 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-42'
			SET @TEMPCOLUMN='ship.Fax AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-43'
			SET @TEMPCOLUMN='ship.Email1 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-44'
			SET @TEMPCOLUMN='ship.Email2 AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='-45'
			SET @TEMPCOLUMN='ship.URL AS '+ @COLUMN
		ELSE IF @TEMPCOLUMN='CompanyCountry'
		BEGIN
		begin
			set @TEMPCOLUMN=(select E.acAlpha41 
			from PACT2C.dbo.adm_company C with(nolock) inner join PACT2C.dbo.ADM_CompanyExtended E with(nolock) ON C.CompanyID=E.CompanyID where C.DBName=db_name())
			set @TEMPCOLUMN=''''+isnull(@TEMPCOLUMN,'')+''' as '+@COLUMN
		end
		END	
		else if @LinkFeatureID=110 and @COLUMN not like '%CCNID%'
		begin
			SET @TEMPCOLUMN='addr.'+@TEMPCOLUMN+' AS '+ @COLUMN
			--set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID'
		end	
		--else if exists (select syscolumnname from ADM_CostCenterDef where CostCenterID=110 and CostCenterColID=-(convert(float,@TEMPCOLUMN)))
		--begin
		--	declare @cname nvarchar(100)
		--	select @cname=syscolumnname from ADM_CostCenterDef where CostCenterID=110 and CostCenterColID=-(convert(float,@TEMPCOLUMN))
		--	set @TEMPCOLUMN='addr.'+@cname +' AS '+ @COLUMN
		--end
		ELSE IF(@TEMPCOLUMN IS NOT NULL AND @TEMPCOLUMN<>'' AND @LinkFeatureID<>110)
		BEGIN 
			if(@TEMPCOLUMN like '%CCNID%' or @TEMPCOLUMN='CategoryID' or (@COSTCENTERID>50000 and @TEMPCOLUMN in('ProductID','AccountID','RptManager')))
			begin
				select @FeatureID=FCCID from  @TEMPLINKTABLE WHERE ID =  @I  			
				SELECT @FeatureTableName=TABLENAME FROM ADM_FEATURES WITH(NOLOCK)  WHERE FEATUREID =  @FeatureID 

				if(@TEMPCOLUMN='CategoryID')
				BEGIN
					set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID'
					if(@IsParent=1)
					BEGIN
						set @Join=@Join+'=pa.'+@TEMPCOLUMN
						set @TEMPCOLUMN='pa.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
					END	
					else
					BEGIN
						set @Join=@Join+'=a.'+@TEMPCOLUMN
						set @TEMPCOLUMN='a.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
					END	
				END	
				else if(@TEMPCOLUMN='ProductID')
				BEGIN
					set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.ProductID'
					if(@IsParent=1)
					BEGIN
						set @Join=@Join+'=pc.'+@TEMPCOLUMN
						set @TEMPCOLUMN='pc.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
					END	
					else
					BEGIN
						set @Join=@Join+'=c.'+@TEMPCOLUMN
						set @TEMPCOLUMN='c.'+@TEMPCOLUMN+ ' AS '+ @COLUMN

					END	
					set @TEMPCOLUMN=@TEMPCOLUMN+',C'+CONVERT(nvarchar,@I)+'.ProductNAME '+ ' AS '+ @COLUMN+'Name,C'+CONVERT(nvarchar,@I)+'.ProductCode '+ ' AS '+ @COLUMN+'Code'
				END	
				else if(@TEMPCOLUMN='AccountID')
				BEGIN
					set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.AccountID'
					if(@IsParent=1)
					BEGIN
						set @Join=@Join+'=pc.'+@TEMPCOLUMN
						set @TEMPCOLUMN='pc.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
					END	
					else
					BEGIN
						set @Join=@Join+'=c.'+@TEMPCOLUMN
						set @TEMPCOLUMN='c.'+@TEMPCOLUMN+ ' AS '+ @COLUMN

					END	
					set @TEMPCOLUMN=@TEMPCOLUMN+',C'+CONVERT(nvarchar,@I)+'.AccountNAME '+ ' AS '+ @COLUMN+'Name,C'+CONVERT(nvarchar,@I)+'.AccountCode '+ ' AS '+ @COLUMN+'Code'
				END	
				else if(@TEMPCOLUMN='RptManager')
				BEGIN
					set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NodeID'
					if(@IsParent=1)
					BEGIN
						set @Join=@Join+'=pc.'+@TEMPCOLUMN
						set @TEMPCOLUMN='pc.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
					END	
					else
					BEGIN
						set @Join=@Join+'=a.'+@TEMPCOLUMN
						set @TEMPCOLUMN='a.'+@TEMPCOLUMN+ ' AS '+ @COLUMN

					END	
					set @TEMPCOLUMN=@TEMPCOLUMN+',C'+CONVERT(nvarchar,@I)+'.Name '+ ' AS '+ @COLUMN+'Name,C'+CONVERT(nvarchar,@I)+'.Code '+ ' AS '+ @COLUMN+'Code'
				END	
				else	
				BEGIN
					set @CID=0
					
					if(@isHist=1)
						select @CID=HistoryNodeID from COM_HistoryDetails with(nolock)
						where Costcenterid=@costcenteriD and NodeID=@NODEID and HistoryCCID=@FeatureID
						and fromdate<=@DocDate and (todate is null or todate>=@DocDate)
						order by fromdate
					
					if(@CID>0)
					BEGIN
						set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID='+convert(nvarchar(max),@CID)
						set @TEMPCOLUMN=convert(nvarchar(max),@CID)+ ' AS '+ @COLUMN
					END	
					ELSE
					BEGIN
						set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID'
					
						if(@IsParent=1)
						BEGIN
							set @Join=@Join+'=pc.'+@TEMPCOLUMN
							set @TEMPCOLUMN='pc.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
						END	
						else
						BEGIN
							set @Join=@Join+'=c.'+@TEMPCOLUMN
							set @TEMPCOLUMN='c.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
						END	
					END	
				END	
				
				if(@TEMPCOLUMN not like '%ProductID%' and @TEMPCOLUMN not like '%AccountID%' and @TEMPCOLUMN not like '%RptManager%')
					set @TEMPCOLUMN=@TEMPCOLUMN+',C'+CONVERT(nvarchar,@I)+'.NAME '+ ' AS '+ @COLUMN+'Name,C'+CONVERT(nvarchar,@I)+'.Code '+ ' AS '+ @COLUMN+'Code'
			end	
			else if(@TEMPCOLUMN = 'ParentID')
			begin
				if(@Join not like '%Par%')
					set @Join=@Join+' JOIN '+@TableName+' Par WITH(NOLOCK) ON Par.'+@ID+'=a.ParentID '
				if exists(select *from adm_costcenterdef a WITH(NOLOCK)
				join adm_costcenterdef b WITH(NOLOCK) on a.ParentCCDefaultColid=b.Costcentercolid
				where a.costcentercolid=@linkData and a.syscolumnname='parentid' and b.syscolumnname like '%code')
				BEGIN
					if(@COSTCENTERID =3)
						set @TEMPCOLUMN='a.ParentID AS '+ @COLUMN+',Par.ProductCode AS '+ @COLUMN+'Name'
					else if(@COSTCENTERID =2)
						set @TEMPCOLUMN='a.ParentID AS '+ @COLUMN+',Par.AccountCode AS '+ @COLUMN+'Name'	
					else if(@COSTCENTERID >50000)
						set @TEMPCOLUMN='a.ParentID AS '+ @COLUMN+',Par.Code AS '+ @COLUMN+'Name'		
				END
				ELSE
				BEGIN
					if(@COSTCENTERID =3)
						set @TEMPCOLUMN='a.ParentID AS '+ @COLUMN+',Par.ProductName AS '+ @COLUMN+'Name'
					else if(@COSTCENTERID =2)
						set @TEMPCOLUMN='a.ParentID AS '+ @COLUMN+',Par.AccountName AS '+ @COLUMN+'Name'	
					else if(@COSTCENTERID >50000)
						set @TEMPCOLUMN='a.ParentID AS '+ @COLUMN+',Par.Name AS '+ @COLUMN+'Name'		
				END
			END
			else if(@TEMPCOLUMN = 'ProductTypeID')
			begin
				set @Join=@Join+'JOIN INV_ProductTypes PP WITH(NOLOCK) ON '
				if(@IsParent=1)
					set @Join=@Join+'PA.ProductTypeID'
				else								
					set @Join=@Join+'A.ProductTypeID'
				
				set @Join=@Join+'=PP.ProductTypeID            
				 JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=PP.ResourceID AND PT.LanguageID='+ convert(NVARCHAR(10),@LangID)            
				
				set @TEMPCOLUMN='PT.ResourceData AS '+ @COLUMN
			end	
			else if(@TEMPCOLUMN = 'ProductTypeID')
			begin
				set @Join=@Join+'JOIN INV_ProductTypes PP WITH(NOLOCK) ON '
				if(@IsParent=1)
					set @Join=@Join+'PA.ProductTypeID'
				else								
					set @Join=@Join+'A.ProductTypeID'
				
				set @Join=@Join+'=PP.ProductTypeID            
				 JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=PP.ResourceID AND PT.LanguageID='+ convert(NVARCHAR(10),@LangID)            
				
				set @TEMPCOLUMN='PT.ResourceData AS '+ @COLUMN
			end	
			else if(@TEMPCOLUMN = 'uomid')
			begin
				set @Join=@Join+'JOIN Com_UOM UM WITH(NOLOCK) ON '
				if(@IsParent=1)
					set @Join=@Join+'PA.UOMID'
				else								
					set @Join=@Join+'A.UOMID'
				
				set @Join=@Join+'=UM.UOMID  '
				
				set @TEMPCOLUMN='UM.UnitName AS '+ @COLUMN
			end	
			else if(@TEMPCOLUMN = 'Due As On Document Date')
			begin			
				delete from @cctable
				insert into @cctable  
				exec SPSplitString @IncludeCC,','  
				set @ccWhere=''
				select @ccWhere=@ccWhere+' and dcccnid'+convert(nvarchar,(a.CCID-50000))+'='+convert(nvarchar,NodeID)
				from @dims a join @cctable b on a.CCID=b.CCID
				
					
				set @TEMPCOLUMN='(select abs(sum(Amount+Paid)) from (SELECT AdjAmount Amount,
				ISNULL((SELECT SUM(SQ.AdjAmount) FROM COM_Billwise SQ WITH(NOLOCK) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo ),0) Paid
				FROM COM_Billwise B WITH(NOLOCK) WHERE AccountID=a.AccountID and DocDueDate<='+convert(nvarchar,convert(float,@DocDate))+@ccWhere+' and IsNewReference=1)as t)  AS '+ @COLUMN
			end	
			else if(@TEMPCOLUMN = 'Due As On Date')
			begin			
				delete from @cctable
				insert into @cctable  
				exec SPSplitString @IncludeCC,','  
				set @ccWhere=''
				select @ccWhere=@ccWhere+' and dcccnid'+convert(nvarchar,(a.CCID-50000))+'='+convert(nvarchar,NodeID)
				from @dims a join @cctable b on a.CCID=b.CCID
								
				set @TEMPCOLUMN='(select abs(sum(Amount+Paid)) from (SELECT AdjAmount Amount,
				ISNULL((SELECT SUM(SQ.AdjAmount) FROM COM_Billwise SQ  WITH(NOLOCK) WHERE SQ.RefDocNo=B.DocNo AND SQ.RefDocSeqNo=B.DocSeqNo ),0) Paid
				FROM COM_Billwise B WITH(NOLOCK)  WHERE AccountID=a.AccountID and DocDueDate<='+convert(nvarchar,convert(float,getdate()))+@ccWhere+' and IsNewReference=1)as t)  AS '+ @COLUMN
			end	
			else if(@TEMPCOLUMN = 'Balance As On Document Date')
			begin				
				delete from @cctable
				insert into @cctable  
				exec SPSplitString @IncludeCC,','  
				set @ccWhere=''
				select @ccWhere=@ccWhere+' and dcccnid'+convert(nvarchar,(a.CCID-50000))+'='+convert(nvarchar,NodeID)
				from @dims a join @cctable b on a.CCID=b.CCID
							
				declare @BalDocDate float
				if(@ccWhere<>'')
				BEGIN					
					--Debit Amount	
					set @sql='SELECT @BalDocDate=isnull(sum(Amt),0) from (SELECT ISNULL(AMOUNT,0) Amt FROM ACC_DocDetails AD with(nolock)
							 JOIN Com_docCCData D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
						 where DebitAccount='+convert(nvarchar,@NodeID)+@ccWhere
						+' and DocDate<='+convert(nvarchar,convert(float,@DocDate))+@AccWhere+'
						UNION ALL
						SELECT ISNULL(AMOUNT,0) Amt FROM ACC_DocDetails ID with(nolock)
						JOIN Com_docCCData D1 with(nolock) ON D1.AccDocDetailsID=ID.AccDocDetailsID
						 where DebitAccount='+convert(nvarchar,@NodeID)+@ccWhere
						+' and DocDate<='+convert(nvarchar,convert(float,@DocDate))+@AccWhere+') as t '
					exec sp_executesql @sql,N'@BalDocDate float output',@BalDocDate output
					--Credit Amount	 
					set @sql='SELECT @BalDocDate=@BalDocDate-isnull(sum(Amt),0) from (SELECT ISNULL(AMOUNT,0) Amt FROM ACC_DocDetails AD with(nolock)
							 JOIN Com_docCCData D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
						 where CreditAccount='+convert(nvarchar,@NodeID)+@ccWhere
						+' and DocDate<='+convert(nvarchar,convert(float,@DocDate))+@AccWhere+'
						UNION ALL
						SELECT ISNULL(AMOUNT,0) Amt FROM ACC_DocDetails ID with(nolock)
						JOIN Com_docCCData D1 with(nolock) ON D1.AccDocDetailsID=ID.AccDocDetailsID
						 where CreditAccount='+convert(nvarchar,@NodeID)+@ccWhere
						+' and DocDate<='+convert(nvarchar,convert(float,@DocDate))+@AccWhere+') as t '
					exec sp_executesql @sql,N'@BalDocDate float output',@BalDocDate output
				END
				ELSE
				BEGIN				
					--Debit Amount	
					set @sql='SELECT @BalDocDate=ISNULL((SELECT SUM(ISNULL(AMOUNT,0)) FROM ACC_DocDetails with(nolock) where DebitAccount='+convert(nvarchar,@NodeID)
					+' and DocDate<='+convert(nvarchar,convert(float,@DocDate))+@AccWhere+'),0) '
					--Credit Amount	 
					set @sql=@sql+'-ISNULL((SELECT SUM(ISNULL(AMOUNT,0)) FROM ACC_DocDetails with(nolock) where CreditAccount='+convert(nvarchar,@NodeID)
					+' and DocDate<='+convert(nvarchar,convert(float,@DocDate))+@AccWhere+'),0)'
					exec sp_executesql @sql,N'@BalDocDate float output',@BalDocDate output
				END
				
				print @sql
				SET @TEMPCOLUMN='CONVERT(FLOAT,'+CONVERT(NVARCHAR,round(@BalDocDate,@dec))+')  AS '+ @COLUMN
			end	
			else if(@TEMPCOLUMN = 'Balance As On System Date')
			begin		
				delete from @cctable
				insert into @cctable  
				exec SPSplitString @IncludeCC,','  
				set @ccWhere=''
				select @ccWhere=@ccWhere+' and dcccnid'+convert(nvarchar,(a.CCID-50000))+'='+convert(nvarchar,NodeID)
				from @dims a join @cctable b on a.CCID=b.CCID
						
				declare @BalSysDate float
				if(@ccWhere<>'')
				BEGIN
					--Debit Amount	
					set @sql='SELECT @BalSysDate=isnull(sum(Amt),0) from (SELECT ISNULL(AMOUNT,0) Amt FROM ACC_DocDetails AD with(nolock)
							 JOIN Com_docCCData D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
						 where DebitAccount='+convert(nvarchar,@NodeID)+@ccWhere
						+' and DocDate<='+convert(nvarchar,convert(float,GETDATE()))+@AccWhere+'
						UNION ALL
						SELECT ISNULL(AMOUNT,0) Amt FROM ACC_DocDetails ID with(nolock)
						JOIN Com_docCCData D1 with(nolock) ON D1.AccDocDetailsID=ID.AccDocDetailsID
						 where DebitAccount='+convert(nvarchar,@NodeID)+@ccWhere
						+' and DocDate<='+convert(nvarchar,convert(float,GETDATE()))+@AccWhere+') as t '
					exec sp_executesql @sql,N'@BalSysDate float output',@BalSysDate output
					--Credit Amount	 
					set @sql='SELECT @BalSysDate=@BalSysDate-isnull(sum(Amt),0) from (SELECT ISNULL(AMOUNT,0) Amt FROM ACC_DocDetails AD with(nolock)
							 JOIN Com_docCCData D with(nolock) ON D.InvDocDetailsID=AD.InvDocDetailsID
						 where CreditAccount='+convert(nvarchar,@NodeID)+@ccWhere
						+' and DocDate<='+convert(nvarchar,convert(float,GETDATE()))+@AccWhere+'
						UNION ALL
						SELECT ISNULL(AMOUNT,0) Amt FROM ACC_DocDetails ID with(nolock)
						JOIN Com_docCCData D1 with(nolock) ON D1.AccDocDetailsID=ID.AccDocDetailsID
						 where CreditAccount='+convert(nvarchar,@NodeID)+@ccWhere
						+' and DocDate<='+convert(nvarchar,convert(float,GETDATE()))+@AccWhere+') as t '
					exec sp_executesql @sql,N'@BalSysDate float output',@BalSysDate output				
				
				END
				ELSE
				BEGIN
					--Debit Amount	
					set @sql='SELECT @BalSysDate=ISNULL((SELECT SUM(ISNULL(AMOUNT,0)) FROM ACC_DocDetails with(nolock) where DebitAccount='+convert(nvarchar,@NodeID)
					+' and DocDate<='+convert(nvarchar,convert(float,GETDATE()))+@AccWhere+'),0) '
					--Credit Amount	 
					set @sql=@sql+'-ISNULL((SELECT SUM(ISNULL(AMOUNT,0)) FROM ACC_DocDetails with(nolock) where CreditAccount='+convert(nvarchar,@NodeID)
					+' and DocDate<='+convert(nvarchar,convert(float,GETDATE()))+@AccWhere+'),0)'
					exec sp_executesql @sql,N'@BalSysDate float output',@BalSysDate output
				END
				SET @TEMPCOLUMN='CONVERT(FLOAT,'+CONVERT(NVARCHAR,round(@BalSysDate,@dec))+') AS '+ @COLUMN
			end	
			ELSE IF(@TEMPCOLUMN='Balance Credit')
			BEGIN				
				SET @TEMPCOLUMN='0 AS '+ @COLUMN
			END
			ELSE IF(@TEMPCOLUMN='Balance')
			BEGIN	
				declare @Bal float
			  SET @sql='set @Bal=isnull((select SUM(isnull(amount,0)) from ACC_DocDetails WITH(NOLOCK)  where DocDate < =' +convert(nvarchar,convert(float,@DocDate))+' and debitaccount='+convert(nvarchar,@NodeID)+'),0)
					   -isnull((select SUM(isnull(amount,0)) from ACC_DocDetails WITH(NOLOCK)  where DocDate < =' +convert(nvarchar,convert(float,@DocDate))+' and creditaccount='+convert(nvarchar,@NodeID)+'),0)'      
			  exec sp_executesql @sql,N'@Bal float output',@Bal output

				SET @TEMPCOLUMN='CONVERT(FLOAT,'+CONVERT(NVARCHAR,round(@Bal,@dec))+') AS '+ @COLUMN
			END			
			else if(@TEMPCOLUMN = 'AccountTypeID')
			begin
				set @Join=@Join+' JOIN ACC_AccountTypes AA WITH(NOLOCK) ON A.AccountTypeID=AA.AccountTypeID            
						JOIN COM_LanguageResources AT WITH(NOLOCK) ON AT.ResourceID=AA.ResourceID AND AT.LanguageID='+convert(NVARCHAR(10),@LangID)  
				
				set @TEMPCOLUMN='AT.ResourceData AS '+ @COLUMN
			end
			else if(@LinkFeatureID=2 and @TEMPCOLUMN='PaymentTerms')
			begin
				set @Join=@Join+' LEFT JOIN Acc_PaymentDiscountProfile APDP WITH(NOLOCK) ON APDP.ProfileID=a.'+@TEMPCOLUMN            
													
				set @TEMPCOLUMN='APDP.ProfileName AS '+ @COLUMN
			end
			else if(@TEMPCOLUMN = 'CreditLimit' OR @TEMPCOLUMN = 'DebitLimit' 
					OR @TEMPCOLUMN = 'CreditDays' OR @TEMPCOLUMN = 'DebitDays'
					OR @TEMPCOLUMN = 'CreditRemarks'OR @TEMPCOLUMN = 'DebitRemarks' )
			begin						
				IF(@COSTCENTERID =2 OR (@LocWise=1 AND @COSTCENTERID=50001) 
				OR (@DivWise=1 AND @COSTCENTERID=50002) OR (@DimWise>0 AND @COSTCENTERID=@DimWise) )
				BEGIN
					declare @dL NVARCHAR(MAX),@DimID INT
					select @lOCATION=ISNULL(NodeID,0) from @dims where CCID= 50002
					select @DIVIS=ISNULL(NodeID,0) from @dims where CCID= 50001
					IF(@DimWise>0)
						select @DimID=ISNULL(NodeID,0) from @dims where CCID=@DimWise
					
					IF(@LocWise=1 OR @DivWise=1 OR @DimWise>0)
					BEGIN
						SET @SQL='SELECT @dL='
						
						if(@TEMPCOLUMN = 'CreditLimit')
							SET @SQL=@SQL+'CreditAmount'
						if(@TEMPCOLUMN = 'DebitLimit')
							SET @SQL=@SQL+'DebitAmount'
						if(@TEMPCOLUMN = 'CreditDays')
							SET @SQL=@SQL+'CreditDays'
						if(@TEMPCOLUMN = 'DebitDays')
							SET @SQL=@SQL+'DebitDays'
						if(@TEMPCOLUMN = 'CreditRemarks')
							SET @SQL=@SQL+'CreditRemarks'
						if(@TEMPCOLUMN = 'DebitRemarks')
							SET @SQL=@SQL+'DebitRemarks'
						
						SET @SQL=@SQL+' FROM Acc_CreditDebitAmount WITH(NOLOCK) where'
						IF(@COSTCENTERID =2)
							SET @SQL=@SQL+' AccountID='+CONVERT(NVARCHAR,@NODEID)
						ELSE
							SET @SQL=@SQL+' AccountID='+CONVERT(NVARCHAR,@CreditAccount)
						if(@LocWise=1)
							SET @SQL=@SQL+' and LocationID='+CONVERT(NVARCHAR,@lOCATION)
						if(@DivWise=1)
							SET @SQL=@SQL+' and DivisionID='+CONVERT(NVARCHAR,@DIVIS)
						IF(@DimWise>0)
							SET @SQL=@SQL+' and DimensionID='+CONVERT(NVARCHAR,@DimID)
					
						EXEC SP_EXECUTESQL @SQL,N'@dL NVARCHAR(MAX) OUT',@dL OUT
						
						if(@TEMPCOLUMN = 'CreditLimit' OR @TEMPCOLUMN = 'DebitLimit' 
							OR @TEMPCOLUMN = 'CreditDays' OR @TEMPCOLUMN = 'DebitDays')
							SET @TEMPCOLUMN='CONVERT(FLOAT,'+isnull(@dL,0)+') AS '+ @COLUMN
						ELSE if(@TEMPCOLUMN = 'CreditRemarks'OR @TEMPCOLUMN = 'DebitRemarks' )
							SET @TEMPCOLUMN=''''+isnull(@dL,' ')+''' AS '+ @COLUMN
					END
					ELSE
					BEGIN					
						set @TEMPCOLUMN='a.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
					END	
				END
				ELSE
					set @TEMPCOLUMN='a.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
			end	
			else if(@TEMPCOLUMN like '%alpha%' and (@COSTCENTERID=2 or @COSTCENTERID=65 or @COSTCENTERID=3 or @COSTCENTERID=83))
			BEGIN
				select @FeatureID=CCID from  @TEMPLINKTABLE WHERE ID =  @I  			
				SELECT @FeatureTableName=TABLENAME FROM ADM_FEATURES WITH(NOLOCK)  WHERE FEATUREID =  @FeatureID
				
				if (@FeatureID=44)
				BEGIN
					if(@IsParent=1)
					BEGIN
						set @Join=@Join+' left join com_lookup l'+convert(nvarchar,@I)+' WITH(NOLOCK) on isnumeric(Pe.'+@TEMPCOLUMN+ ')=1 and l'+convert(nvarchar,@I)+'.NODEID=Pe.'+@TEMPCOLUMN

						set @TEMPCOLUMN='Pe.'+@TEMPCOLUMN+ ' AS '+ @COLUMN+',l'+convert(nvarchar,@I)+'.Name '+ @COLUMN+'name'	
					END	
					ELSE
					BEGIN
						set @Join=@Join+' left join com_lookup l'+convert(nvarchar,@I)+' WITH(NOLOCK) on isnumeric(e.'+@TEMPCOLUMN+ ')=1 and l'+convert(nvarchar,@I)+'.NODEID=e.'+@TEMPCOLUMN

						set @TEMPCOLUMN='e.'+@TEMPCOLUMN+ ' AS '+ @COLUMN+',l'+convert(nvarchar,@I)+'.Name '+ @COLUMN+'name'
					END
				END
				ELSE if(@FeatureID>50000)
				begin
					set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID=e.'+@TEMPCOLUMN
					
					set @TEMPCOLUMN='e.'+@TEMPCOLUMN+ 'AS '+ @COLUMN+',C'+CONVERT(nvarchar,@I)+'.Name'+ ' as '+@COLUMN+'Name'
				
				end
				ELSE if(@FeatureID=2)
				begin
					set @Join=@Join+' left join acc_Accounts C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.AccountID=e.'+@TEMPCOLUMN
					
					set @TEMPCOLUMN='e.'+@TEMPCOLUMN+ ' AS '+ @COLUMN+',C'+CONVERT(nvarchar,@I)+'.AccountName'+ ' as '+@COLUMN+'Name'				
				end
				ELSE
				BEGIN
					if(@IsParent=1)
						set @TEMPCOLUMN='Pe.'+@TEMPCOLUMN+ ' AS '+ @COLUMN	
					ELSE
						set @TEMPCOLUMN='e.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
				END
			END	
			Else If (@costcenterId=50051 and (select COUNT(*) from ADM_CostCenterDef where CostcenterId=@costcenterId and CostCenterColID=@linkData and ColumnDatatype ='DATE')>0)
			Begin
			 if(@IsParent=1)
				set @TEMPCOLUMN='pa.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
			ELSE 
				set @TEMPCOLUMN='Convert(Datetime,a.'+@TEMPCOLUMN+ ') AS '+ @COLUMN
			End
			Else If (@costcenterId=50051 and (@TEMPCOLUMN='BasicMonthly' OR @TEMPCOLUMN='NetSalary' OR @TEMPCOLUMN='AnnualCTC' OR @TEMPCOLUMN LIKE'Earning%' OR @TEMPCOLUMN LIKE'Deduction%'))
			BEGIN
				DECLARE @TEMPI INT
				SET @TEMPI=(SELECT TOP 1 ID FROM @TEMPLINKTABLE WHERE SYSCOLUMNNAME IN('BasicMonthly','NetSalary','AnnualCTC') OR SYSCOLUMNNAME LIKE'Earning%' OR SYSCOLUMNNAME LIKE'Deduction%' ORDER BY ID ASC)

				IF(@Join NOT LIKE'%Pay_EmpPay%')
				BEGIN
					set @Join=@Join+' left join Pay_EmpPay C'+CONVERT(nvarchar,@TEMPI)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@TEMPI)+'.EmployeeID'
					set @Join=@Join+'=a.NodeID AND C'+CONVERT(nvarchar,@TEMPI)+'.SeqNo IN (SELECT TOP 1 SeqNo FROM PAY_EMPPAY with(nolock) WHERE EmployeeID=C.NodeID ORDER BY EffectFrom DESC)'
				END

				set @TEMPCOLUMN='c'+CONVERT(nvarchar,@TEMPI)+'.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
			END			
			else 
			BEGIN 
				select @FeatureID=FCCID from  @TEMPLINKTABLE WHERE ID =  @I 
				
				IF @COSTCENTERID=61 AND @TEMPCOLUMN='Year'
					set @TEMPCOLUMN='a.StartYear,a.ENDYear,a.StartYear AS '+ @COLUMN
				ELSE if(@FeatureID=2 and (@TEMPCOLUMN like '%account%' or @TEMPCOLUMN like '%alpha%'))
				BEGIN
					set @Join=@Join+' LEFT JOIN ACC_Accounts a'+convert(nvarchar,@I)+' WITH(NOLOCK) ON a'+convert(nvarchar,@I)+'.AccountID=a.'+@TEMPCOLUMN            
														
					set @TEMPCOLUMN='a.'+@TEMPCOLUMN+ ' AS '+ @COLUMN+',a'+convert(nvarchar,@I)+'.AccountName '+' AS '+ @COLUMN+'name,a'+convert(nvarchar,@I)+'.AccountCode '+ ' AS '+ @COLUMN+'Code '
				END			
				ELSE
				BEGIN
					if exists(select CCID from  @TEMPLINKTABLE WHERE ID =  @I and CCID=44)
					BEGIN
						if(@IsParent=1)
						BEGIN
							set @Join=@Join+' left join com_lookup l'+convert(nvarchar,@I)+' WITH(NOLOCK) on isnumeric(Pa.'+@TEMPCOLUMN+ ')=1 and l'+convert(nvarchar,@I)+'.NODEID=Pa.'+@TEMPCOLUMN

							set @TEMPCOLUMN='Pa.'+@TEMPCOLUMN+ ' AS '+ @COLUMN+',l'+convert(nvarchar,@I)+'.Name '+ @COLUMN+'name'	
						END	
						ELSE
						BEGIN
							set @Join=@Join+' left join com_lookup l'+convert(nvarchar,@I)+' WITH(NOLOCK) on isnumeric(a.'+@TEMPCOLUMN+ ')=1 and l'+convert(nvarchar,@I)+'.NODEID=a.'+@TEMPCOLUMN

							set @TEMPCOLUMN='a.'+@TEMPCOLUMN+ ' AS '+ @COLUMN+',l'+convert(nvarchar,@I)+'.Name '+ @COLUMN+'name'
						END
					END
					ELSE
					BEGIN
						if(@IsParent=1)
							set @TEMPCOLUMN='pa.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
						ELSE
							set @TEMPCOLUMN='a.'+@TEMPCOLUMN+ ' AS '+ @COLUMN
					END		
				END	
			END
				
		end	
		else if(@COLUMN like 'ContactID')
		begin
			if(@COSTCENTERID=2)
			BEGIN
				set @Join=@Join+' left join com_contacts con WITH(NOLOCK) on con.FeaturePK=a.AccountID and con.FeatureID=2 and con.AddressTypeID=1 '
				set @TEMPCOLUMN='	con.ContactID AS '+ @COLUMN+' ,con.FirstName'+ ' as '+@COLUMN+'Name'
			END	
				
		END
		else if(@COLUMN like '%CCNID%')
		begin
				select @FeatureID=CCID from  @TEMPLINKTABLE WHERE ID =  @I  			
				SELECT @FeatureTableName=TABLENAME FROM ADM_FEATURES WITH(NOLOCK)  WHERE FEATUREID =  @FeatureID
				if(@FeatureID=50006 and @COSTCENTERID=3)
				begin
					set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID=a.CategoryID'
					
					set @TEMPCOLUMN='a.CategoryID AS '+ @COLUMN+' ,C'+CONVERT(nvarchar,@I)+'.IsGroup'+ ' as '+@COLUMN+'Group,C'+CONVERT(nvarchar,@I)+'.Name'+ ' as '+@COLUMN+'Name,C'+CONVERT(nvarchar,@I)+'.Code'+ ' as '+@COLUMN+'Code,C'+CONVERT(nvarchar,@I)+'.lft'+ ' as '+@COLUMN+'lft,C'+CONVERT(nvarchar,@I)+'.rgt'+ ' as '+@COLUMN+'rgt'
				
				end
				else
				begin
					select @IsParent=isnull(filterinuse,1),@dependancy=dependancy from @TEMPLINKTABLE where ID=@I
					
					if(@IsParent=0)
					BEGIN
						set @CID=0
						if(@dependancy=5)
							select @CID=isnull(max(NodeID),0),@CurrencyID=COUNT(NodeID) from COM_CostCenterCostCenterMap DCCM with(nolock) where DCCM.CostCenterID=@FeatureID
							and  DCCM.ParentCostCenterID=@COSTCENTERID and DCCM.ParentNodeID=@NODEID
						else
							select @CID=isnull(max(ParentNodeID),0),@CurrencyID=COUNT(ParentNodeID) from COM_CostCenterCostCenterMap DCCM with(nolock) where DCCM.ParentCostCenterID=@FeatureID
							and  DCCM.CostCenterID=@COSTCENTERID and DCCM.NodeID=@NODEID
						
                        if(@CurrencyID=1 and @CID>0)
                        BEGIN
							set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID='+convert(nvarchar,@CID)	
							set @TEMPCOLUMN= convert(nvarchar,@CID)+ ' AS '+ @COLUMN+' ,C'+CONVERT(nvarchar,@I)+'.IsGroup'+ ' as '+@COLUMN+'Group,C'+CONVERT(nvarchar,@I)+'.Name'+ ' as '+@COLUMN+'Name,C'+CONVERT(nvarchar,@I)+'.Code'+ ' as '+@COLUMN+'Code,C'+CONVERT(nvarchar,@I)+'.lft'+ ' as '+@COLUMN+'lft,C'+CONVERT(nvarchar,@I)+'.rgt'+ ' as '+@COLUMN+'rgt'
						END
						ELSE
						BEGIN
							set @TEMPCOLUMN= '0 AS '+ @COLUMN
						END	
					END
					ELSE
					BEGIN
						IF(@LinkFeatureID=110)
						BEGIN
							set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID=addr.'+REPLACE(@COLUMN,'DCCCNID','CCNID')						
							set @TEMPCOLUMN='addr.'+REPLACE(@COLUMN,'DCCCNID','CCNID')+ ' AS '+ @COLUMN+' ,C'+CONVERT(nvarchar,@I)+'.IsGroup'+ ' as '+@COLUMN+'Group,C'+CONVERT(nvarchar,@I)+'.Name'+ ' as '+@COLUMN+'Name,C'+CONVERT(nvarchar,@I)+'.Code'+ ' as '+@COLUMN+'Code,C'+CONVERT(nvarchar,@I)+'.lft'+ ' as '+@COLUMN+'lft,C'+CONVERT(nvarchar,@I)+'.rgt'+ ' as '+@COLUMN+'rgt'
						END
						ELSE
						BEGIN
							set @CID=0
					
							if(@isHist=1)
								select @CID=HistoryNodeID from COM_HistoryDetails with(nolock)
								where Costcenterid=@costcenteriD and NodeID=@NODEID and HistoryCCID=@FeatureID
								and fromdate<=@DocDate and (todate is null or todate>=@DocDate)
								order by fromdate
							
							if(@CID>0)
							BEGIN
								set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID='+convert(nvarchar(max),@CID)
								set @TEMPCOLUMN=convert(nvarchar(max),@CID)+ ' AS '+ @COLUMN
							END	
							ELSE
							BEGIN
								set @Join=@Join+' left join '+@FeatureTableName +' C'+CONVERT(nvarchar,@I)+' WITH(NOLOCK) on '+' C'+CONVERT(nvarchar,@I)+'.NODEID=c.'+REPLACE(@COLUMN,'DCCCNID','CCNID')						
								set @TEMPCOLUMN='c.'+REPLACE(@COLUMN,'DCCCNID','CCNID')+ ' AS '+ @COLUMN
							END	
							set @TEMPCOLUMN=@TEMPCOLUMN+' ,C'+CONVERT(nvarchar,@I)+'.IsGroup'+ ' as '+@COLUMN+'Group,C'+CONVERT(nvarchar,@I)+'.Name'+ ' as '+@COLUMN+'Name,C'+CONVERT(nvarchar,@I)+'.Code'+ ' as '+@COLUMN+'Code,C'+CONVERT(nvarchar,@I)+'.lft'+ ' as '+@COLUMN+'lft,C'+CONVERT(nvarchar,@I)+'.rgt'+ ' as '+@COLUMN+'rgt'
						END
					END	
				end
		end
		
		IF (@I = 1)
			SET @COLUMNS  = @TEMPCOLUMN 
		ELSE IF (@I > 1)
			SET @COLUMNS   =  @COLUMNS + ' , ' + @TEMPCOLUMN 
	SET @I = @I + 1 
 END  
 if(@COLUMNS is not null and @COLUMNS<>'')
 begin
	SET @QUERY = ' SELECT '+ ISNULL(@COLUMNS, '*') 
	if(@COSTCENTERID=2)
	begin
		set @QUERY=@QUERY+ ',a.CreditDays,a.CrOptionID,a.DebitDays,a.DrOptionID '
		
		if exists (select value from adm_globalpreferences with(nolock) where name='TCSVersion' and  value<>'')
        and exists (select CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterColID=@COSTCENTERCOlID and  SysColumnName='DebitAccount')
			EXEC spDOC_GetTCSData @DOCUMENTID,@NODEID,@DocDate,@ccxml,@QUERY OUTPUT

        if exists (select value from adm_globalpreferences with(nolock) where name='TDSVersion' and  value<>'')
        and exists (select CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterColID=@COSTCENTERCOlID and  SysColumnName='CreditAccount')
			EXEC spDOC_GetTDSData @DOCUMENTID,@NODEID,@DocDate,@ccxml,@QUERY OUTPUT
	end
	
	set @QUERY=@QUERY+' FROM '+ @TableName +' a with(NOLOCK)'
	
	if(@COSTCENTERID=2)
		set @QUERY=@QUERY+ ' join ACC_AccountsExtended e WITH(NOLOCK)  on a.AccountID=e.AccountID
					left	join COM_CCCCData c WITH(NOLOCK) on c.NodeID =a.AccountID and  c.CostCenterID=2'
	else if(@COSTCENTERID=3)
	BEGIN
		set @QUERY=@QUERY+ ' join INV_ProductExtended e WITH(NOLOCK)  on a.ProductID=e.ProductID
						join COM_CCCCData c WITH(NOLOCK) on c.NodeID =a.ProductID and  c.CostCenterID=3'
		if exists(select IsParent from @TEMPLINKTABLE where IsParent=1)
			set @QUERY=@QUERY+ ' LEFT join INV_Product pa WITH(NOLOCK)  on a.ParentID=pa.ProductID
						LEFT join INV_ProductExtended pe WITH(NOLOCK)  on pa.ProductID=pe.ProductID
						LEFT join COM_CCCCData pc WITH(NOLOCK) on pc.NodeID =pa.ProductID and  pc.CostCenterID=3'
						
    END						
	else if(@COSTCENTERID=83)
		set @QUERY=@QUERY+ ' join CRM_CustomerExtended e WITH(NOLOCK)  on a.CustomerID=e.CustomerID
						  join COM_CCCCData c WITH(NOLOCK) on c.NodeID =a.CustomerID and  c.CostCenterID=83'
	else if(@COSTCENTERID=65)
		set @QUERY=@QUERY+ ' join COM_ContactsExtended e WITH(NOLOCK)  on e.ContactID =a.ContactID join COM_CCCCData c WITH(NOLOCK)  on c.NodeID =a.ContactID and  c.CostCenterID=65'
	else if(@COSTCENTERID<>61)
		set @QUERY=@QUERY+ ' join COM_CCCCData c WITH(NOLOCK)  on c.NodeID =a.NODEID and  c.CostCenterID='+CONVERT(NVARCHAR(50),@COSTCENTERID)
	print @QUERY
	if(@DOCUMENTID=73)
	BEGIN
		set @QUERY=@QUERY+ ' left join COM_Address AS addr WITH(NOLOCK) on addr.addresstypeid=1 and addr.FEATUREID='+CONVERT(NVARCHAR,@COSTCENTERID)+' AND addr.FEATUREPK='+CONVERT(NVARCHAR,@NODEID)
		set @QUERY=@QUERY+ ' left join COM_Address AS bill WITH(NOLOCK) on bill.addresstypeid=2 and bill.FEATUREID='+CONVERT(NVARCHAR,@COSTCENTERID)+' AND bill.FEATUREPK='+CONVERT(NVARCHAR,@NODEID)
		set @QUERY=@QUERY+ ' left join COM_Address AS ship WITH(NOLOCK) on ship.addresstypeid=3 and ship.FEATUREID='+CONVERT(NVARCHAR,@COSTCENTERID)+' AND ship.FEATUREPK='+CONVERT(NVARCHAR,@NODEID)
	END
	else if(@COSTCENTERID<>61 and @COSTCENTERID<>3)
		set @QUERY=@QUERY+ ' left join COM_Address AS addr WITH(NOLOCK)  on addr.FEATUREID='+CONVERT(NVARCHAR,@COSTCENTERID)+' AND addr.FEATUREPK='+CONVERT(NVARCHAR,@NODEID)
	
	set @QUERY=@QUERY+' '+@Join+' WHERE a.'+ @ID +' = ' + CONVERT(NVARCHAR(50),@NODEID)
	
	if(@COSTCENTERID not in (61,3,73))
		set @QUERY=@QUERY+' order by addr.AddressTypeID '
 end
 else
 begin
	if(@COSTCENTERID=2)
		set @QUERY='select CreditDays,CrOptionID,DebitDays,DrOptionID  FROM acc_accounts a with(NOLOCK) WHERE a.accountid = ' + CONVERT(NVARCHAR(50),@NODEID)
	else
		set @QUERY='select 1 where 1=2'--NOT to return any row
 end
 print @QUERY
EXEC sp_executesql @QUERY

  	declare @DocumentType int,@isinventory bit,@Costcenters nvarchar(max),@II int,@CCNT int,@isinvexists bit
	select @DocumentType=DocumentType,@isinventory=isinventory from adm_documenttypes WITH(NOLOCK) where costcenterid=@DOCUMENTID

	if(@COSTCENTERID>50000)
	BEGIN
		set @CurrencyID=null
		set @QUERY='SELECT @CurrencyID=CurrencyID FROM '+@TableName+' WITH(NOLOCK) WHERE NodeID='+convert(nvarchar,@NODEID)
		exec sp_executesql @QUERY,N'@CurrencyID INT OUTPUT',@CurrencyID output
		
		IF @CurrencyID IS NOT NULL
		BEGIN
			set @lOCATION=1
			set @FeatureID=0
			select @FeatureID=isnull(value,0) from ADM_GlobalPreferences WITH(NOLOCK) 
			where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
			if(@FeatureID>0)
				select @lOCATION=NodeID from @dims where CCID=@FeatureID
			
			SELECT @CurrencyID CurrencyID
			EXEC [spDoc_GetCurrencyExchangeRate] @CurrencyID,@DocDate,@lOCATION,@LangID
			
		END
		else
		begin
			select 1 CurrencyID where 1=2
			select 1 Rate where 1=2
		end
		
		
		if(@isinventory=1 and exists(select prefvalue from [com_documentpreferences] WITH(NOLOCK) where costcenterid=@DOCUMENTID and prefname='defprod' and prefvalue=@COSTCENTERID))
		begin
			if(@COSTCENTERID =50006)
				set @QUERY='if(isnull((select count(a.ProductID) from INV_Product a WITH(NOLOCK)    
				WHERE a.IsGroup=0  AND  CategoryID='+convert(nvarchar,@NODEID)+' and  (a.StatusID<>32) ),0)=1)  
				select a.ProductID,a.ProductCode,a.ProductName from INV_Product a WITH(NOLOCK)    
				WHERE a.IsGroup=0  AND   CategoryID='+convert(nvarchar,@NODEID)+' and (a.StatusID<>32) ' 
			else  if(@COSTCENTERID =50004)
				set @QUERY='if(isnull((select count(a.ProductID) from INV_Product a WITH(NOLOCK)    
				WHERE a.IsGroup=0  AND  DepartmentID='+convert(nvarchar,@NODEID)+' and  (a.StatusID<>32) ),0)=1)  
				select a.ProductID,a.ProductCode,a.ProductName from INV_Product a WITH(NOLOCK)    
				WHERE a.IsGroup=0  AND   DepartmentID='+convert(nvarchar,@NODEID)+' and (a.StatusID<>32) ' 
			else
				set @QUERY='if(isnull((select count(a.ProductID) from INV_Product a WITH(NOLOCK)  
				WHERE a.IsGroup=0  AND 
				a.ProductID IN (select NodeID from COM_CCCCData where CostCenterID=3 and (CCNID'+convert(nvarchar,(@COSTCENTERID-50000))+'='+convert(nvarchar,@NODEID)+')) 
				and  (a.StatusID<>32) ),0)=1)
				select a.ProductID,a.ProductCode,a.ProductName from INV_Product a WITH(NOLOCK)  
				WHERE a.IsGroup=0  AND 
				a.ProductID IN (select NodeID from COM_CCCCData where CostCenterID=3 and (CCNID'+convert(nvarchar,(@COSTCENTERID-50000))+'='+convert(nvarchar,@NODEID)+')) 
				and  (a.StatusID<>32) '
			
			exec(@QUERY)
		END
	END
	ELSE
		SELECT * FROM COM_Address WITH(NOLOCK) 
		WHERE FEATUREID = 2 AND FEATUREPK =@NODEID  

--select * from COM_ADDRESS 
--WHERE FEATUREID=50002 AND FEATUREPK=@NODEID  
 
   if(@COSTCENTERID =2)
	BEGIN
		set @CurrencyID=null
		SELECT @CurrencyID=Currency FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=@NODEID
		
		IF @CurrencyID IS NOT NULL
		BEGIN
			set @lOCATION=1
			set @FeatureID=0
			select @FeatureID=isnull(value,0) from ADM_GlobalPreferences WITH(NOLOCK) 
			where Name='DimensionwiseCurrency' and ISNUMERIC(value)=1 and CONVERT(INT,value)>50000
			if(@FeatureID>0)
				select @lOCATION=NodeID from @dims where CCID=@FeatureID
			
			SELECT @CurrencyID CurrencyID
			EXEC [spDoc_GetCurrencyExchangeRate] @CurrencyID,@DocDate,@lOCATION,@LangID
			
		END
		else
		begin
			select 1 CurrencyID where 1=2
			select 1 Rate where 1=2
		end
		select * from ACC_ChequeBooks WITH(NOLOCK)  
		where BankAccountID=@NODEID and convert(INT,CurrentNo)<=convert(INT,EndNo) and Status=1
		
		SELECT * FROM  COM_Files WITH(NOLOCK) 
		WHERE FeatureID=2 and  FeaturePK=@NODEID

	end
	
	if((@isinventory=1 and @COSTCENTERID =3) or (@isinventory=0 and @COSTCENTERID =2))
	begin
		declare @LastValue TABLE(ID INT IDENTITY(1,1),SYSCOLUMNNAME NVARCHAR(100),COLUMNxml NVARCHAR(max),LinkData INT)
		
		
		INSERT INTO @LastValue 
		SELECT C.SYSCOLUMNNAME,lastvalueVouchers,LinkData
		FROM ADM_COSTCENTERDEF C WITH(NOLOCK) 		  
		WHERE C.CostCenterID = @DOCUMENTID and LocalReference=79 and LinkData in (26585,53529,53530,53589,54306,54307) 
		and lastvalueVouchers is not null and lastvalueVouchers like '%XML%' 
		and C.SYSCOLUMNNAME not like 'dcCalcNum%' and C.SYSCOLUMNNAME not like 'dcCurrID%' and C.SYSCOLUMNNAME not like 'dcExchRT%'
		
		SELECT @COLUMNCNT = COUNT(ID)  FROM @LastValue
		SET @I = 0
		WHILE (@I<@COLUMNCNT)
		BEGIN 
			set @I=@I+1
			SELECT @COLUMN = SYSCOLUMNNAME,@xml = COLUMNxml,@LinkData=LinkData FROM @LastValue WHERE ID =  @I  			
			
			Declare @includeProductWhere bit
			declare @LastValueColumns TABLE(ID INT IDENTITY(1,1),SYSCOLUMNNAME NVARCHAR(100),CCID int)
			delete from @LastValueColumns
			
			insert into @LastValueColumns
			SELECT X.value('@SysColumnName','nvarchar(100)'),X.value('@CostCenterID','int')  
			from @XML.nodes('/XML/Row') as Data(X) 
			where X.value('@CostCenterID','int') in(select costcenterid from adm_documenttypes WITH(NOLOCK) where isinventory=1)
			
			set @Costcenters='' 
			set @Where='' 
			if(@LinkData=53530 or @LinkData=53589)
				set @includeProductWhere=0
			else
				set @includeProductWhere=1
				
			set @QUERY='declare @val nvarchar(max) select @val=case'
			if(@LinkData=53530)		
			set @QUERY='declare @val FLOAT select @val=sum(val) from (select case'
			
			SELECT @II =min(ID) ,@CCNT = max(ID)  FROM @LastValueColumns			
			WHILE (@II<=@CCNT)
			BEGIN 
				select @TEMPCOLUMN=SYSCOLUMNNAME,@FeatureID=CCID from @LastValueColumns where ID=@II
				if(@TEMPCOLUMN like 'dcccnid%' or @TEMPCOLUMN ='ContactID')
				BEGIN
					
					select @CID=ColumnCostcenterid from adm_costcenterdef WITH(NOLOCK) 
					where SYSCOLUMNNAME=@TEMPCOLUMN and costcenterid=@FeatureID
										
					set @Where=@Where+' and '+@TEMPCOLUMN+'='+convert(nvarchar,isnull((select TOP 1 NodeID from @dims where CCID= @CID),0))
					
				END
				ELSE if(@TEMPCOLUMN ='DebitAccount' or @TEMPCOLUMN ='CreditAccount')
				BEGIN
					if((@TEMPCOLUMN ='CreditAccount' and (@DocumentType=1 or @DocumentType=27 or @DocumentType=26 or @DocumentType=25 or @DocumentType=2  or @DocumentType=34 or @DocumentType=6 or @DocumentType=3 or @DocumentType=4 or @DocumentType=13))
					or (@TEMPCOLUMN ='DebitAccount' and not (@DocumentType=1 or @DocumentType=27 or @DocumentType=26 or @DocumentType=25 or @DocumentType=2  or @DocumentType=34 or @DocumentType=6 or @DocumentType=3 or @DocumentType=4 or @DocumentType=13)) )  
						set @Where=@Where+' and  '+@TEMPCOLUMN+'='+convert(nvarchar,@CreditAccount)
				END
				ELSE if(@TEMPCOLUMN ='ProductID')
				BEGIN
					set @includeProductWhere=1
				END
				ELSE
				BEGIN
					 set @QUERY=@QUERY+' when costcenterid='+convert(nvarchar,@FeatureID)+' then '
					 if(@LinkData=54306)
					 BEGIN
					 	 if(@TEMPCOLUMN in ('BillDate','DocDate','DueDate'))
							set @QUERY=@QUERY+'convert(nvarchar,convert(datetime,min('+@TEMPCOLUMN+')))'
						 else
							set @QUERY=@QUERY+'min('+@TEMPCOLUMN+')'

					 END
					 ELSE  if(@LinkData=54307)
					 BEGIN
							if(@TEMPCOLUMN in ('BillDate','DocDate','DueDate'))
							set @QUERY=@QUERY+'convert(nvarchar,convert(datetime,max('+@TEMPCOLUMN+')))'
						 else
							set @QUERY=@QUERY+'max('+@TEMPCOLUMN+')'
					 END
					 ELSE
					 BEGIN
						
						if(@TEMPCOLUMN in ('CurrencyID'))
							set @QUERY=@QUERY+'(select Name from COM_Currency tmp WITH(NOLOCK) where tmp.CurrencyID=a.CurrencyID)'
						 else if(@TEMPCOLUMN in ('BillDate','DocDate','DueDate'))
							set @QUERY=@QUERY+'convert(nvarchar,convert(datetime,'+@TEMPCOLUMN+'))'
						 else
							set @QUERY=@QUERY+@TEMPCOLUMN 	
					 END	
					 set @Costcenters=@Costcenters+convert(nvarchar,@FeatureID)+','
				END
				set @II=@II+1			
			 end
			 
			
			if exists(select  ID FROM @LastValueColumns where SYSCOLUMNNAME not in('ProductID','ContactID') and SYSCOLUMNNAME not like 'dcccnid%')
			BEGIN
				set @isinvexists=1
				
				set @QUERY=@QUERY+' end '
				if(@LinkData=53530)			
					set @QUERY=@QUERY+' as val'
				set @QUERY=@QUERY+' from INV_DocDetails a WITH(NOLOCK) 
				join COM_DocNumData b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid 
				join COM_DocCCData c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid 
				join COM_DocTextData d WITH(NOLOCK) on a.invdocdetailsid=d.invdocdetailsid'	
				 
				set @QUERY=@QUERY+	' where DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))+' and statusid=369 and CostCenterID in ('+substring(@Costcenters,0,len(@Costcenters))+')'
				if(@includeProductWhere=1)
					set @QUERY=@QUERY+' and ProductID='+convert(nvarchar,@NODEID)
				if(@CreditAccount <>0 and (@LinkData=26585 or @LinkData=54306 or @LinkData=54307))
				begin
					if(@DocumentType=1 or @DocumentType=27 or @DocumentType=26 or @DocumentType=25 or @DocumentType=2  or @DocumentType=34 or @DocumentType=6 or @DocumentType=3 or @DocumentType=4 or @DocumentType=13)    
						set @QUERY=@QUERY+' and  CreditAccount='+convert(nvarchar,@CreditAccount)
					else
						set @QUERY=@QUERY+' and DebitAccount='+convert(nvarchar,@CreditAccount)
				end				
			
				set @QUERY=@QUERY+@Where
			END
			ELSE
				set @isinvexists=0
			
			
			
			if(@LinkData=53530)	
			BEGIN		
				Declare @JVCC nvarchar(max)
				delete from @LastValueColumns
				insert into @LastValueColumns
				SELECT X.value('@SysColumnName','nvarchar(100)'),X.value('@CostCenterID','int')  
				from @XML.nodes('/XML/Row') as Data(X) 
				where X.value('@CostCenterID','int') in(select costcenterid from adm_documenttypes WITH(NOLOCK)  where isinventory=0)
				set @Costcenters='' 
				set @JVCC='' 
				if exists(select SYSCOLUMNNAME from @LastValueColumns)
				BEGIN
					if(@isinvexists=1)
						set @QUERY=@QUERY+' UNIOn ALL select case	'
						
					SELECT @II =min(ID) ,@CCNT = max(ID)  FROM @LastValueColumns			
					WHILE (@II<=@CCNT)
					BEGIN 
						select @TEMPCOLUMN=SYSCOLUMNNAME,@FeatureID=CCID from @LastValueColumns where ID=@II
						if(@TEMPCOLUMN like 'dcccnid%' or @TEMPCOLUMN ='ContactID')
						BEGIN
							
							select @CID=ColumnCostcenterid from adm_costcenterdef WITH(NOLOCK) 
							where SYSCOLUMNNAME=@TEMPCOLUMN and costcenterid=@FeatureID
												
							set @Where=@Where+' and '+@TEMPCOLUMN+'='+convert(nvarchar,isnull((select TOP 1 NodeID from @dims where CCID= @CID),0))
							
						END
						ELSE
						BEGIN
							 set @QUERY=@QUERY+' when costcenterid='+convert(nvarchar,@FeatureID)+' then '
							 if(@TEMPCOLUMN in ('DebitAmount','CreditAmount'))
							 BEGIN
						 		set @QUERY=@QUERY+' AMOUNT '
						 		set @JVCC=@JVCC+convert(nvarchar,@FeatureID)+','
							 END	
							 else
							 BEGIN
								set @QUERY=@QUERY+@TEMPCOLUMN 	
								set @Costcenters=@Costcenters+convert(nvarchar,@FeatureID)+','
							 END
						END
							 	
						set @II=@II+1	
					END
					set @QUERY=@QUERY+' end  as val '
					
					set @QUERY=@QUERY+' from ACC_DocDetails a WITH(NOLOCK)
					join COM_DocNumData b WITH(NOLOCK) on a.Accdocdetailsid=b.Accdocdetailsid 
					join COM_DocCCData c WITH(NOLOCK) on a.Accdocdetailsid=c.Accdocdetailsid 
					join COM_DocTextData d WITH(NOLOCK) on a.Accdocdetailsid=d.Accdocdetailsid'	
					 
					set @QUERY=@QUERY+	' where DocDate<='+convert(nvarchar,CONVERT(float,@DocDate))+'  and statusid=369 and '
					
					if(@Costcenters<>'')
						set @QUERY=@QUERY+	' (CostCenterID in ('+substring(@Costcenters,0,len(@Costcenters))+')'
					if(@JVCC<>'')
					BEGIN
						if(@Costcenters<>'')
							set @QUERY=@QUERY+	' or '
						set @QUERY=@QUERY+	' (CostCenterID in ('+substring(@JVCC,0,len(@JVCC))+') and CreditAccount<0)'
					END	
					if(@Costcenters<>'')
						set @QUERY=@QUERY+')'	
						
					set @QUERY=@QUERY+@Where					
				END	
				set @QUERY=@QUERY+') as t select isnull(@val,0) as '+@COLUMN
			END	
			ELSE IF(@LinkData=54306 or @LinkData=54307)
				 set @QUERY=@QUERY+' Group by CostCenterID  select @val as '+@COLUMN
			else
				 set @QUERY=@QUERY+' order by DocDate  select @val as '+@COLUMN
			   print @QUERY
		 	exec(@QUERY)
			
		end
	end

	
	if(@DocumentLinkDefID>0)
		exec spDOC_GetLinkDetails @DocumentLinkDefID,@LocationID,@DivisionID,@DocDate,
		@DueDate,@DocID,@DbAcc,@CrAcc,@DimWhere,@UserID,@LangID,@RoleID

	
	if(@ProfileExists=1)
	BEGIN
		declare @ProfileCC nvarchar(max),@PXML XML,@K INT,@CNT INT,@profileid NVARCHAR(MAX)

		set @ProfileCC=''
		SelecT @ProfileCC=prefvalue from com_documentpreferences WITH(NOLOCK) where Costcenterid=@DOCUMENTID and prefname='DefaultProfileID'
		
		declare @Profiletable table(ID INT IDENTITY(1,1),wef datetime,tilldate datetime,profileid NVARCHAR(50)) 
		set @PXML=@ProfileCC
		
		INSERT INTO @Profiletable      
		SELECT     
			X.value('@WEFDate','DateTime')       
			,X.value('@TillDate','DateTime')
			,X.value('@ProfileID','INT')
		from @PXML.nodes('/DimensionDefProfile/Row') as Data(X) 
		
		SET @K=1
		SELECT  @CNT=COUNT(*) FROM @Profiletable
		WHILE (@K<=@CNT)
		BEGIN
				IF(ISNULL(@IncludeCC,'')='')
					SELECT  @IncludeCC=profileid FROM @Profiletable WHERE ID=@K AND ((CONVERT(DATETIME,@DocDate) BETWEEN CONVERT(DATETIME,WEF) AND CONVERT(DATETIME,tilldate)) OR ISNULL(WEF,'')='')
				ELSE
					SELECT  @IncludeCC=@IncludeCC+','+profileid FROM @Profiletable WHERE ID=@K AND ((CONVERT(DATETIME,@DocDate) BETWEEN CONVERT(DATETIME,WEF) AND CONVERT(DATETIME,tilldate)) OR ISNULL(WEF,'')='')
		SET @K=@K+1
		END
		--Remove Duplicate Datar
		CREATE TABLE #PDATA (ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT,PrefValue NVARCHAR(MAX))
		INSERT INTO #PDATA
			SELECT CostCenterID,PrefValue FROM COM_DocumentPreferences P WITH(NOLOCK) 
			WHERE P.PrefName='DefaultProfileID' and P.PrefValue!=''
		UPDATE #PDATA SET PrefValue=REPLACE(REPLACE(PrefValue,'<DimensionDefProfile>',''),'</DimensionDefProfile>','')
		UPDATE #PDATA SET PrefValue='<DimensionDefProfile>'+PrefValue+'</DimensionDefProfile>' 

		select * from #PDATA
		drop table #PDATA

		delete from @cctable

		insert into @cctable  
		exec SPSplitString @IncludeCC,','  
		
		SELECT @I=min(ID),@COLUMNCNT = max(ID)  FROM @cctable
 
		WHILE (@I<=@COLUMNCNT )
		BEGIN 
				SELECT @FeatureID = CCID FROM @cctable WHERE ID =  @I  			
				set @I=@I+1
				
				SelecT @XML=defxml from COM_DimensionMappings WITH(NOLOCK)
				where ProfileID=@FeatureID
				SET @Where=''
				SET @Join=''
				
				set @QUERY='select ProfileID'
				SELECT @QUERY=@QUERY+case when X.value('@cols','int')=2 THEN ' ,AccountID,CC2.AccountName'
				when X.value('@cols','int')=3 THEN ' , ProductID,CC3.ProductName'
				ELSE  ' , CCNID'+convert(nvarchar,X.value('@cols','int')-50000)+',CC'+convert(nvarchar,X.value('@cols','int')-50000)+'.Name' END
				FROM @XML.nodes('/XML/Row') as Data(X)
				where X.value('@IsBase','int')=0

				SELECT @Where=@Where+case when X.value('@cols','int')=2 THEN ' and AccountID='+isnull(CONVERT(nvarchar,@CreditAccount),'0')
				when X.value('@cols','int')=3 THEN ' and ProductID='+isnull(CONVERT(nvarchar,isnull(NodeId,@NODEID)),'0')
				ELSE  ' and CCNID'+convert(nvarchar,X.value('@cols','int')-50000)+'='+isnull(CONVERT(nvarchar,NodeId),0) END
				FROM @XML.nodes('/XML/Row') as Data(X)
				left join @dims a on X.value('@cols','int')=a.ccid
				where X.value('@IsBase','int')=1

				SELECT @Join=@Join+case when X.value('@cols','int')=2 THEN ' left join Acc_Accounts CC2 WITH(NOLOCK)  on CC2.AccountID=a.AccountID '
				when X.value('@cols','int')=3 THEN ' left join Inv_product CC3 WITH(NOLOCK)  on CC3.ProductID=a.ProductID '
				ELSE  ' left join '+(select tablename from adm_features where featureid=X.value('@cols','int'))+' CC'+convert(nvarchar,X.value('@cols','int')-50000)+' WITH(NOLOCK)  on CC'+convert(nvarchar,X.value('@cols','int')-50000)+'.NodeID=a.CCNID'+convert(nvarchar,X.value('@cols','int')-50000) END
				FROM @XML.nodes('/XML/Row') as Data(X)
				where X.value('@IsBase','int')=0
				set @QUERY=@QUERY+' from COM_DimensionMappings a WITH(NOLOCK) '+@Join+' where ProfileID='+convert(nvarchar,@FeatureID)+@Where
				EXEC sp_executesql @QUERY
				print @QUERY
		END				
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName,
		ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
