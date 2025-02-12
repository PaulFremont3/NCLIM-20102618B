#!bin/usr/bin/env Rscript
library("gbm")
library('randomForest')
library('mgcv')
library('nnet')
library("dismo")
library("FactoMineR")
# library("factoextra")
#library("readxl")
# library("ggplot2")
# library("reshape2")
library("gplots")
# library("plotly")
library("stringr")
# library("caret")
library('mapproj')
library('mapplots')
library('SDMTools')
library('RColorBrewer')
library('ncdf4')
library("CDFt")
library('plotrix')
library('png')
library('grid')
library('matlab')


df <- readRDS('Provinces_env_parameters_woa.rds')
variables <- c(6:11,13)
pred_2006_list<-readRDS('model-mean_pred_2006_list.rds')
pred_2090_list<-readRDS('model-mean_pred_2090_list.rds')
drivers_solo <- readRDS('drivers_solo_niche.rds')
selections <- readRDS('selections.rds')
n <- dim(pred_2006_list)[2]
latitude <- readRDS('latitude.rds')
deltas <- readRDS('deltas.rds')
latitude0 <- as.vector(latitude)[!is.na(apply(deltas, 1, sum))]

stats <- NULL
stats_area <- NULL
for (i in 1:n){
  drivers_ <- drivers_solo[[i]]
  sel_<- selections[[i]]
  weights_cos <- cos(latitude0[sel_]*2*pi/360)
  stats <- append(stats, colnames(pred_2006_list)[i])
  stats_area <- append(stats_area, colnames(pred_2006_list)[i])
  max_driv_area <- apply(drivers_, 1,which.max)
  deltas <- abs(pred_2090_list[sel_, i]- pred_2006_list[sel_, i])
  for (j in 1:7){
    stats_area <- append(stats_area, sum(weights_cos[max_driv_area==j])/sum(weights_cos))
    stats <- append(stats, sum(drivers_[,j]*weights_cos*deltas)/sum(weights_cos*deltas))
  }
}

stats <- matrix(stats, ncol=8, byrow = T)
colnames(stats)<- c('cluster', colnames(df)[variables])
write.table(stats,file='drivers_solo_niches.txt', col.names=T)


stats_area <- matrix(stats_area, ncol=8, byrow = T)
colnames(stats_area)<- c('cluster', colnames(df)[variables])
write.table(stats,file='drivers_solo_niches_area.txt', col.names=T)

stats_up <- NULL
stats_area_up <- NULL
upwelling_clusters <- c('5-20_4','0.8-5_9', '0.22-3_3', '0-0.2_6')
for (u in upwelling_clusters){
  i <- which(colnames(pred_2006_list)==u)
  drivers_ <- drivers_solo[[i]]
  sel_<- selections[[i]]
  weights_cos <- cos(latitude0[sel_]*2*pi/360)
  sel0 <- latitude0[sel_]<23.5 & latitude0[sel_]>-23.5
  stats_up <- append(stats_up, colnames(pred_2006_list)[i])
  stats_area_up <- append(stats_area_up, colnames(pred_2006_list)[i])
  max_driv_area <- apply(drivers_, 1,which.max)
  deltas <- abs(pred_2090_list[sel_, i]- pred_2006_list[sel_, i])
  for (j in 1:7){
    stats_area_up <- append(stats_area_up, sum(weights_cos[max_driv_area==j & sel0])/sum(weights_cos[sel0]))
    stats_up <- append(stats_up, 
                       sum(drivers_[sel0,j]*weights_cos[sel0]*deltas[sel0])/sum(weights_cos[sel0]*deltas[sel0]))
  }
}
stats_up <- matrix(stats_up, ncol=8, byrow = T)
colnames(stats_up)<- c('cluster', colnames(df)[variables])
write.table(stats_up,file='drivers_solo_niches_area_upwelling.txt', col.names=T)

stats_area_up <- matrix(stats_area_up, ncol=8, byrow = T) 
colnames(stats_area_up)<- c('cluster', colnames(df)[variables])
write.table(stats_area_up,file='drivers_solo_niches_area_upwelling.txt', col.names=T)
