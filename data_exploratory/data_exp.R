###############################################################################
#                                                                             #
#  City Lab Finance project                                                   #
#  Data exploration I                                                         #
#  Coded by Scarlett Swerdlow                                                 #
#  scarlettswerdlow@uchicago.edu                                              #
#  April 5, 2015                                                              #
#                                                                             #
###############################################################################

# If you have not already installed the following packages, run
# install.packages("<package name>") for each before sourcing code.

library(data.table)
library(ggplot2)
library(reshape)
# library(RSocrata) Can't get this to work

##################
#                #
#  PAYMENT DATA  #
#                #
##################

# https://data.cityofchicago.org/Administration-Finance/Payments/s4vu-giwb

# User must set working directory
setwd("~/Google Drive/Grad school/Courses/City Lab/cl-fin-fraud/data_exploratory")
payment <- fread('Payments.csv', header=T, stringsAsFactors = F)

################
#  CLEAN DATA  #
################

nrow(payment)
length(unique(payment$vendor.name))

# Rename columns
payment <- rename(payment, 
                  c("VOUCHER NUMBER" = "dv.num",
                    "AMOUNT" = "pmt.amt",
                    "Check Date" = "pmt.date",
                    "DEPARTMENT NAME" = "dept.name",
                    "CONTRACT NUMBER" = "cntrct.num",
                    "VENDOR NAME" = "vendor.name"))

# Assign correct types to data
amt <- substr(payment$pmt.amt, 2, nchar(payment$pmt.amt)) # Remove '$'
payment$pmt.amt <- as.numeric(amt) # Convert to numeric

payment <- within(payment, { # Separate check date into columns
  month <- ifelse(nchar(pmt.date) == 4, NA, substr(pmt.date, 1, 2))
  day <- ifelse(nchar(pmt.date) == 4, NA, substr(pmt.date, 4, 5))
  year <- ifelse(nchar(pmt.date) == 4, pmt.date, substr(pmt.date, 7, 10))
})

payment$month <- factor(payment$month, # Convert to factor
                        levels = c("01","02","03","04","05","06",
                                   "07","08","09","10","11","12"))

payment$day <- factor(payment$day, # Convert to factor
                      levels = c("01","02","03","04","05","06",
                                 "07","08","09","10","11","12",
                                 "13", "14", "15", "16", "17", "18",
                                 "19", "20", "21", "22", "23", "24",
                                 "25", "26", "27", "28", "29", "30", "31"))

payment$year <- factor(payment$year, # Convert to factor
                       levels = c("2003", "2004", "2005", "2006", "2007",
                                  "2008", "2009", "2010", "2011", "2012", 
                                  "2013", "2014", "2015"))

payment$dept.name <- factor(payment$dept.name) # Convert to factor

payment$vendor.name <- factor(payment$vendor.name) # Convert to factor

# Create boolean for whether payment is for contract or DV
payment$pmt.type <- ifelse(payment$cntrct.num != "DV", 
                           "Contract", "Direct voucher")

table(payment$pmt.date)

# Weird stuff going on with check dates. 1996-2002 data is rolled up and
# dated as 2002. Data that is older than two years is also supposed to be
# rolled up into one annual observation by contract, but this is not
# consistent in the data. Perhaps contracts with only one payment are
# dated by the date of the one payment.

pmt <- subset(payment, payment$year != '2002') # Remove 2002 data

##################
#  EXPLORE DATA  #
##################

nrow(pmt) # Number of observations
length(unique(pmt$vendor.name)) # Number of unique vendors

# Summary stats by year; cannot compare before/after 2013 due to roll-up
sum.by.yr <- aggregate(pmt$pmt.amt, list(pmt$year), summary)

# Total contract payments by year
tot.con.by.yr <- aggregate(pmt$pmt.amt[pmt$pmt.type == "Contract"], 
                           list(pmt$year[pmt$pmt.type == "Contract"]),
                           sum, na.rm=T)
tot.con.by.yr$type <- "Contract"

# Total DV payments by year
tot.dvs.by.yr <- aggregate(pmt$pmt.amt[pmt$pmt.type == "Direct voucher"], 
                           list(pmt$year[pmt$pmt.type == "Direct voucher"]),
                           sum, na.rm=T)
