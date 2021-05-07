#!/bin/bash

set -e

QT_VERSION=$1

compile_chm() {
    # Chocolatey has html-help-workshop, but it cannot install it properly

    # wget -q "https://download.microsoft.com/download/0/A/9/0A939EF6-E31C-430F-A3DF-DFAE7960D564/htmlhelp.exe"
    wget --no-check-certificate -q "https://www.helpandmanual.com/download/htmlhelp.exe"
    7z x -y -ohtmlhelp htmlhelp.exe &> /dev/null
    7z x -y -ohtmlhelp htmlhelp/hhupd.exe &> /dev/null

    /c/Windows/SysWOW64/regsvr32 //s htmlhelp/itircl.dll
    /c/Windows/SysWOW64/regsvr32 //s htmlhelp/itss.dll
    /c/Windows/SysWOW64/regsvr32 //s htmlhelp/itcc.dll

    # hhc.exe returns 1 on success

    set +e
    htmlhelp/hhc.exe "$@"
    retVal=$?
    set -e

    if [ $retVal -ne 1 ]; then
        echo "CHM compilation failed"
        return 1
    fi

    return 0
}

echo "Getting QT Docs archives list..."

python get_qt_docs.py --docs "$QT_VERSION" > docs_list.txt

echo "Downloading archives..."

aria2c -q -d Docs -j 10 --async-dns=false -i docs_list.txt

echo "Unpacking archives..."

7z x "Docs/*.7z" &> /dev/null
DOCS_SOURCE=$(realpath $(ls -d Docs/*/))

echo "Converting docs into CHM project..."

python -m pysassc qt-documentation-chm/style.sass style.css
python qt-documentation-chm -s style.css "$DOCS_SOURCE" output

echo "Compiling CHM project into CHM file..."

CHM_PROJECT=$(ls output/*.hhp)

compile_chm "$CHM_PROJECT"

CHM_FILE=$(ls output/*.chm)

echo "Packing up for release..."

7z a "Qt-${QT_VERSION}.chm.zip" ./qt-documentation-chm/fonts "./$CHM_FILE" &> /dev/null

echo "Done!"
