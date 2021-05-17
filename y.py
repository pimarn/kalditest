import os
import shutil

# List all files in a directory using os.listdir
basepath = '/data/corpus/moca_data/data'
odir = '/data/corpus/moca_data/lang2'
i=0

for entry in os.listdir(basepath):
    fpath=os.path.join(basepath,entry) + "/language2/sound.m4a"
    if os.path.isfile(fpath):
        i += 1
        nfile = odir + "/S" + str(i).zfill(9) + ".m4a"
        shutil.copyfile (fpath,nfile)
        print ("copy %s to %s" % (fpath,nfile))
