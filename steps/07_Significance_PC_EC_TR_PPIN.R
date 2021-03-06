
rm(list = ls())

library(igraph)
source("config/PIPELINE_PARAMS.R")
source("utils/getTiming.R")
source("steps/07_PC_Significance_EC_TR/significance_test.R")
source("steps/07_PC_Significance_EC_TR/MultiplePlotSignificance.R")

DATA_DIR = file.path(Global.DATA_DIR, Global.G.name)
NEXT_DIR = Global.SIGNIFICANCE_PC_NEXTDIR
roundTo = Global.PC.roundTo
Ts = Global.SIGNIFICANCE_PC.Tvalues
G.name = Global.G.name
roundTo  = Global.PC.roundTo

old_data = list.files(".", pattern = "results_PC" , include.dirs = T)
for (od in old_data) 
  unlink(od, recursive = T)

if (!dir.exists(NEXT_DIR)) {
  dir.create(NEXT_DIR, recursive = T)
}
if (!dir.exists(NEXT_DIR))
  stop("Unable to create NEXT_DIR directory.")


random_types = c("EC", "TR")
rank_types = Global.rank_types
func_types = c()
if (length(Global.ranking.incrementals))
  func_types = c(func_types, "incremental")
if (length(Global.ranking.decrementals))
  func_types = c(func_types, "decremental")

#  Colori
FIncrementalColors = Global.FIncrementalColors 
FDecrementalColors = Global.FDecrementalColors

