from itertools import groupby
import re
import numpy
from matplotlib.pyplot import legend,plot,savefig,clf

f = open('uart_data.txt')
commands = f.read().split('#')
isdump = lambda a: a.startswith('Sending command 01')
coincident_dumps = [list(g) for k,g in groupby(commands,key=isdump) if k]

def extract_data(dump_string):
    dump_lines = dump_string.split('\n')
    data = [ int(a.strip(),16) for a in dump_lines[1:] if a]
    channel = re.search("[0-9]*([0-9]{1})[0-9]{2}",dump_lines[0]).group(1)
    return channel,numpy.array(data)

coincident_datas = [dict(extract_data(x) for x in coincident_dump) for coincident_dump in coincident_dumps]

for i,datas in enumerate(coincident_datas):
    clf()
    for channel in datas:
        plot(datas[channel],label='Channel {}'.format(channel))
        legend(loc='best')
    savefig('coincident_dump{}.png'.format(i))
