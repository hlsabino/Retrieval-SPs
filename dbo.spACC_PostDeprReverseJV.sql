USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_PostDeprReverseJV]
	@PostCOSTCENTERID [int],
	@DeprVoucherNo [nvarchar](50),
	@DeptID [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100)    
BEGIN TRY        
SET NOCOUNT ON;
DECLARE   @XML XML ,@DXML XML , @CNT INT , @ICNT INT , @DocXml nvarchar(max) , @return_value INT ,@DT datetime,@DT_INT INT,@Vendor INT,@PN nvarchar(50)
DECLARE @DEPID INT ,@VOUCHERNO NVARCHAR(200) ,@DocDate float ,@STATUSID INT  , @AssetNetValue FLOAT,@AssetOldValue Float
DECLARE @AssetID INT ,@Prefix nvarchar(200),@DeprPostDate nvarchar(50),@CCQUERY nvarchar(max)
declare @DepAmount float,@LocationDimID INT,@AssDimNodeID INT,@AssDimID INT,@LocationID INT
declare @TblDepr as table(ID int identity(1,1),DeprID INT,AssetID INT)
declare @dbl float,@dblCum float,@DeprStartDate int,@DeprEndDate int,@IsPartial bit,@DOCID INT,@COSTCENTERID INT,@Decimals int
declare @SqlCC nvarchar(max)    
select @Decimals=Value from ADM_GlobalPreferences with(nolock) where Name='DecimalsinAmount'

SELECT @AssetID=ISNULL(RefNodeID,0) FROM ACC_DocDetails WITH(NOLOCK) WHERE VoucherNo=@DeprVoucherNo AND RefCCID=72
SELECT @AssetNetValue = AssetNetValue,@DepAmount=DepAmount FROM ACC_AssetDepSchedule with(nolock) WHERE AssetID = @AssetID and DocID IS NOT NULL

insert into @TblDepr(DeprID)
execute SPSplitString @DeptID,','

delete T
from ACC_AssetDepSchedule A with(nolock) 
inner join @TblDepr T ON A.DPScheduleID=T.DeprID
where DocID is null and DocID=0

update T
set T.AssetID=A.AssetID
from @TblDepr T  
inner join ACC_AssetDepSchedule A with(nolock) on A.DPScheduleID=T.DeprID

--Check for next months depreciation exists
if exists (select P.DPScheduleID--,convert(datetime,P.DeprStartDate),P.DPScheduleID,P.DocID,A.* 
	from @TblDepr T
	inner join ACC_AssetDepSchedule A with(nolock) on A.DPScheduleID=T.DeprID
	inner join ACC_AssetDepSchedule P with(nolock) on P.AssetID=A.AssetID and P.DeprStartDate>A.DeprStartDate
	LEFT join @TblDepr TP on TP.DeprID=P.DPScheduleID 
where TP.DeprID is null and (P.DocID is not null and P.DocID!=''))
begin
	RAISERROR('-151',16,1)
end

--Check for partial depreciation exists
set @IsPartial=0
if exists (select A.DPScheduleID from ACC_AssetDepSchedule A with(nolock)
	left join @TblDepr T on A.DPScheduleID=T.DeprID
	where A.VoucherNo=@DeprVoucherNo and T.DeprID is null)
begin
	set @IsPartial=1
end

Set @DT=getdate()   
set @DT_INT=floor(convert(float,@DT))

select @COSTCENTERID=CostCenterID,@DOCID=DocID from ACC_DocDetails with(nolock) where VoucherNo=@DeprVoucherNo
select @DeprPostDate=Value from com_costcenterpreferences with(nolock) where costcenterid=72 and Name='AssetUnpostDepr'

