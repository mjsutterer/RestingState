#!/bin/bash

##################################################################################################################
# Motion Correction and Other inital processing for Resting State Analysis
#     1. Motion Correction		
#     2. SNR Estimation
#     4. Spike Detection
#     5. Registration
#       a. T1 to MNI (flirt/fnirt), with/without lesion mask optimization
#       b. EPI to T1 (BBR), with/without FieldMap correction
##################################################################################################################
#Commenting out code I want to remove (RM)
#(RM)scriptPath=`perl -e 'use Cwd "abs_path";print abs_path(shift)' $0`
#(RM)scriptDir=`dirname $scriptPath`
spikeThreshInt=300
spikeThresh=$(echo $spikeThreshInt 100 | awk '{print ($1/$2)}')


function printCommandLine {
  echo "Usage: qualityCheck.sh -E restingStateImage -a T1Image -A T1SkullImage -l lesionMask -f -b fieldMapPrepped -v fieldMapMagSkull -x fieldMapMag -D 0.00056 -d PhaseEncDir -c"
  echo ""
  echo "   where:"
  echo "   -E Resting State file"
  echo "   -A T1 file"
  echo "   -a T1 (with skull) file"
  echo "     *Both EPI and T1 (with and without skull) should be from output of dataPrep script"
  echo "   -l Binary lesion mask"
  echo "   -f (fieldMap registration correction)"
  echo "   -b fieldMapPrepped (B0 correction image from dataPrep/fsl_prepare_fieldmap)"
  echo "   -v fieldMapMagSkull (FieldMap Magnitude image, with skull (from dataPrep))"
  echo "   -x fieldMapMag (FieldMap Magnitude image, skull-stripped (from dataPrep))"
  echo "   -D dwell time (in seconds)"
  echo "       *dwell time is from the EPI but is only set if FieldMap correction ('-f') is chosen."
  echo "       *If not set and FieldMap correction is flagged ('-f'), default is 0.00056"
  echo "   -d Phase Encoding Direction (from dataPrep)"
  echo "       *Options are x/y/z/-x/-y/-z"
  echo "   -c clobber/overwrite previous results"
  exit 1
}



# Parse Command line arguments
while getopts “hE:A:a:l:fb:v:x:D:d:c” OPTION
do
  case $OPTION in
    h)
      printCommandLine
      ;;
    E)
      epiData=$OPTARG
      ;;
    A)
      t1Data=$OPTARG
      ;;
    a)
      t1SkullData=$OPTARG
      ;;
    l)
      lesionMask=$OPTARG
      lesionMaskFlag=1
      ;;
    f)
      fieldMapFlag=1
      ;;
    b)
      fieldMap=$OPTARG
      ;;
    v)
      fieldMapMagSkull=$OPTARG
      ;;
    x)
      fieldMapMag=$OPTARG
      ;;
    D)
      dwellTime=$OPTARG
      ;;
    d)
      peDir=$OPTARG
      ;;
    c)
      clob=true
      ;;
    ?)
      echo "ERROR: Invalid option"
      printCommandLine
      ;;
     esac
done




#First check for proper input files
if [ "$epiData" == "" ]; then
  echo "Error: The restingStateImage (-E) is a required option"
  exit 1
fi

if [ "$t1Data" == "" ]; then
  echo "Error: The T1 data (-a) is a required option"
  exit 1
fi

if [ "$t1SkullData" == "" ]; then
  echo "Error: The T1 (with skull) data (-A) is a required option"
  exit 1
fi


  #A few default parameters (if input not specified, these parameters are assumed)


  if [[ $lesionMaskFlag == "" ]]; then
    lesionMaskFlag=0
  fi

  if [[ $fieldMapFlag == "" ]]; then
    fieldMapFlag=0
  fi

  if [[ $peDir == "" ]]; then
    peDir="-y"
  fi

  if [[ $dwellTime == "" ]]; then
    dwellTime=0.00056
  fi





#If FieldMap correction is chosen, check for proper input files
if [[ $fieldMapFlag == 1 ]]; then
  if [[ "$fieldMap" == "" ]]; then
    echo "Error: The prepared FieldMap from fsl_prepare_fieldmap data (-b) is a required option if you wish to use FieldMap correction (-f)"
    exit 1
  fi
  if [[ "$fieldMapMagSkull" == "" ]]; then
    echo "Error: The FieldMap, Magnitude image (with skull) data (-v) is a required option if you wish to use FieldMap correction (-f)"
    exit 1
  fi
  if [[ "$fieldMapMag" == "" ]]; then
    echo "Error: The FieldMap, Magnitude image (skull-stripped) data (-w) is a required option if you wish to use FieldMap correction (-f)"
    exit 1
  fi
fi

#echo experimental variables to log
printf "%s\n" "------------------------" | tee -a ${outDir}/log/qualityCheck.log
date >> ${outDir}/log/qualityCheck.log
printf "%s\t" "$0 $@" | tee -a ${outDir}/log/DataPrep.log
printf "%s\ " "$0 $@" | tee -a ${outDir}/log/qualityCheck.log


#Setting variable for FSL base directory
#fslDir=`echo $FSLDIR` (do we need this?)


#indir=$logDir why set a variable as a variable


echo "Running $0 ..."

#cd $indir
#if [[ $overwriteFlag == 1 ]]; then
  #rm -rf mcImg* mc*par SNR* analysisResults.html
  #rm rot.png trans.png disp.png
  #rm GM_Mean.par AntNoise_Mean.par PostNoise_Mean.par SigNoise.par NoiseAvg.par
  #rm SigNoisePlot.png NoisePlot.png
  #rm global_mean_ts.dat Normscore.par normscore.png
  #rm nonfiltered*nii.gz thr1000Img.nii.gz thr400Img  
  #rm 3dTqual.png
