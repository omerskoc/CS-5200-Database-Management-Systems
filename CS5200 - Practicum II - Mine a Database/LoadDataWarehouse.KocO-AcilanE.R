# 1. Library (must be installed prior to loading)
# Load the required packages
library(RSQLite)
library(RMySQL)

# 2. My SQL Settings
db_user <- 'acilankocdbp2'
db_password <- 'SQL12345'
db_name <- 'acilankocdbp2'
db_host <- 'db4free.net' 
db_port <- 3306 # always this port unless you change it during installation

# 3. Connect to DB (mydb)
mydb = dbConnect(MySQL(), user = db_user, password = db_password,
                 dbname = db_name, host = db_host, port = db_port)
# Connect to the SQLite database
sqlite_conn <- dbConnect(RSQLite::SQLite(), dbname = "Practicum2Part1db.sqlite")

## Create Database.
# Drop ALL Tables
dbExecute(mydb,"DROP TABLE IF EXISTS JournalF")

# The existence of the table is checked, if any, it is dropped.
dbExecute(mydb,"CREATE TABLE IF NOT EXISTS JournalF (
    JournalID INTEGER,
    Title VARCHAR(255),
    Year INTEGER,
    MonthID INTEGER,
    Quarter INTEGER,
    NumArticlesQuarter INTEGER,
    NumArticlesYear INTEGER,
    NumAuthorsQuarter INTEGER,
    NumAuthorsYear INTEGER
  );")

# Execute the SQL query that selects the required data for creating the JournalF tables which is the fact table for journals.
query_result <- dbSendQuery(sqlite_conn, "

SELECT q.JournalID, q.Title, q.Year, q.MonthID, q.Quarter, q.NumArticlesQuarter, y.NumArticlesYear, q.NumAuthorsQuarter, y.NumAuthorsYear
FROM (SELECT j.JournalID, j.Title, p.Year, p.MonthID, ((p.MonthID-1)/3 + 1) as Quarter, count(distinct pd.PubDID) as NumArticlesQuarter, 
                    count(distinct ae.AuthorID) as NumAuthorsQuarter
                        FROM Journals j
                        JOIN JournalIssue ji ON j.JournalIssueID = ji.JournalIssueID
                        JOIN PubDetails pd ON j.JournalID=pd.JournalID
                        JOIN PubDate p ON ji.PubDateID = p.PubDateID
                        JOIN AuthorEnrollment ae ON pd.AuthorListID = ae.AuthorListID
                        GROUP BY j.Title, p.Year, Quarter) q

              LEFT JOIN (SELECT j.JournalID, j.Title, p.Year, p.MonthID, count(distinct pd.PubDID) as NumArticlesYear,
                    count(distinct ae.AuthorID) as NumAuthorsYear
                        FROM Journals j
                        JOIN JournalIssue ji ON j.JournalIssueID = ji.JournalIssueID
                        JOIN PubDetails pd ON j.JournalID=pd.JournalID
                        JOIN PubDate p ON ji.PubDateID = p.PubDateID
                        JOIN AuthorEnrollment ae ON pd.AuthorListID = ae.AuthorListID
                        GROUP BY j.Title, p.Year) y 
                  ON q.Title = y.Title AND q.Year = y.Year;
")

# Fetch the results and arrange the NULL data.
fact_data <- dbFetch(query_result)
fact_data[which(is.na.data.frame(fact_data), arr.ind = TRUE)] = 'NULL'
fact_data[which(fact_data$Year == 'NULL')] = 0

# Do batch insertion to MySQL database from the previosly obtained data from SQLite database.
batch <- list()
for(i in 1:nrow(fact_data)){
  row <- fact_data[i,]
  values <- paste0("(", row$JournalID, ",'", gsub("'", "''", row$Title), "'," , row$Year, "," , row$MonthID, "," , row$Quarter, "," , row$NumArticlesQuarter, "," , row$NumArticlesYear, "," , row$NumAuthorsQuarter, "," , row$NumAuthorsYear,")")   
  batch <- c(batch, values)
}
dbExecute(mydb, paste0("INSERT INTO JournalF (JournalID, Title, Year, MonthID, Quarter, NumArticlesQuarter, NumArticlesYear, NumAuthorsQuarter, NumAuthorsYear) VALUES ", paste(batch, collapse = ",")))

dbDisconnect(mydb)