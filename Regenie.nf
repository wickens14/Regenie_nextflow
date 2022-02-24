
process chunk_phenotype {
  label "chunk"
  executor "local"
  cache "lenient"
    
  input :
  file pheno_file from Channel.fromPath(params.pheno_file) // phenotype file will be staged (usually with hard-link) to the work directory

  output:
  file "chunk_*_phe.txt" into chunks_phenotypes mode flatten
  
  publishDir "${params.OutDir}/chunked_pheno", pattern: "chunk_*_phe.txt", mode: "copy"

  """
  # make sure phenotype file is tab-delimited
  cat ${pheno_file} | tr " " "\t" > temp_pheno_file.txt  
  
  Nb_PHENO=\$((\$(head -n 1 temp_pheno_file.txt | wc -w ) - 2)) 
  val=\$((\$Nb_PHENO/${params.PheStep}))
  if [[ \$val > 1 ]]; then
    for ((Q=1;Q<=\$val;Q++)); do
      cut -f 1,2,\$((( \$Q - 1) * ${params.PheStep} + 3 ))-\$(((\$Q * ${params.PheStep}) + 2)) temp_pheno_file.txt > chunk_\${Q}_phe.txt
    done
  else
    cp temp_pheno_file.txt chunk_1_phe.txt
  fi
  """
}

//____________________________________STEP 1 __________________________________________
process step1_l0 {
  label "STEP_1_0"
  cache "lenient"
  scratch false
  


  input:
  tuple val(pheno_chunk_no), file(pheno_chunk) from chunks_phenotypes.map { f -> [f.getBaseName().split('_')[1], f] } 
tuple file(common), file(sample_file), file(pvar) from Channel.fromPath(params.CommonVar_file[-4..-1]=="pgen" ? [params.CommonVar_file, params.CommonVar_file.replaceAll('.pgen', '.pvar'), params.CommonVar_file.replaceAll('.pgen', '.psam')] :[params.CommonVar_file,"NULL",params.CommonVar_file.replaceAll('.bgen$', '.sample')]).toSortedList()




  output:
  tuple val(pheno_chunk_no), file(pheno_chunk), file("fit_bin${pheno_chunk_no}.master"), file("fit_bin${pheno_chunk_no}_*.snplist") into step1_l0_split mode flatten
  file "*.log" into step1_l0_logs

  publishDir "${params.OutDir}/step1_l0_logs", pattern: "*.log", mode: "copy"

script :
if (params.CommonVar_file[-4..-1]=="pgen")
  """
  name=${common.baseName}
  regenie \
    --step 1 \
    --loocv \
    --phenoFile ${pheno_chunk} \
    --bsize ${params.Bsize} \
    --gz \
    --pgen \$name \
    --out fit_bin_${pheno_chunk_no} \
    --split-l0 fit_bin${pheno_chunk_no},${params.njobs} \
    --threads ${params.Threads_S_10} \
    --force-step1 ${params.options_s1}
  """
  else
  """
    regenie \
    --step 1 \
    --loocv \
    --phenoFile ${pheno_chunk} \
    --bsize ${params.Bsize} \
    --gz \
    --bgen ${common} \
    --sample ${sample_file} \
    --out fit_bin_${pheno_chunk_no} \
    --split-l0 fit_bin${pheno_chunk_no},${params.njobs} \
    --threads ${params.Threads_S_10} \
    --force-step1 ${params.options_s1}

  """
}




