//Description : From vcf files (with indexes) to a single bgen file with custom filter

// Typicall VCF/BCF/PGEN/BGEN files are already split by chromosome. We make use of this, and process each of them in parallel.

process filter_by_chrom_VCF_BCF {
  cache "lenient"
  //scratch true

  input:
  path vcf // accepts VCF or BCF
  each path(LCR_bed)
  each path(LD_bed)
  
  output:
  path "${vcf.getBaseName()}.common_independent_snps.*",  emit: filtered_by_chrom
      
  """
  # Apply hard filters and identify independent SNPs
  if [ ${vcf.getExtension()} = "bcf" ]; then
     plink_import_option="--bcf ${vcf} ${params.name}"
  else
     plink_import_option="--vcf ${vcf} ${params.name}"
  fi

  cat ${LCR_bed} ${LD_bed} > exclude_bed.gz
  ${params.plink2_exec} \${plink_import_option} \
    --maf ${params.maf} \
    --geno ${params.geno} \
    --mind ${params.mind} \
    --hwe ${params.HWE} \
    --min-alleles 2 \
    --max-alleles 2 \
    --exclude bed0 exclude_bed.gz \
    --snps-only \
    --set-all-var-ids '@:#:\$r:\$a' \
    --indep-pairwise 1000 100 ${params.Rsq} \
    --make-pgen\
    --out common_snps

  # Keep only independent SNPs
  ${params.plink2_exec} \
    --pfile common_snps \
    --extract common_snps.prune.in \
    --make-pgen erase-phase \
    --out ${vcf.getBaseName()}.common_independent_snps
  """
}

process filter_by_chrom_pgen_bgen {
  cache "lenient"
  //scratch true

  input:
  tuple path(input), path(sample_file), path(additional_file)
  each path(LCR_bed) 
  each path(LD_bed) 

  output:
  path "${input.getBaseName()}.common_independent_snps.*", emit: filtered_by_chrom

  """
  # Apply hard filters and identify independent SNPs
  if [ ${input.Extension} = "pgen" ]; then
     plink_import_option="--pgen ${input} --pvar ${additional_file} --psam ${sample_file}"
  else
     plink_import_option="--bgen ${input} --sample ${sample_file}"
  fi

  cat ${LCR_bed} ${LD_bed} > exclude_bed.gz
  ${params.plink2_exec} \${plink_import_option} \
    --maf ${params.maf} \
    --geno ${params.geno} \
    --hwe ${params.HWE} \
    --mind ${params.mind} \
    --min-alleles 2 \
    --max-alleles 2 \
    --exclude bed0 exclude_bed.gz \
    --snps-only \
    --set-all-var-ids '@:#:\$r:\$a' \
    --indep-pairwise 1000 100 ${params.Rsq} \
    --make-pgen  ${params.name}\
    --out common_snps

  # Keep only independent SNPs
  ${params.plink2_exec} \
    --pfile common_snps \
    --extract common_snps.prune.in \
    --make-pgen erase-phase ${params.name} \
    --out ${input.getBaseName()}.common_independent_snps
  """
}
process merge_chroms {
  cache "lenient"
  //scratch true

  input:
  path(pfiles)

  output:
  path "all.common_independent_snps.*", emit:pgen
  publishDir "${params.OutDir}/", pattern: "all.common_independent_snps.*", mode: "copy"
    
  script:
  if (params.format == "PGEN")
     """
     find . -name "*.pgen" -printf "%f\n" | sort -V | sed s"/.pgen//" > files.txt
     ${params.plink2_exec} --pmerge-list files.txt --make-pgen ${params.name} --out all.common_independent_snps
     """

  else if (params.format == "BGEN")
     """
     find . -name "*.pgen" -printf "%f\n" | sort -V | sed s"/.pgen//" > files.txt
     ${params.plink2_exec} --pmerge-list files.txt --export vcf-4.2 bgz ref-first --out temporary_merged_vcf
     ${params.qctool_exec} -g temporary_merged_vcf.vcf.gz -filetype vcf -bgen-bits 8 -og all.common_independent_snps.bgen -os all.common_independent_snps.sample
     ${params.bgenix_exec} -index -g all.common_independent_snps.bgen
     """
  
  else
     error "Invalid output format: ${params.format}"
}


workflow {
	geno = Channel.fromPath(params.genotypes_file,checkIfExists:true)
	LCR_bed = Channel.fromPath("${workflow.projectDir}/Low_complexity_regions/${params.lcr_regions}.bed.gz")
	LD_bed = Channel.fromPath("${workflow.projectDir}/Low_complexity_regions/${params.ld_regions}.bed.gz")
	println(params.genotypes_file[-4..-1]);
	if(params.genotypes_file[-4..-1] == "pgen" || params.genotypes_file[-4..-1] == "bgen"){
		pbgen = geno.map(f -> f.getExtension() == "pgen" ? [f, file("${f.getParent()}/${f.getBaseName()}.psam"), file("${f.getParent()}/${f.getBaseName()}.pvar")] : [f, file("${f.getParent()}/${f.getBaseName()}.sample"), ""]);
		filtered_by_chrom = filter_by_chrom_pgen_bgen(pbgen, LCR_bed, LD_bed)
		}
	else if(params.genotypes_file[-3..-1] == "bcf" || params.genotypes_file[-3..-1] == "vcf" || params.genotypes_file[-6..-1] == "vcf.gz" || params.genotypes_file[-6..-1] == "bcf.gz"){
		filtered_by_chrom = filter_by_chrom_VCF_BCF(geno, LCR_bed, LD_bed)

	}
	else{
	error "Invalid Input format please use PGEN,BGEN,VCF or BCF"
}
output = merge_chroms(filtered_by_chrom.collect())
}