tot.dvs.by.yr$type <- "Direct voucher"

# Total payments by year
tot.by.yr <- rbind(tot.con.by.yr, tot.dvs.by.yr)

# Plot: Total payments by year
tot.by.yr.plt <- ggplot(tot.by.yr, 
                        aes(x = Group.1, y = x/1000000000, fill = type)) +
  geom_bar(stat = "identity") +
  ggtitle("Total amount paid annually by payment type") +
  xlab("Year") +
  ylab("Amount in billions")

# Plot: Distribution of payment amounts by year
amt.by.yr.plt <- ggplot(pmt, aes(x = year, y = log(pmt.amt))) + 
  geom_boxplot() + 
  ggtitle("Distribution of payment amount by year") +
  xlab("Year") +
  ylab("Log payment amount") +
  facet_grid(pmt.type ~ .)

# Number of unique contracts by year
num.con.by.yr <- aggregate(pmt$cntrct.num[pmt$pmt.type == "Contract"],
                             list(pmt$year[pmt$pmt.type == "Contract"]), 
                             function(x) length(unique(x)))

# Plot: Number of unique contracts by year plot
num.con.by.yr.plt <- ggplot(num.con.by.yr, aes(x = Group.1, y = x/1000)) + 
  geom_bar(stat = 'identity', color = "#F8766D", fill = "#F8766D") +
  ggtitle("Number of unique contracts by year") +
  xlab("Year") +
  ylab("Count in thousands")

# Number of DVs by year
# Question: why did DVs increase so much in 2014?
num.dvs.by.yr <- aggregate(pmt$cntrct.num[pmt$pmt.type == "Direct voucher"],
                           list(pmt$year[pmt$pmt.type == "Direct voucher"]), 
                           length)

# Plot: Number of DVs by year plot
num.dvs.by.yr.plt <- ggplot(num.dvs.by.yr, aes(x = Group.1, y = x/1000)) + 
  geom_bar(stat = 'identity', color = "#00C3C5", fill = "#00C3C5") +
  ggtitle("Number of Direct Voucher payments by year") +
  xlab("Year") +
  ylab("Count in thousands")

############################
#                          #
#  2013-2015 PAYMENT DATA  #
#                          #
############################

pmt.recent <- subset(pmt, pmt$year == '2014' | pmt$year == '2015')

################
#  CLEAN DATA  #
################

pmt.recent$month.year <- paste(pmt.recent$month, pmt.recent$year, sep='-')
pmt.recent$month.year <- factor(pmt.recent$month.year, 
                                levels=c('01-2014', '02-2014', '03-2014', 
                                         '04-2014', '05-2014', '06-2014', 
                                         '07-2014', '08-2014', '09-2014', 
                                         '10-2014', '11-2014', '12-2014',
                                         '01-2015', '02-2015', '03-2015') )

##################
#  EXPLORE DATA  #
##################

nrow(pmt.recent) # Number of payments
length(unique(pmt.recent$vendor.name)) # Number of unique vendors

summary(pmt.recent$pmt.amt) # Summarize payment amount
summary(pmt.recent$pmt.amt[pmt.recent$pmt.type == "Direct voucher"]) # DVs
summary(pmt.recent$pmt.amt[pmt.recent$pmt.type == "Contract"]) # Contracts

# Total contract payments by month
tot.con.by.mo <- aggregate(pmt.recent$pmt.amt[
  pmt.recent$pmt.type == "Contract"], 
  list(pmt.recent$month.year[pmt.recent$pmt.type == "Contract"]),
  sum, na.rm=T)
tot.con.by.mo$type <- "Contract"

# Total DV payments by month
tot.dvs.by.mo <- aggregate(pmt.recent$pmt.amt[
  pmt.recent$pmt.type == "Direct voucher"], 
  list(pmt.recent$month.year[pmt.recent$pmt.type == "Direct voucher"]),
  sum, na.rm=T)
tot.dvs.by.mo$type <- "Direct voucher"

# Total payments by month
tot.by.mo <- rbind(tot.con.by.mo, tot.dvs.by.mo)

