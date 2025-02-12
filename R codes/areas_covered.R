
source('axis_map0.R')
source('hide_arctic.R')
coastline <- readShapeSpatial('ne_10m_coastline/ne_10m_coastline.shp')

raw_data06 <-readRDS('pred_dom06.rds')
raw_data90 <-readRDS('pred_dom90.rds')
mapping <- readRDS('rev_mapping_lo_lt.rds')
raw_data06 <- raw_data06[mapping,]
raw_data90 <- raw_data90[mapping,]
coords<- readRDS('new_stations_1deg.rds')
coords <- as.data.frame(coords)
colnames(coords) <- c('lat', 'long')
weights_cos <- readRDS('model-mean_weights_cos.rds')
tot_area <- sum(111*111*weights_cos)

best_models <- read.table('best_selected_models.txt',header = T)
best_models <- as.data.frame(best_models)
N <-dim(best_models)[1]
row.names(best_models)<-c(1:N)
#SMAGS <- unique(best_models$SMAG)

bray_curtis <- readRDS('model-mean_bray_curtis_cond_fish_eez.rds')
cond_bc <- 1-bray_curtis$b_c > 1/6


cond_na <- coords$long<30 & coords$long > -80 & coords$lat >0 
cond_sa <- coords$long<20 & coords$long > -70 & coords$lat < 0 
cond_np <- (coords$long>120 | coords$long < -90) & coords$lat >0 
cond_sp <- (coords$long>120 | coords$long < -70) & coords$lat <0 
cond_i <- coords$long>20 & coords$long < 120 & coords$lat <30 
cond_arc <- coords$lat > 60
cond_ant <- coords$lat < -60

list_conds <- list(cond_na, cond_sa, cond_np, cond_sp, cond_i)
oceans <- c('North Atlantic', 'South Atlantic', 'North Pacific', 'South Pacific', 'Indian ocean')

type0 <- 'SMAGs'
if (type0=='MAGprok'){
  comp_all <- readRDS('MAGprok_provinces_compositional_functions_diazotrophy.rds')
} else{
  comp_all <- readRDS('SMAGs_provinces_compositional_functions_genomics_trophic.rds')
}
best_models <- read.table('best_selected_models.txt', header = T)

selec<-readRDS('fractions0.rds')
full_data <- rep(list(NULL), length(selec)-1)
full_data0 <- rep(list(NULL), length(selec)-1)
frcs <- c('180-2000', '20-180', '5-20', '0.8-5', '0.22-3')
names(full_data) <- frcs
names(selec)<- frcs
letters <-c('F', 'E', 'D', 'C', 'B', 'A')

annotations0 <- list('180-2000'=c('polar', 'temperate','tropico-equatorial'), 
                     '20-180'=c('polar', 'tropico-equatorial', 'temperate'),
                     '5-20'=c('temperate', 'equatorial',  'tropical'),
                     '0.8-5' =c('polar', 'subtropical', 'subtropical', 'temperate', 'equatorial', 'subtropical', 'tropical'),
                     '0.22-3'=c('subtropical', 'equatorial', 'tropical','temperate', 'temperate', 'polar'),
                     '0-0.2'=c('tropical', 'subtropical', 'equatorial', 'temperate', 'temperate'))

conds_sizes <- list()
trans_sizes <- list()
transp_sizes <- list()
c=1
for (cond in selec){
  dom06 <- apply(raw_data06[,cond],1, which.max)
  dom90 <- apply(raw_data90[,cond],1, which.max)
  c06 = annotations0[[c]][dom06]
  c90 = annotations0[[c]][dom90]
  tc <- paste(c06, c90, sep='->')
  tp <- paste(letters[c], best_models$Gen[cond][dom06], '->', letters[c], best_models$Gen[cond][dom90], sep='')
  tpf <- paste(tp, ' ', '(', tc,')', sep='')
  condi <- dom06 != dom90
  conds_sizes[[c]] <- condi
  tc[!condi] <- F
  tpf[!condi] <- F
  tp[!condi]<-F
  trans_sizes[[c]] <-tp
  transp_sizes[[c]] <-tpf
  c=c+1
}


for (j in 1:(length(selec)-1)){
  full_data[[ frcs[j] ]] <- rep(list(NULL), length(oceans))
  names(full_data[[ frcs[j] ]])<- oceans
  full_data0[[ frcs[j] ]] <- rep(list(NULL), length(oceans))
  names(full_data0[[ frcs[j] ]])<- oceans
  cond_frc <- conds_sizes[[j]]
  for (l in 1:length(list_conds)){
    data <- NULL
    data_0 <- NULL
    for (k in 1:length(selec[[j]])){
      i=selec[[j]][k]
      cond_ba <- list_conds[[l]]
      area06 <- sum(111*111*weights_cos[cond_ba & cond_bc]*raw_data06[cond_ba & cond_bc,i])
      area90 <- sum(111*111*weights_cos[cond_ba & cond_bc]*raw_data90[cond_ba & cond_bc,i])
      area06_0 <- sum(111*111*weights_cos[cond_ba & cond_frc]*raw_data06[cond_ba & cond_frc,i])
      area90_0 <- sum(111*111*weights_cos[cond_ba & cond_frc]*raw_data90[cond_ba & cond_frc,i])
      prov <- paste(letters[j], best_models$Gen[i], sep='')
      data <- rbind(data, c(prov, area06, area90))
      data_0 <- rbind(data_0, c(prov, area06_0, area90_0))
    }
    data <- as.data.frame(data)
    colnames(data) <- c('Province', 'area06', 'area90')
    data$Province <- as.character(levels(data$Province))[data$Province]
    data$area06<- as.numeric(levels(data$area06))[data$area06]
    data$area90<- as.numeric(levels(data$area90))[data$area90]
    full_data[[ frcs[j] ]][[  oceans[l] ]] <- data
    
    data_0 <- as.data.frame(data_0)
    colnames(data_0) <- c('Province', 'area06', 'area90')
    data_0$Province <- as.character(levels(data_0$Province))[data_0$Province]
    data_0$area06<- as.numeric(levels(data_0$area06))[data_0$area06]
    data_0$area90<- as.numeric(levels(data_0$area90))[data_0$area90]
    full_data0[[ frcs[j] ]][[  oceans[l] ]] <- data_0
  }
}
saveRDS(full_data, 'areas_provinces_cond_bray_curtis_basins.rds')
saveRDS(full_data0, 'areas_provinces_cond_domchange_basins.rds')

