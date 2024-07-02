USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_PayrollWorksheetData]
	@Flag [int] = 0,
	@EmpNode [int] = 0,
	@PayrollMonth [datetime],
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  
If (Isnull(@Flag,0)=0)
Begin 
	SELECT Top 1 A.InvDocDetailsID,A.DocID,A.CostCenterID,A.VoucherNo,CONVERT(DATETIME,A.DocDate) as DocDate
	FROM INV_DocDetails A WITH(NOLOCK) 	JOIN COM_DocCCData B WITH(NOLOCK) ON B.INVDOCDETAILSID=a.INVDOCDETAILSID JOIN COM_DocTextData d WITH(NOLOCK) ON d.INVDOCDETAILSID=a.INVDOCDETAILSID
	WHERE d.tCostCenterID=40079 and a.StatusID=369 AND B.dccCNID51=@EmpNode AND ISDATE(d.dcAlpha1)=1 AND CONVERT(DATETIME,d.dcAlpha1)=CONVERT(DATETIME,@PayrollMonth)
End
Else if (Isnull(@Flag,0)=1)
Begin 
	Declare @TabWorksheet Table(ID Int Identity(1,1),PayrollMonth DateTime,DaysAttended float,AbsentDays float,OT1 float, OT1ID INT,
								OT2 float, OT2ID INT,OT3 float, OT3ID INT,OT4 float, OT4ID INT,OT5 float, OT5ID INT)
	Declare @TabOTMap Table(ID Int Identity(1,1),OTType Varchar(10),NodeID Int,PayrollMonth DateTime)
									
	Insert into @TabWorksheet								
	SELECT Convert(DateTime,TD.dcAlpha1) PayrollMonth,Isnull(TD.dcAlpha2,0) DaysAttended,Isnull(TD.dcAlpha3,0) AbsentDays ,
	ND.dcNum5 as OT1,0,ND.dcNum7 as OT2,0,
	ND.dcNum9 as OT3,0,ND.dcNum11 as OT4,0,ND.dcNum13 as OT5,0
	FROM INV_DocDetails ID WITH(NOLOCK) 
	JOIN COM_DocCCData CC WITH(NOLOCK) ON CC.INVDOCDETAILSID=ID.INVDOCDETAILSID 
	JOIN COM_DocTextData TD WITH(NOLOCK) ON TD.INVDOCDETAILSID=ID.INVDOCDETAILSID
	JOIN COM_DocNumData ND WITH(NOLOCK) ON ND.INVDOCDETAILSID=ID.INVDOCDETAILSID
	WHERE TD.tCostCenterID=40079 and ID.StatusID=369 AND ISDATE(TD.dcAlpha1)=1 AND CC.dccCNID51=@EmpNode AND  CONVERT(DATETIME,TD.dcAlpha1)=CONVERT(DATETIME,@PayrollMonth)
	
	Insert into @TabOTMap
	Select CCD.UserColumnName,Isnull(DD.Distributeon,0) Distributeon,@PayrollMonth 
	From Adm_CostCenterDef CCD  WITH(NOLOCK) join Adm_DocumentDef DD WITH(NOLOCK) on CCD.CostCenterColID=DD.CostCenterColID 
	AND ISNUMERIC(DD.Distributeon)=1 And CCD.CostCenterID=40067 And Convert(Int,Isnull(DD.Distributeon,0))>0
	
	--Update T Set OT1ID=T1.NodeID from @TabWorksheet T,@TabOTMap T1 Where T.PayrollMonth=T1.PayrollMonth And T1.ID=1
	--Update T Set OT2ID=T1.NodeID from @TabWorksheet T,@TabOTMap T1 Where T.PayrollMonth=T1.PayrollMonth And T1.ID=2
	--Update T Set OT3ID=T1.NodeID from @TabWorksheet T,@TabOTMap T1 Where T.PayrollMonth=T1.PayrollMonth And T1.ID=3
	--Update T Set OT4ID=T1.NodeID from @TabWorksheet T,@TabOTMap T1 Where T.PayrollMonth=T1.PayrollMonth And T1.ID=4
	--Update T Set OT5ID=T1.NodeID from @TabWorksheet T,@TabOTMap T1 Where T.PayrollMonth=T1.PayrollMonth And T1.ID=5
	
	Select * From @TabWorksheet
	Select * From @TabOTMap
End
			 
SET NOCOUNT OFF;     
RETURN 1
END TRY
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
IF ERROR_NUMBER()=50000  
BEGIN  
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
END  
ELSE  
BEGIN  
	SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine  
	FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
