select * from dim_branch;
select * from dim_client;
select * from dim_product;
select * from fact_loan;
select * from fact_payment;
select * from final_fact;

# 1.Total Clients → COUNTROWS(Dim Client)
SELECT 
	count(*)  as Total_Client 
FROM dim_client;

#2.Active Clients → Clients with at least 1 active loan
SELECT
    COUNT(DISTINCT ClientId) AS Active_Client_Count
FROM Fact_Loan
WHERE
    -- Filter for the status that signifies an active loan
    LoanStatus = 'Active';
    
#3.New Clients → Clients whose first loan disbursement is in the selected period
SELECT 
	ClientID, MIN(DisbursementDate) AS FirstLoanDisbursement
FROM 
	final_fact
GROUP BY 
	ClientID;
    
#4.Client Retention Rate = (Returning Clients ÷ Previous Period Clients)
-- step:1. Distinct Count of Clients
SELECT COUNT(DISTINCT ClientID) AS TotalDistinctClients
FROM final_fact;

-- step:2. SUMMARIZE( ClientID, TransactionCount ) FILTER TransactionCount > 1(powerBI DAX we are using in SQL as below)
SELECT COUNT(*) AS RepeatClients
FROM (
    SELECT ClientID, COUNT(*) AS TransactionCount
    FROM final_fact
    GROUP BY ClientID
    HAVING COUNT(*) > 1
) AS t;
-- Step:3.Retention Rate = Repeat Clients / Total Clients
SELECT 
    concat(round((repeat_clients / total_clients)*100,2),"%") AS RetentionRate
FROM (
    SELECT 
        COUNT(DISTINCT ClientID) AS total_clients,
        (
            SELECT COUNT(*)
            FROM (
                SELECT ClientID
                FROM final_fact
                GROUP BY ClientID
                HAVING COUNT(*) > 1
            ) AS r
        ) AS repeat_clients
    FROM final_fact
) AS final;

#5.Total Loan Amount Disbursed = SUM(Fact Loan[Loan Amount])
SELECT
    concat(round(SUM(LoanAmount)/1000000,2),"M") AS Total_Loan_Amount_Disbursed
FROM
    fact_loan;

#6.Total Funded Amount = SUM(Fact Loan[Funded Amount])
SELECT
    concat(round(SUM(FundedAmount)/1000000,2),"M") AS Total_Funded_Amount
FROM
    fact_loan;
    

#7.Average Loan Size = AVERAGE(Fact Loan[Loan Amount])
SELECT
   concat(round(avg(LoanAmount)/1000,2),"K") AS Avg_Loan_Size
FROM
    fact_loan;
    
#8.Loan Growth % = (This Period Loan Amount - Last Period Loan Amount) ÷ Last Period Loan Amount
-- step:1.Calculate Total Loan Amount per Year
SELECT 
    YEAR(DisbursementDate) AS yr,
    SUM(loanamount) AS total_loan
FROM final_fact
GROUP BY YEAR(DisbursementDate)
ORDER BY yr;

-- step:2.Self-Join to Get Previous Year
SELECT 
    curr.yr AS year,
    curr.total_loan AS this_year_loan,
    prev.total_loan AS last_year_loan,
    ((curr.total_loan - prev.total_loan) / prev.total_loan) * 100 AS loan_growth_percentage
FROM
    (SELECT YEAR(DisbursementDate) AS yr, SUM(loanamount) AS total_loan
     FROM final_fact
     GROUP BY YEAR(disbursementdate)) curr
LEFT JOIN
    (SELECT YEAR(disbursementdate) AS yr, SUM(loanamount) AS total_loan
     FROM final_fact
     GROUP BY YEAR(disbursementdate)) prev
        ON curr.yr = prev.yr + 1
ORDER BY year;

#9.Total Repayments Collected = SUM(Fact Repayment[Total Pymnt])
SELECT
   concat(round(sum(TotalPymnt)/1000000,2),"M") AS Total_Repayment_Collected
FROM
    fact_payment;
    
#10. Principal Recovery Rate = SUM(Fact Repayment[Total Rec Prncp]) ÷ SUM(Fact Loan[Loan Amount])
SELECT
    SUM(p.TotalRecPrncp) AS total_principal_recovered,
    SUM(l.loanamount) AS total_loan_amount,
    concat(round((SUM(p.TotalRecPrncp) / SUM(l.loanamount)) * 100,2),"%") AS principal_recovery_rate
