#!/bin/bash

if [ "$#" -lt "3" ]; then
    echo "usage:\n\t$0 in number displacement_max_corner"
    echo "example toto.tiff 10 5"
    exit 1
fi

in=$1
NUMBER=$2
L=$3

# create directory
dir=evaluation_modification
mkdir $dir
cd $dir
in=../$in

# create burst
echo "Creating burst of $NUMBER images with displacement of $L"
interp=bicubic
boundary=hsym
base_out=burst
transform=8 #homography
#create_burst $in $base_out $NUMBER $interp $boundary $L $transform

# the reference image is assumed to be the first image
ref_number=1

# global file to store the result
global_results=../results.txt

# sift parameters
regpat=sift_%i.tiff #just used to set the name of the homography files ...
regpat_sift=sift_%i.hom # to this value (shitty script)
method=splineper #useless
boundary=hsym #useless
sr=sr
field_sift=field_sift_%i.tiff
rmse_sift=rmse_sift.txt
max_sift=max_sift.txt

# ICA parameters
NORMALIZATION=0
SCALES=5
PRECISION=0.001

# comparison fields
centered=0
w=`imprintf %w $in`
h=`imprintf %h $in`
opt=1 # to determine if comparison has h1-h2 (1) or h2^-1 o h1 - id (0)

# resampling parameters
outpat_sift=sift_%i.tiff
outpat_sift_noisy=sift_noisy_%i.tiff
zoom=1
interp=bicubic
boundary=hsym

# image parameters
INPAT=../${base_out}_%i.tiff
INPAT_NOISY=noisy_%i.tiff
TRUE_REGPAT=../${base_out}_%i.hom
REF=`printf $INPAT_NOISY 1`

# loop over the noise level
# echo "Starting the loop"
for noise in 0 3 5 10 20 30 50; do
# for noise in 3 5 10; do
    echo "Noise level $noise"
    dir=noise$noise
    mkdir $dir
    cd $dir
    echo -e "\n Noise level $noise" >> $global_results
    for i in `seq 1 $NUMBER`; do
            INi=`printf $INPAT $i`
            OUTi=`printf $INPAT_NOISY $i`
           # echo "add_noise $noise $INi $OUTi"
    done | parallel -j 32

    # SIFT + RANSAC estimation
        echo "SIFT + RANSAC estimation"
        echo "SIFT + RANSAC estimation" >> $global_results
        start=`date +%s.%N`
        burst_registration_iteration.sh $INPAT_NOISY $regpat $ref_number $NUMBER $ref_number $method $boundary $sr 0 > /dev/null
        end=`date +%s.%N`
        runtime=$(echo "$end - $start" | bc)
        echo "runtime $runtime seconds" >> $global_results

        # field comparison
        for i in `seq 2 $NUMBER`; do
            REGSIFTi=`printf $regpat_sift $i`
            REGi=`printf $TRUE_REGPAT $i`
            FIELDi=`printf $field_sift $i`
            compare_homography $w $h "`cat $REGSIFTi`" "`cat $REGi`" $FIELDi $opt
            compute rmse $centered $FIELDi >> $rmse_sift
            compute max $centered $FIELDi >> $max_sift
        done
        echo "Mean and std of the RMSE" >> $global_results
        mean_and_std $rmse_sift 2 >> $global_results
        echo "Mean and std of the MAX" >> $global_results
        mean_and_std $max_sift 2 >> $global_results

        # resampling
#         for i in `seq 2 $NUMBER`; do
#             INi=`printf $INPAT $i`
#             INNOISYi=`printf $INPAT_NOISY $i`
#             REGi=`printf $TRUE_REGPAT $i`
#
#             # sift
#             REGSIFTi=`printf $regpat_sift $i`
#             OUTi=`printf $outpat_sift $i`
#             synflow_global hom "`cat $REGSIFTi`" ../$in $OUTi /dev/null $zoom $interp /dev/null $boundary
#             diff2 $OUTi $INi $OUTi
#             crop 10 10 -10 -10 $OUTi $OUTi
#
#             # sift noisy
#             REGSIFTi=`printf $regpat_sift $i`
#             OUTi=`printf $outpat_sift_noisy $i`
#             synflow_global hom "`cat $REGSIFTi`" $REF $OUTi /dev/null $zoom $interp /dev/null $boundary
#             diff2 $OUTi $INNOISYi $OUTi
#             crop 10 10 -10 -10 $OUTi $OUTi
#         done

    # ICA
        echo "ICA estimation"
        echo -e "\n ICA estimation" >> $global_results
        #for NORMALIZATION in 0 1; do
        #for SAVE in 0 1; do
