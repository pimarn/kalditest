import os
import pandas as pd

#rootDir = "\\Users\\king\\test\\data\\corpus\\AIFORTHAI-LotusCorpus\\LOTUS-CD-FREE"
rootDir = "/data/corpus/AIFORTHAI-LotusCorpus/LOTUS-CD-FREE/PD"
outTxt = "lotus_text"
outWav = "lotus_wav.scp"


df = pd.read_csv('/data/corpus/lotus/lotus_map.csv',dtype='str')
df['file'] = df['fname'] + "_" + df['seq'] + '.wav'
df = df[['file', 'sentence']]
my_dict = df.set_index('file').T.to_dict('list')


oTxt = open(outTxt, 'w', encoding='utf-8')
oFile = open(outWav, 'w', encoding='utf-8')

for dirName, subdirList, fileList in os.walk(rootDir):
    #print('Found directory: %s' % dirName)
    for fname in fileList:
        if fname.endswith(".wav"):
            #print(dirName, '\t%s' % fname)
            file_id = fname[7:]
            s = my_dict[file_id][0]
            fpath = dirName + "/" + fname
            print('\t%s' % fpath)
            #txtLine = fpath + " " + s + '\n'
            #txtLine = fname[:-4] + " " + s + '\n'
            txtLine = s + '\n'
            wavLine = fname[:-4] + " " + fpath + '\n'
            oFile.write(wavLine)
            oTxt.write(txtLine)
oFile.close()
oTxt.close()
