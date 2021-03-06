library(dplyr)
library(reshape2)
library(ggplot2)
library(caret)

# Load data
training <- read.csv("./data/pml-training.csv", stringsAsFactors = FALSE) %>% tbl_df
testing <- read.csv("./data/pml-testing.csv", stringsAsFactors = FALSE) %>% tbl_df

training$set <- "train"
testing$set <- "test"
classe <- training$classe
problem_id <- testing$problem_id
testing$problem_id <- NULL

full <- rbind(select(training, -classe), testing)
rm(training, testing)

# Remove variables with mostly NAs
naCols <- apply(full, 2, function(x) sum(is.na(x)))
full <- full[-which(naCols > 0)]

# Remove variables not related to instrument readings
full <- full[-(1:7)]

# Re-split into training and testing sets
train <- full[full$set == "train",]
test <- full[full$set == "test",]

train$classe <- classe
test$problem_id <- problem_id
rm(full)

# Create training and validation set
index <- createDataPartition(train$classe, p = 0.8, list = FALSE)

train <- train[index,]
valid <- train[-index,]

# Remove variables with near-zero variance
nsv <- nearZeroVar(train)
train <- train[,-nsv]
valid <- valid[,-nsv]
test <- test[,-nsv]

# Scale and center the data
scale_center <- preProcess(select(train, -classe), 
                           method = c("scale", "center"))

train_scaled <- predict(scale_center, select(train, -classe))
train_scaled$classe <- train$classe

valid_scaled <- predict(scale_center, select(valid, -classe))
valid_scaled$classe <- valid$classe

test_scaled <- predict(scale_center, select(test, -problem_id))
test_scaled$classe <- test$problem_id

train_scaled$classe <- factor(train_scaled$classe)
valid_scaled$classe <- factor(valid_scaled$classe)

# Train models
trc <- trainControl("repeatedcv", number = 10, repeats = 2)

gbmGrid <- expand.grid(n.trees = seq(50, 500, 50), 
                        interaction.depth = 1:5,
                        shrinkage = c(0.1, 0.01))

gbm <- train(classe ~ ., 
             data = train_scaled, 
             method = "gbm", 
             trControl = trc, 
             tuneGrid = gbmGrid)

confusionMatrix(predict(gbm, valid_scaled), valid_scaled$classe)

answers <- predict(gbm, test_scaled)
