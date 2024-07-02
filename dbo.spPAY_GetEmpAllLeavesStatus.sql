USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmpAllLeavesStatus]
	@EmployeeID [varchar](20) = '442',
	@CostCenterID [int] = 50051,
	@PayrollDate [datetime] = '01-apr-2020'
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN            
        
 DECLARE @GRADE as int        
 DECLARE @TotCount int       
 DECLARE @Counter int       
 DECLARE @TotAssign float       
 DECLARE @TotTaken float  
 set @TotTaken=0          
 DECLARE @LeaveId int       
 DECLARE @CURRDATE DATETIME      
 SET @CURRDATE=GETDATE()      
 DECLARE @FromDate DATETIME      
 DECLARE @ToDate DATETIME     
 set @FromDate=CONVERT(VARCHAR,YEAR(CONVERT(DATETIME,@PayrollDate)))+'-' + DATENAME(MONTH,@PayrollDate)+'-' +'01'  
    set @ToDate=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@FromDate)+1,0))  
    print @FromDate  
    print @ToDate   
-- SELECT @GRADE=ISNULL(CCNID53,0) FROM COM_CCCCData WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID=@EmployeeID           
 --print @GRADE      
 CREATE TABLE #EmpLeaveList (ID INT IDENTITY(1,1),LeaveId varchar(50),LeaveName varchar(100),ShortName varchar(5),TotAssignLeave float,TakenLeave float,Balance float)      
       
 --INSERT INTO #EmpLeaveList    select Nodeid as LeaveId,Name as LeaveName,Left(isnull(AliasName,''),2) as ShortName,0,0,0 from COM_CC50052  where NodeId in ( SELECT  componentid FROM COM_CC50054 WITH(NOLOCK)           
 --WHERE GradeID=@Grade and CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,@PayrollDate) and type=4  )    
 INSERT INTO #EmpLeaveList   
 SELECT b.Nodeid as LeaveId,b.Name as LeaveName,Left(isnull(b.AliasName,''),2) as ShortName,0,0,0 FROM COM_CC50054 a WITH(NOLOCK)   
 Left Join COM_CC50052 b on b.NodeID=a.ComponentID  
 WHERE a.type=4 and GradeID IN(SELECT  DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK)   
 WHERE NodeID IN(@EmployeeID) AND CostCenterID=50051 AND HistoryCCID=50053     
 AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,CONVERT(NVARCHAR,@FromDate)) OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,CONVERT(NVARCHAR,@FromDate)) AND CONVERT(DATETIME,CONVERT(NVARCHAR,@ToDate)))   
 AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,CONVERT(NVARCHAR,@FromDate)) OR ToDate IS NULL))           
 and PayrollDate=(SELECT MAX(PAYROLLDATE) FROM COM_CC50054  WITH(NOLOCK) WHERE CONVERT(DATETIME,PAYROLLDATE)<=CONVERT(DATETIME,CONVERT(NVARCHAR,@FromDate))   
 AND GradeID IN( SELECT  DISTINCT HistoryNodeID FROM COM_HistoryDetails WITH(NOLOCK)   
 WHERE NodeID IN(@EmployeeID)AND CostCenterID=50051 AND HistoryCCID=50053     
 AND (CONVERT(DATETIME,FromDate)<=CONVERT(DATETIME,CONVERT(NVARCHAR,@FromDate)) OR CONVERT(DATETIME,FromDate) BETWEEN CONVERT(DATETIME,CONVERT(NVARCHAR,@FromDate)) AND CONVERT(DATETIME,CONVERT(NVARCHAR,@ToDate)))   
 AND (CONVERT(DATETIME,ToDate)>=CONVERT(DATETIME,CONVERT(NVARCHAR,@FromDate)) OR ToDate IS NULL))  
          )   
       ORDER BY GradeID,Type,SNo        
 Select @TotCount= count(*) from #EmpLeaveList        
 SET @Counter=1      
 WHILE (@Counter<=@TotCount)      
 BEGIN       
  SELECT @LeaveId=LeaveId FROM #EmpLeaveList WHERE ID=@Counter        
  declare @EssTempTable table(C1 float,TotAssign varchar(20),C3 datetime,C4 datetime,C5 varchar(20),C6 varchar(20),C7 varchar(20),C8 varchar(20))        
  insert into @EssTempTable      
  Exec [spPAY_ExtGetAssignedLeaves] @EmployeeID,@LeaveId,@PayrollDate         
  select @TotAssign= TotAssign,@FromDate=C3,@ToDate=C4 from @EssTempTable       
          
SELECT @TotTaken=convert(float,isnull(td.dcalpha7,0))       
FROM   COM_DocTextData td,COM_DocccData dc,inv_docdetails id ,COM_CC50052 lt      
WHERE  id.invdocdetailsid=td.invdocdetailsid       
    and id.invdocdetailsid=dc.invdocdetailsid      
    and td.invdocdetailsid=dc.invdocdetailsid      
    and id.statusid not in (372,376)      
    and lt.nodeid=DC.dcccnid52      
    and id.COSTCENTERID=40062      
    and dc.dcccnid51=@EmployeeID      
   AND DC.DCCCNID52=@LeaveId      
    and
     (CONVERT(DATETIME,dcAlpha4) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)      
     or CONVERT(DATETIME,dcAlpha5) between CONVERT(DATETIME,@FromDate) and CONVERT(DATETIME,@ToDate)      
     or CONVERT(DATETIME,@FromDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha5)      
     or CONVERT(DATETIME,@ToDate) between CONVERT(DATETIME,dcAlpha4) and CONVERT(DATETIME,dcAlpha4))             
        
  update #EmpLeaveList set  TotAssignLeave=@TotAssign,TakenLeave=ISNULL(@TotTaken,0) WHERE ID=@Counter               
  set @TotAssign=0      
  set @TotTaken=0      
  
  delete from @EssTempTable      
            
 SET @Counter=@Counter+1      
 END      
       
 select  LeaveId,  LeaveName,ShortName,isnull(TotAssignLeave,0) as TotAssignLeave ,isnull(TakenLeave,0) as TakenLeave,isnull(TotAssignLeave-TakenLeave,0) as Balance  
 --,58 as Percentage,((TakenLeave/TotAssignLeave)*100) as Percentage1 from #EmpLeaveList     
  ,58-TotAssignLeave as Percentage  from #EmpLeaveList     
       
 drop table #EmpLeaveList      
           
       
       
       
       
                  
                  
       
        
         
            
           
END
GO
