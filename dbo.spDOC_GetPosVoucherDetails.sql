USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetPosVoucherDetails]
	@vno [nvarchar](200),
	@CCID [int],
	@UserID [int],
	@LangID [int] = 1,
	@VoucherDate [datetime] = null
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON
		
		declare @Sql NVARCHAR(MAX),@TABLE NVARCHAR(max),@NodeID INT,@amt Float,@par nvarchar(200),@stat int,@used float,@wef nvarchar(200),@till nvarchar(200)
		declare @Percentage Float, @ActualAmount Float, @MinAmount Float
		
		select @table=tablename from adm_features WITH(NOLOCK) where featureid=@CCID

		
			SET @Sql='Select @NodeID=NodeID,@Percentage=convert(float,ccalpha43),@MinAmount=convert(float,ccalpha42),@amt=convert(float,ccalpha50),@par=ccalpha46,@stat=StatusID from '+@table+' where name=''' + @vno + ''' and isnumeric(ccalpha50)=1'
			EXEC sp_executesql @SQL,N'@NodeID INT OUTPUT,@Percentage Float OUTPUT,@MinAmount Float OUTPUT,@amt Float OUTPUT,@par nvarchar(200) output,@stat int OUTPUT',@NodeID output,@Percentage output,@MinAmount output,@amt output,@par output,@stat output
		
				select @used=isnull(SUM(Amount),0)
				from COM_PosPayModes WITH(NOLOCK) 
				where VoucherNodeID=@NodeID  and VoucherType=-1

				set @ActualAmount = @amt
		
			if(@NodeID>0 and exists(select statusid from com_status WITH(NOLOCK) where featureid=@CCID and statusid=@stat and status='active'))
			BEGIN			
			
				if not exists(select * from COM_PosPayModes WITH(NOLOCK) where VoucherNodeID=@NodeID  and VoucherType=1)
				BEGIN
					if((@par='0' or @par='NO' or @par='N') and @used>0)
						set @amt=0
				
					SET @Sql='select @wef=ccalpha45,@till=ccalpha47 from '+@table+' with(nolock) where NodeID='+convert(nvarchar(max), @NodeID) 
					EXEC sp_executesql @SQL,N'@wef nvarchar(200) OUTPUT,@till nvarchar(200) OUTPUT',@wef output,@till output
					if(isdate(@wef)=1 and convert(datetime,@wef)>convert(datetime,@VoucherDate))
						raiserror('Voucher can not be used now',16,1)
					if(isdate(@till)=1 and convert(datetime,@till)< convert(datetime,@VoucherDate))
						raiserror('Voucher expired',16,1)	
				END
			END
			ELSE
				raiserror('Invalid voucher',16,1)
		
			if(@used is not null and @used>0)
			BEGIN
				if(@amt>@used)
					set @amt=@amt-@used
				else
					set @amt=0
			END
			
			select @amt BAL, @Percentage [Percentage], @ActualAmount ActualAmount, @MinAmount MinAmount
			
	
SET NOCOUNT OFF;
RETURN @NodeID
END TRY
BEGIN CATCH  
		--Return exception info [Message,Number,ProcedureName,LineNumber] 
		IF ISNUMERIC(ERROR_MESSAGE())<>1
		BEGIN
			SELECT ERROR_MESSAGE() ErrorMessage
		END 
		ELSE IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
		END
		ELSE
		BEGIN
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
		END

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
