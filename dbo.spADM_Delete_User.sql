USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_Delete_User]
	@DataUserID [int],
	@DataUserName [nvarchar](50),
	@RoleID [int],
	@LangID [int] = 1,
	@UserName [nvarchar](50),
	@UserID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
SET NOCOUNT ON    
BEGIN TRY    
      
  --Declaration Section    
  DECLARE @HasAccess BIT,@RowsDeleted INT, @IsUserdefined BIT    
  DECLARE @iUserCheckFlag int=0;    
  --SP Required Parameters Check    
  IF @DataUserID=0    
  BEGIN    
   RAISERROR('-100',16,1)    
  END  
  --User acces check    
  SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,7,4)    
  IF @HasAccess=0    
  BEGIN    
   RAISERROR('-105',16,1)    
  END     
 ----checking for Admin      
 --if(LOWER(@DataUserName)='admin')    
 --BEGIN    
 -- set @iUserCheckFlag=1;   
 --END     
 --Fetch IsUserdefined user.    
  SELECT @IsUserdefined = IsUserdefined     
  FROM [PACT2C].dbo.ADM_Users WITH(NOLOCK) WHERE UserName =@DataUserName    
       
  IF @IsUserdefined IS NULL    
  BEGIN    
   RAISERROR('-100',16,1)     
  END    
  ELSE IF @IsUserdefined = 0    
   RAISERROR('-102',16,1)     
  
   --Checking for Master Tables     
   CREATE TABLE #Tab (ID INT IDENTITY(1,1),FeatureID INT,TableName NVARCHAR(520),iFlag int)  
 INSERT INTO #Tab   
 --Dimension Tables Adding  
 SELECT FeatureID,TableName,0 FROM ADM_FEATURES with(nolock)   
 where (featureid in (2,3) or FeatureID >50000) and TableName!=''  
 --CRM  
 INSERT INTO #Tab   
 SELECT distinct FeatureID,TableName,0 FROM ADM_FEATURES with(nolock)   
 where featureid in (86,89,88,73,65,82,91,40997,145) and TableName!=''  
  
 --Payrol  
 INSERT INTO #Tab   
 SELECT distinct FeatureID,TableName,0 FROM ADM_FEATURES with(nolock)   
 where featureid in (256,258,260,263,262,261,264,141,266,267,44,498) and TableName!=''  
  
 --rental  
 INSERT INTO #Tab   
 SELECT distinct FeatureID,TableName,0 FROM ADM_FEATURES with(nolock)   
 where featureid in (92,93,94,95,103,104) and TableName!=''  
  
 --Document  
 INSERT INTO #Tab   
 SELECT distinct FeatureID,TableName,0 FROM ADM_FEATURES with(nolock)   
 where featureid >=40001 and featureid<=50000 and   TableName!=''  
   
 --Production  
 INSERT INTO #Tab   
 SELECT distinct FeatureID,TableName,0 FROM ADM_FEATURES with(nolock)   
 where featureid in (71,76,78) and TableName!=''   
   
  INSERT INTO #Tab   
 select 404, name,0 from sys.tables where (name not in ('ADM_Users','ADM_UserRoleMap')) or name not in (select tableName from #Tab)  
   
 

 declare @dynWhere varchar(200)  
 DECLARE @ICount INT,@CNTtot INT,@ID int, @CCID INT,@CCNAME NVARCHAR(300),@STRQRY NVARCHAR(MAX)    
 SELECT @ICount=1,@CNTtot=COUNT(*) FROM #Tab      
 WHILE(@ICount<=@CNTtot)    
 BEGIN    
  select @CCID=FeatureID,@CCNAME=TableName,@ID=ID from #Tab where ID=@ICount        
  set @dynWhere=''  
  if exists(select column_name from information_schema.columns where table_name=@CCNAME and column_name='ModifiedBy')  
   set @dynWhere= ' isnull(ModifiedBy,'''')  = '''+ @DataUserName +''' '  
  else   
   set @dynWhere=''  
    
  if exists(select column_name from information_schema.columns where table_name=@CCNAME and column_name='CreatedBy')  
  begin  
   if(isnull(@dynWhere,'')<>'')  
    set @dynWhere=@dynWhere  +  ' and  isnull(CreatedBy,'''') = '''+ @DataUserName +''''  
   else  
    set @dynWhere=@dynWhere  +  '   isnull(CreatedBy,'''') = '''+ @DataUserName +''''  
  end   
  
  if(@ID>0 and @CCID=404 and isnull(@dynWhere,'')<>'')  
  BEGIN   
  SET @STRQRY='if (select count(*) from '+ @CCNAME +' with(nolock) WHERE   '+ @dynWhere +')>0    
      
  begin       
   update   #Tab  SET iFlag=1 where ID='''+ convert(varchar,@ID)+'''  
  end   
  '  
  END  
  ELSE if(@CCID>0 and @CCID<>404 and isnull(@dynWhere,'')<>'')  
   BEGIN   
  SET @STRQRY='if (select count(*) from '+ @CCNAME +' with(nolock) WHERE   '+ @dynWhere +')>0    
      
  begin       
   update   #Tab  SET iFlag=1 where FeatureID='''+ convert(varchar,@CCID)+'''  
  end   
  '  
  END   
  
  EXEC (@STRQRY)    
  SET @ICount=@ICount+1     
  
 END    

 if ((select count(*) from #Tab with(nolock) WHERE   iFlag>0)=0  and @iUserCheckFlag=0 )  
 BEGIN    
 set @iUserCheckFlag=1;    
 END   
  
   
 IF(@iUserCheckFlag=1 and LOWER(@DataUserName) !='admin')    
 BEGIN    
 
   insert into ADM_UsersHistory    
    select   UserID,UserName,Password,StatusID,DefaultLanguage,IsUserDeleted,FirstName,MiddleName,LastName    
      ,Address1,Address2,Address3,City,State,Zip,Country,Phone1,Phone2,Fax,Email1,Email2,Website,GUID    
      ,Description,@UserName,convert(float,GETDATE()),@UserName,convert(float,GETDATE())    
      ,Email1Password,Email2Password,DefaultScreenXML,IsPassEncr,CalendarXML,0,TwoStepVerMode from ADM_Users with(nolock)    
    WHERE UserID=@DataUserID    

   DELETE A FROM [PACT2C].dbo.ADM_UserCompanyMap A
   join [PACT2C].dbo.ADM_Users B on b.userid=a.userid where b.username=@DataUserName  
   DELETE FROM [PACT2C].dbo.ADM_Users WHERE username=@DataUserName   
   DELETE FROM ADM_Users WHERE UserID=@DataUserID   
   DELETE FROM ADM_UserRoleMap where UserID=@DataUserID    


   --SELECT ErrorNumber,'User '+ErrorMessage FROM COM_ERRORMESSAGES WITH(NOLOCK) WHERE ERRORNUMBER=102 AND LANGUAGEID=@LangID  
   END             
   ELSE IF(@iUserCheckFlag=0 and LOWER(@DataUserName) !='admin')  
   BEGIN  
   --Change the status to deleted    
   UPDATE [PACT2C].dbo.ADM_Users     
   SET StatusID=2--For Deleted    
   WHERE UserName = @DataUserName    
    
   UPDATE  dbo.ADM_Users     
   SET IsUserDeleted=1, statusid=10--For Deleted    
   WHERE UserID=@DataUserID     
   and UserName = @DataUserName    
        
   UPDATE  ADM_UserRoleMap    
   SET STATUS = 2    
   WHERE UserID=@DataUserID     
   and UserName = @DataUserName    
  END  
   --SELECT * FROM  #Tab  
 DROP TABLE #Tab  
  
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH 
GO
