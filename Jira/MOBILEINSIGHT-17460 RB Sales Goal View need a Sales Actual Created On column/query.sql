--select * from Objects where objectname like '%salesgoal%'

select   s.StoreName as "Store name",   s.StoreNumber as "Store number",   s.PhoneNumber as "Store Phone number"
,   s.CertifiedStorenickname as "Certified store nickname",   s.ServicedBy "Seviced by",   s.StoreLatitude "Store latitude"
,   s.StoreLongitude "Store longitude",   s.TimeZone "Timezone",   s.IsActive "Is store active",   s.StoreVisitRule "Store visit rule"
,   s.StoreVisitsCategory "Store visit category",   s.StoreVisitEffectiveDate "Store visit effective date",   s.Address "Address"
,   s.City "City",   state.StateName "State",   s.Zipcode "Zipcode",   a.AccountName "Account name"
,   sd.StoreDesignation "Store designation",   st.StoreType "Store type",   dr_store.Division "Store division"
,   dr_store.market_Cluster "Store market cluster",   dr_store.region "Store region",   dr_store.TimeZone "DivsionRegion Timezone"
,   u.UserName "Username",   u.FirstName "First name",   u.LastName "Last name",   u.FullName "Full name",   u.CreatedOn "Created on"
,   u.EmailAddress "Email address",   u.LastLogined "Last logged in",   u.OnBordingDate "On boarding date",   u.Timezone "User Timezone"
,   u.PhoneNo "Phone number",   u.MobileNumber "Mobile number",   dr.Division "User division",   dr.market_cluster "User market cluster"
,   dr.region "User region",   dr.TimeZone "User Division region timezone",   urf.BusinessRoleName "User hierarchy name"
,   u_mgr.UserName "Manager Username",   u_mgr.FirstName "Manager First name",   u_mgr.LastName "Manager Last name"
,   u_mgr.FullName "Manager Full name",   u_mgr.CreatedOn "Manager Created on",   u_mgr.EmailAddress "Manager Email address"
,   u_mgr.LastLogined "Manager Last logged in",   u_mgr.OnBordingDate "Manager On boarding date",   u_mgr.Timezone "Manager Timezone"
,   u_mgr.PhoneNo "Manager Phone number",   u_mgr.MobileNumber "Manager Mobile number",   br_mgr.BusinessRoleName "Manager User hierarchy name"
,   sgt.Name "Sales Goal Type Name",   sgt.isActive "Sales Goal Type Is Active",   sgt.valueType "Sales Goal Type Value Type"
,   sgt.showPercentage "Sales Goal Type Show Percentage",   sgt.quotaType "Sales Goal Type Quota Type",sgad.MonthYear "Month/Year"
,   sgad.Data "Sales Goals Actual Data",  sgad.CreatedOn AS "Sales Actual Created On", ssga.MonthlyTarget "Store Sales Goals Assignment Monthly Target"
,   usgs.MonthlyTotal "User Sales Goals Summary Monthly Total",   usgs.LeftToAssign "User Sales Goals Summary Left To Assign"
,   usgs.Status "User Sales Goals Summary Status"  
from Downline_NoTestData(22, 314) urf      --store details   
join storeusermapping sm on sm.userid = urf.userId   
join store s on s.storeid = sm.storeid and s.orgId=22   
join Account a on a.accountid = s.accountId and a.orgId=22   
left join storedesignation sd on sd.storedesignationid = s.storedesignationId   
left join storestype st on st.storetypeid = s.storetypeid   
join divisionregion dr_store on dr_store.divisionregionid = s.divisionregionid      --user details   
join users u on urf.userid = u.userId   
join userdivisionregionmapping udrm on udrm.userId = u.userId   
join divisionregion dr on dr.divisionregionId = udrm.divisionregionId and dr.orgId = 22      --user manager   
left join users u_mgr on u_mgr.userid = urf.UserParentId   
left join userorgprofile uop_mgr on uop_mgr.userid = u_mgr.userid and uop_mgr.orgid = 22    
left join businessrole br_mgr on br_mgr.BusinessRoleId = uop_mgr.BusinessRoleId     --sales goals details   
join UserSalesGoalSummary usgs on usgs.userid = u.userid   
join SalesGoalsActualsData sgad on sgad.storeid = s.storeid and sgad.MonthYear = usgs.MonthYear   
join StoreSalesGoalAssignment ssga on ssga.storeid = s.storeid and usgs.UserSalesGoalSummaryId = ssga.UserSalesGoalSummaryId   
join SalesGoalType sgt on sgt.salesgoaltypeid = usgs.salesgoaltypeid   
join state on state.stateid = s.stateid  
WHERE s.StoreNumber = '10032' 