# Plot: Total payments by month
tot.by.mo.plt <- ggplot(tot.by.mo, 
                        aes(x = Group.1, y = x/1000000000, fill = type)) +
  geom_bar(stat = "identity") +
  ggtitle("Total amount paid monthly by payment type") +
  xlab("Month") +
  ylab("Amount in billions")

# Plot: Distribution of payment amounts by month
amt.by.mo.plt <- ggplot(data = pmt.recent, 
                        aes(x = month.year, y = log(pmt.amt))) + 
  geom_boxplot() +
  ggtitle("Distribution of payment amount by month") +
  xlab("Month") +
  ylab("Log payment amount") +
  facet_grid(pmt.type ~ .)

# Number of contract payments by month
num.con.by.mo <- aggregate(pmt.recent$cntrct.num[
  pmt.recent$pmt.type == "Contract"], 
  list(pmt.recent$month.year[pmt.recent$pmt.type == "Contract"]),
  length)
num.con.by.mo$type <- "Contract"

# Number of DV payments by month
num.dvs.by.mo <- aggregate(pmt.recent$cntrct.num[
  pmt.recent$pmt.type == "Direct voucher"], 
  list(pmt.recent$month.year[pmt.recent$pmt.type == "Direct voucher"]),
  length)
num.dvs.by.mo$type <- "Direct voucher"

# Number payments by month
num.by.mo <- rbind(num.con.by.mo, num.dvs.by.mo)

# Plot: Number of monthly payments by payment type
num.by.mo.plt <- ggplot(num.by.mo, 
                        aes(x = Group.1, y = x/1000, fill = type)) +
  geom_bar(stat = "identity") +
  ggtitle("Number of monthly payments by payment type") +
  xlab("Month") +
  ylab("Count in thousands")

# Total contract payments by day of month
tot.con.by.day <- aggregate(pmt.recent$pmt.amt[
  pmt.recent$pmt.type == "Contract"], 
  list(pmt.recent$day[pmt.recent$pmt.type == "Contract"]),
  sum, na.rm=T)
tot.con.by.day$type <- "Contract"

# Total DV payments by day of month
tot.dvs.by.day <- aggregate(pmt.recent$pmt.amt[
  pmt.recent$pmt.type == "Direct voucher"], 
  list(pmt.recent$day[pmt.recent$pmt.type == "Direct voucher"]),
  sum, na.rm=T)
tot.dvs.by.day$type <- "Direct voucher"

# Total payments by day of month
tot.by.day <- rbind(tot.con.by.day, tot.dvs.by.day)

# Plot: Total payments by day of month
tot.by.day.plt <- ggplot(tot.by.day, 
                        aes(x = Group.1, y = x/1000000000, fill = type)) +
  geom_bar(stat = "identity") +
  ggtitle("Total amount paid daily by payment type") +
  xlab("Day") +
  ylab("Amount in billions")

# Plot: Distribution of payment amounts by day of month
amt.by.day.plt <- ggplot(pmt.recent, aes(x = day, y = log(pmt.amt))) + 
  geom_boxplot() +
  ggtitle("Distribution of payment amount by day of month") +
  xlab("Day of month") +
  ylab("Log payment amount") +
  facet_grid(pmt.type ~ .)

# Number of contract payments by day
num.con.by.day <- aggregate(pmt.recent$cntrct.num[
  pmt.recent$pmt.type == "Contract"], 
  list(pmt.recent$day[pmt.recent$pmt.type == "Contract"]),
  length)
num.con.by.day$type <- "Contract"

# Number of DV payments by day
num.dvs.by.day <- aggregate(pmt.recent$cntrct.num[
  pmt.recent$pmt.type == "Direct voucher"], 
  list(pmt.recent$day[pmt.recent$pmt.type == "Direct voucher"]),
  length)
num.dvs.by.day$type <- "Direct voucher"

# Number of payments by day
num.by.day <- rbind(num.con.by.day, num.dvs.by.day)

# Plot: Number of daily payments by payment type
num.by.day.plt <- ggplot(num.by.day, 
                         aes(x = Group.1, y = x/1000, fill = type)) +
  geom_bar(stat = "identity") +
  ggtitle("Number of daily payments by payment type") +
  xlab("Day") +
  ylab("Count in thousands")

