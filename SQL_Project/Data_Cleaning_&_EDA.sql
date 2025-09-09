-- Creating Database
create database world_layoffs;

SELECT 
    *
FROM
    layoffs;

-- create another table just like layoffs
CREATE TABLE layoffs_staging LIKE layoffs;

insert layoffs_staging
select 
		*
from
		layoffs;


-- Data Cleaning

-- 1. Removing Duplicates

with Duplicate_CTE as
		(select *, 
		row_number() 
		over(partition by company, location, industry, total_laid_off, percentage_laid_off,
		`date`, stage, country, funds_raised_millions) as row_num
from layoffs_staging
)
select * from Duplicate_CTE
where row_num >1;

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
   row_num int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

insert into layoffs_staging2
		select *, 
		row_number() 
		over(partition by company, location, industry, total_laid_off, percentage_laid_off,
		`date`, stage, country, funds_raised_millions) as row_num
from layoffs_staging;

SELECT 
    *
FROM
    layoffs_staging2
WHERE
    row_num > 1;

DELETE FROM layoffs_staging2 
WHERE
    row_num > 1;


-- 2. Standardizing Data

UPDATE layoffs_staging2 
SET 
    company = TRIM(company);

SELECT 
    industry
FROM
    layoffs_staging2
WHERE
    industry LIKE 'crypto%';

UPDATE layoffs_staging2 
SET 
    industry = 'Crypto'
WHERE
    industry LIKE 'crypto%';

UPDATE layoffs_staging2 
SET 
    country = TRIM(TRAILING '.' FROM country)
WHERE
    country LIKE 'United States%';

SELECT DISTINCT
    (country)
FROM
    layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2 
SET 
    `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

alter table layoffs_staging2
modify column `date` DATE;

SELECT 
    `date`
FROM
    layoffs_staging2;


-- 3. Checking Null and Blank Values

SELECT 
    *
FROM
    layoffs_staging2
WHERE
    industry IS NULL OR industry = '';

UPDATE layoffs_staging2 
SET 
    industry = NULL
WHERE
    industry = '';

SELECT 
    t1.industry, t2.industry
FROM
    layoffs_staging2 t1
        JOIN
    layoffs_staging2 t2 ON t1.company = t2.company
WHERE
    t1.industry IS NULL
        AND t2.industry IS NOT NULL;

UPDATE layoffs_staging2 t1
        JOIN
    layoffs_staging2 t2 ON t1.company = t2.company 
SET 
    t1.industry = t2.industry
WHERE
    t1.industry IS NULL
        AND t2.industry IS NOT NULL;


-- 4. Deleting Rows and Columns

SELECT 
    *
FROM
    layoffs_staging2
WHERE
    total_laid_off IS NULL
        AND percentage_laid_off IS NULL;

DELETE FROM layoffs_staging2 
WHERE
    total_laid_off IS NULL
    AND percentage_laid_off IS NULL;

alter table layoffs_staging2
drop column row_num;


-- Exploratory Data Analysis

-- View all records from the layoffs staging table
SELECT 
    *
FROM
    layoffs_staging2;

-- Find the maximum, minimum, average, and total number of layoffs
SELECT 
    MAX(total_laid_off),
    MIN(total_laid_off),
    AVG(total_laid_off),
    SUM(total_laid_off)
FROM
    layoffs_staging2;

-- Top 10 companies with the highest total layoffs
SELECT 
    company, SUM(total_laid_off)
FROM
    layoffs_staging2
GROUP BY company
ORDER BY SUM(total_laid_off) DESC
LIMIT 10; 

-- Companies that laid off 100% of their workforce, ordered by number of employees laid off
SELECT 
    *
FROM
    layoffs_staging2
WHERE
    percentage_laid_off = 1
ORDER BY total_laid_off DESC;

-- Industries with the highest total layoffs
SELECT 
    industry, SUM(total_laid_off)
FROM
    layoffs_staging2
GROUP BY industry
ORDER BY SUM(total_laid_off) DESC;

-- Countries with the highest total layoffs
SELECT 
    country, SUM(total_laid_off)
FROM
    layoffs_staging2
GROUP BY country
ORDER BY SUM(total_laid_off) DESC;

-- Startup stages with the highest total layoffs
SELECT 
    stage, SUM(total_laid_off)
FROM
    layoffs_staging2
GROUP BY stage
ORDER BY SUM(total_laid_off) DESC;

-- Companies with the highest total funds raised (in millions)
SELECT 
    company, SUM(funds_raised_millions)
FROM
    layoffs_staging2
GROUP BY company
ORDER BY SUM(funds_raised_millions) DESC;

-- Industries ranked by layoffs per million dollars raised
SELECT 
    industry,
    SUM(total_laid_off) AS total_layoffs,
    SUM(funds_raised_millions) AS total_funds,
    ROUND((SUM(total_laid_off)) / NULLIF(SUM(funds_raised_millions), 0),
            2) AS layoffs_per_million
FROM
    layoffs_staging2
WHERE
    total_laid_off IS NOT NULL
        AND funds_raised_millions IS NOT NULL
GROUP BY industry
ORDER BY layoffs_per_million DESC;

-- Yearly layoffs trend (total layoffs per year)
SELECT 
    YEAR(`date`), SUM(total_laid_off)
FROM
    layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY SUM(total_laid_off) DESC;

-- Yearly trend of funds raised (total funds per year)
SELECT 
    YEAR(`date`), SUM(funds_raised_millions)
FROM
    layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY SUM(funds_raised_millions) DESC;

-- Monthly layoffs trend (total layoffs per month)
SELECT 
    SUBSTRING(`date`, 1, 7) AS `MONTH`, SUM(total_laid_off)
FROM
    layoffs_staging2
WHERE
    SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY `MONTH`
ORDER BY `MONTH` ASC;

-- Rolling sum of layoffs over time (cumulative layoffs by month)
with Rolling_Total as 
		(select substring(`date`,1,7) as `MONTH`, sum(total_laid_off) as Total_Persons_Laid_off
		from layoffs_staging2
where substring(`date`,1,7) is not null
group by `MONTH`
order by `MONTH` ASC
)
select `MONTH`, Total_Persons_Laid_off,
sum(Total_Persons_Laid_off) over(order by `MONTH`) as Rolling_Sum
from Rolling_Total;

-- Yearly layoffs per company
SELECT 
    company, YEAR(`date`), SUM(total_laid_off)
FROM
    layoffs_staging2
GROUP BY company , YEAR(`date`)
ORDER BY SUM(total_laid_off) DESC;

-- Top 5 companies per year with the highest layoffs
with Company_Year (company, years, total_laid_off) as
(
select company, year(`date`), sum(total_laid_off)
from layoffs_staging2
group by company, year(`date`)
), Company_Year_Rank as
(
select *, 
dense_rank() over (partition by years order by total_laid_off DESC) as Ranking
from Company_Year
where years is not null
)
select * from Company_Year_Rank
where Ranking <= 5;

-- Layoffs by company stage: number of companies, total layoffs, and average layoffs per company
SELECT 
    stage,
    COUNT(DISTINCT company) AS num_companies,
    SUM(COALESCE(total_laid_off, 0)) AS total_layoffs,
    ROUND(SUM(COALESCE(total_laid_off, 0)) / NULLIF(COUNT(DISTINCT company), 0),
            2) AS avg_layoffs_per_company
FROM
    layoffs_staging2
WHERE
    stage IS NOT NULL
GROUP BY stage
ORDER BY avg_layoffs_per_company DESC;