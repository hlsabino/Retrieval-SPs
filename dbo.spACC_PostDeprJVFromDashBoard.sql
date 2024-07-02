USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_PostDeprJVFromDashBoard]
	@COSTCENTERID [int],
	@JVXML [nvarchar](max),
	@Post [bit],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100)    
BEGIN TRY        
SET NOCOUNT ON;
DECLARE   @XML XML ,@DXML XML , @CNT INT , @ICNT INT , @DocXml nvarchar(max) , @return_value INT ,@DT datetime,@DT_INT INT,@Vendor INT,@PN nvarchar(50)
DECLARE @DEPID INT ,@VOUCHERNO NVARCHAR(200) ,@DocDate float ,@STATUSID INT  , @AssetNetValue FLOAT, @ScheduleID INT,@DoXML xml,@AssetOldValue Float
DECLARE @LineXML NVARCHAR(MAX),@AssetID INT ,@Prefix nvarchar(200),@DeprPostDate nvarchar(50),@CCQUERY nvarchar(max)
declare @DepAmount float,@Locationid INT,@LocationDimID INT,@AssDimNodeID INT,@AssDimID INT
declare @TblHist as table(ID int identity(1,1),HDays int,HNodeID INT,HFromDate float,HToDate float)
declare @Hi int,@HCnt int,@Decimals int,@PostAccounting bit,@PostDate datetime
declare @tblListJVPost as Table(ID int identity(1,1),DepID INT,AssetID INT,Dt DateTime)      
set @return_value=0
select @Decimals=Value from ADM_GlobalPreferences with(nolock) where Name='DecimalsinAmount'

