#---
#title: "CS5200.PracticumII.KocO-AcilanE"
#author: 'Omer Koc and Etki Acilan'
#---

# Libraries 
library(RSQLite) # import the necessary SQLite library.
library(XML) # import the necessary XML library.

################### Realize the relational schema in SQLite using R. ################### 
fpath  <- ""
dbfile <- "Practicum2Part1db.sqlite"
dbcon  <- dbConnect(RSQLite::SQLite(), paste0(fpath,dbfile))

# Drop the tables if exists.
tableNames = list('Articles', 'PubDetails', 'AuthorList', 'Authors', 'AffiliationInfo',
                  'Journals', 'ISSNType', 'JournalIssue', 'CitedMedium', 'PubDate', 'Months', 'AuthorEnrollment')
for(i in 1:length(tableNames)){
  dbExecute(dbcon, paste0("DROP TABLE IF EXISTS ", paste(tableNames[i], collapse = ",")))
}


## Create Tables
#1 Create Articles table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS Articles (
    PMID INTEGER PRIMARY KEY,
    PubDID VARCHAR(255) NOT NULL,
    FOREIGN KEY (PubDID) REFERENCES PubDetails (PubDID)
);")

#2 Create PubDetails table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS PubDetails (
    PubDID VARCHAR(255) PRIMARY KEY,
    JournalID VARCHAR(255),
    ArticleTitle VARCHAR(255),
    AuthorListID VARCHAR(255),
    FOREIGN KEY (JournalID) REFERENCES Journals (JournalID),
    FOREIGN KEY (AuthorListID) REFERENCES AuthorList (AuthorListID)
  );")

#3 Create AuthorList table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS AuthorList (
    AuthorListID VARCHAR(255) PRIMARY KEY,
    CompleteYN CHAR(1) CHECK (CompleteYN IN ('Y', 'N'))
);")

#4 Create Authors table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS Authors (
    AuthorID VARCHAR(255) PRIMARY KEY,
    LastName VARCHAR(255),
    ForeName VARCHAR(255),
    Initials VARCHAR(255),
    Suffix VARCHAR(255),
    CollectiveName VARCHAR(255),
    AffiliationInfoID VARCHAR(255),
    ValidYN CHAR(1) CHECK (ValidYN IN ('Y', 'N')),
    FOREIGN KEY (AffiliationInfoID) REFERENCES AffiliationInfo (AffiliationInfoID)
  );")

#5 Create AffiliationInfo table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS AffiliationInfo (
    AffiliationInfoID VARCHAR(255) PRIMARY KEY,
    Affiliation VARCHAR(255)
  );")

#6 Create Journals table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS Journals (
    JournalID VARCHAR(255) PRIMARY KEY,
    ISSN VARCHAR(255),
    JournalIssueID VARCHAR(255) ,
    Title VARCHAR(255),
    ISOAbbreviation VARCHAR(255),
    ISSNTypeID VARCHAR(255),
    FOREIGN KEY (JournalIssueID) REFERENCES JournalIssue (JournalIssueID),
    FOREIGN KEY (ISSNTypeID) REFERENCES ISSNType (ISSNTypeID)
  );")

#7 Create ISSNType table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS ISSNType (
    ISSNTypeID VARCHAR(255) PRIMARY KEY,
    Type VARCHAR(255)
  );")

#8 Create JournalIssue table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS JournalIssue (
    JournalIssueID VARCHAR(255) PRIMARY KEY,
    Volume VARCHAR(255),
    Issue VARCHAR(255),
    PubDateID VARCHAR(255),
    CitedMediumID VARCHAR(255),
    FOREIGN KEY (CitedMediumID) REFERENCES CitedMedium (CitedMediumID),
    FOREIGN KEY (PubDateID) REFERENCES PubDate (PubDateID)
  );")

#9 Create CitedMedium table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS CitedMedium (
    CitedMediumID VARCHAR(255) PRIMARY KEY,
    Type VARCHAR(255)
  );")

