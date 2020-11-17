--ConsoPick___----------------------------------																
--CONSO Picker Productivity Query																
---------------------------------------------																
Select 	src.emailaddress
		,'2020-11-05 00:00:00' as ConsoPick_StartDate														
		--,src.totalnotfound													
		--,src.B2B_Picking_Qty as B2B_Qty														
		--,src.B2C_Picking_Qty as B2C_Qty
		,src.ordercount as No_of_Orders
		--,src.totalprocess as Total_Quantity														
		,tgt.Total_Working_Hrs as Total_Working_Hrs														
		,Round(((src.ordercount/tgt.Total_Working_Seconds)*60*60)::numeric,2) as EPH_Orders	
		--,Round(((src.totalprocess/tgt.Total_Working_Seconds)*60*60)::numeric,2) as EPH_Quantity	
		--,src.BabyGear_Qty,src.Consumable_Qty
		,'whracks10' as Warehouse
From( 																
	--To get Conso Pick Details															
Select  "emailaddress", sum("quantity") as totalpick, sum("processquantity") as totalprocess																
		,sum("notfoundquantity") as totalnotfound 														
		,sum(case when businesstype = 'B2B' then processquantity else 0 end) as B2B_Picking_Qty														
		,sum(case when businesstype = 'B2C' then processquantity else 0 end) as B2C_Picking_Qty														
		,sum(case when productcatid = '7' then processquantity else 0 end) as BabyGear_Qty														
		,sum(case when productcatid = '999' then processquantity else 0 end) as Consumable_Qty
		,count(distinct poid) as ordercount
		--,count(distinct whpoid) as ordercount1
From(--For Final GroupBy																
 Select * From(--For Union																
  Select Distinct J1.id,"emailaddress","businesstype", "quantity", "processquantity", "notfoundquantity"																
	             ,J1.productid, productcatid,poid,whpoid															
  From( --For Join with fc_productdetails																
   SELECT "id","emailaddress","businesstype", "quantity", "processquantity"
	  	, "notfoundquantity","productid"			
	  	,poid, whpoid
        FROM whracks10.orderitemsrackconsodetails																
        WHERE   (																
        "processquantity" >0																
        OR "notfoundquantity" >0																
         )																
        AND   (																
        "taskid" IN(SELECT distinct "taskid"																
                    FROM whracks10.taskmaster																
                    WHERE "tasktype" = 'ConsoOut'																
                    AND   (																
                    ("startdate" between '2020-11-05 00:00:00' and '2020-11-05 11:59:59' or  "enddate" between '2020-11-05 00:00:00' and '2020-11-05 11:59:59')																
                    OR ('2020-11-05 00:00:00' between "startdate" and enddate or '2020-11-05 11:59:59' between "startdate" and enddate)																
                 		)														
        			)													
			)													
        AND "lastmodifieddate" < '2020-11-05 11:59:59'																
        AND "lastmodifieddate" > '2020-11-05 00:00:00' 																
	)J1															
	Left Join orderworkflow.fc_productdetails as J2															
	on J1.productid = J2.productid)U															
Union All																
 Select Distinct J1.id,"emailaddress","businesstype", "quantity", "processquantity", "notfoundquantity"																
				,J1.productid, productcatid,poid,whpoid												
 From( --For Join with fc_productdetails																
	SELECT "id","emailaddress","businesstype", "quantity"
	 		, "processquantity", "notfoundquantity","productid"		
	 		,poid, whpoid
    FROM whracksarchive10.orderitemsrackconsodetails																
    WHERE ("processquantity" >0 OR "notfoundquantity" >0)																
        AND (																
        	taskid IN(SELECT distinct "taskid"															
                    FROM whracksarchive10.taskmaster																
                    WHERE "tasktype" = 'ConsoOut'																
                    AND   (																
                    ("startdate" between '2020-11-05 00:00:00' and '2020-11-05 11:59:59' or  "enddate" between '2020-11-05 00:00:00' and '2020-11-05 11:59:59')																
                    OR ('2020-11-05 00:00:00' between "startdate" and enddate or '2020-11-05 11:59:59' between "startdate" and enddate)																
                 			)													
        				)												
		)														
        AND "lastmodifieddate" < '2020-11-05 11:59:59'																
        AND "lastmodifieddate" > '2020-11-05 00:00:00' 																
	)J1															
	Left Join orderworkflow.fc_productdetails as J2															
	on J1.productid = J2.productid															
)Final1																
Group By 1																
Order By 1																
)src																
-- get total working hours: 																
Left Join (																
Select emailaddress																
		,Sum(Case When Working_Seconds < 0 
			 Then Working_interval+'2020-11-05 11:59:59'::timestamp-'2020-11-05 00:00:00'::timestamp 
			 Else Working_interval End) as Total_Working_Hrs														
		,Sum(Case When Working_Seconds < 0 
			 Then Working_Seconds+(date_part('day','2020-11-05 11:59:59'::timestamp-'2020-11-05 00:00:00'::timestamp )*24*60*60														
								+ date_part('hour','2020-11-05 11:59:59'::timestamp-'2020-11-05 00:00:00'::timestamp )*60*60
								+ date_part('minute','2020-11-05 11:59:59'::timestamp-'2020-11-05 00:00:00'::timestamp )*60
								+ date_part('second','2020-11-05 11:59:59'::timestamp-'2020-11-05 00:00:00'::timestamp ) )  
			 Else Working_Seconds End) As Total_Working_Seconds													
From(																
Select 	emailaddress															
		,Sum(Case When status in ('out') then diff_interval end)
			-Sum(Case When status = 'in' then diff_interval end) as Working_interval														
		,Sum(Case When status in ('out') then diff_in_seconds end)
			-Sum(Case When status = 'in' then diff_in_seconds end) as Working_Seconds														
From(
Select emailaddress, status,  actiontime
	,date_part('day',actiontime-'2020-11-05 00:00:00' )*1440*60 												
					+ date_part('hour',actiontime-'2020-11-05 00:00:00' )*60*60 											
					+ date_part('minute',actiontime-'2020-11-05 00:00:00' )*60
					+ date_part('second',actiontime-'2020-11-05 00:00:00' )as diff_in_seconds											
	,actiontime-'2020-11-05 00:00:00'::timestamp as diff_interval
From(
	SELECT emailaddress, status,  actiontime, logid
 	   ,lag(status) OVER (Partition by emailaddress ORDER BY logid) as prev_to
	FROM whracks10.userworkdetails_log
	Where actiontime between '2020-11-05 00:00:00' and '2020-11-05 11:59:59'
    AND status in ('in', 'out') 
	AND modulename in ('b2c_pick_completed_orders', 'b2c_not_found_list')	
	order by emailaddress, logid
) table1
	Where prev_to ISNULL or status<> prev_to												
)WH																
Group By 1																
)WH																
Group By 1																
)tgt 																
On src.emailaddress=tgt.emailaddress																
Order By src.emailaddress

--select * from  whracksarchive10.orderitemsrackconsodetails limit 10