FROM fact_payment p
JOIN fact_loan l 
      ON p.AccountID = l.AccountID;

#11.Interest Income = SUM(Fact Repayment[Total Rrec int])
SELECT
   concat(round(sum(TotalRrecInt)/1000000,2),"M") AS Total_Repayment_Collected
FROM
    fact_payment;
    
#12.Default Rate = Loans with Is Default Loan = Y ÷ Total Loans
SELECT  
    SUM(CASE WHEN `Is Default Loan` = 'Y' THEN LoanAmount ELSE 0 END) AS default_loans_amount,
    SUM(LoanAmount) AS total_loans_amount,
    concat(round((SUM(CASE WHEN `Is Default Loan` = 'Y' THEN LoanAmount ELSE 0 END) 
     / SUM(LoanAmount)) * 100,2),"%") AS default_rate_percentage
FROM final_fact;

#13.Delinquency Rate = Loans with Is Delinquent Loan = Y ÷ Total Loans
SELECT  
    SUM(CASE WHEN `Is Default Loan` = 'Y' THEN LoanAmount ELSE 0 END) AS delinquent_loans_amount,
    SUM(LoanAmount) AS total_loans_amount,
    concat(round((SUM(CASE WHEN `Is Delinquent Loan` = 'Y' THEN LoanAmount ELSE 0 END) 
     / SUM(LoanAmount)) * 100,2),"%") AS default_rate_percentage
FROM final_fact;

#14.On-Time Repayment % = Repayments with Repayment Behavior = On-Time ÷ Total Repayments
SELECT
    COUNT(*) AS total_repayments,

    SUM(CASE WHEN RepaymentBehavior = 'On-Time' THEN 1 ELSE 0 END) 
        AS ontime_repayments,

    concat(round((SUM(CASE WHEN RepaymentBehavior = 'On-Time' THEN 1 ELSE 0 END) 
     / COUNT(*)) * 100,2),"%") AS ontime_repayment_percentage
FROM fact_payment;

#15.Loan Distribution by Branch (Total Loan Amount per Branch)
SELECT 
	BranchName,
    sum(LoanAmount) AS Total_Loan_Amount
FROM fact_loan
GROUP BY BranchName;

#16.Branch Performance Category Split (from Dim Branch)
SELECT 
	BranchPerformanceCategory,
	COUNT( BankName) 
FROM dim_branch
GROUP BY BranchPerformanceCategory;

#17.Product-wise Loan Volume = Loan Amount by Product
SELECT
	ProductId,
    sum(LoanAmount)
FROM final_fact
GROUP BY ProductId;

#18.Product Profitability = Interest Income per Product
SELECT
    ProductId,
    round(SUM(`Total Rrec int`),0) AS total_interest_income,
    concat(ROUND((SUM(`Total Rrec int`) / (SELECT SUM(`Total Rrec int`) FROM final_fact)) * 100, 2),"%") AS product_profitability_percentage
FROM final_fact
GROUP BY ProductId
ORDER BY product_profitability_percentage DESC;


-- CREDIT AND DEBIT BANKING DATA
select * from `debit and credit banking_data`;
#1-Total Credit Amount:
select
	`Transaction type`,
    concat(round(sum(amount)/1000000,1),"M") Total_crerdit_amount
from `debit and credit banking_data`
where `Transaction type`="credit";

#2-Total Debit Amount:
select
	`Transaction type`,
    concat(round(sum(amount)/1000000,1),"M") Total_crerdit_amount
from `debit and credit banking_data`
where `Transaction type`="debit";

#3-Credit to Debit Ratio:
SELECT 
    credit_total,
    debit_total,
    concat(ROUND((credit_total / debit_total)*100, 2),"%") AS credit_to_debit_ratio
FROM (
    SELECT 
        SUM(CASE WHEN `Transaction type` = 'credit' THEN amount ELSE 0 END) AS credit_total,
        SUM(CASE WHEN `Transaction type` = 'debit' THEN amount ELSE 0 END) AS debit_total
    FROM `debit and credit banking_data`
) AS t;