IF(@Post = 1)
BEGIN
	IF(@JVXML is not null and @JVXML<>'')  
	BEGIN   
		 SET @XML =   @JVXML  
		
		 set @AssDimID=isnull((select convert(int,value) from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='AssetDimension' and isnumeric(value)=1),0)
		 set @LocationDimID=isnull((select convert(int,value) from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='AssetLocationDim' and isnumeric(value)=1),0)
		 set @PostAccounting=isnull((select 1 from com_costcenterpreferences with(nolock) where CostCenterID=72 and Name='PostAccountingWhileTransfer' and value='True'),0)

		 INSERT INTO @tblListJVPost
		 SELECT X.value('@DepID', 'INT'),X.value('@AssetID', 'INT'),X.value('@Dt', 'datetime')
		 from @XML.nodes('/JVXML/ROWS/DepreciationID') as Data(X)  
		 
		 SELECT @CNT=COUNT(ID) FROM @tblListJVPost  
		  
		 Set @DT=getdate()   
		 set @DT_INT=floor(convert(float,@DT))
		 select @DeprPostDate=Value from com_costcenterpreferences with(nolock) where costcenterid=72 and Name='AssetDeprPostDate'
		    
		 SET @ICNT = 0  
		 WHILE(@ICNT < @CNT)  
		 BEGIN  
			SET @ICNT =@ICNT+1  
			   
			SELECT @DEPID=DEPID,@AssetID=AssetID,@PostDate=Dt FROM @tblListJVPost WHERE  ID = @ICNT  

			if exists (select * from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DPScheduleID=@DEPID and DocID is not null and DocID!=0)
				continue;
			
			declare @dbl float,@dblCum float,@DeprStartDate int,@DeprEndDate int
				,@DrAcc INT,@CrAcc INT,@HDays int,@HNodeID INT,@TotDays int,@HLine int,@HFromDate float,@HToDate float
			
			select @DepAmount=D.DepAmount,@DeprStartDate=D.DeprStartDate,@DeprEndDate=D.DeprEndDate
			,@DrAcc=Ass.DeprExpenseACCID,@CrAcc=Ass.AccumDeprACCID
			from ACC_AssetDepSchedule D with(nolock) 
			Join Acc_Assets Ass with(nolock) on	D.AssetID=Ass.AssetID
			where D.AssetID=@AssetID and D.DPScheduleID=@DEPID  

			if exists (select * from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DeprStartDate<@DeprStartDate and (DocID is null or DocID=0))
			begin
				set @return_value=-150
				continue;
			end
				
			if(@LocationDimID=0)
				set @LocationDimID=-123
			if(@AssDimID=0)
				set @AssDimID=-123

			set @CCQUERY=''			
			select @CCQUERY=@CCQUERY+'+''dcccnid'+replace(SysColumnName,'CCNID','')+'=''+convert(nvarchar,'+SysColumnName+')+'','''
			from adm_costcenterdef with(nolock) 
			where CostCenterID=72 and SysColumnName like 'CCNID%' and (IsColumnInUse=1 or ColumnCostCenterID IN (@AssDimID)) and ColumnCostCenterID NOT IN (@LocationDimID)-- or ColumnCostCenterID IN (@LocationDimID,@AssDimID)
			if(len(@CCQUERY)>1)
				set @CCQUERY=substring(@CCQUERY,2,len(@CCQUERY)-1)
				
			select @Locationid=locationid from acc_assets with(nolock) where AssetID=@AssetID
			if(@Locationid=0 or @Locationid is null)
				set @Locationid=1
			
			--set @AssDimNodeID=null
			if(@CCQUERY!='')
			begin
				set @DocXml=N'set @SQL=''''
				select @SQL='+@CCQUERY+' from COM_CCCCDATA with(nolock) where CostCenterID=72 and NodeID='+convert(nvarchar,@AssetID)
				--print(@DocXml)
				EXEC sp_executesql @DocXml,N'@SQL nvarchar(max) OUTPUT',@CCQUERY OUTPUT
				if(@LocationDimID>50000)
					set @CCQUERY=@CCQUERY+'dcccnid'+convert(nvarchar,@LocationDimID-50000)+'=LOCNODEID,'
				set @CCQUERY='<CostCenters Query="'+@CCQUERY+'"/>'
			end
			else if(@LocationDimID>50000)
				set @CCQUERY='<CostCenters Query="dcccnid'+convert(nvarchar,@LocationDimID-50000)+'=LOCNODEID,"/>'
		 
			SET @DocXml=''
			
			insert into @TblHist
			select * from
			(
			select case when ToDate is null then 1+convert(float,@DeprEndDate)-FromDate 
			else 1+ToDate-FromDate end HDays,HistoryNodeID,FromDate,ToDate
			from COM_HistoryDetails with(nolock) 
			WHERE CostCenterID=72 and NodeID=@AssetID and HistoryCCID=1 and 
			(FromDate between @DeprStartDate and @DeprEndDate or ToDate between @DeprStartDate and @DeprEndDate
			 or @DeprStartDate between FromDate and ToDate)
			 ) AS T
			 group by HDays,HistoryNodeID,FromDate,ToDate
			order by FromDate
			
			--select * from @TblHist
			
			select @HCnt=max(ID),@Hi=min(ID) from @TblHist
			
			--select @Hi,@HCnt
			
			set @dblCum=0
			set @HLine=1
			set @TotDays=(@DeprEndDate-@DeprStartDate)+1
			while(@HCnt is not null and @Hi<=@HCnt)
			begin
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
				set @LineXML='<Row> <Transactions DocSeqNo="'+convert(nvarchar,@HLine)+'"  DocDetailsID="0" LinkedInvDocDetailsID="" LinkedFieldName="" DebitAccount="'+convert(nvarchar,@DrAcc)+'" CreditAccount="-99" 
 Amount="'+convert(nvarchar,@dbl)+'" AmtFc="'+convert(nvarchar,@dbl)+'" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Posting" CommonNarration=" Depreciation Posting" TDEPRIDT="'+convert(nvarchar,@DEPID)+'">
 </Transactions> <Numeric /><Alpha />'+replace(@CCQUERY,'LOCNODEID',convert(nvarchar,@HNodeID))+'<EXTRAXML/>
  </Row><Row> <Transactions DocSeqNo="'+convert(nvarchar,@HLine+1)+'"  DocDetailsID="0" LinkedInvDocDetailsID="" LinkedFieldName="" DebitAccount="-99" CreditAccount="'+convert(nvarchar,@CrAcc)+'"
   Amount="'+convert(nvarchar,@dbl)+'" AmtFc="'+convert(nvarchar,@dbl)+'" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Posting" CommonNarration="Depreciation Posting"  >
   </Transactions> <Numeric /> <Alpha />'+replace(@CCQUERY,'LOCNODEID',convert(nvarchar,@HNodeID))+'<EXTRAXML/> </Row>'
				--select @dbl				
				set @Hi=@Hi+1
				if @PostAccounting=1
				begin
					set @DocXml=@LineXML
				end
				else
				begin
					set @DocXml=@DocXml+@LineXML
					set @HLine=@HLine+2
				end
			end
			
			if(@DocXml='')
			begin
				set @DocXml='<DocumentXML><Row> <Transactions DocSeqNo="1"  DocDetailsID="0" LinkedInvDocDetailsID="" LinkedFieldName="" DebitAccount="'+convert(nvarchar,@DrAcc)+'" CreditAccount="-99" 
 Amount="'+convert(nvarchar,@DepAmount)+'" AmtFc="'+convert(nvarchar,@DepAmount)+'" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Posting" CommonNarration=" Depreciation Posting" TDEPRIDT="'+convert(nvarchar,@DEPID)+'">
 </Transactions> <Numeric /> <Alpha /> '+replace(@CCQUERY,'LOCNODEID',convert(nvarchar,@Locationid))+' <EXTRAXML/>
  </Row><Row> <Transactions DocSeqNo="2"  DocDetailsID="0" LinkedInvDocDetailsID="" LinkedFieldName="" DebitAccount="-99" CreditAccount="'+convert(nvarchar,@CrAcc)+'"
   Amount="'+convert(nvarchar,@DepAmount)+'" AmtFc="'+convert(nvarchar,@DepAmount)+'" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Posting" CommonNarration="Depreciation Posting"  >
   </Transactions> <Numeric /> <Alpha /> '+replace(@CCQUERY,'LOCNODEID',convert(nvarchar,@Locationid))+'<EXTRAXML/> </Row></DocumentXML>'
			end
			else
			begin
				set @DocXml='<DocumentXML>'+@DocXml+'</DocumentXML>'
			end

		--	select convert(xml, @DocXml)
			
			delete from @TblHist

			if @PostDate is not null
				set @DT_INT=convert(int,@PostDate)
			else if @DeprPostDate='ScheduleDate'
				select @DT_INT=DeprEndDate from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DPScheduleID=@DEPID
		  
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
					@RefNodeid =@AssetID ,
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
						WHERE DPScheduleID = @DEPID and AssetID = @AssetID
						
						set @DXML=@DocXml
						insert into ACC_AssetDeprDocDetails(DPScheduleID,Amount,DocSeqNo)
						SELECT X.value('@TDEPRIDT', 'INT'),X.value('@Amount', 'float'),X.value('@DocSeqNo', 'int')
						from @DXML.nodes('/DocumentXML/Row/Transactions') as Data(X)
						where X.value('@TDEPRIDT', 'INT') is not null
						 
						SELECT @AssetNetValue = AssetNetValue FROM ACC_AssetDepSchedule with(nolock) WHERE DPScheduleID = @DEPID and AssetID = @AssetID
					
						 UPDATE ACC_Assets
						 SET AssetNetValue =  @AssetNetValue
						 WHERE   AssetID = @AssetID
						
						--update Location based on asset
						 /*select @Locationid=locationid from acc_assets with(nolock) where AssetID=@AssetID
						 if(@Locationid>1)
						 BEGIN
							update com_docccdata set dcccnid2=@Locationid   
							from com_docccdata cc with(nolock)
							join acc_docdetails d with(nolock) on cc.accdocdetailsid=d.accdocdetailsid 
							where d.RefCCID=72 and d.RefNodeid=@AssetID 
						 END */
						
						 if not exists( select AssetNewValue from ACC_AssetChanges with(nolock) where AssetID=@AssetID)
						    set @AssetOldValue=(select purchaseValue from acc_assets with(nolock) where AssetID=@AssetID)
						 else
						 begin
							if exists(select *  from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DOCID is not null and VoucherNo is not null)
							  set @AssetOldValue=(select top(1)AssetNetValue  from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DOCID is not null and VoucherNo is not null)
							else
								set @AssetOldValue=(select top(1)AssetNewValue from acc_assetchanges with(nolock) where AssetID=@AssetID order by AssetChangeID desc)
						 end 
						 --select * from ACC_AssetDepSchedule 
						 insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,LocationID,GUID,CreatedBy,CreatedDate)
						 values(@AssetID,7,'Depreciation Dashboard Post',1,@DT_INT,@AssetOldValue,@DepAmount,@AssetNetValue,NULL,newid(),'ADMIN',convert(float,@DT))
				  END
				  
			  END 
	 END 
END
ELSE   
BEGIN  
   IF(@JVXML is not null and @JVXML<>'')    
   BEGIN    
    DECLARE @DOCID INT,@DELDocPrefix nvarchar(50),@DELDocNumber nvarchar(500)
    select @DeprPostDate=Value from com_costcenterpreferences with(nolock) where costcenterid=72 and Name='AssetUnpostDepr'
   
    SET @XML=@JVXML     
   
    INSERT INTO @tblListJVPost(DepID,AssetID) 
	SELECT X.value('@DepID', 'INT'),X.value('@AssetID', 'INT')
	from @XML.nodes('/JVXML/DepreciationID') as Data(X) 
  
    SELECT @CNT = COUNT(ID) FROM @tblListJVPost    
  
    Set @DT=getdate()   
    set @DT_INT=floor(convert(float,@DT))
    
    
  --  select * from @tblListJVPost

	
    SET @ICNT = 0
    declare @SummaryDeprFound int
    set @SummaryDeprFound=0
    WHILE(@ICNT < @CNT)    
    BEGIN    
		SET @ICNT =@ICNT+1    
		SET @ScheduleID = 0   
		SELECT  @ScheduleID  = DEPID,@AssetID=AssetID  FROM @tblListJVPost WHERE  ID = @ICNT    
	  
		SET @VOUCHERNO = ''  
		SET @STATUSID = 0   
		SET @AssetNetValue = 0   
  
		SELECT @DOCID=DOCID,@VOUCHERNO=VOUCHERNO,@DocDate=DOCDATE,@STATUSID=STATUSID,@DepAmount=DepAmount   
		,@AssetNetValue=AssetNetValue,@DeprStartDate=DeprStartDate
		FROM ACC_AssetDepSchedule with(nolock)
		where AssetID = @AssetID and DPScheduleID = @ScheduleID  
		
		if(select count(*) from ACC_AssetDepSchedule with(nolock) where @DOCID=DOCID and @VOUCHERNO=VOUCHERNO)>1
		begin
			set @SummaryDeprFound=@SummaryDeprFound+1
			continue;
		end
		
		if exists (select * from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DeprStartDate>@DeprStartDate and DocID is not null and DocID!=0)
		begin
			set @return_value=-151
			continue;	
		end
		    
--ReverseDeprOnPostDt
--ReverseDeprOnCurrDt
		--Checking of asset transafer not done
		if @DeprPostDate like 'ReverseDeprOn%'
		begin
			set @DocXml='<DocumentXML>'

			declare @SqlCC nvarchar(max)
			set @SqlCC=''
select @SqlCC=@SqlCC+'+'','+name+'=''+convert(nvarchar,'+name+')' from sys.columns where object_id=object_id('COM_DocCCDATA') and name like 'dcCCNID%'
set @SqlCC=substring(@SqlCC,4,len(@SqlCC))+'+''"/></Row>'''

