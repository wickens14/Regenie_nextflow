params {

  pheno_file = "[PATH]/[file]"				//see read.me
  genotypes_file = "[PATH]/[file]"			//Modeling SNPs file PGEN or BGEN (both with associate file in directory)
  covar_file = "[PATH]/[file]"				//Single
  
  gwas_genotypes_files  = "[PATH]/[file]"   //Association testing SNPs file  PGEN or BGEN (both with associate file in directory)

  njobs=                                       //SNPs parrallelisation step 1 (nb jobs/1st dimension) not implemented for LOCO analysis by definition
  PheStep=                                     //Phenotype parralelisation (nb jobs/2nd dimension)]
  SnpStep = 					//SNPs parrallelisation step 2 (1st dimention) (i.e. total nb of SNPs / snpstep = nb jobs @ second step)
  OutDir="[PATH_OUTPUT_DIR]"                                      //Path to out directory
  Bsize=1000                                   //Number of Nb SNP into sub-buckets
                        //    Threads  ## optimal with CPU below
  Threads_S_10=1 //step 1.0: Split into Ridges
  Threads_S_11=2 //step 1.1: Ridge predictions
  Threads_S_12=2 //step 1.2: LOCO predictions
  Threads_S_2=2  //step 2 :  Association testing

                        //     Optional    
                                                                                                // files must be written with path

//                  List of supported options
// --sample	FILE	         ## optionnal must correspond to BGEN file
// --ref-first	FLAG       ## optional	Specify to use the first allele as the reference allele for BGEN input [default is to use the last allele as the reference]
// --keep	FILE		         ## Optional Inclusion file that lists individuals to retain in the analysis
// --remove	FILE	         ## Optional	Exclusion file that lists individuals to remove from the analysis
// --exclude	FILE         ## Optional	Exclusion file that lists IDs of variants to remove
// --extract-or	FILE       ## Optional	Inclusion file that lists IDs of variants to keep regardless of minimum MAC filter
// --exclude-or	FILE       ## Optional	Exclusion file that lists IDs of variants to remove unless MAC is above threshold
// --covarFile	FILE       ## Optional	Covariates file
// --covarCol	STRING       ## Optional	Use for each covariate you want to include in the analysis
// --covarColList	STRING   ## Optional	Comma separated list of covariates to include in the analysis
// --catCovarList	STRING   ## Optional	Comma separated list of categorical covariates to include in the analysis
// --bt	FLAG	             ## Optional	specify that traits are binary with 0=control,1=case,NA=missing (default is quantitative)
// -1,--cc12	FLAG	       ## Optional	specify to use 1/2/NA encoding for binary traits (1=control,2=case,NA=missing)
// --cv	INT	               ## Optional	number of cross validation (CV) folds [default is 5]
// --loocv	FLAG           ## Optional	flag to use leave-one out cross validation
// --lowmem	FLAG           ## Optional	flag to reduce memory usage by writing level 0 predictions to disk (details below). This is very useful if the number of traits is large (e.g. greater than 10)
// --keep-l0	FLAG	       ## Optional	avoid deleting the level 0 predictions written on disk after fitting the level 1 models
// --print-prs	FLAG	     ## Optional	flag to print whole genome predictions (i.e. PRS) without using LOCO scheme
// --force-step1	FLAG     ##	Optional	flag to run step 1 when >1M variants are used (not recommened)
// --minCaseCount	INT      ##	Optional	flag to ignore BTs with low case counts [default is 10]
// --apply-rint	FLAG       ##	Optional	to apply Rank Inverse Normal Transformation (RINT) to quantitative phenotypes
// --nb	INT	               ## Optional number of blocks (determined from block size if not provided)
// --strict	FLAG	         ## Optional	flag to removing samples with missing data at any of the phenotypes
// --ignore-pred	FLAG     ## Optional	skip reading the file specified by --pred (corresponds to simple linear/logistic regression)
// --use-prs	FLAG	       ## Optional	flag to use whole genome PRS in --pred (this is output in step 1 when using --print-prs)
// --force-impute	FLAG     ## Optional	flag to keep and impute missing observations for QTs in step 2
// --write-samples	FLAG	 ## Optional	flag to write sample IDs for those kept in the analysis for each trait in step 2
// --print-pheno	FLAG	   ## Optional	flag to write phenotype name in the first line of the sample ID files when using --write-samples
// --firth	FLAG	         ## Optional	specify to use Firth likelihood ratio test (LRT) as fallback for p-values less than threshold
// --approx	FLAG	         ## Optional	flag to use approximate Firth LRT for computational speedup (only works when option --firth is used)
// --firth-se	FLAG         ##	Optional	flag to compute SE based on effect size and LRT p-value when using Firth correction (instead of based on Hessian of unpenalized log-likelihood)
// --write-null-firth	FLAG ##	Optional	to write the null estimates for approximate Firth [can be used in step 1 or 2]
// --use-null-firth	FILE   ##	Optional	to use stored null estimates for approximate Firth in step 2
// --spa	FLAG             ## Optional	specify to use Saddlepoint approximation as fallback for p-values less than threshold
// --pThresh	FLOAT        ## Optional	P-value threshold below which to apply Firth/SPA correction [default is 0.05]
// --test	STRING           ## Optional	specify to carry out dominant or recessive test [default is additive; argument can be dominant or recessive]
// --chr	INT	             ## Optional	specify which chromosomes to test in step 2 (use for each chromosome to include)
// --minMAC	FLOAT          ## Optional	flag to specify the minimum minor allele count (MAC) when testing variants [default is 5]. Variants with lower MAC are ignored.
// --minINFO	FLOAT	       ## Optional	flag to specify the minimum imputation info score (IMPUTE/MACH R^2) when testing variants. Variants with lower info score are ignored.
// --sex-specific	STRING	 ## Optional	to perform sex-specific analyses [either 'male'/'female']
// --af-cc	FLAG	         ## Optional	to output A1FREQ in case/controls separately in the step 2 result file
// --nauto	INT	           ## Optional	number of autosomal chromosomes (for non-human studies) [default is 22]
// --maxCatLevels	         ## INT	Optional	maximum number of levels for categorical covariates (for non-human studies) [default is 10]
// --niter	INT	           ## Optional	maximum number of iterations for logistic regression [default is 30]
// --maxstep-null	INT	     ## Optional	maximum step size for logistic model with Firth penalty under the null [default is 25]
// --maxiter-null	INT	     ## Optional	maximum number of iterations for logistic model with Firth penalty under the null [default is 1000]

// some options are unavailable as they are used in the paralelisation process or would crash said paralelisation but could be performed in pre-processing
}

singularity {

	enabled = true
	autoMounts = true
}


process {
withLabel: 'STEP_1_0|STEP_1_1|STEP_1_2|Asscociation_testing' {
container = "file:///path/to/regenie_v2.2.4.gz.sif"
    }
	  
withLabel: 'STEP_1_0' {    // Spliting for ridge prediction
  cpus = 1
  time = "1h"
  memory = "4GB"
    }

withLabel: 'STEP_1_1' {    // Ridge prediction
  cpus = 2
  time = "1h"
  memory = "4GB"
    }

withLabel: 'STEP_1_2' {    // LOCO analysis
  cpus = 2
  time = "4h"
  memory = "8GB"
    }
    
withLabel: 'Asscociation_testing' {      // Association testing
  cpus = 2
  time = "4h"
  memory = "4GB"
    }

  executor = "slurm"
  	// can add --account=[] to cluster Options
  clusterOptions = ""
  cpus = 1
  time = "12h"
  memory = "10GB"
}

executor {
        $slurm {
              queueSize = 100
              jobName = { "Regenie" }
        }
        $local {
                cpus = 1
        }
}
