##########################
message("#################################################################################################################")
message("#DilutionPickR  v0.12")
message("#J Bisanz 22 Feb 2022")
message("#Picks appropriate dilution from primary PCR for AmpliconSeq Protocol")
message("#################################################################################################################")
message(" ")

theme_plt<-function () {
  theme_classic(base_size = 8, base_family = "Helvetica") + 
    theme(panel.border = element_rect(color = "black", size = 1, 
                                      fill = NA)) + theme(axis.line = element_blank(), 
                                                          strip.background = element_blank())
}

#.libPaths("/data/shared_resources/Rlibs_4.1.0")

##########################
#Get arguments
suppressMessages(library(optparse))
option_list = list(
  make_option(c("-d", "--folder"), type="character", help="A folder of csvs exported from CFX opus  containing ...Quantification Amplification Results_SYBR.csv", metavar="character"),
  make_option(c("-t", "--tracking"), type="character", help="The 16S tracking sheet (an excel file downloaded from AmpliconSeq).", metavar="character"),
  make_option(c("-i", "--plateid"), type="numeric", default="1", help="Which plate are we looking at (to pull sample names)?", metavar="character"),
  make_option(c("-o", "--output"), type="character", default="WellsForIndexing.csv", help="A csv file which will contain the appropriate wells to pick", metavar="character"),
  make_option(c("-p", "--pdf"), type="character", default="PrimaryCurves.pdf", help="A set of ", metavar="character"),
  make_option(c("-c", "--persamplecurves"), type="character", default="PerSample_PrimaryCurves.pdf", help="A set of ", metavar="character"),
  make_option(c("-r", "--rfu"), type="numeric", help="The max RFU used for picking (default=detected from samples using 3rd quartile)", metavar="numeric"),
  make_option(c("-f", "--fraction"), type="numeric", default="0.8", help="Pick the dilution closest to fraction x  RFU", metavar="numeric"),
  make_option(c("-l", "--libpath"), type="character", default="/data/shared_resources/Rlibs_4.1.0", help="Location", metavar="numeric")
)

opt_parser = OptionParser(option_list=option_list)
opt = parse_args(opt_parser)

.libPaths(opt$libpath)


#opt$folder="Plate3/"
#opt$tracking="LSDTrackingSheet_20Oct2021.xlsx"
#opt$plateid="3"

if (is.null(opt$folder) | is.null(opt$tracking) | is.null(opt$plateid)){
  print_help(opt_parser)
  stop("Specify the ampification results (--csv), tracking sheet (--tracking), and plate ID (--plateid)", call.=FALSE)
}

message(date(), "---> Loading tidyverse and readxl")
suppressMessages(library(tidyverse))
suppressMessages(library(readxl))

files<-list.files(opt$folder, pattern="Quantification Amplification Results_SYBR\\.csv", full.names = TRUE)
if(length(files)!="1"){
  message(opt$folder)
  stop("Error: too many (or no) amplification results found, please make sure only 1 run per folder!")
  }

message(date(), paste("---> Reading ", files))
suppressMessages(suppressWarnings(amps<-read_csv(files)))
suppressMessages(suppressWarnings(tracking<-read_excel(opt$tracking, col_names = FALSE)))

if(length(tracking$SampleID)!=length(unique(tracking$SampleID))){stop("There are duplicated sample names, please make sure every sample has a unique name!")}

amps<-
  amps %>%
  select(-1) %>%
  gather(-Cycle, key="Well", value="RFU")

line<-grep(paste0("Extraction and Indexing Plate ", opt$plateid, " of 6"), tracking[,1]$...1)

tracking<-tracking[(line+1):(line+9),]
colnames(tracking)<-c("Row", 1:12)
tracking<-
  tracking[-1,] %>%
  gather(-Row, key="Column", value="SampleID") %>%
  mutate(Column=as.numeric(Column))
  
tracking<-
  tracking %>%
  dplyr::select(SampleID, Row_96well=Row, Column_96well=Column)

tracking$Row_384well <- rep(seq(1,16,2),12)
tracking$Column_384well <- tracking$Column_96well

tracking<-
bind_rows(tracking %>% mutate(dilution=1),
      tracking %>% mutate(Row_384well=Row_384well+1, dilution=10),
      tracking %>% mutate(Column_384well=Column_384well+12, dilution=100),
      tracking %>% mutate(Row_384well=Row_384well+1,Column_384well=Column_384well+12, dilution=1000)
)

