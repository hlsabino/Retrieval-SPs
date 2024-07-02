USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetUnApprovedDocuments]
	@Location [nvarchar](max),
	@StatusID [int],
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY        
SET NOCOUNT ON;          
       
	DECLARE @SQL NVARCHAR(MAX),@LocWhere NVARCHAR(MAX),@INVJOIN NVARCHAR(MAX),@ACCJOIN NVARCHAR(MAX),@Dimensions nvarchar(max),@JOIN nvarchar(max),@WHERE nvarchar(max)
	CREATE TABLE #TblUserDims(ID int IDENTITY(1,1),Dimension INT)
	
	set @JOIN=''
	
	if(@UserID!=1 and @RoleID!=1)
	begin
		set @Dimensions=(select value from ADM_GlobalPreferences with(nolock) where name='Dimension List')
		if(@Dimensions is not null and @Dimensions!='')
		begin
			insert into #TblUserDims
			exec SPSplitString @Dimensions,','
			set @Dimensions=''
			select @Dimensions=@Dimensions+' INNER JOIN COM_CostCenterCostCenterMap CCMU'+convert(nvarchar,ID)+' with(nolock) on DocCC.dcCCNID'+convert(nvarchar,(Dimension-50000))+'=CCMU'+convert(nvarchar,ID)+'.NodeID and CCMU'+convert(nvarchar,ID)+'.ParentCostCenterID=7 and CCMU'+convert(nvarchar,ID)+'.CostCenterID='+convert(nvarchar,Dimension)+' and CCMU'+convert(nvarchar,ID)+'.ParentNodeID='+convert(nvarchar,@UserID)
			from #TblUserDims WITH(NOLOCK)
			where Dimension>50000
		end
	end
	
	if @Dimensions is null
		set @Dimensions=''
		
	declare @DBCustomize nvarchar(max),@XML xml,@DIMCOLS NVARCHAR(MAX),@DIMCOLSJOIN NVARCHAR(MAX),@i int,@CNT nvarchar(max)
	set @DIMCOLS=''
	set @DIMCOLSJOIN=''
	select @DBCustomize=Value from adm_globalPreferences with(nolock) where Name='Un Approved Documents_DashBoardCustomize'
	if(@DBCustomize is not null and @DBCustomize!='')
	begin
		set @XML=@DBCustomize
		declare @Tbl as Table(ID int identity(1,1),ActCol nvarchar(50),Col nvarchar(50),FID int,TableName nvarchar(50))
		insert into @Tbl(ActCol,Col,FID)
		SELECT distinct X.value('@ID','nvarchar(50)'),substring(X.value('@ID','nvarchar(50)'),5,4),substring(X.value('@ID','nvarchar(50)'),10,50)
		FROM @XML.nodes('/XML/Row') as Data(X)
		WHERE X.value('@ID','nvarchar(50)') like 'DIM_%'
		
		if exists(select ID FROM @Tbl)
		begin
			update @Tbl
			set TableName=F.TableName 
			from @Tbl T
			inner join adm_features F with(nolock) on T.FID=F.FeatureID
			
			select @i=1,@Cnt=count(*) from @Tbl
			while(@i<=@Cnt)
			begin
				select @DIMCOLS=@DIMCOLS+',max(DIM'+convert(nvarchar,ID)+'.'+Col+') '+ActCol
				from @Tbl WHERE ID=@i
				
				--if not exists (select ID FROM @Tbl WHERE ID<@i and FID=(select FID FROM @Tbl where ID=@I))
				select @DIMCOLSJOIN=@DIMCOLSJOIN+' LEFT JOIN '+TableName+' DIM'+convert(nvarchar,ID)+' with(nolock) ON DIM'+convert(nvarchar,ID)+'.NodeID=DocCC.dcCCNID'+convert(nvarchar,(FID-50000))
				from @Tbl WHERE ID=@i
				
				set @i=@i+1
			end
		end
--		select @DIMCOLS,@DIMCOLSJOIN
	end
	
	IF(@Location IS NOT NULL AND @Location <>'' AND @Location <> '0')    
		SET @LocWhere=' and DocCC.dcCCNID2 in (' + @Location +') '
	ELSE
		SET @LocWhere=''
	
	if @LocWhere!='' OR @Dimensions!='' OR @DIMCOLSJOIN!=''
	BEGIN    
		SET @INVJOIN=' INNER JOIN COM_DocCCData DocCC with(nolock) ON DocCC.InvDocDetailsID=I.InvDocDetailsID'+@Dimensions
		SET @ACCJOIN=' INNER JOIN COM_DocCCData DocCC with(nolock) ON DocCC.AccDocDetailsID=I.AccDocDetailsID'+@Dimensions
	END
	ELSE
	BEGIN
		SET @INVJOIN=''
		SET @ACCJOIN=''
	END
	

	if(@StatusID=371)-- and (@UserID!=1 and @RoleID!=1)
	begin
		set @WHERE='I.StatusID=371'
		--set @WHERE='I.StatusID=371 and I.CreatedBy='''+(SELECT UserName FROM ADM_Users with(nolock) WHERE USERID=@UserID)+''''
		--set @WHERE='(I.StatusID=371 or I.StatusID=441)'
		--set @WHERE=@WHERE+' and dbo.[fnRPT_CanApprove](I.WorkflowID,I.WorkFlowLevel,I.StatusID,I.CreatedDate,'+convert(nvarchar,@UserID)+','+convert(nvarchar,@RoleID)+')=1'
	end
	else
	begin
		set @WHERE='I.StatusID='+convert(nvarchar,@StatusID)
	end
   
   SET @SQL =  'declare @Tbl AS TABLE(featureid INT)
INSERT INTO @Tbl
select featureid from adm_featureaction with(nolock) 
where featureactionid in (select FeatureActionID from adm_featureactionrolemap with(nolock) where RoleID='+Convert(nvarchar,@RoleID)+') 
group by featureid
having (featureid>40000 and featureid<50000) or featureid=95

delete from @Tbl where featureid IN (select convert(int,PrefValue) from com_documentpreferences with(nolock) where PrefName=''PDCDocument'' and PrefValue is not null and PrefValue!='''' and isnumeric(PrefValue)=1)

