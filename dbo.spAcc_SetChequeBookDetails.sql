USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAcc_SetChequeBookDetails]
	@BankAccountID [bigint],
	@GridXML [nvarchar](max),
	@TypeID [bigint],
	@CompanyGUID [varchar](50),
	@UserID [int],
	@CreatedBy [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;      
  
        declare @XML xml,@Dt float,@CurrNo nvarchar(50),@Return int,@StartingCheque bigint,@Status bigint
        declare @BookNo nvarchar(50),@CurrentNo nvarchar(50),@StartNo nvarchar(50),@EndNo nvarchar(50)
        
        set @Dt=convert(float,getdate())
        set @XML=@GridXML
        
        select @BookNo=X.value('@BookNo','nvarchar(50)'),@CurrentNo=X.value('@CurrentNo','nvarchar(50)'),@StartNo=isnull(X.value('@StartNo','nvarchar(50)'),0),
			   @Status=isnull(X.value('@Status','bigint'),0),@EndNo=isnull(X.value('@EndNo','nvarchar(50)'),0) FROM @XML.nodes('/XML/Rows') as Data(X)      
        
        if(@TypeID=0)
        BEGIN
			if exists (select * from ACC_ChequeBooks WITH(NOLOCK) where BankAccountID=@BankAccountID)
			BEGIN
				delete from ACC_ChequeBooks where BankAccountID=@BankAccountID
			END
	        
  			Insert into ACC_ChequeBooks (BankAccountID,BookNo,StartNo,EndNo,CurrentNo,CompanyGUID,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate,Status)
  			select @BankAccountID,X.value('@BookNo','nvarchar(50)'),X.value('@StartNo','nvarchar(50)'),X.value('@EndNo','nvarchar(50)'),X.value('@CurrentNo','nvarchar(50)'),
				   @CompanyGUID,newid(),@UserID,@Dt,@UserID,@Dt,isnull(X.value('@Status','bigint'),0)  FROM @XML.nodes('/XML/Rows') as Data(X)      
			
			set @Return=1
		END 	
		ELSE
		BEGIN
			if exists(select * from ACC_ChequeCancelled WITH(NOLOCK) where BankAccountID=@BankAccountID  and BookNo=@BookNo and ChequeNo=@CurrentNo)
			BEGIN
				raiserror('-392',16,1)
			END
			ELSE
			BEGIN
				select @CurrNo=CurrentNo from ACC_ChequeBooks WITH(NOLOCK) where BankAccountID=@BankAccountID and BookNo=@BookNo
				IF not exists(select * from ACC_ChequeCancelled WITH(NOLOCK) where BankAccountID=@BankAccountID and BookNo=@BookNo)
				BEGIN
					set @StartingCheque=1
				END
				ELSE
				BEGIN
					set @StartingCheque=0
				END
				
				Insert into ACC_ChequeCancelled (BankAccountID,BookNo,ChequeNo,CompanyGUID,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
				select @BankAccountID,@BookNo,@CurrentNo,@CompanyGUID,newid(),@UserID,@Dt,@UserID,@Dt 
					  
				IF(@CurrentNo=@CurrNo)
				BEGIN
					IF(@StartingCheque=1)
					BEGIN
						set @CurrentNo = REPLACE(@CurrentNo,CONVERT(BIGINT,@CurrentNo),'')+CONVERT(NVARCHAR,(@CurrentNo+1))
					END
					ELSE
					BEGIN
						set @CurrentNo = REPLACE(@CurrentNo,CONVERT(BIGINT,@CurrentNo),'')+CONVERT(NVARCHAR,(@CurrentNo+1))
						while exists(select ChequeNo from ACC_ChequeCancelled WITH(NOLOCK) where BankAccountID=@BankAccountID and BookNo=@BookNo and ChequeNo=@CurrentNo)
						BEGIN
							set @CurrentNo = REPLACE(@CurrentNo,CONVERT(BIGINT,@CurrentNo),'')+CONVERT(NVARCHAR,(@CurrentNo+1))
						END
					END
					update ACC_ChequeBooks
					set CurrentNo=@CurrentNo	  
					where BankAccountID=@BankAccountID and BookNo=@BookNo
					set @Return=@CurrentNo
				END
				ELSE
				BEGIN
					Select @Return=CurrentNo from ACC_ChequeBooks WITH(NOLOCK) where BankAccountID=@BankAccountID and BookNo=@BookNo
				END
			END	   
	   END
COMMIT TRANSACTION          
SET NOCOUNT OFF;       
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID        
RETURN @Return
END TRY        
BEGIN CATCH        
 IF ERROR_NUMBER()=-392      
 BEGIN          
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END      
 ELSE IF ERROR_NUMBER()=50000      
 BEGIN          
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END 
  ELSE    
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID      
 END      
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
END CATCH   
GO
