USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetGeoLocation]
	@CompanyID [bigint],
	@EmpSeqNo [bigint]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN    
    
DECLARE @AttendanceDimension BIGINT,@LongitudeCol NVARCHAR(500),@LatitudeCol NVARCHAR(500),@TableName NVARCHAR(500),@sQ NVARCHAR(MAX)    
    
SELECT @AttendanceDimension=VALUE FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='AttendanceDimension'    
SELECT @LongitudeCol=VALUE FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='AttendanceLongitude'    
SELECT @LatitudeCol=VALUE FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE NAME='AttendanceLatitude'    
    
--0    
if(@AttendanceDimension=4)    
BEGIN    
select @TableName=TableName from  ADM_FEATURES WITH(NOLOCK) where FeatureID=@AttendanceDimension    
    
SET @sQ='SELECT DBIndex AS NodeID,'+ @LongitudeCol +' AS Longitude,'+ @LatitudeCol +' AS Latitude FROM pact2c.dbo.ADM_CompanyExtended CE WITH(NOLOCK) 
JOIN pact2c.dbo.ADM_Company C WITH(NOLOCK) on C.CompanyID=CE.CompanyID
WHERE DBIndex='+ CONVERT(nvarchar,@CompanyID)    
    
EXEC(@sQ)    
END    
ELSE    
BEGIN    
 SELECT @TableName=TableName FROM  ADM_FEATURES WITH(NOLOCK) WHERE FeatureID=@AttendanceDimension    
    
 SET @sQ='SELECT NodeID,'+ @LongitudeCol +' AS Longitude,'+ @LatitudeCol +' AS Latitude FROM '+ @TableName +' WITH(NOLOCK)'    
     
 EXEC(@sQ)    
END    
    
--1    
SET @sQ='SELECT NodeID,CheckInOutDevice,CheckInOutMobileRange,AttSetType,AttSetDimNodes,Anywhere FROM COM_CC50051 WITH(NOLOCK) WHERE NODEID='+CONVERT(NVARCHAR,@EmpSeqNo)    
EXEC(@sQ)    
    
END 
GO