if @IsPartial=1
begin
	CREATE TABLE #tblDocDetail(iLineNo int,Amount float)
	insert into #tblDocDetail
	select DocSeqNo,sum(Amount) Amount from @TblDepr T
	inner join ACC_AssetDeprDocDetails D with(nolock) on D.DPScheduleID=T.DeprID
	group by DocSeqNo
	
	insert into #tblDocDetail
	select iLineNo+1,Amount from #tblDocDetail with(nolock)
	
	if @DeprPostDate like 'ReverseDeprOn%'
	begin
		set @DocXml='<DocumentXML>'
		
		set @SqlCC=''
select @SqlCC=@SqlCC+'+'','+name+'=''+convert(nvarchar,'+name+')' from sys.columns where object_id=object_id('COM_DocCCDATA') and name like 'dcCCNID%'
set @SqlCC=substring(@SqlCC,4,len(@SqlCC))+'+''"/></Row>'''

set @SqlCC='
set @DocXml=''''
select @DT_INT=DocDate,@DocXml=@DocXml+''<Row> <Transactions DocSeqNo="''+convert(nvarchar,DocSeqNo)+''" DocDetailsID="0" DebitAccount="''+convert(nvarchar,D.CreditAccount)+''" CreditAccount="''+convert(nvarchar,D.DebitAccount)+''" 
 Amount="''+convert(nvarchar,T.Amount)+''" AmtFc="''+convert(nvarchar,T.AmountFC)+''" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Un-Posting" CommonNarration=" Depreciation Un-Posting" RefNodeID="0">
</Transactions><Numeric /><Alpha/><EXTRAXML/>
<CostCenters Query="'+@SqlCC

set @SqlCC=@SqlCC+'
from ACC_DocDetails D with(nolock) inner join COM_DocCCDATA DCC with(nolock) on D.AccDocDetailsID=DCC.AccDocDetailsID
inner join #tblDocDetail T with(nolock) on T.iLineNo=D.DocSeqNo
where DocID='+convert(nvarchar,@DOCID)+'
order by DocSeqNo

print(@DocXml)
'

EXEC sp_executesql @SqlCC, N'@DT_INT INT OUTPUT, @DocXml nvarchar(max) OUTPUT',@DT_INT OUTPUT,@DocXml OUTPUT

		set @DocXml=@DocXml+'</DocumentXML>'
		
		if @DeprPostDate='ReverseDeprOnCurrDt'
			set @DT_INT=floor(convert(float,@DT))

		set @Prefix=''
		EXEC [sp_GetDocPrefix] @DocXml,@DT_INT,@COSTCENTERID,@Prefix output 

		EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]
			@CostCenterID = @COSTCENTERID,
			@DocID = 0,
			@DocPrefix = @Prefix,
			@DocNumber = N'',
			@DocDate = @DT_INT,
			@DueDate =NULL,
			@BillNo = NULL,
			@InvDocXML = @DocXml,
			@NotesXML =  N'',
			@AttachmentsXML =  N'',
			@ActivityXML = N'',
			@IsImport = 0,
			@LocationID = 1,
			@DivisionID = 1,
			@WID = 0,
			@RoleID = 1,
			@RefCCID = 72,
			@RefNodeid =1 ,
			@CompanyGUID = @CompanyGUID,
			@UserName = @UserName,
			@UserID = @UserID,
			@LangID = @LangID
	end
	else
	begin
		RAISERROR('-141',16,1)
	end
end
else
begin
	if @DeprPostDate like 'ReverseDeprOn%'
	begin
		set @DocXml='<DocumentXML>'

		set @SqlCC=''
		select @SqlCC=@SqlCC+'+'','+name+'=''+convert(nvarchar,'+name+')' from sys.columns where object_id=object_id('COM_DocCCDATA') and name like 'dcCCNID%'
		set @SqlCC=substring(@SqlCC,4,len(@SqlCC))+'+''"/></Row>'''

		set @SqlCC='
		set @DocXml=''''
		select @DT_INT=DocDate,@DocXml=@DocXml+''<Row> <Transactions DocSeqNo="''+convert(nvarchar,DocSeqNo)+''" DocDetailsID="0" DebitAccount="''+convert(nvarchar,D.CreditAccount)+''" CreditAccount="''+convert(nvarchar,D.DebitAccount)+''" 
		 Amount="''+convert(nvarchar,D.Amount)+''" AmtFc="''+convert(nvarchar,D.AmountFC)+''" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Un-Posting" CommonNarration=" Depreciation Un-Posting" RefNodeID="0">
		</Transactions><Numeric /><Alpha/><EXTRAXML/>
		<CostCenters Query="'+@SqlCC

		set @SqlCC=@SqlCC+'
		from ACC_DocDetails D with(nolock) inner join COM_DocCCDATA DCC with(nolock) on D.AccDocDetailsID=DCC.AccDocDetailsID
		where DocID='+convert(nvarchar,@DOCID)+'
		order by DocSeqNo

		print(@DocXml)
		'

		EXEC sp_executesql @SqlCC, N'@DT_INT INT OUTPUT, @DocXml nvarchar(max) OUTPUT',@DT_INT OUTPUT,@DocXml OUTPUT
		
		set @DocXml=@DocXml+'</DocumentXML>'
		
		if @DeprPostDate='ReverseDeprOnCurrDt'
			set @DT_INT=floor(convert(float,@DT))

		set @Prefix=''
		EXEC [sp_GetDocPrefix] @DocXml,@DT_INT,@COSTCENTERID,@Prefix output 

		EXEC @return_value = [dbo].[spDOC_SetTempAccDocument]
			@CostCenterID = @COSTCENTERID,
			@DocID = 0,
			@DocPrefix = @Prefix,
			@DocNumber = N'',
			@DocDate = @DT_INT,
			@DueDate =NULL,
			@BillNo = NULL,
			@InvDocXML = @DocXml,
			@NotesXML =  N'',
			@AttachmentsXML =  N'',
			@ActivityXML = N'',
			@IsImport = 0,
			@LocationID = 1,
			@DivisionID = 1,
			@WID = 0,
			@RoleID = 1,
			@RefCCID = 72,
			@RefNodeid =1 ,
			@CompanyGUID = @CompanyGUID,
			@UserName = @UserName,
			@UserID = @UserID,
			@LangID = @LangID
				
	end
	else
	begin
		if @DOCID is not null
		begin
			EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]    
			@CostCenterID = @COSTCENTERID,@DocPrefix = '',@DocNumber = '', @DOcID=   @DOCID,
			@UserID = 1,@UserName = N'ADMIN',@LangID = 1,@RoleID=1
		end
	end
end

if @return_value>0
begin
	UPDATE ACC_Assets
	set ASSETNETVALUE=(AssetNetValue-T.DeprAmount)
	from ACC_Assets A with(nolock)
	inner join 
	(
	select T.AssetID,sum(Amount) DeprAmount 
	from ACC_AssetDeprDocDetails D with(nolock)
	inner join @TblDepr T on D.DPScheduleID=T.DeprID
	group by T.AssetID
	) AS T on A.AssetID=T.AssetID
	
	update ACC_AssetDepSchedule  
	set DOCID=NULL,VOUCHERNO=NULL,DOCDATE=NULL,STATUSID=0
	from @TblDepr T
	inner join ACC_AssetDepSchedule D with(nolock) on D.DPScheduleID=T.DeprID

	delete from ACC_AssetDeprDocDetails where DPScheduleID in (select DeprID from @TblDepr)	
	
	insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,LocationID,GUID,CreatedBy,CreatedDate)  
	values(@AssetID,7,'Depreciation Schedule UnPost',1,@DT_INT,@AssetNetValue,@DepAmount,(@AssetNetValue-@DepAmount),NULL,newid(),'ADMIN',convert(float,@DT))  
end

COMMIT TRANSACTION
--ROLLBACK TRANSACTION
     
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;   
RETURN @return_value

END TRY        
BEGIN CATCH        
IF ERROR_NUMBER()=50000    
 BEGIN    
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
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