process step_1_l1 {
  label "STEP_1_1"
  cache "lenient"
  scratch false

  input:
  tuple val(pheno_chunk_no), file(pheno_chunk), file(master), file(snplist) from step1_l0_split
tuple file(common), file(sample_file), file(pvar) from Channel.fromPath(params.CommonVar_file[-4..-1]=="pgen" ? [params.CommonVar_file, params.CommonVar_file.replaceAll('.pgen', '.pvar'), params.CommonVar_file.replaceAll('.pgen', '.psam')]: [params.CommonVar_file,params.CommonVar_file + ".bgi",params.CommonVar_file.replaceAll('.bgen$', '.sample')]).toSortedList()



  output:
  tuple val(pheno_chunk_no), file(pheno_chunk), file(master), file("*_l0_Y*") into step_1_l1
  file "*.log" into step1_l1_logs
 
  publishDir "${params.OutDir}/step1_l1_logs", pattern: "*.log", mode: "copy"

script :
if (params.CommonVar_file[-4..-1]=="pgen")
  """
      name=${common.baseName}
  i=${snplist.getSimpleName().split('_')[2].replaceFirst('^job', '')}
  regenie \
    --step 1 \
    --loocv \
    --phenoFile ${pheno_chunk} \
    --bsize ${params.Bsize} \
    --gz \
    --pgen \$name \
    --out fit_bin_${pheno_chunk_no}_\${i} \
    --run-l0 ${master},\${i} \
    --threads ${params.Threads_S_11} ${params.options_s1} 
  """
  else
  """
  i=${snplist.getSimpleName().split('_')[2].replaceFirst('^job', '')}
  regenie \
    --step 1 \
    --loocv \
    --phenoFile ${pheno_chunk} \
    --bsize ${params.Bsize} \
    --sample ${sample_file} \
    --gz \
    --bgen ${common} \
    --out fit_bin_${pheno_chunk_no}_\${i} \
    --run-l0 ${master},\${i} \
    --threads ${params.Threads_S_11} ${params.options_s1} 

  """
}




process step_1_l2 {
  label "STEP_1_2"
  cache "lenient"
  scratch false

  input:
  tuple val(pheno_chunk_no), file(pheno_chunk), file(master), file(predictions) from step_1_l1.groupTuple(by: 0).map{ t -> [t[0], t[1][0], t[2][0], t[3].flatten()] }
tuple file(common), file(sample_file), file(pvar) from Channel.fromPath(params.CommonVar_file[-4..-1]=="pgen" ? [params.CommonVar_file, params.CommonVar_file.replaceAll('.pgen', '.pvar'), params.CommonVar_file.replaceAll('.pgen', '.psam')]: [params.CommonVar_file,params.CommonVar_file + ".bgi",params.CommonVar_file.replaceAll('.bgen$', '.sample')]).toSortedList()

  


  output:       
  tuple val(pheno_chunk_no), file(pheno_chunk), file("fit_bin${pheno_chunk_no}_loco_pred.list"), file("*.loco.gz") into step1_l2
  file "*.log" into step1_l2_logs

  publishDir "${params.OutDir}/step1_l2_logs", pattern: "*.log", mode: "copy"
  
script :
if (params.CommonVar_file[-4..-1]=="pgen")
  """
    name=${common.baseName}
  regenie \
    --step 1 \
    --phenoFile ${pheno_chunk} \
    --bsize ${params.Bsize} \
    --gz \
    --pgen \$name \
    --out fit_bin${pheno_chunk_no}_loco \
    --run-l1 ${master} \
    --keep-l0 \
    --threads ${params.Threads_S_12} \
    --use-relative-path \
    --force-step1 ${params.options_s1}
    """
else
    """
    regenie \
    --step 1 \
    --phenoFile ${pheno_chunk} \
    --bsize ${params.Bsize} \
    --sample ${sample_file} \
    --gz \
    --bgen ${common} \
    --out fit_bin${pheno_chunk_no}_loco \
    --run-l1 ${master} \
    --keep-l0 \
    --threads ${params.Threads_S_12} \
    --use-relative-path \
    --force-step1 ${params.options_s1}

  """
  }


      
// _________________________________________STEP2_________________________________________

// ________________STEP 2 SPLIT ___________________________