fracs <- c('180-2000', '20-180', '5-20', '0.8-5', '0.22-3', '0-0.2')
longi<-seq(0.5,359.5,1)
longi[181:360] =as.numeric(longi[181:360])-360
longi_sorted =sort(longi)
lati<-seq(-89.5, 60, 1)
color_set <- rev(c('saddlebrown', 'red', 'dodgerblue2', 'darkgreen',
'darkviolet', 'darkorange'))
c=1
for (co in conds_sizes){
  co[co==F]=NA
  co[co==T]=1
  data_contour <- matrix(NA, ncol=150, nrow=360)
  for (i in 1:length(coords$lat)){
    data_contour[which(longi_sorted==coords$long[i]),which(lati==coords$lat[i])]= co[i]
  }
  pdf(family="Helvetica",file=paste('dominant_community_changes_',fracs[c],'.pdf', sep=''),
      width=10,height=4.065)
  par(mar=c(0,0,0,0))
  maps::map(database="world",fill=T,col="grey80",border="gray80",xpd=TRUE)
  plot(coastline,lwd=0.0475, col='black', add=T, cex=0.284)
  .filled.contour(x=longi_sorted,y=lati, z=data_contour,  col=color_set[c], levels=c(0,1))
  hide_arctic()
  axis_map0()
  dev.off()
  c=c+1
}

trans <- NULL
for (u in 1:6){
  print(u)
  for (k in unique(transp_sizes[[u]])){
    if (k!=F){
      perc <- sum(transp_sizes[[u]]==k)*100/sum(transp_sizes[[u]]!=F)
      if (perc > 3){
        trans <- c(trans, k)
      }
    }
  }
}

col_list <- list(c('darkorange', 'darkorange4', 'darkgoldenrod1', 'yellow'),c('darkviolet', 'mediumpurple1', 'magenta') ,
                 c('darkgreen', 'mediumseagreen', 'green', 'greenyellow'),
                 c('dodgerblue2', 'mediumpurple4', 'darkblue', 'darkturquoise', 'cyan', 'lightslateblue', 'slateblue4', 'skyblue', 
                   'blueviolet', 'cadetblue'),
                 c('red', 'darkred', 'coral', 'deeppink', 'indianred1', 'orangered', 'rosybrown', 'violetred', 'bisque'),
                 c('saddlebrown', 'peru', 'sandybrown', 'rosybrown', 'moccasin'))
for (u in 1:6){
  color_set=col_list[[u]]
  co=transp_sizes[[u]]
  pdf(family="Helvetica",file=paste('dominant_community_changes_trans_',fracs[u],'.pdf', sep=''),
      width=10,height=4.065) 
  par(mar=c(0,0,0,0))
  maps::map(database="world",fill=T,col="grey80",border="gray80",xpd=TRUE)
  plot(coastline,lwd=0.0475, col='black', add=T, cex=0.284)
  c=1
  for (tr in trans[grepl(letters[u], trans)]){
    cop <- co
    cop[co==tr]=1
    cop[co!=tr]=NA
    #cop[cop!=tr & !is.na(cop)]=NA
    data_contour <- matrix(NA, ncol=150, nrow=360)
    for (i in 1:length(coords$lat)){
      data_contour[which(longi_sorted==coords$long[i]),which(lati==coords$lat[i])]= cop[i]
    }
    .filled.contour(x=longi_sorted,y=lati, z=data_contour,  col=color_set[c], levels=c(0,1))
    c=c+1
  }
  
  cop <- co
  cop[co==F | co %in% trans]=NA
  cop[co!=F & !(co %in% trans) ]=1
  data_contour <- matrix(NA, ncol=150, nrow=360)
  for (i in 1:length(coords$lat)){
    data_contour[which(longi_sorted==coords$long[i]),which(lati==coords$lat[i])]= cop[i]
  }
  .filled.contour(x=longi_sorted,y=lati, z=data_contour,  col='gray', levels=c(0,1))
  
  hide_arctic()
  axis_map0()
  plot(0,0, xlim=c(0,150), ylim=c(0,150), bty='n', xaxt='n', yaxt='n', xlab='', ylab='')
  leg <- c(unique(trans[grepl(letters[u], trans)]), 'other')
  legend('topleft', legend = leg, fill=c(color_set, 'gray'), bty='n', cex=1.1)
  dev.off()
}
saveRDS(transp_sizes, 'transitions.rds')
saveRDS(trans_sizes, 'transitions_bis.rds')
saveRDS(trans, 'considered_transitions.rds')