###########################
#                         #
#  PAYMENT-CONTRACT DATA  #
#                         #
###########################

# Restrict payments data to contract data
pmt.cntrct <- subset(pmt, pmt$pmt.type == "Contract")

# https://data.cityofchicago.org/Administration-Finance/Contracts/rsxa-ify5
cntrct <- fread('Contracts.csv', header=T, stringsAsFactors = F)

################
#  CLEAN DATA  #
################

cntrct <- rename(cntrct, # Rename column headers
                 c("Purchase Order Description" = "cntrct.desc",
                   "Purchase Order (Contract) Number" = "cntrct.num",
                   "Revision Number" = "rev.num",
                   "Specification Number" = "spec.num",
                   "Contract Type" = "cntrct.type",
                   "Start Date" = "cntrct.start.date",
                   "End Date" = "cntrct.end.date",
                   "Approval Date" = "cntrct.app.date",
                   "Department" = "department",
                   "Vendor Name" = "vendor.name",
                   "Vendor ID" = "vendor.id",
                   "Address 1" = "addr.1",
                   "Address 2" = "addr.2",
                   "City" = "city",
                   "State" = "state",
                   "Zip" = "zip",
                   "Award Amount" = "cntrct.amt",
                   "Procurement Type" = "proc.type"))

amt <- substr(cntrct$cntrct.amt, 2, nchar(cntrct$cntrct.amt)) # Remove '$'
cntrct$cntrct.amt <- as.numeric(amt) # Convert to numeric

# Find length of contract
end <- strptime(cntrct$cntrct.end.date, format="%m/%d/%Y %I:%M:%S %p")
start <- strptime(cntrct$cntrct.start.date, format="%m/%d/%Y %I:%M:%S %p")
cntrct$cntrct.lngth <- as.numeric(difftime(end, start, units = "week"))

cntrct2 <- merge(as.data.frame(pmt.cntrct), # Merge with pmt
                 as.data.frame(cntrct),
                 by = "cntrct.num")

cntrct2 <- subset(cntrct2, cntrct2$year == "2014" | cntrct2$year == "2015")

cntrct <- data.table(cntrct2)

##################
#  EXPLORE DATA  #
##################

nrow(cntrct)
length(unique(cntrct$vendor.id))

# Number of unique contracts by department
num.by.dept <- aggregate(cntrct$cntrct.num,
                         list(cntrct$dept.name),
                         function(x) length(unique(x)))

# Plot: Number of unique contracts by department
num.by.dept.plt <- ggplot(num.by.dept, 
                          aes(x = reorder(factor(Group.1), x), y = x/100)) + 
  geom_bar(stat = "identity") +
  ggtitle("Number of unique contracts by department") +
  xlab(" ") +
  ylab("Count in hundreds") +
  coord_flip()

# Total payment amount by department
tot.by.dept <- aggregate(cntrct$pmt.amt, 
                         list(cntrct$dept.name),
                         sum, na.rm=T)

# Plot: Total payment amount by department
tot.by.dept.plt <- ggplot(tot.by.dept, 
                          aes(x = reorder(factor(Group.1), x), 
                              y = x/1000000000)) + 
  geom_bar(stat = "identity") +
  ggtitle("Total amount paid in contracts by department") +
  xlab(" ") +
  ylab("Amount in billions") +
  coord_flip()

# Average payment amount by department (restrict to not rolled up data)
avg.by.dept <- aggregate(cntrct$pmt.amt, 
                         list(cntrct$dept.name),
                         mean, na.rm=T)

# Number of unique contracts by type
num.by.type <- aggregate(cntrct$cntrct.num, 
                         list(cntrct$cntrct.type), 
                         function(x) length(unique(x))) 

# Plot: Number of unique contracts by type
num.by.type.plt <- ggplot(num.by.type, 
                          aes(x = reorder(factor(Group.1), x), y = x/100)) + 
  geom_bar(stat = "identity") +
  ggtitle("Number of unique contracts by type") +
  xlab(" ") +
  ylab("Count in hundreds") +
  coord_flip()