#        SAVE=1
#            for FIRST_SCALE in 0 1 2 3 4; do
#                for EDGEPADDING in 0 5; do
#                    for ROBUST_GRADIENT in 0 1 2 3 4 5; do
#                        for ROBUST in 0 1 2 3 4; do
#                            echo "save $SAVE first_scale ${FIRST_SCALE} edge ${EDGEPADDING} gradient ${ROBUST_GRADIENT} robust ${ROBUST}"
#                            echo -e "\n save $SAVE first_scale ${FIRST_SCALE} edge ${EDGEPADDING} gradient ${ROBUST_GRADIENT} robust ${ROBUST}" >> $global_results
#                            basefile=save${SAVE}_scale${FIRST_SCALE}_edge${EDGEPADDING}_gradient${ROBUST_GRADIENT}_robust${ROBUST}
#                            regpat_ica=ica_${basefile}_%i.hom
#
#                            # ICA estimation
#                            start=`date +%s.%N`
#                            for i in `seq 2 $NUMBER`; do
#                                INi=`printf $INPAT_NOISY $i`
#                                REGi=`printf $regpat_ica $i`
#                                cmd="SAVELONGER=$SAVE NORMALIZATION=$NORMALIZATION EDGEPADDING=$EDGEPADDING NANIFOUTSIDE=$EDGEPADDING ROBUST_GRADIENT=$ROBUST_GRADIENT inverse_compositional_algorithm $REF $INi -f $REGi -n $SCALES -r $ROBUST -e $PRECISION -t $transform -s $FIRST_SCALE"
#                                echo "$cmd"
#                            done | parallel -j 32
#                            end=`date +%s.%N`
#                            runtime=$(echo "$end - $start" | bc) 
#                            echo "runtime $runtime seconds" >> $global_results
#
#                            # field comparison
#                            field_ica=field_ica_${basefile}_%i.tiff
#                            rmse_ica=rmse_ica_${basefile}.txt
#                            max_ica=max_ica_${basefile}.txt
#                            for i in `seq 2 $NUMBER`; do
#                                REGICAi=`printf $regpat_ica $i`
#                                REGi=`printf $TRUE_REGPAT $i`
#                                FIELDi=`printf $field_ica $i`
#                                compare_homography $w $h "`cat $REGICAi`" "`cat $REGi`" $FIELDi $opt
#                                compute rmse $centered $FIELDi >> $rmse_ica
#                                compute max $centered $FIELDi >> $max_ica
#                            done
#                            echo "Mean and std of the RMSE" >> $global_results
#                            mean_and_std $rmse_ica 2 >> $global_results
#                            echo "Mean and std of the MAX" >> $global_results
#                            mean_and_std $max_ica 2 >> $global_results
#
#                            # image resampling
#    #                         outpat_ica=ica_${basefile}_%i.tiff
#    #                         outpat_ica_noisy=ica_noisy_${basefile}_%i.tiff
#    #                         for i in `seq 2 $NUMBER`; do
#    #                             INi=`printf $INPAT $i`
#    #                             INNOISYi=`printf $INPAT_NOISY $i`
#    #                             REGi=`printf $TRUE_REGPAT $i`
#    #                             # ica
#    #                                 REGICAi=`printf $regpat_ica $i`
#    #                                 OUTi=`printf $outpat_ica $i`
#    #                                 synflow_global hom "`cat $REGICAi`" ../$in $OUTi /dev/null $zoom $interp /dev/null $boundary
#    #                                 diff2 $OUTi $INi $OUTi
#    #                                 crop 10 10 -10 -10 $OUTi $OUTi
#    #                             # ica noisy
#    #                                 REGICAi=`printf $regpat_ica $i`
#    #                                 OUTi=`printf $outpat_ica_noisy $i`
#    #                                 synflow_global hom "`cat $REGICAi`" $REF $OUTi /dev/null $zoom $interp /dev/null $boundary
#    #                                 diff2 $OUTi $INNOISYi $OUTi
#    #                                 crop 10 10 -10 -10 $OUTi $OUTi
#    #                         done
#                        done
#                    done
#                done
#            done
#        #done
    cd ..
done

cd ..
