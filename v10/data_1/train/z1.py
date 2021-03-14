#!/usr/bin/python

import os

dname = "wave_king" 
for i in os.listdir(dname):
    print ("spk%03d wave_king/k%03d.wav" %(i,i))

