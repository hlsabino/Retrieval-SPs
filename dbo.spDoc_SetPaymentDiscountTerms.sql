USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_SetPaymentDiscountTerms]
	@Name [nvarchar](50),
	@ID [nvarchar](50),
	@Dim [int] = null,
	@TermXML [nvarchar](max) = NULL,
	@CompanyGUID [varchar](50),
	@GUID [varchar](50),
	@CreatedBy [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  

	declare @XML xml,@Dt float,@RowCount int
	set @XML=@TermXML
	set @Dt=convert(float,getdate())
	
	if(@ID='-1')
	begin
		declare @ccid int,@RetVal int
		select @ccid=value from ADM_GlobalPreferences WITH(NOLOCK) 
		where Name='PaytermLinkDim' and ISNUMERIC(value)=1
		
		if(@ccid is not null and @ccid>50000)
		BEGIN
			declare @CCStatusID int
			select  @CCStatusID =statusid from com_status with(nolock) 
			where costcenterid=@ccid and [status] = 'Active'

			EXEC @RetVal = [dbo].[spCOM_SetCostCenter]
				@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
				@Code = @Name,
				@Name = @Name,
				@AliasName='',
				@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
				@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
				@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
				@CostCenterID = @ccid,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@CreatedBy,@RoleID=1,@UserID=1,
				@CodePrefix='',@CodeNumber='',
				@CheckLink = 0,@IsOffline=0
		END
		
		insert into Acc_PaymentDiscountProfile (ProfileName,DimCCID,DimNodeID,[GUID],CreatedBy ,CreatedDate)
		values (@Name,@ccid,@RetVal,newid(),@CreatedBy,@Dt)
		set @RowCount=scope_identity()
	end
	else
	begin
		set @RowCount=@ID
	end

	if exists(select * from Acc_PaymentDiscountTerms with(nolock) where ProfileID=@RowCount)
	begin
	   delete from Acc_PaymentDiscountTerms where ProfileID=@RowCount
	end

	if(@TermXML is not null and @TermXML<>'')
	begin
		INSERT INTO  Acc_PaymentDiscountTerms (ProfileID,percentage,[Days],Discount
		,[GUID],CreatedBy,CreatedDate,Period,TypeID,BasedOn,Occurences,DateNo,Remarks,Remarks1,DimCCID,DimNodeID)  
		SELECT  @RowCount,X.value('@percentage','FLOAT'),X.value('@Days','FLOAT'),X.value('@Discount','FLOAT'),newid(),@CreatedBy,@Dt  
		,isnull(X.value('@Period','int'),1),X.value('@TypeID','int'),isnull(X.value('@BasedOn','int'),1)
		,X.value('@Occurences','int'),isnull(X.value('@DateNo','int'),0),X.value('@Remarks','nvarchar(max)'),X.value('@Remarks1','nvarchar(max)'),@Dim,X.value('@Dim','INT')
		FROM @XML.nodes('/Row') as Data(X) 
	end	

COMMIT TRANSACTION   
SET NOCOUNT OFF;	
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=1  
RETURN 1  
END TRY  
BEGIN CATCH    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE()    
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999  
  END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
