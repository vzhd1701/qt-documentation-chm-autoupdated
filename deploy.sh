#!/bin/bash

set -e

USER_NAME="vzhd1701"
USER_EMAIL="vzhd1701@gmail.com"

VERSION_CHECKFILE_QT_DOCS="version_qt_docs"
VERSION_CHECKFILE_REVISION="version_revision"

verlte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

compile_chm() {
    # Chocolatey has html-help-workshop, but it cannot install it properly

    # wget -q "https://download.microsoft.com/download/0/A/9/0A939EF6-E31C-430F-A3DF-DFAE7960D564/htmlhelp.exe"
    wget -q "https://www.helpandmanual.com/download/htmlhelp.exe"
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

release_new_version() {
    local -r VERSION_NEW=$1
    local -r VERSION_CURRENT=$2
    local -r REVISION=$3

    wget -q -nc https://raw.githubusercontent.com/vzhd1701/random.scripts/master/sign_key.asc.7z
    7z e -so -p$REPO_SIGN_KEY_PASS_7Z sign_key.asc.7z | gpg --import &> /dev/null
    rm sign_key.asc.7z

    git remote set-url origin "https://${REPO_GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git"

    git config user.name "$USER_NAME"
    git config user.email "$USER_EMAIL"
    git config user.signingkey "$REPO_SIGN_KEY_ID"
    git config commit.gpgsign true
    git config tag.gpgsign true

    git checkout master

    if [ "$VERSION_NEW" != "$VERSION_CURRENT" ]; then
        TAG_NEW="$VERSION_NEW"

        if [ -z "$VERSION_CURRENT" ]; then
            MESSAGE_COMMIT="initial Qt Docs version $VERSION_NEW"
            MESSAGE_TAG="Qt Docs $VERSION_NEW CHM"
        else
            MESSAGE_COMMIT="update Qt Docs version $VERSION_CURRENT -> $VERSION_NEW"
            MESSAGE_TAG="Qt Docs $VERSION_NEW CHM (update from $VERSION_CURRENT)"
        fi

        sed -i "s/^\[\*\*Download Qt Documentation CHM.*\*\*\]/[**Download Qt Documentation CHM $LATEST_QT_VERSION**]/" README.md
        echo -n "$LATEST_QT_VERSION" > "$VERSION_CHECKFILE_QT_DOCS"
        git add README.md
        git add "$VERSION_CHECKFILE_QT_DOCS"

        if [ -f "$VERSION_CHECKFILE_REVISION" ]; then
            echo "Removing revision file from repo"
            rm "$VERSION_CHECKFILE_REVISION"
            git rm "$VERSION_CHECKFILE_REVISION"
        fi
    else
        TAG_NEW="$VERSION_NEW-$REVISION"
        MESSAGE_COMMIT="revision $REVISION Qt Docs version $VERSION_NEW"
        MESSAGE_TAG="Qt Docs $VERSION_NEW CHM (revision $REVISION)"
    fi

    git commit --allow-empty -m "(autoupdate) $MESSAGE_COMMIT"
    git tag -a -m "$MESSAGE_TAG" "$TAG_NEW"

    git push origin master
    git push origin "$TAG_NEW"

    # Shutting down gpg-agent so that Travis build could terminate properly
    taskkill //F //FI "Imagename eq gpg-agent.exe"
}

case $1 in
  -c|--check)
    if [ ! -z "$TRAVIS_TAG" ]; then
        echo "Building for TAG, skipping check..."
        exit 0
    fi

    if [[ $(git tag) ]]; then
        CURRENT_TAG=$(git describe --tags --abbrev=0)
        [[ $CURRENT_TAG =~ -[0-9]+$ ]] && CURRENT_REVISION=${CURRENT_TAG##*-}
    fi

    echo "Checking latest Qt Docs version..."

    LATEST_QT_VERSION=$(py -3 get_qt_docs.py --latest-version)

    [ -f "$VERSION_CHECKFILE_QT_DOCS" ] && CURRENT_QT_VERSION=$(cat "$VERSION_CHECKFILE_QT_DOCS")

    if [ "$LATEST_QT_VERSION" == "$CURRENT_QT_VERSION" ]; then
        [ -f "$VERSION_CHECKFILE_REVISION" ] && LATEST_REVISION=$(cat "$VERSION_CHECKFILE_REVISION")
    fi

    if [ "$LATEST_QT_VERSION" == "$CURRENT_QT_VERSION" ]; then
        if [ "$LATEST_REVISION" == "$CURRENT_REVISION" ]; then
            echo "Current version is up to date, terminating..."
            exit 0
        fi    
    elif verlte "$LATEST_QT_VERSION" "$CURRENT_QT_VERSION"; then
        echo "Latest version is lower than current! Something wrong, terminating..."
        exit 1
    fi

    echo "Latest Version: $LATEST_QT_VERSION"
    [ -n "$LATEST_REVISION" ] && echo "Latest Revision: $LATEST_REVISION"
    [ -n "$CURRENT_QT_VERSION" ] && echo "Current Version: $CURRENT_QT_VERSION"
    [ -n "$CURRENT_REVISION" ] && echo "Current Revision: $CURRENT_REVISION"
    echo "Initiating release..."

    release_new_version "$LATEST_QT_VERSION" "$CURRENT_QT_VERSION" "$LATEST_REVISION"

    exit 0
    ;;
  -d|--deploy)
    echo "Getting QT Docs archives list..."

    py -3 get_qt_docs.py --docs-latest > docs_list.txt

    echo "Downloading archives..."

    aria2c -q -d Docs -j 10 --async-dns=false -i docs_list.txt

    echo "Unpacking archives..."

    7z x "Docs/*.7z" &> /dev/null
    DOCS_SOURCE=$(realpath $(ls -d Docs/*/))

    echo "Converting docs into CHM project..."

    py -3 -m pysassc qt-documentation-chm/style.sass style.css
    py -3 qt-documentation-chm -s style.css "$DOCS_SOURCE" output

    echo "Compiling CHM project into CHM file..."

    CHM_PROJECT=$(ls output/*.hhp)

    compile_chm "$CHM_PROJECT"

    CHM_FILE=$(ls output/*.chm)

    echo "Packing up for release..."

    7z a "Qt-$TRAVIS_TAG.chm.zip" ./qt-documentation-chm/fonts "./$CHM_FILE" &> /dev/null

    echo "Done!"

    exit 0
    ;;
esac
