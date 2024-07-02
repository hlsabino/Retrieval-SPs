USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetPoleDisplayDetails]
	@PoleID [int] = 0,
	@DocumentID [int],
	@PortID [int],
	@PortName [nvarchar](100),
	@DisplayName [nvarchar](max),
	@NoOfLines [int],
	@CharactersPerLine [int],
	@CashDrawerPort [int],
	@CashDrawerPortName [nvarchar](100),
	@CashDrawerCommand [nvarchar](100),
	@IdleMessage [nvarchar](max),
	@ProductScan [nvarchar](max),
	@BillPay [nvarchar](max),
	@OnExitXML [nvarchar](max),
	@Registers [nvarchar](max),
	@CashDrawPrintID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY   
SET NOCOUNT ON  

	declare @DT float,@XML XML
	
	
	Set @DT=convert(float,getdate())
	if(@PoleID=0)
	BEGIN
		if exists(select * from ADM_PoleDisplay WITH(NOLOCK) where DisplayName=@DisplayName)
		begin
			RAISERROR('-112',16,1)
			
		end
		
		insert into ADM_PoleDisplay(DocumentID,PortID,PortName,DisplayID,DisplayName,NoOfLines,CharactersPerLine,CashDrawerPort,CashDrawerName,CashDrawerCommand,CashDrawPrintID,IdleMessageXML,ProductScanXML,BillPayXML,OnExitXML,GUID,Createdby,CreatedDate,ModifiedBy,ModifiedDate)
					values(@DocumentID,@PortID,@PortName,0,@DisplayName,@NoOfLines,@CharactersPerLine,@CashDrawerPort,@CashDrawerPortName,@CashDrawerCommand,@CashDrawPrintID,@IdleMessage,@ProductScan,@BillPay,@OnExitXML,newid(),@UserID,@DT,@UserID,@DT)
		
		set @PoleID=Scope_Identity()
		
	END
	ELSE
	BEGIN
		update ADM_PoleDisplay
			   set NoOfLines=@NoOfLines,CharactersPerLine=@CharactersPerLine,IdleMessageXML=@IdleMessage,ProductScanXML=@ProductScan,BillPayXML=@BillPay,OnExitXML=@OnExitXML,
				  PortName=@PortName, CashDrawerPort=@CashDrawerPort,CashDrawerName=@CashDrawerPortName,CashDrawerCommand=@CashDrawerCommand,CashDrawPrintID=@CashDrawPrintID
			   where PoleID=@PoleID
	END
	set @XML=@Registers
	
	if exists(select * from ADM_PoleDisplayRegisters WITH(NOLOCK) where PoleID=@PoleID)
	begin
		delete from ADM_PoleDisplayRegisters where PoleID=@PoleID
	end

	if(@PoleID <> 0)
	BEGIN
		insert into ADM_PoleDisplayRegisters(PoleID,NodeID,CostCenterID,GUID,Createdby,CreatedDate,ModifiedBy,ModifiedDate)
				select @PoleID,X.value('@Registers','INT'),X.value('@CostCenterID','INT'),newid(),@UserID,@DT,@UserID,@DT from @XML.nodes('Registers/Rows') as Data(X)
	END
	
	
COMMIT TRANSACTION  
SET NOCOUNT OFF;
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID     
RETURN @PoleID
END TRY  
BEGIN CATCH    
 IF ERROR_NUMBER()=50000  
 BEGIN  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID   
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