set @SqlCC='
set @DocXml=''''
select @DT_INT=DocDate,@DocXml=@DocXml+''<Row> <Transactions DocSeqNo="''+convert(nvarchar,DocSeqNo)+''" DocDetailsID="0" DebitAccount="''+convert(nvarchar,D.CreditAccount)+''" CreditAccount="''+convert(nvarchar,D.DebitAccount)+''" 
 Amount="''+convert(nvarchar,D.Amount)+''" AmtFc="''+convert(nvarchar,D.AmountFC)+''" CurrencyID="1" ExchangeRate="1" LineNarration="Depreciation Un-Posting" CommonNarration=" Depreciation Un-Posting"  >
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
			
		--	print(@DocXml)
			
			if @DeprPostDate='ReverseDeprOnCurrDt'
				set @DT_INT=floor(convert(float,@DT))
			--select @DeprPostDate,@DocXml

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
					@RefNodeid =@AssetID ,
					@CompanyGUID = @CompanyGUID,
					@UserName = @UserName,
					@UserID = @UserID,
					@LangID = @LangID
					
			--SELECT @VOUCHERNO=VOUCHERNO,@DocDate=Docdate,@STATUSID=STATUSID FROM ACC_DOCDETAILS with(nolock) WHERE DOCID = @return_value 
					
			--SELECT * FROM ACC_DOCDETAILS with(nolock) WHERE DOCID = @return_value 
			     
			IF(@return_value < 0 )
				continue;
		end
		else
		begin
			EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]    
			@CostCenterID = @COSTCENTERID,@DocPrefix = '',@DocNumber = '', @DOcID=   @DOCID,
			@UserID = 1,@UserName = N'ADMIN',@LangID = 1,@RoleID=1
		end
		
		 UPDATE ACC_Assets  
		 SET ASSETNETVALUE = (@AssetNetValue+@DepAmount)    
		 WHERE ASSETID = @AssetID  
	  
		 --SELECT * FROM ACC_AssetDepSchedule    
		 UPDATE ACC_AssetDepSchedule  
		 SET DOCID = NULL, VOUCHERNO = NULL , DOCDATE = NULL , STATUSID = 0   
		 WHERE ASSETID = @AssetID and DPScheduleID = @ScheduleID  
		 
		 delete from ACC_AssetDeprDocDetails where DPScheduleID=@ScheduleID
	        
		 insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,LocationID,GUID,CreatedBy,CreatedDate)  
		 values(@AssetID,7,'Depreciation Schedule UnPost',1,@DT_INT,@AssetNetValue,@DepAmount,(@AssetNetValue-@DepAmount),NULL,newid(),'ADMIN',convert(float,@DT))  
     
		set @return_value = 1  
    END--END WHILE   
    
    if @SummaryDeprFound>0 and @CNT=@SummaryDeprFound
    begin
		RAISERROR('-141',16,1)    
    end
    
   END -- END IF   
END --ELSE END  

COMMIT TRANSACTION
--ROLLBACK TRANSACTION
if @return_value=-150 or @return_value=-151
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)
	WHERE ErrorNumber=@return_value AND LanguageID=@LangID
else
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
	WHERE ErrorNumber=100 AND LanguageID=@LangID

SET NOCOUNT OFF;  
RETURN @return_value
END TRY        
BEGIN CATCH   

	if(@return_value<0)
		return @return_value
					     
IF ERROR_NUMBER()=50000    
 BEGIN    
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM    
COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END    
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM    
COM_ErrorMessages WITH(nolock)    
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
