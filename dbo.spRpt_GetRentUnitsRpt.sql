USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRpt_GetRentUnitsRpt]
	@ReportType [int],
	@Type [int],
	@FromDate [datetime],
	@ToDate [datetime],
	@PropertyID [nvarchar](max),
	@UserID [bigint],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
Begin Try    
    
SET ARITHABORT ON    
     
   create  table #tblTempFlatType(NODEID BIGINT NULL , NAME NVARCHAR(100) NULL)             
   DECLARE @TBLNAME NVARCHAR(50) ,@QRY NVARCHAR (MAX)                 
   SELECT @TBLNAME = TABLENAME FROM  dbo.ADM_Features  with(nolock)
   WHERE FEATUREID in ( select value from dbo.ADM_GlobalPreferences with(nolock) where name  = 'UnitLinkDimension') 
   
   IF(@TBLNAME is not null and @TBLNAME <>'')                 
   BEGIN                  
	   SET @QRY = ' SELECT Nodeid,Name FROM ' + @TBLNAME+' with(nolock) where IsGroup=0 order by lft'
	   INSERT INTO #tblTempFlatType(NODEID , NAME)                  
	   EXEC (@QRY)                 
   END
   
   SELECT * FROM #tblTempFlatType
   
   IF @ReportType=1
   BEGIN
		if @Type=1
		begin
			SET @Qry = ' SELECT distinct COUNT(T0.UnitID)  UnitCount, T2.NodeID PropertyID ,T2.Name PropertyName ,T2.PARENTID   
, PG.Name GroupName,PG.lft,T2.lft
			, TMPStatusID.NodeID UnitTypeID , TMPStatusID.Name   Name
			FROM REN_Units T0 with(nolock)
			JOIN REN_Property T2  with(nolock)  ON T2.NODEID = T0.PROPERTYID
			JOIN REN_Property PG with(nolock) ON PG.NODEID=T2.PARENTID
			LEFT JOIN #tblTempFlatType  TMPStatusID ON  TMPStatusID.NODEID = T0.NODEID   
			where   T0.PropertyID=T2.NodeID  and T0.Name is not null and T0.Name <>'''' ' 
		    
			IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')
				SET  @Qry = @Qry  + ' AND T2.NodeID IN (' + @PropertyID + ')'
			SET  @Qry = @Qry  + ' GROUP BY   PG.Name,PG.lft,T2.NodeID,T2.lft,T2.Name    , TMPStatusID.NodeID, TMPStatusID.Name, T2.Name  , T2.PARENTID
		ORDER BY   PG.lft, T2.lft , TMPStatusID.NodeID '
		end
		else
		begin
			SET @Qry = ' select PU.Numbers UnitCount,PU.PropertyID,P.Name PropertyName,PG.Name GroupName,P.ParentID,PU.Type UnitTypeID,UT.Name
from REN_PropertyUnits PU with(nolock)
inner join #tblTempFlatType UT with(nolock) ON UT.NodeID=PU.Type
inner join REN_Property P with(nolock) ON P.NodeID=PU.PROPERTYID
left join REN_Property PG with(nolock) ON PG.NodeID=P.ParentID
WHERE PU.Numbers!=0'
			IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')
				SET  @Qry = @Qry  + ' AND P.NodeID IN (' + @PropertyID + ')'
			SET  @Qry = @Qry  + ' ORDER BY Pg.lft,P.lft,UT.NodeID'
		end
		print @Qry
		EXEC(@Qry)
	END
	ELSE IF @ReportType=2
	BEGIN
		if @Type=1
		begin
			SET @Qry = '  SELECT distinct SUM(T0.AnnualRent)  UnitCount, T2.NodeID PropertyID ,T2.Name PropertyName   ,T2.PARENTID  
, PG.Name GroupName,PG.lft,T2.lft
		, TMPStatusID.NodeID UnitTypeID , TMPStatusID.Name   Name
		FROM REN_Units T0 with(nolock)
		JOIN REN_Property T2 with(nolock) ON T2.NODEID = T0.PROPERTYID
		JOIN REN_Property PG with(nolock) ON PG.NODEID=T2.PARENTID
		LEFT JOIN #tblTempFlatType  TMPStatusID ON  TMPStatusID.NODEID = T0.NODEID   
		where   T0.PropertyID=T2.NodeID  and T0.Name is not null and T0.Name <>'''' ' 
		    
			IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')
				SET  @Qry = @Qry  + ' AND T2.NodeID IN (' + @PropertyID + ')'
			SET  @Qry = @Qry  + ' GROUP BY PG.Name,PG.lft,T2.NodeID,T2.lft,T2.Name    , TMPStatusID.NodeID, TMPStatusID.Name, T2.Name  , T2.PARENTID
		ORDER BY PG.lft, T2.lft ,TMPStatusID.NodeID '
		end
		else
		begin
			SET @Qry = ' select PU.Rent UnitCount,PU.PropertyID,P.Name PropertyName,PG.Name GroupName,P.ParentID,PU.Type UnitTypeID,UT.Name
from REN_PropertyUnits PU with(nolock)
inner join #tblTempFlatType UT with(nolock) ON UT.NodeID=PU.Type
inner join REN_Property P with(nolock) ON P.NodeID=PU.PROPERTYID
left join REN_Property PG with(nolock) ON PG.NodeID=P.ParentID
WHERE PU.Rent!=0'
			IF(@PropertyID IS NOT NULL AND @PropertyID <> '' AND @PropertyID <>'0')
				SET  @Qry = @Qry  + ' AND P.NodeID IN (' + @PropertyID + ')'
			SET  @Qry = @Qry  + ' ORDER BY Pg.lft,P.lft,UT.NodeID'
		end
		print @Qry
		EXEC(@Qry)
	END
    	 
    
drop table #tblTempFlatType
IF @@ERROR<>0 BEGIN  RETURN -103 END    
      
RETURN 1    
End Try    
Begin Catch    
 RETURN -12345    
End Catch    
GO
