USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_SetOpeningLoan]
	@CostCenterID [int],
	@DocID [int],
	@invID [int],
	@LocationID [int],
	@DivisionID [int],
	@DocDate [datetime],
	@DocNo [nvarchar](10),
	@UserName [nvarchar](200),
	@Userid [int],
	@langID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY      
SET NOCOUNT ON;  
  declare @Amt float,@InstAmt float,@NoOfins int,@ActInst Float,@tot float,@totUsed float,@i int,@dM datetime,@Prefix nvarchar(200),@DOCNumber nvarchar(10),@dMStart datetime
  declare @VoucherNO nvarchar(500),@DocumentType int,@ABBR nvarchar(50),@InvDocDetailsID INT,@DocumentTypeID INT,@IM datetime,@sql nvarchar(max)
  declare @tab table(seq int,ins float,mnth datetime)
  set @Amt=0
  set @InstAmt=0
  set @NoOfins=1
  set @tot=0
  set @totUsed=0
  set @i=0
  
IF((SELECT COUNT(*) FROM INV_DOCDETAILS WITH(NOLOCK) WHERE COSTCENTERID=40056 AND REFNODEID IN (SELECT INVDOCDETAILSID FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID))>0)
BEGIN
	IF((SELECT COUNT(*) FROM INV_DOCDETAILS WITH(NOLOCK) WHERE COSTCENTERID=40057 AND REFNODEID IN (SELECT INVDOCDETAILSID FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID))=0)
	BEGIN
		DECLARE @DOCPREFIX NVARCHAR(50),@DCNO INT
		SELECT @DOCPREFIX=DOCPREFIX,@DCNO=DOCNUMBER FROM INV_DOCDETAILS WITH(NOLOCK) WHERE COSTCENTERID=40056 AND REFNODEID IN (SELECT INVDOCDETAILSID FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID)
		UPDATE INV_DOCDETAILS SET REFNODEID=0 WHERE COSTCENTERID=40056 AND REFNODEID IN (SELECT INVDOCDETAILSID FROM INV_DOCDETAILS WITH(NOLOCK) WHERE DOCID=@DOCID)
		EXEC spDOC_DeleteInvDocument 40056,@DOCPREFIX,@DCNO,0,' and (a.CostCenterID=c.DocumentID or c.DocumentID=1) and (b.dcCCNID2=c.CCNID2 or c.CCNID2=0)','','',1,'Admin',1,1
	END