process step_2_split {
  label "STEP_2_spit"
  cache "lenient"
  scratch false 
  executor "local"
  

  input:
  
tuple file(common), file(sample_file), file(pvar) from Channel.fromPath(params.test_variants_file[-4..-1]=="pgen" ? [params.test_variants_file, params.test_variants_file.replaceAll('.pgen', '.pvar'), params.test_variants_file.replaceAll('.pgen', '.psam')]:[params.test_variants_file, params.test_variants_file+ ".bgi", params.test_variants_file.replaceAll('.bgen$', '.sample')]).toSortedList().flatten().collate(3)



  output:
 tuple file("*.subsetted_*.bgen"), file("*.subsetted_*.bgen.bgi"), file("*.subsetted_*.sample") into split mode flatten

script :
if (params.test_variants_file[-4..-1]=="pgen")
  """
grep -v "^#" ${common.baseName}.pvar | cut -f 3 > SNP_temp.txt
nb_snp=\$(cat SNP_temp.txt | wc -l )
val=\$((\$nb_snp/${params.SnpStep}))
if [[ \$val > 1 ]]; then
split --numeric-suffixes -l  ${params.SnpStep} SNP_temp.txt split
for i in split*
do
plink2 --pfile ${common.baseName} --extract \$i --make-pgen --out ${common.baseName}.subsetted_\$i
done
else
cp ${common} ${common.baseName}.subsetted_00.pgen ; cp ${common.baseName}.pvar ${common.baseName}.subsetted_00.pvar ; cp ${common.baseName}.psam ${common.baseName}.subsetted_00.psam
fi
  """
else
  """
bgenix -list -g ${common} |cut -f 1 | sed '/^#/d' | sed '1d' > SNP_temp.txt
nb_snp=\$(cat SNP_temp.txt | wc -l )
val=\$((\$nb_snp/${params.SnpStep}))
if [[ \$val > 1 ]]; then
    split --numeric-suffixes -l  ${params.SnpStep} SNP_temp.txt split
    for i in split*
      do
      qctool -g ${common} -og ${common.baseName}.subsetted_\$i.bgen -ofiletype "bgen" -incl-snpids \$i -os ${common.baseName}.subsetted_\$i.sample
      bgenix -index -g ${common.baseName}.subsetted_\$i.bgen
      done
else
  cp ${common} ${common.baseName}.subsetted_00.bgen ; cp ${common}.bgi ${common.baseName}.subsetted_00.bgen.bgi ; cp ${common.name}.sample ${common.baseName}.subsetted_00.sample
fi
  """
}
    
    
    
//___________________STEP 2 main ____________________________
process step_2 {
  label "STEP_2"
  cache "lenient"
  scratch false 

  input:
  tuple val(pheno_chunk_no), file(pheno_chunk), file(loco_pred_list), file(loco_pred), file(common), file(pvar), file(sample_file) from step1_l2.combine(split)

  output:       
  file("*.regenie") into summary_stats
  file "*.log" into step2_logs

  publishDir "${params.OutDir}/step2_logs", pattern: "*.log", mode: "copy"


script :
if (params.test_variants_file[-4..-1]=="pgen")
  """
  name=${common.baseName}
  regenie \
    --step 2 \
    --phenoFile ${pheno_chunk} \
    --bsize ${params.Bsize} \
    --pgen \$name \
    --out "\$name"_${pheno_chunk_no}_assoc_ \
    --pred ${loco_pred_list} \
    --threads ${params.Threads_S_2} ${params.options_s2}
  """
  else
  """
  name=${common.getName().replaceAll('.bgen$', '')}
  regenie \
    --step 2 \
    --phenoFile ${pheno_chunk} \
    --sample ${sample_file} \
    --bsize ${params.Bsize} \
    --bgen ${common} \
    --out "\$name"_${pheno_chunk_no}_assoc_ \
    --pred ${loco_pred_list} \
    --threads ${params.Threads_S_2} ${params.options_s2}
  """
}



//______________________MERGE______________________
process step_2_merge {
  label "STEP_2"
  cache "lenient"
  scratch false 



  input:
  tuple val(pheno_no), file(summary) from summary_stats.map{ t -> [t.baseName.split("assoc_")[1], t] }.groupTuple()

  output:       
  file "*.regenie.gz" into summary_stats_final


  publishDir "${params.OutDir}/step2_result", pattern: "*.regenie.gz", mode: "copy"


  """
  Q=\$(find . -name "*.regenie" | sort -V)
 cat \$Q > assoc_${pheno_no}.regenie
gzip assoc_${pheno_no}.regenie
  """
}
