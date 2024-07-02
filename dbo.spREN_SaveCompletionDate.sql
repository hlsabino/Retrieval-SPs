USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SaveCompletionDate]
	@PropXml [nvarchar](max),
	@dt [datetime],
	@TowerCCID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY         
SET NOCOUNT ON  

		declare @Sql nvarchar(max),@xml xml,@CostCenterID bigint,@I int,@Cnt int
		declare @Columnname nvarchar(100),@vno nvarchar(200),@docid bigint
		set @xml=@PropXml
		
		declare @tblList table(ID int identity(1,1),docid bigint,ccid bigint,vno nvarchar(200))  
		
		insert into @tblList  
		SELECT X.value('@ID','bigint')  , X.value('@CostCenterID','bigint')  , X.value('@VNO','NVARCHAR(200)') 
		from @xml.nodes('/XML/Row') as Data(X)   
		
		SELECT @I=0, @Cnt=count(*) FROM @tblList       
       

WHILE(@I<@Cnt)        
BEGIN      
	SET @I=@I+1    
    
	SELECT  @docid=docid,@CostCenterID=ccid,@vno=vno FROM @tblList  WHERE ID=@I        
  

	select @Columnname=PrefValue from COM_DocumentPreferences
	where CostCenterID=@CostCenterID and PrefName='Paymenttermsbasedon'
	and PrefValue<>''
	 
	 if(@Columnname is not null and @Columnname like 'dcAlpha%')
	 begin
		 set @Sql='update COM_DocTextData
		 set '+@Columnname+'='''+convert(nvarchar,@dt)+''' 
		  where invDocDetailsID in (select invDocDetailsID from INV_DocDetails
		 where DocID='+convert(nvarchar,@DocID)+')'	 
 		 exec (@Sql)
	 end 
	 else if(@Columnname is not null)
	 begin
		 set @Sql='update INV_DocDetails 
		 set '+@Columnname+'='''+convert(nvarchar,CONVERT(float,@dt))+''' 
		 where DocID='+convert(nvarchar,@DocID)
 		 exec (@Sql)
	 end 
	 
	 update COM_DocPayTerms
	 set BaseDate=CONVERT(float,@dt),DueDate=convert(float, DATEADD(Day,days,@dt))
	 where VoucherNo=@vno and BasedOn=2 and Period=1
	 
	 update COM_DocPayTerms
	 set BaseDate=CONVERT(float,@dt),DueDate=convert(float, DATEADD(MONTH,days,@dt))
	 where VoucherNo=@vno and BasedOn=2 and Period=2
 
 END
		
	select @Columnname=Value from COM_CostCenterPreferences
	where CostCenterID=106 and Name='PaymentTermCompletionDate'
	and Value<>''
	
	select @CostCenterID=Value from COM_CostCenterPreferences
	where CostCenterID=92 and Name='LinkDocument'
	and Value<>'' and ISNUMERIC(Value)=1
	
	select @vno=TableName from ADM_Features
	where FeatureID=@CostCenterID
	set @DocID=0
	
	set @Sql='select @DocID=NodeID from REN_Property 
	where Code=(select Code from '+@vno+' where NodeID='+convert(nvarchar,@TowerCCID)+')'
 
	EXEC sp_executesql @Sql,N'@DocID bigint OUTPUT',@DocID output
	
	
	if(@Columnname is not null and @Columnname like 'Alpha%')
	begin
		set @Sql='update REN_PropertyExtended
		set '+@Columnname+'='''+convert(nvarchar,@dt)+''' 
		where NodeID='+convert(nvarchar,@DocID)		
		exec (@Sql)
	END
	else if(@Columnname is not null)
	begin
		set @Sql='update REN_Property
		set '+@Columnname+'='''+convert(nvarchar,CONVERT(float,@dt))+''' 
		where NodeID='+convert(nvarchar,@DocID)
		exec (@Sql)
	end 
 
	 
COMMIT TRANSACTION        
	
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  		
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS          
ErrorLine        
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
 END        
ROLLBACK TRANSACTION        
SET NOCOUNT OFF          
RETURN -999           
END CATCH     
GO
