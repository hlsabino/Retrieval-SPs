USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetContractTemplate]
	@CTEMPLID [int],
	@TEMPLCODE [nvarchar](500),
	@TEMPLName [nvarchar](500),
	@StatusID [int],
	@BILLFREQID [int],
	@BILLFREQNAME [nvarchar](50) = NULL,
	@SVCFREQID [int],
	@SVCFREQNAME [nvarchar](50) = NULL,
	@RESPTIME [nvarchar](50) = NULL,
	@SVCLVLID [int] = NULL,
	@SVCLVLNAME [nvarchar](50) = NULL,
	@DURATION [int] = NULL,
	@DISCOUNT [float] = NULL,
	@Description [nvarchar](max) = NULL,
	@IsGroup [bit],
	@UserName [nvarchar](50),
	@CompanyGUID [nvarchar](50),
	@CreatedBy [nvarchar](50),
	@SelectedNodeID [int],
	@RoleID [int] = 0,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION 
BEGIN TRY
SET NOCOUNT ON;

 
 DECLARE @Dt float,@HasAccess bit,@UpdateSql nvarchar(max),@IsDuplicateNameAllowed bit,@IsTmplCodeAutoGen bit  ,@IsIgnoreSpace bit
    DECLARE @lft INT,@rgt INT,@Selectedlft INT,@Selectedrgt INT,@Depth int,@ParentID INT,@SelectedIsGroup int,@ParentCode nvarchar(200)

 
  --User access check 
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,81,1)
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END

    --GETTING PREFERENCE  
  SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=81 and  [Name]='DuplicateNameAllowed'  
  SELECT @IsTmplCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=81 and  [Name]='CodeAutoGen'  
  SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=81 and  [Name]='IgnoreSpaces'  
  
 -- DUPLICATE CHECK  
  IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0  
  BEGIN  
    IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1  
   BEGIN  
    IF @CTEMPLID=0  
    BEGIN  
     IF EXISTS (SELECT ContractTemplID FROM CRM_ContractTemplate WITH(nolock) WHERE replace(CTemplName,' ','')=replace(@TEMPLName,' ',''))  
     BEGIN  
      RAISERROR('-208',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ContractTemplID FROM CRM_ContractTemplate WITH(nolock) WHERE replace(CTemplName,' ','')=replace(@TEMPLName,' ','') AND ContractTemplID <> @CTEMPLID)  
     BEGIN  
      RAISERROR('-208',16,1)       
     END  
    END  
   END  
   ELSE  
   BEGIN  
    IF @CTEMPLID=0  
    BEGIN  
     IF EXISTS (SELECT ContractTemplID FROM CRM_ContractTemplate WITH(nolock) WHERE CTemplName=@TEMPLName)  
     BEGIN  
      RAISERROR('-208',16,1)  
     END  
    END  
    ELSE  
    BEGIN  
     IF EXISTS (SELECT ContractTemplID FROM CRM_ContractTemplate WITH(nolock) WHERE CTemplName=@TEMPLName AND ContractTemplID <> @CTEMPLID)  
     BEGIN  
      RAISERROR('-208',16,1)  
     END  
    END  
   END
  END

 SET @Dt=convert(float,getdate())
 IF(@CTEMPLID=0)
 ---New Insert of record
 BEGIN
      
    SELECT @SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
    from [CRM_ContractTemplate] with(NOLOCK) where ContractTemplID=@SelectedNodeID  
   
    --IF No Record Selected or Record Doesn't Exist  
    if(@SelectedIsGroup is null)   
     select @SelectedNodeID=@CTEMPLID,@SelectedIsGroup=IsGroup,@Selectedlft =lft,@Selectedrgt=rgt,@ParentID=ParentID,@Depth=Depth  
     from [CRM_ContractTemplate] with(NOLOCK) where ParentID =0  
	 

    if(@SelectedIsGroup = 1)--Adding Node Under the Group  
     BEGIN  
      UPDATE [CRM_ContractTemplate] SET rgt = rgt + 2 WHERE rgt > @Selectedlft;  
      UPDATE [CRM_ContractTemplate] SET lft = lft + 2 WHERE lft > @Selectedlft;  
      set @lft =  @Selectedlft + 1  
      set @rgt = @Selectedlft + 2  
      set @ParentID = @SelectedNodeID  
      set @Depth = @Depth + 1  
     END  
    else if(@SelectedIsGroup = 0)--Adding Node at Same level  
     BEGIN  
      UPDATE [CRM_ContractTemplate] SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;  
      UPDATE [CRM_ContractTemplate] SET lft = lft + 2 WHERE lft > @Selectedrgt;  
      set @lft =  @Selectedrgt + 1  
      set @rgt = @Selectedrgt + 2   
     END  
    else  --Adding Root  
     BEGIN  
      set @lft =  1  
      set @rgt = 2   
      set @Depth = 0  
      set @ParentID =0  
      
     END 
     --GENERATE CODE  
    IF @IsTmplCodeAutoGen IS NOT NULL AND @IsTmplCodeAutoGen=1 AND @CTEMPLID=0  
    BEGIN  
     SELECT @ParentCode=[CTemplCode]  
     FROM [CRM_ContractTemplate] WITH(NOLOCK) WHERE ContractTemplID=@ParentID    
  
     --CALL AUTOCODEGEN  
     EXEC [spCOM_SetCode] 81,@ParentCode,@TEMPLCODE OUTPUT    
    END  

     INSERT INTO CRM_ContractTemplate(CTemplCode,CTemplName,StatusID,
     BillFrequencyID,BillFrequencyName,SvcFrequencyID,SvcFrequencyName,ResponseTimeHrs,ServiceLvlID,
     ServiceLvlName,DurationMonths,DiscountAsPct,Description,Depth,ParentID,lft,
     rgt,IsGroup,CompanyGUID,GUID,CreatedBy,CreatedDate)
     Values (@TEMPLCODE,@TEMPLName,@StatusID,
     @BILLFREQID,@BILLFREQNAME,@SVCFREQID,@SVCFREQNAME,@RESPTIME,@SVCLVLID,
     @SVCLVLNAME,@DURATION,@DISCOUNT,@Description,@Depth,@SelectedNodeID,@lft,
     @rgt,@IsGroup,@CompanyGUID,newid(),@CreatedBy,convert(float,getdate()))


     --To get inserted record primary key  
      SET @CTEMPLID= SCOPE_IDENTITY()
     END
      ELSE
   BEGIN
     Update CRM_ContractTemplate
     SET CTemplCode=@TEMPLCODE,
     CTemplName=@TEMPLName,
     StatusID=@StatusID,
     BillFrequencyID=@BILLFREQID,
     BillFrequencyName=@BILLFREQNAME,
     SvcFrequencyID=@SVCFREQID,
     SvcFrequencyName=@SVCFREQNAME,
     ResponseTimeHrs=@RESPTIME,
     ServiceLvlID=@SVCLVLID,
     ServiceLvlName=@SVCLVLNAME,
     DurationMonths=@DURATION,
     DiscountAsPct=@DISCOUNT,
     [Description]=@Description,
     GUID=NEWID(),
     CreatedBy=@CreatedBy,
     CreatedDate=@Dt
   WHERE  ContractTemplID=@CTEMPLID
  END


--validate Data External function
	DECLARE @tempCCCode NVARCHAR(200)
	set @tempCCCode=''
	select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=81 and Mode=9
	if(@tempCCCode<>'')
	begin
		exec @tempCCCode 81,@CTEMPLID,1,@LangID
	end
  COMMIT TRANSACTION    
SELECT * FROM CRM_ContractTemplate WITH(nolock) WHERE ContractTemplID=@CTEMPLID  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @CTEMPLID    
END TRY    
BEGIN CATCH    
-- Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
 SELECT * FROM CRM_ContractTemplate WITH(nolock) WHERE ContractTemplID=@CTEMPLID    

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
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH  


--Select * from CRM_ContractTemplate
GO
