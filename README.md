Not yet ready

# Basic Usage

Specify necessary parameter parameters in .config files

```
cd [PATH]/util/
nextflow run VCFs_to_PGEN_Step1.nf -c util_standard_step1.config # produce PGEN/PSAM/PVAR file for common SNPs
nextflow run VCFs_to_PGEN_Step2.nf -c util_standard_step2.config # produce PGEN/PSAM/PVAR file for SNPs to be tested
cd ..
nextflow run Regenie.nf -c Standard.config
```
## Software needed for basic usage

- Install this repository
```
git clone https://github.com/CERC-Genomic-Medicine/Regenie_pipe.git 
```
- Install regenie image (if not already installed)  
```
module load singularity    
singularity pull docker://ghcr.io/rgcgithub/regenie/regenie:VERSION.gz    
tested with  singularity pull docker://ghcr.io/rgcgithub/regenie/regenie:v2.2.4.gz  
```
software needed : Nextflow, Singularity and plink (version > 2)

## Step 1 Input file generation
Minimaly Specify in util_standard_step1.config : 

 - Output Directory Path (OutDir)
 - Complete Path to VCF/BCF (ex.[...]/* .vcf.gz ; with indexes in the same folder)
 - Bedfile of low complexity/repeat regions (instances can be fount in util file) 
* Dosage field and filters can be specified
** if there is no Family ID && using the PGEN version consider --double-id

## Step 2 Input file generation
necessary tools plink version >2
Minimaly Specify in util_standard_step2.config : 

 - Output Directory Path (OutDir)
 - Complete Path to VCF/BCF (ex.[...]/* .vcf.gz)
 - Bedfile of low complexity/repeat regions.  
* Dosage field and filters can be specified
** if there is no Family ID && using the PGEN version consider --double-id

## Regenie main implementation
Minimaly Specify in Standard.config : 
 - Output Directory Path (OutDir)
 - PGEN for Common variants (Step 1 input file generation)
 - PGEN for variants to be tested (Step 2 input file generation) 
 - njob, PheStep, SnpStep (paralelisation options)
 - Path to Regenie Image ([...] / Regenie_v*.sif) 
 - Covariant and Phenotype files (see format below)
```
FID IID Pheno1/Covar1 Pheno2/Covar2  
F1   S1      0.4            0.75
F2   S2      0.2             0.5
...
```
if there is no FID information use IIDx2 (and --double-id option in PGEN generation) psam must correspond to the FID ID column


# Advance implementations

## BGEN alternative :  
If desired, the BGEN alternate format is compatible with the main script and can be generate using :
nextflow run VCFs_to_BGEN_Step1_files_alt.nf -c util_standard_step1.config 
nextflow run VCFs_to_PGEN_Step2_files_alt.nf -c util_standard_step2.config

## Binary testing
If desired, the options parameter within Standard.config can be modified to add Binary testing specification :
 - flag : bt
 - testing flag : --firth --firth-se etc.

## Further Regenie Parameters
If desired, the options parameter within Standard.config can be modified to accomodate all Regenie options.

## Additionnal Scripts provided
- util/Scripts/random_gen.py (Generate random covariate or phenotype)
- Manhattan.py (provide cursory manhattan plot)
* needs python packages : pandas, bioinfokit, matplotlib, argparse and random

# Necessary software and their installation

BGEN most recent version available @ https://enkre.net/cgi-bin/code/bgen/dir?ci=tip (compute canada : module load nixpkgs/16.09 gcc/5.4.0 bgen/1.1.4) (for bgen files)
Plink2 available @ https://github.com/chrchang/plink-ng
QCTOOL available @ https://www.well.ox.ac.uk/~gav/qctool_v2/documentation/download.html (for BGEN files)
