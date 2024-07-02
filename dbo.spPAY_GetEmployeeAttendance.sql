USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmployeeAttendance]
	@Date [nvarchar](max),
	@EmployeeID [int] = 0,
	@userid [int] = 1,
	@langid [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY

--  SHITS DATA

SELECT b.dcCCNID51 as EmpSeqNo,b.dcCCNID73 as ShiftSeqNo,s.Code as ShiftCode,s.Name as ShiftName,
CONVERT(VARCHAR(8),CONVERT(DATETIME,s.ccAlpha2),108) as ShiftStartTime,CONVERT(VARCHAR(8),CONVERT(DATETIME,s.ccAlpha3),108) as ShiftEndTime
FROM INV_DocDetails a WITH(NOLOCK) 
JOIN COM_DocCCData b WITH(NOLOCK) ON b.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_DocTextData d WITH(NOLOCK) ON d.InvDocDetailsID=a.InvDocDetailsID
JOIN COM_CC50073 s WITH(NOLOCK) on s.NodeID=b.dcCCNID73
WHERE a.CostCenterID=40092 and a.StatusID=369 and ISDATE(d.dcAlpha5)=1 and ISDATE(d.dcAlpha6)=1 and
Convert(datetime,d.dcAlpha5)<=Convert(datetime,@Date) and Convert(datetime,d.dcAlpha6)>=Convert(datetime,@Date) and b.dcCCNID51=@EmployeeID

                                        
--dOCUMENT DATA QUERY                              
	Select isnull(max(convert(varchar(5),cast(isnull(td.dcAlpha2,'') as time),108 )),'') LastInTime,isnull(max(convert(varchar(5),cast(isnull(td.dcAlpha4,'') as time),108 )),'') LastOutTime
	,isnull(max(td.dcAlpha1),'') LastInDate,
	isnull(max(td.dcAlpha3),'') LastOutDate, 
	max( id.docid) DocID ,max( id.docprefix) Prefix ,max( id.docnumber) docnumber
	from Inv_DocDetails id with(nolock),COM_DocCCData cc with(nolock) ,COM_DocTextData td with(nolock) 
	where id.invdocdetailsid=cc.invdocdetailsid and id.invdocdetailsid=td.invdocdetailsid and id.costcenterid=40089 
	and ISDATE(dcAlpha1)=1 and convert(datetime,td.dcAlpha1)=''+CONVERT(NVARCHAR,@Date) +'' and isnull(cc.dcCCNID51,'')= @EmployeeID
                                                
                                                --DOCUMENT DATA
	Select isnull(max(convert(varchar(5),cast(isnull(td.dcAlpha2,'') as time),108 )),'') LastInTime,isnull(max(convert(varchar(5),cast(isnull(td.dcAlpha4,'') as time),108 )),'')  LastOutTime 
	,isnull(max(td.dcAlpha1),'') LastInDate,
	isnull(max(td.dcAlpha3),'') LastOutDate, 
	max( id.docid) DocID ,max( id.docprefix) Prefix ,max( id.docnumber) docnumber
	from Inv_DocDetails id with(nolock),COM_DocCCData cc with(nolock) ,COM_DocTextData td with(nolock) 
	where id.invdocdetailsid=cc.invdocdetailsid and id.invdocdetailsid=td.invdocdetailsid and id.costcenterid=40089
	and ISDATE(dcAlpha3)=1 and convert(datetime,td.dcAlpha3)='' + CONVERT(NVARCHAR,@Date) + '' and isnull(cc.dcCCNID51,'')= @EmployeeID

     EXEC [spPAY_ExtGetESSWeekdays] @DATE,@DATE,@EMPLOYEEID,@USERID,@LANGID                                     
      --LEAVES EXIST OR NOT
                                                
      IF ((SELECT count(*)  FROM Inv_DocDetails ID with(nolock) join Com_DocTextData TD with(nolock) on ID.InvDocDetailsID=TD.InvDocDetailsID
		JOIN Com_DocCCData CC WITH(NOLOCK) ON ID.InvDocDetailsID=CC.InvDocDetailsID
		WHERE  CC.DCCCNID51=@EmployeeID AND ID.COSTCENTERID=40072 
		AND isnull(TD.DCALPHA16,'''')='No' AND Isdate(TD.dcAlpha2)=1 And IsDate(TD.dcAlpha3)=1
		AND Convert(DateTime,CONVERT(NVARCHAR,@Date)) Between Convert(DateTime,TD.dcAlpha2) And Convert(DateTime,TD.dcAlpha3)
		AND ID.StatusID=369)>0)
		BEGIN
				SELECT top 1 ID.DocID as DocID,ID.CostCenterID as CostCenterID, TD.dcAlpha2 as FromDate,TD.dcAlpha3 as ToDate ,pc.Name as LeaveName FROM Inv_DocDetails ID with(nolock) join Com_DocTextData TD with(nolock) on ID.InvDocDetailsID=TD.InvDocDetailsID
				JOIN Com_DocCCData CC WITH(NOLOCK) ON ID.InvDocDetailsID=CC.InvDocDetailsID
				left join COM_CC50052 pc with(nolock) on CC.dcCCNID52=pc.NodeID 
				WHERE  CC.DCCCNID51=@EmployeeID AND ID.COSTCENTERID=40072 
				AND isnull(TD.DCALPHA16,'''')='No' AND Isdate(TD.dcAlpha2)=1 And IsDate(TD.dcAlpha3)=1
				AND Convert(DateTime,CONVERT(NVARCHAR,@Date)) Between Convert(DateTime,TD.dcAlpha2) And Convert(DateTime,TD.dcAlpha3)
				AND ID.StatusID=369
		END	
		ELSE IF ((Select  COUNT(*)  From Inv_DocDetails ID with(nolock)
				Inner Join Com_DocTextData TD with(nolock) on ID.InvDocDetailsID=TD.InvDocDetailsID
				Inner Join Com_DocCCData CC with(nolock) on ID.InvDocDetailsID=CC.InvDocDetailsID
				Where   ID.CostCenterId=40062 And CC.dcCCnid51=@EmployeeID And Isdate(TD.dcAlpha4)=1 And IsDate(TD.dcAlpha5)=1 AND ID.StatusID not in (372,376)
			    And Convert(DateTime,CONVERT(NVARCHAR,@Date)) Between Convert(DateTime,TD.dcAlpha4) And Convert(DateTime,TD.dcAlpha5))>0)						    
		BEGIN
			 Select  ID.DocID as DocID,ID.CostCenterID as CostCenterID,TD.dcAlpha4 as FromDate,TD.dcAlpha5 as ToDate,cc.dcCCNID52 as LEaveNodeID,pc.Name as LeaveName ,* From Inv_DocDetails ID with(nolock)
				Inner Join Com_DocTextData TD with(nolock) on ID.InvDocDetailsID=TD.InvDocDetailsID
				Inner Join Com_DocCCData CC with(nolock) on ID.InvDocDetailsID=CC.InvDocDetailsID
				left join COM_CC50052 pc with(nolock) on CC.dcCCNID52=pc.NodeID 
				Where   ID.CostCenterId=40062 And CC.dcCCnid51=@EmployeeID And Isdate(TD.dcAlpha4)=1 And IsDate(TD.dcAlpha5)=1 AND ID.StatusID not in (372,376)
			    And Convert(DateTime,CONVERT(NVARCHAR,@Date)) Between Convert(DateTime,TD.dcAlpha4) And Convert(DateTime,TD.dcAlpha5)
		END
		ELSE
		SELECT 0 AS LEAVEEMPTY	 	
                                        
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
