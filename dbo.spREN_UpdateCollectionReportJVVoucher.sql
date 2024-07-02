USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_UpdateCollectionReportJVVoucher]
	@Date [datetime],
	@DocumentXML [nvarchar](max),
	@MapIDs [nvarchar](max),
	@AccIDs [nvarchar](max),
	@LocationID [int] = 0,
	@divisionID [int] = 0,
	@RoleID [int] = 0,
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100), @XML xml,@wid int 
BEGIN TRY      
select 1
SET NOCOUNT ON;   
	
	
 
	DECLARE @return_value INT,@Prefix nvarchar(200),@sql nvarchar(max),@Vno nvarchar(200),@CostCenterID INT ,@ActXml nvarchar(max)         
	
	set @ActXml='<XML SysInfo="'+@sysinfo+'" AP="'+@AP+'" ></XML>'   

	set @CostCenterID=0
	select @CostCenterID=Value from com_costcenterpreferences
	where costcenterid = 95 and Name  = 'CashCollectionJV'
	and ISNUMERIC(Value)=1
	
	if(@CostCenterID<40000)
		set @CostCenterID=40017
		
	   SELECT  @wid=isnull(a.[WorkFlowID],0) FROM [COM_WorkFlowDef]  a   WITH(NOLOCK)
	   join COM_WorkFlow b WITH(NOLOCK) on a.WorkFlowID=b.WorkFlowID  and a.LevelID=b.LevelID
	   LEFT JOIN COM_Groups G with(nolock) on b.GroupID=G.GID
	   where [CostCenterID]=@CostCenterID and IsEnabled=1  
	   and (b.UserID =@UserID or b.RoleID=@RoleID or G.UserID=@UserID or G.RoleID=@RoleID OR b.RoleID=-1)  
    	
     set @Prefix=''
     EXEC [sp_GetDocPrefix] @DocumentXML,@Date,@CostCenterID,@Prefix   output

	 
	  EXEC @return_value = [dbo].spDOC_SetTempAccDocument      
	   @CostCenterID = @CostCenterID,      
	   @DocID = 0,      
	   @DocPrefix = @Prefix,      
	   @DocNumber =1,      
	   @DocDate = @Date,      
	   @DueDate = NULL,      
	   @BillNo = '',      
	   @InvDocXML = @DocumentXML,      
	   @NotesXML = N'',      
	   @AttachmentsXML = N'',      
	   @ActivityXML  = @ActXml,     
	   @IsImport = 0,      
	   @LocationID = @LocationID,      
	   @DivisionID = @divisionID,      
	   @WID = @wid,      
	   @RoleID = @RoleID,      
	   @RefCCID = 0,    
	   @RefNodeid = 0 ,    
	   @CompanyGUID = @CompanyGUID,      
	   @UserName = @UserName,      
	   @UserID = @UserID,      
	   @LangID = @LangID  

		select  @Vno=VOUCHERNO  from ACC_DocDetails 
		where DocID =  @return_value
		
		if(@MapIDs<>'')
			BEGIN
			set @sql='update ren_contractdocmapping set JVVoucherNO ='''+@Vno+''' 
			where mapid in( ' + @MapIDs + ')'
			exec(@sql)
			
			
			
			 set @sql=' INSERT INTO [REN_CollectionHistory]([DocID],[CostCenterID],[ContractCCID],[ReceiveDate],jvvoucherno,[DocDetID]
			 ,CreatedBy,CreatedDate)
			select [DocID],[CostCenterID],[ContractCCID],[ReceiveDate],jvvoucherno,
			case when [DocDetID] is null then (select top 1 ACCDocDetailsID from ACC_DocDetails where DocID=ren_contractdocmapping.DocID)
			else [DocDetID] end
			 ,'''+@UserName+''',convert(float,getdate()) from ren_contractdocmapping
 			where mapid in( ' + @MapIDs + ')'
	 		
 			print @sql
 			exec(@sql)
 		END
 		
 		if(@AccIDs!='')
 		BEGIN	
 			set @XML=@AccIDs
 			
 			INSERT INTO  [REN_ContractDocMapping]([ContractID],[Type],[Sno],DocID,CostcenterID,IsAccDoc,DocType,ContractCCID,ReceiveDate,DocDetID,JVVoucherNO)
			SELECT distinct -1,10,0,a.docid,a.CostcenterID,1,a.DocumentType,95,CONVERT(float,x.value('@ReceiveDate','DateTime')),x.value('@DocDetailsID','INT'),@Vno
			FROM @XML.nodes('/XML/Row') as Data(X)   
			join  ACC_DocDetails a on x.value('@DocDetailsID','INT') = a.AccDocDetailsID
 		END
 		
 			
COMMIT TRANSACTION     
   
 SELECT @Vno VOUCHERNO,ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;   
   
RETURN @return_value      
END TRY      
BEGIN CATCH 
 if(@return_value is null or  @return_value<>-999)   
 BEGIN        
IF ERROR_NUMBER()=50000  
 BEGIN  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
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
 END
 SET NOCOUNT OFF      
 RETURN -999       
  
  
END CATCH 

GO
