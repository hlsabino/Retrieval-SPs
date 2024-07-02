USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOc_SaveBudgetDocs]
	@Budgetxml [nvarchar](max),
	@INVDocDetailsID [bigint],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY      
SET NOCOUNT ON;  

		
		Declare @DocID bigint,@costcenterid int,@VoucherNo nvarchar(200),@DocPrefix nvarchar(200),@dt datetime,@DocNumber nvarchar(50)
		declare @xml xml,@DocAbbr nvarchar(200),@DocumentTypeID bigint,@DocumentType int,@DocOrder int,@creatdt float,@GUID nvarchar(max)
		
		set @xml=@Budgetxml
		
		select  @costcenterid=X.value('@BudgetDoc','int')
		from @xml.nodes('/DynPromXML') as Data(X)
		
		if(@costcenterid is null or @costcenterid<40000)
			RAISERROR('-101',16,1)
			
							
		if exists(SELECT INVDocDetailsID FROM  [INV_DocDetails]  WITH(NOLOCK)    
		WHERE refccid=300 and refnodeid=@INVDocDetailsID)
		BEGIN
			delete T from [COM_DocNumData] T
			join INV_DocDetails I on T.INVDocDetailsID=I.INVDocDetailsID
			where RefCCID=300 and RefNodeid=@INVDocDetailsID
			
			delete T from [COM_DocTextData] T
			join INV_DocDetails I on T.INVDocDetailsID=I.INVDocDetailsID
			where RefCCID=300 and RefNodeid=@INVDocDetailsID
			
			delete T from [COM_DocCCData] T
			join INV_DocDetails I on T.INVDocDetailsID=I.INVDocDetailsID
			where RefCCID=300 and RefNodeid=@INVDocDetailsID
			
			delete from INV_DocDetails
			where RefCCID=300 and RefNodeid=@INVDocDetailsID
		END
		
		SELECT @GUID=newid(),@creatdt=CONVERT(float,getdate()),@DocumentTypeID=DocumentTypeID,@DocumentType=DocumentType,@DocAbbr=DocumentAbbr,@DocOrder=DocOrder
		FROM ADM_DocumentTypes WITH(NOLOCK) WHERE CostCenterID=@CostCenterID  
		

		
			EXEC [sp_GetDocPrefix] '',@creatdt,@costcenterid,@DocPrefix output,@INVDocDetailsID
			
			
			if  NOT EXISTS(SELECT CurrentCodeNumber FROM COM_CostCenterCodeDef  WITH(NOLOCK) WHERE CostCenterID=@costcenterid AND CodePrefix=@DocPrefix)    
			begin    
				INSERT INTO COM_CostCenterCodeDef(CostCenteriD,FeatureiD,CodePrefix,CodeNumberRoot,CodeNumberInc,CurrentCodeNumber,CodeNumberLength,GUID,CreatedBy,CreatedDate,Location,Division)    
				VALUES(@costcenterid,@costcenterid,@DocPrefix,1,1,1,1,Newid(),@UserName,convert(float,getdate()),0,0)    
				 set @DocNumber='1'
			end    
			ELSE
			BEGIN
				SELECT  @DocNumber=ISNULL(CurrentCodeNumber,0)+1 FROM COM_CostCenterCodeDef WITH(NOLOCK) --AS CurrentCodeNumber    
				WHERE CostCenterID=@costcenterid AND CodePrefix=@DocPrefix 
			END
		    
		    
			SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')    
  
			while exists (select DocNo from COM_DocID with(nolock) where DocNo=@VoucherNo)
			begin			
				SET @DocNumber=@DocNumber+1
				SET @VoucherNo=isnull(@DocAbbr,'')+'-'+isnull(@DocPrefix,'')+isnull(@DocNumber,'')
			end
			
			INSERT INTO COM_DocID(DocNo,[CompanyGUID],[GUID])
			VALUES(@VoucherNo,@CompanyGUID,@GUID)
			SET @DocID=@@IDENTITY
				
			UPDATE COM_CostCenterCodeDef     
			SET CurrentCodeNumber=@DocNumber    
			WHERE CostCenterID=@costcenterid AND CodePrefix=@DocPrefix    
			
		 
				
				INSERT INTO INV_DocDetails    
				 ([DocID]    
				 ,[CostCenterID]    
				   
				 ,[DocumentType],DocOrder   ,[VoucherType] 
				 ,[VersionNo]    
				 ,[VoucherNo]    
				 ,[DocAbbr]    
				 ,[DocPrefix]    
				 ,[DocNumber]    
				 ,[DocDate]    
				 ,[DueDate]    
				 ,[StatusID]    				   
				 ,[BillNo]    
				 ,BillDate                 
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
				 ,[CreatedDate] ,[ModifiedBy]  
				 ,[ModifiedDate],WorkflowID , WorkFlowStatus , WorkFlowLevel,RefCCID ,RefNodeid
				 ,[Description])    
		          
				SELECT @DocID    
				 , @CostCenterID    
				
				 , @DocumentType,@DocOrder ,1  
				 , 1  
				 , @VoucherNo    
				 , @DocAbbr    
				 , @DocPrefix    
				 , @DocNumber    
				 , CONVERT(FLOAT, X.value('@DocDate','Datetime'))    
				 , DueDate
				 , StatusID 
				, BillNo
				 ,BillDate
				 ,CommonNarration
				 ,LineNarration
				 ,[DebitAccount]    
				 ,[CreditAccount]
				 ,1
				 ,[ProductID]      
				,1      
				,[Unit]      
				,[HoldQuantity]    
				,[ReserveQuantity]     
				,[ReleaseQuantity]    
				,[IsQtyIgnored]      
				,[IsQtyFreeOffer]      
				, X.value('@Amount','float')/ExchangeRate              
				,[AverageRate]      
				, X.value('@Amount','float')/ExchangeRate       
				,[StockValue]     				
				 , CurrencyID
				 , ExchangeRate
				 , X.value('@Amount','float') ,0				 
				 , @UserName    
				 , @creatdt, @UserName    
				 , @creatdt,WorkflowID , WorkFlowStatus , WorkFlowLevel,300,@INVDocDetailsID
				 ,null				 
				 from @xml.nodes('/DynPromXML/Row') as Data(X) ,INV_DocDetails WITH(NOLOCK)
				  where INVDocDetailsID=@INVDocDetailsID  
				    
				  
				  INSERT INTO [COM_DocNumData] ([INVDocDetailsID])     
				  select [INVDocDetailsID] from INV_DocDetails WITH(NOLOCK)
				  where RefCCID=300 and RefNodeid=@INVDocDetailsID  
			  
				  INSERT INTO [COM_DocTextData]([INVDocDetailsID])
				    select [INVDocDetailsID] from INV_DocDetails WITH(NOLOCK)
				  where RefCCID=300 and RefNodeid=@INVDocDetailsID  
			  
			  declare @cols nvarchar(max)
			set @cols=''
			select @cols=@cols+name+',' from sys.columns
			where object_id('COM_DocCCData')=object_id
			and name like 'dcCCNID%'
			select @cols
				  
				 set @cols=' INSERT INTO [COM_DocCCData] ('+@cols+'INVDocDetailsID )    
				  SELECT     '+@cols+'b.INVDocDetailsID    
				  from [COM_DocCCData] a with(nolock),INV_DocDetails b WITH(NOLOCK)
				  where RefCCID=300 and RefNodeid='+convert(nvarchar(max),@INVDocDetailsID )+'  
					and  a.INVDocDetailsID ='+convert(nvarchar(max),@INVDocDetailsID )
					exec(@cols)
				  
				 

COMMIT TRANSACTION
   
SET NOCOUNT OFF;      
RETURN 1      
END TRY      
BEGIN CATCH   
	
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN    
	  SELECT ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
	  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END  
  ELSE IF ERROR_NUMBER()=1205  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-350 AND LanguageID=@LangID  
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
