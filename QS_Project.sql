USE QS_Project
GO	
									/* QS_Project */
								
/* I scraped the data from Qatar Sale website (https://qatarsale.com/en/products/cars_for_sale). 
Due to the limitations of the scraper, I had stop the scraping and download the CSV file and start again. I ended up having 12 CSV files containg a total of 10.6k rows of data.
I used Power Query to get the data in shape and append all the 12 files.

This is the M Language code for geting the data in the shape I wanted (deleting some rows and renaming the headers. I had to change the code a little bit for some files.
	 let
		Source = Csv.Document(File.Contents("D:\***file path****\qatarsale (2).csv"),[Delimiter=",", Columns=17, Encoding=1252, QuoteStyle=QuoteStyle.None]),
		#"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
		#"Changed Type" = Table.TransformColumnTypes(#"Promoted Headers",{{"product-img href", type text}, {"product-img src", type text}, {"product-details href", type text}, {"p3", type text}, {"p5", type text}, {"p5 2", type text}, {"def-value", Int64.Type}, {"def-value 2", type text}, {"def-value 3", Int64.Type}, {"def-value 4", Int64.Type}, {"p4", type text}, {"p1", Int64.Type}, {"p5 3", type text}, {"showroom-name href", type text}, {"p5 4", type text}, {"img-loading href", type text}, {"img-loading src", type text}}),
		#"Removed Columns" = Table.RemoveColumns(#"Changed Type",{"img-loading href", "img-loading src", "p4", "p5 4", "product-img href", "product-img src"}),
		#"Renamed Columns" = Table.RenameColumns(#"Removed Columns",{{"product-details href", "Id"}, {"p3", "Make"}, {"p5", "Model"}, {"p5 2", "Variant"}, {"showroom-name href", "Dealer Id"}, {"p5 3", "Dealer"}, {"def-value", "Mileage"}, {"def-value 2", "Transmission"}, {"def-value 3", "Year"}, {"def-value 4", "Engine"}, {"p1", "Price"}})
	in
		#"Renamed Columns" 

Then I appended them all in 1 file:
	 let
		Source = Table.Combine({set1, #"set1 (2)", set2, set3, set4, set5, set6, set7, #"set2 1", #"set2 1 (2)", #"set2 3", #"set2 4", #"set2 5", #"set2 2"}),
		#"Reordered Columns" = Table.ReorderColumns(Source,{"Id", "Make", "Model", "Variant", "Year", "Mileage", "Price", "Engine", "Transmission", "Dealer", "Dealer Id"})
	in
		#"Reordered Columns" 

The makes table has all the distinct makes from the appended file. I entered the country by myself depending on my knowledge or my search.

*/

					/* Imported the data from Excel. */
SELECT *
FROM Makes

SELECT *
FROM QatarSaleData

							/* The Cleaning */

-- Sorting Year datatype
SELECT *, CAST(Year AS int)
FROM QatarSaleData

ALTER TABLE QatarSaleData
ALTER COLUMN Year int

-- Rounding up the mileage to thousends, to get rid off non-sensable values.
SELECT Mileage , FLOOR ((Mileage + 999) /1000) *1000
FROM QatarSaleData

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Mileage = FLOOR ((Mileage + 999) /1000) *1000

COMMIT TRANSACTION

