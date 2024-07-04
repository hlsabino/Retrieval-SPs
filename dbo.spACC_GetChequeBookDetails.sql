USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetChequeBookDetails]
	@BankAccountID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

	 IF(@BankAccountID = 0)
	 BEGIN
		select * from acc_accounts with(nolock) where accounttypeid in (2,3) and isgroup=0 order by accountname
	 END
	 ELSE
	 BEGIN
		
		declare @CancelledCheque nvarchar(max),@i bigint,@cnt bigint,@Chequeno nvarchar(50),@count bigint
		declare @book nvarchar(500) , @j int 
		declare @table table(ID bigint identity(1,1),ChequeNo nvarchar(50),bookno nvarchar(500),AccountID bigint) 
		declare @Counttable table(ID bigint identity(1,1),bookno nvarchar(500)) 
		
		declare @Finaltable table(ID bigint identity(1,1) ,ChequeNo nvarchar(500),bookno nvarchar(500),AccountID bigint) 
		
		
		insert into @table
		select ChequeNo,bookno,BankAccountID from ACC_ChequeCancelled with(nolock) 
		where bookno in (select bookno from  ACC_ChequeBooks with(nolock) where BankAccountID=@BankAccountID)
		
		insert into @Counttable
		select distinct bookno from @table
					
		set @i=1
		set @j=1
		
		set @CancelledCheque=''
		
		select @cnt=count(ChequeNo) from @table 
		select @count = count(bookno) from @Counttable
		 
		while(@i<=@count)
		begin

			while(@j<=@cnt)
			begin
		    	select @book =  bookno from @Counttable where id = @i
		    	
				if exists( select bookno from  @table where id = @j and BookNo  = @book and AccountID=@BankAccountID) 
				begin 
					select @Chequeno=ChequeNo from @table where id=@j and bookno = @book and AccountID=@BankAccountID
					set @CancelledCheque=@CancelledCheque + ',' +convert(nvarchar,@Chequeno)
				end
				 
				set @j=@j+1
				
			END
			set @CancelledCheque=substring(@CancelledCheque,2,len(@CancelledCheque))
			
			insert into @Finaltable 
			select @book,@CancelledCheque,@BankAccountID 
			set @j = 1
			set @CancelledCheque= ''
			set @i=@i+1
		end
		select AccBook.*, TmpTbl.BookNo CancelledCheques  from ACC_ChequeBooks AccBook with(nolock)  
		left join @Finaltable  TmpTbl on AccBook.BookNo = TmpTbl.ChequeNo  
		where BankAccountID=@BankAccountID
		
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