#else
  
#fi

#Overwrites material or skips
function clobber() 
{
#Tracking Variables
local -i num_existing_files=0
local -i num_args=$#

#Tally all existing outputs
for arg in $@; do
if [ -e "${arg}" ] && [ "${clob}" == true ]; then
rm -rf "${arg}"
elif [ -e "${arg}" ] && [ "${clob}" == false ]; then
num_existing_files=$(( ${num_existing_files} + 1 ))
continue
elif [ ! -e "${arg}" ]; then
continue
else
echo "How did you get here?"
fi
done

#see if the command should be run by seeing if the requisite files exist.
#0=true
#1=false
if [ ${num_existing_files} -lt ${num_args} ]; then
return 0
else
return 1
fi

#example usage
#clobber test.nii.gz &&\
#fslmaths input.nii.gz -mul 10 test.nii.gz
}

clob=false

#try not to cd if not necessary, it 1) gets people confused when they guess where the output is being written and 2) if the script breaks, the person will be in some strange directory
#cd $indir

    #Overwrite the data
#rm -rf mcImg* mc*par SNR* analysisResults.html
#rm rot.png trans.png disp.png
#rm GM_Mean.par AntNoise_Mean.par PostNoise_Mean.par SigNoise.par NoiseAvg.par
#rm SigNoisePlot.png NoisePlot.png
#rm global_mean_ts.dat Normscore.par normscore.png
#rm nonfiltered*nii.gz thr1000Img.nii.gz thr400Img  
#rm 3dTqual.png


########## Motion Correction ###################
  #Going to run with AFNI's 3dvolreg over FSL's mcflirt.  Output pics will have same names to be drop-in replacments

