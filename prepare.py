#!/usr/bin/python

from glob import glob
import sys
import re
import os
import datetime
import shutil


def prepare(fname):
    print "processing " + fname
    f = open(fname, 'rw')
    content = f.read()
    f.close()
    content = re.sub(r"```([a-zA-Z]+)", r'{% highlight \1 linenos %}', content, re.M)
    content = content.replace("```", "{% endhighlight %}")
    content = re.sub(r"(\n|\r)(>\s)", r'\n', content, 500, re.M)
    content = re.sub(r"(\n|\r)(>\s)", r'\n', content, 500, re.M)

    fname_new = fname.replace(".lidr", ".markdown")
    f = open(fname_new, 'w')
    f.write(content)
    f.close()

os.system('cp -rf _lidr/* _posts/idris/')

for fname in glob('_posts/idris/**/*.lidr'):
    prepare(fname)
for fname in glob('_posts/idris/*.lidr'):
    prepare(fname)

for fname in glob('_posts/idris/**/*'):
    print "processing " + fname
    if ((not fname.endswith(".markdown")) and (not os.path.isdir(fname))):
        os.remove(fname)
for fname in glob('_posts/idris/*'):
    print "processing " + fname
    if ((not fname.endswith(".markdown")) and (not os.path.isdir(fname))):
        os.remove(fname)