# Total payment amount by type
tot.by.type <- aggregate(cntrct$pmt.amt, 
                         list(cntrct$cntrct.type),
                         sum, na.rm=T)

# Plot: Total payment amount by type
tot.by.type.plt <- ggplot(tot.by.type, 
                          aes(x = reorder(factor(Group.1), x), 
                              y = x/1000000000)) + 
  geom_bar(stat = "identity") +
  ggtitle("Total amount paid in contracts by contract type") +
  xlab(" ") +
  ylab("Amount in billions") +
  coord_flip()

# Average payment amount by type (restrict to not rolled up data)
avg.by.type <- aggregate(cntrct$pmt.amt[
  cntrct$year == "2014" | cntrct$year == "2015"], 
  list(cntrct$cntrct.type[cntrct$year == "2014" | cntrct$year == "2015"]),
  mean, na.rm=T)

# Number of unique contracts by procurement type
num.by.proc <- aggregate(cntrct$cntrct.num, 
                         list(cntrct$proc.type), 
                         function(x) length(unique(x))) 

# Plot: Number of unique contracts by procurement type
num.by.proc.plt <- ggplot(num.by.proc, 
                          aes(x = reorder(factor(Group.1), x), y = x/100)) + 
  geom_bar(stat = "identity") +
  ggtitle("Number of unique contracts by procurement") +
  xlab(" ") +
  ylab("Count in hundreds") +
  coord_flip()

# Total payment amount by procurement type
tot.by.proc <- aggregate(cntrct$pmt.amt, 
                         list(cntrct$proc.type),
                         sum, na.rm=T)

# Plot: Total payment amount by department
tot.by.proc.plt <- ggplot(tot.by.proc, 
                          aes(x = reorder(factor(Group.1), x), 
                              y = x/1000000000)) + 
  geom_bar(stat = "identity") +
  ggtitle("Total amount paid in contracts by procurement type") +
  xlab(" ") +
  ylab("Amount in billions") +
  coord_flip()

# Average payment amount by procurement type
avg.by.proc <- aggregate(cntrct$pmt.amt, 
                         list(cntrct$proc.type),
                         mean, na.rm=T)

# Plot: Number of contracts vs total payment amount by department
by.dept.tot <- merge(num.by.dept, tot.by.dept, by = "Group.1")

by.dept.tot.plt <- ggplot(by.dept.tot, aes(x = x.x, y = x.y/1000000000)) +
  geom_point() +
  geom_smooth(method = lm, se = T) +
  ggtitle("Number of contracts vs total payment amount by department") +
  xlab("Number of contracts") +
  ylab("Total amount paid across all contracts in billions")

# Plot: Number of contracts vs average payment amount by department
by.dept.avg <- merge(num.by.dept, avg.by.dept, by = "Group.1")

by.dept.avg.plt <- ggplot(by.dept.avg, aes(x = x.x, y = x.y/1000000)) +
  geom_point() +
  geom_smooth(method = lm, se = T) +
  ggtitle("Number of contracts vs average payment amount by department") +
  xlab("Number of contracts") +
  ylab("Average payment amount in millions")

# Plot: Number of contracts vs total payment amount by type
by.type.tot <- merge(num.by.type, tot.by.type, by = "Group.1")

by.type.tot.plt <- ggplot(by.type.tot, aes(x = x.x, y = x.y/1000000000)) +
  geom_point() +
  geom_smooth(method = lm, se = T) +
  ggtitle("Number of contracts vs total payment amount by contract type") +
  xlab("Number of contracts") +
  ylab("Total amount paid across all contracts in billions")

# Plot: Number of contracts vs average payment amount by type
by.type.avg <- merge(num.by.type, avg.by.type, by = "Group.1")

by.type.avg.plt <- ggplot(by.type.avg, aes(x = x.x, y = x.y/1000000)) +
  geom_point() +
  geom_smooth(method = lm, se = T) +
  ggtitle("Number of contracts vs average payment amount by contract type") +
  xlab("Number of contracts") +
  ylab("Average payment amount in millions")

