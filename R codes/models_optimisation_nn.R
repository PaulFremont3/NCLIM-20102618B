#!bin/usr/bin/env Rscript
# models_optimisation_nn.R
# Code to optimize hyperparameters of neural network for each metacommunities using 30 random cross-validations
library("gbm")
library("dismo")
library("FactoMineR")
library("factoextra")
#library("readxl")
library("ggplot2")
library("reshape2")
library("gplots")
library("stringr")
library('mapproj')
library('mapplots')
library('SDMTools')
library('RColorBrewer')
library('ncdf4')
library('plotrix')
library('randomForest')
library('mgcv')
library('nnet')

df <- readRDS('Provinces_env_parameters_woa_scaled.rds')

fractions <- c('180-2000', '20-180', '43952','0.8-5','0.22-3', '0-0.2')

## nn optimisation grid: space of parameters tested
nnetGrid <-  expand.grid(size = seq(from = 1, to = 10, by = 1),
                         decay = c(seq(1, 10, by= 2) %o% 10^(-5:-4)),
                         mxit = c(200, 500))


best_models_nn<-function(id){
  optimisation_nn <- function(i, nnetGrid, variables){
    flag <- TRUE
    nn_model <- NULL
    # Fitting the model on the whole dataset
    set.seed(42)
    possibleError <- tryCatch(
      nn_model <- nnet::nnet(nnet::class.ind(df2$Province) ~ T  + Sal + Si + NO3 + Phos + Fe  + SI_NO3, data = df2,softmax=T,
                             size=nnetGrid[i,1], decay=nnetGrid[i,2], maxit=nnetGrid[i,3], trace=F),
      error=function(e) flag <- FALSE
    )
    test3<- nn_model$fitted.values[,2]
    TSSs <- 0
    # Performing 30 cross-validations to calculate the mean AUC (area under ROC curve) which is the parameter we chose to optimize
    cv_nn <- function(sample,i){
      df3 <- df2[sample,]
      set.seed(42)
      nn_model_cv <- nnet::nnet(nnet::class.ind(df3$Province) ~ T  + Sal + Si + NO3 + Phos + Fe  + SI_NO3 , 
                                data = df3,softmax=T, size=nnetGrid[i,1], decay=nnetGrid[i,2], maxit=nnetGrid[i,3], trace=F)
      preds <- stats::predict(nn_model_cv, df2[!(c(1:nrow(df2)) %in% sample),variables], type='raw')[,2]
      d <- cbind(df2$Province[!(c(1:nrow(df2)) %in% sample)], as.numeric(preds>0.5))
      pres <- d[d[,1]==1, 2]
      abs <- d[d[,1]==0, 2]
      sens <- sum(pres)/(sum(pres)+(length(pres)-sum(pres)))
      spec <- (length(abs)-sum(abs))/( (length(abs)-sum(abs)) +  sum(abs) )
      TSS <- sens+spec-1
      e <- dismo::evaluate(pres, abs)
      auc <- e@auc 
      cor <- e@cor
      return(c(TSS, auc, cor))
    }
    
    set.seed(42)
    samples_list <- rep(list(), 30)
    for (u in 1:30){
      df3<-NULL
      while (sum(df3[,3], na.rm = T) < 2 | sum(df3[,3], na.rm = T) == sum(df2[,3], na.rm = T)){
        samples <- sample(nrow(df2), 0.85*nrow(df2))
        df3 <- df2[samples,]
      }
      samples_list[[u]] <- samples
    }
    score_list <- lapply(samples_list, FUN = cv_nn, i=i)
    
    tss_list <- NULL
    auc_list <- NULL
    cor_list <- NULL
    for (vector in score_list){
      tss_list <- append(tss_list,vector[1])
      auc_list <- append(auc_list,vector[2])
      cor_list <- append(cor_list,vector[3])
    }
    TSSs <- mean(tss_list, na.rm=T)
    AUCs <- mean(auc_list, na.rm=T)
    CORs <- mean(cor_list, na.rm=T)
    if (flag == FALSE || is.null(nn_model)) {
      rmse1 <- NA
      AUCs <- NA
      CORs <- NA
      TSSs<- NA
    } else {
      rmse1 <- Metrics::rmse(test3[!is.na(test3)],df2$Province[!is.na(test3)])
    }
    optimisation_nn <- list(TSSs,AUCs, CORs, rmse1, nn_model)
  }
  fraction <- strsplit(id, '_')[[1]][1]
  k <- as.integer(strsplit(id, '_')[[1]][2])
  df1 <- df[df$Fraction== fraction,]
  df1 <- df1[!is.na(df1$Province),]

  df2 <- df1
  df2$Province <- as.integer(df2$Province == k)
  set.seed(42)
  df2 <- df2[sample(1:nrow(df2)),]
  df2 <- as.data.frame(df2)
  
  for (i in 6:14){
    df2[,i] <- randomForest::na.roughfix(df2[,i])
  }
  tss <- NULL
  core <- NULL
  auce <- NULL
  rmse <- NULL
  nn_models_sd <- NULL
  for (i in 1:dim(nnetGrid)[1]){
    set.seed(42)
    vec <- optimisation_nn(i, nnetGrid = nnetGrid , variables=variables)
    tss <- append(tss,vec[[1]])
    auce <- append(auce, vec[[2]])
    core <- append(core, vec[[3]])
    rmse <- append(rmse, vec[[4]])
    mod <- vec[[5]]
    print(sd(mod$fitted.values[,2]))
    nn_models_sd <- append(nn_models_sd, sd(mod$fitted.values[,2]))
  }
  # Finding the parameters combination for which the mean auc of the cross-validation is maximized
  ord <- order(auce, decreasing=T)
  marker <- 'not_ok'
  g <- NULL
  c <- 1
  while (marker != 'ok'){
    i=ord[c]
    if (nn_models_sd[i]>0.1){
      g <- i
      marker <- 'ok'
    }
    c=c+1
  }
  if (length(g)>0){
    best_model <- c(fraction,k, nnetGrid[g,1], nnetGrid[g,2],nnetGrid[g,3], tss[g], rmse[g], auce[g], core[g])
  } else{
    best_model <- c(fraction, k, NA,NA,NA,NA, NA, NA, NA)
  }
  write(c(fraction, k), 'follow_nn.txt', append=T)
  return(best_model)
}
# Initiate cluster
variables <-c(6:11,13)
no_cores <- detectCores()-1
cl <- makeCluster(no_cores)
clusterExport(cl=cl, varlist=c("df","nnetGrid",  'fractions', 'variables'))
clusters <- sort(unique(df$id))
score_list <- parSapply(cl = cl, clusters, FUN = best_models_nn)
stopCluster(cl)
# Saving the results
best_models_nn1 <-t(score_list)
colnames(best_models_nn1) <- c('Fraction','Gen', 'size', 'decay','mxit', 'tss', 'rmse', 'auc', 'cor')
best_models_nn1 <- as.data.frame(best_models_nn1)
write.table(best_models_nn1, 'best_models_nn.txt')
