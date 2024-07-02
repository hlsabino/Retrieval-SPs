USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_PostDeprJV]
	@AssetID [bigint],
	@COSTCENTERID [bigint],
	@JVXML [nvarchar](max) = NULL,
	@Post [bit],
	@CompanyGUID [nvarchar](50),
	@GUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
DECLARE @QUERYTEST NVARCHAR(100)  , @IROWNO NVARCHAR(100) , @TYPE NVARCHAR(100)      
BEGIN TRY          
SET NOCOUNT ON;  
DECLARE   @XML XML ,@DXML XML , @CNT INT , @ICNT INT , @AA XML, @DocXml nvarchar(max) , @return_value BIGINT ,@DT datetime,@DT_INT INT,@Vendor bigint,@PN nvarchar(50)  
DECLARE @DEPID BIGINT ,@DEPIDXML XML,  @VOUCHERNO NVARCHAR(200) ,@DocDate float ,@STATUSID INT  , @AssetNetValue FLOAT, @ScheduleID BIGINT,@DoXML xml,@AssetOldValue Float  
DECLARE @MPSNO NVARCHAR(MAX),@ChangeValue float,@Prefix nvarchar(200),@DeprPostDate nvarchar(50)
  
  
  IF(@Post = 1)  
  BEGIN  
   IF(@JVXML is not null and @JVXML<>'')    
     BEGIN     
    SET @XML =   @JVXML     
           
     CREATE TABLE #tblListJVPost(ID int identity(1,1),TRANSXML NVARCHAR(MAX), DEPIDXML NVARCHAR(MAX))        
     INSERT INTO #tblListJVPost      
     SELECT  CONVERT(NVARCHAR(MAX),  X.query('DocumentXML'))  ,    CONVERT(NVARCHAR(100),  X.query('DepreciationID'))          
     from @XML.nodes('/JVXML/ROWS') as Data(X)      
         
     SELECT @CNT = COUNT(ID) FROM #tblListJVPost    
        
     Set @DT=getdate()   
     set @DT_INT=floor(convert(float,@DT)) 
     select @DeprPostDate=Value from com_costcenterpreferences with(nolock) where costcenterid=72 and Name='AssetDeprPostDate'
          
     SET @ICNT = 0    
    WHILE(@ICNT < @CNT)    
	BEGIN    
       SET @ICNT =@ICNT+1    
          
       SELECT @AA = TRANSXML , @DEPIDXML  = DEPIDXML  FROM #tblListJVPost WHERE  ID = @ICNT    
         
       SELECT @DEPID=X.value ('@DepID', 'NVARCHAR(100)' ) from @DEPIDXML.nodes('/DepreciationID') as Data(X)    
       
       if @DeprPostDate='ScheduleDate'
			select @DT_INT=DeprEndDate from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DPScheduleID=@DEPID  
         
       select  @ChangeValue= X.value ('@Amount', 'FLOAT' ) from  @AA.nodes('/DocumentXML/Row/Transactions') as Data(X)         
       select  @ChangeValue= X.value ('@Amount', 'FLOAT' ) from  @AA.nodes('/DocumentXML/Row/Transactions') as Data(X)   
       
       Set @DocXml=convert(nvarchar(max), @AA) 
          
       set @Prefix=''
       EXEC [sp_GetDocPrefix] @DocXml,@DT_INT,@COSTCENTERID,@Prefix output 
     
       EXEC @return_value = [dbo].spDOC_SetTempAccDocument  
       @CostCenterID = @COSTCENTERID,  
       @DocID = 0,  
       @DocPrefix = @Prefix,  
       @DocNumber = N'',  
       @DocDate = @DT_INT,  
       @DueDate =NULL,  
       @BillNo = NULL,  
       @InvDocXML = @DocXml,  
       @NotesXML =  N'',  
       @AttachmentsXML =  N'',  
       @ActivityXML = N'',  
       @IsImport = 0,  
       @LocationID = 1,  
       @DivisionID = 1,  
       @WID = 0,  
       @RoleID = 1,  
       @RefCCID = 72,  
       @RefNodeid =@AssetID ,  
       @CompanyGUID = @CompanyGUID,  
       @UserName = @UserName,  
       @UserID = @UserID,  
       @LangID = @LangID  
         
         
       --SELECT  * FROM ACC_AssetDepSchedule with(nolock)
      --  SELECT  * FROM COM_Status  
              
            
        -- select  '@return_value', @return_value
        IF(@return_value > 0 )  
        BEGIN  
        
         SELECT @VOUCHERNO = VoucherNo , @STATUSID=STATUSID FROM ACC_DOCDETAILS with(nolock)
         where costcenterid = @COSTCENTERID and docid = @return_value
          
         -- SELECT @STATUSID=STATUSID from ACC_DocDetails WHERE DocID=@return_value  
          
          
        UPDATE  ACC_AssetDepSchedule  
        SET DOCID = @return_value , VOUCHERNO = @VOUCHERNO ,  Docdate =@DT_INT , STATUSID = @STATUSID  
        WHERE DPScheduleID = @DEPID and AssetID = @AssetID  
          
           
        SELECT @AssetNetValue = AssetNetValue FROM ACC_AssetDepSchedule with(nolock) WHERE DPScheduleID = @DEPID and AssetID = @AssetID  
         
         UPDATE ACC_Assets  
         SET AssetNetValue =  @AssetNetValue  
         WHERE   AssetID = @AssetID  
           
          
         if not exists( select AssetNewValue from ACC_AssetChanges with(nolock) where AssetID=@AssetID)  
         begin  
            set @AssetOldValue=(select purchaseValue from acc_assets with(nolock) where AssetID=@AssetID)  
         end  
         else  
         begin  
         if exists(select *  from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DOCID is not null and VoucherNo is not null)  
         begin  
           set @AssetOldValue=(select top(1)AssetNetValue  from ACC_AssetDepSchedule with(nolock) where AssetID=@AssetID and DOCID is not null and VoucherNo is not null)  
         end  
         else  
         begin  
          set @AssetOldValue=(select top(1)AssetNewValue from acc_assetchanges with(nolock) where AssetID=@AssetID order by AssetChangeID desc)  
         end  
         end   
         --select * from ACC_AssetDepSchedule   
         insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,LocationID,GUID,CreatedBy,CreatedDate)  
         values(@AssetID,6,'Depreciation Schedule Post',1,@DT_INT,@AssetOldValue,@ChangeValue,@AssetNetValue,NULL,newid(),'ADMIN',convert(float,@DT))  
        END  
       END   
    END   
  END     
  ELSE   
  BEGIN  
   IF(@JVXML is not null and @JVXML<>'')    
     BEGIN    
    DECLARE @DOCID BIGINT, @DepAmount FLOAT ,     @DELDocPrefix nvarchar(50) ,  @DELDocNumber nvarchar(500)   -- @DocDate float ,@STATUSID INT  ,   
  
    SET @XML =   @JVXML     
    CREATE TABLE #tblListJVUnPost(ID int identity(1,1) , DEPIDXML BIGINT)        
    INSERT INTO #tblListJVUnPost      
    SELECT    X.value('@DepID','BIGINT')      
    from @XML.nodes('/JVXML/DepreciationID') as Data(X)    
  
    SELECT @CNT = COUNT(ID) FROM #tblListJVUnPost    
  
    Set @DT=getdate()   
    set @DT_INT=floor(convert(float,@DT))
  
    SET @ICNT = 0   
    
    WHILE(@ICNT < @CNT)    
     BEGIN    
     SET @ICNT =@ICNT+1    
     SET @ScheduleID = 0   
     SELECT  @ScheduleID  = DEPIDXML  FROM #tblListJVUnPost WHERE  ID = @ICNT    
  
     SET @VOUCHERNO = ''  
     SET @STATUSID = 0   
     SET @AssetNetValue = 0   
  
     --SELECT * FROM ACC_AssetDepSchedule  
     SELECT @DOCID = DOCID,  @VOUCHERNO = VOUCHERNO, @DocDate = DOCDATE,@STATUSID = STATUSID , @DepAmount= DepAmount   
     , @AssetNetValue  = AssetNetValue  FROM ACC_AssetDepSchedule with(nolock)
     where AssetID = @AssetID and DPScheduleID = @ScheduleID  
  
      PRINT @VOUCHERNO
     --SELECT * FROM ACC_AssetDepSchedule --DELETE  
  
    
     EXEC @return_value = [dbo].[spDOC_DeleteAccDocument]    
       @CostCenterID = @COSTCENTERID,    
       @DocPrefix = '',    
       @DocNumber = '', 
       @DOcID=   @DOCID,
       @UserID = 1,    
       @UserName = N'ADMIN',    
       @LangID = 1,
       @RoleID=1
  
     --SELECT * FROM ACC_Assets   
  
     UPDATE ACC_Assets  
     SET ASSETNETVALUE = (@AssetNetValue   +  @DepAmount)    
     WHERE ASSETID = @AssetID  
  
     --SELECT * FROM ACC_AssetDepSchedule    
     UPDATE ACC_AssetDepSchedule  
     SET DOCID = NULL, VOUCHERNO = NULL , DOCDATE = NULL , STATUSID = 0   
     WHERE ASSETID = @AssetID and DPScheduleID = @ScheduleID  
    --DOCID, VOUCHERNO,DOCDATE,STATUSID   
        
     insert into ACC_AssetChanges(AssetID,ChangeType,ChangeName,StatusID,ChangeDate,AssetOldValue,ChangeValue,AssetNewValue,LocationID,GUID,CreatedBy,CreatedDate)  
     values(@AssetID,7,'Depreciation Schedule UnPost',1,@DT_INT,@AssetNetValue,@DepAmount,(@AssetNetValue   +  @DepAmount),NULL,newid(),'ADMIN',convert(float,@DT))  
  
      
    set @return_value = 1  
    END--END WHILE   
   END -- END IF   
  END --ELSE END  
  
  
COMMIT TRANSACTION          
--ROLLBACK TRANSACTION
       
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
WHERE ErrorNumber=100 AND LanguageID=@LangID      
SET NOCOUNT OFF;     
RETURN @return_value  
  
END TRY          
BEGIN CATCH          
IF ERROR_NUMBER()=50000      
 BEGIN      
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID      
 END      
 ELSE IF ERROR_NUMBER()=547      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM      
COM_ErrorMessages WITH(nolock)      
  WHERE ErrorNumber=-110 AND LanguageID=@LangID      
 END      
 ELSE IF ERROR_NUMBER()=2627      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM      
COM_ErrorMessages WITH(nolock)      
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