END

  SET @SQL='select @dM=convert(datetime,dcAlpha1) from COM_DocTextData WITH(NOLOCK)
  where InvDocDetailsID='+CONVERT(VARCHAR,@invID)+' and dcAlpha1 is not null and dcAlpha1<>'''''
  
  EXEC sp_executesql @SQL,N'@dM datetime OUTPUT',@dM OUTPUT
  
  set @dMStart=convert(datetime,@dM)
  
  SET @SQL='select @tot=dcNum1,@Amt=dcNum2,@InstAmt=dcNum3 from COM_DocNumData WITH(NOLOCK)
  where InvDocDetailsID='+CONVERT(VARCHAR,@invID)
  
  EXEC sp_executesql @SQL,N'@tot float OUTPUT,@Amt float OUTPUT ,@InstAmt float OUTPUT',@tot OUTPUT,@Amt OUTPUT ,@InstAmt OUTPUT  
	IF(@tot>0)
	BEGIN  
		set @NoOfins=@tot/@InstAmt
		
		set @ActInst=@tot/@InstAmt
		if(@ActInst>@NoOfins)
			SET @NoOfins=@NoOfins+1
		
		while(@i<@NoOfins)
		BEGIN
			set @i=@i+1
			
			if(@i>=@NoOfins)
				set @InstAmt=@tot-@totUsed
			else
				set @totUsed=@totUsed+@InstAmt	
			insert into @tab(seq,ins,mnth)
			values(@i,@InstAmt,@dM)
			
			set @dM=DATEADD(MONTH,1,@dM)				
		END	
	END	
	
	EXEC [sp_GetDocPrefix] '',@DocDate,40056,@Prefix output,@invID,0,0   
	set @Prefix=@Prefix+@DocNo+'/'
	
	select @DocumentTypeID=DocumentTypeID,@DocumentType=DocumentType,@ABBR=DocumentAbbr from ADM_DOCUMENTTYPES with(nolock) where CostCenterId=40056


	if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef with(nolock) WHERE CostCenterID=40056 AND CodePrefix=@Prefix)    
	begin 
	 INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
	 VALUES(40056,40056,@Prefix,1,1,1,1,Newid(),@UserName,convert(float,getdate()),@LocationID,@DivisionID)    
	 set @DOCNumber=1
	end   
	else
	begin		 
		set @DOCNumber=(select  CurrentCodeNumber+1 from Com_CostCenterCodeDef with(nolock) where CodePrefix=@Prefix  and CostCenterID=40056)
		 UPDATE Com_CostCenterCodeDef
		 SET CurrentCodeNumber=CurrentCodeNumber+1 
		 where CodePrefix=@Prefix  and CostCenterID=40056
	end
	if(@Prefix='')
	begin
		set @VoucherNO=@ABBR+'-'+convert(nvarchar(50), @DOCNumber)
	end
	else
	begin
		set @VoucherNO=@ABBR+'-'+@Prefix+convert(nvarchar(50), @DOCNumber)
	end
	
	while exists (select DocNo from COM_DocID with(nolock) where DocNo=@VoucherNo)
	begin			
		SET @DOCNumber=@DocNumber+1
		SET @VoucherNO=isnull(@ABBR,'')+'-'+isnull(@Prefix,'')+isnull(@DocNumber,'')
	end	
	
	INSERT INTO COM_DocID(DocNo)
	VALUES(@VoucherNo)
	SET @DocID=@@IDENTITY
	
	set @i=0
	select @NoOfins=COUNT(*) from @tab 
	
	while(@i<@NoOfins)
	BEGIN
		set @i=@i+1
		INSERT INTO [INV_DocDetails]      
					([AccDocDetailsID]      
					,[DocID]      
					,[CostCenterID]      
					,[DocumentType],DocOrder      
					,[VoucherType]      
					,[VoucherNo]      
					,[VersionNo]      
					,[DocAbbr]      
					,[DocPrefix]      
					,[DocNumber]      
					,[DocDate]      
					,[DueDate]      
					,[StatusID]      
					,[BillNo]      
					,BillDate      
					,[LinkedInvDocDetailsID]      
					,[LinkedFieldName]      
					,[LinkedFieldValue]      
					,[CommonNarration]      
					,LineNarration      
					,[DebitAccount]      
					,[CreditAccount]      
					,[DocSeqNo]      
					,[ProductID]      
					,[Quantity]      
					,[Unit]      
					,[HoldQuantity]    
					,[ReserveQuantity]     
					,[ReleaseQuantity]    
					,[IsQtyIgnored]      
					,[IsQtyFreeOffer]      
					,[Rate]      
					,[AverageRate]      
					,[Gross]      
					,[StockValue]      
					,[CurrencyID]      
					,[ExchangeRate]     
					,[GrossFC]    
					,[StockValueFC] 
					,[CreatedBy]      
					,[CreatedDate],ModifiedBy,ModifiedDate,UOMConversion       
					,UOMConvertedQty,WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID,RefNodeid,ParentSchemeID,RefNo)    
					SELECT [AccDocDetailsID]      
					,@DocID      
					,40056           
					,@DocumentType,DocOrder      
					,[VoucherType]      
					,@VoucherNO      
					,[VersionNo]      
					,@ABBR     
					,@Prefix      
					,@DOCNumber
					,[DocDate]      
					,[DueDate]      
					,[StatusID]      
					,[BillNo]      
					,BillDate      
					,0      
					,''      
					,null      
					,[CommonNarration]      
					,LineNarration      
					,[DebitAccount]      
					,[CreditAccount]      
					,[DocSeqNo]      
					,[ProductID]      
					,[Quantity]      
					,[Unit]      
					,[HoldQuantity]    
					,[ReserveQuantity]     
					,[ReleaseQuantity]    
					,[IsQtyIgnored]      
					,[IsQtyFreeOffer]      
					,[Rate]      
					,[AverageRate]      
					,[Gross]      
					,[StockValue]      
					,[CurrencyID]      
					,[ExchangeRate]     
					,[GrossFC]    
					,[StockValueFC]       
					      
					,[CreatedBy]      
					,[CreatedDate],ModifiedBy,ModifiedDate,UOMConversion       
					,UOMConvertedQty,WorkflowID , WorkFlowStatus , WorkFlowLevel,300,@invID,ParentSchemeID,RefNo
					from [INV_DocDetails] WITH(NOLOCK)				
					where InvDocDetailsID=@invID
					
					SET @InvDocDetailsID=@@IDENTITY  

			
			declare @cols nvarchar(max)
			SET @SQL=''
			set @cols=''
			select @cols=@cols+name+',' from sys.columns
			where object_id('COM_DocCCData')=object_id
			and name like 'dcCCNID%'

			SET @SQL='INSERT INTO [COM_DocCCData]    
			('+@cols+'InvDocDetailsID)
			
			SELECT '+@cols +CONVERT(NVARCHAR,@InvDocDetailsID)+'
			from [COM_DocCCData] with(nolock)   where  InvDocDetailsID='+CONVERT(NVARCHAR,@invID)
			PRINT @SQL
			EXEC(@SQL)
			
			select @InstAmt=ins,@IM=mnth from @tab where seq=@i
			
			INSERT INTO [COM_DocNumData] ([InvDocDetailsID])     
			values(@InvDocDetailsID)
			
			set @sql='update [COM_DocNumData] set dcNum1='+convert(nvarchar(max),@i)+',dcCalcNum1='+convert(nvarchar(max),@i)+',
			dcNum2='+convert(nvarchar(max),@InstAmt)+',dcCalcNum2='+convert(nvarchar(max),@InstAmt)+'
			where [InvDocDetailsID]='+convert(nvarchar(max),@InvDocDetailsID)
			PRINT @SQL
			exec (@sql)
			
			SET @SQL='INSERT INTO [COM_DocTextData] ([InvDocDetailsID],dcAlpha1,dcAlpha2,dcAlpha3,dcAlpha4,dcAlpha5,dcAlpha6)     
			values('+CONVERT(NVARCHAR,@InvDocDetailsID)+','''+CONVERT(NVARCHAR(MAX),@tot)+''','''+CONVERT(NVARCHAR(MAX),@tot)+''','''+CONVERT(NVARCHAR(MAX),@InstAmt)+''','''+CONVERT(NVARCHAR(MAX),@NoOfins)+''',CONVERT(nvarchar,'''+CONVERT(NVARCHAR(MAX),@dMStart)+''',100),CONVERT(nvarchar,'''+CONVERT(NVARCHAR(MAX),@IM)+''',100))'
			exec (@sql)	
					
		END
COMMIT TRANSACTION
SET NOCOUNT OFF;         
END TRY      
BEGIN CATCH  
 ROLLBACK TRANSACTION    
 SET NOCOUNT OFF      
 RETURN -999       
END CATCH 

----spDOC_SetOpeningLoan
--40055,2857,17185,0,0,'2022-06-08 00:00:00.000',1,'admin',1,1
GO
