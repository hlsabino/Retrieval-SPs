USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_PostDeprJVSummary]
	@COSTCENTERID [bigint],
	@postingDate [datetime],
	@DrAcc [bigint],
	@CrAcc [bigint],
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
DECLARE   @XML XML ,@DXML XML , @CNT INT , @ICNT INT , @DocXml nvarchar(max) , @return_value BIGINT ,@DT datetime,@DT_INT INT,@Vendor bigint,@PN nvarchar(50)
DECLARE @DEPID BIGINT ,@VOUCHERNO NVARCHAR(200) ,@DocDate float ,@STATUSID INT  , @AssetNetValue FLOAT, @ScheduleID BIGINT,@DoXML xml,@AssetOldValue Float
DECLARE @LineXML NVARCHAR(MAX),@AssetID bigint ,@Prefix nvarchar(200),@DeprPostDate nvarchar(50),@CCQUERY nvarchar(max)
declare @DepAmount float,@LocationDimID bigint,@AssDimNodeID bigint,@AssDimID bigint,@LocationID bigint,@tblAmountID bigint
declare @TblHist as table(ID int identity(1,1),HDays int,HNodeID bigint,HFromDate float,HToDate float)
declare @TblDepr as table(ID int identity(1,1),DeprID bigint)
declare @JVXML nvarchar(max),@Hi int,@HCnt int,@Decimals int,@IsTransferFound bit,@PostAccounting bit
declare @tblListJVPost as Table(ID int identity(1,1),DepID bigint,AssetID bigint) 
declare @tblAmount as Table(ID int identity(1,1),LocationID bigint,Amount float) 
declare @tblDocDetail as Table(DeprSchID bigint,Amount float,iLineNo int)

declare @dbl float,@dblCum float,@DeprStartDate int,@DeprEndDate int
		,@HDays int,@HNodeID bigint,@TotDays int,@HLine int,@HFromDate float,@HToDate float
     

select @Decimals=Value from ADM_GlobalPreferences with(nolock) where Name='DecimalsinAmount'

insert into @TblDepr
execute SPSplitString @DeptID,','

delete from @TblDepr
from ACC_AssetDepSchedule A
inner join @TblDepr T ON A.DPScheduleID=T.DeprID
where DocID is not null and DocID!=0

if exists (select P.DPScheduleID--convert(datetime,P.DeprStartDate),P.DPScheduleID,P.DocID,A.* 
from @TblDepr T
inner join ACC_AssetDepSchedule A with(nolock) on A.DPScheduleID=T.DeprID
inner join ACC_AssetDepSchedule P with(nolock) on P.AssetID=A.AssetID and P.DeprStartDate<A.DeprStartDate
LEFT join @TblDepr TP on TP.DeprID=P.DPScheduleID 
where TP.DeprID is null and (P.DocID is null or P.DocID=0))
begin
	RAISERROR('-150',16,1)
end


if(@LocationDimID=0)
	set @LocationDimID=-123
		
set @LocationDimID=isnull((select convert(int,value) from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='AssetLocationDim' and isnumeric(value)=1),0)
set @AssDimID=isnull((select convert(int,value) from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='AssetDimension' and isnumeric(value)=1),0)
set @PostAccounting=isnull((select 1 from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='PostAccountingWhileTransfer' and value='True'),0)

set @CCQUERY=''			
select @CCQUERY=@CCQUERY+'+''dcccnid'+replace(SysColumnName,'CCNID','')+'=''+convert(nvarchar,'+SysColumnName+')+'','''
from adm_costcenterdef with(nolock) 
where CostCenterID=72 and SysColumnName like 'CCNID%' and IsColumnInUse=1 and ColumnCostCenterID NOT IN (@AssDimID,@LocationDimID)-- or ColumnCostCenterID IN (@LocationDimID,@AssDimID)
if(len(@CCQUERY)>1)
	set @CCQUERY=substring(@CCQUERY,2,len(@CCQUERY)-1)
	
