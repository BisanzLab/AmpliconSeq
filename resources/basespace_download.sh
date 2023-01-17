#Building bcl2fastq for server
#    export TMP=/tmp
#    export SOURCE=/data/shared_resources/sftwr/bcl2fastq
#    export BUILD=${TMP}/bcl2fastq2-v2.17.1.x-build
#    export INSTALL_DIR=/data/shared_resources/sftwr/bcl2fastq2-v2.20.0.422
#    mkdir ${BUILD}
#    cd ${BUILD}
#    ${SOURCE}/src/configure --prefix=${INSTALL_DIR}
#    make
#    make install
#see here for necessary update to make it work for ubuntu 18 https://sarahpenir.github.io/linux/Installing-bcl2fastq/



#/data/shared_resources/sftwr/basespace_cli/bs run list # to find the run id matching the sequencing run
mkdir basespacedl
/data/shared_resources/sftwr/basespace_cli/bs download run -i YOURRUNHERE -o basespacedl

#need to increase number of open files for session 
ulimit -n 4096

bcl2fastq \
 --runfolder-dir  /data/SequencingRuns/YOURDIRHERE/basespacedl \
 --output-dir reads \
 -r 4 -p 4 -w 4 \
 --sample-sheet /data/SequencingRuns/YOURDIRHERE/YOURSAMPLESHEETHERE.csv
