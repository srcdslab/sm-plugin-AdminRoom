import sys
import os
import re
import io
import getopt

DEBUG = False

def fileopen(input_file):
    encodings = ["utf-32", "utf-16", "utf-8", "cp1252", "gb2312", "gbk", "big5"]
    tmp = ''
    for enc in encodings:
        try:
            with io.open(input_file, mode="r", encoding=enc) as fd:
                tmp = fd.read()
                break
        except:
            if DEBUG:
                print(enc + ' failed')
            continue
    return [tmp, enc]

def mapadmin2adminroom(input_file):
    if not os.path.isfile(input_file):
        print(input_file + ' not exist')
        return

    src = fileopen(input_file)
    tmp = src[0]
    src = ''
    utf8bom = ''

    if u'\ufeff' in tmp:
        tmp = tmp.replace(u'\ufeff', '')
        utf8bom = u'\ufeff'
    
    tmp = tmp.replace("\r", "")
    lines = tmp.split("\n")

    content = ''
    output_file = ''
    outputfolder = 'maps'
    startwritting = False
    for ln in range(len(lines)):
        line = lines[ln]

        if "ze_" in line or "ZE_" in line:
            if startwritting == True:
                with io.open(output_file, 'a+', encoding='utf8') as output:
                    output.write(content)

            content = utf8bom + '\"AdminRoom\"' + '\n'
            startwritting = True
            mapname = line.strip()
            mapname = mapname[1:len(mapname)-1]
            if not os.path.exists(outputfolder) or not os.path.isdir(outputfolder):
                os.makedirs(outputfolder)
            output_file = "{mapsfolder}/{mapname}.cfg".format(mapsfolder=outputfolder, mapname=mapname)

        if "ze_" not in line and not "ZE_" in line and startwritting == True:
            if "adminroom" in line:
                pos = [m.start() for m in re.finditer('\"', line)]
                origin = line[pos[2]:]
                origin = origin[1:len(origin)-1]
                adminrooms = '''    "adminrooms"
    {{
        "0"
        {{
            "name"      "Admin Room"
            "origin"    "{origin}"
        }}
    }}'''.format(origin=origin)
                line = adminrooms
            else:
                line = line[1:]

            content = content + line + '\n'

def print_helper():
    print('mapdmin2adminroom.py -i <input> inputfile')

if __name__ == "__main__":
    try:
        opts, args = getopt.getopt(sys.argv[1:], "i:", ["input="])
    except getopt.GetoptError:
        print_helper()
        sys.exit(2)

    input_file = None
    for opt, arg in opts:
        if opt in ("-i", "--input"):
            input_file = arg

    if not input_file:
        print_helper()
        sys.exit(2)

    mapadmin2adminroom(input_file)