if(@CCQUERY!='')
begin
	set @DocXml=N'set @SQL=''''
	select @SQL='+@CCQUERY+' from COM_CCCCDATA with(nolock) where CostCenterID=72 and NodeID='+convert(nvarchar,(select AssetID from ACC_AssetDepSchedule D with(nolock) where DPScheduleID=(select DeprID from  @TblDepr where ID=1)))
	EXEC sp_executesql @DocXml,N'@SQL nvarchar(max) OUTPUT',@CCQUERY OUTPUT
	if(@LocationDimID>50000)
		set @CCQUERY=@CCQUERY+'dcccnid'+convert(nvarchar,@LocationDimID-50000)+'=LOCNODEID,'
	set @CCQUERY='<CostCenters Query="'+@CCQUERY+'"/>'
end
else if(@LocationDimID>50000)
	set @CCQUERY='<CostCenters Query="dcccnid'+convert(nvarchar,@LocationDimID-50000)+'=LOCNODEID,"/>'

Set @DT=getdate()   
set @DT_INT=floor(convert(float,@postingDate))

DECLARE @DEPRCUR cursor, @nStatusOuter int

SET @DEPRCUR = cursor for 
SELECT DeprID FROM @TblDepr

OPEN @DEPRCUR 
SET @nStatusOuter = @@FETCH_STATUS

FETCH NEXT FROM @DEPRCUR Into @DEPID
SET @nStatusOuter = @@FETCH_STATUS
WHILE(@nStatusOuter <> -1)
BEGIN
	select @DepAmount=D.DepAmount,@DeprStartDate=D.DeprStartDate,@DeprEndDate=D.DeprEndDate,@AssetID=D.AssetID
	from ACC_AssetDepSchedule D with(nolock) 
	where D.DPScheduleID=@DEPID  
	
	set @IsTransferFound=0
	
	insert into @TblHist
	select case when ToDate is null then 1+convert(float,@DeprEndDate)-FromDate 
	else 1+ToDate-FromDate end,HistoryNodeID,FromDate,ToDate
	from COM_HistoryDetails with(nolock) 
	WHERE CostCenterID=72 and NodeID=@AssetID and HistoryCCID=1 and 
	(FromDate between @DeprStartDate and @DeprEndDate or ToDate between @DeprStartDate and @DeprEndDate
	 or @DeprStartDate between FromDate and ToDate)
	order by FromDate
	
	select @HCnt=max(ID),@Hi=min(ID) from @TblHist

	set @dblCum=0
	set @HLine=1
	set @TotDays=(@DeprEndDate-@DeprStartDate)+1
	while(@HCnt is not null and @Hi<=@HCnt)
	begin
		set @IsTransferFound=1
		select @HNodeID=HNodeID,@HDays=HDays,@HFromDate=HFromDate,@HToDate=HToDate from @TblHist where ID=@Hi

		if @Hi=@HCnt
		begin
			set @dbl=@DepAmount-@dblCum
		end				
		else
		begin
			 if(@HLine=1 and @HFromDate<@DeprStartDate)
				set @HDays=1+@HToDate-@DeprStartDate
			 set @dbl=(@DepAmount*@HDays)/@TotDays
			 set @dbl=str(@dbl,12,@Decimals)
             set @dblCum=@dblCum+@dbl
		end
	
		if @PostAccounting=0 or @Hi=@HCnt--To dont add trasferred depreciation
		begin
			if exists(select * from @tblAmount where LocationID=@HNodeID)
			begin
				update @tblAmount set Amount=Amount+@dbl where LocationID=@HNodeID
				insert into @tblDocDetail
				select @DEPID,@dbl,ID from @tblAmount where LocationID=@HNodeID
			end
			else
			begin
				insert into @tblAmount
				values(@HNodeID,@dbl)
				SET @tblAmountID=SCOPE_IDENTITY()
				insert into @tblDocDetail
				values(@DEPID,@dbl,@tblAmountID)
			end
		end
		--select @dbl
		
		set @Hi=@Hi+1
		set @HLine=@HLine+2
	end

	if(@IsTransferFound=0)
	begin
		select @LocationID=LocationID from acc_assets with(nolock)where AssetID=@AssetID
		if @LocationID is null or @LocationID=0
			set @LocationID=1

		if exists(select * from @tblAmount where LocationID=@LocationID)
		begin
			update @tblAmount set Amount=Amount+@DepAmount where LocationID=@LocationID
			insert into @tblDocDetail
			select @DEPID,@DepAmount,ID from @tblAmount where LocationID=@LocationID
		end
		else
		begin
			insert into @tblAmount
			values(@LocationID,@DepAmount)
			SET @tblAmountID=SCOPE_IDENTITY()
			insert into @tblDocDetail
			values(@DEPID,@DepAmount,@tblAmountID)
		end
	end

	delete from @TblHist
		
	FETCH NEXT FROM @DEPRCUR Into @DEPID
	SET @nStatusOuter = @@FETCH_STATUS
END
CLOSE @DEPRCUR
DEALLOCATE @DEPRCUR
--select * from @tblDocDetail
--select * from @tblAmount
SELECT @CNT=COUNT(ID) FROM @tblAmount  
SET @ICNT = 1  
set @HLine=1
set @DocXml=''
while(@ICNT<=@CNT)  
begin  
	SELECT @dbl=Amount,@HNodeID=LocationID FROM @tblAmount where ID=@ICNT

--select @dbl,convert(nvarchar,@dbl),str(@dbl,10,@Decimals)
	set @DocXml=@DocXml+'<Row> <Transactions DocSeqNo="'+convert(nvarchar,@HLine)+'"  DocDetailsID="0" LinkedInvDocDetailsID="" LinkedFieldName="" DebitAccount="'+convert(nvarchar,@DrAcc)+'" CreditAccount="-99" 
 Amount="'+str(@dbl,10,@Decimals)+'" AmtFc="'+str(@dbl,10,@Decimals)+'" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Posting" CommonNarration=" Depreciation Posting"  >
 </Transactions> <Numeric /><Alpha />'+replace(@CCQUERY,'LOCNODEID',convert(nvarchar,@HNodeID))+'<EXTRAXML/>
  </Row><Row> <Transactions DocSeqNo="'+convert(nvarchar,@HLine+1)+'"  DocDetailsID="0" LinkedInvDocDetailsID="" LinkedFieldName="" DebitAccount="-99" CreditAccount="'+convert(nvarchar,@CrAcc)+'"
   Amount="'+str(@dbl,10,@Decimals)+'" AmtFc="'+str(@dbl,10,@Decimals)+'" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Posting" CommonNarration="Depreciation Posting"  >
   </Transactions> <Numeric /> <Alpha />'+replace(@CCQUERY,'LOCNODEID',convert(nvarchar,@HNodeID))+'<EXTRAXML/> </Row>'
 
	SET @ICNT =@ICNT+1  
	set @HLine=@HLine+2
end
  
if @DocXml!=''
begin
	set @DocXml='<DocumentXML>'+@DocXml+'</DocumentXML>'
--select convert(xml, @DocXml)

	 set @Prefix=''
	EXEC [sp_GetDocPrefix] @DocXml,@DT_INT,@COSTCENTERID,@Prefix output 

	EXEC	@return_value = [dbo].[spDOC_SetTempAccDocument]
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
		
	SELECT @VOUCHERNO = VOUCHERNO , @DocDate =Docdate ,@STATUSID =STATUSID FROM ACC_DOCDETAILS with(nolock)
	WHERE DOCID = @return_value 
	
	--SELECT * FROM ACC_DOCDETAILS with(nolock) WHERE DOCID = @return_value 

	IF(@return_value > 0 )
	BEGIN
		
		UPDATE  ACC_AssetDepSchedule
		SET DOCID = @return_value , VOUCHERNO = @VOUCHERNO ,  Docdate = @DocDate , STATUSID = @STATUSID
		from @TblDepr T inner join ACC_AssetDepSchedule DP with(nolock) on T.DEPRID=DP.DPScheduleID
		
		insert into ACC_AssetDeprDocDetails(DPScheduleID,Amount,DocSeqNo)
		select DeprSchID,Amount,iLineNo*2-1 from @tblDocDetail
		
		update ACC_Assets
		set AssetNetValue=DP.AssetNetValue
		from @TblDepr T inner join ACC_AssetDepSchedule DP with(nolock) on T.DEPRID=DP.DPScheduleID
		inner join ACC_Assets acc with(nolock) on acc.AssetID=DP.AssetID
		
		--select acc.AssetNetValue,DP.AssetNetValue
		--from @TblDepr T inner join ACC_AssetDepSchedule DP with(nolock) on T.DEPRID=DP.DPScheduleID
		--inner join ACC_Assets acc with(nolock) on acc.AssetID=DP.AssetID
		
		--if not exists( select AssetNewValue from ACC_AssetChanges with(nolock) where AssetID=@AssetID)
		--	set @AssetOldValue=(select purchaseValue from acc_assets with(nolock) where AssetID=@AssetID)
		--else
		--begin
		--	if exists(select *  from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DOCID is not null and VoucherNo is not null)
		--	  set @AssetOldValue=(select top(1)AssetNetValue  from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DOCID is not null and VoucherNo is not null)
		--	else
		--		set @AssetOldValue=(select top(1)AssetNewValue from acc_assetchanges with(nolock) where AssetID=@AssetID order by AssetChangeID desc)
		--end 

		--insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,LocationID,GUID,CreatedBy,CreatedDate)
		--values(@AssetID,7,'Depreciation Dashboard Post',1,@DT_INT,@AssetOldValue,@DepAmount,@AssetNetValue,NULL,newid(),'ADMIN',convert(float,@DT))
		insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,LocationID,GUID,CreatedBy,CreatedDate)
		select acc.AssetID,7,'Depreciation Dashboard Post',1,@DT_INT,DP.DepAmount+acc.AssetNetValue,DP.DepAmount,acc.AssetNetValue,NULL,newid(),'ADMIN',convert(float,@DT)
		from @TblDepr T inner join ACC_AssetDepSchedule DP with(nolock) on T.DEPRID=DP.DPScheduleID
		inner join ACC_Assets acc with(nolock) on acc.AssetID=DP.AssetID
	END
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
