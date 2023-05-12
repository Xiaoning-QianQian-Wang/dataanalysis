/*
Central Park squirrels Data Exploration 

Skills used: Subquery, Temp Tables, Aggregate Functions, Unpivot tables, Converting Data Types

Data Analysis on following questions:
1. What was the date for the highest number of sightings?
2. Who runs more, adults or juveniles?
3. In which areas are squirrels more willing to approach humans?
4. How many sighting include more than 1 acitivities?
5. How would squirrels interact most frequently?

*/

--1. What was the date for the highest number of sightings?

SELECT TOP 1
       date
      ,count(*) AS number_of_sightings
FROM dbo.Central_Park_Squirrel_Census
GROUP BY date
ORDER BY count(*) DESC

--2. Who runs more, adults or juveniles?

SELECT Age
       ,SUM(CAST(RUNNING AS decimal)) AS number_of_running
	   ,COUNT(*) AS number_of_sightings
	   ,CONCAT(CAST(SUM(CAST(RUNNING AS FLOAT))/COUNT(*)*100 AS DECIMAL(5,2)),'%') as running_percentage
FROM dbo.Central_Park_Squirrel_Census
WHERE age IN ('Adult','Juvenile')
AND Running IS NOT NULL
GROUP BY Age

--3. In which areas are squirrels more willing to approach humans?

SELECT Hectare
      ,SUM(CAST(approaches AS INT)) AS number_of_approaches
	  ,(SELECT COUNT(*) 
	   FROM dbo.Central_Park_Squirrel_Census
	   WHERE Hectare=T1.Hectare)    AS number_of_sightings
	  ,CAST(SUM(CAST(approaches AS FLOAT))/(SELECT COUNT(*) 
									   FROM dbo.Central_Park_Squirrel_Census
									   WHERE Hectare=T1.Hectare)*100 AS decimal(5,2)) as approach_liklihood
FROM dbo.Central_Park_Squirrel_Census T1
GROUP BY Hectare
ORDER BY approach_liklihood DESC


--4. How many sighting include more than 1 acitivities?

drop table if exists #actsummary
SELECT   X
      ,Y
	  ,Unique_Squirrel_ID
	  ,Hectare
	  ,Shift
	  ,Hectare_Squirrel_Number
	  ,Age
	  ,Activities
	  ,Act
into #actsummary
FROM
		(
		SELECT X
				,Y
				,Unique_Squirrel_ID
				,Hectare
				,Shift
				,Hectare_Squirrel_Number
				,Age
				,Running
				,Chasing
				,Climbing
				,Eating
				,Foraging
				--,Other_Activities
		FROM dbo.Central_Park_Squirrel_Census
		) P
		UNPIVOT
		(     
				Act for Activities IN
				([Running]
				,[Chasing]
				,[Climbing]
				,[Eating]
				,[Foraging]
				--,[Other_Activities]
				)
		) AS upvt

select count(*) as number_of_sighting_with_multiple_activities
from (
select x,y,Unique_Squirrel_ID
from #actsummary
where act='1'
group by x,y,Unique_Squirrel_ID
having count(act)>1 ) as t2



--5. How would squirrels interact most frequently?

drop table if exists #interactsummary
SELECT   X
      ,Y
	  ,Unique_Squirrel_ID
	  ,Hectare
	  ,Shift
	  ,Hectare_Squirrel_Number
	  ,Age
	  ,Interactions
	  ,Act
into #interactsummary
FROM
		(
		SELECT X
				,Y
				,Unique_Squirrel_ID
				,Hectare
				,Shift
				,Hectare_Squirrel_Number
				,Age
				,Kuks
				,Quaas
				,cast(Moans AS BIT) AS Moans
				,Tail_flags
				,Tail_twitches
				,Approaches
				,Indifferent
				,Runs_from
		FROM dbo.Central_Park_Squirrel_Census
		) P2
		UNPIVOT
		(     
				Act for Interactions IN
				([Kuks]
				,[Quaas]
				,[Moans]
				,[Tail_flags]
				,[Tail_twitches]
				,[Approaches]
				,[Indifferent]
				,[Runs_from]
				)
		) AS upvt2


select Interactions
      ,count(*) as number_of_interactions
from #interactsummary
where act=1
group by Interactions
order by count(*) desc






