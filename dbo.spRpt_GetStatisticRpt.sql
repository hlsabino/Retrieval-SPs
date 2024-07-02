USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_GetStatisticRpt]
	@FromDate [nvarchar](100),
	@ToDate [nvarchar](100),
	@Type [nvarchar](50),
	@UserID [bigint],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
Begin Try    
    
SET ARITHABORT ON    
    
DECLARE @Qry nvarchar(max)     
     
if(@Type = 'stat')    
 BEGIN    
 SET @Qry = '   create table #tblTempFlatType( ID INT IDENTITY(1,1),NODEID BIGINT NULL , NAME NVARCHAR(100) NULL)  
     
  DECLARE @TBLNAME NVARCHAR(50) ,@QRY NVARCHAR (MAX)  
             SELECT @TBLNAME = TABLENAME FROM  dbo.ADM_Features with(nolock) WHERE FEATUREID in ( select value from dbo.ADM_GlobalPreferences with(nolock) where name  = ''UnitLinkDimension'')      
             IF(@TBLNAME is not null and @TBLNAME <>'''')  
             BEGIN  
              SET @QRY = '' select nodeid,Name  from '' + @TBLNAME   
              INSERT INTO #tblTempFlatType(NODEID , NAME)  
              EXEC (@QRY)  
             END   
                                  
                                 SELECT     SUM(T.Occupied) Occupied ,T.TowerNodeno TowerNodeno, T.FlatType FlatType , T.NAME  from    
    ( SELECT   distinct  -COUNT(PROP.NodeID) Occupied ,PROP.NodeID TowerNodeno ,UNIT.NodeID FlatType , TMP.NAME     
    from dbo.Ren_Contract with(nolock)
    join Ren_property PROP with(nolock) on PROP.NodeID = Ren_Contract.PropertyID    
    JOIN Ren_Units UNIT with(nolock) ON UNIT.UnitID = Ren_Contract.UNITID  
    LEFT JOIN #tblTempFlatType TMP ON TMP.NODEID = UNIT.NodeID   
      
    left join   ( SELECT distinct   b.code,b.NodeID     from Ren_Units  a with(nolock)
    inner join Ren_property  b with(nolock) on b.NodeID = a.PropertyID     
        
     ) as Tow on      
    Tow.NodeID = PROP.NodeID     
    WHERE    (Convert(datetime,STARTDATE) >=  '''+ @FromDate +''' AND  CONVERT(DATETIME, ENDDATE) <='''+ @ToDate +''')    
    GROUP BY PROP.NodeID, UNIT.NodeID ,TMP.name    
    UNION     
    SELECT  COUNT(PROP.NodeID) Occupied ,PROP.NodeID TowerNodeno, UNIT.NodeID FlatType, TMP.NAME     
    FROM Ren_property  PROP with(nolock)
    JOIN Ren_Units UNIT with(nolock) ON UNIT.PropertyID =  PROP.NodeID       
      LEFT JOIN #tblTempFlatType TMP ON TMP.NODEID = UNIT.NodeID  
    GROUP BY PROP.NodeID , UNIT.NodeID, TMP.NAME ) AS T   
    WHERE   T.NAME IS NOT NULL AND  T.NAME  <> '''' GROUP BY T.TowerNodeno , T.FlatType, T.NAME   
   
      
    DROP TABLE #tblTempFlatType  
      
      
      '     
 END    
--ELSE     
-- BEGIN    
-- SET @Qry = ' SELECT    sum(convert(float,UNIT.EX16)) Occupied ,PROP.nodeno TowerNodeno, UNIT.EX2 FlatType  from dbo.Tbl_ContractMT      
--    join '+@PropertyTable+' PROP on PROP.nodeno = Tbl_ContractMT.PropertySeqNo    
--    JOIN '+@UnitTable+' UNIT ON UNIT.NODENO = Tbl_ContractMT.UNITSeqNo    
--    left join   ( SELECT distinct   b.code,b.NODENO     from '+@UnitTable+'  a    
--    inner join '+@PropertyTable+'  b  on b.nodeno = a.ex0     
--    left join Tbl_REstateProperty REProp on  b.code = REProp.propertycode     
--    where a.ex0 is not null and a.ex0 <>'''' and REProp.propertycat is not null     ) as Tow on      
--    Tow.NODENO = PROP.nodeno     
--    WHERE    (Convert(datetime,FROMDATE) >= '''+@FromDate+''' AND  CONVERT(DATETIME, TODATE) <=''' + @ToDate+''')    
--    GROUP BY   PROP.nodeno,  UNIT.EX2 '     
-- END    
 
EXEC(@Qry)    
    
IF @@ERROR<>0 BEGIN  RETURN -103 END    
      
RETURN 1    
End Try    
Begin Catch    
 RETURN -12345    
End Catch    
     
     
GO