-- These transmission types are bothering me (Tiptronic doesn't make sence, it is automatic after all).
SELECT DISTINCT Transmission
FROM QatarSaleData
SELECT * FROM QatarSaleData
WHERE Transmission = 'Tiptronic' OR Transmission = 'F-1'

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Transmission = 'Automatic'
WHERE Transmission = 'Tiptronic'
OR Transmission = 'F-1'

SELECT *
FROM QatarSaleData
WHERE Transmission NOT IN ('AUTOMATIC', 'MANUAL')

COMMIT TRANSACTION

-- Extracting the product id
	-- It is the numbers at the end (after the dash -)
SELECT Id, PARSENAME(REPLACE(Id,'-','.'),1)
FROM QatarSaleData

ALTER TABLE QatarSaleData
ADD Product_Id NVARCHAR(5)

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Product_Id = PARSENAME(REPLACE(Id,'-','.'),1)

COMMIT TRANSACTION

-- Removing Duplicates
SELECT DISTINCT Product_Id
FROM QatarSaleData

SELECT *, ROW_NUMBER() OVER (PARTITION BY Product_Id ORDER BY Product_Id, Price ) AS RowNumber
FROM QatarSaleData
WHERE 1=1

WITH RowNum AS (
SELECT *, ROW_NUMBER() OVER (PARTITION BY Product_Id ORDER BY Product_Id, Price ) AS RowNumber
FROM QatarSaleData )
--SELECT *
DELETE 
FROM RowNum 
WHERE RowNumber > 1

SELECT *
FROM QatarSaleData

-- The scraper picked up Q.R as variant or model for some rows

--SEELCT * FROM 
UPDATE 
QatarSaleData
SET Variant = NULL
WHERE Variant = 'Q.R'

--SELECT * FROM 
UPDATE 
QatarSaleData
SET Model = Variant, Variant = NULL
WHERE Model = 'Q.R'

-- Extracting the dealer id from the the link
SELECT DISTINCT Dealer_Id
FROM QatarSaleData

SELECT Dealer_Id, Dealer, SUBSTRING(Dealer_Id, LEN(Dealer_Id) - CHARINDEX('/',REVERSE(Dealer_Id)) + 2, LEN(Dealer_Id))
FROM QatarSaleData
WHERE Dealer_Id IS NOT NULL
AND Dealer_Id <> ''

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Dealer_Id = SUBSTRING(Dealer_Id, LEN(Dealer_Id) - CHARINDEX('/',REVERSE(Dealer_Id)) + 2, LEN(Dealer_Id))
WHERE Dealer_Id IS NOT NULL
AND Dealer_Id <> ''

COMMIT TRANSACTION

-- Now lets sort the dealer situation. 

SELECT DISTINCT Dealer
FROM QatarSaleData

	-- The scraper picked up Q.R as dealer for some rows. So, I will get rid of it.
SELECT *
FROM QatarSaleData
WHERE Dealer = 'Q.R'

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Dealer = ''
WHERE Dealer = 'Q.R'
COMMIT TRANSACTION
	
	-- The scraper picked up the dealer as variant for some rows. So, I will shift it to Dealer.
SELECT *
FROM QatarSaleData
WHERE Variant IN (SELECT DISTINCT Dealer
FROM QatarSaleData)
AND VARIANT IS NOT NULL

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Dealer = Variant, Variant = NULL
WHERE Variant IN (SELECT DISTINCT Dealer
FROM QatarSaleData)
AND VARIANT IS NOT NULL
COMMIT TRANSACTION

-- WHY there are both null and '' ?! Lets standarize that.
SELECT *
FROM QatarSaleData
WHERE Dealer = ''
OR Dealer_Id = ''

UPDATE QatarSaleData
SET Dealer = NULL
WHERE Dealer = ''
UPDATE QatarSaleData
SET Dealer_Id = NULL
WHERE Dealer_Id = ''

	-- There are few rows where dealer is still null even thought there is a dealer id.
SELECT *
FROM QatarSaleData
WHERE Dealer IS NULL 
AND Dealer_Id IS NOT NULL

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Dealer = Variant, Variant = NULL
WHERE Dealer IS NULL 
AND Dealer_Id IS NOT NULL
COMMIT TRANSACTION

	-- There are some rows where dealer id is null even thought there is a dealer
SELECT DISTINCT Dealer, Dealer_Id
FROM QatarSaleData
WHERE Dealer_Id IS NULL
AND Dealer IS NOT NULL

SELECT DISTINCT A.Dealer, A.Dealer_Id, B.Dealer, B.Dealer_Id, ISNULL(A.Dealer_Id, B.Dealer_Id)
FROM QatarSaleData A
JOIN QatarSaleData B ON A.Dealer = B.Dealer
WHERE A.Dealer IS NOT NULL
AND B.Dealer_Id IS NOT NULL
AND A.Dealer_Id IS NULL

BEGIN TRANSACTION
UPDATE A
SET Dealer_Id =  ISNULL(A.Dealer_Id, B.Dealer_Id)
FROM QatarSaleData A
JOIN QatarSaleData B ON A.Dealer = B.Dealer
WHERE A.Dealer IS NOT NULL
AND B.Dealer_Id IS NOT NULL
AND A.Dealer_Id IS NULL
COMMIT TRANSACTION

	-- Now I will convert the null to Private
SELECT *
FROM QatarSaleData
WHERE Dealer IS NULL

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Dealer = 'Private', Dealer_Id = 'private'
WHERE Dealer IS NULL
COMMIT TRANSACTION

	-- I will delete the dealers that are not in Qatar
--SELECT *
DELETE 
FROM QatarSaleData
WHERE Dealer LIKE '%UAE%'
OR Dealer LIKE '%BAHRAIN%'
OR Dealer = 'Auto Capital'

-- I want to add a new column for type (body style)

ALTER TABLE QatarSaleData
ADD Type VARCHAR(50)
	
	-- And I will extract the data from the id (if available)
UPDATE QatarSaleData
SET Type = 
	CASE
		WHEN Id LIKE '%sedan%' THEN 'Sedan'
		WHEN Id LIKE '%hatchback%' THEN 'Hatchback'
		WHEN Id LIKE '%convertible%' THEN 'Convertible'
		WHEN Id LIKE '%classic%' THEN 'Classic'
		WHEN Id LIKE '%suv%' THEN 'SUV'
		WHEN Id LIKE '%pick_up%' THEN 'Pick Up'
		WHEN Id LIKE '%special_needs%' THEN 'Van/Bus'
		WHEN Id LIKE '%van_bus%' THEN 'Van/Bus'
		WHEN Id LIKE '%coupe_sport%' THEN 'Coupe'
	END

		--these are not classics
UPDATE QatarSaleData
SET Type = NULL
--SELECT *
--FROM QatarSaleData
WHERE Product_Id IN ('53337', '59345', '28302', '57722', '54332', '54173', '63605')

-- There are a lot of null values. So, lets figure that out.
SELECT *
FROM QatarSaleData
WHERE Type IS NULL

SELECT DISTINCT Make, Model, Variant
FROM QatarSaleData
WHERE Type IS NULL

	-- For some, there is a matching set of make, model and variant. 
SELECT DISTINCT A.Make, A.Model, A.Variant, A.Type, B.Make, B.Model, B.Variant, B.Type, ISNULL(B.Type, A.Type) AS B_Type
FROM QatarSaleData A
JOIN QatarSaleData B 
ON A.Make = B.Make AND A.Model = B.Model AND A.Variant = B.Variant
WHERE A.Type IS NOT NULL
AND B.Type IS NULL

BEGIN TRANSACTION
UPDATE B
SET Type =  ISNULL(B.Type, A.Type)
FROM QatarSaleData A
JOIN QatarSaleData B
ON A.Make = B.Make AND A.Model = B.Model AND A.Variant = B.Variant
WHERE A.Type IS NOT NULL
AND B.Type IS NULL
COMMIT TRANSACTION

	-- For some reason, not all of them were matcehd and added. So, I wil use another way.
SELECT *
FROM QatarSaleData
WHERE Type IS NULL

WITH CTE1 AS (
SELECT DISTINCT CONCAT_WS( ' ', Make, Model, Variant) AS Car, Make, Model, Variant, Type
from QatarSaleData
WHERE Type IS NOT NULL ) ,
CTE2 AS (
SELECT Car, COUNT(*) AS Count
FROM CTE1
GROUP BY Car
HAVING COUNT(*) = 1 )
--SELECT QS.*, B.Car, A.Type
UPDATE QS
SET QS.Type = A.Type
FROM QatarSaleData QS
JOIN CTE1 A ON CONCAT_WS( ' ', QS.Make, QS.Model, QS.Variant) = A.Car
JOIN CTE2 B ON A.Car = B.Car
WHERE QS.Type IS NULL
 
 	-- There are some of the remainings which match with make and model only
WITH CTE1 AS (
SELECT DISTINCT CONCAT_WS( ' ', Make, Model) AS Car, Make, Model, Type
from QatarSaleData
WHERE Type IS NOT NULL ) ,
CTE2 AS (
SELECT Car, COUNT(*) AS Count
FROM CTE1
GROUP BY Car
HAVING COUNT(*) = 1 )
--SELECT QS.*, B.Car, A.Type
UPDATE QS
SET QS.Type = A.Type
FROM QatarSaleData QS
JOIN CTE1 A ON CONCAT_WS( ' ', QS.Make, QS.Model) = A.Car
JOIN CTE2 B ON A.Car = B.Car
WHERE QS.Type IS NULL

	-- The remaining should have more that 1 type
SELECT *
FROM QatarSaleData
WHERE Type IS NULL

WITH CTE1 AS (
SELECT DISTINCT CONCAT_WS( ' ', Make, Model, Variant) AS Car, Make, Model, Variant, Type
from QatarSaleData
WHERE Type IS NOT NULL ) ,
CTE2 AS (
SELECT Car, COUNT(*) AS Count
FROM CTE1
GROUP BY Car
HAVING COUNT(*) > 1 )
SELECT B.Car, STRING_AGG( A.Type, '; ')
FROM CTE2 B
JOIN CTE1 A
ON A.Car = B.Car
GROUP BY B.Car
	-- While many of them actually have multiple types, some are incorrect entries. So, I will fix them. (By using variables) 
		-- These are that I changed: AUDI S 3, CADILLAC ESCALADE, INFINITI Q 30S, QX 60, LAND CRUISER LX, MINI COOPER
		--	(some without variant): AUDI A7, FERRARI CALIFORNIA, FIAT 500, 595, FROD RAPTOR, GMC SIERRA, HONDA PILOT, HYUNDAI VELOSTER, ISUZU D-MAX, SKODA KAMIQ, TOYOTA HILUX, VW JETTA
DECLARE @Make VARCHAR(50)
DECLARE @Model VARCHAR(50)
DECLARE @Variant VARCHAR(50)
DECLARE @Right_BodyStyle VARCHAR(50);
SET @Make = 'VOLKSWAGEN'
SET @Model = 'JETTA'
-- SET @Variant = 'LX'
SET @Right_BodyStyle = 'SEDAN';

SELECT * FROM QatarSaleData WHERE Make = @Make AND Model = @Model -- AND Variant = @Variant 

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Type = @Right_BodyStyle
WHERE Make = @Make AND Model = @Model -- AND Variant = @Variant

SELECT * FROM QatarSaleData WHERE Make = @Make AND Model = @Model -- AND Variant = @Variant

COMMIT TRANSACTION 
		-- One benefit of doing this is that whenever there was a null type for those cars, it got updated
SELECT *
FROM QatarSaleData
WHERE Type IS NULL

	-- For these which actually have multiple types, I will use both 
WITH CTE1 AS (
SELECT DISTINCT CONCAT_WS( ' ', Make, Model, Variant) AS Car, Make, Model, Variant, Type
from QatarSaleData
WHERE Type IS NOT NULL ) ,
CTE2 AS (
SELECT Car, COUNT(*) AS Count
FROM CTE1
GROUP BY Car
HAVING COUNT(*) > 1 ),
CTE3 AS (
SELECT B.Car, STRING_AGG( A.Type, '; ') MultipleTypes
FROM CTE2 B
JOIN CTE1 A
ON A.Car = B.Car
GROUP BY B.Car )
-- SELECT *
UPDATE QS
SET Type = CTE3.MultipleTypes
FROM QatarSaleData QS
LEFT JOIN CTE3 
ON CONCAT_WS( ' ', QS.Make, QS.Model, QS.Variant) = CTE3.Car
WHERE QS.Type IS NULL
AND CTE3.MultipleTypes IS NOT NULL

	-- For the remaining, I will repeat what I did (where more than 1 type) but with make and model only
SELECT *
FROM QatarSaleData
WHERE Type IS NULL

WITH CTE1 AS (
SELECT DISTINCT CONCAT_WS( ' ', Make, Model) AS Car, Make, Model, Type
from QatarSaleData
WHERE Type IS NOT NULL ) ,
CTE2 AS (
SELECT Car, COUNT(*) AS Count
FROM CTE1
GROUP BY Car
HAVING COUNT(*) > 1 )
SELECT B.Car, STRING_AGG( A.Type, '; ')
FROM CTE2 B
JOIN CTE1 A
ON A.Car = B.Car
GROUP BY B.Car

	-- As before, some of them have actually have multiple types, and some are incorrect entries. So, I will fix them. (By using variables) 
	-- These are that I changed: CHEVROLET TRAX, GMC YUKON, JAGUAR F-PACE, MERCEDES GLC, Peugeot 3008, VW GOLF

DECLARE @Make1 VARCHAR(50)
DECLARE @Model1 VARCHAR(50)
DECLARE @Right_BodyStyle1 VARCHAR(50);
SET @Make1 = 'VOLKSWAGEN'
SET @Model1 = 'GOLF'
SET @Right_BodyStyle1 = 'Hatchback';

SELECT * FROM QatarSaleData WHERE Make = @Make1 AND Model = @Model1 

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Type = @Right_BodyStyle1
WHERE Make = @Make1 AND Model = @Model1 

SELECT * FROM QatarSaleData WHERE Make = @Make1 AND Model = @Model1

COMMIT TRANSACTION 

SELECT *
FROM QatarSaleData
WHERE Type IS NULL

	-- Again, for which actually have multiple types, I will use them all. However, this time I'm excluding some that doesn't make sence to update both types (Because types are specific to variants for them)
		-- And I'm adding another filter, so the types that are already double won't be picked up

WITH CTE1 AS (
SELECT DISTINCT CONCAT_WS( ' ', Make, Model) AS Car, Make, Model, Type
from QatarSaleData
WHERE Type IS NOT NULL ) ,
CTE2 AS (
SELECT Car, COUNT(*) AS Count
FROM CTE1
GROUP BY Car
HAVING COUNT(*) > 1 ),
CTE3 AS (
SELECT B.Car, STRING_AGG( A.Type, '; ') MultipleTypes, LEN(STRING_AGG( A.Type, '; ')) AS Len
FROM CTE2 B
JOIN CTE1 A
ON A.Car = B.Car
GROUP BY B.Car )
 --SELECT *
UPDATE QS
SET Type = CTE3.MultipleTypes
FROM QatarSaleData QS
LEFT JOIN CTE3 
ON CONCAT_WS( ' ', QS.Make, QS.Model) = CTE3.Car
WHERE QS.Type IS NULL
AND CTE3.MultipleTypes IS NOT NULL
AND CTE3.Car NOT IN ('Aston Martin DB','Audi RS','BMW M-Series','Nissan Patrol','Toyota Land Cruiser')
AND CTE3.Len < 26

-- For the rest , I will just add it manually (using variables)
SELECT DISTINCT Make, Model, Variant
FROM QatarSaleData
WHERE Type IS NULL

		/* These are that I changed: ASTON MARTIN DB S, BMW M2/235i, BENTLEY CONTINENTAL GT, FORD E 350, HYUNDAI GENESIS G70, PORSCHE 718 SPYDER, VOLVO V40, LAND CRUISER, MINI COOPER GP
			   (some of them without variant): Cadillac SRX, GMC SUBURBAN, Hummer H3, JEEP COMPASS, NISSAN Murano, SKODA KAROQ, VW T-Roc, Suzuki Ertiga, Tesla Model Y, Toyota C-HR, Toyota Innova, Toyota Raize, Zotye Domy X7, Mitsubishi Xpander,
				Zxauto Terralord, Dodge	Pickup, Isuzu Reward, Nissan NAVARA, BAIC	X35, Fiat 695, ford focus, Seat	Ibiza, GMC Van, Savana, Hyundai	County, Maxus V80, 
				AUDI TT, Ferrari	Mondial, 812, Lamborghini Aventador, Mercedes 280 SEL, SLS, CL, NISSAN 300 ZX, MERCEDES 560 SL, Porsche Boxster, Rolls-Royce Dawn,
				Chevrolet Caprice, MERCEDES 560 SEL, FORD Fusion, Escort, MUSTANG, GAC GA 3S, HONDA CIVIC, Hyundai Azera, KIA CERATO, Optima, STINGER, Porsche Taycan, Subaru	Legacy, WRX, VOLVO S */

DECLARE @Make2 VARCHAR(50)
DECLARE @Model2 VARCHAR(50)
DECLARE @Variant2 VARCHAR(50)
DECLARE @BodyStyle VARCHAR(50);
SET @Make2 = 'Ferrari'
SET @Model2 = '812'
--SET @Variant2 = 'LX'
SET @BodyStyle = 'Convertible; Coupe';

SELECT * FROM QatarSaleData WHERE Make = @Make2 AND Model = @Model2 --AND Variant = @Variant2 

BEGIN TRANSACTION
UPDATE QatarSaleData
SET Type = @BodyStyle
WHERE Make = @Make2 AND Model = @Model2 --AND Variant = @Variant2

SELECT * FROM QatarSaleData WHERE Make = @Make2 AND Model = @Model2 --AND Variant = @Variant2

COMMIT TRANSACTION 

SELECT *
FROM QatarSaleData
WHERE Type IS NULL

SELECT DISTINCT Type
FROM QatarSaleData
ORDER BY 1
	
	--Finally, standarizing some of the multiple types
--SELECT * FROM
UPDATE 
QatarSaleData
SET Type = 'Hatchback; Sedan'
WHERE Type = 'Sedan; Hatchback'

--SELECT * FROM 
UPDATE 
QatarSaleData
SET Type = 'Convertible; Coupe'
WHERE Type = 'Coupe; Convertible'

--SELECT * FROM 
UPDATE 
QatarSaleData
SET Type = 'Pick Up'
WHERE Type = 'Pickup'

-- And with that, I am DONE with CLEANING



								/* The Analysis */

SELECT *
FROM QatarSaleData
					
-- First, getting general Idea 
SELECT Make, COUNT(*) AS Count
FROM QatarSaleData
GROUP BY Make
ORDER BY Count DESC

SELECT TOP 10 *
FROM QatarSaleData
ORDER BY Mileage DESC	

SELECT TOP 20 *
FROM QatarSaleData
ORDER BY Price DESC

SELECT Type, COUNT(*) AS Count
FROM QatarSaleData
GROUP BY Type
ORDER BY 2 DESC
	-- Interestingly, pick ups are mor popular than sedans.

-- Most popular cars. Offsetting by 1 because it will be Land Cruiser of sure. 
SELECT Make, Model, COUNT(*) AS Count
FROM QatarSaleData
GROUP BY Make, Model
ORDER BY 3 DESC
OFFSET 1 ROWS
FETCH FIRST 10 ROWS ONLY

-- Finding out which dealer has the most high end cars. 
SELECT Dealer, COUNT(*) AS Count, ROUND(AVG(Price), -3)AS AVG_Price
FROM QATARSALEDATA
WHERE Dealer_id <> 'private'
GROUP BY Dealer
ORDER BY 3 DESC

-- Most popular engines. 
SELECT Engine, COUNT(*) AS Count
FROM QatarSaleData
GROUP BY Engine
ORDER BY 2 DESC
	-- Interestingly, 0 (EV) are more popular than V10
	
-- Finding out which engine is more popular in Land Cruisers. 
SELECT Engine, COUNT(*) AS Count
FROM QatarSaleData
WHERE Model = 'Land Cruiser'
GROUP BY Engine
	SELECT Engine, COUNT(*) AS Count
	FROM QatarSaleData
	WHERE Model = 'Land Cruiser'
	AND Year BETWEEN 1998 AND 2021
	GROUP BY Engine


-- Analysis by countries. 
SELECT Country, COUNT(*) Makes_Count
FROM Makes
GROUP BY Country
ORDER BY 2 DESC

SELECT Country, COUNT(*) AS Count, ROUND (AVG(PRICE), -3) AS AVG_Price,
	RANK() OVER (ORDER BY ROUND (AVG(PRICE), -3) DESC ) AS Avg_Price_Rank
FROM QatarSaleData 
JOIN Makes ON QatarSaleData.Make = Makes.Make
GROUP BY Country
ORDER BY 2 DESC

-- Cheap new cars (under 100k) 
SELECT COUNT(*) AS Count_of_cheap_cars
FROM QatarSaleData
WHERE Mileage = 0
AND Price <= 100000;
SELECT *
FROM QatarSaleData
WHERE Mileage = 0
AND Price <= 100000

SELECT DISTINCT Make, Model, Variant
FROM QatarSaleData
WHERE Mileage = 0
AND Price <= 100000

SELECT FORMAT( ROUND(  
		( SELECT COUNT(*) FROM QatarSaleData 
		  WHERE Mileage = 0
		  AND Price <= 100000 ) * 1.0 /
		COUNT(*) * 100 , 2) , '#.00' ) AS '%_of_Cheap'
FROM QatarSaleData
WHERE Mileage = 0

	-- And lets see them without the chinese ones. 
SELECT COUNT(QatarSaleData.Id) AS Count_of_cheap_cars
FROM QatarSaleData
JOIN Makes
ON QatarSaleData.Make = Makes.Make
WHERE Mileage = 0
AND Price <= 100000
AND Country <> 'China';
SELECT QatarSaleData.*
FROM QatarSaleData
JOIN Makes
ON QatarSaleData.Make = Makes.Make
WHERE Mileage = 0
AND Price <= 100000
AND Country <> 'China'

SELECT DISTINCT QatarSaleData.Make, Model, Variant
FROM QatarSaleData
JOIN Makes
ON QatarSaleData.Make = Makes.Make
WHERE Mileage = 0
AND Price <= 100000
AND Country <> 'China'

				/**/
/* I want to know about manuals. I have an assumption that manual cars are dropping and becomming less common. 
So, lets test that by the percentage of manuals over the total for each decade (excluding pick ups and buses). */

	/*The *1.0 is to have a decimal place in the terms so the returned answer will have decimals also.	
	For some reason, it rounds up the answers of the division to integers */

WITH Decades AS (
SELECT *, CASE
			WHEN Year BETWEEN 2020 AND 2029 THEN '2020s'
			WHEN Year BETWEEN 2010 AND 2019 THEN '2010s'
			WHEN Year BETWEEN 2000 AND 2009 THEN '2000s'
			WHEN Year BETWEEN 1990 AND 1999 THEN '1990s'
			WHEN Year BETWEEN 1980 AND 1989 THEN '1980s'
			ELSE 'Old'
		END AS Decade 
FROM QatarSaleData ), 
Manuals AS (SELECT * FROM Decades WHERE Transmission = 'MANUAL')

SELECT D.Decade, FORMAT( ROUND( COUNT(M.Id) * 1.0 / COUNT(D.Id) * 100 , 2) , '#.00') AS '%of_Manuals'
FROM Decades D
FULL JOIN Manuals M ON D.Id = M.Id
WHERE D.Type NOT LIKE 'Van/Bus'
AND D.Type NOT LIKE '%Pick Up%'
GROUP BY D.Decade
ORDER BY D.Decade

	-- Lastly, I will create a view from this quey because Power BI doesn't accpect CTE! 

DROP VIEW IF EXISTS Manuals_over_Decades 	
CREATE VIEW Manuals_over_Decades AS

WITH Decades AS (
SELECT *, CASE
			WHEN Year BETWEEN 2020 AND 2029 THEN '2020s'
			WHEN Year BETWEEN 2010 AND 2019 THEN '2010s'
			WHEN Year BETWEEN 2000 AND 2009 THEN '2000s'
			WHEN Year BETWEEN 1990 AND 1999 THEN '1990s'
			WHEN Year BETWEEN 1980 AND 1989 THEN '1980s'
			ELSE 'Old'
		END AS Decade 
FROM QatarSaleData ), 
Manuals AS (SELECT * FROM Decades WHERE Transmission = 'MANUAL')

SELECT D.Decade, COUNT(M.Id) * 1.0 / COUNT(D.Id) * 100 AS '%of_Manuals'
FROM Decades D
FULL JOIN Manuals M ON D.Id = M.Id
WHERE D.Type NOT LIKE 'Van/Bus'
AND D.Type NOT LIKE '%Pick Up%'
GROUP BY D.Decade

SELECT *
FROM Manuals_over_Decades
ORDER BY Decade

-- These are the codes I used to import the data to Power BI Desktop

SELECT *
FROM QatarSaleData

SELECT *
FROM Makes

SELECT *
FROM Manuals_over_Decades