#4-Net Transaction Amount:
SELECT 
    credit_total,
    debit_total,
    concat(ROUND((credit_total - debit_total)/1000000, 2),"M") AS credit_to_debit_ratio
FROM (
    SELECT 
        SUM(CASE WHEN `Transaction type` = 'credit' THEN amount ELSE 0 END) AS credit_total,
        SUM(CASE WHEN `Transaction type` = 'debit' THEN amount ELSE 0 END) AS debit_total
    FROM `debit and credit banking_data`
) AS t;

#5-Account Activity Ratio:Number of transactions ÷ Account balance.
SELECT
    Number_of_Transactions,
    Account_Balance,
    CONCAT(
        -- ROUND the result to 7 decimal places to see the value
        ROUND(
            ((Number_of_Transactions / Account_Balance) * 100) / 10000,
            7
        ),
        '%'
    ) AS Account_Activity_Ratio
FROM (
    -- Your subquery remains unchanged
    SELECT
        COUNT(*) AS Number_of_Transactions,
        SUM(balance) AS Account_Balance
    FROM `debit and credit banking_data`
) AS t;

#6-Transactions per Day/Week/Month
-- Use this ONLY if you don't care which Day_Name is chosen for the month
SELECT
    DATE_FORMAT(`Transaction Date`, '%Y-%m') AS Transaction_Month,
    ANY_VALUE(DAYNAME(`Transaction Date`)) AS Day_Name, -- Tells MySQL to pick ANY Day_Name
    ANY_VALUE(MONTHNAME(`Transaction Date`)) AS Month_Name,
    COUNT(*) AS Total_Transactions
FROM
    `debit and credit banking_data`
GROUP BY
    Transaction_Month
ORDER BY
    Transaction_Month;
    
#7-Total Transaction Amount by Branch:
SELECT 
	Branch,
    concat(round(sum(amount)/1000000,2),"M")
FROM
	 `debit and credit banking_data`
GROUP BY 
	Branch;
    
#8-Transaction Volume by Bank:
SELECT 
	`Bank Name`,
    concat(round(sum(amount)/1000000,2),"M")
FROM
	 `debit and credit banking_data`
GROUP BY 
	`Bank Name`;

#9-Transaction Method Distribution:
SELECT 
	`Transaction Method` Transaction_Method_Distribution,
    concat(round(COUNT(*)/1000,2),"K") AS Number_of_Transactions
FROM
	 `debit and credit banking_data`
GROUP BY 
	Transaction_Method_Distribution;

#10-Branch Transaction Growth:
SELECT
    YearMonth,
    Branch,
    -- Concatenate the rounded number with the '%' symbol
    CONCAT(
        ROUND(
            (CurrentVolume - LAG(CurrentVolume, 1, 0) OVER (PARTITION BY Branch ORDER BY YearMonth)) * 100.0 / 
            NULLIF(LAG(CurrentVolume, 1, 0) OVER (PARTITION BY Branch ORDER BY YearMonth), 0),
        2)
    , '%') AS Branch_Growth_Rate_Percent
FROM
    ( 
    SELECT 
        DATE_FORMAT(`Transaction Date`, '%Y-%m') AS YearMonth,
        Branch,
        SUM(Amount) AS CurrentVolume
    FROM `debit and credit banking_data`
    GROUP BY YearMonth, Branch
    ) AS MonthlyData
ORDER BY 
    Branch, 
    YearMonth DESC;

#11-High-Risk Transaction Flag:
SELECT
	Amount,
    CASE
        WHEN Amount > 2500 THEN 'HIGH_RISK_FLAGGED' -- Condition 1: If amount exceeds the threshold
        ELSE 'NORMAL_ACTIVITY'                     -- Default: If condition 1 is not met
        END AS Risk_Flag_Status                   -- The name of the new column
FROM `debit and credit banking_data`;

#12-Suspicious Transaction Frequency:
SELECT 
	DATE_FORMAT(`Transaction Date`, '%Y-%m') AS YearMonth,COUNT(*) AS Suspicious_Transaction_Count
FROM 
	`debit and credit banking_data`
WHERE 
	Amount > 2500  -- Filter for high-risk transactions
GROUP BY 
	YearMonth
ORDER BY 
	YearMonth;
    
    
    




    

    











  

