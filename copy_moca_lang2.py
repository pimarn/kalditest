import os
import shutil

# List all files in a directory using os.listdir
basepath = '/data/corpus/moca_data/data4'
odir = '/data/corpus/moca_data/lang2'
i=0

for entry in os.listdir(basepath):
    fpath=os.path.join(basepath,entry) + "/language2/sound.m4a"
    fpath_ans=os.path.join(basepath,entry) + "/language2/answer.png"
    if os.path.isfile(fpath):
        i += 1
        nfile = odir + "/S" + str(i).zfill(9) + ".m4a"
        nfile_ans = odir + "/S" + str(i).zfill(9) + ".png"
        shutil.copyfile (fpath,nfile)
        shutil.copyfile (fpath_ans,nfile_ans)
        print ("copy %s to %s" % (fpath,nfile))
