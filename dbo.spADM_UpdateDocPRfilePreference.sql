USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_UpdateDocPRfilePreference]
	@CallType [int],
	@ProfileID [int],
	@MapXML [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
-- =============================================  
-- Author:  Waseem  
-- Create date: 22 Nov 2023  
-- Description: Update DocumentprofileMapping  
-- Example :    
-- spADM_UpdateDocPRfilePreference   
 -- 1 or 2  
 -- ,50004  
 -- ,'<DimensionDefProfile><Row  WEFDate="01 Nov 2023" TillDate="24 Nov 2023" CostCenterID="41052" ProfileID="50004"/></DimensionDefProfile>'  
 -- ,1  
--  ,1  
-- =============================================  
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
   
 declare @XML xml,@I INT,@CNT INT , @CCID bigint, @WEFDate nvarchar(20), @TillDate nvarchar(20), @sql  nvarchar(max),@sXML nvarchar(max),@PrfileID nvarchar(100)  
 set @XML=@MapXML 
   DECLARE @x xml,@PrefValue NVARCHAR(MAX);DECLARE @lft INT,@rgt INT;  
  
  --Remove Duplicate Data if any  
  CREATE TABLE #PDATA_1 (ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT,PrefValue NVARCHAR(MAX))  
  INSERT INTO #PDATA_1  
  SELECT CostCenterID,PrefValue FROM COM_DocumentPreferences P WITH(NOLOCK)   
  WHERE P.PrefName='DefaultProfileID' and P.PrefValue!='' -- and CostCenterID=@CostCenterID   
  
  UPDATE #PDATA_1 SET PrefValue=REPLACE(REPLACE(PrefValue,'<DimensionDefProfile>',''),'</DimensionDefProfile>','')  
  UPDATE #PDATA_1 SET PrefValue='<DimensionDefProfile>'+PrefValue+'</DimensionDefProfile>'   
  

  SELECT @lft=1,@rgt=Count(*) FROM #PDATA_1 WITH(NOLOCK)  
    
   While @lft<=@rgt  
   BEGIN  
    SELECT @x=PrefValue,@PrefValue='' FROM #PDATA_1 WITH(NOLOCK) WHERE ID=@lft  
    SELECT @PrefValue=@PrefValue+PrefValue from (  
    SELECT Distinct CONVERT(NVARCHAR(MAX),x.e.query('.')) PrefValue  
    FROM @x.nodes('DimensionDefProfile/Row') as x(e) ) AS T  
    UPDATE #PDATA_1 SET PrefValue='<DimensionDefProfile>'+@PrefValue+'</DimensionDefProfile>' WHERE ID=@lft  
    SET @lft=@lft+1  
   END  
   UPDATE P SET P.PrefValue=T.PrefValue  
   FROM COM_DocumentPreferences P WITH(NOLOCK)   
   JOIN #PDATA_1 T WITH(NOLOCK) ON T.CostCenterID=P.CostCenterID  
   WHERE P.PrefName='DefaultProfileID'  
   drop table #PDATA_1  
  ---  
  
 IF(@CallType=2)--get  
 BEGIN  
  declare @ProfileCC nvarchar(max),@PXML XML,@K INT,@CNT_1 int;  
  declare @J INT,@CNT1 INT  
  Create table #cctable(ID INT IDENTITY(1,1),ProID nvarchar(50),ccid bigint)   
  declare @Pccid int;  
  declare @cctableMAIN table(ID INT IDENTITY(1,1),ProfileCC nvarchar(MAX),ccid bigint)   
  declare @IncludeCC nvarchar(max)  
   create table #Profiletable(ID INT IDENTITY(1,1),wef datetime,tilldate datetime,profileid NVARCHAR(50))   
  ---  
     
  INSERT INTO @cctableMAIN  
     SELECT prefvalue,CostCenterID from com_documentpreferences  
     WITH(NOLOCK) where prefname='DefaultProfileID'-- and    
     --ISNULL(prefvalue,'')<>''  
       
    SET @J=1  
    SELECT  @CNT1=COUNT(*) FROM @cctableMAIN      
    WHILE (@J<=@CNT1)  
    BEGIN  
       
     SET @ProfileCC=''  
     SELECT @ProfileCC =ProfileCC,@Pccid=ccid FROM  @cctableMAIN WHERE ID=@J  
     IF(ISNULL(@ProfileCC,'')<>'')  
     BEGIN      
     
      set @PXML=@ProfileCC      
      INSERT INTO #Profiletable        
      SELECT       
       X.value('@WEFDate','DateTime')         
       ,X.value('@TillDate','DateTime')  
       ,X.value('@ProfileID','INT')  
      from @PXML.nodes('/DimensionDefProfile/Row') as Data(X)       
      SET @K=1  
      SELECT  @CNT_1=COUNT(*) FROM #Profiletable     
      set @IncludeCC=''  
      WHILE (@K<=@CNT_1)  
      BEGIN  
        insert into #cctable(ProID,ccid)   
        Select  profileid,@Pccid FROM #Profiletable WHERE ID=@K  
        
      SET @K=@K+1  
      END  
     END  
    SET @J=@J+1     
   
    END    
      drop table #Profiletable  
   select CostCenterID,PrefValue from com_documentpreferences with(nolock) where prefname='DefaultProfileID'  
   and  CostCenterID in (select ccid from  #cctable where ProID=@ProfileID)  and PrefValue<>'<DimensionDefProfile></DimensionDefProfile>'
   drop table #cctable
 END  
  IF(@CallType=1)--update  
  Begin
  	CREATE table  #TblParamData(ID INT IDENTITY(1,1),CCID bigint,WEFDate nvarchar(20),TillDate nvarchar(20),ProfileID bigint)  
	CREATE TABLE #PDATA (ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT,PrefValue NVARCHAR(MAX)) 
  set @XML=@MapXML    
IF @MapXML<>'' AND @MapXML IS NOT NULL
		BEGIN
		--add/Update Start  
		declare @PrefValue_Con  nvarchar(max)
		declare @PrefValue_Con1  nvarchar(max)
			set @PrefValue='';
			set @PrefValue_Con='';
			declare @cc_id bigint		
			SET @XML=@MapXML   	
			
			INSERT INTO #TblParamData
			SELECT  X.value('@CostCenterID','bigint'),X.value('@WEFDate','DATETIME'),X.value('@TillDate','DATETIME'),@ProfileID	FROM @XML.nodes('/DimensionDefProfile/Row') as DATA(X)			 		
			
			INSERT INTO #PDATA
			SELECT CostCenterID,PrefValue FROM COM_DocumentPreferences P WITH(NOLOCK) 
			WHERE P.PrefName='DefaultProfileID'  and ISNULL(PrefValue,'')!=''
			
			--UPDATE #PDATA SET PrefValue=REPLACE(REPLACE(PrefValue,'<DimensionDefProfile>',''),'</DimensionDefProfile>','')
			Select @CNT=COUNT(*) FROM #TblParamData
			set @I=1
			
			set @PrefValue_Con1=''	
			WHILE(@I<=@CNT)
			BEGIN		 		  
			SELECT  @PrefValue_Con=' WEFDate='''+CONVERT(NVARCHAR,CONVERT(DATETIME,WEFDate),106)+'''  TillDate='''+CONVERT(NVARCHAR,CONVERT(DATETIME,TillDate),106)+''' ',  @cc_id=CCID
			FROM #TblParamData   WITH(NOLOCK) where ID=@I 	
			print 'ww'
			print @PrefValue_Con
			if exists(select PrefValue from COM_DocumentPreferences where  CostCenterID=@cc_id and PrefName='DefaultProfileID'	 )--and isnull(PrefValue,'')<>''
			begin
				if(isnull(@PrefValue_Con,'')!='')
					update #PDATA set PrefValue=PrefValue+'<Row '+@PrefValue_Con+' ProfileID='''+CONVERT(NVARCHAR(MAX),@ProfileID)+''' />' 
				 where CostCenterID=@cc_id 
				else if(isnull(@PrefValue_Con,'')='')			
					update #PDATA set PrefValue=PrefValue+'<Row   ProfileID='''+CONVERT(NVARCHAR(MAX),@ProfileID)+''' />' where CostCenterID=@cc_id
			end			 
			--else
			--begin
			--print '2'
			--print @PrefValue_Con
			--print @cc_id
			--	if(isnull(@PrefValue_Con,'')!='')
			--	INSERT INTO #PDATA select @cc_id,'<DimensionDefProfile>'+'<Row '+@PrefValue_Con+' ProfileID='''+CONVERT(NVARCHAR(MAX),@ProfileID)+''' />'+'</DimensionDefProfile>' 
			--	else if(isnull(@PrefValue_Con,'')='')
			--	INSERT INTO #PDATA select @cc_id,'<DimensionDefProfile>'+'<Row  ProfileID='''+CONVERT(NVARCHAR(MAX),@ProfileID)+''' />'+'</DimensionDefProfile>' 
			--end
			SET @I=@I+1							
	    END	 
			
			
			UPDATE #PDATA SET PrefValue=REPLACE(REPLACE(PrefValue,'<DimensionDefProfile>',''),'</DimensionDefProfile>','')
			UPDATE #PDATA SET PrefValue='<DimensionDefProfile>'+PrefValue+'</DimensionDefProfile>' 
			--select * from #PDATA where CostCenterID=40001
 	    	set @PrefValue='';			 
			DECLARE @xmlData xml;DECLARE @lft1 INT,@rgt1 INT;      
			SELECT @lft1=1,@rgt1=Count(*) FROM #PDATA WITH(NOLOCK)              
			While @lft1<=@rgt1      
			BEGIN    
					declare @ccid1 bigint
						SELECT @xmlData=PrefValue,@PrefValue='',@ccid1=CostCenterID FROM #PDATA WITH(NOLOCK) WHERE ID=@lft1      
						SELECT @PrefValue=@PrefValue+PrefValue from (      
						SELECT Distinct CONVERT(NVARCHAR(MAX),x.e.query('.')) PrefValue      
						FROM @xmlData.nodes('DimensionDefProfile/Row') as x(e) ) AS T	 
						if( ISNULL(@PrefValue,'')<>'')
						begin
							UPDATE #PDATA SET PrefValue='<DimensionDefProfile>'+@PrefValue+'</DimensionDefProfile>' WHERE   ID=@lft1         
						end
					SET @lft1=@lft1+1      
			END   			 
			--select * from #PDATA where CostCenterID=40001
			UPDATE P SET P.PrefValue=T.PrefValue
			FROM COM_DocumentPreferences P WITH(NOLOCK) 
			JOIN #PDATA T WITH(NOLOCK) ON T.CostCenterID=P.CostCenterID
			WHERE P.PrefName='DefaultProfileID'	 	 
		 	--add/Update END  

			--Start Here Deleting the records which are save as profile id in other costcenter
			CREATE TABLE #tableALLData(ID INT IDENTITY(1,1),ProfileCC nvarchar(MAX),ccid bigint) 
			CREATE TABLE #Deltable(ID INT IDENTITY(1,1),WEFDate datetime,TillDate datetime,profileid NVARCHAR(50),CostCenterID INT,PrefValue NVARCHAR(MAX))   
			CREATE TABLE #DDATA (ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT,PrefValue NVARCHAR(MAX),ProfileID bigint,flagDel int) 
			 
			INSERT INTO #DDATA  
			 SELECT Distinct CCID,'',ProfileID,0 from #TblParamData  
			 WITH(NOLOCK) where CCID>0
			  
		--select * from #DDATA
			 
			INSERT INTO #tableALLData  
			 SELECT prefvalue,CostCenterID from com_documentpreferences  
			 WITH(NOLOCK) where prefname='DefaultProfileID' and  CostCenterID not in (select CostCenterID from #DDATA where flagDel=0)  
			 and ISNULL(prefvalue,'')<>'' and prefvalue!='<DimensionDefProfile></DimensionDefProfile>' 
		    --select * from #tableALLData
			SET @J=1  
			SELECT  @CNT1=COUNT(*) FROM #tableALLData      
			WHILE (@J<=@CNT1)  
			BEGIN  
       
			 SET @ProfileCC=''  
			 SELECT @ProfileCC =ProfileCC,@Pccid=ccid FROM  #tableALLData WHERE ID=@J  
			 IF(ISNULL(@ProfileCC,'')<>'')  
			 BEGIN    
			   set @PXML=@ProfileCC      
			  INSERT INTO #Deltable        
			  SELECT       
			   X.value('@WEFDate','DateTime')         
			   ,X.value('@TillDate','DateTime')  
			   ,X.value('@ProfileID','INT') ,@Pccid,'' 
			  from @PXML.nodes('/DimensionDefProfile/Row') as Data(X)      
			  END  
			SET @J=@J+1     
			END  
	--deleting the profiles id temp table
	--select * from #Deltable 
			--DELETE FROM #Deltable where profileid=@ProfileID
				
			drop table #DDATA	
			drop table #TblParamData
			 drop table #PDATA
	--latestest xml is updating other than profile id passed
		 set @sql=''    
		 set @I=1      
		select @CNT=COUNT(*) FROM #Deltable   
		WHILE(@I<=@CNT)      
		BEGIN      
		  set @sql=''      
		  select  @CCID=CostCenterID,@TillDate=isnull(TillDate,''),@WEFDate=isnull(WEFDate,''),@PrfileID=ProfileID from #Deltable where ID=@I      
		  print 1
		  print @WEFDate
		  if(isnull(@WEFDate,'')='' or isnull(@WEFDate,'')='Jan  1 1900 12:00AM')      
		  set @sql='<Row  ProfileID='''+Convert(nvarchar(100),@PrfileID) + ''' /> '      
		  else            
		  set @sql=@sql + '<Row WEFDate='''+ Convert(nvarchar,@WEFDate,106) +''' TillDate='''+ Convert(nvarchar,@TillDate,106) +''' ProfileID='''+Convert(nvarchar(100),@PrfileID) + ''' /> '      
		  UPDATE #Deltable SET PrefValue=@sql WHERE CostCenterID=@CCID       
          
		  print @sql    
		   SET @I=@I+1       
		END 
		--select * from #Deltable

		CREATE TABLE #FinalDATA (ID INT IDENTITY(1,1) PRIMARY KEY,CostCenterID INT,PrefValue NVARCHAR(MAX))
		INSERT INTO #FinalDATA
		SELECT CostCenterID,PrefValue FROM #Deltable P WITH(NOLOCK) 
		where ISNULL(PrefValue,'')!=''

		Select @CNT=COUNT(*) FROM #FinalDATA
			set @I=1
			set @PrefValue_Con1=''			
	    	WHILE(@I<=@CNT)
			BEGIN		 		  
			SELECT  @PrefValue_Con=PrefValue,  @cc_id=CostCenterID
			FROM #FinalDATA   WITH(NOLOCK) where ID=@I 	 
			--if exists(select PrefValue from COM_DocumentPreferences where  CostCenterID=@cc_id and PrefName='DefaultProfileID'	 )--and isnull(PrefValue,'')<>''
			--begin
				if(isnull(@PrefValue_Con,'')!='')
					update #FinalDATA set PrefValue=PrefValue+ @PrefValue_Con 
				 where CostCenterID=@cc_id 				
			--end		
			set @I=@I+1
			end

			--select * from  #FinalDATA
			
			--UPDATE P SET P.PrefValue=T.PrefValue
			--FROM COM_DocumentPreferences P WITH(NOLOCK) 
			--JOIN #FinalDATA T WITH(NOLOCK) ON T.CostCenterID=P.CostCenterID
			--WHERE P.PrefName='DefaultProfileID'			
			
			drop table #FinalDATA
			drop table #Deltable
			drop table #tableALLData					   			 
			----Deleting End here
 	END
  End

COMMIT TRANSACTION   
SET NOCOUNT OFF;     
RETURN 1  
END TRY  
BEGIN CATCH    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
 FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  
GO