#10 Create PubDate table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS PubDate (
    PubDateID VARCHAR(255) PRIMARY KEY,
    Year VARCHAR(255),
    MonthID VARCHAR(255),
    Day VARCHAR(255),
    Season VARCHAR(255),
    MedlineDate VARCHAR(255),
    FOREIGN KEY (MonthID) REFERENCES Months (MonthID)
  );")

#11 Create Months table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS Months (
    MonthID VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255)
  );")

#12 Create AuthorEnrollment table if not exists.
dbExecute(dbcon,"CREATE TABLE IF NOT EXISTS AuthorEnrollment (
    AuthorEnrollmentID VARCHAR(255) PRIMARY KEY,
    AuthorListID VARCHAR(255),
    AuthorID VARCHAR(255),
    FOREIGN KEY (AuthorListID) REFERENCES AuthorList (AuthorListID),
    FOREIGN KEY (AuthorID) REFERENCES Authors (AuthorID)
  );")


## Load (with validation of the DTD) the XML file into R 
# URL of the XML file
xml_url <- "http://practicum2-omeretki.s3.us-east-2.amazonaws.com/pubmed22n0001-tf-aws.xml"
xmlObj <- xmlParse(xml_url, validate = TRUE)


## Populate the tables
batch     <- list() # batch command list for inserting into the database.
root      <- xmlRoot(xmlObj) # Get the reference root.
xpathQ    <- "count(//Article)" # The number of visit to the page200.
numArticle<- xpathApply(xmlObj, xpathQ, xmlValue) # Apply the XPath

## Queries
# 1) Get the Journal Node
QISSN         <- "(./Journal/ISSN)"
QVolume       <- "(./Journal/JournalIssue/Volume)"
QIssue        <- "(./Journal/JournalIssue/Issue)"
QYear         <- "(./Journal/JournalIssue/PubDate/Year)"
QMonth        <- "(./Journal/JournalIssue/PubDate/Month)"
QDay          <- "(./Journal/JournalIssue/PubDate/Day)"
QMedlineDate  <- "(./Journal/JournalIssue/PubDate/MedlineDate)"
QSeason       <- "(./Journal/JournalIssue/PubDate/Season)"
QTitle        <- "(./Journal/Title)"
QISOAbbreviation <- "(./Journal/ISOAbbreviation)"

# 2) Get the ArticleTitle
QArticleTitle <- "./ArticleTitle"

# 3) Get the Authorlist Node
QfindAuthor     <- "(./AuthorList/Author[LastName="
QlastName       <- "(./AuthorList/Author/LastName)"
QforeName       <- "/ForeName"
Qinitials       <- "/Initials"
QSuffix         <- "/Suffix"
QCollectiveName <- "/CollectiveName"
QAffiliation1   <- "(./AuthorList/Author[LastName=" 
QAffiliation2   <- "/AffiliationInfo/Affiliation"

Qlist1 <- list(QISSN, QVolume, QIssue, QYear, QMonth, QDay, QMedlineDate, QSeason, QArticleTitle, QTitle, QISOAbbreviation)

# Tables
AffiliationInfo <- list()
Authors         <- list()
Journals        <- list()
AuthorList      <- list()
PubDetails      <- list()
Articles        <- list()
PubDate         <- list() #Pubdate tables
JournalIssue    <- list() #JournalIssue tables


