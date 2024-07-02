USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_ValidateChequeNo]
	@AccountID [bigint] = 0,
	@DocDetID [int],
	@Typeid [int] = 0,
	@ChequeNo [nvarchar](50),
	@ChequeBookNo [nvarchar](50),
	@RefCCID [bigint],
	@RefNodeid [bigint],
	@CostCenterID [int],
	@DocID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE  @Exists bit, @cnt nvarchar(500),@RefNID BIGINT,@SectionID int,@sql nvarchar(max)
		
		select @SectionID=SectionID from adm_costcenterdef
		where CostCenterID=@CostCenterID and SysColumnName='ChequeNumber'
		
		select @RefNID=RefNodeID from Acc_DocDetails  WITH(NOLOCK) 
		where AccDocDetailsID =@DocDetID 
		if(@RefNID is null)
			set @RefNID=0
	 
	 	 
		set @sql='select @cnt=voucherno from Acc_DocDetails  WITH(NOLOCK) '
		if(@Typeid=14 or @Typeid=15)
			set @sql=@sql+'where documenttype in(14,15) and (CreditAccount='+convert(nvarchar,@AccountID)+' or BankAccountID='+convert(nvarchar,@AccountID) 
		else if (@Typeid=18 or @Typeid=19)
			set @sql=@sql+'where documenttype in(18,19) and (DebitAccount='+convert(nvarchar,@AccountID)+' or BankAccountID='+convert(nvarchar,@AccountID) 
		ELSE 
		BEGIN
			set @Exists=0
			return 0
		END
		set @sql=@sql+') and replace(chequenumber,'' '','''')=replace('''+@ChequeNo+''','' '','''') '
		if (@ChequeBookNo is not null and @ChequeBookNo <>'')
			set @sql=@sql+' and replace(ChequeBookNo,'' '','''')=replace('''+@ChequeBookNo+''','' '','''') '
		else
			set @sql=@sql+' and (ChequeBookNo is null or ChequeBookNo='''') '
		set @sql=@sql+' and statusid<>447 and statusid<>376  and statusid<>429 '
		if(@RefNodeid is not null and @RefNodeid<>0)
			set @sql=@sql+' and AccDocDetailsID <>'+convert(nvarchar,@RefNodeid)
		if(@RefNID is not null and @RefNID<>0)
			set @sql=@sql+' and AccDocDetailsID <>'+convert(nvarchar,@RefNID  )
		if(@DocDetID is not null and @DocDetID<>0)
			set @sql=@sql+' and AccDocDetailsID <>'+convert(nvarchar,@DocDetID)+' and RefNodeID<> '+convert(nvarchar,@DocDetID) 
		if(@DocID is not null and @DocID<>0 and @SectionID<>3)				
			set @sql=@sql+' and DOCID <>'+convert(nvarchar,@DocID) 
		print @sql
		exec sp_executesql @sql,N'@cnt nvarchar(500) output',@cnt output	 
		 
		if(@cnt is not null and @cnt <>'')
			RAISERROR('-359',16,1)  
			
		
 

SET NOCOUNT OFF;
RETURN @Exists
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		IF (ERROR_MESSAGE() LIKE '-359' )
		BEGIN			
			SELECT    ERROR_MESSAGE(),ErrorMessage+ @cnt  ErrorMessage, ERROR_MESSAGE() AS ServerMessage,
			ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE() as ProcedureName, ERROR_LINE() AS ErrorLine  FROM COM_ErrorMessages WITH(nolock)  
			WHERE ErrorNumber=-359 AND LanguageID=@LangID  
		END 
		ELSE
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages  WITH(NOLOCK)  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages  WITH(NOLOCK)  WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH   
GO