# Plot: Number of contracts vs total payment amount by procurement type
by.proc.tot <- merge(num.by.proc, tot.by.proc, by = "Group.1")

by.proc.tot.plt <- ggplot(by.proc.tot, aes(x = x.x, y = x.y/1000000000)) +
  geom_point() +
  geom_smooth(method = lm, se = T) +
  ggtitle("Number of contracts vs total payment amount by procurement type") +
  xlab("Number of contracts") +
  ylab("Total amount paid across all contracts in billions")

# Plot: Number of contracts vs average payment amount by procurement type
by.proc.avg <- merge(num.by.proc, avg.by.proc, by = "Group.1")

by.proc.avg.plt <- ggplot(by.proc.avg, aes(x = x.x, y = x.y/1000000)) +
  geom_point() +
  geom_smooth(method = lm, se = T) +
  ggtitle("Number of contracts vs average payment amount by procurement type") +
  xlab("Number of contracts") +
  ylab("Average payment amount in millions")

# Plot: Number of contracts vs average payment amount by vendor id
num.by.vendor <- aggregate(cntrct$cntrct.num,
                           list(cntrct$vendor.id),
                           length)

avg.by.vendor <- aggregate(cntrct$pmt.amt,
                           list(cntrct$vendor.id),
                           mean, na.rm = T)

by.vendor.avg <- merge(num.by.vendor, avg.by.vendor, by = "Group.1")

by.vendor.avg.plt <- ggplot(by.vendor.avg, aes(x = x.x, y = x.y/1000000)) +
  geom_point() +
  geom_smooth(method = lm, se = T) +
  ggtitle("Number of contracts vs average payment amount by vendor") +
  xlab("Number of contracts") +
  ylab("Average amount paid across all contracts in millions")

# Length of contract
lngth.con <- aggregate(cntrct$cntrct.lngth, list(cntrct$cntrct.num), max)

# Plot: Length of contract
lngth.con.plt <- ggplot(lngth.con, aes(x)) +
  geom_histogram(binwidth=26) +
  scale_x_continuous(breaks=seq(0,1040,52)) + # Exclude top 1 percentile
  coord_cartesian(xlim = c(0,1040)) +
  ggtitle("Distribution of contract length") +
  xlab("Length in weeks") +
  ylab("Count")

# Plot: Contract length in weeks versus amount
con.amt.lngth.plt <- ggplot(cntrct, 
                            aes(x = cntrct.lngth, y = cntrct.amt/1000000000)) +
  geom_point() +
  geom_smooth(method = lm, se = T) +
  ggtitle("Length of contract versus contract amount") +
  xlab("Length of contract in weeks") +
  ylab("Contract amount in billions")

###########################
#                         #
#  INTERESTING QUESTIONS  #
#                         #
###########################

# How many contracts have been paid more than their award?
# Appears multiple contracts have multiple awards of different amounts.
# Should we sum award amounts over contracts?

tot.pmt.by.con <- aggregate(cntrct$pmt.amt,
                            list(cntrct$cntrct.num), 
                            sum)

# Should we sum up awards?
tot.cntrct.amt.by.con <- aggregate(cntrct$cntrct.amt,
                                   list(cntrct$cntrct.num),
                                   sum)

tot.by.con <- merge(tot.pmt.by.con, tot.cntrct.amt.by.con, by="Group.1")

tot.by.con <- rename(tot.by.con, c("Group.1" = "cntrct.num",
                                   "x.x" = "tot.pmt.amt",
                                   "x.y" = 'tot.cntrct.amt'))

tot.by.con$comp <- ifelse(tot.by.con$tot.pmt.amt > tot.by.con$tot.cntrct.amt,
                          "more", "less or equal")

prop.table(table(tot.by.con$comp))

# How many unique vendors have the same address as another vendor?

cntrct$addr.street <- paste(cntrct$addr.1, cntrct$addr.2, sep = ",")

unique.vendors <- length(unique(cntrct$vendor.id))
unique.addr <- length(unique(cntrct$addr.street))

(unique.vendors - unique.addr)/unique.vendors

# There are 3976 unique vendors but only 3811 unique addresses. Explore
# vendors with the same addresses.
