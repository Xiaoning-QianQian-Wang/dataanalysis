/*Olympic game analysis Data Exploration 

Skills used: join, CTE, Temp Tables, window function, Rollup, Converting Data Types*/


--1. Who are the swimming champions who regin gold mendal in the same event for 2 continuous times?
--2. For each hosting city, which city is the next to host olympic game?
--3. For each event, when was first included in Olympics and who was the champion?
--4. In 2016, rank coutry by medal numbers in each type?
--5. List the TOP 33% country who won the most godel medals in 2016.
--6. Return running total and max medals order by game year for each country.
--7. What is the moving average of gold medal number for 3 games for countray USA?
--8. Return the medal results for each country in 2020, for each country include medal number for each type and grand total.


drop table if exists #medal_summary

SELECT LEFT(OH.game_name,len(OH.game_name)-(CHARINDEX(' ',REVERSE(OH.game_name))-1)-1) AS City
      ,OH.game_year
	  ,'' AS Sport
	  ,ORS.discipline_title
	  ,ORS.event_title
	  ,CASE WHEN ORS.athlete_full_name IS NULL THEN ORS.country_name
	        ELSE ORS.athlete_full_name END AS athlete_name
	  ,ORS.country_name
	  ,ORS. medal_type
INTO #medal_summary
FROM [MyPortfolio].[dbo].[olympic_results] ORS
LEFT JOIN dbo.olympic_hosts OH on OH.game_slug=ORS.slug_game-- AND OH.game_season='Summer' 
WHERE ORS.medal_type IS NOT NULL
AND OH.game_season='Summer' 


--1. Who are the swimming champions who regin gold mendal in the same event for 2 continuous times?
WITH swimming_champion AS(
SELECT event_title
      ,discipline_title
	  ,game_year
	  ,country_name
	  ,athlete_name as champion
	  --,ROW_NUMBER() OVER(PARTITION BY discipline_title,event_title ORDER BY game_year) AS row_num
	  ,LAG(athlete_name,1) OVER(PARTITION BY discipline_title,event_title ORDER BY game_year ASC) AS last_champion
FROM #medal_summary
WHERE medal_type='GOLD'
AND discipline_title like '%swimming%')


SELECT  event_title,game_year,champion,country_name
FROM swimming_champion
WHERE champion=last_champion
AND country_name <>champion


--2. For each hosting city, which city is the next to host olympic game?
WITH host_cities_by_season AS(
SELECT LEFT(game_name,len(game_name)-(CHARINDEX(' ',REVERSE(game_name))-1)-1) AS City
      ,game_year
	  ,game_season
FROM dbo.olympic_hosts)


SELECT game_year
      ,city
	  ,LEAD(city,1) OVER(PARTITION BY game_season ORDER BY game_year ASC) as next_city
	  ,game_season
FROM host_cities_by_season
ORDER BY game_season,game_year

--3. For each event, when was first included in Olympics and who was the champion?
SELECT discipline_title
      ,event_title
	  ,game_year as first_year
	  ,FIRST_VALUE(athlete_name) OVER(PARTITION BY discipline_title,event_title ORDER BY game_year ASC) as first_champion
FROM #medal_summary
WHERE medal_type='GOLD'
ORDER BY discipline_title,event_title,game_year


--4. In 2016, rank coutry by medal numbers in each type?
WITH numbers_by_type AS(
SELECT country_name
      ,medal_type
	  ,count(*) as medal_number
FROM #medal_summary
WHERE game_year=2016
GROUP BY country_name,medal_type)

SELECT *
      ,RANK() OVER(PARTITION BY medal_type ORDER BY medal_number desc) as country_rank
FROM numbers_by_type
ORDER BY medal_type,medal_number desc

--5.List the TOP 33% country who won the most godel medals in 2016

WITH top_gold_medal AS(
SELECT country_name
	  ,count(*) as gold_number
FROM #medal_summary
WHERE game_year=2016
and   medal_type='GOLD'
GROUP BY country_name)

select row_number() OVER(ORDER BY gold_number DESC) as [rank]
       ,country_name
       ,gold_number
from(
select *
      ,NTILE(3) OVER (ORDER BY gold_number DESC) as Tile
from top_gold_medal
) t1
where tile=1
order by gold_number desc

--6. Return running total and max medals order by game year for each country
With Contry_medals AS(
SELECT country_name
      ,game_year
	  ,COUNT(*) as medal_number
FROM #medal_summary
group by country_name,game_year )

SELECT country_name
       ,game_year
	   ,medal_number
	   ,SUM(medal_number) OVER(PARTITION BY country_name ORDER BY game_year) as Running_total_medal
	   ,MAX(medal_number) OVER(PARTITION BY country_name ORDER BY game_year) as max_medal_number
FROM Contry_medals
--WHERE country_name='United States of America'
ORDER BY country_name,game_year

--7. What is the moving average of gold medal number for 3 games for countray USA?
With USA_medals AS(
SELECT country_name
      ,game_year
	  ,COUNT(*) as medal_number
FROM #medal_summary
WHERE country_name='United States of America'
group by country_name,game_year )

SELECT  country_name
      ,game_year
	  ,medal_number
	  ,AVG(medal_number) OVER(ORDER BY game_year ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS Moving_average
FROM USA_medals
ORDER BY game_year

--8.  Return the medal results for each country in 2020, for each country include medal number for each type and grand total
With Contry_medals_2020 AS(
SELECT country_name
      ,game_year
	  ,medal_type
	  ,COUNT(*) as medal_number
FROM #medal_summary
WHERE game_year=2020
group by country_name,game_year )

SELECT COALESCE(country_name,'All country medals') as country
      ,COALESCE(medal_type,'Sum for the country') as medal_type
	  ,count(*) medal_number
FROM #medal_summary
WHERE game_year=2020
GROUP BY ROLLUP(country_name,medal_type)
ORDER BY country_name desc,medal_type
