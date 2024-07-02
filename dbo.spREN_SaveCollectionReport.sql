USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_SaveCollectionReport]
	@CollectionXML [nvarchar](max),
	@ccid [int],
	@PropertyID [bigint],
	@Type [int],
	@Status [bigint],
	@DocStatus [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY   
SET NOCOUNT ON  
  
	declare @XML xml,@SQL nvarchar(max),@cID bigint,@Sno int,@DocType int,@userName nvarchar(50),@dt FLOAT
	if(@CollectionXML<>'')
	begin
		set @XML=@CollectionXML
		
		select @userName=UserName from ADM_Users WITH(NOLOCK) where UserID=@UserID
	    set @dt=COnvert(float,getdate())
	   
	    INSERT INTO [REN_CollectionHistory]([DocID],[CostCenterID],[ContractCCID],[ReceiveDate],[DocDetID]
	     ,CreditAccount,DebitAccount,StatusID,CreatedBy,CreatedDate)
	    select   a.docid,a.CostcenterID,95,CONVERT(float,x.value('@ReceiveDate','DateTime')),x.value('@DocDetailsID','bigint')
	    ,x.value('@CreditAccount','bigint'),x.value('@DebitAccount','bigint'),x.value('@StatusID','bigint'),@userName,@dt
		FROM @XML.nodes('/XML/Row') as Data(X)   
		join  ACC_DocDetails a on x.value('@DocDetailsID','bigint') = a.AccDocDetailsID
		
		
		set @SQL =' update COM_DocCCData
		 set dcCCNID'+CONVERT(nvarchar,@ccid)+'=x.value(''@StatusID'',''bigint'')  
		 from @XML.nodes(''/XML/Row'') as data(x)      
		 where COM_DocCCData.AccDocDetailsID is not null and  x.value(''@DocDetailsID'',''bigint'') = COM_DocCCData.AccDocDetailsID'
		print @SQL
		EXEC sp_executesql @SQL, N'@XML xml', @XML	
		
		update REN_ContractDocMapping
		set ReceiveDate=CONVERT(float,x.value('@ReceiveDate','DateTime'))  
		from @XML.nodes('/XML/Row') as data(x) 
		join  ACC_DocDetails a on x.value('@DocDetailsID','bigint') = a.AccDocDetailsID
		where a.docid=REN_ContractDocMapping.DocID and IsAccDoc=1 and  contractid>0
		
		
		update REN_ContractDocMapping
		set ReceiveDate=CONVERT(float,x.value('@ReceiveDate','DateTime'))  
		from @XML.nodes('/XML/Row') as data(x) 
		where  x.value('@DocDetailsID','bigint') = DocDetID 
		and IsAccDoc=1 and  contractid=-1
		 
		INSERT INTO  [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID,ReceiveDate,DocDetID)
		SELECT  -1,10,0,a.docid,a.CostcenterID,1,a.DocumentType,95,CONVERT(float,x.value('@ReceiveDate','DateTime')),x.value('@DocDetailsID','bigint')
		FROM @XML.nodes('/XML/Row') as Data(X)   
		join  ACC_DocDetails a on x.value('@DocDetailsID','bigint') = a.AccDocDetailsID
		where a.docid not in (select DocID from REN_ContractDocMapping where IsAccDoc=1 and DocID is not null and [ContractID]>0)
		and a.AccDocDetailsID not in (select DocDetID from REN_ContractDocMapping where [ContractID]=-1 and IsAccDoc=1 and DocDetID is not null)
		
		 declare @tab table(id int identity(1,1),CrAcc bigint,DbAcc bigint,DocDetID bigint)
		 declare @I int,@cnt int,@DbAcc bigint,@DocDetID bigint,@CrAcc bigint,@PrefValue Nvarchar(100),@DocumentType int,@BankAccountID bigint
		 insert into @tab 
		select x.value('@CreditAccount','bigint'),x.value('@DebitAccount','bigint') , x.value('@DocDetailsID','bigint')
		from @XML.nodes('/XML/Row') as data(x) 
		set @i=0
		select @cnt=count(id) from @tab
		while(@i<@cnt)
		begin
			set  @i=@i+1
			select @DbAcc=DbAcc,@DocDetID=DocDetID,@CrAcc=CrAcc from @tab where id=@i
			set @BankAccountID=NULL
			set @DocumentType=0
			select @DocumentType=DocumentType from ACC_DocDetails where AccDocDetailsID=@DocDetID
		    select @PrefValue=value from adm_globalpreferences where name='Intermediate PDC'		
			if(@PrefValue='True' and @DocumentType in(19,14))
			begin     
				if(@DocumentType =19)
				begin
					if exists(select accounttypeid from ACC_Accounts where AccountID=@DbAcc and accounttypeid in(2,3))
					begin
						set @BankAccountID=@DbAcc
						select @DbAcc=PDCReceivableAccount from ACC_Accounts where AccountID=@DbAcc
						 IF(@DbAcc is null or @DbAcc <=1)
							RAISERROR('-365',16,1)
										
					end
				end
				else
				begin
					if exists(select accounttypeid from ACC_Accounts where AccountID=@CrAcc and accounttypeid in(2,3))
					begin
						set @BankAccountID=@CrAcc
						select @CrAcc=PDCPayableAccount from ACC_Accounts where AccountID=@CrAcc
						 IF(@CrAcc is null or @CrAcc <=1)
							RAISERROR('-366',16,1)				
					end
				end
			end
			
			update ACC_DocDetails
			set DebitAccount=@DbAcc,BankAccountID=@BankAccountID			
			where AccDocDetailsID =@DocDetID
			set @DocType=0
			select @DocType=DocType,@cID=ContractID,@Sno=Sno from REN_ContractDocMapping where  IsAccDoc=1 and DocID=(select DocID from ACC_DocDetails where AccDocDetailsID =@DocDetID)
			if(@DocType =3)
			begin
				if(@PrefValue='True' and @DocumentType =19)
                BEGIN
                	update REN_ContractParticulars
					set DebitAccID=@BankAccountID
					where ContractID=@cID and  Sno=@Sno
                END
                ELSE
				BEGIN
					update REN_ContractParticulars
					set DebitAccID=@DbAcc
					where ContractID=@cID and  Sno=@Sno
				END	
			end
			else if(@DocType in (1,2))
			begin
				if(@PrefValue='True' and @DocumentType=19)
                BEGIN				
					 update REN_ContractPayTerms
					 set DebitAccID=@BankAccountID
					 where ContractID=@cID and  Sno=@Sno
				END
				ELSE
				BEGIN
					update REN_ContractPayTerms
					 set DebitAccID=@DbAcc
					 where ContractID=@cID and  Sno=@Sno
				END	 
			end
		end	
    end
    exec spREN_GetPropertyDetails @PropertyID,@Type,@Status,@DocStatus,@UserID,@LangID 
    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=100 AND LanguageID=@LangID

COMMIT TRANSACTION  
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