## XML Parsing by node traversal
for(i in 1:numArticle){
  
  # Get the Article with PMID = i
  mainNode <- root[[i]]
  nodeList <- mainNode[[1]]
  
  # Get the #1 and #2
  articleInfo <- lapply(Qlist1, function(xpath) xpathApply(nodeList, xpath, xmlValue))
  articleInfo <- sapply(sapply(articleInfo,"[",1),"[[",1)
  
  # Get the #3
  authorLastName  <- xpathApply(nodeList, QlastName, xmlValue)
  authorNumber    <- length(authorLastName) #Last Name must exist always.
  
  authorlistID      <- i
  singleAuthor      <- list(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)
  duplicated_last_name_counter = 1
  if (authorNumber > 0){ # 
    for(j in 1:authorNumber){
      
      # Authorlist attributes
      CompleteYN  <- xmlGetAttr(node = mainNode[[1]][[3]], name = "CompleteYN")  
      # Author attributes
      validYN         <- xmlGetAttr(node = mainNode[[1]][[3]][[j]], name = "ValidYN")
      
      # if collectiveName exists
      collectiveName    <- xpathApply(nodeList, paste(QfindAuthor, '"',authorLastName[[j]], '"]', QCollectiveName , ')', sep = ""), xmlValue)
      singleAuthor      <- list(validYN, authorLastName[[j]], NULL, NULL, NULL, NULL, collectiveName, authorlistID)
      
      # else if collectiveName does not exist.
      if(length(collectiveName) == 0){
        authorForeName  <- unlist(xpathApply(nodeList, paste(QfindAuthor, '"',authorLastName[[j]], '"]', QforeName , ')', sep = ""), xmlValue))[duplicated_last_name_counter]
        authorInitials  <- unlist(xpathApply(nodeList, paste(QfindAuthor, '"',authorLastName[[j]], '"]' ,Qinitials, ')', sep = ""), xmlValue))[duplicated_last_name_counter]
        authorSuffix    <- unlist(xpathApply(nodeList, paste(QfindAuthor, '"',authorLastName[[j]], '"]' , QSuffix , ')', sep = ""), xmlValue))[duplicated_last_name_counter]
        authorAff       <- unlist(xpathApply(nodeList, paste(QAffiliation1, '"',authorLastName[[j]], '"]', QAffiliation2 , ')', sep = ""), xmlValue))[duplicated_last_name_counter]
        
        # if there are authors with the same last name.
        if (length(unlist(xpathApply(nodeList, paste(QfindAuthor, '"',authorLastName[[j]], '"]', QforeName , ')', sep = ""), xmlValue))) > 1){
          duplicated_last_name_counter = duplicated_last_name_counter +1
        }
        
        # Insert to Authors table
        singleAuthor      <- list(validYN, authorLastName[[j]], authorForeName, authorInitials, authorSuffix, authorAff, NULL, authorlistID)
        Authors           <- c(Authors,singleAuthor)
        AffiliationInfo   <- c(AffiliationInfo, list(authorAff))
      }
    }
  }
  
  # Attributes 
  PMID        <- xmlGetAttr(node = mainNode, name = "PMID") 
  IssnType    <- xmlGetAttr(node = mainNode[[1]][[1]][[1]], name = "IssnType")
  CitedMedium <- xmlGetAttr(node = mainNode[[1]][[1]][[2]], name = "CitedMedium")
  
  # Synthetic keys
  pubdID <- i
  
  # Create row of data list.
  singlePubDate     <- list(i, articleInfo[[4]], articleInfo[[5]], articleInfo[[6]], articleInfo[[8]],articleInfo[[7]])
  singleJournalIssue<- list(articleInfo[[2]], articleInfo[[3]], CitedMedium)
  singleJournal     <- list(articleInfo[[1]], articleInfo[[10]], articleInfo[[11]], IssnType)
  singleAuthorList  <- list(CompleteYN,authorlistID) 
  singlePubDetails  <- list(pubdID, articleInfo[[9]]) 
  singleArticles    <- list(PMID) 
  
  # Add the overall frame row.
  Journals    <- c(Journals, singleJournal)
  AuthorList  <- c(AuthorList, singleAuthorList)
  PubDetails  <- c(PubDetails, singlePubDetails)
  Articles    <- c(Articles, singleArticles)
  PubDate     <- c(PubDate, singlePubDate)
  JournalIssue<- c(JournalIssue, singleJournalIssue)
}