SELECT I.DocID,I.ModifiedBy,I.CostCenterID,I.VoucherNo,CONVERT(DATETIME,I.DocDate) DocDate,D.DocumentName,I.DocPrefix,I.DocNumber    
,ACC.accountName BankAccountID,acd.accountname AccountID ,sum(StockValue) Amount, I.CreatedBy,  isnull(CONVERT(DATETIME,I.ModifiedDate),I.CreatedDate) ModifiedDate
 , D.IsInventory'+@DIMCOLS+'
FROM INV_DocDetails I with(nolock)
INNER JOIN ADM_DocumentTypes D with(nolock) ON I.CostCenterID=D.CostCenterID  
INNER JOIN ACC_ACCOUNTS ACC with(nolock) ON ACC.ACCOUNTID=I.CreditAccount
INNER JOIN ACC_ACCOUNTS ACD with(nolock) ON ACD.ACCOUNTID=I.DebitAccount '+@INVJOIN+@JOIN+@DIMCOLSJOIN+'
WHERE '+@WHERE+' AND I.REFCCID<>95 and d.CostCenterid in (select featureid from @Tbl)'
+@LocWhere+' GROUP BY I.DocDate,I.VoucherNo,D.DocumentName,I.DocPrefix,I.DocNumber,I.DocID,I.ModifiedBy,I.CostCenterID,ACC.accountName,acd.accountName,I.ModifiedDate , I.CreatedDate, I.CreatedBy, D.IsInventory'

 SET @SQL = @SQL  + '
	UNION
SELECT I.DocID,I.ModifiedBy,I.CostCenterID,I.VoucherNo,CONVERT(DATETIME,I.DocDate) DocDate,D.DocumentName,I.DocPrefix,I.DocNumber
,ACC.AccountName BankAccountID,ACD.AccountName AccountID,I.Amount, I.CreatedBy,    isnull(CONVERT(DATETIME,I.ModifiedDate), I.CreatedDate) ModifiedDate
, D.IsInventory'+@DIMCOLS+'
FROM ACC_DocDetails I with(nolock)
INNER JOIN ADM_DocumentTypes D with(nolock) ON D.IsInventory=0 AND I.CostCenterID=D.CostCenterID '+@ACCJOIN+'
INNER JOIN ACC_ACCOUNTS ACC with(nolock) ON ACC.ACCOUNTID=I.CreditAccount
INNER JOIN ACC_ACCOUNTS ACD with(nolock) ON ACD.ACCOUNTID=I.DebitAccount'+@JOIN+@DIMCOLSJOIN+'
WHERE '+@WHERE+' AND I.REFCCID<>95 and d.CostCenterid in (select featureid from @Tbl)'
+@LocWhere+' GROUP BY I.DocDate,I.VoucherNo,D.DocumentName,I.DocPrefix,I.DocNumber,I.DocID,I.ModifiedBy,I.CostCenterID,ACC.AccountName,ACD.AccountName,I.Amount ,I.ModifiedDate , I.CreatedDate, I.CreatedBy, D.IsInventory'


IF (select count(*) from ACC_DocDetails with(nolock) WHERE REFCCID=95)>1
BEGIN
	 SET @SQL = @SQL  + '
		UNION
	SELECT CONTRCT.CONTRACTID DocID,max(CONTRCT.ModifiedBy) ModifiedBy, 95 CostCenterID,CONVERT(NVARCHAR,ISNULL(CONTRCT.SNO,0))   
	,CONVERT(DATETIME, CONTRCT.ContractDate) DocDate,''Sales Contract'' DocumentName,CONTRCT.CONTRACTPREFIX DocPrefix,CONVERT(NVARCHAR,CONTRACTNUMBER) DocNumber      
	,max(ACC.AccountName) BankAccountID,min(ACD.AccountName) AccountID,max(CONTRCT.TotalAmount) Amount, max(CONTRCT.CreatedBy) CreatedBy
	,isnull(CONVERT(DATETIME,max(I.ModifiedDate)),max(I.CreatedDate)) ModifiedDate, D.IsInventory'+@DIMCOLS+'
	FROM ACC_DocDetails I with(nolock)
	INNER JOIN ADM_DocumentTypes D with(nolock) ON I.CostCenterID=D.CostCenterID      
	INNER JOIN REN_CONTRACT CONTRCT with(nolock) ON CONTRCT.CONTRACTID=I.REFNODEID 
	INNER JOIN ACC_ACCOUNTS ACC with(nolock) ON ACC.ACCOUNTID=I.CreditAccount
	INNER JOIN ACC_ACCOUNTS ACD with(nolock) ON ACD.ACCOUNTID=I.DebitAccount '+@ACCJOIN+@JOIN+@DIMCOLSJOIN+'  
	WHERE '+@WHERE+' AND I.REFCCID=95 and d.CostCenterid in (select featureid from @Tbl)'
	+@LocWhere+' GROUP BY CONTRCT.ContractDate,CONTRCT.SNO,CONTRCT.CONTRACTPREFIX,CONVERT(NVARCHAR,CONTRACTNUMBER),CONTRCT.CONTRACTID, I.CreatedBy , D.IsInventory'     
END

  print(@SQL)
 
EXEC(@SQL)    
      
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
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine        
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
  END        
 SET NOCOUNT OFF          
 RETURN -999           
END CATCH
GO