#  Carica matrici RPF in una unica lista
for (percs in Global.percs) {
  
  granularity = as.character(percs[1])
  
  RPF_EC.file = file.path(Global.RE_PC_EC_NEXTDIR, 
                          paste("results_PC_EC_random", G.name, granularity, sep="_"), 
                          "RPF.Rdata")
  
  RPF_TR.file = file.path(Global.RE_PC_TR_NEXTDIR, 
                          paste("results_PC_TR_random", G.name, granularity, sep="_"), 
                          "RPF.Rdata")
  
  PC_DATA = file.path(Global.PC_NEXTDIR, 
                      paste("results_PC", G.name, granularity, sep="_"))
  
	cat(sprintf("RPF_EC=%s\n", RPF_EC.file))
	cat(sprintf("RPF_TR=%s\n", RPF_TR.file))
	cat(sprintf("PC_DATA=%s\n", PC_DATA))
	
  tA = Sys.time()
  
  load(RPF_EC.file)
  RPF.EC = RPF$EC
  load(RPF_TR.file)
  RPF[[ "EC" ]] = RPF.EC
  rm(RPF.EC)
  
  getTiming(tA, Sys.time(), "loading RPF matrices")
  
  #  Trasponi matrici
  tA = Sys.time()
  
  RPF[[ "TR" ]][[ "incremental" ]][[ "R" ]] = t(RPF[[ "TR" ]][[ "incremental" ]][[ "R" ]])
  RPF[[ "TR" ]][[ "incremental" ]][[ "P" ]] = t(RPF[[ "TR" ]][[ "incremental" ]][[ "P" ]])
  RPF[[ "TR" ]][[ "incremental" ]][[ "Fm" ]] = t(RPF[[ "TR" ]][[ "incremental" ]][[ "Fm" ]])
  
  RPF[[ "TR" ]][[ "decremental" ]][[ "R" ]] = t(RPF[[ "TR" ]][[ "decremental" ]][[ "R" ]])
  RPF[[ "TR" ]][[ "decremental" ]][[ "P" ]] = t(RPF[[ "TR" ]][[ "decremental" ]][[ "P" ]])
  RPF[[ "TR" ]][[ "decremental" ]][[ "Fm" ]] = t(RPF[[ "TR" ]][[ "decremental" ]][[ "Fm" ]])
  
  for (RANKTYPE in rank_types) {
    for (FTYPE in func_types) {
      for (f in names(RPF[[ "EC" ]][[ RANKTYPE ]][[ FTYPE ]])) {
        RPF[[ "EC" ]][[ RANKTYPE ]][[ FTYPE ]][[ f ]][[ "R" ]] = t(RPF[[ "EC" ]][[ RANKTYPE ]][[ FTYPE ]][[ f ]][[ "R" ]])
        RPF[[ "EC" ]][[ RANKTYPE ]][[ FTYPE ]][[ f ]][[ "P" ]] = t(RPF[[ "EC" ]][[ RANKTYPE ]][[ FTYPE ]][[ f ]][[ "P" ]])
        RPF[[ "EC" ]][[ RANKTYPE ]][[ FTYPE ]][[ f ]][[ "Fm" ]] = t(RPF[[ "EC" ]][[ RANKTYPE ]][[ FTYPE ]][[ f ]][[ "Fm" ]])
      }
    }
  }
  
  getTiming(tA, Sys.time(), "transposing RPF matrices")
  
  
  for (RRTYPE in random_types) {
    
    # Crea cartelle di output
    OUTPUT_DIR = file.path(paste("results_PC",        # results_GC_WGN_EC_N100_<date>
                                 #format(Sys.time(), "%Y_%m_%d_%H%M%S"),
                                 RRTYPE,
                                 granularity,
                                 sep = "_"))
    
    if (!dir.exists(OUTPUT_DIR)) {
      dir.create(OUTPUT_DIR, recursive = T)
    } else {
      warning("OUTPUT_DIR exists yet, specify another results directory.")
    }
    
    for (RANKTYPE in rank_types) {
      for (FTYPE in func_types) {
        dir.create(file.path(OUTPUT_DIR, 
                             RANKTYPE,
                             FTYPE), recursive = TRUE)
      }
    }
    
  }
  
  
  #  Codice
  for (RRTYPE in random_types) {
    for (RANKTYPE in rank_types) {
      for (FTYPE in func_types) {
        
        OUTPUT_DIR = file.path(paste("results_PC",        # results_GC_WGN_EC_N100_<date>
                                     #format(Sys.time(), "%Y_%m_%d_%H%M%S"),
                                     RRTYPE,
                                     granularity,
                                     sep = "_"))
        
        for (perfm in c("R", "P", "Fm")) {
          # 1. WPF:  P[f, ], valori di performance reali (osservati)
          WPF.file = file.path(PC_DATA,   # results_PC/
                               RANKTYPE,  # results_PC/static
                               FTYPE,     # results_PC/static/incremental
                               paste(perfm, ".txt", sep=""))     
          
          if(! file.exists(WPF.file))
            next
          
          cat(sprintf("* Processing %s_%s: %s\n", RRTYPE, file.path(PC_DATA, RANKTYPE, FTYPE), perfm))
          WPF = read.table(WPF.file, check.names = F)
          
          # 2. RPF[[ RRTYPE ]][[ RANKTYPE ]][[ FTYPE ]], valori performance da esperimenti casuali
          # Ce li ho gi?? nella lista RPF.
          
          # 3. Compute significance
          S = WPF
          
          if (RRTYPE == "TR") {
            odir = file.path(OUTPUT_DIR, RANKTYPE, FTYPE)
            
            for (f in rownames(WPF))
              S[f, ] = significance_test(t(WPF[f, ]),                 # trasposta di P[f, ] 
                                         RPF[[ "TR" ]][[ FTYPE ]][[ perfm]],    # trasposta (a monte) di RPF
                                       	 roundTo=roundTo,                                         
                                         minus=F) 
          } else if (RRTYPE == "EC") {
            odir = file.path(OUTPUT_DIR, RANKTYPE, FTYPE)
            
            for (f in rownames(WPF)) {
              S[f, ] = significance_test(t(WPF[f, ]),                          
                                         RPF[[ "EC" ]][[ RANKTYPE ]][[ FTYPE ]][[ f ]][[ perfm ]],
                                         roundTo=roundTo,
                                         minus=F) 
            }
          } else {
            stop("ERROR: unrecognized RRTYPE, check parameters.")
          }
          
          outputF = file.path(odir,
                              paste("S", "_", perfm, ".csv", sep = ""))
          write.table(S, outputF, sep = ",", col.names = F)                  # scrivo S sia in .csv che .Rdata
          
          outputF = file.path(odir,
                              paste("S", "_", perfm, ".Rdata", sep = ""))
          save(S, file=outputF)
          
          
          # 6:  thresholding significance
          for (thr in Ts) {
            Sb = S
            Sb = Sb >= thr
            Sb = matrix(apply(Sb, 2, as.integer), nrow=nrow(S), ncol=ncol(S), dimnames = list(rownames(S), colnames(S)))

            outputF = file.path(odir,
                                paste("S_", perfm, "_", thr , ".csv", sep = ""))
            write.table(Sb, outputF, sep = ",", col.names = F)              # scrivo S sia in .csv che .Rdata
            
            outputF = file.path(odir,
                                paste("S_", perfm, "_", thr , ".Rdata", sep = ""))
            save(Sb, file=outputF)
            
            # 7:  plot
            # plotSignificance: write single plot, multiple plot
            # single plots
            for (f in rownames(WPF)) {
              outputF = file.path(odir, paste(f, "_", perfm, "_", ((1-thr)*100), ".pdf", sep=""))
              #cat(sprintf("%s: %s\n", f, outputF))
              MultiplePlotSignificance(Sb[f, ], WPF[f, ], 
                                       roundTo=roundTo,
                                       title=paste(f, ", confidence level ", ((1-thr)*100), "%", sep=""),
                                       Flabel=f, ##outputFile='')
                                       outputFile=outputF)
            }
            
# #            multiple plot
#             if (FTYPE == "incremental") {
#               color = FIncrementalColors
#             } else {
#               color = FDecrementalColors
#             }
#             
#             outputF = file.path(odir, paste("overall_",  ((1-thr)*100), ".pdf", sep=""))
#             cat(sprintf("%s: %s\n", f, outputF))
#             MultiplePlotSignificance(Sb, WPF, 
#                                      roundTo=roundTo,
#                                      title=paste("overall comparison, confidence level ", ((1-thr)*100), "%", sep=""),
#                                      Flabel=rownames(WPF),
#                                      color=color, ##outputFile='',
#                                      outputFile=outputF,
#                                      legendPos="topleft")
            
          }
          
        }
        
        # COPIA
        file.copy(from=OUTPUT_DIR, to=file.path(NEXT_DIR), recursive=T)
        
      }
    }
  }
  
}

# Remove the temporary output dir
unlink("results_*", recursive=TRUE)