tracking<-tracking %>% mutate(Row_384well=LETTERS[Row_384well])

tracking<-tracking %>% 
  mutate(Well_96=paste0(Row_96well, Column_96well), Well_384=paste0(Row_384well, Column_384well)) %>%
  dplyr::select(SampleID, dilution, Well_96, Well_384)

suppressMessages(
amps<-
amps %>% dplyr::rename(Well_384=Well) %>% left_join(tracking) %>%
  filter(!grepl("^Empty", SampleID)) %>%
  dplyr::select(SampleID, dilution, Well_96, Well_384, Cycle, RFU)
)

if(is.null(opt$rfu)){opt$rfu<-amps %>% filter(dilution==1 & Cycle==max(amps$Cycle)) %>% pull(RFU) %>% median()}

picks<-
amps %>%
  filter(Cycle==max(amps$Cycle)) %>%
  group_by(SampleID) %>%
  filter(abs(RFU - (opt$rfu*opt$fraction)) == min(abs(RFU - opt$rfu*opt$fraction))) %>%
  select(SampleID, dilution, Well_96) %>%
  mutate(Status="Index")

if(nrow(picks)!=nrow(subset(amps, dilution==1 & Cycle==1))){stop("Error: For some reason not all samples have a dilution picked, manually inspect!")}

amps<-
amps %>%
  left_join(picks) %>%
  mutate(Status=if_else(is.na(Status), "Discard","Index"))



pdat<-
amps %>%
  mutate(Column=gsub("[A-Z]","", Well_96) %>% as.numeric()) %>%
  mutate(Row=gsub("[0-9]","", Well_96))

  ggplot(pdat, aes(x=Cycle, y=RFU, color=Status, group=Well_384)) +
  geom_hline(yintercept = opt$rfu, linetype="dashed", color="grey80") +
  geom_line() +
  ggtitle(paste0("Samples for Indexing: Plate ", opt$plateid)) +
  facet_grid(Row~Column) +
  scale_x_continuous(breaks=seq(1,25,5)) +
  scale_color_manual(values=c("grey80","indianred")) +
  theme_plt() +
  theme(legend.position="bottom") +
  geom_text(data=subset(pdat, Cycle==1 & dilution==1), aes(label=SampleID, x=2, y=0.2*opt$rfu), size=2, hjust=0, vjust=1, color="black")
ggsave(paste0("PrimaryCurves_Plate",opt$plateid,".pdf"), height=8.5, width=11, useDingbats=F)


pdf(paste0("PerSampleCurves_Plate",opt$plateid,".pdf"), height=8.5, width=11, useDingbats=F)
for(p in unique(pdat$SampleID)){
  print( 
    pdat %>%
    filter(SampleID==p) %>%
    mutate(Status=factor(Status, levels=c("Index","Discard"))) %>%
    ggplot(aes(x=Cycle, y=RFU, color=paste(dilution, ": ", Well_384), group=Well_384, linetype=Status)) +
    geom_hline(yintercept = opt$rfu, linetype="dashed", color="grey80") +
    geom_line() +
    ggtitle(paste0("Samples for Indexing: Plate ", opt$plateid)) +
    scale_x_continuous(breaks=seq(1,25,5)) +
    theme_plt() +
    ggtitle(paste(p)) +
    scale_color_manual(values=c("blue4", "olivedrab", "firebrick", "darkorchid"), name="Dilution")
  )
}
dev.off()



amps %>%
  filter(Cycle==max(amps$Cycle) & Status=="Index") %>%
  arrange(Well_96) %>%
  select(SampleID, dilution, gDNA_Well=Well_96, PrimaryPCR_Well=Well_384) %>%
  mutate(row=gsub("[A-Z]", "", gDNA_Well) %>% as.numeric()) %>%
  mutate(column=gsub("[0-9]", "", gDNA_Well)) %>%
  arrange(row) %>%
  arrange(column) %>%
  dplyr::select(-row, -column) %>%
  write_csv(gsub("\\.csv",paste0("_Plate",opt$plateid,".csv"),opt$output))
 
message("---------------------------> !!!Script is complete, please manually check over outputs!!!")