function motion_correction() 
{ 
  echo "...Applying motion correction."
  local epi=$1
  local outDir=$2

  #Determine halfway point of dataset to use as a target for registration
  local halfPoint=$(fslhd $epi | grep "^dim4" | awk '{print int($2/2)}')

  #Run 3dvolreg, save matrices and parameters
  #Saving "raw" AFNI output for possible use later (motionscrubbing?)
  clobber ${outDir}/func/mcImg.nii.gz &&\
  { 3dvolreg -verbose \
  -tshift 0 \
  -Fourier \
  -zpad 4 \
  -prefix ${outDir}/func/mcImg.nii.gz \
  -base $halfPoint \
  -dfile ${outDir}/func/mcImg.nii.gzmcImg_raw.par \
  -1Dmatrix_save ${outDir}/func/mcImg.nii.gzmcImg.mat \
  $epi ||\
  { printf "%s\n" "3dvolreg failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Create a mean volume
  clobber ${outDir}/func/mcImgMean.nii.gz &&\
  { fslmaths ${outDir}/func/mcImg.nii.gz -Tmean ${outDir}/func/mcImgMean.nii.gz ||\
  { printf "%s\n" "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Save out mcImg.par (like fsl) with only the translations and rotations
  #mcflirt appears to have a different rotation/translation order.  Reorder 3dvolreg output to match "RPI" FSL ordering
  ##AFNI ordering
  #roll  = rotation about the I-S axis }
  #pitch = rotation about the R-L axis } degrees CCW
  #yaw   = rotation about the A-P axis }
  #dS  = displacement in the Superior direction  }
  #dL  = displacement in the Left direction      } mm
  #dP  = displacement in the Posterior direction }

  awk '{print ($3 " " $4 " " $2 " " $6 " " $7 " " $5)}' ${outDir}/func/mcImg_raw.par > ${outDir}/func/mcImg_deg.par ||\
  { printf "%s\n" "creation of mcImg_deg.par failed, exiting ${FUNCNAME}" && return 1; }

  #Need to convert rotational parameters from degrees to radians
  #rotRad= (rotDeg*pi)/180
  #pi=3.14159

  awk -v pi=3.14159 '{print (($1*pi)/180) " " (($2*pi)/180) " " (($3*pi)/180) " " $4 " " $5 " " $6}' ${outDir}/func/mcImg_deg.par > ${outDir}/func/mcImg.par ||\
  { printf "%s\n" "creation of mcImg.par failed, exiting ${FUNCNAME}" && return 1; }

  #Need to create a version where ALL (rotations and translations) measurements are in mm.  Going by Power 2012 Neuroimage paper, radius of 50mm.
  #Convert degrees to mm, leave translations alone.
  #rotDeg= ((2r*Pi)/360) * Degrees = Distance (mm)
  #d=2r=2*50=100
  #pi=3.14159

  awk -v pi=3.14159 -v d=100 '{print (((d*pi)/360)*$1) " " (((d*pi)/360)*$2) " " (((d*pi)/360)*$3) " " $4 " " $5 " " $6}' ${outDir}/func/mcImg_deg.par > ${outDir}/func/mcImg_mm.par ||\
  { printf "%s\n" "creation of mcImg_mm.par failed, exiting ${FUNCNAME}" && return 1; }

  #Cut motion parameter file into 6 distinct TR parameter files
  for i in {1..6}; do
    awk -v var=${i} '{print $var}' ${outDir}/func/mcImg.par > ${outDir}/func/mc${i}.par ||\
    { printf "%s\n" "creation of mc{$1}.par failed, exiting ${FUNCNAME}" && return 1; }
  done

  ##Need to create the absolute and relative displacement RMS measurement files
  #From the FSL mailing list (https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=FSL;2ce58db1.1202):
  #rms = sqrt(0.2*R^2*((cos(theta_x)-1)^2+(sin(theta_x))^2 + (cos(theta_y)-1)^2 + (sin(theta_y))^2 + (cos(theta_z)-1)^2 + (sin(theta_z)^2)) + transx^2+transy^2+transz^2)
  #where R=radius of spherical ROI = 80mm used in rmsdiff; theta_x, theta_y, theta_z are the three rotation angles from the .par file; and transx, transy, transz are the three translations from the .par file.

  #Absolute Displacement
  awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' ${outDir}/func/mcImg.par > ${outDir}/func/mcImg_abs.rms ||\
  { printf "%s\n" "creation of mcImg_abs.rms failed, exiting ${FUNCNAME}" && return 1; }

  #Relative Displacement
  #Create the relative displacement .par file from the input using AFNI's 1d_tool.py to first calculate the derivatives
  1d_tool.py -infile ${outDir}/func/mcImg.par -set_nruns 1 -derivative -write ${outDir}/func/mcImg_deriv.par ||\
  { printf "%s\n" "creation of mcImg_deriv.par failed, exiting ${FUNCNAME}" && return 1; }

  awk '{print (sqrt(0.2*80^2*((cos($1)-1)^2+(sin($1))^2 + (cos($2)-1)^2 + (sin($2))^2 + (cos($3)-1)^2 + (sin($3)^2)) + $4^2+$5^2+$6^2))}' ${outDir}/func/mcImg_deriv.par > ${outDir}/func/mcImg_rel.rms ||\
  { printf "%s\n" "creation of mcImg_rel.rms failed, exiting ${FUNCNAME}" && return 1; }


  #Create images of the motion correction (translation, rotations, displacement), mm and radians
    #switched from "MCFLIRT estimated...." title
  fsl_tsplot -i ${outDir}/func/mcImg.par -t '3dvolreg estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 800 -h 300 -o ${outDir}/func/rot.png ||\
  { printf "%s\n" "creation of rot.png failed, exiting ${FUNCNAME}" && return 1; }
  fsl_tsplot -i ${outDir}/func/mcImg.par -t '3dvolreg estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 800 -h 300 -o ${outDir}/func/trans.png ||\
  { printf "%s\n" "creation of trans.png failed, exiting ${FUNCNAME}" && return 1; }
  fsl_tsplot -i ${outDir}/func/mcImg_mm.par -t '3dvolreg estimated rotations (mm)' -u 1 --start=1 --finish=3 -a x,y,z -w 800 -h 300 -o ${outDir}/func/rot_mm.png ||\
  { printf "%s\n" "creation of rot_mm.png failed, exiting ${FUNCNAME}" && return 1; }
  fsl_tsplot -i ${outDir}/func/mcImg_mm.par -t '3dvolreg estimated rotations and translations (mm)' -u 1 --start=1 --finish=6 -a "x(rot),y(rot),z(rot),x(trans),y(trans),z(trans)" -w 800 -h 300 -o ${outDir}/func/rot_trans.png ||\
  { printf "%s\n" "creation of rot_trans.png failed, exiting ${FUNCNAME}" && return 1; }
  fsl_tsplot -i ${outDir}/func/mcImg_abs.rms,mcImg_rel.rms -t '3dvolreg estimated mean displacement (mm)' -u 1 -w 800 -h 300 -a absolute,relative -o ${outDir}/func/disp.png ||\
  { printf "%s\n" "creation of dip.png failed, exiting ${FUNCNAME}" && return 1; }

  printf "%s\n" "${FUNCNAME} completed successfully" && return 0
}


#putting a sticky note here until I figure out where this code flows the best
########## In vs. Out of Brain SNR Calculation #
echo "...SNR mask creation."

#Calculate a few dimensions
xdim=$(fslhd mcImg.nii.gz | grep ^dim1 | awk '{print $2}')
ydim=$(fslhd mcImg.nii.gz | grep ^dim2 | awk '{print $2}')
zdim=$(fslhd mcImg.nii.gz | grep ^dim3 | awk '{print $2}')
tdim=$(fslhd mcImg.nii.gz | grep ^dim4 | awk '{print $2}')
xydimTenth=$(echo $xdim 0.06 | awk '{print int($1*$2)}')
ydimMaskAnt=$(echo $ydim 0.93 | awk '{print int($1*$2)}')
ydimMaskPost=$(echo $ydim 0.07 | awk '{print int($1*$2)}')

################################################################



########## T1 to MNI registration ##############
function lesionMaskPrep()
{
  local lesionMask=$1
  local outDir=$2

  printf "%s\n" "...Prepping the Lesion Mask"

  mkdir -p ${outDir}/func/T1forWarp ||\
  { printf "%s\n" "creation of directory T1forWarp failed, exiting ${FUNCNAME}" && return 1; }

  #Create a temporaray binary lesion mask (in case it's not char, binary format)
  clobber ${outDir}/func/T1forWarp/T1_lesionmask.nii.gz &&\
  { fslmaths ${T1_mask} -bin ${outDir}/func/T1forWarp/T1_lesionmask.nii.gz -odt char ||\
  { printf "%s\n" "creation of ${outDir}/func/T1forWarp/T1_mask.nii.gz failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Orient lesion mask to RPI
  clobber ${outDir}/func/T1forWarp/T1_lesionmask_RPI.nii.gz &&\
  { RPI_Orient ${outDir}/func/T1forWarp/T1_lesionmask.nii.gz ||\
  { printf "%s\n" "creation of ${outDir}/func/T1forWarp/T1_lesionmask_RPI.nii.gz failed, exiting ${FUNCNAME}" && return 1 ;} ;}


  #Invert the lesion mask
  clobber ${outDir}/func/T1forWarp/LesionWeight.nii.gz &&\
  { fslmaths  -mul -1 -add 1 -thr 0.5 -bin ${outDir}/func/T1forWarp/LesionWeight.nii.gz ||\
  { printf "%s\n" "creation of ${outDir}/func/T1forWarp/LesionWeight.nii.gz failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} completed successfully"

}

function T1ToStd()
{ 
  local T1_brain=$1
  local T1_head=$2
  local T1_mask=$3
  local outDir=$4
  local lesion=$5


  printf "%s\n" "...Optimizing T1 (highres) to MNI (standard) registration."
  local maskname="T1"
  if [ ${lesion} -eq 1 ]; then
    lesionMaskprep ${T1_mask} ${outDir}
    local flirt_transform_option="-inweight ${outDir}/func/T1forWarp/LesionWeight.nii.gz"
    local fnirt_transform_option="--inmask=$t1WarpDir/LesionWeight.nii.gz"
    local maskname="lesion"
  fi

   mkdir -p ${outDir}/func/T1forWarp ||\
  { printf "%s\n" "creation of directory T1forWarp failed, exiting ${FUNCNAME}" && return 1; }

  #T1 to MNI, affine (skull-stripped data)
  clobber ${outDir}/func/T1forWarp/T1_to_MNIaff.nii.gz ${outDir}/func/T1forWarp/T1_to_MNIaff.mat &&\
  { flirt -in $t1Data \
  -ref $fslDir/data/standard/MNI152_T1_2mm_brain.nii.gz \
  -out ${outDir}/func/T1forWarp/T1_to_MNIaff.nii.gz \
  -omat ${outDir}/func/T1forWarp/T1_to_MNIaff.mat ${flirt_transform_option} ||\
  { printf "%s\n" "flirt failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #T1 to MNI, nonlinear (T1 with skull)
  clobber ${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz ${outDir}/func/T1forWarp/T1_to_MNI152.nii.gz ${outDir}/func/T1forWarp/jac_T1_to_MNI152.nii.gz &&\
  { fnirt --in=${T1_head} \
  --aff=${outDir}/func/T1forWarp/T1_to_MNIaff.mat \
  --config=T1_2_MNI152_2mm.cnf \
  --cout=${outDir}/func/T1forWarp/coef_T1_to_MNI152 \
  --iout=${outDir}/func/T1forWarp/T1_to_MNI152.nii.gz \
  --jout=${outDir}/func/T1forWarp/jac_T1_to_MNI152 \
  --jacrange=0.1,10 ${fnirt_transform_option} ||\
  { printf "%s\n" "fnirt failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply the warp to the skull-stripped T1
  clobber ${outDir}/func/T1forWarp/T1_brain_to_MNI152.nii.gz &&\
  { applywarp \
  --ref=$fslDir/data/standard/MNI152_T1_2mm_brain.nii.gz \
  --in=$T1_brain \
  --out=${outDir}/func/T1forWarp/T1_brain_to_MNI152.nii.gz \
  --warp=${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply the warp to the lesion mask or to the T1 mask
  clobber ${outDir}/func/T1forWarp/${maskname}MasktoMNI.nii.gz &&\
  { applywarp \
  --ref=$fslDir/data/standard/MNI152_T1_2mm_brain.nii.gz \
  --in=$T1_mask \
  --out=${outDir}/func/T1forWarp/${maskname}MasktoMNI.nii.gz \
  --warp=${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz \
  --interp=nn ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the warp (to get MNItoT1)
  clobber ${outDir}/func/T1forWarp/MNItoT1_warp.nii.gz &&\
  { invwarp \
  -w ${outDir}/func/T1forWarp/coef_T1_to_MNI152.nii.gz \
  -r $T1_brain \
  -o ${outDir}/func/T1forWarp/MNItoT1_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n" "${FUNCNAME} completed successfully"
}


################################################################

function EPItoT1Master()
{ 
  #basic args (without fieldmap)
  local epi=$1
  local T1_brain=$2
  local T1_head=$3
  local T1_mask=$4
  local outDir=$5
  #additional arguments for fieldmap processing
  local fieldmap=$6
  local fieldmapMagHead=$7
  local fieldmapMagBrain=$8
  local dwellTime=$9
  local peDir=$10
  #number of arguments to decide which processing stream.
  local num_args=$#


  printf "%s\n" "...Optimizing EPI (func) to T1 (highres) registration."
  mkdir -p ${outDir}/func/EPItoT1 ||\
  { printf "%s\n" "creation of ${outDir}/func/EPItoT1 failed, exiting ${FUNCNAME}" && return 1; }

  case ${num_args} in
    5)
      clobber something &&\
      { EPItoT1FieldMap ${epi} ${T1_brain} ${outDir}/func/EPItoT1 ||\
      { printf "%s\n"  "Generic Error Statement" && return 1 ;} ;}
      ;;
    10)
      clobber something &&\
      { EPItoT1 ${epi} ${outDir}/func/EPItoT1 ||\
      { printf "%s\n" "Generic Error Statement"&& return 1 ;} ;}
      ;;
    *)
      printf "%s\n" "Error, the number of arguments does not match the number required for normal or fieldmap EPItoT1 processing" &&\
      return 1
      ;;
  esac 

  printf "%s\n" "${FUNCNAME} completed successfully" && return 0
}

function EPItoT1FieldMap()
{
  #basic args (without fieldmap)
  local epi=$1
  local epiDir=$(basename ${epi})
  local T1_brain=$2
  local T1_head=$3
  local T1_mask=$4
  local EPItoT1outDir=$5
  #additional arguments for fieldmap processing
  local fieldmap=$6
  local fieldmapMagHead=$7
  local fieldmapMagBrain=$8
  local dwellTime=$9
  local peDir=$10

  printf "%s\n" "......Registration With FieldMap Correction."

  #Warp using FieldMap correction
  #Output will be a (warp) .nii.gz file
  #epi_reg --epi=${indir}/mcImgMean.nii.gz --t1=${t1SkullData} --t1brain=${t1Data} --wmseg=$epiWarpDir/T1_MNI_brain_wmseg.nii.gz --out=$epiWarpDir/EPItoT1 --fmap=${fieldMap} --fmapmag=${fieldMapMagSkull} --fmapmagbrain=${fieldMapMag} --echospacing=${dwellTime} --pedir=${peDir}

  clobber ${outDir}/func/EPItoT1/EPItoT1_warp.nii.gz &&\
  { epi_reg --epi=${epi} \
  --t1=${T1_head} \
  --t1brain=${T1_brain} \
  --out=${EPItoT1outDir} \
  --fmap=${fieldMap} \
  --fmapmag=${fieldMapMagHead} \
  --fmapmagbrain=${fieldMapMagBrain} \
  --echospacing=${dwellTime} \
  --pedir=${peDir} --noclean ||\
  { printf "%s\n" "epi_reg failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the affine registration (to get T1toEPI)
  clobber ${EPItoT1outDir}/T1toEPI.mat &&\
  { convert_xfm -omat ${EPItoT1outDir}/T1toEPI.mat -inverse ${EPItoT1outDir}/EPItoT1.mat ||\
  { printf "%s\n" "convert_xfm failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the nonlinear warp (to get T1toEPI)
  clobber ${EPItoT1outDir}/T1toEPI_warp.nii.gz &&\
  { invwarp -w ${EPItoT1outDir}/EPItoT1_warp.nii.gz -r ${epi} -o ${EPItoT1outDir}/T1toEPI_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply the inverted (T1toEPI) warp to the brain mask
  clobber ${epiDir}/mcImgMean_mask.nii.gz &&\
  { applywarp --ref=${epiDir}/mcImgMean.nii.gz --in=${T1mask} --out=${epiDir}/mcImgMean_mask.nii.gz --warp=${EPItoT1outDir}/T1toEPI_warp.nii.gz --datatype=char --interp=nn ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

   #Create a stripped version of the EPI (mcImg) file, apply the warp
  clobber ${epiDir}/mcImgMean_stripped.nii.gz &&\
  { fslmaths ${epiDir}/mcImgMean.nii.gz -mas ${epiDir}/mcImgMean_mask.nii.gz ${epiDir}/mcImgMean_stripped.nii.gz ||\
  { printf "%s\n" "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  clobber ${EPItoT1outDir}/EPIstrippedtoT1.nii.gz &&\
  { applywarp --ref=${T1_brain} --in=${epiDir}/mcImgMean_stripped.nii.gz --out=${EPItoT1outDir}/EPIstrippedtoT1.nii.gz --warp=${EPItoT1outDir}/EPItoT1_warp.nii.gz ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Sum the nonlinear warp (MNItoT1_warp.nii.gz) with the second nonlinear warp (T1toEPI_warp.nii.gz) to get a warp from MNI to EPI
  clobber ${EPItoT1outDir}/MNItoEPI_warp.nii.gz &&\
  { convertwarp \
  --ref=${epiDir}/mcImgMean.nii.gz \
  --warp1=${outDir}/func/T1forWarp/MNItoT1_warp.nii.gz \
  --warp2=${EPItoT1outDir}/T1toEPI_warp.nii.gz \
  --out=${epiWarpDir}/MNItoEPI_warp.nii.gz --relout ||\
  { printf "%s\n" "convertwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the warp to get EPItoMNI_warp.nii.gz
  clobber ${epiWarpDir}/EPItoMNI_warp.nii.gz &&\
  { invwarp -w ${epiWarpDir}/MNItoEPI_warp.nii.gz -r $fslDir/data/standard/MNI152_T1_2mm.nii.gz -o ${epiWarpDir}/EPItoMNI_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply EPItoMNI warp to EPI file
  clobber $epiWarpDir/EPItoMNI.nii.gz &&\
  { applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm.nii.gz --in=${indir}/mcImgMean_stripped.nii.gz --out=$epiWarpDir/EPItoMNI.nii.gz --warp=${epiWarpDir}/EPItoMNI_warp.nii.gz ||\
  { printf "%s\n" "applywarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  printf "%s\n ${FUNCNAME} successful" && return 0
}

function EPItoT1()
{
  #local variables here
  #
  #
  #
  printf "%s\n" "......Registration Without FieldMap Correction." 
  #Warp without FieldMap correction
  #Ouput will be a .mat file
  #epi_reg --epi=${indir}/mcImgMean.nii.gz --t1=${t1SkullData} --t1brain=${t1Data} --wmseg=$epiWarpDir/T1_MNI_brain_wmseg.nii.gz --out=$epiWarpDir/EPItoT1
  clobber $epiWarpDir/EPItoT1 &&\
  { epi_reg --epi=${indir}/mcImgMean.nii.gz --t1=${t1SkullData} --t1brain=${t1Data} --out=$epiWarpDir/EPItoT1 --noclean ||\
  { printf "%s\n" "epi_reg failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the affine registration (to get T1toEPI)
  clobber $epiWarpDir/T1toEPI.mat &&\
  { convert_xfm -omat $epiWarpDir/T1toEPI.mat -inverse $epiWarpDir/EPItoT1.mat ||\
  { printf "%s\n" "convert_xfm failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply the inverted (T1toEPI) mat file to the brain mask
  clobber ${indir}/mcImgMean_mask.nii.gz &&\
  { flirt -in $T1mask -ref ${indir}/mcImgMean.nii.gz -applyxfm -init $epiWarpDir/T1toEPI.mat -out ${indir}/mcImgMean_mask.nii.gz -interp nearestneighbour -datatype char ||\
  { printf "%s\n" "flirt failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Create a stripped version of the EPI (mcImg) file, apply the mat file
  clobber ${indir}/mcImgMean_stripped.nii.gz &&\
  { fslmaths ${indir}/mcImgMean.nii.gz -mas ${indir}/mcImgMean_mask.nii.gz ${indir}/mcImgMean_stripped.nii.gz ||\
  { printf "%s\n" "fslmaths failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  clobber $epiWarpDir/EPIstrippedtoT1.nii.gz &&\
  { flirt -in ${indir}/mcImgMean_stripped.nii.gz -ref ${t1Data} -applyxfm -init $epiWarpDir/EPItoT1.mat -out $epiWarpDir/EPIstrippedtoT1.nii.gz ||\
  { printf "%s\n" "flirt failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Sum the nonlinear warp (MNItoT1_warp.nii.gz) with the affine transform (T1toEPI.mat) to get a warp from MNI to EPI
  clobber ${epiWarpDir}/MNItoEPI_warp.nii.gz &&\
  { convertwarp --ref=${indir}/mcImgMean.nii.gz --warp1=${t1WarpDir}/MNItoT1_warp.nii.gz --postmat=${epiWarpDir}/T1toEPI.mat --out=${epiWarpDir}/MNItoEPI_warp.nii.gz --relout ||\
  { printf "%s\n" "convertwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Invert the warp to get EPItoMNI_warp.nii.gz
  clobber ${epiWarpDir}/EPItoMNI_warp.nii.gz &&\
  { invwarp -w ${epiWarpDir}/MNItoEPI_warp.nii.gz -r $fslDir/data/standard/MNI152_T1_2mm.nii.gz -o ${epiWarpDir}/EPItoMNI_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

  #Apply EPItoMNI warp to EPI file
  clobber $epiWarpDir/EPItoMNI.nii.gz &&\
  applywarp --ref=$fslDir/data/standard/MNI152_T1_2mm.nii.gz --in=${indir}/mcImgMean_stripped.nii.gz --out=$epiWarpDir/EPItoMNI.nii.gz --warp=${epiWarpDir}/EPItoMNI_warp.nii.gz ||\
  { printf "%s\n" "invwarp failed, exiting ${FUNCNAME}" && return 1 ;} ;}

}


#Do we need to run fast if epi_reg runs fast?
########## Tissue class segmentation ###########
echo "...Creating Tissue class segmentations."

t1Dir=`dirname $t1Data`
segDir=$t1Dir/tissueSeg

if [[ ! -e $segDir ]]; then
  mkdir $segDir
fi

#Tissue segment the skull-stripped T1
echo "......Starting FAST segmentation"
clobber $t1Dir/T1_MNI_brain_wmseg.nii.gz &&\
fast -t 1 -n 3 -g -o $segDir/T1 $t1Data &&\
cp $segDir/T1_seg_2.nii.gz $t1Dir/T1_MNI_brain_wmseg.nii.gz 


########## Skullstrip the EPI data ######################

#ENTER FUNCTION FOR SKULLSTRIPPING
#skull-strip mcImgMean volume, write output to rsParams file
fslmaths mcImg.nii.gz -mas $mcMask mcImg_stripped.nii.gz

#Leftover section from dataPrep (to create "RestingState.nii.gz")
fslmaths RestingStateRaw.nii.gz -mas $mcMask RestingState.nii.gz




########## SNR Estimation ######################
function Estimate_SNR()
{
  #putting a sticky note here until I figure out where this code flows the best
########## In vs. Out of Brain SNR Calculation #
echo "...SNR mask creation."

#Calculate a few dimensions
xdim=$(fslhd mcImg.nii.gz | grep ^dim1 | awk '{print $2}')
ydim=$(fslhd mcImg.nii.gz | grep ^dim2 | awk '{print $2}')
zdim=$(fslhd mcImg.nii.gz | grep ^dim3 | awk '{print $2}')
tdim=$(fslhd mcImg.nii.gz | grep ^dim4 | awk '{print $2}')
xydimTenth=$(echo $xdim 0.06 | awk '{print int($1*$2)}')
ydimMaskAnt=$(echo $ydim 0.93 | awk '{print int($1*$2)}')
ydimMaskPost=$(echo $ydim 0.07 | awk '{print int($1*$2)}')

echo "...Estimating SNR."

#Create a folder to dump temp data into
if [ ! -e SNR ]; then
  mkdir SNR
fi

snrDir=${indir}/SNR


#Create a GM segmentation mask (copy data from FAST processing)
fslmaths $segDir/T1_seg_1.nii.gz -bin $snrDir/T1_GM.nii.gz -odt char


echo "...Warping GM/WM/CSF mask to EPI space"
  #Warp GM, WM and CSF to EPI space
##WM/CSF will be used in MELODIC s/n determination


#Check for FieldMap correction.  If used, will have to applywarp, othewise use flirt with the .mat file
if [[ $fieldMapFlag == 1 ]]; then
  #Apply the warp file  
  applywarp -i $snrDir/T1_GM.nii.gz -o $snrDir/RestingState_GM.nii.gz -r ${indir}/mcImgMean.nii.gz -w ${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn --datatype=char

  #Transfer over GM/WM/CSF from original segmentation, without binarizing/conversion to 8bit
  applywarp -i $segDir/T1_seg_0.nii.gz -o $snrDir/CSF_to_RS.nii.gz -r ${indir}/mcImgMean.nii.gz -w ${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn
  applywarp -i $segDir/T1_seg_1.nii.gz -o $snrDir/GM_to_RS.nii.gz -r ${indir}/mcImgMean.nii.gz -w ${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn
  applywarp -i $segDir/T1_seg_2.nii.gz -o $snrDir/WM_to_RS.nii.gz -r ${indir}/mcImgMean.nii.gz -w ${epiWarpDir}/T1toEPI_warp.nii.gz --interp=nn

  #Echo out location of GM/WM/CSF (EPI) to rsParams file
  echo "epiCSF=${snrDir}/CSF_to_RS.nii.gz" >> $indir/rsParams
  echo "epiGM=${snrDir}/GM_to_RS.nii.gz" >> $indir/rsParams
  echo "epiWM=${snrDir}/WM_to_RS.nii.gz" >> $indir/rsParams

else
  #Apply the affine .mat file
  flirt -in $snrDir/T1_GM.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/RestingState_GM.nii.gz -interp nearestneighbour -datatype char

  #Transfer over GM/WM/CSF from original segmentation, without binarizing/conversion to 8bit
  flirt -in $segDir/T1_seg_0.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/CSF_to_RS.nii.gz -interp nearestneighbour
  flirt -in $segDir/T1_seg_1.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/GM_to_RS.nii.gz -interp nearestneighbour
  flirt -in $segDir/T1_seg_2.nii.gz -ref ${indir}/mcImgMean.nii.gz -applyxfm -init ${epiWarpDir}/T1toEPI.mat -out $snrDir/WM_to_RS.nii.gz -interp nearestneighbour

  #Echo out location of GM/WM/CSF (EPI) to rsParams file
  echo "epiCSF=${snrDir}/CSF_to_RS.nii.gz" >> $indir/rsParams
  echo "epiGM=${snrDir}/GM_to_RS.nii.gz" >> $indir/rsParams
  echo "epiWM=${snrDir}/WM_to_RS.nii.gz" >> $indir/rsParams
fi


#smooth output to get rid of pixellation
3dmerge -doall -prefix RestingState_GMsmooth.nii.gz -session $snrDir -1blur_fwhm 5 $snrDir/RestingState_GM.nii.gz -overwrite
fslmaths $snrDir/RestingState_GMsmooth.nii.gz -add $snrDir/RestingState_GM.nii.gz -bin $snrDir/RestingState_GMfinal.nii.gz -odt char

#Strip out GM from EPI
fslmaths mcImg.nii.gz -mul $snrDir/RestingState_GMfinal.nii.gz $snrDir/RestingState_GM4d.nii.gz


echo "...Calculating SNR measurements per TR."
#Split 4D into separate files (for calculating mean of each TR)
if [ ! -e $snrDir/GMtsplit ]; then
  mkdir -p $snrDir/GMtsplit
fi
fslsplit $snrDir/RestingState_GM4d.nii.gz $snrDir/GMtsplit/RestingState_GM -t

#Calculate Mean value of signal per TR
for data in `ls -1tv $snrDir/GMtsplit/RestingState_GM*gz`
do
  fslstats $data -M  >> GM_Mean.par
done

#Create ROIs for calculating anterior and posterior noise (on Raw EPI) - based on 6% of xydimensions
$scriptDir/makeROI_Noise.sh $ydimMaskAnt $xydimTenth mcImgMean.nii.gz $snrDir/NoiseAntMask
$scriptDir/makeROI_Noise.sh $ydimMaskPost $xydimTenth mcImgMean.nii.gz $snrDir/NoisePostMask

#Strip out Anterior/Posterior Noise from EPI
fslmaths mcImg.nii.gz -mul $snrDir/NoiseAntMask.nii.gz $snrDir/RestingState_NoiseAntMask.nii.gz
fslmaths mcImg.nii.gz -mul $snrDir/NoisePostMask.nii.gz $snrDir/RestingState_NoisePostMask.nii.gz

#Split 4D (Anterior/Posterior Noise) into separate files (for calculating mean of each TR)
if [ ! -e $snrDir/Noisetsplit ]; then
  mkdir -p $snrDir/Noisetsplit
fi

tsplitDir=$snrDir/Noisetsplit

fslsplit $snrDir/RestingState_NoiseAntMask.nii.gz $tsplitDir/RestingState_AntNoise -t
fslsplit $snrDir/RestingState_NoisePostMask.nii.gz $tsplitDir/RestingState_PostNoise -t

#Calculate Mean value of Noise (Anterior and Posterior) per TR
for data in `ls -1tv $tsplitDir/RestingState_AntNoise*gz`
do
  fslstats $data -M  >> AntNoise_Mean.par
done

for data in `ls -1tv $tsplitDir/RestingState_PostNoise*gz`
do
  fslstats $data -M  >> PostNoise_Mean.par
done

#Calculate Noise (signal mean), signal to noise for each TR
i="1"
while [ $i -lt $tdim ]
do
  AntNoise=`cat AntNoise_Mean.par | head -$i | tail -1`
  #Controlling for 0.0000 to be read as 0 (to avoid division by zero awk errors)
  AntNoisebin=`echo $AntNoise | awk '{print int($1)}'`
  PostNoise=`cat PostNoise_Mean.par | head -$i | tail -1`
  #Controlling for 0.0000 to be read as 0 (to avoid division by zero awk errors)
  PostNoisebin=`echo $PostNoise | awk '{print int($1)}'`
  echo "antnoise${i} = $AntNoise" >> testNoise.txt
  echo "postnoise${i} = $PostNoise" >> testNoise.txt
  NoiseAvg=`echo $AntNoise $PostNoise | awk '{print (($1+$2)/2)}'`
  NoiseAvgbin=`echo $NoiseAvg | awk '{print int($1)}'`
  echo "noiseavg${i} = $NoiseAvg" >> testNoise.txt
  GMMean=`cat GM_Mean.par | head -$i | tail -1`
  echo "gmmean${i} = $GMMean" >> testNoise.txt

  #Avoid division by zero awk errors
  if [ $AntNoisebin == 0 ]; then
AntSigNoise=0
  else
AntSigNoise=`echo $GMMean $AntNoise | awk '{print $1/$2}'`
  fi
  echo "antsignoise${i} = $AntSigNoise" >> testNoise.txt

  #Avoid division by zero awk errors
  if [ $PostNoisebin == 0 ]; then
PostSigNoise=0
  else
PostSigNoise=`echo $GMMean $PostNoise | awk '{print $1/$2}'`
  fi
  echo "postsignoise${i} = $PostSigNoise" >> testNoise.txt

  #Avoid division by zero awk errors
  if [ $NoiseAvgbin == 0 ]; then
SigNoiseAvg=0
  else
SigNoiseAvg=`echo $GMMean $NoiseAvg | awk '{print $1/$2}'`
  fi
  echo "$AntSigNoise $PostSigNoise $SigNoiseAvg" >> SigNoise.par
  echo "$NoiseAvg" >> NoiseAvg.par

i=$[$i+1]
done
################################################################



########## Plot out Ant/Post Noise, Global SNR #

fsl_tsplot -i SigNoise.par -o SigNoisePlot.png -t 'Signal to Noise Ratio per TR' -a Anterior,Posterior,Average -u 1 --start=1 --finish=3 -w 800 -h 300
fsl_tsplot -i AntNoise_Mean.par,PostNoise_Mean.par,NoiseAvg.par -o NoisePlot.png -t 'Noise (Mean Intensity) per TR' -a Anterior,Posterior,Average -u 1 -w 800 -h 300

################################################################



########## Temporal filtering (legacy option) ##
  #NOT suggested to run until just before nuisance regression
  #To maintain consistency with previous naming, motion-corrected image is just renamed
#Updating to call file "nonfiltered" to avoid any confusion down the road
cp $indir/mcImg.nii.gz $indir/nonfilteredImg.nii.gz

################################################################



########## Global SNR Estimation ###############
echo "...Calculating signal to noise measurements"

fslmaths $indir/nonfilteredImg -Tmean $indir/nonfilteredMeanImg
fslmaths $indir/nonfilteredImg -Tstd $indir/nonfilteredStdImg 
fslmaths $indir/nonfilteredMeanImg -div $indir/nonfilteredStdImg $indir/nonfilteredSNRImg
fslmaths $indir/nonfilteredSNRImg -mas $indir/mcImgMean_mask $indir/nonfilteredSNRImg
SNRout=`fslstats $indir/nonfilteredSNRImg -M`

#Get information for timecourse 
echo "$indir rest $SNRout" >> ${indir}/SNRcalc.txt

################################################################



########## Spike Detection #####################
echo "...Detecting time series spikes"

  if [ -e ${indir}/SPIKES.txt ]; then
rm ${indir}/SPIKES.txt
  fi

  if [ -e ${indir}/evspikes.txt ]; then
rm ${indir}/evspikes.txt
  fi

  if [ -e ${indir}/tmp ]; then
rm -rf ${indir}/tmp
  fi

####  CALCULATE SPIKES BASED ON NORMALIZED TIMECOURSE OF GLOBAL MEAN ####
fslstats -t nonfilteredImg.nii.gz -M >> ${indir}/global_mean_ts.dat
ImgMean=`fslstats $indir/nonfilteredImg.nii.gz -M`
echo "Image mean is $ImgMean"
meanvolsd=`$scriptDir/sd.sh ${indir}/global_mean_ts.dat`
echo "Image standard deviation is $meanvolsd"

vols=`cat ${indir}/global_mean_ts.dat`

for vol in $vols
do
  Diffval=`echo "scale=6; ${vol}-${ImgMean}" | bc`
  Normscore=`echo "scale=6; ${Diffval}/${meanvolsd}" | bc`
  echo "$Normscore" >>  ${indir}/Normscore.par

  echo $Normscore | awk '{if ($1 < 0) $1 = -$1; if ($1 > 3) print 1; else print 0}' >> ${indir}/evspikes.txt
done

fsl_tsplot -i Normscore.par -t 'Normalized global mean timecourse' -u 1 --start=1 -a normedts -w 800 -h 300 -o normscore.png

################################################################




########## AFNI QC tool ########################
  #AFNI graphing tool is fugly.  Replacing with FSL

3dTqual -range -automask nonfilteredImg.nii.gz >> tmpPlot
fsl_tsplot -i tmpPlot -t '3dTqual Results (Difference From Norm)' -u 1 --start=1 -a quality_index -w 800 -h 300 -o 3dTqual.png
rm tmpPlot

################################################################



########## Spike Report ########################

spikeCount=`cat ${indir}/evspikes.txt | awk '/1/{n++}; END {print n+0}'`

cd ${indir}

################################################################



########## Report Output to HTML File ##########

echo "<h1>Resting State Analysis</h1>" > analysisResults.html
echo "<br><b>Directory: </b>$indir" >> analysisResults.html
analysisDate=`date`
echo "<br><b>Date: </b>$analysisDate" >> analysisResults.html
user=`whoami`
echo "<br><b>User: </b>$user<br><hr>" >> analysisResults.html
echo "<h2>Motion Results</h2>" >> analysisResults.html
echo "<br><img src="rot.png" alt="rotations"><br><br><img src="rot_mm.png" alt="rotations_mm"><br><br><img src="trans.png" alt="translations"><br><br><img src="rot_trans.png" alt="rotations_translations"><br><br><img src="disp.png" alt="displacement"><hr>" >> analysisResults.html
echo "<h2>SNR Results</h2>" >> analysisResults.html
echo "<br><b>Scan SNR: </b>$SNRout" >> analysisResults.html
echo "<br>$spikeCount spikes detected at ${spikeThresh} standard deviation threshold" >> analysisResults.html
echo "<br><br><img src="normscore.png"" >> analysisResults.html
echo "<br>" >> analysisResults.html
echo "<br><b>AFNI 3dTqual Results</b><br><br>" >> analysisResults.html
echo "<br><img src="3dTqual.png"" >> analysisResults.html
echo "<br>" >> analysisResults.html

################################################################

#Cleanup
rm -rf tmpLesionMask
} #end function

printf "%s\n\n\n" "$0 Complete"