## Create data frame and map the related foreign keys.
# Create Months data frame.
monthList <- list("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
Months <- data.frame(monthid = 1:12, name = unlist(monthList))

# Create CitedMedium data frame.
citedmediumList <- list("Print", "Internet")
CitedMedium <- data.frame(citedmediumid = 1:2, name = unlist(citedmediumList)
)

# Create ISSNType data frame
ISSNTypeList <- list("Print", "Electronic")
ISSNType <- data.frame(issntypeid = 1:2, type = unlist(ISSNTypeList)
)

# Create AffiliationInfo data frame
AffiliationInfo <- unique(AffiliationInfo)
AffiliationInfo[which(AffiliationInfo == 'NULL')] = 'null'
AffiliationInfo <- data.frame(affiliationinfoid = 1:length(AffiliationInfo), 
                              affiliation = unlist(AffiliationInfo)
)

# Create PubDate data frame, divide the PubDate lists by each publication,
PubDate[which(PubDate == 'NULL')] = 'null'
PubDate <- data.frame(pubdateid = unlist(PubDate[seq(from = 1, to = length(PubDate), by = 6)]),
                      year = unlist(PubDate[seq(from = 2, to = length(PubDate), by = 6)]),
                      month = unlist(PubDate[seq(from = 3, to = length(PubDate), by = 6)]),
                      day = unlist(PubDate[seq(from = 4, to = length(PubDate), by = 6)]),
                      season = unlist(PubDate[seq(from = 5, to = length(PubDate), by = 6)]),
                      medlinedate = unlist(PubDate[seq(from = 6, to = length(PubDate), by = 6)])
)

PubDate$month <- Months$monthid[match(PubDate$month, Months$name)] #Match monthid

PubDate_unique    <- unique(subset(PubDate, select = -pubdateid)) # get the unique pubdates.
# matched_indices are to be used for journal issue.
matched_indices   <- match(paste(PubDate$year, PubDate$month, PubDate$day, PubDate$season, PubDate$medlinedate, sep = "-"), paste(PubDate_unique$year, PubDate_unique$month,PubDate_unique$day, PubDate_unique$season, PubDate_unique$medlinedate, sep = "-")) # get the matched versions.
PubDate           <- PubDate_unique
PubDate$pubdateid <- 1:nrow(PubDate)

# Create Journals data frame
JournalIssue[which(JournalIssue == 'NULL')] = 'null'
JournalIssue <- data.frame(journalissueid = 1:(length(JournalIssue)/3), #3 is the 'by = 3'
                           volume = unlist(JournalIssue[seq(from = 1, to = length(JournalIssue), by = 3)]),
                           issue = unlist(JournalIssue[seq(from = 2, to = length(JournalIssue), by = 3)]), 
                           citedmediumid = unlist(JournalIssue[seq(from = 3, to = length(JournalIssue), by = 3)]),
                           pubdateid = matched_indices
)

JournalIssue$citedmediumid <- CitedMedium$citedmediumid[match(JournalIssue$citedmedium, CitedMedium$name)] #Match citedmediumid.

JournalIssue_unique    <- unique(subset(JournalIssue, select = -journalissueid)) # get the unique journalissues
# matched_indices are to be used for journals.
matched_indices       <- match(paste(JournalIssue$volume, JournalIssue$issue, JournalIssue$citedmediumid, JournalIssue$pubdateid, sep = "-"),
                               paste(JournalIssue_unique$volume, JournalIssue_unique$issue,JournalIssue_unique$citedmediumid,
                                     JournalIssue_unique$pubdateid, sep = "-")) # get the matched versions.
JournalIssue           <- JournalIssue_unique
JournalIssue$journalissueid <- 1:nrow(JournalIssue)



# Create Journals data frame
Journals[which(Journals == 'NULL')] = 'null'
Journals <- data.frame(issn = unlist(Journals[seq(from = 1, to = length(Journals), by = 4)]), 
                       title = unlist(Journals[seq(from = 2, to = length(Journals), by = 4)]), 
                       isoabbreviation = unlist(Journals[seq(from = 3, to = length(Journals), by = 4)]),
                       issntypeid = unlist(Journals[seq(from = 4, to = length(Journals), by = 4)]),
                       journalissueid = matched_indices
)

Journals$issntype       <- ISSNType$issntypeid[match(Journals$issntypeid, ISSNType$type)] #Match issntype


Journals_unique       <- unique(Journals) # get the unique Journals
# matched_indices are to be used for pubdetails.
matched_indices_pub       <- match(paste(Journals$issn, Journals$title, Journals$isoabbreviation, Journals$issntypeid, Journals$journalissueid, sep = "-"),
                                   paste(Journals_unique$issn, Journals_unique$title, Journals_unique$isoabbreviation, Journals_unique$issntypeid,
                                         Journals_unique$journalissueid, sep = "-")) # get the matched versions.
Journals                <- Journals_unique
Journals$journalid <- 1:nrow(Journals)



# Create Authors data frame
Authors[which(Authors == 'NULL')] = 'null'
Authors <- data.frame(validyn = unlist(Authors[seq(from = 1, to = length(Authors), by = 8)]),
                      lastname = unlist(Authors[seq(from = 2, to = length(Authors), by = 8)]),
                      forename = unlist(Authors[seq(from = 3, to = length(Authors), by = 8)]),
                      initials = unlist(Authors[seq(from = 4, to = length(Authors), by = 8)]),
                      suffix = unlist(Authors[seq(from = 5, to = length(Authors), by = 8)]),
                      affiliation = unlist(Authors[seq(from = 6, to = length(Authors), by = 8)]),
                      collectivename = unlist(Authors[seq(from = 7, to = length(Authors), by = 8)]),
                      authorlistid = unlist(Authors[seq(from = 8, to = length(Authors), by = 8)])
)

Authors$affiliation <- AffiliationInfo$affiliationinfoid[match(Authors$affiliation, AffiliationInfo$affiliation)] #Match affiliationid
Authors_unique       <- unique(subset(Authors, select = -authorlistid)) # get the unique Journals

# matched_indices are to be used for authorenrollment.
matched_indices_ae     <- match(paste(Authors$lastname, Authors$forename, Authors$initials, Authors$suffix, Authors$affiliation, Authors$collectivename, sep = "-"),
                                paste(Authors_unique$lastname, Authors_unique$forename, Authors_unique$initials,
                                      Authors_unique$suffix, Authors_unique$affiliation, Authors_unique$collectivename, sep = "-")) # get the matched versions.
# matched_authorlistid is to be used for authorenrollment.
matched_authorlistid_ae <- Authors$authorlistid

Authors             <- Authors_unique
Authors$authorid    <- 1:nrow(Authors)

# Create AuthorEnrollment data frame.
AuthorEnrollment <- data.frame(authorlistid = matched_authorlistid_ae,
                               authorid = matched_indices_ae
)
AuthorEnrollment$authorenrollmentid <- 1:nrow(AuthorEnrollment)

# Create AuthorList data frame
AuthorList[which(AuthorList == 'NULL')] = 'null'
AuthorList <- data.frame(completeyn = unlist(AuthorList[seq(from = 1, to = length(AuthorList), by = 2)]),
                         authorlistid = unlist(AuthorList[seq(from = 2, to = length(AuthorList), by = 2)])
)

# Create PubDetails data frame
PubDetails[which(PubDetails == 'NULL')] = 'null'
PubDetails <- data.frame(pubdid = unlist(PubDetails[seq(from = 1, to = length(PubDetails), by = 2)]),
                         articletitle = unlist(PubDetails[seq(from = 2, to = length(PubDetails), by = 2)]),
                         authorlistid = AuthorList$authorlistid,
                         journalid = matched_indices_pub
                         )

# Create Articles data frame
Articles[which(Articles == 'NULL')] = 'null'
Articles <- data.frame(pmid = unlist(Articles),
                       pubdid = PubDetails$pubdid
                       )

## Arrange the data sequence for convenience 
PubDate1            <- data.frame(PubDateID = PubDate$pubdateid, Year=PubDate$year, MonthID = PubDate$month, Day = PubDate$day, Season = PubDate$season, MedlineDate = PubDate$medlinedate)
JournalIssue1       <- data.frame(JournalIssueID = JournalIssue$journalissueid, Volume = JournalIssue$volume, Issue = JournalIssue$issue, PubDateID = JournalIssue$pubdateid, CitedMediumID = JournalIssue$citedmediumid)
Journals1           <- data.frame(JournalID = Journals$journalid, ISSN = Journals$issn, JournalIssueID = Journals$journalissueid, Title = Journals$title, ISOAbbreviation = Journals$isoabbreviation, ISSNTypeID = Journals$issntypeid)
Authors1            <- data.frame(AuthorID = Authors$authorid, ValidYN = Authors$validyn, LastName = Authors$lastname, ForeName = Authors$forename, Initials = Authors$initials, Suffix = Authors$suffix, CollectiveName = Authors$collectivename, AffiliationInfoID = Authors$affiliation)
AuthorList1         <- data.frame(AuthorListID = AuthorList$authorlistid, CompleteYN = AuthorList$completeyn)
AuthorEnrollment1   <- data.frame(AuthorEnrollmentID = AuthorEnrollment$authorenrollmentid, AuthorListID = AuthorEnrollment$authorlistid , AuthorID = AuthorEnrollment$authorid)
PubDetails1         <- data.frame(PubDID = PubDetails$pubdid, JournalID = PubDetails$journalid, ArticleTitle = PubDetails$articletitle, AuthorListID = PubDetails$authorlistid)
Months1             <- data.frame(MonthID = Months$monthid, name = Months$name)
CitedMedium1        <- data.frame(CitedMediumID = CitedMedium$citedmediumid, Type = CitedMedium$name)
Articles1           <- data.frame(PMID = Articles$pmid, PubDID = Articles$pubdid)
ISSNType1           <- data.frame(ISSNTypeID = ISSNType$issntypeid, Type = ISSNType$type)
AffiliationInfo1    <- data.frame(AffiliationInfoID = AffiliationInfo$affiliationinfoid, Affiliation = AffiliationInfo$affiliation)

# Remove the duplicate authors within the same authorlist.
duplicated_authors= which(duplicated(subset(AuthorEnrollment1, select = -AuthorEnrollmentID)))
AuthorEnrollment1 <- AuthorEnrollment1[-duplicated_authors, ]

# Write Months to the database.
dbWriteTable(dbcon, "Months", Months1, append = TRUE)
# Write CitedMedium to the database.
dbWriteTable(dbcon, "CitedMedium", CitedMedium1, append = TRUE)
# Write ISSNType to the database.
dbWriteTable(dbcon, "ISSNType", ISSNType1, append = TRUE)
# Write AffiliationInfo to the database.
dbWriteTable(dbcon, "AffiliationInfo", AffiliationInfo1, append = TRUE)
# Write PubDate to the database.
dbWriteTable(dbcon, "PubDate", PubDate1, append = TRUE)
# Write JournalIssue to the database.
dbWriteTable(dbcon, "JournalIssue", JournalIssue1, append = TRUE)
# Write Journals to the database.
dbWriteTable(dbcon, "Journals", Journals1, append = TRUE)
# Write Authors to the database.
dbWriteTable(dbcon, "Authors", Authors1, append = TRUE)
# Write AuthorList to the database.
dbWriteTable(dbcon, "AuthorList", AuthorList1, append = TRUE)
# Write AuthorEnrollment to the database.
dbWriteTable(dbcon, "AuthorEnrollment", AuthorEnrollment1, append = TRUE)
# Write PubDetails to the database.
dbWriteTable(dbcon, "PubDetails", PubDetails1, append = TRUE)
# Write Articles to the database.
dbWriteTable(dbcon, "Articles", Articles1, append = TRUE)